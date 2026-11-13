## Canonical v1.7 §4.1 (#64–67) — the compact smithy: a 19 × 18 ground floor (the smithing hall, shopfront, stock hall
## and the neighbours' three workshop rooms), the household in the Loft (small quarters from the start, the household
## wing as an upgrade), the material store and the arcane foundry in a basement dug in two steps (absent at the start);
## save step 8 (Property.migrate_layout_v17) carrying older plans over without losing a room's stations, an upgrade or
## the smith; the millpond, millstream and watermill on the freed ground; the smithy's map marker at its real door.
extends SuiteCase

const SMOKE := ["test_new_layout", "test_migration_keeps_everything"]


func test_new_layout() -> void:
	fresh_game()
	var r: Array = DB.building("smithy")["rect"]
	eq([int(r[2]), int(r[3])], [19, 18], "the ground floor is 19 × 18")
	check(19 * 18 <= 0.52 * 30 * 23 and 19 * 18 >= 0.45 * 30 * 23, "about half the old 30 × 23 (%d of 690 tiles)" % (19 * 18))
	for rid in ["forge_room", "shop", "stock_hall"]:
		eq(Property.floor_of_room(Property.room_by_id(Property.rooms(), rid)), "ground", "%s stays on the ground floor" % rid)
	for rid in ["study", "living", "bedroom", "storage", "pantry"]:
		eq(Property.floor_of_room(Property.room_by_id(Property.rooms(), rid)), "loft", "%s is in the Loft" % rid)
	for rid in ["material_store", "arcane_room", "cellar_stair"]:
		eq(Property.floor_of_room(Property.room_by_id(Property.rooms(), rid)), "basement", "%s is in the basement" % rid)
	check(Property.room_owned(Property.room_by_id(Property.rooms(), "study")) and Property.floor_owned("loft"),
		"a small living area under the roof is his from the start (the stair landing and his quarters)")
	check(not Property.room_owned(Property.room_by_id(Property.rooms(), "living")), "the household wing is a later upgrade")
	check(not Property.floor_owned("basement"), "no basement at the start")
	eq(Property.validate(Property.plan_copy()), "", "the starting layout is valid (a bed upstairs is reachable)")
	# dig the basement, step by step
	Game.state["gold"] = 5000
	check(Property.buy_unit("cellar") != "", "the vault cannot be dug before the cellar")
	eq(Property.buy_unit("chandler"), "", "dig the cellar (a stair down from the stock hall and a store)")
	check(Property.floor_owned("basement"), "now there is a basement")
	eq(Property.buy_unit("cellar"), "", "then dig on to the vault")
	check(Game.has_upgrade("arcane_foundry"), "the vault is the arcane foundry")
	Property.dev_install_in_owned()
	for sid in ["loom", "arcane_crucible", "arcane_anvil"]:
		eq(Property.station_floor(sid), "basement", "%s stands in the basement" % sid)
	eq(Property.validate(Property.plan_copy()), "", "the three-floor workshop is valid")
	eq(Property.buy_unit("apartment"), "", "the household wing (living room, bedroom, storage, pantry)")
	eq(Property.validate(Property.plan_copy()), "", "and still valid")
	check(save_load("t_compact_rt"), "save and load")
	check(Property.floor_owned("basement") and Property.station_floor("arcane_anvil") == "basement", "kept through save and load")


## An older (schema-7) plan: the old ground-floor rooms with the foundry's stations at their old places, a room the
## player divided off the old pantry (with a station in it), the foundry bought without the chandler's store, and
## the smith standing in what is now the millpond.
func _old_plan() -> Dictionary:
	fresh_game()
	var s: Dictionary = Game.state["property"]
	var old_rects := {"study": [19, 7, 5, 6], "living": [19, 0, 11, 7], "bedroom": [24, 7, 6, 9], "storage": [19, 13, 5, 10],
		"pantry": [24, 16, 6, 3], "material_store": [12, 18, 7, 5], "arcane_room": [0, 18, 12, 5]}
	for rm in s["rooms"]:
		if old_rects.has(str(rm["id"])):
			rm["rect"] = old_rects[str(rm["id"])]
	s["rooms"] = (s["rooms"] as Array).filter(func(rm): return str(rm["id"]) != "cellar_stair")
	s["rooms"].append({"id": "r_9", "name": "Divided-off nook", "rect": [24, 19, 6, 4], "floor": "floor_wood", "unit": "apartment", "kind": "home"})
	s["units"] = ["start", "cobbler", "cellar", "apartment"]
	s["stations"]["arcane_crucible"] = {"pos": [1.6, 20.6], "flip": false}
	s["stations"]["arcane_anvil"] = {"pos": [10.3, 21.6], "flip": false}
	s["stations"]["mortar_station"] = {"pos": [27.0, 21.0], "flip": false}
	s.erase("layout_v")
	Game.state["player"]["pos"] = [(18 + 26.0) * 64.0, (34 + 10.0) * 64.0]   # the old bedroom: now the millpond's shore
	Game.state["player"]["area"] = "smithy"
	Game.state["version"] = 7
	return Game.state


func test_migration_keeps_everything() -> void:
	var data := _old_plan()
	var held := Game.inventory().size()
	var rep := Property.migrate_layout_v17(data)
	note("migration: " + rep)
	var arc := Property.room_by_id(Property.rooms(), "arcane_room")
	eq(Property.floor_of_room(arc), "basement", "the foundry is in the basement")
	eq(Property.pos_of("arcane_crucible"), Vector2(113.6, 42.6), "its crucible keeps its place in the room (1.6, 2.6 from the corner)")
	eq(Property.pos_of("arcane_anvil"), Vector2(122.3, 43.6), "and its anvil")
	check(Property.owns("chandler"), "owning the foundry brings the cellar dig that leads to it")
	check(Property.room_by_id(Property.rooms(), "r_9").is_empty(), "the nook divided off in the removed wing is gone")
	check((Property.st()["stored"] as Array).has("mortar_station") and not Property.is_installed("mortar_station"), "its station is in storage, not lost")
	eq(Property.floor_of_room(Property.room_by_id(Property.rooms(), "bedroom")), "loft", "the bedroom is upstairs")
	check(Property.owns("apartment") and Property.room_owned(Property.room_by_id(Property.rooms(), "bedroom")), "the household wing is still his")
	eq(Property.validate(Property.plan_copy()), "", "the migrated plan is valid")
	var pp: Array = Game.state["player"]["pos"]
	var pt := Vector2(float(pp[0]), float(pp[1])) / 64.0
	check(Rect2(18, 34, 19, 18).has_point(pt), "the smith is set down inside the front door, not in the pond (%s)" % str(pt))
	eq(Game.inventory().size(), held, "nothing in the stores changed")
	var once := JSON.stringify(Game.state["property"])
	Property.migrate_layout_v17(data)
	eq(JSON.stringify(Game.state["property"]), once, "running it again changes nothing")


func test_golden_saves_keep_their_stations() -> void:
	for g in ["build-0.13.5", "build-0.14.6"]:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % g))
		if not check(raw is Dictionary, "%s is present" % g):
			continue
		var before: Dictionary = (raw as Dictionary)["data"].get("property", {})
		var n_before := (before.get("stations", {}) as Dictionary).size() + (before.get("stored", []) as Array).size()
		var f := FileAccess.open(Saves.path("t_compact_old"), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % g))
		f.close()
		if not check(Saves.load_slot("t_compact_old"), "%s loads" % g):
			continue
		var n_after := (Property.st()["stations"] as Dictionary).size() + (Property.st()["stored"] as Array).size()
		check(n_after >= n_before, "%s: every station kept (%d → %d)" % [g, n_before, n_after])
		eq(Property.validate(Property.plan_copy()), "", "%s: the migrated plan is valid" % g)
		Saves.delete("t_compact_old")


func _world() -> VillageWorld:
	var root := (Engine.get_main_loop() as SceneTree).root
	var host: Node = root.get_child(root.get_child_count() - 1)
	var w := VillageWorld.new()
	host.add_child(w)
	return w


func test_village_and_floors_in_the_world() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	Property.buy_unit("chandler")
	var w := _world()
	check(w.find_child("Watermill", true, false) != null and w.mill_wheel != null, "the watermill and its wheel stand by the millstream")
	check(w.find_child("MillSound", true, false) is AudioStreamPlayer2D, "the mill has its own sound by the water")
	var up := w.interactables.filter(func(e): return str(e["kind"]) == "stairs" and str(e["id"]) == "smithy_loft")
	var down := w.interactables.filter(func(e): return str(e["kind"]) == "stairs" and str(e["id"]) == "smithy_basement")
	check(not up.is_empty() and not down.is_empty(), "a stair up to the Loft and one down to the cellar in the stock hall")
	check(not down.is_empty() and str(down[0]["label"]).contains("down"), "the cellar stair says down (%s)" % (str(down[0]["label"]) if not down.is_empty() else ""))
	var beds := w.interactables.filter(func(e): return str(e["kind"]) == "bed")
	check(beds.any(func(e): return str(e["id"]) == "cot"), "his cot is upstairs and usable")
	check(not beds.any(func(e): return str(e["id"]) == "player_bed"), "the household wing's bed only once it is his")
	var mp: Vector2 = VillageMapView.venue_world_pos(w, "forge")
	check(mp.distance_to(w.spots["smithy_door_out"]) < 1.0, "the forge's map marker is at its door")
	var c := w.tp(DB.layout["millpond"]["center"])
	check(not Rect2(w.brect(DB.building("smithy"))).has_point(c), "the millpond lies outside the smithy's walls")
	w.queue_free()
