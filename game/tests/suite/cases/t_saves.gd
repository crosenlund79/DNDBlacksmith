## Save reliability (Milestone A1 "Protect the Foundation"): explicit, ordered schema migrations (SaveMigrations);
## authentic golden saves written by past releases' own code (tests/fixtures/saves/, see its README) load, migrate
## to the current schema and pass a whole-state integrity check; load → save → load is idempotent over the whole
## state; every migration step is idempotent; a newer-version save loads best-effort; write/replace failures keep
## the previous good file; a corrupt or truncated slot falls back to its .bak; tests save into their own run folder
## and can never touch the player's user://saves/.
extends SuiteCase

const SMOKE := ["test_step_registry", "test_golden_0_14_6", "test_fresh_game_round_trip_idempotent", "test_corrupt_main_falls_back_to_bak",
	"test_test_mode_refuses_real_saves"]
const FIXTURES := "res://tests/fixtures/saves/"
const GOLDEN := ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]
## Top-level keys every save has carried since 0.11 (Game.new_game).
const REQUIRED_KEYS := ["version", "day", "minute", "gold", "next_uid", "ledger", "journal", "flags", "upgrades", "player",
	"hirelings", "applicants", "adventurers", "social", "orders", "customers", "craft", "returns", "world", "objectives",
	"stats", "difficulty", "chronicle", "exp", "offers"]


# ------------------------------------------------------------------ helpers
## Puts a golden save into this run's test folder as `slot` (the file bytes exactly as the old release wrote them).
func _install_golden(name: String, slot: String) -> bool:
	var text := FileAccess.get_file_as_string(FIXTURES + name + ".json")
	if not check(text.length() > 1000, "the golden save %s is present" % name):
		return false
	var f := FileAccess.open(Saves.path(slot), FileAccess.WRITE)
	if not check(f != null, "the golden save can be copied into the test folder"):
		return false
	f.store_string(text)
	f.close()
	return true


func _golden_data(name: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
	if not doc is Dictionary or not (doc as Dictionary).get("data") is Dictionary:
		return {}
	return Saves._restore_ints(doc["data"])


func _snap(v: Variant) -> String:
	return JSON.stringify(v, "", true, true)


func _is_item(d: Dictionary) -> bool:
	return d.has("def") and d.has("stats") and d.has("rarity") and d.has("affixes")


## Whole-state integrity: required keys, well-formed player / inventories / equipment, every item has a uid.
func _integrity(s: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for k in REQUIRED_KEYS:
		if not s.has(k):
			bad.append("missing top-level key '%s'" % k)
	var p: Variant = s.get("player")
	if not p is Dictionary:
		bad.append("player is not a dictionary")
		return bad
	if not (p as Dictionary).get("inventory") is Array:
		bad.append("player.inventory is not a list")
	if not (p as Dictionary).get("equipment") is Dictionary:
		bad.append("player.equipment is not a dictionary")
	if not (p as Dictionary).get("skills") is Dictionary:
		bad.append("player.skills is not a dictionary")
	if int(s.get("next_uid", 0)) < 1:
		bad.append("next_uid is not positive")
	# the people who really wear things: their equipment holds whole items
	var holders: Array = [["player", p]]
	for h in s.get("hirelings", []):
		holders.append(["hireling", h])
	var advs: Variant = s.get("adventurers", {})
	if advs is Dictionary:
		for id in advs:
			holders.append(["adventurer " + str(id), advs[id]])
	var appr: Variant = s.get("apprentices", {})
	if appr is Dictionary:
		for a in (appr as Dictionary).get("staff", []):
			holders.append(["apprentice", a])
	for hp in holders:
		if not hp[1] is Dictionary:
			bad.append("%s is not a dictionary" % str(hp[0]))
			continue
		var eqv: Variant = (hp[1] as Dictionary).get("equipment")
		if eqv == null:
			continue
		if not eqv is Dictionary:
			bad.append("%s has no equipment dictionary" % str(hp[0]))
			continue
		for slot in eqv:
			var piece: Variant = eqv[slot]
			if not piece is Dictionary or (not (piece as Dictionary).is_empty() and not _is_item(piece)):
				bad.append("%s wears something that is not an item in %s" % [str(hp[0]), str(slot)])
	var counts := {"items": 0, "max_uid": 0}
	_walk(s, "", bad, counts, 0)
	# Game.new_uid() increments first, so next_uid is the last uid issued: no item may carry a higher one
	if int(counts["max_uid"]) > int(s.get("next_uid", 0)):
		bad.append("an item uid (%d) is above the last issued uid (%d)" % [int(counts["max_uid"]), int(s.get("next_uid", 0))])
	return bad


func _walk(v: Variant, where: String, bad: Array[String], counts: Dictionary, depth: int) -> void:
	if depth > 40 or bad.size() > 20:
		return
	if v is Dictionary:
		var d: Dictionary = v
		if _is_item(d):
			counts["items"] = int(counts["items"]) + 1
			if not d.has("uid") or not (d["uid"] is int) or int(d["uid"]) < 1:
				bad.append("an item without a valid uid at %s (%s)" % [where, str(d.get("def", "?"))])
			else:
				counts["max_uid"] = maxi(int(counts["max_uid"]), int(d["uid"]))
			if not d["stats"] is Dictionary:
				bad.append("item %s at %s has malformed stats" % [str(d.get("uid", "?")), where])
		var eq: Variant = d.get("equipment")
		if eq != null:
			if not eq is Dictionary:
				bad.append("equipment at %s is not a dictionary" % where)
			else:
				for slot in eq:
					var piece: Variant = eq[slot]
					if not piece is Dictionary:
						bad.append("equipment slot %s at %s is not a dictionary" % [str(slot), where])
					elif not (piece as Dictionary).is_empty() and not _is_item(piece) and not (piece as Dictionary).get("uid") is int:
						# records (expedition party snapshots) keep uid + a summary; anything else is malformed
						bad.append("equipment slot %s at %s holds neither an item nor a uid record" % [str(slot), where])
		var inv: Variant = d.get("inventory")
		if inv != null and not inv is Array:
			bad.append("inventory at %s is not a list" % where)
		elif inv is Array:
			for it in inv:
				if not it is Dictionary or not _is_item(it):
					bad.append("inventory at %s holds something that is not an item" % where)
					break
		for k in d:
			if d[k] is Dictionary or d[k] is Array:
				_walk(d[k], where + "/" + str(k), bad, counts, depth + 1)
	elif v is Array:
		for e in v:
			if e is Dictionary or e is Array:
				_walk(e, where + "[]", bad, counts, depth + 1)


## Loads `slot`, then save → load twice: the whole state must be identical after each round.
func _round_trips_identical(slot: String, what: String) -> void:
	var s1 := _snap(Game.state)
	if not check(Saves.save(slot + "_r1") and Saves.load_slot(slot + "_r1"), "%s: first save → load" % what):
		return
	var s2 := _snap(Game.state)
	if not check(Saves.save(slot + "_r2") and Saves.load_slot(slot + "_r2"), "%s: second save → load" % what):
		return
	var s3 := _snap(Game.state)
	check(s1 == s2, "%s: the whole state is unchanged by load → save → load (%d vs %d chars)" % [what, s1.length(), s2.length()])
	check(s2 == s3, "%s: and by a second round (%d vs %d chars)" % [what, s2.length(), s3.length()])
	check(Saves.last_load.get("migration", {}).get("steps", ["?"]).is_empty(), "%s: a current save runs no migration steps" % what)
	Saves.delete(slot + "_r1")
	Saves.delete(slot + "_r2")


## The full golden-save check for one release.
func _golden(name: String) -> void:
	var slot := "suite_golden_" + name.replace(".", "_").replace("-", "_")
	if not _install_golden(name, slot):
		return
	var errs := Log.error_count
	if not check(Saves.load_slot(slot), "%s loads" % name):
		return
	var rep: Dictionary = Saves.last_load.get("migration", {})
	eq(int(rep.get("from", -1)), 1, "%s declares schema 1" % name)
	eq(int(rep.get("to", -1)), Game.SAVE_VERSION, "%s is migrated to the current schema" % name)
	eq(int(Game.state.get("version", -1)), Game.SAVE_VERSION, "%s: the state records the new version" % name)
	check(not bool(Saves.last_load.get("from_backup", true)), "%s: read from the main file" % name)
	eq(Log.error_count, errs, "%s: loading and migrating logs no errors" % name)
	var bad := _integrity(Game.state)
	check(bad.is_empty(), "%s: whole-state integrity %s" % [name, str(bad)])
	# the v1 → v2 conversions are done: the lazy converters find nothing left to do
	check(Game.state.has("property") and (Game.state["property"] as Dictionary).has("floors_v"), "%s: the property plan has the Loft's rooms" % name)
	check(Game.state.has("skilltree"), "%s: the skill tree is present" % name)
	var before := _snap(Game.state)
	eq(Items.migrate_cloak_slots(Game.state), 0, "%s: no cloak is left in an amulet slot" % name)
	Property.st()
	SkillTree.ensure()
	check(_snap(Game.state) == before, "%s: after migration, the lazy property / skill-tree / cloak converters change nothing" % name)
	note("%s: day %d, gold %d, %d items, steps %s" % [name, Game.day(), Game.gold(), _count_items(Game.state), str(rep.get("steps", []))])
	# load → save → load is idempotent over the whole state
	_round_trips_identical(slot, name)
	# and the old campaign plays on: a day of simulation runs
	var d0 := Game.day()
	Game.advance_minutes(1440)
	eq(Game.day(), d0 + 1, "%s: a further day of play runs" % name)
	eq(Log.error_count, errs, "%s: no errors logged while playing on" % name)
	Saves.delete(slot)


func _count_items(s: Dictionary) -> int:
	var counts := {"items": 0, "max_uid": 0}
	var bad: Array[String] = []
	_walk(s, "", bad, counts, 0)
	return int(counts["items"])


# ------------------------------------------------------------------ the step registry
func test_step_registry() -> void:
	eq(SaveMigrations.latest(), Game.SAVE_VERSION, "the last migration step produces Game.SAVE_VERSION")
	for i in SaveMigrations.STEPS.size():
		eq(int(SaveMigrations.STEPS[i]["to"]), i + 1, "step %d converts v%d → v%d" % [i, i, i + 1])
		check(str(SaveMigrations.STEPS[i].get("what", "")) != "", "step v%d → v%d documents what it does" % [i, i + 1])
		var probe := {"version": i}
		check(SaveMigrations.apply_step(i + 1, probe), "step v%d → v%d exists" % [i, i + 1])
	check(not SaveMigrations.apply_step(SaveMigrations.latest() + 1, {}), "there is no step beyond the current version")
	# a prototype save (no version) runs every step, in order, and records the version
	var proto := {}
	var rep := SaveMigrations.run(proto)
	eq(int(rep["from"]), 0, "a prototype save starts at v0")
	eq((rep["steps"] as Array).size(), Game.SAVE_VERSION, "every step runs once")
	eq(int(proto.get("version", -1)), Game.SAVE_VERSION, "the version is recorded")
	check(proto.has("returns") and proto.has("customers") and proto.has("orders"), "v0 → v1 adds the early containers")
	eq((SaveMigrations.run(proto)["steps"] as Array).size(), 0, "a current save runs no steps")


# ------------------------------------------------------------------ golden saves from past releases
func test_golden_0_11_2() -> void:
	_golden("build-0.11.2")


func test_golden_0_12_4() -> void:
	_golden("build-0.12.4")


func test_golden_0_13_5() -> void:
	_golden("build-0.13.5")


func test_golden_0_14_6() -> void:
	_golden("build-0.14.6")


func test_golden_provenance_documented() -> void:
	var readme := FileAccess.get_file_as_string(FIXTURES + "README.md")
	for g in GOLDEN:
		check(readme.contains(g + ".json"), "the fixtures README documents %s" % g)
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + g + ".json"))
		check(doc is Dictionary and (doc as Dictionary).has("meta") and int(doc["meta"].get("version", -1)) == 1, "%s is an untouched schema-1 file" % g)


## Each migration step is idempotent: applying it again to its own output changes nothing.
func test_migrations_idempotent_on_golden_saves() -> void:
	for g in GOLDEN:
		var data := _golden_data(g)
		if not check(not data.is_empty(), "%s parses" % g):
			continue
		SaveMigrations.run(data)
		var once := _snap(data)
		for to in range(1, SaveMigrations.latest() + 1):
			SaveMigrations.apply_step(to, data)
			check(_snap(data) == once, "%s: step v%d → v%d run again changes nothing" % [g, to - 1, to])
		eq((SaveMigrations.run(data)["steps"] as Array).size(), 0, "%s: a migrated save runs no further steps" % g)


## The v1 → v2 cloak walk on an authentic old save keeps the same instances.
func test_migration_keeps_item_instances() -> void:
	var data := _golden_data("build-0.13.5")
	if not check(not data.is_empty(), "the 0.13.5 golden save parses"):
		return
	var uids_before := _uids(data)
	SaveMigrations.run(data)
	eq(_uids(data), uids_before, "the migration neither adds nor removes nor renumbers items")


func _uids(s: Dictionary) -> Array:
	var out := []
	_collect_uids(s, out, 0)
	out.sort()
	return out


func _collect_uids(v: Variant, out: Array, depth: int) -> void:
	if depth > 40:
		return
	if v is Dictionary:
		if _is_item(v) and (v as Dictionary).has("uid"):
			out.append(int(v["uid"]))
		for k in v:
			_collect_uids(v[k], out, depth + 1)
	elif v is Array:
		for e in v:
			_collect_uids(e, out, depth + 1)


# ------------------------------------------------------------------ idempotence of a freshly played game
func test_fresh_game_round_trip_idempotent() -> void:
	var it := craft("iron_longsword", 90.0)
	check(not it.is_empty(), "a longsword is forged")
	days(3)
	_round_trips_identical("suite_fresh_rt", "a freshly played game")
	var bad := _integrity(Game.state)
	check(bad.is_empty(), "the fresh game passes the integrity check %s" % str(bad))


# ------------------------------------------------------------------ newer versions
func test_newer_version_loads_best_effort() -> void:
	var day := Game.day()
	check(save_as_version("suite_newer", Game.SAVE_VERSION + 7), "a save from a newer build is written")
	check(Saves.load_slot("suite_newer"), "a newer save loads (best-effort), it does not crash")
	check(bool(Saves.last_load.get("migration", {}).get("newer", false)), "it is reported as newer")
	eq((Saves.last_load.get("migration", {}).get("steps", ["?"]) as Array).size(), 0, "no step is run on it")
	eq(Game.day(), day, "its state is used")
	Saves.delete("suite_newer")


# ------------------------------------------------------------------ write / replace / failure handling
func _bytes(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _bak(slot: String) -> String:
	return Saves.path(slot).trim_suffix(".json") + ".bak"


func test_save_rotates_backup() -> void:
	check(Saves.save("suite_rot"), "first save")
	var first := _bytes(Saves.path("suite_rot"))
	check(not FileAccess.file_exists(_bak("suite_rot")), "no backup after the first save")
	Game.add_gold(7, "test", "rotation")
	check(Saves.save("suite_rot"), "second save")
	eq(_bytes(_bak("suite_rot")), first, "the previous good file became the .bak")
	check(_bytes(Saves.path("suite_rot")) != first, "the main file holds the new save")
	check(not FileAccess.file_exists(Saves.path("suite_rot") + ".tmp"), "no temp file is left behind")
	Saves.delete("suite_rot")
	check(not FileAccess.file_exists(_bak("suite_rot")) and not Saves.exists("suite_rot"), "delete removes the slot and its backup")


func test_corrupt_main_falls_back_to_bak() -> void:
	var gold1 := Game.gold()
	check(Saves.save("suite_corrupt"), "a good save")
	Game.add_gold(50, "test", "second")
	check(Saves.save("suite_corrupt"), "a second save (the first becomes the .bak)")
	var f := FileAccess.open(Saves.path("suite_corrupt"), FileAccess.WRITE)
	f.store_string("{\"meta\": {\"version\": 2}, \"data\": {\"day\": 3, \"gold\"")   # garbage / cut off
	f.close()
	check(Saves.load_slot("suite_corrupt"), "a corrupt main file falls back to the backup")
	check(bool(Saves.last_load.get("from_backup", false)), "the load reports it used the backup")
	eq(Game.gold(), gold1, "the backup's state is loaded")
	Saves.delete("suite_corrupt")


func test_truncated_main_falls_back_to_bak() -> void:
	check(Saves.save("suite_trunc"), "a good save")
	var good := _bytes(Saves.path("suite_trunc"))
	Game.add_gold(5, "test", "second")
	check(Saves.save("suite_trunc"), "a second save")
	var full := _bytes(Saves.path("suite_trunc"))
	var f := FileAccess.open(Saves.path("suite_trunc"), FileAccess.WRITE)
	f.store_string(full.left(full.length() / 2))   # a write cut off half-way
	f.close()
	check(Saves.load_slot("suite_trunc"), "a truncated main file falls back to the backup")
	check(bool(Saves.last_load.get("from_backup", false)), "from the backup")
	eq(_bytes(_bak("suite_trunc")), good, "the backup is the earlier good save")
	Saves.delete("suite_trunc")


func test_corrupt_without_backup_fails_cleanly() -> void:
	check(Saves.save("suite_nobak"), "a single save (no backup yet)")
	var f := FileAccess.open(Saves.path("suite_nobak"), FileAccess.WRITE)
	f.store_string("not json at all")
	f.close()
	var day := Game.day()
	var gold := Game.gold()
	check(not Saves.load_slot("suite_nobak"), "a corrupt save without a backup does not load")
	check(Saves.last_error != "", "the failure is reported (%s)" % Saves.last_error)
	check(Game.day() == day and Game.gold() == gold and not Game.state.is_empty(), "the current game is left as it was")
	Saves.delete("suite_nobak")
	check(not Saves.load_slot("suite_never_written"), "a missing slot fails cleanly")
	check(Saves.meta("suite_never_written").is_empty() and not Saves.exists("suite_never_written"), "and has no metadata")


func test_unwritable_path_keeps_previous_file() -> void:
	check(Saves.save("suite_unw"), "a good save")
	Game.add_gold(9, "test", "next")
	check(Saves.save("suite_unw"), "a second good save (now with a backup)")
	var main := _bytes(Saves.path("suite_unw"))
	var bak := _bytes(_bak("suite_unw"))
	# the temp file cannot be created: a directory stands where it would go
	DirAccess.make_dir_recursive_absolute(Saves.path("suite_unw") + ".tmp")
	Game.add_gold(11, "test", "lost")
	check(not Saves.save("suite_unw"), "save() returns false when the file cannot be written")
	check(Saves.last_error != "", "the reason is reported (%s)" % Saves.last_error)
	eq(_bytes(Saves.path("suite_unw")), main, "the previous good file is untouched")
	eq(_bytes(_bak("suite_unw")), bak, "and so is its backup")
	DirAccess.remove_absolute(Saves.path("suite_unw") + ".tmp")
	# a save folder that cannot exist (a file stands where a folder should be)
	var old_dir := Saves.dir
	var blocker := Saves.dir + "blocker_file"
	var bf := FileAccess.open(blocker, FileAccess.WRITE)
	bf.store_string("x")
	bf.close()
	Saves.dir = blocker + "/sub/"
	check(not Saves.save("suite_unw"), "save() returns false for a folder that cannot be created")
	Saves.dir = old_dir
	DirAccess.remove_absolute(blocker)
	Saves.delete("suite_unw")


func test_interrupted_write_leaves_previous_save() -> void:
	check(Saves.save("suite_intr"), "a good save")
	var gold := Game.gold()
	# a crash mid-write leaves a partial temp file next to the good save
	var f := FileAccess.open(Saves.path("suite_intr") + ".tmp", FileAccess.WRITE)
	f.store_string("{\"meta\": {}, \"data\": {\"gol")
	f.close()
	Game.add_gold(30, "test", "unsaved")
	check(Saves.load_slot("suite_intr"), "the good save still loads")
	check(not bool(Saves.last_load.get("from_backup", true)), "from the main file (the temp file is ignored)")
	eq(Game.gold(), gold, "with the saved state")
	check(Saves.save("suite_intr"), "the next save succeeds over the stale temp file")
	check(not FileAccess.file_exists(Saves.path("suite_intr") + ".tmp"), "and leaves no temp file")
	check(Saves.load_slot("suite_intr") and Game.gold() == gold, "and loads")
	Saves.delete("suite_intr")


# ------------------------------------------------------------------ test isolation
func test_test_mode_refuses_real_saves() -> void:
	check(Saves.test_mode, "the suite runs in test mode")
	check(Saves.run_id.begins_with("run_") and Saves.dir.begins_with(Saves.TEST_ROOT + Saves.run_id), "saves go to this run's own folder (%s)" % Saves.dir)
	check(not Saves.is_real_dir(Saves.dir), "which is not the real save folder")
	var real_before := _listing(Saves.DIR)
	var old_dir := Saves.dir
	Saves.dir = Saves.DIR
	eq(Saves.path("slot_1"), "", "path() refuses the real save folder in test mode")
	check(not Saves.save("slot_1"), "save() refuses it")
	check(not Saves.exists("slot_1") and not Saves.load_slot("slot_1"), "exists()/load_slot() refuse it")
	Saves.dir = "user://saves/../saves/"
	eq(Saves.path("autosave"), "", "also when spelled differently")
	Saves.dir = old_dir
	eq(_listing(Saves.DIR), real_before, "the real save folder is untouched")


func test_stale_run_folders_are_swept() -> void:
	var stale := Saves.TEST_ROOT + "run_1000_4242"
	var fresh := Saves.TEST_ROOT + "run_%d_4243" % int(Time.get_unix_time_from_system())
	var other := Saves.TEST_ROOT + "keep_me"
	for d in [stale, fresh, other]:
		DirAccess.make_dir_recursive_absolute(d)
		var f := FileAccess.open(d + "/x.json", FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	Saves._sweep_stale_runs()
	check(not DirAccess.dir_exists_absolute(stale), "a run folder older than a day is removed")
	check(DirAccess.dir_exists_absolute(fresh), "a recent run folder (another run in parallel) is kept")
	check(DirAccess.dir_exists_absolute(other), "folders that are not run folders are kept")
	check(DirAccess.dir_exists_absolute(Saves.dir), "this run's folder is kept")
	Saves._remove_tree(fresh)
	Saves._remove_tree(other)


func _listing(dir: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return "<none>"
	var out := []
	for f in d.get_files():
		var p := dir + f
		out.append("%s:%d" % [f, FileAccess.get_modified_time(p)])
	out.sort()
	return ",".join(out)
