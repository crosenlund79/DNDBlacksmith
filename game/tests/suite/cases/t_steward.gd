## Steward Mode (Milestone S1): activation rules and the runtime-only flag; standing instructions validated and saved;
## the steward acts only through existing actions (commissions queued for apprentices and delivered, materials bought
## at open village counters within the limits, new work displayed and sold at the listed price); protected pieces
## are never touched; deferrals and sealed letters come only from real events and lead to the real matter; the world
## settles matters without the smith; the report reconciles every coin with the ledger; a save made while the steward
## runs loads with the mode OFF and nothing is caught up; seeded headless soaks of 30 and 365 days (statistics in the
## notes): no invented gold or items, no duplicate uids before and after save/load, no deadlock, the absent smith
## gains no crafting experience.
extends SuiteCase

const SMOKE := ["test_activation_and_runtime_flag", "test_instructions_validated_and_saved", "test_save_load_mid_session_mode_off",
	"test_contract_letter_deferred_and_sealed", "test_protected_pieces"]
const FIN := ["done", "failed", "cancelled"]


# ------------------------------------------------------------------ fixtures
## A seeded new game whose workshop can teach (Smithing 6, one extra workshop room), `gold` in the purse and
## `n` apprentices: the first trained to the apprentice rank (Smithing 3), the others novices. Field hirelings
## are let go so that every item entering the stores can be accounted for (their own production is not the steward's).
func _workshop(n := 2, gold := 3000, rng := 4242) -> Array:
	fresh_game("journeyman", rng)
	train("smithing", 6)
	Property.dev_grant_unit("cobbler")
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = gold
	var out := []
	for i in n:
		var g := 0
		while Apprentices.applicants().is_empty() and g < 20:
			Apprentices.refresh_applicants()
			g += 1
		var err := Apprentices.hire(0)
		if not check(err == "", "hire an apprentice (%s)" % err):
			break
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []
		out.append(a)
	if not out.is_empty():
		var a0: Dictionary = out[0]
		a0["rank"] = "apprentice"
		a0["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	Game.state["gold"] = gold
	return out


## What the village does while the steward runs: a customer who set out reaches a seat (VillageWorld does this when
## the figure arrives — Shop.mark_arrived; headless there is no world, so the soak seats them as it would).
func _seat_customers() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _hours(n: int) -> void:
	for i in n:
		Game.advance_minutes(60)
		_seat_customers()


func _all_uids() -> Dictionary:
	var out := {}
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, true):
		out[int(it.get("uid", -1))] = true
	return out


func _smith_xp() -> String:
	return JSON.stringify(Game.player_skills())


## Runs a soak of `days` days with the steward in charge and checks the hard rules. Returns the statistics.
func _soak(days: int, label: String) -> Dictionary:
	var apps := _workshop(2, 3000)
	if apps.is_empty():
		return {}
	# the smith's own pieces in the stores: a protected heirloom, a named blade, a legendary and an ordinary piece
	var heir := Items.make("sword_steel", {"quality": 96.0})
	heir["named"] = {"name": "Grandfather's Edge", "day": 1}
	Game.add_item(heir, false)
	var leg := Items.make("axe_battle", {"quality": 90.0, "rarity": "legendary"})
	Game.add_item(leg, false)
	var plain := Items.make("helm_iron", {"quality": 80.0})
	Game.add_item(plain, false)
	check(Steward.protect(int(plain["uid"])) == "", "the smith can protect an ordinary piece by hand")
	var protected_uids := [int(heir["uid"]), int(leg["uid"]), int(plain["uid"])]
	var scan0 := ItemRegistry.scan()
	eq((scan0["dup"] as Array).size(), 0, "%s: no duplicate uids before" % label)
	var before_uids := _all_uids()
	var inv0 := {}
	for it in Game.inventory():
		inv0[str(it["def"])] = int(inv0.get(str(it["def"]), 0)) + int(it.get("qty", 1))
	var xp0 := _smith_xp()
	var crafted0 := int(Game.state["stats"].get("crafted", 0))
	var gold0 := Game.gold()
	var t0 := Time.get_ticks_msec()
	if not check(Steward.activate() == "", "%s: the steward takes over" % label):
		return {}
	var o: Dictionary = Steward.orders()
	var decisions_by_month: Array = []
	var staff_by_month: Array = []
	var last_decisions := 0
	for d in days:
		_hours(24)
		if (d + 1) % 30 == 0 or d == days - 1:
			var now_dec := int(Steward.st()["acc"]["decisions"])
			decisions_by_month.append(now_dec - last_decisions)
			staff_by_month.append(Apprentices.staff().size())
			last_decisions = now_dec
	var ms := Time.get_ticks_msec() - t0
	# spending within the limits, day by day (from the steward's own purchase records)
	var by_day := {}
	var spent := 0
	for e in Steward.st()["log"]:
		if str(e["kind"]) == "buy":
			by_day[int(e["day"])] = int(by_day.get(int(e["day"]), 0)) + int(e["data"]["cost"])
	spent = int(Steward.st()["acc"]["spent"])
	for dd in by_day:
		check(int(by_day[dd]) <= int(o["daily_limit"]), "%s: day %d spending %d within the daily limit %d" % [label, int(dd), int(by_day[dd]), int(o["daily_limit"])])
	check(spent <= int(o["session_limit"]), "%s: total spending %d within the session limit" % [label, spent])
	for e in Steward.st()["log"]:
		if str(e["kind"]) == "buy":
			check(int(e["data"].get("gold_after", 0)) >= int(o["reserve"]), "%s: the purchase on day %d kept the reserve" % [label, int(e["day"])])
	var acc: Dictionary = (Steward.st()["acc"] as Dictionary).duplicate(true)
	var r := Steward.deactivate()
	check(not Steward.is_active(), "%s: the smith takes the workshop back" % label)
	# the report is truthful: every coin explained by ledger lines of the time away
	check(bool(r["gold"]["reconciled"]), "%s: gold change %d == the sum of the session's ledger lines (unexplained %d)" % [label, int(r["gold"]["change"]), int(r["gold"]["unexplained"])])
	eq(int(r["gold"]["change"]), Game.gold() - gold0, "%s: the report's gold change is the real change" % label)
	eq(int(r["production"]["made_count"]), (acc["made"] as Array).size(), "%s: the report counts every piece made" % label)
	eq(int(r["sales"]["count"]), int(acc["by_kind"].get("sell", 0)), "%s: the report counts every sale the steward made" % label)
	# no invented items: every new uid in the stores is a piece the workshop made in the session
	var made := {}
	for u in acc["made"]:
		made[int(u)] = true
	for it in Game.inventory():
		var u2 := int(it.get("uid", -1))
		if Items.is_equipment(it) and not before_uids.has(u2):
			check(made.has(u2), "%s: %s (uid %d) entered the stores through apprentice work" % [label, str(it["name"]), u2])
	# … and stackable materials grew by no more than was bought, prepared or delivered by Aldric
	var bought: Dictionary = acc["bought"]
	var produced: Dictionary = acc.get("produced", {})
	var prov: Dictionary = acc.get("provisions", {})
	var inv1 := {}
	for it3 in Game.inventory():
		inv1[str(it3["def"])] = int(inv1.get(str(it3["def"]), 0)) + int(it3.get("qty", 1))
	for d3 in inv1:
		if Items.is_equipment({"def": str(d3)}):
			continue
		var grew := int(inv1[d3]) - int(inv0.get(d3, 0))
		var allowed := int((bought.get(d3, [0, 0]) as Array)[0]) + int(produced.get(d3, {}).get("max", 0)) + int(prov.get(d3, 0))
		check(grew <= allowed, "%s: %s grew by %d (bought/prepared/provisions allow %d)" % [label, str(d3), grew, allowed])
	# protected pieces untouched
	for pu in protected_uids:
		var pit := Game.find_uid(int(pu))
		check(not pit.is_empty() and not bool(pit.get("for_sale", false)), "%s: protected piece %d is still in the stores, not on display" % [label, int(pu)])
	# the absent smith gained no crafting experience and made nothing himself
	eq(_smith_xp(), xp0, "%s: the smith's skills are unchanged" % label)
	eq(int(Game.state["stats"].get("crafted", 0)), crafted0, "%s: the smith crafted nothing" % label)
	# identity: no duplicates now, nor after a save/load round trip
	eq((ItemRegistry.scan()["dup"] as Array).size(), 0, "%s: no duplicate uids after" % label)
	check(save_load("steward_soak_" + label), "%s: save and load after the soak" % label)
	eq((ItemRegistry.scan()["dup"] as Array).size(), 0, "%s: no duplicate uids after save/load" % label)
	check(not Steward.is_active(), "%s: still off after loading" % label)
	# no deadlock: while there are hands in the workshop, something meaningful happens every month (the steward
	# never hires — when the apprentices have all left, it keeps the shop, the provisions and the deferrals)
	for i in decisions_by_month.size():
		if int(staff_by_month[i]) > 0:
			check(int(decisions_by_month[i]) >= 10, "%s: the steward acted in period %d (%d decisions)" % [label, i + 1, int(decisions_by_month[i])])
		else:
			check(int(decisions_by_month[i]) > 0, "%s: with no apprentices left the steward still keeps house in period %d" % [label, i + 1])
	var stall_txt := PackedStringArray()
	for sline in r["decisions"]["stalls"]:
		stall_txt.append("%s×%d (%s)" % [sline["code"], int(sline["count"]), str(sline["text"]).left(70)])
	var kinds := PackedStringArray()
	var bk: Array = (r["decisions"]["by_kind"] as Dictionary).keys()
	bk.sort()
	for k in bk:
		kinds.append("%s %d" % [k, int(r["decisions"]["by_kind"][k])])
	var cats := PackedStringArray()
	for c in r["gold"]["by_category"]:
		cats.append("%s %+d" % [c, int(r["gold"]["by_category"][c])])
	var staff := PackedStringArray()
	for a in r["staff"]["current"]:
		staff.append("%s %s→%s (+%d works)" % [a["name"], a["rank_before"], a["rank"], int(a["works"])])
	note("%s soak: %d days in %.1f s (%.0f ms/day)" % [label, days, ms / 1000.0, float(ms) / days])
	note("%s decisions %d — %s" % [label, int(r["decisions"]["total"]), ", ".join(kinds)])
	note("%s orders: committed %d, delivered %d, declined %d, still open %d" % [label, int(r["orders"]["counts"]["accepted"]),
		int(r["orders"]["counts"]["delivered"]), int(r["orders"]["counts"]["declined"]), int(r["orders"]["counts"]["pending"])])
	note("%s production: %s; pieces made %d; failed %d" % [label, JSON.stringify(r["production"]["completed"]), int(r["production"]["made_count"]), int(r["production"]["failed"])])
	note("%s purchases %d g (%d kinds); steward sales %d for %d g; all display/counter sales in the ledger %d g; listed %d" % [label,
		int(r["purchases"]["total"]), (r["purchases"]["items"] as Array).size(), int(r["sales"]["count"]), int(r["sales"]["gold"]), int(r["sales"]["ledger_sales"]), int(r["sales"]["listed"])])
	note("%s gold %d → %d (income %d, expenses %d; %s); reconciled %s over %d ledger lines" % [label, int(r["gold"]["start"]), int(r["gold"]["end"]),
		int(r["gold"]["income"]), int(r["gold"]["expenses"]), ", ".join(cats), str(r["gold"]["reconciled"]), int(r["gold"]["lines"])])
	note("%s stalls: %s" % [label, ", ".join(stall_txt) if not stall_txt.is_empty() else "none"])
	note("%s deferrals %s; open now %d, sealed letters %d, lapsed without you %d; world events (Lore ≥2) %d" % [label,
		JSON.stringify(r["decisions"]["deferrals"]), (r["deferred"] as Array).size(), (r["letters"] as Array).size(), (r["lapsed"] as Array).size(), int(r["world"]["count"])])
	note("%s staff: %s; left %d" % [label, ", ".join(staff), (r["staff"]["left"] as Array).size()])
	note("%s failures: %s" % [label, JSON.stringify(r["production"]["failed_why"])])
	var left_txt := PackedStringArray()
	for lf in r["staff"]["left"]:
		left_txt.append("%s day %d" % [str(lf["how"]), int(lf["day"])])
	note("%s left: %s; sealed letters: %s" % [label, ", ".join(left_txt), JSON.stringify((r["letters"] as Array).map(func(x): return str(x["kind"])))])
	note("%s per-month decisions %s (apprentices %s); scan %s" % [label, str(decisions_by_month), str(staff_by_month), ItemRegistry.scan_text(ItemRegistry.scan())])
	return r


# ------------------------------------------------------------------ activation
func test_activation_and_runtime_flag() -> void:
	_workshop(1)
	check(not Steward.is_active() and not Steward.smith_away(), "a new game starts without the steward")
	check(not Game.state.has("steward"), "an untouched game has no steward state (old saves load unchanged)")
	check(Crafting.start("iron_shortsword"), "the smith starts a piece")
	check(Steward.can_activate() != "", "no hand-over in the middle of a craft (%s)" % Steward.can_activate())
	check(Steward.activate() != "" and not Steward.is_active(), "activation refused mid-craft")
	Crafting.cancel()
	eq(Steward.can_activate(), "", "the hand-over is allowed at rest")
	eq(Steward.activate(), "", "the steward takes over")
	check(Steward.is_active() and Steward.smith_away(), "active; the smith is away")
	check(Steward.activate() != "", "no second activation")
	var st0: Dictionary = Steward.status()
	check(bool(st0["active"]) and int(st0["since_day"]) == Game.day(), "the live status reports the session")
	_hours(6)
	check(int(Steward.status()["elapsed_minutes"]) == 360, "time runs while the steward works (%d)" % int(Steward.status()["elapsed_minutes"]))
	var r := Steward.deactivate()
	check(not Steward.is_active(), "the smith takes the workshop back")
	eq(str(r.get("ended", "")), "returned", "the report says the smith returned")
	eq(int(r["elapsed_minutes"]), 360, "the report covers the six hours away")
	eq(Steward.last_report().get("elapsed_minutes", -1), 360, "the report is kept")
	# off: ticking does nothing
	var n := (Steward.st()["log"] as Array).size()
	_hours(24)
	eq((Steward.st()["log"] as Array).size(), n, "with the mode off the steward records and does nothing")


func test_instructions_validated_and_saved() -> void:
	_workshop(1)
	var o := Steward.orders()
	check(int(o["daily_limit"]) > 0 and int(o["reserve"]) > 0 and (o["duties"] as Dictionary).size() == Steward.DUTIES.size(), "sensible defaults")
	check(Steward.purchase_categories().has("Ore & metal") and Steward.purchase_categories().has("Herbs"), "categories come from the village counters")
	check(Steward.set_orders({"daily_limit": -5}) != "", "a negative limit is refused")
	check(Steward.set_orders({"buy_categories": ["Dragons"]}) != "", "an unknown category is refused")
	check(Steward.set_orders({"duties": {"conquest": true}}) != "", "an unknown duty is refused")
	check(Steward.set_orders({"reserved": {"no_such_item": 3}}) != "", "an unknown material is refused")
	check(Steward.set_orders({"bogus": 1}) != "", "an unknown instruction is refused")
	eq(int(Steward.orders()["daily_limit"]), int(o["daily_limit"]), "a refused patch changes nothing")
	eq(Steward.set_orders({"daily_limit": 60, "session_limit": 30, "reserve": 400, "buy_categories": ["Ore & metal", "Coal & fuel"],
		"duties": {"sales": false}, "reserved": {"ingot_iron": 4}, "order_rules": {"max_difficulty": 2}, "sell_rules": {"stock_target": 2}}), "", "a valid patch applies")
	var o2 := Steward.orders()
	check(int(o2["daily_limit"]) == 60 and int(o2["session_limit"]) == 60, "the session limit is never below the daily one")
	check(not bool(o2["duties"]["sales"]) and bool(o2["duties"]["orders"]), "duties switch one by one")
	eq(Steward.reserve("coal", 5), "", "a reserved supply")
	var sw := Items.make("sword_iron", {"quality": 70.0})
	Game.add_item(sw, false)
	eq(Steward.protect(int(sw["uid"])), "", "protect by uid")
	check(Steward.protect(999999) != "", "an unknown piece cannot be protected")
	check(save_load("steward_orders"), "save and load")
	var o3 := Steward.orders()
	check(int(o3["reserve"]) == 400 and int(o3["reserved"]["coal"]) == 5 and int(o3["reserved"]["ingot_iron"]) == 4, "instructions survive save/load")
	check((o3["protected"] as Array).has(int(sw["uid"])), "protection survives save/load")
	eq(Steward.protection_reason(Game.find_uid(int(sw["uid"]))), "You marked it as protected.", "the reason is given")


func test_save_load_mid_session_mode_off() -> void:
	_workshop(2)
	eq(Steward.activate(), "", "the steward takes over")
	_hours(48)
	check(Steward.is_active(), "running")
	check(Saves.save("steward_mid"), "save while the steward runs")
	var saved_now := Game.now()
	var saved_gold := Game.gold()
	var saved_dec := int(Steward.st()["acc"]["decisions"])
	_hours(24)   # the session carries on in this process…
	check(Saves.load_slot("steward_mid"), "…then the save is loaded")
	check(not Steward.is_active() and not Steward.smith_away(), "a loaded save starts with the mode OFF")
	eq(Game.now(), saved_now, "no time was added on load (no catch-up)")
	eq(Game.gold(), saved_gold, "no gold was added on load (no catch-up)")
	var lr := Steward.last_report()
	eq(str(lr.get("ended", "")), "closed", "the saved session was closed on load")
	check(bool(lr["gold"]["reconciled"]), "the closed session's report reconciles")
	var pr := Steward.take_pending_report()
	check(not pr.is_empty() and Steward.take_pending_report().is_empty(), "its report is offered once after loading")
	check((Steward.st()["log"] as Array).any(func(e): return str(e["kind"]) == "stood_down"), "the log says the steward stood down")
	eq(int(Steward.st()["acc"]["decisions"]), saved_dec, "no steward action happened on load")
	# normal play afterwards: time moves, the steward does nothing
	var n_log := (Steward.st()["log"] as Array).size()
	var by_kind: Dictionary = Steward.stats()["by_kind"]
	_hours(48)
	eq((Steward.st()["log"] as Array).size(), n_log, "no steward actions after loading")
	eq(JSON.stringify(Steward.stats()["by_kind"]), JSON.stringify(by_kind), "no steward decisions after loading")
	eq(Game.now(), saved_now + 48 * 60, "time moves only by normal play")
	Saves.delete("steward_mid")


# ------------------------------------------------------------------ duties
func test_commission_queued_made_and_delivered() -> void:
	var apps := _workshop(1)
	var adv := {}
	for id in Adv.all().keys():
		var a := Adv.get_a(str(id))
		if str(a["status"]) == "in_town" and not Shop.refuses(str(id)):
			adv = a
			break
	if not check(not adv.is_empty(), "an adventurer in town"):
		return
	# a commission for an exact ordinary piece — the shape Shop.accept_part creates when a counter part is accepted
	var oid := "ord_%d" % Game.new_uid()
	Shop.orders().append({"id": oid, "npc": str(adv["id"]), "slot": "weapon", "stat": "attack", "min": 0, "tier": 1, "def": "sword_short",
		"recipe": "iron_shortsword", "reward": 70, "deadline": Game.day() + 4, "status": "open", "placed": Game.day(), "priority": "quality"})
	give("ingot_iron", 2)
	give("leather_cured", 2)
	var g0 := Game.gold()
	eq(Steward.activate(), "", "the steward takes over")
	_hours(2)
	var t := Steward._commission_task(oid)
	check(not t.is_empty(), "the steward committed the workshop to the commission")
	check((Steward.st()["log"] as Array).any(func(e): return str(e["kind"]) == "commit"), "the decision is logged")
	var g := 0
	while str(Steward._order(oid).get("status", "")) == "open" and g < 96:
		_hours(1)
		g += 1
	eq(str(Steward._order(oid).get("status", "")), "done", "the apprentice made it and the steward delivered it")
	var r := Steward.deactivate()
	eq(int(r["orders"]["counts"]["delivered"]), 1, "the report lists the delivery")
	check(int(r["gold"]["by_category"].get("commissions", 0)) > 0, "the reward is a ledger line (commissions %d)" % int(r["gold"]["by_category"].get("commissions", 0)))
	check(bool(r["gold"]["reconciled"]), "the gold reconciles")
	var delivered := int(Steward._order(oid).get("delivered_uid", -1))
	var it := ItemRegistry.find(delivered)
	check(not it.is_empty() and str(Provenance.maker(it).get("id", "")) == str(apps[0]["id"]), "the piece carries the apprentice as maker")
	check(Game.gold() != g0, "money moved only through ledger lines")


func test_replenish_within_limits_at_open_counters() -> void:
	_workshop(2)
	# empty the stores of iron: the planned work needs bought ore and coal
	for d in ["ingot_iron", "ore_iron", "coal"]:
		Game.remove_def(d, Game.count(d))
	eq(Steward.set_orders({"daily_limit": 40, "session_limit": 100, "sell_rules": {"stock_target": 2}}), "", "tight limits")
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 6)
	var buys := (Steward.st()["log"] as Array).filter(func(e): return str(e["kind"]) == "buy")
	check(not buys.is_empty(), "materials were bought (%d purchases)" % buys.size())
	var by_day := {}
	for b in buys:
		by_day[int(b["day"])] = int(by_day.get(int(b["day"]), 0)) + int(b["data"]["cost"])
		var h := int(str(b["time"]).split(":")[0])
		check(h >= 7 and h < 19, "bought while the counter was open (%s)" % str(b["time"]))
	for d2 in by_day:
		check(int(by_day[d2]) <= 40, "day %d spending %d ≤ 40" % [int(d2), int(by_day[d2])])
	check(int(Steward.st()["acc"]["spent"]) <= 100, "session spending within its limit")
	var r := Steward.deactivate()
	eq(int(r["purchases"]["total"]), int(Steward.st()["acc"]["spent"]), "the report's purchases are the steward's spending")
	check(int(r["gold"]["by_category"].get("materials", 0)) <= -int(r["purchases"]["total"]), "purchases are ledger lines (materials %d)" % int(r["gold"]["by_category"].get("materials", 0)))
	check(bool(r["gold"]["reconciled"]), "the gold reconciles")


func test_protected_pieces() -> void:
	_workshop(1)
	var named := Items.make("sword_iron", {"quality": 80.0})
	named["named"] = {"name": "Oathkeeper", "day": 1}
	var leg := Items.make("sword_iron", {"quality": 80.0, "rarity": "legendary"})
	var epic := Items.make("sword_iron", {"quality": 80.0})
	epic["epic"] = {"day": 1, "deed": "held the bridge"}
	var plain := Items.make("sword_iron", {"quality": 80.0})
	for it in [named, leg, epic, plain]:
		Game.add_item(it, false)
	check(Steward.protection_reason(named) != "" and Steward.protection_reason(leg) != "" and Steward.protection_reason(epic) != "", "named, legendary and Epic pieces are protected")
	eq(Steward.protection_reason(plain), "", "an ordinary piece is not")
	eq(Steward.set_orders({"sell_rules": {"list_existing": true}}), "", "the smith allows listing his ordinary pieces")
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 3)
	for it2 in [named, leg, epic]:
		var x := Game.find_uid(int(it2["uid"]))
		check(not x.is_empty() and not bool(x.get("for_sale", false)), "%s stays in the stores, off the display" % str(it2["name"]))
	Steward.deactivate()


func test_contract_letter_deferred_and_sealed() -> void:
	_workshop(1)
	eq(Steward.activate(), "", "the steward takes over")
	var c := Contracts.make_offer("queens_guard")
	var c2 := Contracts.make_offer("drovers_kit")
	_hours(1)
	var defs := Steward.deferred().filter(func(e): return str(e["kind"]) == "contract")
	eq(defs.size(), 2, "both letters are left for the smith")
	var royal := defs.filter(func(e): return str(e["source"]["id"]) == str(c["id"]))
	check(not royal.is_empty() and bool(royal[0]["sealed"]), "the Royal Household's letter is sealed")
	var plain := defs.filter(func(e): return str(e["source"]["id"]) == str(c2["id"]))
	check(not plain.is_empty() and not bool(plain[0]["sealed"]), "a merchant's letter is not sealed")
	check(Contracts.offers().size() == 2, "the steward neither accepts nor declines a major contract")
	var letters := Steward.letters()
	eq(letters.size(), 1, "one sealed letter waits")
	var l := Steward.open_letter(str(letters[0]["id"]))
	check(str(l["action"]["route"]) == "contracts" and str(l["action"]["args"]["id"]) == str(c["id"]), "the letter leads to the actual offer")
	check(Steward.letters().is_empty(), "opened letters leave the unopened pile")
	# the world is not frozen: unanswered offers lapse on their own
	_hours(24 * 7)
	var after := Steward.deferred(true).filter(func(e): return str(e["kind"]) == "contract" and str(e["source"]["id"]) in [str(c["id"]), str(c2["id"])])
	check(after.all(func(e): return bool(e["resolved"]) and str(e.get("resolved_by", "")) == "world"), "the offers lapsed without the smith and are marked so")
	var r := Steward.deactivate()
	check((r["lapsed"] as Array).size() >= 2, "the report lists what lapsed")


func test_notice_visitor_and_lore_deferrals() -> void:
	var apps := _workshop(1)
	var mine := craft("iron_shortsword")   # the smith's own piece, before he leaves
	check(not mine.is_empty(), "the smith made a blade")
	eq(Steward.activate(), "", "the steward takes over")
	# an apprentice's independence notice (a real notice)
	Apprentices.give_notice(apps[0])
	# an adventurer comes for advice (Consult) and sits down
	var cu := Consult.approach("sigrun")
	_seat_customers()
	# the smith's blade earns Epic distinction out in the world (a real Lore event)
	Recognition.grant_epic(mine, "held the ford alone")
	_hours(1)   # matters are gathered every quarter hour (visitors) and on the hour (letters, notices, Lore)
	var kinds := Steward.deferred().map(func(e): return str(e["kind"]))
	check(kinds.has("notice"), "the independence notice is deferred")
	check(cu.is_empty() or kinds.has("visitor"), "the advice visitor is deferred")
	check(kinds.has("deed"), "the Epic deed of the smith's piece is deferred")
	var sealed := Steward.letters().map(func(e): return str(e["kind"]))
	check(sealed.has("notice") and sealed.has("deed"), "independence and the Epic deed arrive as sealed letters (%s)" % str(sealed))
	check(not sealed.has("visitor"), "an ordinary visitor is not a sealed letter")
	var deed := Steward.letters().filter(func(e): return str(e["kind"]) == "deed")
	var l := Steward.open_letter(str(deed[0]["id"]))
	check(str(l["action"]["route"]) == "history" and str(l["action"]["args"]["id"]) == str(mine["uid"]), "the deed letter opens the piece's history")
	eq(Steward.resolve(str(deed[0]["id"])), "", "the smith marks it seen to")
	check(not Steward.deferred().any(func(e): return str(e["id"]) == str(deed[0]["id"])), "resolved matters leave the list")
	# no invented triggers: nothing else became a letter
	check(Steward.letters().size() <= 2, "letters only from real events")
	# the visitor leaves on their own schedule
	_hours(6)
	if not cu.is_empty():
		var v := Steward.deferred(true).filter(func(e): return str(e["kind"]) == "visitor")
		check(not v.is_empty() and bool(v[0]["resolved"]), "the visitor left; the matter lapsed (%s)" % str(v[0].get("outcome", "")) if not v.is_empty() else "visitor entry")
	check(save_load("steward_defer"), "save and load")
	check(not Steward.deferred(true).is_empty(), "deferred matters survive save/load")
	eq((ItemRegistry.scan()["stray"] as Array).size(), 0, "the steward's records hold no item copies")


func test_reserve_stops_spending() -> void:
	_workshop(2, 200)
	for d in ["ingot_iron", "ore_iron", "coal"]:
		Game.remove_def(d, Game.count(d))
	eq(Steward.set_orders({"reserve": 1000}), "", "a reserve above the purse")
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 2)
	var buys := (Steward.st()["log"] as Array).filter(func(e): return str(e["kind"]) == "buy")
	for b in buys:
		check(int(b["data"].get("gold_after", 0)) >= 1000, "a purchase never takes the purse below the reserve")
	check(buys.is_empty() or Game.gold() >= 1000, "nothing bought while the purse is below the reserve (%d purchases)" % buys.size())
	var r := Steward.deactivate()
	check((r["decisions"]["stalls"] as Array).any(func(s): return str(s["code"]) == "reserve"), "the stall at the reserve is recorded with its reason")


# ------------------------------------------------------------------ soaks
func test_soak_30_days() -> void:
	var r := _soak(30, "30d")
	if r.is_empty():
		return
	check(int(r["decisions"]["total"]) > 20, "the steward is busy over a month (%d decisions)" % int(r["decisions"]["total"]))
	check(int(r["production"]["made_count"]) > 0, "the workshop produced while the smith was away")


func test_soak_365_days() -> void:
	var r := _soak(365, "365d")
	if r.is_empty():
		return
	check(int(r["production"]["made_count"]) > 20, "a year of production (%d pieces)" % int(r["production"]["made_count"]))
	check(int(r["sales"]["count"]) + int(r["orders"]["counts"]["delivered"]) > 0, "a year of sales or deliveries")


## S1 (lead): while the smith is away his fatigue neither rises nor falls; after return it moves normally again.
func test_fatigue_holds_while_away() -> void:
	fresh_game()
	Vitality.set_fatigue(30.0)
	if not check(Steward.activate() == "", "the steward takes over"):
		return
	Game.advance_minutes(48 * 60)
	eq(snappedf(Vitality.fatigue(), 0.01), 30.0, "two days away: fatigue unchanged")
	Steward.deactivate()
	Game.advance_minutes(3 * 60)
	check(Vitality.fatigue() > 30.0, "back at the forge, waking hours tire him again (%.1f)" % Vitality.fatigue())


## S1 (lead): a contract letter that arrives while the smith is away does not reveal its contents in the toast,
## journal or Chronicle — only its sender; the offer itself is real and waits for him.
func test_letter_contents_stay_sealed_while_away() -> void:
	fresh_game()
	if not check(Steward.activate() == "", "the steward takes over"):
		return
	var c := Contracts.make_offer("queens_guard", "test")
	if not check(not c.is_empty(), "a real offer arrives"):
		return
	var title := str(c["title"])
	var leaked := false
	for e in Game.state.get("chronicle", []):
		if str(e.get("text", "")).contains(title):
			leaked = true
	for j in Game.state.get("journal", []):
		if str(j if j is String else j.get("text", "")).contains(title):
			leaked = true
	check(not leaked, "the letter's subject is not revealed while sealed")
	var announced := (Game.state.get("journal", []) as Array).any(func(j): return str(j.get("text", "")).contains("left a sealed letter from"))
	check(announced, "its arrival is recorded — sender only")
	check(Contracts.offers().any(func(o): return str(o["id"]) == str(c["id"])), "the offer itself is real and waiting")
	Steward.deactivate()
