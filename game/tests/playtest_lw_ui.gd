## Rendered play-test phase "lw_ui" (The Living Workshop — the UI worker: interface and information, playtest #38,
## #42–44, #46–47, #54–55). What the player sees: the HUD's top-left counters with a large purse (#43); the Save and
## Load screens with ten manual slots (#42); the caravan's arrival (#44); an adventurer's health over time on the
## character sheet (#38); the material ledger (#46); the counter, the commissions book and the inn telling waiting
## customers, commission opportunities and visiting adventurers apart (#54–55); and the busiest panels at their new,
## tighter sizes (#47).
## Written against APIs that exist before the Living Workshop too (new screens are reached through Events.open_panel
## and looked up by node name), so the same phase gives the BEFORE pictures on the base build.
## LWUI_TAG=before|after names the shots (lwui_<tag>_<what>); LWUI_ONLY=hud,saves,… runs a subset.
## Called from tests/playtest.gd (phase_lw_ui). Screenshots: lwui_*.
extends RefCounted

var pt: Node
var tag := "now"
var only: PackedStringArray = []


func _on(part: String) -> bool:
	return only.is_empty() or only.has(part)


func _shot(what: String) -> void:
	await pt.shot("lwui_%s_%s" % [tag, what])


func _open(id: String, args := {}) -> Control:
	await pt.close_panel()
	Events.open_panel.emit(id, args)
	await pt.wait(0.8)
	return pt.panel()


func _scroll_all(root: Node, v: int) -> void:
	if root == null:
		return
	for c in root.find_children("*", "ScrollContainer", true, false):
		(c as ScrollContainer).scroll_vertical = v


## The tallest/widest a panel lays out to (its combined minimum), against the 1920×1080 canvas.
func _fits(p: Control, what: String) -> void:
	if p == null:
		pt.expect(false, "lw_ui: %s opens" % what)
		return
	var ms := p.get_combined_minimum_size()
	pt.note("   %s: minimum %d×%d, on screen %d×%d" % [what, int(ms.x), int(ms.y), int(p.size.x), int(p.size.y)])
	pt.expect(ms.x <= 1920.0 and ms.y <= 1080.0, "lw_ui: %s fits the 1920×1080 canvas (%d×%d)" % [what, int(ms.x), int(ms.y)])


func run(p: Node) -> void:
	pt = p
	tag = OS.get_environment("LWUI_TAG")
	if tag == "":
		tag = "now"
	var o := OS.get_environment("LWUI_ONLY")
	if o != "":
		only = o.split(",")
	# this phase's own save folder (the shared play-test folder holds other phases' saves, some mid-run)
	Saves.use_test_dir("lw_ui_" + tag)
	for sl in Saves.SLOTS:
		Saves.delete(sl)
	await pt.click("New Game")
	await pt.wait(2.5)
	Game.state["gold"] = 5000
	await pt.grant_full_workshop()
	await pt.advance_to(10, 0)
	if _on("hud"):
		await _hud()
	if _on("saves"):
		await _saves()
	if _on("caravan"):
		await _caravan()
	if _on("health"):
		await _health()
	if _on("materials"):
		await _materials()
	if _on("counter"):
		await _counter()
	if _on("panels"):
		await _panels()


# ---------------------------------------------------------------- #43 the HUD counters with a large purse
func _hud() -> void:
	await pt.close_panel()
	Game.state["gold"] = 1234567
	Game.add_item(Items.make("coal", {"qty": 9876}), false)
	Events.gold_changed.emit(Game.gold())
	await pt.wait(0.6)
	var ui: UIRoot = pt.U()
	var gl: Label = ui.gold_label
	pt.expect(gl.text.contains("1") and gl.text.contains("567"), "lw_ui: the HUD shows the whole purse (%s)" % gl.text)
	# the purse label must not be cut by its panel or the screen: its full text fits its own width
	var f := gl.get_theme_font("font")
	var need := f.get_string_size(gl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, gl.get_theme_font_size("font_size")).x
	var gr := gl.get_global_rect()
	pt.note("   gold label '%s' needs %d px, has %d px at x %d" % [gl.text, int(need), int(gr.size.x), int(gr.position.x)])
	pt.expect(gr.size.x + 0.5 >= need and gr.end.x <= 1920.0, "lw_ui: the gold counter is not clipped")
	var panel_rect := (gl.get_parent().get_parent() as Control).get_global_rect()
	pt.expect(panel_rect.has_point(gr.position) and panel_rect.encloses(gr), "lw_ui: the gold counter sits inside its HUD plate")
	await _shot("hud_big_purse")
	Game.state["gold"] = 5000
	Events.gold_changed.emit(Game.gold())


# ---------------------------------------------------------------- #42 ten save slots
func _saves() -> void:
	var sp := await _open("saves", {"mode": "save"})
	_fits(sp, "the Save screen")
	await _shot("save_screen")
	var n := 0
	if sp:
		for b in sp.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Save") or (b as Button).text.begins_with("Overwrite"):
				n += 1
	pt.note("   save buttons: %d" % n)
	pt.expect(n >= 10 or tag == "before", "lw_ui: the Save screen offers ten manual slots (%d)" % n)
	await pt.close_panel()
	# a game in the tenth slot (where it exists) and the Load screen
	var last := "slot_10" if Saves.SLOTS.has("slot_10") else "slot_3"
	pt.expect(Saves.save(last), "lw_ui: saving to %s" % last)
	Saves.save("quicksave")
	var lp := await _open("saves", {"mode": "load"})
	_fits(lp, "the Load screen")
	pt.expect(lp != null and pt.find_label_containing(lp, "Day %d" % Game.day()) != null, "lw_ui: the Load screen lists the saved game")
	await _shot("load_screen")
	await pt.close_panel()


# ---------------------------------------------------------------- #44 the caravan arrives
func _caravan() -> void:
	await pt.close_panel()
	await pt.tp(pt.W().spots.get("smithy_door_out", pt.W().player.position))
	if Commerce.caravan_present():
		Commerce.dev_caravan_leave()
		await pt.wait(0.5)
	var jn := (Game.state["journal"] as Array).size()
	Commerce.dev_force_caravan()
	await pt.wait(1.0)
	await _shot("caravan_arrival")
	pt.expect(Commerce.caravan_present(), "lw_ui: the caravan is in town")
	var journaled := (Game.state["journal"] as Array).size() > jn
	pt.expect(journaled or tag == "before", "lw_ui: the arrival is written in the journal")
	await pt.wait(7.0)   # the toast has faded: what still tells the player?
	var chip := pt.U().hud.find_child("CaravanChip", true, false) as Control
	pt.expect((chip != null and chip.visible) or tag == "before", "lw_ui: a caravan chip stays on the HUD while it is in town")
	await _shot("caravan_after_toast")


# ---------------------------------------------------------------- #38 health over time
func _health() -> void:
	await pt.close_panel()
	# a few real days: expeditions leave, fight, come home and recover
	for d in 4:
		Game.advance_minutes(1440)
		await pt.wait(0.1)
	var pick := ""
	for e in Expeditions.done():
		for id in e["party"]:
			if Adv.get_a(str(id)).get("status", "") != "dead":
				pick = str(id)
				break
		if pick != "":
			break
	if pick == "":
		pick = "elowen"
	pt.note("   health page for %s" % pick)
	var dp := await _open("dossier", {"id": pick, "tab": "Overview"})
	_fits(dp, "the character sheet")
	var curve := dp.find_child("HealthCurve", true, false) if dp else null
	pt.expect(curve != null or tag == "before", "lw_ui: the character sheet draws a health curve")
	await _shot("dossier_health")
	await pt.close_panel()


# ---------------------------------------------------------------- #46 the material ledger
func _materials() -> void:
	await pt.close_panel()
	# acquisitions and use from now on: bought, crafted with
	Game.add_item(Items.make("ore_iron", {"qty": 5}), false)
	Game.remove_def("coal", 2)
	var ip := await _open("inventory")
	_fits(ip, "the stores")
	await _shot("inventory")
	var mp := await _open("materials")
	var ok := mp != null and mp.name == "MaterialLedger"
	pt.expect(ok or tag == "before", "lw_ui: the material ledger opens")
	if ok:
		_fits(mp, "the material ledger")
		await _shot("material_ledger")
	await pt.close_panel()


# ---------------------------------------------------------------- #54–55 who is who at the counter, the book and the inn
func _counter() -> void:
	await pt.close_panel()
	Shop.customers().clear()
	var town := Adv.in_town()
	var ids: Array = town.map(func(a): return str(a["id"]))
	pt.note("   in town: %s" % ", ".join(ids))
	# a waiting customer (repair), a browsing adventurer, a multi-part request
	Shop._add_customer("martha", "repair")
	if ids.size() > 0:
		Shop._add_customer(str(ids[0]), "browse")
	if ids.size() > 1:
		Shop._add_customer(str(ids[1]), "multi")
	for c in Shop.customers():
		Shop.mark_arrived(str(c["npc"]), false)
	# an open commission and an adventurer with a need nobody has asked about yet (the inn opportunity)
	if ids.size() > 2:
		Shop.create_order(str(ids[2]), "")
	var opp := ""
	for a in town:
		if str(a.get("needs", "")) != "" and not Shop.open_orders().any(func(x): return x["npc"] == a["id"]) and Shop.customer(str(a["id"])).is_empty():
			opp = str(a["id"])
			break
	pt.note("   inn opportunity: %s" % opp)
	var sp := await _open("shop", {"tab": "customers"})
	_fits(sp, "the counter")
	await _shot("counter_customers")
	var op := await _open("orders")
	_fits(op, "the commissions book")
	pt.expect(op != null and (pt.find_label_containing(op, "opportunit") != null or tag == "before"), "lw_ui: the commissions book lists opportunities")
	await _shot("commissions")
	# further down the book: the opportunities (before: the end of the list)
	var sec: Control = (op.find_child("Section_opportunity", true, false) as Control) if op != null else null
	if sec != null:
		for sc in op.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).ensure_control_visible(sec)
	else:
		_scroll_all(op, 100000)
	await pt.wait(0.4)
	await _shot("commissions_lower")
	if op != null and pt.find_label_containing(op, "Ask what they need forged") != null:
		pt.expect(true, "lw_ui: the book says how to ask")
	var ap := await _open("adventurers")
	_fits(ap, "the adventurers' roster")
	await _shot("adventurers")
	if opp != "":
		await _open("dialogue", {"npc": opp, "area": "inn"})
		await _shot("inn_talk_opportunity")
	await pt.close_panel()


# ---------------------------------------------------------------- #47 the busiest panels
func _panels() -> void:
	await pt.close_panel()
	for spec in [["inventory", {}, "inventory_panel"], ["shop", {"tab": "stock"}, "shop_stock"], ["shop", {"tab": "ledger"}, "shop_ledger"],
			["station", {"id": "anvil"}, "station_anvil"], ["steward", {}, "steward"], ["workshop", {}, "workshop_ledger"],
			["help", {}, "help"], ["dossier", {"id": "elowen", "tab": "Combat"}, "dossier_combat"]]:
		var p := await _open(str(spec[0]), spec[1])
		_fits(p, str(spec[2]))
		await _shot(str(spec[2]))
	await pt.close_panel()
