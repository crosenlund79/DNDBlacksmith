## RivalSmithPanel — Maren Tallowgate's Salt Anvil: sea-bronze and ripple-steel work the smith cannot make yet,
## priced high, plus the odd specialist material. A side column shows her, a rivalry line and who bought from her.
## DA: Den rivaliserende smeds butik: specialudstyr og -materialer til høje priser.
class_name RivalSmithPanel
extends UIWindow

var side: VBoxContainer
var body: VBoxContainer
var line := ""


func _init(args: Dictionary = {}) -> void:
	super._init("The Salt Anvil", 1500, 880)


func _ready() -> void:
	super._ready()
	var row := UIKit.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	side = UIKit.vbox(10)
	side.custom_minimum_size = Vector2(320, 0)
	row.add_child(side)
	body = UIKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UIKit.scroll(body, 700))
	(body.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line = Commerce.greeting("rival_smith")
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	var c := DB.character("rival_smith")
	title_label.text = str(Commerce.rival_cfg().get("shop", "The Salt Anvil"))
	UIKit.clear(side)
	side.add_child(UIKit.portrait("portraits/rival_smith", 260))
	side.add_child(UIKit.label(c.get("name", "The rival smith"), 28, "heading", UIKit.RUBRIC))
	side.add_child(UIKit.label(c.get("title", "Smith"), 20, "body_italic"))
	var l := UIKit.rich("[i]%s[/i]" % line, 20)
	l.custom_minimum_size = Vector2(310, 0)
	side.add_child(l)
	side.add_child(UIKit.divider())
	var band := Commerce.rivalry_band()
	side.add_child(UIKit.rich("Rivalry: [b]%s[/b]" % {"low": "she thinks you a beginner", "mid": "she keeps an eye on you", "high": "she calls you her equal (grudgingly)"}.get(band, band), 19))
	var sales := Commerce.rival_sales()
	if not sales.is_empty():
		var s: Dictionary = sales[-1]
		side.add_child(UIKit.rich("[i]Lately sold: %s to %s (day %d).[/i]" % [s["item"], Talk.npc_name(str(s["adv"])), int(s["day"])], 18))
	side.add_child(UIKit.rich("Your purse: [b]%d g[/b]" % Game.gold(), 22))
	side.add_child(UIKit.button("Talk to her", func():
		close()
		Events.open_panel.emit.call_deferred("dialogue", {"npc": "rival_smith", "area": "village"}), 0))

	UIKit.clear(body)
	var stock := Commerce.rival_stock()
	var eq := []
	var mats := []
	for i in stock.size():
		if Items.is_equipment({"def": str(stock[i]["def"])}):
			eq.append(i)
		else:
			mats.append(i)
	body.add_child(UIKit.label("From the Salt Anvil", 26, "heading", UIKit.RUBRIC))
	body.add_child(UIKit.rich("[i]Sea-bronze does not rust; ripple-steel shows water in the blade. Fresh work every few days.[/i]", 19))
	body.add_child(_grid(eq, stock))
	if not mats.is_empty():
		body.add_child(UIKit.label("Specialist materials", 26, "heading", UIKit.RUBRIC))
		body.add_child(_grid(mats, stock))


func _grid(idx: Array, stock: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	for i: int in idx:
		grid.add_child(_card(i, stock[i]))
	return grid


func _card(i: int, e: Dictionary) -> Control:
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(520, 0)
	var have := int(e["qty"])
	var it: Dictionary = e["item"] if e.has("item") else Items.make(str(e["def"]), {"qty": maxi(1, have), "quality": 85.0})
	h.add_child(ItemSlot.new(it, 76))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := str(it.get("name", e["def"])) if e.has("item") else str(DB.item(str(e["def"])).get("name", e["def"]))
	v.add_child(UIKit.label(nm, 21, "body_bold", Items.color(it, false)))
	var stats := []
	for k in ["attack", "protection", "ward", "magic", "speed"]:
		var val := Items.stat(it, k)
		if val != 0:
			stats.append("%s %d" % [k.capitalize(), val])
	if not stats.is_empty() and e.has("item"):
		v.add_child(UIKit.label(" · ".join(stats), 17, "body"))
	v.add_child(UIKit.label("%d g%s · %s" % [int(e["price"]), "" if e.has("item") else " each", ("%d left" % have) if have > 0 else "sold"], 18, "body", UIKit.INK if have > 0 else UIKit.RUBRIC))
	var b := UIKit.button("Buy — %d g" % int(e["price"]), func():
		var err := Commerce.buy_rival(i, 1)
		if err == "":
			line = "\"Treat it kindly. And if anyone asks — you bought it from the better smith.\""
		Events.toast.emit(err if err != "" else "Bought %s." % nm, "bad" if err != "" else "good")
		_build(), 200)
	b.disabled = have <= 0 or not Game.can_afford(int(e["price"]))
	v.add_child(b)
	h.add_child(v)
	return h
