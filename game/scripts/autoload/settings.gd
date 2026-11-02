## Settings — persistent options and input map.
## EN: Stores settings in user://settings.cfg, applies display options and defines the input
##     actions at runtime (so they can be rebound without editing project.godot).
## DA: Gemmer indstillinger i user://settings.cfg, anvender skærmindstillinger og definerer
##     input-handlinger ved kørsel (så de kan omdefineres uden at redigere project.godot).
extends Node

const PATH := "user://settings.cfg"

var values := {
	"audio/master": 0.9,
	"audio/music": 0.6,
	"audio/sfx": 0.85,
	"audio/ambience": 0.6,
	"audio/ui": 0.7,
	"display/fullscreen": false,
	"display/vsync": true,
	"gameplay/dice_mode": "auto",     # auto | physical
	"gameplay/show_hints": true,
	"gameplay/time_scale": 1.0,
	"debug/overlay": false,
}

# action -> list of keycodes (first is primary)
const DEFAULT_KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_SPACE],
	"cancel": [KEY_ESCAPE],
	"inventory": [KEY_I, KEY_TAB],
	"panel_hirelings": [KEY_H],
	"panel_skills": [KEY_K],
	"panel_adventurers": [KEY_J],
	"panel_ledger": [KEY_L],
	"panel_orders": [KEY_O],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"debug_overlay": [KEY_F3],
	"run": [KEY_SHIFT],
}


func _ready() -> void:
	_setup_input()
	load_settings()
	apply_display()


func _setup_input() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in DEFAULT_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# gamepad basics
	_add_joy("interact", JOY_BUTTON_A)
	_add_joy("cancel", JOY_BUTTON_B)
	_add_joy("inventory", JOY_BUTTON_Y)


func _add_joy(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func get_value(key: String, default: Variant = null) -> Variant:
	return values.get(key, default)


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	if key.begins_with("display/"):
		apply_display()
	if key.begins_with("audio/") and has_node("/root/Audio"):
		get_node("/root/Audio").apply_volumes()
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in values.keys():
		var parts: PackedStringArray = key.split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			values[key] = cfg.get_value(parts[0], parts[1])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		var parts: PackedStringArray = key.split("/")
		cfg.set_value(parts[0], parts[1], values[key])
	cfg.save(PATH)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fs: bool = values["display/fullscreen"]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["display/vsync"] else DisplayServer.VSYNC_DISABLED)


func key_label(action: String) -> String:
	if not DEFAULT_KEYS.has(action):
		return "?"
	return OS.get_keycode_string(DEFAULT_KEYS[action][0])
