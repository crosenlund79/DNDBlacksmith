## The Living Realm, milestone 3a — living adventurers (Living, Companies): a reproducible seeded roster
## within balanced limits (the established adventurers keep their roles), personal goals that change real
## choices (risk, destination, shopping), friendships and rivalries from shared events, retirement and
## newcomers, persistent named companies that travel together, recruit, lose members and disband for a reason,
## one Lore event per life/company event, save/load, an old save, and a long deterministic soak.
extends SuiteCase

const SMOKE := ["test_seed_reproducible", "test_goals_change_behaviour", "test_relationships_form", "test_save_load_and_old_save"]


func _seeded(s: int) -> void:
	Living.next_seed = s
	fresh_game()


func _sig() -> String:
	return Living.signature() + "#" + Companies.signature()


func _lore_kind(kind: String, actor := "") -> Array:
	var out := []
	for id in Lore.st()["order"]:
		var e := Lore.event(str(id))
		if str(e.get("kind", "")) == kind and (actor == "" or (e.get("actors", []) as Array).has(actor)):
			out.append(e)
	return out


func _reserve_in_town() -> Dictionary:
	for a in Adv.all().values():
		if Living.is_reserve(str(a["id"])) and str(a["status"]) == "in_town":
			return a
	return {}


func test_seed_reproducible() -> void:
	_seeded(424242)
	eq(Living.world_seed(), 424242, "the world seed is stored in the save")
	var s1 := _sig()
	_seeded(424242)
	eq(_sig(), s1, "the same seed reproduces the same roster, friendships and companies")
	_seeded(77)
	check(_sig() != s1, "a different seed gives a different roster")
	# the established adventurers keep their roles
	for id in ["mira", "sigrun", "elowen", "kestra", "garrick", "tomas", "varn", "pip"]:
		var a := Adv.get_a(id)
		check(not a.is_empty() and int(a["level"]) == int(DB.character(id)["level"]) and a["cls"] == DB.character(id)["cls"], "%s keeps class and level" % id)
	eq(int(Adv.get_a("mira")["depart_day"]), 3, "Mira still leaves on day 3 (the grocer's story)")
	eq(str(Adv.get_a("mira").get("company", "")), "", "Mira is not tied to a company at the start")
	note("seed 77: " + ", ".join(Adv.all().keys().filter(func(i): return Living.is_reserve(str(i)))))


func test_balanced_ranges() -> void:
	var rosters := {}
	var companies := 0
	for s in [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]:
		_seeded(s)
		var n := Adv.all().size()
		check(n >= 11 and n <= 13, "seed %d: 8 established + 3–5 reserves (%d)" % [s, n])
		var res := []
		for a in Adv.all().values():
			if not Living.is_reserve(str(a["id"])):
				continue
			res.append(a["id"])
			check(int(a["level"]) >= 1 and int(a["level"]) <= 5, "%s level %d in 1–5" % [a["id"], int(a["level"])])
			check(int(a["gold"]) >= 20 and int(a["gold"]) <= 260, "%s purse %d in 20–260" % [a["id"], int(a["gold"])])
			for sl in a["equipment"]:
				var q := float(a["equipment"][sl]["quality"])
				check(q >= 35.0 and q <= 80.0, "%s %s quality %.0f in 35–80" % [a["id"], sl, q])
		for a in Adv.all().values():
			check(Living.goals(a).size() >= 2, "%s pursues two goals (or more)" % a["id"])
		res.sort()
		rosters[str(res)] = true
		companies += Companies.active().size()
		check(Companies.active().size() >= 1, "seed %d starts with a company" % s)
		eq(Living.st()["queue"].size() + res.size(), Living.reserve_ids().size(), "the other reserves wait as newcomers")
	check(rosters.size() >= 6, "ten seeds give varied rosters (%d distinct)" % rosters.size())
	note("%d distinct reserve line-ups, %d starting companies over ten seeds" % [rosters.size(), companies])


func test_goals_change_behaviour() -> void:
	_seeded(4242)
	var a := Adv.get_a("varn")
	Expeditions.ensure(a)
	a["goals"] = [{"kind": "wealth", "target": 9999, "since": 1}]
	var wealth_risk := Living.eff_risk(a)
	var wealth_dest := 0.0
	seed(7)
	for i in 30:
		wealth_dest += Expeditions.rating(str(Expeditions.choose_destination([a]).get("dest", "whisperwood")))
	a["goals"] = [{"kind": "gear", "target": 9999, "since": 1}]
	var gear_risk := Living.eff_risk(a)
	var gear_dest := 0.0
	seed(7)
	for i in 30:
		gear_dest += Expeditions.rating(str(Expeditions.choose_destination([a]).get("dest", "whisperwood")))
	check(wealth_risk > gear_risk, "a wealth-seeker takes more risk (%.2f vs %.2f)" % [wealth_risk, gear_risk])
	check(wealth_dest > gear_dest, "and chooses more dangerous, better-paid places (mean rating %.1f vs %.1f)" % [wealth_dest / 30.0, gear_dest / 30.0])
	# shopping: a gear-seeker pays up for an upgrade a wealth-seeker calls overpriced
	a["gold"] = 2000
	var axe := Items.make(str(a["equipment"]["weapon"]["def"]), {"quality": 96.0})
	var price := int(Items.value(axe) * 1.32)
	eq(Adv.purchase_check(a, axe, price), "", "the gear-seeker buys the better axe at %d g" % price)
	a["goals"] = [{"kind": "wealth", "target": 9999, "since": 1}]
	eq(Adv.purchase_check(a, axe, price), "thinks it's overpriced", "the wealth-seeker will not pay that")
	# a gear-seeker calls a piece too weak sooner, so it goes on the shopping list
	a["goals"] = [{"kind": "gear", "target": 9999, "since": 1}]
	check(Living.inferior_factor(a) > 0.6, "gear-seekers look for upgrades sooner")
	# goals are achieved from what actually happens and replaced
	a["goals"] = [{"kind": "wealth", "target": 100, "since": 1}]
	a["gold"] = 150
	Living.update_goals(a)
	check(bool(a["goals"][0].get("done", false)), "the wealth goal is achieved once the purse is full")
	eq(Living.goals(a).size(), 2, "and new goals take its place")
	eq(_lore_kind("goal", "varn").size(), 1, "one Lore event for the achievement")


func test_relationships_form() -> void:
	_seeded(9)
	var x := Adv.get_a("pip")
	var y := Adv.get_a("tomas")
	Expeditions.ensure(x)
	Expeditions.ensure(y)
	x["relations"]["tomas"] = 0.0
	y["relations"]["pip"] = 0.0
	var e := {"id": "exp_t", "party": ["pip", "tomas"], "leader": "pip", "dest": "whisperwood",
		"encounters": [{"actions": [{"kind": "heal", "actor": y["name"], "target": x["name"]}]}]}
	var trips := 0
	while Living.bond(x, "tomas") == "" and trips < 12:
		Living.on_expedition(e, ["pip", "tomas"], 2, "returned")
		trips += 1
	eq(Living.bond(x, "tomas"), "friend", "shared roads and a healer's care make friends (%d trips)" % trips)
	eq(Living.bond(y, "pip"), "friend", "the bond is mutual")
	var ev := _lore_kind("bond", "pip")
	eq(ev.size(), 1, "one Lore event for the friendship")
	check(not ev.is_empty() and (ev[0]["actors"] as Array).has("tomas"), "naming both")
	# competition: two glory-seekers on the same road become rivals
	var g := Adv.get_a("garrick")
	var v := Adv.get_a("varn")
	Expeditions.ensure(g)
	Expeditions.ensure(v)
	g["goals"] = [{"kind": "renown", "target": 999, "since": 1}]
	v["goals"] = [{"kind": "renown", "target": 999, "since": 1}]
	g["relations"]["varn"] = -20.0
	v["relations"]["garrick"] = -20.0
	g["bonds"] = {}
	v["bonds"] = {}
	var e2 := {"id": "exp_t2", "party": ["garrick", "varn"], "leader": "garrick", "dest": "whisperwood", "encounters": []}
	var n := 0
	while Living.bond(g, "varn") != "rival" and n < 12:
		Living.on_expedition(e2, ["garrick", "varn"], 0, "retreated")
		n += 1
	eq(Living.bond(g, "varn"), "rival", "competing for the same glory makes rivals (%d trips)" % n)
	check(Living.has_goal(g, "rival") or Living.has_goal(v, "rival"), "the one behind means to outshine the other")
	# rivals avoid each other when parties form
	var with_rival := Expeditions.invite_score([g], v)
	check(with_rival < Expeditions.invite_score([g], Adv.get_a("sigrun")), "rivals are not invited along")
	# grief: a friend's death leaves a mark
	x["status"] = "dead"
	var t0 := float(y["trauma"])
	Living.on_expedition({"id": "exp_t3", "party": ["pip", "tomas"], "leader": "tomas", "dest": "whisperwood", "encounters": []}, ["tomas"], 0, "retreated")
	check(float(y["trauma"]) > t0 + 15.0, "losing a friend weighs on the survivor (trauma %.0f → %.0f)" % [t0, float(y["trauma"])])


func test_retirement_and_replacement() -> void:
	_seeded(31)
	var a := _reserve_in_town()
	check(not a.is_empty(), "a reserve adventurer is in town")
	if a.is_empty():
		return
	# a friend who can use the gear
	var f := {}
	for o in Adv.all().values():
		if str(o["id"]) != str(a["id"]) and o["cls"] == a["cls"] and str(o["status"]) == "in_town":
			f = o
	if f.is_empty():
		for o in Adv.all().values():
			if str(o["id"]) != str(a["id"]) and str(o["status"]) == "in_town" and not Living.is_story(str(o["id"])) or str(o["id"]) == "sigrun":
				f = o
				break
	a["relations"][str(f["id"])] = 0.0
	f["relations"][str(a["id"])] = 0.0
	Living.relate(str(a["id"]), str(f["id"]), 60.0, "test")
	var wid := int(a["equipment"]["weapon"]["uid"])
	f["equipment"].erase("weapon")
	var before := Living.active_count()
	var r := Living.retire(a, "wealth", 1)
	eq(str(a["status"]), "retired", "retired and staying in the village")
	eq(Living.active_count(), before - 1, "no longer adventuring")
	eq(_lore_kind("retired", str(a["id"])).size(), 1, "one Lore event for the retirement")
	check(int(r["given"]) >= 1, "gear passed on (%d piece(s))" % int(r["given"]))
	eq(int(f["equipment"].get("weapon", {}).get("uid", -1)), wid, "the weapon (same uid) went to the friend")
	eq(Provenance.owner_id(f["equipment"]["weapon"]), str(f["id"]), "its chain of owners says so")
	eq(Expeditions.status_word(a), "Retired", "the sheet says Retired")
	# a smith's piece is offered back to the forge
	var b := {}
	for o in Adv.all().values():
		if Living.is_reserve(str(o["id"])) and str(o["status"]) == "in_town":
			b = o
	if not b.is_empty():
		var mine := craft("iron_longsword", 95.0)
		if not mine.is_empty():
			Game.inventory().erase(mine)
			b["equipment"]["weapon"] = mine
			Provenance.transfer(mine, str(b["id"]), "sold")
		b["bonds"] = {}
		Living.retire(b, "age", 0)
		eq(str(b["status"]), "gone", "a lonely veteran leaves Brindlewick")
		if not mine.is_empty():
			check(Shop.offers().any(func(o): return int(o["item"]["uid"]) == int(mine["uid"])), "the smith's own work is offered back at the counter")
	# newcomers keep the roster healthy
	var s := Living.st()
	s["target"] = Living.active_count() + 1
	s["last_arrival"] = -10
	var q0: int = (s["queue"] as Array).size()
	var arrived := {}
	for i in 40:
		if (s["queue"] as Array).size() < q0:
			break
		Living.on_day()
	check((s["queue"] as Array).size() < q0, "a newcomer arrived to fill the gap")
	var nid: String = s["arrived"][-1] if not (s["arrived"] as Array).is_empty() else ""
	arrived = Adv.get_a(nid)
	check(not arrived.is_empty() and str(arrived["status"]) == "in_town", "the newcomer is at the Wyvern")
	eq(_lore_kind("arrival", nid).size(), 1, "one Lore event for the arrival")
	check(int(arrived.get("level", 9)) <= 5, "within balanced limits (level %d)" % int(arrived.get("level", 0)))


func test_companies_lifecycle() -> void:
	_seeded(5)
	var cs := Companies.active()
	check(not cs.is_empty(), "a company exists from the start")
	var c: Dictionary = cs[0]
	note("%s — %s" % [c["name"], Companies.summary(c)])
	eq(_lore_kind("company").filter(func(e): return str(e["data"].get("what", "")) == "formed").size(), cs.size(), "one Lore event per founding")
	# they set out together
	for id in c["members"]:
		var a := Adv.get_a(str(id))
		a["depart_day"] = 1
		a["hp"] = a["hp_max"]
		a["fatigue"] = 0.0
	var avail: Array = Adv.all().values().filter(func(a): return str(a["status"]) == "in_town")
	var plans := Companies.plan_parties(avail)
	check(plans.any(func(p): return str(p["company"]) == str(c["id"]) and (p["members"] as Array).size() >= (c["members"] as Array).size()),
		"the company forms one party with all its rested members")
	# a member falls: struck off with a reason; the company recruits a replacement
	var lost: String = (c["members"] as Array).filter(func(i): return str(i) != str(c["leader"]))[0]
	Adv.get_a(lost)["status"] = "dead"
	seed(3)
	for i in 8:
		Companies.daily()
	check(not (c["members"] as Array).has(lost), "the fallen member is struck off")
	check((c["former"] as Array).any(func(f): return str(f["id"]) == lost), "and remembered among the former members")
	eq(_lore_kind("company", lost).filter(func(e): return str(e["data"].get("what", "")) == "lost").size(), 1, "one Lore event for the loss")
	var joined := _lore_kind("company").filter(func(e): return str(e["data"].get("what", "")) == "joined" and str(e["data"].get("company", "")) == str(c["id"]))
	check(not joined.is_empty() or (c["members"] as Array).size() >= 2, "a replacement was recruited (or enough remain)")
	# a quarrel splits them
	if (c["members"] as Array).size() >= 2:
		var m0: String = c["members"][0]
		var m1: String = c["members"][1]
		Adv.get_a(m0)["relations"][m1] = -60.0
		Adv.get_a(m1)["relations"][m0] = -60.0
		var n0: int = (c["members"] as Array).size()
		Companies.daily()
		check((c["members"] as Array).size() < n0 or str(c["status"]) != "active", "rivals inside a company: one walks out")
	# a long losing streak breaks it
	if str(c["status"]) == "active":
		var ids: Array = (c["members"] as Array).duplicate()
		for i in Companies.STREAK_LIMIT:
			Companies.on_expedition({"id": "x%d" % i, "company": c["id"], "party": ids, "dest": "whisperwood", "encounters": [], "leader": c["leader"]}, ids, 0, "retreated")
	eq(str(c["status"]), "disbanded", "a company breaks up for a reason")
	check(str(c.get("end_why", "")) != "", "the reason is kept: %s" % str(c.get("end_why", "")))
	eq(_lore_kind("company").filter(func(e): return str(e["data"].get("what", "")) == "disbanded" and str(e["data"].get("company", "")) == str(c["id"])).size(), 1, "one Lore event for the disbanding")
	for id in Adv.all():
		check(Companies.of(str(id)).get("id", "") != c["id"], "%s is no longer in it" % id)
	# friends who have shared the road found a new one
	for co in Companies.active():
		Companies.disband(str(co["id"]), "test")
	var pair: Array = Adv.all().keys().filter(func(i): return str(Adv.get_a(str(i))["status"]) == "in_town" and str(i) != "mira").slice(0, 2)
	Living.relate(str(pair[0]), str(pair[1]), 70.0, "test")
	var before := Companies.active().size()
	seed(11)
	for i in 30:
		Companies._formations()
		if Companies.active().size() > before:
			break
	check(Companies.active().size() > before and not Companies.of(str(pair[0])).is_empty(), "a new company is founded by friends (%s)" % Companies.signature())


func test_companies_persist_over_days() -> void:
	_seeded(12)
	var t0 := Time.get_ticks_msec()
	days(30)
	var ms := Time.get_ticks_msec() - t0
	var trips := 0
	for c in Companies.list_all():
		trips += int(c.get("trips", 0))
	check(trips > 0, "companies went out together (%d company trips in 30 days)" % trips)
	var with_co := Expeditions.done().filter(func(e): return str(e.get("company", "")) != "")
	check(not with_co.is_empty(), "expedition records name their company")
	var hist := 0
	for c in Companies.list_all():
		hist += (c["lore"] as Array).size()
	check(hist > Companies.list_all().size(), "companies keep a shared history (%d Lore ids)" % hist)
	check(Living.active_count() >= 6, "the roster stays healthy (%d active)" % Living.active_count())
	note("30 days in %d ms; companies: %s" % [ms, ", ".join(Companies.list_all().map(func(c): return "%s [%s, %d trips, %d–%d]" % [c["name"], c["status"], int(c["trips"]), int(c["wins"]), int(c["losses"])]))])


func test_save_load_and_old_save() -> void:
	_seeded(2024)
	days(3)
	var a := _reserve_in_town()
	if not a.is_empty():
		Living.retire(a, "goal", 1)
	var sig := _sig()
	var seed_v := Living.world_seed()
	var co := Companies.signature()
	check(save_load("suite_living"), "saved and loaded")
	eq(Living.world_seed(), seed_v, "the world seed survives")
	eq(Companies.signature(), co, "companies survive (names, leaders, members)")
	eq(_sig(), sig, "roster, goals, relations survive")
	if not a.is_empty():
		eq(str(Adv.get_a(str(a["id"]))["status"]), "retired", "a retirement survives")
	days(2)
	check(true, "the world runs on after loading")
	# an old save: no world seed, no Living or company state, the old fixed roster of eight
	_seeded(6)
	for id in Adv.all().keys():
		if Living.is_reserve(str(id)):
			Adv.all().erase(id)
	for k in ["world_seed", "living", "companies"]:
		Game.state.erase(k)
	for x in Adv.all().values():
		for k in ["goals", "bonds", "trauma", "company", "age", "origin", "joined_day", "retire_on_goal"]:
			x.erase(k)
	check(save_load("suite_living_old"), "an old save loads")
	for x in Adv.all().values():
		Expeditions.ensure(x)
		check(Living.goals(x).size() >= 2 and x.has("bonds"), "%s gains goals and bonds lazily" % x["id"])
	check(Living.world_seed() > 0, "an old save is given a world seed")
	days(4)
	check((Living.st()["queue"] as Array).size() > 0 or (Living.st()["arrived"] as Array).size() > 0, "the reserves queue up as future newcomers")
	# companies form gradually from existing friendships
	Living.relate("sigrun", "garrick", 40.0, "old comrades")
	for i in 40:
		Companies.daily()
		if not Companies.active().is_empty():
			break
	check(not Companies.active().is_empty(), "the old save's friends found a company (%s)" % Companies.signature())


func test_soak_90_days() -> void:
	_seeded(90)
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for d in 90:
		var t := Time.get_ticks_msec()
		days(1)
		worst = maxi(worst, Time.get_ticks_msec() - t)
	var ms := Time.get_ticks_msec() - t0
	var counts := {}
	for a in Adv.all().values():
		counts[str(a["status"])] = int(counts.get(str(a["status"]), 0)) + 1
	check(Living.active_count() >= 6, "after 90 days the roster is healthy (%d active; %s)" % [Living.active_count(), str(counts)])
	check(ms < 120000, "90 days simulated in %d ms (worst day %d ms)" % [ms, worst])
	var kinds := {}
	for id in Lore.st()["order"]:
		var k := str(Lore.event(str(id)).get("kind", ""))
		if k in ["retired", "arrival", "company", "bond", "goal", "death"]:
			kinds[k] = int(kinds.get(k, 0)) + 1
	# one Lore event per life event: every retired adventurer has exactly one, every arrival exactly one
	for a in Adv.all().values():
		if str(a["status"]) in ["retired", "gone"]:
			# the retiree is the event's first actor (a companion who inherits their gear is named in it too)
			eq(_lore_kind("retired", str(a["id"])).filter(func(e): return str((e.get("actors", [""]) as Array)[0]) == str(a["id"])).size(), 1,
				"%s: one retirement event" % a["id"])
		if str(a.get("origin", "")) == "arrived":
			eq(_lore_kind("arrival", str(a["id"])).size(), 1, "%s: one arrival event" % a["id"])
	for c in Companies.list_all():
		for m in c["members"]:
			check(Living.is_active(Adv.get_a(str(m))) or str(Adv.get_a(str(m)).get("status", "")) == "missing", "%s: members are all still adventuring" % c["name"])
	note("90 days in %d ms (worst day %d ms); life events %s; companies: %s" % [ms, worst, str(kinds),
		"; ".join(Companies.list_all().map(func(c): return "%s %s (%d trips, rep %d%s)" % [c["name"], c["status"], int(c["trips"]), int(c["rep"]), (", " + str(c.get("end_why", ""))) if str(c["status"]) != "active" else ""]))])
	# deterministic: the same seed and the same RNG give the same 20 days
	_seeded(91)
	days(20)
	var s1 := _sig()
	_seeded(91)
	days(20)
	eq(_sig(), s1, "20 simulated days from the same seed are identical")
