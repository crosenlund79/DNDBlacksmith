## Rendered play-test phase "steward_s1" (Milestone S1, Steward Mode UI): a modest workshop (two apprentices, gold,
## materials); the hand-over with its confirmation and the standing instructions; the forge handed over (the status
## plate, the smith away, a world action refused with its reason, panels that let time run); the steward at work for
## real hours (its own actions on the plate and in its panel, the Workshop Ledger looked at while away); a patron's
## sealed letter from a real contract offer; taking the workshop back → While You Were Away; the sealed envelope → open
## → the actual offer at the Project Bench; save while the steward runs → load → mode off and the closed session's
## report once. Called from tests/playtest.gd (phase_steward_s1). Screenshots are named s1_*.
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _seat() -> void:
	# customers who set out reach a seat (the world does this when the figure arrives; big clock jumps outrun them)
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _hours(n: int) -> void:
	for i in n:
		Game.advance_minutes(60)
		_seat()
		await pt.wait(0.15)


func _plate() -> StewardPlate:
	return pt.U().steward_plate


func _scroll_down(root: Node, frac := 1.0) -> void:
	for sc in root.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		s.scroll_vertical = int(s.get_v_scroll_bar().max_value * frac)
	await pt.wait(0.3)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w := _w()
	# ---- a modest workshop: Smithing 6, a second workshop room, two apprentices, gold and materials
	var guard := 0
	while Game.player_level("smithing") < 6 and guard < 200:
		Game.grant_player_xp("smithing", SkillSys.xp_needed(Game.player_level("smithing") + 1))
		guard += 1
	Game.state["gold"] = 2400
	(Game.state["hirelings"] as Array).clear()
	w._update_schedules(true)
	Property.dev_grant_unit("cobbler")
	pt.note(ApprenticeDev.unlock())
	Apprentices.refresh_applicants()
	while Apprentices.applicants().size() < 2:
		ApprenticeDev.add_applicant()
	pt.expect(Apprentices.hire(0) == "" and Apprentices.hire(0) == "", "s1: two apprentices hired")
	var a0: Dictionary = Apprentices.staff()[0]
	a0["rank"] = "apprentice"
	a0["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	a0["works"] = 6
	for pair in [["ingot_iron", 6], ["leather_cured", 4], ["coal", 8]]:
		Game.add_item(Items.make(pair[0], {"qty": pair[1]}), false)
	# a counter commission the workshop can make (the shape Shop.accept_part leaves on the board)
	var adv := ""
	for id in Adv.all().keys():
		if str(Adv.get_a(str(id))["status"]) == "in_town" and not Shop.refuses(str(id)):
			adv = str(id)
			break
	var oid := "ord_%d" % Game.new_uid()
	if adv != "":
		Shop.orders().append({"id": oid, "npc": adv, "slot": "weapon", "stat": "attack", "min": 0, "tier": 1, "def": "sword_short",
			"recipe": "iron_shortsword", "reward": 70, "deadline": Game.day() + 4, "status": "open", "placed": Game.day(), "priority": "quality"})
	await pt.advance_to(8, 0)
	await pt.tp(w.spots.get("smithy_bag", w.player.position) + Vector2(0, -80))
	await pt.wait(1.0)
	# ---- the hand-over: confirmation and the instructions in brief (N)
	await pt.press("panel_steward")
	await pt.wait(0.5)
	pt.expect(pt.panel() is StewardPanel, "s1: N opens the steward panel")
	pt.expect(pt.find_label_containing(pt.panel(), "nothing happens while the game is closed") != null, "s1: the confirmation says nothing happens while the game is closed")
	await pt.shot("s1_handover")
	# ---- the standing instructions
	await pt.click("Standing instructions")
	await pt.wait(0.5)
	await pt.shot("s1_instructions")
	await _scroll_down(pt.panel())
	await pt.shot("s1_instructions_lower")
	# a refusal shown with the engine's reason: a piece in hand
	await pt.close_panel()
	Crafting.start("iron_shortsword")
	Events.open_panel.emit("steward", {})
	await pt.wait(0.5)
	var ho: Button = pt.find_button(pt.panel(), "Hand over the forge")
	pt.expect(ho == null and pt.find_label_containing(pt.panel(), "Not now:") != null, "s1: mid-craft the hand-over is refused with the reason")
	await pt.shot("s1_handover_refused")
	await pt.close_panel()
	Crafting.cancel()
	# ---- hand over (from the Workshop Ledger, Y)
	await pt.press("panel_workshop")
	await pt.wait(0.6)
	pt.expect(pt.panel() is WorkshopPanel, "s1: Y opens the Workshop Ledger")
	await pt.click("Hand over to the steward")
	await pt.wait(0.6)
	pt.expect(pt.panel() is StewardPanel, "s1: the ledger leads to the hand-over")
	await pt.click("Hand over the forge")
	await pt.wait(1.6)
	pt.expect(Steward.is_active() and Steward.smith_away(), "s1: the steward runs the forge")
	pt.expect(_plate().plate.visible, "s1: the status plate is shown")
	# S2 supersedes "the smith's miniature fades away": he keeps working under the steward, on its autopilot
	pt.expect(w.player.sprite.modulate.a > 0.9 and Steward.smith_away(), "s1: the smith stays in the world, working under the steward (S2)")
	await pt.shot("s1_plate_away")
	# the smith is away: a world action is refused with the reason; the stores do not open
	var toasts: Array = []
	var cb := func(t: String, _k: String): toasts.append(t)
	Events.toast.connect(cb)
	await pt.press("inventory")
	await pt.wait(0.3)
	pt.expect(pt.panel() == null and toasts.any(func(t): return str(t).contains("You are away")), "s1: the stores are refused while away, with the reason")
	var e: Dictionary = pt.find_entry("station", "anvil")
	if not e.is_empty():
		w.interact(e)
	await pt.wait(0.3)
	Events.toast.disconnect(cb)
	pt.expect(pt.panel() == null, "s1: the anvil cannot be used while away")
	await pt.shot("s1_away_refused")
	# ---- the steward at work: real hours pass (speed ×4 for a moment of real-time running too)
	Game.set_speed(4)
	var m0 := Game.now()
	await pt.wait(1.5)
	pt.expect(Game.now() > m0, "s1: time runs while the steward works")
	await _hours(5)
	await pt.wait(0.8)
	await pt.shot("s1_plate_running")
	# a panel opened while the steward runs does not stop the clock
	await pt.click("Details", _plate())
	await pt.wait(0.4)
	pt.expect(pt.panel() is StewardPanel and Game.ui_blockers == 0, "s1: the steward panel opens without stopping time")
	var m1 := Game.now()
	await pt.wait(1.2)
	pt.expect(Game.now() > m1, "s1: the clock keeps running with the panel open")
	await pt.shot("s1_status_panel")
	await pt.close_panel()
	await pt.press("panel_workshop")
	await pt.wait(0.6)
	pt.expect(pt.panel() is WorkshopPanel, "s1: the Workshop Ledger opens for a look while away")
	await pt.shot("s1_workshop_away")
	await pt.close_panel()
	# a patron's letter arrives (the same offer Contracts.on_day writes): the Royal Household — a sealed letter
	var c := Contracts.make_offer("queens_guard")
	await _hours(4)
	await _hours(14)
	pt.expect(Steward.letters().size() >= 1, "s1: the Royal Household's letter is sealed (%d letters)" % Steward.letters().size())
	var by_kind: Dictionary = Steward.st()["acc"]["by_kind"]
	pt.note("s1: steward decisions so far %s" % JSON.stringify(by_kind))
	pt.expect(int(Steward.st()["acc"]["decisions"]) > 0, "s1: the steward acted (%d decisions)" % int(Steward.st()["acc"]["decisions"]))
	await pt.shot("s1_plate_letter")
	Game.set_speed(1)
	# ---- take the workshop back → While You Were Away
	await pt.click("Take the workshop back", _plate())
	await pt.wait(1.0)
	pt.expect(not Steward.is_active(), "s1: the smith takes the workshop back")
	pt.expect(pt.panel() is WelcomeBackPanel, "s1: While You Were Away is shown")
	if pt.panel() is WelcomeBackPanel:
		pt.note("s1: report sections %s" % ", ".join((pt.panel() as WelcomeBackPanel).sections))
	await pt.shot("s1_welcome_back")
	await _scroll_down(pt.panel())
	await pt.shot("s1_welcome_back_lower")
	# ---- the sealed letter
	await pt.click("Back to the forge")
	await pt.wait(0.8)
	pt.expect(pt.panel() is SealedLetterPanel, "s1: the sealed envelope follows the report")
	await pt.shot("s1_letter_sealed")
	await pt.click("Break the seal")
	await pt.wait(0.6)
	await pt.shot("s1_letter_open")
	await pt.click("Read the offer at the Project Bench")
	await pt.wait(0.8)
	pt.expect(pt.panel() is ContractsPanel, "s1: the letter leads to the actual offer")
	pt.expect(Contracts.offers().any(func(o): return str(o["id"]) == str(c["id"])), "s1: the offer still waits for the smith's answer")
	await pt.shot("s1_letter_matter")
	await pt.close_panel()
	await pt.wait(0.6)
	pt.expect(w.player.sprite.modulate.a > 0.9, "s1: the smith is back in the world")
	await pt.shot("s1_back_at_forge")
	# ---- save while the steward runs, load: mode off, the closed session reported once
	await pt.press("panel_steward")
	await pt.wait(0.5)
	await pt.click("Hand over the forge")
	await pt.wait(0.8)
	await _hours(3)
	pt.expect(Saves.save("s1_steward_mid"), "s1: saved while the steward runs")
	await _hours(2)
	pt.main.call("load_slot", "s1_steward_mid")
	await pt.wait(2.5)
	pt.expect(not Steward.is_active() and not Steward.smith_away(), "s1: after loading the mode is off")
	pt.expect(pt.panel() is WelcomeBackPanel, "s1: the closed session's report is shown once")
	pt.expect(pt.find_label_containing(pt.panel(), "it stood down there") != null, "s1: it says the steward stood down where the save was made")
	await pt.shot("s1_after_load_report")
	await pt.close_panel()
	await pt.wait(0.8)
	pt.expect(not _plate().plate.visible, "s1: no status plate after loading")
	await pt.shot("s1_after_load_world")
	Saves.delete("s1_steward_mid")
