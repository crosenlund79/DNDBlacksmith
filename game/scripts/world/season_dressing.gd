## SeasonDressing — the seasons and the weather over Brindlewick (canonical v1.6 §11). VISUAL AND AUDIO ONLY.
## EN: Reads the moment from Seasons (a pure function of the saved day, minute and world seed) and dresses the village
##     to match: the grass, foliage, flowers and reeds take the season's palette (summer is the art as drawn), autumn
##     trees turn gold and red, winter lays snow on the ground, the roofs and the trees, spring blossoms; rain, showers,
##     snowfall, drifting leaves and petals, mist and fog fall over the streets (never inside the building the smith is
##     in — the street around it still shows them); the daylight takes the season's colour; rain and winter wind sound
##     on their own ambience layer. Everything changes smoothly with the clock and the calendar.
##     It writes nothing to the game state, never draws from the game's random number generators, and nothing in the
##     simulation reads it. The art is never replaced: templates and a creator's own sprites are tinted or overlaid.
## DA: Årstiderne og vejret over landsbyen — kun billede og lyd; ændrer intet i spillets regler eller tilstand.
class_name SeasonDressing
extends Node2D

const DECIDUOUS := ["tree_oak_a", "tree_oak_b", "tree_small", "bush", "bush_flower", "undergrowth", "fern"]
const BLOSSOMING := ["tree_small", "bush_flower", "tree_oak_b"]
const FLOWERS := ["flowers", "flower_patch_a", "flower_patch_b"]

## Multipliers on the existing art (summer's plants are the art as drawn; its grass a deeper, lusher green).
const GROUND := {"spring": Color(0.94, 1.0, 0.86), "summer": Color(0.88, 0.98, 0.74), "autumn": Color(1.0, 0.9, 0.68), "winter": Color(0.84, 0.88, 0.94)}
const FOLIAGE := {"spring": Color(0.9, 1.0, 0.84), "summer": Color(1, 1, 1), "autumn": Color(1.0, 0.74, 0.4), "winter": Color(0.72, 0.7, 0.68)}
const AUTUMN_VARIANTS := [Color(1.0, 0.56, 0.3), Color(1.0, 0.8, 0.34), Color(0.92, 0.64, 0.34), Color(0.84, 0.46, 0.28)]
const PINE := {"spring": Color(0.96, 1.0, 0.94), "summer": Color(1, 1, 1), "autumn": Color(0.92, 0.95, 0.86), "winter": Color(0.86, 0.9, 0.94)}
const FLOWER := {"spring": Color(1, 1, 1, 1), "summer": Color(1, 1, 1, 1), "autumn": Color(0.95, 0.8, 0.6, 0.65), "winter": Color(0.8, 0.8, 0.86, 0.2)}
const REED := {"spring": Color(0.92, 1.0, 0.86), "summer": Color(1, 1, 1), "autumn": Color(1.0, 0.84, 0.52), "winter": Color(0.86, 0.84, 0.78)}
const LIGHT := {"spring": Color(0.98, 1.0, 0.97), "summer": Color(1.0, 0.99, 0.95), "autumn": Color(1.0, 0.91, 0.8), "winter": Color(0.87, 0.92, 1.0)}
const SNOW := {"spring": 0.0, "summer": 0.0, "autumn": 0.0, "winter": 1.0}
const BLOSSOM := {"spring": 0.55, "summer": 0.0, "autumn": 0.0, "winter": 0.0}
const WASH := {"spring": Color(0.5, 0.78, 0.34, 0.1), "summer": Color(0.5, 0.62, 0.3, 0.0), "autumn": Color(0.72, 0.46, 0.2, 0.2), "winter": Color(0.8, 0.82, 0.86, 0.0)}
## How much each weather darkens the daylight (at full strength).
const DIM := {"light_rain": 0.45, "showers": 0.55, "rain": 0.95, "overcast": 0.75, "fog": 0.55, "snow": 0.55, "mist": 0.25}
const BLOSSOM_COL := Vector3(1.0, 0.82, 0.9)
const SNOW_COL := Vector3(0.9, 0.93, 0.98)

var world: VillageWorld
var look := {}                       # the last computed look (for tests and the HUD)
var _veg: Array = []                 # [sprite, kind, variant 0…1, autumn variant colour]
var _mats := {}                      # kind -> its own copy of the breeze material (snow and blossom per kind)
var _roof_mats: Array = []
var _grass: CanvasItem
var _overlay: Polygon2D
var _overlay_mat: ShaderMaterial
var _layer: Node2D
var _wmat: ShaderMaterial
var _fx := {}                        # kind -> CPUParticles2D
var _fog: Polygon2D
var _t := 1.0
var _snd_t := 0.0
var _snd := ""
var _applied := {}


func setup(w: VillageWorld) -> void:
	world = w
	name = "SeasonDressing"
	_collect_vegetation()
	_build_ground_overlay()
	_dress_roofs()
	_build_weather_layer()
	refresh(true)


# ======================================================================= the look of a moment
## The season's look at (day, minute): palette, snow cover, blossom, ground wash, light, weather and particle levels.
## Pure (no node is touched): the dressing applies it, the tests read it.
static func look_for(day: int, minute: int, seed_ := -1) -> Dictionary:
	var w := Seasons.weights(day, minute)
	var wx := Seasons.weather(day, minute, seed_)
	var mix := func(table: Dictionary) -> Color:
		var c := Color(0, 0, 0, 0)
		for s in w:
			c += (table[s] as Color) * float(w[s])
		return c
	var num := func(table: Dictionary) -> float:
		var v := 0.0
		for s in w:
			v += float(table[s]) * float(w[s])
		return v
	var kind := str(wx["kind"])
	var amt := float(wx["amount"])
	var light: Color = mix.call(LIGHT)
	var dim := float(DIM.get(kind, 0.0)) * amt
	light = light.lerp(Color(0.8, 0.83, 0.88), dim * 0.5)
	if kind == "sun":
		light = light.lerp(Color(1.0, 0.98, 0.93), amt * 0.3)
	var h := float(minute) / 60.0
	var morning := 1.0 - smoothstep(8.0, 11.5, h) if h >= 3.0 else 1.0
	var rain: float = amt * float({"light_rain": 0.45, "showers": 0.75, "rain": 1.0}.get(kind, 0.0))
	var fog: float = amt * float({"fog": 0.36, "mist": 0.24 * (0.35 + 0.65 * morning), "rain": 0.07, "snow": 0.08, "overcast": 0.04}.get(kind, 0.0))
	return {
		"day": day, "minute": minute, "season": Seasons.season(day), "weights": w, "weather": wx,
		"ground": mix.call(GROUND), "foliage": mix.call(FOLIAGE), "pine": mix.call(PINE), "flower": mix.call(FLOWER),
		"reed": mix.call(REED), "light": light, "wash": mix.call(WASH),
		"snow": num.call(SNOW), "blossom": num.call(BLOSSOM),
		"autumn": float(w["autumn"]),
		"fx": {
			"rain": rain,
			"snow": amt if kind == "snow" else 0.0,
			"leaves": maxf(float(w["autumn"]) * 0.3, amt if kind == "leaves" else 0.0) * (1.0 - rain * 0.5),
			"petals": maxf(float(w["spring"]) * 0.22, amt if kind == "blossom" else 0.0) * (1.0 - rain),
			"mist": fog,
		},
		"fog": fog,
	}


## The daylight tint the village's light takes from the season and the weather (VillageWorld._update_light).
func light_tint() -> Color:
	return look.get("light", Color.WHITE)


# ======================================================================= per frame
func _process(delta: float) -> void:
	if world == null or Game.state.is_empty():
		return
	_follow_camera()
	_t += delta
	if _t >= 0.5:
		refresh(false)
	_snd_t += delta
	if _snd_t >= 2.0:
		_snd_t = 0.0
		_update_sound()


## Recompute the look from the saved calendar and apply what changed.
func refresh(force: bool) -> void:
	_t = 0.0
	look = look_for(Game.day(), int(Game.state.get("minute", 720)))
	_apply(force)


func _changed(key: String, v: Variant, force: bool) -> bool:
	if force or not _applied.has(key):
		_applied[key] = v
		return true
	var old: Variant = _applied[key]
	var diff := 0.0
	if v is Color:
		var a: Color = old
		var b: Color = v
		diff = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a)))
	else:
		diff = absf(float(old) - float(v))
	if diff < 0.004:
		return false
	_applied[key] = v
	return true


func _apply(force: bool) -> void:
	if _grass != null and _changed("ground", look["ground"], force):
		_grass.self_modulate = look["ground"]
	var wash: Color = look["wash"]
	if _changed("overlay", Color(wash.r, wash.g, wash.b, wash.a + float(look["snow"]) * 7.0), force):
		_overlay_mat.set_shader_parameter("snow", float(look["snow"]))
		_overlay_mat.set_shader_parameter("wash", Vector4(wash.r, wash.g, wash.b, wash.a))
		_overlay.visible = float(look["snow"]) > 0.001 or wash.a > 0.004   # nothing to draw in high summer
	if _changed("roof_snow", float(look["snow"]), force):
		for m in _roof_mats:
			(m as ShaderMaterial).set_shader_parameter("snow", float(look["snow"]) * 0.95)
	var plants := Color(look["foliage"])
	plants.a = float(look["autumn"]) + float(look["snow"]) * 3.0 + float(look["blossom"]) * 5.0
	var c1 := _changed("plants", plants, force)
	var c2 := _changed("pine", look["pine"], force)
	var c3 := _changed("flower", look["flower"], force)
	if c1 or c2 or c3:
		_dress_plants()
	for k in _fx:
		_level(k, float(look["fx"].get(k, 0.0)))
	if _fog != null:
		_fog.color = Color(0.86, 0.88, 0.92, clampf(float(look["fog"]), 0.0, 0.5))
		_fog.visible = float(look["fog"]) > 0.01


func _dress_plants() -> void:
	var foliage: Color = look["foliage"]
	var autumn := float(look["autumn"])
	var snow := float(look["snow"])
	var blossom := float(look["blossom"])
	for e in _veg:
		var s := e[0] as CanvasItem
		if not is_instance_valid(s):
			continue
		var kind := str(e[1])
		var c := Color.WHITE
		if kind == "tree_pine":
			c = look["pine"]
		elif FLOWERS.has(kind):
			c = look["flower"]
		elif kind == "reeds":
			c = look["reed"]
		elif DECIDUOUS.has(kind):
			# each tree turns in its own way in autumn (gold, orange, russet, red)
			c = foliage.lerp(foliage * (e[3] as Color) / Color(1.0, 0.74, 0.4), autumn * float(e[2]))
			c.a = 1.0
		s.self_modulate = c
	for kind in _mats:
		var m: ShaderMaterial = _mats[kind]
		var bl := blossom if BLOSSOMING.has(kind) else 0.0
		var amount := snow if snow > bl else bl
		m.set_shader_parameter("snow", clampf(amount, 0.0, 1.0) * (0.9 if kind != "tree_pine" else 0.75))
		m.set_shader_parameter("snow_col", SNOW_COL if snow >= bl else BLOSSOM_COL)


# ======================================================================= building the dressing
func _collect_vegetation() -> void:
	var sprites: Array = []
	for n in world.ysort.get_children():
		if n is Node2D:
			for ch in n.get_children():
				if ch is Sprite2D and ch.has_meta("veg"):
					sprites.append(ch)
	for ch in world.floor_layer.get_children():
		if ch is Sprite2D and ch.has_meta("veg"):
			sprites.append(ch)
	for s in sprites:
		var sp := s as Sprite2D
		var kind := str(sp.get_meta("veg"))
		var p := sp.global_position
		var h := Seasons._h(int(p.x), int(p.y), 9)
		var variant: Color = AUTUMN_VARIANTS[int(Seasons._h(int(p.x), int(p.y), 10) * AUTUMN_VARIANTS.size()) % AUTUMN_VARIANTS.size()]
		_veg.append([sp, kind, 0.55 + 0.45 * h, variant])
		# its own copy of the breeze material, so snow and blossom can differ by kind (strength and speed kept)
		if sp.material is ShaderMaterial:
			if not _mats.has(kind):
				_mats[kind] = (sp.material as ShaderMaterial).duplicate()
				(_mats[kind] as ShaderMaterial).set_shader_parameter("noise_tex", noise_texture())
			sp.material = _mats[kind]


func _build_ground_overlay() -> void:
	var gl := world.ground_layer
	if gl.get_child_count() > 0:
		_grass = gl.get_child(0) as CanvasItem   # the grass (VillageWorld._build_ground)
	var size: Array = DB.layout.get("size", [96, 64])
	var r := Rect2(-512, -512, float(size[0]) * VillageWorld.T + 1024, float(size[1]) * VillageWorld.T + 1024)
	_overlay = Polygon2D.new()
	_overlay.name = "SeasonGround"
	_overlay.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = load("res://shaders/season_ground.gdshader")
	_overlay_mat.set_shader_parameter("noise_tex", noise_texture())
	_overlay.material = _overlay_mat
	_overlay.light_mask = 4
	# over the grass and the roads, under the stream, the pond, the harbour and the worked soil
	var at := 1
	for i in gl.get_child_count():
		var ch := gl.get_child(i) as CanvasItem
		if ch != null and ch.material is ShaderMaterial and str((ch.material as ShaderMaterial).shader.resource_path).ends_with("road_ground.gdshader"):
			at = i + 1
			break
	gl.add_child(_overlay)
	gl.move_child(_overlay, at)


func _dress_roofs() -> void:
	var shader: Shader = load("res://shaders/season_snow.gdshader")
	for bid in world.buildings:
		var roof: Variant = world.buildings[bid].get("roof")
		if roof is Sprite2D and (roof as Sprite2D).material == null:
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("noise_tex", noise_texture())
			(roof as Sprite2D).material = m
			_roof_mats.append(m)


func _build_weather_layer() -> void:
	_layer = Node2D.new()
	_layer.name = "Weather"
	_layer.z_index = 46   # over the roofs (40)
	add_child(_layer)
	_wmat = ShaderMaterial.new()
	_wmat.shader = load("res://shaders/weather.gdshader")
	_fog = Polygon2D.new()
	_fog.material = _wmat
	_fog.light_mask = 0
	_fog.visible = false
	_layer.add_child(_fog)
	_fx["mist"] = _particles(18, 16.0, _fx_mist)
	_fx["rain"] = _particles(420, 0.5, _fx_rain)
	_fx["snow"] = _particles(260, 9.0, _fx_snow)
	_fx["leaves"] = _particles(46, 10.0, _fx_leaves)
	_fx["petals"] = _particles(40, 11.0, _fx_petals)


func _particles(max_amount: int, life: float, style: Callable) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.set_meta("max", max_amount)
	p.amount = max_amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emitting = false
	p.visible = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 700)
	p.material = _wmat
	p.light_mask = 0   # in the air: not lit by the street lamps (the night's darkness still applies)
	style.call(p)
	_layer.add_child(p)
	return p


func _fx_rain(p: CPUParticles2D) -> void:
	p.texture = _streak_tex()
	p.particle_flag_align_y = true
	p.direction = Vector2(0.12, 1.0)
	p.spread = 3.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 720.0
	p.initial_velocity_max = 900.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	p.color = Color(0.86, 0.91, 1.0, 0.75)


func _fx_snow(p: CPUParticles2D) -> void:
	p.texture = FX.light_texture()
	p.direction = Vector2(0.15, 1.0)
	p.spread = 22.0
	p.gravity = Vector2(4, 6)
	p.initial_velocity_min = 28.0
	p.initial_velocity_max = 62.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.068
	p.color = Color(1, 1, 1, 1)


func _fx_leaves(p: CPUParticles2D) -> void:
	p.texture = _leaf_tex()
	p.direction = Vector2(0.7, 0.6)
	p.spread = 30.0
	p.gravity = Vector2(6, 9)
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 58.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -140.0
	p.angular_velocity_max = 140.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.7
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.42, 0.12))
	g.set_color(1, Color(0.62, 0.34, 0.14))
	g.add_point(0.35, Color(0.95, 0.7, 0.2))
	g.add_point(0.7, Color(0.76, 0.22, 0.12))
	p.color_initial_ramp = g
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade


func _fx_petals(p: CPUParticles2D) -> void:
	_fx_leaves(p)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.78, 0.86))
	g.set_color(1, Color(1.0, 0.96, 0.98))
	g.add_point(0.5, Color(0.98, 0.66, 0.8))
	p.color_initial_ramp = g


func _fx_mist(p: CPUParticles2D) -> void:
	p.texture = FX.light_texture()
	p.direction = Vector2(1, 0)
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 2.6
	p.scale_amount_max = 4.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.93, 0.96, 0))
	fade.add_point(0.4, Color(0.92, 0.93, 0.96, 0.16))
	fade.add_point(0.7, Color(0.92, 0.93, 0.96, 0.14))
	fade.set_color(fade.get_point_count() - 1, Color(0.92, 0.93, 0.96, 0))
	p.color_ramp = fade


static var _streak: Texture2D
static var _leaf: Texture2D
static var _noise: Texture2D


## A seamless value-noise texture (fixed seed), shared by the ground, roof and plant shaders.
static func noise_texture() -> Texture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		n.seed = 8431
		n.frequency = 1.0 / 16.0
		var img := n.get_seamless_image(256, 256)
		img.convert(Image.FORMAT_L8)
		_noise = ImageTexture.create_from_image(img)
	return _noise


static func _streak_tex() -> Texture2D:
	if _streak == null:
		var img := Image.create(3, 30, false, Image.FORMAT_RGBA8)
		for y in 30:
			var a := sin(PI * float(y) / 29.0)
			for x in 3:
				img.set_pixel(x, y, Color(1, 1, 1, a * [0.45, 1.0, 0.45][x]))
		_streak = ImageTexture.create_from_image(img)
	return _streak


static func _leaf_tex() -> Texture2D:
	if _leaf == null:
		var img := Image.create(10, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 10:
				var d := pow((float(x) - 4.5) / 5.0, 2) + pow((float(y) - 3.0) / 3.2, 2)
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
		_leaf = ImageTexture.create_from_image(img)
	return _leaf


## A weather particle system at `level` (0…1): its opacity follows the level smoothly (fading in from nothing and out
## to nothing); its density is half or full (with a margin, so it rarely switches — a switch restarts it prefilled).
func _level(k: String, level: float) -> void:
	var p: CPUParticles2D = _fx[k]
	if level < 0.02:
		p.emitting = false
		p.visible = false
		return
	var mx := int(p.get_meta("max"))
	var want := p.amount
	if level > 0.6:
		want = mx
	elif level < 0.45:
		want = maxi(4, mx / 2)
	var restart := not p.emitting
	if p.amount != want:
		p.amount = want
		restart = true
	p.modulate.a = clampf(level * 5.0, 0.0, 1.0) * (0.6 + 0.4 * clampf(level, 0.0, 1.0))
	p.emitting = true
	if restart:
		p.restart()
	p.visible = true


## The weather follows the view (it is the sky, not a place); inside a building it stays outside (the shader's hole);
## in a cellar or an upper floor (no street to see) it is not drawn at all.
func _follow_camera() -> void:
	var cam := world.camera
	if cam == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var zoom := cam.zoom if cam.zoom.x > 0.0 else Vector2.ONE
	var half := vs / zoom * 0.5
	var c := cam.get_screen_center_position()
	_layer.position = c
	var ext := half + Vector2(220, 260)
	for k in _fx:
		var p: CPUParticles2D = _fx[k]
		p.emission_rect_extents = ext
		p.position = Vector2(0, -180) if k == "rain" else Vector2.ZERO
	_fog.polygon = PackedVector2Array([-half - Vector2(8, 8), Vector2(half.x + 8, -half.y - 8), half + Vector2(8, 8), Vector2(-half.x - 8, half.y + 8)])
	var b: Dictionary = world.buildings.get(world.area, {})
	if world.area == "village" or b.is_empty():
		_layer.visible = true
		_wmat.set_shader_parameter("hole_on", 0.0)
	elif bool(b.get("area", false)):
		_layer.visible = false
	else:
		_layer.visible = true
		var r: Rect2 = b["rect"]
		var ct := get_viewport().get_canvas_transform()
		var tl := ct * r.position
		var br := ct * r.end
		_wmat.set_shader_parameter("hole", Vector4(tl.x / vs.x, tl.y / vs.y, (br.x - tl.x) / vs.x, (br.y - tl.y) / vs.y))
		_wmat.set_shader_parameter("hole_on", 1.0)


## Rain or the winter wind on its own ambience layer ("weather"), quieter indoors; nothing in calm weather.
func _update_sound() -> void:
	var fx: Dictionary = look.get("fx", {})
	var wx: Dictionary = look.get("weather", {})
	var id := ""
	var lvl := 0.0
	if float(fx.get("rain", 0.0)) > 0.05:
		id = "amb/rain_loop"
		lvl = float(fx["rain"])
	elif float(look.get("snow", 0.0)) > 0.5 and (str(wx.get("kind", "")) in ["snow", "overcast", "fog"]):
		id = "amb/wind_loop"
		lvl = 0.35 + 0.65 * float(fx.get("snow", 0.0))
	if id == "":
		if _snd != "":
			Audio.set_ambience("weather", "", 0.0, 3.0)
			_snd = ""
		return
	var off_map := bool(world.buildings.get(world.area, {}).get("area", false))
	var db := lerpf(-24.0, -8.0, clampf(lvl, 0.0, 1.0)) - (0.0 if world.area == "village" else (18.0 if off_map else 10.0))
	Audio.set_ambience("weather", id, db, 3.0)
	_snd = id
