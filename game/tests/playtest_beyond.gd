## Rendered play-test phases of the overnight build "Beyond the Safe Roads" (canonical v1.6).
## beyond_map: the world map with the three dangerous regions revealed (Starfall Observatory, Weeping Fortress,
## Blackglass Rift), each site's page, and an observer on the road to one of them. Shots beyond_*.
## seasons: the village in each of the four seasons with its typical weather (spring blossom and light rain, summer sun
## and showers, autumn leaves and fog, winter snowfall), the turn from autumn into winter, and the weather seen from inside
## the workshop (it stays outside). Each moment is a real (day, minute) whose deterministic weather is the wanted one —
## found by asking Seasons, never forced. Shots season_*.
## Called from tests/playtest.gd (phase_beyond_map, phase_seasons).
extends RefCounted

const NEW := ["starfall_observatory", "weeping_fortress", "blackglass_rift"]

var pt: Node


func _shot(name: String) -> void:
	await pt.shot("beyond_%s" % name)


func run_map(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	# the places beyond: found from the dangerous places nearer home (their neighbours known too)
	for rid in ["ravens_hold", "sunken_temple", "drakes_crag"] + NEW:
		WorldSites.reveal(rid, "explored" if NEW.has(rid) else "rumour")
	for rid in NEW:
		pt.expect(WorldSites.is_discovered(rid) and Game.has_flag("site_" + rid), "beyond: %s is on the map and a destination" % rid)
	# a party bound for the Weeping Fortress, so the map shows a company on the road
	var ids := ["sigrun", "garrick", "tomas"]
	for id in ids:
		var a := Adv.get_a(id)
		a["status"] = "in_town"
		a["level"] = 9
	var e := Expeditions.start({"id": "p_beyond", "members": ids, "leader": ids[0], "dest": "weeping_fortress", "goal": "explore"})
	e["leg"]["t1"] = Game.now() + 180
	e["leg"]["t0"] = Game.now() - 60
	await pt.press("panel_world_map")
	await pt.wait(1.0)
	pt.expect(pt.panel() is WorldMapPanel, "beyond: the world map opens")
	await _shot("world_map")
	var wp := pt.panel() as WorldMapPanel
	if wp == null:
		return
	for rid in NEW:
		wp.select(rid)
		await pt.wait(0.6)
		await _shot("site_" + rid)
	await pt.close_panel()
	Events.open_panel.emit("observe", {"id": str(e["id"])})
	await pt.wait(1.0)
	await _shot("observer_fortress")
	await pt.close_panel()


# ======================================================================= seasons (canonical v1.6 §11)
## The first daylight moment in `season` (from its `from`th day) whose weather is `kind` at amount >= `least`.
func _moment(season: String, kind: String, least := 0.5, from := 1) -> Array:
	var base := Seasons.ORDER.find(season) * Seasons.LENGTH + 1
	for d in range(base + from - 1, base + Seasons.LENGTH - int(Seasons.BLEND_DAYS)):
		for m in range(9 * 60, 15 * 60 + 1, 30):
			var w := Seasons.weather(d, m)
			if str(w["kind"]) == kind and float(w["amount"]) >= least:
				return [d, m]
	return []


func _at(day: int, minute: int) -> void:
	Game.state["day"] = day
	Game.state["minute"] = minute
	var w: VillageWorld = pt.W()
	w.season_dressing.refresh(true)
	w._update_light(true)
	await pt.wait(2.2)
	await _fps_note("")


func _fps_note(_tag: String) -> void:   # frames per second over 1.5 s, and how many weather particles fly
	var w: VillageWorld = pt.W()
	var f0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_msec()
	await pt.wait(1.5)
	var live := 0
	for k in w.season_dressing._fx:
		var pp: CPUParticles2D = w.season_dressing._fx[k]
		live += pp.amount if pp.emitting else 0
	pt.note("frames: %.1f fps with %d weather particles (day %d %02d:%02d)" % [float(Engine.get_process_frames() - f0) * 1000.0 / maxf(1.0, float(Time.get_ticks_msec() - t0)),
		live, Game.day(), int(Game.state["minute"]) / 60, int(Game.state["minute"]) % 60])


func run_seasons(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w: VillageWorld = pt.W()
	pt.expect(w.season_dressing != null, "seasons: the village has its season dressing")
	var square: Vector2 = w.spots["square_0"]
	# the dressing's own cost: the same view with and without it (snowing, evening — the heaviest case)
	await pt.tp(square + Vector2(-300, 120))
	var heavy := _moment("winter", "snow", 0.7)
	if not heavy.is_empty():
		await _at(int(heavy[0]), 19 * 60)
		w.season_dressing.set_process(false)
		w.season_dressing._layer.visible = false
		w.season_dressing._overlay.visible = false
		await pt.wait(1.0)
		var f0 := Engine.get_process_frames()
		var t0 := Time.get_ticks_msec()
		await pt.wait(1.5)
		pt.note("frames: %.1f fps without the weather layer and ground overlay (same view)" % (float(Engine.get_process_frames() - f0) * 1000.0 / maxf(1.0, float(Time.get_ticks_msec() - t0))))
		w.season_dressing.set_process(true)
		w.season_dressing.refresh(true)
	var shots := [["spring", "blossom"], ["spring", "light_rain"], ["summer", "sun"], ["summer", "showers"], ["autumn", "leaves"],
		["autumn", "fog"], ["autumn", "rain"], ["winter", "snow"]]
	for s in shots:
		var at := _moment(str(s[0]), str(s[1]), 0.55)
		if at.is_empty():
			at = _moment(str(s[0]), str(s[1]), 0.3)
		pt.expect(not at.is_empty(), "seasons: %s brings %s on some day" % [s[0], s[1]])
		if at.is_empty():
			continue
		await pt.tp(square + Vector2(-300, 120))
		await _at(int(at[0]), int(at[1]))
		var lk: Dictionary = w.season_dressing.look
		pt.expect(str(lk["season"]) == str(s[0]) and str(lk["weather"]["kind"]) == str(s[1]),
			"seasons: day %d %s — %s (%.2f)" % [at[0], Seasons.describe(int(at[0]), int(at[1])), lk["weather"]["kind"], float(lk["weather"]["amount"])])
		await _shot("season_%s_%s" % [s[0], s[1]])
	# the turn of autumn into winter: the last day of autumn, half white
	await _at(62, 13 * 60)
	pt.expect(float(w.season_dressing.look["snow"]) > 0.1 and float(w.season_dressing.look["snow"]) < 0.9,
		"seasons: day 62 is turning — snow cover %.2f" % float(w.season_dressing.look["snow"]))
	await _shot("season_turning_to_winter")
	# winter evening: lamps on the snow
	var eve := _moment("winter", "snow", 0.4, 5)
	if not eve.is_empty():
		await _at(int(eve[0]), 18 * 60 + 40)
		await _shot("season_winter_evening")
	# inside the workshop, snow and rain stay outside
	var inside: Vector2 = w._room_rect_by_id("smithy", "shop").get_center()
	for s in [["winter", "snow"], ["autumn", "rain"]]:
		var at2 := _moment(str(s[0]), str(s[1]), 0.6)
		if at2.is_empty():
			continue
		await pt.tp(inside)
		await _at(int(at2[0]), int(at2[1]))
		pt.expect(w.area == "smithy", "seasons: the smith is inside the smithy (%s)" % w.area)
		await _shot("season_inside_%s" % s[1])
	# no season or weather is kept in the game state: it is derived from the calendar
	pt.expect(not Game.state.keys().any(func(k): return str(k).contains("season") or str(k).contains("weather")),
		"seasons: no season or weather is kept in the game state")
