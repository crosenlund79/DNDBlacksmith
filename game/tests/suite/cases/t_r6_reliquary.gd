## R6 "Legacy: the Reliquary & Heirs": the case holds only out-of-service pieces with earned significance and adds no
## fame; heirs come only from recorded ownership and authored family (never invented); the heir's three answers are
## enforced and recorded; the bloodline Unique needs its line for a full restoration; the steward defers heir letters;
## pieces in a family's custody cannot be sold; the journey "a relic and its heir" (EQ-057) end to end; save/load.
## (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R6 acceptance.)
extends SuiteCase

const SMOKE := ["test_heirs_only_from_records", "test_relic_and_its_heir_journey"]


func _reliquary() -> void:
	Property.dev_grant_all()
	SkillTree.unlock_all()
	Game.state["gold"] = 50000
	if not Property.is_owned_station(Reliquary.STATION):
		check(Property.buy_station(Reliquary.STATION) == "", "the Reliquary is bought")
	var plan := Property.plan_copy()
	if not Reliquary.installed():
		var why := Property.auto_place(plan, Reliquary.STATION)
		check(why == "" and Property.commit(plan) == "", "the Reliquary is set up (%s)" % why)
	check(Reliquary.installed(), "the Reliquary stands in the smithy")


## A piece a fallen adventurer bore, carried home to the forge: real records (owners, the death, the homecoming).
func _bearer_piece(def: String, bearer: String, epic := true) -> Dictionary:
	var it := Items.make(def, {"quality": 92.0})
	if Uniques.is_unique_def(def):
		Uniques.register(it, "loot")   # a Unique is found (Loot), not forged by the smith
	else:
		Provenance.forged(it)
	var a := Adv.get_a(bearer)
	Provenance.transfer(it, bearer, "bought", "brindlewick")
	if epic:
		Recognition.grant_epic(it, "struck down the Barrow King", bearer, "boss")
	return it


func _fall(bearer: String) -> String:
	var a := Adv.get_a(bearer)
	a["status"] = "dead"
	a["died_day"] = Game.day()
	var dev := Lore.record("death", "%s fell at the Barrow Fields." % str(a["name"]), {"actors": [bearer], "importance": 3})
	a["death_event"] = dev
	return dev


func _home(it: Dictionary, bearer: String) -> void:
	Lore.push_cause(str(Adv.get_a(bearer).get("death_event", "")))
	Provenance.transfer(it, Provenance.SMITH_ID, "recovered", "brindlewick", "%s's companions carried %s home." % [Talk.npc_name(bearer), Items.display_name(it)])
	Lore.pop_cause()
	Game.add_item(it, false)


func _days(n: int) -> void:
	for i in n:
		Game.advance_minutes(24 * 60)


# ------------------------------------------------------------------ 1. the case
func test_case_holds_only_remembered_service() -> void:
	fresh_game()
	_reliquary()
	# a working Epic sword belongs in the world
	var sword := _bearer_piece("sword_steel", "garrick")
	Game.add_item(sword, false)
	check(Reliquary.enshrine(int(sword["uid"])).contains("wielded"), "a working Epic sword is refused — it still serves")
	# a broken piece with no history earns no place
	var plain := Items.make("sword_iron", {"quality": 60.0})
	plain["broken"] = true
	Game.add_item(plain, false)
	check(Reliquary.enshrine(int(plain["uid"])).contains("no place in history"), "a broken piece nobody remembers is refused")
	# rarity alone is not significance
	var rare := Items.make("sword_steel", {"quality": 100.0})
	rare["rarity"] = "legendary"
	GearDepth.disable(rare, "test")
	Game.add_item(rare, false)
	check(Reliquary.significance(rare) == "" and Reliquary.enshrine(int(rare["uid"])) != "", "a disabled Legendary with no remembered deed is refused (rarity alone is not enough)")
	# the disabled Epic piece is accepted
	GearDepth.disable(sword, "shattered on the Barrow King's crown")
	var rep0 := Reputation.standing()
	var word0 := JSON.stringify(Game.state.get("reputation", {}))
	eq(Reliquary.enshrine(int(sword["uid"])), "", "the shattered Epic sword is laid in")
	check(Game.find_uid(int(sword["uid"])).is_empty() and not Reliquary.held(int(sword["uid"])).is_empty(), "it moved from the stores into the case — one instance")
	eq(ItemRegistry.where(int(sword["uid"])).get("holder", ""), "reliquary", "the registry knows it in the Reliquary")
	check(is_equal_approx(Reputation.standing(), rep0) and JSON.stringify(Game.state.get("reputation", {})) == word0, "exhibition adds no fame")
	check(Lore.of_item(int(sword["uid"])).any(func(e): return str(e["kind"]) == "enshrined"), "the enshrining is in its history")
	eq(Reliquary.take_out(int(sword["uid"])), "", "it can be taken out")
	check(not Game.find_uid(int(sword["uid"])).is_empty(), "back in the stores")


# ------------------------------------------------------------------ 2. heirs only from records (negative test)
func test_heirs_only_from_records() -> void:
	fresh_game()
	# a bearer with no recorded family who fell: no heir
	var lone := ""
	for id in Adv.all():
		if Social.relatives(str(id)).is_empty():
			lone = str(id)
			break
	check(lone != "", "premise: an adventurer without authored family is in the roster")
	var p1 := _bearer_piece("sword_steel", lone)
	_fall(lone)
	_home(p1, lone)
	eq(Reliquary.heirs_of(p1), [], "a fallen bearer without recorded family leaves no heir — none is invented")
	# a piece its bearer sold: the line's claim ended with the sale
	var p2 := _bearer_piece("sword_steel", "mira")
	Provenance.transfer(p2, Provenance.SMITH_ID, "bought", "brindlewick")
	eq(Reliquary.heirs_of(p2), [], "a piece sold to the smith has no heir")
	# a bearer still living is the claimant
	var p3 := _bearer_piece("sword_steel", "kestra")
	Provenance.lose(p3, "the Barrow Fields", "dropped in flight")
	Provenance.transfer(p3, Provenance.SMITH_ID, "found", "brindlewick")
	var h3 := Reliquary.heirs_of(p3)
	check(h3.size() == 1 and str(h3[0]["id"]) == "kestra" and str(h3[0]["relation"]) == "its own bearer", "a living bearer is the claimant (%s)" % str(h3))
	# a fallen bearer with authored family: the living relatives, with the record behind them
	var p4 := _bearer_piece("sword_steel", "garrick")
	_fall("garrick")
	_home(p4, "garrick")
	var h4 := Reliquary.heirs_of(p4)
	check(h4.size() == 1 and str(h4[0]["id"]) == "martha" and str(h4[0]["relation"]) == "mother", "Garrick's mother Martha is his heir (%s)" % str(h4))
	check(str(h4[0]["evidence"]).contains("family record") and str(h4[0]["evidence"]).contains("Garrick"), "the evidence names the record")
	# the invariant over every piece in the world: each heir is provable from data
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, true):
		for h in Reliquary.heirs_of(it):
			var hid := str(h["id"])
			var bearer := str(h["bearer"])
			var owned := Provenance.owners(it).any(func(o): return str(o["id"]) == bearer)
			var proven := owned and (hid == bearer or Social.relatives(bearer).has(hid))
			check(proven, "every heir is proven by the ownership record and the authored family (%s of %s)" % [hid, Items.display_name(it)])
	# no character was created to make an heir
	var roster := Adv.all().size()
	for i in 3:
		Reliquary.on_day(Game.day())
	eq(Adv.all().size(), roster, "no one was added to the world to be an heir")


# ------------------------------------------------------------------ 3. the journey: a relic and its heir (EQ-057)
func _journey(aff: float, comp_share: float) -> Dictionary:
	fresh_game()
	_reliquary()
	Social.ensure("martha")["aff"] = aff
	var g := _bearer_piece("grimhold", "garrick")
	Game.add_item(g, false)
	var uid := int(g["uid"])
	Game.take_uid(uid)
	(Adv.get_a("garrick")["equipment"] as Dictionary)["weapon"] = g
	_fall("garrick")
	(Adv.get_a("garrick")["equipment"] as Dictionary).erase("weapon")
	GearDepth.disable(g, "shattered in Garrick's last fight")
	_home(g, "garrick")
	eq(Reliquary.ancestral_state(g), "asleep", "the bloodline Unique's ancestral nature sleeps while it is unusable")
	eq(Reliquary.enshrine(uid), "", "Grimhold rests in the Reliquary")
	_days(Reliquary.LETTER_AFTER + 1)
	var req := Reliquary.letters().filter(func(l): return int(l["uid"]) == uid and str(l["kind"]) == "request")
	check(req.size() == 1 and str(req[0]["heir"]) == "martha", "Martha, Garrick's mother, writes to ask for its restoration")
	var claim_ev := Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "heir_claim")
	check(claim_ev.size() == 1 and str(claim_ev[0].get("roles", {}).get("martha", "")) == "heir", "her claim is in the relic's history, Martha as heir")
	var v := Valuation.value(Reliquary.held(uid))
	eq(Reliquary.write_to(uid, "martha", int(round(float(v) * comp_share))), "", "the smith writes to her")
	check(Reliquary.write_to(uid, "garrick", 10) != "", "no letter to someone the records do not name as heir")
	_days(1)
	return {"uid": uid, "answer": str(Reliquary.claim(uid).get("answer", "")), "value": v}


func _restore(uid: int, q: float) -> Dictionary:
	if not Reliquary.held(uid).is_empty():
		eq(Reliquary.take_out(uid), "", "taken out for restoration")
	var it := Game.find_uid(uid)
	for d in Refinement.inputs_for(it, "restore"):
		Game.add_item(Items.make(str(d), {"qty": 8}), false)
	return Refinement.perform(uid, "restore", q, {"station": Refinement.station_for(it, "restore")})


func test_relic_and_its_heir_journey() -> void:
	# the heir who wants it home (warm regard): return
	var j := _journey(45.0, 0.25)
	var uid := int(j["uid"])
	eq(j["answer"], "return", "Martha consents on one condition: restored, it goes home")
	var it := Reliquary.held(uid)
	eq(Provenance.owner_id(it), "martha", "the family is acknowledged as its owner — permission and ownership are separate")
	var r := _restore(uid, 90.0)
	check(bool(r.get("ok", false)) and str(r.get("outcome", "")) == "success", "the restoration succeeds (%s)" % str(r.get("text", "")))
	var after := ItemRegistry.find(uid)
	check(not after.is_empty() and not GearDepth.disabled(after), "restored: the same instance, usable")
	eq(ItemRegistry.where(uid).get("holder", ""), "holdings", "it went home with Martha (the terms enforced)")
	check(Game.find_uid(uid).is_empty() and Reliquary.held(uid).is_empty(), "the smith keeps nothing — it left the forge")
	eq(Provenance.owner_id(after), "martha", "its owner is Martha")
	eq(Reliquary.ancestral_state(after), "awake", "with the line's consent the ancestral nature woke")
	var kinds := Lore.of_item(uid).map(func(e): return str(e["kind"]))
	for k in ["enshrined", "heir_claim", "heir_letter", "heir_terms", "restored", "returned"]:
		check(kinds.has(k), "its history records %s" % k)
	var rest := Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "restored")
	check(not rest.is_empty() and (rest[0].get("data", {}).get("contributors", []) as Array).any(func(c): return str(c.get("who", "")) == "martha"), "Martha's consent rite is recorded among the restoration's contributors")
	var ret := Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "returned")
	check(not ret.is_empty() and (ret[0].get("because", []) as Array).has(str(rest[0]["id"])), "the homecoming follows from the restoration (causal link)")
	eq(Uniques.audit(), [], "one authentic Grimhold")
	eq(ItemRegistry.scan()["dup"], [], "no uid held twice")


func test_heir_custody_and_decline() -> void:
	# neutral regard, a fair compensation: custody — the family keeps ownership, the forge keeps the piece
	var j := _journey(0.0, 0.25)
	var uid := int(j["uid"])
	eq(j["answer"], "custody", "Martha consents but will not part with it")
	check(Game.gold() <= 50000 - int(round(float(int(j["value"])) * 0.25)), "the compensation was paid")
	var r := _restore(uid, 90.0)
	check(str(r.get("outcome", "")) == "success", "restored")
	var it := Game.find_uid(uid)
	check(not it.is_empty(), "it stays in the forge's keeping")
	eq(Provenance.owner_id(it), "martha", "but it is Martha's")
	check(Shop.set_for_sale(uid, true) != "" and not bool(it.get("for_sale", false)), "it cannot be put up for sale")
	check(Commerce.pawnable(it) != "", "nor pawned")
	check(Steward.protection_reason(it) != "", "the steward protects it")
	eq(Reliquary.ancestral_state(it), "awake", "the line consented: its nature woke")
	# cold regard: decline — the smith may still restore what he holds, but without the line
	var j2 := _journey(-50.0, 0.25)
	var uid2 := int(j2["uid"])
	eq(j2["answer"], "decline", "Martha, cold to the smith, declines")
	var it2 := Reliquary.held(uid2)
	eq(Provenance.owner_id(it2), Provenance.SMITH_ID, "nothing changed hands")
	var p := Refinement.plan(it2, "restore")
	check(float(p.get("success_at", 0.0)) > float(Refinement.SUCCESS["restore"]), "without the line the restoration is harder (%s)" % str(p.get("success_at", "")))
	check(str(p.get("risk", {}).get("text", "")).contains("line"), "the plan says why")
	var r2 := _restore(uid2, 90.0)
	check(bool(r2.get("ok", false)) and not GearDepth.disabled(Game.find_uid(uid2)), "restored by the smith alone")
	eq(Reliquary.ancestral_state(Game.find_uid(uid2)), "asleep", "but its ancestral nature sleeps on — incomplete without the line")
	var it3 := Game.find_uid(uid2)
	var raw := int(it3["stats"].get("attack", 0))
	for af in it3.get("affixes", []):
		if str(af["stat"]) == "attack":
			raw += int(af["value"])
	eq(Items.base_stat(it3, "attack"), int(floor(float(raw) * Reliquary.ASLEEP_FACTOR)), "its strength is held back while its nature sleeps (%d of %d)" % [Items.base_stat(it3, "attack"), raw])


# ------------------------------------------------------------------ 4. ancestral binding is not universal
func test_binding_only_for_the_bloodline_unique() -> void:
	fresh_game()
	var s := _bearer_piece("sword_steel", "garrick")
	GearDepth.disable(s, "test")
	eq(Reliquary.ancestral_state(s), "", "an ordinary Epic sword has no ancestral nature")
	check(not Reliquary.bloodline(s), "not bloodline-bound")
	var g := Items.make("grimhold", {"quality": 90.0})
	Uniques.register(g, "loot")
	check(Reliquary.bloodline(g), "Grimhold, the Last Hammer, is bloodline-bound (tag in data)")
	var f0 := float(Items.base_stat(g, "attack"))
	GearDepth.disable(g, "test")
	g.erase("disabled")
	g["ancestral"] = {"state": "asleep"}
	check(float(Items.base_stat(g, "attack")) < f0, "asleep, its strength is held back")


# ------------------------------------------------------------------ 5. the steward defers heir matters
func test_steward_defers_heir_letters() -> void:
	fresh_game()
	_reliquary()
	var g := _bearer_piece("sword_steel", "garrick")
	_fall("garrick")
	GearDepth.disable(g, "test")
	_home(g, "garrick")
	eq(Reliquary.enshrine(int(g["uid"])), "", "laid in")
	check(Steward.activate() == "", "the steward takes over")
	_days(Reliquary.LETTER_AFTER + 1)
	var d := Steward.deferred().filter(func(e): return str(e["kind"]) == "heir")
	check(d.size() == 1 and bool(d[0]["sealed"]), "the heir's letter waits as sealed correspondence")
	check(Reliquary.write_to(int(g["uid"]), "martha", 0) != "", "the steward never writes to an heir")
	Steward.deactivate()


# ------------------------------------------------------------------ 6. save / load
func test_save_load_keeps_case_and_terms() -> void:
	var j := _journey(0.0, 0.25)
	var uid := int(j["uid"])
	check(Saves.save("suite_r6") and Saves.load_slot("suite_r6"), "saved and loaded")
	Saves.delete("suite_r6")
	check(not Reliquary.held(uid).is_empty(), "the relic is still in the case")
	eq(Reliquary.claim(uid).get("answer", ""), "custody", "the agreed terms survive")
	eq(Provenance.owner_id(Reliquary.held(uid)), "martha", "and the ownership")
	eq(ItemRegistry.scan()["dup"], [], "no duplicate after loading")


# ------------------------------------------------------------------ 7. a possible purchase (§6.6 ¶2)
func test_heir_may_sell() -> void:
	fresh_game()
	_reliquary()
	Social.ensure("martha")["aff"] = 10.0
	var g := _bearer_piece("grimhold", "garrick")
	_fall("garrick")
	GearDepth.disable(g, "shattered")
	_home(g, "garrick")
	var uid := int(g["uid"])
	eq(Reliquary.enshrine(uid), "", "laid in")
	var v := Valuation.value(Reliquary.held(uid))
	var low := Reliquary.decide(Reliquary.held(uid), Reliquary.heirs_of(Reliquary.held(uid))[0], 0, int(v * 0.5))
	check(low != "sold", "an unfair purchase offer does not buy it (%s)" % low)
	var gold0 := Game.gold()
	eq(Reliquary.write_to(uid, "martha", 0, int(round(float(v) * 1.2))), "", "the smith offers to buy it")
	_days(1)
	eq(str(Reliquary.claim(uid).get("answer", "")), "sold", "Martha sells it and consents")
	eq(Provenance.owner_id(Reliquary.held(uid)), Provenance.SMITH_ID, "it is the smith's now")
	var paid := (Game.state["ledger"] as Array).filter(func(l): return str(l.get("cat", "")) == "heir" and str(l.get("party", "")) == "martha")
	check(paid.size() == 1 and int(paid[0]["amount"]) == -int(round(float(v) * 1.2)), "the price was paid to Martha — one ledger line (%s)" % str(paid))
	check(gold0 - Game.gold() >= int(round(float(v) * 1.2)), "and it left the smith's purse")
	var owners := Provenance.owners(Reliquary.held(uid)).map(func(o): return str(o["id"]))
	check(owners.has("martha") and owners[-1] == Provenance.SMITH_ID, "the record shows it passing through Martha's hands to the smith")
	check(Reliquary.consented(uid), "her consent stands: the line's rite is possible")
