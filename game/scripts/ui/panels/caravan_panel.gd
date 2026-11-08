## CaravanPanel — the Brask caravan at the caravan camp: its wagons (curios, exotic goods, fine arms, sometimes an
## Ironfront special) and the "goods wanted" list it pays a premium for.
## EN: When the caravan is away, the panel says when it is expected back.
## DA: Karavanens vogne: kuriositeter, eksotiske varer og udstyr — og varer, den betaler ekstra for.
class_name CaravanPanel
extends UIWindow

var tab := "wagons"
var qty := 1
var head: HBoxContainer
var tabs_row: HBoxContainer
var body: VBoxContainer


func _init(args: Dictionary = {}) -> void:
	tab = str(args.get("tab", "wagons"))
	super._init("The Travelling Caravan", 1500, 900)


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
	var cc: Dictionary = Commerce.cfg().get("caravan", {})
	title_label.text = str(cc.get("label", "The Travelling Caravan"))
	UIKit.clear(head)
	var m := DB.character("caravan_master")
	head.add_child(UIKit.portrait("portraits/caravan_master", 130))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label("%s — %s" % [m.get("name", "The caravan master"), m.get("title", "Caravan Master")], 26, "heading", UIKit.RUBRIC))
	hv.add_child(UIKit.rich("[i]%s[/i]" % Commerce.greeting("caravan_master"), 20))
	hv.add_child(UIKit.rich(_status(), 21))
	head.add_child(hv)
	head.add_child(UIKit.rich("Purse\n[font_size=30][b]%d g[/b][/font_size]" % Game.gold(), 20))

	UIKit.clear(tabs_row)
	UIKit.clear(body)
	if not Commerce.caravan_present():
		body.add_child(UIKit.rich("The caravan camp is empty: wheel-ruts, a cold fire-ring, a tassel caught on a thorn.\n\n[i]%s[/i]" % cc.get("desc", ""), 22))
		return
	for t in [["wagons", "The Wagons"], ["wanted", "Goods Wanted"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; _build(), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(sp)
	if tab == "wagons":
		tabs_row.add_child(UIKit.label("Quantity:", 20, "body_bold"))
		for q in [1, 2, 5]:
			var qq: int = q
			var qb := UIKit.button("×%d" % q, func(): qty = qq; _build(), 62)
			qb.disabled = qty == q
			tabs_row.add_child(qb)
		_wagons()
	else:
		_wanted()


func _status() -> String:
	var cv := Commerce.caravan()
	if not cv.is_empty():
		var left := maxi(0, int(cv["leaves"]) - Game.now())
		return "The wagons are drawn up at the caravan camp — they leave in %s." % _dur(left)
	var n := Commerce.next_caravan()
	if n.is_empty():
		return "Nobody knows when the caravan will come again."
	var d := int(n["days"])
	return "The caravan is expected %s." % ("today" if d <= 0 else ("tomorrow" if d == 1 else "in about %d days" % d))


func _dur(mins: int) -> String:
	if mins >= 1440:
		var dd := int(round(mins / 1440.0))
		return "about %d day%s" % [dd, "" if dd == 1 else "s"]
	return "%d hour%s" % [maxi(1, int(mins / 60.0)), "" if int(mins / 60.0) == 1 else "s"]


func _wagons() -> void:
	var stock: Array = Commerce.caravan()["stock"]
	var groups := [["Curiosities", func(e): return str(e.get("kind", "")) == "curiosities"],
		["Arms & Armour", func(e): return str(e.get("kind", "")) == "equipment"],
		["Exotic Goods", func(e): return not e.has("kind") and not e.has("card")],
		["Ironfront Specials", func(e): return e.has("card")]]
	for g in groups:
		var f: Callable = g[1]
		var idx := []
		for i in stock.size():
			if f.call(stock[i]):
				idx.append(i)
		if idx.is_empty():
			continue
		body.add_child(UIKit.label(str(g[0]), 26, "heading", UIKit.RUBRIC))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 12)
		for i: int in idx:
			grid.add_child(_card(i, stock[i]))
		body.add_child(grid)


func _card(i: int, e: Dictionary) -> Control:
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(450, 0)
	var have := int(e["qty"])
	var nm := ""
	if e.has("card"):
		var cd: Variant = Commerce._ironfront_call("card", [str(e["card"])])
		nm = "Ironfront card: %s" % (str((cd as Dictionary).get("name", str(e["card"]).capitalize())) if cd is Dictionary else str(e["card"]).capitalize())
		h.add_child(UIKit.icon("icons/recipe_scroll", 72))
	else:
		var it: Dictionary = e["item"] if e.has("item") else Items.make(str(e["def"]), {"qty": maxi(1, have), "quality": 80.0})
		nm = str(it.get("name", e["def"])) if e.has("item") else str(DB.item(str(e["def"])).get("name", e["def"]))
		h.add_child(ItemSlot.new(it, 72))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UIKit.label(nm, 21, "body_bold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(UIKit.label("%d g each · %s" % [int(e["price"]), ("%d in the wagon" % have) if have > 0 else "sold"], 18, "body", UIKit.INK if have > 0 else UIKit.RUBRIC))
	var n := maxi(1, mini(qty, have))
	var b := UIKit.button("Buy %d — %d g" % [n, int(e["price"]) * n], func():
		var err := Commerce.buy_caravan(i, qty)
		Events.toast.emit(err if err != "" else "Bought %s." % nm, "bad" if err != "" else "good")
		_build(), 190)
	b.disabled = have <= 0 or not Game.can_afford(int(e["price"]) * n)
	v.add_child(b)
	h.add_child(v)
	return h


func _wanted() -> void:
	body.add_child(UIKit.rich("The caravan buys these at a premium — good steel travels further than gold. They take only so many of each.", 21))
	for w in Commerce.caravan().get("wanted", []):
		var def_id: String = w["def"]
		var row := UIKit.hbox(14)
		row.add_child(ItemSlot.new(Items.make(def_id, {"quality": 80.0}), 64))
		var left := int(w["max"]) - int(w["taken"])
		var info := UIKit.rich("[b]%s[/b] — pays about [b]%d%%[/b] of its worth · wants %d more" % [DB.item(def_id).get("name", def_id), int(round(float(w["mult"]) * 100)), left], 21)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		body.add_child(row)
		var mine := Game.inventory().filter(func(it): return str(it["def"]) == def_id)
		if mine.is_empty():
			body.add_child(UIKit.label("     You have none in your stores.", 19, "body_italic"))
			continue
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		for it in mine:
			var uid := int(it["uid"])
			var offer := Commerce.wanted_offer(uid)
			var hb := UIKit.hbox(6)
			hb.add_child(ItemSlot.new(it, 56))
			var b := UIKit.button("Sell 1 — %d g" % offer, func():
				var err := Commerce.sell_wanted(uid, 1)
				Events.toast.emit(err if err != "" else "Sold to the caravan.", "bad" if err != "" else "good")
				_build(), 0)
			b.disabled = offer <= 0
			hb.add_child(b)
			flow.add_child(hb)
		body.add_child(flow)
		body.add_child(UIKit.divider())
