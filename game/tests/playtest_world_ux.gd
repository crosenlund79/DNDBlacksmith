## Rendered play-test phase "world_ux" (UX iteration, WORLD worker): the village map with a shop selected, quick
## travel with honest labels and opening hours, Pell's Provisions' counter screen, the interaction prompts at the
## anvil, a shop and a person (zoomed), a dialogue with a greyed option and its reason, and a closed shop at night.
## Called from tests/playtest.gd (phase_world_ux). Screenshots are named wux_*.
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


## Stand beside an interactable facing it (north of it, or south for a shop counter the customer faces from the
## door side), zoom in, and take a picture of the prompt.
func _prompt_at(e: Dictionary, name: String, zoom := 1.5, from_south := false) -> String:
	var w := _w()
	var off := minf(float(e["r"]) * 0.5, 60.0)
	await pt.tp((e["pos"] as Vector2) + Vector2(0, off if from_south else -off))
	w.player.facing = "n" if from_south else "s"
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.8)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE
	return str(pt.U().prompt_label.text) + " | " + str(pt.U().prompt_sub.text)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var w := _w()
	Game.state["gold"] = 400
	Game.state["world"]["delivery_pending"] = false
	await pt.advance_to(10, 0)
	w._update_schedules(true)
	await pt.wait(0.5)

	# ---- the map: Pell's Provisions selected (as the guidance pages link it)
	Events.open_panel.emit("map", {"venue": "general_store"})
	await pt.wait(0.8)
	var mp := pt.panel() as MapPanel
	pt.expect(mp != null and mp.selected == "general_store", "world_ux: the map opens with Pell's selected")
	await pt.shot("wux_map_pells")
	if mp:
		mp.select("caravan")
		await pt.wait(0.4)
		await pt.shot("wux_map_caravan_away")
	await pt.close_panel()

	# ---- quick travel: the honest line and the hours for Pell's
	Events.open_panel.emit("quick_travel", {})
	await pt.wait(0.6)
	var qt := pt.panel() as QuickTravelMenu
	if qt:
		for d in qt.dests:
			if d["id"] == "provisions":
				qt.wheel.hover = qt.dests.find(d)
				qt.centre_text(d)
		qt.wheel.queue_redraw()
		await pt.wait(0.3)
		pt.expect(qt.status_label.text.begins_with("Open until"), "world_ux: quick travel shows Pell's hours (%s)" % qt.status_label.text)
		await pt.shot("wux_quick_travel")
	await pt.close_panel()

	# ---- Pell's counter by day: the prompt, then the purchasing screen
	var store: Dictionary = pt.find_entry("store", "general_store")
	pt.expect(not store.is_empty(), "world_ux: Pell's counter exists")
	if not store.is_empty():
		var t := await _prompt_at(store, "wux_prompt_shop", 1.5, true)
		pt.expect(t.contains("Buy (open until 19:00)"), "world_ux: shop prompt: %s" % t)
		await pt.press("interact")
		await pt.wait(0.6)
		pt.expect(pt.panel() is HerbalistPanel, "world_ux: E at Pell's opens the counter")
		await pt.shot("wux_pells_counter")
		await pt.click("Buy 1")
		await pt.wait(0.4)
		await pt.close_panel()

	# ---- the anvil
	var anvil: Dictionary = pt.find_entry("station", "anvil")
	if not anvil.is_empty():
		var ta := await _prompt_at(anvil, "wux_prompt_anvil", 1.3)
		pt.expect(ta.contains("[E]") and ta.contains("Reforge"), "world_ux: anvil prompt: %s" % ta)

	# ---- a person: Aldric behind his counter
	var al: NPCActor = w.npcs.get("aldric")
	if al and al.visible:
		al.path = PackedVector2Array()
		await pt.tp(al.position + Vector2(0, 70))
		w.player.facing = "n"
		w.camera.zoom = Vector2(1.5, 1.5)
		w.camera.reset_smoothing()
		await pt.wait(0.8)
		var tn := str(pt.U().prompt_label.text)
		pt.expect(tn.contains("Talk") and tn.contains("Buy"), "world_ux: Aldric prompt: %s" % tn)
		await pt.shot("wux_prompt_npc")
		w.camera.zoom = Vector2.ONE

	# ---- the evening: Aldric at the inn, the counter option greyed with its reason
	await pt.advance_to(19, 30)
	w._update_schedules(true)
	await pt.wait(0.5)
	if await pt.talk_to("aldric"):
		var dis := false
		for b in pt.panel().find_children("*", "Button", true, false):
			if (b as Button).disabled and (b as Button).text.contains("Buy from the counter"):
				dis = true
		pt.expect(dis, "world_ux: the counter option is shown disabled with its reason in the evening")
		await pt.shot("wux_dialogue_greyed")
		await pt.close_panel()

	# ---- night: the shop is closed; the prompt says when it opens and E does not open the screen
	await pt.advance_to(22, 0)
	w._update_schedules(true)
	if not store.is_empty():
		var tc := await _prompt_at(store, "wux_closed_night", 1.5, true)
		pt.expect(tc.contains("Closed — opens 7:00"), "world_ux: closed prompt: %s" % tc)
		await pt.press("interact")
		await pt.wait(0.3)
		pt.expect(not (pt.panel() is HerbalistPanel), "world_ux: a closed counter does not open")
		await pt.shot("wux_closed_toast")
