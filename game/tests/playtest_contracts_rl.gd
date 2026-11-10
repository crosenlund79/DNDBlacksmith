## Rendered play-test phase "contracts_rl" (The Living Realm, milestone 5 — major contracts): the Project Bench set up in
## the workshop, a patron's letter arriving (toast), the letter at the bench (why it came, the terms), accepting it,
## an apprentice assigned through the queue, the smith working a block of hours, the bench mid-production with the
## patron's crate, the stacked goods and the apprentice at work, the bench prompt, the contract view and the Workshop
## Ledger mid-production, and the delivery. Called from tests/playtest.gd (phase_contracts_rl). Screenshots: ct_*.
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _view(name: String, center: Vector2, zoom := 1.0, aside := Vector2.ZERO) -> void:
	var w := _w()
	await pt.tp(center + aside)
	w.camera.offset = -aside
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.8)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE
	w.camera.offset = Vector2.ZERO


func _bench_pos() -> Vector2:
	var tp := Property.pos_of(Contracts.BENCH)
	return _w().bpos("smithy", tp.x, tp.y)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Game.state["gold"] = 6000
	(Game.state["hirelings"] as Array).clear()
	Game.state["stats"]["crafted"] = 9   # a working smith: nine pieces already sold from the shop
	Property.dev_grant_unit("cobbler")
	# ---- the Project Bench: bought and set up through Property
	pt.expect(Property.buy_station(Contracts.BENCH) == "", "contracts_rl: the Project Bench is bought")
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, Contracts.BENCH)
	pt.expect(why == "" and Property.commit(plan) == "", "contracts_rl: the bench is set up in a workshop room (%s)" % why)
	pt.main.call("rebuild_world")
	await pt.wait(2.5)
	pt.note("   bench at %s (room %s)" % [str(Property.pos_of(Contracts.BENCH)), str(Property.room_at_tile(Property.rooms(), Property.pos_of(Contracts.BENCH)).get("id", ""))])
	await _view("ct_bench_in_workshop", _bench_pos(), 0.9, Vector2(0, 240))
	# ---- a letter arrives with the morning
	Contracts.st()["last_offer_day"] = 0
	var g := 0
	while Contracts.offers().is_empty() and g < 10:
		await pt.advance_to(0, 5)
		g += 1
	await pt.advance_to(8, 0)
	Vitality.sleep()   # the smith slept through those nights
	pt.expect(not Contracts.offers().is_empty(), "contracts_rl: a patron's letter arrives (%d)" % Contracts.offers().size())
	if Contracts.offers().is_empty():
		return
	var o: Dictionary = Contracts.offers()[0]
	Events.toast.emit("A messenger brings a sealed letter from %s: %s. Read it at your Project Bench or in the Workshop Ledger (%s)." % [Contracts.patron_name(str(o["patron"])), o["title"], Settings.key_label("panel_workshop")], "good")
	await pt.wait(0.4)
	await pt.shot("ct_letter_arrives")
	# ---- the letter at the bench
	await pt.use("station", Contracts.BENCH)
	await pt.wait(0.6)
	pt.expect(pt.panel() is ContractsPanel, "contracts_rl: the bench opens the contract view")
	await pt.shot("ct_letter_at_bench")
	await pt.click("Accept the order")
	await pt.wait(0.5)
	var cid := str(o["id"])
	var c := Contracts.get_c(cid)
	pt.expect(str(c.get("status", "")) == "active", "contracts_rl: the order is accepted")
	await pt.shot("ct_accepted")
	await pt.close_panel()
	# ---- an apprentice, materials, hours queued
	pt.note(ApprenticeDev.unlock())
	while Apprentices.applicants().is_empty():
		ApprenticeDev.add_applicant()
	pt.expect(Apprentices.hire(0) == "", "contracts_rl: an apprentice is taken on")
	var a: Dictionary = Apprentices.staff()[0]
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 4, "xp": 0}
	for d in Contracts.materials_needed(c):
		Game.add_item(Items.make(str(d), {"qty": int(Contracts.materials_needed(c)[d])}), false)
	var t := Apprentices.add_task("contract", {"target": cid, "repeat": 8, "assignee": str(a["id"]), "priority": 3})
	pt.expect(not t.has("error"), "contracts_rl: hours queued for %s (%s)" % [a["name"], t.get("error", "")])
	# ---- the smith works a block at the bench (through the view's button)
	await pt.use("station", Contracts.BENCH)
	await pt.wait(0.4)
	await pt.click("Work 2 h")
	await pt.wait(3.6)
	pt.expect(float(c["hours_done"]) > 1.0, "contracts_rl: two hours at the bench went into the order (%.1f h)" % float(c["hours_done"]))
	await pt.close_panel()
	Game.advance_minutes(30)   # mid-morning: the apprentice is at work (the break is at noon)
	await pt.wait(0.5)
	var acts := _w().get_node_or_null("ApprenticeActors") as ApprenticeActors
	if acts:
		acts._t = 0.0
	await pt.wait(4.0)
	var pl := ApprenticeActors.plan_for(a)
	pt.note("   %s: %s at %s · %s" % [a["name"], pl["kind"], pl["station"], a.get("activity", "")])
	pt.expect(str(pl["station"]) != "", "contracts_rl: the apprentice works the order at a station (%s)" % pl["station"])
	pt.expect(int(ContractWorld.state_now()["goods"]) >= 1, "contracts_rl: finished goods stand beside the bench")
	await _view("ct_bench_mid_production", _bench_pos(), 1.3, Vector2(-260, 150))
	# the prompt, facing the bench
	var e: Dictionary = pt.find_entry("station", Contracts.BENCH)
	await pt.tp((e["pos"] as Vector2) + Vector2(0, 96))
	_w().player.facing = "n"
	await pt.wait(1.4)
	await pt.shot("ct_bench_prompt")
	# ---- the contract view mid-production, and the Workshop Ledger
	Events.open_panel.emit("contracts", {"id": cid})
	await pt.wait(0.6)
	await pt.shot("ct_view_mid_production")
	await pt.close_panel()
	await pt.press("panel_workshop")
	await pt.wait(0.6)
	pt.expect(pt.panel() is WorkshopPanel, "contracts_rl: the Workshop Ledger opens")
	await pt.shot("ct_ledger_contract")
	await pt.close_panel()
	# ---- finish and deliver
	var guard := 0
	while not Contracts.ready(cid) and guard < 40:
		Vitality.set_fatigue(0.0)
		var r := Contracts.work(cid, 4)
		if str(r.get("error", "")) != "":
			pt.note("   work stopped: " + str(r["error"]))
			break
		guard += 1
	pt.expect(Contracts.ready(cid), "contracts_rl: every piece is made")
	if acts:
		acts._t = 0.0
	await pt.wait(1.0)
	await _view("ct_bench_finished", _bench_pos(), 1.3, Vector2(-260, 150))
	await pt.use("station", Contracts.BENCH)
	await pt.wait(0.5)
	await pt.shot("ct_ready_to_deliver")
	await pt.click("Deliver the order")
	await pt.wait(0.6)
	pt.expect(str(Contracts.get_c(cid).get("status", "")) == "delivered", "contracts_rl: the order is delivered (%s)" % Contracts.get_c(cid).get("outcome", ""))
	await pt.shot("ct_delivered")
	await pt.close_panel()
