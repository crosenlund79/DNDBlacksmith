## Navigation & UI (iteration 010): quick travel costs exactly the walking time, the clock (and what runs
## on it) advances during the trip, it cannot start while a window stops the clock, the walk grid finds real
## paths through doors and up stairs, and K opens the Skill Tree.
extends SuiteCase

const SMOKE := ["test_walk_duration", "test_blocked_by_ui", "test_hotkeys"]


## A synthetic straight path: the trip's cost is the walk time for its length, and stepping it to the end
## puts exactly that many minutes on the clock (cancelling midway pays only for the distance walked).
func test_walk_duration() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(3000, 0), Vector2(3000, 1600)])
	var q := QuickTravel.make(pts)
	eq(q.length, 4600.0, "path length")
	var expect_m := int(round(4600.0 / PlayerBody.WALK * Game.MINUTES_PER_SECOND * float(Settings.get_value("gameplay/time_scale", 1.0))))
	eq(q.minutes, expect_m, "quick-travel cost equals the walk time for the path length")
	eq(QuickTravel.walk_minutes(4600.0), expect_m, "walk_minutes agrees")
	var t0 := Game.now()
	var guard := 0
	while not q.done() and guard < 1000:
		q.step(PlayerBody.WALK * QuickTravel.SPEED_MULT / 60.0)
		guard += 1
	check(q.done(), "the trip ends")
	eq(Game.now() - t0, expect_m, "the clock advanced by the whole walk")
	check(q.pos.distance_to(Vector2(3000, 1600)) < 0.01, "the traveller stands at the end of the path")
	# cancelled halfway: only the distance walked is paid
	var q2 := QuickTravel.make(pts)
	var t1 := Game.now()
	q2.step(2300.0)
	q2.cancel()
	var paid := Game.now() - t1
	check(absi(paid - int(expect_m / 2.0)) <= 1, "half the walk costs half the time (%d of %d)" % [paid, expect_m])
	# stair hops are free and instant
	var q3 := QuickTravel.make(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(9000, 0), Vector2(9100, 0)]), {1: true})
	eq(q3.length, 200.0, "a stairway hop adds no walking distance")


## During a trip the clock advances minute by minute, so an expedition out on the road progresses.
func test_clock_runs_during_travel() -> void:
	var aid := ""
	for k in Adv.all():
		var a: Dictionary = Adv.all()[k]
		Expeditions.ensure(a)
		if a["status"] != "dead":
			aid = k
			break
	if aid == "":
		skip("no adventurer in this build")
		return
	var a2 := Adv.get_a(aid)
	a2["status"] = "in_town"
	a2["hp"] = a2["hp_max"]
	Expeditions.st()["parties"] = {}
	var dest := "whisperwood" if Expeditions.region("whisperwood").size() > 0 else str(DB.destinations.keys()[0])
	var e := Expeditions.start({"id": "p_nav", "members": [aid], "leader": aid, "dest": dest, "goal": "explore"})
	if e.is_empty() or not Expeditions.active().has(str(e["id"])):
		skip("the expedition did not start")
		return
	var ex: Dictionary = Expeditions.active()[str(e["id"])]
	var leg_end := int(ex["next_at"])
	var mins := leg_end - Game.now() + 30
	# a walk long enough to outlast the first leg of the expedition
	var px := float(mins) / Game.MINUTES_PER_SECOND / float(Settings.get_value("gameplay/time_scale", 1.0)) * PlayerBody.WALK
	var q := QuickTravel.make(PackedVector2Array([Vector2.ZERO, Vector2(px, 0)]))
	var t0 := Game.now()
	var mid_checked := false
	var guard := 0
	while not q.done() and guard < 5000:
		q.step(PlayerBody.WALK * QuickTravel.SPEED_MULT / 30.0)
		guard += 1
		if not mid_checked and q.covered > q.length * 0.5:
			mid_checked = true
			check(Game.now() > t0 and Game.now() < t0 + q.minutes, "the clock advances step by step during the trip")
	eq(Game.now() - t0, q.minutes, "the trip cost the walking time")
	check(not Expeditions.active().has(str(e["id"])) or str(ex["phase"]) != "travel_out" or str(ex["at"]) != "village",
		"the expedition progressed on its timer while the smith travelled (phase %s, at %s)" % [ex.get("phase", "?"), ex.get("at", "?")])


## A window that stops the clock (or a fade) blocks quick travel.
func test_blocked_by_ui() -> void:
	eq(QuickTravel.blocked_reason(), "", "free to travel with nothing open")
	Game.block_time(true)
	check(QuickTravel.blocked_reason() != "", "a clock-stopping window blocks quick travel")
	var w := _world()
	if w:
		var nav := _nav(w)
		var why := nav.start_travel("harbour")
		check(why != "" and nav.trip == null, "start_travel refuses while blocked (%s)" % why)
	Game.block_time(false)
	if w:
		_free(w)


## The real village: a path from inside the smithy to the harbour leaves by the door, its cost is the walk
## time for its length, the trip ends at the harbour with that many minutes on the clock; the inn's upper
## floor is reached by the stairs.
func test_real_paths() -> void:
	var w := _world()
	if w == null:
		skip("the village could not be built here")
		return
	var nav := _nav(w)
	nav.ensure_grid(true)
	var start := w.bpos("smithy", 15, 7.5)
	w.player.position = start
	check(nav.walkable(start), "the smith's start inside the forge is walkable")
	var dests := {}
	for d in nav.destinations():
		dests[d["id"]] = d
	check(dests.has("harbour") and dests.has("inn") and dests.has("smithy"), "known destinations: %s" % [dests.keys()])
	var r := nav.route_to(dests["harbour"]["pos"])
	check(not r.is_empty(), "there is a walk from the forge to the harbour")
	if r.is_empty():
		_free(w)
		return
	eq(int(r["minutes"]), QuickTravel.walk_minutes(float(r["length"])), "the travel cost is the walk time for the path length")
	# the path leaves the forge through its door
	var door: Vector2 = w.spots.get("smithy_door_out", Vector2.INF)
	var near_door := false
	for p in (r["points"] as PackedVector2Array):
		if door != Vector2.INF and p.distance_to(door) < 200.0:
			near_door = true
	check(near_door, "the walk passes the forge's door")
	# every straight leg is collision-free
	var pts: PackedVector2Array = r["points"]
	var clear_legs := true
	for i in range(pts.size() - 1):
		if not nav.los(pts[i], pts[i + 1]):
			clear_legs = false
	check(clear_legs, "every leg of the path is clear of walls and furniture")
	var t0 := Game.now()
	eq(nav.start_travel("harbour"), "", "quick travel starts")
	var guard := 0
	while nav.trip != null and guard < 2000:
		nav.travel_step(1.0 / 30.0)
		guard += 1
	eq(Game.now() - t0, int(r["minutes"]), "the clock advanced by the walk time")
	check(w.player.position.distance_to(dests["harbour"]["pos"]) < 120.0, "the smith stands at the harbour")
	# upstairs at the inn: by the stairs
	if w.spots.has("lantern_1"):
		var up := nav.plan(w.player.position, w.spots["lantern_1"])
		check(not up.is_empty() and not (up["jumps"] as Dictionary).is_empty(), "the rooms upstairs are reached by the stairs")
	_free(w)


func test_hotkeys() -> void:
	eq(UIRoot.panel_for_action("panel_skills"), "skilltree", "K opens the Skill Tree")
	check((Settings.DEFAULT_KEYS["panel_skills"] as Array).has(KEY_K), "panel_skills is bound to K")
	eq(UIRoot.panel_for_action("panel_skill_levels"), "skills", "the skill levels stay reachable (U)")
	eq(UIRoot.panel_for_action("quick_travel"), "quick_travel", "T opens quick travel")
	check((Settings.DEFAULT_KEYS["quick_travel"] as Array).has(KEY_T), "quick_travel is bound to T")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	ev.pressed = true
	check(InputMap.event_is_action(ev, "panel_skills"), "pressing K triggers panel_skills")
	check(bool(Settings.values.get("gameplay/click_to_move", false)), "click-to-move is on by default")


# ------------------------------------------------------------------ helpers
func _world() -> VillageWorld:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	# the suite runs from the runner's _ready (the root is still busy): host the village under the runner
	var host: Node = tree.root.get_child(tree.root.get_child_count() - 1)
	var w := VillageWorld.new()
	host.add_child(w)
	if w.player == null:
		_free(w)
		return null
	return w


func _nav(w: VillageWorld) -> PlayerNav:
	var n := PlayerNav.of(w)
	if n == null:
		n = PlayerNav.new()
		w.add_child(n)
		n.setup(w, w.player)
	return n


func _free(w: VillageWorld) -> void:
	if is_instance_valid(w):
		if w.get_parent():
			w.get_parent().remove_child(w)
		w.free()
