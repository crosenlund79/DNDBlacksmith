## SkillTree — the smith's own path and the workshop's knowledge (data/skilltree.json, made by tools/data/make_skilltree.py).
## EN: Seven branches of nodes, of two kinds (The Living Workshop B2; canonical §4.2, §5, D2, D3):
##       the smith's own path (branch "owner": "smith" — Traditional Smithing, Mining & Metallurgy): his personal
##         progression as the blacksmith; a node's skill requirement is HIS level, its techniques are his alone;
##       the workshop's knowledge (owner "workshop" — Arcane Metalworking, Runecrafting, Alchemy, Leatherworking &
##         Enchanted Stitching, Textiles & Tailoring): learned through a competent worker — the smith at his basic
##         level of that craft or a specialist on the staff (Workers.tree_level; the worker it came through is
##         recorded); never a demand that the smith master another profession.
##     A node is learned when its requirements are met — a level in its own branch's craft, prerequisite nodes,
##     knowledge flags, installed stations, materials the workshop has held or hands over, tuition. Learning adds the
##     node's Designs (internal key: recipes), stations (eligible to buy and install) and techniques to the workshop's
##     knowledge (WorkshopKnowledge), which every gate asks; it never raises anyone's competence. Every Design and every
##     station is taught by exactly one node.
##     State: Game.state["skilltree"] = {"nodes": [ids learned], "day": {id: day learned}, "by": {id: actor id} (lazy;
##            absent = the smith)}; Game.state["items_seen"] = {item def: true} (fed by Game.add_item → note_item).
##     Old saves without "skilltree" get every node whose skill requirement they meet (ensure()).
## DA: Smedens egen sti (smedning, minedrift: hans egne niveauer og teknikker) og værkstedets viden om de andre
##     håndværk (lært gennem en kompetent arbejder). En knude åbner Designs, stationer og teknikker i værkstedets
##     viden; den giver aldrig nogen personlig kompetence. Gamle gemte spil får alle knuder hvis færdighedskrav de opfylder.
class_name SkillTree

const RARITY_RANK := {"common": 0, "magic": 1, "rare": 2, "legendary": 3}


# ------------------------------------------------------------------ data
static func data() -> Dictionary:
	var d: Variant = DB.extra("skilltree")
	return d if d is Dictionary else {}


static func nodes() -> Array:
	return data().get("nodes", [])


static func branches() -> Array:
	return data().get("branches", [])


static var _index := {}


static func node(id: String) -> Dictionary:
	if _index.is_empty():
		for n in nodes():
			_index[n["id"]] = n
	return _index.get(id, {})


static func branch(id: String) -> Dictionary:
	for b in branches():
		if b["id"] == id:
			return b
	return {}


static func branch_nodes(bid: String) -> Array:
	return nodes().filter(func(n): return n["branch"] == bid)


## The node that teaches a recipe / a station ("" when none does — e.g. content added by another module).
static func recipe_node(rid: String) -> String:
	return str(data().get("recipe_node", {}).get(rid, ""))


static func station_node(sid: String) -> String:
	return str(data().get("station_node", {}).get(sid, ""))


static func flag_info(f: String) -> Dictionary:
	return data().get("flags", {}).get(f, {"name": f.capitalize(), "hint": ""})


## Nodes that list `id` among their prerequisites.
static func children(id: String) -> Array:
	return nodes().filter(func(n): return (n["requires"].get("nodes", []) as Array).has(id))


# ------------------------------------------------------------------ state
static func _st() -> Dictionary:
	ensure()
	return Game.state["skilltree"]


## New game: the starting nodes only (basic ironworking and ordinary leatherwork).
static func init_new() -> void:
	Game.state["skilltree"] = {"nodes": (data().get("start", []) as Array).duplicate(), "day": {}}
	WorkshopKnowledge.reset_to(data().get("start", []))
	if not Game.state.has("items_seen"):
		Game.state["items_seen"] = {}
	for it in Game.inventory():
		Game.state["items_seen"][str(it["def"])] = true


## Legacy saves (no "skilltree" key): learn every node whose skill requirement is met, so a smith
## keeps the capabilities the old save had. Secret nodes still need their knowledge flags.
static func ensure() -> void:
	if Game.state.is_empty() or Game.state.has("skilltree"):
		return
	var learned: Array = (data().get("start", []) as Array).duplicate()
	for n in nodes():
		if learned.has(n["id"]):
			continue
		if n.get("secret", false) and not _flags_met(n):
			continue
		var sk: Array = n["requires"].get("skill", [])
		if sk.is_empty() or Game.player_level(str(sk[0])) >= int(sk[1]):
			learned.append(n["id"])
	Game.state["skilltree"] = {"nodes": learned, "day": {}, "migrated": true}
	WorkshopKnowledge.resync()   # B2: the rebuilt tree's knowledge is the workshop's
	if not Game.state.has("items_seen"):
		Game.state["items_seen"] = {}
		if Game.state.has("player"):
			for it in Game.inventory():
				Game.state["items_seen"][str(it["def"])] = true


static func learned() -> Array:
	return _st()["nodes"]


static func is_unlocked(id: String) -> bool:
	return learned().has(id)


## Record that the smith has held a material (called from Game.add_item). Studying a dragon's
## scale or bone teaches dragon lore.
static func note_item(def_id: String) -> void:
	if Game.state.is_empty():
		return
	if not Game.state.has("items_seen"):
		Game.state["items_seen"] = {}
	var seen: Dictionary = Game.state["items_seen"]
	if seen.has(def_id):
		return
	seen[def_id] = true
	if def_id in ["dragon_scale", "dragon_bone"] and Game.state.has("flags") and not Game.has_flag("dragon_lore"):
		Game.set_flag("dragon_lore")
		Game.journal("I sat up half the night with the dragon's %s. I think I understand now how the old armourers worked it." % ("scale" if def_id == "dragon_scale" else "bone"))


static func seen(def_id: String) -> bool:
	return bool(Game.state.get("items_seen", {}).get(def_id, false)) or Game.count(def_id) > 0


# ------------------------------------------------------------------ requirements
static func _flags_met(n: Dictionary) -> bool:
	for f in n["requires"].get("flags", []):
		if not Game.has_flag(str(f)):
			return false
	return true


static func _prereqs_met(n: Dictionary) -> bool:
	for p in n["requires"].get("nodes", []):
		if not is_unlocked(str(p)):
			return false
	return true


## One entry per requirement: {"ok": bool, "text": String, "kind": String, "hint": String}.
static func requirements(id: String) -> Array:
	var n := node(id)
	var out := []
	if n.is_empty():
		return out
	var r: Dictionary = n["requires"]
	if r.has("skill"):
		out.append(_skill_requirement(n, r["skill"]))
	for p in r.get("nodes", []):
		var pn := node(str(p))
		out.append({"ok": is_unlocked(str(p)), "kind": "node", "text": "Learned: %s (%s)" % [pn.get("name", p), branch(str(pn.get("branch", ""))).get("name", "")], "hint": ""})
	for f in r.get("flags", []):
		var fi := flag_info(str(f))
		out.append({"ok": Game.has_flag(str(f)), "kind": "flag", "text": "Knowledge: %s — %s" % [fi.get("name", f), fi.get("hint", "")], "hint": str(fi.get("hint", ""))})
	for s in r.get("stations_installed", []):
		out.append({"ok": Property.is_installed(str(s)), "kind": "station", "text": "%s installed" % DB.station(str(s)).get("name", s),
			"hint": "Buy and install it through the workshop (Property)."})
	for d in r.get("items_seen", []):
		out.append({"ok": seen(str(d)), "kind": "seen", "text": "Have held %s at least once" % DB.item(str(d)).get("name", str(d).capitalize().replace("_", " ")),
			"hint": "Suppliers, the herbalist, harbour imports and expeditions bring exotic materials."})
	var items: Dictionary = r.get("items", {})
	for d in items:
		var have_n := Game.count(str(d))
		out.append({"ok": have_n >= int(items[d]), "kind": "items", "text": "Give up %d× %s (you have %d)" % [int(items[d]), DB.item(str(d)).get("name", d), have_n], "hint": "Consumed when learning."})
	if int(r.get("gold", 0)) > 0:
		out.append({"ok": Game.gold() >= int(r["gold"]), "kind": "gold", "text": "Tuition: %d gold (you have %d)" % [int(r["gold"]), Game.gold()], "hint": "Paid when learning."})
	return out


## The skill row of a node's requirements. On the smith's own path: HIS level ("Smithing 6 (you: 5)"). In another
## craft: the workshop's most competent hand meets it — the smith at his basic level, or a specialist on the staff
## ("Runecraft 6 (you: 1 · Edda Vell: 8)"); beyond the smith's basic level the hint names the profession to take on.
## {"ok", "kind": "skill", "text", "hint", "by": the worker it would be learned through ("" = nobody yet), "owner"}.
static func _skill_requirement(n: Dictionary, sk: Array) -> Dictionary:
	var skill := str(sk[0])
	var need := int(sk[1])
	var sname := SkillSys.skill_name(skill)
	var you := Workers.level("player", skill)
	var own := WorkshopKnowledge.node_owner(str(n["id"])) == "smith"
	if own:
		return {"ok": you >= need, "kind": "skill", "owner": "smith", "by": "player" if you >= need else "",
			"text": "%s %d (you: %d)" % [sname, need, you], "hint": "Raise it by your own %s work — your own path as the blacksmith." % sname.to_lower()}
	var best := Workers.best_level(skill)
	var have := maxi(you, int(best["level"]))
	var txt := "%s %d (you: %d)" % [sname, need, you]
	if int(best["level"]) > you:
		txt = "%s %d (you: %d · %s: %d)" % [sname, need, you, str(best["name"]), int(best["level"])]
	var prof := Workers.skill_profession(skill)
	var hint := "Workshop knowledge: any worker with %s %d brings it in — you, or %s on your staff." % [sname, need, Workers.a_noun(prof)]
	if Workers.is_basic("player", skill) and need > Workers.BASIC_LEVEL:
		hint = "Beyond the smith's basic %s — %s on your staff with %s %d meets it." % [sname.to_lower(), Workers.a_noun(prof), sname, need]
	return {"ok": have >= need, "kind": "skill", "owner": "workshop", "by": WorkshopKnowledge.bearer(str(n["id"])), "text": txt, "hint": hint}


## Each requirement as text marked ✓ / ✗.
static func requirements_text(id: String) -> Array[String]:
	var out: Array[String] = []
	for q in requirements(id):
		out.append(("✓ " if q["ok"] else "✗ ") + str(q["text"]))
	return out


## "" when the node can be learned now, otherwise why not (the first unmet requirement).
static func can_unlock(id: String) -> String:
	var n := node(id)
	if n.is_empty():
		return "Unknown skill-tree node."
	if is_unlocked(id):
		return "Already learned."
	for q in requirements(id):
		if not q["ok"]:
			return "Requires " + str(q["text"])
	return ""


## Learns a node (pays tuition, hands over consumed materials). Returns "" on success, else the reason.
static func unlock(id: String) -> String:
	var why := can_unlock(id)
	if why != "":
		return why
	var n := node(id)
	var r: Dictionary = n["requires"]
	if int(r.get("gold", 0)) > 0:
		Game.add_gold(-int(r["gold"]), "training", "Tuition: " + str(n["name"]), "skill_teacher")
	var items: Dictionary = r.get("items", {})
	for d in items:
		Game.remove_def(str(d), int(items[d]))
	var by := WorkshopKnowledge.bearer(id)
	_learn(id, true, by if by != "" else "player")
	return ""


## Records a learned node and adds what it teaches to the workshop's knowledge, through worker `by` (the smith on his
## own path; in another craft the competent hand who brought it in).
static func _learn(id: String, announce: bool, by := "player") -> void:
	var st := _st()
	if st["nodes"].has(id):
		return
	st["nodes"].append(id)
	st["day"][id] = Game.day()
	if by != "player":
		if not st.get("by") is Dictionary:
			st["by"] = {}
		st["by"][id] = by
	WorkshopKnowledge.learn_node(id, by)
	if announce:
		var n := node(id)
		var what := unlock_summary(id)
		var bname := str(branch(str(n.get("branch", ""))).get("name", ""))
		if WorkshopKnowledge.node_owner(id) == "smith" or by == "player":
			Chronicle.add("skill", "Brannoc learned %s (%s)%s." % [n.get("name", id), bname, (" — " + what) if what != "" else ""], {"node": id}, true)
			Events.toast.emit("Learned: %s" % n.get("name", id), "legendary" if id == "ar_legend" else "good")
		else:
			var who := WorkshopKnowledge.who_text(by)
			Chronicle.add("skill", "The workshop learned %s (%s) through %s%s." % [n.get("name", id), bname, who, (" — " + what) if what != "" else ""], {"node": id, "by": by}, true)
			Events.toast.emit("The workshop learned %s — through %s" % [n.get("name", id), who], "legendary" if id == "ar_legend" else "good")
		Audio.play("sfx/level_up")
	Events.crafting_changed.emit()


## Short "unlocks" summary for journal lines.
static func unlock_summary(id: String) -> String:
	var n := node(id)
	var u: Dictionary = n.get("unlocks", {})
	var parts := []
	for r in u.get("recipes", []):
		if recipe_visible(str(r)):
			parts.append(DB.recipe(str(r)).get("name", r))
	for s in u.get("stations", []):
		parts.append(DB.station(str(s)).get("name", s))
	for t in u.get("techniques", []):
		parts.append(str(t.get("name", "")))
	return ", ".join(parts)


## "unlocked" | "available" (can be learned now) | "locked" | "hidden" (a secret not yet hinted at).
static func node_state(id: String) -> String:
	if is_unlocked(id):
		return "unlocked"
	var n := node(id)
	if n.get("secret", false) and not _flags_met(n):
		return "hidden"
	return "available" if can_unlock(id) == "" else "locked"


# ------------------------------------------------------------------ gating (the workshop's knowledge — B2)
## Does the workshop know how to set up and work this station? (WorkshopKnowledge; not whether it is bought.)
static func station_unlocked(sid: String) -> bool:
	return WorkshopKnowledge.knows_station(sid)


## "" when the workshop knows the station, otherwise the reason (shown in tooltips).
static func station_reason(station_id: String) -> String:
	return WorkshopKnowledge.station_reason(station_id)


## Secret recipes (requires_flag) are hidden from every list until their flag is known.
static func recipe_visible(rid: String) -> bool:
	var rf := str(DB.recipe(rid).get("requires_flag", ""))
	return rf == "" or Game.has_flag(rf)


## Does the workshop know this Design? (WorkshopKnowledge — internal ids keep the word "recipe".)
static func recipe_known(rid: String) -> bool:
	return WorkshopKnowledge.knows_design(rid)


## "" when the workshop knows the Design, otherwise the reason.
static func recipe_reason(recipe_id: String) -> String:
	if Game.state.is_empty():
		return ""
	return WorkshopKnowledge.design_reason(recipe_id)


# ------------------------------------------------------------------ techniques
static func techniques() -> Array:
	var out := []
	for id in learned():
		for t in node(str(id)).get("unlocks", {}).get("techniques", []):
			out.append(t)
	return out


static func technique_matches(t: Dictionary, r: Dictionary) -> bool:
	var f: Dictionary = t.get("filter", {})
	if f.has("discipline") and not (f["discipline"] as Array).has(r.get("discipline", "")):
		return false
	if f.has("category") and not (f["category"] as Array).has(r.get("category", "")):
		return false
	if f.has("material") and not (f["material"] as Array).has(r.get("material", "")):
		return false
	if f.has("recipes") and not (f["recipes"] as Array).has(r.get("id", "")):
		return false
	return true


## Craftsmanship bonus (percentage points) from the techniques that help `actor` (default the smith) on a Design —
## B2: the workshop must know them and they must be the actor's own (WorkshopKnowledge.technique_applies).
static func quality_bonus(recipe_id: String, actor: Variant = "player") -> float:
	return WorkshopKnowledge.quality_bonus(recipe_id, actor)


## Techniques that help `actor` on a Design (for the designer and tooltips).
static func techniques_for(recipe_id: String, actor: Variant = "player") -> Array:
	return WorkshopKnowledge.techniques_for(recipe_id, actor)


static func min_rarity_rank(recipe_id: String) -> int:
	return int(RARITY_RANK.get(str(DB.recipe(recipe_id).get("min_rarity", "common")), 0))


# ------------------------------------------------------------------ dev / test helpers
## Learns every node at once (developer tools, older tests). Secret recipes still need their flag.
static func unlock_all() -> void:
	for n in nodes():
		if not is_unlocked(n["id"]):
			_st()["nodes"].append(n["id"])
	WorkshopKnowledge.resync()
	Events.crafting_changed.emit()


## Learns a node without checking or paying anything.
static func unlock_node_force(id: String) -> void:
	if not node(id).is_empty():
		_learn(id, false)


## Back to a new game's tree.
static func reset_new() -> void:
	Game.state["skilltree"] = {"nodes": (data().get("start", []) as Array).duplicate(), "day": {}}
	WorkshopKnowledge.reset_to(data().get("start", []))
	Events.crafting_changed.emit()


## Counts for the panel header.
static func count_learned(bid := "") -> int:
	var n := 0
	for id in learned():
		if bid == "" or node(str(id)).get("branch", "") == bid:
			n += 1
	return n
