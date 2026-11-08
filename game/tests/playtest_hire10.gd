## Rendered play-test phase "hire10" (iteration 010, hirelings): the bottom-left HUD, a camera glance at a
## hireling, activity bubbles, a death and the funeral, the grave close up, a ghost in the workshop, the
## wildflowers on the step and the vase. Called from tests/playtest.gd (phase_hire10).
extends RefCounted

var pt: Node
const T := 64.0


## A close view of `center`; the smith stands `aside` from it so he does not hide what we look at.
func _view(name: String, center: Vector2, zoom := 1.0, aside := Vector2.ZERO) -> void:
	var w: VillageWorld = pt.W()
	await pt.tp(center + aside)
	w.camera.offset = -aside
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.6)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE
	w.camera.offset = Vector2.ZERO


func _next(hour: int) -> void:
	Game.advance_minutes(1440 - int(Game.state["minute"]) + hour * 60)
	await pt.wait(0.5)


func _hud() -> HirelingHud:
	return pt.U().hud.get_node_or_null("HirelingHud") as HirelingHud


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w: VillageWorld = pt.W()
	Game.state["gold"] = 6000
	await pt.advance_to(10, 30)
	# ---- three hands: one away, one hurt, one at work
	var guard := 0
	while Hire.alive_count() < 3 and guard < 30:
		if (Game.state["applicants"] as Array).is_empty():
			Hire.refresh_applicants()
		else:
			Hire.hire_applicant(0)
		guard += 1
	w.spawn_new_hirelings()
	var others := Hire.list().filter(func(h): return str(h["id"]) != "borin")
	pt.expect(others.size() >= 2, "hire10: two more hands hired (%d)" % others.size())
	var hurt: Dictionary = others[0]
	var fated: Dictionary = others[1] if others.size() > 1 else others[0]
	hurt["status"] = "injured"
	hurt["injured_days"] = 2
	hurt["injured_total"] = 3
	hurt["injuries"] = 2
	var dest := "forest" if DB.destinations.has("forest") else str(DB.destinations.keys()[0])
	pt.expect(Hire.send("borin", dest) == "", "hire10: Borin sets out")
	borin_days()
	Events.hirelings_changed.emit()
	w._update_schedules(true)
	await pt.wait(1.0)
	var hud := _hud()
	pt.expect(hud != null and hud.row.get_child_count() == 3, "hire10: the HUD shows three hands (%d)" % (hud.row.get_child_count() if hud else -1))
	await pt.tp(w.spots.get("smithy_door_out", w.player.position) + Vector2(0, -260))
	await pt.shot("h10_hud")
	# ---- clicking an absent hand: where they are
	hud.clicked("borin")
	await pt.wait(0.6)
	await pt.shot("h10_hud_away_toast")
	# ---- a camera glance at the hand at work (the player stands out in the lane)
	await pt.tp(w.spots.get("well", w.player.position))
	hud.clicked(str(fated["id"]))
	await pt.wait(2.2)
	pt.expect(w.camera.offset.length() > 150.0, "hire10: the camera eases toward %s (offset %.0f)" % [fated["name"], w.camera.offset.length()])
	await pt.shot("h10_focus")
	w.player.position += Vector2(40, 0)
	await pt.wait(1.5)
	pt.expect(w.camera.offset.length() < 40.0, "hire10: moving brings the camera back to the smith (%.0f)" % w.camera.offset.length())
	# ---- activity bubbles near the workshop
	var n: NPCActor = w.npcs.get(str(fated["id"]))
	await pt.tp(n.position + Vector2(-120, 140))
	var bub := w.get_node("ActivityBubbles") as ActivityBubbles
	for i in 3:
		bub._t = 0.0
		await pt.wait(0.15)
	await pt.wait(0.6)
	pt.expect(bub.shown() >= 1, "hire10: activity bubbles show (%d)" % bub.shown())
	await pt.shot("h10_bubbles")
	# ---- death on an expedition, then the funeral the next morning
	await _next(9)
	Hire.get_h(str(fated["id"]))
	pt.expect(Hire.send(str(fated["id"]), dest) == "", "hire10: %s sets out" % fated["name"])
	Hire.force_outcome = "death"
	fated["expedition"]["days_left"] = 1
	await _next(8)
	pt.expect(str(fated["status"]) == "dead", "hire10: %s died on the expedition" % fated["name"])
	pt.expect(Hire.alive_count() == 2, "hire10: the place is free")
	await pt.shot("h10_death_toasts")
	await _next(9)
	pt.expect(not Memorial.funeral_today().is_empty(), "hire10: the funeral is today")
	await pt.advance_to(10, 0)
	w._update_schedules(true)
	var g := Memorial.grave(str(fated["id"]))
	var mw := w.get_node("MemorialWorld") as MemorialWorld
	var gp := mw.plot_pos(int(g["plot"]))
	# the clock jumped: let the mourners finish their walk
	for id: String in Memorial.mourners():
		var mn: NPCActor = w.npcs.get(id)
		if mn and w.spots.has(Memorial.funeral_spot(id)):
			mn.set_meta("travelling", false)
			mn.target_spot = Memorial.funeral_spot(id)
			mn.path = PackedVector2Array()
			mn.position = w.spots[mn.target_spot]
			mn.visible = true
	var at_grave := 0
	for id: String in Memorial.mourners():
		var nn: NPCActor = w.npcs.get(id)
		if nn and nn.visible and nn.position.distance_to(gp) < 400.0:
			at_grave += 1
	for id: String in ["oswin", "martha", "borin"]:
		var dn: NPCActor = w.npcs.get(id)
		pt.note("  %s: spot_for=%s target=%s visible=%s pos=%s grave=%s" % [id, w.spot_for(id), dn.target_spot if dn else "-", dn.visible if dn else false, dn.position if dn else Vector2.ZERO, gp])
	pt.expect(at_grave >= 4, "hire10: mourners gather at the graveside (%d)" % at_grave)
	await pt.tp(gp + Vector2(150, 170))
	w.camera.offset = Vector2(-150, -150)
	w.camera.zoom = Vector2(1.4, 1.4)
	w.camera.reset_smoothing()
	await pt.wait(1.2)
	await pt.shot("h10_funeral")
	await pt.wait(3.6)
	await pt.shot("h10_funeral_mourners")
	await pt.wait(6.0)
	await pt.shot("h10_funeral_fade")
	await pt.wait(4.0)
	w.camera.zoom = Vector2.ONE
	w.camera.offset = Vector2.ZERO
	pt.expect(bool(Memorial.grave(str(fated["id"]))["attended"]), "hire10: the smith attended the funeral")
	await _view("h10_grave", gp + Vector2(0, 60), 2.2)
	await pt.advance_to(13, 0)
	w._update_schedules(true)     # the mourners have gone home
	await pt.use("grave", str(fated["id"]))
	if not (pt.panel() is MemorialPanel):
		# someone (the priest tending the churchyard, by the day's schedule) stands nearer than the stone on this
		# side: like a player, step round and face the headstone from another side
		if pt.panel() != null:
			await pt.close_panel()
		var ge: Dictionary = pt.find_entry("grave", str(fated["id"]))
		for side in [["n", Vector2(0, 40)], ["e", Vector2(-40, 0)], ["w", Vector2(40, 0)]]:
			await pt.tp((ge["pos"] as Vector2) + (side[1] as Vector2))
			w.player.facing = str(side[0])
			await pt.wait(0.2)
			await pt.press("interact")
			await pt.wait(0.4)
			if pt.panel() is MemorialPanel:
				pt.note("  read the headstone from another side (%s)" % side[0])
				break
			if pt.panel() != null:
				await pt.close_panel()
	pt.expect(pt.panel() is MemorialPanel, "hire10: the headstone can be read")
	await pt.shot("h10_grave_panel")
	await pt.close_panel()
	# ---- weeks later, a quiet evening: the ghost in the workshop
	Game.state["day"] = int(Game.state["day"]) + Memorial.GHOST_AFTER_DAYS
	await pt.advance_to(20, 0)
	Memorial.st()["visit"] = {"id": str(fated["id"]), "day": Game.day(), "met": false}
	await pt.wait(1.0)
	pt.expect(mw.ghost_visible(), "hire10: the ghost is in the workshop")
	await _view("h10_ghost", mw.ghost_spot() + Vector2(0, -20), 1.7, Vector2(-120, 60))
	await pt.use("ghost", str(fated["id"]))
	pt.expect(pt.panel() is MemorialPanel, "hire10: talking to the ghost")
	await pt.shot("h10_ghost_talk")
	await pt.close_panel()
	# ---- another evening, unmet: wildflowers on the step by morning
	await _next(20)
	Memorial.st()["visit"] = {"id": str(fated["id"]), "day": Game.day(), "met": false}
	await _next(7)
	pt.expect(Memorial.flowers_at_door().size() == 1, "hire10: wildflowers lie on the smithy step")
	await _view("h10_flowers", mw.flowers_spot(), 1.9, Vector2(-130, -40))
	await pt.use("remembrance_flowers", "door")
	pt.expect(Game.count("flowers_remembrance") == 1, "hire10: the flowers are picked up")
	await pt.shot("h10_flowers_taken")
	# ---- the vase in the quarters
	var ve: Dictionary = pt.find_entry("vase", "quarters")
	pt.expect(not ve.is_empty(), "hire10: the vase is in the quarters")
	if not ve.is_empty():
		await _view("h10_vase_empty", ve["pos"] + Vector2(0, 20), 2.2, Vector2(-110, 30))
		await pt.use("vase", "quarters")
		pt.expect(not Memorial.vase().is_empty() and mw.has_flowers_in_vase(), "hire10: the vase holds the flowers")
		await _view("h10_vase", ve["pos"] + Vector2(0, 20), 2.2, Vector2(-110, 30))
		await pt.use("vase", "quarters")
		pt.expect(pt.panel() is MemorialPanel, "hire10: the vase remembers")
		await pt.shot("h10_vase_panel")
		await pt.close_panel()
	# ---- persistence
	pt.expect(Saves.save("hire10_pt"), "hire10: saved")
	pt.expect(Saves.load_slot("hire10_pt"), "hire10: loaded")
	pt.expect(not Memorial.grave(str(fated["id"])).is_empty() and not Memorial.vase().is_empty(), "hire10: grave and vase survive a reload")
	Saves.delete("hire10_pt")


func borin_days() -> void:
	var b := Hire.get_h("borin")
	if not b.is_empty() and b.get("expedition", {}).has("total"):
		b["expedition"]["total"] = 4
		b["expedition"]["days_left"] = 3
