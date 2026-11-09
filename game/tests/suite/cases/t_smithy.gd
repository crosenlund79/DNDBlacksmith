## The Living Realm, milestone 2a — the evolving smithy (`Smithy`, `Property` floors and lift, world dressing):
## discipline areas (every workshop room has a craft, a banner and its name; auto-placement keeps a craft together),
## room tiers follow real progress (a new game is modest; skill, stations and renown raise them) and the dressing
## never blocks a station, a doorway or the walk grid; the Loft is bought only after Ilse's room and the West
## Garret only next to it; stations craft upstairs; the aetheric lift (needs the Loft and an Arcane Foundry) and the
## stair move the smith between floors in one step; an apprentice works upstairs (station reachable, task done);
## "Walk to the <station>" and "Craft again"; save/load and old saves (before the Loft, before property); every
## station reachable in the fully bought building; the capacity report per craft.
extends SuiteCase

const SMOKE := ["test_tiers_follow_progress", "test_loft_purchase_rules", "test_old_saves"]


# ------------------------------------------------------------------ fixtures
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _world() -> VillageWorld:
	var w := VillageWorld.new()
	_host().add_child(w)
	if PlayerNav.of(w) == null:
		var nav := PlayerNav.new()
		nav.name = "PlayerNav"
		w.add_child(nav)
		nav.setup(w, w.player)
	PlayerNav.of(w).ensure_grid(true)
	return w


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


func _room(rid: String) -> Dictionary:
	return Property.room_by_id(Property.rooms(), rid)


func _entity(w: VillageWorld, kind: String, id: String) -> Dictionary:
	for e in w.interactables:
		if str(e["kind"]) == kind and str(e["id"]) == id:
			return e
	return {}


## The whole building and every station set up (auto-placed), the lift rigged; returns the commit error ("" = ok).
func _full_building() -> String:
	Game.state["gold"] = 50000
	for u in Property.units():
		Property.dev_grant_unit(str(u["id"]))
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Property.buy_lift()
	var plan := Property.plan_copy()
	for st in DB.stations.values():
		var sid: String = st["id"]
		if (plan["stations"] as Dictionary).has(sid):
			continue
		(plan["stored"] as Array).append(sid)
		var why := Property.auto_place(plan, sid)
		if why != "":
			note("could not place %s: %s" % [sid, why])
	return Property.commit(plan)


# ------------------------------------------------------------------ tiers & discipline areas
func test_tiers_follow_progress() -> void:
	fresh_game()
	var forge := _room("forge_room")
	eq(Smithy.trade(forge), "classic", "the smithing hall reads as Smithing")
	eq(Smithy.room_tier(forge), 0, "a new game's smithing hall is Modest (smithing 4)")
	check(str(Smithy.tier_info(forge)["next"]).contains("Smithing 6"), "the next tier says what it needs: %s" % Smithy.tier_info(forge)["next"])
	eq(Smithy.room_tier(_room("rune_room")), 0, "a room he does not own has no tier")
	train("smithing", 6)
	eq(Smithy.room_tier(forge), 1, "Smithing 6 with its stations → Established")
	train("smithing", 12)
	Game.state["gold"] = 100
	eq(Smithy.room_tier(forge), 1, "skill alone does not make a Masterwork room (renown needed)")
	check(str(Smithy.tier_info(forge)["next"]).contains("renown"), "it says renown is missing: %s" % Smithy.tier_info(forge)["next"])
	Game.state["gold"] = 3000
	eq(Smithy.room_tier(forge), 2, "with renown (a wealthy workshop) → Masterwork")
	Game.state["gold"] = 100
	for i in 3:
		Recognition.record("epic", "Plaque %d" % i, "test", {}, "suite_smithy_%d" % i)
	eq(Smithy.room_tier(forge), 2, "Hall of Fame plaques are renown too")
	# planned crafts for empty rooms and discipline names
	eq(Property.planned_discipline(_room("leather_room")), "stitching", "Ilse's room is meant for leather & tailoring")
	eq(Smithy.trade_name("stitching"), "Leatherworking & Tailoring", "craft names")
	var plan := Property.plan_copy()
	Game.state["gold"] = 5000
	Property.buy_unit("laundry")
	plan = Property.plan_copy()
	eq(Property.set_discipline(plan, "alchemy_room", "runecraft"), "", "a room's craft can be changed in the layout")
	check(Property.set_discipline(plan, "shop", "classic") != "", "the shopfront is not a workshop")
	eq(Property.commit(plan), "", "and applied")
	eq(Smithy.trade(_room("alchemy_room")), "runecraft", "the empty room now reads as Runecrafting")


func test_auto_place_keeps_crafts_together() -> void:
	fresh_game()
	Game.state["gold"] = 9000
	for u in ["cobbler", "laundry", "weaver"]:
		Property.dev_grant_unit(u)
	var plan := Property.plan_copy()
	(plan["stored"] as Array).append("cauldron")
	(plan["stations"] as Dictionary).erase("cauldron")
	# move the alembic's usual place out of the way: a stitching station must not land in the alchemy room
	(plan["stored"] as Array).append("stitching_table")
	eq(Property.auto_place(plan, "cauldron"), "", "the cauldron is set up")
	eq(Property.auto_place(plan, "stitching_table"), "", "the stitching table is set up")
	var host := Property.room_at_tile(plan["rooms"], Vector2(float(plan["stations"]["cauldron"]["pos"][0]), float(plan["stations"]["cauldron"]["pos"][1])))
	eq(str(host.get("id", "")), "alchemy_room", "the cauldron stands in the alchemy room")
	var h2 := Property.room_at_tile(plan["rooms"], Vector2(float(plan["stations"]["stitching_table"]["pos"][0]), float(plan["stations"]["stitching_table"]["pos"][1])))
	eq(str(h2.get("id", "")), "leather_room", "the stitching table stands in the leather room")
	# with the leather room full, a tailoring station prefers the weaving loft over another trade's room
	Property.dev_grant_unit("loft")
	plan = Property.plan_copy()
	for sid in ["stitching_table", "thread_spinner", "leather_vat", "embroidery_frame", "fitting_mannequin", "tailors_bench"]:
		Property.place(plan, sid, Vector2(float(Property.data()["station_pos"][sid][0]), float(Property.data()["station_pos"][sid][1])))
	(plan["stored"] as Array).append("loom")
	(plan["stations"] as Dictionary).erase("loom")
	# the material store is not his: the loom's usual place is unavailable
	eq(Property.auto_place(plan, "loom"), "", "the loom is set up")
	var h3 := Property.room_at_tile(plan["rooms"], Vector2(float(plan["stations"]["loom"]["pos"][0]), float(plan["stations"]["loom"]["pos"][1])))
	eq(str(h3.get("id", "")), "loft_weaving", "a full leather room sends the loom up to the weaving loft")


func test_dressing_never_blocks() -> void:
	fresh_game()
	eq(_full_building(), "", "the full building is accepted")
	train("smithing", 12)
	for sk in ["runecraft", "alchemy", "enchanted_stitching", "arcane_metalwork"]:
		train(sk, 12)
	Game.state["gold"] = 4000
	var w := _world()
	var tiers := {}
	var dressing := 0
	for fid in ["ground", "loft"]:
		var off := Property.floor_rect(fid).position
		var list: Array = w.smithy_dressed.get(fid, [])
		dressing += list.size()
		for f in list:
			var p := Vector2(float(f[1]), float(f[2])) + off
			var fr := w._prop_rect_tiles(str(f[0]), p, float(f[3]))
			for sid in Property.st()["stations"]:
				check(not fr.intersects(Property.footprint(str(sid), Property.st()["stations"][sid])), "%s clear of the %s" % [f[0], sid])
			for d in Property.doors():
				var c := Property.door_center(Property.st(), d)
				check(c == Vector2.INF or not fr.grow(0.3).has_point(c), "%s clear of a doorway" % f[0])
			for rv: Rect2 in Property.reserved_rects():
				check(not fr.intersects(rv), "%s clear of the stair and the hoist" % f[0])
	for r in Property.rooms():
		if Property.room_owned(r) and Property.kind(r) == "workshop" and Smithy.trade(r) != "":
			tiers[str(r["id"])] = Smithy.room_tier(r)
	check(dressing >= 6, "advanced rooms are dressed (%d pieces)" % dressing)
	check(tiers.values().has(2), "some rooms are Masterwork in a progressed workshop: %s" % str(tiers))
	note("tiers in the progressed workshop: %s" % str(tiers))
	# banners: one per owned workshop room with a craft, on both floors
	var banners := 0
	for c in w.floor_layer.get_children():
		if c.has_meta("craft_banner"):
			banners += 1
	eq(banners, tiers.size(), "every workshop room has its craft banner")
	# every station can still be walked up to from the front door
	var nav := PlayerNav.of(w)
	var start: Vector2 = w.spots["smithy_inside"]
	var bad := []
	for e in w.interactables:
		if str(e["kind"]) != "station":
			continue
		var pl := nav.plan(start, e["pos"], float(e["r"]) - 12.0)
		if pl.is_empty():
			bad.append(str(e["id"]))
	eq(bad, [], "every station is reachable on foot with the dressing in place")
	_unmount(w)


# ------------------------------------------------------------------ the Loft
func test_loft_purchase_rules() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	eq(Property.unit_state("loft"), "unavailable", "the Loft is not for sale at the start")
	check(Property.buy_unit("loft").contains("Weaver"), "it needs Ilse's room first: %s" % Property.buy_unit("loft"))
	eq(Property.unit_state("garret"), "unavailable", "the garret neither")
	eq(Property.buy_unit("weaver"), "", "buy Ilse's room")
	eq(Property.unit_state("loft"), "available", "now the Loft is for sale")
	eq(Property.unit_state("garret"), "unavailable", "the garret only next to the Loft")
	eq(Property.buy_unit("loft"), "", "buy the Loft")
	check(Property.floor_owned("loft"), "he owns part of the upper floor")
	eq(Property.unit_state("garret"), "available", "the garret joins onto the Loft")
	eq(Property.buy_unit("garret"), "", "buy the garret")
	eq(Property.validate(Property.plan_copy()), "", "both floors are reachable (stair included)")
	# a station cannot stand on the stairwell or the hoist
	var plan := Property.plan_copy()
	var f := Property.floor_def("loft")
	check(Property.place(plan, "anvil", Vector2(float(f["stairs"][0]), float(f["stairs"][1]))) != "", "the stairwell stays clear")
	check(Property.place(plan, "anvil", Vector2(float(f["down_lift"][0]), float(f["down_lift"][1]))) != "", "the hoist shaft stays clear")
	eq(Property.place(plan, "anvil", Vector2(float(f["lift"][0]), float(f["lift"][1]))), "Keep the stairwell and the hoist clear.", "upstairs too, in the weaving loft")
	eq(Property.place(plan, "anvil", Vector2(float(f["lift"][0]), float(f["lift"][1]) - 2.0)), "", "but the weaving loft takes a station beside it")
	check(Property.stage().contains("workshop") or Property.stage().contains("smithy"), "stage: %s" % Property.stage())


func test_loft_stations_craft() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	Property.buy_unit("weaver")
	Property.buy_unit("loft")
	var plan := Property.plan_copy()
	eq(Property.place(plan, "anvil", Vector2(113.0, 25.5)), "", "move the anvil up into the weaving loft")
	eq(Property.place(plan, "grinding_wheel", Vector2(116.5, 25.5)), "", "and the grinding wheel")
	eq(Property.commit(plan), "", "the two-floor layout is accepted")
	eq(Property.station_floor("anvil"), "loft", "the anvil stands upstairs")
	check(Property.is_installed("anvil") and Crafting.station_locked_reason("anvil") == "", "it works there")
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var it := craft("iron_longsword")
	check(not it.is_empty() and str(it.get("def", "")) == "sword_iron", "a longsword forged below and drawn out upstairs (%s)" % it.get("def", "-"))
	var ops: Array = (it.get("craft", {}) as Dictionary).get("ops", [])
	check(ops.any(func(o): return str(o.get("station", "")) == "anvil"), "the anvil operation is in the record")
	check(save_load("suite_smithy_loft"), "save and load")
	eq(Property.station_floor("anvil"), "loft", "the anvil is still upstairs after loading")
	check(Property.owns("loft") and Property.floor_owned("loft"), "the Loft is still his")


func test_lift_and_stairs() -> void:
	fresh_game()
	Game.state["gold"] = 9000
	Property.buy_unit("weaver")
	check(Property.lift_reason() != "", "no lift without the Loft: %s" % Property.lift_reason())
	Property.buy_unit("loft")
	check(Property.lift_reason().contains("Arcane"), "the ley-stone needs an Arcane Foundry: %s" % Property.lift_reason())
	check(Property.buy_lift() != "" and not Property.has_lift(), "refused without it")
	Property.buy_unit("cobbler")
	eq(Property.buy_unit("cellar"), "", "buy the Old Dye-Works (the Arcane Foundry)")
	var g0 := Game.gold()
	eq(Property.buy_lift(), "", "rig the lift")
	check(Property.has_lift() and Game.gold() == g0 - Property.lift_price(), "it is running and was paid for")
	eq(Property.validate(Property.plan_copy()), "", "the lift is reachable on both floors")
	var w := _world()
	var up := _entity(w, "stairs", "smithy_loft")
	var down := _entity(w, "stairs", "smithy")
	var lift_up := _entity(w, "lift", "smithy_loft")
	var lift_down := _entity(w, "lift", "smithy")
	check(not up.is_empty() and not down.is_empty(), "a stair up from the stock hall and down from the landing")
	check(not lift_up.is_empty() and not lift_down.is_empty(), "the lift on both floors")
	var loft_rect: Rect2 = w.buildings["smithy_loft"]["rect"]
	w.player.position = lift_up["pos"]
	w.interact(lift_up)
	check(loft_rect.has_point(w.player.position), "one step on the lift: the smith is in the Loft")
	w.interact(lift_down)
	check((w.buildings["smithy"]["rect"] as Rect2).has_point(w.player.position), "and back down to the leather room")
	eq(w.room_at("smithy", w.player.position), "leather_room", "the lift arrives in the leather room")
	w.interact(up)
	check(loft_rect.has_point(w.player.position), "the stair also leads up")
	eq(w.room_at("smithy_loft", w.player.position), "loft_landing", "onto the landing")
	# walking: a click on an upstairs station from the shop plans through the stair or the lift
	var plan := Property.plan_copy()
	Property.place(plan, "grinding_wheel", Vector2(113.0, 25.5))
	Property.commit(plan)
	_unmount(w)
	w = _world()
	var nav := PlayerNav.of(w)
	w.player.position = w.spots["smithy_inside"]
	var gw := _entity(w, "station", "grinding_wheel")
	var pl := nav.plan(w.player.position, gw["pos"], float(gw["r"]) - 12.0)
	check(not pl.is_empty() and not (pl["jumps"] as Dictionary).is_empty(), "the walk to an upstairs station takes the stair or lift")
	check(save_load("suite_smithy_lift"), "save and load")
	check(Property.has_lift(), "the lift survives save/load")
	_unmount(w)


func test_apprentice_works_upstairs() -> void:
	fresh_game()
	train("smithing", 6)
	Game.state["gold"] = 20000
	(Game.state["hirelings"] as Array).clear()
	Property.buy_unit("weaver")
	Property.buy_unit("loft")
	var plan := Property.plan_copy()
	eq(Property.place(plan, "anvil", Vector2(113.0, 25.5)), "", "the anvil goes upstairs")
	eq(Property.commit(plan), "", "applied")
	var g := 0
	while Apprentices.applicants().is_empty() and g < 20:
		Apprentices.refresh_applicants()
		g += 1
	eq(Apprentices.hire(0), "", "hire an apprentice")
	var a: Dictionary = Apprentices.staff()[-1]
	a["traits"] = []
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	var m := int(Game.state["minute"]) % 1440
	Game.advance_minutes((7 * 60 + 50 - m + 1440) % 1440)
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "assignee": str(a["id"])})
	check(not t.has("error"), "a longsword queued (%s)" % t.get("error", ""))
	var w := _world()
	var acts := w.get_node("ApprenticeActors") as ApprenticeActors
	var seen_up := false
	var guard := 0
	while guard < 400 and not _done(t):
		Game.advance_minutes(5)
		guard += 1
		if Apprentices.station_user("anvil") == str(a["id"]):
			acts._last_now = -1
			acts.sync()
			var n: NPCActor = acts.actors.get(str(a["id"]))
			if n != null and n.visible and (w.buildings["smithy_loft"]["rect"] as Rect2).has_point(n.position):
				seen_up = true
				var ws := acts.work_spot("anvil")
				var nav := PlayerNav.of(w)
				check(nav.walkable(ws["pos"]) and nav.clear_at(ws["pos"], 16.0), "the anvil's working side upstairs is clear floor")
				var pl := nav.plan(w.spots["smithy_door_out"], ws["pos"])
				check(not pl.is_empty(), "the apprentice can walk there from the front door (by the stair)")
	check(seen_up, "the apprentice was seen working at the anvil in the Loft")
	check(_done(t), "the task finished (%s)" % str(t.get("state", "?")))
	_unmount(w)


func _done(t: Dictionary) -> bool:
	var live := Apprentices.task(int(t.get("id", -1)))
	if live.is_empty():
		live = t
	return str(live.get("state", "")) == "done"


# ------------------------------------------------------------------ less walking
func test_walk_and_craft_again() -> void:
	fresh_game()
	give("ingot_iron", 4)
	give("leather_cured", 2)
	var w := _world()
	var nav := PlayerNav.of(w)
	w.player.position = w.spots["smithy_inside"]
	check(Crafting.start("iron_longsword"), "begin a longsword")
	Crafting.record_step("forge", [95.0])
	eq(Crafting.current_station(), "anvil", "next: the anvil")
	eq(Smithy.walk_to_station("anvil", w), "", "walk to the anvil")
	check(nav.active() and str(nav.goal.get("e", {}).get("id", "")) == "anvil", "the smith is on his way to the anvil (and will use it)")
	nav.cancel()
	Crafting.cancel()
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var it := craft("iron_longsword")
	check(not it.is_empty(), "a longsword finished")
	var rid := str((it.get("craft", {}) as Dictionary).get("recipe", ""))
	eq(rid, "iron_longsword", "the piece remembers its recipe")
	eq(Smithy.craft_again_reason(rid), "", "materials for another: craft again is offered")
	eq(Smithy.craft_again(rid, false), "", "craft again starts the same recipe")
	eq(str(Crafting.job().get("recipe", "")), "iron_longsword", "the same recipe is running")
	Crafting.cancel()
	Game.remove_def("ingot_iron", Game.count("ingot_iron"))
	check(Smithy.craft_again_reason(rid).begins_with("Missing"), "without ingots it says what is missing: %s" % Smithy.craft_again_reason(rid))
	# the result panel offers it
	var panel := CraftResultPanel.new(it, true)
	_host().add_child(panel)
	var b := panel.find_child("CraftAgain", true, false) as Button
	check(b != null and b.disabled, "the result panel shows Craft again, greyed without materials")
	_unmount(panel)
	_unmount(w)


# ------------------------------------------------------------------ persistence
func test_old_saves() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	Property.buy_unit("cobbler")
	# a save from before the Loft: no loft rooms, no floors marker
	var s: Dictionary = Game.state["property"]
	s["rooms"] = (s["rooms"] as Array).filter(func(r): return not str(r["id"]).begins_with("loft_"))
	s["doors"] = (s["doors"] as Array).filter(func(d): return not str(d["between"][0]).begins_with("loft_"))
	s.erase("floors_v")
	for r in s["rooms"]:
		(r as Dictionary).erase("disc")
	check(Property.room_by_id(Property.rooms(), "loft_weaving").size() > 0, "an old save gains the Loft's rooms")
	check(not Property.owns("loft") and not Property.floor_owned("loft"), "but does not own them")
	eq(Property.planned_discipline(_room("rune_room")), "runecraft", "rooms without a stored craft read it from the data")
	eq(Property.validate(Property.plan_copy()), "", "the old layout is still valid")
	check(Property.owns("cobbler"), "and keeps what he bought")
	check(save_load("suite_smithy_old"), "save and load")
	check(Property.room_by_id(Property.rooms(), "loft_landing").size() > 0, "the Loft rooms persist")
	# a save from before property existed: the whole ground floor, not the Loft
	Game.state.erase("property")
	check(Property.owns("apartment") and Property.owns("cellar"), "a pre-009 save keeps the whole building")
	check(not Property.owns("loft") and not Property.owns("garret"), "but not the Loft")
	check(not Property.has_lift(), "nor a lift")


func test_every_station_reachable_full() -> void:
	fresh_game()
	eq(_full_building(), "", "with the whole building every station is set up and the plan accepted")
	var all := true
	for st in DB.stations.values():
		all = all and Property.is_installed(str(st["id"]))
	check(all, "all %d stations installed" % DB.stations.size())
	var up := 0
	for sid in Property.st()["stations"]:
		if Property.station_floor(str(sid)) == "loft":
			up += 1
	note("stations upstairs after auto-placement: %d" % up)
	var w := _world()
	var nav := PlayerNav.of(w)
	var start: Vector2 = w.spots["smithy_door_out"]
	var bad := []
	for e in w.interactables:
		if str(e["kind"]) == "station" and nav.plan(start, e["pos"], float(e["r"]) - 12.0).is_empty():
			bad.append(str(e["id"]))
	eq(bad, [], "every station on both floors is reachable from the front door")
	# capacity per craft: every craft has places for all its stations in rooms of its own craft
	var lines := []
	for c in Smithy.capacity_report():
		lines.append("%s %d stations / %d places (%d free)" % [c["disc"], int(c["stations"]), int(c["places"]), int(c["free"])])
		check(int(c["places"]) >= int(c["stations"]), "%s: room for all its stations in its own rooms (%d of %d)" % [c["name"], int(c["places"]), int(c["stations"])])
	note("capacity: " + "; ".join(lines))
	check(save_load("suite_smithy_full"), "save and load")
	check(Property.has_lift() and Property.floor_owned("loft"), "the full two-floor workshop persists")
	_unmount(w)
	# a lived-in two-floor arrangement: tailoring, alchemy and runecraft stations moved up into the Loft
	var plan := Property.plan_copy()
	var ups := [["loom", Vector2(112.6, 25.0)], ["cutting_table", Vector2(116.8, 25.0)], ["tailors_bench", Vector2(112.6, 30.2)],
		["alembic", Vector2(102.6, 20.4)], ["mortar_station", Vector2(106.6, 20.4)], ["reagent_table", Vector2(102.8, 24.8)],
		["rune_polishing_wheel", Vector2(102.4, 30.6)], ["resonance_pedestal", Vector2(106.4, 30.6)]]
	for pr in ups:
		eq(Property.place(plan, str(pr[0]), pr[1]), "", "%s moves upstairs" % pr[0])
	eq(Property.commit(plan), "", "the two-floor arrangement is accepted")
	w = _world()
	nav = PlayerNav.of(w)
	var acts := w.get_node("ApprenticeActors") as ApprenticeActors
	bad = []
	var cramped := []
	for e2 in w.interactables:
		if str(e2["kind"]) != "station":
			continue
		var sid2 := str(e2["id"])
		if nav.plan(w.spots["smithy_door_out"], e2["pos"], float(e2["r"]) - 12.0).is_empty():
			bad.append(sid2)
		var ws: Dictionary = acts.work_spot(sid2)
		if not (nav.walkable(ws["pos"]) and nav.clear_at(ws["pos"], 16.0)):
			cramped.append(sid2)
	eq(bad, [], "every station on both floors is reachable from the front door (stair or lift)")
	eq(cramped, [], "every station has a clear working side for an apprentice")
	var per_floor := {}
	for sid3 in Property.st()["stations"]:
		var fl := Property.station_floor(str(sid3))
		per_floor[fl] = int(per_floor.get(fl, 0)) + 1
	note("stations per floor: %s; free places %d" % [str(per_floor), Property.free_places()])
	_unmount(w)
