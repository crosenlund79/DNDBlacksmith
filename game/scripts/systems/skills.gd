## SkillSys — one progression framework for the player, apprentices and hirelings.
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


## Adds XP; returns number of levels gained. `who` owns the experience ("player", an apprentice or hireling id): a
## workshop worker's craft outside their profession grows only to Workers.BASIC_LEVEL (The Living Workshop B1, D2) —
## at that level new experience is not banked; a level earned above it before B1 is kept, never reduced.
static func add_xp(sset: Dictionary, skill: String, amount: int, who: String) -> int:
	if not sset.has(skill):
		sset[skill] = {"lvl": 0, "xp": 0}
	var e: Dictionary = sset[skill]
	var max_lvl := int(DB.skill_curve.get("max_level", 20))
	var cap := mini(max_lvl, Workers.growth_cap(who, skill))
	if cap < max_lvl and int(e["lvl"]) >= cap:
		return 0   # beyond their profession: no new growth (what they earned stays)
	e["xp"] = int(e["xp"]) + amount
	var gained := 0
	while int(e["lvl"]) < cap and int(e["xp"]) >= xp_needed(int(e["lvl"]) + 1):
		e["xp"] = int(e["xp"]) - xp_needed(int(e["lvl"]) + 1)
		e["lvl"] = int(e["lvl"]) + 1
		gained += 1
		Events.skill_level_up.emit(who, skill, int(e["lvl"]))
	if cap < max_lvl and int(e["lvl"]) >= cap:
		e["xp"] = 0
		Workers.note_basic_reached(who, skill)
	return gained


static func skill_name(skill: String) -> String:
	return DB.skills.get(skill, {}).get("name", skill.capitalize())
