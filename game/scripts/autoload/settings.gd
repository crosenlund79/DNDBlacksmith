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
	"gameplay/check_assist": false,           # skill checks at tutorial difficulty (wider zones, slower)
	"gameplay/check_tutorials_seen": [],      # mechanics whose how-to card the player has dismissed
	"gameplay/click_to_move": true,           # left-click the ground, an object or a person to walk there
	"gameplay/item_voices": true,             # awakened pieces now and then speak while worked on (ItemSpirit)
	"gameplay/item_voice_freq": "normal",     # normal | rare
	"gameplay/auto_walk": false,              # S2: after a skill check, walk to the recipe's next station (only walks)
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
	"panel_map": [KEY_M],
	"panel_help": [KEY_F1],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"debug_overlay": [KEY_F3],
	"dev_panel": [KEY_F10],
	"run": [KEY_SHIFT],
	"panel_wanted": [KEY_B],
	"time_pause": [KEY_P],
	"time_faster": [KEY_EQUAL, KEY_KP_ADD],
	"time_slower": [KEY_MINUS, KEY_KP_SUBTRACT],
	"quick_travel": [KEY_T],
	"panel_skill_levels": [KEY_U],
	"panel_world_map": [KEY_G],          # the world map (iteration 011)
	# S2: Y opens what the toolbar's "Workshop" button opens (rooms, stations, furnishings), so the key and the label
	# match; the workshop ledger (apprentices and their work queue, iteration 012) moved from Y to Q ("queue") and stays
	# on that button's right-click
	"panel_property": [KEY_Y],
	"panel_workshop": [KEY_Q],
	"panel_steward": [KEY_N],            # Steward Mode: hand over the forge / the steward at work (Milestone S1)
}

## S2: every shortcut, in the order Help and Settings list them: [action, what it does]. The keys shown come from
## DEFAULT_KEYS through key_label/keys_label, so the lists can never drift from the real bindings.
const HOTKEY_HELP := [
	["interact", "Talk / use / stop a check needle"], ["run", "Hurry"],
	["inventory", "Inventory"], ["panel_skills", "Skill Tree"], ["panel_skill_levels", "Skill levels"],
	["panel_hirelings", "Hirelings"], ["panel_property", "Workshop (rooms, stations, furnishings)"],
	["panel_workshop", "Workshop Ledger (apprentices & work queue)"], ["panel_steward", "Steward"],
	["panel_adventurers", "Adventurers"], ["panel_wanted", "Most Wanted board"], ["panel_orders", "Commissions"],
	["panel_ledger", "Ledger"], ["panel_map", "Map"], ["panel_world_map", "World map"], ["quick_travel", "Quick travel"],
	["time_pause", "Pause time"], ["time_slower", "Slower"], ["time_faster", "Faster"],
	["quick_save", "Quick-save"], ["quick_load", "Quick-load"], ["panel_help", "Help"], ["cancel", "Menu"],
	["debug_overlay", "Diagnostics"],
]
## Readable names for keys whose engine names are long or cryptic.
const KEY_NAMES := {KEY_ESCAPE: "Esc", KEY_EQUAL: "+", KEY_MINUS: "−", KEY_KP_ADD: "Num +", KEY_KP_SUBTRACT: "Num −"}


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
	return key_name(DEFAULT_KEYS[action][0])


## Every key bound to an action, e.g. "I / Tab" ("?" when unbound).
func keys_label(action: String, sep := " / ") -> String:
	if not DEFAULT_KEYS.has(action):
		return "?"
	return sep.join(PackedStringArray((DEFAULT_KEYS[action] as Array).map(func(k): return key_name(int(k)))))


func key_name(code: int) -> String:
	return str(KEY_NAMES.get(code, OS.get_keycode_string(code)))


## S2: the shortcut list as "[b]key[/b] what · …" (bbcode) or "key what, …" (plain) — Help and Settings show this.
func controls_text(bbcode := true) -> String:
	var parts := PackedStringArray()
	for h in HOTKEY_HELP:
		var k := keys_label(str(h[0]), "/")
		parts.append(("[b]%s[/b] %s" if bbcode else "%s %s") % [k, str(h[1])])
	return (" · " if bbcode else ", ").join(parts)
