## Captains — the named captains of Brindlewick harbour and their voyages (R7 "Negotiation & Procurement"; ECO-036,
## ECO-037, QST-012, decision 12). Not a naval game (§1.3): a voyage is a timed record, never sailing.
## EN: The nine captains and skippers who sail the three ships' routes (data/trade.json) are persistent people. Every
##     ship's call is THEIR visit (Trade._dock → on_dock): counted, remembered, and greeted with what they remember of
##     the smith. While a captain is in port the smith can commission a procurement voyage: a known importable good,
##     a quantity, a price (the harbour's import price, less a discount for the trust they have earned), a deposit now
##     (coin and/or goods — Barter: a piece counts at CAPTAIN_SHARE as cargo to sell) and the balance on delivery.
##     The voyage starts when they sail; on its due day it is decided (seeded "commerce" stream, the ship's own risk):
##       success  — the cargo waits at the harbour for the smith;
##       delayed  — weather or a bad port: due DELAY days later (once), then decided again;
##       failed   — the cargo is lost; the captain returns half the deposit, as honest captains do.
##     Each outcome is reported as it happened (Lore + Chronicle, the captain as actor). The captain remembers the
##     payment: the balance paid within PAY_DAYS of arrival builds trust (better terms next time — lower price and
##     deposit); a cargo left unpaid past ABANDON_DAYS is sold elsewhere, the deposit kept, and trust falls. On the
##     next visit the captain says what they remember.
##     State: Game.state["captains"] = {roster: {cid: captain}, voyages: [voyage], seq} — created on first write.
## DA: Navngivne kaptajner med tidsbestemte rejser, sandfærdige udfald og hukommelse om betalinger.
class_name Captains
extends RefCounted

## Each route's character: lead-time factor and the share of voyages that fail (the barge is slow and sure).
const ROUTE := {"spice": {"speed": 1.0, "risk": 0.10}, "barge": {"speed": 1.3, "risk": 0.05}, "whaler": {"speed": 1.1, "risk": 0.15}}
const DELAY_SHARE := 0.2
const DELAY := [2, 4]
const PAY_DAYS := 3
const ABANDON_DAYS := 8
const TRUST_MAX := 3
const DISCOUNT_PER_TRUST := 0.05
const BASE_DEPOSIT := 0.4
const MAX_OPEN := 3
## Tests can force a voyage's outcome: "success", "delayed" or "failed" — for one voyage by id (`force`), or for the
## next one decided (`force_outcome`, like Hire.force_outcome).
static var force_outcome := ""
static var force := {}


# ======================================================================= state
static func st() -> Dictionary:
	var c: Variant = Game.state.get("captains", {})
	return c if c is Dictionary else {}


static func _w() -> Dictionary:
	if not Game.state.get("captains") is Dictionary:
		Game.state["captains"] = {"roster": {}, "voyages": [], "seq": 0}
	return Game.state["captains"]


static func id_of(captain_name: String) -> String:
	return "cap_" + captain_name.to_lower().replace("captain ", "").replace("skipper ", "").strip_edges().replace(" ", "_")


## The roster entry for a captain (created on first meeting from the trade data).
static func get_c(cid: String) -> Dictionary:
	return st().get("roster", {}).get(cid, {})


static func _ensure(cid: String, cname: String, ship: String, type: String) -> Dictionary:
	var r: Dictionary = _w()["roster"]
	if not r.has(cid):
		r[cid] = {"id": cid, "name": cname, "ship": ship, "type": type, "met": Game.day(), "visits": 0, "last_visit": -1,
			"trust": 0, "memory": []}
	return r[cid]


## Every captain the data names, as {id, name, ship, type} (for lists; no state is created).
static func roster_data() -> Array:
	var out := []
	for t in Trade.cfg().get("ships", {}):
		for nm in Trade.ship_type(str(t)).get("names", []):
			out.append({"id": id_of(str(nm[1])), "name": str(nm[1]), "ship": str(nm[0]), "type": str(t)})
	return out


## The captain in port now ({} when no ship is docked).
static func in_port() -> Dictionary:
	var s := Trade.current_ship()
	if s.is_empty():
		return {}
	return _ensure(id_of(str(s["captain"])), str(s["captain"]), str(s["name"]), str(s["type"]))


static func voyages(cid := "") -> Array:
	return (st().get("voyages", []) as Array).filter(func(v): return cid == "" or str(v["captain"]) == cid)


static func open_voyages() -> Array:
	return voyages().filter(func(v): return str(v["status"]) in ["agreed", "at_sea", "delayed", "arrived"])


# ======================================================================= visits and memory
## A ship docked (Trade._dock): the captain's visit, and what they remember.
static func on_dock(type: String, ship: String, cname: String) -> void:
	var c := _ensure(id_of(cname), cname, ship, type)
	c["visits"] = int(c["visits"]) + 1
	c["last_visit"] = Game.day()
	var line := greeting(c)
	if line != "":
		c["last_greeting"] = line
		Chronicle.add("trade", "%s, in port again: %s" % [cname, line], {"captain": str(c["id"])})


## What the captain says of their dealings with the smith (their memory; "" when there is none).
static func greeting(c: Dictionary) -> String:
	var mem: Array = c.get("memory", [])
	if mem.is_empty():
		return ""
	var last: Dictionary = mem[-1]
	match str(last.get("kind", "")):
		"paid":
			return "\"You paid in full for the %s on day %d — I don't forget that. My price for you is the better for it.\"" % [str(last.get("goods", "cargo")), int(last.get("day", 0))]
		"unpaid":
			return "\"The %s I brought you sat on the quay unpaid. I sold it in Saltreach. Coin first this time.\"" % str(last.get("goods", "cargo"))
		"lost":
			return "\"I lost your %s to the sea, and you had half your deposit back. I still owe you a good voyage.\"" % str(last.get("goods", "cargo"))
	return ""


static func _remember(c: Dictionary, kind: String, v: Dictionary, delta_trust: int) -> void:
	(c["memory"] as Array).append({"day": Game.day(), "kind": kind, "voyage": str(v["id"]), "goods": "%d × %s" % [int(v["qty"]), _name(str(v["def"]))],
		"amount": int(v.get("paid", 0))})
	while (c["memory"] as Array).size() > 20:
		(c["memory"] as Array).pop_front()
	c["trust"] = clampi(int(c.get("trust", 0)) + delta_trust, -TRUST_MAX, TRUST_MAX)


static func _name(def_id: String) -> String:
	return str(DB.item(def_id).get("name", def_id))


# ======================================================================= terms
## The captain's terms for a voyage: {unit, total, deposit, deposit_share, lead: [lo, hi], discount}. {} when the good
## cannot be shipped.
static func quote(cid: String, def_id: String, qty: int) -> Dictionary:
	var info := Trade.import_info(def_id)
	if info.is_empty():
		return {}
	var c := get_c(cid)
	var trust := int(c.get("trust", 0))
	var disc := clampf(DISCOUNT_PER_TRUST * float(trust), -0.15, 0.15)
	var unit := maxi(1, int(round(float(info["unit"]) * (1.0 - disc))))
	var total := unit * maxi(1, qty)
	var share := clampf(BASE_DEPOSIT - 0.05 * float(trust), 0.2, 0.6)
	var sp: Dictionary = ROUTE.get(str(c.get("type", "spice")), ROUTE["spice"])
	var lead: Array = info["lead"]
	return {"unit": unit, "total": total, "deposit": int(ceil(float(total) * share)), "deposit_share": share, "discount": disc,
		"lead": [int(ceil(float(lead[0]) * float(sp["speed"]))), int(ceil(float(lead[1]) * float(sp["speed"])))], "trust": trust}


## Commissions a voyage from the captain in port. Payment of the deposit: `gold` and/or `goods` (uids; a piece
## counts at Barter.CAPTAIN_SHARE of its value). "" or why not.
static func commission(def_id: String, qty: int, gold: int, goods := []) -> String:
	var c := in_port()
	if c.is_empty():
		return "No captain is in port."
	if not Trade.knows(def_id):
		return "\"Never heard of it — I can't fetch what nobody can name.\""
	if open_voyages().filter(func(v): return str(v["captain"]) == str(c["id"])).size() >= 1:
		return "\"One cargo for you at a time, smith.\""
	if open_voyages().size() >= MAX_OPEN:
		return "Three voyages are already out for you."
	var q := quote(str(c["id"]), def_id, qty)
	if q.is_empty():
		return "\"That can't be shipped to Brindlewick.\""
	var goods_val := 0
	for u in goods:
		var it := Game.find_uid(int(u))
		var why := Barter.payable_reason(it)
		if why != "":
			return why
		goods_val += int(round(float(Valuation.value(it)) * Barter.CAPTAIN_SHARE))
	if gold + goods_val < int(q["deposit"]):
		return "\"%d g down, or cargo worth as much — that's my deposit.\"" % int(q["deposit"])
	if not Game.can_afford(gold):
		return "You cannot pay %d g." % gold
	var s := _w()
	s["seq"] = int(s.get("seq", 0)) + 1
	var v := {"id": "voy_%d" % int(s["seq"]), "captain": str(c["id"]), "captain_name": str(c["name"]), "ship": str(c["ship"]),
		"def": def_id, "qty": maxi(1, qty), "total": int(q["total"]), "deposit": gold + goods_val, "balance": maxi(0, int(q["total"]) - gold - goods_val),
		"lead": Rng.ri("commerce", int(q["lead"][0]), int(q["lead"][1])), "agreed": Game.day(), "status": "agreed", "due": -1,
		"delayed": false, "goods": goods.duplicate(), "paid": gold + goods_val}
	(s["voyages"] as Array).append(v)
	var text := "%s agreed to fetch %d × %s aboard %s: %d g in all, %d paid down%s." % [str(c["name"]), int(v["qty"]), _name(def_id), str(c["ship"]),
		int(v["total"]), int(v["deposit"]), (" (%s in goods)" % ", ".join(PackedStringArray(goods.map(func(u): return Items.display_name(Game.find_uid(int(u))))))) if not goods.is_empty() else ""]
	var ev := Lore.record("voyage", text, {"actors": [str(c["id"])], "roles": {str(c["id"]): "captain"}, "place": "brindlewick", "importance": 1, "chronicle": true,
		"data": {"voyage": str(v["id"]), "total": int(v["total"]), "deposit": int(v["deposit"])}})
	v["event"] = ev
	Lore.push_cause(ev)
	if gold > 0:
		Game.add_gold(-gold, "imports", "Voyage deposit to %s: %d × %s" % [str(c["name"]), int(v["qty"]), _name(def_id)], str(c["id"]))
	for u in goods:
		Barter.pay_captain(str(c["id"]), str(c["name"]), int(u), "%d × %s" % [int(v["qty"]), _name(def_id)])
	Lore.pop_cause()
	return ""


# ======================================================================= the voyage
## The captain sails (Trade._depart): their voyages for the smith are under way.
static func on_sail(cname: String) -> void:
	var cid := id_of(cname)
	for v in open_voyages():
		if str(v["captain"]) == cid and str(v["status"]) == "agreed":
			v["status"] = "at_sea"
			v["sailed"] = Game.day()
			v["due"] = Game.day() + int(v["lead"])


## The daily round: voyages come due; unpaid cargo is given up.
static func on_day() -> void:
	if st().is_empty():
		return
	for v in open_voyages():
		match str(v["status"]):
			"at_sea", "delayed":
				if Game.day() >= int(v["due"]):
					_decide(v)
			"arrived":
				if Game.day() - int(v.get("arrived", Game.day())) > ABANDON_DAYS:
					_abandon(v)


static func _decide(v: Dictionary) -> void:
	var c := get_c(str(v["captain"]))
	var sp: Dictionary = ROUTE.get(str(c.get("type", "spice")), ROUTE["spice"])
	var r := Rng.f("commerce")
	var fo := str(force.get(str(v["id"]), force_outcome))
	if force.has(str(v["id"])):
		force.erase(str(v["id"]))
	else:
		force_outcome = ""
	match fo:
		"failed": r = -1.0
		"delayed": r = float(sp["risk"]) + 0.001 if not bool(v["delayed"]) else 0.99
		"success": r = 0.99
	var cargo := "%d × %s" % [int(v["qty"]), _name(str(v["def"]))]
	Lore.push_cause(str(v.get("event", "")))
	if r < float(sp["risk"]):
		v["status"] = "failed"
		var back := int(v["deposit"]) / 2
		if back > 0:
			Game.add_gold(back, "imports", "Half the deposit returned by %s (cargo lost)" % str(v["captain_name"]), str(v["captain"]))
		v["refund"] = back
		_remember(c, "lost", v, 0)
		Lore.record("voyage_failed", "%s lost the cargo of %s at sea; %d g of the deposit came back." % [str(v["captain_name"]), cargo, back],
			{"actors": [str(v["captain"])], "roles": {str(v["captain"]): "captain"}, "importance": 2, "chronicle": true})
	elif r < float(sp["risk"]) + DELAY_SHARE and not bool(v["delayed"]):
		v["status"] = "delayed"
		v["delayed"] = true
		v["due"] = Game.day() + Rng.ri("commerce", int(DELAY[0]), int(DELAY[1]))
		Lore.record("voyage_delayed", "%s sent word: the cargo of %s is delayed — expected on day %d." % [str(v["captain_name"]), cargo, int(v["due"])],
			{"actors": [str(v["captain"])], "roles": {str(v["captain"]): "captain"}, "importance": 1, "chronicle": true})
	else:
		v["status"] = "arrived"
		v["arrived"] = Game.day()
		Lore.record("voyage_arrived", "%s landed %s at Brindlewick for the smith%s (%d g balance due)." % [str(v["captain_name"]), cargo,
			" — late, but landed" if bool(v["delayed"]) else "", int(v["balance"])],
			{"actors": [str(v["captain"])], "roles": {str(v["captain"]): "captain"}, "importance": 1, "chronicle": true})
		Events.toast.emit("%s has landed your %s at the harbour." % [str(v["captain_name"]), cargo], "good")
	Lore.pop_cause()


## The smith collects an arrived cargo and pays the balance. "" or why not.
static func collect(vid: String) -> String:
	for v in open_voyages():
		if str(v["id"]) != vid:
			continue
		if str(v["status"]) != "arrived":
			return "It has not landed yet."
		var bal := int(v["balance"])
		if not Game.can_afford(bal):
			return "The balance is %d g — you cannot pay it yet." % bal
		if bal > 0:
			Game.add_gold(-bal, "imports", "Voyage balance to %s: %d × %s" % [str(v["captain_name"]), int(v["qty"]), _name(str(v["def"]))], str(v["captain"]))
		v["paid"] = int(v["paid"]) + bal
		var it := Items.make(str(v["def"]), {"qty": int(v["qty"]), "quality": Rng.rf("commerce", 72, 94)})
		Game.add_item(it, false)
		Trade.mark_seen(str(v["def"]))
		v["status"] = "collected"
		v["collected"] = Game.day()
		var on_time := Game.day() - int(v.get("arrived", Game.day())) <= PAY_DAYS
		var c := get_c(str(v["captain"]))
		_remember(c, "paid", v, 1 if on_time else 0)
		Lore.push_cause(str(v.get("event", "")))
		Lore.record("voyage_paid", "The smith paid %s in full for %d × %s (%d g)%s." % [str(v["captain_name"]), int(v["qty"]), _name(str(v["def"])), int(v["paid"]),
			"" if on_time else ", if not promptly"], {"actors": [str(v["captain"])], "roles": {str(v["captain"]): "captain"}, "importance": 1})
		Lore.pop_cause()
		return ""
	return "No such voyage."


static func _abandon(v: Dictionary) -> void:
	v["status"] = "abandoned"
	var c := get_c(str(v["captain"]))
	_remember(c, "unpaid", v, -1)
	Lore.push_cause(str(v.get("event", "")))
	Lore.record("voyage_unpaid", "%s gave up waiting: the %d × %s sat unpaid on the quay and was sold elsewhere; the deposit is kept." % [str(v["captain_name"]),
		int(v["qty"]), _name(str(v["def"]))], {"actors": [str(v["captain"])], "roles": {str(v["captain"]): "captain"}, "importance": 1, "chronicle": true})
	Lore.pop_cause()
