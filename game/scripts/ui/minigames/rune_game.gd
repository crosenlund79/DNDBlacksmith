## RuneGame — Runecrafting: "Rune Stabilization".
## EN: The engraved socket sits on the actual piece. A charged rune hovers above it, vibrating and
##     drifting: it has momentum, the socket's magic swirls it sideways, and it surges now and then.
##     First guide it into the socket, then hold it there. Quality is how closely and steadily it
##     stays seated for the binding (continuous; a perfect binding exceeds 100%).
##     Mouse: the rune is drawn towards the cursor (it lags — it is magic, not a handle).
##     Keys: W/A/S/D or arrows push it.
## DA: Før runen ned i soklen og hold den stabil mod magisk drift. Kvaliteten er, hvor tæt og
##     roligt den sidder under bindingen.
class_name RuneGame
extends MinigameBase

const BIND := 4.0
const CAPTURE := 30.0

var r := Vector2.ZERO        # rune position relative to the socket (px)
var v := Vector2.ZERO
var swirl := 1.0
var surge := Vector2.ZERO
var surge_t := 0.0
var mouse_target := Vector2.ZERO
var mouse_active := false
var seated := false
var guide_t := 0.0
var bind_t := 0.0
var q_sum := 0.0
var live_q := 0.0
var sparks: Array = []


func instructions() -> String:
	return "Guide the rune into the socket and hold it there: move the mouse (the rune follows) or push it with W/A/S/D / arrows"


func tol() -> float:
	return 20.0 * ease


func _start_round() -> void:
	var a := randf() * TAU
	r = Vector2(cos(a), sin(a)) * randf_range(150.0, 190.0)
	v = Vector2.ZERO
	swirl = 1.0 if randf() < 0.5 else -1.0
	seated = false
	guide_t = 0.0
	bind_t = 0.0
	q_sum = 0.0
	surge_t = randf_range(0.8, 1.6)
	mouse_active = false
	Audio.play("sfx/rune_hum", -6.0)


func _tick(delta: float) -> void:
	var item := _item_rect()
	# forces: the socket's swirl (perpendicular), a wandering surge, and the player's guidance
	var strength := 70.0 * pace / sqrt(ease)
	var acc := Vector2(-r.y, r.x).normalized() * swirl * strength if r.length() > 2.0 else Vector2.ZERO
	surge_t -= delta
	if surge_t <= 0.0:
		surge_t = randf_range(0.9, 1.8) * sqrt(ease)
		surge = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 260.0 * pace
		swirl = -swirl if randf() < 0.3 else swirl
		Audio.play("sfx/rune_hum", -12.0, 1.4)
	acc += surge
	surge = surge.move_toward(Vector2.ZERO, delta * 500.0)
	var inp := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	acc += inp * 720.0
	if mouse_active:
		acc += (mouse_target - r) * 9.0
	v += acc * delta
	v *= pow(0.12, delta)          # magical damping
	r += v * delta
	r = r.limit_length(item.size.x * 0.5)
	var d := r.length()
	live_q = q_from_error(d, tol())
	if not seated:
		guide_t += delta
		if d <= CAPTURE or guide_t > 3.0:
			seated = true
			Audio.play("sfx/chisel", -4.0)
	else:
		bind_t += delta
		q_sum += live_q * delta
		if bind_t >= BIND:
			var q := q_sum / BIND
			finish_round(q, "Rune bound true" if q >= 114.0 else ("Rune bound" if q >= 90.0 else ("Rune holds" if q >= 75.0 else "Rune flickers")))
			return
	# sparks when the rune strains away from its socket
	if randf() < delta * (2.0 + d * 0.12):
		sparks.append([r, Vector2(randf_range(-80, 80), randf_range(-120, -20)), 0.6])
	for s in sparks:
		s[0] += s[1] * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)


func _gui_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseMotion:
		mouse_active = true
		var mp: Vector2 = event.position
		mouse_target = mp - _socket_pos()
		accept_event()


func _socket_pos() -> Vector2:
	return size * 0.5 + Vector2(40, 10)


func _item_rect() -> Rect2:
	return Rect2(size * 0.5 + Vector2(-380, -60), Vector2(760, 140))


func _draw() -> void:
	var c := draw_frame()
	var sp := _socket_pos()
	var calm := clampf(live_q / 120.0, 0.0, 1.0)
	# the piece: a blade with an engraved fuller and the socket in its ricasso
	var bl := sp + Vector2(-360, 0)
	var br := sp + Vector2(300, 0)
	draw_colored_polygon(PackedVector2Array([bl + Vector2(0, -34), br + Vector2(0, -26), br + Vector2(70, 0), br + Vector2(0, 26), bl + Vector2(0, 34)]), Color("#b8bcc0"))
	draw_polyline(PackedVector2Array([bl + Vector2(0, -34), br + Vector2(0, -26), br + Vector2(70, 0), br + Vector2(0, 26), bl + Vector2(0, 34), bl + Vector2(0, -34)]), INK, 3.0)
	draw_line(bl + Vector2(20, 0), br + Vector2(-10, 0), Color(0.4, 0.42, 0.45), 6.0)
	draw_rect(Rect2(bl + Vector2(-90, -14), Vector2(90, 28)), Color("#6a4a2a"))
	draw_rect(Rect2(bl + Vector2(-16, -60), Vector2(16, 120)), Color("#8a6a3a"))
	# the socket: engraved ring with guide marks, lit as the rune settles
	draw_circle(sp, tol() + 26.0, Color(0.55, 0.45, 1.0, 0.08 + 0.3 * calm * (1.0 if seated else 0.4)))
	draw_circle(sp, 26.0, Color(0.25, 0.26, 0.3))
	draw_arc(sp, 26.0, 0, TAU, 32, INK, 3.0)
	draw_arc(sp, tol(), 0, TAU, 48, Color(0.75, 0.65, 1.0, 0.5), 2.0)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		draw_line(sp + Vector2(cos(a), sin(a)) * 32, sp + Vector2(cos(a), sin(a)) * 44, Color(0.75, 0.65, 1.0, 0.7), 2.0)
	# the rune: vibrates in proportion to how far it strains
	var jit := Vector2(sin(t * 47.0), cos(t * 53.0)) * (1.0 + r.length() * 0.04)
	var rp := sp + r + jit
	draw_circle(rp, 34.0, Color(0.6, 0.5, 1.0, 0.18 + 0.25 * calm))
	draw_circle(rp, 22.0, Color("#3a3448"))
	draw_arc(rp, 22.0, 0, TAU, 24, INK, 3.0)
	var gc := Color(0.85, 0.78, 1.0, 0.7 + 0.3 * calm)
	draw_line(rp + Vector2(0, -13), rp + Vector2(0, 13), gc, 3.0)
	draw_line(rp + Vector2(0, -3), rp + Vector2(9, -11), gc, 3.0)
	draw_line(rp + Vector2(0, 4), rp + Vector2(-9, -4), gc, 3.0)
	for s in sparks:
		draw_circle(sp + s[0], 2.5, Color(0.85, 0.75, 1.0, s[2] * 1.5))
	var fb := Assets.font("heading")
	var status := "guide the rune into the socket" if not seated else "hold it — binding %d%%" % int(clampf(bind_t / BIND, 0.0, 1.0) * 100.0)
	draw_string(fb, Vector2(c.x - 300, c.y - 150), status, HORIZONTAL_ALIGNMENT_CENTER, 600, 24, PAPER)
	var avg := q_sum / maxf(bind_t, 0.01) if bind_t > 0.0 else live_q
	draw_meter(c + Vector2(-150, 200), 300, avg, "Binding")
	if flash > 0.0:
		draw_circle(sp, 90.0, Color(0.8, 0.7, 1.0, flash * 0.35))
	draw_feedback(c + Vector2(0, 150))
