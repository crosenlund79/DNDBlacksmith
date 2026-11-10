## Rendered play-test phase "a2_experience" (Milestone A2, EXPERIENCE worker): the four early-game observations.
##  1. The selling tutorial: the "Serve a customer" step stays on screen while nobody is waiting (a background sale such
##     as Borin's horseshoes does not complete it), says who is on the way / waiting, and completes when the smith serves.
##  2. The consultation: an adventurer who wants better gear, with a fitting piece in the stores, gets a real offer; the
##     footer ("Finish the consultation") sits at the bottom of the window, visible without scrolling; when the forge
##     has nothing they would buy, the screen says why and what to do next.
##  8. The stores with 120 pieces fit the screen; the details column scrolls and can be collapsed.
##  9. Selling to an adventurer at the counter: a compact grid of pieces, a details view (their piece vs this one, the
##     price, would they buy) and an explicit "Sell for N g" — with 1, 10 and 60 pieces on display.
## Shot names: a2x_<tag>_<res>_* (tag from the A2_TAG environment variable, default "after"; res = window height).
## Called from tests/playtest.gd (phase_a2_experience).
extends RefCounted

var pt: Node
var tag := "after"


func _name(n: String) -> String:
	return "a2x_%s_%d_%s" % [tag, DisplayServer.window_get_size().y, n]


func _shot(n: String) -> void:
	await pt.wait(0.4)
	await pt.shot(_name(n))


## Is the control wholly inside the visible viewport (the logical 1920×1080 canvas)?
func _on_screen(c: Control) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	var vr := pt.get_viewport().get_visible_rect()
	var r := c.get_global_rect()
	return vr.encloses(r.grow(-1.0))


func _seat_all() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _equipment_pool(n: int) -> Array:
	var defs := []
	for id in DB.items:
		var sl: Variant = DB.items[id].get("slot")
		if sl is String and sl != "" and sl != "companion":
			defs.append(str(id))
	defs.sort()
	var out := []
	var rar := ["common", "common", "magic", "rare", "common", "legendary"]
	for i in n:
		var it := Items.make(str(defs[i % defs.size()]), {"quality": 70.0 + float(i % 7) * 6.0})
		it["rarity"] = rar[i % rar.size()]
		out.append(it)
	return out


func run(p: Node) -> void:
	pt = p
	var t := OS.get_environment("A2_TAG")
	tag = t if t != "" else "after"
	await pt.click("New Game")
	await pt.wait(2.5)
	await _tutorial()
	await _consult()
	await _inventory()
	await _offer()


# ------------------------------------------------------------------ 1. the selling tutorial
func _tutorial() -> void:
	Tutorial.restart()
	for id in ["move", "interact", "craft", "dice"]:
		Tutorial.complete(id)
	Shop.customers().clear()
	await pt.advance_to(8, 30)
	Shop.customers().clear()
	pt.expect(str(Tutorial.current().get("id", "")) == "customer", "a2 tutorial: 'Serve a customer' is the current step")
	# Borin sells horseshoes and nails while the smith is elsewhere (the same ledger line hirelings.gd writes)
	Game.add_gold(4, "sales", "Borin sold horseshoes and nails")
	await pt.wait(0.8)
	pt.expect(str(Tutorial.current().get("id", "")) == "customer", "a2 tutorial: a background sale does not complete the selling step")
	await _shot("tutorial_nobody_waiting")
	# a customer sets out and sits down
	Shop.customers().clear()
	Shop._add_customer("mira", "browse")
	await pt.advance_to(10, 0)
	_seat_all()
	await pt.wait(1.2)
	pt.expect(str(Tutorial.current().get("id", "")) == "customer", "a2 tutorial: still the selling step with a customer at the counter")
	await _shot("tutorial_customer_ready")


# ------------------------------------------------------------------ 2. the consultation
func _consult() -> void:
	# Kestra wants a kit worth trusting; the smith has just forged an iron longsword (still in the stores)
	var a := Adv.get_a("kestra")
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a.erase("next_dest")
	a.erase("planned_dest")
	var sw := Items.make("sword_iron", {"quality": 92.0})
	Provenance.forged(sw)
	Game.add_item(sw, false)
	Shop.customers().clear()
	Consult.approach("kestra", {"kind": "goal", "text": "I want a kit worth trusting. Where would you have me spend my coin, smith?"})
	_seat_all()
	Events.open_panel.emit("consult", {"id": "kestra"})
	await pt.wait(0.9)
	var ses := Consult.session("kestra")
	var kinds := (ses.get("recs", []) as Array).map(func(r): return str(r["kind"]))
	pt.note("a2 consult kestra recs: " + " | ".join((ses.get("recs", []) as Array).map(func(r): return "%s: %s" % [r["kind"], r["title"]])))
	pt.expect(kinds.has("buy"), "a2 consult: the longsword from the stores is offered (not praise only)")
	var fin: Button = pt.find_button(pt.panel(), "Finish the consultation") if pt.panel() else null
	pt.expect(fin != null and _on_screen(fin), "a2 consult: 'Finish the consultation' is visible without scrolling")
	if fin != null:
		pt.note("a2 consult: finish button at y=%d (window bottom %d)" % [int(fin.get_global_rect().end.y), int(pt.panel().get_global_rect().end.y)])
	await _shot("consult_offer")
	await pt.close_panel()
	Consult.finish("kestra")
	# Varn: nothing the forge has would do for him (the longsword is beyond his purse) — the screen says why
	sw["for_sale"] = true
	var v := Adv.get_a("varn")
	Expeditions.ensure(v)
	v["status"] = "in_town"
	v.erase("next_dest")
	v.erase("planned_dest")
	v["gold"] = 30
	Events.open_panel.emit("consult", {"id": "varn"})
	await pt.wait(0.9)
	pt.expect(pt.find_label_containing(pt.panel(), "can't afford") != null, "a2 consult: the screen explains why nothing is offered")
	await _shot("consult_nothing_suits")
	await pt.close_panel()
	Consult.finish("varn")
	Game.take_uid(int(sw["uid"]))


# ------------------------------------------------------------------ 8. the stores
func _inventory() -> void:
	for it in _equipment_pool(110):
		Game.add_item(it, false)
	for d in ["ore_iron", "coal", "leather_cured", "herb_moonwort", "ingot_iron", "ingot_steel", "potion_healing", "runestone_blank", "reagent_salt", "cloth_linen"]:
		if DB.items.has(d):
			Game.add_item(Items.make(d, {"qty": 7}), false)
	pt.note("a2 inventory: %d items in the stores" % Game.inventory().size())
	Events.open_panel.emit("inventory", {})
	await pt.wait(0.8)
	var inv := pt.panel() as InventoryPanel
	pt.expect(inv != null, "a2 inventory: the stores open")
	if inv == null:
		return
	# select a forged piece with a long tooltip (its record of work, maker, history)
	var pick := {}
	for it in Game.inventory():
		if Items.is_equipment(it) and str(it.get("rarity", "")) == "legendary":
			pick = it
			break
	if not pick.is_empty():
		Provenance.forged(pick)
		Items.add_history(pick, "Shown to the reeve on market day.")
		inv.call("_select", pick)
		await pt.wait(0.6)
	pt.expect(_on_screen(inv), "a2 inventory: the whole window is on screen with 120 items and a piece selected (%s)" % str(inv.get_global_rect()))
	await _shot("inventory_selected")
	var col: Button = pt.find_button(inv, "Hide details")
	if col != null:
		col.pressed.emit()
		await pt.wait(0.5)
		pt.expect(_on_screen(inv), "a2 inventory: collapsed details — still on screen")
		await _shot("inventory_collapsed")
		var ex: Button = pt.find_button(inv, "Details")
		if ex != null:
			ex.pressed.emit()
			await pt.wait(0.3)
	else:
		pt.expect(false, "a2 inventory: a 'Hide details' toggle")
	await pt.close_panel()


# ------------------------------------------------------------------ 9. selling to an adventurer at the counter
func _offer() -> void:
	for it in Game.inventory().duplicate():
		if Items.is_equipment(it):
			Game.take_uid(int(it["uid"]))
	var a := Adv.get_a("pip")
	a["status"] = "in_town"
	a["gold"] = 400
	var good := Items.make("sword_iron", {"quality": 96.0})
	Provenance.forged(good)
	good["for_sale"] = true
	Game.add_item(good, false)
	for n in [1, 10, 60]:
		var have := Shop.stock().filter(func(x): return Items.is_equipment(x)).size()
		for it in _equipment_pool(maxi(0, n - have)):
			it["for_sale"] = true
			Game.add_item(it, false)
		Shop.customers().clear()
		Shop._add_customer("pip", "browse")
		_seat_all()
		Events.open_panel.emit("shop", {"npc": "pip"})
		await pt.wait(0.9)
		var sp: Control = pt.panel()
		pt.expect(sp is ShopPanel and _on_screen(sp), "a2 offer: the counter with %d pieces on display fits the screen (%s)" % [n, str(sp.get_global_rect()) if sp else "-"])
		await _shot("offer_%d" % n)
		await pt.close_panel()
	# select the longsword, then sell it with the explicit button
	Events.open_panel.emit("shop", {"npc": "pip"})
	await pt.wait(0.9)
	var picker: Node = pt.panel().find_child("OfferPicker", true, false) if pt.panel() else null
	pt.expect(picker != null, "a2 offer: the graphical offer picker")
	if picker != null:
		picker.call("select_uid", int(good["uid"]))
		await pt.wait(0.4)
		pt.expect(Game.find_uid(int(good["uid"])).size() > 0, "a2 offer: choosing a piece does not sell it")
		await _shot("offer_selected")
		var sell: Button = pt.find_button(picker, "Sell for")
		pt.expect(sell != null, "a2 offer: an explicit 'Sell for N g' button")
		if sell != null:
			sell.pressed.emit()
			await pt.wait(0.6)
			pt.expect(Game.find_uid(int(good["uid"])).is_empty() and int(a["equipment"]["weapon"]["uid"]) == int(good["uid"]), "a2 offer: Pip bought and wears the longsword")
	await _shot("offer_sold")
	pt.expect(Tutorial.is_done("customer"), "a2 tutorial: serving Pip at the counter completes the selling step")
	await pt.close_panel()
	await _shot("tutorial_after_sale")
