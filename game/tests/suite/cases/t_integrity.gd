## Progression integrity: static checks over the game's data that catch dead ends before a player does —
## unlearnable recipes, broken or circular skill-tree prerequisites, materials with no source, stations with
## no way to acquire them, rooms that can never be bought, broken references and impossible commissions.
extends SuiteCase

const SMOKE := ["test_references", "test_tree_shape", "test_material_sources"]


## Every way a material can enter the game: shops, ships, imports, loot, expeditions, crafting, the start.
func _sources() -> Dictionary:
	var src := {}
	var add := func(def: String, why: String) -> void:
		if not src.has(def):
			src[def] = []
		src[def].append(why)
	for k in DB.suppliers:
		if k == "_doc":
			continue
		for e in DB.suppliers[k]:
			add.call(str(e[0]), "supplier " + k)
	var t: Dictionary = DB.extra("trade")
	for e in t.get("herbalist", {}).get("stock", []):
		add.call(str(e[0]), "herbalist")
	for sid in t.get("ships", {}):
		for e in t["ships"][sid].get("stock", []):
			add.call(str(e[0]), "ship " + sid)
	for d in t.get("imports", {}):
		add.call(str(d), "import")
	for tid in DB.loot:
		if tid == "_doc":
			continue
		for e in DB.loot[tid].get("entries", []):
			add.call(str(e[0]), "loot " + tid)
	for r in DB.recipes.values():
		add.call(str(r["output"]), "recipe " + str(r["id"]))
	fresh_game()
	for it in Game.inventory():
		add.call(str(it["def"]), "starting stores")
	return src


func test_references() -> void:
	for r in DB.recipes.values():
		check(not DB.item(str(r["output"])).is_empty(), "recipe %s outputs a real item (%s)" % [r["id"], r["output"]])
		for d in r["inputs"]:
			check(not DB.item(str(d)).is_empty(), "recipe %s input %s exists" % [r["id"], d])
		for s in r["steps"]:
			check(not DB.station(str(s)).is_empty(), "recipe %s station %s exists" % [r["id"], s])
	for tid in DB.loot:
		if tid == "_doc":
			continue
		for e in DB.loot[tid].get("entries", []):
			var def := str(e[0])
			check(def.begins_with("equip:") or not DB.item(def).is_empty(), "loot table %s entry %s exists" % [tid, def])
	var t: Dictionary = DB.extra("trade")
	for sid in t.get("ships", {}):
		for e in t["ships"][sid].get("stock", []):
			check(not DB.item(str(e[0])).is_empty(), "ship %s sells a real item %s" % [sid, e[0]])
	for n in SkillTree.nodes():
		for rid in n.get("unlocks", {}).get("recipes", []):
			check(not DB.recipe(str(rid)).is_empty(), "node %s unlocks a real recipe %s" % [n["id"], rid])
		for sid2 in n.get("unlocks", {}).get("stations", []):
			check(not DB.station(str(sid2)).is_empty(), "node %s unlocks a real station %s" % [n["id"], sid2])


func test_tree_shape() -> void:
	var by := {}
	for n in SkillTree.nodes():
		check(not by.has(n["id"]), "node id %s is unique" % n["id"])
		by[n["id"]] = n
	for n in SkillTree.nodes():
		for p in n.get("requires", {}).get("nodes", []):
			check(by.has(p), "node %s: prerequisite %s exists" % [n["id"], p])
	# no cycles: depth-first with colours
	var colour := {}
	var cyc := []
	var visit := func(id: String, f: Callable) -> void:
		if colour.get(id, 0) == 2:
			return
		if colour.get(id, 0) == 1:
			cyc.append(id)
			return
		colour[id] = 1
		for p in by.get(id, {}).get("requires", {}).get("nodes", []):
			f.call(str(p), f)
		colour[id] = 2
	for id in by:
		visit.call(str(id), visit)
	check(cyc.is_empty(), "no circular prerequisites %s" % str(cyc))
	# every recipe and station is unlocked by exactly one node; recipes are visible once their flag is known
	for rid in DB.recipes:
		var n2 := 0
		for n in SkillTree.nodes():
			if (n.get("unlocks", {}).get("recipes", []) as Array).has(rid):
				n2 += 1
		eq(n2, 1, "recipe %s is learned from exactly one node" % rid)
	for sid in DB.stations:
		var n3 := 0
		for n in SkillTree.nodes():
			if (n.get("unlocks", {}).get("stations", []) as Array).has(sid):
				n3 += 1
		eq(n3, 1, "station %s is learned from exactly one node" % sid)
		check(Property.station_price(sid) > 0 or (Property.data().get("starter_stations", []) as Array).has(sid), "station %s can be bought" % sid)
	# flags required by nodes have a legitimate source
	var teach := {}
	for r in DB.recipes.values():
		if str(r.get("teaches_flag", "")) != "":
			teach[str(r["teaches_flag"])] = true
	for n in SkillTree.nodes():
		for f in n.get("requires", {}).get("flags", []):
			check(teach.has(f) or f in ["dragon_lore", "recipe_starsteel"], "knowledge '%s' (node %s) can be found in play" % [f, n["id"]])


func test_material_sources() -> void:
	var src := _sources()
	var missing := []
	for r in DB.recipes.values():
		for d in r["inputs"]:
			if not src.has(str(d)):
				missing.append("%s (for %s)" % [d, r["id"]])
	for n in SkillTree.nodes():
		for d in n.get("requires", {}).get("items_seen", []):
			if not src.has(str(d)):
				missing.append("%s (seen for node %s)" % [d, n["id"]])
	check(missing.is_empty(), "every required material has a source: missing %s" % str(missing))


func test_rooms_reachable() -> void:
	# every unit can eventually be bought: buy available ones until none remain
	Game.state["gold"] = 100000
	var guard := 0
	var progress := true
	while progress and guard < 20:
		progress = false
		guard += 1
		for u in Property.units():
			if Property.unit_state(str(u["id"])) == "available":
				progress = Property.buy_unit(str(u["id"])) == "" or progress
	for u in Property.units():
		check(Property.owns(str(u["id"])), "the %s can be bought (directly or after its neighbours)" % u["name"])
	eq(Property.validate(Property.plan_copy()), "", "the whole building, once owned, is reachable")


func test_commissions_possible() -> void:
	# the best each slot/stat can reach: craft every recipe once at top craftsmanship and dice, with every station
	Property.dev_grant_all()
	SkillTree.unlock_all()
	for sk in DB.skill_list:
		legacy_level(str(sk["id"]), 12)   # B1: an all-round master smith (an old save's levels) — content reach, not progression
	var best := {}
	for r in DB.recipes.values():
		var rid: String = r["id"]
		for d in r["inputs"]:
			give(str(d), int(r["inputs"][d]))
		Vitality.set_fatigue(0.0)
		var it := craft(rid, 118.0, {"edge": 20, "temper": 20, "fortune": 95, "guard": 20, "spellweave": 20})
		if it.is_empty() or not Items.is_equipment(it):
			continue
		for stat in ["attack", "protection", "magic", "fire", "frost", "ward"]:
			var key := "%s/%s" % [Items.slot(it), stat]
			best[key] = maxi(int(best.get(key, 0)), Items.stat(it, stat))
	for a in Adv.all().values():
		var o := Shop.create_order(str(a["id"]))
		if o.is_empty():
			continue
		var reach := int(best.get("%s/%s" % [o["slot"], o["stat"]], 0))
		check(reach >= int(o["min"]), "%s's commission (%s) can be met — the best craftable reaches %d" % [a["name"], Shop.order_text(o), reach])
