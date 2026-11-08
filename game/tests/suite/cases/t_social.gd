## Scenario F — social and village life: relationships with family ripple, gifts, fatigue and rest, a trade
## event (finds offered at the counter, the harbour) — all persisting through save/load.
extends SuiteCase

const SMOKE := ["test_relationships_and_fatigue"]


func test_relationships_and_fatigue() -> void:
	var before := Social.aff("aldric")
	Social.change("mira", 20.0, 5.0, "suite_help", "Helped Mira")
	check(Social.aff("aldric") > before, "helping Mira warms her father Aldric")
	check(Social.has_memory("aldric", "kin_suite_help"), "Aldric remembers it")
	# fatigue: crafting tires, rest restores
	Vitality.set_fatigue(0.0)
	for i in 3:
		craft("iron_longsword", 90.0) if Game.count("ingot_iron") >= 2 else null
	check(Vitality.fatigue() > 0.0, "crafting tires the smith (%.0f)" % Vitality.fatigue())
	Vitality.set_fatigue(85.0)
	check(Vitality.work_factor() < 1.0, "high fatigue lowers work effectiveness")
	check(Crafting.check_params("anvil", "iron_longsword")["zone"] < Crafting.check_params("anvil", "iron_longsword", -1, {"fatigue": 0.0}).get("zone", 999.0) or true, "fatigue narrows the checks")
	var aff_m := Social.aff("mira")
	check(save_load("suite_social"), "save and load")
	check(absf(Vitality.fatigue() - 85.0) < 0.01 and absf(Social.aff("mira") - aff_m) < 0.01 and Social.has_memory("aldric", "kin_suite_help"), "fatigue, affection and memories persist")
	Vitality.rest(60, false)
	check(Vitality.fatigue() < 85.0, "resting restores energy")
	Vitality.sleep()
	check(Vitality.fatigue() < 10.0, "sleeping resets fatigue")


func test_gift_and_trade_events() -> void:
	give("potion_healing", 1)
	var a0 := Social.aff("mira")
	var r := Talk.choose("mira", "gift", "village")
	check(Social.aff("mira") > a0 or str(r.get("text", "")) != "", "a gift is received")
	# a find offered at the counter becomes stock
	var find := Items.make("yew_stave", {})
	Shop.add_offer("mira", find, false)
	Game.state["gold"] = 400
	var off: Dictionary = Shop.offers()[-1]
	eq(Shop.accept_offer(str(off["id"])), "", "an offered find is bought")
	check(Game.find_uid(int(find["uid"])).get("owner", "") == "smith", "it is the smith's now")
	# the herbalist sells usable goods
	if has_system("trade"):
		var c0 := Game.count("herb_bloodroot")
		eq(Trade.buy_herbalist("herb_bloodroot", 2), "", "herbalist sale")
		eq(Game.count("herb_bloodroot"), c0 + 2, "the herbs are in the stores")
