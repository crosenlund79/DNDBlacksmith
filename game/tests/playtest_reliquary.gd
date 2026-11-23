## Rendered play-test phase "reliquary" (R6 "Legacy: the Reliquary & Heirs"): Grimhold, the Last Hammer, borne by
## Garrick, shattered in his last fight and carried home; it rests in the Reliquary (the case refuses a working piece);
## the panel shows its heir from the records — Martha, his mother — with the evidence; her letter, the smith's answer,
## her terms (restored, it goes home); the restoration at the anvil with her consent rite; the piece leaves the forge for
## her home; a save/load keeps everything traceable. Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.wait(0.7)
	await pt.shot(name)


func _days(n: int) -> void:
	Game.advance_minutes(1440 * n)
	await pt.wait(0.8)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Game.state["gold"] = 20000
	pt.expect(Property.buy_station(Reliquary.STATION) == "" or Property.is_owned_station(Reliquary.STATION), "reliquary: the Reliquary is bought")
	var plan := Property.plan_copy()
	if not Reliquary.installed():
		var why := Property.auto_place(plan, Reliquary.STATION)
		pt.expect(why == "" and Property.commit(plan) == "", "reliquary: the case is set up in the smithy (%s)" % why)
	pt.main.call("rebuild_world")
	await pt.advance_to(10, 0)
	# the premise, from real records: Garrick bore Grimhold, it earned Epic, he fell, his companions carried it home
	var g := Items.make("grimhold", {"quality": 94.0})
	Uniques.register(g, "loot")   # as Loot mints it: found, not forged at the Ironhand forge
	Provenance.transfer(g, "garrick", "bought", "brindlewick")
	Recognition.grant_epic(g, "struck down the Barrow King", "garrick", "boss")
	var a := Adv.get_a("garrick")
	a["status"] = "dead"
	a["died_day"] = Game.day()
	a["death_event"] = Lore.record("death", "Garrick Stone fell at the Barrow Fields.", {"actors": ["garrick"], "importance": 3})
	GearDepth.disable(g, "shattered in Garrick's last fight")
	Lore.push_cause(str(a["death_event"]))
	Provenance.transfer(g, Provenance.SMITH_ID, "recovered", "brindlewick", "Garrick's companions carried Grimhold home to the forge.")
	Lore.pop_cause()
	Game.add_item(g, false)
	Social.ensure("martha")["aff"] = 45.0
	var uid := int(g["uid"])
	# a working sword is refused; the shattered relic is laid in through the panel
	var sound := Items.make("sword_steel", {"quality": 90.0})
	Game.add_item(sound, false)
	pt.expect(Reliquary.enshrine(int(sound["uid"])) != "", "reliquary: a working sword is refused — it belongs in the world")
	Events.open_panel.emit("reliquary", {"uid": uid})
	await _shot("reliquary_before")
	pt.expect(pt.panel() is ReliquaryPanel, "reliquary: the Reliquary panel opens")
	var en: Button = pt.panel().find_child("Enshrine", true, false) if pt.panel() != null else null
	pt.expect(en != null and not en.disabled, "reliquary: the relic can be laid in")
	if en != null:
		en.pressed.emit()
		await pt.wait(0.6)
	pt.expect(not Reliquary.held(uid).is_empty(), "reliquary: Grimhold rests in the case")
	var heir: Node = pt.panel().find_child("Heir_martha", true, false) if pt.panel() != null else null
	pt.expect(heir != null, "reliquary: Martha, Garrick's mother, is shown as heir with the record behind her")
	await _shot("reliquary_case_and_heir")
	await pt.close_panel()
	# her letter comes; the smith writes back
	await _days(Reliquary.LETTER_AFTER + 1)
	pt.expect(Reliquary.letters().any(func(l): return int(l["uid"]) == uid and str(l["kind"]) == "request"), "reliquary: Martha writes to ask for its restoration")
	Events.open_panel.emit("reliquary", {"uid": uid})
	await pt.wait(0.6)
	var wb: Button = pt.panel().find_child("WriteHeir", true, false) if pt.panel() != null else null
	pt.expect(wb != null, "reliquary: the smith can write to her")
	if wb != null:
		wb.pressed.emit()
	await _shot("reliquary_letter_sent")
	await pt.close_panel()
	await _days(1)
	pt.expect(str(Reliquary.claim(uid).get("answer", "")) == "return", "reliquary: her terms — restored, it goes home (%s)" % str(Reliquary.claim(uid).get("answer", "")))
	Events.open_panel.emit("reliquary", {"uid": uid})
	await _shot("reliquary_terms")
	await pt.close_panel()
	# restoration at the anvil
	pt.expect(Reliquary.take_out(uid) == "", "reliquary: taken out for restoration")
	for d in Refinement.inputs_for(Game.find_uid(uid), "restore"):
		Game.add_item(Items.make(str(d), {"qty": 6}), false)
	Events.open_panel.emit("refine", {"station": "anvil", "uid": uid, "action": "restore"})
	await _shot("reliquary_restore_plan")
	var rk: Node = pt.panel().find_child("Risk", true, false) if pt.panel() != null else null
	pt.expect(rk != null and str((rk as RichTextLabel).text).contains("never lost"), "reliquary: the restoration's risk is stated (the piece is never lost)")
	await pt.close_panel()
	var r := Refinement.perform(uid, "restore", 88.0, {"station": "anvil"})
	pt.expect(str(r.get("outcome", "")) == "success", "reliquary: restored with her consent (%s)" % str(r.get("text", "")))
	var after := ItemRegistry.find(uid)
	pt.expect(not after.is_empty() and str(ItemRegistry.where(uid).get("holder", "")) == "holdings" and Provenance.owner_id(after) == "martha",
		"reliquary: Grimhold went home to Martha — the smith keeps nothing")
	pt.expect(Reliquary.ancestral_state(after) == "awake", "reliquary: its ancestral nature woke with the rite of its line")
	Events.open_panel.emit("item", {"uid": uid, "tab": "History"})
	await _shot("reliquary_history")
	await pt.close_panel()
	pt.expect(Saves.save("pt_reliquary") and Saves.load_slot("pt_reliquary"), "reliquary: saved and loaded")
	await pt.wait(1.5)
	pt.expect(Provenance.owner_id(ItemRegistry.find(uid)) == "martha" and Uniques.audit().is_empty(), "reliquary: after loading Grimhold is still Martha's, one authentic piece")
	pt.note("reliquary: %d events in Grimhold's history" % Lore.of_item(uid).size())
