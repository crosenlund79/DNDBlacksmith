## ItemPanel — inspecting one piece of equipment and its story (route `item` {uid, tab}; also `history` for items).
## EN: A header (the piece, its rarity and earned distinctions, the maker's mark) and three tabs:
##     Overview — stats, rarity, maker's mark, materials, craftsmanship, origin day and place, distinctions
##                (Legendary is how it was made; Epic and a name are what it has done — shown apart);
##     History  — the chronological Lore record (Provenance.story) with an icon per kind, links to the
##                adventurers involved (their sheet) and to places (the world map, when that panel exists);
##     Owners   — the journey from the maker through every pair of hands to whoever holds it now.
##     Routine pieces show a short record; exceptional ones everything. Opened over the panel that asked for it.
## DA: Genstandens historie: overblik, kronologisk historik med links og ejerrejsen.
class_name ItemPanel
extends UIWindow

const TABS := ["Overview", "History", "Owners"]
const PAPER_CARD := Color(0.94, 0.89, 0.78, 0.65)

var uid := -1
var tab := "Overview"
var page: VBoxContainer
var tab_row: HBoxContainer


func _init(item_uid: int = -1, start_tab := "Overview") -> void:
	uid = item_uid
	tab = start_tab if TABS.has(start_tab) else "Overview"
	super._init("", 1440, 900)


func _it() -> Dictionary:
	return ItemStory.find(uid)


func _ready() -> void:
	super._ready()
	var it := _it()
	if it.is_empty():
		title_label.text = "A lost piece"
		content.add_child(UIKit.label("This piece is no longer anywhere you can see.", 22, "body_italic"))
		return
	title_label.text = Items.display_name(it)
	title_label.add_theme_color_override("font_color", Items.color(it, false))
	content.add_child(_header(it))
	tab_row = UIKit.hbox(8)
	content.add_child(tab_row)
	for t in TABS:
		var b := UIKit.button(t, select_tab.bind(t), 170)
		b.name = "Tab" + t
		b.toggle_mode = true
		tab_row.add_child(b)
	content.add_child(UIKit.divider())
	page = UIKit.vbox(10)
	var sc := UIKit.scroll(page, 520)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sc)
	_build()


func select_tab(t: String) -> void:
	tab = t
	_build()


func _build() -> void:
	var it := _it()
	if it.is_empty() or page == null:
		return
	var n_hist := ItemStory.events_of(it).size()
	var n_own := Provenance.owners(it).size()
	for b in tab_row.get_children():
		var t := str(b.name).substr(3)
		(b as Button).text = t + ({"History": " (%d)" % n_hist, "Owners": " (%d)" % n_own}.get(t, ""))
		(b as Button).set_pressed_no_signal(t == tab)
		(b as Button).add_theme_color_override("font_color", UIKit.RUBRIC if t == tab else UIKit.INK)
	UIKit.clear(page)
	match tab:
		"Overview": _overview(it)
		"History": _history(it)
		"Owners": _owners(it)


# ======================================================================= header
func _header(it: Dictionary) -> Control:
	var h := UIKit.hbox(18)
	var slot := ItemSlot.new(it, 120.0)
	slot.inspectable = false
	h.add_child(slot)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sub := "%s %s" % [Items.RARITY_LABEL.get(str(it.get("rarity", "common")), ""), Items.type_label(it)]
	if ItemStory.is_named(it):
		sub += " · once called %s" % str(it.get("base_name", Items.def(it).get("name", "")))
	v.add_child(UIKit.label(sub, 22, "heading_italic", UIKit.RUBRIC))
	var chips := UIKit.hbox(8)
	if str(it.get("rarity", "")) in ["legendary", "unique", "set", "rare"]:
		chips.add_child(_chip("%s — how it was made" % Items.RARITY_LABEL.get(str(it["rarity"]), ""), Items.COL_LIGHT.get(str(it["rarity"]), UIKit.INK)))
	if it.has("epic"):
		chips.add_child(_chip("✦ Epic — what it has done", Recognition.EPIC_COLOR_LIGHT))
	if ItemStory.is_named(it):
		chips.add_child(_chip("Named “%s”" % ItemStory.earned_name(it), Color("#5e421c")))
	if chips.get_child_count() > 0:
		v.add_child(chips)
	v.add_child(UIKit.rich("[i]%s[/i]" % ItemStory.summary(it), 19))
	h.add_child(v)
	# the maker's mark, large
	var mk := Provenance.maker(it)
	var mv := UIKit.vbox(2)
	mv.custom_minimum_size = Vector2(300, 0)
	var mh := UIKit.hbox(10)
	var mark := UIKit.icon(ItemStory.mark_icon(it), 64)
	mark.name = "MakersMark"
	mh.add_child(mark)
	var mt := UIKit.vbox(0)
	mt.add_child(UIKit.label("MAKER'S MARK", 14, "body_bold", Color("#8a7a60")))
	mt.add_child(UIKit.label(str(mk.get("name", "an unknown smith")), 20, "body_bold"))
	if ApprenticeUI.is_apprentice_work(it):
		mt.add_child(UIKit.label("apprentice at the Ironhand forge" if str(mk.get("workshop", "")) == "ironhand" else "a former apprentice", 15, "body_italic", Color("#7e2418")))
	mt.add_child(UIKit.label(str(Provenance.mark(it).get("name", "")), 17, "body_italic"))
	mh.add_child(mt)
	mv.add_child(mh)
	h.add_child(mv)
	return h


func _chip(t: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.10)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UIKit.label(t, 17, "body_bold", col))
	return p


func _card(min_w := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_CARD
	sb.border_color = Color(UIKit.INK, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	if min_w > 0.0:
		p.custom_minimum_size = Vector2(min_w, 0)
	return p


# ======================================================================= overview
func _overview(it: Dictionary) -> void:
	var row := UIKit.hbox(20)
	# left: the item's full statistics as on the dark tooltip
	var dark := PanelContainer.new()
	dark.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	dark.custom_minimum_size = Vector2(560, 0)
	var tip := Items.tooltip(it).replace("\n[color=#8a7a60][font_size=15]Right-click to inspect its story[/font_size][/color]", "")
	dark.add_child(UIKit.rich(tip, 19, true))
	row.add_child(dark)
	# right: origin and distinctions
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := Provenance.st(it)
	var mk: Dictionary = p.get("maker", {})
	var og: Dictionary = p.get("origin", {})
	var oc := _card()
	var ov := UIKit.vbox(6)
	ov.add_child(UIKit.label("Origin", 26, "heading"))
	var om := UIKit.hbox(12)
	om.add_child(UIKit.icon(ItemStory.mark_icon(it), 48))
	var day := int(mk.get("day", 0))
	var where := str(mk.get("place", ""))
	var omt := UIKit.rich("Made by [b]%s[/b]%s%s.\n[i]%s — %s.[/i]" % [str(mk.get("name", "an unknown smith")),
		(" on day %d" % day) if day > 0 else "", (" at " + where) if where != "" else "", str(Provenance.mark(it).get("name", "")).capitalize(),
		str(Provenance.mark(it).get("desc", ""))], 19)
	if ApprenticeUI.is_apprentice_work(it):
		# iteration 012: an apprentice's piece names them, the forge, their own mark and the master's eye
		omt.text = "%s%s\n[i]%s[/i]" % [ApprenticeUI.maker_line(it, true), (" Day %d." % day) if day > 0 else "", str(Provenance.mark(it).get("name", ""))]
	omt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	om.add_child(omt)
	ov.add_child(om)
	var cr: Dictionary = it.get("craft", {})
	var lines := []
	var mats: Array = og.get("materials", [])
	if not mats.is_empty():
		lines.append("[b]Materials:[/b] %s" % ", ".join(PackedStringArray(mats)))
	if str(cr.get("recipe_name", "")) != "":
		lines.append("[b]Recipe:[/b] %s (%d operations%s)" % [cr["recipe_name"], (cr.get("ops", []) as Array).size(), ", masterwork" if bool(cr.get("masterwork", false)) else ""])
	var q0 := float(og.get("quality", it.get("quality", 0.0)))
	var q1 := float(it.get("quality", 0.0))
	lines.append("[b]Craftsmanship:[/b] %d%%%s" % [int(round(q0)), ("  →  %d%% after work at the forge" % int(round(q1))) if absf(q1 - q0) >= 0.5 else ""])
	lines.append("[b]Rarity at the anvil:[/b] %s" % Items.RARITY_LABEL.get(str(og.get("rarity", it.get("rarity", "common"))), "Common"))
	ov.add_child(UIKit.rich("\n".join(PackedStringArray(lines)), 19))
	oc.add_child(ov)
	right.add_child(oc)
	# distinctions: rarity (made) vs Epic and a name (earned)
	var dc := _card()
	var dv := UIKit.vbox(6)
	dv.add_child(UIKit.label("Distinctions", 26, "heading"))
	var r := str(it.get("rarity", "common"))
	dv.add_child(UIKit.rich("[b]Rarity — how it was made:[/b] [color=#%s]%s[/color]" % [Items.COL_LIGHT.get(r, UIKit.INK).to_html(false), Items.RARITY_LABEL.get(r, "Common")], 19))
	if it.has("epic"):
		var ep: Dictionary = it["epic"]
		dv.add_child(UIKit.rich("[b][color=#%s]✦ Epic — what it has done:[/color][/b] %s (day %d)%s" % [Recognition.EPIC_COLOR_LIGHT.to_html(false), str(ep.get("deed", "")),
			int(ep.get("day", 0)), (" · %d more deeds" % (ep.get("deeds", []) as Array).size()) if not (ep.get("deeds", []) as Array).is_empty() else ""], 19))
	else:
		dv.add_child(UIKit.rich("[b]Epic:[/b] [i]not yet — a great deed done with it would earn it.[/i]", 19))
	if ItemStory.is_named(it):
		var nd: Dictionary = it.get("named", {})
		dv.add_child(UIKit.rich("[b]Name:[/b] “%s” — %s%s" % [ItemStory.earned_name(it), str(nd.get("why", "earned on the road")), (" (day %d)" % int(nd.get("day", 0))) if nd.has("day") else ""], 19))
	else:
		dv.add_child(UIKit.rich("[b]Name:[/b] [i]none yet — names are earned, not given.[/i]", 19))
	dc.add_child(dv)
	right.add_child(dc)
	# the record at a glance
	var rc := _card()
	var rv := UIKit.vbox(4)
	var evs := ItemStory.events_of(it)
	var owners := Provenance.owners(it)
	rv.add_child(UIKit.label("The record", 26, "heading"))
	rv.add_child(UIKit.rich("%d event%s · %d owner%s · %s" % [evs.size(), "" if evs.size() == 1 else "s", owners.size(), "" if owners.size() == 1 else "s",
		"a rich history — every deed kept" if ItemStory.is_rich(it) else "a short record, as plain pieces keep"], 19))
	var holder := Provenance.owner_id(it)
	rv.add_child(UIKit.rich("[b]Held now by:[/b] %s" % (Provenance.SMITH_NAME + " (your stores)" if holder in ["", Provenance.SMITH_ID] else Provenance._who(holder)), 19))
	var row2 := UIKit.hbox(8)
	row2.add_child(UIKit.button("Read its history", select_tab.bind("History"), 0))
	row2.add_child(UIKit.button("Follow its owners", select_tab.bind("Owners"), 0))
	if it.has("craft"):
		var it2 := it
		row2.add_child(UIKit.button("Craft record", func(): _go("craft_result", {"item": it2, "fresh": false}), 0))
	if not Game.find_uid(uid).is_empty():   # UX iteration: refine / rework / upgrade / reforge (RefinePanel)
		var u := uid
		var ib := UIKit.button("Improve it…", func(): _go("refine", {"uid": u}), 0)
		ib.name = "ImproveIt"
		ib.tooltip_text = "Refine, rework, upgrade or reforge it at the forge — the same piece, with one more line in its history."
		row2.add_child(ib)
	rv.add_child(row2)
	rc.add_child(rv)
	right.add_child(rc)
	row.add_child(right)
	page.add_child(row)


# ======================================================================= history
func _history(it: Dictionary) -> void:
	var evs := ItemStory.events_of(it)
	if evs.is_empty():
		page.add_child(UIKit.label("Nothing recorded yet.", 22, "body_italic"))
		return
	if not ItemStory.is_rich(it):
		page.add_child(UIKit.label("A plain piece keeps a short record.", 18, "body_italic", Color("#6e5a40")))
	var last_day := -1
	for e in evs:
		var d := int(e.get("day", 0))
		if d != last_day:
			last_day = d
			page.add_child(UIKit.label("Day %d" % d if d > 0 else "Long ago", 22, "heading", UIKit.RUBRIC))
		page.add_child(_event_row(e))


func _event_row(e: Dictionary) -> Control:
	var imp := int(e.get("importance", 1))
	var p := _card()
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	if imp >= 3:
		sb.border_color = UIKit.GILT
		sb.set_border_width_all(3)
	elif imp <= 0:
		sb.bg_color = Color(0.94, 0.89, 0.78, 0.30)
		sb.border_color = Color(UIKit.INK, 0.2)
	sb.set_content_margin_all(6)
	var h := UIKit.hbox(12)
	var ic := UIKit.icon(ItemStory.story_icon(str(e.get("kind", "note")), str(e.get("text", ""))), 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tm := str(e.get("time", ""))
	v.add_child(UIKit.rich(("[color=#7a6a50]%s[/color]  " % tm if tm != "" else "") + ("[b]%s[/b]" % str(e.get("text", "")) if imp >= 3 else str(e.get("text", ""))), 19))
	var links := UIKit.hbox(6)
	for a_id in e.get("actors", []):
		var aid := str(a_id)
		if not Adv.get_a(aid).is_empty():
			links.add_child(_link("◆ " + Talk.npc_name(aid), func(): _go("dossier", {"id": aid})))
	var place := str(e.get("place", ""))
	if place != "":
		if ItemStory.has_world_map() and place != "brindlewick":
			links.add_child(_link("⌖ " + ItemStory.place_name(place), func(): _go("world_map", {"site": place})))
		else:
			links.add_child(UIKit.label("⌖ " + ItemStory.place_name(place), 16, "body_italic", Color("#5e421c")))
	if links.get_child_count() > 0:
		v.add_child(links)
	h.add_child(v)
	p.add_child(h)
	return p


func _link(t: String, cb: Callable) -> Button:
	var b := UIKit.button(t, cb, 0)
	b.flat = true
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", UIKit.RUBRIC)
	b.add_theme_color_override("font_hover_color", Color("#b8321e"))
	return b


## Leaves the inspection for another panel (the panel underneath gives way to it).
func _go(panel_id: String, args: Dictionary) -> void:
	close()
	Events.open_panel.emit.call_deferred(panel_id, args)


# ======================================================================= owners
func _owners(it: Dictionary) -> void:
	var mk := Provenance.maker(it)
	var first := _card()
	var fh := UIKit.hbox(14)
	fh.add_child(UIKit.icon(ItemStory.mark_icon(it), 56))
	var fr := UIKit.rich("[b]%s by %s[/b]%s\n[i]%s · %s[/i]" % ["Forged" if Provenance.is_mine(it) else "Made", (ApprenticeUI.maker_short(it) if ApprenticeUI.is_apprentice_work(it) else str(mk.get("name", "an unknown smith"))),
		(" — day %d" % int(mk.get("day", 0))) if int(mk.get("day", 0)) > 0 else "", str(mk.get("place", "")) if str(mk.get("place", "")) != "" else "place unknown",
		str(Provenance.mark(it).get("name", ""))], 20)
	fr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(fr)
	first.add_child(fh)
	page.add_child(first)
	var ow := ItemStory.owners_shown(it)
	for o in ow:
		if str(o.get("id", "")) == Provenance.SMITH_ID and str(o.get("how", "")) == "forged":
			continue   # the maker's own hands: the card above
		page.add_child(UIKit.label("    ↓  %s" % _how_word(str(o.get("how", ""))), 17, "body_italic", Color("#6e5a40")))
		var c := _card()
		var h := UIKit.hbox(14)
		var id := str(o.get("id", ""))
		var a := Adv.get_a(id)
		if Assets.has_tex("portraits/" + id):
			var por := UIKit.portrait("portraits/" + id, 72)
			if not a.is_empty() and str(a.get("status", "")) == "dead":
				por.modulate = Color(0.55, 0.5, 0.48)
			h.add_child(por)
		elif id == Provenance.SMITH_ID:
			h.add_child(UIKit.icon("ui/story_reunion", 64))
		else:
			h.add_child(UIKit.icon("ui/ic_family", 56))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var to := int(o.get("to", -1))
		var span := ("from day %d — still holds it" % int(o.get("from", 0))) if to == -1 else ("day %d to day %d" % [int(o.get("from", 0)), to])
		var extra := ""
		if not a.is_empty():
			extra = " · %s %s, level %d%s" % [Expeditions.renown_title(a), str(a.get("cls", "")), int(a.get("level", 1)), " · fallen" if str(a.get("status", "")) == "dead" else ""]
		v.add_child(UIKit.rich("[b]%s[/b]%s" % [str(o.get("name", id)), extra], 20))
		v.add_child(UIKit.label(span, 17, "body_italic"))
		h.add_child(v)
		if not a.is_empty():
			var aid := id
			h.add_child(UIKit.button("Sheet", func(): _go("dossier", {"id": aid}), 110))
		c.add_child(h)
		page.add_child(c)
	if ow.size() <= 1:
		page.add_child(UIKit.label("It has never left its first hands.", 19, "body_italic"))
	var lost: Dictionary = Provenance.st(it).get("lost", {})
	if not lost.is_empty():
		page.add_child(UIKit.label("Lost on day %d — %s." % [int(lost.get("day", 0)), str(lost.get("how", ""))], 19, "body_italic", UIKit.RUBRIC))


static func _how_word(how: String) -> String:
	return {"forged": "forged", "sold": "sold", "bought": "bought", "given": "given", "found": "found", "looted": "taken as spoils",
		"inherited": "inherited", "recovered": "carried home", "pawned": "pawned", "redeemed": "redeemed from the pawnbroker",
		"commissioned": "made to order", "offered": "offered at the counter", "returned": "returned", "received": "came to the forge",
		"held": "held"}.get(how, how)
