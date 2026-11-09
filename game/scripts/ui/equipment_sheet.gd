## EquipmentSheet — the humanoid equipment layout shared by the adventurer sheet (Equipment tab) and the hirelings
## ledger (The Living Realm, milestone 2b).
## EN: The ink miniature (ui/paperdoll) stands in the middle; every slot sits beside the body region where it is worn —
##     head, shoulders (cloak), torso, hands, main hand, feet on the left; neck, off hand, waist, finger and the
##     companion on the right — joined to the figure by a leader line. On the figure itself each worn piece shows as
##     its icon in a ring coloured by condition, a worn cloak drapes behind the shoulders, empty regions are dotted
##     circles: the gear and its state read at a glance. Progressive disclosure: hover a piece for the full tooltip,
##     click it for its maker, owners and history (item panel), "⇄" compares it with a piece from your stores, and the
##     complete stat list sits behind a toggle. `compact` is the smaller variant (icon tiles) for the hirelings ledger.
## DA: Et menneskeformet udstyrsark: hver plads ved den kropsdel, hvor den bæres; tilstand på et blik, detaljer ved
##     hover/klik, sammenligning med lagerets ting og den fulde statliste bag en knap.
class_name EquipmentSheet
extends VBoxContainer

## [slot, column (0 left / 1 right), row, anchor on the 360×560 figure]
const LAYOUT := [
	["helmet", 0, 0, Vector2(180, 74)], ["cloak", 0, 1, Vector2(116, 160)], ["armor", 0, 2, Vector2(180, 224)],
	["weapon", 0, 3, Vector2(52, 292)], ["gloves", 0, 4, Vector2(84, 352)], ["boots", 0, 5, Vector2(180, 452)],
	["amulet", 1, 0, Vector2(180, 148)], ["shield", 1, 1, Vector2(310, 246)], ["belt", 1, 2, Vector2(180, 300)],
	["ring", 1, 3, Vector2(278, 352)], ["companion", 1, 4, Vector2(318, 478)]]
const FIG := Vector2(360, 560)
const STATS := [["attack", "Attack", "Atk"], ["protection", "Protection", "Prot"], ["magic", "Magic", "Mag"], ["fire", "Fire", "Fire"],
	["frost", "Frost", "Frost"], ["ward", "Ward", "Ward"], ["vitality", "Vitality", "Vit"], ["speed", "Speed", "Spd"],
	["scouting", "Scouting", "Scout"], ["heal", "Healing", "Heal"], ["carry", "Carry", "Carry"], ["luck", "Luck", "Luck"]]
const C_GOOD := Color("#4c7a34")
const C_WORN := Color("#b8862e")
const C_BAD := Color("#a8321e")
const C_BROKEN := Color("#7e2418")
const C_FAINT := Color(0.13, 0.08, 0.05, 0.28)
const C_LABEL := Color("#8a7a60")

static var show_stats := false   # the full stat list is behind a toggle; remembered while the game runs

var eq: Dictionary
var compact := false
var known_fn: Callable          # (item) -> bool: false shows "a <kind>" only (Master difficulty, strangers)
var wanted: Array = []          # slots on the owner's shopping list ("wanted" on an empty card)
var candidates := {}            # slot -> Array of store items worth comparing (shows "⇄" on that card)
var on_compare: Callable        # (slot) -> void
var slots: Array = []           # the layout actually used, with extra slots from item data appended
var doll: Control
var overlay: Control
var stats_box: VBoxContainer
var card_size := Vector2(350, 96)
var row_h := 106.0
var fig_pos := Vector2.ZERO
var fig_scale := 1.0
var cards := {}                 # slot -> Control (for tests and the overlay's lines)


## opts: compact (bool), known (Callable item -> bool), wanted (Array of slots), candidates ({slot: [items]}),
## on_compare (Callable slot -> void), extra_slots (Array: slots beyond the standard layout, e.g. from item data).
func _init(equipment: Dictionary, opts := {}) -> void:
	eq = equipment
	compact = bool(opts.get("compact", false))
	known_fn = opts.get("known", Callable())
	wanted = opts.get("wanted", [])
	candidates = opts.get("candidates", {})
	on_compare = opts.get("on_compare", Callable())
	add_theme_constant_override("separation", 8)
	slots = LAYOUT.duplicate(true)
	var rows := [6, 5]
	for extra in opts.get("extra_slots", []):
		if region_of(str(extra)) != "" or _has_slot(str(extra)):
			continue
		var col := 0 if rows[0] <= rows[1] else 1
		slots.append([str(extra), col, rows[col], Vector2(180, 260)])
		rows[col] += 1
	for s in eq:   # anything worn in a slot the layout does not know still shows
		if not _has_slot(str(s)) and not (eq[s] as Dictionary).is_empty():
			var col2 := 0 if rows[0] <= rows[1] else 1
			slots.append([str(s), col2, rows[col2], Vector2(180, 260)])
			rows[col2] += 1
	if compact:
		card_size = Vector2(64, 64)
		row_h = 86.0
		fig_scale = 0.75
	else:
		fig_scale = 1.0
	var max_rows := maxi(rows[0], rows[1])
	var fig_sz := FIG * fig_scale
	var side := (card_size.x + (60.0 if compact else 36.0))
	fig_pos = Vector2(side, 0)
	_build_header()
	doll = Control.new()
	doll.custom_minimum_size = Vector2(side * 2.0 + fig_sz.x, maxf(fig_sz.y + 8.0, max_rows * row_h))
	doll.mouse_filter = Control.MOUSE_FILTER_PASS
	doll.draw.connect(_draw_under)
	add_child(doll)
	var tr := TextureRect.new()
	tr.texture = Assets.get_tex("ui/paperdoll")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = fig_pos
	tr.size = fig_sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(tr)
	for d in slots:
		var s := str(d[0])
		var c := _tile(s) if compact else _card(s)
		c.position = _card_pos(d)
		c.name = "Slot_" + s
		doll.add_child(c)
		cards[s] = c
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = doll.custom_minimum_size
	overlay.draw.connect(_draw_over)
	doll.add_child(overlay)
	stats_box = UIKit.vbox(4)
	stats_box.name = "FullStats"
	add_child(stats_box)
	_fill_stats()


func _has_slot(s: String) -> bool:
	for d in slots:
		if str(d[0]) == s:
			return true
	return false


## The body region a slot is worn on ("" for slots outside the humanoid layout).
static func region_of(slot: String) -> String:
	return str(Items.SLOT_REGION.get(slot, ""))


## Where a slot's card sits (column 0 left of the figure, 1 right of it).
func _card_pos(d: Array) -> Vector2:
	var fig_sz := FIG * fig_scale
	var x := 0.0 if int(d[1]) == 0 else fig_pos.x + fig_sz.x + (60.0 if compact else 36.0)
	return Vector2(x, float(d[2]) * row_h)


func _anchor(d: Array) -> Vector2:
	return fig_pos + (d[3] as Vector2) * fig_scale


func _item(slot: String) -> Dictionary:
	var v: Variant = eq.get(slot, {})
	return v if v is Dictionary else {}


func _known(it: Dictionary) -> bool:
	return it.is_empty() or not known_fn.is_valid() or bool(known_fn.call(it))


## Condition colour of a worn piece: sound, worn (under half), badly worn (under a quarter), broken.
static func condition_color(it: Dictionary) -> Color:
	if it.get("broken", false):
		return C_BROKEN
	var f := Items.durability_frac(it)
	return C_GOOD if f >= 0.5 else (C_WORN if f >= 0.25 else C_BAD)


static func condition_word(it: Dictionary) -> String:
	if it.get("broken", false):
		return "broken"
	var f := Items.durability_frac(it)
	return "sound" if f >= 0.5 else ("worn" if f >= 0.25 else "badly worn")


## "8 pieces worn · 1 badly worn · 1 broken · 2 empty" — the at-a-glance line above the figure.
func summary() -> String:
	var worn := 0
	var weak := 0
	var broken := 0
	var empty := 0
	for d in slots:
		var it := _item(str(d[0]))
		if it.is_empty():
			if str(d[0]) != "companion":
				empty += 1
			continue
		worn += 1
		if it.get("broken", false):
			broken += 1
		elif Items.durability_frac(it) < 0.5:
			weak += 1
	var bits := ["%d piece%s worn" % [worn, "" if worn == 1 else "s"]]
	if weak > 0:
		bits.append("%d worn down" % weak)
	if broken > 0:
		bits.append("%d broken" % broken)
	if empty > 0:
		bits.append("%d empty" % empty)
	return " · ".join(bits)


func _build_header() -> void:
	var h := UIKit.hbox(12)
	var l := UIKit.label(summary(), 17 if compact else 19, "body_bold")
	l.name = "Summary"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := UIKit.button("Hide full stats" if show_stats else "Full stats", func():
		show_stats = not show_stats
		_fill_stats()
		var hb := get_node_or_null("Header/StatsToggle") as Button
		if hb:
			hb.text = "Hide full stats" if show_stats else "Full stats", 0)
	b.name = "StatsToggle"
	b.tooltip_text = "Every stat of every piece worn, and the totals."
	h.add_child(b)
	h.name = "Header"
	add_child(h)


# ----------------------------------------------------------------------- the full stat list (behind the toggle)
func _fill_stats() -> void:
	if stats_box == null:
		return
	UIKit.clear(stats_box)
	stats_box.visible = show_stats
	if not show_stats:
		return
	var used := []
	for st in STATS:
		for d in slots:
			var it := _item(str(d[0]))
			if not it.is_empty() and _known(it) and Items.stat(it, st[0]) != 0:
				used.append(st)
				break
	var g := GridContainer.new()
	g.columns = used.size() + 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 2)
	g.add_child(UIKit.label("Piece", 16, "body_bold", C_LABEL))
	for st in used:
		g.add_child(UIKit.label(str(st[2]), 16, "body_bold", C_LABEL))
	g.add_child(UIKit.label("Condition", 16, "body_bold", C_LABEL))
	var tot := {}
	for d in slots:
		var it := _item(str(d[0]))
		if it.is_empty():
			continue
		var kn := _known(it)
		var nm := Items.display_name(it) if kn else "a %s" % Items.type_label(it).to_lower()
		g.add_child(UIKit.label("%s — %s" % [Items.SLOT_LABEL.get(str(d[0]), str(d[0]).capitalize()), nm.left(28)], 16, "body", Items.color(it, false) if kn else UIKit.INK))
		for st in used:
			var v := Items.stat(it, st[0]) if kn else 0
			tot[st[0]] = int(tot.get(st[0], 0)) + v
			g.add_child(UIKit.label(str(v) if v != 0 else ("·" if kn else "?"), 16))
		var stt: Dictionary = it.get("stats", {})
		g.add_child(UIKit.label(("%s %d/%d" % [condition_word(it), int(stt["durability"]), int(stt["durability_max"])]) if stt.has("durability_max") else condition_word(it), 16, "body", condition_color(it)))
	g.add_child(UIKit.label("Total", 16, "body_bold"))
	for st in used:
		g.add_child(UIKit.label(str(int(tot.get(st[0], 0))), 16, "body_bold"))
	g.add_child(UIKit.label("", 16))
	stats_box.add_child(UIKit.divider())
	stats_box.add_child(g)


# ----------------------------------------------------------------------- cards (full) and tiles (compact)
func _slot_ui(it: Dictionary, px: float) -> ItemSlot:
	var kn := _known(it)
	var ui := ItemSlot.new(it if kn else {}, px)
	ui.show_condition = kn and not it.is_empty()
	if kn and not it.is_empty() and Provenance.applies(it):
		var iu := int(it.get("uid", -1))
		ui.clicked.connect(func(_x): Events.open_panel.emit("item", {"uid": iu}))
	elif not kn and not it.is_empty():
		ui.tooltip_text = "A %s — you don't know them well enough to judge it." % Items.type_label(it).to_lower()
	return ui


func _ghost(slot: String, host: Control, px: float) -> void:
	var ex: String = {"weapon": "icons/sword_iron", "shield": "icons/shield_round", "armor": "icons/jerkin_leather", "helmet": "icons/helm_iron",
		"gloves": "icons/gloves_leather", "boots": "icons/boots_leather", "belt": "icons/belt_leather", "ring": "icons/ring_silver",
		"amulet": "icons/amulet_silver", "cloak": "icons/cloak_travel", "companion": "ui/slot_companion"}.get(slot, "ui/stat_gear")
	var g := TextureRect.new()
	g.texture = Assets.get_tex(ex)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.modulate = Color(1, 1, 1, 0.22)
	g.size = Vector2(px - 18, px - 18)
	g.position = Vector2(9, 9)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(g)


func _slot_title(slot: String) -> String:
	var reg := region_of(slot)
	var lab := str(Items.SLOT_LABEL.get(slot, slot.capitalize()))
	if reg == "" or reg == "at their side":
		return lab.to_upper()
	return (reg + " · " + lab).to_upper() if reg.to_lower() != lab.to_lower() else lab.to_upper()


func _card(slot: String) -> Control:
	var it := _item(slot)
	var kn := _known(it)
	var p := PanelContainer.new()
	p.custom_minimum_size = card_size
	p.size = card_size
	var border: Color = Items.COL_BORDER.get(it.get("rarity", "common"), Color("#6e6250")) if not it.is_empty() else C_FAINT
	if it.get("broken", false):
		border = C_BROKEN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.55) if not it.is_empty() else Color(0.13, 0.08, 0.05, 0.05)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var h := UIKit.hbox(10)
	var sui := _slot_ui(it, 80.0)
	if it.is_empty():
		_ghost(slot, sui, 80.0)
	h.add_child(sui)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(4)
	var tl := UIKit.label(_slot_title(slot), 13, "body_bold", C_LABEL)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	top.add_child(tl)
	if not (candidates.get(slot, []) as Array).is_empty() and on_compare.is_valid():
		var cb := UIKit.button("⇄", on_compare.bind(slot), 0)
		cb.name = "Compare"
		cb.add_theme_font_size_override("font_size", 15)
		cb.custom_minimum_size = Vector2(34, 24)
		cb.tooltip_text = "Compare with %d piece%s from your stores." % [(candidates[slot] as Array).size(), "" if (candidates[slot] as Array).size() == 1 else "s"]
		top.add_child(cb)
	v.add_child(top)
	if it.is_empty():
		v.add_child(UIKit.label("— empty —" + ("  (wanted)" if wanted.has(slot) else ""), 18, "body_italic", C_LABEL))
	elif not kn:
		v.add_child(UIKit.label("a %s" % Items.type_label(it).to_lower(), 19, "body_italic"))
	else:
		var nm := Items.display_name(it)
		if nm.length() > 25:
			nm = nm.left(24) + "…"
		v.add_child(UIKit.label(nm + (" ⚒" if Provenance.is_mine(it) else ""), 18, "body_bold", Items.color(it, false)))
		v.add_child(UIKit.label(key_stats(it), 15))
		var st: Dictionary = it.get("stats", {})
		if st.has("durability_max"):
			var dh := UIKit.hbox(6)
			var col := condition_color(it)
			var b := _bar(float(st["durability"]), float(st["durability_max"]), col, 120, 9)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dh.add_child(b)
			dh.add_child(UIKit.label("BROKEN" if it.get("broken", false) else "%d/%d" % [int(st["durability"]), int(st["durability_max"])],
				15 if not it.get("broken", false) else 16, "body_bold" if it.get("broken", false) else "body", col.darkened(0.15)))
			v.add_child(dh)
	h.add_child(v)
	p.add_child(h)
	return p


func _tile(slot: String) -> Control:
	var it := _item(slot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(card_size.x + 40, row_h)
	var sui := _slot_ui(it, card_size.x)
	sui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if it.is_empty():
		_ghost(slot, sui, card_size.x)
		sui.tooltip_text = "%s — empty" % Items.SLOT_LABEL.get(slot, slot.capitalize())
	v.add_child(sui)
	var reg := region_of(slot)
	var lab := UIKit.label((reg.capitalize() if reg != "" and reg != "at their side" else str(Items.SLOT_LABEL.get(slot, slot.capitalize()))), 13, "body_bold", C_LABEL)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lab)
	return v


static func _bar(v: float, mx: float, col: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(1.0, mx)
	b.value = v
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.08, 0.05, 0.18)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


## The first few non-zero stats: "Atk 12 · Mag 3 · Frost 2".
static func key_stats(it: Dictionary, n := 4) -> String:
	var bits := []
	for k in STATS:
		var v := Items.stat(it, k[0])
		if v != 0:
			bits.append("%s %d" % [k[2], v])
		if bits.size() >= n:
			break
	return " · ".join(bits) if not bits.is_empty() else Items.type_label(it)


# ----------------------------------------------------------------------- drawing on and around the figure
## Under the figure: a worn cloak drapes behind the shoulders, tinted by its rarity.
func _draw_under() -> void:
	var it := _item("cloak")
	if it.is_empty():
		return
	var s := fig_scale
	var o := fig_pos
	var col: Color = Items.COL_BORDER.get(it.get("rarity", "common"), Color("#6e6250"))
	col = col.lerp(Color("#5e4a36"), 0.55)
	var pts := PackedVector2Array()
	for p in [Vector2(118, 140), Vector2(180, 126), Vector2(242, 140), Vector2(286, 220), Vector2(304, 420), Vector2(262, 446),
			Vector2(180, 452), Vector2(98, 446), Vector2(56, 420), Vector2(74, 220)]:
		pts.append(o + p * s)
	doll.draw_colored_polygon(pts, Color(col, 0.55 if not it.get("broken", false) else 0.3))
	var line := pts.duplicate()
	line.append(pts[0])
	doll.draw_polyline(line, Color(0.13, 0.08, 0.05, 0.75), 2.5 * s, true)
	for k in [Vector2(130, 300), Vector2(180, 310), Vector2(230, 300)]:   # folds
		doll.draw_line(o + k * s, o + (k + Vector2(0, 130)) * s, Color(0.13, 0.08, 0.05, 0.3), 1.6 * s, true)


## Over the figure: leader lines, a condition ring with the piece's icon at each body region, dotted rings where empty.
func _draw_over() -> void:
	var r := (22.0 if not compact else 16.0)
	for d in slots:
		var s := str(d[0])
		var it := _item(s)
		var a := _anchor(d)
		var c: Control = cards.get(s)
		if c == null:
			continue
		var cp := c.position + Vector2(card_size.x if int(d[1]) == 0 else 0.0, card_size.y * 0.5)
		if compact:   # tiles centre a slot of card_size in a box 40 px wider
			cp = c.position + Vector2(20.0 + card_size.x if int(d[1]) == 0 else 20.0, card_size.y * 0.5)
		var dir := (a - cp).normalized()
		var lc := Color(0.13, 0.08, 0.05, 0.5) if not it.is_empty() else Color(0.13, 0.08, 0.05, 0.16)
		overlay.draw_line(cp, a - dir * r, lc, 1.6, true)
		if it.is_empty():
			var n := 14
			for i in n:
				if i % 2 == 0:
					overlay.draw_arc(a, r * 0.7, TAU * i / n, TAU * (i + 1) / n, 3, Color(0.13, 0.08, 0.05, 0.35), 1.6, true)
			continue
		var cc := condition_color(it) if _known(it) else Color(0.13, 0.08, 0.05, 0.5)
		overlay.draw_circle(a, r, Color(0.96, 0.92, 0.82, 0.92))
		if _known(it):
			overlay.draw_texture_rect(Assets.get_tex(Items.icon_id(it)), Rect2(a - Vector2(r, r) * 0.82, Vector2(r, r) * 1.64), false)
		overlay.draw_arc(a, r, 0.0, TAU, 28, cc, 3.0 if not compact else 2.4, true)
		if it.get("broken", false):
			overlay.draw_line(a + Vector2(-r, -r) * 0.6, a + Vector2(r, r) * 0.6, C_BROKEN, 3.0, true)


# ----------------------------------------------------------------------- comparing with a piece from the stores
## Side by side: what they wear now and a candidate from your stores, every stat with its difference, the condition,
## and `verdict` (would they take it, at what price — or why not). Static so any panel can show one.
static func compare_view(current: Dictionary, candidate: Dictionary, verdict := "", verdict_good := true) -> Control:
	var box := PanelContainer.new()
	box.name = "CompareView"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.6)
	sb.border_color = UIKit.GILT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", sb)
	var v := UIKit.vbox(6)
	var top := UIKit.hbox(16)
	for pair in [["Wears now", current], ["From your stores", candidate]]:
		var it: Dictionary = pair[1]
		var col := UIKit.hbox(8)
		var sl := ItemSlot.new(it, 64.0)
		sl.show_condition = not it.is_empty()
		col.add_child(sl)
		var cv := UIKit.vbox(0)
		cv.add_child(UIKit.label(str(pair[0]).to_upper(), 13, "body_bold", C_LABEL))
		cv.add_child(UIKit.label(Items.display_name(it) if not it.is_empty() else "— nothing —", 18, "body_bold", Items.color(it, false) if not it.is_empty() else C_LABEL))
		if not it.is_empty():
			cv.add_child(UIKit.label("%s · %s" % [Items.type_label(it), condition_word(it)], 15, "body", condition_color(it)))
		col.add_child(cv)
		col.custom_minimum_size = Vector2(340, 0)
		top.add_child(col)
	v.add_child(top)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 0)
	for hdr in ["", "Now", "Offered", "Change"]:
		g.add_child(UIKit.label(hdr, 14, "body_bold", C_LABEL))
	var rows := 0
	for st in STATS:
		var a := Items.stat(current, st[0]) if not current.is_empty() else 0
		var b := Items.stat(candidate, st[0]) if not candidate.is_empty() else 0
		if a == 0 and b == 0:
			continue
		rows += 1
		g.add_child(UIKit.label(str(st[1]), 16))
		g.add_child(UIKit.label(str(a), 16))
		g.add_child(UIKit.label(str(b), 16, "body_bold"))
		var dlt := b - a
		g.add_child(UIKit.label(("+%d" % dlt) if dlt > 0 else (str(dlt) if dlt < 0 else "="), 16, "body_bold", C_GOOD if dlt > 0 else (C_BAD if dlt < 0 else C_LABEL)))
	var da := Items.durability_frac(current) if not current.is_empty() else 0.0
	var db := Items.durability_frac(candidate) if not candidate.is_empty() else 0.0
	g.add_child(UIKit.label("Condition", 16))
	g.add_child(UIKit.label("%d%%" % int(round(da * 100.0)) if not current.is_empty() else "—", 16))
	g.add_child(UIKit.label("%d%%" % int(round(db * 100.0)) if not candidate.is_empty() else "—", 16, "body_bold"))
	g.add_child(UIKit.label("", 16))
	if rows > 0 or not candidate.is_empty():
		v.add_child(g)
	if verdict != "":
		v.add_child(UIKit.label(verdict, 18, "body_bold", C_GOOD if verdict_good else C_BAD))
	box.add_child(v)
	return box
