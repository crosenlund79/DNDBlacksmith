## Canonical v1.6 §11 — four atmospheric seasons of 21 days (an 84-day cycle from spring on Day 1) with visual and audio
## weather only: the calendar of seasons, smooth transitions, deterministic weather that survives saves and time skips,
## nothing written to the game state, no draw on the game's random numbers, no gameplay system reading it, and the
## village actually dressed for each season (palette, snow on ground, roofs and trees, blossom, particles, light).
extends SuiteCase

const SMOKE := ["test_calendar_of_seasons", "test_nothing_written_no_randomness"]


func test_calendar_of_seasons() -> void:
	var want := {1: "spring", 21: "spring", 22: "summer", 42: "summer", 43: "autumn", 63: "autumn", 64: "winter", 84: "winter",
		85: "spring", 106: "summer", 169: "spring", 336: "winter", 337: "spring"}
	for d in want:
		eq(Seasons.season(int(d)), str(want[d]), "day %d is %s" % [d, want[d]])
	eq([Seasons.day_of_season(1), Seasons.day_of_season(21), Seasons.day_of_season(22), Seasons.day_of_season(84)], [1, 21, 1, 21],
		"21 days each")
	var bad := 0
	for d in range(1, 400):
		if Seasons.season(d) != Seasons.season(d + Seasons.CYCLE):
			bad += 1
	eq(bad, 0, "an 84-day cycle")
	eq(Seasons.label(64), "Winter, day 1 of 21", "the clock's words")
	# the calendar itself is untouched: no new day length, week or year
	fresh_game()
	eq([Game.day(), Game.weekday_name()], [1, "Moonday"], "Day 1 is still a Moonday, and spring")


func test_smooth_transitions() -> void:
	var prev := {}
	var worst := {"ground": 0.0, "foliage": 0.0, "light": 0.0, "snow": 0.0, "amount": 0.0}
	var kind_jumps := 0
	var steps := 0
	for day in range(1, 2 * Seasons.CYCLE + 1):
		for m in range(0, 1440, 30):
			var lk := SeasonDressing.look_for(day, m, 4242)
			if not prev.is_empty():
				for k in ["ground", "foliage", "light"]:
					var a: Color = prev[k]
					var b: Color = lk[k]
					worst[k] = maxf(float(worst[k]), maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)))
				worst["snow"] = maxf(float(worst["snow"]), absf(float(prev["snow"]) - float(lk["snow"])))
				var pw: Dictionary = prev["weather"]
				var nw: Dictionary = lk["weather"]
				worst["amount"] = maxf(float(worst["amount"]), absf(float(pw["amount"]) - float(nw["amount"])))
				if str(pw["kind"]) != str(nw["kind"]) and float(nw["amount"]) > 0.05:
					kind_jumps += 1
			prev = lk
			steps += 1
	note("over two cycles in half hours (%d steps), the largest step: %s" % [steps, str(worst)])
	# the season's palette moves by thousandths an hour; the daylight also follows the weather (a shower greys it), still
	# by a few hundredths at most in half an hour
	check(float(worst["ground"]) < 0.02 and float(worst["foliage"]) < 0.02 and float(worst["light"]) < 0.06,
		"palette and light turn gradually (largest half-hour steps: %s)" % str(worst))
	check(float(worst["snow"]) < 0.06, "snow comes and thaws gradually")
	check(float(worst["amount"]) < 0.55, "weather builds and fades (largest half-hour change %.2f)" % float(worst["amount"]))
	eq(kind_jumps, 0, "one weather gives way to another only through a calm moment")
	# each season looks its part at its heart, and the turn sits at the season's end
	var mid := {}
	for s in Seasons.ORDER:
		mid[s] = SeasonDressing.look_for(Seasons.ORDER.find(s) * Seasons.LENGTH + 10, 720, 4242)
	check(float(mid["winter"]["snow"]) > 0.99 and float(mid["summer"]["snow"]) == 0.0 and float(mid["spring"]["snow"]) == 0.0,
		"snow in winter only")
	check(float(mid["spring"]["blossom"]) > 0.4 and float(mid["autumn"]["autumn"]) > 0.99, "blossom in spring, turning leaves in autumn")
	var turning := SeasonDressing.look_for(62, 720, 4242)
	check(float(turning["snow"]) > 0.1 and float(turning["snow"]) < 0.9, "the last days of autumn turn toward winter (%.2f)" % float(turning["snow"]))
	# over a year every season shows its typical weather
	var seen := {}
	for day in range(1, Seasons.CYCLE + 1):
		for m in range(0, 1440, 60):
			var w := Seasons.weather(day, m, 4242)
			seen["%s/%s" % [Seasons.season(day), w["kind"]]] = true
	for k in ["spring/blossom", "spring/light_rain", "spring/mist", "summer/sun", "summer/showers", "autumn/leaves", "autumn/rain",
			"autumn/fog", "winter/snow"]:
		check(seen.has(k), "%s happens in a cycle" % k)


func test_deterministic_weather_survives_saves_and_skips() -> void:
	eq(Seasons.weather(30, 615, 77), Seasons.weather(30, 615, 77), "the same moment, the same weather")
	var diff := 0
	for d in range(1, 85):
		if Seasons.weather(d, 720, 77)["kind"] != Seasons.weather(d, 720, 78)["kind"]:
			diff += 1
	check(diff > 10, "another world (seed) has its own weather (%d of 84 noons differ)" % diff)
	# a save and load shows the same sky
	fresh_game("journeyman", 5150)
	days(3)
	Game.advance_minutes(37)
	var before := SeasonDressing.look_for(Game.day(), int(Game.state["minute"]))
	check(save_load("t_seasons_rt"), "save and load")
	var after := SeasonDressing.look_for(Game.day(), int(Game.state["minute"]))
	eq(JSON.stringify(after), JSON.stringify(before), "the same season, palette and weather after loading")
	# one long skip and many short steps arrive at the same sky
	fresh_game("journeyman", 5151)
	Game.advance_minutes(5 * 1440 + 200)
	var skip := [Game.day(), int(Game.state["minute"]), JSON.stringify(SeasonDressing.look_for(Game.day(), int(Game.state["minute"])))]
	fresh_game("journeyman", 5151)
	for i in 5 * 24:
		Game.advance_minutes(60)
	Game.advance_minutes(200)
	var stepped := [Game.day(), int(Game.state["minute"]), JSON.stringify(SeasonDressing.look_for(Game.day(), int(Game.state["minute"])))]
	eq(stepped, skip, "a time skip and hour-by-hour play show the same sky")


func test_nothing_written_no_randomness() -> void:
	fresh_game("journeyman", 5152)
	var snap := JSON.stringify(Game.state)
	seed(9090)
	var expect_next := randi()
	seed(9090)
	for d in [1, 20, 22, 50, 62, 70, 84, 300]:
		Seasons.now()
		Seasons.describe(d, 600)
		SeasonDressing.look_for(d, 600)
	eq(randi(), expect_next, "no draw on the game's random numbers")
	eq(JSON.stringify(Game.state), snap, "nothing written to the game state")
	# no gameplay system reads the seasons; the dressing and the HUD are the only users
	var users := []
	for dir in ["res://scripts/systems/", "res://scripts/autoload/", "res://scripts/ui/", "res://scripts/world/", "res://scripts/ui/panels/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			if f != "seasons.gd" and (src.contains("Seasons.") or src.contains("SeasonDressing") or src.contains("season_dressing")):
				users.append(f)
	users.sort()
	eq(users, ["season_dressing.gd", "ui_root.gd", "world.gd"], "only the village dressing, its world and the HUD clock use the seasons")
	for f in ["res://scripts/systems/seasons.gd", "res://scripts/world/season_dressing.gd"]:
		var src := FileAccess.get_file_as_string(f)
		var code := "\n".join(Array(src.split("\n")).filter(func(l): return not str(l).strip_edges().begins_with("#")))
		for bad in ["randf(", "randi(", "seed(", "Game.state[", "set_flag(", "advance_minutes", "add_gold", ".emit("]:
			var pat: String = bad.replace("(", "\\(").replace("[", "\\[").replace(".", "\\.")
			var re := RegEx.create_from_string(pat if bad.begins_with(".") else "(?<![A-Za-z_.])" + pat)
			check(re.search(code) == null, "%s never uses %s" % [f.get_file(), bad])


func _world() -> VillageWorld:
	var root := (Engine.get_main_loop() as SceneTree).root
	var host: Node = root.get_child(root.get_child_count() - 1)
	var w := VillageWorld.new()
	host.add_child(w)
	return w


func test_the_village_is_dressed() -> void:
	fresh_game("journeyman", 5153)
	var w := _world()
	var sd := w.season_dressing
	if not check(sd != null and is_instance_valid(sd), "the village has its season dressing"):
		w.queue_free()
		return
	var trees: Array = sd._veg.filter(func(e): return str(e[1]) in ["tree_oak_a", "tree_oak_b"])
	var pines: Array = sd._veg.filter(func(e): return str(e[1]) == "tree_pine")
	check(trees.size() > 20 and pines.size() > 5, "the dressing knows the village's trees (%d broadleaf, %d pines)" % [trees.size(), pines.size()])
	check(sd._roof_mats.size() >= 5, "and its roofs (%d)" % sd._roof_mats.size())
	var snap := JSON.stringify(Game.state)
	var at := func(day: int, minute: int) -> Dictionary:
		Game.state["day"] = day
		Game.state["minute"] = minute
		sd.refresh(true)
		sd._follow_camera()
		w._update_light(true)
		var tree: Sprite2D = trees[0][0]
		var oak_mat: ShaderMaterial = sd._mats.get("tree_oak_a", sd._mats.get("tree_oak_b"))
		return {"tree": tree.self_modulate, "grass": sd._grass.self_modulate, "roof": float((sd._roof_mats[0] as ShaderMaterial).get_shader_parameter("snow")),
			"tree_snow": float(oak_mat.get_shader_parameter("snow")), "ground_snow": float(sd._overlay_mat.get_shader_parameter("snow")),
			"sky": w.canvas_mod.color, "snowing": (sd._fx["snow"] as CPUParticles2D).emitting, "raining": (sd._fx["rain"] as CPUParticles2D).emitting}
	var day0 := Game.day()
	var min0 := int(Game.state["minute"])
	var summer: Dictionary = at.call(30, 720)
	var autumn: Dictionary = at.call(52, 720)
	var winter: Dictionary = at.call(74, 720)
	var spring: Dictionary = at.call(10, 720)
	eq(summer["tree"], Color.WHITE, "summer: the trees as drawn")
	check((autumn["tree"] as Color).b < 0.6 and (autumn["tree"] as Color).r > 0.8, "autumn: the broadleaf trees turn gold and red (%s)" % str(autumn["tree"]))
	check(float(winter["roof"]) > 0.8 and float(winter["ground_snow"]) > 0.95 and float(winter["tree_snow"]) > 0.5, "winter: snow on the roofs, the ground and the trees")
	check(float(summer["roof"]) == 0.0 and float(summer["ground_snow"]) == 0.0, "summer: no snow")
	check(float(spring["tree_snow"]) > 0.0 or float(sd._mats.get("tree_small", sd._mats.values()[0]).get_shader_parameter("snow")) > 0.0, "spring: blossom on the flowering trees")
	check((winter["sky"] as Color).b > (winter["sky"] as Color).r, "winter: a pale, cold daylight")
	check((autumn["grass"] as Color).b < (summer["grass"] as Color).b, "autumn: the grass dries to gold")
	# weather particles follow the deterministic weather
	var snowy := []
	var rainy := []
	for d in range(64, 85):
		for m in range(540, 900, 30):
			var wx := Seasons.weather(d, m)
			if str(wx["kind"]) == "snow" and float(wx["amount"]) > 0.4 and snowy.is_empty():
				snowy = [d, m]
	for d in range(43, 64):
		for m in range(540, 900, 30):
			var wx2 := Seasons.weather(d, m)
			if str(wx2["kind"]) == "rain" and float(wx2["amount"]) > 0.4 and rainy.is_empty():
				rainy = [d, m]
	if check(not snowy.is_empty() and not rainy.is_empty(), "a snowy and a rainy moment exist"):
		var sn: Dictionary = at.call(int(snowy[0]), int(snowy[1]))
		check(bool(sn["snowing"]) and not bool(sn["raining"]), "it snows when the weather is snow")
		var rn: Dictionary = at.call(int(rainy[0]), int(rainy[1]))
		check(bool(rn["raining"]) and not bool(rn["snowing"]), "it rains when the weather is rain")
	Game.state["day"] = day0
	Game.state["minute"] = min0
	eq(JSON.stringify(Game.state), snap, "dressing the village through every season wrote nothing to the game state")
	w.queue_free()
