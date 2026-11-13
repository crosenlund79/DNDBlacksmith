## VillageMapView — an ink-on-parchment drawing of Brindlewick (or of the building the smith stands in),
## used by the HUD minimap (compact) and the full village map panel.
## EN: Reads the live world (buildings, interactables, NPC figures, player) and data/layout.json
##     (roads, square, stream, exits). Redrawn a few times a second, never per frame.
## DA: En blæk-på-pergament-tegning af landsbyen (eller bygningen), til minikortet og kortpanelet.
class_name VillageMapView
extends Control

signal clicked
signal venue_clicked(id: String)   # the full map: a shop medallion was clicked (Venues)

const INK := Color("#20140c")
const PAPER := Color("#e9dcbc")
const RUBRIC := Color("#7e2418")
const GILT := Color("#b8923e")
const ROAD := Color("#b49466")
const WATER := Color("#7fa3b4")
const ROOF := Color("#cdb184")
const MEADOW := Color("#d3d2a0")
const WATER_LIGHT := Color("#b9d2d8")
const ROAD_LIGHT := Color("#d8c39a")
const FLOOR_COL := {"floor_soot": Color("#9c8a72"), "floor_wood": Color("#d2b07e"), "floor_stone": Color("#c8bea8"),
	"floor_slate": Color("#aab2b6"), "floor_herb": Color("#bfc79a"), "floor_arcane": Color("#b6a6c8"), "floor_tavern": Color("#c49a78")}
const ROOF_COL := {"slate": Color("#8a8f98"), "thatch": Color("#c9a35c"), "tile": Color("#a65a3c"), "": Color("#b07a4e")}
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
var show_venues := false       # the full map: a medallion for every shop and service (Venues)
var selected_venue := ""
var _venue_hits: Array = []    # [{pos (local), id}]
const VENUE_R := 17.0


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
		var vhit := venue_at((event as InputEventMouseButton).position)
		if vhit != "":
			venue_clicked.emit(vhit)
		else:
			clicked.emit()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and compact:
		Events.open_panel.emit("quick_travel", {})   # the minimap's right-click: quick travel
		accept_event()
	elif event is InputEventMouseMotion and not compact:
		var vh := venue_at((event as InputEventMouseMotion).position)
		if vh != "":
			_hover = -2
			UIRoot.show_tooltip("[b]%s[/b] — %s\n[i]%s · click for details[/i]" % [Venues.get_v(vh)["name"], Venues.get_v(vh)["type"], Venues.status_text(vh)])
			return
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
	_geo_build(w)
	# v1.7 (#68, #72): the village drawn like the world map — washed meadow, ink-crowned woods, wavy water, worn paths,
	# roofs you can tell apart, the watermill; names, exits, medallions, people and the smith as before
	var land := Rect2(m(Vector2.ZERO), Vector2(float(sz[0]), float(sz[1])) * T * _scale)
	draw_rect(land, MEADOW)
	for d in _geo["stipple"]:
		draw_circle(m(d[0]), maxf(0.6, 1.1 * _scale * 12.0) if not compact else 0.6, d[1])
	# water: the harbour, the ponds, the streams
	for poly: PackedVector2Array in _geo["pools"]:
		var mp := _mapped(poly)
		draw_colored_polygon(mp, Color(WATER, 0.95))
		var inner := PackedVector2Array()
		var c := Vector2.ZERO
		for q in mp:
			c += q
		c /= maxf(1.0, mp.size())
		for q in mp:
			inner.append(c + (q - c) * 0.72)
		draw_colored_polygon(inner, Color(WATER_LIGHT, 0.6))
		mp.append(mp[0])
		draw_polyline(mp, INK, 1.6 if compact else 2.2, true)
	for s in _geo["streams"]:
		var sp := _mapped(s[0])
		var sw := maxf(2.0, float(s[1]) * T * _scale)
		draw_polyline(sp, INK, sw + 2.4, true)
		draw_polyline(sp, WATER, sw, true)
		if not compact:
			draw_polyline(sp, Color(WATER_LIGHT, 0.8), maxf(1.0, sw * 0.28), true)
	# the square and the paths
	var sq: Dictionary = DB.layout.get("square", {})
	if not sq.is_empty():
		var sc := Vector2(float(sq["center"][0]), float(sq["center"][1])) * T
		var rad := Vector2(float(sq["radius"][0]), float(sq["radius"][1])) * T
		var poly2 := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			poly2.append(m(sc + Vector2(cos(a) * rad.x, sin(a) * rad.y) * (1.0 + 0.04 * sin(a * 5.0))))
		draw_colored_polygon(poly2, Color("#cdb994"))
		poly2.append(poly2[0])
		draw_polyline(poly2, Color(INK, 0.55), 1.3, true)
	for r in _geo["roads"]:
		var pts := _mapped(r[0])
		var wpx := maxf(2.0, float(r[1]) * T * _scale)
		draw_polyline(pts, Color(INK, 0.5), wpx + 2.2, true)
		draw_polyline(pts, ROAD, wpx, true)
		if not compact and wpx > 5.0:
			draw_polyline(pts, Color(ROAD_LIGHT, 0.55), wpx * 0.35, true)
	var st: Dictionary = DB.layout.get("stream", {})
	if not st.is_empty():
		var br: Array = st["bridge"]
		var a0 := m(Vector2(float(br[0][0]), float(br[0][1])) * T)
		var a1 := m(Vector2(float(br[1][0]), float(br[1][1])) * T)
		draw_rect(Rect2(a0, a1 - a0), Color("#8a6440"))
		draw_rect(Rect2(a0, a1 - a0), INK, false, 1.0)
	for dk in _geo["docks"]:
		var dr := Rect2(m((dk as Rect2).position), (dk as Rect2).size * _scale)
		draw_rect(dr, Color("#9a7448"))
		draw_rect(dr, INK, false, 1.0)
	# woods: ink-crowned trees, darker toward the edge
	for tr in _geo["trees"]:
		var tp0 := m(tr[0])
		var rr := maxf(1.6, float(tr[1]) * _scale)
		draw_circle(tp0 + Vector2(rr * 0.25, rr * 0.3), rr, Color(INK, 0.18))
		draw_circle(tp0, rr, tr[2])
		if rr > 3.0:
			draw_arc(tp0, rr, 0, TAU, 14, Color(INK, 0.75), 1.0, true)
			draw_arc(tp0 + Vector2(-rr * 0.25, -rr * 0.25), rr * 0.45, PI, TAU * 0.9, 8, Color(1, 1, 1, 0.22), 1.0, true)
	# buildings: roofs you can tell apart (slate, thatch, tile), a ridge and hips, a shadow; the forge in rubric
	var f := Assets.font("heading")
	for id in w.buildings:
		var b: Dictionary = w.buildings[id]
		if b.get("area", false):
			continue
		var r: Rect2 = b["rect"]
		var mr := Rect2(m(r.position), r.size * _scale)
		_roof(mr, str(DB.building(str(id)).get("roof", "")), str(DB.building(str(id)).get("ridge", "h")), id == "smithy")
		if not compact:
			var nm := str(b.get("name", id))
			var fs := 15
			var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := Vector2(mr.get_center().x - tw * 0.5, mr.position.y - 4.0) if mr.size.y < 60.0 else Vector2(mr.get_center().x - tw * 0.5, mr.position.y + 20.0)
			draw_string_outline(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(PAPER, 0.92))
			draw_string(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	_watermill_glyph()
	if not compact:
		_compass(Vector2(size.x - 70.0, size.y - 74.0), 38.0)
		_cartouche("Brindlewick")
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
			var lp := mp - dir * 30.0 + Vector2(-tw2 * 0.5, 6)
			if dir.x != 0.0:
				lp = Vector2(mp.x + 24.0 if dir.x < 0.0 else mp.x - 24.0 - tw2, mp.y - 16.0)
			lp.x = clampf(lp.x, 10.0, size.x - tw2 - 10.0)
			lp.y = clampf(lp.y, 24.0, size.y - 10.0)
			draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Color(PAPER, 0.95))
			draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, RUBRIC)
	if show_venues:
		_draw_venues(w)
	_draw_people(w, Rect2())
	_draw_player(w, "")


## Where a venue's medallion sits in world coordinates: on the lower edge of its building, else at its spot.
static func venue_world_pos(w: VillageWorld, id: String) -> Vector2:
	var v := Venues.get_v(id)
	var bid := str(v.get("building", ""))
	if bid != "" and w.buildings.has(bid) and not w.buildings[bid].get("area", false):
		# v1.7 #67: at the building's real entrance (its doorstep), not the middle of its south wall — the smithy's
		# door is in its north wall, so the old marker sat at the back of the building
		if w.spots.has(bid + "_door_out"):
			return w.spots[bid + "_door_out"]
		var r: Rect2 = w.buildings[bid]["rect"]
		return Vector2(r.get_center().x, r.end.y - 8.0)
	return w.spots.get(str(v.get("spot", "")), Vector2.INF)


func venue_at(local: Vector2) -> String:
	if not show_venues:
		return ""
	for h in _venue_hits:
		if local.distance_to(h["pos"]) < VENUE_R + 3.0:
			return str(h["id"])
	return ""


## Shop medallions: the venue's ink icon in a parchment disc, a gilt ring when open, dimmed with a rubric bar when
## closed or away; the selected one carries a pulsing rubric ring.
func _draw_venues(w: VillageWorld) -> void:
	_venue_hits.clear()
	for id: String in Venues.ids():
		var wp := venue_world_pos(w, id)
		if wp == Vector2.INF:
			continue
		var p := m(wp)
		var open := Venues.is_open(id)
		var sel := id == selected_venue
		if sel:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
			draw_circle(p, VENUE_R + 7.0 + pulse * 2.0, Color(RUBRIC, 0.25))
		draw_circle(p + Vector2(1.5, 2.0), VENUE_R + 1.0, Color(INK, 0.35))
		draw_circle(p, VENUE_R, Color("#f3e7c6") if open else Color("#cbbf9f"))
		var tex := Assets.get_tex("ui/qt_" + str(Venues.ICONS.get(id, "square")), Vector2i(96, 96))
		var s := VENUE_R * 1.55
		draw_texture_rect(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color.WHITE if open else Color(0.62, 0.58, 0.54))
		draw_arc(p, VENUE_R, 0, TAU, 32, INK, 2.0, true)
		draw_arc(p, VENUE_R - 2.5, 0, TAU, 32, GILT if open else Color(INK, 0.3), 1.4, true)
		if not open:
			draw_line(p + Vector2(-VENUE_R * 0.7, VENUE_R * 0.7), p + Vector2(VENUE_R * 0.7, -VENUE_R * 0.7), Color(RUBRIC, 0.85), 2.6, true)
		if sel:
			draw_arc(p, VENUE_R + 4.0, 0, TAU, 36, RUBRIC, 3.0, true)
		_venue_hits.append({"pos": p, "id": id})


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
	draw_rect(Rect2(m(r.position) + Vector2(3, 4), r.size * _scale), Color(INK, 0.22))
	draw_rect(Rect2(m(r.position), r.size * _scale), Color("#cdb68a"))
	var f := Assets.font("body_bold")
	var cur := w.room
	# v1.7 (#72): each room in the colour of its floor (soot, boards, flags, slate, herbs, the arcane vault), a faint
	# pattern of boards or flagstones, and double ink walls; the room you stand in is lighter with a rubric edge
	for rm in b.get("rooms", []):
		var rr: Rect2 = rm["rect"]
		var mr := Rect2(m(rr.position), rr.size * _scale)
		var flr := _room_floor(bid, str(rm["id"]), str(rm.get("floor", "")))
		var fc: Color = FLOOR_COL.get(flr, Color("#d9c39a"))
		if rm["id"] == cur:
			fc = fc.lightened(0.18)
		draw_rect(mr, fc)
		var boards := flr.contains("wood") or flr.contains("tavern")
		var step := maxf(4.0, 0.9 * T * _scale)
		if boards:
			var yy := mr.position.y + step
			while yy < mr.end.y - 1.0:
				draw_line(Vector2(mr.position.x + 1, yy), Vector2(mr.end.x - 1, yy), Color(INK, 0.12), 1.0)
				yy += step
		else:
			var yy2 := mr.position.y + step
			var row := 0
			while yy2 < mr.end.y - 1.0:
				draw_line(Vector2(mr.position.x + 1, yy2), Vector2(mr.end.x - 1, yy2), Color(INK, 0.1), 1.0)
				var xx := mr.position.x + (step if row % 2 == 0 else step * 0.5)
				while xx < mr.end.x - 1.0:
					draw_line(Vector2(xx, yy2 - step), Vector2(xx, yy2), Color(INK, 0.08), 1.0)
					xx += step
				yy2 += step
				row += 1
		if rm["id"] == cur:
			draw_rect(mr.grow(-2), Color(RUBRIC, 0.7), false, 1.6)
		draw_rect(mr, Color(INK, 0.85), false, 2.0 if not compact else 1.4)
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
				if compact:
					draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(GILT, 0.7))
				else:
					draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), GILT)
					draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), INK, false, 1.0)
					_markers.append({"pos": p, "name": str(e.get("label", e["id"])), "reason": ""})
			"stairs", "bed", "counter", "ledger":
				draw_circle(p, 3.0, Color(INK, 0.6))
	draw_rect(Rect2(m(r.position), r.size * _scale).grow(2.0), INK, false, 1.0)
	if not compact:
		var nm2 := str(b.get("name", bid))
		draw_string(Assets.font("heading"), Vector2(16, 30), nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	_floor_badge(bid)
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


# ======================================================================= v1.7 (#68, #72): the illustrated village
## Static drawing geometry in world pixels, built once from layout.json (trees, paths, water); only mapped per draw.
static var _geo := {}


func _geo_build(w: VillageWorld) -> void:
	if not _geo.is_empty():
		return
	var g := {"trees": [], "roads": [], "streams": [], "pools": [], "docks": [], "stipple": []}
	var sz: Array = DB.layout.get("size", [96, 64])
	var W := float(sz[0]) * T
	var H := float(sz[1]) * T
	for r in DB.layout.get("roads", []):
		(g["roads"] as Array).append([_smooth_w(r["points"]), float(r["width"])])
	for key in ["stream", "millstream"]:
		var s: Dictionary = DB.layout.get(key, {})
		if not s.is_empty():
			(g["streams"] as Array).append([_smooth_w(s["points"]), float(s["width"])])
	for key in ["pond", "millpond"]:
		var pd: Dictionary = DB.layout.get(key, {})
		if pd.is_empty():
			continue
		var c := Vector2(float(pd["center"][0]), float(pd["center"][1])) * T
		var rad := Vector2(float(pd["radius"][0]), float(pd["radius"][1])) * T
		var wob := float(pd.get("wobble", 0.06))
		var sd := float(pd.get("seed", 5))
		var poly := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			var k := 1.0 + wob * sin(a * 3.0 + sd) + wob * 0.6 * sin(a * 7.0 + sd * 2.0)
			poly.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * k)
		(g["pools"] as Array).append(poly)
		var jr: Array = pd.get("jetty", pd.get("dock", []))
		if jr.size() == 4:
			(g["docks"] as Array).append(Rect2(Vector2(float(jr[0]), float(jr[1])) * T, Vector2(float(jr[2]), float(jr[3])) * T))
	var hb: Dictionary = DB.layout.get("harbour", {})
	if not hb.is_empty():
		var hp := PackedVector2Array()
		for q in hb["water"]:
			hp.append(Vector2(float(q[0]), float(q[1])) * T)
		(g["pools"] as Array).append(hp)
	# where no tree may stand: buildings, paths, water, the square
	var blocked := func(p: Vector2) -> bool:
		for id in w.buildings:
			if not w.buildings[id].get("area", false) and (w.buildings[id]["rect"] as Rect2).grow(28.0).has_point(p):
				return true
		for r2 in g["roads"]:
			for q in r2[0]:
				if (q as Vector2).distance_to(p) < float(r2[1]) * T * 0.5 + 40.0:
					return true
		for s2 in g["streams"]:
			for q2 in s2[0]:
				if (q2 as Vector2).distance_to(p) < float(s2[1]) * T * 0.5 + 34.0:
					return true
		for pl in g["pools"]:
			if Geometry2D.is_point_in_polygon(p, pl):
				return true
		return false
	var greens := [Color("#6f8a4a"), Color("#5d7a3e"), Color("#7e9652"), Color("#4f6a36")]
	var depth := float(DB.layout.get("boundary", {}).get("depth", 3.6)) * T
	var step := 1.9 * T
	var y := -0.4 * T
	while y < H + 0.4 * T:
		var x := -0.4 * T
		while x < W + 0.4 * T:
			var h1 := _hash(x, y)
			var q := Vector2(x, y) + Vector2(h1 - 0.5, _hash(y, x) - 0.5) * step * 0.7
			var edge := minf(minf(q.x, W - q.x), minf(q.y, H - q.y))
			if edge < depth and h1 < 0.86 and not blocked.call(q):
				(g["trees"] as Array).append([q, T * (0.95 + 0.5 * _hash(q.y, q.x)), greens[int(h1 * 97.0) % greens.size()].darkened(0.12 * (1.0 - edge / depth))])
			x += step
		y += step
	for gr in DB.layout.get("groves", []):
		var gc := Vector2(float(gr[0]), float(gr[1])) * T
		var gR := float(gr[2]) * T
		var n := int(float(gr[3]) * PI * pow(float(gr[2]), 2) / 2.6) + 2
		for i in n:
			var a := _hash(gc.x + i, gc.y) * TAU
			var d := sqrt(_hash(gc.y + i * 3.0, gc.x)) * gR
			var q2 := gc + Vector2(cos(a), sin(a)) * d
			if not blocked.call(q2):
				(g["trees"] as Array).append([q2, T * (0.85 + 0.45 * _hash(q2.x, q2.y + 1.0)), greens[i % greens.size()]])
	for i in 900:   # the meadow's grain
		var sp := Vector2(_hash(i, 1.7) * W, _hash(2.3, i) * H)
		if not blocked.call(sp):
			(g["stipple"] as Array).append([sp, Color(0.36, 0.42, 0.18, 0.18 + 0.12 * _hash(i, i))])
	_geo = g


static func _hash(a: float, b: float) -> float:
	var s := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return s - floorf(s)


## A tile-space polyline smoothed (Catmull-Rom) into world pixels.
static func _smooth_w(points: Array) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for p in points:
		pts.append(Vector2(float(p[0]), float(p[1])) * T)
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) / 96.0))
		for k in n:
			var tt := float(k) / n
			var t2 := tt * tt
			var t3 := t2 * tt
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _mapped(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(m(q))
	return out


## A roof seen from above: its colour by kind, a ridge along the long side with hips to the corners, lit from the
## north-west, a shadow and an ink edge (the smith's own forge with a rubric line and a smoking chimney).
func _roof(mr: Rect2, kind: String, ridge: String, own: bool) -> void:
	var col: Color = ROOF_COL.get(kind, ROOF_COL[""])
	draw_rect(Rect2(mr.position + Vector2(2.5, 3.0), mr.size), Color(INK, 0.28))
	var horiz := ridge != "v" if mr.size.x != mr.size.y else true
	var inset := (mr.size.y if horiz else mr.size.x) * 0.5
	var c := mr.get_center()
	var r0 := Vector2(mr.position.x + inset, c.y) if horiz else Vector2(c.x, mr.position.y + inset)
	var r1 := Vector2(mr.end.x - inset, c.y) if horiz else Vector2(c.x, mr.end.y - inset)
	var tl := mr.position
	var tr := Vector2(mr.end.x, mr.position.y)
	var br := mr.end
	var bl := Vector2(mr.position.x, mr.end.y)
	if horiz:
		draw_colored_polygon(PackedVector2Array([tl, tr, r1, r0]), col.lightened(0.16))
		draw_colored_polygon(PackedVector2Array([bl, br, r1, r0]), col.darkened(0.08))
		draw_colored_polygon(PackedVector2Array([tl, r0, bl]), col.lightened(0.05))
		draw_colored_polygon(PackedVector2Array([tr, r1, br]), col.darkened(0.16))
	else:
		draw_colored_polygon(PackedVector2Array([tl, bl, r1, r0]), col.lightened(0.16))
		draw_colored_polygon(PackedVector2Array([tr, br, r1, r0]), col.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([tl, tr, r0]), col.lightened(0.05))
		draw_colored_polygon(PackedVector2Array([bl, br, r1]), col.darkened(0.16))
	var lw := 1.0 if compact else 1.4
	draw_line(r0, r1, INK, lw + 0.4, true)
	for k in [[tl, r0], [bl, r0], [tr, r1], [br, r1]]:
		draw_line(k[0], k[1], Color(INK, 0.55), lw * 0.8, true)
	draw_rect(mr, INK, false, 2.2 if own else 1.4)
	if own:
		draw_rect(mr.grow(-3.0), RUBRIC, false, 1.1)
		var ch := mr.position + Vector2(mr.size.x * 0.12, mr.size.y * 0.16)
		var cs := maxf(3.0, mr.size.x * 0.06)
		draw_rect(Rect2(ch, Vector2(cs, cs)), Color("#6e665c"))
		draw_rect(Rect2(ch, Vector2(cs, cs)), INK, false, 1.0)
		if not compact:
			for i in 3:
				draw_arc(ch + Vector2(cs * 0.5 + i * 5.0, -6.0 - i * 7.0), 4.0 + i * 1.5, PI * 0.2, PI * 1.4, 8, Color(0.4, 0.38, 0.36, 0.45 - i * 0.1), 1.4, true)


## The watermill: a small thatched house on the bank and its wheel in the millstream.
func _watermill_glyph() -> void:
	var wm: Dictionary = DB.layout.get("watermill", {})
	if wm.is_empty():
		return
	var hp := Vector2(float(wm["pos"][0]), float(wm["pos"][1])) * T
	var mr := Rect2(m(hp - Vector2(80, 66)), Vector2(160, 132) * _scale)
	_roof(mr, "thatch", "h", false)
	var wp := m(Vector2(float(wm["wheel"][0]), float(wm["wheel"][1])) * T)
	var wr := maxf(3.0, 52.0 * _scale)
	draw_circle(wp, wr, Color("#8a6440"))
	draw_arc(wp, wr, 0, TAU, 18, INK, 1.4, true)
	var spin := Time.get_ticks_msec() / 1400.0
	for k in 4:
		var a := spin + k * PI / 4.0
		draw_line(wp - Vector2(cos(a), sin(a)) * wr, wp + Vector2(cos(a), sin(a)) * wr, INK, 1.0, true)
	if not compact:
		var f := Assets.font("heading_italic")
		draw_string_outline(f, mr.position + Vector2(-4, mr.size.y + 16), "the mill", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(PAPER, 0.9))
		draw_string(f, mr.position + Vector2(-4, mr.size.y + 16), "the mill", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


## A compass rose in the corner, as on the world map.
func _compass(c: Vector2, r: float) -> void:
	draw_circle(c, r * 0.62, Color(PAPER, 0.85))
	draw_arc(c, r * 0.62, 0, TAU, 32, INK, 1.4, true)
	draw_arc(c, r * 0.5, 0, TAU, 32, Color(GILT, 0.9), 1.0, true)
	for k in 4:
		var a := k * PI / 2.0 - PI / 2.0
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([c + d * r, c + s * r * 0.16, c - d * r * 0.18, c - s * r * 0.16])
		draw_colored_polygon(pts, RUBRIC if k == 0 else INK)
	var f := Assets.font("heading")
	draw_string(f, c + Vector2(-5, -r - 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RUBRIC)


## The village's name in a little cartouche, top left.
func _cartouche(name: String) -> void:
	var f := Assets.font("heading")
	var fs := 24
	var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(22, 18), Vector2(tw + 40, 38))
	draw_rect(r, Color(PAPER, 0.92))
	draw_rect(r, INK, false, 1.6)
	draw_rect(r.grow(-4), Color(GILT, 0.9), false, 1.0)
	draw_string(f, r.position + Vector2(20, 27), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


## In the smithy, which floor you are on: "Ground · Loft · Cellar" with yours marked (only the floors he has).
func _floor_badge(bid: String) -> void:
	var here := ""
	for fl in Property.floors():
		if str(fl.get("area", Property.BID)) == bid:
			here = str(fl["id"])
	if here == "":
		return
	var names := []
	for fl in Property.floors():
		if Property.floor_owned(str(fl["id"])):
			var nm: String = {"ground": "Ground", "loft": "Loft", "basement": "Cellar"}.get(str(fl["id"]), str(fl.get("name", fl["id"])))
			names.append(("▸" + nm) if str(fl["id"]) == here else nm)
	if names.size() < 2:
		return
	var f := Assets.font("heading_italic")
	var fs := 12 if compact else 16
	var txt := "  ·  ".join(names)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(size.x - tw - 14.0, size.y - 10.0) if compact else Vector2(size.x - tw - 22.0, 30.0)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(PAPER, 0.95))
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RUBRIC)


## A room's floor material from the layout data (the world's room records carry only id, name and rect): the smith's
## plan for the smithy's floors, the building or area record for the rest.
static func _room_floor(bid: String, rid: String, known := "") -> String:
	if known != "":
		return known
	if bid == Property.BID or bid.begins_with("smithy_"):
		var r := Property.room_by_id(Property.rooms(), rid)
		if not r.is_empty():
			return str(r.get("floor", ""))
	var src: Dictionary = DB.building(bid)
	if src.is_empty():
		for a in DB.layout.get("areas", []):
			if str(a["id"]) == bid:
				src = a
	for r2 in src.get("rooms", []):
		if str(r2["id"]) == rid:
			return str(r2.get("floor", src.get("floor", "")))
	return str(src.get("floor", ""))

