## SkillCheckPanel — the universal circular timing check (inspired by generator skill checks).
## EN: A needle sweeps around a ring; press Interact/Space/Click to stop it. The closer to the
##     centre of the target zone, the higher the craftsmanship (perfect centre > 100%). Several
##     checks per station; misses degrade quality rather than destroying the piece.
## DA: En viser farer rundt om en ring; tryk for at stoppe den. Jo tættere på zonens midte, jo
##     højere håndværk (perfekt midte > 100%). Bomskud forringer kvaliteten i stedet for at ødelægge.
class_name SkillCheckPanel
extends Control

var args: Dictionary
var count := 1
var speed := 0.55
var zone := 34.0
var angle := -90.0
var zone_center := 90.0
var results: Array = []
var running := false
var swept := 0.0
var feedback := ""
var feedback_col := Color.WHITE
var feedback_t := 0.0
var flash := 0.0


func _init(a: Dictionary) -> void:
	args = a
	count = int(a.get("count", 1))
	speed = float(a.get("speed", 0.55))
	zone = float(a.get("zone", 34.0))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	Game.block_time(true)
	_next()


func _exit_tree() -> void:
	Game.block_time(false)


func _next() -> void:
	angle = -90.0
	swept = 0.0
	zone_center = randf_range(-90.0 + 70.0, -90.0 + 320.0)
	running = true
	Audio.play("sfx/check_start", -4.0)


func _process(delta: float) -> void:
	if running:
		# clamp the step so a frame hitch can never jump the needle past the zone
		var d := speed * 360.0 * minf(delta, 0.05)
		angle += d
		swept += d
		if swept > 360.0 * 2.0:
			_resolve(true)
	if feedback_t > 0.0:
		feedback_t -= delta
	flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var press: bool = event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if press and running:
		get_viewport().set_input_as_handled()
		_resolve(false)
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()


func _resolve(missed: bool) -> void:
	running = false
	var q := 8.0
	if not missed:
		var off := fposmod(angle - zone_center + 180.0, 360.0) - 180.0
		q = Crafting.check_quality(off, zone)
	results.append(q)
	var g := Crafting.grade(q) if not missed else "Missed"
	feedback = "%s  %d%%" % [g, int(round(q))]
	feedback_col = Color("#ffa050") if q >= 114 else (Color("#f0d060") if q >= 95 else (Color("#efe4cc") if q >= 75 else Color("#ff9a80")))
	feedback_t = 1.0
	flash = 1.0 if q >= 95 else 0.4
	if q >= 114:
		Audio.play("sfx/check_perfect")
	elif q >= 95:
		Audio.play("sfx/check_great")
	elif q >= 75:
		Audio.play("sfx/check_good")
	else:
		Audio.play("sfx/check_poor")
	var station := str(args.get("station", ""))
	Events.station_worked.emit(station, q)
	var sfx := str(DB.station(station).get("sfx", ""))
	if sfx.begins_with("hammer"):
		Audio.play("sfx/hammer_%d" % randi_range(1, 3) if sfx == "hammer" else "sfx/hammer_arcane", -3.0)
	elif sfx != "":
		Audio.play("sfx/" + sfx, -5.0)
	await get_tree().create_timer(0.75).timeout
	if results.size() < count:
		_next()
	else:
		await get_tree().create_timer(0.35).timeout
		var cb: Callable = args.get("on_done", Callable())
		queue_free()
		if cb.is_valid():
			cb.call(results)


func _draw() -> void:
	var vs := size
	# lighter veil, so the station and its sparks/steam stay visible behind the ring
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.025, 0.015, 0.42))
	draw_circle(vs * 0.5, 300.0, Color(0.04, 0.025, 0.015, 0.45))
	var c := vs * 0.5
	var R := 170.0
	if Assets.has_tex("ui/skillcheck_ring"):
		var tex := Assets.get_tex("ui/skillcheck_ring")
		draw_texture_rect(tex, Rect2(c - Vector2(232, 232), Vector2(464, 464)), false)
	draw_arc(c, R, 0, TAU, 96, Color(0.94, 0.89, 0.8, 0.35), 18.0)
	# target zone with a brighter perfect band
	var half := deg_to_rad(zone * 0.5)
	var zc := deg_to_rad(zone_center)
	draw_arc(c, R, zc - half, zc + half, 32, Color("#e6702a"), 22.0)
	draw_arc(c, R, zc - half * 0.2, zc + half * 0.2, 8, Color("#ffd27a"), 26.0)
	for i in 24:
		var a := TAU * i / 24.0
		draw_line(c + Vector2(cos(a), sin(a)) * (R - 22), c + Vector2(cos(a), sin(a)) * (R - 12), Color(0.94, 0.89, 0.8, 0.5), 2.0)
	var na := deg_to_rad(angle)
	var tip := c + Vector2(cos(na), sin(na)) * (R + 14)
	draw_line(c, tip, Color("#20140c"), 9.0)
	draw_line(c, tip, Color("#efe4cc"), 4.0)
	draw_circle(tip, 9.0, Color("#ffd27a"))
	draw_circle(c, 16.0, Color("#20140c"))
	draw_circle(c, 9.0, Color("#b8923e"))
	var f := Assets.font("title")
	var fb := Assets.font("heading")
	draw_string(f, Vector2(0, c.y - R - 92), str(args.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 42, Color("#efe4cc"))
	if args.has("subtitle"):
		draw_string(fb, Vector2(0, c.y - R - 56), str(args["subtitle"]), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color("#c8b898"))
	# per-check results so far, as small coloured pips
	for i in count:
		var px := c.x + (i - (count - 1) * 0.5) * 34.0
		var col := Color(0.94, 0.89, 0.8, 0.25)
		if i < results.size():
			var rq := float(results[i])
			col = Color("#ffa050") if rq >= 114 else (Color("#f0d060") if rq >= 90 else (Color("#efe4cc") if rq >= 75 else Color("#ff9a80")))
		draw_circle(Vector2(px, c.y + R + 150), 11.0, col)
	draw_string(fb, Vector2(0, c.y + R + 70), "Check %d of %d — press %s when the needle crosses the ember" % [mini(results.size() + 1, count), count, Settings.key_label("interact")], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 26, Color("#c8b898"))
	if feedback_t > 0.0:
		draw_string(f, Vector2(0, c.y + 14), feedback, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 44, Color(feedback_col, clampf(feedback_t * 1.5, 0.0, 1.0)))
	var avg := 0.0
	for q in results:
		avg += float(q)
	if results.size() > 0:
		draw_string(fb, Vector2(0, c.y + R + 110), "Craftsmanship so far: %d%%" % int(round(avg / results.size())), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color("#ffc070"))
	if flash > 0.0:
		draw_arc(c, R, 0, TAU, 96, Color(1.0, 0.75, 0.35, flash * 0.6), 40.0)
