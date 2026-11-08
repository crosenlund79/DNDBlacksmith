## VillageMapView — an ink-on-parchment drawing of Brindlewick (or of the building the smith stands in),
## used by the HUD minimap (compact) and the full village map panel.
## EN: Reads the live world (buildings, interactables, NPC figures, player) and data/layout.json
##     (roads, square, stream, exits). Redrawn a few times a second, never per frame.
## DA: En blæk-på-pergament-tegning af landsbyen (eller bygningen), til minikortet og kortpanelet.
class_name VillageMapView
extends Control

signal clicked

const INK := Color("#20140c")
const PAPER := Color("#e9dcbc")
const RUBRIC := Color("#7e2418")
const GILT := Color("#b8923e")
const ROAD := Color("#b49466")
const WATER := Color("#7fa3b4")
const ROOF := Color("#cdb184")
const COL_ADV := Color("#7e2418")
const COL_HIRE := Color("#2d5a78")
const COL_CUST := Color("#c08a1e")
const COL_VILL := Color("#5e4c38")
const T := 64.0

var compact := true            # minimap: fewer labels, only relevant people
var force_village := false     # the full map always shows the village
var hz := 4.0
var _acc := 0.0
var _scale := 1.0
var _off := Vector2.ZERO
var _view := Rect2()
var _markers: Array = []       # [{pos (local), name, reason}] for hover
var _hover := -1
var markers_cache := {}


func _init(is_compact := true) -> void:
	compact = is_compact
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _ready() -> void:
	mouse_exited.connect(func():
		_hover = -1
		UIRoot.hide_tooltip())
	queue_redraw()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / hz:
		_acc = 0.0
		queue_redraw()


func world() -> VillageWorld:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("world") as VillageWorld


## Which building interior to draw ("" = the village).
func interior_id() -> String:
	var w := world()
	if w == null or force_village:
		return ""
	return w.area if w.area != "village" and w.buildings.has(w.area) else ""


func _fit(r: Rect2, margin := 10.0) -> void:
	_view = r
	var avail := size - Vector2(margin, margin) * 2.0
	_scale = minf(avail.x / maxf(1.0, r.size.x), avail.y / maxf(1.0, r.size.y))
	_off = (size - r.size * _scale) * 0.5 - r.position * _scale


func m(p: Vector2) -> Vector2:
	return _off + p * _scale


## Map position (local) -> world position.
func to_world(local: Vector2) -> Vector2:
	return (local - _off) / maxf(0.0001, _scale)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()
	elif event is InputEventMouseMotion and not compact:
		var best := -1
		var bd := 16.0
		for i in _markers.size():
			var d := (event as InputEventMouseMotion).position.distance_to(_markers[i]["pos"])
			if d < bd:
				bd = d
				best = i
		if best != _hover:
			_hover = best
			if best >= 0:
				var mk: Dictionary = _markers[best]
				UIRoot.show_tooltip("[b]%s[/b]%s" % [mk["name"], ("\n[color=#ffd890]“%s”[/color]" % mk["reason"]) if str(mk.get("reason", "")) != "" else ""])
			else:
				UIRoot.hide_tooltip()
			queue_redraw()


# ======================================================================= drawing
func _draw() -> void:
	_markers.clear()
	var w := world()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_paper_grain()
	if w == null or DB.layout.is_empty():
		_frame()
		return
	markers_cache = TalkMarkers.all()
	var bid := interior_id()
	if bid != "":
		_draw_interior(w, bid)
	else:
		_draw_village(w)
	_frame()


func _paper_grain() -> void:
	# a few faint ruled lines and a burnt edge give the minimap its parchment feel
	var c := Color(0.36, 0.24, 0.1, 0.06)
	var y := 6.0
	while y < size.y:
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), c, 1.0)
		y += 9.0
	for i in 6:
		draw_rect(Rect2(Vector2(i, i), size - Vector2(i, i) * 2.0), Color(0.36, 0.2, 0.06, 0.07), false, 1.0)


func _frame() -> void:
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), INK, false, 3.0)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), GILT, false, 1.0)


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(m(Vector2(float(p[0]), float(p[1])) * T))
	return out


func _draw_village(w: VillageWorld) -> void:
	var sz: Array = DB.layout.get("size", [96, 64])
	_fit(Rect2(0, 0, float(sz[0]) * T, float(sz[1]) * T), 8.0 if compact else 14.0)
	draw_rect(Rect2(m(Vector2.ZERO), Vector2(float(sz[0]), float(sz[1])) * T * _scale), Color(0.62, 0.66, 0.42, 0.22))
	# square, roads, stream
	var sq: Dictionary = DB.layout.get("square", {})
	if not sq.is_empty():
		var c := Vector2(float(sq["center"][0]), float(sq["center"][1])) * T
		var rad := Vector2(float(sq["radius"][0]), float(sq["radius"][1])) * T
		var poly := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			poly.append(m(c + Vector2(cos(a) * rad.x, sin(a) * rad.y)))
		draw_colored_polygon(poly, Color("#c8b48c"))
		poly.append(poly[0])
		draw_polyline(poly, Color(INK, 0.6), 1.2, true)
	for r in DB.layout.get("roads", []):
		var pts := _pts(r["points"])
		var wpx := maxf(2.0, float(r["width"]) * T * _scale)
		draw_polyline(pts, Color(INK, 0.55), wpx + 2.0, true)
		draw_polyline(pts, ROAD, wpx, true)
	var st: Dictionary = DB.layout.get("stream", {})
	if not st.is_empty():
		var sp := _pts(st["points"])
		var sw := maxf(2.0, float(st["width"]) * T * _scale)
		draw_polyline(sp, INK, sw + 2.0, true)
		draw_polyline(sp, WATER, sw, true)
		var br: Array = st["bridge"]
		var a0 := m(Vector2(float(br[0][0]), float(br[0][1])) * T)
		var a1 := m(Vector2(float(br[1][0]), float(br[1][1])) * T)
		draw_rect(Rect2(a0, a1 - a0), Color("#8a6440"))
		draw_rect(Rect2(a0, a1 - a0), INK, false, 1.0)
	# buildings
	var f := Assets.font("heading")
	for id in w.buildings:
		var b: Dictionary = w.buildings[id]
		if b.get("area", false):
			continue
		var r: Rect2 = b["rect"]
		var mr := Rect2(m(r.position), r.size * _scale)
		draw_rect(Rect2(mr.position + Vector2(2, 2), mr.size), Color(INK, 0.25))
		draw_rect(mr, Color("#d9c08c") if id != "smithy" else Color("#e0b27a"))
		_hatch(mr, Color(INK, 0.12))
		draw_rect(mr, INK, false, 2.0 if id == "smithy" else 1.4)
		if id == "smithy":
			draw_rect(mr.grow(-3), RUBRIC, false, 1.0)
		if not compact:
			var nm := str(b.get("name", id))
			var fs := 15
			var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := mr.get_center() + Vector2(-tw * 0.5, 5)
			draw_string_outline(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(PAPER, 0.92))
			draw_string(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	# exits
	for ex in DB.layout.get("exits", []):
		var p := Vector2(float(ex["pos"][0]) + 0.5, float(ex["pos"][1]) + 0.5) * T
		var mp := m(p)
		var dir := Vector2.ZERO
		match str(ex["id"]):
			"west": dir = Vector2.LEFT
			"east": dir = Vector2.RIGHT
			"north": dir = Vector2.UP
			_: dir = Vector2.DOWN
		_arrow(mp - dir * 4.0, dir, 8.0 if compact else 12.0, RUBRIC)
		if not compact:
			var label := str(ex.get("label", ex["id"]))
			var fs2 := 16
			var tw2 := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var lp := mp - dir * 26.0 + Vector2(-tw2 * 0.5, 6)
			lp.x = clampf(lp.x, 10.0, size.x - tw2 - 10.0)
			lp.y = clampf(lp.y, 24.0, size.y - 10.0)
			draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Color(PAPER, 0.95))
			draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, RUBRIC)
	_draw_people(w, Rect2())
	_draw_player(w, "")


func _hatch(r: Rect2, col: Color) -> void:
	var step := 5.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(x, r.end.y)
		var b := Vector2(x + r.size.y, r.position.y)
		# clip the diagonal to the rect
		if a.x < r.position.x:
			a = Vector2(r.position.x, r.end.y - (r.position.x - x))
		if b.x > r.end.x:
			b = Vector2(r.end.x, r.position.y + (b.x - r.end.x))
		draw_line(a, b, col, 1.0)
		x += step


func _draw_interior(w: VillageWorld, bid: String) -> void:
	var b: Dictionary = w.buildings[bid]
	var r: Rect2 = b["rect"]
	_fit(r.grow(40), 10.0)
	draw_rect(Rect2(m(r.position), r.size * _scale), Color("#d6c094"))
	var f := Assets.font("body_bold")
	var cur := w.room
	for rm in b.get("rooms", []):
		var rr: Rect2 = rm["rect"]
		var mr := Rect2(m(rr.position), rr.size * _scale)
		draw_rect(mr, Color("#ead7a8") if rm["id"] == cur else Color("#d9c39a"))
		if rm["id"] == cur:
			draw_rect(mr.grow(-2), Color(RUBRIC, 0.6), false, 1.5)
		draw_rect(mr, Color(INK, 0.75), false, 1.2)
		var nm := str(rm.get("name", rm["id"]))
		var fs := 11 if compact else 15
		var tsz := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		if tsz.x < mr.size.x - 4 and tsz.y < mr.size.y - 2:
			var tp := mr.position + Vector2((mr.size.x - tsz.x) * 0.5, mr.size.y * 0.5 + fs * 0.35)
			draw_string(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, 0.8))
	draw_rect(Rect2(m(r.position), r.size * _scale), INK, false, 3.0)
	# stations and other fixtures
	for e in w.interactables:
		if not r.has_point(e["pos"]):
			continue
		var p := m(e["pos"])
		match str(e["kind"]):
			"station":
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), GILT)
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), INK, false, 1.0)
				if not compact:
					_markers.append({"pos": p, "name": str(e.get("label", e["id"])), "reason": ""})
			"stairs", "bed", "counter", "ledger":
				draw_circle(p, 3.0, Color(INK, 0.6))
	if not compact:
		var nm2 := str(b.get("name", bid))
		draw_string(Assets.font("heading"), Vector2(16, 30), nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	_draw_people(w, r)
	_draw_player(w, bid)


func _kind_of(id: String) -> String:
	for c in Shop.customers():
		if c["npc"] == id:
			return "customer"
	if not Hire.get_h(id).is_empty():
		return "hireling"
	if not Adv.get_a(id).is_empty():
		return "adventurer"
	return "villager"


static func color_of(kind: String) -> Color:
	match kind:
		"customer": return COL_CUST
		"hireling": return COL_HIRE
		"adventurer": return COL_ADV
	return COL_VILL


func _draw_people(w: VillageWorld, inside: Rect2) -> void:
	var talk_later := []
	for id in w.npcs:
		var n: NPCActor = w.npcs[id]
		if not n.visible:
			continue
		if inside.size != Vector2.ZERO and not inside.has_point(n.position):
			continue
		var kind := _kind_of(id)
		var reason := str(markers_cache.get(id, ""))
		if compact and kind == "villager" and reason == "" and inside.size == Vector2.ZERO:
			continue
		var p := m(n.position)
		if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
			continue
		var rad := 3.2 if compact else 5.0
		draw_symbol(self, kind, p, rad)
		_markers.append({"pos": p, "name": str(n.display_name), "reason": reason, "kind": kind})
		if reason != "":
			talk_later.append(p)
		if _hover >= 0 and _hover == _markers.size() - 1:
			draw_arc(p, rad + 4.0, 0, TAU, 20, RUBRIC, 2.0)
	for p in talk_later:
		draw_symbol(self, "talk", p + Vector2(0, -(8.0 if compact else 13.0)), 6.0 if compact else 8.0)


func _draw_player(w: VillageWorld, bid: String) -> void:
	var pos := w.player.position
	if bid == "" and w.area != "village" and w.buildings.has(w.area) and w.buildings[w.area].get("area", false):
		# upstairs rooms live outside the village map: mark the inn instead
		pos = (w.buildings.get("inn", {}).get("rect", Rect2(pos, Vector2.ZERO)) as Rect2).get_center()
	var p := m(pos)
	var dir := w.player.facing_vector()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var s := 7.0 if compact else 11.0
	draw_circle(p, s + 3.0, Color(Color("#ffc070"), 0.35))
	_arrow(p - dir * s * 0.3, dir, s, Color("#e6702a"))


func _arrow(p: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([p + dir * s, p - dir * s * 0.6 + side * s * 0.7, p - dir * s * 0.25, p - dir * s * 0.6 - side * s * 0.7])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, INK, 1.5, true)


## Shared marker drawing (also used by the map legend).
static func draw_symbol(ci: CanvasItem, kind: String, p: Vector2, r: float) -> void:
	match kind:
		"talk":
			var rr := Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6))
			ci.draw_rect(rr, Color("#f6ecd0"))
			ci.draw_colored_polygon(PackedVector2Array([rr.position + Vector2(r * 0.5, rr.size.y), rr.position + Vector2(r * 1.1, rr.size.y), rr.position + Vector2(r * 0.4, rr.size.y + r * 0.6)]), Color("#f6ecd0"))
			ci.draw_rect(rr, INK, false, 1.2)
			ci.draw_line(p + Vector2(0, -r * 0.5), p + Vector2(0, r * 0.15), RUBRIC, maxf(1.5, r * 0.28))
			ci.draw_circle(p + Vector2(0, r * 0.45), maxf(0.9, r * 0.14), RUBRIC)
		"player":
			var side := Vector2(1, 0)
			var pts := PackedVector2Array([p + Vector2(0, -r), p + side * r * 0.7 + Vector2(0, r * 0.6), p + Vector2(0, r * 0.25), p - side * r * 0.7 + Vector2(0, r * 0.6)])
			ci.draw_colored_polygon(pts, Color("#e6702a"))
			pts.append(pts[0])
			ci.draw_polyline(pts, INK, 1.5, true)
		"building":
			ci.draw_rect(Rect2(p - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), Color("#d9c08c"))
			ci.draw_rect(Rect2(p - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), INK, false, 1.4)
		"exit":
			var pts2 := PackedVector2Array([p + Vector2(r, 0), p + Vector2(-r * 0.6, r * 0.7), p + Vector2(-r * 0.25, 0), p + Vector2(-r * 0.6, -r * 0.7)])
			ci.draw_colored_polygon(pts2, RUBRIC)
		"station":
			ci.draw_rect(Rect2(p - Vector2(r * 0.6, r * 0.6), Vector2(r * 1.2, r * 1.2)), GILT)
			ci.draw_rect(Rect2(p - Vector2(r * 0.6, r * 0.6), Vector2(r * 1.2, r * 1.2)), INK, false, 1.0)
		"road":
			ci.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), ROAD, r * 0.8)
		"water":
			ci.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), WATER, r * 0.8)
		_:
			ci.draw_circle(p, r + 1.2, INK)
			ci.draw_circle(p, r, color_of(kind))
