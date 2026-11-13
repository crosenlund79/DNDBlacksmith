## Rendered play-test phases of "The Living Village & Workshop Experience" (canonical v1.7, observations #64–76).
## lvw_dev: the in-game menu's Developer tools entry, the quick tools (gold, item catalogue, skill by levels) and the
## simulation pace measured against unscaled time: the clock and walking speed up together, and return to normal.
## Shots lvw_*. Called from tests/playtest.gd (phase_lvw_*).
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.shot("lvw_%s" % name)


func _wait_unscaled(s: float) -> void:
	await pt.get_tree().create_timer(s, true, false, true).timeout


## Game minutes and the player's walked distance over `s` real seconds, walking right.
func _measure(s: float) -> Array:
	var w: VillageWorld = pt.W()
	var m0 := Game.now()
	var p0: Vector2 = w.player.position
	Input.action_press("move_right")
	await _wait_unscaled(s)
	Input.action_release("move_right")
	return [Game.now() - m0, w.player.position.distance_to(p0)]


func run_dev(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	await pt.press("cancel")
	await pt.wait(0.6)
	pt.expect(pt.panel() is PausePanel, "dev: Esc opens the in-game menu")
	await _shot("menu")
	pt.expect(await pt.click("Developer tools (F10)", pt.panel()), "dev: the menu has a Developer tools entry")
	await pt.wait(0.8)
	pt.expect(pt.panel() is DevPanel, "dev: it opens the F10 tools")
	pt.expect(pt.panel().find_child("QuickTools", true, false) != null, "dev: the quick tools are first")
	await _shot("panel_cheats_off")
	await pt.click("Enable cheats for this session", pt.panel())
	await pt.wait(0.4)
	pt.expect(DevTools.enabled(), "dev: cheats switched on")
	await _shot("panel_cheats_on")
	var g0 := Game.gold()
	await pt.click("Add gold", pt.panel())
	pt.expect(Game.gold() == g0 + 1000, "dev: +1000 gold (%d → %d)" % [g0, Game.gold()])
	var l0 := Game.player_level("smithing")
	await pt.click("Raise skill by levels", pt.panel())
	pt.expect(Game.player_level(str(DB.skill_list[0]["id"])) >= 1, "dev: the chosen skill was raised (%s)" % str(DB.skill_list[0]["id"]))
	await pt.close_panel()
	await pt.wait(0.3)
	# the pace: the whole simulation speeds up together (clock and walking), then normal again
	var w: VillageWorld = pt.W()
	await pt.tp(w.spots["square_0"] + Vector2(-500, 0))
	var normal := await _measure(1.5)
	await pt.tp(w.spots["square_0"] + Vector2(-500, 0))
	DevTools.set_sim_pace(4.0)
	var fast := await _measure(1.5)
	DevTools.set_sim_pace(1.0)
	var back := await _measure(1.0)
	pt.note("pace: ×1 %d min / %.0f px; ×4 %d min / %.0f px; back ×1 %d min / %.0f px (per the same real time; last 1.0 s)" % [normal[0], normal[1], fast[0], fast[1], back[0], back[1]])
	var rc := float(fast[0]) / maxf(1.0, float(normal[0]))
	var rw := float(fast[1]) / maxf(1.0, float(normal[1]))
	pt.expect(rc > 3.0 and rc < 5.0, "dev: ×4 runs the clock about four times as fast (%.1f×)" % rc)
	pt.expect(rw > 2.8 and rw < 5.2, "dev: …and the smith walks about four times as far (%.1f×) — together" % rw)
	pt.expect(Engine.time_scale == 1.0, "dev: back to normal speed")
	DevTools.set_enabled(false)
	pt.expect(not DevTools.enabled() and Engine.time_scale == 1.0, "dev: cheats off")
	pt.expect(Game.player_level("smithing") >= l0, "dev: levels kept")


## lvw_ironfront: Barnaby's in-character introduction (paged), the teaching match with his suggestion and ability notes,
## the Field Manual (lessons, every card explained), Barnaby's shelf with a found card and the sell list.
func run_ironfront(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Events.open_panel.emit("ironfront", {"id": "barnaby", "tutorial": true})
	await pt.wait(1.2)
	var ip: Control = pt.panel()
	pt.expect(ip is IronfrontPanel and ip.find_child("IntroText", true, false) != null, "ironfront: Barnaby's introduction opens first")
	await _shot("if_intro_1")
	for i in 3:
		await pt.click("Go on…", ip)
		await pt.wait(0.4)
	await _shot("if_intro_4")
	pt.expect(await pt.click("Deal me in", ip), "ironfront: the teaching match is dealt")
	await pt.wait(1.5)
	var board: IronfrontBoard = (ip as IronfrontPanel).board if ip is IronfrontPanel else null
	pt.expect(board != null and int(board.m["seed"]) == Ironfront.TEACHING_SEED, "ironfront: the fixed teaching deal")
	if board != null and int(board.m["turn"]) != 0:
		await pt.wait(3.0)
	if board != null:
		board._refresh()
		await pt.wait(0.3)
		pt.expect(board.coach_box.visible and str(board.coach_label.text).contains("Barnaby suggests"), "ironfront: Barnaby suggests a move and why")
		pt.note("coach: " + str(board.coach_label.text).left(240))
		await _shot("if_teaching_board")
	# the Field Manual and the shelf
	await pt.close_panel()
	await pt.wait(0.5)
	var a: Dictionary = Adv.in_town()[0]
	Ironfront.card_found(a, false, "special")
	Ironfront.on_day()
	Events.open_panel.emit("ironfront", {"page": "manual"})
	await pt.wait(1.0)
	await _shot("if_manual")
	(pt.panel() as IronfrontPanel)._show("shop")
	await pt.wait(0.8)
	pt.expect(not Ironfront.found_shelf().is_empty(), "ironfront: a card %s found on the road is on Barnaby's shelf" % a.get("name", ""))
	await _shot("if_shop")
	await pt.close_panel()


## lvw_ui: the compact HUD; the stores with icon categories and the floating item tooltip (no fixed description area,
## kept on screen at the edges, dismissed on leaving); the hireling ledger (gear left, assignments and expeditions
## right, the skills box optional).
func run_ui(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var ui: UIRoot = UIRoot.instance
	pt.note("hud plate %s" % str(ui.hud_plate.size))
	pt.expect(ui.hud_plate.size.y < 150 and ui.hud_plate.size.x < 470, "ui: the HUD plate is compact (%dx%d)" % [int(ui.hud_plate.size.x), int(ui.hud_plate.size.y)])
	await _shot("ui_hud")
	for d in ["sword_iron", "shield_kite", "ore_iron", "runestone_ember", "relic_idol"]:
		Game.add_item(Items.make(d, {"quality": 90.0}))
	Events.open_panel.emit("inventory", {})
	await pt.wait(1.0)
	var inv: Control = pt.panel()
	pt.expect(inv is InventoryPanel, "ui: the stores open")
	for k in ["all", "equipment", "materials", "magic", "relics"]:
		var b := inv.find_child("Cat_" + k, true, false) as Button
		pt.expect(b != null and b.tooltip_text != "", "ui: the %s category is an icon with a hover label" % k)
	pt.expect(not (inv.find_child("DetailScroll", true, false) as Control).visible, "ui: no fixed description column at first")
	# hover a piece: the floating tooltip
	var grid: GridContainer = (inv as InventoryPanel).grid
	var slot: ItemSlot = grid.get_child(0) as ItemSlot
	slot.mouse_entered.emit()
	pt.get_viewport().warp_mouse(slot.get_global_rect().get_center())
	await pt.wait(0.4)
	pt.expect(ui.tooltip_panel.visible and ui.tooltip_text.text.length() > 20, "ui: hovering a piece shows its full description")
	var r := ui.tooltip_panel.get_global_rect()
	var vs := pt.get_viewport().get_visible_rect().size
	pt.expect(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= vs.x + 1 and r.end.y <= vs.y + 1, "ui: the tooltip is on screen %s" % str(r))
	pt.expect(ui.tooltip_panel.get_index() == ui.get_child_count() - 1, "ui: the tooltip is above every panel")
	await _shot("ui_stores_tooltip")
	# near the right/bottom edge it moves to stay on screen
	pt.get_viewport().warp_mouse(vs - Vector2(10, 10))
	await pt.wait(0.3)
	r = ui.tooltip_panel.get_global_rect()
	pt.expect(r.end.x <= vs.x + 1 and r.end.y <= vs.y + 1, "ui: at the screen corner it stays on screen")
	slot.mouse_exited.emit()
	await pt.wait(0.2)
	pt.expect(not ui.tooltip_panel.visible, "ui: leaving the piece dismisses it")
	(inv as InventoryPanel)._cat_buttons["materials"].pressed.emit()
	await pt.wait(0.3)
	await _shot("ui_stores_materials")
	await pt.close_panel()
	# the hireling ledger
	Events.open_panel.emit("hirelings", {})
	await pt.wait(1.0)
	var hp: Control = pt.panel()
	pt.expect(hp is HirelingsPanel and hp.find_child("Assignments", true, false) != null and hp.find_child("WhoAndGear", true, false) != null,
		"ui: the hireling card — who and gear, assignments and expeditions")
	pt.expect(hp.find_child("SkillsBox", true, false) == null, "ui: the skills box is optional (closed)")
	await _shot("ui_hirelings")
	var tg := hp.find_child("SkillsToggle", true, false) as Button
	if tg != null:
		tg.pressed.emit()
		await pt.wait(0.5)
		pt.expect(pt.panel().find_child("SkillsBox", true, false) != null, "ui: the skills box opens on request")
		await _shot("ui_hirelings_skills")
	await pt.close_panel()


## lvw_layout: the compact smithy and the freed ground — the village by the smithy with the millpond, its dock and reeds,
## the millstream and the turning watermill; the ground floor; walking up to the quarters in the Loft; digging the
## cellar and going down; the forge's map marker at its door. Shots lvw_layout_*.
func run_layout(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w: VillageWorld = pt.W()
	var pond: Vector2 = w.tp(DB.layout["millpond"]["center"])
	await pt.tp(pond + Vector2(-60, 360))
	await pt.wait(1.0)
	var r0 := w.mill_wheel.rotation
	await pt.wait(0.8)
	pt.expect(absf(w.mill_wheel.rotation - r0) > 0.05, "layout: the mill wheel turns")
	await _shot("layout_millpond")
	await pt.tp(w.tp([30.0, 47.0]))
	await pt.wait(0.8)
	await _shot("layout_smithy_outside")
	# inside: the ground floor
	await pt.tp(w.spots["smithy_inside"] + Vector2(0, 120))
	await pt.wait(0.8)
	pt.expect(w.area == "smithy", "layout: inside the smithy (%s)" % w.area)
	await _shot("layout_ground_floor")
	# walk up to the quarters: the route takes the stair
	var nav := PlayerNav.of(w)
	var bed: Vector2 = Vector2.INF
	for e in w.interactables:
		if str(e["kind"]) == "bed" and str(e["id"]) == "cot":
			bed = e["pos"]
	pt.expect(bed != Vector2.INF, "layout: the cot is in the Loft")
	if bed != Vector2.INF:
		var route := nav.route_to(bed)
		pt.expect(not route.is_empty(), "layout: the smith can walk from the shop to his cot (%d min)" % int(route.get("minutes", -1)))
		await pt.tp(bed + Vector2(60, 40))
		await pt.wait(0.8)
		pt.expect(w.area == "smithy_loft", "layout: the cot is up in the Loft (%s)" % w.area)
		await _shot("layout_loft_quarters")
	# dig the cellar, then go down
	Game.state["gold"] = 4000
	pt.expect(Property.buy_unit("chandler") == "", "layout: the cellar is dug")
	pt.get_tree().root.get_node("Main").call("rebuild_world")
	await pt.wait(2.0)
	w = pt.W()
	var down := w.interactables.filter(func(e): return str(e["kind"]) == "stairs" and str(e["id"]) == "smithy_basement")
	pt.expect(not down.is_empty(), "layout: a stair down to the cellar stands in the stock hall")
	if not down.is_empty():
		var nav2 := PlayerNav.of(w)
		await pt.tp(w.spots["smithy_inside"] + Vector2(0, 120))
		var rt := nav2.route_to(w.spots.get("smithy_basement_inside", Vector2.INF))
		pt.expect(not rt.is_empty(), "layout: the cellar can be walked to")
		await pt.tp(w.spots["smithy_basement_inside"])
		await pt.wait(0.8)
		pt.expect(w.area == "smithy_basement", "layout: in the cellar (%s)" % w.area)
		await _shot("layout_cellar")
	# the village map: the forge's marker at its door
	await pt.tp(w.spots["smithy_door_out"] + Vector2(0, -60))
	await pt.press("panel_map")
	await pt.wait(1.0)
	await _shot("layout_village_map")
	await pt.close_panel()


## lvw_maps: the illustrated village map (full and minimap) and the smithy's floor plans on the minimap (ground, Loft,
## cellar), the shop medallions, people and exits still drawn and clickable. Shots lvw_map_*.
func run_maps(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Game.state["gold"] = 4000
	Property.buy_unit("chandler")
	pt.get_tree().root.get_node("Main").call("rebuild_world")
	await pt.wait(2.0)
	var w: VillageWorld = pt.W()
	await pt.tp(w.spots["smithy_door_out"] + Vector2(0, -90))
	await pt.wait(0.8)
	await _shot("map_minimap_village")
	await pt.press("panel_map")
	await pt.wait(1.2)
	var mp: Control = pt.panel()
	pt.expect(mp is MapPanel, "maps: the village map opens")
	var view := mp.find_children("*", "VillageMapView", true, false)
	pt.expect(not view.is_empty(), "maps: it draws the village view")
	if not view.is_empty():
		var vv: VillageMapView = view[0]
		pt.expect(not VillageMapView._geo.is_empty() and (VillageMapView._geo["trees"] as Array).size() > 80, "maps: woods, water and paths are drawn (%d trees)" % (VillageMapView._geo["trees"] as Array).size())
		pt.expect(vv.venue_at(vv.m(VillageMapView.venue_world_pos(w, "forge"))) == "forge", "maps: the forge's medallion (at its door) is still clickable")
	await _shot("map_full")
	await pt.close_panel()
	for spot in ["smithy_inside", "smithy_basement_inside"]:
		if w.spots.has(spot):
			await pt.tp(w.spots[spot] + (Vector2(0, 120) if spot == "smithy_inside" else Vector2.ZERO))
			await pt.wait(1.0)
			await _shot("map_minimap_" + spot)
	for e in w.interactables:
		if str(e["kind"]) == "bed" and str(e["id"]) == "cot":
			await pt.tp(e["pos"] + Vector2(60, 40))
			await pt.wait(1.0)
			await _shot("map_minimap_loft")


## lvw_oldsave: a real 0.14.6 save (golden fixture) loaded through the menu path into the compact smithy: it migrates
## (step 8), the smith stands inside, every station stands or waits in storage, the Loft and the cellar as owned.
func run_oldsave(p: Node) -> void:
	pt = p
	await pt.wait(0.5)
	var f := FileAccess.open(Saves.path("lvw_oldsave"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/build-0.14.6.json"))
	f.close()
	pt.get_tree().root.get_node("Main").call("load_slot", "lvw_oldsave")
	await pt.wait(3.0)
	var w: VillageWorld = pt.W()
	pt.expect(w != null, "oldsave: the world is up")
	pt.expect(int(Game.state.get("version", 0)) == Game.SAVE_VERSION, "oldsave: migrated to schema %d" % Game.SAVE_VERSION)
	var steps: Array = Saves.last_load.get("migration", {}).get("steps", [])
	pt.expect(steps.has("the compact smithy"), "oldsave: the compact-smithy step ran (%s)" % str(steps))
	var pp: Vector2 = w.player.position / 64.0
	pt.expect(not Rect2(37, 34, 12, 24).has_point(pp), "oldsave: the smith is not standing in the millpond (%s)" % str(pp))
	pt.expect(Property.validate(Property.plan_copy()) == "", "oldsave: the plan is valid")
	pt.note("units %s, stations %d set up, %d stored" % [str(Property.st()["units"]), (Property.st()["stations"] as Dictionary).size(), (Property.st()["stored"] as Array).size()])
	await pt.tp(w.spots["smithy_inside"] + Vector2(0, 120))
	await pt.wait(1.0)
	await _shot("oldsave_ground")
	if w.spots.has("smithy_basement_inside") and Property.floor_owned("basement"):
		await pt.tp(w.spots["smithy_basement_inside"])
		await pt.wait(1.0)
		await _shot("oldsave_cellar")
	Saves.delete("lvw_oldsave")
