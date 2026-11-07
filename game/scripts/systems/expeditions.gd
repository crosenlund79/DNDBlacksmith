## Expeditions — the authoritative adventurer simulation: parties, expeditions over game time, fights.
## EN: Every morning adventurers who are rested gather at the Tipsy Wyvern; a leader picks a region
##     that suits the party's strength and nerve and invites companions (healers, front-liners and
##     scouts are wanted; friends preferred; rivals avoided). They prepare (buying draughts from the
##     smith's shelf), leave through the region's village exit, travel, and work through the region's
##     points of interest one step at a time on the game clock: fights are fought round by round with
##     dice, using the real statistics of the items each adventurer carries; traps, locks, rune doors,
##     shrines and travellers are skill checks. They retreat when hurt or shaken, come home with loot,
##     gold, experience, wounds — or not at all.
##     Everything is written once, here, into the expedition's own journal and encounter records and
##     into the Chronicle; the Most Wanted board and the observer only READ it. Nothing happens because
##     someone is watching: the board can be closed and reopened and the same steps happen at the same
##     game minutes. Difficulty changes danger, death, recovery and economy — and what the board shows.
## DA: Den autoritative eventyrersimulation: grupper, ekspeditioner over spiltid og kampe med terninger
##     og rigtige genstandsværdier. Tavlen og observatøren læser kun herfra.
class_name Expeditions
extends RefCounted

const STEP_MIN := 2          # game minutes per combat round in the record timeline
const BANE := {"beast": "Wolfbane", "spider": "Webcutter", "humanoid": "Tollbreaker", "spirit": "Shadowsunder",
	"undead": "Gravebane", "construct": "Stonesplitter"}


# ======================================================================= data & state
static func cfg() -> Dictionary:
	return DB.expeditions


static func region(id: String) -> Dictionary:
	return cfg().get("regions", {}).get(id, {})


static func node_of(rid: String, nid: String) -> Dictionary:
	for n in region(rid).get("nodes", []):
		if n["id"] == nid:
			return n
	return {}


static func diff_id() -> String:
	return str(Game.state.get("difficulty", "journeyman"))


static func diff() -> Dictionary:
	return cfg().get("difficulty", {}).get(diff_id(), {"observe": true, "detail": true, "enemy": 1.0, "death": true, "death_dc": 7, "heal_rate": 1.0, "prices": 1.0, "wages": 1.0, "loot": 1.0})


## Change difficulty mid-game: permissions (observation, detail) and economy factors follow at once.
static func set_difficulty(id: String) -> void:
	if not cfg().get("difficulty", {}).has(id) or id == diff_id():
		return
	Game.state["difficulty"] = id
	Chronicle.add("info", "The smith now plays at %s difficulty." % str(diff().get("name", id)))
	Events.expeditions_changed.emit()


static func can_observe() -> bool:
	return bool(diff().get("observe", true))


static func st() -> Dictionary:
	if not Game.state.has("exp"):
		Game.state["exp"] = {"active": {}, "done": [], "parties": {}}
	return Game.state["exp"]


static func active() -> Dictionary:
	return st()["active"]


static func done() -> Array:
	return st()["done"]


static func get_exp(id: String) -> Dictionary:
	if active().has(id):
		return active()[id]
	for e in done():
		if e["id"] == id:
			return e
	return {}


static func exp_of(adv_id: String) -> Dictionary:
	for e in active().values():
		if (e["party"] as Array).has(adv_id):
			return e
	return {}


static func party_of(adv_id: String) -> Dictionary:
	for p in st()["parties"].values():
		if (p["members"] as Array).has(adv_id):
			return p
	return {}


# ======================================================================= adventurers
static func arch(a: Dictionary) -> Dictionary:
	return cfg().get("archetypes", {}).get(a.get("cls", "Fighter"), {"role": "front", "attr": {"str": 2, "dex": 1, "int": 0, "wis": 0, "con": 2}, "hp": 12, "hp_lv": 6, "skills": [], "prefers": []})


## Adds the expedition model to an adventurer (new games and older saves alike).
static func ensure(a: Dictionary) -> Dictionary:
	Adv.ensure(a)
	if not a.has("hp_max"):
		a["hp_max"] = hp_max(a)
		a["hp"] = a["hp_max"]
	if not a.has("fatigue"):
		a["fatigue"] = 0.0
		a["morale"] = 70.0
		a["renown"] = int(a.get("victories", 0)) * 6
		a["achievements"] = []
		a["relations"] = {}
		a["activity"] = "at_inn"
		a["kills"] = 0
		a["loot_value"] = 0
		a["deaths_cheated"] = 0
	if not a.has("risk"):
		a["risk"] = {"brave": 0.7, "reckless": 0.85, "cautious": 0.3, "greedy": 0.6, "steady": 0.5, "devout": 0.55}.get(a.get("trait", "steady"), 0.5)
	return a


static func hp_max(a: Dictionary) -> int:
	var ar := arch(a)
	var con := int(ar["attr"].get("con", 1))
	return int(ar["hp"]) + (int(a["level"]) - 1) * int(ar["hp_lv"]) + con * int(a["level"]) / 2 + Items.stat(a["equipment"].get("amulet", {}), "vitality")


static func attr(a: Dictionary, k: String) -> int:
	var base := int(arch(a)["attr"].get(k, 0))
	return base + (int(a["level"]) / 3 if base >= 3 else 0)


static func has_skill(a: Dictionary, s: String) -> bool:
	return (arch(a).get("skills", []) as Array).has(s)


static func role(a: Dictionary) -> String:
	return str(arch(a).get("role", "front"))


## Total of a stat over everything the adventurer wears (rings, amulet, armour, weapon…).
static func total(a: Dictionary, stat: String) -> int:
	var t := 0
	for slot in a["equipment"]:
		t += Items.stat(a["equipment"][slot], stat)
	return t


static func coat(it: Dictionary, stat: String) -> int:
	var c: Dictionary = it.get("coating", {})
	return int(c.get("value", 0)) if str(c.get("stat", "")) == stat else 0


static func defence(a: Dictionary) -> int:
	return 10 + attr(a, "dex") + int(round(total(a, "protection") * 0.25))


## Weapon profile: to-hit bonus and damage parts, all derived from the actual item instance.
static func weapon_profile(a: Dictionary) -> Dictionary:
	var w: Dictionary = a["equipment"].get("weapon", {})
	var wt := Items.wtype(w)
	var prefers: Array = arch(a).get("prefers", [])
	var main := attr(a, "dex") if wt in ["bow", "dagger"] or a["cls"] in ["Rogue", "Ranger"] else attr(a, "str")
	var qb := int((float(w.get("quality", 70)) - 70.0) / 20.0) if not w.is_empty() else 0
	var aff := 2 if prefers.has(wt) else 0
	var to_hit := main + int(a["level"]) / 2 + aff + qb + (2 if wt == "bow" and a["cls"] == "Ranger" else 0)
	var atk := float(Items.stat(w, "attack") + coat(w, "attack")) if not w.is_empty() else 3.0
	if w.get("broken", false):
		atk *= 0.5
	return {"item": w, "wtype": wt, "to_hit": to_hit, "base": atk * 0.55 + main, "qb": qb, "aff": aff, "main": main}


static func power(a: Dictionary) -> float:
	var wp := weapon_profile(a)
	return int(a["level"]) * 4.0 + float(wp["base"]) * 1.5 + total(a, "protection") * 0.4 + total(a, "magic") * 0.6 + float(hp_max(a)) * 0.3


static func renown_title(a: Dictionary) -> String:
	var t := "Unknown"
	for e in cfg().get("renown_titles", []):
		if int(a.get("renown", 0)) >= int(e[0]):
			t = str(e[1])
	return t


static func relation(a: Dictionary, b: String) -> float:
	return float(a.get("relations", {}).get(b, 0.0))


static func relate(a_id: String, b_id: String, d: float) -> void:
	var a := Adv.get_a(a_id)
	var b := Adv.get_a(b_id)
	if a.is_empty() or b.is_empty():
		return
	a["relations"][b_id] = clampf(relation(a, b_id) + d, -100.0, 100.0)
	b["relations"][a_id] = clampf(relation(b, a_id) + d, -100.0, 100.0)


static func achieve(a: Dictionary, text: String, renown: int) -> void:
	a["achievements"].append({"day": Game.day(), "text": text})
	while a["achievements"].size() > 12:
		a["achievements"].pop_front()
	var before := renown_title(a)
	a["renown"] = int(a.get("renown", 0)) + renown
	if renown_title(a) != before:
		Chronicle.add("renown", "%s is now spoken of as %s." % [a["name"], renown_title(a)], {"adv": a["id"]}, true)
		Events.toast.emit("%s — now “%s”." % [a["name"], renown_title(a)], "good")


## New game (and older saves): every adventurer gets the expedition model and their friendships.
static func init_world() -> void:
	for a in Adv.all().values():
		ensure(a)
	for r in cfg().get("relations", []):
		var x := Adv.get_a(str(r[0]))
		var y := Adv.get_a(str(r[1]))
		if not x.is_empty() and not y.is_empty() and relation(x, str(r[1])) == 0.0:
			x["relations"][r[1]] = float(r[2])
			y["relations"][r[0]] = float(r[2])
	# legacy expeditions from the old model come straight home
	for a in Adv.all().values():
		if a["status"] == "away" and not a.has("exp"):
			a["status"] = "in_town"
			a["depart_day"] = Game.day() + 1


# ======================================================================= the daily rhythm
static func on_hour(h: int) -> void:
	# recovery in town
	for a in Adv.all().values():
		ensure(a)
		if a["status"] in ["in_town", "injured"]:
			var rate := 0.03 * float(diff().get("heal_rate", 1.0)) * (2.0 if a["status"] == "in_town" else 1.0)
			a["hp"] = mini(int(a["hp_max"]), int(a["hp"]) + maxi(1, int(round(float(a["hp_max"]) * rate))))
			a["fatigue"] = maxf(0.0, float(a["fatigue"]) - 3.0)
			a["morale"] = minf(90.0, float(a["morale"]) + 1.0)
			if a["status"] == "in_town" and a.get("activity", "") in ["recovering", ""] and float(a["hp"]) >= float(a["hp_max"]) * 0.9:
				a["activity"] = "at_inn"
	match h:
		6:
			form_parties()
		7:
			prepare_parties()
		8:
			depart_parties()
	check_missing()


## 06:00 — the inn: leaders gather companions.
static func form_parties() -> void:
	var avail := []
	for a in Adv.all().values():
		ensure(a)
		if a["status"] == "in_town" and Game.day() >= int(a.get("depart_day", 0)) and float(a["hp"]) >= float(a["hp_max"]) * 0.7 \
				and float(a["fatigue"]) < 40.0 and party_of(a["id"]).is_empty():
			avail.append(a)
	avail.sort_custom(func(x, y): return float(x["risk"]) + float(x.get("renown", 0)) * 0.002 > float(y["risk"]) + float(y.get("renown", 0)) * 0.002)
	var made := 0
	while not avail.is_empty() and made < 3:
		var leader: Dictionary = avail.pop_front()
		var members := [leader]
		var size := 1 + (1 if float(leader["risk"]) >= 0.35 else 0) + (1 if randf() < 0.6 else 0) + (1 if float(leader["risk"]) >= 0.65 and randf() < 0.5 else 0)
		while members.size() < size and not avail.is_empty():
			var best_i := -1
			var best_v := -5.0
			for i in avail.size():
				var v := invite_score(members, avail[i])
				if v > best_v:
					best_v = v
					best_i = i
			if best_i < 0:
				break
			members.append(avail.pop_at(best_i))
		var ids: Array = members.map(func(m): return m["id"])
		var plan := choose_destination(members)
		if plan.is_empty():
			continue
		var pid := "party_%d" % Game.new_uid()
		st()["parties"][pid] = {"id": pid, "members": ids, "leader": leader["id"], "dest": plan["dest"], "goal": plan["goal"],
			"formed": Game.now(), "table": made + 1}
		for m in members:
			m["activity"] = "recruiting"
		var names := ids.map(func(i): return Adv.get_a(i)["name"])
		Chronicle.add("party", "%s gathered %s at the Wyvern, bound for %s%s." % [leader["name"], ("a party: " + ", ".join(names.slice(1))) if ids.size() > 1 else "no one — going alone", region(plan["dest"])["name"],
			" to search for the missing" if plan["goal"] == "search" else ""], {"adv": leader["id"], "party": ids, "dest": plan["dest"]})
		made += 1
	Events.expeditions_changed.emit()


## How much the party would like this adventurer along: roles it lacks, friendship, rivalry.
static func invite_score(members: Array, c: Dictionary) -> float:
	var roles := members.map(func(m): return role(m))
	var s := 0.0
	var r := role(c)
	if r == "healer" and not roles.has("healer"):
		s += 12.0
	if r == "front" and not roles.has("front"):
		s += 10.0
	if r == "scout" and not roles.has("scout"):
		s += 8.0
	if r == "caster" and not roles.has("caster"):
		s += 6.0
	if roles.has(r):
		s -= 4.0
	for m in members:
		s += relation(m, c["id"]) * 0.25
	return s + randf() * 3.0


## Pick a region whose danger fits the party's strength and nerve, or answer a call for help.
static func choose_destination(members: Array) -> Dictionary:
	var pow := 0.0
	var risk := 0.0
	for m in members:
		pow += power(m)
		risk += float(m["risk"])
	risk /= members.size()
	# what the party can take on: the average member's strength, a little more for each companion
	var strength := pow / members.size() * (0.8 + 0.4 * (members.size() - 1))
	# a missing party is an opportunity for the brave and the strong
	for mid in Game.state["world"].get("missing", {}):
		var mi: Dictionary = Game.state["world"]["missing"][mid]
		if not mi.get("searched", false) and risk >= 0.5 and strength >= rating(str(mi["dest"])) * 0.75:
			mi["searched"] = true
			return {"dest": str(mi["dest"]), "goal": "search"}
	var best := ""
	var best_s := -1e9
	for rid in cfg().get("regions", {}):
		var dd: Dictionary = DB.destinations.get(rid, {})
		if dd.has("requires_flag") and not Game.has_flag(str(dd["requires_flag"])):
			continue
		var want := strength * (0.6 + risk * 0.8)
		var s := -absf(rating(rid) * float(diff().get("enemy", 1.0)) - want) + randf() * 18.0
		# a change of scene: the leader went there last time
		var hist: Array = members[0].get("history", [])
		if not hist.is_empty() and str(hist[-1].get("dest", "")) == rid:
			s -= 12.0
		if s > best_s:
			best_s = s
			best = rid
	if best == "":
		return {}
	return {"dest": best, "goal": "explore"}


## A rough danger rating for a region (strongest group the party may meet).
static func rating(rid: String) -> float:
	var r := 0.0
	for n in region(rid).get("nodes", []):
		var p := 0.0
		for e in n.get("enemies", []):
			p += float(DB.enemies.get(e[0], {}).get("power", 10)) * int(e[1])
		r = maxf(r, p)
	return r


## 07:00 — preparing: draughts from the smith's shelf, a last drink.
static func prepare_parties() -> void:
	for p in st()["parties"].values():
		for id in p["members"]:
			var a := Adv.get_a(id)
			a["activity"] = "preparing"
			Adv._buy_supplies(a)
	Events.expeditions_changed.emit()


## 08:00 — they leave through the region's exit; the expedition begins.
static func depart_parties() -> void:
	for pid in st()["parties"].keys():
		var p: Dictionary = st()["parties"][pid]
		var ok := true
		for id in p["members"]:
			if Adv.get_a(id).get("status", "") != "in_town":
				ok = false
		if ok:
			start(p)
		else:
			for id in p["members"]:
				var a := Adv.get_a(id)
				if a.get("activity", "") in ["recruiting", "preparing"]:
					a["activity"] = "at_inn"
		st()["parties"].erase(pid)
	Events.expeditions_changed.emit()


static func start(p: Dictionary) -> Dictionary:
	var rid: String = p["dest"]
	var reg := region(rid)
	var d: Dictionary = DB.destinations.get(rid, {})
	var exit: String = d.get("exit", "north")
	var eid := "exp_%d" % Game.new_uid()
	var tr: Array = reg.get("travel_h", [2, 3])
	var travel := randi_range(int(tr[0]) * 60, int(tr[1]) * 60)
	var e := {"id": eid, "party": p["members"].duplicate(), "leader": p["leader"], "dest": rid, "goal": p.get("goal", "explore"),
		"start": Game.now(), "phase": "travel_out", "at": "village", "route": plan_route(rid, p["members"]), "step": 0,
		"leg": {"from": "village", "to": "gate", "t0": Game.now(), "t1": Game.now() + travel},
		"next_at": Game.now() + travel, "journal": [], "encounters": [], "loot": [], "gold": 0, "explored": [],
		"outcome": "", "difficulty": diff_id(), "snap": {}}
	for id in e["party"]:
		var a := Adv.get_a(id)
		a["status"] = "away"
		a["dest"] = rid
		a["exit"] = exit
		a["exp"] = eid
		a["activity"] = "adventuring"
		a["expeditions"] = int(a.get("expeditions", 0)) + 1
		e["snap"][id] = snapshot(a)
	active()[eid] = e
	var names: Array = e["party"].map(func(i): return Adv.get_a(i)["name"])
	_j(e, "%s departed through the %s gate for %s." % [_and(names), exit, reg.get("name", rid)], "depart")
	Chronicle.add("departure", "%s set out for %s." % [_and(names), reg.get("name", rid)], {"party": e["party"], "exp": eid, "dest": rid}, true)
	for id in e["party"]:
		Events.adventurer_departed.emit(id, exit)
	Audio.play("sfx/door", -8.0)
	return e


## The planned route: from the entry, walk the region's links preferring unexplored, richer and — for
## the bold — deeper places. A search party heads for where the missing were last seen.
static func plan_route(rid: String, party: Array) -> Array:
	var risk := 0.0
	for id in party:
		risk += float(Adv.get_a(id).get("risk", 0.5))
	risk /= maxf(1.0, party.size())
	var nodes: Array = region(rid).get("nodes", [])
	var route := []
	var cur: Dictionary = nodes[0]
	var depth := 3 + int(risk * 3.0) + (1 if party.size() >= 3 else 0)
	var target := ""
	for mid in Game.state["world"].get("missing", {}):
		var mi: Dictionary = Game.state["world"]["missing"][mid]
		if str(mi["dest"]) == rid:
			target = str(mi["node"])
	while route.size() < depth:
		var links: Array = cur.get("links", [])
		if links.is_empty():
			break
		var choice: String = links[0]
		if links.size() > 1:
			if target != "" and links.has(target):
				choice = target
			else:
				choice = links[randi() % links.size()]
		route.append(choice)
		cur = node_of(rid, choice)
		if choice == target:
			break
	return route


# ======================================================================= the clock
## Called every 5 game minutes by Game.advance_minutes — whatever is open on screen.
static func tick() -> void:
	if Game.state.is_empty():
		return
	var now := Game.now()
	for eid in active().keys():
		var e: Dictionary = active()[eid]
		var guard := 0
		while active().has(eid) and int(e["next_at"]) <= now and guard < 6:
			guard += 1
			step(e)


static func step(e: Dictionary) -> void:
	match str(e["phase"]):
		"travel_out":
			e["at"] = "gate"
			_j(e, "The party entered %s." % region(e["dest"]).get("name", e["dest"]), "arrive")
			_next_leg(e)
		"moving":
			var nid: String = e["leg"]["to"]
			e["at"] = nid
			if not (e["explored"] as Array).has(nid):
				e["explored"].append(nid)
			var dur := resolve_node(e, node_of(e["dest"], nid))
			e["phase"] = "acting"
			e["next_at"] = Game.now() + dur
		"acting":
			if _wiped(e):
				_wipe(e)
			elif should_retreat(e):
				_j(e, "%s called the retreat." % _lead_name(e), "retreat")
				e["outcome"] = "retreated"
				_go_home(e)
			else:
				e["step"] = int(e["step"]) + 1
				_next_leg(e)
		"travel_back":
			finish(e)
	Events.expedition_event.emit(e["id"], e["journal"][-1] if not e["journal"].is_empty() else {})


static func _next_leg(e: Dictionary) -> void:
	var route: Array = e["route"]
	if int(e["step"]) >= route.size():
		if e["outcome"] == "":
			e["outcome"] = "returned"
		_go_home(e)
		return
	var to: String = route[int(e["step"])]
	var a := node_of(e["dest"], str(e["at"]))
	var b := node_of(e["dest"], to)
	var dist := Vector2(float(a.get("x", 0)), float(a.get("y", 0))).distance_to(Vector2(float(b.get("x", 0)), float(b.get("y", 0))))
	var mins := int(clampf(dist / 6.0, 30.0, 110.0))
	e["leg"] = {"from": e["at"], "to": to, "t0": Game.now(), "t1": Game.now() + mins}
	e["phase"] = "moving"
	e["next_at"] = Game.now() + mins
	for id in e["party"]:
		var m := Adv.get_a(id)
		m["fatigue"] = minf(100.0, float(m["fatigue"]) + 5.0)


static func _go_home(e: Dictionary) -> void:
	var tr: Array = region(e["dest"]).get("travel_h", [2, 3])
	var mins := randi_range(int(tr[0]) * 60, int(tr[1]) * 60)
	e["leg"] = {"from": e["at"], "to": "village", "t0": Game.now(), "t1": Game.now() + mins}
	e["phase"] = "travel_back"
	e["next_at"] = Game.now() + mins
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") == "away":
			a["activity"] = "returning"
	_j(e, "The party turned for home.", "homeward")


static func should_retreat(e: Dictionary) -> bool:
	var hp := 0.0
	var mx := 0.0
	var risk := 0.0
	var standing := 0
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") != "away":
			continue
		hp += maxf(0.0, float(a["hp"]))
		mx += float(a["hp_max"])
		risk += float(a["risk"])
		if float(a["hp"]) > 0.0:
			standing += 1
	if standing == 0 or mx <= 0.0:
		return true
	risk /= maxf(1.0, e["party"].size())
	var down := standing < (e["party"] as Array).filter(func(i): return Adv.get_a(i).get("status", "") == "away").size()
	return hp / mx < 0.55 - risk * 0.3 or (down and risk < 0.75)


static func _wiped(e: Dictionary) -> bool:
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") == "away" and float(a["hp"]) > 0.0:
			return false
	return true


# ======================================================================= points of interest
## Resolves what happens at a node; returns how many game minutes it takes.
static func resolve_node(e: Dictionary, n: Dictionary) -> int:
	var kind := str(n.get("kind", "path"))
	match kind:
		"encounter", "boss":
			return fight(e, n)
		"trap":
			return trap(e, n)
		"chest":
			return chest(e, n)
		"resource":
			return gather(e, n)
		"puzzle":
			return puzzle(e, n)
		"shrine":
			for id in _standing(e):
				var a := Adv.get_a(id)
				a["hp"] = mini(int(a["hp_max"]), int(a["hp"]) + int(float(a["hp_max"]) * 0.3))
				a["fatigue"] = maxf(0.0, float(a["fatigue"]) - 20.0)
				a["morale"] = minf(100.0, float(a["morale"]) + 10.0)
			_j(e, "Rested at %s; wounds eased and spirits rose." % n["name"], "rest")
			return 50
		"traveller":
			return traveller(e, n)
		_:
			var sc := _best(e, "scouting")
			if not sc.is_empty():
				var r := _check(sc, "wis", 11, "scouting")
				if r["ok"]:
					_j(e, "%s scouted %s and found the safest way on (%s)." % [sc["name"], n["name"], r["txt"]], "scout")
				else:
					_j(e, "Pushed on through %s." % n["name"], "path")
			else:
				_j(e, "Pushed on through %s." % n["name"], "path")
			return 20
	return 20


static func _standing(e: Dictionary) -> Array:
	return (e["party"] as Array).filter(func(i):
		var a := Adv.get_a(i)
		return a.get("status", "") == "away" and float(a.get("hp", 0)) > 0.0)


## The standing member best at a skill (falls back to anyone standing).
static func _best(e: Dictionary, skill: String) -> Dictionary:
	var best := {}
	for id in _standing(e):
		var a := Adv.get_a(id)
		if has_skill(a, skill) and (best.is_empty() or int(a["level"]) > int(best["level"])):
			best = a
	return best


static func _check(a: Dictionary, at: String, dc: int, skill := "") -> Dictionary:
	var roll := Dice.roll("1d20")
	var mod := attr(a, at) + int(a["level"]) / 2 + (3 if skill != "" and has_skill(a, skill) else 0) - int(float(a.get("fatigue", 0)) / 34.0)
	var tot := int(roll["total"]) + mod
	return {"ok": tot >= dc, "roll": int(roll["total"]), "mod": mod, "total": tot, "dc": dc,
		"txt": "d20 %d %+d = %d vs %d" % [int(roll["total"]), mod, tot, dc]}


static func trap(e: Dictionary, n: Dictionary) -> int:
	var dc := int(n.get("dc", 13)) + (1 if diff_id() == "master" else 0)
	var spotter := _best(e, "traps")
	if spotter.is_empty():
		spotter = _best(e, "scouting")
	var rec := {"kind": "trap", "node": n["id"], "node_name": n["name"], "t": Game.now(), "checks": []}
	if not spotter.is_empty():
		var r := _check(spotter, "dex", dc, "traps")
		rec["checks"].append({"who": spotter["name"], "what": "spot and disarm", "txt": r["txt"], "ok": r["ok"]})
		if r["ok"]:
			_j(e, "%s detected and disarmed a concealed trap in %s (%s)." % [spotter["name"], n["name"], r["txt"]], "trap", _rec(e, rec))
			spotter["renown"] = int(spotter.get("renown", 0)) + 2
			if n.get("loot", "") != "":
				_loot(e, str(n["loot"]), int(n.get("tier", 1)))
			return 35
	var st_ids := _standing(e)
	var victim := Adv.get_a(st_ids[randi() % st_ids.size()])
	var dmg := int(Dice.roll("2d6")["total"]) + int(n.get("tier", 1)) * 2
	var dodge := _check(victim, "dex", dc)
	rec["checks"].append({"who": victim["name"], "what": "dodge", "txt": dodge["txt"], "ok": dodge["ok"]})
	if dodge["ok"]:
		dmg /= 2
	victim["hp"] = int(victim["hp"]) - dmg
	rec["damage"] = {"who": victim["name"], "dmg": dmg}
	_j(e, "A trap sprang in %s: %s took %d damage%s." % [n["name"], victim["name"], dmg, " (half, dodging)" if dodge["ok"] else ""], "trap", _rec(e, rec))
	if n.get("loot", "") != "":
		_loot(e, str(n["loot"]), int(n.get("tier", 1)))
	return 40


static func chest(e: Dictionary, n: Dictionary) -> int:
	var dc := int(n.get("dc", 13))
	var picker := _best(e, "locks")
	if picker.is_empty():
		picker = Adv.get_a(_standing(e)[0])
	var r := _check(picker, "dex", dc, "locks")
	var rec := {"kind": "chest", "node": n["id"], "node_name": n["name"], "t": Game.now(), "checks": [{"who": picker["name"], "what": "open the lock", "txt": r["txt"], "ok": r["ok"]}]}
	if r["ok"]:
		var got := _loot(e, str(n.get("loot", "barrow")), int(n.get("tier", 1)) + 1)
		var g := randi_range(10, 30) * int(n.get("tier", 1))
		e["gold"] = int(e["gold"]) + g
		rec["loot"] = got
		_j(e, "%s opened the %s (%s): %d gold%s." % [picker["name"], n["name"].to_lower(), r["txt"], g, (" and " + ", ".join(got)) if not got.is_empty() else ""], "loot", _rec(e, rec))
	else:
		_j(e, "%s could not open the %s (%s)." % [picker["name"], n["name"].to_lower(), r["txt"]], "fail", _rec(e, rec))
	return 30


static func gather(e: Dictionary, n: Dictionary) -> int:
	var who := _best(e, "survival")
	if who.is_empty():
		who = Adv.get_a(_standing(e)[0])
	var r := _check(who, "wis", 11, "survival")
	var got := _loot(e, str(n.get("loot", "forest")), int(n.get("tier", 1)) + (1 if r["ok"] else 0))
	_j(e, "Gathered at %s%s: %s." % [n["name"], (" — %s knew where to look (%s)" % [who["name"], r["txt"]]) if r["ok"] else "", ", ".join(got) if not got.is_empty() else "little worth carrying"], "loot")
	return 60


static func puzzle(e: Dictionary, n: Dictionary) -> int:
	var sage := _best(e, "arcana")
	if sage.is_empty():
		sage = _best(e, "lore")
	if sage.is_empty():
		sage = Adv.get_a(_standing(e)[0])
	var r := _check(sage, "int", int(n.get("dc", 14)), "arcana")
	var rec := {"kind": "puzzle", "node": n["id"], "node_name": n["name"], "t": Game.now(), "checks": [{"who": sage["name"], "what": "read the runes", "txt": r["txt"], "ok": r["ok"]}]}
	if r["ok"]:
		var relic := Items.make(["relic_unknown_tablet", "relic_unknown_reliquary", "relic_unknown_arms"].pick_random())
		e["loot"].append(relic)
		rec["loot"] = [relic["name"]]
		sage["renown"] = int(sage.get("renown", 0)) + 6
		_j(e, "%s read the runes of %s (%s); it opened on %s." % [sage["name"], n["name"], r["txt"], relic["name"]], "discovery", _rec(e, rec))
		Chronicle.add("relic", "%s opened %s in %s and found %s." % [sage["name"], n["name"], region(e["dest"])["name"], relic["name"]], {"adv": sage["id"], "exp": e["id"]})
	else:
		_j(e, "%s puzzled over %s, but it stayed shut (%s)." % [sage["name"], n["name"], r["txt"]], "fail", _rec(e, rec))
	return 45


static func traveller(e: Dictionary, n: Dictionary) -> int:
	var healer := _best(e, "healing")
	var rec := {"kind": "traveller", "node": n["id"], "node_name": n["name"], "t": Game.now(), "checks": []}
	if not healer.is_empty():
		var r := _check(healer, "wis", 12, "healing")
		rec["checks"].append({"who": healer["name"], "what": "tend the wounded", "txt": r["txt"], "ok": r["ok"]})
		if r["ok"]:
			Regions.add_scouting(e["dest"], 4.0, "told by a grateful traveller")
			healer["renown"] = int(healer.get("renown", 0)) + 5
			var got := _loot(e, "gift", 1)
			_j(e, "%s tended %s (%s). In thanks: directions, and %s." % [healer["name"], n["name"].to_lower(), r["txt"], ", ".join(got) if not got.is_empty() else "a blessing"], "rescue", _rec(e, rec))
			return 40
	var got2 := _loot(e, str(n.get("loot", "trade")), 1)
	_j(e, "Found %s by the way%s." % [n["name"].to_lower(), (" — and " + ", ".join(got2)) if not got2.is_empty() else ""], "path", _rec(e, rec))
	return 30


## Rolls loot into the expedition's pack; returns the names (difficulty and tier raise the odds).
static func _loot(e: Dictionary, table: String, tier: int) -> Array:
	var items := Loot.roll_table(table, (tier - 1) * 8.0 + (float(diff().get("loot", 1.0)) - 1.0) * 30.0, tier * 2)
	items = items.slice(0, mini(items.size(), 1 + tier))
	var names := []
	for it in items:
		it["found"] = {"day": Game.day(), "where": region(e["dest"]).get("name", ""), "exp": e["id"]}
		e["loot"].append(it)
		names.append(Items.display_name(it))
	return names


# ======================================================================= combat
## A fight, round by round, with real dice and real equipment. Effects are applied as rolled; the
## record keeps every action with its timestamp so the observer can replay it in game time.
static func fight(e: Dictionary, n: Dictionary) -> int:
	var df := float(diff().get("enemy", 1.0))
	var foes := []
	var size_adj := maxi(0, (e["party"] as Array).size() - 2)
	for spec in n.get("enemies", []):
		var en: Dictionary = DB.enemies.get(spec[0], {})
		for i in int(spec[1]) + (size_adj if int(spec[1]) > 1 and en.get("power", 10) < 30 else 0):
			foes.append({"key": "%s_%d" % [spec[0], i], "id": spec[0], "name": en["name"] + ("" if int(spec[1]) == 1 else " %d" % (i + 1)),
				"kind": en["kind"], "hp": int(round(float(en["hp"]) * df)), "hp_max": int(round(float(en["hp"]) * df)), "atk": int(en["atk"]) + (1 if df > 1.1 else (-1 if df < 0.9 else 0)),
				"dmg": en["dmg"], "ac": int(en["ac"]), "weak": en.get("weak", ""), "resist": en.get("resist", ""), "xp": int(en["xp"]), "power": int(en.get("power", 10))})
	var rec := {"kind": "combat", "node": n["id"], "node_name": n["name"], "t": Game.now(), "boss": n.get("kind", "") == "boss",
		"enemies": foes.map(func(f): return {"key": f["key"], "id": f["id"], "name": f["name"], "kind": f["kind"], "hp_max": f["hp_max"], "weak": f["weak"], "resist": f["resist"], "ac": f["ac"]}),
		"party": [], "actions": [], "outcome": "", "xp": 0}
	for id in _standing(e):
		var a := Adv.get_a(id)
		var wp := weapon_profile(a)
		var w: Dictionary = wp["item"]
		rec["party"].append({"id": id, "name": a["name"], "cls": a["cls"], "hp": int(a["hp"]), "hp_max": int(a["hp_max"]), "ac": defence(a),
			"weapon": {"uid": w.get("uid", -1), "name": Items.display_name(w) if not w.is_empty() else "bare hands", "attack": Items.stat(w, "attack"),
				"rarity": w.get("rarity", "common"), "crafted": str(w.get("crafted_by", "")).begins_with("Brannoc")}})
	# ambush or first strike, decided by scouting
	var scout := _best(e, "scouting")
	if scout.is_empty():
		scout = _best(e, "traps")
	var first := false
	if not scout.is_empty():
		var sr := _check(scout, "wis", 12 + (2 if rec["boss"] else 0), "scouting")
		first = sr["ok"]
		rec["actions"].append({"t": 0, "kind": "scout", "actor": scout["name"], "txt": ("%s spotted them first (%s)" if first else "%s failed to spot the ambush (%s)") % [scout["name"], sr["txt"]]})
	var t := 1
	var inspired := false
	var guard_by := ""
	for rnd in 8:
		if foes.filter(func(f): return f["hp"] > 0).is_empty() or _standing(e).is_empty():
			break
		# the party acts
		for id in _standing(e):
			var a := Adv.get_a(id)
			var alive := foes.filter(func(f): return f["hp"] > 0)
			if alive.is_empty():
				break
			if has_skill(a, "inspire") and not inspired:
				inspired = true
				rec["actions"].append({"t": t, "kind": "inspire", "actor": a["name"], "txt": "%s struck up a battle-song: +1 to hit for all" % a["name"]})
				continue
			if has_skill(a, "guard") and guard_by == "":
				guard_by = a["id"]
			if has_skill(a, "healing"):
				var hurt := {}
				for oid in _standing(e):
					var o := Adv.get_a(oid)
					if float(o["hp"]) < float(o["hp_max"]) * 0.45 and (hurt.is_empty() or float(o["hp"]) / float(o["hp_max"]) < float(hurt["hp"]) / float(hurt["hp_max"])):
						hurt = o
				if not hurt.is_empty():
					var heal := int(Dice.roll("1d8")["total"]) + attr(a, "wis") + total(a, "magic") / 2
					hurt["hp"] = mini(int(hurt["hp_max"]), int(hurt["hp"]) + heal)
					rec["actions"].append({"t": t, "kind": "heal", "actor": a["name"], "target": hurt["name"], "heal": heal, "hp_after": int(hurt["hp"]),
						"parts": [["1d8", heal - attr(a, "wis") - total(a, "magic") / 2], ["wisdom", attr(a, "wis")], ["magic from gear", total(a, "magic") / 2]],
						"txt": "%s healed %s for %d" % [a["name"], hurt["name"], heal]})
					continue
			var tgt: Dictionary = alive[0] if not rec["boss"] else alive[alive.size() - 1]
			for f in alive:
				if f["hp"] < tgt["hp"]:
					tgt = f
			_attack(a, tgt, rec, t, first and rnd == 0, inspired)
			if tgt["hp"] <= 0:
				a["kills"] = int(a.get("kills", 0)) + 1
		t += STEP_MIN
		# the enemies act
		for f in foes:
			if f["hp"] <= 0:
				continue
			var st_ids := _standing(e)
			if st_ids.is_empty():
				break
			var victim := Adv.get_a(st_ids[randi() % st_ids.size()])
			# fighters and paladins step in front of the weakest
			if guard_by != "" and Adv.get_a(guard_by).get("hp", 0) > 0 and float(victim["hp"]) < float(victim["hp_max"]) * 0.5 and randf() < 0.6:
				var gd := Adv.get_a(guard_by)
				rec["actions"].append({"t": t, "kind": "guard", "actor": gd["name"], "target": victim["name"], "txt": "%s stepped in front of %s" % [gd["name"], victim["name"]]})
				victim = gd
			_enemy_attack(f, victim, rec, t)
			if float(victim["hp"]) < float(victim["hp_max"]) * 0.3 and float(victim["hp"]) > 0 and int(victim.get("potions", 0)) > 0:
				victim["potions"] = int(victim["potions"]) - 1
				var ph := int(float(victim["hp_max"]) * 0.4)
				victim["hp"] = mini(int(victim["hp_max"]), int(victim["hp"]) + ph)
				rec["actions"].append({"t": t, "kind": "potion", "actor": victim["name"], "heal": ph, "hp_after": int(victim["hp"]), "txt": "%s drank a healing draught (+%d)" % [victim["name"], ph]})
		t += STEP_MIN
		# morale: flee if the fight is going badly and nerve fails
		if rnd >= 2 and _party_frac(e) < 0.35 and foes.filter(func(f): return f["hp"] > 0).size() > 0:
			var lead := Adv.get_a(_standing(e)[0]) if not _standing(e).is_empty() else {}
			if not lead.is_empty() and float(lead["risk"]) < 0.8:
				var fr := _check(lead, "dex", 11)
				rec["actions"].append({"t": t, "kind": "flee", "actor": lead["name"], "txt": "%s ordered a retreat (%s)%s" % [lead["name"], fr["txt"], "" if fr["ok"] else " — cut off!"]})
				if fr["ok"]:
					rec["outcome"] = "retreat"
					break
	var won := foes.filter(func(f): return f["hp"] > 0).is_empty()
	if rec["outcome"] == "":
		rec["outcome"] = "victory" if won else ("defeat" if _standing(e).is_empty() else "retreat")
	var xp := 0
	for f in foes:
		if f["hp"] <= 0:
			xp += int(f["xp"])
	rec["xp"] = xp
	rec["duration"] = t + 10
	# wear: weapons dull, armour dents
	for id in e["party"]:
		_wear(Adv.get_a(id), rec)
	var names := foes.map(func(f): return f["name"])
	if won:
		e["xp"] = int(e.get("xp", 0)) + xp
		var purse := int(round(xp / 3.0 * float(diff().get("loot", 1.0))))
		e["gold"] = int(e["gold"]) + purse
		var got := _loot(e, str(n.get("loot", "")), int(n.get("tier", 1))) if str(n.get("loot", "")) != "" else []
		rec["loot"] = got
		var key_action := _key_moment(rec)
		_j(e, "Fought %s at %s and won%s.%s" % [_group_name(n), n["name"], (" — " + key_action) if key_action != "" else "", (" Loot: " + ", ".join(got) + ".") if not got.is_empty() else ""], "victory", _rec(e, rec))
		for id in _standing(e):
			var a := Adv.get_a(id)
			a["renown"] = int(a.get("renown", 0)) + (12 if rec["boss"] else 3)
			a["morale"] = minf(100.0, float(a["morale"]) + 6.0)
		if rec["boss"]:
			_boss_down(e, n, rec)
	else:
		_j(e, "Fought %s at %s — %s." % [_group_name(n), n["name"], "driven off" if rec["outcome"] == "retreat" else "overwhelmed"], "defeat", _rec(e, rec))
		e["outcome"] = "retreated" if rec["outcome"] == "retreat" else e["outcome"]
		for id in e["party"]:
			var a := Adv.get_a(id)
			a["morale"] = maxf(0.0, float(a["morale"]) - 15.0)
	# the fallen: death saves depend on difficulty
	_down_checks(e, rec)
	if rec["outcome"] == "retreat":
		e["outcome"] = "retreated"
		_force_home(e)
	return int(rec["duration"])


static func _force_home(e: Dictionary) -> void:
	e["route"] = (e["route"] as Array).slice(0, int(e["step"]) + 1)


static func _party_frac(e: Dictionary) -> float:
	var hp := 0.0
	var mx := 0.0
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") == "away":
			hp += maxf(0.0, float(a["hp"]))
			mx += float(a["hp_max"])
	return hp / maxf(1.0, mx)


## One attack by an adventurer, with every bonus written down. The weapon's real attack stat, its
## damage-type stats (fire/frost/magic from runes, coatings, enchantments) against the foe's weakness
## or resistance, quality, class affinity, attributes and level all go into the numbers.
static func _attack(a: Dictionary, f: Dictionary, rec: Dictionary, t: int, ambush: bool, inspired: bool) -> void:
	var wp := weapon_profile(a)
	var w: Dictionary = wp["item"]
	var spell := has_skill(a, "firebolt") and (Items.wtype(w) in ["staff", "dagger", "none"] or randf() < 0.6)
	var to_hit := int(wp["to_hit"]) + (1 if inspired else 0)
	var parts := []
	var roll := int(Dice.roll("1d20")["total"])
	var label := Items.display_name(w) if not w.is_empty() else "fists"
	var dmg := 0.0
	if spell:
		to_hit = attr(a, "int") + int(a["level"]) / 2 + (1 if inspired else 0)
		var mg := total(a, "magic")
		dmg = float(Dice.roll("1d8")["total"]) + attr(a, "int") + int(a["level"]) / 2 + mg * 0.6
		parts = [["firebolt 1d8 + int + level", int(dmg - mg * 0.6)], ["magic from gear (×0.6)", int(mg * 0.6)]]
		label = "a firebolt"
	else:
		dmg = float(wp["base"]) * randf_range(0.75, 1.25)
		parts = [["%s (attack %d ×0.55 + %s %d)" % [label, Items.stat(w, "attack"), "dex" if int(wp["main"]) == attr(a, "dex") else "str", int(wp["main"])], int(round(dmg))]]
		if int(wp["aff"]) > 0:
			parts.append(["%s favours a %s" % [a["cls"], wp["wtype"]], 0])
	var hit := roll + to_hit >= int(f["ac"]) or roll == 20
	var crit := roll == 20 or (ambush and has_skill(a, "sneak"))
	var act := {"t": t, "kind": "spell" if spell else "attack", "actor": a["name"], "actor_id": a["id"], "target": f["name"], "target_key": f["key"],
		"roll": roll, "mod": to_hit, "total": roll + to_hit, "vs": f["ac"], "hit": hit, "crit": crit, "weapon_uid": w.get("uid", -1), "weapon": label}
	if hit:
		# damage types: the foe's weakness multiplies, resistance cancels
		var elem := 0.0
		for d in ["fire", "frost", "magic"]:
			var v := float(total(a, d) + coat(w, d))
			if spell and d == "fire":
				v += 2.0
			if v <= 0.0:
				continue
			if str(f["resist"]) == d:
				parts.append(["%s resisted by %s" % [d, f["name"]], 0])
				continue
			var mult := 2.0 if str(f["weak"]) == d else 0.6
			elem += v * mult
			parts.append(["%s %d%s" % [d, int(v), " ×2 — its weakness!" if str(f["weak"]) == d else " ×0.6"], int(round(v * mult))])
		if str(f["resist"]) == "physical" and not spell:
			parts.append(["%s is barely touched by steel (×0.4)" % f["name"], -int(round(dmg * 0.6))])
			dmg *= 0.4
		if has_skill(a, "smite") and str(f["kind"]) in ["undead", "spirit"]:
			elem += 4.0
			parts.append(["smite against the dead", 4])
		if has_skill(a, "rage"):
			elem += 2.0
			parts.append(["rage", 2])
		if ambush and has_skill(a, "sneak"):
			parts.append(["sneak attack ×2", int(round(dmg))])
		dmg += elem
		if crit:
			dmg *= 2.0
		var total_dmg := maxi(1, int(round(dmg)))
		f["hp"] = int(f["hp"]) - total_dmg
		act["dmg"] = total_dmg
		act["hp_after"] = maxi(0, int(f["hp"]))
		act["parts"] = parts
		act["txt"] = "%s %s %s with %s: %d damage%s%s" % [a["name"], "critically struck" if crit else "hit", f["name"], label, total_dmg, " — slain" if f["hp"] <= 0 else "", ""]
		if not w.is_empty() and not spell:
			w["hits"] = int(w.get("hits", 0)) + 1
			if f["hp"] <= 0:
				w["kills"] = int(w.get("kills", 0)) + 1
	else:
		act["txt"] = "%s missed %s (d20 %d %+d = %d vs %d)" % [a["name"], f["name"], roll, to_hit, roll + to_hit, int(f["ac"])]
	rec["actions"].append(act)


static func _enemy_attack(f: Dictionary, v: Dictionary, rec: Dictionary, t: int) -> void:
	var roll := int(Dice.roll("1d20")["total"])
	var ac := defence(v)
	var hit := roll + int(f["atk"]) >= ac or roll == 20
	var act := {"t": t, "kind": "enemy", "actor": f["name"], "actor_key": f["key"], "target": v["name"], "target_id": v["id"],
		"roll": roll, "mod": int(f["atk"]), "total": roll + int(f["atk"]), "vs": ac, "hit": hit}
	if hit:
		var raw := int(Dice.roll(str(f["dmg"]))["total"]) * (2 if roll == 20 else 1)
		var prot := total(v, "protection")
		var red := int(round(prot * 0.12))
		var ward := 0
		if str(f["kind"]) in ["undead", "spirit"]:
			ward = total(v, "ward")
		var taken := maxi(1, raw - red - ward)
		v["hp"] = int(v["hp"]) - taken
		var armour: Dictionary = v["equipment"].get("armor", {})
		act["dmg"] = taken
		act["hp_after"] = int(v["hp"])
		act["parts"] = [[str(f["dmg"]), raw], ["armour (protection %d ×0.12)" % prot, -red]]
		if ward > 0:
			act["parts"].append(["ward against the dead", -ward])
		act["armour_uid"] = armour.get("uid", -1)
		act["absorbed"] = red + ward
		act["txt"] = "%s hit %s for %d%s" % [f["name"], v["name"], taken, (" (armour turned %d)" % (red + ward)) if red + ward > 0 else ""]
		if int(v["hp"]) <= 0:
			act["txt"] += " — %s is down!" % v["name"]
	else:
		act["txt"] = "%s missed %s (d20 %d %+d = %d vs %d)" % [f["name"], v["name"], roll, int(f["atk"]), roll + int(f["atk"]), ac]
		act["parts"] = [["defence: 10 + dex + protection ×0.25", ac]]
	rec["actions"].append(act)


static func _wear(a: Dictionary, rec: Dictionary) -> void:
	if a.get("status", "") != "away":
		return
	var w: Dictionary = a["equipment"].get("weapon", {})
	var stw: Dictionary = w.get("stats", {})
	var swings: int = rec["actions"].filter(func(x): return x.get("actor", "") == a["name"] and x.get("kind", "") == "attack").size()
	if stw.has("durability") and swings > 0:
		stw["durability"] = maxi(0, int(stw["durability"]) - swings * 2)
		if int(stw["durability"]) == 0 and not w.get("broken", false):
			w["broken"] = true
			Items.add_history(w, "Broke in %s's hands at %s." % [a["name"], rec["node_name"]])
			rec["actions"].append({"t": int(rec.get("duration", 10)), "kind": "break", "actor": a["name"], "txt": "%s's %s broke!" % [a["name"], w.get("name", "weapon")]})
	var arm: Dictionary = a["equipment"].get("armor", {})
	var sta: Dictionary = arm.get("stats", {})
	var hits: int = rec["actions"].filter(func(x): return x.get("target", "") == a["name"] and x.get("kind", "") == "enemy" and x.get("hit", false)).size()
	if sta.has("durability") and hits > 0:
		sta["durability"] = maxi(0, int(sta["durability"]) - hits * 3)


static func _key_moment(rec: Dictionary) -> String:
	var best := {}
	for x in rec["actions"]:
		if x.get("kind", "") in ["attack", "spell"] and x.get("hit", false) and (best.is_empty() or int(x.get("dmg", 0)) > int(best.get("dmg", 0))):
			best = x
	if best.is_empty():
		return ""
	return "%s's %s with %s dealt %d" % [best["actor"], "critical strike" if best.get("crit", false) else "best blow", best.get("weapon", "a blade"), int(best["dmg"])]


static func _group_name(n: Dictionary) -> String:
	var parts := []
	for spec in n.get("enemies", []):
		var en: Dictionary = DB.enemies.get(spec[0], {})
		parts.append(("%d × %s" % [int(spec[1]), en.get("name", spec[0])]) if int(spec[1]) > 1 else en.get("name", spec[0]))
	return " and ".join(parts)


## Downed adventurers: on Apprentice nobody dies; otherwise a death save against the difficulty.
static func _down_checks(e: Dictionary, rec: Dictionary) -> void:
	if _standing(e).is_empty():
		return   # the whole party is down: what became of them is decided (and kept secret) in _wipe
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") != "away" or float(a["hp"]) > 0.0:
			continue
		if not bool(diff().get("death", true)) or not _standing(e).is_empty() and has_healer_standing(e):
			a["hp"] = 1
			_j(e, "%s was dragged clear, badly wounded." % a["name"], "wound")
			continue
		var save := int(Dice.roll("1d20")["total"]) + attr(a, "con")
		var dc := int(diff().get("death_dc", 7))
		rec.get("actions", []).append({"t": int(rec.get("duration", 10)), "kind": "death_save", "actor": a["name"], "txt": "%s's death save: d20 + con = %d vs %d — %s" % [a["name"], save, dc, "survives" if save >= dc else "falls"]})
		if save >= dc:
			a["hp"] = 1
			a["deaths_cheated"] = int(a.get("deaths_cheated", 0)) + 1
			_j(e, "%s fell, but clung to life (death save %d vs %d)." % [a["name"], save, dc], "wound")
		else:
			_kill(e, a, rec.get("node_name", "the wilds"))


static func has_healer_standing(e: Dictionary) -> bool:
	for id in _standing(e):
		if has_skill(Adv.get_a(id), "healing"):
			return true
	return false


static func _kill(e: Dictionary, a: Dictionary, where: String) -> void:
	a["status"] = "dead"
	a["died_day"] = Game.day()
	a["activity"] = "fallen"
	a["hp"] = 0
	_j(e, "%s fell at %s." % [a["name"], where], "death")
	a["last_report"] = "%s fell at %s, %s." % [a["name"], where, region(e["dest"]).get("name", "")]
	# companions grieve; the smith's work is judged
	for oid in e["party"]:
		if oid != a["id"]:
			var o := Adv.get_a(oid)
			o["morale"] = maxf(0.0, float(o["morale"]) - 25.0)
			if relation(o, a["id"]) > 20.0:
				o["achievements"].append({"day": Game.day(), "text": "Lost %s at %s." % [a["name"], where]})
	var mine := Adv._crafted_by_player(a)
	Adv._die_consequences(a, mine, region(e["dest"]).get("name", where))


static func _boss_down(e: Dictionary, n: Dictionary, rec: Dictionary) -> void:
	var foe_kind: String = str(rec["enemies"][0]["kind"]) if not rec["enemies"].is_empty() else "beast"
	var boss_name: String = str(rec["enemies"][0]["name"]) if not rec["enemies"].is_empty() else n["name"]
	# whose blow felled it, and with what
	var killer := {}
	for x in rec["actions"]:
		if x.get("kind", "") in ["attack", "spell"] and x.get("target_key", "") == str(rec["enemies"][0].get("key", "")) and int(x.get("hp_after", 1)) == 0:
			killer = x
	var names: Array = e["party"].map(func(i): return Adv.get_a(i)["name"])
	Chronicle.add("victory", "%s defeated %s in %s." % [_and(names), boss_name, region(e["dest"])["name"]], {"party": e["party"], "exp": e["id"], "dest": e["dest"]}, true)
	for id in _standing(e):
		achieve(Adv.get_a(id), "Defeated %s." % boss_name, 25)
	if killer.is_empty():
		return
	var a := Adv.get_a(str(killer.get("actor_id", "")))
	var w := Game.find_uid_anywhere(int(killer.get("weapon_uid", -1)))
	if a.is_empty() or w.is_empty():
		return
	Items.add_history(w, "Felled %s in %s, wielded by %s." % [boss_name, region(e["dest"])["name"], a["name"]])
	# exceptional work earns a name of its own
	if not w.has("title") and str(w.get("crafted_by", "")).begins_with("Brannoc"):
		var bane: String = BANE.get("spider" if boss_name.contains("Brood") else foe_kind, "Banebringer")
		w["title"] = "The " + bane
		w["base_name"] = w.get("name", "")
		w["name"] = "The %s" % bane
		Items.add_history(w, "Named “The %s” after the deed." % bane)
		Chronicle.add("legend", "The blade %s forged — now called The %s — felled %s." % ["Brannoc", bane, boss_name], {"adv": a["id"], "item": str(w["uid"])}, true)
		Events.toast.emit("Your work has a name now: The %s (%s's blade)." % [bane, a["name"]], "legendary")
	# an unexpected hero: a green adventurer, the smith's gear, a mighty foe
	if int(a["level"]) <= 3 and str(w.get("crafted_by", "")).begins_with("Brannoc") and not a.get("unexpected_hero", false):
		a["unexpected_hero"] = true
		achieve(a, "Stood against %s and struck it down — the unexpected hero of %s." % [boss_name, region(e["dest"])["name"]], 60)
		Social.change(a["id"], 15.0, 10.0, "hero_blade", "I'd be dead without the blade Brannoc made me.")
		Chronicle.add("chain", "An unexpected hero: young %s felled %s with a blade from the Ironhand forge." % [a["name"], boss_name], {"adv": a["id"], "item": str(w["uid"])}, true)


# ======================================================================= wipes, missing, returns
static func _wipe(e: Dictionary) -> void:
	var names: Array = e["party"].map(func(i): return Adv.get_a(i)["name"])
	if not bool(diff().get("death", true)):
		_j(e, "Every one of them fell — but passing woodcutters carried them home.", "rescue")
		for id in e["party"]:
			Adv.get_a(id)["hp"] = 1
		e["outcome"] = "rescued"
		_go_home(e)
		return
	e["outcome"] = "missing"
	e["phase"] = "done"
	e["end"] = Game.now()
	_j(e, "The party did not come back from %s." % node_of(e["dest"], str(e["at"])).get("name", "the wilds"), "missing")
	var w: Dictionary = Game.state["world"]
	if not w.has("missing"):
		w["missing"] = {}
	for id in e["party"]:
		var a := Adv.get_a(id)
		if a.get("status", "") != "away":
			continue
		# the truth is decided now (a death save against the difficulty), revealed later
		var save := int(Dice.roll("1d20")["total"]) + attr(a, "con")
		var alive := save >= int(diff().get("death_dc", 7))
		a["status"] = "missing"
		a["activity"] = "missing"
		w["missing"][id] = {"dest": e["dest"], "node": e["at"], "since": Game.day(), "alive": alive, "exp": e["id"], "searched": false}
	Chronicle.add("missing", "%s did not return from %s." % [_and(names), region(e["dest"])["name"]], {"party": e["party"], "exp": e["id"], "dest": e["dest"]}, true)
	Events.toast.emit("%s have not come back from %s." % [_and(names), region(e["dest"])["name"]], "bad")
	_archive(e)


## Days pass for the missing: some limp home, some are found, some are never seen alive again.
static func check_missing() -> void:
	var w: Dictionary = Game.state["world"]
	for id in w.get("missing", {}).keys():
		var mi: Dictionary = w["missing"][id]
		var a := Adv.get_a(id)
		if a.is_empty() or a["status"] != "missing":
			w["missing"].erase(id)
			continue
		var days := Game.day() - int(mi["since"])
		if Game.hour() != 12:
			continue
		if mi["alive"] and days >= 2 and randf() < 0.35:
			_come_home(a, "limped home from %s, half-starved" % region(mi["dest"])["name"])
			w["missing"].erase(id)
		elif days >= 6:
			_reveal_fate(a, mi, "")
			w["missing"].erase(id)


static func _come_home(a: Dictionary, how: String) -> void:
	a["status"] = "injured"
	a["injured_days"] = 3
	a["hp"] = maxi(1, int(a["hp_max"]) / 4)
	a["activity"] = "recovering"
	Chronicle.add("rescue", "%s %s." % [a["name"], how], {"adv": a["id"]}, true)
	Events.toast.emit("%s %s!" % [a["name"], how], "good")
	Events.adventurer_returned.emit(a["id"], a.get("exit", "south"))


static func _reveal_fate(a: Dictionary, mi: Dictionary, finder: String) -> void:
	if mi["alive"]:
		_come_home(a, "was found alive%s" % ((" by " + finder) if finder != "" else ""))
		return
	a["status"] = "dead"
	a["died_day"] = Game.day()
	a["activity"] = "fallen"
	Chronicle.add("death", "%s's fate is known at last: %s fell in %s." % [a["name"], a["name"], region(mi["dest"])["name"]], {"adv": a["id"]}, true)
	Adv._die_consequences(a, Adv._crafted_by_player(a), region(mi["dest"])["name"])
	# a finder brings the lost weapon home
	if finder != "":
		var w: Dictionary = a["equipment"].get("weapon", {})
		if not w.is_empty():
			a["equipment"].erase("weapon")
			Items.add_history(w, "Recovered from %s's body by %s." % [a["name"], finder])
			w["owner"] = "smith"
			Game.state["returns"].append(Loot.make_container("chest_recovered", [w], finder, "%s brought back %s's weapon: \"It should come home to the forge that made it.\"" % [finder, a["name"]]))
			Events.inventory_changed.emit()


## Home again: wounds, experience, levels, loot, gold, renown, the smith's work judged.
static func finish(e: Dictionary) -> void:
	e["phase"] = "done"
	e["end"] = Game.now()
	var reg := region(e["dest"])
	# a search party at the place the missing were lost finds them
	if e.get("goal", "") == "search":
		var w: Dictionary = Game.state["world"]
		for mid in w.get("missing", {}).keys():
			var mi: Dictionary = w["missing"][mid]
			if str(mi["dest"]) == e["dest"] and (e["explored"] as Array).has(str(mi["node"])):
				var finder: String = Adv.get_a(e["leader"]).get("name", "a search party")
				_j(e, "Found %s at %s." % [Adv.get_a(mid)["name"], node_of(e["dest"], str(mi["node"])).get("name", "")], "rescue")
				_reveal_fate(Adv.get_a(mid), mi, finder)
				w["missing"].erase(mid)
				for id in e["party"]:
					achieve(Adv.get_a(id), "Searched %s for the missing." % reg["name"], 15)
	var alive: Array = (e["party"] as Array).filter(func(i): return Adv.get_a(i).get("status", "") == "away")
	var share := int(e["gold"]) / maxi(1, alive.size())
	var xp_each := int(e.get("xp", 0)) / maxi(1, alive.size())
	for id in alive:
		var a := Adv.get_a(id)
		a["gold"] = int(a["gold"]) + share
		a["xp"] = int(a["xp"]) + xp_each
		while int(a["xp"]) >= int(a["level"]) * 100:
			a["xp"] = int(a["xp"]) - int(a["level"]) * 100
			a["level"] = int(a["level"]) + 1
			a["hp_max"] = hp_max(a)
			Chronicle.add("levelup", "%s reached level %d." % [a["name"], a["level"]], {"adv": id})
		var wounded := float(a["hp"]) < float(a["hp_max"]) * 0.5
		a["status"] = "injured" if wounded else "in_town"
		a["injured_days"] = (2 if wounded else 0)
		a["activity"] = "recovering" if wounded or float(a["fatigue"]) > 50.0 else "at_inn"
		a["depart_day"] = Game.day() + randi_range(1, 2) + (1 if wounded else 0)
		a.erase("exp")
		for oid in alive:
			if oid != id:
				relate(id, oid, 2.0)
	# the loot: gear goes to whoever it suits; materials and relics are offered to the smith
	_share_loot(e, alive)
	var outcome: String = e["outcome"] if e["outcome"] != "" else "returned"
	var won: int = (e["encounters"] as Array).filter(func(r): return r.get("outcome", "") == "victory").size()
	var names: Array = alive.map(func(i): return Adv.get_a(i)["name"])
	var summary := "%s came home from %s: %d fight%s won, %d gold%s." % [_and(names), reg["name"], won, "" if won == 1 else "s", int(e["gold"]),
		" — they retreated" if outcome == "retreated" else ""]
	e["summary"] = summary
	_j(e, summary, "return")
	for id in alive:
		var a := Adv.get_a(id)
		a["last_report"] = summary
		a["history"].append({"day": Game.day(), "dest": e["dest"], "outcome": "success" if won > 0 and outcome != "retreated" else "failed", "exp": e["id"]})
		while a["history"].size() > 8:
			a["history"].pop_front()
		if won > 0:
			a["victories"] = int(a.get("victories", 0)) + 1
	Chronicle.add("return", summary, {"party": e["party"], "exp": e["id"], "dest": e["dest"]}, true)
	_judge_gear(e, alive)
	Regions.add_scouting(e["dest"], 0.6)
	for id in alive:
		Events.adventurer_returned.emit(id, DB.destinations.get(e["dest"], {}).get("exit", "north"))
		var a := Adv.get_a(id)
		a["needs"] = Adv._weakest_slot(a)
		Adv.plan_next(a)
		# the broken blade: back for repairs, and maybe something better
		var w: Dictionary = a["equipment"].get("weapon", {})
		if w.get("broken", false):
			Shop._add_customer(id, "repair_own")
			if Shop.open_orders().filter(func(o): return o["npc"] == id).is_empty():
				Shop.create_order(id, "weapon", "My %s broke at %s. Mend it — or make me something that won't." % [w.get("name", "blade"), reg["name"]])
			Chronicle.add("chain", "%s came home with a broken %s." % [a["name"], w.get("name", "blade")], {"adv": id, "item": str(w.get("uid", ""))})
	Audio.play("sfx/door_bell", -6.0)
	_archive(e)


static func _share_loot(e: Dictionary, alive: Array) -> void:
	var offers := []
	for it in e["loot"]:
		var placed := false
		if Items.is_equipment(it):
			for id in alive:
				var a := Adv.get_a(id)
				var s := Items.slot(it)
				if Items.score(it) > Items.score(a["equipment"].get(s, {})) + 1.0:
					if a["equipment"].has(s):
						a["loot"].append(a["equipment"][s])
					a["equipment"][s] = it
					it["owner"] = id
					Items.add_history(it, "Found in %s by %s." % [region(e["dest"])["name"], a["name"]])
					placed = true
					break
		if not placed and alive.size() > 0:
			offers.append(it)
	var notable := []
	for it in offers:
		var seller := Adv.get_a(alive[randi() % alive.size()])
		Shop.add_offer(seller["id"], it, false)
		if Regions.is_unidentified(it) or it.get("rarity", "common") in ["rare", "legendary", "unique"] or DB.item(it["def"]).get("tags", []).has("rare"):
			notable.append(Items.display_name(it))
	if not notable.is_empty():
		var who := Adv.get_a(alive[0])
		Chronicle.add("discovery", "%s's party brought home %s — offered to the forge." % [who["name"], ", ".join(notable.slice(0, 3)) + (" and more" if notable.size() > 3 else "")], {"party": e["party"], "exp": e["id"]}, true)
		Events.toast.emit("Returning adventurers offer you %s — see the shop counter." % ", ".join(notable.slice(0, 2)), "good")
	for id in alive:
		Adv.get_a(id)["loot_value"] = int(Adv.get_a(id).get("loot_value", 0)) + int(e["gold"]) / maxi(1, alive.size())


## Did the smith's work matter? Credit the pieces that landed blows and turned them.
static func _judge_gear(e: Dictionary, alive: Array) -> void:
	for id in e["party"]:
		var a := Adv.get_a(id)
		for slot in a["equipment"]:
			var it: Dictionary = a["equipment"][slot]
			if not str(it.get("crafted_by", "")).begins_with("Brannoc"):
				continue
			var dealt := 0
			var turned := 0
			for rec in e["encounters"]:
				for x in rec.get("actions", []):
					if int(x.get("weapon_uid", -2)) == int(it.get("uid", -1)) and x.get("hit", false):
						dealt += int(x.get("dmg", 0))
					if int(x.get("armour_uid", -2)) == int(it.get("uid", -1)):
						turned += int(x.get("absorbed", 0))
			if dealt + turned <= 0:
				continue
			it["deeds"] = int(it.get("deeds", 0)) + 1
			Items.add_history(it, "%s at %s: %s." % [a["name"], region(e["dest"])["name"], ("dealt %d damage" % dealt) if dealt > 0 else ("turned %d damage" % turned)])
			if alive.has(id):
				Social.change(id, 3.0 + minf(8.0, (dealt + turned) / 12.0), 3.0, "gear_" + e["id"], "Your %s %s at %s." % [it["name"], "struck true" if dealt > 0 else "held", region(e["dest"])["name"]])
				Shop.rep_change(0.8)


static func _archive(e: Dictionary) -> void:
	active().erase(e["id"])
	done().push_front(e)
	while done().size() > 25:
		done().pop_back()
	Events.expeditions_changed.emit()


## What an adventurer says when asked about their last expedition: drawn from its real journal.
static func tale(adv_id: String) -> String:
	var a := Adv.get_a(adv_id)
	var cur := exp_of(adv_id)
	if not cur.is_empty():
		return ""
	var last := {}
	for e in done():
		if (e["party"] as Array).has(adv_id):
			last = e
			break
	if last.is_empty():
		return ""
	var reg: String = region(last["dest"]).get("name", "the wilds")
	var lines := []
	for j in last["journal"]:
		if str(j["kind"]) in ["victory", "defeat", "death", "trap", "discovery", "loot", "rescue", "wound", "retreat"]:
			lines.append(str(j["text"]))
	var picked: Array = lines.slice(maxi(0, lines.size() - 4))
	var mood: String = {"returned": "We came back with our heads high.", "retreated": "We turned back. No shame in living.", "missing": "", "rescued": "I don't remember the end of it. Woodcutters, they say."}.get(str(last["outcome"]), "")
	var weapon: Dictionary = a.get("equipment", {}).get("weapon", {})
	var praise := ""
	if str(weapon.get("crafted_by", "")).begins_with("Brannoc"):
		praise = " Your %s held the whole way." % Items.display_name(weapon) if not weapon.get("broken", false) else " Your %s broke on the way — I need it mended." % Items.display_name(weapon)
	return "\"%s, day %d. %s%s\"\n\n[i]%s[/i]" % [reg, int(last["journal"][-1]["day"]) if not (last["journal"] as Array).is_empty() else Game.day(), mood, praise, "\n".join(picked.map(func(x): return "— " + str(x)))]


# ======================================================================= helpers
static func snapshot(a: Dictionary) -> Dictionary:
	var eq := {}
	for s in a["equipment"]:
		var it: Dictionary = a["equipment"][s]
		eq[s] = {"uid": it.get("uid", -1), "name": Items.display_name(it), "rarity": it.get("rarity", "common"), "attack": Items.stat(it, "attack"),
			"protection": Items.stat(it, "protection"), "crafted": str(it.get("crafted_by", "")).begins_with("Brannoc")}
	return {"level": a["level"], "hp": a["hp"], "hp_max": a["hp_max"], "equipment": eq}


static func _rec(e: Dictionary, rec: Dictionary) -> int:
	rec["party_snap"] = {}
	for id in e["party"]:
		rec["party_snap"][id] = snapshot(Adv.get_a(id))
	e["encounters"].append(rec)
	return e["encounters"].size() - 1


static func _j(e: Dictionary, text: String, kind: String, rec := -1) -> void:
	var entry := {"t": Game.now(), "time": Game.time_string(), "day": Game.day(), "text": text, "kind": kind, "rec": rec}
	e["journal"].append(entry)


static func _lead_name(e: Dictionary) -> String:
	return Adv.get_a(e["leader"]).get("name", "The leader")


static func _and(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


## Where the party is on the region map right now (for the observer): interpolated along the leg.
static func marker_pos(e: Dictionary) -> Vector2:
	var leg: Dictionary = e["leg"]
	var a := _pt(e["dest"], str(leg["from"]))
	var b := _pt(e["dest"], str(leg["to"]))
	var span := maxf(1.0, float(leg["t1"]) - float(leg["t0"]))
	var f := clampf((float(Game.now()) - float(leg["t0"])) / span, 0.0, 1.0)
	if e["phase"] in ["acting", "done"]:
		f = 1.0
	return a.lerp(b, f)


static func _pt(rid: String, nid: String) -> Vector2:
	if nid == "village":
		var g := node_of(rid, "gate")
		var gp := Vector2(float(g.get("x", 0)), float(g.get("y", 0)))
		return gp + (gp - Vector2(640, 360)).normalized() * 70.0
	var n := node_of(rid, nid)
	return Vector2(float(n.get("x", 0)), float(n.get("y", 0)))


static func status_word(a: Dictionary) -> String:
	ensure(a)
	match str(a.get("status", "")):
		"dead":
			return "Fallen"
		"missing":
			return "Missing"
		"injured":
			return "Recovering"
		"away":
			return {"adventuring": "Adventuring", "returning": "Returning"}.get(a.get("activity", ""), "Adventuring")
	return {"recruiting": "Recruiting", "preparing": "Preparing", "recovering": "Recovering"}.get(a.get("activity", ""), "At the Inn")
