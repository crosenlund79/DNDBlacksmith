## SettingsPanel — audio buses, display, dice mode, hints and time speed.
## DA: Lydbusser, skærm, terningetilstand, hjælpetekster og tidshastighed.
class_name SettingsPanel
extends UIWindow


func _init() -> void:
	super._init("Settings", 860, 720)
	blocks_time = true


func _ready() -> void:
	super._ready()
	for s in [["audio/master", "Master volume"], ["audio/music", "Music"], ["audio/sfx", "Sound effects"], ["audio/ambience", "Ambience"], ["audio/ui", "Interface sounds"]]:
		var row := UIKit.hbox()
		var lab := UIKit.label(s[1], 22)
		lab.custom_minimum_size = Vector2(260, 0)
		row.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Settings.get_value(s[0], 0.8))
		sl.custom_minimum_size = Vector2(400, 28)
		var key: String = s[0]
		sl.value_changed.connect(func(v): Settings.set_value(key, v))
		row.add_child(sl)
		content.add_child(row)
	for t in [["display/fullscreen", "Fullscreen"], ["display/vsync", "V-Sync"], ["gameplay/show_hints", "Show objective hints"]]:
		var cb := CheckBox.new()
		cb.text = t[1]
		cb.button_pressed = bool(Settings.get_value(t[0], false))
		var k2: String = t[0]
		cb.toggled.connect(func(on): Settings.set_value(k2, on))
		content.add_child(cb)
	var dm := UIKit.hbox()
	dm.add_child(UIKit.label("Dice:", 22))
	var ob := OptionButton.new()
	ob.add_item("Digital dice (automatic)")
	ob.add_item("Physical dice (enter your rolls)")
	ob.selected = 1 if Settings.get_value("gameplay/dice_mode", "auto") == "physical" else 0
	ob.item_selected.connect(func(i): Settings.set_value("gameplay/dice_mode", "physical" if i == 1 else "auto"))
	dm.add_child(ob)
	content.add_child(dm)
	var ts := UIKit.hbox()
	ts.add_child(UIKit.label("Day length:", 22))
	var ob2 := OptionButton.new()
	for p in [["Leisurely (×0.5)", 0.5], ["Normal (≈15 min)", 1.0], ["Brisk (×2)", 2.0]]:
		ob2.add_item(p[0])
	var cur := float(Settings.get_value("gameplay/time_scale", 1.0))
	ob2.selected = 0 if cur < 0.9 else (2 if cur > 1.5 else 1)
	ob2.item_selected.connect(func(i): Settings.set_value("gameplay/time_scale", [0.5, 1.0, 2.0][i]))
	ts.add_child(ob2)
	content.add_child(ts)
	content.add_child(UIKit.label("Controls: WASD/arrows move, Shift run, E/Space interact, I inventory, H hirelings, K skills, J adventurers, O orders, L ledger, F5/F9 quick save/load, F3 diagnostics.", 18, "body_italic"))
