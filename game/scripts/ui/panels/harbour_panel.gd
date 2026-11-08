## HarbourPanel — the harbourmaster's booth on the quay.
## EN: Tabs: The Quay (the docked ship and its hold, or when the next one is expected) · Special Imports
##     (order a known material from abroad: deposit now, balance on arrival) · Orders & Deliveries.
## DA: Havnefogedens bod: skibet ved kajen, særlige importordrer og leveringer.
class_name HarbourPanel
extends UIWindow

var tab := "quay"
var qty := 1
var body: VBoxContainer
var tabs_row: HBoxContainer
var head: HBoxContainer


func _init(args := {}) -> void:
	tab = str(args.get("tab", "quay"))
	super._init("Brindlewick Harbour", 1500, 900)


func _ready() -> void:
	super._ready()
	head = UIKit.hbox(18)
	content.add_child(head)
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 560))
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	UIKit.clear(head)
	var hm := DB.character("harbourmaster")
	head.add_child(UIKit.portrait("portraits/harbourmaster", 130))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label("%s — %s" % [hm.get("name", "The harbourmaster"), hm.get("title", "Harbourmaster")], 26, "heading", UIKit.RUBRIC))
	var lines: Array = Trade.cfg().get("harbour", {}).get("lines", [])
	if not lines.is_empty():
		hv.add_child(UIKit.rich("[i]%s[/i]" % lines[Game.day() % lines.size()], 20))
	hv.add_child(UIKit.rich(_status_line(), 21))
	head.add_child(hv)
	head.add_child(UIKit.rich("Purse\n[font_size=30][b]%d g[/b][/font_size]" % Game.gold(), 20))

	UIKit.clear(tabs_row)
	var n_del := Trade.deliveries().size()
	for t in [["quay", "The Quay"], ["imports", "Special Imports"], ["orders", "Orders & Deliveries" + (" (%d waiting)" % n_del if n_del > 0 else "")], ["knowledge", "Lore & Cargo"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; _build(), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(sp)
	tabs_row.add_child(UIKit.label("Quantity:", 20, "body_bold"))
	for q in [1, 2, 5, 10]:
		var qq: int = q
		var qb := UIKit.button("×%d" % q, func(): qty = qq; _build(), 62)
		qb.disabled = qty == q
		tabs_row.add_child(qb)

	UIKit.clear(body)
	match tab:
		"quay": _quay()
		"imports": _imports()
		"orders": _orders()
		"knowledge": body.add_child(GuideUI.knowledge_box("harbourmaster", _build))


func _status_line() -> String:
	var s := Trade.current_ship()
	var out := ""
	if not s.is_empty():
		var left := maxi(0, int(s["leaves"]) - Game.now())
		out = "[b]%s[/b] is moored at the quay — she sails in %s." % [s["name"], _dur(left)]
	else:
		var n := Trade.next_arrival()
		if not n.is_empty():
			out = "[b]%s[/b] (%s) is expected %s." % [n["name"], Trade.ship_type(str(n["type"])).get("label", "a merchant ship").to_lower(), _when(int(n["days"]), int(n["at"]))]
	var d := Trade.deliveries().size()
	if d > 0:
		out += "  [color=#26622f][b]%d deliver%s waiting.[/b][/color]" % [d, "y" if d == 1 else "ies"]
	return out


func _dur(mins: int) -> String:
	if mins >= 1440:
		var dd := int(round(mins / 1440.0))
		return "about %d day%s" % [dd, "" if dd == 1 else "s"]
	return "%d hour%s" % [maxi(1, int(mins / 60.0)), "" if int(mins / 60.0) == 1 else "s"]


func _when(days: int, at: int) -> String:
	if days <= 0:
		return "today around %02d:00" % int((at % 1440) / 60.0)
	if days == 1:
		return "tomorrow"
	return "in about %d days" % days


# ------------------------------------------------------------------ the quay
func _quay() -> void:
	var s := Trade.current_ship()
	if s.is_empty():
		var n := Trade.next_arrival()
		var row := UIKit.hbox(18)
		if not n.is_empty():
			row.add_child(_ship_pic(str(n["type"]), 0.6, 0.45))
			var sd := Trade.ship_type(str(n["type"]))
			var r := UIKit.rich("The quay is empty but for gulls and nets.\n\n[b]%s[/b], %s under %s, is expected %s.\n[i]%s[/i]" % [n["name"], sd.get("label", "a merchant ship").to_lower(), n["captain"], _when(int(n["days"]), int(n["at"])), sd.get("desc", "")], 22)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(r)
		else:
			row.add_child(UIKit.label("No ships are expected.", 22, "body_italic"))
		body.add_child(row)
		return
	var sd2 := Trade.ship_type(str(s["type"]))
	var top := UIKit.hbox(18)
	top.add_child(_ship_pic(str(s["type"]), 0.85, 1.0))
	var info := UIKit.rich("[font_size=28][b]%s[/b][/font_size]\n%s · %s\n[i]%s[/i]\nSails in %s." % [s["name"], sd2.get("label", ""), s["captain"], sd2.get("desc", ""), _dur(maxi(0, int(s["leaves"]) - Game.now()))], 21)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	body.add_child(top)
	body.add_child(UIKit.label("In the hold", 26, "heading", UIKit.RUBRIC))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	var stock: Array = s["stock"]
	for i in stock.size():
		grid.add_child(_ship_card(i, stock[i]))
	if stock.is_empty():
		body.add_child(UIKit.label("The hold is bare — everything has been sold.", 22, "body_italic"))
	body.add_child(grid)


func _ship_pic(type: String, k: float, alpha: float) -> Control:
	var sd := Trade.ship_type(type)
	var t := TextureRect.new()
	t.texture = Assets.get_tex(str(sd.get("sprite", "props/ship_" + type)), Vector2i(512, 192))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(512 * k, 192 * k)
	t.modulate = Color(1, 1, 1, alpha)
	return t


func _ship_card(i: int, e: Dictionary) -> Control:
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(440, 0)
	var have := int(e["qty"])
	var nm := ""
	if e.has("card"):
		nm = "Ironfront card: %s" % str(e["card"]).capitalize()
		h.add_child(UIKit.icon("icons/recipe_scroll", 72))
	else:
		var it: Dictionary = e["item"] if e.has("item") else Items.make(str(e["def"]), {"qty": maxi(1, have), "quality": 80.0})
		nm = DB.item(str(e["def"])).get("name", e["def"])
		h.add_child(ItemSlot.new(it, 72))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(nm, 21, "body_bold"))
	v.add_child(UIKit.label("%d g each · %s" % [int(e["price"]), ("%d aboard" % have) if have > 0 else "sold"], 18, "body", UIKit.INK if have > 0 else UIKit.RUBRIC))
	var n := maxi(1, mini(qty, have))
	var b := UIKit.button("Buy %d — %d g" % [n, int(e["price"]) * n], func():
		var err := Trade.buy_from_ship(i, qty)
		Events.toast.emit(err if err != "" else "Bought %s." % nm, "bad" if err != "" else "good")
		_build(), 190)
	b.disabled = have <= 0 or not Game.can_afford(int(e["price"]) * n)
	v.add_child(b)
	h.add_child(v)
	return h


# ------------------------------------------------------------------ special imports
func _imports() -> void:
	var dep := int(round(float(Trade.cfg().get("harbour", {}).get("deposit", 0.4)) * 100))
	body.add_child(UIKit.rich("Order goods from abroad through the harbourmaster's book: [b]%d%% deposit[/b] now, the balance when the goods are landed. Only things you know of can be asked for — rarer goods take longer." % dep, 21))
	var list := Trade.importables()
	if list.is_empty():
		body.add_child(UIKit.label("You know of nothing worth sending abroad for yet.", 22, "body_italic"))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 10)
	for info in list:
		grid.add_child(_import_card(info))
	body.add_child(grid)


func _import_card(info: Dictionary) -> Control:
	var def_id: String = info["def"]
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(660, 0)
	h.add_child(ItemSlot.new(Items.make(def_id, {"qty": qty, "quality": 80.0}), 64))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var total := int(info["unit"]) * qty
	var deposit := int(ceil(total * float(info["deposit_share"])))
	v.add_child(UIKit.rich("[b]%s[/b] — %d g each · [i]%s[/i] · %d–%d days" % [DB.item(def_id).get("name", def_id), int(info["unit"]), str(info["tier"]), int(info["lead"][0]), int(info["lead"][1])], 20))
	var b := UIKit.button("Order %d — deposit %d g (total %d g)" % [qty, deposit, total], func():
		var err := Trade.place_import(def_id, qty)
		Events.toast.emit(err if err != "" else "Ordered %d × %s." % [qty, DB.item(def_id).get("name", def_id)], "bad" if err != "" else "good")
		_build(), 0)
	b.disabled = not Game.can_afford(deposit)
	v.add_child(b)
	h.add_child(v)
	return h


# ------------------------------------------------------------------ orders & deliveries
func _orders() -> void:
	var open := Trade.imports()
	if open.is_empty():
		body.add_child(UIKit.label("No orders in the harbourmaster's book.", 22, "body_italic"))
	for o in open:
		var oid: String = o["id"]
		var row := UIKit.hbox(14)
		row.add_child(ItemSlot.new(Items.make(str(o["def"]), {"qty": int(o["qty"]), "quality": 80.0}), 64))
		var nm: String = DB.item(str(o["def"])).get("name", o["def"])
		var txt := ""
		if o["status"] == "arrived":
			txt = "[b]%d × %s[/b] — [color=#26622f][b]landed and waiting[/b][/color]. Paid %d g; balance %d g." % [int(o["qty"]), nm, int(o["deposit"]), int(o["balance"])]
		else:
			var days := int(o["due"]) - Game.day()
			txt = "[b]%d × %s[/b] — ordered on day %d, expected %s. Deposit %d g paid; %d g due on arrival." % [int(o["qty"]), nm, int(o["placed"]), "tomorrow" if days == 1 else ("any day now" if days <= 0 else "in about %d days" % days), int(o["deposit"]), int(o["balance"])]
		var r := UIKit.rich(txt, 20)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(r)
		if o["status"] == "arrived":
			var b := UIKit.button("Pay %d g & collect" % int(o["balance"]), func():
				var err := Trade.collect_delivery(oid)
				if err != "":
					Events.toast.emit(err, "bad")
				_build(), 260)
			b.disabled = not Game.can_afford(int(o["balance"]))
			row.add_child(b)
		body.add_child(row)
	var hist: Array = Trade.st()["history"]
	if not hist.is_empty():
		body.add_child(UIKit.divider())
		body.add_child(UIKit.label("Collected", 24, "heading", UIKit.RUBRIC))
		var lines := []
		for i in range(hist.size() - 1, maxi(-1, hist.size() - 7), -1):
			var o: Dictionary = hist[i]
			lines.append("Day %d — %d × %s (%d g)" % [int(o.get("collected", 0)), int(o["qty"]), DB.item(str(o["def"])).get("name", o["def"]), int(o["total"])])
		body.add_child(UIKit.rich("\n".join(lines), 19))
