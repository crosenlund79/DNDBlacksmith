## Rendered play-test phase "living_rl" (The Living Realm 3a, adventurers): a seeded campaign, three weeks of
## village life (companies setting out together, friendships, a retirement, a newcomer), then the roster with
## company lines, the Most Wanted board and its Legends page (companies, the retired, Chronicle lines), a company
## member's sheet (left column, Relationships with the company roll and bonds, Career with personal goals) and
## the save slot with its world seed. Called from tests/playtest.gd (phase_living_rl).
extends RefCounted

var pt: Node


func _open_dossier(id: String, tab: String, name: String) -> void:
	Events.open_panel.emit("dossier", {"id": id})
	await pt.wait(0.7)
	pt.expect(pt.panel() is DossierPanel, "living: %s's sheet opens" % id)
	if pt.panel() is DossierPanel:
		await pt.click(tab, pt.panel())
		await pt.wait(0.5)
	await pt.shot(name)


func run(p: Node) -> void:
	pt = p
	Living.next_seed = 5
	await pt.click("New Game")
	await pt.wait(2.5)
	pt.expect(Living.world_seed() == 5, "living: the campaign's world seed is 5")
	pt.expect(not Companies.active().is_empty(), "living: a company exists on day 1 (%s)" % Companies.signature())
	pt.note("roster: " + ", ".join(Adv.all().keys()))
	# three weeks of village life
	for d in 20:
		Game.advance_minutes(1440)
	await pt.wait(0.5)
	# a veteran hangs up their sword; a newcomer arrives to take the empty chair
	var vet := {}
	for a in Adv.all().values():
		if Living.is_reserve(str(a["id"])) and str(a["status"]) == "in_town" and not Companies.of(str(a["id"])).is_empty():
			vet = a
	if vet.is_empty():
		for a in Adv.all().values():
			if Living.is_reserve(str(a["id"])) and str(a["status"]) == "in_town":
				vet = a
	if not vet.is_empty():
		Living.retire(vet, "wealth", 1)
		pt.expect(str(vet["status"]) == "retired", "living: %s retired" % vet["name"])
	Living.st()["last_arrival"] = -10
	var nc := Living.newcomer()
	pt.expect(not nc.is_empty(), "living: a newcomer arrived (%s)" % nc.get("name", "none"))
	Game.advance_minutes(60)
	await pt.wait(0.4)
	var co: Dictionary = Companies.active()[0] if not Companies.active().is_empty() else {}
	pt.expect(not co.is_empty() and int(co.get("trips", 0)) > 0, "living: a company has been out together (%s)" % Companies.summary(co) if not co.is_empty() else "none")
	# the roster: company lines on the cards
	await pt.press("panel_adventurers")
	await pt.wait(0.8)
	pt.expect(pt.panel() is AdventurersPanel, "living: J opens the roster")
	await pt.shot("living_rl_roster")
	pt.close_panel()
	await pt.wait(0.3)
	# the Most Wanted board: company names under the whereabouts
	Events.open_panel.emit("wanted", {})
	await pt.wait(0.8)
	await pt.shot("living_rl_wanted")
	await pt.click("Legends & History", pt.panel())
	await pt.wait(0.6)
	await pt.shot("living_rl_legends")
	pt.close_panel()
	await pt.wait(0.3)
	# a company member's sheet
	if not co.is_empty():
		var lead := str(co["leader"])
		await _open_dossier(lead, "Relationships", "living_rl_sheet_relations")
		await pt.click("Career", pt.panel())
		await pt.wait(0.5)
		await pt.shot("living_rl_sheet_career")
		await pt.click("Overview", pt.panel())
		await pt.wait(0.5)
		await pt.shot("living_rl_sheet_overview")
		pt.close_panel()
		await pt.wait(0.3)
	if not vet.is_empty():
		await _open_dossier(str(vet["id"]), "Relationships", "living_rl_sheet_retired")
		pt.close_panel()
		await pt.wait(0.3)
	# the save slot shows the world seed (a private save folder: the user data folder is shared)
	Saves.dir = Saves.dir + "living_rl/"
	DirAccess.make_dir_recursive_absolute(Saves.dir)
	pt.expect(Saves.save("slot_3"), "living: saved to slot 3")
	Events.open_panel.emit("saves", {"mode": "load"})
	await pt.wait(0.7)
	await pt.shot("living_rl_saves")
	pt.close_panel()
	pt.note("chronicle: " + " | ".join(Chronicle.recent(8, ["company", "retired", "arrival", "bond", "goal"]).map(func(c): return str(c["text"]))))
