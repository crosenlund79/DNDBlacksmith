## Iteration 010 village: every building has a non-solid sign beside its door, the new venues' spots and
## interactables exist, the caravan comes and goes, animals never wander into walls or houses, horses and cows graze
## in their paddocks.
extends SuiteCase

const SMOKE := ["test_signs_and_venues"]

const SPOTS := ["pawn_counter", "rival_smith_counter", "rival_smith_forge", "hale_yard", "hale_study", "caravan_camp",
	"square_podium", "square_audience_1", "square_audience_2", "square_audience_3", "square_audience_4", "square_audience_5",
	"square_audience_6", "graveyard_1", "graveyard_2", "graveyard_3", "graveyard_4", "graveyard_5", "graveyard_6",
	"graveyard_7", "graveyard_8", "horse_paddock", "cow_pasture"]
const INTERACT := [["pawn", "pawn"], ["rival_smith", "rival_smith"], ["creatures", "hale"], ["hall_of_fame", "square"]]


func _world() -> VillageWorld:
	# the suite runs inside the runner's _ready, while the root is still busy: hang the world off the runner
	var root := (Engine.get_main_loop() as SceneTree).root
	var host: Node = root.get_child(root.get_child_count() - 1)
	var w := VillageWorld.new()
	host.add_child(w)
	return w


func _has_entry(w: VillageWorld, kind: String, id: String) -> bool:
	for e in w.interactables:
		if e["kind"] == kind and e["id"] == id:
			return true
	return false


func test_signs_and_venues() -> void:
	# data: every building names a sign whose prop exists, is drawn and is not solid
	for b in DB.layout["buildings"]:
		if not check(b.has("sign"), "%s has a sign" % b["id"]):
			continue
		var sid := str(b["sign"])
		check(DB.props.has(sid), "sign prop %s is defined" % sid)
		check(not bool(DB.props.get(sid, {}).get("solid", true)), "sign %s is not solid" % sid)
		check(Assets.has_tex("props/" + sid), "sign %s is drawn" % sid)
	var w := _world()
	var signs: Array = w.get_meta("v10_signs", [])
	eq(signs.size(), DB.layout["buildings"].size(), "a sign hangs at every building")
	for sg in signs:
		var b := DB.building(str(sg["building"]))
		var r := w.brect(b)
		var d: Dictionary = b["doors"][0]
		var dc: Vector2 = w._door_center(r, d)
		var node: Sprite2D = sg["node"]
		check(node.get_child_count() == 0 and not (node.get_parent() is PhysicsBody2D), "%s: the sign has no collision" % sg["building"])
		# keeps the doorway clear: the board (80 px wide) stays beside the door gap, never in front of it
		var half := float(d["w"]) * VillageWorld.T * 0.5
		var off: float = absf((sg["pos"] as Vector2).x - dc.x) if d["side"] in ["n", "s"] else absf((sg["pos"] as Vector2).y + 24.0 - dc.y)
		check(off >= half + 24.0, "%s: sign clear of the doorway (%.0f px from the door centre)" % [sg["building"], off])
	for name in SPOTS:
		check(w.spots.has(name), "spot %s exists" % name)
		check(w.spot_ids.has(name), "spot %s is on the navigation graph" % name)
	var start: int = w.spot_ids.get("square_0", -1)
	for name in ["pawn_counter", "rival_smith_forge", "hale_study", "hale_yard", "caravan_camp", "square_podium", "graveyard_5"]:
		if w.spot_ids.has(name):
			check(not w.astar.get_id_path(start, w.spot_ids[name]).is_empty(), "%s reachable from the square" % name)
	for k in INTERACT:
		check(_has_entry(w, k[0], k[1]), "interactable %s/%s" % k)
	for bid in ["pawnshop", "rival_forge", "hale_cottage"]:
		check(w.buildings.has(bid), "building %s stands" % bid)
		check(Assets.has_tex("roofs/" + bid), "building %s has a roof" % bid)
	# the caravan comes and goes
	Village10.set_caravan(w, true)
	check(_has_entry(w, "caravan", "caravan"), "the caravan's interactable appears when it is in the village")
	Village10.set_caravan(w, false)
	check(not _has_entry(w, "caravan", "caravan"), "and disappears when it has gone")
	# the venue keepers' schedules point at the new spots by day
	Game.state["minute"] = 11 * 60
	eq(w.spot_for("pawnbroker"), "pawn_counter", "the pawnbroker keeps his counter by day")
	eq(w.spot_for("rival_smith"), "rival_smith_forge", "the rival smith works his forge by day")
	eq(w.spot_for("hale_elder"), "hale_yard", "old Hale tends the yard")
	eq(w.spot_for("hale_younger"), "hale_study", "young Hale studies")
	note("%d signs, %d lamps, %d interactables" % [signs.size(), int(w.get_meta("v10_lamps", 0)), w.interactables.size()])
	w.free()


func test_animals_respect_walls() -> void:
	var w := _world()
	var nav := w.animal_nav()
	if not check(nav != null, "the animals' walkability grid is built"):
		w.free()
		return
	var houses: Array = []
	for bid in w.buildings:
		if not w.buildings[bid]["area"]:
			houses.append((w.buildings[bid]["rect"] as Rect2))
	var horses := 0
	var cows := 0
	for an in w.animals:
		var a := an as AnimalActor
		horses += int(a.kind == "horse")
		cows += int(a.kind == "cow")
	check(horses >= 2, "horses graze in the paddock (%d)" % horses)
	check(cows >= 3, "cows graze in the pasture (%d)" % cows)
	# target sampling never picks a point inside a house, around every house
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad_targets := 0
	for r in houses:
		var c := (r as Rect2).get_center()
		for i in 40:
			var from := nav.nearest_free(c + Vector2(0, (r as Rect2).size.y * 0.5 + 48.0))
			var t := nav.sample_target(from, from, 420.0, Rect2(), rng)
			for h in houses:
				if (h as Rect2).has_point(t):
					bad_targets += 1
	eq(bad_targets, 0, "wander targets are never inside a building")
	# simulated wandering: five minutes of game time for every animal
	var inside := []
	var blocked := []
	var strays := []
	var moved := 0
	for an in w.animals:
		var a := an as AnimalActor
		var p0 := a.position
		for i in 3000:
			a.step(0.1)
			for h in houses:
				if (h as Rect2).grow(-2).has_point(a.position) and inside.size() < 5:
					inside.append("%s@%s" % [a.kind, a.position])
			if a._placed and not nav.free_at(a.position) and blocked.size() < 5:
				blocked.append("%s@%s" % [a.kind, a.position])
			if a.bounds.size != Vector2.ZERO and not a.bounds.grow(1).has_point(a.position) and strays.size() < 5:
				strays.append("%s@%s" % [a.kind, a.position])
		moved += int(a.position.distance_to(p0) > 8.0)
	check(inside.is_empty(), "no animal ever stands inside a building %s" % [inside])
	check(blocked.is_empty(), "no animal ever stands on a wall, prop or tree footprint %s" % [blocked])
	check(strays.is_empty(), "horses and cows stay in their paddocks %s" % [strays])
	check(moved >= w.animals.size() / 2, "the animals do wander (%d of %d moved)" % [moved, w.animals.size()])
	note("%d animals (%d horses, %d cows), %d moved" % [w.animals.size(), horses, cows, moved])
	w.free()
