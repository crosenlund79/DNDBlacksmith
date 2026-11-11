## AdventurersPanel [J] — the roster of the Tipsy Wyvern as compact cards: portrait, class icon,
## level, whereabouts, a gear-completeness meter and durability warnings. A card opens the full
## character sheet (DossierPanel).
## EN: Accuracy grows with familiarity (talk, drink, equip them) and with rumours from the Velvet
##     Lantern: strangers show a level range; acquaintances show exact levels and their gear's state.
## DA: Kroens eventyrere som kort; et kort åbner karakterarket.
class_name AdventurersPanel
extends UIWindow

var grid: GridContainer


func _init() -> void:
	super._init("Adventurers of the Tipsy Wyvern", 1620, 830)   # #47: was 1640×900


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.note("Click a card for the full character sheet. What you know depends on how well you know them — talk, share a drink, equip them, or pay for rumours at the Velvet Lantern."))
	# Living Workshop #54–55: who is a customer now, who has an order, who would order if asked (WhoIsWho)
	var legend := UIKit.hbox(10)
	legend.name = "KindLegend"
	for kd in ["waiting", "commission", "opportunity"]:
		legend.add_child(WhoIsWho.chip(kd, false))
	legend.add_child(UIKit.note("— everyone else in town is simply visiting.", UIKit.FS_MIN))
	content.add_child(legend)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(UIKit.scroll(grid, 660))
	_build()


func _build() -> void:
	UIKit.clear(grid)
	var list := Adv.all().values()
	# the living first, then by how well you know them
	list.sort_custom(func(a, b):
		var da := 1 if a["status"] == "dead" else 0
		var db := 1 if b["status"] == "dead" else 0
		if da != db:
			return da < db
		return Social.fam(a["id"]) > Social.fam(b["id"]))
	for a in list:
		Expeditions.ensure(a)
		grid.add_child(card(a))


func _know(a: Dictionary) -> float:
	if bool(Expeditions.diff().get("detail", true)):
		return 100.0
	return Social.fam(a["id"]) + (25.0 if Game.has_flag("rumour_" + a["id"]) else 0.0)


func card(a: Dictionary) -> Control:
	var k := _know(a)
	var id: String = a["id"]
	var p := PanelContainer.new()
	p.name = "Card_" + id
	p.custom_minimum_size = Vector2(385, 176)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.6) if a["status"] != "dead" else Color(0.6, 0.56, 0.5, 0.45)
	sb.border_color = UIKit.GILT if Social.spouse() != id else UIKit.RUBRIC
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Audio.play("sfx/ui_click", -4.0)
			Events.open_panel.emit("dossier", {"id": id}))
	p.mouse_entered.connect(func(): sb.border_color = Color("#e6702a"))
	p.mouse_exited.connect(func(): sb.border_color = UIKit.GILT if Social.spouse() != id else UIKit.RUBRIC)
	var h := UIKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# portrait with the class badge in its corner
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(120, 150)
	var por := UIKit.portrait("portraits/" + id, 120)
	if a["status"] == "dead":
		por.modulate = Color(0.5, 0.45, 0.42)
	pc.add_child(por)
	var badge := UIKit.icon(DossierPanel.CLASS_ICON.get(a["cls"], "ui/cls_fighter"), 46)
	badge.position = Vector2(78, 104)
	badge.size = Vector2(46, 46)
	pc.add_child(badge)
	if a["status"] in ["dead", "missing"] and Assets.has_tex("ui/stamp_" + ("fallen" if a["status"] == "dead" else "missing")):
		var st := UIKit.icon("ui/stamp_" + ("fallen" if a["status"] == "dead" else "missing"), 110)
		st.position = Vector2(5, 20)
		st.size = Vector2(110, 110)
		pc.add_child(st)
	# Living Workshop #54–55: a customer now, an open commission, or someone who would order if asked — a tag on the
	# portrait's corner (the card keeps its width)
	var kind := WhoIsWho.kind_of(id)
	if kind in ["waiting", "commission", "opportunity"]:
		var tag := WhoIsWho.chip(kind, true)
		tag.position = Vector2(0, 0)
		pc.add_child(tag)
	h.add_child(pc)
	var v := UIKit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(a["name"], 24, "body_bold"))
	var lv := int(a["level"])
	v.add_child(UIKit.label(("Level %d %s" % [lv, a["cls"]]) if k >= 25.0 else ("Level %d–%d %s" % [maxi(1, lv - 1), lv + 2, a["cls"]]), 18))
	var sw := Expeditions.status_word(a)
	var where := sw
	if a["status"] == "away":
		where += " · " + str(Expeditions.region(str(a.get("dest", ""))).get("name", ""))
	v.add_child(UIKit.label(where, 18, "body_bold", WantedPanel.STATUS_COL.get(sw, UIKit.INK)))
	var co := Companies.name_of(id)   # The Living Realm: their company
	if co != "":
		v.add_child(UIKit.label(co, 16, "body_italic", Color("#24409a")))
	if a["status"] != "dead":
		var c := Adv.completeness(a)
		var gm := UIKit.hbox(6)
		gm.add_child(UIKit.icon("ui/stat_gear", 26))
		var b := DossierPanel._bar(float(c.x), float(c.y), Color("#4c7a34"), 120, 12)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gm.add_child(b)
		gm.add_child(UIKit.label("%d/%d" % [c.x, c.y], 16))
		v.add_child(gm)
		var ww := Adv.wear_warnings(a)
		var wr := UIKit.hbox(4)
		if k < 15.0:
			wr.add_child(UIKit.label("gear's state unknown", 15, "body_italic", Color("#8a7a60")))
		elif int(ww["broken"]) + int(ww["worn"]) == 0:
			wr.add_child(UIKit.label("gear sound", 16, "body_italic", Color("#4c7a34")))
		else:
			if int(ww["broken"]) > 0:
				wr.add_child(UIKit.icon("ui/warn_broken", 26))
				wr.add_child(UIKit.label("%d broken " % int(ww["broken"]), 16, "body_bold", UIKit.RUBRIC))
			if int(ww["worn"]) > 0:
				wr.add_child(UIKit.icon("ui/warn_worn", 26))
				wr.add_child(UIKit.label("%d worn" % int(ww["worn"]), 16, "body_bold", Color("#8a4a10")))
		v.add_child(wr)
		var sh: Array = a.get("shopping", [])
		if not sh.is_empty() and k >= 15.0:
			var e: Dictionary = sh[0]
			v.add_child(UIKit.label("Wants: %s (%s)" % [Adv._slot_name(str(e["slot"])).to_lower(), {"buy": "to buy", "repair": "repair", "requested": "repair asked",
				"commission": "commission", "commissioned": "commissioned", "elsewhere": "elsewhere", "save": "saving", "watch": "watching your display"}.get(e["plan"], e["plan"])], 15, "body_italic", Color("#5e421c")))
	for c2 in v.get_children():
		if c2 is Control:
			(c2 as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	p.add_child(h)
	_ignore_mouse(h)
	return p


func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)
