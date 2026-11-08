## UIRoot — HUD, toasts, tooltips, fades, hotkeys and panel routing for the playing state.
## EN: Panels are created on demand from Events.open_panel; modal panels pause the clock.
## DA: Paneler oprettes ved behov fra Events.open_panel; modale paneler sætter uret på pause.
class_name UIRoot
extends CanvasLayer

static var instance: UIRoot

var hud: Control
var clock_label: Label
var gold_label: Label
var energy_bar: ProgressBar
var energy_label: Label
var objective_label: RichTextLabel
var prompt_label: Label
var toast_box: VBoxContainer
var area_banner: Label
var tooltip_panel: PanelContainer
var tooltip_text: RichTextLabel
var fade_rect: ColorRect
var fade_label: Label
var flash_rect: ColorRect
var debug_label: Label
var panel_host: Control
var current: Control
var current_id := ""
var minimap: VillageMapView
var minimap_caption: Label
var toolbar: HudToolbar
var tutorial_card: TutorialCard
var _last_player_pos := Vector2.INF
var _poll := 0.0

const MINIMAP_SIZE := Vector2(330, 222)


func _ready() -> void:
	instance = self
	layer = 10
	_build_hud()
	Events.open_panel.connect(_on_open_panel)
	Events.toast.connect(toast)
	Events.gold_changed.connect(func(_g): _refresh_hud())
	Events.time_changed.connect(func(_d, _m): _refresh_hud())
	Events.objective_changed.connect(func(_t): _refresh_hud())
	Events.fatigue_changed.connect(func(_f): _refresh_hud())
	Events.request_fade.connect(fade)
	Events.legendary_found.connect(func(_it): legendary_flash())
	Events.skill_level_up.connect(_on_level_up)
	Events.close_panels.connect(close_current)
	Events.inventory_changed.connect(Reference.note_seen)
	Tutorial.wire()
	Reference.note_seen()
	_refresh_hud()


static func show_tooltip(bbcode: String) -> void:
	if instance:
		instance.tooltip_text.text = bbcode
		instance.tooltip_panel.visible = true
		instance.tooltip_panel.reset_size()


static func hide_tooltip() -> void:
	if instance:
		instance.tooltip_panel.visible = false


# ======================================================================= HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = Assets.theme
	add_child(hud)
	# top-left: date, time, gold, objective
	var tl := PanelContainer.new()
	tl.add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	tl.position = Vector2(20, 18)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	clock_label = UIKit.label("", 26, "heading")
	gold_label = UIKit.label("", 24, "body_bold", UIKit.RUBRIC)
	objective_label = UIKit.rich("", 20)
	objective_label.custom_minimum_size = Vector2(430, 0)
	v.add_child(clock_label)
	# energy (Vitality): a slim bar under the clock, coloured as fatigue builds
	var er := UIKit.hbox(8)
	er.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_label = UIKit.label("", 18, "body_italic")
	energy_bar = UIKit.bar(100.0, 100.0, 150)
	energy_bar.custom_minimum_size = Vector2(150, 12)
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_bar.show_percentage = false
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var efill := StyleBoxFlat.new()
	efill.set_corner_radius_all(3)
	energy_bar.add_theme_stylebox_override("fill", efill)
	er.add_child(UIKit.label("Energy", 18, "body_bold"))
	er.add_child(energy_bar)
	er.add_child(energy_label)
	v.add_child(er)
	v.add_child(gold_label)
	v.add_child(objective_label)
	tl.add_child(v)
	hud.add_child(tl)
	# top-right: minimap (click for the village map)
	minimap = VillageMapView.new(true)
	minimap.name = "Minimap"
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-20 - MINIMAP_SIZE.x, 18)
	minimap.size = MINIMAP_SIZE
	minimap.clicked.connect(func(): _on_open_panel("map", {}))
	minimap.mouse_entered.connect(func(): show_tooltip("[b]Map[/b]  [color=#e8cc84][%s][/color]\n[i]Click for the village map. Speech marks: someone wants a word.[/i]" % Settings.key_label("panel_map")))
	minimap.mouse_exited.connect(hide_tooltip)
	hud.add_child(minimap)
	minimap_caption = UIKit.label("", 18, "heading_italic", Color("#efe4cc"))
	minimap_caption.add_theme_color_override("font_outline_color", Color("#20140c"))
	minimap_caption.add_theme_constant_override("outline_size", 6)
	minimap_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	minimap_caption.position = Vector2(-20 - MINIMAP_SIZE.x, 22 + MINIMAP_SIZE.y)
	minimap_caption.size = Vector2(MINIMAP_SIZE.x, 26)
	hud.add_child(minimap_caption)
	# bottom centre: the illustrated toolbar
	toolbar = HudToolbar.new()
	toolbar.name = "Toolbar"
	toolbar.anchor_left = 0.5
	toolbar.anchor_right = 0.5
	toolbar.anchor_top = 1.0
	toolbar.anchor_bottom = 1.0
	toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toolbar.offset_bottom = -6
	toolbar.offset_top = -6
	hud.add_child(toolbar)
	# left: the tutorial card
	tutorial_card = TutorialCard.new()
	tutorial_card.position = Vector2(20, 250)
	hud.add_child(tutorial_card)
	# prompt
	prompt_label = UIKit.label("", 26, "heading", Color("#efe4cc"))
	prompt_label.add_theme_color_override("font_outline_color", Color("#20140c"))
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-500, -172)   # above the toolbar
	prompt_label.size = Vector2(1000, 40)
	hud.add_child(prompt_label)
	# area banner
	area_banner = UIKit.label("", 44, "title", Color("#efe4cc"))
	area_banner.add_theme_color_override("font_outline_color", Color("#20140c"))
	area_banner.add_theme_constant_override("outline_size", 10)
	area_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	area_banner.position = Vector2(-500, 80)
	area_banner.size = Vector2(1000, 60)
	area_banner.modulate.a = 0.0
	hud.add_child(area_banner)
	# toasts
	toast_box = UIKit.vbox(6)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toast_box.position = Vector2(-536, -420)      # clear of the toolbar (it ends near x 1355 at 1920)
	toast_box.size = Vector2(516, 400)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast_box)
	# panel host
	panel_host = Control.new()
	panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_host)
	# tooltip
	tooltip_panel = PanelContainer.new()
	tooltip_panel.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100
	tooltip_text = UIKit.rich("", 20, true)
	tooltip_text.custom_minimum_size = Vector2(380, 0)
	tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tooltip_text)
	add_child(tooltip_panel)
	# flash + fade
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.62, 0.25, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.03, 0.02, 0.01, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	fade_label = UIKit.label("", 36, "heading_italic", Color("#efe4cc"))
	fade_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	fade_label.position = Vector2(-600, -40)
	fade_label.size = Vector2(1200, 80)
	fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_label.modulate.a = 0.0
	add_child(fade_label)
	debug_label = UIKit.label("", 16, "body", Color("#c8ffc8"))
	debug_label.position = Vector2(20, 340)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.visible = Settings.get_value("debug/overlay", false)
	add_child(debug_label)


func _refresh_hud() -> void:
	if Game.state.is_empty():
		return
	clock_label.text = "Day %d · %s · %s%s" % [Game.day(), Game.weekday_name(), Game.time_string(),
		"  ‖ paused" if Game.paused else ("  ▸×%d" % Game.speed if Game.speed > 1 else "")]
	gold_label.text = "%d gold" % Game.gold()
	energy_bar.value = Vitality.energy()
	var fb := Vitality.band()
	energy_label.text = fb
	var ecol: Color = {"Fresh": Color("#4e6a2e"), "Steady": Color("#6a6a2e"), "Tired": Color("#9a6a1e"),
		"Weary": Color("#a4441e"), "Exhausted": UIKit.RUBRIC}.get(fb, UIKit.INK)
	(energy_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = ecol.lightened(0.15)
	energy_label.add_theme_color_override("font_color", ecol)
	var obj := Objectives.text()
	objective_label.visible = obj != "" and Settings.get_value("gameplay/show_hints", true)
	objective_label.text = "[color=#7e2418]❧[/color] [i]%s[/i]" % obj


func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.25:
		_poll = 0.0
		_poll_world()
	if tooltip_panel.visible:
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		var p := mp + Vector2(24, 18)
		if p.x + tooltip_panel.size.x > vs.x:
			p.x = mp.x - tooltip_panel.size.x - 16
		if p.y + tooltip_panel.size.y > vs.y:
			p.y = vs.y - tooltip_panel.size.y - 8
		tooltip_panel.position = p
	if debug_label.visible:
		debug_label.text = "FPS %d | day %d %s | area %s | blockers %d | errors %d | missing sprites %d\n%s" % [
			Engine.get_frames_per_second(), Game.day(), Game.time_string(), Game.state.get("player", {}).get("area", "?"),
			Game.ui_blockers, Log.error_count, Assets.missing.size(), "\n".join(Log.lines.slice(max(0, Log.lines.size() - 6)))]


## A few times a second: feed the tutorial the distance walked and caption the minimap.
func _poll_world() -> void:
	var w := get_tree().get_first_node_in_group("world") as VillageWorld
	if w == null or w.player == null or Game.state.is_empty():
		return
	var p := w.player.position
	if _last_player_pos != Vector2.INF:
		Tutorial.on_moved(minf(p.distance_to(_last_player_pos), 200.0))
	_last_player_pos = p
	var cap := "Brindlewick"
	if w.area != "village" and w.buildings.has(w.area):
		cap = str(w.buildings[w.area].get("name", w.area))
		for rm in w.buildings[w.area].get("rooms", []):
			if rm["id"] == w.room:
				cap += " · " + str(rm.get("name", ""))
	minimap_caption.text = cap
	tutorial_card.refresh()


func toast(text: String, kind := "info") -> void:
	if kind == "area":
		area_banner.text = text
		var tw := create_tween()
		tw.tween_property(area_banner, "modulate:a", 1.0, 0.4)
		tw.tween_interval(1.6)
		tw.tween_property(area_banner, "modulate:a", 0.0, 0.8)
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: String = {"good": "#9ad890", "bad": "#ff9a80", "legendary": "#ffa050", "info": "#efe4cc"}.get(kind, "#efe4cc")
	var r := UIKit.rich("[color=%s]%s[/color]" % [col, text], 20, true)
	r.custom_minimum_size = Vector2(456, 0)
	p.add_child(r)
	toast_box.add_child(p)
	# remove_child first: queue_free() alone keeps the node counted until the frame ends,
	# which made this loop spin forever (and exhaust memory) once more than 5 toasts stacked up
	while toast_box.get_child_count() > 5:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw2 := p.create_tween()
	p.modulate.a = 0.0
	tw2.tween_property(p, "modulate:a", 1.0, 0.25)
	tw2.tween_interval(5.5)
	tw2.tween_property(p, "modulate:a", 0.0, 0.6)
	tw2.tween_callback(p.queue_free)


func _on_level_up(who: String, skill: String, lvl: int) -> void:
	var name := "You" if who == "player" else Talk.npc_name(who)
	toast("%s reached %s %d!" % [name, SkillSys.skill_name(skill), lvl], "good")
	if who == "player":
		Audio.play("sfx/level_up", -4.0)


## Fade to black with a line of text, advancing the clock by `minutes`.
func fade(text: String, minutes: int) -> void:
	Game.block_time(true)
	fade_label.text = text
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.8)
	tw.parallel().tween_property(fade_label, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func():
		Game.block_time(false)
		if minutes > 0:
			Game.advance_minutes(minutes)
		Game.block_time(true))
	tw.tween_interval(1.6)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.9)
	tw.parallel().tween_property(fade_label, "modulate:a", 0.0, 0.9)
	tw.tween_callback(func(): Game.block_time(false))


func legendary_flash() -> void:
	Audio.play("sfx/legendary_drop")
	flash_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.55, 0.12)
	tw.tween_property(flash_rect, "color:a", 0.0, 1.2)


# ======================================================================= panels
func close_current() -> void:
	if is_instance_valid(current):
		if current.has_method("close"):
			current.call("close")
		else:
			current.queue_free()
	current = null
	current_id = ""
	hide_tooltip()


## Is the panel `id` (with these args, for the shop's tab) the one on screen?
func current_is(id: String, args := {}) -> bool:
	if not is_instance_valid(current) or current_id != id:
		return false
	if id == "shop" and args.has("tab"):
		return current is ShopPanel and (current as ShopPanel).tab == str(args["tab"])
	return true


func open(panel: Control) -> void:
	close_current()
	current = panel
	panel_host.add_child(panel)
	if panel is UIWindow:
		panel.closed.connect(_on_panel_closed.bind(panel))


func _on_panel_closed(panel: Control) -> void:
	if current == panel:
		current = null
		current_id = ""
	hide_tooltip()


func _on_open_panel(id: String, args: Dictionary) -> void:
	var before := current
	_route(id, args)
	if current != before and is_instance_valid(current):
		current_id = id


func _route(id: String, args: Dictionary) -> void:
	match id:
		"prompt":
			var t: String = args.get("text", "")
			prompt_label.text = ("[%s]  %s" % [Settings.key_label("interact"), t]) if t != "" else ""
		"station":
			open(StationPanel.new(args["id"]))
		"skillcheck":
			# overlay: the panel that asked for the check stays alive (its callback lives there)
			var sc := Minigames.create(args)
			var under := current
			if is_instance_valid(under):
				under.visible = false
			sc.tree_exited.connect(func():
				if is_instance_valid(under) and not under.is_queued_for_deletion():
					under.visible = true)
			panel_host.add_child(sc)
		"dice":
			open(DicePanel.new())
		"reveal":
			open(RevealPanel.new(args["item"]))
		"craft_result":
			open(CraftResultPanel.new(args["item"], bool(args.get("fresh", true))))
		"loot":
			open(LootPanel.new(int(args["uid"])))
		"inventory":
			open(InventoryPanel.new())
		"shop":
			open(ShopPanel.new(args.get("tab", "customers"), args.get("npc", "")))
		"notice":
			open(NoticePanel.new())
		"hirelings":
			open(HirelingsPanel.new())
		"skills":
			open(SkillsPanel.new())
		"adventurers":
			open(AdventurersPanel.new())
		"orders":
			open(OrdersPanel.new())
		"dialogue":
			open(DialoguePanel.new(args["npc"], args.get("area", "village")))
		"sleep":
			open(SleepPanel.new())
		"pause":
			open(PausePanel.new())
		"saves":
			open(SavePanel.new(args.get("mode", "save")))
		"settings":
			open(SettingsPanel.new())
		"difficulty":
			open(DifficultyPanel.new())
		"skilltree":
			open(SkillTreePanel.new())
		"designer":
			open(DesignerPanel.new())
		"property":
			open(PropertyPanel.new())
		"harbour":
			open(HarbourPanel.new())
		"herbalist":
			open(HerbalistPanel.new())
		"ironfront":
			open(IronfrontPanel.new(args))
		"help":
			open(HelpPanel.new(args))
		"history":
			open(HistoryPanel.new(str(args.get("kind", "")), str(args.get("id", ""))))
		"map":
			open(MapPanel.new())
		"customize":
			open(CustomizePanel.new())
		"pawn":
			open(PawnPanel.new(args))
		"rival_smith":
			open(RivalSmithPanel.new(args))
		"creatures":
			open(CreaturesPanel.new(args))
		"caravan":
			open(CaravanPanel.new(args))
		"hall_of_fame":
			open(HallOfFamePanel.new(args))
		"quick_travel":
			open(QuickTravelMenu.new(args))
		"wanted":
			open(WantedPanel.new(str(args.get("tab", "wanted"))))
		"dossier":
			open(DossierPanel.new(str(args["id"])))
		"observe":
			open(ObserverPanel.new(str(args["id"])))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("debug_overlay"):
		debug_label.visible = not debug_label.visible
		Settings.set_value("debug/overlay", debug_label.visible)
		return
	if event.is_action_pressed("dev_panel"):
		get_viewport().set_input_as_handled()
		if current is DevPanel:
			close_current()
		else:
			open(DevPanel.new())
		return
	# time controls work over the board and the observer (they do not stop the clock)
	if event.is_action_pressed("time_pause"):
		get_viewport().set_input_as_handled()
		Game.toggle_pause()
		toast("Time paused." if Game.paused else "Time runs again.", "info")
		_refresh_hud()
		return
	if event.is_action_pressed("time_faster") or event.is_action_pressed("time_slower"):
		get_viewport().set_input_as_handled()
		var i := Game.SPEEDS.find(Game.speed) + (1 if event.is_action_pressed("time_faster") else -1)
		Game.set_speed(int(Game.SPEEDS[clampi(i, 0, Game.SPEEDS.size() - 1)]))
		toast("Time ×%d" % Game.speed, "info")
		_refresh_hud()
		return
	if is_instance_valid(current):
		return
	if event.is_action_pressed("panel_wanted"):
		get_viewport().set_input_as_handled()
		_on_open_panel("wanted", {})
		return
	var map := {"inventory": "inventory", "panel_hirelings": "hirelings", "panel_skills": "skills",
		"panel_adventurers": "adventurers", "panel_orders": "orders", "cancel": "pause"}
	for action in map:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_on_open_panel(map[action], {})
			return
	if event.is_action_pressed("panel_map"):
		get_viewport().set_input_as_handled()
		_on_open_panel("map", {})
	elif event.is_action_pressed("panel_help"):
		get_viewport().set_input_as_handled()
		_on_open_panel("help", {})
	elif event.is_action_pressed("panel_ledger"):
		_on_open_panel("shop", {"tab": "ledger"})
	elif event.is_action_pressed("quick_save"):
		if Saves.save("quicksave"):
			toast("Quick-saved.", "good")
	elif event.is_action_pressed("quick_load"):
		if Saves.exists("quicksave"):
			get_tree().root.get_node("Main").call("load_slot", "quicksave")
