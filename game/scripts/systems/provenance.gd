## Provenance — every equipment instance has a stable identity: its uid, its maker and maker's mark (fixed for
## ever, whatever repairs, reforging or resale follow), materials, craftsmanship, original rarity, the chain of
## owners and the ids of the Lore events it took part in (battles, discoveries, repairs, naming, loss).
## EN: it["prov"] = {maker:{id,name,mark,place,day}, origin:{materials,quality,rarity,def}, owners:[{id,name,from,
##     to,how}], events:[ev ids], reunions:[...], lost:{}, destroyed:{}}. Routine items stay light: owners and a
##     few events. Old saves are migrated on first touch from crafted_by / owner / history.
## DA: Proveniens — hver genstand har en fast identitet, smed, mærke og ejerkæde.
class_name Provenance

const SMITH_ID := "smith"
const SMITH_NAME := "Brannoc Ironhand"
const SMITH_MARK := "ironhand"           # the anvil-and-flame mark of the Ironhand forge
const SMITH_PLACE := "the Ironhand forge, Brindlewick"

## Other makers' marks (the rival smith, the old dead smiths of the barrows and deeps, hirelings).
const MARKS := {
	"ironhand": {"name": "the Ironhand mark", "desc": "an anvil under a single flame, struck small near the tang"},
	"salt_anvil": {"name": "the Salt Anvil mark", "desc": "a ship's anchor crossed by a hammer — Maren Tallowgate's"},
	"barrow": {"name": "a barrow-king's sigil", "desc": "a worn crown over three lines; old beyond counting"},
	"ironroot": {"name": "a dwarf-rune of Ironroot", "desc": "an angular rune for 'deep' cut into the steel"},
	"unknown": {"name": "no mark", "desc": "no maker's mark can be found"},
	"hand": {"name": "a journeyman's scratch", "desc": "initials scratched in by an unknown hand"},
}


static func applies(it: Dictionary) -> bool:
	return not it.is_empty() and Items.is_equipment(it)


## The provenance record, created (migrated) on first touch.
static func st(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {}
	if not it.has("prov"):
		it["prov"] = _migrate(it)
	return it["prov"]


static func _migrate(it: Dictionary) -> Dictionary:
	var by := str(it.get("crafted_by", ""))
	var maker := {}
	if by.begins_with("Brannoc"):
		maker = {"id": SMITH_ID, "name": SMITH_NAME, "mark": SMITH_MARK, "place": SMITH_PLACE, "day": int(it.get("craft", {}).get("day", 0))}
	elif by.to_lower().contains("barrow"):
		maker = {"id": "ancient", "name": by, "mark": "barrow", "place": "the Barrow Fields", "day": 0}
	elif by.to_lower().contains("ironroot") or by.to_lower().contains("dwarf"):
		maker = {"id": "ancient", "name": by, "mark": "ironroot", "place": "Ironroot", "day": 0}
	elif by.to_lower().contains("tallowgate") or by.to_lower().contains("salt anvil"):
		maker = {"id": "rival_smith", "name": by, "mark": "salt_anvil", "place": "the Salt Anvil, Brindlewick", "day": 0}
	elif by != "":
		maker = {"id": by.to_lower().replace(" ", "_"), "name": by, "mark": "hand", "place": "", "day": 0}
	else:
		maker = {"id": "unknown", "name": "an unknown smith", "mark": "unknown", "place": "", "day": 0}
	var owners := []
	var cur := str(it.get("owner", ""))
	if cur != "":
		owners.append({"id": cur, "name": _who(cur), "from": 0, "to": -1, "how": "held"})
	return {"maker": maker, "origin": {"def": str(it.get("def", "")), "quality": float(it.get("quality", 0.0)),
		"rarity": str(it.get("rarity", "common")), "materials": _materials(it)}, "owners": owners, "events": [], "reunions": []}


static func _materials(it: Dictionary) -> Array:
	var c: Dictionary = it.get("craft", {})
	var out := []
	if str(c.get("material", "")) != "":
		out.append(str(c["material"]))
	return out


static func _who(id: String) -> String:
	if id == SMITH_ID or id == "":
		return SMITH_NAME
	var a := Adv.get_a(id)
	if not a.is_empty():
		return str(a["name"])
	var h := Hire.get_h(id)
	if not h.is_empty():
		return str(h["name"])
	var c := DB.character(id)
	return str(c.get("name", id.capitalize()))


# ------------------------------------------------------------------ creation
## Sets the maker once. Called when an item is forged at the Ironhand forge or made by another named smith.
## Never overwrites an existing maker — the original creator is permanent.
static func set_maker(it: Dictionary, maker_id: String, maker_name: String, mark: String, place: String) -> void:
	if not applies(it):
		return
	var p := st(it)
	if str(p.get("maker", {}).get("id", "unknown")) not in ["unknown", ""] and bool(p.get("maker_fixed", false)):
		return
	p["maker"] = {"id": maker_id, "name": maker_name, "mark": mark, "place": place, "day": Game.day()}
	p["maker_fixed"] = true
	p["origin"] = {"def": str(it.get("def", "")), "quality": float(it.get("quality", 0.0)), "rarity": str(it.get("rarity", "common")),
		"materials": _materials(it)}


## The smith forged this piece: maker's mark, origin and a "forged" event. With `by` (an apprentice:
## {id, name, mark, supervised}) the apprentice is the maker, the piece was made at the Ironhand forge
## (maker.workshop = "ironhand") and, when the smith watched over the work, maker.supervisor = "smith".
static func forged(it: Dictionary, by := {}) -> void:
	if not applies(it):
		return
	if not by.is_empty():
		_forged_by(it, by)
		return
	set_maker(it, SMITH_ID, SMITH_NAME, SMITH_MARK, SMITH_PLACE)
	# a fresh piece: the lazy migration may have opened a placeholder "held" entry — the chain begins at the anvil
	var ow: Array = st(it)["owners"]
	if ow.size() == 1 and str(ow[0].get("id", "")) == SMITH_ID and str(ow[0].get("how", "")) == "held":
		ow.clear()
	_open_owner(it, SMITH_ID, "forged")
	var q := float(it.get("quality", 0.0))
	var rich := q >= 105.0 or str(it.get("rarity", "")) in ["rare", "legendary"]
	Lore.record("forged", "%s forged %s at the Ironhand forge (%d%% craftsmanship%s)." % [SMITH_NAME, Items.display_name(it), int(round(q)),
		(", " + str(it.get("rarity", ""))) if str(it.get("rarity", "common")) != "common" else ""],
		{"items": [it], "actors": [], "place": "brindlewick", "importance": 2 if rich else 0})


static func _forged_by(it: Dictionary, by: Dictionary) -> void:
	var aid := str(by.get("id", ""))
	set_maker(it, aid, str(by.get("name", "")), str(by.get("mark", aid)), SMITH_PLACE)
	var mk: Dictionary = st(it)["maker"]
	mk["workshop"] = SMITH_MARK
	if bool(by.get("supervised", false)):
		mk["supervisor"] = SMITH_ID
	var ow: Array = st(it)["owners"]
	if ow.size() == 1 and str(ow[0].get("id", "")) == SMITH_ID and str(ow[0].get("how", "")) == "held":
		ow.clear()
	_open_owner(it, SMITH_ID, "forged")
	var q := float(it.get("quality", 0.0))
	var rich := q >= 105.0 or str(it.get("rarity", "")) in ["rare", "legendary"]
	Lore.record("forged", "%s, %s at the Ironhand forge, made %s (%d%% craftsmanship%s%s)." % [str(by.get("name", "")),
		str(by.get("rank_name", "apprentice")).to_lower(), Items.display_name(it), int(round(q)),
		(", " + str(it.get("rarity", ""))) if str(it.get("rarity", "common")) != "common" else "",
		", under the smith's eye" if bool(by.get("supervised", false)) else ""],
		{"items": [it], "actors": [aid], "place": "brindlewick", "importance": 2 if rich else 0, "data": {"apprentice": aid}})


## Living Workshop C1 (D4): the specialists who worked stages of this piece, recorded beside its maker — never
## replacing him — as prov.contrib[] {who, name, profession, stage, title, work, stations, at, quality, day}, with
## one Lore event naming them.
static func add_contributions(it: Dictionary, entries: Array, maker_name := "") -> void:
	if not applies(it) or entries.is_empty():
		return
	var p := st(it)
	var c: Array = p.get("contrib", [])
	for e in entries:
		c.append((e as Dictionary).duplicate(true))
	p["contrib"] = c
	var parts := PackedStringArray()
	var actors := []
	for e2 in entries:
		parts.append("%s (%s) — %s, %d%%" % [str(e2.get("name", "")), str(e2.get("profession", "")), str(e2.get("work", e2.get("title", ""))).to_lower(),
			int(round(float(e2.get("quality", 0.0))))])
		var w := str(e2.get("who", ""))
		if w != "" and w != SMITH_ID:
			actors.append(w)
	Lore.record("contributed", "At the Ironhand forge, %s worked %s stage%s of %s%s: %s." % ["specialists" if entries.size() > 1 else "a specialist",
		"their" if entries.size() > 1 else "a", "s" if entries.size() > 1 else "", Items.display_name(it),
		(" (made by %s)" % maker_name) if maker_name != "" else "", "; ".join(parts)],
		{"items": [it], "actors": actors, "place": "brindlewick", "importance": 1, "data": {"contrib": entries.size()}})


## The contributors recorded on a piece (prov.contrib), [] for most pieces.
static func contributors(it: Dictionary) -> Array:
	if not applies(it):
		return []
	return st(it).get("contrib", [])


## Made at the Ironhand forge: the smith's own work OR an apprentice's work at his forge. Used where the world asks
## "is it ours" for fame (Epic, Hall of Fame, names, reunions). is_mine still means the smith made it himself.
static func is_workshop(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if is_mine(it):
		return true
	return it.has("prov") and str(st(it).get("maker", {}).get("workshop", "")) == SMITH_MARK


static func is_mine(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if not it.has("prov"):
		return str(it.get("crafted_by", "")).begins_with("Brannoc")
	return str(st(it).get("maker", {}).get("id", "")) == SMITH_ID


static func maker(it: Dictionary) -> Dictionary:
	return st(it).get("maker", {})


## The maker's mark: a fixed mark, or an apprentice's / former apprentice's own (resolved from their record).
static func mark(it: Dictionary) -> Dictionary:
	var id := str(maker(it).get("mark", "unknown"))
	if MARKS.has(id):
		return MARKS[id]
	var m := Apprentices.mark_info(id)
	return m if not m.is_empty() else MARKS["unknown"]


# ------------------------------------------------------------------ ownership
static func owner_id(it: Dictionary) -> String:
	var ow: Array = st(it).get("owners", [])
	for i in range(ow.size() - 1, -1, -1):
		if int(ow[i].get("to", -1)) == -1:
			return str(ow[i]["id"])
	return ""


static func _open_owner(it: Dictionary, to_id: String, how: String) -> void:
	var ow: Array = st(it)["owners"]
	for o in ow:
		if int(o.get("to", -1)) == -1:
			if str(o["id"]) == to_id:
				return
			o["to"] = Game.day()
	ow.append({"id": to_id, "name": _who(to_id), "from": Game.day(), "to": -1, "how": how})
	it["owner"] = to_id


## The piece changes hands. `how`: sold, bought, given, found, looted, inherited, recovered, pawned, redeemed,
## commissioned, offered, returned. A light Lore event is recorded (rich for the smith's notable pieces).
static func transfer(it: Dictionary, to_id: String, how: String, place := "", note := "") -> void:
	if not applies(it):
		return
	var from := owner_id(it)
	if from == to_id and how != "inherited":
		return
	_open_owner(it, to_id, how)
	var notable := is_notable(it)
	var text := note if note != "" else "%s passed from %s to %s (%s)." % [Items.display_name(it), _who(from) if from != "" else "nobody",
		_who(to_id), how]
	Lore.record(how, text, {"items": [it], "actors": _actors(from, to_id),
		"place": place, "importance": 1 if notable or how in ["inherited", "recovered", "looted", "found"] else 0})


static func _actors(a: String, b: String) -> Array:
	var out := []
	for x in [a, b]:
		if x != "" and x != SMITH_ID and not out.has(x):
			out.append(x)
	return out


static func owners(it: Dictionary) -> Array:
	return st(it).get("owners", [])


# ------------------------------------------------------------------ deeds & workshop
## Called by Lore.record — the event becomes part of the item's story.
static func link(it: Dictionary, event_id: String) -> void:
	if not applies(it):
		return
	var ev: Array = st(it)["events"]
	if not ev.has(event_id):
		ev.append(event_id)
		# the short index the old tooltips and panels read: one line per event, carrying the event id
		var e := Lore.event(event_id)
		if not it.has("history"):
			it["history"] = []
		(it["history"] as Array).append({"day": int(e.get("day", Game.day())), "text": str(e.get("text", "")), "event": event_id})
		while (it["history"] as Array).size() > 12:
			(it["history"] as Array).pop_front()
	# routine pieces keep a short memory; exceptional ones keep everything
	# (the first event — how the piece came to be — is always kept)
	if not is_notable(it):
		while ev.size() > 24:
			ev.remove_at(1)


## Workshop work on a piece (repair, sharpening, reforging, enchanting, treatment) — recorded, maker untouched.
## `data` (refinement: smith, station, materials, check, outcome, stat changes) is kept on the Lore event.
static func workshop(it: Dictionary, kind: String, text: String, data := {}) -> String:
	if not applies(it):
		return ""
	if kind == "reforged":
		st(it)["reforged"] = int(st(it).get("reforged", 0)) + 1
	return Lore.record(kind, text, {"items": [it], "place": "brindlewick", "importance": 1 if is_notable(it) else 0, "data": data})


static func lose(it: Dictionary, where: String, how: String, place := "") -> void:
	if not applies(it):
		return
	st(it)["lost"] = {"day": Game.day(), "where": where, "how": how}
	Lore.record("lost", "%s was lost — %s." % [Items.display_name(it), how], {"items": [it], "place": place, "importance": 2 if is_notable(it) else 0})


static func destroy(it: Dictionary, how: String) -> void:
	if not applies(it):
		return
	st(it)["destroyed"] = {"day": Game.day(), "how": how}
	Lore.record("destroyed", "%s was destroyed — %s." % [Items.display_name(it), how], {"items": [it], "importance": 2 if is_notable(it) else 0})


## Exceptional pieces get richer histories: named, Epic, legendary or unique, or with a famous deed.
static func is_notable(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	return it.has("epic") or it.has("title") or it.has("named") or str(it.get("rarity", "")) in ["legendary", "unique", "set"] \
		or float(it.get("quality", 0.0)) >= 110.0


## The item's story in order (Lore events + any legacy notes from before provenance existed).
static func story(it: Dictionary) -> Array:
	var out := Lore.events(st(it).get("events", []))
	# notes written before provenance existed (it["history"]) appear once, unless an event says the same
	for h in it.get("history", []):
		if str(h.get("event", "")) != "":
			continue   # an index line of an event already in the list
		var dup := false
		for e in out:
			if str(e.get("text", "")) == str(h.get("text", "")):
				dup = true
		if not dup:
			out.append({"id": "", "day": int(h.get("day", 0)), "t": int(h.get("day", 0)) * 1440, "kind": "note", "text": str(h.get("text", "")), "icon": "ui/ic_history", "items": [int(it.get("uid", -1))], "actors": [], "place": ""})
	out.sort_custom(func(a, b): return int(a.get("t", 0)) < int(b.get("t", 0)))
	return out
