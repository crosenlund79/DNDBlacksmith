## Rendered play-test phase "honor_guard" (R4 "Commissions v2 & Civic Recipients"): the reeve's letter for an honour
## guard — ten helms and ten round shields for the ranks and three pieces named in the letter (Vigil, Hearthward,
## Millstone); the order in hand with its named pieces as work orders; the bench pieces worked; the named pieces laid in
## (Vigil forged by the smith's own hand); delivery; the closed order with the lot record and the named pieces now at
## the Brindlewick muster; a save/load with every piece still traceable. Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.wait(0.6)
	await pt.shot(name)


func _piece(def: String, q: float) -> Dictionary:
	var it := Items.make(def, {"quality": q})
	Provenance.forged(it)
	Game.add_item(it, false)
	return it


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Game.state["gold"] = 8000
	pt.expect(Property.buy_station(Contracts.BENCH) == "" or Contracts.bench_installed(), "honor_guard: the Project Bench is bought")
	var plan := Property.plan_copy()
	if not Contracts.bench_installed():
		var why := Property.auto_place(plan, Contracts.BENCH)
		pt.expect(why == "" and Property.commit(plan) == "", "honor_guard: the bench is set up (%s)" % why)
	pt.main.call("rebuild_world")
	await pt.advance_to(10, 0)
	await pt.wait(1.0)
	var c := Contracts.make_offer("honor_guard")
	pt.expect(not c.has("error"), "honor_guard: the reeve's letter arrives")
	var cid := str(c.get("id", ""))
	Events.open_panel.emit("contracts", {"id": cid})
	await _shot("honor_guard_letter")
	pt.expect(pt.panel() is ContractsPanel, "honor_guard: the contracts panel shows the letter")
	pt.expect(Contracts.accept(cid) == "", "honor_guard: the order is accepted")
	await pt.close_panel()
	c = Contracts.get_c(cid)
	Game.add_item(Items.make("ingot_iron", {"qty": 24}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 24}), false)
	Contracts.add_hours(c, 200.0, 88.0, "smith")
	pt.expect(int(c["units_done"]) == 20, "honor_guard: the twenty bench pieces are made")
	Events.open_panel.emit("contracts", {"id": cid})
	await _shot("honor_guard_named_waiting")
	pt.expect(not Contracts.ready(cid), "honor_guard: not ready without the named pieces")
	await pt.close_panel()
	# the three named pieces: Vigil by the smith's own hand, the others too (the staff path is covered by t_r4_commissions)
	var defs := ["sword_steel", "cuirass_steel", "shield_tower"]
	for i in 3:
		var it := _piece(defs[i], 96.0)
		var err := Contracts.lay_in_named(cid, i, int(it["uid"]))
		pt.expect(err == "", "honor_guard: «%s» laid in (%s)" % [str(c["named"][i]["name"]), err])
	Events.open_panel.emit("contracts", {"id": cid})
	await _shot("honor_guard_ready")
	pt.expect(Contracts.ready(cid), "honor_guard: the order is ready")
	await pt.close_panel()
	var o := Contracts.deliver(cid)
	pt.expect(not o.has("error"), "honor_guard: delivered (%s)" % str(o.get("outcome", o.get("error", ""))))
	Events.open_panel.emit("contracts", {"id": cid})
	await _shot("honor_guard_delivered")
	await pt.close_panel()
	pt.expect(Institutions.holds("muster", "helm_iron") == 10 and Institutions.stock("muster").size() == 3, "honor_guard: the muster holds the helms and the three named pieces")
	var uids := Institutions.stock("muster").map(func(x): return int(x["uid"]))
	pt.expect(Saves.save("pt_honor") and Saves.load_slot("pt_honor"), "honor_guard: saved and loaded")
	await pt.wait(1.5)
	var ok := true
	for u in uids:
		var it2 := ItemRegistry.find(int(u))
		ok = ok and not it2.is_empty() and str(it2.get("given_name", {}).get("name", "")) != ""
	pt.expect(ok, "honor_guard: after loading every named piece is still at the muster, named")
	if not uids.is_empty():
		var it3 := ItemRegistry.find(int(uids[0]))
		pt.note("honor_guard: %s — %d events in its history" % [Items.display_name(it3), Lore.of_item(int(uids[0])).size()])
