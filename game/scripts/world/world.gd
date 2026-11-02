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
	_build_nav()
	_spawn_player()
	_spawn_npcs()
	_refresh_bags()
	_refresh_eggs()
	Events.hour_passed.connect(func(_d, _h): _update_schedules())
	Events.adventurer_departed.connect(_on_departed)
	Events.hireling_departed.connect(_on_departed)
	Events.adventurer_returned.connect(_on_returned)
	Events.hireling_returned.connect(_on_returned)
	Events.world_flag_changed.connect(_on_flag)
	Events.inventory_changed.connect(_refresh_bags)
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
	for s in segs:
		var pts := _rect_pts(s)
		_tex_poly(pts, tex, floor_layer)
		_outline(pts, 2.5, floor_layer)
		_solid(s)


func _build_building(b: Dictionary, is_area: bool) -> void:
	var r := brect(b)
	if is_area:
		# interior areas live outside the village map: frame them with dim roof timbers, not a void
		_tex_poly(_rect_pts(r.grow(900)), "wall_timber", ground_layer, Color(0.32, 0.26, 0.22))
	_tex_poly(_rect_pts(r), b.get("floor", "floor_wood"), floor_layer)
	var wall_tex := "wall_timber" if b.get("roof", "") == "thatch" else "wall_stone"
	_draw_walls(_wall_segments(r, b.get("doors", [])), wall_tex)
	for room in b.get("rooms", []):
		var rr: Array = room["rect"]
		var rrect := Rect2(r.position + Vector2(float(rr[0]), float(rr[1])) * T, Vector2(float(rr[2]), float(rr[3])) * T)
		_tex_poly(_rect_pts(rrect.grow(-2)), room.get("floor", "floor_wood"), floor_layer)
		var skip := []
		if is_equal_approx(rrect.position.y, r.position.y):
			skip.append("n")
		if is_equal_approx(rrect.end.y, r.end.y):
			skip.append("s")
		if is_equal_approx(rrect.position.x, r.position.x):
			skip.append("w")
		if is_equal_approx(rrect.end.x, r.end.x):
			skip.append("e")
		_draw_walls(_wall_segments(rrect, [room.get("door", {"side": "x", "at": 0, "w": 0})], skip), "wall_timber")
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
	var info := {"rect": r, "roof": null, "alpha": 1.0, "name": b.get("name", b["id"]), "area": is_area}
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
		spots["stairs_" + b["id"]] = spos + Vector2(0, 90)


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
func _prop(id: String, pos: Vector2, rot := 0.0) -> Node2D:
	var info: Dictionary = DB.props.get(id, {"size": [64, 64], "solid": true})
	var size := Vector2(float(info["size"][0]), float(info["size"][1]))
	if not info.get("solid", true):
		var fs := _sprite("props/" + id, pos, floor_layer)
		fs.rotation = rot
		return fs
	var holder := Node2D.new()
	holder.position = pos + Vector2(0, size.y * 0.3)
	var s := Sprite2D.new()
	s.texture = Assets.get_tex("props/" + id, Vector2i(int(size.x), int(size.y)))
	s.offset = Vector2(0, -size.y * 0.3)
	s.rotation = rot
	holder.add_child(s)
	ysort.add_child(holder)
	var foot := size * Vector2(0.75, 0.55)
	if id.begins_with("tree"):
		foot = Vector2(size.x * 0.22, size.y * 0.18)
	_solid(Rect2(pos - foot * 0.5 + Vector2(0, size.y * 0.1), foot))
	return holder


func _furnish() -> void:
	# --- smithy shop front
	var B := "smithy"
	_prop("shop_counter", bpos(B, 15, 4.2))
	_prop("weapon_rack", bpos(B, 10, 0.95))
	_prop("armor_stand", bpos(B, 12.6, 1.3))
	_prop("armor_stand", bpos(B, 19.4, 1.3))
	_prop("display_table", bpos(B, 21.4, 2.2))
	_add_interactable(bpos(B, 15, 4.2), 150.0, "counter", "smithy", "Shop counter — stock, customers & ledger")
	spots["smithy_counter_front"] = bpos(B, 15, 2.9)
	spots["smithy_counter_back"] = bpos(B, 15, 5.6)
	spots["smithy_bag"] = bpos(B, 11.2, 6.4)
	spots["smithy_inside"] = bpos(B, 15, 7.5)
	_prop("coal_pile", bpos(B, 4.6, 14.6))
	_prop("ore_pile", bpos(B, 9.0, 14.3))
	_prop("barrel", bpos(B, 1.0, 1.2))
	_prop("crate", bpos(B, 2.1, 1.1))
	_prop("woodpile", bpos(B, 4.2, 1.0))
	_prop("rug_brown", bpos(B, 12, 10), 0.0)
	var work := {"mining": [5.4, 13.6], "alchemy": [17.8, 15.0], "runecraft": [7.8, 15.2], "smithing": [10.6, 9.2], "travelling": [20.5, 3.2], "relic_hunting": [22.6, 4.2]}
	for k in work:
		spots["work_" + k] = bpos(B, work[k][0], work[k][1])
	# quarters
	_prop("bed", bpos(B, 28.6, 2.6))
	_add_interactable(bpos(B, 28.6, 2.6), 110.0, "bed", "player_bed", "Your bed — sleep until morning (autosave)")
	_prop("wardrobe", bpos(B, 26.2, 0.8))
	_prop("table_round", bpos(B, 26.4, 5.8))
	_prop("chair", bpos(B, 25.3, 5.8))
	_prop("chest", bpos(B, 28.9, 8.4))
	_prop("rug_red", bpos(B, 27.2, 4.6), PI / 2)
	_prop("candle", bpos(B, 26.4, 5.6))
	spots["quarters_table"] = bpos(B, 27.4, 6.4)
	spots["quarters_door_in"] = bpos(B, 24.8, 7.0)
	var cl := FX.light(Color("#ffb060"), 220.0, 0.8, true)
	cl.position = bpos(B, 26.4, 5.6)
	add_child(cl)
	# --- inn
	B = "inn"
	_prop("bar_counter", bpos(B, 6, 3.0))
	for x in [4.6, 6.0, 7.4]:
		_prop("keg", bpos(B, x, 1.0))
	_prop("fireplace", bpos(B, 12, 0.8))
	var fl := FX.light(Color("#ff9a40"), 380.0, 1.1, true)
	fl.position = bpos(B, 12, 1.3)
	add_child(fl)
	var fe := FX.embers(10)
	fe.position = bpos(B, 12, 0.9)
	add_child(fe)
	var tables := [[5, 7], [9, 6.2], [14, 5.4], [15.2, 9.4], [4.6, 11.0], [10, 10.4]]
	var ti := 0
	for t in tables:
		ti += 1
		_prop("table_round", bpos(B, t[0], t[1]))
		_prop("candle", bpos(B, t[0], t[1] - 0.1))
		for off in [Vector2(-1.0, 0), Vector2(1.0, 0), Vector2(0, 0.95)]:
			_prop("stool", bpos(B, t[0] + off.x, t[1] + off.y))
		spots["inn_t%d" % ti] = bpos(B, t[0] - 1.0, t[1] + 0.05)
		spots["inn_t%db" % ti] = bpos(B, t[0] + 1.0, t[1] + 0.05)
		var tl := FX.light(Color("#ffb868"), 170.0, 0.55)
		tl.position = bpos(B, t[0], t[1])
		add_child(tl)
	_prop("bench", bpos(B, 17.4, 12.6))
	_prop("rug_red", bpos(B, 9.8, 8.4))
	_prop("barrel", bpos(B, 1.0, 12.8))
	_prop("barrel", bpos(B, 1.9, 12.9))
	spots["inn_bar"] = bpos(B, 6.0, 4.3)
	spots["inn_behind_bar"] = bpos(B, 6.0, 1.95)
	spots["inn_hearth"] = bpos(B, 12, 2.2)
	spots["inn_inside"] = bpos(B, 10, 12.2)
	_prop("beer_table", Vector2(21.6 * T, 22.0 * T))
	_prop("beer_table", Vector2(21.6 * T, 25.6 * T))
	spots["inn_garden"] = Vector2(22.9 * T, 23.8 * T)
	# --- grocery
	B = "grocery"
	_prop("shop_counter", bpos(B, 5.5, 3.2))
	_prop("shelf", bpos(B, 5.5, 0.8))
	for p in [[1.6, 6.6], [3.0, 6.8], [8.4, 6.6], [9.6, 2.2]]:
		_prop("produce_crate", bpos(B, p[0], p[1]))
	_prop("grain_sacks", bpos(B, 1.6, 2.0))
	_prop("sack", bpos(B, 9.6, 4.6))
	spots["grocery_behind"] = bpos(B, 5.5, 1.9)
	spots["grocery_front"] = bpos(B, 5.5, 4.6)
	var gl := FX.light(Color("#ffc070"), 260.0, 0.6)
	gl.position = bpos(B, 5.5, 3.0)
	add_child(gl)
	# --- homes
	for hid in ["house_martha", "house_tobin", "house_jory", "house_eda", "house_wenna"]:
		var b := DB.building(hid)
		var w := float(b["rect"][2])
		var h := float(b["rect"][3])
		_prop("bed", bpos(hid, w - 1.4, 2.0))
		_prop("table_round", bpos(hid, w * 0.45, h * 0.55))
		_prop("chair", bpos(hid, w * 0.45 - 0.9, h * 0.55))
		_prop("chest", bpos(hid, 1.2, h - 1.2))
		_prop("shelf", bpos(hid, w * 0.5, 0.75))
		_prop("candle", bpos(hid, w * 0.45, h * 0.53))
		spots[hid + "_inside"] = bpos(hid, w * 0.45 + 1.0, h * 0.62)
		var hl := FX.light(Color("#ffb060"), 220.0, 0.6, true)
		hl.position = bpos(hid, w * 0.45, h * 0.5)
		add_child(hl)
	_prop("workbench", bpos("house_tobin", 2.4, 4.2))
	_prop("washtub", bpos("house_eda", 1.6, 1.6))
	# chapel
	_prop("altar", bpos("house_oswin", 8.6, 4.5), PI / 2)
	for y in [2.0, 3.5, 5.5, 7.0]:
		_prop("pew", bpos("house_oswin", 4.6, y))
	spots["house_oswin_inside"] = bpos("house_oswin", 7.4, 4.5)
	for c in [[8.6, 3.2], [8.6, 5.8]]:
		var al := FX.light(Color("#ffd080"), 160.0, 0.7, true)
		al.position = bpos("house_oswin", c[0], c[1])
		add_child(al)
	# --- upstairs: inn rooms + the Velvet Lantern
	B = "inn_upstairs"
	for p in [[3.4, 6.0], [3.4, 11.0], [7.4, 6.0], [7.4, 11.0]]:
		_prop("bed", bpos(B, p[0], p[1]))
	_prop("bed_fancy", bpos(B, 17.6, 3.4))
	_prop("bed_fancy", bpos(B, 17.6, 10.6))
	_prop("rug_red", bpos(B, 14.6, 7.0), PI / 2)
	_prop("table_round", bpos(B, 13.0, 7.0))
	_prop("chair", bpos(B, 12.0, 7.0))
	_prop("chair", bpos(B, 14.0, 7.0))
	for c in [[13.0, 6.8], [11.2, 2.0], [11.2, 12.0], [19.0, 7.0]]:
		_prop("candle", bpos(B, c[0], c[1]))
		var ll := FX.light(Color("#ff8a6a"), 200.0, 0.75, true)
		ll.position = bpos(B, c[0], c[1])
		add_child(ll)
	spots["lantern_1"] = bpos(B, 12.8, 4.2)
	spots["lantern_2"] = bpos(B, 12.8, 10.0)
	spots["lantern_3"] = bpos(B, 16.2, 7.0)
	spots["upstairs_hall"] = bpos(B, 5.4, 8.4)


# ======================================================================= stations
func _build_stations() -> void:
	for st in DB.stations.values():
		var p: Array = st["pos"]
		var pos := bpos("smithy", float(p[0]), float(p[1]))
		var size := Vector2(float(st["size"][0]), float(st["size"][1]))
		var tex := Assets.get_tex("stations/" + st["id"], Vector2i(int(size.x), int(size.y)))
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
	Events.world_flag_changed.connect(func(_f): _refresh_station_locks())
	Events.skill_level_up.connect(func(_a, _b, _c): _refresh_station_locks())


func _station_fx(fx: String, pos: Vector2, size: Vector2) -> void:
	match fx:
		"fire", "light_forge":
			if fx == "light_forge":
				var l := FX.light(Color("#ff8a2a"), 520.0, 1.35, true)
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


func _refresh_station_locks() -> void:
	for id in station_sprites:
		var locked := Crafting.station_locked_reason(id) != ""
		(station_sprites[id] as CanvasItem).modulate = Color(0.55, 0.5, 0.48, 0.85) if locked else Color.WHITE


# ======================================================================= outdoors
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
	var want := {"tree_oak_a": 70, "tree_oak_b": 55, "tree_pine": 45, "tree_small": 40, "bush": 50, "bush_flower": 30, "rock_a": 22, "rock_b": 16, "flowers": 60}
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
		if name.begins_with("square_") or name in ["notice", "well", "inn_garden"] or name.begins_with("exit_"):
			var id := _pt(spots[name])
			spot_ids[name] = id
			_link_nearest(id, 1400.0, 2)
			outdoor_ids.append(id)
	# building doors: outside ↔ inside, interiors star-linked to the inside door
	for b in DB.layout.get("buildings", []):
		var r := brect(b)
		var d: Dictionary = b["doors"][0]
		var dc := _door_center(r, d)
		var out_id := _pt(dc + _door_out(d) * 70.0)
		var in_id := _pt(dc - _door_out(d) * 70.0)
		astar.connect_points(out_id, in_id)
		_link_nearest(out_id, 1400.0, 1)
		spots[b["id"] + "_door_out"] = dc + _door_out(d) * 70.0
		spot_ids[b["id"] + "_door_out"] = out_id
		for name in spots.keys():
			if spot_ids.has(name):
				continue
			if r.grow(-4).has_point(spots[name]):
				var sid := _pt(spots[name])
				spot_ids[name] = sid
				astar.connect_points(sid, in_id)
	# the smithy quarters sit behind an inner door
	if spot_ids.has("quarters_door_in") and spot_ids.has("smithy_inside"):
		var qd: int = spot_ids["quarters_door_in"]
		for name in ["quarters_table"]:
			if spot_ids.has(name):
				astar.disconnect_points(spot_ids[name], _closest_in("smithy"))
				astar.connect_points(spot_ids[name], qd)
	# upstairs graph
	var up_hall := _pt(spots.get("upstairs_hall", Vector2.ZERO))
	spot_ids["upstairs_hall"] = up_hall
	for name in ["lantern_1", "lantern_2", "lantern_3", "stairs_inn_upstairs"]:
		if spots.has(name):
			var id := _pt(spots[name])
			spot_ids[name] = id
			astar.connect_points(id, up_hall)


func _closest_in(bid: String) -> int:
	var r := brect(DB.building(bid))
	var d: Dictionary = DB.building(bid)["doors"][0]
	return astar.get_closest_point(_door_center(r, d) - _door_out(d) * 70.0)


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
			return "smithy_counter_front"
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
		if a["status"] in ["away", "dead"]:
			return ""
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
		_on_area_changed()


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
	for id in npcs:
		var n: NPCActor = npcs[id]
		if not n.visible:
			continue
		var d := ppos.distance_to(n.position)
		n.show_name(d < 220.0)
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
