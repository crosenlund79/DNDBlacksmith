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
	if OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_args().has("--smoke-test"):
		_smoke_test()


## Packaged-build self-check (used by the installer CI): start a new game, let the world run a few
## seconds, then report data, sprites and errors to stdout and user://smoke_test.txt and quit (0 = ok).
func _smoke_test() -> void:
	await get_tree().create_timer(1.0).timeout
	new_game("journeyman")
	await get_tree().create_timer(5.0).timeout
	Game.advance_minutes(120)
	await get_tree().create_timer(1.0).timeout
	var ui_ok := is_instance_valid(ui) and ui.get_script() != null and ui.get("hud") != null
	var ok := DB.items.size() > 50 and DB.recipes.size() > 30 and is_instance_valid(world) and ui_ok and Assets.missing.size() < 5 and Log.error_count == 0
	var report := "SMOKE %s items=%d recipes=%d stations=%d missing_sprites=%d %s ui=%s log_errors=%d version=%s" % ["OK" if ok else "FAIL",
		DB.items.size(), DB.recipes.size(), DB.stations.size(), Assets.missing.size(), str(Assets.missing.slice(0, 5)), str(ui_ok), Log.error_count,
		Engine.get_version_info().get("string", "")]
	print(report)
	var f := FileAccess.open("user://smoke_test.txt", FileAccess.WRITE)
	if f:
		f.store_string(report + "\n")
		f.close()
	get_tree().quit(0 if ok else 1)


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


## Rebuild the village after the smith bought rooms or rearranged the workshop (state is kept; the player
## stays where he stood).
func rebuild_world() -> void:
	_start_world()


func continue_game() -> void:
	var s := Saves.latest_slot()
	if s != "":
		load_slot(s)


func load_slot(slot: String) -> void:
	# a save from a newer build is refused BEFORE anything is torn down: a running game keeps going untouched,
	# the menu shows why (Saves.load_slot explains, keeps the file and sets Saves.notice)
	if Saves.newer_schema(slot) > 0:
		Saves.load_slot(slot)
		if world == null:
			to_menu()
		else:
			Saves.notice = ""   # already shown in the running game as a toast
		return
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
