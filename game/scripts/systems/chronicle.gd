## Chronicle — the village's news feed: the last CAP (400) notable happenings, newest last.
## EN: Entries are written by the authoritative simulation, with references to the people, items, expeditions and
##     places involved; the Most Wanted board (Legends & History), dossiers, History panels and Recognition read it.
##     KNOWN INCONSISTENCY, preserved on purpose until Gate J (Run 0.1; decision register LORE-017 / GOV-031): Lore
##     (lore.gd) is meant to be the single shared memory and this feed only a view of it (canon §10.4, §15), but today
##     the two stores run side by side. About two thirds of writers call Chronicle.add directly and never reach Lore
##     (hireling deaths and funerals, many social notes); the feed is capped, so such entries vanish after 400 newer
##     ones; Recognition awards Hall of Fame plaques and Epic by matching Chronicle text. Do not "fix" one side alone:
##     the rebuild (Lore coverage, roles and indices, a retention policy, converting old entries) belongs to Gate J.
##     See game/docs/TECHNICAL.md "History: Lore and the Chronicle".
## DA: Landsbyens nyhedsstrøm (de seneste 400 hændelser). Kendt uoverensstemmelse: den kører ved siden af Lore i
##     stedet for at være en visning af den; det bevares bevidst, indtil historiksystemet samles i Gate J.
class_name Chronicle
extends RefCounted

const CAP := 400


static func entries() -> Array:
	if not Game.state.has("chronicle"):
		Game.state["chronicle"] = []
	return Game.state["chronicle"]


## kind: departure, return, victory, defeat, death, missing, rescue, discovery, legend, levelup,
##       renown, relic, item, sale, commission, social, chain
static func add(kind: String, text: String, refs := {}, notable := false) -> Dictionary:
	var e := {"t": Game.now(), "day": Game.day(), "time": Game.time_string(), "kind": kind, "text": text, "refs": refs}
	entries().append(e)
	while entries().size() > CAP:
		entries().pop_front()
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
	for i in range(entries().size() - 1, -1, -1):
		var e: Dictionary = entries()[i]
		if kinds.is_empty() or kinds.has(e["kind"]):
			out.append(e)
			if out.size() >= n:
				break
	return out
