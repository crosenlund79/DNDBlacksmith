## Main — top-level state machine: main menu ⇄ playing (world + UI).
## DA: Øverste tilstandsmaskine: hovedmenu ⇄ spil (verden + brugerflade).
extends Node

var world: VillageWorld
var ui: UIRoot
var menu: Control


func _ready() -> void:
	get_tree().root.theme = Assets.theme
	to_menu()


func _clear() -> void:
	Game.running = false
	Game.ui_blockers = 0
	for n in [world, ui, menu]:
		if is_instance_valid(n):
			n.queue_free()
	world = null
	ui = null
	menu = null


func to_menu() -> void:
	_clear()
	menu = MainMenu.new()
	add_child(menu)
	Audio.play_music("music/title")
	Audio.set_ambience("bed", "")


func new_game() -> void:
	Game.new_game()
	_start_world()


func continue_game() -> void:
	var s := Saves.latest_slot()
	if s != "":
		load_slot(s)


func load_slot(slot: String) -> void:
	_clear()
	if Saves.load_slot(slot):
		_start_world()
	else:
		Log.error("Could not load " + slot)
		to_menu()


func _start_world() -> void:
	_clear()
	world = VillageWorld.new()
	add_child(world)
	ui = UIRoot.new()
	add_child(ui)
	Game.ui_blockers = 0
	Game.running = true
	Events.objective_changed.emit(Objectives.text())
	Log.info("World started on day %d" % Game.day())
