## The Living Workshop — RELIABILITY worker (wave 1): playtest defects #57, #59–61, #53, #58, #39, #45, #56 and the
## verifications #41, #48, #49. Each test reproduces the reported behaviour with the real systems and then checks the fix
## (or records the numbers for the later balance pass).
extends SuiteCase

const SMOKE := ["test_shield_stays_with_the_smith"]


# ------------------------------------------------------------------ fixtures
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Control) -> Control:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


## The first node called `n` under `root` that is not being freed (UIKit.clear queues the old children for deletion).
func _live(root: Node, n: String, cls := "") -> Node:
	for c in root.find_children(n, cls, true, false):
		var x: Node = c
		var dead := false
		while x != null and x != root:
			if x.is_queued_for_deletion():
				dead = true
				break
			x = x.get_parent()
		if not dead:
			return c
	return null


func _live_button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			var x: Node = b
			var dead := false
			while x != null and x != root:
				dead = dead or x.is_queued_for_deletion()
				x = x.get_parent()
			if not dead:
				return b
	return null


func _scan_clean(what: String) -> void:
	var r := ItemRegistry.scan()
	check((r["dup"] as Array).is_empty() and (r["shared"] as Array).is_empty() and (r["stray"] as Array).is_empty(),
		"%s: ItemRegistry.scan is clean (%s)" % [what, ItemRegistry.scan_text(r)])


## A shield the smith forges himself (real recipe, real materials).
func _forge_shield() -> Dictionary:
	give("ingot_iron", 1)
	give("leather_cured", 1)
	return craft("round_shield")


# ------------------------------------------------------------------ #53 / #58 check difficulty
## Plays the rune stabilisation like a steady player: the cursor held on the socket from the start (the rune follows it,
## late). Returns the binding's craftsmanship (the average over the binding time), without the result banner.
func _rune_round(args: Dictionary, rng_seed: int) -> float:
	seed(rng_seed)
	var g := RuneGame.new(args, Minigames.config_for("rune_engraving_stand"))
	g.set_anchors_preset(Control.PRESET_TOP_LEFT)
	g.size = Vector2(1920, 1080)
	g.started = true
	g._start_round()
	g.mouse_active = true
	g.mouse_target = Vector2.ZERO
	var dt := 1.0 / 60.0
	var guard := 0
	while guard < 3000 and not (g.seated and g.bind_t + dt >= RuneGame.BIND):
		g._tick(dt)
		guard += 1
	var q := g.q_sum / maxf(g.bind_t, 0.001)
	g.free()
	return q


func _avg_rune(args: Dictionary) -> float:
	var tot := 0.0
	for s in 12:
		tot += _rune_round(args, 1000 + s)
	return tot / 12.0


## Ring check: the needle crosses the zone (zone°) at speed × 360°/s — the time a ≥70 % press has.
func _ring_window(p: Dictionary) -> float:
	return float(p["zone"]) / (float(p["speed"]) * 360.0)


# ------------------------------------------------------------------ #57 the smith's own shield
func test_shield_stays_with_the_smith() -> void:
	fresh_game()
	var sh := _forge_shield()
	if not check(not sh.is_empty(), "the smith forges a round shield (%s)" % craft_blocker("round_shield")):
		return
	var uid := int(sh["uid"])
	var maker := str(sh.get("crafted_by", ""))
	var owners: Array = (sh.get("prov", {}).get("owners", []) as Array).duplicate(true)
	# the stores window before: the shield is in the grid
	var p := _mount(InventoryPanel.new()) as InventoryPanel
	p._select(sh)
	var take := func(n: String) -> Node: return _live(p, n)
	check(take.call("Worn_shield") != null, "the stores window has a worn-shield slot")
	# equip through the same button the player uses
	var eb := _live_button(p, "Equip on Brannoc")
	if check(eb != null, "the stores window offers 'Equip on Brannoc' for the shield"):
		eb.pressed.emit()
	eq(Game.player_worn_slot(uid), "shield", "the smith wears it in the shield slot")
	check(Game.find_uid(uid).is_empty(), "it left the stores grid (it is worn, not duplicated)")
	check(is_same(Game.state["player"]["equipment"]["shield"], sh), "the very same piece is worn (one object per uid)")
	eq(str(ItemRegistry.where(uid).get("holder", "")), "smith", "the registry knows where it is")
	var slot_node := take.call("Worn_shield") as ItemSlot
	check(slot_node != null and int(slot_node.item.get("uid", -1)) == uid, "the worn-shield slot shows it (it no longer vanishes)")
	check(take.call("TakeOff") != null, "the worn piece is selected and can be taken off")
	_scan_clean("worn")
	# identity: uid, maker and owners untouched by wearing it
	eq(str(sh.get("crafted_by", "")), maker, "maker unchanged")
	eq((sh.get("prov", {}).get("owners", []) as Array), owners, "owner chain unchanged")
	# every slot a piece can be worn in is shown (cloak, belt, amulet were missing too)
	for s in ["weapon", "shield", "armor", "helmet", "gloves", "boots", "cloak", "belt", "ring", "amulet"]:
		check(take.call("Worn_" + s) != null, "the stores window shows the %s slot" % s)
	# save/load keeps it worn, same uid, once
	check(save_load("lwrel_shield"), "save/load")
	var worn: Dictionary = Game.state["player"]["equipment"].get("shield", {})
	eq(int(worn.get("uid", -1)), uid, "after loading he still wears the same shield")
	eq(str(worn.get("crafted_by", "")), maker, "maker survives save/load")
	_scan_clean("after load")
	_unmount(p)
	# a second shield replaces it; the first goes back to the stores (nothing lost)
	var sh2 := _forge_shield()
	if check(not sh2.is_empty(), "a second shield"):
		eq(Game.equip_player(int(sh2["uid"])), "shield", "the second shield is put on")
		check(not Game.find_uid(uid).is_empty(), "the first shield is back in the stores, not lost")
		_scan_clean("swapped")
	# taking it off through the window's button
	p = _mount(InventoryPanel.new()) as InventoryPanel
	p._select(Game.state["player"]["equipment"]["shield"])
	var off := _live(p, "TakeOff") as Button
	if check(off != null, "the take-off button is offered for the worn shield"):
		off.pressed.emit()
	check(Game.player_worn_slot(int(sh2["uid"])) == "" and not Game.find_uid(int(sh2["uid"])).is_empty(), "taken off: back in the stores")
	check(not Game.unequip_player("shield"), "nothing left to take off")
	_scan_clean("taken off")
	_unmount(p)


# ------------------------------------------------------------------ #53 Weave Linen Cloth (multi-hit sections)
## Plays one round of the real MultiHitGame (mounted, no how-to card): presses `offset_s` seconds after each section's
## centre passes under the needle. Returns [hits, sections, quality].
func _multihit_round(args: Dictionary, offset_s: float, rng_seed: int) -> Array:
	seed(rng_seed)
	var a := args.duplicate()
	a["no_tutorial"] = true
	var g := MultiHitGame.new(a, Minigames.config_for(str(a["station"])))
	_mount(g)
	var dt := 1.0 / 240.0
	var pressed := {}
	var guard := 0
	var q := -1.0
	while guard < 4000 and not g.finished:
		g._tick(dt)
		if g.running:
			for i in g.targets.size():
				if not pressed.has(i) and g.angle >= float(g.targets[i][0]) + offset_s * g.sweep:
					pressed[i] = true
					var ev := InputEventAction.new()
					ev.action = "interact"
					ev.pressed = true
					g._input(ev)
		guard += 1
	if not g.results.is_empty():
		q = float(g.results[0])
	var out := [g.hits(), g.targets.size(), q]
	_unmount(g)
	Game.block_time(false)
	return out


## The old section layout (before LW #53), kept here only to report the difference: section half-width 0.4 × zone (≥ 9°,
## ≤ 0.38 of its share) swept at speed × 1.45 × 360°/s.
func _old_multihit_window(zone: float, speed: float, n: int) -> float:
	var half := minf(maxf(9.0, zone * 0.4), 300.0 / n * 0.38)
	return 2.0 * half / (speed * 1.45 * 360.0)


func test_weave_sections_as_fair_as_the_ring() -> void:
	fresh_game()
	Vitality.set_fatigue(0.0)
	Settings.set_value("gameplay/check_assist", false)
	var cases := [["loom", "weave_linen", 1], ["loom", "weave_linen", 3], ["loom", "weave_wool", 2], ["thread_spinner", "yew_longbow", 3],
		["embroidery_frame", "scholar_robe", 3], ["infusion_rack", "healing_draught", 2], ["resonance_pedestal", "ward_runestone", 2],
		["spellbinding_array", "mithril_runeblade", 5]]
	for c in cases:
		var sk := Crafting.skill_for_station(str(c[0]))
		Game.player_skills()[sk]["lvl"] = int(c[2])
		var p := Crafting.check_params(str(c[0]), str(c[1]))
		var n := int(Minigames.config_for(str(c[0])).get("targets", 5))
		var lay := MultiHitGame.layout(float(p["zone"]), float(p["speed"]), n)
		var ring := _ring_window(p)
		note("%s / %s at %s %d: %d sections — window %.0f ms (ring %.0f ms; before %.0f ms), at least %.0f ms between sections, sweep %.1f s" % [c[0], c[1],
			SkillSys.skill_name(sk), int(c[2]), n, float(lay["window"]) * 1000.0, ring * 1000.0, _old_multihit_window(float(p["zone"]), float(p["speed"]), n) * 1000.0,
			float(lay["gap"]) * 1000.0, 340.0 / float(lay["sweep"])])
		check(absf(float(lay["window"]) - ring) < 0.001, "%s: each section gives the ring's time window for the same zone and speed" % c[0])
		check(float(lay["gap"]) >= float(lay["window"]) * 0.5 - 0.001, "%s: neighbouring sections never crowd each other" % c[0])
	# Weave Linen Cloth at Enchanted Stitching 1, played: a press 60 ms after each centre (an ordinary human lag)
	Game.player_skills()["enchanted_stitching"]["lvl"] = 1
	var lp := Crafting.check_params("loom", "weave_linen")
	var args := {"station": "loom", "count": 1, "speed": lp["speed"], "zone": lp["zone"], "title": "test"}
	var late := _multihit_round(args, 0.06, 7)
	note("weave linen at Enchanted Stitching 1, every press 60 ms late: %d of %d struck, %.0f %%" % [late[0], late[1], float(late[2])])
	eq(int(late[0]), int(late[1]), "a press 60 ms late still strikes every section (before: ~45 ms either side)")
	var sloppy := _multihit_round(args, 0.13, 7)
	check(int(sloppy[0]) < int(sloppy[1]), "a press 130 ms late misses (precision still matters: %d of %d)" % [sloppy[0], sloppy[1]])
	check(float(late[2]) > 110.0, "all six struck is exceptional work (%.0f %%)" % float(late[2]))
	# mastery: a better weaver has wider, slower sections
	Game.player_skills()["enchanted_stitching"]["lvl"] = 5
	var hp := Crafting.check_params("loom", "weave_linen")
	check(float(MultiHitGame.layout(float(hp["zone"]), float(hp["speed"]), 6)["window"]) > float(MultiHitGame.layout(float(lp["zone"]), float(lp["speed"]), 6)["window"]) * 1.5,
		"Enchanted Stitching 5 gives clearly wider windows than 1")


# ------------------------------------------------------------------ #58 weapon rune binding
func test_rune_binding_follows_skill() -> void:
	fresh_game()
	Vitality.set_fatigue(0.0)
	Settings.set_value("gameplay/check_assist", false)
	# the station panel's "Set a runestone" opens the check from the smith's skill (it was fixed at zone 28 / speed 0.6)
	var sw := Items.make("sword_iron", {"quality": 80.0})
	Game.add_item(sw, false)
	var seen := []
	var grab := func(id: String, a: Dictionary) -> void:
		if id == "skillcheck":
			seen.append(a)
	Events.open_panel.connect(grab)
	var ob_item := OptionButton.new()
	ob_item.add_item("sword", int(sw["uid"]))
	ob_item.select(0)
	var ob_rune := OptionButton.new()
	ob_rune.add_item("frost")
	ob_rune.set_item_metadata(0, "runestone_frost")
	ob_rune.select(0)
	var sp := StationPanel.new("rune_engraving_stand")
	var zones := []
	for lv in [1, 6]:
		Game.player_skills()["runecraft"]["lvl"] = lv
		seen.clear()
		sp._on_socket_pressed(ob_item, ob_rune)
		if check(seen.size() == 1, "Runecraft %d: the binding check opens" % lv):
			var want := Minigames.socket_check("runestone_frost")
			check(is_equal_approx(float(seen[0]["zone"]), float(want["zone"])) and is_equal_approx(float(seen[0]["speed"]), float(want["speed"])),
				"Runecraft %d: zone/speed come from the smith's skill (%.1f / %.2f)" % [lv, float(seen[0]["zone"]), float(seen[0]["speed"])])
			zones.append(float(seen[0]["zone"]))
	Events.open_panel.disconnect(grab)
	check(zones.size() == 2 and zones[1] > zones[0] + 5.0, "a master gets a wider binding ring than a novice (%s)" % str(zones))
	sp.free()
	ob_item.free()
	ob_rune.free()
	# a steady player (cursor held on the socket) — the binding's craftsmanship by skill (frost runestone: difficulty 4)
	var by_level := {}
	for lv in [1, 2, 4, 6, 8]:
		Game.player_skills()["runecraft"]["lvl"] = lv
		var p := Minigames.socket_check("runestone_frost")
		by_level[lv] = _avg_rune({"zone": p["zone"], "speed": p["speed"], "count": 1})
		note("binding a frost rune at Runecraft %d (zone %.1f, speed %.2f): steady hold %.0f %%" % [lv, float(p["zone"]), float(p["speed"]), float(by_level[lv])])
	note("before LW #58 a steady hold scored about 53 % at every Runecraft level (fixed check), 37–85 % with the skill's params")
	check(float(by_level[4]) >= 85.0, "at the rune's own level a steady hold binds well (%.0f %%)" % float(by_level[4]))
	check(float(by_level[1]) >= 60.0 and float(by_level[1]) < 90.0, "a novice's steady hold is rough but workable (%.0f %%)" % float(by_level[1]))
	check(float(by_level[1]) < float(by_level[4]) and float(by_level[4]) < float(by_level[8]), "mastery still matters: novice < journeyman < master")
	check(float(by_level[8]) >= 95.0, "a master's steady binding reaches excellent work (%.0f %%)" % float(by_level[8]))
	# letting go is still punished: no cursor at all, the rune drifts
	Game.player_skills()["runecraft"]["lvl"] = 4
	var p4 := Minigames.socket_check("runestone_frost")
	seed(3)
	var g := RuneGame.new({"zone": p4["zone"], "speed": p4["speed"], "count": 1}, {})
	g.set_anchors_preset(Control.PRESET_TOP_LEFT)
	g.size = Vector2(1920, 1080)
	g.started = true
	g._start_round()
	var guard := 0
	while guard < 3000 and not (g.seated and g.bind_t + 1.0 / 60.0 >= RuneGame.BIND):
		g._tick(1.0 / 60.0)
		guard += 1
	var idle := g.q_sum / maxf(g.bind_t, 0.001)
	g.free()
	check(idle < 40.0, "a rune left to itself binds badly (%.0f %%)" % idle)
