## Village10 — iteration 010 outdoor dressing for VillageWorld (data: layout.json, see tools/data/village10_layout.py).
## EN: hanging trade signs beside every door (never solid, drawn above the actors, swaying a little), street lamps with
##     a lit lantern at night, overhead bunting, outdoor interactables of the new venues (the Hales' menagerie, the
##     square's honours board), the caravan camp whose wagon comes and goes with Commerce.caravan_present(), horses and
##     cows grazing in their paddocks, and the animals' walkability grid (AnimalNav).
## DA: Skilte, gadelygter, karavanelejren, heste og køer på fold og dyrenes gangbare område.
class_name Village10
extends RefCounted

const T := 64.0
## The lantern posts of iteration 009 (used when layout.json has no "lamps" list).
const OLD_LAMPS := [[50, 29.2], [68, 32.8], [40, 29.5], [26, 32.6], [12, 29.4], [80, 32.6], [57.2, 20], [60.8, 42], [57.4, 52], [33.4, 33.4],
	[52.0, 14.0], [40.4, 13.4], [27.0, 13.2], [37.2, 10.7], [70.0, 18.4], [79.6, 50.4], [92.2, 51.0], [84.0, 58.6],
	[64.2, 57.0], [8.6, 24.0], [60.8, 46.0], [83.6, 36.6], [11.0, 33.8], [57.6, 8.0]]


# ----------------------------------------------------------------------- signs
## Hangs building `b`'s sign beside its first door: outside the wall, clear of the doorway, no collision.
static func place_sign(w: VillageWorld, b: Dictionary, r: Rect2) -> Sprite2D:
	var d0: Dictionary = b["doors"][0]
	var side := -1.0 if int(b.get("sign_side", -1)) < 0 else 1.0
	var dc: Vector2 = w._door_center(r, d0)
	var out: Vector2 = w._door_out(d0)
	var along := Vector2(1, 0) if d0["side"] in ["n", "s"] else Vector2(0, 1)
	var half := float(d0["w"]) * T * 0.5
	var s := Sprite2D.new()
	s.texture = Assets.get_tex("props/" + str(b["sign"]), Vector2i(80, 48))
	# pivot on the bracket (top centre) so the board can swing a touch
	s.offset = Vector2(0, 24)
	var pos: Vector2
	match str(d0["side"]):
		"s":
			pos = dc + out * (VillageWorld.WALL * 0.5 + 2.0) + along * side * (half + 50.0)
		"n":
			pos = dc + out * (VillageWorld.WALL * 0.5 + 50.0) + along * side * (half + 50.0)
		_:
			pos = dc + out * (VillageWorld.WALL * 0.5 + 44.0) + along * side * (half + 30.0) - Vector2(0, 24)
	s.position = pos
	s.z_index = 30
	w.add_child(s)
	var sw := s.create_tween().set_loops()
	var amp := 0.03 + 0.02 * float(absi(str(b["id"]).hash()) % 5) / 5.0
	sw.tween_property(s, "rotation", amp, 1.9 + float(absi(str(b["id"]).hash()) % 7) * 0.1).set_trans(Tween.TRANS_SINE)
	sw.tween_property(s, "rotation", -amp, 2.1).set_trans(Tween.TRANS_SINE)
	var all: Array = w.get_meta("v10_signs", [])
	all.append({"building": str(b["id"]), "sprite": str(b["sign"]), "node": s, "pos": pos})
	w.set_meta("v10_signs", all)
	return s


# ----------------------------------------------------------------------- street lamps
static func build_lamps(w: VillageWorld) -> void:
	var lamps: Array = DB.layout.get("lamps", OLD_LAMPS)
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for p in lamps:
		var pos := w.tp(p)
		w._veg_mark(pos, T * 1.0, 3)
		var holder := Node2D.new()
		holder.position = pos
		var s := Sprite2D.new()
		s.texture = Assets.get_tex("props/street_lamp", Vector2i(64, 128))
		s.position = Vector2(2, -52)        # the stone foot (32, 116 in the sprite) stands on the holder's origin
		holder.add_child(s)
		var g := Sprite2D.new()
		g.texture = Assets.get_tex("props/street_lamp_glow", Vector2i(64, 128))
		g.position = s.position
		g.material = glow_mat
		g.modulate.a = 0.0
		holder.add_child(g)
		w._window_glows.append(g)
		w.ysort.add_child(holder)
		w._solid(Rect2(pos - Vector2(12, 8), Vector2(24, 14)))
		var l := FX.light(Color("#ffb060"), 290.0, 0.0, true)
		l.position = pos + Vector2(18, -46)
		w.add_child(l)
		w.night_lights.append(l)
	w.set_meta("v10_lamps", lamps.size())


# ----------------------------------------------------------------------- venues outdoors
static func build_outdoors(w: VillageWorld) -> void:
	for f in DB.layout.get("overhead_props", []):
		var info: Dictionary = DB.props.get(str(f[0]), {"size": [64, 64]})
		var s := Sprite2D.new()
		s.texture = Assets.get_tex("props/" + str(f[0]), Vector2i(int(info["size"][0]), int(info["size"][1])))
		s.position = w.tp([f[1], f[2]])
		s.rotation = deg_to_rad(float(f[3])) if f.size() > 3 else 0.0
		s.z_index = 31
		w.add_child(s)
	for it in DB.layout.get("outdoor_interact", []):
		w._add_interactable(w.tp(it["pos"]), float(it.get("r", 120)), str(it["kind"]), str(it["id"]), str(it["label"]))
	_build_caravan(w)


## The caravan wagon, its crates and the `caravan` interactable exist while the caravan is in the village.
static func _build_caravan(w: VillageWorld) -> void:
	var cv: Dictionary = DB.layout.get("caravan", {})
	if cv.is_empty():
		return
	var nodes: Array = []
	var bodies: Array = []
	var items: Array = [["caravan_wagon", cv["wagon"]]]
	for c in cv.get("crates", []):
		items.append(["crate_stack", c])
	for it in items:
		var id: String = it[0]
		var pos := w.tp(it[1])
		var info: Dictionary = DB.props.get(id, {"size": [64, 64]})
		var size := Vector2(float(info["size"][0]), float(info["size"][1]))
		var holder := Node2D.new()
		holder.position = pos + Vector2(0, size.y * 0.3)
		var s := Sprite2D.new()
		s.texture = Assets.get_tex("props/" + id, Vector2i(int(size.x), int(size.y)))
		s.position = Vector2(0, -size.y * 0.3)
		holder.add_child(s)
		w.ysort.add_child(holder)
		nodes.append(holder)
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = size * Vector2(0.8, 0.6)
		cs.shape = sh
		body.position = pos + Vector2(0, size.y * 0.1)
		body.add_child(cs)
		w.add_child(body)
		bodies.append(cs)
	var fire := w.tp(DB.layout.get("caravan", {}).get("fire", cv["wagon"]))
	for f in DB.layout.get("outdoor_props", []):
		if str(f[0]) == "campfire":
			fire = w.tp([f[1], f[2]])
	var fl := FX.light(Color("#ff9a40"), 300.0, 0.0, true)
	fl.position = fire
	w.add_child(fl)
	var em := FX.embers(10)
	em.position = fire
	w.add_child(em)
	w.set_meta("v10_caravan", {"nodes": nodes, "bodies": bodies, "light": fl, "embers": em, "def": cv["interact"]})
	var wr: WeakRef = weakref(w)
	Events.hour_passed.connect(func(_d: int, _h: int) -> void: _refresh_ref(wr))
	Events.day_started.connect(func(_d: int) -> void: _refresh_ref(wr))
	refresh_caravan(w)


## Is the caravan in the village? Commerce.caravan_present() when the Commerce system exists (guarded); a world can
## force it with meta "v10_caravan_force" (true/false) for play-tests.
static func caravan_present(w: Node = null) -> bool:
	if w != null and w.has_meta("v10_caravan_force"):
		return bool(w.get_meta("v10_caravan_force"))
	if ResourceLoader.exists("res://scripts/systems/commerce.gd"):
		var sc: Script = load("res://scripts/systems/commerce.gd")
		for m in sc.get_script_method_list():
			if str(m["name"]) == "caravan_present":
				return bool(sc.call("caravan_present"))
	return false


static func _refresh_ref(wr: WeakRef) -> void:
	var o: Object = wr.get_ref()
	if o != null and o is VillageWorld:
		refresh_caravan(o as VillageWorld)


static func refresh_caravan(w: VillageWorld) -> void:
	if not w.has_meta("v10_caravan"):
		return
	var c: Dictionary = w.get_meta("v10_caravan")
	var here := caravan_present(w)
	for n in c["nodes"]:
		(n as Node2D).visible = here
	for cs in c["bodies"]:
		(cs as CollisionShape2D).set_deferred("disabled", not here)
	(c["embers"] as CPUParticles2D).emitting = here
	var l: PointLight2D = c["light"]
	l.visible = here
	l.energy = 0.9 if here else 0.0
	for i in range(w.interactables.size() - 1, -1, -1):
		if w.interactables[i]["kind"] == "caravan":
			w.interactables.remove_at(i)
	if here:
		var d: Dictionary = c["def"]
		w._add_interactable(w.tp(d["pos"]), float(d.get("r", 150)), str(d["kind"]), str(d["id"]), str(d["label"]))


static func set_caravan(w: VillageWorld, present: bool) -> void:
	w.set_meta("v10_caravan_force", present)
	refresh_caravan(w)


# ----------------------------------------------------------------------- livestock & the walkability grid
static func spawn_livestock(w: VillageWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1010
	for pd in DB.layout.get("paddocks", []):
		var r: Array = pd["rect"]
		var rect := Rect2(w.tp([r[0], r[1]]), Vector2(float(r[2]), float(r[3])) * T).grow(-T * 0.7)
		var sprites: Array = pd.get("sprites", ["animal_cow_1"])
		for i in int(pd.get("count", 1)):
			var at := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
			var an := AnimalActor.new()
			an.setup(str(sprites[i % sprites.size()]), at, maxf(rect.size.x, rect.size.y), rect, w)
			an.set_meta("paddock", str(pd["id"]))
			w.ysort.add_child(an)
			w.animals.append(an)


static func build_nav(w: VillageWorld) -> AnimalNav:
	var size: Array = DB.layout.get("size", [96, 64])
	var houses: Array = []
	for bid in w.buildings:
		if not w.buildings[bid]["area"]:
			houses.append(w.buildings[bid]["rect"])
	return AnimalNav.create(w.solid_rects, houses, Vector2(float(size[0]), float(size[1])) * T)
