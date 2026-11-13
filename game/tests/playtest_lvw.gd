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
