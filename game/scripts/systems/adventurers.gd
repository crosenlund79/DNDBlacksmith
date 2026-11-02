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


const TRAITS := {
	"brave": "Brave — presses on where others turn back",
	"cautious": "Cautious — turns back early, rarely badly hurt",
	"greedy": "Greedy — goes deeper for richer spoils",
	"steady": "Steady — dependable in a long fight",
	"reckless": "Reckless — strikes hard, bleeds freely",
	"devout": "Devout — wards and faith hold against the dead",
}
const CLASS_TRAIT := {"Ranger": "cautious", "Fighter": "steady", "Wizard": "cautious", "Rogue": "greedy",
	"Paladin": "devout", "Cleric": "devout", "Barbarian": "reckless", "Bard": "brave"}
const CASTERS := ["Wizard", "Cleric", "Bard"]


## Older saves: add the fields the encounter simulation needs.
static func ensure(a: Dictionary) -> Dictionary:
	if not a.has("trait"):
		a["trait"] = CLASS_TRAIT.get(a.get("cls", ""), "steady")
	if not a.has("potions"):
		a["potions"] = 0
	if not a.has("log"):
		a["log"] = []
	if not a.has("history"):
		a["history"] = []
	return a


## Rough capability words by class (shown in the overview; precise with familiarity).
static func skills_text(a: Dictionary) -> String:
	var lv := int(a["level"])
	var main: String = {"Ranger": "archery and woodcraft", "Fighter": "sword and shield", "Wizard": "fire and arcana",
		"Rogue": "blades and locks", "Paladin": "mace and faith", "Cleric": "healing and faith", "Barbarian": "the great axe",
		"Bard": "song and blade"}.get(a["cls"], "fighting")
	var grade := "a novice at" if lv <= 2 else ("practised in" if lv <= 4 else ("skilled at" if lv <= 6 else "a master of"))
	return "%s %s" % [grade, main]


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
	if a.has("next_dest"):
		var nd: String = a["next_dest"]
		a.erase("next_dest")
		return nd
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


## Where they mean to go next, and what that place demands (a damage type its threats fear).
static func plan_next(a: Dictionary) -> void:
	if not a.has("next_dest"):
		a["next_dest"] = choose_dest(a)
	var d: Dictionary = DB.destinations.get(a["next_dest"], {})
	var weak := {}
	for th in d.get("threats", []):
		var w := str(th.get("weak", ""))
		if w in ["fire", "frost"]:
			weak[w] = int(weak.get(w, 0)) + 1
	a["wants_prop"] = ""
	for w in weak:
		if _total(a, w) <= 0 and int(weak[w]) >= 2:
			a["wants_prop"] = w


## Before leaving, an adventurer buys a healing draught from the smith's displayed stock.
static func _buy_supplies(a: Dictionary) -> void:
	if int(a.get("potions", 0)) >= 2:
		return
	for it in Shop.stock():
		if it["def"] != "potion_healing":
			continue
		var price := Shop.price_of(it) / maxi(1, int(it.get("qty", 1)))
		if int(a["gold"]) < price:
			return
		a["gold"] = int(a["gold"]) - price
		a["potions"] = int(a.get("potions", 0)) + 1
		Game.add_gold(price, "sales", "%s bought a healing draught" % a["name"])
		if int(it.get("qty", 1)) > 1:
			it["qty"] = int(it["qty"]) - 1
		else:
			Game.inventory().erase(it)
		Events.inventory_changed.emit()
		return


## Called each morning at 7:00.
static func morning_departures() -> void:
	for a in all().values():
		ensure(a)
		if a["status"] != "in_town" or Game.day() < int(a["depart_day"]):
			continue
		_buy_supplies(a)
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


## The expedition, encounter by encounter. Equipment matters directly: attack and the damage type a
## threat is weak to decide whether it falls; protection and ward decide how much it hurts; a
## healing draught closes a bad wound; coatings add their bite for a few trips.
## Returns {wins, fought, wounds, lines, credits: {item uid: reason}}.
static func run_encounters(a: Dictionary, dest: String) -> Dictionary:
	ensure(a)
	var d: Dictionary = DB.destinations[dest]
	var threats: Array = d.get("threats", [{"name": "trouble", "kind": "beast", "power": 10.0 * float(d["danger"]), "dmg": 6, "weak": "", "resist": ""}])
	var scale := Regions.danger(dest) / maxf(0.1, float(d["danger"]))
	var eq: Dictionary = a["equipment"]
	var weapon: Dictionary = eq.get("weapon", {})
	var lv := int(a["level"])
	var tr: String = a["trait"]
	var n := randi_range(2, 4) + (1 if tr == "greedy" else 0) - (1 if tr == "cautious" else 0)
	var res := {"wins": 0, "fought": 0, "wounds": 0.0, "lines": [], "credits": {}}
	for i in maxi(1, n):
		var th: Dictionary = threats.pick_random()
		var power := float(th["power"]) * scale * randf_range(0.85, 1.2)
		var atk := float(Items.stat(weapon, "attack")) + _coat(weapon, "attack")
		if str(th.get("resist", "")) == "physical":
			atk *= 0.45
		var offence := lv * 4.0 + atk + (float(_total(a, "magic")) * (1.0 if CASTERS.has(a["cls"]) else 0.4))
		var weak := str(th.get("weak", ""))
		var exploit := 0.0
		var exploit_item := {}
		if weak in ["fire", "frost", "magic"]:
			for slot in eq:
				var v := float(Items.stat(eq[slot], weak)) + _coat(eq[slot], weak)
				if v > 0.0:
					exploit += v * 3.0
					if exploit_item.is_empty() or v > float(Items.stat(exploit_item, weak)):
						exploit_item = eq[slot]
		var rs := str(th.get("resist", ""))
		if rs in ["fire", "frost"]:
			offence -= float(_total(a, rs)) * 2.0
		offence += exploit
		if tr == "reckless":
			offence *= 1.15
		var chance := clampf(0.5 + (offence - power) / (power + 14.0), 0.08, 0.96)
		var won := randf() < chance
		var defence := lv * 2.0 + float(_total(a, "protection")) * 1.2 + (float(_total(a, "ward")) * 2.0 if th["kind"] in ["spirit", "undead"] else 0.0)
		if tr == "devout" and th["kind"] in ["spirit", "undead"]:
			defence += 6.0
		var hit := float(th["dmg"]) * scale * (0.5 if won else 1.2) * (1.25 if tr == "reckless" else 1.0)
		var taken := maxf(0.0, hit - defence * 0.35)
		res["fought"] = int(res["fought"]) + 1
		res["wounds"] = float(res["wounds"]) + taken
		var line := ""
		if won:
			res["wins"] = int(res["wins"]) + 1
			if not exploit_item.is_empty() and exploit >= 6.0:
				line = "%s's %s (%s) tore through %s." % [a["name"], exploit_item["name"], weak, th["name"]]
				res["credits"][str(exploit_item.get("uid", ""))] = "%s against %s" % [weak, th["name"]]
			elif not weapon.is_empty():
				line = "%s cut down %s with the %s." % [a["name"], th["name"], weapon["name"]]
				if atk >= lv * 2.0 + 8.0:
					res["credits"][str(weapon.get("uid", ""))] = "felled %s" % th["name"]
			else:
				line = "%s drove off %s." % [a["name"], th["name"]]
		else:
			line = "%s was driven back by %s%s." % [a["name"], th["name"], (" — " + str(weak) + " would have helped") if weak != "" and exploit <= 0.0 else ""]
		var armour: Dictionary = eq.get("armor", {})
		if taken <= 1.0 and not armour.is_empty() and hit >= 6.0:
			line += " The %s turned the blows." % armour["name"]
			res["credits"][str(armour.get("uid", ""))] = "turned the blows of %s" % th["name"]
		# a bad wound: drink a draught if one is carried
		if float(res["wounds"]) >= 14.0 and int(a["potions"]) > 0:
			a["potions"] = int(a["potions"]) - 1
			res["wounds"] = float(res["wounds"]) * 0.4
			line += " A healing draught closed the worst of it."
		res["lines"].append(line)
		if tr == "cautious" and float(res["wounds"]) >= 12.0:
			res["lines"].append("%s turned back while still able to walk." % a["name"])
			break
	# coatings wear off with use
	for slot in eq:
		var it: Dictionary = eq[slot]
		if it.has("coating"):
			it["coating"]["uses"] = int(it["coating"]["uses"]) - 1
			if int(it["coating"]["uses"]) <= 0:
				it.erase("coating")
	return res


static func _coat(it: Dictionary, stat: String) -> float:
	var c: Dictionary = it.get("coating", {})
	return float(c.get("value", 0)) if str(c.get("stat", "")) == stat else 0.0


static func _total(a: Dictionary, stat: String) -> int:
	var t := 0
	for slot in a["equipment"]:
		t += Items.stat(a["equipment"][slot], stat)
	return t


static func _resolve(a: Dictionary) -> void:
	ensure(a)
	var d: Dictionary = DB.destinations[a["dest"]]
	var danger := Regions.danger(a["dest"])
	var enc := run_encounters(a, a["dest"])
	var success := int(enc["wins"]) * 2 >= int(enc["fought"]) and int(enc["fought"]) > 0
	var wounds := float(enc["wounds"])
	var injured := wounds >= 12.0
	var dies := wounds >= 26.0 and not success and randf() < clampf((wounds - 22.0) * 0.04, 0.0, 0.7)
	a["log"] = enc["lines"]
	a["history"].append({"day": Game.day(), "dest": a["dest"], "outcome": "died" if dies else ("success" if success else "failed") + ("_injured" if injured else ""),
		"wins": enc["wins"], "fought": enc["fought"], "credits": enc["credits"]})
	while a["history"].size() > 8:
		a["history"].pop_front()
	Regions.on_trip(a["dest"], 2, success)
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
	var loot: Array = Loot.roll_table(d["loot"], float(a["level"]) * 2.0) if success else []
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
	var report := "%s returned from %s %s (%d of %d fights won)." % [a["name"], d["name"], "triumphant" if success else "battered and empty-handed", int(enc["wins"]), int(enc["fought"])]
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
	# your craftsmanship mattered — and they know exactly which piece did it
	var credited := []
	for it in mine:
		if enc["credits"].has(str(it.get("uid", ""))):
			credited.append(it)
			it["deeds"] = int(it.get("deeds", 0)) + 1
	if success and not credited.is_empty():
		Shop.rep_change(2.0, "%s swears by the smith's work." % a["name"])
		var ci: Dictionary = credited[0]
		Social.change(a["id"], 8.0, 5.0, "gear_held_" + str(Game.day()), "Your %s saved me at %s (%s)." % [ci["name"], d["name"], enc["credits"][str(ci["uid"])]])
	elif success and not mine.is_empty():
		Social.change(a["id"], 4.0, 4.0, "gear_held_" + str(Game.day()), "The gear you made held at %s." % d["name"])
	elif not success and not mine.is_empty():
		var worst := 999.0
		for it in mine:
			worst = minf(worst, float(it.get("quality", 70)))
		if worst < 60.0:
			Social.change(a["id"], -12.0, 2.0, "gear_failed_" + str(Game.day()), "Your work failed me at %s." % d["name"])
			if injured:
				Shop.raise_dispute(a["id"], mine[0])
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
	plan_next(a)
	if a.get("wants_prop", "") != "":
		a["needs"] = "weapon"
	Events.adventurer_returned.emit(a["id"], d["exit"])


static func _die(a: Dictionary, d: Dictionary, mine: Array) -> void:
	a["status"] = "dead"
	a["died_day"] = Game.day()
	a["last_report"] = "%s fell at %s." % [a["name"], d["name"]]
	Game.journal(a["last_report"])
	Events.toast.emit(a["last_report"], "bad")
	var bad := false
	for it in mine:
		if float(it.get("quality", 70)) < 60.0:
			bad = true
	if bad:
		Shop.rep_change(-10.0, "%s died carrying the smith's shoddy work." % a["name"])
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
	if Shop.refuses(a["id"]):
		return "won't buy from you"
	if not married and int(a["gold"]) < price:
		return "can't afford it"
	var fair := Items.value(it) * (1.15 + Social.aff(a["id"]) / 200.0 + Shop.reputation() / 300.0)
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
