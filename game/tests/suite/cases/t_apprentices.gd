## Workshop apprentices (iteration 012): hiring, wages and limits; the unlock gate; eligibility by rank, skill and the
## smith's own unlocks; queue priorities with automatic and manual assignment; materials taken and returned without
## duplication; one worker per station (the smith first); work identical through small ticks and one long sleep;
## quality by rank against the smith's exceptional work; proportionate mistakes; rank-ups and specialties; mentoring;
## the apprentice as maker (mark, supervisor, workshop) through repair, sale, reforge and save/load; Epic and Hall of
## Fame for workshop work; recognition by the maker once; commissions; independence (bless → alumni, stay); station
## wear and upkeep; a station removed mid-task; save/load of everything; an old save without the key.
extends SuiteCase

const SMOKE := ["test_unlock_and_limits", "test_materials_taken_and_returned", "test_station_exclusivity", "test_save_load_roundtrip"]
const FIN := ["done", "failed", "cancelled"]


# ------------------------------------------------------------------ fixtures
## A new game where the smith can teach (Smithing 6), with gold and `rooms` extra workshop rooms; hires `n`.
func _setup(n := 1, rooms := 0) -> Array:
	fresh_game()
	train("smithing", 6)
	Game.state["gold"] = 20000
	var extra := ["cobbler", "laundry", "weaver"]
	for i in mini(rooms, extra.size()):
		Property.dev_grant_unit(extra[i])
	(Game.state["hirelings"] as Array).clear()   # Borin's own smelting and mining would move the stores under the test
	var out := []
	for i in n:
		var g := 0
		while Apprentices.applicants().is_empty() and g < 20:
			Apprentices.refresh_applicants()
			g += 1
		var err := Apprentices.hire(0)
		if not check(err == "", "hire an apprentice (%s)" % err):
			break
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []   # neutral hands: tests do not depend on random traits
		out.append(a)
	return out


func _skills(a: Dictionary, rank: String, lv: Dictionary) -> void:
	a["rank"] = rank
	for sk in lv:
		a["skills"][sk] = {"lvl": int(lv[sk]), "xp": 0}


## Advance to the start of the next shift (08:00).
func _to_shift() -> void:
	var m := int(Game.state["minute"])
	Game.advance_minutes(8 * 60 - m if m < 8 * 60 else 24 * 60 - m + 8 * 60)


## Let the clock run until the task is finished (or `max_min` minutes pass).
func _run_until_done(t: Dictionary, max_min := 4 * 1440) -> void:
	var g := 0
	while not str(t["state"]) in FIN and g < max_min:
		Game.advance_minutes(15)
		g += 15


func _in_town_adv(skip_id := "") -> Dictionary:
	var ids := Adv.all().keys()
	ids.sort()
	for id in ids:
		var a := Adv.get_a(str(id))
		if a["status"] == "in_town" and not Shop.refuses(str(id)) and str(id) != skip_id:
			return a
	return {}


## An apprentice-made iron longsword (rank apprentice, Smithing 3).
func _app_sword(a: Dictionary, supervised := false) -> Dictionary:
	_skills(a, "apprentice", {"smithing": 3})
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "assignee": str(a["id"]), "supervised": supervised})
	if not check(not t.has("error"), "queue a longsword (%s)" % t.get("error", "")):
		return {}
	_to_shift()
	_run_until_done(t)
	if not check(str(t["state"]) == "done" and not (t["made"] as Array).is_empty(), "the longsword is finished (%s %s)" % [t["state"], t["blocker"]]):
		return {}
	return Game.find_uid(int(t["made"][0]))


# ------------------------------------------------------------------ hiring, limits, wages
func test_unlock_and_limits() -> void:
	fresh_game()
	check(not Apprentices.unlocked() and Apprentices.unlock_reason() != "", "a new smith cannot take apprentices yet (%s)" % Apprentices.unlock_reason())
	check(Apprentices.add_task("prep", {"recipe": "smelt_iron"}).has("error"), "no tasks before the workshop takes apprentices")
	check(Apprentices.hire_reason() != "", "hiring is refused with a reason")
	Property.dev_grant_unit("cobbler")
	check(Apprentices.unlocked(), "buying the first room next door unlocks apprentices")
	fresh_game()
	train("smithing", 6)
	check(Apprentices.unlocked(), "Smithing 6 unlocks apprentices")
	eq(Apprentices.max_staff(), 1, "one place in the starting workshop")
	Game.state["gold"] = 5000
	var g := 0
	while Apprentices.applicants().size() < 2 and g < 30:
		Apprentices.refresh_applicants()
		g += 1
	check(Apprentices.applicants().size() >= 2, "applicants answer the notice")
	var p: Dictionary = Apprentices.applicants()[0]
	check(str(p["name"]) != "" and str(p["look"]).begins_with("applicant_") and not (p["traits"] as Array).is_empty() and int(p["wage"]) > 0 and int(p["fee"]) > 0,
		"an applicant has a name, look, traits, wage and fee")
	var g0 := Game.gold()
	eq(Apprentices.hire(0), "", "hire the first")
	eq(Game.gold(), g0 - int(p["fee"]), "the signing fee is paid")
	var a: Dictionary = Apprentices.staff()[0]
	eq(str(a["rank"]), "novice", "a new apprentice is a novice")
	check(str(a["mark"]["id"]) == str(a["id"]) and str(a["mark"]["name"]).contains("mark"), "they have a maker's mark of their own")
	check(Apprentices.hire(0) != "", "a second apprentice needs more room (%s)" % Apprentices.hire_reason())
	Property.dev_grant_unit("cobbler")
	Property.dev_grant_unit("laundry")
	Property.dev_grant_unit("weaver")
	Property.dev_grant_unit("chandler")
	Property.dev_grant_unit("cellar")
	eq(Apprentices.max_staff(), 4, "more workshop rooms, more places — never more than four")


func test_wages_loyalty_dismissal() -> void:
	var apps := _setup(1)
	var a: Dictionary = apps[0]
	var g0 := Game.gold()
	Apprentices.on_day()
	eq(Game.gold(), g0 - int(round(int(a["wage"]) * float(Expeditions.diff().get("wages", 1.0)))), "daily wage paid")
	check((Game.state["ledger"] as Array).any(func(e): return str(e.get("note", "")) == "Apprentice wages" or str(e).contains("Apprentice wages")), "the wage is in the ledger")
	Game.state["gold"] = 0
	var l0 := float(a["loyalty"])
	Apprentices.on_day()
	check(float(a["loyalty"]) < l0 and int(a["unpaid_days"]) == 1, "unpaid wages lower loyalty")
	var g := 0
	while str(a.get("notice", {}).get("kind", "")) != "leave" and g < 10:
		Apprentices.on_day()
		g += 1
	check(str(a.get("notice", {}).get("kind", "")) == "leave", "after enough unpaid days they give notice")
	var due := int(a["notice"]["due"])
	while Game.day() < due:
		Game.state["day"] = int(Game.state["day"]) + 1
	Apprentices.on_day()
	check(Apprentices.get_a(str(a["id"])).is_empty() and str(a["status"]) == "gone", "unpaid, they leave")
	# dismissal
	var apps2 := _setup(1)
	var b: Dictionary = apps2[0]
	eq(Apprentices.dismiss(str(b["id"])), "", "an idle apprentice can be let go")
	check(Apprentices.staff().is_empty(), "the staff list is empty again")


# ------------------------------------------------------------------ eligibility
func test_eligibility_by_rank_skill_unlock() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 1})
	eq(Apprentices.can_make(a, "smelt_iron"), "", "a novice may smelt iron")
	check(Apprentices.can_make(a, "iron_longsword") != "", "a novice may not forge a longsword (%s)" % Apprentices.can_make(a, "iron_longsword"))
	_skills(a, "apprentice", {"smithing": 2})
	eq(Apprentices.can_make(a, "iron_longsword"), "", "an apprentice of the rank may forge a plain longsword")
	check(Apprentices.can_make(a, "steel_bastard_sword").contains("Too hard"), "hard work is beyond their rank")
	check(Apprentices.can_make(a, "mithril_runeblade") != "", "arcane work is beyond an apprentice")
	_skills(a, "journeyman", {"smithing": 6, "runecraft": 0})
	check(Apprentices.can_make(a, "ward_runestone").contains("trained"), "a journeyman needs training in another discipline (%s)" % Apprentices.can_make(a, "ward_runestone"))
	_skills(a, "journeyman", {"runecraft": 3})
	eq(Apprentices.can_make(a, "ward_runestone"), "", "…and once trained, may cut runes")
	_skills(a, "journeyman", {"smithing": 1})
	check(Apprentices.can_make(a, "iron_cuirass").contains("Needs"), "skill against difficulty still counts")
	_skills(a, "master", {"arcane_metalwork": 9, "smithing": 9})
	eq(Apprentices.can_make(a, "dragonscale_armor"), "", "a master may attempt legendary-grade work")
	_skills(a, "journeyman", {"arcane_metalwork": 9})
	check(Apprentices.can_make(a, "dragonscale_armor") != "", "legendary-grade work needs a master or the smith")
	# the smith must have learned the recipe himself
	check(Crafting.recipe_locked_reason("steel_longsword") != "", "the smith has not learned steel yet")
	check(Apprentices.add_task("craft", {"recipe": "steel_longsword"}).has("error"), "an apprentice cannot make what the smith has not learned")
	var names := Apprentices.recipes_for(a).map(func(r): return str(r["id"]))
	check(not names.has("steel_longsword"), "recipes_for lists only what the smith has unlocked")


# ------------------------------------------------------------------ queue & assignment
func test_queue_priorities_and_assignment() -> void:
	var apps := _setup(2, 1)
	var a: Dictionary = apps[0]
	var b: Dictionary = apps[1]
	_skills(a, "novice", {"smithing": 2})
	_skills(b, "novice", {"smithing": 0})
	give("ore_iron", 10)
	give("coal", 10)
	var low := Apprentices.add_task("prep", {"recipe": "smelt_iron", "priority": 1})
	var high := Apprentices.add_task("prep", {"recipe": "smelt_iron", "priority": 3})
	_to_shift()
	Game.advance_minutes(5)
	eq(str(high["worker"]), str(a["id"]), "the high-priority task goes to the best idle apprentice")
	eq(str(low["worker"]), str(b["id"]), "the next one goes to the other")
	eq(Apprentices.assign(int(low["id"]), str(a["id"])), "", "a task can be pinned to someone")
	eq(str(low["assignee"]), str(a["id"]), "pinned")
	check(bool(low["manual"]), "manual override recorded")
	eq(Apprentices.assign(int(low["id"]), ""), "", "back to automatic")
	Apprentices.set_auto(false)
	var third := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	Game.advance_minutes(30)
	eq(str(third["worker"]), "", "with automatic assignment off, unpinned work waits")
	check(str(third["blocker"]) != "", "…and says why (%s)" % third["blocker"])
	Apprentices.set_priority(int(third["id"]), 9)
	eq(int(third["priority"]), 3, "priority is clamped to 1–3")


# ------------------------------------------------------------------ materials
func test_materials_taken_and_returned() -> void:
	var apps := _setup(1)
	var a: Dictionary = apps[0]
	_skills(a, "novice", {"smithing": 2})
	var ore0 := Game.count("ore_iron")
	var coal0 := Game.count("coal")
	var ing0 := Game.count("ingot_iron")
	var t := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_to_shift()
	Game.advance_minutes(20)
	check(bool(t["started"]), "the work has started")
	eq(Game.count("ore_iron"), ore0 - 2, "two ore taken from the stores")
	eq(Game.count("coal"), coal0 - 1, "one coal taken")
	eq(int(t["taken"].get("ore_iron", 0)), 2, "the task holds what it took")
	eq(Apprentices.cancel_task(int(t["id"])), "", "cancel the task")
	eq(Game.count("ore_iron"), ore0, "ore returned exactly")
	eq(Game.count("coal"), coal0, "coal returned exactly")
	eq(Game.count("ingot_iron"), ing0, "nothing made, nothing duplicated")
	check(Apprentices.cancel_task(int(t["id"])) != "", "a cancelled task cannot be cancelled twice")
	eq(Game.count("ore_iron"), ore0, "…and returns nothing twice")
	# dismissal: between steps the materials come back; in the middle of a step it is refused
	var t2 := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	Game.advance_minutes(25)
	check(str(t2["station"]) != "" and float(t2["progress"]) > 0.0, "the apprentice is mid-step at the %s" % t2["station"])
	check(Apprentices.dismiss(str(a["id"])) != "", "no dismissal in the middle of an operation")
	t2["progress"] = 0.0
	t2["station"] = ""
	eq(Apprentices.dismiss(str(a["id"])), "", "between steps they can go")
	eq(Game.count("ore_iron"), ore0, "dismissal returned the reserved ore")
	eq(Game.count("coal"), coal0, "…and the coal")
	eq(str(t2["state"]), "queued", "the task waits for another hand")
	# finished work consumes exactly the inputs once
	var b: Dictionary = _setup(1)[0]
	_skills(b, "novice", {"smithing": 2})
	var o1 := Game.count("ore_iron")
	var i1 := Game.count("ingot_iron")
	var t3 := Apprentices.add_task("prep", {"recipe": "smelt_iron", "repeat": 2})
	_to_shift()
	_run_until_done(t3)
	eq(str(t3["state"]), "done", "two smeltings done")
	eq(int(t3["done"]), 2, "repeat count reached, never more")
	var wasted := 0
	for d in t3.get("wasted", {}):
		wasted += int(t3["wasted"][d])
	eq(Game.count("ore_iron"), o1 - 4, "exactly four ore consumed")
	check(Game.count("ingot_iron") >= i1 + 4, "ingots made (%d → %d)" % [i1, Game.count("ingot_iron")])


# ------------------------------------------------------------------ stations
func test_station_exclusivity() -> void:
	var apps := _setup(2, 1)
	for a in apps:
		_skills(a, "novice", {"smithing": 2})
	give("ore_iron", 6)
	var t1 := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	var t2 := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_to_shift()
	Game.advance_minutes(20)
	var users := [str(t1["station"]), str(t2["station"])]
	check(users.count("crucible") == 1, "only one apprentice at the crucible (%s)" % str(users))
	var user := Apprentices.station_user("crucible")
	check(user.begins_with("app_"), "the crucible is held by an apprentice")
	var waiting: Dictionary = t2 if str(t1["station"]) == "crucible" else t1
	check(str(waiting["blocker"]).begins_with("Waiting for the crucible"), "the other waits (%s)" % waiting["blocker"])
	eq(Apprentices.station_state("crucible"), "busy", "the station shows busy")
	# the smith steps up to the crucible: he has priority, the apprentice steps aside
	give("ore_iron", 2)
	check(Crafting.start("smelt_iron"), "the smith starts his own smelting")
	eq(Apprentices.station_user("crucible"), "smith", "the smith is at the crucible")
	Game.advance_minutes(10)
	check(str(t1["station"]) != "crucible" and str(t2["station"]) != "crucible", "no apprentice works at the smith's station")
	eq(Apprentices.station_user("crucible"), "smith", "still the smith's")
	Crafting.cancel()
	Game.advance_minutes(10)
	check(Apprentices.station_user("crucible").begins_with("app_"), "the apprentice returns once the smith leaves")
	for a in apps:
		var held := 0
		for t in Apprentices.tasks():
			if str(t.get("worker", "")) == str(a["id"]) and str(t.get("station", "")) != "":
				held += 1
		check(held <= 1, "an apprentice never holds two stations")


func test_station_removed_blocks_task() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "apprentice", {"smithing": 3})
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword"})
	_to_shift()
	Game.advance_minutes(20)
	check(bool(t["started"]), "the longsword is under way")
	var saved: Dictionary = (Property.st()["stations"]["anvil"] as Dictionary).duplicate(true)
	Property.st()["stations"].erase("anvil")
	var g := 0
	while str(t["state"]) != "blocked" and g < 600:
		Game.advance_minutes(15)
		g += 15
	eq(str(t["state"]), "blocked", "removing the anvil blocks the task instead of breaking it")
	check(str(t["blocker"]).contains("anvil"), "the blocker names the anvil (%s)" % t["blocker"])
	check(not (t["taken"] as Dictionary).is_empty(), "the materials stay with the task")
	Property.st()["stations"]["anvil"] = saved
	_run_until_done(t)
	eq(str(t["state"]), "done", "with the anvil back the work is finished")


func test_wear_and_upkeep() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 2})
	var t := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_to_shift()
	_run_until_done(t)
	check(Apprentices.station_condition("crucible") < 100.0, "apprentice work wears the crucible (%.1f)" % Apprentices.station_condition("crucible"))
	Apprentices.st()["stations"]["crucible"]["condition"] = 30.0
	eq(Apprentices.station_state("crucible"), "worn", "a worn station shows as worn")
	var slow := Apprentices.op_minutes(a, {"kind": "prep", "recipe": "smelt_iron"}, {"station": "crucible", "checks": 1})
	var fast := Apprentices.op_minutes(a, {"kind": "prep", "recipe": "smelt_iron"}, {"station": "forge", "checks": 1})
	check(slow > fast, "work at a worn station is slower (%.0f vs %.0f min)" % [slow, fast])
	check(Apprentices.bottlenecks().any(func(s): return s.contains("worn")), "the bottleneck list mentions the worn station")
	Apprentices.on_day()
	var m := {}
	for x in Apprentices.open_tasks():
		if str(x["kind"]) == "maintain" and str(x["target"]) == "crucible":
			m = x
	check(not m.is_empty(), "an upkeep task is queued for the worn station")
	_to_shift()
	_run_until_done(m)
	check(Apprentices.station_condition("crucible") >= 60.0, "tended: the crucible is in order again (%.0f)" % Apprentices.station_condition("crucible"))


# ------------------------------------------------------------------ time
func _timeline(step: int) -> Dictionary:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "apprentice", {"smithing": 3})
	give("ingot_iron", 4)
	give("leather_cured", 2)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 2})
	var total := 2 * 1440
	var done := 0
	while done < total:
		Game.advance_minutes(step)
		done += step
	var qs := []
	for u in t["made"]:
		qs.append(float(Game.find_uid(int(u)).get("quality", 0.0)))
	return {"state": str(t["state"]), "done": int(t["done"]), "q": qs, "works": int(a["works"]), "xp": JSON.stringify(a["skills"]),
		"progress": float(t["progress"]), "day": Game.day(), "minute": int(Game.state["minute"])}


func test_time_ticks_vs_sleep() -> void:
	var small := _timeline(5)
	var big := _timeline(2 * 1440)
	note("small steps %s / one advance %s" % [str(small), str(big)])
	eq(JSON.stringify(small), JSON.stringify(big), "many 5-minute steps and one long sleep simulate exactly the same work")
	eq(int(small["done"]), 2, "both pieces were finished within two days")


# ------------------------------------------------------------------ quality
func test_quality_by_rank() -> void:
	var a: Dictionary = _setup(1)[0]
	var qn := Apprentices.expected_quality({"rank": "novice", "skills": {"smithing": {"lvl": 1, "xp": 0}}}, "smelt_iron")
	var qm := Apprentices.expected_quality({"rank": "master", "skills": {"smithing": {"lvl": 10, "xp": 0}}}, "smelt_iron")
	check(qn < qm, "a novice is expected to do rougher work than a master (%.0f < %.0f)" % [qn, qm])
	var runs := {}
	for rank in ["apprentice", "master"]:
		_skills(a, rank, {"smithing": 3 if rank == "apprentice" else 10})
		give("ingot_iron", 6)
		give("leather_cured", 3)
		var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 3})
		_to_shift()
		_run_until_done(t, 6 * 1440)
		var qs := []
		for u in t["made"]:
			qs.append(float(Game.find_uid(int(u))["quality"]))
		runs[rank] = qs
	note("apprentice %s · master %s" % [str(runs["apprentice"]), str(runs["master"])])
	var avg := func(arr: Array) -> float:
		var s := 0.0
		for x in arr:
			s += float(x)
		return s / maxf(1.0, arr.size())
	check((runs["apprentice"] as Array).size() == 3 and (runs["master"] as Array).size() == 3, "both made three swords")
	check(float(avg.call(runs["apprentice"])) < float(avg.call(runs["master"])), "a master works better than an apprentice")
	for q in runs["master"]:
		check(float(q) <= 112.0, "a master apprentice stays at or below ~110%% (%.1f)" % float(q))
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var mine := craft("iron_longsword", 125.0)
	check(not mine.is_empty() and float(mine["quality"]) >= 115.0, "the smith's exceptional work (%.1f) is clearly better" % float(mine.get("quality", 0)))
	# rarity is possible through the same pipeline
	var it := Crafting.build("iron_longsword", [], 105.0, {"edge": 14, "temper": 8, "fortune": 100}, "digital",
		{"id": str(a["id"]), "name": str(a["name"]), "mark": str(a["id"]), "level": 10, "rank": "master", "rank_name": "Master"})
	check(str(it["rarity"]) != "common", "an apprentice's piece can come out %s" % it["rarity"])
	eq(str(it["crafted_by"]), str(a["name"]), "and it names its maker")


func test_mistakes_proportionate() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 2})
	var mc: Dictionary = DB.extra("apprentices")["mistakes"]
	var keep := mc.duplicate(true)
	mc["chance"] = 1.0
	mc["kinds"] = ["waste"]
	var ore0 := Game.count("ore_iron")
	var coal0 := Game.count("coal")
	var t := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_to_shift()
	_run_until_done(t)
	eq(str(t["state"]), "done", "the smelting is finished despite the mistakes")
	var lost := 0
	for d in t["wasted"]:
		lost += int(t["wasted"][d])
	eq(lost, 1, "at most one unit is lost on a piece")
	check((t["wasted"] as Dictionary).has("coal"), "the lost unit is a cheap one (coal) (%s)" % str(t["wasted"]))
	eq(Game.count("ore_iron"), ore0 - 2, "the ore is used exactly")
	eq(Game.count("coal"), coal0 - 2, "one coal used and one wasted")
	check((Apprentices.st()["log"] as Array).any(func(e): return str(e["text"]).contains("coal")), "the log explains the waste")
	# a rough piece: lower craftsmanship, explained
	mc["kinds"] = ["rough"]
	var t2 := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_run_until_done(t2)
	var q := float(t2.get("last_quality", 0.0))   # ingots join the stack in the stores; the task keeps the craftsmanship
	check(q > 0.0 and q < Apprentices.expected_quality(a, "smelt_iron") - 10.0, "rough work comes out poorer (%.0f)" % q)
	check(int(a["mistakes"]) >= 3, "mistakes are counted (%d)" % int(a["mistakes"]))
	# cancelling after a waste returns what is left, minus the documented waste
	mc["kinds"] = ["waste"]
	var coal1 := Game.count("coal")
	var t3 := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	var g := 0
	while int(t3.get("op", 0)) < 1 and g < 3000:
		Game.advance_minutes(5)
		g += 5
	check(not (t3["wasted"] as Dictionary).is_empty(), "a unit was wasted in the first step")
	Apprentices.cancel_task(int(t3["id"]))
	eq(Game.count("coal"), coal1 - 1, "cancel returns everything but the one wasted coal")
	for k in keep:
		mc[k] = keep[k]


# ------------------------------------------------------------------ training
func test_rank_up_specialty_mentoring() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 3})
	a["works"] = 7
	a["cat_counts"] = {"ingots": 11}
	a["works"] = 11
	var w0 := int(a["wage"])
	var t := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	_to_shift()
	_run_until_done(t)
	eq(str(a["rank"]), "apprentice", "enough works and skill: a novice becomes an apprentice")
	check(int(a["wage"]) > w0, "a rank-up brings a raise")
	eq(str(a["specialty"]), "ingots", "a specialty after many works in one category")
	var e := Apprentices.expected_quality(a, "smelt_iron")
	a["specialty"] = ""
	check(Apprentices.expected_quality(a, "smelt_iron") < e, "the specialty gives a visible quality bonus")
	a["specialty"] = "ingots"
	check(not Apprentices.next_rank(a).is_empty() and str(Apprentices.next_rank(a)["rank"]) == "journeyman", "next rank: journeyman (%s)" % Apprentices.next_rank(a).get("text", ""))
	# mentoring once a day
	Game.advance_minutes(60)
	var xp0 := int(a["skills"]["smithing"]["xp"]) + int(a["skills"]["smithing"]["lvl"]) * 100000
	var m0 := Game.now()
	var l0 := float(a["loyalty"])
	eq(Apprentices.mentor(str(a["id"])), "", "the smith spends an hour teaching")
	eq(Game.now() - m0, 60, "it costs the smith an hour")
	check(int(a["skills"]["smithing"]["xp"]) + int(a["skills"]["smithing"]["lvl"]) * 100000 > xp0, "the apprentice learns from it")
	check(float(a["loyalty"]) > l0, "and grows more loyal")
	check(Apprentices.mentor(str(a["id"])) != "", "only once a day")


# ------------------------------------------------------------------ provenance & fame
func test_apprentice_provenance() -> void:
	var a: Dictionary = _setup(1)[0]
	var it := _app_sword(a, true)
	if it.is_empty():
		return
	var uid := int(it["uid"])
	var mk := Provenance.maker(it)
	eq(str(mk.get("id", "")), str(a["id"]), "the apprentice is the maker")
	eq(str(mk.get("mark", "")), str(a["mark"]["id"]), "their own mark is struck")
	eq(str(mk.get("workshop", "")), "ironhand", "made at the Ironhand forge")
	eq(str(mk.get("supervisor", "")), "smith", "under the smith's eye (supervised)")
	eq(str(Provenance.mark(it).get("name", "")), str(a["mark"]["name"]), "the mark resolves to the apprentice's")
	check(not Provenance.is_mine(it) and Provenance.is_workshop(it), "not the smith's own work, but the workshop's")
	check(Recognition.made_by_smith(it), "it counts as Ironhand work for fame")
	var forged := Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "forged")
	check(forged.size() == 1 and (forged[0]["actors"] as Array).has(str(a["id"])), "one 'forged' event naming the apprentice")
	check(str(it["craft"].get("maker", "")) == str(a["id"]) and bool(it["craft"].get("supervised", false)), "the craft record names maker and supervision")
	# reforge, sale, repair, save/load: the maker never changes
	give("coal", 2)
	check(bool(ItemStory.reforge(uid, 100.0).get("ok", false)), "reforged at the anvil")
	var adv := _in_town_adv()
	if not check(not adv.is_empty(), "an adventurer is in town"):
		return
	adv["gold"] = 999
	Adv.give_item(adv, Game.take_uid(uid), 40)
	var w: Dictionary = adv["equipment"][Items.slot(it)]
	w["stats"]["durability"] = 3
	Shop.customers().append({"npc": str(adv["id"]), "want": "repair", "own_slot": Items.slot(it), "pay": 10, "present": true, "seat": 0, "arrived": 0})
	Shop.do_repair(str(adv["id"]), 90.0)
	check(save_load("suite_app_prov"), "save and load")
	var back := Game.find_uid_anywhere(uid)
	check(not back.is_empty(), "the same piece (uid) after save/load")
	eq(str(Provenance.maker(back).get("id", "")), str(a["id"]), "the maker survives repair, sale, reforge and save/load")
	eq(str(Provenance.mark(back).get("name", "")), str(a["mark"]["name"]), "the mark still resolves after loading")
	check(Provenance.is_workshop(back), "still workshop work")


func test_epic_and_hall_for_apprentice_work() -> void:
	var a: Dictionary = _setup(1)[0]
	var it := _app_sword(a)
	if it.is_empty():
		return
	check(ItemStory.can_be_named(it), "an apprentice's piece can earn a name")
	var adv := _in_town_adv()
	check(Recognition.grant_epic(it, "struck the killing blow on the Barrow King", str(adv.get("id", "")), "boss"), "an apprentice's piece can become Epic")
	check(Recognition.has_key("epic_%d" % int(it["uid"])), "the Hall of Fame records it")
	check(not Apprentices.famous_works(a).is_empty(), "it is among the apprentice's famous works")


func test_recognised_by_maker_once() -> void:
	var a: Dictionary = _setup(1)[0]
	var it := _app_sword(a)
	if it.is_empty():
		return
	it["epic"] = {"day": Game.day(), "deed": "test", "adventurer": "", "deeds": []}   # a piece worth greeting
	var adv := _in_town_adv()
	Adv.give_item(adv, Game.take_uid(int(it["uid"])), 0)
	var m: int = int(Game.state["minute"])
	Game.advance_minutes((24 * 60 + 9 * 60 - int(m)) % 1440)   # 09:00, on shift
	check(Apprentices.on_shift(a) or str(Apprentices._phase()) == "working", "the apprentice is on shift")
	a["status"] = "working"
	var mem0 := (a["memories"] as Array).size()
	var card := ItemStory.recognise(it, "repair", str(adv["id"]))
	check(not card.is_empty(), "the piece is recognised at the counter")
	eq((a["memories"] as Array).size(), mem0 + 1, "the apprentice who made it remembers it")
	check(str(a["memories"][-1]["text"]).contains("Recognised"), "a recognition memory (%s)" % a["memories"][-1]["text"])
	var card2 := ItemStory.recognise(it, "repair", str(adv["id"]))
	check(card2.is_empty(), "the same occasion is not recognised twice")
	eq((a["memories"] as Array).size(), mem0 + 1, "no duplicate memory")


func test_repair_for_customer() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 1})
	var adv := _in_town_adv()
	var w: Dictionary = adv["equipment"].get("weapon", {})
	if not check(not w.is_empty(), "the adventurer has a weapon"):
		return
	w["stats"]["durability"] = 2
	_to_shift()
	Shop.customers().append({"npc": str(adv["id"]), "want": "repair", "own_slot": "weapon", "pay": 20, "present": true, "seat": 0,
		"arrived": Game.day() * 24 + Game.hour(), "seated": Game.day() * 24 + Game.hour()})
	var xp0: int = int(Game.player_skills()["smithing"]["xp"])
	var g0 := Game.gold()
	var t := Apprentices.add_task("repair", {"target": str(adv["id"]), "priority": 3})
	check(not t.has("error"), "a repair task for the waiting customer (%s)" % t.get("error", ""))
	_run_until_done(t, 300)
	eq(str(t["state"]), "done", "the apprentice mended it while the customer waited")
	check(int(w["stats"]["durability"]) > 2, "durability restored (%d)" % int(w["stats"]["durability"]))
	check(Game.gold() > g0, "the customer paid")
	eq(int(Game.player_skills()["smithing"]["xp"]), xp0, "the smith gains no experience from an apprentice's repair")
	check(Shop.customer(str(adv["id"])).is_empty(), "the customer left satisfied")
	check(Lore.of_item(int(w["uid"])).any(func(e): return str(e["kind"]) == "repaired" and str(e["text"]).contains(str(a["name"]))), "the repair names the apprentice")


func test_repair_own_stores() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "novice", {"smithing": 1})
	var it := Items.make("sword_iron", {"quality": 70.0})
	it["stats"]["durability"] = 1
	Game.add_item(it, false)
	check(Apprentices.worn_in_stores().has(it), "the worn sword is offered for repair")
	var t := Apprentices.add_task("repair", {"target": int(it["uid"])})
	check(not t.has("error"), "repair queued for a piece in the stores (%s)" % t.get("error", ""))
	_to_shift()
	_run_until_done(t, 600)
	eq(str(t["state"]), "done", "mended")
	check(int(it["stats"]["durability"]) > 1, "durability restored (%d)" % int(it["stats"]["durability"]))
	check(not Game.find_uid(int(it["uid"])).is_empty(), "still the same piece in the stores")


func test_commission_fulfilment() -> void:
	var a: Dictionary = _setup(1)[0]
	_skills(a, "apprentice", {"smithing": 3})
	var adv := _in_town_adv()
	var o := {"id": "ord_test12", "npc": str(adv["id"]), "slot": "weapon", "stat": "attack", "min": 1, "def": "sword_iron", "tier": 1,
		"reward": 80, "deadline": Game.day() + 5, "status": "open", "note": "", "placed": Game.day(), "priority": "quality"}
	Shop.orders().append(o)
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var t := Apprentices.add_task("commission", {"order_id": "ord_test12"})
	check(not t.has("error"), "the commission is queued (%s)" % t.get("error", ""))
	check(Apprentices.add_task("commission", {"order_id": "ord_test12"}).has("error"), "the same commission cannot be queued twice")
	_to_shift()
	_run_until_done(t)
	eq(str(t["state"]), "done", "the commission piece is finished")
	var it := Game.find_uid(int(t["made"][0])) if not (t["made"] as Array).is_empty() else {}
	eq(str(it.get("for_order", "")), "ord_test12", "it waits in the stores for the order")
	var g0 := Game.gold()
	eq(Shop.fulfil("ord_test12", int(it.get("uid", -1))), "", "the smith delivers it")
	check(Game.gold() > g0 and str(o["status"]) == "done", "the commission is paid and closed")


# ------------------------------------------------------------------ independence
func test_independence() -> void:
	var apps := _setup(2, 1)
	var a: Dictionary = apps[0]
	var b: Dictionary = apps[1]
	var it := _app_sword(a)
	for x in apps:
		_skills(x, "master", {"smithing": 10})
		x["loyalty"] = 90.0
		x["works"] = 80
		x["hired_day"] = Game.day() - 70
	Apprentices.give_notice(a)
	eq((Apprentices.st()["notices"] as Array).size(), 1, "a notice is given")
	eq(str(a["notice"]["kind"]), "independence", "they ask to open their own workshop")
	var dc: Dictionary = DB.extra("apprentices")["independence"]
	var keep := float(dc["chance"])
	dc["chance"] = 1.0
	Apprentices._independence()
	check((b.get("notice", {}) as Dictionary).is_empty(), "never more than one notice at a time")
	eq(Apprentices.answer_notice(str(a["id"]), "bless"), "", "the smith gives his blessing")
	check(Apprentices.get_a(str(a["id"])).is_empty(), "they leave the staff")
	eq(Apprentices.alumni().size(), 1, "and become a former apprentice")
	var alum: Dictionary = Apprentices.alumni()[0]
	check(int(alum["works"]) >= 80 and str(alum["mark"]["id"]) == str(a["id"]) and str(alum["rank"]) == "master", "keeping name, mark, rank and achievements")
	check(bool(Apprentices.mark_info(str(a["id"])).get("alumni", false)), "their mark is known as a former apprentice's")
	if not it.is_empty():
		eq(str(Provenance.mark(it).get("name", "")), str(a["mark"]["name"]), "pieces they made at the forge still carry their mark")
	# their own work enters the adventurers' economy
	var sold := {}
	var ids := Adv.all().keys()
	ids.sort()
	for d in 12:
		for id in ids:
			var adv := Adv.get_a(str(id))
			adv["gold"] = 5000
			if Apprentices.alumni_buy_for(adv, {"slot": "weapon"}):
				sold = adv["equipment"]["weapon"]
				break
		if not sold.is_empty():
			break
		Game.state["day"] = int(Game.state["day"]) + 1
	check(not sold.is_empty(), "an adventurer bought a piece from the former apprentice's workshop")
	if not sold.is_empty():
		eq(str(Provenance.maker(sold).get("id", "")), str(a["id"]), "it carries its maker")
		eq(str(Provenance.mark(sold).get("name", "")), str(a["mark"]["name"]), "and their mark")
		check(not Provenance.is_workshop(sold), "it is their own workshop's work, not the Ironhand forge's")
	# stay: the other master is asked next and stays
	Apprentices._independence()
	eq(str(b.get("notice", {}).get("kind", "")), "independence", "the other master asks in turn")
	var w0 := int(b["wage"])
	eq(Apprentices.answer_notice(str(b["id"]), "stay"), "", "asked to stay")
	check(int(b["wage"]) > w0 and (b["notice"] as Dictionary).is_empty() and int(b["no_ask_until"]) > Game.day() + 60, "a raise, and no new request for a long time")
	Apprentices._independence()
	check((b["notice"] as Dictionary).is_empty(), "they do not ask again soon")
	dc["chance"] = keep
	check(save_load("suite_app_alumni"), "save and load")
	eq(Apprentices.alumni().size(), 1, "the former apprentice persists")
	eq(str(Apprentices.alumni()[0]["name"]), str(alum["name"]), "with their name")


# ------------------------------------------------------------------ persistence
func test_save_load_roundtrip() -> void:
	var apps := _setup(2, 1)
	_skills(apps[0], "apprentice", {"smithing": 3})
	_skills(apps[1], "novice", {"smithing": 2})
	give("ingot_iron", 4)
	give("leather_cured", 2)
	var t1 := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 2, "priority": 3})
	var t2 := Apprentices.add_task("prep", {"recipe": "smelt_iron", "assignee": str(apps[1]["id"])})
	_to_shift()
	Game.advance_minutes(95)
	var before := JSON.stringify(Apprentices.st())
	check(bool(t1["started"]) and not (t1["taken"] as Dictionary).is_empty(), "work in progress with materials taken")
	check(save_load("suite_app_rt"), "save and load mid-work")
	check(Game.state.has("apprentices"), "the state is saved")
	var after := JSON.stringify(JSON.parse_string(JSON.stringify(Apprentices.st())))
	eq(after, JSON.stringify(JSON.parse_string(before)), "staff, tasks, stations and log round-trip unchanged")
	var t1b := Apprentices.task(int(t1["id"]))
	_run_until_done(t1b)
	eq(str(t1b["state"]), "done", "the work carries on after loading")
	eq(int(t1b["done"]), 2, "both pieces made, none duplicated")
	var t2b := Apprentices.task(int(t2["id"]))
	_run_until_done(t2b)
	eq(str(t2b["state"]), "done", "the pinned task too")


func test_old_save_without_key() -> void:
	fresh_game()
	Game.state.erase("apprentices")
	check(save_load("suite_app_old"), "an old save without apprentices loads")
	Game.advance_minutes(60 * 30)
	check(not Game.state.has("apprentices") or Apprentices.staff().is_empty(), "time passes without apprentice state")
	eq(Apprentices.staff().size(), 0, "no apprentices")
	check(Game.state.has("apprentices"), "the state is created lazily on first touch")
	check(Apprentices.bottlenecks() is Array, "queries work on the fresh state")
