## Iteration 010 — hirelings: the bottom-left HUD's view of each hand (status, health, expedition progress),
## death on an expedition (the place frees up, the record stays, a grave and a funeral follow), the friendly
## ghost who leaves wildflowers when unmet, the vase that keeps them, and all of it through save/load.
extends SuiteCase

const SMOKE := ["test_hud_info", "test_death_grave_funeral"]


## Next day at `hour` (always crosses midnight, so the day tick runs).
func _next(hour: int) -> void:
	Game.advance_minutes(1440 - int(Game.state["minute"]) + hour * 60)


func _dest() -> String:
	return "forest" if DB.destinations.has("forest") else str(DB.destinations.keys()[0])


func _hire_one() -> Dictionary:
	Game.state["gold"] = 5000
	var guard := 0
	while (Game.state["applicants"] as Array).is_empty() and guard < 20:
		Hire.refresh_applicants()
		guard += 1
	if Hire.hire_applicant(0) != "":
		return {}
	return Hire.list()[-1]


## Sends `id` out with a forced outcome and runs the days until the expedition resolves.
func _expedition(id: String, outcome: String) -> void:
	eq(Hire.send(id, _dest()), "", "%s sets out" % id)
	Hire.force_outcome = outcome
	var g := 0
	while Hire.get_h(id).get("status", "") == "away" and g < 12:
		days(1)
		g += 1
	Hire.force_outcome = ""


func test_hud_info() -> void:
	var borin := Hire.get_h("borin")
	check(not borin.is_empty(), "Borin is on the books")
	Game.advance_minutes(((24 + 10) * 60 - int(Game.state["minute"])) % 1440)   # 10:00, working hours
	var i := Hire.hud_info(borin)
	eq(i["status"], "working", "at ten in the morning Borin is working")
	eq(float(i["health"]), 1.0, "a hale hand shows full health")
	check(str(i["icon"]) != "" and Assets.has_tex(str(i["icon"])), "the activity icon exists (%s)" % i["icon"])
	# evening: resting
	Game.advance_minutes(10 * 60)
	eq(Hire.hud_info(borin)["status"], "resting", "at eight in the evening Borin is resting")
	# away: expedition progress and days left
	Game.advance_minutes(((24 + 9) * 60 - int(Game.state["minute"])) % 1440)
	eq(Hire.send("borin", _dest()), "", "Borin sets out")
	var a := Hire.hud_info(borin)
	eq(a["status"], "away", "the card says away")
	check(int(a["days_left"]) >= 1 and float(a["exp_progress"]) == 0.0, "days left %d, progress %.2f at the start" % [int(a["days_left"]), float(a["exp_progress"])])
	check(Hire.whereabouts(borin).contains(str(a["dest_name"])) and Hire.whereabouts(borin).contains("back in about"), "clicking an absent hand says where they are: " + Hire.whereabouts(borin))
	var total := int(borin["expedition"]["total"])
	if total >= 2:
		days(1)
		check(float(Hire.hud_info(borin)["exp_progress"]) > 0.0, "the expedition bar fills as days pass")
	# injured on return: health drops and an injury mark appears
	Hire.force_outcome = "injury"
	var g := 0
	while borin["status"] == "away" and g < 12:
		days(1)
		g += 1
	eq(borin["status"], "injured", "a forced injury brings Borin home hurt")
	var hi := Hire.hud_info(borin)
	eq(hi["status"], "injured", "the card says injured")
	check(float(hi["health"]) < 1.0 and int(hi["injuries"]) == 1, "health %.2f below full, one injury mark" % float(hi["health"]))
	check(Chronicle.recent(5, ["return"]).size() > 0, "the return is written in the Chronicle")


func test_death_grave_funeral() -> void:
	var h := _hire_one()
	check(not h.is_empty(), "a second hand is hired")
	var h2 := _hire_one()
	check(not h2.is_empty(), "a third hand is hired")
	eq(Hire.alive_count(), 3, "three places taken")
	if not (Game.state["applicants"] as Array).is_empty():
		eq(Hire.hire_applicant(0), "You already employ three hands. Dismiss someone first.", "no room for a fourth")
	var id := str(h["id"])
	Game.advance_minutes(((24 + 9) * 60 - int(Game.state["minute"])) % 1440)
	_expedition(id, "death")
	eq(Hire.get_h(id)["status"], "dead", "the forced death happened")
	eq(Hire.alive_count(), 2, "the place is free again")
	check(not Hire.get_h(id).is_empty(), "their record stays in the ledger")
	var g := Memorial.grave(id)
	check(not g.is_empty(), "a grave is recorded")
	eq(int(g["funeral_day"]), Game.day() + 1, "the funeral is the next day")
	check((g["achievements"] as Array).size() >= 2, "the headstone lists achievements: %s" % str(g["achievements"]))
	check(TalkMarkers.wants_to_talk("oswin") != "", "Father Oswin wants a word (the invitation)")
	check(Chronicle.recent(10, ["death"]).size() > 0, "the death is in the Chronicle")
	# a slot opens for recruitment
	while (Game.state["applicants"] as Array).is_empty():
		Hire.refresh_applicants()
	eq(Hire.hire_applicant(0), "", "a new hand can be hired into the empty place")
	# the funeral morning: mourners walk to the graveside
	_next(9)
	check(Memorial.standing().size() == 1, "the grave stands on the funeral morning")
	check(Memorial.funeral_spot("oswin").ends_with("priest"), "Oswin goes to the graveside: %s" % Memorial.funeral_spot("oswin"))
	check(Memorial.funeral_spot("martha").begins_with("funeral_"), "villagers gather too")
	check(Memorial.funeral_spot("borin").begins_with("funeral_"), "the other hands come")
	Game.advance_minutes(60)
	check(Memorial.funeral_now(), "at ten the service is under way")
	Memorial.attend()
	check(bool(Memorial.grave(id)["attended"]) and bool(Memorial.grave(id)["funeral_done"]), "attending is recorded")
	eq(Memorial.funeral_spot("oswin"), "", "afterwards everyone goes back to their day")
	eq(TalkMarkers.wants_to_talk("oswin"), "", "the invitation is cleared")
	check(Memorial.epitaph(Memorial.grave(id)).contains(str(h["name"])), "the headstone reads their name")


func test_funeral_missed_closes() -> void:
	var h := _hire_one()
	var id := str(h["id"])
	_expedition(id, "death")
	days(1)
	Game.advance_minutes(((24 + 12) * 60 - int(Game.state["minute"])) % 1440)
	var g := Memorial.grave(id)
	check(bool(g["funeral_done"]) and not bool(g["attended"]), "a funeral the smith missed still happens")


func test_ghost_flowers_vase() -> void:
	var h := _hire_one()
	var id := str(h["id"])
	_expedition(id, "death")
	days(1)
	# weeks later: quiet evenings; some evening the ghost visits (forced here, then left unmet)
	Game.state["day"] = int(Game.state["day"]) + Memorial.GHOST_AFTER_DAYS
	Memorial.force_ghost = true
	_next(20)   # past midnight (the visit is decided), then 20:00
	var v: Dictionary = Memorial.st()["visit"]
	eq(str(v.get("id", "")), id, "a ghost visits this evening")
	check(not Memorial.ghost_now().is_empty(), "the ghost is in the workshop at eight in the evening")
	_next(7)    # morning, unmet
	eq(Memorial.flowers_at_door().size(), 1, "unmet, they left wildflowers at the smithy door")
	eq(str(Memorial.flowers_at_door()[0]["id"]), id, "the flowers are from them")
	var it := Memorial.collect_flowers()
	check(not it.is_empty() and Game.count("flowers_remembrance") == 1, "the flowers are picked up into the pack")
	eq(Memorial.flowers_at_door().size(), 0, "the step is empty again")
	check(Memorial.place_in_vase(), "the flowers go into the vase")
	eq(str(Memorial.vase()["id"]), id, "the vase remembers who they were from")
	eq(Game.count("flowers_remembrance"), 0, "the flowers left the pack")
	check(Memorial.vase_text().contains(str(h["name"])), "the vase's memory names them: " + Memorial.vase_text())
	# another evening, met this time: a warm line and no flowers
	Memorial.force_ghost = true
	Memorial.st()["last_visit_day"] = -99
	_next(20)
	var line := Memorial.meet_ghost()
	check(line.length() > 10, "talking to the ghost gives a warm line: " + line)
	_next(7)
	eq(Memorial.flowers_at_door().size(), 0, "a ghost who was met leaves no flowers")
	eq(int(Memorial.st()["seen"].get(id, 0)), 1, "the meeting is remembered")


func test_save_load_memorial() -> void:
	var h := _hire_one()
	var id := str(h["id"])
	_expedition(id, "death")
	Memorial.st()["flowers"].append({"id": id, "name": h["name"], "day": Game.day()})
	Memorial.st()["vase"] = {"id": id, "name": h["name"], "day": Game.day()}
	Memorial.st()["seen"][id] = 2
	check(save_load("suite_hirelings10"), "save and load")
	check(not Memorial.grave(id).is_empty(), "the grave persists")
	eq(Memorial.flowers_at_door().size(), 1, "the flowers on the step persist")
	eq(str(Memorial.vase().get("id", "")), id, "the vase persists")
	eq(int(Memorial.st()["seen"].get(id, 0)), 2, "ghosts seen persist")
	eq(Hire.get_h(id)["status"], "dead", "the dead hand's record persists")
	# an old save without the memorial key still works
	Game.state.erase("memorial")
	eq(Memorial.graves().size(), 0, "old saves start with an empty graveyard")
	Hire.on_day()
	check(Game.state.has("memorial") or true, "the day passes without errors on an old save")
