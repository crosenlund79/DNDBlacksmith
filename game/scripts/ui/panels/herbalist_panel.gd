## HerbalistPanel — Maud Fennimore's counter: today's herbs, salts and reagents with prices.
## EN: Stock refreshes every morning (Trade.herbalist_stock); pick a quantity (×1 / ×5 / ×10) and buy.
## DA: Urtekonens disk: dagens urter og reagenser; vælg antal og køb.
class_name HerbalistPanel
extends UIWindow

var qty := 1
var body: VBoxContainer
var side: VBoxContainer
var npc_id := "herbalist"


func _init(_args := {}) -> void:
	super._init("The Herbalist", 1240, 760)


func _ready() -> void:
	super._ready()
	var row := UIKit.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	side = UIKit.vbox(10)
	side.custom_minimum_size = Vector2(300, 0)
	row.add_child(side)
	body = UIKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	var c := DB.character(npc_id)
	title_label.text = Trade.cfg().get("herbalist", {}).get("shop", "The Herbalist")
	UIKit.clear(side)
	side.add_child(UIKit.portrait("portraits/" + npc_id, 260))
	side.add_child(UIKit.label(c.get("name", "The herbalist"), 28, "heading", UIKit.RUBRIC))
	side.add_child(UIKit.label(c.get("title", "Herbalist"), 20, "body_italic"))
	var line := UIKit.rich("[i]%s[/i]" % Trade.herbalist_line(), 20)
	line.custom_minimum_size = Vector2(290, 0)
	side.add_child(line)
	side.add_child(UIKit.divider())
	side.add_child(UIKit.rich("Your purse: [b]%d g[/b]" % Game.gold(), 22))
	side.add_child(UIKit.label("Fresh stock every morning.", 18, "body_italic"))
	if npc_id == "herbalist":   # UX iteration (GUIDE): Maud sells herb lore — Knowledge
		side.add_child(UIKit.button("Ask about herb lore…", func(): UIKit.clear(body); body.add_child(GuideUI.knowledge_box("herbalist", _build)), 0))

	UIKit.clear(body)
	var qrow := UIKit.hbox(8)
	qrow.add_child(UIKit.label("Buy quantity:", 22, "body_bold"))
	for q in [1, 5, 10]:
		var qq: int = q
		var b := UIKit.button("×%d" % q, func(): qty = qq; _build(), 70)
		b.disabled = qty == q
		qrow.add_child(b)
	body.add_child(qrow)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	for e in Trade.herbalist_stock():
		grid.add_child(_card(e))
	body.add_child(UIKit.scroll(grid, 560))


func _card(e: Dictionary) -> Control:
	var def_id: String = e["def"]
	var d := DB.item(def_id)
	var h := UIKit.hbox(12)
	h.custom_minimum_size = Vector2(420, 0)
	var have := int(e["qty"])
	var it := Items.make(def_id, {"qty": maxi(1, have), "quality": 80.0})
	h.add_child(ItemSlot.new(it, 72))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(d.get("name", def_id), 22, "body_bold"))
	v.add_child(UIKit.label("%d g each · %s" % [int(e["price"]), ("%d left" % have) if have > 0 else "sold out"], 18, "body", UIKit.INK if have > 0 else UIKit.RUBRIC))
	var n := mini(qty, have)
	var b := UIKit.button("Buy %d — %d g" % [maxi(n, 1), int(e["price"]) * maxi(n, 1)], func():
		var err := Trade.buy_herbalist(def_id, qty)
		Events.toast.emit(err if err != "" else "Bought %s." % d.get("name", def_id), "bad" if err != "" else "good")
		_build(), 200)
	b.disabled = have <= 0 or not Game.can_afford(int(e["price"]) * maxi(n, 1))
	v.add_child(b)
	h.add_child(v)
	return h
