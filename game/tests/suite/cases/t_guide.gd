## UX iteration — the Guide (acquisition & crafting guidance), purchasable knowledge and the encyclopedia.
## Raw Hide → Cured Leather → Iron Longsword explained from start to finish (tree, states, the next step changing
## as the smith acquires things), every source the Guide lists is real (buying or crafting through it works), every
## recipe input in the visible game has a source, secrets stay hidden, bought knowledge persists and is listed,
## readiness states, recursion terminates for every recipe, an old save loads. Rendered: playtest.tscn -- guide_ux
extends SuiteCase

const SMOKE := ["test_longsword_chain", "test_secrecy", "test_knowledge_persists"]


func _at_hour(h: int) -> void:
	var mins: int = (h * 60 - int(Game.state["minute"]) % 1440 + 1440) % 1440
	Game.advance_minutes(mins)


func _kinds(def: String) -> Array:
	return Guide.sources(def).map(func(s): return "%s/%s/%s" % [s["kind"], s["id"], s["state"]])


func _install(sid: String) -> bool:
	if not Property.is_owned_station(sid):
		Game.add_gold(Property.station_price(sid), "sales", "test income")
		if Property.buy_station(sid) != "":
			return false
	var plan := Property.plan_copy()
	if Property.auto_place(plan, sid) == "" and Property.commit(plan) == "":
		return Property.is_installed(sid)
	Property.dev_grant_all()
	plan = Property.plan_copy()
	return Property.auto_place(plan, sid) == "" and Property.commit(plan) == "" and Property.is_installed(sid)


# ------------------------------------------------------------------ the chain, fully explained
func test_longsword_chain() -> void:
	fresh_game()
	_at_hour(10)
	Game.remove_def("leather_cured", Game.count("leather_cured"))
	var rs := Guide.recipe_status("iron_longsword")
	eq(str(rs["state"]), "missing", "an Iron Longsword without cured leather is missing materials")
	eq(int(rs["missing"].get("leather_cured", 0)), 1, "it lacks exactly 1 Cured Leather")
	eq(Guide.status("leather_cured"), "obtainable", "cured leather is obtainable")
	eq(Guide.status("ore_iron"), "have", "iron ore is in the stores")
	# the dependency tree: Longsword → Cured Leather (intermediate) → Cure Leather → Raw Hide + Leather Vat
	var t := Guide.tree("recipe:iron_longsword")
	eq(str(t["type"]), "recipe", "the tree starts at the recipe")
	var leather: Dictionary = {}
	for c in t["children"]:
		if str(c["id"]) == "leather_cured":
			leather = c
	check(not leather.is_empty() and bool(leather["intermediate"]), "cured leather is an intermediate material in the tree")
	var cure: Dictionary = leather["children"][0] if not leather.is_empty() and not (leather["children"] as Array).is_empty() else {}
	eq(str(cure.get("id", "")), "cure_leather", "it is made by Cure Leather")
	var kids: Array = cure.get("children", []).map(func(c): return "%s:%s:%s" % [c["type"], c["id"], c["state"]])
	check(kids.has("item:leather_hide:have"), "Cure Leather needs Raw Hide (held) — %s" % str(kids))
	check(kids.has("station:leather_vat:locked"), "Cure Leather needs the Leather Vat (not yet in the workshop) — %s" % str(kids))
	eq(str(cure.get("state", "")), "locked", "Cure Leather is locked while there is no vat")
	# shop open: buy the leather at Pell's
	var ns := Guide.next_step("recipe:iron_longsword")
	check(str(ns["text"]).contains("Cured Leather") and str(ns["text"]).contains("Pell's Provisions") and str(ns["text"]).contains("open now"),
		"next step by day: buy at Pell's (%s)" % ns["text"])
	eq(str(ns["action"].get("route", "")), "map", "the action shows the shop on the map")
	eq(str(ns["action"].get("args", {}).get("venue", "")), "general_store", "…Pell's Provisions")
	# at night the shop is shut: still the cheapest reliable way, opening tomorrow
	_at_hour(22)
	ns = Guide.next_step("recipe:iron_longsword")
	check(str(ns["text"]).contains("opens tomorrow"), "next step at night says when Pell's opens (%s)" % ns["text"])
	var alts := Guide.alternatives("recipe:iron_longsword")
	check(alts.size() >= 2, "there are alternatives (%d)" % alts.size())
	# a vat bought but not set up
	Game.add_gold(Property.station_price("leather_vat"), "sales", "test income")
	eq(Property.buy_station("leather_vat"), "", "the vat is bought")
	var vs := Guide.next_step("recipe:cure_leather")
	check(str(vs["text"]).begins_with("Set up"), "a stored vat: the next step is to set it up (%s)" % vs["text"])
	eq(str(vs["action"].get("route", "")), "property", "…in Property & Workshop")
	check(_install("leather_vat"), "the vat is placed in the workshop")
	# now curing is possible right away and beats waiting for the shop
	ns = Guide.next_step("recipe:iron_longsword")
	check(str(ns["text"]).contains("Cure Leather"), "at night with a vat: cure leather now (%s)" % ns["text"])
	var leather_item := craft("cure_leather")
	check(not leather_item.is_empty(), "curing leather through the guided recipe works")
	eq(Guide.status("leather_cured"), "have", "cured leather is now in the stores")
	eq(str(Guide.recipe_status("iron_longsword")["state"]), "ready", "the longsword is ready")
	check(str(Guide.next_step("recipe:iron_longsword")["text"]).begins_with("Everything is ready"), "the next step is to begin the sword")
	check(not craft("iron_longsword").is_empty(), "and the sword can be forged")


# ------------------------------------------------------------------ every source is real
func test_sources_are_real() -> void:
	fresh_game()
	_at_hour(10)
	Game.add_gold(2000, "sales", "test income")
	# the herbalist
	var herb: Array = Guide.sources("herb_bloodroot").filter(func(s): return s["kind"] == "vendor" and s["id"] == "herbalist")
	check(not herb.is_empty() and str(herb[0]["state"]) == "ready", "the herbalist sells bloodroot, open now")
	var c0 := Game.count("herb_bloodroot")
	eq(Trade.buy_herbalist("herb_bloodroot", 1), "", "buying it there works")
	eq(Game.count("herb_bloodroot"), c0 + 1, "…and it is in the stores")
	if not herb.is_empty():
		eq(int(herb[0]["price"]), int(Trade.herbalist_stock().filter(func(e): return e["def"] == "herb_bloodroot")[0]["price"]), "the listed price is the shop's price")
	# a docked ship
	Trade.dev_force_ship("whaler")
	var in_port := ""
	for e in Trade.current_ship()["stock"]:
		if str(e.get("def", "")) != "" and not e.has("item") and int(e.get("qty", 0)) > 0:
			in_port = str(e["def"])
			break
	check(in_port != "", "the whaler carries materials")
	if in_port != "":
		var sh: Array = Guide.sources(in_port).filter(func(s): return s["kind"] == "ship" and s["state"] == "ready")
		check(not sh.is_empty(), "the Guide lists %s as in port now" % in_port)
		var idx := -1
		var stock: Array = Trade.current_ship()["stock"]
		for i in stock.size():
			if str(stock[i].get("def", "")) == in_port and not stock[i].has("item"):
				idx = i
		var b0 := Game.count(in_port)
		eq(Trade.buy_from_ship(idx, 1), "", "buying it from the ship works")
		eq(Game.count(in_port), b0 + 1, "…and it is in the stores")
	# a special import
	var imp: Array = Guide.sources("leather_cured").filter(func(s): return s["kind"] == "import")
	check(not imp.is_empty() and str(imp[0]["state"]) == "obtainable", "cured leather can be imported")
	eq(Trade.place_import("leather_cured", 1), "", "ordering the import works")
	# crafting
	var cr: Array = Guide.sources("ingot_iron").filter(func(s): return s["kind"] == "craft")
	check(not cr.is_empty() and str(cr[0]["state"]) == "ready", "iron ingots can be smelted now")
	var i0 := Game.count("ingot_iron")
	check(not craft(str(cr[0]["id"])).is_empty() and Game.count("ingot_iron") > i0, "smelting through the listed recipe works")
	# a trade run and an expedition name real things
	for s in Guide.sources("leather_hide"):
		match str(s["kind"]):
			"trade_run":
				check(Regions.supply_list().any(func(e): return str(e[0]) == "leather_hide"), "the village trade run really buys raw hide")
			"expedition":
				check(DB.destinations.has(str(s["id"])), "expedition %s exists" % s["id"])
	# Pell's Provisions: the listed vendor really sells it
	var pell: Array = Guide.sources("leather_hide").filter(func(s): return s["kind"] == "vendor" and s["id"] == "general_store")
	check(not pell.is_empty(), "Pell's Provisions is listed for raw hide")
	var h0 := Game.count("leather_hide")
	eq(Trade.buy_store("general_store", "leather_hide", 1), "", "buying raw hide at Pell's Provisions works")
	eq(Game.count("leather_hide"), h0 + 1, "…and the hide is in the stores")
	check(Venues.selling_ids("leather_hide").has("general_store"), "Venues agrees that Pell's sells it")


# ------------------------------------------------------------------ coverage
func test_every_input_has_a_source() -> void:
	fresh_game()
	var none := []
	for r in DB.recipes.values():
		if not Reference.recipe_visible(str(r["id"])):
			continue
		for d in r["inputs"]:
			if Guide.sources(str(d)).is_empty() and not none.has(str(d)):
				none.append(str(d))
	note("inputs without any listed source in a new game: %s" % str(none))
	# with the whole tree learned and every route known, nothing may be without a source
	SkillTree.unlock_all()
	for f in ["delve_map", "site_ravens_hold", "site_sunken_temple", "site_drakes_crag", "supplier_herbalist", "supplier_highmarsh", "recipe_starsteel"]:
		Game.set_flag(f)
	var missing := []
	for r in DB.recipes.values():
		for d in r["inputs"]:
			if Guide.sources(str(d)).is_empty() and not missing.has(str(d)):
				missing.append(str(d))
	check(missing.is_empty(), "every recipe input has a source once known: missing %s" % str(missing))


# ------------------------------------------------------------------ secrecy
func test_secrecy() -> void:
	fresh_game()
	var secret := ""
	for r in DB.recipes.values():
		if str(r.get("requires_flag", "")) != "":
			secret = str(r["id"])
	check(secret != "", "the data has a forgotten recipe")
	var flag := str(DB.recipe(secret)["requires_flag"])
	var out := str(DB.recipe(secret)["output"])
	eq(str(Guide.recipe_status(secret)["state"]), "hidden", "a forgotten recipe is hidden")
	check(not Reference.topic_visible("recipe:" + secret), "its encyclopedia page cannot be opened")
	check(not Guide.sources(out).any(func(s): return s["kind"] == "craft" and s["id"] == secret), "its output does not reveal the recipe")
	eq(str(Guide.next_step("recipe:" + secret)["text"]), "", "no next step for an unknown recipe")
	check(not Reference.tab_entries("recipes").any(func(e): return str(e.get("topic", "")) == "recipe:" + secret), "it is not in Help › Recipes")
	# gated routes and exotic imports stay secret
	check(not Guide.sources("ore_adamantine").any(func(s): return s["kind"] == "expedition" and s["id"] == "deep_ironroot"), "Deep Ironroot is not listed before the map is found")
	check(not Guide.sources("ore_orichalcum").any(func(s): return s["kind"] == "import"), "orichalcum cannot be ordered before the smith has heard of it")
	# learning the secret the real way reveals it
	Game.set_flag(flag)
	check(Reference.topic_visible("recipe:" + secret), "after the discovery the recipe has its page")
	check(Guide.sources(out).any(func(s): return s["kind"] == "craft" and s["id"] == secret), "…and is listed as a way to make its output")
	Game.set_flag("delve_map")
	check(Guide.sources("ore_adamantine").any(func(s): return s["kind"] == "expedition" and s["id"] == "deep_ironroot"), "with the map, Deep Ironroot is listed")


# ------------------------------------------------------------------ knowledge
func test_knowledge_persists() -> void:
	fresh_game()
	Game.add_gold(500, "sales", "test income")
	var offers := Knowledge.offers("pawnbroker")
	check(offers.size() >= 2, "Quell sells old notes (%d)" % offers.size())
	check(offers.all(func(o): return str(o["text"]) == ""), "the full text is not shown before buying")
	var g0 := Game.gold()
	eq(Knowledge.buy("hint_forgotten_recipes"), "", "a hint is bought")
	check(Game.gold() < g0, "it costs gold")
	check(not Game.has_flag("recipe_starsteel"), "a hint does not grant the discovery itself")
	eq(Knowledge.buy("hint_forgotten_recipes"), "You already know it.", "it cannot be bought twice")
	# complete knowledge: the exotic cargo manifests make exotic imports orderable
	eq(Knowledge.buy("know_exotic_cargo"), "", "the cargo manifests are bought")
	check(Trade.knows("ore_orichalcum"), "the smith now knows of orichalcum")
	check(Guide.sources("ore_orichalcum").any(func(s): return s["kind"] == "import" and s["state"] == "obtainable"), "…and can order it at the harbour")
	check(save_load("suite_guide_k"), "save/load")
	check(Knowledge.owned("hint_forgotten_recipes") and Knowledge.owned("know_exotic_cargo"), "bought knowledge persists through save/load")
	var titles: Array = Reference.tab_entries("knowledge").map(func(e): return str(e["title"]))
	check(titles.has("Old notes: forgotten recipes"), "the hint is in Help › Knowledge (%s)" % str(titles))
	check(Knowledge.offers("pawnbroker").any(func(o): return bool(o["bought"]) and str(o["text"]) != ""), "Quell's counter shows it as known, with its text")
	eq(Knowledge.buy("nonsense"), "Nobody sells that.", "unknown offers are refused")


# ------------------------------------------------------------------ states
func test_readiness_states() -> void:
	fresh_game()
	eq(Guide.status("ore_iron"), "have", "have")
	Game.remove_def("leather_cured", Game.count("leather_cured"))
	eq(Guide.status("leather_cured"), "obtainable", "obtainable")
	var locked := ""
	var unavailable := ""
	for d in DB.items:
		var st := Guide.status(str(d))
		if st == "locked" and locked == "":
			locked = str(d)
		if st == "unavailable" and unavailable == "" and Reference.item_visible(str(d)):
			unavailable = str(d)
	check(locked != "", "some item is locked behind a public obstacle (%s)" % locked)
	if locked != "":
		check(Guide.sources(locked).all(func(s): return str(s["state"]) in ["locked", "unavailable"]), "…and all its sources say why")
		check(Guide.sources(locked).all(func(s): return str(s["why"]) != ""), "every locked source has a reason")
	note("first locked item: %s · first unavailable visible item: %s" % [locked, unavailable])
	eq(Guide.status("no_such_item"), "unavailable", "an item with no source is unavailable")
	# recipe states
	eq(str(Guide.recipe_status("smelt_iron")["state"]), "ready", "smelting iron is ready")
	var lk := ""
	for r in DB.recipes.values():
		if Reference.recipe_visible(str(r["id"])) and str(Guide.recipe_status(str(r["id"]))["state"]) == "locked":
			lk = str(r["id"])
			break
	check(lk != "", "some recipe is locked")
	if lk != "":
		var obs: Array = Guide.recipe_status(lk)["obstacles"]
		check(obs.any(func(o): return str(o["kind"]) in ["node", "skill", "station"]), "a locked recipe names what is in the way")
	check(Guide.tooltip_line("leather_hide").contains("Pell's Provisions") or Guide.tooltip_line("leather_hide") != "", "a material tooltip gets one source line (%s)" % Guide.tooltip_line("leather_hide"))


# ------------------------------------------------------------------ recursion
func test_recursion_terminates() -> void:
	fresh_game()
	for f in ["recipe_starsteel", "delve_map"]:
		Game.set_flag(f)
	var t0 := Time.get_ticks_msec()
	for r in DB.recipes.values():
		var rid := str(r["id"])
		var t := Guide.tree("recipe:" + rid, 6)
		var n := Guide.tree_lines(t, 0, []).size()
		check(n > 0 and n < 2000, "tree of %s is finite (%d lines)" % [rid, n])
		var ns := Guide.next_step("recipe:" + rid)
		check(str(ns.get("text", "")) != "", "%s has a next step" % rid)
	note("trees and next steps for %d recipes in %d ms" % [DB.recipes.size(), Time.get_ticks_msec() - t0])
	t0 = Time.get_ticks_msec()
	var hits := Reference.search("hide")
	note("a Help search over every tab took %d ms (%d hits)" % [Time.get_ticks_msec() - t0, hits.size()])
	for d in DB.items:
		Guide.next_step("item:" + str(d))
	check(true, "next_step terminates for every item")


# ------------------------------------------------------------------ old saves
func test_old_save_loads() -> void:
	fresh_game()
	Game.state.erase("knowledge")
	check(save_load("suite_guide_old"), "an old save (no knowledge key) loads")
	check(not Knowledge.owned("hint_rune_lore"), "nothing is owned")
	check(Knowledge.offers("harbourmaster").size() > 0, "the harbourmaster's offers are listed")
	Game.add_gold(100, "sales", "test income")
	eq(Knowledge.buy("hint_dragon_lore"), "", "knowledge can be bought on an old save")
	check(Game.state.has("knowledge") and Knowledge.owned("hint_dragon_lore"), "the knowledge key is created lazily")
	check(not Guide.sources("leather_hide").is_empty(), "the Guide works on the loaded game")
