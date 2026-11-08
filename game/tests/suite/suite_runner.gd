## The permanent regression & progression suite.
##   godot --headless --path game res://tests/suite/suite.tscn -- [smoke|full|<case>...]
## EN: Discovers tests/suite/cases/*.gd (SuiteCase subclasses), runs every test_* method from a fresh seeded game,
##     with saves redirected to user://test_saves/ (real saves are never touched). Prints PASS / FAIL / SKIPPED with
##     diagnostics and writes user://logs/suite_report.txt. Exit code 0 = no failures.
## DA: Den permanente testsuite: smoke (hurtig) eller full; rigtige gemte spil røres aldrig.
extends Node

const CASES_DIR := "res://tests/suite/cases"

var lines: Array[String] = []
var n_pass := 0
var n_fail := 0
var n_skip := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "full"
	var only: Array[String] = []
	for a in args:
		if a in ["smoke", "full"]:
			mode = a
		else:
			only.append(a)
	Saves.use_test_dir()
	var t0 := Time.get_ticks_msec()
	_out("Ember & Ash test suite — %s%s" % [mode, (" (" + ", ".join(only) + ")") if not only.is_empty() else ""])
	for path in _case_files():
		var cname := path.get_file().get_basename()
		if not only.is_empty() and not only.has(cname):
			continue
		var script: Script = load(path)
		if script == null:
			_result("FAIL", cname, "load", ["the case script does not compile"])
			continue
		var smoke: Array = script.get_script_constant_map().get("SMOKE", [])
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			if mode == "smoke" and not smoke.has(mname):
				continue
			var inst: SuiteCase = script.new()
			inst.fresh_game()
			var t1 := Time.get_ticks_msec()
			inst.call(mname)   # tests are synchronous by design (drive systems directly, not frames)
			var ms := Time.get_ticks_msec() - t1
			if inst._skipped != "":
				_result("SKIPPED", cname, mname, [inst._skipped], ms)
			elif inst._fails.is_empty():
				_result("PASS", cname, mname, inst._notes, ms, inst._checks)
			else:
				_result("FAIL", cname, mname, inst._fails, ms, inst._checks)
			if Crafting.active():
				Crafting.cancel()
	_out("")
	_out("%d passed, %d failed, %d skipped — %.1f s" % [n_pass, n_fail, n_skip, (Time.get_ticks_msec() - t0) / 1000.0])
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open("user://logs/suite_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
	Saves.dir = Saves.DIR
	get_tree().quit(1 if n_fail > 0 else 0)


func _case_files() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(CASES_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(CASES_DIR.path_join(f))
	out.sort()
	return out


func _result(kind: String, case_name: String, method: String, msgs: Array, ms := 0, checks := 0) -> void:
	match kind:
		"PASS": n_pass += 1
		"FAIL": n_fail += 1
		_: n_skip += 1
	_out("%-7s %s.%s%s" % [kind, case_name, method.substr(5), ("  (%d checks, %d ms)" % [checks, ms]) if kind != "SKIPPED" else ""])
	for m in msgs:
		_out("          %s %s" % ["✗" if kind == "FAIL" else "·", str(m)])


func _out(t: String) -> void:
	lines.append(t)
	print(t)
