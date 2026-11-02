## SkillSys — one progression framework for the player and hirelings.
## EN: A skill set is {skill_id: {"lvl": int, "xp": int}}. XP needed for the next level follows
##     base * level^exp (data/skills.json). Level-ups emit Events.skill_level_up.
## DA: Et færdighedssæt er {færdighed: {"lvl", "xp"}}. Erfaring til næste niveau følger
##     base * niveau^eksponent (data/skills.json). Niveaustigninger udsender et signal.
class_name SkillSys
extends RefCounted


static func new_set(levels: Dictionary) -> Dictionary:
	var s := {}
	for sk in DB.skill_list:
		s[sk["id"]] = {"lvl": int(levels.get(sk["id"], 0)), "xp": 0}
	return s


static func xp_needed(lvl: int) -> int:
	var c := DB.skill_curve
	return int(float(c.get("base", 60)) * pow(max(lvl, 1), float(c.get("exp", 1.45))))


static func level(sset: Dictionary, skill: String) -> int:
	return int(sset.get(skill, {}).get("lvl", 0))


static func progress(sset: Dictionary, skill: String) -> float:
	var e: Dictionary = sset.get(skill, {"lvl": 0, "xp": 0})
	return float(e["xp"]) / float(xp_needed(int(e["lvl"]) + 1))


## Adds XP; returns number of levels gained.
static func add_xp(sset: Dictionary, skill: String, amount: int, who: String) -> int:
	if not sset.has(skill):
		sset[skill] = {"lvl": 0, "xp": 0}
	var e: Dictionary = sset[skill]
	var max_lvl := int(DB.skill_curve.get("max_level", 20))
	e["xp"] = int(e["xp"]) + amount
	var gained := 0
	while int(e["lvl"]) < max_lvl and int(e["xp"]) >= xp_needed(int(e["lvl"]) + 1):
		e["xp"] = int(e["xp"]) - xp_needed(int(e["lvl"]) + 1)
		e["lvl"] = int(e["lvl"]) + 1
		gained += 1
		Events.skill_level_up.emit(who, skill, int(e["lvl"]))
	return gained


static func skill_name(skill: String) -> String:
	return DB.skills.get(skill, {}).get("name", skill.capitalize())
