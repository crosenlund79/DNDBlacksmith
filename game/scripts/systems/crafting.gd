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
## Stackable materials and goods: craftsmanship at or above this (or a purity die of 6) adds one unit to the batch.
const YIELD_BONUS_Q := 105.0


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


## How the work feels to `actor` (default the smith): the Design's difficulty against their level in its skill.
static func difficulty_word(recipe_id: String, actor: Variant = "player") -> String:
	var gap := difficulty(recipe_id) - Workers.level(actor, recipe_skill(recipe_id))
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
## May the SMITH work at this station? (owned and installed, learned in the tree, its upgrade, his own station skill).
## Living Workshop B1: the same question for any worker is Workers.station_reason(actor, sid); the workshop's part
## alone is Workers.workshop_station_reason(sid).
static func station_locked_reason(station_id: String) -> String:
	return Workers.station_reason("player", station_id)


## May the SMITH make this Design himself? "" or the first reason, in this order: the workshop's knowledge (the skill
## tree, a forgotten recipe's notes), his competence (what the Design names, then — Living Workshop B1 — work beyond
## his basic grasp of another craft: "Needs a runesmith (Runecraft 6) — the smith's runecraft is basic (3)"), then each
## station. For any worker: Workers.can_do(actor, recipe_id); for the workshop as a whole: Workers.workshop_can.
static func recipe_locked_reason(recipe_id: String) -> String:
	return Workers.can_do("player", recipe_id)


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
	var t := Property.type_of(station_id)   # #37: any instance of a station offers its type's Designs
	for r in DB.recipes.values():
		if r["steps"].has(t):
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
	if not Steward.is_active():
		Objectives.complete("select_recipe")   # S2: the steward's smith completes no objective for the player
	return true


static func cancel() -> void:
	var j := job()
	if j.is_empty():
		return
	if j.has("order"):
		# C1: his stage of a work order — the materials belong to the order and stay with it; the stage waits again
		WorkOrders.smith_abandon(j)
		Events.crafting_changed.emit()
		Events.toast.emit("You set the work down — the order keeps its materials and the stage waits for you.", "info")
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


## Living Workshop (#37): the station INSTANCE the smith works the current operation at — the one he chose (walked up
## to or worked at: job["at"]) while it is of the operation's type and set up; otherwise the first set-up instance of
## that type no apprentice is using (else the first). "" without a current operation.
static func smith_instance() -> String:
	var t := current_station()
	if t == "":
		return ""
	var at := str(job().get("at", ""))
	if at != "" and Property.type_of(at) == t and Property.is_installed(at):
		return at
	var inst := Property.instances(t)
	if Game.state.has("apprentices"):
		for sid in inst:
			if Apprentices.instance_user(str(sid), false) == "":
				return str(sid)
	return str(inst[0]) if not inst.is_empty() else t


## The smith settles at this instance for his current operation (he walked up to it, or works there). An apprentice
## using it steps aside to another free one of its kind (the smith has priority).
static func choose_instance(sid: String) -> void:
	var j := job()
	if j.is_empty() or Property.type_of(sid) != current_station() or not Property.is_installed(sid):
		return
	j["at"] = sid


static func skill_for_station(station_id: String) -> String:
	return DISCIPLINE_SKILL.get(DB.station(station_id).get("discipline", "classic"), "smithing")


# ------------------------------------------------------------------ skill-check difficulty
## Station tier: the more exotic the discipline, the less forgiving its checks (zone ÷, speed ×).
const STATION_TIER := {"classic": 1.0, "stitching": 1.0, "alchemy": 1.04, "runecraft": 1.07, "arcane": 1.14}
## Hand-tuned per-station corrections on top of the data (zone ×, speed ×; > 1 zone = easier).
const STATION_TUNING := {
	"infusion_rack": {"zone": 1.15, "speed": 0.88},         # slightly easier multi-hit
	"resonance_pedestal": {"speed": 0.5},                   # was far too fast: half the sweep speed
	"grinding_wheel": {"zone": 1.12, "speed": 0.9},         # slightly easier edge control
	"rune_polishing_wheel": {"zone": 1.12, "speed": 0.9},
}
## Tutorial difficulty: used by practice runs, and everywhere when the player turns on the assist.
const ASSIST := {"zone": 1.55, "speed": 0.62}
## Fatigue: at work factor 0 the zone shrinks by this much (linear; a fresh smith loses nothing).
const FATIGUE_ZONE := 0.22
## Recipe complexity: each operation beyond three tightens the work a little (bounded).
const COMPLEXITY_PER_OP := 0.02
const COMPLEXITY_RANGE := Vector2(0.96, 1.12)


static func assist_on() -> bool:
	return bool(Settings.get_value("gameplay/check_assist", false))


## Check parameters for a station. EN: built from explicit factors so it reads like a recipe:
##   zone  = (base_zone × skill_zone + per_level + upgrades) ÷ complexity ÷ tier × tuning × fatigue × assist
##   speed = base_speed × skill_speed × complexity × tier × tuning × assist
## where skill weighs the recipe's difficulty against the relevant skill level (a beginner gets a
## narrow zone and a fast needle, an expert a wide zone and a slow one). `factors` in the result
## lists every multiplier for tooltips and tests. Quality itself is untouched: the minigames only
## turn these into tolerances and paces. opts: {"assist": bool} forces / suppresses the assist; {"actor": id} — the
## worker at the station (Living Workshop B1; default the smith): THEIR level in the station's skill sets the zone and
## pace, and the smith's fatigue counts only for the smith (Workers.check_params(actor, …) is the same call).
## DA: Prøvens zone og fart fra tydelige faktorer: færdighed mod sværhed, opskriftens kompleksitet,
##     stationens niveau, finjustering, træthed og evt. hjælp (tutorial-sværhed).
static func check_params(station_id: String, recipe_id := "", checks := -1, opts := {}) -> Dictionary:
	var c: Dictionary = DB.station(station_id).get("check", {"count": 1, "speed": 0.55, "zone": 34, "weight": 1.0})
	var sk := cfg("skill")
	var skill := skill_for_station(station_id)
	var actor: Variant = opts.get("actor", "player")
	var is_smith := Workers.kind(actor) == "player"
	var lvl := Workers.level(actor, skill)
	var f := {}
	# 1. skill against difficulty (recipe difficulty includes its material)
	var diff := float(difficulty(recipe_id)) if recipe_id != "" else 2.0
	var gap := diff - float(lvl)
	f["skill_zone"] = clampf(1.0 - float(sk.get("difficulty_zone", 0.06)) * gap, 0.55, 1.45)
	var per_level_zone := float(sk.get("zone_per_level", 1.4)) * lvl
	var level_ease := minf(float(sk.get("speed_ease_per_level", 0.015)) * lvl, float(sk.get("speed_ease_max", 0.3)))
	f["skill_speed"] = (1.0 - level_ease) * clampf(1.0 + float(sk.get("difficulty_speed", 0.05)) * gap, 0.75, 1.4)
	# 2. recipe complexity: number of operations
	var n_ops := operations(recipe_id).size() if recipe_id != "" else 3
	f["complexity"] = clampf(1.0 + COMPLEXITY_PER_OP * (n_ops - 3), COMPLEXITY_RANGE.x, COMPLEXITY_RANGE.y)
	# 3. workstation tier and hand tuning
	f["tier"] = float(STATION_TIER.get(str(DB.station(station_id).get("discipline", "classic")), 1.0))
	var tune: Dictionary = STATION_TUNING.get(Property.type_of(station_id), {})
	f["tune_zone"] = float(tune.get("zone", 1.0))
	f["tune_speed"] = float(tune.get("speed", 1.0))
	# 4. the smith's condition (his fatigue; other workers' tiredness is not modelled)
	var wf := clampf(Vitality.work_factor(), 0.0, 1.0) if is_smith else 1.0
	f["fatigue"] = 1.0 - FATIGUE_ZONE * (1.0 - wf)
	# 5. assist / tutorial difficulty
	var assist: bool = bool(opts.get("assist", assist_on()))
	f["assist_zone"] = float(ASSIST["zone"]) if assist else 1.0
	f["assist_speed"] = float(ASSIST["speed"]) if assist else 1.0
	var upgrade_zone := 0.0
	var upg: Dictionary = sk.get("upgrade_zone", {})
	for u in upg:
		var pair: Array = upg[u]
		if pair[0] == skill and Game.has_upgrade(u):
			upgrade_zone += float(pair[1])
	var zone: float = (float(c.get("zone", 34)) * float(f["skill_zone"]) + per_level_zone + upgrade_zone) \
		/ float(f["complexity"]) / float(f["tier"]) * float(f["tune_zone"]) * float(f["fatigue"]) * float(f["assist_zone"])
	var speed: float = float(c.get("speed", 0.55)) * float(f["skill_speed"]) * float(f["complexity"]) * float(f["tier"]) \
		* float(f["tune_speed"]) * float(f["assist_speed"])
	return {
		"count": checks if checks > 0 else int(c.get("count", 1)),
		"speed": speed,
		"zone": clampf(zone, 12.0, 90.0),
		"weight": float(c.get("weight", 1.0)),
		"skill": skill, "level": lvl, "difficulty": diff, "assist": assist, "factors": f, "actor": Workers.resolve(actor)["id"],
	}


## Practice / tutorial parameters for a station: the normal check at tutorial difficulty.
static func tutorial_params(station_id: String, recipe_id := "") -> Dictionary:
	return check_params(station_id, recipe_id, 1, {"assist": true})


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
	var t := Property.type_of(station_id)   # #37: any instance of the operation's station type
	if j.is_empty() or current_station() != t:
		return
	var o := current_op()
	var w := float(o.get("weight", 1.0))
	var sum := 0.0
	for q in qualities:
		j["samples"].append({"station": t, "q": float(q), "w": w})
		sum += float(q)
	if not j.has("ops"):
		j["ops"] = []
	var rec := {"op": str(o.get("op", "")), "station": t, "q": sum / maxf(1.0, qualities.size()), "checks": qualities.duplicate(), "w": w}
	if station_id != t or Property.instance_count(t) > 1:
		rec["at"] = station_id   # the instance he worked at
	j["ops"].append(rec)
	j["step"] = int(j["step"]) + 1
	j.erase("at")
	var sw := Steward.marked(j)   # S2: work begun under the steward teaches the smith nothing (also when he finishes it later)
	Steward.begin_marked(sw)
	Game.grant_player_xp(skill_for_station(station_id), 3 + qualities.size() * 2)
	Steward.end_marked(sw)
	Vitality.on_craft_step(qualities.size())
	if j.has("order"):
		WorkOrders.smith_op_done(j, rec)   # C1: his stage of a work order — the operation goes into the order
		Events.crafting_changed.emit()
		return
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
	return float(cfg("skill").get("quality_per_level", 0.4)) * Game.player_level(recipe_skill(recipe_id)) + hireling_assist(recipe_id) \
		+ SkillTree.quality_bonus(recipe_id)


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
## Rarity score and verdict from craftsmanship, the fortune die and bonuses (all from crafting.json). `crafted`:
## crafted work (canonical v1.6 §6.2) — no masterwork bonus in the score (Masterwork stays a craftsmanship distinction);
## found loot keeps the bonus. The crafted cap and the Legendary gates are crafted_rarity()'s business.
static func rarity_eval(quality: float, fortune: int, bonus := 0.0, crafted := false) -> Dictionary:
	var rc := cfg("rarity")
	var w: Dictionary = rc.get("weights", {"quality": 0.75, "fortune": 0.35})
	var th: Dictionary = rc.get("thresholds", {"magic": 68, "rare": 88, "legendary": 112})
	var mw: Dictionary = rc.get("masterwork", {"quality": 115, "bonus": 26})
	var parts := {"quality": quality * float(w["quality"]), "fortune": fortune * float(w["fortune"]), "bonus": bonus, "masterwork": 0.0}
	var is_mw := quality >= float(mw.get("quality", 115))
	if is_mw and not crafted:
		parts["masterwork"] = float(mw.get("bonus", 26))
	var score: float = parts["quality"] + parts["fortune"] + parts["bonus"] + parts["masterwork"]
	var rar := "common"
	for r in ["magic", "rare", "legendary"]:
		if score >= float(th[r]):
			rar = r
	return {"score": score, "rarity": rar, "parts": parts, "thresholds": th, "masterwork": is_mw}


## Canonical v1.6 §6.2 — crafted rarity: ordinary Designs top out at crafted_cap (Rare) whatever the rolls; a designated
## Legendary Design (recipes.json legendary) is Legendary only when every gate holds (legendary_shortfall). `skill_level`:
## the relevant craft's skill of the qualified worker; `master_specialist`: a master specialist made it (their
## craftsmanship cannot pass master_quality, so that ceiling counts as the craftsmanship gate).
static func crafted_rarity(rid: String, q: float, fortune: int, bonus: float, skill_level: int, master_specialist := false) -> Dictionary:
	var rev := rarity_eval(q, fortune, bonus, true)
	var why := legendary_shortfall(rid, q, fortune, float(rev["score"]), skill_level, master_specialist)
	rev["legendary_why"] = why
	rev["legendary_design"] = bool(DB.recipe(rid).get("legendary", false))
	if why.is_empty():
		rev["rarity"] = "legendary"
	else:
		var cap := str(cfg("rarity").get("crafted_cap", "rare"))
		if int(SkillTree.RARITY_RANK.get(str(rev["rarity"]), 0)) > int(SkillTree.RARITY_RANK.get(cap, 2)):
			rev["rarity"] = cap
			rev["capped"] = true
	return rev


## The rarity bonus a Design's material and runestone inputs bring (part of the rarity score).
static func rarity_bonus(rid: String) -> float:
	var r := DB.recipe(rid)
	var bonus := float(material(rid).get("rarity_bonus", 0))
	for inp in r.get("inputs", {}):
		if DB.item(inp).get("type") == "runestone" and inp != "runestone_blank":
			bonus += float(cfg("rarity").get("runestone_bonus", 8))
	return bonus


## What stands between this piece and Legendary ([] = nothing: it is Legendary). Plain player-facing reasons.
static func legendary_shortfall(rid: String, q: float, fortune: int, score: float, skill_level: int, master_specialist := false) -> Array:
	var lc: Dictionary = cfg("rarity").get("legendary_crafting", {})
	var r := DB.recipe(rid)
	if not bool(r.get("legendary", false)):
		return ["%s is not a Legendary Design — ordinary work tops out at Rare" % str(r.get("name", rid))]
	var out := []
	var need_skill := int(lc.get("skill", 6))
	if skill_level < need_skill:
		out.append("%s %d of %d — a master of the craft must work it" % [SkillSys.skill_name(recipe_skill(rid)), skill_level, need_skill])
	var need_q := float(lc.get("master_quality", 112)) if master_specialist else float(lc.get("quality", 115))
	if q < need_q:
		out.append("craftsmanship %d%% of %d%%" % [int(round(q)), int(need_q)])
	if fortune < int(lc.get("fortune", 95)):
		out.append("fortune %d of %d" % [fortune, int(lc.get("fortune", 95))])
	if score < float(lc.get("score", 125)):
		out.append("rarity score %d of %d" % [int(round(score)), int(lc.get("score", 125))])
	return out


# ------------------------------------------------------------------ weighted dice
## EN: Craftsmanship weights the STAT dice (edge, guard, temper, potency, resonance, spellweave) — not the
##     fortune or purity dice, so the rarity progression is unchanged. Digital dice roll the expression
##     several times and keep the best (advantage) or the worst (disadvantage); physical dice keep the
##     player's numbers and add a shown craftsmanship modifier worth about the same on average.
##       below 55%  heavy disadvantage  — roll 3, keep the lowest   (physical −25% of the die's range)
##       55–69%     disadvantage        — roll 2, keep the lowest   (−17%)
##       70–94%     even odds           — one roll                  (±0)
##       95–114%    advantage           — roll 2, keep the highest  (+17%)
##       115%+      strong advantage    — roll 3, keep the highest  (+25%)
## DA: Håndværket vægter statistik-terningerne: digitale slås flere gange (bedste/værste beholdes),
##     fysiske beholder spillerens tal og får en vist håndværksmodifikator.
const ADVANTAGE := [[115.0, 2, "strong advantage"], [95.0, 1, "advantage"], [70.0, 0, "even odds"], [55.0, -1, "disadvantage"], [-999.0, -2, "heavy disadvantage"]]
const PHYSICAL_SHIFT := {-2: -0.25, -1: -0.17, 0: 0.0, 1: 0.17, 2: 0.25}


## Advantage tier for a craftsmanship: {"tier": -2..2, "word", "rolls": how many times the die is rolled}.
static func advantage(quality: float) -> Dictionary:
	for a in ADVANTAGE:
		if quality >= float(a[0]):
			return {"tier": int(a[1]), "word": str(a[2]), "rolls": 1 + absi(int(a[1]))}
	return {"tier": 0, "word": "even odds", "rolls": 1}


## Is this die weighted by craftsmanship? (stat dice yes; fortune and purity no)
static func is_stat_die(key: String) -> bool:
	var stat := str(DB.crafting.get("dice", {}).get(key, {}).get("stat", key))
	return not stat in ["rarity", "yield"]


## Rolls one die expression for a craftsmanship: {"total", "faces", "rolls": [{"total","faces"}…], "kept": index,
## "tier", "word", "quality", "weighted"}. Stat dice roll 1–3 times and keep the best/worst; others roll once.
static func roll_weighted(key: String, expr: String, quality: float) -> Dictionary:
	var weighted := is_stat_die(key)
	var adv := advantage(quality) if weighted else {"tier": 0, "word": "even odds", "rolls": 1}
	var rolls := []
	var kept := 0
	for i in int(adv["rolls"]):
		var r := Dice.roll(expr)
		rolls.append({"total": int(r["total"]), "faces": r["faces"]})
		if i > 0:
			var better: bool = int(r["total"]) > int(rolls[kept]["total"])
			var worse: bool = int(r["total"]) < int(rolls[kept]["total"])
			if (int(adv["tier"]) > 0 and better) or (int(adv["tier"]) < 0 and worse):
				kept = i
	return {"total": int(rolls[kept]["total"]), "faces": rolls[kept]["faces"], "rolls": rolls, "kept": kept,
		"tier": int(adv["tier"]), "word": str(adv["word"]), "quality": quality, "weighted": weighted}


## Rolls every die of a recipe's dice spec for a craftsmanship (what the digital dice do).
static func roll_dice(spec: Dictionary, quality: float) -> Dictionary:
	var out := {}
	for k in spec:
		out[k] = roll_weighted(str(k), str(spec[k]), quality)
	return out


## Lowest and highest total an expression can show.
static func die_range(expr: String) -> Vector2i:
	var p := Dice.parse(expr)
	return Vector2i(int(p["n"]) + int(p["mod"]), int(p["n"]) * int(p["sides"]) + int(p["mod"]))


## The craftsmanship modifier added to a physically rolled stat die (shown to the player; 0 for fortune/purity).
static func physical_modifier(key: String, expr: String, quality: float) -> int:
	if not is_stat_die(key) or expr == "":
		return 0
	var rg := die_range(expr)
	return int(round(float(PHYSICAL_SHIFT[int(advantage(quality)["tier"])]) * float(rg.y - rg.x)))


## One line explaining a die: "rolled 14, 13 → kept 14 (advantage from 108% craftsmanship)".
static func die_explanation(e: Dictionary) -> String:
	var q := int(round(float(e.get("quality", 0))))
	match str(e.get("how", "")):
		"weighted":
			var rolls: Array = e.get("rolls", [])
			if not bool(e.get("weighted", true)):
				return "rolled %d (pure luck — craftsmanship does not weight this die)" % int(e.get("total", 0))
			if rolls.size() <= 1:
				return "rolled %d (even odds at %d%% craftsmanship)" % [int(e.get("total", 0)), q]
			var vals := PackedStringArray()
			for r in rolls:
				vals.append(str(int(r["total"])))
			return "rolled %s → kept %d (%s from %d%% craftsmanship)" % [", ".join(vals), int(e.get("total", 0)), str(e.get("word", "")), q]
		"physical":
			var m := int(e.get("mod", 0))
			if m == 0:
				return "you rolled %d%s" % [int(e.get("entered", 0)), "" if bool(e.get("weighted", true)) else " (pure luck — not weighted)"]
			return "you rolled %d, %+d from %d%% craftsmanship (%s) → counts as %d" % [int(e.get("entered", 0)), m, q, str(e.get("word", "")), int(e.get("total", 0))]
	return "set to %d" % int(e.get("total", 0))


# ------------------------------------------------------------------ stats
static func _norm(dice: Dictionary, spec: Dictionary, key: String, fallback := 0.5) -> float:
	if not dice.has(key) or not spec.has(key):
		return fallback
	var sides := Dice.sides(str(spec[key]))
	return clampf((float(dice[key]) - 1.0) / maxf(1.0, sides - 1.0), 0.0, 1.0)


## Statistics from definition × craftsmanship × material × dice × skill. Craftsmanship dominates;
## the main die moves a stat by ±15%, temper ±10% durability, potency/resonance ±20% effect.
## `explain` (optional, filled in place): per stat {base, range, craft, die, die_factor, material, skill, final}.
static func compute_stats(d: Dictionary, quality: float, dice: Dictionary, spec: Dictionary, mat: Dictionary, lvl: int, explain := {}) -> Dictionary:
	var st: Dictionary = d.get("stats", {})
	var q := clampf(quality / 100.0 * 0.85, 0.0, 1.15)
	var skill_mult := 1.0 + 0.01 * lvl
	var main_n := _norm(dice, spec, "edge", _norm(dice, spec, "guard", -1.0))
	var main_key := "edge" if dice.has("edge") and spec.has("edge") else ("guard" if dice.has("guard") and spec.has("guard") else "")
	var potency_n := _norm(dice, spec, "potency", _norm(dice, spec, "resonance", 0.5))
	var potency_key := "potency" if dice.has("potency") and spec.has("potency") else ("resonance" if dice.has("resonance") and spec.has("resonance") else "")
	if main_n < 0.0:
		main_n = potency_n
		main_key = potency_key
	var weave_n := _norm(dice, spec, "spellweave", main_n)
	var weave_key := "spellweave" if dice.has("spellweave") and spec.has("spellweave") else main_key
	var temper_n := _norm(dice, spec, "temper", 0.5)
	var ms := float(mat.get("stat", 1.0))
	var out := {}
	for key in st:
		var v: Variant = st[key]
		var base := 0.0
		var cq := 1.0
		var df := 1.0
		var dk := ""
		var mm := ms
		var sm := 1.0
		if v is Array:
			base = lerpf(float(v[0]), float(v[1]), q)
			df = 0.85 + main_n * 0.3
			dk = main_key
			sm = skill_mult
			out[key] = int(round(base * df * sm * mm))
		elif key == "durability":
			base = float(v)
			cq = 0.6 + 0.4 * minf(quality / 100.0, 1.25)
			df = 0.9 + temper_n * 0.2
			dk = "temper" if dice.has("temper") and spec.has("temper") else ""
			mm = float(mat.get("durability", 1.0))
			out[key] = int(round(base * cq * df * mm))
		elif key == "magic":
			base = float(v)
			cq = 0.7 + 0.3 * minf(quality / 100.0, 1.3)
			df = 0.85 + weave_n * 0.3
			dk = weave_key
			out[key] = int(round(base * cq * df * mm))
		else:
			base = float(v)
			cq = 0.7 + 0.3 * minf(quality / 100.0, 1.3)
			df = 0.8 + potency_n * 0.4
			dk = potency_key
			out[key] = maxi(1, int(round(base * cq * df * mm)))
		explain[key] = {"base": base, "range": v is Array, "craft": cq, "die": dk, "die_factor": df, "material": mm,
			"skill": sm, "final": int(out[key])}
	if out.has("durability"):
		out["durability_max"] = out["durability"]
	return out


## One stat's account: "Attack 14 = 11.2 from the item's range at 108% craftsmanship · edge die ×1.06 · Steel ×1.30 · Smithing 6 +6%".
static func stat_explanation(stat: String, e: Dictionary, quality: float, mat_name: String, skill_id: String, lvl: int) -> String:
	var bits := PackedStringArray()
	if bool(e.get("range", false)):
		bits.append("%.1f from the item's range at %d%% craftsmanship" % [float(e.get("base", 0)), int(round(quality))])
	else:
		bits.append("base %d × %.2f for %d%% craftsmanship" % [int(e.get("base", 0)), float(e.get("craft", 1.0)), int(round(quality))])
	if str(e.get("die", "")) != "":
		var lab := str(DB.crafting.get("dice", {}).get(str(e["die"]), {}).get("label", str(e["die"]).capitalize()))
		bits.append("%s die ×%.2f" % [lab.to_lower(), float(e.get("die_factor", 1.0))])
	if absf(float(e.get("material", 1.0)) - 1.0) > 0.001:
		bits.append("%s ×%.2f" % [mat_name if mat_name != "" else "material", float(e.get("material", 1.0))])
	if float(e.get("skill", 1.0)) > 1.0001:
		bits.append("%s %d %+d%%" % [SkillSys.skill_name(skill_id), lvl, int(round((float(e["skill"]) - 1.0) * 100.0))])
	return "%s [b]%d[/b] = %s" % [stat.capitalize(), int(e.get("final", 0)), " · ".join(bits)]


# ------------------------------------------------------------------ finishing
## Finalises the job. dice: {key: total} or {key: {"total", "faces"}}; mode "digital"/"physical".
static func finish(dice: Dictionary, mode := "digital") -> Dictionary:
	var j := job()
	if j.is_empty():
		return {}
	return build(str(j["recipe"]), j.get("ops", []), final_quality(j), dice, mode, {}, base_quality(j))


## Builds the finished piece — the one pipeline shared by the smith and his apprentices: dice (weighted by
## craftsmanship), statistics, rarity, arcane binding, the craft record, provenance, history, stats, the Hall of
## Fame and events. `maker` empty = the smith (his active job is closed, he gains the experience and any knowledge);
## otherwise an apprentice: {id, name, mark, level, supervised, rank} — the item carries their name and mark, made at
## the Ironhand forge; experience is the caller's business (Apprentices). `base` = quality before the skill bonus.
##   Living Workshop C1: `maker` {"smith": true, "xp_skills", "steward"} = a work order whose forging stage the smith
##   worked (his mark; experience only in the crafts he worked; his own craft job is left alone); `maker.uid` = the uid
##   the order reserved when it was created (the piece keeps it).
static func build(rid: String, ops: Array, q: float, dice: Dictionary, mode := "digital", maker := {}, base := -1.0) -> Dictionary:
	var order_smith := bool(maker.get("smith", false))
	var player := maker.is_empty() or order_smith
	var marked := (player and Steward.marked(job())) if not order_smith else bool(maker.get("steward", false))   # S2: a piece begun under the steward (no experience, no knowledge)
	var r := DB.recipe(rid)
	var spec: Dictionary = r.get("dice", {})
	var totals := {}
	var dice_log := {}
	if base < 0.0:
		base = q
	var adv := advantage(q)
	for k in dice:
		var v: Variant = dice[k]
		var total: int = int(v["total"]) if v is Dictionary else int(v)
		var faces: Array = v.get("faces", [total]) if v is Dictionary else [total]
		var expr := str(spec.get(k, ""))
		var entry := {"expr": expr, "total": total, "faces": faces, "quality": q, "weighted": is_stat_die(str(k)),
			"tier": int(adv["tier"]), "word": str(adv["word"])}
		if mode == "physical":
			# the player's own numbers stand; craftsmanship adds a shown modifier (kept within the die's range)
			var m := physical_modifier(str(k), expr, q)
			var rg := die_range(expr) if expr != "" else Vector2i(total, total)
			entry["how"] = "physical"
			entry["entered"] = total
			entry["mod"] = m
			total = clampi(total + m, rg.x, rg.y)
			entry["total"] = total
		elif v is Dictionary and v.has("rolls"):
			entry["how"] = "weighted"
			entry["rolls"] = v["rolls"]
			entry["kept"] = int(v.get("kept", 0))
		else:
			entry["how"] = "fixed"   # numbers given directly (tests, tools) are used exactly as given
		entry["text"] = die_explanation(entry)
		totals[k] = total
		dice_log[k] = entry
	var out_def: String = r["output"]
	var d := DB.item(out_def)
	var skill_id := recipe_skill(rid)
	var lvl := Game.player_level(skill_id) if player else int(maker.get("level", 0))
	var mat := material(rid)
	var it := Items.make(out_def, {"quality": q, "qty": int(r.get("qty", 1)), "crafted_by": "Brannoc Ironhand" if player else str(maker.get("name", ""))})
	if int(maker.get("uid", 0)) > 0:
		it["uid"] = int(maker["uid"])   # C1: one identity from the order's creation to the finished piece
	var explain := {}
	it["stats"] = compute_stats(d, q, totals, spec, mat, lvl, explain)
	var breakdown := []
	for sk_key in explain:
		breakdown.append(stat_explanation(str(sk_key), explain[sk_key], q, str(mat.get("name", "")), skill_id, lvl))
	# rarity: quality + fortune + material + runestone bonuses
	var bonus := rarity_bonus(rid)
	var fortune := int(totals.get("fortune", 50))
	# canonical v1.6 §6.2: the relevant craft's skill of the qualified worker (the smith; an apprentice maker; for a work
	# order the best of whoever worked that craft's stages) and whether a master specialist's ceiling bounds the work
	var leg_skill := int(maker.get("skill_level", Game.player_level(skill_id) if player else int(maker.get("level", 0))))
	var master_spec := not player and str(maker.get("rank", "")) == "master"
	var rev := crafted_rarity(rid, q, fortune, bonus, leg_skill, master_spec) if totals.has("fortune") else {"score": 0.0, "rarity": "common", "parts": {}, "masterwork": false, "legendary_why": []}
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
	# legendary-grade recipes (dragon scale) never leave the forge below their minimum rarity
	var min_rank := SkillTree.min_rarity_rank(rid)
	if int(SkillTree.RARITY_RANK.get(rar, 0)) < min_rank:
		rar = str(r.get("min_rarity", rar))
	if it["rarity"] == "common" and rar != "common":
		if Items.is_equipment(it):
			Items.apply_rarity(it, rar)
		else:
			_apply_rarity_plain(it, rar)
	# materials: excellent work or a pure batch yields a bonus unit
	var yield_rec := {}
	if not Items.is_equipment(it) and d.get("stack", false):
		yield_rec = {"base": int(it["qty"]), "bonus": 0, "why": "", "purity": int(totals.get("purity", 0)) if totals.has("purity") else -1}
		if q >= YIELD_BONUS_Q or int(totals.get("purity", 0)) >= 6:
			it["qty"] = int(it["qty"]) + 1
			yield_rec["bonus"] = 1
			yield_rec["why"] = "craftsmanship" if q >= YIELD_BONUS_Q else "purity"
	var parts := []
	for k in totals:
		parts.append("%s %d" % [k, int(totals[k])])
	it["dice_log"] = ", ".join(parts)
	# experience: experts learn little from routine work
	var sk := cfg("skill")
	var xp := {}
	var expert := lvl - difficulty(rid) >= int(sk.get("xp_expert_gap", 5))
	if player:
		Steward.begin_marked(marked)
		for skill in r.get("xp", {}):
			if order_smith and not (maker.get("xp_skills", []) as Array).has(str(skill)):
				continue   # C1: a specialist's stage teaches the smith nothing of their craft
			var amt := float(r["xp"][skill]) * (0.6 + q / 200.0)
			# an expert smith may still be a novice miner: damp only a skill he is also expert in (Mining XP hotfix)
			if expert and Game.player_level(str(skill)) - difficulty(rid) >= int(sk.get("xp_expert_gap", 5)):
				amt *= float(sk.get("xp_expert_mult", 0.4))
			if not Workers.can_grow("player", str(skill)):
				continue   # B1: another craft at the smith's basic level teaches him nothing more (the record says so)
			xp[skill] = int(round(amt))
			Game.grant_player_xp(skill, xp[skill])
		Steward.end_marked(marked)
		if marked or Steward.is_active():
			xp = {}   # withheld (Game.grant_player_xp refused it): the record says what was really gained
	it["craft"] = {
		"recipe": rid, "recipe_name": r.get("name", rid), "material": mat.get("name", ""),
		"difficulty": difficulty(rid), "skill": skill_id, "level": lvl,
		"ops": ops.duplicate(true), "base_quality": base, "skill_bonus": q - base, "quality": q,
		"dice": dice_log, "dice_mode": mode, "rarity_score": rev["score"], "rarity_parts": rev.get("parts", {}),
		"legendary_design": bool(rev.get("legendary_design", false)), "legendary_why": rev.get("legendary_why", []),
		"rarity_capped": bool(rev.get("capped", false)),
		"masterwork": rev.get("masterwork", false), "xp": xp, "expert": expert, "day": Game.day(),
		"advantage": {"tier": int(adv["tier"]), "word": str(adv["word"]), "rolls": int(adv["rolls"])},
		"breakdown": breakdown, "tree_bonus": SkillTree.quality_bonus(rid) if player else 0.0, "assist_bonus": hireling_assist(rid) if player else 0.0,
	}
	if not yield_rec.is_empty():
		it["craft"]["yield"] = yield_rec   # S2: what made the batch (shown on the result screen)
	if order_smith:
		it["craft"]["order"] = true
	if not player:
		it["craft"]["maker"] = str(maker.get("id", ""))
		it["craft"]["maker_name"] = str(maker.get("name", ""))
		it["craft"]["rank"] = str(maker.get("rank", ""))
		it["craft"]["supervised"] = bool(maker.get("supervised", false))
	it["owner"] = "smith"
	# the maker's mark, origin and the "forged" event — the start of the piece's story
	Provenance.forged(it, {} if player else maker)
	History.log_crafted(it)   # workstation logs (Interface)
	if player and not order_smith:
		Game.state["craft"] = {}
		Game.state["stats"]["crafted"] += 1
	elif order_smith:
		Game.state["stats"]["crafted"] += 1
	else:
		Game.state["stats"]["apprentice_crafted"] = int(Game.state["stats"].get("apprentice_crafted", 0)) + 1
	if player and (out_def == "ingot_mithril" or out_def == "sword_mithril"):
		Game.set_flag("crafted_arcane")
	# some work teaches the smith something (restoring an old runestone → rune lore)
	var teach := str(r.get("teaches_flag", "")) if player and not marked and not Steward.is_active() else ""
	if teach != "" and not Game.has_flag(teach):
		Game.set_flag(teach)
		var fi := SkillTree.flag_info(teach)
		Game.journal("Working on the %s taught me something new: %s." % [r.get("name", rid), str(fi.get("name", teach)).to_lower()])
		Events.toast.emit("New knowledge: %s" % fi.get("name", teach), "good")
	Game.add_item(it, false)
	if player:
		Events.crafting_changed.emit()
	Events.item_crafted.emit(it)
	if it.get("rarity") == "legendary":
		Game.state["stats"]["legendaries"] += 1
		Events.legendary_found.emit(it)
	if player and not marked and not Steward.is_active():
		Objectives.on_crafted(it)
	Recognition.on_crafted(it)
	Log.info("Crafted %s (q %.1f%%, %s, score %.1f)%s" % [it["name"], q, it["rarity"], float(rev["score"]), "" if player else " by " + str(maker.get("name", ""))])
	return it


## Rarity for potions, runestones and materials: a name prefix and stronger effect, no affixes.
static func _apply_rarity_plain(it: Dictionary, rar: String) -> void:
	var p: Array = NON_EQUIP_RARITY.get(rar, ["", 1.0])
	it["rarity"] = rar
	it["name"] = "%s %s" % [p[0], it["name"]]
	it["star"] = rar == "legendary"
	for k in it["stats"]:
		it["stats"][k] = int(round(float(it["stats"][k]) * float(p[1])))


const TREATMENTS := {"oil_whetstone": ["attack", "Whetstone Oil"], "coating_flame": ["fire", "Flame Coating"], "coating_frost": ["frost", "Frost Coating"],
	"infusion_aether": ["magic", "Aether Infusion"], "coating_wyrmfire": ["fire", "Wyrmfire Coating"]}


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
	Provenance.workshop(it, "treated", "Treated with %s at the Ironhand forge (+%d %s)." % [t[1], val, t[0]])
	ItemSpirit.speak(it, "treat")
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
	Provenance.workshop(it, "enchanted", "A %s was set into it at the Ironhand forge." % DB.item(rune_def).get("name", rune_def))
	ItemSpirit.speak(it, "enchant")
	Game.grant_player_xp("runecraft", 20)
	Events.inventory_changed.emit()
	return true
