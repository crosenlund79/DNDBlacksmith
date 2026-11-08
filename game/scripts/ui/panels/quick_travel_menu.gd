## QuickTravelMenu — an illustrated radial menu of the village destinations the smith knows.
## EN: Brass medallions with ink drawings ring a parchment compass; hovering one shows its name, what is
##     there and how long the walk takes. Choosing one closes the menu and the smith walks there at five
##     times the pace while the clock advances by the full walking time (PlayerNav / QuickTravel).
##     Opened with T, from the map panel or by right-clicking the minimap.
## DA: Et illustreret hjul af steder i landsbyen; smeden går derhen i højt tempo, men uret tæller hele gåtiden.
class_name QuickTravelMenu
extends UIWindow

var nav: PlayerNav
var dests: Array = []          # {id, name, icon, pos, desc, minutes (-1 unreachable), here}
var wheel: Wheel
var name_label: Label
var desc_label: Label
var time_label: Label


func _init(_args: Dictionary = {}) -> void:
	super._init("Quick Travel", 900, 900)


func _ready() -> void:
	super._ready()
	title_label.text = "✦ Quick Travel ✦"
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	nav = PlayerNav.of(w)
	if nav == null or nav.player == null:
		content.add_child(UIKit.label("There is nowhere to go from here.", 22, "body_italic"))
		return
	for d in nav.destinations():
		var r := nav.route_to(d["pos"])
		d["minutes"] = int(r.get("minutes", -1)) if not r.is_empty() else -1
		d["here"] = not r.is_empty() and float(r["length"]) < 160.0
		dests.append(d)
	wheel = Wheel.new(self)
	wheel.custom_minimum_size = Vector2(820, 720)
	wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(wheel)
	var foot := UIKit.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var fh := InkIcons.heading("ic_travel", "You walk there briskly; the clock still counts the whole walk. Any key or click stops you.", 18, "body_italic")
	var fl := fh.get_child(fh.get_child_count() - 1) as Label
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.add_child(fh)
	content.add_child(foot)


## The wheel draws itself and hosts three centre labels (name, line, walk time).
func centre_text(d: Dictionary) -> void:
	if d.is_empty():
		name_label.text = "Where to?"
		desc_label.text = "Choose a place on the ring."
		time_label.text = ""
		return
	name_label.text = str(d["name"])
	desc_label.text = str(d["desc"])
	if bool(d.get("here", false)):
		time_label.text = "You are here."
	elif int(d["minutes"]) < 0:
		time_label.text = "No way there from here."
	else:
		time_label.text = "≈ %s on foot" % PlayerNav._dur(int(d["minutes"]))


func choose(d: Dictionary) -> void:
	if int(d["minutes"]) < 0 or bool(d.get("here", false)):
		Audio.play("sfx/error", -8.0)
		return
	var n := nav
	var id := str(d["id"])
	close()
	n.request_travel(id)


class Wheel extends Control:
	var menu: QuickTravelMenu
	var hover := -1
	var _t := 0.0
	const MED := 96.0

	func _init(m: QuickTravelMenu) -> void:
		menu = m
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		var v := UIKit.vbox(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.custom_minimum_size = Vector2(300, 170)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.name_label = UIKit.label("", 30, "heading")
		menu.desc_label = UIKit.label("", 19, "body_italic")
		menu.time_label = UIKit.label("", 22, "body_bold", UIKit.RUBRIC)
		for l: Label in [menu.name_label, menu.desc_label, menu.time_label]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(300, 0)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		v.name = "Centre"
		add_child(v)
		menu.centre_text({})

	func centre() -> Vector2:
		return size * 0.5

	func radius() -> float:
		return minf(size.x, size.y) * 0.5 - MED * 0.5 - 30.0

	func slot(i: int) -> Vector2:
		var n := maxi(1, menu.dests.size())
		var a := -PI * 0.5 + TAU * float(i) / float(n)
		return centre() + Vector2(cos(a), sin(a)) * radius()

	func _process(delta: float) -> void:
		_t += delta
		var v := get_node_or_null("Centre") as Control
		if v:
			v.position = (size * 0.5 - v.size * 0.5).round()
		if hover >= 0:
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var h := -1
			for i in menu.dests.size():
				if (event as InputEventMouseMotion).position.distance_to(slot(i)) < MED * 0.55:
					h = i
			if h != hover:
				hover = h
				if h >= 0:
					Audio.play("sfx/ui_hover", -10.0)
				menu.centre_text(menu.dests[h] if h >= 0 else {})
				queue_redraw()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			for i in menu.dests.size():
				if (event as InputEventMouseButton).position.distance_to(slot(i)) < MED * 0.55:
					Audio.play("sfx/ui_click", -4.0)
					menu.choose(menu.dests[i])
					return

	func _draw() -> void:
		var c := centre()
		var R := radius()
		var ink := UIKit.INK
		# compass rose: rings, spokes and a few tick marks
		draw_circle(c, R + MED * 0.5 + 18.0, Color(0.86, 0.78, 0.6, 0.45))
		draw_arc(c, R + MED * 0.5 + 18.0, 0, TAU, 96, ink, 3.0, true)
		draw_arc(c, R + MED * 0.5 + 10.0, 0, TAU, 96, Color(ink, 0.5), 1.2, true)
		draw_arc(c, R, 0, TAU, 96, Color(ink, 0.35), 1.5, true)
		draw_arc(c, 165.0, 0, TAU, 64, Color(ink, 0.7), 2.4, true)
		draw_arc(c, 158.0, 0, TAU, 64, Color(UIKit.GILT, 0.8), 1.4, true)
		for i in 32:
			var a := TAU * i / 32.0
			var l := 12.0 if i % 4 == 0 else 6.0
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (R + MED * 0.5 + 18.0), c + d * (R + MED * 0.5 + 18.0 - l), ink, 1.6, true)
		for i in menu.dests.size():
			var p := slot(i)
			var d := (p - c).normalized()
			var col := Color(ink, 0.25)
			if i == hover:
				col = Color(UIKit.RUBRIC, 0.8)
			draw_line(c + d * 168.0, p - d * MED * 0.52, col, 2.0 if i == hover else 1.2, true)
		var f := Assets.font("heading")
		for i in menu.dests.size():
			var dd: Dictionary = menu.dests[i]
			var p := slot(i)
			var off := int(dd["minutes"]) < 0
			var here := bool(dd.get("here", false))
			var s := MED * (1.1 if i == hover else 1.0)
			if i == hover:
				var pulse := 0.5 + 0.5 * sin(_t * 4.0)
				draw_circle(p, s * 0.5 + 6.0 + pulse * 3.0, Color(1.0, 0.62, 0.25, 0.25 + 0.25 * pulse))
			var r := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
			var tint := Color(0.55, 0.52, 0.5) if off else (Color(0.8, 0.78, 0.72) if here else Color.WHITE)
			draw_texture_rect(Assets.get_tex("ui/tb_socket", Vector2i(96, 96)), r, false, tint)
			draw_texture_rect(Assets.get_tex(str(dd["icon"]), Vector2i(96, 96)), r.grow(-s * 0.16), false, tint)
			if here:
				draw_arc(p, s * 0.5 + 2.0, 0, TAU, 40, UIKit.GILT, 3.0, true)
			# name under (or over, for the lower half) the medallion
			var nm := str(dd["name"])
			var fs := 17
			var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var below := p.y < c.y + 10.0   # names sit on the inner side of the ring
			var ty := p.y + s * 0.5 + 18.0 if below else p.y - s * 0.5 - 6.0
			var tp := Vector2(p.x - tw * 0.5, ty)
			draw_string_outline(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.94, 0.89, 0.78, 0.95))
			draw_string(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.5) if off else ink)
