## Run 0.1 — canonical corrections and critical integrity:
##   D13  a Unique artifact exists once per campaign (no new duplicates; old saves' duplicates kept whole and recorded);
##   D14  the four payment paths that did not conserve money now move it from one purse to another;
##   D18  renown is earned, never bought (a full purse is not renown);
##   the Chronicle/Lore split is preserved as documented until Gate J (characterisation only).
extends SuiteCase

const SMOKE := ["test_unique_minted_once_per_campaign", "test_payments_conserve_money"]
const FIXTURES := "res://tests/fixtures/saves/"


func _grimholds(items: Array) -> Array:
	return items.filter(func(x): return str(x.get("def", "")) == "grimhold")


# ------------------------------------------------------------------ D13: one authentic Unique
func test_unique_minted_once_per_campaign() -> void:
	fresh_game()
	seed(1301)
	check(Uniques.is_unique_def("grimhold") and not Uniques.is_unique_def("wyvernscale_pauldron"), "Grimhold is a Unique; the pauldron is a Set piece")
	check(Uniques.can_mint("grimhold") and not Game.state.has("uniques"), "a new campaign has minted nothing (and reading creates no state)")
	var rolls := []
	for i in 600:
		rolls.append(Loot.random_equipment("weapon", 200.0))
	var g := _grimholds(rolls)
	var p := rolls.filter(func(x): return str(x.get("def", "")) == "wyvernscale_pauldron")
	eq(g.size(), 1, "600 very lucky finds make exactly one Grimhold")
	check(p.size() > 1, "Set pieces may still recur (%d pauldrons)" % p.size())
	if g.is_empty():
		return
	eq(Uniques.authentic_uid("grimhold"), int(g[0]["uid"]), "the registry names that piece as the authentic Grimhold")
	check(Uniques.is_authentic(g[0]) and not Uniques.can_mint("grimhold"), "it is authentic; the campaign cannot mint another")
	# the piece is lost to the world: it still never respawns (D13: not after sale, loss or inheritance)
	var more := []
	for i in 600:
		more.append(Loot.random_equipment("any", 200.0))
	eq(_grimholds(more).size(), 0, "after it is gone, 600 more lucky finds make no second Grimhold")
	check(Uniques.audit().is_empty(), "the audit finds no unregistered Unique in the state")
	check(save_load("suite_run01_unique"), "save and load")
	eq(Uniques.authentic_uid("grimhold"), int(g[0]["uid"]), "the registry survives a reload")


func test_unique_not_minted_by_a_discarded_roll() -> void:
	fresh_game()
	var gh := Items.make("grimhold", {"quality": 100.0})
	check(Uniques.register(gh, "loot"), "a rolled Grimhold is registered as it is made")
	eq(Payments.gift_within([gh], 50), [], "a gift capped at 50 g cannot carry it")
	check(Uniques.can_mint("grimhold"), "a roll that never reached the world does not count as minted")
	var gh2 := Items.make("grimhold", {"quality": 100.0})
	Uniques.register(gh2, "loot")
	eq(Payments.gift_within([gh2], 100000).size(), 1, "a gift that can carry it keeps it")
	eq(Uniques.authentic_uid("grimhold"), int(gh2["uid"]), "the kept piece is the authentic one")


func test_migration_registers_legacy_duplicates_without_touching_them() -> void:
	fresh_game()
	var a: Dictionary = Adv.all().values()[0]
	var g1 := Items.make("grimhold", {"quality": 101.0})
	var g2 := Items.make("grimhold", {"quality": 95.0})
	var g3 := Items.make("grimhold", {"quality": 99.0})
	g2["owner"] = str(a["id"])
	a["equipment"]["weapon"] = g2
	Game.add_item(g1, false)
	(Game.state["exp"]["done"] as Array).append({"id": "exp_t01", "loot": [ItemRegistry.ref(g3)]})   # remembered only by a record
	var before := {}
	for it in [g1, g2]:
		before[int(it["uid"])] = JSON.stringify(it)
	var data: Dictionary = Game.state.duplicate(true)
	data["version"] = 3
	data.erase("uniques")
	var rep := SaveMigrations.run(data)
	eq(int(rep["to"]), Game.SAVE_VERSION, "a schema-3 save migrates to schema %d" % Game.SAVE_VERSION)
	check((rep["steps"] as Array).has("campaign Unique registry"), "the Unique registry step ran")
	var e: Dictionary = data["uniques"]["grimhold"]
	eq(int(e["uid"]), int(g1["uid"]), "the lowest uid (the first made) is the authentic Grimhold")
	var copies: Array = (e["copies"] as Array).map(func(u): return int(u))
	copies.sort()
	eq(copies, [int(g2["uid"]), int(g3["uid"])], "the later pieces (worn and recorded) are kept as legacy copies")
	eq(JSON.stringify(data["player"]["inventory"].filter(func(x): return int(x.get("uid", -1)) == int(g1["uid"]))[0]), before[int(g1["uid"])], "the authentic piece is untouched")
	eq(JSON.stringify(data["adventurers"][str(a["id"])]["equipment"]["weapon"]), before[int(g2["uid"])], "the adventurer's legacy copy is untouched (name, stats, rarity, owner)")
	var snap := JSON.stringify(data["uniques"])
	data["version"] = 3
	SaveMigrations.run(data)
	eq(JSON.stringify(data["uniques"]), snap, "running the step again changes nothing (idempotent)")
	check(Uniques.audit(data).is_empty(), "every Grimhold in the migrated save is accounted for")
	Game.state = data
	var rolls := []
	for i in 400:
		rolls.append(Loot.random_equipment("weapon", 200.0))
	eq(_grimholds(rolls).size(), 0, "a migrated campaign never mints another Grimhold")


func test_golden_saves_register_their_unique() -> void:
	for name in ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
		if not check(doc is Dictionary and (doc as Dictionary).get("data") is Dictionary, "%s is readable" % name):
			continue
		var data: Dictionary = Saves._restore_ints(doc["data"])
		var rep := SaveMigrations.run(data)
		eq(int(rep["to"]), Game.SAVE_VERSION, "%s migrates to the current schema" % name)
		check(Uniques.audit(data).is_empty(), "%s: every Unique piece is registered" % name)
		if name == "build-0.11.2":
			eq(int(data.get("uniques", {}).get("grimhold", {}).get("uid", -1)), 1069, "0.11.2: Sigrun's Grimhold (uid 1069) is the authentic one")
			eq((data["uniques"]["grimhold"]["copies"] as Array).size(), 0, "0.11.2: the expedition record refers to the same piece, not a copy")
			eq(str(data["adventurers"]["sigrun"]["equipment"]["weapon"]["name"]), "Grimhold, the Last Hammer", "0.11.2: Sigrun still carries it, unchanged")
		else:
			check(not data.has("uniques"), "%s: no Unique was ever minted, so no registry is written" % name)


# ------------------------------------------------------------------ D14: the four paths conserve money
func test_payments_conserve_money() -> void:
	fresh_game()
	Game.state["gold"] = 2000
	var ids := Adv.all().keys()
	ids.sort()
	# 1. a dispute refund reaches the adventurer's purse
	var a: Dictionary = Adv.get_a(str(ids[0]))
	a["status"] = "in_town"
	var piece := Items.make("sword_iron", {"quality": 70.0})
	Shop.raise_dispute(str(a["id"]), piece)
	var c := Shop.customer(str(a["id"]))
	if check(str(c.get("want", "")) == "dispute", "a dispute is raised"):
		var amount := int(c.get("refund", 20))
		var g0 := Game.gold()
		var p0 := int(a["gold"])
		Shop.settle_dispute(str(a["id"]), true)
		eq(Game.gold(), g0 - amount, "the refund leaves the smith's purse")
		eq(int(a["gold"]), p0 + amount, "… and reaches the adventurer's")
		eq(str(Game.state["ledger"][-1].get("party", "")), str(a["id"]), "the ledger line names them")
	# 2. the legacy resolver: the spouse's share comes out of her own spoils
	var s: Dictionary = Adv.get_a(str(ids[1]))
	Social.ensure(str(s["id"]))["romance"] = "married"
	eq(Social.spouse(), str(s["id"]), "the smith is married to %s" % s["name"])
	var ok := false
	for attempt in 30:
		seed(500 + attempt)
		s["status"] = "away"
		s.erase("exp")
		s["dest"] = str(DB.destinations.keys()[0])
		s["hp"] = int(s.get("max_hp", s.get("hp", 30)))
		var gs := Game.gold()
		var ps := int(s["gold"])
		Adv._resolve(s)
		if str(s.get("status", "")) == "dead":
			continue
		var smith_gain := Game.gold() - gs
		var her_gain := int(s["gold"]) - ps
		if smith_gain <= 0:
			continue
		ok = true
		eq(smith_gain, (smith_gain + her_gain) / 2, "the smith's share (%d g) is half of the spoils (%d g)" % [smith_gain, smith_gain + her_gain])
		check(her_gain >= smith_gain, "her purse keeps the other half (+%d g)" % her_gain)
		break
	check(ok, "a legacy expedition returned with spoils to share")
	# 3. a sponsorship still owed is paid later, to the company's members
	var m1 := str(ids[2])
	var m2 := str(ids[3])
	var sp := {"id": "sp_901", "status": "done", "who": "Test Company", "leader": m1, "party": [m1, m2], "paid": {},
		"result": {"owed": 50, "paid": 0, "creditors": [m1, m2]}}
	Sponsor.st()["list"]["sp_901"] = sp
	Game.state["gold"] = 30
	var q1 := int(Adv.get_a(m1)["gold"])
	var q2 := int(Adv.get_a(m2)["gold"])
	eq(Sponsor.settle_debts(), 30, "with 30 g in hand the smith pays 30 g of the 50 g owed")
	eq(Game.gold(), 0, "the smith's purse goes down by what he paid")
	eq(int(Adv.get_a(m1)["gold"]) + int(Adv.get_a(m2)["gold"]) - q1 - q2, 30, "the members' purses go up by the same")
	eq(int(sp["result"]["owed"]), 20, "20 g are still owed")
	Game.state["gold"] = 500
	eq(Sponsor.settle_debts(), 20, "the next morning the rest is paid")
	eq(int(sp["result"]["owed"]), 0, "nothing is owed any more")
	eq(Sponsor.settle_debts(), 0, "and nothing more is paid")
	# 4. a contract given up returns the patron's advance
	Game.state["gold"] = 1000
	var o := Contracts.make_offer("drovers_kit")
	if check(not o.has("error"), "a contract letter (%s)" % o.get("error", "")):
		eq(Contracts.accept(str(o["id"])), "", "accepted")
		var ct := Contracts.get_c(str(o["id"]))
		var adv_g := int(ct["advance"])
		check(adv_g > 0, "the patron paid an advance of %d g" % adv_g)
		var before_abandon := Game.gold()
		eq(Contracts.abandon(str(o["id"])), "", "the smith gives the order up")
		eq(Game.gold(), before_abandon - adv_g, "the advance goes back to the patron")
		eq(str(Game.state["ledger"][-1].get("party", "")), "patron:" + str(ct["patron"]), "the ledger line names the patron")
	check(Payments.unaccounted(1).is_empty(), "every ledger line names its payer or recipient")


func test_withdrawn_contract_returns_the_advance() -> void:
	fresh_game()
	Game.state["gold"] = 1000
	var o := Contracts.make_offer("drovers_kit")
	if not check(not o.has("error"), "a contract letter"):
		return
	Contracts.accept(str(o["id"]))
	var ct := Contracts.get_c(str(o["id"]))
	var adv_g := int(ct["advance"])
	ct["deadline"] = Game.day() - 30   # long overdue: the patron withdraws on the next check
	var g0 := Game.gold()
	Contracts._check_deadline(ct)
	eq(str(ct.get("status", "")), "failed", "the patron withdrew the order")
	eq(Game.gold(), g0 - adv_g, "the advance went back with it")
	eq(int(ct.get("advance_returned", 0)), adv_g, "the contract records the returned advance")


# ------------------------------------------------------------------ D18: renown is earned
func test_renown_is_not_bought() -> void:
	fresh_game()
	Game.state["gold"] = 1000000
	(Game.state["world"] as Dictionary)["rep"] = 0.0
	check(not bool(Smithy.renown()["ok"]), "a million gold is not renown (%s)" % Smithy.renown()["why"])
	check(not str(Smithy.renown()["why"]).contains("gold"), "the forge is told what earns renown, not what buys it")
	check(not bool(Contracts.standing()["renown"]), "contracts do not see a wealthy forge as renowned")
	(Game.state["world"] as Dictionary)["rep"] = 40.0
	check(bool(Smithy.renown()["ok"]), "a renowned name is renown")
	(Game.state["world"] as Dictionary)["rep"] = 0.0
	for i in 3:
		Recognition.record("epic", "Plaque %d" % i, "test", {}, "suite_run01_%d" % i)
	check(bool(Smithy.renown()["ok"]), "three Hall of Fame plaques are renown")


# ------------------------------------------------------------------ the Chronicle/Lore split, as documented
## Characterisation (not an endorsement): until Gate J the Chronicle is a separate, capped feed beside Lore
## (decision register LORE-017). This pins today's behaviour so any change to it is deliberate and documented.
func test_chronicle_and_lore_split_is_as_documented() -> void:
	fresh_game()
	eq(Chronicle.CAP, 400, "the Chronicle feed keeps its last 400 entries")
	var n_lore := (Lore.st()["events"] as Dictionary).size()
	var n_chr := Chronicle.entries().size()
	Chronicle.add("social", "A Chronicle-only note (Run 0.1 characterisation).", {})
	eq(Chronicle.entries().size(), n_chr + 1, "a Chronicle.add lands in the feed")
	eq((Lore.st()["events"] as Dictionary).size(), n_lore, "… and not in Lore (the known split)")
	var id := Lore.record("test", "A notable Lore event (Run 0.1 characterisation).", {"importance": 2, "chronicle": true, "notable": true})
	check(str(id) != "", "Lore records the event")
	check(Chronicle.entries().any(func(e): return str(e.get("text", "")).contains("A notable Lore event")), "a notable Lore event is mirrored into the feed")
