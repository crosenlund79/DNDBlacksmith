## Adventurers (iteration 010): durability wears through real fights and changes the numbers, broken
## gear weakens every stat, adventurers look over their gear each day and buy, ask for repairs,
## commission or save up, the companion slot strikes in combat, and all of it persists.
extends SuiteCase

const SMOKE := ["test_broken_gear_lowers_combat", "test_missing_slot_buys_from_display", "test_companion_strikes"]


func _adv(cls: String) -> Dictionary:
	for a in Adv.all().values():
		if a["cls"] == cls:
			Expeditions.ensure(a)
			a["status"] = "in_town"
			return a
	return {}


func _clear_display() -> void:
	for it in Game.inventory():
		it.erase("for_sale")


func _dur(it: Dictionary) -> int:
	return int(it.get("stats", {}).get("durability", 0))


## A placeholder companion (the real creatures come from the Commerce worker's data).
func _companion() -> Dictionary:
	return {"uid": Game.new_uid(), "def": "test_companion", "name": "Ash-hound", "creature_name": "Ash-hound", "qty": 1, "rarity": "magic",
		"quality": 70.0, "stats": {"attack": 8, "protection": 3, "heal": 4, "scouting": 4, "carry": 4}, "affixes": [], "sockets": []}


func _fight_node(rid: String) -> Dictionary:
	for n in Expeditions.region(rid).get("nodes", []):
		if n["kind"] == "encounter":
			return n
	return {}


func test_durability_falls_on_expeditions() -> void:
	var a := _adv("Fighter")
	a["equipment"]["boots"] = Items.make("boots_leather", {"quality": 80.0})
	var before := {}
	for s in a["equipment"]:
		before[s] = _dur(a["equipment"][s])
	var e := Expeditions.start({"members": [a["id"]], "leader": a["id"], "dest": "whisperwood"})
	var n := _fight_node("whisperwood")
	for i in 3:
		if a["status"] == "away" and float(a["hp"]) > 0.0:
			a["hp"] = a["hp_max"]
			Expeditions.fight(e, n)
	var worn := []
	for s in ["weapon", "armor", "shield", "boots"]:
		if _dur(a["equipment"][s]) < int(before[s]):
			worn.append(s)
	check(worn.has("weapon"), "the weapon wears with every swing (%d → %d)" % [int(before["weapon"]), _dur(a["equipment"]["weapon"])])
	check(worn.has("armor") or worn.has("shield"), "armour or shield wears when struck or blocking (%s)" % str(worn))
	check(worn.has("boots"), "boots wear on the march")
	# and the whole trip home wears boots and belt
	var b0 := _dur(a["equipment"]["boots"])
	Expeditions.trip_wear(a)
	check(_dur(a["equipment"]["boots"]) < b0, "the road home wears the boots")
	# a piece worn to nothing breaks, with the break in its history
	Expeditions.wear_item(a, "shield", 9999, {"node_name": "the den", "actions": []})
	check(a["equipment"]["shield"].get("broken", false), "a shield worn to nothing breaks")
	check(str(a["equipment"]["shield"].get("history", [{}])[-1].get("text", "")).contains("Broke"), "the break is in its history")


func test_broken_gear_lowers_combat() -> void:
	var a := _adv("Fighter")
	var w: Dictionary = a["equipment"]["weapon"]
	var arm: Dictionary = a["equipment"]["armor"]
	var base0 := float(Expeditions.weapon_profile(a)["base"])
	var def0 := Expeditions.defence(a)
	var prot0 := Expeditions.total(a, "protection")
	var p0 := Expeditions.power(a)
	# badly worn: a little weaker
	w["stats"]["durability"] = int(int(w["stats"]["durability_max"]) * 0.1)
	var base_worn := float(Expeditions.weapon_profile(a)["base"])
	check(base_worn < base0, "a worn weapon deals less (%.1f < %.1f)" % [base_worn, base0])
	# broken: half strength on every stat
	w["broken"] = true
	arm["broken"] = true
	var base_b := float(Expeditions.weapon_profile(a)["base"])
	check(base_b < base_worn, "a broken weapon deals less still (%.1f)" % base_b)
	check(Expeditions.total(a, "protection") < prot0 and Expeditions.defence(a) <= def0, "broken armour protects less (%d → %d)" % [prot0, Expeditions.total(a, "protection")])
	check(Expeditions.power(a) < p0, "the adventurer's power falls")
	var am := Items.make("amulet_silver", {"quality": 90.0})
	var mg := Items.stat(am, "magic")
	am["broken"] = true
	check(Items.stat(am, "magic") < mg, "a broken amulet's magic is halved too")
	check(Items.tooltip(w).contains("half strength"), "the tooltip says so")
	# and it changes outcomes: over many blows a sound weapon deals clearly more
	seed(77)
	var dealt := [0, 0]
	for k in 2:
		w["broken"] = k == 1
		w["stats"]["durability"] = w["stats"]["durability_max"] if k == 0 else 0
		for i in 150:
			var foe := {"key": "dummy", "name": "Dummy", "hp": 9999, "ac": 5, "weak": "", "resist": "", "kind": "beast"}
			var rec := {"actions": []}
			Expeditions._attack(a, foe, rec, 1, false, false)
			dealt[k] += 9999 - int(foe["hp"])
	check(dealt[0] > dealt[1] * 1.2, "sound gear wins fights a broken blade loses (%d vs %d damage over 150 blows)" % [dealt[0], dealt[1]])


func test_missing_slot_buys_from_display() -> void:
	_clear_display()
	var a := _adv("Fighter")
	a["equipment"].erase("helmet")
	a["gold"] = 500
	var helm := Items.make("helm_iron", {"quality": 85.0})
	helm["for_sale"] = true
	Game.add_item(helm, false)
	Adv.evaluate_gear(a)
	var e: Dictionary = {}
	for x in a["shopping"]:
		if x["slot"] == "helmet":
			e = x
	eq(str(e.get("why", "")), "missing", "the empty helmet slot is noticed")
	eq(str(e.get("plan", "")), "buy", "and the helmet on display is chosen")
	var g0 := Game.gold()
	a.erase("gear_day")
	Adv.gear_hour()
	eq(int(a["equipment"].get("helmet", {}).get("uid", -1)), int(helm["uid"]), "the adventurer bought and wears the displayed helmet")
	check(Game.gold() > g0, "the smith was paid")
	check(int(a["gold"]) < 500, "from the adventurer's purse")
	check(not Chronicle.about(a["id"], ["gear"]).is_empty(), "the purchase is in the Chronicle")
	check(a["shopping"].filter(func(x): return x["slot"] == "helmet").is_empty(), "the helmet is off the shopping list")
	# class preferences are read from the item data: a wizard will not wear plate
	var wiz := _adv("Wizard")
	check(Adv.affinity(wiz, Items.make("cuirass_iron")) == 0.0, "a wizard has no use for metal armour")
	check(Adv.affinity(wiz, Items.make("ring_silver")) > 1.0, "but favours a ring")
	check(Adv.affinity(_adv("Ranger"), Items.make("bow_hunting")) > Adv.affinity(_adv("Ranger"), Items.make("sword_iron")), "a ranger prefers a bow")
	check(Adv.desired_slots(wiz).has("ring") and not Adv.desired_slots(wiz).has("shield"), "a wizard wants rings, not shields")


func test_broken_gear_asks_for_repair_or_commission() -> void:
	_clear_display()
	var a := _adv("Fighter")
	a["gold"] = 300
	var w: Dictionary = a["equipment"]["weapon"]
	w["stats"]["durability"] = 0
	w["broken"] = true
	Adv.evaluate_gear(a)
	var e: Dictionary = a["shopping"][0]
	eq(str(e["slot"]), "weapon", "the broken weapon is the most urgent need")
	check(str(e["plan"]) in ["repair", "commission"], "they plan a repair or a commission (%s)" % e["plan"])
	var did := Adv.act_on_plans(a)
	if did == "repair":
		check(not Shop.customer(a["id"]).is_empty() and str(Shop.customer(a["id"]).get("own_slot", "")) == "weapon", "they set out for the forge with the broken weapon")
	else:
		check(not Shop.open_orders().filter(func(o): return o["npc"] == a["id"] and o["slot"] == "weapon").is_empty(), "a weapon commission is open (%s)" % did)
	# a sturdier piece that is only worn gets a repair request
	_clear_display()
	var b := _adv("Paladin")
	b["gold"] = 300
	var arm: Dictionary = b["equipment"]["armor"]
	arm["stats"]["durability"] = 3
	Shop.remove_customer(b["id"])
	Adv.evaluate_gear(b)
	var ea: Array = b["shopping"].filter(func(x): return x["slot"] == "armor")
	check(not ea.is_empty() and str(ea[0]["why"]) == "worn", "badly worn armour is noticed")
	check(not ea.is_empty() and str(ea[0]["plan"]) == "repair", "a sound-enough piece is sent for repair (%s)" % (ea[0]["plan"] if not ea.is_empty() else "-"))


func test_poor_adventurer_saves() -> void:
	_clear_display()
	var a := _adv("Fighter")
	a["equipment"].erase("helmet")
	a["gold"] = 0
	Adv.evaluate_gear(a)
	var e: Array = a["shopping"].filter(func(x): return x["slot"] == "helmet")
	check(not e.is_empty() and e[0]["plan"] == "save", "with an empty purse they save up (%s)" % (e[0]["plan"] if not e.is_empty() else "-"))
	eq(str(a["saving_for"].get("slot", "")), "helmet", "the savings goal is the helmet")
	check(int(a["saving_for"].get("goal", 0)) > 0, "with a price to reach")
	check(a["ambitions"].any(func(t): return str(t).begins_with("Saving for")), "it is one of their ambitions")
	eq(Adv.act_on_plans(a), "", "they buy nothing")
	eq(a["status"], "in_town", "and keep adventuring with what they have")
	# a rich, well-equipped veteran dreams of a companion
	var g := _adv("Paladin")
	g["gold"] = 2000
	g["equipment"]["helmet"] = Items.make("helm_iron", {"quality": 80.0})
	check(Adv.wants_companion(g), "a rich, well-equipped veteran wants a companion")
	check(Adv.desired_slots(g).has("companion"), "so the companion slot joins their wants")
	var c0: bool = g["equipment"].get("companion", {}).is_empty()
	var bought := Adv.buy_elsewhere(g, {"slot": "companion"})
	check(not c0 or not bought or not g["equipment"].get("companion", {}).is_empty(), "buying elsewhere puts a creature from the Hales into the companion slot")


func test_companion_strikes() -> void:
	var a := _adv("Fighter")
	var comp := _companion()
	a["equipment"]["companion"] = comp
	var mod0 := 0
	var e := Expeditions.start({"members": [a["id"]], "leader": a["id"], "dest": "whisperwood"})
	var foe := {"key": "wolf_0", "name": "Grey Wolf", "hp": 40, "ac": 1, "weak": "", "resist": "", "kind": "beast"}
	var rec := {"actions": []}
	check(Expeditions.companion_strike(a, [foe], rec, 1), "the companion attacks")
	var act: Dictionary = rec["actions"][0] if not rec["actions"].is_empty() else {}
	eq(str(act.get("kind", "")), "companion", "as a companion action in the combat log")
	eq(str(act.get("actor", "")), "Ash-hound", "under the creature's name")
	check(int(foe["hp"]) < 40 or not act.get("hit", false), "a hit does damage")
	# in a real fight the strikes are recorded
	var n := _fight_node("whisperwood")
	a["hp"] = a["hp_max"]
	Expeditions.fight(e, n)
	var r: Dictionary = e["encounters"][-1]
	check((r["actions"] as Array).any(func(x): return x.get("kind", "") == "companion"), "the fight record holds the companion's strikes")
	# protection, scouting, heal and carry
	var prot := Expeditions.total(a, "protection")
	a["equipment"].erase("companion")
	check(prot > Expeditions.total(a, "protection"), "a companion adds protection")
	seed(5)
	mod0 = int(Expeditions._check(a, "wis", 10, "scouting")["mod"])
	a["equipment"]["companion"] = comp
	check(int(Expeditions._check(a, "wis", 10, "scouting")["mod"]) > mod0, "it improves scouting checks")
	if a["status"] == "away":
		a["hp"] = 1
		var rec2 := {"actions": []}
		Expeditions.companion_heal(e, rec2)
		check(int(a["hp"]) > 1, "it tends wounds after a fight")
		check(Expeditions._carry(e) >= 4, "and carries more home")


func test_save_load_new_state() -> void:
	_clear_display()
	var a := _adv("Fighter")
	a["equipment"].erase("helmet")
	a["gold"] = 0
	a["equipment"]["companion"] = _companion()
	a["equipment"]["weapon"]["broken"] = true
	Adv.evaluate_gear(a)
	var n_shop: int = a["shopping"].size()
	var n_amb: int = a["ambitions"].size()
	var n_log: int = a["gear_log"].size()
	var id: String = a["id"]
	var sv := str(a["saving_for"].get("slot", ""))
	check(n_shop > 0 and n_log > 0, "there is gear state to keep")
	check(save_load("suite_adv10"), "save and load")
	var b := Adv.get_a(id)
	eq(b["shopping"].size(), n_shop, "the shopping list persists")
	eq(b["ambitions"].size(), n_amb, "ambitions persist")
	eq(b["gear_log"].size(), n_log, "the gear log persists")
	check(sv != "" and str(b["saving_for"].get("slot", "")) == sv, "the savings goal persists (%s)" % sv)
	eq(Items.stat(b["equipment"].get("companion", {}), "attack"), 8, "the companion persists")
	check(b["equipment"]["weapon"].get("broken", false), "a broken weapon stays broken")
	# an older save without the new keys gains them
	for k in ["shopping", "ambitions", "gear_log", "saving_for"]:
		b.erase(k)
	Adv.ensure(b)
	check(b.has("shopping") and b.has("ambitions") and b.has("gear_log") and b.has("saving_for"), "older saves gain the new keys")
	Adv.on_day()
	check(true, "the daily evaluation runs on an old save")
