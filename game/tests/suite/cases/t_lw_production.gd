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
		SaveMigrations.run(data, 6)   # the schema before station instances (step 7; v1.7 added step 8 after it)
		var before := JSON.stringify(data.get("property", {}), "", true)
		SaveMigrations.apply_step(7, data)
		var after := JSON.stringify(data.get("property", {}), "", true)
		eq(after, before, "%s: the layout is unchanged — every station is instance #1 under its own id" % g)
		var again := JSON.stringify(data, "", true)
		SaveMigrations.apply_step(7, data)
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


# ================================================================== C1: staged work orders
const EMBER := "emberwarden_longsword"


## The whole building with every station set up (the specialists' rooms included).
func _full_workshop() -> void:
	_workshop()
	Property.dev_install_in_owned()


func _ember_mats(n := 1) -> void:
	give("ingot_steel", 2 * n)
	give("runestone_ember", n)
	give("coating_flame", n)
	give("thread_ethereal", n)


func _counts() -> Dictionary:
	var out := {}
	for d in ["ingot_steel", "runestone_ember", "coating_flame", "thread_ethereal", "sword_emberwarden"]:
		out[d] = Game.count(d)
	return out


## Runs the clock in 5-minute steps until `cond` holds (at most `max_min` minutes); records the station types each
## apprentice was seen working at in `seen` {app id: [types]}.
func _until(cond: Callable, max_min := 2 * 1440, seen := {}) -> bool:
	var g := 0
	while not cond.call() and g < max_min:
		Game.advance_minutes(5)
		g += 5
		for a in Apprentices.staff():
			var cur := Apprentices.current(a)
			if str(cur.get("phase", "")) == "working" and str(cur.get("station", "")) != "":
				var arr: Array = seen.get(str(a["id"]), [])
				var ty := Property.type_of(str(cur["station"]))
				if not arr.has(ty):
					arr.append(ty)
				seen[str(a["id"])] = arr
	return cond.call()


## The smith works the stage he claimed: begins it and plays every operation of it at the stations (fixed scores).
func _smith_stage(t: Dictionary, q := 100.0) -> bool:
	var err := WorkOrders.begin_smith_stage(int(t["id"]))
	if not check(err == "", "the smith begins his stage (%s)" % err):
		return false
	var guard := 0
	while Crafting.active() and Crafting.job().has("order") and guard < 12:
		var n := int(Crafting.current_op().get("checks", 1))
		var qs := []
		for i in n:
			qs.append(q)
		Crafting.record_step(Crafting.smith_instance(), qs)
		guard += 1
	return not Crafting.active()


func test_work_order_shape_and_uid() -> void:
	_full_workshop()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	check(not t.has("error"), "an Emberwarden order is queued (%s)" % t.get("error", ""))
	var st := WorkOrders.stages(t)
	eq(st.size(), 5, "five stages: smithing, rune work, alchemy, smithing, leatherwork")
	eq(st.map(func(s): return str(s["disc"])), ["classic", "runecraft", "alchemy", "classic", "stitching"], "the stages follow the stations' crafts")
	eq((st[0]["ops"] as Array), [0, 1], "the smith's first stage is forge and anvil together")
	eq(WorkOrders.maker_stage(t), 0, "the forging stage makes the maker")
	check(int(t.get("uid", 0)) > 0, "the order reserved its piece's uid at creation (%d)" % int(t.get("uid", 0)))
	check(Game.find_uid(int(t["uid"])).is_empty(), "…without making a half-built item in the stores")
	eq(WorkOrders.stage_materials(t, 1).keys(), ["runestone_ember"], "the rune stage puts in the runestone")
	eq(WorkOrders.stage_materials(t, 0).get("ingot_steel", 0), 2, "the forging stage the steel")
	var plain := Apprentices.add_task("craft", {"recipe": "iron_hatchet"})
	eq(WorkOrders.stages(plain).size(), 1, "an ordinary one-craft Design stays one stage (one worker, as before)")
	check(not WorkOrders.staged(plain), "…and is not a staged order")
	var prep := Apprentices.add_task("prep", {"recipe": "smelt_iron"})
	eq(int(prep.get("uid", 0)), 0, "materials take their uid when they are made")
	check(ItemRegistry.scan()["dup"].is_empty(), "no duplicate uids")


## The latent C1 defect (PROD-010): the maker is the forging-stage worker, not the hand that finishes.
func test_maker_is_forging_worker_not_finisher() -> void:
	_full_workshop()
	var smith_a := Apprentices.dev_take_on("blacksmith", 9, "master", "Tobin Brand")
	var rune := Apprentices.dev_take_on("runesmith", 6, "journeyman")
	var alch := Apprentices.dev_take_on("alchemist", 6, "journeyman")
	var leath := Apprentices.dev_take_on("leatherworker", 6, "journeyman")
	_ember_mats()
	var c0 := _counts()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	var uid := int(t["uid"])
	_at_hour(8)
	var seen := {}
	check(_until(func(): return str(t["state"]) in FIN, 3 * 1440, seen), "the order finishes (%s: %s)" % [t["state"], t.get("blocker", "")])
	eq(str(t["state"]), "done", "done")
	var it := Game.find_uid(uid)
	check(not it.is_empty(), "the finished sword carries the uid reserved at creation")
	eq(str(Provenance.maker(it).get("id", "")), str(smith_a["id"]), "the master blacksmith who forged it is the maker")
	var con := Provenance.contributors(it)
	eq(con.size(), 3, "three specialists contributed")
	eq(con.map(func(e): return str(e["who"])), [str(rune["id"]), str(alch["id"]), str(leath["id"])], "runesmith, alchemist, leatherworker in order")
	check(str(con[2]["profession"]) == "leatherworker" and not str(Provenance.maker(it).get("id", "")) == str(leath["id"]),
		"the leatherworker finished the piece but is a contributor, not the maker")
	check((smith_a["creations"] as Array).has(uid) and not (leath["creations"] as Array).has(uid), "the creation is the maker's")
	check(seen.get(str(rune["id"]), []).has("rune_engraving_stand"), "the runesmith worked at the rune engraving stand %s" % str(seen.get(str(rune["id"]), [])))
	check(seen.get(str(alch["id"]), []).has("cauldron"), "the alchemist at the cauldron %s" % str(seen.get(str(alch["id"]), [])))
	check(seen.get(str(leath["id"]), []).has("stitching_table"), "the leatherworker at the stitching table %s" % str(seen.get(str(leath["id"]), [])))
	check(not seen.get(str(leath["id"]), []).has("anvil"), "…and never at the anvil")
	var c1 := _counts()
	eq(c0["ingot_steel"] - c1["ingot_steel"], 2, "two steel used, once")
	eq(c0["runestone_ember"] - c1["runestone_ember"], 1, "one ember runestone used")
	eq(c1["sword_emberwarden"] - c0["sword_emberwarden"], 1, "exactly one sword")
	var sc := ItemRegistry.scan()
	check((sc["dup"] as Array).is_empty() and (sc["shared"] as Array).is_empty() and (sc["stray"] as Array).is_empty(), "identity clean: %s" % ItemRegistry.scan_text(sc))
	check((rune.get("memories", []) as Array).any(func(m): return str(m.get("text", "")).begins_with("Did the")), "the runesmith remembers the stage")


func test_cancel_mid_order_returns_materials_once() -> void:
	_full_workshop()
	Apprentices.dev_take_on("runesmith", 6, "journeyman")
	_ember_mats()
	train("smithing", 8)
	var c0 := _counts()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	eq(WorkOrders.assign_stage(int(t["id"]), 0, "player"), "", "the smith claims the forging stage")
	_at_hour(8)
	_smith_stage(t)
	eq(_counts()["ingot_steel"], c0["ingot_steel"] - 2, "the order holds the steel")
	eq(Apprentices.cancel_task(int(t["id"])), "", "the order is cancelled halfway")
	var c1 := _counts()
	eq(c1, c0, "every material is back in the stores, once %s" % str(c1))
	check(Apprentices.cancel_task(int(t["id"])) != "", "…and nothing comes back twice")
	eq(c1["sword_emberwarden"], c0["sword_emberwarden"], "no piece was made")


func test_smith_claim_abandon_resume() -> void:
	_full_workshop()
	train("smithing", 8)
	_ember_mats()
	var c0 := _counts()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	var tid := int(t["id"])
	eq(WorkOrders.assign_stage(tid, 0, "player"), "", "he claims the forging stage")
	_at_hour(8)
	Game.advance_minutes(10)
	check(str(t["blocker"]).begins_with("Waiting for you"), "the order waits for him: %s" % t["blocker"])
	eq(WorkOrders.waiting_for_smith().get("task", -1), tid, "the workshop knows it waits for him")
	eq(WorkOrders.begin_smith_stage(tid), "", "he begins at the forge")
	var j := Crafting.job()
	eq(int(j.get("order", -1)), tid, "his craft job carries the order")
	eq(int(j.get("stop", -1)), 2, "…from the forge to the end of his stage (the anvil)")
	Crafting.record_step(Crafting.smith_instance(), [96.0])
	eq((t["ops_done"] as Array).size(), 1, "the heated steel is recorded in the order")
	eq(str(t["ops_done"][0].get("by", "")), "player", "…as the smith's work")
	Crafting.cancel()
	check(not Crafting.active(), "he sets the work down")
	eq(_counts()["ingot_steel"], c0["ingot_steel"] - 2, "the materials stay with the order (not back, not lost)")
	eq((t["ops_done"] as Array).size(), 1, "the operation he did is kept")
	eq(str(WorkOrders.current(t).get("assignee", "")), "player", "the stage is still his")
	eq(WorkOrders.begin_smith_stage(tid), "", "he takes it up again")
	eq(int(Crafting.job().get("step", -1)), 1, "…at the anvil, where he stopped")
	eq(_counts()["ingot_steel"], c0["ingot_steel"] - 2, "nothing is taken twice")
	Crafting.record_step(Crafting.smith_instance(), [100.0, 100.0, 100.0])
	check(not Crafting.active(), "his stage is done — the piece goes on to the rune stage")
	eq(str(WorkOrders.stages(t)[0]["state"]), "done", "stage 1 done")
	eq(str(WorkOrders.stages(t)[0]["by"]), "player", "…by the smith")
	check(str(WorkOrders.current(t)["disc"]) == "runecraft", "the rune stage is next")


func test_worker_leaves_stage_is_reassigned() -> void:
	_full_workshop()
	train("smithing", 8)
	var r1 := Apprentices.dev_take_on("runesmith", 6, "journeyman", "Edda Vell")
	Apprentices.dev_take_on("alchemist", 6, "journeyman", "Mira Holt")
	_ember_mats()
	var c0 := _counts()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	WorkOrders.assign_stage(int(t["id"]), 0, "player")
	_at_hour(8)
	_smith_stage(t)
	Game.advance_minutes(5)
	eq(str(t.get("worker", "")), str(r1["id"]), "the runesmith takes the rune stage")
	t["progress"] = 0.0
	t["station"] = ""
	eq(Apprentices.dismiss(str(r1["id"])), "", "the runesmith is let go before setting to work")
	eq((t["ops_done"] as Array).size(), 2, "the forging work stays in the piece")
	eq(_counts()["ingot_steel"], c0["ingot_steel"] - 2, "…and the order keeps its materials")
	Game.advance_minutes(10)
	check(str(t["blocker"]).contains("runesmith"), "the order says who it needs: %s" % t["blocker"])
	var r2 := Apprentices.dev_take_on("runesmith", 7, "journeyman", "Ada Quill")
	check(_until(func(): return WorkOrders.stage_index(t) >= 2 or str(t["state"]) in FIN, 1440), "another runesmith picks the stage up")
	eq(str(WorkOrders.stages(t)[1].get("by", "")), str(r2["id"]), "the new runesmith did the rune stage")
	eq(_counts()["ingot_steel"], c0["ingot_steel"] - 2, "nothing was taken again")


func test_help_requests_are_optional() -> void:
	_full_workshop()
	train("smithing", 8)
	var weak := Apprentices.dev_take_on("runesmith", 2, "journeyman", "Wren Marsh")
	Apprentices.dev_take_on("alchemist", 6, "journeyman")
	Apprentices.dev_take_on("leatherworker", 6, "journeyman")
	_ember_mats(2)
	var t := Apprentices.add_task("craft", {"recipe": EMBER, "repeat": 2})
	WorkOrders.assign_stage(int(t["id"]), 0, "player")
	WorkOrders.assign_stage(int(t["id"]), 3, "player")
	_at_hour(8)
	_smith_stage(t)
	check(_until(func(): return not WorkOrders.open_help().is_empty(), 240), "the runesmith, out of depth, asks for a hand")
	var h: Dictionary = WorkOrders.open_help()[0]
	eq(str(h["app"]), str(weak["id"]), "…it is the runesmith's request")
	check(str(h["text"]).contains("hard work"), "it says why: %s" % h["text"])
	var now0 := Game.now()
	eq(WorkOrders.answer_help(int(h["id"]), "help"), "", "the smith lends a hand")
	eq(Game.now() - now0, WorkOrders.HELP_MINUTES, "half an hour at their side")
	check(_until(func(): return WorkOrders.stage_index(t) >= 2, 600), "the rune stage is done")
	var q_helped := float(WorkOrders.stages(t)[1]["q"])
	check(q_helped > 0.0, "the helped stage scored %d%%" % int(q_helped))
	# a second request the same day is never made; the work goes on regardless
	check(_until(func(): return WorkOrders.current(t).get("assignee", "") == "player" and str(t.get("worker", "")) == "", 600), "the order reaches the smith's honing stage")
	_smith_stage(t)
	check(_until(func(): return int(t["done"]) >= 1, 600), "the first sword is finished")
	eq(WorkOrders.open_help().size(), 0, "no further request that day (at most one a day)")
	# a request that is declined or lapses never blocks the work
	Game.advance_minutes(1440 - (int(Game.state["minute"]) % 1440) + 8 * 60)
	_smith_stage(t)
	check(_until(func(): return not WorkOrders.open_help().is_empty(), 300), "the next day she asks again")
	eq(WorkOrders.answer_help(int(WorkOrders.open_help()[0]["id"]), "decline"), "", "the smith declines")
	check(_until(func(): return WorkOrders.stage_index(t) >= 2, 600), "she carries on alone, without the bonus")
	check(WorkOrders.answer_help(int(h["id"]), "help") != "", "an old request cannot be answered again")


func test_migration_work_orders() -> void:
	_full_workshop()
	var bs := Apprentices.dev_take_on("blacksmith", 9, "master")
	Apprentices.dev_take_on("runesmith", 6, "journeyman")
	_ember_mats()
	var t := Apprentices.add_task("craft", {"recipe": EMBER, "assignee": str(bs["id"])})
	_at_hour(8)
	check(_until(func(): return int(t["op"]) >= 2, 600), "the blacksmith forged and drew the blade")
	var tid := int(t["id"])
	# make it look like a schema-5 task: no stages, no reserved uid
	for k in ["stages", "stages_for", "uid", "handoff"]:
		t.erase(k)
	var taken := JSON.stringify(t["taken"])
	check(save_as_version("suite_lw_wo5", 6), "written as schema 6 (before work orders)")
	check(Saves.load_slot("suite_lw_wo5"), "it loads")
	Saves.delete("suite_lw_wo5")
	var t2 := Apprentices.task(tid)
	check(t2.has("stages"), "the open task became a staged work order")
	eq(str(t2["stages"][0]["state"]), "done", "the forging stage is done")
	eq(str(t2["stages"][0]["by"]), str(bs["id"]), "…by the blacksmith who worked it")
	check(str(t2["stages"][1]["state"]) in ["ready", "working"], "the rune stage is next")
	check(int(t2.get("uid", 0)) > 0, "its piece's uid is reserved")
	eq(JSON.stringify(t2["taken"]), taken, "the materials in hand are kept")
	var snap := JSON.stringify(Game.state.get("apprentices", {}), "", true)
	eq(Apprentices.migrate_work_orders(Game.state), 0, "a second pass converts nothing")
	eq(JSON.stringify(Game.state.get("apprentices", {}), "", true), snap, "…and changes nothing")
	var uid := int(t2["uid"])
	check(_until(func(): return str(t2["state"]) in FIN, 2 * 1440), "the migrated order finishes")
	eq(str(Provenance.maker(Game.find_uid(uid)).get("id", "")), str(bs["id"]), "the piece carries the reserved uid; the blacksmith is its maker")


# ------------------------------------------------------------------ the Ledger and the station panel show the order
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r != null:
			return r
	return null


func _text_in(n: Node, needle: String) -> bool:
	return _find(n, func(x): return (x is Label and (x as Label).text.contains(needle)) or (x is RichTextLabel and (x as RichTextLabel).text.contains(needle)) \
		or (x is Button and (x as Button).text.contains(needle))) != null


func test_ledger_and_station_show_the_order() -> void:
	_full_workshop()
	train("smithing", 8)
	var rune := Apprentices.dev_take_on("runesmith", 2, "journeyman", "Edda Vell")
	Apprentices.dev_take_on("alchemist", 6, "journeyman", "Mira Holt")
	_ember_mats()
	# the smith cannot make it alone (a leatherworker is missing: the grip) — "Order it" says why not yet
	Apprentices.dev_take_on("leatherworker", 6, "journeyman", "Wren Marsh")
	eq(StationPanel.order_reason(EMBER), "", "with a runesmith, an alchemist and a leatherworker it can be ordered")
	var sp := StationPanel.new("anvil")
	_host().add_child(sp)
	sp._order(EMBER)
	var t := {}
	for x in Apprentices.open_tasks():
		if str(x.get("recipe", "")) == EMBER:
			t = x
	check(not t.is_empty(), "Order it queued the Emberwarden as a work order")
	eq(str(WorkOrders.stages(t)[0].get("assignee", "")), "player", "the smith took the forging stage")
	eq(str(WorkOrders.stages(t)[3].get("assignee", "")), "player", "…and the honing")
	sp.free()
	_at_hour(8)
	Game.advance_minutes(5)
	# the station panel at the forge offers his stage
	var fp := StationPanel.new("forge")
	_host().add_child(fp)
	check(fp.find_child("MyStage", true, false) != null, "the forge's panel offers his stage of the order")
	fp.free()
	var lp := WorkshopPanel.new()
	_host().add_child(lp)
	var tid := int(t["id"])
	check(lp.find_child("Stages_%d" % tid, true, false) != null, "the Ledger lists the order's stages")
	check(lp.find_child("StageAssign_%d_1" % tid, true, false) != null, "…with who does each stage")
	check(lp.find_child("GoStage_%d" % tid, true, false) != null, "…and a way to walk to his stage")
	check(_text_in(lp, "work order, 5 stages"), "the row says it is a work order")
	check(_text_in(lp, "Ember Runestone"), "the rune stage's material is listed")
	lp.free()
	# his stage, then the runesmith (out of her depth) asks for a hand — the Ledger shows the request
	var err := WorkOrders.begin_smith_stage(tid)
	eq(err, "", "he takes up his stage")
	while Crafting.active():
		var qs := []
		for i in int(Crafting.current_op().get("checks", 1)):
			qs.append(100.0)
		Crafting.record_step(Crafting.smith_instance(), qs)
	check(_until(func(): return not WorkOrders.open_help().is_empty(), 240), "the runesmith asks for a hand")
	var lp2 := WorkshopPanel.new()
	_host().add_child(lp2)
	var hid := int(WorkOrders.open_help()[0]["id"])
	check(lp2.find_child("HelpRequest_%d" % hid, true, false) != null, "the Ledger shows the request with its answers")
	check(_text_in(lp2, "Edda"), "…naming who asks")
	check(_text_in(lp2, "at work"), "the stage at hand shows its worker at work")
	lp2.free()
	eq(str(rune["id"]), str(t.get("worker", "")), "the runesmith is on the rune stage")


# ------------------------------------------------------------------ the steward and work orders (S1/S2 kept)
func test_steward_plans_with_the_workshops_people() -> void:
	_full_workshop()
	var bs := Apprentices.dev_take_on("blacksmith", 9, "master", "Tobin Brand")
	check(Apprentices.can_make(bs, EMBER) != "", "the master blacksmith cannot make the Emberwarden alone (%s)" % Apprentices.can_make(bs, EMBER))
	check(Apprentices.order_reason(bs, EMBER) != "", "…nor as a work order without a runesmith: %s" % Apprentices.order_reason(bs, EMBER))
	check(Steward._maker_for(EMBER).is_empty(), "so the steward plans no Emberwarden")
	Apprentices.dev_take_on("runesmith", 6, "journeyman")
	eq(Apprentices.order_reason(bs, EMBER), "", "with a runesmith on the staff it is a work order the blacksmith makes")
	eq(str(Steward._maker_for(EMBER).get("id", "")), str(bs["id"]), "the steward plans with the workshop's real people (its maker: the blacksmith)")
	eq(Apprentices.order_reason(bs, "iron_hatchet"), Apprentices.can_make(bs, "iron_hatchet"), "ordinary one-craft work: exactly as before")


func test_steward_smith_works_claimed_stage_without_experience() -> void:
	_full_workshop()
	train("smithing", 8)
	Apprentices.dev_take_on("runesmith", 7, "journeyman")
	Apprentices.dev_take_on("alchemist", 7, "journeyman")
	Apprentices.dev_take_on("leatherworker", 7, "journeyman")
	_ember_mats()
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	WorkOrders.assign_stage(int(t["id"]), 0, "player")
	WorkOrders.assign_stage(int(t["id"]), 3, "player")
	var uid := int(t["uid"])
	Steward.st()["orders"]["order_rules"]["max_difficulty"] = 6   # the player's standing rule lets him do this work
	var skills0 := JSON.stringify(Game.player_skills())
	_at_hour(8)
	eq(Steward.activate(), "", "the steward takes over")
	check(_until(func(): return str(t["state"]) in FIN, 3 * 1440), "the order is finished under the steward (%s %s)" % [t["state"], t.get("blocker", "")])
	var st := WorkOrders.stages(t)
	var it := Game.find_uid(uid)
	if check(not it.is_empty(), "the sword is in the stores under its reserved uid"):
		eq(str(Provenance.maker(it).get("id", "")), Provenance.SMITH_ID, "the smith — working under the steward — is its maker")
		eq(Provenance.contributors(it).size(), 3, "the three specialists are recorded")
		check(float(it.get("quality", 0.0)) <= StewardSmith.QUALITY_CAP + 0.01, "competent, not exceptional: %d%%" % int(it.get("quality", 0.0)))
	var marks := (it.get("craft", {}).get("ops", []) as Array).filter(func(o): return str(o.get("by", "")) == "player")
	check(not marks.is_empty() and marks.all(func(o): return bool(o.get("steward", false))), "his operations are marked as the steward's work")
	Steward.deactivate()
	eq(JSON.stringify(Game.player_skills()), skills0, "ZERO player experience: every skill unchanged")
