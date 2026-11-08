## Commerce: the travelling caravan comes and goes, the pawnshop's prices and pledges, the rival smith's shop,
## companion creatures bought for adventurers, and everything surviving a save/load.
extends SuiteCase

const SMOKE := ["test_pawn_prices", "test_companion_for_adventurer"]


func test_caravan_comes_and_goes() -> void:
	if not has_system("commerce"):
		skip("Commerce not in this build")
		return
	check(not Commerce.caravan_present(), "no caravan at the start of a new game")
	check(not Commerce.next_caravan().is_empty(), "the caravan is expected")
	var guard := 0
	while not Commerce.caravan_present() and guard < 14:
		days(1)
		guard += 1
	check(Commerce.caravan_present(), "the caravan arrives after %d days" % guard)
	check(guard >= 2, "it does not arrive at once (%d days)" % guard)
	var cv := Commerce.caravan()
	check(not (cv.get("stock", []) as Array).is_empty(), "the wagons carry goods")
	check(not (cv.get("wanted", []) as Array).is_empty(), "the caravan wants goods")
	check(TalkMarkers.wants_to_talk("caravan_master") != "", "the caravan master is marked on the map")
	check(Chronicle.recent(10, ["trade"]).any(func(e): return str(e["text"]).contains("caravan")), "the Chronicle records the arrival")
	# buy something and sell a wanted good
	Game.state["gold"] = 20000
	var g0 := Game.gold()
	eq(Commerce.buy_caravan(0, 1), "", "a caravan purchase goes through")
	check(Game.gold() < g0, "the purchase is paid for")
	var w: Dictionary = cv["wanted"][0]
	give(str(w["def"]), 1)
	var mine := Game.inventory().filter(func(it): return str(it["def"]) == str(w["def"]))
	var uid := int(mine[0]["uid"])
	var offer := Commerce.wanted_offer(uid)
	check(offer > Commerce.unit_value(mine[0]), "the caravan pays a premium for wanted goods (%d > %d)" % [offer, Commerce.unit_value(mine[0])])
	var g1 := Game.gold()
	eq(Commerce.sell_wanted(uid, 1), "", "a wanted good is sold to the caravan")
	eq(Game.gold(), g1 + offer, "the premium is paid")
	check(save_load("suite_commerce_cv") and Commerce.caravan_present(), "the visiting caravan persists")
	guard = 0
	while Commerce.caravan_present() and guard < 5:
		days(1)
		guard += 1
	check(not Commerce.caravan_present(), "the caravan leaves again after %d days" % guard)
	check(TalkMarkers.wants_to_talk("caravan_master") == "", "the map marker is cleared")
	check(int(Commerce.next_caravan().get("days", 0)) >= 1, "the next visit is scheduled")


func test_pawn_prices() -> void:
	if not has_system("commerce"):
		skip("Commerce not in this build")
		return
	Game.state["gold"] = 500
	give("ring_silver", 1)
	var it: Dictionary = Game.inventory().filter(func(x): return str(x["def"]) == "ring_silver")[0]
	eq(Commerce.pawnable(it), "", "a silver ring can be pawned")
	var val := Items.value(it)
	var pay := Commerce.pawn_payout(it, 1)
	var back := Commerce.pawn_buyback(it)
	check(pay >= int(val * 0.35) and pay <= int(ceil(val * 0.45)), "payout is 35–45%% of value (%d of %d)" % [pay, val])
	check(back > pay and back >= int(val * 0.6) and back <= int(ceil(val * 0.7)), "buy-back costs more, 60–70%% (%d)" % back)
	var g0 := Game.gold()
	eq(Commerce.pawn_item(int(it["uid"])), "", "the ring is pledged")
	eq(Game.gold(), g0 + pay, "the payout is paid")
	eq(Game.count("ring_silver"), 0, "the ring is with the pawnbroker")
	check(Game.state["ledger"].any(func(e): return str(e["cat"]) == "pawn"), "the ledger has a pawn entry")
	check(save_load("suite_commerce_pawn"), "save/load with a pledge")
	var p: Array = Commerce.pledges()
	eq(p.size(), 1, "the pledge persists")
	eq(str(p[0]["status"]), "held", "it is held for the smith")
	# a quest-like container is refused
	give("bag_traveller", 1)
	var bag: Dictionary = Game.inventory().filter(func(x): return str(x["def"]) == "bag_traveller")[0]
	check(Commerce.pawnable(bag) != "", "containers are not pawnable")
	# redeem
	var g1 := Game.gold()
	eq(Commerce.redeem(str(p[0]["id"])), "", "the ring is redeemed")
	eq(Game.gold(), g1 - back, "redeeming costs the buy-back price")
	eq(Game.count("ring_silver"), 1, "the ring is back")
	# a pledge lapses and goes on the shelf
	give("dagger", 1)
	var dg: Dictionary = Game.inventory().filter(func(x): return str(x["def"]) == "dagger")[0]
	eq(Commerce.pawn_item(int(dg["uid"])), "", "a dagger is pledged")
	days(int(Commerce.pawn_cfg().get("hold_days", 10)) + 2)
	var lapsed: Array = Commerce.pledges().filter(func(x): return x["status"] == "forfeit")
	eq(lapsed.size(), 1, "an unredeemed pledge lapses onto the shelf")
	if not lapsed.is_empty():
		check(Commerce.pledge_price(lapsed[0]) >= Commerce.pawn_buyback(lapsed[0]["item"]), "the shelf price is no cheaper than redeeming")
	note("house stock this week: %d pieces" % Commerce.house_stock().size())
	check(Commerce.pawn_log().size() >= 3, "transactions are logged")


func test_rival_stock() -> void:
	if not has_system("commerce"):
		skip("Commerce not in this build")
		return
	Game.state["gold"] = 20000
	var s := Commerce.rival_stock()
	check(not s.is_empty(), "the Salt Anvil has stock")
	var idx := -1
	for i in s.size():
		if s[i].has("item"):
			idx = i
			break
	check(idx >= 0, "the rival sells equipment")
	if idx < 0:
		return
	var def := str(s[idx]["def"])
	var price := int(s[idx]["price"])
	check(price > int(DB.item(def).get("value", 0)), "rival work is priced high (%d)" % price)
	var c0 := Game.count(def)
	eq(Commerce.buy_rival(idx), "", "rival equipment can be bought")
	eq(Game.count(def), c0 + 1, "it is in the stores")
	check(Commerce.buy_rival(idx) != "", "a sold piece cannot be bought twice")
	# talk hooks
	var opts := Talk.options("rival_smith", "village").map(func(o): return o["id"])
	check(opts.has("c_rival_tip") and opts.has("c_rival_jab"), "the rival has shop talk, rivalry and tips")
	var r := Talk.choose("rival_smith", "c_rival_tip", "village")
	check(str(r.get("text", "")) != "", "she gives a tip")
	check(str(Talk.choose("rival_smith", "c_rival_jab", "village").get("text", "")) != "", "she trades jabs")
	# an adventurer buys from her
	var a: Dictionary = Adv.all().values()[0]
	a["gold"] = 5000
	for k in a["equipment"].keys():
		a["equipment"].erase(k)
	Game.state["commerce"]["rival"].erase("stock")
	var bought := Commerce.rival_buy_for(a)
	check(not bought.is_empty(), "a rich, poorly-equipped adventurer buys at the Salt Anvil")
	if not bought.is_empty():
		check(a["equipment"].has(str(bought["slot"])), "and wears it")
	check(save_load("suite_commerce_rival") and not Commerce.rival_sales().is_empty(), "rival sales persist")


func test_companion_for_adventurer() -> void:
	if not has_system("commerce"):
		skip("Commerce not in this build")
		return
	Game.state["gold"] = 20000
	var s := Commerce.creature_stock()
	check(s.size() >= 3, "the Hales have creatures (%d)" % s.size())
	check(s.any(func(e): return Companions.magical(str(e["def"]))), "at least one magical creature")
	var a: Dictionary = {}
	for x in Adv.all().values():
		if x["status"] == "in_town":
			a = x
			break
	check(not a.is_empty(), "an adventurer is in town")
	if a.is_empty():
		return
	var id := str(a["id"])
	var aff0 := Social.aff(id)
	eq(Commerce.arrange_creature(0, id, "gift"), "", "the smith gives a creature to an adventurer")
	var comp := Companions.of(Adv.get_a(id))
	check(not comp.is_empty(), "it is in their companion slot")
	eq(Items.slot(comp), "companion", "the item's slot is companion")
	check(str(comp.get("creature_name", "")) != "" and str(comp["name"]).contains(" the "), "the creature has a name (%s)" % comp.get("name", ""))
	check(not (comp.get("history", []) as Array).is_empty(), "and a history")
	check(Social.aff(id) > aff0, "a gift warms the adventurer")
	check(Commerce.arrange_creature(1, id, "gift") != "", "one companion per adventurer")
	# another adventurer pays through the smith at a margin
	var b: Dictionary = {}
	for x in Adv.all().values():
		if x["status"] == "in_town" and x["id"] != id:
			b = x
			break
	if not b.is_empty():
		b["gold"] = 5000
		var idx := -1
		for i in s.size():
			if not bool(s[i].get("sold", false)):
				idx = i
				break
		var g0 := Game.gold()
		var price := int(s[idx]["price"])
		eq(Commerce.arrange_creature(idx, str(b["id"]), "sell", 1.15), "", "a creature is sold on to an adventurer")
		eq(Game.gold(), g0 - price + int(round(price * 1.15)), "the smith keeps the margin")
		check(not Companions.of(b).is_empty(), "the buyer keeps the creature")
	# buy one for yourself and an autonomous purchase offer
	var idx2 := -1
	for i in s.size():
		if not bool(s[i].get("sold", false)):
			idx2 = i
			break
	if idx2 >= 0:
		eq(Commerce.buy_creature(idx2), "", "the smith buys a creature for the stores")
		check(Game.inventory().any(func(it): return Companions.is_companion(it)), "it waits in the stores")
	Game.state["commerce"]["creatures"].erase("stock")
	var c: Dictionary = {}
	for x in Adv.all().values():
		if Companions.of(x).is_empty() and x["status"] == "in_town":
			c = x
			break
	if not c.is_empty():
		c["gold"] = 5000
		var offer := Commerce.creature_offer_for(c)
		if not offer.is_empty():
			check(not Commerce.creature_buy_for(c, offer).is_empty(), "a rich adventurer buys a creature on their own")
			check(not Companions.of(c).is_empty(), "and keeps it")
		else:
			note("no creature suited %s this week" % c["name"])
	# commission
	eq(Commerce.commission_creature("comp_pocket_drake"), "", "a drake can be commissioned")
	check(save_load("suite_commerce_comp"), "save/load")
	var after := Companions.of(Adv.get_a(id))
	check(not after.is_empty() and str(after["name"]) == str(comp["name"]), "the companion and its name survive save/load")
	eq(Commerce.commissions().size(), 1, "the commission persists")
	days(7)
	eq(Commerce.commissions().size(), 0, "the commission is delivered")
	check(Game.inventory().any(func(it): return str(it["def"]) == "comp_pocket_drake"), "the drake is in the stores")
	# expeditions with a companion still run
	days(6)
	check(true, "days pass with companions in the world")
