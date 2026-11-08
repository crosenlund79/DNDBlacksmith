## Chronicle — the village's single record of what happened.
## EN: Every significant world event is written here once, by the authoritative simulation, with
##     references to the people, items, expeditions and places involved. The Most Wanted board,
##     dossiers, expedition histories, rumours and table talk all READ this record — no interface
##     invents its own version of an event.
## DA: Landsbyens ene fortegnelse over hændelser. Tavlen, dossierer, rygter og bordsnak læser herfra.
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
