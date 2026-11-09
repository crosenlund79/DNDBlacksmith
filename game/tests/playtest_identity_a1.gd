## Rendered play-test phase "identity_a1" (Milestone A1 — item identity): the screens that now read a piece through
## ItemRegistry must look exactly as before. A piece bought from the Brask caravan keeps its uid and its whole story
## (item inspection, History tab); an adventurer's repair request at the counter refers to the piece they wear (the
## card reads the live piece); a delivered contract's masterpiece is shown from the holdings archive. The integrity
## probe is run at each step. Called from tests/playtest.gd (phase_identity_a1). Screenshots: id_*.
extends RefCounted

var pt: Node


func _clean(what: String) -> void:
	var r := ItemRegistry.scan()
	pt.expect((r["dup"] as Array).is_empty() and (r["shared"] as Array).is_empty() and (r["stray"] as Array).is_empty(),
		"identity_a1: %s — %s" % [what, ItemRegistry.scan_text(r)])


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Game.state["gold"] = 50000
	(Game.state["hirelings"] as Array).clear()
	_clean("a new game")
	# ---- a caravan piece: bought, same uid, story intact
	var k := -1
	for i in 30:
		Commerce.dev_force_caravan()
		var stock: Array = Commerce.caravan()["stock"]
		for j in stock.size():
			if stock[j].has("item") and Items.is_equipment(stock[j]["item"]):
				k = j
		if k >= 0:
			break
	pt.expect(k >= 0, "identity_a1: the caravan brought a piece of equipment")
	if k >= 0:
		var it: Dictionary = Commerce.caravan()["stock"][k]["item"]
		var uid := int(it["uid"])
		pt.expect(Commerce.buy_caravan(k) == "", "identity_a1: bought from the caravan")
		pt.expect(is_same(Game.find_uid(uid), it), "identity_a1: the very piece is in the stores (uid %d)" % uid)
		Events.open_panel.emit("item", {"uid": uid, "tab": "History"})
		await pt.wait(0.8)
		await pt.shot("id_caravan_piece_history")
		await pt.press("cancel")   # the inspection is an overlay
		await pt.wait(0.3)
		await pt.close_panel()
	_clean("after the caravan purchase")
	# ---- an adventurer's repair request refers to the piece they wear
	var a := {}
	for x in Adv.all().values():
		if str(x.get("status", "")) != "dead" and not (x.get("equipment", {}).get("weapon", {}) as Dictionary).is_empty():
			a = x
			break
	if not a.is_empty():
		var w: Dictionary = a["equipment"]["weapon"]
		w["stats"]["durability"] = 6
		Shop.customers().clear()
		Shop._add_customer(str(a["id"]), "repair_own")
		Shop.mark_arrived(str(a["id"]), false)
		var c := Shop.customer(str(a["id"]))
		pt.expect(ItemRegistry.is_ref(c.get("item", {})), "identity_a1: the counter request holds a reference")
		w["stats"]["durability"] = 9   # the card must show the live piece (9), not a copy taken at the door (6)
		pt.expect(str(Shop.request(c).get("condition", "")).begins_with("durability 9 /"), "identity_a1: the request reads the live piece (%s)" % Shop.request(c).get("condition", ""))
		Events.open_panel.emit("shop", {"tab": "customers", "npc": str(a["id"])})
		await pt.wait(0.8)
		await pt.shot("id_counter_repair_request")
		await pt.close_panel()
	_clean("with a repair request at the counter")
	# ---- a delivered masterpiece, shown from the holdings archive
	SkillTree.unlock_all()
	Property.dev_grant_unit("cobbler")
	var ok := Property.buy_station(Contracts.BENCH) == ""
	var plan := Property.plan_copy()
	ok = ok and Property.auto_place(plan, Contracts.BENCH) == "" and Property.commit(plan) == ""
	pt.expect(ok and Contracts.bench_installed(), "identity_a1: the Project Bench is set up")
	var o := Contracts.make_offer("watch_arms")
	var cid := str(o.get("id", ""))
	pt.expect(cid != "" and Contracts.accept(cid) == "", "identity_a1: the Watch's order is taken")
	var mp := Items.make("sword_iron", {"quality": 121.0, "crafted_by": Provenance.SMITH_NAME})
	Provenance.forged(mp)
	Game.add_item(mp, false)
	var muid := int(mp["uid"])
	pt.expect(Contracts.lay_in_masterpiece(cid, muid) == "", "identity_a1: the masterpiece is laid in")
	var c2 := Contracts.get_c(cid)
	for d in Contracts.materials_needed(c2):
		Game.add_item(Items.make(str(d), {"qty": int(Contracts.materials_needed(c2)[d])}), false)
	for d in c2.get("rare", {}):
		Game.add_item(Items.make(str(d), {"qty": int(c2["rare"][d])}), false)
	var g := 0
	while not Contracts.ready(cid) and g < 200:
		Vitality.set_fatigue(0.0)
		if str(Contracts.work(cid, 4).get("error", "")) != "":
			break
		g += 1
	var r := Contracts.deliver(cid)
	pt.expect(bool(r.get("masterpiece", false)), "identity_a1: delivered with the masterpiece")
	pt.expect(str(ItemRegistry.where(muid).get("holder", "")) == "holdings", "identity_a1: the masterpiece is in the holdings archive")
	Events.open_panel.emit("contracts", {"id": cid})
	await pt.wait(0.8)
	await pt.shot("id_contract_masterpiece_archived")
	var shown := false
	if pt.panel() != null:
		for s in pt.panel().find_children("*", "ItemSlot", true, false):
			if is_same((s as ItemSlot).item, mp):
				shown = true
	pt.expect(shown, "identity_a1: the closed order shows the live masterpiece from the archive (not a copy)")
	if pt.panel() != null:
		for sc in pt.panel().find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000
	await pt.wait(0.5)
	await pt.shot("id_contract_masterpiece_archived_end")
	await pt.close_panel()
	_clean("after the delivery")
