## StewardSmith — Steward Mode's working smith (Milestone S2; canonical v1.1 §4.5 "competent, not superior").
## EN: While the steward runs the forge the smith keeps working under its direction: the player's own figure on an
##     autopilot. The steward chooses ordinary, feasible work — a customer's repair at the counter, a commission it
##     committed to him, materials to prepare (smelting) and pieces to restock the display — and he does it through the
##     existing actions: Crafting.start (real materials from the stores), one Crafting.record_step per operation at the
##     right station (fatigue by the existing Vitality rule), Crafting.build (provenance, the smith as maker), and
##     Shop.do_repair / Shop.repair_part (the customer pays from their own purse). His checks resolve automatically at
##     an AVERAGE performance for his current skill (Contracts.smith_hour_quality — the Project Bench's own automatic
##     path), never above QUALITY_CAP: no masterwork, no anvil naming, no Hall of Fame craftsmanship. Only routine
##     smithing Designs he has unlocked (no secret, flagged or legendary-grade recipe, never above his level or the
##     order rule), never masterpieces, refinement, reforging, sockets, enchanting, designer experiments, protected,
##     Unique or Epic pieces.
##     He keeps working hours (standing instruction, default 8–18) with the midday break by the hearth, rests an hour
##     when his hands get unsteady, goes home in the evening and sleeps in his bed (Vitality.rest / Vitality.sleep).
##     Every 5 game minutes (Game.advance_minutes, like the apprentices) tick() advances him: walking takes time, an
##     operation takes time at the station. With no world (headless soaks) a walk is an estimate from the stations'
##     positions; with a VillageWorld the StewardSmithActor walks the figure for real (stairs and lift included) and
##     reports arrival — one engine for play and tests.
##     Zero experience: work begun under the steward is marked on the Crafting job ("steward"); Game.grant_player_xp
##     refuses while the mode runs or while such marked work is being recorded (Steward.xp_blocked) — also when the
##     smith finishes the piece himself after taking the workshop back, or after a save is loaded.
##     State: Game.state["steward"]["smith"] (lazy); the session's record of his work: Steward acc["smith"].
## DA: Smeden arbejder videre under forvalteren: rutinearbejde, reparationer, forberedelse og lager — gennem spillets
##     egne handlinger, i gennemsnitlig kvalitet for hans færdighed, inden for arbejdstiden; hvile og søvn efter de
##     gældende regler. Ingen erfaring for arbejde begyndt i forvaltertilstand.
##
## Public API (static):
##   tick(minutes)   plan()   on_activate()   on_stand_down()   want() -> String   status() -> Dictionary
##   recipe_ok(rid) -> String   can_make(rid) -> bool   expected_quality(rid) -> float   order_plan(o, need) -> Dictionary
##   enqueue_commission(oid, rid)   enqueue_prep(def, short) -> bool   has_order(oid) -> bool   claims(npc) -> bool
##   will_mend(npc, pt) -> bool   queue_needs() -> Dictionary   report_part(since) -> Dictionary   arrived(place)
##   goal() -> String   driver (the world's actor, or null)
class_name StewardSmith
extends RefCounted

## Never at or above this craftsmanship under the steward: below the Hall of Fame's "very high craftsmanship" (112),
## the masterwork bonus (115) and the anvil naming (120).
const QUALITY_CAP := 110.0
const WAKE_HOUR := 6
const BED_HOUR := 22
const BREAK_START := 12
const BREAK_END := 13
## Fatigue at which his hands get unsteady (Vitality's warning): he rests an hour by the hearth before going on.
const TIRED := 80.0
## Walking estimates when there is no world: game minutes per tile at his walking pace (64 px at 230 px/s, 1.6 game
## minutes a second), a minute to set down and pick up, the way to the quarters, a floor by the stairs or the lift.
const WALK_PER_TILE := 0.45
const WALK_MIN := 1.0
const HOME_WALK := 4.0
const FLOOR_WALK := 3.0
const DEFAULT_WALK := 5.0
## With a world, a walk that has not arrived after this many times its estimate (+30 min) is taken as done.
const STUCK_FACTOR := 4.0
const PREP_RUNS := 6
const PURPOSE_ORDER := {"commission": 0, "prep": 1, "restock": 2}
const PLACE_NAME := {"bed": "his bed", "armchair": "the hearth", "table": "the table in the quarters"}

## The world's actor that walks the figure (StewardSmithActor) — when it is there, walks are physical.
static var driver: Object = null


# ======================================================================= state
static func _fresh() -> Dictionary:
	return {"act": "idle", "place": "", "goal": "", "walk_left": 0.0, "walk_est": 0.0, "walk_t": 0, "walking": false, "arrived": false,
		"job": {}, "op_progress": 0.0, "op_need": 0.0, "queue": [], "next_q": 1, "rest_until": -1, "sleep_until": -1, "break_day": -1,
		"rest_set": -1, "ops_n": 0, "tries": {}, "why_idle": ""}


## The smith's state under the steward (created on first use; old saves gain it lazily).
static func sm() -> Dictionary:
	if Game.state.is_empty():
		return _fresh()
	var s := Steward.st()
	if not s.has("smith") or not s["smith"] is Dictionary:
		s["smith"] = _fresh()
	var m: Dictionary = s["smith"]
	if not m.has("why_idle"):
		var f := _fresh()
		for k in f:
			if not m.has(k):
				m[k] = f[k]
	return m


## The session's record of his work (Steward acc["smith"]).
static func acc() -> Dictionary:
	var a: Dictionary = Steward.st()["acc"]
	if not a.has("smith") or not a["smith"] is Dictionary:
		a["smith"] = {"made": [], "made_n": 0, "repairs": [], "repairs_n": 0, "repair_gold": 0, "prepared": {}, "used": {}, "minutes": 0,
			"walk_minutes": 0, "ops": 0, "begun": 0, "nights": 0, "breaks": 0, "rests": 0, "abandoned": [], "xp_withheld": 0}
	return a["smith"]


static func _on() -> bool:
	return Steward.duty_on("smith")


static func _driven() -> bool:
	return driver != null and is_instance_valid(driver)


# ======================================================================= the routine Designs he may do
## "" when the smith may make this recipe under the steward, else why not: classic smithing only (his own trade —
## other crafts belong to specialists), a known, ordinary Design (no secret node, no forgotten recipe, nothing that
## teaches, no legendary-grade minimum rarity), unlocked with its stations, within the order rule and his own level.
static func recipe_ok(rid: String) -> String:
	var r := DB.recipe(rid)
	if r.is_empty():
		return "Unknown Design."
	if str(r.get("discipline", "classic")) != "classic":
		return "%s is a specialist's craft." % str(Crafting.DISCIPLINE_NAME.get(str(r.get("discipline", "")), "That"))
	if str(r.get("requires_flag", "")) != "" or str(r.get("teaches_flag", "")) != "" or str(r.get("min_rarity", "")) != "":
		return "%s is not routine work." % str(r.get("name", rid))
	if bool(SkillTree.node(SkillTree.recipe_node(rid)).get("secret", false)):
		return "%s is a secret Design." % str(r.get("name", rid))
	var why := Crafting.recipe_locked_reason(rid)
	if why != "":
		return why
	var d := Crafting.difficulty(rid)
	if d > int(Steward.st()["orders"]["order_rules"]["max_difficulty"]):
		return "Harder than your rule allows (difficulty %d)." % d
	if d > Game.player_level(Crafting.recipe_skill(rid)):
		return "Beyond routine work for him (difficulty %d)." % d
	return ""


static func can_make(rid: String) -> bool:
	return _on() and routine_ids().has(rid)


## The routine Designs (recipe ids) he may make today — recomputed when the day, his level, the order rule or the
## installed stations change (planning looks at them often; the answer rarely changes).
static var _routine_key := ""
static var _routine_ids: Array = []
static var _routine_state: Dictionary = {}


static func routine_ids() -> Array:
	var key := "%d|%d|%d|%d|%d" % [Game.day(), Game.player_level("smithing"), int(Steward.st()["orders"]["order_rules"]["max_difficulty"]),
		(Property.st()["stations"] as Dictionary).size(), (Game.state.get("skilltree", {}).get("nodes", []) as Array).size()]
	if key != _routine_key or not is_same(_routine_state, Game.state):
		_routine_key = key
		_routine_state = Game.state
		_routine_ids = []
		var ids := DB.recipes.keys()
		ids.sort()
		for rid_v in ids:
			if recipe_ok(str(rid_v)) == "":
				_routine_ids.append(str(rid_v))
	return _routine_ids


## His average craftsmanship for a recipe now (the Project Bench's automatic estimate, no luck), capped.
static func expected_quality(rid: String) -> float:
	return minf(QUALITY_CAP, Contracts.smith_hour_quality(rid))


static func _op_minutes(rid: String, op: Dictionary) -> float:
	var tm: Dictionary = Apprentices.cfg("time")
	var base := float(tm.get("op_base", 30.0)) + float(tm.get("per_check", 12.0)) * maxi(1, int(op.get("checks", 1)))
	return maxf(float(tm.get("min_op", 10.0)), base / maxf(0.25, Contracts.smith_pace(rid)))


static func _repair_minutes() -> float:
	return float(Apprentices.cfg("time").get("repair_minutes", 50.0)) / maxf(0.25, Contracts.smith_pace(""))


static func _repair_station() -> String:
	return str(Apprentices.cfg("time").get("repair_station", "grinding_wheel"))


## Rough minutes for a whole piece (operations and the walks between them).
static func est_minutes(rid: String) -> float:
	var m := 0.0
	for op in Crafting.operations(rid):
		m += _op_minutes(rid, op) + 3.0
	return m


## Minutes of work already waiting for him (the queue and the piece in hand).
static func backlog_minutes() -> float:
	var m := 0.0
	for e in sm()["queue"]:
		m += est_minutes(str(e["recipe"])) * float(maxi(1, int(e.get("repeat", 1)) - int(e.get("done", 0))))
	if Crafting.active() and Steward.marked(Crafting.job()):
		var j := Crafting.job()
		var ops := Crafting.operations(str(j["recipe"]))
		for i in range(int(j.get("step", 0)), ops.size()):
			m += _op_minutes(str(j["recipe"]), ops[i]) + 3.0
		m -= float(sm()["op_progress"])
	if not (sm()["job"] as Dictionary).is_empty():
		m += maxf(0.0, float(sm()["job"].get("need", 0.0)) - float(sm()["job"].get("progress", 0.0)))
	return maxf(0.0, m)


static func _hours() -> Array:
	var h: Variant = Steward.st()["orders"].get("smith_hours", [8, 18])
	if not h is Array or (h as Array).size() < 2:
		return [8, 18]
	return [int(h[0]), int(h[1])]


static func _has_break() -> bool:
	var h := _hours()
	return int(h[0]) < BREAK_START and int(h[1]) >= BREAK_END


## His working minutes in one day.
static func day_minutes() -> float:
	var h := _hours()
	return float(int(h[1]) - int(h[0])) * 60.0 - (60.0 if _has_break() else 0.0)


## His working minutes from now until the end of `last_day`.
static func shift_minutes_until(last_day: int) -> float:
	if last_day < Game.day():
		return 0.0
	var h := _hours()
	var start := int(h[0]) * 60
	var stop := int(h[1]) * 60
	var m := int(Game.state["minute"])
	var today := 0.0
	if m < stop:
		today = float(stop - maxi(m, start))
		if _has_break() and m < BREAK_END * 60:
			today -= float(mini(60, BREAK_END * 60 - maxi(m, BREAK_START * 60)))
	return maxf(0.0, today) + float(last_day - Game.day()) * day_minutes()


# ======================================================================= the day: work, break, rest, home, sleep
## What he should be doing now: "sleep" (22–6), "home" (outside working hours), "break" (12–13), "rest" (tired), "work".
static func want() -> String:
	var h := Game.hour()
	if h >= BED_HOUR or h < WAKE_HOUR:
		return "sleep"
	var hrs := _hours()
	if h < int(hrs[0]) or h >= int(hrs[1]):
		return "home"
	if _has_break() and h >= BREAK_START and h < BREAK_END:
		return "break"
	if Game.now() < int(sm()["rest_until"]) or Vitality.fatigue() >= TIRED:
		return "rest"
	return "work"


## Game.advance_minutes, every 5 game minutes while the steward runs the forge.
static func tick(minutes: int) -> void:
	if Game.state.is_empty() or not Steward.is_active():
		return
	var m := sm()
	match want():
		"sleep":
			_home("bed", "sleep", minutes)
		"break":
			_home("armchair", "break", minutes)
		"rest":
			_home("armchair", "rest", minutes)
		"home":
			_home("table" if Game.hour() < 12 else "armchair", "home", minutes)
		_:
			_work(minutes)


static func _home(place: String, kind: String, minutes: int) -> void:
	var m := sm()
	if not _reach(place, minutes):
		m["act"] = "walk"
		return
	m["act"] = kind
	match kind:
		"sleep":
			# a night in his own bed (the bed's rule: fatigue cleared, the night's hours add none)
			var wake := _next_wake()
			if int(m["sleep_until"]) != wake:
				m["sleep_until"] = wake
				m["rest_set"] = wake
				Vitality.sleep(wake - Game.now())
				acc()["nights"] = int(acc()["nights"]) + 1
		"break":
			if int(m["break_day"]) != Game.day():
				m["break_day"] = Game.day()
				var mins := maxi(5, BREAK_END * 60 - int(Game.state["minute"]))
				m["rest_set"] = Game.now() + mins
				Vitality.rest(mins, false)   # the midday break by the hearth (the armchair's rule)
				acc()["breaks"] = int(acc()["breaks"]) + 1
		"rest":
			if Game.now() >= int(m["rest_until"]):
				m["rest_until"] = Game.now() + 60
				m["rest_set"] = int(m["rest_until"])
				Vitality.rest(60, false)   # unsteady hands: an hour with his feet up
				acc()["rests"] = int(acc()["rests"]) + 1


static func _next_wake() -> int:
	var day_start := (Game.day() - 1) * 1440
	var w := day_start + WAKE_HOUR * 60
	if Game.now() >= w:
		w += 1440
	return w


# ======================================================================= walking
## Moves him towards `place` ("station:<id>", "bed", "armchair", "table"). True once he is there.
static func _reach(place: String, minutes: int) -> bool:
	var m := sm()
	if str(m["place"]) == place and not bool(m["walking"]):
		return true
	if str(m["goal"]) != place or not bool(m["walking"]):
		m["goal"] = place
		m["walking"] = true
		m["arrived"] = false
		m["walk_t"] = Game.now()
		m["walk_est"] = _walk_minutes(str(m["place"]), place)
		m["walk_left"] = float(m["walk_est"])
	if _driven():
		if bool(m["arrived"]) or Game.now() - int(m["walk_t"]) > int(float(m["walk_est"]) * STUCK_FACTOR) + 30:
			_arrive(place)
			return true
		return false
	m["walk_left"] = float(m["walk_left"]) - float(minutes)
	acc()["walk_minutes"] = int(acc()["walk_minutes"]) + minutes
	if float(m["walk_left"]) <= 0.0:
		_arrive(place)
		return true
	return false


static func _arrive(place: String) -> void:
	var m := sm()
	m["place"] = place
	m["walking"] = false
	m["arrived"] = false
	m["goal"] = ""


## Where the world should take him now ("" = stay).
static func goal() -> String:
	if Game.state.is_empty() or not Steward.is_active():
		return ""
	var m := sm()
	return str(m["goal"]) if bool(m["walking"]) else ""


## The world's actor: he has reached `place`.
static func arrived(place: String) -> void:
	if Game.state.is_empty():
		return
	var m := sm()
	if bool(m["walking"]) and str(m["goal"]) == place:
		m["arrived"] = true


## Estimated walk in game minutes (no world): station to station by distance, to and from the quarters, floors.
static func _walk_minutes(from: String, to: String) -> float:
	if from == to:
		return 0.0
	if from == "":
		return DEFAULT_WALK
	var fs := from.trim_prefix("station:") if from.begins_with("station:") else ""
	var ts := to.trim_prefix("station:") if to.begins_with("station:") else ""
	if fs != "" and ts != "":
		var d := Property.pos_of(fs).distance_to(Property.pos_of(ts))
		var floors := 0.0 if Property.station_floor(fs) == Property.station_floor(ts) else FLOOR_WALK
		return snappedf(WALK_MIN + d * WALK_PER_TILE + floors, 0.5)
	if fs == "" and ts == "":
		return WALK_MIN
	var st := fs if fs != "" else ts
	return HOME_WALK + (0.0 if Property.station_floor(st) == "ground" else FLOOR_WALK)


# ======================================================================= work
static func _work(minutes: int) -> void:
	var m := sm()
	if not (m["job"] as Dictionary).is_empty():
		_work_repair(minutes)
		return
	if Crafting.active():
		if not Steward.marked(Crafting.job()):
			m["act"] = "idle"   # never the smith's own piece in hand (activation refuses it; kept for safety)
			m["why_idle"] = "A piece of your own lies at the station; the steward leaves it alone."
			return
		# between two operations a waiting customer comes first
		if float(m["op_progress"]) <= 0.0 and not bool(m["walking"]) and _take_repair():
			_work_repair(minutes)
			return
		_work_piece(minutes)
		return
	if not _on():
		m["act"] = "idle"
		m["why_idle"] = "His own work is not among the steward's duties."
		return
	if _take_repair():
		_work_repair(minutes)
		return
	if _start_next():
		_work_piece(minutes)
		return
	m["act"] = "idle"


static func _work_piece(minutes: int) -> void:
	var m := sm()
	var j := Crafting.job()
	var sid := Crafting.current_station()
	if sid == "":
		_finish_piece()
		return
	if float(m["op_progress"]) <= 0.0:
		var why := Crafting.station_locked_reason(sid)
		if why != "":
			m["act"] = "idle"
			m["why_idle"] = "The %s is not available — %s" % [str(DB.station(sid).get("name", sid)), why]
			Steward._stall("smith", "station", m["why_idle"])
			return
	if not _reach("station:" + sid, minutes):
		m["act"] = "walk"
		return
	m["act"] = "work"
	if float(m["op_need"]) <= 0.0:
		m["op_need"] = _op_minutes(str(j["recipe"]), Crafting.current_op())
	m["op_progress"] = float(m["op_progress"]) + float(minutes)
	acc()["minutes"] = int(acc()["minutes"]) + minutes
	if float(m["op_progress"]) >= float(m["op_need"]):
		_finish_op()


## One operation done: his checks at an average performance for his skill and freshness (seeded), recorded as the
## operation's samples through Crafting.record_step (which adds the operation's fatigue).
static func _finish_op() -> void:
	var m := sm()
	var j := Crafting.job()
	var op := Crafting.current_op()
	var sid := str(op.get("station", ""))
	var rid := str(j["recipe"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|%d|smith" % [rid, int(j.get("day", 0)), int(j.get("step", 0)), Game.now()])
	var qs: Array = []
	for i in maxi(1, int(op.get("checks", 1))):
		qs.append(snappedf(minf(QUALITY_CAP, Contracts.smith_hour_quality(rid, rng)), 0.1))
	Crafting.record_step(sid, qs)
	m["op_progress"] = 0.0
	m["op_need"] = 0.0
	m["ops_n"] = int(m["ops_n"]) + 1
	acc()["ops"] = int(acc()["ops"]) + 1
	if Crafting.current_station() == "":
		_finish_piece()


## The piece is done: dice from his craftsmanship (seeded, like an apprentice's), Crafting.build as the smith.
static func _finish_piece() -> void:
	var m := sm()
	var j := Crafting.job()
	if j.is_empty():
		return
	var rid := str(j["recipe"])
	var mark: Dictionary = j.get("steward", {})
	var base := Crafting.base_quality(j)
	var q := minf(base, QUALITY_CAP)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|smith_dice" % [rid, int(j.get("day", 0)), Game.now()])
	var dice := Apprentices.roll_dice(DB.recipe(rid).get("dice", {}), q, rng)
	var it := Crafting.build(rid, j.get("ops", []), q, dice, "digital", {}, base)
	m["op_progress"] = 0.0
	m["op_need"] = 0.0
	if it.is_empty():
		return
	var cr: Dictionary = it.get("craft", {})
	cr["steward"] = true          # made by the smith's hand while the steward ran the forge
	cr["tree_bonus"] = 0.0        # his automatic, average work: no technique or assistant bonus was applied
	cr["assist_bonus"] = 0.0
	var purpose := str(mark.get("purpose", "restock"))
	var oid := str(mark.get("order_id", ""))
	var nm := Items.display_name(it)
	var a := acc()
	var sacc: Dictionary = Steward.st()["acc"]
	var line := ""
	if Items.is_equipment(it):
		(sacc["made"] as Array).append(int(it["uid"]))
		sacc["made_n"] = int(sacc["made_n"]) + 1
		var rec := {"uid": int(it["uid"]), "name": nm, "quality": snappedf(q, 0.1), "purpose": purpose, "day": Game.day(), "rarity": str(it.get("rarity", "common"))}
		if purpose == "commission":
			var o := Steward._order(oid)
			if not o.is_empty() and str(o.get("status", "")) == "open" and Shop.item_meets(o, it):
				it["for_order"] = oid
				rec["for"] = Talk.npc_name(str(o.get("npc", "")))
				line = "The smith finished %s (%d%%) for %s's commission." % [nm, int(round(q)), Talk.npc_name(str(o.get("npc", "")))]
			else:
				m["tries"][oid] = int(m["tries"].get(oid, 0)) + 1
				line = "The smith finished %s (%d%%); it does not meet the commission and went to the stores." % [nm, int(round(q))]
		else:
			line = "The smith finished %s (%d%%) for the display." % [nm, int(round(q))]
		(a["made"] as Array).append(rec)
		while (a["made"] as Array).size() > 60:
			(a["made"] as Array).pop_front()
		a["made_n"] = int(a["made_n"]) + 1
	else:
		var out := str(it["def"])
		var per := maxi(1, int(DB.recipe(rid).get("qty", 1)))
		var got := int(it.get("qty", per))
		a["prepared"][out] = int(a["prepared"].get(out, 0)) + got
		var pr: Dictionary = sacc["produced"].get(out, {"n": 0, "qty": 0, "max": 0})
		pr["n"] = int(pr["n"]) + 1
		pr["qty"] = int(pr["qty"]) + got
		pr["max"] = int(pr["max"]) + per + 1
		sacc["produced"][out] = pr
		line = "The smith prepared %d %s (%d%%)." % [got, str(DB.item(out).get("name", out)), int(round(q))]
	_consume_entry(int(mark.get("qid", -1)))
	Steward._log("smith_made", line, {"uid": int(it["uid"]), "recipe": rid, "quality": snappedf(q, 0.1), "purpose": purpose}, false)


static func _consume_entry(qid: int) -> void:
	var q: Array = sm()["queue"]
	for i in q.size():
		if int(q[i]["id"]) == qid:
			q[i]["done"] = int(q[i].get("done", 0)) + 1
			if int(q[i]["done"]) >= int(q[i].get("repeat", 1)):
				q.remove_at(i)
			return


## Materials free for him: the stores less reserved supplies and what the apprentices' open tasks still need.
static func _free(def_id: String, app_need: Dictionary, held: Dictionary) -> int:
	return Game.count(def_id) - Steward._reserved(def_id) - int(app_need.get(def_id, 0)) - int(held.get(def_id, 0))


## Starts the first queued piece whose materials are in the stores (commissions first, then preparation, then the
## display). True when a piece is in hand.
static func _start_next() -> bool:
	var m := sm()
	var q: Array = m["queue"]
	if q.is_empty():
		m["why_idle"] = str(m.get("why_idle", "")) if str(m.get("why_idle", "")) != "" else "Nothing planned for him right now."
		return false
	# nothing could start a moment ago: look again with the steward's next quarter hour (materials come by then)
	if int(m.get("start_fail_t", -1000)) >= 0 and Game.now() - int(m["start_fail_t"]) < 15 and q.size() == int(m.get("start_fail_n", -1)):
		return false
	var order := q.duplicate()
	order.sort_custom(func(a, b):
		var pa := int(PURPOSE_ORDER.get(str(a["purpose"]), 3))
		var pb := int(PURPOSE_ORDER.get(str(b["purpose"]), 3))
		if pa != pb:
			return pa < pb
		return int(a["id"]) < int(b["id"]))
	var app_need := Steward._needs(false)
	var held := {}
	var short := ""
	for e in order:
		var rid := str(e["recipe"])
		var why := "" if routine_ids().has(rid) else recipe_ok(rid)
		if why == "" and str(e["purpose"]) == "commission":
			var o := Steward._order(str(e.get("order_id", "")))
			if o.is_empty() or str(o.get("status", "")) != "open":
				why = "the commission is no longer open"
		if why != "":
			q.erase(e)
			Steward._log("cancel", "Took %s off the smith's work — %s" % [str(DB.recipe(rid).get("name", rid)), why.trim_suffix(".").to_lower()], {"recipe": rid}, false)
			continue
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		var ok := true
		for d in inputs:
			if _free(str(d), app_need, held) < int(inputs[d]):
				ok = false
				short = "waiting for %s" % str(DB.item(str(d)).get("name", d)).to_lower()
		if not ok:
			for d2 in inputs:
				held[str(d2)] = int(held.get(str(d2), 0)) + int(inputs[d2])
			continue
		if not Crafting.start(rid):
			continue
		Game.state["craft"]["steward"] = {"qid": int(e["id"]), "purpose": str(e["purpose"]), "order_id": str(e.get("order_id", "")),
			"t": Game.now(), "session": int(Steward.st().get("sessions", 0))}
		m["op_progress"] = 0.0
		m["op_need"] = 0.0
		m["why_idle"] = ""
		var a := acc()
		a["begun"] = int(a["begun"]) + 1
		for d3 in inputs:
			a["used"][str(d3)] = int(a["used"].get(str(d3), 0)) + int(inputs[d3])
		var what: String = {"commission": "for %s's commission" % Talk.npc_name(str(Steward._order(str(e.get("order_id", ""))).get("npc", ""))),
			"prep": "to prepare materials", "restock": "for the display"}.get(str(e["purpose"]), "")
		Steward._log("smith_begin", "The smith set to work on %s %s." % [str(DB.recipe(rid).get("name", rid)), what],
			{"recipe": rid, "purpose": str(e["purpose"])})
		m["start_fail_t"] = -1000
		return true
	m["why_idle"] = ("Planned work is " + short + ".") if short != "" else "Nothing he can start right now."
	m["start_fail_t"] = Game.now()
	m["start_fail_n"] = q.size()
	return false


# ======================================================================= repairs at the counter
## Takes on a waiting customer's repair (or a repair part of a visitor with several requests) when he can finish
## before they give up. Protected pieces are left for the smith himself (deferred). True when a repair is in hand.
static func _take_repair() -> bool:
	if not _on() or not Steward.duty_on("repairs"):
		return false
	# the same customers as a moment ago, none of whom he could take: look again with the next quarter hour
	var m := sm()
	var sig := ""
	for c0 in Shop.waiting():
		sig += "%s:%d:%s;" % [str(c0["npc"]), int(c0.get("arrived", 0)), str(c0.get("want", ""))]
	if sig == "" or (sig == str(m.get("rep_sig", "")) and Game.now() - int(m.get("rep_t", -1000)) < 15):
		return false
	m["rep_sig"] = sig
	m["rep_t"] = Game.now()
	var sid := _repair_station()
	if not Property.is_installed(sid) or Crafting.station_locked_reason(sid) != "":
		return false
	for c in Shop.waiting():
		var npc := str(c["npc"])
		if str(c.get("want", "")) != "repair" or Steward._personal(npc):
			continue
		if c.has("parts"):
			for pt in c.get("parts", []):
				if str(pt.get("kind", "")) == "repair" and str(pt.get("status", "")) == "pending" and will_mend(npc, pt):
					_set_repair(c, str(pt.get("pid", "")), _part_item(npc, pt))
					return true
			continue
		if Game.state.has("apprentices") and Apprentices.open_tasks().any(func(t): return str(t["kind"]) == "repair" and str(t["target"]) == npc):
			continue
		var it := Apprentices.repair_item({"kind": "repair", "target": npc})
		if it.is_empty():
			continue
		var prot := Steward.protection_reason(it)
		if prot != "" and not prot.begins_with("You marked"):
			Steward.defer_protected_repair(c, it, prot)
			continue
		if _repair_need() > Steward._patience_minutes(c):
			continue
		_set_repair(c, "", it)
		return true
	for c2 in Shop.waiting():
		# a visitor with several requests whose repair part is in the list too (want "multi")
		if str(c2.get("want", "")) != "multi" or Steward._personal(str(c2["npc"])):
			continue
		for pt2 in c2.get("parts", []):
			if str(pt2.get("kind", "")) == "repair" and str(pt2.get("status", "")) == "pending" and will_mend(str(c2["npc"]), pt2):
				_set_repair(c2, str(pt2.get("pid", "")), _part_item(str(c2["npc"]), pt2))
				return true
	return false


static func _part_item(npc: String, pt: Dictionary) -> Dictionary:
	if pt.has("own_slot"):
		return Adv.get_a(npc).get("equipment", {}).get(str(pt["own_slot"]), {})
	var it: Variant = ItemRegistry.resolve(pt.get("item", {}))
	return it if it is Dictionary else {}


## Minutes before he could have a repair done: what is left of the operation in hand, the walk and the mending.
static func _repair_need() -> float:
	var m := sm()
	var busy := 0.0
	if Crafting.active() and float(m["op_progress"]) > 0.0:
		busy = maxf(0.0, float(m["op_need"]) - float(m["op_progress"]))
	if want() != "work":
		busy += 60.0
	return busy + _walk_minutes(str(m["place"]), "station:" + _repair_station()) + _repair_minutes() * 1.1


## Will he mend this repair part himself (it is ordinary and he can finish before the visitor gives up)?
static func will_mend(npc: String, pt: Dictionary) -> bool:
	if not _on() or not Steward.duty_on("repairs") or str(pt.get("kind", "")) != "repair":
		return false
	var sid := _repair_station()
	if not Property.is_installed(sid) or Crafting.station_locked_reason(sid) != "":
		return false
	var it := _part_item(npc, pt)
	if it.is_empty() or Steward.protection_reason(it) != "":
		return false
	var c := Shop.customer(npc)
	if c.is_empty():
		return false
	var m := sm()
	if not (m["job"] as Dictionary).is_empty() and str(m["job"].get("npc", "")) != npc:
		return false
	return _repair_need() <= Steward._patience_minutes(c)


static func _set_repair(c: Dictionary, pid: String, it: Dictionary) -> void:
	var m := sm()
	m["job"] = {"kind": "repair", "npc": str(c["npc"]), "arrived": int(c.get("arrived", 0)), "pid": pid,
		"name": str(it.get("name", "piece")), "need": _repair_minutes(), "progress": 0.0}
	m["why_idle"] = ""
	Steward._log("smith_begin", "The smith took %s's %s to the %s." % [Talk.npc_name(str(c["npc"])), str(it.get("name", "piece")).to_lower(),
		str(DB.station(_repair_station()).get("name", "wheel")).to_lower()], {"npc": str(c["npc"]), "purpose": "repair"})


## Is he on shift with nothing in hand (the steward then plans at once rather than on the hour — at most every half
## hour, so a smith with nothing to do does not have the whole catalogue looked over every quarter)?
static func idle() -> bool:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return false
	var m := sm()
	return str(m["act"]) == "idle" and want() == "work" and not Crafting.active() and Game.now() - int(m.get("plan_t", -1000)) >= 30


static func claims(npc: String) -> bool:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return false
	return str(sm()["job"].get("npc", "")) == npc


static func _still_waiting(job: Dictionary) -> bool:
	var c := Shop.customer(str(job.get("npc", "")))
	if c.is_empty() or int(c.get("arrived", -1)) != int(job.get("arrived", -2)) or not bool(c.get("present", true)):
		return false
	if str(job.get("pid", "")) != "":
		for pt in c.get("parts", []):
			if str(pt.get("pid", "")) == str(job["pid"]):
				return str(pt.get("status", "")) == "pending"
		return false
	return str(c.get("want", "")) == "repair"


static func _work_repair(minutes: int) -> void:
	var m := sm()
	var job: Dictionary = m["job"]
	if not _still_waiting(job):
		(acc()["abandoned"] as Array).append("%s left before the smith had mended their %s." % [Talk.npc_name(str(job.get("npc", ""))), str(job.get("name", "piece")).to_lower()])
		m["job"] = {}
		m["act"] = "idle"
		return
	var sid := _repair_station()
	if not _reach("station:" + sid, minutes):
		m["act"] = "walk"
		return
	var user := Apprentices.station_user(sid) if Game.state.has("apprentices") else ""
	if user != "" and user != "smith":
		m["act"] = "wait"
		return
	m["act"] = "work"
	job["progress"] = float(job["progress"]) + float(minutes)
	acc()["minutes"] = int(acc()["minutes"]) + minutes
	if float(job["progress"]) >= float(job["need"]):
		_finish_repair()


static func _finish_repair() -> void:
	var m := sm()
	var job: Dictionary = m["job"]
	var npc := str(job["npc"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|smith_repair" % [npc, int(job.get("arrived", 0)), Game.now()])
	var q := snappedf(minf(QUALITY_CAP, Contracts.smith_hour_quality("", rng)), 0.1)
	var g0 := Game.gold()
	if str(job.get("pid", "")) != "":
		Shop.repair_part(npc, str(job["pid"]), q)
	else:
		Shop.do_repair(npc, q, "")   # his own hand at the wheel; the customer pays from their own purse (A2)
	var paid := Game.gold() - g0
	var a := acc()
	(a["repairs"] as Array).append({"npc": npc, "who": Talk.npc_name(npc), "name": str(job.get("name", "")), "quality": q, "paid": paid, "day": Game.day()})
	while (a["repairs"] as Array).size() > 40:
		(a["repairs"] as Array).pop_front()
	a["repairs_n"] = int(a["repairs_n"]) + 1
	a["repair_gold"] = int(a["repair_gold"]) + paid
	m["job"] = {}
	m["ops_n"] = int(m["ops_n"]) + 1
	Steward._log("smith_repair", "The smith mended %s's %s (%d%%) — %s paid %d g." % [Talk.npc_name(npc), str(job.get("name", "piece")).to_lower(), int(round(q)),
		Talk.npc_name(npc), paid], {"npc": npc, "gold": paid, "quality": q})


# ======================================================================= planning (hourly, from Steward.tick)
static func _queued(purpose: String) -> Array:
	return (sm()["queue"] as Array).filter(func(e): return str(e["purpose"]) == purpose)


static func _in_hand_purpose() -> String:
	if Crafting.active() and Steward.marked(Crafting.job()):
		return str(Crafting.job()["steward"].get("purpose", ""))
	return ""


static func has_order(oid: String) -> bool:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return false
	if (sm()["queue"] as Array).any(func(e): return str(e.get("order_id", "")) == oid):
		return true
	return Crafting.active() and Steward.marked(Crafting.job()) and str(Crafting.job()["steward"].get("order_id", "")) == oid


static func _enqueue(purpose: String, rid: String, extra := {}) -> Dictionary:
	var m := sm()
	var e := {"id": int(m["next_q"]), "purpose": purpose, "recipe": rid, "repeat": 1, "done": 0, "t": Game.now()}
	for k in extra:
		e[k] = extra[k]
	m["next_q"] = int(m["next_q"]) + 1
	(m["queue"] as Array).append(e)
	return e


static func enqueue_commission(oid: String, rid: String) -> void:
	_enqueue("commission", rid, {"order_id": oid})


## Materials the counters do not sell, prepared by the smith himself (e.g. smelting iron for a blade). True if queued.
static func enqueue_prep(def_id: String, short: int) -> bool:
	if not _on() or _queued("prep").any(func(e): return str(e.get("def", "")) == def_id):
		return false
	var rid := Steward._prep_recipe(def_id)
	if rid == "" or recipe_ok(rid) != "":
		return false
	var per := maxi(1, int(DB.recipe(rid).get("qty", 1)))
	var runs := clampi(int(ceil(float(short) / float(per))), 1, PREP_RUNS)
	_enqueue("prep", rid, {"repeat": runs, "def": def_id})
	Steward._log("prep", "The smith will prepare %s himself: %s ×%d for the planned work." % [str(DB.item(def_id).get("name", def_id)),
		str(DB.recipe(rid).get("name", rid)), runs], {"recipe": rid, "def": def_id})
	return true


## Materials still to be taken by his queued (not yet started) work: {def: n}.
static func queue_needs() -> Dictionary:
	var need := {}
	if Game.state.is_empty() or not Game.state.has("steward") or not Steward.st().has("smith"):
		return need
	for e in sm()["queue"]:
		var left := maxi(0, int(e.get("repeat", 1)) - int(e.get("done", 0)))
		var inputs: Dictionary = DB.recipe(str(e["recipe"])).get("inputs", {})
		for d in inputs:
			need[str(d)] = int(need.get(str(d), 0)) + int(inputs[d]) * left
	return need


## Hourly: tidies the queue and plans a piece for the display when it runs short.
static func plan() -> void:
	if not _on():
		return
	var m := sm()
	var q: Array = m["queue"]
	for e in q.duplicate():
		match str(e["purpose"]):
			"commission":
				var o := Steward._order(str(e.get("order_id", "")))
				if o.is_empty() or str(o.get("status", "")) != "open":
					q.erase(e)
			"restock":
				if Game.now() - int(e.get("t", 0)) > 2880:   # waited two days for its materials: plan afresh
					q.erase(e)
			"prep":
				if Game.now() - int(e.get("t", 0)) > 4320 and int(e.get("done", 0)) == 0:
					q.erase(e)
	var h := Game.hour()
	var hrs := _hours()
	if Steward.duty_on("production") and h >= int(hrs[0]) - 1 and h < int(hrs[1]) - 1:
		_plan_restock()


## A piece for the display when it holds fewer than the selling rules' target (counting what is being made).
static func _plan_restock() -> void:
	var rules: Dictionary = Steward.st()["orders"]["sell_rules"]
	if not bool(rules["list_new_work"]) or int(rules["stock_target"]) <= 0:
		return
	if not _queued("restock").is_empty() or _in_hand_purpose() == "restock":
		return
	var shown := 0
	var by_def := {}
	for it in Shop.stock():
		if Items.is_equipment(it):
			shown += 1
			by_def[str(it["def"])] = int(by_def.get(str(it["def"]), 0)) + 1
	var coming := 0
	if Game.state.has("apprentices"):
		var mine: Dictionary = Steward.st()["mine"]
		for k in mine:
			if str(mine[k]) == "restock":
				coming += 1
	if shown + coming >= int(rules["stock_target"]):
		return
	var blk := Steward._spend_block()
	var need := Steward._needs()
	var best := {}
	var best_score := -99999.0
	var why_none := "No ordinary piece he can make right now."
	sm()["plan_t"] = Game.now()
	for rid_v in routine_ids():
		var rid := str(rid_v)
		var out := str(DB.recipe(rid).get("output", ""))
		if not Items.is_equipment({"def": out}):
			continue
		var plan := Steward._material_plan(rid, need)
		if str(plan["why"]) != "":
			why_none = str(plan["why"])
			continue
		if int(plan["cost"]) > 0 and (blk != "" or int(plan["cost"]) > Steward.spendable()):
			why_none = "Materials for a new piece would break the spending limits (the purse is at or near the reserve)."
			continue
		var value := Items.value({"def": out, "quality": expected_quality(rid)})
		var cost := 0
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		for d in inputs:
			var sp := Steward._shop_price(str(d))
			cost += int(inputs[d]) * (int(sp["price"]) if not sp.is_empty() else int(DB.item(str(d)).get("value", 5)))
		var margin := float(value - cost)
		if margin <= 0.0:
			continue
		var score := margin - 25.0 * float(by_def.get(out, 0))
		if score > best_score:
			best_score = score
			best = {"rid": rid, "value": value, "cost": cost}
	if best.is_empty():
		Steward._stall("smith", "restock", why_none)
		sm()["why_idle"] = why_none
		return
	Steward._unstall("smith")
	_enqueue("restock", str(best["rid"]))
	Steward._log("restock", "The smith will make %s for the display (worth about %d g, materials about %d g)." % [str(DB.recipe(str(best["rid"])).get("name", best["rid"])),
		int(best["value"]), int(best["cost"])], {"recipe": str(best["rid"]), "by": "smith"})


## The routine Design the smith would use for an order (the easiest that should meet it at his average work), or "".
static func commission_recipe(o: Dictionary) -> String:
	if o.is_empty():
		return ""
	if str(o.get("recipe", "")) != "":
		return str(o["recipe"]) if recipe_ok(str(o["recipe"])) == "" else ""
	var best := ""
	var best_d := 999
	var best_margin := -999.0
	for rid_v in routine_ids():
		var rid := str(rid_v)
		var r := DB.recipe(rid)
		var out := str(r.get("output", ""))
		if o.has("def"):
			if out != str(o["def"]):
				continue
		elif str(DB.item(out).get("slot", "")) != str(o.get("slot", "")):
			continue
		var margin := 0.0
		if not o.has("def"):
			if Items.tier({"def": out}) < int(o.get("tier", 1)):
				continue
			var est := Crafting.compute_stats(DB.item(out), expected_quality(rid), {}, r.get("dice", {}), Crafting.material(rid),
				Game.player_level(Crafting.recipe_skill(rid)))
			margin = float(est.get(str(o.get("stat", "")), 0)) - float(o.get("min", 0))
			if margin < 1.0:
				continue
		var d := Crafting.difficulty(rid)
		if d < best_d or (d == best_d and margin > best_margin):
			best = rid
			best_d = d
			best_margin = margin
	return best


## Can the smith himself make this order in time? {ok, rid, who: "smith", cost, why}.
static func order_plan(o: Dictionary, need: Dictionary) -> Dictionary:
	if not _on():
		return {"ok": false, "why": "His own work is not among the steward's duties."}
	var oid := str(o.get("id", ""))
	if int(sm()["tries"].get(oid, 0)) >= 1:
		return {"ok": false, "why": "His piece fell short of it once; the rest is for you to decide."}
	var rid := commission_recipe(o)
	if rid == "":
		var r0 := str(o.get("recipe", ""))
		return {"ok": false, "why": recipe_ok(r0) if r0 != "" and recipe_ok(r0) != "" else "He has no routine Design that would meet it."}
	var plan := Steward._material_plan(rid, need)
	if str(plan["why"]) != "":
		return {"ok": false, "why": str(plan["why"])}
	var rules: Dictionary = Steward.st()["orders"]["order_rules"]
	var mins := est_minutes(rid) + float(plan.get("minutes", 0.0)) + backlog_minutes()
	var avail := shift_minutes_until(int(o.get("deadline", Game.day()))) - float(rules["deadline_margin"]) * day_minutes()
	if mins > avail:
		var days_need := int(ceil(mins / maxf(60.0, day_minutes())))
		return {"ok": false, "why": "Not enough time before the deadline (about %d working day%s for the smith, his queue included)." % [days_need, "" if days_need == 1 else "s"]}
	return {"ok": true, "rid": rid, "who": "smith", "app": "", "cost": int(plan["cost"]), "why": ""}


# ======================================================================= the session
static func on_activate() -> void:
	var m := sm()
	m["walking"] = false
	m["arrived"] = false
	m["goal"] = ""
	m["place"] = ""
	m["job"] = {}
	m["act"] = "idle"
	m["why_idle"] = ""
	m["rest_until"] = -1
	if not (Crafting.active() and Steward.marked(Crafting.job())):
		m["op_progress"] = 0.0
		m["op_need"] = 0.0
	acc()


## The smith takes the workshop back (or the save was loaded): a repair in hand is set down (the customer still waits,
## nothing was done to the piece); a piece in hand stays at the station — his to finish (no experience) or set aside;
## a rest or night's sleep the steward began ends (he is up).
static func on_stand_down() -> void:
	if Game.state.is_empty() or not Game.state.has("steward") or not Steward.st().has("smith"):
		return
	var m := sm()
	if not (m["job"] as Dictionary).is_empty():
		(acc()["abandoned"] as Array).append("The repair of %s's %s was set down when you took the workshop back." % [Talk.npc_name(str(m["job"].get("npc", ""))),
			str(m["job"].get("name", "piece")).to_lower()])
	m["job"] = {}
	m["walking"] = false
	m["goal"] = ""
	m["act"] = "idle"
	var p: Dictionary = Game.state.get("player", {})
	if int(p.get("resting_until", -1)) > Game.now() and int(p.get("resting_until", -1)) == int(m.get("rest_set", -2)):
		p["resting_until"] = Game.now()
	m["rest_until"] = -1


# ======================================================================= words
static func _place_text(place: String) -> String:
	if place.begins_with("station:"):
		return Smithy.station_ref(place.trim_prefix("station:"))
	return str(PLACE_NAME.get(place, "the workshop"))


static func _activity() -> String:
	var m := sm()
	var hrs := _hours()
	match str(m["act"]):
		"walk":
			var g := str(m["goal"])
			var why := ""
			match want():
				"sleep":
					why = " — bedtime"
				"break":
					why = " — the midday break"
				"rest":
					why = " — his hands need a rest"
				"home":
					why = " — the day's work is done" if Game.hour() >= 12 else ""
			return "On his way to %s%s" % [_place_text(g), why]
		"work":
			if not (m["job"] as Dictionary).is_empty():
				return "Mending %s's %s at %s" % [Talk.npc_name(str(m["job"]["npc"])), str(m["job"].get("name", "piece")).to_lower(), Smithy.station_ref(_repair_station())]
			if Crafting.active():
				var j := Crafting.job()
				return "%s at %s — %s (step %d of %d)" % [str(Crafting.current_op().get("op", "Working")), Smithy.station_ref(Crafting.current_station()),
					str(DB.recipe(str(j["recipe"])).get("name", j["recipe"])), int(j.get("step", 0)) + 1, Crafting.operations(str(j["recipe"])).size()]
			return "At work"
		"wait":
			return "Waiting for %s (an apprentice is using it)" % Smithy.station_ref(_repair_station())
		"sleep":
			return "Asleep in his bed until %02d:00" % WAKE_HOUR
		"break":
			return "The midday break by the hearth (until %02d:00)" % BREAK_END
		"rest":
			return "Resting an hour by the hearth — his hands were getting unsteady"
		"home":
			return ("Up and breakfasting — work starts at %02d:00" % int(hrs[0])) if Game.hour() < int(hrs[0]) else "The evening at home after the day's work"
	var why2 := str(m.get("why_idle", ""))
	return "Tidying the forge — %s" % (why2.trim_suffix(".").to_lower() if why2 != "" else "nothing to start right now")


## For the plate and the panel: {act, activity, place, fatigue, band, piece {name, step, steps}, queue, repairs, made,
## minutes, hours}.
static func status() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return {}
	var m := sm()
	var piece := {}
	if Crafting.active() and Steward.marked(Crafting.job()):
		var j := Crafting.job()
		piece = {"recipe": str(j["recipe"]), "name": str(DB.recipe(str(j["recipe"])).get("name", j["recipe"])), "step": int(j.get("step", 0)),
			"steps": Crafting.operations(str(j["recipe"])).size(), "purpose": str(j["steward"].get("purpose", ""))}
	var a: Dictionary = Steward.st()["acc"].get("smith", {})
	return {"act": str(m["act"]), "activity": _activity(), "place": str(m["place"]),
		"fatigue": Vitality.fatigue(), "band": Vitality.band(), "piece": piece, "queue": (m["queue"] as Array).size(),
		"made": int(a.get("made_n", 0)), "repairs": int(a.get("repairs_n", 0)), "minutes": int(a.get("minutes", 0)), "on": _on(),
		"hours": _hours()}


## The smith's own work for the report (from the session's records and the state now).
static func report_part(since: Dictionary) -> Dictionary:
	var a: Dictionary = Steward.st()["acc"].get("smith", {})
	if a.is_empty():
		return {}
	var in_hand := {}
	if Crafting.active() and Steward.marked(Crafting.job()):
		var j := Crafting.job()
		in_hand = {"recipe": str(j["recipe"]), "name": str(DB.recipe(str(j["recipe"])).get("name", j["recipe"])), "step": int(j.get("step", 0)),
			"steps": Crafting.operations(str(j["recipe"])).size(), "station": Crafting.current_station()}
	var mins := int(a.get("minutes", 0))
	return {"made": (a.get("made", []) as Array).duplicate(true), "made_count": int(a.get("made_n", 0)),
		"repairs": (a.get("repairs", []) as Array).duplicate(true), "repairs_count": int(a.get("repairs_n", 0)), "repair_gold": int(a.get("repair_gold", 0)),
		"prepared": (a.get("prepared", {}) as Dictionary).duplicate(), "used": (a.get("used", {}) as Dictionary).duplicate(),
		"minutes": mins, "hours_text": "%d h %02d min" % [int(mins / 60), mins % 60], "walk_minutes": int(a.get("walk_minutes", 0)),
		"ops": int(a.get("ops", 0)), "begun": int(a.get("begun", 0)), "nights": int(a.get("nights", 0)), "breaks": int(a.get("breaks", 0)),
		"rests": int(a.get("rests", 0)), "abandoned": (a.get("abandoned", []) as Array).duplicate(), "in_hand": in_hand,
		"xp_withheld": int(a.get("xp_withheld", 0)), "xp_unchanged": str(since.get("skills", "")) == "" or str(since.get("skills", "")) == JSON.stringify(Game.player_skills()),
		"fatigue": snappedf(Vitality.fatigue(), 0.1), "band": Vitality.band()}
