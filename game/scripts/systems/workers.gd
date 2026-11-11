## Workers — the shared worker capability model (The Living Workshop, B1; canonical §4.2–4.3, D1, D2, D7).
## EN: One answer, for every actor in the forge, to "who is this worker, what may they do, and how well?". An actor is
##     "player" (the smith; "smith" is accepted too), a workshop apprentice/specialist (their id "app_<n>" or their
##     dictionary), a field hireling (their id or dictionary) and, later, other helpers ("spouse" — FAMILY, wave 2).
##     The two staff families stay distinct entities (D1); this layer gives them one, mostly derived, profile:
##       profession   one of PROFESSIONS for workshop workers — the smith is the blacksmith; an apprentice's is stored on
##                    them ("profession", migration step 5 / hiring); field hirelings have none, only a read-only field
##                    role derived from their best work skill (they keep their field work unchanged);
##       competence   the actor's OWN skill level per discipline (SkillSys) — never the smith's on their behalf;
##       growth       unlimited in the profession's skills; other crafts stop growing at BASIC_LEVEL (D2: basic other-craft
##                    knowledge, mastery belongs to specialists). Levels earned above it before B1 are kept, never reduced;
##       eligibility  can_do(actor, what) → "" or the reason. The workshop must know the Design (knowledge_reason — today
##                    the skill tree; KNOWLEDGE, wave 2, replaces its internals), the stations must be there and usable
##                    (station_reason), and the actor's competence must meet every operation (competence_reason);
##       checks       check_params(actor, …) and the quality inputs come from the acting worker's level.
##     What an operation asks (op_requirement): the skill of its STATION's discipline; for operations in the Design's
##     own discipline the Design's difficulty less the apprentices' "reach" (data/apprentices.json, 1); for a
##     contribution in another discipline (a grip wrap at the stitching table) only what the Design names in
##     "requires"; station "unlock" skills and Design "requires" always. Who must meet the difficulty part:
##       apprentices/specialists — always (the long-standing apprentice rule, now per operation and per discipline);
##       the smith — in his own craft (smithing, mining) nothing new: the tree and his checks decide, as before; in
##         another craft only work beyond BASIC_LEVEL is closed to him ("needs a runesmith (Runecraft 6) — the smith's
##         runecraft is basic (3)"); basic work stays open at his actual competence (harder checks, rougher results).
##     Workshop knowledge (which Designs the forge knows) is separate from personal competence and never grants it.
## DA: Fælles kapabilitetsmodel for alle der arbejder i smedjen: profession, kompetence pr. disciplin (egen
##     færdighed), vækstloft uden for professionen (BASIC_LEVEL; tidligere optjente niveauer bevares), berettigelse med
##     begrundelse, og prøveparametre og kvalitet fra den faktiske arbejders niveau.
class_name Workers
extends RefCounted

const PROFESSIONS := ["blacksmith", "leatherworker", "runesmith", "alchemist", "arcanist"]
## Profession data: display name, the noun used in reasons, the discipline it owns and the skills it may master.
## Herbalism sits within the alchemist (D7); the leatherworker is also the tailor (tree branches leather + tailoring).
const PROFESSION := {
	"blacksmith": {"name": "Blacksmith", "noun": "blacksmith", "discipline": "classic", "skills": ["smithing", "mining"],
		"desc": "Forging, smelting and metallurgy at the forge, anvil and crucible."},
	"leatherworker": {"name": "Leatherworker & Tailor", "noun": "leatherworker", "discipline": "stitching", "skills": ["enchanted_stitching"],
		"desc": "Hides, leather, textiles, bows and enchanted garments."},
	"runesmith": {"name": "Runesmith", "noun": "runesmith", "discipline": "runecraft", "skills": ["runecraft"],
		"desc": "Cutting, engraving and tuning runestones; setting runes."},
	"alchemist": {"name": "Alchemist & Herbalist", "noun": "alchemist", "discipline": "alchemy", "skills": ["alchemy"],
		"desc": "Oils, potions, reagents and coatings; herb lore (herbalism belongs to the alchemist)."},
	"arcanist": {"name": "Arcanist", "noun": "arcanist", "discipline": "arcane", "skills": ["arcane_metalwork"],
		"desc": "Binding magic into mithril and adamantine; arcane metalworking."},
}
const DISCIPLINE_PROFESSION := {"classic": "blacksmith", "stitching": "leatherworker", "runecraft": "runesmith",
	"alchemy": "alchemist", "arcane": "arcanist"}
## The craft skills (one per discipline). Field skills (mining, travelling, relic_hunting) are not capped by profession.
const CRAFT_SKILLS := ["smithing", "enchanted_stitching", "runecraft", "alchemy", "arcane_metalwork"]
## D2: the level at which a craft outside one's profession stops growing. 5 is the journeyman's grasp
## (apprentices.json: a journeyman needs skill 5, a master 8): the smith can learn nearly the whole workshop catalogue
## and do basic-to-journeyman work in every craft himself, while the top tier of each craft — difficulty 7+ Designs
## (Concord runestone, wyvern and wyrm leather, warded gloves, the archmage's robe, the four arcane masterworks) and the
## two master nodes (Runecraft 6, Tailoring 6) — needs a qualified specialist (node requirements: Workers.tree_level).
const BASIC_LEVEL := 5
## A field hireling's read-only role, from their best work skill.
const FIELD_ROLES := {"mining": "miner", "travelling": "trader", "relic_hunting": "relic hunter", "smithing": "smelter",
	"alchemy": "herb gatherer", "runecraft": "stone splitter"}


# ======================================================================= actors
## {kind: "player" | "apprentice" | "hireling" | "spouse" | "", id, name, data}. `actor` is an id or the entity dictionary.
## FAMILY (Living Workshop #50–51): "spouse" — the smith's spouse, by her own NPC id (one identity; "spouse" and
## "spouse:<id>" are accepted too); `data` is the family record (Family, Game.state["family"]); no apprentice record, no
## employee slot. She is not one of workshop_actors(): she helps at the counter, not at the stations.
static func resolve(actor: Variant) -> Dictionary:
	var none := {"kind": "", "id": "", "name": "", "data": {}}
	if actor is Dictionary:
		var d: Dictionary = actor
		if d.is_empty():
			return none
		if d.has("kind") and d.has("data") and d.has("id"):
			return d   # already resolved
		var did := str(d.get("id", ""))
		if did == "player" or did == "smith":
			return _player()
		if d.has("rank") or did.begins_with("app_"):
			return {"kind": "apprentice", "id": did, "name": str(d.get("name", "")), "data": d}
		if d.has("alloc") or d.has("expedition"):
			return {"kind": "hireling", "id": did, "name": str(d.get("name", "")), "data": d}
		return none
	var s := str(actor)
	if s == "player" or s == "smith":
		return _player()
	if s == "" or Game.state.is_empty():
		return none
	var ap: Variant = Game.state.get("apprentices", {})
	if ap is Dictionary:
		for a in (ap as Dictionary).get("staff", []):
			if str(a.get("id", "")) == s:
				return {"kind": "apprentice", "id": s, "name": str(a.get("name", "")), "data": a}
	for h in Game.state.get("hirelings", []):
		if str(h.get("id", "")) == s:
			return {"kind": "hireling", "id": s, "name": str(h.get("name", "")), "data": h}
	if s == "spouse" or s.begins_with("spouse:") or (not s.begins_with("app_") and Game.state.has("social") and s == Social.spouse()):
		return _spouse(s.trim_prefix("spouse:"))
	return none


static func _player() -> Dictionary:
	var p: Dictionary = Game.state.get("player", {}) if not Game.state.is_empty() else {}
	return {"kind": "player", "id": "player", "name": str(p.get("name", "the smith")), "data": p}


## The smith's spouse as a worker (none when `id` is not the current spouse).
static func _spouse(id: String) -> Dictionary:
	var sp := Social.spouse()
	if sp == "" or (id != "spouse" and id != sp):
		return {"kind": "", "id": "", "name": "", "data": {}}
	var f: Variant = Game.state.get("family", {})
	return {"kind": "spouse", "id": sp, "name": Talk.npc_name(sp), "data": f if f is Dictionary else {}}


static func kind(actor: Variant) -> String:
	return str(resolve(actor)["kind"])


## Every workshop worker: the smith, then the apprentices on the staff (by id).
static func workshop_actors() -> Array:
	var out := ["player"]
	if Game.state.is_empty():
		return out
	var ap: Variant = Game.state.get("apprentices", {})
	if ap is Dictionary:
		for a in (ap as Dictionary).get("staff", []):
			if str(a.get("status", "")) != "gone":
				out.append(str(a.get("id", "")))
	return out


# ======================================================================= professions
static func skill_of(profession: String) -> String:
	return str((PROFESSION.get(profession, {}) as Dictionary).get("skills", ["smithing"])[0])


static func discipline_of(profession: String) -> String:
	return str((PROFESSION.get(profession, {}) as Dictionary).get("discipline", "classic"))


static func profession_name(profession: String) -> String:
	return str((PROFESSION.get(profession, {}) as Dictionary).get("name", profession.capitalize()))


## "a runesmith", "an alchemist", "an arcanist".
static func a_noun(profession: String) -> String:
	var n := str((PROFESSION.get(profession, {}) as Dictionary).get("noun", profession))
	return ("an " if n.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + n


static func discipline_profession(disc: String) -> String:
	return str(DISCIPLINE_PROFESSION.get(disc, "blacksmith"))


static func skill_profession(skill: String) -> String:
	for p in PROFESSIONS:
		if (PROFESSION[p]["skills"] as Array).has(skill):
			return str(p)
	return ""


static func _lvl_in(levels: Dictionary, skill: String) -> int:
	var v: Variant = levels.get(skill, 0)
	if v is Dictionary:
		return int((v as Dictionary).get("lvl", 0))
	return int(v) if (v is int or v is float) else 0


## The profession an existing worker gets (migration step 5; also the lazy fallback): their strongest workshop skill,
## ties going to their preferred discipline, then in PROFESSIONS order (blacksmith first). `levels` may be a SkillSys
## set ({skill: {"lvl", "xp"}}) or plain levels ({skill: int}, applicants).
static func derive_profession(levels: Dictionary, prefs: Array = []) -> String:
	var order := []
	for d in prefs:
		var p := str(DISCIPLINE_PROFESSION.get(str(d), ""))
		if p != "" and not order.has(p):
			order.append(p)
	for p in PROFESSIONS:
		if not order.has(p):
			order.append(p)
	var best := "blacksmith"
	var best_lvl := -1
	for p in order:
		var lv := _lvl_in(levels, skill_of(str(p)))
		if lv > best_lvl:
			best = str(p)
			best_lvl = lv
	return best


## The actor's profession ("" for field hirelings and unknown actors).
static func profession(actor: Variant) -> String:
	var a := resolve(actor)
	match str(a["kind"]):
		"player":
			var pp := str((a["data"] as Dictionary).get("profession", "blacksmith"))
			return pp if PROFESSION.has(pp) else "blacksmith"
		"apprentice":
			var d: Dictionary = a["data"]
			var p := str(d.get("profession", ""))
			if PROFESSION.has(p):
				return p
			return derive_profession(d.get("skills", {}), d.get("prefs", []))
	return ""


## The skills the actor may master (their profession's); [] for field hirelings (their progression is not capped).
static func deep_skills(actor: Variant) -> Array:
	var p := profession(actor)
	return (PROFESSION[p]["skills"] as Array).duplicate() if PROFESSION.has(p) else []


## "Runesmith" / "Blacksmith" — or, for a field hireling, their role ("Miner").
static func title(actor: Variant) -> String:
	var a := resolve(actor)
	if str(a["kind"]) == "hireling":
		return field_role(a).capitalize()
	if str(a["kind"]) == "spouse":
		return "The smith's wife — at the shop counter" if Family.helper() == str(a["id"]) else "The smith's wife"
	var p := profession(a)
	return profession_name(p) if p != "" else ""


## A field hireling's read-only role: their best work skill ("miner", "trader", "relic hunter" …).
static func field_role(actor: Variant) -> String:
	var a := resolve(actor)
	if str(a["kind"]) != "hireling":
		return ""
	var sk: Dictionary = (a["data"] as Dictionary).get("skills", {})
	var best := "mining"
	for s in DB.work_skills:
		if SkillSys.level(sk, str(s)) > SkillSys.level(sk, best):
			best = str(s)
	return str(FIELD_ROLES.get(best, best.replace("_", " ")))


# ======================================================================= competence
## The actor's own level in a skill (0 for unknown actors).
static func level(actor: Variant, skill: String) -> int:
	var a := resolve(actor)
	match str(a["kind"]):
		"player":
			return SkillSys.level((a["data"] as Dictionary).get("skills", {}), skill)
		"apprentice", "hireling", "spouse":
			return SkillSys.level((a["data"] as Dictionary).get("skills", {}), skill)
	return 0


## The level a skill may still grow to through experience (SkillSys.add_xp asks this with the experience's owner).
## A workshop worker's craft skills outside their profession stop at BASIC_LEVEL; everything else (their profession,
## field skills, field hirelings, unknown owners) at the curve's max_level. Never lowers an earned level.
static func growth_cap(who: Variant, skill: String) -> int:
	var mx := int(DB.skill_curve.get("max_level", 20))
	if not CRAFT_SKILLS.has(skill):
		return mx
	var a := resolve(who)
	if not str(a["kind"]) in ["player", "apprentice", "spouse"]:
		return mx
	return mx if deep_skills(a).has(skill) else BASIC_LEVEL


## Can this actor still gain experience in this skill?
static func can_grow(actor: Variant, skill: String) -> bool:
	var cap := growth_cap(actor, skill)
	return cap >= int(DB.skill_curve.get("max_level", 20)) or level(actor, skill) < cap


## Is this skill one the actor's growth is capped in (a craft outside their profession)?
static func is_basic(actor: Variant, skill: String) -> bool:
	return growth_cap(actor, skill) < int(DB.skill_curve.get("max_level", 20))


## The best level in a skill among the workshop's workers: {"level", "actor", "name"} (the smith counts).
static func best_level(skill: String) -> Dictionary:
	var out := {"level": level("player", skill), "actor": "player", "name": "the smith"}
	for id in workshop_actors():
		if str(id) == "player":
			continue
		var lv := level(str(id), skill)
		if lv > int(out["level"]):
			out = {"level": lv, "actor": str(id), "name": str(resolve(str(id))["name"])}
	return out


## The level that meets a skill-tree requirement (the seam KNOWLEDGE, wave 2, builds on). The smith's own craft
## (smithing, mining) and the field skills are his personal tree: his level. Another craft is workshop knowledge that a
## competent worker can bring (lead decision 4: no player-grind deadlocks): the best level on the staff.
static func tree_level(skill: String) -> int:
	if not CRAFT_SKILLS.has(skill) or deep_skills("player").has(skill):
		return level("player", skill)
	return int(best_level(skill)["level"])


# ======================================================================= requirements
static func reach() -> int:
	var d: Variant = DB.extra("apprentices")
	var v: Variant = (d as Dictionary).get("reach", 1) if d is Dictionary else 1
	return int(v) if (v is int or v is float) else 1


## What operation `i` of Design `rid` asks of whoever performs it:
## {op, station, discipline, skill, main (the Design's own discipline), difficulty (the level the Design's difficulty
##  asks: difficulty − reach, main operations only), explicit (what the Design or the station names outright), level
##  (the larger), profession (who owns that discipline), advanced (difficulty beyond BASIC_LEVEL)}. {} = no such op.
static func op_requirement(rid: String, i: int) -> Dictionary:
	var ops := Crafting.operations(rid)
	if i < 0 or i >= ops.size():
		return {}
	var o: Dictionary = ops[i]
	var r := DB.recipe(rid)
	var sid := str(o.get("station", ""))
	var disc := str(DB.station(sid).get("discipline", "classic"))
	var skill := Crafting.skill_for_station(sid)
	var main := disc == str(r.get("discipline", "classic"))
	var diff_need := maxi(0, Crafting.difficulty(rid) - reach()) if main else 0
	var explicit := int((r.get("requires", {}) as Dictionary).get(skill, 0))
	var u: Dictionary = r.get("unlock", {})
	if u.has("skill") and str((u["skill"] as Array)[0]) == skill:
		explicit = maxi(explicit, int((u["skill"] as Array)[1]))
	var su: Dictionary = DB.station(sid).get("unlock", {})
	if su.has("skill") and str((su["skill"] as Array)[0]) == skill:
		explicit = maxi(explicit, int((su["skill"] as Array)[1]))
	return {"op": str(o.get("op", "")), "station": sid, "discipline": disc, "skill": skill, "main": main,
		"difficulty": diff_need, "explicit": explicit, "level": maxi(diff_need, explicit),
		"profession": discipline_profession(disc), "advanced": main and diff_need > BASIC_LEVEL}


## Every requirement of a Design, one per operation (see op_requirement).
static func requirements(rid: String) -> Array:
	var out := []
	for i in Crafting.operations(rid).size():
		out.append(op_requirement(rid, i))
	return out


# ======================================================================= eligibility
## Does the workshop know this Design? "" = yes, otherwise why not. Workshop knowledge, not anyone's competence:
## today the skill tree's recipe node and a secret Design's notes (KNOWLEDGE, wave 2, replaces the internals).
static func knowledge_reason(rid: String) -> String:
	var r := DB.recipe(rid)
	if r.is_empty():
		return "Unknown Design."
	var tr := SkillTree.recipe_reason(rid)
	if tr != "":
		return tr
	var rf := str(r.get("requires_flag", ""))
	if rf != "" and not Game.has_flag(rf):
		return "A forgotten recipe — find its notes among the relics"
	return ""


## Is the station there and known to the workshop (owned room, installed, learned in the tree, its upgrade bought)?
## "" = yes. No one's competence.
static func workshop_station_reason(sid: String) -> String:
	var pr := Property.station_reason(sid)
	if pr != "":
		return pr
	var tr := SkillTree.station_reason(sid)
	if tr != "":
		return tr
	var u: Dictionary = DB.station(sid).get("unlock", {})
	if u.has("upgrade") and not Game.has_upgrade(str(u["upgrade"])):
		return "Requires workshop upgrade: " + str(DB.upgrades.get(str(u["upgrade"]), {}).get("name", u["upgrade"]))
	return ""


## May this actor work at this station? The workshop part (workshop_station_reason), then the actor's competence for a
## station that names a skill ("unlock": {"skill": [id, level]}). "" = yes.
static func station_reason(actor: Variant, sid: String) -> String:
	var w := workshop_station_reason(sid)
	if w != "":
		return w
	var a := resolve(actor)
	if str(a["kind"]) == "hireling":
		return "%s is a field hireling — workshop stations are for the workshop's own hands." % a["name"]
	if str(a["kind"]) == "":
		return "Unknown worker."
	var u: Dictionary = DB.station(sid).get("unlock", {})
	if u.has("skill"):
		var sk: Array = u["skill"]
		if level(a, str(sk[0])) < int(sk[1]):
			return _needs(a, str(sk[0]), int(sk[1]))
	return ""


## The workshop can make this Design if it knows it and its stations are there (nobody's competence): "" = yes.
static func workshop_reason(rid: String) -> String:
	var k := knowledge_reason(rid)
	if k != "":
		return k
	var seen := {}
	for o in Crafting.operations(rid):
		var sid := str(o.get("station", ""))
		if seen.has(sid):
			continue
		seen[sid] = true
		var why := workshop_station_reason(sid)
		if why != "":
			return str(DB.station(sid).get("name", sid)) + " — " + why
	return ""


## The actor's competence for a Design (op = -1: every operation, as one worker makes it today) or for one operation
## (a stage of a work order — PRODUCTION, wave 2). Apprentices also meet their rank's rules (Apprentices.rank_reason)
## for a whole Design. Not the workshop's knowledge, not the stations. "" = competent.
static func competence_reason(actor: Variant, rid: String, op := -1) -> String:
	var a := resolve(actor)
	var r := DB.recipe(rid)
	if r.is_empty():
		return "Unknown Design."
	match str(a["kind"]):
		"":
			return "Unknown worker."
		"hireling":
			return "%s is a field hireling — workshop work needs a workshop worker." % a["name"]
		"spouse":
			return _spouse_competence(a, rid, op)
		"apprentice":
			if op < 0:
				var rr := Apprentices.rank_reason(a["data"], rid)
				if rr != "":
					return rr
	var is_player := str(a["kind"]) == "player"
	if op < 0:
		# everything the Design names outright (a whole Design: every skill it lists)
		var req: Dictionary = r.get("requires", {})
		for sk in req:
			if level(a, str(sk)) < int(req[sk]):
				return _needs(a, str(sk), int(req[sk]))
		var u: Dictionary = r.get("unlock", {})
		if u.has("skill"):
			var usk: Array = u["skill"]
			if level(a, str(usk[0])) < int(usk[1]):
				return _needs(a, str(usk[0]), int(usk[1]))
	var idx := []
	if op < 0:
		idx = range(Crafting.operations(rid).size())
	else:
		idx = [op]
	for i in idx:
		var q := op_requirement(rid, int(i))
		if q.is_empty():
			return "No such operation."
		var have := level(a, str(q["skill"]))
		if op >= 0 and have < int(q["explicit"]):
			return _needs(a, str(q["skill"]), int(q["explicit"]))
		if not bool(q["main"]) or int(q["difficulty"]) <= 0 or have >= int(q["difficulty"]):
			continue
		if is_player:
			# his own craft: the tree and his checks decide (unchanged); another craft: basic work stays open to him
			if deep_skills(a).has(str(q["skill"])) or int(q["difficulty"]) <= BASIC_LEVEL:
				continue
			return specialist_text(a, q, rid if op < 0 else "")
		return _needs(a, str(q["skill"]), int(q["difficulty"]))
	return ""


## The spouse helps at the counter; craft work only with her own competence: at least a first level in every
## operation's skill (she was never taught a craft) and whatever the operation or Design asks of it.
static func _spouse_competence(a: Dictionary, rid: String, op: int) -> String:
	var idx := []
	if op < 0:
		idx = range(Crafting.operations(rid).size())
	else:
		idx = [op]
	for i in idx:
		var q := op_requirement(rid, int(i))
		if q.is_empty():
			return "No such operation."
		var need := maxi(1, maxi(int(q["explicit"]), int(q["difficulty"]) if bool(q["main"]) else 0))
		if level(a, str(q["skill"])) < need:
			return "%s helps at the shop counter — she has no %s (%s %d needed)." % [str(a["name"]).split(" ")[0],
				SkillSys.skill_name(str(q["skill"])).to_lower(), SkillSys.skill_name(str(q["skill"])), need]
	return ""


## The one eligibility question. `what`: a Design id or {"recipe": id} (the whole Design, one worker), {"recipe": id,
## "op": i} (one operation / stage), or {"station": id} (working at a station). "" = yes, otherwise the reason.
## Order: the workshop's knowledge, the actor's competence (rank rules, named requirements, each operation), the
## stations (installed, learned, upgraded, the actor's station skill).
static func can_do(actor: Variant, what: Variant) -> String:
	var w: Dictionary = {}
	if what is Dictionary:
		w = what
	else:
		w = {"recipe": str(what)}
	var a := resolve(actor)
	if str(a["kind"]) == "":
		return "Unknown worker."
	if w.has("station") and not w.has("recipe"):
		return station_reason(a, str(w["station"]))
	var rid := str(w.get("recipe", ""))
	var k := knowledge_reason(rid)
	if k != "":
		return k
	var op := int(w.get("op", -1))
	var c := competence_reason(a, rid, op)
	if c != "":
		return c
	var sids := []
	var ops := Crafting.operations(rid)
	if op >= 0:
		sids = [str(ops[op].get("station", ""))]
	else:
		for o in ops:
			if not sids.has(str(o.get("station", ""))):
				sids.append(str(o.get("station", "")))
	for sid in sids:
		var why := station_reason(a, str(sid))
		if why != "":
			return str(DB.station(str(sid)).get("name", sid)) + " — " + why
	return ""


## Every workshop worker who may do `what` now (ids; the smith first). Availability (shift, busy) is not considered.
static func who_can(what: Variant) -> Array:
	var out := []
	for id in workshop_actors():
		if can_do(str(id), what) == "":
			out.append(str(id))
	return out


## "" when someone in the workshop (the smith or a specialist) can do it, otherwise the smith's own reason.
static func workshop_can(what: Variant) -> String:
	var mine := can_do("player", what)
	if mine == "":
		return ""
	for id in workshop_actors():
		if str(id) != "player" and can_do(str(id), what) == "":
			return ""
	return mine


# ======================================================================= reason texts
## "Requires Runecraft 2" (the smith — the long-standing wording) / "Needs Runecraft 2 (has 1)." (anyone else).
static func _needs(a: Dictionary, skill: String, need: int) -> String:
	if str(a["kind"]) == "player":
		return "Requires %s %d" % [SkillSys.skill_name(skill), need]
	return "Needs %s %d (has %d)." % [SkillSys.skill_name(skill), need, level(a, skill)]


## Work beyond the smith's basic grasp of another craft: "Needs a runesmith (Runecraft 6) — the smith's runecraft is
## basic (3)", plus who on the staff can make the Design when `rid` is given.
static func specialist_text(actor: Variant, q: Dictionary, rid := "") -> String:
	var a := resolve(actor)
	var sk := str(q.get("skill", "smithing"))
	var need := int(q.get("level", q.get("difficulty", 0)))
	var have := level(a, sk)
	var whose := "the smith's" if str(a["kind"]) == "player" else "%s's" % str(a["name"]).split(" ")[0]
	var word := ("basic (%d)" % have) if have <= BASIC_LEVEL else str(have)
	var t := "Needs %s (%s %d) — %s %s is %s" % [a_noun(str(q.get("profession", ""))), SkillSys.skill_name(sk), need, whose,
		SkillSys.skill_name(sk).to_lower(), word]
	if rid != "":
		for id in workshop_actors():
			if str(id) != "player" and competence_reason(str(id), rid) == "":
				var who := resolve(str(id))
				t += ". %s (%s) can make it — queue it in the Workshop Ledger" % [who["name"], str(profession(who)).to_lower()]
				break
	return t


## The first operation of a Design that is beyond the smith's basic grasp of another craft (and his actual level):
## its op_requirement, or {} when there is none. Other workers: {} (their "Needs …" reason covers it).
static func specialist_need(actor: Variant, rid: String) -> Dictionary:
	var a := resolve(actor)
	if str(a["kind"]) != "player":
		return {}
	for i in Crafting.operations(rid).size():
		var q := op_requirement(rid, i)
		if bool(q["main"]) and int(q["difficulty"]) > BASIC_LEVEL and not deep_skills(a).has(str(q["skill"])) \
				and level(a, str(q["skill"])) < int(q["difficulty"]):
			return q
	return {}


## The staff member (id) who may make this Design when the smith may not, or "".
static func staff_who_can(rid: String) -> String:
	for id in workshop_actors():
		if str(id) != "player" and competence_reason(str(id), rid) == "":
			return str(id)
	return ""


## The one-line requirement of an operation, for lists: "Engrave the rune — Runecraft 6 (a runesmith's work)".
static func requirement_text(q: Dictionary) -> String:
	if q.is_empty():
		return ""
	var lv := int(q.get("level", 0))
	var t := "%s — %s" % [str(q.get("op", "")), ("%s %d" % [SkillSys.skill_name(str(q["skill"])), lv]) if lv > 0 else "basic %s" % SkillSys.skill_name(str(q["skill"])).to_lower()]
	if bool(q.get("advanced", false)):
		t += " (%s's work)" % str((PROFESSION.get(str(q["profession"]), {}) as Dictionary).get("noun", "specialist"))
	return t


# ======================================================================= checks, quality, experience
## Check parameters for this actor at a station (zone, speed, factors …) — Crafting.check_params with the actor's
## level; the smith's fatigue applies to the smith only.
static func check_params(actor: Variant, station_id: String, recipe_id := "", checks := -1, opts := {}) -> Dictionary:
	var o: Dictionary = opts.duplicate()
	o["actor"] = actor
	return Crafting.check_params(station_id, recipe_id, checks, o)


## The quality inputs of one operation for this actor: {skill (the station's), level, difficulty (the Design's), gap}.
static func op_quality_inputs(actor: Variant, rid: String, i: int) -> Dictionary:
	var q := op_requirement(rid, i)
	if q.is_empty():
		return {}
	var lv := level(actor, str(q["skill"]))
	var d := Crafting.difficulty(rid)
	return {"skill": str(q["skill"]), "level": lv, "difficulty": d, "gap": lv - d, "station": str(q["station"])}


## The craftsmanship bonus a finished piece gets from its maker's level in the Design's skill (+ the smith's
## techniques and a hireling's assistance — the smith only).
static func skill_bonus(actor: Variant, rid: String) -> float:
	var a := resolve(actor)
	if str(a["kind"]) == "player":
		return Crafting.skill_bonus(rid)
	return float(Crafting.cfg("skill").get("quality_per_level", 0.4)) * level(a, Crafting.recipe_skill(rid))


## Expected craftsmanship of operation `i` by a simulated worker (apprentices/specialists); -1 for the smith, whose
## own checks are played (the steward's smith: StewardSmith).
static func expected_op_quality(actor: Variant, rid: String, i: int, supervised := false) -> float:
	var a := resolve(actor)
	if str(a["kind"]) != "apprentice":
		return -1.0
	var q := op_requirement(rid, i)
	return Apprentices.expected_op_quality(a["data"], rid, str(q.get("station", "")), supervised)


## Experience for an actor, through their own family's rules (the smith: Game.grant_player_xp with the steward's
## zero-XP guard; apprentices: traits; hirelings: traits and potential) — the growth cap applies in SkillSys.add_xp.
static func grant_xp(actor: Variant, skill: String, amount: float) -> void:
	var a := resolve(actor)
	match str(a["kind"]):
		"player":
			Game.grant_player_xp(skill, int(round(amount)))
		"apprentice":
			Apprentices.add_xp(a["data"], skill, amount)
		"hireling":
			Hire.add_xp(a["data"], skill, int(round(amount)))
		# "spouse": counter work is no craft — she gains no craft experience from it


## Called by SkillSys.add_xp when an actor's capped craft reaches BASIC_LEVEL: said once per actor and skill.
static func note_basic_reached(who: Variant, skill: String) -> void:
	var a := resolve(who)
	if not str(a["kind"]) in ["player", "apprentice"] or Game.state.is_empty():
		return
	var d: Dictionary = a["data"]
	if not d.has("basic_noted"):
		d["basic_noted"] = {}
	if bool((d["basic_noted"] as Dictionary).get(skill, false)):
		return
	d["basic_noted"][skill] = true
	var prof := discipline_profession(_skill_discipline(skill))
	if str(a["kind"]) == "player":
		var line := "My %s is as good as a smith's gets (%d). Mastery of it belongs to %s." % [SkillSys.skill_name(skill).to_lower(), BASIC_LEVEL, a_noun(prof)]
		Game.journal(line)
		Events.toast.emit(line, "info")
	else:
		Apprentices.log_line(str(a["id"]), "%s has learned what %s can of %s; mastery belongs to %s." % [a["name"],
			a_noun(profession(a)), SkillSys.skill_name(skill).to_lower(), a_noun(prof)])


static func _skill_discipline(skill: String) -> String:
	for d in Crafting.DISCIPLINE_SKILL:
		if str(Crafting.DISCIPLINE_SKILL[d]) == skill:
			return str(d)
	return "classic"


# ======================================================================= profile
## The shared worker profile (read-only view): {id, name, kind, family "workshop"/"field", profession, profession_name,
## title, rank (apprentices), deep [skills they may master], basic_level, competence {craft skill: level},
## basic [craft skills capped for them], field_role (hirelings), read_only (hirelings: nothing here is editable)}.
static func profile(actor: Variant) -> Dictionary:
	var a := resolve(actor)
	var k := str(a["kind"])
	if k == "":
		return {}
	var comp := {}
	var basic := []
	for sk in CRAFT_SKILLS:
		comp[sk] = level(a, str(sk))
		if k != "hireling" and is_basic(a, str(sk)):
			basic.append(str(sk))
	var out := {"id": str(a["id"]), "name": str(a["name"]), "kind": k, "family": "field" if k == "hireling" else ("family" if k == "spouse" else "workshop"),
		"profession": profession(a), "profession_name": profession_name(profession(a)) if profession(a) != "" else "",
		"title": title(a), "rank": "", "deep": deep_skills(a), "basic_level": BASIC_LEVEL, "competence": comp, "basic": basic,
		"field_role": field_role(a), "read_only": k in ["hireling", "spouse"]}
	if k == "apprentice":
		out["rank"] = Apprentices.rank_name(a["data"])
	if k == "player":
		out["rank"] = "master of the forge"
	return out


# ======================================================================= migration (save schema 5)
## Save step v4 → v5 "worker professions": the smith is the blacksmith; every apprentice on the staff, every former
## apprentice and every waiting applicant without a profession gets one (derive_profession). Nothing else is touched:
## levels, experience, traits, wages, ranks, logs, memories, creations, tasks and contract hours stay as they were;
## field hirelings are unchanged (their profile is derived). Idempotent. Returns how many workers were given one.
static func migrate_professions(data: Dictionary) -> int:
	var n := 0
	var p: Variant = data.get("player", null)
	if p is Dictionary and not PROFESSION.has(str((p as Dictionary).get("profession", ""))):
		(p as Dictionary)["profession"] = "blacksmith"
	var ap: Variant = data.get("apprentices", null)
	if not ap is Dictionary:
		return n
	for key in ["staff", "alumni"]:
		for a in (ap as Dictionary).get(key, []):
			if a is Dictionary and not PROFESSION.has(str(a.get("profession", ""))):
				a["profession"] = derive_profession(a.get("skills", {}), a.get("prefs", []))
				n += 1
	for c in (ap as Dictionary).get("applicants", []):
		if c is Dictionary and not PROFESSION.has(str(c.get("profession", ""))):
			c["profession"] = derive_profession(c.get("levels", {}), c.get("prefs", []))
			n += 1
	return n
