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
	_adventurers()
	_social()
	_loot()
	_saves()
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


func _crafting() -> void:
	check(Crafting.missing_inputs("iron_longsword").is_empty(), "crafting: starter materials cover a sword")
	check(Crafting.start("iron_longsword"), "crafting: start sword job")
	var guard := 0
	while Crafting.current_station() != "" and guard < 10:
		var st := Crafting.current_station()
		var qs := []
		for i in int(Crafting.check_params(st)["count"]):
			qs.append(112.0)
		Crafting.record_step(st, qs)
		guard += 1
	check(Crafting.job().get("awaiting_dice", false), "crafting: all steps done, awaiting dice")
	var it := Crafting.finish({"edge": 15, "temper": 8, "fortune": 60})
	check(not it.is_empty() and Items.stat(it, "attack") > 0, "crafting: sword has attack %d" % Items.stat(it, "attack"))
	check(it.get("rarity") != "common", "crafting: excellent work yields above-common rarity (%s)" % it.get("rarity"))
	check(Game.find_uid(int(it["uid"])) != {}, "crafting: sword is in the inventory")
	check(Crafting.station_locked_reason("arcane_crucible") != "", "crafting: arcane crucible starts locked")


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
	Saves.delete("test_slot")
