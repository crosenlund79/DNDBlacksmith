## CheckOverlay — the shared chrome over every skill check (ring and specialised minigames).
## EN: Adds to any check: a small "?" button that reopens the mechanic's how-to card; the card itself
##     (illustration, what to watch, which keys, what scores well, a "Practice (tutorial difficulty)"
##     button and "Don't show again"); hit/miss colour pulses; and the closing result banner that
##     shows the grade and percentage for ~1.5 s with a sound, then continues the crafting flow by
##     itself (click / E / Space continues at once). The host check stays the owner of its callback.
##     Host contract: host.set_suspended(on: bool) pauses/resumes the check while a card or a
##     practice run is open; host.begin() starts the first round if it has not started yet.
## DA: Fælles overlag for alle færdighedsprøver: "?"-knap, vejledningskort med øvelse, farveblink
##     ved træf og bom, og et resultatbanner der lukker af sig selv efter et øjeblik.
class_name CheckOverlay
extends Control

signal result_closed

const RESULT_SECS := 1.5
const INK := Color("#20140c")
const PAPER := Color("#efe4cc")
const GILT := Color("#b8923e")

var host: Control
var args: Dictionary
var type := "ring"
var practice := false
var help_btn: Button
var card: Control
var dont_show: CheckBox
var practice_line: RichTextLabel
var pulse_col := Color.TRANSPARENT
var pulse_t := 0.0
var result_t := -1.0
var result_q := 0.0
var result_n := 0
var result_rounds: Array = []
var _closing := false


func _init(h: Control, a: Dictionary) -> void:
	host = h
	args = a
	type = Minigames.mechanic(a)
	practice = bool(a.get("practice", false))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5


func _ready() -> void:
	help_btn = Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "How does this check work? (opens the how-to card and practice)"
	help_btn.custom_minimum_size = Vector2(52, 52)
	help_btn.add_theme_font_override("font", Assets.font("title"))
	help_btn.add_theme_font_size_override("font_size", 30)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.pressed.connect(func(): Audio.play("sfx/ui_click", -4.0); open_tutorial(false))
	help_btn.visible = not practice
	add_child(help_btn)
	_place_help()
	resized.connect(_place_help)


func _place_help() -> void:
	if help_btn:
		help_btn.position = size * 0.5 + Vector2(480 - 74, -360 + 20)


## True when the event is meant for the overlay (a click on "?" or anywhere while a card is open),
## so the check underneath must not treat it as its own press.
func eats(event: InputEvent) -> bool:
	if card != null and is_instance_valid(card) and card.visible:
		return true
	if event is InputEventMouseButton and help_btn != null and help_btn.visible:
		return help_btn.get_global_rect().grow(4).has_point((event as InputEventMouseButton).global_position)
	return false


func busy() -> bool:
	return (card != null and is_instance_valid(card) and card.visible) or result_t >= 0.0


# ------------------------------------------------------------------ feedback
## A short coloured pulse around the check: gold for good work, red for a miss.
func pulse(col: Color, strength := 1.0) -> void:
	pulse_col = Color(col, clampf(strength, 0.2, 1.0))
	pulse_t = 0.45


static func hit_color(q: float) -> Color:
	if q >= 114.0:
		return Color("#ffb04a")
	if q >= 90.0:
		return Color("#f0d060")
	if q >= 75.0:
		return Color("#d8d0b0")
	return Color("#e0402a")


# ------------------------------------------------------------------ result banner (auto-close)
## Shows the overall grade for RESULT_SECS (or until clicked), then emits result_closed.
func show_result(rounds: Array) -> void:
	result_rounds = rounds.duplicate()
	result_n = rounds.size()
	var tot := 0.0
	for q in rounds:
		tot += float(q)
	result_q = tot / maxf(1.0, float(result_n))
	result_t = RESULT_SECS
	help_btn.visible = false
	var snd := "sfx/reveal_rare" if result_q >= 114.0 else ("sfx/reveal_magic" if result_q >= 90.0 else ("sfx/reveal_common" if result_q >= 60.0 else "sfx/check_poor"))
	Audio.play(snd, -6.0)
	pulse(hit_color(result_q), 0.8)


func _finish_result() -> void:
	if _closing:
		return
	_closing = true
	result_t = -1.0
	result_closed.emit()


func _input(event: InputEvent) -> void:
	if result_t >= 0.0 and result_t < RESULT_SECS - 0.25:
		var press: bool = event.is_action_pressed("interact") or event.is_action_pressed("cancel") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if press:
			get_viewport().set_input_as_handled()
			_finish_result()
	elif card != null and is_instance_valid(card) and card.visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_close_card()


func _process(delta: float) -> void:
	if help_btn:
		help_btn.visible = not practice and card == null and result_t < 0.0 and bool(host.call("can_help"))
	if pulse_t > 0.0:
		pulse_t -= delta
	if result_t >= 0.0:
		result_t -= delta
		if result_t < 0.0:
			_finish_result()
	queue_redraw()


func _draw() -> void:
	var vs := size
	if card != null and is_instance_valid(card) and card.visible:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.01, 0.5))
	if pulse_t > 0.0:
		var a := clampf(pulse_t / 0.45, 0.0, 1.0) * pulse_col.a
		if host is SkillCheckPanel:
			# the ring check has no frame: pulse around the dial
			for i in 4:
				draw_arc(vs * 0.5, 236.0 + i * 8.0, 0, TAU, 96, Color(pulse_col, a * (0.6 - i * 0.13)), 7.0)
		else:
			var r := Rect2(vs * 0.5 - Vector2(480, 360), Vector2(960, 720))
			for i in 4:
				draw_rect(r.grow(4 + i * 7), Color(pulse_col, a * (0.55 - i * 0.12)), false, 7.0)
	if result_t >= 0.0:
		_draw_result(vs)


func _draw_result(vs: Vector2) -> void:
	var c := vs * 0.5
	var fade := clampf((RESULT_SECS - result_t) * 6.0, 0.0, 1.0)
	var box := Rect2(c - Vector2(330, 120), Vector2(660, 240))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.01, 0.35 * fade))
	draw_style_box(Assets.panel_style("dark"), box)
	var col := hit_color(result_q)
	var fb := Assets.font("heading")
	var ft := Assets.font("title")
	var head := "Practice result" if practice else "Work complete"
	draw_string(fb, Vector2(box.position.x, box.position.y + 46), head, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 22, Color(PAPER, 0.75 * fade))
	draw_string(ft, Vector2(box.position.x, box.position.y + 120), "%s  %d%%" % [Crafting.grade(result_q), int(round(result_q))], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 54, Color(col, fade))
	# one pip per round, coloured by its grade
	for i in result_n:
		var px := c.x + (i - (result_n - 1) * 0.5) * 30.0
		draw_circle(Vector2(px, box.position.y + 152), 9.0, Color(hit_color(float(result_rounds[i])), fade))
		draw_arc(Vector2(px, box.position.y + 152), 9.0, 0, TAU, 20, INK, 2.0)
	var sub := "nothing here affects your work" if practice else ("exceptional — beyond the usual craft" if result_q > 100.0 else "")
	if sub != "":
		draw_string(fb, Vector2(box.position.x, box.position.y + 190), sub, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 18, Color(GILT.lightened(0.3), fade))
	# remaining time as a thin bar, and the hint to continue early
	var frac := clampf(result_t / RESULT_SECS, 0.0, 1.0)
	draw_rect(Rect2(box.position + Vector2(60, box.size.y - 30), Vector2((box.size.x - 120) * frac, 4)), Color(PAPER, 0.5 * fade))
	draw_string(fb, Vector2(box.position.x, box.end.y + 30), "continuing…  (click or %s to continue now)" % Settings.key_label("interact"), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 18, Color(PAPER, 0.6 * fade))


# ------------------------------------------------------------------ the how-to card
func open_tutorial(auto: bool) -> void:
	if card != null and is_instance_valid(card):
		card.queue_free()
	host.call("set_suspended", true)
	var tut := Minigames.tutorial(type)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(900, 0)
	var v := UIKit.vbox(10)
	card.add_child(v)
	var head := UIKit.hbox(12)
	var tl := UIKit.title("How to: " + str(tut["name"]), 36)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if auto:
		head.add_child(UIKit.label("new mechanic", 20, "body_italic", UIKit.RUBRIC))
	v.add_child(head)
	v.add_child(UIKit.divider())
	var row := UIKit.hbox(20)
	var ill := TextureRect.new()
	ill.texture = Assets.get_tex("ui/tut_" + type) if Assets.has_tex("ui/tut_" + type) else null
	ill.custom_minimum_size = Vector2(360, 260)
	ill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ill)
	var tx := UIKit.vbox(8)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for part in [["Watch", "watch", "ui/tut_eye"], ["Keys", "keys", "ui/tut_key"], ["Scores well", "score", "ui/tut_star"]]:
		var pr := UIKit.hbox(10)
		var ic := UIKit.icon(str(part[2]), 40)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pr.add_child(ic)
		var rt := UIKit.rich("[b]%s:[/b] %s" % [part[0], tut[part[1]]], 21)
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pr.add_child(rt)
		tx.add_child(pr)
	practice_line = UIKit.rich("", 19)
	tx.add_child(practice_line)
	row.add_child(tx)
	v.add_child(row)
	var btns := UIKit.hbox(12)
	btns.add_child(UIKit.button("Start the check" if not host.get("started") else "Back to the check", _close_card, 240))
	btns.add_child(UIKit.button("Practice (tutorial difficulty)", _practice, 330))
	dont_show = CheckBox.new()
	dont_show.text = "Don't show again"
	dont_show.button_pressed = true if auto else Minigames.tutorial_seen(type)
	dont_show.add_theme_color_override("font_color", INK)
	dont_show.add_theme_color_override("font_hover_color", INK)
	dont_show.add_theme_color_override("font_pressed_color", INK)
	dont_show.add_theme_font_size_override("font_size", 20)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(spacer)
	btns.add_child(dont_show)
	v.add_child(btns)
	add_child(card)
	help_btn.visible = false
	await get_tree().process_frame
	if is_instance_valid(card):
		card.reset_size()
		card.position = (size - card.size) * 0.5


func _close_card() -> void:
	if card == null or not is_instance_valid(card):
		return
	Minigames.set_tutorial_seen(type, dont_show.button_pressed)
	card.queue_free()
	card = null
	help_btn.visible = not practice and result_t < 0.0
	host.call("set_suspended", false)
	host.call("begin")


## A no-consequence run of the same mechanic at tutorial difficulty, played on top of the check.
func _practice() -> void:
	if card == null:
		return
	card.visible = false
	host.self_modulate = Color(1, 1, 1, 0)      # the practice run draws its own dial on top
	var pa := Minigames.practice_args(args)
	pa["on_done"] = func(qs: Array):
		host.self_modulate = Color.WHITE
		if is_instance_valid(card):
			card.visible = true
			var q := float(qs[0]) if not qs.is_empty() else 0.0
			practice_line.text = "[color=#5e421c]Practice: [b]%s %d%%[/b] — try again, or start the real check.[/color]" % [Crafting.grade(q), int(round(q))]
	var g := Minigames.create(pa)
	host.add_child(g)
