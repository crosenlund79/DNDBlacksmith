## StationPanel — the interface of a crafting station: purpose, recipes, current job step,
## runestone setting (engraving stand) and practice checks.
## DA: Et håndværksstations brugerflade: formål, opskrifter, aktuelt trin, isætning af runesten
##     og øvelsesprøver.
class_name StationPanel
extends UIWindow

## Recipe categories shown as chips (a recipe can belong to several: a leather boot is armour and leather).
const CATS := [["all", "All"], ["weapons", "Weapons"], ["armour", "Armour"], ["jewellery", "Jewellery"], ["materials", "Materials"],
	["alchemy", "Alchemy"], ["runes", "Runes"], ["leather", "Leather"], ["arcane", "Arcane"]]
const AVAIL := [["all", "All recipes"], ["craftable", "Craftable now"], ["missing", "Known — missing materials"], ["locked", "Locked"]]

var station_id := ""
## Remembered between openings of any station panel.
static var query := ""
static var cat := "all"
static var avail := "all"
static var everywhere := false
## The recipe whose guidance is unfolded under its row ("" = none).
static var selected := ""
var list_box: VBoxContainer
var chips_row: HBoxContainer
var count_label: Label


func _init(id: String) -> void:
	station_id = id
	var st := DB.station(id)
	super._init(st.get("name", id), 1220, 860)


func _ready() -> void:
	super._ready()
	_build()
	Events.crafting_changed.connect(_build)
	Events.inventory_changed.connect(_build)


func _build() -> void:
	UIKit.clear(content)
	var st := DB.station(station_id)
	var head := UIKit.hbox(18)
	head.add_child(UIKit.icon("stations/" + station_id, 128))
	var info := UIKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(Crafting.DISCIPLINE_NAME.get(st.get("discipline", ""), ""), 22, "heading_italic", UIKit.RUBRIC))
	info.add_child(UIKit.label(st.get("purpose", ""), 22))
	var chk := UIKit.label(check_line(station_id), 18, "body_italic")
	chk.name = "CheckLine"
	chk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(chk)
	var why := Crafting.station_locked_reason(station_id)
	if why != "":
		info.add_child(UIKit.label("Locked — " + why, 22, "body_bold", UIKit.RUBRIC))
	head.add_child(info)
	var hist := UIKit.button("History", func(): Events.open_panel.emit("history", {"kind": "station", "id": station_id}), 120)
	hist.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(hist)
	content.add_child(head)
	content.add_child(UIKit.divider())
	var body := UIKit.vbox(10)
	var job := Crafting.job()
	if not job.is_empty():
		var r := DB.recipe(job["recipe"])
		var ops := Crafting.operations(job["recipe"])
		body.add_child(UIKit.rich("[b]Current work:[/b] %s  [i](%s, %s)[/i]" % [r["name"], Crafting.material(job["recipe"]).get("name", ""), Crafting.difficulty_word(job["recipe"])], 22))
		var done: Array = job.get("ops", [])
		var lines := []
		for i in ops.size():
			var o: Dictionary = ops[i]
			var nm := "%d. %s — %s (%d check%s · %s)" % [i + 1, o["op"], DB.station(o["station"]).get("name", o["station"]), int(o.get("checks", 1)), "s" if int(o.get("checks", 1)) > 1 else "",
				check_name(str(o["station"]))]
			if i < int(job["step"]):
				var q := float(done[i]["q"]) if i < done.size() else 0.0
				lines.append("[color=#5e421c][s]%s[/s]  [b]%d%%[/b][/color]" % [nm, int(round(q))])
			elif i == int(job["step"]) and not job["awaiting_dice"]:
				lines.append("[b][color=#7e2418]▶ %s[/color][/b]" % nm)
			else:
				lines.append(nm)
		lines.append(("[b][color=#7e2418]▶ Roll the dice[/color][/b]" if job["awaiting_dice"] else "Then: roll the dice"))
		body.add_child(UIKit.rich("\n".join(lines), 20))
		if job["awaiting_dice"]:
			body.add_child(UIKit.button("Roll the dice and finish the piece", func(): Events.open_panel.emit("dice", {}), 420))
		elif Crafting.current_station() == station_id:
			var op := Crafting.op_params()
			var wb := UIKit.button("%s (%d check%s · %s)" % [op["op"], op["count"], "s" if op["count"] > 1 else "", check_name(station_id)], _work, 520)
			wb.name = "WorkButton"
			wb.tooltip_text = check_line(station_id)
			body.add_child(wb)
		else:
			# The Living Realm: the next station is marked in the workshop; one click walks there (stairs/lift too)
			var nsid := Crafting.current_station()
			var hint := Smithy.floor_hint(nsid)
			body.add_child(UIKit.label("Next: %s at %s%s." % [Crafting.current_op().get("op", ""), Smithy.station_ref(nsid), (" (" + hint + ")") if hint != "" else ""], 22, "body_italic"))
			if Property.is_installed(nsid):
				var go := UIKit.button("Walk to %s" % Smithy.station_ref(nsid), _walk_next, 420)
				go.name = "WalkNext"
				go.tooltip_text = "Walks you there and opens it — the ember marker shows where it stands."
				body.add_child(go)
		body.add_child(UIKit.button("Abandon work (return materials)", func(): Crafting.cancel(), 340))
	else:
		content.add_child(_filter_bar())
		list_box = UIKit.vbox(10)
		body.add_child(list_box)
		_fill_list()
	if station_id == "rune_engraving_stand" and why == "":
		body.add_child(UIKit.divider())
		body.add_child(_socket_ui())
	if station_id == "infusion_rack" and why == "":
		body.add_child(UIKit.divider())
		body.add_child(_treat_ui())
	if why == "" and job.is_empty():
		var svc := WorkshopServices.build(station_id)   # sharpening (grinding wheel), reforging (anvil)
		if svc != null:
			body.add_child(UIKit.divider())
			body.add_child(svc)
	if why == "":
		body.add_child(UIKit.divider())
		body.add_child(UIKit.button("Practise a check — %s (no materials, a little experience)" % check_name(station_id), _practice, 460))
	content.add_child(UIKit.scroll(body, 560 if job.is_empty() else 600))


# ------------------------------------------------------------------ recipe search and filters
func _filter_bar() -> Control:
	var v := UIKit.vbox(6)
	var top := UIKit.hbox(10)
	var le := LineEdit.new()
	le.placeholder_text = "Search recipes by name or type…"
	le.text = query
	le.custom_minimum_size = Vector2(380, 44)
	le.add_theme_font_override("font", Assets.font("body"))
	le.add_theme_font_size_override("font_size", 20)
	le.clear_button_enabled = true
	le.add_theme_color_override("font_color", UIKit.INK)
	le.add_theme_color_override("font_placeholder_color", Color(UIKit.INK, 0.45))
	le.text_changed.connect(func(t: String): query = t; _fill_list())
	le.name = "RecipeSearch"
	top.add_child(le)
	var ob := OptionButton.new()
	for i in AVAIL.size():
		ob.add_item(AVAIL[i][1], i)
		if AVAIL[i][0] == avail:
			ob.select(i)
	ob.add_theme_font_size_override("font_size", 18)
	ob.item_selected.connect(func(i: int): avail = AVAIL[i][0]; _fill_list())
	ob.name = "RecipeAvailability"
	top.add_child(ob)
	var cb := CheckBox.new()
	cb.text = "All workshop recipes"
	cb.button_pressed = everywhere
	cb.add_theme_font_override("font", Assets.font("body"))
	cb.add_theme_font_size_override("font_size", 18)
	cb.add_theme_color_override("font_color", UIKit.INK)
	cb.add_theme_color_override("font_pressed_color", UIKit.INK)
	cb.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
	cb.toggled.connect(func(on: bool): everywhere = on; _fill_list())
	top.add_child(cb)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UIKit.button("Design equipment…", func(): Events.open_panel.emit("designer", {"station": station_id}), 220))
	top.add_child(UIKit.button("Skill tree", func(): Events.open_panel.emit("skilltree", {}), 140))
	v.add_child(top)
	chips_row = UIKit.hbox(6)
	v.add_child(chips_row)
	return v


## S2 (OBS-12, BUG-044): the skill check a station runs, in a few words ("precision ring", "Spark & Ember alignment"…).
static func check_name(sid: String) -> String:
	var t := Minigames.mechanic({"station": sid})
	return "precision ring" if t == "ring" else Minigames.label(t)


## The header line: which check this station runs and what it is like at average difficulty, in that mechanic's own
## terms — the ring's zone and needle for the precision ring; tolerance and pace against the standard for the others
## (MinigameBase reads zone/speed as `ease` and `pace`).
static func check_line(sid: String) -> String:
	var c := Crafting.check_params(sid)
	var sk := Crafting.skill_for_station(sid)
	var you := "your %s %d" % [SkillSys.skill_name(sk), Game.player_level(sk)]
	var t := Minigames.mechanic({"station": sid})
	if t == "ring":
		return "Check: precision ring — at average difficulty the target zone is %d° and the needle turns %.2f rev/s (%s widens and slows it)." % [
			int(c["zone"]), float(c["speed"]), you]
	var tol := clampf(float(c["zone"]) / 40.0, 0.55, 2.2)
	var pc := clampf(float(c["speed"]) / 0.55, 0.6, 1.6)
	return "Check: %s (not the precision ring) — at average difficulty: tolerance %d%%, pace %d%% of standard (%s makes it more forgiving and calmer)." % [
		Minigames.label(t), int(round(tol * 100.0)), int(round(pc * 100.0)), you]


static func recipe_cats(r: Dictionary) -> Array:
	var out := []
	var c: String = {"weapon": "weapons", "armour": "armour", "jewellery": "jewellery", "material": "materials",
		"alchemy": "alchemy", "runestone": "runes"}.get(str(r.get("category", "")), "")
	if c != "":
		out.append(c)
	var d: String = {"stitching": "leather", "arcane": "arcane", "alchemy": "alchemy", "runecraft": "runes"}.get(str(r.get("discipline", "")), "")
	if d != "" and not out.has(d):
		out.append(d)
	return out


## "craftable" | "missing" | "locked"
static func recipe_status(rid: String) -> String:
	if Crafting.recipe_locked_reason(rid) != "":
		return "locked"
	return "craftable" if Crafting.missing_inputs(rid).is_empty() else "missing"


static func recipe_matches(r: Dictionary, q: String) -> bool:
	q = q.strip_edges().to_lower()
	if q == "":
		return true
	var out := DB.item(str(r.get("output", "")))
	var hay := " ".join([r.get("name", ""), r.get("category", ""), Crafting.DISCIPLINE_NAME.get(r.get("discipline", ""), ""),
		out.get("name", ""), Items.type_label({"def": r.get("output", "")}), str(out.get("slot", "")), " ".join(recipe_cats(r)),
		Crafting.material(str(r["id"])).get("name", "")]).to_lower()
	for word in q.split(" ", false):
		if not hay.contains(word):
			return false
	return true


## Recipes in scope (this station or the whole workshop), visible, matching the query — before chip and availability filters.
func _scoped() -> Array:
	var src: Array = DB.recipes.values() if everywhere else Crafting.recipes_for_station(station_id)
	return src.filter(func(r): return SkillTree.recipe_visible(str(r["id"])) and recipe_matches(r, query))


func _fill_list() -> void:
	if list_box == null or not is_instance_valid(list_box):
		return
	UIKit.clear(list_box)
	var scoped := _scoped()
	# category chips with counts
	if chips_row and is_instance_valid(chips_row):
		UIKit.clear(chips_row)
		for c in CATS:
			var key: String = c[0]
			var n := scoped.filter(func(r): return key == "all" or recipe_cats(r).has(key)).size()
			var b := UIKit.button("%s (%d)" % [c[1], n], func(): cat = key; _fill_list(), 0)
			b.custom_minimum_size = Vector2(0, 38)
			b.add_theme_font_size_override("font_size", 17)
			b.disabled = cat == key
			b.tooltip_text = "Show only %s" % str(c[1]).to_lower() if key != "all" else "Show every category"
			chips_row.add_child(b)
	var shown := scoped.filter(func(r): return (cat == "all" or recipe_cats(r).has(cat)) and (avail == "all" or recipe_status(str(r["id"])) == avail))
	# craftable first, then known-but-missing, then locked
	var rank := {"craftable": 0, "missing": 1, "locked": 2}
	shown.sort_custom(func(a, b): return int(rank[recipe_status(str(a["id"]))]) < int(rank[recipe_status(str(b["id"]))]))
	var scope_txt := "in the whole workshop" if everywhere else "using this station"
	list_box.add_child(UIKit.label("Recipes %s — %d shown%s" % [scope_txt, shown.size(), (" for “%s”" % query) if query.strip_edges() != "" else ""], 24, "heading"))
	if shown.is_empty():
		list_box.add_child(UIKit.label("No recipe matches. Clear the search or choose another filter — or learn more in the skill tree.", 20, "body_italic"))
	for rec in shown:
		list_box.add_child(_recipe_row(rec))


func _recipe_row(rec: Dictionary) -> Control:
	var rid := str(rec["id"])
	var outer := UIKit.vbox(6)
	var row := UIKit.hbox(14)
	row.add_child(UIKit.icon("icons/" + str(DB.item(rec["output"]).get("icon", rec["output"])), 56))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ins := []
	for id in rec["inputs"]:
		var need := int(rec["inputs"][id])
		var have := Game.count(id)
		# every ingredient is a link to its encyclopedia page (where to get it, how to make it)
		ins.append("[url=item:%s][color=%s]%s %d/%d[/color][/url]" % [id, "#26622f" if have >= need else "#9e3a0c", DB.item(id).get("name", id), have, need])
	var steps := []
	for o in Crafting.operations(rid):
		steps.append("%s (%s)" % [str(o["op"]), check_name(str(o["station"]))])   # S2: the check of every operation, before Begin
	var rs := Guide.recipe_status(rid)
	var lock := Crafting.recipe_locked_reason(rid)
	var lock_txt := ""
	if lock != "":
		var link_to := ""
		for o in rs["obstacles"]:
			if str(o["kind"]) == "node":
				link_to = "skilltree:" + str(o["id"])
				break
			if str(o["kind"]) == "station":
				link_to = "station:" + str(o["id"])
				break
		lock_txt = ("\n[url=%s][color=#9e3a0c]%s[/color][/url]" % [link_to, lock]) if link_to != "" else ("\n[color=#9e3a0c]%s[/color]" % lock)
	var req := []
	for sk in rec.get("requires", {}):
		req.append("%s %d" % [SkillSys.skill_name(sk), int(rec["requires"][sk])])
	var meta := "[color=#5e421c]%d operations · %s · difficulty %d (%s)%s[/color]" % [steps.size(), Crafting.material(rid).get("name", ""),
		Crafting.difficulty(rid), Crafting.difficulty_word(rid), (" · needs " + ", ".join(req)) if not req.is_empty() else ""]
	var txt := GuideUI.rich_links("[b]%s[/b]  [i]%s[/i]\n%s\n%s\n[color=#5e421c][i]%s[/i][/color]%s" % [rec["name"], rec.get("desc", ""), ", ".join(ins), meta, " → ".join(steps),
		lock_txt], 19, _on_link)
	v.add_child(txt)
	row.add_child(v)
	var side := UIKit.vbox(4)
	side.custom_minimum_size = Vector2(170, 0)
	side.add_child(GuideUI.badge(str(rs["state"]), GuideUI.recipe_badge_text(rs), 30))
	var how := UIKit.button("Close ▲" if selected == rid else ("How?" if str(rs["state"]) != "ready" else "Details"), func():
		selected = "" if selected == rid else rid
		_fill_list(), 150)
	how.name = "How_" + rid
	how.tooltip_text = "Show me how: the next step, every source and the full dependency tree"
	side.add_child(how)
	row.add_child(side)
	var b := UIKit.button("Begin", func(): _start(rid), 120)
	b.disabled = lock != "" or not Crafting.missing_inputs(rid).is_empty()
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(b)
	outer.add_child(row)
	if selected == rid:
		outer.add_child(_guidance(rid))
	return outer


## "Show me how" under a selected recipe: the next step with its button, then the full details on request.
func _guidance(rid: String) -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.25, 0.1, 0.08)
	sb.border_color = Color(UIKit.GILT, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	var v := UIKit.vbox(6)
	v.add_child(GuideUI.next_step_box("recipe:" + rid, _on_link, _back()))
	v.add_child(GuideUI.expander("Full details", func(body: VBoxContainer):
		body.add_child(GuideUI.tree_block("recipe:" + rid, _on_link))
		var miss := Crafting.missing_inputs(rid)
		for d in miss:
			body.add_child(UIKit.label("Every way to get %s" % Guide.iname(str(d)), 21, "heading"))
			body.add_child(GuideUI.sources_block(str(d), _on_link, 6))
		body.add_child(GuideUI.rich_links(GuideUI.link("recipe:" + rid, "Open the full page in Help ›"), 19, _on_link))))
	box.add_child(v)
	box.name = "Guidance"
	return box


func _back() -> Dictionary:
	return {"route": "station", "args": {"id": station_id}}


## A link in the recipe list: encyclopedia pages open in Help with a way back to this station.
func _on_link(meta: String) -> void:
	GuideUI.follow(meta, _back())


func _start(rid: String) -> void:
	if Crafting.start(rid):
		Events.toast.emit("Begun: %s. First: %s at the %s." % [DB.recipe(rid)["name"], Crafting.current_op().get("op", ""), DB.station(Crafting.current_station())["name"]], "info")
		if Crafting.current_station() == station_id:
			_work()


func _work() -> void:
	var c := Crafting.op_params()
	if c.is_empty():
		return
	var sid := station_id
	Events.open_panel.emit("skillcheck", {"station": sid, "count": c["count"], "speed": c["speed"], "zone": c["zone"],
		"title": c["op"], "subtitle": "%s · %s" % [DB.station(sid)["name"], DB.recipe(Crafting.job()["recipe"]).get("name", "")],
		"on_done": _on_work_done.bind(sid)})
	Audio.play("sfx/" + str(DB.station(sid).get("sfx", "hammer")).replace("hammer", "hammer_1"), -2.0)


## Closes the panel and walks to the station of the next operation (Smithy.walk_to_station).
func _walk_next() -> void:
	var nsid := Crafting.current_station()
	close()
	if nsid != "":
		var why := Smithy.walk_to_station(nsid)
		if why != "":
			Events.toast.emit(why, "bad")


func _on_work_done(qs: Array, sid: String) -> void:
	Crafting.record_step(sid, qs)
	if Crafting.job().get("awaiting_dice", false):
		Events.open_panel.emit("dice", {})
	else:
		var avg := 0.0
		for q in qs:
			avg += float(q)
		avg /= maxf(1.0, qs.size())
		var hint := Smithy.floor_hint(Crafting.current_station())
		Events.toast.emit("%s — %d%%. Next: %s at %s%s." % [Crafting.grade(avg), int(round(avg)), Crafting.current_op().get("op", "?"),
			Smithy.station_ref(Crafting.current_station()), (" (" + hint + ")") if hint != "" else ""], "good" if avg >= 90.0 else "info")
		# S2: the optional auto-walk (Settings, off by default) — this panel closes and the smith only walks there
		if Smithy.auto_walk_target(sid) != "":
			close()
			Smithy.auto_walk_next(sid)


func _practice() -> void:
	var c := Crafting.check_params(station_id)
	var sid := station_id
	Events.open_panel.emit("skillcheck", {"station": sid, "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Practice — " + DB.station(sid)["name"],
		"on_done": func(qs: Array): Game.grant_player_xp(Crafting.skill_for_station(sid), 2 + int(float(qs[0]) / 40.0))})


func _on_socket_pressed(ob_item: OptionButton, ob_rune: OptionButton) -> void:
	var uid := ob_item.get_item_id(ob_item.selected)
	var rd: String = ob_rune.get_item_metadata(ob_rune.selected)
	ItemSpirit.speak(Game.find_uid(uid), "enchant")   # an awakened piece may have something to say about it
	var c := Minigames.socket_check(rd)   # LW #58: skill-dependent (was a fixed zone 28 / speed 0.6)
	Events.open_panel.emit("skillcheck", {"station": "rune_engraving_stand", "count": 1, "speed": c["speed"], "zone": c["zone"],
		"title": "Setting the runestone", "on_done": _on_socket_done.bind(uid, rd)})


func _on_socket_done(qs: Array, uid: int, rd: String) -> void:
	if Crafting.socket(uid, rd, float(qs[0])):
		Events.toast.emit("The runestone settles into the metal with a hum.", "good")
		Audio.play("sfx/rune_hum")


func _socket_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Set a runestone into equipment", 26, "heading"))
	var items := Game.inventory().filter(func(it): return Items.is_equipment(it) and it.get("sockets", []).size() < 2)
	var runes := Game.inventory().filter(func(it): return DB.item(it["def"]).get("type") == "runestone" and it["def"] != "runestone_blank")
	if items.is_empty() or runes.is_empty():
		v.add_child(UIKit.label("You need a finished runestone and a piece of equipment.", 20, "body_italic"))
		return v
	var h := UIKit.hbox()
	var ob_item := OptionButton.new()
	for it in items:
		ob_item.add_item(Items.display_name(it), int(it["uid"]))
	var ob_rune := OptionButton.new()
	for r in runes:
		ob_rune.add_item(r["name"])
		ob_rune.set_item_metadata(ob_rune.item_count - 1, r["def"])
	h.add_child(ob_item)
	h.add_child(ob_rune)
	h.add_child(UIKit.button("Engrave and set", _on_socket_pressed.bind(ob_item, ob_rune), 220))
	v.add_child(h)
	return v


## Infusion rack: brush an oil or coating onto a piece of equipment (lasts a few expeditions).
func _treat_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Treat equipment with an oil or coating", 26, "heading"))
	var items := Game.inventory().filter(func(x): return Items.is_equipment(x))
	var coats := Game.inventory().filter(func(x): return x["def"] in Crafting.TREATMENTS)
	if items.is_empty() or coats.is_empty():
		v.add_child(UIKit.label("You need a whetstone oil, flame or frost coating, and a piece of equipment.", 20, "body_italic"))
		return v
	var h := UIKit.hbox()
	var ob_item := OptionButton.new()
	for x in items:
		ob_item.add_item(Items.display_name(x), int(x["uid"]))
	var ob_coat := OptionButton.new()
	for c in coats:
		ob_coat.add_item(c["name"])
		ob_coat.set_item_metadata(ob_coat.item_count - 1, c["def"])
	h.add_child(ob_item)
	h.add_child(ob_coat)
	h.add_child(UIKit.button("Apply", func():
		var msg := Crafting.treat(ob_item.get_item_id(ob_item.selected), str(ob_coat.get_item_metadata(ob_coat.selected)))
		Events.toast.emit(msg, "good" if msg.begins_with("The") else "bad"), 160))
	v.add_child(h)
	return v
