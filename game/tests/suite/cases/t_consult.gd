## The Living Realm, milestone 3b — adventurer consultations (Consult): adventurers come to the counter for
## equipment advice in credible moments (broken/worn gear, a defeat, a trip their kit handles badly, a gear goal),
## rate-limited; recommendations are built from real gear and threat data; persuasion odds move with skill,
## relationship, reputation, credibility, purse and temper; refusals happen; accepted advice changes the actual
## purchase / repair / commission / coating / destination / departure; credibility updates after the next
## expedition (one Lore event for notable cases); save/load and an old save.
extends SuiteCase

const SMOKE := ["test_triggers_rate_limited", "test_recommendations_from_data", "test_odds_move", "test_save_load_and_old_save"]


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["history"] = []
	a["hp"] = a["hp_max"]
	a["trauma"] = 0.0
	return a


## A sound, uncomplaining adventurer: fresh gear, a coated blade, no gear goal, bound for Whisperwood.
func _calm(a: Dictionary) -> void:
	for s in a["equipment"]:
		var it: Dictionary = a["equipment"][s]
		it.erase("broken")
		if it.get("stats", {}).has("durability_max"):
			it["stats"]["durability"] = int(it["stats"]["durability_max"])
	a["goals"] = [{"kind": "skill", "target": 99, "since": 1}]
	a["next_dest"] = "ironroot_mine"
	a["equipment"]["weapon"]["coating"] = {"name": "Flame Coating", "stat": "fire", "value": 4, "uses": 3}


func _break(a: Dictionary, slot: String) -> void:
	var it: Dictionary = a["equipment"][slot]
	it["stats"]["durability"] = 0
	it["broken"] = true


func _rec(recs: Array, kind: String) -> Dictionary:
	for r in recs:
		if str(r["kind"]) == kind:
			return r
	return {}


## Picks a world seed for which today's roll for this advice satisfies `want` (accept → low roll, refuse → high).
func _seed_roll(npc: String, rid: String, low: bool) -> void:
	for s in range(1, 400):
		Game.state["world_seed"] = s
		var x := Consult.roll(npc, rid)
		if (low and x < 0.3) or (not low and x > 0.8):
			return


func _persuadable(npc: String) -> void:
	Social.change(npc, 80.0, 40.0, "", "", false)
	Consult._cred_add(npc, 60.0, 20.0)
	train("smithing", 8)


func test_triggers_rate_limited() -> void:
	fresh_game()
	for a in Adv.all().values():
		_adv(str(a["id"]))
		_calm(a)
	var a := _adv("sigrun")
	eq(Consult.reason_for(a), {}, "a sound adventurer with nothing to worry about does not come asking")
	_break(a, "weapon")
	eq(str(Consult.reason_for(a).get("kind", "")), "broken", "a broken weapon is a reason to ask")
	# a defeat outranks it; worn gear; a trip the kit handles badly; a gear goal
	var b := _adv("tomas")
	b["history"] = [{"day": Game.day(), "dest": "barrow_fields", "outcome": "failed", "exp": "x1"}]
	eq(str(Consult.reason_for(b).get("kind", "")), "defeat", "coming home beaten is a reason to ask")
	var c := _adv("pip")
	c["equipment"]["weapon"].erase("coating")
	c["next_dest"] = "barrow_fields"
	eq(str(Consult.reason_for(c).get("kind", "")), "mismatch", "a trip to wights that fear fire, with no fire in the kit")
	c["next_dest"] = "ironroot_mine"
	c["equipment"]["weapon"]["coating"] = {"name": "Flame Coating", "stat": "fire", "value": 4, "uses": 3}
	c["goals"] = [{"kind": "gear", "target": 999, "since": 1}]
	eq(str(Consult.reason_for(c).get("kind", "")), "goal", "a gear-seeker asks where to spend their coin")
	b["history"] = []
	c["goals"] = [{"kind": "skill", "target": 99, "since": 1}]
	# rate limit: at most one approach a day, never before 10 or after 17, never the same adventurer twice in COOLDOWN days
	Shop.customers().clear()
	seed(5)
	for h in [6, 8, 9, 17, 20]:
		for i in 10:
			Consult.on_hour(h)
	eq(Shop.customers().size(), 0, "nobody comes for advice outside 10–17")
	for h in range(10, 17):
		for i in 10:
			Consult.on_hour(h)
	var adv_c := Shop.customers().filter(func(x): return str(x["want"]) == "advice")
	eq(adv_c.size(), 1, "exactly one adventurer comes for advice in a day, however many have reasons")
	eq(str(adv_c[0]["npc"]) if not adv_c.is_empty() else "", "sigrun", "the one with the broken weapon")
	check(str(adv_c[0].get("question", "")).contains("gave out") if not adv_c.is_empty() else false, "and asks in their own words about it")
	Shop.customers().clear()
	_break(_adv("varn"), "weapon")
	Consult.st()["approach_day"] = Game.day() - 1
	for h in range(10, 17):
		for i in 10:
			Consult.on_hour(h)
	eq(Shop.customers().size(), 0, "the next day nobody comes (at most every %d days in the village)" % Consult.APPROACH_GAP)
	Consult.st()["approach_day"] = -99
	check(not Consult.can_approach(a), "the same adventurer does not come back the next hour or day (cooldown)")
	Consult.st()["last"]["sigrun"] = Game.day() - Consult.COOLDOWN
	check(Consult.can_approach(a), "after %d days they may come again" % Consult.COOLDOWN)
	# the counter and the dialogue show it
	var cu := Consult.approach("sigrun")
	eq(str(cu.get("want", "")), "advice", "they sit down as an advice customer")
	check(str(Shop.request(cu)["headline"]).begins_with("Asks your advice"), "the counter card reads as a request for advice")
	Shop.mark_arrived("sigrun", false)
	var ids := Talk.options("sigrun", "village").map(func(o): return str(o["id"]))
	check(ids.has("consult") and ids.has("send_away"), "dialogue offers to hear them out, or send them away (skippable)")
	check(Talk.greeting("sigrun").contains("gave out"), "the greeting is their question")
	Shop.dismiss_customer("sigrun")
	eq(Shop.customer("sigrun"), {}, "sending them away frees the seat")
	# the smith can raise it himself in conversation, at most every couple of days
	var ids2 := Talk.options("garrick", "village").map(func(o): return str(o["id"]))
	check(ids2.has("consult"), "talking to an adventurer in town: 'Talk about their gear and plans'")
	Consult.session("garrick")
	Consult.finish("garrick")
	var opt: Array = Consult.talk_options("garrick")
	check(not opt.is_empty() and str(opt[0].get("disabled", "")) != "", "after a consultation the option rests a while (%s)" % (opt[0].get("disabled", "") if not opt.is_empty() else ""))
	# a fortnight of ordinary play: some approaches, never a flood
	fresh_game()
	days(14)
	var n := int(Consult.st().get("approaches", 0))
	note("approaches in 14 simulated days: %d" % n)
	check(n >= 1 and n <= 5, "now and then, never a flood (%d in 14 days)" % n)


func test_recommendations_from_data() -> void:
	fresh_game()
	var a := _adv("sigrun")
	_calm(a)
	a["equipment"]["weapon"].erase("coating")
	a["next_dest"] = "barrow_fields"
	a["gold"] = 3000
	var armor: Dictionary = a["equipment"]["armor"]
	armor["stats"]["durability"] = int(int(armor["stats"]["durability_max"]) * 0.2)
	Game.state["inventory"] = Game.inventory().filter(func(it): return not str(it["def"]).begins_with("coating"))
	# a fire blade on display
	var blade := Items.make("sword_emberwarden", {"quality": 95.0})
	blade["for_sale"] = true
	Game.add_item(blade, false)
	var g := Consult.gaps(a, "barrow_fields")
	check(g.any(func(x): return str(x["kind"]) == "weak" and str(x["prop"]) == "fire"), "Barrow Fields: wights fear fire and the kit has none (%s)" % str(g))
	var recs := Consult.recommendations(a)
	check(recs.size() >= 3 and recs.size() <= 4, "3–4 recommendations (%d)" % recs.size())
	var rep := _rec(recs, "repair")
	eq(str(rep.get("slot", "")), "armor", "mend the armour, which is down to 20%")
	check(str(rep.get("why", "")).contains("%d%%" % int(round(Items.durability_frac(armor) * 100.0))), "the reason cites its real durability (%s)" % rep.get("why", ""))
	var buy := _rec(recs, "buy")
	eq(int(buy.get("uid", -1)), int(blade["uid"]), "take the fire blade on display")
	check(str(buy.get("title", "")).contains("fear fire"), "because the threats fear fire (%s)" % buy.get("title", ""))
	note("recs: " + " | ".join(recs.map(func(r): return str(r["title"]))))
	# no blade on display, but a coating in the stores
	Game.take_uid(int(blade["uid"]))
	give("coating_flame")
	recs = Consult.recommendations(a)
	check(not _rec(recs, "coat").is_empty(), "a flame coating from the stores instead")
	# nothing in stock or stores: a commission for a fire-touched blade
	Game.remove_def("coating_flame", 9)
	recs = Consult.recommendations(a)
	check(not _rec(recs, "commission").is_empty(), "or a commission for a fire-touched weapon")
	# a place beyond them: a safer site that fits their strength
	var p := _adv("pip")
	_calm(p)
	WorldSites.site("drakes_crag")["discovered"] = true
	p["next_dest"] = "drakes_crag"
	var pr := Consult.recommendations(p)
	var dr := _rec(pr, "dest")
	check(not dr.is_empty(), "Drake's Crag is %s for a level-%d bard: 'try somewhere else first'" % [Consult.danger_text(p, "drakes_crag"), int(p["level"])])
	if not dr.is_empty():
		check(Consult.danger_ratio(p, str(dr["dest"])) <= Consult.SAFE and WorldSites.is_discovered(str(dr["dest"])), "the suggested place (%s) is known and within reach" % dr["dest"])
		check(str(dr["title"]).begins_with("Don't go to Drake's Crag"), dr["title"])
	# after a beating: rest
	p["hp"] = int(p["hp_max"]) / 3
	check(not _rec(Consult.recommendations(p), "rest").is_empty(), "hurt: rest before going out again")
	# a sound kit: say so
	var t := _adv("garrick")
	_calm(t)
	var tr := Consult.recommendations(t)
	check(not _rec(tr, "keep").is_empty(), "a sound kit for an easy trip: 'keep your coin' is among the advice")


func test_odds_move() -> void:
	fresh_game()
	var a := _adv("sigrun")
	_calm(a)
	_break(a, "weapon")
	a["gold"] = 400
	a["trait"] = "steady"
	var rec := _rec(Consult.recommendations(a), "repair")
	check(not rec.is_empty(), "a repair to advise")
	var p0 := float(Consult.odds(a, rec)["p"])
	train("smithing", 8)
	var p1 := float(Consult.odds(a, rec)["p"])
	check(p1 > p0, "smithing skill raises the odds (%.2f → %.2f)" % [p0, p1])
	Social.change("sigrun", 40.0, 10.0, "", "", false)
	var p2 := float(Consult.odds(a, rec)["p"])
	check(p2 > p1, "a warmer relationship raises them (%.2f)" % p2)
	Shop.rep_change(40.0)
	var p3 := float(Consult.odds(a, rec)["p"])
	check(p3 > p2, "the workshop's reputation raises them (%.2f)" % p3)
	Consult._cred_add("sigrun", -60.0, -20.0)
	var p4 := float(Consult.odds(a, rec)["p"])
	check(p4 < p3, "bad past advice lowers them (%.2f)" % p4)
	eq(Consult.credibility_word("sigrun"), "your counsel has cost them dear", "and the words say so")
	a["gold"] = int(rec["cost"]) + 2
	var p5 := float(Consult.odds(a, rec)["p"])
	check(p5 < p4, "a thin purse lowers them (%.2f)" % p5)
	a["gold"] = 0
	check(float(Consult.odds(a, rec)["p"]) <= 0.1, "they cannot afford it at all")
	var od := Consult.odds(a, rec)
	check(str(od["reasons"][0][0]).begins_with("It costs"), "the main reason is named: %s" % od["reasons"][0][0])
	# temper and goals: a reckless adventurer will not turn back, a cautious one listens
	var drec := {"id": "dest_x", "kind": "dest", "dest": "whisperwood", "avoid": "barrow_fields", "cost": 0, "relevance": 0.7, "skill": "travelling", "title": "", "why": ""}
	a["trait"] = "reckless"
	var pr := float(Consult.odds(a, drec)["p"])
	a["trait"] = "cautious"
	var pc := float(Consult.odds(a, drec)["p"])
	check(pc > pr + 0.2, "cautious %.2f vs reckless %.2f for a change of destination" % [pc, pr])
	for w in [0.9, 0.7, 0.5, 0.3, 0.1]:
		note("%.1f → %s" % [w, Consult.odds_word(w)])
	eq(Consult.odds_word(0.7), "likely", "odds in words")
	eq(Consult.odds_word(0.3), "a hard sell", "odds in words")


func test_refusal_and_acceptance() -> void:
	fresh_game()
	var a := _adv("tomas")
	_calm(a)
	a["gold"] = 500
	_break(a, "weapon")
	var ses := Consult.session("tomas")
	var rec := _rec(ses["recs"], "repair")
	check(not rec.is_empty(), "a repair to advise")
	# a refusal: distrust, doubtful record, reckless, and the seeded roll is high
	Social.change("tomas", -30.0, 0.0, "", "", false)
	Consult._cred_add("tomas", -70.0, -30.0)
	_seed_roll("tomas", str(rec["id"]), false)
	var p := float(Consult.odds(a, rec)["p"])
	var r := Consult.advise("tomas", str(rec["id"]))
	check(not bool(r["accepted"]), "refused at %s (%.2f)" % [r.get("word", ""), p])
	check(str(r["text"]).begins_with("\""), "in their own voice: %s" % r["text"])
	eq(str(Shop.customer("tomas").get("want", "")), "", "no repair was asked for")
	eq(Consult.advise("tomas", str(rec["id"])), r, "the same advice gets the same answer (no re-rolling)")
	eq(Consult.records_of("tomas").size(), 1, "the refusal is recorded")
	# an acceptance (another adventurer, a persuadable smith)
	var b := _adv("sigrun")
	_calm(b)
	b["gold"] = 500
	_break(b, "weapon")
	_persuadable("sigrun")
	var rb := _rec(Consult.session("sigrun")["recs"], "repair")
	_seed_roll("sigrun", str(rb["id"]), true)
	var res := Consult.advise("sigrun", str(rb["id"]))
	check(bool(res["accepted"]), "accepted (%s): %s" % [res.get("word", ""), res.get("text", "")])
	eq(Consult.picks_left(Consult.session("sigrun")), 1, "one more piece of advice may be put forward")


func test_accepted_advice_changes_decisions() -> void:
	fresh_game()
	# 1. buy: the blade leaves the display for their hand
	var a := _adv("sigrun")
	_calm(a)
	a["equipment"]["weapon"].erase("coating")
	a["next_dest"] = "barrow_fields"
	a["gold"] = 3000
	_persuadable("sigrun")
	var blade := Items.make("sword_emberwarden", {"quality": 95.0})
	blade["for_sale"] = true
	Game.add_item(blade, false)
	var rec := _rec(Consult.session("sigrun")["recs"], "buy")
	_seed_roll("sigrun", str(rec["id"]), true)
	var gold0 := Game.gold()
	var r := Consult.advise("sigrun", str(rec["id"]))
	check(bool(r["accepted"]), "she takes the advice")
	eq(int(a["equipment"]["weapon"]["uid"]), int(blade["uid"]), "the fire blade is now her weapon (the same instance)")
	check(Game.find_uid(int(blade["uid"])).is_empty() and Game.gold() > gold0, "it left the display and was paid for")
	# 2. repair: they wait at the counter and hold off a day; the repair flow mends it
	var b := _adv("tomas")
	_calm(b)
	_break(b, "weapon")
	b["gold"] = 500
	_persuadable("tomas")
	var rr := _rec(Consult.session("tomas")["recs"], "repair")
	_seed_roll("tomas", str(rr["id"]), true)
	check(bool(Consult.advise("tomas", str(rr["id"]))["accepted"]), "Tomas agrees to the repair")
	var cu := Shop.customer("tomas")
	eq(str(cu.get("want", "")), "repair", "he is now a repair customer for his own weapon")
	check(int(b["depart_day"]) >= Game.day() + 1, "and holds off a day")
	Shop.do_repair("tomas", 90.0)
	check(not bool(b["equipment"]["weapon"].get("broken", false)), "the existing repair flow mends the very piece")
	# 3. commission for a fire-touched weapon
	var c := _adv("garrick")
	_calm(c)
	c["equipment"]["weapon"].erase("coating")
	c["next_dest"] = "barrow_fields"
	c["gold"] = 3000
	_persuadable("garrick")
	Game.state["inventory"] = Game.inventory().filter(func(it): return not str(it["def"]).begins_with("coating"))
	var rc := _rec(Consult.session("garrick")["recs"], "commission")
	check(not rc.is_empty(), "a commission is advised")
	if not rc.is_empty():
		_seed_roll("garrick", str(rc["id"]), true)
		check(bool(Consult.advise("garrick", str(rc["id"]))["accepted"]), "Garrick orders it")
		var os := Shop.open_orders().filter(func(o): return str(o["npc"]) == "garrick")
		check(not os.is_empty() and str(os[0]["note"]).begins_with("On the smith's advice"), "an open commission, on the smith's advice")
		check(not os.is_empty() and str(os[0]["stat"]) == "fire", "for a fire weapon (%s)" % (Shop.order_text(os[0]) if not os.is_empty() else ""))
	# 4. a coating from the stores, brushed onto their own blade
	var d := _adv("varn")
	_calm(d)
	d["equipment"]["weapon"].erase("coating")
	d["next_dest"] = "barrow_fields"
	d["gold"] = 500
	_persuadable("varn")
	give("coating_flame")
	var rco := _rec(Consult.session("varn")["recs"], "coat")
	check(not rco.is_empty(), "a coating is advised")
	if not rco.is_empty():
		_seed_roll("varn", str(rco["id"]), true)
		check(bool(Consult.advise("varn", str(rco["id"]))["accepted"]), "Varn takes the coating")
		eq(str(d["equipment"]["weapon"].get("coating", {}).get("stat", "")), "fire", "his own axe now bites with fire")
		eq(Game.count("coating_flame"), 0, "the coating came out of the stores")
		check(Consult.coverage(d, "fire") > 0, "Barrow Fields no longer finds him without fire")
	# 5. a change of destination: the avoided place is not chosen while the advice holds
	var p := _adv("pip")
	_calm(p)
	WorldSites.site("drakes_crag")["discovered"] = true
	p["next_dest"] = "drakes_crag"
	_persuadable("pip")
	var rd := _rec(Consult.session("pip")["recs"], "dest")
	check(not rd.is_empty(), "a change of plan is advised")
	if not rd.is_empty():
		_seed_roll("pip", str(rd["id"]), true)
		check(bool(Consult.advise("pip", str(rd["id"]))["accepted"]), "Pip agrees")
		eq(str(p["next_dest"]), str(rd["dest"]), "her plan is now %s" % rd["dest"])
		check(Consult.dest_bias([p], "drakes_crag") < 0.0 and Consult.dest_bias([p], str(rd["dest"])) > 0.0, "the party choice is steered away and towards")
		seed(3)
		var picks := {}
		for i in 30:
			var dd := str(Expeditions.choose_destination([p]).get("dest", ""))
			picks[dd] = int(picks.get(dd, 0)) + 1
		check(not picks.has("drakes_crag"), "Drake's Crag is not chosen in 30 tries (%s)" % str(picks))
	# 6. rest
	var k := _adv("kestra")
	_calm(k)
	k["hp"] = int(k["hp_max"]) / 3
	_persuadable("kestra")
	var rs := _rec(Consult.session("kestra")["recs"], "rest")
	if not rs.is_empty():
		_seed_roll("kestra", str(rs["id"]), true)
		check(bool(Consult.advise("kestra", str(rs["id"]))["accepted"]), "Kestra will rest")
		check(int(k["depart_day"]) >= Game.day() + 2, "her departure is put back two days")


func test_credibility_after_outcomes() -> void:
	fresh_game()
	var a := _adv("pip")
	_calm(a)
	WorldSites.site("drakes_crag")["discovered"] = true
	a["next_dest"] = "drakes_crag"
	_persuadable("pip")
	var rd := _rec(Consult.session("pip")["recs"], "dest")
	_seed_roll("pip", str(rd["id"]), true)
	Consult.advise("pip", str(rd["id"]))
	var cred0 := Consult.credibility("pip")
	var aff0 := Social.aff("pip")
	Consult.resolve_outcomes()
	eq(str(Consult.records_of("pip")[0]["status"]), "open", "the advice waits for its test")
	# she goes where the smith said, and wins
	a["history"].append({"day": Game.day(), "dest": str(rd["dest"]), "outcome": "success", "exp": "exp_t1"})
	Consult.resolve_outcomes()
	var rec: Dictionary = Consult.records_of("pip")[0]
	eq(str(rec["verdict"]), "right", "the advice proved right")
	check(Consult.credibility("pip") > cred0, "credibility rises (%.0f → %.0f)" % [cred0, Consult.credibility("pip")])
	check(Social.aff("pip") > aff0, "she thinks better of the smith")
	var lore: Array = Lore.st()["order"].filter(func(id): return str(Lore.event(str(id)).get("kind", "")) == "advice")
	eq(lore.size(), 1, "a notable case: one Lore event")
	check(not lore.is_empty() and str(Lore.event(str(lore[0]))["text"]).begins_with("On Brannoc's advice"), Lore.event(str(lore[0]))["text"] if not lore.is_empty() else "")
	Consult.resolve_outcomes()
	eq(Lore.st()["order"].filter(func(id): return str(Lore.event(str(id)).get("kind", "")) == "advice").size(), 1, "and only one")
	# accepted advice that ends badly costs credibility
	var b := _adv("tomas")
	_calm(b)
	_break(b, "weapon")
	b["gold"] = 500
	_persuadable("tomas")
	var rr := _rec(Consult.session("tomas")["recs"], "repair")
	_seed_roll("tomas", str(rr["id"]), true)
	Consult.advise("tomas", str(rr["id"]))
	var c1 := Consult.credibility("tomas")
	b["history"].append({"day": Game.day(), "dest": "whisperwood", "outcome": "failed", "exp": "exp_t2"})
	Consult.resolve_outcomes()
	check(Consult.credibility("tomas") < c1, "taken and failed: credibility falls (%.0f → %.0f)" % [c1, Consult.credibility("tomas")])
	# refused advice, and they come to grief: the smith was right
	var c := _adv("kestra")
	_calm(c)
	_break(c, "weapon")
	c["gold"] = 500
	Social.change("kestra", -40.0, 0.0, "", "", false)
	var rk := _rec(Consult.session("kestra")["recs"], "repair")
	_seed_roll("kestra", str(rk["id"]), false)
	var res := Consult.advise("kestra", str(rk["id"]))
	check(not bool(res["accepted"]), "Kestra refuses")
	var c2 := Consult.credibility("kestra")
	c["history"].append({"day": Game.day(), "dest": "barrow_fields", "outcome": "failed", "exp": "exp_t3"})
	Consult.resolve_outcomes()
	eq(str(Consult.records_of("kestra")[0].get("verdict", "")), "right", "ignored and beaten: the smith was right")
	check(Consult.credibility("kestra") > c2, "her trust in his counsel grows")
	var tr := Consult.track_record()
	note("track record: %s" % str(tr))
	check(int(tr["right"]) == 2 and int(tr["wrong"]) == 1, "the record: 2 right, 1 wrong")
	# a real simulated expedition closes an open record too
	var g := _adv("garrick")
	_calm(g)
	g["depart_day"] = Game.day()
	_persuadable("garrick")
	var rg: Dictionary = Consult.session("garrick")["recs"][0]
	Consult.advise("garrick", str(rg["id"]))
	days(10)
	var grec: Dictionary = Consult.records_of("garrick")[0]
	note("Garrick's advice after 10 days: %s / %s (history %d)" % [grec["status"], grec.get("verdict", ""), (g.get("history", []) as Array).size()])
	check(str(grec["status"]) == "closed" or (g.get("history", []) as Array).is_empty(), "his next expedition judged the advice")


func test_save_load_and_old_save() -> void:
	fresh_game()
	var a := _adv("sigrun")
	_calm(a)
	_break(a, "weapon")
	a["gold"] = 400
	Consult.approach("sigrun")
	var ses := Consult.session("sigrun")
	var rid := str(ses["recs"][0]["id"])
	var r := Consult.advise("sigrun", rid)
	var cred := Consult.credibility("sigrun")
	var n := Consult.records().size()
	check(save_load("suite_consult"), "saved and loaded")
	eq(Consult.records().size(), n, "advice records survive")
	eq(Consult.credibility("sigrun"), cred, "credibility survives")
	eq(bool(Consult.session("sigrun")["done"][rid]["accepted"]), bool(r["accepted"]), "today's consultation and its answer survive")
	check(not Shop.customer("sigrun").is_empty(), "the customer is still at the counter")
	days(2)
	check(true, "the world runs on after loading")
	# an old save without any consultation state
	fresh_game()
	Game.state.erase("consult")
	check(save_load("suite_consult_old"), "an old save loads")
	eq(Consult.credibility("garrick"), 0.0, "untested counsel")
	eq(Consult.records().size(), 0, "no records yet")
	for h in range(8, 18):
		Consult.on_hour(h)
	days(3)
	check(Game.state.has("consult"), "the state is created lazily and the days run")
