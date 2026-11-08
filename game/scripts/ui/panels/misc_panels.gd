## Misc panels — sleep, pause menu, save/load slots and settings.
## DA: Diverse paneler — søvn, pausemenu, gemmepladser og indstillinger.
class_name SleepPanel
extends UIWindow


func _init() -> void:
	super._init("Your Bed", 860, 380)


func _ready() -> void:
	super._ready()
	var row := UIKit.hbox(14)
	row.add_child(UIKit.label("Energy", 22, "body_bold"))
	row.add_child(UIKit.bar(Vitality.energy(), Vitality.MAX, 220))
	row.add_child(UIKit.label("%s — %s" % [Vitality.band(), Vitality.status_text()], 20, "body_italic"))
	content.add_child(row)
	content.add_child(UIKit.label("Sleep until six in the morning? The village carries on without you, and the game is saved.", 22))
	var h := UIKit.hbox()
	h.add_child(UIKit.button("Sleep", func():
		close()
		var hours := (6 - Game.hour() + 24) % 24
		if hours == 0:
			hours = 24
		var mins: int = hours * 60 - Game.state["minute"] % 60
		Vitality.sleep(mins)
		Events.request_fade.emit("You sleep… the forge ticks as it cools.", mins)
		var t := get_tree().create_timer(2.6)
		t.timeout.connect(Saves.save.bind("autosave"))
		t.timeout.connect(func(): Events.toast.emit("Autosaved.", "good")), 200))
	h.add_child(UIKit.button("Rest for an hour", func():
		close()
		Audio.play("sfx/rest", -6.0)
		Vitality.rest(60), 240))
	h.add_child(UIKit.button("Not yet", close, 200))
	content.add_child(h)
