## RingsGame — Alchemy: "Ring Contact Timing".
## EN: A still ring appears; a moment later a second ring appears and contracts towards it (dir
##     "in": mixing, brewing) or expands towards it (dir "out": distilling, volatile reactions).
##     Press E / Space / click the instant they touch. Precision of the contact sets the quality
##     (continuous; a perfect contact exceeds 100%).
## DA: En fast ring, så en bevægelig ring der trækker sig sammen eller udvider sig. Tryk, når de mødes.
class_name RingsGame
extends MinigameBase

const R0 := 120.0
const FX := {
	"mixing": [Color("#b89060"), Color("#e8d0a0"), "Grind and fold"],
	"brewing": [Color("#5aa040"), Color("#c8f0a0"), "Bring to the boil"],
	"distilling": [Color("#4a80b8"), Color("#c0e0ff"), "Let the vapour rise"],
	"volatile": [Color("#c04030"), Color("#ffc080"), "Catch the reaction"],
}

var r := 0.0
var dir := -1.0
var state := 0          # 0 waiting for the second ring, 1 moving, 2 done
var wait_t := 0.0
var spd := 0.0
var motes: Array = []


func _look() -> Array:
	return FX.get(str(cfg.get("fx", "brewing")), FX["brewing"])


func instructions() -> String:
	return "Press E, Space or click the moment the %s ring touches the still one" % ("contracting" if str(cfg.get("dir", "in")) == "in" else "expanding")


func tol() -> float:
	return 9.0 * ease


func _start_round() -> void:
	dir = -1.0 if str(cfg.get("dir", "in")) == "in" else 1.0
	r = R0 * (2.0 if dir < 0.0 else 0.22)
	spd = randf_range(130.0, 170.0) * pace
	state = 0
	wait_t = randf_range(0.45, 0.9)
	Audio.play("sfx/check_start", -4.0)


func _tick(delta: float) -> void:
	if state == 0:
		wait_t -= delta
		if wait_t <= 0.0:
			state = 1
			Audio.play("sfx/bubble" if dir < 0.0 else "sfx/glass", -6.0)
	elif state == 1:
		r += dir * spd * delta
		var overshoot := (r - R0) * dir
		if overshoot > tol() * 3.5:
			_resolve(true)
	if randf() < delta * 14.0:
		motes.append([Vector2(randf_range(-60, 60), randf_range(-20, 40)), Vector2(randf_range(-20, 20), randf_range(-70, -30)), 1.0])
	for m in motes:
		m[0] += m[1] * delta
		m[2] -= delta * 0.8
	motes = motes.filter(func(m): return m[2] > 0.0)


func _input(event: InputEvent) -> void:
	if finished:
		return
	if confirm_pressed(event):
		get_viewport().set_input_as_handled()
		if state == 1:
			_resolve(false)


func _resolve(timeout: bool) -> void:
	state = 2
	var err := absf(r - R0)
	var q := 8.0 if timeout else q_from_error(err, tol())
	var fxname := str(cfg.get("fx", "brewing"))
	var words := {"mixing": ["Perfect blend", "Smooth paste", "Grainy", "Lumpy"], "brewing": ["Perfect boil", "Good simmer", "Uneven", "Scorched"],
		"distilling": ["Pure essence", "Clear drops", "Cloudy", "Spoiled run"], "volatile": ["Caught perfectly", "Contained", "Spitting", "Flash-burnt"]}
	var w: Array = words.get(fxname, words["brewing"])
	finish_round(q, w[0] if q >= 114.0 else (w[1] if q >= 90.0 else (w[2] if q >= 60.0 else w[3])))


func _draw() -> void:
	var c := draw_frame() + Vector2(0, 10)
	var look := _look()
	var base: Color = look[0]
	var hi: Color = look[1]
	# the vessel seen from above
	draw_circle(c, 252.0, INK)
	draw_circle(c, 244.0, Color("#5a4a3a"))
	draw_circle(c, 228.0, Color(base.darkened(0.55), 0.95))
	draw_circle(c, 210.0, Color(base, 0.32))
	for i in 14:
		var y := -200.0 + i * 30.0
		var hw := sqrt(maxf(0.0, 210.0 * 210.0 - y * y))
		draw_line(c + Vector2(-hw, y) + Vector2(0, 10), c + Vector2(-hw + 40, y - 30), Color(0, 0, 0, 0.12), 2.0)
	for m in motes:
		draw_circle(c + m[0] * 2.0, 4.0, Color(hi, m[2] * 0.6))
	# still ring + contact window
	draw_arc(c, R0, 0, TAU, 96, Color(hi, 0.25), tol() * 2.0)
	draw_arc(c, R0, 0, TAU, 96, hi, 6.0)
	draw_arc(c, R0, 0, TAU, 96, INK, 2.0)
	if state >= 1:
		var close := clampf(1.0 - absf(r - R0) / 120.0, 0.0, 1.0)
		draw_arc(c, r, 0, TAU, 96, Color(base.lightened(0.3), 0.6 + 0.4 * close), 8.0)
		draw_arc(c, r, 0, TAU, 96, INK, 2.0)
		if absf(r - R0) <= tol():
			draw_arc(c, R0, 0, TAU, 96, Color(1.0, 0.85, 0.5, 0.5), 16.0)
	var lbl: String = look[2]
	draw_string(Assets.font("title"), Vector2(c.x - 250, c.y + 12), "…" if state == 0 else lbl, HORIZONTAL_ALIGNMENT_CENTER, 500, 30, PAPER)
	if flash > 0.0:
		draw_arc(c, R0, 0, TAU, 96, Color(1.0, 0.8, 0.5, flash * 0.6), 30.0)
	draw_feedback(c + Vector2(0, -170))
