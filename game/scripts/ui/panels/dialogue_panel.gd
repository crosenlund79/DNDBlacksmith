## DialoguePanel — portrait, words and choices; consequences are applied by Talk.
## DA: Portræt, replikker og valg; konsekvenserne udføres af Talk.
class_name DialoguePanel
extends UIWindow

var npc := ""
var area := ""
var text: RichTextLabel
var opts: VBoxContainer


func _init(id: String, a: String) -> void:
	npc = id
	area = a
	super._init(Talk.npc_name(id), 1160, 560)


func _ready() -> void:
	super._ready()
	var c := DB.character(npc)
	var sub := str(c.get("title", c.get("cls", "")))
	if sub != "":
		title_label.text += "  ·  " + sub
	var h := UIKit.hbox(20)
	var pid := "portraits/" + npc
	var hl := Hire.get_h(npc)
	if not hl.is_empty():
		pid = "portraits/" + str(hl["look"])
	h.add_child(UIKit.portrait(pid, 220))
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = UIKit.rich("", 24)
	v.add_child(text)
	opts = UIKit.vbox(6)
	v.add_child(opts)
	h.add_child(v)
	content.add_child(h)
	text.text = Talk.greeting(npc)
	_options()


func _options() -> void:
	UIKit.clear(opts)
	for o in Talk.options(npc, area):
		var oid: String = o["id"]
		var b := UIKit.button("❧ " + o["label"], func(): _choose(oid), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		opts.add_child(b)


func _choose(oid: String) -> void:
	if oid == "bye":
		close()
		return
	var r := Talk.choose(npc, oid, area)
	var action: String = r.get("action", "")
	if action == "close":
		close()
		return
	if action != "":
		var who := npc
		match action:
			"hirelings": Events.open_panel.emit("hirelings", {})
			"shop": Events.open_panel.emit("shop", {"npc": who})
			"repair":
				var c := Crafting.check_params("grinding_wheel")
				Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Repair at the grinding wheel",
					"on_done": func(qs: Array):
						Shop.do_repair(who, float(qs[0]))
						Events.toast.emit("Repair finished (%d%%)." % int(qs[0]), "good")
						close()})
		return
	if r.has("fade"):
		Events.request_fade.emit(r["fade"], int(r.get("minutes", 60)))
	text.text = r.get("text", "")
	_options()
