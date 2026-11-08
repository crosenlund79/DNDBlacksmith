## Refinement — improving a piece that already exists, without ever making it a different piece.
## EN: Four workshop actions share one pipeline (plan → precision check → perform → one Lore event):
##       Refine  — hone/planish at the grinding wheel (or stitching table): craftsmanship up a little, existing
##                 stats follow, fine work nudges existing affixes within their legal range.
##       Rework  — re-roll ONE chosen affix (or the main stat's die) within its legal range with dice weighted by
##                 the check, at the anvil (physical) or the rune engraving stand (magical).
##       Upgrade — one material step (iron → steel plating, steel → mithril edge, leather → bear leather …):
##                 base stats scale by the material ratio; needs the new material's know-how and station.
##       Reforge — the existing reforge (made whole, craftsmanship may rise), now with the same plan/UI/history.
##     Limits: a per-piece budget (refine 3, rework 2, upgrade 1), a craftsmanship ceiling tied to the original
##     work and the smith's skill, diminishing returns, no rarity change, and no stat above what a freshly made
##     piece of that kind/material/rarity could reach (fresh_cap). Failures cost the materials and at worst a
##     little craftsmanship or durability — never the piece, its rarity or its history.
##     Identity: uid, maker & mark, name, owners, Epic, rarity, spirit and every Lore event stay; each improvement
##     is ONE new Lore event (kind refined/reworked/upgraded/reforged) whose data holds the smith, station,
##     materials, check, outcome and every stat change. Bookkeeping lives on the item: it["refine"].
## DA: Forbedring af eksisterende udstyr (forfin, omarbejd, opgradér, omsmed) — samme genstand, ny historie.
class_name Refinement
extends RefCounted

const ACTIONS := ["refine", "rework", "upgrade", "reforge"]
const KIND := {"refine": "refined", "rework": "reworked", "upgrade": "upgraded", "reforge": "reforged"}
const LABEL := {"refine": "Refine", "rework": "Rework", "upgrade": "Upgrade", "reforge": "Reforge"}
const BLURB := {
	"refine": "Hone and planish the piece: its craftsmanship rises a little and its stats follow.",
	"rework": "Re-cut one attribute: it is re-rolled within its legal range, the dice weighted by your work.",
	"upgrade": "Add a better material: its base stats rise one material step.",
	"reforge": "Heat and rework it whole: made sound again; fine work can raise its craftsmanship.",
}
## Improvements allowed per piece (successful ones count; -1 = no count, only the ceiling limits it).
const LIMIT := {"refine": 3, "rework": 2, "upgrade": 1, "reforge": -1}
## Check thresholds: at or above SUCCESS the work takes; below FAIL it slips (a small, recoverable loss).
const SUCCESS := {"refine": 70.0, "rework": 50.0, "upgrade": 60.0, "reforge": 0.0}
const FAIL := {"refine": 50.0, "rework": 40.0, "upgrade": 40.0, "reforge": -1.0}
const XP := {"refine": 6, "rework": 8, "upgrade": 16, "reforge": 12}
const SPIRIT_CTX := {"refine": "sharpen", "rework": "enchant", "upgrade": "reforge", "reforge": "reforge"}
const MAGIC_STATS := ["fire", "frost", "magic", "ward", "luck", "vitality"]
const FAMILY := {"iron": "metal", "steel": "metal", "silver": "metal", "mithril": "metal", "jewel": "metal", "adamantine": "metal",
	"starmetal": "metal", "orichalcum": "metal", "dragonscale": "metal", "runestone": "metal", "ore": "metal",
	"leather": "leather", "bearhide": "leather", "wyrmhide": "leather", "ethereal": "leather",
	"cloth": "cloth", "silk": "cloth", "moonweave": "cloth", "spidersilk": "cloth", "warded_cloth": "cloth"}
const OWN_STOCK := {"iron": "ingot_iron", "steel": "ingot_steel", "mithril": "ingot_mithril", "adamantine": "ingot_adamantine",
	"orichalcum": "ingot_orichalcum", "starmetal": "ingot_steel", "silver": "ore_silver", "jewel": "ore_silver", "dragonscale": "ingot_steel"}
## One material step: to, the material added, the station and a recipe whose know-how the step needs.
const STEPS := {
	"iron": {"to": "steel", "add": "ingot_steel", "station": "anvil", "gate": "smelt_steel", "words": "steel plating"},
	"steel": {"to": "mithril", "add": "ingot_mithril", "station": "arcane_anvil", "gate": "mithril_runeblade", "words": "a mithril edge"},
	"leather": {"to": "bearhide", "add": "leather_bear", "station": "stitching_table", "gate": "cure_bear_leather", "words": "bear-leather facings"},
	"bearhide": {"to": "wyrmhide", "add": "leather_wyrm", "station": "stitching_table", "gate": "wyrmleather_boots", "words": "wyrm-leather facings"},
	"cloth": {"to": "silk", "add": "cloth_silk", "station": "tailors_bench", "gate": "weave_silk", "words": "a silk lining"},
	"silk": {"to": "moonweave", "add": "cloth_moonweave", "station": "tailors_bench", "gate": "weave_moonweave", "words": "a moonweave lining"},
}
const PLACE_WORD := {"anvil": "forge and anvil", "grinding_wheel": "grinding wheel", "rune_engraving_stand": "rune engraving stand",
	"stitching_table": "stitching table", "tailors_bench": "tailor's bench", "arcane_anvil": "arcane anvil"}

static var _recipe_by_output := {}


# ======================================================================= item facts
static func rec(it: Dictionary) -> Dictionary:
	if not it.has("refine"):
		it["refine"] = {"refined": 0, "reworked": 0, "upgraded": 0, "reforged": 0, "steps": []}
	return it["refine"]


## The recipe a piece is made from (its craft record, else the simplest recipe with that output).
static func recipe_of(it: Dictionary) -> String:
	var rid := str(it.get("craft", {}).get("recipe", ""))
	if rid != "" and not DB.recipe(rid).is_empty():
		return rid
	if _recipe_by_output.is_empty():
		for r in DB.recipes.values():
			var out := str(r.get("output", ""))
			if not _recipe_by_output.has(out) or int(r.get("difficulty", 1)) < int(DB.recipe(_recipe_by_output[out]).get("difficulty", 1)):
				_recipe_by_output[out] = str(r["id"])
	return str(_recipe_by_output.get(str(it.get("def", "")), ""))


## The working material of the piece (after any upgrade).
static func material_of(it: Dictionary) -> String:
	var m := str(it.get("refine", {}).get("material", ""))
	if m != "":
		return m
	var rid := recipe_of(it)
	if rid != "":
		return str(DB.recipe(rid).get("material", "iron"))
	var t := str(Items.def(it).get("type", ""))
	if t in ["armor_leather", "boots", "gloves", "belt"]:
		return "leather"
	if t in ["armor_cloth", "cloak"]:
		return "cloth"
	return {1: "iron", 2: "steel", 3: "mithril", 4: "adamantine"}.get(Items.tier(it), "iron")


static func material_name(m: String) -> String:
	return str(Crafting.cfg("materials").get(m, {}).get("name", m.capitalize()))


static func family(it: Dictionary) -> String:
	return str(FAMILY.get(material_of(it), "metal"))


static func used(it: Dictionary, action: String) -> int:
	return int(it.get("refine", {}).get(KIND[action], 0))


## Improvements left for an action (-1 = unlimited).
static func left(it: Dictionary, action: String) -> int:
	var lim := int(LIMIT[action])
	return -1 if lim < 0 else maxi(0, lim - used(it, action))


static func origin_quality(it: Dictionary) -> float:
	if it.has("prov"):
		return float(Provenance.st(it).get("origin", {}).get("quality", it.get("quality", 70.0)))
	return float(it.get("quality", 70.0))


## The highest craftsmanship refinement can bring this piece to: a little above the original work, and no
## finer than the smith's own skill allows (never below what it already has).
static func ceiling(it: Dictionary) -> float:
	var skill := Crafting.skill_for_station(station_for(it, "refine"))
	var q0 := origin_quality(it)
	var cap := minf(q0 + 15.0, 95.0 + 2.5 * float(Game.player_level(skill)))
	return clampf(maxf(cap, q0), 1.0, 125.0)


## The best stats a freshly made piece of this kind, material and rarity could have (best check, best dice).
static func fresh_cap(it: Dictionary, mat_id := "") -> Dictionary:
	var rid := recipe_of(it)
	var spec: Dictionary = DB.recipe(rid).get("dice", {}) if rid != "" else {}
	if spec.is_empty():
		spec = {"edge": "1d20", "temper": "1d12"}
	var dice := {}
	for k in spec:
		dice[k] = Crafting.die_range(str(spec[k])).y
	var mats: Dictionary = Crafting.cfg("materials")
	var m: Dictionary = mats.get(mat_id if mat_id != "" else material_of(it), {"stat": 1.0, "durability": 1.0})
	var skill := Crafting.recipe_skill(rid) if rid != "" else "smithing"
	var lvl := maxi(Game.player_level(skill), int(it.get("craft", {}).get("level", 0)))
	var cap := Crafting.compute_stats(Items.def(it), 125.0, dice, spec, m, lvl)
	if str(it.get("rarity", "")) == "legendary":
		for k in ["attack", "protection", "magic"]:
			if cap.has(k):
				cap[k] = int(round(float(cap[k]) * 1.15))
	return cap


static func _qf(q: float) -> float:
	return 0.7 + 0.3 * minf(q / 100.0, 1.3)


## A stat never rises above max(fresh cap, what it already is).
static func _capped(key: String, v: int, old: int, cap: Dictionary) -> int:
	if not cap.has(key):
		return v
	return mini(v, maxi(int(cap[key]), old))


# ======================================================================= where and with what
## A station's name to follow "the" ("The Anvil" → "Anvil").
static func station_label(st: String) -> String:
	var n := str(DB.station(st).get("name", st))
	return n.substr(4) if n.begins_with("The ") else n


static func station_for(it: Dictionary, action: String, target := "") -> String:
	var fam := family(it)
	match action:
		"refine":
			return "grinding_wheel" if fam == "metal" else "stitching_table"
		"rework":
			var t := _target(it, target)
			if str(t.get("stat", "")) in MAGIC_STATS:
				return "rune_engraving_stand"
			return "anvil" if fam == "metal" else "stitching_table"
		"upgrade":
			return str(STEPS.get(material_of(it), {}).get("station", "anvil"))
	return "anvil"


static func inputs_for(it: Dictionary, action: String, target := "") -> Dictionary:
	var fam := family(it)
	var big := Items.slot(it) in ["armor", "shield"]
	match action:
		"refine":
			return {"reagent_salt": 1} if fam == "metal" else {"thread_linen": 1}
		"rework":
			if station_for(it, action, target) == "rune_engraving_stand":
				return {"reagent_salt": 1, "coal": 1}
			if fam == "metal":
				return {str(OWN_STOCK.get(material_of(it), "ingot_iron")): 1, "coal": 1}
			return {"leather_cured": 1, "thread_linen": 1}
		"upgrade":
			var s: Dictionary = STEPS.get(material_of(it), {})
			if s.is_empty():
				return {}
			var out := {str(s["add"]): 2 if big else 1}
			if fam == "metal":
				out["coal"] = 1
			else:
				out["thread_linen"] = 1
			return out
	return {"coal": 1}


## The attributes Rework can re-cut: [{id, label, kind: affix|stat, stat, value, lo, hi}].
static func rework_targets(it: Dictionary) -> Array:
	var out := []
	var d := Items.def(it)
	for key in ["attack", "protection"]:
		if d.get("stats", {}).get(key) is Array:
			var rg := _stat_range(it, key)
			out.append({"id": "stat:" + key, "kind": "stat", "stat": key, "label": "%s — the %s die" % [key.capitalize(), "edge" if key == "attack" else "guard"],
				"value": int(it.get("stats", {}).get(key, 0)), "lo": int(rg.x), "hi": int(rg.y)})
	var affs: Array = it.get("affixes", [])
	for i in affs.size():
		var a: Dictionary = affs[i]
		var info := _affix_info(str(a.get("id", "")))
		if info.is_empty():
			continue   # runes and bound abilities are set, not re-cut
		var m := 2 if str(it.get("rarity", "")) == "legendary" else 1
		var nm := str(info.get("prefix", info.get("suffix", "")))
		out.append({"id": "affix:%d" % i, "kind": "affix", "stat": str(a["stat"]), "label": "%s — +%d %s" % [nm, int(a["value"]), str(a["stat"])],
			"value": int(a["value"]), "lo": int(info["lo"]) * m, "hi": int(info["hi"]) * m})
	return out


static func _affix_info(id: String) -> Dictionary:
	for a in Items.AFFIXES:
		if str(a["id"]) == id:
			return a
	return {}


static func _target(it: Dictionary, target: String) -> Dictionary:
	var ts := rework_targets(it)
	for t in ts:
		if str(t["id"]) == target:
			return t
	if ts.is_empty():
		return {}
	var first: Dictionary = ts[0]
	return first


## The legal range of a base stat at the piece's current craftsmanship and material (worst die → best die),
## never above the fresh cap, never below what it is.
static func _stat_range(it: Dictionary, key: String) -> Vector2i:
	var lo := _stat_with_die(it, key, 0.0)
	var hi := _stat_with_die(it, key, 1.0)
	var cap := fresh_cap(it)
	hi = mini(hi, int(cap.get(key, hi)))
	return Vector2i(mini(lo, hi), hi)


static func _stat_with_die(it: Dictionary, key: String, n: float) -> int:
	var rid := recipe_of(it)
	var spec := {"edge": "1d20"} if key == "attack" else {"guard": "1d20"}
	var dk := "edge" if key == "attack" else "guard"
	var dice := {dk: 1 + int(round(n * 19.0))}
	var mats: Dictionary = Crafting.cfg("materials")
	var m: Dictionary = mats.get(material_of(it), {"stat": 1.0, "durability": 1.0})
	var lvl := int(it.get("craft", {}).get("level", Game.player_level(Crafting.recipe_skill(rid) if rid != "" else "smithing")))
	var st := Crafting.compute_stats({"stats": {key: Items.def(it).get("stats", {}).get(key, [0, 0])}}, float(it.get("quality", 70.0)), dice, spec, m, lvl)
	var v := int(st.get(key, 0))
	if str(it.get("rarity", "")) == "legendary":
		v = int(round(float(v) * 1.15))
	return v


## Does the smith know how to work a material? The gate recipe's skill-tree node, discovery flag and skill
## levels (its stations are not needed — the upgrade has its own).
static func knowhow_reason(rid: String) -> String:
	var r := DB.recipe(rid)
	var tr := SkillTree.recipe_reason(rid)
	if tr != "":
		return tr
	var rf := str(r.get("requires_flag", ""))
	if rf != "" and not Game.has_flag(rf):
		return "a forgotten craft — find its notes among the relics"
	var req: Dictionary = r.get("requires", {})
	for sk in req:
		if Game.player_level(str(sk)) < int(req[sk]):
			return "requires %s %d" % [SkillSys.skill_name(str(sk)), int(req[sk])]
	return ""


# ======================================================================= the plan (what the UI shows before work)
## What an action would need and do, before any work: {ok, why, obstacles:[...], station, station_name,
## station_why, inputs, missing, left, limit, ceiling, rows:[{label, now, lo, hi}], next_step, target, check}.
static func plan(it: Dictionary, action: String, opts := {}) -> Dictionary:
	var out := {"ok": false, "why": "", "obstacles": [], "action": action, "rows": [], "inputs": {}, "missing": {}}
	if it.is_empty() or not Items.is_equipment(it):
		out["why"] = "Choose a piece of equipment from your stores."
		out["obstacles"] = [out["why"]]
		return out
	var target := str(opts.get("target", ""))
	var st := station_for(it, action, target)
	out["station"] = st
	out["station_name"] = station_label(st)
	out["here"] = str(opts.get("station", st)) == st
	out["limit"] = int(LIMIT[action])
	out["left"] = left(it, action)
	out["ceiling"] = ceiling(it)
	out["material"] = material_of(it)
	var obs := []
	var sw := Crafting.station_locked_reason(st)
	out["station_why"] = sw
	if sw != "":
		obs.append("%s — %s" % [out["station_name"], sw])
	if Game.find_uid(int(it.get("uid", -1))).is_empty():
		obs.append("It must be in your stores to be worked on.")
	if int(out["left"]) == 0:
		obs.append("No more %s for this piece (%d of %d used) — more would spoil it." % [{"refine": "refining", "rework": "reworking", "upgrade": "upgrades"}.get(action, action), used(it, action), int(LIMIT[action])])
	match action:
		"refine":
			if float(it.get("quality", 0.0)) >= float(out["ceiling"]) - 0.5:
				obs.append("At its ceiling: %d%% is as fine as your skill and the original work allow." % int(round(float(out["ceiling"]))))
		"rework":
			var t := _target(it, target)
			if t.is_empty():
				obs.append("Nothing on it can be re-cut (no affix or ranged stat).")
			else:
				out["target"] = t
				if int(t["lo"]) >= int(t["hi"]):
					obs.append("%s has no room to change." % str(t["label"]))
		"upgrade":
			var s: Dictionary = STEPS.get(material_of(it), {})
			if s.is_empty():
				obs.append("%s is already the finest material it can take a step from." % material_name(material_of(it)))
			else:
				out["next_step"] = s
				var gw := knowhow_reason(str(s["gate"]))
				if gw != "":
					obs.append("You do not yet know how to work %s — %s" % [material_name(str(s["to"])), gw])
	var inp := inputs_for(it, action, target)
	out["inputs"] = inp
	var miss := {}
	for d in inp:
		var have := Game.count(str(d))
		if have < int(inp[d]):
			miss[d] = int(inp[d]) - have
	out["missing"] = miss
	for d in miss:
		obs.append("Missing %d × %s" % [int(miss[d]), str(DB.item(str(d)).get("name", d))])
	out["obstacles"] = obs
	out["ok"] = obs.is_empty()
	out["why"] = "" if obs.is_empty() else str(obs[0])
	out["rows"] = preview_rows(it, action, target)
	var c := Crafting.check_params(st, str(STEPS.get(material_of(it), {}).get("gate", "")) if action == "upgrade" else "", mini(2, int(DB.station(st).get("check", {}).get("count", 1))))
	out["check"] = c
	return out


## Before / after rows for the comparison (expected outcome of good work; lo..hi where dice decide).
static func preview_rows(it: Dictionary, action: String, target := "") -> Array:
	var rows := []
	var q := float(it.get("quality", 0.0))
	var cap := fresh_cap(it)
	match action:
		"refine", "reforge":
			var q1 := _gain_quality(it, action, 112.0)
			rows.append({"label": "Craftsmanship", "now": int(round(q)), "lo": int(round(q)), "hi": int(round(q1)), "pct": true})
			var f := _qf(q1) / _qf(q)
			for k in _stat_keys(it):
				var v := int(it["stats"][k])
				var up := maxi(v, int(round(float(v) * f)))
				if action == "refine":
					up = maxi(up, v + 1)   # fine work (95%+) draws each stat up by at least one
				rows.append({"label": k.capitalize(), "now": v, "lo": v, "hi": _capped(k, up, v, cap)})
			if action == "refine":
				for a in it.get("affixes", []):
					var info := _affix_info(str(a.get("id", "")))
					if not info.is_empty():
						var hi := int(info["hi"]) * (2 if str(it.get("rarity", "")) == "legendary" else 1)
						rows.append({"label": "+%s (%s)" % [str(a["stat"]), str(info.get("prefix", info.get("suffix", "")))], "now": int(a["value"]), "lo": int(a["value"]), "hi": mini(hi, int(a["value"]) + 1)})
			_dur_row(it, rows, action)
		"rework":
			var t := _target(it, target)
			if not t.is_empty():
				rows.append({"label": str(t["label"]).get_slice(" — ", 0) + " (" + str(t["stat"]) + ")", "now": int(t["value"]), "lo": int(t["lo"]), "hi": int(t["hi"]), "dice": true})
		"upgrade":
			var s: Dictionary = STEPS.get(material_of(it), {})
			if not s.is_empty():
				var mats: Dictionary = Crafting.cfg("materials")
				var a: Dictionary = mats.get(material_of(it), {"stat": 1.0, "durability": 1.0})
				var b: Dictionary = mats.get(str(s["to"]), {"stat": 1.0, "durability": 1.0})
				var cap2 := fresh_cap(it, str(s["to"]))
				rows.append({"label": "Material", "now_text": material_name(material_of(it)), "after_text": material_name(str(s["to"]))})
				for k in _stat_keys(it):
					var v := int(it["stats"][k])
					var r := float(b.get("stat", 1.0)) / maxf(0.01, float(a.get("stat", 1.0)))
					rows.append({"label": k.capitalize(), "now": v, "lo": v, "hi": _capped(k, maxi(v, int(round(float(v) * r))), v, cap2)})
				var stt: Dictionary = it.get("stats", {})
				if stt.has("durability_max"):
					var dr := float(b.get("durability", 1.0)) / maxf(0.01, float(a.get("durability", 1.0)))
					var dm := int(stt["durability_max"])
					rows.append({"label": "Durability (max)", "now": dm, "lo": dm, "hi": _capped("durability", maxi(dm, int(round(float(dm) * dr))), dm, cap2)})
	return rows


static func _dur_row(it: Dictionary, rows: Array, action: String) -> void:
	var st: Dictionary = it.get("stats", {})
	if not st.has("durability_max"):
		return
	var d := int(st.get("durability", 0))
	var m := int(st["durability_max"])
	var after := m if action == "reforge" else mini(m, d + int(round(float(m) * 0.2)))
	rows.append({"label": "Durability", "now_text": "%d / %d" % [d, m], "after_text": "%d / %d" % [after, m] + (" (made whole)" if action == "reforge" else "")})


static func _stat_keys(it: Dictionary) -> Array:
	var out := []
	var st: Dictionary = it.get("stats", {})
	for k in st:
		if str(k) in ["durability", "durability_max"]:
			continue
		if (st[k] is int or st[k] is float) and int(st[k]) > 0:
			out.append(str(k))
	return out


## Craftsmanship after refining/reforging with a check of `q` (ceiling, diminishing returns).
static func _gain_quality(it: Dictionary, action: String, q: float) -> float:
	var q0 := float(it.get("quality", 70.0))
	var ceil_q := maxf(q0, ceiling(it))
	var gain := 0.0
	if action == "refine":
		var skill := Crafting.skill_for_station(station_for(it, "refine"))
		gain = clampf((q - 65.0) * 0.15, 0.0, 7.0) * (1.0 + 0.02 * Game.player_level(skill)) / (1.0 + 0.5 * used(it, "refine"))
	else:
		# the original reforge: up to +8 when the rework is finer than the piece; each later reforge gives less
		gain = (clampf((q - q0) * 0.3, 0.0, 8.0) if q > q0 else 0.0) / (1.0 + 0.5 * used(it, "reforge"))
	return minf(ceil_q, q0 + gain)


# ======================================================================= doing the work
## Runs an action on a piece in the stores with the check quality `quality` (the minigame's score, or a fixed
## score in tests). opts: {target (rework), station (where the smith stands), roll (rework die 1–20, tests)}.
## Returns {ok, text, kind, action, outcome: success|partial|fail, before, after, changes, event}.
static func perform(uid: int, action: String, quality: float, opts := {}) -> Dictionary:
	var it := Game.find_uid(uid)
	if it.is_empty() or not Items.is_equipment(it):
		return {"ok": false, "text": "Nothing to %s." % action}
	var p := plan(it, action, opts)
	if not bool(p["ok"]):
		if action == "reforge" and p["missing"].has("coal"):
			return {"ok": false, "text": "You need a sack of coal to heat the forge for reforging."}
		return {"ok": false, "text": str(p["why"])}
	for d in p["inputs"]:
		Game.remove_def(str(d), int(p["inputs"][d]))
	var before := snapshot(it)
	var res := {}
	match action:
		"refine": res = _do_refine(it, quality)
		"rework": res = _do_rework(it, quality, str(opts.get("target", "")), int(opts.get("roll", 0)))
		"upgrade": res = _do_upgrade(it, quality)
		_: res = _do_reforge(it, quality)
	var outcome := str(res.get("outcome", "success"))
	var r := rec(it)
	if outcome == "success":
		r[KIND[action]] = int(r.get(KIND[action], 0)) + 1
	var after := snapshot(it)
	var changes := diff(before, after)
	var mats := PackedStringArray()
	for d in p["inputs"]:
		mats.append("%d %s" % [int(p["inputs"][d]), str(DB.item(str(d)).get("name", d))])
	var text := "%s at the Ironhand %s (%d%%): %s." % [{"refine": "Refined", "rework": "Reworked", "upgrade": "Upgraded", "reforge": "Reforged"}[action],
		PLACE_WORD.get(str(p["station"]), str(p["station_name"]).to_lower()), int(round(quality)), str(res.get("summary", ""))]
	if not changes.is_empty():
		text += " " + change_text(changes) + "."
	var data := {"action": action, "smith": Provenance.SMITH_ID, "smith_name": Provenance.SMITH_NAME, "station": str(p["station"]),
		"materials": (p["inputs"] as Dictionary).duplicate(), "check": quality, "outcome": outcome, "changes": changes,
		"quality_before": float(before["quality"]), "quality_after": float(after["quality"]), "target": str(res.get("target", ""))}
	var ev := Provenance.workshop(it, KIND[action], text, data)
	(r["steps"] as Array).append({"day": Game.day(), "action": action, "outcome": outcome, "event": ev})
	while (r["steps"] as Array).size() > 20:
		(r["steps"] as Array).pop_front()
	Game.grant_player_xp(Crafting.skill_for_station(str(p["station"])), int(XP[action]) if outcome != "fail" else int(float(XP[action]) * 0.5))
	ItemSpirit.speak(it, SPIRIT_CTX[action])
	Events.inventory_changed.emit()
	return {"ok": true, "text": text, "kind": KIND[action], "action": action, "outcome": outcome, "before": before, "after": after,
		"changes": changes, "event": ev, "summary": str(res.get("summary", ""))}


static func _scale_stats(it: Dictionary, f: float, df: float, cap: Dictionary) -> void:
	var st2: Dictionary = it.get("stats", {})
	for k in st2.keys():
		if k in ["durability", "durability_max"]:
			continue
		if st2[k] is float or st2[k] is int:
			var v := int(st2[k])
			if v > 0:
				st2[k] = _capped(str(k), maxi(v, int(round(float(v) * f))), v, cap)
	if st2.has("durability_max"):
		var dm := int(st2["durability_max"])
		var frac := clampf(float(st2.get("durability", dm)) / maxf(1.0, float(dm)), 0.0, 1.0)
		st2["durability_max"] = _capped("durability", maxi(dm, int(round(float(dm) * df))), dm, cap)
		st2["durability"] = int(round(frac * float(st2["durability_max"])))


static func _do_refine(it: Dictionary, q: float) -> Dictionary:
	var st2: Dictionary = it.get("stats", {})
	var q0 := float(it.get("quality", 70.0))
	if q < float(FAIL["refine"]):
		# the hand slipped: a little craftsmanship and some wear — recoverable by later work or a reforge
		var loss := clampf((50.0 - q) / 15.0, 1.0, 3.0)
		it["quality"] = maxf(1.0, q0 - loss)
		if st2.has("durability_max"):
			st2["durability"] = maxi(1, int(st2.get("durability", 0)) - int(round(float(st2["durability_max"]) * 0.08)))
		return {"outcome": "fail", "summary": "the hand slipped and the work went backwards a little"}
	if st2.has("durability_max"):
		var heal := 0.2 if q >= float(SUCCESS["refine"]) else 0.1
		st2["durability"] = mini(int(st2["durability_max"]), int(st2.get("durability", 0)) + int(round(float(st2["durability_max"]) * heal)))
	if q < float(SUCCESS["refine"]):
		return {"outcome": "partial", "summary": "the work did not take — a cleaner surface, nothing more"}
	var q1 := _gain_quality(it, "refine", q)
	it["quality"] = q1
	var cap := fresh_cap(it)
	var was := st2.duplicate()
	_scale_stats(it, _qf(q1) / _qf(q0), _qf(q1) / _qf(q0), cap)
	var nudged := 0
	if q >= 95.0:
		# fine work draws each existing stat up by at least one — never past a fresh piece of its kind
		for k in _stat_keys(it):
			st2[k] = _capped(k, maxi(int(st2[k]), int(was.get(k, 0)) + 1), int(was.get(k, 0)), cap)
		for a in it.get("affixes", []):
			var info := _affix_info(str(a.get("id", "")))
			if info.is_empty():
				continue
			var hi := int(info["hi"]) * (2 if str(it.get("rarity", "")) == "legendary" else 1)
			if int(a["value"]) < hi:
				a["value"] = int(a["value"]) + 1
				nudged += 1
	return {"outcome": "success", "summary": "honed and planished%s" % (", its virtues drawn out a little" if nudged > 0 else "")}


static func _do_rework(it: Dictionary, q: float, target: String, roll := 0) -> Dictionary:
	var t := _target(it, target)
	var tid := str(t.get("id", ""))
	var lo := int(t.get("lo", 0))
	var hi := int(t.get("hi", 0))
	var cur := int(t.get("value", 0))
	var nv := cur
	var outcome := "success"
	if q < float(FAIL["rework"]):
		nv = maxi(lo, cur - 1)
		outcome = "fail"
	else:
		var total := roll if roll > 0 else int(Crafting.roll_weighted("edge", "1d20", q)["total"])
		var n := clampf(float(total - 1) / 19.0, 0.0, 1.0)
		nv = lo + int(round(n * float(hi - lo)))
		if str(t.get("kind", "")) == "stat":
			nv = clampi(_stat_with_die(it, str(t["stat"]), n), lo, hi)
	if str(t.get("kind", "")) == "affix":
		var i := int(tid.get_slice(":", 1))
		(it["affixes"] as Array)[i]["value"] = nv
	else:
		it["stats"][str(t["stat"])] = nv
	var nm := str(t.get("label", "")).get_slice(" — ", 0)
	return {"outcome": outcome, "target": tid, "summary": ("the re-cut slipped on %s" % nm) if outcome == "fail" else "%s re-cut (legal range %d–%d)" % [nm, lo, hi]}


static func _do_upgrade(it: Dictionary, q: float) -> Dictionary:
	var from := material_of(it)
	var s: Dictionary = STEPS.get(from, {})
	var st2: Dictionary = it.get("stats", {})
	if q < float(SUCCESS["upgrade"]):
		if st2.has("durability_max"):
			st2["durability"] = maxi(1, int(st2.get("durability", 0)) - int(round(float(st2["durability_max"]) * 0.1)))
		if q < float(FAIL["upgrade"]):
			it["quality"] = maxf(1.0, float(it.get("quality", 70.0)) - 1.0)
			return {"outcome": "fail", "summary": "%s would not bond and was spoiled; the piece took some strain" % str(s.get("words", "the new material"))}
		return {"outcome": "partial", "summary": "%s would not bond; the material is spent" % str(s.get("words", "the new material"))}
	var mats: Dictionary = Crafting.cfg("materials")
	var a: Dictionary = mats.get(from, {"stat": 1.0, "durability": 1.0})
	var b: Dictionary = mats.get(str(s["to"]), {"stat": 1.0, "durability": 1.0})
	var f := float(b.get("stat", 1.0)) / maxf(0.01, float(a.get("stat", 1.0)))
	var df := float(b.get("durability", 1.0)) / maxf(0.01, float(a.get("durability", 1.0)))
	_scale_stats(it, f, df, fresh_cap(it, str(s["to"])))
	var r := rec(it)
	if not r.has("base_material"):
		r["base_material"] = from
	r["material"] = str(s["to"])
	return {"outcome": "success", "summary": "%s added — %s work now (was %s)" % [str(s["words"]), material_name(str(s["to"])), material_name(from)]}


static func _do_reforge(it: Dictionary, q: float) -> Dictionary:
	var q0 := float(it.get("quality", 70.0))
	var q1 := _gain_quality(it, "reforge", q)
	var st2: Dictionary = it.get("stats", {})
	var f := _qf(q1) / _qf(q0)
	_scale_stats(it, f, f, fresh_cap(it))
	if st2.has("durability_max"):
		st2["durability"] = int(st2["durability_max"])
	it.erase("broken")
	it["quality"] = q1
	if q1 - q0 >= 0.5:
		return {"outcome": "success", "summary": "made whole again"}
	return {"outcome": "success", "summary": "made whole again; the rework could not better the original %d%%" % int(round(q0))}


# ======================================================================= records
## A comparable picture of a piece: quality, every stat, affixes, material and the old service fields.
static func snapshot(it: Dictionary) -> Dictionary:
	var st2: Dictionary = it.get("stats", {})
	return {"quality": float(it.get("quality", 0.0)), "stats": st2.duplicate(true), "affixes": (it.get("affixes", []) as Array).duplicate(true),
		"attack": Items.stat(it, "attack"), "protection": Items.stat(it, "protection"), "durability": int(st2.get("durability", 0)),
		"durability_max": int(st2.get("durability_max", 0)), "broken": bool(it.get("broken", false)), "material": material_of(it),
		"rarity": str(it.get("rarity", "common")), "name": str(it.get("name", ""))}


## Every difference between two snapshots: [{stat, from, to}] (quality, stats, affixes as "affix:<id>").
static func diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	if absf(float(b["quality"]) - float(a["quality"])) >= 0.5:
		out.append({"stat": "craftsmanship", "from": int(round(float(a["quality"]))), "to": int(round(float(b["quality"])))})
	var sa: Dictionary = a["stats"]
	var sb: Dictionary = b["stats"]
	for k in sb:
		if int(sa.get(k, 0)) != int(sb[k]):
			out.append({"stat": str(k), "from": int(sa.get(k, 0)), "to": int(sb[k])})
	var aa: Array = a["affixes"]
	var ab: Array = b["affixes"]
	for i in mini(aa.size(), ab.size()):
		if int(aa[i].get("value", 0)) != int(ab[i].get("value", 0)):
			out.append({"stat": "%s (%s)" % [str(ab[i].get("stat", "")), str(ab[i].get("id", ""))], "from": int(aa[i]["value"]), "to": int(ab[i]["value"])})
	if str(a["material"]) != str(b["material"]):
		out.append({"stat": "material", "from": material_name(str(a["material"])), "to": material_name(str(b["material"]))})
	return out


static func change_text(changes: Array) -> String:
	var parts := PackedStringArray()
	for c in changes:
		if str(c["stat"]) == "durability":
			continue   # wear is shown on the card, not in the history line
		var pct := "%" if str(c["stat"]) == "craftsmanship" else ""
		parts.append("%s %s%s → %s%s" % [str(c["stat"]).replace("_", " "), str(c["from"]), pct, str(c["to"]), pct])
	var s := "; ".join(parts)
	return s.left(1).to_upper() + s.substr(1)


## One line for the item tooltip: what has been done to it, and what is left.
static func tooltip_line(it: Dictionary) -> String:
	var r: Dictionary = it.get("refine", {})
	if r.is_empty():
		return ""
	var bits := PackedStringArray()
	for a in ["refine", "rework", "upgrade"]:
		var n := int(r.get(KIND[a], 0))
		if n > 0:
			bits.append("%s %d/%d" % [KIND[a], n, int(LIMIT[a])])
	if str(r.get("material", "")) != "":
		bits.append("%s work (was %s)" % [material_name(str(r["material"])), material_name(str(r.get("base_material", "")))])
	if bits.is_empty():
		return ""
	return "[color=#c8b898][i]Improved at the forge: %s[/i][/color]" % ", ".join(bits)


## The station screens: what can be done at this station ([[action, short label]]).
static func actions_at(station_id: String) -> Array:
	var out := []
	match station_id:
		"anvil": out = ["reforge", "upgrade", "rework"]
		"grinding_wheel": out = ["refine"]
		"rune_engraving_stand": out = ["rework"]
		"stitching_table": out = ["refine", "rework", "upgrade"]
		"tailors_bench", "arcane_anvil": out = ["upgrade"]
	return out
