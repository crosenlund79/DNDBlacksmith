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
## Plays every open precision check. aim=false deliberately misses; frac aims that far from the
## centre (as a fraction of the half-zone), so demos can produce good, great or perfect work.
var check_log: Array = []


func play_checks(aim := true, frac := 0.0) -> int:
	var n := 0
	var guard := 0.0
	while guard < 60.0:
		var sc: SkillCheckPanel = null
		for c in U().panel_host.get_children():
			if c is SkillCheckPanel and not c.is_queued_for_deletion():
				sc = c
		if sc == null:
			break
		if sc.running:
			var off := fposmod(sc.zone_center - sc.angle, 360.0) - frac * sc.zone * 0.5
			var step := sc.speed * 360.0 * minf(get_process_delta_time(), 0.05)
			if (aim and off >= 0.0 and off < step * 1.5) or (not aim and off > 300.0):
				await press("interact")
				n += 1
				if not sc.results.is_empty():
					check_log.append(float(sc.results[-1]))
				continue
		await get_tree().process_frame
		guard += get_process_delta_time()
	await wait(0.5)
	return n


func _checks_open() -> bool:
	for c in U().panel_host.get_children():
		if c is SkillCheckPanel and not c.is_queued_for_deletion():
			return true
	return false


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
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 12:
		guard += 1
		var st := Crafting.current_station()
		if not _checks_open():
			if panel() == null or not (panel() is StationPanel) or (panel() as StationPanel).station_id != st:
				await close_panel()
				await use("station", st)
			await click(str(Crafting.current_op().get("op", "")))
		await wait(0.4)
		if guard == 1:
			await shot("skillcheck_" + st)
		var n := await play_checks(true)
		note("  step %s: %d checks played, samples so far %d" % [st, n, Crafting.job().get("samples", []).size()])
	expect(Crafting.job().get("awaiting_dice", false), "crafting: all %d stations worked" % steps.size())
	await wait(0.5)
	expect(panel() is DicePanel, "dice panel opened after the last step")
	await shot("dice_panel")
	if panel() is DicePanel and (panel() as DicePanel).mode != "auto":
		await click("Digital dice")
		await wait(0.3)
	await click("Roll the dice")
	await wait(1.8)
	await shot("dice_rolled")
	var before := Game.inventory().size()
	await click("Finish the piece")
	await wait(1.0)
	expect(panel() is CraftResultPanel, "results panel shows the finished sword")
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


## Visits the rooms of the redesigned buildings and photographs them (plus a zoomed-out plan).
func phase_interiors() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(10, 0)
	var tour := [["smithy", [5.0, 7.0], "forge_room"], ["smithy", [14.5, 1.6], "shop"], ["smithy", [14.5, 8.0], "stock_hall"],
		["smithy", [3.6, 13.6], "rune_room"], ["smithy", [10.0, 13.0], "alchemy_room"], ["smithy", [16.0, 13.6], "leather_room"],
		["smithy", [5.5, 22.2], "arcane_room"], ["smithy", [15.6, 20.4], "material_store"], ["smithy", [24.0, 2.4], "living"],
		["smithy", [20.6, 10.4], "study"], ["smithy", [26.0, 11.6], "bedroom"], ["smithy", [21.0, 16.0], "storage"],
		["smithy", [27.0, 19.0], "pantry"], ["inn", [7.0, 8.4], "common"], ["inn", [16.6, 3.4], "kitchen"],
		["inn", [16.6, 10.6], "hilde_room"], ["grocery", [3.6, 7.0], "g_shop"], ["grocery", [4.6, 2.4], "g_living"],
		["house_tobin", [3.0, 4.6], "house_tobin_main"], ["inn_upstairs", [6.0, 7.0], "landing"],
		["inn_upstairs", [15.0, 6.0], "velvet_parlour"]]
	for t in tour:
		await tp(W().bpos(t[0], t[1][0], t[1][1]))
		await wait(0.9)
		expect(W().area == t[0] and W().room == t[2], "room: %s/%s (area %s room %s)" % [t[0], t[2], W().area, W().room])
		await shot("room_%s_%s" % [t[0], t[2]])
	# zoomed-out plan of the smithy with its roof hidden
	await tp(W().bpos("smithy", 15.0, 11.5))
	W().camera.zoom = Vector2(0.62, 0.62)
	W().camera.limit_bottom = 100000
	await wait(1.0)
	await shot("plan_smithy")
	W().camera.zoom = Vector2.ONE
	# NPC routing through rooms: path from the front door to the private study must use doorways
	var path: PackedVector2Array = W().path_to(W().spots["smithy_door_out"], "quarters_table")
	expect(path.size() >= 6, "nav: path into the living room goes room to room (%d points)" % path.size())


## Every named spot must be reachable on the navigation graph from the village square.
func phase_nav() -> void:
	await click("New Game")
	await wait(2.0)
	var start: int = W().spot_ids["square_0"]
	var up_start: int = W().spot_ids["upstairs_hall"]
	var up_rect: Rect2 = W().brect(DB.building("inn_upstairs"))
	var bad := []
	for name in W().spot_ids:
		# the upper floor is its own graph island, reached by the stairs (a floor change, not a walk)
		var from: int = up_start if up_rect.has_point(W().spots[name]) else start
		var ids: PackedInt64Array = W().astar.get_id_path(from, W().spot_ids[name])
		if ids.is_empty():
			bad.append(name)
	expect(bad.is_empty(), "nav: all %d spots reachable from the square %s" % [W().spot_ids.size(), bad])
	var missing := []
	for id in W().npcs:
		W().spot_for(id)
	for name in ["smithy_counter_front", "work_mining", "work_alchemy", "work_runecraft", "work_smithing", "quarters_table", "inn_t1", "inn_behind_bar", "grocery_behind", "lantern_1"]:
		if not W().spot_ids.has(name):
			missing.append(name)
	expect(missing.is_empty(), "nav: schedule spots exist %s" % [missing])


# ======================================================================= crafting demonstrations
var shot_stations := {}


## Crafts one recipe entirely through the UI: walk to each station, run its operation's checks,
## roll (digital) or enter (physical) the dice, and return the item from the results panel.
func craft_ui(rid: String, frac: float, dice_mode: String, phys := {}, tag := "") -> Dictionary:
	var r := DB.recipe(rid)
	var ops := Crafting.operations(rid)
	await close_panel()
	await use("station", str(ops[0]["station"]))
	if not (panel() is StationPanel):
		expect(false, "%s: station panel at %s" % [rid, ops[0]["station"]])
		return {}
	var row_btn: Button = null
	for b in _buttons(panel()):
		if b.text == "Begin" and _row_text(b).begins_with(str(r["name"]) + " "):
			row_btn = b
	if row_btn == null:
		expect(false, "%s: Begin button available" % rid)
		return {}
	if tag != "":
		await shot(tag + "_recipes")
	row_btn.pressed.emit()
	await wait(0.4)
	check_log.clear()
	var guard := 0
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 16:
		guard += 1
		var st := Crafting.current_station()
		if not _checks_open():
			if panel() == null or not (panel() is StationPanel) or (panel() as StationPanel).station_id != st:
				await close_panel()
				await use("station", st)
			await click(str(Crafting.current_op().get("op", "")))
		await wait(0.35)
		if tag != "" and not shot_stations.has(st):
			shot_stations[st] = true
			await shot("check_" + st)
		await play_checks(true, frac)
	expect(Crafting.job().get("awaiting_dice", false), "%s: all %d operations performed at their stations" % [rid, ops.size()])
	await wait(0.5)
	if not (panel() is DicePanel):
		expect(false, "%s: dice panel opens after the last operation" % rid)
		return {}
	var dp := panel() as DicePanel
	if dice_mode == "physical":
		if dp.mode != "physical":
			await click("Physical dice")
			await wait(0.3)
		dp = panel() as DicePanel
		for k in phys:
			for sb in dp.inputs.get(k, []):
				(sb as SpinBox).value = int(phys[k])
		if tag != "":
			await shot(tag + "_dice_physical")
		await click("Use these rolls")
	else:
		if dp.mode != "auto":
			await click("Digital dice")
			await wait(0.3)
		if tag != "":
			await shot(tag + "_dice")
		await click("Roll the dice")
		await wait(1.8)
		if tag != "":
			await shot(tag + "_dice_rolled")
		await click("Finish the piece")
	await wait(1.4)
	if not (panel() is CraftResultPanel):
		expect(false, "%s: results panel shown" % rid)
		return {}
	var it: Dictionary = (panel() as CraftResultPanel).item
	note("  %s → %s | q %.1f%% | %s | checks %s | dice %s" % [rid, it.get("name"), float(it.get("quality", 0)), it.get("rarity"),
		check_log.map(func(x): return int(round(x))), it.get("dice_log", "")])
	await wait(1.2)
	await shot("result_" + (tag if tag != "" else rid))
	await click("Keep it")
	await wait(0.3)
	return it


func phase_craft() -> void:
	await click("New Game")
	await wait(2.5)
	Settings.set_value("gameplay/dice_mode", "auto")
	# the arcane room is locked but can be inspected
	await use("station", "arcane_crucible")
	expect(panel() is StationPanel and Crafting.station_locked_reason("arcane_crucible") != "", "arcane: room inspectable, station locked")
	await shot("arcane_locked")
	await close_panel()
	# materials first: short recipes with one or two operations
	var ingots := await craft_ui("smelt_iron", 0.45, "auto", {}, "smelt")
	expect(not ingots.is_empty(), "material: iron ingots smelted (2 operations)")
	var leather := await craft_ui("cure_leather", 0.5, "auto")
	expect(not leather.is_empty(), "material: leather cured (1 operation)")
	# 1. basic iron sword through several stations, digital dice
	var sword := await craft_ui("iron_longsword", 0.35, "auto", {}, "sword")
	expect(sword.get("def") == "sword_iron" and sword.get("craft", {}).get("ops", []).size() == 4, "1. iron longsword forged through 4 stations")
	expect(sword.get("craft", {}).get("dice_mode") == "digital", "7a. digital dice recorded")
	# 2. higher-quality steel weapon (7 operations), physical dice
	var steel := await craft_ui("steel_longsword", 0.25, "physical", {"edge": 14, "temper": 9, "fortune": 41}, "steel")
	expect(steel.get("def") == "sword_steel" and Items.stat(steel, "attack") > Items.stat(sword, "attack"), "2. steel longsword outclasses the iron one (%d vs %d attack)" % [Items.stat(steel, "attack"), Items.stat(sword, "attack")])
	expect(steel.get("craft", {}).get("dice_mode") == "physical" and int(steel.get("craft", {}).get("dice", {}).get("edge", {}).get("total", 0)) == 14, "7b. physical dice entered and used (edge 14)")
	# 3. armour
	var cuirass := await craft_ui("iron_cuirass", 0.4, "auto", {}, "cuirass")
	expect(cuirass.get("def") == "cuirass_iron" and Items.stat(cuirass, "protection") > 0, "3. iron cuirass (%d protection)" % Items.stat(cuirass, "protection"))
	# 4. runestone
	var rune := await craft_ui("ember_runestone", 0.35, "auto", {}, "rune")
	expect(str(rune.get("def", "")) == "runestone_ember" and Items.stat(rune, "fire") > 0, "4. ember runestone (fire %d)" % Items.stat(rune, "fire"))
	# 5. alchemical treatment
	var draught := await craft_ui("healing_draught", 0.4, "auto", {}, "alchemy")
	expect(str(draught.get("def", "")) == "potion_healing" and Items.stat(draught, "heal") > 0, "5. healing draught (heal %d)" % Items.stat(draught, "heal"))
	# 6. leather item
	var jerkin := await craft_ui("leather_jerkin", 0.4, "physical", {"guard": 11, "temper": 7, "fortune": 55}, "leather")
	expect(str(jerkin.get("def", "")) == "jerkin_leather", "6. leather jerkin (%d protection)" % Items.stat(jerkin, "protection"))
	# 8. craftsmanship above 100%
	var best := 0.0
	for x in [sword, steel, cuirass, rune, draught, jerkin]:
		best = maxf(best, float(x.get("quality", 0)))
	expect(best > 100.0, "8. craftsmanship above 100%% (best %.1f%%)" % best)
	# 9. legendary through exceptional crafting: dead-centre checks, a mediocre fortune roll
	Engine.time_scale = 0.3
	var leg := await craft_ui("iron_longsword", 0.0, "physical", {"edge": 9, "temper": 6, "fortune": 18}, "legendary")
	Engine.time_scale = 1.0
	expect(leg.get("rarity") == "legendary" and leg.get("star", false), "9. legendary from exceptional crafting with fortune 18 (q %.1f%%, %s)" % [float(leg.get("quality", 0)), leg.get("rarity")])
	# 10. save, then (phase craft_reload) restart, load and inspect the record
	await close_panel()
	await press("cancel")
	await wait(0.4)
	await click("Save game")
	await wait(0.5)
	await click("Save")
	await wait(0.5)
	expect(Saves.exists("slot_1"), "10a. saved to slot 1")
	var keep := {}
	for x in [sword, steel, cuirass, rune, draught, jerkin, leg]:
		if not x.is_empty():
			keep[str(x["uid"])] = {"name": x["name"], "rarity": x["rarity"], "quality": x["quality"], "stats": x["stats"], "ops": x.get("craft", {}).get("ops", []).size()}
	var f := FileAccess.open("user://playtest/expect_craft.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"items": keep, "legendary": str(leg.get("uid", ""))}))


func phase_craft_reload() -> void:
	expect(await click("Continue"), "restart: Continue")
	await wait(3.0)
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://playtest/expect_craft.json"))
	var items: Dictionary = exp["items"]
	var ok := 0
	for uid in items:
		var it := Game.find_uid(int(uid))
		var e: Dictionary = items[uid]
		if not it.is_empty() and it["name"] == e["name"] and it["rarity"] == e["rarity"] and is_equal_approx(float(it["quality"]), float(e["quality"])) \
				and it.get("craft", {}).get("ops", []).size() == int(e["ops"]) and JSON.stringify(it["stats"]) == JSON.stringify(e["stats"]):
			ok += 1
		else:
			note("  mismatch %s: %s" % [uid, it.get("name", "missing")])
	expect(ok == items.size(), "10b. %d/%d crafted items restored with stats, rarity and record" % [ok, items.size()])
	await press("inventory")
	await wait(0.6)
	var inv := panel() as InventoryPanel
	expect(inv != null, "inventory opens after reload")
	var leg := Game.find_uid(int(exp["legendary"]))
	if inv and not leg.is_empty():
		inv._select(leg)
		await wait(0.4)
		await shot("reload_inventory_legendary")
		expect(await click("Read the record of the work"), "10c. record of the work can be opened")
		await wait(1.0)
		expect(panel() is CraftResultPanel, "10c. results panel re-opened from the saved record")
		await shot("reload_record_legendary")


## Diagnostic: where are the adventurers in the evening, and are they getting to the inn?
func phase_inn_diag() -> void:
	await click("New Game")
	await wait(2.0)
	await advance_to(19, 30)
	for t in 4:
		await wait(5.0)
		for a in Adv.in_town():
			var n: NPCActor = W().npcs.get(a["id"])
			if n == null:
				continue
			var spot: String = W().spot_for(a["id"])
			note("t+%ds %s status=%s spot=%s pos=%s in_inn=%s path=%d visible=%s area=%s" % [(t + 1) * 5, a["id"], a.get("status", ""), spot, n.position.round(),
				W().brect(DB.building("inn")).has_point(n.position), n.path.size(), n.visible, W().room_at("inn", n.position)])
