## Crafting — recipes as sequences of physical operations, precision checks, dice and rarity.
## EN: A recipe lists OPERATIONS ("Heat the billet" at the forge, "Draw out the blade" at the anvil…).
##     The player walks to each station in turn; every operation runs one or more precision checks.
##     Each check yields a continuous craftsmanship percentage (centre of the zone ≈ 120%, the edge
##     70%, misses fall towards 10%). Operation scores are weighted into the final craftsmanship, and a
##     little skill bonus is added. Recipe difficulty against the relevant skill sets how wide the zone
##     is and how fast the needle runs — skill makes the work easier, but never does it for you.
##     Dice (digital or physical) then set the statistics together with material and quality, and
##     quality + the fortune die + material/rune bonuses decide the rarity (data/crafting.json).
##     The complete record of the work is stored on the item under "craft" and saved with it.
## DA: En opskrift er en række arbejdsgange ved fysiske stationer. Hver arbejdsgang kører en eller
##     flere præcisionsprøver med kontinuerlig kvalitet (midten ≈ 120 %). Sværhedsgrad mod færdighed
##     styrer zonens bredde og viserens fart. Terninger, materiale og kvalitet giver statistikken;
##     kvalitet, lykkeslag og bonusser giver sjældenheden. Hele forløbet gemmes på genstanden.
class_name Crafting
extends RefCounted

const DISCIPLINE_SKILL := {"classic": "smithing", "runecraft": "runecraft", "alchemy": "alchemy",
	"arcane": "arcane_metalwork", "stitching": "enchanted_stitching"}
const DISCIPLINE_NAME := {"classic": "Classic Smithing", "runecraft": "Runecrafting", "alchemy": "Alchemy",
	"arcane": "Arcane Metalworking", "stitching": "Enchanted Stitching"}
const NON_EQUIP_RARITY := {"magic": ["Fine", 1.15], "rare": ["Exquisite", 1.3], "legendary": ["Flawless", 1.6]}


static func cfg(section: String) -> Dictionary:
	return DB.crafting.get(section, {})


static func job() -> Dictionary:
	return Game.state.get("craft", {})


static func active() -> bool:
	return not job().is_empty()


# ------------------------------------------------------------------ recipe data
## Operations of a recipe; older data without "operations" falls back to one operation per step.
static func operations(recipe_id: String) -> Array:
	var r := DB.recipe(recipe_id)
	if r.has("operations"):
		return r["operations"]
	var out := []
	for s in r.get("steps", []):
		out.append({"station": s, "op": DB.station(s).get("name", s), "checks": int(DB.station(s).get("check", {}).get("count", 1)), "weight": 1.0})
	return out


static func material(recipe_id: String) -> Dictionary:
	var mats: Dictionary = cfg("materials")
	return mats.get(DB.recipe(recipe_id).get("material", ""), {"name": "—", "stat": 1.0, "durability": 1.0, "difficulty": 0, "rarity_bonus": 0})


static func recipe_skill(recipe_id: String) -> String:
	return DISCIPLINE_SKILL.get(DB.recipe(recipe_id).get("discipline", "classic"), "smithing")


## Effective difficulty: the recipe's own plus its material's.
static func difficulty(recipe_id: String) -> int:
	return int(DB.recipe(recipe_id).get("difficulty", 1)) + int(material(recipe_id).get("difficulty", 0))


static func difficulty_word(recipe_id: String) -> String:
	var gap := difficulty(recipe_id) - Game.player_level(recipe_skill(recipe_id))
	if gap <= -4:
		return "routine work"
	if gap <= -1:
		return "comfortable"
	if gap <= 1:
		return "demanding"
	if gap <= 3:
		return "hard"
	return "beyond you — expect rough work"


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
	var rf := str(r.get("requires_flag", ""))
	if rf != "" and not Game.has_flag(rf):
		return "A forgotten recipe — find its notes among the relics"
	var req: Dictionary = r.get("requires", {})
	for sk in req:
		if Game.player_level(sk) < int(req[sk]):
			return "Requires %s %d" % [SkillSys.skill_name(sk), int(req[sk])]
	var u: Dictionary = r.get("unlock", {})
	if u.has("skill"):
		var usk: Array = u["skill"]
		if Game.player_level(usk[0]) < int(usk[1]):
			return "Requires %s %d" % [SkillSys.skill_name(usk[0]), int(usk[1])]
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
	Game.state["craft"] = {"recipe": recipe_id, "step": 0, "samples": [], "ops": [], "awaiting_dice": false, "day": Game.day()}
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


static func current_op() -> Dictionary:
	var j := job()
	if j.is_empty() or j.get("awaiting_dice", false):
		return {}
	var ops := operations(j["recipe"])
	return ops[int(j["step"])] if int(j["step"]) < ops.size() else {}


static func current_station() -> String:
	return str(current_op().get("station", ""))


static func skill_for_station(station_id: String) -> String:
	return DISCIPLINE_SKILL.get(DB.station(station_id).get("discipline", "classic"), "smithing")


## Check parameters for a station. With a recipe, its difficulty is weighed against the skill:
## a beginner gets a narrow zone and a fast needle, an expert a wide zone and a slow one.
static func check_params(station_id: String, recipe_id := "", checks := -1) -> Dictionary:
	var c: Dictionary = DB.station(station_id).get("check", {"count": 1, "speed": 0.55, "zone": 34, "weight": 1.0})
	var sk := cfg("skill")
	var skill := skill_for_station(station_id)
	var lvl := Game.player_level(skill)
	var diff := float(difficulty(recipe_id)) if recipe_id != "" else 2.0
	var gap := diff - float(lvl)
	var zone := float(c.get("zone", 34)) * clampf(1.0 - float(sk.get("difficulty_zone", 0.06)) * gap, 0.55, 1.45) \
		+ float(sk.get("zone_per_level", 1.4)) * lvl
	var ease := minf(float(sk.get("speed_ease_per_level", 0.015)) * lvl, float(sk.get("speed_ease_max", 0.3)))
	var speed := float(c.get("speed", 0.55)) * (1.0 - ease) * clampf(1.0 + float(sk.get("difficulty_speed", 0.05)) * gap, 0.75, 1.4)
	var upg: Dictionary = sk.get("upgrade_zone", {})
	for u in upg:
		var pair: Array = upg[u]
		if pair[0] == skill and Game.has_upgrade(u):
			zone += float(pair[1])
	return {
		"count": checks if checks > 0 else int(c.get("count", 1)),
		"speed": speed,
		"zone": clampf(zone, 14.0, 90.0),
		"weight": float(c.get("weight", 1.0)),
		"skill": skill, "level": lvl, "difficulty": diff,
	}


## Parameters for the current operation of the active job.
static func op_params() -> Dictionary:
	var o := current_op()
	if o.is_empty():
		return {}
	var p := check_params(str(o["station"]), str(job()["recipe"]), int(o.get("checks", 1)))
	p["weight"] = float(o.get("weight", 1.0))
	p["op"] = str(o.get("op", ""))
	return p


## Precision → craftsmanship for one check (continuous). offset_deg = distance from the zone centre.
static func check_quality(offset_deg: float, zone_deg: float) -> float:
	var c := cfg("check")
	var peak := float(c.get("peak", 120.0))
	var edge := float(c.get("edge", 70.0))
	var half := zone_deg * 0.5
	var off := absf(offset_deg)
	if off <= half:
		return peak - (peak - edge) * pow(off / half, float(c.get("curve", 1.3)))
	return lerpf(float(c.get("miss_hi", 65.0)), float(c.get("floor", 10.0)), clampf((off - half) / (half * 2.0), 0.0, 1.0))


static func grade(q: float) -> String:
	if q >= 114.0:
		return "PERFECT"
	if q >= 100.0:
		return "Masterful"
	if q >= 90.0:
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
	var o := current_op()
	var w := float(o.get("weight", 1.0))
	var sum := 0.0
	for q in qualities:
		j["samples"].append({"station": station_id, "q": float(q), "w": w})
		sum += float(q)
	if not j.has("ops"):
		j["ops"] = []
	j["ops"].append({"op": str(o.get("op", "")), "station": station_id, "q": sum / maxf(1.0, qualities.size()),
		"checks": qualities.duplicate(), "w": w})
	j["step"] = int(j["step"]) + 1
	Game.grant_player_xp(skill_for_station(station_id), 3 + qualities.size() * 2)
	if int(j["step"]) >= operations(j["recipe"]).size():
		j["awaiting_dice"] = true
	Events.crafting_changed.emit()


## Weighted mean of all checks (without the skill bonus).
static func base_quality(j := {}) -> float:
	if j.is_empty():
		j = job()
	var total := 0.0
	var wsum := 0.0
	for s in j.get("samples", []):
		total += float(s["q"]) * float(s["w"])
		wsum += float(s["w"])
	return total / wsum if wsum > 0 else 50.0


static func skill_bonus(recipe_id: String) -> float:
	return float(cfg("skill").get("quality_per_level", 0.4)) * Game.player_level(recipe_skill(recipe_id)) + hireling_assist(recipe_id)


## A skilled hand at work in the forge steadies the smith's work: +0.25% per level of the best
## hireling in the recipe's skill (smithing for smithing recipes, etc.) who is on shift.
static func hireling_assist(recipe_id: String) -> float:
	var sk := recipe_skill(recipe_id)
	if not sk in DB.work_skills:
		sk = "smithing" if sk == "arcane_metalwork" else ("alchemy" if sk == "enchanted_stitching" else sk)
	var best := 0
	var who := ""
	for h in Hire.list():
		if h["status"] == "working" and SkillSys.level(h["skills"], sk) > best:
			best = SkillSys.level(h["skills"], sk)
			who = h["name"]
	return 0.25 * best


static func assistant_name(recipe_id: String) -> String:
	var sk := recipe_skill(recipe_id)
	var best := 0
	var who := ""
	for h in Hire.list():
		if h["status"] == "working" and h["skills"].has(sk) and SkillSys.level(h["skills"], sk) > best:
			best = SkillSys.level(h["skills"], sk)
			who = h["name"]
	return who


static func final_quality(j := {}) -> float:
	if j.is_empty():
		j = job()
	return clampf(base_quality(j) + skill_bonus(j.get("recipe", "")), 1.0, 130.0)


static func dice_spec() -> Dictionary:
	return DB.recipe(job().get("recipe", "")).get("dice", {})


# ------------------------------------------------------------------ rarity
## Rarity score and verdict from craftsmanship, the fortune die and bonuses (all from crafting.json).
static func rarity_eval(quality: float, fortune: int, bonus := 0.0) -> Dictionary:
	var rc := cfg("rarity")
	var w: Dictionary = rc.get("weights", {"quality": 0.75, "fortune": 0.35})
	var th: Dictionary = rc.get("thresholds", {"magic": 68, "rare": 88, "legendary": 112})
	var mw: Dictionary = rc.get("masterwork", {"quality": 115, "bonus": 26})
	var parts := {"quality": quality * float(w["quality"]), "fortune": fortune * float(w["fortune"]), "bonus": bonus, "masterwork": 0.0}
	if quality >= float(mw.get("quality", 115)):
		parts["masterwork"] = float(mw.get("bonus", 26))
	var score: float = parts["quality"] + parts["fortune"] + parts["bonus"] + parts["masterwork"]
	var rar := "common"
	for r in ["magic", "rare", "legendary"]:
		if score >= float(th[r]):
			rar = r
	return {"score": score, "rarity": rar, "parts": parts, "thresholds": th, "masterwork": parts["masterwork"] > 0.0}


# ------------------------------------------------------------------ stats
static func _norm(dice: Dictionary, spec: Dictionary, key: String, fallback := 0.5) -> float:
	if not dice.has(key) or not spec.has(key):
		return fallback
	var sides := Dice.sides(str(spec[key]))
	return clampf((float(dice[key]) - 1.0) / maxf(1.0, sides - 1.0), 0.0, 1.0)


## Statistics from definition × craftsmanship × material × dice × skill. Craftsmanship dominates;
## the main die moves a stat by ±15%, temper ±10% durability, potency/resonance ±20% effect.
static func compute_stats(d: Dictionary, quality: float, dice: Dictionary, spec: Dictionary, mat: Dictionary, lvl: int) -> Dictionary:
	var st: Dictionary = d.get("stats", {})
	var q := clampf(quality / 100.0 * 0.85, 0.0, 1.15)
	var skill_mult := 1.0 + 0.01 * lvl
	var main_n := _norm(dice, spec, "edge", _norm(dice, spec, "guard", -1.0))
	var potency_n := _norm(dice, spec, "potency", _norm(dice, spec, "resonance", 0.5))
	if main_n < 0.0:
		main_n = potency_n
	var weave_n := _norm(dice, spec, "spellweave", main_n)
	var temper_n := _norm(dice, spec, "temper", 0.5)
	var ms := float(mat.get("stat", 1.0))
	var out := {}
	for key in st:
		var v: Variant = st[key]
		if v is Array:
			out[key] = int(round(lerpf(float(v[0]), float(v[1]), q) * (0.85 + main_n * 0.3) * skill_mult * ms))
		elif key == "durability":
			out[key] = int(round(float(v) * (0.6 + 0.4 * minf(quality / 100.0, 1.25)) * (0.9 + temper_n * 0.2) * float(mat.get("durability", 1.0))))
		elif key == "magic":
			out[key] = int(round(float(v) * (0.7 + 0.3 * minf(quality / 100.0, 1.3)) * (0.85 + weave_n * 0.3) * ms))
		else:
			out[key] = maxi(1, int(round(float(v) * (0.7 + 0.3 * minf(quality / 100.0, 1.3)) * (0.8 + potency_n * 0.4) * ms)))
	if out.has("durability"):
		out["durability_max"] = out["durability"]
	return out


# ------------------------------------------------------------------ finishing
## Finalises the job. dice: {key: total} or {key: {"total", "faces"}}; mode "digital"/"physical".
static func finish(dice: Dictionary, mode := "digital") -> Dictionary:
	var j := job()
	if j.is_empty():
		return {}
	var rid: String = j["recipe"]
	var r := DB.recipe(rid)
	var spec: Dictionary = r.get("dice", {})
	var totals := {}
	var dice_log := {}
	for k in dice:
		var v: Variant = dice[k]
		var total: int = int(v["total"]) if v is Dictionary else int(v)
		var faces: Array = v.get("faces", [total]) if v is Dictionary else [total]
		totals[k] = total
		dice_log[k] = {"expr": str(spec.get(k, "")), "total": total, "faces": faces}
	var base := base_quality(j)
	var q := final_quality(j)
	var out_def: String = r["output"]
	var d := DB.item(out_def)
	var skill_id := recipe_skill(rid)
	var lvl := Game.player_level(skill_id)
	var mat := material(rid)
	var it := Items.make(out_def, {"quality": q, "qty": int(r.get("qty", 1)), "crafted_by": "Brannoc Ironhand"})
	it["stats"] = compute_stats(d, q, totals, spec, mat, lvl)
	# rarity: quality + fortune + material + runestone bonuses
	var bonus := float(mat.get("rarity_bonus", 0))
	for inp in r["inputs"]:
		if DB.item(inp).get("type") == "runestone" and inp != "runestone_blank":
			bonus += float(cfg("rarity").get("runestone_bonus", 8))
	var fortune := int(totals.get("fortune", 50))
	var rev := rarity_eval(q, fortune, bonus) if totals.has("fortune") else {"score": 0.0, "rarity": "common", "parts": {}, "masterwork": false}
	if r.get("discipline", "") == "arcane":
		it["arcane_glow"] = true
		# arcane metalworking binds an ability into the metal itself (distinct from a socketed rune)
		if Items.is_equipment(it):
			var weave := _norm(totals, spec, "spellweave", 0.5)
			var bstat := "ward" if Items.slot(it) in ["armor", "shield", "helmet"] else "magic"
			var bval := int(round((3.0 + 6.0 * weave) * (0.6 + q / 250.0)))
			var bname: String = {"ward": "Leyward", "magic": "Leyline Edge"}[bstat]
			it["bound"] = {"name": bname, "stat": bstat, "value": bval}
			it["affixes"].append({"id": "bound", "stat": bstat, "value": bval})
	var rar: String = rev["rarity"]
	if it["rarity"] == "common" and rar != "common":
		if Items.is_equipment(it):
			Items.apply_rarity(it, rar)
		else:
			_apply_rarity_plain(it, rar)
	# materials: excellent work or a pure batch yields a bonus unit
	if not Items.is_equipment(it) and d.get("stack", false):
		if q >= 105.0 or int(totals.get("purity", 0)) >= 6:
			it["qty"] = int(it["qty"]) + 1
	var parts := []
	for k in totals:
		parts.append("%s %d" % [k, int(totals[k])])
	it["dice_log"] = ", ".join(parts)
	# experience: experts learn little from routine work
	var sk := cfg("skill")
	var xp := {}
	var expert := lvl - difficulty(rid) >= int(sk.get("xp_expert_gap", 5))
	for skill in r.get("xp", {}):
		var amt := float(r["xp"][skill]) * (0.6 + q / 200.0)
		if expert:
			amt *= float(sk.get("xp_expert_mult", 0.4))
		xp[skill] = int(round(amt))
		Game.grant_player_xp(skill, xp[skill])
	it["craft"] = {
		"recipe": rid, "recipe_name": r.get("name", rid), "material": mat.get("name", ""),
		"difficulty": difficulty(rid), "skill": skill_id, "level": lvl,
		"ops": j.get("ops", []).duplicate(true), "base_quality": base, "skill_bonus": q - base, "quality": q,
		"dice": dice_log, "dice_mode": mode, "rarity_score": rev["score"], "rarity_parts": rev.get("parts", {}),
		"masterwork": rev.get("masterwork", false), "xp": xp, "expert": expert, "day": Game.day(),
	}
	Game.state["craft"] = {}
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
	Log.info("Crafted %s (q %.1f%%, %s, score %.1f)" % [it["name"], q, it["rarity"], float(rev["score"])])
	return it


## Rarity for potions, runestones and materials: a name prefix and stronger effect, no affixes.
static func _apply_rarity_plain(it: Dictionary, rar: String) -> void:
	var p: Array = NON_EQUIP_RARITY.get(rar, ["", 1.0])
	it["rarity"] = rar
	it["name"] = "%s %s" % [p[0], it["name"]]
	it["star"] = rar == "legendary"
	for k in it["stats"]:
		it["stats"][k] = int(round(float(it["stats"][k]) * float(p[1])))


const TREATMENTS := {"oil_whetstone": ["attack", "Whetstone Oil"], "coating_flame": ["fire", "Flame Coating"], "coating_frost": ["frost", "Frost Coating"]}


## Brushes a treatment onto equipment: its effect lasts three expeditions (used by the encounters).
static func treat(item_uid: int, coat_def: String) -> String:
	var it := Game.find_uid(item_uid)
	if it.is_empty() or not TREATMENTS.has(coat_def) or Game.count(coat_def) < 1:
		return "Nothing to treat."
	var c: Dictionary = {}
	for x in Game.inventory():
		if x["def"] == coat_def:
			c = x
			break
	var t: Array = TREATMENTS[coat_def]
	var base := float(DB.item(coat_def).get("stats", {}).get(t[0], DB.item(coat_def).get("stats", {}).get("edge", 2)))
	var val := int(round(maxf(2.0, base * 2.0) * (0.7 + float(c.get("quality", 70)) / 200.0)))
	Game.remove_def(coat_def, 1)
	it["coating"] = {"name": t[1], "stat": t[0], "value": val, "uses": 3}
	Audio.play("sfx/glass")
	Game.grant_player_xp("alchemy", 4)
	Events.inventory_changed.emit()
	return "The %s takes the %s (+%d %s for three expeditions)." % [it["name"], t[1], val, t[0]]


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
