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
var solid_rects: Array[Rect2] = []   # every static footprint (walls, props, trees, water): the animals' walkability grid
var _animal_nav: AnimalNav



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
	ysort.add_child(CompanionFollowers.new(self))   # adventurers' creature companions trot behind them
	_spawn_animals()
	_refresh_bags()
	_refresh_display()
	_refresh_eggs()
	add_child(ActivityBubbles.new())   # iteration 010 (hirelings): activity bubbles over nearby people
	add_child(MemorialWorld.new())     # iteration 010 (hirelings): graves, funeral, ghost, flowers, vase
	add_child(ApprenticeActors.new())  # iteration 012: workshop apprentices at their stations
	add_child(ContractWorld.new())     # The Living Realm: crates of a major contract beside the Project Bench
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
	solid_rects.append(r)


## Where village animals may walk (built on first use, once the whole village stands).
func animal_nav() -> AnimalNav:
	if _animal_nav == null and is_node_ready():
		_animal_nav = Village10.build_nav(self)
	return _animal_nav


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


## Roads, verges, doorsteps and the square's cobbles, worn into the ground (iteration 010: VillageGround).
func _build_roads() -> void:
	VillageGround.build(self)


func _build_stream() -> void:
	var st: Dictionary = DB.layout.get("stream", {})
	if st.is_empty():
		return
	var pts := _smooth(st["points"])
	var wpx := float(st["width"]) * T
	# damp banks feathering into the grass on either side (VillageGround.soft_strip), under the ink edge
	VillageGround.soft_strip(ground_layer, pts, wpx * 0.5 + 6.0, wpx * 0.5 + 76.0, Color(0.46, 0.36, 0.22, 0.42))
	VillageGround.soft_strip(ground_layer, pts, wpx * 0.5, wpx * 0.5 + 24.0, Color(0.3, 0.23, 0.14, 0.5), false)
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
	var smithy_floor := _smithy_floor_of(b, is_area)   # "" for every other building
	if smithy_floor != "":
		b = _smithy_view(b, smithy_floor)
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
	if smithy_floor != "":
		_smithy_overlays(r, smithy_floor)
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
			Village10.place_sign(self, b, r)   # hangs beside the door: no collision, drawn above the actors
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
	"tree_oak_a": 1.3, "tree_oak_b": 1.3, "tree_pine": 1.0, "tree_small": 1.6, "reeds": 2.4, "fern": 1.8, "undergrowth": 1.2}
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
		"standing_lamp":
			var sl2 := FX.light(Color("#ffc070"), 230.0, 0.75, true)
			sl2.position = pos
			add_child(sl2)
		"rival_forge":
			var rf := FX.light(Color("#ff7a26"), 300.0, 0.85, true)
			rf.position = pos
			add_child(rf)
			var re := FX.embers(8)
			re.position = pos + Vector2(0, -10)
			add_child(re)
		"wax_vat":
			var wv := FX.light(Color("#ff9a50"), 150.0, 0.5, true)
			wv.position = pos + Vector2(0, 26)
			add_child(wv)
		"paint_desk":
			var pdl := FX.light(Color("#ffd090"), 150.0, 0.55)
			pdl.position = pos + Vector2(42, -10)
			add_child(pdl)
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
	# only the stations installed in rooms the smith owns, where he placed them (Property)
	var mains := Property.main_stations()
	for sid in Property.st()["stations"]:
		if not Property.is_installed(sid):
			continue
		var st := DB.station(sid)
		if st.is_empty():
			continue
		var tpos := Property.pos_of(sid)
		var pos := bpos("smithy", tpos.x, tpos.y)
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
			s.flip_h = Property.flipped(sid)
			station_sprites[st["id"]] = s
		else:
			var fs := _sprite("stations/" + st["id"], pos, floor_layer)
			fs.flip_h = Property.flipped(sid)
			station_sprites[st["id"]] = fs
			node = fs
		var is_main := mains.has(sid)
		_add_interactable(pos, maxf(size.x, size.y) * 0.5 + 42.0, "station", st["id"], str(st["name"]) + (" — choose recipes here" if is_main else ""))
		if is_main:
			_main_station_mark(pos, size)
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
	var tpos := Property.pos_of(id)
	return bpos("smithy", tpos.x, tpos.y)


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
		an.setup(a[0], tp(a[1]), float(a[2]), Rect2(), self)
		ysort.add_child(an)
		animals.append(an)
	Village10.spawn_livestock(self)   # horses and cows at grass in their paddocks


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
		var fp := station_pos("forge") if Property.is_installed("forge") else fr.get_center()
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
	_build_night_dressing()
	_forge_night_light()


## S2: as the evening falls the forge fire becomes the workshop's light — a wide, warm, flickering glow from the hearth
## that grows with `night_factor` (a night light: _update_light scales it, Flicker breathes it) and is gone by day.
## Added after the night dressing so it keeps the interior light mask: it lights the workshop, not the street.
func _forge_night_light() -> void:
	var fr := _room_rect_by_id("smithy", "forge_room")
	if fr.size == Vector2.ZERO:
		return
	var fp := station_pos("forge") if Property.is_installed("forge") else fr.get_center()
	var nl := FX.light(Color("#ff6a1c"), 640.0, 0.0, true)
	nl.name = "ForgeNightLight"
	nl.position = fp + Vector2(0, 24)
	nl.set_meta("gain", 1.7)
	add_child(nl)
	night_lights.append(nl)


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
	_prop("market_stall", tp(DB.layout.get("market_stall", [54.0, 35.0])))
	_prop("cart", Vector2(66.5 * T, 30.0 * T))
	_prop("haybale", Vector2(68.0 * T, 31.3 * T))
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		spots["square_%d" % i] = Vector2(59 * T + cos(a) * 4.6 * T, 31 * T + sin(a) * 3.2 * T)
	# the customer waiting area outside the shop's street door: four seats, a sign and a display
	_build_waiting_area()
	# street lamps along the roads (iteration 010: iron lamp posts with a lantern that lights at dusk)
	Village10.build_lamps(self)
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
	# iteration 009: stairs, pond, harbour, hand-placed dressing, ground wear, groves and the woodland boundary
	_build_stairways()
	for name in DB.layout.get("outdoor_spots", {}):
		spots[name] = tp(DB.layout["outdoor_spots"][name])
	_build_pond()
	_build_harbour()
	_build_outdoor_props()
	Village10.build_outdoors(self)   # iteration 010: overhead bunting, venue interactables, the caravan camp
	_build_ground_detail()
	_build_vegetation(rng)
	_place_animals_extra()


# ======================================================================= iteration 009: the living village
## Generic stairways (data: buildings[].stairways / areas[].stairways = [{pos, to, arrive, sprite, label}]).
## Each stairway is an interactable of kind "stairs" whose id is the building/area it leads to; arriving there
## puts you on its "stairs_<id>" spot. Barnaby's house ↔ the Ironfront basement uses this; the inn keeps its
## older "stairs" record, which `interact()` handles the same way.
func _build_stairways() -> void:
	for b in DB.layout.get("buildings", []) + DB.layout.get("areas", []):
		if not b.has("stairways"):
			continue
		var r := brect(b)
		for st in b["stairways"]:
			var spos := r.position + Vector2(float(st["pos"][0]), float(st["pos"][1])) * T
			_sprite("props/" + str(st.get("sprite", "stairs_up")), spos, floor_layer)
			_add_interactable(spos, 80.0, "stairs", str(st["to"]), str(st.get("label", "Stairs")))
			var arr: Array = st.get("arrive", [st["pos"][0], float(st["pos"][1]) + 1.5])
			spots["stairs_" + str(b["id"])] = r.position + Vector2(float(arr[0]), float(arr[1])) * T


## Static collision for a water body: 32 px cells whose centre lies inside `poly`, minus the `open` rects
## (jetties, quays), merged into horizontal runs.
func _water_collision(poly: PackedVector2Array, open: Array) -> void:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var cs := 32.0
	var y := bb.position.y
	while y < bb.end.y:
		var run_start := -1.0
		var x := bb.position.x
		while x <= bb.end.x + cs:
			var c := Vector2(x + cs * 0.5, y + cs * 0.5)
			var wet := x <= bb.end.x and Geometry2D.is_point_in_polygon(c, poly)
			for o in open:
				if (o as Rect2).has_point(c):
					wet = false
			if wet and run_start < 0.0:
				run_start = x
			elif not wet and run_start >= 0.0:
				_solid(Rect2(run_start, y, x - run_start, cs))
				run_start = -1.0
			x += cs
		y += cs


func _ellipse_poly(c: Vector2, rad: Vector2, n := 36, wob := 0.05, seed := 3) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + wob * sin(a * 3.0 + seed) + wob * 0.6 * sin(a * 7.0 + seed * 2.0)
		poly.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * k)
	return poly


func _water_body(poly: PackedVector2Array) -> void:
	# muddy bank, ink shoreline, water, and a pale sheen toward the middle
	# damp earth that feathers out into the grass, then a wetter, darker lip right at the water
	VillageGround.soft_ring(ground_layer, poly, 4.0, 70.0, Color(0.46, 0.36, 0.22, 0.42))
	VillageGround.soft_ring(ground_layer, poly, 4.0, 22.0, Color(0.3, 0.23, 0.14, 0.5), false)
	_tex_poly(poly, "water", ground_layer)
	_outline(poly, 4.0, ground_layer)
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var inner := PackedVector2Array()
	for p in poly:
		inner.append(c + (p - c) * 0.82)
	var sheen := Polygon2D.new()
	sheen.polygon = inner
	sheen.color = Color(0.85, 0.92, 1.0, 0.10)
	ground_layer.add_child(sheen)


func _plank_deck(r: Rect2, vertical: bool) -> void:
	_tex_poly(_rect_pts(r), "floor_wood", floor_layer, Color(0.9, 0.84, 0.76))
	_outline(_rect_pts(r), 3.0, floor_layer)
	var n := int((r.size.y if vertical else r.size.x) / 22.0)
	for i in range(1, n):
		var t := float(i) / n
		var seam: PackedVector2Array
		if vertical:
			var yy := r.position.y + r.size.y * t
			seam = PackedVector2Array([Vector2(r.position.x + 3, yy), Vector2(r.end.x - 3, yy)])
		else:
			var xx := r.position.x + r.size.x * t
			seam = PackedVector2Array([Vector2(xx, r.position.y + 3), Vector2(xx, r.end.y - 3)])
		_outline(seam, 1.2, floor_layer, Color(0.13, 0.08, 0.05, 0.45), false)


# ----------------------------------------------------------------------- the pond
var _ducks: Array = []


func _build_pond() -> void:
	var pd: Dictionary = DB.layout.get("pond", {})
	if pd.is_empty():
		return
	var c := tp(pd["center"])
	var rad := tp(pd["radius"])
	_water_body(_ellipse_poly(c, rad, 40, 0.06, 5))
	var jr: Array = pd.get("jetty", [])
	var jetty := Rect2()
	if jr.size() == 4:
		jetty = Rect2(tp([jr[0], jr[1]]), Vector2(float(jr[2]), float(jr[3])) * T)
		_plank_deck(jetty, true)
		for py in [jetty.position.y + 10, jetty.position.y + jetty.size.y * 0.5]:
			for px in [jetty.position.x - 4, jetty.end.x + 4]:
				_sprite("props/mooring_post", Vector2(px, py), floor_layer).scale = Vector2(0.6, 0.6)
	_water_collision(_ellipse_poly(c, rad * 0.9, 40, 0.06, 5), [jetty.grow(-6)])
	for p in pd.get("lilies", []):
		_prop("lily_pads", tp(p))
	for p in pd.get("reeds", []):
		_prop("reeds", tp(p))
	if pd.has("bench"):
		_prop("bench", tp(pd["bench"]))
	_veg_mark_ellipse(c, rad + Vector2(T * 1.6, T * 1.4), 1)
	_veg_mark_ellipse(c, rad + Vector2(T * 0.4, T * 0.4), 2)
	# ducks paddle slow loops on the water
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for d in pd.get("ducks", []):
		var home := tp(d)
		var duck := _sprite("props/duck", home, floor_layer)
		duck.z_index = 1
		duck.scale = Vector2(1.5, 1.5)
		var tw := duck.create_tween().set_loops()
		var prev: Vector2 = home
		var legs: Array[Vector2] = []
		for k in 4:
			var a := rng.randf() * TAU
			legs.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * rng.randf_range(0.25, 0.68))
		legs.append(home)
		for nxt in legs:
			var west := nxt.x < prev.x
			tw.tween_callback(func() -> void: duck.flip_h = west)
			tw.tween_property(duck, "position", nxt, maxf(0.5, prev.distance_to(nxt) / 14.0)).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(rng.randf_range(1.5, 4.0))
			prev = nxt
		_ducks.append(duck)


# ----------------------------------------------------------------------- the harbour
var harbour_ship: Sprite2D
var harbour_ship_id := ""


func _build_harbour() -> void:
	var hb: Dictionary = DB.layout.get("harbour", {})
	if hb.is_empty():
		return
	var poly := PackedVector2Array()
	for p in hb["water"]:
		poly.append(tp(p))
	_water_body(poly)
	var q: Array = hb["quay"]
	var quay := Rect2(tp([q[0], q[1]]), Vector2(float(q[2]), float(q[3])) * T)
	_tex_poly(_rect_pts(quay), "cobble", floor_layer, Color(0.86, 0.82, 0.76))
	_outline(_rect_pts(quay), 3.0, floor_layer)
	# timber fender along the water's edge, weed on the wet stone below it
	var edge_y := quay.end.y - 6.0
	_outline(PackedVector2Array([Vector2(quay.position.x, edge_y), Vector2(quay.end.x, edge_y)]), 12.0, floor_layer, Color("#4a3220"), false)
	_outline(PackedVector2Array([Vector2(quay.position.x, edge_y), Vector2(quay.end.x, edge_y)]), 2.0, floor_layer, INK, false)
	_outline(PackedVector2Array([Vector2(quay.position.x, quay.end.y + 6), Vector2(quay.end.x, quay.end.y + 6)]), 8.0, ground_layer, Color(0.3, 0.36, 0.22, 0.6), false)
	if hb.has("culvert"):
		# the stream runs under a plank bridge in the quay and spills out into the harbour
		var cv: Array = hb["culvert"]
		var deck := Rect2(tp([cv[0], cv[1]]) - Vector2(float(cv[2]) * T * 0.5, 0), Vector2(float(cv[2]), float(cv[3])) * T)
		_plank_deck(deck, false)
		var mouth := Polygon2D.new()
		mouth.polygon = _ellipse_poly(Vector2(deck.get_center().x, deck.end.y + 4), Vector2(deck.size.x * 0.42, 10), 16, 0.02)
		mouth.color = Color(0.06, 0.05, 0.05, 0.7)
		ground_layer.add_child(mouth)
	for p in hb.get("boats", []):
		_prop("rowboat", tp(p))
	var jr: Array = hb.get("jetty", [])
	var jetty := Rect2()
	if jr.size() == 4:
		jetty = Rect2(tp([jr[0], jr[1]]), Vector2(float(jr[2]), float(jr[3])) * T)
		_plank_deck(jetty, true)
	for p in hb.get("posts", []):
		_prop("mooring_post", tp(p))
	_water_collision(poly, [jetty.grow(-4), quay])
	# the harbourmaster's booth: interactable `harbour` at its serving hatch
	if hb.has("booth"):
		var bp := tp(hb["booth"])
		_prop("harbour_booth", bp)
		_add_interactable(bp + Vector2(0, 76), 130.0, "harbour", "harbour", "Harbourmaster's booth — ships, cargo & trade")
		var bl := FX.light(Color("#ffb060"), 220.0, 0.0, true)
		bl.position = bp + Vector2(-56, -50)
		add_child(bl)
		night_lights.append(bl)
	_veg_mark_poly(poly, 3)
	_veg_mark_rect(quay.grow(T * 1.5), 1)
	_veg_mark_rect(quay, 2)
	# the docked-ship hook: a sprite at the berth, shown when Trade reports a ship in port
	harbour_ship = Sprite2D.new()
	harbour_ship.position = tp(hb["ship"])
	harbour_ship.z_index = 2
	harbour_ship.visible = false
	floor_layer.add_child(harbour_ship)
	var bob := harbour_ship.create_tween().set_loops()
	bob.tween_property(harbour_ship, "offset:y", 3.0, 2.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(harbour_ship, "offset:y", -3.0, 2.2).set_trans(Tween.TRANS_SINE)
	Events.day_started.connect(func(_d: int) -> void: refresh_harbour_ship())
	Events.hour_passed.connect(func(_d: int, _h: int) -> void: refresh_harbour_ship())
	refresh_harbour_ship()


## Shows the ship `Trade` reports in port at the berth (props/ship_spice, ship_barge, ship_whaler — drawn by the
## trade worker). Contract: static Trade.docked_ship() -> String returns "" (no ship) or a ship id ("spice" or
## "ship_spice"…). Guarded so the village works without the Trade system. The lead can also call
## `set_harbour_ship(id)` directly or connect a Trade signal to `refresh_harbour_ship()`.
func refresh_harbour_ship() -> void:
	var id := ""
	if ResourceLoader.exists("res://scripts/systems/trade.gd"):
		var tr: Script = load("res://scripts/systems/trade.gd")
		for m in tr.get_script_method_list():
			if str(m["name"]) == "docked_ship":
				id = str(tr.call("docked_ship"))
				break
	set_harbour_ship(id)


func set_harbour_ship(id: String) -> void:
	if harbour_ship == null:
		return
	if id != "" and not id.begins_with("ship_"):
		id = "ship_" + id
	harbour_ship_id = id
	if id == "" or not Assets.has_tex("props/" + id):
		harbour_ship.visible = false
		return
	harbour_ship.texture = Assets.get_tex("props/" + id, Vector2i(512, 192))
	harbour_ship.visible = true


# ----------------------------------------------------------------------- hand-placed dressing & ground wear
func _build_outdoor_props() -> void:
	for f in DB.layout.get("outdoor_props", []):
		_prop(str(f[0]), tp([f[1], f[2]]), deg_to_rad(float(f[3])) if f.size() > 3 else 0.0)


func _build_ground_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var size: Array = DB.layout["size"]
	var grass := Assets.get_tex("textures/grass", Vector2i(256, 256))
	# greener, lusher meadow patches and darker damp hollows break up the flat ground
	for i in 46:
		var c := Vector2(rng.randf_range(-2, float(size[0]) + 2), rng.randf_range(-2, float(size[1]) + 2)) * T
		var rad := Vector2(rng.randf_range(2.0, 5.5), rng.randf_range(1.6, 4.0)) * T
		# feathered into the grass (VillageGround.soft_patch), not hard-edged polygons
		VillageGround.soft_patch(ground_layer, _ellipse_poly(c, rad, 18, 0.16, i),
			Color(0.78, 0.86, 0.6, 0.42) if i % 3 != 0 else Color(0.6, 0.62, 0.46, 0.34), 0.55, grass)
	# grime along the foot of every wall (the trodden doorsteps are part of the road mask, VillageGround)
	for b in DB.layout.get("buildings", []):
		var r := brect(b)
		VillageGround.soft_ring(ground_layer, _rect_pts(r.grow(4)), 6.0, 30.0, Color(0.2, 0.13, 0.07, 0.26), false)
	# a glow and embers over the forge chimney: the smithy reads from the street, day and night
	var sm := DB.building("smithy")
	var chims: Array = sm.get("chimneys", [])
	if not chims.is_empty():
		var cp := brect(sm).position + Vector2(float(chims[0][0]) + 0.4, float(chims[0][1]) + 0.4) * T
		var fg := FX.light(Color("#ff7a26"), 230.0, 0.0, true)
		fg.position = cp
		fg.set_meta("gain", 1.3)
		fg.set_meta("roof", true)
		add_child(fg)
		night_lights.append(fg)
		var em := FX.embers(8)
		em.position = cp
		em.z_index = 45
		add_child(em)


## Point list offset sideways by `d` pixels (cart ruts along a road).
func _offset_line(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var dir := (b - a).normalized()
		out.append(pts[i] + Vector2(-dir.y, dir.x) * d)
	return out


# ----------------------------------------------------------------------- vegetation: groves & the woodland edge
## A coarse half-tile grid of where plants may not grow. Bit 1 blocks trees, bit 2 blocks undergrowth/flowers.
const VEG_CELL := 32.0
const VEG_PAD := 6
var _veg: PackedByteArray
var _veg_w := 0
var _veg_h := 0
var _trees_at: Dictionary = {}


func _veg_init() -> void:
	if _veg_w > 0:
		return
	var size: Array = DB.layout.get("size", [96, 64])
	_veg_w = int((float(size[0]) + VEG_PAD * 2) * T / VEG_CELL)
	_veg_h = int((float(size[1]) + VEG_PAD * 2) * T / VEG_CELL)
	_veg.resize(_veg_w * _veg_h)
	_veg.fill(0)


func _veg_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x + VEG_PAD * T) / VEG_CELL)), int(floor((p.y + VEG_PAD * T) / VEG_CELL)))


func _veg_get(p: Vector2) -> int:
	_veg_init()
	var c := _veg_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= _veg_w or c.y >= _veg_h:
		return 3
	return _veg[c.y * _veg_w + c.x]


func _veg_set_cells(a: Vector2i, b: Vector2i, bits: int, test: Callable) -> void:
	for y in range(maxi(a.y, 0), mini(b.y + 1, _veg_h)):
		for x in range(maxi(a.x, 0), mini(b.x + 1, _veg_w)):
			var centre := Vector2((x + 0.5) * VEG_CELL - VEG_PAD * T, (y + 0.5) * VEG_CELL - VEG_PAD * T)
			if test.call(centre):
				_veg[y * _veg_w + x] |= bits


func _veg_mark(p: Vector2, r: float, bits: int) -> void:
	_veg_init()
	_veg_set_cells(_veg_cell(p - Vector2(r, r)), _veg_cell(p + Vector2(r, r)), bits, func(c: Vector2) -> bool: return c.distance_to(p) <= r)


func _veg_mark_rect(r: Rect2, bits: int) -> void:
	_veg_init()
	_veg_set_cells(_veg_cell(r.position), _veg_cell(r.end), bits, func(_c: Vector2) -> bool: return true)


func _veg_mark_ellipse(c: Vector2, rad: Vector2, bits: int) -> void:
	_veg_init()
	_veg_set_cells(_veg_cell(c - rad), _veg_cell(c + rad), bits,
		func(p: Vector2) -> bool: return pow((p.x - c.x) / rad.x, 2) + pow((p.y - c.y) / rad.y, 2) <= 1.0)


func _veg_mark_poly(poly: PackedVector2Array, bits: int) -> void:
	_veg_init()
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	_veg_set_cells(_veg_cell(bb.position), _veg_cell(bb.end), bits, func(c: Vector2) -> bool: return Geometry2D.is_point_in_polygon(c, poly))


## A tree or shrub; outside the playable map it skips the collision body (the map border walls are there).
func _veg_prop(id: String, pos: Vector2, solid := true) -> void:
	if solid:
		_prop(id, pos)
		return
	var info: Dictionary = DB.props.get(id, {"size": [64, 64]})
	var h := float(info["size"][1])
	var holder := Node2D.new()
	holder.position = pos + Vector2(0, h * 0.3)
	var s := Sprite2D.new()
	s.texture = Assets.get_tex("props/" + id, Vector2i(int(info["size"][0]), int(h)))
	s.position = Vector2(0, -h * 0.3)
	if SWAY.has(id):
		s.material = _sway_material(id)
	holder.add_child(s)
	ysort.add_child(holder)


func _tree_free(p: Vector2, gap: float) -> bool:
	var c := _veg_cell(p)
	var k := int(ceil(gap / VEG_CELL))
	for y in range(c.y - k, c.y + k + 1):
		for x in range(c.x - k, c.x + k + 1):
			var key := y * 100000 + x
			if _trees_at.has(key) and (_trees_at[key] as Vector2).distance_to(p) < gap:
				return false
	return true


func _plant(kind: String, p: Vector2, gap: float, solid := true) -> bool:
	var bit := 1 if kind.begins_with("tree") else 2
	if _veg_get(p) & bit:
		return false
	if not _tree_free(p, gap):
		return false
	var c := _veg_cell(p)
	_trees_at[c.y * 100000 + c.x] = p
	_veg_prop(kind, p, solid)
	return true


func _build_vegetation(rng: RandomNumberGenerator) -> void:
	_veg_init()
	var size: Array = DB.layout["size"]
	var mw := float(size[0]) * T
	var mh := float(size[1]) * T
	# what may not be overgrown: buildings, roads, the square, the stream, exits, spots, props already placed
	for bid in buildings:
		if buildings[bid]["area"]:
			continue
		_veg_mark_rect((buildings[bid]["rect"] as Rect2).grow(T * 1.3), 1)
		_veg_mark_rect((buildings[bid]["rect"] as Rect2).grow(T * 0.3), 2)
	for r in DB.layout.get("roads", []):
		var half := float(r["width"]) * T * 0.5
		for p in _smooth(r["points"], 32.0):
			_veg_mark(p, half + T * 1.1, 1)
			_veg_mark(p, half + T * 0.3, 2)
	var st: Dictionary = DB.layout.get("stream", {})
	if not st.is_empty():
		for p in _smooth(st["points"], 32.0):
			_veg_mark(p, float(st["width"]) * T * 0.5 + T * 0.9, 3)
	var sq: Dictionary = DB.layout.get("square", {})
	if not sq.is_empty():
		_veg_mark_ellipse(tp(sq["center"]), tp(sq["radius"]) + Vector2(T * 2, T * 2), 1)
		_veg_mark_ellipse(tp(sq["center"]), tp(sq["radius"]) + Vector2(T * 0.4, T * 0.4), 2)
	for ex in DB.layout.get("exits", []):
		_veg_mark(tp(ex["pos"]), T * 5.0, 1)
		_veg_mark(tp(ex["pos"]), T * 2.6, 2)
	for kc in DB.layout.get("boundary", {}).get("keep_clear", []):
		_veg_mark_rect(Rect2(tp([kc[0], kc[1]]), Vector2(float(kc[2]), float(kc[3])) * T), 1)
	for cl in DB.layout.get("clearings", []):   # paddocks, yards, the camp, the stage: nothing grows there
		_veg_mark_rect(Rect2(tp([cl[0], cl[1]]), Vector2(float(cl[2]), float(cl[3])) * T), 3)
	for n in ysort.get_children():
		if n is Node2D:
			_veg_mark((n as Node2D).position, T * 1.15, 1)
			_veg_mark((n as Node2D).position, T * 0.75, 2)
	for f in DB.layout.get("outdoor_props", []):
		if str(f[0]) in ["crop_rows", "herb_garden", "mud_patch", "puddle"]:
			_veg_mark(tp([f[1], f[2]]), T * 1.6, 3)
	for name in spots:
		if not _inside_any_building(spots[name]):
			_veg_mark(spots[name], T * 1.0, 3)
	var tree_kinds := ["tree_oak_a", "tree_oak_b", "tree_pine", "tree_small", "tree_pine", "tree_oak_a"]
	var under_kinds := ["undergrowth", "fern", "bush", "undergrowth", "fern", "bush_flower"]
	# 1) the woodland boundary: a dense belt along the map edge and a ragged row just beyond it
	var bd: Dictionary = DB.layout.get("boundary", {})
	var depth := float(bd.get("depth", 3.5)) * T
	var sp := float(bd.get("spacing", 1.3)) * T
	var y := -2.4 * T
	while y < mh + 2.4 * T:
		var x := -2.4 * T
		while x < mw + 2.4 * T:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.42, 0.42)) * sp
			var edge := minf(minf(p.x, mw - p.x), minf(p.y, mh - p.y))
			var outside := edge < 0.0
			var east_wood := p.x > 91.6 * T and p.y < 46.0 * T
			if edge < depth or east_wood:
				var dense := 1.0 - clampf(edge / depth, 0.0, 1.0) * 0.45
				if rng.randf() < dense:
					var kind: String = tree_kinds[rng.randi() % tree_kinds.size()]
					if not _plant(kind, p, sp * 0.82, not outside):
						if not outside and rng.randf() < 0.7:
							_plant(under_kinds[rng.randi() % under_kinds.size()], p, T * 0.7)
					elif not outside and rng.randf() < 0.55:
						# undergrowth on the inner side of the trunk
						var inward := (Vector2(mw * 0.5, mh * 0.5) - p).normalized()
						_plant(under_kinds[rng.randi() % under_kinds.size()], p + inward * T * rng.randf_range(0.9, 1.4), T * 0.7)
			x += sp
		y += sp
	# 2) groves: clustered trees, the biggest near the middle, fringed with shrubs, ferns and brambles
	for g in DB.layout.get("groves", []):
		var gc := tp([g[0], g[1]])
		var gr := float(g[2]) * T
		var want := int(float(g[3]) * PI * pow(float(g[2]), 2) / 2.2) + 1
		var tries := 0
		while want > 0 and tries < 260:
			tries += 1
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * gr
			var gp := gc + Vector2(cos(a), sin(a)) * d
			var kind2: String = ["tree_oak_a", "tree_oak_b", "tree_pine"][rng.randi() % 3] if d < gr * 0.55 else tree_kinds[rng.randi() % tree_kinds.size()]
			if _plant(kind2, gp, T * 1.35):
				want -= 1
		for k in int(float(g[2]) * 5.0):
			var a2 := rng.randf() * TAU
			_plant(under_kinds[rng.randi() % under_kinds.size()], gc + Vector2(cos(a2), sin(a2)) * gr * rng.randf_range(0.7, 1.25), T * 0.75)
	# 3) the open meadow: a few lone shrubs, rocks, flowers and stumps
	var want2 := {"bush": 26, "bush_flower": 18, "rock_a": 16, "rock_b": 10, "flowers": 50, "flower_patch_a": 40, "flower_patch_b": 40,
		"fern": 20, "stump": 8, "tree_small": 10}
	for kind3 in want2:
		var n2: int = want2[kind3]
		var tries2 := 0
		while n2 > 0 and tries2 < 1500:
			tries2 += 1
			var p3 := Vector2(rng.randf_range(2, float(size[0]) - 2) * T, rng.randf_range(2, float(size[1]) - 2) * T)
			if _plant(kind3, p3, T * (1.6 if kind3.begins_with("tree") else 0.9)):
				n2 -= 1


# ----------------------------------------------------------------------- night dressing: lit windows, light masks
var _window_glows: Array = []


## Roofs only take light from street lamps, windows and the forge chimney (light mask 2), never from candles and
## hearths inside (mask 1), so interiors no longer bleed through the roofs by day. At night every house shows
## warm lit windows along its eaves (children of the roof, so they fade with it when you step inside).
## Light masks: 1 = interiors and actors, 2 = roofs, 4 = outdoor ground and props, 8 = lit window panes.
## Interior lights (candles, hearths, stations) keep the default cull mask 1; street lights cull 1|4.
func _build_night_dressing() -> void:
	for l in night_lights:
		(l as PointLight2D).range_item_cull_mask = 7 if l.get_meta("roof", false) else 5
	for ch in ground_layer.get_children():
		(ch as CanvasItem).light_mask = 4
	for ch in floor_layer.get_children():
		if ch is Sprite2D and not _inside_any_building((ch as Sprite2D).position):
			(ch as CanvasItem).light_mask = 5
	for ch in ysort.get_children():
		if ch is Node2D and ch.get_child_count() > 0 and ch.get_child(0) is Sprite2D and not _inside_any_building((ch as Node2D).position):
			(ch.get_child(0) as CanvasItem).light_mask = 5
	for bid in buildings:
		var info: Dictionary = buildings[bid]
		var roof: Sprite2D = info["roof"]
		if roof == null:
			continue
		roof.light_mask = 2
		var r: Rect2 = info["rect"]
		var b := DB.building(bid)
		var sides := ["n", "s"] if b.get("ridge", "h") == "h" else ["w", "e"]
		var rng := RandomNumberGenerator.new()
		rng.seed = bid.hash()
		for side in sides:
			var length := r.size.x if side in ["n", "s"] else r.size.y
			var n := maxi(1, int(length / (3.4 * T)))
			for i in n:
				var t := (i + 0.5) / n + rng.randf_range(-0.06, 0.06)
				var local: Vector2
				var sz := Vector2(30, 9) if side in ["n", "s"] else Vector2(9, 30)
				match side:
					"n": local = Vector2(r.size.x * t, 9)
					"s": local = Vector2(r.size.x * t, r.size.y - 9)
					"w": local = Vector2(9, r.size.y * t)
					_: local = Vector2(r.size.x - 9, r.size.y * t)
				var win := Polygon2D.new()
				# the roof sprite is scaled to the building: draw in its local (texture) space
				win.polygon = _rect_pts(Rect2((local - sz * 0.5) / roof.scale, sz / roof.scale))
				win.color = Color(1.0, 0.78, 0.4)
				win.light_mask = 8
				win.modulate.a = 0.0
				roof.add_child(win)
				_window_glows.append(win)
				if i % 2 == 0:
					var wl := FX.light(Color("#ffae58"), 120.0, 0.0)
					wl.position = r.position + local + _side_vec(side) * 26.0
					wl.range_item_cull_mask = 5
					wl.set_meta("gain", 0.8)
					add_child(wl)
					night_lights.append(wl)
		# one light per house that only lights its window panes (mask 8), so the panes glow without lighting the roof
		var pane := FX.light(Color("#ffc070"), r.size.length() * 0.6, 0.0)
		pane.position = r.get_center()
		pane.range_item_cull_mask = 8
		pane.set_meta("gain", 2.4)
		add_child(pane)
		night_lights.append(pane)


func _side_vec(side: String) -> Vector2:
	return {"n": Vector2.UP, "s": Vector2.DOWN, "w": Vector2.LEFT, "e": Vector2.RIGHT}[side]


# ----------------------------------------------------------------------- more animals
const ANIMALS_EXTRA := [["animal_cat_2", [86.0, 52.4], 220.0], ["animal_dog_1", [10.2, 27.6], 200.0], ["animal_cat_1", [35.0, 11.8], 160.0]]


func _place_animals_extra() -> void:
	for a in ANIMALS_EXTRA:
		var an := AnimalActor.new()
		an.setup(a[0], tp(a[1]), float(a[2]), Rect2(), self)
		ysort.add_child(an)
		animals.append(an)


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
	# S2 (OBS-13/14): every bag on clear floor in the stock hall — never under the Loft stair or the hoist, nor in a doorway
	var at := Property.drop_spots(returns.size())
	for i in returns.size():
		var pos: Vector2 = bpos(Property.BID, (at[i] as Vector2).x, (at[i] as Vector2).y)
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
	# outdoor spots: every named spot that is not inside a building or an area
	for name in spots.keys():
		if not _inside_any_building(spots[name]):
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
	# stairs join floors: the arrival spot of each stairway links to the arrival spot on the other side
	for e in interactables:
		if not (e["kind"] in ["stairs", "lift"]):
			continue
		var pre := "lift_" if e["kind"] == "lift" else "stairs_"   # the smithy's aetheric lift has its own spots
		var there: String = pre + str(e["id"])
		var here := ""
		for bid in buildings:
			if (buildings[bid]["rect"] as Rect2).has_point(e["pos"]):
				here = pre + bid
		if spot_ids.has(here) and spot_ids.has(there) and not astar.are_points_connected(spot_ids[here], spot_ids[there]):
			astar.connect_points(spot_ids[here], spot_ids[there])


func _inside_any_building(p: Vector2) -> bool:
	for bid in buildings:
		if (buildings[bid]["rect"] as Rect2).has_point(p):
			return true
	return false


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
	if Rect2(104 * T, 10 * T, 20 * T, 14 * T).has_point(player.position):
		player.position += Vector2((118 - 104) * T, 0)   # saved upstairs before iteration 009 moved the area east
	ysort.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()
	_set_camera_limits()


func _set_camera_limits() -> void:
	var r: Rect2
	if buildings.get(area, {}).get("area", false):
		r = (buildings[area]["rect"] as Rect2).grow(400)
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
	if Memorial.funeral_spot(id) != "":   # a funeral morning gathers the village at the graveside
		return Memorial.funeral_spot(id)
	for cu in Shop.customers():
		if cu["npc"] == id:
			return "wait_seat_%d" % int(cu.get("seat", 0))
	var cer := Ceremony.spot_for(id, spots)   # a ceremony in the square overrides the day's routine
	if cer != "":
		return cer
	var hire := Hire.get_h(id)
	if not hire.is_empty():
		var hold := Hire.tutorial_spot(hire)   # S2: Borin waits in the smithy for his first talk on a new game
		if hold != "":
			return hold
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
		if a["status"] in ["away", "dead", "missing", "gone"]:   # "gone": retired and left Brindlewick (Living)
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
		return ["square_%d" % (seed % 6), "notice", "well", "inn_garden", "square_%d" % ((seed + 3) % 6), "pond_%d" % (1 + seed % 3),
			"harbour_quay"][(seed + h) % 7]
	var cs := Commerce.spot_for(id, h)   # caravan master, pawnbroker, rival smith, the Hales
	if cs != "-":
		return cs if spots.has(cs) else ""
	match id:
		"aldric":
			if Venues.keeper_away("general_store", h) != "":   # the weekly delivery: at the smithy door (hours: Venues)
				return "smithy_door_out"
			return "grocery_behind" if Venues.in_hours("general_store", h) else ("inn_t2b" if h >= 19 and h < 21 else "")
		"hilde":
			return "inn_behind_bar" if Venues.in_hours("inn", h) else ""
		"wenna":
			if h >= 11 and h < 24:
				return ["inn_t1b", "inn_t3b", "inn_t4", "inn_bar", "inn_t6b", "inn_t2"][h % 6]
			return ""
		"martha":
			if h >= 15 and h < 17:
				return "pond_1"   # an afternoon on the pond bench
			return "well" if h >= 8 and h < 12 else ("house_martha_inside" if h < 21 else "")
		"tobin":
			return "house_tobin_inside" if h >= 8 and h < 17 else ("inn_t4b" if h < 21 else "")
		"oswin":
			return "house_oswin_inside" if h >= 6 and h < 21 else ""
		"jory":
			if h >= 7 and h < 11:
				return "fields"
			if h >= 15 and h < 18:
				return "pond_3"
			return "house_jory_inside" if h >= 7 and h < 15 else (["square_2", "inn_t5b"][int(h >= 18)] if h < 21 else "")
		"eda":
			if h >= 13 and h < 16:
				return "pond_2"
			return "well" if h >= 8 and h < 16 else ("square_4" if h < 20 else "")
		"barnaby":
			# the Ironfront host: his parlour by day, the basement den in the evening
			if Venues.in_hours("ironfront", h):
				return "ironfront_host"
			if h >= 12 and h < 14:
				return "inn_t6b"
			return "barnaby_house_inside" if h >= 8 and h < 17 else ""
		"herbalist":
			return "herbalist_counter" if Venues.in_hours("herbalist", h) else ("pond_3" if h >= 18 and h < 20 else "")
		"harbourmaster":
			return "harbour_quay" if Venues.in_hours("harbour", h) else ("inn_bar" if h >= 19 and h < 22 else "")
		"rosalind":
			return "lantern_3"
		# the pawnbroker, the rival smith, the Hales and the caravan master are placed by Commerce.spot_for above
		# (their counter hours come from Venues)
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
		if n.get_meta("travelling", false) or n.get_meta("apprentice", false):
			continue   # apprentices follow their shift (ApprenticeActors)
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
	if home.begins_with("house_") or spots.has(home + "_inside"):
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
	_amb_t += delta
	if _amb_t > 1.5 and area == "village":
		_amb_t = 0.0
		var w := _water_zone()
		if w != _water_amb:
			_water_amb = w
			_update_ambience()
	_update_focus()
	_update_light(false)
	Ceremony.tick(player.position, spots, delta)
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
	_update_ambience()
	Events.toast.emit(buildings.get(area, {}).get("name", "Brindlewick"), "area")


## Ambience bed + music for where the player is and the time of day: the village day loop gives way to
## the night loop at dusk (and back at dawn), cottages and shops muffle the street, the inn and the
## basement den carry the tavern murmur.
var _amb_t := 0.0
var _water_amb := ""


func _water_zone() -> String:
	if spots.has("harbour_quay") and player.position.distance_to(spots["harbour_quay"]) < 900.0:
		return "harbour"
	if spots.has("pond_1") and player.position.distance_to(spots["pond_1"]) < 600.0:
		return "pond"
	return ""


func _update_ambience() -> void:
	var night := Game.is_night() or night_factor > 0.5
	match area:
		"smithy":
			Audio.set_ambience("bed", "amb/workshop_loop", -4.0)
			Audio.play_music("music/hearth_day")
		"inn":
			Audio.set_ambience("bed", "amb/tavern_loop", -6.0)
			Audio.play_music("music/tavern")
		"inn_upstairs":
			Audio.set_ambience("bed", "amb/lantern", -16.0)
			Audio.play_music("music/lantern")
		"ironfront_basement":
			Audio.set_ambience("bed", "amb/tavern_loop", -18.0)
			Audio.play_music("music/ironfront")
		"village":
			# by the water the harbour (or the pond) takes over the street sounds
			var near_water := ""
			if spots.has("harbour_quay") and player.position.distance_to(spots["harbour_quay"]) < 900.0:
				near_water = "amb/harbour"
			elif spots.has("pond_1") and player.position.distance_to(spots["pond_1"]) < 600.0:
				near_water = "amb/pond"
			Audio.set_ambience("bed", near_water if near_water != "" else ("amb/village_night_loop" if night else "amb/village_day_loop"), -6.0)
			Audio.play_music("music/village_evening" if Game.hour() >= 17 or night else "music/hearth_day")
		_:
			# other houses and shops: the street outside, muffled by the walls
			Audio.set_ambience("bed", "amb/village_night_loop" if night else "amb/village_day_loop", -15.0)
			Audio.play_music("music/village_evening" if Game.hour() >= 17 or night else "music/hearth_day")


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
	if best.get("kind", "") == "station":
		# iteration 012: a station an apprentice is using says so (the smith still takes it; they step aside)
		var lab := ApprenticeActors.station_prompt(str(best["id"]), str(best.get("label", "")))
		if lab != str(best.get("label", "")):
			best = best.duplicate()
			best["label"] = lab
	# the prompt lists what can be done here (WorldPrompts); rebuilt when the focus changes and every second
	var key := "%s/%s/%s" % [best.get("kind", ""), best.get("id", ""), best.get("label", "")]
	_prompt_t += get_process_delta_time()
	if key != _focus_key or (not best.is_empty() and _prompt_t > 1.0):
		_prompt_t = 0.0
		var changed := key != _focus_key
		_focus_key = key
		_focus = best
		var pr := WorldPrompts.for_entity(best, area) if not best.is_empty() else {}
		if changed or pr != _prompt:
			_prompt = pr
			Events.open_panel.emit("prompt", pr if not pr.is_empty() else {"text": ""})
		if changed:
			_set_highlight(best)
	if _hl_ring and _hl_ring.visible:
		_hl_t += get_process_delta_time()
		_hl_ring.modulate.a = 0.55 + 0.35 * sin(_hl_t * 4.0)
		if _focus.get("kind", "") == "npc" and npcs.has(_focus.get("id", "")):
			_hl_ring.position = (npcs[_focus["id"]] as Node2D).position + Vector2(0, 6)
	_update_hint(ppos)


# ----------------------------------------------------------------------- S2: contextual hint
## A restrained cue for the nearest station or person within a few steps that has something for the smith NOW (the
## station of his next step or one where a recipe is ready to begin; a customer to serve, a delivery…), before he is in
## reach: one faint, slowly breathing ring at a time, no brightening. The gilt focus ring takes over in reach.
const HINT_RANGE := 320.0
const HINT_EVERY := 0.4
var _hint_ring: Line2D
var _hint := {}
var _hint_t := 0.0
var _hint_phase := 0.0


## Is there something to do at this station now? Unlocked, and either the current job's next station or (no job) one
## where a recipe could begin; the Project Bench while a contract is in hand.
static func station_usable(sid: String) -> bool:
	if sid == Contracts.BENCH:
		return Contracts.bench_installed() and not Contracts.active().is_empty()
	if not Property.is_installed(sid) or Crafting.station_locked_reason(sid) != "":
		return false
	if Crafting.active():
		return Crafting.current_station() == sid
	return WorldPrompts._ready_count(sid) > 0


## Does this person have something for the smith now beyond small talk (WorldPrompts' verbs)?
static func person_usable(npc: String, where := "village") -> bool:
	if npc.begins_with("app_"):
		return false
	for a in WorldPrompts.npc_actions(npc, where)["actions"]:
		if str(a) != "Talk":
			return true
	return false


## Pure: the nearest usable candidate ({kind, id, pos, usable}) within `max_d` of `from`, except `skip` ("kind/id").
static func hint_pick(from: Vector2, cands: Array, skip := "", max_d := HINT_RANGE) -> Dictionary:
	var best := {}
	var best_d := max_d
	for c: Dictionary in cands:
		if not bool(c.get("usable", false)) or "%s/%s" % [c.get("kind", ""), c.get("id", "")] == skip:
			continue
		var d := from.distance_to(c["pos"])
		if d < best_d:
			best_d = d
			best = c
	return best


## The candidates around `from`: interactable stations and visible people in range (usability asked only of those).
func hint_candidates(from: Vector2) -> Array:
	var out := []
	for e in interactables:
		if str(e.get("kind", "")) == "station" and from.distance_to(e["pos"]) < HINT_RANGE:
			out.append({"kind": "station", "id": str(e["id"]), "pos": e["pos"], "usable": station_usable(str(e["id"]))})
	for id in npcs:
		var n: NPCActor = npcs[id]
		if n.visible and from.distance_to(n.position) < HINT_RANGE:
			out.append({"kind": "npc", "id": str(id), "pos": n.position, "usable": person_usable(str(id), area)})
	return out


func _update_hint(ppos: Vector2) -> void:
	var dt := get_process_delta_time()
	_hint_t -= dt
	if _hint_t <= 0.0:
		_hint_t = HINT_EVERY
		var skip := "%s/%s" % [_focus.get("kind", ""), _focus.get("id", "")]
		_hint = hint_pick(ppos, hint_candidates(ppos), skip) if Game.ui_blockers == 0 and not Steward.smith_away() else {}
	if _hint_ring == null:
		_hint_ring = Line2D.new()
		_hint_ring.name = "HintRing"
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector2(cos(a) * 46.0, sin(a) * 22.0))
		_hint_ring.points = pts
		_hint_ring.width = 2.5
		_hint_ring.default_color = Color("#e8c060")
		_hint_ring.z_index = 2   # above the floor, the station bases and the forge shade; below every figure
		floor_layer.add_child(_hint_ring)
	_hint_ring.visible = not _hint.is_empty()
	if _hint.is_empty():
		return
	var pos: Vector2 = _hint["pos"]
	var radius := 34.0
	if str(_hint["kind"]) == "station":
		var size: Array = DB.station(str(_hint["id"])).get("size", [96, 96])
		radius = float(size[0]) * 0.55
		pos += Vector2(0, float(size[1]) * 0.42)
	elif npcs.has(_hint["id"]):
		pos = (npcs[_hint["id"]] as Node2D).position + Vector2(0, 6)
	_hint_phase += dt
	_hint_ring.scale = Vector2(radius / 46.0, radius / 46.0)
	_hint_ring.position = pos
	_hint_ring.modulate.a = 0.34 + 0.14 * sin(_hint_phase * 1.6)


var _focus_key := "//"
var _prompt := {}
var _prompt_t := 0.0
var _hl_ring: Line2D
var _hl_sprite: CanvasItem
var _hl_t := 0.0


## Highlights whatever the smith would use: a gilt ring on the floor and a brighter sprite for stations.
func _set_highlight(e: Dictionary) -> void:
	if _hl_ring == null:
		_hl_ring = Line2D.new()
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector2(cos(a) * 46.0, sin(a) * 22.0))
		_hl_ring.points = pts
		_hl_ring.width = 3.5
		_hl_ring.default_color = Color("#e8c060")
		_hl_ring.z_index = 2   # S2: was -1, under the interior floors (the ring showed only outdoors)
		floor_layer.add_child(_hl_ring)
	if is_instance_valid(_hl_sprite):
		_hl_sprite.self_modulate = Color.WHITE
	_hl_sprite = null
	if e.is_empty():
		_hl_ring.visible = false
		return
	_hl_ring.visible = true
	var pos: Vector2 = e.get("pos", Vector2.ZERO)
	var radius := 46.0
	if e.get("kind", "") == "station" and station_sprites.has(e.get("id", "")):
		var size: Array = DB.station(str(e["id"]))["size"]
		radius = float(size[0]) * 0.55
		pos += Vector2(0, float(size[1]) * 0.42)
		_hl_sprite = station_sprites[e["id"]]
		_hl_sprite.self_modulate = Color(1.18, 1.12, 0.98)
	elif e.get("kind", "") == "npc":
		radius = 34.0
		pos += Vector2(0, 6)
	_hl_ring.scale = Vector2(radius / 46.0, radius / 46.0)
	_hl_ring.position = pos


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and Game.ui_blockers == 0 and not _focus.is_empty():
		get_viewport().set_input_as_handled()
		interact(_focus)


func interact(e: Dictionary) -> void:
	# Steward Mode: the smith is away — he cannot use, talk or trade until he takes the workshop back
	if Steward.smith_away():
		Audio.play("sfx/error", -8.0)
		Events.toast.emit(StewardUI.away_block("station"), "info")
		return
	# a shop counter respects its keeper's hours (Venues): closed counters say when they open instead
	var vid := Venues.venue_for_entity(str(e.get("kind", "")), str(e.get("id", "")))
	if vid != "" and not Venues.is_open(vid):
		Audio.play("sfx/error", -8.0)
		Events.toast.emit("%s — %s." % [Venues.get_v(vid)["name"], Venues.status_text(vid)], "info")
		return
	match e["kind"]:
		"store":   # Pell's Provisions and any other restocking counter (HerbalistPanel, Trade.store_stock)
			Events.open_panel.emit("store", {"id": e["id"]})
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
			if n.get_meta("apprentice", false):
				Events.open_panel.emit("apprentice", {"id": e["id"]})   # iteration 012: a word with a workshop apprentice
			else:
				Events.open_panel.emit("dialogue", {"npc": e["id"], "area": area})
		"bed":
			Events.open_panel.emit("sleep", {})
		"ledger":
			Events.open_panel.emit("shop", {"tab": "ledger"})
		"wanted":
			Events.open_panel.emit("wanted", {})
		"harbour", "herbalist", "ironfront", "property", "customize", "help", "designer", "skilltree", \
				"pawn", "rival_smith", "creatures", "caravan", "hall_of_fame":
			# venues and desks added in iteration 009 open their panel; the id travels along
			Events.open_panel.emit(e["kind"], {"id": e["id"]})
		"vase", "grave", "ghost", "remembrance_flowers":   # remembrance (MemorialWorld)
			(get_node("MemorialWorld") as MemorialWorld).interact(e)
		"bag":
			Events.open_panel.emit("loot", {"uid": int(e["id"])})
		"eggs":
			Sim.clean_eggs()
			Audio.play("sfx/water")
			Events.toast.emit("You scrub the shop front clean. Somebody in this village is cross with you.", "info")
		"stairs":
			# stairs lead to building/area `id`; you arrive at its "stairs_<id>" spot (inn ↔ upstairs, house ↔ basement…)
			var arrive: String = "stairs_" + str(e["id"])
			if spots.has(arrive):
				player.position = spots[arrive]
				Audio.play("sfx/door", -4.0)
				camera.reset_smoothing()
		"lift":
			# The Living Realm: the smithy's aetheric lift — one step between the floors (arrival spot "lift_<area>")
			var arrive_l: String = "lift_" + str(e["id"])
			if spots.has(arrive_l):
				if PlayerNav.of(self) != null:
					PlayerNav.of(self).cancel()
				player.position = spots[arrive_l]
				Audio.play("sfx/arcane", -6.0)
				camera.reset_smoothing()
				var fl := FX.light(Color("#9a6cff"), 260.0, 1.3)
				fl.position = player.position
				add_child(fl)
				var tw := fl.create_tween()
				tw.tween_property(fl, "energy", 0.0, 0.8)
				tw.tween_callback(fl.queue_free)
		"exit":
			var ex := {}
			for x in DB.layout["exits"]:
				if x["id"] == e["id"]:
					ex = x
			var dest: Dictionary = DB.destinations.get(ex.get("region", ""), {})
			Events.toast.emit("%s — %s Send hirelings from the Hirelings ledger [H]." % [ex.get("label", ""), dest.get("desc", "")], "info")


# ======================================================================= the smith's property
## Which floor of the smithy a building/area record draws ("" = not the smithy): the building itself is the ground
## floor; an area with "floor_of": "smithy" is an upper floor (the Loft). Upper floors keep Property's PLAN coordinates
## (see tools/data/smithy_layout.py): their area lies at the smithy's origin + the floor's offset, so a plan position
## p is always drawn at bpos("smithy", p) — stations, stairs and the lift need no conversion; rooms, doorways and
## furniture of an area are shifted back by the offset into the area's own coordinates.
func _smithy_floor_of(b: Dictionary, is_area: bool) -> String:
	if not is_area:
		return "ground" if str(b.get("id", "")) == Property.BID else ""
	if str(b.get("floor_of", "")) != Property.BID:
		return ""
	for f in Property.floors():
		if str(f.get("area", "")) == str(b["id"]):
			return str(f["id"])
	return ""


func _rooms_on(fid: String) -> Array:
	return Property.rooms().filter(func(rm): return Property.floor_of_room(rm) == fid)


## The smithy as the smith owns and arranged it: his rooms and partitions, open and locked doors, the
## neighbours' furnishings in rooms he has not bought, workshop clutter where his stations stand.
func _smithy_view(src: Dictionary, fid := "ground") -> Dictionary:
	var off := Property.floor_rect(fid).position
	var b := src.duplicate()
	var rooms := []
	for rm in _rooms_on(fid):
		var r2: Dictionary = (rm as Dictionary).duplicate(true)
		var a: Array = r2["rect"]
		r2["rect"] = [float(a[0]) - off.x, float(a[1]) - off.y, float(a[2]), float(a[3])]
		if not Property.room_owned(rm):
			var t: Array = r2.get("tint", [1.0, 1.0, 1.0])
			r2["tint"] = [float(t[0]) * 0.62, float(t[1]) * 0.58, float(t[2]) * 0.55]
		rooms.append(r2)
	b["rooms"] = rooms
	var open := []
	for d in Property.doors():
		if not Property.door_open(Property.st(), d):
			continue
		var e := Property._door_edge(Property.st(), d)
		if e.is_empty() or Property.floor_of_point(Property.door_center(Property.st(), d)) != fid:
			continue
		var d2: Dictionary = (d as Dictionary).duplicate(true)
		d2["at"] = float(d["at"]) - (off.y if bool(e[0]) else off.x)
		open.append(d2)
	b["room_doors"] = open
	b["furniture"] = _smithy_furniture(src, fid)
	if fid == "ground":
		var inter := []
		for it in src.get("interact", []):
			var ip: Array = it["pos"]
			var host := Property.room_at_tile(Property.rooms(), Vector2(float(ip[0]), float(ip[1])))
			if not host.is_empty() and Property.room_owned(host):
				inter.append(it)
		b["interact"] = inter
		b["spots"] = _smithy_spots(src)
	return b


func _prop_rect_tiles(id: String, p: Vector2, rot_deg := 0.0) -> Rect2:
	var info: Dictionary = DB.props.get(id, {"size": [64, 64]})
	var sz := Vector2(float(info["size"][0]), float(info["size"][1])) / T
	if int(round(rot_deg / 90.0)) % 2 != 0:
		sz = Vector2(sz.y, sz.x)   # a quarter turn swaps the footprint
	return Rect2(p - sz * 0.5, sz)


## Would a piece of furniture at tile `p` clash with a station, block a doorway, straddle a wall or stand on the
## stairwell or the hoist shaft? (plan coordinates)
func _furniture_clashes(id: String, p: Vector2, host: Dictionary, rot_deg := 0.0) -> bool:
	var fr := _prop_rect_tiles(id, p, rot_deg).grow(-0.08)
	if not Property.rect(host).grow(0.15).encloses(fr):
		return true
	for sid in Property.st()["stations"]:
		if Property.is_installed(sid) and fr.intersects(Property.footprint(sid, Property.st()["stations"][sid]).grow(0.15)):
			return true
	for d in Property.doors():
		var c := Property.door_center(Property.st(), d)
		if c != Vector2.INF and fr.grow(0.55).has_point(c):
			return true
	for rv: Rect2 in Property.reserved_rects():
		if fr.intersects(rv):
			return true
	return false


const CLUTTER := {
	"classic": ["coal_pile", "iron_bars", "ore_pile", "soot_decal"],
	"runecraft": ["stone_blocks", "rune_glyph_decal", "rune_shelf", "candle"],
	"alchemy": ["ingredient_crates", "spill_decal", "bottle_shelf", "herb_rack"],
	"stitching": ["leather_bundle", "hide_rack", "thread_spools", "pattern_board"],
	"arcane": ["arcane_rack", "arcane_glyph_decal", "candle", "crate"],
}
## The Living Realm: what an Established room of each craft adds along a wall (a rack of the trade's tools).
const TIER_RACK := {"classic": "weapon_rack", "runecraft": "rune_shelf", "alchemy": "bottle_shelf", "stitching": "pattern_board",
	"arcane": "arcane_rack"}
var _smithy_furn := {}     # floor id -> furniture shown on it (local coords), for the banners
var smithy_dressed := {}   # floor id -> the tier dressing placed on it (local coords; tests and screenshots read it)


func _smithy_furniture(src: Dictionary, fid := "ground") -> Array:
	var off := Property.floor_rect(fid).position
	var out := []
	var rooms := Property.rooms()
	var decorated := {}
	for f in src.get("furniture", []):
		var p := Vector2(float(f[1]), float(f[2])) + off
		var host := Property.room_at_tile(rooms, p)
		if host.is_empty():
			continue
		var owned := Property.room_owned(host)
		var tag := str(f[4]) if (f as Array).size() > 4 else ""
		var show := true
		if tag == "occ":
			show = not owned
		elif tag == "own":
			show = owned
		elif tag == "bare":
			show = owned and Property.stations_in(host).is_empty()
		elif tag.begins_with("ws:"):
			show = owned and Property.room_discipline(host) == tag.substr(3)
			if show:
				decorated[str(host["id"])] = true
		if show and owned and _furniture_clashes(str(f[0]), p, host, float(f[3]) if (f as Array).size() > 3 else 0.0):
			show = false
		if show:
			out.append(f)
	# rooms the smith has turned into workshops get the clutter of their trade
	for rm in _rooms_on(fid):
		if not Property.room_owned(rm) or decorated.has(str(rm["id"])):
			continue
		var disc := Property.room_discipline(rm)
		if disc == "" or not CLUTTER.has(disc) or str(rm["id"]) == "forge_room":
			continue
		var rr := Property.rect(rm)
		var corners := [rr.position + Vector2(0.9, 0.9), Vector2(rr.end.x - 0.9, rr.position.y + 0.9), Vector2(rr.position.x + 0.9, rr.end.y - 0.9), rr.end - Vector2(0.9, 0.9)]
		var items: Array = CLUTTER[disc]
		for i in corners.size():
			var c: Vector2 = corners[i]
			var pid: String = items[i % items.size()]
			if not _furniture_clashes(pid, c, rm) and not _hits_any(_prop_rect_tiles(pid, c), out, off):
				out.append([pid, c.x - off.x, c.y - off.y, 0])
	var dressed := smithy_dressing(fid, out)
	out.append_array(dressed)
	_smithy_furn[fid] = out
	smithy_dressed[fid] = dressed
	return out


## Furniture rects (plan coordinates) of a local-coordinate furniture list.
func _furn_rects(list: Array, off: Vector2) -> Array:
	var out := []
	for f in list:
		out.append(_prop_rect_tiles(str(f[0]), Vector2(float(f[1]), float(f[2])) + off, float(f[3]) if (f as Array).size() > 3 else 0.0))
	return out


## Like _hits_any, but only solid furniture counts (a name may be painted across a rug or a soot mark).
func _hits_solid(r: Rect2, list: Array, off: Vector2) -> bool:
	for f in list:
		if not bool(DB.props.get(str(f[0]), {}).get("solid", true)):
			continue
		var fr := _prop_rect_tiles(str(f[0]), Vector2(float(f[1]), float(f[2])) + off, float(f[3]) if (f as Array).size() > 3 else 0.0)
		if fr.grow(-0.05).intersects(r):
			return true
	return false


func _hits_any(r: Rect2, list: Array, off: Vector2) -> bool:
	for fr: Rect2 in _furn_rects(list, off):
		if fr.grow(-0.05).intersects(r):
			return true
	return false


## The Living Realm — rooms that grow with the smith. For every owned workshop room with a craft, by its tier
## (Smithy.room_tier: skill in the craft, its stations in the room, the workshop's renown): Established adds a
## runner on the floor and a rack of the trade on a wall; Masterwork a red rug instead, a plaque wall of famous work
## and two standing lamps. Deterministic candidate order; solid pieces keep 0.7 tiles from every station (its
## working sides stay free) and 1.4 from every doorway, and nothing lands on the stairwell, the hoist or other
## furniture — so the dressing never blocks a station, a door or the walk grid. Returns local-coordinate entries.
func smithy_dressing(fid: String, existing: Array) -> Array:
	var off := Property.floor_rect(fid).position
	var out := []
	for rm in _rooms_on(fid):
		if not Property.room_owned(rm) or Property.kind(rm) != "workshop":
			continue
		var disc := Smithy.trade(rm)
		var tier := Smithy.room_tier(rm)
		if disc == "" or tier < 1:
			continue
		var want: Array = [[("rug_red" if tier >= 2 else "rug_brown"), "floor"], [str(TIER_RACK.get(disc, "shelf")), "wall"]]
		if tier >= 2:
			want.append(["trophy_wall", "wall"])
			want.append(["standing_lamp", "corner"])
			want.append(["standing_lamp", "corner"])
		for wv in want:
			var pick := _dress_spot(str(wv[0]), str(wv[1]), rm, existing + out, off)
			if not pick.is_empty():
				out.append([str(wv[0]), float(pick[0]) - off.x, float(pick[1]) - off.y, float(pick[2])])
	return out


## A free spot for one piece of dressing in room `rm`: [x, y, rot] in plan coordinates, or [].
func _dress_spot(pid: String, how: String, rm: Dictionary, placed: Array, off: Vector2) -> Array:
	var rr := Property.rect(rm)
	var info: Dictionary = DB.props.get(pid, {"size": [64, 64], "solid": true})
	var sz := Vector2(float(info["size"][0]), float(info["size"][1])) / T
	var solid := bool(info.get("solid", true))
	var cands := []
	var steps_x := []   # offsets from the centre outwards, every half tile, across the whole room
	var steps_y := []
	for k in range(0, int(rr.size.x) * 2 + 1):
		steps_x.append((0.5 * ceil(k / 2.0)) * (1.0 if k % 2 == 0 else -1.0))
	for k in range(0, int(rr.size.y) * 2 + 1):
		steps_y.append((0.5 * ceil(k / 2.0)) * (1.0 if k % 2 == 0 else -1.0))
	match how:
		"wall":
			for k: float in steps_x:
				cands.append([rr.get_center().x + k, rr.position.y + sz.y * 0.5 + 0.06, 0.0])
			for k2: float in steps_x:
				cands.append([rr.get_center().x + k2, rr.end.y - sz.y * 0.5 - 0.06, 180.0])
			for k3: float in steps_y:
				cands.append([rr.position.x + sz.y * 0.5 + 0.06, rr.get_center().y + k3, 90.0])
				cands.append([rr.end.x - sz.y * 0.5 - 0.06, rr.get_center().y + k3, 270.0])
		"corner":
			for c in [rr.position + Vector2(0.55, 0.55), Vector2(rr.end.x - 0.55, rr.position.y + 0.55), Vector2(rr.position.x + 0.55, rr.end.y - 0.55), rr.end - Vector2(0.55, 0.55),
					rr.position + Vector2(1.1, 0.55), Vector2(rr.end.x - 1.1, rr.position.y + 0.55), Vector2(rr.position.x + 1.1, rr.end.y - 0.55), rr.end - Vector2(1.1, 0.55)]:
				cands.append([(c as Vector2).x, (c as Vector2).y, 0.0])
		_:
			var grid := []
			for dy: float in steps_y:
				for dx: float in steps_x:
					grid.append([absf(dx) + absf(dy), rr.get_center().x + dx, rr.get_center().y + dy])
			grid.sort_custom(func(a, b): return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and (float(a[2]) < float(b[2]) or (float(a[2]) == float(b[2]) and float(a[1]) < float(b[1])))))
			for g in grid:
				cands.append([float(g[1]), float(g[2]), 0.0])
	for c in cands:
		var p := Vector2(float(c[0]), float(c[1]))
		var fr := _prop_rect_tiles(pid, p, float(c[2]))
		if _furniture_clashes(pid, p, rm, float(c[2])) or _hits_any(fr, placed, off):
			continue
		if not rr.grow(-0.02).encloses(fr):
			continue
		var bad := false
		for sid in Property.stations_in(rm):
			if Property.is_installed(str(sid)) and fr.intersects(Property.footprint(str(sid), Property.st()["stations"][sid]).grow(0.7 if solid else 0.2)):
				bad = true
		for d in Property.doors():
			var dc := Property.door_center(Property.st(), d)
			if dc != Vector2.INF and fr.grow(1.4 if solid else 0.3).has_point(dc):
				bad = true
		for kp: Vector2 in Property.keep_clear_points():
			if fr.grow(0.6).has_point(kp):
				bad = true
		if Property.floor_of_room(rm) == "ground":
			var ent: Array = Property.data().get("entrance", [14.0, 0.6])
			if fr.grow(1.2).has_point(Vector2(float(ent[0]), float(ent[1]))):
				bad = true
		if not bad:
			return c
	return []


## Spots inside the smithy must be in rooms he owns; hirelings work next to the station of their craft.
func _smithy_spots(src: Dictionary) -> Dictionary:
	var out := {}
	var rooms := Property.rooms()
	var fallback := Vector2(21.5, 9.0)
	for r in rooms:
		if r["id"] == "study" and Property.room_owned(r):
			fallback = Property.rect(r).get_center()
	var work_disc := {"work_smithing": "classic", "work_alchemy": "alchemy", "work_runecraft": "runecraft"}
	for name in src.get("spots", {}):
		var a: Array = src["spots"][name]
		var p := Vector2(float(a[0]), float(a[1]))
		if work_disc.has(name):
			for sid in Property.st()["stations"]:
				if Property.is_installed(sid) and str(DB.station(sid).get("discipline", "")) == work_disc[name] and Property.station_floor(sid) == "ground":
					var size: Array = DB.station(sid)["size"]
					var cand := Property.pos_of(sid) + Vector2(0, float(size[1]) / T * 0.5 + 0.7)
					var h2 := Property.room_at_tile(rooms, cand)
					if not h2.is_empty() and Property.room_owned(h2):
						p = cand
						break
		var host := Property.room_at_tile(rooms, p)
		if host.is_empty() or not Property.room_owned(host):
			p = fallback
		out[name] = [p.x, p.y]
	return out


## Locked doors into the neighbours' rooms and a quiet note of whose rooms they are; the craft banner and name of
## every workshop room; the stair and the aetheric lift between the floors.
func _smithy_overlays(r: Rect2, fid := "ground") -> void:
	var off := Property.floor_rect(fid).position
	for d in Property.doors():
		if Property.door_open(Property.st(), d):
			continue
		var c := Property.door_center(Property.st(), d)
		if c == Vector2.INF or Property.floor_of_point(c) != fid:
			continue
		var e := Property._door_edge(Property.st(), d)
		var vertical := bool(e[0])
		var half := Vector2(WALL * 0.5 + 3.0, float(d["w"]) * T * 0.5 - 6.0) if vertical else Vector2(float(d["w"]) * T * 0.5 - 6.0, WALL * 0.5 + 3.0)
		var wp := r.position + (c - off) * T
		var pts := _rect_pts(Rect2(wp - half, half * 2.0))
		var door := Polygon2D.new()
		door.polygon = pts
		door.color = Color("#5a3a22")
		door.z_index = 1
		floor_layer.add_child(door)
		_outline(pts, 2.5, floor_layer)
		var lock := Polygon2D.new()
		lock.polygon = _rect_pts(Rect2(wp - Vector2(5, 5), Vector2(10, 10)))
		lock.color = Color("#b8923e")
		lock.z_index = 2
		floor_layer.add_child(lock)
	for rm in _rooms_on(fid):
		if Property.room_owned(rm):
			continue
		var u := Property.unit(str(rm.get("unit", "")))
		var rr := Property.rect(rm)
		var lab := Label.new()
		lab.text = "%s\n%s" % [u.get("name", "Private"), ("For sale — %d g (see Property & Workshop)" % Property.unit_price(str(u.get("id", "")))) if Property.unit_state(str(u.get("id", ""))) == "available" else "Private"]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", Assets.font("heading_italic"))
		lab.add_theme_font_size_override("font_size", 22)
		lab.add_theme_color_override("font_color", Color(0.94, 0.89, 0.8, 0.85))
		lab.add_theme_color_override("font_outline_color", Color("#20140c"))
		lab.add_theme_constant_override("outline_size", 6)
		lab.size = Vector2(rr.size.x * T, 70)
		lab.position = r.position + Vector2((rr.position.x - off.x) * T, (rr.get_center().y - off.y) * T - 35)
		lab.z_index = 3
		floor_layer.add_child(lab)
	# arcane rooms breathe a violet haze
	for rm2 in _rooms_on(fid):
		if Property.room_owned(rm2) and Property.room_discipline(rm2) == "arcane":
			var ar := Property.rect(rm2)
			var fog := _dust(r.position + (ar.get_center() - off) * T, ar.size * T * 0.45, 26, Color("#b08cff"))
			fog.modulate = Color(1, 1, 1, 0.8)
			add_child(fog)
	for rm3 in _rooms_on(fid):
		_craft_banner(r, rm3, off, fid)
	_floor_links(fid)


## The Living Realm — discipline areas: a banner of the room's craft on its north wall (gilt-trimmed in a Masterwork
## room) and the craft's name painted on the floor below it, so every workshop room reads at a glance.
func _craft_banner(r: Rect2, rm: Dictionary, off: Vector2, fid: String) -> void:
	if not Property.room_owned(rm) or Property.kind(rm) != "workshop":
		return
	var disc := Smithy.trade(rm)
	if disc == "":
		return
	var tier := Smithy.room_tier(rm)
	var rr := Property.rect(rm)
	var furn: Array = _smithy_furn.get(fid, [])
	var text := str(Smithy.SIGN_NAMES.get(disc, Smithy.trade_name(disc).to_upper()))
	var lab_w := float(text.length()) * 0.19 + 0.25   # tiles: ~12 px a capital at 17 px
	# the banner hangs on the north wall with its name painted beside it (right, else left) — one low strip along the
	# wall, clear of doorways, of every station's picture (not just its footprint), the furniture and the stair/hoist;
	# the first free place from the centre outwards. A room too crowded for the name still gets its banner.
	var station_pics := []
	for sid in Property.stations_in(rm):
		if Property.is_installed(str(sid)):
			var ssz: Array = DB.station(str(sid)).get("size", [96, 96])
			var sz2 := Vector2(float(ssz[0]), float(ssz[1])) / T
			station_pics.append(Rect2(Property.pos_of(str(sid)) - sz2 * 0.5, sz2).grow(0.06))
	var at := Vector2.INF
	var side := 0   # +1 name to the right, -1 to the left, 0 no name
	var steps := [0.0]
	for k in range(1, int(rr.size.x * 2.0)):
		steps.append(0.5 * ceil(k / 2.0) * (1.0 if k % 2 == 1 else -1.0))
	for sd: int in [1, -1, 0]:
		for k: float in steps:
			var p := Vector2(rr.get_center().x + k, rr.position.y + 0.55)
			var block := Rect2(p - Vector2(0.5, 0.55), Vector2(1.0, 1.15))
			if sd != 0:
				var lx := p.x + 0.5 if sd > 0 else p.x - 0.5 - lab_w
				block = block.merge(Rect2(Vector2(lx, rr.position.y + 0.12), Vector2(lab_w, 0.72)))
			if not rr.grow(-0.04).encloses(block):
				continue
			var bad := _hits_any(block, furn, off)
			for d in Property.doors():
				var dc := Property.door_center(Property.st(), d)
				if dc != Vector2.INF and block.grow(0.3).has_point(dc):
					bad = true
			for pic: Rect2 in station_pics:
				if block.intersects(pic):
					bad = true
			for rv: Rect2 in Property.reserved_rects():
				if block.intersects(rv):
					bad = true
			if not bad:
				at = p
				side = sd
				break
		if at != Vector2.INF:
			break
	if at == Vector2.INF:
		at = Vector2(rr.position.x + 0.7, rr.position.y + 0.55)
	var wp := r.position + (at - off) * T
	var bn := _sprite("props/banner_" + disc, wp, floor_layer)
	bn.z_index = 2
	bn.set_meta("craft_banner", disc)
	if tier >= 2:
		var gilt := _sprite("props/banner_gilt", wp, floor_layer)
		gilt.z_index = 3
	var stencil := Vector2.INF
	var st_text := text
	var st_h := 0.72
	if side == 0:
		# a painted stencil is smaller (15 px) and breaks a long name after "&"
		st_text = text.replace(" & ", " &\n")
		var longest := 0
		for ln in st_text.split("\n"):
			longest = maxi(longest, ln.length())
		lab_w = float(longest) * 0.165 + 0.2
		st_h = 0.3 * float(st_text.split("\n").size() + (1 if tier > 0 else 0)) + 0.1
		# no room beside the banner: paint the name on the floor in the nearest free aisle (non-solid, never in the way)
		var grid := []
		var stx := []
		var sty := []
		for k2 in range(0, int(rr.size.x) * 2 + 1):
			stx.append(0.5 * ceil(k2 / 2.0) * (1.0 if k2 % 2 == 0 else -1.0))
		for k3 in range(0, int(rr.size.y) * 2 + 1):
			sty.append(0.5 * ceil(k3 / 2.0) * (1.0 if k3 % 2 == 0 else -1.0))
		for dy: float in sty:
			for dx: float in stx:
				grid.append([absf(dx) + absf(dy) * 1.2, rr.get_center().x + dx, rr.get_center().y + dy])
		grid.sort_custom(func(a, b): return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and (float(a[2]) < float(b[2]) or (float(a[2]) == float(b[2]) and float(a[1]) < float(b[1])))))
		for g in grid:
			var lr := Rect2(Vector2(float(g[1]) - lab_w * 0.5, float(g[2]) - st_h * 0.5), Vector2(lab_w, st_h))
			if not rr.grow(-0.1).encloses(lr):
				continue
			var bad2 := _hits_solid(lr, furn, off)
			for pic2: Rect2 in station_pics:
				if lr.intersects(pic2):
					bad2 = true
			for rv2: Rect2 in Property.reserved_rects():
				if lr.intersects(rv2):
					bad2 = true
			if not bad2:
				stencil = Vector2(float(g[1]), float(g[2]))
				break
		if stencil == Vector2.INF:
			return
	var lab := Label.new()
	lab.text = text + ("" if tier == 0 else "\n" + Smithy.TIER_NAMES[tier])
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side > 0 else HORIZONTAL_ALIGNMENT_RIGHT
	lab.add_theme_font_override("font", Assets.font("heading"))
	lab.add_theme_font_size_override("font_size", 17)
	lab.add_theme_constant_override("line_spacing", -7)
	lab.add_theme_color_override("font_color", Color("#20140c") if tier < 2 else Color("#5a3a08"))
	lab.add_theme_color_override("font_outline_color", Color(0.95, 0.89, 0.76, 0.95))
	lab.add_theme_constant_override("outline_size", 6)
	lab.size = Vector2(lab_w * T, 46)
	var top_y := r.position.y + (rr.position.y - off.y + 0.12) * T
	lab.position = Vector2(wp.x + 0.5 * T + 2.0, top_y) if side > 0 else Vector2(wp.x - 0.5 * T - 2.0 - lab.size.x, top_y)
	if side == 0:
		lab.text = st_text + ("" if tier == 0 else "\n" + Smithy.TIER_NAMES[tier])
		lab.add_theme_font_size_override("font_size", 15)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.size = Vector2(lab_w * T, st_h * T)
		lab.position = r.position + (stencil - off) * T - lab.size * 0.5
		lab.modulate = Color(1, 1, 1, 0.82)   # painted on the boards
	lab.z_index = 2
	lab.set_meta("craft_label", disc)
	floor_layer.add_child(lab)


## The stair (stock hall ↔ Loft landing) and the aetheric lift (leather room ↔ weaving loft). Each stair/lift is an
## interactable whose id is the area it leads to; its arrival spot is "stairs_<area>" / "lift_<area>" (PlayerNav and
## the nav graph bridge floors through them). Before the lift is rigged the old hoist shows, greyed, and says what
## it needs (it opens Property & Workshop).
func _floor_links(fid: String) -> void:
	for f in Property.floors():
		var up := str(f["id"])
		if up == "ground" or not Property.floor_owned(up):
			continue
		var area_id := str(f.get("area", ""))
		var here_ground := fid == "ground"
		if not here_ground and fid != up:
			continue
		var sk := "down_stairs" if here_ground else "stairs"
		if f.has(sk):
			var sp := bpos(Property.BID, float(f[sk][0]), float(f[sk][1]))
			var spr := _sprite("props/stairs_up" if here_ground else "props/stairs_down", sp, floor_layer)
			spr.z_index = 1
			_add_interactable(sp, 80.0, "stairs", area_id if here_ground else Property.BID,
				"Stair — up to %s" % Property.floor_name(up).replace("The ", "the ") if here_ground else "Stair — down to the stock hall")
			var ak := "arrive_down" if here_ground else "entrance"
			spots["stairs_" + (Property.BID if here_ground else area_id)] = bpos(Property.BID, float(f[ak][0]), float(f[ak][1]))
		var lk := "down_lift" if here_ground else "lift"
		if not f.has(lk):
			continue
		var lp := bpos(Property.BID, float(f[lk][0]), float(f[lk][1]))
		var host := Property.room_at_tile(Property.rooms(), Vector2(float(f[lk][0]), float(f[lk][1])))
		if host.is_empty() or not Property.room_owned(host):
			continue
		var plat := _sprite("props/lift_platform", lp, floor_layer)
		plat.z_index = 1
		if Property.has_lift():
			var gl := FX.light(Color("#9a6cff"), 170.0, 0.55, true)
			gl.position = lp
			add_child(gl)
			_add_interactable(lp, 80.0, "lift", area_id if here_ground else Property.BID,
				"Aetheric lift — up to %s" % Property.floor_name(up).replace("The ", "the ") if here_ground else "Aetheric lift — down to the leather room")
			var lak := "lift_arrive_down" if here_ground else "lift_arrive"
			var other := "lift_arrive" if here_ground else "lift_arrive_down"
			# arriving here (from the other floor) puts you beside this platform
			spots["lift_" + (Property.BID if here_ground else area_id)] = bpos(Property.BID, float(f[lak][0]), float(f[lak][1]))
			if not spots.has("lift_" + (area_id if here_ground else Property.BID)):
				spots["lift_" + (area_id if here_ground else Property.BID)] = bpos(Property.BID, float(f[other][0]), float(f[other][1]))
		else:
			plat.modulate = Color(0.62, 0.56, 0.5, 0.85)
			var why := Property.lift_reason()
			_add_interactable(lp, 70.0, "property", "lift", "Ilse's old goods hoist — %s" % (
				"rig it as an aetheric lift for %d g (Property & Workshop)" % Property.lift_price() if why == "" else why.trim_suffix(".")))




## The main recipe-selection station of each room carries a small brass recipe plaque, always visible.
func _main_station_mark(pos: Vector2, size: Vector2) -> void:
	var m := Sprite2D.new()
	m.texture = Assets.get_tex("ui/recipe_plaque", Vector2i(44, 44))
	m.position = pos + Vector2(size.x * 0.42, -size.y * 0.42)
	m.z_index = 25
	add_child(m)


# ======================================================================= light
## Sky colour keyframes over the day (hour, colour): deep blue night, a warm dawn, a clean white midday,
## a golden late afternoon, a short dusky violet and back to night. Lights follow `night_factor`.
const SKY := [[0.0, Color(0.20, 0.24, 0.44)], [4.6, Color(0.21, 0.25, 0.46)], [5.6, Color(0.36, 0.36, 0.56)],
	[6.5, Color(0.90, 0.72, 0.70)], [7.4, Color(1.0, 0.86, 0.74)], [9.5, Color(1.0, 0.97, 0.93)], [14.5, Color(1.0, 0.98, 0.93)],
	[16.8, Color(1.0, 0.88, 0.72)], [18.0, Color(0.98, 0.68, 0.50)], [19.0, Color(0.72, 0.50, 0.58)], [20.2, Color(0.36, 0.34, 0.56)],
	[21.6, Color(0.22, 0.26, 0.46)], [24.0, Color(0.20, 0.24, 0.44)]]
var night_factor := 0.0
var _last_night := -1


func sky_color(h: float) -> Color:
	for i in SKY.size() - 1:
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1], smoothstep(0.0, 1.0, t))
	return SKY[0][1]


## 0 by day, 1 at night: lamps, windows and the forge chimney glow come up through dusk and fade at dawn.
static func night_amount(h: float) -> float:
	if h < 5.2 or h >= 20.4:
		return 1.0
	if h < 7.4:
		return 1.0 - smoothstep(5.2, 7.4, h)
	if h >= 17.2:
		return smoothstep(17.2, 20.4, h)
	return 0.0


func _update_light(force: bool) -> void:
	var m := float(Game.state.get("minute", 720))
	var h := m / 60.0
	var night_f := night_amount(h)
	var c := sky_color(h)
	if area != "village":
		# interiors are lit by hearths and candles; at night they stay warm and readable
		c = c.lerp(Color(0.92, 0.84, 0.74), 0.55 + 0.2 * night_f)
		if buildings.get(area, {}).get("area", false):
			c = Color(0.86, 0.78, 0.68).lerp(Color(0.74, 0.66, 0.6), night_f)   # cellars and upper floors: lamp-lit
	canvas_mod.color = c
	night_factor = night_f
	var e := night_f * 0.9
	for l in night_lights:
		var pl := l as PointLight2D
		pl.visible = e > 0.01
		pl.energy = e * float(pl.get_meta("gain", 1.0))
		if pl.has_method("_process"):
			pl.set("base_energy", e * float(pl.get_meta("gain", 1.0)))
	for w in _window_glows:
		(w as CanvasItem).modulate.a = clampf(night_f * 1.2, 0.0, 1.0)
	var is_night := int(night_f > 0.5)
	if force:
		_on_area_changed()
	elif is_night != _last_night and _last_night >= 0 and area == "village":
		_update_ambience()
	_last_night = is_night
