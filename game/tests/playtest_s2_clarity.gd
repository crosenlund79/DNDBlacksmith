## Rendered play-test phase "s2_clarity" (Milestone S2 — the CLARITY worker: workshop clarity and physical presence).
## What the player sees: a leather batch says what decided its size (and that its grade is not kept); a station names
## its skill check in the world prompt and the panel; returns bags (a hireling's haul with linen thread, an expedition
## find, a sponsor delivery) lie clear of the Loft stair; a potion customer is offered only what they asked for, the
## rest greyed with why; the optional "only what they would buy / can buy" filters; the contracts panel opened on a
## closed order; the quiet hint ring on the nearest usable station; the forge light by day and at night; apprentices
## at their stations (forge room, leather room, the Loft) and in Steward Mode; the smithy's front entrance.
## Written against APIs that exist before S2 too, so the same phase gives the BEFORE pictures on the base build.
## Called from tests/playtest.gd (phase_s2_clarity). Screenshots: s2c_*.
extends RefCounted

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _view(name: String, plan_center: Vector2, zoom := 0.55) -> void:
	var w := _w()
	await pt.tp(w.bpos("smithy", plan_center.x, plan_center.y))
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.7)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE


func _rebuild() -> void:
	pt.main.call("rebuild_world")
	await pt.wait(2.5)


func _text(root: Node, needle: String) -> bool:
	return root != null and pt.find_label_containing(root, needle) != null


func _checkbox(root: Node, nm: String) -> CheckBox:
	if root == null:
		return null
	return root.find_child(nm, true, false) as CheckBox


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Shop.customers().clear()
	Game.state["gold"] = 5000
	await pt.grant_full_workshop()   # every room (the Loft too) and every station: the user's situation
	await pt.advance_to(10, 0)
	await _leather()
	await _checks()
	await _bags()
	await _goods()
	await _offer_filter()
	await _vendor_filter()
	await _contract_closed()
	await _hint()
	await _forge_light()
	await _apprentices()
	await _entrance()


# ---------------------------------------------------------------- 1. leather curing: quantity versus quality
func _cure(q: float, purity: int) -> Dictionary:
	Game.add_item(Items.make("leather_hide", {"qty": 2}), false)
	if not Crafting.start("cure_leather"):
		pt.note("   cure_leather could not start: %s" % Crafting.recipe_locked_reason("cure_leather"))
		return {}
	Crafting.record_step("leather_vat", [q])
	return Crafting.finish({"purity": purity}, "digital")


func _leather() -> void:
	var it := _cure(96.0, 4)
	pt.expect(not it.is_empty() and int(it.get("qty", 0)) == 2, "s2_clarity: an ordinary batch of cured leather is 2 units")
	Events.open_panel.emit("craft_result", {"item": it, "fresh": true})
	await pt.wait(0.8)
	pt.expect(_text(pt.panel(), "105%"), "s2_clarity: the result names the bonus-unit rule (105% craftsmanship or a purity 6)")
	pt.expect(_text(pt.panel(), "not their grade"), "s2_clarity: and says the batch's craftsmanship is not kept")
	await pt.shot("s2c_leather_plain")
	await pt.close_panel()
	var it2 := _cure(112.0, 3)
	pt.expect(not it2.is_empty() and int(it2.get("qty", 0)) == 3, "s2_clarity: excellent work yields a third unit")
	Events.open_panel.emit("craft_result", {"item": it2, "fresh": true})
	await pt.wait(0.8)
	pt.expect(_text(pt.panel(), "+1 bonus unit"), "s2_clarity: the result says what earned the extra unit")
	await pt.shot("s2c_leather_bonus")
	await pt.close_panel()


# ---------------------------------------------------------------- 2. the skill check named before the work
func _checks() -> void:
	var w := _w()
	for sid in ["bellows", "anvil"]:
		await pt.tp(w.station_pos(sid) + Vector2(0, 70))
		w.player.facing = "n"
		await pt.wait(1.3)
		var line := str(pt.U().prompt_label.text)
		pt.note("   prompt at %s: %s" % [sid, line])
		pt.expect(line.contains("alignment" if sid == "bellows" else "precision ring"), "s2_clarity: the %s prompt names its check" % sid)
		await pt.shot("s2c_prompt_%s" % sid)
	Events.open_panel.emit("station", {"id": "bellows"})
	await pt.wait(0.8)
	pt.expect(_text(pt.panel(), "Spark & Ember alignment") and not _text(pt.panel(), "needle"), "s2_clarity: the bellows panel describes the alignment check, not a ring's needle")
	await pt.shot("s2c_station_bellows")
	await pt.close_panel()


# ---------------------------------------------------------------- 3. floor drops clear of the Loft stair
func _bags() -> void:
	var ret: Array = Game.state["returns"]
	ret.clear()
	ret.append(Loot.make_container("bag_traveller", [Items.make("thread_linen", {"qty": 6}), Items.make("leather_cured", {"qty": 2})], "Borin", "Borin's trade run: linen thread and cured leather."))
	ret.append(Loot.make_container("bag_traveller", [Items.make("ingot_iron", {"qty": 4})], "Borin", "Smelted at the mine."))
	ret.append(Loot.make_container("chest_recovered", [Items.make("ore_silver", {"qty": 3})], "Mira", "Found in the barrows."))
	ret.append(Loot.make_container("bag_traveller", [Items.make("thread_linen", {"qty": 3})], "Kestra", "From the market."))
	ret.append(Loot.make_container("purse_gift", [], "Aldric Pell", "A little something."))
	ret.append(Loot.make_container("bag_traveller", [Items.make("cloth_linen", {"qty": 2})], "Borin", "Woven at the harbour lofts."))
	_w()._refresh_bags()
	await pt.wait(0.4)
	var stair := Rect2()
	for f in Property.floors():
		if f.has("down_stairs"):
			stair = Rect2(_w().bpos("smithy", float(f["down_stairs"][0]), float(f["down_stairs"][1])) - Vector2(48, 64), Vector2(96, 128))
	var under := 0
	for e in _w().interactables:
		if str(e["kind"]) == "bag" and stair.grow(-4.0).intersects(Rect2((e["pos"] as Vector2) - Vector2(32, 24), Vector2(64, 48))):
			under += 1
	pt.expect(stair.size != Vector2.ZERO and under == 0, "s2_clarity: no bag lies under the Loft stair (%d do)" % under)
	await _view("s2c_bags_stock_hall", Vector2(18.3, 6.7), 0.75)
	ret.clear()
	_w()._refresh_bags()


# ---------------------------------------------------------------- 4. a potion customer: what they asked for
func _goods() -> void:
	Shop.customers().clear()
	Shop.customers().append({"npc": "martha", "want": "goods", "seat": 0, "present": true, "arrived": Game.day() * 24 + Game.hour(),
		"budget": 50, "looking_for": "potion_healing"})
	for d in ["potion_healing", "oil_whetstone", "coating_flame", "infusion_aether"]:
		Game.add_item(Items.make(d, {"qty": 2}), false)
	Events.open_panel.emit("shop", {"tab": "customers", "npc": "martha"})
	await pt.wait(0.8)
	var pn: Control = pt.panel()
	var enabled := []
	for b in pn.find_children("*", "Button", true, false):
		var t := (b as Button).text
		if not (b as Button).disabled and (t.contains(" g") and (t.contains("Oil") or t.contains("Coating") or t.contains("Infusion") or t.contains("Sell one"))):
			enabled.append(t)
	pt.note("   enabled potion buttons: %s" % str(enabled))
	pt.expect(enabled.size() == 1, "s2_clarity: only the healing draught can be sold to her (%d enabled)" % enabled.size())
	pt.expect(_text(pn, "not what they asked for"), "s2_clarity: the others say why not")
	await pt.shot("s2c_goods_offers")
	var cb := _checkbox(pn, "OnlyBuyable")
	pt.expect(cb != null and not cb.button_pressed, "s2_clarity: an optional filter, off by default")
	if cb != null:
		cb.button_pressed = true
		await pt.wait(0.6)
		await pt.shot("s2c_goods_filtered")
		cb = _checkbox(pt.panel(), "OnlyBuyable")
		if cb != null:
			cb.button_pressed = false
			await pt.wait(0.3)
	# BUG-043: a sale of another potion is refused
	var oil := {}
	for it in Game.inventory():
		if str(it["def"]) == "oil_whetstone":
			oil = it
	pt.expect(not oil.is_empty() and Shop.sell_goods("martha", int(oil["uid"])) != "", "s2_clarity: whetstone oil does not fill a request for a healing draught")
	await pt.close_panel()
	Shop.customers().clear()


# ---------------------------------------------------------------- 5. the adventurer's offer grid with the filter
func _offer_filter() -> void:
	var mira := Adv.get_a("mira")
	mira["status"] = "in_town"
	mira["gold"] = 140
	for d in ["sword_iron", "sword_iron", "dagger_iron", "helm_iron", "shield_round", "sword_steel"]:
		var it := Items.make(d, {"quality": 92.0})
		if it.is_empty():
			continue
		it["for_sale"] = true
		Game.add_item(it, false)
	Shop.customers().append({"npc": "mira", "want": "browse", "seat": 0, "present": true, "arrived": Game.day() * 24 + Game.hour(), "slot": "weapon"})
	Events.open_panel.emit("shop", {"tab": "customers", "npc": "mira"})
	await pt.wait(0.8)
	await pt.shot("s2c_offer_grid")
	var cb := _checkbox(pt.panel(), "OnlyBuyable")
	if cb != null:
		cb.button_pressed = true
		await pt.wait(0.6)
		await pt.shot("s2c_offer_grid_filtered")
		cb = _checkbox(pt.panel(), "OnlyBuyable")
		if cb != null:
			cb.button_pressed = false
	await pt.close_panel()
	Shop.customers().clear()


# ---------------------------------------------------------------- 6. a village counter with the filter
func _vendor_filter() -> void:
	var g0 := Game.gold()
	Game.state["gold"] = 25
	Events.open_panel.emit("herbalist", {"id": "herbalist"})
	await pt.wait(0.8)
	await pt.shot("s2c_vendor")
	var cb := _checkbox(pt.panel(), "OnlyAffordable")
	if cb != null:
		cb.button_pressed = true
		await pt.wait(0.6)
		await pt.shot("s2c_vendor_filtered")
		cb = _checkbox(pt.panel(), "OnlyAffordable")
		if cb != null:
			cb.button_pressed = false
	await pt.close_panel()
	Game.state["gold"] = g0


# ---------------------------------------------------------------- 7. the contracts panel on a closed order
func _contract_closed() -> void:
	if not Contracts.bench_installed():
		pt.note("   no Project Bench installed — skipped")
		return
	# the Watch's order: a 61-character title (UIKit.label wraps beyond 48 characters — BUG-001's trigger)
	var o := Contracts.make_offer("watch_arms")
	if o.has("error"):
		pt.note("   offer: %s" % str(o["error"]))
		return
	var cid := str(o["id"])
	Events.open_panel.emit("contracts", {"id": cid})
	await pt.wait(1.0)
	pt.expect(_narrow(pt.panel()) == 0, "s2_clarity: the letter's header is not squeezed into a narrow column (%d narrow)" % _narrow(pt.panel()))
	await pt.shot("s2c_contract_letter")
	await pt.close_panel()
	pt.expect(Contracts.accept(cid) == "", "s2_clarity: a contract accepted")
	var c := Contracts.get_c(cid)
	for d in Contracts.materials_needed(c):
		Game.add_item(Items.make(str(d), {"qty": int(Contracts.materials_needed(c)[d])}), false)
	for d in c["rare"]:
		Game.add_item(Items.make(str(d), {"qty": int(c["rare"][d])}), false)
	var g := 0
	while not Contracts.ready(cid) and g < 200:
		Vitality.set_fatigue(0.0)
		var r := Contracts.work(cid, 4)
		if str(r.get("error", "")) != "":
			pt.note("   work stopped: %s" % r["error"])
			break
		g += 1
	var res := Contracts.deliver(cid)
	pt.note("   delivered: %s" % str(res.get("outcome", res.get("error", "?"))))
	Events.open_panel.emit("contracts", {"id": cid})
	await pt.wait(1.0)
	var pn: Control = pt.panel()
	var narrow := _narrow(pn)
	pt.expect(pn != null and narrow == 0, "s2_clarity: the closed order's text is not squeezed into a narrow column (%d narrow)" % narrow)
	await pt.shot("s2c_contract_closed")
	await pt.close_panel()


## Visible text boxes holding more than a few words but squeezed under 300 px wide (one letter per line).
func _narrow(pn: Control) -> int:
	var n := 0
	if pn == null:
		return 0
	for l in pn.find_children("*", "Label", true, false):
		var lb := l as Label
		if lb.is_visible_in_tree() and lb.text.length() > 30 and lb.size.x < 300.0:
			n += 1
	for l in pn.find_children("*", "RichTextLabel", true, false):
		var rl := l as RichTextLabel
		if rl.is_visible_in_tree() and rl.get_parsed_text().length() > 40 and rl.size.x < 300.0:
			n += 1
	return n


# ---------------------------------------------------------------- 8. the quiet hint ring
func _hint() -> void:
	var w := _w()
	Game.add_item(Items.make("ingot_iron", {"qty": 6}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 3}), false)
	await pt.tp(w.station_pos("anvil") + Vector2(-60, 230))
	w.player.facing = "n"
	await pt.wait(1.2)
	var ring: Node = w.find_child("HintRing", true, false)
	pt.expect(ring != null and (ring as CanvasItem).visible, "s2_clarity: a quiet ring marks a usable station nearby")
	await _view_here("s2c_hint_nearby", 0.85)


func _view_here(name: String, zoom: float) -> void:
	var w := _w()
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(0.7)
	await pt.shot(name)
	w.camera.zoom = Vector2.ONE


# ---------------------------------------------------------------- 9. the forge at day and at night
func _forge_light() -> void:
	await pt.advance_to(14, 0)
	await _view("s2c_forge_day", Vector2(5.0, 5.5), 0.7)
	await pt.advance_to(18, 30)
	await _view("s2c_forge_evening", Vector2(5.0, 5.5), 0.7)
	await pt.advance_to(22, 0)
	var fl: Node = _w().find_child("ForgeNightLight", true, false)
	pt.expect(fl != null and (fl as PointLight2D).visible and (fl as PointLight2D).energy > 0.5, "s2_clarity: the forge's night light burns")
	await _view("s2c_forge_night", Vector2(5.0, 5.5), 0.7)


# ---------------------------------------------------------------- 10. apprentices at their stations
func _apprentices() -> void:
	(Game.state["hirelings"] as Array).clear()
	# the loom goes up to the weaving loft
	var plan := Property.plan_copy()
	pt.note("   loom upstairs: %s" % Property.place(plan, "loom", Vector2(112.6, 25.0)))
	pt.note("   commit: %s" % Property.commit(plan))
	pt.note(ApprenticeDev.unlock())
	var staff := []
	for i in 4:
		Apprentices.refresh_applicants()
		var gg := 0
		while Apprentices.applicants().is_empty() and gg < 10:
			ApprenticeDev.add_applicant()
			gg += 1
		Game.state["gold"] = 20000
		var err := Apprentices.hire(0)
		if err != "":
			pt.note("   hire: %s" % err)
			continue
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []
		a["rank"] = "apprentice"
		for sk in ["smithing", "enchanted_stitching", "alchemy", "runecraft"]:
			a["skills"][sk] = {"lvl": 4, "xp": 0}
		staff.append(a)
	await pt.advance_to(7, 50)
	Game.add_item(Items.make("ingot_iron", {"qty": 4}), false)
	Game.add_item(Items.make("leather_cured", {"qty": 2}), false)
	Game.add_item(Items.make("leather_hide", {"qty": 6}), false)
	Game.add_item(Items.make("thread_linen", {"qty": 9}), false)
	var jobs := [["craft", "iron_longsword"], ["prep", "cure_leather"], ["prep", "weave_linen"]]
	for i in mini(jobs.size(), staff.size()):
		var t := Apprentices.add_task(str(jobs[i][0]), {"recipe": str(jobs[i][1]), "assignee": str(staff[i]["id"]), "repeat": 3})
		pt.note("   task %s for %s: %s" % [jobs[i][1], staff[i]["name"], str(t.get("error", "queued"))])
	await _rebuild()
	var acts := _w().get_node("ApprenticeActors") as ApprenticeActors
	var g := 0
	while g < 40:
		Game.advance_minutes(5)
		g += 1
		var busy := 0
		for a in staff:
			if str(ApprenticeActors.plan_for(a)["kind"]) == "station":
				busy += 1
		if busy >= mini(3, staff.size()):
			break
	acts._last_now = -1
	acts.sync()
	await pt.wait(1.0)
	for a in staff:
		var pl := ApprenticeActors.plan_for(a)
		var n: NPCActor = acts.actors.get(str(a["id"]))
		var where := _w().room_at("smithy", n.position) if n != null else ""
		if where == "" and n != null:
			where = _w().room_at("smithy_loft", n.position)
		pt.note("   %s: plan %s at %s (user %s) — visible %s, in room '%s'" % [a["name"], pl["kind"], pl["station"],
			Apprentices.station_user(str(pl["station"])) if str(pl["station"]) != "" else "-", str(n != null and n.visible), where])
		if str(pl["kind"]) == "station":
			var sroom := _w().room_at("smithy", _w().station_pos(str(pl["station"])))
			if sroom == "":
				sroom = _w().room_at("smithy_loft", _w().station_pos(str(pl["station"])))
			pt.expect(n != null and n.visible and n.position.distance_to(_w().station_pos(str(pl["station"]))) < 200.0 and where == sroom,
				"s2_clarity: %s is visible at the %s (%s)" % [str(a["name"]).split(" ")[0], pl["station"], sroom])
	await _view("s2c_apprentices_ground", Vector2(9.0, 10.0), 0.5)
	await _view("s2c_apprentices_loft", Vector2(112.0, 26.0), 0.7)
	# Steward Mode: the workshop runs on — the apprentices stay where their work is
	var why := Steward.activate()
	pt.note("   steward: %s" % (why if why != "" else "active"))
	if why == "":
		Game.advance_minutes(20)
		acts._last_now = -1
		acts.sync()
		await pt.wait(1.0)
		var seen := 0
		for a in staff:
			var n2: NPCActor = acts.actors.get(str(a["id"]))
			if n2 != null and n2.visible:
				seen += 1
		pt.expect(seen >= mini(3, staff.size()), "s2_clarity: in Steward Mode the apprentices are still at work (%d visible)" % seen)
		await _view("s2c_apprentices_steward", Vector2(9.0, 10.0), 0.5)
		Steward.deactivate()
		await pt.wait(0.5)
		await pt.close_panel()
	for a in staff:
		Apprentices.dismiss(str(a["id"]))


# ---------------------------------------------------------------- 11. the smithy's front entrance
func _entrance() -> void:
	await pt.advance_to(11, 0)
	var w := _w()
	var door: Vector2 = w.spots.get("smithy_door_out", w.bpos("smithy", 14.0, -1.0))
	await pt.tp(door + Vector2(0, -120))
	w.camera.zoom = Vector2(0.45, 0.45)
	w.camera.reset_smoothing()
	await pt.wait(0.8)
	await pt.shot("s2c_entrance_north")
	await pt.tp(w.bpos("smithy", 14.0, 25.5))
	w.camera.zoom = Vector2(0.45, 0.45)
	w.camera.reset_smoothing()
	await pt.wait(0.8)
	await pt.shot("s2c_entrance_south")
	w.camera.zoom = Vector2.ONE
