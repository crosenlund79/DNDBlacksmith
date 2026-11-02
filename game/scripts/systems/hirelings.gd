## Hire — employees: work allocation, production, expeditions and recruitment.
## EN: Up to three hirelings (four with the smith). Each has the six trainable work skills, an
##     allocation of normal working time that must total 100%, and a status: working, away
##     (expedition), injured or dead. Expeditions resolve from skill, gear, danger and chance.
## DA: Op til tre ansatte. Hver har seks trænbare arbejdsfærdigheder, en fordeling af arbejdstiden
##     der skal give 100%, og en status: arbejder, ude (ekspedition), skadet eller død.
##     Ekspeditioner afgøres af færdighed, udstyr, fare og tilfældighed.
class_name Hire
extends RefCounted

const MAX_HIRELINGS := 3


static func list() -> Array:
	return Game.state["hirelings"]


static func get_h(id: String) -> Dictionary:
	for h in list():
		if h["id"] == id:
			return h
	return {}


static func alive_count() -> int:
	return list().filter(func(h): return h["status"] != "dead").size()


static func _new_entry(id: String, name: String, look: String, race: String, personality: String, levels: Dictionary, wage: int) -> Dictionary:
	var alloc := {}
	for s in DB.work_skills:
		alloc[s] = 0
	var best: String = DB.work_skills[0]
	for s in DB.work_skills:
		if int(levels.get(s, 0)) > int(levels.get(best, 0)):
			best = s
	alloc[best] = 100
	return {"id": id, "name": name, "look": look, "race": race, "personality": personality,
		"skills": SkillSys.new_set(levels), "alloc": alloc, "progress": {}, "status": "working",
		"expedition": {}, "injured_days": 0, "wage": wage, "hired_day": Game.day(), "equipment": {}, "expeditions": 0}


static func hire_from_character(char_id: String) -> void:
	var c := DB.character(char_id)
	var h := _new_entry(char_id, c["name"], char_id, "Dwarf", c.get("personality", ""), c.get("skills", {}), int(c.get("wage", 5)))
	h["equipment"] = {"weapon": Items.make("axe_hand", {"quality": 70.0}), "armor": Items.make("jerkin_leather", {"quality": 66.0})}
	list().append(h)


# ------------------------------------------------------------------ recruitment
static func refresh_applicants() -> void:
	var out := []
	var looks: Array = DB.names.get("applicant_looks", [])
	for i in randi_range(3, 4):
		var lk: Dictionary = looks.pick_random()
		var race: String = lk["race"]
		var pool: Dictionary = DB.names["first"].get(race, DB.names["first"]["Human"])
		var first: String = (pool["f"] if lk["female"] else pool["m"]).pick_random()
		var name := "%s %s" % [first, DB.names["last"].pick_random()]
		var levels := {}
		var skills: Array = DB.work_skills.duplicate()
		skills.shuffle()
		for j in skills.size():
			levels[skills[j]] = [randi_range(3, 5), randi_range(2, 4), randi_range(1, 2), randi_range(0, 2), randi_range(0, 1), 0][j]
		var wage := 3 + int((levels.values().reduce(func(a, b): return a + b, 0)) / 3)
		out.append({"name": name, "look": lk["look"], "race": race, "female": lk["female"],
			"personality": DB.names["personality"].pick_random(), "levels": levels, "wage": wage, "fee": wage * 4})
	Game.state["applicants"] = out
	Events.hirelings_changed.emit()


static func hire_applicant(index: int) -> String:
	var apps: Array = Game.state["applicants"]
	if index < 0 or index >= apps.size():
		return "No such applicant."
	if alive_count() >= MAX_HIRELINGS:
		return "You already employ three hands. Dismiss someone first."
	var a: Dictionary = apps[index]
	if not Game.can_afford(int(a["fee"])):
		return "You cannot afford the signing fee."
	Game.add_gold(-int(a["fee"]), "wages", "Signing fee: " + a["name"])
	var id := "hire_%d" % Game.new_uid()
	var h := _new_entry(id, a["name"], a["look"], a["race"], a["personality"], a["levels"], int(a["wage"]))
	list().append(h)
	apps.remove_at(index)
	Audio.play("sfx/hire")
	Game.journal("Hired %s (%s)." % [a["name"], a["race"]])
	Events.hirelings_changed.emit()
	return ""


static func dismiss(id: String) -> void:
	var h := get_h(id)
	if h.is_empty() or h["status"] == "away":
		return
	list().erase(h)
	Game.journal("%s was let go." % h["name"])
	Events.hirelings_changed.emit()


static func set_alloc(id: String, alloc: Dictionary) -> bool:
	var total := 0
	for k in alloc:
		total += int(alloc[k])
	if total != 100:
		return false
	get_h(id)["alloc"] = alloc
	Events.hirelings_changed.emit()
	return true


# ------------------------------------------------------------------ hourly work
const WORK_OUTPUT := {
	"mining": [["ore_iron", 2], ["coal", 2], ["ore_copper", 1]],
	"alchemy": [["herb_moonwort", 1], ["reagent_salt", 1], ["herb_emberleaf", 1]],
	"runecraft": [["runestone_blank", 1]],
	"smithing": [["ingot_iron", 1]],
	"travelling": [],
	"relic_hunting": [["relic_coin", 1]],
}


static func work_hour(_h: int) -> void:
	if not Game.is_work_hours():
		return
	var boost := 1.15 if Game.has_upgrade("second_anvil_hook") else 1.0
	for h in list():
		if h["status"] != "working":
			continue
		for skill in h["alloc"]:
			var pct := float(h["alloc"][skill]) / 100.0
			if pct <= 0.0:
				continue
			var lvl := SkillSys.level(h["skills"], skill)
			var prog: Dictionary = h["progress"]
			prog[skill] = float(prog.get(skill, 0.0)) + pct * (0.18 + lvl * 0.05) * boost
			if float(prog[skill]) >= 1.0:
				prog[skill] = float(prog[skill]) - 1.0
				_produce(h, skill, lvl)
				SkillSys.add_xp(h["skills"], skill, 6, h["id"])


static func _produce(h: Dictionary, skill: String, lvl: int) -> void:
	if skill == "travelling":
		var g := 4 + lvl * 2 + randi_range(0, 4)
		Game.add_gold(g, "trade", "%s traded small goods" % h["name"])
		return
	if skill == "relic_hunting" and randf() > 0.25 + lvl * 0.05:
		return
	var opts: Array = WORK_OUTPUT.get(skill, [])
	if skill == "mining" and lvl >= 4 and randf() < 0.25:
		opts = [["ore_silver", 1]]
	if skill == "alchemy" and lvl >= 3 and randf() < 0.3:
		opts = [["potion_healing", 1]]
	if opts.is_empty():
		return
	var pick: Array = opts.pick_random()
	if skill == "smithing" and Game.count("ore_iron") >= 2:
		Game.remove_def("ore_iron", 2)
	elif skill == "smithing":
		Game.add_gold(3 + lvl, "sales", "%s sold horseshoes and nails" % h["name"])
		return
	Game.add_item(Items.make(pick[0], {"qty": int(pick[1])}), false)


# ------------------------------------------------------------------ expeditions
static func gear_score(h: Dictionary) -> float:
	var s := 0.0
	for k in h.get("equipment", {}):
		s += Items.score(h["equipment"][k])
	return s


static func send(id: String, dest_id: String) -> String:
	var h := get_h(id)
	var d: Dictionary = DB.destinations.get(dest_id, {})
	if h.is_empty() or d.is_empty():
		return "Unknown hireling or destination."
	if h["status"] != "working":
		return "%s is not available." % h["name"]
	if d.has("requires_flag") and not Game.has_flag(d["requires_flag"]):
		return "Nobody knows the way there yet."
	var trav := SkillSys.level(h["skills"], "travelling")
	var days: int = maxi(1, randi_range(int(d["days"][0]), int(d["days"][1])) - (1 if trav >= 5 else 0))
	h["status"] = "away"
	h["expedition"] = {"dest": dest_id, "days_left": days, "total": days, "exit": d["exit"], "left_day": Game.day()}
	Game.journal("%s set out for %s (%d days)." % [h["name"], d["name"], days])
	Events.hireling_departed.emit(id, d["exit"])
	Events.hirelings_changed.emit()
	if id == "borin":
		Objectives.complete("send_borin")
	return ""


static func on_day() -> void:
	for h in list():
		if h["status"] == "injured":
			h["injured_days"] = int(h["injured_days"]) - 1
			if int(h["injured_days"]) <= 0:
				h["status"] = "working"
				Events.toast.emit("%s is fit for work again." % h["name"], "good")
		elif h["status"] == "away":
			var e: Dictionary = h["expedition"]
			e["days_left"] = int(e["days_left"]) - 1
			if int(e["days_left"]) <= 0:
				_resolve(h)
	# wages
	var wages := 0
	for h in list():
		if h["status"] != "dead":
			wages += int(h["wage"])
	if wages > 0:
		Game.add_gold(-wages, "wages", "Daily wages")
	Events.hirelings_changed.emit()


static func _resolve(h: Dictionary) -> void:
	var e: Dictionary = h["expedition"]
	var d: Dictionary = DB.destinations[e["dest"]]
	var skill: String = d["skill"]
	var lvl := SkillSys.level(h["skills"], skill)
	var danger := float(d["danger"])
	var power := lvl * 1.0 + SkillSys.level(h["skills"], "travelling") * 0.4 + gear_score(h) * 0.05
	var success := randf() < clampf(0.5 + (power - danger) * 0.09, 0.1, 0.97)
	var injury := randf() < clampf(0.08 + (danger - power) * 0.06, 0.02, 0.6)
	var death := (not success) and injury and randf() < clampf((danger - power) * 0.05, 0.0, 0.3)
	h["expeditions"] = int(h.get("expeditions", 0)) + 1
	var first_bag: bool = h["id"] == "borin" and not Game.has_flag("borin_first_bag")
	var contents: Array = []
	if death:
		h["status"] = "dead"
		Game.journal("%s did not come back from %s." % [h["name"], d["name"]])
		Events.toast.emit("%s died at %s." % [h["name"], d["name"]], "bad")
		var survivors := Loot.roll_table(d["loot"], -20.0)
		if not survivors.is_empty():
			Game.state["returns"].append(Loot.make_container("chest_recovered", survivors.slice(0, 2),
				"Recovered by a passing patrol", "All that came back of %s's expedition." % h["name"]))
		return
	if first_bag:
		Game.set_flag("borin_first_bag")
		contents = Loot.roll_table("start_bag", 0.0)
		contents.append(Loot.random_equipment("legendary_demo"))
		contents.append(Items.make("ore_mithril", {"qty": 2}))
	else:
		contents = Loot.roll_table(d["loot"], lvl * 2.0 + (0.0 if success else -25.0))
		if not success:
			contents = contents.slice(0, max(1, contents.size() / 2))
	var bag_def := "shipment_miner" if d["kind"] == "mining" else ("satchel_relic" if d["kind"] == "relics" else "bag_traveller")
	Game.state["returns"].append(Loot.make_container(bag_def, contents, h["name"],
		"%s's haul from %s." % [h["name"], d["name"]]))
	SkillSys.add_xp(h["skills"], skill, 40 + int(danger) * 15, h["id"])
	SkillSys.add_xp(h["skills"], "travelling", 15, h["id"])
	if injury:
		h["status"] = "injured"
		h["injured_days"] = randi_range(1, 3)
		Events.toast.emit("%s came back hurt from %s." % [h["name"], d["name"]], "bad")
	else:
		h["status"] = "working"
	h["expedition"] = {}
	Game.journal("%s returned from %s%s." % [h["name"], d["name"], "" if success else " with little to show"])
	Events.toast.emit("%s is back from %s — a bag waits in the workshop." % [h["name"], d["name"]], "good")
	Events.hireling_returned.emit(h["id"], d["exit"])
	if h["id"] == "borin":
		Objectives.set_current("open_bag")
