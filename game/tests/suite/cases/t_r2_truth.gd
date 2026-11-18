## R2 "Truthful World Model" — one danger model, one reputation entry point, truthful plans, honest rumours, real
## possessions, one valuation interface and honest stats (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R2).
extends SuiteCase

const SMOKE := ["test_one_danger_entry_point", "test_reputation_facade_preserves_standing", "test_plan_is_the_planners_and_pure",
	"test_rumours_state_real_facts"]


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	Shop.remove_customer(id)
	return a


## Every script, except the files allowed to, must not contain `needle`.
func _only_in(needle: String, allowed: Array) -> Array:
	var bad := []
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for sub in d.get_directories():
			stack.append(dir + "/" + sub)
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var path := dir + "/" + f
			if allowed.has(path.get_file()):
				continue
			if FileAccess.get_file_as_string(path).contains(needle):
				bad.append(path)
	return bad


# ------------------------------------------------------------------ 1. danger
func test_one_danger_entry_point() -> void:
	eq(_only_in("Expeditions.rating(", ["danger.gd"]), [], "only Danger reads the live site strength (Expeditions.rating)")
	eq(_only_in("Regions.danger(", []), [], "nothing calls the old Regions.danger directly")
	eq(_only_in("WorldSites.danger(", []), [], "nothing calls WorldSites.danger directly")
	eq(_only_in("WorldSites.danger_word(", []), [], "nothing calls WorldSites.danger_word directly")
	eq(_only_in("DB.destinations.get(rid, {}).get(\"threats\"", []), [], "advice no longer reads destinations.json threats")
	for rid in ["whisperwood", "barrow_fields", "weeping_fortress"]:
		eq(Danger.site(rid), Expeditions.rating(rid), "%s: Danger.site is the live strength" % rid)
		eq(WorldSites.danger(rid), Danger.site(rid), "%s: the old name agrees" % rid)


func test_trip_danger_matches_the_old_model_on_an_unchanged_place() -> void:
	for d in DB.destinations:
		var old := float(DB.destinations[d].get("danger", 1)) * (1.0 - 0.3 * Regions.scouted(str(d)) / Regions.SCOUT_MAX)
		check(absf(Danger.trip(str(d)) - old) < 0.001, "%s: an unchanged place keeps its trip danger (%.2f)" % [d, old])


func test_live_state_moves_trip_danger() -> void:
	var rid := "whisperwood"
	var t0 := Danger.trip(rid)
	WorldSites.site(rid)["threat"] = 2.0
	check(Danger.site_scale(rid) > 1.0 and Danger.trip(rid) > t0, "growing threats there make a hireling's trip more dangerous (%.2f → %.2f)" % [t0, Danger.trip(rid)])
	WorldSites.site(rid)["threat"] = 0.0
	WorldSites.site(rid)["boss"]["alive"] = false
	check(Danger.trip(rid) <= t0, "with the master slain it is no more dangerous than it started")
	var names := Danger.threats(rid).map(func(t): return str(t["id"]))
	check(not names.has(str(WorldSites.info(rid).get("boss", "_none_"))), "the slain master is not among the threats advice names")


func test_scouting_helps_parties_truly() -> void:
	var rid := "highmarsh_road"
	var dc0 := Danger.ambush_dc(rid)
	Regions.add_scouting(rid, Regions.SCOUT_MAX)
	eq(Danger.knowledge(rid), 1.0, "well charted")
	eq(Danger.ambush_dc(rid), dc0 - Danger.AMBUSH_DC_MAX, "a party's scout spots foes first more easily there (DC %d → %d)" % [dc0, Danger.ambush_dc(rid)])
	check(Danger.trip(rid) < float(DB.destinations[rid]["danger"]), "and hirelings' trips there are safer")


func test_consult_threats_are_the_foes_fought() -> void:
	var rid := "barrow_fields"
	var fought := {}
	for n in Expeditions.region(rid).get("nodes", []):
		for spec in WorldSites.enemies_at(rid, n):
			fought[str(spec[0])] = true
	var advised := Consult.threats(rid).map(func(t): return str(t["id"]))
	advised.sort()
	var keys := fought.keys()
	keys.sort()
	eq(advised, keys, "consultation advice names exactly the foes parties meet there")


# ------------------------------------------------------------------ 2. reputation
func test_reputation_facade_preserves_standing() -> void:
	eq(_only_in("[\"world\"][\"rep\"]", ["reputation.gd"]), [], "no script reads the old world.rep")
	eq(_only_in("get(\"rep\", 0.0)", ["reputation.gd"]), [], "no script reads world.rep lazily either")
	for old_name in ["Shop.reputation(", "Shop.rep_change(", "Shop.reputation_word("]:
		eq(_only_in(old_name, []), [], "no script calls %s… — every system asks Reputation" % old_name)
	eq(Reputation.AUDIENCES, ["villagers", "adventurers", "traders", "artisans", "nobility"], "the audiences of decision D-7")
	eq(Reputation.PLACES, ["village", "region"], "the places of decision D-7 (civilizations come later)")
	var tot := 0.0
	var n := 0
	for npc in Game.state["social"]:
		if str(DB.character(npc).get("kind", "")) in ["adventurer", "villager"]:
			tot += float(Game.state["social"][npc]["aff"])
			n += 1
	Reputation.change(12.0)
	var old := clampf(tot / maxf(1.0, n) * 0.8 + 12.0, -100.0, 100.0)
	check(absf(Reputation.standing() - old) < 0.001, "the general standing is the old formula (%.2f)" % old)
	eq(Shop.reputation(), Reputation.standing(), "the old name reads the facade")
	for a in Reputation.AUDIENCES:
		eq(Reputation.word(a, "village"), 12.0, "%s in the village heard it" % a)
		eq(Reputation.word(a, "region"), 0.0, "%s in the region heard nothing yet (spreading is R8)" % a)


func test_reputation_migration_step_10() -> void:
	var data := {"world": {"rep": 37.5}, "version": 9}
	eq(Reputation.migrate(data), 1, "an older save's world.rep is moved")
	check(not (data["world"] as Dictionary).has("rep"), "the old key is gone (one truth)")
	for a in Reputation.AUDIENCES:
		eq(float(data["reputation"]["word"][a]["village"]), 37.5, "%s in the village keeps what it had heard" % a)
	var snap := JSON.stringify(data)
	eq(Reputation.migrate(data), 0, "running it again moves nothing")
	eq(JSON.stringify(data), snap, "and changes nothing")


# ------------------------------------------------------------------ 3. truthful characters
func test_plan_is_the_planners_and_pure() -> void:
	var a := _adv("garrick")
	seed(4711)
	var r0 := randi()
	seed(4711)
	var plan := Adv.current_plan(a)
	eq(randi(), r0, "reading a plan uses no randomness (the world does not change by looking)")
	var pre := Expeditions.choose_destination([a], true)
	eq(str(plan.get("dest", "")), str(pre.get("dest", "")), "the plan is the live planner's preview")
	check(str(plan.get("dest", "")) != "", "they lean somewhere (%s)" % plan.get("dest", ""))
	check(not bool(plan.get("committed", true)), "a lean, not a commitment")
	# their own wish weighs on the planner (+6 when they lead) and so is part of the plan shown — not shown as the plan
	a["next_dest"] = "barrow_fields"
	var with_wish := Expeditions.choose_destination([a], true)
	eq(str(Adv.current_plan(a).get("dest", "")), str(with_wish.get("dest", "")), "the shown plan includes their wish's pull")
	Adv.plan_next(a)
	eq(str(a.get("next_dest", "")), "barrow_fields", "a wish, once made, is kept (the pre-R2 rule, unchanged)")
	a.erase("next_dest")
	a["planned_dest"] = "whisperwood"
	Adv.plan_next(a)
	eq(str(a.get("next_dest", "")), "whisperwood", "a story plan (planned_dest) becomes their wish")


## The wish list says "the things there fear fire": whenever the (pre-R2) rule names a weakness, at least two kinds of
## foe really at that place share it — at the start and after a season of play.
func test_wish_list_claims_are_true() -> void:
	var a := _adv("garrick")
	for k in ["fire", "frost"]:
		a["equipment"]["weapon"] = {}
	for rnd in 2:
		if rnd == 1:
			for i in 60:
				Game.advance_minutes(1440)
		for dest in DB.destinations:
			var w := Adv.wish_prop(a, str(dest))
			if w == "":
				continue
			var n := 0
			for th in Danger.threats(str(dest)):
				if str(th.get("weak", "")) == w:
					n += 1
			check(n >= 2, "day %d: wanting %s for %s is true — %d kinds of foe there fear it" % [Game.day(), w, dest, n])


func test_party_destination_is_shown_as_committed() -> void:
	var a := _adv("mira")
	Expeditions.st()["parties"]["p_r2"] = {"id": "p_r2", "members": ["mira"], "leader": "mira", "dest": "sunken_temple", "goal": "explore"}
	var plan := Adv.current_plan(a)
	eq(str(plan["dest"]), "sunken_temple", "a forming party's destination is the plan")
	check(bool(plan["committed"]), "and it is committed")
	Expeditions.st()["parties"].erase("p_r2")


func test_consult_never_redirects_a_sponsored_party() -> void:
	var a := _adv("tomas")
	Expeditions.st()["parties"]["p_sp"] = {"id": "p_sp", "members": ["tomas"], "leader": "tomas", "dest": "weeping_fortress",
		"goal": "sponsored", "sponsor": "sp_1"}
	check(Consult.sponsored(a), "Tomas's party is on the smith's sponsored expedition")
	for rec in Consult.recommendations(a):
		check(str(rec.get("kind", "")) != "dest", "no advice offers to send it elsewhere (%s)" % rec.get("title", ""))
	var res := Consult._apply(a, {"kind": "dest", "dest": "whisperwood", "avoid": "weeping_fortress", "title": "test"})
	check(str(res).begins_with("!"), "applying such advice is refused (%s)" % res)
	eq(str(Expeditions.st()["parties"]["p_sp"]["dest"]), "weeping_fortress", "the agreed objective stands")
	Expeditions.st()["parties"].erase("p_sp")


func test_strength_word_uses_the_expedition_formula() -> void:
	var a := _adv("pip")
	var p := Expeditions.power(a)
	var want := "Legendary"
	for b in Adv.RATING_BANDS:
		if p < float(b[0]):
			want = str(b[1])
			break
	eq(Adv.rating_text(a), want, "the sheet's word follows the strength decisions use (%.1f)" % p)


# ------------------------------------------------------------------ 4. honest rumours
func test_rumours_state_real_facts() -> void:
	var a := _adv("varn")
	var w: Dictionary = a["equipment"].get("weapon", {})
	if not w.is_empty() and w["stats"].has("durability_max"):
		w["stats"]["durability"] = 1
	for f in Talk.rumour_facts():
		var adv: Dictionary = f.get("adv", {})
		match str(f["kind"]):
			"plan":
				eq(str(f["dest"]), WorldSites.name_of(Adv.choose_dest(adv)), "%s's plan is their real lean" % adv["name"])
			"worn":
				check(Shop.worn_slot(adv) != "", "%s really has a worn piece" % adv["name"])
			"away":
				check(str(adv["status"]) == "away" and not Expeditions.exp_of(str(adv["id"])).is_empty(), "%s really is away" % adv["name"])
			"hurt":
				eq(str(adv["status"]), "injured", "%s really is hurt" % adv["name"])
			"flush":
				check(int(adv.get("gold", 0)) >= 250, "%s really is flush" % adv["name"])
	check(Talk.rumour_facts().any(func(f): return str(f["kind"]) == "worn" and str(f["adv"]["id"]) == "varn"), "Varn's worn weapon is talked about")
	for t in DB.dialogue["rumours"]:
		check(not str(DB.dialogue["rumours"][t]).contains("limps when they think nobody"), "the old invented templates are gone")


func test_table_talk_names_the_real_place_of_death() -> void:
	var a := _adv("kestra")
	a["status"] = "dead"
	a["died_day"] = Game.day()
	a["died_where"] = "the Sunken Temple"
	check(InnLife.table_talk().contains("the Sunken Temple took a good one") or InnLife.table_talk().contains("Sunken Temple"), "the room names where they really fell")
	check(not InnLife.table_talk().contains("The barrows took"), "not the barrows for every death")


# ------------------------------------------------------------------ 5. real possessions
func test_gifts_come_from_real_possessions() -> void:
	var a := _adv("elowen")
	Game.add_gold(200, "sales", "Sold Elowen a blade", "elowen")
	a["loot"] = []
	a["gold"] = 0
	eq(Sim.gift_of("elowen"), {}, "nothing in her pack and no coin: no gift")
	var spare := Items.make("dagger", {"quality": 70.0})
	a["loot"] = [spare]
	var g := Sim.gift_of("elowen")
	eq((g.get("items", []) as Array).size(), 1, "a piece from her own pack")
	eq(int(g["items"][0]["uid"]), int(spare["uid"]), "the very piece she carried")
	check(not (a["loot"] as Array).has(spare), "and it is no longer in her pack")
	a["gold"] = 300
	var g2 := Sim.gift_of("elowen")
	if g2.has("gold"):
		check(int(a["gold"]) == 300 - int(g2["gold"]), "a coin gift leaves her purse")
	eq(Sim.gift_of("hilde"), {}, "a villager with nothing simulated to give gives nothing")


func test_shopkeeper_gift_comes_off_the_shelf() -> void:
	Game.add_gold(200, "sales", "Aldric's business", "aldric")
	var before := 0
	for e in Trade.store_stock("general_store"):
		before += int(e["qty"])
	var g := Sim.gift_of("aldric")
	if check(not (g.get("items", []) as Array).is_empty(), "Aldric gives something from his own counter"):
		var after := 0
		for e in Trade.store_stock("general_store"):
			after += int(e["qty"])
		eq(after, before - int(g["items"][0]["qty"]), "and it is no longer for sale")


func test_spare_part_is_a_real_piece() -> void:
	var a := _adv("sigrun")
	for s in a["equipment"]:
		var it: Dictionary = a["equipment"][s]
		if it.get("stats", {}).has("durability_max"):
			it["stats"]["durability"] = int(it["stats"]["durability_max"])
	a["loot"] = []
	a["gold"] = 500
	eq(Shop.worn_spare(a), {}, "nothing worn in her pack")
	var parts := Shop.multi_parts_for(a)
	check(not parts.any(func(p): return str(p.get("kind", "")) == "repair"), "so no spare is invented for repair")
	var sp := Items.make("sword_iron", {"quality": 70.0})
	sp["stats"]["durability"] = 2
	a["loot"] = [sp]
	eq(Shop.worn_spare(a), sp, "her own worn spare")
	var parts2 := Shop.multi_parts_for(a)
	var rep := {}
	for p in parts2:
		if str(p.get("kind", "")) == "repair":
			rep = p
	if check(not rep.is_empty(), "the repair part is her real spare"):
		eq(int(rep["loot_uid"]), int(sp["uid"]), "it names the piece in her pack")
		Shop.customers().append({"npc": "sigrun", "want": "multi", "parts": parts2, "present": true})
		Shop.repair_part("sigrun", "rep", 90.0)
		check(int(sp["stats"]["durability"]) > 2, "the repair mends the piece in her pack")


func test_pawn_house_stock_claims_no_pledge() -> void:
	for e in Commerce.house_stock():
		for h in e["item"].get("history", []):
			check(not str(h.get("text", h)).contains("unredeemed"), "no invented pledge history")


# ------------------------------------------------------------------ 6. valuation
func test_one_valuation_interface() -> void:
	eq(Trade.price_factor(), Valuation.smith_buys_factor(), "the import desk's factor is the shared one")
	eq(Commerce.price_factor(), Valuation.smith_buys_factor(), "the merchants' factor is the same (no more verbatim copy)")
	eq(Shop.buyer_factor(), Valuation.buyers_factor(), "buyers pay by the shared factor")
	eq(Valuation.merchant_price("ore_iron", 1.5), maxi(1, int(round(float(DB.item("ore_iron")["value"]) * 1.5 * Valuation.smith_buys_factor()))), "a merchant's price")
	var it := Items.make("potion_healing", {"qty": 3})
	eq(Commerce.unit_value(it) * 3, Valuation.value(it), "a unit of a stack")


func test_material_cost_is_one_rule() -> void:
	var rid := "iron_longsword"
	var cost := Valuation.design_material_cost(rid)
	var manual := 0
	var inputs: Dictionary = DB.recipe(rid)["inputs"]
	for d in inputs:
		var cp := Valuation.counter_price(str(d))
		manual += int(inputs[d]) * (int(cp["price"]) if not cp.is_empty() else int(DB.item(str(d)).get("value", 5)))
	eq(cost, manual, "a Design's materials cost what the counters charge (else the catalogue value)")
	var est := Apprentices.estimate({"kind": "craft", "recipe": rid, "repeat": 1, "done": 0})
	eq(int(est.get("cost", -1)), cost, "the Workshop Ledger shows the cost the steward plans with")


# ------------------------------------------------------------------ 7. honest stats
func test_stats_with_no_effect_are_labelled() -> void:
	var ring := Items.make("ring_silver", {"quality": 80.0})
	ring["affixes"].append({"id": "fortune", "stat": "luck", "value": 5})
	check(not Items.stat_in_play(ring, "luck"), "luck changes nothing in play")
	check(Items.tooltip(ring).contains(Items.NO_EFFECT_NOTE), "the tooltip says so")
	var amulet := Items.make("amulet_silver") if not DB.item("amulet_silver").is_empty() else {}
	if not amulet.is_empty():
		check(Items.stat_in_play(amulet, "vitality"), "vitality on an amulet adds hit points")
	var boots := Items.make("boots_leather")
	check(not Items.stat_in_play(boots, "vitality"), "vitality on boots does not")
	boots["affixes"].append({"id": "haste", "stat": "speed", "value": 6})
	check(not EquipmentSheet.key_stats(boots).contains("Spd"), "a sheet's key stats leave out what has no effect")
	for s in ["attack", "protection", "magic", "fire", "frost", "ward", "heal"]:
		check(Items.stat_in_play(boots, s), "%s is in play" % s)
