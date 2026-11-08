## MapPanel — the full village map: buildings by name, exits labelled with their regions, the smith,
## everyone in view (names on hover) and who wants a word; legend alongside.
## DA: Det fulde landsbykort med bygninger, udgange, personer (navne ved mus-over) og signaturforklaring.
class_name MapPanel
extends UIWindow

var view: VillageMapView
var wants: VBoxContainer
var _acc := 0.0
var _toggle: Button


func _init() -> void:
	super._init("Map of Brindlewick", 1640, 900)


func _ready() -> void:
	super._ready()
	var h := UIKit.hbox(18)
	view = VillageMapView.new(false)
	view.force_village = true
	view.custom_minimum_size = Vector2(1200, 800)
	h.add_child(view)
	var side := UIKit.vbox(8)
	side.custom_minimum_size = Vector2(330, 0)
	side.add_child(InkIcons.heading("tb_map", "Legend", 26))
	for row in [["player", "You (the arrow points where you face)"], ["building", "Building"], ["station", "Workstation (indoors)"],
			["exit", "Road out of the village"], ["road", "Road"], ["water", "Stream"], ["adventurer", "Adventurer"],
			["customer", "Customer at the shop"], ["hireling", "Your hireling"], ["villager", "Villager"], ["talk", "Wants a word with you"]]:
		side.add_child(_legend_row(row[0], row[1]))
	side.add_child(UIKit.divider())
	side.add_child(InkIcons.heading("ic_talk", "Wanting a word", 24))
	wants = UIKit.vbox(4)
	side.add_child(UIKit.scroll(wants, 250))
	side.add_child(UIKit.label("Hover a figure for its name.", 17, "body_italic"))
	side.add_child(InkIcons.button("ic_travel", "Quick travel [%s]" % Settings.key_label("quick_travel"), func(): Events.open_panel.emit("quick_travel", {}), 0))
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	if w and w.area != "village" and w.buildings.has(w.area):
		var bname := str(w.buildings[w.area].get("name", w.area))
		_toggle = UIKit.button("Show " + bname, func():
			view.force_village = not view.force_village
			_toggle.text = ("Show " + bname) if view.force_village else "Show the village"
			view.queue_redraw(), 0)
		side.add_child(_toggle)
	h.add_child(side)
	content.add_child(h)
	_fill_wants()


func _legend_row(kind: String, text: String) -> Control:
	var row := UIKit.hbox(10)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(30, 26)
	sw.draw.connect(func(): VillageMapView.draw_symbol(sw, kind, Vector2(15, 13), 9.0 if kind in ["talk", "building", "player", "station", "exit", "road", "water"] else 6.0))
	row.add_child(sw)
	row.add_child(UIKit.label(text, 18))
	return row


func _fill_wants() -> void:
	UIKit.clear(wants)
	var all := TalkMarkers.all()
	if all.is_empty():
		wants.add_child(UIKit.label("Nobody is waiting on you.", 18, "body_italic"))
		return
	for npc in all:
		wants.add_child(UIKit.rich("[b]%s[/b] — [i]%s[/i]" % [Talk.npc_name(npc), all[npc]], 18))


func _process(delta: float) -> void:
	_acc += delta
	if _acc > 2.0:
		_acc = 0.0
		_fill_wants()
