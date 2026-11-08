## PlayerNav — point-and-click movement and quick travel for the smith.
## EN: A walk grid (32 px cells) is rasterised from the world's static collision rectangles with the smith's
##     clearance, so every path respects walls, doors, furniture, water and stations. Floors joined by stairs
##     (the inn's rooms upstairs, Barnaby's basement) are bridged through the stair interactables.
##     Left-click the ground to walk there, an object to walk up and use it, a person to walk up and talk.
##     Any keyboard movement cancels. Quick travel walks the same paths at five times the pace while the clock
##     advances by the normal walking time (QuickTravel); any key or click stops it where it is.
## DA: Peg-og-klik-bevægelse og hurtigrejse. Et gangnet bygges ud fra verdenens kollisioner; trapper forbinder
##     etager. Hurtigrejse går ruten hurtigt, men uret flyttes den fulde gåtid frem.
class_name PlayerNav
extends Node

signal travel_finished(dest: String, minutes: int, cancelled: bool)

const CELL := 32.0
const CLEAR := 21.0                # clearance used for the grid (the smith's circle is 20 px)
const LOS_CLEAR := 20.5
const FOOT := Vector2(0, -6)       # the smith's collision circle sits 6 px above his feet
const NPC_REACH := 82.0

var world: VillageWorld
var player: PlayerBody

# ---- the walk grid
var grid: AStarGrid2D
var _region := Rect2i()
var _rects: Array[Rect2] = []
var _bucket := {}                  # Vector2i (128 px) -> Array of rect indices
var _comp := PackedInt32Array()    # connected component per cell (-1 = solid)
var _sig := -1
var _checked := -100000

# ---- following a click
var path := PackedVector2Array()
var jumps := {}
var _i := 0
var goal := {}                     # {"kind": "ground"|"entity"|"npc", "e": {...}, "npc": id, "at": Vector2}
var _stuck_t := 0.0
var _stuck_from := Vector2.ZERO
var _repaths := 0
var _npc_t := 0.0
var marker: Node2D

# ---- quick travel
var trip: QuickTravel
var _last_now := 0
var _pending_dest := ""
var _pending_frames := 0


static func of(w: Node) -> PlayerNav:
	if w == null:
		return null
	return w.get_node_or_null("PlayerNav") as PlayerNav


func _ready() -> void:
	name = "PlayerNav"
	process_physics_priority = -1


func setup(w: VillageWorld, p: PlayerBody) -> void:
	world = w
	player = p
	player.nav = self


func active() -> bool:
	return trip != null or _i < path.size()


func traveling() -> bool:
	return trip != null


# ======================================================================= the walk grid
func _static_shapes() -> Array:
	var out := []
	for b in world.find_children("*", "StaticBody2D", true, false):
		for cs in (b as Node).get_children():
			if cs is CollisionShape2D and (cs as CollisionShape2D).shape and not (cs as CollisionShape2D).disabled:
				out.append(cs)
	return out


## (Re)builds the grid when the world's static collision changed (stations moved, a building rebuilt…).
func ensure_grid(force := false) -> void:
	if not force and grid != null and Time.get_ticks_msec() - _checked < 1000:
		return
	_checked = Time.get_ticks_msec()
	var shapes := _static_shapes()
	if not force and grid != null and shapes.size() == _sig:
		return
	_sig = shapes.size()
	_rects.clear()
	_bucket.clear()
	for cs: CollisionShape2D in shapes:
		var r := _shape_rect(cs)
		if r.size.x > 0.0 and r.size.y > 0.0:
			_rects.append(r)
	for i in _rects.size():
		var g := _rects[i].grow(CLEAR + 2.0)
		for bx in range(int(floor(g.position.x / 128.0)), int(floor(g.end.x / 128.0)) + 1):
			for by in range(int(floor(g.position.y / 128.0)), int(floor(g.end.y / 128.0)) + 1):
				var k := Vector2i(bx, by)
				if not _bucket.has(k):
					_bucket[k] = []
				(_bucket[k] as Array).append(i)
	# bounds: the village map and every building or separate floor
	var size: Array = DB.layout.get("size", [96, 64])
	var bounds := Rect2(0, 0, float(size[0]) * VillageWorld.T, float(size[1]) * VillageWorld.T)
	for bid in world.buildings:
		bounds = bounds.merge(world.buildings[bid]["rect"] as Rect2)
	bounds = bounds.grow(64.0)
	var c0 := Vector2i(int(floor(bounds.position.x / CELL)), int(floor(bounds.position.y / CELL)))
	var c1 := Vector2i(int(ceil(bounds.end.x / CELL)), int(ceil(bounds.end.y / CELL)))
	_region = Rect2i(c0, c1 - c0)
	grid = AStarGrid2D.new()
	grid.region = _region
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# rasterise: a cell is solid if the smith's circle there would touch a rectangle
	for i in _rects.size():
		var g := _rects[i].grow(CLEAR)
		for cx in range(maxi(c0.x, int(floor(g.position.x / CELL))), mini(c1.x, int(ceil(g.end.x / CELL)) + 1)):
			for cy in range(maxi(c0.y, int(floor(g.position.y / CELL))), mini(c1.y, int(ceil(g.end.y / CELL)) + 1)):
				var c := Vector2i(cx, cy)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c) and _rect_dist(_rects[i], Vector2(c) * CELL + FOOT) < CLEAR:
					grid.set_point_solid(c, true)
	_components()


func _shape_rect(cs: CollisionShape2D) -> Rect2:
	var xf := cs.global_transform
	var sh := cs.shape
	var local: Rect2
	if sh is RectangleShape2D:
		var s := (sh as RectangleShape2D).size
		local = Rect2(-s * 0.5, s)
	elif sh is CircleShape2D:
		var r := (sh as CircleShape2D).radius
		local = Rect2(-r, -r, r * 2.0, r * 2.0)
	else:
		local = sh.get_rect()
	return xf * local


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func _cidx(c: Vector2i) -> int:
	return (c.y - _region.position.y) * _region.size.x + (c.x - _region.position.x)


func _components() -> void:
	var n := _region.size.x * _region.size.y
	_comp.resize(n)
	_comp.fill(-2)
	var label := 0
	for y in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var c := Vector2i(x, y)
			if _comp[_cidx(c)] != -2:
				continue
			if grid.is_point_solid(c):
				_comp[_cidx(c)] = -1
				continue
			var stack: Array[Vector2i] = [c]
			_comp[_cidx(c)] = label
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = q + d
					if not grid.is_in_boundsv(nb):
						continue
					var ni := _cidx(nb)
					if _comp[ni] != -2:
						continue
					if grid.is_point_solid(nb):
						_comp[ni] = -1
						continue
					_comp[ni] = label
					stack.append(nb)
			label += 1


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x / CELL)), int(round(p.y / CELL)))


func comp_at(c: Vector2i) -> int:
	if grid == null or not grid.is_in_boundsv(c):
		return -1
	return _comp[_cidx(c)]


## Is the smith's circle clear of every static rectangle at `p` (his feet)?
func clear_at(p: Vector2, r := LOS_CLEAR) -> bool:
	var q := p + FOOT
	var k := Vector2i(int(floor(q.x / 128.0)), int(floor(q.y / 128.0)))
	for i in _bucket.get(k, []):
		if _rect_dist(_rects[int(i)], q) < r:
			return false
	return true


func walkable(p: Vector2) -> bool:
	ensure_grid()
	return comp_at(cell_of(p)) >= 0


## The walkable cell nearest `p` within `max_px` (optionally in component `comp`); Vector2i(-99999, 0) if none.
func nearest_cell(p: Vector2, max_px := 160.0, comp := -1) -> Vector2i:
	var c := cell_of(p)
	var best := Vector2i(-99999, 0)
	var bd := INF
	var rr := int(ceil(max_px / CELL))
	for dx in range(-rr, rr + 1):
		for dy in range(-rr, rr + 1):
			var q := c + Vector2i(dx, dy)
			var k := comp_at(q)
			if k < 0 or (comp >= 0 and k != comp):
				continue
			var d := (Vector2(q) * CELL).distance_to(p)
			if d <= max_px and d < bd:
				bd = d
				best = q
	return best


static func _ok(c: Vector2i) -> bool:
	return c.x != -99999


## A path from `from` to `to` (both world positions). Returns {"points", "jumps", "length"} or {} when there
## is no way. With `reach` > 0 the walk may stop anywhere within `reach` of `to` (to use an object there).
func plan(from: Vector2, to: Vector2, reach := 0.0) -> Dictionary:
	ensure_grid()
	var a := nearest_cell(from, 96.0)
	if not _ok(a):
		return {}
	var ca := comp_at(a)
	var b := nearest_cell(to, maxf(reach, 140.0) if reach > 0.0 else 220.0, ca)
	if _ok(b) and reach > 0.0 and (Vector2(b) * CELL).distance_to(to) > reach:
		b = Vector2i(-99999, 0)
	if _ok(b):
		var exact := reach <= 0.0 and comp_at(cell_of(to)) == ca and clear_at(to) and los(Vector2(b) * CELL, to)
		var pts := _grid_path(from, a, b, to if exact else Vector2(b) * CELL)
		if pts.is_empty():
			return {}
		return {"points": pts, "jumps": {}, "length": QuickTravel.path_length(pts)}
	# another floor: go by the stairs
	var best := {}
	for e in world.interactables:
		if e["kind"] != "stairs" or not world.spots.has("stairs_" + str(e["id"])):
			continue
		var s := nearest_cell(e["pos"], float(e["r"]) - 10.0, ca)
		if not _ok(s):
			continue
		var arrive: Vector2 = world.spots["stairs_" + str(e["id"])]
		var a2 := nearest_cell(arrive, 96.0)
		if not _ok(a2):
			continue
		var b2 := nearest_cell(to, maxf(reach, 140.0) if reach > 0.0 else 220.0, comp_at(a2))
		if not _ok(b2) or (reach > 0.0 and (Vector2(b2) * CELL).distance_to(to) > reach):
			continue
		var p1 := _grid_path(from, a, s, Vector2(s) * CELL)
		var p2 := _grid_path(arrive, a2, b2, to if reach <= 0.0 and clear_at(to) and comp_at(cell_of(to)) == comp_at(a2) else Vector2(b2) * CELL)
		if p1.is_empty() or p2.is_empty():
			continue
		var pts2 := p1.duplicate()
		var hop := pts2.size() - 1
		pts2.append_array(p2)
		var hops := {hop: true}
		var l := QuickTravel.path_length(pts2, hops)
		if best.is_empty() or l < float(best["length"]):
			best = {"points": pts2, "jumps": hops, "length": l}
	return best


func _grid_path(from: Vector2, a: Vector2i, b: Vector2i, end: Vector2) -> PackedVector2Array:
	var ids := grid.get_id_path(a, b)
	if ids.is_empty():
		return PackedVector2Array()
	var raw := PackedVector2Array([from])
	for c in ids:
		raw.append(Vector2(c) * CELL)
	if end.distance_to(raw[raw.size() - 1]) > 1.0:
		raw.append(end)
	return _smooth(raw)


## String-pulls a grid path: corners only, then straight runs wherever the smith fits.
func _smooth(raw: PackedVector2Array) -> PackedVector2Array:
	if raw.size() <= 2:
		return raw
	var corners := PackedVector2Array([raw[0]])
	for i in range(1, raw.size() - 1):
		var d1 := (raw[i] - raw[i - 1]).normalized()
		var d2 := (raw[i + 1] - raw[i]).normalized()
		if d1.distance_to(d2) > 0.01:
			corners.append(raw[i])
	corners.append(raw[raw.size() - 1])
	var out := PackedVector2Array([corners[0]])
	var anchor := 0
	var j := 1
	while j < corners.size():
		if j + 1 < corners.size() and los(corners[anchor], corners[j + 1]):
			j += 1
			continue
		out.append(corners[j])
		anchor = j
		j += 1
	return out


## Can the smith walk straight from a to b?
func los(a: Vector2, b: Vector2) -> bool:
	var l := a.distance_to(b)
	var n := int(ceil(l / 8.0))
	for k in range(1, n):
		if not clear_at(a.lerp(b, float(k) / float(n))):
			return false
	return true


# ======================================================================= clicks
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not bool(Settings.get_value("gameplay/click_to_move", true)) or not _free() or _over_hud(mb.position):
		return
	get_viewport().set_input_as_handled()
	click_at(world.get_viewport().get_canvas_transform().affine_inverse() * mb.position)


## Nothing on screen holds the smith (no window, fade or scene).
func _free() -> bool:
	if world == null or player == null or player.frozen or Game.ui_open > 0 or Game.ui_blockers > 0:
		return false
	if UIRoot.instance and is_instance_valid(UIRoot.instance.current):
		return false
	return trip == null


## Is the pointer over a HUD box (the status panel, minimap, toolbar, toasts, cards)?
func _over_hud(screen: Vector2) -> bool:
	if UIRoot.instance == null or UIRoot.instance.hud == null:
		return false
	return _hud_hit(UIRoot.instance.hud, screen, 0)


func _hud_hit(n: Node, screen: Vector2, depth: int) -> bool:
	for c in n.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var ctl := c as Control
		if (ctl is PanelContainer or ctl is VillageMapView or ctl.mouse_filter == Control.MOUSE_FILTER_STOP) and ctl.get_global_rect().has_point(screen):
			return true
		if depth < 3 and _hud_hit(ctl, screen, depth + 1):
			return true
	return false


## What is under a world point: a person, an object or the ground.
func pick(p: Vector2) -> Dictionary:
	for id in world.npcs:
		var n: NPCActor = world.npcs[id]
		if n.visible and absf(p.x - n.position.x) < 34.0 and p.y > n.position.y - 92.0 and p.y < n.position.y + 14.0:
			return {"kind": "npc", "npc": id}
	var best := {}
	var bd := INF
	for e in world.interactables:
		var hit := false
		var d := p.distance_to(e["pos"])
		if e["kind"] == "station" and DB.stations.has(str(e["id"])):
			var sz: Array = DB.station(str(e["id"]))["size"]
			hit = Rect2((e["pos"] as Vector2) - Vector2(float(sz[0]), float(sz[1])) * 0.5, Vector2(float(sz[0]), float(sz[1]))).has_point(p)
		else:
			hit = d < minf(46.0, float(e["r"]))
		if hit and d < bd:
			bd = d
			best = e
	if not best.is_empty():
		return {"kind": "entity", "e": best}
	return {"kind": "ground"}


func click_at(p: Vector2) -> bool:
	var t := pick(p)
	cancel()
	match str(t["kind"]):
		"npc":
			var n: NPCActor = world.npcs[t["npc"]]
			if player.position.distance_to(n.position) < NPC_REACH:
				_arrive_npc(str(t["npc"]))
				return true
			return _go(n.position, NPC_REACH - 12.0, {"kind": "npc", "npc": t["npc"], "at": n.position}, n.position)
		"entity":
			var e: Dictionary = t["e"]
			if _in_reach(e):
				_use(e)
				return true
			return _go(e["pos"], float(e["r"]) - 12.0, {"kind": "entity", "e": e}, p)
	return _go(p, 0.0, {"kind": "ground"}, p)


func _go(to: Vector2, reach: float, g: Dictionary, mark_at: Vector2) -> bool:
	var pl := plan(player.position, to, reach)
	if pl.is_empty():
		_mark(mark_at, false)
		return false
	path = pl["points"]
	jumps = pl["jumps"]
	_i = 1
	goal = g
	_stuck_t = 0.0
	_stuck_from = player.position
	_repaths = 0
	_mark(mark_at, true)
	return true


func cancel() -> void:
	path = PackedVector2Array()
	jumps = {}
	_i = 0
	goal = {}
	if marker:
		marker.queue_free()
		marker = null


func _mark(p: Vector2, ok: bool) -> void:
	if marker:
		marker.queue_free()
	marker = NavMarker.new(ok)
	marker.position = p
	world.floor_layer.add_child(marker)


func _in_reach(e: Dictionary) -> bool:
	return player.position.distance_to(e["pos"]) < float(e["r"]) - 4.0


func _use(e: Dictionary) -> void:
	_face_to(e["pos"])
	world.interact(e)


func _arrive_npc(id: String) -> void:
	var n: NPCActor = world.npcs.get(id)
	if n == null or not n.visible:
		return
	_face_to(n.position)
	world.interact({"kind": "npc", "id": id, "label": "Talk to " + n.display_name, "pos": n.position})


func _face_to(p: Vector2) -> void:
	var d := p - player.position
	if d.length() > 1.0:
		player.facing = ("e" if d.x > 0 else "w") if absf(d.x) > absf(d.y) else ("s" if d.y > 0 else "n")


## Called by the smith's body each physics frame while following a click: the direction to walk in.
func steer(delta: float) -> Vector2:
	if _i >= path.size():
		return Vector2.ZERO
	# a person moves: follow them, and stop to talk once close
	if goal.get("kind", "") == "npc":
		var n: NPCActor = world.npcs.get(goal["npc"])
		if n == null or not n.visible:
			cancel()
			return Vector2.ZERO
		if player.position.distance_to(n.position) < NPC_REACH:
			var id := str(goal["npc"])
			cancel()
			_arrive_npc(id)
			return Vector2.ZERO
		_npc_t += delta
		if _npc_t > 0.5 and n.position.distance_to(goal["at"]) > 64.0:
			_npc_t = 0.0
			var g := goal.duplicate()
			g["at"] = n.position
			var pl := plan(player.position, n.position, NPC_REACH - 12.0)
			if not pl.is_empty():
				path = pl["points"]
				jumps = pl["jumps"]
				_i = 1
				goal = g
	if goal.get("kind", "") == "entity" and _in_reach(goal["e"]):
		var e: Dictionary = goal["e"]
		cancel()
		_use(e)
		return Vector2.ZERO
	# take the stairs
	if jumps.has(_i - 1):
		player.position = path[_i]
		_i += 1
		Audio.play("sfx/door", -4.0)
		world.camera.reset_smoothing()
		_stuck_from = player.position
		return Vector2.ZERO
	var tgt := path[_i]
	var d := tgt - player.position
	if d.length() < (6.0 if _i == path.size() - 1 else 14.0):
		_i += 1
		if _i >= path.size():
			_finish_walk()
			return Vector2.ZERO
		tgt = path[_i]
		d = tgt - player.position
	# stuck against something (a person's cart, a door that shut): try a fresh path once, then give up
	_stuck_t += delta
	if _stuck_t > 0.6:
		if player.position.distance_to(_stuck_from) < 18.0:
			_repaths += 1
			var dest := path[path.size() - 1]
			if _repaths > 2:
				cancel()
				return Vector2.ZERO
			var pl2 := plan(player.position, dest, 0.0)
			if pl2.is_empty():
				cancel()
				return Vector2.ZERO
			path = pl2["points"]
			jumps = pl2["jumps"]
			_i = 1
		_stuck_t = 0.0
		_stuck_from = player.position
	return d.normalized() if d.length() > 0.5 else Vector2.ZERO


func _finish_walk() -> void:
	var g := goal
	cancel()
	if g.get("kind", "") == "entity":
		var e: Dictionary = g["e"]
		if player.position.distance_to(e["pos"]) < float(e["r"]) + 8.0:
			_use(e)
	elif g.get("kind", "") == "npc":
		_arrive_npc(str(g["npc"]))


# ======================================================================= quick travel
## Destinations the smith knows, guarded against spots that do not exist in this build.
## Each: {id, name, icon, spot, pos}
func destinations() -> Array:
	var out := []
	for d in DESTINATIONS:
		var pos := Vector2.INF
		for s in d[3]:
			if world.spots.has(s):
				pos = world.spots[s]
				break
		if pos == Vector2.INF:
			continue
		var vid := Venues.for_travel(str(d[0]))
		out.append({"id": d[0], "name": d[1], "icon": "ui/qt_" + str(d[2]), "pos": pos, "desc": d[4], "venue": vid,
			"short": str(SHORT.get(str(d[0]), d[1])),
			"status": Venues.status_text(vid) if vid != "" else "", "open": Venues.is_open(vid) if vid != "" else true})
	return out


## Short names under the quick-travel medallions (the full name shows in the centre when hovered).
const SHORT := {"provisions": "Provisions", "herbalist": "Herbalist", "pawn": "Pawnshop", "rival_smith": "Salt Anvil",
	"creatures": "Menagerie", "chapel": "Chapel", "barnaby": "Barnaby's", "inn": "Tipsy Wyvern", "smithy": "Your Forge"}


## id, name, icon, candidate spots (first that exists), line — each line says what the smith can really do there
## (opening hours and open/closed come from Venues and are shown beside it).
const DESTINATIONS := [
	["smithy", "Ironhand Forge", "smithy", ["smithy_inside", "smithy_counter_back", "smithy_door_out"], "Your forge, stores and shop counter."],
	["inn", "The Tipsy Wyvern", "inn", ["inn_inside", "inn_bar", "inn_door_out"], "Hilde's inn: meals, ale, gossip and adventurers."],
	["square", "Village Square", "square", ["well", "notice", "square_0"], "The well, the notice board and the Hall of Fame."],
	["provisions", "Pell's Provisions", "market", ["grocery_front", "grocery_door_out"], "Aldric's counter: ore, coal, hides, leather and thread."],
	["herbalist", "Fennimore's Simples", "herbalist", ["herbalist_inside", "herbalist_counter", "herbalist_door_out"], "Maud's counter: herbs, reagents and fibres."],
	["harbour", "The Harbour", "harbour", ["harbour_quay"], "Buy from a docked ship or order imports from the harbourmaster."],
	["barnaby", "Barnaby's House", "barnaby", ["barnaby_house_inside", "barnaby_house_door_out"], "Barnaby's parlour; the Ironfront den below in the evening."],
	["chapel", "Chapel & Graveyard", "chapel", ["graveyard", "house_oswin_door_out", "house_oswin_inside"], "Father Oswin and the quiet dead."],
	["pond", "The Pond", "pond", ["pond_1", "pond_2"], "Ducks, reeds, a bench."],
	["pawn", "The Three Brass Balls", "pawn", ["pawn_counter"], "The pawnbroker: pledge, sell, redeem or buy curios."],
	["rival_smith", "The Salt Anvil", "rival", ["rival_smith_counter", "rival_smith_forge"], "The rival smith: sea-bronze arms and a few materials."],
	["creatures", "The Hales' Menagerie", "creatures", ["hale_yard", "hale_study"], "Companion beasts for you or an adventurer."],
	["caravan", "Caravan Camp", "caravan", ["caravan_camp"], "The Brask caravan's wagons: rare wares, only while they are camped."],
]


## Walk cost (game minutes) and path to a destination from where the smith stands; {} if unreachable.
func route_to(pos: Vector2) -> Dictionary:
	var pl := plan(player.position, pos, 0.0)
	if pl.is_empty():
		return {}
	pl["minutes"] = QuickTravel.walk_minutes(float(pl["length"]))
	return pl


## Starts quick travel to a destination id (or a world position). Waits a couple of frames for the menu
## that asked to close; refuses while anything stops the clock.
func request_travel(dest_id: String) -> void:
	_pending_dest = dest_id
	_pending_frames = 3


func start_travel(dest_id: String) -> String:
	var why := QuickTravel.blocked_reason()
	if why != "":
		return why
	var pos := Vector2.INF
	var name := dest_id
	for d in destinations():
		if d["id"] == dest_id:
			pos = d["pos"]
			name = d["name"]
	if pos == Vector2.INF:
		return "You do not know the way there."
	cancel()
	var pl := route_to(pos)
	if pl.is_empty():
		return "There is no way there from here."
	if float(pl["length"]) < 48.0:
		return "You are already there."
	trip = QuickTravel.make(pl["points"], pl["jumps"], name)
	_last_now = Game.now()
	_mark(pos, true)
	Events.toast.emit("Walking to %s (about %s)…  Any key stops." % [name, _dur(trip.minutes)], "info")
	return ""


static func _dur(m: int) -> String:
	if m < 60:
		return "%d min" % m
	return "%dh %02dm" % [int(m / 60.0), m % 60]


func _process(_delta: float) -> void:
	if _pending_dest != "":
		_pending_frames -= 1
		if _pending_frames <= 0:
			var d := _pending_dest
			_pending_dest = ""
			var why := start_travel(d)
			if why != "":
				Events.toast.emit(why, "bad")


## Called by the smith's body each physics frame during quick travel.
func travel_step(delta: float) -> Vector2:
	if trip == null:
		return Vector2.ZERO
	# minutes the clock ran by itself since the last frame are part of the walk, not extra
	trip.note_natural(Game.now() - _last_now)
	var before := trip.idx
	player.position = trip.step(PlayerBody.WALK * QuickTravel.SPEED_MULT * delta)
	if trip.idx != before and trip.jumps.has(before - 1):
		world.camera.reset_smoothing()
		Audio.play("sfx/door", -4.0)
	_last_now = Game.now()
	if trip.done():
		_end_trip(false)
	return trip.last_dir if trip else Vector2.ZERO


func stop_travel() -> void:
	if trip != null:
		trip.cancel()
		_end_trip(true)


func _end_trip(cancelled: bool) -> void:
	var t := trip
	trip = null
	if marker:
		marker.queue_free()
		marker = null
	if cancelled:
		Events.toast.emit("You stop (%s on the road)." % _dur(t.applied), "info")
	else:
		Events.toast.emit("You reach %s." % t.dest, "good")
	travel_finished.emit(t.dest, t.applied, cancelled)


func _input(event: InputEvent) -> void:
	if trip == null:
		return
	if (event is InputEventKey and event.pressed and not event.is_echo()) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		stop_travel()


## A small inked target where the smith was sent (fades when he gets there or is cancelled).
class NavMarker extends Node2D:
	var ok := true
	var t := 0.0

	func _init(good: bool) -> void:
		ok = good
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		if not ok and t > 0.7:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var ink := Color("#20140c")
		var col := Color("#e8c060") if ok else Color("#a4341e")
		var s := 1.0 + 0.08 * sin(t * 6.0)
		var rad := 20.0 * s
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * rad, sin(a) * rad * 0.55))
		draw_polyline(pts, ink, 5.0, true)
		draw_polyline(pts, col, 2.5, true)
		var k := 9.0
		draw_line(Vector2(-k, -k * 0.55), Vector2(k, k * 0.55), ink, 4.0, true)
		draw_line(Vector2(-k, k * 0.55), Vector2(k, -k * 0.55), ink, 4.0, true)
		draw_line(Vector2(-k, -k * 0.55), Vector2(k, k * 0.55), col, 1.8, true)
		draw_line(Vector2(-k, k * 0.55), Vector2(k, -k * 0.55), col, 1.8, true)
