## Rendered play-test phase "smithy_rl" (The Living Realm, milestone 2a — the evolving smithy): every discipline room
## at the Modest tier and again at the Established/Masterwork tiers (banners, names, dressing), the Loft (bought,
## furnished, stations upstairs), the stair and the aetheric lift (one step each way), the layout editor's floor
## switcher on both floors and the lift box, an apprentice working at the anvil upstairs, and "Walk to the …" /
## "Craft again". Called from tests/playtest.gd (phase_smithy_rl). Screenshots are named srl_*.
extends RefCounted

var pt: Node
const T := 64.0


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


func _place_upstairs(pairs: Array) -> void:
	var plan := Property.plan_copy()
	for pr in pairs:
		var sid: String = pr[0]
		if not (plan["stations"] as Dictionary).has(sid) and not (plan["stored"] as Array).has(sid):
			(plan["stored"] as Array).append(sid)
		var why := Property.place(plan, sid, pr[1])
		pt.note("   place %s upstairs: %s" % [sid, why if why != "" else "ok"])
	var err := Property.commit(plan)
	pt.expect(err == "", "smithy_rl: the two-floor layout is accepted (%s)" % err)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	(Game.state["hirelings"] as Array).clear()   # keep the rooms clear of Borin for the pictures
	Game.state["gold"] = 300
	# ---- Modest: a new smith who has bought the neighbours' rooms and set up their stations, skills still low
	for u in ["cobbler", "laundry", "weaver", "chandler", "cellar"]:
		Property.dev_grant_unit(u)
	(Game.state["upgrades"] as Array).append("arcane_foundry")
	Property.dev_install_in_owned()
	SkillTree.unlock_all()
	await _rebuild()
	pt.expect(Smithy.room_tier(Property.room_by_id(Property.rooms(), "forge_room")) == 0, "smithy_rl: a new smith's rooms are Modest")
	await _view("srl_modest_forge_rune", Vector2(5.0, 9.0), 0.62)
	await _view("srl_modest_alchemy_leather", Vector2(13.0, 14.0), 0.62)
	await _view("srl_modest_arcane_store", Vector2(9.0, 20.0), 0.62)
	# ---- progress: skills, a famous name — the rooms grow
	for sk in ["smithing", "runecraft", "alchemy", "enchanted_stitching", "arcane_metalwork"]:
		var sset: Dictionary = Game.state["player"]["skills"]
		sset[sk] = {"lvl": 14, "xp": 0}
	Game.state["gold"] = 4000
	await _rebuild()
	var tiers := []
	for r in Property.rooms():
		if Property.room_owned(r) and Property.kind(r) == "workshop" and Smithy.trade(r) != "":
			tiers.append("%s=%s" % [r["id"], Smithy.TIER_NAMES[Smithy.room_tier(r)]])
	pt.note("   tiers: " + ", ".join(tiers))
	pt.expect(Smithy.room_tier(Property.room_by_id(Property.rooms(), "forge_room")) == 2, "smithy_rl: a renowned master's smithing hall is Masterwork")
	await _view("srl_master_forge_rune", Vector2(5.0, 9.0), 0.62)
	await _view("srl_master_alchemy_leather", Vector2(13.0, 14.0), 0.62)
	await _view("srl_master_arcane_store", Vector2(9.0, 20.0), 0.62)
	await _view("srl_master_whole_ground", Vector2(15.0, 11.5), 0.42)
	# ---- the Loft: bought after Ilse's room; the West Garret next to it
	Game.state["gold"] = 6000
	pt.expect(Property.buy_unit("loft") == "", "smithy_rl: the Loft is bought")
	pt.expect(Property.buy_unit("garret") == "", "smithy_rl: the West Garret is bought")
	_place_upstairs([["loom", Vector2(112.6, 25.0)], ["cutting_table", Vector2(116.8, 25.0)], ["tailors_bench", Vector2(112.6, 30.2)],
		["alembic", Vector2(102.6, 20.4)], ["mortar_station", Vector2(106.6, 20.4)], ["reagent_table", Vector2(102.8, 24.8)],
		["rune_polishing_wheel", Vector2(102.4, 30.6)], ["resonance_pedestal", Vector2(106.4, 30.6)]])
	await _rebuild()
	await _view("srl_ground_stair", Vector2(13.5, 9.0), 0.8)
	var up: Dictionary = pt.find_entry("stairs", "smithy_loft")
	pt.expect(not up.is_empty(), "smithy_rl: a stair rises from the stock hall")
	if not up.is_empty():
		await pt.use("stairs", "smithy_loft")
		await pt.wait(0.6)
		pt.expect(_w().area == "smithy_loft", "smithy_rl: the stair leads up into the Loft (%s)" % _w().area)
		await pt.shot("srl_loft_arrive_stair")
	await _view("srl_loft_whole", Vector2(109.5, 26.0), 0.55)
	# ---- the aetheric lift: the old hoist first, then rigged
	await _view("srl_hoist_unrigged", Vector2(16.0, 14.0), 0.85)
	pt.expect(Property.buy_lift() == "", "smithy_rl: the lift is rigged (%s)" % Property.lift_reason())
	await _rebuild()
	await _view("srl_lift_ground", Vector2(16.0, 14.4), 0.85)
	var lift: Dictionary = pt.find_entry("lift", "smithy_loft")
	pt.expect(not lift.is_empty(), "smithy_rl: the lift stands in the leather room")
	if not lift.is_empty():
		await pt.use("lift", "smithy_loft")
		await pt.wait(0.7)
		pt.expect(_w().area == "smithy_loft", "smithy_rl: one step on the lift — the Loft (%s)" % _w().area)
		_w().camera.zoom = Vector2(0.85, 0.85)
		await pt.wait(0.5)
		await pt.shot("srl_lift_loft")
		_w().camera.zoom = Vector2.ONE
		await pt.use("lift", "smithy")
		await pt.wait(0.7)
		pt.expect(_w().area == "smithy" and _w().room == "leather_room", "smithy_rl: and back down to the leather room (%s/%s)" % [_w().area, _w().room])
	# ---- the layout editor: the floor switcher
	Events.open_panel.emit("property", {})
	await pt.wait(0.6)
	var pp := pt.panel() as PropertyPanel
	pt.expect(pp != null, "smithy_rl: Property & Workshop opens")
	if pp:
		await pt.shot("srl_editor_property_lift")
		await pt.click("Workshop layout")
		await pt.wait(0.4)
		await pt.shot("srl_editor_ground")
		pp.set_floor("loft")
		await pt.wait(0.4)
		pt.expect(pp.floor_id == "loft", "smithy_rl: the editor switches to the Loft")
		await pt.shot("srl_editor_loft")
		await pt.close_panel()
	# ---- an apprentice at the anvil upstairs
	var plan := Property.plan_copy()
	pt.expect(Property.place(plan, "anvil", Vector2(116.6, 30.0)) == "", "smithy_rl: the anvil moves up to the weaving loft")
	pt.expect(Property.commit(plan) == "", "smithy_rl: applied")
	pt.note(ApprenticeDev.unlock())
	Apprentices.refresh_applicants()
	while Apprentices.applicants().is_empty():
		ApprenticeDev.add_applicant()
	pt.expect(Apprentices.hire(0) == "", "smithy_rl: an apprentice is taken on")
	var a: Dictionary = Apprentices.staff()[-1]
	a["traits"] = []
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	await pt.advance_to(7, 55)
	for d in [["ingot_iron", 2], ["leather_cured", 1]]:
		Game.add_item(Items.make(str(d[0]), {"qty": int(d[1])}), false)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "assignee": str(a["id"])})
	pt.note("   task: %s" % str(t.get("error", "queued")))
	await _rebuild()
	var g := 0
	while Apprentices.station_user("anvil") != str(a["id"]) and g < 80:
		Game.advance_minutes(5)
		g += 1
	var acts := _w().get_node("ApprenticeActors") as ApprenticeActors
	acts._last_now = -1
	acts.sync()
	await pt.wait(1.0)
	var n: NPCActor = acts.actors.get(str(a["id"]))
	pt.expect(n != null and n.visible and (_w().buildings["smithy_loft"]["rect"] as Rect2).has_point(n.position),
		"smithy_rl: the apprentice works at the anvil upstairs")
	await _view("srl_apprentice_upstairs", Vector2(115.0, 29.0), 0.85)
	# ---- less walking: the next station and craft again
	Apprentices.dismiss(str(a["id"]))
	for d2 in [["ingot_iron", 4], ["leather_cured", 2]]:
		Game.add_item(Items.make(str(d2[0]), {"qty": int(d2[1])}), false)
	await pt.tp(_w().bpos("smithy", 4.0, 4.0))
	Crafting.start("iron_longsword")
	Crafting.record_step("forge", [96.0])
	await pt.use("station", "forge")
	await pt.wait(0.5)
	pt.expect(pt.find_button(pt.get_tree().root, "Walk to the Anvil") != null, "smithy_rl: the station offers a walk to the next one")
	await pt.shot("srl_walk_to_next")
	await pt.click("Walk to the Anvil")
	await pt.wait(0.3)
	await pt._await_walk(20.0)
	await pt.wait(0.6)
	pt.expect(pt.panel() is StationPanel and _w().area == "smithy_loft", "smithy_rl: walked up to the anvil in the Loft and it opened")
	await pt.shot("srl_walked_upstairs_anvil")
	await pt.close_panel()
	Crafting.cancel()
	var it := Items.make("sword_iron", {"quality": 90.0})
	it["craft"] = {"recipe": "iron_longsword", "recipe_name": "Iron Longsword", "ops": [], "dice": {}}
	Events.open_panel.emit("craft_result", {"item": it, "fresh": true})
	await pt.wait(0.8)
	pt.expect(pt.find_button(pt.get_tree().root, "Craft again") != null, "smithy_rl: the finished piece offers Craft again")
	await pt.shot("srl_craft_again")
	await pt.close_panel()
