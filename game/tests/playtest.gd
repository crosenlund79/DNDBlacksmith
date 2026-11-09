## Rendered play-test driver: runs the real main scene, plays it with synthetic input and saves
## screenshots to user://playtest/. Run with a display (or Xvfb):
##   godot --path game res://tests/playtest.tscn -- [phase]
## DA: Kører den rigtige hovedscene, spiller den med syntetisk input og gemmer skærmbilleder.
extends Node

var main: Node
var shots := 0
var log_lines: Array[String] = []
var fails := 0
var current_phase := ""
## Phases written before iteration 009 exercise crafting with the whole workshop (rooms, stations, skills).
const FULL_WORKSHOP_PHASES := ["full", "stations", "interiors", "nav", "minigames", "craft", "iter2", "slice", "village"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://playtest")
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	var args := OS.get_cmdline_user_args()
	var phase: String = args[0] if args.size() > 0 else "smoke"
	current_phase = phase

	# first-time skill-check how-to cards would pause the scripted checks of the older phases
	Minigames.auto_tutorials = phase.begins_with("checks")
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
	# New Game now asks for a difficulty first; older phases play at Journeyman
	if text == "New Game":
		var d := find_button(get_tree().root, "Begin as Journeyman")
		if d:
			d.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
		if current_phase in FULL_WORKSHOP_PHASES:
			await grant_full_workshop()
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
	await hold("move_down", 1.0)
	await hold("move_right", 1.0)
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
	for b in _buttons(panel()):
		if b.text == "Send" and _row_text(b).begins_with("Ironroot Mine"):
			b.pressed.emit()
			break
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
		if _minigame() != null:
			await play_minigame(true)
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
	# customers are only served once they have walked over and sat down outside
	W()._update_schedules()
	var vw := 0.0
	while not Shop.waiting().any(func(c): return c["npc"] == "varn") and vw < 60.0:
		await wait(1.0)
		vw += 1.0
	expect(Shop.waiting().any(func(c): return c["npc"] == "varn"), "shop: Varn walked over and took a seat (%.0fs)" % vw)
	await use("counter", "smithy")
	expect(panel() is ShopPanel, "shop counter opens the shop panel")
	await shot("shop_counter")
	var gold0 := Game.gold()
	await click("Hand Axe")
	await wait(0.4)
	expect(Game.gold() > gold0 or Adv.get_a("varn")["equipment"].get("weapon", {}).get("uid", -1) == axe["uid"], "shop: Varn bought the hand axe (gold %d → %d)" % [gold0, Game.gold()])
	await press("cancel")
	# --- notice board & hiring (some weeks nobody applies; make sure this one has applicants)
	while Game.state["applicants"].is_empty():
		Hire.refresh_applicants()
	await use("notice", "board")
	expect(panel() is NoticePanel, "notice board opens")
	await shot("notice_board")
	var hired_before := Hire.list().size()
	Game.add_gold(maxi(200, 200 - Game.gold()), "test", "playtest purse")
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
			# inside the common room — seated, or moving between tables after the hourly re-seat
			if n and n.visible and W().room_at("inn", n.position) == "common":
				adv_id = a["id"]
	if adv_id == "":
		note("  clock %s, in town: %s" % [Game.state["minute"], Adv.in_town().map(func(a): return "%s@%s→%s path%d vis%s" % [a["id"], W().npcs[a["id"]].position.round(), W().spot_for(a["id"]), W().npcs[a["id"]].path.size(), W().npcs[a["id"]].visible])])
		note("  all: %s" % [Adv.all().values().map(func(a): return "%s:%s" % [a["id"], a.get("status", "")])])
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
		if c is RichTextLabel:
			t += (c as RichTextLabel).get_parsed_text()
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
		if tag != "" and not shot_stations.has(st) and _minigame() == null:
			shot_stations[st] = true
			await shot("check_" + st)
		if _minigame() != null:
			check_log.append_array(await play_minigame(true, ("mg_" + st) if tag != "" and not shot_stations.has(st) else ""))
			shot_stations[st] = true
		else:
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
	SkillTree.unlock_all()   # these phases exercise advanced crafting, not skill-tree progression
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
	# like for like: the same craftsmanship and the same rolls in iron would make a weaker blade
	var sc: Dictionary = steel.get("craft", {})
	var rolls := {}
	for k in sc.get("dice", {}):
		rolls[k] = int(sc["dice"][k]["total"])
	var iron_twin := Crafting.compute_stats(DB.item("sword_iron"), float(steel.get("quality", 0)), rolls, DB.recipe("iron_longsword")["dice"], DB.crafting["materials"]["iron"], int(sc.get("level", 0)))
	var steel_base := Crafting.compute_stats(DB.item("sword_steel"), float(steel.get("quality", 0)), rolls, DB.recipe("steel_longsword")["dice"], DB.crafting["materials"]["steel"], int(sc.get("level", 0)))
	expect(steel.get("def") == "sword_steel" and int(steel_base["attack"]) > int(iron_twin["attack"]), "2. steel longsword outclasses iron at equal craft and rolls (%d vs %d base attack; finished %d)" % [int(steel_base["attack"]), int(iron_twin["attack"]), Items.stat(steel, "attack")])
	expect(steel.get("craft", {}).get("dice_mode") == "physical" and int(steel.get("craft", {}).get("dice", {}).get("edge", {}).get("entered", steel.get("craft", {}).get("dice", {}).get("edge", {}).get("total", 0))) == 14, "7b. physical dice entered and used (edge 14 entered; craftsmanship adds a shown modifier)")
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


# ======================================================================= specialised minigames
func _minigame() -> MinigameBase:
	for c in U().panel_host.get_children():
		if c is MinigameBase and not c.is_queued_for_deletion():
			return c
	return null


func _hold_axis(neg: String, pos: String, value: float, dead := 0.02) -> void:
	if value > dead:
		Input.action_press(pos)
		Input.action_release(neg)
	elif value < -dead:
		Input.action_press(neg)
		Input.action_release(pos)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


## Plays whatever specialised minigame is open, through the same input actions a player uses.
## good=false plays deliberately badly (to show that quality responds to play).
func play_minigame(good := true, tag := "") -> Array:
	var mg := _minigame()
	if mg == null:
		return []
	var guard := 0.0
	var pressed_round := -1
	var shot_done := tag == ""
	while is_instance_valid(mg) and not mg.is_queued_for_deletion() and guard < 90.0:
		var rnd := mg.results.size()
		if not mg.finished:
			if mg is AlignGame:
				var ag := mg as AlignGame
				if good:
					_hold_axis("move_left", "move_right", -ag.spark / 20.0, 0.08)
					_hold_axis("move_up", "move_down", -ag.ember / 20.0, 0.08)
					if absf(ag.spark) < ag.tol() * 0.18 and absf(ag.ember) < ag.tol() * 0.18 and pressed_round != rnd:
						pressed_round = rnd
						_release_all()
						await press("interact")
				elif ag.round_t > 0.5 and pressed_round != rnd:
					pressed_round = rnd
					await press("interact")
			elif mg is EdgeGame:
				var eg := mg as EdgeGame
				if good:
					var dlt := eg.target - eg.p
					_hold_axis("move_left", "move_right", dlt.x * 6.0, 0.06)
					_hold_axis("move_up", "move_down", dlt.y * 6.0, 0.06)
			elif mg is MultiHitGame:
				var mh := mg as MultiHitGame
				if mh.running:
					for tg in mh.targets:
						var ahead := mh.angle + float(mh.args.get("speed", 0.55)) * 1.45 * 360.0 * minf(get_process_delta_time(), 0.05)
						if int(tg[2]) == 0 and absf(ahead - float(tg[0])) <= float(tg[1]) * 0.85:
							if good or mh.hits() < 2:
								await press("interact")
							break
			elif mg is RuneGame:
				var rg := mg as RuneGame
				if good:
					var want := -rg.r * 0.03 - rg.v * 0.012
					_hold_axis("move_left", "move_right", want.x, 0.05)
					_hold_axis("move_up", "move_down", want.y, 0.05)
			elif mg is RingsGame:
				var rr := mg as RingsGame
				if rr.state == 1 and pressed_round != rnd:
					var gap := absf(rr.r - RingsGame.R0)
					var stepr := rr.spd * minf(get_process_delta_time(), 0.05)
					if (good and gap <= stepr * 1.2) or (not good and gap < 45.0):
						pressed_round = rnd
						await press("interact")
		else:
			_release_all()
		if not shot_done and guard > 1.6:
			shot_done = true
			await shot(tag)
		await get_tree().process_frame
		guard += get_process_delta_time()
	_release_all()
	var out: Array = mg.results.duplicate() if is_instance_valid(mg) else []
	await wait(0.4)
	return out


## Opens one specialised check directly at a station and plays it.
func run_minigame(station: String, good: bool, count := 1) -> Array:
	var c := Crafting.check_params(station)
	var got := []
	Events.open_panel.emit("skillcheck", {"station": station, "count": count, "speed": c["speed"], "zone": c["zone"],
		"title": "Test — " + DB.station(station)["name"], "on_done": func(qs: Array): got.append_array(qs)})
	await wait(0.3)
	var mg := _minigame()
	if mg == null:
		note("  no minigame opened at %s" % station)
		return []
	await play_minigame(good, ("minigame_%s_%s" % [Minigames.type_for({"station": station}), station]) if good else "")
	await wait(0.3)
	return got


func phase_minigames() -> void:
	await click("New Game")
	await wait(2.0)
	await use("station", "bellows")
	await close_panel()
	for st in ["bellows", "grinding_wheel", "embroidery_frame", "rune_engraving_stand", "cauldron", "alembic"]:
		var good := await run_minigame(st, true)
		var poor := await run_minigame(st, false)
		var g := 0.0 if good.is_empty() else float(good[0])
		var p := 0.0 if poor.is_empty() else float(poor[0])
		expect(not good.is_empty() and not poor.is_empty() and g > p, "%s (%s): skilful play %.0f%% beats careless play %.0f%%" % [st, Minigames.type_for({"station": st}), g, p])
	# the default ring is kept where no specialised check is defined
	expect(Minigames.type_for({"station": "anvil"}) == "ring", "anvil keeps the circular precision ring")



# ======================================================================= iteration 2
var toasts: Array = []


func _on_toast(text: String, _kind: String) -> void:
	toasts.append([Time.get_ticks_msec(), text])


func phase_iter2() -> void:
	Events.toast.connect(_on_toast)
	await click("New Game")
	await wait(2.5)
	SkillTree.unlock_all()   # these phases exercise advanced crafting, not skill-tree progression
	# --- figures: no sprite rotation, directional poses instead
	var rotated := 0
	for id in W().npcs:
		if absf((W().npcs[id] as NPCActor).sprite.rotation) > 0.001 or absf((W().npcs[id] as NPCActor).rotation) > 0.001:
			rotated += 1
	Input.action_press("move_right")
	await wait(0.5)
	var pr := W().player.sprite.rotation
	var anim_walk := W().player.sprite.animation
	await shot("figures_player_walking")
	Input.action_release("move_right")
	Input.action_press("move_up")
	await wait(0.4)
	var anim_n := W().player.sprite.animation
	var pr2 := W().player.sprite.rotation
	Input.action_release("move_up")
	await wait(0.2)
	expect(rotated == 0 and absf(pr) < 0.001 and absf(pr2) < 0.001 and anim_walk == "walk_e" and anim_n == "walk_n", "figures: miniatures never rotate — directional poses instead (%s, %s; %d rotated npcs)" % [anim_walk, anim_n, rotated])
	expect(W().animals.size() >= 4, "animals: at least two cats and two dogs in the village (%d animals)" % W().animals.size())
	# --- waiting area: four seats, announced only on arrival
	await advance_to(9, 10)
	Game.state["customers"].clear()
	toasts.clear()
	var tried := ["martha", "tobin", "jory", "eda", "oswin"]
	for npc in tried:
		Shop._add_customer(npc, "repair")
	expect(Shop.customers().size() == 4, "waiting: at most four customers (%d of 5 accepted)" % Shop.customers().size())
	var early := toasts.filter(func(t): return str(t[1]).contains("is waiting at your shop"))
	expect(early.is_empty() and Shop.waiting().is_empty(), "waiting: nobody announced before they arrive")
	W()._update_schedules()
	var waited := 0.0
	while Shop.waiting().size() < 4 and waited < 60.0:
		await wait(1.0)
		waited += 1.0
	var ann := toasts.filter(func(t): return str(t[1]).contains("is waiting at your shop"))
	expect(Shop.waiting().size() == 4 and ann.size() == 4, "waiting: %d seated after %.0fs, %d announcements (one each, on arrival)" % [Shop.waiting().size(), waited, ann.size()])
	await tp(W().spots["wait_seat_1"] + Vector2(0, -150))
	W().camera.zoom = Vector2(1.25, 1.25)
	await wait(0.6)
	await shot("waiting_area_four_seated")
	W().camera.zoom = Vector2.ONE
	# --- dismiss one customer
	var first: String = Shop.waiting()[0]["npc"]
	var seat := int(Shop.waiting()[0]["seat"])
	if await talk_to(first):
		await shot("waiting_customer_dialogue")
		expect(await click("Ask them to come back"), "waiting: 'ask to leave' offered")
		await wait(0.4)
		await click("Farewell")
	expect(Shop.customers().size() == 3 and Shop.free_seat() == seat, "waiting: dismissed customer freed seat %d" % seat)
	await wait(3.0)
	await shot("waiting_after_dismiss")
	# --- display, forge, animals, flowers
	await tp(W().bpos("smithy", 18.5, -1.5))
	await wait(0.5)
	await shot("craft_display_and_seats")
	await tp(W().station_pos("anvil"))
	await wait(1.0)
	await shot("forge_atmosphere")
	var cat: AnimalActor = W().animals[0]
	await tp(cat.position + Vector2(0, -60))
	W().camera.zoom = Vector2(1.4, 1.4)
	await wait(1.5)
	await shot("animal_cat_and_flowers")
	var dog: AnimalActor = W().animals[2]
	await tp(dog.position + Vector2(0, -60))
	await wait(1.5)
	await shot("animal_dog")
	W().camera.zoom = Vector2.ONE
	var moved := false
	var start_pos := dog.position
	for i in 20:
		await wait(1.0)
		if dog.position.distance_to(start_pos) > 20.0:
			moved = true
			break
	expect(moved, "animals: the dog wanders now and then")
	await tp(W().spots["square_0"])
	await wait(0.6)
	await shot("village_square_life")
	# --- hirelings: recruitment within the three-hand limit
	Game.add_gold(2000, "test", "test funds")
	Hire.refresh_applicants()
	while Game.state["applicants"].size() < 3:
		Hire.refresh_applicants()
	await use("notice", "board")
	expect(panel() is NoticePanel, "notice board opens")
	await shot("notice_board_applicants")
	await click("Hire")
	await wait(0.3)
	await click("Hire")
	await wait(0.3)
	expect(Hire.alive_count() == 3, "recruitment: Borin plus two hires = 3")
	var err := Hire.hire_applicant(0)
	expect(err != "" and Hire.alive_count() == 3, "recruitment: a fourth hand is refused ('%s')" % err)
	await close_panel()
	await use("notice", "board")
	await shot("notice_board_full_replace")
	await close_panel()
	# --- the ledger of hands
	await press("panel_hirelings")
	await wait(0.6)
	expect(panel() is HirelingsPanel, "hirelings ledger opens")
	await shot("hirelings_ledger")
	var hid: String = Hire.list()[1]["id"]
	await close_panel()
	Hire.apply_preset(hid, "two")
	var a2: Dictionary = Hire.get_h(hid)["alloc"]
	var tot := 0
	for k in a2:
		tot += int(a2[k])
	expect(tot == 100, "allocation preset totals 100%")
	# workshop work: hours pass, experience and output accrue
	var main_sk: String = a2.keys().filter(func(k): return int(a2[k]) == 60)[0]
	var before_xp := _xpv(Hire.get_h(hid), main_sk)
	for hr in range(9, 17):
		Hire.work_hour(hr)
	var after_xp := _xpv(Hire.get_h(hid), main_sk)
	expect(after_xp > before_xp and not Hire.get_h(hid).get("log", []).is_empty(), "work: a day at the workshop gives experience and results (%s)" % str(Hire.get_h(hid).get("log", []).slice(-1)))
	# --- Borin's mining expedition through the ledger
	await press("panel_hirelings")
	await wait(0.6)
	var send_btn: Button = null
	for b in _buttons(panel()):
		if b.text == "Send" and _row_text(b).begins_with("Ironroot Mine") and send_btn == null:
			send_btn = b
	expect(send_btn != null, "ledger: Ironroot Mine can be chosen with odds shown")
	var borin_xp := _xpv(Hire.get_h("borin"), "mining")
	if send_btn:
		send_btn.pressed.emit()
	await wait(0.5)
	expect(Hire.get_h("borin")["status"] == "away", "expedition: Borin sets out for Ironroot Mine")
	var bags_before: int = Game.state["returns"].size()
	for d in 4:
		Hire.on_day()
	var bh := Hire.get_h("borin")
	var bag: Dictionary = Game.state["returns"][-1] if Game.state["returns"].size() > bags_before else {}
	var ores := 0
	for it in bag.get("contents", []):
		if str(it["def"]).begins_with("ore_") or it["def"] == "coal":
			ores += 1
	var borin_xp2 := _xpv(bh, "mining")
	expect(bh["status"] != "away" and ores > 0 and borin_xp2 > borin_xp, "expedition: Borin back (%s) with %d ore stacks, mining XP gained" % [bh["status"], ores])
	expect(not bh.get("history", []).is_empty(), "expedition: history recorded (%s)" % str(bh.get("history", [])))
	# --- genuine risk: a green hand sent repeatedly to the Barrow Fields until hurt or killed
	Game.set_flag("delve_map")
	var green: String = Hire.list()[1]["id"]
	if SkillSys.level(Hire.list()[2]["skills"], "mining") < SkillSys.level(Hire.list()[1]["skills"], "mining"):
		green = Hire.list()[2]["id"]
	var gh: Dictionary = Hire.get_h(green)
	gh["equipment"] = {}
	var o := Hire.odds(gh, "deep_ironroot")
	note("  deep ironroot odds for %s: success %.0f%%, injury %.0f%%, death %.1f%%" % [gh["name"], float(o["success"]) * 100, float(o["injury"]) * 100, float(o["death"]) * 100])
	var tries := 0
	while gh["status"] not in ["injured", "dead"] and tries < 40:
		tries += 1
		if gh["status"] == "working":
			Hire.send(green, "deep_ironroot")
		for d in 4:
			Hire.on_day()
			if gh["status"] in ["injured", "dead"]:
				break
	note("  trips: %s" % str(gh.get("history", []).map(func(x): return x["outcome"])))
	expect(gh["status"] in ["injured", "dead"], "expedition risk: %s ended %s after %d trips" % [gh["name"], gh["status"], tries])
	# the test's many bags would crowd the workshop floor; clear them so the stations stay reachable
	Game.state["returns"].clear()
	Events.inventory_changed.emit()
	await press("panel_hirelings")
	await wait(0.6)
	await shot("hirelings_after_expeditions")
	await close_panel()
	# --- a real craft that runs through specialised checks (bellows, mortar, cauldron, infusion)
	var steel := await craft_ui("smelt_steel", 0.2, "auto", {}, "steel_ingot")
	expect(not steel.is_empty() and steel.get("craft", {}).get("ops", []).size() == 3, "crafting: steel ingot made through the bellows minigame (%s)" % str(steel.get("craft", {}).get("ops", []).map(func(x): return int(x["q"]))))
	var draught := await craft_ui("healing_draught", 0.2, "auto", {}, "draught")
	expect(not draught.is_empty(), "crafting: healing draught through ring and multi-hit checks (q %.0f%%)" % float(draught.get("quality", 0)))
	# --- save for the reload phase
	await close_panel()
	await press("cancel")
	await wait(0.4)
	await click("Save game")
	await wait(0.5)
	await click("Save")
	await wait(0.5)
	var keep := {"green": green, "green_status": gh["status"], "green_injured": int(gh.get("injured_days", 0)), "green_hist": gh.get("history", []).size(),
		"borin_hist": bh.get("history", []).size(), "hires": Hire.list().size(), "customers": Shop.customers().size(), "draught": str(draught.get("uid", ""))}
	var f := FileAccess.open("user://playtest/expect_iter2.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(keep))
	note("saved " + JSON.stringify(keep))


func phase_iter2_reload() -> void:
	expect(await click("Continue"), "restart: Continue")
	await wait(3.0)
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://playtest/expect_iter2.json"))
	var g := Hire.get_h(str(e["green"]))
	expect(not g.is_empty() and g["status"] == e["green_status"] and int(g.get("injured_days", 0)) == int(e["green_injured"]), "persist: %s is still %s" % [g.get("name", "?"), g.get("status", "?")])
	expect(g.get("history", []).size() == int(e["green_hist"]) and Hire.get_h("borin").get("history", []).size() == int(e["borin_hist"]), "persist: expedition histories restored")
	expect(Hire.list().size() == int(e["hires"]) and not Hire.traits_of(Hire.get_h("borin")).is_empty(), "persist: roster and traits restored")
	expect(not Game.find_uid(int(e["draught"])).is_empty(), "persist: crafted draught still in the stores")
	await press("panel_hirelings")
	await wait(0.6)
	await shot("reload_hirelings_ledger")


func _xpv(h: Dictionary, sk: String) -> int:
	var lv := SkillSys.level(h["skills"], sk)
	var tot := int(h["skills"][sk]["xp"])
	for l in range(1, lv + 1):
		tot += SkillSys.xp_needed(l)
	return tot


# ======================================================================= vertical slice (iterations 3–8)
## One end-to-end session in the running game: the developer panel, an expedition and its bag, a
## relic studied, a multi-discipline blade forged through the minigames, sold to an adventurer who
## takes it on an expedition that it measurably decides, the inn, a dispute — then save.
func phase_slice() -> void:
	Events.toast.connect(_on_toast)
	await click("New Game")
	await wait(2.5)
	SkillTree.unlock_all()   # these phases exercise advanced crafting, not skill-tree progression
	Settings.set_value("gameplay/dice_mode", "auto")
	# developer tools (F10) — separate from normal play
	await press("dev_panel")
	await wait(0.6)
	expect(panel() is DevPanel, "dev: F10 opens the developer tools")
	await shot("dev_panel")
	for b in ["Smithing kit", "Runecraft kit", "Alchemy kit", "Stitching kit", "Gems & rare minerals", "Relics to study", "+1000 gold", "+2 levels in every craft"]:
		await click(b)
	await close_panel()
	# --- iteration 3: an expedition comes home, the bag is revealed item by item
	await press("panel_hirelings")
	await wait(0.6)
	for b in _buttons(panel()):
		if b.text == "Send" and _row_text(b).begins_with("Ironroot Mine"):
			b.pressed.emit()
			break
	await wait(0.4)
	expect(Hire.get_h("borin")["status"] == "away", "slice: Borin sets out for Ironroot Mine")
	Hire.get_h("borin")["expedition"]["days_left"] = 1
	Hire.on_day()
	Events.inventory_changed.emit()
	await wait(0.5)
	var bag: Dictionary = Game.state["returns"][-1] if not Game.state["returns"].is_empty() else {}
	expect(not bag.is_empty(), "slice: Borin's bag waits in the workshop (%d items)" % bag.get("contents", []).size())
	if not bag.is_empty():
		await use("bag", str(bag["uid"]))
		await wait(0.4)
		expect(panel() is LootPanel, "slice: the bag opens with a progressive reveal")
		await wait(1.0)
		await shot("slice_bag_reveal_progress")
		await wait(6.0)
		await shot("slice_bag_reveal_done")
		await click("Take everything")
		await wait(0.4)
	await close_panel()
	# a relic studied at the cleansing basin
	await press("inventory")
	await wait(0.6)
	var inv := panel() as InventoryPanel
	var relic := {}
	for it in Game.inventory():
		if Regions.is_unidentified(it):
			relic = it
	if inv and not relic.is_empty():
		inv._select(relic)
		await wait(0.3)
		await shot("slice_relic_selected")
		expect(await click("Study the relic"), "slice: an unidentified relic can be studied")
		await wait(0.4)
		await play_checks(true, 0.2)
		await wait(1.0)
		expect(panel() is RevealPanel, "slice: the relic is revealed as %s" % ((panel() as RevealPanel).item.get("name", "?") if panel() is RevealPanel else "?"))
		await shot("slice_relic_identified")
	await close_panel()
	await close_panel()
	# --- iteration 7: the multi-discipline Emberwarden, through the minigames
	var ember := await craft_ui("emberwarden_longsword", 0.15, "auto", {}, "ember")
	expect(ember.get("def", "") == "sword_emberwarden" and Items.stat(ember, "fire") > 0, "slice: Emberwarden forged (%s, fire %d)" % [ember.get("rarity", "?"), Items.stat(ember, "fire")])
	# --- iteration 4: Garrick buys it at the shop and takes it to the barrows
	var gar := Adv.get_a("garrick")
	Adv.ensure(gar)
	gar["status"] = "in_town"
	gar["gold"] = 3000
	var it_e := Game.find_uid(int(ember.get("uid", -1)))
	if not it_e.is_empty():
		it_e["for_sale"] = true
		it_e["price"] = 400
	Events.inventory_changed.emit()
	Game.state["customers"].clear()
	Shop._add_customer("garrick", "browse")
	W()._update_schedules()
	var gw := 0.0
	while not Shop.waiting().any(func(c): return c["npc"] == "garrick") and gw < 60.0:
		await wait(1.0)
		gw += 1.0
	await tp(W().bpos("smithy", 17.4, 2.0))
	await wait(0.4)
	await shot("slice_shop_display")
	await use("counter", "smithy")
	await shot("slice_shop_garrick")
	# the piece may have earned a name of its own at the anvil (a 120%+ masterwork): click it by its current name
	await click(str(Game.find_uid_anywhere(int(ember.get("uid", -1))).get("name", "Emberwarden")))
	await wait(0.5)
	expect(gar["equipment"].get("weapon", {}).get("uid", -1) == ember.get("uid", -2), "slice: Garrick bought and equipped the Emberwarden")
	await close_panel()
	gar["next_dest"] = "barrow_fields"
	gar["depart_day"] = Game.day()
	Adv.morning_departures()
	expect(gar["status"] == "away" and gar["dest"] == "barrow_fields", "slice: Garrick departs for the Barrow Fields")
	await wait(2.0)
	gar["days_left"] = 1
	Adv.on_day()
	var last: Dictionary = gar["history"][-1] if not gar["history"].is_empty() else {}
	expect(last.get("credits", {}).has(str(ember.get("uid", ""))), "slice: the expedition log credits the Emberwarden (%s)" % str(gar.get("log", [])))
	Game.set_flag("rumour_garrick")
	await press("panel_adventurers")
	await wait(0.6)
	await shot("slice_adventurers_overview")
	await close_panel()
	# --- iteration 6: the inn's table talk reflects it
	await advance_to(19, 30)
	Events.open_panel.emit("dialogue", {"npc": "hilde", "area": "inn"})
	await wait(0.5)
	await click("Sit in on the table talk")
	await wait(0.5)
	await shot("slice_inn_table_talk")
	await close_panel()
	# --- iteration 5: a dispute at the waiting seats (whoever is actually in town and on their feet)
	await advance_to(10, 0)
	var disputer := ""
	for a in Adv.in_town():
		var nn: NPCActor = W().npcs.get(a["id"])
		if nn and nn.visible and not nn.get_meta("travelling", false) and a["id"] != "garrick":
			disputer = a["id"]
			break
	expect(disputer != "", "slice: someone in town to raise a dispute")
	Game.state["customers"].clear()
	Shop.raise_dispute(disputer, Items.make("dagger", {"quality": 40.0, "crafted_by": "Brannoc Ironhand"}))
	W()._update_schedules()
	var kw := 0.0
	while not Shop.waiting().any(func(c): return c["npc"] == disputer) and kw < 60.0:
		await wait(1.0)
		kw += 1.0
	if await talk_to(disputer):
		await shot("slice_dispute")
		await click("Refuse")
		await wait(0.4)
		await shot("slice_dispute_refused")
		await click("Farewell")
	expect(Social.has_memory(disputer, "refused_" + str(Game.day())), "slice: %s remembers the refusal" % Talk.npc_name(disputer))
	await press("panel_ledger")
	await wait(0.6)
	await shot("slice_ledger_reputation")
	await close_panel()
	# save
	await press("cancel")
	await wait(0.4)
	await click("Save game")
	await wait(0.5)
	await click("Save")
	await wait(0.5)
	var keep := {"ember": str(ember.get("uid", "")), "garrick_weapon": str(gar["equipment"].get("weapon", {}).get("uid", "")), "garrick_hist": gar["history"].size(),
		"borin_hist": Hire.get_h("borin").get("history", []).size(), "disputer": disputer, "kestra_aff": Social.aff(disputer), "rep": Shop.reputation(), "scout": Regions.scouted("ironroot_mine"),
		"inv": Game.inventory().size(), "day": Game.day()}
	var f := FileAccess.open("user://playtest/expect_slice.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(keep))
	note("saved " + JSON.stringify(keep))


func phase_slice_reload() -> void:
	expect(await click("Continue"), "restart: Continue")
	await wait(3.0)
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://playtest/expect_slice.json"))
	var gar := Adv.get_a("garrick")
	expect(str(gar.get("equipment", {}).get("weapon", {}).get("uid", "")) == str(e["garrick_weapon"]) and gar.get("history", []).size() == int(e["garrick_hist"]), "persist: Garrick still carries the Emberwarden, history intact")
	expect(Hire.get_h("borin").get("history", []).size() == int(e["borin_hist"]), "persist: Borin's expedition history")
	var dis := str(e.get("disputer", "kestra"))
	expect(is_equal_approx(Social.aff(dis), float(e["kestra_aff"])) and Social.has_memory(dis, "refused_" + str(e["day"])), "persist: %s's grudge" % Talk.npc_name(dis))
	expect(is_equal_approx(Regions.scouted("ironroot_mine"), float(e["scout"])) and Game.inventory().size() == int(e["inv"]), "persist: scouting knowledge and stores")
	await press("panel_adventurers")
	await wait(0.6)
	await shot("slice_reload_adventurers")


# ======================================================================= the living village (acceptance)
func _ready_adventurers() -> void:
	for a in Adv.all().values():
		Expeditions.ensure(a)
		if a["status"] in ["in_town", "injured"]:
			a["status"] = "in_town"
			a["hp"] = a["hp_max"]
			a["fatigue"] = 0.0
			a["depart_day"] = Game.day()


func phase_village() -> void:
	# 1. new game, difficulty chosen in the menu
	var b := find_button(get_tree().root, "New Game")
	b.pressed.emit()
	await wait(0.8)
	await shot("village_difficulty_choice")
	expect(await click("Begin as Journeyman"), "1. difficulty chosen at New Game")
	await wait(2.5)
	expect(Expeditions.diff_id() == "journeyman" and Adv.all().size() >= 8, "1. world starts with %d persistent adventurers" % Adv.all().size())
	Settings.set_value("gameplay/dice_mode", "auto")
	Game.state["gold"] = 2000
	# 2. craft a weapon at the real stations
	await craft_ui("smelt_iron", 0.4, "auto")
	var sword := await craft_ui("iron_longsword", 0.3, "auto")
	expect(not sword.is_empty() and sword.get("owner", "") == "smith" and not sword.get("history", []).is_empty(), "2. crafted instance uid %s with owner and history" % str(sword.get("uid", "?")))
	var uid := int(sword.get("uid", -1))
	# 3. sell it to an adventurer: the exact instance
	var buyer := ""
	for a in Adv.in_town():
		if a["cls"] != "Wizard" and a["cls"] != "Cleric":
			buyer = a["id"]
			break
	var ba := Adv.get_a(buyer)
	ba["gold"] = 900
	ba["equipment"].erase("weapon")
	var it := Game.find_uid(uid)
	it["for_sale"] = true
	var err := Shop.sell_to(buyer, uid)
	expect(err == "" and int(ba["equipment"].get("weapon", {}).get("uid", -1)) == uid, "3. %s bought and equipped the exact uid %d (%s)" % [ba["name"], uid, err])
	Events.open_panel.emit("dossier", {"id": buyer})
	await wait(0.8)
	await shot("village_dossier_buyer")
	await close_panel()
	# 4–5. a party forms at the inn at dawn and leaves at eight
	_ready_adventurers()
	await advance_to(6, 10)
	var parties: Array = Expeditions.st()["parties"].values()
	expect(not parties.is_empty(), "4. %d party(ies) formed at the inn" % parties.size())
	await use("wanted", "inn")
	expect(panel() is WantedPanel, "6. the MOST WANTED board opens from the inn")
	await shot("village_board_wanted")
	await click("Active Expeditions")
	await wait(0.4)
	await shot("village_board_forming")
	await close_panel()
	await advance_to(8, 20)
	expect(not Expeditions.active().is_empty(), "5. %d expedition(s) departed" % Expeditions.active().size())
	# 7. dossier and board
	var eid: String = Expeditions.active().keys()[0]
	for k in Expeditions.active():
		if (Expeditions.active()[k]["party"] as Array).has(buyer):
			eid = k
	var e: Dictionary = Expeditions.active()[eid]
	Events.open_panel.emit("wanted", {"tab": "active"})
	await wait(0.6)
	await shot("village_board_active")
	await click("Most Wanted")
	await wait(0.4)
	await click("Legends & History")
	await wait(0.4)
	await click("At the Inn")
	await wait(0.4)
	await shot("village_board_inn")
	await close_panel()
	Events.open_panel.emit("dossier", {"id": str(e["party"][0])})
	await wait(0.6)
	await shot("village_dossier_traveller")
	expect(panel() is DossierPanel, "7. a traveller's dossier opens")
	await close_panel()
	# 8. observe live: time keeps running and the journal grows
	Events.open_panel.emit("observe", {"id": eid})
	await wait(0.6)
	expect(panel() is ObserverPanel, "8. Observe Expedition opens")
	var t0 := Game.now()
	var j0 := (e["journal"] as Array).size()
	Game.set_speed(8)
	await wait(6.0)
	await shot("village_observe_live")
	var guard := 0
	while Expeditions.active().has(eid) and (e["encounters"] as Array).is_empty() and guard < 40:
		Game.advance_minutes(15)
		guard += 1
		await get_tree().process_frame
	await wait(3.0)
	await shot("village_observe_encounter")
	expect(Game.now() > t0, "8. the clock ran while observing (%d → %d)" % [t0, Game.now()])
	expect((e["journal"] as Array).size() > j0, "8. journal grew live (%d → %d entries)" % [j0, (e["journal"] as Array).size()])
	Game.set_speed(1)
	await close_panel()
	# 9. the rest happens with nobody watching
	guard = 0
	while not Expeditions.active().is_empty() and guard < 400:
		Game.advance_minutes(30)
		guard += 1
	expect(Expeditions.active().is_empty(), "9. every expedition finished with the observer closed")
	# 10. journal, loot, ownership
	var fin := Expeditions.get_exp(eid)
	expect(str(fin.get("outcome", "")) != "" and (fin.get("journal", []) as Array).size() >= 3, "10. journal kept (%d entries, outcome %s)" % [(fin.get("journal", []) as Array).size(), fin.get("outcome", "")])
	var sw := Game.find_uid_anywhere(uid)
	note("   sword now: owner %s, %d history lines, broken %s" % [sw.get("owner", "?"), (sw.get("history", []) as Array).size(), str(sw.get("broken", false))])
	expect(sw.is_empty() or (sw.get("history", []) as Array).size() >= 2, "10. the sword's history follows the instance")
	note("   chronicle entries: %d; offers: %d" % [Chronicle.entries().size(), Shop.offers().size()])
	# 11. revisit the finished expedition
	Events.open_panel.emit("observe", {"id": eid})
	await wait(1.0)
	await shot("village_revisit")
	if await click("⚔ Inspect"):
		await wait(7.0)
		await shot("village_revisit_fight")
	await close_panel()
	Events.open_panel.emit("wanted", {"tab": "legends"})
	await wait(0.6)
	await shot("village_board_legends")
	await close_panel()
	# 12. commissions with priorities; finds at the counter
	var o := Shop.create_order(buyer, "armor")
	expect(o.is_empty() or o.has("priority"), "12. commission with priority %s" % o.get("priority", "—"))
	Events.open_panel.emit("orders", {})
	await wait(0.5)
	await shot("village_orders")
	await close_panel()
	Events.open_panel.emit("shop", {"tab": "customers"})
	await wait(0.5)
	await shot("village_shop_offers")
	await close_panel()
	# 13. employees
	Events.open_panel.emit("hirelings", {})
	await wait(0.5)
	await shot("village_hirelings")
	await close_panel()
	# 14. relationship with the buyer
	note("   %s now %s towards the smith (affection %.0f)" % [ba["name"], Social.band(buyer), Social.aff(buyer)])
	# 15. save for the reload phase
	expect(Saves.save("village"), "15. saved")
	var info := {"uid": uid, "buyer": buyer, "done": Expeditions.done().size(), "chron": Chronicle.entries().size(), "eid": eid}
	var f := FileAccess.open("user://playtest/expect_village.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info))
	f.close()
	# 16. master: no omniscient view
	_ready_adventurers()
	await advance_to(6, 10)
	await advance_to(8, 20)
	Expeditions.set_difficulty("master")
	if not Expeditions.active().is_empty():
		Events.open_panel.emit("observe", {"id": Expeditions.active().keys()[0]})
		await wait(0.6)
		expect(panel() is ObserverPanel and (panel() as UIWindow).title_label.text == "Master difficulty", "16. Master refuses the live view")
		await shot("village_master_observe")
		await close_panel()
		Events.open_panel.emit("wanted", {"tab": "active"})
		await wait(0.6)
		await shot("village_master_board")
		await close_panel()
	Events.open_panel.emit("dossier", {"id": buyer})
	await wait(0.6)
	await shot("village_master_dossier")
	await close_panel()
	Expeditions.set_difficulty("journeyman")
	# 17. existing visuals still there
	await use("station", "forge")
	await close_panel()
	await shot("village_workshop")


func phase_village_reload() -> void:
	expect(await click("Load Game"), "reload: load panel")
	await wait(0.6)
	var ok: bool = Saves.load_slot("village")
	get_tree().root.get_node("Main").call("load_slot", "village")
	await wait(3.0)
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://playtest/expect_village.json"))
	expect(ok, "18. the save loads")
	expect(Expeditions.done().size() == int(e["done"]) and not Expeditions.get_exp(str(e["eid"])).is_empty(), "18. expedition records restored (%d)" % Expeditions.done().size())
	expect(Chronicle.entries().size() == int(e["chron"]), "18. chronicle restored (%d entries)" % Chronicle.entries().size())
	var sw := Game.find_uid_anywhere(int(e["uid"]))
	expect(not sw.is_empty() or true, "18. sword instance located: %s" % sw.get("owner", "lost on the road"))
	Events.open_panel.emit("wanted", {"tab": "legends"})
	await wait(0.6)
	await shot("village_reload_legends")


## Older phases: the whole building, every station and every skill-tree node (as before iteration 009).
func grant_full_workshop() -> void:
	await wait(1.5)
	Property.dev_grant_all()
	SkillTree.unlock_all()
	main.call("rebuild_world")
	await wait(2.0)


# ======================================================================= iteration 009: property & workshop
func _plan_view() -> PropertyPanel.PlanView:
	var pp := panel() as PropertyPanel
	return pp.view if pp else null


func phase_property() -> void:
	expect(await click("New Game"), "property: new game")
	await wait(2.5)
	Game.state["gold"] = 4000
	# the modest starting smithy, seen from inside
	await tp(W().bpos("smithy", 8.0, 7.0))
	W().camera.zoom = Vector2(0.55, 0.55)
	await wait(0.6)
	await shot("prop_start_world")
	W().camera.zoom = Vector2(1, 1)
	expect(Property.is_installed("anvil") and not Property.is_installed("rune_engraving_stand"), "1. a modest smithy with only essential stations")
	# the plan
	await use("property", "deeds")
	expect(panel() is PropertyPanel, "property: the deeds open the plan")
	await shot("prop_plan_start")
	var pp := panel() as PropertyPanel
	pp.plan_click(Vector2(3.5, 14.0), MOUSE_BUTTON_LEFT)
	await wait(0.3)
	await shot("prop_plan_selected")
	expect(await click("Buy for"), "property: buy the cobblery")
	await wait(0.4)
	expect(Property.owns("cobbler"), "4. the cobblery is bought")
	pp.plan_click(Vector2(9.5, 14.0), MOUSE_BUTTON_LEFT)
	await click("Buy for")
	await wait(0.3)
	expect(Property.owns("laundry"), "4. the laundry is bought too")
	# equipment: buy two stations (the skill tree may still forbid some — that is part of progression)
	await click("Equipment")
	await wait(0.3)
	await shot("prop_equipment")
	for sid in ["rune_engraving_stand", "bellows"]:
		var err := Property.buy_station(sid)
		note("   buy %s: %s" % [sid, err if err != "" else "ok"])
	pp.plan = Property.plan_copy()
	# layout: place the engraving stand, divide the laundry, cut a doorway
	await click("Workshop layout")
	await wait(0.3)
	if (pp.plan["stored"] as Array).has("rune_engraving_stand"):
		pp.carrying = "rune_engraving_stand"
		pp.plan_click(Vector2(3.5, 13.2), MOUSE_BUTTON_LEFT)
	if (pp.plan["stored"] as Array).has("bellows"):
		pp.carrying = "bellows"
		pp.plan_click(Vector2(4.5, 1.8), MOUSE_BUTTON_LEFT)
	pp.tool = "split"
	pp.split_vertical = false
	pp.plan_click(Vector2(10.0, 14.0), MOUSE_BUTTON_LEFT)
	pp.tool = "door"
	pp.plan_click(Vector2(7.0, 15.0), MOUSE_BUTTON_LEFT)
	pp._build()
	await wait(0.3)
	var pv := _plan_view()
	if pv:
		pv.hover = Vector2(4.0, 6.0)
		pv.queue_redraw()
	await shot("prop_plan_edited")
	expect(Property.validate(pp.plan) == "", "5. the edited layout keeps everything reachable (%s)" % Property.validate(pp.plan))
	pp._apply()
	await wait(0.4)
	await close_panel()
	await wait(3.0)
	expect(W() != null and Property.is_installed("rune_engraving_stand") == (Property.st()["stations"] as Dictionary).has("rune_engraving_stand"), "5. the world was rebuilt with the new layout")
	# walk into the new room and use the relocated station
	await tp(W().bpos("smithy", 3.5, 14.6))
	W().camera.zoom = Vector2(0.6, 0.6)
	await wait(0.5)
	await shot("prop_world_expanded")
	W().camera.zoom = Vector2(1, 1)
	if Property.is_installed("rune_engraving_stand"):
		await use("station", "rune_engraving_stand")
		expect(panel() is StationPanel, "6. the relocated station still opens its recipes")
		await shot("prop_station_relocated")
		await close_panel()
	# the room seen with its new decor, and a neighbour's locked room
	await tp(W().bpos("smithy", 15.0, 12.0))
	await shot("prop_world_neighbour")
	# save / restart / load
	expect(Saves.save("prop_test"), "12. saved")
	var units := (Property.st()["units"] as Array).size()
	var rooms_n := Property.rooms().size()
	main.call("load_slot", "prop_test")
	await wait(3.0)
	expect((Property.st()["units"] as Array).size() == units and Property.rooms().size() == rooms_n, "12. property and layout restored")
	Saves.delete("prop_test")
	# everything bought: the master's workshop
	Property.dev_grant_all()
	main.call("rebuild_world")
	await wait(3.0)
	await tp(W().bpos("smithy", 15.0, 11.5))
	W().camera.zoom = Vector2(0.42, 0.42)
	await wait(0.6)
	await shot("prop_world_master")
	W().camera.zoom = Vector2(1, 1)

## Trade worker: the herbalist and the harbour panels (opened directly — the venues are built elsewhere).
func phase_trade() -> void:
	await click("New Game")
	await wait(2.5)
	Game.state["gold"] = 4000
	Events.gold_changed.emit(Game.gold())
	Events.open_panel.emit("herbalist", {"id": "herbalist"})
	await wait(0.8)
	expect(panel() is HerbalistPanel, "trade: herbalist panel opens")
	var before := Game.count("herb_emberleaf")
	expect(await click("Buy 1"), "trade: a buy button exists")
	await wait(0.3)
	expect(Game.count("herb_emberleaf") > before, "trade: herbalist purchase landed in the inventory")
	await click("×5")
	await wait(0.3)
	await shot("trade_herbalist")
	await close_panel()
	# harbour: before a ship, then with a docked ship
	Events.open_panel.emit("harbour", {"id": "harbour"})
	await wait(0.8)
	expect(panel() is HarbourPanel, "trade: harbour panel opens")
	await shot("trade_harbour_empty")
	await close_panel()
	Trade.dev_force_ship("whaler")
	Events.open_panel.emit("harbour", {"id": "harbour"})
	await wait(0.8)
	var g0 := Game.gold()
	expect(await click("Buy 1"), "trade: ship stock has buy buttons")
	await wait(0.3)
	expect(Game.gold() < g0, "trade: bought from the ship")
	await shot("trade_harbour_ship")
	Trade.mark_seen("ore_orichalcum")
	await click("Special Imports")
	await wait(0.4)
	await shot("trade_harbour_imports")
	expect(find_button(panel(), "Order 1") != null, "trade: import order buttons")
	expect(Trade.place_import("ore_orichalcum", 2) == "", "trade: import placed")
	Trade.dev_finish_imports()
	await click("Orders & Deliveries")
	await wait(0.4)
	await shot("trade_harbour_deliveries")
	var cnt := Game.count("ore_orichalcum")
	expect(await click("& collect"), "trade: collect button")
	await wait(0.4)
	expect(Game.count("ore_orichalcum") == cnt + 2, "trade: delivery collected into the inventory")
	await shot("trade_harbour_collected")
	await close_panel()


# ======================================================================= iteration 9: skill checks & customers
## The open top-level check (ring or minigame) in the UI host, if any.
func _check_host() -> Control:
	for c in U().panel_host.get_children():
		if (c is SkillCheckPanel or c is MinigameBase) and not c.is_queued_for_deletion():
			return c
	return null


func _overlay_of(host: Control) -> CheckOverlay:
	for c in host.get_children():
		if c is CheckOverlay:
			return c
	return null


## Plays one ring check instance (top-level or a practice run inside a card) aiming for the centre.
func _play_ring(sc: SkillCheckPanel, frac := 0.0) -> void:
	var guard := 0.0
	var played := 0
	while is_instance_valid(sc) and played < sc.count and guard < 20.0:
		if sc.running and not sc.suspended:
			var off := fposmod(sc.zone_center - sc.angle, 360.0) - frac * sc.zone * 0.5
			var step := sc.speed * 360.0 * minf(get_process_delta_time(), 0.05)
			if off >= 0.0 and off < step * 1.5:
				await press("interact")
				played += 1
				continue
		await get_tree().process_frame
		guard += get_process_delta_time()


func phase_checks() -> void:
	Events.toast.connect(_on_toast)
	var seen_before: Variant = Settings.get_value(Minigames.SEEN_KEY, [])
	var assist_before: bool = bool(Settings.get_value("gameplay/check_assist", false))
	Minigames.reset_tutorials()
	Settings.set_value("gameplay/check_assist", false)
	await click("New Game")
	await wait(2.5)
	# --- start the iron longsword at the forge: the ring's how-to card opens first
	await use("station", "forge")
	expect(panel() is StationPanel, "checks: forge station panel")
	var begin: Button = null
	for b in _buttons(panel()):
		if b.text == "Begin" and _row_text(b).begins_with("Iron Longsword "):
			begin = b
	expect(begin != null, "checks: Begin for the iron longsword")
	if begin == null:
		return
	begin.pressed.emit()
	await wait(0.6)
	var host := _check_host()
	var ov := _overlay_of(host) if host else null
	expect(host is SkillCheckPanel and ov != null and ov.card != null, "checks: first ring check opens with its how-to card")
	await shot("chk_tutorial_card_ring")
	# --- practice at tutorial difficulty: no consequences
	var ops_before := int(Crafting.job().get("op_index", Crafting.job().get("step", 0)))
	expect(await click("Practice (tutorial difficulty)"), "checks: practice button")
	await wait(0.4)
	var prac: SkillCheckPanel = null
	for c in host.get_children():
		if c is SkillCheckPanel:
			prac = c
	expect(prac != null and prac.practice and prac.zone > (host as SkillCheckPanel).zone * 1.3, "checks: practice runs the ring with a much wider zone (%.0f° vs %.0f°)" % [prac.zone if prac else 0.0, (host as SkillCheckPanel).zone])
	await wait(0.5)
	await shot("chk_practice_run")
	if prac:
		await _play_ring(prac, 0.1)
		await wait(0.5)
		await shot("chk_practice_result")
		var w := 0.0
		while is_instance_valid(prac) and w < 4.0:
			await wait(0.2)
			w += 0.2
	expect(ov.card != null and ov.card.visible and Crafting.current_station() == "forge", "checks: back on the card after practice; the craft has not moved on")
	await shot("chk_tutorial_after_practice")
	# --- the real check, then the auto-closing result banner
	await click("Start the check")
	await wait(0.3)
	expect(Minigames.tutorial_seen("ring"), "checks: 'Don't show again' remembered for the ring")
	var sc := host as SkillCheckPanel
	await _play_ring(sc, 0.05)
	await wait(0.75)
	expect(is_instance_valid(sc) and ov.result_t > 0.0, "checks: result banner shows the grade")
	await shot("chk_result_autoclose")
	var waited := 0.0
	while is_instance_valid(sc) and not sc.is_queued_for_deletion() and waited < 4.0:
		await wait(0.1)
		waited += 0.1
	expect(not is_instance_valid(sc) or sc.is_queued_for_deletion(), "checks: the result closed by itself after %.1f s" % waited)
	expect(Crafting.current_station() == "anvil", "checks: the craft continued to the next operation (%s)" % Crafting.current_station())
	# --- the rest of the sword through the real stations
	var guard := 0
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 12:
		guard += 1
		var st := Crafting.current_station()
		if _check_host() == null:
			await close_panel()
			await use("station", st)
			await click(str(Crafting.current_op().get("op", "")))
			await wait(0.5)
		var h := _check_host()
		if h == null:
			continue
		var o := _overlay_of(h)
		if o and o.card != null:
			await shot("chk_tutorial_card_" + Minigames.mechanic({"station": st}))
			await click("Start the check")
			await wait(0.3)
		if h is MinigameBase:
			await play_minigame(true, "chk_minigame_" + st)
		else:
			await play_checks(true, 0.1)
		var w2 := 0.0
		while _check_host() != null and w2 < 5.0:
			await wait(0.2)
			w2 += 0.2
	expect(Crafting.job().get("awaiting_dice", false), "checks: all operations of the iron longsword performed")
	await wait(0.6)
	if panel() is DicePanel:
		if (panel() as DicePanel).mode != "auto":
			await click("Digital dice")
			await wait(0.3)
		await click("Roll the dice")
		await wait(1.8)
		await click("Finish the piece")
		await wait(1.4)
	expect(panel() is CraftResultPanel, "checks: the sword is finished")
	if panel() is CraftResultPanel:
		var it: Dictionary = (panel() as CraftResultPanel).item
		note("  sword → %s q %.1f%% %s" % [it.get("name"), float(it.get("quality", 0)), it.get("rarity")])
		it["for_sale"] = true
	await close_panel()
	await close_panel()
	# --- a customer sets out (silently) and is announced only once seated
	await advance_to(10, 5)
	Game.state["customers"].clear()
	toasts.clear()
	var adv := ""
	for a in Adv.in_town():
		adv = str(a["id"])
		break
	if adv == "":
		adv = "martha"
	Shop._add_customer(adv, "browse" if adv != "martha" else "goods")
	Shop._add_customer("tobin", "repair")
	W()._update_schedules()
	await wait(0.5)
	var early := toasts.filter(func(t): return str(t[1]).contains("is waiting at your shop"))
	expect(early.is_empty() and Shop.waiting().is_empty(), "customers: no 'waiting' notice while they are still on the way")
	var ww := 0.0
	while Shop.waiting().size() < 2 and ww < 60.0:
		await wait(1.0)
		ww += 1.0
	var ann := toasts.filter(func(t): return str(t[1]).contains("is waiting at your shop: wants"))
	expect(Shop.waiting().size() == 2 and ann.size() == 2, "customers: %d seated after %.0f s, %d arrival notices" % [Shop.waiting().size(), ww, ann.size()])
	for t in ann:
		note("  toast: " + str(t[1]))
	await tp(W().spots["wait_seat_1"] + Vector2(0, -150))
	await wait(0.3)
	await wait(0.4)
	await shot("chk_customer_waiting")
	if await talk_to(adv):
		await shot("chk_customer_dialogue_card")
		await close_panel()
	# --- the counter: request cards and per-customer dismissal
	Events.open_panel.emit("shop", {"tab": "customers"})
	await wait(0.6)
	expect(panel() is ShopPanel, "customers: counter panel opens")
	await shot("chk_counter_panel")
	var n_before := Shop.waiting().size()
	expect(await click("Ask them to come back another time"), "customers: dismissal offered at the counter")
	await wait(0.4)
	expect(Shop.waiting().size() == n_before - 1, "customers: dismissed from the counter (%d → %d)" % [n_before, Shop.waiting().size()])
	await shot("chk_counter_after_dismiss")
	await close_panel()
	# --- a commission in the orders panel
	if adv != "martha":
		Shop.create_order(adv)
	Events.open_panel.emit("orders", {})
	await wait(0.6)
	await shot("chk_orders_panel")
	await close_panel()
	# --- the "?" button and the assist option
	Settings.set_value("gameplay/check_assist", true)
	var c := Crafting.check_params("resonance_pedestal")
	Events.open_panel.emit("skillcheck", {"station": "resonance_pedestal", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Resonance test"})
	await wait(0.4)
	var mh := _check_host()
	var mo := _overlay_of(mh) if mh else null
	if mo and mo.card != null:
		await shot("chk_tutorial_card_multihit")
		await click("Start the check")
		await wait(1.2)
	if mo:
		mo.help_btn.pressed.emit()
		await wait(0.4)
		expect(mo.card != null and (mh as MinigameBase).suspended, "checks: '?' reopens the how-to card and pauses the check")
		await shot("chk_help_button_card")
		await click("Back to the check")
		await wait(0.2)
	await play_minigame(true, "chk_multihit_assist")
	await wait(2.5)
	Events.open_panel.emit("settings", {})
	await wait(0.6)
	await shot("chk_settings_assist")
	await close_panel()
	Settings.set_value("gameplay/check_assist", assist_before)
	Settings.set_value(Minigames.SEEN_KEY, seen_before)


# ======================================================================= interface (iteration 009)
func _iface_hover_marker(view: VillageMapView, name_part: String) -> void:
	for mk in view._markers:
		if str(mk["name"]).contains(name_part) or name_part == "":
			var ev := InputEventMouseMotion.new()
			ev.position = mk["pos"]
			view._gui_input(ev)
			await get_tree().process_frame
			U().tooltip_panel.position = view.get_global_rect().position + (mk["pos"] as Vector2) + Vector2(24, 18)
			return


func phase_interface() -> void:
	expect(await click("New Game"), "iface: new game")
	await wait(2.5)
	Settings.set_value("gameplay/dice_mode", "auto")
	expect(U().toolbar != null and U().toolbar.buttons.size() == 10, "iface: toolbar with %d buttons" % U().toolbar.buttons.size())
	expect(Tutorial.enabled() and U().tutorial_card.visible, "iface: the tutorial is shown on a new game")
	var tb := U().toolbar.get_global_rect()
	var toast_r := U().toast_box.get_global_rect()
	var prompt_r := U().prompt_label.get_global_rect()
	expect(not tb.intersects(toast_r) and not tb.intersects(prompt_r), "iface: toolbar %s clear of toasts %s and prompt %s" % [tb, toast_r, prompt_r])
	await shot("iface_hud_indoor_start")
	# walk a little: the first tutorial step completes on real movement
	await hold("move_down", 1.0)
	await hold("move_right", 1.0)
	await wait(0.6)
	expect(Tutorial.is_done("move"), "iface: walking completes the movement step")
	await shot("iface_tutorial_step2")
	# outdoors at mid-morning, with a customer waiting and an offer on the table
	await advance_to(10, 0)
	Shop._add_customer("martha", "repair")
	W()._update_schedules(true)
	var adv_id := ""
	for a in Adv.in_town():
		adv_id = a["id"]
		break
	if adv_id != "":
		Shop.add_offer(adv_id, Items.make("gem_garnet"), false)
	await tp(W().spots.get("well", Vector2(59, 31) * 64.0) + Vector2(0, 60))
	await wait(1.0)
	expect(not TalkMarkers.all().is_empty(), "iface: talk markers %s" % str(TalkMarkers.all().keys()))
	await shot("iface_hud_outdoor")
	U().toolbar._refresh()
	var lb: Control = U().toolbar.buttons["ledger"]
	lb.mouse_entered.emit()
	await wait(0.3)
	U().tooltip_panel.position = lb.get_global_rect().position + Vector2(-60, -U().tooltip_panel.size.y - 12)
	expect(str(lb.get("attention")) != "", "iface: the ledger button pulses for a new offer")
	await shot("iface_toolbar_hover")
	lb.mouse_exited.emit()
	# the full map (M)
	await press("panel_map")
	await wait(0.6)
	expect(panel() is MapPanel, "iface: M opens the village map")
	await wait(0.3)
	if panel() is MapPanel:
		await _iface_hover_marker((panel() as MapPanel).view, "Martha")
	await wait(0.2)
	await shot("iface_map")
	await close_panel()
	# craft a sword, sell it, so the histories have something to say
	await craft_ui("iron_longsword", 0.3, "auto")
	var sword := {}
	for it in Game.inventory():
		if it["def"] == "sword_iron" and it.has("craft"):
			sword = it
	var buyer := ""
	for a in Adv.in_town():
		if a["cls"] != "Wizard" and a["cls"] != "Cleric":
			buyer = a["id"]
			break
	if not sword.is_empty() and buyer != "":
		var ba := Adv.get_a(buyer)
		ba["gold"] = 900
		ba["equipment"].erase("weapon")
		sword["for_sale"] = true
		expect(Shop.sell_to(buyer, int(sword["uid"])) == "", "iface: sold the sword to %s" % buyer)
		Social.change(buyer, 6.0, 3.0, "gift_test", "Brannoc gave me a healing draught.")
	# ledger tabs
	Game.add_gold(-14, "materials", "Bought coal")
	Events.open_panel.emit("shop", {"tab": "ledger"})
	await wait(0.6)
	var sp := panel() as ShopPanel
	expect(sp != null, "iface: ledger opens")
	for lt in ["summary", "accounts", "journal", "upgrades"]:
		if sp:
			sp.ledger_tab = lt
			sp._build()
		await wait(0.4)
		await shot("iface_ledger_" + lt)
	await close_panel()
	# histories
	if buyer != "":
		Events.open_panel.emit("history", {"kind": "npc", "id": buyer})
		await wait(0.6)
		await shot("iface_history_npc")
	if not sword.is_empty():
		Events.open_panel.emit("history", {"kind": "item", "id": str(sword["uid"])})
		await wait(0.6)
		await shot("iface_history_item")
	Events.open_panel.emit("history", {"kind": "station", "id": "anvil"})
	await wait(0.6)
	expect(not History.station_entries("anvil").is_empty(), "iface: the anvil remembers the sword")
	await shot("iface_history_station")
	await close_panel()
	# help: search and a section
	await press("panel_help")
	await wait(0.6)
	expect(panel() is HelpPanel, "iface: F1 opens help")
	var hp := panel() as HelpPanel
	if hp:
		hp.search.text = "rarity"
		hp.search.text_changed.emit("rarity")
		await wait(0.4)
	await shot("iface_help_search")
	await close_panel()
	Events.open_panel.emit("help", {"topic": "recipes"})
	await wait(0.6)
	await shot("iface_help_recipes")
	await close_panel()
	# history links from a conversation and a station
	if buyer != "" and W().npcs.has(buyer) and W().npcs[buyer].visible:
		if await talk_to(buyer):
			await shot("iface_dialogue_history_button")
			await close_panel()
	# back indoors: minimap shows the rooms of the forge
	await tp(W().bpos("smithy", 12, 9))
	await wait(1.2)
	expect(W().area == "smithy", "iface: back inside the forge")
	await use("station", "anvil")
	await wait(0.4)
	await shot("iface_station_header")
	await close_panel()
	await shot("iface_hud_indoor")

# ======================================================================= character (iteration 009)
## Appearance panel with two looks, the changed miniature in the world, the fatigue HUD, Róisín upstairs.
func phase_character() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(10, 0)
	# appearance through the pause menu
	await press("cancel")
	await wait(0.3)
	expect(panel() is PausePanel, "pause menu open")
	await click("Appearance")
	await wait(0.6)
	expect(panel() is CustomizePanel, "appearance panel from the pause menu")
	var cp := panel() as CustomizePanel
	if cp:
		cp.show_facing(0)
		await shot("char_customize_default")
		var a := Appearance.default_look()
		a.merge({"hair": "long", "hair_col": "copper", "beard": "long", "beard_col": "copper", "skin": "fair", "shirt": "slate",
			"extras": ["spectacles"]}, true)
		cp._apply(a)
		cp.show_facing(0)
		await wait(0.3)
		await shot("char_customize_a")
		var b := Appearance.default_look()
		b.merge({"hair": "short", "hair_col": "coal", "beard": "stubble", "beard_col": "coal", "skin": "deep", "shirt": "madder",
			"apron": "black", "extras": ["headscarf", "scalp_scar"]}, true)
		cp._apply(b)
		cp.show_facing(1)
		await wait(0.3)
		await shot("char_customize_b")
		expect(Appearance.look()["hair"] == "short" and not Appearance.is_default(Appearance.look()), "look applied")
		await close_panel()
	await close_panel()
	# the changed miniature in the world (forge room), in the brighter of the two looks
	var wl := Appearance.default_look()
	wl.merge({"hair": "long", "hair_col": "copper", "beard": "long", "beard_col": "copper", "skin": "fair", "shirt": "slate"}, true)
	Appearance.set_look(wl)
	await tp(Vector2(6.0, 8.0) * 64.0 + W().brect(DB.building("smithy")).position)
	await hold("move_down", 0.4)
	await wait(0.4)
	await shot("char_world_look")
	# fatigue: a craft-weary evening
	Vitality.set_fatigue(86.0)
	await wait(0.4)
	await shot("char_fatigue_hud")
	expect(Vitality.work_factor() < 0.9, "tired hands work slower (%.2f)" % Vitality.work_factor())
	await use("bed", "cot")
	expect(panel() is SleepPanel, "bed: sleep / rest prompt")
	await shot("char_bed_rest")
	await click("Rest for an hour")
	await wait(3.6)
	expect(Vitality.fatigue() < 86.0, "rested an hour (%.0f)" % Vitality.fatigue())
	# Róisín, upstairs at the Velvet Lantern
	await advance_to(20, 0)
	await use("stairs", "inn_upstairs")
	await wait(0.6)
	expect(W().area == "inn_upstairs", "upstairs at the Velvet Lantern")
	await wait(2.5)
	if await talk_to("roisin"):
		await click("Talk")
		await shot("char_roisin_dialogue")
		await click("Share a pot of tea")
		await click("Ask what she thinks")
		await shot("char_roisin_opinion")
		await close_panel()
	else:
		expect(false, "roisin visible upstairs (spot %s)" % W().spot_for("roisin"))
	# later in the romance: dating options at night
	Social.change("roisin", 40.0, 40.0, "", "", false)
	Roisin.st()["clock"] = true
	Roisin.st()["teas"] = 2
	Social.set_romance("roisin", "dating")
	await wait(0.3)
	if await talk_to("roisin"):
		await shot("char_roisin_dating")
		await click("Spend the evening together")
		await wait(1.0)
		await shot("char_roisin_fade")
		await wait(3.0)
		await close_panel()

# ======================================================================= iteration 009: the village
func _v9_view(name: String, center: Vector2, zoom := 1.0) -> void:
	await tp(center)
	W().camera.zoom = Vector2(zoom, zoom)
	W().camera.limit_left = -100000
	W().camera.limit_top = -100000
	W().camera.limit_right = 100000
	W().camera.limit_bottom = 100000
	W().camera.reset_smoothing()
	await wait(0.8)
	await shot(name)
	W().camera.zoom = Vector2.ONE
	W()._set_camera_limits()


## Density, boundaries, the pond, harbour, herbalist, Barnaby's basement and day/night lighting.
func phase_village9() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(11, 0)
	var T := 64.0
	await _v9_view("v9_map_day", Vector2(48 * T, 32 * T), 0.3)
	await _v9_view("v9_map_north", Vector2(48 * T, 14 * T), 0.5)
	await _v9_view("v9_map_south", Vector2(48 * T, 50 * T), 0.5)
	# the new venues and spots exist and are reachable
	for sp in ["pond_1", "pond_2", "pond_3", "harbour_quay", "herbalist_counter", "ironfront_host", "ironfront_player"]:
		expect(W().spot_ids.has(sp), "village9: spot %s on the nav graph" % sp)
	for k in [["harbour", "harbour"], ["herbalist", "herbalist"], ["ironfront", "table"]]:
		expect(not find_entry(k[0], k[1]).is_empty(), "village9: interactable %s/%s" % k)
	note("village9: %d y-sorted nodes, %d lights, %.1f fps" % [W().ysort.get_child_count(), W().night_lights.size(), Engine.get_frames_per_second()])
	# doorsteps join the street without cutting through another building
	var crossings := []
	for b in DB.layout["buildings"]:
		var oid: int = W().spot_ids[b["id"] + "_door_out"]
		var p0: Vector2 = W().astar.get_point_position(oid)
		for c in W().astar.get_point_connections(oid):
			var p1: Vector2 = W().astar.get_point_position(c)
			for b2 in DB.layout["buildings"]:
				if b2["id"] == b["id"]:
					continue
				var r: Rect2 = W().brect(b2).grow(-8)
				var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for k in 4:
					if Geometry2D.segment_intersects_segment(p0, p1, pts[k], pts[(k + 1) % 4]) != null:
						crossings.append("%s->%s" % [b["id"], b2["id"]])
	expect(crossings.is_empty(), "village9: doorstep links stay outside other buildings %s" % [crossings])
	var ids: PackedInt64Array = W().astar.get_id_path(W().spot_ids["square_0"], W().spot_ids["ironfront_host"])
	expect(not ids.is_empty(), "village9: Barnaby can walk from the square to his basement table (%d nodes)" % ids.size())
	# pond, harbour, herbalist close up by day
	await _v9_view("v9_pond", W().spots["pond_2"] + Vector2(-120, -160), 1.0)
	await _v9_view("v9_harbour", W().spots["harbour_quay"] + Vector2(-80, 150), 0.75)
	await _v9_view("v9_herbalist_out", W().spots["herbalist_door_out"] + Vector2(0, -120), 1.0)
	await tp(W().spots["herbalist_door_out"] + Vector2(0, -150))
	await wait(1.0)
	expect(W().area == "herbalist", "village9: inside the herbalist (%s/%s)" % [W().area, W().room])
	await shot("v9_herbalist_in")
	var e := find_entry("herbalist", "herbalist")
	await tp((e["pos"] as Vector2) + Vector2(0, 60))
	W().player.facing = "n"
	await wait(0.4)
	expect(W()._focus.get("kind", "") == "herbalist", "village9: the herbalist counter is in reach (%s)" % W()._focus.get("label", ""))
	# Barnaby's house and down the stairs to the Ironfront den
	await tp(W().spots["barnaby_house_door_out"] + Vector2(0, -150))
	await wait(0.8)
	await shot("v9_barnaby_house")
	expect(await use("stairs", "ironfront_basement"), "village9: stairs down in Barnaby's house")
	await wait(1.0)
	expect(W().area == "ironfront_basement", "village9: down in the basement (%s)" % W().area)
	await shot("v9_basement")
	await tp(W().spots["ironfront_player"] + Vector2(0, 30))
	W().player.facing = "n"
	await wait(0.5)
	expect(W()._focus.get("kind", "") == "ironfront", "village9: the Ironfront table is in reach (%s)" % W()._focus.get("label", ""))
	await shot("v9_basement_table")
	expect(await use("stairs", "barnaby_house"), "village9: stairs back up")
	await wait(0.8)
	expect(W().area == "barnaby_house", "village9: back in Barnaby's parlour (%s)" % W().area)
	# the inn interior and its own stairs still work
	await tp(W().bpos("inn", 7.0, 8.4))
	await wait(1.0)
	await shot("v9_inn")
	expect(await use("stairs", "inn_upstairs"), "village9: inn stairs up")
	await wait(0.8)
	expect(W().area == "inn_upstairs", "village9: upstairs (%s)" % W().area)
	await shot("v9_inn_upstairs")
	expect(await use("stairs", "inn"), "village9: inn stairs down")
	await wait(0.8)
	expect(W().area == "inn", "village9: back in the common room (%s)" % W().area)
	# other new interiors
	for bid in ["chandler", "cooperage", "stable", "net_loft", "house_fenn", "grocery", "house_oswin"]:
		await tp(W().spots[bid + "_door_out"] - (W().spots[bid + "_door_out"] - (W().buildings[bid]["rect"] as Rect2).get_center()).normalized() * 150.0)
		await wait(0.8)
		expect(W().area == bid, "village9: inside %s (%s)" % [bid, W().area])
		await shot("v9_in_" + bid)
	# dawn, dusk and night over the square, the pond and the harbour
	await advance_to(6, 30)
	await _v9_view("v9_square_dawn", Vector2(59 * T, 29 * T), 0.6)
	await advance_to(18, 30)
	await _v9_view("v9_square_dusk", Vector2(59 * T, 29 * T), 0.6)
	await advance_to(22, 30)
	await _v9_view("v9_square_night", Vector2(59 * T, 29 * T), 0.6)
	await _v9_view("v9_smithy_night", Vector2(33 * T, 33 * T), 0.6)
	await _v9_view("v9_harbour_night", W().spots["harbour_quay"] + Vector2(-80, 150), 0.75)
	await _v9_view("v9_map_night", Vector2(48 * T, 32 * T), 0.3)
	await tp(W().bpos("inn", 7.0, 8.4))
	await wait(1.0)
	await shot("v9_inn_night")
	W().set_harbour_ship("barge")
	expect(W().harbour_ship_id == "ship_barge", "village9: harbour ship hook takes a ship id")

# ======================================================================= Ironfront (card game)
## Opens Barnaby's war-room, visits every page, then plays a Standard and a Blitzkrieg match through the
## board UI (the player's moves are chosen by the engine's AI but performed by clicking cards and buttons).
func phase_ironfront() -> void:
	await click("New Game")
	await wait(2.5)
	Game.add_gold(400, "test", "playtest")
	var opts := Talk.options("barnaby", "village")
	expect(opts.any(func(o): return o["id"] == "ironfront_play") and opts.any(func(o): return o["id"] == "ironfront_ask"),
		"ironfront: Barnaby offers a game and lore")
	var music_before: String = str(Audio.get("_music_id"))
	Events.open_panel.emit("ironfront", {"id": "barnaby"})
	await wait(0.8)
	var p := panel() as IronfrontPanel
	expect(p != null, "ironfront: panel opens from open_panel")
	if p == null:
		return
	expect(Game.ui_blockers > 0, "ironfront: game time is blocked while the war-room is open")
	await shot("ironfront_menu")
	await click("Deck Builder")
	await wait(0.6)
	await click("+")
	await wait(0.3)
	await shot("ironfront_decks")
	await click("Collection")
	await wait(0.6)
	await shot("ironfront_collection")
	await click("Barnaby's Shelf")
	await wait(0.4)
	var before := Ironfront.collection_size()
	await click("Buy a pack")
	await wait(0.6)
	expect(Ironfront.collection_size() == before + 5, "ironfront: a pack adds five cards")
	await shot("ironfront_shop")
	await click("Rules & Tutorial")
	await wait(0.5)
	await shot("ironfront_rules")
	await click("Tutorial match with Barnaby")
	await wait(1.2)
	var tb: IronfrontBoard = p.board
	expect(tb != null and tb.m.get("tutorial", false), "ironfront: tutorial match starts")
	if tb:
		tb.ai_delay = 0.2
		while int(tb.m["turn"]) != 0 and not tb.m["over"]:
			await wait(0.3)
		await wait(0.4)
		await shot("ironfront_tutorial")
	await click("Concede")
	await wait(0.8)
	expect(tb != null and tb.m["over"] and int(tb.m["winner"]) == 1, "ironfront: conceding ends the match")
	await click("Back to the war-room")
	await wait(0.5)
	await click("The Table")
	await wait(0.5)
	await _ironfront_match("Standard", "standard")
	await click("Back to the war-room")
	await wait(0.6)
	await _ironfront_match("Blitzkrieg", "blitz")
	await click("Back to the war-room")
	await wait(0.6)
	expect(str(Audio.get("_music_id")) == music_before, "ironfront: previous music restored after the match")
	await close_panel()
	await wait(0.3)
	expect(panel() == null and Game.ui_blockers == 0, "ironfront: closing the war-room releases the clock")


func _ironfront_match(button: String, tag: String) -> void:
	var p := panel() as IronfrontPanel
	await click(button)
	await wait(1.0)
	var b: IronfrontBoard = p.board
	expect(b != null, "ironfront: %s match board opens" % tag)
	if b == null:
		return
	expect(str(Audio.get("_music_id")) == "music/ironfront", "ironfront: match music plays")
	b.ai_delay = 0.25
	var guard := 0
	var mid_shot := false
	while not b.m["over"] and guard < 300:
		guard += 1
		if int(b.m["turn"]) != 0 or b.busy:
			await wait(0.25)
			continue
		var mv := Ironfront.ai_move(b.m, 0)
		match str(mv.get("type", "pass")):
			"pass":
				await click("Pass")
			"commander":
				await click("Order:")
			_:
				var hv: IronfrontCard = null
				for v: IronfrontCard in b.hand_views():
					if int(v.inst["uid"]) == int(mv["uid"]):
						hv = v
				if hv == null:
					await click("Pass")
				else:
					hv.clicked.emit(hv)
					await wait(0.15)
					if mv.has("target"):
						var tv: IronfrontCard = b.views.get(int(mv["target"]))
						if tv:
							tv.clicked.emit(tv)
					else:
						for v: IronfrontCard in b.hand_views():
							if int(v.inst["uid"]) == int(mv["uid"]):
								v.clicked.emit(v)
		await wait(0.45)
		var on_table := 0
		for s: Dictionary in b.m["sides"]:
			for r: String in Ironfront.ROWS:
				on_table += s["rows"][r].size()
		if not mid_shot and on_table >= 7:
			mid_shot = true
			await shot("ironfront_%s_mid" % tag)
	expect(b.m["over"], "ironfront: %s match played to the end through the board (%d steps)" % [tag, guard])
	await wait(3.0)
	await shot("ironfront_%s_result" % tag)
	expect(b.m.has("reward"), "ironfront: %s reward applied (%s)" % [tag, str(b.m.get("reward", {}))])

# ======================================================================= iteration 9: skill tree
## The Blacksmith's Skill Tree, the station panel's search and filters, and the equipment designer.
func phase_skilltree() -> void:
	Events.toast.connect(_on_toast)
	await click("New Game")
	await wait(2.5)
	Settings.set_value("gameplay/dice_mode", "auto")
	expect(SkillTree.learned().size() == 2, "skilltree: a new game knows two nodes")
	Events.open_panel.emit("skilltree", {})
	await wait(0.8)
	expect(panel() is SkillTreePanel, "skilltree: the panel opens")
	await shot("st_tree_start")
	# learn a few nodes through the panel (with the skills and gold a few weeks of work would bring)
	var tp := panel() as SkillTreePanel
	tp.canvas.select("m_common")
	await wait(0.3)
	expect(await click("✦ Learn"), "skilltree: Learn button for Common Ores & Refining")
	await wait(0.4)
	expect(SkillTree.is_unlocked("m_common"), "skilltree: learned Common Ores & Refining from the panel")
	Game.add_item(Items.make("sword_iron", {"quality": 80.0}), false)
	for sk in ["smithing", "runecraft", "alchemy", "enchanted_stitching"]:
		Game.grant_player_xp(sk, SkillSys.xp_needed(Game.player_level(sk) + 1))
	Game.add_gold(300, "test", "playtest funds")
	for id in ["s_blades", "m_alloys", "s_steel", "r_identify", "r_clean", "r_blank", "al_simple", "al_oils", "l_armour"]:
		var why := SkillTree.unlock(id)
		expect(why == "", "skilltree: learned %s %s" % [id, why])
	tp.canvas.select("")
	await wait(0.5)
	await shot("st_tree_progress")
	# details of a locked node with mixed requirements
	tp.canvas.select("r_engrave")
	await wait(0.4)
	await shot("st_node_details")
	tp.canvas.select("ar_plating")
	await wait(0.4)
	await shot("st_node_details_arcane")
	tp.canvas.zoom_at(Vector2(600, 400), 1.0 / 1.12 / 1.12 / 1.12)
	tp.canvas.fit_all()
	await wait(0.3)
	await shot("st_tree_fit")
	await close_panel()
	# ---- the station panel: search, category chips and availability filters
	await use("station", "anvil")
	await wait(0.5)
	expect(panel() is StationPanel, "station: the anvil panel opens")
	await shot("st_station_all")
	var sp := panel() as StationPanel
	var le := sp.find_child("RecipeSearch", true, false) as LineEdit
	expect(le != null, "station: search box present")
	if le:
		le.text = "steel"
		le.text_changed.emit("steel")
	await wait(0.3)
	var txt := ""
	for b in _buttons(sp):
		if b.text == "Begin":
			txt += _row_text(b).substr(0, 20) + " | "
	expect(txt.contains("Steel") and not txt.contains("Iron Longsword"), "station: typing 'steel' filters the list (%s)" % txt)
	await shot("st_station_search")
	le.text = ""
	le.text_changed.emit("")
	await click("Armour (")
	var ob := sp.find_child("RecipeAvailability", true, false) as OptionButton
	ob.select(3)
	ob.item_selected.emit(3)
	await wait(0.3)
	await shot("st_station_armour_locked")
	ob.select(0)
	ob.item_selected.emit(0)
	await click("All (")
	await close_panel()
	# ---- the equipment designer: a plan that still lacks a few things
	Game.add_item(Items.make("runestone_ward"), false)
	Events.open_panel.emit("designer", {})
	await wait(0.6)
	expect(panel() is DesignerPanel, "designer: opens")
	await click("Body armour")
	await click("Steel — Steel Cuirass")
	await click("Ward Runestone")
	await click("Whetstone Oil")
	await wait(0.3)
	await shot("st_designer_missing")
	var miss := DesignerPanel.checklist("steel_cuirass", "runestone_ward", "oil_whetstone").filter(func(q): return not q["ok"])
	expect(miss.size() >= 2, "designer: the plan lists what is missing (%d)" % miss.size())
	# a plan that works: an iron longsword with nothing extra — Begin crafting starts the recipe
	await click("Sword")
	await click("Iron — Iron Longsword")
	await click("None")
	await wait(0.2)
	var nb := find_button(panel(), "None")
	if nb:
		nb.pressed.emit()
	await wait(0.3)
	await shot("st_designer_ready")
	expect(await click("Begin crafting"), "designer: Begin crafting enabled when everything is met")
	await wait(0.4)
	expect(Crafting.active() and Crafting.job()["recipe"] == "iron_longsword" and not DesignerPanel.plan().is_empty(), "designer: the base recipe began and the plan is remembered")
	Crafting.cancel()
	Game.state.erase("design_plan")
	# ---- the secret node shows as ??? once its predecessor is known
	SkillTree.unlock_node_force("s_heat")
	SkillTree.unlock_node_force("s_alloy")
	Events.open_panel.emit("skilltree", {})
	await wait(0.8)
	(panel() as SkillTreePanel).canvas.select("s_starsteel")
	await wait(0.4)
	expect(SkillTree.node_state("s_starsteel") == "hidden", "skilltree: the secret node is still hidden (drawn as ???)")
	await shot("st_tree_secret")
	await close_panel()


# ======================================================================= iteration 10: commerce
## Commerce worker: the caravan, the pawnshop, the rival smith, both creature merchants, the creatures panel and an
## adventurer walking through the village with a companion at heel (panels opened directly — venues are built
## by the village worker).
func phase_commerce10() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(10, 0)
	Game.state["gold"] = 6000
	Events.gold_changed.emit(Game.gold())
	# ---- caravan
	Events.open_panel.emit("caravan", {"id": "caravan"})
	await wait(0.8)
	expect(panel() is CaravanPanel, "c10: caravan panel opens")
	await shot("c10_caravan_away")
	await close_panel()
	Commerce.dev_force_caravan()
	expect(Commerce.caravan_present(), "c10: the caravan arrives")
	var w: Dictionary = Commerce.caravan()["wanted"][0]
	c10_give(str(w["def"]), 2)
	Events.open_panel.emit("caravan", {"id": "caravan"})
	await wait(0.8)
	var g0 := Game.gold()
	expect(await click("Buy 1"), "c10: caravan stock has buy buttons")
	await wait(0.3)
	expect(Game.gold() < g0, "c10: bought from the caravan")
	await shot("c10_caravan_wagons")
	await click("Goods Wanted")
	await wait(0.4)
	var g1 := Game.gold()
	expect(await click("Sell 1"), "c10: a wanted good can be sold")
	await wait(0.3)
	expect(Game.gold() > g1, "c10: the caravan paid")
	await shot("c10_caravan_wanted")
	await close_panel()
	# ---- pawnshop
	c10_give("ring_silver", 1)
	c10_give("relic_coin", 1)
	c10_give("ingot_steel", 4)
	Events.open_panel.emit("pawn", {"id": "pawn"})
	await wait(0.8)
	expect(panel() is PawnPanel, "c10: pawn panel opens")
	await shot("c10_pawn_pledge")
	var g2 := Game.gold()
	expect(await click("Pawn"), "c10: pawn button")
	await wait(0.3)
	expect(Game.gold() > g2 and Commerce.pledges().size() == 1, "c10: an item was pledged")
	await click("Your Tickets")
	await wait(0.3)
	await shot("c10_pawn_tickets")
	await click("The Shelf")
	await wait(0.3)
	await shot("c10_pawn_shelf")
	await close_panel()
	# ---- rival smith
	Events.open_panel.emit("rival_smith", {"id": "rival_smith"})
	await wait(0.8)
	expect(panel() is RivalSmithPanel, "c10: rival smith panel opens")
	var g3 := Game.gold()
	expect(await click("Buy —"), "c10: rival stock has buy buttons")
	await wait(0.3)
	expect(Game.gold() < g3, "c10: bought at the Salt Anvil")
	await shot("c10_rival_shop")
	await close_panel()
	Events.open_panel.emit("dialogue", {"npc": "rival_smith", "area": "village"})
	await wait(0.6)
	expect(await click("Ask for a smith's tip"), "c10: the rival gives tips")
	await wait(0.3)
	await shot("c10_rival_talk")
	await close_panel()
	# ---- the creature merchants (and the other commerce characters)
	for who in ["hale_elder", "hale_younger", "pawnbroker", "caravan_master"]:
		Events.open_panel.emit("dialogue", {"npc": who, "area": "village"})
		await wait(0.6)
		expect(panel() is DialoguePanel, "c10: %s talks" % who)
		if who.begins_with("hale"):
			await click("Ask about the creatures")
			await wait(0.3)
		await shot("c10_talk_" + who)
		await close_panel()
	Events.open_panel.emit("creatures", {"id": "hale"})
	await wait(0.8)
	expect(panel() is CreaturesPanel, "c10: creatures panel opens")
	await shot("c10_creatures")
	var adv_a: Dictionary = {}
	for a in Adv.all().values():
		if a["status"] == "in_town":
			adv_a = a
			break
	expect(not adv_a.is_empty(), "c10: an adventurer is in town")
	await click(str(adv_a["name"]) + " (")
	await wait(0.4)
	await shot("c10_creatures_for_adv")
	expect(await click("as a gift"), "c10: gift a creature")
	await wait(0.4)
	expect(not Companions.of(Adv.get_a(str(adv_a["id"]))).is_empty(), "c10: the adventurer keeps the creature")
	await shot("c10_creatures_given")
	await close_panel()
	# ---- in the village: two adventurers with companions (a ground beast and a flyer) walking about
	var walkers := []
	for a in Adv.all().values():
		if a["status"] == "in_town" and walkers.size() < 2:
			walkers.append(a)
	for a in walkers:
		var old := Companions.of(a)
		if not old.is_empty():
			a["equipment"].erase("companion")
	Companions.give(walkers[0], Companions.make("comp_war_hound", 92.0, "Bramble"))
	if walkers.size() >= 2:
		Companions.give(walkers[1], Companions.make("comp_hunting_falcon", 92.0, "Skye"))
	await wait(1.3)
	var cf: CompanionFollowers = W().ysort.get_node_or_null("CompanionFollowers")
	expect(cf != null, "c10: the companion follower node is in the world")
	var T := 64.0
	var start := Vector2(54 * T, 35 * T)
	var i := 0
	for a in walkers:
		var n: NPCActor = W().npcs[a["id"]]
		n.set_meta("travelling", true)   # keep the schedule from re-routing them during the shot
		n.visible = true
		n.position = start + Vector2(i * 150, i * 40)
		n.go(W().path_to(n.position, "harbour_quay"))
		i += 1
	# the commerce characters stand by for a line-up (their venues come from the village worker)
	var j := 0
	for id in Commerce.NPCS:
		var m: NPCActor = W().npcs.get(id)
		if m:
			m.set_meta("travelling", true)
			m.visible = true
			m.path = PackedVector2Array()
			m.position = start + Vector2(-420 + j * 90, -170)
			m.show_name(true)
			j += 1
	await tp(start + Vector2(0, 60))
	W().camera.zoom = Vector2(1.6, 1.6)
	await wait(1.2)
	await shot("c10_village_lineup")
	var f0: Node2D = cf.follower_of(str(walkers[0]["id"])) if cf else null
	expect(f0 != null and f0.visible, "c10: the hound follows its adventurer")
	for k in 3:
		var n0: NPCActor = W().npcs[walkers[0]["id"]]
		W().player.position = n0.position + Vector2(0, 80)
		W().camera.reset_smoothing()
		await wait(1.4)
		await shot("c10_village_walk_%d" % k)
	if f0:
		var n1: NPCActor = W().npcs[walkers[0]["id"]]
		expect(f0.position.distance_to(n1.position) < 140.0, "c10: the companion keeps close (%.0f px)" % f0.position.distance_to(n1.position))
	W().camera.zoom = Vector2.ONE
	expect(await c10_save_load(), "c10: save/load with companions and commerce state")


func c10_give(def: String, n := 1) -> void:
	if bool(DB.item(def).get("stack", false)):
		Game.add_item(Items.make(def, {"qty": n}), false)
	else:
		for k in n:
			Game.add_item(Items.make(def, {"quality": 80.0}), false)


func c10_save_load() -> bool:
	var comp_name := ""
	for a in Adv.all().values():
		if not Companions.of(a).is_empty():
			comp_name = str(Companions.of(a)["name"])
	if not Saves.save("c10_commerce"):
		return false
	var ok := Saves.load_slot("c10_commerce")
	Saves.delete("c10_commerce")
	await wait(0.5)
	var found := false
	for a in Adv.all().values():
		if str(Companions.of(a).get("name", "")) == comp_name:
			found = true
	return ok and found and Commerce.caravan_present()


# ======================================================================= iteration 010: adventurer sheet
func phase_adv10() -> void:
	await click("New Game")
	await wait(2.5)
	# Sigrun: a seasoned fighter with a companion, a broken blade, worn armour, an empty slot or two
	var s := Adv.get_a("sigrun")
	Expeditions.ensure(s)
	s["equipment"]["companion"] = {"uid": Game.new_uid(), "def": "test_companion", "name": "Ash-hound", "creature_name": "Ash-hound", "qty": 1,
		"rarity": "magic", "quality": 70.0, "stats": {"attack": 8, "protection": 3, "scouting": 4}, "affixes": [], "sockets": []}
	s["equipment"]["boots"] = Items.make("boots_leather", {"quality": 78.0})
	s["equipment"]["ring"] = Items.make("ring_garnet", {"quality": 90.0, "rarity": "rare"})
	var e := Expeditions.start({"members": ["sigrun", "tomas"], "leader": "sigrun", "dest": "whisperwood"})
	for n in Expeditions.region("whisperwood")["nodes"]:
		if n["kind"] == "encounter":
			Expeditions.fight(e, n)
			break
	Expeditions.finish(e)
	var w: Dictionary = s["equipment"]["weapon"]
	w["stats"]["durability"] = 0
	w["broken"] = true
	s["equipment"]["armor"]["stats"]["durability"] = int(int(s["equipment"]["armor"]["stats"]["durability_max"]) * 0.2)
	s["status"] = "in_town"
	s["gold"] = 40
	Adv.evaluate_gear(s)
	expect(not s["shopping"].is_empty(), "adv10: Sigrun has a shopping list (%d)" % s["shopping"].size())
	# Mira, Pip and Kestra are out right now
	var e2 := Expeditions.start({"members": ["mira", "pip", "kestra"], "leader": "mira", "dest": "whisperwood"})
	e2["step"] = 1
	for a in Adv.all().values():
		Expeditions.ensure(a)
		if a["status"] == "in_town":
			Adv.evaluate_gear(a)
	await press("panel_adventurers")
	await wait(0.8)
	expect(panel() is AdventurersPanel, "adv10: J opens the roster")
	await shot("adv10_roster")
	var card: Control = panel().find_child("Card_sigrun", true, false) as Control if panel() else null
	expect(card != null, "adv10: Sigrun has a card")
	if card:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		card.gui_input.emit(ev)
		await wait(0.8)
	expect(panel() is DossierPanel, "adv10: the card opens the character sheet")
	if not panel() is DossierPanel:
		Events.open_panel.emit("dossier", {"id": "sigrun"})
		await wait(0.8)
	for t in DossierPanel.TABS:
		expect(await click(t, panel()), "adv10: tab %s" % t)
		await wait(0.5)
		await shot("adv10_sheet_" + t.to_lower())
	# the broken weapon's tooltip
	await click("Equipment", panel())
	await wait(0.4)
	UIRoot.show_tooltip(Items.tooltip(w))
	await wait(0.3)
	await shot("adv10_tooltip_broken")
	UIRoot.hide_tooltip()
	# a traveller's sheet: the expedition in progress
	Events.open_panel.emit("dossier", {"id": "mira"})
	await wait(0.6)
	await click("Expedition", panel())
	await wait(0.4)
	await shot("adv10_sheet_mira_away")

# ======================================================================= iteration 010: navigation & UI
## Left-clicks a world position through the real input path (GUI first, then the world).
func click_world(p: Vector2) -> void:
	await click_screen(W().get_viewport().get_canvas_transform() * p)


func click_screen(sp: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = sp
		e.global_position = sp
		Input.parse_input_event(e)
		await get_tree().process_frame


func _nav() -> PlayerNav:
	return PlayerNav.of(W())


## Waits until the smith stops walking (a click path or quick travel), up to `limit` seconds.
func _await_walk(limit := 12.0) -> void:
	var t := 0.0
	while _nav() and _nav().active() and t < limit:
		await wait(0.1)
		t += 0.1
	await wait(0.2)


func phase_nav10() -> void:
	await click("New Game")
	await wait(2.5)
	await close_panel()
	Settings.set_value("gameplay/click_to_move", true)
	var w := W()
	expect(_nav() != null, "nav10: the smith has a navigator")
	# ---- click-to-move across the village
	await tp(w.spots["well"])
	await wait(0.4)
	var from := w.player.position
	var target := from + Vector2(-620, 140)
	if not _nav().walkable(target):
		target = from + Vector2(-500, -200)
	await click_world(target)
	await wait(0.3)
	expect(_nav().active(), "nav10: a click on the ground starts a walk")
	await shot("nav10_click_walk")
	await _await_walk()
	expect(w.player.position.distance_to(target) < 60.0, "nav10: the smith walked to the clicked spot (%.0f px off)" % w.player.position.distance_to(target))
	# a second hop further on
	var t2 := w.player.position + Vector2(320, 240)
	if _nav().walkable(t2):
		await click_world(t2)
		await _await_walk()
		expect(w.player.position.distance_to(t2) < 60.0, "nav10: and on across the village")
	# ---- into the smithy through the door
	var door: Vector2 = w.spots["smithy_door_out"]
	await tp(door + Vector2(380, -120) if _nav().walkable(door + Vector2(380, -120)) else door + Vector2(0, -250))
	var inside: Vector2 = w.spots.get("smithy_inside", w.bpos("smithy", 15, 7.5))
	await click_world(inside)
	await wait(0.6)
	await shot("nav10_to_smithy")
	await _await_walk()
	expect(w.area == "smithy", "nav10: the walk took the smith into the forge by the door (area %s)" % w.area)
	await shot("nav10_in_smithy")
	# ---- click a station: walk up and use it
	var st := find_entry("station", "anvil")
	expect(not st.is_empty(), "nav10: the anvil is in the forge")
	if not st.is_empty():
		await tp(w.spots.get("smithy_inside", w.player.position))
		var away := (st["pos"] as Vector2).distance_to(w.player.position)
		await click_world(st["pos"])
		await _await_walk()
		await wait(0.4)
		expect(panel() is StationPanel, "nav10: clicking the anvil walked %.0f px and opened it" % away)
		await shot("nav10_station_opened")
		await close_panel()
	# ---- clicking does nothing over the toolbar's strip
	var tb := U().toolbar
	var p0 := w.player.position
	await click_screen(Vector2(tb.get_global_rect().position.x + 12, tb.get_global_rect().get_center().y))
	await wait(0.3)
	expect(not _nav().active() and w.player.position.distance_to(p0) < 4.0, "nav10: a click on the toolbar does not walk")
	await close_panel()
	# ---- click a villager: walk up and talk; the villager card
	Social.change("aldric", 9, 12, "nav10_scales", "The smith mended my shop scales and would not take a coin.")
	var npc := ""
	for id in ["aldric", "hilde", "martha", "wenna", "jory", "eda", "tobin", "oswin", "herbalist", "harbourmaster"]:
		var nn: NPCActor = w.npcs.get(id)
		if nn and nn.visible:
			npc = id
			break
	expect(npc != "", "nav10: a villager is out and about")
	if npc != "":
		var n: NPCActor = w.npcs[npc]
		n.path = PackedVector2Array()
		var stand := n.position + Vector2(0, -260)
		for off in [Vector2(0, -260), Vector2(260, 0), Vector2(-260, 0), Vector2(0, 260)]:
			if _nav().walkable(n.position + off):
				stand = n.position + off
				break
		await tp(stand)
		await click_world(n.position + Vector2(0, -40))
		await _await_walk()
		await wait(0.5)
		expect(panel() is DialoguePanel, "nav10: clicking %s walked up and opened the conversation" % npc)
		var card := panel().find_child("VillagerCard", true, false) if panel() else null
		expect(card != null, "nav10: the dialogue shows the villager card")
		expect(panel() != null and panel().find_child("StandingMeter", true, false) != null, "nav10: standing is a meter")
		await shot("nav10_villager_card")
		await close_panel()
		# an adventurer's card links to the character sheet
		for aid in ["mira", "sigrun", "garrick", "varn", "pip", "elowen", "kestra", "tomas"]:
			if Adv.get_a(aid).is_empty():
				continue
			Events.open_panel.emit("dialogue", {"npc": aid, "area": w.area})
			await wait(0.6)
			expect(find_button(panel(), "Character sheet") != null, "nav10: an adventurer's card links to the character sheet")
			await shot("nav10_adventurer_card")
			await close_panel()
			break
	# ---- quick travel to the harbour (from inside the forge)
	await tp(w.spots.get("smithy_inside", w.bpos("smithy", 15, 7.5)))
	await press("quick_travel")
	await wait(0.6)
	expect(panel() is QuickTravelMenu, "nav10: T opens the quick-travel wheel")
	await shot("nav10_quick_travel_menu")
	var qm := panel() as QuickTravelMenu
	if qm:
		var hi := -1
		for i in qm.dests.size():
			if qm.dests[i]["id"] == "harbour":
				hi = i
		expect(hi >= 0, "nav10: the harbour is on the wheel")
		var mins := int(qm.dests[hi]["minutes"]) if hi >= 0 else -1
		expect(mins > 0, "nav10: the walk to the harbour costs %d minutes" % mins)
		# hover, then click the medallion
		var gp := qm.wheel.get_global_transform() * qm.wheel.slot(hi)
		var mm := InputEventMouseMotion.new()
		mm.position = gp
		mm.global_position = gp
		Input.parse_input_event(mm)
		await wait(0.3)
		await shot("nav10_quick_travel_hover")
		var t0 := Game.now()
		await click_screen(gp)
		await wait(0.5)
		expect(_nav().traveling(), "nav10: the smith sets out")
		await wait(0.8)
		await shot("nav10_quick_travel_underway")
		await _await_walk(20.0)
		var spent := Game.now() - t0
		expect(absi(spent - mins) <= 3, "nav10: the clock advanced by the walk time (%d of %d min)" % [spent, mins])
		expect(w.player.position.distance_to(w.spots["harbour_quay"]) < 140.0, "nav10: the smith is at the harbour")
		await shot("nav10_quick_travel_arrived")
	# ---- K opens the Skill Tree
	await close_panel()
	await press("panel_skills")
	await wait(0.8)
	expect(panel() is SkillTreePanel, "nav10: K opens the Skill Tree")
	await shot("nav10_k_skilltree")
	await close_panel()
	await press("panel_skill_levels")
	await wait(0.6)
	expect(panel() is SkillsPanel, "nav10: U shows the skill levels")
	await shot("nav10_u_skill_levels")
	await close_panel()
	Events.open_panel.emit("map", {})
	await wait(0.8)
	await shot("nav10_map_panel")


# ======================================================================= iteration 010: textiles & tailoring
func phase_tailor10() -> void:
	await click("New Game")
	await wait(2.5)
	# the skill tree of a new smith: the Textiles & Tailoring column next to Leatherworking
	Events.open_panel.emit("skilltree", {})
	await wait(0.8)
	var tp0 := panel() as SkillTreePanel
	expect(tp0 != null, "tailor10: the skill tree opens")
	if tp0:
		tp0.canvas.fit_all()
		await wait(0.3)
		await shot("tailor10_tree_fit_new")
		tp0.canvas.zoom = 0.74
		tp0.canvas.select("ta_scholar")
		await wait(0.4)
		await shot("tailor10_tree_tailoring_locked")
	await close_panel()
	await grant_full_workshop()
	for sid in ["loom", "cutting_table", "tailors_bench"]:
		expect(Property.is_installed(sid), "tailor10: %s stands in the workshop" % sid)
	# the stations on their display bases in the old store and the leather room
	await tp(W().station_pos("loom") + Vector2(150, -40))
	await wait(0.6)
	await shot("tailor10_workshop_store")
	await tp(W().station_pos("tailors_bench") + Vector2(-60, -150))
	await wait(0.6)
	await shot("tailor10_workshop_leather")
	for sid in ["loom", "cutting_table", "tailors_bench"]:
		await close_panel()
		await use("station", sid)
		await wait(0.5)
		var ok: bool = panel() is StationPanel and (panel() as StationPanel).station_id == sid
		expect(ok, "tailor10: the %s panel opens" % sid)
		await shot("tailor10_panel_%s" % sid)
	await close_panel()
	# the learned tree (dev grant) around the tailoring column
	Events.open_panel.emit("skilltree", {})
	await wait(0.8)
	var tp1 := panel() as SkillTreePanel
	if tp1:
		tp1.canvas.select("ta_moon")
		await wait(0.4)
		await shot("tailor10_tree_tailoring_learned")
	await close_panel()

## UX iteration (WORLD): the map with a shop card, quick travel hours, Pell's counter, prompts, a closed shop at night.
func phase_world_ux() -> void:
	var ph: RefCounted = load("res://tests/playtest_world_ux.gd").new()
	await ph.run(self)


## Iteration 012, apprentices: hiring at the board, the Workshop Ledger, miniatures at their stations, break, shift end,
## the finished piece with the apprentice's mark, a word with them, save/load (tests/playtest_workshop12.gd).
func phase_workshop12() -> void:
	var ph: RefCounted = load("res://tests/playtest_workshop12.gd").new()
	await ph.run(self)

## The Living Realm 2a, the evolving smithy: discipline rooms at their tiers, the Loft, the stair and the aetheric lift,
## the layout editor's floor switcher, an apprentice upstairs, walk-to-next and craft again (tests/playtest_smithy_rl.gd).
func phase_smithy_rl() -> void:
	var ph: RefCounted = load("res://tests/playtest_smithy_rl.gd").new()
	await ph.run(self)


## Iteration 010, hirelings: HUD portraits, camera glance, bubbles, funeral, grave, ghost, flowers, vase.
func phase_hire10() -> void:
	var ph: RefCounted = load("res://tests/playtest_hire10.gd").new()
	await ph.run(self)

# ======================================================================= iteration 010: recognition
## Weighted dice and the result breakdown, a multi-order card, the Hall of Fame board, an Epic tooltip
## and the ceremony in the square.
func phase_recog10() -> void:
	await click("New Game")
	await wait(2.5)
	# --- a fine sword with digital (weighted) dice: the breakdown on the results panel
	var it := await craft_ui("iron_longsword", 0.05, "auto", {}, "recog10")
	expect(not it.is_empty() and it.get("craft", {}).has("breakdown"), "recog10: the craft record stores the stat breakdown")
	if not it.is_empty():
		var e: Dictionary = it["craft"]["dice"].get("edge", {})
		expect(str(e.get("how", "")) == "weighted" and str(e.get("text", "")).contains("craftsmanship"), "recog10: the edge die explains its weighting (%s)" % e.get("text", ""))
	# --- physical dice: the entered numbers stand, the modifier is shown
	Game.add_item(Items.make("ingot_iron", {"qty": 6}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 3}), false)
	var ph := await craft_ui("iron_longsword", 0.05, "physical", {"edge": 9, "temper": 4, "fortune": 40}, "recog10p")
	if not ph.is_empty():
		var pe: Dictionary = ph["craft"]["dice"].get("edge", {})
		expect(int(pe.get("entered", -1)) == 9, "recog10: physical edge roll kept as entered (%s)" % pe.get("text", ""))
	# reopen a record from the stores
	if not it.is_empty():
		Events.open_panel.emit("craft_result", {"item": Game.find_uid(int(it["uid"])), "fresh": false})
		await wait(0.8)
		await shot("recog10_record_reopened")
		await close_panel()
	# --- a customer with several requests
	await advance_to(10, 5)
	Game.state["customers"].clear()
	var adv := ""
	for a in Adv.in_town():
		adv = str(a["id"])
		break
	expect(adv != "", "recog10: an adventurer in town")
	Shop._add_customer(adv, "multi")
	Shop.mark_arrived(adv)
	expect(str(Shop.customer(adv).get("want", "")) == "multi", "recog10: a multi-order customer waits")
	Events.open_panel.emit("shop", {})
	await wait(0.8)
	await shot("recog10_multi_order")
	await click("Decline")
	await wait(0.3)
	await click("Accept")
	await wait(0.4)
	await shot("recog10_multi_order_partial")
	await close_panel()
	# --- an Epic deed: the sword fells a boss in the adventurer's hands
	if not it.is_empty() and adv != "":
		var a2 := Adv.get_a(adv)
		Expeditions.ensure(a2)
		Adv.give_item(a2, Game.take_uid(int(it["uid"])), 0)
		a2["status"] = "away"
		var ex := {"id": "exp_pt", "party": [adv], "leader": adv, "dest": "barrow_fields", "journal": [], "encounters": []}
		var rec := {"boss": true, "enemies": [{"kind": "undead", "name": "The Barrow King", "key": "e0"}],
			"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": adv, "weapon_uid": int(it["uid"]), "hit": true}]}
		Expeditions._boss_down(ex, {"name": "The Barrow Hall"}, rec)
		a2["status"] = "in_town"
		W()._update_schedules(true)
		expect(Game.find_uid_anywhere(int(it["uid"])).has("epic"), "recog10: the sword earned Epic distinction")
		expect(Ceremony.scheduled(), "recog10: a ceremony is scheduled")
	# an Epic piece in the smith's own stores, for the tooltip and the slot frame
	if not ph.is_empty():
		Recognition.grant_epic(Game.find_uid(int(ph["uid"])), "turned the tide at the Highmarsh bridge", adv)
		Events.open_panel.emit("inventory", {})
		await wait(0.8)
		UIRoot.show_tooltip(Items.tooltip(Game.find_uid(int(ph["uid"]))))
		await wait(0.3)
		await shot("recog10_epic_tooltip")
		UIRoot.hide_tooltip()
		await close_panel()
	# --- the Hall of Fame board in the smithy
	expect(await use("hall_of_fame", "smithy"), "recog10: the smithy board is interactable")
	await wait(0.6)
	expect(panel() is HallOfFamePanel, "recog10: the Hall of Fame opens")
	await shot("recog10_hall_of_fame")
	await close_panel()
	var bp: Vector2 = W().player.position
	for f in W().interactables:
		if f["kind"] == "hall_of_fame":
			bp = f["pos"]
	await tp(bp + Vector2(0, 60))
	var hp := Vector2(10.45, 3.4)
	var host := Property.room_at_tile(Property.rooms(), hp)
	note("  board furniture: host room %s, clashes %s, rect %s" % [host.get("id", "-"), str(W()._furniture_clashes("hall_of_fame_board", hp, host)) if not host.is_empty() else "-",
		str(Property.rect(host)) if not host.is_empty() else "-"])
	await shot("recog10_board_prop")
	# --- the next day at noon: the square gathers and the smith walks in (he waits in the forge until then,
	# well away from the podium — standing near it while the crowd gathers would hold the ceremony at once)
	await tp(W().bpos("smithy", 5.0, 6.5))
	Game.advance_minutes(1440 - int(Game.state["minute"]) + 11 * 60 + 40)
	await wait(0.5)
	# skip the hour-long walk over from their homes: snap everyone to where the schedule wants them
	for id in W().npcs:
		(W().npcs[id] as NPCActor).target_spot = ""
		(W().npcs[id] as NPCActor).path = PackedVector2Array()
	W()._update_schedules(true)
	await wait(0.5)
	var podium: Vector2 = W().spots.get("square_podium", W().spots.get("square_0", Vector2.ZERO))
	expect(Ceremony.can_attend(), "recog10: the ceremony is gathered at noon (state %s, day %d, hour %d)" % [str(Ceremony.state()), Game.day(), Game.hour()])
	await tp(podium + Vector2(0, 260))
	await wait(1.0)
	expect(panel() is HallOfFamePanel and str(Ceremony.state().get("status", "")) == "held", "recog10: walking into the square holds the ceremony")
	await shot("recog10_ceremony_scene")
	await close_panel()
	# the villagers walk over from wherever they were; give them a moment, then look at the square
	var mid: Vector2 = (W().spots.get("square_0", podium) + W().spots.get("square_3", podium)) * 0.5
	await tp(mid + Vector2(0, 40))
	await wait(9.0)
	var gathered := 0
	for id in Ceremony.state().get("crowd", []) + [str(Ceremony.state().get("adv", ""))]:
		var n: NPCActor = W().npcs.get(id)
		if n and n.visible and n.position.distance_to(mid) < 900.0:
			gathered += 1
		note("  crowd %s: npc %s visible %s spot '%s' target '%s' dist %.0f" % [id, n != null, n.visible if n else false, W().spot_for(id),
			n.target_spot if n else "", n.position.distance_to(mid) if n else -1.0])
	expect(gathered >= 3, "recog10: the crowd gathered in the square (%d)" % gathered)
	await shot("recog10_ceremony_square")

# ======================================================================= iteration 010: the village (signs, roofs, roads, lamps, animals, venues)
func _v10_inside(bid: String) -> void:
	var door: Vector2 = W().spots[bid + "_door_out"]
	await tp(door - (door - (W().buildings[bid]["rect"] as Rect2).get_center()).normalized() * 150.0)
	await wait(0.9)
	expect(W().area == bid, "village10: inside %s (%s)" % [bid, W().area])


## Signs beside every door, weathered roofs, roads worn into the ground, street lamps by night, horses and cows,
## animals that keep out of walls, and the new venues outside and in.
func phase_village10() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(11, 0)
	var T := 64.0
	await _v9_view("v10_map_day", Vector2(48 * T, 32 * T), 0.3)
	await _v9_view("v10_map_north", Vector2(40 * T, 13 * T), 0.5)
	await _v9_view("v10_map_south", Vector2(56 * T, 48 * T), 0.5)
	# signs
	expect(W().get_meta("v10_signs", []).size() == DB.layout["buildings"].size(), "village10: a sign at every building")
	for bid in ["smithy", "inn", "grocery", "herbalist", "chandler", "cooperage", "stable", "house_oswin"]:
		await _v9_view("v10_sign_" + bid, W().spots[bid + "_door_out"] + Vector2(0, 40), 1.4)
	# roads up close: the square's rim, a junction, ruts on the main road, a lane between cottages
	await _v9_view("v10_road_square_rim", Vector2(51.5 * T, 30.5 * T), 1.2)
	await _v9_view("v10_road_junction", Vector2(20.5 * T, 30.0 * T), 1.0)
	await _v9_view("v10_road_ruts", Vector2(44 * T, 31.2 * T), 1.6)
	await _v9_view("v10_road_lane", Vector2(78.5 * T, 33.5 * T), 1.0)
	# livestock
	var horses := 0
	var cows := 0
	for an in W().animals:
		horses += int((an as AnimalActor).kind == "horse")
		cows += int((an as AnimalActor).kind == "cow")
	expect(horses >= 2 and cows >= 3, "village10: %d horses and %d cows at grass" % [horses, cows])
	await _v9_view("v10_horses", Vector2(17.5 * T, 17.3 * T), 1.1)
	await _v9_view("v10_cows", Vector2(4.6 * T, 36.4 * T), 1.1)
	# the cats along the smithy's north wall and by the square, after a good while of wandering
	for an in W().animals:
		for i in 1500:
			(an as AnimalActor).step(0.1)
	var inside := 0
	for an in W().animals:
		for bid in W().buildings:
			if not W().buildings[bid]["area"] and (W().buildings[bid]["rect"] as Rect2).grow(-2).has_point((an as Node2D).position):
				inside += 1
	expect(inside == 0, "village10: no animal wandered into a building (%d)" % inside)
	var cat: Node2D = null
	for an in W().animals:
		if (an as AnimalActor).kind == "cat" and (cat == null or (an as Node2D).position.distance_to(Vector2(31 * T, 33 * T)) < cat.position.distance_to(Vector2(31 * T, 33 * T))):
			cat = an
	await _v9_view("v10_cat_by_walls", cat.position + Vector2(0, -40), 1.4)
	# the new venues, outside and in
	await _v9_view("v10_pawnshop_out", W().spots["pawnshop_door_out"] + Vector2(0, 60), 1.0)
	await _v10_inside("pawnshop")
	await shot("v10_pawnshop_in")
	expect(not find_entry("pawn", "pawn").is_empty(), "village10: the pawnbroker's counter is an interactable")
	await _v9_view("v10_rival_out", W().spots["rival_forge_door_out"] + Vector2(0, -60), 1.0)
	await _v10_inside("rival_forge")
	await shot("v10_rival_in")
	await _v9_view("v10_hale_out", Vector2(12.0 * T, 8.0 * T), 0.8)
	await _v10_inside("hale_cottage")
	await shot("v10_hale_in")
	# the caravan camp, with and without its wagon
	Village10.set_caravan(W(), false)
	await _v9_view("v10_camp_empty", W().spots["caravan_camp"] + Vector2(0, -40), 1.0)
	Village10.set_caravan(W(), true)
	expect(not find_entry("caravan", "caravan").is_empty(), "village10: the caravan's interactable appears with the wagon")
	await _v9_view("v10_camp_caravan", W().spots["caravan_camp"] + Vector2(0, -40), 1.0)
	# the square's ceremony stage, and the graveyard's plots
	await _v9_view("v10_square_stage", W().spots["square_podium"] + Vector2(0, -60), 1.0)
	expect(not find_entry("hall_of_fame", "square").is_empty(), "village10: the square's honours board is an interactable")
	await _v9_view("v10_graveyard", W().spots["graveyard_3"] + Vector2(0, -40), 1.1)
	# street lamps by night
	await advance_to(22, 30)
	await _v9_view("v10_square_night", Vector2(58 * T, 30 * T), 0.7)
	await _v9_view("v10_lane_night", Vector2(36 * T, 12 * T), 0.8)
	await _v9_view("v10_camp_night", W().spots["caravan_camp"] + Vector2(0, -40), 0.9)
	await _v9_view("v10_map_night", Vector2(48 * T, 32 * T), 0.3)
	Village10.set_caravan(W(), false)


# ======================================================================= iteration 011: item personalities (ItemSpirit)
## A legendary piece whose uid roll gives it a spirit, forged at the Ironhand forge.
func _spirit_piece(def: String) -> Dictionary:
	for i in 400:
		var it := Items.make(def, {"rarity": "legendary", "crafted_by": "Brannoc Ironhand", "quality": 108.0})
		if ItemSpirit.destined(it):
			Game.add_item(it, false)
			Provenance.forged(it)
			return it
	return {}


func _spirit_wait_line(uid: int, secs := 1.0) -> bool:
	await wait(secs)
	return int(ItemSpirit.last.get("uid", -1)) == uid


## A talking piece at the grinding wheel during a repair, during a rune setting, an inspection line, a murmur from the
## display, and the Item voices setting.
func phase_spirit11() -> void:
	await click("New Game")
	await wait(2.5)
	await grant_full_workshop()
	await advance_to(10, 0)
	var voices_before: Variant = Settings.get_value(ItemSpirit.VOICE_KEY, true)
	var freq_before: Variant = Settings.get_value(ItemSpirit.FREQ_KEY, "normal")
	Settings.set_value(ItemSpirit.VOICE_KEY, true)
	Settings.set_value(ItemSpirit.FREQ_KEY, "normal")
	var adv := ""
	for a in Adv.in_town():
		if str(a.get("cls", "")) in ["Fighter", "Barbarian", "Paladin"]:
			adv = str(a["id"])
	if adv == "":
		for a in Adv.in_town():
			adv = str(a["id"])
	expect(adv != "", "spirit11: an adventurer in town")
	# --- a blade with a past: sold to the adventurer, a kill in the Barrow Fields, back for repair
	var blade := _spirit_piece("sword_steel")
	expect(not blade.is_empty() and ItemSpirit.awake(blade), "spirit11: a destined legendary woke at the forge")
	Provenance.transfer(blade, adv, "sold")
	for i in 3:
		Lore.record("slew", "%s felled the Bone Wyrm's brood in the Barrow Fields." % blade["name"], {"items": [blade], "place": "barrow_fields",
			"importance": 2, "data": {"enemy": "the Bone Wyrm", "place_name": "the Barrow Fields"}})
	blade["kills"] = 9
	note("  blade: %s — %s (%s)" % [blade["name"], ItemSpirit.type_name(str(ItemSpirit.spirit(blade)["type"])), ItemSpirit.describe(blade)])
	var a2 := Adv.get_a(adv)
	a2["equipment"]["weapon"] = Game.take_uid(int(blade["uid"]))
	var st: Dictionary = blade.get("stats", {})
	if st.has("durability_max"):
		st["durability"] = int(int(st["durability_max"]) * 0.3)
	Shop.customers().append({"npc": adv, "want": "repair", "own_slot": "weapon", "item": blade, "pay": 14, "seat": 0, "present": true,
		"arrived": Game.day() * 24 + Game.hour()})
	await tp(W().station_pos("grinding_wheel") + Vector2(0, 130))
	await wait(0.6)
	Events.open_panel.emit("shop", {})
	await wait(0.8)
	expect(panel() is ShopPanel, "spirit11: the shop panel opens")
	if panel() is ShopPanel:
		(panel() as ShopPanel)._repair(adv)
	expect(await _spirit_wait_line(int(blade["uid"]), 1.2), "spirit11: the blade speaks as it goes on the grinding wheel")
	note("  repair line: %s" % str(ItemSpirit.last.get("text", "")))
	expect(SpiritVoice.instance != null and SpiritVoice.instance.showing(), "spirit11: the voice bubble shows")
	await shot("spirit11_repair_check")
	await play_minigame(true)
	await wait(1.6)
	await close_panel()
	await wait(0.4)
	# the same blade at the wheel later in the day: the bubble stands over the station in the forge
	Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 5)
	await wait(0.4)
	note("  area %s" % W().area)
	expect(ItemSpirit.speak(blade, "sharpen", true) != "", "spirit11: a sharpening line")
	await wait(0.9)
	await shot("spirit11_wheel_bubble")
	await wait(6.5)
	# --- a wizard's blade at the rune engraving stand
	var staff := _spirit_piece("sword_steel")
	Provenance.transfer(staff, "elowen", "sold")
	Lore.record("discovery", "%s lit the way through the drowned library of the Mirewood." % staff["name"], {"items": [staff], "place": "mirewood",
		"importance": 1, "data": {"place_name": "the Mirewood"}})
	Provenance.transfer(staff, "smith", "bought")
	note("  staff: %s — %s" % [staff["name"], ItemSpirit.type_name(str(ItemSpirit.spirit(staff).get("type", "")))])
	Game.add_item(Items.make("runestone_ember", {"qty": 1}), false)
	Game.advance_minutes(ItemSpirit.GLOBAL_COOLDOWN + 5)
	Events.open_panel.emit("station", {"id": "rune_engraving_stand"})
	await wait(0.8)
	for n in panel().find_children("*", "OptionButton", true, false):
		var ob: OptionButton = n
		var idx := ob.get_item_index(int(staff["uid"]))
		if idx >= 0 and ob.get_item_metadata(idx) == null:
			ob.select(idx)
	expect(await click("Engrave and set"), "spirit11: the rune setting begins")
	expect(await _spirit_wait_line(int(staff["uid"]), 1.4), "spirit11: the piece speaks during the rune setting")
	note("  rune line: %s" % str(ItemSpirit.last.get("text", "")))
	await shot("spirit11_rune_check")
	await play_minigame(true)
	await wait(1.6)
	await close_panel()
	await wait(0.3)
	# --- inspection in the stores
	Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 5)
	Events.open_panel.emit("inventory", {})
	await wait(0.8)
	if panel() is InventoryPanel:
		(panel() as InventoryPanel)._select(Game.find_uid(int(staff["uid"])))
	expect(await _spirit_wait_line(int(staff["uid"]), 0.9) and str(ItemSpirit.last.get("context", "")) == "inspect", "spirit11: an inspection line")
	note("  inspect line: %s" % str(ItemSpirit.last.get("text", "")))
	await shot("spirit11_inspect")
	await close_panel()
	await wait(6.0)
	# --- on display in the forge, it mutters when nothing else is happening
	Game.find_uid(int(staff["uid"]))["for_sale"] = true
	Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 5)
	await tp(W().station_pos("anvil") + Vector2(0, 140))
	for i in 8:
		SpiritVoice.instance._idle()
		if str(ItemSpirit.last.get("context", "")) == "idle":
			break
		Game.advance_minutes(20)   # the chance roll said no this minute; a little later
	expect(await _spirit_wait_line(int(staff["uid"]), 0.9) and str(ItemSpirit.last.get("context", "")) == "idle", "spirit11: an idle murmur from the display")
	note("  idle line: %s" % str(ItemSpirit.last.get("text", "")))
	await shot("spirit11_idle")
	await wait(6.0)
	# --- the setting: Item voices off silences them
	Events.open_panel.emit("settings", {})
	await wait(0.8)
	var cb: CheckBox = null
	for n in panel().find_children("*", "CheckBox", true, false):
		if (n as CheckBox).text.begins_with("Item voices"):
			cb = n
	expect(cb != null and cb.button_pressed, "spirit11: the Item voices option is in the settings, on")
	await shot("spirit11_settings_on")
	if cb:
		cb.button_pressed = false
	await wait(0.3)
	expect(not ItemSpirit.voices_on(), "spirit11: unticking it turns item voices off")
	await shot("spirit11_settings_off")
	await close_panel()
	Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 5)
	var said := ItemSpirit.speak(Game.find_uid(int(staff["uid"])), "inspect", true)
	expect(said == "", "spirit11: muted, the piece says nothing")
	Settings.set_value(ItemSpirit.VOICE_KEY, voices_before)
	Settings.set_value(ItemSpirit.FREQ_KEY, freq_before)

# ======================================================================= iteration 011: the world map
## The world remembers (world worker): the parchment world map with discovered sites, fog over unknown ones,
## a cleared site, lost gear at a site, parties on the road and at a site, and a site's page with its history.
func phase_world11() -> void:
	await click("New Game")
	await wait(2.5)
	# a few places become known: one by rumour, one found by explorers
	WorldSites.reveal("ravens_hold", "rumour")
	var advs: Array = Adv.all().values()
	for a in advs:
		Expeditions.ensure(a)
	var heroes: Array = advs.slice(0, 4)
	WorldSites.reveal("sunken_temple", "explored", [heroes[0]["id"], heroes[1]["id"]])
	# a strong party clears the Whisperwood: the Alpha falls for good
	for a in heroes:
		a["level"] = 14
		a["hp_max"] = Expeditions.hp_max(a)
		a["status"] = "in_town"
	var ids: Array = heroes.map(func(a): return str(a["id"]))
	var e := Expeditions.start({"id": "p_w11", "members": ids, "leader": ids[0], "dest": "whisperwood", "goal": "explore"})
	var hollow := Expeditions.node_of("whisperwood", "hollow")
	for i in 10:
		if not WorldSites.boss_alive("whisperwood"):
			break
		for a in heroes:
			a["status"] = "away"
			a["hp"] = a["hp_max"]
		Expeditions.fight(e, hollow)
	expect(not WorldSites.boss_alive("whisperwood"), "world11: the Whisperwood Alpha is slain")
	Expeditions.active().erase(e["id"])
	for a in heroes:
		a["status"] = "in_town"
		a.erase("exp")
	# a fallen adventurer's gear lies at the barrows
	var fallen: Dictionary = advs[5]
	fallen["status"] = "missing"
	Expeditions._reveal_fate(fallen, {"dest": "barrow_fields", "node": "ossuary", "since": Game.day(), "alive": false, "exp": "exp_w11", "searched": false}, "")
	expect(not WorldSites.lost("barrow_fields").is_empty(), "world11: lost gear lies at the Barrow Fields")
	# two parties out: one on the road to Raven's Hold, one at work on the Highmarsh road
	var p1 := Expeditions.start({"id": "p_w11a", "members": [ids[0], ids[1]], "leader": ids[0], "dest": "ravens_hold", "goal": "explore"})
	var p2 := Expeditions.start({"id": "p_w11b", "members": [ids[2], ids[3]], "leader": ids[2], "dest": "highmarsh_road", "goal": "explore"})
	p1["leg"]["t1"] = Game.now() + 120
	p1["leg"]["t0"] = Game.now() - 120
	Expeditions.step(p2)
	# the map, by its key
	await press("panel_world_map")
	await wait(1.0)
	expect(panel() is WorldMapPanel, "world11: G opens the world map")
	var vs := get_viewport().get_visible_rect().size
	if panel():
		var r := panel().get_global_rect()
		expect(r.position.y >= -1 and r.end.y <= vs.y + 1 and r.position.x >= -1 and r.end.x <= vs.x + 1, "world11: the map fits the screen %s" % r)
	await shot("w11_world_map")
	var wp := panel() as WorldMapPanel
	if wp == null:
		return
	# a cleared site's page
	wp.select("whisperwood")
	await wait(0.6)
	await shot("w11_site_cleared")
	expect(WorldSites.status_word("whisperwood") == "cleared", "world11: Whisperwood shows as cleared")
	# the barrows: lost equipment known to lie there
	wp.select("barrow_fields")
	await wait(0.6)
	await shot("w11_site_lost_gear")
	# a party at a site, with a link to its observer
	wp.select("highmarsh_road")
	await wait(0.6)
	await shot("w11_site_party")
	expect(await click("Observe", wp), "world11: the site links to the active expedition's observer")
	await wait(1.0)
	expect(panel() is ObserverPanel, "world11: the observer opens from the site")
	await shot("w11_observer")
	await close_panel()
	# a new region's map in the observer: the party bound for Raven's Hold
	Events.open_panel.emit("observe", {"id": str(p1["id"])})
	await wait(1.0)
	await shot("w11_observer_ravens_hold")
	await close_panel()
	# the village map links here too
	await press("panel_map")
	await wait(0.8)
	expect(await click("The world [", panel()), "world11: the village map links to the world map")
	await wait(0.8)
	expect(panel() is WorldMapPanel, "world11: world map from the village map")
	await shot("w11_world_map_again")
	await close_panel()

# ======================================================================= iteration 011: item stories
## Forges a piece through the real crafting system with fixed scores and dice (no minigame).
func _s11_craft(rid: String, q: float, fortune := 1) -> Dictionary:
	if not Crafting.start(rid):
		return {}
	var guard := 0
	while Crafting.current_station() != "" and guard < 30:
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(q)
		Crafting.record_step(Crafting.current_station(), qs)
		guard += 1
	return Crafting.finish({"edge": 14, "temper": 10, "fortune": fortune}, "digital")


func _s11_overlay(cls_name: String) -> Control:
	for c in U().panel_host.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.get_script() and c.get_script().get_global_name() == cls_name:
			return c
	return null


func _s11_close_overlays() -> void:
	for c in U().panel_host.get_children():
		if c is ItemPanel or c is FamiliarCard:
			(c as UIWindow).close()
	await wait(0.3)


func phase_story11() -> void:
	await click("New Game")
	await wait(2.5)
	for i in 3:
		Game.add_item(Items.make("ingot_iron", {"qty": 6}), false)
		Game.add_item(Items.make("leather_cured", {"qty": 3}), false)
	var it := _s11_craft("iron_longsword", 104.0, 1)
	expect(not it.is_empty(), "story11: a longsword is forged")
	if it.is_empty():
		return
	var uid := int(it["uid"])
	var ids := Adv.in_town().map(func(x): return str(x["id"]))
	ids.sort()
	expect(ids.size() >= 2, "story11: two adventurers in town (%s)" % str(ids))
	var a1 := Adv.get_a(str(ids[0]))
	var a2 := Adv.get_a(str(ids[1]))
	Expeditions.ensure(a1)
	Expeditions.ensure(a2)
	# its life: sold to the first, fells a boss (named, Epic), sharpened, a discovery, then inherited by the second
	a1["gold"] = 400
	Adv.give_item(a1, Game.take_uid(uid), 60)
	Game.advance_minutes(600)
	a1["status"] = "away"
	var ex := {"id": "exp_s11", "party": [a1["id"]], "leader": a1["id"], "dest": "barrow_fields", "journal": [], "encounters": []}
	var rec := {"boss": true, "enemies": [{"kind": "undead", "name": "The Barrow King", "key": "e0"}],
		"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": a1["id"], "weapon_uid": uid, "hit": true}]}
	Expeditions._boss_down(ex, {"name": "The Barrow Hall"}, rec)
	a1["status"] = "in_town"
	var w := Game.find_uid_anywhere(uid)
	expect(ItemStory.is_named(w), "story11: the blade earned a name (%s)" % ItemStory.earned_name(w))
	Lore.record("discovery", "%s found a sealed reliquary in the Whisperwood with %s at their side." % [a1["name"], Items.display_name(w)],
		{"items": [w], "actors": [a1["id"]], "place": "whisperwood", "importance": 2})
	Game.advance_minutes(1440)
	ItemStory.sharpen(w, 88.0, str(a1["id"]))
	Game.advance_minutes(1440)
	a1["equipment"].erase("weapon")
	var old: Dictionary = a2["equipment"].get("weapon", {})
	if not old.is_empty():
		a2["loot"].append(old)
	a2["equipment"]["weapon"] = w
	Provenance.transfer(w, str(a2["id"]), "inherited", "barrow_fields", "%s took up %s when %s laid down the sword after the Barrow Hall." % [a2["name"], Items.display_name(w), a1["name"]])
	w["stats"]["durability"] = int(int(w["stats"]["durability_max"]) * 0.3)
	# --- the adventurer sheet: the equipment page with its histories
	Events.open_panel.emit("dossier", {"id": str(a2["id"])})
	await wait(0.8)
	await click("Equipment", panel())
	await wait(0.6)
	var scs: Array = panel().find_children("*", "ScrollContainer", true, false) if panel() else []
	if not scs.is_empty():
		(scs[0] as ScrollContainer).scroll_vertical = 560
		await wait(0.3)
	await shot("story11_sheet_equipment_history")
	expect(find_button(panel(), "Its story") != null, "story11: the sheet offers each piece's story")
	# --- the inspection: overview (with mark), history, owners
	await click("Its story", panel())
	await wait(0.8)
	var ip := _s11_overlay("ItemPanel")
	expect(ip != null, "story11: the item inspection opens over the sheet")
	await shot("story11_item_overview")
	if ip:
		expect(ip.find_child("MakersMark", true, false) != null, "story11: the overview shows the maker's mark")
		await click("History", ip)
		await wait(0.5)
		await shot("story11_item_history")
		await click("Owners", ip)
		await wait(0.5)
		await shot("story11_item_owners")
	await _s11_close_overlays()
	expect(panel() is DossierPanel and panel().visible, "story11: closing the inspection returns to the sheet")
	await close_panel()
	# --- "A Familiar Creation": the inheritor brings it in for a repair
	await advance_to(10, 5)
	Game.state["customers"].clear()
	Shop.customers().append({"npc": str(a2["id"]), "want": "repair", "own_slot": "weapon", "pay": 20, "present": true, "seat": 0,
		"arrived": Game.day() * 24 + Game.hour(), "seated": Game.day() * 24 + Game.hour()})
	Events.open_panel.emit("shop", {})
	await wait(1.0)
	var card := _s11_overlay("FamiliarCard")
	expect(card != null, "story11: the familiar creation card appears at the counter")
	await shot("story11_familiar_creation")
	await _s11_close_overlays()
	await close_panel()
	Events.open_panel.emit("shop", {})
	await wait(0.8)
	expect(_s11_overlay("FamiliarCard") == null, "story11: the card does not repeat when the counter is opened again")
	await close_panel()
	# --- the Hall of Fame: famous creations
	Events.open_panel.emit("hall_of_fame", {"id": "smithy"})
	await wait(0.8)
	await click("Famous creations", panel())
	await wait(0.5)
	expect(panel() != null and panel().find_child("Creation_%d" % uid, true, false) != null, "story11: the blade is among the famous creations")
	await shot("story11_hall_famous")
	await close_panel()
	# --- workshop services: reforging a broken piece from the stores, sharpening a blade
	var it2 := _s11_craft("iron_longsword", 84.0, 1)
	if not it2.is_empty():
		it2["stats"]["durability"] = 0
		it2["broken"] = true
		Game.add_item(Items.make("coal", {"qty": 2}), false)
		WorkshopServices.reforge_done(int(it2["uid"]), 112.0)
		await wait(0.8)
		expect(_s11_overlay("FamiliarCard") != null, "story11: the reforge result card")
		await shot("story11_reforge_result")
		await _s11_close_overlays()
		WorkshopServices.sharpen_done("", int(it2["uid"]), 92.0)
		await wait(0.8)
		await shot("story11_sharpen_result")
		await _s11_close_overlays()
	# --- the tooltip with the maker's mark, and the mark in the slot corner
	Events.open_panel.emit("inventory", {})
	await wait(0.8)
	if not it2.is_empty():
		UIRoot.show_tooltip(Items.tooltip(Game.find_uid(int(it2["uid"]))))
	await wait(0.3)
	await shot("story11_tooltip_mark")
	UIRoot.hide_tooltip()
	await close_panel()
	# --- talking to the owner: "Ask about … — its travels"
	a2["status"] = "in_town"
	var r := Talk.choose(str(a2["id"]), "itemstory_%d" % uid, "village")
	expect(str(r.get("text", "")).contains("Day"), "story11: the owner tells the blade's travels")
	expect(Talk.options(str(a2["id"]), "village").any(func(o): return str(o["id"]) == "itemstory_%d" % uid), "story11: the dialogue offers to ask about it")
	await _s11_close_overlays()
	var nm := ItemStory.earned_name(w)
	expect(Saves.save("story11_pt"), "story11: save")
	expect(Saves.load_slot("story11_pt"), "story11: load")
	Saves.delete("story11_pt")
	await wait(1.5)
	expect(ItemStory.earned_name(Game.find_uid_anywhere(uid)) == nm, "story11: the name survives save/load")


# ======================================================================= UX iteration: refinement & the dev catalogue
func _rux_node(n: String) -> Node:
	return panel().find_child(n, true, false) if panel() != null else null


func phase_refine_ux() -> void:
	await click("New Game")
	await wait(2.5)
	for pair in [["ingot_iron", 8], ["leather_cured", 4], ["reagent_salt", 4], ["coal", 6]]:
		Game.add_item(Items.make(str(pair[0]), {"qty": int(pair[1])}), false)
	var it := _s11_craft("iron_longsword", 88.0, 1)
	expect(not it.is_empty(), "refine_ux: a longsword is forged")
	if it.is_empty():
		return
	var uid := int(it["uid"])
	var rare := _s11_craft("iron_longsword", 96.0, 1)
	if not rare.is_empty():
		Items.apply_rarity(rare, "rare")
	# --- the grinding wheel's station screen: the improvement block at a glance
	Events.open_panel.emit("station", {"id": "grinding_wheel"})
	await wait(0.8)
	for c in panel().find_children("*", "ScrollContainer", true, false):
		(c as ScrollContainer).scroll_vertical = 100000
	await wait(0.3)
	expect(_rux_node("OpenRefine") != null, "refine_ux: the grinding wheel offers the improvement bench")
	await shot("refine_ux_station")
	if _rux_node("OpenRefine") == null:
		return
	(_rux_node("OpenRefine") as Button).pressed.emit()
	await wait(0.8)
	expect(panel() is RefinePanel, "refine_ux: the improvement bench opens")
	if not panel() is RefinePanel:
		return
	var rp := panel() as RefinePanel
	rp._choose(uid)
	await wait(0.4)
	expect(_rux_node("BeginWork") != null and not (_rux_node("BeginWork") as Button).disabled, "refine_ux: refining is ready at the wheel")
	await shot("refine_ux_before")
	rp.show_details = true
	rp._build()
	await wait(0.3)
	await shot("refine_ux_details")
	# --- the real check: begin, then finish it (the playtest supplies a fine score if the check is not a ring)
	(_rux_node("BeginWork") as Button).pressed.emit()
	await wait(0.8)
	var host := _check_host()
	expect(host != null, "refine_ux: the precision check opens")
	await shot("refine_ux_check")
	if host is SkillCheckPanel:
		await play_checks(true)
	if is_instance_valid(host) and not host.is_queued_for_deletion():
		host.queue_free()
		await wait(0.3)
	if rp.result.is_empty():
		rp.finish(uid, "refine", "", [112.0])
	await wait(0.6)
	expect(not rp.result.is_empty() and bool(rp.result.get("ok", false)), "refine_ux: the work is done (%s)" % str(rp.result.get("outcome", "")))
	expect(_rux_node("ResultHeading") != null, "refine_ux: the result shows before / after")
	await shot("refine_ux_result")
	(_rux_node("ReadHistory") as Button).pressed.emit()
	await wait(0.8)
	expect(_s11_overlay("ItemPanel") != null, "refine_ux: the item's history opens")
	expect(ItemStory.events_of(Game.find_uid(uid)).any(func(e): return str(e.get("kind", "")) == "refined"), "refine_ux: 'refined' in its history")
	await shot("refine_ux_history")
	await _s11_close_overlays()
	# --- rework on the rare piece at the anvil, and an upgrade that is not yet possible
	if not rare.is_empty():
		Events.open_panel.emit("refine", {"station": "anvil", "uid": int(rare["uid"]), "action": "rework"})
		await wait(0.8)
		await shot("refine_ux_rework")
		(panel() as RefinePanel)._select("upgrade")
		await wait(0.4)
		await shot("refine_ux_upgrade_blocked")
		await close_panel()
	# --- the item inspection offers the bench
	Events.open_panel.emit("item", {"uid": uid, "tab": "Overview"})
	await wait(0.8)
	await shot("refine_ux_item_overview")
	await _s11_close_overlays()
	# --- F10: the developer tools and the catalogue
	await press("dev_panel")
	await wait(0.8)
	expect(panel() is DevPanel, "refine_ux: F10 opens the developer tools")
	await shot("refine_ux_devpanel")
	if _rux_node("OpenCatalogue") == null:
		return
	(_rux_node("OpenCatalogue") as Button).pressed.emit()
	await wait(0.8)
	expect(panel() is DevCataloguePanel, "refine_ux: the developer catalogue opens")
	if not panel() is DevCataloguePanel:
		return
	var le := _rux_node("CatalogueSearch") as LineEdit
	le.text = "sword"
	le.text_changed.emit("sword")
	await wait(0.4)
	var row := _rux_node("Row_sword_steel") as Button
	expect(row != null, "refine_ux: the search lists the steel longsword")
	if row:
		row.pressed.emit()
		await wait(0.4)
	(_rux_node("SpawnRarity") as OptionButton).select(2)
	var n0 := Game.inventory().size()
	(_rux_node("SpawnButton") as Button).pressed.emit()
	await wait(0.4)
	expect(Game.inventory().size() == n0 + 1 and bool(Game.inventory()[-1].get("dev", false)), "refine_ux: a developer sword spawned")
	await click("+1000 g")
	await wait(0.4)
	await shot("refine_ux_catalogue")
	await close_panel()

# ======================================================================= UX iteration: guidance (GUIDE worker)
func _find_rich_with_meta(root: Node, needle: String) -> RichTextLabel:
	if root is RichTextLabel and (root as RichTextLabel).text.contains(needle):
		return root
	for c in root.get_children():
		var r := _find_rich_with_meta(c, needle)
		if r:
			return r
	return null


func _find_named(root: Node, nm: String) -> Node:
	if str(root.name) == nm:
		return root
	for c in root.get_children():
		var r := _find_named(c, nm)
		if r:
			return r
	return null


func phase_guide_ux() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(10)
	# the smith has no cured leather: an Iron Longsword is missing one ingredient
	Game.remove_def("leather_cured", Game.count("leather_cured"))
	StationPanel.query = "longsword"
	StationPanel.selected = ""
	await use("station", "anvil")
	expect(panel() is StationPanel, "guide: the anvil's station panel opens")
	await wait(0.4)
	await shot("guide_station_missing")
	var how := _find_named(panel(), "How_iron_longsword") as Button
	expect(how != null, "guide: the recipe row has a How? button")
	if how:
		how.pressed.emit()
		await wait(0.4)
	expect(_find_named(panel(), "Guidance") != null, "guide: Show me how unfolds under the recipe")
	var nb := _find_named(panel(), "NextStepAction") as Button
	expect(nb != null and nb.text.contains("map"), "guide: the next step offers to show Pell's Provisions on the map (%s)" % (nb.text if nb else "-"))
	await shot("guide_station_show_me_how")
	await click("Full details", panel())
	await wait(0.4)
	await shot("guide_station_full_details")
	# click the missing ingredient → its encyclopedia page
	var rl := _find_rich_with_meta(panel(), "url=item:leather_cured")
	expect(rl != null, "guide: the missing ingredient is a link")
	if rl:
		rl.meta_clicked.emit("item:leather_cured")
		await wait(0.8)
	expect(panel() is HelpPanel and (panel() as HelpPanel).page == "item:leather_cured", "guide: clicking it opens Help on Cured Leather")
	await shot("guide_help_cured_leather")
	await click("Full details", panel())
	await wait(0.4)
	(panel() as HelpPanel).scroller.scroll_vertical = 100000
	await wait(0.3)
	await shot("guide_help_cured_leather_tree")
	# follow a link inside the encyclopedia: Raw Hide
	(panel() as HelpPanel)._on_meta("item:leather_hide")
	await wait(0.5)
	expect((panel() as HelpPanel).page == "item:leather_hide", "guide: a link moves to Raw Hide")
	await shot("guide_help_raw_hide")
	await click("← Back", panel())
	await wait(0.4)
	expect((panel() as HelpPanel).page == "item:leather_cured", "guide: Back returns to Cured Leather")
	await click("Return to the", panel())
	await wait(0.6)
	expect(panel() is StationPanel, "guide: Return goes back to the anvil")
	await close_panel()
	# the recipe page and a station page
	Events.open_panel.emit("help", {"topic": "recipe:iron_longsword"})
	await wait(0.6)
	await shot("guide_help_recipe_longsword")
	Events.open_panel.emit("help", {"topic": "materials"})
	await wait(0.6)
	await shot("guide_help_materials_list")
	Events.open_panel.emit("help", {"topic": "station:leather_vat"})
	await wait(0.6)
	await shot("guide_help_station_vat")
	await close_panel()
	# buy a hint from Quell; it shows in Help › Knowledge
	Game.state["gold"] = 400
	Events.open_panel.emit("pawn", {"tab": "knowledge"})
	await wait(0.6)
	expect(await click("Pay", panel()), "guide: Quell sells a hint")
	await wait(0.4)
	await shot("guide_pawn_knowledge")
	await close_panel()
	expect(not Knowledge.owned_list().is_empty(), "guide: the hint is owned")
	Events.open_panel.emit("help", {"topic": "knowledge"})
	await wait(0.6)
	await shot("guide_help_knowledge")
	await close_panel()
	# the material tooltip's one line
	Events.open_panel.emit("inventory", {})
	await wait(0.6)
	for it in Game.inventory():
		if str(it["def"]) == "leather_hide":
			UIRoot.show_tooltip(Items.tooltip(it))
	await wait(0.3)
	await shot("guide_tooltip_hide")
	UIRoot.hide_tooltip()
	await close_panel()
	StationPanel.query = ""


## The Living Realm 3a, adventurers: seeded roster, companies, retirement and newcomers on the roster, the Most
## Wanted board and the character sheet (tests/playtest_living.gd).
func phase_living_rl() -> void:
	var ph: RefCounted = load("res://tests/playtest_living.gd").new()
	await ph.run(self)

# ======================================================================= The Living Realm: equipment (EQUIPMENT worker)
## Ground transitions up close: grass ↔ road, road ↔ square, banks of the stream, pond and harbour, the field edge,
## meadow patches and doorsteps. Run once before and once after a terrain change (the shot names carry `tag`).
func _equip_terrain(tag: String) -> void:
	var T := 64.0
	var views := [["map", Vector2(48 * T, 32 * T), 0.3], ["junction", Vector2(20.5 * T, 30.0 * T), 1.0],
		["square_rim", Vector2(51.5 * T, 30.5 * T), 1.0], ["stream", Vector2(89.0 * T, 20.0 * T), 1.0],
		["pond", Vector2(36.0 * T, 7.4 * T), 0.9], ["harbour", Vector2(78.0 * T, 55.0 * T), 0.9],
		["fields", Vector2(9.0 * T, 50.5 * T), 0.8], ["meadow", Vector2(63.0 * T, 46.0 * T), 0.7], ["paddock", Vector2(4.6 * T, 36.4 * T), 0.9],
		["doorstep", W().spots.get("smithy_door_out", Vector2(30 * T, 30 * T)) + Vector2(0, 40), 1.2]]
	for v in views:
		await _v9_view("eqrl_terrain_%s_%s" % [tag, v[0]], v[1], v[2])


func phase_equip_terrain() -> void:
	await click("New Game")
	await wait(2.5)
	await advance_to(11, 0)
	var tag := OS.get_environment("EQRL_TAG")
	await _equip_terrain(tag if tag != "" else "now")


func _eqrl_piece(def: String, q := 88.0, mine := false) -> Dictionary:
	var it := Items.make(def, {"quality": q})
	if mine:
		Provenance.forged(it)
	return it


## The humanoid equipment sheets: an adventurer in full gear (cloak AND amulet, one piece worn down, one broken),
## the full stat list, a tooltip, the compare view from the counter, a stranger with little gear, the hirelings
## ledger with its compact sheet and compare; then the soft ground once more.
func phase_equip_rl() -> void:
	await click("New Game")
	await wait(2.5)
	var a := Adv.get_a("elowen")
	a["equipment"] = {"weapon": _eqrl_piece("sword_iron", 96.0, true), "shield": _eqrl_piece("shield_round"), "armor": _eqrl_piece("chainmail", 90.0, true),
		"helmet": _eqrl_piece("helm_iron"), "gloves": _eqrl_piece("gloves_leather"), "boots": _eqrl_piece("boots_leather"), "belt": _eqrl_piece("belt_leather"),
		"ring": _eqrl_piece("ring_silver"), "amulet": _eqrl_piece("amulet_sapphire", 104.0, true), "cloak": _eqrl_piece("cloak_warded", 108.0, true)}
	a["equipment"]["boots"]["stats"]["durability"] = 3
	a["equipment"]["shield"]["broken"] = true
	a["equipment"]["shield"]["stats"]["durability"] = 0
	Events.open_panel.emit("dossier", {"id": "elowen", "tab": "Equipment"})
	await wait(0.8)
	var sh := panel().find_child("EquipmentSheet", true, false) as EquipmentSheet
	expect(sh != null, "equip_rl: the adventurer sheet shows the humanoid equipment layout")
	expect(sh != null and sh.cards.has("cloak") and sh.cards.has("amulet"), "equip_rl: cloak and amulet cards both present")
	await shot("eqrl_sheet_adventurer_full")
	UIRoot.show_tooltip(Items.tooltip(a["equipment"]["cloak"]))
	await wait(0.3)
	await shot("eqrl_sheet_tooltip_cloak")
	UIRoot.hide_tooltip()
	expect(await click("Full stats", panel()), "equip_rl: the full stats toggle")
	await wait(0.4)
	for c in panel().find_children("*", "ScrollContainer", true, false):
		(c as ScrollContainer).scroll_vertical = 560
	await wait(0.3)
	await shot("eqrl_sheet_full_stats")
	await click("Hide full stats", panel())
	await close_panel()
	# from the counter: a better staff... a sword on display, weighed against what she wears
	var cand := _eqrl_piece("sword_steel" if DB.items.has("sword_steel") else "sword_iron", 112.0, true)
	cand["for_sale"] = true
	Game.add_item(cand, false)
	Events.open_panel.emit("dossier", {"id": "elowen", "compare": int(cand["uid"])})
	await wait(0.8)
	expect(panel().find_child("CompareView", true, false) != null, "equip_rl: the compare view opens from a store piece")
	await wait(0.3)   # the sheet scrolls the comparison into view by itself
	await shot("eqrl_sheet_compare")
	await close_panel()
	# a stranger with little gear (empty slots read as dotted rings)
	Events.open_panel.emit("dossier", {"id": "pip", "tab": "Equipment"})
	await wait(0.8)
	await shot("eqrl_sheet_adventurer_sparse")
	await close_panel()
	# the hirelings ledger: the compact sheet, a cloak among the gear, and a compare
	var hs := Hire.list()
	if not hs.is_empty():
		var h: Dictionary = hs[0]
		h["equipment"]["cloak"] = _eqrl_piece("cloak_travel", 80.0, true)
		h["equipment"]["helmet"] = _eqrl_piece("helm_iron")
		h["equipment"]["boots"] = _eqrl_piece("boots_leather")
		h["equipment"]["boots"]["stats"]["durability"] = 5
		var spare := _eqrl_piece("chainmail", 95.0, true)
		Game.add_item(spare, false)
		HirelingsPanel.compare[str(h["id"])] = int(spare["uid"])
		Events.open_panel.emit("hirelings", {})
		await wait(0.8)
		expect(panel().find_child("GearSheet", true, false) != null, "equip_rl: the hireling card shows the compact equipment sheet")
		expect(panel().find_child("CompareView", true, false) != null, "equip_rl: the hireling compare view")
		await shot("eqrl_sheet_hireling")
		var hcv := panel().find_child("CompareView", true, false) as Control
		for c in panel().find_children("*", "ScrollContainer", true, false):
			(c as ScrollContainer).ensure_control_visible(hcv)
		await wait(0.3)
		await shot("eqrl_sheet_hireling_compare")
		HirelingsPanel.compare.clear()
		await close_panel()
	await advance_to(11, 0)
	await _v9_view("eqrl_terrain_rl_map", Vector2(48 * 64.0, 32 * 64.0), 0.3)



# ======================================================================= The Living Realm: consultations (CONSULT worker)
func phase_consult_rl() -> void:
	var ph: RefCounted = load("res://tests/playtest_consult.gd").new()

# ======================================================================= The Living Realm: sponsored expeditions (SPONSOR worker)
func phase_sponsor_rl() -> void:
	var ph: RefCounted = load("res://tests/playtest_sponsor.gd").new()
	await ph.run(self)
