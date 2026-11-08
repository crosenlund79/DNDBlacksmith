## World — builds and runs the playable village of Brindlewick from data/layout.json.
## EN: Modular, transparent sprites on textured ground (not a flattened illustration): roads and
##     plazas are textured lines/polygons, buildings have walls with doorways, furnished interiors
##     and roofs that fade when you step inside (top-down occlusion). Actors and props are Y-sorted.
##     NPCs follow schedules over an AStar2D waypoint graph; lighting follows the in-game clock.
## DA: Modulære, gennemsigtige sprites på teksturerede flader (ikke én flad illustration): veje og
##     pladser er teksturerede linjer/polygoner, bygninger har mure med døråbninger, møblerede
##     interiører og tage, der fader ud, når man går ind. Figurer og rekvisitter Y-sorteres.
##     Personer følger skemaer over et AStar2D-vejnet; lyset følger spillets ur.
class_name VillageWorld
extends Node2D

const T := 64.0
const WALL := 22.0
const INK := Color("#20140c")

var ground_layer: Node2D
var floor_layer: Node2D
var ysort: Node2D
var roof_layer: Node2D
var canvas_mod: CanvasModulate
var player: PlayerBody
var camera: Camera2D

var astar := AStar2D.new()
var spots := {}            # name -> Vector2
var spot_ids := {}         # name -> astar id
var interactables: Array = []   # {pos, r, kind, id, label}
var buildings := {}        # id -> {rect, roof, alpha, kind}
var npcs := {}             # id -> NPC node
var night_lights: Array = []
var station_sprites := {}
var area := "village"
var _bag_nodes: Array = []
var _eggs_node: Node2D
var _focus: Dictionary = {}
var _next_point := 0
var _room_doors: Array = []
var room := ""
var _marker: Sprite2D



func _ready() -> void:
	add_to_group("world")
	ground_layer = Node2D.new()
	ground_layer.z_index = -20
	add_child(ground_layer)
	floor_layer = Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	roof_layer = Node2D.new()
	roof_layer.z_index = 40
	add_child(roof_layer)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_build_ground()
	_build_roads()
	_build_stream()
	for b in DB.layout.get("buildings", []):
		_build_building(b, false)
	for a in DB.layout.get("areas", []):
		_build_building(a, true)
	_furnish()
	_build_stations()
	_build_outdoors()
	_build_atmosphere()
	_build_nav()
	_spawn_player()
	_spawn_npcs()
	_spawn_animals()
	_refresh_bags()
	_refresh_display()
	_refresh_eggs()
	Events.hour_passed.connect(func(_d, _h): _update_schedules())
	Events.adventurer_departed.connect(_on_departed)
	Events.hireling_departed.connect(_on_departed)
	Events.adventurer_returned.connect(_on_returned)
	Events.hireling_returned.connect(_on_returned)
	Events.world_flag_changed.connect(_on_flag)
	Events.inventory_changed.connect(_refresh_bags)
	Events.inventory_changed.connect(_refresh_display)
	Events.day_started.connect(func(_d): _refresh_bags())
	_update_schedules(true)
	_update_light(true)


func _on_flag(f: String) -> void:
	if f in ["eggs", "delivery"]:
		_refresh_eggs()
		_update_schedules()


# ======================================================================= helpers
func tp(v: Variant) -> Vector2:
	return Vector2(float(v[0]) * T, float(v[1]) * T)


func brect(b: Dictionary) -> Rect2:
	var r: Array = b["rect"]
	return Rect2(float(r[0]) * T, float(r[1]) * T, float(r[2]) * T, float(r[3]) * T)


func bpos(bid: String, rx: float, ry: float) -> Vector2:
	var r := brect(DB.building(bid))
	return r.position + Vector2(rx * T, ry * T)


func _tex_poly(points: PackedVector2Array, tex_id: String, parent: Node, tint := Color.WHITE) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.texture = Assets.get_tex("textures/" + tex_id, Vector2i(256, 256))
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.color = tint
	parent.add_child(p)
	return p


func _outline(points: PackedVector2Array, width: float, parent: Node, color := INK, closed := true) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.width = width
	l.default_color = color
	l.closed = closed
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)
	return l


func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.position = r.get_center()
	body.add_child(cs)
	add_child(body)


func _smooth(points: Array, step := 48.0) -> PackedVector2Array:
	# Catmull-Rom densification of a tile-space polyline into pixels
	var pts: Array[Vector2] = []
	for p in points:
		pts.append(tp(p))
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[max(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[min(i + 2, pts.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) / step))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _add_interactable(pos: Vector2, r: float, kind: String, id: String, label: String) -> Dictionary:
	var e := {"pos": pos, "r": r, "kind": kind, "id": id, "label": label}
	interactables.append(e)
	return e


# ======================================================================= ground & roads
func _build_ground() -> void:
	var size: Array = DB.layout.get("size", [96, 64])
	var s := Sprite2D.new()
	s.texture = Assets.get_tex("textures/grass", Vector2i(256, 256))
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(-512, -512, float(size[0]) * T + 1024, float(size[1]) * T + 1024)
	s.centered = false
	s.position = Vector2(-512, -512)
	ground_layer.add_child(s)
	# map border walls (exits stay open)
	var w := float(size[0]) * T
	var h := float(size[1]) * T
	for r in [Rect2(-64, -64, w * 0.5 + 64 - 3 * T, 64), Rect2(w * 0.5 + 3 * T + 0.0, -64, w, 64)]:
		_solid(r)
	_solid(Rect2(-64, h, w + 128, 64))
	_solid(Rect2(-64, -64, 64, h * 0.5))
	_solid(Rect2(-64, h * 0.5 + 3 * T, 64, h))
	_solid(Rect2(w, -64, 64, h * 0.5 + 64 - 2 * T))
	_solid(Rect2(w, h * 0.5 + 2 * T, 64, h))


func _build_roads() -> void:
	for r in DB.layout.get("roads", []):
		var pts := _smooth(r["points"])
		var wpx := float(r["width"]) * T
		var edge := Line2D.new()
		edge.points = pts
		edge.width = wpx + 8
		edge.default_color = Color(0.13, 0.08, 0.05, 0.45)
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		ground_layer.add_child(edge)
		var road := Line2D.new()
		road.points = pts
		road.width = wpx
		road.texture = Assets.get_tex("textures/dirt_road", Vector2i(256, 256))
		road.texture_mode = Line2D.LINE_TEXTURE_TILE
		road.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		road.joint_mode = Line2D.LINE_JOINT_ROUND
		road.begin_cap_mode = Line2D.LINE_CAP_ROUND
		road.end_cap_mode = Line2D.LINE_CAP_ROUND
		ground_layer.add_child(road)
	var sq: Dictionary = DB.layout.get("square", {})
	if not sq.is_empty():
		var c := tp(sq["center"])
		var rad := tp(sq["radius"])
		var poly := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			var wob := 1.0 + 0.04 * sin(a * 5.0)
			poly.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * wob)
		_tex_poly(poly, "cobble", ground_layer)
		_outline(poly, 3.0, ground_layer, Color(0.13, 0.08, 0.05, 0.7))


func _build_stream() -> void:
	var st: Dictionary = DB.layout.get("stream", {})
	if st.is_empty():
		return
	var pts := _smooth(st["points"])
	var wpx := float(st["width"]) * T
	var bank := Line2D.new()
	bank.points = pts
	bank.width = wpx + 10
	bank.default_color = INK
	ground_layer.add_child(bank)
	var water := Line2D.new()
	water.points = pts
	water.width = wpx
	water.texture = Assets.get_tex("textures/water", Vector2i(256, 256))
	water.texture_mode = Line2D.LINE_TEXTURE_TILE
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_layer.add_child(water)
	var br: Array = st["bridge"]
	var r := Rect2(tp(br[0]), tp(br[1]) - tp(br[0]))
	_tex_poly(_rect_pts(r), "floor_wood", floor_layer)
	_outline(_rect_pts(r), 3.0, floor_layer)
	for yy in [r.position.y + 4, r.end.y - 4]:
		_outline(PackedVector2Array([Vector2(r.position.x, yy), Vector2(r.end.x, yy)]), 7.0, floor_layer, Color("#5a3e26"), false)
	# collision along the stream except across the bridge
	for i in pts.size() - 1:
		var p := pts[i]
		if p.y > r.position.y - 24 and p.y < r.end.y + 24:
			continue
		_solid(Rect2(p - Vector2(wpx * 0.4, 20), Vector2(wpx * 0.8, 40)))


# ======================================================================= buildings
func _wall_segments(r: Rect2, doors: Array, skip_sides := []) -> Array:
	var segs := []
	for side in ["n", "s", "w", "e"]:
		if skip_sides.has(side):
			continue
		var horiz: bool = side in ["n", "s"]
		var length := r.size.x if horiz else r.size.y
		var cuts := []
		for d in doors:
			if d["side"] == side:
				cuts.append([float(d["at"]) * T, float(d["at"] + d["w"]) * T])
		cuts.sort_custom(func(a, b): return a[0] < b[0])
		var start := 0.0
		var pieces := []
		for c in cuts:
			if c[0] > start:
				pieces.append([start, c[0]])
			start = c[1]
		if start < length:
			pieces.append([start, length])
		for pc in pieces:
			var a: float = pc[0]
			var b: float = pc[1]
			var seg: Rect2
			match side:
				"n": seg = Rect2(r.position.x + a, r.position.y, b - a, WALL)
				"s": seg = Rect2(r.position.x + a, r.end.y - WALL, b - a, WALL)
				"w": seg = Rect2(r.position.x, r.position.y + a, WALL, b - a)
				"e": seg = Rect2(r.end.x - WALL, r.position.y + a, WALL, b - a)
			segs.append(seg)
	return segs


func _draw_walls(segs: Array, tex: String) -> void:
	# lime-plaster partitions are pale: tone them down and ink them harder so rooms read clearly
	var tint := Color(0.74, 0.68, 0.6) if tex == "wall_plaster" else Color.WHITE
	for s in segs:
		var pts := _rect_pts(s)
		_tex_poly(pts, tex, floor_layer, tint)
		_outline(pts, 3.5 if tex == "wall_plaster" else 2.5, floor_layer)
		_solid(s)


func _room_rect(r: Rect2, room: Dictionary) -> Rect2:
	var rr: Array = room["rect"]
	return Rect2(r.position + Vector2(float(rr[0]), float(rr[1])) * T, Vector2(float(rr[2]), float(rr[3])) * T)


## Interior walls: one wall per shared edge between two rooms, with gaps for the doors between them.
func _interior_walls(b: Dictionary, r: Rect2) -> void:
	var rooms: Array = b.get("rooms", [])
	var doors: Array = b.get("room_doors", [])
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a: Array = rooms[i]["rect"]
			var c: Array = rooms[j]["rect"]
			var ax0 := float(a[0]); var ay0 := float(a[1]); var ax1 := ax0 + float(a[2]); var ay1 := ay0 + float(a[3])
			var cx0 := float(c[0]); var cy0 := float(c[1]); var cx1 := cx0 + float(c[2]); var cy1 := cy0 + float(c[3])
			var vertical := false
			var line := 0.0
			var lo := 0.0
			var hi := 0.0
			if is_equal_approx(ax1, cx0) or is_equal_approx(cx1, ax0):
				vertical = true
				line = ax1 if is_equal_approx(ax1, cx0) else ax0
				lo = maxf(ay0, cy0)
				hi = minf(ay1, cy1)
			elif is_equal_approx(ay1, cy0) or is_equal_approx(cy1, ay0):
				line = ay1 if is_equal_approx(ay1, cy0) else ay0
				lo = maxf(ax0, cx0)
				hi = minf(ax1, cx1)
			else:
				continue
			if hi - lo < 0.5:
				continue
			# door gaps on this edge
			var gaps := []
			for d in doors:
				var pair: Array = d["between"]
				if (pair[0] == rooms[i]["id"] and pair[1] == rooms[j]["id"]) or (pair[1] == rooms[i]["id"] and pair[0] == rooms[j]["id"]):
					gaps.append([float(d["at"]), float(d["at"]) + float(d["w"])])
					var dc := r.position + (Vector2(line, float(d["at"]) + float(d["w"]) * 0.5) if vertical else Vector2(float(d["at"]) + float(d["w"]) * 0.5, line)) * T
					_room_doors.append({"b": b["id"], "pos": dc, "vertical": vertical, "a": rooms[i]["id"], "c": rooms[j]["id"]})
			gaps.sort_custom(func(x, y): return x[0] < y[0])
			var start := lo
			var pieces := []
			for g in gaps:
				if g[0] > start:
					pieces.append([start, g[0]])
				start = maxf(start, g[1])
			if start < hi:
				pieces.append([start, hi])
			var tex: String = rooms[i].get("wall", "wall_timber")
			for pc in pieces:
				var seg: Rect2
				if vertical:
					seg = Rect2(r.position.x + line * T - WALL * 0.5, r.position.y + float(pc[0]) * T, WALL, (float(pc[1]) - float(pc[0])) * T)
				else:
					seg = Rect2(r.position.x + float(pc[0]) * T, r.position.y + line * T - WALL * 0.5, (float(pc[1]) - float(pc[0])) * T, WALL)
				_draw_walls([seg], tex)


func _build_building(b: Dictionary, is_area: bool) -> void:
	var r := brect(b)
	if is_area:
		# interior areas live outside the village map: frame them with dim roof timbers, not a void
		_tex_poly(_rect_pts(r.grow(900)), "wall_timber", ground_layer, Color(0.32, 0.26, 0.22))
	_tex_poly(_rect_pts(r), b.get("floor", "floor_wood"), floor_layer)
	var rooms_info := []
	for room in b.get("rooms", []):
		var rr := _room_rect(r, room)
		var tint := Color.WHITE
		if room.has("tint"):
			tint = Color(float(room["tint"][0]), float(room["tint"][1]), float(room["tint"][2]))
		_tex_poly(_rect_pts(rr), room.get("floor", "floor_wood"), floor_layer, tint)
		rooms_info.append({"id": room["id"], "name": room.get("name", room["id"]), "rect": rr})
	_interior_walls(b, r)
	var wall_tex := "wall_timber" if b.get("roof", "") == "thatch" else "wall_stone"
	_draw_walls(_wall_segments(r, b.get("doors", [])), wall_tex)
	# doors: mat + light outside
	for d in b.get("doors", []):
		var dc := _door_center(r, d)
		var mat := _sprite("props/door_mat", dc + _door_out(d) * 26, floor_layer)
		if d["side"] in ["w", "e"]:
			mat.rotation = PI / 2
		if not is_area:
			var l := FX.light(Color("#ffb060"), 190.0, 0.0)
			l.position = dc + _door_out(d) * 44
			add_child(l)
			night_lights.append(l)
	var info := {"rect": r, "roof": null, "alpha": 1.0, "name": b.get("name", b["id"]), "area": is_area, "rooms": rooms_info}
	if not is_area:
		# cast shadow + roof
		var sh := Polygon2D.new()
		var off := Vector2(26, 30)
		sh.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y) + off, r.end + off, Vector2(r.position.x, r.end.y) + off, Vector2(r.position.x, r.end.y)])
		sh.color = Color(0.1, 0.06, 0.03, 0.32)
		sh.z_index = -5
		add_child(sh)
		var roof := Sprite2D.new()
		roof.texture = Assets.get_tex("roofs/" + b["id"], Vector2i(int(r.size.x), int(r.size.y)))
		roof.centered = false
		roof.position = r.position
		roof.scale = r.size / roof.texture.get_size()
		roof_layer.add_child(roof)
		info["roof"] = roof
		for ch in b.get("chimneys", []):
			var smoke := FX.smoke(8)
			smoke.position = r.position + Vector2(float(ch[0]) + 0.4, float(ch[1]) + 0.4) * T
			roof_layer.add_child(smoke)
		# warm window glow spilling out at night
		for side_pt in [Vector2(r.position.x - 10, r.get_center().y), Vector2(r.end.x + 10, r.get_center().y)]:
			var wl := FX.light(Color("#ffa850"), 150.0, 0.0)
			wl.position = side_pt
			add_child(wl)
			night_lights.append(wl)
		if b.has("sign"):
			var d0: Dictionary = b["doors"][0]
			var sp := _door_center(r, d0) + _door_out(d0) * 40 + Vector2(-T * 1.4, 0)
			_prop(b["sign"], sp)
	buildings[b["id"]] = info
	if b.has("stairs"):
		var s: Array = b["stairs"]["pos"]
		var spos := r.position + Vector2(float(s[0]) + 0.75, float(s[1]) + 1.0) * T
		_sprite("props/stairs_up" if not is_area else "props/stairs_down", spos, floor_layer)
		_add_interactable(spos, 70.0, "stairs", b["stairs"]["to"], "Stairs — " + ("up to the rooms" if not is_area else "down to the common room"))
		spots["stairs_" + b["id"]] = spos + Vector2(0, 90) if not is_area else spos + Vector2(110, 0)
	# furniture, spots and interactables from data
	for f in b.get("furniture", []):
		_furniture(str(f[0]), r.position + Vector2(float(f[1]), float(f[2])) * T, float(f[3]) if f.size() > 3 else 0.0)
	for name in b.get("spots", {}):
		var sp2: Array = b["spots"][name]
		spots[name] = r.position + Vector2(float(sp2[0]), float(sp2[1])) * T
	var ti := 0
	for t in b.get("tables", []):
		ti += 1
		spots["inn_t%d" % ti] = r.position + Vector2(float(t[0]) - 1.0, float(t[1]) + 0.05) * T
		spots["inn_t%db" % ti] = r.position + Vector2(float(t[0]) + 1.0, float(t[1]) + 0.05) * T
	for it in b.get("interact", []):
		var ip: Array = it["pos"]
		_add_interactable(r.position + Vector2(float(ip[0]), float(ip[1])) * T, float(it.get("r", 100)), it["kind"], it["id"], it["label"])


func _door_center(r: Rect2, d: Dictionary) -> Vector2:
	var mid := (float(d["at"]) + float(d["w"]) * 0.5) * T
	match d["side"]:
		"n": return Vector2(r.position.x + mid, r.position.y + WALL * 0.5)
		"s": return Vector2(r.position.x + mid, r.end.y - WALL * 0.5)
		"w": return Vector2(r.position.x + WALL * 0.5, r.position.y + mid)
		_: return Vector2(r.end.x - WALL * 0.5, r.position.y + mid)


func _door_out(d: Dictionary) -> Vector2:
	return {"n": Vector2.UP, "s": Vector2.DOWN, "w": Vector2.LEFT, "e": Vector2.RIGHT}[d["side"]]


# ======================================================================= sprites & props
func _sprite(id: String, pos: Vector2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Assets.get_tex(id)
	s.position = pos
	parent.add_child(s)
	return s


## Places a prop: floor props go flat on the floor layer, others are Y-sorted with collision.
## `rot` is in radians; quarter turns swap the footprint so collisions match the drawn sprite.
const SWAY := {"flowers": 2.6, "flower_patch_a": 2.8, "flower_patch_b": 2.8, "bush_flower": 1.8, "bush": 1.4,
	"tree_oak_a": 1.3, "tree_oak_b": 1.3, "tree_pine": 1.0, "tree_small": 1.6}
var _sway_mats := {}


## Shared breeze material for a plant prop (one per strength).
func _sway_material(id: String) -> ShaderMaterial:
	var k := float(SWAY[id])
	if not _sway_mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/sway.gdshader")
		m.set_shader_parameter("strength", k)
		m.set_shader_parameter("speed", 1.6 if k > 2.0 else 1.1)
		_sway_mats[k] = m
	return _sway_mats[k]


func _prop(id: String, pos: Vector2, rot := 0.0) -> Node2D:
	var info: Dictionary = DB.props.get(id, {"size": [64, 64], "solid": true})
	var size := Vector2(float(info["size"][0]), float(info["size"][1]))
	if not info.get("solid", true):
		var fs := _sprite("props/" + id, pos, floor_layer)
		fs.rotation = rot
		if SWAY.has(id):
			fs.material = _sway_material(id)
		return fs
	var quarter := int(round(rot / (PI / 2))) % 2 != 0
	var ext := Vector2(size.y, size.x) if quarter else size
	var holder := Node2D.new()
	holder.position = pos + Vector2(0, ext.y * 0.3)
	var s := Sprite2D.new()
	s.texture = Assets.get_tex("props/" + id, Vector2i(int(size.x), int(size.y)))
	s.position = Vector2(0, -ext.y * 0.3)
	s.rotation = rot
	if SWAY.has(id):
		s.material = _sway_material(id)
	holder.add_child(s)
	ysort.add_child(holder)
	var foot := ext * Vector2(0.75, 0.55)
	if id.begins_with("tree"):
		foot = Vector2(size.x * 0.22, size.y * 0.18)
	_solid(Rect2(pos - foot * 0.5 + Vector2(0, ext.y * 0.1), foot))
	return holder


## Furniture with its own light/particles (candles, hearths, stoves).
func _furniture(id: String, pos: Vector2, rot_deg: float) -> void:
	_prop(id, pos, deg_to_rad(rot_deg))
	match id:
		"candle":
			var l := FX.light(Color("#ffb868"), 190.0, 0.6, true)
			l.position = pos
			add_child(l)
		"fireplace":
			var fl := FX.light(Color("#ff9a40"), 380.0, 1.0, true)
			fl.position = pos
			add_child(fl)
			var fe := FX.embers(10)
			fe.position = pos
			add_child(fe)
		"kitchen_stove":
			var sl := FX.light(Color("#ff9a50"), 220.0, 0.6, true)
			sl.position = pos
			add_child(sl)
		"arcane_rack", "arcane_glyph_decal":
			var al := FX.light(Color("#9a6cff"), 160.0, 0.35, true)
			al.position = pos
			add_child(al)
		"rune_shelf", "rune_glyph_decal":
			var rl := FX.light(Color("#ffe0a0"), 140.0, 0.3)
			rl.position = pos
			add_child(rl)


func _furnish() -> void:
	# outdoor dressing that belongs to buildings (interiors are data-driven in layout.json)
	_prop("beer_table", Vector2(21.6 * T, 22.0 * T))
	_prop("beer_table", Vector2(21.6 * T, 25.6 * T))
	spots["inn_garden"] = Vector2(22.9 * T, 23.8 * T)


# ======================================================================= stations
func _build_stations() -> void:
	var override: Dictionary = DB.building("smithy").get("station_pos", {})
	for st in DB.stations.values():
		var p: Array = override.get(st["id"], st["pos"])
		var pos := bpos("smithy", float(p[0]), float(p[1]))
		var size := Vector2(float(st["size"][0]), float(st["size"][1]))
		var tex := Assets.get_tex("stations/" + st["id"], Vector2i(int(size.x), int(size.y)))
		_station_base(st["id"], pos, size)
		var node: Node2D
		if st.get("solid", true):
			node = Node2D.new()
			node.position = pos + Vector2(0, size.y * 0.3)
			var s := Sprite2D.new()
			s.texture = tex
			s.offset = Vector2(0, -size.y * 0.3)
			node.add_child(s)
			ysort.add_child(node)
			_solid(Rect2(pos - size * Vector2(0.38, 0.28), size * Vector2(0.76, 0.56)))
			station_sprites[st["id"]] = s
		else:
			var fs := _sprite("stations/" + st["id"], pos, floor_layer)
			station_sprites[st["id"]] = fs
			node = fs
		_add_interactable(pos, maxf(size.x, size.y) * 0.5 + 42.0, "station", st["id"], st["name"])
		for fx in st.get("fx", []):
			_station_fx(fx, pos, size)
	_refresh_station_locks()
	_marker = Sprite2D.new()
	_marker.texture = Assets.get_tex("ui/station_marker", Vector2i(48, 48))
	_marker.z_index = 30
	_marker.visible = false
	add_child(_marker)
	Events.crafting_changed.connect(_update_marker)
	Events.station_worked.connect(_station_worked)
	_update_marker()
	Events.world_flag_changed.connect(func(_f): _refresh_station_locks())
	Events.skill_level_up.connect(func(_a, _b, _c): _refresh_station_locks())


var _base_anchors := {}


## A painted tabletop base under each station, matching the characters' miniature bases (purely
## visual: on the floor layer, no collision, interaction points unchanged). The station's lower edge
## stands on the base's top face; geometry mirrors tools/art/make_station_bases.py.
func _station_base(id: String, pos: Vector2, size: Vector2) -> void:
	if not Assets.has_tex("stations/bases/" + id):
		return
	if _base_anchors.is_empty():
		var txt := FileAccess.get_file_as_string("res://assets/sprites/stations/bases/anchors.json")
		var parsed: Variant = JSON.parse_string(txt) if txt != "" else null
		_base_anchors = parsed if parsed is Dictionary else {"_": {}}
	var a: Dictionary = _base_anchors.get(id, {})
	if a.is_empty():
		return
	var rx := size.x * 0.56
	var ry := maxf(rx * 0.27, size.y * 0.24)
	var top := pos + Vector2(0, size.y * 0.5 - ry * 0.55)
	var b := Sprite2D.new()
	b.texture = Assets.get_tex("stations/bases/" + id)
	b.position = top + Vector2(float(a["w"]) * 0.5 - float(a["cx"]), float(a["h"]) * 0.5 - float(a["cy"]))
	floor_layer.add_child(b)   # added after the floor textures, so it sits on the floor and under every station


func _station_fx(fx: String, pos: Vector2, size: Vector2) -> void:
	match fx:
		"fire", "light_forge":
			if fx == "light_forge":
				var l := FX.light(Color("#ff8a2a"), 400.0, 1.4, true)
				l.position = pos
				add_child(l)
			else:
				var e := FX.embers(22)
				e.position = pos + Vector2(0, -size.y * 0.1)
				add_child(e)
		"embers":
			var e2 := FX.embers(10)
			e2.position = pos
			add_child(e2)
		"glow_small":
			var l2 := FX.light(Color("#ff9a40"), 200.0, 0.7, true)
			l2.position = pos
			add_child(l2)
		"steam":
			var s := FX.smoke(6)
			s.position = pos
			s.modulate = Color(1, 1, 1, 0.6)
			add_child(s)
		"bubbles":
			var b := FX.motes(Color("#9ad070"), 10, 26.0)
			b.position = pos
			add_child(b)
		"light_green":
			var l3 := FX.light(Color("#8ad070"), 220.0, 0.55, true)
			l3.position = pos
			add_child(l3)
		"rune_glow", "light_rune":
			var m := FX.motes(Color("#e8d08a"), 6, 24.0)
			m.position = pos
			add_child(m)
			if fx == "light_rune":
				var l4 := FX.light(Color("#ffe0a0"), 200.0, 0.5)
				l4.position = pos
				add_child(l4)
		"arcane_glow", "light_arcane":
			var am := FX.motes(Color("#b08cff"), 12, 34.0)
			am.position = pos
			add_child(am)
			if fx == "light_arcane":
				var l5 := FX.light(Color("#9a6cff"), 260.0, 0.7, true)
				l5.position = pos
				add_child(l5)
		"thread_glow":
			var tm := FX.motes(Color("#e0e8ff"), 6, 22.0)
			tm.position = pos
			add_child(tm)


func station_pos(id: String) -> Vector2:
	var p: Array = DB.building("smithy").get("station_pos", {}).get(id, DB.station(id).get("pos", [0, 0]))
	return bpos("smithy", float(p[0]), float(p[1]))


## Ember marker bobbing over the station the current crafting job needs next.
func _update_marker() -> void:
	var st := Crafting.current_station()
	if st == "":
		_marker.visible = false
		return
	var size: Array = DB.station(st)["size"]
	_marker.visible = true
	var base := station_pos(st) - Vector2(0, float(size[1]) * 0.5 + 30.0)
	_marker.position = base
	var tw := _marker.create_tween().set_loops()
	tw.tween_property(_marker, "position:y", base.y - 12.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_marker, "position:y", base.y, 0.45).set_trans(Tween.TRANS_SINE)


## Tactile feedback in the world for each resolved check: sparks, steam, bubbles, rune and arcane flashes.
func _station_worked(id: String, quality: float) -> void:
	var pos := station_pos(id)
	var good := quality >= 95.0
	match id:
		"anvil", "arcane_anvil", "grinding_wheel", "rune_polishing_wheel":
			var sp := FX.sparks()
			sp.amount = 40 if good else 22
			if id == "arcane_anvil":
				sp.color_ramp.set_color(0, Color("#d8c0ff"))
			sp.position = pos
			add_child(sp)
			sp.emitting = true
			get_tree().create_timer(2.0).timeout.connect(sp.queue_free)
		"quench_trough", "leather_vat", "rune_cleansing_basin":
			var st := FX.smoke(18)
			st.one_shot = true
			st.explosiveness = 0.8
			st.lifetime = 2.2
			st.modulate = Color(1.4, 1.4, 1.5, 0.9)
			st.position = pos
			add_child(st)
			st.emitting = true
			get_tree().create_timer(3.0).timeout.connect(st.queue_free)
		"cauldron", "alembic", "mortar_station", "reagent_table", "infusion_rack":
			var bu := FX.motes(Color("#b8e08a"), 24, 30.0)
			bu.one_shot = true
			bu.explosiveness = 0.6
			bu.position = pos
			add_child(bu)
			bu.emitting = true
			get_tree().create_timer(3.0).timeout.connect(bu.queue_free)
	var flash_col: Color = {"forge": Color("#ff8a2a"), "bellows": Color("#ff8a2a"), "crucible": Color("#ff9a40"),
		"rune_cutting_bench": Color("#ffe0a0"), "rune_engraving_stand": Color("#ffe0a0"), "resonance_pedestal": Color("#ffe0a0"),
		"rune_cleansing_basin": Color("#c8e0ff"), "arcane_crucible": Color("#9a6cff"), "spellbinding_array": Color("#9a6cff"),
		"leyline_conductor": Color("#9a6cff"), "aetheric_stabilizer": Color("#9a6cff"), "arcane_anvil": Color("#b08cff"),
		"thread_spinner": Color("#e0e8ff"), "embroidery_frame": Color("#e0e8ff")}.get(id, Color("#ffc070"))
	var l := FX.light(flash_col, 320.0, 1.6 if good else 0.9)
	l.position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _refresh_station_locks() -> void:
	for id in station_sprites:
		var locked := Crafting.station_locked_reason(id) != ""
		(station_sprites[id] as CanvasItem).modulate = Color(0.55, 0.5, 0.48, 0.85) if locked else Color.WHITE


# ======================================================================= outdoors
# ======================================================================= atmosphere & animals
var animals: Array = []
const ANIMALS := [["animal_cat_1", [57.0, 33.5], 260.0], ["animal_cat_2", [30.5, 31.6], 160.0],
	["animal_dog_1", [48.0, 30.2], 300.0], ["animal_dog_2", [64.5, 25.6], 240.0]]


func _spawn_animals() -> void:
	for a in ANIMALS:
		var an := AnimalActor.new()
		an.setup(a[0], tp(a[1]), float(a[2]))
		ysort.add_child(an)
		animals.append(an)


## Restrained dust in the air, and a darker, smokier, warmer forge corner.
func _build_atmosphere() -> void:
	# street dust drifting over the square and the main roads
	for p in [[59, 31], [40, 29.5], [26, 31], [70, 31]]:
		add_child(_dust(tp(p), Vector2(420, 220), 14, Color("#e8d8b0")))
	# interiors: workshop air, inn haze
	for rm in [["smithy", "forge_room"], ["smithy", "stock_hall"], ["smithy", "shop"], ["inn", "common"]]:
		var r := _room_rect_by_id(rm[0], rm[1])
		if r.size != Vector2.ZERO:
			add_child(_dust(r.get_center(), r.size * 0.45, 10 if rm[1] != "forge_room" else 22, Color("#f0d8a8") if rm[1] != "forge_room" else Color("#ffb070")))
	# the forge corner: shadowed, sooty, with a strong warm hearth glow and rising smoke
	var fr := _room_rect_by_id("smithy", "forge_room")
	if fr.size != Vector2.ZERO:
		var shade := Polygon2D.new()
		shade.polygon = PackedVector2Array([fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)])
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.0))
		g.set_color(1, Color(0.05, 0.02, 0.0, 0.42))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.24, 0.24)
		gt.fill_to = Vector2(1.05, 1.05)
		gt.width = 256
		gt.height = 256
		shade.texture = gt
		shade.uv = PackedVector2Array([Vector2(0, 0), Vector2(256, 0), Vector2(256, 256), Vector2(0, 256)])
		shade.z_index = 1
		floor_layer.add_child(shade)
		var fp := station_pos("forge")
		var glow := FX.light(Color("#ff7a20"), 380.0, 0.9, true)
		glow.position = fp + Vector2(0, 30)
		add_child(glow)
		var sm := FX.smoke(8)
		sm.position = fp + Vector2(0, -50)
		sm.modulate = Color(0.55, 0.5, 0.45, 0.55)
		add_child(sm)
		var em := FX.embers(14)
		em.position = fp + Vector2(40, 20)
		add_child(em)


func _room_rect_by_id(bid: String, rid: String) -> Rect2:
	for rm in buildings.get(bid, {}).get("rooms", []):
		if str(rm["id"]) == rid:
			return rm["rect"]
	return Rect2()


func _dust(at: Vector2, extents: Vector2, amount: int, col: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(1, -0.3)
	p.spread = 60.0
	p.gravity = Vector2(0, -2)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.3, Color(col, 0.38))
	g.add_point(0.7, Color(col, 0.3))
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = g
	p.z_index = 20
	return p


# the shop's display table: what is for sale is visibly laid out for customers
const DISPLAY_SLOTS := [[16.85, 2.4], [17.4, 2.4], [17.95, 2.4], [16.85, 2.85], [17.4, 2.85], [17.95, 2.85]]
var _display_nodes: Array = []


func _refresh_display() -> void:
	for n in _display_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_display_nodes.clear()
	var stock := Shop.stock()
	stock.sort_custom(func(a, b): return Items.value(a) > Items.value(b))
	for i in mini(stock.size(), DISPLAY_SLOTS.size()):
		var it: Dictionary = stock[i]
		var sp := Sprite2D.new()
		sp.texture = Assets.get_tex(Items.icon_id(it), Vector2i(64, 64))
		sp.scale = Vector2(0.5, 0.5)
		sp.position = bpos("smithy", float(DISPLAY_SLOTS[i][0]), float(DISPLAY_SLOTS[i][1]))
		sp.z_index = 1   # on top of the display table
		if it.get("rarity", "common") != "common":
			var halo := Sprite2D.new()
			halo.texture = FX.light_texture()
			halo.modulate = Color(Items.COL_BORDER.get(it["rarity"], Color.WHITE), 0.45)
			halo.scale = Vector2(0.14, 0.14)
			sp.add_child(halo)
			halo.show_behind_parent = true
		ysort.add_child(sp)
		_display_nodes.append(sp)


const WAIT_SEATS := [[25.4, 33.0], [26.6, 33.0], [27.8, 33.0], [29.0, 33.0]]


func _build_waiting_area() -> void:
	for i in WAIT_SEATS.size():
		var p := tp(WAIT_SEATS[i])
		_prop("waiting_seat", p)
		# the customer stands on the seat's front edge so the figure reads in front of it
		spots["wait_seat_%d" % i] = p + Vector2(0, 24)
	_prop("waiting_awning", tp([22.6, 32.7]))
	_prop("craft_display", tp([36.8, 32.9]))


func _build_outdoors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# notice board, well, market
	var nb := Vector2(55.4 * T, 26.6 * T)
	_prop("notice_board", nb)
	_add_interactable(nb, 110.0, "notice", "board", "Village notice board — applicants, orders & upgrades")
	spots["notice"] = nb + Vector2(0, 70)
	_prop("well", Vector2(62.4 * T, 33.6 * T))
	spots["well"] = Vector2(62.4 * T, 35.0 * T)
	_prop("market_stall", Vector2(54.0 * T, 35.0 * T))
	_prop("cart", Vector2(66.5 * T, 30.0 * T))
	_prop("haybale", Vector2(68.0 * T, 31.3 * T))
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		spots["square_%d" % i] = Vector2(59 * T + cos(a) * 4.6 * T, 31 * T + sin(a) * 3.2 * T)
	# the customer waiting area outside the shop's street door: four seats, a sign and a display
	_build_waiting_area()
	# lantern posts along the roads
	var lp := [[50, 29.2], [68, 32.8], [40, 29.5], [26, 32.6], [12, 29.4], [80, 32.6], [57.2, 20], [60.8, 42], [57.4, 52], [33.4, 33.4]]
	for p in lp:
		var pos := tp(p)
		_prop("lantern_post", pos)
		var l := FX.light(Color("#ffb060"), 260.0, 0.0, true)
		l.position = pos
		add_child(l)
		night_lights.append(l)
	# farm fence and crops by Jory's
	for x in range(2, 15):
		_prop("fence_h", Vector2(x * T + 32, 49.4 * T))
	for y in range(39, 49):
		_prop("fence_v", Vector2(15.2 * T, y * T + 32))
	for p in [[2.6, 50.6], [5.0, 51.0], [8.0, 50.8]]:
		_prop("haybale", tp(p))
	# exits
	for ex in DB.layout.get("exits", []):
		var pos := tp(ex["pos"])
		_add_interactable(pos, 160.0, "exit", ex["id"], "Road to " + ex["label"])
		spots["exit_" + ex["id"]] = pos
	# trees, bushes, rocks, flowers — avoid roads, buildings and the square
	var blocked: Array[Rect2] = []
	for b in buildings.values():
		blocked.append((b["rect"] as Rect2).grow(80))
	var road_pts: Array[Vector2] = []
	for r in DB.layout.get("roads", []):
		for p in _smooth(r["points"], 64.0):
			road_pts.append(p)
	var sq_c := tp(DB.layout["square"]["center"])
	var placed: Array[Vector2] = []
	var size: Array = DB.layout["size"]
	var want := {"tree_oak_a": 70, "tree_oak_b": 55, "tree_pine": 45, "tree_small": 40, "bush": 50, "bush_flower": 30, "rock_a": 22, "rock_b": 16, "flowers": 60,
		"flower_patch_a": 45, "flower_patch_b": 45}
	for kind in want:
		var n: int = want[kind]
		var tries := 0
		while n > 0 and tries < 3000:
			tries += 1
			var p := Vector2(rng.randf_range(0, float(size[0]) * T), rng.randf_range(0, float(size[1]) * T))
			var edge := minf(minf(p.x, float(size[0]) * T - p.x), minf(p.y, float(size[1]) * T - p.y))
			# trees cluster near the map edges (forest), the rest is open meadow
			if kind.begins_with("tree") and edge > 9 * T and rng.randf() < 0.82:
				continue
			var ok := p.distance_to(sq_c) > 9 * T
			for br in blocked:
				if br.has_point(p):
					ok = false
					break
			if ok:
				for rp in road_pts:
					if rp.distance_to(p) < (2.4 * T if kind.begins_with("tree") else 1.7 * T):
						ok = false
						break
			if ok:
				var gap := 1.6 * T if kind.begins_with("tree") else 0.9 * T
				for q in placed:
					if q.distance_to(p) < gap:
						ok = false
						break
			if not ok:
				continue
			# keep exits open
			var near_exit := false
			for ex in DB.layout["exits"]:
				if tp(ex["pos"]).distance_to(p) < 5 * T:
					near_exit = true
			if near_exit:
				continue
			placed.append(p)
			_prop(kind, p, 0.0)
			n -= 1


func _refresh_eggs() -> void:
	if _eggs_node:
		_eggs_node.queue_free()
		_eggs_node = null
	for i in range(interactables.size() - 1, -1, -1):
		if interactables[i]["kind"] == "eggs":
			interactables.remove_at(i)
	if Game.state.get("world", {}).get("eggs", false):
		var pos := bpos("smithy", 12.4, -0.55)
		_eggs_node = _sprite("props/eggs_splat", pos, roof_layer)
		_eggs_node.z_index = 2
		_add_interactable(pos + Vector2(0, -30), 110.0, "eggs", "eggs", "Scrub the eggs off the shop front")


func _refresh_bags() -> void:
	for n in _bag_nodes:
		n.queue_free()
	_bag_nodes.clear()
	for i in range(interactables.size() - 1, -1, -1):
		if interactables[i]["kind"] == "bag":
			interactables.remove_at(i)
	var returns: Array = Game.state.get("returns", [])
	for i in returns.size():
		var pos: Vector2 = spots.get("smithy_bag", Vector2.ZERO) + Vector2((i % 4) * 56.0, int(i / 4) * 44.0)
		var s := _sprite("props/loot_pile", pos, floor_layer)
		var glow := FX.motes(Items.COL_BORDER.get(Loot.best_rarity(returns[i].get("contents", [])), Color.WHITE), 5, 18.0)
		s.add_child(glow)
		_bag_nodes.append(s)
		_add_interactable(pos, 70.0, "bag", str(returns[i]["uid"]), "Open: " + str(returns[i]["name"]) + (" (from %s)" % returns[i]["from"] if returns[i].get("from", "") != "" else ""))


# ======================================================================= navigation graph
func _pt(pos: Vector2) -> int:
	var id := _next_point
	_next_point += 1
	astar.add_point(id, pos)
	return id


func _link_nearest(id: int, max_d := 900.0, count := 2) -> void:
	var pos := astar.get_point_position(id)
	var cands := []
	for other in astar.get_point_ids():
		if other == id:
			continue
		var d := astar.get_point_position(other).distance_to(pos)
		if d < max_d:
			cands.append([d, other])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(count, cands.size()):
		astar.connect_points(id, cands[i][1])


func _build_nav() -> void:
	var road_ids: Array[int] = []
	for r in DB.layout.get("roads", []):
		var prev := -1
		for p in _smooth(r["points"], 110.0):
			var id := _pt(p)
			road_ids.append(id)
			if prev >= 0:
				astar.connect_points(prev, id)
			prev = id
	# stitch road junctions
	for a in road_ids:
		for b in road_ids:
			if a < b and not astar.are_points_connected(a, b) and astar.get_point_position(a).distance_to(astar.get_point_position(b)) < 120.0:
				astar.connect_points(a, b)
	var outdoor_ids: Array[int] = road_ids.duplicate()
	# outdoor spots
	for name in spots.keys():
		if name.begins_with("square_") or name in ["notice", "well", "inn_garden"] or name.begins_with("exit_") or name.begins_with("wait_seat_"):
			var id := _pt(spots[name])
			spot_ids[name] = id
			_link_nearest(id, 1400.0, 2)
			outdoor_ids.append(id)
	# room hubs: every room gets a centre node; rooms are convex, so hub ↔ anything inside is wall-free
	var hubs := {}
	for bid in buildings:
		for rm in buildings[bid].get("rooms", []):
			hubs[bid + "/" + str(rm["id"])] = _pt((rm["rect"] as Rect2).get_center())
	# interior doors: a node on each side, linked through the gap and to their room hubs
	for d in _room_doors:
		var off := Vector2(56, 0) if d["vertical"] else Vector2(0, 56)
		var p1 := _pt((d["pos"] as Vector2) - off)
		var p2 := _pt((d["pos"] as Vector2) + off)
		astar.connect_points(p1, p2)
		for q in [p1, p2]:
			var rid := room_at(d["b"], astar.get_point_position(q))
			if rid != "":
				astar.connect_points(q, hubs[d["b"] + "/" + rid])
	# exterior doors: outside ↔ inside ↔ hub of the entrance room
	for b in DB.layout.get("buildings", []):
		var r := brect(b)
		var d: Dictionary = b["doors"][0]
		var dc := _door_center(r, d)
		var out_id := _pt(dc + _door_out(d) * 70.0)
		var in_id := _pt(dc - _door_out(d) * 70.0)
		astar.connect_points(out_id, in_id)
		# the doorstep joins the outdoor network only (never its own building's interior nodes)
		var best := -1
		var best_d := INF
		for o in outdoor_ids:
			var dd := astar.get_point_position(o).distance_to(astar.get_point_position(out_id))
			if dd < best_d:
				best_d = dd
				best = o
		if best >= 0:
			astar.connect_points(out_id, best)
		spots[b["id"] + "_door_out"] = dc + _door_out(d) * 70.0
		spot_ids[b["id"] + "_door_out"] = out_id
		var rid2 := room_at(b["id"], astar.get_point_position(in_id))
		if rid2 != "":
			astar.connect_points(in_id, hubs[b["id"] + "/" + rid2])
	# interior spots hang off their room's hub
	for name in spots.keys():
		if spot_ids.has(name):
			continue
		for bid in buildings:
			if not (buildings[bid]["rect"] as Rect2).has_point(spots[name]):
				continue
			var rid3 := room_at(bid, spots[name])
			if rid3 != "":
				var sid := _pt(spots[name])
				spot_ids[name] = sid
				astar.connect_points(sid, hubs[bid + "/" + rid3])
			break
	if spot_ids.has("upstairs_hall"):
		pass


## Room id at a world position inside building `bid` ("" outside any room).
func room_at(bid: String, pos: Vector2) -> String:
	for rm in buildings.get(bid, {}).get("rooms", []):
		if (rm["rect"] as Rect2).has_point(pos):
			return rm["id"]
	return ""


func path_to(from: Vector2, spot: String) -> PackedVector2Array:
	if not spot_ids.has(spot):
		if spots.has(spot):
			return PackedVector2Array([spots[spot]])
		return PackedVector2Array()
	var a := astar.get_closest_point(from)
	var pts := astar.get_point_path(a, spot_ids[spot])
	var out := PackedVector2Array([from])
	out.append_array(pts)
	out.append(spots[spot] if spots.has(spot) else astar.get_point_position(spot_ids[spot]))
	return out


# ======================================================================= actors
func _spawn_player() -> void:
	player = PlayerBody.new()
	var saved: Array = Game.state["player"].get("pos", [])
	player.position = Vector2(float(saved[0]), float(saved[1])) if saved.size() == 2 else bpos("smithy", 15, 7.5)
	ysort.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()
	_set_camera_limits()


func _set_camera_limits() -> void:
	var r: Rect2
	if area == "inn_upstairs":
		r = brect(DB.building("inn_upstairs")).grow(400)
	else:
		var size: Array = DB.layout["size"]
		r = Rect2(-256, -256, float(size[0]) * T + 512, float(size[1]) * T + 512)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)


func _spawn_npcs() -> void:
	for id in DB.characters:
		var c: Dictionary = DB.characters[id]
		if c["kind"] in ["player", "applicant_look"]:
			continue
		_make_npc(id, c["sprite"], c["name"])
	for h in Hire.list():
		if not npcs.has(h["id"]):
			_make_npc(h["id"], "chars/" + str(h["look"]), h["name"])


func spawn_new_hirelings() -> void:
	for h in Hire.list():
		if not npcs.has(h["id"]):
			_make_npc(h["id"], "chars/" + str(h["look"]), h["name"])
	_update_schedules()


func _make_npc(id: String, sprite_id: String, name: String) -> NPCActor:
	var n := NPCActor.new()
	ysort.add_child(n)
	n.setup(id, sprite_id, name)
	n.arrived.connect(_on_npc_arrived)
	n.visible = false
	npcs[id] = n
	return n


## Schedule: where should this NPC be right now? "" = not present in the world (asleep, away…).
func spot_for(id: String) -> String:
	var h := Game.hour()
	for cu in Shop.customers():
		if cu["npc"] == id:
			return "wait_seat_%d" % int(cu.get("seat", 0))
	var hire := Hire.get_h(id)
	if not hire.is_empty():
		match hire["status"]:
			"away", "dead":
				return ""
			"injured":
				return "inn_t5" if h >= 8 and h < 22 else ""
		if h >= 8 and h < 18:
			var top := "mining"
			for k in hire["alloc"]:
				if int(hire["alloc"][k]) > int(hire["alloc"].get(top, 0)):
					top = k
			return "work_" + top
		if h >= 18 and h < 23:
			return "inn_t3"
		return ""
	var a := Adv.get_a(id)
	if not a.is_empty():
		if a["status"] in ["away", "dead", "missing"]:
			return ""
		# a party forming at dawn sits together at its own table until it leaves at eight
		var pt := Expeditions.party_of(id)
		if not pt.is_empty() and h >= 6 and h < 8:
			return "inn_t%d" % (1 + int(pt.get("table", 1)) % 6) if id == pt["leader"] else "inn_t%db" % (1 + int(pt.get("table", 1)) % 6)
		if Social.spouse() == id and (h >= 21 or h < 7):
			return "quarters_table" if h < 23 and h >= 21 else ""
		if a["status"] == "injured":
			return "inn_t%d" % (1 + (absi(id.hash()) % 6)) if h >= 9 and h < 22 else ""
		if h < 7:
			return ""
		var seed := absi(id.hash() + Game.day())
		if h < 9 or (h >= 12 and h < 14) or h >= 18:
			return ["inn_t%d" % (1 + seed % 6), "inn_t%db" % (1 + (seed / 7) % 6), "inn_bar", "inn_hearth"][(seed + h) % 4]
		return ["square_%d" % (seed % 6), "notice", "well", "inn_garden", "square_%d" % ((seed + 3) % 6)][(seed + h) % 5]
	match id:
		"aldric":
			if Game.state["world"].get("delivery_pending", false) and h >= 9 and h < 17:
				return "smithy_door_out"
			return "grocery_behind" if h >= 7 and h < 19 else ("inn_t2b" if h < 21 else "")
		"hilde":
			return "inn_behind_bar" if h >= 6 else ""
		"wenna":
			if h >= 11 and h < 24:
				return ["inn_t1b", "inn_t3b", "inn_t4", "inn_bar", "inn_t6b", "inn_t2"][h % 6]
			return ""
		"martha":
			return "well" if h >= 8 and h < 12 else ("house_martha_inside" if h < 21 else "")
		"tobin":
			return "house_tobin_inside" if h >= 8 and h < 17 else ("inn_t4b" if h < 21 else "")
		"oswin":
			return "house_oswin_inside" if h >= 6 and h < 21 else ""
		"jory":
			return "house_jory_inside" if h >= 7 and h < 15 else (["square_2", "inn_t5b"][int(h >= 18)] if h < 21 else "")
		"eda":
			return "well" if h >= 8 and h < 16 else ("square_4" if h < 20 else "")
		"rosalind":
			return "lantern_3"
		"roisin":
			return Roisin.spot(spots.has("lantern_roisin"))
		"lysa":
			return "lantern_1"
		"celeste":
			return "lantern_2"
	return ""


func _update_schedules(instant := false) -> void:
	for id in npcs:
		var n: NPCActor = npcs[id]
		if n.get_meta("travelling", false):
			continue
		var spot := spot_for(id)
		if spot == "":
			if n.visible and not instant:
				# walk off to bed / out of sight
				var home := _home_spot(id)
				if home != "":
					n.hidden_after_arrival = true
					n.go(path_to(n.position, home))
					continue
			n.visible = false
			n.target_spot = ""
			continue
		if not n.visible:
			n.position = spots.get(_home_spot(id), spots.get(spot, Vector2.ZERO)) if not instant else spots.get(spot, Vector2.ZERO)
			n.visible = true
		if n.target_spot != spot:
			n.target_spot = spot
			n.hidden_after_arrival = false
			if instant:
				n.position = spots.get(spot, n.position)
				if spot.begins_with("wait_seat_"):
					Shop.mark_arrived(id, false)
			else:
				n.go(path_to(n.position, spot))


func _home_spot(id: String) -> String:
	var c := DB.character(id)
	var home: String = c.get("home", "")
	if home == "grocery":
		return "grocery_behind"
	if home.begins_with("house_"):
		return home + "_inside"
	if home == "inn_upstairs":
		return "lantern_3"
	return "inn_door_out"


func _on_npc_arrived(id: String) -> void:
	var n: NPCActor = npcs[id]
	if n.target_spot.begins_with("wait_seat_"):
		Shop.mark_arrived(id)
	if n.hidden_after_arrival:
		n.visible = false
		n.hidden_after_arrival = false
	if n.get_meta("travelling", false):
		n.set_meta("travelling", false)
		if n.get_meta("leaving", false):
			n.visible = false
			n.set_meta("leaving", false)
		_update_schedules()
	elif randf() < 0.25 and n.visible:
		_bark(id)


func _bark(id: String) -> void:
	var lines := {"inn": ["\"Another round!\"", "\"…and then the wight just *looked* at me.\"", "\"To the smith!\"", "\"My feet ache.\""],
		"village": ["\"Fine day.\"", "\"Mind the cart.\"", "\"Smells like rain.\"", "\"Did you hear about the barrows?\""],
		"smithy": ["\"Nice blade on the rack.\"", "\"How much for the dagger?\""]}
	var n: NPCActor = npcs[id]
	var where := "village"
	for bid in ["inn", "smithy"]:
		if brect(DB.building(bid)).has_point(n.position):
			where = bid
	if randf() < 0.5:
		n.say((lines[where] as Array).pick_random())


func _on_departed(id: String, exit_id: String) -> void:
	if not npcs.has(id):
		return
	var n: NPCActor = npcs[id]
	if not n.visible:
		n.position = spots.get("inn_door_out", n.position) if Hire.get_h(id).is_empty() else spots.get("smithy_door_out", n.position)
		n.visible = true
	n.set_meta("travelling", true)
	n.set_meta("leaving", true)
	n.go(path_to(n.position, "exit_" + exit_id))
	n.say(["\"Off we go.\"", "\"Wish me luck, smith.\"", "\"Back in a few days.\""].pick_random(), 3.0)
	Objectives.complete("watch_depart")


func _on_returned(id: String, exit_id: String) -> void:
	if not npcs.has(id):
		return
	var n: NPCActor = npcs[id]
	n.position = spots.get("exit_" + exit_id, n.position)
	n.visible = true
	n.set_meta("travelling", true)
	n.set_meta("leaving", false)
	n.go(path_to(n.position, "smithy_door_out" if not Hire.get_h(id).is_empty() else "inn_door_out"))


# ======================================================================= frame update
func _process(delta: float) -> void:
	if player == null:
		return
	_update_area(delta)
	_update_focus()
	_update_light(false)
	Game.state["player"]["pos"] = [player.position.x, player.position.y]


func _update_area(delta: float) -> void:
	var new_area := "village"
	for id in buildings:
		var b: Dictionary = buildings[id]
		var inside := (b["rect"] as Rect2).grow(-WALL).has_point(player.position)
		if inside:
			new_area = id
		var roof: Sprite2D = b["roof"]
		if roof:
			var target := 0.0 if inside else 1.0
			roof.modulate.a = move_toward(roof.modulate.a, target, delta * 3.0)
	if new_area != area:
		area = new_area
		Game.state["player"]["area"] = area
		room = room_at(area, player.position)
		_on_area_changed()
	else:
		var new_room := room_at(area, player.position)
		if new_room != room:
			room = new_room
			if room != "":
				for rm in buildings[area]["rooms"]:
					if rm["id"] == room:
						Events.toast.emit(str(rm["name"]), "area")


func _on_area_changed() -> void:
	_set_camera_limits()
	var night := Game.is_night()
	match area:
		"smithy":
			Audio.set_ambience("bed", "amb/workshop_loop", -4.0)
			Audio.play_music("music/hearth_day")
		"inn", "inn_upstairs":
			Audio.set_ambience("bed", "amb/tavern_loop", -6.0 if area == "inn" else -16.0)
			Audio.play_music("music/tavern")
		_:
			Audio.set_ambience("bed", "amb/village_night_loop" if night else "amb/village_day_loop", -6.0)
			Audio.play_music("music/village_evening" if Game.hour() >= 17 or night else "music/hearth_day")
	Events.toast.emit(buildings.get(area, {}).get("name", "Brindlewick"), "area")


func _update_focus() -> void:
	var best := {}
	var best_d := 1e9
	var ppos := player.position + player.facing_vector() * 24.0
	for e in interactables:
		var d := ppos.distance_to(e["pos"])
		if d < float(e["r"]) and d < best_d:
			best_d = d
			best = e
	# only the nearest figure shows its name, so a row of customers never overlaps
	var near_id := ""
	var near_d := 220.0
	for id in npcs:
		var nn: NPCActor = npcs[id]
		if nn.visible and ppos.distance_to(nn.position) < near_d:
			near_d = ppos.distance_to(nn.position)
			near_id = id
	for id in npcs:
		var n: NPCActor = npcs[id]
		if not n.visible:
			continue
		var d := ppos.distance_to(n.position)
		n.show_name(id == near_id)
		if d < 90.0 and d < best_d:
			best_d = d
			best = {"kind": "npc", "id": id, "label": "Talk to " + n.display_name, "pos": n.position}
	if best.get("label", "") != _focus.get("label", ""):
		_focus = best
		Events.open_panel.emit("prompt", {"text": best.get("label", "")})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and Game.ui_blockers == 0 and not _focus.is_empty():
		get_viewport().set_input_as_handled()
		interact(_focus)


func interact(e: Dictionary) -> void:
	match e["kind"]:
		"station":
			Events.open_panel.emit("station", {"id": e["id"]})
		"counter":
			Events.open_panel.emit("shop", {})
		"notice":
			Events.open_panel.emit("notice", {})
		"npc":
			var n: NPCActor = npcs[e["id"]]
			n.facing = "s"
			Audio.play("sfx/npc_greet", -6.0, randf_range(0.85, 1.15))
			Events.open_panel.emit("dialogue", {"npc": e["id"], "area": area})
		"bed":
			Events.open_panel.emit("sleep", {})
		"ledger":
			Events.open_panel.emit("shop", {"tab": "ledger"})
		"wanted":
			Events.open_panel.emit("wanted", {})
		"harbour", "herbalist", "ironfront", "property", "customize", "help", "designer", "skilltree":
			# venues and desks added in iteration 009 open their panel; the id travels along
			Events.open_panel.emit(e["kind"], {"id": e["id"]})
		"bag":
			Events.open_panel.emit("loot", {"uid": int(e["id"])})
		"eggs":
			Sim.clean_eggs()
			Audio.play("sfx/water")
			Events.toast.emit("You scrub the shop front clean. Somebody in this village is cross with you.", "info")
		"stairs":
			var target := "inn_upstairs" if e["id"] == "inn_upstairs" else "inn"
			player.position = spots["stairs_inn_upstairs"] if target == "inn_upstairs" else spots["stairs_inn"]
			Audio.play("sfx/door", -4.0)
			camera.reset_smoothing()
		"exit":
			var ex := {}
			for x in DB.layout["exits"]:
				if x["id"] == e["id"]:
					ex = x
			var dest: Dictionary = DB.destinations.get(ex.get("region", ""), {})
			Events.toast.emit("%s — %s Send hirelings from the Hirelings ledger [H]." % [ex.get("label", ""), dest.get("desc", "")], "info")


# ======================================================================= light
func _update_light(force: bool) -> void:
	var m := float(Game.state.get("minute", 720))
	var h := m / 60.0
	var c: Color
	var night_f := 0.0
	if h < 4.5:
		c = Color(0.36, 0.40, 0.62); night_f = 1.0
	elif h < 7.0:
		var t := (h - 4.5) / 2.5
		c = Color(0.36, 0.40, 0.62).lerp(Color(1.0, 0.86, 0.78), t); night_f = 1.0 - t
	elif h < 17.5:
		c = Color(1.0, 0.86, 0.78).lerp(Color(1.0, 0.98, 0.94), clampf((h - 7.0) / 3.0, 0.0, 1.0))
		if h > 15.5:
			c = Color(1.0, 0.98, 0.94).lerp(Color(1.0, 0.84, 0.66), (h - 15.5) / 2.0)
	elif h < 21.0:
		var t2 := (h - 17.5) / 3.5
		c = Color(1.0, 0.84, 0.66).lerp(Color(0.40, 0.42, 0.64), t2); night_f = t2
	else:
		c = Color(0.36, 0.40, 0.62); night_f = 1.0
	if area in ["smithy", "inn", "grocery", "inn_upstairs"] or area.begins_with("house_"):
		c = c.lerp(Color(0.92, 0.84, 0.74), 0.55)   # interiors are lit by hearths and candles
	canvas_mod.color = c
	for l in night_lights:
		(l as PointLight2D).energy = night_f * 0.9
		if l.has_method("_process"):
			l.set("base_energy", night_f * 0.9)
	if force:
		_on_area_changed()
