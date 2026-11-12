## Milestone A1 "Protect the Foundation" — item identity (canonical §6.1 "One creation. One authentic history."):
## one canonical physical item per uid, one item-location registry (`ItemRegistry`) behind every lookup, records that
## hold a reference (uid + snapshot) instead of the live dict, purchases and returns that move the very piece (same
## uid and story) instead of copying it, hand-overs out of the forge recorded, delivered masterpieces kept outside the
## capped contract history, the old-save conversion (`ItemRegistry.migrate_records`) and the integrity probe: no uid
## in two physical holders, no item dict shared between containers, no live copy inside a record — in memory and after
## a real save/load, including a seeded 365-day light-management game.
extends SuiteCase

const SMOKE := ["test_scanner_detects_faults", "test_purchases_keep_identity", "test_repair_record_does_not_fork",
	"test_pawn_round_trip", "test_migration_converts_old_state", "test_lookups_route_through_registry"]
## Long-running tests left out of `run_tests.sh quick` (they still run in full and in CI).
const SLOW := ["test_year_integrity_probe"]


# ------------------------------------------------------------------ fixtures
func _sword(q := 104.0) -> Dictionary:
	give("ingot_iron", 6)
	give("leather_cured", 2)
	return craft("iron_longsword", q, {"edge": 15, "temper": 10, "fortune": 40})


## The integrity invariant; `what` names the moment. Returns true when clean.
func _clean(what: String, state := {}) -> bool:
	var r := ItemRegistry.scan(state)
	var ok := check((r["dup"] as Array).is_empty(), "%s: no uid in two physical holders %s" % [what, str(r["dup"]).left(300)])
	ok = check((r["shared"] as Array).is_empty(), "%s: no item dict shared between containers %s" % [what, str(r["shared"]).left(300)]) and ok
	ok = check((r["stray"] as Array).is_empty(), "%s: no live copy outside a holder %s" % [what, str(r["stray"]).left(300)]) and ok
	var u := Uniques.audit(state)
	ok = check(u.is_empty(), "%s: every Unique piece is the campaign's registered one (D13) %s" % [what, str(u).left(300)]) and ok
	return ok


func _count(uid: int) -> int:
	return ItemRegistry.locations().filter(func(x): return int(x["item"].get("uid", -1)) == uid).size()


func _kinds(it: Dictionary) -> Array:
	return Provenance.story(it).map(func(x): return str(x["kind"]))


func _adv(skip := []) -> Dictionary:
	for a in Adv.all().values():
		if str(a.get("status", "")) != "dead" and not skip.has(str(a["id"])) and str(a["id"]) != "mira":
			return a
	return {}


# ------------------------------------------------------------------ the probe itself
func test_scanner_detects_faults() -> void:
	fresh_game()
	_clean("a new game")
	var a := _adv()
	var w: Dictionary = a["equipment"].get("weapon", {})
	if not check(not w.is_empty(), "an adventurer with a weapon"):
		return
	# the same dict in two places (the review's day-120 finding): an offer holding the adventurer's own blade
	Shop.offers().append({"id": "off_probe", "from": a["id"], "item": w, "price": 1, "day": Game.day()})
	var r := ItemRegistry.scan()
	check(not (r["dup"] as Array).is_empty(), "a uid held twice is found")
	check(not (r["shared"] as Array).is_empty(), "the shared dict is found")
	Shop.offers().clear()
	# a separate copy of a live piece inside a record (what save/load used to make of the shared dicts)
	Expeditions.done().append({"id": "exp_probe", "loot": [w.duplicate(true)], "party": [], "journal": [], "encounters": []})
	r = ItemRegistry.scan()
	check(not (r["stray"] as Array).is_empty(), "a live copy in a record is found: %s" % str(r["stray"]).left(200))
	Expeditions.done().pop_back()
	# a reference is fine
	Expeditions.done().append({"id": "exp_probe2", "loot": [ItemRegistry.ref(w)], "party": [], "journal": [], "encounters": []})
	r = ItemRegistry.scan()
	check((r["stray"] as Array).is_empty() and int(r["records"]) >= 1, "a reference is a record, not a copy (%s)" % ItemRegistry.scan_text(r))
	eq(Items.display_name(ItemRegistry.ref(w)), Items.display_name(w), "a reference reads like the piece")
	check(is_same(ItemRegistry.resolve(ItemRegistry.ref(w)), w), "and resolves to the live piece")


# ------------------------------------------------------------------ purchases move the piece itself
func _caravan_piece() -> int:
	for i in 30:
		Commerce.dev_force_caravan()
		var stock: Array = Commerce.caravan()["stock"]
		for k in stock.size():
			if stock[k].has("item") and Items.is_equipment(stock[k]["item"]):
				return k
	return -1


func test_purchases_keep_identity() -> void:
	fresh_game()
	Game.state["gold"] = 50000
	# the Brask caravan
	var k := _caravan_piece()
	if check(k >= 0, "the caravan brought a piece of equipment"):
		var it: Dictionary = Commerce.caravan()["stock"][k]["item"]
		var uid := int(it["uid"])
		var n0 := Lore.of_item(uid).size()
		eq(Commerce.buy_caravan(k), "", "bought from the caravan")
		var got := Game.find_uid(uid)
		check(is_same(got, it), "the very piece is in the stores, same uid %d" % uid)
		check(Lore.of_item(uid).size() > n0 and _kinds(got).has("bought"), "its story carries on: %s" % str(_kinds(got)))
		eq(Provenance.owner_id(got), "smith", "the smith owns it")
	# the pawnshop's house stock
	Commerce.st()["pawn"]["house"]["week"] = -1
	var hs := Commerce.house_stock()
	var hi := -1
	for i in hs.size():
		if Items.is_equipment(hs[i]["item"]):
			hi = i
	if hs.is_empty():
		note("Quell's shelf is empty this week")
	else:
		hi = maxi(hi, 0)
		var hit: Dictionary = hs[hi]["item"]
		var huid := int(hit["uid"])
		eq(Commerce.buy_house(hi), "", "bought off Quell's shelf")
		check(is_same(Game.find_uid(huid), hit), "the same piece, same uid %d" % huid)
	# the Salt Anvil: the smith buys, and an adventurer buys
	Commerce.st()["rival"]["day"] = -999
	var rs := Commerce.rival_stock()
	var ri := -1
	for i in rs.size():
		if rs[i].has("item"):
			ri = i
			break
	if check(ri >= 0, "Maren has a piece on her bench"):
		var rit: Dictionary = rs[ri]["item"]
		var ruid := int(rit["uid"])
		eq(Commerce.buy_rival(ri), "", "bought at the Salt Anvil")
		var mine := Game.find_uid(ruid)
		check(is_same(mine, rit), "the same piece, same uid")
		eq(str(Provenance.maker(mine).get("mark", "")), "salt_anvil", "Maren's mark stays")
		check(_kinds(mine).has("forged") and _kinds(mine).has("bought"), "forged at the Salt Anvil and bought — one story: %s" % str(_kinds(mine)))
	Commerce.st()["rival"]["day"] = -999
	var a := _adv()
	a["gold"] = 5000
	a["equipment"].clear()
	a["needs"] = "weapon"
	var bought := Commerce.rival_buy_for(a)
	if bought.is_empty():
		note("nothing on Maren's bench suited %s" % a["name"])
	else:
		var bit: Dictionary = bought["item"]
		check(is_same(a["equipment"][str(bought["slot"])], bit), "the adventurer wears Maren's very piece")
		eq(Provenance.owner_id(bit), str(a["id"]), "and owns it in its chain")
		check(_kinds(bit).has("forged"), "its Salt Anvil forging stays in its story")
	# a merchant ship
	var si := -1
	for i in 30:
		Trade.dev_force_ship("barge")
		var st: Array = Trade.current_ship().get("stock", [])
		for j in st.size():
			if st[j].has("item"):
				si = j
		if si >= 0:
			break
	if check(si >= 0, "a ship brought arms"):
		var sit: Dictionary = Trade.current_ship()["stock"][si]["item"]
		var suid := int(sit["uid"])
		eq(Trade.buy_from_ship(si), "", "bought at the harbour")
		check(is_same(Game.find_uid(suid), sit), "the same piece, same uid")
	_clean("after every purchase")
	check(save_load("suite_identity_buy"), "save and load")
	_clean("after save/load")


# ------------------------------------------------------------------ records refer, never fork
func test_repair_record_does_not_fork() -> void:
	fresh_game()
	var a := _adv()
	var w: Dictionary = a["equipment"].get("weapon", {})
	if not check(not w.is_empty(), "an adventurer with a weapon"):
		return
	var uid := int(w["uid"])
	w["stats"]["durability"] = 5
	Shop.customers().clear()
	Shop._add_customer(str(a["id"]), "repair_own")
	var c := Shop.customer(str(a["id"]))
	check(ItemRegistry.is_ref(c.get("item", {})), "the request holds a reference to the piece, not the piece")
	eq(int(c["item"]["uid"]), uid, "by uid")
	var head := str(Shop.request(c)["headline"])
	eq(head, "Repair: %s" % w["name"], "the request reads as before")
	_clean("a repair request in memory")
	check(save_load("suite_identity_repair"), "save and load")
	_clean("a repair request after save/load")
	a = Adv.get_a(str(a["id"]))
	c = Shop.customer(str(a["id"]))
	var live: Dictionary = a["equipment"]["weapon"]
	live["stats"]["durability"] = 7   # the world moves on: the record follows the piece, not a stale copy
	eq(str(Shop.request(c).get("condition", "")), "durability 7 / %d" % int(live["stats"]["durability_max"]), "the request reads the live piece")
	Shop.do_repair(str(a["id"]), 90.0)
	check(int(live["stats"]["durability"]) > 7, "the repair mends the piece the adventurer wears")
	eq(_count(uid), 1, "one instance of the blade")
	_clean("after the repair")


func test_expedition_loot_record() -> void:
	fresh_game()
	var a := _adv()
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["level"] = 8
	a["hp_max"] = Expeditions.hp_max(a)
	a["hp"] = a["hp_max"]
	a.erase("exp")
	Expeditions.st()["parties"] = {}
	var e := Expeditions.start({"id": "p_ident", "members": [a["id"]], "leader": a["id"], "dest": "whisperwood", "goal": "explore"})
	if not check(not e.is_empty(), "the party set out"):
		return
	var eid := str(e["id"])
	var piece := Items.make("ring_silver", {"quality": 90.0})
	var uid := int(piece["uid"])
	(e["loot"] as Array).append(piece)   # carried in the pack
	_clean("a piece in a pack on the road")
	var guard := 0
	while Expeditions.active().has(eid) and guard < 600:
		Expeditions.step(e)
		guard += 1
	var rec := Expeditions.get_exp(eid)
	check(not rec.is_empty() and (rec["loot"] as Array).all(func(x): return ItemRegistry.is_ref(x)), "the finished report holds references only")
	var w := ItemRegistry.where(uid)
	if str(a.get("status", "")) == "dead" or w.is_empty():
		note("the ring did not come home (%s)" % str(a.get("status", "")))
		check(Lore.of_item(uid).size() >= 1, "its history remains")
	else:
		check(str(w["holder"]) in ["adventurer", "offer", "pack"], "the ring is worn or offered (%s)" % str(w["holder"]))
		var r0: Dictionary = (rec["loot"] as Array).filter(func(x): return int(x["uid"]) == uid)[0]
		check(is_same(ItemRegistry.resolve(r0), w["item"]), "the report's line resolves to the live ring")
		eq(Items.display_name(r0), Items.display_name(w["item"]), "and reads the same")
	_clean("after the expedition")
	check(save_load("suite_identity_exp"), "save and load")
	_clean("after save/load")
	eq(_count(uid), 0 if w.is_empty() else 1, "one instance of the ring (or none, lost)")


func test_wiped_pack_is_lost_not_kept() -> void:
	fresh_game()
	var a := _adv()
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a.erase("exp")
	Expeditions.st()["parties"] = {}
	var e := Expeditions.start({"id": "p_wipe", "members": [a["id"]], "leader": a["id"], "dest": "whisperwood", "goal": "explore"})
	if not check(not e.is_empty(), "the party set out"):
		return
	var piece := Items.make("sword_iron", {"quality": 80.0})
	var uid := int(piece["uid"])
	(e["loot"] as Array).append(piece)
	a["hp"] = 0
	Expeditions._wipe(e)
	var rec := Expeditions.get_exp(str(e["id"]))
	check(ItemRegistry.is_ref(rec["loot"][0]), "the lost party's report keeps a reference")
	eq(_count(uid), 0, "the piece no longer exists physically")
	check(_kinds(piece).has("lost"), "its loss is recorded: %s" % str(_kinds(piece)))
	check(Lore.of_item(uid).any(func(x): return str(x["kind"]) == "lost"), "and its history keeps it")
	_clean("after the wipe")


# ------------------------------------------------------------------ pledges, strangers, hand-overs
func test_pawn_round_trip() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	var it := _sword()
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var uid := int(it["uid"])
	ItemStory.remember_pool()   # the forge remembers its piece
	eq(Commerce.pawn_item(uid), "", "pawned")
	eq(str(ItemRegistry.where(uid).get("holder", "")), "pledge", "the registry knows it is pledged")
	check(not ItemStory.circulating().any(func(x): return int(x["uid"]) == uid), "a pledged piece is not 'circulating' (no stranger can bring a copy)")
	_clean("pledged")
	var pid := str(Commerce.pledges()[0]["id"])
	eq(Commerce.redeem(pid), "", "redeemed")
	check(is_same(Game.find_uid(uid), it), "the very sword is back, same uid")
	var hows: Array = Provenance.owners(it).map(func(o): return str(o["how"]))
	check(hows.has("pawned") and hows.has("redeemed"), "its chain: %s" % str(hows))
	_clean("redeemed")
	# pledge again and let it lapse and be sold on: the hand-over is recorded and the piece may circulate
	eq(Commerce.pawn_item(uid), "", "pawned again")
	var p: Dictionary = Commerce.pledges()[0]
	p["due"] = Game.day() - 1
	Commerce._pawn_day()
	p["forfeit_day"] = Game.day() - 999
	Commerce._pawn_day()
	check(Commerce.pledges().is_empty(), "sold to a passing buyer")
	eq(Provenance.owner_id(it), "pawn_buyer", "the sale is in its chain")
	eq(str(Provenance.owners(it)[-1]["name"]), "a passing buyer", "named as people say it")
	check(ItemStory.circulating().any(func(x): return int(x["uid"]) == uid), "now it circulates (the forge's memory of it)")
	eq(_count(uid), 0, "no live instance remains")
	_clean("sold on")


func test_stranger_visit_moves_the_piece() -> void:
	fresh_game()
	var it := _sword()
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var uid := int(it["uid"])
	var a := _adv()
	a["equipment"].erase("weapon")
	Adv.give_item(a, Game.take_uid(uid), 0)
	ItemStory.remember_pool()
	check(not ItemStory.circulating().any(func(x): return int(x["uid"]) == uid), "worn by an adventurer: not circulating")
	# the adventurer leaves the world with it (the record of the piece stays in the forge's memory)
	a["equipment"].erase("weapon")
	Shop.customers().clear()
	var c := ItemStory.stranger_visit()
	if not check(not c.is_empty(), "a stranger brings an old blade"):
		return
	var held: Dictionary = c["item"]
	eq(int(held["uid"]), uid, "the forge's own piece, same uid")
	check(not ItemStory.st()["pool"].has(str(uid)), "it left the pool (moved, not copied)")
	eq(_count(uid), 1, "one instance")
	_clean("a stranger at the counter")
	Shop.do_repair(str(c["npc"]), 90.0)
	eq(_count(uid), 0, "after the repair it goes home with them")
	check(ItemStory.st()["pool"].has(str(uid)), "and back into the forge's memory")
	_clean("after the stranger's repair")


func test_exits_record_hand_overs() -> void:
	fresh_game()
	var a := _adv()
	# an expired offer is sold on at the market
	var it := Items.make("helm_iron", {"quality": 80.0})
	Shop.add_offer(str(a["id"]), it, false)
	Shop.offers()[-1]["day"] = Game.day() - 5
	Shop.expire_offers()
	eq(Provenance.owner_id(it), "market_buyer", "an expired offer is sold on — recorded")
	eq(str(Provenance.owners(it)[-1]["name"]), "a buyer at the market", "named as people say it")
	# a declined offer too
	var it2 := Items.make("shield_round", {"quality": 80.0})
	Shop.add_offer(str(a["id"]), it2, false)
	Shop.decline_offer(str(Shop.offers()[-1]["id"]))
	eq(Provenance.owner_id(it2), "market_buyer", "a declined offer is sold on — recorded")
	# a piece sold to a villager at the counter
	var it3 := _sword()
	if check(not it3.is_empty(), "a sword to sell"):
		Shop.customers().clear()
		Shop.customers().append({"npc": "wenna", "want": "goods", "arrived": 0, "seat": 0, "present": true, "budget": 99999, "looking_for": "sword_iron"})
		eq(Shop.sell_goods("wenna", int(it3["uid"])), "", "sold to Wenna")
		eq(Provenance.owner_id(it3), "wenna", "the villager's purchase is in its chain")
	_clean("after the hand-overs")


# ------------------------------------------------------------------ sponsorship deliveries
func test_sponsorship_delivery_keeps_identity() -> void:
	fresh_game()
	Expeditions.st()["parties"] = {}
	for id in Expeditions.active().keys():
		Expeditions.active().erase(id)
	var dead := _adv()
	var blade := Items.make("sword_iron", {"quality": 96.0})
	Provenance.forged(blade)
	Provenance.transfer(blade, str(dead["id"]), "sold", "brindlewick")
	dead["equipment"]["weapon"] = blade
	var uid := int(blade["uid"])
	dead["status"] = "dead"
	WorldSites.leave_gear(dead, "barrow_fields", "rows", "fell with %s" % dead["name"])
	eq(str(ItemRegistry.where(uid).get("holder", "")), "site", "the registry knows where it lies")
	_clean("lost at a site")
	var a := {}
	for x in Adv.all().values():   # a lone, active adventurer in town (as t_sponsor picks them)
		if str(x["id"]) != str(dead["id"]) and str(x["id"]) != "mira" and Companies.of(str(x["id"])).is_empty() and Living.is_active(x) and str(x.get("status", "")) != "dead":
			a = x
			break
	if not check(not a.is_empty(), "a lone adventurer"):
		return
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["activity"] = "at_inn"
	a["level"] = 16
	a["hp_max"] = Expeditions.hp_max(a)
	a["hp"] = a["hp_max"]
	a["fatigue"] = 0.0
	a.erase("exp")
	var obj := {}
	for o in Sponsor.objectives("barrow_fields"):
		if str(o["kind"]) == "lost" and int(o["uid"]) == uid:
			obj = o
	if not check(int(obj.get("uid", -1)) == uid, "the lost blade is an objective"):
		return
	Game.state["gold"] = 5000
	var ans := Sponsor.propose(obj, "adv:" + str(a["id"]), {"fee": 400, "bonus": 300, "share": 0})
	if str(ans.get("verdict", "")) != "accept":
		note("the sponsorship was not accepted (%s)" % str(ans.get("reason", "")))
		return
	var sid := str(ans["sid"])
	var h := 0
	while h < 240 and str(Sponsor.get_s(sid).get("status", "")) in ["contracted", "under_way"]:
		Game.advance_minutes(60)
		h += 1
		if h % 24 == 0:
			_clean("sponsored expedition, hour %d" % h)
	var sp := Sponsor.get_s(sid)
	note("sponsorship outcome: %s" % str(sp.get("outcome", "")))
	if str(sp.get("outcome", "")) == "success":
		var w := ItemRegistry.where(uid)
		eq(str(w.get("holder", "")), "returns", "delivered once, on the returns shelf")
		check(is_same(w.get("item", {}), blade), "the very blade")
	check(_count(uid) <= 1, "one instance at most (%d)" % _count(uid))
	_clean("after the sponsorship")
	check(save_load("suite_identity_sponsor"), "save and load")
	_clean("after save/load")


# ------------------------------------------------------------------ the masterpiece archive
func _bench() -> bool:
	if Contracts.bench_installed():
		return true
	if not check(Property.buy_station(Contracts.BENCH) == "", "the Project Bench can be bought"):
		return false
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, Contracts.BENCH)
	if why != "":
		Property.dev_grant_unit("cobbler")
		plan = Property.plan_copy()
		why = Property.auto_place(plan, Contracts.BENCH)
	return check(why == "" and Property.commit(plan) == "" and Contracts.bench_installed(), "the bench is installed (%s)" % why)


func test_masterpiece_survives_forty_contracts() -> void:
	fresh_game()
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = 50000
	SkillTree.unlock_all()
	train("smithing", 8)
	if not _bench():
		return
	var o := Contracts.make_offer("watch_arms")
	if not check(not o.has("error") and Contracts.accept(str(o["id"])) == "", "the Watch's order is taken"):
		return
	var cid := str(o["id"])
	var c := Contracts.get_c(cid)
	var fine := _sword(125.0)
	if not check(not fine.is_empty(), "a fine longsword is forged"):
		return
	var uid := int(fine["uid"])
	eq(Contracts.lay_in_masterpiece(cid, uid), "", "laid into the order")
	eq(str(ItemRegistry.where(uid).get("holder", "")), "contract", "the registry knows it waits at the bench")
	for d in Contracts.materials_needed(c):
		give(str(d), int(Contracts.materials_needed(c)[d]))
	for d in c["rare"]:
		give(str(d), int(c["rare"][d]))
	var g := 0
	while not Contracts.ready(cid) and g < 200:
		Vitality.set_fatigue(0.0)
		if str(Contracts.work(cid, 4).get("error", "")) != "":
			break
		g += 1
	var r := Contracts.deliver(cid)
	if not check(bool(r.get("masterpiece", false)), "delivered with the masterpiece"):
		return
	var rec: Dictionary = Contracts.get_c(cid)["masterpiece"]["item"]
	check(ItemRegistry.is_ref(rec), "the contract record keeps a reference")
	var w := ItemRegistry.where(uid)
	eq(str(w.get("holder", "")), "holdings", "the masterpiece is kept in the holdings archive")
	check(is_same(w.get("item", {}), fine), "the very sword")
	eq(Provenance.owner_id(fine), "patron_highmarsh_watch", "owned by the Watch")
	var n_events := Lore.of_item(uid).size()
	# forty later orders close; the history keeps 30
	for i in 40:
		var oo := Contracts.make_offer("watch_arms")
		if oo.has("error"):
			break
		var cc := Contracts.get_c(str(oo["id"]))
		Contracts.offers().erase(cc)
		Contracts._close(cc, "poor", 0, 0.0, 0, "A test order closed.")
	check(Contracts.get_c(cid).is_empty(), "the original order has left the capped history (%d kept)" % Contracts.history().size())
	var w2 := ItemRegistry.where(uid)
	check(is_same(w2.get("item", {}), fine), "the masterpiece is still in the world, whole")
	eq(int(Provenance.maker(fine).get("day", -1)), int(Provenance.maker(fine).get("day", -2)), "its maker record intact")
	check(Lore.of_item(uid).size() >= n_events, "and its story")
	check(save_load("suite_identity_mp"), "save and load")
	var w3 := ItemRegistry.where(uid)
	eq(str(w3.get("holder", "")), "holdings", "after loading it is still in the archive")
	eq(str(Provenance.maker(w3.get("item", {})).get("id", "")), "smith", "maker kept")
	check(Lore.of_item(uid).any(func(x): return str(x["kind"]) == "commission"), "its delivery is in its story")
	_clean("after forty contracts and a reload")


# ------------------------------------------------------------------ the old-save conversion
## A synthetic save from before A1: live copies in records, a masterpiece only in the history, one piece twice.
func _old_state() -> Dictionary:
	fresh_game()
	var a := _adv()
	var w: Dictionary = a["equipment"]["weapon"]
	var ring := Items.make("ring_silver", {"quality": 88.0})
	var helm := Items.make("helm_iron", {"quality": 77.0})
	var mp := Items.make("sword_iron", {"quality": 120.0, "crafted_by": "Brannoc Ironhand"})
	Shop.offers().append({"id": "off_old", "from": a["id"], "item": ring, "price": 10, "day": Game.day()})
	Expeditions.done().append({"id": "exp_old", "loot": [ring, helm], "party": [a["id"]], "journal": [], "encounters": []})
	Shop.customers().append({"npc": a["id"], "want": "repair", "own_slot": "weapon", "item": w, "arrived": 0, "seat": 0, "present": false, "pay": 10})
	Contracts.history().append({"id": "con_old", "patron": "highmarsh_watch", "outcome": "good", "closed_day": 3, "masterpiece": {"uid": int(mp["uid"]), "item": mp, "defs": ["sword_iron"]}})
	var dup := Items.make("dagger", {"quality": 70.0})
	Game.inventory().append(dup)
	Commerce.pledges().append({"id": "pl_old", "item": dup.duplicate(true), "payout": 1, "buyback": 2, "day": 1, "due": 9, "status": "held"})
	# what a save and a load did to all of that: shared dicts became separate copies
	var data: Dictionary = JSON.parse_string(JSON.stringify(Game.state))
	return Saves._restore_ints(data)


func test_migration_converts_old_state() -> void:
	var data := _old_state()
	var before := ItemRegistry.scan(data)
	check(not (before["stray"] as Array).is_empty() and not (before["dup"] as Array).is_empty(), "the old state has copies and a doubled piece (%s)" % ItemRegistry.scan_text(before))
	var names := {}
	for e in data["exp"]["done"]:
		for x in e.get("loot", []):
			names[int(x["uid"])] = Items.display_name(x)
	var n := ItemRegistry.migrate_records(data)
	check(n >= 5, "converted %d records" % n)
	_clean("after the conversion", data)
	eq(ItemRegistry.migrate_records(data), 0, "a second pass changes nothing (idempotent)")
	var text0 := JSON.stringify(data)
	ItemRegistry.migrate_records(data)
	eq(JSON.stringify(data), text0, "byte-identical after a second pass")
	# readable text is unchanged
	for e in data["exp"]["done"]:
		for x in e.get("loot", []):
			if names.has(int(x["uid"])):
				eq(Items.display_name(x), str(names[int(x["uid"])]), "a report line reads as before")
	var hold: Array = data["item_registry"]["holdings"]
	check(hold.size() == 1 and str(hold[0]["item"]["def"]) == "sword_iron", "the masterpiece moved to the holdings archive")
	var mp_rec: Dictionary = data["contracts"]["history"].filter(func(c): return str(c.get("id", "")) == "con_old")[0]["masterpiece"]["item"]
	check(ItemRegistry.is_ref(mp_rec), "the history keeps a reference")
	# the doubled dagger: the stores keep it, the pledge keeps a reference
	var pl: Dictionary = data["commerce"]["pawn"]["pledges"].filter(func(p): return str(p.get("id", "")) == "pl_old")[0]
	check(ItemRegistry.is_ref(pl["item"]), "the doubled pledge copy became a reference")
	# the converted state plays on
	Game.from_save(data)
	_clean("the converted game loaded")
	check(not ItemRegistry.find(int(hold[0]["item"]["uid"])).is_empty(), "the masterpiece is found in the loaded game")


func test_migration_leaves_new_state_alone() -> void:
	fresh_game()
	_sword()
	days(2)
	var data: Dictionary = Saves._restore_ints(JSON.parse_string(JSON.stringify(Game.state)))
	var text0 := JSON.stringify(data)
	eq(ItemRegistry.migrate_records(data), 0, "a state made by this build needs no conversion")
	eq(JSON.stringify(data), text0, "and is left byte-identical")


# ------------------------------------------------------------------ one map behind every lookup
func test_lookups_route_through_registry() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	var it := _sword()
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var uid := int(it["uid"])
	check(is_same(Game.find_uid_anywhere(uid), it) and is_same(History.find_item(uid), it) and is_same(ItemStory.find(uid), it), "stores: every lookup finds it")
	eq(Commerce.pawn_item(uid), "", "pawned")
	check(is_same(ItemRegistry.find(uid), it), "the registry finds it in the pledge book")
	check(Lore._all_items().any(func(x): return is_same(x, it)), "Lore keeps its events while it is pledged")
	check(Game.find_uid_anywhere(uid).is_empty(), "find_uid_anywhere keeps its scope (stores and worn gear) — gameplay reads it")
	# the smith's own gear
	var pid := str(Commerce.pledges()[0]["id"])
	Commerce.redeem(pid)
	Game.equip_player(uid)
	check(is_same(History.find_item(uid), it) and is_same(ItemStory.find(uid), it), "worn by the smith: History and ItemStory find it")
	eq(str(ItemRegistry.where(uid)["holder"]), "smith", "the registry says where")
	# a villager's piece at the counter
	var v := Items.make("axe_hand", {"quality": 60.0})
	Shop.customers().append({"npc": "tobin", "want": "repair", "item": v, "arrived": 0, "seat": 0, "present": true, "pay": 9})
	check(is_same(ItemStory.find(int(v["uid"])), v), "ItemStory finds a customer's piece")
	eq(str(ItemRegistry.where(int(v["uid"]))["holder"]), "customer", "the registry says where")
	_clean("lookups")


# ------------------------------------------------------------------ history survives loss and destruction
func test_history_survives_loss_and_destruction() -> void:
	fresh_game()
	var it := _sword()
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var uid := int(it["uid"])
	var a := _adv()
	a["equipment"].erase("weapon")
	Adv.give_item(a, Game.take_uid(uid), 0)
	a["equipment"].erase("weapon")
	Provenance.destroy(it, "shattered on a troll's skull")
	eq(_count(uid), 0, "physically gone")
	var kinds: Array = Lore.of_item(uid).map(func(x): return str(x["kind"]))
	check(kinds.has("forged") and kinds.has("destroyed"), "its history remains: %s" % str(kinds))
	check(save_load("suite_identity_gone"), "save and load")
	kinds = Lore.of_item(uid).map(func(x): return str(x["kind"]))
	check(kinds.has("forged") and kinds.has("destroyed"), "and after loading: %s" % str(kinds))


# ------------------------------------------------------------------ the 365-day integrity probe (not SMOKE)
## The review's probe as a permanent test: a seeded journeyman game, light management (weekly mining trips, repairs
## at 80 %, returned bags opened), checked at day 120 and day 365, before and after a real save/load.
func test_year_integrity_probe() -> void:
	fresh_game("journeyman", 4242)
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for day in 365:
		var td := Time.get_ticks_msec()
		if day % 7 == 2:
			for h in Hire.list():
				if h["status"] == "working":
					Hire.send(h["id"], "ironroot_mine")
		Game.advance_minutes(1440)
		for c in Shop.waiting().duplicate():
			if c["want"] == "repair":
				Shop.do_repair(c["npc"], 80.0)
		for b in Game.state["returns"].duplicate():
			for it in b.get("contents", []):
				Game.add_item(it, false)
		Game.state["returns"].clear()
		worst = maxi(worst, Time.get_ticks_msec() - td)
		if day + 1 == 120 or day + 1 == 365:
			var r := ItemRegistry.scan()
			note("day %d before save: %s" % [Game.day(), ItemRegistry.scan_text(r)])
			_clean("day %d in memory" % Game.day())
			var ts := Time.get_ticks_msec()
			check(Saves.save("suite_identity_year"), "saved on day %d" % Game.day())
			var save_ms := Time.get_ticks_msec() - ts
			var size := FileAccess.get_file_as_bytes(Saves.path("suite_identity_year")).size()
			var tl := Time.get_ticks_msec()
			check(Saves.load_slot("suite_identity_year"), "loaded on day %d" % Game.day())
			var load_ms := Time.get_ticks_msec() - tl
			r = ItemRegistry.scan()
			note("day %d after load: %s · save %d ms, load %d ms, %d KB" % [Game.day(), ItemRegistry.scan_text(r), save_ms, load_ms, size / 1024])
			_clean("day %d after save/load" % Game.day())
			Saves.delete("suite_identity_year")
	note("365 days in %.1f s (worst day %d ms)" % [(Time.get_ticks_msec() - t0) / 1000.0, worst])
