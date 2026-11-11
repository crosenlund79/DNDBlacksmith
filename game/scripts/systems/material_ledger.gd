## MaterialLedger — what came into the stores, from where, what was used, and what is left (Living Workshop #46).
## EN: Records every material (item type "material") the smith's stores gain or lose from the moment the ledger
##     begins — a new game from its first minute, an older save from the first movement after it is loaded. Nothing
##     is reconstructed: the stock already on hand when the record began is shown as "on hand before day N, origin
##     unknown", and a change made by a path that does not pass through Game.add_item / Game.remove_def (a sale of
##     materials to the caravan, a gift) is booked, when next seen, as "not itemised" — never given an invented source.
##     Sources: starting stores, made at the smith's stations, made by a named worker, bought (with the seller, from the
##     purchase's ledger line written in the same game minute and naming this material), developer tools, and
##     "received" (hauls, deliveries, gifts, work returned unused). The gold ledger is untouched.
##     State (lazy, created on the first movement): Game.state["mat_ledger"] = {since: day, since_t: minute,
##     open: {def: qty on hand when the record began}, m: {def: {in: {source: qty}, out: qty, x: ±qty}},
##     recent: [[t, def, ±qty, source], … ≤ RECENT]}.
## DA: Registrerer materialer ind og ud af lageret fra det øjeblik, registreringen begynder; tidligere beholdning vises
##     som "før dag N, ukendt oprindelse". Intet opfindes.
class_name MaterialLedger
extends RefCounted

const KEY := "mat_ledger"
const RECENT := 60
const PURCHASE_CATS := ["materials", "imports", "caravan", "pawn", "creatures", "equipment"]
const SRC_START := "Starting stores"
const SRC_OWN := "Made at your stations"
const SRC_DEV := "Developer tools"
const SRC_RECEIVED := "Received — hauls, deliveries, gifts, work returned unused"

## The last purchase line written to the gold ledger and the game minute it was written (Game.add_gold → note_gold),
## so materials that arrive in that same minute are attributed to that seller.
static var _last_buy: Dictionary = {}
static var _last_buy_t := -1


static func is_material(def_id: String) -> bool:
	return str(DB.item(def_id).get("type", "")) == "material"


## The ledger, or {} when nothing has been recorded yet (reading never creates it).
static func st() -> Dictionary:
	if Game.state.is_empty():
		return {}
	var l: Variant = Game.state.get(KEY, {})
	return l if l is Dictionary else {}


## Creates the ledger on the first movement: what is on hand now is the opening stock of unknown origin.
static func _ensure() -> Dictionary:
	var l := st()
	if not l.is_empty():
		return l
	var open := {}
	for it in Game.inventory():
		var d := str(it.get("def", ""))
		if is_material(d):
			open[d] = int(open.get(d, 0)) + int(it.get("qty", 1))
	l = {"since": Game.day(), "since_t": Game.now(), "open": open, "m": {}, "recent": []}
	Game.state[KEY] = l
	return l


static func _m(l: Dictionary, d: String) -> Dictionary:
	var mm: Dictionary = l["m"]
	if not mm.has(d):
		mm[d] = {"in": {}, "out": 0, "x": 0}
	return mm[d]


## What the record says should be in the stores (opening + in − out ± not itemised).
static func expected(d: String) -> int:
	var l := st()
	if l.is_empty():
		return Game.count(d)
	var e := int((l["open"] as Dictionary).get(d, 0))
	var m: Dictionary = (l["m"] as Dictionary).get(d, {})
	for s in m.get("in", {}):
		e += int(m["in"][s])
	return e - int(m.get("out", 0)) + int(m.get("x", 0))


## Books any difference between the record and the stores (a change that bypassed the hooks) as "not itemised".
static func _reconcile(l: Dictionary, d: String) -> void:
	var diff := Game.count(d) - expected(d)
	if diff != 0:
		var m := _m(l, d)
		m["x"] = int(m["x"]) + diff
		_recent(l, d, diff, "not itemised")


static func _recent(l: Dictionary, d: String, q: int, src: String) -> void:
	var r: Array = l["recent"]
	r.append([Game.now(), d, q, src])
	while r.size() > RECENT:
		r.pop_front()


## Game.add_item hook (before the item joins the stores).
static func on_add(item: Dictionary) -> void:
	var d := str(item.get("def", ""))
	if Game.state.is_empty() or not is_material(d):
		return
	var l := _ensure()
	_reconcile(l, d)
	var q := int(item.get("qty", 1))
	var src := source_of(item)
	var m := _m(l, d)
	(m["in"] as Dictionary)[src] = int((m["in"] as Dictionary).get(src, 0)) + q
	_recent(l, d, q, src)


## Game.remove_def hook (after the stores were checked to hold `qty`, before they are taken).
static func on_remove(d: String, qty: int) -> void:
	if Game.state.is_empty() or not is_material(d) or qty <= 0:
		return
	var l := _ensure()
	_reconcile(l, d)
	var m := _m(l, d)
	m["out"] = int(m["out"]) + qty
	_recent(l, d, -qty, "used")


## Game.add_gold hook: remembers a purchase line for the materials that arrive in the same minute.
static func note_gold(line: Dictionary) -> void:
	if int(line.get("amount", 0)) < 0 and str(line.get("cat", "")) in PURCHASE_CATS:
		_last_buy = line
		_last_buy_t = Game.now()


## Where an incoming material came from, from what the game actually knows at that moment.
static func source_of(item: Dictionary) -> String:
	if bool(item.get("dev", false)):
		return SRC_DEV
	if (Game.state.get("journal", []) as Array).is_empty() and Game.day() == 1:
		return SRC_START   # Game.new_game fills the stores before its first journal line
	var cr: Variant = item.get("craft", null)
	if cr is Dictionary:
		var mk := str((cr as Dictionary).get("maker_name", ""))
		return ("Made by " + mk) if mk != "" else SRC_OWN
	if str(item.get("crafted_by", "")) != "":
		return "Made by " + str(item["crafted_by"])
	# bought: a purchase line written this same game minute that names this very material (every purchase line does:
	# "Pell's Provisions: 3 × Coal", "Caravan: 2 × Wyvern Hide", "Bought Iron Ore from Garrick"); used once
	var nm := str(DB.item(str(item.get("def", ""))).get("name", ""))
	if _last_buy_t == Game.now() and not _last_buy.is_empty() and nm != "" and str(_last_buy.get("note", "")).contains(nm):
		var who := Payments.party_name(str(_last_buy.get("party", "")))
		if who == "":
			who = str(_last_buy.get("cat", ""))
		_last_buy = {}
		return "Bought — " + who
	return SRC_RECEIVED


# ---------------------------------------------------------------- reading (the panel, tests)
## One row per material that was ever recorded or is in the stores now, sorted by name:
## {def, name, remaining, acquired, sources: [[source, qty]…], used, unitemised, before (on hand before the record,
## origin unknown), since}.
static func rows() -> Array:
	var l := st()
	var defs := {}
	for it in Game.inventory():
		var d := str(it.get("def", ""))
		if is_material(d):
			defs[d] = true
	if not l.is_empty():
		for d in l["m"]:
			defs[d] = true
		for d in l["open"]:
			defs[d] = true
	var out := []
	for d in defs:
		var m: Dictionary = (l.get("m", {}) as Dictionary).get(d, {})
		var srcs := []
		var acq := 0
		for s in m.get("in", {}):
			srcs.append([str(s), int(m["in"][s])])
			acq += int(m["in"][s])
		srcs.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		var rem := Game.count(str(d))
		var before := int((l.get("open", {}) as Dictionary).get(d, 0)) if not l.is_empty() else rem
		var unit := int(m.get("x", 0))
		if not l.is_empty():
			unit += rem - expected(str(d))   # a change not yet seen by a hook
		out.append({"def": str(d), "name": str(DB.item(str(d)).get("name", d)), "remaining": rem, "acquired": acq,
			"sources": srcs, "used": int(m.get("out", 0)), "unitemised": unit, "before": before,
			"since": int(l.get("since", Game.day()))})
	out.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return out


## The day the record began (the current day when nothing has moved yet).
static func since_day() -> int:
	var l := st()
	return int(l.get("since", Game.day())) if not l.is_empty() else Game.day()


## True when the record covers the whole game (it began with a new game's starting stores).
static func complete() -> bool:
	var l := st()
	return not l.is_empty() and int(l.get("since", 0)) == 1 and (l.get("open", {}) as Dictionary).is_empty()


static func recent() -> Array:
	var l := st()
	return (l.get("recent", []) as Array) if not l.is_empty() else []
