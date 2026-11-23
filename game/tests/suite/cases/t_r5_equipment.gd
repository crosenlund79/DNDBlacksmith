## R5 "Equipment Depth": every affix changes a real outcome (a seeded combat comparison), sets reward matched pieces,
## an arcanist enchants an existing piece without changing its identity ("the famous sword returns"), a warned
## experiment can fail and its history endures ("the cost of ambition"), nothing is destroyed without the warning, and
## the Unique / Epic rules (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R5 acceptance).
extends SuiteCase

const SMOKE := ["test_each_affix_changes_outcomes", "test_nothing_is_destroyed_without_the_warning"]


func _fighter(id := "") -> Dictionary:
	var a := Adv.get_a(id if id != "" else str(Adv.all().keys()[0]))
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["equipment"] = {"weapon": Items.make("sword_iron", {"quality": 80.0}), "armor": Items.make("cuirass_iron", {"quality": 80.0})}
	a["hp"] = Expeditions.hp_max(a)
	return a


func _foe() -> Dictionary:
	return {"name": "Test Brute", "key": "f0", "hp": 9999, "ac": 12, "atk": 6, "dmg": "2d6", "kind": "beast", "weak": "", "resist": ""}


func _affix(it: Dictionary, id: String, value: int) -> void:
	var stat := ""
	for a in Items.AFFIXES:
		if str(a["id"]) == id:
			stat = str(a["stat"])
	(it["affixes"] as Array).append({"id": id, "stat": stat, "value": value})


## n exchanges (the fighter attacks, the foe strikes back), seeded: what happened.
func _bout(a: Dictionary, n: int, sd: int) -> Dictionary:
	Rng.reseed(sd)
	var f := _foe()
	var rec := {"actions": []}
	var out := {"dealt": 0, "crits": 0, "taken": 0, "foe_hits": 0, "healed": 0, "foe_lost": 0}
	for i in n:
		a["hp"] = Expeditions.hp_max(a) - 5
		var hp0 := int(f["hp"])
		Expeditions._attack(a, f, rec, i, false, false)
		var act: Dictionary = rec["actions"][-1]
		out["dealt"] += int(act.get("dmg", 0))
		out["crits"] += 1 if bool(act.get("crit", false)) and bool(act.get("hit", false)) else 0
		out["healed"] += int(act.get("leech", 0))
		var hpa := int(a["hp"])
		var fh := int(f["hp"])
		Expeditions._enemy_attack(f, a, rec, i)
		var act2: Dictionary = rec["actions"][-1]
		out["taken"] += hpa - int(a["hp"])
		out["foe_hits"] += 1 if bool(act2.get("hit", false)) else 0
		out["foe_lost"] += fh - int(f["hp"])
		f["hp"] = 9999
	return out


# ------------------------------------------------------------------ 1. every affix changes outcomes
func test_each_affix_changes_outcomes() -> void:
	fresh_game()
	var a := _fighter()
	var base := _bout(a, 300, 777)
	var cases := [
		["keen", "weapon", 4, "crits", 1], ["embers", "weapon", 5, "dealt", 1], ["haste", "weapon", 10, "dealt", 1],
		["leech", "weapon", 3, "healed", 1], ["frost", "weapon", 5, "foe_hits", -1], ["warded", "armor", 4, "taken", -1],
		["thorns", "armor", 3, "foe_lost", 1]]
	for c in cases:
		a = _fighter()
		_affix(a["equipment"][c[1]], c[0], c[2])
		var r := _bout(a, 300, 777)
		var d := int(r[c[3]]) - int(base[c[3]])
		check(d * int(c[4]) > 0, "%s changes %s over 300 seeded exchanges (%d → %d)" % [c[0], c[3], int(base[c[3]]), int(r[c[3]])])
	# vigor: hit points from any piece
	a = _fighter()
	var hp0 := Expeditions.hp_max(a)
	_affix(a["equipment"]["armor"], "vigor", 8)
	eq(Expeditions.hp_max(a), hp0 + 8, "vigor on armour adds 8 hit points (before R5 only an amulet did)")
	# bear: the piece wears at half the rate
	a = _fighter()
	var w0: Dictionary = a["equipment"]["weapon"]
	_affix(w0, "bear", 20)
	var d0 := int(w0["stats"]["durability"])
	Expeditions.wear_item(a, "weapon", 10)
	eq(d0 - int(w0["stats"]["durability"]), 5, "the Bear wears at half the rate (10 → 5)")
	# sage: spells strike truer
	a = _fighter()
	a["equipment"]["armor"] = Items.make("cuirass_iron", {"quality": 80.0})
	var ring := Items.make("ring_silver", {"quality": 80.0})
	a["equipment"]["ring"] = ring
	check(not GearDepth.has_fx(a, "sage"), "without a Sage's piece")
	_affix(ring, "sage", 3)
	check(GearDepth.has_fx(a, "sage"), "with one, the spell to-hit gains +1 (read in Expeditions._attack)")
	# fortune: one more piece from the spoils
	var e := {"id": "exp_t", "dest": "whisperwood", "party": [str(a["id"])], "loot": []}
	a = _fighter(str(a["id"]))
	Rng.reseed(55)
	var plain := 0
	for i in 200:
		e["loot"] = []
		Expeditions._loot(e, "barrow", 1)
		plain += (e["loot"] as Array).size()
	_affix(a["equipment"]["armor"], "fortune", 9)
	a["equipment"]["ring"] = Items.make("ring_silver", {"quality": 80.0})
	_affix(a["equipment"]["ring"], "fortune", 9)
	Rng.reseed(55)
	var lucky := 0
	for i in 200:
		e["loot"] = []
		Expeditions._loot(e, "barrow", 1)
		lucky += (e["loot"] as Array).size()
	check(lucky > plain, "fortune brings more finds over 200 spoils (%d → %d)" % [plain, lucky])
	# stalwart: grief costs half the morale
	var b := _fighter(str(Adv.all().keys()[1]))
	var c2 := _fighter(str(Adv.all().keys()[2]))
	b["morale"] = 80.0
	c2["morale"] = 80.0
	b["status"] = "away"
	c2["status"] = "away"
	_affix(c2["equipment"]["armor"], "stalwart", 3)
	var dead := _fighter(str(Adv.all().keys()[3]))
	var e2 := {"id": "exp_g", "dest": "whisperwood", "party": [dead["id"], b["id"], c2["id"]], "journal": []}
	Expeditions._kill(e2, dead, "the woods")
	check(80.0 - float(c2["morale"]) < 80.0 - float(b["morale"]), "the stalwart grieves with half the loss (%.1f vs %.1f)" % [80.0 - float(c2["morale"]), 80.0 - float(b["morale"])])


# ------------------------------------------------------------------ 2. sets
func test_sets_reward_matched_pieces() -> void:
	fresh_game()
	var a := _fighter()
	var p0 := Expeditions.total(a, "protection")
	var s := Items.make("sword_steel", {"quality": 90.0})
	var cu := Items.make("cuirass_steel", {"quality": 90.0})
	var sh := Items.make("shield_tower", {"quality": 90.0})
	for it in [s, cu, sh]:
		Provenance.forged(it)
	a["equipment"] = {"weapon": s, "armor": cu}
	eq(int(GearDepth.sets_worn(a).get("hearthguard", 0)), 2, "two matched Hearthguard pieces from one forge")
	check(Expeditions.total(a, "protection") >= Items.stat(cu, "protection") + 4, "+4 protection for the pair")
	var other := Items.make("shield_tower", {"quality": 90.0})
	Provenance.forged(other, {"id": "app_z", "name": "Another hand", "mark": "app_z"})
	a["equipment"]["shield"] = other
	eq(int(GearDepth.sets_worn(a).get("hearthguard", 0)), 2, "a shield from another maker does not complete the set")
	a["equipment"]["shield"] = sh
	eq(int(GearDepth.sets_worn(a).get("hearthguard", 0)), 3, "the matched shield does")
	a["hp"] = 5
	var f := _foe()
	f["atk"] = 99
	f["dmg"] = "10d10"
	var rec := {"actions": []}
	Expeditions._enemy_attack(f, a, rec, 0)
	eq(int(a["hp"]), 1, "the Hearthguard stands fast: a felling blow leaves them at 1")
	Expeditions._enemy_attack(f, a, rec, 1)
	check(int(a["hp"]) <= 0, "but only once a fight")


# ------------------------------------------------------------------ 3. the famous sword returns (journey)
func _workshop() -> void:
	fresh_game()
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")   # the spellbinding array stands in the Arcane Foundry
	Game.state["gold"] = 20000


func test_the_famous_sword_returns() -> void:
	_workshop()
	var arc := Apprentices.dev_take_on("arcanist", 9, "journeyman", "Ysolde Marr")
	check(not arc.is_empty(), "an arcanist is on the staff")
	var sword := craft("iron_longsword", 96.0)
	var uid := int(sword["uid"])
	var maker0 := JSON.stringify(Provenance.maker(sword))
	var ids := Adv.all().keys()
	var hero := _fighter(str(ids[0]))
	var heir := _fighter(str(ids[1]))
	Game.take_uid(uid)
	Provenance.transfer(sword, str(hero["id"]), "sold")
	hero["equipment"]["weapon"] = sword
	Recognition.on_boss_down(str(hero["id"]), sword, "the Test Wight", "the Barrow Fields")
	check(sword.has("epic"), "the sword earns Epic for the killing blow")
	hero["status"] = "away"
	heir["status"] = "away"
	heir["equipment"]["weapon"] = Items.make("dagger", {"quality": 30.0})
	Expeditions._kill({"id": "exp_f", "dest": "barrow_fields", "party": [hero["id"], heir["id"]], "journal": []}, hero, "the barrow mouth")
	Adv.bequeath(hero, [heir["id"]], "barrow_fields", "the Barrow Fields")
	eq(int(heir["equipment"]["weapon"].get("uid", -1)), uid, "the heir takes it up")
	# years on, the heir brings it to the forge; the arcanist binds a deep property into the very same piece
	heir["equipment"].erase("weapon")
	Provenance.transfer(sword, Provenance.SMITH_ID, "returned", "brindlewick", "%s brought %s to the forge." % [heir["name"], sword["name"]])
	Game.add_item(sword, false)
	give("infusion_aether", 2)
	give("thread_ethereal", 2)
	var r := Refinement.perform(uid, "enchant", 95.0, {"target": "lambent"})
	check(bool(r.get("ok", false)) and str(r.get("outcome", "")) == "success", "the arcanist enchants it: %s" % str(r.get("text", r)))
	var it := Game.find_uid(uid)
	eq(int(it.get("uid", -1)), uid, "the same uid")
	eq(JSON.stringify(Provenance.maker(it)), maker0, "the same maker")
	check(it.has("epic"), "its Epic history stays")
	check(Provenance.contributors(it).any(func(e): return str(e.get("profession", "")) == "arcanist"), "the arcanist is credited")
	check(Items.stat(it, "magic") >= 3, "and the property works (+%d magic)" % Items.stat(it, "magic"))
	# back into service
	Game.take_uid(uid)
	Provenance.transfer(it, str(heir["id"]), "given")
	heir["equipment"]["weapon"] = it
	check(save_load("r5_famous"), "saved and loaded")
	var it2 := ItemRegistry.find(uid)
	check(not it2.is_empty() and it2.has("epic") and not (it2.get("arcana", []) as Array).is_empty(), "after loading: Epic and arcana on the same piece")
	var kinds := Lore.of_item(uid).map(func(x): return str(x["kind"]))
	for k in ["forged", "sold", "epic", "inherited", "enchanted"]:
		check(kinds.has(k), "its story holds %s" % k)


# ------------------------------------------------------------------ 4. the cost of ambition (journey) and safety
func test_the_cost_of_ambition() -> void:
	_workshop()
	var outcomes := {}
	for i in 30:
		var it := craft("iron_longsword", 92.0)
		var uid := int(it["uid"])
		give("ingot_iron", 4)
		give("coal", 4)
		var p := Refinement.plan(it, "experiment")
		eq(str(p["risk"]["tier"]), "extraordinary", "the danger is stated before the decision")
		Rng.reseed(900 + i)
		var r := Refinement.perform(uid, "experiment", 20.0, {"warned": true})
		outcomes[str(r.get("outcome", ""))] = true
		if str(r["outcome"]) == "destroyed":
			check(Game.find_uid(uid).is_empty(), "the piece is gone")
			var tb := ItemRegistry.tombstone_of(uid)
			check(not tb.is_empty() and str(tb.get("cause", "")) == "destroyed", "its tombstone keeps it in history")
			check(Lore.of_item(uid).any(func(x): return str(x["kind"]) == "destroyed") and Lore.of_item(uid).any(func(x): return str(x["kind"]) == "forged"),
				"Lore keeps its forging and its end")
		elif str(r["outcome"]) == "fail":
			var w := Game.find_uid(uid)
			check(GearDepth.disabled(w) and Items.condition(w) == 0.0, "the piece is left unusable")
			check(Lore.of_item(uid).any(func(x): return str(x["kind"]) == "disabled"), "and its history says why")
		if outcomes.has("destroyed") and outcomes.has("fail"):
			break
	check(outcomes.has("destroyed") and outcomes.has("fail"), "a failed experiment can destroy or disable (%s)" % str(outcomes.keys()))


func test_nothing_is_destroyed_without_the_warning() -> void:
	_workshop()
	var arc := Apprentices.dev_take_on("arcanist", 6, "journeyman", "Ysolde Marr")
	var it := craft("iron_longsword", 92.0)
	it["epic"] = {"day": 1, "deed": "test", "adventurer": "", "kind": "deed", "deeds": []}
	var uid := int(it["uid"])
	give("ingot_iron", 30)
	give("ingot_steel", 30)
	give("coal", 30)
	give("reagent_salt", 30)
	give("infusion_aether", 10)
	give("thread_ethereal", 10)
	var r := Refinement.perform(uid, "experiment", 0.0, {})
	check(not bool(r.get("ok", false)) and str(r["text"]).contains("danger"), "an unwarned experiment is refused: %s" % r.get("text", ""))
	for a in ["refine", "rework", "upgrade", "reforge", "enchant", "attune"]:
		for q in [0.0, 5.0]:
			Refinement.perform(uid, a, q, {})
			check(not Game.find_uid(uid).is_empty(), "%s at %d%% never destroys an (Epic) piece" % [a, int(q)])
	check(not GearDepth.disabled(Game.find_uid(uid)), "nor leaves it unusable")


func test_dormant_arcana_and_attunement() -> void:
	_workshop()
	Apprentices.dev_take_on("arcanist", 7, "journeyman", "Ysolde Marr")
	var it := craft("iron_longsword", 90.0)
	var uid := int(it["uid"])
	give("infusion_aether", 4)
	give("thread_ethereal", 4)
	var m0 := Items.stat(it, "magic")
	var r := Refinement.perform(uid, "enchant", 47.0, {"target": "lambent"})
	eq(str(r["outcome"]), "partial", "a half-done binding: %s" % r.get("summary", ""))
	eq(Items.stat(it, "magic"), m0, "a dormant property does nothing")
	check(GearDepth.lines(it).any(func(l): return str(l).contains("dormant")), "and says so")
	var r2 := Refinement.perform(uid, "attune", 80.0, {})
	eq(str(r2["outcome"]), "success", "the arcanist attunes it")
	check(Items.stat(it, "magic") > m0, "now it works (+%d)" % (Items.stat(it, "magic") - m0))


func test_only_an_arcanist_enchants() -> void:
	_workshop()
	var it := craft("iron_longsword", 90.0)
	give("infusion_aether", 2)
	give("thread_ethereal", 2)
	var p := Refinement.plan(it, "enchant", {"target": "lambent"})
	check(not bool(p["ok"]) and str(p["why"]).contains("arcanist"), "without an arcanist: %s" % p["why"])


func test_second_rune_needs_a_runesmith() -> void:
	_workshop()
	var it := craft("iron_longsword", 90.0)
	give("runestone_ember", 2)
	check(Crafting.socket(int(it["uid"]), "runestone_ember", 90.0), "the first rune any smith can set")
	check(Crafting.socket_reason(it).contains("runesmith"), "the second needs a runesmith: %s" % Crafting.socket_reason(it))
	check(not Crafting.socket(int(it["uid"]), "runestone_ember", 90.0), "so it is refused")
	Apprentices.dev_take_on("runesmith", 6, "journeyman", "Edda Vell")
	check(Crafting.socket(int(it["uid"]), "runestone_ember", 90.0), "with a runesmith it is set")


# ------------------------------------------------------------------ 5. advice, Unique and Epic
func test_advice_to_refine_their_own_piece() -> void:
	_workshop()
	var a := _fighter()
	a["gold"] = 500
	a["equipment"]["weapon"] = Items.make("sword_iron", {"quality": 70.0})
	var w: Dictionary = a["equipment"]["weapon"]
	give("reagent_salt", 3)
	train("smithing", 8)
	var rec := Consult.refine_offer(a)
	check(not rec.is_empty(), "the smith can advise honing their own sword")
	var q0 := float(w["quality"])
	var g0 := Game.gold()
	var res := Consult._apply(a, rec)
	check(not str(res).begins_with("!"), "advice taken: %s" % res)
	check(is_same(a["equipment"]["weapon"], w), "they keep the very same piece")
	check(float(w["quality"]) >= q0, "refined (%d%% → %d%%)" % [int(q0), int(w["quality"])])
	check(Game.gold() > g0, "and they paid for the work")


func test_legacy_unique_copy_and_epic_for_any_maker() -> void:
	fresh_game()
	var g1 := Items.make("grimhold", {"quality": 90.0})
	var reg := Uniques._reg_w()
	reg["grimhold"] = {"authentic": int(g1["uid"]), "copies": [int(g1["uid"]) + 1000]}
	var copy := Items.make("grimhold", {"quality": 90.0})
	copy["uid"] = int(g1["uid"]) + 1000
	check(Items.display_name(copy).contains("contemporary copy"), "a legacy copy says what it is: %s" % Items.display_name(copy))
	check(not Items.display_name(g1).contains("copy"), "the authentic piece does not")
	var foreign := Items.make("sword_steel", {"quality": 85.0})
	Provenance.set_maker(foreign, "rival", "Harl Vosk", "rival", "highmarsh_road")   # made elsewhere, not at the Ironhand forge
	var rep0 := Reputation.standing()
	check(Recognition.grant_epic(foreign, "test deed", ""), "another maker's piece earns Epic (decision 16)")
	eq(Reputation.standing(), rep0, "but the smith's fame does not grow from it")
