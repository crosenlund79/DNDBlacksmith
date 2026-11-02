## Misc panels — sleep, pause menu, save/load slots and settings.
## DA: Diverse paneler — søvn, pausemenu, gemmepladser og indstillinger.
class_name SleepPanel
extends UIWindow


func _init() -> void:
	super._init("Your Bed", 640, 320)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("Sleep until six in the morning? The village carries on without you, and the game is saved.", 22))
	var h := UIKit.hbox()
	h.add_child(UIKit.button("Sleep", func():
		close()
		var hours := (6 - Game.hour() + 24) % 24
		if hours == 0:
			hours = 24
		Events.request_fade.emit("You sleep… the forge ticks as it cools.", hours * 60 - Game.state["minute"] % 60)
		var t := get_tree().create_timer(2.6)
		t.timeout.connect(Saves.save.bind("autosave"))
		t.timeout.connect(func(): Events.toast.emit("Autosaved.", "good")), 200))
	h.add_child(UIKit.button("Not yet", close, 200))
	content.add_child(h)
