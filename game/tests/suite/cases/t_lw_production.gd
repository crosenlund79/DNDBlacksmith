## The Living Workshop — PRODUCTION: several stations of one type (#37, D6) and staged work orders (C1).
## Station instances: ids (instance #1 keeps the type id, further ones "anvil#2"), buying another (price rising a little
## per instance, one per pair of hands, at most five, the Project Bench once), placing/moving/validating each, workers
## spreading across the free instances instead of queueing at the first, the smith's priority at the instance he uses,
## instances surviving save/load; the save step that turns today's stations into instance #1 (layouts unchanged,
## idempotent, golden saves).
extends SuiteCase

const SMOKE := ["test_station_instances_buy_and_place"]
const FIN := ["done", "failed", "cancelled"]
const GOLDEN := ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]
const FIXTURES := "res://tests/fixtures/saves/"


# ------------------------------------------------------------------ fixtures
## A new game owning the whole building (empty rooms to place in), every Design and station known, money — and only
## the starter stations set up.
func _workshop() -> void:
	fresh_game()
	for u in Property.units():
		Property.dev_grant_unit(str(u["id"]))
	SkillTree.unlock_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Game.state["gold"] = 50000
	(Game.state["hirelings"] as Array).clear()   # Borin's own work would move the stores under the test


## Buys one more of a type and sets it up in a sensible free spot. Returns the new instance id ("" on failure).
func _add_instance(t: String) -> String:
	var before := Property.instances(t, false)
	var err := Property.buy_station(t)
	if not check(err == "", "another %s is bought (%s)" % [t, err]):
		return ""
	var iid := ""
	for x in Property.instances(t, false):
		if not before.has(x):
			iid = str(x)
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, iid)
	if not check(why == "" and Property.commit(plan) == "", "%s is set up (%s)" % [iid, why]):
		return ""
	return iid


func _at_hour(h: int) -> void:
	var mins: int = (h * 60 - int(Game.state["minute"]) % 1440 + 1440) % 1440
	Game.advance_minutes(mins)


# ------------------------------------------------------------------ instances: ids, price, limits, placing
func test_station_instances_buy_and_place() -> void:
	_workshop()
	eq(Property.type_of("anvil#2"), "anvil", "an instance id names its type")
	eq(Property.instance_no("anvil#3"), 3, "…and its number")
	eq(Property.instance_no("anvil"), 1, "the type id is instance #1 (every old key stays valid)")
	eq(str(DB.station("anvil#2").get("name", "")), str(DB.station("anvil").get("name", "?")), "an instance reads its type's data")
	eq(Property.instances("anvil"), ["anvil"], "a new game has one anvil, under the type id")
	var base := int(Property.PRICE["anvil"])
	eq(Property.station_price("anvil"), int(round(base * 1.25)), "the second anvil costs a quarter more than the first (%d g)" % base)
	var gold0 := Game.gold()
	var a2 := _add_instance("anvil")
	eq(a2, "anvil#2", "the second anvil is anvil#2")
	eq(gold0 - Game.gold(), int(round(base * 1.25)), "…paid at its price")
	eq(Property.instances("anvil"), ["anvil", "anvil#2"], "both stand in the workshop, #1 first")
	check(Property.is_installed("anvil#2") and Property.is_installed("anvil"), "each instance is installed on its own")
	check(Property.pos_of("anvil#2") != Property.pos_of("anvil"), "…at its own place %s vs %s" % [Property.pos_of("anvil#2"), Property.pos_of("anvil")])
	eq(Property.instance_label("anvil#2"), str(DB.station("anvil")["name"]) + " #2", "players tell them apart: %s" % Property.instance_label("anvil#2"))
	# limits: one per pair of hands (the smith alone: two), at most five; the Project Bench once
	eq(Property.max_instances("anvil"), 2, "the smith alone keeps two anvils busy at most")
	var why3 := Property.buy_station("anvil")
	check(why3.contains("pair of hands"), "a third anvil waits for more staff: %s" % why3)
	for p in ["blacksmith", "blacksmith", "runesmith", "alchemist"]:
		check(not Apprentices.dev_take_on(p, 6).is_empty(), "a %s is taken on" % p)
	eq(Property.max_instances("anvil"), 5, "five workers keep five anvils busy")
	for i in 3:
		check(_add_instance("anvil") != "", "anvil #%d" % (i + 3))
	eq(Property.instance_count("anvil"), 5, "five anvils")
	check(Property.buy_station("anvil").contains("as many as a workshop"), "never a sixth: %s" % Property.buy_station("anvil"))
	eq(Property.max_instances(Contracts.BENCH), 1, "one Project Bench")
	check(Property.validate(Property.plan_copy()) == "", "every station can still be reached: %s" % Property.validate(Property.plan_copy()))
	# moving one instance moves only that one; storing it and placing it again
	var plan := Property.plan_copy()
	var p2 := Property.pos_of("anvil#2")
	Property.store(plan, "anvil#2")
	check((plan["stored"] as Array).has("anvil#2") and not (plan["stations"] as Dictionary).has("anvil#2"), "anvil #2 goes into storage")
	eq(Property.commit(plan), "", "…which is a valid plan")
	check(not Property.is_installed("anvil#2") and Property.is_installed("anvil"), "#2 is in storage, the others stand")
	check(Property.station_reason("anvil#2").contains("not set up"), "#2 says it waits in storage")
	plan = Property.plan_copy()
	eq(Property.place(plan, "anvil#2", p2), "", "…and goes back to its place")
	eq(Property.commit(plan), "", "the plan is applied")
	check(Property.is_installed("anvil#2"), "#2 stands again")
	# the room's main station is the lowest-numbered of its type
	for sid in Property.main_stations():
		check(Property.instance_no(str(sid)) == 1 or Property.instances(Property.type_of(str(sid))).size() == 1 or not Property.main_stations().has(Property.type_of(str(sid))),
			"a main station is the first of its kind in the room (%s)" % sid)
	# survives save/load
	check(save_load("suite_lw_inst"), "saved and loaded")
	eq(Property.instance_count("anvil"), 5, "five anvils after loading")
	eq(Property.pos_of("anvil#2"), p2, "anvil #2 stands where it stood")


# ------------------------------------------------------------------ workers spread across free instances
func test_workers_spread_across_instances() -> void:
	_workshop()
	var hands := []
	for i in 3:
		var a := Apprentices.dev_take_on("blacksmith", 6, "journeyman")
		check(not a.is_empty(), "journeyman blacksmith %d" % (i + 1))
		hands.append(str(a["id"]))
	for t in ["anvil", "anvil", "forge", "forge"]:
		_add_instance(t)
	eq(Property.instances("anvil").size(), 3, "three anvils")
	eq(Property.instances("forge").size(), 3, "three forges")
	give("ingot_iron", 30)
	give("coal", 30)
	for aid in hands:
		var t := Apprentices.add_task("craft", {"recipe": "iron_hatchet", "repeat": 3, "assignee": aid})
		check(not t.has("error"), "three hatchets for %s (%s)" % [aid, t.get("error", "")])
	_at_hour(8)
	var max_anvils := 0
	var max_forges := 0
	var waited_with_free := false
	for step in 8 * 12:
		Game.advance_minutes(5)
		var used := {}
		for t in Apprentices.open_tasks():
			var at := str(t.get("station", ""))
			if at != "" and str(t.get("state", "")) == "working":
				used[at] = true
				# never two at one instance
		var an := 0
		var fo := 0
		for sid in used:
			if Property.type_of(str(sid)) == "anvil":
				an += 1
			elif Property.type_of(str(sid)) == "forge":
				fo += 1
		max_anvils = maxi(max_anvils, an)
		max_forges = maxi(max_forges, fo)
		for t2 in Apprentices.open_tasks():
			if str(t2.get("blocker", "")).begins_with("Waiting for the anvil"):
				for sid2 in Property.instances("anvil"):
					if Apprentices.station_user(str(sid2)) == "":
						waited_with_free = true
	check(max_anvils >= 2, "several anvils are worked at once (at most %d at a time)" % max_anvils)
	check(max_forges >= 2, "several forges are worked at once (at most %d at a time)" % max_forges)
	check(not waited_with_free, "nobody waits for an anvil while another stands free")
	var made := 0
	for t3 in Apprentices.tasks():
		made += int(t3.get("done", 0))
	check(made >= 3, "the work got done (%d hatchets)" % made)
	var wear := 0
	for sid3 in Property.instances("anvil"):
		if int(Apprentices.st()["stations"].get(str(sid3), {}).get("uses", 0)) > 0:
			wear += 1
	check(wear >= 2, "wear is kept per instance (%d anvils used)" % wear)


## The smith takes the anvil an apprentice works at: the apprentice steps aside to another free one.
func test_smith_priority_moves_apprentice_to_free_instance() -> void:
	_workshop()
	var a := Apprentices.dev_take_on("blacksmith", 6, "journeyman")
	_add_instance("anvil")
	give("ingot_iron", 10)
	give("coal", 10)
	var t := Apprentices.add_task("craft", {"recipe": "iron_hatchet", "repeat": 1, "assignee": str(a["id"])})
	_at_hour(8)
	var guard := 0
	while Property.type_of(str(t.get("at", ""))) != "anvil" and guard < 200:
		Game.advance_minutes(5)
		guard += 1
	var held := str(t.get("at", ""))
	check(Property.type_of(held) == "anvil", "the apprentice holds an anvil (%s)" % held)
	# the smith begins a hatchet and settles at that very anvil
	check(Crafting.start("hand_axe") or Crafting.active(), "the smith begins work")
	Crafting.record_step("forge", [90.0])
	eq(Crafting.current_station(), "anvil", "his next step is at an anvil")
	Crafting.choose_instance(held)
	eq(Crafting.smith_instance(), held, "he stands at the apprentice's anvil")
	eq(Apprentices.station_user(held), "smith", "the smith has it now")
	Game.advance_minutes(5)
	var now_at := str(t.get("at", ""))
	check(now_at != held and Property.type_of(now_at) == "anvil", "the apprentice moved to the other anvil (%s)" % now_at)
	check(not str(t.get("blocker", "")).begins_with("Waiting"), "…without waiting: %s" % str(t.get("blocker", "")))
	Crafting.record_step(held, [90.0])
	var it := Crafting.finish({"edge": 10, "temper": 6, "fortune": 40})
	check(not it.is_empty(), "the smith finished his piece")
	var ops: Array = it.get("craft", {}).get("ops", [])
	eq(str(ops[-1].get("at", "")), held, "his record names the anvil he worked at")


# ------------------------------------------------------------------ the save step
func _golden_data(name: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
	if not doc is Dictionary or not (doc as Dictionary).get("data") is Dictionary:
		return {}
	return Saves._restore_ints(doc["data"])


func test_migration_station_instances_golden_saves() -> void:
	for g in GOLDEN:
		var data := _golden_data(g)
		if not check(not data.is_empty(), "%s loads as data" % g):
			continue
		SaveMigrations.run(data, Game.SAVE_VERSION - 1)
		var before := JSON.stringify(data.get("property", {}), "", true)
		SaveMigrations.apply_step(Game.SAVE_VERSION, data)
		var after := JSON.stringify(data.get("property", {}), "", true)
		eq(after, before, "%s: the layout is unchanged — every station is instance #1 under its own id" % g)
		var again := JSON.stringify(data, "", true)
		SaveMigrations.apply_step(Game.SAVE_VERSION, data)
		eq(JSON.stringify(data, "", true), again, "%s: the step is idempotent" % g)
	# a doubled storage entry is tidied once
	_workshop()
	var s := Property.st()
	(s["stored"] as Array).append("anvil")
	(s["stored"] as Array).append("loom")
	(s["stored"] as Array).append("loom")
	var n := Property.migrate_instances(Game.state)
	eq(n, 2, "a station both set up and stored, and a doubled storage entry, are tidied")
	check(not (s["stored"] as Array).has("anvil") and (s["stored"] as Array).count("loom") == 1, "anvil stays set up; one loom in storage")
	eq(Property.migrate_instances(Game.state), 0, "a second pass changes nothing")
