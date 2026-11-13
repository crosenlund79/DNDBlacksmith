## PausePanel — the in-game menu.
## DA: Menuen i spillet.
class_name PausePanel
extends UIWindow


func _init() -> void:
	super._init("Ember & Ash", 520, 820)


func _ready() -> void:
	super._ready()
	for e in [["Resume", close], ["Save game", func(): Events.open_panel.emit("saves", {"mode": "save"})],
			["Load game", func(): Events.open_panel.emit("saves", {"mode": "load"})],
			["Appearance", func(): Events.open_panel.emit("customize", {})],
			["Settings", func(): Events.open_panel.emit("settings", {})],
			["Difficulty — %s" % str(Expeditions.diff().get("name", "")), func(): Events.open_panel.emit("difficulty", {})],
			["Developer tools (F10) — testing only", func(): close(); Events.open_panel.emit.call_deferred("dev_panel", {})],
			["Return to main menu", func(): close(); get_tree().root.get_node("Main").call("to_menu")],
			["Quit", func(): get_tree().quit()]]:
		content.add_child(UIKit.button(e[0], e[1], 420))
