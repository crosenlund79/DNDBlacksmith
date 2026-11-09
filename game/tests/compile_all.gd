## Startup regression test: loads every GDScript in the project (with autoloads present) and
## fails if any of them does not compile. Run: godot --headless --path game res://tests/compile_all.tscn
## DA: Indlæser alle GDScript-filer (med autoloads) og fejler, hvis nogen ikke kan kompileres.
extends Node


func _ready() -> void:
	var failed: Array[String] = []
	var count := 0
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		count += 1
		var s: Script = load(path)
		if s == null or not s.can_instantiate() and not (s is GDScript and (s as GDScript).get_global_name() != ""):
			failed.append(path)
	for p in failed:
		print("COMPILE FAIL  ", p)
	print("compile_all: %d scripts, %d failed" % [count, failed.size()])
	Saves.end_test_run()
	get_tree().quit(1 if not failed.is_empty() else 0)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
