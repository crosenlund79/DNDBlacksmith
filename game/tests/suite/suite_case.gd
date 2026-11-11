## SuiteCase — base class for the permanent regression & progression suite (tests/suite/cases/*.gd).
## EN: A case file extends SuiteCase and defines test_* methods. Methods listed in SMOKE also run in the fast
##     smoke subset. Each test starts from a fresh, seeded new game. Use check/eq/skip; fixtures below drive
##     the real systems (crafting with fixed check scores and dice, skill XP, buying, time) — never edit state
##     to skip a progression requirement unless a test is explicitly about something else.
## DA: Basisklasse for den permanente testsuite. Hver test starter fra et nyt, seedet spil.
class_name SuiteCase
extends RefCounted

var _fails: Array[String] = []
var _notes: Array[String] = []
var _skipped := ""
var _checks := 0


# ------------------------------------------------------------------ assertions
func check(cond: bool, what: String) -> bool:
	_checks += 1
	if not cond:
		_fails.append(what)
	return cond


func eq(a: Variant, b: Variant, what: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [what, str(a), str(b)])


func note(t: String) -> void:
	_notes.append(t)


## Mark the test skipped (e.g. a system not present in this build) — reported as SKIPPED, not PASS.
func skip(reason: String) -> void:
	_skipped = reason


# ------------------------------------------------------------------ fixtures
## A genuine new game (journeyman unless said otherwise), seeded for determinism.
func fresh_game(difficulty := "journeyman", rng_seed := 9001) -> void:
	seed(rng_seed)
	Game.new_game(difficulty)


## Is an optional system's script present in this build?
func has_system(file: String) -> bool:
	return ResourceLoader.exists("res://scripts/systems/%s.gd" % file)


## Calls a static method on a system script by name (for systems added by other modules).
func sys(file: String, method: String, args := []) -> Variant:
	var sc: Script = load("res://scripts/systems/%s.gd" % file)
	return sc.callv(method, args)


func give(def: String, n := 1) -> void:
	if bool(DB.item(def).get("stack", false)):
		Game.add_item(Items.make(def, {"qty": n}), false)
	else:
		for i in n:
			Game.add_item(Items.make(def, {"quality": 80.0}), false)


## Drives a whole crafting job through its stations with fixed check scores and dice; returns the item
## ({} if the recipe could not start — locked, missing inputs or another job running).
func craft(recipe: String, q := 92.0, dice := {"edge": 12, "temper": 12, "fortune": 50}) -> Dictionary:
	if not Crafting.start(recipe):
		return {}
	var guard := 0
	while Crafting.current_station() != "" and guard < 30:
		var st := Crafting.current_station()
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(q)
		Crafting.record_step(st, qs)
		guard += 1
	return Crafting.finish(dice, "digital")


## Why a recipe cannot be crafted right now ("" = it can): locks and missing materials.
func craft_blocker(recipe: String) -> String:
	var why := Crafting.recipe_locked_reason(recipe)
	if why != "":
		return why
	var miss := Crafting.missing_inputs(recipe)
	return "" if miss.is_empty() else "missing " + str(miss)


## Raise a player skill the legitimate way: experience until the level is reached.
func train(skill: String, level: int) -> void:
	var guard := 0
	while Game.player_level(skill) < level and guard < 200:
		Game.grant_player_xp(skill, SkillSys.xp_needed(Game.player_level(skill) + 1))
		guard += 1


## An old save's earned level: experience first (train), then — for a craft outside the smith's profession, which since
## The Living Workshop B1 stops growing at Workers.BASIC_LEVEL — the level an old save keeps (save step 5 never lowers
## it). For content checks that need an all-round master smith; progression tests use train() and specialists.
func legacy_level(skill: String, level: int) -> void:
	train(skill, level)
	if Game.player_level(skill) < level:
		Game.player_skills()[skill] = {"lvl": level, "xp": 0}


func days(n: int) -> void:
	for i in n:
		Game.advance_minutes(1440)


func save_load(slot := "suite_roundtrip") -> bool:
	if not Saves.save(slot):
		return false
	var ok := Saves.load_slot(slot)
	Saves.delete(slot)
	return ok


## Writes the current game as a save from an OLDER schema version (the file declares `version`), so loading it
## runs the migration steps from that version — for tests that build an old-shaped state by hand.
func save_as_version(slot: String, version: int) -> bool:
	if not Saves.save(slot):
		return false
	var p := Saves.path(slot)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not doc is Dictionary:
		return false
	doc["data"]["version"] = version
	doc["meta"]["version"] = version
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	return true
