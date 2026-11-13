## Canonical v1.6 §8.1 — three dangerous regions beyond the safe roads: the Starfall Observatory (danger 5), the Weeping
## Fortress (7) and the Blackglass Rift (8). Data validation (ids, connected graphs, enemy and loot references, map
## positions and pictures), discovery and the destination list, persistent site state through save/load, and parties
## of three strengths simulated at each new region (and two existing ones for comparison) through the expedition engine.
extends SuiteCase

const SMOKE := ["test_data_references_and_graphs", "test_discovery_flags_and_persistence"]
const NEW := {"starfall_observatory": 5, "weeping_fortress": 7, "blackglass_rift": 8}
const PARTY := ["sigrun", "garrick", "tomas", "elowen"]   # Fighter, Paladin, Cleric, Wizard


func test_data_references_and_graphs() -> void:
	var enemy_ids := {}
	for e in DB.enemies.values():
		enemy_ids[str(e["id"])] = true
	for rid in NEW:
		var d: Dictionary = DB.destinations.get(rid, {})
		check(not d.is_empty(), "%s: a destination" % rid)
		eq(int(d.get("danger", 0)), int(NEW[rid]), "%s: danger %d" % [rid, NEW[rid]])
		eq(str(d.get("requires_flag", "")), "site_" + rid, "%s: unlocked by its discovery flag" % rid)
		check(DB.loot.has(str(d.get("loot", ""))), "%s: its hireling loot table exists" % rid)
		var reg := Expeditions.region(rid)
		var nodes: Array = reg.get("nodes", [])
		check(nodes.size() >= 8, "%s: %d places on its map" % [rid, nodes.size()])
		var ids := {}
		for n in nodes:
			ids[str(n["id"])] = n
		var kinds := {}
		for n in nodes:
			kinds[str(n["kind"])] = true
			for l in n["links"]:
				check(ids.has(str(l)), "%s: %s links to an existing place (%s)" % [rid, n["id"], l])
			for en in n["enemies"]:
				check(enemy_ids.has(str(en[0])), "%s: enemy %s exists" % [rid, en[0]])
			if str(n.get("loot", "")) != "":
				check(DB.loot.has(str(n["loot"])), "%s: loot table %s exists" % [rid, n["loot"]])
		for k in ["entry", "encounter", "trap", "boss"]:
			check(kinds.has(k), "%s: has a%s %s" % [rid, "n" if k in ["entry", "encounter"] else "", k])
		check(kinds.has("resource") or kinds.has("chest"), "%s: resources or a cache" % rid)
		# connected: every place reachable from the entry, and the boss among them
		var seen := {}
		var stack := [str(nodes[0]["id"])]
		while not stack.is_empty():
			var x: String = stack.pop_back()
			if seen.has(x):
				continue
			seen[x] = true
			for l in ids[x]["links"]:
				stack.append(str(l))
		eq(seen.size(), ids.size(), "%s: every place is reachable from the entry" % rid)
		var inf := WorldSites.info(rid)
		check(seen.has(str(inf.get("boss", ""))), "%s: the boss lair is reachable" % rid)
		for su in inf.get("successor", []):
			check(enemy_ids.has(str(su[0])), "%s: successor %s exists" % [rid, su[0]])
		# the world map: on the parchment, clear of the other sites, with an existing picture
		var p := WorldSites.world_pos(rid)
		check(p.x > 60 and p.x < 1540 and p.y > 60 and p.y < 960, "%s: on the 1600x1000 map (%s)" % [rid, str(p)])
		for other in WorldSites.ids():
			if str(other) != rid:
				check(p.distance_to(WorldSites.world_pos(str(other))) >= 150.0, "%s: clear of %s on the map" % [rid, other])
		check(ResourceLoader.exists("res://assets/sprites/ui/world/template_site_%s.png" % WorldSites.icon_of(rid)), "%s: an existing site picture (%s)" % [rid, WorldSites.icon_of(rid)])
		check(WorldSites.TYPE_WORD.has(WorldSites.type_of(rid)), "%s: its kind has a name (%s)" % [rid, WorldSites.TYPE_WORD.get(WorldSites.type_of(rid), "?")])
		# loot entries name real items
		for t in [str(d["loot"]), str(ids[str(inf["boss"])].get("loot", ""))]:
			for en in DB.loot[t]["entries"]:
				check(str(en[0]).begins_with("equip:") or DB.items.has(str(en[0])), "%s: loot %s is a real item" % [t, en[0]])
	# danger rises with the danger number, and above the existing regions
	var r5 := Expeditions.rating("starfall_observatory")
	var r7 := Expeditions.rating("weeping_fortress")
	var r8 := Expeditions.rating("blackglass_rift")
	note("ratings: barrow %.0f, deep %.0f, crag %.0f | observatory %.0f, fortress %.0f, rift %.0f" % [Expeditions.rating("barrow_fields"),
		Expeditions.rating("deep_ironroot"), Expeditions.rating("drakes_crag"), r5, r7, r8])
	check(r5 > Expeditions.rating("barrow_fields") and r7 > Expeditions.rating("drakes_crag") and r8 > r7 and r7 > r5, "ratings rise with danger")


func test_discovery_flags_and_persistence() -> void:
	for rid in NEW:
		check(not WorldSites.is_discovered(rid), "%s: unknown at the start" % rid)
		check(not Game.has_flag("site_" + rid), "%s: not yet a destination" % rid)
	# beyond the safe roads: explorers of the safe roads never find them; explorers of the dangerous places beyond may
	# (chance forced to 1)
	Expeditions.ensure(Adv.get_a("sigrun"))
	Adv.get_a("sigrun")["status"] = "away"
	for here in ["ironroot_mine", "whisperwood", "highmarsh_road"]:
		var e := {"dest": here, "party": ["sigrun"], "explored": [], "journal": []}
		var id := WorldSites.try_discover(e, 1.0)
		check(not NEW.has(id), "exploring %s (a safe road) never finds a new region (%s)" % [here, id])
	var found := []
	WorldSites.reveal("sunken_temple", "known")   # the Barrow Fields' other neighbour, so the pick is not left to chance
	for here in ["barrow_fields", "drakes_crag", "starfall_observatory"]:
		WorldSites.reveal(here, "known")
		var e := {"dest": here, "party": ["sigrun"], "explored": [], "journal": []}
		var id := WorldSites.try_discover(e, 1.0)
		if id != "":
			found.append(id)
	note("found: %s" % str(found))
	check(NEW.keys().all(func(r): return found.has(r)), "the Barrow Fields lead to the Observatory, Drake's Crag to the Fortress, the Observatory to the Rift")
	WorldSites.reveal("blackglass_rift", "explored", ["sigrun"])
	check(WorldSites.is_discovered("blackglass_rift") and Game.has_flag("site_blackglass_rift"), "revealed: on the map and a destination")
	check(Lore.of_place("blackglass_rift").size() >= 1, "the discovery is one Lore event at the place")
	# persistent state: a slain master stays slain, threat and lost gear keep through save/load
	var s := WorldSites.site("weeping_fortress")
	s["boss"]["alive"] = false
	s["boss"]["slain"].append({"day": Game.day(), "by": "sigrun"})
	s["threat"] = 1.7
	WorldSites.reveal("weeping_fortress", "rumour")
	check(save_load("t_regions_rt"), "save and load")
	var s2 := WorldSites.site("weeping_fortress")
	check(not bool(s2["boss"]["alive"]) and float(s2["threat"]) == 1.7 and WorldSites.is_discovered("weeping_fortress"), "the fortress's state survives save/load")
	check(WorldSites.is_discovered("blackglass_rift"), "the rift stays discovered")
	eq(Expeditions.rating("weeping_fortress") < Expeditions.rating("blackglass_rift"), true, "a cleared fortress is rated below the rift")


# ------------------------------------------------------------------ parties simulated through the expedition engine
func _party(level: int, q: float, rar: String) -> Array:
	for id in PARTY:
		var a := Adv.get_a(id)
		Expeditions.ensure(a)
		a["level"] = level
		a["status"] = "in_town"
		a["injured_days"] = 0
		a["fatigue"] = 0.0
		a["morale"] = 80.0
		var eq := {}
		for slot in Adv.START_GEAR.get(str(a["cls"]), {}):
			var it := Items.make(str(Adv.START_GEAR[a["cls"]][slot][0]), {"quality": q})
			if rar != "common" and Items.is_equipment(it):
				Items.apply_rarity(it, rar)
			eq[slot] = it
		a["equipment"] = eq
		a["hp_max"] = Expeditions.hp_max(a)
		a["hp"] = a["hp_max"]
	return PARTY.duplicate()


func _run(rid: String, level: int, q: float, rar: String, seed_: int, risk := -1.0) -> Dictionary:
	fresh_game("journeyman", seed_)
	seed(seed_)
	WorldSites.reveal(rid, "known")
	var ids := _party(level, q, rar)
	if risk >= 0.0:
		# a reckless band without its healer (nobody drags the fallen clear): they press on where others turn back
		ids = ids.filter(func(i): return not Expeditions.has_skill(Adv.get_a(i), "healing"))
		for i in ids:
			Adv.get_a(i)["risk"] = risk
	var e := Expeditions.start({"dest": rid, "members": ids, "leader": ids[0], "goal": "explore"})
	var guard := 0
	while Expeditions.active().has(str(e["id"])) and guard < 500:
		var dt := maxi(1, int(e["next_at"]) - Game.now())
		var m := int(Game.state["minute"]) + dt
		Game.state["day"] = int(Game.state["day"]) + m / 1440
		Game.state["minute"] = m % 1440
		Expeditions.tick()
		guard += 1
	var dead := ids.filter(func(i): return str(Adv.get_a(i).get("status", "")) in ["dead", "missing"]).size()
	var hpf := 0.0
	for i in ids:
		var a := Adv.get_a(i)
		hpf += clampf(float(a.get("hp", 0)) / maxf(1.0, float(a.get("hp_max", 1))), 0.0, 1.0) / ids.size()
	return {"dead": dead, "boss": not WorldSites.boss_alive(rid), "outcome": str(e.get("outcome", "")), "hp": hpf, "finished": not Expeditions.active().has(str(e["id"]))}


func _batch(rid: String, level: int, q: float, rar: String, n: int, risk := -1.0) -> Dictionary:
	var out := {"runs": n, "any_death": 0, "deaths": 0, "boss": 0, "retreat": 0, "hp": 0.0, "unfinished": 0}
	for i in n:
		var r := _run(rid, level, q, rar, 7000 + i * 13 + level, risk)
		out["any_death"] += 1 if int(r["dead"]) > 0 else 0
		out["deaths"] += int(r["dead"])
		out["boss"] += 1 if bool(r["boss"]) else 0
		out["retreat"] += 1 if str(r["outcome"]) == "retreated" else 0
		out["hp"] += float(r["hp"]) / n
		out["unfinished"] += 0 if bool(r["finished"]) else 1
	return out


func test_parties_meet_scaled_danger() -> void:
	var tiers := {"weak (lv 3)": [3, 55.0, "common"], "suitable (lv 6)": [6, 70.0, "magic"], "experienced (lv 9)": [9, 95.0, "rare"]}
	var res := {}
	for rid in ["barrow_fields", "drakes_crag", "deep_ironroot", "starfall_observatory", "weeping_fortress", "blackglass_rift"]:
		for t in tiers:
			var a: Array = tiers[t]
			var b := _batch(rid, int(a[0]), float(a[1]), str(a[2]), 12)
			res["%s|%s" % [rid, t]] = b
			note("%-20s %-20s death-runs %2d/12  deaths %2d  boss %2d/12  retreats %2d  hp left %.0f%%" % [rid, t, b["any_death"], b["deaths"], b["boss"], b["retreat"], float(b["hp"]) * 100.0])
			eq(int(b["unfinished"]), 0, "%s %s: every expedition comes to an end" % [rid, t])
	for rid in NEW:
		var ex: Dictionary = res["%s|experienced (lv 9)" % rid]
		var su: Dictionary = res["%s|suitable (lv 6)" % rid]
		var wk: Dictionary = res["%s|weak (lv 3)" % rid]
		check(int(ex["any_death"]) < 12, "%s: experienced parties are not doomed (%d of 12 runs with a death)" % [rid, ex["any_death"]])
		check(int(wk["any_death"]) < 12 or int(wk["retreat"]) > 0, "%s: even the weak can turn back (deaths in %d of 12)" % [rid, wk["any_death"]])
		check(int(ex["boss"]) >= int(wk["boss"]), "%s: strength matters for the master (%d vs %d)" % [rid, ex["boss"], wk["boss"]])
		check(float(ex["hp"]) >= float(wk["hp"]) - 0.05, "%s: the experienced come home in better shape" % rid)
	# genuinely more dangerous than the existing places, for the same experienced party
	var risk := func(k: String) -> float:
		var b: Dictionary = res[k]
		return float(b["deaths"]) + float(b["retreat"]) * 0.5 + (1.0 - float(b["hp"])) * 6.0
	var barrow: float = risk.call("barrow_fields|suitable (lv 6)")
	var rift: float = risk.call("blackglass_rift|suitable (lv 6)")
	var fortress: float = risk.call("weeping_fortress|suitable (lv 6)")
	note("risk index (suitable party): barrow %.1f, observatory %.1f, fortress %.1f, rift %.1f" % [barrow, risk.call("starfall_observatory|suitable (lv 6)"), fortress, rift])
	check(rift > barrow and fortress > barrow, "the fortress and the rift are more dangerous than the Barrow Fields for the same party")
	var ex_rift: Dictionary = res["blackglass_rift|experienced (lv 9)"]
	check(int(ex_rift["deaths"]) + int(ex_rift["retreat"]) > 0 or float(ex_rift["hp"]) < 0.8, "the rift is a real risk even for an experienced party")
	# the same experienced adventurers, reckless and without their healer (risk 0.85) — death is possible, never certain;
	# with a healer and ordinary caution (above) they come home
	var reck_deaths := 0
	for rid in ["weeping_fortress", "blackglass_rift"]:
		var b := _batch(rid, 9, 95.0, "rare", 12, 0.85)
		reck_deaths += int(b["any_death"])
		note("%-20s %-20s death-runs %2d/12  deaths %2d  boss %2d/12  retreats %2d  hp left %.0f%%" % [rid, "reckless (lv 9)", b["any_death"], b["deaths"], b["boss"], b["retreat"], float(b["hp"]) * 100.0])
		check(int(b["any_death"]) < 12, "%s: even a reckless experienced band is not doomed" % rid)
	check(reck_deaths > 0, "pressing on recklessly in the fortress or the rift can cost an experienced adventurer's life (%d runs)" % reck_deaths)


## Autonomous adventurers choose by their own strength (Expeditions.choose_destination): with every region known, a weak
## party almost never picks the new dangerous places; an experienced one does go to them.
func test_autonomous_choice_follows_strength() -> void:
	var picks := {}
	for tier in [[3, 55.0, "common"], [6, 70.0, "magic"], [9, 95.0, "rare"]]:
		fresh_game("journeyman", 4100 + int(tier[0]))
		for rid in WorldSites.ids():
			WorldSites.reveal(str(rid), "known")
		var ids := _party(int(tier[0]), float(tier[1]), str(tier[2]))
		var members := ids.map(func(i): return Adv.get_a(i))
		var n := {"new": 0, "rift": 0, "fortress": 0}
		for i in 200:
			var c := Expeditions.choose_destination(members)
			var d := str(c.get("dest", ""))
			if NEW.has(d):
				n["new"] += 1
			if d == "blackglass_rift":
				n["rift"] += 1
			if d == "weeping_fortress":
				n["fortress"] += 1
		picks[int(tier[0])] = n
		note("level %d party: new regions chosen %d/200 (fortress %d, rift %d)" % [tier[0], n["new"], n["fortress"], n["rift"]])
	check(int(picks[3]["rift"]) + int(picks[3]["fortress"]) <= 4, "a weak party (lv 3) all but never walks into the fortress or the rift")
	check(int(picks[9]["new"]) > int(picks[3]["new"]), "an experienced party (lv 9) goes beyond the safe roads more often")
