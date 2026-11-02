## Adv — autonomous adventurers living at the inn and pursuing their own careers.
## EN: Each adventurer has a class, level, gold, equipment and a cycle: rest in town → depart at
##     dawn through a village exit → simulated expedition → return (or not). Survival and success
##     depend on level and on the equipment they carry — much of which the smith may have made.
## DA: Hver eventyrer har klasse, niveau, guld, udstyr og en cyklus: hvile i byen → afrejse ved
##     daggry gennem en udgang → simuleret ekspedition → hjemkomst (eller ej). Overlevelse og succes
##     afhænger af niveau og af det udstyr, de bærer — som smeden måske selv har lavet.
class_name Adv
extends RefCounted

const START_GEAR := {
	"Ranger": {"weapon": ["dagger", 50], "armor": ["jerkin_leather", 52]},
	"Fighter": {"weapon": ["sword_iron", 60], "armor": ["chainmail", 58], "shield": ["shield_round", 55]},
	"Wizard": {"weapon": ["dagger", 45], "amulet": ["amulet_silver", 60]},
	"Rogue": {"weapon": ["dagger", 62], "armor": ["jerkin_leather", 50]},
	"Paladin": {"weapon": ["mace_flanged", 66], "armor": ["cuirass_iron", 64], "shield": ["shield_kite", 60]},
	"Cleric": {"weapon": ["mace_flanged", 48], "armor": ["jerkin_leather", 46]},
	"Barbarian": {"weapon": ["axe_hand", 44], "armor": ["jerkin_leather", 40]},
	"Bard": {"weapon": ["dagger", 50]},
}
const CLASS_WANTS := {
	"Ranger": ["weapon", "armor", "boots", "gloves"], "Fighter": ["weapon", "armor", "shield", "helmet"],
	"Wizard": ["amulet", "ring", "boots"], "Rogue": ["weapon", "gloves", "boots", "armor"],
	"Paladin": ["weapon", "armor", "shield", "helmet"], "Cleric": ["armor", "weapon", "amulet"],
	"Barbarian": ["weapon", "armor", "belt"], "Bard": ["weapon", "ring", "boots"],
}


static func all() -> Dictionary:
	return Game.state["adventurers"]


static func get_a(id: String) -> Dictionary:
	return all().get(id, {})


static func init_population() -> void:
	for id in DB.characters:
		var c: Dictionary = DB.characters[id]
		if c.get("kind") != "adventurer":
			continue
		var eq := {}
		for slot in START_GEAR.get(c["cls"], {}):
			var g: Array = START_GEAR[c["cls"]][slot]
			eq[slot] = Items.make(g[0], {"quality": float(g[1])})
		all()[id] = {"id": id, "name": c["name"], "cls": c["cls"], "level": int(c.get("level", 1)), "xp": 0,
			"gold": int(c.get("gold", 50)), "equipment": eq, "loot": [], "status": "in_town", "dest": "",
			"days_left": 0, "depart_day": Game.day() + randi_range(1, 3), "injured_days": 0,
			"expeditions": 0, "victories": 0, "last_report": "", "exit": "", "needs": ""}
	# Mira leaves on day 3 for the Barrow Fields — the grocer's story hangs on it
	if all().has("mira"):
		all()["mira"]["depart_day"] = 3
		all()["mira"]["planned_dest"] = "barrow_fields"
	if all().has("sigrun"):
		all()["sigrun"]["depart_day"] = 2


static func gear_score(a: Dictionary) -> float:
	var s := 0.0
	for k in a.get("equipment", {}):
		s += Items.score(a["equipment"][k])
	return s


static func power(a: Dictionary) -> float:
	return int(a["level"]) * 9.0 + gear_score(a)


## Rough, player-facing estimate (no hidden numbers revealed exactly).
static func rating_text(a: Dictionary) -> String:
	var p := power(a)
	if p < 50:
		return "Green"
	if p < 80:
		return "Capable"
	if p < 115:
		return "Seasoned"
	if p < 160:
		return "Formidable"
	return "Legendary"


static func in_town() -> Array:
	return all().values().filter(func(a): return a["status"] == "in_town")


static func choose_dest(a: Dictionary) -> String:
	if a.has("planned_dest"):
		var p: String = a["planned_dest"]
		a.erase("planned_dest")
		return p
	var lvl := int(a["level"])
	var options := ["whisperwood", "highmarsh_road", "ironroot_mine"]
	if lvl >= 3:
		options.append("barrow_fields")
	if lvl >= 4:
		options.append("barrow_fields")
	if lvl >= 6 and Game.has_flag("delve_map"):
		options.append("deep_ironroot")
	return options.pick_random()


## Called each morning at 7:00.
static func morning_departures() -> void:
	for a in all().values():
		if a["status"] != "in_town" or Game.day() < int(a["depart_day"]):
			continue
		var dest := choose_dest(a)
		var d: Dictionary = DB.destinations[dest]
		a["status"] = "away"
		a["dest"] = dest
		a["exit"] = d["exit"]
		a["days_left"] = randi_range(int(d["days"][0]), int(d["days"][1]))
		Game.journal("%s the %s set out for %s." % [a["name"], a["cls"], d["name"]])
		Events.adventurer_departed.emit(a["id"], d["exit"])
	Events.adventurers_changed.emit()


static func on_day() -> void:
	for a in all().values():
		match a["status"]:
			"away":
				a["days_left"] = int(a["days_left"]) - 1
				if int(a["days_left"]) <= 0:
					_resolve(a)
			"injured":
				a["injured_days"] = int(a["injured_days"]) - 1
				if int(a["injured_days"]) <= 0:
					a["status"] = "in_town"
					a["depart_day"] = Game.day() + randi_range(1, 2)
	Events.adventurers_changed.emit()


static func _crafted_by_player(a: Dictionary) -> Array:
	var out := []
	for k in a["equipment"]:
		var it: Dictionary = a["equipment"][k]
		if str(it.get("crafted_by", "")).begins_with("Brannoc"):
			out.append(it)
	return out


static func _resolve(a: Dictionary) -> void:
	var d: Dictionary = DB.destinations[a["dest"]]
	var danger := float(d["danger"])
	var ratio := power(a) / (danger * 16.0 + 30.0)
	var success := randf() < clampf(0.3 + 0.45 * ratio, 0.08, 0.96)
	var injured := randf() < clampf(0.38 - 0.24 * ratio, 0.03, 0.6)
	var dies := (not success) and randf() < clampf(danger * 0.04 - ratio * 0.05, 0.0, 0.3)
	var mine := _crafted_by_player(a)
	var spouse: bool = Social.spouse() == a["id"]
	a["expeditions"] = int(a["expeditions"]) + 1
	if dies:
		_die(a, d, mine)
		return
	var gold := int(danger * randf_range(14, 36) * (1.0 if success else 0.35))
	var xp := int(danger * 30 * (1.0 if success else 0.4))
	a["gold"] = int(a["gold"]) + gold
	a["xp"] = int(a["xp"]) + xp
	var loot := Loot.roll_table(d["loot"], float(a["level"]) * 2.0) if success else []
	# wear and tear
	for k in a["equipment"]:
		var st: Dictionary = a["equipment"][k].get("stats", {})
		if st.has("durability"):
			st["durability"] = max(1, int(st["durability"]) - randi_range(4, 14) * int(danger))
	# upgrade from loot
	for it in loot:
		var s := Items.slot(it)
		if s != "" and Items.score(it) > Items.score(a["equipment"].get(s, {})):
			a["equipment"][s] = it
	while int(a["xp"]) >= int(a["level"]) * 100:
		a["xp"] = int(a["xp"]) - int(a["level"]) * 100
		a["level"] = int(a["level"]) + 1
		Game.journal("%s reached level %d." % [a["name"], a["level"]])
	var report := "%s returned from %s %s." % [a["name"], d["name"], "triumphant" if success else "battered and empty-handed"]
	if injured:
		a["status"] = "injured"
		a["injured_days"] = randi_range(1, 3)
		report += " Injured."
	else:
		a["status"] = "in_town"
		a["depart_day"] = Game.day() + randi_range(1, 3)
	if success:
		a["victories"] = int(a["victories"]) + 1
	a["last_report"] = report
	Game.journal(report)
	# your craftsmanship mattered
	if success and not mine.is_empty():
		Social.change(a["id"], 6.0, 4.0, "gear_held_" + str(Game.day()), "The blade you made held at %s." % d["name"])
	elif not success and not mine.is_empty():
		var worst := 999.0
		for it in mine:
			worst = minf(worst, float(it.get("quality", 70)))
		if worst < 60.0:
			Social.change(a["id"], -12.0, 2.0, "gear_failed_" + str(Game.day()), "Your work failed me at %s." % d["name"])
	# spouse shares the spoils
	if spouse:
		var share := gold / 2
		Game.add_gold(share, "family", "%s's share of the spoils" % a["name"])
		if not loot.is_empty():
			var gift := []
			for it in loot:
				if Items.slot(it) == "" or Items.score(it) <= Items.score(a["equipment"].get(Items.slot(it), {})):
					gift.append(it)
			if not gift.is_empty():
				Game.state["returns"].append(Loot.make_container("bag_traveller", gift, a["name"], "%s brought this home for you." % a["name"]))
	if a["id"] == "mira":
		Sim.on_mira_returned(success, mine)
	a["needs"] = _weakest_slot(a)
	Events.adventurer_returned.emit(a["id"], d["exit"])


static func _die(a: Dictionary, d: Dictionary, mine: Array) -> void:
	a["status"] = "dead"
	a["last_report"] = "%s fell at %s." % [a["name"], d["name"]]
	Game.journal(a["last_report"])
	Events.toast.emit(a["last_report"], "bad")
	var bad := false
	for it in mine:
		if float(it.get("quality", 70)) < 60.0:
			bad = true
	for r in Social.relatives(a["id"]):
		if bad:
			Social.change(r, -35.0, 5.0, "blame_" + a["id"], "%s died carrying your shoddy work." % a["name"], false)
		else:
			Social.change(r, -5.0, 8.0, "grief_" + a["id"], "We buried %s." % a["name"], false)
	if Social.spouse() == a["id"]:
		Social.set_romance(a["id"], "widowed")
		Game.journal("Your wife %s did not come home." % a["name"])


static func _weakest_slot(a: Dictionary) -> String:
	var wants: Array = CLASS_WANTS.get(a["cls"], ["weapon"])
	var worst := ""
	var worst_score := 1e9
	for s in wants:
		var sc := Items.score(a["equipment"].get(s, {}))
		if sc < worst_score:
			worst_score = sc
			worst = s
	return worst


## Would the adventurer buy `it` at `price`? Returns a reason or "".
static func purchase_check(a: Dictionary, it: Dictionary, price: int) -> String:
	var s := Items.slot(it)
	if s == "":
		return "has no use for that"
	if Items.score(it) <= Items.score(a["equipment"].get(s, {})) + 1.0:
		return "already has better"
	var married: bool = Social.spouse() == a["id"]
	if not married and int(a["gold"]) < price:
		return "can't afford it"
	var fair := Items.value(it) * (1.15 + Social.aff(a["id"]) / 200.0)
	if not married and price > fair:
		return "thinks it's overpriced"
	return ""


static func give_item(a: Dictionary, it: Dictionary, price: int) -> void:
	var s := Items.slot(it)
	var married: bool = Social.spouse() == a["id"]
	if married:
		price = 0
	a["gold"] = int(a["gold"]) - price
	if a["equipment"].has(s):
		a["loot"].append(a["equipment"][s])
	a["equipment"][s] = it
	if a["needs"] == s:
		a["needs"] = ""
	var q := float(it.get("quality", 70))
	var good: bool = q >= 85.0 or it.get("rarity") in ["rare", "legendary", "unique", "set"]
	Social.change(a["id"], (8.0 if good else 3.0) + (6.0 if price == 0 else 0.0), 6.0,
		"equipped_" + str(it["uid"]), "Brannoc equipped me with %s." % it["name"])
	Events.adventurers_changed.emit()
