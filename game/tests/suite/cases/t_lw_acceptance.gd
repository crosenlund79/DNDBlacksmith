## The Living Workshop — consolidated acceptance (the milestone brief §9), end to end through the paths the game itself
## calls (Crafting, Shop, Apprentices/WorkOrders, Property, Steward/StewardSmith, Family, Saves/SaveMigrations); only
## fixtures (specialists taken on with Apprentices.dev_take_on, the whole tree known, a full purse) are set directly.
##  a. a fresh poor smith with no employees: start gold, basic crafting and selling at the counter, his basic cap and
##     the specialist reasons are honest, and no Design, tree node or work-order path leaves him without a next step;
##  b. an established five-hand workshop (smith, blacksmith, runesmith, alchemist, leatherworker) with several anvils
##     and forges bought through Property: over working days two or more instances of a type are worked at once,
##     the hands spread, nobody waits for instance #1 while another stands free;
##  c. the Emberwarden Longsword from raw ore, herbs and blank runestones to a buyer: the intermediates made by the right
##     professions, the order's stages at real station instances, the smith claiming and forging his stages, one uid
##     from the order to the buyer, the maker unchanged, the contributors in provenance and Lore, identity clean, the
##     sale conserving money (the buyer's purse down by exactly what the forge's purse gained, one ledger line);
##  d. the same work order manually (the smith learns) and under Steward Mode (a stage begun under the steward, saved
##     and loaded in the middle and finished after the return; another stage by the steward's smith): ZERO player
##     experience, skill, mastery or knowledge, while the employees progress;
##  e. the spouse's discount cap on real counter sales while the steward runs the forge, at 0 % and at 10 %;
##  f. commissions only for combinations the workshop can make: many generated requests (the world's own and every
##     adventurer × slot) checked against RELIABILITY's data oracle and against work-order feasibility;
##  g. short cross-system smoke: per-actor checks, a worn shield (#57), buying and moving station instances and then
##     rebuilding the skill tree (#59–60), ten save slots;
##  h. old saves: every golden save (0.11.2–0.14.6) and a schema-4 save with apprentices, tasks and stations load through
##     the real loader to schema 7, migrating twice changes nothing, identity and Uniques clean, three days played on.
extends SuiteCase

const SMOKE := ["test_a_fresh_poor_smith", "test_c_emberwarden_from_raw_materials_to_a_buyer"]
const FIN := ["done", "failed", "cancelled"]
const EMBER := "emberwarden_longsword"
const GOLDEN := ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]
const FIXTURES := "res://tests/fixtures/saves/"


# ================================================================== fixtures
func _at_hour(h: int) -> void:
	var mins: int = (h * 60 - int(Game.state["minute"]) % 1440 + 1440) % 1440
	Game.advance_minutes(mins)


## Customers whose figures would have reached their seat (headless there is no world: Shop.mark_arrived, as soaks do).
func _seat() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _skills() -> String:
	return JSON.stringify(Game.player_skills())


func _clean(label: String) -> void:
	var sc := ItemRegistry.scan()
	check((sc["dup"] as Array).is_empty() and (sc["shared"] as Array).is_empty() and (sc["stray"] as Array).is_empty(),
		"%s: ItemRegistry.scan is clean (%s)" % [label, ItemRegistry.scan_text(sc)])
	eq(Uniques.audit().size(), 0, "%s: Uniques.audit is clean" % label)


## The gold ledger from a mark on: Game.add_gold appends one line per payment (the ledger keeps the last 400).
func _lmark() -> Dictionary:
	var lg: Array = Game.state["ledger"]
	return {"last": lg[lg.size() - 1] if not lg.is_empty() else {}, "gold": Game.gold()}


func _lines_since(m: Dictionary) -> Array:
	var lg: Array = Game.state["ledger"]
	var out := []
	var i := lg.size() - 1
	var last: Dictionary = m["last"]
	while i >= 0 and not (not last.is_empty() and is_same(lg[i], last)):
		out.push_front(lg[i])
		i -= 1
	return out


func _sum(lines: Array) -> int:
	var s := 0
	for ln in lines:
		s += int(ln["amount"])
	return s


## An established workshop: every room bought through Property with the purse, the whole tree known (fixture), every
## station of the owned rooms set up, the smith at Smithing 8 by experience, and a blacksmith, a runesmith, an
## alchemist and a leatherworker taken on (four is the most the workshop houses: five hands with the smith).
func _established(rng := 9001, purse := 60000, lvl := 7) -> Dictionary:
	fresh_game("journeyman", rng)
	(Game.state["hirelings"] as Array).clear()   # field hirelings' hauls would move the stores under the test
	Game.state["gold"] = purse
	var guard := 0
	var more := true
	while more and guard < 12:
		more = false
		for u in Property.units():
			if not Property.owns(str(u["id"])) and Property.buy_unit(str(u["id"])) == "":
				more = true
		guard += 1
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	train("smithing", 8)
	var hands := {}
	for p in ["blacksmith", "runesmith", "alchemist", "leatherworker"]:
		var a := Apprentices.dev_take_on(p, lvl, "master" if lvl >= 8 else "journeyman")
		check(not a.is_empty(), "a %s is taken on" % p)
		hands[p] = a
	return hands


## Buys one more of a type through Property and sets it up (auto-placed, plan committed). "" on failure.
func _buy_instance(t: String) -> String:
	var before := Property.instances(t, false)
	var err := Property.buy_station(t)
	if not check(err == "", "another %s is bought (%s)" % [t, err]):
		return ""
	var iid := ""
	for x in Property.instances(t, false):
		if not before.has(x):
			iid = str(x)
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, iid)
	if not check(why == "" and Property.commit(plan) == "", "%s is set up (%s)" % [iid, why]):
		return ""
	return iid


## Runs the clock in 5-minute steps until `cond` holds or `max_min` pass.
func _until(cond: Callable, max_min: int) -> bool:
	var g := 0
	while not cond.call() and g < max_min:
		Game.advance_minutes(5)
		g += 5
	return cond.call()


## The smith plays every operation of the stage he claimed (fixed scores at the station instance he stands at).
func _smith_stage(tid: int, q := 100.0) -> bool:
	var err := WorkOrders.begin_smith_stage(tid)
	if not check(err == "", "the smith takes up his stage (%s)" % err):
		return false
	var guard := 0
	while Crafting.active() and Crafting.job().has("order") and guard < 12:
		var qs := []
		for i in int(Crafting.current_op().get("checks", 1)):
			qs.append(q)
		Crafting.record_step(Crafting.smith_instance(), qs)
		guard += 1
	return check(not Crafting.active(), "his stage is done and the piece handed on")


## An adventurer (not the smith's spouse) in town who would buy `it` at `price` once their purse holds it.
func _buyer_for(it: Dictionary, price: int) -> Dictionary:
	var ids: Array = Adv.all().keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = Adv.all()[id]
		if str(a["id"]) == Social.spouse() or str(a.get("status", "")) == "dead":
			continue
		var keep := int(a["gold"])
		a["gold"] = price
		var ok := Adv.purchase_check(a, it, price) == ""
		a["gold"] = keep
		if ok:
			Expeditions.ensure(a)
			a["status"] = "in_town"
			return a
	return {}


# ================================================================== a. a fresh poor smith
func test_a_fresh_poor_smith() -> void:
	fresh_game("journeyman", 4242)
	eq(Game.gold(), 120, "a new game starts with 120 g")
	check(Apprentices.staff().is_empty(), "no employees")
	eq(Workers.workshop_actors(), ["player"], "the workshop is the smith alone")
	var m := _lmark()
	var crafted0 := int(Game.state["stats"]["crafted"])
	# basic crafting through his own stations with the starting materials
	var made := []
	for rid in ["dagger", "hand_axe", "iron_hatchet", "round_shield", "iron_longsword"]:
		if made.size() >= 2 or DB.recipe(rid).is_empty() or craft_blocker(rid) != "":
			continue
		var it := craft(rid, 88.0)
		if check(not it.is_empty(), "the smith makes a %s from the starting stores" % rid):
			made.append(it)
	check(made.size() >= 2, "two pieces made with the starting materials (%d)" % made.size())
	eq(int(Game.state["stats"]["crafted"]) - crafted0, made.size(), "the forge's record counts them")
	for it in made:
		eq(str(Provenance.maker(it).get("id", "")), Provenance.SMITH_ID, "%s: the smith is its maker" % it["name"])
		Shop.set_for_sale(int(it["uid"]), true)
	# the counter over two working days: repairs paid by the customer, display pieces sold to who will pay
	var sold := 0
	var repairs := 0
	var conserved := true
	for d in 2:
		_at_hour(9)
		for h in 10:
			Game.advance_minutes(60)
			_seat()
			for c in Shop.waiting().duplicate():
				var npc := str(c["npc"])
				match str(c.get("want", "")):
					"repair":
						var g0 := Game.gold()
						Shop.do_repair(npc, 80.0)
						if Game.gold() > g0:
							repairs += 1
					"browse":
						var a := Adv.get_a(npc)
						if a.is_empty():
							continue
						for it2 in Shop.stock():
							if not Items.is_equipment(it2):
								continue
							var price := Shop.price_of(it2)
							if Adv.purchase_check(a, it2, price) != "":
								continue
							var purse0 := int(a["gold"])
							var gold0 := Game.gold()
							var uid := int(it2["uid"])
							if Shop.sell_to(npc, uid) == "":
								sold += 1
								conserved = conserved and Game.gold() - gold0 == price and purse0 - int(a["gold"]) == price
								check(not Game.find_uid_anywhere(uid).is_empty() and str(Game.find_uid_anywhere(uid).get("owner", "")) == npc,
									"the buyer holds the very piece (uid %d)" % uid)
							break
	check(sold + repairs > 0, "two days at the counter earned real money (%d sales, %d repairs)" % [sold, repairs])
	check(conserved, "every sale moved the price from the buyer's purse to the forge's")
	var lines := _lines_since(m)
	eq(_sum(lines), Game.gold() - int(m["gold"]), "every coin is a ledger line (%d lines)" % lines.size())
	check(lines.all(func(l): return str(l.get("party", "")) != "" or int(l["amount"]) == 0), "each line names the other party (D14)")
	note("poor smith, 2 days: gold 120 → %d, %d sales, %d repairs, %d ledger lines" % [Game.gold(), sold, repairs, lines.size()])
	# his basic cap: other crafts stop at the basic level; smithing and mining keep growing
	eq(Workers.growth_cap("player", "runecraft"), Workers.BASIC_LEVEL, "runecraft is basic for him (cap %d)" % Workers.BASIC_LEVEL)
	eq(Workers.growth_cap("player", "smithing"), int(DB.skill_curve.get("max_level", 20)), "smithing is his own craft (no cap)")
	for i in 40:
		Game.grant_player_xp("runecraft", 400)
	eq(Game.player_level("runecraft"), Workers.BASIC_LEVEL, "experience takes runecraft to the basic level and no further")
	train("smithing", Workers.BASIC_LEVEL + 2)
	eq(Game.player_level("smithing"), Workers.BASIC_LEVEL + 2, "smithing grows past it")
	# the specialist reasons are honest: master-grade work names the profession and where to find one
	var q := Workers.specialist_need("player", "concord_runestone")
	check(not q.is_empty() and str(q.get("skill", "")) == "runecraft", "the Concord runestone is beyond the basic smith (%s)" % str(q))
	var hint := ""
	for r in SkillTree.requirements("r_master"):
		if str(r["kind"]) == "skill":
			hint = str(r["hint"])
	check(hint.contains("runesmith"), "Master Runecrafting names who meets it: %s" % hint)
	# no dead end: every visible Design he cannot make has a next step; beyond-basic crafts lead to the notice board
	var no_step := []
	var to_board := 0
	for rid2 in DB.recipes:
		if not Guide.recipe_visible(str(rid2)) or Workers.can_do("player", str(rid2)) == "":
			continue
		var stp := Guide.next_step("recipe:" + str(rid2))
		if str(stp.get("text", "")) == "":
			no_step.append(str(rid2))
		elif str(stp.get("action", {}).get("route", "")) == "notice":
			to_board += 1
	eq(no_step, [], "every Design he cannot make yet has a next step")
	note("Designs whose next step is the notice board (a specialist): %d" % to_board)
	# the tree: his own path needs his levels; another craft beyond basic names a specialist
	var dead_nodes := []
	for n in SkillTree.nodes():
		for r2 in SkillTree.requirements(str(n["id"])):
			if str(r2["kind"]) == "skill" and str(r2.get("owner", "")) == "workshop" and not bool(r2["ok"]) and str(r2["hint"]) == "":
				dead_nodes.append(str(n["id"]))
	eq(dead_nodes, [], "every tree node he cannot meet says who can")
	# the work-order path: without staff the Workshop Ledger explains how to get there, it does not fail
	var err: Dictionary = Apprentices.add_task("craft", {"recipe": "dagger"})
	check(err.has("error") and str(err["error"]) != "", "with no workshop staff the queue says why: %s" % str(err.get("error", "")))
	eq(StationPanel.order_reason(EMBER), "No staff.", "'Order it' is not offered without staff")
	check(Apprentices.unlock_reason() == "" or Apprentices.unlock_reason().length() > 10, "the way to the notice board is named: %s" % Apprentices.unlock_reason())
	_clean("poor smith")
	# once the workshop knows every Design (fixture), each one beyond his basic grasp names the specialist to take on
	SkillTree.unlock_all()
	Property.dev_grant_all()
	var beyond := 0
	var dead := []
	var two_step := []
	var keep := JSON.stringify(Game.player_skills())
	for rid3 in DB.recipes:
		var why := Workers.can_do("player", str(rid3))
		if why == "" or not Guide.recipe_visible(str(rid3)) or Workers.specialist_need("player", str(rid3)).is_empty():
			continue
		beyond += 1
		# follow the steps: a basic skill step he can take first (e.g. "Raise Enchanted Stitching to 3"), then the specialist
		var steps := PackedStringArray()
		var stp2 := Guide.next_step("recipe:" + str(rid3))
		var g := 0
		while str(stp2.get("action", {}).get("route", "")) != "notice" and str(stp2.get("text", "")).begins_with("Raise ") and g < 4:
			steps.append(str(stp2["text"]).get_slice(" —", 0))
			for o in Guide.recipe_status(str(rid3))["obstacles"]:
				if str(o["kind"]) == "skill" and int(o["level"]) <= Workers.BASIC_LEVEL:
					Game.player_skills()[str(o["id"])] = {"lvl": int(o["level"]), "xp": 0}   # as if he had raised it
			stp2 = Guide.next_step("recipe:" + str(rid3))
			g += 1
		if str(stp2.get("action", {}).get("route", "")) != "notice" or not str(stp2.get("text", "")).begins_with("Take on"):
			dead.append("%s: %s" % [rid3, str(stp2.get("text", ""))])
		elif not steps.is_empty():
			two_step.append("%s (%s, then: %s)" % [rid3, "; ".join(steps), str(stp2["text"]).get_slice(" —", 0)])
		Game.state["player"]["skills"] = JSON.parse_string(keep)
		Game.state["player"]["skills"] = Saves._restore_ints(Game.state["player"]["skills"])
	check(beyond >= 5, "several master-grade Designs are beyond the basic smith (%d)" % beyond)
	eq(dead, [], "each of them leads him, step by step, to the notice board for the specialist")
	if not two_step.is_empty():
		note("FINDING: the first step shown is a basic skill step that does not by itself open the Design: %s" % ", ".join(PackedStringArray(two_step)))


# ================================================================== b. an established five-hand workshop
## Who stands at each installed instance of `stype` now ("" = free).
func _users(stype: String) -> Dictionary:
	var out := {}
	for sid in Property.instances(stype):
		out[str(sid)] = Apprentices.instance_user(str(sid))
	return out


func test_b_established_workshop_spreads_over_station_instances() -> void:
	var hands := _established(8080, 60000, 6)
	eq(Workers.workshop_actors().size(), 5, "five hands: the smith and four specialists (the most the workshop houses)")
	eq(Property.max_instances("anvil"), 5, "one anvil per pair of hands, at most five")
	for t in ["anvil", "anvil", "forge", "forge", "grinding_wheel", "stitching_table"]:
		_buy_instance(t)
	eq(Property.instance_count("anvil"), 3, "three anvils")
	eq(Property.instance_count("forge"), 3, "three forges")
	check(Property.validate(Property.plan_copy()) == "", "the workshop plan is valid with the extra stations")
	for pair in [["ingot_iron", 40], ["coal", 40], ["leather_cured", 20], ["thread_linen", 10], ["runestone_blank", 4], ["reagent_salt", 12],
			["herb_emberleaf", 8], ["herb_moonwort", 8]]:
		give(str(pair[0]), int(pair[1]))
	var bs := str(hands["blacksmith"]["id"])
	_at_hour(7)   # the day's work starts with the sampling
	var queue := [["craft", "iron_hatchet", 10, bs], ["craft", "iron_longsword", 4, ""], ["prep", "ward_runestone", 3, ""], ["prep", "whetstone_oil", 4, ""],
		["prep", "healing_draught", 3, ""], ["craft", "leather_boots", 3, ""], ["craft", "studded_leather", 2, ""]]
	var tasks := []
	for q in queue:
		var opts := {"recipe": str(q[1]), "repeat": int(q[2])}
		if str(q[3]) != "":
			opts["assignee"] = str(q[3])
		var t := Apprentices.add_task(str(q[0]), opts)
		if check(not t.has("error"), "%s ×%d queued (%s)" % [q[1], q[2], t.get("error", "")]):
			tasks.append(t)
	var studded: Dictionary = tasks[-1]
	check(WorkOrders.staged(studded), "studded leather is a staged work order (leather · anvil · leather)")
	# three working days, sampled every five minutes; the smith works pieces by hand at the anvils and forges
	var busy := {}        # instance id → sampled minutes in use
	var peak := {}        # type → most instances of it in use at once
	var waited_free := []
	var smith_pieces := 0
	var smith_wait := 0
	for d in 3:
		if d > 0:
			_at_hour(7)
		for step in 12 * 12:
			if not Crafting.active() and Game.hour() < 18 and Game.count("ingot_iron") > 4:
				if Crafting.start("hand_axe"):
					smith_wait = 0
			elif Crafting.active():
				smith_wait += 1
				if smith_wait >= 4:   # twenty minutes an operation
					smith_wait = 0
					var at := Crafting.smith_instance()
					Crafting.choose_instance(at)
					var qs := []
					for i in int(Crafting.current_op().get("checks", 1)):
						qs.append(90.0)
					Crafting.record_step(at, qs)
					if Crafting.job().get("awaiting_dice", false):
						if not Crafting.finish({"edge": 10, "temper": 8, "fortune": 40}, "digital").is_empty():
							smith_pieces += 1
			Game.advance_minutes(5)
			for ty in ["anvil", "forge", "grinding_wheel", "stitching_table", "crucible"]:
				var u := _users(ty)
				var n := 0
				for sid in u:
					if str(u[sid]) != "":
						n += 1
						busy[sid] = int(busy.get(sid, 0)) + 5
				peak[ty] = maxi(int(peak.get(ty, 0)), n)
			for t2 in Apprentices.open_tasks():
				if not str(t2.get("blocker", "")).begins_with("Waiting for the"):
					continue
				var ops := Crafting.operations(str(t2.get("recipe", "")))
				if ops.is_empty():
					continue
				var ty2 := Property.type_of(str(ops[mini(int(t2.get("op", 0)), ops.size() - 1)].get("station", "")))
				for sid2 in Property.instances(ty2):
					if Apprentices.instance_user(str(sid2)) == "":
						waited_free.append("%s waits for %s while %s stands free" % [t2.get("label", ""), ty2, sid2])
	check(int(peak.get("anvil", 0)) >= 2, "two or more anvils worked at once (peak %d)" % int(peak.get("anvil", 0)))
	check(int(peak.get("forge", 0)) >= 2 or int(peak.get("anvil", 0)) >= 3, "…and forges too (peak %d)" % int(peak.get("forge", 0)))
	eq(waited_free.slice(0, 3), [], "nobody waits for a station while another of its kind stands free")
	var used := []
	for sid in Property.instances("anvil"):
		used.append("%s %d min" % [sid, int(busy.get(str(sid), 0))])
	check((Property.instances("anvil") as Array).filter(func(s): return int(busy.get(str(s), 0)) > 0).size() >= 2, "the work spreads over the anvils: %s" % ", ".join(PackedStringArray(used)))
	var made := 0
	for t3 in tasks:
		made += int(t3["done"])
	check(made >= 10, "the hands got real work done (%d pieces and batches)" % made)
	check(smith_pieces >= 3, "the smith made pieces of his own beside them (%d)" % smith_pieces)
	var util := PackedStringArray()
	var ks := busy.keys()
	ks.sort()
	for k in ks:
		util.append("%s %d" % [k, int(busy[k])])
	note("peaks %s; minutes in use (3 days, 07–19): %s; staff pieces %d, smith %d" % [str(peak), ", ".join(util), made, smith_pieces])
	note("queue: %s" % ", ".join(PackedStringArray(tasks.map(func(x): return "%s %d/%d %s %s" % [x["recipe"], int(x["done"]), int(x["repeat"]), x["state"], str(x.get("blocker", "")).left(50)]))))
	if str(studded["state"]) == "done":
		var su := Game.find_uid(int((studded["made"] as Array)[-1]))
		check(not su.is_empty() and Provenance.contributors(su).size() + 1 >= 1, "the staged studded leather was made")
	_clean("established workshop")


# ================================================================== c. the Emberwarden from raw materials to a buyer
## Buys `def` from the Brask caravan through Commerce.buy_caravan when it is in town with it. Returns the qty bought.
func _buy_from_caravan(def: String, qty: int) -> int:
	var cv := Commerce.caravan()
	if cv.is_empty():
		return 0
	var stock: Array = cv["stock"]
	for i in stock.size():
		if str(stock[i].get("def", "")) == def and int(stock[i].get("qty", 0)) >= qty:
			var n0 := Game.count(def)
			if Commerce.buy_caravan(i, qty) == "":
				return Game.count(def) - n0
	return 0


func test_c_emberwarden_from_raw_materials_to_a_buyer() -> void:
	var hands := _established(4711)
	var bs: Dictionary = hands["blacksmith"]
	var rune: Dictionary = hands["runesmith"]
	var alch: Dictionary = hands["alchemist"]
	var leath: Dictionary = hands["leatherworker"]
	# raw materials only: the starting ingots go (fixture); ore, coal, herbs and blank runestones stay
	Game.remove_def("ingot_iron", Game.count("ingot_iron"))
	Game.remove_def("ingot_steel", Game.count("ingot_steel"))
	for d in ["ore_iron", "coal", "herb_emberleaf", "runestone_blank"]:
		check(Game.count(d) > 0, "raw %s in the stores (%d)" % [d, Game.count(d)])
	eq(Game.count("ingot_steel") + Game.count("ingot_iron") + Game.count("runestone_ember") + Game.count("coating_flame"), 0, "no worked material to start from")
	# the intermediates as ordinary preparation orders — the workshop gives each to whoever may do it
	var preps := []
	for spec in [["smelt_iron", 2], ["smelt_steel", 2], ["ember_runestone", 1], ["flame_coating", 1]]:
		var p := Apprentices.add_task("prep", {"recipe": str(spec[0]), "repeat": int(spec[1])})
		if check(not p.has("error"), "%s ×%d is queued (%s)" % [spec[0], spec[1], p.get("error", "")]):
			preps.append(p)
	_at_hour(8)
	check(_until(func(): return preps.all(func(p): return str(p["state"]) in FIN), 6 * 1440),
		"the preparation is done: %s" % str(preps.map(func(p): return "%s %s %s" % [p["recipe"], p["state"], p.get("blocker", "")])))
	eq(Game.count("ingot_steel"), 2, "two steel ingots smelted from ore")
	eq(Game.count("runestone_ember"), 1, "an ember runestone cut")
	eq(Game.count("coating_flame"), 1, "a flame coating brewed")
	var by := {}
	for row in MaterialLedger.rows():
		by[str(row["def"])] = row
	var src := func(d: String) -> String: return str((by.get(d, {}).get("sources", []) as Array).map(func(s): return str(s[0])))
	check(src.call("ingot_steel").contains(str(bs["name"])), "the blacksmith smelted the steel (%s)" % src.call("ingot_steel"))
	for pair in [["runestone_ember", rune, "the runesmith cut the runestone"], ["coating_flame", alch, "the alchemist brewed the coating"]]:
		var made_by := ""
		for x in Game.inventory():
			if str(x["def"]) == str(pair[0]):
				made_by = str(x.get("crafted_by", x.get("craft", {}).get("maker_name", "")))
		eq(made_by, str(pair[1]["name"]), str(pair[2]))
	# the ethereal thread is bought from the Brask caravan when it comes to town (an imported raw material)
	var thread := 0
	check(_until(func(): return Commerce.caravan_present(), 12 * 1440), "the caravan comes to town")
	thread = _buy_from_caravan("thread_ethereal", 1)
	if thread == 0:
		Commerce.dev_force_caravan()   # its wagons did not carry thread this time: the next visit (developer tool)
		thread = _buy_from_caravan("thread_ethereal", 1)
	if thread == 0:
		give("thread_ethereal", 1)
		note("no ethereal thread in two caravan visits — given as a fixture")
	else:
		note("ethereal thread bought from the Brask caravan")
	# the order: one uid reserved now; the smith claims the forging and the honing
	var m := _lmark()
	var steel0 := Game.count("ingot_steel")
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	if not check(not t.has("error"), "the Emberwarden is ordered (%s)" % t.get("error", "")):
		return
	var tid := int(t["id"])
	var uid := int(t.get("uid", 0))
	check(uid > 0 and ItemRegistry.find(uid).is_empty(), "uid %d reserved, nothing half-made exists" % uid)
	eq(WorkOrders.assign_stage(tid, 0, "player"), "", "the smith claims the forging")
	eq(WorkOrders.assign_stage(tid, 3, "player"), "", "…and the honing")
	_at_hour(8)
	Game.advance_minutes(5)
	_smith_stage(tid)
	eq(steel0 - Game.count("ingot_steel"), 2, "the order took the two steel ingots once")
	check(_until(func(): return WorkOrders.stage_index(t) == 3 and str(t.get("worker", "")) == "", 2 * 1440), "rune and quench done; the honing waits for him (%s)" % t.get("blocker", ""))
	_smith_stage(tid)
	check(_until(func(): return str(t["state"]) in FIN, 2 * 1440), "the order finishes (%s %s)" % [t["state"], t.get("blocker", "")])
	eq(str(t["state"]), "done", "done")
	var it := Game.find_uid(uid)
	if not check(not it.is_empty(), "the sword is in the stores under the uid reserved at creation"):
		return
	var ops: Array = it.get("craft", {}).get("ops", [])
	eq(ops.map(func(o): return str(o.get("by", ""))), ["player", "player", str(rune["id"]), str(alch["id"]), "player", str(leath["id"])],
		"every operation by the right hand (the smith forged, drew and honed; each specialist their own craft)")
	for o in ops:
		var at := str(o.get("at", o.get("station", "")))
		check(Property.is_installed(at) and Property.type_of(at) == str(o.get("station", "")), "%s at a real %s (%s)" % [o.get("op", ""), o.get("station", ""), at])
	eq(str(it["def"]), "sword_emberwarden", "it is the Emberwarden Longsword")
	eq(str(Provenance.maker(it).get("id", "")), Provenance.SMITH_ID, "the smith is the maker")
	var con := Provenance.contributors(it)
	eq(con.map(func(e): return str(e["profession"])), ["runesmith", "alchemist", "leatherworker"], "the three specialists in its provenance")
	var lore := Lore.of_item(uid).filter(func(e): return str(e.get("kind", "")) == "contributed")
	check(lore.size() == 1 and str(lore[0]["text"]).contains(str(rune["name"]).split(" ")[0]), "one Lore event names the contributors")
	eq(_sum(_lines_since(m)), Game.gold() - int(m["gold"]), "no coin moved without a ledger line while it was made")
	_clean("the Emberwarden made")
	# stored, displayed and sold at the counter to a real buyer
	Shop.set_for_sale(uid, true)
	var price := Shop.price_of(it)
	var a := _buyer_for(it, price)
	if not check(not a.is_empty(), "someone would buy it at %d g" % price):
		return
	a["gold"] = price + 25   # an adventurer's purse is rarely this deep: the buyer is given the coin (fixture)
	_at_hour(10)
	var purse0 := int(a["gold"])
	var m2 := _lmark()
	eq(Shop.sell_to(str(a["id"]), uid), "", "%s buys it at the counter" % a["name"])
	var lines := _lines_since(m2)
	eq(lines.size(), 1, "one ledger line")
	if lines.size() == 1:
		eq(int(lines[0]["amount"]), price, "…for the price")
		eq(str(lines[0].get("party", "")), str(a["id"]), "…naming the buyer")
		eq(str(lines[0]["cat"]), "sales", "…as a sale")
	eq(Game.gold() - int(m2["gold"]), price, "the forge's purse gained the price")
	eq(purse0 - int(a["gold"]), price, "the buyer's purse lost exactly that")
	var held := Game.find_uid_anywhere(uid)
	if check(not held.is_empty(), "the sword is found by its uid with the buyer"):
		check(is_same(held, it), "one creation, one object: the very sword")
		eq(str(held.get("owner", "")), str(a["id"]), "owned by the buyer")
		eq(str(Provenance.maker(held).get("id", "")), Provenance.SMITH_ID, "the maker unchanged")
		eq(Provenance.contributors(held).size(), 3, "the contributors still recorded")
	check(Lore.of_item(uid).any(func(e): return str(e.get("kind", "")) == "sold"), "its Lore records the sale")
	_clean("after the sale")
	check(save_load("lwacc_ember"), "saved and loaded")
	var again := Game.find_uid_anywhere(uid)
	check(not again.is_empty() and str(again.get("owner", "")) == str(a["id"]) and Provenance.contributors(again).size() == 3, "…the buyer still holds it with its history")
	_clean("after loading")


# ================================================================== d. manual and Steward production: zero player XP
## Everything that would show the smith learning: his skills (levels and experience) and the tree's learned nodes.
## (World flags are not his learning: the village goes on — "aldric_asked" and the like.)
func _smith_learning() -> String:
	return JSON.stringify({"skills": Game.player_skills(), "nodes": SkillTree._st()["nodes"]})


func _staff_xp(hands: Dictionary) -> Dictionary:
	var out := {}
	for p in hands:
		var a := Apprentices.get_a(str(hands[p]["id"]))
		var sk := Workers.skill_of(str(p))
		out[p] = int(a["skills"].get(sk, {}).get("lvl", 0)) * 100000 + int(a["skills"].get(sk, {}).get("xp", 0))
	return out


func test_d_work_order_manual_and_under_the_steward_zero_xp() -> void:
	var hands := _established(5150)
	give("ingot_steel", 4)
	give("runestone_ember", 2)
	give("coating_flame", 2)
	give("thread_ethereal", 2)
	Steward.st()["orders"]["order_rules"]["max_difficulty"] = 6   # the player's standing rule lets the steward's smith do this work
	# 1. by hand: the smith claims his stages and works them — he learns from his own work
	var t1 := Apprentices.add_task("craft", {"recipe": EMBER})
	WorkOrders.assign_stage(int(t1["id"]), 0, "player")
	WorkOrders.assign_stage(int(t1["id"]), 3, "player")
	var xp_m0 := int(Game.player_skills()["smithing"]["xp"]) + 100000 * Game.player_level("smithing")
	_at_hour(8)
	Game.advance_minutes(5)
	_smith_stage(int(t1["id"]))
	check(_until(func(): return WorkOrders.stage_index(t1) == 3 and str(t1.get("worker", "")) == "", 2 * 1440), "manual order: the honing waits for him")
	_smith_stage(int(t1["id"]))
	check(_until(func(): return str(t1["state"]) in FIN, 2 * 1440), "the manual order is finished (%s)" % t1["state"])
	check(int(Game.player_skills()["smithing"]["xp"]) + 100000 * Game.player_level("smithing") > xp_m0, "by hand, the smith gains smithing experience")
	# 2. the same work order under the steward
	var learn0 := _smith_learning()
	var staff0 := _staff_xp(hands)
	var t2 := Apprentices.add_task("craft", {"recipe": EMBER})
	var tid := int(t2["id"])
	var uid := int(t2["uid"])
	WorkOrders.assign_stage(tid, 0, "player")
	WorkOrders.assign_stage(tid, 3, "player")
	_at_hour(7)
	eq(Steward.activate(), "", "the steward takes over")
	check(_until(func(): return Crafting.active() and int(Crafting.job().get("order", -1)) == tid and int(Crafting.job().get("step", 0)) >= 1, 12 * 60),
		"the steward's smith takes up his claimed forging stage and is in the middle of it")
	check(Steward.marked(Crafting.job()), "…a job begun under the steward")
	# saved and loaded in the middle of the stage: Steward Mode is off after loading, the job stays marked
	check(save_load("lwacc_steward_mid"), "saved and loaded mid-stage")
	check(not Steward.is_active(), "a loaded game starts with the steward off (no offline progress)")
	t2 = Apprentices.task(tid)
	check(Crafting.active() and int(Crafting.job().get("order", -1)) == tid and Steward.marked(Crafting.job()), "the half-done stage is still in his hands, still marked")
	# the player finishes that stage himself after the return
	var guard := 0
	while Crafting.active() and Crafting.job().has("order") and guard < 12:
		var qs := []
		for i in int(Crafting.current_op().get("checks", 1)):
			qs.append(100.0)
		Crafting.record_step(Crafting.smith_instance(), qs)
		guard += 1
	eq(str(WorkOrders.stages(t2)[0].get("by", "")), "player", "the forging stage is done by the smith")
	check(bool(WorkOrders.stages(t2)[0].get("steward", false)), "…and recorded as the steward's work")
	eq(_smith_learning(), learn0, "finishing a stage begun under the steward teaches him nothing")
	# the specialists' stages; then the steward again for his honing
	check(_until(func(): return WorkOrders.stage_index(t2) == 3 and str(t2.get("worker", "")) == "", 2 * 1440), "rune and quench done (%s)" % t2.get("blocker", ""))
	eq(Steward.activate(), "", "the steward takes over again")
	check(_until(func(): return WorkOrders.stage_index(t2) >= 4 or str(t2["state"]) in FIN, 2 * 1440), "the steward's smith hones the blade")
	var r := Steward.deactivate()
	check(int(r.get("smith", {}).get("xp_withheld", 0)) > 0, "the guard withheld his experience (%d)" % int(r.get("smith", {}).get("xp_withheld", 0)))
	# the leatherworker finishes the order after the player is back
	check(_until(func(): return str(t2["state"]) in FIN, 2 * 1440), "the order finishes after the return (%s %s)" % [t2["state"], t2.get("blocker", "")])
	var it := Game.find_uid(uid)
	if check(not it.is_empty(), "the steward's Emberwarden is in the stores under its reserved uid"):
		eq(str(Provenance.maker(it).get("id", "")), Provenance.SMITH_ID, "the smith is its maker")
		eq(Provenance.contributors(it).size(), 3, "the three specialists contributed")
		var mine := (it.get("craft", {}).get("ops", []) as Array).filter(func(o): return str(o.get("by", "")) == "player")
		check(not mine.is_empty() and mine.all(func(o): return bool(o.get("steward", false))), "all his operations are marked as the steward's work")
	eq(_smith_learning(), learn0, "ZERO player experience, skill, mastery or knowledge for the steward's order")
	var staff1 := _staff_xp(hands)
	for p in ["runesmith", "alchemist", "leatherworker"]:
		check(int(staff1[p]) > int(staff0[p]), "the %s progressed in their own craft (%d → %d)" % [p, int(staff0[p]), int(staff1[p])])
	_clean("after the steward's order")


## Defect found by this acceptance (ACC-1): cancelling a work order in the Workshop Ledger while the smith is in the
## middle of his claimed stage returned the materials but left his craft job carrying the cancelled order — new work
## and the steward's hand-over were refused ("Finish or set aside the work at the station first") and his further
## steps vanished without a piece. The job now ends with the order; nothing is doubled or lost.
func test_d_cancelled_order_ends_the_smiths_stage() -> void:
	_established(1357)
	give("ingot_steel", 2)
	give("runestone_ember", 1)
	give("coating_flame", 1)
	give("thread_ethereal", 1)
	var before := {}
	for d in ["ingot_steel", "runestone_ember", "coating_flame", "thread_ethereal"]:
		before[d] = Game.count(d)
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	var tid := int(t["id"])
	eq(WorkOrders.assign_stage(tid, 0, "player"), "", "the smith claims the forging")
	_at_hour(8)
	Game.advance_minutes(5)
	eq(WorkOrders.begin_smith_stage(tid), "", "he begins it")
	Crafting.record_step(Crafting.smith_instance(), [90.0])
	check(Crafting.active() and int(Crafting.job().get("order", -1)) == tid, "he is in the middle of his stage")
	eq(Apprentices.cancel_task(tid), "", "the order is cancelled in the Workshop Ledger (✕)")
	for d in before:
		eq(Game.count(str(d)), int(before[d]), "%s is back in the stores, once" % d)
	check(not Crafting.active(), "his stage of the cancelled order ends with it — no stale job in his hands")
	eq(Steward.can_activate(), "", "the steward can take over")
	check(Crafting.start("hand_axe"), "and he can start other work")
	Crafting.cancel()
	_clean("after cancelling mid-stage")


# ================================================================== e. the spouse's discount cap under the steward
func _marry_helping(npc: String) -> void:
	Social.set_romance(npc, "married")
	Social.ensure(npc)["aff"] = 80.0
	if npc == Roisin.ID:
		Roisin.st()["free"] = true
	check(bool(Family.ask(npc)["ok"]), "%s agrees to help at the counter" % npc)


func _seat_buyer(a: Dictionary) -> void:
	Shop.remove_customer(str(a["id"]))
	var now := Game.day() * 24 + Game.hour()
	Shop.customers().append({"npc": str(a["id"]), "want": "browse", "arrived": now, "seated": now, "seat": Shop.free_seat(), "present": true,
		"budget": 0, "looking_for": ""})


func test_e_spouse_discount_cap_under_the_steward() -> void:
	fresh_game("journeyman", 6060)
	(Game.state["hirelings"] as Array).clear()
	Shop.customers().clear()
	for x in Game.inventory():
		x.erase("for_sale")
	_marry_helping("roisin")
	eq(Family.discount_cap(), 0, "the default cap is 0 %")
	# two of the smith's own pieces on display
	give("ingot_iron", 6)
	give("leather_cured", 4)
	give("coal", 6)
	var p1 := craft("iron_longsword", 90.0)
	var p2 := craft("iron_longsword", 90.0)
	if not check(not p1.is_empty() and not p2.is_empty(), "two longswords forged (%s)" % craft_blocker("iron_longsword")):
		return
	Shop.set_for_sale(int(p1["uid"]), true)
	Shop.set_for_sale(int(p2["uid"]), true)
	var price := Shop.price_of(p1)
	var a := _buyer_for(p1, price)
	if not check(not a.is_empty(), "someone would buy a longsword at %d g" % price):
		return
	var xp0 := _smith_learning()
	_at_hour(9)
	Game.advance_minutes(45)
	eq(Steward.activate(), "", "the steward runs the forge (its own sales duty on)")
	# 0 %: a buyer 3 g short is served by nobody — neither she nor the steward sells below the display price
	a["gold"] = price - 3
	_seat_buyer(a)
	var m := _lmark()
	Game.advance_minutes(60)
	check(not Game.find_uid(int(p1["uid"])).is_empty() and not Game.find_uid(int(p2["uid"])).is_empty(), "cap 0 %: nothing sold below the display price")
	check(_lines_since(m).filter(func(l): return str(l["cat"]) == "sales").is_empty(), "…no sales line")
	# 10 %: she gives the 3 g the buyer lacks, no more
	eq(Family.set_discount_cap(10), "", "the player allows her 10 %")
	if Shop.customer(str(a["id"])).is_empty():
		_seat_buyer(a)
	var purse0 := int(a["gold"])
	var m2 := _lmark()
	Game.advance_minutes(30)
	var gone := Game.find_uid(int(p1["uid"])).is_empty() or Game.find_uid(int(p2["uid"])).is_empty()
	check(gone, "within the cap, she sells")
	var sales := _lines_since(m2).filter(func(l): return str(l["cat"]) == "sales")
	if check(sales.size() == 1, "one sales line (%d)" % sales.size()):
		var ln: Dictionary = sales[0]
		eq(int(ln["amount"]), price - 3, "for what the buyer could pay (≥ the 10 %% floor %d)" % Family.floor_price(price))
		check(price - 3 >= Family.floor_price(price), "never below the floor")
		eq(str(ln.get("party", "")), str(a["id"]), "the buyer is the payer")
		check(str(ln["note"]).contains("at the counter") and str(ln["note"]).contains("% off"), "the line names her and the discount: %s" % ln["note"])
	eq(purse0 - int(a["gold"]), price - 3, "the buyer's purse paid it")
	eq(_sum(_lines_since(m2)), Game.gold() - int(m2["gold"]), "every coin is a ledger line")
	var sold: Array = Steward.st()["acc"]["sold"]
	check(not sold.is_empty() and str(sold[-1].get("by", "")) != "", "the steward's report counts her sale")
	# a buyer who needs 20 % off is not served at 10 %
	var b := {}
	var left := p2 if Game.find_uid(int(p1["uid"])).is_empty() else p1
	for id in Adv.all():
		var c: Dictionary = Adv.all()[id]
		if str(c["id"]) != str(a["id"]) and str(c["id"]) != Social.spouse() and str(c.get("status", "")) != "dead":
			var keep := int(c["gold"])
			c["gold"] = price
			if Adv.purchase_check(c, left, price) == "":
				b = c
			c["gold"] = keep
			if not b.is_empty():
				break
	if check(not b.is_empty(), "a second buyer"):
		Expeditions.ensure(b)
		b["status"] = "in_town"
		b["gold"] = int(price * 0.8)
		_seat_buyer(b)
		Game.advance_minutes(60)
		check(not Game.find_uid(int(left["uid"])).is_empty(), "20 % short with a 10 % cap: not sold")
	var r := Steward.deactivate()
	eq(int(r["sales"]["count"]), 1, "While You Were Away: one sale")
	check(bool(r["gold"]["reconciled"]), "the steward's report reconciles every coin")
	eq(_smith_learning(), xp0, "zero player experience")
	_clean("spouse sales")


# ================================================================== f. commissions only for what can be made
## RELIABILITY's independent data oracle (t_lw_reliability._feasible): is there ANY Design whose piece this adventurer
## would use for the slot, of the tier, reaching the stat — by itself (range top × 1.2) or with one runestone (× 1.32)?
func _oracle(a: Dictionary, slot: String, stat: String, need: int, tier: int) -> bool:
	var rune := 0
	for r in DB.recipes.values():
		var d := DB.item(str(r["output"]))
		if str(d.get("type", "")) == "runestone":
			rune = maxi(rune, int(floor(float(d.get("stats", {}).get(stat, 0)) * 1.32)))
	for r in DB.recipes.values():
		var out := str(r["output"])
		var d := DB.item(out)
		if str(d.get("slot", "")) != slot or str(d.get("type", "")) == "companion" or Adv.affinity(a, {"def": out}) <= 0.0 or Items.tier({"def": out}) < tier:
			continue
		var v: Variant = d.get("stats", {}).get(stat, 0)
		var top := int(floor((float(v[1]) if v is Array else float(v)) * 1.2))
		if top >= need or (slot == "weapon" and not (stat in ["attack", "protection", "magic"]) and rune >= need):
			return true
	return false


## Can the workshop — its knowledge, stations and people — make this Design as a work order? Every stage has a hand.
func _wo_ok(rid: String, memo: Dictionary) -> bool:
	if memo.has(rid):
		return bool(memo[rid])
	var probe := {"kind": "craft", "recipe": rid, "op": 0, "ops_done": [], "started": false, "worker": ""}
	var ok := Workers.knowledge_reason(rid) == ""
	if ok:
		for s in WorkOrders.stages(probe):
			if WorkOrders.who_can_stage(probe, int(s["i"])).is_empty():
				ok = false
				break
	memo[rid] = ok
	return ok


## A Design the workshop can make as a work order that meets the commission ("" = none): the piece itself, or a piece
## with a runestone set into it (the runestone's Design must be feasible too).
func _wo_route(a: Dictionary, o: Dictionary, memo: Dictionary) -> String:
	if o.has("def"):
		for r in DB.recipes.values():
			if str(r["output"]) == str(o["def"]) and _wo_ok(str(r["id"]), memo):
				return str(r["id"])
		return ""
	var req := {"stat": str(o["stat"]), "min": int(o["min"]), "tier": int(o.get("tier", 1))}
	var rr := Shop.rune_route(str(o["stat"]))
	for r in DB.recipes.values():
		var how := Shop._route(r, str(o["slot"]), a, req)
		if how == "" or not _wo_ok(str(r["id"]), memo):
			continue
		if how == "rune" and not _wo_ok(str(rr.get("recipe", "")), memo):
			continue
		return str(r["id"])
	return ""


## Checks every commission in `orders` (oracle + work-order feasibility); returns {n, bad_oracle, bad_wo, flagged_but_makeable, examples}.
func _audit_orders(orders: Array, memo: Dictionary) -> Dictionary:
	var out := {"n": 0, "bad_oracle": 0, "bad_wo": 0, "flagged_makeable": 0, "not_wo": 0, "examples": [], "not_wo_why": []}
	for o in orders:
		var a := Adv.get_a(str(o.get("npc", "")))
		if a.is_empty():
			continue
		out["n"] = int(out["n"]) + 1
		if not o.has("def") and not _oracle(a, str(o["slot"]), str(o["stat"]), int(o["min"]), int(o.get("tier", 1))):
			out["bad_oracle"] = int(out["bad_oracle"]) + 1
			(out["examples"] as Array).append("oracle: %s %s %s ≥ %d" % [a["cls"], o["slot"], o["stat"], int(o["min"])])
		var route := _wo_route(a, o, memo)
		if route == "":
			out["not_wo"] = int(out.get("not_wo", 0)) + 1
			var why := ""
			var req := {"stat": str(o.get("stat", "")), "min": int(o.get("min", 0)), "tier": int(o.get("tier", 1))}
			for r in DB.recipes.values():
				if not o.has("def") and Shop._route(r, str(o["slot"]), a, req) != "":
					var probe := {"kind": "craft", "recipe": str(r["id"]), "op": 0, "ops_done": [], "started": false, "worker": ""}
					for s in WorkOrders.stages(probe):
						if WorkOrders.who_can_stage(probe, int(s["i"])).is_empty():
							why = "%s: %s" % [r["id"], WorkOrders.staff_gap(probe, int(s["i"])).get_slice(" —", 0)]
					break
			(out["not_wo_why"] as Array).append("%s %s (%s)%s" % [a["cls"], Shop.order_text(o), why, " — flagged 'not yet'" if bool(o.get("opportunity", false)) else ""])
			if not bool(o.get("opportunity", false)):
				out["bad_wo"] = int(out["bad_wo"]) + 1   # promised as makeable, yet nobody can make it: dishonest
				(out["examples"] as Array).append("no work order: %s %s" % [a["cls"], Shop.order_text(o)])
		elif bool(o.get("opportunity", false)):
			out["flagged_makeable"] = int(out["flagged_makeable"]) + 1
	return out


func test_f_commissions_only_for_what_the_workshop_can_make() -> void:
	var tot := {"n": 0, "bad_oracle": 0, "bad_wo": 0, "flagged_makeable": 0, "not_wo": 0}
	var examples := []
	var not_wo := []
	var parts_n := 0
	var parts_bad := []
	for world_seed in [9001, 77, 1234]:
		_established(world_seed, 60000, 8)
		var memo := {}
		var seen := {}
		var orders := []
		# the world's own commissions over three weeks (Sim, adventurers' plans, consultations, broken blades …)
		for d in 21:
			Game.advance_minutes(1440)
			for o in Shop.orders():
				if not seen.has(str(o["id"])):
					seen[str(o["id"])] = true
					orders.append(o)
		# and one commission from every adventurer for every slot they would ask about, through Shop.create_order
		for a in Adv.all().values():
			if str(a.get("status", "")) == "dead" or Shop.refuses(str(a["id"])):
				continue
			for slot in Adv.desired_slots(a):
				var o2 := Shop.create_order(str(a["id"]), str(slot))
				if not o2.is_empty():
					orders.append(o2.duplicate(true))
			for pt in Shop.multi_parts_for(a):
				if str(pt.get("kind", "")) != "craft":
					continue
				parts_n += 1
				if not _wo_ok(str(pt["recipe"]), memo):
					parts_bad.append("%s: %s" % [a["cls"], pt["recipe"]])
		Shop.orders().clear()
		var r := _audit_orders(orders, memo)
		for k in tot:
			tot[k] = int(tot[k]) + int(r[k])
		examples.append_array(r["examples"])
		not_wo.append_array(r["not_wo_why"])
	note("%d commissions checked (3 worlds, a five-hand workshop of masters without an arcanist: 21 days of the world's own + every adventurer × slot): %d fail the data oracle; %d no work order of this workshop could make (%d of them promised as makeable); %d flagged 'not yet' that the staffed workshop could make; %d multi-part pieces, %d not makeable"
		% [int(tot["n"]), int(tot["bad_oracle"]), int(tot["not_wo"]), int(tot["bad_wo"]), int(tot["flagged_makeable"]), parts_n, parts_bad.size()])
	if not not_wo.is_empty():
		note("beyond this workshop's people (honestly 'not yet'): %s" % ", ".join(PackedStringArray(not_wo.slice(0, 6))))
	check(int(tot["n"]) >= 200, "many commissions were generated (%d)" % int(tot["n"]))
	eq(int(tot["bad_oracle"]), 0, "no commission asks for what no Design they would use makes %s" % str(examples.slice(0, 4)))
	eq(int(tot["bad_wo"]), 0, "no commission is promised as makeable that the workshop's people cannot make as a work order %s" % str(examples.slice(0, 4)))
	check(int(tot["not_wo"]) * 20 <= int(tot["n"]), "commissions beyond the staffed workshop are rare (%d of %d)" % [int(tot["not_wo"]), int(tot["n"])])
	eq(parts_bad.slice(0, 4), [], "every multi-part piece can be made by the staffed workshop")


# ================================================================== g. short cross-system smoke
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _ghosts(n: Node) -> int:
	var g := 0
	for c in n.get_children():
		if c.is_queued_for_deletion() and (c as CanvasItem).visible:
			g += 1
	return g


func test_g_checks_shield_tree_after_moving_stations_and_ten_slots() -> void:
	var hands := _established(3131, 60000, 6)
	var bs := str(hands["blacksmith"]["id"])
	# per-actor checks: each worker's own level shapes the check (the smith at Smithing 8, the blacksmith at 6)
	var cs := Workers.check_params("player", "anvil", "iron_longsword")
	var cb := Workers.check_params(bs, "anvil", "iron_longsword")
	eq(str(cb.get("actor", "")), bs, "the check carries its actor")
	check(float(cs.get("zone", 0.0)) > float(cb.get("zone", 0.0)), "the smith's wider zone (%.1f) than the blacksmith's (%.1f) — his own level" % [float(cs.get("zone", 0.0)), float(cb.get("zone", 0.0))])
	var cr := Workers.check_params(str(hands["runesmith"]["id"]), "rune_engraving_stand", "ward_runestone")
	var cp := Workers.check_params("player", "rune_engraving_stand", "ward_runestone")
	check(float(cr.get("zone", 0.0)) > float(cp.get("zone", 0.0)), "at the rune stand the runesmith's check is the easier one")
	# #57: a shield the smith forges and wears stays one piece, shown and taken off again
	give("ingot_iron", 2)
	give("leather_cured", 2)
	var sh := craft("round_shield")
	if check(not sh.is_empty(), "a round shield forged (%s)" % craft_blocker("round_shield")):
		var uid := int(sh["uid"])
		eq(Game.equip_player(uid), "shield", "worn in the shield slot")
		check(Game.find_uid(uid).is_empty() and is_same(Game.state["player"]["equipment"]["shield"], sh), "the very piece is worn, not copied")
		eq(str(ItemRegistry.where(uid).get("holder", "")), "smith", "the registry knows where it is")
		check(save_load("lwacc_shield"), "save/load while worn")
		eq(int(Game.state["player"]["equipment"].get("shield", {}).get("uid", -1)), uid, "still worn after loading")
		check(Game.unequip_player("shield") and not Game.find_uid(uid).is_empty(), "taken off: back in the stores")
	# #59–60: buy and move station instances, then open and rebuild the skill tree
	var a2 := _buy_instance("anvil")
	var f2 := _buy_instance("forge")
	if check(a2 != "" and f2 != "", "two more stations bought and set up"):
		var plan := Property.plan_copy()
		var p0 := Property.pos_of(a2)
		Property.store(plan, a2)
		eq(Property.commit(plan), "", "the new anvil is put in storage")
		plan = Property.plan_copy()
		eq(Property.auto_place(plan, a2), "", "…and set up again elsewhere")
		eq(Property.commit(plan), "", "the plan is applied")
		check(Property.is_installed(a2), "it stands (moved from %s to %s)" % [p0, Property.pos_of(a2)])
	var tp := SkillTreePanel.new()
	_host().add_child(tp)
	for i in 3:
		tp._build_skills()
	eq(_ghosts(tp.skill_row), 0, "rebuilding the branch row leaves no ghosts")
	for id in ["s_basic", "r_master", "ar_plating", "l_dragon", "s_starsteel", ""]:
		tp._show(id, true)
		eq(_ghosts(tp.side), 0, "the side page for «%s» is laid out alone" % id)
	tp._refresh()
	tp._refresh()
	check(tp._refresh_queued, "refreshes in one frame are gathered")
	tp._do_refresh()
	tp.get_parent().remove_child(tp)
	tp.free()
	_clean("after buying and moving stations")
	# ten save slots: each holds the game and loads it back
	var slots := Saves.manual_slots()
	eq(slots.size(), 10, "ten save slots")
	var snap := JSON.stringify({"gold": Game.gold(), "day": Game.day(), "staff": Apprentices.staff().size(), "anvils": Property.instances("anvil")})
	for s in slots:
		check(Saves.save(str(s)), "saved into %s" % s)
	for s in [slots[0], slots[4], slots[9]]:
		check(Saves.load_slot(str(s)), "%s loads" % s)
		eq(JSON.stringify({"gold": Game.gold(), "day": Game.day(), "staff": Apprentices.staff().size(), "anvils": Property.instances("anvil")}), snap, "%s holds the same game" % s)
	for s in slots:
		Saves.delete(str(s))
	_clean("after the save slots")


# ================================================================== h. old saves
func _install_golden(name: String, slot: String) -> bool:
	var text := FileAccess.get_file_as_string(FIXTURES + name + ".json")
	if not check(text.length() > 1000, "the golden save %s is present" % name):
		return false
	var f := FileAccess.open(Saves.path(slot), FileAccess.WRITE)
	if not check(f != null, "it can be copied into this run's test folder"):
		return false
	f.store_string(text)
	f.close()
	return true


func _snap(v: Variant) -> String:
	return JSON.stringify(v, "", true, true)


## Loaded and migrated: the version, identity, Uniques, idempotent re-migration, a round trip, three days of play.
func _old_save_checks(label: String, steps_expected: Array) -> void:
	var errs := Log.error_count
	var rep: Dictionary = Saves.last_load.get("migration", {})
	eq(int(Game.state.get("version", -1)), Game.SAVE_VERSION, "%s: migrated to schema %d" % [label, Game.SAVE_VERSION])
	check(steps_expected.all(func(s): return (rep.get("steps", []) as Array).has(s)), "%s: the Living Workshop steps ran %s" % [label, str(rep.get("steps", []))])
	_clean("%s loaded" % label)
	var once := _snap(Game.state)
	var again: Dictionary = JSON.parse_string(once)
	again = Saves._restore_ints(again)
	for to in range(1, SaveMigrations.latest() + 1):
		SaveMigrations.apply_step(to, again)
	eq(_snap(again), once, "%s: migrating the migrated save again changes nothing" % label)
	check(save_load("lwacc_old_rt"), "%s: saved and loaded again" % label)
	eq((Saves.last_load.get("migration", {}).get("steps", ["?"]) as Array).size(), 0, "%s: a schema-%d save runs no step" % [label, Game.SAVE_VERSION])
	var d0 := Game.day()
	for i in 3:
		Game.advance_minutes(1440)
		for c in Shop.customers().duplicate():
			if not bool(c.get("present", false)):
				Shop.mark_arrived(str(c["npc"]), false)
	eq(Game.day(), d0 + 3, "%s: three more days of play" % label)
	eq(Log.error_count, errs, "%s: no errors logged while loading on and playing" % label)
	_clean("%s after three days" % label)


func test_h_golden_saves_load_migrate_and_play_on() -> void:
	for g in GOLDEN:
		var slot := "lwacc_" + str(g).replace(".", "_").replace("-", "_")
		if not _install_golden(str(g), slot):
			continue
		var errs := Log.error_count
		if not check(Saves.load_slot(slot), "%s loads through the real loader" % g):
			continue
		eq(Log.error_count, errs, "%s: loading logs no error" % g)
		eq(int(Saves.last_load.get("migration", {}).get("from", -1)), 1, "%s: a schema-1 save" % g)
		_old_save_checks(str(g), ["worker professions", "workshop knowledge", "station instances and work orders"])
		# migrating the same file twice from scratch gives the same data
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + str(g) + ".json"))
		var d1: Dictionary = Saves._restore_ints(raw["data"])
		var d2: Dictionary = Saves._restore_ints((JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + str(g) + ".json")) as Dictionary)["data"])
		SaveMigrations.run(d1)
		SaveMigrations.run(d2)
		eq(_snap(d1), _snap(d2), "%s: two migrations of the same file agree" % g)
		Saves.delete(slot)


func test_h_schema4_save_with_apprentices_tasks_and_stations() -> void:
	var hands := _established(2468, 60000, 7)
	var bs: Dictionary = Apprentices.get_a(str(hands["blacksmith"]["id"]))
	bs["skills"]["smithing"] = {"lvl": 9, "xp": 0}
	bs["rank"] = "master"
	give("ingot_steel", 2)
	give("runestone_ember", 1)
	give("coating_flame", 1)
	give("thread_ethereal", 1)
	give("ingot_iron", 6)
	give("leather_cured", 2)
	give("ore_iron", 4)
	give("coal", 6)
	var ember := Apprentices.add_task("craft", {"recipe": EMBER, "assignee": str(bs["id"])})
	var sword := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 2})
	var smelt := Apprentices.add_task("prep", {"recipe": "smelt_iron", "repeat": 2})
	check(not ember.has("error") and not sword.has("error") and not smelt.has("error"), "three tasks queued")
	_at_hour(8)
	check(_until(func(): return int(ember["op"]) >= 2, 600), "the master blacksmith forged and drew the Emberwarden's blade (op %d)" % int(ember["op"]))
	var plan := Property.plan_copy()
	Property.store(plan, "loom")
	eq(Property.commit(plan), "", "a station waits in storage")
	# the shape of a schema-4 save: no professions, no workshop-knowledge store, tasks without stages or reserved uids
	var tids := Apprentices.open_tasks().map(func(t): return int(t["id"]))
	var taken := JSON.stringify(ember["taken"])
	for a in Apprentices.staff():
		(a as Dictionary).erase("profession")
	(Game.state["player"] as Dictionary).erase("profession")
	Game.state.erase("workshop_knowledge")
	for t in Apprentices.tasks():
		for k in ["stages", "stages_for", "uid", "handoff"]:
			(t as Dictionary).erase(k)
	var layout := _snap(Property.st()["stations"])
	var stored := _snap(Property.st()["stored"])
	check(save_as_version("lwacc_v4", 4), "written as a schema-4 save")
	check(Saves.load_slot("lwacc_v4"), "it loads through the real loader")
	Saves.delete("lwacc_v4")
	eq(Saves.last_load.get("migration", {}).get("steps", []), ["worker professions", "workshop knowledge", "station instances and work orders", "the compact smithy"],
		"steps 5, 6, 7 and (v1.7) 8 run, once each")
	for a in Apprentices.staff():
		check(Workers.PROFESSIONS.has(str(a.get("profession", ""))), "%s has a profession again (%s)" % [a["name"], a.get("profession", "")])
	check(WorkshopKnowledge.knows_design(EMBER), "the workshop knows its Designs again")
	eq(_snap(Property.st()["stations"]), layout, "the layout is unchanged (every station is instance #1 under its id)")
	eq(_snap(Property.st()["stored"]), stored, "storage unchanged")
	eq(Apprentices.open_tasks().map(func(t): return int(t["id"])), tids, "every open task is still there")
	var e2 := Apprentices.task(int(ember["id"]))
	check(e2.has("stages") and str(e2["stages"][0]["state"]) == "done" and str(e2["stages"][0]["by"]) == str(bs["id"]), "the in-flight Emberwarden became a work order, its forging done by the blacksmith")
	check(int(e2.get("uid", 0)) > 0, "…with its piece's uid reserved")
	eq(JSON.stringify(e2["taken"]), taken, "…and its materials in hand")
	var uid := int(e2["uid"])
	_old_save_checks("schema-4 workshop", ["station instances and work orders"])
	e2 = Apprentices.task(int(ember["id"]))
	check(str(e2.get("state", "")) in FIN or WorkOrders.stage_index(e2) > 0, "the work went on (%s)" % e2.get("state", ""))
	if str(e2.get("state", "")) == "done":
		var it := ItemRegistry.find(uid)
		check(not it.is_empty() and str(Provenance.maker(it).get("id", "")) == str(bs["id"]), "the finished Emberwarden carries the reserved uid; the blacksmith is its maker")
