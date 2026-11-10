## TutorialCard — the small HUD card showing the current tutorial step (see Tutorial).
## DA: Det lille HUD-kort med det aktuelle vejledningstrin.
class_name TutorialCard
extends PanelContainer

var step_label: Label
var title: Label
var body: RichTextLabel
## A2: the selling step's live status (who is waiting / on the way / nobody yet), refreshed with the card.
var status: RichTextLabel
var _shown_id := "-"
var _status_text := ""


func _init() -> void:
	theme = Assets.theme
	add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	custom_minimum_size = Vector2(430, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := UIKit.vbox(4)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon("ui/tb_help", 34))
	step_label = UIKit.label("", 16, "heading_italic", UIKit.RUBRIC)
	step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(step_label)
	v.add_child(head)
	title = UIKit.label("", 24, "heading")
	v.add_child(title)
	body = UIKit.rich("", 18)
	body.custom_minimum_size = Vector2(380, 0)
	v.add_child(body)
	status = UIKit.rich("", 17)
	status.name = "TutorialStatus"
	status.custom_minimum_size = Vector2(380, 0)
	status.visible = false
	v.add_child(status)
	var row := UIKit.hbox(8)
	var skip := UIKit.button("Skip step", func(): Tutorial.skip_step(); refresh(), 0)
	skip.custom_minimum_size = Vector2(0, 34)
	skip.add_theme_font_size_override("font_size", 16)
	row.add_child(skip)
	var hide_b := UIKit.button("Hide tutorial", func():
		Tutorial.set_enabled(false)
		Events.toast.emit("Tutorial hidden — restart it any time from Help (F1).", "info")
		refresh(), 0)
	hide_b.custom_minimum_size = Vector2(0, 34)
	hide_b.add_theme_font_size_override("font_size", 16)
	row.add_child(hide_b)
	v.add_child(row)
	add_child(v)
	visible = false


func refresh() -> void:
	var c := Tutorial.current()
	visible = not c.is_empty()
	if c.is_empty():
		return
	_refresh_status(str(c["id"]))
	if str(c["id"]) == _shown_id:
		return
	_shown_id = str(c["id"])
	step_label.text = "Tutorial · step %d of %d" % [Tutorial.index_of(_shown_id) + 1, Tutorial.STEPS.size()]
	title.text = str(c["title"])
	body.text = str(c["text"])
	reset_size()
	# a little flourish when a new step appears
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


## The live line under the "Serve a customer" step: a seated customer (act now), one on the way, or nobody yet.
func _refresh_status(id: String) -> void:
	var st := Tutorial.customer_status() if id == "customer" else {}
	var t := ""
	if not st.is_empty():
		var ok := str(st["state"]) == "ready"
		t = "[color=%s]%s %s[/color]" % ["#26622f" if ok else "#5e421c", "✓" if ok else "◷", str(st["text"])]
	if t == _status_text:
		return
	_status_text = t
	status.text = t
	status.visible = t != ""
	reset_size()
