## OrdersPanel — special commissions: requirements, rewards, deadlines and delivery.
## EN: Living Workshop #54–55: two sections, each with its own word and colour (WhoIsWho) —
##     · Open commissions — orders you accepted: the request card, what in your stores meets it, delivery;
##     · Commission opportunities — adventurers in town who need something forged and have not ordered it yet. They
##       place a commission when you ask ("Ask what they need forged" in conversation, usually at the Tipsy Wyvern);
##       each row says what they need, where they are, and opens their character sheet.
##     Customers waiting at the counter are on the counter (L); visiting adventurers on the roster (J).
##     #47: compact rows (smaller portraits and buttons), the same information.
## DA: Særlige bestillinger og bestillingsmuligheder (eventyrere i byen, der mangler noget smedet).
class_name OrdersPanel
extends UIWindow

var body: VBoxContainer


func _init() -> void:
	super._init("Commissions", 1240, 0)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(UIKit.GAP)
	content.add_child(UIKit.scroll(body, 580))
	Events.orders_changed.connect(_build)
	Events.inventory_changed.connect(_build)
	Events.customers_changed.connect(_build)
	_build()


func _section(title: String, kind: String, n: int) -> void:
	var h := UIKit.hbox(10)
	h.name = "Section_" + kind
	var t := UIKit.heading("%s (%d)" % [title, n])
	h.add_child(t)
	h.add_child(WhoIsWho.chip(kind, true))
	body.add_child(h)


func _build() -> void:
	UIKit.clear(body)
	var orders := Shop.open_orders()
	_section("Open commissions", "commission", orders.size())
	if orders.is_empty():
		body.add_child(UIKit.note("No open commissions. Adventurers place orders when their gear falls behind their ambitions — the opportunities below are the ones in town now."))
	for o in orders:
		var row := UIKit.hbox(12)
		row.add_child(UIKit.portrait("portraits/" + str(o["npc"]), 72))
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.rich("[b]%s[/b] — [color=#7e2418]%s[/color]. More coin for exceeding the minimum." % [
			Talk.npc_name(o["npc"]), Shop.order_terms(o)], UIKit.FS_SMALL))
		v.add_child(CustomerCard.build(Shop.order_request(o)))
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 6)
		h.add_theme_constant_override("v_separation", 4)
		var any := false
		for it in Game.inventory():
			if Items.slot(it) != o["slot"]:
				continue
			var ok := Shop.item_meets(o, it)
			var b := UIKit.small_button("%s (%s %d)" % [Items.display_name(it), o["stat"], Items.stat(it, o["stat"])], func():
				var err := Shop.fulfil(o["id"], int(it["uid"]))
				Events.toast.emit(err if err != "" else "Delivered to %s." % Talk.npc_name(o["npc"]), "bad" if err != "" else "good"), 0)
			b.disabled = not ok
			b.add_theme_color_override("font_color", Items.color(it, false))
			h.add_child(b)
			any = true
		if not any:
			h.add_child(UIKit.note("You have nothing of that kind yet."))
		v.add_child(h)
		row.add_child(v)
		body.add_child(row)
		body.add_child(UIKit.divider())
	# Living Workshop #54–55: the opportunities nobody has asked about yet
	var opp := WhoIsWho.opportunities()
	_section("Commission opportunities", "opportunity", opp.size())
	if opp.is_empty():
		body.add_child(UIKit.note("Nobody in town needs anything forged that they have not already ordered."))
		return
	body.add_child(UIKit.note("They need something forged and will order it if you ask: talk to them (usually at the Tipsy Wyvern) and choose “Ask what they need forged”."))
	var grid := GridContainer.new()
	grid.name = "Opportunities"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for a in opp:
		grid.add_child(_opportunity(a))
	body.add_child(grid)


func _opportunity(a: Dictionary) -> Control:
	var id := str(a["id"])
	var p := PanelContainer.new()
	p.name = "Opp_" + id
	p.add_theme_stylebox_override("panel", UIKit.row_style(true))
	p.custom_minimum_size = Vector2(560, 0)
	var h := UIKit.hbox(10)
	p.add_child(h)
	h.add_child(UIKit.portrait("portraits/" + id, 52))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s · level %d %s" % [a["name"], int(a.get("level", 1)), a.get("cls", "")], UIKit.FS_SMALL, "body_bold"))
	v.add_child(UIKit.label("Needs %s · %s" % [WhoIsWho.need_text(a), WhoIsWho.where_text(a)], UIKit.FS_MIN, "body", WhoIsWho.KINDS["opportunity"]["col"].darkened(0.3)))
	h.add_child(v)
	var b := UIKit.small_button("Character sheet", func(): Events.open_panel.emit("dossier", {"id": id}), 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p
