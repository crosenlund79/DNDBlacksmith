## Living — living adventurers (The Living Realm, milestone 3a): the campaign's world seed and starting roster,
## personal goals, friendships and rivalries between adventurers, and life events (retirement, newcomers).
## EN: A new game draws a world seed (Game.state.world_seed). The seed alone decides the starting roster: the
##     eight established adventurers keep their story roles (class, level, family, romance) but their purse,
##     gear quality and goals vary; three to five of the sixteen reserve adventurers (data/characters.json,
##     `reserve: true`) are already at the Wyvern with seeded level, purse, gear, temper, knack, goals and
##     friendships; the rest arrive later as newcomers, in a seeded order, when the roster thins.
##     Goals are small records on the adventurer (`goals`) read by the existing decisions — destination choice
##     (Expeditions.choose_destination), risk appetite (form_parties) and shopping (Adv.purchase_check /
##     gear_needs) — not a new decision engine. Relationships live in the existing `relations` map; when one
##     crosses a threshold it becomes a `bond` (friend, sworn, rival) — one Lore event. Retirement, arrivals,
##     achieved goals and bonds are each ONE Lore event (actors = the adventurers), posted to the Chronicle.
##     Companies (persistent named parties) are in Companies (companies.gd).
## DA: Levende eventyrere: verdensfrø og startliste, personlige mål, venskaber og rivaler, livsbegivenheder.
class_name Living
extends RefCounted

## Set before Game.new_game to force the world seed (tests, the dev panel); -1 = draw one. `--seed=N` on the
## command line does the same.
static var next_seed := -1

const RESERVE_START := [3, 5]      # reserve adventurers at the Wyvern on day 1 (seeded count)
const MIN_TARGET := 6              # the roster the world tries to keep alive and adventuring
const ARRIVAL_GAP := 3             # days between newcomers at least

const GOAL_KINDS := ["gear", "skill", "wealth", "renown", "discovery", "rival", "partner"]
const GOAL_WORD := {"gear": "Better gear", "skill": "Mastery", "wealth": "Wealth", "renown": "Renown", "discovery": "Discovery",
	"rival": "A rival to surpass", "partner": "A companion for the road"}
## What a temper or a class leans towards (weights; the seed picks).
const TRAIT_GOALS := {"brave": {"renown": 4, "discovery": 2, "skill": 2}, "cautious": {"gear": 4, "skill": 3, "wealth": 1},
	"greedy": {"wealth": 5, "gear": 2}, "steady": {"skill": 3, "gear": 3, "partner": 1}, "reckless": {"renown": 4, "wealth": 2},
	"devout": {"discovery": 2, "skill": 2, "partner": 2}}
const CLASS_GOALS := {"Fighter": "gear", "Paladin": "renown", "Barbarian": "renown", "Ranger": "discovery", "Rogue": "wealth",
	"Wizard": "discovery", "Cleric": "skill", "Bard": "renown"}
## Risk appetite by goal: a wealth-seeker takes the dangerous, well-paid work.
const GOAL_RISK := {"wealth": 0.15, "renown": 0.12, "skill": 0.05, "discovery": 0.06, "gear": -0.04, "rival": 0.08, "partner": -0.02}
const KNACKS := ["scouting", "survival", "lore", "locks", "traps"]
const ATTRS := ["str", "dex", "int", "wis", "con"]
const BOND_AT := {"friend": 45.0, "sworn": 75.0, "rival": -35.0}
const RETIRE_WORD := {"age": "the years have caught up with them", "trauma": "they have seen too many friends fall", "wealth": "their fortune is made",
	"goal": "they have done what they set out to do", "injury": "the old wounds will not let them"}


# ======================================================================= state
static func st() -> Dictionary:
	if not Game.state.has("living"):
		Game.state["living"] = {"target": 0, "arrived": [], "last_arrival": 0, "queue": [], "events": 0}
	return Game.state["living"]


## The campaign's world seed. Old saves get one lazily (stable from then on; their roster stays as it was).
static func world_seed() -> int:
	if not Game.state.has("world_seed"):
		Game.state["world_seed"] = absi(hash("%s|%d|%d" % [",".join(Game.state.get("adventurers", {}).keys()), int(Game.state.get("next_uid", 1)), Game.day()])) % 2000000000
	return int(Game.state["world_seed"])


static func make_seed() -> int:
	if next_seed >= 0:
		var s := next_seed
		next_seed = -1
		return s
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--seed="):
			return absi(int(str(arg).split("=")[1]))
	return randi() % 2000000000


static func rng_for(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(hash("%d|%s" % [world_seed(), key]))
	return r


static func _pick(r: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[r.randi() % arr.size()]


static func _weighted(r: RandomNumberGenerator, w: Dictionary) -> String:
	var tot := 0
	for k in w:
		tot += int(w[k])
	var x := r.randi() % maxi(1, tot)
	for k in w:
		x -= int(w[k])
		if x < 0:
			return str(k)
	return str(w.keys()[0])


static func reserve_ids() -> Array:
	var out := []
	for id in DB.characters:
		var c: Dictionary = DB.characters[id]
		if c.get("kind") == "adventurer" and bool(c.get("reserve", false)):
			out.append(id)
	out.sort()
	return out


static func is_reserve(id: String) -> bool:
	return bool(DB.character(id).get("reserve", false))


## The established story adventurers (fixed roles: Mira's errand, the romance options, families).
static func is_story(id: String) -> bool:
	var c := DB.character(id)
	return c.get("kind") == "adventurer" and not bool(c.get("reserve", false))


## Still part of the adventuring world (not fallen, retired or gone).
static func is_active(a: Dictionary) -> bool:
	return str(a.get("status", "")) in ["in_town", "away", "injured", "missing"]


static func active_count() -> int:
	return Adv.all().values().filter(func(a): return is_active(a)).size()


# ======================================================================= campaign generation
## New game: the seeded starting roster (called by Adv.init_population). Same seed → same roster.
static func generate_roster() -> void:
	Game.state["world_seed"] = make_seed()
	var r := rng_for("roster")
	# the established adventurers: same people, varied circumstances
	for id in DB.characters:
		if is_story(id):
			Adv.all()[id] = make_adventurer(id, r, true)
	# the reserves: the seed picks who is already in town; the rest queue up as later newcomers
	var pool := reserve_ids()
	_shuffle(r, pool)
	var n := r.randi_range(RESERVE_START[0], RESERVE_START[1])
	for i in mini(n, pool.size()):
		Adv.all()[pool[i]] = make_adventurer(str(pool[i]), r, false)
	var s := st()
	s["queue"] = pool.slice(mini(n, pool.size()))
	s["last_arrival"] = 1
	for a in Adv.all().values():
		Expeditions.ensure(a)
	s["target"] = maxi(MIN_TARGET, Adv.all().size())
	Game.journal("World seed %d: %d adventurers drink at the Tipsy Wyvern." % [world_seed(), Adv.all().size()])


## Called at the end of Expeditions.init_world (after the established friendships are set): the seeded
## friendships and rivalries of the reserves, the first bonds and the first companies.
static func after_world_init() -> void:
	var r := rng_for("bonds")
	var ids: Array = Adv.all().keys()
	ids.sort()
	for id: String in ids:
		if not is_reserve(id):
			continue
		var links := r.randi_range(1, 2)
		for i in links:
			var other: String = _pick(r, ids)
			if other == id or Expeditions.relation(Adv.get_a(id), other) != 0.0:
				continue
			var v := float(r.randi_range(25, 50)) if r.randf() < 0.65 else -float(r.randi_range(25, 45))
			Expeditions.relate(id, other, v)
	for id: String in ids:
		update_bonds(Adv.get_a(id), true)
		ensure(Adv.get_a(id))
	Companies.seed_start(rng_for("companies"))


static func _shuffle(r: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## One adventurer from character data and the seed. Story characters keep level and role; reserves vary
## within balanced limits (level 1–5, purse 20–260, gear quality 35–80).
static func make_adventurer(id: String, r: RandomNumberGenerator, story: bool) -> Dictionary:
	var c := DB.character(id)
	var cls: String = c["cls"]
	var base_lv := int(c.get("level", 1))
	var lv := base_lv if story else clampi(base_lv + r.randi_range(-1, 1), 1, 5)
	var gold := int(float(c.get("gold", 50)) * r.randf_range(0.8, 1.3)) if story else clampi(int(float(c.get("gold", 60)) * r.randf_range(0.6, 1.5)), 20, 260)
	var eq := {}
	for slot in Adv.START_GEAR.get(cls, {}):
		var g: Array = Adv.START_GEAR[cls][slot]
		var q := float(g[1]) + r.randi_range(-6, 8) if story else 40.0 + lv * 4.0 + r.randi_range(-8, 8)
		eq[slot] = Items.make(g[0], {"quality": clampf(q, 35.0, 80.0)})
	if not story and r.randf() < 0.35 and DB.items.has("boots_leather"):
		eq["boots"] = Items.make("boots_leather", {"quality": float(r.randi_range(48, 66))})
	var a := {"id": id, "name": c["name"], "cls": cls, "level": lv, "xp": r.randi_range(0, lv * 40), "gold": gold, "equipment": eq,
		"loot": [], "status": "in_town", "dest": "", "days_left": 0, "depart_day": Game.day() + r.randi_range(1, 3), "injured_days": 0,
		"expeditions": 0, "victories": 0, "last_report": "", "exit": "", "needs": "",
		"age": int(c.get("age", 30)), "race": str(c.get("race", "Human")), "joined_day": Game.day(), "origin": "start"}
	if story:
		a["trait"] = Adv.CLASS_TRAIT.get(cls, "steady")
	else:
		a["trait"] = Adv.CLASS_TRAIT.get(cls, "steady") if r.randf() < 0.45 else str(_pick(r, Adv.TRAITS.keys()))
		# a little of their own: one attribute up and one down, or a knack outside their class
		if r.randf() < 0.5:
			var up: String = _pick(r, ATTRS)
			var down: String = _pick(r, ATTRS)
			if up != down:
				a["attr_mod"] = {up: 1, down: -1}
		var arch_skills: Array = Expeditions.cfg().get("archetypes", {}).get(cls, {}).get("skills", [])
		var k: String = _pick(r, KNACKS)
		if r.randf() < 0.45 and not arch_skills.has(k):
			a["knacks"] = [k]
		a["retire_on_goal"] = r.randf() < 0.25
	a["goals"] = []
	_fill_goals(a, r)
	# Mira leaves on day 3 for the Barrow Fields — the grocer's story hangs on it
	if id == "mira":
		a["depart_day"] = 3
		a["planned_dest"] = "barrow_fields"
	if id == "sigrun":
		a["depart_day"] = 2
	Biography.ensure(a)   # their pre-game history, written once now (canonical v1.5 §8.1; its own random generator)
	return a


## Two goals: one from class or temper, a second from temper (never the same twice).
static func _fill_goals(a: Dictionary, r: RandomNumberGenerator) -> void:
	_add_goal(a, _first_goal(a, r), r)
	var guard := 0
	while goals(a).size() < 2 and guard < 8:
		guard += 1
		var kind := _weighted(r, TRAIT_GOALS.get(a.get("trait", "steady"), {"skill": 1})) if guard < 4 else str(_pick(r, ["skill", "gear", "renown", "wealth", "discovery"]))
		_add_goal(a, kind, r)


static func _first_goal(a: Dictionary, r: RandomNumberGenerator) -> String:
	return CLASS_GOALS.get(a["cls"], "skill") if r.randf() < 0.5 else _weighted(r, TRAIT_GOALS.get(a.get("trait", "steady"), {"skill": 1}))


## Adds a goal of `kind` with a target fitted to the adventurer now (no duplicates; rival needs a rival).
static func _add_goal(a: Dictionary, kind: String, r: RandomNumberGenerator = null) -> bool:
	if not a.has("goals"):
		a["goals"] = []
	for g in a["goals"]:
		if str(g["kind"]) == kind and not bool(g.get("done", false)):
			return false
	var g := {"kind": kind, "since": Game.day()}
	var lv := int(a.get("level", 1))
	var jitter := r.randi_range(0, 4) if r != null else 2
	match kind:
		"wealth":
			g["target"] = int(a.get("gold", 0)) + 250 + lv * 60 + jitter * 25
		"skill":
			g["target"] = lv + (2 if lv < 5 else 1)
		"renown":
			g["target"] = _next_title(int(a.get("renown", 0)))
		"gear":
			g["target"] = int(Adv.gear_score(a) * 1.3) + 6 + jitter
		"discovery":
			g["target"] = discoveries(a) + 1
		"rival":
			var rv := rival_of(a)
			if rv == "":
				return false
			g["target"] = rv
		"partner":
			g["target"] = 0
		_:
			return false
	if bool(progress(a, g)["ok"]):
		return false   # nothing to strive for: already true (a sworn friend, a rival already outshone…)
	(a["goals"] as Array).append(g)
	return true


static func _next_title(renown: int) -> int:
	for t in Expeditions.cfg().get("renown_titles", []):
		if renown < int(t[0]):
			return int(t[0])
	return renown + 120


## Lazily adds the Living fields (old saves: goals from temper and class, seeded per adventurer).
static func ensure(a: Dictionary) -> Dictionary:
	if a.is_empty():
		return a
	if not a.has("goals"):
		var r := rng_for("goals_" + str(a.get("id", "")))
		a["goals"] = []
		_fill_goals(a, r)
	if not a.has("bonds"):
		a["bonds"] = {}
	if not a.has("trauma"):
		a["trauma"] = 0.0
	if not a.has("age"):
		a["age"] = int(DB.character(str(a.get("id", ""))).get("age", 30))
	Biography.ensure(a)   # older saves: written once on first meeting, then kept unchanged
	return a


# ======================================================================= goals
static func goals(a: Dictionary) -> Array:
	if not a.has("goals"):
		ensure(a)
	return (a.get("goals", []) as Array).filter(func(g): return not bool(g.get("done", false)))


static func has_goal(a: Dictionary, kind: String) -> bool:
	for g in goals(a):
		if str(g["kind"]) == kind:
			return true
	return false


## Discoveries an adventurer has a hand in (Lore: relics found, sites discovered, masters cleared).
static func discoveries(a: Dictionary) -> int:
	var n := 0
	for eid in a.get("lore", []):
		var e := Lore.event(str(eid))
		if str(e.get("kind", "")) in ["discovery", "cleared"]:
			n += 1
	return n


## Progress of a goal: [current, target] as numbers, and whether it is achieved.
static func progress(a: Dictionary, g: Dictionary) -> Dictionary:
	match str(g["kind"]):
		"wealth":
			return {"cur": int(a.get("gold", 0)), "max": int(g["target"]), "ok": int(a.get("gold", 0)) >= int(g["target"])}
		"skill":
			return {"cur": int(a.get("level", 1)), "max": int(g["target"]), "ok": int(a.get("level", 1)) >= int(g["target"])}
		"renown":
			return {"cur": int(a.get("renown", 0)), "max": int(g["target"]), "ok": int(a.get("renown", 0)) >= int(g["target"])}
		"gear":
			var gs := int(Adv.gear_score(a))
			return {"cur": gs, "max": int(g["target"]), "ok": gs >= int(g["target"])}
		"discovery":
			var d := discoveries(a)
			return {"cur": d, "max": int(g["target"]), "ok": d >= int(g["target"])}
		"rival":
			var o := Adv.get_a(str(g["target"]))
			var mine := int(a.get("renown", 0))
			var theirs := int(o.get("renown", 0))
			return {"cur": mine, "max": theirs + 1, "ok": not o.is_empty() and mine > theirs and is_active(o), "gone": o.is_empty() or not is_active(o)}
		"partner":
			var ok := Social.spouse() == str(a.get("id", ""))
			for oid in a.get("bonds", {}):
				if str(a["bonds"][oid].get("kind", "")) == "sworn":
					ok = true
			return {"cur": 1 if ok else 0, "max": 1, "ok": ok}
	return {"cur": 0, "max": 1, "ok": false}


## The goal in plain words, with progress ("Wealth — 310 / 640 gold put by").
static func goal_text(a: Dictionary, g: Dictionary) -> String:
	var p := progress(a, g)
	match str(g["kind"]):
		"wealth":
			return "Wealth — wants %d gold put by (%d / %d)" % [int(g["target"]), int(p["cur"]), int(p["max"])]
		"skill":
			return "Mastery — means to reach level %d (now %d)" % [int(g["target"]), int(p["cur"])]
		"renown":
			return "Renown — wants to be spoken of more widely (%d / %d)" % [int(p["cur"]), int(p["max"])]
		"gear":
			return "Better gear — wants a stronger kit (%d / %d)" % [int(p["cur"]), int(p["max"])]
		"discovery":
			return "Discovery — hopes to find something no one has (%d / %d finds)" % [int(p["cur"]), int(p["max"])]
		"rival":
			return "Rivalry — means to outshine %s (renown %d vs %d)" % [str(Adv.get_a(str(g["target"])).get("name", "a rival")), int(p["cur"]), int(p["max"]) - 1]
		"partner":
			return "A companion for the road — wants someone to trust with their back"
	return str(GOAL_WORD.get(str(g["kind"]), g["kind"]))


## Daily: achieved goals are marked (one Lore event each) and replaced by a new one drawn from what happened.
static func update_goals(a: Dictionary) -> void:
	ensure(a)
	if not is_active(a):
		return
	for g in a["goals"]:
		if bool(g.get("done", false)):
			continue
		var p := progress(a, g)
		if bool(p.get("gone", false)):
			g["done"] = true
			g["result"] = "moot"
			g["day"] = Game.day()
			continue
		if bool(p["ok"]):
			g["done"] = true
			g["result"] = "achieved"
			g["day"] = Game.day()
			a["goals_achieved"] = int(a.get("goals_achieved", 0)) + 1
			Lore.record("goal", "%s achieved what they set out for: %s." % [a["name"], _achieved_word(a, g)],
				{"actors": [a["id"]], "importance": 1, "chronicle": str(g["kind"]) in ["renown", "rival", "discovery", "partner"], "data": {"goal": g["kind"]}})
	# keep two live goals: the next one follows from what happened
	var guard := 0
	while goals(a).size() < 2 and guard < 6:
		guard += 1
		var r := rng_for("goal_%s_%d_%d" % [a["id"], Game.day(), guard])
		var kind := _weighted(r, TRAIT_GOALS.get(a.get("trait", "steady"), {"skill": 1}))
		if rival_of(a) != "" and r.randf() < 0.5:
			kind = "rival"
		elif guard > 2:
			kind = str(_pick(r, ["skill", "gear", "renown", "wealth"]))
		_add_goal(a, kind, r)
	# old finished goals: keep the last few
	var done: Array = (a["goals"] as Array).filter(func(g): return bool(g.get("done", false)))
	if done.size() > 4:
		var keep: Array = done.slice(done.size() - 4)
		a["goals"] = (a["goals"] as Array).filter(func(g): return not bool(g.get("done", false)) or keep.has(g))


static func _achieved_word(a: Dictionary, g: Dictionary) -> String:
	match str(g["kind"]):
		"wealth": return "%d gold put by" % int(a.get("gold", 0))
		"skill": return "level %d" % int(a.get("level", 1))
		"renown": return "the name “%s”" % Expeditions.renown_title(a)
		"gear": return "a kit worth trusting"
		"discovery": return "a find of their own"
		"rival": return "outshining %s" % str(Adv.get_a(str(g["target"])).get("name", "a rival"))
		"partner": return "someone to trust with their back"
	return str(g["kind"])


## How much an adventurer's goals add to their nerve (wealth and renown push them into danger).
static func risk_bonus(a: Dictionary) -> float:
	var b := 0.0
	for g in goals(a):
		b += float(GOAL_RISK.get(str(g["kind"]), 0.0))
	b -= float(a.get("trauma", 0.0)) / 250.0
	if int(a.get("age", 30)) >= 50:
		b -= 0.05
	return b


static func eff_risk(a: Dictionary) -> float:
	return clampf(float(a.get("risk", 0.5)) + risk_bonus(a), 0.05, 0.95)


## How much more than a fair price an adventurer will pay (a gear-seeker pays up; a wealth-seeker haggles).
static func price_tolerance(a: Dictionary) -> float:
	var t := 0.0
	if has_goal(a, "gear"):
		t += 0.3
	if has_goal(a, "wealth"):
		t -= 0.12
	return t


## Gear-seekers call a piece "too weak" sooner (they shop for upgrades others would not).
static func inferior_factor(a: Dictionary) -> float:
	return 0.85 if has_goal(a, "gear") else 0.6


## Extra appeal of a region for a party, from its members' goals. Returns {score, why}.
static func goal_appeal(members: Array, rid: String, rating: float, strength: float) -> Dictionary:
	var sc := 0.0
	var why := ""
	var ratio := rating / maxf(1.0, strength)
	for m in members:
		for g in goals(m):
			match str(g["kind"]):
				"wealth":
					sc += ratio * 9.0
					if ratio > 0.8 and why == "":
						why = "%s wants coin, and it pays to go deep" % m["name"]
				"renown":
					sc += ratio * 6.0
					if ratio > 0.9 and why == "":
						why = "%s wants a deed worth a song" % m["name"]
				"skill":
					sc += 4.0 - absf(ratio - 0.8) * 6.0
				"discovery":
					var seen := false
					for h in m.get("history", []):
						if str(h.get("dest", "")) == rid:
							seen = true
					if not seen:
						sc += 7.0
						if why == "":
							why = "%s hopes to find something new" % m["name"]
				"gear":
					sc -= ratio * 3.0
	return {"score": sc, "why": why}


# ======================================================================= relationships
static func rival_of(a: Dictionary) -> String:
	for oid in a.get("bonds", {}):
		if str(a["bonds"][oid].get("kind", "")) == "rival" and is_active(Adv.get_a(str(oid))):
			return str(oid)
	return ""


static func bond(a: Dictionary, other: String) -> String:
	return str(a.get("bonds", {}).get(other, {}).get("kind", ""))


## Changes how two adventurers regard each other, and turns a crossed threshold into a bond (one Lore event).
static func relate(a_id: String, b_id: String, d: float, why := "") -> void:
	if a_id == b_id:
		return
	Expeditions.relate(a_id, b_id, d)
	var a := Adv.get_a(a_id)
	var b := Adv.get_a(b_id)
	if a.is_empty() or b.is_empty():
		return
	if why != "":
		a["rel_why"] = a.get("rel_why", {})
		b["rel_why"] = b.get("rel_why", {})
		a["rel_why"][b_id] = why
		b["rel_why"][a_id] = why
	update_bonds(a)


## Bonds follow the relations: friend at 45, sworn at 75, rival at -35 (with a little hysteresis).
static func update_bonds(a: Dictionary, quiet := false) -> void:
	ensure(a)
	for oid in a.get("relations", {}).keys():
		var o := Adv.get_a(str(oid))
		if o.is_empty():
			continue
		ensure(o)
		var v := float(a["relations"][oid])
		var cur := bond(a, str(oid))
		var nk := cur
		if v >= BOND_AT["sworn"]:
			nk = "sworn"
		elif v >= BOND_AT["friend"]:
			nk = "friend" if cur != "sworn" or v < 65.0 else "sworn"
		elif v <= BOND_AT["rival"]:
			nk = "rival"
		elif (cur in ["friend", "sworn"] and v < 25.0) or (cur == "rival" and v > -15.0):
			nk = ""
		if nk == cur:
			continue
		var why := str(a.get("rel_why", {}).get(oid, ""))
		if nk == "":
			a["bonds"].erase(oid)
			o["bonds"].erase(a["id"])
			continue
		var b := {"kind": nk, "since": Game.day(), "why": why}
		a["bonds"][oid] = b
		o["bonds"][a["id"]] = b.duplicate()
		if nk == "rival":
			# the one behind means to catch up
			_add_goal(a if int(a.get("renown", 0)) <= int(o.get("renown", 0)) else o, "rival")
		if quiet:
			continue
		var text := ""
		match nk:
			"friend":
				text = "%s and %s became fast friends%s." % [a["name"], o["name"], (" — " + why) if why != "" else ""]
			"sworn":
				text = "%s and %s swore to watch each other's backs%s." % [a["name"], o["name"], (" — " + why) if why != "" else ""]
			"rival":
				text = "%s and %s are rivals now%s." % [a["name"], o["name"], (" — " + why) if why != "" else ""]
		Lore.record("bond", text, {"actors": [a["id"], o["id"]], "importance": 1, "chronicle": nk != "friend", "data": {"bond": nk}})


## After an expedition: shared danger, rescues, grief and competition change how they regard each other.
## `alive` = members who came home. Called by Expeditions.finish.
static func on_expedition(e: Dictionary, alive: Array, won: int, outcome: String) -> void:
	var party: Array = e["party"]
	var by_name := {}
	for id in party:
		by_name[str(Adv.get_a(id).get("name", ""))] = str(id)
	var reg: String = Expeditions.region(str(e["dest"])).get("name", "the wilds")
	var good := won > 0 and outcome != "retreated"
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var x: String = alive[i]
			var y: String = alive[j]
			relate(x, y, 4.0 if good else 1.0, "shared the road to %s" % reg)
			# competition: two glory-seekers on one road keep score
			var ax := Adv.get_a(x)
			var ay := Adv.get_a(y)
			if has_goal(ax, "renown") and has_goal(ay, "renown") and Expeditions.relation(ax, y) < 40.0:
				relate(x, y, -5.0, "both want the glory of %s" % reg)
			if rival_of(ax) == y:
				relate(x, y, -2.0)
	# rescues: a healer who closed a friend's wounds, a guard who stepped in front of them
	for rec in e.get("encounters", []):
		for act in rec.get("actions", []):
			var k := str(act.get("kind", ""))
			if k in ["heal", "guard"] and by_name.has(str(act.get("actor", ""))) and by_name.has(str(act.get("target", ""))):
				var who: String = by_name[str(act["actor"])]
				var whom: String = by_name[str(act["target"])]
				if alive.has(who) and alive.has(whom):
					relate(who, whom, 5.0 if k == "guard" else 3.0, ("%s stepped in front of a blow for %s" if k == "guard" else "%s closed %s's wounds") % [act["actor"], act["target"]])
	# a bad trip: someone gets the blame
	if not good and alive.size() >= 2:
		var lead: String = str(e.get("leader", ""))
		for id in alive:
			if id != lead and alive.has(lead) and (has_goal(Adv.get_a(id), "wealth") or has_goal(Adv.get_a(id), "renown")):
				relate(id, lead, -4.0, "blames %s for %s" % [Adv.get_a(lead).get("name", "the leader"), reg])
	# grief: the fallen leave a mark on those who loved them
	for fid in party:
		var fa := Adv.get_a(fid)
		if str(fa.get("status", "")) != "dead":
			continue
		for id in alive:
			var a := Adv.get_a(id)
			ensure(a)
			a["trauma"] = minf(100.0, float(a["trauma"]) + (22.0 if Expeditions.relation(a, fid) >= 20.0 else 9.0))
	for id in alive:
		var a := Adv.get_a(id)
		ensure(a)
		if float(a.get("hp", 1)) < float(a.get("hp_max", 10)) * 0.2:
			a["trauma"] = minf(100.0, float(a["trauma"]) + 6.0)


# ======================================================================= life events
## Daily (from Adv.on_day): goals, slow healing of the mind, retirement, newcomers.
static func on_day() -> void:
	var s := st()
	if int(s.get("target", 0)) <= 0:
		s["target"] = maxi(MIN_TARGET, active_count())
	if (s.get("queue", []) as Array).is_empty() and not s.has("queue_built"):
		_build_queue()
	var retired_today := false
	for id: String in Adv.all().keys():
		var a := Adv.get_a(id)
		ensure(a)
		if not is_active(a):
			continue
		update_goals(a)
		a["trauma"] = maxf(0.0, float(a["trauma"]) - 0.5)
		if retired_today or str(a.get("status", "")) != "in_town":
			continue
		var why := retire_reason(a)
		if why != "":
			retire(a, why)
			retired_today = true
	Companies.daily()
	if active_count() < int(s["target"]) and Game.day() - int(s.get("last_arrival", 0)) >= ARRIVAL_GAP and randf() < 0.4:
		newcomer()


## Old saves: the reserves that are not yet in the world queue up in a seeded order.
static func _build_queue() -> void:
	var s := st()
	s["queue_built"] = true
	var pool := reserve_ids().filter(func(id): return not Adv.all().has(id))
	_shuffle(rng_for("queue"), pool)
	s["queue"] = pool


## Why this adventurer would hang up their sword today ("" = not today).
static func retire_reason(a: Dictionary) -> String:
	var id := str(a["id"])
	var c := DB.character(id)
	if Social.spouse() == id or bool(c.get("romance", false)) or id == "mira":
		return ""   # the story's people stay in the story
	if Game.day() - int(a.get("joined_day", 0)) < 10 or Shop.customer(id).size() > 0 or not Expeditions.party_of(id).is_empty():
		return ""
	var age := int(a.get("age", 30)) + int(Game.day() / 360)
	var lv := int(a.get("level", 1))
	if float(a.get("trauma", 0.0)) >= 70.0 and randf() < 0.2:
		return "trauma"
	if age >= 55 and randf() < 0.03:
		return "age"
	if int(a.get("gold", 0)) >= 900 + lv * 100 and randf() < 0.06:
		return "wealth"
	if bool(a.get("retire_on_goal", false)) and int(a.get("goals_achieved", 0)) >= 2 and randf() < 0.2:
		return "goal"
	if int(a.get("deaths_cheated", 0)) >= 3 and randf() < 0.1:
		return "injury"
	return ""


## Retirement: one Lore event. The adventurer stays in the village (status "retired") or leaves for good
## ("gone"); their gear goes to a companion who can use it, the smith's own work is offered back to the forge,
## the rest is kept (a keepsake) or carried away.
static func retire(a: Dictionary, why: String, stays := -1) -> Dictionary:
	ensure(a)
	var id := str(a["id"])
	var friends := []
	for oid in a.get("bonds", {}):
		if str(a["bonds"][oid].get("kind", "")) in ["friend", "sworn"]:
			friends.append(str(oid))
	var co := Companies.of(id)
	for m in co.get("members", []):
		if str(m) != id and not friends.has(str(m)):
			friends.append(str(m))
	var stay := stays == 1 or (stays == -1 and (is_story(id) or not friends.is_empty() and randf() < 0.65))
	var given := []
	var offered := []
	for slot in (a.get("equipment", {}) as Dictionary).keys():
		var it: Dictionary = a["equipment"][slot]
		if it.is_empty() or not Items.is_equipment(it):
			continue
		var heir := {}
		var best := 0.0
		for fid in friends:
			var h := Adv.get_a(fid)
			if h.is_empty() or not str(h.get("status", "")) in ["in_town", "injured"]:
				continue
			var gain := Items.score(it) - Items.score(h["equipment"].get(slot, {}))
			if gain > best and Adv.affinity(h, it) > 0.0:
				best = gain
				heir = h
		if not heir.is_empty():
			a["equipment"].erase(slot)
			var old: Dictionary = heir["equipment"].get(slot, {})
			if not old.is_empty():
				heir["loot"].append(old)
			heir["equipment"][slot] = it
			Provenance.transfer(it, str(heir["id"]), "given", "brindlewick", "%s handed %s to %s on leaving the road." % [a["name"], Items.display_name(it), heir["name"]])
			given.append([it, str(heir["id"])])
		elif Provenance.is_mine(it):
			a["equipment"].erase(slot)
			Shop.add_offer(id, it, false)
			offered.append(it)
	a["status"] = "retired" if stay else "gone"
	a["activity"] = "retired" if stay else "gone"
	a["retired_day"] = Game.day()
	a["retire_why"] = why
	a["shopping"] = []
	a["saving_for"] = {}
	var text := "%s hung up their %s: %s." % [a["name"], "sword" if a["cls"] in ["Fighter", "Paladin"] else "pack", RETIRE_WORD.get(why, why)]
	text += " They will stay in Brindlewick." if stay else " They have left Brindlewick for good."
	if not given.is_empty():
		text += " " + "; ".join(given.map(func(x): return "%s went to %s" % [Items.display_name(x[0]), Adv.get_a(str(x[1])).get("name", "")])) + "."
	if not offered.is_empty():
		text += " The smith's own work was offered back to the forge."
	var actors := [id]
	for x in given:
		if not actors.has(str(x[1])):
			actors.append(str(x[1]))
	var items := given.map(func(x): return x[0]) + offered
	var ev := Lore.record("retired", text, {"actors": actors, "items": items, "importance": 2, "chronicle": true, "notable": true, "place": "brindlewick",
		"data": {"why": why, "stays": stay}})
	Social.change(id, 2.0, 4.0, "retired", "Hung up my %s. The road is someone else's now." % ("sword" if a["cls"] in ["Fighter", "Paladin"] else "pack"), false)
	Companies.on_member_left(id, "retired" if stay else "left", ev)
	Events.toast.emit("%s has retired from adventuring." % a["name"], "info")
	Events.adventurers_changed.emit()
	return {"event": ev, "stays": stay, "given": given.size(), "offered": offered.size()}


## A newcomer arrives at the Wyvern (the next reserve in the seeded queue): one Lore event.
static func newcomer() -> Dictionary:
	var s := st()
	var q: Array = s.get("queue", [])
	while not q.is_empty() and Adv.all().has(str(q[0])):
		q.pop_front()
	if q.is_empty():
		return {}
	var id: String = q.pop_front()
	var r := rng_for("arrival_" + id)
	var a := make_adventurer(id, r, false)
	# within balanced limits: never far beyond the roster's middle
	var levels: Array = Adv.all().values().filter(func(x): return is_active(x)).map(func(x): return int(x.get("level", 1)))
	levels.sort()
	var mid: int = levels[levels.size() / 2] if not levels.is_empty() else 2
	a["level"] = clampi(int(a["level"]), 1, maxi(2, mid))
	a["origin"] = "arrived"
	a["joined_day"] = Game.day()
	Adv.all()[id] = a
	Expeditions.ensure(a)
	a["hp_max"] = Expeditions.hp_max(a)
	a["hp"] = a["hp_max"]
	ensure(a)
	(s["arrived"] as Array).append(id)
	s["last_arrival"] = Game.day()
	var c := DB.character(id)
	var text := "%s, a %s %s, arrived at the Tipsy Wyvern looking for work. %s" % [a["name"], str(c.get("race", "Human")).to_lower(), a["cls"].to_lower(), str(c.get("personality", ""))]
	Lore.record("arrival", text, {"actors": [id], "importance": 1, "chronicle": true, "place": "brindlewick"})
	Events.toast.emit("A newcomer at the Wyvern: %s the %s." % [a["name"], a["cls"]], "info")
	Events.adventurers_changed.emit()
	return a


# ======================================================================= presentation helpers
static func status_word(a: Dictionary) -> String:
	match str(a.get("status", "")):
		"retired":
			return "Retired"
		"gone":
			return "Left Brindlewick"
	return ""


## Short lines about who they are close to (for the sheet): [[other id, kind, why]].
static func bond_lines(a: Dictionary) -> Array:
	var out := []
	for oid in ensure(a)["bonds"]:
		var b: Dictionary = a["bonds"][oid]
		out.append([str(oid), str(b.get("kind", "")), str(b.get("why", "")), int(b.get("since", 0))])
	return out


## The roster in one line for logs and tests: ids, levels, purses, tempers, goals, gear.
static func signature() -> String:
	var parts := []
	var ids: Array = Adv.all().keys()
	ids.sort()
	for id: String in ids:
		var a := Adv.get_a(id)
		var eq := []
		var slots: Array = a["equipment"].keys()
		slots.sort()
		for s in slots:
			eq.append("%s:%s@%d" % [s, a["equipment"][s]["def"], int(float(a["equipment"][s].get("quality", 0)))])
		var rel := []
		var others: Array = a.get("relations", {}).keys()
		others.sort()
		for o in others:
			rel.append("%s=%d" % [o, int(float(a["relations"][o]))])
		parts.append("%s/L%d/%dg/%s/%s/%s/%s/%s/%s" % [id, int(a["level"]), int(a["gold"]), a.get("trait", ""), ",".join((a.get("goals", []) as Array).map(func(g): return str(g["kind"]))),
			",".join(eq), JSON.stringify(a.get("attr_mod", {})) + str(a.get("knacks", [])), ",".join(rel), str(a.get("company", ""))])
	return "|".join(parts)
