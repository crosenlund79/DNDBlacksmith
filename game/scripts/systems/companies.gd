## Companies — persistent named parties of adventurers (The Living Realm, milestone 3a).
## EN: A company has a name, a leader, members, former members (and why they left), a reputation, a record of
##     trips, wins, losses and its current losing streak, and a shared history: the Lore ids of its own events
##     (formed, joined, lost a member, new leader, disbanded) and of what its members did on its expeditions.
##     Companies usually adventure together: Expeditions.form_parties asks plan_parties() first, so a company
##     whose members are rested sets out as one party (topped up with a pick-up companion when small); the
##     rest still form solo and pick-up parties. Companies recruit replacements, lose members (death,
##     retirement, quarrels), change leaders and disband for credible reasons (too few left, the leader gone,
##     a long losing streak). New games start with one or two seeded companies; old saves form them gradually
##     from adventurers who are friends and have shared the road.
##     State: Game.state.companies = {list: {cid: company}, next}; each adventurer carries `company` (cid or "").
## DA: Navngivne, vedvarende kompagnier: medlemmer, leder, omdømme, fælles historie; de rejser sammen.
class_name Companies
extends RefCounted

const MAX_SIZE := 4
const STREAK_LIMIT := 4      # losing trips in a row before a company breaks up
const SHORT_DAYS := 5        # days a company may stand at one member before it disbands
const ADJ := ["Ember", "Grey", "Iron", "Lantern", "Ashen", "Silver", "Barrow", "Thorn", "Hollow", "Wyvern", "Crimson", "Oaken",
	"Raven", "Salt", "Winter", "Gilded", "Black", "Last"]
const NOUN := ["Lanterns", "Harts", "Oaths", "Wardens", "Blades", "Cloaks", "Hounds", "Shields", "Wolves", "Candles", "Banners", "Keys",
	"Pilgrims", "Spears", "Crows", "Anvils"]
const PATTERNS := ["The %s %s", "Company of the %s %s", "The %s %s of Brindlewick"]


# ======================================================================= state
static func st() -> Dictionary:
	if not Game.state.has("companies"):
		Game.state["companies"] = {"list": {}, "next": 1}
	return Game.state["companies"]


static func list_all() -> Array:
	return st()["list"].values()


static func active() -> Array:
	var out := list_all().filter(func(c): return str(c.get("status", "")) == "active")
	out.sort_custom(func(x, y): return int(x.get("rep", 0)) > int(y.get("rep", 0)) or (int(x.get("rep", 0)) == int(y.get("rep", 0)) and str(x["id"]) < str(y["id"])))
	return out


static func get_c(cid: String) -> Dictionary:
	return st()["list"].get(cid, {})


## The active company this adventurer belongs to ({} if none).
static func of(adv_id: String) -> Dictionary:
	var a := Adv.get_a(adv_id)
	var c := get_c(str(a.get("company", "")))
	if not c.is_empty() and str(c.get("status", "")) == "active" and (c["members"] as Array).has(adv_id):
		return c
	return {}


static func name_of(adv_id: String) -> String:
	return str(of(adv_id).get("name", ""))


static func make_name(r: RandomNumberGenerator) -> String:
	var used := list_all().map(func(c): return str(c["name"]))
	for i in 20:
		var n: String = PATTERNS[r.randi() % PATTERNS.size()] % [ADJ[r.randi() % ADJ.size()], NOUN[r.randi() % NOUN.size()]]
		if not used.has(n):
			return n
	return "The Company of %d" % int(st()["next"])


static func rep_word(c: Dictionary) -> String:
	var r := int(c.get("rep", 0))
	if r < 10:
		return "little known"
	if r < 35:
		return "known in the village"
	if r < 80:
		return "well regarded"
	if r < 150:
		return "famous in the valley"
	return "legendary"


## "The Ember Lanterns (leader Sigrun Halvard; Garrick Stone, Brother Tomas)".
static func summary(c: Dictionary) -> String:
	var others: Array = (c["members"] as Array).filter(func(i): return str(i) != str(c["leader"])).map(func(i): return str(Adv.get_a(str(i)).get("name", i)))
	return "%s (led by %s%s)" % [c["name"], Adv.get_a(str(c["leader"])).get("name", "?"), ("; " + ", ".join(others)) if not others.is_empty() else ""]


static func _names(ids: Array) -> String:
	return Expeditions._and(ids.map(func(i): return str(Adv.get_a(str(i)).get("name", i))))


## One Lore event for a company happening (actors = the adventurers involved), kept in the company's history.
static func _event(c: Dictionary, what: String, text: String, actors: Array, importance := 1) -> String:
	var ev := Lore.record("company", text, {"actors": actors, "importance": importance, "chronicle": true, "notable": importance >= 2,
		"place": "brindlewick", "data": {"company": c["id"], "what": what}})
	(c["lore"] as Array).append(ev)
	return ev


# ======================================================================= life of a company
## Founds a company. `r` names it (seeded), defaulting to the world seed and the company counter.
static func found(ids: Array, leader: String, why := "", r: RandomNumberGenerator = null) -> Dictionary:
	var s := st()
	var cid := "co_%d" % int(s["next"])
	s["next"] = int(s["next"]) + 1
	if r == null:
		r = Living.rng_for("company_" + cid)
	var c := {"id": cid, "name": make_name(r), "founded": Game.day(), "leader": leader, "members": ids.duplicate(), "former": [],
		"rep": 0, "trips": 0, "wins": 0, "losses": 0, "streak": 0, "lore": [], "status": "active", "why": why, "short_since": -1}
	for id in ids:
		var a := Adv.get_a(str(id))
		c["rep"] = int(c["rep"]) + int(a.get("renown", 0)) / 4
		a["company"] = cid
	s["list"][cid] = c
	_event(c, "formed", "%s founded %s%s." % [_names(ids), c["name"], (" — " + why) if why != "" else ""], ids, 2)
	Events.adventurers_changed.emit()
	return c


static func join(cid: String, adv_id: String, why := "") -> void:
	var c := get_c(cid)
	var a := Adv.get_a(adv_id)
	if c.is_empty() or a.is_empty() or (c["members"] as Array).has(adv_id):
		return
	var prev := of(adv_id)
	if not prev.is_empty():
		leave(str(prev["id"]), adv_id, "left to join " + str(c["name"]))
	(c["members"] as Array).append(adv_id)
	a["company"] = cid
	c["short_since"] = -1
	_event(c, "joined", "%s joined %s%s." % [a["name"], c["name"], (" — " + why) if why != "" else ""], [adv_id, c["leader"]])
	for m in c["members"]:
		if str(m) != adv_id:
			Living.relate(str(m), adv_id, 6.0, "sworn into %s" % c["name"])


## A member leaves (`why` in words). Picks a new leader or disbands when the company can no longer stand.
static func leave(cid: String, adv_id: String, why: String, ev := "") -> void:
	var c := get_c(cid)
	if c.is_empty() or not (c["members"] as Array).has(adv_id):
		return
	(c["members"] as Array).erase(adv_id)
	(c["former"] as Array).append({"id": adv_id, "day": Game.day(), "why": why})
	var a := Adv.get_a(adv_id)
	if str(a.get("company", "")) == cid:
		a["company"] = ""
	a["left_company_day"] = Game.day()
	var nm := str(a.get("name", adv_id))
	if ev != "":
		(c["lore"] as Array).append(ev)   # the death / retirement itself is the member's own Lore event
	_event(c, "lost", "%s lost %s: %s." % [c["name"], nm, why], [adv_id] + (c["members"] as Array))
	if str(c["status"]) != "active":
		return
	if (c["members"] as Array).is_empty():
		disband(cid, "no one is left")
		return
	if str(c["leader"]) == adv_id:
		if (c["members"] as Array).size() >= 2 and randf() < 0.65:
			var nl := _best_leader(c["members"])
			c["leader"] = nl
			_event(c, "leader", "%s now leads %s." % [Adv.get_a(nl).get("name", nl), c["name"]], [nl])
		else:
			disband(cid, "without %s it lost its heart" % nm)
			return
	if (c["members"] as Array).size() < 2 and int(c.get("short_since", -1)) < 0:
		c["short_since"] = Game.day()


static func _best_leader(ids: Array) -> String:
	var best := ""
	var bv := -1.0
	for id in ids:
		var a := Adv.get_a(str(id))
		var v := float(a.get("renown", 0)) + int(a.get("level", 1)) * 10.0
		if v > bv:
			bv = v
			best = str(id)
	return best


static func disband(cid: String, why: String) -> void:
	var c := get_c(cid)
	if c.is_empty() or str(c["status"]) != "active":
		return
	c["status"] = "disbanded"
	c["ended"] = Game.day()
	c["end_why"] = why
	var was: Array = (c["members"] as Array).duplicate()
	for id in was:
		var a := Adv.get_a(str(id))
		if str(a.get("company", "")) == cid:
			a["company"] = ""
		(c["former"] as Array).append({"id": str(id), "day": Game.day(), "why": "the company broke up"})
	c["members"] = []
	_event(c, "disbanded", "%s disbanded: %s." % [c["name"], why], was if not was.is_empty() else [c["leader"]], 2)
	Events.adventurers_changed.emit()


## A member died, retired or left Brindlewick (called by Living.retire, Expeditions, the daily check).
static func on_member_left(adv_id: String, how: String, ev := "") -> void:
	var c := of(adv_id)
	if c.is_empty():
		return
	var why: String = {"died": "fell on the road", "retired": "retired from the road", "left": "left Brindlewick"}.get(how, how)
	leave(str(c["id"]), adv_id, why, ev)


# ======================================================================= the daily round
## New game: one or two companies from the seeded friendships (Mira keeps to her own errand at first).
static func seed_start(r: RandomNumberGenerator) -> void:
	var ids: Array = Adv.all().keys().filter(func(i): return str(i) != "mira")
	ids.sort()
	var pairs := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var v := Expeditions.relation(Adv.get_a(ids[i]), ids[j])
			if v >= 25.0:
				pairs.append([ids[i], ids[j], v])
	pairs.sort_custom(func(x, y): return float(x[2]) > float(y[2]) or (float(x[2]) == float(y[2]) and str(x[0]) + str(x[1]) < str(y[0]) + str(y[1])))
	var want := r.randi_range(1, 2)
	var used := []
	var made := 0
	var start := r.randi() % maxi(1, mini(3, pairs.size()))   # the seed decides which friendship founds the first company
	for k in pairs.size():
		var p: Array = pairs[(start + k) % pairs.size()]
		if made >= want:
			break
		if used.has(p[0]) or used.has(p[1]):
			continue
		var members := [str(p[0]), str(p[1])]
		for id in ids:
			if members.size() >= 3 or used.has(id) or members.has(id):
				continue
			if Expeditions.relation(Adv.get_a(id), members[0]) >= 15.0 and Expeditions.relation(Adv.get_a(id), members[1]) >= 0.0 and r.randf() < 0.7:
				members.append(str(id))
		used.append_array(members)
		found(members, _best_leader(members), "old friends who came to Brindlewick together", r)
		made += 1


## Daily: members lost to death or departure are struck off, quarrels split companies, short companies
## recruit or disband, and friends who have shared the road found new companies (old saves too).
static func daily() -> void:
	for c in active():
		var cid: String = c["id"]
		# the fallen and the departed (deaths revealed later, retirements elsewhere)
		for id in (c["members"] as Array).duplicate():
			var a := Adv.get_a(str(id))
			var s := str(a.get("status", "dead"))
			if s == "dead":
				leave(cid, str(id), "fell on the road")
			elif s in ["retired", "gone"]:
				leave(cid, str(id), "retired from the road" if s == "retired" else "left Brindlewick")
		if str(c["status"]) != "active":
			continue
		_quarrels(c)
		if str(c["status"]) != "active":
			continue
		if (c["members"] as Array).size() < 3:
			recruit(c)
		if (c["members"] as Array).size() < 2:
			if int(c.get("short_since", -1)) < 0:
				c["short_since"] = Game.day()
			elif Game.day() - int(c["short_since"]) >= SHORT_DAYS:
				disband(cid, "too few were left to call it a company")
	_formations()


## Rivals inside one company: the one with less standing walks out.
static func _quarrels(c: Dictionary) -> void:
	var ms: Array = c["members"]
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			var x := Adv.get_a(str(ms[i]))
			var y := Adv.get_a(str(ms[j]))
			if x.is_empty() or y.is_empty() or Expeditions.relation(x, str(ms[j])) > Living.BOND_AT["rival"]:
				continue
			if not str(x.get("status", "")) in ["in_town", "injured"] or not str(y.get("status", "")) in ["in_town", "injured"]:
				continue
			var goer := y if str(ms[i]) == str(c["leader"]) or (str(ms[j]) != str(c["leader"]) and int(x.get("renown", 0)) >= int(y.get("renown", 0))) else x
			var other := x if goer == y else y
			leave(str(c["id"]), str(goer["id"]), "quarrelled with %s and walked out" % other["name"])
			return


## Takes in an unaffiliated adventurer in town who fills a gap and is not anyone's rival here.
static func recruit(c: Dictionary) -> bool:
	if randf() > 0.5:
		return false
	var members: Array = (c["members"] as Array).map(func(i): return Adv.get_a(str(i)))
	var best := {}
	var bv := 4.0
	for a in Adv.all().values():
		if str(a.get("status", "")) != "in_town" or not of(str(a["id"])).is_empty() or (c["members"] as Array).has(a["id"]):
			continue
		if Game.day() - int(a.get("left_company_day", -99)) < 3:
			continue
		var v := Expeditions.invite_score(members, a)
		var bad := false
		for m in members:
			if Expeditions.relation(m, str(a["id"])) <= -15.0:
				bad = true
		if bad:
			continue
		if v > bv:
			bv = v
			best = a
	if best.is_empty():
		return false
	join(str(c["id"]), str(best["id"]), "to fill the gap in the line")
	return true


## Friends who have shared the road found a company (a few at a time; old saves get theirs this way).
static func _formations() -> void:
	var free: Array = Adv.all().values().filter(func(a): return _free(a))
	if active().size() >= maxi(1, Living.active_count() / 4) or free.size() < 2 or randf() > 0.35:
		return
	var best := []
	var bv := 34.0
	for i in free.size():
		for j in range(i + 1, free.size()):
			var x: Dictionary = free[i]
			var y: Dictionary = free[j]
			var v := Expeditions.relation(x, str(y["id"]))
			if v < 35.0:
				continue
			var shared := shared_trips(str(x["id"]), str(y["id"]))
			if shared < 1 and v < 50.0:
				continue
			if v + shared * 3.0 > bv:
				bv = v + shared * 3.0
				best = [x, y]
	if best.is_empty():
		return
	var ids := [str(best[0]["id"]), str(best[1]["id"])]
	for a in free:
		if ids.size() >= 3 or ids.has(str(a["id"])):
			continue
		if Expeditions.relation(a, ids[0]) >= 25.0 and Expeditions.relation(a, ids[1]) >= 15.0:
			ids.append(str(a["id"]))
	found(ids, _best_leader(ids), "friends who have shared the road")


static func _free(a: Dictionary) -> bool:
	if not str(a.get("status", "")) in ["in_town", "injured"] or not of(str(a["id"])).is_empty():
		return false
	return not (str(a["id"]) == "mira" and Game.day() < 6)


static func shared_trips(x: String, y: String) -> int:
	var n := 0
	for e in Expeditions.done():
		if (e["party"] as Array).has(x) and (e["party"] as Array).has(y):
			n += 1
	return n


# ======================================================================= expeditions
## For Expeditions.form_parties: the companies that set out today, from the available adventurers (`avail`,
## Array of adventurer dicts — claimed members are removed from it). Returns [{company, leader, members}].
## A lone member whose companions are away or hurt usually waits for them.
static func plan_parties(avail: Array) -> Array:
	var out := []
	for c in active():
		var ms := avail.filter(func(a): return (c["members"] as Array).has(a["id"]))
		if ms.is_empty():
			continue
		if ms.size() == 1 and (c["members"] as Array).size() >= 2:
			if randf() < 0.6:
				avail.erase(ms[0])
				ms[0]["activity"] = "waiting"
			continue
		ms = ms.slice(0, MAX_SIZE)
		for m in ms:
			avail.erase(m)
		var lead: Dictionary = ms[0]
		for m in ms:
			if str(m["id"]) == str(c["leader"]):
				lead = m
		ms.erase(lead)
		ms.push_front(lead)
		out.append({"company": c["id"], "leader": lead, "members": ms})
	# small companies take on a pick-up companion for the trip (never a rival of theirs)
	for p in out:
		var ms: Array = p["members"]
		if ms.size() >= 3 or avail.is_empty():
			continue
		var best_i := -1
		var best_v := 6.0
		for i in avail.size():
			var a: Dictionary = avail[i]
			if not of(str(a["id"])).is_empty():
				continue
			var v := Expeditions.invite_score(ms, a)
			for m in ms:
				if Living.bond(m, str(a["id"])) == "rival":
					v -= 30.0
			if v > best_v:
				best_v = v
				best_i = i
		if best_i >= 0:
			ms.append(avail.pop_at(best_i))
	return out


## After a company's expedition (Expeditions.finish): record, reputation, streak, shared history; members who
## fell are struck off; a long losing streak breaks the company.
static func on_expedition(e: Dictionary, alive: Array, won: int, outcome: String) -> void:
	var c := get_c(str(e.get("company", "")))
	if c.is_empty() or str(c["status"]) != "active":
		return
	c["trips"] = int(c["trips"]) + 1
	var good := won > 0 and outcome != "retreated"
	var boss := 0
	for rec in e.get("encounters", []):
		if bool(rec.get("boss", false)) and str(rec.get("outcome", "")) == "victory":
			boss += 1
	if good:
		c["wins"] = int(c["wins"]) + 1
		c["streak"] = 0
		c["rep"] = int(c["rep"]) + won * 2 + boss * 12
	else:
		c["losses"] = int(c["losses"]) + 1
		c["streak"] = int(c["streak"]) + 1
		c["rep"] = maxi(0, int(c["rep"]) - 2)
		# a bad trip strains the company
		var ms: Array = (c["members"] as Array).filter(func(i): return alive.has(i))
		if ms.size() >= 2:
			Living.relate(str(ms[randi() % ms.size()]), str(c["leader"]), -3.0, "argued over %s" % Expeditions.region(str(e["dest"])).get("name", "the trip"))
	# the shared history: what members did out there (Lore recorded during the trip)
	var mark := int(e.get("lore_mark", 0))
	if mark > 0:
		for eid in Lore.st()["order"]:
			var n := int(str(eid).trim_prefix("ev_"))
			if n < mark:
				continue
			var ev := Lore.event(str(eid))
			for act in ev.get("actors", []):
				if (e["party"] as Array).has(act) and not (c["lore"] as Array).has(eid):
					(c["lore"] as Array).append(eid)
					break
	while (c["lore"] as Array).size() > 60:
		(c["lore"] as Array).pop_front()
	for id in e["party"]:
		if (c["members"] as Array).has(id) and str(Adv.get_a(str(id)).get("status", "")) == "dead":
			leave(str(c["id"]), str(id), "fell at %s" % Expeditions.region(str(e["dest"])).get("name", "the wilds"))
	if str(c["status"]) == "active" and int(c["streak"]) >= STREAK_LIMIT:
		disband(str(c["id"]), "%d bad trips in a row broke their nerve" % int(c["streak"]))


## The company's own history, newest first (Lore events).
static func history(c: Dictionary) -> Array:
	var out := Lore.events(c.get("lore", []))
	out.reverse()
	return out


static func signature() -> String:
	var parts := []
	var ids: Array = st()["list"].keys()
	ids.sort()
	for cid in ids:
		var c: Dictionary = st()["list"][cid]
		var ms: Array = (c["members"] as Array).duplicate()
		ms.sort()
		parts.append("%s:%s:%s:%s" % [cid, c["name"], c["leader"], ",".join(ms)])
	return "|".join(parts)
