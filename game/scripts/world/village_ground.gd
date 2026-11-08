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
