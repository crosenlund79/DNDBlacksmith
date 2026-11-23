## Reliquary — a workshop with a conscience (R6 "Legacy: the Reliquary & Heirs"; canonical §6.5–§6.6, §13 "A relic and
## its heir"; EQ-041 … EQ-046, EQ-057; decision 11).
## EN: • THE CASE. A magically secured display case, bought and placed in the smithy like any station ("reliquary").
##       It holds only pieces that can no longer serve (broken or unusable) AND have earned genuine significance — Epic
##       distinction, a name given by a patron or earned, a Hall of Fame plaque, or a recorded deed of note in Lore.
##       Legendary or Unique rarity alone is not enough. Exhibition never manufactures fame: placing a piece records it
##       and changes no reputation. A restored piece leaves the case.
##     • HEIRS (heirs_of). Only from recorded data: the piece's ownership chain (Provenance.owners) and the authored
##       family links in characters.json (Social.relatives). The rightful line is the latest character who held the
##       piece without selling or giving it away. Alive, that holder is the claimant; fallen, their living authored
##       relatives are. A bearer without recorded family leaves no heir — no ancestor or descendant is ever invented.
##     • LETTERS. An heir who learns that the relic is in the case writes to ask for its restoration (once). The smith
##       can write to an heir: compensation and, optionally, an offer to buy. The heir answers the next day, by what is
##       on record (their regard for the smith, what is offered, whether they can wield it):
##         decline  — no part in it; the smith may still restore what he holds, without the line;
##         custody  — consent, but no transfer: the piece is the family's, kept in the forge's care (it cannot be sold);
##         return   — consent on the condition that the restored piece goes home to the family (its own living bearer,
##                    an heir who can wield it, or a family warm to the smith);
##         sold     — consent and a sale: the piece becomes the smith's (only when a purchase was offered and fair).
##       Every term is recorded in the item's own history (Lore); a compensation is paid when consent is given.
##       While the steward runs the forge, heir letters arrive as sealed correspondence; the steward never writes.
##     • ANCESTRAL BINDING (EQ-046). A Unique tagged "bloodline" (Grimhold, the Last Hammer) carries an ancestral
##       nature that sleeps while the piece is unusable. Restored with the line's consent (a symbolic rite: the heir's
##       hand on the piece — no gore), it wakes; without it the restoration is harder and its nature stays asleep
##       (its strength reduced) until an heir of the line consents. Not every Unique is bloodline-bound.
##     State: Game.state["reliquary"] = {cases: [items], claims: {uid: claim}, letters: [letter]} — created on the
##       first write; ItemRegistry knows the cases as holder "reliquary". Reads are pure.
## DA: Relikvieskabet: kun ødelagte, historisk betydningsfulde genstande; arvinger kun fra registreret ejerskab og familie.
class_name Reliquary
extends RefCounted

const STATION := "reliquary"
const CASES := 3
## The heir's letter about a relic in the case arrives this many days after it was placed.
const LETTER_AFTER := 2
## Answers of the heir.
const ANSWERS := ["decline", "custody", "return", "sold"]
## A sale ends the line's claim; these do not (a fallen bearer's piece carried home, found, looted or inherited).
const CLAIM_ENDS := ["sold", "bought", "given", "offered", "pawned", "commissioned"]
## The ancestral nature asleep: the piece's strength at this share.
const ASLEEP_FACTOR := 0.75


# ======================================================================= state
static func st() -> Dictionary:
	var r: Variant = Game.state.get("reliquary", {})
	return r if r is Dictionary else {}


static func _w() -> Dictionary:
	if not Game.state.get("reliquary") is Dictionary:
		Game.state["reliquary"] = {"cases": [], "claims": {}, "letters": [], "next": 1}
	var s: Dictionary = Game.state["reliquary"]
	for k in ["cases", "letters"]:
		if not s.get(k) is Array:
			s[k] = []
	if not s.get("claims") is Dictionary:
		s["claims"] = {}
	return s


static func installed() -> bool:
	return Property.is_installed(STATION)


static func cases() -> Array:
	return st().get("cases", [])


static func held(uid: int) -> Dictionary:
	for it in cases():
		if int(it.get("uid", -1)) == uid:
			return it
	return {}


static func claim(uid: int) -> Dictionary:
	return st().get("claims", {}).get(str(uid), {})


static func letters(include_done := false) -> Array:
	return (st().get("letters", []) as Array).filter(func(l): return include_done or not bool(l.get("done", false)))


# ======================================================================= significance (§6.5)
## Why the piece has earned its place in history ("" = it has not). Rarity alone never counts.
static func significance(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	if it.has("epic"):
		return "Epic: %s" % str(it["epic"].get("deed", "a deed of renown"))
	if it.has("given_name"):
		return "named «%s» by %s" % [str(it["given_name"].get("name", "")), str(it["given_name"].get("by", ""))]
	if ItemStory.is_named(it):
		return "it bears the name %s" % ItemStory.earned_name(it)
	var uid := int(it.get("uid", -1))
	for e in Game.state.get("hall_of_fame", []):
		if int(e.get("refs", {}).get("uid", -2)) == uid:
			return "it hangs in the Hall of Fame"
	for e in Lore.of_item(uid):
		if int(e.get("importance", 0)) >= 2 and not str(e.get("kind", "")) in ["lost", "destroyed", "disabled", "enshrined", "restored"]:
			return str(e.get("text", "a deed of note"))
	return ""


## The piece can no longer serve: broken or unusable.
static func out_of_service(it: Dictionary) -> bool:
	return GearDepth.disabled(it) or bool(it.get("broken", false))


## Why this piece cannot go into the case ("" = it can).
static func enshrine_reason(it: Dictionary) -> String:
	if it.is_empty() or not Items.is_equipment(it):
		return "Only equipment can rest in the Reliquary."
	if not installed():
		return "The workshop has no Reliquary yet — buy one and set it up."
	if not out_of_service(it):
		return "\"A sword was forged to be wielded, not admired behind glass.\" It still serves — it belongs in the world."
	if significance(it) == "":
		return "It has earned no place in history — the Reliquary honours service that is remembered, not rarity."
	if cases().size() >= CASES:
		return "All %d places in the case are taken." % CASES
	return ""


## Places a piece from the stores in the case. "" or why not.
static func enshrine(uid: int) -> String:
	var it := Game.find_uid(uid)
	if it.is_empty():
		return "That piece is not in your stores."
	var why := enshrine_reason(it)
	if why != "":
		return why
	Game.take_uid(uid)
	it.erase("for_sale")
	(_w()["cases"] as Array).append(it)
	it["enshrined"] = {"day": Game.day()}
	Lore.record("enshrined", "%s was laid in the Reliquary of the Ironhand forge — %s." % [Items.display_name(it), significance(it)],
		{"items": [it], "place": "brindlewick", "importance": 1, "chronicle": true})
	Events.inventory_changed.emit()
	return ""


## Takes a piece out of the case into the stores (for restoration, or simply). "" or why not.
static func take_out(uid: int) -> String:
	var s := _w()
	for i in (s["cases"] as Array).size():
		var it: Dictionary = s["cases"][i]
		if int(it.get("uid", -1)) == uid:
			(s["cases"] as Array).remove_at(i)
			it.erase("enshrined")
			Game.add_item(it, false)
			Events.inventory_changed.emit()
			return ""
	return "That piece is not in the Reliquary."


## The world prompt at the case.
static func prompt() -> Dictionary:
	var p := {"title": "The Reliquary", "actions": ["Look into the Reliquary"], "status": "", "off": [], "note": "", "open": true, "text": ""}
	p["status"] = "%d of %d places taken" % [cases().size(), CASES]
	var waiting := letters().filter(func(l): return str(l["kind"]) == "request")
	if not waiting.is_empty():
		p["note"] = "A letter from %s waits" % str(waiting[0]["heir_name"])
	return p


# ======================================================================= heirs (EQ-043; decision 11)
static func _alive(id: String) -> bool:
	if id == "" or id == Provenance.SMITH_ID or id.begins_with("inst_") or id.begins_with("patron_"):
		return false
	var a := Adv.get_a(id)
	if not a.is_empty():
		return str(a.get("status", "")) != "dead"
	return not DB.character(id).is_empty()


static func _dead(id: String) -> bool:
	var a := Adv.get_a(id)
	return not a.is_empty() and str(a.get("status", "")) == "dead"


static func _is_character(id: String) -> bool:
	return not Adv.get_a(id).is_empty() or not DB.character(id).is_empty()


## The living heirs of a piece, from recorded data only: [{id, name, relation, bearer, bearer_name, evidence}].
## The rightful line: the latest character who held the piece without selling or giving it away.
static func heirs_of(it: Dictionary) -> Array:
	var ow: Array = Provenance.owners(it)
	for i in range(ow.size() - 1, -1, -1):
		var o: Dictionary = ow[i]
		var oid := str(o.get("id", ""))
		if not _is_character(oid):
			continue
		# how the piece left them: the next record's "how" (a sale or a gift ends the line's claim)
		var left_how := str(ow[i + 1].get("how", "")) if i + 1 < ow.size() else ""
		if left_how in CLAIM_ENDS:
			return []
		var bearer_name := str(o.get("name", Talk.npc_name(oid)))
		var span := "held it from day %d%s" % [int(o.get("from", 0)), (" to day %d" % int(o["to"])) if int(o.get("to", -1)) >= 0 else ""]
		if _alive(oid):
			if str(o.get("how", "")) == "acknowledged":   # the agreed terms named them its owner
				return [{"id": oid, "name": Talk.npc_name(oid), "relation": "its acknowledged owner", "bearer": oid, "bearer_name": bearer_name,
					"evidence": "%s was acknowledged as its rightful owner on day %d (the agreed terms)." % [bearer_name, int(o.get("from", 0))]}]
			return [{"id": oid, "name": Talk.npc_name(oid), "relation": "its own bearer", "bearer": oid, "bearer_name": bearer_name,
				"evidence": "%s %s (the ownership record)." % [bearer_name, span]}]
		if not _dead(oid):
			return []
		var out := []
		for rid in Social.relatives(oid):
			if not _alive(str(rid)):
				continue
			out.append({"id": str(rid), "name": Talk.npc_name(str(rid)), "relation": Social.relation_word(oid, str(rid)), "bearer": oid,
				"bearer_name": bearer_name, "evidence": "%s %s and fell on day %d; %s is %s's %s (the family record)." % [bearer_name, span,
				int(Adv.get_a(oid).get("died_day", 0)), Talk.npc_name(str(rid)), bearer_name, Social.relation_word(oid, str(rid))]})
		return out
	return []


static func is_heir(it: Dictionary, id: String) -> bool:
	return heirs_of(it).any(func(h): return str(h["id"]) == id)


# ======================================================================= letters (EQ-044)
static func _letter(kind: String, uid: int, heir: Dictionary, text: String, data := {}) -> Dictionary:
	var s := _w()
	var l := {"id": "rl_%d" % int(s.get("next", 1)), "day": Game.day(), "kind": kind, "uid": uid, "heir": str(heir.get("id", "")),
		"heir_name": str(heir.get("name", "")), "text": text, "data": data.duplicate(true), "done": false}
	s["next"] = int(s.get("next", 1)) + 1
	(s["letters"] as Array).append(l)
	if Steward.is_active():
		Steward.defer("heir", text, {"type": "heir", "id": str(heir.get("id", "")), "from": str(heir.get("name", "")),
			"key": "heir:%s" % str(l["id"])}, true, {"route": "reliquary", "args": {"uid": uid}})
	return l


## The daily round: heirs learn of relics in the case and write; answers to the smith's letters arrive.
static func on_day(_day: int) -> void:
	var s := st()
	if s.is_empty():
		return
	for it in s.get("cases", []):
		var uid := int(it.get("uid", -1))
		if Game.day() - int(it.get("enshrined", {}).get("day", Game.day())) < LETTER_AFTER:
			continue
		var c := claim(uid)
		if bool(c.get("asked", false)) or c.has("answer"):
			continue
		var hs := heirs_of(it)
		if hs.is_empty():
			continue
		var h: Dictionary = hs[0]
		var cw := _claim_w(uid)
		cw["asked"] = true
		cw["asked_by"] = str(h["id"])
		var whose := "It was mine" if str(h["relation"]) == "its own bearer" else "It was my %s's — %s bore it until he fell on day %d" % [
			Social.relation_word(str(h["id"]), str(h["bearer"])), str(h["bearer_name"]), int(Adv.get_a(str(h["bearer"])).get("died_day", 0))]
		var text := "A letter from %s: \"I have heard that %s rests in your Reliquary. %s. Will you restore it?\"" % [
			str(h["name"]), Items.display_name(it), whose]
		var ev := Lore.record("heir_claim", "%s, %s, asked for %s to be restored." % [str(h["name"]), _rel_text(h), Items.display_name(it)],
			{"items": [it], "actors": [str(h["id"])], "roles": {str(h["id"]): "heir"}, "importance": 2, "chronicle": true,
			"data": {"evidence": str(h["evidence"])}})
		_letter("request", uid, h, text, {"event": ev})
	for l in s.get("letters", []):
		if str(l.get("kind", "")) == "sent" and not bool(l.get("done", false)) and Game.day() > int(l.get("day", 0)):
			_answer(l)


static func _rel_text(h: Dictionary) -> String:
	return "its own bearer" if str(h["relation"]) == "its own bearer" else "%s of %s" % [str(h["relation"]), str(h["bearer_name"])]


static func _claim_w(uid: int) -> Dictionary:
	var cl: Dictionary = _w()["claims"]
	if not cl.has(str(uid)):
		cl[str(uid)] = {}
	return cl[str(uid)]


## The piece wherever the smith holds it: in the case or in the stores.
static func _find(uid: int) -> Dictionary:
	var it := held(uid)
	return it if not it.is_empty() else Game.find_uid(uid)


## The smith writes to an heir: compensation (gold, paid when consent is given) and an optional purchase offer.
## "" or why not. The answer comes the next day.
static func write_to(uid: int, heir_id: String, compensation: int, purchase := 0) -> String:
	if Steward.smith_away():
		return "The smith is away — letters to an heir are his to write."
	var it := _find(uid)
	if it.is_empty():
		return "The piece is not in your keeping."
	var hs := heirs_of(it).filter(func(h): return str(h["id"]) == heir_id)
	if hs.is_empty():
		return "No record makes %s an heir of this piece." % Talk.npc_name(heir_id)
	var c := claim(uid)
	if c.has("answer") and str(c["answer"]) != "decline":
		return "Terms are already agreed (%s)." % str(c["answer"])
	if letters().any(func(l): return int(l["uid"]) == uid and str(l["kind"]) == "sent"):
		return "A letter is already on its way."
	if compensation < 0 or purchase < 0:
		return "An offer cannot be negative."
	if not Game.can_afford(compensation + purchase):
		return "You cannot pay what you would offer (%d g)." % (compensation + purchase)
	var h: Dictionary = hs[0]
	var text := "You wrote to %s about %s: the restoration, %s%s." % [str(h["name"]), Items.display_name(it),
		("%d g in compensation" % compensation) if compensation > 0 else "no compensation", (", and an offer of %d g to buy it" % purchase) if purchase > 0 else ""]
	var ev := Lore.record("heir_letter", text, {"items": [it], "actors": [heir_id], "roles": {heir_id: "heir"}, "importance": 1,
		"data": {"compensation": compensation, "purchase": purchase}})
	var l := _letter("sent", uid, h, text, {"compensation": compensation, "purchase": purchase, "event": ev})
	for l2 in letters():
		if int(l2["uid"]) == uid and str(l2["kind"]) == "request":
			l2["done"] = true
	return "" if not l.is_empty() else "The letter could not be sent."


## The heir's answer, decided by what is on record — their regard for the smith, the offer, whether they can wield it.
static func decide(it: Dictionary, h: Dictionary, compensation: int, purchase: int) -> String:
	var hid := str(h["id"])
	var aff := Social.aff(hid) if not DB.character(hid).is_empty() else 0.0
	var v := maxi(1, Valuation.value(it))
	if aff <= -30.0:
		return "decline"
	if purchase > 0 and float(purchase) >= float(v) * (1.5 if str(h["relation"]) == "its own bearer" else 1.0) and aff >= 0.0:
		return "sold"
	if str(h["relation"]) == "its own bearer":
		return "return"
	if float(compensation) < float(v) * 0.1 and aff < 20.0:
		return "decline"
	var a := Adv.get_a(hid)
	if not a.is_empty() and str(a.get("status", "")) != "dead" and Adv.affinity(a, it) > 0.0:
		return "return"   # an heir who can wield it wants it home
	if aff >= 30.0:
		return "return"   # a close family who trusts the smith still wants it home, restored
	return "custody"


static func _answer(l: Dictionary) -> void:
	l["done"] = true
	var uid := int(l["uid"])
	var it := _find(uid)
	if it.is_empty():
		return
	var hs := heirs_of(it).filter(func(h): return str(h["id"]) == str(l["heir"]))
	if hs.is_empty():
		return
	var h: Dictionary = hs[0]
	var comp := int(l["data"].get("compensation", 0))
	var buy := int(l["data"].get("purchase", 0))
	var ans := decide(it, h, comp, buy)
	agree(uid, h, ans, comp, buy, str(l["data"].get("event", "")))


## Records and enforces the heir's answer (also used directly by tests). Returns the Lore event id.
static func agree(uid: int, h: Dictionary, answer: String, comp: int, buy: int, because := "") -> String:
	var it := _find(uid)
	if it.is_empty() or not answer in ANSWERS:
		return ""
	var hid := str(h["id"])
	var c := _claim_w(uid)
	c["answer"] = answer
	c["heir"] = hid
	c["heir_name"] = str(h["name"])
	c["relation"] = str(h["relation"])
	c["day"] = Game.day()
	c["compensation"] = 0
	var name := Items.display_name(it)
	var text := ""
	Lore.push_cause(because)
	if answer != "decline" and comp > 0 and Game.can_afford(comp):
		Game.add_gold(-comp, "heir", "Compensation to %s for %s" % [str(h["name"]), name], hid)
		_pay(hid, comp)
		c["compensation"] = comp
	match answer:
		"decline":
			text = "%s declined to take part in the restoration of %s." % [str(h["name"]), name]
		"custody":
			Provenance.transfer(it, hid, "acknowledged", "brindlewick", "%s is acknowledged as the rightful owner of %s; it stays in the Ironhand forge's keeping." % [str(h["name"]), name])
			it["custody"] = {"for": hid, "name": str(h["name"]), "since": Game.day(), "return": false}
			text = "%s consented to the restoration of %s but will not part with it: it remains the family's, kept at the forge." % [str(h["name"]), name]
		"return":
			Provenance.transfer(it, hid, "acknowledged", "brindlewick", "%s is acknowledged as the rightful owner of %s; it is to go home once restored." % [str(h["name"]), name])
			it["custody"] = {"for": hid, "name": str(h["name"]), "since": Game.day(), "return": true}
			text = "%s consented to the restoration of %s on one condition: restored, it goes home to them." % [str(h["name"]), name]
		"sold":
			if Game.can_afford(buy):
				Game.add_gold(-buy, "heir", "Bought %s from %s" % [name, str(h["name"])], hid)
				_pay(hid, buy)
			Provenance.transfer(it, hid, "acknowledged", "brindlewick", "%s is acknowledged as the rightful owner of %s." % [str(h["name"]), name])
			Provenance.transfer(it, Provenance.SMITH_ID, "bought", "brindlewick", "%s sold %s to the Ironhand forge for %d g, and consented to its restoration." % [str(h["name"]), name, buy])
			it.erase("custody")
			c["purchase"] = buy
			text = "%s sold %s to the smith (%d g) and consented to its restoration." % [str(h["name"]), name, buy]
	var ev := Lore.record("heir_terms", text, {"items": [it], "actors": [hid], "roles": {hid: "heir"}, "importance": 2, "chronicle": true,
		"data": {"answer": answer, "compensation": int(c["compensation"]), "purchase": buy, "relation": str(h["relation"])}})
	Lore.pop_cause()
	c["event"] = ev
	var msg := "A letter from %s: %s" % [str(h["name"]), text]
	if Steward.is_active():
		Steward.defer("heir", msg, {"type": "heir", "id": hid, "from": str(h["name"]), "key": "heir_terms:%d:%s" % [uid, ev]}, true,
			{"route": "reliquary", "args": {"uid": uid}})
	else:
		Events.toast.emit(msg, "info")
	return ev


static func _pay(hid: String, amount: int) -> void:
	var a := Adv.get_a(hid)
	if not a.is_empty():
		a["gold"] = int(a.get("gold", 0)) + amount


## The line consented (custody, return or a sale): the ancestral rite can be performed.
static func consented(uid: int) -> bool:
	return str(claim(uid).get("answer", "")) in ["custody", "return", "sold"]


# ======================================================================= ancestral binding (EQ-046)
static func bloodline(it: Dictionary) -> bool:
	return (Items.def(it).get("tags", []) as Array).has("bloodline") and Uniques.is_authentic(it)


## The ancestral nature: "awake" (or "" for a piece without one) / "asleep".
static func ancestral_state(it: Dictionary) -> String:
	if not bloodline(it):
		return ""
	if GearDepth.disabled(it):
		return "asleep"
	return str(it.get("ancestral", {}).get("state", "awake"))


## Items.base_stat: the strength a sleeping ancestral nature leaves.
static func strength_factor(it: Dictionary) -> float:
	return ASLEEP_FACTOR if ancestral_state(it) == "asleep" else 1.0


# ======================================================================= restoration's consequences (EQ-045)
## Called by Refinement after a restoration that made the piece usable again: records the terms and enforces them.
static func on_restored(it: Dictionary, ev: String, full: bool) -> void:
	var uid := int(it.get("uid", -1))
	var c := claim(uid)
	if bloodline(it):
		if full and consented(uid):
			it["ancestral"] = {"state": "awake", "day": Game.day(), "rite": str(c.get("heir", ""))}
		else:
			it["ancestral"] = {"state": "asleep", "day": Game.day(), "why": "restored without the line" if not consented(uid) else "the restoration fell short"}
	var cu: Dictionary = it.get("custody", {})
	if bool(cu.get("return", false)):
		_send_home(it, str(cu["for"]), str(cu.get("name", "")), ev)


## Enforced terms: the restored piece goes home to the heir (an adventurer receives it among their possessions and may
## take it up; a villager keeps it at home — the holdings archive). Its history records the homecoming.
static func _send_home(it: Dictionary, hid: String, hname: String, because: String) -> void:
	Game.take_uid(int(it.get("uid", -1)))   # out of the stores (it may already be elsewhere: nothing to take then)
	it.erase("custody")
	it.erase("for_sale")
	Lore.push_cause(because)
	var a := Adv.get_a(hid)
	if not a.is_empty() and str(a.get("status", "")) != "dead":
		# among their possessions; they take it up when it serves them better than what they carry (as an heir would)
		var slot := Items.slot(it)
		var cur: Dictionary = a.get("equipment", {}).get(slot, {})
		if not a.has("loot"):
			a["loot"] = []
		if Items.score(it) > Items.score(cur) and Adv.affinity(a, it) > 0.0:
			if not cur.is_empty():
				(a["loot"] as Array).append(cur)
			a["equipment"][slot] = it
		else:
			(a["loot"] as Array).append(it)
	else:
		ItemRegistry.archive(it, hid, hname, "returned to the family", {"terms": "return"})
	# the family already owns it (the terms acknowledged them): the homecoming is a move, recorded as its own event
	if Provenance.owner_id(it) != hid:
		Provenance.transfer(it, hid, "returned", "brindlewick")
	Lore.record("returned", "%s went home to %s, restored, as was agreed." % [Items.display_name(it), hname],
		{"items": [it], "actors": [hid], "roles": {hid: "heir"}, "place": "brindlewick", "importance": 2, "chronicle": true})
	Lore.pop_cause()
	Events.inventory_changed.emit()


## A piece in the family's custody cannot be sold, pawned or displayed for sale ("" = free).
static func custody_reason(it: Dictionary) -> String:
	if it.has("custody"):
		return "It belongs to %s — kept in your care, not yours to sell." % str(it["custody"].get("name", "its family"))
	return ""
