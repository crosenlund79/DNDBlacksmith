## MapPanel — the full village map: buildings by name, exits labelled with their regions, the smith,
## everyone in view (names on hover), who wants a word, and every shop and service as a medallion.
## EN: Click a shop medallion (or its row in "Shops & services") for a compact card: name, business, open now or
##     closed (Venues, the same hours the keepers keep), what it deals in (categories, never the full stock),
##     whether its counter has a purchasing screen, how to use it and a "Travel there" button (quick travel).
##     Opened with args {"venue": id} the card is selected at once (links from the Help/guidance pages).
##     The legend folds away under its own button.
## DA: Landsbykortet med butikker: klik et skilt for åbningstid, varekategorier, betjening og hurtigrejse.
class_name MapPanel
extends UIWindow

var view: VillageMapView
var wants: VBoxContainer
var list: VBoxContainer
var card: VBoxContainer
var legend: VBoxContainer
var selected := ""
var _acc := 0.0
var _toggle: Button


func _init(args := {}) -> void:
	selected = str(args.get("venue", ""))
	if Venues.get_v(selected).is_empty():
		selected = ""
	super._init("Map of Brindlewick", 1660, 940)


func _ready() -> void:
	super._ready()
	var h := UIKit.hbox(18)
	view = VillageMapView.new(false)
	view.force_village = true
	view.show_venues = true
	view.custom_minimum_size = Vector2(1180, 820)
	view.venue_clicked.connect(select)
	h.add_child(view)
	var side := UIKit.vbox(8)
	side.custom_minimum_size = Vector2(400, 0)
	side.add_child(InkIcons.heading("ic_travel", "Shops & services", 26))
	list = UIKit.vbox(2)
	list.name = "VenueList"
	side.add_child(UIKit.scroll(list, 220))
	card = UIKit.vbox(4)
	card.name = "VenueCard"
	var cardbox := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.92)
	sb.border_color = Color(UIKit.INK, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	cardbox.add_theme_stylebox_override("panel", sb)
	cardbox.custom_minimum_size = Vector2(390, 290)
	cardbox.add_child(card)
	side.add_child(cardbox)
	side.add_child(InkIcons.heading("ic_talk", "Wanting a word", 22))
	wants = UIKit.vbox(4)
	side.add_child(UIKit.scroll(wants, 80))
	var btns := UIKit.hbox(6)
	btns.add_child(InkIcons.button("ic_travel", "Quick travel [%s]" % Settings.key_label("quick_travel"), func(): Events.open_panel.emit("quick_travel", {}), 0))
	btns.add_child(InkIcons.button("tb_map", "The world [%s]" % Settings.key_label("panel_world_map"), func(): Events.open_panel.emit("world_map", {}), 0))
	side.add_child(btns)
	var row2 := UIKit.hbox(6)
	var lb := UIKit.button("Legend ▸", func(): pass, 0)
	lb.pressed.connect(func():
		legend.visible = not legend.visible
		cardbox.visible = not legend.visible
		lb.text = "Legend ▾" if legend.visible else "Legend ▸")
	row2.add_child(lb)
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	if w and w.area != "village" and w.buildings.has(w.area):
		var bname := str(w.buildings[w.area].get("name", w.area))
		_toggle = UIKit.button("Show " + bname, func():
			view.force_village = not view.force_village
			_toggle.text = ("Show " + bname) if view.force_village else "Show the village"
			view.queue_redraw(), 0)
		row2.add_child(_toggle)
	side.add_child(row2)
	legend = UIKit.vbox(2)
	legend.visible = false
	for row in [["player", "You (the arrow points where you face)"], ["building", "Building"], ["station", "Workstation (indoors)"],
			["exit", "Road out of the village"], ["road", "Road"], ["water", "Stream"], ["adventurer", "Adventurer"],
			["customer", "Customer at the shop"], ["hireling", "Your hireling"], ["villager", "Villager"], ["talk", "Wants a word with you"]]:
		legend.add_child(_legend_row(row[0], row[1]))
	legend.add_child(UIKit.label("Medallions: shops and services (struck through when closed). Hover a figure for its name.", 16, "body_italic"))
	(legend.get_child(legend.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(legend)
	side.move_child(legend, cardbox.get_index())
	h.add_child(side)
	content.add_child(h)
	_fill_list()
	_fill_card()
	_fill_wants()


## Selects a venue: its medallion is ringed on the map and its card shown.
func select(id: String) -> void:
	selected = id if not Venues.get_v(id).is_empty() else ""
	if legend and legend.visible:
		legend.visible = false
		card.get_parent().visible = true
	Audio.play("sfx/ui_click", -8.0)
	_fill_list()
	_fill_card()


func _legend_row(kind: String, text: String) -> Control:
	var row := UIKit.hbox(10)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(30, 24)
	sw.draw.connect(func(): VillageMapView.draw_symbol(sw, kind, Vector2(15, 12), 9.0 if kind in ["talk", "building", "player", "station", "exit", "road", "water"] else 6.0))
	row.add_child(sw)
	row.add_child(UIKit.label(text, 17))
	return row


func _fill_list() -> void:
	view.selected_venue = selected
	UIKit.clear(list)
	for id: String in Venues.ids():
		var vid := id
		var open := Venues.is_open(id)
		var b := UIKit.button("%s %s" % ["●" if open else "○", Venues.get_v(id)["name"]], func(): select(vid), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(370, 34)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", UIKit.INK if open else Color(UIKit.INK, 0.55))
		b.tooltip_text = Venues.status_text(id)
		if id == selected:
			b.add_theme_color_override("font_color", UIKit.RUBRIC)
		list.add_child(b)
	view.queue_redraw()


## The compact card: at a glance (name, business, open now) → how (counter, the next step) → travel.
func _fill_card() -> void:
	UIKit.clear(card)
	if selected == "":
		card.add_child(UIKit.label("Choose a shop", 24, "heading"))
		var l := UIKit.label("Click a medallion on the map or a name above to see when it is open, what it deals in and how to get there.", 18, "body_italic")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		card.add_child(l)
		return
	var c := Venues.card(selected)
	var top := UIKit.hbox(10)
	var ico := TextureRect.new()
	ico.texture = Assets.get_tex("ui/qt_" + str(Venues.ICONS.get(selected, "square")), Vector2i(96, 96))
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.custom_minimum_size = Vector2(52, 52)
	top.add_child(ico)
	var nv := UIKit.vbox(0)
	nv.add_child(UIKit.label(str(c["name"]), 24, "heading"))
	nv.add_child(UIKit.label(str(c["type"]) + (("  ·  " + str(c["keeper_name"])) if str(c["keeper_name"]) != "" else ""), 17, "body_italic", UIKit.RUBRIC))
	top.add_child(nv)
	card.add_child(top)
	var st := UIKit.label("%s   ·   %s" % [c["status"], c["hours"]], 19, "body_bold", Color("#3e5a1e") if bool(c["open"]) else UIKit.RUBRIC)
	st.name = "VenueStatus"
	card.add_child(st)
	var cats: Array = c["categories"]
	if not cats.is_empty():
		var cl := UIKit.rich("[b]Deals in:[/b] %s" % ", ".join(cats.slice(0, 6)), 17)
		cl.custom_minimum_size = Vector2(366, 0)
		card.add_child(cl)
	var how := ""
	if bool(c["interface"]):
		how = "[b]Counter:[/b] press %s there to buy or trade." % Settings.key_label("interact")
	elif str(c["keeper_name"]) != "":
		how = "[b]No counter:[/b] talk to %s." % c["keeper_name"]
	if how != "":
		var hl := UIKit.rich(how, 17)
		hl.custom_minimum_size = Vector2(366, 0)
		card.add_child(hl)
	var desc := UIKit.label(str(c["how"]), 16, "body_italic")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(366, 0)
	card.add_child(desc)
	card.add_child(_travel_button(str(c["travel"])))


func _travel_button(dest: String) -> Control:
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	var nav: PlayerNav = PlayerNav.of(w) if w else null
	var b := InkIcons.button("ic_travel", "Travel there", func(): pass, 0)
	b.name = "TravelThere"
	if nav == null or nav.player == null:
		b.disabled = true
		return b
	var target := {}
	for d in nav.destinations():
		if d["id"] == dest:
			target = d
	var r: Dictionary = nav.route_to(target["pos"]) if not target.is_empty() else {}
	if target.is_empty() or r.is_empty():
		b.text = "No way there from here"
		b.disabled = true
	elif float(r["length"]) < 160.0:
		b.text = "You are here"
		b.disabled = true
	else:
		b.text = "Travel there (≈ %s on foot)" % PlayerNav._dur(int(r["minutes"]))
		b.pressed.connect(func():
			close()
			nav.request_travel(dest))
	return b


func _fill_wants() -> void:
	UIKit.clear(wants)
	var all := TalkMarkers.all()
	if all.is_empty():
		wants.add_child(UIKit.label("Nobody is waiting on you.", 17, "body_italic"))
		return
	for npc in all:
		wants.add_child(UIKit.rich("[b]%s[/b] — [i]%s[/i]" % [Talk.npc_name(npc), all[npc]], 17))


func _process(delta: float) -> void:
	_acc += delta
	if _acc > 2.0:
		_acc = 0.0
		_fill_wants()
