## R7 "Negotiation & Procurement": goods as payment (valued by the R2 valuation; a sword given is really equipped and in
## its provenance), escorts priced on the one danger model that change a run's odds and outcome, and named captains with
## timed voyages that succeed, are delayed or fail, are reported truthfully and remembered ("the sailor who remembers").
## (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R7 acceptance.)
extends SuiteCase

const SMOKE := ["test_goods_payment_is_equipped_and_recorded", "test_the_sailor_who_remembers"]


func _better_blade(a: Dictionary) -> Dictionary:
	var it := Items.make("sword_steel", {"quality": 110.0})
	Provenance.forged(it)
	Game.add_item(it, false)
	check(Barter.serves(a, it), "premise: the blade would serve %s (better than %s)" % [str(a["name"]), Items.display_name(a["equipment"].get("weapon", {}))])
	return it


# ------------------------------------------------------------------ 1. goods as payment
func test_goods_payment_is_equipped_and_recorded() -> void:
	fresh_game()
	Game.state["gold"] = 20000
	var obj := {}
	var cand := {}
	for o in Sponsor.all_objectives():
		for c in Sponsor.candidates():
			if (c["members"] as Array).size() == 1 and str(Sponsor.evaluate(o, c["members"], {"fee": 99999, "bonus": 0, "share": 0})["verdict"]) == "accept":
				obj = o
				cand = c
				break
		if not obj.is_empty():
			break
	check(not obj.is_empty(), "premise: a lone adventurer would take some sponsorship")
	if obj.is_empty():
		return
	var a := Adv.get_a(str(cand["members"][0]))
	var blade := _better_blade(a)
	var uid := int(blade["uid"])
	var worth := Barter.worth_to(a, blade)
	eq(worth, Valuation.value(blade), "a piece that serves them counts at its full value (the one valuation)")
	var ask := int(Sponsor.asking(obj, cand["members"])["ask"])
	var fee := maxi(0, ask - worth + 1)
	var ans := Sponsor.propose(obj, str(cand["key"]), {"fee": fee, "bonus": 0, "share": 0, "goods": [uid]})
	eq(str(ans.get("verdict", "")), "accept", "coin and the blade together meet their price (%s)" % str(ans.get("reason", "")))
	var sid := str(ans.get("sid", ""))
	eq(int(a["equipment"].get("weapon", {}).get("uid", -1)), uid, "the blade is really equipped")
	check(Game.find_uid(uid).is_empty(), "it left the smith's stores — one instance")
	eq(Provenance.owner_id(a["equipment"]["weapon"]), str(a["id"]), "its provenance names its new owner")
	eq(str(Provenance.owners(a["equipment"]["weapon"])[-1].get("how", "")), "payment", "and how it changed hands: as payment")
	check(Lore.of_item(uid).any(func(e): return str(e["text"]).contains("as payment for a sponsored expedition")), "the payment is in its history")
	# without the blade the same coin is not enough
	var short := Sponsor.evaluate(obj, cand["members"], {"fee": fee, "bonus": 0, "share": 0})
	check(str(short["verdict"]) != "accept" or fee >= ask, "the coin alone would not have done it (%s)" % str(short["verdict"]))
	# a cancel gives the goods back with the fee
	eq(Sponsor.cancel(sid), "", "the sponsorship is called off before they leave")
	check(not Game.find_uid(uid).is_empty(), "the blade came back to the stores")
	check(int(a["equipment"].get("weapon", {}).get("uid", -1)) != uid, "and is no longer in their hands")
	eq(ItemRegistry.scan()["dup"], [], "no uid held twice")


func test_goods_not_serving_count_at_resale() -> void:
	fresh_game()
	var a := Adv.get_a(str(Adv.all().keys()[0]))
	Expeditions.ensure(a)
	a["equipment"]["weapon"] = Items.make("sword_steel", {"quality": 90.0})   # they carry a good blade already
	var poor := Items.make("sword_iron", {"quality": 20.0})
	Game.add_item(poor, false)
	check(not Barter.serves(a, poor), "premise: a poor blade does not serve them")
	eq(Barter.worth_to(a, poor), int(round(float(Valuation.value(poor)) * Barter.RESALE_SHARE)), "it counts only at resale value")
	var heir_piece := Items.make("sword_steel", {"quality": 90.0})
	heir_piece["custody"] = {"for": "martha", "name": "Old Martha"}
	Game.add_item(heir_piece, false)
	check(Barter.payable_reason(heir_piece) != "", "a family's piece in the forge's care is no payment")


# ------------------------------------------------------------------ 2. escorts: danger changes price and outcome
func _two_roads() -> Array:
	var ds := DB.destinations.keys().filter(func(d): return not DB.destinations[d].has("requires_flag"))
	ds.sort_custom(func(x, y): return Danger.trip(str(x)) < Danger.trip(str(y)))
	return [str(ds[0]), str(ds[-1])]


func test_escort_price_and_outcome_follow_danger() -> void:
	fresh_game()
	Game.state["gold"] = 20000
	var roads := _two_roads()
	var safe: String = roads[0]
	var hard: String = roads[1]
	check(Danger.trip(hard) > Danger.trip(safe), "premise: two roads of different danger (%.1f, %.1f)" % [Danger.trip(safe), Danger.trip(hard)])
	var cands := Escorts.candidates()
	check(not cands.is_empty(), "premise: adventurers in town")
	cands.sort_custom(func(x, y): return Escorts.strength(x) > Escorts.strength(y))
	var a: Dictionary = cands[0]
	check(Escorts.price(hard, a) > Escorts.price(safe, a), "the dangerous road costs more to guard (%d > %d g)" % [Escorts.price(hard, a), Escorts.price(safe, a)])
	# the outcome: the same hireling, the same road — with an escort, injury and death are less likely
	var h: Dictionary = Hire.list()[0]
	var o0 := Hire.odds(h, hard)
	var o1 := Hire.odds(h, hard, Escorts.cover(a, hard))
	check(float(o1["injury"]) < float(o0["injury"]) and float(o1["death"]) <= float(o0["death"]) and float(o1["success"]) >= float(o0["success"]),
		"an escort lowers the risk (injury %.2f → %.2f, death %.3f → %.3f)" % [float(o0["injury"]), float(o1["injury"]), float(o0["death"]), float(o1["death"])])
	# seeded runs: the hireling's fate over many identical runs, alone and escorted
	var hurt := [0, 0]
	for k in 2:
		Rng.reseed(4242)
		for i in 300:
			var oo := Hire.odds(h, hard, Escorts.cover(a, hard) if k == 1 else 0.0)
			Rng.f("expeditions")
			if Rng.f("expeditions") < float(oo["injury"]):
				hurt[k] += 1
	check(hurt[1] < hurt[0], "over 300 seeded runs fewer come back hurt with an escort (%d < %d)" % [hurt[1], hurt[0]])
	# an underpaid offer is refused with the price; a fair one taken, the escort really goes and comes back
	var low := Escorts.weigh(a, hard, 1, [])
	check(not bool(low["ok"]) and str(low["reason"]).contains(str(Escorts.price(hard, a))), "too little is refused, the price named (%s)" % str(low["reason"]))
	var gold0 := int(a.get("gold", 0))
	var hid := str(h["id"])
	eq(Escorts.hire(hid, str(a["id"]), hard, Escorts.price(hard, a)), "", "%s agrees to escort %s" % [str(a["name"]), str(h["name"])])
	eq(int(a["gold"]), gold0 + Escorts.price(hard, a), "the fee went into their purse")
	eq(str(a["status"]), "escorting", "they are away with the hireling")
	check(not Escorts.candidates().has(a), "and not free for anything else")
	eq(Hire.send(hid, hard), "", "the hireling sets out")
	for i in 12:
		Game.advance_minutes(1440)
		if str(Hire.get_h(hid).get("status", "")) != "away":
			break
	check(str(a["status"]) != "escorting", "the escort came home with the hireling")
	var kinds := Lore.of_actor(str(a["id"])).map(func(e): return str(e["kind"]))
	check(kinds.has("escort") and kinds.has("escort_done"), "the escort and its end are in their history")


func test_escort_refuses_a_road_beyond_them() -> void:
	fresh_game()
	var hard: String = _two_roads()[1]
	var weak := {}
	for a in Escorts.candidates():
		if Escorts.strength(a) < Danger.trip(hard) * 0.6:
			weak = a
	if weak.is_empty():
		var a0: Dictionary = Escorts.candidates()[0]
		a0["level"] = 1
		a0["equipment"] = {}
		weak = a0
	var w := Escorts.weigh(weak, hard, 99999, [])
	check(not bool(w["ok"]) and str(w["reason"]).contains("beyond me"), "a road beyond them is refused at any price (%s)" % str(w["reason"]))


# ------------------------------------------------------------------ 3. the sailor who remembers
func _dock(type: String, idx := 0) -> Dictionary:
	var nm: Array = Trade.ship_type(type)["names"][idx]
	if not Trade.current_ship().is_empty():
		Trade._depart()
	Trade._dock(type, str(nm[0]), str(nm[1]))
	return Captains.in_port()


func _sail() -> void:
	Trade._depart()


## Advances day by day until the voyage's status is no longer `from` (at most `cap` days).
func _until_not(v: Dictionary, from: Array, cap := 20) -> void:
	for i in cap:
		if not str(v["status"]) in from:
			return
		Game.advance_minutes(1440)


func test_the_sailor_who_remembers() -> void:
	fresh_game()
	Game.state["gold"] = 20000
	Trade.mark_seen("ingot_steel")
	var c := _dock("barge", 0)
	check(not c.is_empty() and str(c["name"]) == "Skipper Durra Coalbrow", "Skipper Durra Coalbrow is in port")
	eq(int(c["visits"]), 1, "her first visit, counted")
	eq(Captains.greeting(c), "", "she has no memory of the smith yet")
	var q1 := Captains.quote(str(c["id"]), "ingot_steel", 4)
	eq(Captains.commission("ingot_steel", 4, int(q1["deposit"])), "", "the smith commissions 4 steel ingots")
	var v: Dictionary = Captains.voyages(str(c["id"]))[0]
	eq(str(v["status"]), "agreed", "agreed, sailing when she leaves")
	_sail()
	eq(str(v["status"]), "at_sea", "she sailed with the order")
	check(int(v["due"]) > Game.day(), "a timed voyage: due day %d" % int(v["due"]))
	Captains.force[str(v["id"])] = "success"
	var due := int(v["due"])
	_until_not(v, ["at_sea"])
	eq(str(v["status"]), "arrived", "the cargo landed")
	eq(Game.day(), due, "on its due day")
	var n0 := Game.count("ingot_steel")
	eq(Captains.collect(str(v["id"])), "", "collected and the balance paid")
	eq(Game.count("ingot_steel"), n0 + 4, "four ingots in the stores")
	eq(int(v["paid"]), int(v["total"]), "paid in full")
	var kinds := Lore.of_actor(str(c["id"])).map(func(e): return str(e["kind"]))
	for k in ["voyage", "voyage_arrived", "voyage_paid"]:
		check(kinds.has(k), "her history records %s" % k)
	# her next visit: she remembers, and her terms are the better for it
	var c2 := _dock("barge", 0)
	eq(int(c2["visits"]), 2, "her second visit")
	check(Captains.greeting(c2).contains("paid in full"), "she remembers being paid in full (%s)" % Captains.greeting(c2))
	var q2 := Captains.quote(str(c2["id"]), "ingot_steel", 4)
	check(int(q2["unit"]) < int(q1["unit"]) and int(q2["deposit"]) < int(q1["deposit"]), "her price and deposit are lower now (%d < %d g each)" % [int(q2["unit"]), int(q1["unit"])])
	# another captain has no such memory
	var other := _dock("spice", 1)
	eq(Captains.greeting(other), "", "another captain does not share her memory")
	check(Saves.save("suite_r7") and Saves.load_slot("suite_r7"), "saved and loaded")
	Saves.delete("suite_r7")
	eq(int(Captains.get_c(str(c2["id"])).get("trust", 0)), 1, "her trust survives a save")


func test_voyages_are_delayed_lost_and_unpaid_truthfully() -> void:
	fresh_game()
	Game.state["gold"] = 20000
	Trade.mark_seen("ingot_steel")
	# delayed, then landed
	var c := _dock("whaler", 0)
	var q := Captains.quote(str(c["id"]), "ingot_steel", 2)
	eq(Captains.commission("ingot_steel", 2, int(q["deposit"])), "", "commissioned")
	var v: Dictionary = Captains.voyages(str(c["id"]))[-1]
	_sail()
	var due0 := int(v["due"])
	Captains.force[str(v["id"])] = "delayed"
	_until_not(v, ["at_sea"])
	eq(str(v["status"]), "delayed", "the voyage is delayed")
	check(int(v["due"]) > due0, "with a new due day (%d → %d)" % [due0, int(v["due"])])
	check(Lore.of_actor(str(c["id"])).any(func(e): return str(e["kind"]) == "voyage_delayed" and str(e["text"]).contains(str(int(v["due"])))), "the delay is reported with the day it says")
	# lost at sea: half the deposit back
	var c2 := _dock("spice", 0)
	var q2 := Captains.quote(str(c2["id"]), "ingot_steel", 2)
	eq(Captains.commission("ingot_steel", 2, int(q2["deposit"])), "", "another voyage")
	var v2: Dictionary = Captains.voyages(str(c2["id"]))[-1]
	_sail()
	Captains.force[str(v["id"])] = "success"   # the delayed one lands when it comes due again
	Captains.force[str(v2["id"])] = "failed"
	_until_not(v2, ["at_sea"])
	eq(str(v2["status"]), "failed", "lost at sea")
	var refunds := (Game.state["ledger"] as Array).filter(func(l): return str(l.get("party", "")) == str(c2["id"]) and int(l["amount"]) > 0)
	check(refunds.size() == 1 and int(refunds[0]["amount"]) == int(v2["deposit"]) / 2, "half the deposit came back (%s)" % str(refunds))
	check(Captains.greeting(Captains.get_c(str(c2["id"]))).contains("lost"), "and the captain remembers the loss")
	# landed and left unpaid: sold elsewhere, trust falls
	var c3 := _dock("barge", 1)
	var q3 := Captains.quote(str(c3["id"]), "ingot_steel", 1)
	eq(Captains.commission("ingot_steel", 1, int(q3["deposit"])), "", "a third voyage")
	var v3: Dictionary = Captains.voyages(str(c3["id"]))[-1]
	_sail()
	Captains.force[str(v3["id"])] = "success"
	_until_not(v3, ["at_sea"])
	eq(str(v3["status"]), "arrived", "the third cargo landed")
	for i in Captains.ABANDON_DAYS + 2:
		Game.advance_minutes(1440)
	eq(str(v3["status"]), "abandoned", "an arrival left unpaid is given up")
	check(int(Captains.get_c(str(c3["id"]))["trust"]) < 0, "and the captain trusts the smith less")
	check(int(Captains.quote(str(c3["id"]), "ingot_steel", 1)["unit"]) > int(q3["unit"]), "a dearer price next time")
