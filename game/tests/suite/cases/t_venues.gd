## UX iteration — the WORLD worker: Venues (one source of opening hours for keepers, map and prompts), Pell's
## Provisions as a real counter (stock, price, daily restock, save/load), closed counters, the map card,
## quick-travel labels, and the interaction prompts for a station, a shop and a person.
extends SuiteCase

const SMOKE := ["test_status_and_card", "test_general_store", "test_prompts"]


func _world() -> VillageWorld:
	var root := (Engine.get_main_loop() as SceneTree).root
	var host: Node = root.get_child(root.get_child_count() - 1)
	var w := VillageWorld.new()
	host.add_child(w)
	return w


func _entry(w: VillageWorld, kind: String, id: String) -> Dictionary:
	for e in w.interactables:
		if e["kind"] == kind and str(e["id"]) == id:
			return e
	return {}


func _at(h: int) -> void:
	Game.state["minute"] = h * 60


## Every keeper stands at their counter exactly when Venues says the shop is open (sampled every hour).
func test_hours_match_keepers() -> void:
	var w := _world()
	Commerce.dev_force_caravan()   # the caravan's master only keeps hours while the wagons are in
	Game.state["customers"] = []
	Game.state["world"]["delivery_pending"] = false
	for v in Venues.all():
		var keeper := str(v["keeper"])
		var vid := str(v["id"])
		if keeper == "" or not w.spots.has(str(v["spot"])) or not w.npcs.has(keeper):
			note("skipped %s (keeper %s not in this world)" % [vid, keeper])
			continue
		var bad := []
		for h in 24:
			_at(h)
			var spot := w.spot_for(keeper)
			var at_counter := spot == str(v["spot"]) or (vid == "rival_smith" and spot == "rival_smith_forge")
			if at_counter != Venues.is_open(vid, h):
				bad.append("%d:00 %s open=%s" % [h, spot, Venues.is_open(vid, h)])
		check(bad.is_empty(), "%s: the keeper (%s) is at the counter exactly in opening hours %s" % [vid, keeper, bad])
	# Aldric's weekly delivery: away at the forge door, and the shop says so
	Game.state["world"]["delivery_pending"] = true
	_at(10)
	eq(w.spot_for("aldric"), "smithy_door_out", "Aldric carries the delivery to the forge")
	check(not Venues.is_open("general_store", 10), "the shop is shut while he delivers")
	check(Venues.status_text("general_store", 10).begins_with("Away"), "and its status says he is away (%s)" % Venues.status_text("general_store", 10))
	Game.state["world"]["delivery_pending"] = false
	w.free()


func test_status_and_card() -> void:
	eq(Venues.status_text("general_store", 12), "Open until 19:00", "open status")
	eq(Venues.status_text("general_store", 21), "Closed — opens 7:00", "closed status")
	eq(Venues.status_text("herbalist", 5), "Closed — opens 8:00", "the herbalist before dawn")
	eq(Venues.status_text("inn", 20), "Open until midnight", "the inn keeps late hours")
	eq(Venues.hours_text("general_store"), "7:00–19:00", "hours text")
	Commerce.st()["caravan"] = {}
	check(Venues.status_text("caravan", 12).begins_with("Away"), "the caravan on the road is away (%s)" % Venues.status_text("caravan", 12))
	check(not Venues.is_open("caravan", 12), "and closed")
	# the map card: categories from real stock, never the full inventory
	var c := Venues.card("general_store")
	eq(c["name"], "Pell's Provisions", "card name")
	eq(c["type"], "General store", "card business type")
	check(bool(c["interface"]), "Pell's has a purchasing counter")
	eq(c["travel"], "provisions", "Pell's quick-travel destination")
	for cat in ["Ore & metal", "Coal & fuel", "Hides & leather", "Thread & fibre"]:
		check((c["categories"] as Array).has(cat), "Pell's deals in %s" % cat)
	check(not (c["categories"] as Array).has("Iron Ore"), "categories, not item names")
	check(not bool(Venues.card("inn")["interface"]), "the inn has no purchasing counter (talk to Hilde)")
	check(Venues.categories("herbalist").has("Herbs") and Venues.categories("herbalist").has("Reagents"), "the herbalist's categories")
	check(Venues.categories("creatures").has("Companion creatures"), "the Hales deal in creatures")
	# who sells what (the guidance worker asks this)
	check(Venues.selling_ids("coal").has("general_store"), "coal is sold at Pell's")
	check(Venues.selling_ids("leather_cured").has("general_store"), "cured leather is sold at Pell's")
	check(Venues.selling_ids("herb_emberleaf").has("herbalist"), "emberleaf at the herbalist")
	var s: Array = Venues.selling("ore_iron")
	check(not s.is_empty() and int(s[0]["price"]) > 0 and str(s[0]["note"]) != "", "selling() gives price and a note (%s)" % [s])
	# the map opens on a venue
	var mp := MapPanel.new({"venue": "general_store"})
	eq(mp.selected, "general_store", "the map opens with the requested shop selected")
	mp.free()
	var mp2 := MapPanel.new({"venue": "nowhere"})
	eq(mp2.selected, "", "an unknown venue selects nothing")
	mp2.free()


func test_general_store() -> void:
	Game.state["gold"] = 500
	var stock := Trade.store_stock("general_store")
	var defs := stock.map(func(e): return str(e["def"]))
	for d in ["ore_iron", "coal", "leather_hide", "leather_cured"]:
		check(defs.has(d), "Pell's stocks %s" % d)
	var e: Dictionary = stock[defs.find("coal")]
	var cfg_price := 0
	for row in Trade.store_cfg("general_store")["stock"]:
		if str(row[0]) == "coal":
			cfg_price = maxi(1, int(round(float(row[1]) * Trade.price_factor())))
			check(int(e["qty"]) >= int(row[2][0]) and int(e["qty"]) <= int(row[2][1]), "daily quantity within its range")
	eq(int(e["price"]), cfg_price, "price from the data with the difficulty factor")
	var g0 := Game.gold()
	var c0 := Game.count("coal")
	var q0 := int(e["qty"])
	eq(Trade.buy_store("general_store", "coal", 2), "", "buy two sacks of coal")
	eq(Game.gold(), g0 - 2 * cfg_price, "paid the price")
	eq(Game.count("coal"), c0 + 2, "coal in the stores")
	eq(int(e["qty"]), q0 - 2, "fewer left on the counter")
	# more than is left: capped; then sold out
	Trade.buy_store("general_store", "coal", 99)
	eq(int(e["qty"]), 0, "buying more than is left takes what is left")
	eq(Trade.buy_store("general_store", "coal", 1), "Sold out until tomorrow.", "sold out")
	Game.state["gold"] = 0
	check(Trade.buy_store("general_store", "ore_iron", 1).begins_with("You cannot afford"), "no money, no ore")
	check(Trade.buy_store("general_store", "dragon_scale", 1) != "", "Pell's does not sell dragon scales")
	# survives save/load the same day
	var left_iron := int(Trade.store_stock("general_store")[defs.find("ore_iron")]["qty"])
	check(save_load("suite_venues_store"), "save/load")
	eq(int(Trade.store_stock("general_store")[defs.find("ore_iron")]["qty"]), left_iron, "today's stock survives save/load")
	eq(int(Trade.store_stock("general_store")[defs.find("coal")]["qty"]), 0, "and what was bought stays bought")
	# a new morning restocks
	days(1)
	var coal2: Dictionary = Trade.store_stock("general_store")[defs.find("coal")]
	check(int(coal2["qty"]) > 0, "restocked the next morning (%d coal)" % int(coal2["qty"]))
	eq(int(Game.state["trade"]["stores"]["general_store"]["day"]), Game.day(), "stock dated today")
	# the herbalist still works through the generalised counter
	Game.state["gold"] = 500
	eq(Trade.buy_herbalist("herb_emberleaf", 1), "", "the herbalist still sells")
	# an old save without the new key
	Game.state["trade"].erase("stores")
	check(not Trade.store_stock("general_store").is_empty(), "an old save gains Pell's stock lazily")


func test_closed_counter() -> void:
	var w := _world()
	var opened := []
	var cb := func(id: String, _args: Dictionary): opened.append(id)
	Events.open_panel.connect(cb)
	var e := _entry(w, "store", "general_store")
	check(not e.is_empty(), "Pell's counter stands in the grocery")
	if not e.is_empty():
		check(w.room_at("grocery", e["pos"]) == "g_shop", "the counter is in the shop room")
		_at(22)
		w.interact(e)
		check(not opened.has("store"), "a closed counter does not open the purchasing screen")
		_at(10)
		w.interact(e)
		check(opened.has("store"), "an open counter does")
	var hb := _entry(w, "herbalist", "herbalist")
	if not hb.is_empty():
		opened.clear()
		_at(3)
		w.interact(hb)
		check(not opened.has("herbalist"), "the herbalist's counter is closed at 3:00")
	Events.open_panel.disconnect(cb)
	w.free()


func test_travel_labels() -> void:
	var w := _world()
	var nav := PlayerNav.of(w)
	if nav == null and w.player != null:
		nav = PlayerNav.new()
		w.add_child(nav)
		nav.setup(w, w.player)
	check(nav != null, "the village has a navigator")
	var ids := {}
	if nav != null:
		for d in nav.destinations():
			ids[d["id"]] = d
			check(not str(d["desc"]).contains("stalls"), "%s: no promise of market stalls" % d["id"])
	for v in Venues.all():
		if bool(v["interface"]) and str(v["travel"]) != "":
			check(PlayerNav.DESTINATIONS.any(func(x): return x[0] == v["travel"]), "%s has a quick-travel destination (%s)" % [v["id"], v["travel"]])
			if nav != null:
				check(ids.has(str(v["travel"])), "%s: its destination exists in the village" % v["id"])
	if nav != null and ids.has("provisions"):
		eq(ids["provisions"]["name"], "Pell's Provisions", "the destination is named for the shop")
		eq(ids["provisions"]["venue"], "general_store", "and knows its venue")
		check(str(ids["provisions"]["status"]) != "", "and its status")
	w.free()


func test_prompts() -> void:
	Game.state["customers"] = []
	# a station
	var p := WorldPrompts.for_entity({"kind": "station", "id": "anvil"})
	eq(p["title"], DB.station("anvil")["name"], "station prompt title")
	check((p["actions"] as Array).has("Reforge") and (p["actions"] as Array).size() <= WorldPrompts.MAX_ACTIONS, "the anvil offers reforging (%s)" % [p["actions"]])
	check((p["actions"] as Array).any(func(a): return str(a).begins_with("Craft (") or a == "Designs"), "and crafting")
	check(WorldPrompts.line(p).contains("[E] "), "the line names the key (%s)" % WorldPrompts.line(p))
	var locked := ""
	for st in DB.stations.values():
		if Crafting.station_locked_reason(str(st["id"])) != "":
			locked = str(st["id"])
			break
	if locked != "":
		var lp := WorldPrompts.for_entity({"kind": "station", "id": locked})
		check(str((lp["off"] as Array)[0]).begins_with("Locked — "), "a locked station says why (%s)" % [lp["off"]])
	# a shop, open and closed
	_at(10)
	var sp := WorldPrompts.for_entity({"kind": "store", "id": "general_store"})
	eq(sp["actions"], ["Buy"], "Pell's offers Buy")
	check(WorldPrompts.line(sp).contains("[E] Buy (open until 19:00)"), "open shop line: %s" % WorldPrompts.line(sp))
	_at(22)
	var cp := WorldPrompts.for_entity({"kind": "store", "id": "general_store"})
	check((cp["actions"] as Array).is_empty() and not bool(cp["open"]), "closed shop: no actions")
	check(WorldPrompts.line(cp).contains("Closed — opens 7:00") and not WorldPrompts.line(cp).contains("[E]"), "closed shop line: %s" % WorldPrompts.line(cp))
	# a person: Aldric by day and by night
	_at(10)
	var ap := WorldPrompts.for_entity({"kind": "npc", "id": "aldric"})
	check((ap["actions"] as Array).has("Talk") and (ap["actions"] as Array).has("Buy"), "Aldric: Talk · Buy (%s)" % [ap["actions"]])
	_at(20)
	var an := WorldPrompts.for_entity({"kind": "npc", "id": "aldric"})
	check(not (an["actions"] as Array).has("Buy"), "no Buy when the shop is shut")
	check((an["off"] as Array).any(func(o): return str(o).begins_with("Buy — the shop is closed")), "greyed with the reason (%s)" % [an["off"]])
	var opts := Talk.options("aldric", "village")
	var so: Array = opts.filter(func(o): return o["id"] == "shop_counter")
	check(so.size() == 1 and str(so[0].get("disabled", "")) != "", "the dialogue shows the counter option disabled with a reason")
	# an adventurer: offer gear needs gear
	var adv := ""
	for a in Adv.all().values():
		if str(a["status"]) in ["in_town", "injured"]:
			adv = str(a["id"])
			break
	if adv == "":
		note("no adventurer in town for the gear check")
		return
	for it in Game.inventory().duplicate():
		if Items.is_equipment(it):
			Game.take_uid(int(it["uid"]))
	var np := WorldPrompts.for_entity({"kind": "npc", "id": adv})
	check((np["off"] as Array).any(func(o): return str(o).begins_with("Offer gear — ")), "no gear: Offer gear greyed (%s)" % [np["off"]])
	give("sword_iron")
	var np2 := WorldPrompts.for_entity({"kind": "npc", "id": adv})
	check((np2["actions"] as Array).has("Offer gear"), "with a sword in the stores: Offer gear (%s)" % [np2["actions"]])
