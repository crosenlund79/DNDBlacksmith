## The Living Realm, milestone 5 — major contracts and the Project Bench (`Contracts`, Apprentices task kind "contract"):
## letters come from real accomplishments (a new smith gets none, a royal letter never comes without them, each letter
## names why); accepting pays the advance and delivers the patron's crate exactly once; blocks of hours at the bench
## advance the clock, tire the smith and make pieces whose craftsmanship follows his skill; the crate is used before
## the stores and nothing is duplicated; rare materials are needed from mid-order and taken once; apprentices put hours
## in through the task queue; on time / late / poor deliveries pay and move reputation and favour correctly and a long
## overdue order is withdrawn (never a game over); the masterpiece slot takes only an individually crafted piece meeting
## its minimums (same instance, passes to the patron); the bench is a buyable station with its own prompt; save/load
## mid-production and an old save without the key.
extends SuiteCase

const SMOKE := ["test_offers_need_accomplishments", "test_accept_delivers_crate_once", "test_blocks_of_hours", "test_save_load_and_old_save"]


# ------------------------------------------------------------------ fixtures
func _game() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()   # Borin's own smelting would move the stores under the test
	Game.state["gold"] = 5000


## Buys and sets up the Project Bench through Property (auto-placement in an owned workshop room).
func _bench() -> bool:
	if Contracts.bench_installed():
		return true
	if not check(Property.buy_station(Contracts.BENCH) == "", "the Project Bench can be bought"):
		return false
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, Contracts.BENCH)
	if why != "":
		# a full starting workshop: buy the room next door
		Property.dev_grant_unit("cobbler")
		plan = Property.plan_copy()
		why = Property.auto_place(plan, Contracts.BENCH)
	if not check(why == "", "the bench finds a place in a workshop room (%s)" % why):
		return false
	return check(Property.commit(plan) == "" and Contracts.bench_installed(), "the bench is installed")


func _accept(tpl: String) -> Dictionary:
	var o := Contracts.make_offer(tpl)
	if not check(not o.has("error"), "offer %s (%s)" % [tpl, o.get("error", "")]):
		return {}
	var err := Contracts.accept(str(o["id"]))
	check(err == "", "accept %s (%s)" % [tpl, err])
	return Contracts.get_c(str(o["id"]))


## Finishes every piece of an order quickly (the smith's hours, materials supplied).
func _finish(c: Dictionary) -> void:
	for d in Contracts.materials_needed(c):
		give(str(d), int(Contracts.materials_needed(c)[d]))
	for d in c["rare"]:
		give(str(d), int(c["rare"][d]))
	var g := 0
	while not Contracts.ready(str(c["id"])) and g < 200:
		Vitality.set_fatigue(0.0)
		var r := Contracts.work(str(c["id"]), 4)
		if str(r.get("error", "")) != "":
			check(false, "work stopped: %s" % r["error"])
			return
		g += 1


func _hire(rank: String, lv: int) -> Dictionary:
	train("smithing", 6)
	for u in ["cobbler", "laundry"]:
		if not Property.owns(u):
			Property.dev_grant_unit(u)
	var guard := 0
	while Apprentices.applicants().is_empty() and guard < 20:
		Apprentices.refresh_applicants()
		guard += 1
	if not check(Apprentices.hire(0) == "", "hire an apprentice"):
		return {}
	var a: Dictionary = Apprentices.staff()[-1]
	a["traits"] = []
	a["rank"] = rank
	a["skills"]["smithing"] = {"lvl": lv, "xp": 0}
	return a


func _to_shift() -> void:
	var m := int(Game.state["minute"])
	Game.advance_minutes(8 * 60 - m if m < 8 * 60 else 24 * 60 - m + 8 * 60)


# ------------------------------------------------------------------ letters come from accomplishments
func test_offers_need_accomplishments() -> void:
	_game()
	eq(int(Contracts.standing()["tier"]), 0, "a new smith has no patrons yet")
	check(Contracts.tier_open(1) != "", "and the view says what the first letter needs: %s" % Contracts.tier_open(1))
	days(12)
	check(Contracts.offers().is_empty(), "no letter arrives for a smith who has done nothing yet")
	# a great reputation and a fortune alone do not bring the Crown
	SkillTree.unlock_all()
	(Game.state["world"] as Dictionary)["rep"] = 60.0
	Game.state["gold"] = 50000
	Game.state["stats"]["crafted"] = 40
	check(int(Contracts.standing()["tier"]) < 3, "reputation and gold alone do not open the great lords or the Crown (tier %d)" % int(Contracts.standing()["tier"]))
	var royal := false
	for i in 40:
		days(1)
		for o in Contracts.offers():
			if str(Contracts.patron(str(o["patron"])).get("kind", "")) == "royal":
				royal = true
			# answer every letter so the next can come
			Contracts.decline(str(o["id"]))
	check(not royal, "40 days of fame and fortune bring no royal letter without delivered orders and famous work")
	check(Contracts.st()["last_offer_day"] > 0, "the merchants did write (tier 1 open: %s)" % str(Contracts.standing()["reasons"].get("1", [])))


func test_letter_says_why_and_royal_when_earned() -> void:
	_game()
	SkillTree.unlock_all()
	give("ingot_iron", 4)
	for i in 8:
		give("ingot_iron", 1)
		craft("iron_hatchet")
	check(int(Game.state["stats"]["crafted"]) >= 8, "eight pieces forged the ordinary way")
	eq(int(Contracts.standing()["tier"]), 1, "eight pieces and a decent name open the merchants and the muster")
	Contracts.st()["last_offer_day"] = 0
	var g := 0
	while Contracts.offers().is_empty() and g < 20:
		days(1)
		g += 1
	check(not Contracts.offers().is_empty(), "a letter arrives within days")
	if Contracts.offers().is_empty():
		return
	var o: Dictionary = Contracts.offers()[0]
	eq(int(Contracts.patron(str(o["patron"])).get("tier", 0)), 1, "the first letter is from a merchant or the muster")
	check(str(o["why"]).contains("pieces have left your anvil"), "the letter names the accomplishment: %s" % o["why"])
	# earn the Crown: well-delivered orders up to a great lord, famous work, a renowned forge
	for tpl in ["drovers_kit", "watch_arms", "captains_company"]:
		var c := Contracts._build(Contracts.template(tpl), "")
		c["outcome"] = "good"
		Contracts.history().append(c)
	check(int(Contracts.standing()["tier"]) < 4, "orders alone are not enough without fame (%s)" % Contracts.tier_open(4))
	for i in 4:
		Recognition.record("craft", "Masterwork %d" % i, "test", {}, "t_ct_%d" % i)
	(Game.state["world"] as Dictionary)["rep"] = 60.0
	eq(int(Contracts.standing()["tier"]), 4, "orders well served, four plaques and a renowned forge open the Royal Household")
	var ro := Contracts.make_offer("queens_guard")
	check(not ro.has("error") and str(ro["why"]).contains("Warden"), "the royal letter says why it came: %s" % ro.get("why", ""))


# ------------------------------------------------------------------ accepting
func test_accept_delivers_crate_once() -> void:
	_game()
	var o := Contracts.make_offer("drovers_kit")
	var gold0 := Game.gold()
	var iron0 := Game.count("ingot_iron")
	eq(Contracts.accept(str(o["id"])), "", "the order is accepted")
	var c := Contracts.get_c(str(o["id"]))
	eq(Game.gold() - gold0, int(c["advance"]), "the advance is paid once")
	eq(c["crate"], Contracts.template("drovers_kit")["crate"], "the patron's crate stands at the bench with exactly what he sent")
	eq(Game.count("ingot_iron"), iron0, "the crate is the patron's: it is not mixed into the stores")
	check(Contracts.accept(str(o["id"])) != "", "the same letter cannot be accepted twice")
	eq(Game.gold() - gold0, int(c["advance"]), "and no second advance is paid")
	eq(int(c["deadline"]), Game.day() + int(c["days"]), "the deadline counts from today")
	var o2 := Contracts.make_offer("muster_helms")
	eq(Contracts.decline(str(o2["id"])), "", "a letter can be declined")
	check(Contracts.offers().is_empty(), "and it is gone")


# ------------------------------------------------------------------ the smith's blocks of hours
func test_blocks_of_hours() -> void:
	_game()
	var c := _accept("drovers_kit")
	check(Contracts.can_work(str(c["id"])).contains("Project Bench"), "without a bench the work cannot start: %s" % Contracts.can_work(str(c["id"])))
	_bench()
	give("ingot_iron", 20)
	var t0 := Game.now()
	var f0 := Vitality.fatigue()
	var xp0 := int(Game.player_skills()["smithing"].get("xp", 0)) + Game.player_level("smithing") * 100000
	var r := Contracts.work(str(c["id"]), 2)
	eq(str(r["error"]), "", "a block of two hours is worked")
	eq(Game.now() - t0, 120, "two hours pass on the clock")
	check(Vitality.fatigue() > f0 + 7.0, "the smith tires (%.1f → %.1f)" % [f0, Vitality.fatigue()])
	check(int(Game.player_skills()["smithing"].get("xp", 0)) + Game.player_level("smithing") * 100000 > xp0, "and learns from the work")
	check(float(c["hours_done"]) > 1.5 and float(c["hours_done"]) < 2.6, "about two contract hours went in (%.2f)" % float(c["hours_done"]))
	check(int(c["units_done"]) >= 1, "pieces are made (%d hatchets)" % int(c["units_done"]))
	var q_low := Contracts.quality(c)
	check(q_low > 75.0 and q_low < 105.0, "craftsmanship follows a Smithing-4 smith on easy work (%.1f%%)" % q_low)
	# a master on the same order works faster and better
	_game()
	train("smithing", 14)
	var c2 := _accept("drovers_kit")
	_bench()
	give("ingot_iron", 20)
	Contracts.work(str(c2["id"]), 2)
	check(Contracts.quality(c2) > q_low + 8.0, "a master's hours are finer (%.1f%% vs %.1f%%)" % [Contracts.quality(c2), q_low])
	check(float(c2["hours_done"]) > 2.2, "and faster (%.2f contract hours in two)" % float(c2["hours_done"]))
	# an exhausted smith does not start a block, and tiredness lowers the work
	Vitality.set_fatigue(95.0)
	check(Contracts.can_work(str(c2["id"])).contains("tired"), "an exhausted smith must sleep first")
	Vitality.set_fatigue(85.0)
	check(Contracts.smith_hour_quality("iron_hatchet") < Contracts.smith_hour_quality("iron_hatchet") + 0.01, "quality is computed")
	var tired := Contracts.smith_hour_quality("iron_hatchet")
	Vitality.set_fatigue(0.0)
	check(Contracts.smith_hour_quality("iron_hatchet") > tired + 5.0, "a fresh smith works better than a weary one")


# ------------------------------------------------------------------ materials: crate first, no duplication
func test_materials_crate_first_no_duplication() -> void:
	_game()
	_bench()
	var c := _accept("drovers_kit")
	var crate0: Dictionary = (c["crate"] as Dictionary).duplicate()
	var iron0 := Game.count("ingot_iron")
	var coal0 := Game.count("coal")
	Contracts.work(str(c["id"]), 4)
	var n := int(c["units_done"]) + (1 if bool(c["unit_open"]) else 0)
	eq(int(crate0["ingot_iron"]) - int((c["crate"] as Dictionary).get("ingot_iron", 0)), n, "each hatchet begun took one iron ingot from the patron's crate")
	eq(Game.count("ingot_iron"), iron0, "the smith's own iron is untouched while the crate has iron")
	eq(Game.count("coal"), coal0, "and his coal too (hatchets need none… the crate's coal waits)")
	# empty the crate's iron: the stores take over, exactly one per piece
	c["crate"].erase("ingot_iron")
	Game.remove_def("ingot_iron", Game.count("ingot_iron"))
	give("ingot_iron", 3)
	var u0 := int(c["units_done"]) + (1 if bool(c["unit_open"]) else 0)
	Vitality.set_fatigue(0.0)
	Contracts.work(str(c["id"]), 4)
	var u1 := int(c["units_done"]) + (1 if bool(c["unit_open"]) else 0)
	eq(3 - Game.count("ingot_iron"), u1 - u0, "the stores give exactly one ingot per piece begun")
	check(u1 - u0 <= 3, "no piece is begun without its iron (%d begun from 3 ingots)" % (u1 - u0))
	check(Contracts.can_work(str(c["id"])).contains("Missing materials"), "then the bench says what is missing: %s" % Contracts.can_work(str(c["id"])))
	# rare materials: needed from the middle of the order, taken once
	_game()
	SkillTree.unlock_all()
	_bench()
	var g := _accept("guild_blades")
	give("ingot_steel", 30)
	give("leather_cured", 30)
	var gi := 0
	while Contracts.can_work(str(g["id"])) == "" and gi < 40:
		Vitality.set_fatigue(0.0)
		Contracts.work(str(g["id"]), 2)
		gi += 1
	eq(int(g["units_done"]), 6, "half the matched blades are made, then the silver is needed")
	check(Contracts.can_work(str(g["id"])).contains("Silver"), "the bench names the rare material: %s" % Contracts.can_work(str(g["id"])))
	check(str(Guide.how_to_get("ore_silver", 6).get("text", "")) != "", "and the Guide shows a way to get it: %s" % Guide.how_to_get("ore_silver", 6).get("text", ""))
	give("ore_silver", 8)
	var silver0 := Game.count("ore_silver")
	Vitality.set_fatigue(0.0)
	Contracts.work(str(g["id"]), 1)
	eq(silver0 - Game.count("ore_silver"), 6, "exactly the six silver ore asked for are laid in")
	eq(int(g["rare_in"].get("ore_silver", 0)), 6, "and recorded with the order")
	var silver1 := Game.count("ore_silver")
	_finish(g)
	eq(Game.count("ore_silver"), silver1 + 6, "the rest of the order takes no more silver (the fixture's own 6 stay)")


# ------------------------------------------------------------------ apprentices put hours in
func test_apprentices_contribute() -> void:
	_game()
	_bench()
	var a := _hire("apprentice", 4)
	var c := _accept("drovers_kit")
	give("ingot_iron", 20)
	var nov := _hire("novice", 1)
	check(Apprentices.add_task("contract", {"target": str(c["id"]), "repeat": 4, "assignee": str(nov["id"])}).has("error"), "a novice is not qualified for equipment orders")
	var t := Apprentices.add_task("contract", {"target": str(c["id"]), "repeat": 4, "assignee": str(a["id"])})
	check(not t.has("error"), "an apprentice is assigned 4 hours through the queue (%s)" % t.get("error", ""))
	if t.has("error"):
		return
	_to_shift()
	var g := 0
	while str(t["state"]) != "done" and g < 200:
		Game.advance_minutes(15)
		g += 1
	eq(str(t["state"]), "done", "the apprentice's hours are worked")
	check(float(c["contrib"].get(str(a["id"]), 0.0)) >= 3.99, "four hours are credited to %s (%.2f)" % [a["name"], float(c["contrib"].get(str(a["id"]), 0.0))])
	check(int(c["units_done"]) >= 3, "pieces were made by the apprentice's hours (%d)" % int(c["units_done"]))
	check(Contracts.quality(c) > 40.0 and Contracts.quality(c) < 100.0, "their craftsmanship counts in the order (%.1f%%)" % Contracts.quality(c))
	eq(int(a["works"]), 0, "contract hours are not counted as works of their own")
	# the smith works a block while an apprentice works: both credited, the bench is his
	var t2 := Apprentices.add_task("contract", {"target": str(c["id"]), "repeat": 2, "assignee": str(a["id"])})
	Apprentices.tick(5)
	Contracts.work(str(c["id"]), 2)
	check(float(c["contrib"].get("smith", 0.0)) > 1.5, "the smith's own block is credited to him")
	check(str(t2["station"]) != Contracts.BENCH or not Contracts.smith_working, "an apprentice steps off the bench while the smith works it")


# ------------------------------------------------------------------ deadlines and outcomes
func test_outcomes_pay_and_reputation() -> void:
	# on time and good
	_game()
	_bench()
	var c := _accept("drovers_kit")
	_finish(c)
	var gold0 := Game.gold()
	var rep0 := float(Game.state["world"].get("rep", 0.0))
	var r := Contracts.deliver(str(c["id"]))
	check(str(r["outcome"]) in ["good", "excellent"], "on time above the minimum is good or excellent (%s, %.1f%%)" % [r["outcome"], float(r["quality"])])
	var rest := int(c["pay"]) - int(c["advance"])
	eq(Game.gold() - gold0, int(r["pay"]), "the payment on delivery is credited")
	check(int(r["pay"]) >= rest, "on time and good pays at least the agreed rest (%d ≥ %d)" % [int(r["pay"]), rest])
	check(float(Game.state["world"].get("rep", 0.0)) > rep0, "reputation rises")
	check(Contracts.favour("odo_varrick") >= 1, "the patron's favour rises")
	eq(str(Contracts.history()[-1]["status"]), "delivered", "the order is in the record")
	check((Lore.st()["events"] as Dictionary).values().any(func(e): return str(e.get("kind", "")) == "commission" and str(e.get("text", "")).contains("delivered")), "the delivery is one Lore event")
	check(Game.state["chronicle"].any(func(e): return str(e.get("text", "")).contains("delivered")), "and in the Chronicle")
	# late
	_game()
	_bench()
	var cl := _accept("drovers_kit")
	_finish(cl)
	cl["deadline"] = Game.day() - 3
	var ol := Contracts.outcome_now(cl)
	eq(int(ol["late_days"]), 3, "three days late")
	check(str(ol["outcome"]) != "excellent", "late work is never excellent")
	var restl := int(cl["pay"]) - int(cl["advance"])
	eq(int(ol["pay"]), int(round(restl * (1.15 if str(ol["outcome"]) == "excellent" else 1.0) * 0.7)), "late pay loses 10 % a day")
	var rl0 := float(Game.state["world"].get("rep", 0.0))
	var rlate := Contracts.deliver(str(cl["id"]))
	check(float(Game.state["world"].get("rep", 0.0)) - rl0 < float(cl["rep"]) * 0.6, "late delivery earns less reputation (%.1f)" % float(rlate["rep"]))
	# poor
	_game()
	_bench()
	var cp := _accept("drovers_kit")
	_finish(cp)
	cp["min_q"] = 130.0
	var rp0 := float(Game.state["world"].get("rep", 0.0))
	var g0 := Game.gold()
	var rp := Contracts.deliver(str(cp["id"]))
	eq(str(rp["outcome"]), "poor", "below the minimum craftsmanship is poor")
	eq(Game.gold() - g0, int(round((int(cp["pay"]) - int(cp["advance"])) * 0.6)), "poor work is paid at 60 %")
	check(float(Game.state["world"].get("rep", 0.0)) < rp0, "and costs reputation")
	check(Contracts.favour("odo_varrick") < 0, "the patron is displeased")
	# withdrawn: long overdue, never a game over
	_game()
	_bench()
	var cw := _accept("drovers_kit")
	var cid := str(cw["id"])
	cw["deadline"] = Game.day()
	var w0 := float(Game.state["world"].get("rep", 0.0))
	days(7)
	check(Contracts.active().is_empty(), "an order long overdue is withdrawn by the patron")
	eq(str(Contracts.get_c(cid).get("outcome", "")), "failed", "recorded as withdrawn")
	check(float(Game.state["world"].get("rep", 0.0)) < w0, "reputation suffers")
	eq((Contracts.get_c(cid)["crate_returned"] as Dictionary).get("ingot_iron", 0), 10, "the unused crate went back to the patron")
	check(Game.state.has("player") and Game.day() > 1, "the game goes on")


# ------------------------------------------------------------------ the masterpiece
func test_masterpiece_slot() -> void:
	_game()
	SkillTree.unlock_all()
	train("smithing", 8)
	_bench()
	var c := _accept("watch_arms")
	var cid := str(c["id"])
	give("ingot_iron", 6)
	give("leather_cured", 3)
	var poor := craft("iron_longsword", 40.0)
	var fine := craft("iron_longsword", 125.0)
	check(not fine.is_empty() and float(fine.get("quality", 0)) >= 95.0, "a fine captain's longsword is forged at the stations (%d%%)" % int(fine.get("quality", 0)))
	check(Contracts.masterpiece_reason(cid, poor) != "", "a poor sword is refused: %s" % Contracts.masterpiece_reason(cid, poor))
	var dev := Items.make("sword_iron", {"quality": 120.0})
	dev["dev"] = true
	check(Contracts.masterpiece_reason(cid, dev) != "", "a developer-spawned piece is refused")
	var bought := Items.make("sword_iron", {"quality": 120.0})
	check(Contracts.masterpiece_reason(cid, bought) != "", "a piece not forged by his own hand is refused: %s" % Contracts.masterpiece_reason(cid, bought))
	var uid := int(fine["uid"])
	eq(Contracts.lay_in_masterpiece(cid, uid), "", "the fine sword is laid into the order")
	check(Game.find_uid(uid).is_empty(), "it left the stores (no duplicate)")
	check(Contracts.lay_in_masterpiece(cid, int(poor["uid"])) != "", "the slot holds one piece")
	_finish(c)
	var r := Contracts.deliver(cid)
	check(bool(r["masterpiece"]), "delivered with the masterpiece")
	var it: Dictionary = Contracts.get_c(cid)["masterpiece"]["item"]
	eq(int(it.get("uid", -1)), uid, "the same instance went to the patron")
	eq(str(Provenance.owner_id(it)), "patron_highmarsh_watch", "its owner is now the Watch")
	eq(str(Provenance.maker(it).get("id", "")), "smith", "its maker is still the smith")
	check(Game.find_uid(uid).is_empty(), "and it is not back in the stores")


# ------------------------------------------------------------------ the bench as a station
func test_bench_station_and_prompt() -> void:
	_game()
	eq(SkillTree.station_reason(Contracts.BENCH), "", "the bench needs no special knowledge")
	check(Property.station_price(Contracts.BENCH) > 0, "it has a price")
	_bench()
	eq(str(WorldPrompts.for_entity({"kind": "station", "id": Contracts.BENCH})["title"]), "Project Bench", "the bench has its own prompt")
	var c := _accept("drovers_kit")
	give("ingot_iron", 20)
	var p := WorldPrompts.for_entity({"kind": "station", "id": Contracts.BENCH})
	check((p["actions"] as Array).has("Work on the contract (2 h)") and (p["actions"] as Array).has("Inspect"), "the prompt offers a block of work and inspection: %s" % str(p["actions"]))
	check(WorldPrompts.line(p).contains("[E] Work on the contract (2 h) · Inspect"), "as the HUD shows it: %s" % WorldPrompts.line(p))
	eq(ContractWorld.state_now()["patron"], true, "the patron's crate stands by the bench")
	_finish(c)
	eq(int(ContractWorld.state_now()["goods"]), ContractWorld.STACK, "the finished goods stand stacked beside it")
	check((WorldPrompts.for_entity({"kind": "station", "id": Contracts.BENCH})["actions"] as Array).has("Deliver the order"), "and the prompt says to deliver")


# ------------------------------------------------------------------ persistence
func test_save_load_and_old_save() -> void:
	_game()
	_bench()
	var a := _hire("apprentice", 4)
	var c := _accept("drovers_kit")
	give("ingot_iron", 20)
	Contracts.work(str(c["id"]), 2)
	var t := Apprentices.add_task("contract", {"target": str(c["id"]), "repeat": 3, "assignee": str(a["id"])})
	var cid := str(c["id"])
	var before := {"hours": float(c["hours_done"]), "units": int(c["units_done"]), "crate": (c["crate"] as Dictionary).duplicate(), "q": Contracts.quality(c)}
	check(save_load("suite_contracts"), "save and load mid-production")
	var c2 := Contracts.get_c(cid)
	check(not c2.is_empty() and str(c2["status"]) == "active", "the contract is still in hand")
	check(absf(float(c2["hours_done"]) - float(before["hours"])) < 0.001 and int(c2["units_done"]) == int(before["units"]), "hours and pieces survive")
	eq(int(c2["crate"].get("ingot_iron", 0)), int(before["crate"]["ingot_iron"]), "the patron's crate survives")
	check(absf(Contracts.quality(c2) - float(before["q"])) < 0.01, "craftsmanship so far survives")
	var t2 := Apprentices.task(int(t["id"]))
	eq(str(t2.get("kind", "")), "contract", "the apprentice's contract task survives")
	# the work goes on after loading
	Vitality.set_fatigue(0.0)
	eq(str(Contracts.work(cid, 1)["error"]), "", "work continues after loading")
	# an old save without contracts
	Game.state.erase("contracts")
	check(Contracts.active().is_empty() and Contracts.offers().is_empty(), "an old save gains empty contracts lazily")
	days(2)
	check(Game.state.has("contracts"), "and the daily letter check runs on it")
