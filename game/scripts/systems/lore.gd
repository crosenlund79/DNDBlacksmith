## Lore — the world's single memory (R3 "One History": GOV-031, LORE-017, LORE-002, LORE-005 … LORE-008, LORE-014,
## TECH-024, BUG-018).
## EN: Every significant happening (a forging, a sale, a battle, a discovery, a death, a repair, a naming) is ONE event
##     with a stable id; items, adventurers, places and the Chronicle keep only the ids.
##     Event: {id, t, day, time, kind, text, actors[ids], items[uids], place, importance 0–3, icon, data{},
##             roles{actor: role}?, because[event ids]?, chron?, refs?}.
##     • The Chronicle is a VIEW of Lore: a news-feed entry is a Lore event carrying `chron` (its feed kind) and
##       `refs` (what the feed links to); the ids in order live in `chron_ids`. Nothing is written twice and nothing
##       falls off a capped feed any more (save step 11 converted older saves' separate feed).
##     • Roles and causal links: `roles` names what each actor did (e.g. "fell", "heir"), `because` lists the events
##       that led to this one (a death because of a battle, an inheritance because of a death, an Epic award because
##       of the deed). why(id) walks the chain back; consequences(id) walks it forward.
##     • Indices by kind, actor, item and place are built on demand (not saved) and kept up to date as events arrive.
##     • Retention (decision 6, the audit's default): provenance, people, places, deaths, Epic, named pieces, the
##       Chronicle and anything a causal link points at are kept for ever. Routine workshop work on ordinary pieces
##       (importance 0: notes, repairs, sharpening, treatments) older than ROUTINE_AGE days is folded, month by month
##       and piece by piece, into one "digest" event that counts what happened and when. Every folded id still
##       resolves (to its digest) through `folded`, so no item, tombstone or person's history ever points at nothing.
## DA: Verdens fælles hukommelse — én begivenhed, mange henvisninger; Krøniken er en visning af den.
class_name Lore

## Routine work older than this many days is folded into monthly digests.
const ROUTINE_AGE := 60
const ROUTINE_KINDS := ["note", "repaired", "sharpened", "treated"]
## Folding runs at most this often (days).
const COMPACT_EVERY := 30
const ICONS := {
	# existing sprites only (no new art): the history view shows these beside each entry
	"forged": "ui/act_hammer", "sold": "icons/purse_gift", "bought": "icons/purse_gift", "given": "icons/purse_gift",
	"found": "icons/chest_recovered", "looted": "icons/bag_traveller", "inherited": "ui/act_candle", "recovered": "icons/chest_recovered",
	"repaired": "ui/act_hammer", "reforged": "ui/act_hammer", "sharpened": "ui/act_hammer", "enchanted": "icons/runestone_ember",
	"treated": "icons/potion_healing", "battle": "ui/stat_damage", "slew": "icons/sword_iron", "survived": "ui/stat_defence",
	"discovery": "icons/relic_map", "named": "icons/star", "epic": "icons/star", "deed": "icons/star", "awakened": "ui/ic_talk",
	"lost": "ui/warn_broken", "destroyed": "ui/warn_broken", "death": "ui/act_candle", "returned": "ui/ic_home", "pawned": "icons/purse_gift",
	"redeemed": "icons/purse_gift", "commission": "icons/recipe_scroll", "cleared": "icons/relic_map", "reunion": "ui/ic_home",
	"note": "ui/ic_history", "threat": "ui/warn_worn", "arrival": "ui/act_road", "identified": "icons/relic_map", "departed": "ui/act_road",
	"digest": "ui/ic_history",
}

static var _causes: Array = []
static var _idx := {}
static var _idx_for: Dictionary = {}
static var _idx_n := -1


static func st() -> Dictionary:
	if not Game.state.has("lore"):
		Game.state["lore"] = {"events": {}, "next": 1, "order": []}
	var s: Dictionary = Game.state["lore"]
	if not s.has("chron_ids"):
		s["chron_ids"] = []
	if not s.has("folded"):
		s["folded"] = {}
	return s


## Records one event and links it to every item, adventurer and place it involves. Returns the event id.
## opts: actors (Array of ids), items (Array of item dicts or uids), place (String), importance (0–3), icon,
##       data (Dictionary), roles ({actor: role}), because (Array of event ids), chronicle (bool: also an entry of
##       the news feed), notable (bool: journal it too), refs (the feed's links, for Chronicle entries).
static func record(kind: String, text: String, opts := {}) -> String:
	var e := _make(kind, text, opts)
	var id := str(e["id"])
	# link: items carry the id in their provenance, adventurers in their lore list
	for x in opts.get("items", []):
		if x is Dictionary and not (x as Dictionary).is_empty():
			Provenance.link(x, id)
	_link_actors(e)
	if not bool(opts.get("quiet", false)) and (e["place"] != "" or int(e["importance"]) >= 1):
		Events.lore_recorded.emit(e)
	if bool(opts.get("chronicle", false)):
		var refs := {"event": id}
		if not (e["actors"] as Array).is_empty():
			refs["adv"] = e["actors"][0]
			if (e["actors"] as Array).size() > 1:
				refs["party"] = e["actors"]
		if not (e["items"] as Array).is_empty():
			refs["item"] = str(e["items"][0])
		if e["place"] != "":
			refs["place"] = e["place"]
		Chronicle.add(kind, text, refs, bool(opts.get("notable", false)))
	return id


static func _make(kind: String, text: String, opts: Dictionary) -> Dictionary:
	var s := st()
	var id := "ev_%d" % int(s["next"])
	s["next"] = int(s["next"]) + 1
	var uids: Array = []
	for x in opts.get("items", []):
		var u := int(x.get("uid", -1)) if x is Dictionary else int(x)
		if u > 0 and not uids.has(u):
			uids.append(u)
	var e := {"id": id, "t": int(opts.get("t", Game.now())), "day": int(opts.get("day", Game.day())),
		"time": str(opts.get("time", Game.time_string())), "kind": kind, "text": text,
		"actors": (opts.get("actors", []) as Array).duplicate(), "items": uids, "place": str(opts.get("place", "")),
		"importance": int(opts.get("importance", 1)), "icon": str(opts.get("icon", ICONS.get(kind, "ui/ic_history"))),
		"data": (opts.get("data", {}) as Dictionary).duplicate(true)}
	if opts.get("roles") is Dictionary and not (opts["roles"] as Dictionary).is_empty():
		e["roles"] = (opts["roles"] as Dictionary).duplicate()
	var because := []
	var src: Array = (opts.get("because", []) as Array).duplicate()
	if not _causes.is_empty() and not bool(opts.get("no_cause", false)):
		src.append(_causes[-1])
	for b in src:
		if str(b) != "" and not because.has(str(b)):
			because.append(str(b))
	if not because.is_empty():
		e["because"] = because
	s["events"][id] = e
	(s["order"] as Array).append(id)
	_index_add(e)
	return e


static func _link_actors(e: Dictionary) -> void:
	for a_id in e["actors"]:
		var a := Adv.get_a(str(a_id))
		if not a.is_empty():
			if not a.has("lore"):
				a["lore"] = []
			(a["lore"] as Array).append(str(e["id"]))


## Everything recorded until pop_cause() happened because of `id` (a death → the heirs' inheritance and the burial;
## a boss slain → the Epic it earns). Nested causes: the innermost wins.
static func push_cause(id: String) -> void:
	_causes.append(id)


static func pop_cause() -> void:
	if not _causes.is_empty():
		_causes.pop_back()


## The Chronicle's writer: makes `id` (an existing event) a news-feed entry, or records a new event for a feed entry
## that had none. Returns the event.
static func chronicle(kind: String, text: String, refs: Dictionary, notable: bool) -> Dictionary:
	var s := st()
	var e := event(str(refs.get("event", "")))
	if e.is_empty():
		var actors := []
		if str(refs.get("adv", "")) != "":
			actors.append(str(refs["adv"]))
		for p in refs.get("party", []):
			if not actors.has(str(p)):
				actors.append(str(p))
		var items := []
		for k in ["item", "uid"]:
			var u := str(refs.get(k, ""))
			if u.is_valid_int() and int(u) > 0:
				items.append(int(u))
		e = _make(kind, text, {"actors": actors, "items": items, "place": str(refs.get("place", "")),
			"importance": 2 if notable else 1, "data": {"feed": true}})
		_link_actors(e)
		refs = refs.duplicate()
		refs["event"] = str(e["id"])
	e["chron"] = kind
	e["refs"] = refs.duplicate(true)
	if not (s["chron_ids"] as Array).has(str(e["id"])):
		(s["chron_ids"] as Array).append(str(e["id"]))
	return e


## One event by id; a folded routine event resolves to its digest.
static func event(id: String) -> Dictionary:
	var s := st()
	var e: Dictionary = s["events"].get(id, {})
	if e.is_empty() and s["folded"].has(id):
		return s["events"].get(str(s["folded"][id]), {})
	return e


## Events in chronological order for a list of ids (folded ones resolve to their digest, each event once).
static func events(ids: Array) -> Array:
	var out := []
	var seen := {}
	for id in ids:
		var e := event(str(id))
		if not e.is_empty() and not seen.has(e["id"]):
			seen[e["id"]] = true
			out.append(e)
	out.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]) or (int(a["t"]) == int(b["t"]) and int(str(a["id"]).substr(3)) < int(str(b["id"]).substr(3))))
	return out


# ------------------------------------------------------------------ indices
static func _index() -> Dictionary:
	var s := st()
	if not is_same(_idx_for, s) or _idx_n != (s["order"] as Array).size():
		_idx = {"kind": {}, "actor": {}, "item": {}, "place": {}, "because": {}}
		_idx_for = s
		_idx_n = -1   # _index_add counts while rebuilding
		var n := 0
		for id in s["order"]:
			var e: Dictionary = s["events"].get(id, {})
			if not e.is_empty():
				_put(e)
			n += 1
		_idx_n = n
	return _idx


static func _put(e: Dictionary) -> void:
	var id := str(e["id"])
	_add_to(_idx["kind"], str(e.get("kind", "")), id)
	for a in e.get("actors", []):
		_add_to(_idx["actor"], str(a), id)
	for u in e.get("items", []):
		_add_to(_idx["item"], str(u), id)
	if str(e.get("place", "")) != "":
		_add_to(_idx["place"], str(e["place"]), id)
	for b in e.get("because", []):
		_add_to(_idx["because"], str(b), id)


static func _add_to(d: Dictionary, k: String, id: String) -> void:
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(id)


static func _index_add(e: Dictionary) -> void:
	var s := st()
	if is_same(_idx_for, s) and _idx_n == (s["order"] as Array).size() - 1:
		_put(e)
		_idx_n += 1


static func _ids(dim: String, key: String) -> Array:
	return _index()[dim].get(key, [])


static func of_kind(kind: String) -> Array:
	return events(_ids("kind", kind))


static func of_item(uid: int) -> Array:
	var ids: Array = _ids("item", str(uid)).duplicate()
	var it := Game.find_uid_anywhere(uid)
	if not it.is_empty():
		ids.append_array(Provenance.st(it).get("events", []))
	else:
		var tb := ItemRegistry.tombstone_of(uid)
		ids.append_array(tb.get("events", []))
	return events(ids)


static func of_actor(actor: String) -> Array:
	var ids: Array = _ids("actor", actor).duplicate()
	var a := Adv.get_a(actor)
	if not a.is_empty():
		ids.append_array(a.get("lore", []))
	return events(ids)


static func of_place(place: String) -> Array:
	return events(_ids("place", place))


## The events that led to `id`, nearest first, then theirs (each once, up to `depth` steps back).
static func why(id: String, depth := 6) -> Array:
	var out := []
	var seen := {id: true}
	var frontier := [id]
	for d in depth:
		var nxt := []
		for x in frontier:
			for b in event(str(x)).get("because", []):
				if not seen.has(str(b)):
					seen[str(b)] = true
					var e := event(str(b))
					if not e.is_empty():
						out.append(e)
						nxt.append(str(b))
		frontier = nxt
		if frontier.is_empty():
			break
	return out


## The events that happened because of `id`.
static func consequences(id: String) -> Array:
	return events(_ids("because", id))


# ------------------------------------------------------------------ retention
## Daily (Sim.on_day): fold old routine work into digests every COMPACT_EVERY days.
static func on_day(day: int) -> void:
	if day % COMPACT_EVERY == 0:
		compact()


## Folds routine workshop events (importance 0, ROUTINE_KINDS) older than ROUTINE_AGE days into one digest per piece
## (or subject) per 30-day month. Nothing in a causal chain (pointing at a cause or pointed at as one), nothing in the
## Chronicle and nothing significant is folded.
## Returns how many events were folded.
static func compact(today := -1) -> int:
	var s := st()
	var now_day := Game.day() if today < 0 else today
	var linked := {}
	for e in s["events"].values():
		for b in e.get("because", []):
			linked[str(b)] = true
	var chron := {}
	for id in s["chron_ids"]:
		chron[str(id)] = true
	var groups := {}
	var keys := []
	for id in s["order"]:
		var e: Dictionary = s["events"].get(id, {})
		if e.is_empty() or int(e.get("importance", 1)) != 0 or not str(e.get("kind", "")) in ROUTINE_KINDS:
			continue
		if linked.has(id) or e.has("because") or chron.has(id) or e.has("chron") or int(e.get("day", now_day)) > now_day - ROUTINE_AGE:
			continue
		var month := (int(e["day"]) - 1) / 30
		var subj := ("item:%d" % int(e["items"][0])) if not (e.get("items", []) as Array).is_empty() else \
			(("actor:" + str(e["actors"][0])) if not (e.get("actors", []) as Array).is_empty() else ("place:" + str(e.get("place", ""))))
		var k := "%d|%s" % [month, subj]
		if not groups.has(k):
			groups[k] = []
			keys.append(k)
		(groups[k] as Array).append(id)
	var folded := 0
	var redirect := {}
	for k in keys:
		var ids: Array = groups[k]
		if ids.size() < 2:
			continue
		var counts := {}
		var first: Dictionary = s["events"][ids[0]]
		var last: Dictionary = s["events"][ids[-1]]
		var actors := []
		var items := []
		for id in ids:
			var e: Dictionary = s["events"][id]
			counts[str(e["kind"])] = int(counts.get(str(e["kind"]), 0)) + 1
			for a in e.get("actors", []):
				if not actors.has(a):
					actors.append(a)
			for u in e.get("items", []):
				if not items.has(u):
					items.append(u)
		var parts := []
		for kind in counts:
			parts.append("%s ×%d" % [str(kind), int(counts[kind])])
		var text := "Routine work, days %d–%d: %s." % [int(first["day"]), int(last["day"]), ", ".join(PackedStringArray(parts))]
		var d := _make("digest", text, {"t": int(first["t"]), "day": int(first["day"]), "time": str(first.get("time", "")),
			"actors": actors, "items": items, "place": str(first.get("place", "")), "importance": 1,
			"data": {"month": int(k.get_slice("|", 0)), "subject": k.get_slice("|", 1), "from": int(first["day"]),
				"to": int(last["day"]), "counts": counts, "n": ids.size(), "first_text": str(first.get("text", ""))}})
		for id in ids:
			s["folded"][id] = str(d["id"])
			redirect[id] = str(d["id"])
			s["events"].erase(id)
			folded += 1
	if folded == 0:
		return 0
	var keep := []
	for id in s["order"]:
		if s["events"].has(id):
			keep.append(id)
	s["order"] = keep
	# the lists that point at the folded events now point at their digest (each digest once)
	for a in Adv.all().values():
		if a.get("lore") is Array:
			a["lore"] = _remap(a["lore"], redirect)
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, true):
		var pv: Variant = it.get("prov", {})
		if pv is Dictionary and (pv as Dictionary).get("events") is Array:
			pv["events"] = _remap(pv["events"], redirect)
	for tb in ItemRegistry.tombstones().values():
		if tb.get("events") is Array:
			tb["events"] = _remap(tb["events"], redirect)
	_idx_n = -1
	_idx_for = {}
	return folded


static func _remap(ids: Array, redirect: Dictionary) -> Array:
	var out := []
	for id in ids:
		var r := str(redirect.get(str(id), str(id)))
		if not out.has(r):
			out.append(r)
	return out


## Every item instance the world holds (ItemRegistry: stores, worn, packs, offers, customers, pledges, contracts,
## delivered masterpieces, lost gear at sites, return bags, merchants' stock) and the last-known copies of the
## smith's pieces out in the world.
static func _all_items() -> Array:
	return ItemRegistry.all_physical(ItemRegistry.ALL, true)


# ------------------------------------------------------------------ migration (save step 11)
## Older saves kept the news feed in a separate, capped `chronicle` array. Each entry becomes (or marks) a Lore event,
## in its original time and order; links to people, items and places are kept; the separate array is removed.
## Idempotent; returns how many feed entries were converted.
static func migrate_chronicle(state: Dictionary) -> int:
	if not state.get("chronicle") is Array:
		return 0
	var old: Array = state["chronicle"]
	if not state.get("lore") is Dictionary:
		state["lore"] = {"events": {}, "next": 1, "order": []}
	var s: Dictionary = state["lore"]
	if not s.has("chron_ids"):
		s["chron_ids"] = []
	if not s.has("folded"):
		s["folded"] = {}
	var advs: Dictionary = state.get("adventurers", {}) if state.get("adventurers") is Dictionary else {}
	var n := 0
	for c in old:
		if not c is Dictionary:
			continue
		var refs: Dictionary = (c.get("refs", {}) as Dictionary).duplicate(true) if c.get("refs") is Dictionary else {}
		var kind := str(c.get("kind", "note"))
		var e: Dictionary = s["events"].get(str(refs.get("event", "")), {})
		if e.is_empty():
			var actors := []
			if str(refs.get("adv", "")) != "":
				actors.append(str(refs["adv"]))
			for p in refs.get("party", []):
				if not actors.has(str(p)):
					actors.append(str(p))
			var items := []
			for k in ["item", "uid"]:
				var u := str(refs.get(k, ""))
				if u.is_valid_int() and int(u) > 0 and not items.has(int(u)):
					items.append(int(u))
			var id := "ev_%d" % int(s["next"])
			s["next"] = int(s["next"]) + 1
			e = {"id": id, "t": int(c.get("t", 0)), "day": int(c.get("day", 1)), "time": str(c.get("time", "")), "kind": kind,
				"text": str(c.get("text", "")), "actors": actors, "items": items, "place": str(refs.get("place", "")),
				"importance": 1, "icon": str(ICONS.get(kind, "ui/ic_history")), "data": {"feed": true, "migrated": true}}
			s["events"][id] = e
			(s["order"] as Array).append(id)
			refs["event"] = id
			for a_id in actors:
				var a: Variant = advs.get(a_id)
				if a is Dictionary:
					if not (a as Dictionary).get("lore") is Array:
						a["lore"] = []
					(a["lore"] as Array).append(id)
		e["chron"] = kind
		e["refs"] = refs
		if not (s["chron_ids"] as Array).has(str(e["id"])):
			(s["chron_ids"] as Array).append(str(e["id"]))
		n += 1
	# chronological order (stable on the id number)
	# the feed keeps its own order (it is the order things were told in); views sort by time where they need to
	state.erase("chronicle")
	return n

