## Rendered play-test phase "s2_early" (Milestone S2 — the EARLY worker): the first hour on a fresh save, as the player
## sees it. Borin waiting in the smithy at 07:30; the toolbar with every key (Y on the Workshop, the right-click keys),
## Y / K / U opening what their labels say, Help listing every shortcut, the Settings auto-walk; Borin talked to and sent
## out; the first longsword with auto-walk on (the shorter check result, the smith walking to the next station with
## nothing opened); a background sale while a conversation is open (BUG-050) and Mira Pell's commission delivered with an
## empty purse (the subsidy pays, the selling step completes); K, J and Y finishing the tutorial card; the inn, the night,
## Borin's bag and a quick-save finishing the objectives; and a second new game where Mira's commission lapses and the
## guide moves on. Written to run on the base build too (BEFORE screenshots): new functions are only called dynamically.
## Called from tests/playtest.gd (phase_s2_early). Screenshots: s2e_*.
extends RefCounted

var pt: Node


func _borin_in_smithy() -> bool:
	var n: NPCActor = pt.W().npcs.get("borin")
	return n != null and n.visible and pt.W().brect(DB.building("smithy")).has_point(n.position)


## Opens `st`, starts its operation and plays its ring checks; seconds from the last press until the check is gone.
func _timed_check(st: String) -> float:
	if pt.panel() == null or not (pt.panel() is StationPanel) or (pt.panel() as StationPanel).station_id != st:
		pt.U().close_current()
		await pt.wait(0.2)
		await pt.use("station", st)
	await pt.click(str(Crafting.current_op().get("op", "")))
	await pt.wait(0.4)
	var sc := pt._check_host() as SkillCheckPanel
	if sc == null:
		return -1.0
	await pt._play_ring(sc, 0.05)
	# game time (the sum of frame deltas the timers run on): under Xvfb's software renderer a game second takes several
	# wall-clock seconds, so wall-clock time would measure the test machine, not what a player waits
	var ov: CheckOverlay = pt._overlay_of(sc)
	var t := 0.0
	var banner := -1.0
	var wall0 := Time.get_ticks_msec()
	while is_instance_valid(sc) and not sc.is_queued_for_deletion() and t < 6.0:
		await pt.get_tree().process_frame
		t += pt.get_process_delta_time()
		if banner < 0.0 and is_instance_valid(ov) and ov.result_t >= 0.0:
			banner = t
	pt.note("  check %s: banner from %.2f s, flow on after %.2f s of game time (%.1f s wall clock)" % [st, banner, t, (Time.get_ticks_msec() - wall0) / 1000.0])
	return t


## Presses a panel key with nothing open (closing whatever is) — what the player does on the map.
func _key_panel(action: String) -> Control:
	pt.U().close_current()
	await pt.wait(0.3)
	await pt.press(action)
	await pt.wait(0.6)
	return pt.panel()


func _hover(id: String) -> void:
	var tb: Control = pt.U().toolbar.buttons[id]
	Input.warp_mouse(tb.get_global_rect().get_center())
	tb.mouse_entered.emit()
	await pt.wait(0.4)


func _unhover(id: String) -> void:
	(pt.U().toolbar.buttons[id] as Control).mouse_exited.emit()


func run(p: Node) -> void:
	pt = p
	var after := Settings.values.has("gameplay/auto_walk")   # the S2 build (BEFORE runs lack the setting)
	pt.note("s2_early: %s build" % ("S2" if after else "base"))
	await pt.click("New Game")
	await pt.wait(2.5)
	# ---- 1. 07:30 on day 1: Borin is already in the smithy for "Speak with Borin in the workshop"
	pt.expect(Game.time_string() <= "07:35", "s2e: a new game at %s" % Game.time_string())
	var in_smithy := _borin_in_smithy()
	pt.expect(in_smithy or not after, "s2e: Borin waits inside the smithy at %s (visible %s)" % [Game.time_string(), str(in_smithy)])
	await pt.shot("s2early_borin_at_start")
	# ---- 2. move, then talk to him
	await pt.hold("move_left", 1.0)
	await pt.hold("move_down", 0.4)
	pt.expect(Tutorial.is_done("move"), "s2e: walking completes 'Find your feet'")
	if pt.W().npcs["borin"].visible:
		pt.expect(await pt.talk_to("borin"), "s2e: Borin can be talked to at %s" % Game.time_string())
		await pt.shot("s2early_borin_dialogue")
		await pt.click("Talk")
		await pt.wait(0.3)
		await pt.close_panel()
	pt.expect(Objectives.is_done("talk_borin") or not after, "s2e: the first objective is done before his shift starts")
	# ---- 3. the toolbar, the keys and Help
	await _hover("property")
	await pt.shot("s2early_toolbar_workshop_tooltip")
	_unhover("property")
	await _hover("skills")
	await pt.shot("s2early_toolbar_skilltree_tooltip")
	_unhover("skills")
	await pt.press("panel_property" if after else "panel_workshop")   # the key the Workshop button names (base: Y = the ledger)
	await pt.wait(0.7)
	var opened := "nothing"
	if pt.panel() != null and pt.panel().get_script() != null:
		opened = str((pt.panel().get_script() as Script).get_global_name())
	pt.expect(pt.panel() is PropertyPanel or not after, "s2e: Y opens the Workshop (Property & Workshop), as the button says (%s)" % opened)
	await pt.shot("s2early_y_opens")
	await pt.close_panel()
	await pt.press("panel_skills")
	await pt.wait(0.7)
	pt.expect(pt.panel() is SkillTreePanel, "s2e: K opens the Skill Tree")
	await pt.shot("s2early_k_skill_tree")
	await pt.close_panel()
	await pt.press("panel_skill_levels")
	await pt.wait(0.6)
	pt.expect(pt.panel() is SkillsPanel, "s2e: U opens the skill levels")
	await pt.close_panel()
	Events.open_panel.emit("help", {"topic": "hotkeys"})
	await pt.wait(0.8)
	await pt.shot("s2early_help_hotkeys")
	await pt.close_panel()
	Events.open_panel.emit("settings", {})
	await pt.wait(0.7)
	await pt.shot("s2early_settings_auto_walk")
	await pt.close_panel()
	# ---- 4. Borin to Ironroot Mine
	await pt.press("panel_hirelings")
	await pt.wait(0.6)
	for b in pt._buttons(pt.panel()):
		if b.text == "Send" and pt._row_text(b).begins_with("Ironroot Mine"):
			b.pressed.emit()
			break
	await pt.wait(0.5)
	pt.expect(str(Hire.get_h("borin")["status"]) == "away" and Objectives.is_done("send_borin"), "s2e: Borin sent to Ironroot Mine")
	await pt.close_panel()
	# ---- 5. the first longsword with auto-walk on (a setting in memory only: the shared settings file is not written)
	var walk_was: Variant = Settings.values.get("gameplay/auto_walk", false)
	Settings.values["gameplay/auto_walk"] = true
	pt.expect(await pt.use("station", "forge"), "s2e: the forge")
	var begin: Button = null
	for b in pt._buttons(pt.panel()):
		if b.text == "Begin" and pt._row_text(b).begins_with("Iron Longsword "):
			begin = b
	pt.expect(begin != null, "s2e: Begin the Iron Longsword")
	if begin == null:
		Settings.values["gameplay/auto_walk"] = walk_was
		return
	begin.pressed.emit()
	await pt.wait(0.6)
	var sc: SkillCheckPanel = pt._check_host() as SkillCheckPanel
	pt.expect(sc != null, "s2e: the forge's precision check opens")
	if sc:
		await pt._play_ring(sc, 0.05)
		await pt.wait(0.45)
		await pt.shot("s2early_check_result_banner")
		var w0 := 0.0
		while is_instance_valid(sc) and not sc.is_queued_for_deletion() and w0 < 5.0:
			await pt.wait(0.1)
			w0 += 0.1
	await pt.wait(0.5)
	pt.expect(Crafting.current_station() == "anvil", "s2e: the next operation is at the anvil")
	if after:
		pt.expect(pt.panel() == null, "s2e: auto-walk closed the forge panel — nothing else opened")
		await pt.shot("s2early_auto_walk_on_the_way")
		var w := 0.0
		var anvil: Dictionary = pt.find_entry("station", "anvil")
		while w < 8.0 and pt.W().player.position.distance_to(anvil["pos"]) > float(anvil["r"]) + 8.0:
			await pt.wait(0.2)
			w += 0.2
		await pt.wait(0.6)
		pt.expect(pt.W().player.position.distance_to(anvil["pos"]) <= float(anvil["r"]) + 8.0, "s2e: the smith walked to the anvil by himself (%.1f s)" % w)
		pt.expect(pt.panel() == null and pt._check_host() == null and int(Crafting.job()["step"]) == 1, "s2e: arrived — nothing opened, no check started, the recipe still waits at step 2")
		await pt.shot("s2early_auto_walk_arrived")
	else:
		await pt.shot("s2early_after_check_panel_stays")
	Settings.values["gameplay/auto_walk"] = walk_was
	# the anvil's two checks, timed from the last press until the flow goes on (no screenshot in between)
	var secs := await _timed_check("anvil")
	pt.expect(secs > 0.0 and (secs <= 1.6 or not after), "s2e: from the last press to the flow going on: %.2f s (base: 0.55 s pause + 1.5 s banner)" % secs)
	# the rest of the sword through the real stations (auto-walk off again: the panels as before)
	var guard := 0
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 12:
		guard += 1
		var st := Crafting.current_station()
		if pt._check_host() == null:
			if pt.panel() == null or not (pt.panel() is StationPanel) or (pt.panel() as StationPanel).station_id != st:
				await pt.close_panel()
				await pt.use("station", st)
			await pt.click(str(Crafting.current_op().get("op", "")))
		await pt.wait(0.4)
		if pt._minigame() != null:
			await pt.play_minigame(true)
		await pt.play_checks(true)
	pt.expect(pt.panel() is DicePanel, "s2e: the dice after the last station")
	if pt.panel() is DicePanel and (pt.panel() as DicePanel).mode != "auto":
		await pt.click("Digital dice")
		await pt.wait(0.3)
	await pt.click("Roll the dice")
	await pt.wait(1.8)
	await pt.click("Finish the piece")
	await pt.wait(1.0)
	await pt.shot("s2early_first_sword")
	await pt.click("Keep it")
	await pt.wait(0.3)
	await pt.close_panel()
	pt.expect(Tutorial.is_done("craft") and Tutorial.is_done("dice") and Objectives.is_done("craft_sword"), "s2e: crafting steps and craft_sword done")
	# ---- 6. BUG-050: a background sale while a conversation is open is not "serving a customer"
	pt.expect(str(Tutorial.current().get("id", "")) == "customer", "s2e: 'Serve a customer' is the tutorial step now")
	Events.open_panel.emit("dialogue", {"npc": "aldric", "area": "village"})
	await pt.wait(0.5)
	Game.add_gold(5, "sales", "Borin Flintbeard sold horseshoes and nails", "market")   # what Hire._produce writes each hour
	await pt.wait(0.3)
	await pt.close_panel()
	await pt.wait(0.4)
	pt.expect(not Tutorial.is_done("customer") or not after, "s2e: the market's coin during a conversation leaves the selling step in place")
	await pt.shot("s2early_selling_step_after_background_sale")
	# ---- 7. Mira's commission at 15:00, delivered with an empty purse
	await pt.advance_to(15, 30)
	var mira := Adv.get_a("mira")
	mira["gold"] = 0   # Run 0.1 saw a penniless Mira at the counter
	await pt.wait(0.6)
	await pt.shot("s2early_objective_mira_commission")
	var ord: Array = Shop.open_orders().filter(func(o): return str(o["npc"]) == "mira")
	pt.expect(not ord.is_empty(), "s2e: Aldric's commission for Mira is open")
	await pt.press("panel_orders")
	await pt.wait(0.7)
	await pt.shot("s2early_orders_mira")
	var g0 := Game.gold()
	var deliver: Button = null
	for b in pt._buttons(pt.panel()):
		if b.text.contains("Longsword") and not b.disabled:
			deliver = b
	pt.expect(deliver != null, "s2e: the longsword can be delivered from the Commissions board")
	if deliver:
		deliver.pressed.emit()
		await pt.wait(0.5)
	pt.expect(Objectives.is_done("serve_mira"), "s2e: Mira's objective is done")
	pt.expect(Tutorial.is_done("customer") or not after, "s2e: delivering it in person completes 'Serve a customer' though her purse was empty")
	pt.expect(int(Adv.get_a("mira")["gold"]) == 0 and Payments.unaccounted().is_empty(), "s2e: her purse stays 0, every coin has a payer (+%d g, the recorded subsidy)" % (Game.gold() - g0))
	await pt.close_panel()
	await pt.wait(0.3)
	await pt.shot("s2early_after_mira_delivered")
	Events.open_panel.emit("shop", {"tab": "ledger"})
	await pt.wait(0.6)
	pt.click("Journal")
	await pt.wait(0.6)
	await pt.shot("s2early_ledger_subsidy")
	await pt.close_panel()
	# ---- 8. K, J and Y finish the tutorial card
	for a in ["panel_skills", "panel_adventurers", "panel_property" if after else "panel_workshop"]:
		var opened2: Control = await _key_panel(a)
		pt.expect(opened2 != null, "s2e: %s (%s) opens a panel" % [Settings.key_label(a), a])
	pt.U().close_current()
	await pt.wait(0.3)
	pt.expect(Tutorial.current().is_empty() or not after, "s2e: the tutorial card is complete (current: %s)" % str(Tutorial.current().get("id", "—")))
	await pt.shot("s2early_tutorial_complete")
	# ---- 9. the inn, the night, Borin's bag and a quick-save
	await pt.advance_to(19, 30)
	var adv_id := ""
	var waited := 0.0
	while adv_id == "" and waited < 20.0:
		await pt.wait(1.0)
		waited += 1.0
		for a in Adv.in_town():
			var n: NPCActor = pt.W().npcs.get(a["id"])
			if n and n.visible and pt.W().room_at("inn", n.position) == "common":
				adv_id = a["id"]
	if adv_id != "" and await pt.talk_to(adv_id):
		await pt.click("Talk")
		await pt.wait(0.3)
		await pt.close_panel()
	pt.expect(Objectives.is_done("visit_inn"), "s2e: visited the inn (%s)" % adv_id)
	pt.expect(Objectives.is_done("watch_depart"), "s2e: departures watched (Borin set out)")
	var guard_days := 0
	while str(Hire.get_h("borin")["status"]) == "away" and guard_days < 5:
		Game.advance_minutes(24 * 60)
		guard_days += 1
	await pt.wait(1.0)
	var bag := -1
	for c in Game.state["returns"]:
		if str(c.get("from", "")).begins_with("Borin"):
			bag = int(c["uid"])
	pt.expect(bag >= 0, "s2e: Borin's bag waits in the workshop")
	if bag >= 0:
		await pt.use("bag", str(bag))
		await pt.wait(10.0)
		await pt.click("Take everything")
		await pt.wait(0.5)
	pt.expect(Objectives.is_done("open_bag"), "s2e: opened Borin's bag")
	await pt.close_panel()
	await pt.press("quick_save")
	await pt.wait(0.6)
	pt.expect(Objectives.is_done("save_game") or not after, "s2e: the quick-save completes the last objective")
	pt.expect(Objectives.text() == "" or not after, "s2e: every first-day objective done (now: '%s')" % Objectives.text())
	await pt.shot("s2early_objectives_complete")
	Saves.delete("quicksave")
	# ---- 10. a second new game: Mira's commission lapses unserved and the guide moves on
	pt.main.call("to_menu")
	await pt.wait(1.0)
	await pt.click("New Game")
	await pt.wait(2.5)
	for id in ["talk_borin", "send_borin", "select_recipe", "craft_sword"]:
		Objectives.complete(id)
	for i in 4:
		Game.advance_minutes(24 * 60)
		await pt.wait(0.3)
	await pt.wait(0.5)
	pt.expect(Objectives.is_done("serve_mira") or not after, "s2e: the lapsed commission closes the objective (now: '%s')" % Objectives.text())
	await pt.shot("s2early_lapsed_commission_guide_moves_on")
