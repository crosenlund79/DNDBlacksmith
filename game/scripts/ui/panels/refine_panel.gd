## RefinePanel — improving a piece from the stores (route `refine` {station, uid, action}): Refine, Rework,
## Upgrade and Reforge in one place, with a clear BEFORE / AFTER before the player commits and after the result.
## EN: Progressive disclosure: (1) at a glance — the four actions, where each is done, and the one obstacle in the
##     way (or "Ready"); (2) how — the materials, the station, the check and what is left of the piece's budget;
##     (3) details on request — the outcome bands, the ceiling and the limits. The work itself is the station's
##     precision check (skillcheck overlay); Refinement does the rest and writes ONE event into the piece's history.
##     Opened from the anvil / grinding wheel / engraving stand / stitching benches (WorkshopServices) and from the
##     item inspection (ItemPanel). The work can only begin at the right station.
## DA: Forbedring af et stykke udstyr: forfin, omarbejd, opgradér, omsmed — med før/efter-sammenligning.
class_name RefinePanel
extends UIWindow

const GOOD := Color("#2f6a1e")
const BAD := Color("#9a2a14")
const PAPER_CARD := Color(0.94, 0.89, 0.78, 0.65)

var station := ""
var uid := -1
var action := ""
var target := ""
var show_details := false
var result: Dictionary = {}
var list_box: VBoxContainer
var right: VBoxContainer


func _init(args: Dictionary = {}) -> void:
	station = str(args.get("station", ""))
	uid = int(args.get("uid", -1))
	action = str(args.get("action", ""))
	var t := "Improve a piece"
	if station != "":
		t += " — " + str(DB.station(station).get("name", station))
	super._init(t, 1480, 840)   # v1.7 #69: was 1640×900
	name = "RefinePanel"


func _ready() -> void:
	super._ready()
	var pieces := _pieces()
	if uid < 0 and not pieces.is_empty():
		uid = int(pieces[0]["uid"])
	if action == "":
		var here := Refinement.actions_at(station)
		action = str(here[0]) if not here.is_empty() else "refine"
	_build()


func _pieces() -> Array:
	return Game.inventory().filter(func(x): return Items.is_equipment(x))


func _it() -> Dictionary:
	return Game.find_uid(uid)


func _build() -> void:
	UIKit.clear(content)
	content.add_child(UIKit.rich(_where_line(), 19))
	var row := UIKit.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# left: the pieces in the stores
	var lv := UIKit.vbox(6)
	lv.custom_minimum_size = Vector2(430, 0)
	lv.add_child(UIKit.label("Your pieces", 24, "heading"))
	list_box = UIKit.vbox(4)
	lv.add_child(UIKit.scroll(list_box, 690))
	row.add_child(lv)
	_fill_list()
	# right: the chosen piece, the actions and the comparison (or the result)
	right = UIKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UIKit.scroll(right, 720)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	content.add_child(row)
	if result.is_empty():
		_work_view()
	else:
		_result_view()


## One line: what this station does, and where the others are done.
func _where_line() -> String:
	var here := Refinement.actions_at(station)
	if here.is_empty():
		return "[i]Refine at the grinding wheel · rework at the anvil or the rune engraving stand · upgrade and reforge at the anvil. Choose a piece, then an action.[/i]"
	var names := PackedStringArray()
	for a in here:
		names.append(str(Refinement.LABEL[a]))
	return "[b]Here:[/b] %s.  [i]Each improvement is written into the piece's history; its maker, name and story stay.[/i]" % " · ".join(names)


func _fill_list() -> void:
	UIKit.clear(list_box)
	var pieces := _pieces()
	if pieces.is_empty():
		list_box.add_child(UIKit.label("No equipment in your stores.", 19, "body_italic"))
		return
	for it in pieces:
		list_box.add_child(_piece_row(it))


func _piece_row(it: Dictionary) -> Control:
	var u := int(it["uid"])
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIKit.GILT, 0.22) if u == uid else Color(PAPER_CARD, 0.35)
	sb.border_color = UIKit.RUBRIC if u == uid else Color(UIKit.INK, 0.25)
	sb.set_border_width_all(2 if u == uid else 1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var h := UIKit.hbox(8)
	var slot := ItemSlot.new(it, 56.0)
	slot.clicked.connect(func(_x): _choose(u))
	h.add_child(slot)
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text = "%s\n%d%% · %s" % [Items.display_name(it), int(round(float(it.get("quality", 0)))), _budget_word(it)]
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Items.color(it, false))
	b.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
	b.pressed.connect(func(): _choose(u))
	b.name = "Piece_%d" % u
	h.add_child(b)
	p.add_child(h)
	return p


func _budget_word(it: Dictionary) -> String:
	var r: Dictionary = it.get("refine", {})
	var n := int(r.get("refined", 0)) + int(r.get("reworked", 0)) + int(r.get("upgraded", 0))
	return "untouched" if n == 0 else "improved %d×" % n


func _choose(u: int) -> void:
	uid = u
	result = {}
	target = ""
	_build()


func _select(a: String) -> void:
	action = a
	result = {}
	target = ""
	_build()


# ======================================================================= before the work
func _work_view() -> void:
	var it := _it()
	if it.is_empty():
		right.add_child(UIKit.label("Choose a piece on the left.", 22, "body_italic"))
		return
	right.add_child(_piece_head(it))
	# the four actions: label + where + a one-word status
	var tabs := UIKit.hbox(8)
	for a in Refinement.ACTIONS:
		var p := Refinement.plan(it, a, {"station": station})
		var ok := bool(p["ok"])
		var b := UIKit.button("%s  %s" % [Refinement.LABEL[a], "✓" if ok else "·"], _select.bind(a), 196)
		b.name = "Act_" + a
		b.toggle_mode = true
		b.set_pressed_no_signal(a == action)
		b.add_theme_color_override("font_color", UIKit.RUBRIC if a == action else (UIKit.INK if ok else Color(UIKit.INK, 0.55)))
		b.tooltip_text = "%s — at the %s.\n%s" % [Refinement.BLURB[a], p["station_name"], "Ready." if ok else str(p["why"])]
		tabs.add_child(b)
	right.add_child(tabs)
	var p := Refinement.plan(it, action, {"station": station, "target": target})
	var card := _card()
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label(str(Refinement.BLURB[action]), 21, "body_italic"))
	if action == "rework":
		v.add_child(_target_row(it))
	# at a glance: the station, materials and budget on one line each; the first obstacle in red
	var here := station == str(p["station"])
	v.add_child(UIKit.rich("[b]Where:[/b] the %s%s" % [p["station_name"], "  [color=#2f6a1e](you are here)[/color]" if here else "  [color=#7a6a50](walk there to begin)[/color]"], 19))
	var mats := PackedStringArray()
	for d in p["inputs"]:
		var have := Game.count(str(d))
		var need := int(p["inputs"][d])
		mats.append("%d × %s [color=#%s](have %d)[/color]" % [need, str(DB.item(str(d)).get("name", d)), (GOOD if have >= need else BAD).to_html(false), have])
	v.add_child(UIKit.rich("[b]Uses:[/b] %s" % ", ".join(mats), 19))
	var lim := int(p["limit"])
	var budget := "no limit — but the craftsmanship never passes %d%%" % int(round(float(p["ceiling"]))) if lim < 0 \
		else "%d of %d left for this piece · craftsmanship ceiling %d%%" % [int(p["left"]), lim, int(round(float(p["ceiling"])))]
	v.add_child(UIKit.rich("[b]Budget:[/b] %s" % budget, 19))
	if bool(p["ok"]):
		v.add_child(UIKit.rich("[color=#2f6a1e][b]Ready.[/b][/color]" + ("" if here else " [i]Walk to the %s to begin.[/i]" % p["station_name"]), 20))
	else:
		var why := UIKit.rich("[color=#9a2a14][b]✗ %s[/b][/color]%s" % [str(p["why"]), ("  [color=#7a6a50](+%d more)[/color]" % ((p["obstacles"] as Array).size() - 1)) if (p["obstacles"] as Array).size() > 1 else ""], 20)
		why.name = "Obstacle"
		v.add_child(why)
	card.add_child(v)
	right.add_child(card)
	# before / after
	right.add_child(UIKit.label("Before  →  after good work", 24, "heading"))
	right.add_child(_compare(p["rows"], false))
	# details on request
	var dt := UIKit.button(("▾ " if show_details else "▸ ") + "How it works — outcomes, limits", func(): show_details = not show_details; _build(), 0)
	dt.flat = true
	dt.add_theme_color_override("font_color", UIKit.RUBRIC)
	right.add_child(dt)
	if show_details:
		right.add_child(UIKit.rich(_details(it, p), 18))
	var go := UIKit.hbox(10)
	var c: Dictionary = p.get("check", {})
	var label := "Begin: %s at the %s (%d check%s)" % [Refinement.LABEL[action], p["station_name"], int(c.get("count", 1)), "" if int(c.get("count", 1)) == 1 else "s"]
	var begin := UIKit.button(label, _begin, 0)
	begin.name = "BeginWork"
	begin.disabled = not bool(p["ok"]) or not here
	begin.tooltip_text = "" if not begin.disabled else (str(p["why"]) if not bool(p["ok"]) else "Walk to the %s to do this work." % p["station_name"])
	go.add_child(begin)
	go.add_child(UIKit.button("Inspect its story", func(): _go("item", {"uid": uid, "tab": "History"}), 0))
	right.add_child(go)


func _piece_head(it: Dictionary) -> Control:
	var h := UIKit.hbox(14)
	var s := ItemSlot.new(it, 96.0)
	h.add_child(s)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(Items.display_name(it), 30, "title", Items.color(it, false))
	v.add_child(nm)
	var mk := Provenance.maker(it)
	var maker := ApprenticeUI.maker_short(it) if ApprenticeUI.is_apprentice_work(it) else str(mk.get("name", "an unknown smith"))
	v.add_child(UIKit.label("%s %s · %s work · made by %s — %s" % [Items.RARITY_LABEL.get(str(it.get("rarity", "common")), ""), Items.type_label(it),
		Refinement.material_name(Refinement.material_of(it)), maker, str(Provenance.mark(it).get("name", ""))], 18, "body_italic"))
	h.add_child(v)
	h.add_child(UIKit.icon(ItemStory.mark_icon(it), 56))
	return h


func _target_row(it: Dictionary) -> Control:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.label("Re-cut:", 19, "body_bold"))
	var ob := OptionButton.new()
	ob.name = "ReworkTarget"
	ob.add_theme_font_size_override("font_size", 18)
	var ts := Refinement.rework_targets(it)
	for i in ts.size():
		var t: Dictionary = ts[i]
		ob.add_item("%s  (range %d–%d)" % [str(t["label"]), int(t["lo"]), int(t["hi"])], i)
		if str(t["id"]) == target or (target == "" and i == 0):
			ob.select(i)
	if target == "" and not ts.is_empty():
		target = str(ts[0]["id"])
	ob.item_selected.connect(func(i: int): target = str(ts[i]["id"]); _build())
	h.add_child(ob)
	return h


## Rows: [{label, now, lo, hi} | {label, now_text, after_text}]. done: the result (after = a single value).
func _compare(rows: Array, done: bool) -> Control:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	for hd in ["", "Now" if not done else "Before", "", "After"]:
		g.add_child(UIKit.label(hd, 18, "body_bold", Color("#6e5a40")))
	if rows.is_empty():
		g.add_child(UIKit.label("Nothing changes.", 19, "body_italic"))
		return g
	for r in rows:
		g.add_child(UIKit.label(str(r["label"]), 20, "body_bold"))
		if r.has("now_text"):
			g.add_child(UIKit.label(str(r["now_text"]), 20))
			g.add_child(UIKit.label("→", 20))
			g.add_child(UIKit.label(str(r["after_text"]), 20, "body_bold", GOOD if str(r["after_text"]) != str(r["now_text"]) else UIKit.INK))
			continue
		var pct := "%" if bool(r.get("pct", false)) else ""
		var now := int(r["now"])
		g.add_child(UIKit.label("%d%s" % [now, pct], 20))
		g.add_child(UIKit.label("→", 20))
		var lo := int(r["lo"])
		var hi := int(r["hi"])
		var txt := "%d%s" % [hi, pct] if lo == hi or not bool(r.get("dice", false)) else "%d–%d%s" % [lo, hi, pct]
		var col := UIKit.INK
		if hi > now and lo >= now:
			col = GOOD
		elif hi < now:
			col = BAD
		elif bool(r.get("dice", false)):
			col = Color("#8a5a10")   # a gamble: could go either way
		g.add_child(UIKit.label(txt, 20, "body_bold", col))
	return g


func _details(it: Dictionary, p: Dictionary) -> String:
	var lines := PackedStringArray()
	match action:
		"refine":
			lines.append("[b]Check 70%+[/b]: the work takes — craftsmanship rises (less each time), stats follow; 95%+ also draws each stat and affix up by one — never past a fresh piece or the affix's range.")
			lines.append("[b]50–69%[/b]: the work does not take — the materials are spent, a little wear is honed away.")
			lines.append("[b]Below 50%[/b]: a slip — 1 to 3 points of craftsmanship and a little durability lost (a later refine or reforge recovers it).")
		"rework":
			lines.append("The chosen attribute is [b]re-rolled[/b] within its legal range with a d20 weighted by your check (95%+ rolls twice and keeps the best, 115%+ three times). It may come out lower — that is the gamble.")
			lines.append("[b]Below 40%[/b]: the re-cut slips — the attribute loses one point (never below its range).")
		"upgrade":
			var s: Dictionary = p.get("next_step", {})
			lines.append("Adds %s: base stats rise by the material ratio (%s → %s), never past a fresh piece of that material." % [str(s.get("words", "a better material")),
				Refinement.material_name(Refinement.material_of(it)), Refinement.material_name(str(s.get("to", "")))])
			lines.append("[b]Check 60%+[/b]: it bonds. [b]40–59%[/b]: it will not bond — the material is spent, some wear. [b]Below 40%[/b]: also a point of craftsmanship.")
		"reforge":
			lines.append("Always made whole again (durability full, no longer broken). If your work is finer than the piece, craftsmanship rises (up to +8, less each time).")
	lines.append("[color=#6e5a40]Limits per piece: refine %d, rework %d, upgrade %d. The rarity, affixes, name, maker's mark, Epic and history never change; no stat passes what a fresh piece of its kind, material and rarity could reach. The ceiling (%d%%) is the original work +15, and no more than your skill allows.[/color]" % [
		int(Refinement.LIMIT["refine"]), int(Refinement.LIMIT["rework"]), int(Refinement.LIMIT["upgrade"]), int(round(float(p["ceiling"])))])
	return "\n".join(lines)


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_CARD
	sb.border_color = Color(UIKit.INK, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


# ======================================================================= the work
func _begin() -> void:
	var it := _it()
	var p := Refinement.plan(it, action, {"station": station, "target": target})
	if not bool(p["ok"]):
		Events.toast.emit(str(p["why"]), "bad")
		return
	var c: Dictionary = p["check"]
	var u := uid
	var a := action
	var t := target
	Events.open_panel.emit("skillcheck", {"station": str(p["station"]), "count": int(c["count"]), "speed": c["speed"], "zone": c["zone"],
		"title": "%s — %s" % [Refinement.LABEL[a], Items.display_name(it)], "on_done": func(qs: Array): finish(u, a, t, qs)})


## The check is done (also called by tests and the playtest with fixed scores).
func finish(u: int, a: String, t: String, qs: Array) -> void:
	var q := 0.0
	for x in qs:
		q += float(x)
	q /= maxf(1.0, float(qs.size()))
	var r := Refinement.perform(u, a, q, {"target": t, "station": station})
	if not bool(r.get("ok", false)):
		Events.toast.emit(str(r.get("text", "")), "bad")
		return
	Audio.play({"refine": "sfx/grind", "rework": "sfx/hammer_2", "upgrade": "sfx/hammer_2", "reforge": "sfx/hammer_2"}.get(a, "sfx/hammer_2"), -4.0)
	Events.toast.emit("%s: %s" % [Refinement.LABEL[a], {"success": "the work took.", "partial": "the work did not take.", "fail": "a slip — a small loss."}.get(str(r["outcome"]), "")],
		"good" if str(r["outcome"]) == "success" else "bad")
	uid = u
	action = a
	target = t
	result = r
	if is_inside_tree():
		_build()


# ======================================================================= after the work
func _result_view() -> void:
	var it := _it()
	if it.is_empty():
		right.add_child(UIKit.label("The piece is no longer in your stores.", 22, "body_italic"))
		return
	right.add_child(_piece_head(it))
	var oc := str(result.get("outcome", "success"))
	var head: String = {"success": "%s — the work took" % {"refine": "Refined", "rework": "Reworked", "upgrade": "Upgraded", "reforge": "Reforged"}.get(action, "Done"),
		"partial": "The work did not take", "fail": "A slip at the %s" % Refinement.station_label(Refinement.station_for(it, action, target))}.get(oc, "Done")
	var hl := UIKit.label(head, 30, "heading", GOOD if oc == "success" else BAD)
	hl.name = "ResultHeading"
	right.add_child(hl)
	var rows := []
	var b: Dictionary = result.get("before", {})
	var a: Dictionary = result.get("after", {})
	rows.append({"label": "Craftsmanship", "now": int(round(float(b.get("quality", 0)))), "lo": int(round(float(a.get("quality", 0)))), "hi": int(round(float(a.get("quality", 0)))), "pct": true})
	var sb: Dictionary = b.get("stats", {})
	var sa: Dictionary = a.get("stats", {})
	for k in sa:
		if str(k) in ["durability", "durability_max"]:
			continue
		if int(sa[k]) != int(sb.get(k, 0)) or str(k) in ["attack", "protection", "magic"]:
			rows.append({"label": str(k).capitalize().replace("_", " "), "now": int(sb.get(k, 0)), "lo": int(sa[k]), "hi": int(sa[k])})
	if sa.has("durability_max"):
		rows.append({"label": "Durability", "now_text": "%d / %d" % [int(sb.get("durability", 0)), int(sb.get("durability_max", 0))],
			"after_text": "%d / %d" % [int(sa.get("durability", 0)), int(sa["durability_max"])]})
	var ab: Array = b.get("affixes", [])
	var aa: Array = a.get("affixes", [])
	for i in mini(ab.size(), aa.size()):
		rows.append({"label": "+%s (%s)" % [str(aa[i].get("stat", "")), str(aa[i].get("id", ""))], "now": int(ab[i].get("value", 0)), "lo": int(aa[i].get("value", 0)), "hi": int(aa[i].get("value", 0))})
	if str(b.get("material", "")) != str(a.get("material", "")):
		rows.append({"label": "Material", "now_text": Refinement.material_name(str(b.get("material", ""))), "after_text": Refinement.material_name(str(a.get("material", "")))})
	right.add_child(_compare(rows, true))
	var hr := UIKit.hbox(10)
	hr.add_child(UIKit.icon(ItemStory.story_icon(str(result.get("kind", "reforged"))), 40))
	var t := UIKit.rich("[i]Written into its history: %s[/i]" % str(result.get("text", "")), 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	right.add_child(hr)
	right.add_child(UIKit.label("Same piece: its maker, mark, name, owners and every earlier event are kept.", 17, "body_italic", Color("#6e5a40")))
	var row := UIKit.hbox(10)
	var hb := UIKit.button("Read its history", func(): _go("item", {"uid": uid, "tab": "History"}), 0)
	hb.name = "ReadHistory"
	row.add_child(hb)
	row.add_child(UIKit.button("Improve further", func(): result = {}; _build(), 0))
	if station != "":
		var sid := station
		row.add_child(UIKit.button("Back to the station", func(): _go("station", {"id": sid}), 0))
	right.add_child(row)


func _go(panel_id: String, args: Dictionary) -> void:
	close()
	Events.open_panel.emit.call_deferred(panel_id, args)
