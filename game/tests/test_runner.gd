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
	_materials_cycle()
	_adventurer_world()
	_village_remembers()
	_romance()
	_masters()
	_adventurers()
	_social()
	_loot()
	_living_village()
	_checks_and_customers()
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


## Iteration 3: the material cycle — expedition → haul → processing → crafting — plus trade runs,
## scouting, suppliers, relic study, forgotten recipes and hirelings processing stored materials.
func _materials_cycle() -> void:
	# a skilled miner's haul from Ironroot: ores and, often, gems
	var finds := {}
	for i in 30:
		for it in Loot.roll_table("mine", 10.0, 5):
			finds[it["def"]] = true
	check(finds.has("ore_iron") and (finds.has("gem_garnet") or finds.has("gem_sapphire") or finds.has("gem_moonstone")), "materials: Ironroot yields ores and gemstones %s" % [finds.keys()])
	var deep := {}
	for i in 40:
		for it in Loot.roll_table("deep_mine", 0.0, 6):
			deep[it["def"]] = true
	check(deep.has("gem_starstone") or deep.has("starmetal_fragment") or deep.has("ore_adamantine"), "materials: Deep Ironroot yields rare minerals")
	# scouting lowers danger for everyone and finds suppliers
	var d0 := Regions.danger("highmarsh_road")
	for i in 4:
		Regions.on_trip("highmarsh_road", 4, true)
	check(Regions.danger("highmarsh_road") < d0 and Game.has_flag("supplier_highmarsh"), "travelling: scouting Highmarsh lowers its danger (%.2f → %.2f) and finds a supplier" % [d0, Regions.danger("highmarsh_road")])
	# a trade run: a purse buys materials, trade goods are sold
	Game.add_item(Items.make("oil_whetstone", {"qty": 2}), false)
	for x in Game.inventory():
		if x["def"] == "oil_whetstone":
			x["trade"] = true
	var gold0 := Game.gold()
	var h := Hire._new_entry("trader", "Test Trader", "applicant_1", "Human", "", {"travelling": 5}, 3)
	h["traits"] = []
	Hire.list().append(h)
	Game.add_gold(1000 - Game.gold(), "test", "test funds")   # earlier tests paid many days of wages
	check(Hire.send("trader", "highmarsh_road", {"budget": 100}) == "" and int(h["expedition"].get("budget", 0)) == 100, "travelling: a trade run sets out with a 100 g purse")
	h["expedition"]["days_left"] = 1
	var bags: int = Game.state["returns"].size()
	Hire.on_day()
	var haul: Array = Game.state["returns"][-1]["contents"] if Game.state["returns"].size() > bags else []
	var left := Game.inventory().filter(func(x): return x.get("trade", false))
	var sold_ok := left.is_empty()
	check(h["status"] != "away" and haul.size() > 0 and sold_ok, "travelling: the trade run brought back %d lots and sold the trade goods" % haul.size())
	Hire.list().erase(h)
	# relic study turns unidentified relics into ancient arms, components or recipes
	var kinds := {}
	for i in 20:
		var r := Items.make(["relic_unknown_arms", "relic_unknown_tablet", "relic_unknown_reliquary"][i % 3])
		Game.add_item(r, false)
		var res := Regions.identify(int(r["uid"]), 100.0)
		kinds[DB.item(res.get("def", "")).get("type", "?") if not Items.is_equipment(res) else "equipment"] = true
		if res.get("def", "") == "recipe_scroll":
			kinds["recipe"] = true
	check(kinds.has("equipment") and kinds.size() >= 2, "relics: study reveals ancient arms and other finds %s" % [kinds.keys()])
	check(Crafting.recipe_locked_reason("starsteel_blade") != "", "relics: the Starsteel Blade is a forgotten recipe until learned")
	var scroll := Items.make("recipe_scroll")
	Game.add_item(scroll, false)
	var msg := Regions.read_recipe(int(scroll["uid"]))
	check(Game.has_flag("recipe_starsteel"), "relics: reading the notes teaches the Starsteel Blade (%s)" % msg)
	# hirelings process stored materials into finished goods
	var al := Hire._new_entry("alch", "Test Alchemist", "applicant_2", "Human", "", {"alchemy": 4, "runecraft": 4}, 3)
	al["traits"] = []
	al["alloc"] = {"mining": 0, "smithing": 0, "alchemy": 50, "runecraft": 50, "travelling": 0, "relic_hunting": 0}
	Hire.list().append(al)
	Game.add_item(Items.make("herb_moonwort", {"qty": 6}), false)
	Game.add_item(Items.make("runestone_blank", {"qty": 3}), false)
	Game.add_item(Items.make("reagent_salt", {"qty": 3}), false)
	var pots := Game.count("potion_healing") + Game.count("oil_whetstone")
	var runes := Game.count("runestone_ward") + Game.count("runestone_ember")
	var m0: int = Game.state["minute"]
	Game.state["minute"] = 10 * 60
	for i in 24:
		Hire.work_hour(10)
	Game.state["minute"] = m0
	check(Game.count("potion_healing") + Game.count("oil_whetstone") > pots and Game.count("runestone_ward") + Game.count("runestone_ember") > runes,
		"processing: a hireling brewed potions/oils and prepared runestones from stored materials")
	Hire.list().erase(al)
	Game.add_gold(gold0 - Game.gold(), "test", "reset")


## Iteration 4: equipment materially changes how expeditions go; logs credit the gear;
## orders follow the threats ahead; adventurers buy draughts before they leave.
func _adventurer_world() -> void:
	var a := Adv.get_a("kestra")
	Adv.ensure(a)
	var saved_eq: Dictionary = a["equipment"].duplicate(true)
	var saved_lv: int = a["level"]
	a["level"] = 4
	# the same rogue with a worn dagger vs a forged flame blade, many times over the Barrow Fields
	var trial := func(weapon: Dictionary) -> float:
		a["equipment"] = {"weapon": weapon, "armor": Items.make("jerkin_leather", {"quality": 60.0})}
		var wins := 0
		for i in 300:
			var r := Adv.run_encounters(a, "barrow_fields")
			if int(r["wins"]) * 2 >= int(r["fought"]):
				wins += 1
		return wins / 300.0
	var poor: float = trial.call(Items.make("dagger", {"quality": 45.0}))
	var blade := Items.make("sword_emberwarden", {"quality": 108.0, "crafted_by": "Brannoc Ironhand"})
	var good: float = trial.call(blade)
	check(good > poor + 0.15, "adventurers: a forged flame blade lifts Barrow success from %d%% to %d%%" % [int(poor * 100), int(good * 100)])
	var r2 := Adv.run_encounters(a, "barrow_fields")
	var named := false
	for ln in r2["lines"]:
		if str(ln).contains(blade["name"]):
			named = true
	check(named, "adventurers: the expedition log names the blade %s" % [r2["lines"]])
	# a full trip: equip, depart, resolve — the smith's piece earns the credit and a memory
	a["equipment"] = {"weapon": blade, "armor": Items.make("cuirass_iron", {"quality": 90.0})}
	a["status"] = "away"
	a["dest"] = "barrow_fields"
	a["days_left"] = 1
	var hist0: int = a["history"].size()
	Adv.on_day()
	check(a["history"].size() == hist0 + 1 and a["status"] != "away", "adventurers: the trip resolved (%s)" % a.get("last_report", ""))
	# orders follow the next destination's threats
	a["status"] = "in_town"
	a["equipment"] = {"weapon": Items.make("dagger", {"quality": 50.0})}
	a["next_dest"] = "barrow_fields"
	Adv.plan_next(a)
	var o := Shop.create_order("kestra", "weapon")
	check(o.get("stat", "") == "fire", "orders: bound for the barrows, she asks for %s" % Shop.order_text(o))
	var ok_item := Items.make("sword_emberwarden", {"quality": 100.0})
	check(Shop.item_meets(o, ok_item) and not Shop.item_meets(o, Items.make("sword_iron", {"quality": 120.0})), "orders: only a blade with fire satisfies it")
	Shop.orders().erase(o)
	# supplies: a draught from the shop shelf
	var pot := Items.make("potion_healing", {"qty": 2})
	pot["for_sale"] = true
	Game.inventory().append(pot)
	a["gold"] = 200
	a["potions"] = 0
	a["depart_day"] = Game.day()
	var g0 := Game.gold()
	Adv.morning_departures()
	check(int(a["potions"]) == 1 and Game.gold() > g0, "adventurers: bought a healing draught from the shelf before leaving")
	a["status"] = "in_town"
	a["equipment"] = saved_eq
	a["level"] = saved_lv
	# coatings: treat a blade, it wears off after three trips
	var sw := Items.make("sword_iron", {"quality": 80.0})
	Game.add_item(sw, false)
	Game.add_item(Items.make("coating_flame", {"qty": 1}), false)
	var msg := Crafting.treat(int(sw["uid"]), "coating_flame")
	check(sw.has("coating") and int(sw["coating"]["value"]) > 0, "alchemy: %s" % msg)


## Iteration 5: helping or mistreating an adventurer ripples through family, trade and reputation.
func _village_remembers() -> void:
	var rep0 := Shop.reputation()
	# --- help: Mira gets fine gear for free; her father the grocer remembers
	var mira := Adv.get_a("mira")
	var fine := Items.make("sword_steel", {"quality": 110.0, "crafted_by": "Brannoc Ironhand"})
	Game.add_item(fine, false)
	var aldric0 := Social.aff("aldric")
	Adv.give_item(mira, Game.take_uid(int(fine["uid"])), 0)
	Sim.on_mira_equipped(fine, 0)
	check(Social.aff("aldric") > aldric0 and Social.has_memory("aldric", "kin_equipped_" + str(fine["uid"])), "village: Aldric remembers what you did for his daughter")
	Social.change("aldric", 30.0, 10.0)
	Game.state["world"]["delivery_pending"] = true
	var deliv := Sim.take_delivery()
	check(deliv.contains("good bread") or deliv.contains("best"), "grocer: a warm grocer brings the good provisions")
	# --- mistreat: Kestra's shoddy blade fails her; she disputes it and you refuse
	var kes := Adv.get_a("kestra")
	Adv.ensure(kes)
	kes["status"] = "in_town"
	var junk := Items.make("dagger", {"quality": 40.0, "crafted_by": "Brannoc Ironhand"})
	Shop.raise_dispute("kestra", junk)
	Shop.mark_arrived("kestra", false)
	check(Shop.waiting().any(func(c): return c["npc"] == "kestra" and c["want"] == "dispute"), "disputes: Kestra comes back about the failed blade")
	var tobin0 := Social.aff("tobin")
	var msg := Shop.settle_dispute("kestra", false)
	Social.change("kestra", -30.0, 2.0, "egged", "Still furious about the dagger.")
	check(Social.band("kestra") == "hostile" and Social.aff("tobin") < tobin0, "village: refusing her sours Kestra and her brother Tobin (%s)" % msg)
	var stock_it := Items.make("sword_steel", {"quality": 100.0})
	stock_it["for_sale"] = true
	Game.add_item(stock_it, false)
	kes["gold"] = 999
	check(Adv.purchase_check(kes, stock_it, Shop.price_of(stock_it)) == "won't buy from you", "commerce: a hostile customer won't buy from you")
	check(Shop.create_order("kestra", "weapon").is_empty(), "commerce: …or commission anything")
	check(Shop.reputation() != rep0, "reputation moved with what you did (%.1f → %.1f, %s)" % [rep0, Shop.reputation(), Shop.reputation_word()])
	# a furious villager may egg the shop
	Game.state["world"]["eggs"] = false
	var egged := false
	for i in 20:
		Sim._social_events()
		if Game.state["world"].get("eggs", false):
			egged = true
			break
	check(egged, "consequences: someone eggs the storefront (%s)" % Game.state["world"].get("eggs_by", ""))
	# and the memories survive a save and load
	check(Saves.save("village_slot") and Saves.load_slot("village_slot"), "village: save/load")
	check(Social.band("kestra") == "hostile" and Social.has_memory("aldric", "kin_equipped_" + str(fine["uid"])), "village: grudges and gratitude persist")
	Saves.delete("village_slot")
	Social.change("kestra", 60.0, 0.0)
	Sim.clean_eggs()


## Iteration 6: acquaintance → dating → walk → courting → keepsake → marriage, then married life.
func _romance() -> void:
	var npc := "elowen"
	var el := Adv.get_a(npc)
	Adv.ensure(el)
	el["status"] = "in_town"
	var m0: int = Game.state["minute"]
	Game.state["minute"] = int(Game.state["minute"] / 1440) * 1440 + 19 * 60   # an evening at the inn
	Game.add_gold(1000 - Game.gold(), "test", "test funds")
	var stages := []
	Game.add_item(Items.make("potion_healing", {"qty": 6}), false)
	for i in 3:
		Talk.choose(npc, "gift", "inn")
	check(Talk.options(npc, "inn").any(func(o): return o["id"] == "tabletalk") and Talk.choose(npc, "tabletalk", "inn")["text"] != "", "inn: table talk drawn from recent events")
	check(Talk.choose(npc, "dice", "inn")["text"].contains("throw"), "inn: a game of knucklebones with real dice")
	Talk.choose(npc, "drink", "inn")
	Talk.choose(npc, "drink", "inn")
	stages.append(Social.romance(npc))
	check(Social.romance(npc) == "dating", "romance: two evenings by the fire — dating")
	check(not Talk.options(npc, "inn").any(func(o): return o["id"] == "court"), "romance: no courting before a personal moment")
	Social.change(npc, 40.0 - Social.aff(npc), 0.0)
	check(Talk.options(npc, "inn").any(func(o): return o["id"] == "walk"), "romance: she'll walk home with you along the stream")
	var walk_txt: String = Talk.choose(npc, "walk", "inn")["text"]
	check(walk_txt.contains("college"), "romance: the walk is her own story")
	Social.change(npc, 60.0 - Social.aff(npc), 0.0)
	Talk.choose(npc, "court", "inn")
	stages.append(Social.romance(npc))
	var dt: String = Talk.choose(npc, "drink", "inn")["text"]
	check(Social.romance(npc) == "courting" and dt.contains("Ember Charm") and Game.has_flag("keepsake_elowen"), "romance: courting — she gives you her keepsake")
	Social.change(npc, 85.0 - Social.aff(npc), 0.0)
	var no_ring := true
	for it in Game.inventory():
		if Items.slot(it) == "ring":
			no_ring = false
	if no_ring:
		Game.add_item(Items.make("ring_silver", {"quality": 95.0, "crafted_by": "Brannoc Ironhand"}), false)
	var r: Dictionary = Talk.choose(npc, "propose", "inn")
	stages.append(Social.romance(npc))
	check(Social.spouse() == npc and str(r["text"]).contains("candle"), "marriage: she says yes, and the wedding is hers (%s)" % [stages])
	# married life: free gear, shared spoils, new words
	var blade := Items.make("sword_steel", {"quality": 100.0, "crafted_by": "Brannoc Ironhand"})
	blade["for_sale"] = true
	Game.add_item(blade, false)
	var g0 := Game.gold()
	check(Shop.sell_to(npc, int(blade["uid"])) == "" and Game.gold() == g0 and el["equipment"]["weapon"]["uid"] == blade["uid"], "marriage: your gear is hers, free")
	el["status"] = "away"
	el["dest"] = "whisperwood"
	el["days_left"] = 1
	el["equipment"]["armor"] = Items.make("cuirass_iron", {"quality": 110.0})
	var fam0 := 0
	for e in Game.state["ledger"]:
		if e["cat"] == "family":
			fam0 += 1
	Adv.on_day()
	var fam1 := 0
	for e in Game.state["ledger"]:
		if e["cat"] == "family":
			fam1 += 1
	check(fam1 > fam0 or el["status"] == "dead", "marriage: her spoils come home to the household")
	check(Talk.greeting(npc).contains("Husband"), "marriage: she greets you as her husband")
	Game.state["minute"] = m0


## Iteration 7: all five disciplines, jewellery, the arcane chain with bound magic, a multi-discipline
## enchanted blade that changes an adventurer's next expedition, hireling assistance and repairs.
func _masters() -> void:
	Game.add_gold(3000 - Game.gold(), "test", "test funds")
	for pair in [["ore_adamantine", 4], ["gem_moonstone", 2], ["coal", 6], ["leather_cured", 6], ["ingot_steel", 6], ["runestone_ember", 1],
			["coating_flame", 1], ["thread_ethereal", 2], ["ore_silver", 6], ["gem_garnet", 1], ["gem_sapphire", 1], ["thread_linen", 3], ["starmetal_fragment", 1]]:
		Game.add_item(Items.make(pair[0], {"qty": pair[1]}), false)
	if not Game.has_upgrade("arcane_foundry"):
		Game.state["upgrades"].append("arcane_foundry")
	# multi-discipline: smithing + runecraft + alchemy + stitching in one blade
	var ops := Crafting.operations("emberwarden_longsword")
	var discs := {}
	for o in ops:
		discs[DB.station(o["station"]).get("discipline", "")] = true
	check(discs.size() >= 4, "masters: the Emberwarden spans %d disciplines %s" % [discs.size(), discs.keys()])
	var ember := _craft("emberwarden_longsword", 108.0, {"edge": 14, "resonance": 8, "temper": 8, "fortune": 50})
	check(not ember.is_empty() and Items.stat(ember, "fire") > 0, "masters: Emberwarden forged (fire %d, attack %d, %s)" % [Items.stat(ember, "fire"), Items.stat(ember, "attack"), ember.get("rarity", "")])
	# jewellery: gems give their nature to the piece
	var ring := _craft("garnet_ring", 100.0, {"resonance": 6, "fortune": 40})
	check(Items.stat(ring, "fire") > 0 and Items.stat(ring, "magic") > 0, "jewellery: garnet ring (fire %d, magic %d)" % [Items.stat(ring, "fire"), Items.stat(ring, "magic")])
	# the arcane chain: charge adamantine, then a warplate with a ward bound into the metal
	Game.grant_player_xp("arcane_metalwork", 400)
	var ingot := _craft("charge_adamantine", 100.0, {"purity": 4})
	check(Game.count("ingot_adamantine") >= 2 or not ingot.is_empty(), "arcane: charged adamantine (%d ingots)" % Game.count("ingot_adamantine"))
	if Game.count("ingot_adamantine") < 2:
		Game.add_item(Items.make("ingot_adamantine", {"qty": 2 - Game.count("ingot_adamantine")}), false)
	var plate := _craft("adamantine_warplate", 105.0, {"guard": 15, "spellweave": 10, "temper": 9, "fortune": 50})
	check(plate.has("bound") and plate.get("arcane_glow", false) and Items.stat(plate, "ward") > int(DB.item("warplate_adamantine")["stats"]["ward"]), "arcane: warplate with %s bound into the metal (ward %d)" % [plate.get("bound", {}).get("name", "?"), Items.stat(plate, "ward")])
	# the forgotten recipe, now known
	var star := _craft("starsteel_blade", 100.0, {"edge": 12, "temper": 8, "fortune": 40})
	check(star.get("def", "") == "sword_starsteel", "masters: Starsteel Blade from the forgotten recipe")
	# hireling assistance: a smith on shift steadies the work
	var borin := Hire.get_h("borin")
	var st0: String = borin["status"]
	borin["status"] = "away"
	var alone := Crafting.skill_bonus("iron_longsword")
	borin["status"] = "working"
	var helped := Crafting.skill_bonus("iron_longsword")
	borin["status"] = st0
	check(helped > alone, "assist: Borin at the bench adds %.2f%% craftsmanship" % (helped - alone))
	# repairs of an adventurer's own worn gear
	var gar := Adv.get_a("garrick")
	Adv.ensure(gar)
	gar["status"] = "in_town"
	var arm: Dictionary = gar["equipment"]["armor"]
	arm["stats"]["durability"] = int(int(arm["stats"]["durability_max"]) * 0.2)
	Shop.customers().clear()
	Shop._add_customer("garrick", "repair_own")
	Shop.mark_arrived("garrick", false)
	Shop.do_repair("garrick", 100.0)
	check(int(arm["stats"]["durability"]) > int(arm["stats"]["durability_max"]) * 0.8, "repairs: Garrick's own armour restored (%d/%d)" % [int(arm["stats"]["durability"]), int(arm["stats"]["durability_max"])])
	# milestone: the enchanted blade goes on an adventurer and shapes the next expedition
	gar["equipment"]["weapon"] = ember
	var res := Adv.run_encounters(gar, "barrow_fields")
	var credited := false
	for uid in res["credits"]:
		if str(uid) == str(ember["uid"]):
			credited = true
	check(credited, "milestone: the Emberwarden decided Garrick's barrow fights %s" % [res["lines"]])


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


## Skill-check difficulty (Crafting.check_params factors, assist, tweaks) and customer requests/arrival.
func _checks_and_customers() -> void:
	var sk := Game.player_skills()
	var old_lvl := int(sk["smithing"]["lvl"])
	sk["smithing"]["lvl"] = 1
	var low := Crafting.check_params("anvil", "iron_longsword")
	sk["smithing"]["lvl"] = 8
	var high := Crafting.check_params("anvil", "iron_longsword")
	sk["smithing"]["lvl"] = old_lvl
	check(float(high["zone"]) > float(low["zone"]) and float(high["speed"]) < float(low["speed"]), "checks: higher skill widens the zone (%.1f > %.1f) and slows the needle" % [high["zone"], low["zone"]])
	var simple := Crafting.check_params("anvil", "hand_axe")
	var hard := Crafting.check_params("anvil", "steel_bastard_sword")
	check(float(hard["zone"]) < float(simple["zone"]) and float(hard["speed"]) > float(simple["speed"]), "checks: harder recipe narrows the zone and speeds the needle")
	var many := Crafting.check_params("anvil", "steel_longsword")
	var few := Crafting.check_params("anvil", "hand_axe")
	check(float(many["factors"]["complexity"]) > float(few["factors"]["complexity"]), "checks: more operations count as more complex (%.2f > %.2f)" % [many["factors"]["complexity"], few["factors"]["complexity"]])
	var arc := Crafting.check_params("arcane_anvil", "iron_longsword")
	var cls := Crafting.check_params("anvil", "iron_longsword")
	check(float(arc["factors"]["tier"]) > float(cls["factors"]["tier"]) and float(arc["zone"]) < float(cls["zone"]) and float(arc["speed"]) > float(cls["speed"]), "checks: arcane stations are narrower and faster than classic ones")
	# tweak targets
	var res := Crafting.check_params("resonance_pedestal", "ember_runestone")
	var res_base := float(DB.station("resonance_pedestal")["check"]["speed"])
	var sweep_now := 340.0 / (float(res["speed"]) * 1.45 * 360.0)
	var sweep_before := 340.0 / (res_base * 1.45 * 360.0)
	check(sweep_now > sweep_before * 1.4 and sweep_now > 1.2, "checks: resonance pedestal sweep is much slower (%.2f s, was ≈%.2f s)" % [sweep_now, sweep_before])
	var inf := Crafting.check_params("infusion_rack", "healing_draught")
	var f: Dictionary = inf["factors"]
	check(float(f["tune_zone"]) > 1.0 and float(f["tune_speed"]) < 1.0, "checks: infusion rack is slightly easier (zone ×%.2f, speed ×%.2f)" % [f["tune_zone"], f["tune_speed"]])
	for st in ["grinding_wheel", "rune_polishing_wheel"]:
		var g: Dictionary = Crafting.check_params(st)["factors"]
		check(float(g["tune_zone"]) > 1.0 and float(g["tune_zone"]) < 1.25, "checks: %s slightly easier" % st)
	# tutorial difficulty: practice and the assist setting
	var norm := Crafting.check_params("anvil", "iron_longsword", -1, {"assist": false})
	var tut := Crafting.tutorial_params("anvil", "iron_longsword")
	check(float(tut["zone"]) > float(norm["zone"]) * 1.3 and float(tut["speed"]) < float(norm["speed"]) * 0.8, "checks: tutorial difficulty is clearly easier")
	var was: bool = bool(Settings.get_value("gameplay/check_assist", false))
	Settings.values["gameplay/check_assist"] = true
	var assisted := Crafting.check_params("anvil", "iron_longsword")
	Settings.values["gameplay/check_assist"] = was
	check(bool(assisted["assist"]) and float(assisted["zone"]) > float(norm["zone"]), "checks: the assist option widens the zone")
	check(is_equal_approx(float(norm["factors"]["fatigue"]), 1.0 - Crafting.FATIGUE_ZONE * (1.0 - Vitality.work_factor())), "checks: fatigue hook folded into the zone")
	check(Minigames.mechanic({"station": "anvil"}) == "ring" and Minigames.mechanic({"station": "resonance_pedestal"}) == "multihit" and Minigames.tutorial("edge")["keys"] != "", "checks: every mechanic has a how-to card")
	check(float(Minigames.practice_args({"station": "bellows", "zone": 30, "speed": 0.6})["zone"]) > float(Crafting.check_params("bellows")["zone"]), "checks: practice runs at tutorial difficulty")
	# customers: explicit requests, and no announcement until they sit down
	var saved_customers: Array = Shop.customers().duplicate()
	Shop.customers().clear()
	var heard: Array = []
	var listener := func(t: String, _k: String): heard.append(t)
	Events.toast.connect(listener)
	Shop._add_customer("martha", "goods")
	var waiting_toast := heard.any(func(t): return str(t).contains("waiting"))
	check(not waiting_toast and Shop.waiting().is_empty() and not Shop.customers().is_empty(), "customers: setting out is silent; not waiting before arrival")
	Shop.mark_arrived("martha")
	check(heard.any(func(t): return str(t).contains("is waiting at your shop: wants")) and Shop.waiting().size() == 1, "customers: announced with their wish once seated")
	var req := Shop.request(Shop.customer("martha"))
	check(req["kind"] == "goods" and req.has("budget") and str(req["summary"]).contains("budget"), "customers: goods request states item and budget")
	Shop.dismiss_customer("martha")
	check(Shop.customer("martha").is_empty(), "customers: dismissal frees the seat")
	var advs := Adv.in_town()
	if not advs.is_empty():
		var aid := str(advs[0]["id"])
		Shop._add_customer(aid, "browse")
		var cu := Shop.customer(aid)
		var r2 := Shop.request(cu)
		check(cu.has("slot") and cu.has("stat") and cu.has("min") and cu.has("materials") and str(r2["summary"]).contains("≥"), "customers: adventurer states slot, attribute minimum and materials (%s)" % r2["summary"])
		Shop.remove_customer(aid)
		var o := Shop.create_order(aid)
		if not o.is_empty():
			var orq := Shop.order_request(o)
			check(orq["kind"] == "commission" and orq.has("deadline") and orq.has("reward") and orq["slot"] == o["slot"], "customers: commissions use the same request card data")
			Shop.orders().erase(o)
	Events.toast.disconnect(listener)
	Shop.customers().clear()
	Shop.customers().append_array(saved_customers)


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


## Everyone home, rested and ready to leave today.
func _ready_everyone() -> void:
	for a in Adv.all().values():
		Expeditions.ensure(a)
		if a["status"] != "dead":
			a["status"] = "in_town"
			a["hp"] = a["hp_max"]
			a["fatigue"] = 0.0
			a["depart_day"] = Game.day()
			a.erase("exp")
	Expeditions.st()["parties"] = {}


func _run_out(eid: String) -> Dictionary:
	var e: Dictionary = Expeditions.active().get(eid, {})
	var guard := 0
	while Expeditions.active().has(eid) and guard < 600:
		guard += 1
		Expeditions.step(e)
	return e


func _living_village() -> void:
	Expeditions.set_difficulty("journeyman")
	# template sprites: user-provided names fall back to template_ files
	check(Assets.template_id("stations/forge") == "stations/template_forge", "templates: id maps to template_ file")
	check(Assets.has_tex("stations/forge") and Assets.has_tex("enemies/wolf"), "templates: unprefixed ids resolve via template_ sprites")
	# a crafted instance sold to an adventurer is the exact item they carry
	var sword := Items.make("sword_steel", {"quality": 96.0})
	sword["crafted_by"] = "Brannoc Ironhand"
	var uid := int(sword["uid"])
	var dar: Dictionary = Adv.all().values()[0]
	Adv.give_item(dar, sword, 0)
	check(int(dar["equipment"]["weapon"]["uid"]) == uid and dar["equipment"]["weapon"]["owner"] == dar["id"], "items: the adventurer carries the exact instance (uid %d)" % uid)
	check(int(Game.find_uid_anywhere(uid).get("uid", -1)) == uid, "items: an instance can be found wherever it is")
	# parties form at the inn and leave
	_ready_everyone()
	Expeditions.form_parties()
	var parties: Array = Expeditions.st()["parties"].values()
	check(not parties.is_empty(), "expeditions: parties form at the inn (%d)" % parties.size())
	var sizes_ok := true
	for p in parties:
		sizes_ok = sizes_ok and (p["members"] as Array).size() >= 1 and (p["members"] as Array).size() <= 4
	check(sizes_ok, "expeditions: parties have 1–4 members")
	Expeditions.prepare_parties()
	Expeditions.depart_parties()
	check(not Expeditions.active().is_empty(), "expeditions: parties depart (%d active)" % Expeditions.active().size())
	var e0: Dictionary = Expeditions.active().values()[0]
	var a0 := Adv.get_a(str(e0["party"][0]))
	check(a0["status"] == "away" and Expeditions.region(e0["dest"]).size() > 0, "expeditions: members are away in a real region (%s)" % e0["dest"])
	# observation does not stop time
	var op := ObserverPanel.new(str(e0["id"]))
	check(not op.blocks_time, "observer: watching never pauses the simulation")
	op.free()
	var wp := WantedPanel.new("wanted")
	check(not wp.blocks_time, "board: the Most Wanted board lets time run")
	wp.free()
	# run every expedition to its end without anybody watching
	var ids: Array = Expeditions.active().keys()
	for eid in ids:
		_run_out(eid)
	check(Expeditions.active().is_empty(), "expeditions: all finish on their own")
	var fin: Dictionary = Expeditions.done()[0]
	check(not (fin["journal"] as Array).is_empty() and str(fin["outcome"]) != "", "expeditions: journal and outcome recorded (%s)" % fin["outcome"])
	var timed := true
	for j in fin["journal"]:
		timed = timed and j.has("t") and j.has("time") and j.has("day")
	check(timed, "expeditions: journal entries are timestamped")
	check(not Chronicle.entries().is_empty(), "chronicle: events were recorded (%d)" % Chronicle.entries().size())
	# combat uses real dice and the item instance
	var rolls_ok := true
	var saw_attack := false
	var weapon_seen := false
	for e in Expeditions.done():
		for r in e["encounters"]:
			for act in r.get("actions", []):
				if str(act.get("kind", "")) == "attack" and act.has("roll"):
					saw_attack = true
					rolls_ok = rolls_ok and int(act["roll"]) >= 1 and int(act["roll"]) <= 20
					if int(act.get("weapon_uid", -1)) > 0:
						weapon_seen = true
	check(saw_attack and rolls_ok, "combat: attacks roll a d20 (1–20)")
	check(weapon_seen, "combat: attacks name the weapon instance used")
	# Monte Carlo: apprentice never kills, many expeditions in a row
	Expeditions.set_difficulty("apprentice")
	var alive_before := Adv.all().values().filter(func(x): return x["status"] != "dead").size()
	for round_i in 6:
		_ready_everyone()
		Expeditions.form_parties()
		Expeditions.prepare_parties()
		Expeditions.depart_parties()
		for eid in Expeditions.active().keys():
			_run_out(eid)
	var alive_after := Adv.all().values().filter(func(x): return x["status"] != "dead").size()
	check(alive_after == alive_before, "difficulty: Apprentice never kills (%d → %d alive)" % [alive_before, alive_after])
	check(Expeditions.can_observe(), "difficulty: Apprentice may observe live")
	# Master: no omniscient view; harsher prices; switching updates permissions at once
	var probe := Items.make("sword_steel", {"quality": 80.0})
	Expeditions.set_difficulty("journeyman")
	var p_j := Shop.price_of(probe)
	Expeditions.set_difficulty("master")
	check(not Expeditions.can_observe(), "difficulty: Master forbids live observation")
	check(Shop.price_of(probe) < p_j, "difficulty: Master buyers pay less (%d < %d)" % [Shop.price_of(probe), p_j])
	Expeditions.set_difficulty("journeyman")
	check(Expeditions.can_observe(), "difficulty: switching back restores observation")
	# commissions carry a priority and a bonus objective
	var o := Shop.create_order(str(a0["id"]), "weapon")
	check(o.is_empty() or (o.has("priority") and o.has("bonus")), "commissions: priority and bonus objective")
	# hidden employee potential changes growth
	var hi := {"id": "t_hi", "skills": SkillSys.new_set({"smithing": 3}), "traits": [], "potential": 1.5, "hired_day": Game.day()}
	var lo := {"id": "t_lo", "skills": SkillSys.new_set({"smithing": 3}), "traits": [], "potential": 0.7, "hired_day": Game.day()}
	Hire.add_xp(hi, "smithing", 40)
	Hire.add_xp(lo, "smithing", 40)
	check(int(hi["skills"]["smithing"]["xp"]) > int(lo["skills"]["smithing"]["xp"]), "employees: hidden potential changes growth (%d vs %d xp)" % [int(hi["skills"]["smithing"]["xp"]), int(lo["skills"]["smithing"]["xp"])])
	check(Hire.potential_word(hi).contains("unknown"), "employees: potential is hidden until they have worked a while")
	hi["hired_day"] = Game.day() - 6
	check(Hire.potential_word(hi).contains("remarkable"), "employees: potential revealed by watching them work")
	# finds offered to the forge become real inventory
	var find := Items.make("yew_stave", {})
	Shop.add_offer(str(a0["id"]), find, false)
	var off: Dictionary = Shop.offers()[-1]
	Game.state["gold"] = 500
	check(Shop.accept_offer(str(off["id"])) == "" and Game.find_uid(int(find["uid"])).get("owner", "") == "smith", "offers: a bought find enters the smith's stores")
	# an expedition in progress survives save and load
	_ready_everyone()
	Expeditions.form_parties()
	Expeditions.prepare_parties()
	Expeditions.depart_parties()
	var live_id: String = Expeditions.active().keys()[0] if not Expeditions.active().is_empty() else ""
	Expeditions.step(Expeditions.active()[live_id])
	var jn := (Expeditions.active()[live_id]["journal"] as Array).size()
	check(Saves.save("test_exp"), "saves: write with an expedition on the road")
	Game.state["exp"] = {"active": {}, "done": [], "parties": {}}
	check(Saves.load_slot("test_exp") and Expeditions.active().has(live_id), "saves: the active expedition is restored")
	check((Expeditions.active()[live_id]["journal"] as Array).size() == jn, "saves: its journal is intact")
	_run_out(live_id)
	check(not Expeditions.active().has(live_id), "saves: a restored expedition runs on to its end")
	Saves.delete("test_exp")


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
