## ApprenticeActors — the workshop apprentices as living miniatures in the smithy (iteration 012).
## EN: Every on-shift apprentice is an NPCActor (their applicant look) inside the Ironhand forge. They come in through
##     the front door at 8:00, walk to the station of their current operation (Apprentices.current) along the smith's
##     own walk grid (PlayerNav: walls, doorways and station footprints respected), stand at a free working side of
##     it and work with a small motion fitting the station (a hammer bob at the anvil, a stir at the cauldron…). When
##     they fetch from the stock hall they carry the material's icon above their head; at noon they take their break
##     at the living-room table (or in the stock hall) and at 18:00 they leave by the front door. Stations held by an
##     apprentice get a faint ring on the floor; workshop sounds play softly, rate-limited, when they work near the
##     smith. The actors are registered in VillageWorld.npcs (meta "apprentice"), so talking, names, the map and the
##     activity bubbles treat them like everyone else; world.gd's schedule leaves them to this node.
## DA: Lærlingene som levende figurer i smedjen: de kommer ind ad hoveddøren, går til deres station, arbejder med en
##     lille bevægelse, bærer materialer fra lagerhallen, holder pause og går hjem ved fyraften.
class_name ApprenticeActors
extends Node2D

const SYNC := 0.35
const SOUND_NEAR := 620.0
const STRIKE := ["anvil", "arcane_anvil", "grinding_wheel", "rune_cutting_bench", "rune_engraving_stand", "rune_polishing_wheel",
	"stitching_table", "cutting_table", "tailors_bench", "fitting_mannequin", "loom", "embroidery_frame", "thread_spinner", "project_bench"]
const SOUNDS := {"anvil": ["sfx/hammer_1", "sfx/hammer_2", "sfx/hammer_3"], "arcane_anvil": ["sfx/hammer_arcane"], "forge": ["sfx/bellows"],
	"bellows": ["sfx/bellows"], "grinding_wheel": ["sfx/grind_soft"], "rune_polishing_wheel": ["sfx/grind_soft"], "quench_trough": ["sfx/quench"],
	"crucible": ["sfx/bubble"], "cauldron": ["sfx/bubble"], "alembic": ["sfx/glass"], "mortar_station": ["sfx/chisel"], "reagent_table": ["sfx/glass"],
	"rune_cutting_bench": ["sfx/chisel"], "rune_engraving_stand": ["sfx/chisel"], "resonance_pedestal": ["sfx/rune_hum"], "rune_cleansing_basin": ["sfx/water"],
	"stitching_table": ["sfx/stitch"], "embroidery_frame": ["sfx/stitch"], "tailors_bench": ["sfx/stitch"], "thread_spinner": ["sfx/spin"], "loom": ["sfx/spin"],
	"leather_vat": ["sfx/water"], "arcane_crucible": ["sfx/arcane"], "spellbinding_array": ["sfx/arcane"], "leyline_conductor": ["sfx/arcane"],
	"aetheric_stabilizer": ["sfx/arcane"], "project_bench": ["sfx/hammer_1", "sfx/hammer_2"]}

var w: VillageWorld
var actors := {}          # app id -> NPCActor
var _goal := {}           # app id -> {pos, kind, face, station}
var _motion := {}         # app id -> Tween
var _carry := {}          # app id -> Sprite2D
var _rings := {}          # station id -> Node2D
var _t := 0.0
var _snd_t := 2.0
var _spark_t := 1.0
var _last_now := -1


func _ready() -> void:
	name = "ApprenticeActors"
	w = get_parent() as VillageWorld
	Events.apprentices_changed.connect(func(): _t = 0.0)
	_t = 0.0


func _process(delta: float) -> void:
	if Game.state.is_empty() or w == null or w.player == null:
		return
	# the smith's room counts for supervision (work in the room he stands in is done "under his eye")
	Apprentices.smith_room = w.room if (w.area == "smithy" or w.area == "smithy_loft") else ""
	_t -= delta
	if _t <= 0.0:
		_t = SYNC
		sync()
	_sounds(delta)


# ======================================================================= schedule → where each one should be
## Where an apprentice belongs right now, as pure data (the suite tests this):
## {present: bool, kind: "station"|"stock"|"break"|"idle"|"door", station, carrying, activity}.
static func plan_for(a: Dictionary) -> Dictionary:
	var cur := Apprentices.current(a)
	var out := {"present": true, "kind": "idle", "station": "", "carrying": "", "activity": str(cur.get("activity", ""))}
	match str(cur.get("phase", "off")):
		"off":
			out["present"] = false
			out["kind"] = "door"
		"break":
			out["kind"] = "break"
		"carrying":
			out["kind"] = "stock"
			out["carrying"] = str(cur.get("carrying", ""))
		"working", "walking":
			var sid := str(cur.get("station", ""))
			if sid != "" and Property.is_installed(sid):
				out["kind"] = "station"
				out["station"] = sid
	return out


## The apprentices who should be visible in the smithy now (ids, sorted).
static func present_ids() -> Array:
	var out := []
	if Game.state.is_empty() or not Game.state.has("apprentices"):
		return out
	for a in Apprentices.staff():
		if bool(plan_for(a)["present"]):
			out.append(str(a["id"]))
	out.sort()
	return out


## The interaction prompt for a station an apprentice is using ("" = nobody, use the normal label).
static func station_prompt(sid: String, base_label: String) -> String:
	if Game.state.is_empty() or not Game.state.has("apprentices"):
		return base_label
	var u := Apprentices.station_user(sid)
	if u == "" or u == "smith":
		return base_label
	var a := Apprentices.get_a(u)
	if a.is_empty():
		return base_label
	var sname := Property.instance_label(sid).to_lower().trim_prefix("the ")
	var he := "she" if bool(a.get("female", false)) else "he"
	return "%s — %s is working at the %s; %s will step aside for you" % [base_label, str(a["name"]).split(" ")[0], sname, he]


# ======================================================================= sync
func sync() -> void:
	if not Game.state.has("apprentices"):
		_clear_all()
		return
	var now := Game.now()
	var jumped := _last_now < 0 or now - _last_now > 20
	_last_now = now
	var keep := {}
	var idx := 0
	for a in Apprentices.staff():
		var id := str(a["id"])
		keep[id] = true
		_sync_one(a, idx, jumped)
		idx += 1
	for id: String in actors.keys():
		if not keep.has(id):
			_remove(id)
	_sync_rings()


func _actor(a: Dictionary) -> NPCActor:
	var id := str(a["id"])
	if actors.has(id) and is_instance_valid(actors[id]):
		return actors[id]
	var n := NPCActor.new()
	w.ysort.add_child(n)
	n.setup(id, "chars/" + str(a.get("look", "applicant_0")), str(a.get("name", "")))
	n.set_meta("apprentice", true)
	n.visible = false
	n.speed = 96.0
	n.arrived.connect(_on_arrived)
	actors[id] = n
	w.npcs[id] = n
	return n


func _remove(id: String) -> void:
	_stop_motion(id)
	_set_carry(id, "")
	if actors.has(id) and is_instance_valid(actors[id]):
		(actors[id] as Node).queue_free()
	actors.erase(id)
	_goal.erase(id)
	w.npcs.erase(id)


func _clear_all() -> void:
	for id: String in actors.keys():
		_remove(id)
	for sid: String in _rings.keys():
		(_rings[sid] as Node).queue_free()
	_rings.clear()


func _sync_one(a: Dictionary, idx: int, jumped: bool) -> void:
	var id := str(a["id"])
	var p := plan_for(a)
	var n := _actor(a)
	n.display_name = str(a.get("name", ""))
	var door: Vector2 = w.spots.get("smithy_door_out", w.bpos("smithy", 14.0, -1.0))
	if not bool(p["present"]):
		_stop_motion(id)
		_set_carry(id, "")
		if not n.visible:
			return
		if jumped:
			n.visible = false
			n.path = PackedVector2Array()
			_goal.erase(id)
			return
		# walk out through the front door, then vanish
		if str(_goal.get(id, {}).get("kind", "")) != "door":
			_goal[id] = {"pos": door, "kind": "door", "face": "n", "station": ""}
			_walk(n, door)
		return
	var g := _goal_for(a, p, idx)
	if not n.visible:
		n.visible = true
		n.position = g["pos"] if jumped else door
		n.path = PackedVector2Array()
		if not jumped:
			_walk(n, g["pos"])
	elif jumped:
		n.path = PackedVector2Array()
		n.position = g["pos"]
	else:
		var old: Dictionary = _goal.get(id, {})
		if old.is_empty() or (old["pos"] as Vector2).distance_to(g["pos"]) > 12.0 or str(old.get("kind", "")) == "door":
			_walk(n, g["pos"])
	_goal[id] = g
	# carrying a material from the stock hall (or a bite at the break)
	_set_carry(id, str(p["carrying"]) if str(p["kind"]) == "stock" else ("bread_cheese" if str(p["kind"]) == "break" else ""))
	# at the spot: face the work and move with it
	var at := n.path.is_empty() and n.position.distance_to(g["pos"]) < 6.0
	if at:
		n.idle_t = 5.0   # no idle fidgets while at their place
		n.facing = str(g["face"])
		n._play("idle_" + n.facing)
	var working := at and str(g["kind"]) == "station" and Apprentices.station_user(str(g["station"])) == id
	if working:
		_start_motion(id, n, str(g["station"]))
	else:
		_stop_motion(id)


## The goal position for an apprentice's plan: a working side of the station, the stock hall, the break table, or
## an idle place in the forge room (each apprentice keeps a slightly different spot).
func _goal_for(a: Dictionary, p: Dictionary, idx: int) -> Dictionary:
	var spread := Vector2(float((idx % 3) - 1) * 78.0, float(int(idx / 3)) * 60.0)
	match str(p["kind"]):
		"station":
			var sid := str(p["station"])
			var ws := work_spot(sid)
			if Apprentices.station_user(sid) == "smith":
				# the smith has the station: step aside and wait a little further off
				var wp: Vector2 = ws["pos"]
				ws["pos"] = _free_near(wp + (wp - w.station_pos(sid)).normalized() * 70.0 + Vector2(60, 0))
			ws["kind"] = "station"
			ws["station"] = sid
			return ws
		"stock":
			return {"pos": _free_near(_room_center("stock_hall", Vector2(14.5, 8.0)) + spread), "kind": "stock", "face": "n", "station": ""}
		"break":
			var living := Property.room_by_id(Property.rooms(), "living")
			var at := _room_center("stock_hall", Vector2(14.5, 8.0)) + Vector2(-120, 0)
			if not living.is_empty() and Property.room_owned(living) and w.spots.has("quarters_table"):
				at = (w.spots["quarters_table"] as Vector2) + Vector2(0, 70)
			return {"pos": _free_near(at + spread), "kind": "break", "face": "n", "station": ""}
	return {"pos": _free_near(_room_center("forge_room", Vector2(5.0, 5.0)) + Vector2(60, 40) + spread), "kind": "idle", "face": "s", "station": ""}


func _room_center(rid: String, fallback_tiles: Vector2) -> Vector2:
	for rm in w.buildings.get("smithy", {}).get("rooms", []):
		if str(rm["id"]) == rid:
			return (rm["rect"] as Rect2).get_center()
	return w.bpos("smithy", fallback_tiles.x, fallback_tiles.y)


## A working side of a station: beside it (the miniature stands next to the work, never in front of or inside its
## picture), else below it, else above it — on clear floor, away from the other stations' pictures.
func work_spot(sid: String) -> Dictionary:
	var c := w.station_pos(sid)
	var size: Array = DB.station(sid).get("size", [96, 96])
	var sx := float(size[0])
	var sy := float(size[1])
	var cands := [[Vector2(-sx * 0.5 - 24.0, sy * 0.3), "e"], [Vector2(sx * 0.5 + 24.0, sy * 0.3), "w"], [Vector2(0, sy * 0.5 + 40.0), "n"],
		[Vector2(0, -sy * 0.5 - 6.0), "s"]]
	var own_room := room_id(c)   # S2 (OBS-21): worked from its own room — never through a wall or from the street
	for cnd in cands:
		var p: Vector2 = c + (cnd[0] as Vector2)
		if _spot_ok(p, sid) and room_id(p) == own_room:
			return {"pos": p, "face": str(cnd[1])}
	var near := _free_near(c + (cands[2][0] as Vector2), own_room)
	return {"pos": near, "face": "n" if near.y >= c.y else "s"}


## Clear floor for a miniature: walkable, clear of walls and footprints, and its standing figure (about 44×86 px above
## the feet) not over another station's picture or base.
func _spot_ok(p: Vector2, own := "") -> bool:
	var nav := PlayerNav.of(w)
	if nav != null and not (nav.walkable(p) and nav.clear_at(p, 16.0)):
		return false
	var body := Rect2(p + Vector2(-22, -80), Vector2(44, 86))
	if not _inside_room(body, p):
		return false
	for sid_v in (Property.st()["stations"] as Dictionary).keys():
		var sid := str(sid_v)
		if sid == own or not Property.is_installed(sid):
			continue
		var size: Array = DB.station(sid).get("size", [96, 96])
		var sz := Vector2(float(size[0]), float(size[1]))
		if Rect2(w.station_pos(sid) - sz * 0.5, Vector2(sz.x, sz.y * 1.2)).grow(6.0).intersects(body):
			return false
	return true


## S2 (OBS-21): the standing figure stays inside the room whose floor it stands on — its picture never crosses a wall.
## (Before, the side above a station by the north wall — the forge — put an apprentice on top of the outer wall.)
func _inside_room(body: Rect2, feet: Vector2) -> bool:
	for bid in ["smithy", "smithy_loft"]:
		for rm in w.buildings.get(bid, {}).get("rooms", []):
			var r: Rect2 = rm["rect"]
			if r.has_point(feet):
				return r.grow(2.0).encloses(body)
	return false   # not on the workshop's floor at all (the street outside a wall)


## The workshop room (ground floor or Loft) under `p` ("" = none).
func room_id(p: Vector2) -> String:
	for bid in ["smithy", "smithy_loft"]:
		var rid := w.room_at(bid, p)
		if rid != "":
			return rid
	return ""


## Clear floor near `p`; with `in_room`, only in that room (a station's own room).
func _free_near(p: Vector2, in_room := "") -> Vector2:
	var nav := PlayerNav.of(w)
	if nav == null:
		return p
	nav.ensure_grid()
	if _spot_ok(p) and (in_room == "" or room_id(p) == in_room):
		return p
	# spiral outwards for clear floor away from the stations
	var r := 24.0
	while r <= 260.0:
		for k in 16:
			var q := p + Vector2(cos(TAU * k / 16.0), sin(TAU * k / 16.0)) * r
			if _spot_ok(q) and (in_room == "" or room_id(q) == in_room):
				return q
		r += 20.0
	var c := nav.nearest_cell(p, 200.0)
	return Vector2(c) * PlayerNav.CELL if c.x != -99999 else p


func _walk(n: NPCActor, to: Vector2) -> void:
	var nav := PlayerNav.of(w)
	if nav != null:
		var pl := nav.plan(n.position, to)
		if not pl.is_empty():
			var pts: PackedVector2Array = pl["points"]
			if pts.size() > 0 and pts[pts.size() - 1].distance_to(to) > 4.0:
				pts.append(to)
			n.go(pts)
			return
	n.go(PackedVector2Array([n.position, to]))


func _on_arrived(id: String) -> void:
	var n: NPCActor = actors.get(id)
	if n == null:
		return
	if str(_goal.get(id, {}).get("kind", "")) == "door":
		n.visible = false
		_goal.erase(id)
		return
	_t = 0.0


# ======================================================================= motion, carried things, rings, sound
func _start_motion(id: String, n: NPCActor, sid: String) -> void:
	if _motion.has(id) and is_instance_valid(_motion[id]) and (_motion[id] as Tween).is_running():
		return
	_stop_motion(id)
	var s := n.sprite
	var tw := s.create_tween().set_loops()
	if STRIKE.has(Property.type_of(sid)):   # #37: the motion is the station type's, the place the instance
		# a short strike: up, down hard, a beat
		tw.tween_property(s, "offset:y", -38.0, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "offset:y", -30.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "offset:y", -32.0, 0.12)
		tw.tween_interval(0.32)
	else:
		# a slow stir / tend: lean side to side
		tw.tween_property(s, "rotation", 0.07, 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "rotation", -0.07, 0.55).set_trans(Tween.TRANS_SINE)
	_motion[id] = tw


func _stop_motion(id: String) -> void:
	if _motion.has(id):
		if is_instance_valid(_motion[id]):
			(_motion[id] as Tween).kill()
		_motion.erase(id)
		var n: NPCActor = actors.get(id)
		if n != null and is_instance_valid(n):
			n.sprite.offset = Vector2(0, -32)
			n.sprite.rotation = 0.0


func _set_carry(id: String, def: String) -> void:
	var cur: Sprite2D = _carry.get(id)
	if def == "":
		if cur != null and is_instance_valid(cur):
			cur.queue_free()
		_carry.erase(id)
		return
	var tex_id := "icons/" + def
	if not Assets.has_tex(tex_id):
		tex_id = "icons/ingot_iron"
	if cur != null and is_instance_valid(cur) and str(cur.get_meta("def", "")) == def:
		return
	if cur != null and is_instance_valid(cur):
		cur.queue_free()
	var n: NPCActor = actors.get(id)
	if n == null:
		return
	var s := Sprite2D.new()
	s.texture = Assets.get_tex(tex_id)
	var tsz := s.texture.get_size() if s.texture else Vector2(64, 64)
	s.scale = Vector2.ONE * (34.0 / maxf(1.0, maxf(tsz.x, tsz.y)))
	s.position = Vector2(14, -58)
	s.z_index = 2
	s.set_meta("def", def)
	n.add_child(s)
	_carry[id] = s


## A faint inked ring on the floor under every station an apprentice holds.
func _sync_rings() -> void:
	var held := {}
	for a in Apprentices.staff():
		var g: Dictionary = _goal.get(str(a["id"]), {})
		var sid := str(g.get("station", ""))
		if sid != "" and Apprentices.station_user(sid) == str(a["id"]):
			held[sid] = true
	for sid: String in _rings.keys():
		if not held.has(sid):
			(_rings[sid] as Node).queue_free()
			_rings.erase(sid)
	for sid: String in held:
		if _rings.has(sid):
			continue
		var size: Array = DB.station(sid).get("size", [96, 96])
		var rx := float(size[0]) * 0.58
		var ry := maxf(rx * 0.3, float(size[1]) * 0.22)
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in 41:
			var ang := TAU * i / 40.0
			pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
		ring.points = pts
		ring.width = 3.0
		ring.default_color = Color("#7e2418", 0.55)
		ring.position = w.station_pos(sid) + Vector2(0, float(size[1]) * 0.42)
		ring.z_index = 1   # above the floor and the station's base, below every figure
		w.floor_layer.add_child(ring)
		_rings[sid] = ring


func rings() -> Array:
	return _rings.keys()


func _sounds(delta: float) -> void:
	_snd_t -= delta
	_spark_t -= delta
	if _snd_t > 0.0 and _spark_t > 0.0:
		return
	if (w.area != "smithy" and w.area != "smithy_loft") or Game.ui_blockers > 0:
		return
	var best := ""
	var best_d := SOUND_NEAR
	for id: String in _motion:
		var sid := str(_goal.get(id, {}).get("station", ""))
		if sid == "":
			continue
		var d := w.station_pos(sid).distance_to(w.player.position)
		if d < best_d:
			best_d = d
			best = sid
	if best == "":
		return
	if _snd_t <= 0.0:
		_snd_t = randf_range(2.4, 4.2)
		var arr: Array = SOUNDS.get(Property.type_of(best), ["sfx/hammer_1"])
		Audio.play(str(arr.pick_random()), -18.0 - best_d / SOUND_NEAR * 8.0, randf_range(0.92, 1.06))
	if _spark_t <= 0.0:
		_spark_t = randf_range(1.6, 2.8)
		if Property.type_of(best) in ["anvil", "arcane_anvil", "grinding_wheel"]:
			var sp := FX.sparks()
			sp.amount = 10
			sp.position = w.station_pos(best) + Vector2(0, -6)
			w.add_child(sp)
			sp.emitting = true
			get_tree().create_timer(1.6).timeout.connect(sp.queue_free)
