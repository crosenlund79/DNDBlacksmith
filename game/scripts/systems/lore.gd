## Lore — the world's single memory. Every significant happening (a forging, a sale, a battle, a discovery, a
## death, a repair, a naming) is ONE event with a stable id; items, adventurers and places keep only the ids.
## EN: Item histories, adventurer histories, location histories and the Hall of Fame therefore read the same
##     records — no duplicated or contradictory accounts. Routine events are light (importance 0) and may be
##     pruned from the global index when the world grows old; anything an item or a place still points at, and
##     everything of importance 2+, is kept forever.
##     Event: {id, t, day, time, kind, text, actors[adv/npc ids], items[uids], place(location id), importance 0–3,
##     icon, data{}}. Chronicle (the news feed) gets notable events with refs.event = id.
##     KNOWN INCONSISTENCY (Run 0.1; decision register LORE-017 / GOV-031): Lore is not yet complete. Many happenings
##     are written only to the capped Chronicle feed (chronicle.gd), so "single memory" is the design target (canon
##     §10.4), not today's fact; routine events past CAP are pruned rather than summarised (canon D9 asks for safe
##     summaries). Both are preserved as they are until Gate J — see game/docs/TECHNICAL.md.
## DA: Verdens fælles hukommelse — én begivenhed, mange henvisninger. (Endnu ikke komplet: se Chronicle og Gate J.)
class_name Lore

const CAP := 4000            # routine events beyond this are pruned (oldest, unimportant, unreferenced first)
const ICONS := {
	# existing sprites only (no new art): the history view shows these beside each entry
	"forged": "ui/act_hammer", "sold": "icons/purse_gift", "bought": "icons/purse_gift", "given": "icons/purse_gift",
	"found": "icons/chest_recovered", "looted": "icons/bag_traveller", "inherited": "ui/act_candle", "recovered": "icons/chest_recovered",
	"repaired": "ui/act_hammer", "reforged": "ui/act_hammer", "sharpened": "ui/act_hammer", "enchanted": "icons/runestone_ember",
	"treated": "icons/potion_healing", "battle": "ui/stat_damage", "slew": "icons/sword_iron", "survived": "ui/stat_defence",
	"discovery": "icons/relic_map", "named": "icons/star", "epic": "icons/star", "deed": "icons/star", "awakened": "ui/ic_talk",
	"lost": "ui/warn_broken", "destroyed": "ui/warn_broken", "death": "ui/act_candle", "returned": "ui/ic_home", "pawned": "icons/purse_gift",
	"redeemed": "icons/purse_gift", "commission": "icons/recipe_scroll", "cleared": "icons/relic_map", "reunion": "ui/ic_home",
	"note": "ui/ic_history", "threat": "ui/warn_worn", "arrival": "ui/act_road",
}


static func st() -> Dictionary:
	if not Game.state.has("lore"):
		Game.state["lore"] = {"events": {}, "next": 1, "order": []}
	return Game.state["lore"]


## Records one event and links it to every item, adventurer and place it involves. Returns the event id.
## opts: actors (Array of ids), items (Array of item dicts or uids), place (String), importance (0–3),
##       icon, data (Dictionary), chronicle (bool: also post to the news feed), notable (bool: journal it too).
static func record(kind: String, text: String, opts := {}) -> String:
	var s := st()
	var id := "ev_%d" % int(s["next"])
	s["next"] = int(s["next"]) + 1
	var uids: Array = []
	for x in opts.get("items", []):
		var u := int(x.get("uid", -1)) if x is Dictionary else int(x)
		if u > 0 and not uids.has(u):
			uids.append(u)
	var e := {"id": id, "t": Game.now(), "day": Game.day(), "time": Game.time_string(), "kind": kind, "text": text,
		"actors": (opts.get("actors", []) as Array).duplicate(), "items": uids, "place": str(opts.get("place", "")),
		"importance": int(opts.get("importance", 1)), "icon": str(opts.get("icon", ICONS.get(kind, "ui/ic_history"))),
		"data": (opts.get("data", {}) as Dictionary).duplicate(true)}
	s["events"][id] = e
	(s["order"] as Array).append(id)
	# link: items carry the id in their provenance, adventurers in their lore list
	for x in opts.get("items", []):
		if x is Dictionary and not (x as Dictionary).is_empty():
			Provenance.link(x, id)
	for a_id in e["actors"]:
		var a := Adv.get_a(str(a_id))
		if not a.is_empty():
			if not a.has("lore"):
				a["lore"] = []
			(a["lore"] as Array).append(id)
	if e["place"] != "":
		Events.lore_recorded.emit(e)
	elif int(e["importance"]) >= 1:
		Events.lore_recorded.emit(e)
	if bool(opts.get("chronicle", false)):
		var refs := {"event": id}
		if not (e["actors"] as Array).is_empty():
			refs["adv"] = e["actors"][0]
			if (e["actors"] as Array).size() > 1:
				refs["party"] = e["actors"]
		if not uids.is_empty():
			refs["item"] = str(uids[0])
		if e["place"] != "":
			refs["place"] = e["place"]
		Chronicle.add(kind, text, refs, bool(opts.get("notable", false)))
	_prune()
	return id


static func event(id: String) -> Dictionary:
	return st()["events"].get(id, {})


## Events in chronological order for a list of ids (missing ids — pruned routine ones — are skipped).
static func events(ids: Array) -> Array:
	var out := []
	for id in ids:
		var e := event(str(id))
		if not e.is_empty():
			out.append(e)
	out.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]) or (int(a["t"]) == int(b["t"]) and int(str(a["id"]).substr(3)) < int(str(b["id"]).substr(3))))
	return out


static func of_item(uid: int) -> Array:
	var it := Game.find_uid_anywhere(uid)
	if not it.is_empty():
		return events(Provenance.st(it).get("events", []))
	var out := []
	for id in st()["order"]:
		var e: Dictionary = st()["events"].get(id, {})
		if (e.get("items", []) as Array).has(uid):
			out.append(e)
	return out


static func of_actor(actor: String) -> Array:
	var a := Adv.get_a(actor)
	if not a.is_empty() and a.has("lore"):
		return events(a["lore"])
	var out := []
	for id in st()["order"]:
		var e: Dictionary = st()["events"].get(id, {})
		if (e.get("actors", []) as Array).has(actor):
			out.append(e)
	return out


static func of_place(place: String) -> Array:
	var out := []
	for id in st()["order"]:
		var e: Dictionary = st()["events"].get(id, {})
		if str(e.get("place", "")) == place:
			out.append(e)
	return out


## Keeps the registry bounded: drop the oldest importance-0 events that nothing still lists.
static func _prune() -> void:
	var s := st()
	var order: Array = s["order"]
	if order.size() <= CAP:
		return
	var keep := {}
	for it in _all_items():
		var pv: Variant = it.get("prov", {})   # read only: a piece without a record yet has no events to keep
		for id in (pv.get("events", []) if pv is Dictionary else []):
			keep[id] = true
	var i := 0
	while order.size() > CAP and i < order.size():
		var id: String = order[i]
		var e: Dictionary = s["events"].get(id, {})
		if int(e.get("importance", 1)) == 0 and not keep.has(id):
			s["events"].erase(id)
			order.remove_at(i)
		else:
			i += 1


## Every item instance the world holds (ItemRegistry: stores, worn, packs, offers, customers, pledges, contracts,
## delivered masterpieces, lost gear at sites, return bags, merchants' stock) and the last-known copies of the
## smith's pieces out in the world — their events are never pruned.
static func _all_items() -> Array:
	return ItemRegistry.all_physical(ItemRegistry.ALL, true)
