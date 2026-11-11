## SkillTree — the blacksmith's branching progression (data/skilltree.json, made by tools/data/make_skilltree.py).
## EN: Six branches of nodes (Traditional Smithing, Mining & Metallurgy, Arcane Metalworking, Runecrafting,
##     Alchemy, Leatherworking & Enchanted Stitching). A node is learned when its requirements are met —
##     a skill level, prerequisite nodes, knowledge flags, installed stations, materials seen or handed over,
##     tuition — and unlocks recipes, stations (eligible to buy and install) and techniques (small
##     craftsmanship bonuses). Every recipe and every station is taught by exactly one node.
##     State: Game.state["skilltree"] = {"nodes": [ids learned], "day": {id: day learned}};
##            Game.state["items_seen"] = {item def: true} (fed by Game.add_item → note_item).
##     Old saves without "skilltree" get every node whose skill requirement they meet (ensure()).
## DA: Smedens færdighedstræ. Seks grene; en knude læres når kravene er opfyldt og åbner opskrifter,
##     stationer og teknikker. Gamle gemte spil får alle knuder hvis færdighedskrav de opfylder.
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
		var sk: Array = r["skill"]
		# Living Workshop B1 (seam for KNOWLEDGE, wave 2): the smith's own craft needs HIS level; another craft is workshop
		# knowledge a competent specialist on the staff can bring (Workers.tree_level) — no grind past his basic level
		var you := Game.player_level(str(sk[0]))
		var have := Workers.tree_level(str(sk[0]))
		var best := Workers.best_level(str(sk[0]))
		var txt := "%s %d (you: %d)" % [SkillSys.skill_name(str(sk[0])), int(sk[1]), you]
		if have > you:
			txt = "%s %d (you: %d · %s: %d)" % [SkillSys.skill_name(str(sk[0])), int(sk[1]), you, str(best["name"]), have]
		var hint := "Raise it by crafting work that trains %s." % SkillSys.skill_name(str(sk[0]))
		if Workers.is_basic("player", str(sk[0])) and int(sk[1]) > Workers.BASIC_LEVEL:
			hint = "Beyond the smith's basic %s — %s on your staff with %s %d meets it." % [SkillSys.skill_name(str(sk[0])).to_lower(),
				Workers.a_noun(Workers.skill_profession(str(sk[0]))), SkillSys.skill_name(str(sk[0])), int(sk[1])]
		out.append({"ok": have >= int(sk[1]), "kind": "skill", "text": txt, "hint": hint})
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
	_learn(id, true)
	return ""


static func _learn(id: String, announce: bool) -> void:
	var st := _st()
	if st["nodes"].has(id):
		return
	st["nodes"].append(id)
	st["day"][id] = Game.day()
	if announce:
		var n := node(id)
		var what := unlock_summary(id)
		Chronicle.add("skill", "Brannoc learned %s (%s)%s." % [n.get("name", id), branch(str(n.get("branch", ""))).get("name", ""), (" — " + what) if what != "" else ""], {"node": id}, true)
		Events.toast.emit("Learned: %s" % n.get("name", id), "legendary" if id == "ar_legend" else "good")
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


# ------------------------------------------------------------------ gating (asked by Crafting)
static func station_unlocked(sid: String) -> bool:
	var ni := station_node(sid)
	return ni == "" or is_unlocked(ni)


## "" when the station may be used, otherwise the reason (shown in tooltips).
static func station_reason(station_id: String) -> String:
	if Game.state.is_empty():
		return ""
	var ni := station_node(station_id)
	if ni == "" or is_unlocked(ni):
		return ""
	var n := node(ni)
	return "Skill tree: learn «%s» (%s)" % [n.get("name", ni), branch(str(n.get("branch", ""))).get("name", "")]


## Secret recipes (requires_flag) are hidden from every list until their flag is known.
static func recipe_visible(rid: String) -> bool:
	var rf := str(DB.recipe(rid).get("requires_flag", ""))
	return rf == "" or Game.has_flag(rf)


static func recipe_known(rid: String) -> bool:
	if not recipe_visible(rid):
		return false
	var ni := recipe_node(rid)
	return ni == "" or is_unlocked(ni)


## "" when the recipe is known and allowed, otherwise the reason.
static func recipe_reason(recipe_id: String) -> String:
	if Game.state.is_empty():
		return ""
	if not recipe_visible(recipe_id):
		return "A forgotten recipe — find its notes among the relics"
	var ni := recipe_node(recipe_id)
	if ni == "" or is_unlocked(ni):
		return ""
	var n := node(ni)
	return "Skill tree: learn «%s» (%s)" % [n.get("name", ni), branch(str(n.get("branch", ""))).get("name", "")]


# ------------------------------------------------------------------ techniques
static func techniques() -> Array:
	var out := []
	for id in learned():
		for t in node(str(id)).get("unlocks", {}).get("techniques", []):
			out.append(t)
	return out


static func _matches(t: Dictionary, r: Dictionary) -> bool:
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


## Craftsmanship bonus (percentage points) from learned techniques for a recipe.
static func quality_bonus(recipe_id: String) -> float:
	var r := DB.recipe(recipe_id)
	if r.is_empty() or Game.state.is_empty():
		return 0.0
	var b := 0.0
	for t in techniques():
		if float(t.get("quality", 0)) > 0.0 and _matches(t, r):
			b += float(t["quality"])
	return b


## Techniques that would apply to a recipe (for the designer and tooltips).
static func techniques_for(recipe_id: String) -> Array:
	var r := DB.recipe(recipe_id)
	return techniques().filter(func(t): return float(t.get("quality", 0)) > 0.0 and _matches(t, r))


static func min_rarity_rank(recipe_id: String) -> int:
	return int(RARITY_RANK.get(str(DB.recipe(recipe_id).get("min_rarity", "common")), 0))


# ------------------------------------------------------------------ dev / test helpers
## Learns every node at once (developer tools, older tests). Secret recipes still need their flag.
static func unlock_all() -> void:
	for n in nodes():
		if not is_unlocked(n["id"]):
			_st()["nodes"].append(n["id"])
	Events.crafting_changed.emit()


## Learns a node without checking or paying anything.
static func unlock_node_force(id: String) -> void:
	if not node(id).is_empty():
		_learn(id, false)


## Back to a new game's tree.
static func reset_new() -> void:
	Game.state["skilltree"] = {"nodes": (data().get("start", []) as Array).duplicate(), "day": {}}
	Events.crafting_changed.emit()


## Counts for the panel header.
static func count_learned(bid := "") -> int:
	var n := 0
	for id in learned():
		if bid == "" or node(str(id)).get("branch", "") == bid:
			n += 1
	return n
