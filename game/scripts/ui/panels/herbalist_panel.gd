## HerbalistPanel — a village shop counter: Maud Fennimore's herbs or Aldric Pell's everyday materials.
## EN: Shared purchasing screen for the counters that restock every morning (Trade.STORES): args {"id": store id}
##     ("herbalist" default, "general_store" for Pell's Provisions). Shows the keeper, today's line, your purse,
##     the opening hours (Venues) and today's stock; pick a quantity (×1 / ×5 / ×10) and buy. Each card says how
##     many you already hold, so the smith sees at once whether the purchase is needed.
## DA: Fælles butiksdisk (urtekonen, købmanden): dagens varer, åbningstid, antal og køb.
class_name HerbalistPanel
extends UIWindow

var qty := 1
## S2 (OBS-16): optional "only what I can buy now" filter (off by default; sold-out and unaffordable cards stay visible,
## greyed, until the smith asks to hide them). Remembered for the session.
static var only_affordable := false
var body: VBoxContainer
var side: VBoxContainer
var store_id := "herbalist"
var npc_id := "herbalist"


func _init(args := {}) -> void:
	store_id = str(args.get("id", "herbalist"))
	if Trade.store_cfg(store_id).is_empty():
		store_id = "herbalist"
	npc_id = str(Trade.store_cfg(store_id).get("keeper", "herbalist" if store_id == "herbalist" else ""))
	super._init(Trade.store_name(store_id), 1240, 760)


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
	title_label.text = Trade.store_name(store_id)
	UIKit.clear(side)
	side.add_child(UIKit.portrait("portraits/" + npc_id, 260))
	side.add_child(UIKit.label(c.get("name", "The keeper"), 28, "heading", UIKit.RUBRIC))
	side.add_child(UIKit.label(c.get("title", Venues.get_v(store_id).get("type", "Shopkeeper")), 20, "body_italic"))
	var line := UIKit.rich("[i]%s[/i]" % Trade.store_line(store_id), 20)
	line.custom_minimum_size = Vector2(290, 0)
	side.add_child(line)
	side.add_child(UIKit.divider())
	side.add_child(UIKit.rich("Your purse: [b]%d g[/b]" % Game.gold(), 22))
	var hrs := Venues.hours_text(store_id) if not Venues.get_v(store_id).is_empty() else ""
	side.add_child(UIKit.label("Fresh stock every morning." + ((" Open %s." % hrs) if hrs != "" else ""), 18, "body_italic"))
	if store_id == "herbalist":   # UX iteration (GUIDE): Maud sells herb lore — Knowledge
		side.add_child(UIKit.button("Ask about herb lore…", func(): UIKit.clear(body); body.add_child(GuideUI.knowledge_box("herbalist", _build)), 0))

	UIKit.clear(body)
	var qrow := UIKit.hbox(8)
	qrow.add_child(UIKit.label("Buy quantity:", 22, "body_bold"))
	for q in [1, 5, 10]:
		var qq: int = q
		var b := UIKit.button("×%d" % q, func(): qty = qq; _build(), 70)
		b.disabled = qty == q
		qrow.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(sp)
	var cb := CheckBox.new()
	cb.name = "OnlyAffordable"
	cb.text = "Only what I can buy now"
	cb.button_pressed = only_affordable
	cb.tooltip_text = "Hide sold-out goods and what your purse cannot cover at this quantity."
	cb.add_theme_font_override("font", Assets.font("body"))
	cb.add_theme_font_size_override("font_size", 18)
	cb.add_theme_color_override("font_color", UIKit.INK)
	cb.add_theme_color_override("font_pressed_color", UIKit.INK)
	cb.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
	cb.toggled.connect(func(on: bool): only_affordable = on; _build())
	qrow.add_child(cb)
	body.add_child(qrow)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.name = "StockGrid"
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	var hidden := 0
	for e in Trade.store_stock(store_id):
		if only_affordable and buy_blocker(e, qty) != "":
			hidden += 1
			continue
		grid.add_child(_card(e))
	if hidden > 0:
		body.add_child(UIKit.label("%d item%s hidden — sold out or beyond your purse (untick to see them)." % [hidden, "" if hidden == 1 else "s"], 17, "body_italic", Color("#5e421c")))
	body.add_child(UIKit.scroll(grid, 560))


## Why a stock line cannot be bought now at quantity `q` ("" = it can): sold out, or the purse is short.
static func buy_blocker(e: Dictionary, q: int) -> String:
	var have := int(e["qty"])
	if have <= 0:
		return "sold out"
	if not Game.can_afford(int(e["price"]) * maxi(mini(q, have), 1)):
		return "you cannot afford it"
	return ""


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
	v.add_child(UIKit.label("%d g each · %s · you hold %d" % [int(e["price"]), ("%d left" % have) if have > 0 else "sold out", Game.count(def_id)],
		18, "body", UIKit.INK if have > 0 else UIKit.RUBRIC))
	var n := mini(qty, have)
	var b := UIKit.button("Buy %d — %d g" % [maxi(n, 1), int(e["price"]) * maxi(n, 1)], func():
		var err := Trade.buy_store(store_id, def_id, qty)
		Events.toast.emit(err if err != "" else "Bought %s." % d.get("name", def_id), "bad" if err != "" else "good")
		_build(), 200)
	b.disabled = have <= 0 or not Game.can_afford(int(e["price"]) * maxi(n, 1))
	if have > 0 and b.disabled:
		b.tooltip_text = "You cannot afford it."
	v.add_child(b)
	if have > 0 and b.disabled:   # S2: the reason shown, not only in a tooltip
		v.add_child(UIKit.label("Your purse holds %d g." % Game.gold(), 16, "body_italic", UIKit.RUBRIC))
	h.add_child(v)
	return h
