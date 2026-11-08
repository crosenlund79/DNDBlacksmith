## PawnPanel — Silas Quell's pawnshop: pledge almost anything for ready coin, redeem it within the hold, or buy
## from his shelf (lapsed pledges and the house stock).
## EN: Tabs: Pledge (your stores, with what Quell pays) · Your Tickets (held pledges: redeem price and last day)
##     · The Shelf (for sale) · Ledger (every transaction).
## DA: Pantelånerens butik: pantsæt, indløs, eller køb fra hylden.
class_name PawnPanel
extends UIWindow

var tab := "pledge"
var head: HBoxContainer
var tabs_row: HBoxContainer
var body: VBoxContainer


func _init(args: Dictionary = {}) -> void:
	tab = str(args.get("tab", "pledge"))
	super._init("The Pawnshop", 1500, 900)


func _ready() -> void:
	super._ready()
	head = UIKit.hbox(18)
	content.add_child(head)
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 600))
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	var pc := Commerce.pawn_cfg()
	title_label.text = str(pc.get("shop", "The Pawnshop"))
	UIKit.clear(head)
	var c := DB.character("pawnbroker")
	head.add_child(UIKit.portrait("portraits/pawnbroker", 130))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label("%s — %s" % [c.get("name", "The pawnbroker"), c.get("title", "Pawnbroker")], 26, "heading", UIKit.RUBRIC))
	hv.add_child(UIKit.rich("[i]%s[/i]" % Commerce.greeting("pawnbroker"), 20))
	hv.add_child(UIKit.rich("Pays [b]%d%%[/b] of value · redeem within [b]%d days[/b] for [b]%d%%[/b] · after that it goes on the shelf." % [
		int(round(float(pc.get("payout", 0.4)) * 100)), int(pc.get("hold_days", 10)), int(round(float(pc.get("buyback", 0.65)) * 100))], 20))
	head.add_child(hv)
	head.add_child(UIKit.rich("Purse\n[font_size=30][b]%d g[/b][/font_size]" % Game.gold(), 20))

	UIKit.clear(tabs_row)
	var held := Commerce.pledges().filter(func(p): return p["status"] == "held").size()
	for t in [["pledge", "Pledge"], ["tickets", "Your Tickets" + (" (%d)" % held if held > 0 else "")], ["shelf", "The Shelf"], ["ledger", "Ledger"], ["knowledge", "Old Notes"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; _build(), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	UIKit.clear(body)
	match tab:
		"pledge": _pledge()
		"tickets": _tickets()
		"shelf": _shelf()
		"ledger": _ledger()
		"knowledge": body.add_child(GuideUI.knowledge_box("pawnbroker", _build))


func _pledge() -> void:
	var items := Game.inventory().filter(func(it): return Commerce.pawnable(it) == "")
	if items.is_empty():
		body.add_child(UIKit.label("You have nothing Quell would take a ticket on.", 22, "body_italic"))
		return
	items.sort_custom(func(a, b): return Commerce.unit_value(a) > Commerce.unit_value(b))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	for it in items:
		grid.add_child(_pledge_card(it))
	body.add_child(grid)


func _pledge_card(it: Dictionary) -> Control:
	var uid := int(it["uid"])
	var n := int(it.get("qty", 1))
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(450, 0)
	h.add_child(ItemSlot.new(it, 64))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UIKit.label(Items.display_name(it), 20, "body_bold", Items.color(it, false))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(UIKit.label("worth %d g · redeem %d g" % [Commerce.unit_value(it), Commerce.pawn_buyback(_one(it))], 17, "body"))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.button("Pawn%s — %d g" % [" 1" if n > 1 else "", Commerce.pawn_payout(it, 1)], func(): _do_pawn(uid, 1), 0))
	if n > 1:
		row.add_child(UIKit.button("All %d — %d g" % [n, Commerce.pawn_payout(it, n)], func(): _do_pawn(uid, 0), 0))
	v.add_child(row)
	h.add_child(v)
	return h


func _one(it: Dictionary) -> Dictionary:
	var o := it.duplicate()
	o["qty"] = 1
	return o


func _do_pawn(uid: int, n: int) -> void:
	var err := Commerce.pawn_item(uid, n)
	Events.toast.emit(err if err != "" else "Quell writes out a ticket and counts the coins onto the counter.", "bad" if err != "" else "good")
	_build()


func _tickets() -> void:
	var mine := Commerce.pledges().filter(func(p): return p["status"] == "held")
	if mine.is_empty():
		body.add_child(UIKit.label("You hold no tickets.", 22, "body_italic"))
		return
	for p in mine:
		var pid: String = p["id"]
		var row := UIKit.hbox(14)
		row.add_child(ItemSlot.new(p["item"], 64))
		var left := int(p["due"]) - Game.day()
		var r := UIKit.rich("[b]%s[/b] — ticket %s · pawned on day %d for %d g · redeem for [b]%d g[/b] %s" % [Items.display_name(p["item"]), pid, int(p["day"]), int(p["payout"]), int(p["buyback"]),
			("[color=#7e2418](last day!)[/color]" if left <= 0 else "by day %d (%d day%s left)" % [int(p["due"]), left, "" if left == 1 else "s"])], 20)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(r)
		var b := UIKit.button("Redeem — %d g" % int(p["buyback"]), func():
			var err := Commerce.redeem(pid)
			Events.toast.emit(err if err != "" else "Redeemed.", "bad" if err != "" else "good")
			_build(), 220)
		b.disabled = not Game.can_afford(int(p["buyback"]))
		row.add_child(b)
		body.add_child(row)


func _shelf() -> void:
	var lapsed := Commerce.pledges().filter(func(p): return p["status"] == "forfeit")
	if not lapsed.is_empty():
		body.add_child(UIKit.label("Lapsed pledges (yours, once)", 24, "heading", UIKit.RUBRIC))
		for p in lapsed:
			var pid: String = p["id"]
			var price := Commerce.pledge_price(p)
			var row := UIKit.hbox(14)
			row.add_child(ItemSlot.new(p["item"], 64))
			var r := UIKit.rich("[b]%s[/b] — on the shelf since day %d" % [Items.display_name(p["item"]), int(p.get("forfeit_day", p["due"]))], 20)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(r)
			var b := UIKit.button("Buy back — %d g" % price, func():
				var err := Commerce.redeem(pid)
				Events.toast.emit(err if err != "" else "Bought back.", "bad" if err != "" else "good")
				_build(), 230)
			b.disabled = not Game.can_afford(price)
			row.add_child(b)
			body.add_child(row)
		body.add_child(UIKit.divider())
	body.add_child(UIKit.label("Quell's shelf", 24, "heading", UIKit.RUBRIC))
	var stock := Commerce.house_stock()
	if stock.is_empty():
		body.add_child(UIKit.label("The shelf is bare this week.", 21, "body_italic"))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	for i in stock.size():
		var e: Dictionary = stock[i]
		var idx := i
		var h := UIKit.hbox(10)
		h.custom_minimum_size = Vector2(450, 0)
		h.add_child(ItemSlot.new(e["item"], 64))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Items.display_name(e["item"]), 20, "body_bold"))
		var b := UIKit.button("Buy — %d g" % int(e["price"]), func():
			var err := Commerce.buy_house(idx)
			Events.toast.emit(err if err != "" else "Bought.", "bad" if err != "" else "good")
			_build(), 0)
		b.disabled = not Game.can_afford(int(e["price"]))
		v.add_child(b)
		h.add_child(v)
		grid.add_child(h)
	body.add_child(grid)


func _ledger() -> void:
	var entries := Commerce.pawn_log()
	if entries.is_empty():
		body.add_child(UIKit.label("No dealings with Quell yet.", 22, "body_italic"))
		return
	var lines := []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var amt := int(e["amount"])
		lines.append("Day %d — %s%s" % [int(e["day"]), e["text"], "" if amt == 0 else ("  [color=#26622f]+%d g[/color]" % amt if amt > 0 else "  [color=#7e2418]%d g[/color]" % amt)])
	body.add_child(UIKit.rich("\n".join(lines), 20))
