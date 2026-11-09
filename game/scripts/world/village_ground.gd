## VillageGround — roads worn into the terrain (iteration 010).
## EN: Instead of hard-edged road polygons, the roads, doorsteps and junctions are rendered once into a small road
##     mask (a SubViewport: R road bed, G trampled verges and doorsteps, B wheel ruts on the main roads). One map-sized
##     sprite then paints the ground through shaders/road_ground.gdshader, which blurs and frays the mask with noise so
##     paths feather into the grass; the square's cobbles fray into packed earth at their rim.
## DA: Veje slidt ned i jorden: en vejmaske tegnes én gang, og en shader blander dem blødt ind i græsset.
class_name VillageGround
extends RefCounted

const MASK_SCALE := 0.25        # mask pixels per world pixel
const PAD := 256.0              # world pixels of mask beyond the map edge


static func build(w: VillageWorld) -> void:
	var T := VillageWorld.T
	var size: Array = DB.layout.get("size", [96, 64])
	var origin := Vector2(-PAD, -PAD)
	var world_size := Vector2(float(size[0]) * T, float(size[1]) * T) + Vector2(PAD, PAD) * 2.0
	var msize := Vector2i(int(world_size.x * MASK_SCALE), int(world_size.y * MASK_SCALE))
	var vp := SubViewport.new()
	vp.size = msize
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	w.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(msize)
	vp.add_child(bg)
	var root := Node2D.new()
	root.scale = Vector2(MASK_SCALE, MASK_SCALE)
	root.position = -origin * MASK_SCALE
	vp.add_child(root)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var roads: Array = DB.layout.get("roads", [])
	# G: trampled verges, wider than the road, plus wear where roads meet and outside every door
	for r in roads:
		var pts := w._smooth(r["points"])
		_line(root, pts, float(r["width"]) * T + 62.0, Color(0, 0.75, 0), add)
		for e in [r["points"][0], r["points"][r["points"].size() - 1]]:
			_disc(root, w.tp(e), float(r["width"]) * T * 0.9 + 26.0, Color(0, 0.6, 0), add)
	for b in DB.layout.get("buildings", []):
		var rr := w.brect(b)
		var d: Dictionary = b["doors"][0]
		var dc: Vector2 = w._door_center(rr, d) + w._door_out(d) * 58.0
		var ext := Vector2(80, 50) if d["side"] in ["n", "s"] else Vector2(50, 80)
		var poly := w._ellipse_poly(dc, ext, 18, 0.16, str(b["id"]).length())
		var p := Polygon2D.new()
		p.polygon = poly
		p.color = Color(0, 0.9, 0)
		p.material = add
		root.add_child(p)
	# R: the road beds
	for r in roads:
		_line(root, w._smooth(r["points"]), float(r["width"]) * T, Color(0.55, 0, 0), add)
		_line(root, w._smooth(r["points"]), maxf(8.0, float(r["width"]) * T - 18.0), Color(0.45, 0, 0), add)
	# B: wheel ruts pressed into the main roads (and the lanes carts use)
	for r in roads:
		var wpx := float(r["width"]) * T
		if wpx < 1.35 * T:
			continue
		var pts2 := w._smooth(r["points"])
		for side in [-1.0, 1.0]:
			_line(root, w._offset_line(pts2, side * wpx * 0.23), 10.0 if wpx > 2.0 * T else 8.0, Color(0, 0, 0.9), add)
	# the map-sized ground sprite that paints through the mask
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.position = origin
	spr.scale = Vector2.ONE / MASK_SCALE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/road_ground.gdshader")
	mat.set_shader_parameter("mask_tex", vp.get_texture())
	mat.set_shader_parameter("dirt_tex", Assets.get_tex("textures/dirt_road", Vector2i(256, 256)))
	mat.set_shader_parameter("cobble_tex", Assets.get_tex("textures/cobble", Vector2i(256, 256)))
	mat.set_shader_parameter("world_origin", origin)
	mat.set_shader_parameter("world_size", world_size)
	mat.set_shader_parameter("mask_texel", Vector2(1.0 / msize.x, 1.0 / msize.y))
	var sq: Dictionary = DB.layout.get("square", {})
	mat.set_shader_parameter("has_square", 0.0 if sq.is_empty() else 1.0)
	if not sq.is_empty():
		mat.set_shader_parameter("sq_center", w.tp(sq["center"]))
		mat.set_shader_parameter("sq_radius", w.tp(sq["radius"]))
	spr.material = mat
	w.ground_layer.add_child(spr)
	_build_worked_ground(w)


# ======================================================================= soft transitions (The Living Realm)
## EN: Every other ground material meets the grass through a feathered, noise-frayed edge (shaders/soft_ground):
##     meadow patches, the damp earth along the stream, pond and harbour, tilled soil under the crop beds and herb
##     gardens, trampled paddocks, and the grime at the foot of walls. The meshes carry an edge ramp in their vertex
##     alpha; one shared material per (opacity, texture) pair keeps the draw cost flat.
## DA: Bløde overgange: engpletter, fugtige bredder, pløjet jord og trampede folde glider over i græsset.
static var _mats := {}


static func _soft_mat(peak: float, textured: bool) -> ShaderMaterial:
	var key := "%.3f:%s" % [peak, textured]
	if not _mats.has(key) or not is_instance_valid(_mats[key]):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/soft_ground.gdshader")
		m.set_shader_parameter("peak", peak)
		m.set_shader_parameter("use_tex", 1.0 if textured else 0.0)
		_mats[key] = m
	return _mats[key]


static func _mesh(parent: Node, pts: PackedVector2Array, edge: PackedFloat32Array, polys: Array, col: Color, tex: Texture2D, under: bool) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	var vc := PackedColorArray()
	for e in edge:
		vc.append(Color(col.r, col.g, col.b, e))
	p.vertex_colors = vc
	p.polygons = polys
	if tex != null:
		p.texture = tex
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.material = _soft_mat(col.a, tex != null)
	parent.add_child(p)
	if under:
		parent.move_child(p, mini(1, parent.get_child_count() - 1))   # right above the base grass, under roads and water
	return p


## A patch whose outer `feather` fraction (of the centre-to-rim distance) fades into the ground.
static func soft_patch(parent: Node, poly: PackedVector2Array, col: Color, feather := 0.45, tex: Texture2D = null, under := true) -> Polygon2D:
	var n := poly.size()
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= float(n)
	var pts := PackedVector2Array()
	var edge := PackedFloat32Array()
	var inner := PackedInt32Array()
	for i in n:
		pts.append(c + (poly[i] - c) * (1.0 - feather))
		edge.append(1.0)
		inner.append(i)
	for i in n:
		pts.append(poly[i])
		edge.append(0.0)
	var polys: Array = [inner]
	for i in n:
		var j := (i + 1) % n
		polys.append(PackedInt32Array([i, j, n + j, n + i]))
	return _mesh(parent, pts, edge, polys, col, tex, under)


## Outward normals of a closed polygon (any winding), averaged at each corner.
static func _normals(poly: PackedVector2Array) -> PackedVector2Array:
	var n := poly.size()
	var area := 0.0
	for i in n:
		area += poly[i].cross(poly[(i + 1) % n])
	var flip := 1.0 if area > 0.0 else -1.0   # y points down: a positive cross sum winds clockwise on screen
	var out := PackedVector2Array()
	for i in n:
		var a := (poly[i] - poly[(i - 1 + n) % n]).normalized()
		var b := (poly[(i + 1) % n] - poly[i]).normalized()
		var t := (a + b).normalized() if (a + b).length() > 0.01 else b
		out.append(Vector2(t.y, -t.x) * flip)
	return out


## A band around a closed outline: full strength from `inside` px within it to the outline, fading out over `outside` px.
static func soft_ring(parent: Node, poly: PackedVector2Array, inside: float, outside: float, col: Color, under := true) -> Polygon2D:
	var n := poly.size()
	var nm := _normals(poly)
	var pts := PackedVector2Array()
	var edge := PackedFloat32Array()
	for i in n:
		pts.append(poly[i] - nm[i] * inside)
		edge.append(1.0)
	for i in n:
		pts.append(poly[i])
		edge.append(1.0)
	for i in n:
		pts.append(poly[i] + nm[i] * outside)
		edge.append(0.0)
	var polys: Array = []
	for i in n:
		var j := (i + 1) % n
		polys.append(PackedInt32Array([i, j, n + j, n + i]))
		polys.append(PackedInt32Array([n + i, n + j, 2 * n + j, 2 * n + i]))
	return _mesh(parent, pts, edge, polys, col, null, under)


## A band along an open line (a stream's banks): full strength within `core` px of the line, fading out to `half` px.
static func soft_strip(parent: Node, line: PackedVector2Array, core: float, half: float, col: Color, under := true) -> Polygon2D:
	var n := line.size()
	var pts := PackedVector2Array()
	var edge := PackedFloat32Array()
	var offs := [[-half, 0.0], [-core, 1.0], [core, 1.0], [half, 0.0]]
	for i in n:
		var t := (line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]).normalized()
		var nm := Vector2(-t.y, t.x)
		for o in offs:
			pts.append(line[i] + nm * float(o[0]))
			edge.append(float(o[1]))
	var polys: Array = []
	for i in n - 1:
		for k in 3:
			var a := i * 4 + k
			polys.append(PackedInt32Array([a, a + 1, a + 5, a + 4]))
	return _mesh(parent, pts, edge, polys, col, null, under)


## Worked ground from the layout: tilled soil under each field of crop beds and the herb gardens, trampled earth in
## the paddocks — so the beds sit in their field instead of on the grass.
static func _build_worked_ground(w: VillageWorld) -> void:
	var T := VillageWorld.T
	var dirt := Assets.get_tex("textures/dirt_road", Vector2i(256, 256))
	for kind in ["crop_rows", "herb_garden"]:
		var r := Rect2()
		var any := false
		for f in DB.layout.get("outdoor_props", []):
			if str(f[0]) != kind:
				continue
			var p := w.tp([f[1], f[2]])
			r = Rect2(p, Vector2.ZERO) if not any else r.expand(p)
			any = true
		if not any:
			continue
		var pad := Vector2(2.2, 1.9) * T if kind == "crop_rows" else Vector2(1.6, 1.5) * T
		r = r.grow_individual(pad.x, pad.y, pad.x, pad.y)
		var poly := w._ellipse_poly(r.get_center(), r.size * 0.62, 28, 0.08, kind.length())
		soft_patch(w.ground_layer, poly, Color(0.86, 0.74, 0.6, 0.62), 0.4, dirt)
	for pd in DB.layout.get("paddocks", []):
		var rc: Array = pd["rect"]
		var rr := Rect2(w.tp([rc[0], rc[1]]), Vector2(float(rc[2]), float(rc[3])) * T)
		var poly2 := w._ellipse_poly(rr.get_center(), rr.size * 0.5, 24, 0.12, str(pd["id"]).length())
		soft_patch(w.ground_layer, poly2, Color(0.82, 0.72, 0.56, 0.38), 0.55, dirt)


static func _line(parent: Node, pts: PackedVector2Array, width: float, col: Color, mat: Material) -> void:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.material = mat
	parent.add_child(l)


static func _disc(parent: Node, c: Vector2, r: float, col: Color, mat: Material) -> void:
	var p := Polygon2D.new()
	var poly := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		poly.append(c + Vector2(cos(a), sin(a)) * r)
	p.polygon = poly
	p.color = col
	p.material = mat
	parent.add_child(p)
