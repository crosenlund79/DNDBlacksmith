## Log — diagnostics and logging.
## EN: Levelled logging to the console, a ring buffer for the in-game diagnostics overlay (F3)
##     and a rotating log file at user://logs/ember_ash.log.
## DA: Logning med niveauer til konsollen, en ringbuffer til diagnose-overlayet i spillet (F3)
##     og en roterende logfil i user://logs/ember_ash.log.
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }
const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR"]
const MAX_LINES := 200

var min_level: int = Level.DEBUG
var lines: Array[String] = []
var error_count := 0
var _file: FileAccess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path := "user://logs/ember_ash.log"
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, "user://logs/ember_ash.prev.log")
	_file = FileAccess.open(path, FileAccess.WRITE)
	info("Ember & Ash starting — Godot %s" % Engine.get_version_info().get("string", "?"))


func _write(level: int, msg: String) -> void:
	if level < min_level:
		return
	var t := Time.get_time_string_from_system()
	var line := "[%s] %s: %s" % [t, LEVEL_NAMES[level], msg]
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	if level >= Level.ERROR:
		error_count += 1
		push_error(msg)
	elif level == Level.WARN:
		push_warning(msg)
	print(line)
	if _file:
		_file.store_line(line)
		_file.flush()


func debug(msg: String) -> void:
	_write(Level.DEBUG, msg)


func info(msg: String) -> void:
	_write(Level.INFO, msg)


func warn(msg: String) -> void:
	_write(Level.WARN, msg)


func error(msg: String) -> void:
	_write(Level.ERROR, msg)
