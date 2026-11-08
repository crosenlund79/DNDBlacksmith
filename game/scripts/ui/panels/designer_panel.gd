## DesignerPanel — plan a piece of equipment from what the smith knows.
## EN: Choose an item type (sword, mace, cuirass, boots, ring…), a material variant (the recipes that make
##     that type), an optional runestone to set and an optional oil, coating or infusion. The panel shows
##     the expected statistics (a range: craftsmanship, dice and skill still decide), the techniques that
##     will help, and a ✓/✗ checklist of everything the plan needs: skill-tree knowledge, the recipe,
##     stations, skills and materials. "Begin crafting" starts the base recipe; the plan is remembered
##     (Game.state["design_plan"]) and when the piece exists the panel offers to set the rune and apply
##     the treatment. Open with Events.open_panel.emit("designer", {}) or from any station panel.
## DA: Planlæg udstyr ud fra smedens viden: type, materiale, runesten og behandling, med forventede
##     værdier og en tjekliste over krav. Planen huskes, så rune og behandling kan påføres bagefter.
class_name DesignerPanel
extends UIWindow

const GROUPS := [
	["Weapons", ["sword", "axe", "mace", "bow", "dagger", "weapon"]],
	["Armour", ["body", "helmet", "shield", "gloves", "boots", "belt"]],
	["Jewellery", ["ring", "amulet"]],
]
const TYPE_NAME := {"sword": "Sword", "axe": "Axe", "mace": "Mace", "bow": "Bow", "dagger": "Dagger", "weapon": "Other weapon",
	"body": "Body armour", "helmet": "Helm & hood", "shield": "Shield", "gloves": "Gloves", "boots": "Boots", "belt": "Belt",
	"ring": "Ring", "amulet": "Amulet"}

static var type_key := ""
static var recipe_id := ""
static var rune := ""
static var coat := ""

var types_box: VBoxContainer
var mid: VBoxContainer
var right: VBoxContainer
var plan_box: VBoxContainer


func _init(_args := {}) -> void:
	super._init("Equipment Designer", 1560, 900)


func _ready() -> void:
	super._ready()
	title_label.text = "✦ Equipment Designer ✦"
	plan_box = UIKit.vbox(6)
	content.add_child(plan_box)
	var h := UIKit.hbox(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(h)
	types_box = UIKit.vbox(4)
	var ts := UIKit.scroll(types_box, 700)
	ts.custom_minimum_size = Vector2(290, 700)
	h.add_child(ts)
	mid = UIKit.vbox(8)
	var ms := UIKit.scroll(mid, 700)
	ms.custom_minimum_size = Vector2(560, 700)
	h.add_child(ms)
	right = UIKit.vbox(6)
	var rs := UIKit.scroll(right, 700)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rs)
	Events.inventory_changed.connect(_rebuild)
	Events.crafting_changed.connect(_rebuild)
	if type_key == "" or by_type(type_key).is_empty():
		type_key = "sword"
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build_plan()
	_build_types()
	_build_mid()
	_build_right()


# ------------------------------------------------------------------ data helpers
static func type_of(r: Dictionary) -> String:
	var out := str(r.get("output", ""))
	var d := DB.item(out)
	var slot: Variant = d.get("slot")
	if not slot is String or str(slot) == "":
		return ""
	match str(slot):
		"weapon":
			var w := Items.wtype({"def": out})
			return w if TYPE_NAME.has(w) else "weapon"
		"armor":
			return "body"
	return str(slot)


static func by_type(key: String) -> Array:
	return DB.recipes.values().filter(func(r): return type_of(r) == key and SkillTree.recipe_visible(str(r["id"])))


static func rune_options() -> Array:
	var out := []
	for d in DB.items.values():
		if str(d.get("type", "")) != "runestone" or d["id"] == "runestone_blank":
			continue
		var have := Game.count(str(d["id"]))
		var known := DB.recipes.values().any(func(r): return r["output"] == d["id"] and SkillTree.recipe_known(str(r["id"])))
		if have > 0 or known:
			out.append({"id": d["id"], "name": d["name"], "have": have, "known": known})
	return out


static func coat_options() -> Array:
	var out := []
	for id in Crafting.TREATMENTS:
		var d := DB.item(str(id))
		if d.is_empty():
			continue
		var have := Game.count(str(id))
		var known := DB.recipes.values().any(func(r): return r["output"] == id and SkillTree.recipe_known(str(r["id"])))
		if have > 0 or known:
			out.append({"id": id, "name": d["name"], "have": have, "known": known})
	return out


## Expected statistics range for a recipe (rough work with poor dice → masterful work with great dice),
## plus the rune and treatment chosen.
static func preview(rid: String, rune_def := "", coat_def := "") -> Dictionary:
	var r := DB.recipe(rid)
	var d := DB.item(str(r.get("output", "")))
	var spec: Dictionary = r.get("dice", {})
	var lo_d := {}
	var hi_d := {}
	for k in spec:
		lo_d[k] = 1
		hi_d[k] = Dice.sides(str(spec[k]))
	var mat := Crafting.material(rid)
	var lvl := Game.player_level(Crafting.recipe_skill(rid))
	var lo := Crafting.compute_stats(d, 60.0, lo_d, spec, mat, lvl)
	var hi := Crafting.compute_stats(d, 115.0, hi_d, spec, mat, lvl)
	var out := {}
	for k in lo:
		if k == "durability_max":
			continue
		out[k] = [int(lo[k]), int(hi[k])]
	if str(r.get("discipline", "")) == "arcane":
		var bstat := "ward" if str(d.get("slot", "")) in ["armor", "shield", "helmet"] else "magic"
		var a: Array = out.get(bstat, [0, 0])
		out[bstat] = [int(a[0]) + 3, int(a[1]) + 9]
	if rune_def != "":
		var rs: Dictionary = DB.item(rune_def).get("stats", {})
		for k in rs:
			var a2: Array = out.get(k, [0, 0])
			out[k] = [int(a2[0]) + int(round(float(rs[k]) * 0.96)), int(a2[1]) + int(round(float(rs[k]) * 1.29))]
	if coat_def != "" and Crafting.TREATMENTS.has(coat_def):
		var t: Array = Crafting.TREATMENTS[coat_def]
		var cs: Dictionary = DB.item(coat_def).get("stats", {})
		var base := float(cs.get(t[0], cs.get("edge", 2)))
		var v := maxf(2.0, base * 2.0)
		var a3: Array = out.get(str(t[0]) + "*", [0, 0])
		out[str(t[0]) + "*"] = [int(a3[0]) + int(round(v * 1.05)), int(a3[1]) + int(round(v * 1.25))]
	return out


## Every requirement of the plan: {"ok", "text", "group"}.
static func checklist(rid: String, rune_def := "", coat_def := "") -> Array:
	var r := DB.recipe(rid)
	var out := []
	var ni := SkillTree.recipe_node(rid)
	if ni != "":
		var n := SkillTree.node(ni)
		out.append({"group": "Knowledge", "ok": SkillTree.is_unlocked(ni), "text": "Skill tree: %s (%s)" % [n.get("name", ni), SkillTree.branch(str(n.get("branch", ""))).get("name", "")]})
	out.append({"group": "Knowledge", "ok": SkillTree.recipe_known(rid), "text": "Recipe known: " + str(r.get("name", rid))})
	var seen := {}
	for s in r.get("steps", []):
		if seen.has(s):
			continue
		seen[s] = true
		var why := Crafting.station_locked_reason(str(s))
		out.append({"group": "Stations", "ok": why == "", "text": str(DB.station(str(s)).get("name", s)) + ("" if why == "" else " — " + why)})
	var req: Dictionary = r.get("requires", {})
	for sk in req:
		out.append({"group": "Skills", "ok": Game.player_level(str(sk)) >= int(req[sk]), "text": "%s %d (you: %d)" % [SkillSys.skill_name(str(sk)), int(req[sk]), Game.player_level(str(sk))]})
	var rf := str(r.get("requires_flag", ""))
	if rf != "":
		out.append({"group": "Knowledge", "ok": Game.has_flag(rf), "text": "Knowledge: " + str(SkillTree.flag_info(rf).get("name", rf))})
	for id in r.get("inputs", {}):
		var need := int(r["inputs"][id])
		var have := Game.count(str(id))
		out.append({"group": "Materials", "ok": have >= need, "text": "%s %d/%d" % [DB.item(str(id)).get("name", id), have, need]})
	if rune_def != "":
		out.append({"group": "Finishing", "ok": Game.count(rune_def) > 0, "text": "%s to set (have %d)" % [DB.item(rune_def).get("name", rune_def), Game.count(rune_def)]})
		var w2 := Crafting.station_locked_reason("rune_engraving_stand")
		out.append({"group": "Finishing", "ok": w2 == "", "text": "Rune Engraving Stand" + ("" if w2 == "" else " — " + w2)})
	if coat_def != "":
		out.append({"group": "Finishing", "ok": Game.count(coat_def) > 0, "text": "%s to apply (have %d)" % [DB.item(coat_def).get("name", coat_def), Game.count(coat_def)]})
		var w3 := Crafting.station_locked_reason("infusion_rack")
		out.append({"group": "Finishing", "ok": w3 == "", "text": "Infusion Rack" + ("" if w3 == "" else " — " + w3)})
	return out


# ------------------------------------------------------------------ the pending plan
static func plan() -> Dictionary:
	return Game.state.get("design_plan", {})


## The finished piece of the remembered plan, if it exists yet.
static func plan_item() -> Dictionary:
	var p := plan()
	if p.is_empty():
		return {}
	for it in Game.inventory():
		if it["def"] == p.get("output", "") and int(it.get("uid", 0)) > int(p.get("after_uid", 0)) and it.has("craft"):
			return it
	return {}


func _build_plan() -> void:
	UIKit.clear(plan_box)
	var p := plan()
	if p.is_empty():
		return
	var it := plan_item()
	var h := UIKit.hbox(12)
	var r := DB.recipe(str(p.get("recipe", "")))
	if it.is_empty():
		if Crafting.active() and Crafting.job().get("recipe", "") == p.get("recipe", ""):
			var nxt := "roll the dice" if Crafting.job().get("awaiting_dice", false) else "%s at the %s" % [Crafting.current_op().get("op", ""), DB.station(Crafting.current_station()).get("name", "")]
			h.add_child(UIKit.rich("[b]Your plan is on the anvil:[/b] %s — next: %s." % [r.get("name", ""), nxt], 20))
		else:
			h.add_child(UIKit.rich("[b]Remembered plan:[/b] %s%s%s — not begun or not finished." % [r.get("name", ""), _with(" with ", str(p.get("rune", ""))), _with(", treated with ", str(p.get("coat", "")))], 20))
	else:
		h.add_child(UIKit.rich("[b]Your %s is finished.[/b] Complete the plan:" % Items.display_name(it), 20))
		var uid := int(it["uid"])
		if str(p.get("rune", "")) != "" and not p.get("rune_done", false):
			var b := UIKit.button("Set the %s" % DB.item(str(p["rune"])).get("name", ""), func(): _apply_rune(uid), 0)
			b.disabled = Game.count(str(p["rune"])) < 1 or Crafting.station_locked_reason("rune_engraving_stand") != ""
			h.add_child(b)
		if str(p.get("coat", "")) != "" and not p.get("coat_done", false):
			var b2 := UIKit.button("Apply the %s" % DB.item(str(p["coat"])).get("name", ""), func(): _apply_coat(uid), 0)
			b2.disabled = Game.count(str(p["coat"])) < 1 or Crafting.station_locked_reason("infusion_rack") != ""
			h.add_child(b2)
	h.add_child(UIKit.button("Forget plan", func(): Game.state.erase("design_plan"); _rebuild(), 160))
	plan_box.add_child(h)
	plan_box.add_child(UIKit.divider())


func _with(prefix: String, def_id: String) -> String:
	return "" if def_id == "" else prefix + str(DB.item(def_id).get("name", def_id))


func _apply_rune(uid: int) -> void:
	var p := plan()
	var q := minf(115.0, 70.0 + 4.0 * Game.player_level("runecraft"))
	if Crafting.socket(uid, str(p["rune"]), q):
		p["rune_done"] = true
		Audio.play("sfx/rune_hum")
		Events.toast.emit("The rune settles into the metal with a hum.", "good")
	else:
		Events.toast.emit("The rune will not take — the piece may have no free socket.", "bad")
	_finish_plan_if_done()


func _apply_coat(uid: int) -> void:
	var p := plan()
	var msg := Crafting.treat(uid, str(p["coat"]))
	p["coat_done"] = msg.begins_with("The")
	Events.toast.emit(msg, "good" if p["coat_done"] else "bad")
	_finish_plan_if_done()


func _finish_plan_if_done() -> void:
	var p := plan()
	if (str(p.get("rune", "")) == "" or p.get("rune_done", false)) and (str(p.get("coat", "")) == "" or p.get("coat_done", false)):
		Game.state.erase("design_plan")
		Events.toast.emit("Design complete.", "good")
	_rebuild()


# ------------------------------------------------------------------ columns
func _build_types() -> void:
	UIKit.clear(types_box)
	types_box.add_child(UIKit.label("1. Item type", 24, "heading", UIKit.RUBRIC))
	for g in GROUPS:
		var keys: Array = (g[1] as Array).filter(func(k): return not by_type(str(k)).is_empty())
		if keys.is_empty():
			continue
		types_box.add_child(UIKit.label(str(g[0]), 20, "heading_italic"))
		for k in keys:
			var key := str(k)
			var rs := by_type(key)
			var known := rs.filter(func(r): return SkillTree.recipe_known(str(r["id"]))).size()
			var b := UIKit.button("%s  (%d/%d known)" % [TYPE_NAME.get(key, key.capitalize()), known, rs.size()], func(): _pick_type(key), 270)
			b.disabled = key == type_key
			b.add_theme_font_size_override("font_size", 18)
			types_box.add_child(b)


func _pick_type(key: String) -> void:
	type_key = key
	recipe_id = ""
	_rebuild()


func _build_mid() -> void:
	UIKit.clear(mid)
	var rs := by_type(type_key)
	if rs.is_empty():
		return
	if recipe_id == "" or not rs.any(func(r): return r["id"] == recipe_id):
		var known := rs.filter(func(r): return SkillTree.recipe_known(str(r["id"])))
		recipe_id = str((known[0] if not known.is_empty() else rs[0])["id"])
	mid.add_child(UIKit.label("2. Material & recipe", 24, "heading", UIKit.RUBRIC))
	for r in rs:
		var rid := str(r["id"])
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon("icons/" + str(DB.item(str(r["output"])).get("icon", r["output"])), 52))
		var known := SkillTree.recipe_known(rid)
		var b := UIKit.button(("%s — %s" % [Crafting.material(rid).get("name", ""), r["name"]]) + ("" if known else "  🔒"), func(): recipe_id = rid; _rebuild(), 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = rid == recipe_id
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not known:
			b.tooltip_text = SkillTree.recipe_reason(rid)
		row.add_child(b)
		mid.add_child(row)
	mid.add_child(UIKit.divider())
	mid.add_child(UIKit.label("3. Runestone socket (optional)", 24, "heading", UIKit.RUBRIC))
	var ro := rune_options()
	if rune != "" and not ro.any(func(o): return o["id"] == rune):
		rune = ""
	mid.add_child(_option_row(ro, rune, func(v: String): rune = v; _rebuild(), "No rune — you have none and know none yet."))
	mid.add_child(UIKit.label("4. Alchemical treatment (optional)", 24, "heading", UIKit.RUBRIC))
	var co := coat_options()
	if coat != "" and not co.any(func(o): return o["id"] == coat):
		coat = ""
	mid.add_child(_option_row(co, coat, func(v: String): coat = v; _rebuild(), "No oils or coatings — learn Basic Weapon Oils in the skill tree."))
	mid.add_child(UIKit.label("5. Techniques & enhancement", 24, "heading", UIKit.RUBRIC))
	var techs := SkillTree.techniques_for(recipe_id)
	var lines := []
	for t in techs:
		lines.append("✦ [b]%s[/b] — %s" % [t["name"], t["desc"]])
	if DB.recipe(recipe_id).get("discipline", "") == "arcane":
		lines.append("✦ [b]Bound magic[/b] — arcane metalwork binds a ward or magic into the metal itself.")
	if techs.is_empty() and lines.is_empty():
		lines.append("[i]No technique of yours applies to this piece yet — the skill tree teaches several.[/i]")
	mid.add_child(UIKit.rich("\n".join(lines), 18))


func _option_row(opts: Array, current: String, cb: Callable, empty_text: String) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	var none := UIKit.button("None", func(): cb.call(""), 0)
	none.disabled = current == ""
	none.add_theme_font_size_override("font_size", 17)
	flow.add_child(none)
	if opts.is_empty():
		var l := UIKit.label(empty_text, 17, "body_italic")
		flow.add_child(l)
	for o in opts:
		var id := str(o["id"])
		var txt := "%s (have %d)" % [o["name"], int(o["have"])] if int(o["have"]) > 0 else "%s (known)" % o["name"]
		var b := UIKit.button(txt, func(): cb.call(id), 0)
		b.disabled = current == id
		b.add_theme_font_size_override("font_size", 17)
		b.icon = Assets.get_tex("icons/" + str(DB.item(id).get("icon", id)))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 44)
		flow.add_child(b)
	return flow


func _build_right() -> void:
	UIKit.clear(right)
	if recipe_id == "":
		return
	var r := DB.recipe(recipe_id)
	var d := DB.item(str(r["output"]))
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon("icons/" + str(d.get("icon", r["output"])), 96))
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UIKit.label("%s%s" % [d.get("name", ""), (" + " + str(DB.item(rune).get("name", ""))) if rune != "" else ""], 26, "title")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(tl)
	hv.add_child(UIKit.rich("[i]%s · %s · difficulty %d (%s)[/i]" % [Crafting.DISCIPLINE_NAME.get(r.get("discipline", ""), ""), Crafting.material(recipe_id).get("name", ""),
		Crafting.difficulty(recipe_id), Crafting.difficulty_word(recipe_id)], 18))
	head.add_child(hv)
	right.add_child(head)
	# expected statistics
	right.add_child(UIKit.label("Expected statistics", 22, "heading", UIKit.RUBRIC))
	var pv := preview(recipe_id, rune, coat)
	var parts := []
	for k in pv:
		var a: Array = pv[k]
		var nm := str(k).replace("*", "")
		var label := nm.capitalize() + (" (treatment, 3 expeditions)" if str(k).ends_with("*") else "")
		parts.append("[b]%s[/b] %s" % [label, ("%d" % int(a[0])) if int(a[0]) == int(a[1]) else "%d–%d" % [int(a[0]), int(a[1])]])
	right.add_child(UIKit.rich("  ·  ".join(parts), 19))
	var tb := SkillTree.quality_bonus(recipe_id)
	right.add_child(UIKit.rich("[i][color=#5e421c]A range, not a promise: your craftsmanship at each station, the dice and your %s (%d) decide the real piece. Skill adds +%.1f%% craftsmanship%s.[/color][/i]" % [
		SkillSys.skill_name(Crafting.recipe_skill(recipe_id)), Game.player_level(Crafting.recipe_skill(recipe_id)),
		Crafting.skill_bonus(recipe_id) - tb, (", techniques +%.0f%%" % tb) if tb > 0.0 else ""], 17))
	# requirements
	right.add_child(UIKit.label("Requirements", 22, "heading", UIKit.RUBRIC))
	var cl := checklist(recipe_id, rune, coat)
	var lines := []
	var group := ""
	var missing := []
	for q in cl:
		if q["group"] != group:
			group = q["group"]
			lines.append("[b]%s[/b]" % group)
		lines.append("   [color=%s]%s %s[/color]" % ["#26622f" if q["ok"] else "#9e3a0c", "✓" if q["ok"] else "✗", q["text"]])
		if not q["ok"]:
			missing.append(str(q["text"]))
	right.add_child(UIKit.rich("\n".join(lines), 18))
	if not missing.is_empty():
		right.add_child(UIKit.rich("[color=#9e3a0c][b]Missing:[/b] %s[/color]" % "; ".join(missing), 18))
	var ok := missing.is_empty()
	var b := UIKit.button("Begin crafting" if ok else "Begin crafting — requirements missing", _begin, 0)
	b.disabled = not ok or Crafting.active()
	if Crafting.active():
		b.text = "Finish the work on the anvil first"
	right.add_child(b)


func _begin() -> void:
	var after := int(Game.state.get("next_uid", 0))
	if not Crafting.start(recipe_id):
		Events.toast.emit("The work cannot begin — check the requirements.", "bad")
		return
	Game.state["design_plan"] = {"recipe": recipe_id, "output": DB.recipe(recipe_id)["output"], "rune": rune, "coat": coat, "after_uid": after, "day": Game.day()}
	Events.toast.emit("Begun: %s. First: %s at the %s.%s" % [DB.recipe(recipe_id)["name"], Crafting.current_op().get("op", ""), DB.station(Crafting.current_station()).get("name", ""),
		" Return to the designer when it is finished to complete the plan." if rune != "" or coat != "" else ""], "info")
	close()
