## Core: startup data, a new game's state, crafting from starting facilities, item statistics, save/load.
extends SuiteCase

const SMOKE := ["test_startup", "test_iron_longsword_from_new_game", "test_save_load"]


func test_startup() -> void:
	check(DB.items.size() > 50 and DB.recipes.size() > 30 and DB.stations.size() > 20, "data: items, recipes and stations load")
	check(not DB.layout.is_empty() and DB.building("smithy").has("units"), "data: the village layout with the smithy's units")
	for k in ["player", "property", "hirelings", "adventurers", "orders", "customers", "chronicle", "exp"]:
		check(Game.state.has(k), "new game: state has '%s'" % k)
	check(Game.gold() > 0 and Game.player_level("smithing") >= 1, "new game: gold and skills")


func test_iron_longsword_from_new_game() -> void:
	var before := {}
	var r := DB.recipe("iron_longsword")
	for id in r["inputs"]:
		before[id] = Game.count(id)
	var why := craft_blocker("iron_longsword")
	if not check(why == "", "1-2. a new game can forge an iron longsword with its starting facilities (%s)" % why):
		return
	var it := craft("iron_longsword", 95.0)
	check(it.get("def", "") == "sword_iron", "crafting: the longsword is made")
	for id in r["inputs"]:
		eq(Game.count(id), int(before[id]) - int(r["inputs"][id]), "inventory: %s consumed exactly" % id)
	check(int(it.get("uid", 0)) > 0 and it.has("craft") and it.get("owner", "") == "smith" and not (it.get("history", []) as Array).is_empty(), "items: instance with uid, craft record, owner and history")
	var atk: Variant = it.get("stats", {}).get("attack", 0)
	check(Items.stat(it, "attack") > 0, "items: the blade has attack (%s)" % str(atk))


func test_item_stats_valid() -> void:
	for def in DB.items:
		var it := Items.make(def, {"quality": 100.0})
		for k in it.get("stats", {}):
			var v: Variant = it["stats"][k]
			if v is Array:
				check((v as Array).size() == 2 and float(v[0]) <= float(v[1]) and float(v[0]) >= 0.0, "items: %s.%s range %s" % [def, k, str(v)])
			elif v is float or v is int:
				check(float(v) >= 0.0, "items: %s.%s = %s is not negative" % [def, k, str(v)])
		check(int(DB.item(def).get("value", 0)) >= 0, "items: %s has a value" % def)


func test_no_negative_or_duplicate_inventory() -> void:
	craft("iron_longsword", 90.0)
	var seen := {}
	for it in Game.inventory():
		check(int(it.get("qty", 1)) > 0, "inventory: %s quantity positive" % it.get("def", "?"))
		check(not seen.has(int(it["uid"])), "inventory: uid %d unique" % int(it["uid"]))
		seen[int(it["uid"])] = true


func test_save_load() -> void:
	var it := craft("iron_longsword", 97.0)
	var uid := int(it.get("uid", -1))
	Game.state["gold"] = 777
	check(save_load("suite_core"), "saves: write and read in the test folder")
	eq(Game.gold(), 777, "saves: gold restored")
	check(not Game.find_uid(uid).is_empty(), "saves: the crafted instance is restored")
	check(not FileAccess.file_exists("user://saves/suite_core.json"), "saves: the real save folder was not used")
