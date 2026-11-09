## Consult — adventurers ask the smith for equipment advice (The Living Realm, milestone 3b).
## EN: Now and then — after a defeat or a wound, with worn or broken gear, before a trip whose threats their kit
##     handles badly, or when their goal is better gear — an adventurer in town comes to the counter as a customer
##     with want "advice" (rate-limited: one approach a day in the village, never the same adventurer twice within
##     COOLDOWN days). The smith may also raise it in conversation. The consultation shows their gear and the facts
##     that matter (destination threats and what they are weak to or resist, durability, strength against the
##     danger) and a short list of concrete recommendations built from that data and from what the forge can offer:
##     a repair, a piece on display, a coating from the stores, a commission or an upgrade to a better metal, a
##     safer destination, a few days' rest, or an honest "buy a plainer one at the Salt Anvil". The smith puts
##     forward one or two. Each is a persuasion check combining the smith's relevant skill, the relationship,
##     the workshop's reputation, CREDIBILITY (the track record of past advice), the adventurer's purse, temper
##     and goals; the odds are shown in words with the main reasons and the roll is seeded (same day, same advice,
##     same answer). Accepted advice runs through the existing flows (Shop.sell_to, the repair customer, Shop orders,
##     next_dest/departure, Commerce). Every piece of advice is a record; when the adventurer's next expedition is
##     over the record is judged, credibility and the relationship move, and notable cases become ONE Lore event.
## DA: Eventyrere beder smeden om råd om udstyr; anbefalinger ud fra rigtige data, overtalelse med troværdighed,
##     og fulgte råd ændrer deres virkelige valg. Udfaldet bedømmes efter næste ekspedition.
class_name Consult
extends RefCounted

const COOLDOWN := 4            # days before the same adventurer comes asking again
const TALK_COOLDOWN := 2       # days between consultations raised by the smith in conversation
const HOURS := [10, 17]        # when they come to the counter (opening hours, not the first hour)
const APPROACH_CHANCE := 0.25  # per hour, when someone has a reason and a seat is free
const APPROACH_GAP := 3        # days between approaches in the whole village (never more than one a day)
const MAX_PICKS := 2           # recommendations the smith may put forward in one consultation
const RECORD_DAYS := 21        # advice not tested by an expedition within this long is forgotten
## Danger against their strength (Expeditions.rating is the strongest group there, boss included, against the
## strength of a party like theirs): parties routinely take on ratios near 2; beyond 2.6 they walk into a grave.
const BEYOND := 2.6
const STRETCH := 1.9
const SAFE := 2.0
const PROPS := ["fire", "frost", "magic"]
const COATINGS := {"fire": ["coating_wyrmfire", "coating_flame"], "frost": ["coating_frost"], "magic": ["infusion_aether"]}
const KIND_SKILL := {"repair": "smithing", "buy": "smithing", "coat": "alchemy", "commission": "smithing", "upgrade": "smithing",
	"dest": "travelling", "rest": "travelling", "elsewhere": "smithing", "keep": "smithing"}
const KIND_WORD := {"repair": "Repair", "buy": "Buy from your display", "coat": "Treatment", "commission": "Commission", "upgrade": "Upgrade",
	"dest": "Change of plan", "rest": "Rest first", "elsewhere": "Elsewhere", "keep": "Keep your kit"}
const REASON_WORD := {"defeat": "after a hard trip", "broken": "broken gear", "worn": "worn gear", "mismatch": "before a dangerous trip", "goal": "wants better gear"}


# ======================================================================= state
static func st() -> Dictionary:
	if not Game.state.has("consult"):
		Game.state["consult"] = {"cred": {}, "word": 0.0, "records": [], "last": {}, "approach_day": -99, "next": 1, "sessions": {}, "good": 0, "bad": 0}
	var s: Dictionary = Game.state["consult"]
	for k in ["sessions", "last", "cred"]:
		if not s.has(k):
			s[k] = {}
	return s


static func records() -> Array:
	return st()["records"]


static func records_of(npc: String) -> Array:
	return records().filter(func(r): return str(r["npc"]) == npc)


## The smith's credibility with this adventurer (-100…100): their own experience of his advice weighs most,
## what the village says about it (the word) a little.
static func credibility(npc: String) -> float:
	var s := st()
	return clampf(float(s["cred"].get(npc, 0.0)) + float(s.get("word", 0.0)) * 0.6, -100.0, 100.0)


static func credibility_word(npc: String) -> String:
	var c := credibility(npc)
	if c >= 30.0:
		return "they trust your counsel"
	if c >= 10.0:
		return "your counsel has served them before"
	if c <= -25.0:
		return "your counsel has cost them dear"
	if c <= -8.0:
		return "they doubt your counsel"
	return "your counsel is untested with them"


static func _cred_add(npc: String, d: float, word_d: float) -> void:
	var s := st()
	s["cred"][npc] = clampf(float(s["cred"].get(npc, 0.0)) + d, -100.0, 100.0)
	s["word"] = clampf(float(s.get("word", 0.0)) + word_d, -50.0, 50.0)


# ======================================================================= facts
## Where they mean to go next: the party they are in, else their own plan ("" = undecided).
static func planned_dest(a: Dictionary) -> String:
	var p := Expeditions.party_of(str(a.get("id", "")))
	if not p.is_empty():
		return str(p["dest"])
	return str(a.get("next_dest", a.get("planned_dest", "")))


static func dest_name(rid: String) -> String:
	return str(DB.destinations.get(rid, {}).get("name", Expeditions.region(rid).get("name", rid)))


static func threats(rid: String) -> Array:
	return DB.destinations.get(rid, {}).get("threats", [])


## What a party like theirs can take on (their own strength; they rarely go alone).
static func strength(a: Dictionary) -> float:
	var co := Companies.of(str(a.get("id", "")))
	var n := 2
	if not co.is_empty():
		n = clampi((co.get("members", []) as Array).size(), 1, 4)
	return Expeditions.power(a) * (0.8 + 0.4 * (n - 1))


static func danger_ratio(a: Dictionary, rid: String) -> float:
	return Expeditions.rating(rid) * float(Expeditions.diff().get("enemy", 1.0)) / maxf(1.0, strength(a))


static func danger_text(a: Dictionary, rid: String) -> String:
	var r := danger_ratio(a, rid)
	if r >= BEYOND:
		return "beyond them"
	if r >= STRETCH:
		return "a stretch for them"
	return "within their reach"


## How much of a damage type their kit brings (stats on every piece plus a coating on the weapon).
static func coverage(a: Dictionary, prop: String) -> int:
	return Expeditions.total(a, prop) + Expeditions.coat(a.get("equipment", {}).get("weapon", {}), prop)


## What the destination's threats demand that their kit lacks: [{kind: weak|resist|danger, prop?, names}].
static func gaps(a: Dictionary, rid: String) -> Array:
	var out := []
	if rid == "":
		return out
	for prop in PROPS:
		var names := []
		for th in threats(rid):
			if str(th.get("weak", "")) == prop:
				names.append(str(th.get("name", "")))
		if not names.is_empty() and coverage(a, prop) <= 0:
			out.append({"kind": "weak", "prop": prop, "names": names})
	var hard := []
	for th in threats(rid):
		if str(th.get("resist", "")) == "physical":
			hard.append(str(th.get("name", "")))
	if not hard.is_empty() and coverage(a, "magic") + coverage(a, "fire") + coverage(a, "frost") <= 0:
		out.append({"kind": "resist", "prop": "physical", "names": hard})
	if danger_ratio(a, rid) >= BEYOND:
		out.append({"kind": "danger", "names": []})
	return out


## The pieces that need attention: [{slot, item, frac, broken}] worst first.
static func worn_pieces(a: Dictionary) -> Array:
	var out := []
	for slot in a.get("equipment", {}):
		var it: Dictionary = a["equipment"][slot]
		if it.is_empty() or not (it.get("stats", {}) as Dictionary).has("durability_max"):
			continue
		var f := Items.durability_frac(it)
		if bool(it.get("broken", false)) or f < 0.45:
			out.append({"slot": str(slot), "item": it, "frac": 0.0 if bool(it.get("broken", false)) else f, "broken": bool(it.get("broken", false))})
	out.sort_custom(func(x, y): return float(x["frac"]) < float(y["frac"]))
	return out


## Why this adventurer would want the smith's advice now: {kind, text} ({} = no reason).
static func reason_for(a: Dictionary) -> Dictionary:
	if a.is_empty() or not str(a.get("status", "")) in ["in_town", "injured"]:
		return {}
	var dn := dest_name(planned_dest(a)) if planned_dest(a) != "" else "the next trip"
	var hist: Array = a.get("history", [])
	if str(a.get("status", "")) == "injured" or (not hist.is_empty() and str(hist[-1].get("outcome", "")) == "failed" and Game.day() - int(hist[-1].get("day", 0)) <= 3):
		var where := dest_name(str(hist[-1].get("dest", ""))) if not hist.is_empty() else "the wilds"
		return {"kind": "defeat", "text": "We came back from %s with our tails between our legs. Was it my kit, smith? What should I change before I go out again?" % where}
	var wp := worn_pieces(a)
	if not wp.is_empty():
		var w: Dictionary = wp[0]
		if bool(w["broken"]):
			return {"kind": "broken", "text": "My %s gave out. Is it worth mending, or should I be looking for something else before %s?" % [str(w["item"].get("name", "gear")), dn]}
		return {"kind": "worn", "text": "My %s is wearing thin. Will it hold at %s, or should I see to it?" % [str(w["item"].get("name", "gear")), dn]}
	var g := gaps(a, planned_dest(a))
	if not g.is_empty():
		var first: Dictionary = g[0]
		var what := "they say the place is dangerous" if str(first["kind"]) == "danger" else "they speak of %s there" % str((first["names"] as Array)[0])
		return {"kind": "mismatch", "text": "I'm bound for %s, and %s. Will my kit do, smith?" % [dn, what]}
	if Living.has_goal(a, "gear"):
		return {"kind": "goal", "text": "I want a kit worth trusting. Where would you have me spend my coin, smith?"}
	return {}


# ======================================================================= approaches (rate-limited)
static func on_hour(h: int) -> void:
	resolve_outcomes()
	if h < int(HOURS[0]) or h >= int(HOURS[1]):
		return
	var s := st()
	if Game.day() - int(s.get("approach_day", -99)) < APPROACH_GAP or Shop.free_seat() < 0 or randf() > APPROACH_CHANCE:
		return
	var best := {}
	var best_w := -1
	for a in Adv.in_town():
		if not can_approach(a):
			continue
		var r := reason_for(a)
		if r.is_empty():
			continue
		var w := int({"defeat": 5, "broken": 4, "mismatch": 3, "worn": 2, "goal": 1}.get(str(r["kind"]), 0))
		if w > best_w:
			best_w = w
			best = {"a": a, "r": r}
	if not best.is_empty():
		approach(str(best["a"]["id"]), best["r"])


## Would they come to the counter for advice today? (Not refusing the smith, not already waiting, not asked lately.)
static func can_approach(a: Dictionary) -> bool:
	var id := str(a.get("id", ""))
	if a.is_empty() or Shop.refuses(id) or not Shop.customer(id).is_empty() or not Expeditions.party_of(id).is_empty():
		return false
	return Game.day() - int(st()["last"].get(id, -99)) >= COOLDOWN


## The adventurer sets out for the counter with a question ({} reason = work it out). Returns the customer or {}.
static func approach(npc: String, reason := {}) -> Dictionary:
	var a := Adv.get_a(npc)
	var seat := Shop.free_seat()
	if a.is_empty() or seat < 0 or not Shop.customer(npc).is_empty():
		return {}
	var r: Dictionary = reason if not reason.is_empty() else reason_for(a)
	if r.is_empty():
		return {}
	var c := {"npc": npc, "want": "advice", "arrived": Game.day() * 24 + Game.hour(), "seat": seat, "present": false,
		"reason": str(r["kind"]), "question": str(r["text"]), "dest": planned_dest(a)}
	Shop.customers().append(c)
	st()["last"][npc] = Game.day()
	st()["approach_day"] = Game.day()
	st()["approaches"] = int(st().get("approaches", 0)) + 1
	Events.customers_changed.emit()
	return c


# ======================================================================= dialogue (Talk hooks)
static func talk_options(npc: String) -> Array:
	var a := Adv.get_a(npc)
	if a.is_empty() or not str(a.get("status", "")) in ["in_town", "injured"] or str(Shop.customer(npc).get("want", "")) == "advice":
		return []
	var o := {"id": "consult", "label": "Talk about their gear and plans"}
	var last := int(st()["last"].get(npc, -99))
	if Shop.refuses(npc):
		o["disabled"] = "they would not take your advice"
	elif Game.day() - last < TALK_COOLDOWN and not st()["sessions"].has(npc):
		o["disabled"] = "you talked it over on day %d" % last
	return [o]


static func talk_choose(npc: String, opt: String) -> Dictionary:
	if opt != "consult":
		return {}
	Events.open_panel.emit.call_deferred("consult", {"id": npc})
	return {"text": "\"Well, smith — what do you make of my kit?\"", "action": "close"}


# ======================================================================= the consultation
## Opens (or resumes, the same day) a consultation: {npc, day, reason, question, dest, recs, done{rec id: result}}.
static func session(npc: String) -> Dictionary:
	var s := st()
	var ses: Dictionary = s["sessions"].get(npc, {})
	if not ses.is_empty() and int(ses.get("day", -1)) == Game.day():
		return ses
	var a := Adv.get_a(npc)
	if a.is_empty():
		return {}
	var cu := Shop.customer(npc)
	var r := reason_for(a)
	var question := str(cu.get("question", ""))
	if question == "":
		question = str(r.get("text", "I've no complaints, smith — but I'd hear what you make of my kit before %s." % (dest_name(planned_dest(a)) if planned_dest(a) != "" else "I go out again")))
	ses = {"npc": npc, "day": Game.day(), "reason": str(cu.get("reason", r.get("kind", "asked"))), "question": question, "dest": planned_dest(a),
		"recs": recommendations(a), "done": {}}
	s["sessions"][npc] = ses
	s["last"][npc] = Game.day()
	return ses


static func picks_left(ses: Dictionary) -> int:
	return MAX_PICKS - (ses.get("done", {}) as Dictionary).size()


## Ends the consultation: the advice customer leaves (a repair they agreed to keeps them waiting).
static func finish(npc: String) -> void:
	st()["sessions"].erase(npc)
	if str(Shop.customer(npc).get("want", "")) == "advice":
		Shop.remove_customer(npc)
		var a := Adv.get_a(npc)
		if not a.is_empty():
			Events.toast.emit("%s thanks you for your time and heads off." % a["name"], "info")


# ======================================================================= recommendations
## The small generated list (3–4) from their gear, their plans and what the forge can offer, most pressing first.
## Rec: {id, kind, slot, title, why, details[], cost, relevance 0–1, skill, uid?, dest?, prop?, coat?}
static func recommendations(a: Dictionary) -> Array:
	var out := []
	var rid := planned_dest(a)
	var dn := dest_name(rid) if rid != "" else "your next trip"
	var gold := int(a.get("gold", 0))
	var g := gaps(a, rid)
	var has_order := not Shop.open_orders().filter(func(o): return str(o["npc"]) == str(a["id"])).is_empty()
	# 1. mend what is failing
	for w in worn_pieces(a).slice(0, 2):
		var it: Dictionary = w["item"]
		var cost := Adv.repair_cost(it)
		var pct := int(round(float(w["frac"]) * 100.0))
		out.append({"id": "repair_" + str(w["slot"]), "kind": "repair", "slot": str(w["slot"]), "uid": int(it.get("uid", -1)), "cost": cost,
			"title": "Mend your %s before %s" % [str(it.get("name", "gear")), dn],
			"why": "It is broken — it will barely serve." if bool(w["broken"]) else "It is down to %d%% — the next hard fight may break it." % pct,
			"details": ["Repair at the grinding wheel, about %d g." % cost, "They wait a day for it before setting out."],
			"relevance": 0.95 if bool(w["broken"]) else 0.6 + (0.45 - float(w["frac"])) * 0.6})
	# 2. the damage their destination's threats fear
	for gp in g:
		if str(gp["kind"]) != "weak":
			continue
		var prop := str(gp["prop"])
		var names: Array = gp["names"]
		var one := names.size() == 1 and (str(names[0]).begins_with("a ") or str(names[0]).begins_with("an ") or str(names[0]).begins_with("the "))
		var fear := ("%s %s %s" % [names[0], "fears" if one else "fear", prop]) if names.size() == 1 else "%s and %s fear %s" % [", ".join(PackedStringArray(names.slice(0, names.size() - 1))), names[-1], prop]
		var piece := _stock_with(a, prop)
		var coat := _coating_for(prop)
		var w2: Dictionary = a["equipment"].get("weapon", {})
		if not piece.is_empty():
			var price := Shop.price_of(piece)
			out.append({"id": "buy_%s_%d" % [prop, int(piece["uid"])], "kind": "buy", "slot": Items.slot(piece), "uid": int(piece["uid"]), "prop": prop, "cost": price,
				"title": "Take %s — the %s" % [Items.display_name(piece), fear], "why": "Nothing you carry bites with %s." % prop,
				"details": ["On your display for %d g." % price, "%s: %s %d." % [Items.display_name(piece), prop, Items.stat(piece, prop) + Expeditions.coat(piece, prop)]],
				"relevance": 0.6 + 0.12 * names.size()})
		elif not coat.is_empty() and not w2.is_empty():
			var cprice := maxi(6, int(Items.value(coat) * 1.2))
			out.append({"id": "coat_" + prop, "kind": "coat", "slot": "weapon", "uid": int(w2.get("uid", -1)), "prop": prop, "coat": str(coat["def"]), "cost": cprice,
				"title": "Let me brush %s on your %s — the %s" % [str(coat.get("name", "a coating")), str(w2.get("name", "weapon")), fear],
				"why": "Nothing you carry bites with %s; a coating lasts three trips." % prop,
				"details": ["From your stores: %s (%d g to them)." % [str(coat.get("name", "")), cprice], "Done at once, at the counter."],
				"relevance": 0.55 + 0.12 * names.size()})
		elif not has_order and Adv.can_commission(a, "weapon") and not _has(out, "kind", "commission"):
			var ccost := Adv.commission_cost(a)
			out.append({"id": "commission_" + prop, "kind": "commission", "slot": "weapon", "prop": prop, "cost": ccost,
				"title": "Let me forge you a %s-touched weapon for %s" % [prop, dn], "why": "%s." % (fear.substr(0, 1).to_upper() + fear.substr(1)),
				"details": ["A commission: about %d g, ready in a few days." % ccost, "They hold off on %s until it is ready." % dn],
				"relevance": 0.45 + 0.1 * names.size()})
	# 3. a better piece on display for a slot that lets them down
	for need in Adv.gear_needs(a):
		if not str(need["why"]) in ["missing", "inferior"]:
			continue
		var best := Adv.best_stock(a, str(need["slot"]))
		if best.is_empty() or _has(out, "uid", int(best["uid"])):
			continue
		var cur: Dictionary = a["equipment"].get(str(need["slot"]), {})
		var p2 := Shop.price_of(best)
		out.append({"id": "buy_%d" % int(best["uid"]), "kind": "buy", "slot": str(need["slot"]), "uid": int(best["uid"]), "cost": p2,
			"title": ("Your %s is too light for %s — take %s" % [str(cur.get("name", "")), dn, Items.display_name(best)]) if not cur.is_empty() else ("Don't go to %s without %s — take %s" % [dn, Shop.slot_phrase(str(need["slot"])), Items.display_name(best)]),
			"why": "Their %s is %s." % [Adv._slot_name(str(need["slot"])).to_lower(), Adv.WHY_WORD.get(str(need["why"]), "lacking")],
			"details": ["On your display for %d g." % p2, "Rated %d against %d for what they wear." % [int(Items.score(best)), int(Items.score(cur))]],
			"relevance": 0.55 if str(need["why"]) == "missing" else 0.45})
		break
	# 4. an upgrade to a better metal for a veteran's weapon
	var wpn: Dictionary = a["equipment"].get("weapon", {})
	if not has_order and not wpn.is_empty() and int(a.get("level", 1)) >= 3 and Items.tier(wpn) < 2 and Adv.can_commission(a, "weapon") and not _has(out, "kind", "commission"):
		var ucost := int(Adv.commission_cost(a) * 1.4)
		out.append({"id": "upgrade_weapon", "kind": "upgrade", "slot": "weapon", "cost": ucost,
			"title": "Have your %s made anew in steel" % str(wpn.get("name", "weapon")),
			"why": "Level %d, still swinging plain iron." % int(a.get("level", 1)),
			"details": ["A commission for a steel weapon: about %d g." % ucost, "Steel or better is required."],
			"relevance": 0.35 + (0.1 if Living.has_goal(a, "gear") else 0.0)})
	# 5. a safer place first
	for gp in g:
		if not str(gp["kind"]) in ["danger", "resist"]:
			continue
		var alt := safer_site(a, rid)
		if alt == "":
			break
		out.append({"id": "dest_" + alt, "kind": "dest", "dest": alt, "avoid": rid, "cost": 0,
			"title": "Don't go to %s with this kit — try %s first" % [dn, dest_name(alt)],
			"why": ("%s is %s." % [dn, danger_text(a, rid)]) if str(gp["kind"]) == "danger" else ("Plain steel does little against %s." % ", ".join(PackedStringArray(gp["names"]))),
			"details": ["%s: %s (%s)." % [dest_name(alt), WorldSites.danger_word(alt), danger_text(a, alt)], "Changes where they mean to go next."],
			"relevance": 0.8 if str(gp["kind"]) == "danger" else 0.5})
		break
	# 6. rest after a beating
	var hist: Array = a.get("history", [])
	var beaten := str(a.get("status", "")) == "injured" or float(a.get("hp", 1)) < float(a.get("hp_max", 1)) * 0.7 or float(a.get("trauma", 0.0)) >= 30.0 \
		or (not hist.is_empty() and str(hist[-1].get("outcome", "")) == "failed" and Game.day() - int(hist[-1].get("day", 0)) <= 3)
	if beaten:
		out.append({"id": "rest", "kind": "rest", "cost": 0, "title": "Rest a few days before you go out again",
			"why": "They are %s." % ("still hurt" if float(a.get("hp", 1)) < float(a.get("hp_max", 1)) * 0.7 else "shaken"),
			"details": ["Departure put back two days.", "HP %d / %d." % [int(a.get("hp", 0)), int(a.get("hp_max", 0))]], "relevance": 0.55})
	# 7. honest advice: the forge's work is beyond their purse
	var cheapest := 1 << 30
	for r in out:
		if int(r["cost"]) > 0:
			cheapest = mini(cheapest, int(r["cost"]))
	if cheapest > gold and cheapest < (1 << 30):
		var ro := Commerce.rival_offer_for(a)
		if not ro.is_empty():
			out.append({"id": "elsewhere", "kind": "elsewhere", "slot": str(ro["slot"]), "cost": int(ro["price"]),
				"title": "My work is beyond your purse — the Salt Anvil sells plainer %s" % Shop.slot_phrase(str(ro["slot"])).trim_prefix("a ").trim_prefix("an "),
				"why": "They have %d g; your cheapest fix costs %d g." % [gold, cheapest],
				"details": ["%s at the Salt Anvil for %d g." % [str(ro["item"].get("name", "a piece")), int(ro["price"])], "Honest advice: earns goodwill, not coin."],
				"relevance": 0.5})
	# 8. if the kit is sound, say so; if it is not and nothing else fits, counsel caution
	if out.size() < 3:
		if g.is_empty() and worn_pieces(a).is_empty():
			out.append({"id": "keep", "kind": "keep", "cost": 0, "title": "Your kit will serve at %s — keep your coin" % dn,
				"why": "Nothing pressing: %s is %s." % [dn, danger_text(a, rid) if rid != "" else "not decided"], "details": ["Nothing changes — but they will remember whether you were right."],
				"relevance": 0.5})
		else:
			out.append({"id": "keep", "kind": "keep", "cost": 0, "title": "Go as you are — but turn back at the first bad fight",
				"why": "Their kit has gaps at %s; caution can make up for some of it." % dn, "details": ["Nothing is bought or changed — only their nerve.", "They will remember whether you were right."],
				"relevance": 0.3})
	for r in out:
		r["skill"] = KIND_SKILL.get(str(r["kind"]), "smithing")
		r["relevance"] = clampf(float(r["relevance"]), 0.0, 1.0)
	out.sort_custom(func(x, y): return float(x["relevance"]) > float(y["relevance"]))
	return out.slice(0, 4)


static func _has(recs: Array, key: String, v: Variant) -> bool:
	for r in recs:
		if r.get(key) == v:
			return true
	return false


## A piece on display (for sale) that carries `prop` and that they would actually buy.
static func _stock_with(a: Dictionary, prop: String) -> Dictionary:
	var best := {}
	for it in Shop.stock():
		if not Items.is_equipment(it) or Items.stat(it, prop) + Expeditions.coat(it, prop) <= 0:
			continue
		if Items.slot(it) != "weapon" or Adv.purchase_check(a, it, Shop.price_of(it)) != "":
			continue
		if best.is_empty() or Items.score(it) > Items.score(best):
			best = it
	return best


static func _coating_for(prop: String) -> Dictionary:
	for d in COATINGS.get(prop, []):
		for it in Game.inventory():
			if str(it["def"]) == str(d):
				return it
	return {}


## A discovered site well within their strength (the most rewarding of those), other than `avoid`.
static func safer_site(a: Dictionary, avoid: String) -> String:
	var best := ""
	var best_r := -1.0
	for rid in Expeditions.cfg().get("regions", {}):
		if str(rid) == avoid or not WorldSites.is_discovered(str(rid)):
			continue
		var dd: Dictionary = DB.destinations.get(rid, {})
		if dd.has("requires_flag") and not Game.has_flag(str(dd["requires_flag"])) and not WorldSites.cfg().has(rid):
			continue
		var ratio := danger_ratio(a, str(rid))
		if ratio <= SAFE and ratio < danger_ratio(a, avoid) * 0.8 and Expeditions.rating(str(rid)) > best_r:
			best_r = Expeditions.rating(str(rid))
			best = str(rid)
	return best


# ======================================================================= persuasion
## The odds that they take this advice: {p, word, reasons: [[text, delta]] (largest first)}.
static func odds(a: Dictionary, rec: Dictionary) -> Dictionary:
	var npc := str(a["id"])
	var kind := str(rec["kind"])
	var reasons := []
	var p := 0.42
	# the smith's relevant craft
	var sk := str(rec.get("skill", "smithing"))
	var lv := Game.player_level(sk)
	var d := clampf((lv - 3) * 0.035, -0.08, 0.18)
	reasons.append(["Your %s (level %d)" % [SkillSys.skill_name(sk).to_lower(), lv], d])
	# how they regard the smith
	var aff := Social.aff(npc)
	reasons.append(["They %s you" % ("like" if aff >= 20.0 else ("distrust" if aff <= -10.0 else "hardly know")), aff / 100.0 * 0.3])
	# the workshop's name
	var rep := Shop.reputation()
	reasons.append(["The forge is %s" % Shop.reputation_word(), rep / 100.0 * 0.15])
	# the track record
	var cred := credibility(npc)
	reasons.append(["Your track record: %s" % credibility_word(npc), cred / 100.0 * 0.35])
	# the purse
	var cost := int(rec.get("cost", 0))
	var gold := int(a.get("gold", 0))
	if cost > 0:
		if cost > gold and Social.spouse() != npc:
			reasons.append(["It costs %d g; they have %d g" % [cost, gold], -0.7])
		else:
			reasons.append(["It costs %d of their %d g" % [cost, gold], -float(cost) / maxf(1.0, gold) * 0.35])
	# temper and goals
	var tr := str(a.get("trait", "steady"))
	var cautious_kind := kind in ["dest", "rest", "repair"]
	var t := 0.0
	var tw := ""
	match tr:
		"cautious":
			if cautious_kind:
				t = 0.12
				tw = "Cautious by nature"
		"reckless":
			if kind in ["dest", "rest"]:
				t = -0.18
				tw = "Reckless — hates to turn back"
		"brave":
			if kind == "dest":
				t = -0.08
				tw = "Brave — wants the harder road"
		"greedy":
			if cost > 0:
				t = -0.08
				tw = "Greedy — counts every coin"
	if tw != "":
		reasons.append([tw, t])
	if Living.has_goal(a, "gear") and kind in ["buy", "commission", "upgrade", "coat", "repair"]:
		reasons.append(["Wants better gear", 0.12])
	if Living.has_goal(a, "wealth") and cost > 0:
		reasons.append(["Saving up", -0.1])
	if (Living.has_goal(a, "renown") or Living.has_goal(a, "rival")) and kind in ["dest", "rest"]:
		reasons.append(["Hungry for glory", -0.1])
	if float(a.get("trauma", 0.0)) >= 30.0 and kind in ["dest", "rest"]:
		reasons.append(["Still shaken", 0.1])
	# how clear the case is
	reasons.append(["The case is %s" % ("plain to see" if float(rec["relevance"]) >= 0.7 else ("fair" if float(rec["relevance"]) >= 0.45 else "thin")), (float(rec["relevance"]) - 0.5) * 0.3])
	for r in reasons:
		p += float(r[1])
	p = clampf(p, 0.05, 0.95)
	reasons.sort_custom(func(x, y): return absf(float(x[1])) > absf(float(y[1])))
	return {"p": p, "word": odds_word(p), "reasons": reasons}


static func odds_word(p: float) -> String:
	if p >= 0.8:
		return "almost certain"
	if p >= 0.62:
		return "likely"
	if p >= 0.45:
		return "even odds"
	if p >= 0.28:
		return "a hard sell"
	return "unlikely"


## The seeded roll for this advice today (same day, same advice → same answer).
static func roll(npc: String, rec_id: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = absi(hash("consult|%d|%s|%s|%d" % [Living.world_seed(), npc, rec_id, Game.day()]))
	return r.randf()


## The smith puts this recommendation forward. Returns {ok, accepted, text, effect, p, word, record}.
static func advise(npc: String, rec_id: String) -> Dictionary:
	var a := Adv.get_a(npc)
	var ses := session(npc)
	if a.is_empty() or ses.is_empty():
		return {"ok": false, "text": "They have gone."}
	if (ses["done"] as Dictionary).has(rec_id):
		return ses["done"][rec_id]
	if picks_left(ses) <= 0:
		return {"ok": false, "text": "You have said your piece."}
	var rec := {}
	for r in ses["recs"]:
		if str(r["id"]) == rec_id:
			rec = r
	if rec.is_empty():
		return {"ok": false, "text": "No such advice."}
	var od := odds(a, rec)
	var x := roll(npc, rec_id)
	var accepted := x < float(od["p"])
	var res := {"ok": true, "accepted": accepted, "p": float(od["p"]), "word": str(od["word"]), "effect": ""}
	if accepted:
		var eff := _apply(a, rec)
		if eff.begins_with("!"):
			accepted = false
			res["accepted"] = false
			res["text"] = _voice_refuse(a, rec, od, eff.substr(1))
		else:
			res["effect"] = eff
			res["text"] = _voice_accept(a, rec)
			Adv._gear_note(a, "Took the smith's advice: %s." % str(rec["title"]).to_lower(), false)
	else:
		res["text"] = _voice_refuse(a, rec, od, "")
	var rd := _record(a, rec, accepted, float(od["p"]))
	res["record"] = rd["id"]
	Social.change(npc, 1.0 if accepted else 0.0, 2.0)
	ses["done"][rec_id] = res
	Events.customers_changed.emit()
	Events.adventurers_changed.emit()
	return res


# ======================================================================= what accepted advice does
## Carries out accepted advice through the existing flows. Returns the effect in words, or "!why" if it fell through.
static func _apply(a: Dictionary, rec: Dictionary) -> String:
	var npc := str(a["id"])
	match str(rec["kind"]):
		"buy":
			var keep := Shop.customer(npc)
			var err := Shop.sell_to(npc, int(rec["uid"]))
			if err != "":
				return "!" + err
			if str(keep.get("want", "")) == "repair" and Shop.customer(npc).is_empty():
				Shop.customers().append(keep)   # a repair agreed to in the same visit still waits
			return "%s bought it (%d g)." % [a["name"], int(rec["cost"])]
		"repair":
			var it: Dictionary = a["equipment"].get(str(rec["slot"]), {})
			if it.is_empty():
				return "!the piece is gone"
			var c := Shop.customer(npc)
			if c.is_empty():
				var seat := Shop.free_seat()
				if seat < 0:
					return "!no seat at the counter"
				c = {"npc": npc, "arrived": Game.day() * 24 + Game.hour(), "seat": seat, "present": false}
				Shop.customers().append(c)
			c["want"] = "repair"
			c["own_slot"] = str(rec["slot"])
			c["item"] = it
			c["pay"] = int(rec["cost"])
			a["depart_day"] = maxi(int(a.get("depart_day", 0)), Game.day() + 1)
			Events.customers_changed.emit()
			return "%s waits at the counter for the repair and holds off a day." % a["name"]
		"coat":
			var w: Dictionary = a["equipment"].get("weapon", {})
			var co := _coating_for(str(rec["prop"]))
			if w.is_empty() or co.is_empty():
				return "!there is no coating in your stores"
			if int(a.get("gold", 0)) < int(rec["cost"]):
				return "!can't afford it"
			var t: Array = Crafting.TREATMENTS.get(str(co["def"]), [str(rec["prop"]), str(co.get("name", "Coating"))])
			var base := float(DB.item(str(co["def"])).get("stats", {}).get(t[0], 2))
			var val := int(round(maxf(2.0, base * 2.0) * (0.7 + float(co.get("quality", 70)) / 200.0)))
			Game.remove_def(str(co["def"]), 1)
			w["coating"] = {"name": str(t[1]), "stat": str(t[0]), "value": val, "uses": 3}
			Provenance.workshop(w, "treated", "Treated with %s at the Ironhand forge for %s (+%d %s), on the smith's advice." % [t[1], a["name"], val, t[0]])
			a["gold"] = int(a["gold"]) - int(rec["cost"])
			Game.add_gold(int(rec["cost"]), "sales", "%s for %s's %s" % [t[1], a["name"], w.get("name", "weapon")])
			Game.grant_player_xp("alchemy", 4)
			Events.inventory_changed.emit()
			return "Their %s now bites with %s (+%d for three trips)." % [w.get("name", "weapon"), t[0], val]
		"commission", "upgrade":
			if str(rec.get("prop", "")) != "":
				a["wants_prop"] = str(rec["prop"])
			var note := "On the smith's advice: %s." % str(rec["title"]).to_lower()
			var o := Shop.create_order(npc, str(rec.get("slot", "weapon")), note)
			if o.is_empty():
				return "!won't order from you"
			if str(rec["kind"]) == "upgrade":
				o["tier"] = maxi(2, int(o.get("tier", 1)))
				o["min"] = mini(int(o["min"]), Shop.slot_ceiling(str(o["slot"]), str(o["stat"])))
			o["advised"] = true
			a["depart_day"] = maxi(int(a.get("depart_day", 0)), int(o["deadline"]))
			Events.orders_changed.emit()
			return "A commission: %s (due day %d). They hold off until it is ready." % [Shop.order_text(o), int(o["deadline"])]
		"dest":
			var alt := str(rec["dest"])
			a["next_dest"] = alt
			a["advised"] = {"avoid": str(rec.get("avoid", "")), "prefer": alt, "until": Game.day() + 8}
			var p := Expeditions.party_of(npc)
			if not p.is_empty() and str(p["dest"]) == str(rec.get("avoid", "")) and str(p["leader"]) == npc:
				p["dest"] = alt
			Adv.plan_next(a)
			return "%s will try %s instead of %s." % [a["name"], dest_name(alt), dest_name(str(rec.get("avoid", "")))]
		"rest":
			a["depart_day"] = maxi(int(a.get("depart_day", 0)), Game.day() + 2)
			return "%s will rest until day %d." % [a["name"], int(a["depart_day"])]
		"elsewhere":
			var bought := Commerce.rival_buy_for(a)
			if bought.is_empty():
				return "!the Salt Anvil had nothing for them"
			Social.change(npc, 2.0, 1.0, "honest_" + str(Game.day()), "The smith sent me to the Salt Anvil rather than sell me what I couldn't afford.")
			return "%s went to the Salt Anvil and came back with %s." % [a["name"], str(bought.get("name", bought.get("item", {}).get("name", "a plainer piece")))]
		"keep":
			return "%s keeps their kit as it is." % a["name"]
	return "!"


# ======================================================================= voices
static func _voice_accept(a: Dictionary, rec: Dictionary) -> String:
	match str(rec["kind"]):
		"buy":
			return "\"You're right. I'll take it — and if it fails me, you'll hear of it.\""
		"repair":
			return "\"Aye, mend it. I'd rather wait a day than lose an arm.\""
		"coat":
			return "\"Brush it on, then. Let them taste %s.\"" % str(rec.get("prop", "fire"))
		"commission", "upgrade":
			return "\"Make it, then. I'll wait for it.\""
		"dest":
			return "\"…%s first. Fine. You've not steered me wrong yet.\"" % dest_name(str(rec["dest"]))
		"rest":
			return "\"A few days by the fire. Maybe you're right.\""
		"elsewhere":
			return "\"Honest of you, smith. I won't forget it.\""
	return "\"Good. That's what I hoped to hear.\""


static func _voice_refuse(a: Dictionary, rec: Dictionary, od: Dictionary, fell: String) -> String:
	if fell != "":
		return "\"I'd do it, smith, but %s.\"" % fell.trim_prefix(str(a["name"]) + " ")
	var worst := ""
	for r in od["reasons"]:
		if float(r[1]) < 0.0:
			worst = str(r[0])
			break
	if worst.begins_with("It costs"):
		return "\"I haven't the coin for that, smith. Not now.\""
	if worst.begins_with("Reckless") or worst.begins_with("Brave") or worst.begins_with("Hungry"):
		return "\"Turn back from %s? Not while there's a name to be made there.\"" % dest_name(str(rec.get("avoid", planned_dest(a))))
	if worst.begins_with("Your track record"):
		return "\"Your last advice cost me. I'll trust my own eyes this time.\""
	if worst.begins_with("They distrust"):
		return "\"I'll not be told how to fight by you, smith.\""
	if worst.begins_with("Greedy") or worst.begins_with("Saving"):
		return "\"Every coin I spend here is one I'm not putting by. No.\""
	return "\"I hear you, smith. But I know my own kit — I'll go as I am.\""


# ======================================================================= records and outcomes
static func _record(a: Dictionary, rec: Dictionary, accepted: bool, p: float) -> Dictionary:
	var s := st()
	var hist: Array = a.get("history", [])
	var r := {"id": "adv_%d" % int(s["next"]), "npc": str(a["id"]), "name": str(a["name"]), "day": Game.day(), "kind": str(rec["kind"]),
		"title": str(rec["title"]), "accepted": accepted, "p": p, "dest": planned_dest(a), "avoid": str(rec.get("avoid", "")),
		"uid": int(rec.get("uid", -1)), "after": str(hist[-1].get("exp", "")) if not hist.is_empty() else "", "status": "open", "outcome": ""}
	s["next"] = int(s["next"]) + 1
	records().append(r)
	while records().size() > 120:
		records().pop_front()
	return r


## Judges the advice whose test has come: the adventurer's next expedition after it (or their death).
static func resolve_outcomes() -> void:
	if not Game.state.has("consult"):
		return
	var ses: Dictionary = st()["sessions"]
	for k in ses.keys():
		if int(ses[k].get("day", -1)) != Game.day():
			ses.erase(k)   # a consultation lasts the day it was held
	for r in records():
		if str(r["status"]) != "open":
			continue
		var a := Adv.get_a(str(r["npc"]))
		if a.is_empty() or str(a.get("status", "")) in ["retired", "gone"]:
			_close(r, "moot")
			continue
		if str(a.get("status", "")) in ["dead", "missing"] and int(a.get("died_day", Game.day())) >= int(r["day"]):
			r["went"] = str(a.get("dest", r["dest"]))
			_judge(r, a, "died" if str(a["status"]) == "dead" else "failed")
			continue
		var seen := str(r.get("after", "")) == ""
		for h in a.get("history", []):
			if not seen:
				seen = str(h.get("exp", "")) == str(r["after"])
				continue
			if int(h.get("day", 0)) >= int(r["day"]):
				r["went"] = str(h.get("dest", ""))
				r["exp"] = str(h.get("exp", ""))
				_judge(r, a, str(h.get("outcome", "failed")))
				break
		if str(r["status"]) == "open" and Game.day() - int(r["day"]) > RECORD_DAYS:
			_close(r, "moot")


static func _close(r: Dictionary, outcome: String) -> void:
	r["status"] = "closed"
	r["outcome"] = outcome
	r["closed_day"] = Game.day()


## Credibility, the relationship and (for notable cases) one Lore event.
static func _judge(r: Dictionary, a: Dictionary, outcome: String) -> void:
	_close(r, outcome)
	var npc := str(r["npc"])
	var good := outcome == "success"
	var went := str(r.get("went", ""))
	var where := dest_name(went) if went != "" else "the wilds"
	var s := st()
	var verdict := ""
	if bool(r["accepted"]):
		if str(r["kind"]) == "dest" and went != "" and went == str(r.get("avoid", "")):
			verdict = "moot"   # they ended up there anyway — the advice was never tested
		elif good:
			verdict = "right"
			_cred_add(npc, 10.0, 3.0)
			Social.change(npc, 3.0, 2.0, "advice_" + str(r["id"]), "Brannoc's advice served me well at %s." % where, false)
		else:
			verdict = "wrong"
			_cred_add(npc, -12.0, -4.0)
			Social.change(npc, -4.0, 2.0, "advice_" + str(r["id"]), "I took the smith's advice and still came to grief at %s." % where, false)
	else:
		if good:
			verdict = "wrong"
			_cred_add(npc, -3.0, -1.0)
		else:
			verdict = "right"
			_cred_add(npc, 5.0, 2.0)
			if outcome != "died":
				Social.change(npc, 1.0, 2.0, "advice_" + str(r["id"]), "Should have listened to the smith before %s." % where, false)
	r["verdict"] = verdict
	if verdict == "right":
		s["good"] = int(s.get("good", 0)) + 1
	elif verdict == "wrong":
		s["bad"] = int(s.get("bad", 0)) + 1
	# notable: advice taken and proved at a dangerous place, a death, a warning ignored to the cost of a life
	var risky := went != "" and WorldSites.danger_word(went) in ["risky", "dangerous", "deadly"]
	var notable := (bool(r["accepted"]) and (outcome == "died" or (good and (risky or str(r["kind"]) in ["dest", "coat", "commission", "upgrade"])))) \
		or (not bool(r["accepted"]) and outcome in ["died", "failed"] and risky)
	if notable and verdict != "moot" and not r.has("lore"):
		var text := ""
		var advice := str(r["title"]).to_lower()
		if bool(r["accepted"]):
			if good:
				text = "On Brannoc's advice (\"%s\"), %s set out for %s — and came home victorious." % [advice, a["name"], where]
			elif outcome == "died":
				text = "%s took Brannoc's advice (\"%s\") and did not come home from %s." % [a["name"], advice, where]
			else:
				text = "%s took Brannoc's advice (\"%s\") and still came home beaten from %s." % [a["name"], advice, where]
		else:
			text = "%s ignored Brannoc's warning (\"%s\") and %s at %s." % [a["name"], advice, "fell" if outcome == "died" else "came to grief", where]
		var items := []
		if int(r.get("uid", -1)) > 0:
			var it := Game.find_uid_anywhere(int(r["uid"]))
			if not it.is_empty():
				items.append(it)
		r["lore"] = Lore.record("advice", text, {"actors": [npc], "items": items, "place": went, "importance": 2 if outcome == "died" else 1,
			"chronicle": true, "icon": "ui/ic_talk", "data": {"kind": r["kind"], "accepted": r["accepted"], "outcome": outcome}})


## Bias for Expeditions.choose_destination: accepted advice keeps a party away from where the smith warned them
## off and toward what he suggested (for a few days).
static func dest_bias(members: Array, rid: String) -> float:
	var b := 0.0
	for m in members:
		var adv: Dictionary = m.get("advised", {})
		if adv.is_empty() or Game.day() > int(adv.get("until", 0)):
			continue
		if str(adv.get("avoid", "")) == rid:
			b -= 40.0
		elif str(adv.get("prefer", "")) == rid:
			b += 14.0
	return b


## The smith's record as an adviser: {given, taken, right, wrong, open}.
static func track_record() -> Dictionary:
	var out := {"given": 0, "taken": 0, "right": int(st().get("good", 0)), "wrong": int(st().get("bad", 0)), "open": 0}
	for r in records():
		out["given"] += 1
		if bool(r["accepted"]):
			out["taken"] += 1
		if str(r["status"]) == "open":
			out["open"] += 1
	return out
