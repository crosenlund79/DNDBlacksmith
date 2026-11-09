## Rendered play-test phase "sponsor_rl" (The Living Realm 4, sponsored expeditions): a smith-made blade lies lost
## at the Barrow Fields; the smith opens the Hirelings ledger, chooses the site, the lost blade and an adventurer,
## makes a low offer, sees the counter-offer, agrees; the party leaves at 08:00 and is watched in the observer with
## the sponsorship line; when they are home the ledger shows the result, the returns chest is opened, and the blade's
## inspection shows its history with "recovered". Called from tests/playtest.gd (phase_sponsor_rl).
extends RefCounted

var pt: Node


func _section() -> SponsorSection:
	return pt.panel().find_child("SponsorSection", true, false) as SponsorSection if pt.panel() != null else null


func _open_ledger(name: String) -> void:
	Events.open_panel.emit("hirelings", {})
	await pt.wait(0.8)
	pt.expect(pt.panel() is HirelingsPanel, "sponsor: the Hirelings ledger opens")
	pt.expect(_section() != null, "sponsor: it has the Sponsor adventurers section")
	await pt.shot(name)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	await pt.advance_to(10, 0)
	# a smith-made blade, lost with a fallen adventurer at the ossuary of the Barrow Fields
	var fallen := {}
	var hero := {}
	for a in Adv.all().values():
		var id := str(a["id"])
		if id == "mira" or not Companies.of(id).is_empty() or str(a.get("status", "")) != "in_town":
			continue
		if fallen.is_empty():
			fallen = a
		elif hero.is_empty():
			hero = a
	pt.expect(not fallen.is_empty() and not hero.is_empty(), "sponsor: two lone adventurers in town")
	if hero.is_empty():
		return
	var blade := Items.make("sword_steel", {"quality": 104.0})
	Provenance.forged(blade)
	Provenance.transfer(blade, str(fallen["id"]), "sold", "brindlewick")
	fallen["equipment"]["weapon"] = blade
	fallen["status"] = "dead"
	WorldSites.leave_gear(fallen, "barrow_fields", "rows", "fell with %s" % fallen["name"])
	var uid := int(blade["uid"])
	# the hero: seasoned and rested
	Expeditions.ensure(hero)
	hero["level"] = 14
	hero["hp_max"] = Expeditions.hp_max(hero)
	hero["hp"] = hero["hp_max"]
	hero["fatigue"] = 0.0
	hero["equipment"]["weapon"] = Items.make("sword_steel", {"quality": 100.0})
	Game.add_gold(1400, "dev", "play-test purse")
	# the form: Barrow Fields → the lost blade → the hero, a low first offer
	var objs := Sponsor.objectives("barrow_fields")
	SponsorSection.expanded = true
	SponsorSection.sel_site = "barrow_fields"
	for i in objs.size():
		if str(objs[i]["kind"]) == "lost" and int(objs[i]["uid"]) == uid:
			SponsorSection.sel_obj = i
	SponsorSection.sel_party = "adv:" + str(hero["id"])
	var ask := int(Sponsor.asking(objs[SponsorSection.sel_obj], [hero["id"]])["ask"])
	SponsorSection.terms = {"fee": int(ask * 0.45 / 5.0) * 5, "bonus": int(ask * 0.3 / 5.0) * 5, "share": 0}
	SponsorSection.last_answer = {}
	await _open_ledger("sprl_section")
	# the offer and their answer
	pt.expect(await pt.click("Make the offer", pt.panel()), "sponsor: the offer is made from the ledger")
	await pt.wait(0.6)
	var t := Sponsor.talk()
	pt.expect(str(t.get("answer", {}).get("verdict", "")) == "counter", "sponsor: they counter (%s)" % str(t.get("answer", {}).get("reason", SponsorSection.last_answer.get("reason", ""))))
	await pt.shot("sprl_negotiation")
	pt.expect(await pt.click("Agree", pt.panel()), "sponsor: agree to their terms")
	await pt.wait(0.6)
	var open := Sponsor.open()
	pt.expect(open.size() == 1 and str(open[0]["status"]) == "contracted", "sponsor: contracted, preparing for the morning")
	await pt.shot("sprl_contracted")
	pt.close_panel()
	if open.is_empty():
		return
	var sid := str(open[0]["id"])
	# the morning: they leave; watch them in the observer
	await pt.advance_to(8, 0)
	Game.advance_minutes(5)
	var sp := Sponsor.get_s(sid)
	pt.expect(str(sp["status"]) == "under_way", "sponsor: under way at 08:00")
	var guard := 0
	while str(sp["status"]) == "under_way" and not bool(sp.get("reached", false)) and guard < 40:
		Game.advance_minutes(20)
		guard += 1
	Events.open_panel.emit("observe", {"id": str(sp["exp"])})
	await pt.wait(1.2)
	pt.expect(pt.panel() is ObserverPanel, "sponsor: the observer opens on the sponsored expedition")
	await pt.shot("sprl_observer")
	pt.close_panel()
	await pt.wait(0.3)
	# home again
	guard = 0
	while str(sp["status"]) == "under_way" and guard < 60:
		Game.advance_minutes(60)
		guard += 1
	pt.expect(str(sp["status"]) == "done", "sponsor: the sponsorship concluded (%s)" % sp.get("outcome", ""))
	pt.note("result: " + str(sp["result"].get("text", "")))
	await _open_ledger("sprl_result")
	pt.close_panel()
	await pt.wait(0.3)
	# the returns shelf: the chest with the blade, then its history
	var chest := {}
	for c in Game.state["returns"]:
		for it in c.get("contents", []):
			if int(it.get("uid", -1)) == uid:
				chest = c
	pt.expect(str(sp["outcome"]) != "success" or not chest.is_empty(), "sponsor: the blade waits on the returns shelf")
	if chest.is_empty():
		return
	Events.open_panel.emit("loot", {"uid": int(chest["uid"])})
	await pt.wait(2.5)
	await pt.shot("sprl_delivered")
	await pt.click("Take everything", pt.panel())
	await pt.wait(0.5)
	pt.expect(not Game.find_uid(uid).is_empty(), "sponsor: the recovered blade is in the stores, same uid")
	Events.open_panel.emit("item", {"uid": uid, "tab": "History"})
	await pt.wait(0.8)
	await pt.shot("sprl_blade_history")
