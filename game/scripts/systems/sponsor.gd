## Sponsor — sponsored expeditions (The Living Realm, milestone 4).
## EN: The smith commissions a company or a lone adventurer in town to fetch something from a known site: a
##     material or rare find (from the site's real loot tables), a relic, a named piece of lost equipment lying
##     there (WorldSites.lost), salvage, or information / a discovery beyond the site. The party weighs the offer
##     (capability against the site's danger, their gear, fee up front, bonus on success, share of the haul,
##     travel, temper and goals, how they regard the smith and the smith's name) and accepts, refuses with a
##     reason, or counters (a higher fee, a bigger share, a safer site where the same thing is found) — at most two
##     counter rounds. An accepted contract becomes an ordinary party in Expeditions (it gathers, prepares and
##     leaves at 08:00 like any other) with the objective attached: the destination is fixed, the route heads for
##     the objective's node, and what happens there (fights, skill checks, luck, depletion, a master alive or slain)
##     decides the result. Everything the party brings home for the smith arrives once, in a container on the
##     returns shelf; recovered lost gear keeps its uid, maker and history (Provenance transfer "recovered").
##     The fee is held in escrow until the party leaves (a cancel or a failed departure returns it in full); the
##     bonus is paid on success (half on a partial success). The sponsorship and its outcome are ONE Lore event.
##     State: Game.state.sponsor = {list: {sid: record}, next, talk: {} (the open negotiation)}; parties carry
##     `sponsor` (sid) and so do expedition records.
## DA: Sponsorerede ekspeditioner: mål, forhandling (accept, afslag med grund, modbud), rigtige udfald,
##     proveniens og én Lore-begivenhed pr. sponsorat.
class_name Sponsor
extends RefCounted

const KINDS := ["material", "relic", "lost", "salvage", "discovery"]
const KIND_WORD := {"material": "Material", "relic": "Relic", "lost": "Lost equipment", "salvage": "Salvage", "discovery": "Discovery"}
const MAX_COUNTERS := 2            # counter-offers before the party's last word
const STATUS_WORD := {"contracted": "Preparing — leaves at 08:00", "under_way": "Under way", "done": "Home", "cancelled": "Cancelled"}
const OUTCOME_WORD := {"success": "Success", "partial": "Partial success", "failure": "Failed", "lost": "Party lost"}


# ======================================================================= state
static func st() -> Dictionary:
	if not Game.state.has("sponsor"):
		Game.state["sponsor"] = {"list": {}, "next": 1, "talk": {}}
	return Game.state["sponsor"]


static func get_s(sid: String) -> Dictionary:
	return st()["list"].get(sid, {})


## All sponsorships, newest first.
static func all() -> Array:
	var out: Array = st()["list"].values()
	out.sort_custom(func(a, b): return int(str(a["id"]).trim_prefix("sp_")) > int(str(b["id"]).trim_prefix("sp_")))
	return out


static func open() -> Array:
	return all().filter(func(s): return str(s["status"]) in ["contracted", "under_way"])


static func talk() -> Dictionary:
	return st()["talk"]


# ======================================================================= objectives (from the real site data)
static func sites() -> Array:
	var out := []
	var regs: Dictionary = Expeditions.cfg().get("regions", {})
	for rid in regs:
		if WorldSites.is_discovered(str(rid)):
			out.append(str(rid))
	out.sort_custom(func(a, b): return Expeditions.rating(a) < Expeditions.rating(b))
	return out


## What can be commissioned at a site, as it stands now. Each objective:
## {kind, site, node, def, uid, qty, name, value}.
static func objectives(rid: String) -> Array:
	var out := []
	if Expeditions.region(rid).is_empty() or not WorldSites.is_discovered(rid):
		return out
	var nodes: Array = Expeditions.region(rid).get("nodes", [])
	# lost equipment lying here (by name; the uid is the piece's identity)
	for x in WorldSites.lost(rid):
		var it: Dictionary = x["item"]
		out.append({"kind": "lost", "site": rid, "node": str(x.get("node", "")), "def": str(it.get("def", "")), "uid": int(it.get("uid", -1)), "qty": 1,
			"name": "%s (lost by %s, day %d)" % [Items.display_name(it), str(x.get("owner_name", "an adventurer")), int(x.get("day", 0))], "value": Items.value(it)})
	# materials, relics, salvage: from the loot tables of the site's places
	var mats := {}      # def -> [node, share, entry max qty]
	var relic_node := ""
	var relic_share := 0.0
	var salvage_node := ""
	var salvage_score := 0.0
	for n in nodes:
		var table := str(n.get("loot", ""))
		var kind := str(n.get("kind", ""))
		if kind == "puzzle":
			if relic_node == "" or relic_share < 1.0:
				relic_node = str(n["id"])
				relic_share = 1.0
			continue
		if table == "" or not (kind in ["resource", "chest", "boss", "encounter", "trap"]):
			continue
		var t: Dictionary = DB.loot.get(table, {})
		var entries: Array = (t.get("entries", []) as Array).duplicate()
		var se: Dictionary = t.get("skill_entries", {})
		for k in se:
			entries.append_array(se[k])
		var total := 0.0
		for en in entries:
			total += float(en[1])
		var rshare := 0.0
		var eshare := 0.0
		for en in entries:
			var d := str(en[0])
			var sh := float(en[1]) / maxf(1.0, total)
			if d.begins_with("equip:"):
				eshare += sh
				continue
			if d.begins_with("relic"):
				rshare += sh
				continue
			if DB.item(d).is_empty():
				continue
			if not mats.has(d) or float(mats[d][1]) < sh:
				mats[d] = [str(n["id"]), sh, int(en[2][1])]
		if rshare > relic_share:
			relic_share = rshare
			relic_node = str(n["id"])
		var es := eshare * float(n.get("tier", 1))
		if es > salvage_score:
			salvage_score = es
			salvage_node = str(n["id"])
	var mlist := []
	for d in mats:
		var share := float(mats[d][1])
		var qty := 1 if share < 0.06 else clampi(int(mats[d][2]), 1, 4)
		var val := int(DB.item(str(d)).get("value", 5)) * qty
		mlist.append({"kind": "material", "site": rid, "node": str(mats[d][0]), "def": str(d), "uid": -1, "qty": qty,
			"name": "%s%s from %s" % [("%d × " % qty) if qty > 1 else "", str(DB.item(str(d)).get("name", d)), Expeditions.node_of(rid, str(mats[d][0])).get("name", "")], "value": val, "share": share})
	mlist.sort_custom(func(a, b): return float(a["share"]) < float(b["share"]) or (float(a["share"]) == float(b["share"]) and str(a["def"]) < str(b["def"])))
	out.append_array(mlist)
	if relic_node != "":
		out.append({"kind": "relic", "site": rid, "node": relic_node, "def": "", "uid": -1, "qty": 1,
			"name": "A relic from %s" % Expeditions.node_of(rid, relic_node).get("name", ""), "value": 70})
	if salvage_node != "":
		out.append({"kind": "salvage", "site": rid, "node": salvage_node, "def": "", "uid": -1, "qty": 1,
			"name": "Salvage: arms and armour from %s" % Expeditions.node_of(rid, salvage_node).get("name", ""), "value": 60})
	var deep := _deepest(rid)
	if deep != "":
		var beyond := _undiscovered_near(rid)
		out.append({"kind": "discovery", "site": rid, "node": deep, "def": "", "uid": -1, "qty": 1,
			"name": ("Scout beyond %s for unknown places" % WorldSites.name_of(rid)) if not beyond.is_empty() else ("Survey %s to %s (news of the site)" % [WorldSites.name_of(rid), Expeditions.node_of(rid, deep).get("name", "")]),
			"value": 50 if not beyond.is_empty() else 30})
	return out


static func all_objectives() -> Array:
	var out := []
	for rid in sites():
		out.append_array(objectives(rid))
	return out


## The deepest place short of the master's lair (the far edge of what the party can see from).
static func _deepest(rid: String) -> String:
	var depth := _depths(rid)
	var best := ""
	var bd := -1
	var boss := str(WorldSites.info(rid).get("boss", ""))
	for nid in depth:
		var n := Expeditions.node_of(rid, str(nid))
		if str(nid) == boss or str(n.get("kind", "")) == "boss":
			continue
		if int(depth[nid]) > bd:
			bd = int(depth[nid])
			best = str(nid)
	return best


static func _depths(rid: String) -> Dictionary:
	var nodes: Array = Expeditions.region(rid).get("nodes", [])
	var depth := {}
	if nodes.is_empty():
		return depth
	var q := [str(nodes[0]["id"])]
	depth[str(nodes[0]["id"])] = 0
	while not q.is_empty():
		var cur: String = q.pop_front()
		for l in Expeditions.node_of(rid, cur).get("links", []):
			if not depth.has(str(l)):
				depth[str(l)] = int(depth[cur]) + 1
				q.append(str(l))
	return depth


static func _undiscovered_near(rid: String) -> Array:
	return WorldSites.ids().filter(func(i): return not WorldSites.is_discovered(str(i)) and str(WorldSites.info(str(i)).get("gate", "")) == "" \
		and (WorldSites.info(str(i)).get("near", []) as Array).has(rid))


## The route from the entry to the objective's node (shortest path along the links), excluding the entry.
static func route_to(rid: String, target: String) -> Array:
	var nodes: Array = Expeditions.region(rid).get("nodes", [])
	if nodes.is_empty():
		return []
	var start := str(nodes[0]["id"])
	var prev := {start: ""}
	var q := [start]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == target:
			break
		for l in Expeditions.node_of(rid, cur).get("links", []):
			if not prev.has(str(l)):
				prev[str(l)] = cur
				q.append(str(l))
	if not prev.has(target):
		return []
	var path := []
	var c := target
	while c != start:
		path.push_front(c)
		c = str(prev[c])
	return path


## For Expeditions.start: a sponsored party heads straight for the objective.
static func route_for(p: Dictionary, rid: String) -> Array:
	var sp := get_s(str(p.get("sponsor", "")))
	var r := route_to(rid, str(sp.get("objective", {}).get("node", "")))
	return r if not r.is_empty() else Expeditions.plan_route(rid, p["members"])


# ======================================================================= who can be asked
static func _free(a: Dictionary) -> bool:
	return str(a.get("status", "")) == "in_town" and Expeditions.party_of(str(a["id"])).is_empty() and Living.is_active(a) \
		and not (str(a["id"]) == "mira" and Game.day() < 6)


## Companies with members in town, and lone adventurers in town. [{key, name, members, company, label}]
static func candidates() -> Array:
	var out := []
	var taken := {}
	for c in Companies.active():
		var ms: Array = (c["members"] as Array).filter(func(i): return _free(Adv.get_a(str(i))))
		if ms.is_empty():
			continue
		ms = ms.slice(0, Companies.MAX_SIZE)
		if ms.has(str(c["leader"])):
			ms.erase(str(c["leader"]))
			ms.push_front(str(c["leader"]))
		for m in ms:
			taken[str(m)] = true
		out.append({"key": "co:" + str(c["id"]), "name": str(c["name"]), "members": ms, "company": str(c["id"]),
			"label": "%s — %s" % [c["name"], Expeditions._and(ms.map(func(i): return str(Adv.get_a(str(i))["name"])))]})
	var solos := []
	for a in Adv.all().values():
		if taken.has(str(a["id"])) or not Companies.of(str(a["id"])).is_empty() or not _free(a):
			continue
		Expeditions.ensure(a)
		solos.append({"key": "adv:" + str(a["id"]), "name": str(a["name"]), "members": [str(a["id"])], "company": "",
			"label": "%s (%s %d, alone)" % [a["name"], a["cls"], int(a["level"])]})
	solos.sort_custom(func(x, y): return str(x["name"]) < str(y["name"]))
	out.append_array(solos)
	return out


static func candidate(key: String) -> Dictionary:
	for c in candidates():
		if str(c["key"]) == key:
			return c
	return {}


# ======================================================================= weighing an offer
static func strength_of(ids: Array) -> float:
	var pow := 0.0
	for id in ids:
		pow += Expeditions.power(Expeditions.ensure(Adv.get_a(str(id))))
	return pow / maxf(1.0, ids.size()) * (0.8 + 0.4 * (ids.size() - 1))


static func risk_of(ids: Array) -> float:
	var r := 0.0
	for id in ids:
		r += Living.eff_risk(Adv.get_a(str(id)))
	return r / maxf(1.0, ids.size())


## The danger of the site for this party: danger rating against strength (1.0 = an even match).
static func danger_ratio(rid: String, ids: Array) -> float:
	return WorldSites.danger(rid) * float(Expeditions.diff().get("enemy", 1.0)) / maxf(1.0, strength_of(ids))


static func travel_h(rid: String) -> float:
	var tr: Array = Expeditions.region(rid).get("travel_h", [2, 3])
	return (float(tr[0]) + float(tr[1])) / 2.0


## What the party asks for the job (in gold value), and why — fully deterministic.
static func asking(obj: Dictionary, ids: Array) -> Dictionary:
	var rid := str(obj["site"])
	var lead := Adv.get_a(str(ids[0]))
	var dr := danger_ratio(rid, ids)
	var risk := risk_of(ids)
	var steps := route_to(rid, str(obj["node"])).size()
	var base := 12.0 + WorldSites.danger(rid) * 0.45 + travel_h(rid) * 2.0 * 4.0 + steps * 6.0
	base *= 0.7 + 0.3 * ids.size()
	base += float(obj.get("value", 30)) * 0.2
	var m := 1.0
	var notes := []
	# nerve: a cautious party wants paying for danger; the bold shrug
	m *= 1.0 + maxf(0.0, dr - 0.45) * (1.3 - risk)
	# goals (Living)
	var co := Companies.get_c(str(Companies.of(str(ids[0])).get("id", "")))
	for id in ids:
		var a := Adv.get_a(str(id))
		if Living.has_goal(a, "wealth"):
			m *= 1.12
			notes.append("%s wants coin" % a["name"])
		if Living.has_goal(a, "discovery") and (str(obj["kind"]) == "discovery" or int(WorldSites.site(rid).get("visits", 0)) == 0):
			m *= 0.88
			notes.append("%s is curious about it" % a["name"])
		if Living.has_goal(a, "renown") and WorldSites.boss_alive(rid) and dr >= 0.6:
			m *= 0.92
		if Living.has_goal(a, "gear") and str(obj["kind"]) == "salvage":
			m *= 0.92
	# how they regard the smith, and the smith's name in the village
	var aff := Social.aff(str(lead["id"]))
	m *= 1.0 - clampf(aff, -60.0, 80.0) / 400.0
	m *= 1.0 - clampf(Shop.reputation(), -60.0, 60.0) / 300.0
	# a company with a name asks for it
	if not co.is_empty():
		m *= 1.0 + minf(0.3, float(co.get("rep", 0)) / 500.0)
	var ask := int(round(base * m / 5.0)) * 5
	return {"ask": maxi(10, ask), "danger": dr, "risk": risk, "notes": notes}


## How the party values the terms: fee in hand counts fully; a bonus counts by how likely they think success is
## (the bold trust it more); a share counts by the haul's worth (the greedy and coin-seekers like shares).
static func valued(terms: Dictionary, obj: Dictionary, ids: Array, a: Dictionary) -> float:
	var risk := float(a["risk"])
	var p := clampf(1.05 - float(a["danger"]) * 0.5, 0.3, 0.9) * (0.7 + risk * 0.5)
	var share_w := 1.0
	for id in ids:
		var m := Adv.get_a(str(id))
		if Living.has_goal(m, "wealth") or str(m.get("trait", "")) == "greedy":
			share_w = 1.3
	var share_val := 0.0 if str(obj["kind"]) == "discovery" else float(obj.get("value", 30)) * float(terms.get("share", 0)) / 100.0 * share_w
	return float(terms.get("fee", 0)) + float(terms.get("bonus", 0)) * p + share_val


## The party's answer: {verdict: accept|counter|refuse, reason, counter: {fee, bonus, share, site?, node?}, ask, offered}.
static func evaluate(obj: Dictionary, ids: Array, terms: Dictionary, round_no := 1) -> Dictionary:
	var rid := str(obj["site"])
	var lead := Adv.get_a(str(ids[0]))
	var who := str(lead.get("name", "They"))
	if ids.size() > 1 and not Companies.of(str(ids[0])).is_empty():
		who = str(Companies.of(str(ids[0]))["name"])
	# not fit to go: wounds, a broken blade, just back from the road
	for id in ids:
		var a := Expeditions.ensure(Adv.get_a(str(id)))
		var w: Dictionary = a["equipment"].get("weapon", {})
		if bool(w.get("broken", false)):
			return {"verdict": "refuse", "reason": "\"My %s is broken. Mend it first, and then we can talk.\" — %s" % [w.get("name", "blade"), a["name"]], "who": who}
		if float(a["hp"]) < float(a["hp_max"]) * 0.7 or float(a["fatigue"]) >= 40.0:
			return {"verdict": "refuse", "reason": "\"We are still licking our wounds. Ask us again in a day or two.\" — %s" % a["name"], "who": who}
	var strength := strength_of(ids)
	var risk := risk_of(ids)
	if not WorldSites.capable(rid, strength, risk):
		var alt := _safer_site(obj, ids)
		if not alt.is_empty() and round_no <= MAX_COUNTERS:
			var aa := asking(alt, ids)
			return {"verdict": "counter", "who": who, "reason": "\"%s is beyond us — we would not come back. But %s is found at %s, and that we can do.\"" % [WorldSites.name_of(rid),
				_thing(obj), WorldSites.name_of(str(alt["site"]))], "counter": _counter_terms(terms, aa, alt, ids, true), "alt": alt, "ask": int(aa["ask"])}
		return {"verdict": "refuse", "who": who, "reason": "\"%s? Not for any purse. It would kill us.\" (%s is %s for them.)" % [WorldSites.name_of(rid), WorldSites.name_of(rid), "far too dangerous"]}
	var a := asking(obj, ids)
	var offered := valued(terms, obj, ids, a)
	var ratio := offered / maxf(1.0, float(a["ask"]))
	var res := {"who": who, "ask": int(a["ask"]), "offered": int(round(offered)), "ratio": ratio}
	if ratio >= 1.0:
		res["verdict"] = "accept"
		res["reason"] = "\"Done. We leave at first light.\"%s" % ((" (" + str(a["notes"][0]) + ")") if not (a["notes"] as Array).is_empty() else "")
		return res
	if round_no > MAX_COUNTERS:
		if ratio >= 0.95:
			res["verdict"] = "accept"
			res["reason"] = "\"Close enough. We leave at first light.\""
		else:
			res["verdict"] = "refuse"
			res["reason"] = "\"We have named our price twice. Find someone cheaper.\""
		return res
	if ratio < 0.55:
		res["verdict"] = "refuse"
		res["reason"] = "\"For that? %s is %s. Not worth the risk.\"" % [WorldSites.name_of(rid), WorldSites.danger_word(rid)]
		return res
	res["verdict"] = "counter"
	res["counter"] = _counter_terms(terms, a, obj, ids, false)
	var c: Dictionary = res["counter"]
	var asks := []
	if int(c["fee"]) > int(terms.get("fee", 0)):
		asks.append("%d g up front" % int(c["fee"]))
	if int(c["share"]) > int(terms.get("share", 0)):
		asks.append("a %d%% share" % int(c["share"]))
	if int(c["bonus"]) > int(terms.get("bonus", 0)):
		asks.append("%d g when we bring it home" % int(c["bonus"]))
	res["reason"] = "\"%s and %s — make it %s, and we go.\"" % [WorldSites.danger_word(rid).capitalize(), _travel_word(rid), " and ".join(asks) if not asks.is_empty() else "a little more"]
	return res


## Counter terms that meet their price: the cautious want coin up front, coin-seekers a share, the bold a bonus.
static func _counter_terms(terms: Dictionary, a: Dictionary, obj: Dictionary, ids: Array, new_site: bool) -> Dictionary:
	var c := {"fee": int(terms.get("fee", 0)), "bonus": int(terms.get("bonus", 0)), "share": int(terms.get("share", 0))}
	if new_site:
		c["site"] = str(obj["site"])
		c["node"] = str(obj["node"])
	var target := float(a["ask"]) * 1.05
	var greedy := false
	for id in ids:
		var m := Adv.get_a(str(id))
		if Living.has_goal(m, "wealth") or str(m.get("trait", "")) == "greedy":
			greedy = true
	var guard := 0
	while valued(c, obj, ids, a) < target and guard < 200:
		guard += 1
		if greedy and str(obj["kind"]) != "discovery" and int(c["share"]) < 50:
			c["share"] = int(c["share"]) + 5
		elif float(a["risk"]) < 0.5 or int(c["bonus"]) >= int(c["fee"]) * 2 + 40:
			c["fee"] = int(c["fee"]) + 5
		else:
			c["bonus"] = int(c["bonus"]) + 5
	return c


## The same objective at a site the party can manage (a material found elsewhere, or relics/salvage elsewhere).
static func _safer_site(obj: Dictionary, ids: Array) -> Dictionary:
	if str(obj["kind"]) in ["lost", "discovery"]:
		return {}
	var strength := strength_of(ids)
	var risk := risk_of(ids)
	for rid in sites():
		if rid == str(obj["site"]) or not WorldSites.capable(rid, strength, risk):
			continue
		for o in objectives(rid):
			if str(o["kind"]) == str(obj["kind"]) and str(o["def"]) == str(obj["def"]):
				return o
	return {}


static func _thing(obj: Dictionary) -> String:
	match str(obj["kind"]):
		"material":
			return str(DB.item(str(obj["def"])).get("name", obj["def"]))
		"relic":
			return "a relic"
		"salvage":
			return "old arms and armour"
	return "what you want"


static func _travel_word(rid: String) -> String:
	var d := travel_h(rid) * 2.0
	return "%d hours on the road there and back" % int(round(d))


# ======================================================================= negotiation
## The smith makes (or revises) an offer. `party` is a candidate key ("co:<cid>" / "adv:<id>"), `terms`
## {fee, bonus, share}. Returns the answer (see evaluate) plus `round` and, when accepted, `sid`.
static func propose(obj: Dictionary, party: String, terms: Dictionary) -> Dictionary:
	var cand := candidate(party)
	if cand.is_empty():
		return {"verdict": "refuse", "reason": "They are not in town.", "error": true}
	if int(terms.get("fee", 0)) < 0 or int(terms.get("bonus", 0)) < 0 or int(terms.get("share", 0)) < 0 or int(terms.get("share", 0)) > 90:
		return {"verdict": "refuse", "reason": "Those terms make no sense.", "error": true}
	if not Game.can_afford(int(terms.get("fee", 0))):
		return {"verdict": "refuse", "reason": "You cannot pay %d g up front." % int(terms.get("fee", 0)), "error": true}
	var t := talk()
	var same := not t.is_empty() and str(t.get("party", "")) == party and str(t.get("obj", {}).get("kind", "")) == str(obj["kind"]) \
		and str(t.get("obj", {}).get("def", "")) == str(obj["def"]) and int(t.get("obj", {}).get("uid", -1)) == int(obj["uid"])
	var rnd := int(t.get("round", 0)) + 1 if same else 1
	var ans := evaluate(obj, cand["members"], terms, rnd)
	ans["round"] = rnd
	st()["talk"] = {"obj": obj.duplicate(true), "party": party, "terms": terms.duplicate(), "round": rnd, "answer": ans.duplicate(true)}
	if str(ans["verdict"]) == "accept":
		ans["sid"] = _contract(obj, cand, terms)
		st()["talk"] = {}
	elif str(ans["verdict"]) == "refuse":
		st()["talk"] = {}
	Events.expeditions_changed.emit()
	return ans


## The smith agrees to the party's counter-offer. Returns "" or why not.
static func agree() -> String:
	var t := talk()
	if t.is_empty() or str(t.get("answer", {}).get("verdict", "")) != "counter":
		return "There is no offer on the table."
	var cand := candidate(str(t["party"]))
	if cand.is_empty():
		st()["talk"] = {}
		return "They are no longer in town."
	var c: Dictionary = t["answer"]["counter"]
	var obj: Dictionary = t["answer"].get("alt", t["obj"]) if c.has("site") else t["obj"]
	var terms := {"fee": int(c["fee"]), "bonus": int(c["bonus"]), "share": int(c["share"])}
	if not Game.can_afford(int(terms["fee"])):
		return "You cannot pay %d g up front." % int(terms["fee"])
	_contract(obj, cand, terms)
	st()["talk"] = {}
	Events.expeditions_changed.emit()
	return ""


static func walk_away() -> void:
	st()["talk"] = {}
	Events.expeditions_changed.emit()


## A contract: the fee goes into escrow (it reaches the party when they leave), the party is formed for the
## next 08:00 departure through the ordinary Expeditions rhythm. Returns the sponsorship id.
static func _contract(obj: Dictionary, cand: Dictionary, terms: Dictionary) -> String:
	var s := st()
	var sid := "sp_%d" % int(s["next"])
	s["next"] = int(s["next"]) + 1
	var ids: Array = (cand["members"] as Array).duplicate()
	var fee := int(terms.get("fee", 0))
	if fee > 0:
		Game.add_gold(-fee, "sponsor", "Fee held for %s (sponsored expedition)" % str(cand["name"]))
	var rec := {"id": sid, "day": Game.day(), "t": Game.now(), "objective": obj.duplicate(true), "party": ids, "leader": str(ids[0]),
		"company": str(cand.get("company", "")), "who": str(cand["name"]), "terms": {"fee": fee, "bonus": int(terms.get("bonus", 0)), "share": int(terms.get("share", 0))},
		"status": "contracted", "escrow": fee, "paid": {}, "exp": "", "pid": "", "outcome": "", "result": {}, "lore": "", "reached": false, "searched": false}
	s["list"][sid] = rec
	# the party, formed now; it prepares at 07:00 and leaves at 08:00 with the others (Expeditions)
	var pid := "party_%d" % Game.new_uid()
	Expeditions.st()["parties"][pid] = {"id": pid, "members": ids.duplicate(), "leader": str(ids[0]), "dest": str(obj["site"]), "goal": "sponsored",
		"formed": Game.now(), "table": 5, "company": str(cand.get("company", "")), "why": "sponsored by the smith: %s" % objective_text(obj), "sponsor": sid}
	rec["pid"] = pid
	for id in ids:
		Adv.get_a(str(id))["activity"] = "preparing"
	var text := "The smith sponsored %s to go to %s for %s (%s)." % [str(cand["name"]), WorldSites.name_of(str(obj["site"])), objective_text(obj), terms_text(rec["terms"])]
	Chronicle.add("sponsor", text, {"party": ids, "adv": str(ids[0]), "place": str(obj["site"]), "sponsor": sid}, true)
	Events.toast.emit("%s accepted: %s." % [str(cand["name"]), objective_text(obj)], "good")
	return sid


## Before they leave the smith may call it off: the fee comes back in full, the party disbands.
static func cancel(sid: String, why := "") -> String:
	var sp := get_s(sid)
	if sp.is_empty() or str(sp["status"]) != "contracted":
		return "It cannot be called off now."
	_refund(sp)
	Expeditions.st()["parties"].erase(str(sp["pid"]))
	for id in sp["party"]:
		var a := Adv.get_a(str(id))
		if str(a.get("activity", "")) in ["preparing", "recruiting"]:
			a["activity"] = "at_inn"
	sp["status"] = "cancelled"
	sp["outcome"] = "cancelled"
	sp["result"] = {"text": why if why != "" else "Called off before they left; the fee was returned."}
	Chronicle.add("sponsor", "The sponsored expedition of %s to %s was called off%s." % [sp["who"], WorldSites.name_of(str(sp["objective"]["site"])), (" — " + why) if why != "" else ""],
		{"party": sp["party"], "sponsor": sid})
	Events.expeditions_changed.emit()
	return ""


static func _refund(sp: Dictionary) -> void:
	var fee := int(sp.get("escrow", 0))
	if fee > 0:
		Game.add_gold(fee, "sponsor", "Fee returned by %s" % sp["who"])
	sp["escrow"] = 0


# ======================================================================= the expedition hooks
## Expeditions.depart_parties could not send the party (someone hurt, retired or gone): void it, refund.
static func on_abort(p: Dictionary) -> void:
	var sp := get_s(str(p.get("sponsor", "")))
	if sp.is_empty() or str(sp["status"]) != "contracted":
		return
	sp["pid"] = str(p.get("id", ""))
	cancel(str(sp["id"]), "not everyone could leave")


## Expeditions.start: the party set out. The escrowed fee is handed over now.
static func on_depart(e: Dictionary) -> void:
	var sp := get_s(str(e.get("sponsor", "")))
	if sp.is_empty():
		return
	sp["status"] = "under_way"
	sp["exp"] = str(e["id"])
	sp["depart"] = Game.now()
	var fee := int(sp.get("escrow", 0))
	var ids: Array = e["party"]
	for i in ids.size():
		var part := fee / ids.size() + (1 if i < fee % ids.size() else 0)
		var a := Adv.get_a(str(ids[i]))
		a["gold"] = int(a.get("gold", 0)) + part
		sp["paid"][str(ids[i])] = int(sp["paid"].get(str(ids[i]), 0)) + part
	sp["escrow"] = 0
	Expeditions._j(e, "Sponsored by the smith: %s (%s)." % [objective_text(sp["objective"]), terms_text(sp["terms"])], "depart")
	Events.expeditions_changed.emit()


## Called when the party has resolved a node: at the objective's node they search for it (or survey).
## Returns extra game minutes spent.
static func on_node(e: Dictionary, n: Dictionary) -> int:
	var sp := get_s(str(e.get("sponsor", "")))
	if sp.is_empty() or str(n.get("id", "")) != str(sp["objective"]["node"]) or bool(sp.get("searched", false)):
		return 0
	var standing: Array = Expeditions._standing(e)
	if standing.is_empty():
		return 0
	sp["reached"] = true
	sp["searched"] = true
	var obj: Dictionary = sp["objective"]
	var rid := str(e["dest"])
	var tier := int(n.get("tier", 1))
	match str(obj["kind"]):
		"lost":
			if _have_lost(e, int(obj["uid"])):
				Expeditions._j(e, "Found what the smith sent them for: %s." % _lost_name(obj), "discovery")
			else:
				sp["note"] = "It was no longer where it fell."
				Expeditions._j(e, "Searched %s for %s — nothing. Someone came here first." % [n.get("name", ""), _lost_name(obj)], "fail")
			return 20
		"discovery":
			var sc := Expeditions._best(e, "scouting")
			if sc.is_empty():
				sc = Adv.get_a(str(standing[0]))
			var r := Expeditions._check(sc, "wis", 11 + tier, "scouting")
			sp["check"] = r["txt"]
			if r["ok"]:
				var found := ""
				if not _undiscovered_near(rid).is_empty():
					found = WorldSites.try_discover(e, 1.0)
				if found != "":
					sp["found_site"] = found
				else:
					Regions.add_scouting(rid, 6.0, "surveyed for the smith")
					sp["info"] = WorldSites.conditions(rid)
					Expeditions._j(e, "%s surveyed %s from %s for the smith (%s)." % [sc["name"], WorldSites.name_of(rid), n.get("name", ""), r["txt"]], "scout")
			else:
				Regions.add_scouting(rid, 2.0)
				Expeditions._j(e, "%s searched the land beyond %s but found no way on (%s)." % [sc["name"], n.get("name", ""), r["txt"]], "fail")
			return 45
	# material, relic, salvage: the place must be theirs to search
	if str(n.get("kind", "")) in ["encounter", "boss"] and not WorldSites.enemies_at(rid, n).is_empty() and not _won_at(e, str(n["id"])):
		sp["note"] = "The foes at %s still held it." % n.get("name", "")
		Expeditions._j(e, "The foes still hold %s — no chance to search for the smith's %s." % [n.get("name", ""), _thing(obj).to_lower()], "fail")
		return 0
	if str(n.get("kind", "")) == "puzzle":
		if _wanted(e, obj).is_empty():
			sp["note"] = "The door stayed shut."
		return 0
	var rich := WorldSites.resource(rid, str(n["id"]))
	if rich < 0.1:
		sp["note"] = "%s had been picked bare." % n.get("name", "")
		Expeditions._j(e, "%s has been picked bare — nothing left of what the smith wanted." % n.get("name", ""), "fail")
		return 20
	var skill: String = {"resource": "survival", "chest": "locks", "trap": "traps"}.get(str(n.get("kind", "")), "scouting")
	var at: String = {"survival": "wis", "locks": "dex", "traps": "dex"}.get(skill, "wis")
	var who := Expeditions._best(e, skill)
	if who.is_empty():
		who = Adv.get_a(str(standing[0]))
	var dc := 10 + tier * 2 + (3 if str(obj["kind"]) == "material" and float(obj.get("share", 0.1)) < 0.03 else (1 if float(obj.get("share", 0.1)) < 0.08 else 0))
	var chk := Expeditions._check(who, at, dc, skill)
	sp["check"] = chk["txt"]
	if not chk["ok"]:
		Expeditions._j(e, "%s searched %s for the smith's %s and came up empty (%s)." % [who["name"], n.get("name", ""), _thing(obj).to_lower(), chk["txt"]], "fail")
		return 30
	var got := []
	match str(obj["kind"]):
		"material":
			var want := int(obj.get("qty", 1))
			var q := maxi(1, int(round(float(want) * clampf(rich + 0.3, 0.3, 1.0)))) + (1 if int(chk["total"]) >= dc + 6 else 0)
			got.append(Items.make(str(obj["def"]), {"qty": q, "quality": randf_range(60.0, 95.0)}))
		"relic":
			var rel := _relic_defs(str(n.get("loot", "")))
			if not rel.is_empty():
				got.append(Items.make(str(rel[randi() % rel.size()])))
		"salvage":
			got.append(Loot.random_equipment("any", float(tier - 1) * 8.0))
	# a careful search takes its own toll on the place (WorldSites depletion)
	if WorldSites.site(rid)["resources"].has(str(n["id"])):
		WorldSites.site(rid)["resources"][str(n["id"])] = maxf(0.0, rich - 0.2)
	for it in got:
		it["found"] = {"day": Game.day(), "where": WorldSites.name_of(rid), "exp": e["id"]}
		e["loot"].append(it)
	Expeditions._j(e, "%s found the smith's %s at %s (%s): %s." % [who["name"], _thing(obj).to_lower(), n.get("name", ""), chk["txt"],
		", ".join(got.map(func(x): return Items.display_name(x)))], "loot")
	return 40


static func _won_at(e: Dictionary, nid: String) -> bool:
	for i in range((e["encounters"] as Array).size() - 1, -1, -1):
		var rec: Dictionary = e["encounters"][i]
		if str(rec.get("node", "")) == nid and str(rec.get("kind", "")) == "combat":
			return str(rec.get("outcome", "")) == "victory"
	return false


static func _relic_defs(table: String) -> Array:
	var out := []
	for en in DB.loot.get(table, {}).get("entries", []):
		if str(en[0]).begins_with("relic") and not DB.item(str(en[0])).is_empty():
			out.append(str(en[0]))
	if out.is_empty():
		out = ["relic_unknown_tablet", "relic_unknown_reliquary", "relic_unknown_arms"]
	return out


static func _have_lost(e: Dictionary, uid: int) -> bool:
	for it in e["loot"]:
		if int(it.get("uid", -1)) == uid:
			return true
	return false


static func _lost_name(obj: Dictionary) -> String:
	return str(obj["name"]).get_slice(" (", 0)


## The objective items in the party's pack.
static func _wanted(e: Dictionary, obj: Dictionary) -> Array:
	var out := []
	for it in e["loot"]:
		match str(obj["kind"]):
			"material":
				if str(it.get("def", "")) == str(obj["def"]):
					out.append(it)
			"relic":
				if str(it.get("def", "")).begins_with("relic"):
					out.append(it)
			"salvage":
				if Items.is_equipment(it) and not it.has("_site_found"):
					out.append(it)
			"lost":
				if int(it.get("uid", -1)) == int(obj["uid"]):
					out.append(it)
	return out


## Expeditions.finish (before the loot is shared): the objective's result, the share, the bonus, delivery to
## the returns shelf, and the one Lore event.
static func on_finish(e: Dictionary, alive: Array) -> void:
	var sp := get_s(str(e.get("sponsor", "")))
	if sp.is_empty() or str(sp["status"]) != "under_way":
		return
	var obj: Dictionary = sp["objective"]
	var rid := str(obj["site"])
	var share := int(sp["terms"]["share"])
	var outcome := "failure"
	var deliver := []
	var coin_share := 0
	var kept := []
	match str(obj["kind"]):
		"discovery":
			if sp.has("found_site") or sp.has("info"):
				outcome = "success"
			elif bool(sp.get("reached", false)):
				outcome = "partial"
		_:
			var items := _wanted(e, obj)
			for it in items:
				e["loot"].erase(it)
			if str(obj["kind"]) == "material":
				var total := 0
				for it in items:
					total += int(it.get("qty", 1))
				if total > 0:
					var theirs := int(floor(total * share / 100.0))
					var mine := total - theirs
					if mine > 0:
						deliver.append(Items.make(str(obj["def"]), {"qty": mine, "quality": float(items[0].get("quality", 75.0))}))
					if theirs > 0:
						kept.append(Items.make(str(obj["def"]), {"qty": theirs, "quality": float(items[0].get("quality", 75.0))}))
					outcome = "success" if total >= int(obj.get("qty", 1)) else "partial"
			elif str(obj["kind"]) == "salvage" and items.size() > 1:
				items.sort_custom(func(a, b): return Items.score(a) > Items.score(b))
				var keep_n := int(floor(items.size() * share / 100.0))
				kept.append_array(items.slice(0, keep_n))
				deliver.append_array(items.slice(keep_n))
				outcome = "success"
			elif not items.is_empty():
				deliver.append_array(items)
				outcome = "success"
				for it in items:
					coin_share += int(round(Items.value(it) * share / 100.0))
			# a partial success: they reached the place and brought back something else of note
			if outcome == "failure" and bool(sp.get("reached", false)) and str(obj["kind"]) != "lost":
				outcome = "partial" if not (e["loot"] as Array).is_empty() else "failure"
	# what the party keeps goes back into their pack (shared or offered at the counter as usual)
	for it in kept:
		it["found"] = {"day": Game.day(), "where": WorldSites.name_of(rid), "exp": e["id"]}
		e["loot"].append(it)
	if alive.is_empty():
		outcome = "lost"
		deliver.clear()
	# delivery: one container on the returns shelf; recovered gear keeps its identity
	var lead_name := str(Adv.get_a(str(alive[0])).get("name", sp["who"])) if not alive.is_empty() else str(sp["who"])
	for it in deliver:
		it.erase("_site_found")
		if Provenance.applies(it):
			var how := "recovered" if str(obj["kind"]) == "lost" else "given"
			Provenance.transfer(it, "smith", how, rid, "%s brought %s home from %s for the smith, as agreed." % [lead_name, Items.display_name(it), WorldSites.name_of(rid)])
		it["owner"] = "smith"
	if not deliver.is_empty():
		var cdef: String = {"lost": "chest_recovered", "salvage": "chest_recovered", "relic": "satchel_relic"}.get(str(obj["kind"]), "bag_traveller")
		Game.state["returns"].append(Loot.make_container(cdef, deliver, lead_name, "%s: \"As agreed — %s from %s.\"" % [lead_name, objective_text(obj), WorldSites.name_of(rid)]))
		Events.inventory_changed.emit()
	# money: the bonus on success (half on a partial), the share of a single piece in coin
	var bonus := int(sp["terms"]["bonus"])
	var owed := (bonus if outcome == "success" else (bonus / 2 if outcome == "partial" else 0)) + coin_share
	var paid := 0
	if owed > 0 and not alive.is_empty():
		paid = mini(owed, maxi(0, Game.gold()))
		if paid > 0:
			Game.add_gold(-paid, "sponsor", "Paid %s for the sponsored expedition" % sp["who"])
			for i in alive.size():
				var part := paid / alive.size() + (1 if i < paid % alive.size() else 0)
				var a := Adv.get_a(str(alive[i]))
				a["gold"] = int(a.get("gold", 0)) + part
				sp["paid"][str(alive[i])] = int(sp["paid"].get(str(alive[i]), 0)) + part
		if paid < owed:
			Social.change(str(alive[0]), -6.0, 1.0, "sponsor_owed_" + str(sp["id"]), "The smith still owes us %d g for %s." % [owed - paid, WorldSites.name_of(rid)])
			Shop.rep_change(-2.0, "the smith did not pay a sponsored company in full")
	elif outcome == "success" and not alive.is_empty():
		Social.change(str(alive[0]), 2.0, 2.0)
	_conclude(sp, e, outcome, deliver, paid, owed)


## Expeditions._wipe: nobody came back.
static func on_wipe(e: Dictionary) -> void:
	var sp := get_s(str(e.get("sponsor", "")))
	if sp.is_empty() or str(sp["status"]) != "under_way":
		return
	_conclude(sp, e, "lost", [], 0, 0)


static func _conclude(sp: Dictionary, e: Dictionary, outcome: String, deliver: Array, paid: int, owed: int) -> void:
	var obj: Dictionary = sp["objective"]
	var rid := str(obj["site"])
	sp["status"] = "done"
	sp["outcome"] = outcome
	sp["end"] = Game.now()
	var names := Expeditions._and((sp["party"] as Array).map(func(i): return str(Adv.get_a(str(i)).get("name", i))))
	var what := ""
	match outcome:
		"success":
			what = "brought it home" if str(obj["kind"]) == "lost" else "brought home %s" % (", ".join(deliver.map(func(x): return Items.display_name(x))) if not deliver.is_empty() else _discovery_word(sp))
		"partial":
			what = "brought home only part of it%s" % ((" — " + ", ".join(deliver.map(func(x): return Items.display_name(x)))) if not deliver.is_empty() else (" — " + str(sp.get("note", "they reached the place, but no more"))))
		"failure":
			what = "came back without it%s" % ((" — " + str(sp["note"]).to_lower().trim_suffix(".")) if str(sp.get("note", "")) != "" else (" — they never reached %s" % Expeditions.node_of(rid, str(obj["node"])).get("name", "the place")))
		"lost":
			what = "did not come back"
	var dead: Array = (sp["party"] as Array).filter(func(i): return str(Adv.get_a(str(i)).get("status", "")) == "dead")
	var text := "Sponsored by the smith, %s went to %s for %s and %s.%s%s" % [names, WorldSites.name_of(rid), objective_text(obj), what,
		(" %s fell." % Expeditions._and(dead.map(func(i): return str(Adv.get_a(str(i))["name"])))) if not dead.is_empty() and outcome != "lost" else "",
		(" Paid %d g on return%s." % [paid, (" (%d g still owed)" % (owed - paid)) if owed > paid else ""]) if paid > 0 or owed > 0 else ""]
	sp["result"] = {"text": text, "items": deliver.map(func(x): return int(x.get("uid", -1))), "names": deliver.map(func(x): return Items.display_name(x)), "paid": paid, "owed": maxi(0, owed - paid),
		"site": str(sp.get("found_site", ""))}
	sp["lore"] = Lore.record("sponsored", text, {"actors": (sp["party"] as Array).duplicate(), "items": deliver, "place": rid, "importance": 2, "chronicle": true,
		"notable": true, "icon": "icons/recipe_scroll", "data": {"sponsor": sp["id"], "outcome": outcome, "kind": obj["kind"], "exp": str(e.get("id", "")), "terms": sp["terms"].duplicate()}})
	Events.toast.emit("%s — %s." % [OUTCOME_WORD.get(outcome, outcome), text.get_slice(".", 0)], "good" if outcome == "success" else ("info" if outcome == "partial" else "bad"))
	Events.expeditions_changed.emit()


static func _discovery_word(sp: Dictionary) -> String:
	if str(sp.get("found_site", "")) != "":
		return "the way to %s" % WorldSites.name_of(str(sp["found_site"]))
	return "news of the site"


# ======================================================================= presentation
static func objective_text(obj: Dictionary) -> String:
	match str(obj.get("kind", "")):
		"lost":
			return "the lost %s" % _lost_name(obj)
		"discovery":
			return ("a way beyond %s" if str(obj["name"]).begins_with("Scout") else "news of %s") % WorldSites.name_of(str(obj["site"]))
		"relic":
			return "a relic from %s" % Expeditions.node_of(str(obj["site"]), str(obj["node"])).get("name", "the site")
		"salvage":
			return "salvaged arms and armour from %s" % Expeditions.node_of(str(obj["site"]), str(obj["node"])).get("name", "the site")
	return str(obj.get("name", ""))


static func terms_text(t: Dictionary) -> String:
	var parts := []
	if int(t.get("fee", 0)) > 0:
		parts.append("%d g up front" % int(t["fee"]))
	if int(t.get("bonus", 0)) > 0:
		parts.append("%d g on success" % int(t["bonus"]))
	if int(t.get("share", 0)) > 0:
		parts.append("%d%% share" % int(t["share"]))
	return ", ".join(parts) if not parts.is_empty() else "no pay"


## Rough game minute when the party should be home (for the ETA line).
static func eta(sp: Dictionary) -> int:
	var rid := str(sp["objective"]["site"])
	var tr := int(travel_h(rid) * 60.0)
	var steps := route_to(rid, str(sp["objective"]["node"])).size()
	match str(sp["status"]):
		"contracted":
			var d := Game.day() + (1 if Game.hour() >= 8 else 0)
			return (d - 1) * 1440 + 8 * 60 + tr * 2 + steps * 100
		"under_way":
			var e := Expeditions.get_exp(str(sp["exp"]))
			if e.is_empty():
				return Game.now()
			if str(e["phase"]) == "travel_back":
				return int(e["leg"]["t1"])
			var left := maxi(0, (e["route"] as Array).size() - int(e["step"]))
			return maxi(Game.now(), int(e["next_at"])) + left * 100 + tr
	return int(sp.get("end", Game.now()))


static func when_text(m: int) -> String:
	var d := int(m / 1440) + 1
	var hh := int((m % 1440) / 60)
	if d == Game.day():
		return "today around %02d:00" % hh
	if d == Game.day() + 1:
		return "tomorrow around %02d:00" % hh
	return "day %d around %02d:00" % [d, hh]


## One line for lists: objective, party, terms, status / ETA / result.
static func line(sp: Dictionary) -> String:
	var obj: Dictionary = sp["objective"]
	var ot := objective_text(obj)
	var head := "[b]%s[/b] — %s · %s" % [ot.left(1).to_upper() + ot.substr(1), WorldSites.name_of(str(obj["site"])), sp["who"]]
	var tail := ""
	match str(sp["status"]):
		"contracted":
			tail = "Preparing, leaves at 08:00 · back %s" % when_text(eta(sp))
		"under_way":
			var e := Expeditions.get_exp(str(sp["exp"]))
			var ph: String = {"travel_out": "on the road out", "moving": "on the move", "acting": "at a point of interest", "travel_back": "returning home"}.get(str(e.get("phase", "")), "under way")
			tail = "Under way — %s%s · back %s" % [ph, " · objective reached" if bool(sp.get("reached", false)) else "", when_text(eta(sp))]
		"done":
			tail = "%s — %s" % [OUTCOME_WORD.get(str(sp["outcome"]), sp["outcome"]), ", ".join(sp["result"].get("names", [])) if not (sp["result"].get("names", []) as Array).is_empty() else str(sp.get("note", sp["result"].get("site", "")))]
		"cancelled":
			tail = "Called off — fee returned"
	return "%s\n[i]%s[/i] · %s" % [head, terms_text(sp["terms"]), tail]


## The source hook for the guide (Guide.sources): "sponsor a company to <site>".
static func source_sites(def: String) -> Array:
	var out := []
	for rid in sites():
		for o in objectives(rid):
			if str(o["kind"]) == "material" and str(o["def"]) == def:
				out.append(rid)
				break
	return out


static func anyone_in_town() -> bool:
	return not candidates().is_empty()
