## Uniques — one authentic instance of each defined Unique artifact per campaign (Run 0.1; canon §6.2 and decision
## D13: "Exactly one authentic defined Unique artifact per campaign … It cannot respawn as a duplicate after sale, loss
## or inheritance").
## EN: A Unique is an item definition tagged "unique" in data/items.json (today: Grimhold, the Last Hammer). The
##     campaign's registry (Game.state["uniques"], created on its first write) remembers, per definition, the uid of
##     the piece that was minted first: once minted, a definition is never minted again — not after the piece is sold,
##     lost, inherited or destroyed. Loot asks can_mint() before it makes one and register()s what it makes; a roll
##     that is thrown away before it reaches the world (a gift or reward package over its cap) is release()d again.
##     Saves from before Run 0.1 may already hold several pieces of one Unique (loot could mint them repeatedly).
##     The v3 → v4 migration (scan_state) registers the lowest uid as the authentic piece and lists the others as
##     legacy copies. Every existing piece is kept whole — same uid, name, stats, rarity, owner and history; nothing is
##     deleted or rewritten. What, if anything, a legacy copy should show the player is a design decision left open.
##     Reads are pure (no state keys are created by reading).
## DA: Ét autentisk eksemplar af hver unik genstand pr. kampagne. Registret husker den først skabte (laveste uid);
##     ældre gemte spil kan have flere — de bevares uændrede og registreres som tidligere kopier.
##
## Public API
##   is_unique_def(def_id) -> bool        the definition is tagged "unique"
##   minted(def_id) -> bool               this campaign has minted it already (whatever has happened to it since)
##   can_mint(def_id) -> bool             a Unique definition not yet minted
##   authentic_uid(def_id) -> int         the authentic piece's uid (-1 = not minted)
##   is_authentic(it) -> bool / is_legacy_copy(it) -> bool
##   register(it, via := "") -> bool      record a newly made Unique (true when it became the authentic piece)
##   release(it)                          forget a just-made Unique that never reached the world
##   scan_state(data) -> int              (migration) register every Unique piece or record in a save; returns entries
##   audit(data := {}) -> Array           Unique definitions held under more than one unregistered uid (test probe)
class_name Uniques
extends RefCounted


static func _reg(data: Dictionary = {}) -> Dictionary:
	var s: Dictionary = data if not data.is_empty() else Game.state
	var r: Variant = s.get("uniques", {})
	return r if r is Dictionary else {}


static func _reg_w() -> Dictionary:
	if not Game.state.get("uniques") is Dictionary:
		Game.state["uniques"] = {}
	return Game.state["uniques"]


static func is_unique_def(def_id: String) -> bool:
	return (DB.item(def_id).get("tags", []) as Array).has("unique")


static func minted(def_id: String) -> bool:
	return _reg().has(def_id)


static func can_mint(def_id: String) -> bool:
	return is_unique_def(def_id) and not minted(def_id)


static func authentic_uid(def_id: String) -> int:
	return int(_reg().get(def_id, {}).get("uid", -1))


static func is_authentic(it: Dictionary) -> bool:
	return is_unique_def(str(it.get("def", ""))) and int(it.get("uid", -2)) == authentic_uid(str(it.get("def", "")))


static func is_legacy_copy(it: Dictionary) -> bool:
	var e: Dictionary = _reg().get(str(it.get("def", "")), {})
	return (e.get("copies", []) as Array).has(int(it.get("uid", -2))) or (e.get("copies", []) as Array).has(float(it.get("uid", -2)))


## Records a newly made Unique piece. The first becomes the authentic one; any later piece of the same definition
## (only developer tools or tests can make one now) is listed as a copy so the audit stays honest.
static func register(it: Dictionary, via := "") -> bool:
	var d := str(it.get("def", ""))
	if not is_unique_def(d) or not it.has("uid"):
		return false
	var r := _reg_w()
	var uid := int(it["uid"])
	if not r.has(d):
		r[d] = {"uid": uid, "day": Game.day(), "via": via, "copies": []}
		return true
	var e: Dictionary = r[d]
	if int(e["uid"]) != uid and not is_legacy_copy(it):
		(e["copies"] as Array).append(uid)
	return false


## A Unique that was made by a roll but never reached the world (a gift over its cap, a relic study's unused extra):
## the campaign has not minted it after all.
static func release(it: Dictionary) -> void:
	var d := str(it.get("def", ""))
	if not is_unique_def(d) or not Game.state.get("uniques") is Dictionary:
		return
	var r: Dictionary = Game.state["uniques"]
	var e: Dictionary = r.get(d, {})
	if e.is_empty():
		return
	var uid := int(it.get("uid", -2))
	if int(e["uid"]) == uid and (e.get("copies", []) as Array).is_empty() and int(e.get("day", -1)) == Game.day():
		r.erase(d)
	else:
		(e.get("copies", []) as Array).erase(uid)


## Migration (SaveMigrations v3 → v4): every piece or record of a Unique definition anywhere in the save — worn, stored,
## carried, offered, archived, or only remembered by a record's snapshot — is registered. The lowest uid is the
## authentic piece (uids rise as items are made, so it is the first one minted); the rest are legacy copies.
## Idempotent: an existing registry entry keeps its authentic uid; newly seen uids are added as copies.
static func scan_state(data: Dictionary) -> int:
	var found := {}
	_walk(data, found)
	if found.is_empty():
		return 0
	if not data.get("uniques") is Dictionary:
		data["uniques"] = {}
	var r: Dictionary = data["uniques"]
	for d in found:
		var uids: Array = (found[d] as Dictionary).keys()
		uids.sort()
		if not r.has(d):
			r[d] = {"uid": int(uids[0]), "day": -1, "via": "migration", "copies": []}
		var e: Dictionary = r[d]
		for u in uids:
			if int(u) != int(e["uid"]) and not (e["copies"] as Array).has(int(u)):
				(e["copies"] as Array).append(int(u))
	return r.size()


static func _walk(v: Variant, found: Dictionary) -> void:
	if v is Dictionary:
		var dv := v as Dictionary
		if dv.has("def") and dv.has("uid") and is_unique_def(str(dv["def"])):
			var d := str(dv["def"])
			if not found.has(d):
				found[d] = {}
			found[d][int(dv["uid"])] = true
		for k in dv:
			if k != "uniques":
				_walk(dv[k], found)
	elif v is Array:
		for x in v:
			_walk(x, found)


## The integrity probe: Unique definitions present under more than one uid that the registry does not account for
## (an authentic piece plus recorded legacy copies are accounted for). [] = healthy.
static func audit(data: Dictionary = {}) -> Array:
	var s: Dictionary = data if not data.is_empty() else Game.state
	var found := {}
	_walk(s, found)
	var out := []
	var r := _reg(s)
	for d in found:
		var e: Dictionary = r.get(d, {})
		var known := {}
		if not e.is_empty():
			known[int(e["uid"])] = true
			for c in e.get("copies", []):
				known[int(c)] = true
		var stray: Array = (found[d] as Dictionary).keys().filter(func(u): return not known.has(int(u)))
		if not stray.is_empty():
			out.append({"def": d, "uids": (found[d] as Dictionary).keys(), "unregistered": stray})
	return out
