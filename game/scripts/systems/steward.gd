## Steward — Steward Mode's decision layer (Milestone S1; canonical v1.1 §4.5; contract docs/STEWARD_MODE_DESIGN.md).
## EN: While the player has handed the running workshop to a steward (and the game process runs), the steward manages
##     the ROUTINE business of the forge every 15 game minutes, only through the actions a player would use:
##     commissions are taken on by queuing apprentice work (Apprentices.add_task), counter parts accepted or declined
##     (Shop.accept_part / decline_part), finished commissions delivered (Shop.fulfil), materials bought at the village
##     counters while they are open (Trade.buy_store), new workshop pieces put on display (Shop.set_for_sale) and sold
##     to waiting customers at the listed price (Shop.sell_to / sell_goods). Wages and upkeep are paid by the normal
##     daily loop. The steward never crafts (the smith is away and gains no crafting experience), never edits state to
##     conjure gold, items or progress, never acts offline and never catches up: a loaded save starts with the mode OFF.
##     Each duty: evaluate → choose → act through an adapter → record (or record a stall reason once per change).
##     Matters it may not decide (major contract letters, independence notices, advice visitors, disputes, fame
##     commissions, famous pieces' deeds and losses, deaths touching the smith's work, the spouse's affairs) are
##     DEFERRED from the real events that raised them; the genuinely significant ones arrive as sealed letters.
##     On return, report() builds "While You Were Away" purely from recorded steward events, ledger lines, Lore events
##     and the difference between the activation snapshot and now.
##     State: Game.state["steward"] (created lazily — old saves load unchanged; see the design doc §4).
## DA: Forvalteren driver værkstedets rutine, mens smeden er væk — kun gennem spillets egne handlinger, inden for de
##     stående instrukser. Vigtige sager udskydes til smeden (forseglede breve for de betydningsfulde). Ingen offline-
##     fremgang: et indlæst spil starter altid med tilstanden slået fra.
##
## Public API (static) — see docs/STEWARD_MODE_DESIGN.md §3.1 for the full list with return shapes:
##   can_activate() -> String   activate() -> String   deactivate() -> Dictionary (the report)   is_active() -> bool
##   smith_away() -> bool       tick()  (Game.advance_minutes, every 15 min while active)   on_loaded()  (Game.from_save)
##   orders() -> Dictionary     default_orders() -> Dictionary   set_orders(patch) -> String   purchase_categories() -> Array
##   protect(uid, on) -> String   reserve(def, n) -> String   protection_reason(it) -> String
##   defer(kind, text, source, sealed := false, action := {}) -> Dictionary   deferred(include_resolved := false) -> Array
##   letters() -> Array   open_letter(id) -> Dictionary   resolve(id) -> String
##   report() -> Dictionary   last_report() -> Dictionary   take_pending_report() -> Dictionary
##   status() -> Dictionary   recent_log(n := 20) -> Array   stats() -> Dictionary   note_ledger(amount, cat, note)
##   duty_on(d) -> bool   spendable() -> int   min_price(it) -> int
class_name Steward
extends RefCounted

const DUTIES := ["orders", "repairs", "production", "replenish", "sales", "upkeep", "contracts"]
const DUTY_NAME := {"orders": "Take on ordinary commissions", "repairs": "Customers' repairs (apprentices)",
	"production": "Production & restocking", "replenish": "Buy materials at the village counters",
	"sales": "Display & counter sales", "upkeep": "Upkeep, reserve & weekly provisions",
	"contracts": "Apprentice hours on contracts already accepted"}
const TICK_MINUTES := 15
const LOG_CAP := 400
const RECENT_LEDGER := 80
const VILLAGE_STORES := ["general_store", "herbalist"]
## A working shift in minutes (08–18 with the midday hour off) — for "can this be made before the deadline".
const SHIFT_MINUTES := 540.0
## Goods a "goods" customer asks for (Shop._add_customer).
const GOODS := ["potion_healing", "oil_whetstone"]
const SEALED_PATRONS := ["royal", "leader"]

## Runtime-only: the mode is on in THIS process. A loaded save never turns it on (on_loaded clears both flags).
static var _on := false
## The steward state dictionary whose keys st() has already completed (identity check; a loaded save is a new one).
static var _checked: Dictionary = {}


# ======================================================================= state
static func _fresh() -> Dictionary:
	return {"active": false, "since": {}, "orders": default_orders(), "log": [], "deferred": [], "next_id": 1,
		"stats": {"decisions": 0, "by_kind": {}, "stalled": {}}, "stall": {}, "acc": {}, "seen": {}, "mine": {},
		"last_report": {}, "pending_report": false, "sessions": 0}


## The state, created on first touch (old saves gain it lazily). Never called on the load path unless the key exists.
static func st() -> Dictionary:
	if Game.state.is_empty():
		return _fresh()
	if not Game.state.has("steward"):
		Game.state["steward"] = _fresh()
	var s: Dictionary = Game.state["steward"]
	if is_same(s, _checked):
		return s   # already completed in this process (a cheap path: st() is called many times a cycle)
	_checked = s
	var f := _fresh()
	for k in f:
		if not s.has(k):
			s[k] = f[k]
	_fill_orders(s["orders"])
	return s


static func is_active() -> bool:
	return _on and not Game.state.is_empty() and Game.state.has("steward") and bool(Game.state["steward"].get("active", false))


## While the steward runs the workshop the smith is away: the world should not let the player character act, and
## apprentices are not supervised by him.
static func smith_away() -> bool:
	return is_active()


static func _changed() -> void:
	Events.steward_changed.emit()


# ======================================================================= standing instructions
static func default_orders() -> Dictionary:
	var duties := {}
	for d in DUTIES:
		duties[d] = true
	return {
		"daily_limit": 120,          # gold the steward may spend on materials in one day
		"session_limit": 1500,       # … and in the whole time away
		"reserve": 150,              # never spend below this purse
		"buy_categories": ["Ore & metal", "Coal & fuel", "Hides & leather", "Thread & fibre", "Wood", "Herbs", "Reagents"],
		"duties": duties,
		"protected": [],             # uids the steward never sells, lists or hands over
		"reserved": {},              # def -> minimum kept in the stores
		"order_rules": {"max_difficulty": 4, "min_reward": 20, "deadline_margin": 1, "decline_unsuitable": true},
		"sell_rules": {"min_price_pct": 100, "list_new_work": true, "list_existing": false, "stock_target": 3, "sell_goods": true},
	}


static func _fill_orders(o: Dictionary) -> void:
	var d := default_orders()
	for k in d:
		if not o.has(k):
			o[k] = d[k]
		elif d[k] is Dictionary and o[k] is Dictionary and k != "reserved":
			for k2 in d[k]:
				if not (o[k] as Dictionary).has(k2):
					o[k][k2] = d[k][k2]


## A copy of the standing instructions (edit them through set_orders / protect / reserve).
static func orders() -> Dictionary:
	return (st()["orders"] as Dictionary).duplicate(true)


## The purchase categories the village counters deal in (Venues), for the instructions panel.
static func purchase_categories() -> Array:
	var seen := {}
	for vid in VILLAGE_STORES:
		for d in Venues.stock_defs(vid):
			seen[Venues.category_of(str(d))] = true
	var out: Array = []
	for c in Venues.CATEGORY_ORDER:
		if seen.has(c):
			out.append(c)
	return out


static func duty_on(d: String) -> bool:
	return bool(st()["orders"]["duties"].get(d, false))


## Validates and merges a partial set of instructions: {daily_limit, session_limit, reserve, buy_categories[],
## duties{duty: bool}, protected[uid], reserved{def: n}, order_rules{…}, sell_rules{…}}. "" = applied, else why not
## (nothing is applied then).
static func set_orders(patch: Dictionary) -> String:
	var cur: Dictionary = (st()["orders"] as Dictionary).duplicate(true)
	for k in patch:
		var v: Variant = patch[k]
		match str(k):
			"daily_limit", "session_limit", "reserve":
				if not (v is int or v is float) or float(v) < 0.0 or float(v) > 1000000.0:
					return "%s must be a number between 0 and 1,000,000." % str(k).replace("_", " ").capitalize()
				cur[k] = int(v)
			"buy_categories":
				if not v is Array:
					return "Purchase categories must be a list."
				var known := Venues.CATEGORY_ORDER
				var out: Array = []
				for c in v:
					if not known.has(str(c)):
						return "Unknown purchase category: %s." % str(c)
					if not out.has(str(c)):
						out.append(str(c))
				cur[k] = out
			"duties":
				if not v is Dictionary:
					return "Duties must be a dictionary of on/off switches."
				for dk in v:
					if not DUTIES.has(str(dk)):
						return "Unknown duty: %s." % str(dk)
					cur["duties"][str(dk)] = bool(v[dk])
			"protected":
				if not v is Array:
					return "Protected items must be a list of item numbers."
				var ids: Array = []
				for u in v:
					if not (u is int or u is float) or int(u) <= 0:
						return "Protected items are given by their item number."
					if not ids.has(int(u)):
						ids.append(int(u))
				cur[k] = ids
			"reserved":
				if not v is Dictionary:
					return "Reserved supplies must map a material to the minimum kept."
				var res := {}
				for d in v:
					if DB.item(str(d)).is_empty():
						return "Unknown material: %s." % str(d)
					if not (v[d] is int or v[d] is float) or int(v[d]) < 0:
						return "The minimum kept must be a whole number of 0 or more."
					if int(v[d]) > 0:
						res[str(d)] = int(v[d])
				cur[k] = res
			"order_rules":
				if not v is Dictionary:
					return "Order rules must be a dictionary."
				for rk in v:
					match str(rk):
						"max_difficulty":
							cur[k][rk] = clampi(int(v[rk]), 1, 10)
						"min_reward":
							cur[k][rk] = maxi(0, int(v[rk]))
						"deadline_margin":
							cur[k][rk] = clampi(int(v[rk]), 0, 5)
						"decline_unsuitable":
							cur[k][rk] = bool(v[rk])
						_:
							return "Unknown order rule: %s." % str(rk)
			"sell_rules":
				if not v is Dictionary:
					return "Selling rules must be a dictionary."
				for sk in v:
					match str(sk):
						"min_price_pct":
							cur[k][sk] = clampi(int(v[sk]), 50, 300)
						"stock_target":
							cur[k][sk] = clampi(int(v[sk]), 0, 12)
						"list_new_work", "list_existing", "sell_goods":
							cur[k][sk] = bool(v[sk])
						_:
							return "Unknown selling rule: %s." % str(sk)
			_:
				return "Unknown instruction: %s." % str(k)
	if int(cur["session_limit"]) < int(cur["daily_limit"]):
		cur["session_limit"] = int(cur["daily_limit"])
	st()["orders"] = cur
	_changed()
	return ""


## Protects a piece in the stores by its uid (or lifts the explicit protection). "" or why not.
static func protect(uid: int, on := true) -> String:
	var p: Array = (st()["orders"]["protected"] as Array).duplicate()
	if on and not p.has(uid):
		if ItemRegistry.find(uid).is_empty():
			return "No such piece."
		p.append(uid)
	elif not on:
		p.erase(uid)
	return set_orders({"protected": p})


## Keeps at least `n` of a material in the stores (0 = no reserve). "" or why not.
static func reserve(def_id: String, n: int) -> String:
	var r: Dictionary = (st()["orders"]["reserved"] as Dictionary).duplicate()
	r[def_id] = n
	return set_orders({"reserved": r})


static func _reserved(def_id: String) -> int:
	return int(st()["orders"]["reserved"].get(def_id, 0))


## Why the steward will never sell, list or hand over this piece ("" = an ordinary piece it may deal with).
static func protection_reason(it: Dictionary) -> String:
	if it.is_empty():
		return "Nothing there."
	var uid := int(it.get("uid", -1))
	if (st()["orders"]["protected"] as Array).has(uid):
		return "You marked it as protected."
	if it.has("epic"):
		return "It has earned Epic distinction."
	if ItemStory.is_named(it):
		return "It bears a name."
	if str(it.get("rarity", "common")) in ["legendary", "unique", "set"]:
		return "It is %s." % str(it.get("rarity", ""))
	if Provenance.is_notable(it):
		return "It is historically significant."
	for e in Game.state.get("hall_of_fame", []):
		if int(e.get("refs", {}).get("uid", -2)) == uid:
			return "It hangs in the Hall of Fame."
	if (Game.state.get("item_story", {}).get("famous", {}) as Dictionary).has(str(uid)):
		return "It is one of your famous creations."
	if bool(it.get("dev", false)):
		return "A developer's piece."
	return ""


# ======================================================================= activation
## Why the steward cannot take over now ("" = it can).
static func can_activate() -> String:
	if Game.state.is_empty():
		return "There is no game running."
	if is_active():
		return "The steward is already running the workshop."
	if Crafting.active():
		return "Finish or set aside the work at the station first — the steward does not take over a piece in your hands."
	if Contracts.smith_working:
		return "You are in the middle of a block at the Project Bench."
	return ""


## Hands the workshop to the steward: snapshot for the report, watermarks, outstanding matters noted. "" or why not.
static func activate() -> String:
	var why := can_activate()
	if why != "":
		return why
	var s := st()
	s["active"] = true
	s["sessions"] = int(s.get("sessions", 0)) + 1
	s["since"] = _snapshot()
	s["acc"] = {"ledger": {}, "income": 0, "expense": 0, "lines": 0, "recent": [], "spent": 0, "day_spent": {}, "bought": {},
		"sold": [], "sold_n": 0, "sold_gold": 0, "made": [], "made_n": 0, "completed": {}, "failed": 0, "accepted": [],
		"delivered": [], "declined": [], "listed": 0, "task_seen": {}, "produced": {}, "lore_seen": int(s["since"]["lore_next"]),
		"staff_seen": (s["since"]["staff"] as Dictionary).keys(), "staff_left": [], "decisions": 0, "by_kind": {}, "stalled": {}}
	s["stall"] = {}
	s["seen"] = {}
	s["mine"] = {}
	s["pending_report"] = false
	if Game.state.has("apprentices"):
		for t in Apprentices.tasks():   # work already queued: only what it does from now on counts
			s["acc"]["task_seen"][str(int(t["id"]))] = [int(t.get("done", 0)), (t.get("made", []) as Array).size(), str(t["state"])]
	_on = true
	_log("activate", "You handed the workshop to the steward (purse %d g, reserve %d g, %d g a day at most)." % [Game.gold(),
		int(s["orders"]["reserve"]), int(s["orders"]["daily_limit"])], {}, false)
	_scan_deferrals(true)
	_changed()
	return ""


## Takes the workshop back. Returns the While You Were Away report (also kept as last_report).
static func deactivate() -> Dictionary:
	if not is_active():
		_on = false
		return last_report()
	var r := _stand_down("returned")
	_changed()
	return r


static func _stand_down(how: String) -> Dictionary:
	var s := st()
	if not (s["since"] as Dictionary).is_empty():
		# bring the hourly bookkeeping up to this minute (a loaded save's session ends where it was saved: this only
		# reads the state as it was saved — nothing is simulated or caught up)
		_observe_tasks()
		_scan_deferrals(false)
		_refresh_deferred()
	_log("deactivate" if how == "returned" else "stood_down",
		"You took the workshop back." if how == "returned" else "The steward stood down when the game was closed.", {}, false)
	var r := report()
	r["ended"] = how
	s["last_report"] = r
	s["active"] = false
	_on = false
	return r


## Game.from_save: a loaded save always starts with the mode OFF and nothing is caught up. When the save was made
## while the steward ran, the session is closed with the state as it was saved (a truthful report of that span).
static func on_loaded() -> void:
	_on = false
	if Game.state.is_empty() or not Game.state.has("steward"):
		return
	var s: Dictionary = Game.state["steward"]
	if not bool(s.get("active", false)):
		return
	st()   # fills any missing keys of an older steward state
	var r := _stand_down("closed")
	s["pending_report"] = true
	Log.info("Steward: the saved session was closed on load (mode OFF, no catch-up; report covers %s)." % str(r.get("elapsed_text", "")))


static func last_report() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return {}
	return Game.state["steward"].get("last_report", {})


## The report of a session that ended when the game was closed (shown once after loading), or {}.
static func take_pending_report() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("steward") or not bool(Game.state["steward"].get("pending_report", false)):
		return {}
	Game.state["steward"]["pending_report"] = false
	return last_report()


# ======================================================================= the snapshot
static func _inv_counts() -> Dictionary:
	var out := {}
	for it in Game.inventory():
		var d := str(it["def"])
		out[d] = int(out.get(d, 0)) + int(it.get("qty", 1))
	return out


static func _snapshot() -> Dictionary:
	var equip: Array = []
	for it in Game.inventory():
		if Items.is_equipment(it):
			equip.append(int(it["uid"]))
	var staff := {}
	var taken := {}
	if Game.state.has("apprentices"):
		for a in Apprentices.staff():
			staff[str(a["id"])] = {"name": str(a["name"]), "rank": str(a["rank"]), "works": int(a.get("works", 0))}
		for t in Apprentices.open_tasks():
			for d in t.get("taken", {}):
				taken[str(d)] = int(taken.get(str(d), 0)) + int(t["taken"][d])
	var oo: Array = []
	for o in Shop.open_orders():
		oo.append(str(o["id"]))
	return {"t": Game.now(), "day": Game.day(), "time": Game.time_string(), "gold": Game.gold(), "inv": _inv_counts(),
		"equip": equip, "staff": staff, "orders_open": oo, "taken": taken, "lore_next": int(Lore.st()["next"]),
		"crafted": int(Game.state["stats"].get("crafted", 0)), "apprentice_crafted": int(Game.state["stats"].get("apprentice_crafted", 0)),
		"sold_stat": int(Game.state["stats"].get("sold", 0))}


# ======================================================================= ledger, log, stalls
## Game.add_gold: every ledger line while the steward runs is summed here (the ledger itself is capped at 400).
static func note_ledger(amount: int, cat: String, note: String) -> void:
	if not is_active():
		return
	var acc: Dictionary = st()["acc"]
	acc["ledger"][cat] = int(acc["ledger"].get(cat, 0)) + amount
	if amount >= 0:
		acc["income"] = int(acc["income"]) + amount
	else:
		acc["expense"] = int(acc["expense"]) - amount
	acc["lines"] = int(acc["lines"]) + 1
	var rec: Array = acc["recent"]
	rec.append({"day": Game.day(), "time": Game.time_string(), "amount": amount, "cat": cat, "note": note})
	while rec.size() > RECENT_LEDGER:
		rec.pop_front()


## Records one steward event. decision = it was an action the steward took (counted in the statistics).
static func _log(kind: String, text: String, data := {}, decision := true) -> void:
	var s := st()
	var lg: Array = s["log"]
	lg.append({"t": Game.now(), "day": Game.day(), "time": Game.time_string(), "kind": kind, "text": text, "data": data})
	while lg.size() > LOG_CAP:
		lg.pop_front()
	if decision:
		for box in [s["stats"], s["acc"]]:
			if box is Dictionary and (box as Dictionary).has("by_kind"):
				box["decisions"] = int(box.get("decisions", 0)) + 1
				box["by_kind"][kind] = int(box["by_kind"].get(kind, 0)) + 1


## A duty that cannot act records why — once per change of reason. code groups reasons for the statistics.
static func _stall(duty: String, code: String, text: String) -> void:
	var s := st()
	var key := "%s|%s" % [code, text]
	if str(s["stall"].get(duty, "")) == key:
		return
	s["stall"][duty] = key
	for box in [s["stats"], s["acc"]]:
		if box is Dictionary and (box as Dictionary).has("stalled"):
			var e: Dictionary = box["stalled"].get(code, {"n": 0, "text": ""})
			e["n"] = int(e["n"]) + 1
			e["text"] = text
			e["duty"] = duty
			box["stalled"][code] = e
	_log("stall", "%s — %s" % [DUTY_NAME.get(duty, duty), text], {"duty": duty, "code": code}, false)


static func _unstall(duty: String) -> void:
	st()["stall"].erase(duty)


static func recent_log(n := 20) -> Array:
	var lg: Array = st()["log"]
	return lg.slice(maxi(0, lg.size() - n))


static func stats() -> Dictionary:
	return (st()["stats"] as Dictionary).duplicate(true)


# ======================================================================= spending
static func _spent_today() -> int:
	return int(st()["acc"].get("day_spent", {}).get(str(Game.day()), 0))


## Gold the steward may still spend now (daily and session limits, never below the reserve).
static func spendable() -> int:
	if not is_active():
		return 0
	var o: Dictionary = st()["orders"]
	var acc: Dictionary = st()["acc"]
	var by_day := int(o["daily_limit"]) - _spent_today()
	var by_session := int(o["session_limit"]) - int(acc.get("spent", 0))
	var by_reserve := Game.gold() - int(o["reserve"])
	return maxi(0, mini(by_day, mini(by_session, by_reserve)))


static func _spend_block() -> String:
	var o: Dictionary = st()["orders"]
	if Game.gold() <= int(o["reserve"]):
		return "reserve"
	if _spent_today() >= int(o["daily_limit"]):
		return "daily_limit"
	if int(st()["acc"].get("spent", 0)) >= int(o["session_limit"]):
		return "session_limit"
	return ""


static func _note_spent(cost: int) -> void:
	var acc: Dictionary = st()["acc"]
	acc["spent"] = int(acc.get("spent", 0)) + cost
	var ds: Dictionary = acc["day_spent"]
	ds[str(Game.day())] = int(ds.get(str(Game.day()), 0)) + cost
	# keep only the last fortnight of daily totals
	for k in ds.keys():
		if int(str(k)) < Game.day() - 14:
			ds.erase(k)


# ======================================================================= the cycle
## Game.advance_minutes, every 15 game minutes while active (after the world simulated that span).
static func tick() -> void:
	if not is_active():
		return
	var hourly := int(Game.state["minute"]) % 60 == 0
	if hourly:
		_observe_tasks()
	_scan_deferrals(false, hourly)
	if hourly:
		_refresh_deferred()
	if duty_on("upkeep"):
		_duty_upkeep()
	if duty_on("orders"):
		_duty_orders()
	if duty_on("repairs"):
		_duty_repairs()
	if duty_on("production") or duty_on("contracts"):
		_duty_production()
	if duty_on("replenish"):
		_duty_replenish()
	if duty_on("sales"):
		_duty_sales()
	_changed()


# ----------------------------------------------------------------------- observation (report data)
## Notes apprentice task completions (production) and staff changes since the last cycle.
static func _observe_tasks() -> void:
	if not Game.state.has("apprentices"):
		return
	var acc: Dictionary = st()["acc"]
	var seen: Dictionary = acc["task_seen"]
	var present := {}
	for t in Apprentices.tasks():
		var key := str(int(t["id"]))
		present[key] = true
		var done := int(t.get("done", 0))
		var made: Array = t.get("made", [])
		var state := str(t["state"])
		# a task first seen now was queued after activation (activate() noted every task that existed then)
		var prev: Array = seen.get(key, [0, 0, ""])
		if done == int(prev[0]) and made.size() == int(prev[1]) and state == str(prev[2]):
			continue
		if done > int(prev[0]):
			var kind := str(t["kind"])
			var k := done - int(prev[0])
			acc["completed"][kind] = int(acc["completed"].get(kind, 0)) + k
			var out := str(DB.recipe(str(t.get("recipe", ""))).get("output", ""))
			if kind in ["prep", "craft"] and out != "" and not Items.is_equipment({"def": out}):
				# materials stack into the stores: the recipe's quantity (an excellent batch may yield one more)
				var per := maxi(1, int(DB.recipe(str(t["recipe"])).get("qty", 1)))
				var pr: Dictionary = acc["produced"].get(out, {"n": 0, "qty": 0, "max": 0})
				pr["n"] = int(pr["n"]) + k
				pr["qty"] = int(pr["qty"]) + per * k
				pr["max"] = int(pr["max"]) + (per + 1) * k
				acc["produced"][out] = pr
		for i in range(int(prev[1]), made.size()):
			(acc["made"] as Array).append(int(made[i]))
			acc["made_n"] = int(acc["made_n"]) + 1
		if state == "failed" and str(prev[2]) != "failed":
			acc["failed"] = int(acc["failed"]) + 1
			var fw: Dictionary = acc.get("failed_why", {})
			var why := "%s: %s" % [str(t["kind"]), str(t.get("blocker", "")).left(80)]
			fw[why] = int(fw.get(why, 0)) + 1
			acc["failed_why"] = fw
		seen[key] = [done, made.size(), state]
	if seen.size() > present.size():
		for k in seen.keys():
			if not present.has(k):
				seen.erase(k)
	# staff who left (unpaid, dismissed, independence)
	var now_ids := {}
	for a in Apprentices.staff():
		now_ids[str(a["id"])] = true
	var known: Array = acc["staff_seen"]
	for id in known.duplicate():
		if not now_ids.has(str(id)):
			known.erase(id)
			var how := "left the workshop"
			for al in Apprentices.alumni():
				if str(al["id"]) == str(id):
					how = "opened a workshop of their own"
			(acc["staff_left"] as Array).append({"id": str(id), "day": Game.day(), "how": how})
	for id2 in now_ids:
		if not known.has(id2):
			known.append(id2)


# ----------------------------------------------------------------------- material planning
## A village counter's list price for a def (from the trade data; never touches today's stock): {store, price} or {}.
static func _shop_price(def_id: String) -> Dictionary:
	for sid in VILLAGE_STORES:
		for e in Trade.store_cfg(sid).get("stock", []):
			if str(e[0]) == def_id:
				return {"store": sid, "price": maxi(1, int(round(float(e[1]) * Trade.price_factor())))}
	return {}


static func _category_ok(def_id: String) -> bool:
	return (st()["orders"]["buy_categories"] as Array).has(Venues.category_of(def_id))


## The prep recipe (non-equipment) the smith knows that makes def_id, or "".
static func _prep_recipe(def_id: String) -> String:
	var best := ""
	var best_d := 999
	var ids := DB.recipes.keys()
	ids.sort()
	for rid_v in ids:
		var rid := str(rid_v)
		var r := DB.recipe(rid)
		if str(r.get("output", "")) != def_id or Items.is_equipment({"def": def_id}):
			continue
		if Crafting.recipe_locked_reason(rid) != "" or not _stations_ok(rid):
			continue
		if Crafting.difficulty(rid) < best_d:
			best = rid
			best_d = Crafting.difficulty(rid)
	return best


static func _stations_ok(rid: String) -> bool:
	for op in Crafting.operations(rid):
		if not Property.is_installed(str(op.get("station", ""))):
			return false
	return true


## The first apprentice (by id) who can make this recipe, or {}.
static func _maker_for(rid: String) -> Dictionary:
	var ids: Array = []
	for a in Apprentices.staff():
		ids.append(str(a["id"]))
	ids.sort()
	for id in ids:
		var a := Apprentices.get_a(str(id))
		if Apprentices.can_make(a, rid) == "":
			return a
	return {}


## Materials still to be taken by the open apprentice tasks: {def: n}.
static func _needs() -> Dictionary:
	var need := {}
	if not Game.state.has("apprentices"):
		return need
	for t in Apprentices.open_tasks():
		if not str(t["kind"]) in ["craft", "prep", "commission"]:
			continue
		var rid := str(t.get("recipe", ""))
		if rid == "" and str(t["kind"]) == "commission":
			var o := _order(str(t.get("order_id", "")))
			var a := Apprentices.get_a(str(t.get("worker", "")))
			if a.is_empty():
				for x in Apprentices.staff():
					if Apprentices.commission_recipe(o, x) != "":
						a = x
						break
			rid = Apprentices.commission_recipe(o, a) if not a.is_empty() else ""
		if rid == "":
			continue
		var left := int(t.get("repeat", 1)) - int(t.get("done", 0)) - (1 if bool(t.get("started", false)) else 0)
		if left <= 0:
			continue
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		for d in inputs:
			need[str(d)] = int(need.get(str(d), 0)) + int(inputs[d]) * left
	return need


## Can `n` of def_id be had for new work: from the stores beyond reserves and committed work, bought at a village
## counter in a permitted category, or prepared by an apprentice (two levels deep)? Adds the cost to plan["cost"].
## Returns "" or why not.
static func _obtain(def_id: String, n: int, need: Dictionary, plan: Dictionary, depth := 0) -> String:
	var avail := Game.count(def_id) - _reserved(def_id) - int(need.get(def_id, 0)) - int(plan["use"].get(def_id, 0))
	if avail >= n:
		plan["use"][def_id] = int(plan["use"].get(def_id, 0)) + n
		return ""
	var short := n - maxi(0, avail)
	plan["use"][def_id] = int(plan["use"].get(def_id, 0)) + maxi(0, avail)
	var sp := _shop_price(def_id)
	if not sp.is_empty():
		if not duty_on("replenish"):
			return "Buying materials is not among the steward's duties."
		if not _category_ok(def_id):
			return "%s may not be bought (category %s not permitted)." % [str(DB.item(def_id).get("name", def_id)), Venues.category_of(def_id)]
		plan["cost"] = int(plan["cost"]) + int(sp["price"]) * short
		return ""
	if depth < 2:
		var prid := _prep_recipe(def_id)
		if prid != "" and not _maker_for(prid).is_empty():
			var per := maxi(1, int(DB.recipe(prid).get("qty", 1)))
			var runs := int(ceil(float(short) / float(per)))
			var inputs: Dictionary = DB.recipe(prid).get("inputs", {})
			for d in inputs:
				var why := _obtain(str(d), int(inputs[d]) * runs, need, plan, depth + 1)
				if why != "":
					return why
			plan["minutes"] = float(plan.get("minutes", 0.0)) + 90.0 * runs
			return ""
	return "No ordinary source for %s." % str(DB.item(def_id).get("name", def_id))


## A plan to make one piece of `rid`: {ok, why, cost, minutes} (materials only; who makes it is checked by callers).
static func _material_plan(rid: String, need: Dictionary) -> Dictionary:
	var plan := {"use": {}, "cost": 0, "minutes": 0.0}
	var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
	var ks := inputs.keys()
	ks.sort()
	for d in ks:
		var why := _obtain(str(d), int(inputs[d]), need, plan)
		if why != "":
			plan["why"] = why
			return plan
	plan["why"] = ""
	return plan


# ----------------------------------------------------------------------- duty: upkeep
static func _duty_upkeep() -> void:
	var o: Dictionary = st()["orders"]
	if Game.gold() <= int(o["reserve"]):
		_stall("upkeep", "reserve", "The purse (%d g) is at the reserve of %d g — discretionary spending stopped; wages and upkeep are still paid." % [Game.gold(), int(o["reserve"])])
	else:
		var cur := str(st()["stall"].get("upkeep", ""))
		if cur.begins_with("reserve|"):
			_unstall("upkeep")
			_log("reserve_ok", "The purse is above the reserve again (%d g)." % Game.gold(), {}, false)
	# Aldric's weekly provisions: taken in at the door (the same action as talking to him)
	if bool(Game.state.get("world", {}).get("delivery_pending", false)) and Game.hour() >= 9 and Game.hour() < 17:
		var before := _inv_counts()
		Sim.take_delivery()
		var got := []
		var got_n := {}
		var after := _inv_counts()
		for d in after:
			var dn := int(after[d]) - int(before.get(d, 0))
			if dn > 0:
				got.append("%d %s" % [dn, str(DB.item(str(d)).get("name", d))])
				got_n[str(d)] = dn
		var pv: Dictionary = st()["acc"].get("provisions", {})
		for pd in got_n:
			pv[pd] = int(pv.get(pd, 0)) + int(got_n[pd])
		st()["acc"]["provisions"] = pv
		_log("provisions", "Took in Aldric's weekly provisions at the door%s." % ((": " + ", ".join(PackedStringArray(got))) if not got.is_empty() else ""), {"got": got_n})


# ----------------------------------------------------------------------- duty: orders
static func _order(oid: String) -> Dictionary:
	for o in Shop.orders():
		if str(o.get("id", "")) == oid:
			return o
	return {}


static func _commission_task(oid: String) -> Dictionary:
	if not Game.state.has("apprentices"):
		return {}
	for t in Apprentices.open_tasks():
		if str(t["kind"]) == "commission" and str(t.get("order_id", "")) == oid:
			return t
	return {}


## Why an order is not the steward's to take on at all ("" = ordinary).
static func _extraordinary(o: Dictionary) -> String:
	if o.has("inspired_by"):
		return "fame"
	if Social.spouse() != "" and str(o.get("npc", "")) == Social.spouse():
		return "personal"
	return ""


## Can the workshop make this order in time with what it has? {ok, rid, app, cost, why}.
static func _order_plan(o: Dictionary, need: Dictionary) -> Dictionary:
	var rules: Dictionary = st()["orders"]["order_rules"]
	if Apprentices.staff().is_empty():
		return {"ok": false, "why": "There are no apprentices to make it."}
	var reward := int(o.get("reward", 0))
	if reward < int(rules["min_reward"]):
		return {"ok": false, "why": "The reward (%d g) is below your minimum of %d g." % [reward, int(rules["min_reward"])]}
	var why := "Nobody in the workshop can make it yet."
	var ids: Array = []
	for a in Apprentices.staff():
		ids.append(str(a["id"]))
	ids.sort()
	for id in ids:
		var a := Apprentices.get_a(str(id))
		var rid := str(o.get("recipe", "")) if str(o.get("recipe", "")) != "" else Apprentices.commission_recipe(o, a)
		if rid == "" or Apprentices.can_make(a, rid) != "":
			continue
		if Crafting.recipe_locked_reason(rid) != "":
			why = "You have not learned %s yourself." % str(DB.recipe(rid).get("name", rid))
			continue
		if Crafting.difficulty(rid) > int(rules["max_difficulty"]):
			why = "Harder than your rule allows (difficulty %d > %d)." % [Crafting.difficulty(rid), int(rules["max_difficulty"])]
			continue
		if not _stations_ok(rid):
			why = "A station it needs is not installed."
			continue
		var plan := _material_plan(rid, need)
		if str(plan["why"]) != "":
			why = str(plan["why"])
			continue
		var est := Apprentices.estimate({"kind": "commission", "recipe": rid, "order_id": str(o["id"]), "repeat": 1, "done": 0, "started": false, "op": 0}, a)
		# the work itself, material preparation, and the queue already ahead of it (shared by the hands on staff)
		var mins := float(est.get("minutes", 0)) + float(plan["minutes"]) + _backlog_minutes()
		var avail := _working_minutes_until(int(o.get("deadline", Game.day()))) - float(rules["deadline_margin"]) * SHIFT_MINUTES
		if mins > avail:
			var days_need := int(ceil(mins / SHIFT_MINUTES))
			why = "Not enough time before the deadline (about %d working day%s of work, the queue included)." % [days_need, "" if days_need == 1 else "s"]
			continue
		return {"ok": true, "rid": rid, "app": str(a["id"]), "cost": int(plan["cost"]), "why": ""}
	return {"ok": false, "why": why}


## Shift minutes left from now until the end of `last_day` (the order expires the morning after its deadline).
static func _working_minutes_until(last_day: int) -> float:
	var sh: Dictionary = Apprentices.cfg("shift")
	var start := int(sh.get("start", 8)) * 60
	var stop := int(sh.get("end", 18)) * 60
	var today := 0.0
	var m := int(Game.state["minute"])
	if m < stop:
		today = float(stop - maxi(m, start)) - (60.0 if m < int(sh.get("break_start", 12)) * 60 else 0.0)
	if last_day < Game.day():
		return 0.0
	return maxf(0.0, today) + float(last_day - Game.day()) * SHIFT_MINUTES


## Work already waiting for the apprentices (rough: 100 minutes a piece), shared by the hands on staff.
static func _backlog_minutes() -> float:
	var n := 0
	for t in Apprentices.open_tasks():
		if str(t["kind"]) in ["craft", "prep", "commission", "repair"]:
			n += maxi(1, int(t.get("repeat", 1)) - int(t.get("done", 0)))
	return 100.0 * float(n) / float(maxi(1, Apprentices.staff().size()))


static func _duty_orders() -> void:
	var seen: Dictionary = st()["seen"]
	var rules: Dictionary = st()["orders"]["order_rules"]
	var hourly := int(Game.state["minute"]) % 60 == 0
	var multi := Shop.customers().any(func(c): return str(c.get("want", "")) == "multi" and bool(c.get("present", true)))
	var need := _needs() if hourly or multi else {}
	# 1. visitors with several requests at the counter: take on what the workshop can make, decline the rest
	for c in (Shop.waiting().duplicate() if multi else []):
		if str(c.get("want", "")) != "multi" or _personal(str(c["npc"])):
			continue
		var npc := str(c["npc"])
		for pt in (c.get("parts", []) as Array).duplicate():
			if str(pt.get("status", "")) != "pending":
				continue
			var why := ""
			if str(pt.get("kind", "")) != "craft":
				why = "a repair at the counter's grinding wheel is the smith's own work"
			elif bool(pt.get("advanced", false)):
				why = "it is beyond the workshop for now"
			else:
				var o_like := {"id": "part", "def": str(pt.get("def", "")), "recipe": str(pt.get("recipe", "")), "reward": int(pt.get("reward", 0)),
					"deadline": Game.day() + int(pt.get("days", 3)), "slot": str(pt.get("slot", ""))}
				var plan := _order_plan(o_like, need)
				if bool(plan["ok"]):
					var err := Shop.accept_part(npc, str(pt["pid"]))
					if err == "":
						var oid := str(pt.get("order", ""))
						var o := _order(oid)
						var t := Apprentices.add_task("commission", {"order_id": oid, "recipe": str(plan["rid"]), "priority": 3})
						if not t.has("error"):
							st()["mine"][str(int(t["id"]))] = "commission"
						var line := "Took on %s for %s (%d g, by day %d)." % [Shop.order_text(o), Talk.npc_name(npc), int(o.get("reward", 0)), int(o.get("deadline", 0))]
						(st()["acc"]["accepted"] as Array).append(line)
						_log("accept", line, {"order": oid, "npc": npc})
						need = _needs()
						continue
					why = err
				else:
					why = str(plan["why"])
			if bool(rules["decline_unsuitable"]):
				Shop.decline_part(npc, str(pt["pid"]))
				var dl := "Declined %s for %s — %s." % [Shop.part_phrase(pt), Talk.npc_name(npc), why.trim_suffix(".")]
				(st()["acc"]["declined"] as Array).append(dl)
				_log("decline", dl, {"npc": npc})
	# 2. commissions on the board (hourly; an order left aside is looked at again after four hours)
	for o in Shop.open_orders():
		if not hourly:
			break
		var oid := str(o["id"])
		if not _commission_task(oid).is_empty():
			continue
		var ex := _extraordinary(o)
		if ex != "":
			continue   # deferred by _scan_deferrals
		var sig := _staff_sig()
		var last: Array = seen.get("planned:" + oid, ["", -100000, ""])
		if str(last[0]) == sig and (not str(last[2]).contains("aterial") and not str(last[2]).contains("bought") or Game.now() - int(last[1]) < 240):
			continue   # nothing that decided it has changed (time only runs shorter)
		var plan := _order_plan(o, need)
		seen["planned:" + oid] = [sig, Game.now(), str(plan.get("why", ""))]
		if not bool(plan["ok"]):
			var key := "order_left:%s" % oid
			if str(seen.get(key, "")) != str(plan["why"]):
				seen[key] = str(plan["why"])
				_log("order_left", "Left %s's commission (%s) for you — %s" % [Talk.npc_name(str(o["npc"])), Shop.order_text(o), str(plan["why"])], {"order": oid}, false)
			continue
		var t := Apprentices.add_task("commission", {"order_id": oid, "recipe": str(plan["rid"]), "priority": 3})
		if t.has("error"):
			_stall("orders", "queue", "Could not queue %s's commission: %s" % [Talk.npc_name(str(o["npc"])), str(t["error"])])
			continue
		st()["mine"][str(int(t["id"]))] = "commission"
		var line := "Committed the workshop to %s's commission: %s (%d g, by day %d) — %s." % [Talk.npc_name(str(o["npc"])), Shop.order_text(o),
			int(o.get("reward", 0)), int(o.get("deadline", 0)), str(DB.recipe(str(plan["rid"])).get("name", plan["rid"]))]
		(st()["acc"]["accepted"] as Array).append(line)
		_log("commit", line, {"order": oid})
		need = _needs()
	# 3. finished commission pieces in the stores: deliver them (ordinary ones only)
	var pending: Array = Game.inventory().filter(func(x): return x.has("for_order"))
	for it in pending:
		var oid2 := str(it.get("for_order", ""))
		if oid2 == "":
			continue
		var o2 := _order(oid2)
		if o2.is_empty() or str(o2.get("status", "")) != "open":
			continue
		var prot := protection_reason(it)
		if prot != "":
			defer("remarkable", "%s was made for %s's commission and turned out remarkable (%s) — the steward kept it for you to decide." % [
				Items.display_name(it), Talk.npc_name(str(o2["npc"])), prot.trim_suffix(".").to_lower()],
				{"type": "item", "id": str(int(it["uid"])), "key": "remarkable:%d" % int(it["uid"])}, false,
				{"route": "orders", "args": {}})
			continue
		var nm := Items.display_name(it)
		var g0 := Game.gold()
		var err2 := Shop.fulfil(oid2, int(it["uid"]))
		if err2 == "":
			var line2 := "Delivered %s to %s for the commission (+%d g)." % [nm, Talk.npc_name(str(o2["npc"])), Game.gold() - g0]
			(st()["acc"]["delivered"] as Array).append(line2)
			_log("deliver", line2, {"order": oid2, "uid": int(o2.get("delivered_uid", -1)), "gold": Game.gold() - g0})


## What the workshop's hands can do (ids, ranks and skill levels) — order plans are revisited when it changes.
static func _staff_sig() -> String:
	var parts := PackedStringArray()
	for a in Apprentices.staff():
		var lv := PackedStringArray()
		for sk in a.get("skills", {}):
			lv.append(str(int(a["skills"][sk].get("lvl", 0))))
		parts.append("%s:%s:%s" % [str(a["id"]), str(a["rank"]), ",".join(lv)])
	return "|".join(parts)


static func _personal(npc: String) -> bool:
	return Social.spouse() != "" and npc == Social.spouse()


# ----------------------------------------------------------------------- duty: repairs
static func _duty_repairs() -> void:
	if not Game.state.has("apprentices") or not Apprentices.unlocked():
		return
	var seen: Dictionary = st()["seen"]
	for c in Shop.waiting():
		if str(c.get("want", "")) != "repair" or c.has("parts") or _personal(str(c["npc"])):
			continue
		var npc := str(c["npc"])
		var visit := "repair:%s:%d" % [npc, int(c.get("arrived", 0))]
		if seen.has(visit):
			continue   # decided once per visit
		var exists := Apprentices.open_tasks().any(func(t): return str(t["kind"]) == "repair" and str(t["target"]) == npc)
		if exists:
			seen[visit] = true
			continue
		var it := Apprentices.repair_item({"kind": "repair", "target": npc})
		if it.is_empty():
			continue
		if Apprentices.staff().is_empty():
			_stall("repairs", "no_staff", "A customer wants a repair, but there is no apprentice to do it.")
			continue
		seen[visit] = true
		var prot := protection_reason(it)
		if prot != "" and not prot.begins_with("You marked"):
			defer("repair", "%s brought %s to be mended — %s, so the steward left it for your own hands." % [Talk.npc_name(npc), Items.display_name(it), prot.trim_suffix(".").to_lower()],
				{"type": "customer", "id": npc, "arrived": int(c.get("arrived", 0)), "from": Talk.npc_name(npc),
					"key": "repair_piece:%d:%d" % [int(it.get("uid", -1)), int(st().get("sessions", 0))]},   # one matter per piece per absence
				false, {"route": "shop", "args": {"npc": npc}})
			continue
		# will an apprentice finish before the customer gives up waiting?
		# conservative: the slowest hand might take it, behind the urgent work already waiting, with a quarter to spare
		var probe := {"kind": "repair", "target": npc, "repeat": 1, "done": 0, "started": false, "op": 0}
		var slowest := 0.0
		for a in Apprentices.staff():
			slowest = maxf(slowest, float(Apprentices.estimate(probe, a).get("minutes", 60)))
		var ahead := Apprentices.open_tasks().filter(func(t): return int(t["priority"]) >= 3 and str(t.get("worker", "")) == "").size()
		var need_min := slowest * 1.25 + (0.0 if _idle_hand() else 45.0) + 60.0 * float(ahead) / float(maxi(1, Apprentices.staff().size()))
		var left := _patience_minutes(c)
		if need_min > left:
			_log("repair_left", "Left %s's repair (%s) — no apprentice could finish it before they give up waiting (about %d min needed, %d left)." % [
				Talk.npc_name(npc), str(it.get("name", "piece")), int(need_min), int(left)], {"npc": npc}, false)
			continue
		var t := Apprentices.add_task("repair", {"target": npc, "priority": 3})
		if t.has("error"):
			_stall("repairs", "queue", "Could not queue the repair for %s: %s" % [Talk.npc_name(npc), str(t["error"])])
			continue
		st()["mine"][str(int(t["id"]))] = "repair"
		_unstall("repairs")
		_log("repair", "Queued the repair of %s's %s for the apprentices." % [Talk.npc_name(npc), str(it.get("name", "piece"))], {"npc": npc, "task": int(t["id"])})


static func _idle_hand() -> bool:
	for a in Apprentices.staff():
		if Apprentices.on_shift(a) and int(a.get("task", -1)) == -1:
			return true
	return false


## Minutes of apprentice working time before a seated customer gives up (Shop.customer_hour: three hours after
## sitting down, checked on the hour between 9:00 and 18:00 — the evening and night do not count against them).
static func _patience_minutes(c: Dictionary) -> float:
	var seated := int(c.get("seated", c.get("arrived", 0)))
	var leave_abs := seated + 3          # absolute hour (day * 24 + hour) of the first check that sends them away
	var now_h := Game.day() * 24 + Game.hour()
	var leave_hod := leave_abs % 24
	if leave_hod >= 18 or leave_hod < 9:
		leave_abs = (int(leave_abs / 24) + (1 if leave_hod >= 18 else 0)) * 24 + 9   # next morning's first check
	var mins := float(leave_abs - now_h) * 60.0 - float(int(Game.state["minute"]) % 60)
	# apprentices work 8–18 with the midday hour off: subtract time outside the shift (roughly)
	var off := 0.0
	var day_gap := int(leave_abs / 24) - Game.day()
	if day_gap > 0:
		off = float(day_gap) * 14.0 * 60.0
	if Game.hour() < 13 and (day_gap > 0 or leave_abs % 24 > 12):
		off += 60.0   # the midday break
	return maxf(0.0, mins - off)


# ----------------------------------------------------------------------- duty: production
static func _blocker_code(b: String) -> String:
	if b.begins_with("Missing materials"):
		return "materials"
	if b.contains("not installed") or b.contains("is not available"):
		return "station"
	if b.begins_with("Waiting for the"):
		return "station_busy"
	if b.contains("cannot make") or b.contains("novice only") or b.begins_with("Too hard") or b.begins_with("Needs ") or b.contains("beyond") or b.begins_with("Not trained"):
		return "skill"
	if b.begins_with("You have not learned"):
		return "unlearned"
	return "other"


static func _duty_production() -> void:
	if not Game.state.has("apprentices"):
		return
	var s := st()
	var mine: Dictionary = s["mine"]
	# 1. tidy the steward's own tasks: forget finished ones, cancel the ones whose reason is gone
	for k in mine.keys():
		var t := Apprentices.task(int(str(k)))
		if t.is_empty() or str(t["state"]) in Apprentices.FINISHED:
			mine.erase(k)
			continue
		if not bool(t.get("started", false)) and str(t["state"]) == "blocked":
			var prob := Apprentices.task_problem(t)
			if prob in ["The piece is no longer here.", "The commission is no longer open."]:
				var lab := str(t.get("label", ""))
				if Apprentices.cancel_task(int(t["id"])) == "":
					mine.erase(k)
					_log("cancel", "Took %s off the work queue — %s" % [lab, prob.to_lower()], {"task": int(t["id"])})
	if Apprentices.staff().is_empty():
		if Apprentices.unlocked():
			_stall("production", "no_staff", "There are no apprentices — nothing can be made while you are away.")
		return
	# 2. automatic assignment off: the steward pins its own waiting work to a free, eligible hand
	if not bool(Apprentices.st()["auto"]):
		for k2 in mine.keys():
			var t2 := Apprentices.task(int(str(k2)))
			if t2.is_empty() or str(t2.get("worker", "")) != "" or str(t2.get("assignee", "")) != "":
				continue
			for a in Apprentices.staff():
				if int(a.get("task", -1)) == -1 and Apprentices.eligible(a, t2) == "":
					if Apprentices.assign(int(t2["id"]), str(a["id"])) == "":
						_log("assign", "Gave %s to %s." % [str(t2.get("label", "the task")), str(a["name"])], {"task": int(t2["id"]), "app": str(a["id"])})
					break
	# 3. stalls: the first of the steward's own tasks that is blocked says why
	var blocked := ""
	for k3 in mine.keys():
		var t3 := Apprentices.task(int(str(k3)))
		if not t3.is_empty() and str(t3["state"]) == "blocked" and str(t3.get("blocker", "")) != "":
			blocked = str(t3["blocker"])
			break
	if blocked != "":
		_stall("production", _blocker_code(blocked), blocked)
	elif str(s["stall"].get("production", "")) != "":
		_unstall("production")
	# hourly decisions below, during the working day
	if Game.state["minute"] % 60 != 0 or Game.hour() < 8 or Game.hour() >= 17:
		return
	if duty_on("contracts"):
		_contract_hours()
	if duty_on("production"):
		_restock()


## Apprentice hours on contracts the smith has already accepted (never new letters), when an apprentice qualifies.
static func _contract_hours() -> void:
	for c in Contracts.active():
		var cid := str(c["id"])
		if Apprentices.open_tasks().any(func(t): return str(t["kind"]) == "contract" and str(t["target"]) == cid):
			continue
		if Contracts.task_problem(cid) != "" or Contracts.finished_for_apprentices(cid):
			continue
		var probe := {"kind": "contract", "target": cid, "recipe": Contracts.main_recipe(cid)}
		if not Apprentices.staff().any(func(a): return Apprentices.eligible(a, probe) == ""):
			continue
		var t := Apprentices.add_task("contract", {"target": cid, "repeat": 4, "priority": 1})
		if t.has("error"):
			continue
		st()["mine"][str(int(t["id"]))] = "contract"
		_log("contract_hours", "Set the apprentices four hours on the contract «%s»." % str(c.get("title", "")), {"contract": cid, "task": int(t["id"])})


## Ordinary pieces for the display: one restock task at a time, only from ordinary materials, within the purse.
static func _restock() -> void:
	var rules: Dictionary = st()["orders"]["sell_rules"]
	if not bool(rules["list_new_work"]) or int(rules["stock_target"]) <= 0:
		return
	var mine: Dictionary = st()["mine"]
	for k in mine:
		if str(mine[k]) == "restock":
			return
	var shown := 0
	var by_def := {}
	for it in Shop.stock():
		if Items.is_equipment(it):
			shown += 1
			by_def[str(it["def"])] = int(by_def.get(str(it["def"]), 0)) + 1
	if shown >= int(rules["stock_target"]):
		return
	var blk := _spend_block()
	var need := _needs()
	var best := {}
	var best_score := -99999.0
	var ids := DB.recipes.keys()
	ids.sort()
	var why_none := "No ordinary piece the workshop can make right now."
	for rid_v in ids:
		var rid := str(rid_v)
		var out := str(DB.recipe(rid).get("output", ""))
		if not Items.is_equipment({"def": out}) or str(DB.recipe(rid).get("min_rarity", "")) != "":
			continue
		if Crafting.difficulty(rid) > int(st()["orders"]["order_rules"]["max_difficulty"]):
			continue
		if Crafting.recipe_locked_reason(rid) != "" or not _stations_ok(rid):
			continue
		var a := _maker_for(rid)
		if a.is_empty():
			continue
		var plan := _material_plan(rid, need)
		if str(plan["why"]) != "":
			why_none = str(plan["why"])
			continue
		if int(plan["cost"]) > 0 and (blk != "" or int(plan["cost"]) > spendable()):
			why_none = "Materials for new pieces would break the spending limits."
			continue
		var q := Apprentices.expected_quality(a, rid)
		var value := Items.value({"def": out, "quality": q})
		var cost := 0
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		for d in inputs:
			var sp := _shop_price(str(d))
			cost += int(inputs[d]) * (int(sp["price"]) if not sp.is_empty() else int(DB.item(str(d)).get("value", 5)))
		var margin := float(value - cost)
		if margin <= 0.0:
			continue
		var score := margin - 25.0 * float(by_def.get(out, 0))
		if score > best_score:
			best_score = score
			best = {"rid": rid, "value": value, "cost": cost}
	if best.is_empty():
		_stall("production", "restock", why_none)
		return
	var t := Apprentices.add_task("craft", {"recipe": str(best["rid"]), "priority": 2})
	if t.has("error"):
		_stall("production", "queue", "Could not queue new work: %s" % str(t["error"]))
		return
	st()["mine"][str(int(t["id"]))] = "restock"
	_log("restock", "Queued %s for the display (worth about %d g, materials about %d g)." % [str(DB.recipe(str(best["rid"])).get("name", best["rid"])),
		int(best["value"]), int(best["cost"])], {"task": int(t["id"]), "recipe": str(best["rid"])})


# ----------------------------------------------------------------------- duty: replenishment
static func _duty_replenish() -> void:
	if not Game.state.has("apprentices"):
		return
	var need := _needs()
	var ks := need.keys()
	ks.sort()
	for d_v in ks:
		var d := str(d_v)
		var short := int(need[d]) + _reserved(d) - Game.count(d)
		if short <= 0:
			continue
		var sp := _shop_price(d)
		if sp.is_empty():
			if duty_on("production"):
				_queue_prep(d, short)
			continue
		var store := str(sp["store"])
		if not _category_ok(d):
			_stall("replenish", "category", "%s is needed, but %s is not a permitted purchase." % [str(DB.item(d).get("name", d)), Venues.category_of(d)])
			continue
		if not Venues.is_open(store):
			continue   # it waits for the counter to open
		var blk := _spend_block()
		if blk != "":
			_stall("replenish", blk, {"reserve": "The purse is at the reserve — no materials bought.",
				"daily_limit": "Today's spending limit is reached.", "session_limit": "The spending limit for your absence is reached."}[blk])
			continue
		var left := 0
		var price := int(sp["price"])
		for e in Trade.store_stock(store):
			if str(e["def"]) == d:
				left = int(e["qty"])
				price = int(e["price"])
		if left <= 0:
			_stall("replenish", "sold_out", "%s is sold out at %s until tomorrow." % [str(DB.item(d).get("name", d)), Trade.store_name(store)])
			continue
		var qty := mini(short, mini(left, int(spendable() / maxi(1, price))))
		if qty <= 0:
			_stall("replenish", "limit", "%s costs more than the steward may spend now." % str(DB.item(d).get("name", d)))
			continue
		var g0 := Game.gold()
		var err := Trade.buy_store(store, d, qty)
		if err != "":
			_stall("replenish", "refused", "%s: %s" % [Trade.store_name(store), err])
			continue
		var cost := g0 - Game.gold()
		_note_spent(cost)
		var b: Dictionary = st()["acc"]["bought"]
		var cur: Array = b.get(d, [0, 0])
		b[d] = [int(cur[0]) + qty, int(cur[1]) + cost]
		_unstall("replenish")
		_log("buy", "Bought %d %s at %s for %d g." % [qty, str(DB.item(d).get("name", d)), Trade.store_name(store), cost], {"item_def": d, "qty": qty, "cost": cost, "gold_after": Game.gold()})


## Materials the counters do not sell are prepared by an apprentice (e.g. smelting iron for a blade).
static func _queue_prep(def_id: String, short: int) -> void:
	for t in Apprentices.open_tasks():
		if str(t["kind"]) == "prep" and str(DB.recipe(str(t.get("recipe", ""))).get("output", "")) == def_id:
			return
	var rid := _prep_recipe(def_id)
	if rid == "":
		_stall("production", "no_source", "%s is needed, and there is no ordinary way to get it." % str(DB.item(def_id).get("name", def_id)))
		return
	if _maker_for(rid).is_empty():
		_stall("production", "skill", "%s is needed, but no apprentice can make %s yet." % [str(DB.item(def_id).get("name", def_id)), str(DB.recipe(rid).get("name", rid))])
		return
	var per := maxi(1, int(DB.recipe(rid).get("qty", 1)))
	var runs := clampi(int(ceil(float(short) / float(per))), 1, 6)
	var t2 := Apprentices.add_task("prep", {"recipe": rid, "repeat": runs, "priority": 3})
	if t2.has("error"):
		_stall("production", "queue", "Could not queue %s: %s" % [str(DB.recipe(rid).get("name", rid)), str(t2["error"])])
		return
	st()["mine"][str(int(t2["id"]))] = "prep"
	_log("prep", "Queued %s ×%d to prepare %s for the planned work." % [str(DB.recipe(rid).get("name", rid)), runs, str(DB.item(def_id).get("name", def_id))], {"task": int(t2["id"]), "recipe": rid})


# ----------------------------------------------------------------------- duty: stock & sales
## The lowest price the selling rules allow for a piece (value × min %, never below its materials' cost).
static func min_price(it: Dictionary) -> int:
	var pct := int(st()["orders"]["sell_rules"]["min_price_pct"])
	var floor_v := int(ceil(float(Items.value(it)) * float(pct) / 100.0))
	var rid := str(it.get("craft", {}).get("recipe", ""))
	if rid != "":
		var cost := 0
		var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
		for d in inputs:
			var sp := _shop_price(str(d))
			cost += int(inputs[d]) * (int(sp["price"]) if not sp.is_empty() else int(DB.item(str(d)).get("value", 5)))
		floor_v = maxi(floor_v, cost)
	return maxi(1, floor_v)


static func _duty_sales() -> void:
	var rules: Dictionary = st()["orders"]["sell_rules"]
	var acc: Dictionary = st()["acc"]
	# 1. the display: new workshop pieces (and, if allowed, the smith's other ordinary pieces)
	if (bool(rules["list_new_work"]) or bool(rules["list_existing"])) and int(Game.state["minute"]) % 60 == 0:
		var made := {}
		for u in acc["made"]:
			made[int(u)] = true
		for it in Game.inventory():
			if not Items.is_equipment(it) or bool(it.get("for_sale", false)) or str(it.get("for_order", "")) != "":
				continue
			var mine_piece := made.has(int(it["uid"]))
			if not ((mine_piece and bool(rules["list_new_work"])) or (not mine_piece and bool(rules["list_existing"]))):
				continue
			if protection_reason(it) != "":
				continue
			if Shop.set_for_sale(int(it["uid"]), true) != "":
				continue
			var mp := min_price(it)
			if Shop.price_of(it) < mp:
				Shop.set_price(int(it["uid"]), mp)
			acc["listed"] = int(acc.get("listed", 0)) + 1
			_log("list", "Put %s on display for %d g." % [Items.display_name(it), Shop.price_of(it)], {"uid": int(it["uid"])})
	# 2. the counter: sell listed ordinary stock to waiting customers at the listed price
	var seen: Dictionary = st()["seen"]
	for c in Shop.waiting().duplicate():
		var npc := str(c["npc"])
		if _personal(npc) or not str(c.get("want", "")) in ["browse", "goods"]:
			continue
		var visit := "serve:%s:%d" % [npc, int(c.get("arrived", 0))]
		if seen.has(visit) and int(Game.state["minute"]) % 60 != 0:
			continue   # looked at when they sat down; again on the hour
		seen[visit] = true
		match str(c.get("want", "")):
			"browse":
				var a := Adv.get_a(npc)
				if a.is_empty():
					continue
				var pick := {}
				var pick_score := -1.0
				for it in Shop.stock():
					if not Items.is_equipment(it) or protection_reason(it) != "" or str(it.get("for_order", "")) != "":
						continue
					if Shop.price_of(it) < min_price(it):
						continue
					if Adv.purchase_check(a, it, Shop.price_of(it)) != "":
						continue
					var sc := Items.score(it)
					if sc > pick_score:
						pick_score = sc
						pick = it
				if pick.is_empty():
					continue
				var nm := Items.display_name(pick)
				var uid := int(pick["uid"])
				var price := Shop.price_of(pick)
				if Shop.sell_to(npc, uid) == "":
					_record_sale(uid, nm, npc, price)
			"goods":
				if not bool(rules["sell_goods"]):
					continue
				var want := str(c.get("looking_for", ""))
				for it2 in Game.inventory():
					if str(it2["def"]) != want or not bool(it2.get("for_sale", false)) or protection_reason(it2) != "":
						continue
					if Game.count(want) - 1 < _reserved(want):
						break
					var unit := Shop.price_of(it2) / maxi(1, int(it2.get("qty", 1)))
					var nm2 := Items.display_name(it2)
					var uid2 := int(it2["uid"])
					if Shop.sell_goods(npc, uid2) == "":
						_record_sale(uid2, str(DB.item(want).get("name", want)) if nm2.contains("×") else nm2, npc, unit)
					break


static func _record_sale(uid: int, name: String, npc: String, price: int) -> void:
	var acc: Dictionary = st()["acc"]
	acc["sold_n"] = int(acc.get("sold_n", 0)) + 1
	acc["sold_gold"] = int(acc.get("sold_gold", 0)) + price
	var sold: Array = acc["sold"]
	sold.append({"uid": uid, "name": name, "npc": npc, "price": price, "day": Game.day()})
	while sold.size() > 60:
		sold.pop_front()
	_log("sell", "Sold %s to %s for %d g." % [name, Talk.npc_name(npc), price], {"uid": uid, "npc": npc, "gold": price})


# ======================================================================= deferrals & sealed correspondence
## Records a matter the steward may not decide. source {type, id, key}: key de-duplicates (one entry per real
## event). action {route, args}: the panel that leads to the actual pending matter. Returns the entry ({} = known).
static func defer(kind: String, text: String, source: Dictionary, sealed := false, action := {}) -> Dictionary:
	var s := st()
	var key := str(source.get("key", "%s:%s" % [str(source.get("type", "")), str(source.get("id", ""))]))
	if _dkeys().has(key):
		return {}
	var src := source.duplicate(true)
	src["key"] = key
	var e2 := {"id": "sd_%d" % int(s["next_id"]), "t": Game.now(), "day": Game.day(), "time": Game.time_string(), "kind": kind, "text": text,
		"source": src, "sealed": sealed, "opened": false, "resolved": false, "outcome": "", "action": action.duplicate(true),
		"from": str(source.get("from", ""))}
	s["next_id"] = int(s["next_id"]) + 1
	(s["deferred"] as Array).append(e2)
	_dkeys()[key] = str(e2["id"])
	_prune_deferred()
	_log("defer", ("A sealed letter arrived: " if sealed else "Left for you: ") + text, {"deferred": e2["id"]}, false)
	if is_active():
		var by: Dictionary = s["acc"].get("deferrals", {})
		by[kind] = int(by.get(kind, 0)) + 1
		s["acc"]["deferrals"] = by
	return e2


## The de-duplication index of deferred matters (source key -> entry id), rebuilt from the list when missing.
## Keys of pruned entries stay (up to 2000), so one real event never comes back as a second matter.
static func _dkeys() -> Dictionary:
	var s := st()
	if not s.has("dkeys") or not s["dkeys"] is Dictionary:
		var idx := {}
		for e in s["deferred"]:
			idx[str(e.get("source", {}).get("key", ""))] = str(e["id"])
		s["dkeys"] = idx
	return s["dkeys"]


## Old, settled matters are dropped (opened or never sealed, resolved, more than 120 entries).
static func _prune_deferred() -> void:
	var d: Array = st()["deferred"]
	var i := 0
	while d.size() > 120 and i < d.size():
		var e: Dictionary = d[i]
		if bool(e["resolved"]) and (not bool(e["sealed"]) or bool(e["opened"])):
			d.remove_at(i)
		else:
			i += 1
	var idx := _dkeys()
	if idx.size() > 2000:
		var live := {}
		for e2 in d:
			live[str(e2.get("source", {}).get("key", ""))] = true
		for k in idx.keys():
			if not live.has(k) and not str(k).begins_with("sealed_piece:"):
				idx.erase(k)


## Matters waiting for the smith (unresolved), oldest first.
static func deferred(include_resolved := false) -> Array:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return []
	return (Game.state["steward"]["deferred"] as Array).filter(func(e): return include_resolved or not bool(e.get("resolved", false)))


## Sealed letters not yet opened.
static func letters() -> Array:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return []
	return (Game.state["steward"]["deferred"] as Array).filter(func(e): return bool(e.get("sealed", false)) and not bool(e.get("opened", false)))


static func _entry(id: String) -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return {}
	for e in Game.state["steward"]["deferred"]:
		if str(e["id"]) == id:
			return e
	return {}


## Opens a sealed letter (or reads any deferred matter): {id, kind, from, text, day, time, sealed, resolved, outcome,
## action {route, args}} — the action leads to the actual pending matter. {} when unknown.
static func open_letter(id: String) -> Dictionary:
	var e := _entry(id)
	if e.is_empty():
		return {}
	e["opened"] = true
	_changed()
	return {"id": str(e["id"]), "kind": str(e["kind"]), "from": str(e.get("from", "")), "text": str(e["text"]), "day": int(e["day"]),
		"time": str(e["time"]), "sealed": bool(e["sealed"]), "resolved": bool(e["resolved"]), "outcome": str(e.get("outcome", "")),
		"action": (e.get("action", {}) as Dictionary).duplicate(true)}


## The smith has dealt with a deferred matter. "" or why not.
static func resolve(id: String) -> String:
	var e := _entry(id)
	if e.is_empty():
		return "No such matter."
	e["resolved"] = true
	e["opened"] = true
	if str(e.get("outcome", "")) == "":
		e["outcome"] = "Seen to by the smith on day %d." % Game.day()
	_changed()
	return ""


## Finds the matters that arose from real events since the last cycle (or, at activation, those already waiting).
static func _scan_deferrals(at_start: bool, full := true) -> void:
	var seal_ok := not at_start
	var known := _dkeys()
	# major contract letters (Contracts.on_day offers): never accepted or declined by the steward
	for c in (Contracts.offers() if full else []):
		var cid := str(c["id"])
		if known.has("contract:" + cid):
			continue
		var p := Contracts.patron(str(c["patron"]))
		var sealed := seal_ok and SEALED_PATRONS.has(str(p.get("kind", "")))
		defer("contract", "A letter from %s: %s. They ask for an answer by day %d. %s" % [Contracts.patron_name(str(c["patron"])), str(c.get("title", "")),
			int(c.get("expires", 0)), str(c.get("why", ""))], {"type": "contract", "id": cid, "key": "contract:" + cid,
			"from": Contracts.patron_name(str(c["patron"]))}, sealed, {"route": "contracts", "args": {"id": cid}})
	if full and Game.state.has("apprentices"):
		var ap: Dictionary = Game.state["apprentices"]
		for n in ap.get("notices", []):
			if str(n.get("kind", "")) == "independence":
				var aid := str(n.get("app", ""))
				var nk := "indep:%s:%d" % [aid, int(n.get("day", 0))]
				if known.has(nk):
					continue
				defer("notice", str(n.get("text", "An apprentice asks to open a workshop of their own.")) + " (Answer by day %d.)" % int(n.get("due", 0)),
					{"type": "notice", "id": aid, "key": nk, "from": str(Apprentices.get_a(aid).get("name", ""))},
					seal_ok, {"route": "apprentice", "args": {"id": aid}})
		for a in ap.get("staff", []):
			var nt: Dictionary = a.get("notice", {})
			if str(nt.get("kind", "")) == "leave":
				var lk := "leave:%s:%d" % [str(a["id"]), int(nt.get("due", 0))]
				if known.has(lk):
					continue
				defer("staff", "%s has not been paid and will leave on day %d unless wages are paid." % [str(a["name"]), int(nt.get("due", 0))],
					{"type": "notice", "id": str(a["id"]), "key": lk}, false, {"route": "workshop", "args": {}})
	# visitors the steward cannot answer: advice, disputes, the spouse
	for c2 in Shop.customers():
		var want := str(c2.get("want", ""))
		var npc := str(c2["npc"])
		if not bool(c2.get("present", true)) or not (want in ["advice", "dispute"] or _personal(npc)):
			continue
		var arrived := int(c2.get("arrived", 0))
		var key := "cust:%s:%d" % [npc, arrived]
		if known.has(key):
			continue
		var nm := Talk.npc_name(npc)
		var src := {"type": "customer", "id": npc, "arrived": arrived, "key": key, "from": nm}
		if _personal(npc):
			defer("personal", "%s came by the shop asking for you." % nm, src, false, {"route": "shop", "args": {"npc": npc}})
		elif want == "advice":
			var dest := str(c2.get("dest", ""))
			defer("visitor", "%s came for advice on their gear%s; only you can give it." % [nm, (" before " + Consult.dest_name(dest)) if dest != "" else ""],
				src, false, {"route": "consult", "args": {"id": npc}})
		else:
			defer("dispute", "%s came back with a grievance about %s and wants it settled (%d g refund asked)." % [nm, str(c2.get("item_name", "your work")), int(c2.get("refund", 0))],
				src, false, {"route": "shop", "args": {"npc": npc}})
	# extraordinary commissions: fame and the spouse's
	for o in (Shop.orders() if full else []):
		if str(o.get("status", "")) != "open" or known.has("order:" + str(o["id"])):
			continue
		var ex := _extraordinary(o)
		if ex == "":
			continue
		var on := Talk.npc_name(str(o["npc"]))
		defer("fame_commission" if ex == "fame" else "personal", ("%s's commission was inspired by one of your famous pieces: %s (by day %d)." if ex == "fame"
			else "%s asked you for %s (by day %d) — a family matter the steward left to you.") % [on, Shop.order_text(o), int(o.get("deadline", 0))],
			{"type": "order", "id": str(o["id"]), "key": "order:" + str(o["id"]), "from": on}, false, {"route": "orders", "args": {}})
	if not at_start and full:
		_scan_lore()


## Lore since the last cycle: deeds, names and losses of the workshop's pieces, deaths touching the smith's work,
## inheritance of his pieces, sponsored expeditions coming home.
static func _scan_lore() -> void:
	var acc: Dictionary = st()["acc"]
	var nxt := int(Lore.st()["next"])
	var spouse := Social.spouse()
	for n in range(int(acc["lore_seen"]), nxt):
		var e := Lore.event("ev_%d" % n)
		if e.is_empty():
			continue
		var kind := str(e.get("kind", ""))
		if not kind in ["epic", "named", "deed", "awakened", "lost", "destroyed", "death", "inherited", "sponsored"]:
			continue
		var imp := int(e.get("importance", 0))
		var ours := []
		for u in e.get("items", []):
			var it := ItemRegistry.find(int(u))
			if not it.is_empty() and Provenance.is_workshop(it):
				ours.append(it)
		var src := {"type": "lore", "id": str(e["id"]), "key": "lore:" + str(e["id"])}
		var act := {"route": "history", "args": {"kind": "item", "id": str(int(ours[0]["uid"]))}} if not ours.is_empty() else {"route": "", "args": {}}
		# sealed letters are rare by construction: the first Epic distinction of a piece from the smith's OWN hand,
		# the loss of a famous piece, a death touching him (his spouse, or the bearer of a famous piece of his) —
		# and never more than one sealed letter about the same piece
		match kind:
			"epic", "named":
				if not ours.is_empty():
					var seal: bool = kind == "epic" and imp >= 3 and Provenance.is_mine(ours[0]) and _seal_piece(ours[0])
					defer("deed", str(e["text"]), src, seal, act)
			"deed", "awakened":
				if not ours.is_empty() and imp >= 2:
					defer("deed", str(e["text"]), src, false, act)
			"lost", "destroyed":
				if not ours.is_empty() and imp >= 2:
					defer("loss", str(e["text"]), src, _famous(ours[0]) and _seal_piece(ours[0]), act)
			"death":
				var actors: Array = e.get("actors", [])
				var famous_bearer := ours.any(func(x): return _famous(x))
				var spouse_died := spouse != "" and actors.has(spouse)
				if not ours.is_empty() or spouse_died:
					var who := str(actors[0]) if not actors.is_empty() else ""
					defer("death", str(e["text"]) + (" They carried your work." if not ours.is_empty() else ""), src,
						spouse_died or famous_bearer, {"route": "dossier", "args": {"id": who}} if who != "" else act)
			"inherited":
				if not ours.is_empty() and Provenance.is_notable(ours[0]):
					defer("inheritance", str(e["text"]), src, false, act)
			"sponsored":
				var who2 := str((e.get("actors", []) as Array)[0]) if not (e.get("actors", []) as Array).is_empty() else ""
				defer("sponsorship", str(e["text"]), src, false, {"route": "dossier", "args": {"id": who2}} if who2 != "" else act)
	acc["lore_seen"] = nxt


## A famous piece: named, Epic, or historically significant.
static func _famous(it: Dictionary) -> bool:
	return it.has("epic") or ItemStory.is_named(it) or Provenance.is_notable(it)


## True the first time a sealed letter is written about this piece (one sealed letter per piece, ever).
static func _seal_piece(it: Dictionary) -> bool:
	var idx := _dkeys()
	var k := "sealed_piece:%d" % int(it.get("uid", -1))
	if idx.has(k):
		return false
	idx[k] = "sealed"
	return true


## The world moves on: matters that ended without the smith are marked so (never frozen waiting for him).
static func _refresh_deferred() -> void:
	for e in st()["deferred"]:
		if bool(e["resolved"]):
			continue
		var src: Dictionary = e.get("source", {})
		var id := str(src.get("id", ""))
		var gone := ""
		match str(src.get("type", "")):
			"contract":
				if not Contracts.offers().any(func(c): return str(c["id"]) == id):
					var c2 := Contracts.get_c(id)
					gone = "The letter went unanswered and the offer lapsed." if c2.is_empty() or str(c2.get("status", "")) in ["expired", "offered"] else "The offer is no longer open (%s)." % str(c2.get("status", ""))
			"notice":
				var a := Apprentices.get_a(id) if Game.state.has("apprentices") else {}
				if str(src.get("key", "")).begins_with("indep:"):
					if a.is_empty() or str(a.get("notice", {}).get("kind", "")) != "independence":
						gone = "%s's notice ran out: they went to open their own workshop." % str(src.get("from", "The apprentice")) if a.is_empty() else "The notice was answered."
				elif a.is_empty() or str(a.get("notice", {}).get("kind", "")) != "leave":
					gone = "They left the workshop unpaid." if a.is_empty() else "Wages were paid; they stayed."
			"customer":
				var arr := int(src.get("arrived", -1))
				var still := Shop.customers().any(func(c): return str(c["npc"]) == id and int(c.get("arrived", 0)) == arr)
				if not still:
					gone = "%s left the shop." % str(src.get("from", "The visitor"))
			"order":
				var o := _order(id)
				if o.is_empty() or str(o.get("status", "")) != "open":
					gone = "The commission is no longer open (%s)." % str(o.get("status", "gone"))
		if gone != "":
			e["resolved"] = true
			e["outcome"] = gone
			e["resolved_by"] = "world"
			e["resolved_day"] = Game.day()


# ======================================================================= live status
## For the live status view: {active, since_day, since_time, elapsed_minutes, decisions, last, stalls [{duty, text}],
## deferred, letters, spent_today, spent_session, spendable, gold, reserve}.
static func status() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("steward"):
		return {"active": false}
	var s := st()
	var since: Dictionary = s["since"]
	var stalls: Array = []
	for d in s["stall"]:
		var k := str(s["stall"][d])
		stalls.append({"duty": str(d), "name": str(DUTY_NAME.get(d, d)), "code": k.get_slice("|", 0), "text": k.substr(k.find("|") + 1)})
	var lg: Array = s["log"]
	var last := {}
	for i in range(lg.size() - 1, -1, -1):
		if not str(lg[i]["kind"]) in ["stall", "defer"]:
			last = lg[i]
			break
	return {"active": is_active(), "since_day": int(since.get("day", 0)), "since_time": str(since.get("time", "")),
		"elapsed_minutes": (Game.now() - int(since.get("t", Game.now()))) if is_active() else 0,
		"decisions": int(s["acc"].get("decisions", 0)), "last": last, "stalls": stalls, "deferred": deferred().size(), "letters": letters().size(),
		"spent_today": _spent_today() if is_active() else 0, "spent_session": int(s["acc"].get("spent", 0)), "spendable": spendable(),
		"gold": Game.gold(), "reserve": int(s["orders"]["reserve"])}


# ======================================================================= the report
static func _elapsed_text(mins: int) -> String:
	var d := int(mins / 1440)
	var h := int((mins % 1440) / 60)
	if d > 0:
		return "%d day%s%s" % [d, "" if d == 1 else "s", (" and %d hour%s" % [h, "" if h == 1 else "s"]) if h > 0 else ""]
	return "%d hour%s" % [h, "" if h == 1 else "s"]


## "While You Were Away", built only from the steward log, ledger lines, Lore events and the activation snapshot.
static func report() -> Dictionary:
	var s := st()
	var since: Dictionary = s["since"]
	var acc: Dictionary = s["acc"]
	if since.is_empty():
		return {}
	var mins := Game.now() - int(since["t"])
	var r := {"from": {"day": int(since["day"]), "time": str(since["time"]), "t": int(since["t"])},
		"to": {"day": Game.day(), "time": Game.time_string(), "t": Game.now()}, "elapsed_minutes": mins, "elapsed_text": _elapsed_text(mins)}
	# gold: the ledger lines of the session must explain every coin
	var lsum := 0
	for c in acc["ledger"]:
		lsum += int(acc["ledger"][c])
	var change := Game.gold() - int(since["gold"])
	r["gold"] = {"start": int(since["gold"]), "end": Game.gold(), "change": change, "income": int(acc["income"]), "expenses": int(acc["expense"]),
		"by_category": (acc["ledger"] as Dictionary).duplicate(), "lines": int(acc["lines"]), "reconciled": lsum == change, "unexplained": change - lsum,
		"recent": (acc["recent"] as Array).duplicate(true), "steward_spent": int(acc.get("spent", 0))}
	# orders
	var pending: Array = []
	for o in Shop.open_orders():
		var t := _commission_task(str(o["id"]))
		pending.append({"id": str(o["id"]), "text": "%s for %s" % [Shop.order_text(o), Talk.npc_name(str(o["npc"]))], "deadline": int(o.get("deadline", 0)),
			"in_hand": not t.is_empty(), "state": str(t.get("state", "")) if not t.is_empty() else "not taken on"})
	r["orders"] = {"accepted": (acc["accepted"] as Array).duplicate(), "delivered": (acc["delivered"] as Array).duplicate(),
		"declined": (acc["declined"] as Array).duplicate(), "pending": pending,
		"counts": {"accepted": (acc["accepted"] as Array).size(), "delivered": (acc["delivered"] as Array).size(),
			"declined": (acc["declined"] as Array).size(), "pending": pending.size()}}
	# production (apprentice task completions)
	var made: Array = []
	for u in acc["made"]:
		var it := ItemRegistry.find(int(u))
		made.append({"uid": int(u), "name": Items.display_name(it) if not it.is_empty() else "(since gone into the world)",
			"where": str(ItemRegistry.where(int(u)).get("holder", "")) if not it.is_empty() else ""})
	r["production"] = {"completed": (acc["completed"] as Dictionary).duplicate(), "made_count": int(acc["made_n"]),
		"made": made.slice(maxi(0, made.size() - 40)), "failed": int(acc["failed"]), "failed_why": (acc.get("failed_why", {}) as Dictionary).duplicate(), "materials": (acc.get("produced", {}) as Dictionary).duplicate(true),
		"apprentice_crafted": int(Game.state["stats"].get("apprentice_crafted", 0)) - int(since.get("apprentice_crafted", 0)),
		"smith_crafted": int(Game.state["stats"].get("crafted", 0)) - int(since.get("crafted", 0))}
	# purchases and sales
	var bought: Array = []
	var bk: Array = (acc["bought"] as Dictionary).keys()
	bk.sort()
	for d in bk:
		bought.append({"item_def": str(d), "name": str(DB.item(str(d)).get("name", d)), "qty": int(acc["bought"][d][0]), "cost": int(acc["bought"][d][1])})
	r["purchases"] = {"items": bought, "total": int(acc.get("spent", 0))}
	r["sales"] = {"count": int(acc.get("sold_n", 0)), "gold": int(acc.get("sold_gold", 0)), "recent": (acc["sold"] as Array).duplicate(true),
		"listed": int(acc.get("listed", 0)), "ledger_sales": int(acc["ledger"].get("sales", 0))}
	# stock changes
	var now_inv := _inv_counts()
	var before: Dictionary = since["inv"]
	var keys := {}
	for k in now_inv:
		keys[k] = true
	for k2 in before:
		keys[k2] = true
	var ks := keys.keys()
	ks.sort()
	var stock: Array = []
	for d2 in ks:
		var a0 := int(before.get(d2, 0))
		var a1 := int(now_inv.get(d2, 0))
		if a0 != a1:
			stock.append({"item_def": str(d2), "name": str(DB.item(str(d2)).get("name", d2)), "before": a0, "after": a1, "change": a1 - a0})
	r["stock"] = stock
	# employees
	var staff: Array = []
	var was: Dictionary = since["staff"]
	if Game.state.has("apprentices"):
		for a in Apprentices.staff():
			var w: Dictionary = was.get(str(a["id"]), {})
			staff.append({"id": str(a["id"]), "name": str(a["name"]), "rank_before": str(w.get("rank", "")), "rank": str(a["rank"]),
				"rank_name": Apprentices.rank_name(a), "works": int(a.get("works", 0)) - int(w.get("works", 0)), "joined": w.is_empty(),
				"status": str(a.get("status", "")), "notice": str(a.get("notice", {}).get("kind", ""))})
	r["staff"] = {"current": staff, "left": (acc["staff_left"] as Array).duplicate(true)}
	# significant world developments: Lore importance ≥ 2, none that the steward's own sales/deliveries made
	var own := {}
	for x in acc["sold"]:
		own[int(x["uid"])] = true
	for lg in s["log"]:
		if lg.get("data", {}).has("uid"):
			own[int(lg["data"]["uid"])] = true
	var world: Array = []
	var wn := 0
	for n in range(int(since["lore_next"]), int(Lore.st()["next"])):
		var e := Lore.event("ev_%d" % n)
		if e.is_empty() or int(e.get("importance", 0)) < 2:
			continue
		if (e.get("items", []) as Array).any(func(u): return own.has(int(u))) and str(e.get("kind", "")) in ["sold", "given", "commission"]:
			continue
		wn += 1
		world.append({"id": str(e["id"]), "day": int(e["day"]), "time": str(e["time"]), "kind": str(e["kind"]), "text": str(e["text"]), "importance": int(e["importance"])})
	r["world"] = {"count": wn, "events": world.slice(maxi(0, world.size() - 30))}
	# what waits for the smith
	r["deferred"] = deferred().map(func(e): return {"id": str(e["id"]), "kind": str(e["kind"]), "text": str(e["text"]), "day": int(e["day"]), "sealed": bool(e["sealed"])})
	r["letters"] = letters().map(func(e): return {"id": str(e["id"]), "kind": str(e["kind"]), "from": str(e.get("from", "")), "day": int(e["day"])})
	var settled: Array = []
	for e2 in deferred(true):
		if bool(e2.get("resolved", false)) and str(e2.get("resolved_by", "")) == "world" and int(e2.get("t", 0)) >= int(since["t"]):
			settled.append({"id": str(e2["id"]), "text": str(e2["text"]), "outcome": str(e2.get("outcome", ""))})
	r["lapsed"] = settled
	# the steward's own conduct
	var stalls: Array = []
	for code in acc["stalled"]:
		stalls.append({"code": str(code), "count": int(acc["stalled"][code]["n"]), "text": str(acc["stalled"][code]["text"]), "duty": str(acc["stalled"][code].get("duty", ""))})
	r["decisions"] = {"total": int(acc.get("decisions", 0)), "by_kind": (acc["by_kind"] as Dictionary).duplicate(), "stalls": stalls,
		"deferrals": (acc.get("deferrals", {}) as Dictionary).duplicate()}
	return r
