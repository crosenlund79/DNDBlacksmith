## Crafting — recipes, station steps, circular skill-check quality and final item generation.
## EN: A job walks through the recipe's station steps. Each station runs one or more timing checks;
##     every check yields a craftsmanship percentage (precision-based, can exceed 100%). The final
##     quality is the weighted mean of all checks plus a small skill bonus. Dice (auto or physical)
##     then set the statistics and the fortune roll — but quality remains the dominant factor.
## DA: Et arbejde går gennem opskriftens stationstrin. Hver station kører en eller flere
##     timing-prøver; hver giver en håndværksprocent (præcisionsbaseret, kan overstige 100%).
##     Den endelige kvalitet er det vægtede gennemsnit plus en lille færdighedsbonus. Terninger
##     fastsætter derefter statistik og lykkeslag — men kvaliteten vejer tungest.
class_name Crafting
extends RefCounted

const DISCIPLINE_SKILL := {"classic": "smithing", "runecraft": "runecraft", "alchemy": "alchemy",
	"arcane": "arcane_metalwork", "stitching": "enchanted_stitching"}
const DISCIPLINE_NAME := {"classic": "Classic Smithing", "runecraft": "Runecrafting", "alchemy": "Alchemy",
	"arcane": "Arcane Metalworking", "stitching": "Enchanted Stitching"}


static func job() -> Dictionary:
	return Game.state.get("craft", {})


static func active() -> bool:
	return not job().is_empty()


# ------------------------------------------------------------------ unlocks
static func station_locked_reason(station_id: String) -> String:
	var st := DB.station(station_id)
	var u: Dictionary = st.get("unlock", {})
	if u.has("upgrade") and not Game.has_upgrade(u["upgrade"]):
		return "Requires workshop upgrade: " + DB.upgrades.get(u["upgrade"], {}).get("name", u["upgrade"])
	if u.has("skill"):
		var sk: Array = u["skill"]
		if Game.player_level(sk[0]) < int(sk[1]):
			return "Requires %s %d" % [SkillSys.skill_name(sk[0]), int(sk[1])]
	return ""


static func recipe_locked_reason(recipe_id: String) -> String:
	var r := DB.recipe(recipe_id)
	var u: Dictionary = r.get("unlock", {})
	if u.has("skill"):
		var sk: Array = u["skill"]
		if Game.player_level(sk[0]) < int(sk[1]):
			return "Requires %s %d" % [SkillSys.skill_name(sk[0]), int(sk[1])]
	for s in r.get("steps", []):
		var why := station_locked_reason(s)
		if why != "":
			return DB.station(s).get("name", s) + " — " + why
	return ""


static func missing_inputs(recipe_id: String) -> Dictionary:
	var miss := {}
	var r := DB.recipe(recipe_id)
	for id in r.get("inputs", {}):
		var need := int(r["inputs"][id])
		var have := Game.count(id)
		if have < need:
			miss[id] = need - have
	return miss


static func recipes_for_station(station_id: String) -> Array:
	var out := []
	for r in DB.recipes.values():
		if r["steps"].has(station_id):
			out.append(r)
	return out


# ------------------------------------------------------------------ job flow
static func start(recipe_id: String) -> bool:
	if active():
		return false
	if recipe_locked_reason(recipe_id) != "" or not missing_inputs(recipe_id).is_empty():
		return false
	var r := DB.recipe(recipe_id)
	for id in r["inputs"]:
		Game.remove_def(id, int(r["inputs"][id]))
	Game.state["craft"] = {"recipe": recipe_id, "step": 0, "samples": [], "awaiting_dice": false, "day": Game.day()}
	Events.crafting_changed.emit()
	Audio.play("sfx/page_turn")
	Objectives.complete("select_recipe")
	return true


static func cancel() -> void:
	var j := job()
	if j.is_empty():
		return
	var r := DB.recipe(j["recipe"])
	for id in r["inputs"]:
		Game.add_item(Items.make(id, {"qty": int(r["inputs"][id])}), false)
	Game.state["craft"] = {}
	Events.crafting_changed.emit()
	Events.toast.emit("Work abandoned — materials returned.", "info")


static func current_station() -> String:
	var j := job()
	if j.is_empty() or j.get("awaiting_dice", false):
		return ""
	var steps: Array = DB.recipe(j["recipe"])["steps"]
	return steps[int(j["step"])] if int(j["step"]) < steps.size() else ""


static func skill_for_station(station_id: String) -> String:
	return DISCIPLINE_SKILL.get(DB.station(station_id).get("discipline", "classic"), "smithing")


## Station-specific check parameters, eased by the relevant skill level.
static func check_params(station_id: String) -> Dictionary:
	var c: Dictionary = DB.station(station_id).get("check", {"count": 1, "speed": 0.55, "zone": 34, "weight": 1.0})
	var lvl := Game.player_level(skill_for_station(station_id))
	return {
		"count": int(c.get("count", 1)),
		"speed": float(c.get("speed", 0.55)) * maxf(0.7, 1.0 - 0.015 * lvl),
		"zone": float(c.get("zone", 34)) + 1.5 * lvl,
		"weight": float(c.get("weight", 1.0)),
	}


## Precision → craftsmanship for one check. offset_deg = distance of the needle from the zone centre.
## Centre (within 12% of the half-width) ≈ 115–120%; zone edge ≈ 70%; far misses fall to ~10%.
static func check_quality(offset_deg: float, zone_deg: float) -> float:
	var half := zone_deg * 0.5
	var off := absf(offset_deg)
	if off <= half * 0.12:
		return lerpf(120.0, 114.0, off / (half * 0.12))
	if off <= half:
		return lerpf(114.0, 70.0, (off - half * 0.12) / (half * 0.88))
	return lerpf(65.0, 10.0, clampf((off - half) / (half * 2.0), 0.0, 1.0))


static func grade(q: float) -> String:
	if q >= 114.0:
		return "PERFECT"
	if q >= 95.0:
		return "Excellent"
	if q >= 75.0:
		return "Good"
	if q >= 50.0:
		return "Rough"
	return "Poor"


static func record_step(station_id: String, qualities: Array) -> void:
	var j := job()
	if j.is_empty() or current_station() != station_id:
		return
	var w := float(check_params(station_id)["weight"])
	for q in qualities:
		j["samples"].append({"station": station_id, "q": float(q), "w": w})
	j["step"] = int(j["step"]) + 1
	Game.grant_player_xp(skill_for_station(station_id), 4 + qualities.size() * 2)
	var steps: Array = DB.recipe(j["recipe"])["steps"]
	if int(j["step"]) >= steps.size():
		j["awaiting_dice"] = true
	Events.crafting_changed.emit()


static func final_quality(j := {}) -> float:
	if j.is_empty():
		j = job()
	var total := 0.0
	var wsum := 0.0
	for s in j.get("samples", []):
		total += float(s["q"]) * float(s["w"])
		wsum += float(s["w"])
	var base := total / wsum if wsum > 0 else 50.0
	var r := DB.recipe(j.get("recipe", ""))
	var disc: String = r.get("discipline", "classic")
	var lvl := Game.player_level(DISCIPLINE_SKILL.get(disc, "smithing"))
	return clampf(base + 0.6 * lvl, 1.0, 130.0)


static func dice_spec() -> Dictionary:
	return DB.recipe(job().get("recipe", "")).get("dice", {})


## Finalises the job with dice results {key: total}. Returns the produced item.
static func finish(dice: Dictionary) -> Dictionary:
	var j := job()
	if j.is_empty():
		return {}
	var r := DB.recipe(j["recipe"])
	var q := final_quality(j)
	var out_def: String = r["output"]
	var d := DB.item(out_def)
	var disc: String = r.get("discipline", "classic")
	var skill_id: String = DISCIPLINE_SKILL.get(disc, "smithing")
	var it := Items.make(out_def, {"quality": q, "qty": int(r.get("qty", 1)), "crafted_by": "Brannoc Ironhand"})
	if Items.is_equipment(it):
		Items._base_stats(it, d, q, dice, Game.player_level(skill_id))
		var bonus := 0.0
		if disc == "arcane":
			bonus += 10.0
			it["arcane_glow"] = true
		for inp in r["inputs"]:
			if DB.item(inp).get("type") == "runestone":
				bonus += 12.0
		var fortune := int(dice.get("fortune", 50))
		if it["rarity"] == "common":
			var rar := Items.rarity_from(q, fortune, bonus)
			if rar != "common":
				Items.apply_rarity(it, rar)
		var dice_parts := []
		for k in dice:
			dice_parts.append("%s %d" % [k, int(dice[k])])
		it["dice_log"] = ", ".join(dice_parts)
	else:
		# materials / potions: excellent work yields a bonus unit, potency follows quality
		if q >= 105.0 and d.get("stack", false):
			it["qty"] = int(it["qty"]) + 1
		if dice.has("purity"):
			it["dice_log"] = "purity %d" % int(dice["purity"])
	Game.state["craft"] = {}
	for skill in r.get("xp", {}):
		Game.grant_player_xp(skill, int(round(float(r["xp"][skill]) * (0.6 + q / 200.0))))
	Game.state["stats"]["crafted"] += 1
	if out_def == "ingot_mithril" or out_def == "sword_mithril":
		Game.set_flag("crafted_arcane")
	Game.add_item(it, false)
	Events.crafting_changed.emit()
	Events.item_crafted.emit(it)
	if it.get("rarity") == "legendary":
		Game.state["stats"]["legendaries"] += 1
		Events.legendary_found.emit(it)
	Objectives.on_crafted(it)
	Log.info("Crafted %s (q %.0f%%, %s)" % [it["name"], q, it["rarity"]])
	return it


## Sets a runestone into a piece of equipment (Rune Engraving Stand). Quality scales the effect.
static func socket(item_uid: int, rune_def: String, quality: float) -> bool:
	var it := Game.find_uid(item_uid)
	if it.is_empty() or not Items.is_equipment(it) or Game.count(rune_def) < 1:
		return false
	if it.get("sockets", []).size() >= 2:
		return false
	Game.remove_def(rune_def, 1)
	var rs: Dictionary = DB.item(rune_def).get("stats", {})
	for k in rs:
		it["affixes"].append({"id": "rune_" + k, "stat": k, "value": int(round(float(rs[k]) * (0.6 + quality / 100.0 * 0.6)))})
	it["sockets"].append(rune_def)
	if it["rarity"] == "common":
		it["rarity"] = "magic"
		it["name"] = "Runed " + str(it["name"])
	Game.grant_player_xp("runecraft", 20)
	Events.inventory_changed.emit()
	return true
