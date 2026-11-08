## HirelingHud — the hands at a glance, bottom-left: a small inked card per living hireling with their
## portrait, what they are doing (icon), health with injury marks, how far an expedition has gone and
## their status (working / away / injured / resting).
## EN: Click a card to glance at them in the village (the camera eases over and comes back when you move),
##     or to hear where they are when away. Right-click opens the Ledger of Hands.
## DA: De ansatte i nederste venstre hjørne: portræt, aktivitet, helbred, ekspedition og status.
##     Klik for at se personen i landsbyen; højreklik åbner personalebogen.
class_name HirelingHud
extends Control

const CARD := Vector2(112, 164)
const GAP := 8.0
const FOCUS_SECONDS := 6.0

var row: HBoxContainer
var _ids: Array = []
var _t := 0.0
# camera glance
var _focus_id := ""
var _focus_t := 0.0
var _focus_from := Vector2.ZERO
var _returning := false


func _init() -> void:
	name = "HirelingHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20
	offset_top = -CARD.y - 10
	offset_bottom = -10
	offset_right = 20 + CARD.x * 4 + GAP * 3
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	process_priority = 100     # after the world: the glance overrides camera and roof each frame
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(row)


func _ready() -> void:
	Events.hirelings_changed.connect(_rebuild)
	Events.game_loaded.connect(_rebuild)
	_rebuild()


## The living hands, in ledger order.
static func shown() -> Array:
	if Game.state.is_empty() or not Game.state.has("hirelings"):
		return []
	return Hire.list().filter(func(h): return str(h.get("status", "")) != "dead")


func _rebuild() -> void:
	var ids := shown().map(func(h): return str(h["id"]))
	if ids != _ids:
		_ids = ids
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
		for id: String in ids:
			var c := HandCard.new(id, self)
			row.add_child(c)
	for c in row.get_children():
		c.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.0:
		_t = 0.0
		_rebuild()
	_update_glance(delta)


# ======================================================================= clicks
func clicked(id: String) -> void:
	var h := Hire.get_h(id)
	if h.is_empty():
		return
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	var n: NPCActor = w.npcs.get(id) if w else null
	var st := Hire.hud_status(h)
	if st == "away" or n == null or not n.visible:
		Events.toast.emit(Hire.whereabouts(h), "info")
		return
	focus(id)


func focus(id: String) -> void:
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	if w == null or w.player == null:
		return
	_focus_id = id
	_focus_t = 0.0
	_focus_from = w.player.position
	_returning = false
	Audio.play("sfx/ui_click", -8.0)


func focusing() -> String:
	return _focus_id


func _update_glance(delta: float) -> void:
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	if w == null or w.camera == null:
		return
	var cam := w.camera
	if _focus_id != "":
		var n: NPCActor = w.npcs.get(_focus_id)
		_focus_t += delta
		if n == null or not n.visible or _focus_t > FOCUS_SECONDS or w.player.position.distance_to(_focus_from) > 6.0:
			_focus_id = ""
			_returning = true
		else:
			var target := n.position + Vector2(0, -40) - w.player.position
			cam.offset = cam.offset.lerp(target, 1.0 - exp(-3.5 * delta))
			n.show_name(true)
			# lift the roof over them so the glance actually shows them
			for bid in w.buildings:
				var b: Dictionary = w.buildings[bid]
				if b.get("roof") and (b["rect"] as Rect2).has_point(n.position):
					(b["roof"] as Sprite2D).modulate.a = minf((b["roof"] as Sprite2D).modulate.a, 0.12)
	elif _returning:
		cam.offset = cam.offset.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
		if cam.offset.length() < 2.0:
			cam.offset = Vector2.ZERO
			_returning = false


# ======================================================================= one card
class HandCard extends Control:
	var id := ""
	var hud: HirelingHud
	var portrait: Texture2D
	var _hover := false

	func _init(hid: String, owner_hud: HirelingHud) -> void:
		id = hid
		hud = owner_hud
		custom_minimum_size = HirelingHud.CARD
		size = HirelingHud.CARD
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var h := Hire.get_h(id)
		portrait = Assets.get_tex("portraits/" + str(h.get("look", id)), Vector2i(256, 256))
		mouse_entered.connect(func():
			_hover = true
			queue_redraw()
			var hh := Hire.get_h(id)
			if not hh.is_empty():
				UIRoot.show_tooltip("[b]%s[/b]\n%s\n[i][color=#e8cc84]Click[/color] to find them · [color=#e8cc84]right-click[/color] for the Ledger of Hands[/i]" % [hh["name"], Hire.whereabouts(hh)]))
		mouse_exited.connect(func():
			_hover = false
			queue_redraw()
			UIRoot.hide_tooltip())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				UIRoot.hide_tooltip()
				Events.open_panel.emit("hirelings", {})
			elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				hud.clicked(id)

	func _draw() -> void:
		var h := Hire.get_h(id)
		if h.is_empty():
			return
		var info := Hire.hud_info(h)
		var st := str(info["status"])
		var r := Rect2(Vector2.ZERO, size)
		var ink := Color("#20140c")
		# card: parchment with an inked rule, a soft drop shadow and a gilt edge when hovered or watched
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.28))
		draw_rect(r, Color("#e9d9b0"))
		draw_rect(r.grow(-4), Color("#f1e4c2"))
		var edge := Color("#c8a040") if _hover or hud.focusing() == id else ink
		draw_rect(r, edge, false, 2.5 if edge != ink else 2.0)
		draw_rect(r.grow(-4), Color(ink, 0.35), false, 1.0)
		# portrait in a frame
		var pr := Rect2(16, 8, 80, 80)
		draw_rect(pr.grow(2), Color("#3a2a1a"))
		var tint := Color.WHITE
		match st:
			"away":
				tint = Color(0.78, 0.78, 0.86, 0.55)
			"injured":
				tint = Color(1.0, 0.82, 0.78)
			"resting":
				tint = Color(0.86, 0.84, 0.92)
		if portrait:
			draw_texture_rect(portrait, pr, false, tint)
		draw_rect(pr, ink, false, 1.5)
		if st == "away":
			# a road-dust veil and the word AWAY across the portrait
			draw_rect(Rect2(pr.position + Vector2(0, 30), Vector2(80, 20)), Color(0.13, 0.08, 0.05, 0.72))
			_text("AWAY", Vector2(pr.position.x, pr.position.y + 45), 80, 14, "heading", Color("#efe4cc"), HORIZONTAL_ALIGNMENT_CENTER)
		# activity icon in an inked medallion
		var ic := Assets.get_tex(str(info["icon"]))
		var c := Vector2(92, 80)
		draw_circle(c, 17, ink)
		draw_circle(c, 15, Color("#efe2c0"))
		if ic:
			draw_texture_rect(ic, Rect2(c - Vector2(13, 13), Vector2(26, 26)), false)
		# name and status
		var first := str(info["name"]).get_slice(" ", 0)
		_text(first, Vector2(4, 108), size.x - 8, 18, "heading", ink, HORIZONTAL_ALIGNMENT_CENTER)
		var word := {"working": "working", "away": "away", "injured": "injured", "resting": "resting", "dead": "at rest"}.get(st, st) as String
		var wcol: Color = {"working": Color("#2e5a26"), "away": Color("#3a4a72"), "injured": Color("#9e2a18"), "resting": Color("#6a5232")}.get(st, ink)
		_text(word, Vector2(4, 125), size.x - 8, 15, "body_italic", wcol, HORIZONTAL_ALIGNMENT_CENTER)
		# health with injury marks
		var hb := Rect2(12, 133, 88, 8)
		var hp := float(info["health"])
		draw_rect(hb, Color("#3a2a1a"))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp, hb.size.y)), Color("#6a8a3a").lerp(Color("#a43a1e"), 1.0 - hp))
		draw_rect(hb, ink, false, 1.0)
		for i in mini(int(info["injuries"]), 5):
			var x := hb.end.x - 4 - i * 7.0
			draw_line(Vector2(x - 2.5, hb.position.y - 1), Vector2(x + 2.5, hb.end.y + 1), Color("#a42a1a"), 1.8)
		# expedition progress (days left)
		if st == "away":
			var eb := Rect2(12, 147, 66, 7)
			draw_rect(eb, Color("#3a2a1a"))
			draw_rect(Rect2(eb.position, Vector2(eb.size.x * float(info["exp_progress"]), eb.size.y)), Color("#c8a040"))
			draw_rect(eb, ink, false, 1.0)
			_text("%dd" % int(info["days_left"]), Vector2(80, 157), 26, 14, "body_bold", ink, HORIZONTAL_ALIGNMENT_LEFT)
		elif st == "injured":
			_text("%d day%s to mend" % [int(info["injured_days"]), "" if int(info["injured_days"]) == 1 else "s"], Vector2(4, 158), size.x - 8, 13, "body_italic", Color("#9e2a18"), HORIZONTAL_ALIGNMENT_CENTER)

	func _text(t: String, pos: Vector2, w: float, fs: int, font_key: String, col: Color, align: HorizontalAlignment) -> void:
		draw_string(Assets.font(font_key), pos, t, align, w, fs, col)
