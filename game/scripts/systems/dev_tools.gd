## DevTools — the developer catalogue behind F10: search every item definition, spawn items into the stores
## with quantity / rarity / craftsmanship, and add money. Testing only.
## EN: Every spawned item is marked it["dev"] = true (stacks too; dev stacks never merge with real ones).
##     Spawned equipment gets a real uid and provenance: maker "Developer tools", no mark, owner the smith —
##     and never counts for anything earned: Hall of Fame / Epic / names (Recognition, ItemStory), objectives,
##     the skill tree's "items seen" and knowledge flags, the encyclopedia, apprentices' fame.
##     Money is logged in the ledger as "Developer tools" (category "dev", left out of the accounts).
##     S2 — cheats are a SESSION switch: OFF when the game starts, never written to a save, switched off again by a new
##     game or a load (Game.new_game / Game.from_save call end_session). While they are off nothing here spawns, pays or
##     bypasses anything, and the F10 tools are locked. Switching them on shows a "CHEATS ON" banner over the game and
##     marks the running game (state "dev_used": {first_day, last_day, times}) so a save made since says so. The
##     optional skill-check bypass (every check scores BYPASS_QUALITY without the minigame) works only while cheats are
##     on and is caught where a check starts (UIRoot's "skillcheck" route calls run_check).
## DA: Udviklerkatalog (F10): søg alle genstande, læg dem i lageret, tilføj penge — kun til test. Snyd er en
##     sessionskontakt: slået fra ved start, gemmes aldrig, vises med et "CHEATS ON"-banner.
class_name DevTools
extends RefCounted

const MAKER_ID := "dev"
const MAKER_NAME := "Developer tools"
const MONEY_PRESETS := [100, 1000, 10000]
## Type filter: [label, [def types]] ([] = all).
const FILTERS := [
	["All items", []], ["Weapons", ["weapon"]], ["Armour & shields", ["armor_metal", "armor_leather", "armor_cloth", "shield", "helmet", "cloak"]],
	["Hands, feet & belts", ["gloves", "boots", "belt"]], ["Rings & amulets", ["ring", "amulet"]], ["Materials", ["material"]],
	["Alchemy", ["potion"]], ["Runestones", ["runestone"]], ["Relics & curios", ["relic", "curio", "container"]], ["Companions", ["companion"]],
]
const RARITY_CHOICES := ["common", "magic", "rare", "legendary"]
## What a bypassed skill check scores (a clean strike at the centre of the zone).
const BYPASS_QUALITY := 100.0
const INDICATOR_NAME := "DevCheatsIndicator"

## The session switches (never saved).
static var _on := false
static var _bypass := false
static var _indicator: CanvasLayer = null


# ------------------------------------------------------------------ the cheat switch (S2)
static func enabled() -> bool:
	return _on


## Switches developer cheats on or off for this session. On: the banner shows and the running game is marked.
static func set_enabled(on: bool) -> void:
	if on == _on:
		_update_indicator()
		return
	_on = on
	if not on:
		_bypass = false
		set_sim_pace(1.0, true)   # #76: cheats off returns the simulation to normal speed
	elif not Game.state.is_empty():
		mark_game()
	_update_indicator()
	Events.toast.emit("Developer cheats ON for this session — a save made now is marked as tested with cheats." if on
		else "Developer cheats OFF.", "info")


## The optional skill-check bypass: only while cheats are on.
static func bypass_checks() -> bool:
	return _on and _bypass


static func set_bypass(on: bool) -> void:
	_bypass = on and _on
	_update_indicator()


## A new game or a loaded save starts with cheats off (Game.new_game / Game.from_save).
static func end_session() -> void:
	_on = false
	_bypass = false
	set_sim_pace(1.0, true)
	_update_indicator()


## Marks the running game as touched by developer cheats (kept in its saves; created when first needed).
static func mark_game() -> void:
	var m: Dictionary = Game.state.get("dev_used", {})
	if m.is_empty():
		m = {"first_day": Game.day(), "times": 0}
	m["last_day"] = Game.day()
	m["times"] = int(m.get("times", 0)) + 1
	Game.state["dev_used"] = m


## Was this game (or a save's state) ever played with developer cheats on?
static func used_in(state: Dictionary) -> bool:
	return not (state.get("dev_used", {}) as Dictionary).is_empty()


static func indicator_text() -> String:
	return "CHEATS ON" + (" · skill checks bypassed" if _bypass else "") + (" · pace ×%d" % int(_pace) if _pace > 1.0 else "") + " · F10"


## Is the "CHEATS ON" banner showing?
static func indicator_visible() -> bool:
	return is_instance_valid(_indicator) and _indicator.visible


static func _update_indicator() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not is_instance_valid(_indicator):
		if not _on:
			return
		_indicator = CanvasLayer.new()
		_indicator.name = INDICATOR_NAME
		_indicator.layer = 120
		var box := PanelContainer.new()
		box.name = "Box"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.08, 0.06, 0.92)
		sb.border_color = Color("#ffd27a")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.offset_top = 6
		box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var l := Label.new()
		l.name = "Text"
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color("#fff3d6"))
		box.add_child(l)
		_indicator.add_child(box)
		tree.root.add_child.call_deferred(_indicator)
	_indicator.visible = _on
	var lab := _indicator.get_node_or_null("Box/Text") as Label
	if lab:
		lab.text = indicator_text()


## Where a skill check starts (UIRoot, route "skillcheck"): with the bypass on, the check is not played — its callback
## gets BYPASS_QUALITY for every round at once. Returns true when it bypassed the check.
static func run_check(args: Dictionary) -> bool:
	if not bypass_checks():
		return false
	var qs := bypass_scores(args)
	var cb: Callable = args.get("on_done", Callable())
	Events.toast.emit("Developer bypass: %s — %d%% without the check." % [str(args.get("title", "skill check")), int(BYPASS_QUALITY)], "info")
	if cb.is_valid():
		cb.call_deferred(qs)
	return true


## The results a bypassed check hands its callback: BYPASS_QUALITY for each of its rounds.
static func bypass_scores(args: Dictionary) -> Array:
	var qs := []
	for i in maxi(1, int(args.get("count", 1))):
		qs.append(BYPASS_QUALITY)
	return qs


static func _refuse() -> bool:
	if _on:
		return false
	Events.toast.emit("Developer cheats are off — switch them on in the F10 tools first.", "bad")
	return true


static func is_dev(it: Dictionary) -> bool:
	return bool(it.get("dev", false))


## Item definitions matching a query (name, id or type; "" = all) and a type filter index, sorted by name.
static func search(query: String, filter := 0) -> Array:
	var q := query.strip_edges().to_lower()
	var types: Array = FILTERS[clampi(filter, 0, FILTERS.size() - 1)][1]
	var out := []
	for d in DB.items.values():
		var t := str(d.get("type", ""))
		if not types.is_empty() and not types.has(t):
			continue
		if q != "" and not (str(d["id"]).to_lower().contains(q) or str(d.get("name", "")).to_lower().contains(q) or t.contains(q)
				or Items.type_label({"def": str(d["id"])}).to_lower().contains(q)):
			continue
		out.append(d)
	out.sort_custom(func(a, b): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return out


static func is_equipment_def(def_id: String) -> bool:
	return Items.is_equipment({"def": def_id})


## Does this definition take a craftsmanship (equipment, potions, runestones)?
static func has_quality(def_id: String) -> bool:
	return is_equipment_def(def_id) or str(DB.item(def_id).get("type", "")) in ["potion", "runestone"]


## Spawns `qty` of an item into the smith's stores. rarity: "" = common (unique/set pieces keep their own);
## quality < 0 = 90%. Returns the spawned instances (one per piece; one stack for stackables).
static func spawn(def_id: String, qty := 1, rarity := "", quality := -1.0) -> Array:
	var d := DB.item(def_id)
	if d.is_empty() or qty <= 0 or _refuse():
		return []
	var q := quality if quality >= 0.0 else 90.0
	var out := []
	var opts := {"quality": q, "crafted_by": MAKER_NAME}
	if is_equipment_def(def_id) and rarity in RARITY_CHOICES:
		opts["rarity"] = rarity
	if bool(d.get("stack", false)):
		opts["qty"] = qty
		var st := Items.make(def_id, opts)
		st["dev"] = true
		Game.add_item(st, false)
		out.append(st)
	else:
		for i in qty:
			var it := Items.make(def_id, opts)
			if it.is_empty():
				continue
			it["dev"] = true
			if Items.is_equipment(it):
				Provenance.set_maker(it, MAKER_ID, MAKER_NAME, "unknown", "the developer tools")
				Provenance.transfer(it, Provenance.SMITH_ID, "received", "", "%s was spawned by the developer tools." % Items.display_name(it))
			Game.add_item(it, false)
			out.append(it)
	Events.inventory_changed.emit()
	if not out.is_empty():
		Events.toast.emit("Developer tools: %s ×%d added to your stores." % [str(d.get("name", def_id)), qty], "info")
	return out


## Adds (or, negative, removes) money; logged in the ledger as "Developer tools".
static func add_money(amount: int) -> void:
	if amount == 0 or _refuse():
		return
	Game.add_gold(amount, "dev", MAKER_NAME, "dev")
	Events.toast.emit("Developer tools: %+d gold (now %d g)." % [amount, Game.gold()], "info")


# ------------------------------------------------------------------ #75–76: a chosen skill, the simulation's pace
## Raises (or, negative, lowers) one of the smith's skills by `levels`, through the same level record and signal as the
## per-skill +/− buttons (clamped to the skill curve's maximum). Developer-only: the smith's normal limits are bypassed
## knowingly, and only while cheats are on. Returns the new level (-1 when refused).
static func raise_skill(skill: String, levels: int) -> int:
	if _refuse() or Game.state.is_empty() or levels == 0:
		return -1
	var sset: Dictionary = Game.state["player"]["skills"]
	if not sset.has(skill):
		sset[skill] = {"lvl": 0, "xp": 0}
	var lvl := clampi(int(sset[skill]["lvl"]) + levels, 0, int(DB.skill_curve.get("max_level", 20)))
	sset[skill]["lvl"] = lvl
	sset[skill]["xp"] = 0
	Events.skill_level_up.emit("player", skill, lvl)
	Events.toast.emit("Developer tools: %s is now level %d." % [skill, lvl], "info")
	return lvl


## Developer simulation speeds: the whole engine (Engine.time_scale — the clock, walking, work, travel, timers and
## animations together, exactly as the steward's pace does), never one part on its own.
const SIM_PACES := [1.0, 2.0, 4.0, 8.0, 16.0]
static var _pace := 1.0
static var _phys_steps := 0


static func sim_pace() -> float:
	return _pace


## Sets the developer pace (1 = normal). Only while cheats are on and the steward is not running the forge (the
## steward keeps its own pace). Physics may take several steps a frame so movement keeps up with the clock.
static func set_sim_pace(p: float, quiet := false) -> bool:
	if p > 1.0 and (_refuse() or Steward.is_active()):
		if Steward.is_active() and _on:
			Events.toast.emit("The steward keeps its own pace — leave Steward Mode first.", "bad")
		return false
	var want := p if SIM_PACES.has(p) else 1.0
	if want == _pace:
		return true
	if _pace == 1.0 and want > 1.0:
		_phys_steps = Engine.max_physics_steps_per_frame
	_pace = want
	Engine.time_scale = want
	if want > 1.0:
		Engine.max_physics_steps_per_frame = maxi(_phys_steps, int(ceil(want)) + 2)
	elif _phys_steps > 0:
		Engine.max_physics_steps_per_frame = _phys_steps
		_phys_steps = 0
	if not quiet:
		Events.toast.emit("Developer pace: ×%d%s" % [int(want), " — normal speed" if want == 1.0 else ""], "info")
	_update_indicator()
	return true

