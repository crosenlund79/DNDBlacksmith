## MinigameBase — shared frame for the specialised crafting skill checks.
## EN: Same contract as the circular SkillCheckPanel: args {station, count, speed, zone, title,
##     subtitle, on_done}. Each "round" yields one craftsmanship value (can exceed 100%), so a
##     recipe operation with 3 checks plays 3 rounds; on_done receives the array of qualities.
##     Skill reaches the minigame through zone/speed from Crafting.check_params(): `ease` (> 1 =
##     more forgiving) and `pace` (> 1 = faster) are derived from them.
## DA: Fælles ramme for de specialiserede færdighedsprøver. Hver runde giver én håndværksværdi;
##     færdighed kommer ind via zone og fart fra Crafting.check_params().
class_name MinigameBase
extends Control

const INK := Color("#20140c")
const PAPER := Color("#efe4cc")
const DIM := Color("#c8b898")
const EMBER := Color("#ffa050")
const GOLD := Color("#ffd27a")

var args: Dictionary
var cfg: Dictionary
var count := 1
var ease := 1.0
var pace := 1.0
var results: Array = []
var feedback := ""
var feedback_col := Color.WHITE
var feedback_t := 0.0
var flash := 0.0
var finished := false
var t := 0.0
var overlay: CheckOverlay
var suspended := false        # a how-to card or a practice run is open on top
var started := false
var practice := false         # a tutorial-difficulty practice run: no consequences


func _init(a: Dictionary, c := {}) -> void:
	args = a
	cfg = c
	count = maxi(1, int(a.get("count", 1)))
	ease = clampf(float(a.get("zone", 40.0)) / 40.0, 0.55, 2.2)
	pace = clampf(float(a.get("speed", 0.55)) / 0.55, 0.6, 1.6)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	practice = bool(a.get("practice", false))


func _ready() -> void:
	Game.block_time(true)
	overlay = CheckOverlay.new(self, args)
	add_child(overlay)
	if Minigames.should_auto_tutorial(args):
		overlay.open_tutorial(true)
	else:
		begin()


## Starts the first round (once); called directly or when the how-to card is closed.
func begin() -> void:
	if not started:
		started = true
		_start_round()


func set_suspended(on: bool) -> void:
	suspended = on


func can_help() -> bool:
	return started and not finished


func _exit_tree() -> void:
	Game.block_time(false)


## Overridden by each minigame.
func _start_round() -> void:
	pass


func instructions() -> String:
	return ""


func _process(delta: float) -> void:
	t += delta
	if feedback_t > 0.0:
		feedback_t -= delta
	flash = maxf(0.0, flash - delta * 2.5)
	if not finished and not suspended and started:
		_tick(minf(delta, 0.05))
	queue_redraw()


func _tick(_delta: float) -> void:
	pass


func confirm_pressed(event: InputEvent) -> bool:
	if suspended or not started or (overlay != null and overlay.eats(event)):
		return false
	return event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)


## Short visual + audio cue for a single hit or miss inside a round (multi-hit sections, etc.).
func cue(good: bool) -> void:
	if overlay:
		overlay.pulse(Color("#f0d060") if good else Color("#e0402a"), 0.6)
	flash = maxf(flash, 0.5 if good else 0.0)


## Continuous precision → craftsmanship: error relative to tolerance, same curve as the ring.
static func q_from_error(err: float, tol: float) -> float:
	return Crafting.check_quality(err / maxf(tol, 0.0001), 2.0)


func grade_color(q: float) -> Color:
	if q >= 114.0:
		return EMBER
	if q >= 90.0:
		return Color("#f0d060")
	if q >= 75.0:
		return PAPER
	return Color("#ff9a80")


## Records a finished round: feedback, sound, the world effect at the station, next round or done.
func finish_round(q: float, label := "") -> void:
	q = clampf(q, 1.0, 125.0)
	results.append(q)
	feedback = "%s  %d%%" % [label if label != "" else Crafting.grade(q), int(round(q))]
	feedback_col = grade_color(q)
	feedback_t = 1.1
	flash = 1.0 if q >= 95.0 else 0.4
	if q >= 114.0:
		Audio.play("sfx/check_perfect")
	elif q >= 95.0:
		Audio.play("sfx/check_great")
	elif q >= 75.0:
		Audio.play("sfx/check_good")
	else:
		Audio.play("sfx/check_poor")
	if overlay:
		overlay.pulse(CheckOverlay.hit_color(q), 1.0 if q >= 95.0 or q < 50.0 else 0.6)
	var station := str(args.get("station", ""))
	if not practice:
		Events.station_worked.emit(station, q)
	var sfx := str(DB.station(station).get("sfx", ""))
	if sfx.begins_with("hammer"):
		Audio.play("sfx/hammer_%d" % randi_range(1, 3) if sfx == "hammer" else "sfx/hammer_arcane", -6.0)
	elif sfx != "":
		Audio.play("sfx/" + sfx, -6.0)
	finished = true
	var last := results.size() >= count
	await get_tree().create_timer(CheckOverlay.LAST_ROUND_PAUSE if last else 0.8).timeout
	if not is_inside_tree():
		return
	if not last:
		finished = false
		_start_round()
		return
	# the closing banner: grade and percentage for a moment, then the flow continues by itself
	overlay.show_result(results)
	await overlay.result_closed
	var cb: Callable = args.get("on_done", Callable())
	queue_free()
	if cb.is_valid():
		cb.call(results)


# ------------------------------------------------------------------ shared drawing
var _panel_sb: StyleBox


func draw_frame() -> Vector2:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.025, 0.015, 0.45))
	var c := vs * 0.5
	var panel := Rect2(c - Vector2(480, 360), Vector2(960, 720))
	if _panel_sb == null:
		_panel_sb = Assets.panel_style("dark")
	draw_style_box(_panel_sb, panel)
	var f := Assets.font("title")
	var fb := Assets.font("heading")
	draw_string(f, Vector2(panel.position.x, panel.position.y + 66), str(args.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 40, PAPER)
	if args.has("subtitle"):
		draw_string(fb, Vector2(panel.position.x, panel.position.y + 98), str(args["subtitle"]), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, DIM)
	if Assets.has_tex("ui/divider"):
		var dv := Assets.get_tex("ui/divider")
		draw_texture_rect(dv, Rect2(c.x - 220, panel.position.y + 108, 440, 24), false, Color(1, 1, 1, 0.8))
	draw_multiline_string(fb, Vector2(panel.position.x + 60, panel.end.y - 70), instructions(), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 120, 20, 2, DIM)
	# per-round pips
	for i in count:
		var px := c.x + (i - (count - 1) * 0.5) * 34.0
		var col := Color(PAPER, 0.25)
		if i < results.size():
			col = grade_color(float(results[i]))
		draw_circle(Vector2(px, panel.end.y - 18), 8.0, col)
		draw_arc(Vector2(px, panel.end.y - 18), 8.0, 0, TAU, 20, INK, 2.0)
	return c


func draw_feedback(at: Vector2) -> void:
	if feedback_t > 0.0:
		draw_string(Assets.font("title"), Vector2(at.x - 400, at.y), feedback, HORIZONTAL_ALIGNMENT_CENTER, 800, 44, Color(feedback_col, clampf(feedback_t * 1.5, 0.0, 1.0)))


func draw_meter(pos: Vector2, w: float, value: float, label: String) -> void:
	var fb := Assets.font("heading")
	draw_string(fb, pos + Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, w, 18, DIM)
	draw_rect(Rect2(pos, Vector2(w, 12)), Color(0.12, 0.08, 0.05))
	var v := clampf(value / 125.0, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w * v, 12)), grade_color(value))
	var x100 := pos.x + w * 100.0 / 125.0
	draw_line(Vector2(x100, pos.y - 3), Vector2(x100, pos.y + 15), PAPER, 2.0)
	draw_rect(Rect2(pos, Vector2(w, 12)), Color("#6e6250"), false, 1.0)
