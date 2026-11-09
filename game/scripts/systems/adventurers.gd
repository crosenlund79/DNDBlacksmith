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
	# iteration 010: gear wants, plans and ambitions (older saves gain them lazily)
	if not a.has("shopping"):
		a["shopping"] = []
	if not a.has("ambitions"):
		a["ambitions"] = []
	if not a.has("gear_log"):
		a["gear_log"] = []
	if not a.has("saving_for"):
		a["saving_for"] = {}
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


## New game: the seeded starting roster (Living.generate_roster — the world seed decides who is here and their
## circumstances; the established adventurers keep their story roles: Mira leaves on day 3 for the Barrow Fields).
static func init_population() -> void:
	Living.generate_roster()


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
		Game.add_gold(price, "sales", "%s bought a healing draught" % a["name"], str(a["id"]))
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
		ensure(a)
		if a["status"] == "in_town":
			evaluate_gear(a)
		match a["status"]:
			"away":
				if a.has("exp"):
					continue   # the expedition simulation (Expeditions) brings them home
				a["days_left"] = int(a["days_left"]) - 1
				if int(a["days_left"]) <= 0:
					_resolve(a)
			"injured":
				a["injured_days"] = int(a["injured_days"]) - 1
				if int(a["injured_days"]) <= 0:
					a["status"] = "in_town"
					a["activity"] = "recovering"
					a["depart_day"] = Game.day() + randi_range(1, 2)
	Living.on_day()   # goals, retirement, newcomers, companies (The Living Realm)
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
		var power := float(th["power"]) * 1.25 * scale * randf_range(0.85, 1.25)
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
		var taken := hit * (1.0 - defence / (defence + 30.0))
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
	# adventurers keep most of what they learn to themselves; a little reaches the smith
	Regions.add_scouting(a["dest"], 0.6 if success else 0.3)
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
		Game.add_gold(share, "family", "%s's share of the spoils" % a["name"], str(a["id"]))
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
	_die_consequences(a, mine, d["name"])


## What a death means to the village: grief or blame in the family, the smith's name, a widower.
static func _die_consequences(a: Dictionary, mine: Array, where: String) -> void:
	Chronicle.add("death", "%s fell at %s." % [a["name"], where], {"adv": a["id"]}, true)
	Events.toast.emit("%s fell at %s." % [a["name"], where], "bad")
	Audio.play("sfx/check_poor", -2.0)
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
	if affinity(a, it) <= 0.0:
		return "has no use for that"
	if not married and int(a["gold"]) < price:
		return "can't afford it"
	var fair := Items.value(it) * (1.15 + Living.price_tolerance(a) + Social.aff(a["id"]) / 200.0 + Shop.reputation() / 300.0)
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
	Provenance.transfer(it, str(a["id"]), "given" if price <= 0 else "sold", "brindlewick")
	it["owner"] = a["id"]
	if a["needs"] == s:
		a["needs"] = ""
	_clear_want(a, s, "equipped %s" % it.get("name", "it"))
	var q := float(it.get("quality", 70))
	var good: bool = q >= 85.0 or it.get("rarity") in ["rare", "legendary", "unique", "set"]
	Social.change(a["id"], (8.0 if good else 3.0) + (6.0 if price == 0 else 0.0), 6.0,
		"equipped_" + str(it["uid"]), "Brannoc equipped me with %s." % it["name"])
	Events.adventurers_changed.emit()


# ======================================================================= gear: wants, plans, purchases
## EN: Every day in town an adventurer looks over their gear — empty slots their class would fill,
##     broken or badly worn pieces, pieces too weak for their level or plans — and decides, by purse,
##     class and ambition: buy from the smith's display, ask for a repair, place a commission, buy
##     elsewhere (hook), or save up and keep going out with what they have. The list is kept in
##     `shopping` and shown on the character sheet; decisions go to the Chronicle and `gear_log`.
##     Items are judged data-driven by slot, type, stats and tags (cloth/robe/heavy/bow…), never by id.
## DA: Hver dag i byen vurderer eventyreren sit udstyr og beslutter: købe, reparere, bestille, købe
##     andetsteds eller spare op. Listen gemmes i `shopping` og vises på karakterarket.

## How much each slot matters in a judgement of strength (also scales the level target).
const SLOT_WEIGHT := {"weapon": 1.0, "armor": 1.0, "shield": 0.6, "helmet": 0.4, "gloves": 0.3, "boots": 0.3, "belt": 0.2,
	"ring": 0.45, "amulet": 0.55, "cloak": 0.3, "companion": 0.5}
## Slots a class leaves empty on purpose (bows and spells want both hands free).
const CLASS_SKIP := {"Wizard": ["shield"], "Ranger": ["shield"], "Rogue": ["shield"], "Barbarian": ["shield"], "Bard": ["shield"]}
const WHY_ORDER := {"broken": 0, "missing": 1, "worn": 2, "inferior": 3, "extra": 4, "companion": 5}
const WHY_WORD := {"broken": "broken", "missing": "nothing in this slot", "worn": "badly worn", "inferior": "too weak for their level",
	"extra": "would like one", "companion": "wants a companion"}
const PLAN_WORD := {"buy": "means to buy it from your display", "repair": "wants it repaired at your forge", "commission": "will commission one from you",
	"commissioned": "has a commission open with you", "elsewhere": "may look elsewhere", "save": "is saving up", "watch": "is watching your display", "requested": "asked you for a repair"}


## Every slot equipment can use: the standard list plus any slot new item data introduces.
static func all_slots() -> Array:
	var out: Array = Items.SLOTS.duplicate()
	for id in DB.items:
		var sl: Variant = DB.items[id].get("slot")
		if sl is String and sl != "" and not out.has(sl):
			out.append(sl)
	return out


static func _def_tags(it: Dictionary) -> Array:
	return Items.def(it).get("tags", [])


static func _type(it: Dictionary) -> String:
	return str(Items.def(it).get("type", ""))


static func is_heavy(it: Dictionary) -> bool:
	var tg := _def_tags(it)
	return _type(it) in ["armor_metal", "armor_heavy"] or tg.has("heavy") or tg.has("plate")


static func is_cloth(it: Dictionary) -> bool:
	var tg := _def_tags(it)
	var t := _type(it)
	for k in ["cloth", "robe", "linen", "silk", "tunic", "hood", "cloak"]:
		if tg.has(k) or t.contains(k):
			return true
	return str(it.get("def", "")).contains("robe") or str(it.get("def", "")).contains("hood")


static func is_bow(it: Dictionary) -> bool:
	return _def_tags(it).has("bow") or Items.wtype(it) == "bow"


## How well an item suits the adventurer's class (0 = would not use it, 1 = fine, >1 = favoured).
static func affinity(a: Dictionary, it: Dictionary) -> float:
	var s := Items.slot(it)
	if s == "":
		return 0.0
	var cls := str(a.get("cls", ""))
	if (CLASS_SKIP.get(cls, []) as Array).has(s):
		return 0.0
	var caster := CASTERS.has(cls)
	var f := 1.0
	match s:
		"weapon":
			var wt := "bow" if is_bow(it) else Items.wtype(it)
			var prefers: Array = Expeditions.arch(a).get("prefers", [])
			f = 1.35 if prefers.has(wt) else (0.6 if caster else 0.8)
			if cls == "Ranger" and wt == "bow":
				f = 1.6
		"armor":
			if is_heavy(it):
				f = float({"Fighter": 1.4, "Paladin": 1.4, "Barbarian": 0.7, "Cleric": 0.9, "Ranger": 0.4, "Rogue": 0.3, "Bard": 0.3, "Wizard": 0.0}.get(cls, 0.8))
			elif is_cloth(it):
				f = float({"Wizard": 1.5, "Cleric": 1.3, "Bard": 1.2, "Rogue": 0.8, "Ranger": 0.8, "Fighter": 0.4, "Paladin": 0.4, "Barbarian": 0.6}.get(cls, 0.8))
			else:
				f = float({"Ranger": 1.3, "Rogue": 1.3, "Barbarian": 1.2, "Bard": 1.1, "Cleric": 0.9, "Wizard": 0.5, "Fighter": 0.8, "Paladin": 0.7}.get(cls, 1.0))
		"helmet":
			if is_cloth(it):
				f = 1.3 if caster or cls == "Rogue" else 0.8
			else:
				f = 0.4 if cls == "Wizard" else (1.2 if cls in ["Fighter", "Paladin"] else 0.9)
		"shield":
			f = 1.3 if cls in ["Fighter", "Paladin"] else 0.9
		"ring", "amulet":
			f = 1.3 if caster or cls == "Paladin" else 1.0
		"cloak":   # travellers and those who keep to the shadows favour a good cloak; plate-wearers barely notice one
			f = float({"Ranger": 1.4, "Rogue": 1.4, "Wizard": 1.2, "Bard": 1.2, "Cleric": 1.0, "Barbarian": 0.8, "Fighter": 0.8, "Paladin": 0.9}.get(cls, 1.0))
	if f > 0.0 and caster and Items.stat(it, "magic") > 0:
		f += 0.2
	return f


## The slots this adventurer gradually aims to fill: their class essentials first, then the rest.
static func desired_slots(a: Dictionary) -> Array:
	var out: Array = (CLASS_WANTS.get(a.get("cls", ""), ["weapon"]) as Array).duplicate()
	for s in all_slots():
		if s == "companion" or out.has(s) or (CLASS_SKIP.get(a.get("cls", ""), []) as Array).has(s):
			continue
		out.append(s)
	if not a.get("equipment", {}).get("companion", {}).is_empty() or wants_companion(a):
		out.append("companion")
	return out


## Filled desired slots / desired slots (the roster's gear-completeness meter).
static func completeness(a: Dictionary) -> Vector2i:
	var want := desired_slots(a)
	var have := 0
	for s in want:
		if not a.get("equipment", {}).get(s, {}).is_empty():
			have += 1
	return Vector2i(have, want.size())


## Pieces needing attention: {"broken": n, "worn": n}.
static func wear_warnings(a: Dictionary) -> Dictionary:
	var out := {"broken": 0, "worn": 0}
	for s in a.get("equipment", {}):
		var it: Dictionary = a["equipment"][s]
		if it.get("broken", false):
			out["broken"] += 1
		elif Items.needs_mending(it):   # Items.WORN — the one threshold
			out["worn"] += 1
	return out


## What a sound piece for this slot should score at this level.
static func level_target(a: Dictionary, slot: String) -> float:
	return float(SLOT_WEIGHT.get(slot, 0.4)) * (10.0 + int(a.get("level", 1)) * 4.0)


## Rich enough, well equipped, and nothing at the forge: time for a creature companion.
static func wants_companion(a: Dictionary) -> bool:
	if not a.get("equipment", {}).get("companion", {}).is_empty():
		return false
	if int(a.get("level", 1)) < 3 or int(a.get("gold", 0)) < 220 + int(a.get("level", 1)) * 25:
		return false
	for s in CLASS_WANTS.get(a.get("cls", ""), ["weapon"]):
		var it: Dictionary = a["equipment"].get(s, {})
		if it.is_empty() or it.get("broken", false):
			return false
	return true


## Hook for buying from the rival smith, the pawnshop or the caravan. Does nothing (returns false)
## until the lead wires it to the Commerce system; return true when a purchase was made.
static func buy_elsewhere(a: Dictionary, want := {}) -> bool:
	# a creature companion from the Hales, when they want one and can afford it
	if str(want.get("slot", "")) == "companion" or (want.is_empty() and wants_companion(a)):
		var o := Commerce.creature_offer_for(a)
		if not o.is_empty() and not Commerce.creature_buy_for(a, o).is_empty():
			return true
		if str(want.get("slot", "")) == "companion":
			return false
	# a former Ironhand apprentice's own workshop (iteration 012), now and then
	if Apprentices.alumni_buy_for(a, want):
		return true
	# otherwise, now and then, the Salt Anvil across the village
	if randf() < float(Commerce.rival_cfg().get("adv_chance", 0.5)):
		return not Commerce.rival_buy_for(a).is_empty()
	return false


## What the adventurer needs, most urgent first: [{slot, why}].
static func gear_needs(a: Dictionary) -> Array:
	var out := []
	var core: Array = CLASS_WANTS.get(a.get("cls", ""), ["weapon"])
	for s in desired_slots(a):
		var it: Dictionary = a["equipment"].get(s, {})
		var why := ""
		if it.is_empty():
			why = "companion" if s == "companion" else ("missing" if core.has(s) else "extra")
		elif it.get("broken", false):
			why = "broken"
		elif Items.needs_mending(it):   # Items.WORN — the one threshold
			why = "worn"
		elif Items.score(it) < level_target(a, s) * Living.inferior_factor(a) or (s == "weapon" and str(a.get("wants_prop", "")) != "" and Items.stat(it, str(a["wants_prop"])) <= 0):
			why = "inferior"
		if why != "":
			out.append({"slot": s, "why": why})
	out.sort_custom(func(x, y): return int(WHY_ORDER[x["why"]]) < int(WHY_ORDER[y["why"]]))
	return out


static func repair_cost(it: Dictionary) -> int:
	return 10 + int(Items.value(it) * 0.06)


static func commission_cost(a: Dictionary) -> int:
	return 26 + int(a.get("level", 1)) * 12


## Could the smith make something for this slot that this class would use — with the skills, skill-tree knowledge
## and stations the workshop really has today (Milestone A2: before, any recipe in the game counted, so beginners
## were asked for boots their forge could not make)? Missing materials do not count against it: they can be bought.
static func can_commission(a: Dictionary, slot: String) -> bool:
	if slot == "companion":
		return false
	return Shop.can_make_slot(slot, a, Shop.order_need(a, slot))   # what the commission would ask for (steel for veterans …)


## The slot an adventurer brings to the smith for `wanted` (Milestone A2): what they want when the workshop can make
## it (or has a piece on display); otherwise, now and then (Shop.OPPORTUNITY_CHANCE), still that — a visible
## opportunity with the next step shown — and usually the most pressing want the workshop CAN make.
static func request_slot(a: Dictionary, wanted: String) -> String:
	if wanted == "" or wanted == "companion" or Shop.can_make_slot(wanted, a, Shop.order_need(a, wanted)) or not best_stock(a, wanted).is_empty():
		return wanted
	if randf() < Shop.OPPORTUNITY_CHANCE:
		return wanted
	for need in gear_needs(a):
		var s := str(need["slot"])
		if s != "companion" and Shop.can_make_slot(s, a, Shop.order_need(a, s)):
			return s
	var best := ""
	var best_sc := 1e9
	for s2 in CLASS_WANTS.get(a.get("cls", ""), ["weapon"]):
		if not Shop.can_make_slot(str(s2), a, Shop.order_need(a, str(s2))):
			continue
		var sc := Items.score(a.get("equipment", {}).get(str(s2), {}))
		if sc < best_sc:
			best_sc = sc
			best = str(s2)
	return best if best != "" else wanted


## A rough price for a decent piece in this slot (the saving goal).
static func price_estimate(a: Dictionary, slot: String) -> int:
	var best := 0
	var lv := int(a.get("level", 1))
	for id in DB.items:
		var d: Dictionary = DB.items[id]
		if str(d.get("slot", "")) != slot or affinity(a, {"def": id}) <= 0.0:
			continue
		var v := int(d.get("value", 0))
		# the dearest piece they could reasonably aim for at their level
		if v <= 60 + lv * 45 and v > best:
			best = v
	return maxi(15, int(best * 1.05))


## The best piece on the smith's display this adventurer would buy for `slot` ({} if none). `pool` (A2): judge these
## pieces instead of the display by the same rules (a consultation also weighs what waits in the stores).
static func best_stock(a: Dictionary, slot: String, pool: Variant = null) -> Dictionary:
	var best := {}
	var best_v := 0.0
	var items: Array = Shop.stock() if pool == null else pool
	for it in items:
		if Items.slot(it) != slot:
			continue
		if purchase_check(a, it, Shop.price_of(it)) != "":
			continue
		var v := Items.score(it) * affinity(a, it)
		# not a step down from the piece they own (as it was when sound), and fit for their level
		var cur: Dictionary = a["equipment"].get(slot, {})
		if not cur.is_empty() and Items.score(it) <= Items.score(cur) / maxf(0.5, Items.condition(cur)):
			continue
		if v < level_target(a, slot) * 0.35:
			continue
		if v > best_v:
			best_v = v
			best = it
	return best


## Decides what to do about one need. Returns the plan entry {slot, why, plan, goal, note, uid?}.
static func decide(a: Dictionary, need: Dictionary) -> Dictionary:
	var slot: String = need["slot"]
	var why: String = need["why"]
	var cur: Dictionary = a["equipment"].get(slot, {})
	var gold := int(a.get("gold", 0))
	var e := {"slot": slot, "why": why, "plan": "save", "goal": 0, "note": ""}
	var has_order := not Shop.open_orders().filter(func(o): return o["npc"] == a["id"] and o["slot"] == slot).is_empty()
	if has_order:
		e["plan"] = "commissioned"
		e["note"] = "waiting on the commission"
		return e
	# mend what is worth mending
	if why in ["broken", "worn"] and Items.score(cur) / maxf(0.5, Items.condition(cur)) >= level_target(a, slot) * 0.4:
		var cost := repair_cost(cur)
		e["goal"] = cost
		if gold >= cost:
			e["plan"] = "repair"
			e["note"] = "a repair costs about %d g" % cost
		else:
			e["note"] = "can't pay for the repair yet (%d / %d g) — going out with it as it is" % [gold, cost]
		return e
	var st := best_stock(a, slot)
	if not st.is_empty():
		e["plan"] = "buy"
		e["uid"] = int(st["uid"])
		e["goal"] = Shop.price_of(st)
		e["note"] = "%s on your display (%d g)" % [Items.display_name(st), Shop.price_of(st)]
		return e
	var cc := commission_cost(a)
	if (why in ["broken", "missing"] or (why == "inferior" and gold >= cc * 2)) and can_commission(a, slot) and gold >= cc + 10 \
			and Shop.open_orders().filter(func(o): return o["npc"] == a["id"]).is_empty() and not Shop.refuses(a["id"]):
		e["plan"] = "commission"
		e["goal"] = cc
		e["note"] = "nothing suitable on display; can afford a commission (about %d g)" % cc
		return e
	if slot == "companion" or (gold >= 40 and (hash(str(a["id"]) + slot) + int(Game.day() / 5)) % 7 == 0):
		e["plan"] = "elsewhere"
		e["note"] = "may try the other traders in the village"
		return e
	var goal := price_estimate(a, slot)
	e["goal"] = goal
	if gold >= goal:
		e["plan"] = "watch"
		e["note"] = "has the coin (%d g); watching your display" % gold
	else:
		e["note"] = "saving for it (%d / %d g)" % [gold, goal]
	return e


## Daily: look over the gear, keep the shopping list and ambitions current. Changes are logged.
static func evaluate_gear(a: Dictionary) -> void:
	ensure(a)
	if a.get("status", "") == "dead":
		return
	var old := {}
	for e in a["shopping"]:
		old[str(e["slot"])] = e
	var list := []
	var commissioning := false
	for need in gear_needs(a):
		var e := decide(a, need)
		# one commission at a time: later wants wait for it
		if e["plan"] == "commission":
			if commissioning:
				e["plan"] = "save"
				e["goal"] = price_estimate(a, str(e["slot"]))
				e["note"] = "after the first commission"
			commissioning = true
		var prev: Dictionary = old.get(e["slot"], {})
		e["since"] = int(prev.get("since", Game.day())) if prev.get("why", "") == e["why"] else Game.day()
		# a repair already asked for stays asked for while they wait at the counter
		if prev.get("plan", "") == "requested" and e["plan"] == "repair" and not Shop.customer(a["id"]).is_empty():
			e["plan"] = "requested"
		if (prev.get("plan", "") != e["plan"] or prev.get("why", "") != e["why"]) and e["why"] != "extra":
			_gear_note(a, "%s: %s — %s." % [_slot_name(e["slot"]), WHY_WORD[e["why"]], PLAN_WORD.get(e["plan"], e["plan"])],
				e["plan"] == "save" and e["why"] in ["broken", "missing"])
		list.append(e)
	a["shopping"] = list
	# the thing they save for: the most urgent unaffordable want
	a["saving_for"] = {}
	for e in list:
		if e["plan"] == "save" and int(e.get("goal", 0)) > 0:
			a["saving_for"] = {"slot": e["slot"], "goal": int(e["goal"]), "since": int(e["since"])}
			break
	a["ambitions"] = ambitions(a)


## Career goals in plain words (also persisted on the adventurer for the sheet).
static func ambitions(a: Dictionary) -> Array:
	var out := []
	var lv := int(a.get("level", 1))
	var prop := str(a.get("wants_prop", ""))
	if prop != "":
		var dn: String = DB.destinations.get(str(a.get("next_dest", "")), {}).get("name", "the wilds")
		out.append("Wants a %s weapon for %s" % [prop, dn])
	var sv: Dictionary = a.get("saving_for", {})
	if not sv.is_empty():
		out.append("Saving for %s (%d / %d g)" % [Shop.slot_phrase(str(sv["slot"])) if sv["slot"] != "companion" else "a companion creature", int(a.get("gold", 0)), int(sv["goal"])])
	var c := completeness(a)
	if c.x < c.y:
		out.append("Wants every slot filled (%d of %d)" % [c.x, c.y])
	var w: Dictionary = a.get("equipment", {}).get("weapon", {})
	if lv >= 5 and Items.tier(w) < 3:
		out.append("Dreams of a mithril blade")
	elif lv >= 3 and Items.tier(w) < 2:
		out.append("Wants a steel weapon worthy of their skill")
	if wants_companion(a):
		out.append("Can afford a creature companion and means to find one")
	var titles: Array = Expeditions.cfg().get("renown_titles", [])
	for t in titles:
		if int(a.get("renown", 0)) < int(t[0]):
			out.append("Hopes to be spoken of as “%s” (renown %d / %d)" % [str(t[1]), int(a.get("renown", 0)), int(t[0])])
			break
	return out


## 11:00 in town — act on the most urgent plan: visit the forge to buy, ask for a repair,
## place a commission, or try elsewhere. One errand a day.
static func gear_hour() -> void:
	for a in all().values():
		ensure(a)
		if a.get("status", "") != "in_town" or int(a.get("gear_day", -1)) == Game.day():
			continue
		if a["shopping"].is_empty():
			continue
		a["gear_day"] = Game.day()
		act_on_plans(a)


## Carries out the first actionable plan; returns what happened ("" = nothing).
static func act_on_plans(a: Dictionary) -> String:
	for e in a["shopping"].duplicate():
		match str(e["plan"]):
			"buy":
				var it := Game.find_uid(int(e.get("uid", -1)))
				if it.is_empty() or not it.get("for_sale", false):
					continue
				var nm := Items.display_name(it)
				var price := Shop.price_of(it)
				if Shop.sell_to(a["id"], int(e["uid"])) == "":
					_gear_note(a, "Visited the forge and bought %s for %d g." % [nm, price], true)
					Events.toast.emit("%s bought %s from your display (+%d g)." % [a["name"], nm, price], "good")
					evaluate_gear(a)
					return "bought"
			"repair":
				# the piece they PLANNED to have mended is the one they bring (Milestone A2: not merely the first worn one)
				if not Shop.customer(a["id"]).is_empty() or not Items.needs_mending(a["equipment"].get(str(e["slot"]), {})):
					continue
				var before := Shop.customers().size()
				Shop._add_customer(a["id"], "repair_own", str(e["slot"]))
				if Shop.customers().size() > before:
					e["plan"] = "requested"
					_gear_note(a, "Set out for the forge to have the %s repaired." % a["equipment"][e["slot"]].get("name", e["slot"]), false)
					return "repair"
			"commission":
				var why_txt := "I have nothing for my %s yet." % _slot_name(e["slot"]).to_lower() if e["why"] == "missing" \
					else "My %s is %s. Make me something better." % [_slot_name(e["slot"]).to_lower(), WHY_WORD.get(e["why"], "lacking")]
				var o := Shop.create_order(a["id"], str(e["slot"]), why_txt)
				if not o.is_empty():
					e["plan"] = "commissioned"
					e["order"] = str(o["id"])
					_gear_note(a, "Commissioned %s from the smith (%s)." % [Shop.slot_phrase(str(e["slot"])), Shop.PRIORITY.get(o.get("priority", ""), {}).get("name", "")], true)
					return "commission"
			"elsewhere":
				if buy_elsewhere(a, e):
					evaluate_gear(a)
					return "elsewhere"
	return ""


static func _clear_want(a: Dictionary, slot: String, why := "") -> void:
	if not a.has("shopping"):
		return
	var kept := (a["shopping"] as Array).filter(func(e): return str(e["slot"]) != slot)
	if kept.size() != (a["shopping"] as Array).size() and why != "" and a.has("gear_log"):
		a["gear_log"].append({"day": Game.day(), "text": "%s: %s." % [_slot_name(slot), why]})
	a["shopping"] = kept
	if str(a.get("saving_for", {}).get("slot", "")) == slot:
		a["saving_for"] = {}


static func _slot_name(slot: String) -> String:
	return str(Items.SLOT_LABEL.get(slot, slot.capitalize()))


## A gear decision: kept on the adventurer (capped) and, when notable, in the Chronicle.
static func _gear_note(a: Dictionary, text: String, chronicle := true) -> void:
	if not a.has("gear_log"):
		a["gear_log"] = []
	a["gear_log"].append({"day": Game.day(), "text": text})
	while a["gear_log"].size() > 14:
		a["gear_log"].pop_front()
	if chronicle:
		Chronicle.add("gear", "%s — %s" % [a["name"], text], {"adv": a["id"]})


## After an expedition: broken pieces noted, the gear looked over at once.
static func after_expedition(a: Dictionary, where: String) -> void:
	ensure(a)
	for s in a["equipment"]:
		var it: Dictionary = a["equipment"][s]
		if not it.get("broken", false):
			it.erase("broken_noted")
		elif s != "weapon" and not it.get("broken_noted", false):
			it["broken_noted"] = true
			Chronicle.add("chain", "%s came home from %s with a broken %s." % [a["name"], where, it.get("name", s)], {"adv": a["id"], "item": str(it.get("uid", ""))})
	evaluate_gear(a)



## A fallen adventurer's equipment passes on (iteration 011). Each piece goes to a companion who can use it and
## would be better off with it ("inherited"), or — if it is the smith's work or a notable piece — is carried home
## to the forge ("recovered", in a chest at the workshop), or stays buried with its owner ("lost"). The instance
## is never duplicated: it leaves the dead adventurer's equipment.
static func bequeath(dead: Dictionary, heirs: Array, place: String, place_name := "") -> void:
	if dead.get("bequeathed", false):
		return
	dead["bequeathed"] = true
	var home := []
	for slot in (dead.get("equipment", {}) as Dictionary).keys():
		var it: Dictionary = dead["equipment"][slot]
		if it.is_empty() or not Items.is_equipment(it):
			continue
		var heir := {}
		var best := 0.0
		for hid in heirs:
			var h := get_a(str(hid))
			if h.is_empty() or str(h.get("status", "")) == "dead":
				continue
			var cur: Dictionary = h.get("equipment", {}).get(slot, {})
			var gain := Items.score(it) - Items.score(cur)
			if gain > best and affinity(h, it) > 0.0:
				best = gain
				heir = h
		dead["equipment"].erase(slot)
		if not heir.is_empty():
			var old: Dictionary = heir["equipment"].get(slot, {})
			if not old.is_empty():
				heir["loot"].append(old)
			heir["equipment"][slot] = it
			Provenance.transfer(it, str(heir["id"]), "inherited", place,
				"%s took up %s from fallen %s at %s." % [heir["name"], Items.display_name(it), dead["name"], place_name if place_name != "" else "the road"])
		elif Provenance.is_mine(it) or Provenance.is_notable(it) or slot == "weapon":
			home.append(it)
		else:
			Provenance.lose(it, place_name, "buried with %s" % dead["name"], place)
	if not home.is_empty():
		for it2 in home:
			it2["_arrives_how"] = "recovered"
			Lore.record("recovered", "%s's companions carried %s home from %s." % [dead["name"], Items.display_name(it2), place_name if place_name != "" else "the wilds"],
				{"items": [it2], "actors": [dead["id"]] + heirs, "place": place, "importance": 1})
		Game.state["returns"].append(Loot.make_container("chest_recovered", home, str(get_a(str(heirs[0])).get("name", "Companions")),
			"%s's companions brought this home: \"It should go back to the forge.\"" % dead["name"]))
		Events.inventory_changed.emit()
