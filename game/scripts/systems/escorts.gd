## Escorts — protection for a hireling's run (R7 "Negotiation & Procurement"; ECO-032, decision 12).
## EN: Before a hireling sets out, the smith may hire an adventurer in town to go with them. The price follows the one
##     danger model (R2: Danger.trip — the place's live danger, lowered by scouting) and the length of the road; the
##     adventurer weighs the offer — coin and goods (Barter: a piece that would serve them counts in full) — against
##     that price, and refuses a road beyond them. On the road the escort's strength covers part of the danger
##     (COVER_MAX at most), so injury and death become less likely (Hire.odds). The escort is away for the run
##     (status "escorting") and shares its fate: a bad run wounds them too. One Lore event records the escort; the
##     hireling's return closes it.
## DA: Eskorte: en eventyrer følger en daglejers tur — prisen følger faren, og eskorten sænker risikoen.
class_name Escorts
extends RefCounted

## Gold per day of road per point of danger.
const PER_DAY := 9.0
## The largest share of a road's danger an escort can take on.
const COVER_MAX := 0.6


static func _days(dest: String) -> float:
	var d: Dictionary = DB.destinations.get(dest, {})
	var r: Array = d.get("days", [1, 1])
	return (float(r[0]) + float(r[1])) / 2.0


## What this adventurer asks to guard a run to `dest`: the road's danger × its length × their standing.
static func price(dest: String, a: Dictionary) -> int:
	return int(round(PER_DAY * Danger.trip(dest) * _days(dest) * (0.8 + 0.04 * float(a.get("level", 1)))))


## The escort's strength on that road.
static func strength(a: Dictionary) -> float:
	var gear := 0.0
	for s in a.get("equipment", {}):
		gear += Items.score(a["equipment"][s])
	return float(a.get("level", 1)) * 1.0 + gear / 40.0


## The share of the road's danger the escort takes on (0 … COVER_MAX).
static func cover(a: Dictionary, dest: String) -> float:
	var dg := maxf(0.5, Danger.trip(dest))
	return clampf(strength(a) / (dg * 3.0), 0.0, COVER_MAX)


## Adventurers in town who could go: free, healthy, not committed to a party.
static func candidates() -> Array:
	var out := []
	for a in Adv.all().values():
		if str(a.get("status", "")) != "in_town" or not Expeditions.party_of(str(a["id"])).is_empty() or not Living.is_active(a):
			continue
		Expeditions.ensure(a)
		if float(a.get("hp", 0)) < float(a.get("hp_max", 1)) * 0.7:
			continue
		out.append(a)
	return out


## The adventurer's answer to an offer: {ok, price, offered, reason}.
static func weigh(a: Dictionary, dest: String, gold: int, goods: Array) -> Dictionary:
	var p := price(dest, a)
	var offered := gold + Barter.goods_worth(a, goods)
	var d: Dictionary = DB.destinations.get(dest, {})
	if strength(a) < Danger.trip(dest) * 0.6:
		return {"ok": false, "price": p, "offered": offered, "reason": "\"%s? That road is beyond me — find someone stronger.\" — %s" % [str(d.get("name", dest)), str(a["name"])]}
	if offered < p:
		return {"ok": false, "price": p, "offered": offered, "reason": "\"%s is %s — %d g, or goods worth as much to me.\" — %s" % [str(d.get("name", dest)),
			road_word(dest), p, str(a["name"])]}
	return {"ok": true, "price": p, "offered": offered, "reason": "\"I'll see them there and back.\" — %s" % str(a["name"])}


## How the road reads, from the same danger the price uses.
static func road_word(dest: String) -> String:
	var dg := Danger.trip(dest)
	if dg >= 5.0:
		return "a deadly road"
	if dg >= 3.0:
		return "a dangerous road"
	if dg >= 1.5:
		return "a risky road"
	return "a quiet road"


## Hires an escort for a hireling about to set out (or just sent). Pays them (coin to their purse, goods handed over
## and, where they serve, equipped). Returns "" or why not.
static func hire(hid: String, adv_id: String, dest: String, gold: int, goods := []) -> String:
	var h := Hire.get_h(hid)
	var a := Adv.get_a(adv_id)
	if h.is_empty() or a.is_empty():
		return "No such hireling or adventurer."
	if not candidates().has(a):
		return "%s is not free to go." % str(a.get("name", adv_id))
	if not Game.can_afford(gold):
		return "You cannot pay %d g." % gold
	for u in goods:
		var why := Barter.payable_reason(Game.find_uid(int(u)))
		if why != "":
			return why
	var w := weigh(a, dest, gold, goods)
	if not bool(w["ok"]):
		return str(w["reason"])
	var dname := str(DB.destinations.get(dest, {}).get("name", dest))
	var ev := Lore.record("escort", "%s agreed to escort %s to %s for %s." % [str(a["name"]), str(h["name"]), dname, _pay_text(gold, goods)],
		{"actors": [adv_id], "roles": {adv_id: "escort"}, "place": dest, "importance": 1,
		"data": {"hireling": hid, "gold": gold, "goods": goods.duplicate(), "price": int(w["price"]), "cover": cover(a, dest)}})
	Lore.push_cause(ev)
	if gold > 0:
		Game.add_gold(-gold, "escort", "%s's escort fee (%s to %s)" % [str(a["name"]), str(h["name"]), dname], adv_id)
		a["gold"] = int(a.get("gold", 0)) + gold
	for u in goods:
		Barter.pay_adventurer(a, int(u), "escorting %s to %s" % [str(h["name"]), dname])
	Lore.pop_cause()
	a["status"] = "escorting"
	a["activity"] = "escorting %s to %s" % [str(h["name"]), dname]
	a["escort"] = {"hireling": hid, "dest": dest, "day": Game.day(), "event": ev}
	h["escort"] = {"adv": adv_id, "name": str(a["name"]), "cover": cover(a, dest), "event": ev}
	Events.adventurers_changed.emit()
	return ""


static func _pay_text(gold: int, goods: Array) -> String:
	var bits := PackedStringArray()
	if gold > 0:
		bits.append("%d g" % gold)
	for u in goods:
		bits.append(Items.display_name(Game.find_uid(int(u))))
	return " and ".join(bits) if not bits.is_empty() else "nothing"


## The hireling's run is over (Hire._resolve): the escort comes home; a bad run wounds them too.
static func on_return(h: Dictionary, injured: bool, died: bool) -> void:
	var e: Dictionary = h.get("escort", {})
	if e.is_empty():
		return
	h.erase("escort")
	var a := Adv.get_a(str(e.get("adv", "")))
	if a.is_empty():
		return
	a.erase("escort")
	a["status"] = "in_town"
	a["activity"] = ""
	a["depart_day"] = Game.day() + 1
	if injured or died:
		a["hp"] = maxf(1.0, float(a.get("hp", 1)) - float(a.get("hp_max", 10)) * 0.3)
	Lore.push_cause(str(e.get("event", "")))
	Lore.record("escort_done", "%s came home from escorting %s%s." % [str(a["name"]), str(h["name"]),
		" — %s did not survive the road" % str(h["name"]) if died else (" — both came back hurt" if injured else " — the road held no surprise they could not meet")],
		{"actors": [str(a["id"])], "roles": {str(a["id"]): "escort"}, "importance": 2 if died else 1})
	Lore.pop_cause()
