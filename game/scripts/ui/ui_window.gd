## UIWindow — a parchment window with a title, close button and content area.
## EN: While open it blocks the clock and player movement; Esc closes it.
## DA: Mens vinduet er åbent, står tiden og spilleren stille; Esc lukker det.
class_name UIWindow
extends PanelContainer

signal closed

var content: VBoxContainer
var title_label: Label
var blocks_time := true
var _blocked := false
var _counted := false


func _init(title_text := "", w := 900.0, h := 640.0, dark := false) -> void:
	theme = Assets.theme
	add_theme_stylebox_override("panel", Assets.panel_style("dark" if dark else "parchment"))
	custom_minimum_size = Vector2(w, h)
	var root := UIKit.vbox(8)
	add_child(root)
	var head := UIKit.hbox()
	title_label = UIKit.title(title_text, 38)
	if dark:
		title_label.add_theme_color_override("font_color", UIKit.PAPER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(UIKit.button("✕", close, 46))
	root.add_child(head)
	root.add_child(UIKit.divider())
	content = UIKit.vbox(10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)


func _ready() -> void:
	# grow both ways so the window stays centred when its content outgrows the minimum size
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	Game.ui_open += 1
	_counted = true
	if blocks_time:
		Game.block_time(true)
		_blocked = true
	Audio.play("sfx/page_turn", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _blocked:
		Game.block_time(false)
		_blocked = false
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if _counted:
		Game.ui_open = maxi(0, Game.ui_open - 1)
		_counted = false
	if _blocked:
		Game.block_time(false)
		_blocked = false
