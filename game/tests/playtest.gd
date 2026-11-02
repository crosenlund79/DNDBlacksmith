## Rendered play-test driver: runs the real main scene, plays it with synthetic input and saves
## screenshots to user://playtest/. Run with a display (or Xvfb):
##   godot --path game res://tests/playtest.tscn -- [phase]
## DA: Kører den rigtige hovedscene, spiller den med syntetisk input og gemmer skærmbilleder.
extends Node

var main: Node
var shots := 0
var log_lines: Array[String] = []
var fails := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://playtest")
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	var args := OS.get_cmdline_user_args()
	var phase: String = args[0] if args.size() > 0 else "smoke"
	await get_tree().create_timer(1.5).timeout
	await call("phase_" + phase)
	note("DONE phase %s — %d failures" % [phase, fails])
	var f := FileAccess.open("user://playtest/report_%s.txt" % phase, FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	get_tree().quit(1 if fails > 0 else 0)


func note(t: String) -> void:
	log_lines.append(t)
	print("[PLAYTEST] ", t)


func expect(cond: bool, t: String) -> void:
	if not cond:
		fails += 1
	note(("OK   " if cond else "FAIL ") + t)


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	shots += 1
	img.save_png("user://playtest/%02d_%s.png" % [shots, name])
	note("screenshot %s" % name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func phase_smoke() -> void:
	await shot("main_menu")
	main.call("new_game")
	await wait(2.0)
	await shot("new_game")



# ======================================================================= helpers
func W() -> VillageWorld:
	return main.get("world")


func U() -> UIRoot:
	return UIRoot.instance


func panel() -> Control:
	return U().current if U() and is_instance_valid(U().current) else null


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


## Closes the open panel (Esc) without opening the pause menu when nothing is open.
func close_panel() -> void:
	if panel() != null:
		await press("cancel")
		await wait(0.2)


func hold(action: String, secs: float) -> void:
	Input.action_press(action)
	await wait(secs)
	Input.action_release(action)
	await get_tree().process_frame


func find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text.contains(text) and not (root as Button).disabled:
		return root
	for c in root.get_children():
		var b := find_button(c, text)
		if b:
			return b
	return null


func click(text: String, root: Node = null) -> bool:
	var b := find_button(root if root else get_tree().root, text)
	if b == null:
		note("button not found: " + text)
		return false
	b.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func tp(pos: Vector2) -> void:
	W().player.position = pos
	W().camera.reset_smoothing()
	await wait(0.3)


func find_entry(kind: String, id: String) -> Dictionary:
	for e in W().interactables:
		if e["kind"] == kind and str(e["id"]) == id:
			return e
	return {}


## Walk up to an interactable and press the interact key (real input path).
func use(kind: String, id: String) -> bool:
	var e := find_entry(kind, id)
	if e.is_empty():
		note("no interactable %s/%s" % [kind, id])
		return false
	await tp((e["pos"] as Vector2) + Vector2(0, -min(float(e["r"]) * 0.5, 60.0)))
	W().player.facing = "s"
	await wait(0.15)
	await press("interact")
	await wait(0.4)
	return true


func talk_to(npc: String) -> bool:
	var n: NPCActor = W().npcs.get(npc)
	if n == null or not n.visible:
		note("npc %s not visible" % npc)
		return false
	n.path = PackedVector2Array()
	await tp(n.position + Vector2(0, -60))
	W().player.facing = "s"
	await wait(0.2)
	await press("interact")
	await wait(0.4)
	return panel() is DialoguePanel


## Plays the circular skill checks that are currently open, aiming for the zone centre.
func play_checks(aim := true) -> int:
	var n := 0
	var guard := 0.0
	while guard < 30.0:
		var sc: SkillCheckPanel = null
		for c in U().panel_host.get_children():
			if c is SkillCheckPanel and not c.is_queued_for_deletion():
				sc = c
		if sc == null:
			break
		if sc.running:
			var off := fposmod(sc.zone_center - sc.angle, 360.0)
			var step := sc.speed * 360.0 * get_process_delta_time() * 1.5
			if (aim and off < step) or (not aim and off > 300.0):
				await press("interact")
				n += 1
				continue
		await get_tree().process_frame
		guard += get_process_delta_time()
	await wait(0.5)
	return n


func advance_to(hour: int, minute := 0) -> void:
	var target := hour * 60 + minute
	var mins: int = (target - int(Game.state["minute"]) + 1440) % 1440
	Game.advance_minutes(mins)
	await wait(0.6)


# ======================================================================= full playthrough
func phase_full() -> void:
	await shot("main_menu")
	expect(await click("New Game"), "main menu: New Game button")
	await wait(2.5)
	expect(W() != null and W().player != null, "world spawned with player")
	await shot("workshop_start")
	# --- movement, camera, collision
	var p0 := W().player.position
	await hold("move_right", 0.8)
	expect(W().player.position.x > p0.x + 60, "movement: walked right (%.0f px)" % (W().player.position.x - p0.x))
	await hold("move_down", 0.6)
	var wall_x := W().brect(DB.building("smithy")).position.x
	await tp(Vector2(wall_x + 90, W().player.position.y))
	await hold("move_left", 1.2)
	expect(W().player.position.x > wall_x + 10, "collision: smithy west wall stops the player")
	# --- leave and re-enter: door is on the north wall
	await tp(W().spots["smithy_inside"] + Vector2(0, -260))
	await hold("move_up", 1.6)
	await wait(0.5)
	expect(W().area == "village", "building exit: player is outside (%s)" % W().area)
	await shot("village_outside_forge")
	await tp(W().spots["inn_door_out"] + Vector2(0, 30))
	await hold("move_up", 1.2)
	await wait(0.6)
	expect(W().area == "inn", "building entry: player inside the inn (%s)" % W().area)
	await shot("inn_interior_morning")
	# --- Borin
	await advance_to(8, 30)
	await wait(4.0)
	expect(await talk_to("borin"), "dialogue: talk to Borin opens dialogue")
	await shot("dialogue_borin")
	await click("Talk")
	await wait(0.3)
	expect(Objectives.is_done("talk_borin"), "objective: talked to Borin")
	await press("cancel")
	await wait(0.3)
	await press("panel_hirelings")
	await wait(0.6)
	expect(panel() is HirelingsPanel, "hirelings panel opens with H")
	await shot("hirelings_panel")
	await click("Ironroot Mine")
	await wait(0.5)
	expect(Hire.get_h("borin")["status"] == "away", "expedition: Borin sent to Ironroot Mine")
	await wait(2.0)
	await shot("borin_leaving")
	# --- craft an Iron Longsword through every station
	var steps: Array = DB.recipe("iron_longsword")["steps"]
	expect(await use("station", "anvil"), "station: anvil interactable")
	expect(panel() is StationPanel, "station panel opens at the anvil")
	await shot("anvil_station_panel")
	var row_btn: Button = null
	for b in _buttons(panel()):
		if b.text == "Begin" and _row_text(b).contains("Iron Longsword"):
			row_btn = b
	expect(row_btn != null, "recipe: Iron Longsword has a Begin button")
	if row_btn:
		row_btn.pressed.emit()
	await wait(0.5)
	expect(Crafting.active(), "crafting: job started (current step %s)" % Crafting.current_station())
	var guard := 0
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 8:
		guard += 1
		var st := Crafting.current_station()
		if panel() == null or not (panel() is StationPanel) or (panel() as StationPanel).station_id != st:
			await press("cancel")
			await use("station", st)
			await click("Begin work here")
		await wait(0.4)
		if guard == 1:
			await shot("skillcheck_" + st)
		var n := await play_checks(true)
		note("  step %s: %d checks played, samples so far %d" % [st, n, Crafting.job().get("samples", []).size()])
	expect(Crafting.job().get("awaiting_dice", false), "crafting: all %d stations worked" % steps.size())
	await wait(0.5)
	expect(panel() is DicePanel, "dice panel opened after the last step")
	await shot("dice_panel")
	await click("Roll the dice")
	await wait(1.8)
	await shot("dice_rolled")
	var before := Game.inventory().size()
	await click("Finish the piece")
	await wait(1.0)
	expect(panel() is RevealPanel, "reveal panel shows the finished sword")
	await shot("crafted_sword_reveal")
	var sword := {}
	for it in Game.inventory():
		if it["def"] == "sword_iron":
			sword = it
	expect(not sword.is_empty(), "crafting: an Iron Longsword is in the inventory (%s, q %.0f%%, attack %d)" % [sword.get("rarity", "?"), float(sword.get("quality", 0)), Items.stat(sword, "attack")])
	await click("Keep it")
	# --- inventory
	await press("inventory")
	await wait(0.6)
	expect(panel() is InventoryPanel, "inventory opens with I")
	await shot("inventory")
	await press("cancel")
	# --- every station interface
	var opened := 0
	for sid in DB.stations:
		await close_panel()
		if await use("station", sid) and panel() is StationPanel:
			opened += 1
		if sid in ["forge", "arcane_crucible", "cauldron", "resonance_pedestal", "thread_spinner"]:
			await shot("station_" + sid)
	await press("cancel")
	expect(opened == DB.stations.size(), "stations: %d/%d station panels opened" % [opened, DB.stations.size()])
	await shot("workshop_overview")
	# --- Aldric's commission for Mira (15:00) and the shop
	await advance_to(15, 30)
	await wait(0.5)
	var mira_order := Shop.open_orders().filter(func(o): return o["npc"] == "mira")
	expect(not mira_order.is_empty(), "commission: Aldric asked for a blade for Mira")
	await press("panel_orders")
	await wait(0.6)
	await shot("orders_panel")
	var delivered := false
	if not mira_order.is_empty():
		var o: Dictionary = mira_order[0]
		var cands := Game.inventory().filter(func(it): return Shop.item_meets(o, it))
		if not cands.is_empty():
			delivered = Shop.fulfil(o["id"], int(cands[0]["uid"])) == ""
	expect(delivered or Objectives.is_done("serve_mira"), "commission: sword delivered to Mira")
	await press("cancel")
	var axe := Items.make("axe_hand", {"quality": 95.0})
	axe["for_sale"] = true
	Game.add_item(axe, false)
	Adv.get_a("varn")["gold"] = 500
	Shop._add_customer("varn", "browse")
	await use("counter", "smithy")
	expect(panel() is ShopPanel, "shop counter opens the shop panel")
	await shot("shop_counter")
	var gold0 := Game.gold()
	await click("Hand Axe")
	await wait(0.4)
	expect(Game.gold() > gold0 or Adv.get_a("varn")["equipment"].get("weapon", {}).get("uid", -1) == axe["uid"], "shop: Varn bought the hand axe (gold %d → %d)" % [gold0, Game.gold()])
	await press("cancel")
	# --- notice board & hiring
	await use("notice", "board")
	expect(panel() is NoticePanel, "notice board opens")
	await shot("notice_board")
	var hired_before := Hire.list().size()
	Game.add_gold(200, "test", "playtest purse")
	await click("Hire")
	await wait(0.5)
	expect(Hire.list().size() == hired_before + 1, "recruitment: hired an applicant")
	await press("cancel")
	# --- inn in the evening, adventurer dialogue, upstairs
	await advance_to(19, 30)
	var adv_id := ""
	var waited := 0.0
	while adv_id == "" and waited < 20.0:
		await wait(1.0)
		waited += 1.0
		for a in Adv.in_town():
			var n: NPCActor = W().npcs.get(a["id"])
			if n and n.visible and n.path.is_empty() and W().brect(DB.building("inn")).has_point(n.position):
				adv_id = a["id"]
	expect(adv_id != "", "inn: an adventurer is in the common room")
	if adv_id != "":
		await tp(W().npcs[adv_id].position + Vector2(0, -60))
		await wait(0.3)
		await shot("inn_evening")
		expect(await talk_to(adv_id), "inn: dialogue with " + adv_id)
		await click("Talk")
		await shot("inn_dialogue")
		expect(Objectives.is_done("visit_inn"), "objective: visited the inn")
		await press("cancel")
	await use("stairs", "inn_upstairs")
	await wait(0.6)
	expect(W().area == "inn_upstairs", "stairs: up to the Velvet Lantern (%s)" % W().area)
	await wait(2.0)
	if await talk_to("rosalind"):
		await click("Ask what the adventurers")
		await shot("velvet_lantern_dialogue")
		await press("cancel")
	await use("stairs", "inn")
	await wait(0.4)
	# --- sleep, dawn departures, Borin's return and bag
	await use("bed", "player_bed")
	expect(panel() is SleepPanel, "bed: sleep prompt")
	await click("Sleep")
	await wait(4.5)
	expect(Game.hour() == 6, "sleep: woke at 06:00 on day %d" % Game.day())
	var away_before := Adv.all().values().filter(func(a): return a["status"] == "away").size()
	await tp(W().spots["square_0"])
	await advance_to(7, 10)
	await wait(3.0)
	await shot("dawn_departures")
	var away_after := Adv.all().values().filter(func(a): return a["status"] == "away").size()
	expect(away_after > away_before or Objectives.is_done("watch_depart"), "adventurers: departures at dawn (%d → %d away)" % [away_before, away_after])
	var guard_days := 0
	while Hire.get_h("borin")["status"] == "away" and guard_days < 5:
		Game.advance_minutes(24 * 60)
		guard_days += 1
	await wait(1.0)
	expect(Game.state["returns"].size() > 0, "expedition: bags are waiting in the workshop (%d)" % Game.state["returns"].size())
	var borin_bag := -1
	for c in Game.state["returns"]:
		if str(c.get("from", "")).begins_with("Borin"):
			borin_bag = int(c["uid"])
	if borin_bag >= 0:
		await use("bag", str(borin_bag))
		expect(panel() is LootPanel, "loot: Borin's bag opens")
		await wait(1.2)
		await shot("loot_reveal_progress")
		await wait(9.0)
		await shot("loot_reveal_done")
		await click("Take everything")
		await wait(0.5)
		var leg := Game.inventory().filter(func(it): return it.get("rarity") == "legendary" and it.get("star", false))
		expect(not leg.is_empty(), "loot: a starred legendary is now in the inventory")
	await press("panel_adventurers")
	await wait(0.6)
	await shot("adventurers_panel")
	await press("cancel")
	await press("panel_skills")
	await wait(0.6)
	await shot("skills_panel")
	await press("cancel")
	await press("panel_ledger")
	await wait(0.6)
	await shot("ledger")
	await press("cancel")
	# --- save through the pause menu
	await press("cancel")
	await wait(0.4)
	expect(panel() is PausePanel, "Esc opens the pause menu")
	await click("Save game")
	await wait(0.5)
	await click("Save")
	await wait(0.5)
	expect(Saves.exists("slot_1"), "save: slot 1 written")
	var expect_state := {"day": Game.day(), "gold": Game.gold(), "items": Game.inventory().size(), "hirelings": Hire.list().size(),
		"borin": Hire.get_h("borin").get("status", ""), "mira_aff": Social.aff("mira"), "crafted": Game.state["stats"]["crafted"]}
	var f := FileAccess.open("user://playtest/expect.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(expect_state))
	note("saved state " + JSON.stringify(expect_state))


func phase_reload() -> void:
	await shot("menu_after_restart")
	expect(await click("Continue"), "restart: Continue button enabled")
	await wait(3.0)
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://playtest/expect.json"))
	expect(W() != null, "restart: world loaded")
	expect(Game.day() == int(exp["day"]), "load: day %d" % Game.day())
	expect(Game.gold() == int(exp["gold"]), "load: gold %d" % Game.gold())
	expect(Game.inventory().size() == int(exp["items"]), "load: %d inventory entries" % Game.inventory().size())
	expect(Hire.list().size() == int(exp["hirelings"]), "load: hirelings")
	expect(is_equal_approx(Social.aff("mira"), float(exp["mira_aff"])), "load: relationships remembered")
	expect(int(Game.state["stats"]["crafted"]) == int(exp["crafted"]), "load: crafting stats")
	await shot("after_load")
	await hold("move_down", 0.6)
	await shot("after_load_moved")


func _buttons(root: Node) -> Array:
	var out := []
	if root is Button:
		out.append(root)
	for c in root.get_children():
		out.append_array(_buttons(c))
	return out


func _row_text(b: Button) -> String:
	var row := b.get_parent()
	var t := ""
	for c in row.get_children():
		for cc in c.get_children():
			if cc is RichTextLabel:
				t += (cc as RichTextLabel).get_parsed_text()
	return t


func phase_diag() -> void:
	var menu: Control = main.get("menu")
	note("menu size %s anchors %s %s %s %s" % [menu.size, menu.anchor_left, menu.anchor_top, menu.anchor_right, menu.anchor_bottom])
	await shot("diag_menu")


func phase_stations() -> void:
	await click("New Game")
	await wait(2.5)
	for sid in DB.stations:
		await close_panel()
		await use("station", sid)
		var ok: bool = panel() is StationPanel and (panel() as StationPanel).station_id == sid
		var focus: Dictionary = W()._focus
		expect(ok, "station %s (focus %s/%s, panel %s)" % [sid, focus.get("kind", "-"), focus.get("id", "-"), panel().get_class() if panel() else "none"])


func phase_panels() -> void:
	await click("New Game")
	await wait(2.5)
	var vs := get_viewport().get_visible_rect().size
	for a in ["inventory", "panel_hirelings", "panel_skills", "panel_adventurers", "panel_orders", "panel_ledger"]:
		await press(a)
		await wait(0.8)
		var p := panel()
		expect(p != null, "panel opens: " + a)
		if p:
			var r := p.get_global_rect()
			expect(r.position.y >= -1 and r.end.y <= vs.y + 1 and r.position.x >= -1 and r.end.x <= vs.x + 1, "panel %s fits the screen %s" % [a, r])
			await shot("panel_" + a)
		await press("cancel")
		await wait(0.3)
