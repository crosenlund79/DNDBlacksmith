## Rendered play-test phase "lw_foundation" (The Living Workshop — the FOUNDATION worker: B1 professional foundations).
## What the player sees: applicants on the notice board, each with a profession; the resonance pedestal's Design list
## saying who master-grade rune work needs ("Needs a runesmith (Runecraft 6) — the smith's runecraft is basic (1)") while
## basic rune work stays open to the smith; a master runesmith taken on (the Workshop Ledger names their profession);
## the same reason now naming who can make it; the Concord runestone queued for the runesmith, the runesmith at the rune
## station, and the finished stone with the runesmith as its maker; the skill tree's master rune node met by the
## runesmith's level; the Help reference on professions. Screenshots: lwf_*.
## Called from tests/playtest.gd (phase_lw_foundation).
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _text(root: Node, needle: String) -> bool:
	return root != null and pt.find_label_containing(root, needle) != null


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Shop.customers().clear()
	Game.state["gold"] = 8000
	await pt.grant_full_workshop()   # every room and station; the workshop knows every Design (the tree)
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	await pt.advance_to(9, 0)
	await _applicants()
	await _station_before()
	await _take_on()
	await _station_after()
	await _runesmith_works()
	await _tree_seam()
	await _reference()


# ---------------------------------------------------------------- 1. applicants with professions
func _applicants() -> void:
	pt.note(ApprenticeDev.unlock())
	# a week's notice with three different professions on it
	var g := 0
	while g < 60:
		Apprentices.refresh_applicants()
		var profs := {}
		for a in Apprentices.applicants():
			profs[str(a.get("profession", ""))] = true
		if Apprentices.applicants().size() >= 3 and profs.size() >= 3:
			break
		g += 1
	for a in Apprentices.applicants():
		pt.note("   applicant %s — %s (%s)" % [a["name"], a.get("profession", "?"), ApprenticeUI.levels_text(a.get("levels", {}))])
	Events.open_panel.emit("notice", {"tab": "apprentices"})
	await pt.wait(0.8)
	var first := str(Apprentices.applicants()[0].get("profession", ""))
	pt.expect(_text(pt.panel(), Workers.profession_name(first)), "lw_foundation: the notice board names each applicant's profession (%s)" % Workers.profession_name(first))
	await pt.shot("lwf_applicants_professions")
	await pt.click("Take on")
	await pt.wait(0.5)
	pt.expect(not Apprentices.staff().is_empty() and str(Apprentices.staff()[0].get("profession", "")) == first, "lw_foundation: the hired apprentice keeps their profession")
	await pt.close_panel()


# ---------------------------------------------------------------- 2. the station panel: who the work needs
func _open_station(sid: String, avail := "locked", query := "") -> void:
	StationPanel.avail = avail   # "locked": only the Designs the smith cannot start, so the reasons are in view
	StationPanel.cat = "all"
	StationPanel.everywhere = false
	StationPanel.query = query
	Events.open_panel.emit("station", {"id": sid})
	await pt.wait(0.9)


func _station_before() -> void:
	# the Concord runestone's materials are in the stores: only competence stands between the smith and the work
	for d in DB.recipe("concord_runestone")["inputs"]:
		Game.add_item(Items.make(str(d), {"qty": int(DB.recipe("concord_runestone")["inputs"][d])}), false)
	pt.expect(Crafting.recipe_locked_reason("original_runestone") == "", "lw_foundation: basic rune work (an original runestone) stays open to the smith")
	await _open_station("resonance_pedestal")
	pt.expect(_text(pt.panel(), "Needs a runesmith"), "lw_foundation: the Concord runestone says it needs a runesmith")
	pt.expect(_text(pt.panel(), "runecraft is basic"), "lw_foundation: …and that the smith's runecraft is basic")
	await pt.shot("lwf_station_needs_runesmith")
	await pt.close_panel()
	await _open_station("resonance_pedestal", "all", "concord")
	await pt.shot("lwf_station_concord_with_materials")
	await pt.close_panel()
	StationPanel.avail = "all"
	StationPanel.query = ""


# ---------------------------------------------------------------- 3. a master runesmith joins
var rune := {}


func _take_on() -> void:
	rune = Apprentices.dev_take_on("runesmith", 8, "master", "Edda Vell")   # stand-in for a master's years at the bench
	pt.expect(not rune.is_empty(), "lw_foundation: a master runesmith joins the workshop")
	if rune.is_empty():
		return
	pt.note("   %s: %s" % [rune["name"], JSON.stringify(Workers.profile(rune))])
	Events.open_panel.emit("workshop", {})
	await pt.wait(0.9)
	pt.expect(_text(pt.panel(), "Runesmith · Master"), "lw_foundation: the Workshop Ledger names the runesmith's profession and rank")
	await pt.shot("lwf_ledger_runesmith")
	await pt.close_panel()


func _station_after() -> void:
	if rune.is_empty():
		return
	await _open_station("resonance_pedestal")
	pt.expect(_text(pt.panel(), "Edda Vell (runesmith) can make it"), "lw_foundation: the reason now names who can make it")
	await pt.shot("lwf_station_names_specialist")
	await pt.close_panel()
	StationPanel.avail = "all"
	StationPanel.query = ""


# ---------------------------------------------------------------- 4. the specialist does what the smith cannot
func _runesmith_works() -> void:
	if rune.is_empty():
		return
	var t := Apprentices.add_task("craft", {"recipe": "concord_runestone", "assignee": str(rune["id"]), "priority": 3})
	pt.expect(not t.has("error"), "lw_foundation: the Concord runestone is queued for the runesmith (%s)" % t.get("error", ""))
	if t.has("error"):
		return
	if Game.hour() < 8 or Game.hour() >= 16:
		await pt.advance_to(8, 5)   # into a shift (it is mid-morning already when the phase gets here)
	var g := 0
	while str(t.get("station", "")) == "" and g < 40 and not str(t["state"]) in ["done", "failed", "cancelled"]:
		Game.advance_minutes(5)
		g += 1
	var sid := str(t.get("station", ""))
	pt.note("   the runesmith works at: '%s' (%s)" % [sid, Apprentices.current(rune).get("activity", "")])
	if sid != "":
		var w := _w()
		await pt.tp(w.station_pos(sid) + Vector2(0, 90))
		w.camera.zoom = Vector2(0.9, 0.9)
		w.camera.reset_smoothing()
		await pt.wait(1.5)
		await pt.shot("lwf_runesmith_at_station")
		w.camera.zoom = Vector2.ONE
	Events.open_panel.emit("workshop", {})
	await pt.wait(0.9)
	pt.expect(_text(pt.panel(), "Concord"), "lw_foundation: the ledger shows the runesmith on the Concord runestone")
	await pt.shot("lwf_ledger_runesmith_at_work")
	await pt.close_panel()
	g = 0
	while not str(t["state"]) in ["done", "failed", "cancelled"] and g < 6 * 96:
		Game.advance_minutes(15)
		g += 1
	pt.expect(str(t["state"]) == "done" and not (t["made"] as Array).is_empty(), "lw_foundation: the runesmith finished it (%s %s)" % [t["state"], t.get("blocker", "")])
	if (t["made"] as Array).is_empty():
		return
	var it := Game.find_uid(int(t["made"][0]))
	pt.expect(str(it.get("craft", {}).get("maker", "")) == str(rune["id"]), "lw_foundation: the runesmith is the stone's maker")
	Events.open_panel.emit("craft_result", {"item": it, "fresh": false})
	await pt.wait(0.9)
	pt.expect(_text(pt.panel(), "Edda"), "lw_foundation: the result names the runesmith")
	await pt.shot("lwf_concord_by_runesmith")
	await pt.close_panel()


# ---------------------------------------------------------------- 5. the skill tree: another craft's node met by a specialist
func _tree_seam() -> void:
	SkillTree.learned().erase("r_master")
	Events.open_panel.emit("skilltree", {"select": "r_master"})
	await pt.wait(1.0)
	var ok := SkillTree.requirements("r_master").any(func(x): return str(x["kind"]) == "skill" and bool(x["ok"]) and str(x["text"]).contains("Edda"))
	pt.expect(ok, "lw_foundation: the master rune node's Runecraft 6 is met by the runesmith")
	pt.expect(_text(pt.panel(), "Edda Vell: 8"), "lw_foundation: the tree shows whose level meets it")
	await pt.shot("lwf_tree_node_met_by_runesmith")
	await pt.close_panel()
	SkillTree.unlock_node_force("r_master")


# ---------------------------------------------------------------- 6. the Help reference
func _reference() -> void:
	var hits := Reference.search("profession")
	pt.expect(not hits.is_empty(), "lw_foundation: the Help reference explains professions (%d hits)" % hits.size())
	Events.open_panel.emit("help", {"topic": "professions"})
	await pt.wait(1.0)
	pt.expect(_text(pt.panel(), "Professions and competence"), "lw_foundation: Help finds the professions entry")
	await pt.shot("lwf_help_professions")
	await pt.close_panel()
