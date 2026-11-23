## R8 "World Recognition": "a town safer by craftsmanship" — a seeded campaign with and without consignments to the
## muster, the difference in danger, bandits and trade risk explained by state; patrols that rise and fade gradually;
## reputation that crosses from one place to another only by a real channel; credible visitors with recorded reasons
## (renown cannot be bought); political commitments left sealed for the smith.
## (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R8 acceptance.)
extends SuiteCase

const SMOKE := ["test_reputation_crosses_only_by_channel", "test_a_town_safer_by_craftsmanship"]


## The bandit road nearest the village (most reach) and the farthest place of all.
func _roads() -> Dictionary:
	var near := ""
	var far := ""
	for rid in DB.destinations:
		if far == "" or Militia.reach(str(rid)) < Militia.reach(far):
			far = str(rid)
		var has_b := false
		for n in Expeditions.region(str(rid)).get("nodes", []):
			for spec in n.get("enemies", []):
				if Militia.is_bandit(str(spec[0])):
					has_b = true
		if has_b and (near == "" or Militia.reach(str(rid)) > Militia.reach(near)):
			near = str(rid)
	return {"near": near, "far": far}


func _consign(n_each: int, q: float) -> void:
	Institutions.receive("muster", "smith", [{"def": "helm_iron", "n": n_each}, {"def": "shield_round", "n": n_each}], [], q, [], {"test": true})


func _campaign(with_kit: bool, days: int) -> Dictionary:
	fresh_game("journeyman", 5150)
	if with_kit:
		_consign(12, 88.0)
	var after0 := Militia.patrol()
	var mid := 0.0
	for d in days:
		Game.advance_minutes(1440)
		if d == 9:
			mid = Militia.patrol()
	var r := _roads()
	var h: Dictionary = Hire.list()[0]
	var trade := ""
	for rid in DB.destinations:
		if str(DB.destinations[rid].get("kind", "")) == "trade" and (trade == "" or Militia.reach(str(rid)) > Militia.reach(trade)):
			trade = str(rid)
	# the counterfactual in the SAME world: everything as it is, but no patrols — what the patrols alone change
	var cf := {}
	if Game.state.get("militia") is Dictionary:
		var keep := float(Game.state["militia"]["patrol"])
		Game.state["militia"]["patrol"] = 0.0
		cf = {"site_near": Danger.site(r["near"]), "trip_trade": Danger.trip(trade), "injury_trade": float(Hire.odds(h, trade)["injury"]),
			"bandits_near": Militia.bandits_at(r["near"])}
		Game.state["militia"]["patrol"] = keep
	return {"cf": cf, "patrol0": after0, "patrol10": mid, "patrol": Militia.patrol(), "ready": Militia.readiness(), "near": r["near"], "far": r["far"],
		"bandits_near": Militia.bandits_at(r["near"]), "bandits_far": Militia.bandits_at(r["far"]), "site_near": Danger.site(r["near"]),
		"trip_trade": Danger.trip(trade), "injury_trade": float(Hire.odds(h, trade)["injury"]), "trade": trade,
		"effect_near": Militia.effect(r["near"]), "effect_far": Militia.effect(r["far"])}


# ------------------------------------------------------------------ 1. a town safer by craftsmanship (WLD-021)
func test_a_town_safer_by_craftsmanship() -> void:
	var without := _campaign(false, 60)
	var with := _campaign(true, 60)
	check(with["near"] != "" and with["near"] != with["far"], "premise: a near and a far bandit road (%s, %s)" % [str(with["near"]), str(with["far"])])
	eq(float(without["patrol"]), 0.0, "without consignments the muster has nothing to patrol with")
	check(float(with["ready"]) > 0.5, "with them its kit is real (readiness %.2f from the delivered helms and shields)" % float(with["ready"]))
	# gradual: nothing on the day the kit arrives, some after ten days, more after sixty — never above readiness
	eq(float(with["patrol0"]), 0.0, "the patrols do not appear the day the kit arrives")
	check(float(with["patrol10"]) > 0.0 and float(with["patrol10"]) < float(with["patrol"]) and float(with["patrol"]) <= float(with["ready"]) + 0.001,
		"they grow over weeks (%.2f after 10 days, %.2f after 60, readiness %.2f)" % [float(with["patrol10"]), float(with["patrol"]), float(with["ready"])])
	# the difference, explained by state
	check(int(with["bandits_near"]) < int(without["bandits_near"]), "fewer bandits on the near road (%d < %d)" % [int(with["bandits_near"]), int(without["bandits_near"])])
	check(float(with["site_near"]) < float(without["site_near"]), "so its live danger is lower (%.0f < %.0f)" % [float(with["site_near"]), float(without["site_near"])])
	# the same world without its patrols: the difference the patrols alone make (the two campaigns diverge in other ways —
	# scouting, threats — so the clean comparison is within one state)
	var cf: Dictionary = with["cf"]
	check(int(cf["bandits_near"]) > int(with["bandits_near"]) and float(cf["site_near"]) > float(with["site_near"]),
		"in the same world, the patrols are what removed those bandits (%d → %d) and that danger (%.0f → %.0f)" % [int(cf["bandits_near"]), int(with["bandits_near"]), float(cf["site_near"]), float(with["site_near"])])
	check(float(with["trip_trade"]) < float(cf["trip_trade"]) and float(with["injury_trade"]) <= float(cf["injury_trade"]),
		"and a hireling's trade road is safer for it (danger %.2f → %.2f, injury %.3f → %.3f)" % [float(cf["trip_trade"]), float(with["trip_trade"]), float(cf["injury_trade"]), float(with["injury_trade"])])
	# no hard circle: the far road feels the patrols less
	check(float(with["effect_far"]) < float(with["effect_near"]), "the far road feels the patrols less (%.2f < %.2f) — a fall-off, not a circle" % [float(with["effect_far"]), float(with["effect_near"])])
	check(int(with["bandits_near"]) >= 1, "bandits thin but never vanish")
	# the state explains the count exactly: the base foes, thinned by the effect
	var base := 0
	var expect := 0
	for n in Expeditions.region(str(with["near"])).get("nodes", []):
		var foes := WorldSites._enemies_at(str(with["near"]), n)
		for spec in foes:
			if Militia.is_bandit(str(spec[0])):
				base += int(spec[1])
		for spec in Militia.thin(str(with["near"]), foes):
			if Militia.is_bandit(str(spec[0])):
				expect += int(spec[1])
	eq(int(with["bandits_near"]), expect, "the bandits there are exactly the place's foes thinned by the patrols' effect (%d of %d)" % [expect, base])
	check(Militia.line(str(with["near"])) != "" and Militia.line(str(with["near"])).contains("%"), "the map's line states the real reach")


func test_patrols_fade_without_upkeep() -> void:
	fresh_game("journeyman", 5150)
	_consign(12, 88.0)
	for d in 40:
		Game.advance_minutes(1440)
	var p40 := Militia.patrol()
	# the kit is lost (a raid, a fire — here simply taken away): readiness falls at once, the patrols only slowly
	(Institutions.peek("muster")["supply"] as Dictionary).clear()
	eq(Militia.readiness(), 0.0, "no kit left")
	Game.advance_minutes(1440)
	var p41 := Militia.patrol()
	check(p41 < p40 and p41 > p40 * 0.9, "the patrols fade gradually (%.3f → %.3f)" % [p40, p41])


# ------------------------------------------------------------------ 2. reputation spread (WLD-012, QST-010)
func test_reputation_crosses_only_by_channel() -> void:
	fresh_game()
	var v0 := Reputation.word("traders", "village")
	Reputation.change(6.0, "the smith forged a blade that slew a troll")
	check(Reputation.word("traders", "village") > v0, "the village hears at once")
	eq(Reputation.word("traders", "region"), 0.0, "the region has not heard")
	eq(Reputation.word("nobility", "region"), 0.0, "no one in the region has")
	# a ship sails: its crew carry the news to the traders down the coast — not to the nobility
	check(Reputation.carry("village", "region", "ship") >= 1, "a ship carries the news")
	check(is_equal_approx(Reputation.word("traders", "region"), 6.0 * Reputation.CARRY), "the region's traders heard it (%.1f)" % Reputation.word("traders", "region"))
	eq(Reputation.word("nobility", "region"), 0.0, "the nobility still has not")
	Reputation.carry("village", "region", "ship")
	check(is_equal_approx(Reputation.word("traders", "region"), 6.0 * Reputation.CARRY), "the same news is not counted twice")
	Reputation.carry("village", "region", "letter")
	check(Reputation.word("nobility", "region") > 0.0, "a patron's letter brings it to the nobility")
	var n := Reputation.latest_heard("region", "traders")
	eq(str(n.get("via", {}).get("region", {}).get("traders", "")), "ship", "the record says how it reached the traders")
	eq(str(n.get("via", {}).get("region", {}).get("nobility", "")), "letter", "and how it reached the nobility")
	# the real channel: a ship leaving the harbour
	Reputation.change(4.0, "a second deed")
	var t0 := Reputation.word("traders", "region")
	var nm: Array = Trade.ship_type("barge")["names"][0]
	Trade._dock("barge", str(nm[0]), str(nm[1]))
	eq(Reputation.word("traders", "region"), t0, "a ship in port has carried nothing yet")
	Trade._depart()
	check(Reputation.word("traders", "region") > t0, "when it sails, the news goes with it")
	# a village standing is unchanged by the spread
	var s0 := Reputation.standing()
	Reputation.carry("village", "region", "travel")
	check(is_equal_approx(Reputation.standing(), s0), "the village's own standing is unchanged by news leaving it")


# ------------------------------------------------------------------ 3. credible visitors; renown cannot be bought
func test_visitors_come_for_a_recorded_reason() -> void:
	fresh_game()
	# gold is no reason
	Game.state["gold"] = 1000000
	for d in 3:
		Visitors.on_day(Game.day())
	check(Visitors.log_list().is_empty(), "a full purse brings no one")
	check(not bool(Smithy.renown()["ok"]), "and buys no renown")
	# a deed, carried by a ship to the region's traders
	Reputation.change(8.0, "the smith's helms turned an ambush on the Highmarsh road")
	Visitors.on_day(Game.day())
	check(Visitors.log_list().is_empty(), "the region has not heard yet: no visitor")
	Reputation.carry("village", "region", "ship")
	Visitors.on_day(Game.day())
	var log := Visitors.log_list()
	check(log.size() == 1, "a visitor comes once the news has reached them")
	if log.is_empty():
		return
	var v: Dictionary = log[0]
	check(Visitors.CAST.has(str(v["patron"])) and str(Visitors.CAST[str(v["patron"])]) == "traders", "a trader who heard it (%s)" % str(v["name"]))
	eq(str(v["via"]), "ship", "the visit records the channel")
	check(str(v["why"]).contains("ambush"), "and the deed it was about")
	var ev := Lore.event(str(v["event"]))
	check(str(ev.get("kind", "")) == "visit" and str(ev.get("text", "")).contains("a ship's crew"), "one Lore event: who came, why and how they heard")
	Visitors.on_day(Game.day() + 1)
	eq(Visitors.log_list().size(), 1, "no second visit without a new reason")


# ------------------------------------------------------------------ 4. political commitments wait for the smith (STW-014)
func test_steward_defers_political_commitments() -> void:
	fresh_game()
	Property.dev_grant_all()
	SkillTree.unlock_all()
	check(Steward.activate() == "", "the steward takes over")
	var c := Contracts.make_offer("honor_guard")
	check(not c.has("error"), "the reeve's letter for the muster arrives")
	Steward._scan_deferrals(false)
	var d := Steward.deferred().filter(func(e): return str(e.get("source", {}).get("id", "")) == str(c.get("id", "")))
	check(d.size() == 1 and bool(d[0]["sealed"]) and bool(d[0]["source"].get("political", false)), "it waits sealed, marked political")
	check(Contracts.offers().any(func(o): return str(o["id"]) == str(c["id"])), "and unanswered — the steward never accepts it")
	# a visitor while the smith is away leaves a sealed letter
	Reputation.change(8.0, "a deed")
	Reputation.carry("village", "region", "letter")
	Visitors.visit("highmarsh_watch", {"news": "n", "why": "a deed", "via": "letter", "audience": "nobility"})
	check(Steward.deferred().any(func(e): return str(e["kind"]) == "political" and bool(e["sealed"])), "a visitor's call is a sealed political matter")
	Steward.deactivate()
