## WorldSites — the land around Brindlewick as persistent places that change through the adventurers.
## EN: Every expedition region is a site with its own state in Game.state["world_sites"] (created lazily):
##     discovered or not, its unique master (a slain unique boss stays dead — the lair is "cleared"; a weaker
##     successor may move in much later, announced, never silently), a threat level that grows while the
##     master lives (more foes at the dens, a higher danger rating), resources that deplete when gathered and
##     slowly regrow, equipment lost there in a wipe (waiting to be found by a later party), rumours, and the
##     expeditions there now. What happens at a site is ONE Lore event with place = site id (arrivals,
##     discoveries, notable battles, unique kills with killer and weapon, deaths, losses, finds); the site's
##     history is simply Lore.of_place(id). The player never explores: the world changes through adventurers.
## DA: Verdenens steder — vedvarende tilstand pr. sted (opdaget, bosser der forbliver døde, trussel,
##     ressourcer der udtømmes og gror igen, tabt udstyr), og alt der sker optegnes som Lore-begivenheder.
class_name WorldSites
extends RefCounted

const THREAT_MAX := 3.0
const REGROW := {"resource": 0.06, "chest": 0.025, "boss": 0.02}   # per day
const TAKE := {"resource": 0.4, "chest": 0.7, "boss": 0.5}          # one visit's share
const RUMOUR_CHANCE := 0.05                                          # per undiscovered site per day
const TYPE_WORD := {"forest": "Forest", "mine": "Mine", "road": "Road", "barrow": "Ancient tomb", "deep": "Deep ruin",
	"stronghold": "Bandit stronghold", "temple": "Sunken ruin", "crag": "Dangerous wilderness",
	"observatory": "Ruined observatory", "fortress": "Haunted fortress", "rift": "Abyss"}   # v1.6 §8.1


# ======================================================================= data & state
static func cfg() -> Dictionary:
	return Expeditions.cfg().get("sites", {})


static func info(id: String) -> Dictionary:
	return cfg().get(id, {})


static func ids() -> Array:
	return cfg().keys()


static func name_of(id: String) -> String:
	return str(Expeditions.region(id).get("name", id.capitalize()))


static func st() -> Dictionary:
	if not Game.state.has("world_sites"):
		Game.state["world_sites"] = {}
	return Game.state["world_sites"]


## The persistent state of one site, created on first touch (old saves gain it lazily).
static func site(id: String) -> Dictionary:
	var s := st()
	if not s.has(id):
		var inf := info(id)
		var res := {}
		for n in Expeditions.region(id).get("nodes", []):
			if str(n.get("kind", "")) in ["resource", "chest", "boss"]:
				res[str(n["id"])] = 1.0
		var boss_n := Expeditions.node_of(id, str(inf.get("boss", "")))
		var first: Array = boss_n.get("enemies", [["", 1]])[0] if not (boss_n.get("enemies", []) as Array).is_empty() else ["", 1]
		s[id] = {"id": id, "discovered": bool(inf.get("known", false)), "found_day": 0 if bool(inf.get("known", false)) else -1, "found_by": [],
			"found_how": "known" if bool(inf.get("known", false)) else "", "threat": 0.6, "resources": res, "lost": [], "visits": 0,
			"boss": {"alive": true, "enemy": str(first[0]), "unique": str(first[0]), "gen": 0, "slain": [], "next_at": -1},
			"notes": [], "rumour_day": -1, "last_visit": -1}
	return s[id]


## Known on the map: discovered by rumour or adventurers, or revealed by its gate flag (the delve map).
static func is_discovered(id: String) -> bool:
	if not cfg().has(id):
		return true   # a region without a site entry (mods, tests) is always known
	var g := str(info(id).get("gate", ""))
	if g != "" and Game.has_flag(g):
		return true
	return bool(site(id).get("discovered", false))


static func discovered_ids() -> Array:
	return ids().filter(func(i): return is_discovered(str(i)))


static func world_pos(id: String) -> Vector2:
	var p: Array = info(id).get("pos", [800, 520])
	return Vector2(float(p[0]), float(p[1]))


static func type_of(id: String) -> String:
	return str(info(id).get("type", "forest"))


## The site's picture on the world map: its own `icon` (an existing site picture, so new sites need no new art), else its type.
static func icon_of(id: String) -> String:
	return str(info(id).get("icon", type_of(id)))


# ======================================================================= discovery
## Reveals a site. how: "rumour", "explored", "known", "map"… by: adventurer ids. Returns the Lore event id.
static func reveal(id: String, how: String, by: Array = [], text := "") -> String:
	if not cfg().has(id) or bool(site(id).get("discovered", false)):
		return ""
	var s := site(id)
	s["discovered"] = true
	s["found_day"] = Game.day()
	s["found_by"] = by.duplicate()
	s["found_how"] = how
	Game.set_flag("site_" + id)   # hirelings may be sent there too (destinations.json requires_flag)
	if how == "rumour":
		s["rumour_day"] = Game.day()
	var t := text
	if t == "":
		if by.is_empty():
			t = "Word reached Brindlewick of a place called %s — %s" % [name_of(id), str(info(id).get("desc", ""))]
		else:
			t = "%s found %s. %s" % [_names(by), name_of(id), str(info(id).get("desc", ""))]
	var ev := Lore.record("discovery", t, {"actors": by, "place": id, "importance": 2, "chronicle": true, "notable": true,
		"data": {"how": how}})
	Events.toast.emit("A new place on the world map: %s." % name_of(id), "good")
	return ev


## Explorers of a nearby region may stumble on an undiscovered site (chance rises with how far they went).
## Returns the discovered site id ("" = none). `chance` < 0 uses the normal odds.
static func try_discover(e: Dictionary, chance := -1.0) -> String:
	var here := str(e.get("dest", ""))
	var cands := []
	for id in ids():
		if not is_discovered(id) and str(info(id).get("gate", "")) == "" and (info(id).get("near", []) as Array).has(here):
			cands.append(id)
	if cands.is_empty():
		return ""
	var standing: Array = Expeditions._standing(e)
	if standing.is_empty():
		return ""
	var p := chance
	if p < 0.0:
		p = 0.08 + 0.04 * (e.get("explored", []) as Array).size()
		var sc := Expeditions._best(e, "scouting")
		if not sc.is_empty():
			p += 0.08
	if randf() >= p:
		return ""
	var id: String = cands[randi() % cands.size()]
	var finder := Expeditions._best(e, "scouting")
	if finder.is_empty():
		finder = Adv.get_a(str(standing[0]))
	var by: Array = standing.duplicate()
	by.erase(finder["id"])
	by.push_front(finder["id"])
	reveal(id, "explored", by, "%s spotted %s from the edge of %s and the party marked it on their map. %s" % [finder["name"], name_of(id),
		name_of(here), str(info(id).get("desc", ""))])
	Expeditions._j(e, "%s found the way to %s — a new place for the map." % [finder["name"], name_of(id)], "discovery")
	Expeditions.achieve(finder, "Found %s." % name_of(id), 10)
	return id


# ======================================================================= the daily world
## 05:00 each day: resources regrow, threats grow while masters live, successors move into old lairs,
## and rumours at the Tipsy Wyvern may reveal a place nobody has been to.
static func daily() -> void:
	for id in ids():
		var s := site(id)
		var inf := info(id)
		var b: Dictionary = s["boss"]
		# regrowth
		for nid in s["resources"]:
			var kind := str(Expeditions.node_of(id, nid).get("kind", "resource"))
			if kind == "boss" and not bool(b["alive"]):
				continue   # a cleared lair's hoard does not refill
			s["resources"][nid] = minf(1.0, float(s["resources"][nid]) + float(REGROW.get(kind, 0.03)))
		# threat
		var g := float(inf.get("growth", 0.05))
		var cap := THREAT_MAX if bool(b["alive"]) else 1.5
		s["threat"] = minf(cap, float(s["threat"]) + (g if bool(b["alive"]) else g * 0.3))
		# a successor moves in, much later (a countdown of world days) — and the world hears of it
		if not bool(b["alive"]) and int(b.get("next_at", -1)) > 0:
			b["next_at"] = int(b["next_at"]) - 1
			if int(b["next_at"]) <= 0:
				_successor_arrives(id)
		# a gate flag (the delve map) revealed it: the discovery is remembered once
		var gate := str(inf.get("gate", ""))
		if gate != "" and Game.has_flag(gate) and not bool(s["discovered"]):
			reveal(id, "map", [], "The delve map shows the way below the old workings: %s. %s" % [name_of(id), str(inf.get("desc", ""))])
		# rumours
		if not is_discovered(id) and str(inf.get("gate", "")) == "" and randf() < RUMOUR_CHANCE:
			reveal(id, "rumour", [], "Rumour at the Tipsy Wyvern: a pedlar swears to %s. %s" % [name_of(id), str(inf.get("desc", ""))])


static func _successor_arrives(id: String) -> String:
	var s := site(id)
	var b: Dictionary = s["boss"]
	var spec: Array = info(id).get("successor", [])
	if spec.is_empty():
		b["next_at"] = -1
		return ""
	b["alive"] = true
	b["gen"] = int(b.get("gen", 0)) + 1
	b["enemy"] = str(spec[0][0])
	b["next_at"] = -1
	s["threat"] = maxf(float(s["threat"]), 1.0)
	var en: Dictionary = DB.enemies.get(str(spec[0][0]), {})
	var t := "%s %s" % [str(info(id).get("cond", {}).get("successor", "Something new has moved in.")), "(%s, at %s.)" % [str(en.get("name", "a new master")),
		Expeditions.node_of(id, str(info(id).get("boss", ""))).get("name", name_of(id))]]
	_note(id, t)
	return Lore.record("threat", "%s — %s" % [name_of(id), t], {"place": id, "importance": 2, "chronicle": true, "icon": "icons/skull",
		"data": {"enemy": str(spec[0][0]), "gen": int(b["gen"])}})


static func _note(id: String, text: String) -> void:
	var notes: Array = site(id)["notes"]
	notes.append({"day": Game.day(), "text": text})
	while notes.size() > 6:
		notes.pop_front()


# ======================================================================= what the expeditions meet
static func boss_alive(id: String) -> bool:
	if not cfg().has(id):
		return true
	return bool(site(id)["boss"]["alive"])


## The enemies at a node, as the site is now: a slain unique master is gone (or replaced by a weaker
## successor), and a growing threat puts more foes at the dens.
static func enemies_at(rid: String, n: Dictionary) -> Array:
	var base: Array = n.get("enemies", [])
	if not cfg().has(rid) or base.is_empty():
		return base
	var s := site(rid)
	if str(n.get("id", "")) == str(info(rid).get("boss", "")) or str(n.get("kind", "")) == "boss":
		var b: Dictionary = s["boss"]
		if not bool(b["alive"]):
			return []
		if int(b.get("gen", 0)) > 0:
			return (info(rid).get("successor", []) as Array).duplicate(true)
		return base
	var extra := int(floor(float(s.get("threat", 0.0))))
	if extra <= 0:
		return base
	var out := []
	var added := false
	for spec in base:
		var en: Dictionary = DB.enemies.get(str(spec[0]), {})
		if not added and int(en.get("power", 10)) < 30:
			out.append([spec[0], int(spec[1]) + mini(extra, 2)])
			added = true
		else:
			out.append(spec.duplicate())
	return out


## Growing threats make the whole place more dangerous (more foes, bolder, better organised).
static func danger_factor(id: String) -> float:
	if not cfg().has(id):
		return 1.0
	return 1.0 + 0.08 * float(site(id).get("threat", 0.0))


## The danger rating of a site as it stands (Expeditions.rating reads enemies_at and danger_factor).
static func danger(id: String) -> float:
	return Expeditions.rating(id)


static func danger_word(id: String) -> String:
	var r := danger(id)
	if r >= 95.0:
		return "deadly"
	if r >= 70.0:
		return "dangerous"
	if r >= 45.0:
		return "risky"
	return "fair"


static func status_word(id: String) -> String:
	if not is_discovered(id):
		return "unknown"
	var s := site(id)
	if not bool(s["boss"]["alive"]):
		return "cleared"
	if float(s["threat"]) >= 2.0:
		return "threatened"
	if int(s["boss"].get("gen", 0)) > 0:
		return "reoccupied"
	return "wild"


static func boss_name(id: String) -> String:
	return str(DB.enemies.get(str(site(id)["boss"].get("enemy", "")), {}).get("name", "its master"))


## The site's conditions right now, in words.
static func conditions(id: String) -> Array:
	var out := []
	var s := site(id)
	var c: Dictionary = info(id).get("cond", {})
	var b: Dictionary = s["boss"]
	if not bool(b["alive"]):
		var last: Dictionary = (b["slain"] as Array)[-1] if not (b["slain"] as Array).is_empty() else {}
		out.append("%s%s" % [str(c.get("cleared", "Cleared.")), (" (%s fell to %s on day %d.)" % [last.get("name", ""), last.get("by_name", "adventurers"), int(last.get("day", 0))]) if not last.is_empty() else ""])
	elif int(b.get("gen", 0)) > 0:
		out.append(str(c.get("successor", "Something new has moved in.")))
	if float(s["threat"]) >= 2.0:
		out.append(str(c.get("growing", "The danger is growing.")))
	elif float(s["threat"]) >= 1.0:
		out.append(str(c.get("regroup", "Its foes are regrouping.")))
	for nid in s["resources"]:
		var n := Expeditions.node_of(id, nid)
		if str(n.get("kind", "")) != "boss" and float(s["resources"][nid]) < 0.3:
			out.append("%s has been %s." % [n.get("name", nid), "picked bare" if str(n.get("kind", "")) == "resource" else "emptied"])
	if not (s["lost"] as Array).is_empty():
		out.append("The gear of fallen adventurers lies somewhere here.")
	return out


# ======================================================================= resources
static func resource(rid: String, nid: String) -> float:
	if not cfg().has(rid):
		return 1.0
	return float(site(rid)["resources"].get(nid, 1.0))


## A party takes from a node: returns how rich it was (0..1) before they took their share.
static func take(rid: String, nid: String) -> float:
	if not cfg().has(rid):
		return 1.0
	var s := site(rid)
	if not s["resources"].has(nid):
		return 1.0
	var before := float(s["resources"][nid])
	var kind := str(Expeditions.node_of(rid, nid).get("kind", "resource"))
	s["resources"][nid] = maxf(0.0, before - float(TAKE.get(kind, 0.4)))
	return before


## Richness of the site's resource nodes on average (0..1).
static func richness(id: String) -> float:
	var s := site(id)
	var t := 0.0
	var n := 0
	for nid in s["resources"]:
		if str(Expeditions.node_of(id, nid).get("kind", "")) == "resource":
			t += float(s["resources"][nid])
			n += 1
	return t / maxf(1.0, n) if n > 0 else 0.5


# ======================================================================= the expedition hooks
## The party entered the site.
static func on_arrive(e: Dictionary) -> void:
	var rid := str(e["dest"])
	if not cfg().has(rid):
		return
	var s := site(rid)
	var first := int(s["visits"]) == 0
	s["visits"] = int(s["visits"]) + 1
	s["last_visit"] = Game.day()
	if not bool(s["discovered"]) and not is_discovered(rid):
		reveal(rid, "explored", e["party"])
	e["arrival_event"] = Lore.record("arrived", "%s entered %s%s." % [_names(e["party"]), name_of(rid), " — the first expedition there" if first else ""],
		{"actors": e["party"], "place": rid, "importance": 1 if first else 0})


## A node was resolved: lost gear lying there can be found.
static func on_node(e: Dictionary, n: Dictionary) -> void:
	find_lost(e, str(n.get("id", "")))


## The boss node of a cleared site: the empty lair, its leftovers, and what happened there.
static func visit_cleared(e: Dictionary, n: Dictionary) -> int:
	var rid := str(e["dest"])
	var b: Dictionary = site(rid)["boss"]
	var last: Dictionary = (b["slain"] as Array)[-1] if not (b["slain"] as Array).is_empty() else {}
	var rich := take(rid, str(n["id"]))
	var got: Array = Expeditions._loot(e, str(n.get("loot", "")), 1, rich * 0.5) if str(n.get("loot", "")) != "" and rich > 0.3 else []
	Expeditions._j(e, "%s stood empty%s.%s" % [n["name"], (" — %s fell here on day %d, to %s" % [last.get("name", ""), int(last.get("day", 0)), last.get("by_name", "adventurers")]) if not last.is_empty() else "",
		(" Leftovers: " + ", ".join(got) + ".") if not got.is_empty() else " Nothing worth carrying was left."], "path")
	return 30


## After every fight: threat falls when the dens are beaten, and notable fights are remembered as ONE Lore
## event (a boss fight, a near-death, a famous blow) linked to the actors, the gear that mattered and the site.
static func on_fight(e: Dictionary, n: Dictionary, rec: Dictionary) -> void:
	var rid := str(e["dest"])
	if not cfg().has(rid):
		return
	var s := site(rid)
	var won := str(rec.get("outcome", "")) == "victory"
	if won and str(n.get("kind", "")) == "encounter":
		s["threat"] = maxf(0.0, float(s["threat"]) - 0.3)
	elif not won:
		s["threat"] = minf(THREAT_MAX, float(s["threat"]) + 0.15)
	if rec.has("lore_event"):
		return   # the unique kill was already written as the fight's one event
	var near := _near_deaths(e, rec)
	var blow := _famous_blow(rec)
	var boss: bool = bool(rec.get("boss", false))
	if not boss and near.is_empty() and blow.is_empty():
		return   # routine fights stay unrecorded (the expedition journal keeps them)
	var parts := []
	var kind := "battle"
	if boss:
		parts.append("%s fought %s at %s and %s" % [_names(_party_ids(rec)), str(rec["enemies"][0]["name"]) if not (rec["enemies"] as Array).is_empty() else "its master",
			n["name"], "won" if won else ("was driven off" if str(rec["outcome"]) == "retreat" else "was overwhelmed")])
	else:
		parts.append("%s fought %s at %s" % [_names(_party_ids(rec)), Expeditions._group_name({"enemies": enemies_at(rid, n)}), n["name"]])
	if not blow.is_empty():
		parts.append("%s's %s with %s dealt %d" % [blow["actor"], "critical strike" if bool(blow.get("crit", false)) else "blow", blow.get("weapon", "a blade"), int(blow.get("dmg", 0))])
	if not near.is_empty():
		kind = "survived" if not boss else kind
		parts.append("%s went down and lived" % _names(near))
	var items := _items_that_mattered(e, rec)
	var ev := Lore.record(kind, "; ".join(parts) + ".", {"actors": _party_ids(rec), "items": items, "place": rid,
		"importance": 2 if boss else 1, "chronicle": boss, "data": {"node": n["id"], "outcome": rec["outcome"], "exp": e["id"]}})
	rec["lore_event"] = ev


## A unique (or successor) master fell. Marks the site cleared for good and writes the deed once:
## killer, weapon instance, the armour that held, the place. Returns the Lore event id.
static func on_boss_down(e: Dictionary, n: Dictionary, rec: Dictionary, killer: Dictionary) -> String:
	var rid := str(e["dest"])
	var boss_nm := str(rec["enemies"][0]["name"]) if not (rec["enemies"] as Array).is_empty() else str(n["name"])
	var a := Adv.get_a(str(killer.get("actor_id", "")))
	var w := Game.find_uid_anywhere(int(killer.get("weapon_uid", -1))) if not killer.is_empty() else {}
	var unique := true
	if cfg().has(rid):
		var s := site(rid)
		var b: Dictionary = s["boss"]
		unique = int(b.get("gen", 0)) == 0
		b["alive"] = false
		var lo: Array = info(rid).get("successor_days", [30, 45])
		b["next_at"] = randi_range(int(lo[0]), int(lo[1])) * (1 if unique else 2)   # world days until a successor
		s["threat"] = 0.0
		if n.has("id"):
			s["resources"][str(n["id"])] = 0.0   # the hoard goes home with the victors
	var who := str(a.get("name", "")) if not a.is_empty() else _names(_party_ids(rec))
	var text := ""
	if not a.is_empty():
		text = "%s slew %s at %s, %s, with %s." % [who, boss_nm, n["name"], name_of(rid), Items.display_name(w) if not w.is_empty() else str(killer.get("weapon", "a blow"))]
	else:
		text = "%s defeated %s at %s, %s." % [who, boss_nm, n["name"], name_of(rid)]
	var others: Array = _party_ids(rec).filter(func(i): return str(i) != str(a.get("id", "")))
	if not others.is_empty() and not a.is_empty():
		text += " %s fought beside %s." % [_names(others), who]
	var near := _near_deaths(e, rec)
	if not near.is_empty():
		text += " %s went down and lived." % _names(near)
	if unique:
		text += " %s will not rise again." % boss_nm
	var actors := []
	if not a.is_empty():
		actors.append(str(a["id"]))
	for i in _party_ids(rec):
		if not actors.has(i):
			actors.append(i)
	var items := _items_that_mattered(e, rec)
	if not w.is_empty() and not items.has(w):
		items.push_front(w)
	var ev := Lore.record("slew", text, {"actors": actors, "items": items, "place": rid, "importance": 3 if unique else 2,
		"data": {"enemy": str(rec["enemies"][0].get("id", "")) if not (rec["enemies"] as Array).is_empty() else "",
			"killer": str(a.get("id", "")), "weapon_uid": int(w.get("uid", -1)) if not w.is_empty() else -1, "unique": unique, "exp": e["id"], "node": str(n.get("id", ""))}})
	rec["lore_event"] = ev
	# the news feed keeps its "victory" kind (boards read it); the entry points at the one event
	var refs := {"party": e["party"], "exp": e["id"], "dest": rid, "place": rid, "event": ev}
	if not a.is_empty():
		refs["adv"] = str(a["id"])
	if not w.is_empty():
		refs["item"] = str(w["uid"])
	Chronicle.add("victory", text, refs, true)
	if cfg().has(rid):
		var b2: Dictionary = site(rid)["boss"]
		(b2["slain"] as Array).append({"day": Game.day(), "name": boss_nm, "by": str(a.get("id", "")), "by_name": who,
			"weapon_uid": int(w.get("uid", -1)) if not w.is_empty() else -1, "event": ev, "unique": unique})
		_note(rid, "%s fell to %s." % [boss_nm, who])
	return ev


## An adventurer died at the site.
static func on_death(e: Dictionary, a: Dictionary, where: String) -> String:
	var rid := str(e.get("dest", ""))
	var items := []
	for slot in ["weapon", "armor"]:
		var it: Dictionary = a.get("equipment", {}).get(slot, {})
		if not it.is_empty():
			items.append(it)
	return Lore.record("death", "%s fell at %s, %s." % [a["name"], where, name_of(rid)], {"actors": [a["id"]], "items": items, "place": rid, "importance": 2,
		"data": {"exp": e.get("id", "")}})


## The whole party is down: one event for the loss; those already dead leave their gear at the site.
static func on_wipe(e: Dictionary) -> void:
	var rid := str(e["dest"])
	var nid := str(e.get("at", ""))
	Lore.record("lost", "%s did not come back from %s, %s." % [_names(e["party"]), Expeditions.node_of(rid, nid).get("name", "the wilds"), name_of(rid)],
		{"actors": e["party"], "place": rid, "importance": 2, "data": {"exp": e["id"], "node": nid}})
	for id in e["party"]:
		var a := Adv.get_a(str(id))
		if str(a.get("status", "")) == "dead":
			leave_gear(a, rid, nid, "fell with %s" % a["name"])
	if cfg().has(rid):
		site(rid)["threat"] = minf(THREAT_MAX, float(site(rid)["threat"]) + 0.5)


## A dead adventurer's equipment stays where they fell, as "lost equipment" of the site.
static func leave_gear(a: Dictionary, rid: String, nid: String, how := "") -> int:
	if not cfg().has(rid):
		return 0
	var s := site(rid)
	var n := 0
	for slot in (a.get("equipment", {}) as Dictionary).keys():
		var it: Dictionary = a["equipment"][slot]
		if it.is_empty() or not Items.is_equipment(it) or slot == "companion":
			continue
		a["equipment"].erase(slot)
		Provenance.lose(it, "%s, %s" % [Expeditions.node_of(rid, nid).get("name", "the wilds"), name_of(rid)], how if how != "" else "left where %s fell" % a["name"], rid)
		(s["lost"] as Array).append({"item": it, "day": Game.day(), "node": nid, "owner": str(a["id"]), "owner_name": str(a["name"])})
		n += 1
	return n


## Lost gear lying at this node (or anywhere, for a search party) is found by the party's sharpest eye,
## carried home and offered to the smith or used. Its history continues: same uid, same maker.
static func find_lost(e: Dictionary, nid: String) -> Array:
	var rid := str(e.get("dest", ""))
	if not cfg().has(rid):
		return []
	var lost: Array = site(rid)["lost"]
	if lost.is_empty():
		return []
	var standing: Array = Expeditions._standing(e)
	if standing.is_empty():
		return []
	var finder := Expeditions._best(e, "scouting")
	if finder.is_empty():
		finder = Adv.get_a(str(standing[0]))
	var found := []
	for i in range(lost.size() - 1, -1, -1):
		var x: Dictionary = lost[i]
		if str(x.get("node", "")) != nid and str(e.get("goal", "")) != "search":
			continue
		var it: Dictionary = x["item"]
		lost.remove_at(i)
		var place_nm := "%s, %s" % [Expeditions.node_of(rid, str(x.get("node", ""))).get("name", "the wilds"), name_of(rid)]
		Provenance.transfer(it, str(finder["id"]), "found", rid, "%s found %s at %s, where %s fell on day %d." % [finder["name"], Items.display_name(it), place_nm,
			x.get("owner_name", "an adventurer"), int(x.get("day", 0))])
		Provenance.st(it).erase("lost")
		it["_site_found"] = true
		it["found"] = {"day": Game.day(), "where": name_of(rid), "exp": e["id"]}
		e["loot"].append(it)
		found.append(it)
		Expeditions._j(e, "%s found %s where %s fell." % [finder["name"], Items.display_name(it), x.get("owner_name", "an adventurer")], "discovery")
		var o := Adv.get_a(str(x.get("owner", "")))
		if not o.is_empty() and Expeditions.relation(finder, str(o["id"])) > 20.0:
			Expeditions.achieve(finder, "Brought %s's %s home." % [o["name"], Items.display_name(it)], 8)
	if not found.is_empty():
		var evs: Array = Lore.st()["order"]
		Chronicle.add("discovery", "%s's party found %s at %s." % [finder["name"], ", ".join(found.map(func(x): return Items.display_name(x))), name_of(rid)],
			{"adv": finder["id"], "place": rid, "event": evs[-1] if not evs.is_empty() else ""}, true)
	return found


## Home again: an explorer may have spotted a new place nearby.
static func on_finish(e: Dictionary) -> void:
	try_discover(e)


# ======================================================================= where adventurers go
## Can a party of this strength and nerve take the site on at all?
static func capable(id: String, strength: float, risk: float) -> bool:
	var d := danger(id) * float(Expeditions.diff().get("enemy", 1.0))
	return d <= strength * (1.6 + risk)


## How much the party wants to go there, beyond fitting its strength: interests by class and trait,
## opportunities (rumours, a lost comrade's gear, rich untouched resources, an uncleared master for the
## strong) and the leader's ambitions. Returns {score, why}.
static func appeal(members: Array, id: String, strength: float, risk: float) -> Dictionary:
	if not cfg().has(id):
		return {"score": 0.0, "why": ""}
	var s := site(id)
	var inf := info(id)
	var likes: Dictionary = inf.get("likes", {})
	var sc := 0.0
	var why := ""
	for m in members:
		if (likes.get("cls", []) as Array).has(str(m.get("cls", ""))):
			sc += 5.0
		if (likes.get("trait", []) as Array).has(str(m.get("trait", ""))):
			sc += 3.0
	if sc >= 8.0:
		why = "the kind of place they like"
	if int(s.get("rumour_day", -1)) >= 0 and Game.day() - int(s["rumour_day"]) <= 12 and int(s["visits"]) == 0:
		sc += 10.0
		why = "to see if the rumours are true"
	for x in s["lost"]:
		var bonus := 5.0
		for m in members:
			if Expeditions.relation(m, str(x.get("owner", ""))) > 20.0 or Social.relatives(str(m["id"])).has(str(x.get("owner", ""))):
				bonus = 18.0
		sc += bonus
		if bonus > 10.0:
			why = "to bring home %s's gear" % str(x.get("owner_name", "a friend"))
	var rich := richness(id)
	var greedy := members.filter(func(m): return str(m.get("trait", "")) == "greedy").size()
	sc += (rich - 0.5) * (8.0 + greedy * 6.0)
	var b: Dictionary = s["boss"]
	if bool(b["alive"]):
		var bp := float(DB.enemies.get(str(b.get("enemy", "")), {}).get("power", 40))
		if strength >= bp * 1.25 and risk >= 0.5:
			sc += 12.0
			why = "after %s" % boss_name(id)
	elif risk >= 0.6:
		sc -= 4.0   # nothing left to prove there
	var lead: Dictionary = members[0]
	if str(lead.get("next_dest", "")) == id:
		sc += 6.0
		if why == "":
			why = "as %s had planned" % lead["name"]
	for amb in lead.get("ambitions", []):
		if str(amb).begins_with("Hopes to be spoken of") and bool(b["alive"]) and strength >= float(DB.enemies.get(str(b.get("enemy", "")), {}).get("power", 40)):
			sc += 4.0
	return {"score": sc, "why": why}


# ======================================================================= what is there now
## Expeditions now bound for, at or returning from the site.
static func activity(id: String) -> Array:
	return Expeditions.active().values().filter(func(e): return str(e.get("dest", "")) == id)


## The site's history: the Lore events placed there (importance >= min_imp), oldest first.
static func events(id: String, min_imp := 1) -> Array:
	return Lore.of_place(id).filter(func(e): return int(e.get("importance", 0)) >= min_imp)


## Recent notable events (for the seals on the world map).
static func recent_seals(id: String, days := 10) -> Array:
	return Lore.of_place(id).filter(func(e): return int(e.get("importance", 0)) >= 2 and Game.day() - int(e.get("day", 0)) <= days)


static func lost(id: String) -> Array:
	return site(id)["lost"]


## Who lives there: the foes as they stand now, and other folk.
static func inhabitants(id: String) -> Array:
	var out := []
	var seen := {}
	for n in Expeditions.region(id).get("nodes", []):
		var specs := enemies_at(id, n)
		for i in specs.size():
			var en: Dictionary = DB.enemies.get(str(specs[i][0]), {})
			var nm := str(en.get("name", specs[i][0]))
			if not seen.has(nm):
				seen[nm] = true
				out.append({"name": nm, "id": str(specs[i][0]), "kind": str(en.get("kind", "")), "weak": str(en.get("weak", "")),
					"boss": str(n.get("kind", "")) == "boss" and i == 0, "count": int(specs[i][1])})
	return out


## What can be found there: materials, relics, equipment, creatures — and what commissions it brings.
static func finds(id: String) -> Dictionary:
	var mats := {}
	var relics := {}
	var equip := false
	for n in Expeditions.region(id).get("nodes", []):
		var tab: Dictionary = DB.loot.get(str(n.get("loot", "")), {}) if str(n.get("loot", "")) != "" else {}
		for en in tab.get("entries", []):
			var d := str(en[0])
			if d.begins_with("equip:"):
				equip = true
				continue
			var nm := str(DB.item(d).get("name", d))
			if d.begins_with("relic"):
				relics[nm] = true
			else:
				mats[nm] = true
	var weak := {}
	var creatures := []
	for x in inhabitants(id):
		if str(x["weak"]) != "":
			weak[str(x["weak"])] = true
		if str(x["kind"]) == "beast":
			creatures.append(str(x["name"]))
	var comm := []
	for w in weak:
		comm.append("%s weapons (foes here fear %s)" % [str(w).capitalize(), w])
	if type_of(id) in ["barrow", "temple", "deep", "fortress"]:
		comm.append("warded armour against the dead")
	return {"materials": mats.keys(), "relics": relics.keys(), "equipment": equip, "creatures": creatures, "commissions": comm}


# ======================================================================= helpers
static func _party_ids(rec: Dictionary) -> Array:
	return (rec.get("party", []) as Array).map(func(p): return str(p["id"]))


static func _names(ids_: Array) -> String:
	var names: Array = ids_.map(func(i): return str(Adv.get_a(str(i)).get("name", str(i))))
	return Expeditions._and(names)


## Members who were struck down in this fight and are still alive.
static func _near_deaths(e: Dictionary, rec: Dictionary) -> Array:
	var out := []
	for x in rec.get("actions", []):
		if str(x.get("kind", "")) == "enemy" and x.has("hp_after") and int(x["hp_after"]) <= 0:
			var id := str(x.get("target_id", ""))
			if id != "" and not out.has(id) and str(Adv.get_a(id).get("status", "")) != "dead":
				out.append(id)
	return out


## A blow worth telling: a huge critical strike, or one that felled a strong foe from full health at once.
static func _famous_blow(rec: Dictionary) -> Dictionary:
	var best := {}
	var hpmax := {}
	for en in rec.get("enemies", []):
		hpmax[str(en.get("key", ""))] = int(en.get("hp_max", 0))
	for x in rec.get("actions", []):
		if not (str(x.get("kind", "")) in ["attack", "spell"]) or not bool(x.get("hit", false)):
			continue
		var dmg := int(x.get("dmg", 0))
		var mx := int(hpmax.get(str(x.get("target_key", "")), 0))
		var big := (bool(x.get("crit", false)) and dmg >= 45) or (mx >= 30 and dmg >= mx)
		if big and (best.is_empty() or dmg > int(best.get("dmg", 0))):
			best = x
	return best


## The weapons that dealt the most and the armour that turned the most in this fight.
static func _items_that_mattered(e: Dictionary, rec: Dictionary) -> Array:
	var dealt := {}
	var turned := {}
	for x in rec.get("actions", []):
		var wu := int(x.get("weapon_uid", -1))
		if wu > 0 and bool(x.get("hit", false)):
			dealt[wu] = int(dealt.get(wu, 0)) + int(x.get("dmg", 0))
		var au := int(x.get("armour_uid", -1))
		if au > 0:
			turned[au] = int(turned.get(au, 0)) + int(x.get("absorbed", 0))
	var out := []
	var wk: Array = dealt.keys()
	wk.sort_custom(func(a, b): return int(dealt[a]) > int(dealt[b]))
	for u in wk.slice(0, 2):
		var it := Game.find_uid_anywhere(int(u))
		if not it.is_empty():
			out.append(it)
	var ak: Array = turned.keys().filter(func(u): return int(turned[u]) > 0)
	ak.sort_custom(func(a, b): return int(turned[a]) > int(turned[b]))
	for u2 in ak.slice(0, 1):
		var it2 := Game.find_uid_anywhere(int(u2))
		if not it2.is_empty():
			out.append(it2)
	return out
