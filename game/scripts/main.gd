## Main — top-level state machine: main menu ⇄ playing (world + UI).
## DA: Øverste tilstandsmaskine: hovedmenu ⇄ spil (verden + brugerflade).
extends Node

var world: VillageWorld
var ui: UIRoot
var menu: Control
var menu_layer: CanvasLayer


func _ready() -> void:
	get_tree().root.theme = Assets.theme
	to_menu()


func _clear() -> void:
	Game.running = false
	Game.ui_blockers = 0
	for n in [world, ui, menu, menu_layer]:
		if is_instance_valid(n):
			# stop the old world/UI at once: it stays in the tree until the end of the frame and
			# would otherwise keep writing player pos/area into a freshly loaded state
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.queue_free()
	world = null
	ui = null
	menu = null
	menu_layer = null


func to_menu() -> void:
	_clear()
	# Controls need a CanvasLayer (or Control) parent for full-rect anchors to resolve
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	menu = MainMenu.new()
	menu.main = self
	menu_layer.add_child(menu)
	Audio.play_music("music/title")
	Audio.set_ambience("bed", "")


func new_game(difficulty := "journeyman") -> void:
	Game.new_game(difficulty)
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
	Game.paused = false
	Game.speed = 1
	Game.running = true
	Events.objective_changed.emit(Objectives.text())
	Log.info("World started on day %d" % Game.day())
