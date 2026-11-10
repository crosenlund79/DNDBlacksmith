## Rendered play-test phase "s2_steward" (Milestone S2, STEWARD worker): the working smith and the steward's pace.
## A brand-new game (no apprentices): the hand-over with the pace choice; the steward takes over and the smith's own
## figure walks to the forge and the anvil and works there with the work motion and a bubble saying what he does; the
## pace is measured (clock minutes and walking pixels per real second at 1.5×, and again at 1× after the return); the
## steward panel with "You, at work under the steward"; the midday break by the hearth; asleep in his bed at night;
## a Loft station upstairs (the anvil moved to the Loft: he takes the stairs or the lift); taking the workshop back →
## While You Were Away with "Your own work under the steward". Called from tests/playtest.gd (phase_s2_steward).
## Screenshots are named s2st_*.
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _actor() -> StewardSmithActor:
	return _w().get_node_or_null("StewardSmithActor") as StewardSmithActor


func _seat() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


## Lets the day run until `cond` holds: real time while he walks (the world walks him), 5-minute steps otherwise.
func _until(cond: Callable, max_minutes: int, label: String) -> bool:
	var start := Game.now()
	var frames := 0
	while not bool(cond.call()) and Game.now() - start < max_minutes and frames < 6000:
		frames += 1
		if bool(StewardSmith.sm().get("walking", false)):
			await pt.wait(0.2)
		else:
			Game.advance_minutes(5)
			_seat()
			await pt.get_tree().process_frame
			await pt.get_tree().process_frame
	var ok := bool(cond.call())
	pt.note("   until %s: %s at %s (%d game min)" % [label, "yes" if ok else "NO", Game.time_string(), Game.now() - start])
	return ok


func _at_work(sid := "") -> bool:
	var m := StewardSmith.sm()
	var place := str(m.get("place", ""))
	return str(m.get("act", "")) == "work" and not bool(m.get("walking", false)) and place.begins_with("station:") \
		and (sid == "" or place == "station:" + sid) and _actor() != null and _actor().working()


## Waits `s` seconds of UNSCALED engine time (a timer that ignores Engine.time_scale). Rates are measured against it:
## under heavy load the engine clamps each frame's step, which slows the clock and every walk alike — a wall-clock
## measurement would then be meaningless, the engine's own unscaled time is not.
func _wait_unscaled(s: float) -> void:
	await pt.get_tree().create_timer(s, true, false, true).timeout


## {clock: game minutes per unscaled second, smith: px per unscaled second (0 when he is not walking), npc: px/s of a
## walking villager, npc_base: that villager's own pace}.
func _rates(secs: float) -> Dictionary:
	var w := _w()
	var walker: NPCActor = null
	for id in w.npcs:
		var n: NPCActor = w.npcs[id]
		if n.visible and n.path.size() > 1 and not n.get_meta("apprentice", false):
			walker = n
			break
	var n0 := walker.position if walker != null else Vector2.ZERO
	var p0 := w.player.position
	var m0 := Game.now()
	var acc0: float = Game.get("_acc")
	await _wait_unscaled(secs)
	var clock := (float(Game.now() - m0) + float(Game.get("_acc")) - acc0) / secs
	var out := {"clock": clock, "smith": w.player.position.distance_to(p0) / secs, "npc": 0.0, "npc_base": 0.0}
	if walker != null and is_instance_valid(walker):
		out["npc"] = walker.position.distance_to(n0) / secs
		out["npc_base"] = walker.speed
	return out


func _zoom(z: float) -> void:
	_w().camera.zoom = Vector2(z, z)
	_w().camera.reset_smoothing()
	await pt.wait(0.4)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w := _w()
	(Game.state["hirelings"] as Array).clear()
	w._update_schedules(true)
	await pt.advance_to(7, 35)
	await pt.tp(w.bpos("smithy", 9.0, 8.0))
	var xp0 := JSON.stringify(Game.player_skills())
	# ---- the hand-over with the pace choice
	await pt.press("panel_steward")
	await pt.wait(0.6)
	pt.expect(pt.panel() is StewardPanel, "s2st: N opens the steward panel")
	pt.expect(pt.find_button(pt.panel(), "Normal 1×") != null, "s2st: the hand-over offers the pace (1× or 1.5×)")
	pt.expect(pt.find_label_containing(pt.panel(), "sets you to routine work") != null, "s2st: the hand-over says the smith keeps working")
	await pt.shot("s2st_01_handover_pace")
	await pt.click("Hand over the forge")
	await pt.wait(1.0)
	pt.expect(Steward.is_active() and Engine.time_scale == 1.5 and Game.speed == 1, "s2st: the steward runs the forge at 1.5× (time scale %s)" % str(Engine.time_scale))
	pt.expect(w.player.visible and w.player.sprite.modulate.a > 0.9, "s2st: the smith stays in the world (he works under the steward)")
	# ---- the pace: the clock at 1.5× (1.6 game minutes a second × 1.5), measured against unscaled engine time
	var r0 := await _rates(3.0)
	pt.note("   at the steward's pace: clock %.2f game min/s, a villager walks %.0f px/s (own pace %.0f)" % [float(r0["clock"]), float(r0["npc"]), float(r0["npc_base"])])
	pt.expect(absf(float(r0["clock"]) - 1.6 * 1.5) < 0.35, "s2st: the clock runs at 2.4 game minutes a second (%.2f)" % float(r0["clock"]))
	pt.expect(Engine.time_scale == 1.5, "s2st: one time scale for everything that moves (Engine.time_scale %s)" % str(Engine.time_scale))
	# ---- 8:00: he walks to the forge — the walking pace measured too
	var walked := await _until(func(): return Game.hour() >= 8 and bool(StewardSmith.sm().get("walking", false)) and str(StewardSmith.sm().get("goal", "")).begins_with("station:"), 120, "he sets off for a station")
	if walked:
		var r1 := await _rates(0.4)
		pt.note("   the smith walks %.0f px a second at the steward's pace (his own pace %.0f); clock %.2f" % [float(r1["smith"]), PlayerBody.WALK, float(r1["clock"])])
		pt.expect(float(r1["smith"]) > PlayerBody.WALK * 1.25, "s2st: he walks half again as fast as at normal pace (%.0f px/s)" % float(r1["smith"]))
		await pt.shot("s2st_02_walks_to_station")
	pt.expect(await _until(func(): return _at_work(), 180, "at work at a station"), "s2st: he works at a station")
	await pt.wait(0.8)
	pt.note("   bubble: %s" % _actor().bubble_text())
	pt.expect(_actor().bubble_text() != "", "s2st: a bubble says what he is doing")
	await _zoom(1.3)
	await pt.shot("s2st_03_working_first_station")
	pt.expect(await _until(func(): return _at_work("anvil"), 300, "at the anvil"), "s2st: he moves on to the anvil")
	await pt.wait(0.8)
	await pt.shot("s2st_04_working_anvil")
	await _zoom(1.0)
	# ---- the steward panel with the smith at work, then the plate
	await pt.click("Details", pt.U().steward_plate)
	await pt.wait(0.6)
	pt.expect(pt.panel() is StewardPanel and pt.find_label_containing(pt.panel(), "You, at work under the steward") != null, "s2st: the panel shows the smith at work")
	pt.expect(Game.ui_blockers == 0, "s2st: the panel does not stop the clock")
	await pt.shot("s2st_05_panel_smith_and_pace")
	await pt.close_panel()
	await pt.wait(0.4)
	await pt.shot("s2st_06_plate_smith_line")
	# ---- the midday break by the hearth
	pt.expect(await _until(func(): return str(StewardSmith.sm().get("act", "")) == "break", 400, "the midday break"), "s2st: he takes the midday break")
	await pt.wait(0.8)
	await pt.shot("s2st_07_midday_break")
	# ---- the evening and the night: asleep in his bed
	pt.expect(await _until(func(): return str(StewardSmith.sm().get("act", "")) == "sleep", 800, "asleep"), "s2st: at night he sleeps in his bed")
	await pt.wait(0.8)
	pt.note("   at night: %s; fatigue %.1f" % [_actor().bubble_text(), Vitality.fatigue()])
	await pt.shot("s2st_08_asleep_in_bed")
	pt.expect(await _until(func(): return _at_work(), 900, "back at work next morning"), "s2st: next morning he is back at work")
	await pt.wait(0.6)
	await pt.shot("s2st_09_next_morning")
	# ---- take the workshop back → While You Were Away with his own work
	var made := int(Steward.st()["acc"]["smith"]["made_n"])
	await pt.click("Take the workshop back", pt.U().steward_plate)
	await pt.wait(1.2)
	pt.expect(not Steward.is_active() and Engine.time_scale == 1.0, "s2st: back at normal pace the moment he returns")
	pt.expect(pt.panel() is WelcomeBackPanel and (pt.panel() as WelcomeBackPanel).sections.has("smith"), "s2st: the report has 'Your own work under the steward'")
	pt.note("   made under the steward: %d; report sections %s" % [made, str((pt.panel() as WelcomeBackPanel).sections if pt.panel() is WelcomeBackPanel else [])])
	await pt.shot("s2st_10_welcome_back")
	var sec := pt.panel().find_child("Sec_smith", true, false) as Control if pt.panel() != null else null
	if sec != null:
		for sc in pt.panel().find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).ensure_control_visible(sec)
		await pt.wait(0.4)
	await pt.shot("s2st_11_welcome_back_smith")
	pt.expect(JSON.stringify(Game.player_skills()) == xp0, "s2st: no experience gained under the steward")
	await pt.close_panel()
	await pt.wait(0.6)
	# ---- the clock and the village at normal pace again
	var r2 := await _rates(3.0)
	pt.note("   after the return: clock %.2f game min/s, a villager walks %.0f px/s (own pace %.0f)" % [float(r2["clock"]), float(r2["npc"]), float(r2["npc_base"])])
	pt.expect(absf(float(r2["clock"]) - 1.6) < 0.3, "s2st: normal speed after the return (%.2f)" % float(r2["clock"]))
	pt.expect(Engine.time_scale == 1.0, "s2st: the time scale is back to 1")
	if Crafting.active():
		Crafting.cancel()
	# ---- a Loft station: the anvil moved upstairs; he takes the stairs (or the lift) to work there
	Game.state["gold"] = 6000
	for u in ["cobbler", "laundry", "weaver", "chandler", "cellar"]:
		Property.dev_grant_unit(u)
	var bought := Property.buy_unit("loft")
	var plan := Property.plan_copy()
	var placed := Property.place(plan, "anvil", Vector2(116.6, 30.0)) if bought == "" else "no loft: " + bought
	var committed := Property.commit(plan) if placed == "" else placed
	pt.note("   loft: buy '%s', place '%s', commit '%s'" % [bought, placed, committed])
	if committed == "":
		pt.main.call("rebuild_world")
		await pt.wait(2.5)
		w = _w()
		await pt.advance_to(8, 0)
		for d in [["ingot_iron", 3], ["leather_cured", 2], ["coal", 3]]:
			Game.add_item(Items.make(str(d[0]), {"qty": int(d[1])}), false)
		await pt.tp(w.bpos("smithy", 9.0, 8.0))
		Events.open_panel.emit("steward", {})
		await pt.wait(0.5)
		await pt.click("Hand over the forge")
		await pt.wait(0.8)
		pt.expect(Steward.is_active(), "s2st: handed over again")
		var up := await _until(func(): return _at_work("anvil") and w.area == "smithy_loft", 600, "at the anvil in the Loft")
		pt.expect(up, "s2st: he walks up to the anvil in the Loft and works there (area %s)" % w.area)
		await pt.wait(0.8)
		await pt.shot("s2st_12_loft_anvil")
		StewardUI.take_back()
		await pt.wait(1.0)
		await pt.close_panel()
	pt.expect(not Steward.is_active() and Engine.time_scale == 1.0, "s2st: the steward stood down at the end")
