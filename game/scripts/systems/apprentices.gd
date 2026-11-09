## Apprentices — craftspeople who work INSIDE the smithy (distinct from expedition hirelings, Hire).
## EN: The smith takes apprentices once he can teach (data/apprentices.json "unlock"). Each apprentice has a rank
##     (novice → apprentice → journeyman → master), crafting skills (a SkillSys set), traits, a wage, a maker's mark
##     of their own, memories and a log. The workshop keeps a task queue — repairs, commissions, crafting, material
##     preparation and station upkeep — worked through the recipe's real operations, one worker per station (the
##     smith first), only in shift hours, from materials actually taken from the stores (and returned on cancel).
##     Finished pieces go through the smith's own pipeline (Crafting.build) with simulated, seeded checks, so they
##     carry real stats, rarity and a full provenance: the apprentice as maker, made at the Ironhand forge.
##     Progress runs from Game.advance_minutes (tick every 5 minutes): sleeping, waiting and travelling simulate the
##     same work as watching it. State: Game.state["apprentices"] (created lazily — old saves load unchanged).
## DA: Lærlinge arbejder i smedjen: rang, færdigheder, træk, løn, eget mærke og hukommelse. En opgavekø (reparationer,
##     bestillinger, smedning, forarbejdning, vedligehold) udføres trin for trin ved rigtige stationer, med rigtige
##     materialer og samme færdiggørelse som smedens eget arbejde.
class_name Apprentices
extends RefCounted

const RANKS := ["novice", "apprentice", "journeyman", "master"]
const KINDS := ["repair", "commission", "craft", "prep", "maintain", "contract"]   # contract: hours on a major order (Contracts)
const PREF_DISCIPLINES := ["classic", "classic", "stitching", "alchemy", "runecraft"]
const FINISHED := ["done", "failed", "cancelled"]
const LOG_CAP := 80
const MEMORY_CAP := 30
const KEEP_FINISHED := 30
const FETCH_MIN := 10.0      # fetching materials from the stock hall before the first operation
const WALK_MIN := 5.0        # walking to the next station

## The room the smith is standing in (set by the world each time he changes room; "" = unknown / elsewhere).
## Work at a station in the same room counts as supervised.
static var smith_room := ""


# ======================================================================= data & state
static func cfg(key: String) -> Variant:
	var d: Variant = DB.extra("apprentices")
	return (d as Dictionary).get(key, {}) if d is Dictionary else {}


static func _num(key: String, fallback: float) -> float:
	var d: Variant = DB.extra("apprentices")
	var v: Variant = (d as Dictionary).get(key, fallback) if d is Dictionary else fallback
	return float(v) if (v is int or v is float) else fallback


static func _c(section: String, key: String, fallback: Variant) -> Variant:
	var s: Variant = cfg(section)
	return (s as Dictionary).get(key, fallback) if s is Dictionary else fallback


static func _fresh() -> Dictionary:
	return {"staff": [], "applicants": [], "alumni": [], "tasks": [], "next_task": 1, "auto": true, "stations": {},
		"log": [], "notices": [], "applicants_day": -1}


## The state, created on first touch (old saves gain it lazily).
static func st() -> Dictionary:
	if Game.state.is_empty():
		return _fresh()
	if not Game.state.has("apprentices"):
		Game.state["apprentices"] = _fresh()
	var s: Dictionary = Game.state["apprentices"]
	var f := _fresh()
	for k in f:
		if not s.has(k):
			s[k] = f[k]
	return s


static func staff() -> Array:
	return st()["staff"]


static func get_a(id: String) -> Dictionary:
	for a in staff():
		if str(a["id"]) == id:
			return a
	return {}


static func alumni() -> Array:
	return st()["alumni"]


static func tasks() -> Array:
	return st()["tasks"]


static func task(id: int) -> Dictionary:
	for t in tasks():
		if int(t["id"]) == id:
			return t
	return {}


static func open_tasks() -> Array:
	return tasks().filter(func(t): return not str(t["state"]) in FINISHED)


static func _changed() -> void:
	Events.apprentices_changed.emit()


static func _rng(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return r


static func _pick_line(kind: String, key: String) -> String:
	var lines: Dictionary = cfg("lines")
	var arr: Array = lines.get(kind, ["%s"])
	if arr.is_empty():
		return "%s"
	return str(arr[_rng(key).randi_range(0, arr.size() - 1)])


static func log_line(a_id: String, text: String) -> void:
	var lg: Array = st()["log"]
	lg.append({"day": Game.day(), "time": Game.time_string(), "text": text, "app": a_id})
	while lg.size() > LOG_CAP:
		lg.pop_front()


static func remember(a: Dictionary, text: String, uid := -1, event := "") -> void:
	if not a.has("memories"):
		a["memories"] = []
	var m := {"day": Game.day(), "text": text}
	if uid >= 0:
		m["uid"] = uid
	if event != "":
		m["event"] = event
	(a["memories"] as Array).append(m)
	while (a["memories"] as Array).size() > MEMORY_CAP:
		(a["memories"] as Array).pop_front()


# ======================================================================= unlock & limits
## The smith can teach once he is a seasoned hand (Smithing 6) or has bought the first room next door.
## With the planner's career (t_progression) the first neighbouring room is bought early in the midgame, when the
## starting workshop is full; smithing 6 comes with the first steel work.
static func unlock_reason() -> String:
	if Game.state.is_empty():
		return "No game."
	var u: Dictionary = cfg("unlock")
	if Game.player_level("smithing") >= int(u.get("smithing", 6)):
		return ""
	if (Property.st()["units"] as Array).size() >= int(u.get("units", 2)):
		return ""
	return str(u.get("text", "You cannot take apprentices yet."))


static func unlocked() -> bool:
	return unlock_reason() == ""


static func workshop_rooms() -> int:
	var n := 0
	for r in Property.rooms():
		if Property.room_owned(r) and Property.kind(r) == "workshop":
			n += 1
	return n


## 1 place, one more per further owned workshop room, at most 4.
static func max_staff() -> int:
	var s: Dictionary = cfg("staff")
	var n := int(s.get("base", 1)) + int(s.get("per_workshop_room", 1)) * maxi(0, workshop_rooms() - 1)
	return clampi(n, 1, int(s.get("max", 4)))


static func hire_reason() -> String:
	var u := unlock_reason()
	if u != "":
		return u
	if staff().size() >= max_staff():
		var m := max_staff()
		return "The workshop has room for %d apprentice%s — buy another workshop room to take more." % [m, "" if m == 1 else "s"]
	return ""


# ======================================================================= applicants, hiring, dismissal
static func applicants() -> Array:
	var s := st()
	if int(s.get("applicants_day", -1)) < 0 and unlocked():
		refresh_applicants()
	return s["applicants"]


static func _trait_ids(good: bool) -> Array:
	var out := []
	var tr: Dictionary = cfg("traits")
	var ks := tr.keys()
	ks.sort()
	for k in ks:
		if bool(tr[k].get("good", true)) == good:
			out.append(str(k))
	return out


static func _skill_ids() -> Array:
	var sk: Variant = cfg("skills")
	return sk if sk is Array and not (sk as Array).is_empty() else ["smithing", "runecraft", "alchemy", "enchanted_stitching", "arcane_metalwork"]


## A new week's applicants for the workshop (1–3). Low starting skills, 1–2 traits, a preferred discipline.
static func refresh_applicants() -> void:
	var s := st()
	var out := []
	var looks: Array = DB.names.get("applicant_looks", [])
	var ap: Dictionary = cfg("applicants")
	var n := randi_range(int(ap.get("min", 1)), int(ap.get("max", 3)))
	for i in n:
		if looks.is_empty():
			break
		var lk: Dictionary = looks.pick_random()
		var race: String = str(lk.get("race", "Human"))
		var pool: Dictionary = DB.names["first"].get(race, DB.names["first"]["Human"])
		var first: String = str((pool["f"] if bool(lk.get("female", false)) else pool["m"]).pick_random())
		var last: String = str(DB.names["last"].pick_random())
		var pref: String = str(PREF_DISCIPLINES.pick_random())
		var levels := {}
		for sk: String in _skill_ids():
			levels[sk] = 0
		levels["smithing"] = randi_range(0, 2)
		var psk: String = str(Crafting.DISCIPLINE_SKILL.get(pref, "smithing"))
		levels[psk] = int(levels.get(psk, 0)) + randi_range(1, 2)
		var traits := []
		var good := _trait_ids(true)
		var bad := _trait_ids(false)
		if randf() < 0.85 and not good.is_empty():
			traits.append(str(good.pick_random()))
		if randf() < 0.6 and not bad.is_empty():
			traits.append(str(bad.pick_random()))
		if traits.is_empty() and not good.is_empty():
			traits.append(str(good[0]))
		var total := 0
		for k in levels:
			total += int(levels[k])
		var wage := int(ap.get("base_wage", 3)) + int(total / 3)
		out.append({"name": "%s %s" % [first, last], "look": str(lk.get("look", "applicant_0")), "race": race,
			"female": bool(lk.get("female", false)), "personality": str(DB.names["personality"].pick_random()),
			"traits": traits, "prefs": [pref], "levels": levels, "wage": wage, "fee": wage * int(ap.get("fee_days", 5))})
	s["applicants"] = out
	s["applicants_day"] = Game.day()
	_changed()


static func _initials(name: String) -> String:
	var out := ""
	for w in name.split(" ", false):
		out += w.substr(0, 1).to_upper() + "."
	return out


## Hires applicant `index`: pays the signing fee. Returns "" or why not.
static func hire(index: int) -> String:
	var why := hire_reason()
	if why != "":
		return why
	var apps := applicants()
	if index < 0 or index >= apps.size():
		return "No such applicant."
	var p: Dictionary = apps[index]
	if not Game.can_afford(int(p["fee"])):
		return "You cannot afford the signing fee (%d g)." % int(p["fee"])
	Game.add_gold(-int(p["fee"]), "wages", "Signing fee: apprentice " + str(p["name"]), "apprentices")
	var id := "app_%d" % Game.new_uid()
	var skills := {}
	for sk: String in _skill_ids():
		skills[sk] = {"lvl": int(p["levels"].get(sk, 0)), "xp": 0}
	var ini := _initials(str(p["name"]))
	var a := {"id": id, "name": str(p["name"]), "look": str(p["look"]), "race": str(p["race"]), "female": bool(p["female"]),
		"personality": str(p["personality"]), "traits": (p["traits"] as Array).duplicate(), "wage": int(p["wage"]),
		"hired_day": Game.day(), "rank": "novice", "skills": skills, "prefs": (p.get("prefs", []) as Array).duplicate(),
		"cat_counts": {}, "specialty": "", "works": 0, "mistakes": 0, "surprises": 0, "creations": [], "memories": [],
		"mark": {"id": id, "name": "%s's mark (%s)" % [str(p["name"]).split(" ")[0], ini],
			"desc": "the initials %s punched small beside a tiny anvil — %s's own mark" % [ini, p["name"]], "initials": ini},
		"status": _phase(), "task": -1, "activity": "", "loyalty": float(_c("loyalty", "start", 60.0)) + _trait_sum({"traits": p["traits"]}, "loyalty"),
		"mentored_day": -1, "notice": {}, "unpaid_days": 0, "no_ask_until": 0}
	staff().append(a)
	apps.remove_at(index)
	remember(a, "Came to the Ironhand forge as a novice on day %d." % Game.day())
	var line := _pick_line("hired", id) % a["name"]
	log_line(id, line)
	Game.journal("Took on %s as a workshop apprentice." % a["name"])
	Chronicle.add("apprentice", "%s joined the Ironhand forge as an apprentice." % a["name"], {"app": id})
	Audio.play("sfx/hire")
	_changed()
	return ""


## Lets an apprentice go. Not while they are in the middle of an operation (finish or cancel first);
## materials reserved for their unfinished work go back to the stores.
static func dismiss(id: String) -> String:
	var a := get_a(id)
	if a.is_empty():
		return "No such apprentice."
	var t := task(int(a.get("task", -1)))
	if not t.is_empty() and str(t.get("station", "")) != "" and float(t.get("progress", 0.0)) > 0.0:
		return "%s is in the middle of work at the %s — let them finish the step or cancel the task first." % [a["name"], _station_name(str(t["station"]))]
	_release(a)
	for t2 in open_tasks():
		if str(t2.get("assignee", "")) == id:
			t2["assignee"] = ""
			t2["manual"] = false
	_leave(a, "dismissed")
	log_line(id, "%s was let go." % a["name"])
	Game.journal("Let %s go from the workshop." % a["name"])
	_changed()
	return ""


## Removes an apprentice from the staff (dismissed, left, or gone to open their own workshop).
static func _leave(a: Dictionary, how: String) -> void:
	_release(a)
	a["status"] = "gone"
	a["left"] = {"day": Game.day(), "how": how}
	st()["notices"] = (st()["notices"] as Array).filter(func(n): return str(n.get("app", "")) != str(a["id"]))
	staff().erase(a)


## Frees the apprentice from their task: an unstarted or between-steps task returns its materials and waits.
static func _release(a: Dictionary) -> void:
	var t := task(int(a.get("task", -1)))
	a["task"] = -1
	if t.is_empty():
		return
	if str(t.get("worker", "")) == str(a["id"]):
		t["worker"] = ""
		t["station"] = ""
		if not str(t["state"]) in FINISHED:
			_return_taken(t)
			_reset_iteration(t)
			t["state"] = "queued"


# ======================================================================= ranks, traits, skills
static func rank_data(rank: String) -> Dictionary:
	for r in cfg("ranks"):
		if str(r.get("id", "")) == rank:
			return r
	return {"id": rank, "name": rank.capitalize(), "works": 0, "skill": 0, "max_difficulty": 2, "equipment": false,
		"disciplines": ["classic"], "quality": 0.0, "speed": 0.8, "ceiling": 95.0}


static func rank_name(app: Dictionary) -> String:
	return str(rank_data(str(app.get("rank", "novice"))).get("name", "Novice"))


static func rank_index(app: Dictionary) -> int:
	return maxi(0, RANKS.find(str(app.get("rank", "novice"))))


static func level(app: Dictionary, skill: String) -> int:
	return SkillSys.level(app.get("skills", {}), skill)


static func best_skill(app: Dictionary) -> String:
	var best := "smithing"
	for sk: String in _skill_ids():
		if level(app, sk) > level(app, best):
			best = sk
	return best


## What the next rank needs: {rank, name, works, have_works, skill, have_skill, skill_name, ready, text} — {} at master.
static func next_rank(app: Dictionary) -> Dictionary:
	var i := rank_index(app)
	if i >= RANKS.size() - 1:
		return {}
	var r := rank_data(RANKS[i + 1])
	var bs := best_skill(app)
	var hw := int(app.get("works", 0))
	var hs := level(app, bs)
	var ready := hw >= int(r.get("works", 0)) and hs >= int(r.get("skill", 0))
	return {"rank": str(r["id"]), "name": str(r.get("name", "")), "works": int(r.get("works", 0)), "have_works": hw,
		"skill": int(r.get("skill", 0)), "have_skill": hs, "skill_name": SkillSys.skill_name(bs), "ready": ready,
		"text": "%s: %d/%d works, %s %d/%d" % [str(r.get("name", "")), hw, int(r.get("works", 0)), SkillSys.skill_name(bs), hs, int(r.get("skill", 0))]}


static func _trait_mult(app: Dictionary, key: String) -> float:
	var m := 1.0
	var tr: Dictionary = cfg("traits")
	for tid in app.get("traits", []):
		m *= float(tr.get(str(tid), {}).get(key, 1.0))
	return m


static func _trait_sum(app: Dictionary, key: String) -> float:
	var v := 0.0
	var tr: Dictionary = cfg("traits")
	for tid in app.get("traits", []):
		v += float(tr.get(str(tid), {}).get(key, 0.0))
	return v


static func traits_text(app: Dictionary) -> Array:
	var out := []
	var tr: Dictionary = cfg("traits")
	for tid in app.get("traits", []):
		var d: Dictionary = tr.get(str(tid), {})
		out.append({"id": str(tid), "name": str(d.get("name", tid)), "good": bool(d.get("good", true)), "desc": str(d.get("desc", ""))})
	return out


static func add_xp(app: Dictionary, skill: String, amount: float) -> int:
	if amount <= 0.0 or not app.has("skills"):
		return 0
	return SkillSys.add_xp(app["skills"], skill, int(round(amount * _trait_mult(app, "xp"))), str(app["id"]))


## Promotion when the next rank's thresholds are met. Returns true on a rank-up.
static func _check_rank(app: Dictionary) -> bool:
	var nr := next_rank(app)
	if nr.is_empty() or not bool(nr["ready"]):
		return false
	app["rank"] = str(nr["rank"])
	var rd := rank_data(str(nr["rank"]))
	app["wage"] = int(app["wage"]) + int(rd.get("raise", 0))
	var line := _pick_line("rank", "%s|rank|%s" % [app["id"], nr["rank"]]) % [app["name"], str(rd.get("name", "")).to_lower()]
	log_line(str(app["id"]), line)
	remember(app, "Became a %s of the Ironhand forge on day %d." % [str(rd.get("name", "")).to_lower(), Game.day()])
	Events.toast.emit(line, "good")
	Game.journal(line)
	Chronicle.add("apprentice", line, {"app": str(app["id"])})
	return true


# ======================================================================= categories & specialties
## The kind of work a task/recipe is (for specialties and counts): blades, axes, armour, shields, bows, garments,
## potions, runes, ingots, cloth, jewellery, repairs, upkeep.
static func category(kind: String, rid := "") -> String:
	if kind == "repair":
		return "repairs"
	if kind == "maintain":
		return "upkeep"
	var r := DB.recipe(rid)
	if r.is_empty():
		return ""
	var disc := str(r.get("discipline", "classic"))
	var cat := str(r.get("category", ""))
	var out := str(r.get("output", ""))
	var d := DB.item(out)
	if cat == "jewellery":
		return "jewellery"
	if disc == "alchemy":
		return "potions"
	if disc == "runecraft":
		return "runes"
	if cat == "material":
		return "cloth" if disc == "stitching" else "ingots"
	if cat == "weapon":
		if out.begins_with("bow"):
			return "bows"
		if out.contains("axe") or out.contains("mace") or out.contains("hammer"):
			return "axes"
		return "blades"
	if str(d.get("slot", "")) == "shield":
		return "shields"
	return "garments" if disc == "stitching" else "armour"


static func category_name(cat: String) -> String:
	return str((cfg("categories") as Dictionary).get(cat, cat))


static func _check_specialty(app: Dictionary) -> void:
	if str(app.get("specialty", "")) != "":
		return
	var sp: Dictionary = cfg("specialty")
	var works := int(app.get("works", 0))
	if works < int(sp.get("works", 12)):
		return
	var best := ""
	var n := 0
	var cc: Dictionary = app.get("cat_counts", {})
	var ks := cc.keys()
	ks.sort()
	for k in ks:
		if k == "upkeep":
			continue
		if int(cc[k]) > n:
			n = int(cc[k])
			best = str(k)
	if best == "" or n < int(sp.get("works", 12)) * 0.5 or float(n) / float(works) < float(sp.get("share", 0.4)):
		return
	app["specialty"] = best
	var line := _pick_line("specialty", "%s|spec" % app["id"]) % [app["name"], category_name(best)]
	log_line(str(app["id"]), line)
	remember(app, "Found my calling on day %d: %s." % [Game.day(), category_name(best)])
	Events.toast.emit(line, "good")


static func _specialty_match(app: Dictionary, cat: String) -> bool:
	return cat != "" and str(app.get("specialty", "")) == cat


# ======================================================================= eligibility
## Can this apprentice make this recipe at all (rank, discipline training, skill vs difficulty)? "" = yes.
## Whether the SMITH has unlocked it is checked separately (a task only starts when he has).
static func can_make(app: Dictionary, recipe_id: String) -> String:
	var r := DB.recipe(recipe_id)
	if r.is_empty():
		return "Unknown recipe."
	var rd := rank_data(str(app.get("rank", "novice")))
	var rn := str(rd.get("name", "Novice")).to_lower()
	var disc := str(r.get("discipline", "classic"))
	var dname := str(Crafting.DISCIPLINE_NAME.get(disc, disc))
	if not (rd.get("disciplines", []) as Array).has(disc):
		return "%s is beyond a %s." % [dname, rn]
	var skill := Crafting.recipe_skill(recipe_id)
	var lvl := level(app, skill)
	if bool(rd.get("trained_only", false)) and not disc in ["classic", "stitching"] and lvl < int(_num("trained_level", 2.0)):
		return "Not trained in %s yet." % dname
	if Items.is_equipment({"def": str(r.get("output", ""))}) and not bool(rd.get("equipment", false)):
		return "A novice only repairs, prepares materials and tends the stations."
	var diff := Crafting.difficulty(recipe_id)
	if diff > int(rd.get("max_difficulty", 2)):
		return "Too hard for a %s (difficulty %d)." % [rn, diff]
	var reach := int(_num("reach", 1.0))
	if lvl + reach < diff:
		return "Needs %s %d (has %d)." % [SkillSys.skill_name(skill), diff - reach, lvl]
	if str(r.get("min_rarity", "")) != "" and not bool(rd.get("min_rarity", false)):
		return "Legendary-grade work stays with the smith or a master."
	return ""


## Recipes this apprentice may make now (and the smith has unlocked), by name.
static func recipes_for(app: Dictionary) -> Array:
	var out := []
	for r in DB.recipes.values():
		var rid := str(r["id"])
		if can_make(app, rid) == "" and Crafting.recipe_locked_reason(rid) == "":
			out.append(r)
	out.sort_custom(func(x, y): return str(x.get("name", "")) < str(y.get("name", "")))
	return out


## May this apprentice take this task? "" = yes.
static func eligible(app: Dictionary, t: Dictionary) -> String:
	if app.is_empty():
		return "No such apprentice."
	if str(app.get("status", "")) == "gone":
		return "%s no longer works here." % app.get("name", "")
	match str(t.get("kind", "")):
		"repair", "maintain":
			return ""
		"commission":
			var rid := str(t.get("recipe", ""))
			if rid == "":
				rid = commission_recipe(_order(str(t.get("order_id", ""))), app)
			if rid == "":
				return "%s cannot make anything that meets this commission yet." % app.get("name", "")
			return can_make(app, rid)
		"contract":
			if Contracts.finished_for_apprentices(str(t.get("target", ""))):
				return "Every piece of that order is made."
	return can_make(app, str(t.get("recipe", "")))


# ======================================================================= tasks
static func _order(oid: String) -> Dictionary:
	for o in Shop.orders():
		if str(o.get("id", "")) == oid:
			return o
	return {}


static func _customer_repair(npc: String) -> Dictionary:
	var c := Shop.customer(npc)
	if c.is_empty() or str(c.get("want", "")) != "repair":
		return {}
	return c


## The piece to be mended for a repair task: a waiting customer's (their own worn gear or the piece they brought) or
## one of the smith's own worn pieces in the stores (target = its uid).
static func repair_item(t: Dictionary) -> Dictionary:
	var tg: Variant = t.get("target", "")
	if tg is String and str(tg) != "" and not str(tg).is_valid_int():
		var c := _customer_repair(str(tg))
		if c.is_empty():
			return {}
		if c.has("own_slot"):
			return Adv.get_a(str(tg)).get("equipment", {}).get(str(c["own_slot"]), {})
		return c.get("item", {})
	return Game.find_uid(int(str(tg)))


## The smith's own worn equipment in the stores (repair candidates).
static func worn_in_stores() -> Array:
	var out := []
	for it in Game.inventory():
		if Items.is_equipment(it) and (it.get("broken", false) or Items.durability_frac(it) < 0.75):
			out.append(it)
	return out


## Customers at the counter who want something mended (repair candidates).
static func repair_customers() -> Array:
	return Shop.waiting().filter(func(c): return str(c.get("want", "")) == "repair")


## The recipe an apprentice would use for a commission: the easiest recipe they can make (and the smith has
## unlocked) whose piece should meet the order at their expected craftsmanship. "" = none.
static func commission_recipe(o: Dictionary, app: Dictionary) -> String:
	if o.is_empty():
		return ""
	var best := ""
	var best_d := 999
	var best_margin := -999.0
	var ids := DB.recipes.keys()
	ids.sort()
	for rid_v in ids:
		var rid := str(rid_v)
		var r := DB.recipe(rid)
		var out := str(r.get("output", ""))
		if o.has("def"):
			if out != str(o["def"]):
				continue
		elif str(DB.item(out).get("slot", "")) != str(o.get("slot", "")):
			continue
		if not app.is_empty() and can_make(app, rid) != "":
			continue
		if Crafting.recipe_locked_reason(rid) != "":
			continue
		var margin := 0.0
		if not o.has("def"):
			if Items.tier({"def": out}) < int(o.get("tier", 1)):
				continue
			var q := expected_quality(app, rid) if not app.is_empty() else 80.0
			var est := Crafting.compute_stats(DB.item(out), q, {}, r.get("dice", {}), Crafting.material(rid), level(app, Crafting.recipe_skill(rid)) if not app.is_empty() else 0)
			margin = float(est.get(str(o.get("stat", "")), 0)) - float(o.get("min", 0))
			if margin < 1.0:
				continue
		var d := Crafting.difficulty(rid)
		if d < best_d or (d == best_d and margin > best_margin):
			best = rid
			best_d = d
			best_margin = margin
	return best


## Queues a task. kind: repair | commission | craft | prep | maintain. opts: recipe, repeat, priority (1–3),
## assignee (app id = pinned), order_id (commission), target (repair: npc id or item uid; maintain: station id),
## supervised. Returns the task, or {"error": why}.
static func add_task(kind: String, opts := {}) -> Dictionary:
	if not KINDS.has(kind):
		return {"error": "Unknown kind of work."}
	if not unlocked():
		return {"error": unlock_reason()}
	var s := st()
	var t := {"id": int(s["next_task"]), "kind": kind, "recipe": str(opts.get("recipe", "")), "repeat": maxi(1, int(opts.get("repeat", 1))),
		"done": 0, "priority": clampi(int(opts.get("priority", 2)), 1, 3), "assignee": str(opts.get("assignee", "")),
		"manual": str(opts.get("assignee", "")) != "", "order_id": str(opts.get("order_id", "")), "target": _target(opts.get("target", "")),
		"station": "", "op": 0, "progress": 0.0, "need": 0.0, "taken": {}, "state": "queued", "blocker": "", "made": [],
		"supervised": bool(opts.get("supervised", false)), "worker": "", "started": false, "ops_done": [], "fetch": 0.0,
		"walk": 0.0, "carry": "", "wasted": {}, "added_day": Game.day(), "label": ""}
	match kind:
		"craft", "prep":
			var rid := str(t["recipe"])
			if DB.recipe(rid).is_empty():
				return {"error": "Choose a recipe."}
			if kind == "prep" and Items.is_equipment({"def": str(DB.recipe(rid).get("output", ""))}):
				return {"error": "Preparation is for materials, potions and runes — queue equipment as crafting."}
			var why := Crafting.recipe_locked_reason(rid)
			if why != "" and Property.station_reason(_first_station(rid)) == "":
				return {"error": "You have not learned this yourself: " + why}
			t["label"] = "%s%s" % [DB.recipe(rid).get("name", rid), (" ×%d" % int(t["repeat"])) if int(t["repeat"]) > 1 else ""]
		"commission":
			var o := _order(str(t["order_id"]))
			if o.is_empty() or str(o.get("status", "")) != "open":
				return {"error": "That commission is not open."}
			for x in open_tasks():
				if str(x["kind"]) == "commission" and str(x["order_id"]) == str(t["order_id"]):
					return {"error": "That commission is already in the queue."}
			t["repeat"] = 1
			t["target"] = str(o.get("npc", ""))
			if t["recipe"] != "" and DB.recipe(str(t["recipe"])).is_empty():
				return {"error": "Unknown recipe."}
			t["label"] = "Commission for %s: %s" % [Talk.npc_name(str(o.get("npc", ""))), Shop.order_text(o)]
		"repair":
			t["repeat"] = 1
			for x in open_tasks():
				if str(x["kind"]) == "repair" and str(x["target"]) == str(t["target"]):
					return {"error": "That repair is already in the queue."}
			var it := repair_item(t)
			if it.is_empty():
				return {"error": "Nothing to repair there."}
			var who := str(t["target"])
			t["label"] = "Repair %s%s" % [Items.display_name(it), (" for " + Talk.npc_name(who)) if not who.is_valid_int() else ""]
		"maintain":
			t["repeat"] = 1
			var sid := str(t["target"])
			if DB.station(sid).is_empty():
				return {"error": "Unknown station."}
			for x in open_tasks():
				if str(x["kind"]) == "maintain" and str(x["target"]) == sid:
					return {"error": "That station is already on the upkeep list."}
			t["label"] = "Tend the %s" % _station_name(sid)
		"contract":
			# The Living Realm: hours of work on a major contract at the Project Bench (or its stations); the
			# hardest recipe of the order decides who is qualified; each repeat is one hour of the order.
			var cid := str(t["target"])
			var c := Contracts.get_c(cid)
			if c.is_empty() or str(c.get("status", "")) != "active":
				return {"error": "That contract is not in hand."}
			for x in open_tasks():
				if str(x["kind"]) == "contract" and str(x["target"]) == cid and str(x["assignee"]) == str(t["assignee"]) and t["manual"]:
					return {"error": "%s already works on that order." % get_a(str(t["assignee"])).get("name", "")}
			t["recipe"] = Contracts.main_recipe(cid)
			var short := str(c.get("title", ""))
			if short.length() > 30:
				short = short.left(29).strip_edges() + "…"   # short: long labels wrap and vanish in the ledger rows
			t["label"] = "Contract: %s (%d h)" % [short, int(t["repeat"])]
	if t["manual"]:
		var a := get_a(str(t["assignee"]))
		var why2 := eligible(a, t)
		if why2 != "":
			return {"error": why2}
	s["next_task"] = int(s["next_task"]) + 1
	tasks().append(t)
	_prune_finished()
	_changed()
	return t


## Task targets are kept as strings: an npc id, a station id, or an item uid written as an integer.
static func _target(v: Variant) -> String:
	if v is int or v is float:
		return str(int(v))
	return str(v)


static func _prune_finished() -> void:
	var fin := tasks().filter(func(t): return str(t["state"]) in FINISHED)
	while fin.size() > KEEP_FINISHED:
		tasks().erase(fin.pop_front())


## Cancels a task: anything taken from the stores goes back (minus documented mistake waste). "" or why not.
static func cancel_task(id: int) -> String:
	var t := task(id)
	if t.is_empty():
		return "No such task."
	if str(t["state"]) in FINISHED:
		return "That work is already finished."
	_return_taken(t)
	var a := get_a(str(t.get("worker", "")))
	if not a.is_empty():
		a["task"] = -1
		a["activity"] = ""
	t["worker"] = ""
	t["station"] = ""
	t["state"] = "cancelled"
	t["blocker"] = ""
	_changed()
	return ""


static func set_priority(id: int, p: int) -> void:
	var t := task(id)
	if not t.is_empty():
		t["priority"] = clampi(p, 1, 3)
		_changed()


## Pins a task to an apprentice ("" = automatic assignment). "" or why not.
static func assign(task_id: int, app_id: String) -> String:
	var t := task(task_id)
	if t.is_empty() or str(t["state"]) in FINISHED:
		return "No such open task."
	if app_id != "":
		var a := get_a(app_id)
		var why := eligible(a, t)
		if why != "":
			return why
	var w := str(t.get("worker", ""))
	if w != "" and w != app_id:
		if str(t.get("station", "")) != "" and float(t.get("progress", 0.0)) > 0.0:
			return "%s is in the middle of a step — wait for it to finish." % get_a(w).get("name", "")
		var wa := get_a(w)
		if not wa.is_empty():
			wa["task"] = -1
		t["worker"] = ""   # the materials stay with the task; the new hand carries on
	t["assignee"] = app_id
	t["manual"] = app_id != ""
	_changed()
	return ""


static func set_auto(on: bool) -> void:
	st()["auto"] = on
	_changed()


static func _return_taken(t: Dictionary) -> void:
	var tk: Dictionary = t.get("taken", {})
	var ks := tk.keys()
	ks.sort()
	for d in ks:
		var n := int(tk[d])
		if n > 0:
			Game.add_item(Items.make(str(d), {"qty": n}), false)
	t["taken"] = {}


static func _reset_iteration(t: Dictionary) -> void:
	t["started"] = false
	t["op"] = 0
	t["progress"] = 0.0
	t["need"] = 0.0
	t["ops_done"] = []
	t["station"] = ""
	t["fetch"] = 0.0
	t["walk"] = 0.0
	t["carry"] = ""
	t.erase("redo")


static func _station_name(sid: String) -> String:
	return str(DB.station(sid).get("name", sid.replace("_", " ").capitalize())).to_lower()


static func _first_station(rid: String) -> String:
	var ops := Crafting.operations(rid)
	return str(ops[0].get("station", "")) if not ops.is_empty() else ""


## The operations of a task's current piece.
static func task_ops(t: Dictionary, app := {}) -> Array:
	match str(t.get("kind", "")):
		"repair":
			var it := repair_item(t)
			return [{"station": str(_c("time", "repair_station", "grinding_wheel")), "op": "Mend the %s" % str(it.get("name", "piece")).to_lower(), "checks": 1, "weight": 1.0}]
		"maintain":
			return [{"station": str(t.get("target", "")), "op": "Clean, oil and true the %s" % _station_name(str(t.get("target", ""))), "checks": 1, "weight": 1.0}]
		"contract":
			var sid := str(t.get("station", ""))
			if sid == "":
				sid = Contracts.work_station(str(t.get("target", "")), str(t.get("worker", "")))
			return [{"station": sid, "op": "Work an hour on the contract", "checks": 1, "weight": 1.0}]
	var rid := _recipe_of(t, app)
	return Crafting.operations(rid) if rid != "" else []


static func _recipe_of(t: Dictionary, app := {}) -> String:
	if str(t.get("recipe", "")) != "":
		return str(t["recipe"])
	if str(t.get("kind", "")) == "commission":
		return commission_recipe(_order(str(t.get("order_id", ""))), app)
	return ""


# ======================================================================= stations
static func station_condition(sid: String) -> float:
	return float(st()["stations"].get(sid, {}).get("condition", 100.0))


static func _wear(sid: String, amount: float) -> void:
	var s: Dictionary = st()["stations"]
	if not s.has(sid):
		s[sid] = {"condition": 100.0, "uses": 0}
	s[sid]["condition"] = clampf(float(s[sid]["condition"]) - amount, 0.0, 100.0)
	s[sid]["uses"] = int(s[sid].get("uses", 0)) + 1


static func is_worn(sid: String) -> bool:
	return station_condition(sid) < float(_c("wear", "worn", 45.0))


## Who is at a station right now: "smith" (his current craft operation is there — he always has priority; an
## apprentice steps aside and waits), an apprentice id, or "".
static func station_user(sid: String) -> String:
	if Crafting.active() and Crafting.current_station() == sid:
		return "smith"
	for t in tasks():
		if str(t.get("state", "")) == "working" and str(t.get("station", "")) == sid and str(t.get("worker", "")) != "":
			return str(t["worker"])
	return ""


## "not_installed", "locked", "busy", "worn" or "free".
static func station_state(sid: String) -> String:
	if not Property.is_installed(sid):
		return "not_installed"
	if Crafting.station_locked_reason(sid) != "":
		return "locked"
	if station_user(sid) != "":
		return "busy"
	if is_worn(sid):
		return "worn"
	return "free"


# ======================================================================= simulation: shift
static func _phase() -> String:
	var sh: Dictionary = cfg("shift")
	var h := Game.hour()
	if h < int(sh.get("start", 8)) or h >= int(sh.get("end", 18)):
		return "off"
	if h >= int(sh.get("break_start", 12)) and h < int(sh.get("break_end", 13)):
		return "break"
	return "working"


static func on_shift(app: Dictionary) -> bool:
	return str(app.get("status", "")) == "working"


## Called every 5 game minutes from Game.advance_minutes (and by tests): statuses, assignment, work.
static func tick(minutes: int) -> void:
	if Game.state.is_empty() or not Game.state.has("apprentices"):
		return
	var s := st()
	if (s["staff"] as Array).is_empty():
		return
	var ph := _phase()
	var changed := false
	for a in s["staff"]:
		if str(a["status"]) != ph:
			a["status"] = ph
			changed = true
	if ph != "working":
		# off duty or at the midday break: nobody holds a station (the work waits where it is)
		for a in s["staff"]:
			var t := task(int(a.get("task", -1)))
			if not t.is_empty():
				t["station"] = ""
			a["activity"] = "On the midday break" if ph == "break" else "Gone home for the day"
		if changed:
			_changed()
		return
	_assign()
	for a in (s["staff"] as Array).duplicate():
		if _work(a, float(minutes)):
			changed = true
	if changed:
		_changed()


static func on_hour(_h: int) -> void:
	if not Game.state.has("apprentices"):
		return
	_assign()


## Daily: wages, loyalty, upkeep tasks, independence, weekly applicants, former apprentices' trade.
static func on_day() -> void:
	if Game.state.is_empty():
		return
	var s := st()
	if Game.day() % 7 == 1 and unlocked():
		refresh_applicants()
	if (s["staff"] as Array).is_empty():
		return
	_pay_wages()
	_upkeep_tasks()
	_independence()
	_changed()


static func _pay_wages() -> void:
	var total := 0
	for a in staff():
		total += int(a["wage"])
	total = int(round(total * float(Expeditions.diff().get("wages", 1.0))))
	var lo: Dictionary = cfg("loyalty")
	if total <= 0:
		return
	if Game.can_afford(total):
		Game.add_gold(-total, "wages", "Apprentice wages", "apprentices")
		for a in staff():
			a["loyalty"] = clampf(float(a["loyalty"]) + float(lo.get("paid", 0.5)), 0.0, 100.0)
			a["unpaid_days"] = 0
			if str(a.get("notice", {}).get("kind", "")) == "leave":
				a["notice"] = {}
				log_line(str(a["id"]), "%s was paid and unpacks their tools again." % a["name"])
		return
	for a in staff().duplicate():
		a["unpaid_days"] = int(a.get("unpaid_days", 0)) + 1
		a["loyalty"] = clampf(float(a["loyalty"]) + float(lo.get("unpaid", -12.0)) * (1.0 + maxf(0.0, -_trait_sum(a, "loyalty")) / 20.0), 0.0, 100.0)
		var nt: Dictionary = a.get("notice", {})
		if str(nt.get("kind", "")) == "leave":
			if Game.day() >= int(nt.get("due", 0)):
				var line := _pick_line("left_unpaid", str(a["id"])) % a["name"]
				log_line(str(a["id"]), line)
				Events.toast.emit(line, "bad")
				Game.journal(line)
				_leave(a, "unpaid")
		elif float(a["loyalty"]) < float(lo.get("leave_below", 15.0)) and nt.is_empty():
			var days := int(lo.get("notice_days", 3))
			a["notice"] = {"kind": "leave", "day": Game.day(), "due": Game.day() + days}
			var line2 := _pick_line("leave_notice", str(a["id"])) % [a["name"], days]
			log_line(str(a["id"]), line2)
			Events.toast.emit(line2, "bad")
			Game.journal(line2)


static func _upkeep_tasks() -> void:
	if not bool(st()["auto"]):
		return
	var ks: Array = (st()["stations"] as Dictionary).keys()
	ks.sort()
	for sid in ks:
		if is_worn(str(sid)) and Property.is_installed(str(sid)):
			var exists := open_tasks().any(func(t): return str(t["kind"]) == "maintain" and str(t["target"]) == str(sid))
			if not exists:
				add_task("maintain", {"target": str(sid), "priority": 1})


# ======================================================================= simulation: assignment
## Why a task cannot start (or continue) right now, regardless of who does it. "" = it can.
static func task_problem(t: Dictionary) -> String:
	match str(t["kind"]):
		"repair":
			if repair_item(t).is_empty():
				return "The piece is no longer here."
		"maintain":
			if not Property.is_installed(str(t["target"])):
				return "The %s is not installed." % _station_name(str(t["target"]))
			if station_condition(str(t["target"])) >= 99.5 and not bool(t.get("started", false)):
				return "The %s is in good order." % _station_name(str(t["target"]))
		"commission":
			var o := _order(str(t["order_id"]))
			if not bool(t.get("started", false)) and (o.is_empty() or str(o.get("status", "")) != "open"):
				return "The commission is no longer open."
		"contract":
			if not bool(t.get("started", false)):
				var cp := Contracts.task_problem(str(t["target"]))
				if cp != "":
					return cp
	if str(t["kind"]) in ["craft", "prep", "commission"] and str(t.get("recipe", "")) != "":
		var rid := str(t["recipe"])
		var why := Crafting.recipe_locked_reason(rid)
		if why != "":
			return why
		if not bool(t.get("started", false)):
			var miss := Crafting.missing_inputs(rid)
			if not miss.is_empty():
				return "Missing materials: " + _defs_text(miss)
	for o in task_ops(t):
		var sid := str(o.get("station", ""))
		if not Property.is_installed(sid):
			return "The %s is not installed in the workshop." % _station_name(sid)
	return ""


static func _defs_text(m: Dictionary) -> String:
	var parts := PackedStringArray()
	var ks := m.keys()
	ks.sort()
	for d in ks:
		parts.append("%d %s" % [int(m[d]), str(DB.item(str(d)).get("name", d))])
	return ", ".join(parts)


static func _score(app: Dictionary, t: Dictionary) -> float:
	var rid := _recipe_of(t, app)
	var sk := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	var v := float(level(app, sk)) * 10.0 + float(rank_index(app)) * 2.0
	if _specialty_match(app, category(str(t["kind"]), rid)):
		v += 15.0
	if rid != "" and (app.get("prefs", []) as Array).has(str(DB.recipe(rid).get("discipline", ""))):
		v += 5.0
	return v


## Gives idle, on-shift apprentices work: pinned tasks to their apprentice, the rest (when automatic assignment is
## on) to the best eligible idle hand, highest priority first.
static func _assign() -> void:
	if _phase() != "working":
		return
	var q := open_tasks().filter(func(t): return str(t.get("worker", "")) == "")
	q.sort_custom(func(x, y): return int(x["priority"]) > int(y["priority"]) or (int(x["priority"]) == int(y["priority"]) and int(x["id"]) < int(y["id"])))
	# an apprentice the smith has pinned to work that is ready for them is kept for it: automatic assignment
	# never hands them something else first (that left the pinned task waiting behind a lower-priority one)
	var reserved := {}
	for t0 in q:
		if bool(t0.get("manual", false)) and task_problem(t0) == "":
			var a0 := get_a(str(t0["assignee"]))
			if not a0.is_empty() and eligible(a0, t0) == "":
				reserved[str(a0["id"])] = true
	for t in q:
		var prob := task_problem(t)
		if prob != "":
			t["state"] = "blocked"
			t["blocker"] = prob
			continue
		var pick := {}
		var why_not := ""
		if bool(t.get("manual", false)):
			var a := get_a(str(t["assignee"]))
			if a.is_empty():
				t["manual"] = false
				t["assignee"] = ""
			elif int(a.get("task", -1)) == -1 and on_shift(a):
				why_not = eligible(a, t)
				if why_not == "":
					pick = a
			else:
				why_not = "Waiting for %s." % a["name"]
		if pick.is_empty() and not bool(t.get("manual", false)):
			if not bool(st()["auto"]):
				why_not = "Automatic assignment is off — pick an apprentice."
			else:
				var best := -1.0
				var ids := []
				for a in staff():
					ids.append(str(a["id"]))
				ids.sort()
				for aid in ids:
					var a2 := get_a(str(aid))
					if int(a2.get("task", -1)) != -1 or not on_shift(a2) or reserved.has(str(aid)):
						continue
					var e := eligible(a2, t)
					if e != "":
						why_not = "%s: %s" % [a2["name"], e]
						continue
					var sc := _score(a2, t)
					if sc > best:
						best = sc
						pick = a2
				if pick.is_empty() and why_not == "":
					why_not = "Everyone is busy." if not staff().is_empty() else "No apprentices."
		if pick.is_empty():
			t["blocker"] = why_not
			if str(t["state"]) != "working":
				t["state"] = "queued" if why_not.begins_with("Everyone") or why_not.begins_with("Waiting") else "blocked"
			continue
		t["worker"] = str(pick["id"])
		reserved.erase(str(pick["id"]))
		t["blocker"] = ""
		if str(t["recipe"]) == "" and str(t["kind"]) == "commission":
			t["recipe"] = commission_recipe(_order(str(t["order_id"])), pick)
		pick["task"] = int(t["id"])
		if str(t["state"]) != "working":
			t["state"] = "queued"


# ======================================================================= simulation: work
## One apprentice works `minutes`. Returns true when something visible changed.
static func _work(a: Dictionary, minutes: float) -> bool:
	var t := task(int(a.get("task", -1)))
	if t.is_empty() or str(t["state"]) in FINISHED or str(t.get("worker", "")) != str(a["id"]):
		var was := int(a.get("task", -1)) != -1
		a["task"] = -1
		a["activity"] = "Sweeping the forge floor" if open_tasks().is_empty() else "Looking for work they can do"
		return was
	var changed := false
	# 1. start the piece: take the materials from the stores
	if not bool(t.get("started", false)):
		var prob := task_problem(t)
		if prob != "":
			t["state"] = "blocked"
			t["blocker"] = prob
			t["worker"] = ""
			a["task"] = -1
			return true
		_start_iteration(t, a)
		changed = true
	var ops := task_ops(t, a)
	if ops.is_empty():
		_fail(t, a, "Nothing to work on.")
		return true
	var left := minutes
	# 2. fetching the materials
	if float(t["fetch"]) > 0.0:
		var f := minf(left, float(t["fetch"]))
		t["fetch"] = float(t["fetch"]) - f
		left -= f
		a["activity"] = "Fetching %s from the stock hall" % str(DB.item(str(t.get("carry", ""))).get("name", "materials")).to_lower()
		if left <= 0.0:
			return changed
	var op: Dictionary = ops[mini(int(t["op"]), ops.size() - 1)]
	var sid := str(op.get("station", ""))
	# 3. the station: installed, not locked, and free (the smith always has priority)
	if not Property.is_installed(sid) or Crafting.station_locked_reason(sid) != "":
		t["state"] = "blocked"
		t["station"] = ""
		t["blocker"] = "The %s is not available — %s" % [_station_name(sid), Property.station_reason(sid) if Property.station_reason(sid) != "" else Crafting.station_locked_reason(sid)]
		a["activity"] = "Waiting: the %s is not available" % _station_name(sid)
		return true
	var user := station_user(sid)
	if user != "" and user != str(a["id"]):
		t["station"] = ""
		t["blocker"] = "Waiting for the %s (%s is using it)." % [_station_name(sid), "the smith" if user == "smith" else str(get_a(user).get("name", "someone"))]
		a["activity"] = "Waiting for the %s" % _station_name(sid)
		return changed
	if t["blocker"] != "" or str(t["state"]) != "working":
		changed = true
	t["state"] = "working"
	t["blocker"] = ""
	# 4. walking over
	if float(t["walk"]) > 0.0:
		var w := minf(left, float(t["walk"]))
		t["walk"] = float(t["walk"]) - w
		left -= w
		a["activity"] = "Going to the %s" % _station_name(sid)
		if left <= 0.0:
			return changed
	t["station"] = sid
	if float(t["need"]) <= 0.0:
		t["need"] = op_minutes(a, t, op)
	t["progress"] = float(t["progress"]) + left
	a["activity"] = "%s at the %s" % [str(op.get("op", "Working")), _station_name(sid)]
	if float(t["progress"]) >= float(t["need"]):
		_finish_op(t, a, op)
		changed = true
	return changed


static func _start_iteration(t: Dictionary, a: Dictionary) -> void:
	_reset_iteration(t)
	var rid := _recipe_of(t, a)
	if str(t["kind"]) == "commission" and str(t["recipe"]) == "":
		t["recipe"] = rid
	var taken := {}
	if str(t["kind"]) in ["craft", "prep", "commission"] and rid != "":
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		var ks := inputs.keys()
		ks.sort()
		for d in ks:
			if Game.remove_def(str(d), int(inputs[d])):
				taken[str(d)] = int(inputs[d])
		if not ks.is_empty():
			t["carry"] = str(ks[0])
	elif str(t["kind"]) == "repair":
		t["carry"] = str(repair_item(t).get("def", ""))
	t["taken"] = taken
	t["wasted"] = {}
	t["started"] = true
	t["state"] = "working"
	t["fetch"] = FETCH_MIN if not str(t["kind"]) in ["maintain", "contract"] else 0.0   # the order's crate stands at the bench
	t["walk"] = WALK_MIN
	log_line(str(a["id"]), "%s started: %s." % [a["name"], _task_title(t)])


static func _task_title(t: Dictionary) -> String:
	var lab := str(t.get("label", ""))
	if lab != "":
		return lab
	return str(DB.recipe(str(t.get("recipe", ""))).get("name", t.get("kind", "work")))


## Minutes for one operation by this apprentice (data: time, ranks, traits, specialty, station wear).
static func op_minutes(a: Dictionary, t: Dictionary, op: Dictionary) -> float:
	var tm: Dictionary = cfg("time")
	var base := float(tm.get("op_base", 30.0)) + float(tm.get("per_check", 12.0)) * int(op.get("checks", 1))
	var kind := str(t.get("kind", ""))
	if kind == "repair":
		base = float(tm.get("repair_minutes", 50.0))
	elif kind == "maintain":
		base = maxf(float(tm.get("maintain_min", 15.0)), (100.0 - station_condition(str(t["target"]))) * float(tm.get("maintain_per_point", 0.7)))
	elif kind == "contract":
		base = float(Contracts.cfg("hour_minutes", 60))   # one contract hour, at this hand's pace
	var rid := _recipe_of(t, a)
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	var diff := Crafting.difficulty(rid) if rid != "" else 1
	var f := float(rank_data(str(a["rank"])).get("speed", 0.8))
	f *= 1.0 + float(tm.get("level_speed", 0.04)) * clampi(level(a, skill) - diff, -5, 6)
	f *= _trait_mult(a, "speed")
	if _specialty_match(a, category(kind, rid)):
		f *= float(_c("specialty", "speed", 1.15))
	if kind != "maintain" and is_worn(str(op.get("station", ""))):
		f *= float(_c("wear", "slow", 0.8))
	return maxf(float(tm.get("min_op", 10.0)), base / maxf(0.25, f))


static func _supervised(t: Dictionary, sid: String) -> bool:
	if bool(t.get("supervised", false)):
		return true
	if smith_room == "" or Steward.smith_away():   # the smith is away while the steward runs the workshop
		return false
	var r := Property.room_at_tile(Property.rooms(), Property.pos_of(sid))
	return not r.is_empty() and str(r.get("id", "")) == smith_room


## Expected craftsmanship of one operation for this apprentice and recipe (no variance).
static func expected_op_quality(a: Dictionary, rid: String, sid := "", supervised := false, kind := "craft") -> float:
	var qc: Dictionary = cfg("quality")
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	var diff := Crafting.difficulty(rid) if rid != "" else 1
	var gap := clampi(level(a, skill) - diff, int(qc.get("gap_floor", -6)), int(qc.get("gap_ceiling", 6)))
	var q := float(qc.get("base", 76.0)) + float(qc.get("per_level", 3.5)) * gap
	q += float(rank_data(str(a.get("rank", "novice"))).get("quality", 0.0))
	q += _trait_sum(a, "quality")
	if _specialty_match(a, category(kind, rid)):
		q += float(_c("specialty", "quality", 5.0))
	if supervised:
		q += float(qc.get("supervised", 3.0))
	if sid != "" and is_worn(sid):
		q += float(qc.get("worn_station", -6.0))
	return q


## Expected final craftsmanship of a piece (ops at their expected value, the skill bonus, the rank ceiling).
static func expected_quality(a: Dictionary, rid: String, kind := "craft") -> float:
	var q := expected_op_quality(a, rid, "", false, kind)
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	q += float(_c("quality", "skill_bonus", 0.4)) * level(a, skill)
	return clampf(q, 1.0, _ceiling(a, rid, kind))


static func _ceiling(a: Dictionary, rid: String, kind: String) -> float:
	var c := float(rank_data(str(a.get("rank", "novice"))).get("ceiling", 95.0))
	if _specialty_match(a, category(kind, rid)):
		c += 2.0
	return c


static func _finish_op(t: Dictionary, a: Dictionary, op: Dictionary) -> void:
	var sid := str(op.get("station", ""))
	var rid := _recipe_of(t, a)
	var kind := str(t["kind"])
	var key := "%d|%s|%d|%d" % [int(t["id"]), str(a["id"]), Game.now(), int(t["op"])]
	var rng := _rng(key)
	var qc: Dictionary = cfg("quality")
	var mc: Dictionary = cfg("mistakes")
	var sup := _supervised(t, sid)
	var q := expected_op_quality(a, rid, sid, sup, kind) + rng.randfn(0.0, float(qc.get("sd", 8.0)) * _trait_mult(a, "sd"))
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	var diff := Crafting.difficulty(rid) if rid != "" else 1
	var chance := (float(mc.get("chance", 0.07)) + float(mc.get("per_gap", 0.02)) * maxi(0, diff - level(a, skill))) * _trait_mult(a, "mistake")
	var note := ""
	if rng.randf() < chance:
		var kinds: Array = mc.get("kinds", ["rough", "waste", "time"])
		var mk := str(kinds[rng.randi_range(0, kinds.size() - 1)])
		if mk == "time" and t.has("redo"):
			mk = "rough"
		if mk == "waste" and not (t.get("wasted", {}) as Dictionary).is_empty():
			mk = "rough"   # at most one unit is ever lost on a piece
		if mk == "waste":
			var cheap := _cheap_input(t)
			if cheap == "":
				mk = "rough"
			else:
				# one unit of a cheap input is spoiled; another is fetched from the stores if there is one
				t["taken"][cheap] = int(t["taken"][cheap]) - 1
				t["wasted"][cheap] = int(t["wasted"].get(cheap, 0)) + 1
				if Game.remove_def(cheap, 1):
					t["taken"][cheap] = int(t["taken"][cheap]) + 1
				else:
					q += float(mc.get("rough", -22.0)) * 0.5
				note = _pick_line("waste", key) % [a["name"], str(DB.item(cheap).get("name", cheap)).to_lower()]
		if mk == "time":
			t["redo"] = true
			t["progress"] = float(t["need"]) * (1.0 - float(mc.get("time", 0.25)))
			var line := _pick_line("time", key) % [a["name"], _station_name(sid)]
			a["mistakes"] = int(a["mistakes"]) + 1
			log_line(str(a["id"]), line)
			return
		if mk == "rough":
			q += float(mc.get("rough", -22.0))
			note = _pick_line("rough", key) % [a["name"], str(DB.item(str(DB.recipe(rid).get("output", ""))).get("name", "work")).to_lower() if rid != "" else _station_name(sid)]
		a["mistakes"] = int(a["mistakes"]) + 1
		log_line(str(a["id"]), note)
	elif rng.randf() < float(_c("surprise", "chance", 0.04)) * _trait_mult(a, "surprise"):
		var b: Array = _c("surprise", "bonus", [6.0, 12.0])
		q += rng.randf_range(float(b[0]), float(b[1]))
		a["surprises"] = int(a["surprises"]) + 1
		t["surprise"] = true
		var line2 := _pick_line("surprise", key) % [a["name"], str(DB.item(str(DB.recipe(rid).get("output", ""))).get("name", "work")).to_lower() if rid != "" else "work"]
		log_line(str(a["id"]), line2)
	q = clampf(q, float(qc.get("floor", 10.0)), float(qc.get("op_cap", 118.0)))
	(t["ops_done"] as Array).append({"op": str(op.get("op", "")), "station": sid, "q": q, "checks": [q], "w": float(op.get("weight", 1.0)),
		"by": str(a["id"]), "supervised": sup})
	if sup:
		t["was_supervised"] = true
	if kind != "maintain":
		_wear(sid, float(_c("wear", "per_op", 2.5)))
	add_xp(a, skill, float(_c("xp", "per_op", 2)))
	t["op"] = int(t["op"]) + 1
	t["progress"] = 0.0
	t["need"] = 0.0
	t["station"] = ""
	t["walk"] = WALK_MIN
	t.erase("redo")
	if int(t["op"]) >= task_ops(t, a).size():
		_complete(t, a)


static func _cheap_input(t: Dictionary) -> String:
	var lim := int(_c("mistakes", "cheap_value", 12))
	var best := ""
	var bv := 1 << 30
	var ks: Array = (t.get("taken", {}) as Dictionary).keys()
	ks.sort()
	for d in ks:
		var v := int(DB.item(str(d)).get("value", 999))
		if int(t["taken"][d]) > 0 and v <= lim and v < bv:
			best = str(d)
			bv = v
	return best


static func _piece_quality(t: Dictionary, a: Dictionary, rid: String) -> float:
	var tot := 0.0
	var w := 0.0
	for o in t["ops_done"]:
		tot += float(o["q"]) * float(o["w"])
		w += float(o["w"])
	var q := tot / w if w > 0.0 else 50.0
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	q += float(_c("quality", "skill_bonus", 0.4)) * level(a, skill)
	return clampf(q, 1.0, _ceiling(a, rid, str(t["kind"])))


## Rolls a recipe's dice for an apprentice's piece, weighted by craftsmanship exactly like Crafting.roll_weighted
## (stat dice roll 1–3 times and keep the best/worst; fortune and purity once) — but from a seeded generator.
static func roll_dice(spec: Dictionary, q: float, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var ks := spec.keys()
	ks.sort()
	for k in ks:
		var expr := str(spec[k])
		var weighted := Crafting.is_stat_die(str(k))
		var adv := Crafting.advantage(q) if weighted else {"tier": 0, "word": "even odds", "rolls": 1}
		var p := Dice.parse(expr)
		var rolls := []
		var kept := 0
		for i in int(adv["rolls"]):
			var faces := []
			var total := int(p["mod"])
			for n in int(p["n"]):
				var f := rng.randi_range(1, int(p["sides"]))
				faces.append(f)
				total += f
			rolls.append({"total": total, "faces": faces})
			if i > 0:
				var better: bool = total > int(rolls[kept]["total"])
				var worse: bool = total < int(rolls[kept]["total"])
				if (int(adv["tier"]) > 0 and better) or (int(adv["tier"]) < 0 and worse):
					kept = i
		out[k] = {"total": int(rolls[kept]["total"]), "faces": rolls[kept]["faces"], "rolls": rolls, "kept": kept}
	return out


static func _complete(t: Dictionary, a: Dictionary) -> void:
	var kind := str(t["kind"])
	var rid := _recipe_of(t, a)
	var q := _piece_quality(t, a, rid)
	t["last_quality"] = q
	var sup := bool(t.get("was_supervised", false))
	var rng := _rng("%d|%s|%d|dice" % [int(t["id"]), str(a["id"]), Game.now()])
	var cat := category(kind, rid)
	var xpc: Dictionary = cfg("xp")
	match kind:
		"repair":
			var it := repair_item(t)
			var tg := str(t["target"])
			if it.is_empty():
				_fail(t, a, "The piece was gone before the repair was finished.")
				return
			if not tg.is_valid_int():
				Shop.do_repair(tg, q, str(a["name"]))
				remember(a, "Mended %s's %s (%d%%)." % [Talk.npc_name(tg), str(it.get("name", "piece")), int(round(q))], int(it.get("uid", -1)))
			else:
				var stt: Dictionary = it.get("stats", {})
				if stt.has("durability_max"):
					stt["durability"] = maxi(int(stt.get("durability", 0)), int(float(stt["durability_max"]) * clampf(0.55 + q / 250.0, 0.5, 1.0)))
				it.erase("broken")
				Provenance.workshop(it, "repaired", "Repaired at the Ironhand forge by %s, %s (%d%%)." % [a["name"], rank_name(a).to_lower(), int(round(q))])
				Events.inventory_changed.emit()
			add_xp(a, "smithing", float(xpc.get("repair", 10)))
			log_line(str(a["id"]), "%s finished the repair: %s (%d%%)." % [a["name"], str(it.get("name", "piece")), int(round(q))])
		"maintain":
			var sid := str(t["target"])
			var s: Dictionary = st()["stations"]
			if not s.has(sid):
				s[sid] = {"condition": 100.0, "uses": 0}
			s[sid]["condition"] = clampf(maxf(float(s[sid]["condition"]), 60.0 + q * 0.4), 0.0, 100.0)
			add_xp(a, "smithing", float(xpc.get("maintain", 4)))
			log_line(str(a["id"]), "%s tended the %s (now %d%%)." % [a["name"], _station_name(sid), int(round(float(s[sid]["condition"])))])
		"contract":
			var cid := str(t["target"])
			var used := Contracts.apprentice_hour(cid, a, q)
			add_xp(a, Crafting.recipe_skill(rid) if rid != "" else "smithing", float(xpc.get("contract_hour", 5)) * (0.6 + q / 200.0))
			if used <= 0.0:
				t["blocker"] = Contracts.task_problem(cid)   # stalled (materials): the task waits, blocked, until they come
			if Contracts.finished_for_apprentices(cid):
				t["repeat"] = int(t["done"]) + 1   # the order is complete: this hand stops here
		_:
			var r := DB.recipe(rid)
			var maker := {"id": str(a["id"]), "name": str(a["name"]), "mark": str(a["mark"]["id"]), "level": level(a, Crafting.recipe_skill(rid)),
				"supervised": sup, "rank": str(a["rank"]), "rank_name": rank_name(a)}
			var dice := roll_dice(r.get("dice", {}), q, rng)
			t["taken"] = {}   # the materials became the piece
			var it2 := Crafting.build(rid, t["ops_done"], q, dice, "digital", maker)
			if it2.is_empty():
				_fail(t, a, "The work could not be finished.")
				return
			(t["made"] as Array).append(int(it2["uid"]))
			if Items.is_equipment(it2):
				(a["creations"] as Array).append(int(it2["uid"]))
			var skill := Crafting.recipe_skill(rid)
			var gap := level(a, skill) - Crafting.difficulty(rid)
			var amt := 0.0
			for sk in r.get("xp", {}):
				if _skill_ids().has(str(sk)):
					amt = maxf(amt, float(r["xp"][sk]))
			amt = maxf(amt, 8.0) * float(xpc.get("mult", 1.0)) * (0.6 + q / 200.0)
			if gap >= int(xpc.get("routine_gap", 4)):
				amt *= float(xpc.get("routine_mult", 0.35))
			elif gap < 0:
				amt *= float(xpc.get("hard_mult", 1.4))
			if _specialty_match(a, cat):
				amt *= float(_c("specialty", "xp", 1.1))
			add_xp(a, skill, amt)
			var nm := Items.display_name(it2)
			log_line(str(a["id"]), "%s finished %s (%d%%%s)." % [a["name"], nm, int(round(q)), (", " + str(it2.get("rarity", ""))) if str(it2.get("rarity", "common")) != "common" else ""])
			if q >= 100.0 or str(it2.get("rarity", "common")) != "common" or bool(t.get("surprise", false)):
				remember(a, "Made %s on day %d — %d%% craftsmanship%s." % [nm, Game.day(), int(round(q)), (", " + str(it2.get("rarity", ""))) if str(it2.get("rarity", "common")) != "common" else ""], int(it2["uid"]))
			if kind == "commission":
				var o := _order(str(t["order_id"]))
				if not o.is_empty() and str(o.get("status", "")) == "open" and Shop.item_meets(o, it2):
					it2["for_order"] = str(o["id"])
					remember(a, "Made %s for %s's commission." % [nm, Talk.npc_name(str(o.get("npc", "")))], int(it2["uid"]))
					Events.toast.emit("%s finished %s for %s's commission — deliver it at the counter." % [a["name"], nm, Talk.npc_name(str(o.get("npc", "")))], "good")
				elif not o.is_empty():
					t["blocker"] = "The piece did not meet the commission (%s); it went to the stores." % Shop.order_text(o)
					log_line(str(a["id"]), "%s's %s did not meet %s's commission — it went to the stores." % [a["name"], nm, Talk.npc_name(str(o.get("npc", "")))])
	if kind != "contract":   # an hour on a major order is not a finished work of their own
		a["works"] = int(a["works"]) + 1
		var cc: Dictionary = a["cat_counts"]
		if cat != "":
			cc[cat] = int(cc.get(cat, 0)) + 1
	a["loyalty"] = clampf(float(a["loyalty"]) + float(_c("loyalty", "work_day", 0.2)), 0.0, 100.0)
	_check_rank(a)
	_check_specialty(a)
	t["done"] = int(t["done"]) + 1
	_reset_iteration(t)
	t["taken"] = {}
	t.erase("was_supervised")
	t.erase("surprise")
	if int(t["done"]) >= int(t["repeat"]) or kind in ["repair", "maintain", "commission"]:
		t["state"] = "done" if t.get("blocker", "") == "" or kind != "commission" else "failed"
		if str(t["state"]) == "done":
			t["blocker"] = ""
		t["worker"] = ""
		a["task"] = -1
	else:
		t["state"] = "queued"   # the same hand carries on with the next piece (materials permitting)


static func _fail(t: Dictionary, a: Dictionary, why: String) -> void:
	_return_taken(t)
	_reset_iteration(t)
	t["state"] = "failed"
	t["blocker"] = why
	t["worker"] = ""
	a["task"] = -1
	log_line(str(a["id"]), "%s: %s" % [a["name"], why])


# ======================================================================= what the world shows
## {task, station, phase "walking"|"working"|"carrying"|"break"|"off", activity, carrying def}. `station` is where the
## apprentice should stand (the station of the current operation); the world picks the working side of it.
static func current(app: Dictionary) -> Dictionary:
	var out := {"task": -1, "station": "", "phase": "off", "activity": str(app.get("activity", "")), "carrying": ""}
	match str(app.get("status", "")):
		"off", "gone":
			out["activity"] = "Gone home for the day"
			return out
		"break":
			out["phase"] = "break"
			out["activity"] = "On the midday break"
			return out
	var t := task(int(app.get("task", -1)))
	out["phase"] = "walking"
	if t.is_empty():
		return out
	out["task"] = int(t["id"])
	if float(t.get("fetch", 0.0)) > 0.0:
		out["phase"] = "carrying"
		out["carrying"] = str(t.get("carry", ""))
		out["station"] = ""
		return out
	var ops := task_ops(t, app)
	if not ops.is_empty():
		out["station"] = str(ops[mini(int(t.get("op", 0)), ops.size() - 1)].get("station", ""))
	if str(t.get("station", "")) != "" and float(t.get("walk", 0.0)) <= 0.0:
		out["phase"] = "working"
	return out


## Estimate for a task (by `app`, or its worker, or the best eligible hand): {minutes (for what is left), quality,
## cost (materials' value), wage_cost, materials {def: n} still to take, missing {def: n}, station, app}.
static func estimate(t: Dictionary, app := {}) -> Dictionary:
	if app.is_empty():
		app = get_a(str(t.get("worker", "")))
	if app.is_empty() and str(t.get("assignee", "")) != "":
		app = get_a(str(t["assignee"]))
	if app.is_empty():
		var best := -1.0
		for a in staff():
			if eligible(a, t) == "" and _score(a, t) > best:
				best = _score(a, t)
				app = a
	var out := {"minutes": 0, "quality": 0.0, "cost": 0, "wage_cost": 0, "materials": {}, "missing": {}, "station": "", "app": str(app.get("id", ""))}
	var rid := _recipe_of(t, app)
	var ops := task_ops(t, app)
	if not ops.is_empty():
		out["station"] = str(ops[mini(int(t.get("op", 0)), ops.size() - 1)].get("station", ""))
	var left := maxi(0, int(t.get("repeat", 1)) - int(t.get("done", 0)))
	var started := bool(t.get("started", false))
	if not app.is_empty():
		var per := 0.0
		for o in ops:
			per += op_minutes(app, t, o) + WALK_MIN
		per += FETCH_MIN
		var mins := per * left
		if started:
			var done_part := 0.0
			for i in mini(int(t.get("op", 0)), ops.size()):
				done_part += op_minutes(app, t, ops[i]) + WALK_MIN
			mins -= done_part + float(t.get("progress", 0.0)) + FETCH_MIN - float(t.get("fetch", 0.0))
		out["minutes"] = int(round(maxf(0.0, mins)))
		out["quality"] = expected_quality(app, rid, str(t.get("kind", ""))) if rid != "" else expected_op_quality(app, "", "", false, str(t.get("kind", "")))
		var shift := float(int(_c("shift", "end", 18)) - int(_c("shift", "start", 8)) - 1) * 60.0
		out["wage_cost"] = int(ceil(float(app.get("wage", 0)) * float(out["minutes"]) / maxf(60.0, shift)))
	if rid != "" and str(t.get("kind", "")) in ["craft", "prep", "commission"]:
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		var need_n := left - (1 if started else 0)
		var mats := {}
		var miss := {}
		var cost := 0
		for d in inputs:
			var n := int(inputs[d]) * need_n
			if n <= 0:
				continue
			mats[d] = n
			cost += int(DB.item(str(d)).get("value", 0)) * n
			if Game.count(str(d)) < n:
				miss[d] = n - Game.count(str(d))
		out["materials"] = mats
		out["missing"] = miss
		out["cost"] = cost
	return out


## Short sentences on what holds the workshop back right now.
static func bottlenecks() -> Array[String]:
	var out: Array[String] = []
	if staff().is_empty():
		if unlocked():
			out.append("No apprentices yet — take one on at the notice board.")
		return out
	var waits := {}
	for t in open_tasks():
		var b := str(t.get("blocker", ""))
		if b == "":
			continue
		if b.begins_with("Waiting for the "):
			var sname := b.substr(16).split(" (")[0]
			waits[sname] = int(waits.get(sname, 0)) + 1
			continue
		var line := "%s — %s" % [_task_title(t), b]
		if not out.has(line):
			out.append(line)
	for sname in waits:
		out.append("%d task%s waiting for the %s." % [int(waits[sname]), "" if int(waits[sname]) == 1 else "s", sname])
	var ks: Array = (st()["stations"] as Dictionary).keys()
	ks.sort()
	for sid in ks:
		if is_worn(str(sid)) and Property.is_installed(str(sid)):
			out.append("The %s is worn (%d%%) — apprentices work slower and rougher there." % [_station_name(str(sid)), int(round(station_condition(str(sid))))])
	var idle := staff().filter(func(a): return on_shift(a) and int(a.get("task", -1)) == -1)
	if not idle.is_empty() and open_tasks().filter(func(t): return str(t.get("worker", "")) == "").is_empty():
		out.append("%s %s nothing to do — queue some work." % [", ".join(PackedStringArray(idle.map(func(a): return str(a["name"])))), "has" if idle.size() == 1 else "have"])
	for a in staff():
		if str(a.get("notice", {}).get("kind", "")) == "leave":
			out.append("%s has not been paid and will leave on day %d." % [a["name"], int(a["notice"].get("due", 0))])
	return out


# ======================================================================= mentoring
## An hour at the apprentice's side (once a day, while they are at the forge): experience and loyalty.
static func mentor(app_id: String) -> String:
	var a := get_a(app_id)
	if a.is_empty():
		return "No such apprentice."
	if str(a.get("status", "")) == "off":
		return "%s has gone home for the day." % a["name"]
	if int(a.get("mentored_day", -1)) == Game.day():
		return "You have already spent time with %s today." % a["name"]
	var m: Dictionary = cfg("mentor")
	a["mentored_day"] = Game.day()
	var t := task(int(a.get("task", -1)))
	var rid := _recipe_of(t, a) if not t.is_empty() else ""
	var skill := Crafting.recipe_skill(rid) if rid != "" else best_skill(a)
	var cur := current(a)
	var where := str(cur.get("station", ""))
	if where == "":
		where = "anvil"
	add_xp(a, skill, float(m.get("xp", 45)) * _trait_mult(a, "mentor"))
	a["loyalty"] = clampf(float(a["loyalty"]) + float(m.get("loyalty", 4.0)), 0.0, 100.0)
	if not t.is_empty():
		t["supervised"] = true
	var line := _pick_line("mentor", "%s|mentor|%d" % [app_id, Game.day()])
	line = line % [a["name"], _station_name(where)] if line.count("%s") == 2 else line % a["name"]
	log_line(app_id, line)
	remember(a, "The smith taught me at the %s on day %d." % [_station_name(where), Game.day()])
	Game.advance_minutes(int(m.get("minutes", 60)))
	_check_rank(a)
	_changed()
	return ""


# ======================================================================= marks, reunions, fame
## The mark of an apprentice or former apprentice (by maker id or mark id): {id, name, desc, initials, maker,
## apprentice true, alumni bool} — {} when unknown.
static func mark_info(maker_id: String) -> Dictionary:
	if maker_id == "" or Game.state.is_empty() or not Game.state.has("apprentices"):
		return {}
	for pool in [staff(), alumni()]:
		for a in pool:
			var mk: Dictionary = a.get("mark", {})
			if str(a.get("id", "")) == maker_id or str(mk.get("id", "")) == maker_id:
				var out := mk.duplicate()
				out["maker"] = str(a.get("name", ""))
				out["apprentice"] = true
				out["alumni"] = pool == alumni()
				return out
	return {}


## ItemStory.recognise: a returning piece made by an apprentice who is on shift — they know it at once.
## Called once per reunion occasion (ItemStory keeps the bookkeeping).
static func on_reunion(it: Dictionary, occasion: String, who: String) -> void:
	if Game.state.is_empty() or not Game.state.has("apprentices"):
		return
	var aid := str(Provenance.maker(it).get("id", ""))
	var a := get_a(aid)
	if a.is_empty() or not on_shift(a):
		return
	var day := int(Provenance.maker(it).get("day", Game.day()))
	var line := _pick_line("recognise", "%s|%d|%s" % [aid, int(it.get("uid", -1)), occasion]) % [a["name"], str(it.get("base_name", it.get("name", "piece"))).to_lower(), day]
	remember(a, "Recognised my %s when it came back (%s%s)." % [Items.display_name(it), occasion, (", " + Talk.npc_name(who)) if who != "" else ""], int(it.get("uid", -1)))
	log_line(aid, line)
	Events.toast.emit(line, "good")
	_changed()


## An apprentice's notable pieces: [{uid, name, item, quality, rarity, epic, named, hall}] best first.
static func famous_works(app: Dictionary) -> Array:
	var out := []
	for u in app.get("creations", []):
		var it := ItemStory.find(int(u))
		if it.is_empty() or bool(it.get("dev", false)):
			continue
		var hall := Recognition.has_key("craft_%d" % int(u)) or Recognition.has_key("epic_%d" % int(u))
		var notable := Provenance.is_notable(it) or it.has("epic") or ItemStory.is_named(it) or hall or str(it.get("rarity", "common")) in ["rare", "legendary"]
		if notable:
			out.append({"uid": int(u), "name": Items.display_name(it), "item": it, "quality": float(it.get("quality", 0.0)),
				"rarity": str(it.get("rarity", "common")), "epic": it.has("epic"), "named": ItemStory.is_named(it), "hall": hall})
	out.sort_custom(func(x, y): return float(x["quality"]) > float(y["quality"]))
	return out


# ======================================================================= independence
static func _independence() -> void:
	var ic: Dictionary = cfg("independence")
	# notices that fell due without an answer: they go, on good terms
	for a in staff().duplicate():
		var nt: Dictionary = a.get("notice", {})
		if str(nt.get("kind", "")) == "independence" and Game.day() >= int(nt.get("due", 0)):
			_bless(a)
	for a in staff():
		if not (a.get("notice", {}) as Dictionary).is_empty():
			return   # never more than one notice at a time
	for a in staff():
		if str(a["rank"]) != "master" or float(a["loyalty"]) < float(ic.get("loyalty", 75.0)) or int(a["works"]) < int(ic.get("works", 60)):
			continue
		if Game.day() - int(a["hired_day"]) < int(ic.get("min_days", 60)) or Game.day() < int(a.get("no_ask_until", 0)):
			continue
		if _rng("%s|indep|%d" % [a["id"], Game.day()]).randf() < float(ic.get("chance", 0.08)):
			give_notice(a)
			return


## The apprentice asks to open their own workshop in `notice_days` days (notice entry, toast, journal).
static func give_notice(a: Dictionary) -> void:
	var days := int(_c("independence", "notice_days", 7))
	a["notice"] = {"kind": "independence", "day": Game.day(), "due": Game.day() + days}
	var line := _pick_line("independence", str(a["id"])) % [a["name"], days]
	(st()["notices"] as Array).append({"app": str(a["id"]), "kind": "independence", "day": Game.day(), "due": Game.day() + days, "text": line})
	log_line(str(a["id"]), line)
	Events.toast.emit(line, "legendary")
	Game.journal(line)
	_changed()


## Answers an independence notice: "bless" (they leave on good terms and become a former apprentice with their own
## workshop) or "stay" (a raise; they will not ask again for a long time). "" or why not.
static func answer_notice(app_id: String, choice: String) -> String:
	var a := get_a(app_id)
	if a.is_empty():
		return "No such apprentice."
	if str(a.get("notice", {}).get("kind", "")) != "independence":
		return "%s has not asked to leave." % a["name"]
	var ic: Dictionary = cfg("independence")
	match choice:
		"bless":
			var t := task(int(a.get("task", -1)))
			if not t.is_empty() and str(t.get("station", "")) != "" and float(t.get("progress", 0.0)) > 0.0:
				# the step in hand is left for another to finish; the materials stay with the task
				t["progress"] = 0.0
			_bless(a)
			return ""
		"stay":
			a["notice"] = {}
			a["wage"] = int(a["wage"]) + int(ic.get("stay_raise", 2))
			a["loyalty"] = clampf(float(a["loyalty"]) + float(ic.get("stay_loyalty", 10.0)), 0.0, 100.0)
			a["no_ask_until"] = Game.day() + int(ic.get("stay_cooldown", 120))
			st()["notices"] = (st()["notices"] as Array).filter(func(n): return str(n.get("app", "")) != app_id)
			var line := _pick_line("stay", app_id) % a["name"]
			log_line(app_id, line)
			remember(a, "Stayed at the Ironhand forge on day %d, with a raise." % Game.day())
			Game.journal(line)
			_changed()
			return ""
	return "Choose bless or stay."


static func _bless(a: Dictionary) -> void:
	var aid := str(a["id"])
	var alum := {"id": aid, "name": str(a["name"]), "look": str(a["look"]), "race": str(a["race"]), "female": bool(a["female"]),
		"personality": str(a["personality"]), "traits": (a["traits"] as Array).duplicate(), "skills": (a["skills"] as Dictionary).duplicate(true),
		"rank": str(a["rank"]), "specialty": str(a.get("specialty", "")), "works": int(a["works"]), "creations": (a["creations"] as Array).duplicate(),
		"mark": (a["mark"] as Dictionary).duplicate(), "memories": (a.get("memories", []) as Array).duplicate(true), "hired_day": int(a["hired_day"]),
		"left_day": Game.day(), "place": str(_c("alumni", "place", "%s's workshop, Brindlewick")) % str(a["name"]).split(" ")[0], "sold": []}
	alumni().append(alum)
	_leave(a, "independence")
	var line := _pick_line("bless", aid) % alum["name"]
	log_line(aid, line)
	Events.toast.emit(line, "legendary")
	Chronicle.add("apprentice", "%s, once apprenticed at the Ironhand forge, opened a workshop of their own in Brindlewick." % alum["name"], {"app": aid}, true)
	_changed()


## Adventurers.buy_elsewhere: now and then a former apprentice sells an adventurer a piece from their own workshop
## (their mark, full provenance). Returns true when a purchase was made.
static func alumni_buy_for(a: Dictionary, want := {}) -> bool:
	if Game.state.is_empty() or not Game.state.has("apprentices") or alumni().is_empty():
		return false
	var rng := _rng("%s|alumni|%d" % [str(a.get("id", "")), Game.day()])
	if rng.randf() >= float(_c("alumni", "sell_chance", 0.35)):
		return false
	var slot := str(want.get("slot", a.get("needs", "")))
	if slot == "" or slot == "companion":
		return false
	var alum: Dictionary = alumni()[rng.randi_range(0, alumni().size() - 1)]
	var best := ""
	var best_q := -1.0
	var ids := DB.recipes.keys()
	ids.sort()
	for rid_v in ids:
		var rid := str(rid_v)
		var out := str(DB.recipe(rid).get("output", ""))
		if str(DB.item(out).get("slot", "")) != slot or can_make(alum, rid) != "":
			continue
		var q := expected_quality(alum, rid)
		var score := float(Crafting.difficulty(rid)) * 10.0 + q
		if score > best_q:
			best_q = score
			best = rid
	if best == "":
		return false
	var r := DB.recipe(best)
	var q2 := clampf(expected_quality(alum, best) + rng.randfn(0.0, 5.0), 40.0, _ceiling(alum, best, "craft"))
	var it := Items.make(str(r["output"]), {"quality": q2, "crafted_by": str(alum["name"])})
	var price := Items.value(it)
	if int(a.get("gold", 0)) < price:
		return false
	Provenance.set_maker(it, str(alum["id"]), str(alum["name"]), str(alum["mark"].get("id", alum["id"])), str(alum["place"]))
	Lore.record("forged", "%s made %s at %s (%d%% craftsmanship)." % [alum["name"], Items.display_name(it), alum["place"], int(round(q2))],
		{"items": [it], "actors": [str(alum["id"])], "place": "brindlewick", "importance": 0, "data": {"alumni": str(alum["id"])}})
	a["gold"] = int(a.get("gold", 0)) - price
	var eq: Dictionary = a.get("equipment", {})
	if eq.has(slot) and not (eq[slot] as Dictionary).is_empty():
		if not a.has("loot"):
			a["loot"] = []
		a["loot"].append(eq[slot])
	eq[slot] = it
	a["equipment"] = eq
	Provenance.transfer(it, str(a.get("id", "")), "bought", "brindlewick", "%s bought %s from %s." % [a.get("name", "An adventurer"), Items.display_name(it), alum["name"]])
	it["owner"] = str(a.get("id", ""))
	if str(a.get("needs", "")) == slot:
		a["needs"] = ""
	(alum["sold"] as Array).append({"day": Game.day(), "adv": str(a.get("id", "")), "uid": int(it["uid"]), "item": str(it["name"]), "price": price})
	while (alum["sold"] as Array).size() > 20:
		(alum["sold"] as Array).pop_front()
	alum["works"] = int(alum.get("works", 0)) + 1
	var line := _pick_line("alumni_sale", str(alum["id"]) + str(Game.day())) % [alum["name"], a.get("name", "an adventurer"), str(it["name"]).to_lower()]
	Chronicle.add("trade", line, {"adv": str(a.get("id", "")), "app": str(alum["id"])})
	Events.adventurers_changed.emit()
	return true
