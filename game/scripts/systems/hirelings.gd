## Hire — employees: work allocation, production, expeditions and recruitment.
## EN: Up to three hirelings (four with the smith). Each has the six trainable work skills, an
##     allocation of normal working time that must total 100%, and a status: working, away
##     (expedition), injured or dead. Expeditions resolve from skill, gear, danger and chance.
## DA: Op til tre ansatte. Hver har seks trænbare arbejdsfærdigheder, en fordeling af arbejdstiden
##     der skal give 100%, og en status: arbejder, ude (ekspedition), skadet eller død.
##     Ekspeditioner afgøres af færdighed, udstyr, fare og tilfældighed.
class_name Hire
extends RefCounted

const MAX_HIRELINGS := 3

## Strengths and weaknesses. mult: per-skill workshop output; xp: experience rate;
## danger / injury: expedition risk multipliers; haul: expedition loot quality bonus.
const TRAITS := {
	"stout": {"name": "Stout-hearted", "good": true, "desc": "Mining output +30%; steady underground", "mult": {"mining": 1.3}, "danger": 0.85},
	"forge_born": {"name": "Forge-born", "good": true, "desc": "Smithing output +30%", "mult": {"smithing": 1.3}},
	"nimble": {"name": "Nimble fingers", "good": true, "desc": "Runecraft and alchemy output +25%", "mult": {"runecraft": 1.25, "alchemy": 1.25}},
	"silver_tongue": {"name": "Silver tongue", "good": true, "desc": "Trading earns +35%", "mult": {"travelling": 1.35}},
	"keen_eye": {"name": "Keen eye", "good": true, "desc": "Finds more relics; richer expedition hauls", "mult": {"relic_hunting": 1.4}, "haul": 10.0},
	"quick_learner": {"name": "Quick learner", "good": true, "desc": "Gains experience 30% faster", "xp": 1.3},
	"hardy": {"name": "Hardy", "good": true, "desc": "Rarely injured; heals quickly", "injury": 0.6},
	"clumsy_glass": {"name": "Clumsy with glassware", "good": false, "desc": "Alchemy output −40%", "mult": {"alchemy": 0.6}},
	"fearful": {"name": "Fearful", "good": false, "desc": "Expeditions are riskier", "danger": 1.4},
	"slow_learner": {"name": "Slow learner", "good": false, "desc": "Gains experience 25% slower", "xp": 0.75},
	"restless": {"name": "Restless", "good": false, "desc": "All workshop output −15%", "mult": {"*": 0.85}},
	"bad_back": {"name": "Bad back", "good": false, "desc": "Mining output −30%", "mult": {"mining": 0.7}},
	"frail": {"name": "Frail", "good": false, "desc": "Injured more easily", "injury": 1.5},
	"heavy_handed": {"name": "Heavy-handed", "good": false, "desc": "Runecraft output −35%", "mult": {"runecraft": 0.65}},
}
const PRESETS := {"best": "Focus on best skill", "two": "Split two best", "even": "Even spread"}


static func list() -> Array:
	return Game.state["hirelings"]


static func get_h(id: String) -> Dictionary:
	for h in list():
		if h["id"] == id:
			return h
	return {}


static func traits_of(h: Dictionary) -> Array:
	if not h.has("traits"):
		# older saves: give Borin his known nature, others a random strength and weakness
		h["traits"] = ["stout", "clumsy_glass"] if h.get("id", "") == "borin" else random_traits()
	return h["traits"]


static func random_traits() -> Array:
	var good := TRAITS.keys().filter(func(k): return TRAITS[k]["good"])
	var bad := TRAITS.keys().filter(func(k): return not TRAITS[k]["good"])
	var out := []
	if randf() < 0.85:
		out.append(good.pick_random())
	if randf() < 0.75:
		out.append(bad.pick_random())
	return out


static func trait_mult(h: Dictionary, key: String, skill := "") -> float:
	var m := 1.0
	for tid in traits_of(h):
		var tr: Dictionary = TRAITS.get(tid, {})
		if key == "mult":
			var mm: Dictionary = tr.get("mult", {})
			m *= float(mm.get(skill, mm.get("*", 1.0)))
		elif key == "haul":
			m += float(tr.get("haul", 0.0))
		else:
			m *= float(tr.get(key, 1.0))
	return m if key != "haul" else m - 1.0


static func add_xp(h: Dictionary, skill: String, amount: int) -> void:
	SkillSys.add_xp(h["skills"], skill, int(round(amount * trait_mult(h, "xp") * float(h.get("potential", 1.0)))), h["id"])


## Hidden potential: a growth multiplier nobody states on a notice. The smith learns it by watching
## them work — after five days in the shop (or at once on easier difficulties once they have grown).
static func potential_known(h: Dictionary) -> bool:
	return Game.day() - int(h.get("hired_day", Game.day())) >= 5


static func potential_word(h: Dictionary) -> String:
	if not potential_known(h):
		return "Potential: unknown — watch them work for a few days"
	var p := float(h.get("potential", 1.0))
	var w := "remarkable — learns twice as fast as most" if p >= 1.35 else ("promising" if p >= 1.12 else ("ordinary" if p >= 0.9 else "limited — slow to improve"))
	return "Potential: " + w


static func log_line(h: Dictionary, text: String) -> void:
	if not h.has("log"):
		h["log"] = []
	var m := int(Game.state.get("minute", 0))
	h["log"].append("Day %d %02d:%02d — %s" % [Game.day(), (m / 60) % 24, m % 60, text])
	while h["log"].size() > 6:
		h["log"].pop_front()


## What the hireling is doing right now, in words.
static func activity_text(h: Dictionary) -> String:
	match str(h.get("status", "")):
		"away":
			var e: Dictionary = h.get("expedition", {})
			return "On expedition to %s — back in %d day%s" % [DB.destinations.get(e.get("dest", ""), {}).get("name", "?"), int(e.get("days_left", 0)), "" if int(e.get("days_left", 0)) == 1 else "s"]
		"injured":
			return "Injured — resting (%d day%s)" % [int(h.get("injured_days", 0)), "" if int(h.get("injured_days", 0)) == 1 else "s"]
		"dead":
			return "Deceased"
	if not Game.is_work_hours():
		return "Off duty"
	var act := str(h.get("activity", ""))
	if act == "":
		return "At work in the forge"
	var verb := {"mining": "Mining and hauling ore", "smithing": "Smelting and smithing", "alchemy": "Gathering and grinding herbs",
		"runecraft": "Splitting runestone blanks", "travelling": "Trading on the road", "relic_hunting": "Sifting for relics"}
	return "%s (%d%% to the next result)" % [verb.get(act, act.capitalize()), int(float(h.get("progress", {}).get(act, 0.0)) * 100.0)]


static func apply_preset(id: String, preset: String) -> void:
	var h := get_h(id)
	if h.is_empty():
		return
	var ranked: Array = DB.work_skills.duplicate()
	ranked.sort_custom(func(a, b): return SkillSys.level(h["skills"], a) * trait_mult(h, "mult", a) > SkillSys.level(h["skills"], b) * trait_mult(h, "mult", b))
	var alloc := {}
	for sk in DB.work_skills:
		alloc[sk] = 0
	match preset:
		"best":
			alloc[ranked[0]] = 100
		"two":
			alloc[ranked[0]] = 60
			alloc[ranked[1]] = 40
		_:
			var each := 100 / DB.work_skills.size()
			for sk in DB.work_skills:
				alloc[sk] = each
			alloc[ranked[0]] += 100 - each * DB.work_skills.size()
	set_alloc(id, alloc)


static func alive_count() -> int:
	return list().filter(func(h): return h["status"] != "dead").size()


static func _new_entry(id: String, name: String, look: String, race: String, personality: String, levels: Dictionary, wage: int) -> Dictionary:
	var alloc := {}
	for s in DB.work_skills:
		alloc[s] = 0
	var best: String = DB.work_skills[0]
	for s in DB.work_skills:
		if int(levels.get(s, 0)) > int(levels.get(best, 0)):
			best = s
	alloc[best] = 100
	return {"id": id, "name": name, "look": look, "race": race, "personality": personality,
		"skills": SkillSys.new_set(levels), "alloc": alloc, "progress": {}, "status": "working",
		"expedition": {}, "injured_days": 0, "wage": wage, "hired_day": Game.day(), "equipment": {}, "expeditions": 0,
		"traits": [], "log": [], "history": [], "activity": ""}


static func hire_from_character(char_id: String) -> void:
	var c := DB.character(char_id)
	var h := _new_entry(char_id, c["name"], char_id, "Dwarf", c.get("personality", ""), c.get("skills", {}), int(c.get("wage", 5)))
	h["equipment"] = {"weapon": Items.make("axe_hand", {"quality": 70.0}), "armor": Items.make("jerkin_leather", {"quality": 66.0})}
	h["traits"] = c.get("traits", ["stout", "clumsy_glass"] if char_id == "borin" else [])
	list().append(h)


# ------------------------------------------------------------------ recruitment
static func refresh_applicants() -> void:
	var out := []
	var looks: Array = DB.names.get("applicant_looks", [])
	# some weeks nobody answers the notice; most weeks two to four do
	var roll := randf()
	var n := 0 if roll < 0.1 else (1 if roll < 0.25 else (2 if roll < 0.5 else (3 if roll < 0.8 else 4)))
	for i in n:
		var lk: Dictionary = looks.pick_random()
		var race: String = lk["race"]
		var pool: Dictionary = DB.names["first"].get(race, DB.names["first"]["Human"])
		var first: String = (pool["f"] if lk["female"] else pool["m"]).pick_random()
		var name := "%s %s" % [first, DB.names["last"].pick_random()]
		var levels := {}
		var skills: Array = DB.work_skills.duplicate()
		skills.shuffle()
		for j in skills.size():
			levels[skills[j]] = [randi_range(3, 5), randi_range(2, 4), randi_range(1, 2), randi_range(0, 2), randi_range(0, 1), 0][j]
		var wage := 3 + int((levels.values().reduce(func(a, b): return a + b, 0)) / 3)
		out.append({"name": name, "look": lk["look"], "race": race, "female": lk["female"],
			"personality": DB.names["personality"].pick_random(), "levels": levels, "wage": wage, "fee": wage * 4,
			"traits": random_traits(), "potential": snappedf(randf_range(0.7, 1.55), 0.01)})
	Game.state["applicants"] = out
	Events.hirelings_changed.emit()


static func hire_applicant(index: int) -> String:
	var apps: Array = Game.state["applicants"]
	if index < 0 or index >= apps.size():
		return "No such applicant."
	if alive_count() >= MAX_HIRELINGS:
		return "You already employ three hands. Dismiss someone first."
	var a: Dictionary = apps[index]
	if not Game.can_afford(int(a["fee"])):
		return "You cannot afford the signing fee."
	Game.add_gold(-int(a["fee"]), "wages", "Signing fee: " + a["name"])
	var id := "hire_%d" % Game.new_uid()
	var h := _new_entry(id, a["name"], a["look"], a["race"], a["personality"], a["levels"], int(a["wage"]))
	h["traits"] = a.get("traits", random_traits())
	h["potential"] = float(a.get("potential", 1.0))
	list().append(h)
	apps.remove_at(index)
	Audio.play("sfx/hire")
	Game.journal("Hired %s (%s)." % [a["name"], a["race"]])
	Events.hirelings_changed.emit()
	return ""


## Replace an employee with an applicant in one step (when all three places are taken).
static func replace(index: int, id: String) -> String:
	var apps: Array = Game.state["applicants"]
	var h := get_h(id)
	if index < 0 or index >= apps.size() or h.is_empty():
		return "No such applicant or hireling."
	if h["status"] == "away":
		return "%s is away and cannot be let go now." % h["name"]
	if not Game.can_afford(int(apps[index]["fee"])):
		return "You cannot afford the signing fee."
	dismiss(id)
	return hire_applicant(index)


## Gives a piece of equipment from the smith's stores to a hireling (the old piece returns).
static func equip(id: String, uid: int) -> bool:
	var h := get_h(id)
	var it := Game.find_uid(uid)
	if h.is_empty() or it.is_empty() or not Items.is_equipment(it) or h["status"] == "away":
		return false
	var slot := Items.slot(it)
	var key := slot
	Game.inventory().erase(it)
	it.erase("for_sale")
	var old: Dictionary = h["equipment"].get(key, {})
	h["equipment"][key] = it
	if not old.is_empty():
		Game.add_item(old, false)
	log_line(h, "took up %s" % it["name"])
	Events.inventory_changed.emit()
	Events.hirelings_changed.emit()
	return true


static func dismiss(id: String) -> void:
	var h := get_h(id)
	if h.is_empty() or h["status"] == "away":
		return
	list().erase(h)
	Game.journal("%s was let go." % h["name"])
	Events.hirelings_changed.emit()


static func set_alloc(id: String, alloc: Dictionary) -> bool:
	var total := 0
	for k in alloc:
		total += int(alloc[k])
	if total != 100:
		return false
	get_h(id)["alloc"] = alloc
	Events.hirelings_changed.emit()
	return true


# ------------------------------------------------------------------ hourly work
const WORK_OUTPUT := {
	"mining": [["ore_iron", 2], ["coal", 2], ["ore_copper", 1]],
	"alchemy": [["herb_moonwort", 1], ["reagent_salt", 1], ["herb_emberleaf", 1]],
	"runecraft": [["runestone_blank", 1]],
	"smithing": [["ingot_iron", 1]],
	"travelling": [],
	"relic_hunting": [["relic_coin", 1]],
}


static func work_hour(_h: int) -> void:
	if not Game.is_work_hours():
		for h in list():
			if h["status"] == "working":
				h["activity"] = ""
		return
	var boost := 1.15 if Game.has_upgrade("second_anvil_hook") else 1.0
	for h in list():
		if h["status"] != "working":
			continue
		# this hour's visible activity follows the allocation
		var r := randf() * 100.0
		for skill in h["alloc"]:
			r -= float(h["alloc"][skill])
			if r <= 0.0:
				h["activity"] = skill
				break
		for skill in h["alloc"]:
			var pct := float(h["alloc"][skill]) / 100.0
			if pct <= 0.0:
				continue
			var lvl := SkillSys.level(h["skills"], skill)
			var prog: Dictionary = h["progress"]
			prog[skill] = float(prog.get(skill, 0.0)) + pct * (0.18 + lvl * 0.05) * boost * trait_mult(h, "mult", skill)
			add_xp(h, skill, int(round(2.0 * pct)) + 1)
			if float(prog[skill]) >= 1.0:
				prog[skill] = float(prog[skill]) - 1.0
				var what := _produce(h, skill, lvl)
				if what != "":
					log_line(h, what)
				add_xp(h, skill, 6)


static func _produce(h: Dictionary, skill: String, lvl: int) -> String:
	# skilled hands process stored materials into finished goods instead of gathering raw ones
	if skill == "relic_hunting":
		for it in Game.inventory():
			if Regions.is_unidentified(it):
				var res := Regions.identify(int(it["uid"]), 70.0 + lvl * 6.0, h["name"])
				if not res.is_empty():
					Events.toast.emit("%s identified a relic: %s." % [h["name"], Items.display_name(res)], "good")
					return "studied a relic: %s" % Items.display_name(res)
	if skill == "alchemy" and lvl >= 2:
		if Game.count("herb_moonwort") >= 2 and randf() < 0.5:
			Game.remove_def("herb_moonwort", 2)
			Game.add_item(Items.make("potion_healing", {"qty": 1, "quality": 60.0 + lvl * 6.0, "crafted_by": h["name"]}), false)
			return "brewed a Healing Draught from stored moonwort"
		if Game.count("herb_emberleaf") >= 1 and Game.count("reagent_salt") >= 1:
			Game.remove_def("herb_emberleaf", 1)
			Game.remove_def("reagent_salt", 1)
			Game.add_item(Items.make("oil_whetstone", {"qty": 1, "quality": 60.0 + lvl * 6.0, "crafted_by": h["name"]}), false)
			return "pressed Whetstone Oil from stored emberleaf"
	if skill == "runecraft" and lvl >= 2 and Game.count("runestone_blank") >= 1 and randf() < 0.35 + lvl * 0.05:
		var kind := "runestone_ward" if Game.count("reagent_salt") >= 1 else ("runestone_ember" if Game.count("herb_emberleaf") >= 1 else "")
		if kind != "":
			Game.remove_def("runestone_blank", 1)
			Game.remove_def("reagent_salt" if kind == "runestone_ward" else "herb_emberleaf", 1)
			Game.add_item(Items.make(kind, {"qty": 1, "quality": 60.0 + lvl * 6.0, "crafted_by": h["name"]}), false)
			return "prepared a %s" % DB.item(kind)["name"]
	if skill == "travelling":
		var g := int(round((4 + lvl * 2 + randi_range(0, 4)) * trait_mult(h, "mult", "travelling")))
		Game.add_gold(g, "trade", "%s traded small goods" % h["name"])
		return "traded small goods for %d g" % g
	if skill == "relic_hunting" and randf() > (0.25 + lvl * 0.05) * trait_mult(h, "mult", "relic_hunting"):
		return "sifted the spoil heaps and found nothing"
	var opts: Array = WORK_OUTPUT.get(skill, [])
	if skill == "mining" and lvl >= 4 and randf() < 0.25:
		opts = [["ore_silver", 1]]
	if skill == "alchemy" and lvl >= 3 and randf() < 0.3:
		opts = [["potion_healing", 1]]
	if opts.is_empty():
		return ""
	var pick: Array = opts.pick_random()
	if skill == "smithing" and Game.count("ore_iron") >= 2:
		Game.remove_def("ore_iron", 2)
	elif skill == "smithing":
		Game.add_gold(3 + lvl, "sales", "%s sold horseshoes and nails" % h["name"])
		return "sold horseshoes and nails for %d g" % (3 + lvl)
	var it := Items.make(pick[0], {"qty": int(pick[1])})
	Game.add_item(it, false)
	return "%s %d %s" % [{"mining": "mined", "alchemy": "gathered", "runecraft": "split", "smithing": "smelted", "relic_hunting": "found"}.get(skill, "made"), int(pick[1]), it["name"]]


# ------------------------------------------------------------------ expeditions
static func gear_score(h: Dictionary) -> float:
	var s := 0.0
	for k in h.get("equipment", {}):
		s += Items.score(h["equipment"][k])
	return s


static func send(id: String, dest_id: String, opts := {}) -> String:
	var h := get_h(id)
	var d: Dictionary = DB.destinations.get(dest_id, {})
	if h.is_empty() or d.is_empty():
		return "Unknown hireling or destination."
	if h["status"] != "working":
		return "%s is not available." % h["name"]
	if d.has("requires_flag") and not Game.has_flag(d["requires_flag"]):
		return "Nobody knows the way there yet."
	var trav := SkillSys.level(h["skills"], "travelling")
	var days: int = maxi(1, randi_range(int(d["days"][0]), int(d["days"][1])) - (1 if trav >= 5 else 0))
	h["status"] = "away"
	h["expedition"] = {"dest": dest_id, "days_left": days, "total": days, "exit": d["exit"], "left_day": Game.day()}
	# a trade run carries a purse for buying materials (and takes the trade goods along to sell)
	var budget := int(opts.get("budget", 0))
	if budget > 0 and d.get("kind", "") == "trade":
		budget = mini(budget, Game.gold())
		if budget > 0:
			Game.add_gold(-budget, "materials", "Trade purse for %s" % h["name"])
			h["expedition"]["budget"] = budget
			h["expedition"]["want"] = opts.get("want", [])
	Game.journal("%s set out for %s (%d days)." % [h["name"], d["name"], days])
	Events.hireling_departed.emit(id, d["exit"])
	Events.hirelings_changed.emit()
	if id == "borin":
		Objectives.complete("send_borin")
	return ""


static func on_day() -> void:
	for h in list():
		if h["status"] == "injured":
			h["injured_days"] = int(h["injured_days"]) - 1
			if int(h["injured_days"]) <= 0:
				h["status"] = "working"
				Events.toast.emit("%s is fit for work again." % h["name"], "good")
		elif h["status"] == "away":
			var e: Dictionary = h["expedition"]
			e["days_left"] = int(e["days_left"]) - 1
			if int(e["days_left"]) <= 0:
				_resolve(h)
	# wages
	var wages := 0
	for h in list():
		if h["status"] != "dead":
			wages += int(h["wage"])
	wages = int(round(wages * float(Expeditions.diff().get("wages", 1.0))))
	if wages > 0:
		Game.add_gold(-wages, "wages", "Daily wages")
	Events.hirelings_changed.emit()


## Expedition odds for a hireling and destination (also shown in the ledger before sending).
static func odds(h: Dictionary, dest_id: String) -> Dictionary:
	var d: Dictionary = DB.destinations.get(dest_id, {})
	var lvl := SkillSys.level(h["skills"], str(d.get("skill", "mining")))
	var danger := Regions.danger(dest_id) * trait_mult(h, "danger")
	var power := lvl * 1.0 + SkillSys.level(h["skills"], "travelling") * 0.4 + gear_score(h) * 0.05
	var success := clampf(0.5 + (power - danger) * 0.09, 0.1, 0.97)
	var injury := clampf((0.08 + (danger - power) * 0.06) * trait_mult(h, "injury"), 0.02, 0.6)
	var death := (1.0 - success) * injury * clampf((danger - power) * 0.05, 0.0, 0.3)
	return {"success": success, "injury": injury, "death": death, "power": power, "danger": danger, "level": lvl}


static func risk_word(o: Dictionary) -> String:
	var dr := float(o["death"])
	if dr >= 0.03:
		return "deadly"
	if dr > 0.0 or float(o["injury"]) >= 0.25:
		return "dangerous"
	if float(o["injury"]) >= 0.12:
		return "risky"
	return "safe"


static func _resolve(h: Dictionary) -> void:
	var e: Dictionary = h["expedition"]
	var d: Dictionary = DB.destinations[e["dest"]]
	var skill: String = d["skill"]
	var o := odds(h, e["dest"])
	var lvl: int = o["level"]
	var danger: float = o["danger"]
	var success := randf() < float(o["success"])
	var injury := randf() < float(o["injury"])
	var death := (not success) and injury and randf() < clampf((danger - float(o["power"])) * 0.05, 0.0, 0.3)
	h["expeditions"] = int(h.get("expeditions", 0)) + 1
	var first_bag: bool = h["id"] == "borin" and not Game.has_flag("borin_first_bag")
	var contents: Array = []
	if death:
		h["status"] = "dead"
		h["expedition"] = {}
		_history(h, d, "died", [])
		Game.journal("%s did not come back from %s." % [h["name"], d["name"]])
		Events.toast.emit("%s died at %s." % [h["name"], d["name"]], "bad")
		var survivors := Loot.roll_table(d["loot"], -20.0)
		if not survivors.is_empty():
			Game.state["returns"].append(Loot.make_container("chest_recovered", survivors.slice(0, 2),
				"Recovered by a passing patrol", "All that came back of %s's expedition." % h["name"]))
		return
	if first_bag:
		Game.set_flag("borin_first_bag")
		contents = Loot.roll_table("start_bag", 0.0)
		contents.append(Loot.random_equipment("legendary_demo"))
		contents.append(Items.make("ore_mithril", {"qty": 2}))
	else:
		contents = Loot.roll_table(d["loot"], lvl * 2.0 + trait_mult(h, "haul") + (0.0 if success else -25.0), lvl)
		if not success:
			contents = contents.slice(0, max(1, contents.size() / 2))
	var bag_def := "shipment_miner" if d["kind"] == "mining" else ("satchel_relic" if d["kind"] == "relics" else "bag_traveller")
	Game.state["returns"].append(Loot.make_container(bag_def, contents, h["name"],
		"%s's haul from %s." % [h["name"], d["name"]]))
	# a trade run: spend the purse with the region's suppliers, sell the trade goods
	if e.has("budget"):
		var tr := Regions.run_trade(int(e["budget"]), SkillSys.level(h["skills"], "travelling"), e.get("want", []))
		contents.append_array(tr["bought"])
		var back := int(tr["change"]) + int(tr["sold_gold"])
		if back > 0:
			Game.add_gold(back, "trade", "%s's trade run: change and sales" % h["name"])
		for ln in tr["lines"]:
			log_line(h, ln)
		log_line(h, "bought %d lots with a %d g purse" % [tr["bought"].size(), int(e["budget"])])
	Regions.on_trip(e["dest"], SkillSys.level(h["skills"], "travelling"), success)
	add_xp(h, skill, (40 + int(danger) * 15) if success else (20 + int(danger) * 8))
	add_xp(h, "travelling", 15)
	if injury:
		h["status"] = "injured"
		h["injured_days"] = maxi(1, int(round(randi_range(1, 3) * trait_mult(h, "injury"))))
		Events.toast.emit("%s came back hurt from %s." % [h["name"], d["name"]], "bad")
	else:
		h["status"] = "working"
	h["expedition"] = {}
	_history(h, d, ("success" if success else "failed") + ("_injured" if injury else ""), contents)
	Game.journal("%s returned from %s%s." % [h["name"], d["name"], "" if success else " with little to show"])
	Events.toast.emit("%s is back from %s — a bag waits in the workshop." % [h["name"], d["name"]], "good")
	Events.hireling_returned.emit(h["id"], d["exit"])
	if h["id"] == "borin":
		Objectives.set_current("open_bag")


static func _history(h: Dictionary, d: Dictionary, outcome: String, contents: Array) -> void:
	if not h.has("history"):
		h["history"] = []
	var names := []
	for it in contents.slice(0, 4):
		names.append(Items.display_name(it))
	h["history"].append({"day": Game.day(), "dest": d["id"], "outcome": outcome, "haul": names})
	while h["history"].size() > 8:
		h["history"].pop_front()
