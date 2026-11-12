## The permanent regression & progression suite.
##   godot --headless --path game res://tests/suite/suite.tscn -- [smoke|quick|full] [<case>...]
##   quick = full minus the long-running tests a case lists in `const SLOW := [...]` (named in the report as omitted).
##   <case> runs one whole case (`t_property`); <case>.<test> runs one test of it (`t_saves.step_registry`, the name as
##   the report prints it, with or without `test_`). A selector that matches no case or test is reported as a FAIL.
## EN: Discovers tests/suite/cases/*.gd (SuiteCase subclasses), runs every test_* method from a fresh seeded game,
##     with saves redirected to this run's own folder user://test_saves/run_<unix>_<pid>/ (real saves are never touched). Prints PASS / FAIL / SKIPPED with
##     diagnostics and writes user://logs/suite_report.txt. Exit code 0 = no failures.
## DA: Den permanente testsuite: smoke (hurtig) eller full; rigtige gemte spil røres aldrig.
extends Node

const CASES_DIR := "res://tests/suite/cases"

var lines: Array[String] = []
var n_pass := 0
var n_fail := 0
var n_skip := 0
var omitted: Array[String] = []   # quick mode: the SLOW tests not run


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "full"
	var only: Array[String] = []
	for a in args:
		if a in ["smoke", "quick", "full"]:
			mode = a
		else:
			only.append(a)
	Saves.use_test_dir()
	var t0 := Time.get_ticks_msec()
	var picked := ""
	if not only.is_empty():
		picked = (" (" + ", ".join(only) + ")") if only.size() <= 6 else " (%d selectors)" % only.size()
	_out("Ember & Ash test suite — %s%s" % [mode, picked])
	# selectors: "t_case" (the whole case, "*") or "t_case.test" (one test)
	var want := {}
	for sel in only:
		var parts := sel.split(".", true, 1)
		if not want.has(parts[0]):
			want[parts[0]] = []
		(want[parts[0]] as Array).append("*" if parts.size() == 1 else (parts[1] if parts[1].begins_with("test_") else "test_" + parts[1]))
	var matched := {}   # selector → true once it has picked a case or test
	for path in _case_files():
		var cname := path.get_file().get_basename()
		if not only.is_empty() and not want.has(cname):
			continue
		var picks: Array = want.get(cname, ["*"])
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			_result("FAIL", cname, "load", ["the case script does not compile"])
			for m in picks:   # the selector found its case (reported above), not an unknown one
				matched[cname if m == "*" else "%s.%s" % [cname, m]] = true
			continue
		var smoke: Array = script.get_script_constant_map().get("SMOKE", [])
		var slow: Array = script.get_script_constant_map().get("SLOW", [])
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			if not picks.has("*"):
				if not picks.has(mname):
					continue
				matched["%s.%s" % [cname, mname]] = true
			else:
				matched[cname] = true
			if mode == "smoke" and not smoke.has(mname):
				continue
			if mode == "quick" and slow.has(mname):
				omitted.append("%s.%s" % [cname, mname.substr(5)])
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
	for c in want:
		for m in (want[c] as Array):
			var key: String = str(c) if m == "*" else "%s.%s" % [c, m]
			if not matched.has(key):
				_result("FAIL", str(c), str(m) if m != "*" else "test_(case)", ["unknown selector: no such suite case or test"])
	_out("")
	if mode == "quick":
		_out("Omitted in quick mode (const SLOW): %d — %s" % [omitted.size(), ", ".join(omitted) if not omitted.is_empty() else "none"])
	_out("%d passed, %d failed, %d skipped — %.1f s" % [n_pass, n_fail, n_skip, (Time.get_ticks_msec() - t0) / 1000.0])
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open("user://logs/suite_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
	Saves.end_test_run()
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
