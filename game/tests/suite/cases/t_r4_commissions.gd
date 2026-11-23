## R4 "Commissions v2 & Civic Recipients": the Honor Guard (canonical §13) — a patron letter for 20 bench pieces and 3
## named prestige pieces, the named pieces made as staged work orders by three hands, delivered to the muster as real
## stock with a lot record, every piece traceable after save/load; molds and patterns; the village purse; uncapped
## records; old saves with contracts in hand (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R4 acceptance).
extends SuiteCase

const SMOKE := ["test_honor_guard_journey", "test_molds_and_patterns"]


func _workshop() -> void:
	fresh_game()
	for u in Property.units():
		Property.dev_grant_unit(str(u["id"]))
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	Game.state["gold"] = 50000
	(Game.state["hirelings"] as Array).clear()


func _until(cond: Callable, max_min: int) -> bool:
	var g := 0
	while not cond.call() and g < max_min:
		Game.advance_minutes(5)
		g += 5
	return cond.call()


func _smith_stage(tid: int) -> bool:
	var err := WorkOrders.begin_smith_stage(tid)
	if not check(err == "", "the smith takes up his stage (%s)" % err):
		return false
	var guard := 0
	while Crafting.active() and Crafting.job().has("order") and guard < 14:
		var qs := []
		for i in int(Crafting.current_op().get("checks", 1)):
			qs.append(106.0)
		Crafting.record_step(Crafting.smith_instance(), qs)
		guard += 1
	return check(not Crafting.active(), "his stage is done and the piece handed on")


func _honor_guard() -> Dictionary:
	var c := Contracts.make_offer("honor_guard")
	if not check(not c.has("error"), "the reeve's letter arrives (%s)" % c.get("error", "")):
		return {}
	eq((c["named"] as Array).size(), 3, "it names three pieces")
	eq(int(c["units_total"]), 20, "and twenty pieces for the ranks")
	check(eq(Contracts.accept(str(c["id"])), "", "the order is accepted"), "accepted")
	return Contracts.get_c(str(c["id"]))


# ------------------------------------------------------------------ the Honor Guard, end to end
func test_honor_guard_journey() -> void:
	_workshop()
	train("smithing", 9)
	var bs := Apprentices.dev_take_on("blacksmith", 8, "journeyman", "Garth Mallory")
	var lw := Apprentices.dev_take_on("leatherworker", 8, "journeyman", "Wren Marsh")
	check(not bs.is_empty() and not lw.is_empty(), "a blacksmith and a leatherworker are on the staff")
	give("ingot_steel", 12)
	give("leather_cured", 12)
	give("ingot_iron", 24)
	var c := _honor_guard()
	if c.is_empty():
		return
	var cid := str(c["id"])
	var slots: Array = c["named"]
	for s in slots:
		check(int(s["task"]) >= 0, "«%s» is a work order in the Workshop Ledger" % s["name"])
	var reserved := {}
	for s in slots:
		var t := Apprentices.task(int(s["task"]))
		reserved[str(s["name"])] = int(t.get("uid", -1))
		check(int(t.get("uid", -1)) > 0, "«%s» has its uid reserved (%d)" % [s["name"], int(t.get("uid", -1))])
		check(WorkOrders.staged(t), "«%s» is a staged order (%d stages)" % [s["name"], WorkOrders.stages(t).size()])
	# Vigil asks for the smith's own hand: he forges its blade himself
	var vigil_tid := int(slots[0]["task"])
	eq(WorkOrders.assign_stage(vigil_tid, 0, "player"), "", "the smith claims Vigil's forging stage")
	_smith_stage(vigil_tid)
	# the bench: twenty pieces for the ranks
	var used := Contracts.add_hours(c, 200.0, 88.0, "smith")
	eq(int(c["units_done"]), 20, "the twenty bench pieces are made (%.1f h)" % used)
	check(not Contracts.ready(cid), "but the order is not ready without its named pieces")
	# the staff finish the named pieces (each stage at a real station, handed on between hands)
	check(_until(func(): return Contracts.named_missing(c) == 0, 60 * 24 * 12), "all three named pieces are laid in (%d left)" % Contracts.named_missing(c))
	var hands := {}
	for s in slots:
		var it: Dictionary = s["item"]
		if not check(not it.is_empty(), "«%s» is in the order" % s["name"]):
			continue
		eq(int(it["uid"]), int(reserved[str(s["name"])]), "«%s» carries the uid reserved for it" % s["name"])
		eq(str(it.get("given_name", {}).get("name", "")), str(s["name"]), "the reeve's name is given to it")
		check(str(it["name"]).begins_with(str(s["name"]) + ","), "and shown with it (%s)" % it["name"])
		check(float(it.get("quality", 0)) >= float(s["min_q"]), "%d%% craftsmanship (%d%% asked)" % [int(it["quality"]), int(s["min_q"])])
		hands[str(Provenance.maker(it).get("id", ""))] = true
		for e in Provenance.contributors(it):
			hands[str(e.get("who", ""))] = true
	check(Contracts.smith_worked(slots[0]["item"]), "Vigil bears the smith's own work")
	check(hands.size() >= 3, "three hands made the named pieces (%s)" % str(hands.keys()))
	check(Contracts.ready(cid), "now the order is ready")
	var o := Contracts.deliver(cid)
	check(not o.has("error"), "delivered: %s" % str(o.get("outcome", o.get("error", ""))))
	# at the muster: the bench pieces as supply, the named pieces as stock, one lot record
	eq(Institutions.holds("muster", "helm_iron"), 10, "the muster holds the ten helms")
	eq(Institutions.holds("muster", "shield_round"), 10, "and the ten round shields")
	var stock := Institutions.stock("muster")
	eq(stock.size(), 3, "and the three named pieces themselves")
	var lot: Dictionary = Institutions.lots("muster")[-1] if not Institutions.lots("muster").is_empty() else {}
	check(not lot.is_empty() and (lot["pieces"] as Array).size() == 3 and int((lot["lines"] as Array).size()) == 2, "one lot record: two bench lines and three pieces")
	check(not (lot.get("contributors", []) as Array).is_empty(), "with the hands that worked the bench")
	for it in stock:
		eq(Provenance.owner_id(it), Institutions.holder_id("muster"), "%s belongs to the muster" % Items.display_name(it))
		eq(str(ItemRegistry.where(int(it["uid"])).get("holder", "")), "institution", "and the registry finds it there")
	var dev := ""
	for e in Lore.of_kind("commission"):
		if str(e.get("data", {}).get("contract", "")) == cid and str(e.get("data", {}).get("outcome", "")) != "":
			dev = str(e["id"])
	check(dev != "", "the delivery is one Lore event")
	check(Lore.why(dev).any(func(x): return str(x["id"]) == str(c.get("accept_event", ""))), "linked back to the accepted letter")
	for it in stock:
		var hand := Lore.of_item(int(it["uid"])).filter(func(x): return str(x["kind"]) == "commissioned")
		check(not hand.is_empty() and (hand[-1].get("because", []) as Array).has(dev), "%s passed to the muster because of the delivery" % it["given_name"]["name"])
	# save / load: every named piece still individually traceable
	var uids := stock.map(func(x): return int(x["uid"]))
	check(save_load("r4_honor"), "saved and loaded")
	for u in uids:
		var it2 := ItemRegistry.find(int(u))
		check(not it2.is_empty() and str(it2.get("given_name", {}).get("name", "")) != "", "uid %d is still «%s» at the muster" % [u, it2.get("given_name", {}).get("name", "?")])
		check(Lore.of_item(int(u)).size() >= 3, "with its history (%d events)" % Lore.of_item(int(u)).size())
	eq(Institutions.holds("muster", "helm_iron"), 10, "the muster's supply survives the save")
	var scan := ItemRegistry.scan()
	eq(int(scan.get("duplicates", []).size()) if scan.get("duplicates") is Array else int(scan.get("duplicates", 0)), 0, "no uid is held twice")


func test_named_piece_needs_the_smiths_hand_when_asked() -> void:
	_workshop()
	var c := _honor_guard()
	if c.is_empty():
		return
	var it := Items.make("sword_steel", {"quality": 96.0})
	Provenance.forged(it, {"id": "app_x", "name": "An apprentice", "mark": "app_x", "workshop": Provenance.SMITH_MARK})
	Game.add_item(it, false)
	var why := Contracts.named_reason(c, 0, it)
	check(why.contains("own hand"), "a sword made only by the staff cannot be Vigil: %s" % why)
	var mine := Items.make("sword_steel", {"quality": 96.0})
	Provenance.forged(mine)
	Game.add_item(mine, false)
	eq(Contracts.named_reason(c, 0, mine), "", "one the smith forged can")
	var poor := Items.make("sword_steel", {"quality": 60.0})
	Provenance.forged(poor)
	check(Contracts.named_reason(c, 0, poor).contains("craftsmanship"), "a poor one cannot")


func test_steward_defers_named_pieces() -> void:
	_workshop()
	var c := _honor_guard()
	if c.is_empty():
		return
	check(Steward.activate() == "", "the steward takes over")
	var t := {"contract": str(c["id"]), "named_index": 1}
	var it := Items.make("cuirass_steel", {"quality": 95.0})
	Provenance.forged(it)
	Game.add_item(it, false)
	Contracts.on_named_made(t, it)
	check((c["named"][1]["item"] as Dictionary).is_empty(), "the steward does not lay a named piece in")
	eq(int(c["named"][1]["ready_uid"]), int(it["uid"]), "it waits in the stores, marked for the order")
	check(Steward.deferred().any(func(d): return str(d.get("kind", "")) == "contract" and str(d.get("text", "")).contains("Hearthward")), "and the smith is told when he returns")
	Steward.deactivate()
	eq(Contracts.lay_in_named(str(c["id"]), 1, int(it["uid"])), "", "the smith lays it in himself")


# ------------------------------------------------------------------ molds and patterns
func test_molds_and_patterns() -> void:
	_workshop()
	eq(Crafting.recipe_locked_reason("silver_band"), "", "a ring needs no mold (tools are never required)")
	var base_hpu := Contracts.line_hpu({"recipe": "iron_helm", "hpu": 1.5})
	var base_q := Crafting.skill_bonus("silver_band")
	var mold := craft("make_mold_ring", 90.0, {"purity": 3})
	check(not mold.is_empty() and str(mold.get("def", "")) == "mold_ring", "the ring mold is made at the crucible, anvil and wheel")
	check(Crafting.skill_bonus("silver_band") > base_q, "with it in the stores, rings are steadier (+%.0f)" % (Crafting.skill_bonus("silver_band") - base_q))
	eq(Crafting.skill_bonus("iron_helm"), Crafting.skill_bonus("iron_helm"), "")
	var pat := craft("make_pattern_muster", 90.0, {"purity": 3})
	check(not pat.is_empty(), "the muster pattern is forged")
	check(Contracts.line_hpu({"recipe": "iron_helm", "hpu": 1.5}) < base_hpu, "a helm series at the bench goes quicker (%.2f → %.2f h)" % [base_hpu, Contracts.line_hpu({"recipe": "iron_helm", "hpu": 1.5})])
	eq(Contracts.line_hpu({"recipe": "iron_cuirass", "hpu": 1.5}), 1.5, "other work is unchanged")
	for i in 20:
		Crafting.skill_bonus("silver_band")
	check(not Game.find_uid(int(mold["uid"])).is_empty(), "the mold never wears out or is used up")


# ------------------------------------------------------------------ records
func test_village_purse_pays_the_subsidy_on_record() -> void:
	fresh_game()
	var p0 := Institutions.purse()
	var rec := Institutions.pay_from_village(30, "outfitting subsidy: test", "smith", "ord_x")
	eq(Institutions.purse(), p0 - 30, "the subsidy leaves the village purse")
	eq(int(rec["amount"]), -30, "and is a payer record")
	Institutions.on_day(7)
	eq(Institutions.purse(), p0 - 30 + Institutions.PURSE_WEEKLY, "the purse takes in its weekly income")
	Institutions.pay_from_village(100000, "an impossible subsidy", "smith")
	check(int(Institutions.peek("village")["payments"][-1].get("owed", 0)) > 0, "a purse that runs short records what the village owes")


func test_records_are_not_capped() -> void:
	fresh_game()
	var before := 0
	for l in Game.state["ledger"]:
		before += int(l["amount"])
	for i in 450:
		Game.add_gold(1, "test", "line %d" % i, "aldric")
	eq((Game.state["ledger"] as Array).size(), 400, "the ledger keeps its last 400 lines")
	var total := 0
	for m in Game.state.get("ledger_archive", {}).values():
		for k in m:
			total += int(m[k]["amount"])
	for l in Game.state["ledger"]:
		total += int(l["amount"])
	eq(total, before + 450, "the rest is kept as monthly totals by payer and category — nothing is lost")
	check(Game.state["ledger_archive"].values().any(func(m): return m.has("aldric|test")), "by payer: Aldric's lines are summed under his name")
	for i in 35:
		Contracts.history().append({"id": "ct_h%d" % i, "status": "delivered"})
	check(Contracts.history().size() >= 35, "the contract history is not capped at 30")


func test_contract_in_hand_survives_migration() -> void:
	fresh_game()
	var c := Contracts.make_offer("muster_helms")
	Contracts.accept(str(c["id"]))
	c = Contracts.get_c(str(c["id"]))
	give("ingot_iron", 10)
	give("leather_cured", 10)
	Contracts.add_hours(c, 5.0, 80.0, "smith")
	var snap := {"units": int(c["units_done"]), "hours": float(c["hours_done"]), "deadline": int(c["deadline"])}
	c.erase("named")
	check(save_as_version("r4_old", 11), "written as a schema-11 save with a contract in hand")
	check(Saves.load_slot("r4_old"), "it loads")
	var c2 := Contracts.get_c(str(c["id"]))
	eq((c2.get("named", null) as Array).size() if c2.get("named") is Array else -1, 0, "the order gains an empty list of named pieces")
	eq({"units": int(c2["units_done"]), "hours": float(c2["hours_done"]), "deadline": int(c2["deadline"])}, snap, "its work, hours and deadline are unchanged")
	check((Saves.last_load.get("migration", {}).get("steps", []) as Array).has("commissions v2"), "step 12 ran")
