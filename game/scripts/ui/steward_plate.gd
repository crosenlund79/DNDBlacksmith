## StewardPlate — the steward's compact, non-blocking status plate on the HUD (Milestone S1).
## EN: While the steward runs the forge: how long the smith has been away, the purse now against when he left, what the
##     steward spent today, its last few actions, what holds it up, the matters waiting, and two buttons — the details
##     (the steward panel) and "Take the workshop back" (→ While You Were Away). It never stops the clock. When the mode
##     is off it shrinks to a small envelope chip, shown only while a sealed letter waits unopened.
##     Sits on the right under the minimap; 80 % parchment with the gothic dark heading strip.
## DA: Forvalterens lille statusplade på skærmen: tid væk, pung nu mod før, seneste handlinger, hvad der holder igen,
##     ventende sager; knapperne Detaljer og Tag værkstedet tilbage. Uden tilstand: kun et konvolut-mærke for breve.
class_name StewardPlate
extends VBoxContainer

const W := 430.0

var plate: PanelContainer
var head: Label
var body: RichTextLabel
var chip: Button
var _acc := 0.0
var _sig := ""


func _ready() -> void:
	name = "StewardPlate"
	theme = Assets.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-20 - W, 282)
	size = Vector2(W, 10)
	plate = PanelContainer.new()
	plate.name = "Plate"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.88, 0.77, 0.96)
	sb.border_color = UIKit.INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	plate.add_theme_stylebox_override("panel", sb)
	plate.custom_minimum_size = Vector2(W, 0)
	var v := UIKit.vbox(4)
	# the gothic strip: who has the forge
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color("#2a1c12")
	ss.border_color = UIKit.GILT
	ss.set_border_width_all(1)
	ss.set_corner_radius_all(3)
	ss.content_margin_left = 10
	ss.content_margin_right = 10
	ss.content_margin_top = 3
	ss.content_margin_bottom = 3
	strip.add_theme_stylebox_override("panel", ss)
	head = UIKit.label("THE STEWARD RUNS THE FORGE", 17, "heading", Color("#e8cc84"))
	strip.add_child(head)
	v.add_child(strip)
	body = UIKit.rich("", 17)
	body.name = "StewardStatus"
	body.custom_minimum_size = Vector2(W - 30, 0)
	v.add_child(body)
	var row := UIKit.hbox(8)
	var det := UIKit.button("Details", func(): Events.open_panel.emit("steward", {}), 0)
	det.add_theme_font_size_override("font_size", 17)
	det.custom_minimum_size = Vector2(110, 38)
	row.add_child(det)
	var back := UIKit.button("Take the workshop back", func(): StewardUI.take_back(), 0)
	back.name = "TakeBack"
	back.add_theme_font_size_override("font_size", 17)
	back.custom_minimum_size = Vector2(0, 38)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	v.add_child(row)
	plate.add_child(v)
	add_child(plate)
	# the envelope chip (mode off, sealed letters unopened)
	chip = UIKit.button("", func(): Events.open_panel.emit("sealed_letter", {}), 0)
	chip.name = "LetterChip"
	chip.add_theme_font_size_override("font_size", 18)
	chip.custom_minimum_size = Vector2(0, 40)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	if Assets.has_tex("ui/wax_seal"):
		chip.icon = Assets.get_tex("ui/wax_seal")
		chip.expand_icon = false
		chip.add_theme_constant_override("icon_max_width", 28)
	add_child(chip)
	Events.steward_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		refresh()


func refresh() -> void:
	if Game.state.is_empty():
		visible = false
		return
	var active := Steward.is_active()
	var n_letters := Steward.letters().size()
	plate.visible = active
	chip.visible = not active and n_letters > 0
	visible = plate.visible or chip.visible
	if chip.visible:
		chip.text = " %d sealed letter%s wait%s" % [n_letters, "" if n_letters == 1 else "s", "s" if n_letters == 1 else ""]
		chip.tooltip_text = "Break the seal when you are ready — it leads to the matter itself."
	if not active:
		return
	var s := Steward.status()
	var lg := Steward.recent_log(14)
	var sig := "%d|%d|%d|%d|%d" % [int(s.get("elapsed_minutes", 0)), int(s.get("gold", 0)), lg.size(), int(s.get("deferred", 0)), (s.get("stalls", []) as Array).size()]
	if sig == _sig:
		return
	_sig = sig
	var lines := PackedStringArray()
	var since := int(Steward.st()["since"].get("gold", s.get("gold", 0)))
	var gold := int(s.get("gold", 0))
	lines.append("[b]Away %s[/b] [color=#6e5a40]· since day %d, %s · %d decision%s[/color]" % [StewardUI.elapsed(int(s.get("elapsed_minutes", 0))),
		int(s.get("since_day", 0)), str(s.get("since_time", "")), int(s.get("decisions", 0)), "" if int(s.get("decisions", 0)) == 1 else "s"])
	var col := "#26622f" if gold >= since else "#7e2418"
	lines.append("Purse [b]%d g[/b] [color=%s](%s since you left)[/color] · spent today %d g" % [gold, col, StewardUI.signed(gold - since), int(s.get("spent_today", 0))])
	# the last few things it did (no stalls or notes)
	var acts: Array = []
	for i in range(lg.size() - 1, -1, -1):
		var e: Dictionary = lg[i]
		if str(e.get("kind", "")) in ["stall", "activate"]:
			continue
		acts.append(e)
		if acts.size() >= 3:
			break
	if acts.is_empty():
		lines.append("[i][color=#6e5a40]Looking over the workshop…[/color][/i]")
	for e2 in acts:
		lines.append(StewardUI.log_line(e2).left(150))
	var stalls: Array = s.get("stalls", [])
	if not stalls.is_empty():
		var st0: Dictionary = stalls[0]
		lines.append("[color=#9e3a0c]‼ Held up: %s%s[/color]" % [str(st0.get("text", "")).left(110), (" (+%d more)" % (stalls.size() - 1)) if stalls.size() > 1 else ""])
	var nd := int(s.get("deferred", 0))
	var nl := int(s.get("letters", 0))
	if nd > 0:
		lines.append("[color=#7e2418]✉ %d matter%s left for you%s[/color]" % [nd, "" if nd == 1 else "s", (" · %d sealed" % nl) if nl > 0 else ""])
	body.text = "\n".join(lines)
