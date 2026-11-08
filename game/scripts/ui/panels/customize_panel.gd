## CustomizePanel — the mirror: choose Brannoc's hair, beard, colours and a few small extras.
## EN: A live preview shows the miniature turning on its base (south, east, north, west) and the portrait.
##     Every change applies at once (Appearance.set_look) — the world figure and every portrait follow.
##     Opened from the pause menu ("Appearance") and from the mirror in the quarters (interactable "customize").
## DA: Spejlet: vælg hår, skæg, farver og småting. Forhåndsvisningen viser figuren dreje og portrættet;
##     ændringer gælder med det samme.
class_name CustomizePanel
extends UIWindow

const FACINGS := ["S", "E", "N", "W"]

var look: Dictionary
var mini_rect: TextureRect
var portrait_rect: TextureRect
var facing_label: Label
var rows: VBoxContainer
var _sheet: Texture2D
var _facing := 0
var _frame := 0
var _t := 0.0
var _turn_t := 0.0
var spin := true


func _init() -> void:
	super._init("Your Appearance", 1240, 780)


func _ready() -> void:
	super._ready()
	look = Appearance.look()
	var h := UIKit.hbox(26)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(h)
	# ---- preview: the miniature on a little display plinth + the portrait
	var left := UIKit.vbox(10)
	left.custom_minimum_size = Vector2(420, 0)
	h.add_child(left)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	stage.custom_minimum_size = Vector2(420, 330)
	left.add_child(stage)
	var sv := UIKit.vbox(0)
	stage.add_child(sv)
	mini_rect = TextureRect.new()
	mini_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mini_rect.custom_minimum_size = Vector2(400, 290)
	sv.add_child(mini_rect)
	var turn := UIKit.hbox(8)
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	turn.add_child(UIKit.button("◀", func(): _turn(-1), 50))
	facing_label = UIKit.label("", 20, "heading_italic", UIKit.PAPER)
	facing_label.custom_minimum_size = Vector2(150, 0)
	facing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn.add_child(facing_label)
	turn.add_child(UIKit.button("▶", func(): _turn(1), 50))
	sv.add_child(turn)
	var prow := UIKit.hbox(12)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_rect = UIKit.portrait("portraits/player", 250)
	prow.add_child(portrait_rect)
	left.add_child(prow)
	# ---- options
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(UIKit.label("A blacksmith is known by his work. Still — a man may choose his beard.", 20, "body_italic"))
	rows = UIKit.vbox(8)
	right.add_child(rows)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var b := UIKit.hbox(12)
	b.add_child(UIKit.button("Brannoc's own look", func():
		Audio.play("sfx/ui_click")
		_apply(Appearance.default_look()), 280))
	var done := UIKit.button("Done", close, 200)
	b.add_child(done)
	right.add_child(b)
	_build_rows()
	_refresh_preview()


func _build_rows() -> void:
	UIKit.clear(rows)
	_stepper("Hair", "hair")
	_swatches("Hair colour", "hair_col")
	_stepper("Beard", "beard")
	_swatches("Beard colour", "beard_col")
	_swatches("Skin", "skin")
	_swatches("Shirt", "shirt")
	_swatches("Apron", "apron")
	var r := _row("Extras")
	for o in Appearance.options("extras"):
		var id := str(o["id"])
		var on: bool = (look["extras"] as Array).has(id)
		var bt := UIKit.button(("✓ " if on else "") + str(o["name"]), func():
			Audio.play("sfx/ui_toggle")
			_apply(Appearance.toggle_extra(look, id)), 150)
		if on:
			bt.add_theme_color_override("font_color", UIKit.RUBRIC)
		r.add_child(bt)


func _row(title: String) -> HBoxContainer:
	var r := UIKit.hbox(8)
	var l := UIKit.label(title, 22, "body_bold")
	l.custom_minimum_size = Vector2(160, 0)
	r.add_child(l)
	rows.add_child(r)
	return r


func _stepper(title: String, axis: String) -> void:
	var r := _row(title)
	r.add_child(UIKit.button("◀", func():
		Audio.play("sfx/ui_click")
		_apply(Appearance.cycle(look, axis, -1)), 50))
	var nm := UIKit.label(Appearance.option_name(axis, str(look[axis])), 22, "heading")
	nm.custom_minimum_size = Vector2(190, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(nm)
	r.add_child(UIKit.button("▶", func():
		Audio.play("sfx/ui_click")
		_apply(Appearance.cycle(look, axis, 1)), 50))


func _swatches(title: String, axis: String) -> void:
	var r := _row(title)
	for o in Appearance.options(axis):
		var id := str(o["id"])
		var sel := str(look[axis]) == id
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(44, 40)
		bt.tooltip_text = str(o["name"])
		var col := Color(str(o["tones"][1]))
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.lightened(0.12) if st == "hover" else col
			sb.set_corner_radius_all(20)
			sb.set_border_width_all(4 if sel else 2)
			sb.border_color = UIKit.RUBRIC if sel else (UIKit.GILT if st == "hover" else UIKit.INK)
			bt.add_theme_stylebox_override(st, sb)
		bt.pressed.connect(func():
			Audio.play("sfx/ui_chip")
			var l := look.duplicate(true)
			l[axis] = id
			_apply(l))
		r.add_child(bt)
	var n := UIKit.label(Appearance.option_name(axis, str(look[axis])), 18, "body_italic")
	n.custom_minimum_size = Vector2(120, 0)
	r.add_child(n)


func _apply(l: Dictionary) -> void:
	look = Appearance.normalise(l)
	Appearance.set_look(look)
	_build_rows()
	_refresh_preview()


func _refresh_preview() -> void:
	_sheet = Appearance.tex_for("mini", look)
	portrait_rect.texture = Appearance.tex_for("portrait", look)
	_show_frame()


func _turn(d: int) -> void:
	spin = false
	_facing = (_facing + d + 4) % 4
	_show_frame()


func _show_frame() -> void:
	if _sheet == null:
		return
	var at := AtlasTexture.new()
	at.atlas = _sheet
	var cw := _sheet.get_width() / 6.0
	var ch := _sheet.get_height() / 4.0
	# crop to the figure and its base (the top of each cell is empty air)
	at.region = Rect2(_frame * cw + cw * 0.12, _facing * ch + ch * 0.04, cw * 0.76, ch * 0.88)
	mini_rect.texture = at
	facing_label.text = ["Front", "Right side", "Back", "Left side"][_facing]


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.55:
		_t = 0.0
		_frame = 1 - _frame
		if spin:
			_turn_t += 1.0
			if _turn_t >= 3.0:
				_turn_t = 0.0
				_facing = (_facing + 1) % 4
		_show_frame()


## Test / playtest hook: show a given facing without waiting for the turn.
func show_facing(i: int) -> void:
	spin = false
	_facing = clampi(i, 0, 3)
	_show_frame()
