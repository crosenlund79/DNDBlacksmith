## DifficultyPanel — choose Apprentice, Journeyman or Master: at a new game, or later from the menu.
## EN: Observation rights, death, enemy strength and economy factors all read the chosen setting live.
## DA: Vælg sværhedsgrad ved nyt spil eller senere fra menuen.
class_name DifficultyPanel
extends UIWindow

var on_pick: Callable
var fresh := false


func _init(picked: Callable = Callable(), new_game := false) -> void:
	on_pick = picked
	fresh = new_game
	super._init("Choose your difficulty" if new_game else "Difficulty", 1100, 640)


func _ready() -> void:
	super._ready()
	var cur := "journeyman" if fresh else Expeditions.diff_id()
	content.add_child(UIKit.rich("[i]How hard the roads are, how money flows — and how much the smith may see of adventurers out in the wilds.%s[/i]" % ("" if fresh else " You can change this at any time; the change applies at once."), 20))
	var row := UIKit.hbox(18)
	var d: Dictionary = DB.expeditions.get("difficulty", {})
	for id: String in ["apprentice", "journeyman", "master"]:
		var e: Dictionary = d.get(id, {})
		var col := UIKit.vbox(8)
		col.custom_minimum_size = Vector2(320, 0)
		col.add_child(UIKit.label(str(e.get("name", id.capitalize())) + ("  ✓" if id == cur and not fresh else ""), 30, "heading", UIKit.RUBRIC if id == cur else UIKit.INK))
		col.add_child(UIKit.rich(str(e.get("desc", "")), 19))
		col.add_child(UIKit.rich("[color=#5e421c]Enemies ×%.2f · death %s · healing ×%.2f\nPrices ×%.2f · wages ×%.2f · loot ×%.2f\nLive observation: %s[/color]" % [float(e.get("enemy", 1)), "possible" if e.get("death", true) else "never",
			float(e.get("heal_rate", 1)), float(e.get("prices", 1)), float(e.get("wages", 1)), float(e.get("loot", 1)), "yes" if e.get("observe", true) else "no"], 17))
		var pick: String = id
		col.add_child(UIKit.button("Begin as %s" % e.get("name", id) if fresh else "Play at %s" % e.get("name", id), func(): _choose(pick), 300))
		row.add_child(col)
	content.add_child(row)


func _choose(id: String) -> void:
	if fresh:
		close()
		if on_pick.is_valid():
			on_pick.call(id)
		return
	Expeditions.set_difficulty(id)
	Events.toast.emit("Difficulty: %s" % str(Expeditions.diff().get("name", id)), "info")
	close()
