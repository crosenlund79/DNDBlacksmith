## Rendered play-test phase "workshop12" (iteration 012, apprentices): hire at the notice board, the Workshop Ledger
## (empty and with work queued), a customer repair and a longsword queued, apprentices at their stations with activity
## bubbles (zoomed), the station prompt and the property plan, the midday break, the end of the shift, the finished
## piece with the apprentice's mark in its inspection, a word with an apprentice, and save/load.
## Called from tests/playtest.gd (phase_workshop12). Screenshots are named w12_*.
extends RefCounted

var pt: Node
const T := 64.0


func _w() -> VillageWorld:
	return pt.W()


func _acts() -> ApprenticeActors:
	return _w().get_node_or_null("ApprenticeActors") as ApprenticeActors


## A close view of `center`; the smith stands `aside` so he does not hide what we look at.
func _view(name: String, center: Vector2, zoom := 1.0, aside := Vector2.ZERO) -> void:
	var w := _w()
	await pt.tp(center + aside)
	w.camera.offset = -aside
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.6)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE
	w.camera.offset = Vector2.ZERO


func _bubbles() -> void:
	var bub := _w().get_node("ActivityBubbles") as ActivityBubbles
	for i in 4:
		bub._t = 0.0
		await pt.wait(0.2)
	await pt.wait(0.5)


## Let the actors walk to where they belong (real time), then a final sync.
func _settle(secs := 4.0) -> void:
	_acts()._t = 0.0
	await pt.wait(secs)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w := _w()
	Game.state["gold"] = 6000
	(Game.state["hirelings"] as Array).clear()   # keep the smithy to the apprentices for these pictures
	w._update_schedules(true)
	Property.dev_grant_unit("cobbler")           # a second workshop room: two apprentice places
	pt.note(ApprenticeDev.unlock())
	await pt.advance_to(9, 0)
	Apprentices.refresh_applicants()
	while Apprentices.applicants().size() < 2:
		ApprenticeDev.add_applicant()
	# ---- the notice board: the Workshop apprentices tab
	await pt.use("notice", "board")
	pt.expect(pt.panel() is NoticePanel, "workshop12: the notice board opens")
	await pt.click("Workshop apprentices")
	await pt.wait(0.4)
	await pt.shot("w12_notice_apprentices")
	await pt.click("Take on")
	await pt.wait(0.4)
	await pt.click("Take on")
	await pt.wait(0.4)
	pt.expect(Apprentices.staff().size() == 2, "workshop12: two apprentices hired at the board (%d)" % Apprentices.staff().size())
	await pt.shot("w12_notice_after_hire")
	await pt.close_panel()
	var a1: Dictionary = Apprentices.staff()[0]
	var a2: Dictionary = Apprentices.staff()[1]
	# the second one has been here a while: an apprentice who can make a longsword
	a2["rank"] = "apprentice"
	a2["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	a2["works"] = 9
	# ---- the ledger, empty
	await pt.press("panel_workshop")
	await pt.wait(0.5)
	pt.expect(pt.panel() is WorkshopPanel, "workshop12: Y opens the Workshop Ledger")
	await pt.shot("w12_ledger_empty")
	await pt.close_panel()
	# ---- a customer with a dented helmet at the counter, and a longsword to make
	var cust := "martha"
	for id: String in Adv.all():
		if Adv.get_a(id)["status"] == "in_town" and Shop.customer(id).is_empty():
			cust = id
			break
	Shop._add_customer(cust, "repair")
	w._update_schedules(true)
	await pt.wait(0.3)
	pt.expect(not Apprentices.repair_customers().is_empty(), "workshop12: a repair is waiting at the counter")
	Game.add_item(Items.make("ingot_iron", {"qty": 4}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 2}), false)
	await pt.press("panel_workshop")
	await pt.wait(0.4)
	var wp := pt.panel() as WorkshopPanel
	wp.add_kind = "repair"
	wp.build()
	await pt.wait(0.2)
	await pt.click("'s ")         # the waiting customer's piece
	await pt.wait(0.3)
	wp = pt.panel() as WorkshopPanel
	for t in Apprentices.open_tasks():
		if str(t["kind"]) == "repair":
			pt.expect(Apprentices.assign(int(t["id"]), str(a1["id"])) == "", "workshop12: the repair is pinned to %s" % a1["name"])
	var lt := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 2, "priority": 2, "assignee": str(a2["id"])})
	pt.expect(not lt.has("error"), "workshop12: longswords queued for %s (%s)" % [a2["name"], lt.get("error", "")])
	await pt.wait(0.4)
	pt.expect(Apprentices.open_tasks().size() >= 2, "workshop12: a repair and a craft in the queue (%d)" % Apprentices.open_tasks().size())
	if is_instance_valid(wp):
		wp.add_kind = "craft"
		wp.build()
	await pt.wait(0.4)
	await pt.shot("w12_ledger_queued")
	await pt.close_panel()
	# ---- let the work run: apprentices at their stations
	Game.advance_minutes(25)
	await _settle(5.0)
	var forge_c := w.bpos("smithy", 5.2, 3.4)
	var at_station := 0
	for a in Apprentices.staff():
		var n: NPCActor = _acts().actors.get(str(a["id"]))
		var pl := ApprenticeActors.plan_for(a)
		pt.note("  %s: %s %s · %s · visible %s at %s" % [a["name"], pl["kind"], pl["station"], a.get("activity", ""), n.visible if n else false, str(n.position) if n else "-"])
		if n and n.visible and str(pl["kind"]) == "station" and n.position.distance_to(_acts().work_spot(str(pl["station"]))["pos"]) < 40.0:
			at_station += 1
	pt.expect(at_station >= 1, "workshop12: apprentices stand at their stations (%d)" % at_station)
	# the smith stands aside in the stock hall door so the miniatures show
	await _bubbles()
	await _view("w12_at_stations", forge_c, 1.5, Vector2(0, 330))
	await pt.tp(forge_c + Vector2(0, 330))
	await _bubbles()
	w.camera.zoom = Vector2(1.7, 1.7)
	w.camera.offset = Vector2(0, -360)
	w.camera.reset_smoothing()
	await pt.wait(0.8)
	await pt.shot("w12_bubbles_zoom")
	w.camera.zoom = Vector2.ONE
	w.camera.offset = Vector2.ZERO
	# ---- the station prompt: walk up to a station an apprentice holds
	var held := ""
	for sid in ["anvil", "forge", "grinding_wheel", "quench_trough", "crucible"]:
		if Apprentices.station_user(sid).begins_with("app_"):
			held = sid
			break
	if held != "":
		var e: Dictionary = pt.find_entry("station", held)
		await pt.tp((e["pos"] as Vector2) + Vector2(-90, -40))
		w.player.facing = "e"
		await pt.wait(0.5)
		var pr := str(pt.U().prompt_label.text)
		pt.expect(pr.contains("step aside"), "workshop12: the prompt explains the %s is in use (%s)" % [held, pr])
		await pt.shot("w12_station_prompt")
	# ---- the property plan with occupancy
	Events.open_panel.emit("property", {})
	await pt.wait(0.6)
	await pt.click("Workshop layout")
	await pt.wait(0.4)
	await pt.shot("w12_property_occupied")
	await pt.close_panel()
	# ---- the ledger while they work
	await pt.press("panel_workshop")
	await pt.wait(0.5)
	await pt.shot("w12_ledger_working")
	await pt.close_panel()
	# ---- the midday break
	await pt.advance_to(12, 15)
	await _settle(6.0)
	var on_break := 0
	for a in Apprentices.staff():
		if str(ApprenticeActors.plan_for(a)["kind"]) == "break":
			on_break += 1
	pt.expect(on_break == 2, "workshop12: both on the midday break (%d)" % on_break)
	var bc: Vector2 = (_acts()._goal.get(str(a1["id"]), {}) as Dictionary).get("pos", w.player.position)
	await _bubbles()
	await _view("w12_break", bc, 1.4, Vector2(-260, 160))
	# ---- the end of the shift: out through the front door
	await pt.advance_to(17, 55)
	await _settle(2.0)
	Game.advance_minutes(10)
	await pt.wait(1.2)
	var walking_out := 0
	for a in Apprentices.staff():
		var n2: NPCActor = _acts().actors.get(str(a["id"]))
		if n2 and n2.visible:
			walking_out += 1
	pt.note("  at 18:05, %d still walking out" % walking_out)
	await _view("w12_shift_end", w.spots["smithy_inside"] + Vector2(0, 180), 1.0, Vector2(-300, 120))
	await pt.wait(16.0)
	var gone := 0
	for a in Apprentices.staff():
		var n3: NPCActor = _acts().actors.get(str(a["id"]))
		if n3 == null or not n3.visible:
			gone += 1
	pt.expect(gone == 2, "workshop12: after the shift both have left (%d)" % gone)
	# ---- next morning: back to work until the longswords are done
	var guard := 0
	while not str(lt.get("state", "")) in ["done", "failed"] and guard < 300:
		Game.advance_minutes(30)
		guard += 1
	pt.expect(str(lt.get("state", "")) == "done", "workshop12: the longswords are finished (%s %s)" % [lt.get("state", ""), lt.get("blocker", "")])
	await pt.wait(0.5)
	var made: Array = lt.get("made", [])
	if not made.is_empty():
		var it := Game.find_uid(int(made[0]))
		pt.expect(ApprenticeUI.is_apprentice_work(it), "workshop12: the piece is %s's work" % a2["name"])
		Events.open_panel.emit("inventory", {})
		await pt.wait(0.6)
		await pt.shot("w12_stores_with_mark")
		await pt.close_panel()
		Events.open_panel.emit("item", {"uid": int(made[0])})
		await pt.wait(0.6)
		await pt.shot("w12_item_inspection")
		await pt.press("cancel")   # the inspection is an overlay, not the current panel
		await pt.wait(0.3)
	# ---- a word with an apprentice in the smithy
	await pt.advance_to(10, 0)
	Game.advance_minutes(1)
	_acts()._last_now = -1
	_acts().sync()
	await pt.wait(0.5)
	var n4: NPCActor = _acts().actors.get(str(a1["id"]))
	if n4 and n4.visible:
		n4.path = PackedVector2Array()
		await pt.tp(n4.position + Vector2(0, 62))
		w.player.facing = "n"
		await pt.wait(0.3)
		await pt.press("interact")
		await pt.wait(0.5)
		pt.expect(pt.panel() is ApprenticeTalkPanel, "workshop12: talking to %s opens the apprentice talk" % a1["name"])
		await pt.click("How is the work going")
		await pt.wait(0.3)
		await pt.shot("w12_talk")
		await pt.close_panel()
	# ---- save and load
	pt.expect(Saves.save("w12_playtest"), "workshop12: saved")
	pt.main.call("load_slot", "w12_playtest")
	await pt.wait(2.5)
	pt.expect(Apprentices.staff().size() == 2, "workshop12: both apprentices after loading")
	_acts()._t = 0.0
	await pt.wait(1.0)
	var shown := 0
	for a in Apprentices.staff():
		var n5: NPCActor = _acts().actors.get(str(a["id"]))
		if n5 and n5.visible:
			shown += 1
	pt.expect(shown == 2, "workshop12: both back in the smithy after loading (%d)" % shown)
	await _view("w12_after_load", w.station_pos("anvil") + Vector2(40, -40), 1.2, Vector2(260, 220))
	Saves.delete("w12_playtest")
