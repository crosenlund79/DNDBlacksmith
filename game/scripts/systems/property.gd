## Property — the smithy building is shared. The smith owns a few rooms at first and buys his neighbours'
## rooms as the business grows. Inside what he owns he can take down or put up internal walls, cut or
## close doorways, and buy, place, move and turn his workstations.
## EN: State lives in Game.state["property"]: owned units, the editable room/door plan of the building and the
##     installed stations (tile positions in building coordinates). Every change is validated so the player
##     can always reach every owned room, every station, the counter and a bed from the front door.
## DA: Ejendom — smeden ejer kun en del af bygningen og køber naboernes rum efterhånden. Indvendige vægge,
##     døre og arbejdsstationer kan flyttes; alt valideres, så intet bliver utilgængeligt.
class_name Property

const BID := "smithy"
const CELL := 0.5           # validation grid, in tiles
const DOOR_W := 2
const MIN_ROOM := 2

## Station prices by discipline (tier 1 → 3 stations cost more). Starter stations are already installed.
const PRICE := {
	"forge": 120, "anvil": 90, "crucible": 110, "quench_trough": 60, "bellows": 140, "grinding_wheel": 80,
	"rune_cutting_bench": 160, "rune_engraving_stand": 190, "rune_cleansing_basin": 150, "resonance_pedestal": 260, "rune_polishing_wheel": 170,
	"mortar_station": 70, "alembic": 140, "cauldron": 120, "reagent_table": 110, "infusion_rack": 150,
	"stitching_table": 90, "leather_vat": 110, "thread_spinner": 170, "embroidery_frame": 190, "fitting_mannequin": 160,
	"arcane_crucible": 520, "spellbinding_array": 560, "leyline_conductor": 480, "aetheric_stabilizer": 500, "arcane_anvil": 640,
}

## Each room's main workstation — where recipes are chosen; the world marks it permanently.
const MAIN_STATION := {"classic": "anvil", "runecraft": "rune_engraving_stand", "alchemy": "cauldron", "stitching": "stitching_table", "arcane": "arcane_crucible"}


# ------------------------------------------------------------------ state
static func data() -> Dictionary:
	return DB.building(BID)


static func st() -> Dictionary:
	ensure()
	return Game.state["property"]


## Old saves (before iteration 009) owned the whole building and every station: keep it that way.
static func ensure() -> void:
	if Game.state.is_empty() or Game.state.has("property"):
		return
	var all_units := []
	for u in data().get("units", []):
		all_units.append(u["id"])
	Game.state["property"] = _fresh(all_units, DB.stations.keys())
	Game.state["property"]["legacy"] = true


static func init_new() -> void:
	Game.state["property"] = _fresh(["start"], data().get("starter_stations", []))


static func _fresh(units: Array, stations: Array) -> Dictionary:
	var unit_of := {}
	for u in data().get("units", []):
		for rid in u["rooms"]:
			unit_of[rid] = u["id"]
	var rooms := []
	for r in data().get("rooms", []):
		var rr: Dictionary = (r as Dictionary).duplicate(true)
		rr["unit"] = unit_of.get(r["id"], "start")
		rooms.append(rr)
	var doors := []
	for d in data().get("room_doors", []):
		doors.append((d as Dictionary).duplicate(true))
	var placed := {}
	var sp: Dictionary = data().get("station_pos", {})
	for sid in stations:
		var p: Array = sp.get(sid, DB.station(sid).get("pos", [0, 0]))
		placed[sid] = {"pos": [float(p[0]), float(p[1])], "flip": false}
	return {"units": units.duplicate(), "rooms": rooms, "doors": doors, "stations": placed, "stored": [], "next_room": 1}


# ------------------------------------------------------------------ units (purchasable sections)
static func units() -> Array:
	return data().get("units", [])


static func unit(uid: String) -> Dictionary:
	for u in units():
		if u["id"] == uid:
			return u
	return {}


static func owns(uid: String) -> bool:
	return (st()["units"] as Array).has(uid)


static func room_owned(r: Dictionary) -> bool:
	return owns(str(r.get("unit", "start")))


## "owned", "available" (adjacent to what he owns) or "unavailable".
static func unit_state(uid: String) -> String:
	if owns(uid):
		return "owned"
	return "available" if adjacent(uid) else "unavailable"


static func adjacent(uid: String) -> bool:
	var mine := []
	var theirs := []
	for r in rooms():
		if room_owned(r):
			mine.append(rect(r))
		elif str(r.get("unit", "")) == uid:
			theirs.append(rect(r))
	for a in mine:
		for b in theirs:
			if shared_edge(a, b).size() > 0:
				return true
	return false


static func unit_price(uid: String) -> int:
	return int(unit(uid).get("price", 0))


static func buy_unit(uid: String) -> String:
	var u := unit(uid)
	if u.is_empty():
		return "No such property."
	if owns(uid):
		return "You already own it."
	if not adjacent(uid):
		return "You can only buy rooms next to what you already own."
	var price := unit_price(uid)
	if not Game.can_afford(price):
		return "You need %d gold." % price
	Game.add_gold(-price, "property", "Bought " + str(u["name"]))
	(st()["units"] as Array).append(uid)
	if uid == "cellar" and not Game.has_upgrade("arcane_foundry"):
		# the vault's thick stone walls are what an arcane foundry needs
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Chronicle.add("property", "Brannoc bought %s from %s — it will become %s." % [u["name"], u.get("occupant", "its owner"), u.get("becomes", "part of the workshop")], {"unit": uid}, true)
	Game.journal("Bought %s for %d gold." % [u["name"], price])
	Events.toast.emit("%s is yours. Rearrange it under Property & Workshop." % u["name"], "good")
	Tutorial.complete("progress")
	return ""


## A rough stage of the workshop's growth, for flavour and objectives.
static func stage() -> String:
	var n := (st()["units"] as Array).size()
	var arcane := owns("cellar")
	if arcane and n >= 6:
		return "Master's workshop"
	if n >= 4:
		return "Established workshop"
	if n >= 2:
		return "Growing smithy"
	return "Village smithy"


# ------------------------------------------------------------------ rooms & doors (the plan)
static func rooms() -> Array:
	return st()["rooms"]


static func doors() -> Array:
	return st()["doors"]


static func rect(r: Dictionary) -> Rect2:
	var a: Array = r["rect"]
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func room_by_id(rooms_arr: Array, rid: String) -> Dictionary:
	for r in rooms_arr:
		if r["id"] == rid:
			return r
	return {}


static func room_at_tile(rooms_arr: Array, p: Vector2) -> Dictionary:
	for r in rooms_arr:
		if rect(r).has_point(p):
			return r
	return {}


## Shared edge of two room rects: [vertical:bool, line, lo, hi] or [] if they do not touch for >= 1 tile.
static func shared_edge(a: Rect2, b: Rect2) -> Array:
	if is_equal_approx(a.end.x, b.position.x) or is_equal_approx(b.end.x, a.position.x):
		var line := a.end.x if is_equal_approx(a.end.x, b.position.x) else a.position.x
		var lo := maxf(a.position.y, b.position.y)
		var hi := minf(a.end.y, b.end.y)
		if hi - lo >= 1.0:
			return [true, line, lo, hi]
	if is_equal_approx(a.end.y, b.position.y) or is_equal_approx(b.end.y, a.position.y):
		var line2 := a.end.y if is_equal_approx(a.end.y, b.position.y) else a.position.y
		var lo2 := maxf(a.position.x, b.position.x)
		var hi2 := minf(a.end.x, b.end.x)
		if hi2 - lo2 >= 1.0:
			return [false, line2, lo2, hi2]
	return []


## Is the door open (both rooms owned)? Doors to a neighbour's room stay locked.
static func door_open(plan: Dictionary, d: Dictionary) -> bool:
	var pair: Array = d["between"]
	var a := room_by_id(plan["rooms"], str(pair[0]))
	var b := room_by_id(plan["rooms"], str(pair[1]))
	return not a.is_empty() and not b.is_empty() and room_owned(a) and room_owned(b)


# ------------------------------------------------------------------ the editable plan
## A deep copy of rooms, doors and stations that the editor changes; commit() validates and saves it.
static func plan_copy() -> Dictionary:
	return {"rooms": rooms().duplicate(true), "doors": doors().duplicate(true), "stations": (st()["stations"] as Dictionary).duplicate(true),
		"stored": (st()["stored"] as Array).duplicate(), "next_room": int(st().get("next_room", 1))}


static func commit(plan: Dictionary) -> String:
	var err := validate(plan)
	if err != "":
		return err
	var s := st()
	s["rooms"] = plan["rooms"]
	s["doors"] = plan["doors"]
	s["stations"] = plan["stations"]
	s["stored"] = plan["stored"]
	s["next_room"] = plan["next_room"]
	Events.crafting_changed.emit()
	return ""


static func editable(r: Dictionary) -> bool:
	return room_owned(r) and not (data().get("locked_rooms", []) as Array).has(r["id"])


## Take down the wall between two owned rooms. Only when the result is still a rectangle.
static func merge(plan: Dictionary, a_id: String, b_id: String) -> String:
	var a := room_by_id(plan["rooms"], a_id)
	var b := room_by_id(plan["rooms"], b_id)
	if a.is_empty() or b.is_empty():
		return "Pick a wall between two rooms."
	if not editable(a) or not editable(b):
		return "You can only change walls inside rooms you own (the shopfront keeps its walls)."
	var ra := rect(a)
	var rb := rect(b)
	var e := shared_edge(ra, rb)
	if e.is_empty():
		return "Those rooms do not share a wall."
	var u := ra.merge(rb)
	if not is_equal_approx(u.get_area(), ra.get_area() + rb.get_area()):
		return "Only walls along a whole side can come down (the rooms must form a rectangle)."
	var keep := a if ra.get_area() >= rb.get_area() else b
	var gone := b if keep == a else a
	keep["rect"] = [int(u.position.x), int(u.position.y), int(u.size.x), int(u.size.y)]
	(plan["rooms"] as Array).erase(gone)
	for d in (plan["doors"] as Array).duplicate():
		var pair: Array = d["between"]
		if pair.has(keep["id"]) and pair.has(gone["id"]):
			(plan["doors"] as Array).erase(d)
		elif pair.has(gone["id"]):
			d["between"] = _swap(pair, gone["id"], keep["id"])
	return ""


static func _swap(pair: Array, from: String, to: String) -> Array:
	var out := []
	for x in pair:
		out.append(to if x == from else x)
	return out


## Put up a new partition across an owned room along a tile line; a doorway is cut in the middle of it.
static func split(plan: Dictionary, rid: String, vertical: bool, at: int) -> String:
	var r := room_by_id(plan["rooms"], rid)
	if r.is_empty() or not editable(r):
		return "You can only divide rooms you own (the shopfront stays as it is)."
	var rr := rect(r)
	var lo := int(rr.position.x if vertical else rr.position.y)
	var hi := int(rr.end.x if vertical else rr.end.y)
	if at - lo < MIN_ROOM or hi - at < MIN_ROOM:
		return "Each part must be at least %d tiles wide." % MIN_ROOM
	# a doorway must not straddle the new wall
	for d in plan["doors"]:
		if not (d["between"] as Array).has(rid):
			continue
		var e := _door_edge(plan, d)
		if e.is_empty():
			continue
		if bool(e[0]) != vertical and float(d["at"]) < float(at) and float(d["at"]) + float(d["w"]) > float(at):
			return "A doorway is in the way of that wall."
	var a_rect := Rect2(rr.position, Vector2(at - rr.position.x, rr.size.y)) if vertical else Rect2(rr.position, Vector2(rr.size.x, at - rr.position.y))
	var b_rect := Rect2(Vector2(at, rr.position.y), Vector2(rr.end.x - at, rr.size.y)) if vertical else Rect2(Vector2(rr.position.x, at), Vector2(rr.size.x, rr.end.y - at))
	# stations must not stand on the new wall
	for sid in plan["stations"]:
		var fp := footprint(sid, plan["stations"][sid])
		if rr.intersects(fp) and not (a_rect.encloses(fp) or b_rect.encloses(fp)):
			return "Move the %s first — it stands where the wall would go." % DB.station(sid).get("name", sid)
	var nid := "room_%d" % int(plan["next_room"])
	plan["next_room"] = int(plan["next_room"]) + 1
	var nr: Dictionary = r.duplicate(true)
	nr["id"] = nid
	nr["name"] = "Workroom %d" % (int(plan["next_room"]) - 1)
	r["rect"] = [int(a_rect.position.x), int(a_rect.position.y), int(a_rect.size.x), int(a_rect.size.y)]
	nr["rect"] = [int(b_rect.position.x), int(b_rect.position.y), int(b_rect.size.x), int(b_rect.size.y)]
	(plan["rooms"] as Array).append(nr)
	# doors on the far part's edges now belong to the new room
	for d in plan["doors"]:
		var pair: Array = d["between"]
		if not pair.has(rid):
			continue
		var other := room_by_id(plan["rooms"], str(pair[1] if pair[0] == rid else pair[0]))
		if other.is_empty():
			continue
		var e2 := shared_edge(b_rect, rect(other))
		if not e2.is_empty() and float(d["at"]) >= float(e2[2]) - 0.01 and float(d["at"]) + float(d["w"]) <= float(e2[3]) + 0.01:
			d["between"] = _swap(pair, rid, nid)
	# a doorway in the middle of the new wall
	var span_lo := rr.position.y if vertical else rr.position.x
	var span := rr.size.y if vertical else rr.size.x
	var dat := int(span_lo + floor((span - DOOR_W) * 0.5))
	(plan["doors"] as Array).append({"between": [rid, nid], "at": dat, "w": DOOR_W})
	return ""


## The edge a door sits on: [vertical, line, lo, hi] or [].
static func _door_edge(plan: Dictionary, d: Dictionary) -> Array:
	var pair: Array = d["between"]
	var a := room_by_id(plan["rooms"], str(pair[0]))
	var b := room_by_id(plan["rooms"], str(pair[1]))
	if a.is_empty() or b.is_empty():
		return []
	return shared_edge(rect(a), rect(b))


## Cut a doorway (2 tiles) in the wall between two owned rooms, starting at tile `at` along the wall.
static func add_door(plan: Dictionary, a_id: String, b_id: String, at: int) -> String:
	var a := room_by_id(plan["rooms"], a_id)
	var b := room_by_id(plan["rooms"], b_id)
	if a.is_empty() or b.is_empty() or not room_owned(a) or not room_owned(b):
		return "Doorways can only join two rooms you own."
	var e := shared_edge(rect(a), rect(b))
	if e.is_empty():
		return "Those rooms do not share a wall."
	at = clampi(at, int(e[2]), int(e[3]) - DOOR_W)
	if float(at) < float(e[2]) or float(at + DOOR_W) > float(e[3]):
		return "The wall is too short for a doorway."
	for d in plan["doors"]:
		var pair: Array = d["between"]
		if pair.has(a_id) and pair.has(b_id) and float(d["at"]) < float(at + DOOR_W) and float(d["at"]) + float(d["w"]) > float(at):
			return "There is already a doorway there."
	(plan["doors"] as Array).append({"between": [a_id, b_id], "at": at, "w": DOOR_W})
	return ""


static func remove_door(plan: Dictionary, d: Dictionary) -> String:
	if not door_open(plan, d):
		return "That door belongs to your neighbour."
	(plan["doors"] as Array).erase(d)
	return ""


# ------------------------------------------------------------------ stations
static func is_installed(station_id: String) -> bool:
	if Game.state.is_empty():
		return true
	var s: Dictionary = st()["stations"]
	if not s.has(station_id):
		return false
	var r := room_at_tile(rooms(), pos_of(station_id))
	return not r.is_empty() and room_owned(r)


static func is_owned_station(station_id: String) -> bool:
	return is_installed(station_id) or (st()["stored"] as Array).has(station_id)


static func station_reason(station_id: String) -> String:
	if Game.state.is_empty() or is_installed(station_id):
		return ""
	if (st()["stored"] as Array).has(station_id):
		return "Bought, but not set up yet — place it under Property & Workshop › Workshop layout"
	return "Not in your workshop — buy it under Property & Workshop › Equipment"


static func pos_of(station_id: String) -> Vector2:
	var e: Dictionary = st()["stations"].get(station_id, {})
	var p: Array = e.get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func flipped(station_id: String) -> bool:
	return bool(st()["stations"].get(station_id, {}).get("flip", false))


static func station_price(station_id: String) -> int:
	return int(PRICE.get(station_id, 150))


## Collision footprint in tiles (mirrors world.gd: 0.76 × 0.56 of the sprite, centred slightly low).
static func footprint(station_id: String, entry: Dictionary) -> Rect2:
	var p: Array = entry.get("pos", [0, 0])
	var size: Array = DB.station(station_id).get("size", [96, 96])
	var sz := Vector2(float(size[0]), float(size[1])) / 64.0
	var c := Vector2(float(p[0]), float(p[1]))
	return Rect2(c - sz * Vector2(0.38, 0.28), sz * Vector2(0.76, 0.56))


static func buy_station(station_id: String) -> String:
	if is_owned_station(station_id):
		return "You already have one."
	var why := SkillTree.station_reason(station_id)
	if why != "":
		return why
	var price := station_price(station_id)
	if not Game.can_afford(price):
		return "You need %d gold." % price
	Game.add_gold(-price, "equipment", "Bought " + str(DB.station(station_id).get("name", station_id)))
	(st()["stored"] as Array).append(station_id)
	Chronicle.add("property", "Brannoc bought a %s for the workshop." % DB.station(station_id).get("name", station_id), {"station": station_id})
	Events.toast.emit("%s delivered — place it in the workshop." % DB.station(station_id).get("name", station_id), "good")
	Tutorial.complete("progress")
	return ""


## Place (or move) a station in the plan at tile position `pos`; validates the spot itself.
static func place(plan: Dictionary, station_id: String, pos: Vector2, flip := false) -> String:
	var entry := {"pos": [snappedf(pos.x, 0.25), snappedf(pos.y, 0.25)], "flip": flip}
	var why := spot_problem(plan, station_id, entry)
	if why != "":
		return why
	plan["stations"][station_id] = entry
	(plan["stored"] as Array).erase(station_id)
	return ""


static func store(plan: Dictionary, station_id: String) -> void:
	if (plan["stations"] as Dictionary).erase(station_id) and not (plan["stored"] as Array).has(station_id):
		(plan["stored"] as Array).append(station_id)


## Why a station cannot stand there ("" = fine): inside one owned room, clear of walls, doorways and other stations.
static func spot_problem(plan: Dictionary, station_id: String, entry: Dictionary) -> String:
	var fp := footprint(station_id, entry)
	var host := {}
	for r in plan["rooms"]:
		if rect(r).grow(-0.2).encloses(fp):
			host = r
	if host.is_empty():
		return "It must stand wholly inside one room, clear of the walls."
	if not room_owned(host):
		return "That room is not yours."
	for d in plan["doors"]:
		var c := door_center(plan, d)
		if c != Vector2.INF and fp.grow(0.9).has_point(c):
			return "It would block a doorway."
	for other in plan["stations"]:
		if other == station_id:
			continue
		if fp.grow(0.35).intersects(footprint(other, plan["stations"][other])):
			return "Too close to the %s." % DB.station(other).get("name", other)
	var ent: Array = data().get("entrance", [14.0, 0.6])
	if fp.grow(1.0).has_point(Vector2(float(ent[0]), float(ent[1]))):
		return "Keep the front door clear."
	return ""


static func door_center(plan: Dictionary, d: Dictionary) -> Vector2:
	var e := _door_edge(plan, d)
	if e.is_empty():
		return Vector2.INF
	var mid := float(d["at"]) + float(d["w"]) * 0.5
	return Vector2(float(e[1]), mid) if bool(e[0]) else Vector2(mid, float(e[1]))


# ------------------------------------------------------------------ validation (reachability)
## "" when everything owned is reachable from the front door: every room, every installed station, the shop
## counter and a bed. Uses a half-tile walk grid with walls, doorways and station footprints.
static func validate(plan: Dictionary) -> String:
	var b_rect: Array = data().get("rect", [0, 0, 30, 23])
	var w := int(float(b_rect[2]) / CELL)
	var h := int(float(b_rect[3]) / CELL)
	var room_idx := PackedInt32Array()
	room_idx.resize(w * h)
	var rooms_arr: Array = plan["rooms"]
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	var fps := []
	for sid in plan["stations"]:
		fps.append(footprint(sid, plan["stations"][sid]))
	for j in h:
		for i in w:
			var c := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
			var k := j * w + i
			room_idx[k] = -1
			for ri in rooms_arr.size():
				if rect(rooms_arr[ri]).has_point(c):
					room_idx[k] = ri if room_owned(rooms_arr[ri]) else -2
					break
			for fp in fps:
				if (fp as Rect2).has_point(c):
					blocked[k] = 1
	# open doors as allowed crossings
	var crossings := {}
	for d in plan["doors"]:
		if not door_open(plan, d):
			continue
		var e := _door_edge(plan, d)
		if e.is_empty():
			continue
		crossings[str(d["between"][0]) + "|" + str(d["between"][1])] = crossings.get(str(d["between"][0]) + "|" + str(d["between"][1]), []) + [[e, float(d["at"]), float(d["at"]) + float(d["w"])]]
	var ent: Array = data().get("entrance", [14.0, 0.6])
	var si := int(float(ent[0]) / CELL)
	var sj := int(float(ent[1]) / CELL)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := [Vector2i(si, sj)]
	seen[sj * w + si] = 1
	var reached_rooms := {}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		var ck := cur.y * w + cur.x
		reached_rooms[room_idx[ck]] = true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + dv
			if nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h:
				continue
			var nk := nx.y * w + nx.x
			if seen[nk] == 1 or blocked[nk] == 1 or room_idx[nk] < 0:
				continue
			if room_idx[nk] != room_idx[ck]:
				# crossing a wall: only through an open doorway
				var ra: Dictionary = rooms_arr[room_idx[ck]]
				var rb: Dictionary = rooms_arr[room_idx[nk]]
				var along := (float(cur.y) + 0.5) * CELL if dv.y == 0 else (float(cur.x) + 0.5) * CELL
				var ok := false
				for key in [str(ra["id"]) + "|" + str(rb["id"]), str(rb["id"]) + "|" + str(ra["id"])]:
					for cr in crossings.get(key, []):
						if along > float(cr[1]) and along < float(cr[2]):
							ok = true
				if not ok:
					continue
			seen[nk] = 1
			queue.append(nx)
	# every owned room reached
	for ri in rooms_arr.size():
		if room_owned(rooms_arr[ri]) and not reached_rooms.has(ri):
			return "%s cannot be reached from the front door." % rooms_arr[ri]["name"]
	# every station can be walked up to
	for sid in plan["stations"]:
		var e2: Dictionary = plan["stations"][sid]
		var p: Array = e2["pos"]
		var size: Array = DB.station(sid).get("size", [96, 96])
		var reach := (maxf(float(size[0]), float(size[1])) * 0.5 + 34.0) / 64.0
		if not _reachable_near(Vector2(float(p[0]), float(p[1])), reach, seen, w, h):
			return "You could not get to the %s." % DB.station(sid).get("name", sid)
	for need in [["counter", data().get("interact", [])]]:
		for it in need[1]:
			if it["kind"] == "counter":
				var ip: Array = it["pos"]
				if not _reachable_near(Vector2(float(ip[0]), float(ip[1])), 2.2, seen, w, h):
					return "The shop counter would be cut off."
	var bed_ok := false
	for it2 in data().get("interact", []):
		if it2["kind"] == "bed":
			var bp: Array = it2["pos"]
			var host := room_at_tile(rooms_arr, Vector2(float(bp[0]), float(bp[1])))
			if not host.is_empty() and room_owned(host) and _reachable_near(Vector2(float(bp[0]), float(bp[1])), 1.9, seen, w, h):
				bed_ok = true
	if not bed_ok:
		return "You could no longer reach a bed."
	return ""


static func _reachable_near(c: Vector2, radius: float, seen: PackedByteArray, w: int, h: int) -> bool:
	var i0 := maxi(0, int((c.x - radius) / CELL))
	var i1 := mini(w - 1, int((c.x + radius) / CELL))
	var j0 := maxi(0, int((c.y - radius) / CELL))
	var j1 := mini(h - 1, int((c.y + radius) / CELL))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if seen[j * w + i] == 1 and Vector2((i + 0.5) * CELL, (j + 0.5) * CELL).distance_to(c) <= radius:
				return true
	return false


# ------------------------------------------------------------------ helpers for the world
## The discipline whose stations dominate a room ("" if none) — decides decoration.
static func room_discipline(r: Dictionary) -> String:
	var count := {}
	for sid in st()["stations"]:
		if rect(r).has_point(pos_of(sid)):
			var d := str(DB.station(sid).get("discipline", ""))
			count[d] = int(count.get(d, 0)) + 1
	var best := ""
	var n := 0
	for d in count:
		if int(count[d]) > n:
			n = int(count[d])
			best = d
	return best


static func stations_in(r: Dictionary) -> Array:
	var out := []
	for sid in st()["stations"]:
		if rect(r).has_point(pos_of(sid)):
			out.append(sid)
	return out


## Stations marked as each room's main recipe-selection station (one per room, by its discipline).
static func main_stations() -> Array:
	var out := []
	for r in rooms():
		if not room_owned(r):
			continue
		var here := stations_in(r)
		var disc := room_discipline(r)
		var pick := ""
		if here.has(MAIN_STATION.get(disc, "")):
			pick = MAIN_STATION[disc]
		elif not here.is_empty():
			pick = here[0]
		if pick != "":
			out.append(pick)
	return out


# ------------------------------------------------------------------ dev helpers
static func dev_grant_all() -> void:
	var s := st()
	for u in units():
		if not (s["units"] as Array).has(u["id"]):
			(s["units"] as Array).append(u["id"])
	var sp: Dictionary = data().get("station_pos", {})
	for sid in DB.stations:
		if not (s["stations"] as Dictionary).has(sid):
			var p: Array = sp.get(sid, DB.station(sid).get("pos", [0, 0]))
			s["stations"][sid] = {"pos": [float(p[0]), float(p[1])], "flip": false}
		(s["stored"] as Array).erase(sid)


## Installs every station whose original spot lies in a room the smith owns (dev / test presets).
static func dev_install_in_owned() -> void:
	var s := st()
	var sp: Dictionary = data().get("station_pos", {})
	for sid in DB.stations:
		var p: Array = sp.get(sid, DB.station(sid).get("pos", [0, 0]))
		var host := room_at_tile(rooms(), Vector2(float(p[0]), float(p[1])))
		if not host.is_empty() and room_owned(host) and not (s["stations"] as Dictionary).has(sid):
			s["stations"][sid] = {"pos": [float(p[0]), float(p[1])], "flip": false}
			(s["stored"] as Array).erase(sid)


static func dev_grant_unit(uid: String) -> void:
	if not owns(uid):
		(st()["units"] as Array).append(uid)


static func dev_reset_new() -> void:
	init_new()
