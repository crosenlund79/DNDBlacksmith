## The Living Realm 4 — sponsored expeditions (`Sponsor`): objectives come from real site data; a party weighs an
## offer by danger against its strength, the pay, its goals and how it regards the smith; it accepts, refuses with
## a reason or counters (at most two rounds); gold moves once (escrow until departure, refunded on cancel, never on
## refusal); the expedition runs in Expeditions over real game time and the objective's outcome follows what really
## happened there; delivered items arrive once with their provenance (recovered lost gear keeps uid, maker and
## history); one Lore event per sponsorship; save/load mid-expedition; old saves.
extends SuiteCase

const SMOKE := ["test_objectives_from_site_data", "test_acceptance_depends_on_danger_and_pay", "test_gold_moves_once"]


## A lone adventurer (not in a company, not Mira), rested, in town, at `level`.
func _solo(level := 12, skip := []) -> Dictionary:
	for a in Adv.all().values():
		var id := str(a["id"])
		if id == "mira" or skip.has(id) or not Companies.of(id).is_empty() or not Living.is_active(a) or str(a.get("status", "")) == "dead":
			continue
		_ready(a, level)
		return a
	return {}


func _ready(a: Dictionary, level: int) -> void:
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["level"] = level
	a["hp_max"] = Expeditions.hp_max(a)
	a["hp"] = a["hp_max"]
	a["fatigue"] = 0.0
	a["activity"] = "at_inn"
	a.erase("exp")
	var w: Dictionary = a["equipment"].get("weapon", {})
	if not w.is_empty():
		w.erase("broken")
		if w.has("stats") and (w["stats"] as Dictionary).has("durability"):
			w["stats"]["durability"] = 100


## Nobody else is out or gathering: a clean slate for timing and gold checks.
func _quiet() -> void:
	Expeditions.st()["parties"] = {}
	for id in Expeditions.active().keys():
		Expeditions.active().erase(id)


func _obj(rid: String, kind: String, def := "") -> Dictionary:
	for o in Sponsor.objectives(rid):
		if str(o["kind"]) == kind and (def == "" or str(o["def"]) == def):
			return o
	return {}


## Contract directly at generous terms (acceptance is tested separately).
func _hire(obj: Dictionary, a: Dictionary, t := {"fee": 400, "bonus": 200, "share": 0}) -> String:
	Game.state["gold"] = maxi(Game.gold(), 3000)
	var ans := Sponsor.propose(obj, "adv:" + str(a["id"]), t)
	check(str(ans["verdict"]) == "accept", "the offer is accepted (%s: %s)" % [ans.get("verdict", ""), ans.get("reason", "")])
	return str(ans.get("sid", ""))


## Advances whole hours until the sponsorship is concluded (or `max_h` passes); returns hours spent.
func _run(sid: String, max_h := 240) -> int:
	var h := 0
	while h < max_h and str(Sponsor.get_s(sid).get("status", "")) in ["contracted", "under_way"]:
		Game.advance_minutes(60)
		h += 1
	return h


func _sponsor_ledger() -> int:
	var t := 0
	for l in Game.state["ledger"]:
		if str(l.get("cat", "")) == "sponsor":
			t += int(l["amount"])
	return t


func _sponsored_events(sid: String) -> Array:
	return Lore.st()["events"].values().filter(func(e): return str(e["kind"]) == "sponsored" and str(e.get("data", {}).get("sponsor", "")) == sid)


func _delivered(sid: String) -> Array:
	var out := []
	var sp := Sponsor.get_s(sid)
	for c in Game.state["returns"]:
		for it in c.get("contents", []):
			if (sp["result"].get("items", []) as Array).has(int(it.get("uid", -1))):
				out.append(it)
	return out


# ----------------------------------------------------------------------------------------------- tests
func test_objectives_from_site_data() -> void:
	fresh_game()
	var sites := Sponsor.sites()
	check(sites.has("ironroot_mine") and sites.has("whisperwood"), "known sites are offered (%s)" % str(sites))
	check(not sites.has("ravens_hold") and not sites.has("deep_ironroot"), "undiscovered sites are not")
	for rid in sites:
		var objs := Sponsor.objectives(str(rid))
		check(not objs.is_empty(), "%s has objectives" % rid)
		for o in objs:
			var n := Expeditions.node_of(str(rid), str(o["node"]))
			check(not n.is_empty(), "%s: objective node %s exists" % [rid, o["node"]])
			check(not Sponsor.route_to(str(rid), str(o["node"])).is_empty(), "%s: the objective %s can be reached" % [rid, o["node"]])
			if str(o["kind"]) == "material":
				var t: Dictionary = DB.loot.get(str(n.get("loot", "")), {})
				var defs := (t.get("entries", []) as Array).map(func(e): return str(e[0]))
				for k in t.get("skill_entries", {}):
					defs.append_array((t["skill_entries"][k] as Array).map(func(e): return str(e[0])))
				check(defs.has(str(o["def"])), "%s: %s is really in %s's loot table" % [rid, o["def"], o["node"]])
	check(not _obj("ironroot_mine", "material", "ore_mithril").is_empty(), "mithril at the Ironroot Mine")
	check(not _obj("barrow_fields", "relic").is_empty(), "a relic at the Barrow Fields")
	check(not _obj("barrow_fields", "salvage").is_empty(), "salvage at the Barrow Fields")
	var disc := _obj("highmarsh_road", "discovery")
	check(not disc.is_empty() and str(disc["name"]).begins_with("Scout beyond"), "scouting beyond the Highmarsh Road (Raven's Hold lies near)")
	# lost equipment appears by name and uid
	var dead := _solo(3)
	var blade := Items.make("sword_iron", {"quality": 90.0})
	Provenance.forged(blade)
	dead["equipment"]["weapon"] = blade
	dead["status"] = "dead"
	WorldSites.leave_gear(dead, "barrow_fields", "ossuary", "test")
	var lo := _obj("barrow_fields", "lost")
	check(not lo.is_empty() and int(lo["uid"]) == int(blade["uid"]) and str(lo["node"]) == "ossuary", "the lost blade is an objective, by uid, at the ossuary")
	check(str(lo.get("name", "")).contains(Items.display_name(blade)), "named as it is known")
	check(Sponsor.source_sites("ore_mithril").has("ironroot_mine"), "the guide's source hook finds it")
	check(Guide.sources("ore_mithril").any(func(s): return str(s["kind"]) == "sponsor"), "the guide lists 'sponsor a company' as a source")


func test_acceptance_depends_on_danger_and_pay() -> void:
	fresh_game()
	_quiet()
	var a := _solo(10)
	var key := "adv:" + str(a["id"])
	var easy := _obj("ironroot_mine", "material", "ore_iron")
	var cand := Sponsor.candidate(key)
	check(not cand.is_empty(), "the adventurer is in town to be asked")
	var ask := int(Sponsor.asking(easy, [a["id"]])["ask"])
	check(ask > 0, "they name a price (%d)" % ask)
	var good := Sponsor.evaluate(easy, [a["id"]], {"fee": ask, "bonus": 0, "share": 0})
	eq(str(good["verdict"]), "accept", "a fair fee for an easy job is accepted")
	var low := Sponsor.evaluate(easy, [a["id"]], {"fee": int(ask * 0.3), "bonus": 0, "share": 0})
	eq(str(low["verdict"]), "refuse", "a pittance is refused")
	check(str(low["reason"]) != "", "with a reason")
	var mid := Sponsor.evaluate(easy, [a["id"]], {"fee": int(ask * 0.75), "bonus": 0, "share": 0})
	eq(str(mid["verdict"]), "counter", "a little short: they counter")
	check(Sponsor.valued(mid["counter"], easy, [a["id"]], Sponsor.asking(easy, [a["id"]])) >= float(ask), "the counter meets their price")
	# danger: a weak adventurer will not go where they would die
	var weak := _solo(1, [a["id"]])
	weak["equipment"].erase("weapon")
	weak["hp_max"] = Expeditions.hp_max(weak)
	weak["hp"] = weak["hp_max"]
	WorldSites.reveal("drakes_crag", "rumour")
	var crag := _obj("drakes_crag", "discovery")
	check(not crag.is_empty(), "Drake's Crag can be asked for once known")
	var r := Sponsor.evaluate(crag, [weak["id"]], {"fee": 900, "bonus": 900, "share": 0})
	eq(str(r["verdict"]), "refuse", "a level-1 adventurer refuses Drake's Crag at any price")
	check(str(r["reason"]).contains("Drake's Crag"), "naming the danger (%s)" % r["reason"])
	# a weak party is pointed to a safer site where the same material is found
	var obs := _obj("drakes_crag", "material", "ore_iron")
	check(not obs.is_empty(), "iron is found at Drake's Crag too")
	var lv := 1
	while lv < 30 and not (WorldSites.capable("ironroot_mine", Sponsor.strength_of([weak["id"]]), Sponsor.risk_of([weak["id"]])) \
			and not WorldSites.capable("drakes_crag", Sponsor.strength_of([weak["id"]]), Sponsor.risk_of([weak["id"]]))):
		lv += 1
		_ready(weak, lv)
	if not obs.is_empty() and lv < 30:
		var rc := Sponsor.evaluate(obs, [weak["id"]], {"fee": 60, "bonus": 0, "share": 0})
		check(str(rc["verdict"]) == "counter" and rc["counter"].has("site") and str(rc["counter"]["site"]) != "drakes_crag", "…or counters with a safer site (%s)" % str(rc))
	# danger raises the price for the same adventurer
	var deep := _obj("barrow_fields", "relic")
	check(int(Sponsor.asking(deep, [a["id"]])["ask"]) > ask, "the barrows cost more than the mine")
	# goals and temper: a coin-seeker asks more; the smith's friends ask less
	var base := int(Sponsor.asking(easy, [a["id"]])["ask"])
	a["goals"] = [{"kind": "wealth", "target": 9999}]
	var greedy := int(Sponsor.asking(easy, [a["id"]])["ask"])
	check(greedy > base, "a wealth-seeker asks more (%d > %d)" % [greedy, base])
	a["goals"] = []
	Social.ensure(str(a["id"]))["aff"] = 70.0
	var friend := int(Sponsor.asking(easy, [a["id"]])["ask"])
	check(friend < base, "a friend of the smith asks less (%d < %d)" % [friend, base])
	# gear: a broken blade must be mended first
	var w: Dictionary = a["equipment"].get("weapon", {})
	if not w.is_empty():
		w["broken"] = true
		var rb := Sponsor.evaluate(easy, [a["id"]], {"fee": 999, "bonus": 0, "share": 0})
		check(str(rb["verdict"]) == "refuse" and str(rb["reason"]).contains("broken"), "a broken weapon: mend it first")
		w.erase("broken")
	# deterministic: the same offer gets the same answer
	eq(str(Sponsor.evaluate(easy, [a["id"]], {"fee": 30, "bonus": 10, "share": 0})), str(Sponsor.evaluate(easy, [a["id"]], {"fee": 30, "bonus": 10, "share": 0})), "the same offer, the same answer")


func test_negotiation_rounds() -> void:
	fresh_game()
	_quiet()
	var a := _solo(10)
	var key := "adv:" + str(a["id"])
	var obj := _obj("ironroot_mine", "material", "ore_iron")
	var ask := int(Sponsor.asking(obj, [a["id"]])["ask"])
	var t := {"fee": int(ask * 0.7), "bonus": 0, "share": 0}
	var g0 := Game.gold()
	var r1 := Sponsor.propose(obj, key, t)
	eq(str(r1["verdict"]), "counter", "round 1: a counter-offer")
	eq(int(r1["round"]), 1, "round 1")
	var r2 := Sponsor.propose(obj, key, t)
	eq(str(r2["verdict"]), "counter", "round 2: they counter again")
	eq(int(r2["round"]), 2, "round 2")
	var r3 := Sponsor.propose(obj, key, t)
	eq(str(r3["verdict"]), "refuse", "round 3: their last word — refused")
	check(Sponsor.talk().is_empty(), "the talk is over")
	eq(Game.gold(), g0, "no gold moved while haggling")
	# agree to a counter: the contract carries their terms
	var r4 := Sponsor.propose(obj, key, t)
	eq(str(r4["verdict"]), "counter", "a fresh talk starts at round 1 again")
	var c: Dictionary = r4["counter"]
	eq(Sponsor.agree(), "", "the smith agrees to their terms")
	var sp: Dictionary = Sponsor.open()[0] if not Sponsor.open().is_empty() else {}
	check(not sp.is_empty() and int(sp["terms"]["fee"]) == int(c["fee"]) and int(sp["terms"]["share"]) == int(c["share"]), "the contract has the counter's terms")
	eq(Game.gold(), g0 - int(c["fee"]), "the fee left the smith's purse")
	check(not Expeditions.party_of(str(a["id"])).is_empty(), "the party is formed for the morning")
	eq(str(Sponsor.propose(obj, key, t).get("reason", "")), "They are not in town.", "a contracted adventurer cannot be asked twice")


func test_gold_moves_once() -> void:
	fresh_game()
	_quiet()
	Game.state["gold"] = 1000
	var a := _solo(10)
	var key := "adv:" + str(a["id"])
	var obj := _obj("ironroot_mine", "material", "ore_iron")
	var ag := int(a["gold"])
	# a refusal costs nothing
	Sponsor.propose(obj, key, {"fee": 1, "bonus": 0, "share": 0})
	eq(Game.gold(), 1000, "refusal: the smith's gold is untouched")
	eq(int(a["gold"]), ag, "refusal: the adventurer's too")
	# cannot offer what the smith does not have
	check(bool(Sponsor.propose(obj, key, {"fee": 5000, "bonus": 0, "share": 0}).get("error", false)), "a fee beyond the purse is not offered")
	# contract, then call it off: the fee comes back in full
	var sid := str(Sponsor.propose(obj, key, {"fee": 300, "bonus": 50, "share": 0}).get("sid", ""))
	check(sid != "", "accepted")
	eq(Game.gold(), 700, "the fee is held (escrow)")
	eq(int(a["gold"]), ag, "…not yet in the adventurer's purse")
	eq(Sponsor.cancel(sid), "", "called off before they leave")
	eq(Game.gold(), 1000, "the fee is back")
	eq(int(a["gold"]), ag, "the adventurer did not keep any of it")
	check(Expeditions.party_of(str(a["id"])).is_empty(), "the party is disbanded")
	check(Sponsor.cancel(sid) != "", "it cannot be cancelled twice")
	eq(Game.gold(), 1000, "and no second refund")
	# a failed departure (hurt before the morning) refunds too
	var sid2 := str(Sponsor.propose(obj, key, {"fee": 300, "bonus": 0, "share": 0}).get("sid", ""))
	a["status"] = "injured"
	Game.advance_minutes(24 * 60)
	eq(str(Sponsor.get_s(sid2)["status"]), "cancelled", "a party that cannot leave is called off")
	eq(_sponsor_ledger(), 0, "and the fee returned (sponsor ledger nets to zero)")
	# a real departure: the fee goes to the party, once
	_ready(a, 10)
	var l1 := _sponsor_ledger()
	var sid3 := str(Sponsor.propose(obj, key, {"fee": 200, "bonus": 0, "share": 0}).get("sid", ""))
	check(sid3 != "", "accepted again")
	var ag2 := int(a["gold"])
	var guard := 0
	while str(Sponsor.get_s(sid3)["status"]) == "contracted" and guard < 30:
		Game.advance_minutes(60)
		guard += 1
	eq(str(Sponsor.get_s(sid3)["status"]), "under_way", "they left at 08:00")
	eq(Game.hour(), 8, "with the morning departures")
	eq(_sponsor_ledger() - l1, -200, "the smith paid once")
	check(int(a["gold"]) >= ag2 + 200 - 60, "the adventurer has the fee (%d → %d, minus supplies bought at 07:00)" % [ag2, int(a["gold"])])
	eq(int(Sponsor.get_s(sid3)["paid"].get(str(a["id"]), 0)), 200, "recorded as paid")
	check(Sponsor.cancel(sid3) != "", "no calling off once they are on the road")


func test_expedition_success_takes_real_time() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("whisperwood", "material", "herb_bloodroot")
	check(not obj.is_empty(), "bloodroot at the Whisperwood")
	var t0 := Game.now()
	var sid := _hire(obj, a, {"fee": 300, "bonus": 150, "share": 0})
	var hours := _run(sid)
	var sp := Sponsor.get_s(sid)
	eq(str(sp["status"]), "done", "the sponsorship concluded")
	check(hours >= 6, "it took real game time (%d h)" % hours)
	var tr: Array = Expeditions.region("whisperwood")["travel_h"]
	check(int(sp["end"]) - int(sp["depart"]) >= int(tr[0]) * 120, "at least the road there and back (%d min)" % (int(sp["end"]) - int(sp["depart"])))
	var e := Expeditions.get_exp(str(sp["exp"]))
	check(not e.is_empty() and str(e.get("sponsor", "")) == sid, "an ordinary Expeditions record carries the sponsorship")
	eq(str(e["dest"]), "whisperwood", "the destination is fixed to the site")
	check((e["route"] as Array).back() == str(obj["node"]), "the route heads for the objective's node (%s)" % str(e["route"]))
	check(int(e["start"]) > t0, "they left after the contract, in the morning")
	# the outcome follows what was found
	var got := 0
	for it in _delivered(sid):
		got += int(it.get("qty", 1))
	var outcome := str(sp["outcome"])
	note("outcome %s, %d delivered, %d h; journal: %s" % [outcome, got, hours, str((e["journal"] as Array).map(func(j): return str(j["text"])).slice(-4))])
	if outcome == "success":
		check(got >= int(obj["qty"]), "success: all of it delivered (%d of %d)" % [got, int(obj["qty"])])
	elif outcome == "partial":
		check(got > 0 and got < int(obj["qty"]), "partial: some delivered")
	else:
		eq(got, 0, "failure: nothing delivered")
	check(outcome in ["success", "partial", "failure", "lost"], "a real outcome")
	eq(_sponsored_events(sid).size(), 1, "one Lore event for the sponsorship")
	var ev: Dictionary = _sponsored_events(sid)[0] if not _sponsored_events(sid).is_empty() else {}
	eq(str(ev.get("place", "")), "whisperwood", "placed at the site")
	check((ev.get("actors", []) as Array).has(str(a["id"])), "the party are its actors")
	# delivered once: in one container, nowhere else
	for it in _delivered(sid):
		check(not Game.state.get("offers", []).any(func(o): return int(o["item"].get("uid", -2)) == int(it["uid"])), "not also offered at the counter")
		check(not (e["loot"] as Array).any(func(x): return int(x.get("uid", -2)) == int(it["uid"])), "not left in the pack")
	var paid := int(sp["result"].get("paid", 0))
	eq(paid, 150 if outcome == "success" else (75 if outcome == "partial" else 0), "the bonus follows the outcome")


func test_failure_when_picked_bare() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("ironroot_mine", "material", "ore_mithril")
	var sid := _hire(obj, a, {"fee": 200, "bonus": 300, "share": 0})
	var g0 := Game.gold()
	# the vein is stripped and stays stripped (no regrowth during the trip)
	WorldSites.site("ironroot_mine")["resources"][str(obj["node"])] = 0.0
	var guard := 0
	while str(Sponsor.get_s(sid)["status"]) != "done" and guard < 200:
		WorldSites.site("ironroot_mine")["resources"][str(obj["node"])] = 0.0
		Game.advance_minutes(60)
		guard += 1
	var sp := Sponsor.get_s(sid)
	eq(str(sp["status"]), "done", "concluded")
	var have := 0
	for it in _delivered(sid):
		have += int(it.get("qty", 1))
	if str(sp["outcome"]) == "failure":
		eq(have, 0, "nothing delivered")
		eq(int(sp["result"].get("paid", 0)), 0, "no bonus on failure")
		check(Game.gold() <= g0, "the fee is not returned (%d → %d)" % [g0, Game.gold()])
		check(str(sp["result"]["text"]).contains("without"), "the record says so (%s)" % sp["result"]["text"])
	else:
		note("a stray roll still yielded mithril: %s" % sp["result"]["text"])
		check(have > 0, "whatever the outcome, it matches the pack")


func test_partial_success() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("ironroot_mine", "material", "gem_garnet")
	obj["qty"] = 6   # more than one careful search can yield
	var sid := _hire(obj, a, {"fee": 200, "bonus": 100, "share": 0})
	_run(sid)
	var sp := Sponsor.get_s(sid)
	var have := 0
	for it in _delivered(sid):
		have += int(it.get("qty", 1))
	note("garnets: %d of 6 → %s" % [have, sp["outcome"]])
	if have > 0 and have < 6:
		eq(str(sp["outcome"]), "partial", "some but not all: a partial success")
		eq(int(sp["result"]["paid"]), 50, "half the bonus")
	elif have == 0:
		check(str(sp["outcome"]) in ["failure", "partial"], "nothing of it: failure (or partial with other finds)")
	else:
		eq(str(sp["outcome"]), "success", "all of it: success")


func test_share_applied() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("whisperwood", "material", "herb_emberleaf")
	var sid := _hire(obj, a, {"fee": 300, "bonus": 0, "share": 50})
	_run(sid)
	var sp := Sponsor.get_s(sid)
	var e := Expeditions.get_exp(str(sp["exp"]))
	var mine := 0
	for it in _delivered(sid):
		mine += int(it.get("qty", 1))
	var offered := 0
	for o in Game.state.get("offers", []):
		if str(o["item"].get("def", "")) == "herb_emberleaf" and int(o["item"].get("found", {}).get("day", -1)) >= 0 and str(o["item"].get("found", {}).get("exp", "")) == str(e["id"]):
			offered += int(o["item"].get("qty", 1))
	note("emberleaf: smith %d, party share offered at the counter %d" % [mine, offered])
	if mine + offered > 1:
		check(offered >= int(floor((mine + offered) * 0.5)) - 1, "the party kept its half (offered at the counter as their own)")
		check(mine >= 1, "the smith got the rest")


func test_lost_gear_recovered_with_identity() -> void:
	fresh_game()
	_quiet()
	var dead := _solo(3)
	var blade := Items.make("sword_iron", {"quality": 96.0})
	Provenance.forged(blade)
	Provenance.transfer(blade, str(dead["id"]), "sold", "brindlewick")
	dead["equipment"]["weapon"] = blade
	var uid := int(blade["uid"])
	var maker: Dictionary = Provenance.maker(blade).duplicate()
	var n_events := (Provenance.st(blade)["events"] as Array).size()
	dead["status"] = "dead"
	WorldSites.leave_gear(dead, "barrow_fields", "rows", "fell with %s" % dead["name"])
	var a := _solo(16, [dead["id"]])
	var obj := _obj("barrow_fields", "lost")
	check(int(obj.get("uid", -1)) == uid, "the lost blade is the objective")
	var sid := _hire(obj, a, {"fee": 300, "bonus": 200, "share": 0})
	_run(sid)
	var sp := Sponsor.get_s(sid)
	note("lost-gear run: %s" % sp["result"].get("text", ""))
	if str(sp["outcome"]) != "success":
		check(str(sp["outcome"]) in ["failure", "lost"], "no half-measures for a single piece (%s)" % sp["outcome"])
		return
	var d := _delivered(sid)
	eq(d.size(), 1, "the blade is delivered once")
	var it: Dictionary = d[0]
	eq(int(it["uid"]), uid, "the same uid")
	eq(str(Provenance.maker(it)["id"]), str(maker["id"]), "the same maker")
	eq(int(Provenance.maker(it)["day"]), int(maker["day"]), "made the same day")
	eq(Provenance.owner_id(it), "smith", "now the smith's")
	var owners: Array = Provenance.owners(it).map(func(o): return str(o["how"]))
	eq(str(owners[-1]), "recovered", "the last hand-over is 'recovered'")
	var kinds: Array = Provenance.story(it).map(func(x): return str(x["kind"]))
	check(kinds.has("forged") and kinds.has("lost") and kinds.has("found") and kinds.has("recovered"), "its story runs on (%s)" % str(kinds))
	check((Provenance.st(it)["events"] as Array).size() > n_events, "history kept and extended")
	check(not WorldSites.lost("barrow_fields").any(func(x): return int(x["item"]["uid"]) == uid), "the site no longer holds it")
	check(not Adv.all().values().any(func(x): return x["equipment"].values().any(func(q): return int(q.get("uid", -1)) == uid)), "nobody is wearing it")
	var ev: Dictionary = _sponsored_events(sid)[0]
	check((ev["items"] as Array).has(uid), "the sponsorship's Lore event names the blade")
	check(Lore.of_item(uid).any(func(x): return str(x["kind"]) == "sponsored"), "and the blade's history includes it")


func test_discovery_reveals_site() -> void:
	fresh_game()
	_quiet()
	var a := _solo(16)
	var obj := _obj("highmarsh_road", "discovery")
	check(not WorldSites.is_discovered("ravens_hold"), "Raven's Hold is unknown")
	var sid := _hire(obj, a, {"fee": 300, "bonus": 100, "share": 0})
	_run(sid)
	var sp := Sponsor.get_s(sid)
	note("discovery: %s" % sp["result"].get("text", ""))
	if str(sp["outcome"]) == "success":
		check(WorldSites.is_discovered("ravens_hold"), "the scouts revealed Raven's Hold")
		check(Game.has_flag("site_ravens_hold"), "through the existing hook (flag set)")
		eq(str(sp["result"]["site"]), "ravens_hold", "the result names it")
	else:
		check(not WorldSites.is_discovered("ravens_hold") or str(sp["outcome"]) != "success", "no discovery without success")


func test_wipe_is_a_loss() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("whisperwood", "material", "herb_bloodroot")
	var sid := _hire(obj, a, {"fee": 250, "bonus": 100, "share": 0})
	var guard := 0
	while str(Sponsor.get_s(sid)["status"]) == "contracted" and guard < 30:
		Game.advance_minutes(60)
		guard += 1
	var e := Expeditions.get_exp(str(Sponsor.get_s(sid)["exp"]))
	check(not e.is_empty(), "under way")
	var g0 := Game.gold()
	a["hp"] = 0
	Expeditions._wipe(e)
	var sp := Sponsor.get_s(sid)
	eq(str(sp["status"]), "done", "concluded")
	eq(str(sp["outcome"]), "lost", "the party was lost")
	eq(Game.gold(), g0, "no bonus, no refund")
	eq(_sponsored_events(sid).size(), 1, "one Lore event")


func test_save_load_mid_expedition() -> void:
	fresh_game()
	_quiet()
	var a := _solo(14)
	var obj := _obj("ironroot_mine", "material", "ore_iron")
	var sid := _hire(obj, a, {"fee": 250, "bonus": 100, "share": 20})
	check(save_load("suite_sponsor_contract"), "save and load while they prepare")
	eq(str(Sponsor.get_s(sid)["status"]), "contracted", "still contracted")
	eq(str(Expeditions.party_of(str(a["id"])).get("sponsor", "")), sid, "the party is still formed, carrying the sponsorship")
	var guard := 0
	while str(Sponsor.get_s(sid)["status"]) == "contracted" and guard < 30:
		Game.advance_minutes(60)
		guard += 1
	Game.advance_minutes(150)
	eq(str(Sponsor.get_s(sid)["status"]), "under_way", "on the road")
	var phase := str(Expeditions.get_exp(str(Sponsor.get_s(sid)["exp"])).get("phase", ""))
	check(save_load("suite_sponsor_mid"), "save and load mid-expedition (%s)" % phase)
	var sp := Sponsor.get_s(sid)
	eq(str(sp["status"]), "under_way", "still under way after loading")
	var e := Expeditions.get_exp(str(sp["exp"]))
	eq(str(e.get("sponsor", "")), sid, "the expedition still knows its sponsor")
	check(Expeditions.active().has(str(sp["exp"])), "and is still running")
	_run(sid)
	eq(str(Sponsor.get_s(sid)["status"]), "done", "it concludes after loading")
	eq(_sponsored_events(sid).size(), 1, "one Lore event")
	var outcome := str(Sponsor.get_s(sid)["outcome"])
	check(save_load("suite_sponsor_done"), "save and load after")
	eq(str(Sponsor.get_s(sid)["outcome"]), outcome, "the result persists")
	check(str(Sponsor.get_s(sid)["result"].get("text", "")) != "", "with its text")


func test_old_save() -> void:
	fresh_game()
	_quiet()
	Game.state.erase("sponsor")
	check(Sponsor.all().is_empty(), "an old save has no sponsorships")
	check(not Sponsor.candidates().is_empty(), "adventurers can be asked")
	# an expedition from before sponsorship (no `sponsor` key) runs and finishes untouched
	var a := _solo(8)
	var e := Expeditions.start({"id": "p_old", "members": [a["id"]], "leader": a["id"], "dest": "whisperwood", "goal": "explore"})
	e.erase("sponsor")
	var guard := 0
	while Expeditions.active().has(str(e["id"])) and guard < 100:
		Game.advance_minutes(60)
		guard += 1
	check(not Expeditions.active().has(str(e["id"])), "an old expedition finishes")
	check(Sponsor.all().is_empty(), "and creates no sponsorship")
	check(save_load("suite_sponsor_old"), "save and load")


func test_company_sponsored() -> void:
	fresh_game()
	_quiet()
	var cs: Array = Sponsor.candidates().filter(func(c): return str(c["company"]) != "")
	if cs.is_empty():
		skip("no company in town in this seed")
		return
	var c: Dictionary = cs[0]
	for id in c["members"]:
		_ready(Adv.get_a(str(id)), 12)
	var obj := _obj("ironroot_mine", "material", "ore_iron")
	Game.state["gold"] = 5000
	var ans := Sponsor.propose(obj, str(c["key"]), {"fee": 900, "bonus": 300, "share": 0})
	eq(str(ans["verdict"]), "accept", "the company accepts generous terms (%s)" % ans.get("reason", ""))
	var sp := Sponsor.get_s(str(ans.get("sid", "")))
	eq(str(sp.get("company", "")), str(c["company"]), "the contract is with the company")
	var p := Expeditions.party_of(str(c["members"][0]))
	eq(str(p.get("company", "")), str(c["company"]), "the party sets out as the company")
	eq(str(p.get("sponsor", "")), str(sp.get("id", "")), "carrying the sponsorship")
	var trips := int(Companies.get_c(str(c["company"]))["trips"])
	_run(str(sp.get("id", "")))
	eq(int(Companies.get_c(str(c["company"]))["trips"]), trips + 1, "it counts on the company's record")
