## HealthCurve — an adventurer's recorded health drawn over time (Living Workshop #38; data: HealthLog.points).
## EN: x = game time (day ticks), y = hit points; the maximum as a quiet dashed line (it rises with their level),
##     the recorded health as a line through the recorded points only — fights marked in red, a fall with a cross.
##     Nothing is drawn before the first recorded point; hover a point for its day, time, value and what it records.
## DA: Eventyrerens registrerede helbred over tid; kun registrerede punkter tegnes.
class_name HealthCurve
extends Control

const INK := Color("#20140c")
const HP := Color("#a8321e")
const FIGHT := Color("#7e2418")
const MAXC := Color(0.13, 0.08, 0.05, 0.45)

var pts: Array = []
var _hover := -1


func _init(points: Array, w := 560.0, h := 132.0) -> void:
	name = "HealthCurve"
	pts = points
	custom_minimum_size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_exited.connect(func():
		_hover = -1
		UIRoot.hide_tooltip()
		queue_redraw())


## The plotting area (left margin for the hp scale, bottom margin for the day ticks).
func _area() -> Rect2:
	return Rect2(Vector2(38, 6), size - Vector2(46, 28))


func _span() -> Vector2:
	var t0 := float(pts[0]["t"])
	var t1 := maxf(float(pts[-1]["t"]), float(Game.now()))
	if t1 - t0 < 1440.0:
		t1 = t0 + 1440.0   # at least a day wide, so a fresh record does not stretch into a wall
	return Vector2(t0, t1)


func _top() -> float:
	var m := 1.0
	for p in pts:
		m = maxf(m, maxf(float(p["max"]), float(p["hp"])))
	return m


func _pos(p: Dictionary, r: Rect2, sp: Vector2, top: float) -> Vector2:
	var x := r.position.x + (float(p["t"]) - sp.x) / maxf(1.0, sp.y - sp.x) * r.size.x
	var y := r.end.y - clampf(float(p["hp"]) / top, 0.0, 1.0) * r.size.y
	return Vector2(x, y)


func _draw() -> void:
	var r := _area()
	var f := Assets.font("body")
	draw_rect(r, Color(0.13, 0.08, 0.05, 0.05))
	draw_rect(r, Color(0.13, 0.08, 0.05, 0.35), false, 1.0)
	if pts.is_empty():
		draw_string(Assets.font("body_italic"), r.position + Vector2(10, r.size.y * 0.5 + 6), "Nothing recorded yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK, 0.6))
		return
	var sp := _span()
	var top := _top()
	# the hp scale: 0 and the top
	draw_string(f, Vector2(0, r.end.y + 5), "0", HORIZONTAL_ALIGNMENT_RIGHT, r.position.x - 6, 14, Color(INK, 0.7))
	draw_string(f, Vector2(0, r.position.y + 10), str(int(top)), HORIZONTAL_ALIGNMENT_RIGHT, r.position.x - 6, 14, Color(INK, 0.7))
	# day ticks
	var d0 := int(int(sp.x) / 1440) + 1
	var d1 := int(int(sp.y) / 1440) + 1
	var step := maxi(1, int(ceil(float(d1 - d0 + 1) / 8.0)))
	for d in range(d0, d1 + 1, step):
		var tx := r.position.x + (float((d - 1) * 1440) - sp.x) / maxf(1.0, sp.y - sp.x) * r.size.x
		if tx < r.position.x - 1.0 or tx > r.end.x + 1.0:
			continue
		draw_line(Vector2(tx, r.end.y), Vector2(tx, r.end.y + 4), Color(INK, 0.5), 1.0)
		draw_string(f, Vector2(tx - 30, r.end.y + 19), "day %d" % d, HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(INK, 0.75))
	# the maximum (dashed), as recorded at each point
	for i in range(1, pts.size()):
		var a := Vector2(_pos(pts[i - 1], r, sp, top).x, r.end.y - float(pts[i - 1]["max"]) / top * r.size.y)
		var b := Vector2(_pos(pts[i], r, sp, top).x, r.end.y - float(pts[i - 1]["max"]) / top * r.size.y)
		draw_dashed_line(a, b, MAXC, 1.0, 5.0)
	# the recorded health
	var line := PackedVector2Array()
	for p in pts:
		line.append(_pos(p, r, sp, top))
	if line.size() >= 2:
		draw_polyline(line, HP, 2.0, true)
	for i in pts.size():
		var p: Dictionary = pts[i]
		var c := line[i]
		match str(p["kind"]):
			"f", "a":
				draw_circle(c, 3.5 if i != _hover else 5.5, FIGHT)
			"x":
				draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), FIGHT, 2.0)
				draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), FIGHT, 2.0)
			_:
				draw_circle(c, 2.5 if i != _hover else 4.5, HP)


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseMotion) or pts.is_empty():
		return
	var r := _area()
	var sp := _span()
	var top := _top()
	var mp := (ev as InputEventMouseMotion).position
	var best := -1
	var bd := 18.0
	for i in pts.size():
		var d := _pos(pts[i], r, sp, top).distance_to(mp)
		if d < bd:
			bd = d
			best = i
	if best != _hover:
		_hover = best
		queue_redraw()
		if best < 0:
			UIRoot.hide_tooltip()
		else:
			var p: Dictionary = pts[best]
			var t := int(p["t"])
			UIRoot.show_tooltip("[b]Day %d, %02d:%02d[/b] — %d / %d hit points\n[i]%s[/i]" % [int(t / 1440) + 1, int((t % 1440) / 60), t % 60,
				int(p["hp"]), int(p["max"]), HealthLog.KIND_WORD.get(str(p["kind"]), "recorded")])
