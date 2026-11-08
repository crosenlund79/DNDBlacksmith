## The world remembers (iteration 011, world): persistent sites that change through the adventurers.
## A slain unique master stays dead over many later expeditions (a weaker successor may move in much later,
## announced), gathering depletes and the land regrows, new places are discovered, gear lost in a wipe is
## found again with its history unbroken (same uid, same maker), parties choose by capability, and every
## happening is one Lore event placed at the site — read back as the site's history. All of it persists.
extends SuiteCase

const SMOKE := ["test_sites_persist", "test_unique_boss_stays_dead", "test_lost_gear_recovered"]


func _heroes(n: int, level := 12) -> Array:
	var out := []
	for a in Adv.all().values():
		if out.size() >= n:
			break
		Expeditions.ensure(a)
		a["status"] = "in_town"
		a["level"] = level
		a["hp_max"] = Expeditions.hp_max(a)
		a["hp"] = a["hp_max"]
		a["fatigue"] = 0.0
		out.append(a)
	return out


func _start(members: Array, rid: String) -> Dictionary:
	var ids: Array = members.map(func(m): return str(m["id"]))
	return Expeditions.start({"id": "p_world", "members": ids, "leader": ids[0], "dest": rid, "goal": "explore"})


func _heal(members: Array) -> void:
	for m in members:
		m["status"] = "away"
		m["hp"] = m["hp_max"]


## Fights the boss node until the master falls (strong party, healed between attempts).
func _slay(members: Array, rid: String) -> Dictionary:
	var e := _start(members, rid)
	var n := Expeditions.node_of(rid, str(WorldSites.info(rid)["boss"]))
	for i in 12:
		if not WorldSites.boss_alive(rid):
			break
		_heal(members)
		Expeditions.fight(e, n)
	return e


func _home(members: Array) -> void:
	for id in Expeditions.active().keys():
		Expeditions.active().erase(id)
	for m in members:
		m["status"] = "in_town"
		m.erase("exp")


func test_sites_persist() -> void:
	check(WorldSites.ids().size() >= 8, "eight sites or more (%d)" % WorldSites.ids().size())
	for id in ["whisperwood", "ironroot_mine", "highmarsh_road", "barrow_fields"]:
		check(WorldSites.is_discovered(id), "%s is known from the start" % id)
	for id in ["ravens_hold", "sunken_temple", "drakes_crag", "deep_ironroot"]:
		check(not WorldSites.is_discovered(id), "%s starts undiscovered" % id)
	var s := WorldSites.site("ironroot_mine")
	s["threat"] = 2.4
	s["resources"]["vein"] = 0.2
	WorldSites.reveal("sunken_temple", "rumour")
	var h := _heroes(1, 3)
	h[0]["equipment"]["weapon"] = Items.make("sword_iron", {"quality": 90.0})
	var uid := int(h[0]["equipment"]["weapon"]["uid"])
	h[0]["status"] = "dead"
	WorldSites.leave_gear(h[0], "barrow_fields", "rows", "test")
	check(save_load("suite_world_rt"), "save and load")
	check(Game.state.has("world_sites"), "world_sites is saved")
	eq(snappedf(float(WorldSites.site("ironroot_mine")["threat"]), 0.01), 2.4, "threat persists")
	eq(snappedf(float(WorldSites.site("ironroot_mine")["resources"]["vein"]), 0.01), 0.2, "depletion persists")
	check(WorldSites.is_discovered("sunken_temple"), "a discovery persists")
	var lost: Array = WorldSites.lost("barrow_fields")
	check(lost.size() >= 1 and lost.any(func(x): return int(x["item"]["uid"]) == uid), "lost equipment at a site persists")
	eq(WorldSites.status_word("ironroot_mine"), "threatened", "a growing threat shows on the site")
	# an old save without the key gains it lazily
	Game.state.erase("world_sites")
	check(WorldSites.is_discovered("whisperwood") and not WorldSites.is_discovered("ravens_hold"), "old saves gain fresh sites")


func test_unique_boss_stays_dead() -> void:
	var party := _heroes(4, 14)
	var e := _slay(party, "whisperwood")
	if not check(not WorldSites.boss_alive("whisperwood"), "a strong party fells the Whisperwood Alpha"):
		return
	eq(WorldSites.status_word("whisperwood"), "cleared", "the site is cleared")
	var slain: Array = WorldSites.site("whisperwood")["boss"]["slain"]
	check(slain.size() == 1 and bool(slain[0]["unique"]), "the unique kill is on record")
	# the deed is one Lore event at the site, with killer and weapon instance
	var ev := Lore.event(str(slain[0]["event"]))
	eq(str(ev.get("kind", "")), "slew", "the deed is a 'slew' event")
	eq(str(ev.get("place", "")), "whisperwood", "placed at the site")
	var wu := int(ev.get("data", {}).get("weapon_uid", -1))
	check(wu > 0 and (ev["items"] as Array).has(wu), "the event names the weapon instance (%d)" % wu)
	check(str(ev.get("data", {}).get("killer", "")) != "" and (ev["actors"] as Array).has(str(ev["data"]["killer"])), "and the killer")
	_home(party)
	# many later expeditions: the Alpha never comes back
	var hollow := Expeditions.node_of("whisperwood", "hollow")
	for i in 10:
		WorldSites.daily()
		WorldSites.daily()
		_heal(party)
		var e2 := _start(party.slice(0, 2), "whisperwood")
		var before := (e2["encounters"] as Array).size()
		Expeditions.resolve_node(e2, hollow)
		check((e2["encounters"] as Array).size() == before, "visit %d: no fight at the empty hollow" % (i + 1))
		_home(party)
	check(WorldSites.enemies_at("whisperwood", hollow).is_empty(), "the hollow stays empty for twenty days")
	eq(WorldSites.status_word("whisperwood"), "cleared", "still cleared")
	# much later a weaker successor moves in, announced — never the unique Alpha
	for i in 80:
		WorldSites.daily()
	var specs := WorldSites.enemies_at("whisperwood", hollow)
	check(not specs.is_empty() and str(specs[0][0]) == "young_alpha", "a successor holds the hollow (%s)" % str(specs))
	check(not specs.any(func(s): return str(s[0]) == "wolf_alpha"), "the unique Alpha never respawns")
	check(float(DB.enemies["young_alpha"]["power"]) < float(DB.enemies["wolf_alpha"]["power"]), "the successor is weaker")
	check(WorldSites.events("whisperwood").any(func(x): return str(x["kind"]) == "threat"), "its arrival is an event at the site")
	# killing the successor clears it again; the Alpha's kill record is untouched
	_heal(party)
	_slay(party, "whisperwood")
	check(not WorldSites.boss_alive("whisperwood"), "the successor falls too")
	var sl2: Array = WorldSites.site("whisperwood")["boss"]["slain"]
	check(sl2.size() >= 2 and bool(sl2[0]["unique"]) and not bool(sl2[-1]["unique"]), "two kills on record, only the first unique")
	check(save_load("suite_world_boss"), "save and load")
	check(not WorldSites.boss_alive("whisperwood"), "the boss stays dead after loading")


func test_depletion_and_regrowth() -> void:
	var party := _heroes(2, 5)
	var e := _start(party, "whisperwood")
	var glade := Expeditions.node_of("whisperwood", "glade")
	var full := WorldSites.resource("whisperwood", "glade")
	eq(full, 1.0, "the glade starts full")
	var n0 := (e["loot"] as Array).size()
	Expeditions.gather(e, glade)
	var first := (e["loot"] as Array).size() - n0
	Expeditions.gather(e, glade)
	Expeditions.gather(e, glade)
	var n1 := (e["loot"] as Array).size()
	Expeditions.gather(e, glade)
	var depleted := (e["loot"] as Array).size() - n1
	check(WorldSites.resource("whisperwood", "glade") < 0.15, "gathering depletes the glade (%.2f)" % WorldSites.resource("whisperwood", "glade"))
	check(depleted < first or depleted == 0, "a picked-bare glade gives less (%d < %d)" % [depleted, first])
	check(WorldSites.conditions("whisperwood").any(func(c): return str(c).contains("picked bare")), "the site shows it was picked bare")
	var low := WorldSites.resource("whisperwood", "glade")
	for i in 6:
		WorldSites.daily()
	check(WorldSites.resource("whisperwood", "glade") > low + 0.2, "it slowly grows back (%.2f → %.2f)" % [low, WorldSites.resource("whisperwood", "glade")])
	# growing threats raise danger
	var r0 := Expeditions.rating("ironroot_mine")
	WorldSites.site("ironroot_mine")["threat"] = 2.5
	check(Expeditions.rating("ironroot_mine") > r0, "a growing threat raises the danger (%.0f → %.0f)" % [r0, Expeditions.rating("ironroot_mine")])
	var camp := Expeditions.node_of("ironroot_mine", "camp")
	check(int(WorldSites.enemies_at("ironroot_mine", camp)[0][1]) > int(camp["enemies"][0][1]), "more goblins at the camp")


func test_discovery_of_new_site() -> void:
	var party := _heroes(2, 5)
	check(not WorldSites.is_discovered("ravens_hold"), "Raven's Hold is unknown")
	var known_before := WorldSites.discovered_ids().size()
	var e := _start(party, "highmarsh_road")
	(e["explored"] as Array).append_array(["mile", "bridge"])
	var found := WorldSites.try_discover(e, 1.0)
	eq(found, "ravens_hold", "exploring the Highmarsh road finds Raven's Hold")
	check(WorldSites.is_discovered("ravens_hold") and Game.has_flag("site_ravens_hold"), "it is on the map (and hirelings may go)")
	eq(WorldSites.discovered_ids().size(), known_before + 1, "one more known place")
	var evs := WorldSites.events("ravens_hold")
	check(evs.any(func(x): return str(x["kind"]) == "discovery" and ((x["actors"] as Array).has(str(party[0]["id"])) or (x["actors"] as Array).has(str(party[1]["id"])))),"the discovery is an event at the site, with the finders")
	check(str(WorldSites.site("ravens_hold")["found_how"]) == "explored", "found by exploring")
	# the delve map reveals the deep
	check(not WorldSites.is_discovered("deep_ironroot"), "the deep is unknown without the delve map")
	Game.set_flag("delve_map")
	check(WorldSites.is_discovered("deep_ironroot"), "the delve map reveals Deep Ironroot")
	# rumours reveal places nobody has been to
	var guard := 0
	while not WorldSites.is_discovered("sunken_temple") and guard < 400:
		WorldSites.daily()
		guard += 1
	check(WorldSites.is_discovered("sunken_temple") and str(WorldSites.site("sunken_temple")["found_how"]) == "rumour", "a rumour reveals the Sunken Temple (after %d days)" % guard)


func test_lost_gear_recovered() -> void:
	var hs := _heroes(3, 4)
	var fallen: Dictionary = hs[0]
	var finder: Dictionary = hs[1]
	var blade := Items.make("sword_iron", {"quality": 96.0})
	Provenance.forged(blade)
	Provenance.transfer(blade, str(fallen["id"]), "sold", "brindlewick")
	fallen["equipment"]["weapon"] = blade
	var uid := int(blade["uid"])
	var maker_before: Dictionary = Provenance.maker(blade).duplicate()
	# a party is lost at the barrows and nobody finds them: the gear stays where they fell
	fallen["status"] = "missing"
	var mi := {"dest": "barrow_fields", "node": "ossuary", "since": Game.day(), "alive": false, "exp": "exp_test", "searched": false}
	Expeditions._reveal_fate(fallen, mi, "")
	eq(str(fallen["status"]), "dead", "the missing adventurer's fate is revealed")
	check(not fallen["equipment"].has("weapon"), "the weapon is no longer on the body")
	var lost: Array = WorldSites.lost("barrow_fields")
	check(lost.any(func(x): return int(x["item"]["uid"]) == uid and str(x["node"]) == "ossuary"), "it lies at the ossuary as lost equipment")
	check(Provenance.st(blade).has("lost"), "its provenance says it was lost")
	check(WorldSites.conditions("barrow_fields").any(func(c): return str(c).contains("fallen adventurers")), "the site mentions the lost gear")
	# a later party passes the ossuary and finds it
	var e := _start([finder, hs[2]], "barrow_fields")
	var got := WorldSites.find_lost(e, "ossuary")
	if not check(got.size() >= 1, "the later party finds the gear"):
		return
	var it: Dictionary = got.filter(func(x): return int(x["uid"]) == uid)[0]
	eq(int(it["uid"]), uid, "the same piece (same uid)")
	eq(str(Provenance.maker(it)["id"]), str(maker_before["id"]), "the maker is unchanged")
	eq(int(Provenance.maker(it)["day"]), int(maker_before["day"]), "the maker's day is unchanged")
	check(not Provenance.st(it).has("lost"), "no longer lost")
	var story := Provenance.story(it)
	var kinds: Array = story.map(func(x): return str(x["kind"]))
	check(kinds.has("forged") and kinds.has("lost") and kinds.has("found"), "its story runs on: forged, lost, found (%s)" % str(kinds))
	check(kinds.find("forged") < kinds.find("lost") and kinds.find("lost") < kinds.find("found"), "in order")
	var owners: Array = Provenance.owners(it).map(func(o): return str(o["id"]))
	check(owners.has(str(fallen["id"])) and owners[-1] == str(finder["id"]), "owners: … the fallen, then the finder (%s)" % str(owners))
	check(WorldSites.lost("barrow_fields").is_empty() or not WorldSites.lost("barrow_fields").any(func(x): return int(x["item"]["uid"]) == uid), "the site no longer holds it")
	var fev := Lore.of_item(uid).filter(func(x): return str(x["kind"]) == "found")
	check(not fev.is_empty() and str(fev[-1]["place"]) == "barrow_fields", "the find is placed at the site")
	# home: it is used or offered to the smith, still the same piece
	Expeditions.finish(e)
	var where := Game.find_uid_anywhere(uid)
	var offered := Shop.offers().any(func(o): return int(o.get("item", {}).get("uid", -1)) == uid)
	check(not where.is_empty() or offered, "carried home: used by an adventurer or offered at the counter")


func test_destination_respects_capability() -> void:
	for id in WorldSites.ids():
		WorldSites.reveal(str(id), "rumour")
	Game.set_flag("delve_map")
	Game.state["world"]["missing"] = {}
	var deadliest := ""
	for id in WorldSites.ids():
		if deadliest == "" or Expeditions.rating(str(id)) > Expeditions.rating(deadliest):
			deadliest = str(id)
	eq(deadliest, "drakes_crag", "Drake's Crag is the deadliest site")
	var weak := _heroes(1, 1)
	var a: Dictionary = weak[0]
	a["equipment"] = {"weapon": Items.make("dagger", {"quality": 60.0})} if not DB.item("dagger").is_empty() else {}
	a["risk"] = 0.85   # even a reckless one
	var picks := {}
	for i in 60:
		var p := Expeditions.choose_destination([a])
		picks[str(p.get("dest", ""))] = int(picks.get(str(p.get("dest", "")), 0)) + 1
	check(not picks.has(deadliest), "a weak party never picks %s (%s)" % [deadliest, str(picks)])
	check(not picks.has("deep_ironroot"), "nor the Dwarf-King's hall")
	var strong := _heroes(4, 16)
	var p0 := 0.0
	for m in strong:
		p0 += Expeditions.power(m)
	var strength := p0 / 4.0 * (0.8 + 0.4 * 3)
	check(WorldSites.capable(deadliest, strength, 0.7), "a strong party could take it on (strength %.0f vs %.0f)" % [strength, Expeditions.rating(deadliest)])
	# interests: a cleric is drawn to tombs, a ranger to the forest
	var cleric := {}
	var ranger := {}
	for x in Adv.all().values():
		if x["cls"] == "Cleric":
			cleric = x
		if x["cls"] == "Ranger":
			ranger = x
	if not cleric.is_empty() and not ranger.is_empty():
		check(float(WorldSites.appeal([cleric], "barrow_fields", 50.0, 0.5)["score"]) > float(WorldSites.appeal([ranger], "barrow_fields", 50.0, 0.5)["score"]), "a cleric likes the barrows more than a ranger")
		check(float(WorldSites.appeal([ranger], "whisperwood", 50.0, 0.5)["score"]) > float(WorldSites.appeal([cleric], "whisperwood", 50.0, 0.5)["score"]), "a ranger likes the forest more than a cleric")


func test_lore_events_carry_the_place() -> void:
	var party := _heroes(3, 14)
	var e := _start(party, "ironroot_mine")
	Expeditions.step(e)   # travel_out -> arrival at the gate
	var arr := Lore.event(str(e.get("arrival_event", "")))
	eq(str(arr.get("place", "")), "ironroot_mine", "the arrival is placed at the site")
	_home(party)
	_slay(party, "ironroot_mine")
	var evs := WorldSites.events("ironroot_mine")
	check(evs.size() >= 1, "the site's history reads its events (%d)" % evs.size())
	for x in evs:
		eq(str(x["place"]), "ironroot_mine", "every event in the site's history is placed there")
	check(evs.any(func(x): return str(x["kind"]) == "slew"), "the Brood Mother's death is in it")
	check(not WorldSites.recent_seals("ironroot_mine").is_empty(), "a recent notable event seals the site on the map")
	# no duplicate account: one slew event for one kill
	eq(evs.filter(func(x): return str(x["kind"]) == "slew").size(), 1, "one event for the kill")
	# the killer's own history reads the same record
	var ev: Dictionary = evs.filter(func(x): return str(x["kind"]) == "slew")[0]
	var killer := str(ev["data"].get("killer", ""))
	check(killer != "" and Lore.of_actor(killer).any(func(x): return str(x["id"]) == str(ev["id"])), "the killer's history holds the same event")
	var wu := int(ev["data"].get("weapon_uid", -1))
	check(wu > 0 and Lore.of_item(wu).any(func(x): return str(x["id"]) == str(ev["id"])), "the weapon's history holds the same event")
