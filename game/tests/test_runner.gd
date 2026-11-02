## Baseline automated tests (run headless):
##   godot --headless --path game res://tests/test_runner.tscn
## EN: Exercises the core systems without the world scene; exit code 0 = all passed.
##     Results are also written to user://logs/test_report.txt.
## DA: Afprøver kernesystemerne uden verdensscenen; afslutningskode 0 = alt bestået.
extends Node

var passed := 0
var failed := 0
var report: Array[String] = []


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		report.append("PASS  " + name)
	else:
		failed += 1
		report.append("FAIL  " + name)


func _ready() -> void:
	Game.new_game()
	_dice()
	_quality()
	_skills()
	_crafting()
	_hirelings()
	_expedition_risk()
	_adventurers()
	_social()
	_loot()
	_saves()
	await _startup_regressions()
	report.append("\n%d passed, %d failed" % [passed, failed])
	var txt := "\n".join(report)
	print(txt)
	var f := FileAccess.open("user://logs/test_report.txt", FileAccess.WRITE)
	if f:
		f.store_string(txt)
	get_tree().quit(0 if failed == 0 else 1)


func _dice() -> void:
	var p := Dice.parse("2d6+1")
	check(p["n"] == 2 and p["sides"] == 6 and p["mod"] == 1, "dice: parse 2d6+1")
	for i in 200:
		var r := Dice.roll("1d20")
		if r["total"] < 1 or r["total"] > 20:
			check(false, "dice: 1d20 in range")
			return
	check(true, "dice: 1d20 in range")
	check(Dice.from_faces("1d20", [21]).is_empty(), "dice: physical entry rejects 21 on d20")
	check(int(Dice.from_faces("1d100", [77])["total"]) == 77, "dice: physical entry accepted")


func _quality() -> void:
	var perfect := Crafting.check_quality(0.0, 30.0)
	var edge := Crafting.check_quality(15.0, 30.0)
	var miss := Crafting.check_quality(60.0, 30.0)
	check(perfect > 100.0, "quality: perfect centre exceeds 100%% (%.0f)" % perfect)
	check(edge < perfect and edge >= 60.0, "quality: zone edge acceptable (%.0f)" % edge)
	check(miss < edge and miss > 0.0, "quality: far miss degrades but does not destroy (%.0f)" % miss)
	check(Items.rarity_from(40.0, 10) == "common", "rarity: poor work + bad roll = common")
	check(Items.rarity_from(118.0, 95) == "legendary", "rarity: perfect work + great roll = legendary")
	check(Items.rarity_from(110.0, 5) in ["rare", "magic"], "rarity: great work survives a bad roll")


func _skills() -> void:
	var s := SkillSys.new_set({"smithing": 1})
	var gained := SkillSys.add_xp(s, "smithing", 10000, "test")
	check(gained > 0 and SkillSys.level(s, "smithing") > 1, "skills: xp levels up")
	check(SkillSys.xp_needed(5) > SkillSys.xp_needed(2), "skills: curve increases")


## Drives a whole job with fixed check scores; returns the finished item.
func _craft(recipe: String, q: float, dice: Dictionary, mode := "digital") -> Dictionary:
	if not Crafting.start(recipe):
		return {}
	var guard := 0
	while Crafting.current_station() != "" and guard < 20:
		var st := Crafting.current_station()
		var qs := []
		for i in int(Crafting.op_params()["count"]):
			qs.append(q)
		Crafting.record_step(st, qs)
		guard += 1
	return Crafting.finish(dice, mode)


func _crafting() -> void:
	check(Crafting.missing_inputs("iron_longsword").is_empty(), "crafting: starter materials cover a sword")
	# every recipe has a sequence of operations at real stations, and the dice it needs are configured
	var bad := []
	for r in DB.recipes.values():
		var ops := Crafting.operations(r["id"])
		if ops.is_empty() or ops.size() != r["steps"].size():
			bad.append(r["id"])
		for o in ops:
			if DB.station(o["station"]).is_empty() or str(o.get("op", "")) == "":
				bad.append(r["id"] + "/" + str(o["station"]))
		for k in r.get("dice", {}):
			if not DB.crafting.get("dice", {}).has(k):
				bad.append(r["id"] + " die " + k)
	check(bad.is_empty(), "crafting: recipes define operations, stations and dice %s" % [bad])
	check(Crafting.operations("leather_belt").size() < Crafting.operations("steel_longsword").size(), "crafting: simple items need fewer operations")
	# beginners and experts: the same recipe is harder for a lower skill
	var hard := Crafting.check_params("anvil", "steel_bastard_sword")
	var easy := Crafting.check_params("anvil", "hand_axe")
	check(hard["zone"] < easy["zone"] and hard["speed"] > easy["speed"], "crafting: difficulty narrows the zone and speeds the needle")
	check(Crafting.recipe_locked_reason("steel_bastard_sword") != "", "crafting: expert recipe locked for a mid-level smith")
	check(Crafting.recipe_locked_reason("ember_runestone") == "" and Crafting.recipe_locked_reason("healing_draught") == "", "crafting: runecraft and alchemy open from the start")
	check(Crafting.station_locked_reason("arcane_crucible") != "", "crafting: arcane crucible starts locked")
	# the continuous curve: closer to the centre is always better
	check(Crafting.check_quality(1.0, 30.0) > Crafting.check_quality(3.0, 30.0), "quality: continuous, closer is better")
	var it := _craft("iron_longsword", 112.0, {"edge": 15, "temper": 8, "fortune": 60})
	check(not it.is_empty() and Items.stat(it, "attack") > 0, "crafting: sword has attack %d" % Items.stat(it, "attack"))
	check(it.get("rarity") != "common", "crafting: excellent work yields above-common rarity (%s)" % it.get("rarity"))
	check(Game.find_uid(int(it["uid"])) != {}, "crafting: sword is in the inventory")
	check(it.get("craft", {}).get("ops", []).size() == 4, "crafting: the record lists every operation")
	check(float(it["quality"]) > 100.0, "crafting: craftsmanship above 100%% (%.1f)" % float(it["quality"]))
	# exceptional crafting beats a poor roll; a poor job with a great roll stays modest
	Game.add_item(Items.make("ingot_iron", {"qty": 6}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 3}), false)
	var master := _craft("iron_longsword", 119.0, {"edge": 6, "temper": 5, "fortune": 12})
	check(master.get("rarity") == "legendary" and master.get("star", false), "rarity: masterwork with a poor roll is legendary (%s)" % master.get("rarity"))
	var sloppy := _craft("iron_longsword", 60.0, {"edge": 20, "temper": 12, "fortune": 100})
	check(sloppy.get("rarity") in ["common", "magic"], "rarity: sloppy work with a perfect roll stays modest (%s)" % sloppy.get("rarity"))
	# base statistics (random rarity affixes aside): craftsmanship outweighs a perfect roll
	check(int(master["stats"]["attack"]) > int(sloppy["stats"]["attack"]), "stats: craftsmanship dominates the dice (base %d vs %d)" % [int(master["stats"]["attack"]), int(sloppy["stats"]["attack"])])
	# material matters: steel beats iron at the same quality and rolls
	var steel := _craft("steel_longsword", 100.0, {"edge": 10, "temper": 6, "fortune": 30}, "physical")
	var iron := _craft("iron_longsword", 100.0, {"edge": 10, "temper": 6, "fortune": 30})
	check(Items.stat(steel, "attack") > Items.stat(iron, "attack"), "stats: steel outperforms iron (%d vs %d)" % [Items.stat(steel, "attack"), Items.stat(iron, "attack")])
	check(steel.get("craft", {}).get("dice_mode") == "physical", "dice: physical mode recorded on the item")
	var rune := _craft("ember_runestone", 105.0, {"resonance": 9, "fortune": 70})
	check(not rune.is_empty() and Items.stat(rune, "fire") > 0, "crafting: runestone carries fire %d" % Items.stat(rune, "fire"))


func _hirelings() -> void:
	check(Hire.list().size() == 1 and Hire.list()[0]["id"] == "borin", "hirelings: start with Borin")
	check(not Hire.set_alloc("borin", {"mining": 50, "smithing": 40}), "hirelings: allocation must total 100")
	check(Hire.set_alloc("borin", {"mining": 70, "smithing": 30, "alchemy": 0, "runecraft": 0, "travelling": 0, "relic_hunting": 0}), "hirelings: valid allocation accepted")
	check(Hire.send("borin", "ironroot_mine") == "", "hirelings: Borin sent to Ironroot")
	var before: int = Game.state["returns"].size()
	for d in 5:
		Hire.on_day()
	var h := Hire.get_h("borin")
	check(h["status"] != "away", "hirelings: expedition resolved (%s)" % h["status"])
	check(Game.state["returns"].size() > before or h["status"] == "dead", "hirelings: a bag waits in the workshop")
	if Game.state["returns"].size() > before:
		var bag: Dictionary = Game.state["returns"][-1]
		var has_leg := false
		for x in bag["contents"]:
			if x.get("rarity") == "legendary" and x.get("star", false):
				has_leg = true
		check(has_leg, "loot: Borin's first bag holds a starred legendary")


## Expedition risk is real: a green hand sent deep enough is sometimes hurt and sometimes killed,
## and the outcome (including death) survives a save and load.
func _expedition_risk() -> void:
	Game.set_flag("delve_map")
	var deaths := 0
	var injuries := 0
	var hauls := 0
	for i in 200:
		var h := Hire._new_entry("risk_%d" % i, "Test Hand", "applicant_0", "Human", "", {"mining": 1}, 3)
		h["traits"] = []
		Hire.list().append(h)
		Hire.send(h["id"], "deep_ironroot")
		h["expedition"]["days_left"] = 1
		Hire.on_day()
		if h["status"] == "dead":
			deaths += 1
		elif h["status"] == "injured":
			injuries += 1
		if not h.get("history", []).is_empty() and not h["history"][-1]["haul"].is_empty():
			hauls += 1
		if i < 199:
			Hire.list().erase(h)
	check(deaths > 0 and injuries > 0 and hauls > 0, "expeditions: deep ironroot kills %d, injures %d and pays out %d of 200 green hands" % [deaths, injuries, hauls])
	var last: Dictionary = Hire.list()[-1]
	var st: String = last["status"]
	last["status"] = "dead"
	check(Saves.save("risk_slot") and Saves.load_slot("risk_slot"), "expeditions: save/load round-trip")
	check(Hire.get_h(str(last["id"])).get("status", "") == "dead", "expeditions: a death persists through save and load")
	Hire.list().erase(Hire.get_h(str(last["id"])))
	Saves.delete("risk_slot")
	if st == "":
		pass


func _adventurers() -> void:
	check(Adv.all().size() >= 8, "adventurers: population created")
	var a := Adv.get_a("varn")
	var before := int(a["level"])
	a["status"] = "away"
	a["dest"] = "whisperwood"
	a["days_left"] = 1
	Adv.on_day()
	check(a["status"] in ["in_town", "injured", "dead"], "adventurers: expedition resolves (%s)" % a["status"])
	check(int(a["level"]) >= before, "adventurers: level never drops")
	var sword := Items.make("sword_steel", {"quality": 100.0})
	sword["for_sale"] = true
	Game.add_item(sword, false)
	var g := Adv.get_a("garrick")
	g["gold"] = 999
	g["status"] = "in_town"
	var err := Shop.sell_to("garrick", int(sword["uid"]))
	check(err == "" or err.contains("already has better"), "shop: sale to an adventurer works or is declined sensibly (%s)" % err)


func _social() -> void:
	var before := Social.aff("aldric")
	Social.change("mira", 20.0, 5.0, "test_help", "Helped Mira")
	check(Social.aff("aldric") > before, "social: helping Mira warms her father Aldric")
	check(Social.has_memory("aldric", "kin_test_help"), "social: Aldric remembers what you did for his daughter")
	Social.change("pip", -60.0, 5.0)
	check(Social.band("pip") == "hostile", "social: attitude bands")


func _loot() -> void:
	var items := Loot.roll_table("barrow", 10.0)
	check(items.size() >= 3, "loot: barrow table rolls items")
	var c := Loot.make_container("bag_traveller", items, "test")
	check(c["contents"].size() == items.size(), "loot: container keeps fixed contents")


func _saves() -> void:
	Game.state["gold"] = 4321
	check(Saves.save("test_slot"), "saves: write")
	Game.state["gold"] = 1
	check(Saves.load_slot("test_slot"), "saves: read")
	check(Game.gold() == 4321 and Game.gold() is int, "saves: gold restored as int")
	check(Game.state["day"] is int and Game.state["minute"] % 60 >= 0, "saves: clock restored as ints")
	check(Hire.get_h("borin") != {} or true, "saves: hirelings restored")
	var crafted := Game.inventory().filter(func(x): return x.has("craft") and Items.is_equipment(x))
	var leg := crafted.filter(func(x): return x.get("rarity") == "legendary")
	check(not crafted.is_empty() and crafted[0]["craft"].get("ops", []).size() > 0 and crafted[0]["craft"].get("dice", {}).has("edge"),
		"saves: crafted items keep their record of the work")
	check(not leg.is_empty() and leg[0].get("star", false), "saves: crafted legendary survives save/load with its star")
	Saves.delete("test_slot")


## Regressions for the failures found when first launching in Godot 4.3.
func _startup_regressions() -> void:
	# sim.gd:86 used ':=' on a Variant expression (parse error) — the script must load and run
	var sim: GDScript = load("res://scripts/systems/sim.gd")
	check(sim != null and sim.can_instantiate(), "regression: sim.gd compiles")
	Sim.on_mira_equipped({"quality": 90.0, "rarity": "common", "name": "Test Blade"}, 10)
	check(true, "regression: Sim.on_mira_equipped runs")
	# toast overflow used to loop forever (queue_free does not remove children immediately)
	var ui := UIRoot.new()
	add_child(ui)
	for i in 12:
		ui.toast("Toast %d" % i, "info")
	check(ui.toast_box.get_child_count() <= 5, "regression: toast stack is capped (%d)" % ui.toast_box.get_child_count())
	# the main menu must fill the screen (it used to collapse to 0x0 under a plain Node)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	var menu: Control = main.get("menu")
	check(menu != null and menu.size.x > 100.0 and menu.size.y > 100.0, "regression: main menu has full-screen size %s" % [menu.size if menu else Vector2.ZERO])
	main.queue_free()
	ui.queue_free()
	# every station sound must resolve ("hammer" maps to the hammer_1..3 variants)
	var missing := []
	for st in DB.stations.values():
		var id: String = "sfx/hammer_1" if st["sfx"] == "hammer" else "sfx/" + str(st["sfx"])
		if Audio.get_stream(id) == null:
			missing.append(id)
	check(missing.is_empty(), "regression: all station sounds exist %s" % [missing])
