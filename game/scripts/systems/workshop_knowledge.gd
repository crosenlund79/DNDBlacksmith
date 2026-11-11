## WorkshopKnowledge — what the forge knows (The Living Workshop B2; canonical §4.2 row 2, §5, D3; register STAFF-017).
## EN: The workshop's shared catalogue: the Designs it can plan (internal key: recipes), the stations it knows how to
##     set up and work, and its techniques — each with the day it came in and the worker it came in through. The
##     catalogue is separate from anyone's competence and never grants it:
##       - Designs and stations belong to the workshop as a whole. WHO may make a Design is a question of personal
##         competence (Workers.can_do: the worker's own levels, rank, station skills), never of this catalogue.
##       - Techniques. A method (no craftsmanship bonus: "mithril can be charged at the Arcane Crucible") is simply
##         known. A technique WITH a bonus helps a worker's own work only: on the smith's own path (Traditional Smithing,
##         Mining & Metallurgy) it is his personal mastery — his alone; in another craft it helps whoever performs the
##         work at the node's skill level, by their OWN level (a runesmith's Runecraft 6 lets them use Master
##         Runecrafting; the workshop knowing it does not make the smith, at his basic Runecraft, a master runewright).
##     Knowledge comes in through the Skill Tree (SkillTree.unlock: the smith's own path through his own levels; the
##     other crafts through a competent worker — the smith at his basic level or a specialist on the staff), and for old
##     saves from the tree's learned nodes (save step 6, SaveMigrations.migrate_workshop_knowledge). Secret Designs stay
##     hidden until their discovery (the recipe's requires_flag), whatever the catalogue holds.
##     State: Game.state["workshop_knowledge"] = {
##       "nodes":      {node id: {"day", "by"}}               tree knowledge taken in ("by": an actor id, "player" = the smith)
##       "designs":    {recipe id: {"day", "node", "by"}}
##       "stations":   {station id: {"day", "node", "by"}}
##       "techniques": {technique id: {"day", "node", "by"}} }
##     Created lazily and kept in step with the tree's learned nodes (developer tools, older tests); save step 6 writes it
##     explicitly for older saves. Nothing is ever removed in play.
## DA: Værkstedets fælles viden: kendte Designs, stationer og teknikker — hvornår og gennem hvem. Adskilt fra den
##     enkeltes kompetence og giver den aldrig: en teknik med kvalitetsbonus hjælper kun den, der selv har niveauet
##     (smedens egen sti er hans personlige mesterskab).
class_name WorkshopKnowledge
extends RefCounted

const KINDS := ["designs", "stations", "techniques"]


# ======================================================================= state
static func _empty() -> Dictionary:
	return {"nodes": {}, "designs": {}, "stations": {}, "techniques": {}}


## The catalogue (created lazily; kept in step with the tree's learned nodes).
static func st() -> Dictionary:
	if Game.state.is_empty():
		return _empty()
	if not Game.state.get("workshop_knowledge") is Dictionary:
		Game.state["workshop_knowledge"] = _empty()
	var k: Dictionary = Game.state["workshop_knowledge"]
	for key in ["nodes", "designs", "stations", "techniques"]:
		if not k.get(key) is Dictionary:
			k[key] = {}
	if (k["nodes"] as Dictionary).size() != SkillTree.learned().size():
		_sync(k)
	return k


## Takes in every learned node the catalogue does not hold yet (the smith brought it unless the tree says otherwise) and
## lets go of nodes the tree no longer has (only a developer's reset does that). Returns how many entries were added.
static func _sync(k: Dictionary) -> int:
	var learned := SkillTree.learned()
	var keep := {}
	for id in learned:
		keep[str(id)] = true
	for id in (k["nodes"] as Dictionary).keys():
		if not keep.has(str(id)):
			_forget_node(k, str(id))
	var tree: Dictionary = Game.state.get("skilltree", {}) if Game.state.get("skilltree") is Dictionary else {}
	var by: Dictionary = tree.get("by", {}) if tree.get("by") is Dictionary else {}
	var days: Dictionary = tree.get("day", {}) if tree.get("day") is Dictionary else {}
	var n := 0
	for id in learned:
		if not (k["nodes"] as Dictionary).has(str(id)):
			n += _absorb(k, str(id), str(by.get(id, "player")), int(days.get(id, 0)))
	return n


## Re-reads the tree into the catalogue (after the tree itself was rebuilt, e.g. a legacy save's SkillTree.ensure).
static func resync() -> void:
	if Game.state.is_empty():
		return
	if not Game.state.get("workshop_knowledge") is Dictionary:
		Game.state["workshop_knowledge"] = _empty()
	var k: Dictionary = Game.state["workshop_knowledge"]
	for key in ["nodes", "designs", "stations", "techniques"]:
		if not k.get(key) is Dictionary:
			k[key] = {}
	_sync(k)


## Adds a node's Designs, stations and techniques (an entry already known keeps its first record). Returns how many.
static func _absorb(k: Dictionary, nid: String, by: String, day: int) -> int:
	var n := SkillTree.node(nid)
	(k["nodes"] as Dictionary)[nid] = {"day": day, "by": by}
	if n.is_empty():
		return 0
	var u: Dictionary = n.get("unlocks", {})
	var added := 0
	var lists := {"designs": u.get("recipes", []), "stations": u.get("stations", []), "techniques": u.get("techniques", [])}
	for kind in lists:
		var into: Dictionary = k[kind]
		for e in lists[kind]:
			var eid := str((e as Dictionary).get("id", "")) if e is Dictionary else str(e)
			if eid != "" and not into.has(eid):
				into[eid] = {"day": day, "node": nid, "by": by}
				added += 1
	return added


static func _forget_node(k: Dictionary, nid: String) -> void:
	(k["nodes"] as Dictionary).erase(nid)
	for kind in KINDS:
		var d: Dictionary = k[kind]
		for eid in d.keys():
			if str((d[eid] as Dictionary).get("node", "")) == nid:
				d.erase(eid)


## Records that the workshop learned tree node `nid` through actor `by` today (SkillTree._learn).
static func learn_node(nid: String, by: String) -> void:
	if Game.state.is_empty():
		return
	var k := st()
	if (k["nodes"] as Dictionary).has(nid):
		return
	_absorb(k, nid, by, Game.day())


## Back to nothing but the given nodes (SkillTree.reset_new / init_new).
static func reset_to(nodes: Array) -> void:
	if Game.state.is_empty():
		return
	var k := _empty()
	Game.state["workshop_knowledge"] = k
	for id in nodes:
		_absorb(k, str(id), "player", 0)


# ======================================================================= questions
static func knows_node(nid: String) -> bool:
	return (st()["nodes"] as Dictionary).has(nid)


## Does the workshop know this Design? A secret Design is unknown until its discovery; content no tree node teaches
## (another module's) is common knowledge.
static func knows_design(rid: String) -> bool:
	if not SkillTree.recipe_visible(rid):
		return false
	if SkillTree.recipe_node(rid) == "":
		return true
	return (st()["designs"] as Dictionary).has(rid)


static func knows_station(sid: String) -> bool:
	if SkillTree.station_node(sid) == "":
		return true
	return (st()["stations"] as Dictionary).has(sid)


static func knows_technique(tid: String) -> bool:
	return (st()["techniques"] as Dictionary).has(tid)


## "" when the workshop knows the Design, otherwise why not and where it is learned.
static func design_reason(rid: String) -> String:
	if DB.recipe(rid).is_empty():
		return "Unknown Design."
	if not SkillTree.recipe_visible(rid):
		return "A forgotten Design — find its notes among the relics"
	if Game.state.is_empty() or knows_design(rid):
		return ""
	return node_reason(SkillTree.recipe_node(rid))


## "" when the workshop knows how to set up and work the station (not whether it is bought — Property), else the reason.
static func station_reason(sid: String) -> String:
	if Game.state.is_empty() or knows_station(sid):
		return ""
	return node_reason(SkillTree.station_node(sid))


## "Skill tree: learn «Steelworking» (Traditional Smithing)".
static func node_reason(nid: String) -> String:
	var n := SkillTree.node(nid)
	return "Skill tree: learn «%s» (%s)" % [n.get("name", nid), SkillTree.branch(str(n.get("branch", ""))).get("name", "")]


## The catalogue entry of a Design/station/technique ({} when unknown): {"day", "node", "by"}.
static func entry(kind: String, id: String) -> Dictionary:
	var d: Variant = st().get(kind, {})
	return ((d as Dictionary).get(id, {}) as Dictionary) if d is Dictionary else {}


## Who the workshop learned a node through ("player" = the smith; "" = not known).
static func brought_by(nid: String) -> String:
	return str(((st()["nodes"] as Dictionary).get(nid, {}) as Dictionary).get("by", ""))


## "the smith" / "Edda Vell (runesmith)" / "Edda Vell, who has left" — for lines in the interface.
static func who_text(actor_id: String) -> String:
	if actor_id == "" or actor_id == "player":
		return "the smith"
	var a := Workers.resolve(actor_id)
	if str(a["kind"]) == "":
		var gone := _former(actor_id)
		return ("%s, no longer on the staff" % gone) if gone != "" else "a former worker"
	var p := Workers.profession(a)
	return "%s (%s)" % [a["name"], Workers.profession_name(p).to_lower()] if p != "" else str(a["name"])


static func _former(actor_id: String) -> String:
	var ap: Variant = Game.state.get("apprentices", {})
	if ap is Dictionary:
		for key in ["staff", "alumni"]:
			for a in (ap as Dictionary).get(key, []):
				if a is Dictionary and str(a.get("id", "")) == actor_id:
					return str(a.get("name", ""))
	return ""


## Nodes the workshop learned through this worker (their credit), oldest first.
static func credit(actor_id: String) -> Array:
	var out := []
	var nodes: Dictionary = st()["nodes"]
	for nid in nodes:
		if str((nodes[nid] as Dictionary).get("by", "")) == actor_id:
			out.append(str(nid))
	out.sort_custom(func(a, b): return int(nodes[a].get("day", 0)) < int(nodes[b].get("day", 0)) or (int(nodes[a].get("day", 0)) == int(nodes[b].get("day", 0)) and str(a) < str(b)))
	return out


# ======================================================================= who brings a node in
## "smith" (the smith's own path: his personal levels and techniques) or "workshop" (another craft's knowledge).
static func branch_owner(bid: String) -> String:
	return str(SkillTree.branch(bid).get("owner", "smith" if bid in ["smithing", "mining"] else "workshop"))


static func node_owner(nid: String) -> String:
	return branch_owner(str(SkillTree.node(nid).get("branch", "")))


## The worker the workshop would learn this node through now: the smith on his own path (and for nodes that ask no
## level); in another craft the most competent hand on the staff (the smith on a tie). "" when nobody meets its level.
static func bearer(nid: String) -> String:
	var n := SkillTree.node(nid)
	if n.is_empty():
		return ""
	var sk: Array = (n.get("requires", {}) as Dictionary).get("skill", [])
	if node_owner(nid) == "smith" or sk.is_empty():
		return "player" if sk.is_empty() or Workers.level("player", str(sk[0])) >= int(sk[1]) else ""
	var best := Workers.best_level(str(sk[0]))
	return str(best["actor"]) if int(best["level"]) >= int(sk[1]) else ""


# ======================================================================= techniques
## Does a technique taught by tree node `nid` help this worker's own work? On the smith's own path: the smith only (his
## personal mastery). In another craft: any workshop worker whose OWN level meets the node's requirement.
static func technique_applies(actor: Variant, nid: String) -> bool:
	var n := SkillTree.node(nid)
	var k := Workers.kind(actor)
	if n.is_empty() or k == "" or k == "hireling":
		return false
	if node_owner(nid) == "smith":
		return k == "player"
	var sk: Array = (n.get("requires", {}) as Dictionary).get("skill", [])
	return sk.is_empty() or Workers.level(actor, str(sk[0])) >= int(sk[1])


## Craftsmanship techniques that help `actor` on Design `rid`: the workshop knows them and they apply to the actor.
## Each: the technique dictionary + {"node", "personal" (the smith's own path)}.
static func techniques_for(rid: String, actor: Variant = "player") -> Array:
	var out := []
	var r := DB.recipe(rid)
	if r.is_empty() or Game.state.is_empty():
		return out
	var known: Dictionary = st()["techniques"]
	for tid in known:
		var nid := str((known[tid] as Dictionary).get("node", ""))
		for t in SkillTree.node(nid).get("unlocks", {}).get("techniques", []):
			if str(t.get("id", "")) != str(tid) or float(t.get("quality", 0)) <= 0.0:
				continue
			if SkillTree.technique_matches(t, r) and technique_applies(actor, nid):
				var e: Dictionary = (t as Dictionary).duplicate()
				e["node"] = nid
				e["personal"] = node_owner(nid) == "smith"
				out.append(e)
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


## Craftsmanship bonus (percentage points) from the techniques that help `actor` on Design `rid`.
static func quality_bonus(rid: String, actor: Variant = "player") -> float:
	var b := 0.0
	for t in techniques_for(rid, actor):
		b += float(t.get("quality", 0))
	return b


## Techniques the workshop knows that do NOT help this actor on this Design for want of their own level, as
## [{name, need: "Runecraft 6", node}] — for honest tooltips ("the workshop knows it; mastery is the runesmith's").
static func techniques_beyond(rid: String, actor: Variant = "player") -> Array:
	var out := []
	var r := DB.recipe(rid)
	if r.is_empty() or Game.state.is_empty():
		return out
	var known: Dictionary = st()["techniques"]
	for tid in known:
		var nid := str((known[tid] as Dictionary).get("node", ""))
		if node_owner(nid) == "smith":
			continue
		for t in SkillTree.node(nid).get("unlocks", {}).get("techniques", []):
			if str(t.get("id", "")) != str(tid) or float(t.get("quality", 0)) <= 0.0 or not SkillTree.technique_matches(t, r):
				continue
			if not technique_applies(actor, nid):
				var sk: Array = SkillTree.node(nid)["requires"].get("skill", ["", 0])
				out.append({"name": str(t.get("name", "")), "need": "%s %d" % [SkillSys.skill_name(str(sk[0])), int(sk[1])], "node": nid})
	return out


# ======================================================================= the catalogue, for views
## Known Designs (visible ones), grouped by discipline: {discipline: [recipe ids sorted by name]}.
static func designs_by_discipline() -> Dictionary:
	var out := {}
	for rid in DB.recipes:
		if not knows_design(str(rid)):
			continue
		var disc := str(DB.recipe(str(rid)).get("discipline", "classic"))
		if not out.has(disc):
			out[disc] = []
		(out[disc] as Array).append(str(rid))
	for d in out:
		(out[d] as Array).sort_custom(func(a, b): return str(DB.recipe(a).get("name", a)) < str(DB.recipe(b).get("name", b)))
	return out


## The materials the workshop's known Designs work, by material id: {material id: name}.
static func materials() -> Dictionary:
	var out := {}
	var mats: Dictionary = Crafting.cfg("materials")
	for rid in DB.recipes:
		if knows_design(str(rid)):
			var m := str(DB.recipe(str(rid)).get("material", ""))
			if m != "" and mats.has(m):
				out[m] = str((mats[m] as Dictionary).get("name", m))
	return out


## Discoveries the tree asks for (rune lore, dragon lore, the starsteel notes …) that the smith has made:
## [{flag, name, hint}]. Undiscovered secrets are not listed.
static func discoveries() -> Array:
	var out := []
	var flags: Dictionary = SkillTree.data().get("flags", {})
	for f in flags:
		if Game.has_flag(str(f)):
			out.append({"flag": str(f), "name": str((flags[f] as Dictionary).get("name", f)), "hint": str((flags[f] as Dictionary).get("hint", ""))})
	return out


## Counts for headers: {"designs", "designs_total" (visible ones), "stations", "techniques"}.
static func counts() -> Dictionary:
	var vis := 0
	var known := 0
	for rid in DB.recipes:
		if SkillTree.recipe_visible(str(rid)):
			vis += 1
			if knows_design(str(rid)):
				known += 1
	var k := st()
	return {"designs": known, "designs_total": vis, "stations": (k["stations"] as Dictionary).size(), "techniques": (k["techniques"] as Dictionary).size()}


# ======================================================================= specialist progression
## The level a newcomer of a discipline needs for its easiest Design (difficulty less the apprentices' reach). An
## applicant arrives with at least this in their own craft, so every profession has work of its own from the first day
## (B2: an arcanist's easiest Design, Charge Mithril, asks Arcane Metalworking 3; applicants came with 1–2 and could
## never begin their own craft).
static func entry_level(discipline: String) -> int:
	var lo := -1
	for r in DB.recipes.values():
		if str(r.get("discipline", "")) != discipline:
			continue
		var need := maxi(0, Crafting.difficulty(str(r["id"])) - Workers.reach())
		if lo < 0 or need < lo:
			lo = need
	return maxi(lo, 0)


# ======================================================================= save step 6
## Save step v5 → v6 "workshop knowledge" (runs with Game.state bound to the save): every node the old save learned — the
## secret ones and their discoveries included — becomes the workshop's knowledge, with its Designs, stations and
## techniques, through the smith (who learned everything in older saves) on the day the tree recorded. Nothing is
## removed; the tree, flags and every level stay as they were. Idempotent. Returns how many entries were added.
static func migrate_state() -> int:
	if Game.state.is_empty() or not Game.state.get("player") is Dictionary:
		return 0
	if not Game.state.get("workshop_knowledge") is Dictionary:
		Game.state["workshop_knowledge"] = _empty()
	var k: Dictionary = Game.state["workshop_knowledge"]
	for key in ["nodes", "designs", "stations", "techniques"]:
		if not k.get(key) is Dictionary:
			k[key] = {}
	var tree: Dictionary = Game.state.get("skilltree", {}) if Game.state.get("skilltree") is Dictionary else {}
	var by: Dictionary = tree.get("by", {}) if tree.get("by") is Dictionary else {}
	var days: Dictionary = tree.get("day", {}) if tree.get("day") is Dictionary else {}
	var n := 0
	for id in SkillTree.learned():
		var nid := str(id)
		if (k["nodes"] as Dictionary).has(nid):
			# a node already taken in still contributes anything it teaches that the catalogue lacks (idempotent)
			var rec: Dictionary = k["nodes"][nid]
			n += _absorb(k, nid, str(rec.get("by", "player")), int(rec.get("day", 0)))
			continue
		n += _absorb(k, nid, str(by.get(id, "player")), int(days.get(id, 0)))
	return n
