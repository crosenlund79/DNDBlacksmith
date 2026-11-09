## Milestone A2 — early-game experience (EXPERIENCE worker), observations 1, 2, 8 and 9:
##  1. the selling tutorial step stays until the smith serves a customer himself: background income (Borin's horseshoes,
##     an adventurer helping themselves from the display, the steward) does not complete it; its live status says who is
##     waiting, who is on the way, or that nobody is;
##  2. a consultation never offers praise alone when the forge has a suitable piece (the stores count, not only the
##     display); the footer stays outside the scroll; when nothing suits, the screen says why and what to do next;
##  8. the stores window fits the 1920×1080 canvas (1600×900 is the same canvas scaled) with 120 pieces, its details
##     column scrolls and collapses;
##  9. the graphical offer at the counter builds with 1, 10 and 60 pieces, choosing a piece never sells it, and the
##     explicit "Sell for N g" sells through Shop.sell_to with a real payer.
extends SuiteCase

const SMOKE := ["test_tutorial_waits_for_counter", "test_consult_offers_stores_piece", "test_offer_picker_confirms"]
const CANVAS := Vector2(1920, 1080)


# ------------------------------------------------------------------ fixtures
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Control) -> Control:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r != null:
			return r
	return null


func _text_in(n: Node, needle: String) -> bool:
	return _find(n, func(x): return (x is Label and (x as Label).text.contains(needle)) or (x is RichTextLabel and (x as RichTextLabel).text.contains(needle)) \
		or (x is Button and (x as Button).text.contains(needle))) != null


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a.erase("next_dest")
	a.erase("planned_dest")
	return a


func _equipment(n: int, for_sale: bool) -> Array:
	var defs := []
	for id in DB.items:
		var sl: Variant = DB.items[id].get("slot")
		if sl is String and sl != "" and sl != "companion":
			defs.append(str(id))
	defs.sort()
	var out := []
	for i in n:
		var it := Items.make(str(defs[i % defs.size()]), {"quality": 70.0 + float(i % 7) * 6.0})
		if for_sale:
			it["for_sale"] = true
		Game.add_item(it, false)
		out.append(it)
	return out


func _to_step_customer() -> void:
	Tutorial.restart()
	for id in ["move", "interact", "craft", "dice"]:
		Tutorial.complete(id)


func _income(amount: int, cat: String, note_text: String) -> void:
	Game.add_gold(amount, cat, note_text)
	Tutorial._on_gold(Game.gold())   # what the Events.gold_changed hook does in the running game


# ------------------------------------------------------------------ 1. the selling tutorial
func test_tutorial_waits_for_counter() -> void:
	_to_step_customer()
	Shop.customers().clear()
	eq(str(Tutorial.current().get("id", "")), "customer", "the selling step is current")
	# no counter open (no UI in the suite) and no override: background income never counts
	Tutorial.serving_override = null
	check(not Tutorial.serving_at_counter(), "without a counter panel the smith is not serving")
	_income(4, "sales", "Borin sold horseshoes and nails")
	_income(12, "repairs", "Repaired Tobin's sword")
	_income(30, "sales", "Mira bought a healing draught")
	eq(str(Tutorial.current().get("id", "")), "customer", "background sales and repairs leave the selling step in place")
	# the real hireling path: Borin smiths with no ore and sells horseshoes
	var borin := Hire.get_h("borin")
	if not borin.is_empty():
		borin["alloc"] = {"smithing": 100}
		borin["status"] = "working"
		Game.remove_def("ore_iron", Game.count("ore_iron"))
		var g0 := Game.gold()
		var m := int(Game.state["minute"]) % 1440
		Game.advance_minutes((10 * 60 - m + 1440) % 1440)   # into working hours
		Shop.customers().clear()
		for i in 12:
			Hire.work_hour(10)
			Tutorial._on_gold(Game.gold())
		note("Borin earned %d g at the forge without the smith" % (Game.gold() - g0))
		eq(str(Tutorial.current().get("id", "")), "customer", "Borin's horseshoe sales do not complete the step")
	# the live status: nobody / on the way / waiting
	var st := Tutorial.customer_status()
	check(str(st.get("state", "")) in ["none", "closed"], "status with nobody about: %s" % st.get("state", "?"))
	Shop._add_customer("mira", "browse")
	eq(str(Tutorial.customer_status().get("state", "")), "coming", "a customer who set out is 'on the way'")
	Shop.mark_arrived("mira", false)
	var ready := Tutorial.customer_status()
	eq(str(ready.get("state", "")), "ready", "a seated customer is 'ready'")
	check(str(ready.get("text", "")).contains("Mira"), "the status names her: " + str(ready.get("text", "")))
	# the steward in charge: never counts as the smith serving
	Tutorial.serving_override = null
	check(not Tutorial.serving_at_counter(), "nothing open → not serving")
	# the smith sells to her at the counter
	Tutorial.serving_override = true
	var sw := Items.make("sword_iron", {"quality": 95.0})
	sw["for_sale"] = true
	Game.add_item(sw, false)
	var a := Adv.get_a("mira")
	a["gold"] = 500
	var err := Shop.sell_to("mira", int(sw["uid"]))
	Tutorial._on_gold(Game.gold())
	Tutorial.serving_override = null
	eq(err, "", "the sale goes through")
	check(Tutorial.is_done("customer"), "serving her at the counter completes the step")
	check(save_load("t_exp_a2_tut"), "save/load")
	check(Tutorial.is_done("customer") and not Tutorial.is_done("skills"), "the tutorial progress survives save/load")


# ------------------------------------------------------------------ 2. consultations
func test_consult_offers_stores_piece() -> void:
	var a := _adv("kestra")
	var sw := Items.make("sword_iron", {"quality": 92.0})
	Provenance.forged(sw)
	Game.add_item(sw, false)   # just forged: in the stores, not on display
	var recs := Consult.recommendations(a)
	note("recs: " + " | ".join(recs.map(func(r): return "%s: %s" % [r["kind"], r["title"]])))
	var buy := {}
	for r in recs:
		if str(r["kind"]) == "buy":
			buy = r
	check(not buy.is_empty() and int(buy.get("uid", -1)) == int(sw["uid"]), "the longsword in the stores is advised")
	check(not buy.is_empty() and str(buy["details"][0]).contains("stores"), "the details say it comes from the stores")
	# the advice runs through the ordinary sale: a real payer and a ledger line
	var g0 := Game.gold()
	var purse := int(a["gold"])
	var eff := Consult._apply(a, buy) if not buy.is_empty() else "!"
	check(not eff.begins_with("!"), "accepted advice sells it: " + eff)
	eq(Game.gold() - g0, int(buy.get("cost", 0)), "the smith is paid the advised price")
	eq(purse - int(a["gold"]), int(buy.get("cost", 0)), "she pays it from her purse")
	eq(int(a["equipment"]["weapon"]["uid"]), int(sw["uid"]), "she wears the very same blade (same uid)")
	var l: Dictionary = (Game.state["ledger"] as Array)[-1]
	eq(str(l["cat"]), "sales", "the sale is in the ledger")


## Never praise alone when the forge holds something they would buy: every adventurer in town, with a mixed stock.
func test_never_praise_only_with_suitable_stock() -> void:
	_equipment(24, false)
	_equipment(12, true)
	var checked := 0
	for id in Adv.all():
		var a := Adv.get_a(str(id))
		if not str(a.get("status", "")) in ["in_town", "injured"]:
			continue
		a["gold"] = maxi(int(a["gold"]), 400)
		var suitable := false
		for s in Adv.desired_slots(a):
			if str(s) != "companion" and not Adv.best_stock(a, str(s), Consult.offer_pool()).is_empty():
				suitable = true
		if not suitable:
			continue
		checked += 1
		var kinds := Consult.recommendations(a).map(func(r): return str(r["kind"]))
		check(kinds.has("buy") or kinds.has("coat"), "%s gets an offer from the forge (got %s)" % [id, str(kinds)])
		check(not (kinds.size() == 1 and kinds[0] == "keep"), "%s is not given praise alone" % id)
	check(checked >= 3, "several adventurers had something suitable (%d)" % checked)


func test_consult_panel_footer_and_reasons() -> void:
	var v := _adv("varn")
	v["gold"] = 30
	var sw := Items.make("sword_iron", {"quality": 92.0})
	sw["for_sale"] = true
	Game.add_item(sw, false)
	var p := _mount(ConsultPanel.new("varn")) as ConsultPanel
	var foot := p.find_child("ConsultFooter", true, false)
	check(foot != null, "the consultation has a footer")
	check(foot != null and foot.get_parent() == p.content, "the footer sits below the scroll, not inside it")
	check(_find(p, func(x): return x is Button and (x as Button).text == "Finish the consultation") != null, "Finish is in the footer")
	var note_n := p.find_child("NoOfferNote", true, false)
	check(note_n != null, "with nothing he would buy the screen explains it")
	check(note_n != null and _text_in(note_n, "can't afford"), "…and says why (he can't afford the longsword)")
	check(note_n != null and _text_in(note_n, "Next:"), "…and what to do next")
	check(p.get_combined_minimum_size().y <= CANVAS.y and p.get_combined_minimum_size().x <= CANVAS.x, "the window fits the canvas (%s)" % str(p.get_combined_minimum_size()))
	_unmount(p)


# ------------------------------------------------------------------ 8. the stores
func test_inventory_fits_with_120_items() -> void:
	_equipment(110, false)
	for d in ["ore_iron", "coal", "leather_cured", "herb_moonwort", "ingot_iron", "ingot_steel", "potion_healing", "runestone_blank", "reagent_salt", "cloth_linen"]:
		if DB.items.has(d):
			Game.add_item(Items.make(d, {"qty": 5}), false)
	check(Game.inventory().size() >= 120, "120 pieces in the stores (%d)" % Game.inventory().size())
	# the logical canvas is 1920×1080 at every window size of this aspect (1600×900 scales it)
	eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items", "the UI scales with the window")
	eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080, "the canvas is 1080 high")
	InventoryPanel.details_open = true
	var p := _mount(InventoryPanel.new()) as InventoryPanel
	var long := {}
	for it in Game.inventory():
		if Items.is_equipment(it):
			long = it
			break
	Provenance.forged(long)
	for i in 12:
		Items.add_history(long, "Day %d — shown to a curious traveller at the counter." % (i + 1))
	p._select(long)
	var ms := p.get_combined_minimum_size()
	check(ms.x <= CANVAS.x - 40 and ms.y <= CANVAS.y - 120, "the window fits the canvas with a long piece selected (%s)" % str(ms))
	check(p.detail_scroll is ScrollContainer and p.detail_scroll.visible, "the details column scrolls")
	var open_cols := p.grid.columns
	var tg := p.find_child("DetailsToggle", true, false) as Button
	check(tg != null, "a toggle collapses the details")
	if tg != null:
		tg.pressed.emit()
	check(not p.detail_scroll.visible and p.grid.columns > open_cols, "collapsed: no details column and a wider grid (%d → %d columns)" % [open_cols, p.grid.columns])
	check(p.get_combined_minimum_size().y <= CANVAS.y - 120, "still fits collapsed")
	p._select(long)
	check(p.detail_scroll.visible, "clicking a piece opens the details again")
	_unmount(p)
	InventoryPanel.details_open = true


# ------------------------------------------------------------------ 9. the offer at the counter
func test_offer_picker_confirms() -> void:
	var a := _adv("pip")
	a["gold"] = 600
	var good := Items.make("sword_iron", {"quality": 96.0})
	good["for_sale"] = true
	Game.add_item(good, false)
	for n in [1, 10, 60]:
		var have := Shop.stock().filter(func(x): return Items.is_equipment(x)).size()
		if n > have:
			_equipment(n - have, true)
		Shop.customers().clear()
		Shop._add_customer("pip", "browse")
		Shop.mark_arrived("pip", false)
		var req := Shop.request(Shop.customer("pip"))
		var cands := OfferPicker.candidates("pip", req)
		eq(cands.size(), maxi(n, have), "%d pieces offered" % maxi(n, have))
		var pk := _mount(OfferPicker.new("pip", req)) as OfferPicker
		var ms := pk.get_combined_minimum_size()
		check(ms.y <= 330.0 and ms.x <= 1150.0, "%d pieces: the picker stays compact (%s)" % [n, str(ms)])
		# the counter itself fits the canvas
		var sp := _mount(ShopPanel.new("customers", "pip")) as ShopPanel
		check(sp.find_child("OfferPicker", true, false) != null, "%d pieces: the counter shows the graphical picker" % n)
		check(sp.get_combined_minimum_size().y <= CANVAS.y, "%d pieces: the counter fits the canvas (%s)" % [n, str(sp.get_combined_minimum_size())])
		_unmount(sp)
		_unmount(pk)
	# choosing never sells; the explicit button does
	var req2 := Shop.request(Shop.customer("pip"))
	var pk2 := _mount(OfferPicker.new("pip", req2)) as OfferPicker
	pk2.select_uid(int(good["uid"]))
	(pk2.cells[int(good["uid"])] as ItemSlot).clicked.emit(good)
	check(not Game.find_uid(int(good["uid"])).is_empty(), "choosing a piece does not sell it")
	var sell := pk2.find_child("SellButton", true, false) as Button
	check(sell != null and sell.text == "Sell for %d g" % Shop.price_of(good), "the button names the price: " + (sell.text if sell else "-"))
	# a piece they would not buy cannot be sold
	var refuse := {}
	for c in OfferPicker.candidates("pip", req2):
		if str(c["why"]) != "":
			refuse = c
			break
	if not refuse.is_empty():
		pk2.select_uid(int(refuse["item"]["uid"]))
		var sb2 := pk2.find_child("SellButton", true, false) as Button
		check(sb2 != null and sb2.disabled, "a piece they would not buy has a disabled Sell (%s)" % str(refuse["why"]))
		pk2.select_uid(int(good["uid"]))
		sell = pk2.find_child("SellButton", true, false) as Button
	var g0 := Game.gold()
	var purse := int(a["gold"])
	var price := Shop.price_of(good)
	if sell != null:
		sell.pressed.emit()
	check(Game.find_uid(int(good["uid"])).is_empty(), "Sell hands it over")
	eq(int(a["equipment"]["weapon"]["uid"]), int(good["uid"]), "Pip wears the same blade")
	eq(Game.gold() - g0, price, "the smith is paid")
	eq(purse - int(a["gold"]), price, "from Pip's purse")
	_unmount(pk2)
