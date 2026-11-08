## HudToolbar — the illustrated toolbar at the bottom centre of the HUD.
## EN: Brass sockets with ink-drawn icons on a parchment strip; hover shows the name and shortcut,
##     right-click opens the button's second panel (skill levels, Most Wanted board), and a button
##     glows when something needs attention (new offers, a level-up, a commission ready…).
## DA: Den illustrerede værktøjslinje nederst; knapper gløder, når noget kræver opmærksomhed.
class_name HudToolbar
extends PanelContainer

const SOCKET := 68.0

## id, title, icon, hotkey action ("" = none), panel, args, right-click panel, right args, description
const BUTTONS := [
	["inventory", "Inventory", "ui/tb_inventory", "inventory", "inventory", {}, "", {}, "Your stores, equipment and pieces for sale."],
	["skills", "Skill Tree", "ui/tb_skilltree", "panel_skills", "skilltree", {}, "skills", {}, "Plan your growth. Right-click (or K) for your skill levels."],
	["hirelings", "Hirelings", "ui/tb_hirelings", "panel_hirelings", "hirelings", {}, "", {}, "Hire, assign work and send people on expeditions."],
	["adventurers", "Adventurers", "ui/tb_adventurers", "panel_adventurers", "adventurers", {}, "wanted", {}, "Who is in town and how they fare. Right-click (or B) for the Most Wanted board."],
	["orders", "Commissions", "ui/tb_orders", "panel_orders", "orders", {}, "", {}, "Special orders placed by adventurers."],
	["ledger", "Ledger", "ui/tb_ledger", "panel_ledger", "shop", {"tab": "ledger"}, "", {}, "Accounts, status of the business, journal and upgrades."],
	["designer", "Crafting", "ui/tb_designer", "", "designer", {}, "", {}, "Design a piece and plan its work."],
	["property", "Workshop", "ui/tb_property", "", "property", {}, "", {}, "Your rooms, stations and furnishings."],
	["map", "Map", "ui/tb_map", "panel_map", "map", {}, "", {}, "The village of Brindlewick, its people and its roads."],
	["help", "Help", "ui/tb_help", "panel_help", "help", {}, "", {}, "Controls, rules and the reference guide. Restart the tutorial here."],
]

var buttons := {}          # id -> ToolbarButton
var attention := {}        # id -> reason text ("" = none)
var _inv_seen_uid := 0
var _offers_seen := 0
var _acc := 0.0


func _ready() -> void:
	theme = Assets.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Assets.has_tex("ui/toolbar_bar"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.get_tex("ui/toolbar_bar")
		for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			sb.set_texture_margin(s, 44)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 18
		sb.content_margin_bottom = 16
		add_theme_stylebox_override("panel", sb)
	else:
		add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for b in BUTTONS:
		var tb := ToolbarButton.new(b)
		tb.pressed_left.connect(func(): _open(b, false))
		tb.pressed_right.connect(func(): _open(b, true))
		row.add_child(tb)
		buttons[b[0]] = tb
	_inv_seen_uid = _max_uid()
	_offers_seen = Shop.offers().size() if not Game.state.is_empty() else 0
	Events.open_panel.connect(_on_panel_opened)
	Events.skill_level_up.connect(func(who, _s, _l):
		if who == "player":
			attention["skills"] = "You have grown in skill — see what opened up.")
	Events.hireling_returned.connect(func(id, _e): attention["hirelings"] = "%s is back from an expedition." % Talk.npc_name(id))
	Events.adventurer_returned.connect(func(id, _e): attention["adventurers"] = "%s has returned to town." % Talk.npc_name(id))
	_refresh()


func _max_uid() -> int:
	var mx := 0
	if Game.state.is_empty():
		return 0
	for it in Game.inventory():
		mx = maxi(mx, int(it.get("uid", 0)))
	return mx


func _open(b: Array, right: bool) -> void:
	var panel: String = b[6] if right and str(b[6]) != "" else b[4]
	var args: Dictionary = (b[7] if right and str(b[6]) != "" else b[5]).duplicate()
	if UIRoot.instance and UIRoot.instance.current_is(panel, args):
		UIRoot.instance.close_current()
		return
	Events.open_panel.emit(panel, args)


## Clears a button's attention when its panel is opened (by click, hotkey or anywhere else).
func _on_panel_opened(id: String, args: Dictionary) -> void:
	for b in BUTTONS:
		if b[4] == id or b[6] == id:
			if id == "shop" and str(args.get("tab", "")) != "ledger" and b[0] == "ledger":
				continue
			attention.erase(b[0])
	match id:
		"inventory": _inv_seen_uid = _max_uid()
		"shop": _offers_seen = Shop.offers().size()
	_refresh()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		_refresh()


## Recomputes the derived attention reasons (cheap; twice a second).
func _refresh() -> void:
	if Game.state.is_empty():
		return
	var newest := _max_uid()
	if newest > _inv_seen_uid:
		attention["inventory"] = "New items in your stores."
	var offs := Shop.offers().size()
	if offs > _offers_seen:
		attention["ledger"] = "%d offer%s from returning adventurers." % [offs, "" if offs == 1 else "s"]
	elif offs < _offers_seen:
		_offers_seen = offs
	var ready := 0
	for o in Shop.open_orders():
		for it in Game.inventory():
			if Items.is_equipment(it) and Shop.item_meets(o, it):
				ready += 1
				break
	if ready > 0:
		attention["orders"] = "%d commission%s ready to deliver." % [ready, "" if ready == 1 else "s"]
	elif attention.get("orders", "").contains("ready"):
		attention.erase("orders")
	for id in buttons:
		(buttons[id] as ToolbarButton).attention = str(attention.get(id, ""))


## One brass socket.
class ToolbarButton extends Control:
	signal pressed_left
	signal pressed_right

	var def: Array
	var hover := false
	var attention := "":
		set(v):
			if v != attention:
				attention = v
				queue_redraw()
	var _t := 0.0
	var _down := false

	func _init(d: Array) -> void:
		def = d
		custom_minimum_size = Vector2(HudToolbar.SOCKET, HudToolbar.SOCKET)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name = "tb_" + str(d[0])

	func _ready() -> void:
		mouse_entered.connect(func():
			hover = true
			Audio.play("sfx/ui_hover", -10.0)
			UIRoot.show_tooltip(tooltip())
			queue_redraw())
		mouse_exited.connect(func():
			hover = false
			_down = false
			UIRoot.hide_tooltip()
			queue_redraw())

	func key_text() -> String:
		var a := str(def[3])
		return Settings.key_label(a) if a != "" else ""

	func tooltip() -> String:
		var k := key_text()
		var t := "[b]%s[/b]%s\n[i]%s[/i]" % [def[1], ("   [color=#e8cc84][%s][/color]" % k) if k != "" else "", def[8]]
		if str(def[6]) != "":
			var rk := "B" if def[6] == "wanted" else ("K" if def[6] == "skills" else "")
			t += "\n[color=#cbb894]Right-click: %s%s[/color]" % ["Most Wanted board" if def[6] == "wanted" else "skill levels", (" [%s]" % rk) if rk != "" else ""]
		if attention != "":
			t += "\n[color=#ffa050]%s[/color]" % attention
		return t

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_down = mb.pressed
				if not mb.pressed and hover:
					Audio.play("sfx/ui_click", -4.0)
					pressed_left.emit()
				queue_redraw()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				Audio.play("sfx/ui_click", -4.0)
				pressed_right.emit()
				accept_event()

	func _process(delta: float) -> void:
		if attention != "" or hover:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var lift := -2.0 if hover and not _down else (1.0 if _down else 0.0)
		if attention != "":
			var pulse := 0.5 + 0.5 * sin(_t * 4.2)
			draw_circle(c, s.x * 0.5 + 2.0 + pulse * 3.0, Color(1.0, 0.55, 0.18, 0.22 + 0.3 * pulse))
			draw_arc(c, s.x * 0.5 - 1.0, 0, TAU, 40, Color(1.0, 0.62, 0.25, 0.55 + 0.4 * pulse), 2.5)
		if hover:
			draw_circle(c, s.x * 0.5 + 1.0, Color(1.0, 0.75, 0.4, 0.28))
		var r := Rect2(Vector2(0, lift), s)
		draw_texture_rect(Assets.get_tex("ui/tb_socket", Vector2i(96, 96)), r, false)
		var ir := r.grow(-s.x * 0.15)
		draw_texture_rect(Assets.get_tex(str(def[2]), Vector2i(96, 96)), ir, false, Color(1, 1, 1) if not _down else Color(0.85, 0.8, 0.75))
		var k := key_text()
		if k != "":
			var f := Assets.font("body_bold")
			var fs := 14
			var tw := f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var bw := maxf(18.0, tw + 8.0)
			var br := Rect2(Vector2(s.x - bw + 2.0, s.y - 18.0 + lift), Vector2(bw, 18))
			draw_rect(br, Color("#20140c"))
			draw_rect(br, Color("#b8923e"), false, 1.0)
			draw_string(f, br.position + Vector2((bw - tw) * 0.5, 14), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#efe4cc"))
		if attention != "":
			var dp := Vector2(s.x - 10.0, 10.0 + lift)
			draw_circle(dp, 8.0, Color("#20140c"))
			draw_circle(dp, 6.5, Color("#e6702a"))
			draw_string(Assets.font("body_bold"), dp + Vector2(-2.5, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#20140c"))
