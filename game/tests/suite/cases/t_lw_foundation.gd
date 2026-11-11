## The Living Workshop — FOUNDATION (B1): the shared worker capability model (Workers).
## Profiles for the smith, apprentices/specialists and field hirelings; professions on applicants and hires; per-actor
## check parameters and quality inputs; eligibility with reasons (workshop knowledge, competence per operation in its
## station's discipline, station access); the smith's basic cap in other crafts with earned levels preserved;
## specialists not limited by what the smith can do himself (a parallel route to t_apprentices); the skill-tree seam
## (another craft's node met by a specialist); save step 5 "worker professions" on golden saves and on a schema-4 save
## with apprentices (idempotent, nothing lost); the steward's zero-XP guard and the Mining XP hotfix still hold.
extends SuiteCase

const SMOKE := ["test_profiles", "test_eligibility_with_reasons", "test_player_basic_cap_and_preserved_levels"]
const FIN := ["done", "failed", "cancelled"]
const GOLDEN := ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]
const FIXTURES := "res://tests/fixtures/saves/"


# ------------------------------------------------------------------ fixtures
## A new game with the whole building, every station, the whole tree, the Arcane Foundry and money: the workshop
## knows every Design, so the tests are about competence.
func _workshop() -> void:
	fresh_game()
	Property.dev_grant_all()
	SkillTree.unlock_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Game.state["gold"] = 20000
	(Game.state["hirelings"] as Array).clear()   # Borin's own smelting would move the stores under the test


func _run_until_done(t: Dictionary, max_min := 6 * 1440) -> void:
	var g := 0
	while not str(t.get("state", "")) in FIN and g < max_min:
		Game.advance_minutes(15)
		g += 15


func _golden_data(name: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
	if not doc is Dictionary or not (doc as Dictionary).get("data") is Dictionary:
		return {}
	return Saves._restore_ints(doc["data"])


## The task queue without the fields a later save step adds (Living Workshop C1: stages and the reserved uid).
func _queue_text(q: Array) -> String:
	var c := q.duplicate(true)
	for t in c:
		for k in ["stages", "stages_for", "uid"]:
			(t as Dictionary).erase(k)
	return JSON.stringify(c, "", true)


## Everything about a worker except the profession (what migration 5 must leave untouched).
func _without_profession(a: Dictionary) -> String:
	var c := a.duplicate(true)
	c.erase("profession")
	return JSON.stringify(c, "", true)


# ------------------------------------------------------------------ profiles
func test_profiles() -> void:
	var me := Workers.profile("player")
	eq(str(me["profession"]), "blacksmith", "the smith is the blacksmith")
	eq(str(me["family"]), "workshop", "the smith is a workshop worker")
	check((me["deep"] as Array).has("smithing") and (me["deep"] as Array).has("mining"), "he may master smithing and mining %s" % str(me["deep"]))
	check((me["basic"] as Array).has("runecraft") and (me["basic"] as Array).has("alchemy") and not (me["basic"] as Array).has("smithing"),
		"his other crafts are basic %s" % str(me["basic"]))
	eq(int(me["competence"]["smithing"]), Game.player_level("smithing"), "his competence is his own level")
	var borin := Workers.profile("borin")
	eq(str(borin["family"]), "field", "Borin is a field hireling (D1: a distinct family)")
	eq(str(borin["profession"]), "", "field hirelings have no workshop profession")
	eq(str(borin["field_role"]), "miner", "…but a read-only field role from his best work skill")
	check(bool(borin["read_only"]) and (borin["deep"] as Array).is_empty(), "the field profile is read-only and caps nothing")
	check(Workers.profile("nobody").is_empty(), "an unknown actor has no profile")
	check(Workers.can_do("borin", "iron_longsword").contains("field hireling"), "a field hireling does not take workshop work: %s" % Workers.can_do("borin", "iron_longsword"))
	check(Workers.station_reason("borin", "anvil").contains("field hireling"), "…nor work the stations")
	# applicants come with a profession whose discipline they lean to and whose skill they bring
	train("smithing", 6)
	var seen := {}
	for i in 30:
		Apprentices.refresh_applicants()
		for p in Apprentices.applicants():
			var prof := str(p.get("profession", ""))
			check(Workers.PROFESSIONS.has(prof), "an applicant has a profession (%s)" % prof)
			check((p.get("prefs", []) as Array).has(Workers.discipline_of(prof)), "%s leans to their profession's discipline" % p["name"])
			check(int(p["levels"].get(Workers.skill_of(prof), 0)) >= 1, "%s brings some %s" % [p["name"], Workers.skill_of(prof)])
			seen[prof] = true
	check(seen.has("blacksmith") and seen.has("leatherworker") and seen.has("runesmith") and seen.has("alchemist"),
		"blacksmiths, leatherworkers, runesmiths and alchemists answer the notice %s" % str(seen.keys()))
	check(not seen.has("arcanist"), "no arcanist applies before the forge has an Arcane Foundry")
	(Game.state["upgrades"] as Array).append("arcane_foundry")
	var arc := false
	for i in 40:
		Apprentices.refresh_applicants()
		arc = arc or Apprentices.applicants().any(func(p): return str(p.get("profession", "")) == "arcanist")
	check(arc, "with the Arcane Foundry, arcanists apply too")
	# hiring keeps the profession
	Game.state["gold"] = 5000
	var p0: Dictionary = Apprentices.applicants()[0]
	eq(Apprentices.hire(0), "", "hire an applicant")
	var a: Dictionary = Apprentices.staff()[-1]
	eq(str(a["profession"]), str(p0["profession"]), "the hired apprentice keeps their profession")
	var pa := Workers.profile(str(a["id"]))
	eq(str(pa["profession"]), str(p0["profession"]), "their profile names it")
	check((pa["deep"] as Array).has(Workers.skill_of(str(p0["profession"]))), "they may master their profession's skill")
	eq(str(pa["rank"]), "Novice", "and their rank")
	check(Workers.title(a) == Workers.profession_name(str(p0["profession"])), "their title is the profession (%s)" % Workers.title(a))


# ------------------------------------------------------------------ per-actor checks and quality
func test_per_actor_checks_and_quality() -> void:
	_workshop()
	var rune := Apprentices.dev_take_on("runesmith", 7, "journeyman")
	var leather := Apprentices.dev_take_on("leatherworker", 6, "journeyman")
	if not check(not rune.is_empty() and not leather.is_empty(), "two specialists join"):
		return
	Vitality.set_fatigue(0.0)
	var mine := Crafting.check_params("rune_engraving_stand", "ward_runestone")
	var theirs := Workers.check_params(rune, "rune_engraving_stand", "ward_runestone")
	eq(int(mine["level"]), Game.player_level("runecraft"), "the smith's check uses his runecraft")
	eq(int(theirs["level"]), 7, "the runesmith's check uses theirs")
	eq(str(theirs["actor"]), str(rune["id"]), "the parameters name the actor")
	check(float(theirs["zone"]) > float(mine["zone"]) and float(theirs["speed"]) < float(mine["speed"]),
		"the runesmith's zone is wider (%.1f > %.1f) and the needle slower (%.2f < %.2f)" % [float(theirs["zone"]), float(mine["zone"]), float(theirs["speed"]), float(mine["speed"])])
	# the smith's fatigue counts for the smith only
	Vitality.set_fatigue(100.0)
	var tired := Crafting.check_params("rune_engraving_stand", "ward_runestone")
	var theirs2 := Workers.check_params(rune, "rune_engraving_stand", "ward_runestone")
	check(float(tired["zone"]) < float(mine["zone"]), "a tired smith gets a narrower zone (%.1f < %.1f)" % [float(tired["zone"]), float(mine["zone"])])
	check(is_equal_approx(float(theirs2["zone"]), float(theirs["zone"])), "the runesmith is not slowed by the smith's fatigue")
	Vitality.set_fatigue(0.0)
	# quality inputs: the piece's skill bonus follows the maker's level
	check(Workers.skill_bonus(rune, "ward_runestone") > float(Crafting.cfg("skill").get("quality_per_level", 0.4)) * Game.player_level("runecraft"),
		"the runesmith's level, not the smith's, lifts their piece")
	# per operation: the station's discipline decides whose skill counts (a grip wrapped at the stitching table)
	var ops := Crafting.operations("steel_longsword")
	var wrap := -1
	var anvil := -1
	for i in ops.size():
		if Crafting.skill_for_station(str(ops[i]["station"])) == "enchanted_stitching":
			wrap = i
		elif str(ops[i]["station"]) == "anvil" and anvil < 0:
			anvil = i
	if not check(wrap >= 0 and anvil >= 0, "the steel longsword has a stitching operation and an anvil operation"):
		return
	var smith_app := Apprentices.dev_take_on("blacksmith", 6, "journeyman")
	if not check(not smith_app.is_empty(), "a blacksmith apprentice joins"):
		return
	eq(str(Workers.op_quality_inputs(smith_app, "steel_longsword", wrap)["skill"]), "enchanted_stitching", "the wrap is judged by stitching")
	check(Workers.expected_op_quality(leather, "steel_longsword", wrap) > Workers.expected_op_quality(smith_app, "steel_longsword", wrap),
		"the leatherworker wraps a grip better than the blacksmith apprentice (%.1f > %.1f)" % [Workers.expected_op_quality(leather, "steel_longsword", wrap),
		Workers.expected_op_quality(smith_app, "steel_longsword", wrap)])
	check(Workers.expected_op_quality(smith_app, "steel_longsword", anvil) > Workers.expected_op_quality(leather, "steel_longsword", anvil),
		"the blacksmith apprentice works the anvil better than the leatherworker")
	eq(Workers.expected_op_quality("player", "steel_longsword", anvil), -1.0, "the smith's own checks are played, not simulated")
	# experience per operation goes to the station's skill (what they practised)
	give("ingot_steel", 4)
	give("leather_cured", 2)
	give("coal", 4)
	var s0 := int(smith_app["skills"]["enchanted_stitching"]["xp"]) + 1000 * int(smith_app["skills"]["enchanted_stitching"]["lvl"])
	var t := Apprentices.add_task("craft", {"recipe": "steel_longsword", "assignee": str(smith_app["id"])})
	if not check(not t.has("error"), "queue a steel longsword for the blacksmith apprentice (%s)" % t.get("error", "")):
		return
	_run_until_done(t)
	check(str(t["state"]) == "done", "the longsword is finished (%s %s)" % [t["state"], t.get("blocker", "")])
	check(int(smith_app["skills"]["enchanted_stitching"]["xp"]) + 1000 * int(smith_app["skills"]["enchanted_stitching"]["lvl"]) > s0,
		"wrapping the grip taught them a little stitching")


# ------------------------------------------------------------------ eligibility and reasons
func test_eligibility_with_reasons() -> void:
	_workshop()
	# what an operation asks
	var q := Workers.op_requirement("concord_runestone", 0)
	check(str(q["skill"]) == "runecraft" and bool(q["main"]) and int(q["difficulty"]) == Crafting.difficulty("concord_runestone") - Workers.reach() and bool(q["advanced"]),
		"an operation's requirement: skill, the Design's difficulty less reach, advanced %s" % str(q))
	var lw := Crafting.operations("steel_longsword")
	for i in lw.size():
		var r := Workers.op_requirement("steel_longsword", i)
		if str(r["skill"]) == "enchanted_stitching":
			check(not bool(r["main"]) and int(r["level"]) == 0, "a contribution in another discipline asks only what the Design names (%s)" % Workers.requirement_text(r))
	# the smith: basic work in another craft stays open, master-grade work needs a specialist
	eq(Crafting.recipe_locked_reason("original_runestone"), "", "basic-to-journeyman rune work stays open to the smith (at his actual competence)")
	var why := Crafting.recipe_locked_reason("concord_runestone")
	check(why.contains("runesmith") and why.contains("basic") and why.contains("Runecraft"), "master-grade rune work names who it needs: %s" % why)
	check(Crafting.recipe_locked_reason("archmage_robe").contains("leatherworker"), "the archmage's robe needs a leatherworker: %s" % Crafting.recipe_locked_reason("archmage_robe"))
	check(Crafting.recipe_locked_reason("dragonscale_armor").contains("arcanist"), "dragonscale armour needs an arcanist: %s" % Crafting.recipe_locked_reason("dragonscale_armor"))
	check(Crafting.recipe_locked_reason("mithril_runeblade").begins_with("Requires Arcane Metalworking 1"), "a Design's own requirement still comes first, as before: %s" % Crafting.recipe_locked_reason("mithril_runeblade"))
	eq(Crafting.recipe_locked_reason("steel_greatsword"), "", "his own craft is not newly gated (the tree and his checks decide)")
	check(Workers.can_do("player", {"recipe": "concord_runestone", "op": 0}).contains("runesmith"), "per operation too")
	var g := Guide.recipe_status("concord_runestone")
	check((g["obstacles"] as Array).any(func(o): return str(o["kind"]) == "specialist"), "the guide lists the specialist as the obstacle")
	check(str(Guide.next_step("recipe:concord_runestone").get("text", "")).contains("runesmith"), "and its next step is to find one: %s" % str(Guide.next_step("recipe:concord_runestone").get("text", "")))
	# a runesmith of the right level may; the reason then says so
	var rune := Apprentices.dev_take_on("runesmith", 8, "master")
	if not check(not rune.is_empty(), "a master runesmith joins"):
		return
	eq(Workers.can_do(rune, "concord_runestone"), "", "the master runesmith may make the Concord runestone")
	check(Crafting.recipe_locked_reason("concord_runestone").contains(str(rune["name"])), "the smith's reason names who can: %s" % Crafting.recipe_locked_reason("concord_runestone"))
	check(Workers.who_can("concord_runestone") == [str(rune["id"])], "who_can lists the runesmith, not the smith (%s)" % str(Workers.who_can("concord_runestone")))
	eq(Workers.workshop_can("concord_runestone"), "", "the workshop can make it")
	check(str(Guide.next_step("recipe:concord_runestone").get("text", "")).contains(str(rune["name"]).split(" ")[0]), "the guide sends the smith to them: %s" % str(Guide.next_step("recipe:concord_runestone").get("text", "")))
	# station access by the worker's own skill
	var l2 := Apprentices.dev_take_on("leatherworker", 2, "apprentice")
	if not check(not l2.is_empty(), "a young leatherworker joins"):
		return
	check(Workers.can_do(l2, {"station": "thread_spinner"}).contains("Needs Enchanted Stitching 3"), "the thread spinner needs their own stitching 3: %s" % Workers.can_do(l2, {"station": "thread_spinner"}))
	l2["skills"]["enchanted_stitching"] = {"lvl": 4, "xp": 0}
	eq(Workers.can_do(l2, {"station": "thread_spinner"}), "", "at stitching 4 they may use it")
	eq(Workers.station_reason("nobody", "anvil"), "Unknown worker.", "an unknown actor works no station")
	# a rank rule still applies to a specialist (a novice runesmith may cut their own runes from the start)
	var nov := Apprentices.dev_take_on("runesmith", 2, "novice")
	if check(not nov.is_empty(), "a novice runesmith joins"):
		eq(Apprentices.can_make(nov, "restore_runestone"), "", "a novice runesmith may work their own craft")
		check(Apprentices.can_make(nov, "ward_runestone").contains("Too hard"), "but only a novice's work: %s" % Apprentices.can_make(nov, "ward_runestone"))
	# workshop knowledge is separate and never granted by competence
	fresh_game()
	Property.dev_grant_all()
	var r2 := Apprentices.dev_take_on("runesmith", 9, "master")
	if check(not r2.is_empty(), "a master runesmith joins a new forge"):
		check(Workers.can_do(r2, "concord_runestone").contains("Skill tree"), "nobody makes a Design the workshop does not know: %s" % Workers.can_do(r2, "concord_runestone"))
		check(Apprentices.add_task("craft", {"recipe": "concord_runestone"}).get("error", "").contains("does not know"), "the queue refuses it with the reason")


# ------------------------------------------------------------------ the smith's basic cap
func test_player_basic_cap_and_preserved_levels() -> void:
	eq(Workers.growth_cap("player", "runecraft"), Workers.BASIC_LEVEL, "another craft grows to the basic level")
	eq(Workers.growth_cap("player", "smithing"), int(DB.skill_curve.get("max_level", 20)), "smithing grows to mastery")
	eq(Workers.growth_cap("player", "mining"), int(DB.skill_curve.get("max_level", 20)), "so does mining (metallurgy; the Mining XP hotfix)")
	eq(Workers.growth_cap("borin", "alchemy"), int(DB.skill_curve.get("max_level", 20)), "a field hireling's progression is not capped")
	var j0 := (Game.state["journal"] as Array).size()
	for i in 200:
		Game.grant_player_xp("runecraft", 400)
	eq(Game.player_level("runecraft"), Workers.BASIC_LEVEL, "new runecraft experience stops at the basic level")
	eq(int(Game.player_skills()["runecraft"]["xp"]), 0, "and is not banked")
	check(not Workers.can_grow("player", "runecraft"), "the smith can no longer grow in runecraft")
	var lines := (Game.state["journal"] as Array).slice(j0).filter(func(e): return str(e["text"]).contains("Mastery of it belongs to a runesmith"))
	eq(lines.size(), 1, "the smith notes it once in his journal")
	train("smithing", 9)
	eq(Game.player_level("smithing"), 9, "smithing grows past it")
	# a capped skill's record says what was really gained
	Property.dev_grant_all()
	SkillTree.unlock_all()
	give("runestone_blank", 1)
	give("reagent_salt", 2)
	Vitality.set_fatigue(0.0)
	var it := craft("ward_runestone", 95.0, {"resonance": 6, "fortune": 40, "purity": 3})
	if check(not it.is_empty(), "the smith cuts a ward runestone (%s)" % craft_blocker("ward_runestone")):
		check(not (it.get("craft", {}).get("xp", {}) as Dictionary).has("runecraft"), "its record claims no runecraft experience")
	# an old save's higher level is kept and never reduced
	Game.player_skills()["alchemy"] = {"lvl": 9, "xp": 123}
	Game.grant_player_xp("alchemy", 5000)
	eq(Game.player_level("alchemy"), 9, "an earned alchemy 9 is kept")
	eq(int(Game.player_skills()["alchemy"]["xp"]), 123, "…with its experience untouched (no new growth)")
	eq(Crafting.recipe_locked_reason("wyrmfire_coating"), "", "and he keeps doing what it lets him do")
	(Game.state["player"] as Dictionary).erase("profession")
	check(save_as_version("suite_lwf_cap", 4), "written as a schema-4 save")
	check(Saves.load_slot("suite_lwf_cap"), "it loads")
	Saves.delete("suite_lwf_cap")
	eq(Game.player_level("alchemy"), 9, "after migration 5 the smith still has alchemy 9")
	eq(str(Game.state["player"].get("profession", "")), "blacksmith", "and is recorded as the blacksmith")


# ------------------------------------------------------------------ specialists own their craft
func test_specialists_not_limited_by_the_smith() -> void:
	_workshop()
	check(Crafting.recipe_locked_reason("concord_runestone") != "", "the smith cannot make a Concord runestone himself")
	var rune := Apprentices.dev_take_on("runesmith", 8, "master")
	if not check(not rune.is_empty(), "a master runesmith joins"):
		return
	eq(Apprentices.can_make(rune, "concord_runestone"), "", "the runesmith can")
	check(Apprentices.recipes_for(rune).any(func(r): return str(r["id"]) == "concord_runestone"), "their list offers it")
	var inputs: Dictionary = DB.recipe("concord_runestone")["inputs"]
	for d in inputs:
		give(str(d), int(inputs[d]))
	var t := Apprentices.add_task("craft", {"recipe": "concord_runestone", "assignee": str(rune["id"])})
	if not check(not t.has("error"), "the Concord runestone is queued for them (%s)" % t.get("error", "")):
		return
	_run_until_done(t)
	check(str(t["state"]) == "done" and not (t["made"] as Array).is_empty(), "the runesmith finished it (%s %s)" % [t["state"], t.get("blocker", "")])
	if (t["made"] as Array).is_empty():
		return
	var it := Game.find_uid(int(t["made"][0]))
	eq(str(it.get("craft", {}).get("maker", "")), str(rune["id"]), "the runesmith is its maker")
	eq(int(it.get("craft", {}).get("level", 0)), 8, "made at the runesmith's own level")
	eq(str(it.get("crafted_by", "")), str(rune["name"]), "and it carries their name")


# ------------------------------------------------------------------ the skill-tree seam
func test_tree_seam_specialist_meets_another_crafts_node() -> void:
	fresh_game()
	Property.dev_grant_all()
	Game.state["gold"] = 20000
	for nid in ["r_identify", "r_clean", "r_blank", "r_engrave", "r_stabilise", "r_original", "r_combo"]:
		SkillTree.unlock_node_force(nid)
	Game.player_skills()["runecraft"] = {"lvl": Workers.BASIC_LEVEL, "xp": 0}
	var req := SkillTree.requirements("r_master")
	check(req.any(func(x): return str(x["kind"]) == "skill" and not bool(x["ok"])), "the master rune node needs Runecraft 6 — beyond the smith")
	check(req.any(func(x): return str(x["kind"]) == "skill" and str(x["hint"]).contains("runesmith")), "its hint says a runesmith meets it")
	var rune := Apprentices.dev_take_on("runesmith", 6, "journeyman")
	if not check(not rune.is_empty(), "a runesmith joins"):
		return
	var req2 := SkillTree.requirements("r_master")
	check(req2.any(func(x): return str(x["kind"]) == "skill" and bool(x["ok"]) and str(x["text"]).contains(str(rune["name"]))),
		"the runesmith's level meets it: %s" % str(req2.map(func(x): return x["text"])))
	eq(SkillTree.unlock("r_master"), "", "the workshop learns the master rune node")
	# the smith's own tree stays his
	var bs := Apprentices.dev_take_on("blacksmith", 12, "master")
	if check(not bs.is_empty(), "a master blacksmith joins"):
		check(SkillTree.requirements("s_master").any(func(x): return str(x["kind"]) == "skill" and not bool(x["ok"])),
			"smithing nodes still need the smith's own level (the deep smithing tree)")
	# room tiers count the room's best hand
	eq(Workers.best_level("runecraft")["actor"], str(rune["id"]), "the runesmith is the forge's best rune hand")


# ------------------------------------------------------------------ save step 5
func test_migration_5_golden_saves() -> void:
	for g in GOLDEN:
		var data := _golden_data(g)
		if not check(not data.is_empty(), "%s parses" % g):
			continue
		SaveMigrations.run(data, 4)
		var staff: Array = data.get("apprentices", {}).get("staff", [])
		var before := staff.map(func(a): return _without_profession(a))
		var player_before := JSON.stringify(data["player"]["skills"], "", true)
		var hire_before := JSON.stringify(data.get("hirelings", []), "", true)
		var rep := SaveMigrations.run(data, 5)   # step 5 itself (later steps have their own tests)
		eq(rep["steps"], ["worker professions"], "%s: step 5 runs" % g)
		eq(int(data["version"]), 5, "%s: now schema 5" % g)
		eq(str(data["player"].get("profession", "")), "blacksmith", "%s: the smith is the blacksmith" % g)
		eq(JSON.stringify(data["player"]["skills"], "", true), player_before, "%s: the smith keeps every level" % g)
		eq(JSON.stringify(data.get("hirelings", []), "", true), hire_before, "%s: field hirelings are untouched" % g)
		for i in staff.size():
			check(Workers.PROFESSIONS.has(str(staff[i].get("profession", ""))), "%s: %s has a profession (%s)" % [g, staff[i]["name"], staff[i].get("profession", "")])
			eq(_without_profession(staff[i]), before[i], "%s: %s keeps everything else" % [g, staff[i]["name"]])
		for c in data.get("apprentices", {}).get("applicants", []):
			check(Workers.PROFESSIONS.has(str(c.get("profession", ""))), "%s: a waiting applicant has a profession" % g)
		var once := JSON.stringify(data, "", true)
		SaveMigrations.apply_step(5, data)
		eq(JSON.stringify(data, "", true), once, "%s: step 5 again changes nothing" % g)


func test_migration_5_schema4_save_with_apprentices() -> void:
	_workshop()
	var a := Apprentices.dev_take_on("runesmith", 4, "apprentice")
	var b := Apprentices.dev_take_on("leatherworker", 5, "journeyman")
	var c := Apprentices.dev_take_on("blacksmith", 3, "apprentice")
	if not check(not a.is_empty() and not b.is_empty() and not c.is_empty(), "three apprentices"):
		return
	# make them old-save apprentices: a generalist whose strongest skill is runecraft but who leaned to smithing;
	# a tie broken by the preferred discipline; one with only smithing
	a["skills"]["smithing"] = {"lvl": 3, "xp": 40}
	a["skills"]["runecraft"] = {"lvl": 6, "xp": 77}
	a["prefs"] = ["classic"]
	b["skills"]["alchemy"] = {"lvl": 5, "xp": 10}
	b["prefs"] = ["alchemy"]
	a["traits"] = ["careful"]
	a["wage"] = 9
	a["works"] = 41
	Apprentices.remember(a, "An old memory.")
	give("ore_iron", 4)
	give("coal", 4)
	var t := Apprentices.add_task("prep", {"recipe": "smelt_iron", "repeat": 2, "assignee": str(c["id"])})
	check(not t.has("error"), "a task in the queue")
	for x in [a, b, c]:
		x.erase("profession")
	Game.player_skills()["runecraft"] = {"lvl": 8, "xp": 5}
	(Game.state["player"] as Dictionary).erase("profession")
	var keep := {}
	for x in [a, b, c]:
		keep[str(x["id"])] = _without_profession(x)
	var tasks := _queue_text(Apprentices.tasks())
	check(save_as_version("suite_lwf_v4", 4), "written as a schema-4 save")
	check(Saves.load_slot("suite_lwf_v4"), "it loads")
	var rep: Dictionary = Saves.last_load.get("migration", {})
	eq((rep.get("steps", []) as Array).slice(0, 1), ["worker professions"], "step 5 runs first (later steps follow)")
	eq(str(Apprentices.get_a(str(a["id"])).get("profession", "")), "runesmith", "the strongest skill decides (runecraft 6 over smithing 3)")
	eq(str(Apprentices.get_a(str(b["id"])).get("profession", "")), "alchemist", "a tie goes to the preferred discipline (alchemy 5 = stitching 5)")
	eq(str(Apprentices.get_a(str(c["id"])).get("profession", "")), "blacksmith", "a smithing apprentice becomes a blacksmith")
	for id in keep:
		eq(_without_profession(Apprentices.get_a(str(id))), keep[id], "%s keeps every level, experience point, trait, wage, memory and log" % Apprentices.get_a(str(id)).get("name", id))
	eq(_queue_text(Apprentices.tasks()), tasks, "the queue is unchanged (beyond the work-order fields a later step adds)")
	eq(Game.player_level("runecraft"), 8, "the smith keeps runecraft 8")
	# idempotent: saving and loading again changes nothing
	var snap := JSON.stringify(Apprentices.st(), "", true)
	check(Saves.save("suite_lwf_v4") and Saves.load_slot("suite_lwf_v4"), "saved and loaded again")
	Saves.delete("suite_lwf_v4")
	eq((Saves.last_load.get("migration", {}).get("steps", ["?"]) as Array).size(), 0, "a schema-5 save runs no step")
	eq(JSON.stringify(Apprentices.st(), "", true), snap, "and nothing changed")


# ------------------------------------------------------------------ guards that must still hold
func test_steward_zero_xp_and_mining_hotfix_hold() -> void:
	train("smithing", 6)
	Property.dev_grant_all()
	var app := Apprentices.dev_take_on("blacksmith", 4, "apprentice")
	var xp0 := JSON.stringify(Game.player_skills())
	eq(Steward.activate(), "", "the steward takes over")
	Workers.grant_xp("player", "smithing", 500)
	Workers.grant_xp("player", "runecraft", 500)
	eq(JSON.stringify(Game.player_skills()), xp0, "under the steward the smith gains nothing, through Workers too")
	if not app.is_empty():
		var x0 := int(app["skills"]["smithing"]["xp"]) + 1000 * int(app["skills"]["smithing"]["lvl"])
		Workers.grant_xp(app, "smithing", 30)
		check(int(app["skills"]["smithing"]["xp"]) + 1000 * int(app["skills"]["smithing"]["lvl"]) > x0, "employees still progress by the normal rules")
	Steward.deactivate()
	# the Mining XP hotfix: an expert smith still learns Mining from smelting at the full rate while he is no expert
	# miner — and Mining (his profession's metallurgy) grows past the basic level
	Game.player_skills()["smithing"] = {"lvl": 9, "xp": 0}
	Game.player_skills()["mining"] = {"lvl": 6, "xp": 0}
	SkillTree.unlock_all()
	give("ingot_iron", 2)
	give("coal", 2)
	Vitality.set_fatigue(0.0)
	var m0 := int(Game.player_skills()["mining"]["xp"])
	var it := craft("smelt_steel", 80.0, {"purity": 3})
	if check(not it.is_empty(), "the smith smelts steel (%s)" % craft_blocker("smelt_steel")):
		eq(int(Game.player_skills()["mining"]["xp"]) - m0, int(round(24.0 * (0.6 + float(it["quality"]) / 200.0))), "Mining 6 still learns at the full rate from steel (not an expert miner for it)")
		check(Workers.can_grow("player", "mining"), "Mining is not capped at the basic level")
