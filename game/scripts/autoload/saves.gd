## Saves — versioned persistence with multiple slots.
## EN: Slots: slot_1..slot_3, autosave, quicksave → user://saves/<slot>.json.
##     Each file holds {meta, data}. Writes are atomic (temp file + rename) and the previous file
##     is kept as <slot>.bak for recovery. `migrate()` upgrades older save versions step by step.
##     JSON turns integers into floats, so integral floats are converted back on load.
## DA: Pladser: slot_1..slot_3, autosave, quicksave. Skrivning sker atomisk (midlertidig fil +
##     omdøbning), og den forrige fil gemmes som .bak. `migrate()` opgraderer ældre gemte spil
##     trin for trin. Heltal, der er blevet til decimaltal i JSON, konverteres tilbage.
extends Node

const DIR := "user://saves/"
## Where saves go. Tests point this at a scratch folder (use_test_dir) so they never touch real saves.
var dir := DIR
const SLOTS := ["slot_1", "slot_2", "slot_3", "autosave", "quicksave"]

# keys whose values must stay floats even when integral
const FLOAT_KEYS := ["quality", "precision", "aff", "fam", "power", "progress", "alloc_progress", "x", "y"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)


## Redirects every save/load to user://test_saves/ (cleared first) — for automated tests.
func use_test_dir() -> void:
	dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute(dir)
	var d := DirAccess.open(dir)
	if d:
		for f in d.get_files():
			d.remove(f)


func path(slot: String) -> String:
	return dir + slot + ".json"


func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


func meta(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		return d.get("meta", {})
	return {}


func latest_slot() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var m := meta(s)
		if m.has("saved_unix") and float(m["saved_unix"]) > best_t:
			best_t = float(m["saved_unix"])
			best = s
	return best


func save(slot: String) -> bool:
	if Game.state.is_empty():
		return false
	var data := Game.to_save()
	var doc := {
		"meta": {"version": Game.SAVE_VERSION, "slot": slot, "day": Game.day(), "time": Game.time_string(),
			"gold": Game.gold(), "saved_unix": Time.get_unix_time_from_system(),
			"saved_at": Time.get_datetime_string_from_system(false, true)},
		"data": data,
	}
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Log.error("Cannot write save " + tmp)
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	if exists(slot):
		DirAccess.copy_absolute(path(slot), dir + slot + ".bak")
		DirAccess.remove_absolute(path(slot))
	DirAccess.rename_absolute(tmp, path(slot))
	Log.info("Saved %s (day %d)" % [slot, Game.day()])
	return true


func load_slot(slot: String) -> bool:
	var data := _read(path(slot))
	if data.is_empty():
		Log.warn("Save %s unreadable — trying backup" % slot)
		data = _read(dir + slot + ".bak")
	if data.is_empty():
		return false
	data = _restore_ints(data)
	data = migrate(data)
	Game.from_save(data)
	Log.info("Loaded %s (day %d)" % [slot, Game.day()])
	return true


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var doc: Variant = JSON.parse_string(f.get_as_text())
	if doc is Dictionary and doc.has("data"):
		return doc["data"]
	return {}


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


## Upgrades older saves one version at a time. Add a branch per future format change.
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v < 1:
		# v0 → v1: early prototypes lacked these containers
		for key in ["returns", "customers", "orders"]:
			if not data.has(key):
				data[key] = []
		data["version"] = 1
		v = 1
	if v > Game.SAVE_VERSION:
		Log.warn("Save is from a newer version (%d); loading best-effort" % v)
	# The Living Realm: cloaks have their own slot; old saves wore them in the amulet's (idempotent, any version)
	var cloaks := Items.migrate_cloak_slots(data)
	if cloaks > 0:
		Log.info("Moved %d cloak(s) from the amulet slot to the cloak slot" % cloaks)
	return data


func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))
