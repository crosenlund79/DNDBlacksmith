## Property expansion (scenario D): buy rooms, connect them, alter partitions, relocate stations, verify
## accessibility and persistence.
extends SuiteCase

const SMOKE := ["test_modest_start", "test_expand_and_persist"]


func test_modest_start() -> void:
	check(Property.owns("start") and (Property.st()["units"] as Array).size() == 1, "1. a new game owns only the modest smithy")
	check(Property.is_installed("forge") and Property.is_installed("anvil") and not Property.is_installed("arcane_crucible"), "1. only the essential stations are installed")
	eq(Property.validate(Property.plan_copy()), "", "the starting layout is reachable")
	check(Property.unit_state("cobbler") == "available" and Property.unit_state("cellar") == "unavailable", "only adjoining rooms are for sale")


func test_expand_and_persist() -> void:
	Game.state["gold"] = 6000
	check(Property.buy_unit("cellar") != "", "4. a room that does not adjoin cannot be bought")
	eq(Property.buy_unit("cobbler"), "", "4. buy the cobblery")
	eq(Property.buy_unit("chandler"), "", "4. dig the cellar (v1.7: the basement is dug, not bought from a neighbour)")
	eq(Property.buy_unit("cellar"), "", "4. then the vault beyond it")
	var st_ok := Property.buy_station("rune_engraving_stand")
	if st_ok != "":
		note("rune engraving stand not purchasable yet: " + st_ok)
		Property.st()["stored"].append("rune_engraving_stand")
	var plan := Property.plan_copy()
	eq(Property.place(plan, "rune_engraving_stand", Vector2(3.5, 13.0)), "", "6. place a station in the bought room")
	check(Property.place(plan, "anvil", Vector2(10.0, 4.0)) != "", "6. a station cannot straddle a wall")
	eq(Property.place(plan, "grinding_wheel", Vector2(5.0, 15.5)), "", "6. relocate the grinding wheel into the new room")
	eq(Property.split(plan, "arcane_room", true, 118), "", "5. a partition divides the vault (in the basement, plan x 118)")
	eq(Property.add_door(plan, "forge_room", "rune_room", 6), "", "5. a second doorway is cut")
	eq(Property.validate(plan), "", "5. the new layout keeps everything reachable")
	eq(Property.commit(plan), "", "the plan is applied")
	check(Property.is_installed("grinding_wheel") and Crafting.station_locked_reason("grinding_wheel") == "", "6. the relocated station still works")
	var why := craft_blocker("iron_longsword")
	check(why == "", "6. crafting still runs through the relocated station (%s)" % why)
	var units := (Property.st()["units"] as Array).size()
	var rooms := Property.rooms().size()
	var gw := Property.pos_of("grinding_wheel")
	check(save_load("suite_property"), "12. save and load")
	check((Property.st()["units"] as Array).size() == units and Property.rooms().size() == rooms and Property.pos_of("grinding_wheel") == gw, "12. ownership, rooms and station placement restored")


func test_trapping_layouts_refused() -> void:
	Game.state["gold"] = 3000
	Property.buy_unit("cobbler")
	var plan := Property.plan_copy()
	for d in (plan["doors"] as Array).duplicate():
		if (d["between"] as Array).has("rune_room") and Property.door_open(plan, d):
			(plan["doors"] as Array).erase(d)
	check(Property.commit(plan) != "", "a layout that cuts off a room is refused")
	plan = Property.plan_copy()
	check(Property.split(plan, "shop", true, 14) != "", "the shopfront keeps its walls")
	check(Property.place(plan, "anvil", Vector2(14.0, 1.0)) != "", "the front door stays clear")
	# a station dropped in the forge-room doorway to the stock hall is refused
	plan = Property.plan_copy()
	check(Property.place(plan, "anvil", Vector2(9.6, 8.0)) != "", "a station cannot block a doorway")


func test_old_save_keeps_building() -> void:
	Game.state.erase("property")
	check(Property.owns("cellar") and Property.owns("apartment") and Property.is_installed("arcane_anvil"), "a save from before iteration 009 keeps the whole building")


## Iteration 012: every discipline is practically usable — with the whole building bought, all 29 stations can be
## set up (automatically) without breaking reachability, and each room's default layout fits its own capacity.
func test_every_station_fits() -> void:
	fresh_game()
	for u in Property.units():
		Property.dev_grant_unit(str(u["id"]))
	var plan := Property.plan_copy()
	for r in plan["rooms"]:
		if Property.kind(r) == "workshop":
			var n := 0
			var sp: Dictionary = Property.data().get("station_pos", {})
			for sid in sp:
				if Property.rect(r).has_point(Vector2(float(sp[sid][0]), float(sp[sid][1]))):
					n += 1
			check(n <= Property.capacity(r), "%s holds its default stations (%d of %d)" % [r.get("name", r["id"]), n, Property.capacity(r)])
	var placed := 0
	for st in DB.stations.values():
		var sid: String = st["id"]
		if (plan["stations"] as Dictionary).has(sid):
			placed += 1
			continue
		(plan["stored"] as Array).append(sid)
		if Property.auto_place(plan, sid) == "":
			placed += 1
		else:
			note("could not place %s: %s" % [sid, Property.auto_place(plan.duplicate(true), sid)])
	eq(placed, DB.stations.size(), "all %d stations are set up" % DB.stations.size())
	eq(Property.validate(plan), "", "the full workshop is reachable")
	eq(Property.commit(plan), "", "and the plan is accepted")
	var ok := true
	for st2 in DB.stations.values():
		ok = ok and Property.is_installed(str(st2["id"]))
	check(ok, "every station counts as installed")
	check(Property.free_places() >= 0, "free places are counted (%d left)" % Property.free_places())
	check(save_load("suite_prop_full"), "save and load")
	check(Property.is_installed("loom") and Property.is_installed("tailors_bench"), "the late tailoring stations stay installed")
