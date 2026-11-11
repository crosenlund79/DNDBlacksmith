## Rendered play-test phase "lw_reliability" (The Living Workshop — RELIABILITY worker, wave 1). What the player sees:
##  1. #57 the smith's own shield: forged, equipped from the stores, shown in the worn slots, taken off again;
##  2. #39 adventurers in the village at an hour when the schedules send several to one spot;
##  3. #59–60 the skill tree straight after buying a station and moving it in the workshop plan;
##  4. #53 Weave Linen Cloth at the loom (multi-hit) at Enchanted Stitching 1, played by a bot pressing late;
##  5. #58 binding a frost rune into a sword at the engraving stand at Runecraft 2, the cursor held on the socket;
##  6. #61 a commission card for a frost weapon (what the forge can honestly promise) and #48 the price in the stores.
## Runs on the unchanged base too (new functions are only called when present), so the same script takes the "before"
## shots. Shot names: lwrel_<tag>_* (tag from LWREL_TAG, default "after"). Called from tests/playtest.gd.
extends RefCounted

var pt: Node
var tag := "after"


func _shot(n: String) -> void:
	await pt.wait(0.4)
	await pt.shot("lwrel_%s_%s" % [tag, n])


func _has(path: String, method: String) -> bool:
	var sc: Script = load(path)
	for m in sc.get_script_method_list():
		if m["name"] == method:
			return true
	return false


## Crafts a recipe the way the suite fixture does (fixed check scores); returns the item.
func _craft(rid: String, q := 92.0) -> Dictionary:
	if not Crafting.start(rid):
		pt.note("lwrel: cannot start %s: %s" % [rid, Crafting.recipe_locked_reason(rid)])
		return {}
	var guard := 0
	while Crafting.current_station() != "" and guard < 30:
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(q)
		Crafting.record_step(Crafting.current_station(), qs)
		guard += 1
	return Crafting.finish({"edge": 12, "temper": 12, "fortune": 50, "guard": 12}, "digital")


func _give(def: String, n := 1) -> void:
	if bool(DB.item(def).get("stack", false)):
		Game.add_item(Items.make(def, {"qty": n}), false)
	else:
		for i in n:
			Game.add_item(Items.make(def, {"quality": 80.0}), false)


func run(p: Node) -> void:
	pt = p
	tag = OS.get_environment("LWREL_TAG") if OS.get_environment("LWREL_TAG") != "" else "after"
	if OS.get_environment("LWREL_FUZZ") != "":
		await _fuzz(int(OS.get_environment("LWREL_FUZZ")), int(OS.get_environment("LWREL_ROUNDS")) if OS.get_environment("LWREL_ROUNDS") != "" else 12)
		return
	await pt.click("New Game")
	await pt.wait(2.5)
	Settings.set_value("gameplay/check_assist", false)
	Game.state["gold"] = 6000
	await _shield()
	await _village()
	await _tree_after_move()
	await _weave()
	await _rune_binding()
	await _commission_and_price()


# ------------------------------------------------------------------ 1. #57 the shield
func _shield() -> void:
	_give("ingot_iron", 1)
	_give("leather_cured", 1)
	var sh := _craft("round_shield")
	pt.expect(not sh.is_empty(), "lwrel 57: the smith forges a round shield")
	if sh.is_empty():
		return
	var uid := int(sh["uid"])
	Events.open_panel.emit("inventory", {})
	await pt.wait(0.6)
	var inv := pt.panel() as InventoryPanel
	if inv == null:
		pt.expect(false, "lwrel 57: the stores open")
		return
	inv._select(Game.find_uid(uid))
	await _shot("57_stores_shield_selected")
	pt.expect(await pt.click("Equip on Brannoc", inv), "lwrel 57: Equip on Brannoc")
	await pt.wait(0.4)
	var worn: Dictionary = Game.state["player"]["equipment"].get("shield", {})
	pt.expect(int(worn.get("uid", -1)) == uid, "lwrel 57: the smith wears the shield (uid %d)" % uid)
	pt.expect(Game.find_uid(uid).is_empty(), "lwrel 57: it left the stores grid")
	var shown := inv.find_child("Worn_shield", true, false) as ItemSlot
	pt.expect(shown != null and int(shown.item.get("uid", -1)) == uid, "lwrel 57: the worn-shield slot shows it")
	await _shot("57_shield_worn")
	if await pt.click("Take it off", inv):
		await pt.wait(0.3)
		pt.expect(not Game.find_uid(uid).is_empty(), "lwrel 57: taken off, back in the stores")
		await _shot("57_shield_taken_off")
	await pt.close_panel()
	pt.expect((ItemRegistry.scan()["dup"] as Array).is_empty(), "lwrel 57: one object per uid (ItemRegistry.scan)")


# ------------------------------------------------------------------ 2. #39 the village
func _village() -> void:
	var w: VillageWorld = pt.W()
	var best_h := 10
	var best_n := 0
	for h in [9, 10, 11, 14, 15, 16]:
		Game.state["minute"] = h * 60
		var at := {}
		for id in w.npcs:
			var sp := w.spot_for(str(id))
			if sp != "" and (sp.begins_with("square_") or sp in ["notice", "well", "inn_garden", "harbour_quay"] or sp.begins_with("pond_")):
				at[sp] = int(at.get(sp, 0)) + 1
		for sp in at:
			if int(at[sp]) > best_n:
				best_n = int(at[sp])
				best_h = h
	Game.state["minute"] = best_h * 60
	w._update_schedules(true)
	await pt.wait(0.3)
	# the busiest outdoor spot at that hour
	var counts := {}
	for id in w.npcs:
		var n: NPCActor = w.npcs[id]
		if n.visible:
			counts[str(n.target_spot)] = int(counts.get(str(n.target_spot), 0)) + 1
	var spot := ""
	var most := 0
	for sp in counts:
		if (str(sp).begins_with("square_") or sp in ["notice", "well", "inn_garden", "harbour_quay"] or str(sp).begins_with("pond_")) and int(counts[sp]) > most:
			most = int(counts[sp])
			spot = str(sp)
	pt.note("lwrel 39: %02d:00 — %d people sent to %s" % [best_h, most, spot])
	if spot != "":
		await pt.tp(w.spots[spot] + Vector2(0, 180))
		w.camera.zoom = Vector2(1.6, 1.6)
		await pt.wait(0.5)
		var close := 0
		var vis := []
		for id in w.npcs:
			var n2: NPCActor = w.npcs[id]
			if n2.visible and n2.target_spot == spot:
				vis.append(n2)
		for i in vis.size():
			for j in range(i + 1, vis.size()):
				if (vis[i] as NPCActor).position.distance_to((vis[j] as NPCActor).position) < 20.0:
					close += 1
		pt.note("lwrel 39: %d pairs stand on one point at %s" % [close, spot])
		if tag == "after":
			pt.expect(close == 0, "lwrel 39: nobody stands on someone else at %s" % spot)
		await _shot("39_village_%s" % spot)
		w.camera.zoom = Vector2(1, 1)


# ------------------------------------------------------------------ 3. #59–60 the tree after moving a bought station
func _tree_after_move() -> void:
	for sk in ["mining", "runecraft", "alchemy", "enchanted_stitching"]:
		for i in 2:
			Game.grant_player_xp(sk, SkillSys.xp_needed(Game.player_level(sk) + 1))
	for id in ["m_common", "m_alloys", "r_identify", "r_clean", "al_simple"]:
		SkillTree.unlock(id)
	Events.open_panel.emit("property", {})
	await pt.wait(0.5)
	var pp := pt.panel() as PropertyPanel
	if pp == null:
		pt.expect(false, "lwrel 59: the property plan opens")
		return
	await pt.click("Equipment", pp)
	for sid in ["bellows", "mortar_station"]:
		if Property.buy_station(sid) == "" and not (pp.plan["stored"] as Array).has(sid):
			(pp.plan["stored"] as Array).append(sid)
	pp._build()
	await pt.click("Workshop layout", pp)
	pp._auto_place_all()
	# move the newly placed bellows half a tile
	if (pp.plan["stations"] as Dictionary).has("bellows"):
		var e: Dictionary = pp.plan["stations"]["bellows"]
		var at := Vector2(float(e["pos"][0]), float(e["pos"][1]))
		pp.plan_click(at, MOUSE_BUTTON_LEFT)
		pp.plan_click(at + Vector2(0.5, 0), MOUSE_BUTTON_LEFT)
		if pp.carrying != "":
			pp.plan_click(at, MOUSE_BUTTON_LEFT)
	pp._build()
	await _shot("59_plan_moved")
	pp._apply()
	await pt.wait(0.3)
	await pt.close_panel()
	await pt.wait(2.5)   # the world is rebuilt with the new layout
	pt.expect(Property.is_installed("bellows"), "lwrel 59: the bought bellows stand in the workshop")
	await pt.press("panel_skills")
	await pt.wait(0.8)
	var tp := pt.panel() as SkillTreePanel
	pt.expect(tp != null, "lwrel 59: the skill tree opens after the move")
	if tp == null:
		return
	# hover, click, drag and zoom like a player, then learn a node
	for id in ["m_rare", "r_blank", "al_oils", "r_master", "s_starsteel"]:
		var n := SkillTree.node(id)
		if n.is_empty():
			continue
		var mm := InputEventMouseMotion.new()
		mm.position = tp.canvas.scr(tp.canvas.world(n))
		tp.canvas._gui_input(mm)
		await pt.wait(0.15)
	tp.canvas.zoom_at(Vector2(600, 400), 1.12)
	tp.canvas.select("al_oils")
	await pt.wait(0.3)
	if SkillTree.node_state("al_oils") == "available":
		await pt.click("✦ Learn", tp)
	await pt.wait(0.5)
	await _shot("59_tree_after_move")
	await pt.close_panel()


# ------------------------------------------------------------------ 4. #53 the loom
func _weave() -> void:
	Game.player_skills()["enchanted_stitching"]["lvl"] = 1
	Vitality.set_fatigue(0.0)
	var c := Crafting.check_params("loom", "weave_linen")
	pt.note("lwrel 53: weave linen at Enchanted Stitching 1 — zone %.1f, speed %.3f" % [float(c["zone"]), float(c["speed"])])
	var res := []
	Events.open_panel.emit("skillcheck", {"station": "loom", "count": 1, "speed": c["speed"], "zone": c["zone"], "no_tutorial": true,
		"title": "Weave plain linen", "subtitle": "Strike each section as the shuttle passes", "on_done": func(qs: Array): res.append_array(qs)})
	await pt.wait(0.3)
	var g: MultiHitGame = null
	for ch in pt.U().panel_host.get_children():
		if ch is MultiHitGame:
			g = ch
	if g == null:
		pt.expect(false, "lwrel 53: the loom's multi-hit check opens")
		return
	# a player who presses as each section's centre passes — the key reaches the game a frame later (at this
	# renderer's low frame rate that is up to 0.05 s of needle travel: a slightly late human press)
	var done := {}
	var guard := 0.0
	var shot_taken := false
	while not g.finished and guard < 3000.0:
		if g.running:
			for i in g.targets.size():
				if not done.has(i) and g.angle >= float(g.targets[i][0]):
					done[i] = true
					var ev := InputEventAction.new()
					ev.action = "interact"
					ev.pressed = true
					Input.parse_input_event(ev)
					var up := InputEventAction.new()
					up.action = "interact"
					up.pressed = false
					Input.parse_input_event(up)
			if not shot_taken and done.size() >= 3:
				shot_taken = true
				await pt.shot("lwrel_%s_53_weave_midsweep" % tag)
		await pt.get_tree().process_frame
		guard += 1.0   # frames: the minigames advance at most 0.05 s of play per frame
	await pt.wait(0.2)
	pt.note("lwrel 53: %d of %d sections struck (presses one frame late)" % [g.hits(), g.targets.size()] if is_instance_valid(g) else "lwrel 53: check closed")
	if is_instance_valid(g) and tag == "after":
		pt.expect(g.hits() == g.targets.size(), "lwrel 53: a slightly late player still strikes every section")
	await _shot("53_weave_result")
	var w5 := 0
	while is_instance_valid(g) and w5 < 600:   # the result banner closes by itself
		await pt.get_tree().process_frame
		w5 += 1
	await pt.wait(0.3)


# ------------------------------------------------------------------ 5. #58 the rune binding
func _rune_binding() -> void:
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	pt.main.call("rebuild_world")
	await pt.wait(2.5)
	Game.player_skills()["runecraft"]["lvl"] = 2
	Vitality.set_fatigue(0.0)
	_give("runestone_frost", 1)
	var sw := Items.make("sword_iron", {"quality": 85.0})
	Game.add_item(sw, false)
	Events.open_panel.emit("station", {"id": "rune_engraving_stand"})
	await pt.wait(0.8)
	var sp := pt.panel() as StationPanel
	if sp == null:
		pt.expect(false, "lwrel 58: the engraving stand opens")
		return
	if not await pt.click("Engrave and set", sp):
		return
	await pt.wait(0.4)
	var g: RuneGame = null
	for ch in pt.U().panel_host.get_children():
		if ch is RuneGame:
			g = ch
	if g == null:
		pt.expect(false, "lwrel 58: the rune binding opens")
		return
	if g.overlay and g.overlay.card != null and is_instance_valid(g.overlay.card) and g.overlay.card.visible:
		g.overlay._close_card()   # the first-time how-to card
		await pt.wait(0.3)
	pt.note("lwrel 58: binding at Runecraft 2 — zone %.1f, speed %.2f, tolerance %.1f px" % [float(g.args["zone"]), float(g.args["speed"]), g.tol()])
	# a steady player: the cursor held on the socket
	var guard := 0.0
	var shot_taken := false
	while not g.finished and guard < 3000.0:
		var mm := InputEventMouseMotion.new()
		mm.position = g._socket_pos()
		mm.global_position = g._socket_pos()
		g._gui_input(mm)
		if g.seated and g.bind_t > 2.0 and not shot_taken:
			shot_taken = true
			await pt.shot("lwrel_%s_58_binding_held" % tag)
		await pt.get_tree().process_frame
		guard += 1.0   # frames: the minigames advance at most 0.05 s of play per frame
	var q := float(g.results[0]) if is_instance_valid(g) and not g.results.is_empty() else -1.0
	pt.note("lwrel 58: steady hold bound the rune at %.0f %%" % q)
	if tag == "after":
		pt.expect(q >= 75.0, "lwrel 58: a steady hold at Runecraft 2 binds the rune well (%.0f %%)" % q)
	await _shot("58_binding_result")
	var w8 := 0
	while is_instance_valid(g) and w8 < 600:   # the result banner closes by itself, then the rune is set
		await pt.get_tree().process_frame
		w8 += 1
	await pt.wait(0.5)
	pt.expect(Game.inventory().any(func(x): return (x.get("sockets", []) as Array).has("runestone_frost")), "lwrel 58: the frost rune is set into the piece")
	await pt.close_panel()


# ------------------------------------------------------------------ 6. #61 a commission card, #48 the price
func _commission_and_price() -> void:
	SkillTree.reset_new()
	var f: Dictionary = {}
	for a in Adv.all().values():
		if str(a["cls"]) == "Fighter":
			f = a
			break
	if f.is_empty():
		return
	Shop.orders().clear()
	f["wants_prop"] = "frost"
	f["level"] = 4
	var o := Shop.create_order(str(f["id"]), "weapon", "For the Frostfell — they say the things there fear frost.")
	pt.expect(not o.is_empty(), "lwrel 61: a commission for a frost weapon")
	Events.open_panel.emit("orders", {})
	await pt.wait(0.6)
	await _shot("61_commission_frost_weapon")
	await pt.close_panel()
	var sw := Items.make("sword_iron", {"quality": 85.0})
	Game.add_item(sw, false)
	Events.open_panel.emit("inventory", {})
	await pt.wait(0.6)
	var inv := pt.panel() as InventoryPanel
	if inv:
		inv._select(sw)
		await pt.wait(0.3)
		inv.detail_scroll.scroll_vertical = 100000   # the price sits under the piece's description
		await _shot("48_stores_price")
	await pt.close_panel()


# ======================================================================= #59–60: the seeded skill-tree fuzz
## LWREL_FUZZ=<seed> [LWREL_ROUNDS=n] [LWREL_TRACE=1]: no screenshots, runs headless too. Rounds of real panel actions on
## the skill tree (hover, click, drag, wheel, tooltips, Learn, Fit/Top, level-ups) between rounds of buying rooms and
## stations, placing and moving them, applying the layout (the world is rebuilt) and opening the tree again — half the
## time in the very frame the plan closes. On the unchanged base, seed 1234 crashed in round 11 every time (a flood of
## deferred layout calls, "Message queue out of memory", SIGSEGV). Trace lines go straight to disk
## (user://lwrel_fuzz_trace.txt) because stdout is lost in a crash.
var rng := RandomNumberGenerator.new()
var _tf: FileAccess


func _t(line: String) -> void:
	if OS.get_environment("LWREL_TRACE") == "":
		return
	if _tf == null:
		_tf = FileAccess.open("user://lwrel_fuzz_trace.txt", FileAccess.WRITE)
	_tf.store_line(line)
	_tf.flush()


func _canvas_motion(tp: SkillTreePanel, pos: Vector2, pressed := false) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.relative = Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
	if pressed:
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	tp.canvas._gui_input(mm)


func _canvas_button(tp: SkillTreePanel, pos: Vector2, idx: int, down: bool) -> void:
	var a := InputEventMouseButton.new()
	a.button_index = idx
	a.pressed = down
	a.position = pos
	tp.canvas._gui_input(a)


func _tree_actions(n: int) -> void:
	for i in n:
		var tp := pt.panel() as SkillTreePanel
		if tp == null or not is_instance_valid(tp):
			return
		var nodes := SkillTree.nodes()
		var nd: Dictionary = nodes[rng.randi() % nodes.size()]
		var p: Vector2 = tp.canvas.scr(tp.canvas.world(nd))
		var act := rng.randi() % 9
		_t("act %d %s frame %d" % [act, nd["id"], Engine.get_process_frames()])
		match act:
			0, 1:
				_canvas_motion(tp, p)
			2:
				_canvas_button(tp, p, MOUSE_BUTTON_LEFT, true)
				_canvas_button(tp, p, MOUSE_BUTTON_LEFT, false)
			3:
				_canvas_button(tp, p, MOUSE_BUTTON_LEFT, true)
				for k in 4:
					_canvas_motion(tp, p + Vector2(k * 20, k * 10), true)
				_canvas_button(tp, p, MOUSE_BUTTON_LEFT, false)
			4:
				_canvas_button(tp, p, MOUSE_BUTTON_WHEEL_UP if rng.randf() < 0.5 else MOUSE_BUTTON_WHEEL_DOWN, true)
			5:
				for c in tp.side.get_children():
					if c is MarginContainer:
						c.mouse_entered.emit()
						c.mouse_exited.emit()
			6:
				tp.canvas.select(str(nd["id"]))
				await pt.get_tree().process_frame
				var b: Button = pt.find_button(tp, "✦ Learn")
				if b:
					b.pressed.emit()
			7:
				var bb: Button = pt.find_button(tp, ["Fit the whole tree", "Top", "✦ "][rng.randi() % 3])
				if bb:
					bb.pressed.emit()
			8:
				for sk in ["smithing", "runecraft", "alchemy", "enchanted_stitching", "mining", "arcane_metalwork"]:
					if rng.randf() < 0.3:
						Game.grant_player_xp(sk, SkillSys.xp_needed(Game.player_level(sk) + 1))
		await pt.get_tree().process_frame


func _fuzz_property_round(round_i: int) -> void:
	Events.open_panel.emit("property", {"floor": "loft"} if round_i % 3 == 2 and Property.floor_owned("loft") else {})
	await pt.wait(0.3)
	var pp := pt.panel() as PropertyPanel
	if pp == null:
		pt.note("lwrel fuzz: the property plan did not open")
		return
	for u in Property.units():
		if Property.unit_state(str(u["id"])) == "available" and rng.randf() < 0.5:
			Property.buy_unit(str(u["id"]))
	pp.plan = Property.plan_copy()
	await pt.click("Equipment")
	for st in DB.stations.values():
		var sid := str(st["id"])
		if not Property.is_owned_station(sid) and SkillTree.station_reason(sid) == "" and rng.randf() < 0.6:
			if Property.buy_station(sid) == "" and not (pp.plan["stored"] as Array).has(sid):
				(pp.plan["stored"] as Array).append(sid)
	pp._build()
	await pt.click("Workshop layout")
	pp._auto_place_all()
	var keys: Array = (pp.plan["stations"] as Dictionary).keys()
	for k in mini(6, keys.size()):
		var sid2: String = keys[rng.randi() % keys.size()]
		if not (pp.plan["stations"] as Dictionary).has(sid2):
			continue
		var e: Dictionary = pp.plan["stations"][sid2]
		var at := Vector2(float(e["pos"][0]), float(e["pos"][1]))
		if Property.floor_of_point(at) != pp.floor_id:
			continue
		pp.plan_click(at, MOUSE_BUTTON_LEFT)
		if pp.carrying != "":
			pp.plan_click(at + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), MOUSE_BUTTON_LEFT)
			if pp.carrying != "":
				pp.plan_click(at, MOUSE_BUTTON_LEFT)
			if pp.carrying != "":
				pp.carrying = ""
	pp._apply()
	await pt.wait(0.1)
	if rng.randf() < 0.5:
		pp.close()   # the world rebuild is deferred: the tree opens in the very frame the plan closes
		Events.open_panel.emit("skilltree", {})
		await pt.get_tree().process_frame
	else:
		await pt.close_panel()
		await pt.press("panel_skills")
	await pt.wait(0.4)
	if not (pt.panel() is SkillTreePanel):
		Events.open_panel.emit("skilltree", {})
		await pt.wait(0.4)
	await _tree_actions(40)
	if rng.randf() < 0.4:
		var b: Button = pt.find_button(pt.panel() if pt.panel() else pt.get_tree().root, "Skill levels")
		if b:
			b.pressed.emit()
			await pt.wait(0.3)
	await pt.close_panel()
	await pt.wait(0.2)


func _fuzz(fuzz_seed: int, rounds: int) -> void:
	rng.seed = fuzz_seed
	await pt.click("New Game")
	await pt.wait(2.0)
	Game.state["gold"] = 30000
	for sk in ["smithing", "mining", "runecraft", "alchemy", "enchanted_stitching"]:
		for i in 3:
			Game.grant_player_xp(sk, SkillSys.xp_needed(Game.player_level(sk) + 1))
	for d in ["runestone_blank", "flax_bundle", "ore_mithril"]:
		Game.add_item(Items.make(d, {"qty": 3}), false)
	for r in rounds:
		Events.open_panel.emit("skilltree", {})
		await pt.wait(0.3)
		await _tree_actions(30)
		await pt.close_panel()
		await _fuzz_property_round(r)
		pt.note("lwrel fuzz %d: round %d done (%d nodes learned, %d stations set up)" % [fuzz_seed, r, SkillTree.learned().size(), (Property.st()["stations"] as Dictionary).size()])
	pt.expect(true, "lwrel fuzz %d: %d rounds of buying, moving and browsing the tree without a crash" % [fuzz_seed, rounds])
