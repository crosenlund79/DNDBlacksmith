## Scenario A — beginner to master. From genuine new-game conditions, a planner learns the skill tree up to
## Legendary Arcane Craftsmanship and forges Dragonscale Armour using only the game's own systems:
##   * skills rise by actually crafting recipes of that skill (fixed check scores and dice);
##   * materials come from the herbalist, merchant ships, special imports, hireling trade runs and expeditions,
##     or are crafted from other materials;
##   * stations are bought through Property (only once the tree allows) and placed in owned rooms; rooms are
##     bought next door when the workshop is full;
##   * knowledge flags come from what the systems teach (restoring a rune tablet, holding a dragon scale).
## The one stand-in: gold is credited as "business income" (earning it is covered by scenario B), so this
## scenario tests reachability of the crafting progression, not the economy's pacing.
extends SuiteCase

const SMOKE := []
const MAX_DAYS := 900

var trail: Array[String] = []
var days_used := 0
var fails_why := {}


func _say(t: String) -> void:
	trail.append("day %d · %s" % [Game.day(), t])


func _income(n: int) -> void:
	if Game.gold() < n:
		Game.add_gold(n - Game.gold() + 500, "commissions", "Business income (test stand-in)")


func _day() -> void:
	days(1)
	days_used += 1


# ------------------------------------------------------------------ stations & rooms
## Buy the station (the tree must allow it) and set it up in an owned room; buy rooms when there is no space.
func ensure_station(sid: String) -> String:
	if Property.is_installed(sid):
		return _station_upgrade(sid)
	var why := SkillTree.station_reason(sid)
	if why != "":
		return why
	if not Property.is_owned_station(sid):
		_income(Property.station_price(sid))
		var err := Property.buy_station(sid)
		if err != "":
			return err
	for attempt in 8:
		if _place_somewhere(sid):
			_say("installed %s" % sid)
			return _station_upgrade(sid)
		if not _buy_next_room():
			break
	return "no room left for the " + sid


## Stations that also need a workshop upgrade (the arcane foundry): buy it in the ledger.
func _station_upgrade(sid: String) -> String:
	var u: Dictionary = DB.station(sid).get("unlock", {})
	if u.has("upgrade") and not Game.has_upgrade(str(u["upgrade"])):
		var cost := int(DB.upgrades.get(str(u["upgrade"]), {}).get("cost", 0))
		_income(cost)
		var r: Dictionary = DB.upgrades.get(str(u["upgrade"]), {}).get("requires", {})
		if r.has("flag") and not Game.has_flag(str(r["flag"])) and str(r["flag"]) == "found_mithril":
			acquire("ore_mithril", 1)
		var err := Shop.buy_upgrade(str(u["upgrade"]))
		if err != "":
			return "%s needs the %s: %s" % [sid, u["upgrade"], err]
		_say("bought the %s upgrade" % u["upgrade"])
	return ""


func _place_somewhere(sid: String) -> bool:
	var plan := Property.plan_copy()
	for r in plan["rooms"]:
		if not Property.room_owned(r):
			continue
		var rr := Property.rect(r)
		var y := rr.position.y + 1.2
		while y < rr.end.y - 0.8:
			var x := rr.position.x + 1.2
			while x < rr.end.x - 0.8:
				var p2 := plan.duplicate(true)
				if Property.place(p2, sid, Vector2(x, y)) == "" and Property.validate(p2) == "":
					return Property.commit(p2) == ""
				x += 0.75
			y += 0.75
	return false


func _buy_next_room() -> bool:
	var best := ""
	var best_p := 1 << 30
	for u in Property.units():
		var uid: String = u["id"]
		if Property.unit_state(uid) == "available" and Property.unit_price(uid) < best_p:
			best = uid
			best_p = Property.unit_price(uid)
	if best == "":
		return false
	_income(best_p)
	if Property.buy_unit(best) == "":
		_say("bought %s" % best)
		return true
	return false


# ------------------------------------------------------------------ materials
func acquire(def: String, n: int, depth := 0) -> String:
	if Game.count(def) >= n:
		return ""
	if depth > 6:
		return "too deep acquiring " + def
	var need := n - Game.count(def)
	# 1. craft it, if a recipe makes it (refined materials) — learning that recipe's node first if needed
	for r in DB.recipes.values():
		if str(r["output"]) == def and not SkillTree.recipe_known(str(r["id"])) and SkillTree.recipe_visible(str(r["id"])) and depth < 3:
			var rn := SkillTree.recipe_node(str(r["id"]))
			if rn != "" and achieve(rn, 0) == "":
				_say("learned %s to make %s" % [rn, def])
		if str(r["output"]) == def and SkillTree.recipe_known(str(r["id"])) and SkillTree.recipe_reason(str(r["id"])) == "":
			var guard := 0
			while Game.count(def) < n and guard < 20:
				guard += 1
				var err := make(str(r["id"]), depth + 1)
				if err != "":
					break
			if Game.count(def) >= n:
				return ""
	# 2. the herbalist's daily stock
	if has_system("trade"):
		for d in 6:
			for e in Trade.herbalist_stock():
				if e["def"] == def and int(e["qty"]) > 0:
					_income(int(e["price"]) * int(e["qty"]))
					Trade.buy_herbalist(def, mini(int(e["qty"]), n - Game.count(def)))
			if Game.count(def) >= n or not Trade.herbalist_stock().any(func(x): return x["def"] == def):
				break
			_day()
		if Game.count(def) >= n:
			return ""
		# 3. a special import, once the harbourmaster knows of it
		if Trade.knows(def) and not Trade.import_info(def).is_empty():
			var left := n - Game.count(def)
			while left > 0:
				var q := mini(left + 2, 20)
				_income(Trade.import_info(def)["unit"] * q * 2)
				var err2 := Trade.place_import(def, q)
				if err2 != "":
					_collect_imports(40)
					err2 = Trade.place_import(def, q)
					if err2 != "":
						break
				_collect_imports(40)
				left = n - Game.count(def)
			if Game.count(def) >= n:
				_say("imported %s" % def)
				return ""
		# 4. merchant ships: wait for one that carries it (first contact with exotic goods)
		var waited := 0
		while Game.count(def) < n and waited < 260:
			var ship := Trade.current_ship()
			var stock: Array = ship.get("stock", [])
			for i in stock.size():
				if stock[i]["def"] == def and int(stock[i]["qty"]) > 0:
					_income(int(stock[i]["price"]) * int(stock[i]["qty"]))
					Trade.buy_from_ship(i, mini(int(stock[i]["qty"]), n - Game.count(def)))
			if Game.count(def) >= n:
				_say("bought %s from %s" % [def, ship.get("name", "a ship")])
				return ""
			# once known (held one), imports can make up the rest
			if Game.count(def) > 0 and Trade.knows(def) and not Trade.import_info(def).is_empty():
				return acquire(def, n, depth + 1)
			_day()
			waited += 1
	# 5. finds offered at the shop counter by returning adventurers
	for o in Shop.offers().duplicate():
		if str(o["item"].get("def", "")) == def and Game.count(def) < n:
			_income(int(o["price"]))
			Shop.accept_offer(str(o["id"]))
	if Game.count(def) >= n:
		_say("bought %s offered at the counter" % def)
		return ""
	# 6. hireling expeditions (ores, coal, relics)
	for dest in ["highmarsh_road", "ironroot_mine", "barrow_fields", "whisperwood"]:
		var g := 0
		while Game.count(def) < n and g < 30:
			g += 1
			if not _expedition(dest, def):
				break
		if Game.count(def) >= n:
			_say("hirelings brought %s" % def)
			return ""
	return "could not obtain %s ×%d (have %d)" % [def, n, Game.count(def)]


func _collect_imports(max_days: int) -> void:
	var d := 0
	while not Trade.imports().filter(func(o): return o["status"] == "ordered").is_empty() and d < max_days:
		_day()
		d += 1
	for o in Trade.deliveries().duplicate():
		var info := Trade.import_info(str(o["def"]))
		_income(int(info.get("unit", 50)) * int(o.get("qty", 1)) * 2)
		Trade.collect_delivery(str(o["id"]))


## Sends an available hireling (trade runs carry a purse and a shopping list) and collects what comes home.
func _expedition(dest: String, want: String) -> bool:
	var h := {}
	for x in Hire.list():
		if x["status"] == "working":
			h = x
	if h.is_empty():
		if Hire.alive_count() < 3:
			_income(400)
			Hire.refresh_applicants()
			if not (Game.state["applicants"] as Array).is_empty():
				Hire.hire_applicant(0)
		for x in Hire.list():
			if x["status"] == "working":
				h = x
	if h.is_empty():
		_day()
		return true
	_income(300)
	if Hire.send(str(h["id"]), dest, {"budget": 200, "want": [want]}) != "":
		return false
	var g := 0
	while h["status"] == "away" and g < 14:
		_day()
		g += 1
	for c in (Game.state["returns"] as Array).duplicate():
		for it in c.get("contents", []):
			Game.add_item(it, false)
		(Game.state["returns"] as Array).erase(c)
	return true


# ------------------------------------------------------------------ crafting & skills
## Craft one recipe through the real job flow (stations installed, inputs acquired).
func make(rid: String, depth := 0) -> String:
	var r := DB.recipe(rid)
	for sid in r["steps"]:
		var why := ensure_station(str(sid))
		if why != "":
			return "%s: station %s — %s" % [rid, sid, why]
	for def in r["inputs"]:
		var err := acquire(str(def), int(r["inputs"][def]), depth)
		if err != "":
			return "%s: %s" % [rid, err]
	var blocker := craft_blocker(rid)
	if blocker != "":
		return "%s: %s" % [rid, blocker]
	Vitality.set_fatigue(0.0)
	var it := craft(rid, 100.0, {"edge": 14, "temper": 14, "fortune": 60, "guard": 14, "spellweave": 14})
	return "" if not it.is_empty() else "%s: the job did not finish" % rid


## Raise a skill by crafting known recipes that train it (cheapest inputs first).
func train_by_crafting(skill: String, level: int) -> String:
	var tries := 0
	while Game.player_level(skill) < level and tries < 260:
		tries += 1
		var cands := []
		for r in DB.recipes.values():
			var rid: String = r["id"]
			if Crafting.recipe_skill(rid) == skill and SkillTree.recipe_known(rid) and SkillTree.recipe_reason(rid) == "":
				var cost := 0
				for d in r["inputs"]:
					cost += int(DB.item(str(d)).get("value", 10)) * int(r["inputs"][d])
				cands.append([cost, rid])
		cands.sort_custom(func(a, b): return a[0] < b[0])
		var ok := false
		var last := ""
		for c in cands:
			last = make(str(c[1]))
			if last == "":
				ok = true
				break
		if not ok:
			return "cannot train %s to %d (at %d): %s" % [skill, level, Game.player_level(skill), last if last != "" else "no recipe"]
	return "" if Game.player_level(skill) >= level else "training %s stalled" % skill


# ------------------------------------------------------------------ the tree
func achieve(id: String, depth := 0) -> String:
	if SkillTree.is_unlocked(id):
		return ""
	if depth > 30:
		return "prerequisite loop at " + id
	var n := SkillTree.node(id)
	var req: Dictionary = n.get("requires", {})
	for p in req.get("nodes", []):
		var e := achieve(str(p), depth + 1)
		if e != "":
			return e
	if req.has("skill"):
		var e2 := train_by_crafting(str(req["skill"][0]), int(req["skill"][1]))
		if e2 != "":
			return "%s: %s" % [id, e2]
	for f in req.get("flags", []):
		var e3 := obtain_flag(str(f))
		if e3 != "":
			return "%s: %s" % [id, e3]
	for sid in req.get("stations_installed", []):
		var e4 := ensure_station(str(sid))
		if e4 != "":
			return "%s: %s" % [id, e4]
	for def in req.get("items_seen", []):
		if not SkillTree.seen(str(def)):
			var e5 := acquire(str(def), 1)
			if e5 != "":
				return "%s: %s" % [id, e5]
	for def in req.get("items", {}):
		var e6 := acquire(str(def), int(req["items"][def]))
		if e6 != "":
			return "%s: %s" % [id, e6]
	_income(int(req.get("gold", 0)))
	var why := SkillTree.unlock(id)
	if why == "":
		_say("learned %s" % n.get("name", id))
	return why


func obtain_flag(f: String) -> String:
	if Game.has_flag(f):
		return ""
	# a recipe that teaches it (restoring an old runestone teaches rune lore)
	for r in DB.recipes.values():
		if str(r.get("teaches_flag", "")) == f:
			var e := achieve(SkillTree.recipe_node(str(r["id"])))
			if e != "":
				return e
			var e2 := make(str(r["id"]))
			return e2 if not Game.has_flag(f) else ""
	# dragon lore: hold a dragon scale or bone
	if f == "dragon_lore":
		var e3 := acquire("dragon_scale", 1)
		return e3 if not Game.has_flag(f) else ""
	return "no legitimate source for knowledge '%s'" % f


# ------------------------------------------------------------------ the test
func test_beginner_to_master() -> void:
	if not has_system("skilltree") or not has_system("trade"):
		skip("needs the skill tree and trade")
		return
	check(craft_blocker("iron_longsword") == "", "start: an ordinary iron longsword can be forged")
	check(craft_blocker("steel_longsword") != "" and craft_blocker("dragonscale_armor") != "", "start: steel and dragon armour are out of reach")
	var milestones := [["s_blades", "simple blades"], ["s_steel", "steelworking"], ["r_original", "original runes"],
		["ar_crucible", "the Arcane Crucible"], ["ar_plating", "mithril armour plating"], ["l_dragon", "dragon-scale preparation"],
		["ar_legend", "legendary arcane craftsmanship"]]
	for m in milestones:
		var nid: String = m[0]
		if SkillTree.node(nid).is_empty():
			note("node %s not in this tree" % nid)
			continue
		var err := achieve(nid)
		if not check(err == "", "learned %s (day %d) %s" % [m[1], Game.day(), err]):
			for t in trail.slice(maxi(0, trail.size() - 25)):
				note(t)
			break
	if SkillTree.is_unlocked("ar_legend"):
		var e := make("dragonscale_armor")
		check(e == "", "Dragonscale Armour forged from real dragon parts (%s)" % e)
		var arm := {}
		for it in Game.inventory():
			if it.get("def", "") == DB.recipe("dragonscale_armor").get("output", ""):
				arm = it
		check(not arm.is_empty() and Items.stat(arm, "protection") > 0, "the armour exists with protection %d (%s)" % [Items.stat(arm, "protection"), arm.get("rarity", "?")])
	note("%d simulated days, %d rooms owned, %d nodes learned, skills: smithing %d, runecraft %d, arcane %d, stitching %d, mining %d" % [days_used,
		(Property.st()["units"] as Array).size(), SkillTree.learned().size(), Game.player_level("smithing"), Game.player_level("runecraft"),
		Game.player_level("arcane_metalwork"), Game.player_level("enchanted_stitching"), Game.player_level("mining")])
	for t in trail.slice(maxi(0, trail.size() - 14)):
		note(t)
	check(save_load("suite_progression") and SkillTree.is_unlocked("s_steel"), "progression survives save/load")
