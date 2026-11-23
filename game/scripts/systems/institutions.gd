## Institutions — the village and its militia as real recipients (R4 "Commissions v2 & Civic Recipients": WLD-005,
## WLD-006 groundwork, TECH-031, ECO-023, D5, D14).
## EN: Before R4 a delivered contract left the forge as a line of text: the muster "received" forty swords that existed
##     nowhere. Now the patrons that are institutions keep what they are given:
##       village   Brindlewick, run by its reeve (Reeve Tamsin Hale — her title is unchanged; whether the reeve is the
##                 canonical "mayor" is an open decision, R8 / decision 7). Its purse pays the outfitting subsidy (D14)
##                 and receives the village's income; every payment in or out is a payer record.
##       muster    the Brindlewick muster, the village's militia (patron "brindlewick_muster").
##       watch     the Highmarsh Watch (patron "highmarsh_watch").
##     Each holds:
##       supply {def: {n, q_sum}}   bulk pieces received, by kind (a lot record says where each came from);
##       stock  [items]             individually made pieces (named prestige pieces) — real items, same uid, in
##                                  ItemRegistry's "institution" holder;
##       lots   [lot]               one record per delivery: what, how many, quality, contributors, day, contract;
##       purse, payments            the village's purse and its payer records (never capped).
##     Passive for now: the militia does not yet act on what it holds (R8 makes its equipment count).
##     State: Game.state["institutions"] (created on first write; reads are pure).
## DA: Landsbyen og dens milits som virkelige modtagere: lager, partiregistre, pung og betalingsregistre.
class_name Institutions
extends RefCounted

const DEFS := {
	"village": {"name": "Brindlewick", "kind": "village", "head": "Reeve Tamsin Hale", "head_title": "reeve", "place": "brindlewick"},
	"muster": {"name": "the Brindlewick muster", "kind": "militia", "patron": "brindlewick_muster", "of": "village",
		"head": "Reeve Tamsin Hale", "head_title": "reeve", "place": "brindlewick"},
	"watch": {"name": "the Highmarsh Watch", "kind": "watch", "patron": "highmarsh_watch", "head": "Captain Hedda Rourke",
		"head_title": "captain", "place": "highmarsh_road"},
}
## The village purse: what it starts with and what it takes in each week (tolls, the mill's dues, market fees).
const PURSE_START := 400
const PURSE_WEEKLY := 90


static func _blank(id: String) -> Dictionary:
	return {"id": id, "supply": {}, "stock": [], "lots": [], "purse": PURSE_START if id == "village" else 0, "payments": [],
		"next_lot": 1}


static func _all() -> Dictionary:
	var v: Variant = Game.state.get("institutions")
	return v if v is Dictionary else {}


## An institution's state, created on first write.
static func st(id: String) -> Dictionary:
	if not DEFS.has(id):
		return {}
	if not Game.state.get("institutions") is Dictionary:
		Game.state["institutions"] = {}
	var all: Dictionary = Game.state["institutions"]
	if not all.has(id):
		all[id] = _blank(id)
	return all[id]


## Read-only view (no state created).
static func peek(id: String) -> Dictionary:
	return _all().get(id, {})


static func name_of(id: String) -> String:
	return str(DEFS.get(id, {}).get("name", id))


static func holder_id(id: String) -> String:
	return "inst_" + id


## The institution a contract patron stands for ("" when the patron is a private person).
static func of_patron(pid: String) -> String:
	for id in DEFS:
		if str(DEFS[id].get("patron", "")) == pid:
			return id
	return ""


# ======================================================================= deliveries
## Records a delivery: the bulk lines into supply, the individually made pieces into stock (same instances), and one
## lot record. Returns the lot.
static func receive(id: String, from: String, lines: Array, items: Array, quality: float, contributors: Array, data := {}) -> Dictionary:
	var s := st(id)
	if s.is_empty():
		return {}
	var sup: Dictionary = s["supply"]
	var parts := []
	for l in lines:
		var d := str(l.get("def", ""))
		var n := int(l.get("n", 0))
		if d == "" or n <= 0:
			continue
		if not sup.has(d):
			sup[d] = {"n": 0, "q_sum": 0.0}
		sup[d]["n"] = int(sup[d]["n"]) + n
		sup[d]["q_sum"] = float(sup[d]["q_sum"]) + quality * n
		parts.append({"def": d, "n": n, "quality": snappedf(quality, 0.1)})
	var uids := []
	for it in items:
		if it is Dictionary and not (it as Dictionary).is_empty():
			(s["stock"] as Array).append(it)
			uids.append(int(it.get("uid", -1)))
	var lot := {"id": "%s_lot_%d" % [id, int(s["next_lot"])], "day": Game.day(), "from": from, "lines": parts, "pieces": uids,
		"quality": snappedf(quality, 0.1), "contributors": contributors.duplicate(true), "data": data.duplicate(true)}
	s["next_lot"] = int(s["next_lot"]) + 1
	(s["lots"] as Array).append(lot)
	return lot


## How many of a kind of piece the institution holds (bulk supply plus individual pieces).
static func holds(id: String, def := "") -> int:
	var s := peek(id)
	if s.is_empty():
		return 0
	var n := 0
	for d in s.get("supply", {}):
		if def == "" or str(d) == def:
			n += int(s["supply"][d]["n"])
	for it in s.get("stock", []):
		if def == "" or str(it.get("def", "")) == def:
			n += 1
	return n


static func lots(id: String) -> Array:
	return peek(id).get("lots", [])


static func stock(id: String) -> Array:
	return peek(id).get("stock", [])


# ======================================================================= the village purse (D14)
## A payment out of the village purse (the outfitting subsidy …). The purse may run short — the village then owes
## the difference, and the record says so; nothing is ever paid from nowhere.
static func pay_from_village(amount: int, purpose: String, to: String, ref := "") -> Dictionary:
	var s := st("village")
	var before := int(s["purse"])
	s["purse"] = before - amount
	var rec := {"day": Game.day(), "amount": -amount, "purpose": purpose, "to": to, "ref": ref, "purse": int(s["purse"])}
	if int(s["purse"]) < 0:
		rec["owed"] = mini(amount, -int(s["purse"]))
	(s["payments"] as Array).append(rec)
	return rec


## The village's weekly income (Sim.on_day, every seventh day).
static func on_day(day: int) -> void:
	if day % 7 != 0 or not Game.state.get("institutions") is Dictionary or not _all().has("village"):
		return
	var s := st("village")
	s["purse"] = int(s["purse"]) + PURSE_WEEKLY
	(s["payments"] as Array).append({"day": day, "amount": PURSE_WEEKLY, "purpose": "tolls, the mill's dues and market fees",
		"to": "village", "ref": "", "purse": int(s["purse"])})


static func purse() -> int:
	var s := peek("village")
	return int(s.get("purse", PURSE_START))
