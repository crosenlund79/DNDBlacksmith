## Canonical v1.7 §7.1 (#74) — orichalcum, mithril and adamantine come chiefly from dangerous expeditions and
## discoveries: routine traders do not regularly stock them; exceptional trade is very rare and expensive; the deep and
## dangerous places still yield them, so advanced Designs stay achievable.
extends SuiteCase

const SMOKE := ["test_routine_sources_carry_none"]
const RARE := ["ore_mithril", "ore_adamantine", "ore_orichalcum", "ingot_mithril", "ingot_orichalcum", "ingot_adamantine"]


func _rare(def: String) -> bool:
	return RARE.has(def)


func test_routine_sources_carry_none() -> void:
	# the village store, the herbalist and the trade-run suppliers (every day, every early visit)
	for sid in DB.suppliers:
		if str(sid).begins_with("_"):
			continue
		for e in DB.suppliers[sid]:
			check(not _rare(str(e[0])), "%s does not sell %s" % [sid, e[0]])
	var tr: Dictionary = Trade.cfg()
	for e in tr.get("general_store", {}).get("stock", []) + tr.get("herbalist", {}).get("stock", []) if tr.get("herbalist", {}) is Dictionary else []:
		check(not _rare(str(e[0])), "the village shops do not sell %s" % e[0])
	# the ships, the caravan and the rival: only now and then, one at a time, dearly
	var offers := []
	for ty in tr.get("ships", {}):
		for e in tr["ships"][ty].get("stock", []):
			offers.append(["ship " + str(ty), e[0], float(e[1]), e[2], float(e[3])])
	for e in Commerce.cfg().get("caravan", {}).get("stock", []):
		offers.append(["caravan", e[0], float(e[1]), e[2], float(e[3])])
	for e in Commerce.rival_cfg().get("materials", []):
		offers.append(["rival", e[0], float(e[1]), e[2], float(e[3])])
	var n := 0
	for o in offers:
		if _rare(str(o[1])):
			n += 1
			check(float(o[4]) <= 0.08 and float(o[2]) >= 2.4 and int(o[3][1]) == 1,
				"%s: %s only now and then (%.0f%%), one at a time, at %.1f× its value" % [o[0], o[1], float(o[4]) * 100.0, float(o[2])])
	check(n >= 3, "exceptional trade still exists (%d rare offers across traders)" % n)
	# the routine Ironroot mine: none in an ordinary run; a skilled miner only very rarely
	var mine: Dictionary = DB.loot["mine"]
	for e in mine["entries"]:
		check(not _rare(str(e[0])), "the Ironroot mine's ordinary haul has no %s" % e[0])
	# imports: an exceptional favour — slow and dear, only for metals the smith has held or seen
	for d in ["ore_mithril", "ore_adamantine", "ore_orichalcum"]:
		var info := Trade.import_info(d)
		check(str(info.get("tier", "")) == "exceptional" and int(info["lead"][0]) >= 12 and int(info["unit"]) >= int(float(DB.item(d)["value"]) * 2.4),
			"%s import: exceptional, %d g each, %d–%d days" % [d, int(info.get("unit", 0)), int(info.get("lead", [0, 0])[0]), int(info.get("lead", [0, 0])[1])])


func test_sixty_early_days_of_trade() -> void:
	fresh_game("journeyman", 7401)
	var seen := {"ship": 0, "caravan": 0, "rival": 0}
	var visits := {"ship": 0, "caravan": 0, "rival": 0}
	var total_qty := 0
	var ships_seen := {}
	for d in 60:
		days(1)
		var sh := Trade.current_ship()
		if not sh.is_empty() and not ships_seen.has(int(sh.get("arrived", -1))):
			ships_seen[int(sh.get("arrived", -1))] = true
			visits["ship"] += 1
			for e in sh.get("stock", []):
				if _rare(str(e.get("def", ""))):
					seen["ship"] += 1
					total_qty += int(e["qty"])
		var rs := Commerce.rival_stock()
		if Game.day() % int(Commerce.rival_cfg().get("restock_days", 4)) == 0:
			visits["rival"] += 1
			for e in rs:
				if _rare(str(e.get("def", ""))):
					seen["rival"] += 1
					total_qty += int(e.get("qty", 1))
		if Commerce.caravan_present() and not ships_seen.has("caravan_%d" % int(Commerce.caravan().get("arrived", Commerce.caravan().get("since", 0)))):
			ships_seen["caravan_%d" % int(Commerce.caravan().get("arrived", Commerce.caravan().get("since", 0)))] = true
			visits["caravan"] += 1
			for e in Commerce.caravan().get("stock", []):
				if _rare(str(e.get("def", ""))):
					seen["caravan"] += 1
	note("60 days: rare metals offered — ships %d (%d ships), rival %d (%d restocks), caravan %d (%d days present); %d units in all" % [
		seen["ship"], visits["ship"], seen["rival"], visits["rival"], seen["caravan"], visits["caravan"], total_qty])
	check(int(seen["ship"]) + int(seen["rival"]) + int(seen["caravan"]) <= 5, "routine trade in the first two months: rare metals almost never (%s, %s)" % [str(seen), str(visits)])
	# imports: refused before the smith has seen the metal; then at most two, one such cargo at a time, dearly
	Game.state["gold"] = 50000
	for d in ["ore_adamantine", "ore_mithril"]:
		Trade.st()["seen"].erase(d)
		if Game.count(d) > 0:
			Game.remove_def(d, Game.count(d))
	check(Trade.place_import("ore_adamantine", 5) != "", "an import of a never-seen metal is refused")
	Trade.mark_seen("ore_adamantine")
	Trade.mark_seen("ore_mithril")
	eq(Trade.place_import("ore_adamantine", 5), "", "once seen, the harbourmaster takes the order")
	var o: Dictionary = Trade.imports().back()
	eq(int(o["qty"]), 2, "…two at most")
	check(int(o["total"]) >= 2 * int(float(DB.item("ore_adamantine")["value"]) * 2.4), "…dearly (%d g)" % int(o["total"]))
	check(Trade.place_import("ore_mithril", 1) != "", "one such cargo at a time")
	eq(Trade.place_import("ingot_steel", 4), "", "ordinary imports are unaffected")


func test_dangerous_places_still_yield_them() -> void:
	fresh_game("journeyman", 7402)
	var got := {}
	for table in ["deep_mine", "deep_boss", "rift", "rift_boss", "starfall"]:
		var n := 0
		for i in 40:
			for e in Loot.roll_table(table):
				var def := str(e.get("def", e.get("id", ""))) if e is Dictionary else ""
				if _rare(def):
					n += int(e.get("qty", 1))
		got[table] = n
	note("rare metals from 40 rolls each: %s" % str(got))
	check(int(got["deep_mine"]) > 20 and int(got["rift"]) > 20 and int(got["deep_boss"]) > 10, "the deep and the rift yield them well")
	# the advanced Designs that need them are not orphaned: every rare input has a dangerous source
	for d in ["ore_mithril", "ore_adamantine", "ore_orichalcum"]:
		var srcs := []
		for t in DB.loot:
			if str(t).begins_with("_"):
				continue
			for e in (DB.loot[t] as Dictionary).get("entries", []):
				if str(e[0]) == d:
					srcs.append(str(t))
		check(srcs.size() >= 3, "%s comes from %s" % [d, ", ".join(srcs)])
