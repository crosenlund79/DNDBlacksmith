## AlignGame — Bellows: "Spark & Ember Alignment".
## EN: Two independently controlled rotating mechanisms — the inner Spark wheel and the outer Ember
##     ring — are pushed around by the airflow. Turn each until its notch faces the vent, then
##     pump (E / Space / click the bellows button). Quality comes from how precisely BOTH are aligned
##     at the moment of the pump (continuous; a perfect pair exceeds 100%).
##     Keys: A/D (←/→) turn Spark, W/S (↑/↓) turn Ember. Mouse: drag either ring.
## DA: To mekanismer, Gnist og Glød, skubbes af luftstrømmen. Drej begge, så hakket peger mod
##     aftrækket, og pump. Kvaliteten afhænger af, hvor præcist begge flugter.
class_name AlignGame
extends MinigameBase

const R_SPARK := 120.0
const R_EMBER := 190.0
const TURN := 150.0

var spark := 0.0          # degrees from the vent (0 = aligned)
var ember := 0.0
var spark_v := 0.0
var ember_v := 0.0
var drift_t := 0.0
var round_t := 0.0
var dragging := ""
var drag_last := 0.0
var in_spark := false
var in_ember := false
var sparks: Array = []    # [pos, vel, life]


func instructions() -> String:
	return "A/D or ←/→ turn the Spark wheel · W/S or ↑/↓ turn the Ember ring · drag with the mouse · E, Space or click the bellows to pump"


func tol() -> float:
	return 16.0 * ease


func _start_round() -> void:
	spark = randf_range(70.0, 160.0) * (1 if randf() < 0.5 else -1)
	ember = randf_range(70.0, 160.0) * (1 if randf() < 0.5 else -1)
	spark_v = randf_range(-1, 1)
	ember_v = randf_range(-1, 1)
	round_t = 0.0
	Audio.play("sfx/check_start", -4.0)


func error() -> float:
	var a := absf(spark)
	var b := absf(ember)
	return 0.5 * maxf(a, b) + 0.5 * sqrt((a * a + b * b) * 0.5)


func live_quality() -> float:
	return q_from_error(error(), tol())


func _tick(delta: float) -> void:
	round_t += delta
	# airflow: each mechanism drifts with its own slowly changing push
	drift_t -= delta
	if drift_t <= 0.0:
		drift_t = randf_range(0.6, 1.4)
		spark_v = clampf(spark_v + randf_range(-0.9, 0.9), -1.0, 1.0)
		ember_v = clampf(ember_v + randf_range(-0.9, 0.9), -1.0, 1.0)
	var drift := 22.0 * pace / sqrt(ease)
	spark = wrapf(spark + spark_v * drift * delta, -180.0, 180.0)
	ember = wrapf(ember - ember_v * drift * 0.8 * delta, -180.0, 180.0)
	var s_in := Input.get_axis("move_left", "move_right")
	var e_in := Input.get_axis("move_up", "move_down")
	spark = wrapf(spark + s_in * TURN * delta, -180.0, 180.0)
	ember = wrapf(ember + e_in * TURN * delta, -180.0, 180.0)
	# alignment feedback: a click as each mechanism enters the window
	var now_s := absf(spark) <= tol()
	var now_e := absf(ember) <= tol()
	if now_s and not in_spark:
		Audio.play("sfx/check_tick", -6.0, 1.25)
	if now_e and not in_ember:
		Audio.play("sfx/check_tick", -6.0, 0.9)
	in_spark = now_s
	in_ember = now_e
	# sparks rise from the hearth in proportion to the airflow quality
	var lq := live_quality()
	if randf() < delta * (4.0 + lq * 0.25):
		sparks.append([Vector2(randf_range(-30, 30), 10), Vector2(randf_range(-40, 40), randf_range(-160, -90) * (0.5 + lq / 120.0)), 1.0])
	for s in sparks:
		s[0] += s[1] * delta
		s[2] -= delta * 0.9
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	if round_t > 10.0:
		_pump()


func _gui_input(event: InputEvent) -> void:
	if finished or suspended or not started:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var c := size * 0.5 + Vector2(0, -14)
		var ep: Vector2 = event.position
		var d := (ep - c).length()
		if event.pressed:
			if d < 60.0:
				_pump()
			elif absf(d - R_SPARK) < 34.0:
				dragging = "spark"
			elif absf(d - R_EMBER) < 34.0:
				dragging = "ember"
			drag_last = rad_to_deg((ep - c).angle())
		else:
			dragging = ""
		accept_event()
	elif event is InputEventMouseMotion and dragging != "":
		var c2 := size * 0.5 + Vector2(0, -14)
		var mp: Vector2 = event.position
		var a := rad_to_deg((mp - c2).angle())
		var da := wrapf(a - drag_last, -180.0, 180.0)
		drag_last = a
		if dragging == "spark":
			spark = wrapf(spark + da, -180.0, 180.0)
		else:
			ember = wrapf(ember + da, -180.0, 180.0)
		accept_event()


func _input(event: InputEvent) -> void:
	if finished or suspended or not started:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_pump()


func _pump() -> void:
	if finished or suspended or not started:
		return
	Audio.play("sfx/bellows", -2.0)
	var q := live_quality()
	finish_round(q, "Roaring flame" if q >= 114.0 else ("Bright flame" if q >= 90.0 else ("Steady flame" if q >= 75.0 else "Smoky flame")))


func _draw() -> void:
	var c := draw_frame() + Vector2(0, -14)
	var lq := live_quality()
	if finished and not results.is_empty():
		lq = float(results[-1])
	var heat := clampf(lq / 120.0, 0.05, 1.0)
	# hearth glow and airflow streams
	draw_circle(c, 222.0, Color(0.16, 0.08, 0.04, 0.9))
	draw_circle(c, 70.0 + 30.0 * heat, Color(1.0, 0.45, 0.12, 0.18 + 0.25 * heat))
	for i in 7:
		var a0 := -PI * 0.5 + (i - 3) * 0.16
		var ph := fposmod(t * (0.6 + heat) + i * 0.37, 1.0)
		var r0 := lerpf(R_EMBER + 20.0, 64.0, ph)
		draw_arc(c, r0, a0 - 0.05, a0 + 0.05, 6, Color(0.95, 0.85, 0.7, 0.35 * (1.0 - ph) * heat), 3.0)
	# Ember ring (outer)
	_draw_ring(c, R_EMBER, ember, Color("#c8642a"), "EMBER", absf(ember) <= tol())
	# Spark wheel (inner)
	_draw_ring(c, R_SPARK, spark, Color("#e8dcc0"), "SPARK", absf(spark) <= tol())
	# vent marker at the top
	var vt := c + Vector2(0, -R_EMBER - 40)
	draw_colored_polygon(PackedVector2Array([vt + Vector2(-16, -14), vt + Vector2(16, -14), vt + Vector2(0, 10)]), GOLD)
	draw_string(Assets.font("heading"), vt + Vector2(-60, -22), "the vent", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, DIM)
	# alignment window
	var tw := deg_to_rad(tol())
	draw_arc(c, R_EMBER + 26, -PI * 0.5 - tw, -PI * 0.5 + tw, 16, Color(GOLD, 0.6), 4.0)
	# flame in the hearth / bellows button
	draw_circle(c, 54.0, Color("#2a1a10"))
	draw_arc(c, 54.0, 0, TAU, 40, Color("#8a6a3a"), 3.0)
	var fh := 18.0 + 46.0 * heat
	var flick := sin(t * 18.0) * 3.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 24), c + Vector2(22, 24), c + Vector2(6 + flick, 24 - fh), c + Vector2(-4 - flick, 24 - fh * 0.8)]), Color(1.0, 0.5 + 0.3 * heat, 0.15, 0.95))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 24), c + Vector2(10, 24), c + Vector2(flick, 24 - fh * 0.6)]), Color(1.0, 0.9, 0.55, 0.95))
	for s in sparks:
		draw_circle(c + s[0], 2.5, Color(1.0, 0.8, 0.35, s[2]))
	draw_meter(c + Vector2(-150, 240), 300, lq, "Airflow")
	if flash > 0.0:
		draw_arc(c, R_EMBER, 0, TAU, 96, Color(1.0, 0.75, 0.35, flash * 0.6), 36.0)
	draw_feedback(c + Vector2(0, 20))


func _draw_ring(c: Vector2, r: float, off_deg: float, col: Color, name: String, aligned: bool) -> void:
	draw_arc(c, r, 0, TAU, 96, Color("#20140c"), 30.0)
	draw_arc(c, r, 0, TAU, 96, Color(col, 0.55), 22.0)
	var a := deg_to_rad(-90.0 + off_deg)
	for i in 12:
		var ta := a + TAU * i / 12.0
		draw_line(c + Vector2(cos(ta), sin(ta)) * (r - 11), c + Vector2(cos(ta), sin(ta)) * (r + 11), Color("#20140c"), 2.0)
	var tip := c + Vector2(cos(a), sin(a)) * r
	draw_circle(tip, 16.0, GOLD if aligned else col)
	draw_arc(tip, 16.0, 0, TAU, 20, Color("#20140c"), 3.0)
	if aligned:
		draw_circle(tip, 26.0, Color(1.0, 0.8, 0.4, 0.25 + 0.15 * sin(t * 10.0)))
	draw_string(Assets.font("heading"), tip + Vector2(-50, 40), name, HORIZONTAL_ALIGNMENT_CENTER, 100, 18, col)
