## Milestone S2 — workshop clarity and physical presence (the CLARITY worker).
## A material batch says what decided its size — the recipe's units and the bonus unit with its cause, or why there was
## none — and that its craftsmanship is not kept (OBS-11); the skill check is named in the world prompt, the station
## header (in that mechanic's own terms, BUG-044) and per operation before Begin (OBS-12); no floor drop (returns bags,
## the Project Bench's crates) lies on the Loft stair, the hoist, a landing or a doorway (OBS-13/14); a potion customer
## is offered only what they asked for within their budget, the rest greyed with the reason, and the sale itself
## honours the request (OBS-15, BUG-043); the optional "only what they would buy / can buy" filters are off by default
## and hide only ineligible rows (OBS-16); the contracts panel opened on a closed order keeps a readable width
## (BUG-001); the quiet hint ring picks the nearest usable station or person; the forge's night light burns at night
## and is gone by day; apprentices work visibly at stations in the leather room and the Loft (OBS-21).
extends SuiteCase

const SMOKE := ["test_leather_batch_explained", "test_goods_offers_follow_the_request"]


# ------------------------------------------------------------------ fixtures
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Node) -> Node:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


func _world() -> VillageWorld:
	var w := VillageWorld.new()
	_host().add_child(w)
	if PlayerNav.of(w) == null:
		var nav := PlayerNav.new()
		nav.name = "PlayerNav"
		w.add_child(nav)
		nav.setup(w, w.player)
	PlayerNav.of(w).ensure_grid(true)
	return w


## Every text shown under `root` (labels, rich text, buttons), joined.
func _texts(root: Node) -> String:
	var out := PackedStringArray()
	for n in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	for n in root.find_children("*", "RichTextLabel", true, false):
		out.append((n as RichTextLabel).get_parsed_text())
	for n in root.find_children("*", "Button", true, false):
		out.append((n as Button).text)
	return "\n".join(out)


## A leather room with its vat, the Loft above it, the recipes learned (this case is about what the screens say).
func _workshop() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()   # Borin's own errands would move the stores under the test
	Game.state["gold"] = 20000
	for u in ["weaver", "loft"]:
		Property.dev_grant_unit(u)
	Property.dev_install_in_owned()
	SkillTree.unlock_all()


func _cure(q: float, purity: int) -> Dictionary:
	give("leather_hide", 2)
	return craft("cure_leather", q, {"purity": purity})


# ------------------------------------------------------------------ OBS-11: the leather batch
func test_leather_batch_explained() -> void:
	_workshop()
	eq(Crafting.recipe_locked_reason("cure_leather"), "", "cure_leather is learned and its vat stands ready")
	var held0 := Game.count("leather_cured")
	var plain := _cure(96.0, 4)
	if not check(not plain.is_empty(), "an ordinary batch is cured"):
		return
	eq(int(plain["qty"]), 2, "an ordinary batch is the recipe's two units")
	var y: Dictionary = plain["craft"].get("yield", {})
	check(int(y.get("base", 0)) == 2 and int(y.get("bonus", -1)) == 0 and int(y.get("purity", 0)) == 4, "the record keeps what made the batch (%s)" % str(y))
	var t := "\n".join(PackedStringArray(CraftResultPanel.yield_lines(plain)))
	check(t.contains("Batch: 2 Cured Leather") and t.contains("No bonus unit") and t.contains("105%") and t.contains("purity 6"), "no bonus: the rule is stated (%s)" % t)
	check(t.contains("%d%%" % int(round(float(plain["craft"]["quality"])))) and t.contains("purity 4"), "…with this batch's own numbers (%s)" % t)
	check(t.contains("not their grade") and t.contains("work exactly like the rest"), "…and that the batch's craftsmanship is not kept")
	var fine := _cure(112.0, 2)
	eq(int(fine["qty"]), 3, "excellent work yields a third unit")
	var t2 := "\n".join(PackedStringArray(CraftResultPanel.yield_lines(fine)))
	check(t2.contains("+1 bonus unit") and t2.contains("craftsmanship reached %d%%" % int(round(float(fine["craft"]["quality"])))), "the bonus names its cause: craftsmanship (%s)" % t2)
	var pure := _cure(90.0, 6)
	eq(int(pure["qty"]), 3, "a purity 6 yields a third unit")
	var t3 := "\n".join(PackedStringArray(CraftResultPanel.yield_lines(pure)))
	check(t3.contains("+1 bonus unit") and t3.contains("purity die rolled a 6"), "the bonus names its cause: purity (%s)" % t3)
	# the claim is true: the units merge into one stack and a later recipe takes them by kind, whatever their batch
	eq(Game.count("leather_cured") - held0, 8, "all eight units are in the stores")
	var stacks := Game.inventory().filter(func(x): return str(x["def"]) == "leather_cured")
	eq(stacks.size(), 1, "one stack of cured leather: the batches' craftsmanship is not kept apart")
	# an item from before S2 (no yield record) still explains itself
	var old := pure.duplicate(true)
	(old["craft"] as Dictionary).erase("yield")
	var t4 := "\n".join(PackedStringArray(CraftResultPanel.yield_lines(old)))
	check(t4.contains("+1 bonus unit") and t4.contains("the Design makes 2"), "an older record is reconstructed (%s)" % t4)
	# equipment has no batch
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var sword := craft("iron_longsword", 92.0)
	check(not sword.is_empty() and CraftResultPanel.yield_lines(sword).is_empty(), "a sword has no batch line")
	# the result screen shows it
	var p := _mount(CraftResultPanel.new(fine, false)) as CraftResultPanel
	var note_n := p.find_child("YieldNote", true, false) as RichTextLabel
	check(note_n != null and note_n.get_parsed_text().contains("+1 bonus unit"), "the result screen carries the batch note")
	_unmount(p)


# ------------------------------------------------------------------ OBS-12, BUG-044: the check named before the work
func test_check_type_named_before_the_work() -> void:
	_workshop()
	eq(StationPanel.check_name("anvil"), "precision ring", "the anvil runs the precision ring")
	eq(StationPanel.check_name("bellows"), "Spark & Ember alignment", "the bellows run the alignment check")
	eq(StationPanel.check_name("grinding_wheel"), "Edge control", "the grinding wheel runs edge control")
	var ring := StationPanel.check_line("anvil")
	check(ring.begins_with("Check: precision ring") and ring.contains("needle") and ring.contains("zone"), "the ring header quotes the ring's zone and needle (%s)" % ring)
	for sid in ["bellows", "grinding_wheel", "embroidery_frame", "rune_engraving_stand"]:
		var l := StationPanel.check_line(sid)
		check(l.contains("not the precision ring") and not l.contains("needle") and not l.contains("°"), "%s: the header describes its own check (%s)" % [sid, l])
	# the world prompt names it before the smith presses E
	for pair in [["bellows", "check: Spark & Ember alignment"], ["anvil", "check: precision ring"], ["grinding_wheel", "check: Edge control"]]:
		var pr := WorldPrompts.for_entity({"kind": "station", "id": pair[0]})
		check(WorldPrompts.line(pr).contains(str(pair[1])), "%s prompt: %s" % [pair[0], WorldPrompts.line(pr)])
	# a station still locked promises no check
	var locked := ""
	for sid in DB.stations:
		if Crafting.station_locked_reason(str(sid)) != "" and str(sid) != Contracts.BENCH:
			locked = str(sid)
			break
	if locked != "":
		check(not WorldPrompts.line(WorldPrompts.for_entity({"kind": "station", "id": locked})).contains("check:"), "a locked station names no check (%s)" % locked)
	# the panel: header, every operation of a recipe, and the step in hand
	var p := _mount(StationPanel.new("anvil")) as StationPanel
	var t := _texts(p)
	check(t.contains("Check: precision ring"), "the anvil panel's header names the check")
	check(t.contains("(precision ring)") and t.contains("(Edge control)"), "a recipe lists the check of each operation before Begin")
	_unmount(p)
	give("ingot_iron", 2)
	give("leather_cured", 1)
	check(Crafting.start("iron_longsword"), "a longsword begun")
	var p2 := _mount(StationPanel.new(Crafting.current_station())) as StationPanel
	var wb := p2.find_child("WorkButton", true, false) as Button
	check(wb != null and wb.text.contains("·") and wb.text.contains(StationPanel.check_name(Crafting.current_station())), "the work button names the check (%s)" % (wb.text if wb else "none"))
	check(_texts(p2).contains("Edge control)"), "the steps list names the grinding wheel's edge control")
	_unmount(p2)
	Crafting.cancel()


# ------------------------------------------------------------------ OBS-13/14: floor drops clear of the stair
func test_floor_drops_keep_clear() -> void:
	_workshop()
	check(Property.floor_owned("loft"), "the Loft is owned (its stair stands in the stock hall)")
	var ground := Property.floor_def("loft")
	var stair := Vector2(float(ground["down_stairs"][0]), float(ground["down_stairs"][1]))
	var lift := Vector2(float(ground["down_lift"][0]), float(ground["down_lift"][1]))
	for n in [1, 6, 12]:
		var spots := Property.drop_spots(n)
		eq(spots.size(), n, "%d places for %d drops" % [n, n])
		var bad := []
		for p: Vector2 in spots:
			var box := Rect2(p - Property.DROP_HALF, Property.DROP_HALF * 2.0)
			for rv: Rect2 in Property.reserved_rects():
				if box.intersects(rv):
					bad.append("%s on a reserved rect" % str(p))
			if p.distance_to(stair) < Property.DROP_LINK_CLEAR or p.distance_to(lift) < Property.DROP_LINK_CLEAR:
				bad.append("%s beside the stair or lift" % str(p))
			for d in Property.doors():
				var c := Property.door_center(Property.st(), d)
				if c != Vector2.INF and box.grow(0.5).has_point(c):
					bad.append("%s in a doorway" % str(p))
			if Property.drop_problem(p) != "":
				bad.append("%s: %s" % [str(p), Property.drop_problem(p)])
		check(bad.is_empty(), "%d drops: all on clear floor (%s)" % [n, str(bad)])
	var six := Property.drop_spots(6)
	var distinct := {}
	for p: Vector2 in six:
		distinct[str(p)] = true
	eq(distinct.size(), 6, "six drops lie side by side, not on one another")
	eq(Property.drop_problem(stair), "on the stairwell or the hoist", "the old spot under the stair is refused")
	# in the world: a hireling's haul (linen thread), an expedition find and a sponsor-style chest
	var ret: Array = Game.state["returns"]
	ret.append(Loot.make_container("bag_traveller", [Items.make("thread_linen", {"qty": 6})], "Borin", "A trade run."))
	ret.append(Loot.make_container("chest_recovered", [Items.make("ore_silver", {"qty": 2})], "Mira", "From the barrows."))
	for i in 4:
		ret.append(Loot.make_container("bag_traveller", [Items.make("ingot_iron", {"qty": 2})], "Borin", "Smelted."))
	var w := _world()
	var stair_e := {}
	for e in w.interactables:
		if str(e["kind"]) == "stairs":
			stair_e = e
	check(not stair_e.is_empty(), "the Loft stair stands in the stock hall")
	var sp_rect := Rect2((stair_e.get("pos", Vector2.ZERO) as Vector2) - Vector2(48, 64), Vector2(96, 128))
	var bags := 0
	for e in w.interactables:
		if str(e["kind"]) != "bag":
			continue
		bags += 1
		var bp: Vector2 = e["pos"]
		check(not sp_rect.intersects(Rect2(bp - Vector2(32, 24), Vector2(64, 48))), "bag %s is not under the stair's picture" % str(e["id"]))
		check(bp.distance_to(stair_e["pos"]) > float(stair_e["r"]), "bag %s does not compete with the stair for [E] (%.0f px)" % [str(e["id"]), bp.distance_to(stair_e["pos"])])
		eq(w.room_at("smithy", bp), "stock_hall", "bag %s lies in the stock hall" % str(e["id"]))
	eq(bags, 6, "all six returns are drawn")
	_unmount(w)
	# the Project Bench's crates keep the same rule
	if Property.buy_station(Contracts.BENCH) == "":
		var plan := Property.plan_copy()
		var why := Property.auto_place(plan, Contracts.BENCH)
		if why == "" and Property.commit(plan) == "":
			for p: Vector2 in ContractWorld.free_spots(2):
				eq(Property.drop_problem(p, ContractWorld.CRATE_HALF, Contracts.BENCH), "", "a bench crate at %s is on clear floor" % str(p))
		else:
			note("bench not placed: %s" % why)


# ------------------------------------------------------------------ OBS-15, BUG-043: potion offers
func _goods_customer(budget := 50, want := "potion_healing") -> Dictionary:
	Shop.customers().clear()
	var c := {"npc": "martha", "want": "goods", "seat": 0, "present": true, "arrived": 0, "budget": budget, "looking_for": want}
	Shop.customers().append(c)
	return c


func test_goods_offers_follow_the_request() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()
	for d in ["potion_healing", "oil_whetstone", "coating_flame"]:
		give(d, 2)
	var c := _goods_customer(50)
	var cands := ShopPanel.goods_candidates(c)
	eq(cands.size(), 3, "three draughts in the stores")
	var why := {}
	for x in cands:
		why[str(x["item"]["def"])] = str(x["why"])
	eq(why.get("potion_healing", "?"), "", "the healing draught they asked for, within budget, can be sold")
	check(str(why.get("oil_whetstone", "")).begins_with("not what they asked for") and str(why["oil_whetstone"]).contains("Healing Draught"), "whetstone oil: not what they asked for (%s)" % why.get("oil_whetstone", ""))
	check(str(why.get("coating_flame", "")).begins_with("not what they asked for"), "flame coating: not what they asked for")
	eq(str(cands[0]["item"]["def"]), "potion_healing", "what they would buy comes first")
	# a tight budget greys the right potion with the reason
	var c2 := _goods_customer(20)
	var heal := {}
	for x in ShopPanel.goods_candidates(c2):
		if str(x["item"]["def"]) == "potion_healing":
			heal = x
	check(str(heal.get("why", "")).begins_with("over their budget") and str(heal["why"]).contains("20 g"), "over budget, with the numbers (%s)" % heal.get("why", ""))
	# BUG-043: the sale honours the request
	_goods_customer(50)
	var oil := {}
	var pot := {}
	for it in Game.inventory():
		if str(it["def"]) == "oil_whetstone":
			oil = it
		if str(it["def"]) == "potion_healing":
			pot = it
	var err := Shop.sell_goods("martha", int(oil["uid"]))
	check(err.contains("asked for"), "whetstone oil is refused for a healing-draught request (%s)" % err)
	eq(Game.count("oil_whetstone"), 2, "nothing left the stores")
	var g0 := Game.gold()
	eq(Shop.sell_goods("martha", int(pot["uid"])), "", "the healing draught sells")
	check(Game.gold() > g0 and Game.count("potion_healing") == 1 and Shop.customer("martha").is_empty(), "paid, one draught gone, the customer served")
	# the counter: one enabled Sell, the others greyed and saying why
	for d in ["potion_healing"]:
		give(d, 1)
	_goods_customer(50)
	var sp := _mount(ShopPanel.new("customers", "martha")) as ShopPanel
	var sells := sp.find_children("SellGoods", "Button", true, false)
	eq(sells.size(), 3, "a row for each draught")
	eq(sells.filter(func(b): return not (b as Button).disabled).size(), 1, "one enabled: the healing draught")
	var t := _texts(sp)
	check(t.contains("✗ not what they asked for"), "the greyed rows say why")
	for b in sells:
		if (b as Button).disabled:
			check((b as Button).tooltip_text.begins_with("They would not buy it"), "a greyed Sell explains itself")
	_unmount(sp)
	Shop.customers().clear()


# ------------------------------------------------------------------ OBS-16: optional filters
func test_optional_filters_hide_only_ineligible() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()
	check(not OfferPicker.only_buyable and not HerbalistPanel.only_affordable, "both filters are off by default")
	for d in ["potion_healing", "oil_whetstone", "coating_flame"]:
		give(d, 1)
	_goods_customer(50)
	var sp := _mount(ShopPanel.new("customers", "martha")) as ShopPanel
	eq(sp.find_children("SellGoods", "Button", true, false).size(), 3, "unfiltered: every draught shown")
	var cb := sp.find_child("OnlyBuyable", true, false) as CheckBox
	check(cb != null and not cb.button_pressed, "the filter is offered, unticked")
	_unmount(sp)
	OfferPicker.only_buyable = true
	var sp2 := _mount(ShopPanel.new("customers", "martha")) as ShopPanel
	var shown := sp2.find_children("SellGoods", "Button", true, false)
	check(shown.size() == 1 and not (shown[0] as Button).disabled, "filtered: only the healing draught remains")
	check(_texts(sp2).contains("2 other draughts hidden"), "and the hidden ones are counted")
	_unmount(sp2)
	# the adventurer's offer grid
	var mira := Adv.get_a("mira")
	mira["status"] = "in_town"
	mira["gold"] = 90
	for d in ["sword_iron", "sword_steel", "helm_iron"]:
		var it := Items.make(d, {"quality": 92.0})
		it["for_sale"] = true
		Game.add_item(it, false)
	var req := {"kind": "equipment", "slot": "weapon", "stat": "attack", "min": 1}
	var all := OfferPicker.candidates("mira", req)
	var buy := all.filter(func(x): return str(x["why"]) == "")
	check(all.size() > buy.size(), "some pieces she would not buy (%d of %d)" % [all.size() - buy.size(), all.size()])
	var pk := _mount(OfferPicker.new("mira", req)) as OfferPicker
	eq(pk.cells.size(), buy.size(), "filtered: only what she would buy is in the grid")
	OfferPicker.only_buyable = false
	pk.rebuild()
	eq(pk.cells.size(), all.size(), "unticked again: every piece, the others dimmed")
	_unmount(pk)
	# a village counter
	Game.state["gold"] = 0
	var hp := _mount(HerbalistPanel.new({"id": "herbalist"})) as HerbalistPanel
	var grid := hp.find_child("StockGrid", true, false) as GridContainer
	var n_all := grid.get_child_count() if grid else 0
	check(n_all > 0, "unfiltered: today's stock is shown (greyed) with an empty purse (%d)" % n_all)
	_unmount(hp)
	HerbalistPanel.only_affordable = true
	var hp2 := _mount(HerbalistPanel.new({"id": "herbalist"})) as HerbalistPanel
	var grid2 := hp2.find_child("StockGrid", true, false) as GridContainer
	eq(grid2.get_child_count() if grid2 else -1, 0, "filtered with an empty purse: nothing to buy is shown")
	check(_texts(hp2).contains("hidden"), "and it says what is hidden")
	_unmount(hp2)
	HerbalistPanel.only_affordable = false
	OfferPicker.only_buyable = false
	Shop.customers().clear()


# ------------------------------------------------------------------ BUG-001: a closed order
func test_contracts_panel_on_a_closed_order() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = 5000
	check(Property.buy_station(Contracts.BENCH) == "", "a Project Bench bought")
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, Contracts.BENCH)
	if why != "":
		Property.dev_grant_unit("cobbler")
		plan = Property.plan_copy()
		why = Property.auto_place(plan, Contracts.BENCH)
	check(why == "" and Property.commit(plan) == "", "and set up (%s)" % why)
	# the Watch's order has a 61-character title: long enough to wrap (UIKit.label wraps beyond 48)
	var o := Contracts.make_offer("watch_arms")
	if not check(not o.has("error"), "an offer (%s)" % str(o.get("error", ""))):
		return
	var cid := str(o["id"])
	check(str(o["title"]).length() > 48, "a long title (%s)" % o["title"])
	var po := _mount(ContractsPanel.new({"id": cid})) as ContractsPanel
	for l in po.right.find_children("*", "Label", true, false):
		var lb := l as Label
		if lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
			check(lb.custom_minimum_size.x >= 300.0, "the letter: a wrapping line is given a width (%d px: %s)" % [int(lb.custom_minimum_size.x), lb.text.left(30)])
	_unmount(po)
	eq(Contracts.accept(cid), "", "accepted")
	var c := Contracts.get_c(cid)
	for d in Contracts.materials_needed(c):
		give(str(d), int(Contracts.materials_needed(c)[d]))
	for d in c["rare"]:
		give(str(d), int(c["rare"][d]))
	var g := 0
	while not Contracts.ready(cid) and g < 200:
		Vitality.set_fatigue(0.0)
		if str(Contracts.work(cid, 4).get("error", "")) != "":
			break
		g += 1
	Contracts.deliver(cid)
	check(str(Contracts.get_c(cid).get("status", "")) in Contracts.FINISHED, "the order is closed")
	var p := _mount(ContractsPanel.new({"id": cid})) as ContractsPanel
	eq(p.sel, cid, "opened directly on the closed order")
	var rmin := p.right.get_combined_minimum_size().x
	check(rmin >= 900.0, "the right column keeps a readable width (%d px)" % int(rmin))
	for l in p.right.find_children("*", "Label", true, false):
		var lb := l as Label
		if lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
			check(lb.custom_minimum_size.x >= 300.0, "a wrapping line is given a width, not one letter per line (%d px: %s)" % [int(lb.custom_minimum_size.x), lb.text.left(30)])
	for l in p.right.find_children("*", "RichTextLabel", true, false):
		var rl := l as RichTextLabel
		if rl.get_parsed_text().length() > 40:
			check(rl.custom_minimum_size.x >= 600.0, "a long line is given room (%d px: %s…)" % [int(rl.custom_minimum_size.x), rl.get_parsed_text().left(30)])
	check(p.get_combined_minimum_size().x <= 1920.0, "the window still fits the screen (%d px)" % int(p.get_combined_minimum_size().x))
	_unmount(p)


# ------------------------------------------------------------------ contextual hint
func test_hint_picks_the_nearest_usable() -> void:
	var cands := [{"kind": "station", "id": "forge", "pos": Vector2(40, 0), "usable": false},
		{"kind": "station", "id": "anvil", "pos": Vector2(120, 0), "usable": true},
		{"kind": "npc", "id": "martha", "pos": Vector2(0, 200), "usable": true}]
	eq(str(VillageWorld.hint_pick(Vector2.ZERO, cands).get("id", "")), "anvil", "the nearest usable target, not the nearer unusable one")
	eq(str(VillageWorld.hint_pick(Vector2.ZERO, cands, "station/anvil").get("id", "")), "martha", "the one in reach is left to the focus ring")
	check(VillageWorld.hint_pick(Vector2.ZERO, cands, "station/anvil", 150.0).is_empty(), "nothing usable within range — no ring")
	_workshop()
	Game.state["player"]["inventory"] = []   # empty stores: nothing can begin anywhere
	check(not VillageWorld.station_usable("anvil"), "an anvil with no materials offers nothing to do")
	give("ingot_iron", 2)
	give("leather_cured", 1)
	check(VillageWorld.station_usable("anvil"), "with a longsword's materials it does")
	check(Crafting.start("iron_longsword"), "the work begun")
	check(VillageWorld.station_usable(Crafting.current_station()) and not VillageWorld.station_usable("anvil" if Crafting.current_station() != "anvil" else "forge"),
		"during work only the next step's station is usable")
	Crafting.cancel()
	_goods_customer(50)
	check(VillageWorld.person_usable("martha", "smithy"), "a customer waiting to be served is usable")
	Shop.customers().clear()
	# in the world: near the anvil with materials, the ring finds it
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var w := _world()
	var near := w.station_pos("anvil") + Vector2(-60, 230)
	var pick := VillageWorld.hint_pick(near, w.hint_candidates(near))
	check(not pick.is_empty() and bool(pick["usable"]), "a usable station within a few steps is picked (%s)" % str(pick.get("id", "none")))
	w._update_hint(near)
	check(w._hint_ring != null and w._hint_ring.visible, "the hint ring is shown")
	# both rings draw above the interior floor (the focus ring sat under it at z -1 and showed only outdoors)
	w._set_highlight({"kind": "station", "id": "anvil", "pos": w.station_pos("anvil")})
	check(w._hl_ring.z_index > 0 and w._hint_ring.z_index > 0, "the focus and hint rings draw above the floor (z %d, %d)" % [w._hl_ring.z_index, w._hint_ring.z_index])
	_unmount(w)


# ------------------------------------------------------------------ the forge at night
func test_forge_night_light() -> void:
	_workshop()
	var w := _world()
	var fl := w.find_child("ForgeNightLight", true, false) as PointLight2D
	if not check(fl != null, "the forge has a night light"):
		_unmount(w)
		return
	check(w.night_lights.has(fl), "it follows the evening like the other night lights")
	check(fl.has_method("_process"), "and flickers like fire")
	eq(fl.range_item_cull_mask, 1, "it lights the workshop, not the street")
	Game.state["minute"] = 22 * 60
	w._update_light(false)
	check(fl.visible and float(fl.get("base_energy")) > 0.8, "at 22:00 it burns (%.2f)" % float(fl.get("base_energy")))
	Game.state["minute"] = 18 * 60 + 30
	w._update_light(false)
	check(fl.visible and float(fl.get("base_energy")) > 0.1 and float(fl.get("base_energy")) < 0.8, "at 18:30 it is coming up (%.2f)" % float(fl.get("base_energy")))
	Game.state["minute"] = 13 * 60
	w._update_light(false)
	check(not fl.visible, "by day it is gone (the forge's own fire light stays)")
	_unmount(w)


# ------------------------------------------------------------------ OBS-21: apprentices at their stations
## The room [id, world rect] holding `pos`, on the ground floor or the Loft.
func _room_of(w: VillageWorld, pos: Vector2) -> Array:
	for bid in ["smithy", "smithy_loft"]:
		for rm in w.buildings.get(bid, {}).get("rooms", []):
			if (rm["rect"] as Rect2).has_point(pos):
				return [str(rm["id"]), rm["rect"]]
	return ["", Rect2()]


func test_apprentices_stand_inside_rooms() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = 50000
	Property.dev_grant_all()
	SkillTree.unlock_all()
	# some stations up in the Loft, as a player sets them (the same places as the smithy suite)
	var plan := Property.plan_copy()
	for pr in [["loom", Vector2(112.6, 25.0)], ["cutting_table", Vector2(116.8, 25.0)], ["alembic", Vector2(102.6, 20.4)],
			["rune_polishing_wheel", Vector2(102.4, 30.6)]]:
		Property.place(plan, str(pr[0]), pr[1])
	eq(Property.commit(plan), "", "the two-floor layout is accepted")
	var w := _world()
	var acts := w.get_node("ApprenticeActors") as ApprenticeActors
	var bad := []
	var upstairs := 0
	for sid in Property.st()["stations"]:
		if not Property.is_installed(str(sid)) or str(sid) == Contracts.BENCH:
			continue
		var sp := w.station_pos(str(sid))
		var ws := acts.work_spot(str(sid))
		var at: Vector2 = ws["pos"]
		var room := _room_of(w, at)
		if str(room[0]).begins_with("loft"):
			upstairs += 1
		if str(room[0]) != str(_room_of(w, sp)[0]):
			bad.append("%s: works from %s, the station is in %s" % [sid, room[0], _room_of(w, sp)[0]])
		elif not (room[1] as Rect2).grow(2.0).encloses(Rect2(at + Vector2(-22, -80), Vector2(44, 86))):
			bad.append("%s: the figure crosses a wall at %s" % [sid, str(at)])
		elif at.distance_to(sp) > 200.0:
			bad.append("%s: %.0f px from the work" % [sid, at.distance_to(sp)])
	check(bad.is_empty(), "every station has a working side inside its own room, near it, the figure clear of the walls: %s" % str(bad))
	check(upstairs >= 4, "the Loft stations are worked from the Loft (%d)" % upstairs)
	# the forge by the north wall: its apprentice no longer stands on the outer wall
	var fs: Vector2 = acts.work_spot("forge")["pos"]
	var fr: Rect2 = _room_of(w, w.station_pos("forge"))[1]
	check(fs.y - 80.0 >= fr.position.y - 2.0, "the forge's apprentice stands below the north wall (feet %.0f px into the room)" % (fs.y - fr.position.y))
	_unmount(w)
