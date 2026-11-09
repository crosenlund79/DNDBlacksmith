## Saves — versioned persistence with multiple slots.
## EN: Slots: slot_1..slot_3, autosave, quicksave → user://saves/<slot>.json.
##     Each file holds {meta, data}. A save is written to <slot>.json.tmp, read back and parsed (verified), the
##     previous good file is copied to <slot>.bak, and only then is the temp file renamed over <slot>.json. Every
##     file operation is checked: on any failure the previous good file (and its .bak) stay untouched, save()
##     returns false, logs an error and shows a toast. A corrupt or truncated slot falls back to its .bak.
##     `migrate()` upgrades older schemas through the explicit, ordered steps in SaveMigrations.
##     JSON turns integers into floats, so integral floats are converted back on load.
##     Tests: any scene under res://tests/ runs in TEST MODE — saves go to a private folder per run
##     (user://test_saves/run_<unix>_<pid>/, removed by end_test_run(); run folders older than a day are swept) and
##     path() refuses the real save folder, so automated runs can never touch a player's saves.
## DA: Pladser: slot_1..slot_3, autosave, quicksave. Der skrives til en midlertidig fil, som læses tilbage og
##     kontrolleres; den forrige fil gemmes som .bak, og først derefter omdøbes den nye fil. Alle filoperationer
##     tjekkes; ved fejl bevares den forrige fil. En ødelagt fil indlæses fra .bak. Ældre gemte spil opgraderes
##     trin for trin (SaveMigrations). Tests bruger deres egen mappe pr. kørsel og kan aldrig røre rigtige gemte spil.
extends Node

const DIR := "user://saves/"
const TEST_ROOT := "user://test_saves/"
const STALE_RUN_SECONDS := 86400
## Where saves go. In test mode this is the run's private folder (or a sub-folder of it).
var dir := DIR
const SLOTS := ["slot_1", "slot_2", "slot_3", "autosave", "quicksave"]
## True for automated tests: path() then refuses the real save folder.
var test_mode := false
## This test run's folder name under TEST_ROOT ("" outside test mode).
var run_id := ""
## Why the last save()/load_slot() failed ("" after a success).
var last_error := ""
## What the last load_slot() did: {"slot", "from_backup": bool, "migration": SaveMigrations report}.
var last_load := {}

# keys whose values must stay floats even when integral
const FLOAT_KEYS := ["quality", "precision", "aff", "fam", "power", "progress", "alloc_progress", "x", "y"]


func _ready() -> void:
	if launched_from_tests():
		use_test_dir()
	else:
		DirAccess.make_dir_recursive_absolute(dir)


## Was this process started on a scene or script under res://tests/ (the suite, unit tests, play-tests, soak)?
static func launched_from_tests() -> bool:
	for a in OS.get_cmdline_args():
		if str(a).begins_with("res://tests/"):
			return true
	return false


# ------------------------------------------------------------------ test isolation
## Test mode: every save/load goes to this run's own folder user://test_saves/run_<unix>_<pid>/ (created fresh),
## so parallel runs never share files and real saves are never touched. Idempotent within a run. Also sweeps
## run folders older than a day and loose files left by the old shared layout.
func use_test_dir() -> void:
	test_mode = true
	if run_id == "":
		run_id = "run_%d_%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
		_sweep_stale_runs()
	dir = TEST_ROOT + run_id + "/"
	DirAccess.make_dir_recursive_absolute(dir)


## End of a test run: removes the run's folder (the process is about to quit; test mode stays on).
func end_test_run() -> void:
	if run_id == "":
		return
	_remove_tree(TEST_ROOT + run_id)
	dir = TEST_ROOT + run_id + "/"


func _sweep_stale_runs() -> void:
	var d := DirAccess.open(TEST_ROOT)
	if d == null:
		return
	var now := int(Time.get_unix_time_from_system())
	for f in d.get_files():   # the pre-A1 shared layout kept test files directly in user://test_saves/
		if now - int(FileAccess.get_modified_time(TEST_ROOT + f)) > STALE_RUN_SECONDS:
			d.remove(f)
	for sub in d.get_directories():
		var parts := str(sub).split("_")
		if parts.size() == 3 and parts[0] == "run" and parts[1].is_valid_int() and now - int(parts[1]) > STALE_RUN_SECONDS:
			_remove_tree(TEST_ROOT + sub)


static func _remove_tree(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_remove_tree(p.path_join(sub))
	DirAccess.remove_absolute(p)


static func _norm(p: String) -> String:
	return ProjectSettings.globalize_path(p).simplify_path().trim_suffix("/") + "/"


## Is `p` the real save folder (or inside it)?
static func is_real_dir(p: String) -> bool:
	return _norm(p).begins_with(_norm(DIR))


# ------------------------------------------------------------------ paths
## The slot's file. In test mode the real save folder is refused: returns "" (every caller then fails cleanly).
func path(slot: String) -> String:
	if test_mode and is_real_dir(dir):
		Log.error("Saves: test mode refuses the real save folder (%s) — call use_test_dir()" % dir)
		return ""
	return dir + slot + ".json"


func _bak(p: String) -> String:
	return p.trim_suffix(".json") + ".bak"


func exists(slot: String) -> bool:
	var p := path(slot)
	return p != "" and FileAccess.file_exists(p)


func meta(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var doc := _read_doc(path(slot))
	var m: Variant = doc.get("meta", {})
	return m if m is Dictionary else {}


func latest_slot() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var m := meta(s)
		if m.has("saved_unix") and float(m["saved_unix"]) > best_t:
			best_t = float(m["saved_unix"])
			best = s
	return best


# ------------------------------------------------------------------ writing
## Writes the game to a slot: temp file → verify → previous file to .bak → rename. Returns false (and logs, and
## toasts) on any failure, leaving the previous good file and its .bak in place.
func save(slot: String) -> bool:
	last_error = ""
	if Game.state.is_empty():
		return _fail("there is no game to save")
	var p := path(slot)
	if p == "":
		return _fail("the save folder is not allowed here")
	var mk := DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	if mk != OK and not DirAccess.dir_exists_absolute(p.get_base_dir()):
		return _fail("cannot create the save folder %s (error %d)" % [p.get_base_dir(), mk])
	var data := Game.to_save()
	var doc := {
		"meta": {"version": Game.SAVE_VERSION, "slot": slot, "day": Game.day(), "time": Game.time_string(),
			"gold": Game.gold(), "saved_unix": Time.get_unix_time_from_system(), "seed": int(Game.state.get("world_seed", -1)),
			"saved_at": Time.get_datetime_string_from_system(false, true)},
		"data": data,
	}
	var text := JSON.stringify(doc)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
	f.store_string(text)
	var werr := f.get_error()
	f.close()
	# verify: the temp file must read back exactly and parse as a save
	if werr != OK or FileAccess.get_file_as_string(tmp) != text or _read_doc(tmp).is_empty():
		DirAccess.remove_absolute(tmp)
		return _fail("the written save %s did not verify (error %d)" % [tmp, werr])
	# rotate: the previous good file becomes the backup (the main file stays in place until the rename)
	var bak := _bak(p)
	if FileAccess.file_exists(p):
		var cerr := DirAccess.copy_absolute(p, bak)
		if cerr != OK:
			DirAccess.remove_absolute(tmp)
			return _fail("cannot back up %s to %s (error %d)" % [p, bak, cerr])
	var rerr := DirAccess.rename_absolute(tmp, p)
	if rerr != OK and FileAccess.file_exists(p):
		# some platforms will not rename over an existing file: the backup is safe, so replace explicitly
		var del := DirAccess.remove_absolute(p)
		rerr = DirAccess.rename_absolute(tmp, p) if del == OK else del
		if rerr != OK and not FileAccess.file_exists(p) and FileAccess.file_exists(bak):
			DirAccess.copy_absolute(bak, p)   # put the previous good file back
	if rerr != OK:
		DirAccess.remove_absolute(tmp)
		return _fail("cannot move the new save into place at %s (error %d)" % [p, rerr])
	Log.info("Saved %s (day %d)" % [slot, Game.day()])
	return true


func _fail(why: String) -> bool:
	last_error = why
	Log.error("Save failed: " + why)
	Events.toast.emit("Could not save the game: %s." % why, "bad")
	return false


# ------------------------------------------------------------------ loading
## Loads a slot (falling back to its .bak when the main file is missing, corrupt or truncated), restores
## integers, runs the schema migrations and hands the state to Game. False if neither file is usable.
func load_slot(slot: String) -> bool:
	last_error = ""
	last_load = {"slot": slot, "from_backup": false, "migration": {}}
	var p := path(slot)
	if p == "":
		last_error = "the save folder is not allowed here"
		return false
	var data := _read(p)
	if data.is_empty():
		var bak := _bak(p)
		if FileAccess.file_exists(p):
			Log.warn("Save %s is corrupt or unreadable — trying its backup %s" % [p, bak])
		elif FileAccess.file_exists(bak):
			Log.warn("Save %s is missing — trying its backup %s" % [p, bak])
		data = _read(bak)
		if data.is_empty():
			last_error = "no readable save in slot %s" % slot
			if FileAccess.file_exists(p) or FileAccess.file_exists(bak):
				Log.error("Could not load %s: neither the save nor its backup is readable" % slot)
			else:
				Log.warn("No save in slot %s" % slot)
			return false
		last_load["from_backup"] = true
		Log.warn("Loaded the backup of %s" % slot)
	data = _restore_ints(data)
	last_load["migration"] = SaveMigrations.run(data)
	Game.from_save(data)
	Log.info("Loaded %s (day %d)" % [slot, Game.day()])
	return true


## The whole {meta, data} document of a file ({} when missing or not a valid save).
func _read_doc(p: String) -> Dictionary:
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		Log.warn("Cannot open %s (error %d)" % [p, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		Log.warn("%s is not valid JSON (line %d: %s)" % [p, json.get_error_line(), json.get_error_message()])
		return {}
	var doc: Variant = json.data
	if doc is Dictionary and (doc as Dictionary).get("data") is Dictionary:
		return doc
	Log.warn("%s is not a save file" % p)
	return {}


func _read(p: String) -> Dictionary:
	var doc := _read_doc(p)
	return doc["data"] if not doc.is_empty() else {}


func _restore_ints(v: Variant, key := "") -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _restore_ints(v[k], str(k))
		return out
	if v is Array:
		var arr := []
		for e in v:
			arr.append(_restore_ints(e, key))
		return arr
	if v is float and not FLOAT_KEYS.has(key) and is_equal_approx(v, round(v)) and abs(v) < 1e12:
		return int(v)
	return v


## Upgrades older saves through the explicit, ordered schema steps (SaveMigrations); a save from a newer build
## loads best-effort with a warning. Returns the same dictionary, converted in place.
func migrate(data: Dictionary) -> Dictionary:
	SaveMigrations.run(data)
	return data


func delete(slot: String) -> void:
	var p := path(slot)
	if p == "":
		return
	for q in [p, _bak(p), p + ".tmp"]:
		if FileAccess.file_exists(q):
			DirAccess.remove_absolute(q)
