## Chronicle — the village's news feed, a VIEW of Lore (R3 "One History": GOV-031, LORE-017, LORE-002, BUG-018).
## EN: Before R3 this was a separate store capped at 400 entries, written by about seventy places directly, so many
##     happenings (hireling deaths, funerals, social notes) never reached Lore and vanished from the feed after 400
##     newer ones. Now every feed entry IS a Lore event (Lore.chronicle marks it with its feed kind and links); this
##     file only presents them, newest last, in the shape every reader has always used:
##       {t, day, time, kind (the feed kind), text, refs {adv, party, item, uid, place, …, event}, event}.
##     Nothing is capped: the feed is as long as the world's history (panels show the recent part).
##     The Hall of Fame and Epic distinction still read each new entry (Recognition.on_chronicle), now with its event id.
## DA: Landsbyens nyhedsstrøm — en visning af Lore (intet gemmes to gange, intet falder ud af en begrænset liste).
class_name Chronicle
extends RefCounted

static var _view: Array = []
static var _view_for: Dictionary = {}
static var _view_n := 0


static func _entry(e: Dictionary) -> Dictionary:
	var refs: Dictionary = (e.get("refs", {}) as Dictionary).duplicate()
	refs["event"] = str(e["id"])
	return {"t": int(e.get("t", 0)), "day": int(e.get("day", 1)), "time": str(e.get("time", "")), "kind": str(e.get("chron", e.get("kind", ""))),
		"text": str(e.get("text", "")), "refs": refs, "event": str(e["id"])}


## Every feed entry, oldest first (a read-only view: build anything new with add()).
static func entries() -> Array:
	var s := Lore.st()
	var ids: Array = s["chron_ids"]
	if not is_same(_view_for, s) or _view_n > ids.size():
		_view = []
		_view_for = s
		_view_n = 0
	while _view_n < ids.size():
		var e := Lore.event(str(ids[_view_n]))
		if not e.is_empty():
			_view.append(_entry(e))
		_view_n += 1
	return _view


## kind: departure, return, victory, defeat, death, missing, rescue, discovery, legend, levelup,
##       renown, relic, item, sale, commission, social, chain
## refs.event: the Lore event this entry presents (Lore.record with chronicle = true passes it); without it a Lore
## event is recorded for the entry (with the people, items and place in refs).
static func add(kind: String, text: String, refs := {}, notable := false) -> Dictionary:
	var ev := Lore.chronicle(kind, text, refs, notable)
	var e := _entry(ev)
	entries()   # keep the view current
	if notable:
		Game.journal(text)
	Recognition.on_chronicle(e)   # the Hall of Fame and Epic distinction read the record
	Events.chronicle_added.emit(e)
	return e


static func about(id: String, kinds := []) -> Array:
	return entries().filter(func(e):
		var r: Dictionary = e.get("refs", {})
		var hit: bool = str(r.get("adv", "")) == id or (r.get("party", []) as Array).has(id) or str(r.get("item", "")) == id
		return hit and (kinds.is_empty() or kinds.has(e["kind"])))


static func recent(n := 10, kinds := []) -> Array:
	var out := []
	var all := entries()
	for i in range(all.size() - 1, -1, -1):
		var e: Dictionary = all[i]
		if kinds.is_empty() or kinds.has(e["kind"]):
			out.append(e)
			if out.size() >= n:
				break
	return out
