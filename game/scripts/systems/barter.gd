## Barter — goods as payment (R7 "Negotiation & Procurement"; ECO-030, ECO-031).
## EN: People can be paid with things as well as gold: a sponsored party, an escort or a ship's captain accepts
##     crafted equipment from the smith's stores, alone or with coin. A piece is valued by the one valuation (R2:
##     Valuation.value) and by what it is worth to the person taking it:
##       • an adventurer for whom it would serve — they can wield it and it is better than what they carry in that slot —
##         counts it at its full value, and really takes it up: it is equipped (their old piece goes into their pack);
##       • anyone else counts it at RESALE_SHARE of its value (they will have to sell it) and keeps it in their pack;
##       • a captain counts it at CAPTAIN_SHARE (it is cargo to sell in a far port) and the piece sails away.
##     The handover is a real transfer (Provenance "payment"): the same instance, its maker and history, one Lore event
##     naming what it paid for. A piece in a family's custody, set aside for an order, in the Reliquary or marked as
##     protected cannot be paid away.
## DA: Betaling i varer: udstyr værdisat efter den fælles værdiansættelse; et givet sværd bliver virkelig båret.
class_name Barter
extends RefCounted

const RESALE_SHARE := 0.5
const CAPTAIN_SHARE := 0.8


## Why this piece cannot be paid away ("" = it can).
static func payable_reason(it: Dictionary) -> String:
	if it.is_empty():
		return "That piece is not in your stores."
	if not Items.is_equipment(it):
		return "Only crafted equipment is accepted as payment."
	if Reliquary.custody_reason(it) != "":
		return Reliquary.custody_reason(it)
	if str(it.get("for_order", "")) != "":
		return "It is set aside for an order."
	if GearDepth.disabled(it):
		return "An unusable piece is no payment."
	return ""


## Would this piece serve the adventurer: can they wield it, and is it better than what they carry in that slot?
static func serves(a: Dictionary, it: Dictionary) -> bool:
	if a.is_empty() or it.is_empty():
		return false
	var cur: Dictionary = a.get("equipment", {}).get(Items.slot(it), {})
	return Adv.affinity(a, it) > 0.0 and Items.score(it) > Items.score(cur)


## What the piece is worth to this adventurer as payment.
static func worth_to(a: Dictionary, it: Dictionary) -> int:
	var v := Valuation.value(it)
	return v if serves(a, it) else int(round(float(v) * RESALE_SHARE))


## What a set of pieces (uids in the stores) is worth to the adventurer.
static func goods_worth(a: Dictionary, uids: Array) -> int:
	var t := 0
	for u in uids:
		t += worth_to(a, Game.find_uid(int(u)))
	return t


## The member of a party to whom a piece is worth most (the one who would take it up).
static func best_taker(ids: Array, it: Dictionary) -> Dictionary:
	var best := {}
	var bw := -1
	for id in ids:
		var a := Adv.get_a(str(id))
		var w := worth_to(a, it)
		if w > bw:
			bw = w
			best = a
	return best


## Pays an adventurer with a piece from the stores: it changes hands (Provenance "payment") and, when it serves them,
## is equipped (their old piece goes into their pack). `for_what` names the deal. "" or why not.
static func pay_adventurer(a: Dictionary, uid: int, for_what: String) -> String:
	var it := Game.find_uid(uid)
	var why := payable_reason(it)
	if why != "":
		return why
	if a.is_empty() or str(a.get("status", "")) == "dead":
		return "There is no one to pay."
	var equip := serves(a, it)
	Game.take_uid(uid)
	it.erase("for_sale")
	var slot := Items.slot(it)
	if equip:
		var old: Dictionary = a["equipment"].get(slot, {})
		if not old.is_empty():
			(a["loot"] as Array).append(old)
		a["equipment"][slot] = it
	else:
		(a["loot"] as Array).append(it)
	it["owner"] = str(a["id"])
	Provenance.transfer(it, str(a["id"]), "payment", "brindlewick", "%s took %s as payment for %s%s." % [str(a["name"]), Items.display_name(it), for_what,
		" and took it up at once" if equip else ""])
	Events.adventurers_changed.emit()
	Events.inventory_changed.emit()
	return ""


## Pays a captain with a piece: it becomes cargo and sails away with them (the holdings archive keeps it whole).
static func pay_captain(cid: String, cname: String, uid: int, for_what: String) -> String:
	var it := Game.find_uid(uid)
	var why := payable_reason(it)
	if why != "":
		return why
	Game.take_uid(uid)
	it.erase("for_sale")
	Provenance.transfer(it, cid, "payment", "brindlewick", "%s took %s aboard as payment for %s." % [cname, Items.display_name(it), for_what])
	ItemRegistry.archive(it, cid, cname, "payment", {"for": for_what})
	Events.inventory_changed.emit()
	return ""
