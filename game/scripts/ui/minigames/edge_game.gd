## EdgeGame — Grinding Wheel: "Edge Control".
## EN: A close-up of the blade on the turning stone. Hold the sharpening ANGLE (W/S, ↑/↓, mouse up/
##     down) and the contact PRESSURE (A/D, ←/→, mouse left/right) on the sweet spot, which slowly
##     wanders as the stone wears and the steel heats; the grit occasionally catches and kicks the
##     blade. Quality is the average precision held over the whole pass — sustained, steady control,
##     not a single press. Perfect control exceeds 100%.
## DA: Hold vinkel og tryk på det søde punkt, mens det vandrer. Kvaliteten er den gennemsnitlige
##     præcision gennem hele slibningen.
class_name EdgeGame
extends MinigameBase

const PASS := 4.5

var p := Vector2.ZERO          # x = pressure, y = angle  (normalised −1 … 1)
var target := Vector2.ZERO
var phase := Vector2.ZERO
var kick := Vector2.ZERO
var kick_t := 0.0
var elapsed := 0.0
var q_sum := 0.0
var q_n := 0
var live_q := 0.0
var spin := 0.0
var snd_t := 0.0
var sparks: Array = []


func instructions() -> String:
	return "Hold the blade on the sweet spot: W/S or ↑/↓ = angle · A/D or ←/→ = pressure · or move the mouse · keep it there for the whole pass"


func tol() -> float:
	return 0.17 * ease


func _start_round() -> void:
	p = Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
	phase = Vector2(randf() * TAU, randf() * TAU)
	elapsed = -0.6           # a short settle before scoring begins
	q_sum = 0.0
	q_n = 0
	kick_t = randf_range(0.8, 1.6)
	Audio.play("sfx/grind", -6.0)


func _tick(delta: float) -> void:
	elapsed += delta
	spin += delta * 9.0
	# the sweet spot wanders (two incommensurate sines per axis)
	var w := 0.55 * pace
	target = Vector2(0.42 * sin(t * w * 1.3 + phase.x) + 0.12 * sin(t * w * 3.1),
		0.42 * sin(t * w * 0.9 + phase.y) + 0.12 * sin(t * w * 2.7 + 1.0)) / sqrt(ease)
	# the grit catches now and then and kicks the blade
	kick_t -= delta
	if kick_t <= 0.0:
		kick_t = randf_range(0.7, 1.5) * sqrt(ease)
		kick = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 0.9 * pace
		Audio.play("sfx/grind", -10.0, 1.3)
	p += kick * delta
	kick = kick.move_toward(Vector2.ZERO, delta * 3.0)
	var inp := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	p += inp * 1.3 * delta
	p = p.clamp(Vector2(-1, -1), Vector2(1, 1))
	live_q = q_from_error(p.distance_to(target), tol())
	if elapsed >= 0.0:
		q_sum += live_q * delta
		q_n += 1
	snd_t -= delta
	if snd_t <= 0.0:
		snd_t = 0.45
		Audio.play("sfx/grind", lerpf(-16.0, -6.0, (p.x + 1.0) * 0.5), lerpf(0.8, 1.2, live_q / 120.0))
	var rate := 20.0 + live_q * 0.6
	for i in int(rate * delta + randf()):
		var good := live_q >= 90.0
		var dir := Vector2(randf_range(-1.0, -0.2), randf_range(-0.9, 0.3)).normalized()
		sparks.append([Vector2.ZERO, dir * randf_range(180, 420), randf_range(0.25, 0.6), good])
	for s in sparks:
		s[0] += s[1] * delta
		s[1] += Vector2(0, 600) * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	if elapsed >= PASS:
		var q := q_sum / maxf(PASS, 0.001)
		finish_round(q, "Razor edge" if q >= 114.0 else ("Keen edge" if q >= 90.0 else ("Fair edge" if q >= 75.0 else "Ragged edge")))


func _gui_input(event: InputEvent) -> void:
	if finished or suspended or not started:
		return
	if event is InputEventMouseMotion:
		var rel: Vector2 = event.relative
		p += rel / 220.0
		p = p.clamp(Vector2(-1, -1), Vector2(1, 1))
		accept_event()


func _draw() -> void:
	var c := draw_frame()
	var wheel_c := c + Vector2(150, 10)
	var R := 170.0
	# grindstone
	draw_circle(wheel_c, R + 8, Color("#20140c"))
	draw_circle(wheel_c, R, Color("#8a8070"))
	draw_circle(wheel_c, R * 0.82, Color("#9a9080"))
	for i in 10:
		var a := spin + TAU * i / 10.0
		draw_line(wheel_c + Vector2(cos(a), sin(a)) * 30, wheel_c + Vector2(cos(a), sin(a)) * (R - 6), Color(0.3, 0.27, 0.22, 0.5), 2.0)
	draw_circle(wheel_c, 30, Color("#3a2c1c"))
	draw_circle(wheel_c, 12, Color("#b8923e"))
	# the blade: angle from p.y, push towards the stone from p.x
	var contact := wheel_c + Vector2(-R, 0).rotated(deg_to_rad(p.y * 22.0))
	var push := 8.0 + p.x * 14.0
	var ang := deg_to_rad(-8.0 + p.y * 18.0)
	var dirv := Vector2(cos(ang), sin(ang))
	var tip := contact + dirv * push
	var base := tip - dirv * 360.0
	var nrm := Vector2(-dirv.y, dirv.x)
	# ghost of the ideal blade
	var t_contact := wheel_c + Vector2(-R, 0).rotated(deg_to_rad(target.y * 22.0))
	var t_ang := deg_to_rad(-8.0 + target.y * 18.0)
	var t_dir := Vector2(cos(t_ang), sin(t_ang))
	var t_tip := t_contact + t_dir * (8.0 + target.x * 14.0)
	draw_line(t_tip - t_dir * 340.0, t_tip, Color(GOLD, 0.35), 18.0)
	draw_colored_polygon(PackedVector2Array([base + nrm * 14, tip + nrm * 4, tip - nrm * 2, base - nrm * 10]), Color("#c8ccd0"))
	draw_polyline(PackedVector2Array([base + nrm * 14, tip + nrm * 4, tip - nrm * 2, base - nrm * 10, base + nrm * 14]), INK, 3.0)
	draw_line(base + nrm * 2, tip, Color(1, 1, 1, 0.5), 2.0)
	var heat := clampf(live_q / 120.0, 0.0, 1.0)
	draw_circle(tip, 10.0 + 8.0 * heat, Color(1.0, 0.6, 0.2, 0.35 + 0.4 * heat))
	for s in sparks:
		var col: Color = Color(1.0, 0.85, 0.45, s[2] * 1.6) if s[3] else Color(0.9, 0.35, 0.2, s[2] * 1.6)
		draw_line(tip + s[0], tip + s[0] - (s[1] as Vector2) * 0.02, col, 2.0)
	# control gauge: pressure × angle, sweet-spot circle
	var g := Rect2(c + Vector2(-430, -150), Vector2(220, 220))
	draw_rect(g, Color(0.12, 0.08, 0.05))
	draw_rect(g, Color("#6e6250"), false, 2.0)
	var to_g := func(v: Vector2) -> Vector2: return g.get_center() + v * g.size * 0.5
	draw_circle(to_g.call(target), tol() * g.size.x * 0.5, Color(GOLD, 0.22))
	draw_arc(to_g.call(target), tol() * g.size.x * 0.5, 0, TAU, 32, GOLD, 2.0)
	draw_circle(to_g.call(p), 9.0, grade_color(live_q))
	draw_arc(to_g.call(p), 9.0, 0, TAU, 16, INK, 2.0)
	var fb := Assets.font("heading")
	draw_string(fb, g.position + Vector2(0, -8), "angle ↕   pressure ↔", HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 18, DIM)
	var prog := clampf(elapsed / PASS, 0.0, 1.0)
	draw_rect(Rect2(g.position + Vector2(0, g.size.y + 14), Vector2(g.size.x * prog, 8)), Color(PAPER, 0.6))
	draw_string(fb, g.position + Vector2(0, g.size.y + 44), "pass" if elapsed >= 0.0 else "settle the blade…", HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 18, DIM)
	var avg := q_sum / maxf(elapsed, 0.01) if elapsed > 0.0 else live_q
	draw_meter(c + Vector2(-150, 236), 300, avg, "Edge so far")
	draw_feedback(c + Vector2(150, -200))
