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


# ------------------------------------------------------------------ #39 people spread around their destinations
func _village() -> VillageWorld:
	var w := VillageWorld.new()
	_host().add_child(w)
	return w


## Groups of visible people standing within `px` of each other (outside the smithy's waiting seats).
func _stacks(w: VillageWorld, px := 20.0) -> Array:
	var vis := []
	for id in w.npcs:
		var n: NPCActor = w.npcs[id]
		if n.visible and not str(n.target_spot).begins_with("wait_seat_"):
			vis.append(n)
	var out := []
	for i in vis.size():
		for j in range(i + 1, vis.size()):
			if (vis[i] as NPCActor).position.distance_to((vis[j] as NPCActor).position) < px:
				out.append("%s+%s@%s" % [vis[i].npc_id, vis[j].npc_id, vis[i].target_spot])
	return out


func test_people_spread_around_their_destinations() -> void:
	fresh_game()
	var w := _village()
	var stacked := 0
	var samples := 0
	var shared_spots := 0
	var worst := 0
	for d in 3:
		for h in [9, 10, 11, 14, 15, 16, 17, 19, 20]:
			Game.state["day"] = 1 + d
			Game.state["minute"] = h * 60
			w._update_schedules(true)
			samples += 1
			var at := {}
			for id in w.npcs:
				var n: NPCActor = w.npcs[id]
				if not n.visible:
					continue
				var sp := w.spot_for(str(id))
				eq(str(n.target_spot), sp, "%s keeps their real schedule (%s)" % [id, sp])
				if w.spots.has(sp):
					check(n.position.distance_to(w.spots[sp]) <= 2.3 * VillageWorld.T, "%s stands at %s (%.0f px from it)" % [id, sp, n.position.distance_to(w.spots[sp])])
				at[sp] = int(at.get(sp, 0)) + 1
			for sp in at:
				if int(at[sp]) > 1 and not str(sp).begins_with("wait_seat_"):
					shared_spots += 1
					worst = maxi(worst, int(at[sp]))
			var st := _stacks(w)
			stacked += st.size()
			if not st.is_empty():
				check(false, "day %d %02d:00 nobody stands on someone else (%s)" % [1 + d, h, ", ".join(PackedStringArray(st.slice(0, 4)))])
	note("%d village moments: %d times several people shared a destination (up to %d at once) — now each stands in their own place; %d overlaps" % [samples, shared_spots, worst, stacked])
	check(shared_spots > 0, "the schedules really do send several people to one spot (the situation #39 describes)")
	# every standing place is on open ground in sight of the spot
	var nav := PlayerNav.of(w)
	if check(nav != null, "the walk grid is there"):
		for sp in w._stand:
			for id in w._stand[sp]:
				var off: Vector2 = w._stand[sp][id]
				if off == Vector2.ZERO:
					continue   # the spot itself (a seat stays a seat)
				check(w._stand_ok(w.spots[sp], w.spots[sp] + off) and nav.walkable(w.spots[sp] + off), "%s's place at %s is open ground in sight of it" % [id, sp])
	w.get_parent().remove_child(w)
	w.free()


# ------------------------------------------------------------------ #45 early gear value against the purse (numbers)
func _gear_value(a: Dictionary) -> int:
	var v := 0
	for s in a.get("equipment", {}):
		v += Items.value(a["equipment"][s])
	return v


## Where a worn piece came from: the smith, another forge, found on an expedition, or what they started with.
func _origin(it: Dictionary) -> String:
	if str(it.get("crafted_by", "")).begins_with("Brannoc"):
		return "your forge"
	for h in it.get("history", []):
		if str(h).contains("Found in"):
			return "found"
	if it.has("found"):
		return "found"
	return "start or bought"


func test_early_gear_value_numbers() -> void:
	for world_seed in [9001, 4242]:
		fresh_game("journeyman", world_seed)
		for day_mark in [17, 30]:
			days(day_mark - Game.day())
			var rows := []
			var rich := 0
			var rich_found := 0
			for a in Adv.all().values():
				if str(a.get("status", "")) in ["dead", "gone"]:
					continue
				var best := {}
				for s in a.get("equipment", {}):
					var it: Dictionary = a["equipment"][s]
					if best.is_empty() or Items.value(it) > Items.value(best):
						best = it
				var gv := _gear_value(a)
				if not best.is_empty() and Items.value(best) >= 1000:
					rich += 1
					if _origin(best) == "found":
						rich_found += 1
				rows.append("%s (%s %d) %d g, gear %d g, best %s %d g [%s]" % [a["name"], a["cls"], int(a["level"]), int(a["gold"]), gv,
					Items.display_name(best) if not best.is_empty() else "-", Items.value(best) if not best.is_empty() else 0, _origin(best) if not best.is_empty() else "-"])
			note("world %d, day %d: %d adventurers wear a piece worth 1,000 g or more (%d of them found on expeditions)" % [world_seed, Game.day(), rich, rich_found])
			for r in rows:
				note("   " + r)
	# what the uniform equipment pick can hand out (Loot.random_equipment("any")), and boots at the counter for comparison
	var defs := Loot._equip_defs("any")
	var top := defs.filter(func(d): return Items.tier({"def": str(d)}) >= 3 or int(DB.item(str(d)).get("value", 0)) >= 300)
	note("Loot.random_equipment(\"any\") draws evenly from %d equipment kinds; %d of them are mithril/adamantine/dragon-grade or worth 300 g+ base (e.g. %s)" % [defs.size(), top.size(), ", ".join(PackedStringArray(top.slice(0, 6)))])
	var rare_plate := Items.make("warplate_adamantine", {"quality": 80.0})
	rare_plate["rarity"] = "rare"
	note("a rare Adamantine Warplate at 80 %% craftsmanship is valued %d g; leather boots list at %d g, wyrmleather boots at %d g" % [Items.value(rare_plate),
		Shop.list_price(Items.make("boots_leather", {"quality": 80.0})), Shop.list_price(Items.make("boots_wyrmleather", {"quality": 80.0}))])
	check(defs.size() > 0, "numbers recorded")


func test_found_gear_follows_class_use() -> void:
	fresh_game()
	var wiz: Dictionary = {}
	var pal: Dictionary = {}
	for a in Adv.all().values():
		Adv.ensure(a)
		if str(a["cls"]) == "Wizard" and wiz.is_empty():
			wiz = a
		if str(a["cls"]) in ["Paladin", "Fighter"] and pal.is_empty():
			pal = a
	if not check(not wiz.is_empty() and not pal.is_empty(), "a wizard and a plate-wearer in the roster"):
		return
	var plate := Items.make("mithril_plated_cuirass", {"quality": 100.0})
	var uid := int(plate["uid"])
	var before_offers := Shop.offers().size()
	var e := {"id": "exp_lwrel", "dest": str(DB.destinations.keys()[0]), "party": [wiz["id"]], "loot": [plate], "gold": 0}
	Expeditions._share_loot(e, [str(wiz["id"])])
	check(int(wiz["equipment"].get("armor", {}).get("uid", -1)) != uid, "a wizard does not put on found plate (affinity 0)")
	eq(Shop.offers().size(), before_offers + 1, "the plate is offered to the forge instead")
	var plate2 := Items.make("mithril_plated_cuirass", {"quality": 100.0})
	var e2 := {"id": "exp_lwrel2", "dest": str(DB.destinations.keys()[0]), "party": [wiz["id"], pal["id"]], "loot": [plate2], "gold": 0}
	Expeditions._share_loot(e2, [str(wiz["id"]), str(pal["id"])])
	eq(int(pal["equipment"].get("armor", {}).get("uid", -1)), int(plate2["uid"]), "the plate-wearer in the party takes it")
	_scan_clean("found gear")


# ------------------------------------------------------------------ #56 asking an adventurer what they need forged
func _in_town(cls := "") -> Dictionary:
	for a in Adv.all().values():
		Adv.ensure(a)
		if (cls == "" or str(a["cls"]) == cls) and str(a.get("status", "")) in ["in_town", "injured"]:
			return a
	for a in Adv.all().values():
		if cls == "" or str(a["cls"]) == cls:
			a["status"] = "in_town"
			return a
	return {}


func test_asking_for_a_commission_follows_their_rules() -> void:
	fresh_game()
	days(8)   # a week of expeditions: purses, wounds and "needs" as play brings them
	Shop.orders().clear()
	# the numbers: before LW #56 every in-town adventurer with a "needs" slot commissioned on asking
	var before := 0
	var now := 0
	var answers := {}
	var broke_reward := 0
	var offered := 0
	for a in Adv.all().values():
		Adv.ensure(a)
		if str(a.get("needs", "")) == "":
			continue   # the talk option is offered only to adventurers with a "needs" slot (Talk.options)
		offered += 1
		if not Shop.refuses(str(a["id"])):
			before += 1
			if int(a.get("gold", 0)) < Adv.commission_cost(a) + 10:
				broke_reward += int(Shop.order_need(a, str(a["needs"]))["min"]) * 3 + 40 + int(a["level"]) * 18
		var ans := Adv.commission_ask(a)
		answers[str(ans.get("why", "commission"))] = int(answers.get(str(ans.get("why", "commission")), 0)) + 1
		if ans.has("slot") and not ans.has("why"):
			now += 1
	note("day 9, %d of %d adventurers can be asked: asking used to bring %d commissions (about %d g of reward from those who could not pay a commission, the village subsidy covering their share); now %d (%s)" % [
		offered, Adv.all().size(), before, broke_reward, now, str(answers)])
	check(now <= before, "asking never brings more commissions than before")
	# a penniless adventurer with no weapon: an honest answer, no commission
	var a := _in_town()
	if not check(not a.is_empty(), "an adventurer in town"):
		return
	var npc := str(a["id"])
	a["equipment"].erase("weapon")
	a["gold"] = 0
	var r := Talk.choose(npc, "order", "village")
	check(Shop.open_orders().filter(func(o): return o["npc"] == npc).is_empty(), "no commission from someone who cannot pay for one")
	check(str(r.get("text", "")).contains("purse"), "they say why: %s" % r.get("text", ""))
	# with coin, the same want becomes a commission
	a["gold"] = Adv.commission_cost(a) + 60
	r = Talk.choose(npc, "order", "village")
	var mine := Shop.open_orders().filter(func(o): return o["npc"] == npc)
	check(mine.size() == 1, "with the coin they commission it (%s)" % r.get("text", ""))
	# asking again while it is open: no second order
	r = Talk.choose(npc, "order", "village")
	eq(Shop.open_orders().filter(func(o): return o["npc"] == npc).size(), 1, "one open commission at a time")
	# well kitted out: nothing to forge
	Shop.orders().clear()
	for s in Adv.desired_slots(a):
		if s == "companion":
			continue
		var best: Dictionary = {}
		for rr in DB.recipes.values():
			var d := DB.item(str(rr["output"]))
			if str(d.get("slot", "")) == s and Adv.affinity(a, {"def": str(rr["output"])}) > 0.0:
				var it := Items.make(str(rr["output"]), {"quality": 110.0})
				if best.is_empty() or Items.score(it) > Items.score(best):
					best = it
		if not best.is_empty():
			a["equipment"][s] = best
	a["wants_prop"] = ""
	a["gold"] = 5000
	var ans2 := Adv.commission_ask(a)
	eq(str(ans2.get("why", "")), "content", "well equipped: nothing they need forged")
	r = Talk.choose(npc, "order", "village")
	check(Shop.open_orders().filter(func(o): return o["npc"] == npc).is_empty(), "and no commission (%s)" % r.get("text", ""))


# ------------------------------------------------------------------ #61 commissions only for what a Design makes
## Independent oracle: is there ANY Design in the game whose piece this adventurer would use for `o`'s slot, of its tier,
## that reaches `o`'s stat — by itself (range top × 1.2) or with one runestone set into it (stat × 1.32)?
func _feasible(a: Dictionary, slot: String, stat: String, need: int, tier: int) -> bool:
	var rune := 0
	for r in DB.recipes.values():
		var d := DB.item(str(r["output"]))
		if str(d.get("type", "")) == "runestone":
			rune = maxi(rune, int(floor(float(d.get("stats", {}).get(stat, 0)) * 1.32)))
	for r in DB.recipes.values():
		var out := str(r["output"])
		var d := DB.item(out)
		if str(d.get("slot", "")) != slot or str(d.get("type", "")) == "companion" or Adv.affinity(a, {"def": out}) <= 0.0 or Items.tier({"def": out}) < tier:
			continue
		var v: Variant = d.get("stats", {}).get(stat, 0)
		var top := int(floor((float(v[1]) if v is Array else float(v)) * 1.2))
		if top >= need or (slot == "weapon" and not (stat in ["attack", "protection", "magic"]) and rune >= need):
			return true
	return false


## The commission rules before LW #61 (Shop.order_need as it was), to count what they asked for.
func _old_need(a: Dictionary, slot: String) -> Dictionary:
	var stat := "attack" if slot == "weapon" else ("magic" if slot in ["ring", "amulet"] else "protection")
	var need: int = maxi(Items.stat(a.get("equipment", {}).get(slot, {}), stat) + 2, int(a.get("level", 1)) * 2 + 4)
	var prop := str(a.get("wants_prop", ""))
	var tier := 2 if int(a.get("level", 1)) >= 5 and slot in ["weapon", "armor", "shield"] else 1
	if prop != "" and slot == "weapon":
		stat = prop
		need = 3 + int(a.get("level", 1)) / 3
	return {"stat": stat, "min": mini(need, Shop.slot_ceiling(slot, stat)), "tier": tier}


func test_commissions_ask_only_for_what_a_design_makes() -> void:
	var asked := 0
	var bad_now := 0
	var bad_before := 0
	var examples := {}
	for world_seed in [9001, 77, 1234]:
		fresh_game("journeyman", world_seed)
		for a in Adv.all().values():
			var lv0 := int(a.get("level", 1))
			for lv in [1, 3, 5, 7, 9]:
				a["level"] = lv
				for prop in ["", "fire", "frost"]:
					a["wants_prop"] = prop
					for slot in Adv.desired_slots(a):
						if slot == "companion":
							continue
						var n := Shop.order_need(a, slot)
						var o := _old_need(a, slot)
						asked += 1
						if not _feasible(a, slot, str(o["stat"]), int(o["min"]), int(o["tier"])):
							bad_before += 1
							var key := "%s %s (%s ≥ %d, %s)" % [a["cls"], slot, o["stat"], int(o["min"]), Items.TIER_WORD[int(o["tier"])]]
							examples[key] = true
						if bool(n.get("none", false)):
							continue
						if not _feasible(a, slot, str(n["stat"]), int(n["min"]), int(n["tier"])):
							bad_now += 1
							check(false, "%s %s at level %d asks for %s ≥ %d, %s — no Design they would use makes it" % [a["cls"], slot, lv, n["stat"], int(n["min"]), Items.TIER_WORD[int(n["tier"])]])
			a["level"] = lv0
			a["wants_prop"] = ""
	var ex: Array = examples.keys()
	ex.sort()
	note("%d commission requests examined (3 worlds, every adventurer at levels 1–9, with and without a fire/frost want): %d impossible before LW #61, %d now" % [asked, bad_before, bad_now])
	note("impossible before (kinds): " + ", ".join(PackedStringArray(ex.slice(0, 12))))
	eq(bad_now, 0, "no commission asks for something no Design they would use can make")
	check(bad_before > 0, "the old rules did ask for impossible pieces (the defect is real)")
	# companions are never commissioned (no Design makes one)
	fresh_game()
	var any_adv: Dictionary = Adv.all().values()[0]
	check(Shop.create_order(str(any_adv["id"]), "companion").is_empty(), "no commission for a companion creature")
	# a wizard veteran is not asked to wear steel armour
	for a in Adv.all().values():
		if str(a["cls"]) == "Wizard":
			a["level"] = 7
			var nd := Shop.order_need(a, "armor")
			eq(int(nd["tier"]), 1, "a level-7 wizard's armour commission does not demand steel (no plate for a wizard)")
			break


func test_frost_weapon_capability_is_honest() -> void:
	fresh_game()
	var a: Dictionary = {}
	for x in Adv.all().values():
		if str(x["cls"]) == "Fighter":
			a = x
			break
	if not check(not a.is_empty(), "a fighter in the roster"):
		return
	var req := {"stat": "frost", "min": 3}
	var cap := Shop.slot_capability("weapon", a, req)
	note("frost weapon on a new forge: %s — %s" % [cap["state"], cap["why"]])
	check(str(cap["state"]) == "locked", "a new forge cannot honestly promise a frost weapon (it knows no frost runestone): %s" % cap["state"])
	check(not Shop.can_make_slot("weapon", a, req), "can_make_slot agrees")
	# learn runecraft up to the frost runestone, buy the engraving stand, hold a frost runestone: now it can
	SkillTree.unlock_all()
	Property.dev_grant_all()
	Property.dev_install_in_owned()
	give("runestone_frost", 1)
	give("ingot_iron", 4)
	give("leather_cured", 2)
	give("coal", 4)
	var cap2 := Shop.slot_capability("weapon", a, req)
	note("frost weapon with the rune route: %s — %s" % [cap2["state"], cap2["why"]])
	check(str(cap2["state"]) in ["now", "materials"] and str(cap2.get("rune", "")) == "runestone_frost", "with a frost runestone Design and stand, a blade plus the rune is offered (%s)" % cap2["state"])
	check(str(cap2["why"]).contains("Frost Runestone"), "the card says the rune must be set into it")
	# multi-part requests: only pieces the adventurer would use, never a secret Design by name
	var wiz: Dictionary = {}
	for x in Adv.all().values():
		if str(x["cls"]) == "Wizard":
			wiz = x
	if check(not wiz.is_empty(), "a wizard in the roster"):
		fresh_game()
		for x in Adv.all().values():
			if str(x["cls"]) == "Wizard":
				wiz = x
		for i in 40:
			for pt in Shop.multi_parts_for(wiz):
				if str(pt.get("kind", "")) != "craft":
					continue
				check(Adv.affinity(wiz, {"def": str(pt["def"])}) > 0.0, "the wizard asks only for things a wizard would use (%s)" % pt["def"])
				check(Guide.recipe_visible(str(pt["recipe"])), "no secret Design is named (%s)" % pt["recipe"])
