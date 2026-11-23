## The completion run's cross-system scenario (R3–R8 together): forge → sell → equip → a deed on an expedition →
## renown that spreads → death and inheritance → the Reliquary → an heir → restoration → a civic consequence → one
## history in Lore and the Chronicle. One piece, one uid, from the anvil to a mother's house; every step is a real
## system call; the test only stands in for the dice of the fight (the deed and the death are recorded as the
## expedition would record them).
extends SuiteCase


func test_from_the_anvil_to_a_mothers_house() -> void:
	fresh_game("journeyman", 7070)
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Game.state["gold"] = 30000
	# --- forge
	var sword := Items.make("sword_steel", {"quality": 104.0})
	Provenance.forged(sword)
	Game.add_item(sword, false)
	var uid := int(sword["uid"])
	check(Provenance.is_workshop(sword), "forged at the Ironhand forge, with its mark")
	# --- sell (the counter), and the buyer equips it
	var g := Adv.get_a("garrick")
	g["gold"] = 5000
	Expeditions.ensure(g)
	var price := Shop.price_of(sword)
	eq(Shop.sell_to("garrick", uid, price), "", "Garrick buys it at the counter")
	eq(int(g["equipment"].get("weapon", {}).get("uid", -1)), uid, "and wields it")
	eq(Provenance.owner_id(g["equipment"]["weapon"]), "garrick", "its owner is Garrick")
	# --- a deed on an expedition: the killing blow on a master (Epic) — the region's news, carried home by the party
	var w: Dictionary = g["equipment"]["weapon"]
	var rep0 := Reputation.standing()
	Recognition.grant_epic(w, "struck down the Barrow Wight-Lord", "garrick", "boss")
	check(w.has("epic"), "the blade earned Epic distinction for its deed")
	check(Reputation.standing() >= rep0, "the village thinks no less of the forge")
	# --- renown spreads by a channel, and a visitor comes for it (R8)
	Reputation.change(8.0, "a blade from the Ironhand forge struck down the Barrow Wight-Lord")
	eq(Reputation.word("traders", "region"), 0.0, "the region has not heard yet")
	Reputation.carry("village", "region", "ship")
	check(Reputation.word("traders", "region") > 0.0, "a ship carried it to the region's traders")
	Visitors.on_day(Game.day())
	check(not Visitors.log_list().is_empty(), "a Highmarsh trader came because of it")
	# --- death and inheritance: Garrick falls; with no companion to take it up, his blade is carried home to the forge
	g["status"] = "dead"
	g["died_day"] = Game.day()
	g["death_event"] = Lore.record("death", "Garrick Stone fell at the Barrow Fields.", {"actors": ["garrick"], "importance": 3, "chronicle": true})
	GearDepth.disable(w, "shattered in Garrick's last fight")
	# a surviving companion (as Expeditions.finish calls it: only when someone came back); the shattered blade serves
	# no one, so it is carried home to the forge
	Adv.bequeath(g, ["kestra"], "barrow_fields", "the Barrow Fields")
	var chest := {}
	for c in Game.state["returns"]:
		for it in c.get("contents", []):
			if int(it.get("uid", -1)) == uid:
				chest = c
	check(not chest.is_empty(), "his companions' chest holds the blade")
	for it in chest.get("contents", []):
		Game.add_item(it, false)
	Game.state["returns"].erase(chest)
	check(not Game.find_uid(uid).is_empty(), "the same blade is back in the stores")
	var rec := Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "recovered")
	check(not rec.is_empty() and (rec[0].get("because", []) as Array).has(str(g["death_event"])), "its homecoming follows from his death (causal link)")
	# --- the Reliquary and an heir (R6)
	if not Property.is_owned_station(Reliquary.STATION):
		Property.buy_station(Reliquary.STATION)
	var plan := Property.plan_copy()
	if not Reliquary.installed():
		Property.auto_place(plan, Reliquary.STATION)
		Property.commit(plan)
	eq(Reliquary.enshrine(uid), "", "the shattered Epic blade rests in the Reliquary")
	var hs := Reliquary.heirs_of(Reliquary.held(uid))
	check(hs.size() == 1 and str(hs[0]["id"]) == "martha", "the records name his mother Martha as heir")
	Social.ensure("martha")["aff"] = 40.0
	for d in Reliquary.LETTER_AFTER + 1:
		Game.advance_minutes(1440)
	check(Reliquary.letters().any(func(l): return int(l["uid"]) == uid and str(l["kind"]) == "request"), "Martha writes")
	eq(Reliquary.write_to(uid, "martha", 200), "", "the smith answers")
	Game.advance_minutes(1440)
	eq(str(Reliquary.claim(uid).get("answer", "")), "return", "her terms: restored, it comes home")
	# --- restoration
	eq(Reliquary.take_out(uid), "", "taken out for the work")
	for d in Refinement.inputs_for(Game.find_uid(uid), "restore"):
		Game.add_item(Items.make(str(d), {"qty": 6}), false)
	var r := Refinement.perform(uid, "restore", 90.0, {"station": "anvil"})
	eq(str(r.get("outcome", "")), "success", "restored at the anvil")
	eq(str(ItemRegistry.where(uid).get("holder", "")), "holdings", "and sent home to Martha, as agreed")
	# --- a civic consequence (R4 + R8): the forge's work arms the muster; the patrols make the road safer
	var road := "highmarsh_road"
	var b0 := Militia.bandits_at(road)
	Institutions.receive("muster", "smith", [{"def": "helm_iron", "n": 12}, {"def": "shield_round", "n": 12}], [], 90.0, [], {"order": "integration"})
	for d in 40:
		Game.advance_minutes(1440)
	check(Militia.bandits_at(road) < b0, "the muster's patrols thinned the bandits on the Highmarsh road (%d < %d)" % [Militia.bandits_at(road), b0])
	# --- one history
	var kinds := Lore.of_item(uid).map(func(e): return str(e["kind"]))
	for k in ["forged", "sold", "epic", "recovered", "enshrined", "heir_claim", "heir_letter", "heir_terms", "restored", "returned"]:
		check(kinds.has(k), "the blade's history records %s" % k)
	var bad := 0
	for id in Provenance.st(ItemRegistry.find(uid)).get("events", []):
		if Lore.event(str(id)).is_empty():
			bad += 1
	eq(bad, 0, "every event in its story resolves")
	var feed := Chronicle.entries().filter(func(e): return str(e.get("event", "")) != "" and Lore.event(str(e["event"])).is_empty())
	eq(feed.size(), 0, "every Chronicle line is a Lore event")
	eq(ItemRegistry.scan()["dup"], [], "one instance throughout — no uid held twice")
	check(Saves.save("suite_integration") and Saves.load_slot("suite_integration"), "the whole story saves and loads")
	Saves.delete("suite_integration")
	eq(Provenance.owner_id(ItemRegistry.find(uid)), "martha", "and after loading the blade is still Martha's")
	eq(Lore.of_item(uid).size(), kinds.size(), "with its whole history")
