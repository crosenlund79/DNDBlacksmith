## Recognition — weighted dice from craftsmanship, customer multi-orders, the Hall of Fame, Epic distinction
## and the ceremony in the square (iteration 010).
extends SuiteCase

const SMOKE := ["test_weighted_dice_statistics", "test_physical_dice_respected", "test_epic_on_boss_kill"]


func _in_town_adv() -> String:
	for a in Adv.all().values():
		if a["status"] == "in_town" and not Shop.refuses(a["id"]):
			return a["id"]
	return ""


# ------------------------------------------------------------------ weighted dice
func test_weighted_dice_statistics() -> void:
	seed(4242)
	var spec: Dictionary = DB.recipe("iron_longsword")["dice"]
	var d := DB.item("sword_iron")
	var mat: Dictionary = DB.crafting["materials"].get(str(DB.recipe("iron_longsword").get("material", "iron")), {})
	eq(int(Crafting.advantage(60.0)["tier"]), -1, "below 70% gives disadvantage")
	eq(int(Crafting.advantage(100.0)["tier"]), 1, "around 100% gives a slight advantage")
	eq(int(Crafting.advantage(118.0)["tier"]), 2, "115%+ gives strong advantage")
	check(not Crafting.is_stat_die("fortune"), "the fortune die stays pure luck (rarity progression unchanged)")
	var n := 600
	var edge_lo := 0.0
	var edge_hi := 0.0
	var atk_lo := 0.0
	var atk_hi := 0.0
	var upsets := 0
	for i in n:
		var lo := Crafting.roll_dice(spec, 70.0)
		var hi := Crafting.roll_dice(spec, 115.0)
		edge_lo += float(lo["edge"]["total"])
		edge_hi += float(hi["edge"]["total"])
		var tl := {}
		var th := {}
		for k in lo:
			tl[k] = int(lo[k]["total"])
			th[k] = int(hi[k]["total"])
		var sl := Crafting.compute_stats(d, 70.0, tl, spec, mat, 2)
		var sh := Crafting.compute_stats(d, 115.0, th, spec, mat, 2)
		atk_lo += float(sl["attack"])
		atk_hi += float(sh["attack"])
		if int(sl["attack"]) > int(sh["attack"]):
			upsets += 1
	note("edge die mean: 70%% %.2f vs 115%% %.2f; attack mean %.2f vs %.2f; poor beat exceptional %d/%d" % [edge_lo / n, edge_hi / n, atk_lo / n, atk_hi / n, upsets, n])
	check(edge_hi / n > edge_lo / n + 3.0, "the edge die rolls clearly higher at 115% than at 70%")
	check(atk_hi / n > atk_lo / n, "mean attack at 115% beats 70%")
	check(upsets < n * 0.02, "poor crafting beats exceptional only rarely (%d of %d)" % [upsets, n])
	# fortune is never weighted: its distribution does not depend on craftsmanship
	var f := Crafting.roll_weighted("fortune", "1d100", 125.0)
	eq((f["rolls"] as Array).size(), 1, "fortune is rolled exactly once even at 125%")
	# the weighted roll explains itself
	var r := Crafting.roll_weighted("edge", "1d20", 120.0)
	eq((r["rolls"] as Array).size(), 3, "strong advantage rolls three times")
	var best := 0
	for x in r["rolls"]:
		best = maxi(best, int(x["total"]))
	eq(int(r["total"]), best, "strong advantage keeps the best roll")


func test_digital_weighted_record_and_fixed_dice() -> void:
	fresh_game()
	give("ingot_iron", 6)
	give("leather_cured", 3)
	# fixed dice (the progression planner's path) are used exactly as given
	var it := craft("iron_longsword", 100.0, {"edge": 12, "temper": 12, "fortune": 50})
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var cr: Dictionary = it["craft"]
	eq(int(cr["dice"]["edge"]["total"]), 12, "fixed dice are not re-weighted")
	eq(str(cr["dice"]["edge"]["how"]), "fixed", "fixed dice are recorded as such")
	check(not (cr.get("breakdown", []) as Array).is_empty() and str(cr["breakdown"][0]).contains("craftsmanship"), "the craft record explains how the stats came about")
	# a digital weighted roll is stored with every roll and the kept one
	check(Crafting.start("iron_longsword"), "a second sword begins")
	while Crafting.current_station() != "":
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(110.0)
		Crafting.record_step(Crafting.current_station(), qs)
	var q := Crafting.final_quality()
	var rolled := Crafting.roll_dice(Crafting.dice_spec(), q)
	var it2 := Crafting.finish(rolled, "digital")
	var e: Dictionary = it2["craft"]["dice"]["edge"]
	eq(str(e["how"]), "weighted", "digital rolls are recorded as weighted")
	check((e["rolls"] as Array).size() >= 2, "advantage at %d%% rolled the edge die more than once" % int(q))
	check(str(e["text"]).contains("kept") and str(e["text"]).contains("craftsmanship"), "the explanation names the kept roll and the craftsmanship (%s)" % e["text"])


func test_physical_dice_respected() -> void:
	fresh_game()
	give("ingot_iron", 6)
	give("leather_cured", 3)
	check(Crafting.start("iron_longsword"), "the sword begins")
	while Crafting.current_station() != "":
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(118.0)
		Crafting.record_step(Crafting.current_station(), qs)
	var q := Crafting.final_quality()
	var m := Crafting.physical_modifier("edge", "1d20", q)
	check(m > 0, "exceptional craftsmanship gives a positive physical modifier (%+d)" % m)
	var it := Crafting.finish({"edge": {"total": 9, "faces": [9]}, "temper": {"total": 4, "faces": [4]}, "fortune": {"total": 33, "faces": [33]}}, "physical")
	var dl: Dictionary = it["craft"]["dice"]
	eq(int(dl["edge"]["entered"]), 9, "the entered edge roll is kept as entered")
	eq(dl["edge"]["faces"], [9], "the entered faces are never replaced")
	eq(int(dl["edge"]["mod"]), m, "the shown modifier is the craftsmanship modifier")
	eq(int(dl["edge"]["total"]), mini(20, 9 + m), "the counted value is roll + modifier")
	eq(int(dl["fortune"]["total"]), 33, "fortune is counted exactly as rolled")
	check(str(dl["edge"]["text"]).contains("you rolled 9") and str(dl["edge"]["text"]).contains("%+d" % m), "the modifier is shown (%s)" % dl["edge"]["text"])


# ------------------------------------------------------------------ multi-orders
func test_multi_order_partial() -> void:
	fresh_game()
	var aid := _in_town_adv()
	if not check(aid != "", "an adventurer is in town"):
		return
	for c in Shop.customers().duplicate():
		Shop.remove_customer(str(c["npc"]))
	Shop._add_customer(aid, "multi")
	var c := Shop.customer(aid)
	if not check(str(c.get("want", "")) == "multi", "the customer brings several requests"):
		return
	Shop.mark_arrived(aid, false)
	var parts: Array = c["parts"]
	check(parts.size() >= 3, "advanced, ordinary and repair parts (%d)" % parts.size())
	var adv := {}
	var std := {}
	var rep := {}
	for pt in parts:
		match str(pt["pid"]):
			"adv": adv = pt
			"std": std = pt
			"rep": rep = pt
	check(not adv.is_empty() and not bool(Shop.part_availability(adv)["ok"]), "the advanced part is not craftable yet (%s)" % Shop.part_availability(adv).get("why", ""))
	check(not std.is_empty() and bool(Shop.part_availability(std)["ok"]), "the ordinary part is within the smith's abilities")
	var card := Shop.part_request(c, adv)
	check(str(card["availability"]) == "locked" and str(card["why"]) != "", "the card says why the advanced piece is not possible yet")
	# decline the impossible part, accept the ordinary one, do the repair
	Shop.decline_part(aid, "adv")
	eq(str(adv["status"]), "declined", "one part can be declined")
	check(not Shop.customer(aid).is_empty(), "declining one part does not send the customer away")
	var n0 := Shop.open_orders().size()
	eq(Shop.accept_part(aid, "std"), "", "the ordinary part is accepted")
	eq(Shop.open_orders().size(), n0 + 1, "the accepted part became a commission")
	var o: Dictionary = Shop.open_orders().back()
	eq(str(o.get("def", "")), str(std["def"]), "the commission asks for that exact piece")
	var g0 := Game.gold()
	Shop.repair_part(aid, "rep", 90.0)
	check(Game.gold() > g0, "the repair part paid")
	check(Shop.customer(aid).is_empty(), "with nothing pending the customer leaves")
	# the commission is fulfilled with a matching piece
	var it := Items.make(str(std["def"]), {"quality": 95.0})
	it["crafted_by"] = "Brannoc Ironhand"
	Game.add_item(it, false)
	check(Shop.item_meets(o, it), "the exact piece meets the multi-part commission")
	eq(Shop.fulfil(str(o["id"]), int(it["uid"])), "", "the commission is delivered")


# ------------------------------------------------------------------ Hall of Fame
func test_hall_of_fame_records() -> void:
	fresh_game()
	give("ingot_iron", 6)
	give("leather_cured", 3)
	var it := craft("iron_longsword", 119.0, {"edge": 15, "temper": 10, "fortune": 60})
	check(not it.is_empty() and float(it["quality"]) >= 112.0, "an exceptional sword is forged (%.1f%%)" % float(it.get("quality", 0)))
	var crafts := Recognition.of_kind("craft")
	check(crafts.any(func(e): return int(e["refs"].get("uid", -1)) == int(it["uid"])), "exceptional work is on the Hall of Fame")
	var plain := craft("iron_longsword", 80.0)
	check(not Recognition.of_kind("craft").any(func(e): return int(e["refs"].get("uid", -1)) == int(plain.get("uid", -2))), "ordinary work is not")
	# a legendary discovery through the chronicle
	Chronicle.add("discovery", "Mira brought home a legendary relic from the barrows.", {"adv": "mira"}, true)
	check(not Recognition.of_kind("discovery").is_empty(), "a legendary discovery is honoured")
	# a customer comments on the board
	check(Recognition.customer_comment("martha") != "", "a customer remarks on the board")
	check(save_load("suite_recog_hof"), "save/load")
	check(Recognition.of_kind("craft").size() >= 1 and Recognition.of_kind("discovery").size() >= 1, "the Hall of Fame survives save/load")


# ------------------------------------------------------------------ Epic + ceremony
func _boss_fight(aid: String, uid: int) -> void:
	var a := Adv.get_a(aid)
	Expeditions.ensure(a)
	a["status"] = "away"
	a["hp"] = a["hp_max"]
	var e := {"id": "exp_test", "party": [aid], "leader": aid, "dest": "barrow_fields", "journal": [], "encounters": []}
	var rec := {"boss": true, "enemies": [{"kind": "undead", "name": "The Barrow King", "key": "e0"}],
		"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": aid, "weapon_uid": uid, "hit": true}]}
	Expeditions._boss_down(e, {"name": "The Barrow Hall"}, rec)
	a["status"] = "in_town"


func test_epic_on_boss_kill() -> void:
	fresh_game()
	var aid := _in_town_adv()
	if not check(aid != "", "an adventurer is in town"):
		return
	give("ingot_iron", 6)
	give("leather_cured", 3)
	var it := craft("iron_longsword", 100.0)
	if not check(not it.is_empty(), "a blade is forged"):
		return
	var rar := str(it["rarity"])
	var stats: Dictionary = it["stats"].duplicate(true)
	var v0 := Items.value(it)
	var rep0 := Shop.reputation()
	Adv.give_item(Adv.get_a(aid), Game.take_uid(int(it["uid"])), 0)
	_boss_fight(aid, int(it["uid"]))
	var w := Game.find_uid_anywhere(int(it["uid"]))
	check(w.has("epic"), "the blade earned Epic distinction")
	eq(str(w["rarity"]), rar, "the underlying rarity is unchanged")
	eq(w["stats"]["attack"], stats["attack"], "the stats are unchanged")
	check(Items.value(w) > v0, "an Epic piece is worth more (%d > %d)" % [Items.value(w), v0])
	check(Shop.reputation() > rep0, "the smith's reputation rose")
	check(Items.tooltip(w).contains("EPIC"), "the tooltip carries the Epic line")
	check(Items.display_name(w).contains("✦"), "the name carries the Epic mark")
	check(not Recognition.of_kind("epic").is_empty() and not Recognition.of_kind("deed").is_empty(), "the deed and the Epic are on the Hall of Fame")
	check((w.get("history", []) as Array).any(func(h): return str(h["text"]).contains("Epic")), "the history records the distinction")
	# a non-smith weapon earns nothing
	var foreign := Items.make("sword_iron", {"quality": 80.0})
	var b := ""
	for x in Adv.all().values():
		if x["id"] != aid and x["status"] == "in_town":
			b = x["id"]
	if b != "":
		Adv.give_item(Adv.get_a(b), foreign, 0)
		_boss_fight(b, int(foreign["uid"]))
		check(not Game.find_uid_anywhere(int(foreign["uid"])).has("epic"), "a blade the smith did not make earns no Epic")
	# the ceremony is booked for tomorrow at noon, with an invitation marker
	var c := Ceremony.state()
	eq(str(c.get("status", "")), "scheduled", "a ceremony is scheduled")
	eq(int(c.get("day", 0)), Game.day() + 1, "for the next day")
	check(TalkMarkers.wants_to_talk(aid) != "", "the adventurer carries the invitation marker")
	check(save_load("suite_recog_epic"), "save/load")
	check(Game.find_uid_anywhere(int(it["uid"])).has("epic") and Ceremony.scheduled(), "Epic and ceremony survive save/load")


func test_ceremony_attend_and_miss() -> void:
	fresh_game()
	var aid := _in_town_adv()
	Ceremony.schedule(aid, -1, "slew a wyvern")
	var spots := {"square_0": Vector2(100, 100), "square_1": Vector2(200, 100), "square_2": Vector2(300, 100), "square_3": Vector2(100, 200),
		"square_4": Vector2(200, 200), "square_5": Vector2(300, 200), "well": Vector2(0, 0), "notice": Vector2(0, 50)}
	eq(Ceremony.spot_for(aid, spots), "", "nobody gathers before the day")
	days(1)
	Game.advance_minutes(Ceremony.NOON * 60 + 10 - int(Game.state["minute"]))
	check(Ceremony.gathering(), "the square gathers at noon")
	eq(Ceremony.spot_for(aid, spots), "square_0", "the honoured adventurer stands at the podium (square fallback)")
	check(Ceremony.spot_for("martha", spots).begins_with("square_") or Ceremony.spot_for("martha", spots) in ["well", "notice"], "villagers gather in the square")
	spots["square_podium"] = Vector2(150, 150)
	eq(Ceremony.spot_for(aid, spots), "square_podium", "the podium spot is used when it exists")
	var r0 := Ceremony.smith_renown()
	var rep0 := Shop.reputation()
	var res := Ceremony.attend()
	check(not res.is_empty() and str(Ceremony.state()["status"]) == "held", "the smith attends")
	check(Ceremony.smith_renown() > r0 and Shop.reputation() > rep0, "renown and reputation rise")
	check(not Recognition.of_kind("ceremony").is_empty(), "the ceremony is on the Hall of Fame")
	eq(Ceremony.scene_lines().size(), 5, "the scene has its lines")
	# a missed ceremony is held without the smith
	Ceremony.schedule(aid, -1, "found the lost relic")
	days(2)
	Ceremony.update()
	eq(str(Ceremony.state()["status"]), "missed", "a ceremony nobody attended is marked missed")
