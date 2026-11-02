## OrdersPanel — special commissions: requirements, rewards, deadlines and delivery.
## DA: Særlige bestillinger: krav, belønning, frister og levering.
class_name OrdersPanel
extends UIWindow

var body: VBoxContainer


func _init() -> void:
	super._init("Commissions", 1240, 760)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 620))
	Events.orders_changed.connect(_build)
	Events.inventory_changed.connect(_build)
	_build()


func _build() -> void:
	UIKit.clear(body)
	var orders := Shop.open_orders()
	if orders.is_empty():
		body.add_child(UIKit.label("No open commissions. Adventurers place orders when their gear falls behind their ambitions — talk to them at the inn.", 22, "body_italic"))
	for o in orders:
		var row := UIKit.hbox(16)
		row.add_child(UIKit.portrait("portraits/" + str(o["npc"]), 110))
		var v := UIKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.rich("[b]%s[/b] needs a [b]%s[/b] with [b]%s ≥ %d[/b]. Reward %d g (more for exceeding it). Due by day %d.\n[i]%s[/i]" % [
			Talk.npc_name(o["npc"]), o["slot"], o["stat"], o["min"], o["reward"], o["deadline"], o.get("note", "")], 21))
		var h := UIKit.hbox(8)
		var any := false
		for it in Game.inventory():
			if Items.slot(it) != o["slot"]:
				continue
			var ok := Shop.item_meets(o, it)
			var b := UIKit.button("%s (%s %d)" % [Items.display_name(it), o["stat"], Items.stat(it, o["stat"])], func():
				var err := Shop.fulfil(o["id"], int(it["uid"]))
				Events.toast.emit(err if err != "" else "Delivered to %s." % Talk.npc_name(o["npc"]), "bad" if err != "" else "good"), 0)
			b.disabled = not ok
			b.add_theme_color_override("font_color", Items.color(it, false))
			h.add_child(b)
			any = true
		if not any:
			h.add_child(UIKit.label("You have nothing of that kind yet.", 20, "body_italic"))
		v.add_child(h)
		row.add_child(v)
		body.add_child(row)
		body.add_child(UIKit.divider())
