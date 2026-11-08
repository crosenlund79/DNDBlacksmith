## Scenario C — employees and resources: recruit and assign employees, send them out, collect what they bring
## home, see them gain experience, and use the resulting materials in crafting.
extends SuiteCase

const SMOKE := ["test_recruit_assign_expedition"]


func _collect_returns() -> int:
	var n := 0
	for c in (Game.state["returns"] as Array).duplicate():
		for it in c.get("contents", []):
			Game.add_item(it, false)
			n += 1
		(Game.state["returns"] as Array).erase(c)
	return n


func test_recruit_assign_expedition() -> void:
	Game.state["gold"] = 3000
	if Game.state["applicants"].is_empty():
		Hire.refresh_applicants()
	var guard := 0
	while (Game.state["applicants"] as Array).is_empty() and guard < 10:
		Hire.refresh_applicants()
		guard += 1
	var n0 := Hire.list().size()
	eq(Hire.hire_applicant(0), "", "recruit an applicant from the notice")
	eq(Hire.list().size(), n0 + 1, "the new hand is on the books")
	var h: Dictionary = Hire.list()[-1]
	check(h.has("potential") and Hire.potential_word(h).contains("unknown"), "their potential is hidden at first")
	# assign work: all smithing
	var alloc := {}
	for s in DB.work_skills:
		alloc[s] = 0
	alloc["smithing"] = 100
	check(Hire.set_alloc(h["id"], alloc), "work allocation set (100% smithing)")
	var xp0 := int(h["skills"]["smithing"]["xp"]) + int(h["skills"]["smithing"]["lvl"]) * 1000
	for hr in 8:
		Hire.work_hour(9 + hr)
	var xp1 := int(h["skills"]["smithing"]["xp"]) + int(h["skills"]["smithing"]["lvl"]) * 1000
	check(xp1 > xp0, "working gains experience")
	# expedition: Borin to the forest, resolved by the day tick
	var borin := Hire.get_h("borin")
	check(not borin.is_empty(), "Borin works for the smith")
	var dest := "forest" if DB.destinations.has("forest") else str(DB.destinations.keys()[0])
	eq(Hire.send("borin", dest), "", "Borin sets out for %s" % dest)
	var g := 0
	while borin["status"] == "away" and g < 10:
		days(1)
		g += 1
	check(borin["status"] != "away", "the expedition resolves within days")
	var got := _collect_returns()
	check(got > 0 or borin["status"] == "dead" or borin["status"] == "injured", "what they brought home is collected into the stores (%d items)" % got)
	# the materials feed crafting: smelt whatever ore is now in store
	if Game.count("ore_iron") >= 2 and Game.count("coal") >= 1:
		var it := craft("smelt_iron", 95.0)
		check(not it.is_empty(), "collected ore is smelted at the forge")


func test_wages_and_difficulty() -> void:
	Game.state["gold"] = 1000
	var g0 := Game.gold()
	Hire.on_day()
	check(Game.gold() < g0, "wages are paid each day")
