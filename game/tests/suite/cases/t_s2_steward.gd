## Steward Mode S2 — the autonomous working smith and the steward's pace (lead brief: STEWARD worker).
## The smith himself works under the steward through the existing actions (Crafting.start / record_step / build,
## Shop.do_repair / repair_part, Shop.fulfil through the steward): an early-game smith alone, with the starting
## gold and materials, makes real routine pieces from real materials in real time; repairs at the counter are paid by
## the customer; an ordinary commission is made and delivered by him; restocking keeps within the spending limits;
## with apprentices and changing demand the work is shared; zero experience across activation, completion, exit and
## save/load (including a piece begun under the steward and finished after the return or after loading); working
## hours, breaks, rest when tired and sleep at night; never above the craftsmanship cap, never a masterpiece,
## refinement, secret Design or protected piece; the pace is 1.5× while active, restored at once on exit and on load,
## and headless runs stay deterministic; the ledger reconciles; ItemRegistry.scan and Uniques.audit stay clean.
## Soaks: a poor early game (starting resources, no apprentices) for 30 and 365 days (statistics in the notes).
extends SuiteCase

const SMOKE := ["test_activation_needs_no_skill", "test_early_smith_alone_does_real_work", "test_zero_xp_across_exit_and_save_load",
	"test_pace_on_restored_on_exit_and_load"]
## Long-running tests left out of `run_tests.sh quick` (they still run in full and in CI).
const SLOW := ["test_soak_poor_early_365_days"]


# ------------------------------------------------------------------ fixtures
## A genuine new game as the player finds it (starting gold and materials, no apprentices); field hirelings are let
## go so that every item entering the stores can be accounted for.
func _early(rng := 9001) -> void:
	fresh_game("journeyman", rng)
	(Game.state["hirelings"] as Array).clear()


func _seat() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _hours(n: int) -> void:
	for i in n:
		Game.advance_minutes(60)
		_seat()


func _skills() -> String:
	return JSON.stringify(Game.player_skills())


func _smith_log(kind: String) -> Array:
	return (Steward.st()["log"] as Array).filter(func(e): return str(e["kind"]) == kind)


func _clean(label: String) -> void:
	var sc := ItemRegistry.scan()
	eq((sc["dup"] as Array).size(), 0, "%s: no duplicate uids" % label)
	eq((sc["stray"] as Array).size(), 0, "%s: no stray item copies" % label)
	eq(Uniques.audit().size(), 0, "%s: Uniques.audit is clean" % label)


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	Shop.remove_customer(id)
	return a


func _durable_slot(a: Dictionary) -> String:
	for s in a["equipment"]:
		if (a["equipment"][s].get("stats", {}) as Dictionary).has("durability_max") and Steward.protection_reason(a["equipment"][s]) == "":
			return str(s)
	return ""


## Two apprentices (the first trained to the apprentice rank), as the S1 workshop fixture.
func _apprentices(n: int) -> void:
	train("smithing", 6)
	Property.dev_grant_unit("cobbler")
	for i in n:
		var g := 0
		while Apprentices.applicants().is_empty() and g < 20:
			Apprentices.refresh_applicants()
			g += 1
		if not check(Apprentices.hire(0) == "", "hire an apprentice"):
			return
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []
	var a0: Dictionary = Apprentices.staff()[0]
	a0["rank"] = "apprentice"
	a0["skills"]["smithing"] = {"lvl": 3, "xp": 0}


# ------------------------------------------------------------------ activation
func test_activation_needs_no_skill() -> void:
	_early()
	check(Apprentices.staff().is_empty() and Game.player_level("smithing") == 4, "a new smith: Smithing 4, no apprentices")
	eq(Steward.can_activate(), "", "no skill, level or staff is needed to hand over")
	check(Crafting.start("hand_axe"), "the smith starts a piece of his own")
	check(Steward.can_activate() != "", "with his own piece in hand the hand-over is refused (%s)" % Steward.can_activate())
	Crafting.cancel()
	eq(Steward.activate(), "", "the steward takes over a brand-new forge")
	_hours(3)   # 7:30 → 10:30: he is at work
	check(Crafting.active() and Steward.marked(Crafting.job()), "the smith has a piece in hand, begun under the steward")
	Steward.deactivate()
	eq(Steward.can_activate(), "", "a piece the steward's smith left in his hands does not stop the next hand-over")
	eq(Steward.activate(), "", "he hands over again")
	_hours(4)
	Steward.deactivate()


# ------------------------------------------------------------------ the early-game smith alone
func test_early_smith_alone_does_real_work() -> void:
	_early()
	var inv0 := {}
	for it in Game.inventory():
		inv0[str(it["def"])] = int(inv0.get(str(it["def"]), 0)) + int(it.get("qty", 1))
	var xp0 := _skills()
	var gold0 := Game.gold()
	var crafted0 := int(Game.state["stats"]["crafted"])
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 4)
	var acc: Dictionary = (Steward.st()["acc"]["smith"] as Dictionary).duplicate(true)
	var r := Steward.deactivate()
	var sm: Dictionary = r["smith"]
	check(int(sm["made_count"]) >= 4, "four days alone: he made real pieces (%d)" % int(sm["made_count"]))
	check(int(sm["minutes"]) > 4 * 6 * 60, "he spent real working time at the stations (%s)" % str(sm["hours_text"]))
	check(int(sm["ops"]) >= 3 * int(sm["made_count"]) - 3, "every piece went through its operations (%d ops)" % int(sm["ops"]))
	eq(int(Game.state["stats"]["crafted"]) - crafted0, int(r["production"]["smith_crafted"]), "the report counts what he crafted")
	# every piece he made carries him as the maker, was made under the steward and stayed below the cap
	for m in sm["made"]:
		var it := ItemRegistry.find(int(m["uid"]))
		if it.is_empty():
			continue   # sold or delivered: it lives on elsewhere
		check(Provenance.is_mine(it), "%s carries the smith as its maker" % str(m["name"]))
		check(bool(it["craft"].get("steward", false)), "%s is marked as made under the steward" % str(m["name"]))
		# no anvil naming (a masterwork name at the forge); a name EARNED LATER by a real deed in an adventurer's hands
		# (e.g. a boss kill) is history, not the steward's doing, and is allowed (S2 integration: with fairer prices
		# adventurers buy and use the working smith's pieces)
		var anvil_named := ItemStory.is_named(it) and str(it["named"].get("kind", "")) == "masterwork"
		check(float(it["quality"]) <= StewardSmith.QUALITY_CAP + 0.01 and not bool(it["craft"].get("masterwork", false)) and not anvil_named,
			"%s: %.1f%%, no masterwork, no anvil name" % [str(m["name"]), float(it["quality"])])
		if ItemStory.is_named(it) and not anvil_named:
			note("%s later earned the name “%s” (%s) in an adventurer's hands" % [str(m["name"]), ItemStory.earned_name(it), str(it["named"].get("kind", ""))])
		eq(StewardSmith.recipe_ok(str(it["craft"]["recipe"])), "", "%s is a routine Design he knows" % str(m["name"]))
	# real materials: what he used came out of the stores
	var used: Dictionary = sm["used"]
	check(not used.is_empty(), "he used materials from the stores (%s)" % JSON.stringify(used))
	var inv1 := {}
	for it2 in Game.inventory():
		inv1[str(it2["def"])] = int(inv1.get(str(it2["def"]), 0)) + int(it2.get("qty", 1))
	var bought: Dictionary = Steward.st()["acc"]["bought"]
	var produced: Dictionary = Steward.st()["acc"]["produced"]
	var prov: Dictionary = Steward.st()["acc"].get("provisions", {})
	for d in used:
		var expect_max := int(inv0.get(d, 0)) + int((bought.get(d, [0, 0]) as Array)[0]) + int(produced.get(d, {}).get("max", 0)) + int(prov.get(d, 0)) - int(used[d])
		check(int(inv1.get(d, 0)) <= expect_max, "%s: the stores hold %d, no more than before + bought + prepared − used (%d)" % [d, int(inv1.get(d, 0)), expect_max])
	# work only in working hours
	for e in Steward.st()["log"]:
		if str(e["kind"]) in ["smith_begin", "smith_made", "smith_repair"]:
			var h := int(str(e["time"]).split(":")[0])
			check(h >= 8 and h < 18 and h != 12, "%s at %s is within working hours" % [str(e["kind"]), str(e["time"])])
	eq(_skills(), xp0, "no experience: his skills are exactly as he left them")
	check(int(acc.get("xp_withheld", 0)) > 0, "the guard withheld the experience the work would have given (%d)" % int(acc.get("xp_withheld", 0)))
	check(bool(sm["xp_unchanged"]), "the report says so")
	check(bool(r["gold"]["reconciled"]), "every coin is in the ledger (%d → %d)" % [gold0, Game.gold()])
	eq(int(sm["nights"]), 4, "he slept in his bed every night")
	check(int(sm["breaks"]) >= 3, "he took his midday breaks (%d)" % int(sm["breaks"]))
	_clean("early smith")
	note("early smith, 4 days: made %d (%s), repairs %d (+%d g), prepared %s, used %s, %s at the stations, gold %d → %d" % [int(sm["made_count"]),
		", ".join(PackedStringArray((sm["made"] as Array).map(func(x): return "%s %d%%" % [str(x["name"]), int(round(float(x["quality"])))]))),
		int(sm["repairs_count"]), int(sm["repair_gold"]), JSON.stringify(sm["prepared"]), JSON.stringify(used), str(sm["hours_text"]), gold0, Game.gold()])


# ------------------------------------------------------------------ repairs at the counter
func test_counter_repair_paid_by_customer() -> void:
	_early()
	Game.advance_minutes(90)   # 9:00, the shop is open
	var a := _adv("tomas")
	var slot := _durable_slot(a)
	if not check(slot != "", "Tomas wears something that can be mended"):
		return
	var it: Dictionary = a["equipment"][slot]
	it.erase("broken")
	it["stats"]["durability"] = int(float(it["stats"]["durability_max"]) * 0.2)
	a["gold"] = 300
	Shop._add_customer("tomas", "repair_own", slot)
	_seat()
	check(not Shop.customer("tomas").is_empty(), "Tomas waits at the counter with a worn piece")
	var a0 := int(a["gold"])
	var g0 := Game.gold()
	var xp0 := _skills()
	eq(Steward.activate(), "", "the steward takes over")
	_hours(3)
	var reps := _smith_log("smith_repair").filter(func(e): return str(e["data"].get("npc", "")) == "tomas")
	if not check(not reps.is_empty(), "the smith mended Tomas's piece himself"):
		return
	var paid := int(reps[0]["data"]["gold"])
	check(paid > 0, "Tomas paid for it (%d g)" % paid)
	eq(a0 - int(a["gold"]), paid, "out of his own purse")
	check(Items.durability_frac(a["equipment"][slot]) > 0.5, "the piece is mended (%.2f)" % Items.durability_frac(a["equipment"][slot]))
	check((Game.state["ledger"] as Array).any(func(l): return str(l.get("cat", "")) == "repairs" and str(l.get("party", "")) == "tomas"), "the ledger names the payer")
	check(Shop.customer("tomas").is_empty(), "Tomas went home content")
	check(Game.gold() >= g0, "the purse grew by real payments")
	eq(_skills(), xp0, "no experience from the repair")
	var r := Steward.deactivate()
	check(int(r["smith"]["repairs_count"]) >= 1 and bool(r["gold"]["reconciled"]), "the report lists the repair; the ledger reconciles")


## A protected piece (Epic) brought for mending is left for the smith's own hands, never touched by the steward.
func test_protected_repair_left_for_the_smith() -> void:
	_early()
	Game.advance_minutes(90)
	var a := _adv("sigrun")
	var slot := _durable_slot(a)
	if not check(slot != "", "Sigrun wears something that can be mended"):
		return
	var it: Dictionary = a["equipment"][slot]
	it["epic"] = {"day": 1, "deed": "held the ford"}
	it["stats"]["durability"] = int(float(it["stats"]["durability_max"]) * 0.2)
	a["gold"] = 300
	Shop._add_customer("sigrun", "repair_own", slot)
	_seat()
	if not check(not Shop.customer("sigrun").is_empty(), "Sigrun waits with her Epic piece"):
		return
	var d0 := int(it["stats"]["durability"])
	eq(Steward.activate(), "", "the steward takes over")
	_hours(2)
	eq(int(it["stats"]["durability"]), d0, "the Epic piece was not touched")
	check(Steward.deferred(true).any(func(e): return str(e["kind"]) == "repair" and str(e["source"].get("id", "")) == "sigrun"),
		"the repair of the protected piece was left for the smith")
	check(not _smith_log("smith_repair").any(func(e): return str(e["data"].get("npc", "")) == "sigrun"), "the smith did not mend it under the steward")
	Steward.deactivate()


# ------------------------------------------------------------------ a commission
func test_commission_made_by_the_smith() -> void:
	_early()
	var adv := ""
	for id in Adv.all().keys():
		if str(Adv.get_a(str(id))["status"]) == "in_town" and not Shop.refuses(str(id)):
			adv = str(id)
			break
	if not check(adv != "", "an adventurer in town"):
		return
	var oid := "ord_%d" % Game.new_uid()
	Shop.orders().append({"id": oid, "npc": adv, "slot": "weapon", "stat": "attack", "min": 0, "tier": 1, "def": "sword_short",
		"recipe": "iron_shortsword", "reward": 70, "deadline": Game.day() + 3, "status": "open", "placed": Game.day(), "priority": "quality"})
	var xp0 := _skills()
	eq(Steward.activate(), "", "the steward takes over")
	_hours(2)
	check(StewardSmith.has_order(oid), "with no apprentices the steward commits the smith himself to the commission")
	var g := 0
	while str(Steward._order(oid).get("status", "")) == "open" and g < 60:
		_hours(1)
		g += 1
	eq(str(Steward._order(oid).get("status", "")), "done", "he made it and the steward delivered it")
	var it := ItemRegistry.find(int(Steward._order(oid).get("delivered_uid", -1)))
	check(not it.is_empty() and Provenance.is_mine(it) and bool(it["craft"].get("steward", false)), "the delivered piece is his own, made under the steward")
	eq(_skills(), xp0, "no experience from the commission")
	var r := Steward.deactivate()
	check(int(r["orders"]["counts"]["delivered"]) >= 1 and int(r["gold"]["by_category"].get("commissions", 0)) > 0, "the report lists the delivery and its payment")
	check(bool(r["gold"]["reconciled"]), "the gold reconciles")


# ------------------------------------------------------------------ restocking within the limits
func test_restock_within_limits() -> void:
	_early()
	Game.state["gold"] = 400
	for d in ["ingot_iron", "ingot_steel"]:
		Game.remove_def(d, Game.count(d))
	eq(Steward.set_orders({"daily_limit": 30, "session_limit": 70, "reserve": 100, "sell_rules": {"stock_target": 3}}), "", "tight limits")
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 5)
	var buys := _smith_log("buy").filter(func(_e): return true)
	var by_day := {}
	for b in (Steward.st()["log"] as Array).filter(func(e): return str(e["kind"]) == "buy"):
		by_day[int(b["day"])] = int(by_day.get(int(b["day"]), 0)) + int(b["data"]["cost"])
		check(int(b["data"]["gold_after"]) >= 100, "a purchase kept the reserve")
		var h := int(str(b["time"]).split(":")[0])
		check(h >= 7 and h < 19, "bought while the counter was open (%s)" % str(b["time"]))
	for d2 in by_day:
		check(int(by_day[d2]) <= 30, "day %d: %d g within the daily limit" % [int(d2), int(by_day[d2])])
	check(int(Steward.st()["acc"]["spent"]) <= 70, "within the limit for the absence (%d)" % int(Steward.st()["acc"]["spent"]))
	var r := Steward.deactivate()
	check(int(r["smith"]["prepared"].get("ingot_iron", 0)) > 0, "with no ingots in the stores he smelted his own (%s)" % JSON.stringify(r["smith"]["prepared"]))
	check(int(r["smith"]["made_count"]) > 0, "and made pieces for the display (%d)" % int(r["smith"]["made_count"]))
	var shown := Shop.stock().filter(func(x): return Items.is_equipment(x)).size()
	check(shown <= 3 + 2, "the display is kept near its target, not flooded (%d)" % shown)
	check(bool(r["gold"]["reconciled"]), "the gold reconciles")
	note("restock: %d purchases, spent %d g, prepared %s, made %d" % [buys.size(), int(r["purchases"]["total"]), JSON.stringify(r["smith"]["prepared"]), int(r["smith"]["made_count"])])


# ------------------------------------------------------------------ with apprentices and changing demand
func test_with_apprentices_and_changing_demand() -> void:
	_early(4242)
	_apprentices(2)
	Game.state["gold"] = 2000
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24)
	var made_quiet := int(Steward.st()["acc"]["smith"]["made_n"])
	# demand rises: three ordinary commissions arrive at once
	var oids: Array = []
	var advs: Array = []
	for id in Adv.all().keys():
		if str(Adv.get_a(str(id))["status"]) == "in_town" and not Shop.refuses(str(id)) and advs.size() < 3:
			advs.append(str(id))
	for i in advs.size():
		var oid := "ord_%d" % Game.new_uid()
		oids.append(oid)
		Shop.orders().append({"id": oid, "npc": str(advs[i]), "slot": "weapon", "stat": "attack", "min": 0, "tier": 1, "def": ["sword_short", "axe_hand", "axe_hatchet"][i],
			"recipe": ["iron_shortsword", "hand_axe", "iron_hatchet"][i], "reward": 80, "deadline": Game.day() + 4, "status": "open", "placed": Game.day(), "priority": "quality"})
	give("ingot_iron", 6)
	give("leather_cured", 3)
	give("coal", 4)
	_hours(4)
	var by_app := 0
	var by_smith := 0
	for oid2 in oids:
		if not Steward._commission_task(str(oid2)).is_empty():
			by_app += 1
		elif StewardSmith.has_order(str(oid2)):
			by_smith += 1
	check(by_app + by_smith == oids.size(), "every new commission was taken on (%d by apprentices, %d by the smith)" % [by_app, by_smith])
	var g := 0
	while oids.any(func(o): return str(Steward._order(str(o)).get("status", "")) == "open") and g < 96:
		_hours(1)
		g += 1
	for oid3 in oids:
		eq(str(Steward._order(str(oid3)).get("status", "")), "done", "commission %s delivered" % str(oid3))
	var r := Steward.deactivate()
	check(int(r["production"]["completed"].get("commission", 0)) + int(r["smith"]["made_count"]) > 0, "apprentices and the smith both worked")
	check(Apprentices.staff().all(func(a): return int(a.get("works", 0)) > 0), "every apprentice finished work")
	check(bool(r["gold"]["reconciled"]), "the gold reconciles")
	_clean("with apprentices")
	note("demand: quiet day the smith made %d; then %d commissions — %d to apprentices, %d to the smith; total smith pieces %d, repairs %d" % [made_quiet,
		oids.size(), by_app, by_smith, int(r["smith"]["made_count"]), int(r["smith"]["repairs_count"])])


# ------------------------------------------------------------------ zero experience
## Activation, completion, exit and save/load: no experience while the steward runs, and none from a piece begun
## under it — not when the smith finishes it himself after taking the workshop back, not after a save is loaded. His
## own work afterwards teaches him again (the guard is not stuck).
func test_zero_xp_across_exit_and_save_load() -> void:
	_early()
	var xp0 := _skills()
	var nodes0 := (Game.state["skilltree"]["nodes"] as Array).size()
	var flags0 := JSON.stringify(Game.state["flags"])
	var obj_done: Array = Game.state.get("objectives", {}).get("done", [])
	check(not obj_done.has("select_recipe") and not obj_done.has("craft_sword"), "a new game: the crafting objectives are still open")
	eq(Steward.activate(), "", "the steward takes over")
	# run until a piece is in hand with at least one operation done
	var g := 0
	while g < 48 and not (Crafting.active() and int(Crafting.job().get("step", 0)) >= 1):
		Game.advance_minutes(15)
		g += 1
	if not check(Crafting.active() and Steward.marked(Crafting.job()) and int(Crafting.job()["step"]) >= 1, "a piece is half-made under the steward"):
		return
	eq(_skills(), xp0, "while active: no experience")
	check(Saves.save("s2_mid_piece"), "saved with the piece half-made")
	# exit: the piece stays in the smith's hands, marked
	Steward.deactivate()
	check(Crafting.active() and Steward.marked(Crafting.job()), "after the return the half-made piece is in his hands, still marked")
	eq(Engine.time_scale, 1.0, "normal pace after the return")
	var it := craft_rest()
	check(not it.is_empty(), "the smith finishes it himself")
	eq(_skills(), xp0, "finishing a piece the steward began gives no experience")
	check((it.get("craft", {}).get("xp", {}) as Dictionary).is_empty(), "its record says no experience was gained")
	# load the save made mid-piece: mode off, the marked piece in hand; finishing it gives no experience either
	check(Saves.load_slot("s2_mid_piece"), "the save loads")
	Saves.delete("s2_mid_piece")
	check(not Steward.is_active() and Crafting.active() and Steward.marked(Crafting.job()), "after loading: mode off, the marked piece in hand")
	var xp_l := _skills()
	var it2 := craft_rest()
	check(not it2.is_empty(), "he finishes it after loading")
	eq(_skills(), xp_l, "no experience from it after loading either")
	eq((Game.state["skilltree"]["nodes"] as Array).size(), nodes0, "no skill-tree node was learned")
	eq(JSON.stringify(Game.state["flags"]), flags0, "no knowledge flag was set")
	var done_now: Array = Game.state.get("objectives", {}).get("done", [])
	check(not done_now.has("select_recipe") and not done_now.has("craft_sword"), "the steward's work completed no crafting objective for him")
	# his own work afterwards teaches him as before
	var it3 := craft("hand_axe")
	check(not it3.is_empty() and _skills() != xp_l, "his own piece afterwards gives experience again")


## Drives the operations left on the piece in hand with fixed check scores (as the player would), then the dice.
func craft_rest() -> Dictionary:
	var guard := 0
	while Crafting.current_station() != "" and guard < 30:
		var st := Crafting.current_station()
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(95.0)
		Crafting.record_step(st, qs)
		guard += 1
	return Crafting.finish({"edge": 12, "temper": 8, "fortune": 40, "guard": 12, "purity": 3}, "digital")


# ------------------------------------------------------------------ fatigue, hours and sleep
func test_hours_breaks_rest_and_sleep() -> void:
	_early()
	eq(Steward.activate(), "", "the steward takes over")
	var acts := {}
	for i in 24 * 4 * 2:   # two days in quarter hours
		Game.advance_minutes(15)
		var h := Game.hour()
		var act := str(StewardSmith.sm()["act"])
		acts[act] = int(acts.get(act, 0)) + 1
		if act == "work":
			check(h >= 8 and h < 18 and h != 12, "he works only in working hours (worked at %s)" % Game.time_string())
		if h >= 23 or h < 5:
			eq(act, "sleep", "at %s he is asleep" % Game.time_string())
		if h == 12 and Game.state["minute"] % 60 >= 15:
			eq(act, "break", "the midday break at %s" % Game.time_string())
	check(int(acts.get("work", 0)) > 30, "he worked (%s)" % JSON.stringify(acts))
	# unsteady hands at nine in the morning: he rests an hour before going on
	Game.advance_minutes(((9 * 60) - int(Game.state["minute"]) + 1440) % 1440)
	Vitality.set_fatigue(86.0)
	Game.advance_minutes(15)
	eq(str(StewardSmith.sm()["act"]), "rest", "tired: he rests by the hearth")
	check(Vitality.fatigue() < 86.0, "resting eases it (%.1f)" % Vitality.fatigue())
	Game.advance_minutes(75)
	check(str(StewardSmith.sm()["act"]) in ["work", "walk", "idle"], "after the rest he goes back to work (%s)" % str(StewardSmith.sm()["act"]))
	# custom working hours (standing instruction)
	eq(Steward.set_orders({"smith_hours": [10, 16]}), "", "working hours 10–16")
	check(Steward.set_orders({"smith_hours": [3, 23]}) != "", "unreasonable hours are refused")
	Game.advance_minutes(((17 * 60) - int(Game.state["minute"]) + 1440) % 1440)
	Game.advance_minutes(15)
	eq(StewardSmith.want(), "home", "after his hours he is at home")
	var r := Steward.deactivate()
	check(int(r["smith"]["nights"]) >= 2 and int(r["smith"]["rests"]) >= 1, "the report counts his nights (%d) and rests (%d)" % [int(r["smith"]["nights"]), int(r["smith"]["rests"])])


# ------------------------------------------------------------------ never
func test_never_masterwork_secret_or_masterpiece() -> void:
	_early()
	train("smithing", 14)
	Game.state["gold"] = 3000
	give("ingot_iron", 12)
	give("ingot_steel", 6)
	give("leather_cured", 6)
	give("coal", 10)
	# a secret Design and a legendary-grade one are never his routine work
	check(StewardSmith.recipe_ok("starsteel_blade") != "", "a forgotten recipe is not routine (%s)" % StewardSmith.recipe_ok("starsteel_blade"))
	check(StewardSmith.recipe_ok("dragonscale_armor") != "", "legendary-grade work is not routine")
	check(StewardSmith.recipe_ok("healing_draught") != "", "a specialist's craft is not his (%s)" % StewardSmith.recipe_ok("healing_draught"))
	# a major contract with a masterpiece slot, accepted by the smith before he leaves
	var c := Contracts.make_offer("drovers_kit")
	var cid := str(c.get("id", ""))
	var acc_err := Contracts.accept(cid) if cid != "" else "no offer"
	var hof0 := Recognition.of_kind("craft").size()
	eq(Steward.activate(), "", "the steward takes over")
	_hours(24 * 6)
	var r := Steward.deactivate()
	for m in r["smith"]["made"]:
		check(float(m["quality"]) <= StewardSmith.QUALITY_CAP + 0.01, "%s at %.1f%% stays below the cap" % [str(m["name"]), float(m["quality"])])
		var it := ItemRegistry.find(int(m["uid"]))
		if not it.is_empty():
			var fam: Dictionary = ItemStory.st()["famous"].get(str(int(m["uid"])), {})
			check(str(fam.get("kind", "")) != "masterwork" and not bool(it["craft"].get("masterwork", false)) and float(it["craft"].get("quality", 0)) < 115.0,
				"%s: no masterwork, no anvil name" % str(m["name"]))
			check(it.get("sockets", []).is_empty() and not it.has("coating") and not it.has("refined"), "%s: no socket, coating or refinement" % str(m["name"]))
	check(int(r["smith"]["made_count"]) > 0, "a skilled smith worked (%d pieces)" % int(r["smith"]["made_count"]))
	var high := Recognition.of_kind("craft").filter(func(e): return float(e.get("refs", {}).get("quality", 0)) >= 112.0)
	check(Recognition.of_kind("craft").size() - hof0 <= (r["smith"]["made"] as Array).filter(func(x): return str(x.get("rarity", "")) == "legendary").size(),
		"no Hall of Fame plaque for craftsmanship from his work under the steward (%d)" % high.size())
	if acc_err == "":
		var cc := Contracts.get_c(cid)
		check(int(cc.get("masterpiece", {}).get("uid", -1)) < 0, "the contract's masterpiece slot stays for the smith himself")
	_clean("never")


# ------------------------------------------------------------------ the pace
func test_pace_on_restored_on_exit_and_load() -> void:
	_early()
	Game.set_speed(4)
	eq(Steward.activate(), "", "the steward takes over")
	eq(Engine.time_scale, 1.5, "the whole simulation runs at 1.5× (Engine.time_scale)")
	eq(Game.speed, 1, "the clock alone is not sped up on top of it")
	Game.set_speed(8)
	eq(Game.speed, 1, "time controls do not run the clock ahead of the world while the steward runs")
	eq(Steward.set_orders({"pace": 1.0}), "", "the player may choose normal pace")
	eq(Engine.time_scale, 1.0, "… applied at once")
	eq(Steward.set_orders({"pace": 1.5}), "", "and back to 1.5×")
	eq(Engine.time_scale, 1.5, "… applied at once")
	check(Steward.set_orders({"pace": 3.0}) != "", "other paces are refused")
	_hours(6)
	Steward.deactivate()
	eq(Engine.time_scale, 1.0, "normal pace the moment he returns")
	eq(Game.speed, 8, "the speed he asked for applies on return")
	Game.set_speed(1)
	eq(Steward.activate(), "", "again")
	check(Saves.save("s2_pace"), "saved while the steward runs")
	check(Saves.load_slot("s2_pace"), "loaded")
	Saves.delete("s2_pace")
	check(not Steward.is_active() and Engine.time_scale == 1.0, "a loaded save runs at normal speed with the mode off")
	# a new game never inherits it either
	eq(Steward.activate(), "", "once more")
	fresh_game()
	eq(Engine.time_scale, 1.0, "a new game starts at normal pace")


## Headless runs drive Game.advance_minutes and are deterministic: two runs from the same seed agree exactly.
func test_deterministic_headless() -> void:
	var sig := []
	for run in 2:
		_early(777)
		eq(Steward.activate(), "", "run %d: the steward takes over" % run)
		_hours(36)
		var lines := PackedStringArray()
		for e in Steward.st()["log"]:
			lines.append("%d %s %s %s" % [int(e["day"]), str(e["time"]), str(e["kind"]), str(e["text"])])
		var inv := PackedStringArray()
		for it in Game.inventory():
			inv.append("%s:%d:%.2f" % [str(it["def"]), int(it.get("qty", 1)), float(it.get("quality", 0))])
		sig.append("\n".join(lines) + "|" + ",".join(inv) + "|%d|%.3f" % [Game.gold(), Vitality.fatigue()])
		Steward.deactivate()
	check(str(sig[0]) == str(sig[1]), "the same seed gives the same day under the steward (%d chars)" % str(sig[0]).length())


# ------------------------------------------------------------------ soaks: a poor early game
## A brand-new game (120 g, the starting materials, no apprentices, the default instructions — a reserve of 150 g the
## purse does not even reach): the smith alone keeps the forge going. Checks the hard rules; statistics in the notes.
func _poor_soak(days: int, label: String) -> Dictionary:
	_early(5151)
	var gold0 := Game.gold()
	var xp0 := _skills()
	var crafted0 := int(Game.state["stats"]["crafted"])
	var t0 := Time.get_ticks_msec()
	if not check(Steward.activate() == "", "%s: the steward takes over" % label):
		return {}
	var by_month: Array = []
	var last := 0
	for d in days:
		_hours(24)
		if (d + 1) % 30 == 0 or d == days - 1:
			var made := int(Steward.st()["acc"]["smith"]["made_n"]) + int(Steward.st()["acc"]["smith"]["repairs_n"])
			by_month.append(made - last)
			last = made
	var ms := Time.get_ticks_msec() - t0
	var o := Steward.orders()
	var by_day := {}
	for e in Steward.st()["log"]:
		if str(e["kind"]) == "buy":
			by_day[int(e["day"])] = int(by_day.get(int(e["day"]), 0)) + int(e["data"]["cost"])
			check(int(e["data"]["gold_after"]) >= int(o["reserve"]), "%s: a purchase kept the reserve" % label)
	for dd in by_day:
		check(int(by_day[dd]) <= int(o["daily_limit"]), "%s: day %d within the daily limit" % [label, int(dd)])
	var r := Steward.deactivate()
	var sm: Dictionary = r["smith"]
	check(bool(r["gold"]["reconciled"]), "%s: every coin in the ledger (unexplained %d)" % [label, int(r["gold"]["unexplained"])])
	eq(_skills(), xp0, "%s: no experience" % label)
	eq(int(Game.state["stats"]["crafted"]) - crafted0, int(r["production"]["smith_crafted"]), "%s: the report counts his work" % label)
	for m in sm["made"]:
		check(float(m["quality"]) <= StewardSmith.QUALITY_CAP + 0.01, "%s: %s within the cap" % [label, str(m["name"])])
	check(int(sm["nights"]) >= days - 1, "%s: he slept every night (%d)" % [label, int(sm["nights"])])
	_clean(label)
	check(save_load("s2_poor_" + label), "%s: save and load after the soak" % label)
	_clean(label + " after load")
	for i in by_month.size():
		check(int(by_month[i]) > 0, "%s: real work in period %d (%d pieces and repairs)" % [label, i + 1, int(by_month[i])])
	var cats := PackedStringArray()
	for c in r["gold"]["by_category"]:
		cats.append("%s %+d" % [c, int(r["gold"]["by_category"][c])])
	var kinds := PackedStringArray()
	var bk: Array = (r["decisions"]["by_kind"] as Dictionary).keys()
	bk.sort()
	for k in bk:
		kinds.append("%s %d" % [k, int(r["decisions"]["by_kind"][k])])
	var stall_txt := PackedStringArray()
	for sline in r["decisions"]["stalls"]:
		stall_txt.append("%s×%d (%s)" % [sline["code"], int(sline["count"]), str(sline["text"]).left(60)])
	note("%s: %d days in %.1f s (%.0f ms/day)" % [label, days, ms / 1000.0, float(ms) / days])
	note("%s smith: made %d pieces, %d repairs (+%d g from customers), prepared %s, used %s; %s at the stations (%d walking), %d operations; nights %d, breaks %d, rests %d; fatigue now %s" % [
		label, int(sm["made_count"]), int(sm["repairs_count"]), int(sm["repair_gold"]), JSON.stringify(sm["prepared"]), JSON.stringify(sm["used"]),
		str(sm["hours_text"]), int(sm["walk_minutes"]), int(sm["ops"]), int(sm["nights"]), int(sm["breaks"]), int(sm["rests"]), str(sm["band"])])
	note("%s gold %d → %d (income %d, expenses %d; %s); reconciled %s over %d lines; steward bought %d g; steward sales %d (%d g); ledger sales %d g" % [label, gold0,
		int(r["gold"]["end"]), int(r["gold"]["income"]), int(r["gold"]["expenses"]), ", ".join(cats), str(r["gold"]["reconciled"]), int(r["gold"]["lines"]),
		int(r["purchases"]["total"]), int(r["sales"]["count"]), int(r["sales"]["gold"]), int(r["sales"]["ledger_sales"])])
	note("%s orders: taken on %d, delivered %d, declined %d, open %d; decisions %d — %s" % [label, int(r["orders"]["counts"]["accepted"]),
		int(r["orders"]["counts"]["delivered"]), int(r["orders"]["counts"]["declined"]), int(r["orders"]["counts"]["pending"]), int(r["decisions"]["total"]), ", ".join(kinds)])
	note("%s stalls: %s; xp withheld %d; per-month work %s; scan %s" % [label, ", ".join(stall_txt) if not stall_txt.is_empty() else "none", int(sm["xp_withheld"]),
		str(by_month), ItemRegistry.scan_text(ItemRegistry.scan())])
	return r


func test_soak_poor_early_30_days() -> void:
	var r := _poor_soak(30, "poor30")
	if r.is_empty():
		return
	check(int(r["smith"]["made_count"]) >= 20, "a month of the smith's own work (%d pieces)" % int(r["smith"]["made_count"]))


func test_soak_poor_early_365_days() -> void:
	var r := _poor_soak(365, "poor365")
	if r.is_empty():
		return
	check(int(r["smith"]["made_count"]) + int(r["smith"]["repairs_count"]) > 200, "a year of the smith's own work")
