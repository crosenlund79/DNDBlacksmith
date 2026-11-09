## ItemRegistry — one canonical physical item per uid (Milestone A1 "Protect the Foundation", canonical §6.1).
## EN: The single place that knows WHERE equipment and other item instances physically are. Every holder of a
##     real, physical item in Game.state is listed here once (HOLDERS); lookups, Lore pruning and the stranger
##     pool all enumerate through it. Records that only REFER to an item (a customer's request about an
##     adventurer's own worn piece, an expedition's report of what it carried home, a delivered contract's
##     masterpiece line) hold a small reference — {ref: true, uid, def, name, …snapshot} — never the live dict;
##     readers call resolve() to get the live piece (or the snapshot once it no longer exists physically).
##     Delivered masterpieces live in the registry's own holdings archive (never capped).
##     All reads are pure: nothing here creates state keys, so a load → save straight after stays identical.
## DA: Ét fysisk eksemplar pr. uid. Registret kender alle steder, hvor en genstand fysisk kan ligge; optegnelser
##     gemmer kun en reference (uid + et lille øjebliksbillede), og arkivet holder leverede mesterværker.
##
## Public API
##   where(uid, scope := ALL) -> Dictionary        {path, holder, item} or {}
##   find(uid, scope := ALL) -> Dictionary         the live item or {}
##   locations(scope := ALL, state := {}) -> Array [{path, holder, item}] (dormant pool copies with DORMANT)
##   all_physical(scope := ALL) -> Array           the live items
##   ref(it) -> Dictionary / is_ref(d) -> bool / resolve(d) -> Dictionary
##   archive(it, holder_id, holder_name, via, data := {}) / holdings() -> Array
##   scan(state := {}) -> Dictionary               the integrity probe (duplicates, shared dicts, strays)
##   migrate_records(state) -> int                 idempotent conversion of old saves (registered by SaveMigrations)
class_name ItemRegistry

## Every physical holder, in lookup order. The first three are the classic "worn or stored" set.
const HOLDERS := ["stores", "adventurer", "hireling", "smith", "offer", "customer", "returns", "expedition", "pack",
	"site", "pledge", "contract", "holdings", "pawn_stock", "rival_stock", "caravan_stock", "ship_stock"]
## Last-known copies of the smith's pieces that have left the known world (ItemStory "circulating" pool).
## A pool copy is the item's physical form only while no live holder has that uid.
const DORMANT := "pool"

## Scopes. ALL = every live holder. The narrower scopes reproduce exactly what the older lookups searched, so
## routing them through the registry changes no gameplay (Hall of Fame, awakenings and fame commissions read
## them); widening them is a design decision recorded in the A1 report.
const ALL := HOLDERS
const WORN := ["stores", "adventurer", "hireling"]                                    # Game.find_uid_anywhere
const HISTORY := ["stores", "adventurer", "hireling", "smith", "offer"]               # History.find_item
const STORY := ["stores", "adventurer", "hireling", "smith", "offer", "customer"]     # ItemStory.find

## Lookup priority when one uid is (wrongly) held twice: the earlier holder is the authentic one.
const AUTHORITY := ["smith", "stores", "adventurer", "hireling", "contract", "pledge", "holdings", "returns", "expedition",
	"pack", "customer", "offer", "site", "pawn_stock", "rival_stock", "caravan_stock", "ship_stock"]

const REF_KEY := "ref"
## What a reference keeps of the piece (enough for every record's readable text: name, ×qty, ✦ Epic, ★, colour, icon).
const SNAP_KEYS := ["def", "name", "qty", "rarity", "quality", "star", "epic", "named", "title", "broken", "crafted_by", "dev"]


# ======================================================================= state
static func _s(state: Dictionary) -> Dictionary:
	return state if not state.is_empty() else Game.state


## The holdings archive: delivered masterpieces and other pieces handed to holders the world does not simulate
## (a patron's house). Created on first write only.
static func holdings() -> Array:
	if not Game.state.has("item_registry"):
		Game.state["item_registry"] = {"holdings": []}
	var r: Dictionary = Game.state["item_registry"]
	if not r.has("holdings"):
		r["holdings"] = []
	return r["holdings"]


# ======================================================================= references (records)
static func is_ref(d: Variant) -> bool:
	return d is Dictionary and bool((d as Dictionary).get(REF_KEY, false))


## A record's reference to a piece: its uid and a small snapshot (never the live dict).
static func ref(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {}
	if is_ref(it):
		return it.duplicate(true)
	var out := {REF_KEY: true, "uid": int(it.get("uid", -1))}
	for k: String in SNAP_KEYS:
		if it.has(k):
			var v: Variant = it[k]
			out[k] = (v as Dictionary).duplicate(true) if v is Dictionary else ((v as Array).duplicate(true) if v is Array else v)
	return out


## The live piece a record refers to, or the snapshot when it no longer exists physically. A physical item is
## returned as it is.
static func resolve(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var rec: Dictionary = d
	if not is_ref(rec):
		return rec
	var live := find(int(rec.get("uid", -1)))
	return live if not live.is_empty() else rec


# ======================================================================= where things are
static func where(uid: int, scope: Array = ALL) -> Dictionary:
	if uid < 0 or Game.state.is_empty():
		return {}
	var out := []
	_collect(Game.state, scope, uid, out)
	return out[0] if not out.is_empty() else {}


static func find(uid: int, scope: Array = ALL) -> Dictionary:
	var w := where(uid, scope)
	return w.get("item", {}) if not w.is_empty() else {}


## Every physical item location: [{path, holder, item}]. include_dormant adds pool copies whose uid is not held live.
static func locations(scope: Array = ALL, state := {}, include_dormant := false) -> Array:
	var s := _s(state)
	var out := []
	if s.is_empty():
		return out
	_collect(s, scope, -1, out)
	if include_dormant:
		var live := {}
		for x in out:
			live[int(x["item"].get("uid", -1))] = true
		var pool: Variant = s.get("item_story", {}).get("pool", {})
		if pool is Dictionary:
			for k in pool:
				var it: Variant = pool[k]
				if it is Dictionary and not (it as Dictionary).is_empty() and not live.has(int(it.get("uid", -1))):
					out.append({"path": "/item_story/pool/" + str(k), "holder": DORMANT, "item": it})
	return out


static func all_physical(scope: Array = ALL, include_dormant := false) -> Array:
	return locations(scope, {}, include_dormant).map(func(x): return x["item"])


## Walks the holders in `scope`. want >= 0: stops at the first item with that uid. Paths are built only for hits.
static func _collect(s: Dictionary, scope: Array, want: int, out: Array) -> void:
	for h: String in HOLDERS:
		if not scope.has(h):
			continue
		match h:
			"stores":
				if _arr(s.get("player", {}).get("inventory", []), want, h, "/player/inventory", out):
					return
			"smith":
				if _slots(s.get("player", {}).get("equipment", {}), want, h, "/player/equipment", out):
					return
			"adventurer", "pack":
				var advs: Variant = s.get("adventurers", {})
				if advs is Dictionary:
					for id in advs:
						var a: Variant = advs[id]
						if not (a is Dictionary):
							continue
						if h == "adventurer":
							if _slots(a.get("equipment", {}), want, h, "/adventurers/%s/equipment" % str(id), out):
								return
						elif _arr(a.get("loot", []), want, h, "/adventurers/%s/loot" % str(id), out):
							return
			"hireling":
				var hs: Variant = s.get("hirelings", [])
				if hs is Array:
					for i in (hs as Array).size():
						if hs[i] is Dictionary and _slots(hs[i].get("equipment", {}), want, h, "/hirelings[%d]/equipment" % i, out):
							return
			"offer":
				if _wrapped(s.get("offers", []), want, h, "/offers", out):
					return
			"customer":
				var cs: Variant = s.get("customers", [])
				if cs is Array:
					if _wrapped(cs, want, h, "/customers", out):
						return
					for i in (cs as Array).size():
						if cs[i] is Dictionary and _wrapped(cs[i].get("parts", []), want, h, "/customers[%d]/parts" % i, out):
							return
			"returns":
				if _arr(s.get("returns", []), want, h, "/returns", out):
					return
			"expedition":
				var act: Variant = s.get("exp", {}).get("active", {})
				if act is Dictionary:
					for eid in act:
						if act[eid] is Dictionary and _arr(act[eid].get("loot", []), want, h, "/exp/active/%s/loot" % str(eid), out):
							return
			"site":
				var ws: Variant = s.get("world_sites", {})
				if ws is Dictionary:
					for rid in ws:
						if ws[rid] is Dictionary and _wrapped(ws[rid].get("lost", []), want, h, "/world_sites/%s/lost" % str(rid), out):
							return
			"pledge":
				if _wrapped(_dig(s, ["commerce", "pawn", "pledges"]), want, h, "/commerce/pawn/pledges", out):
					return
			"pawn_stock":
				if _wrapped(_dig(s, ["commerce", "pawn", "house", "stock"]), want, h, "/commerce/pawn/house/stock", out):
					return
			"rival_stock":
				if _wrapped(_dig(s, ["commerce", "rival", "stock"]), want, h, "/commerce/rival/stock", out):
					return
			"caravan_stock":
				if _wrapped(_dig(s, ["commerce", "caravan", "stock"]), want, h, "/commerce/caravan/stock", out):
					return
			"ship_stock":
				if _wrapped(_dig(s, ["trade", "ship", "stock"]), want, h, "/trade/ship/stock", out):
					return
			"contract":
				var ca: Variant = _dig(s, ["contracts", "active"])
				if ca is Array:
					for i in (ca as Array).size():
						var mp: Variant = ca[i].get("masterpiece", {}) if ca[i] is Dictionary else {}
						if mp is Dictionary and _hit(mp.get("item", {}), want, h, "/contracts/active[%d]/masterpiece/item" % i, out):
							return
			"holdings":
				if _wrapped(_dig(s, ["item_registry", "holdings"]), want, h, "/item_registry/holdings", out):
					return


static func _dig(s: Dictionary, keys: Array) -> Variant:
	var cur: Variant = s
	for k in keys:
		if not (cur is Dictionary) or not (cur as Dictionary).has(k):
			return []
		cur = cur[k]
	return cur


## One candidate: a physical item (not a reference) — and, for a container, everything inside it.
static func _hit(v: Variant, want: int, holder: String, path: String, out: Array) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	if d.is_empty() or is_ref(d) or not d.has("uid"):
		return false
	if want < 0 or int(d.get("uid", -1)) == want:
		out.append({"path": path, "holder": holder, "item": d})
		if want >= 0:
			return true
	var cont: Variant = d.get("contents")   # containers (bags and chests) wait only on the returns shelf
	if cont is Array and holder == "returns":
		for i in (cont as Array).size():
			if _hit(cont[i], want, holder, "%s/contents[%d]" % [path, i], out):
				return true
	return false


static func _arr(v: Variant, want: int, holder: String, base: String, out: Array) -> bool:
	if not (v is Array):
		return false
	var a: Array = v
	for i in a.size():
		var it: Variant = a[i]
		if want >= 0 and it is Dictionary and int(it.get("uid", -1)) != want and not (it as Dictionary).has("contents"):
			continue   # fast path: no path string for a miss
		if _hit(it, want, holder, "%s[%d]" % [base, i], out):
			return true
	return false


static func _slots(v: Variant, want: int, holder: String, base: String, out: Array) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	for k in d:
		var it: Variant = d[k]
		if want >= 0 and it is Dictionary and int(it.get("uid", -1)) != want:
			continue
		if _hit(it, want, holder, "%s/%s" % [base, str(k)], out):
			return true
	return false


## Arrays of entries that hold their piece under "item" (offers, pledges, stock, lost gear, holdings, customers).
static func _wrapped(v: Variant, want: int, holder: String, base: String, out: Array) -> bool:
	if not (v is Array):
		return false
	var a: Array = v
	for i in a.size():
		if not (a[i] is Dictionary):
			continue
		var it: Variant = a[i].get("item", {})
		if want >= 0 and it is Dictionary and int(it.get("uid", -1)) != want and not (it as Dictionary).has("contents"):
			continue
		if _hit(it, want, holder, "%s[%d]/item" % [base, i], out):
			return true
	return false


# ======================================================================= leaving the simulated world
## A piece passes to someone the world does not simulate (a market buyer, a passing stranger, the caravan): the hand-over
## is recorded on the piece (one transfer, one Lore event, the owner's name as people would say it). The caller then
## lets go of it; the ItemStory pool keeps the smith's own pieces in memory so they can turn up again.
static func leave(it: Dictionary, to_id: String, to_name: String, how: String, note: String, place := "brindlewick") -> void:
	if it.is_empty() or is_ref(it) or not Provenance.applies(it):
		return
	Provenance.transfer(it, to_id, how, place, note)
	var ow: Array = Provenance.owners(it)
	if not ow.is_empty() and str(ow[-1].get("id", "")) == to_id:
		ow[-1]["name"] = to_name


# ======================================================================= the holdings archive
## A piece leaves for a holder the world does not simulate (a patron's house): it is kept here with its full
## identity, outside any capped history. `via` names the occasion ("contract"), `data` links the record.
static func archive(it: Dictionary, holder_id: String, holder_name: String, via: String, data := {}) -> void:
	if it.is_empty() or is_ref(it):
		return
	var u := int(it.get("uid", -1))
	for x in holdings():
		if int(x.get("item", {}).get("uid", -2)) == u:
			return
	holdings().append({"item": it, "holder": holder_id, "holder_name": holder_name, "day": Game.day(), "via": via, "data": data.duplicate(true)})


# ======================================================================= the integrity probe
## Scans a state for identity faults. Returns {items, uids, dup: [{uid, paths}], shared: [{uid, paths}],
## stray: [{uid, path}], records}:
##   dup    — one uid held by two live physical holders (by uid: catches split copies after save/load);
##   shared — one dict object reachable from two places anywhere in the state (in memory);
##   stray  — a full item dict outside every registered holder (a record holding a live copy: a fork).
static func scan(state := {}) -> Dictionary:
	var s := _s(state)
	var res := {"items": 0, "uids": 0, "dup": [], "shared": [], "stray": [], "records": 0}
	if s.is_empty():
		return res
	var live := locations(ALL, s)
	var by_uid := {}
	for x in live:
		var u := int(x["item"].get("uid", -1))
		if not by_uid.has(u):
			by_uid[u] = []
		(by_uid[u] as Array).append(x)
	res["items"] = live.size()
	res["uids"] = by_uid.size()
	for u in by_uid:
		if (by_uid[u] as Array).size() > 1:
			(res["dup"] as Array).append({"uid": u, "paths": (by_uid[u] as Array).map(func(x): return x["path"])})
	# every item-shaped dict in the whole state
	var all := []
	_walk(s, "", all)
	var seen := {}    # uid -> [[path, dict]]
	for x in all:
		var u2 := int(x[1].get("uid", -1))
		if not seen.has(u2):
			seen[u2] = []
		(seen[u2] as Array).append(x)
	var pool: Variant = s.get("item_story", {}).get("pool", {})
	for u3 in seen:
		var group: Array = seen[u3]
		# shared: the same object twice
		for i in group.size():
			for j in range(i + 1, group.size()):
				if is_same(group[i][1], group[j][1]):
					(res["shared"] as Array).append({"uid": u3, "paths": [group[i][0], group[j][0]]})
		for x2 in group:
			var d: Dictionary = x2[1]
			if is_ref(d):
				res["records"] = int(res["records"]) + 1
				continue
			if not d.has("stats"):
				continue   # a register entry (famous creations, Hall of Fame), not an item
			var known := false
			for l in by_uid.get(u3, []):
				if is_same(l["item"], d):
					known = true
					break
			if not known and pool is Dictionary and is_same((pool as Dictionary).get(str(u3), null), d):
				known = true
			if not known:
				(res["stray"] as Array).append({"uid": u3, "path": x2[0]})
	return res


## Item-shaped dicts: a uid and a known item def.
static func _walk(v: Variant, path: String, out: Array) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("uid") and d.has("def") and (d["uid"] is int or d["uid"] is float) and not DB.item(str(d["def"])).is_empty():
			out.append([path, d])
		for k in d:
			var c: Variant = d[k]
			if c is Dictionary or c is Array:
				_walk(c, path + "/" + str(k), out)
	elif v is Array:
		var a: Array = v
		for i in a.size():
			var c2: Variant = a[i]
			if c2 is Dictionary or c2 is Array:
				_walk(c2, "%s[%d]" % [path, i], out)


## One line for logs and test notes.
static func scan_text(r: Dictionary) -> String:
	return "%d items, %d uids, %d duplicate uids, %d shared dicts, %d strays, %d references" % [int(r["items"]), int(r["uids"]),
		(r["dup"] as Array).size(), (r["shared"] as Array).size(), (r["stray"] as Array).size(), int(r["records"])]


# ======================================================================= migration of older saves
## Converts a loaded save (raw data, before Game.from_save) to the A1 identity rules. Idempotent: a second call
## returns 0 and changes nothing. Returns the number of changes. Converts:
##   1. records holding live dicts → references: exp.done[].loot[], customers[].item and customers[].parts[].item
##      for an adventurer's own piece (own_slot); a done expedition's pack is a report, not a holder;
##   2. contracts.history[].masterpiece.item → moved into item_registry.holdings (full identity), a reference left;
##   3. one uid in two live physical holders → the most authoritative holder keeps it (AUTHORITY), the other
##      place drops it (an entry that only wraps the piece keeps a reference). Each case is logged.
## Shared dict objects (same piece twice in memory) are resolved by the same rules.
static func migrate_records(state: Dictionary) -> int:
	if state.is_empty():
		return 0
	var n := 0
	# 1. records
	var done: Variant = _dig(state, ["exp", "done"])
	if done is Array:
		for e in done:
			if e is Dictionary and e.get("loot") is Array:
				var loot: Array = e["loot"]
				for i in loot.size():
					if loot[i] is Dictionary and not is_ref(loot[i]) and (loot[i] as Dictionary).has("uid"):
						loot[i] = ref(loot[i])
						n += 1
	var cs: Variant = state.get("customers", [])
	if cs is Array:
		for c in cs:
			if not (c is Dictionary):
				continue
			if c.has("own_slot") and c.get("item") is Dictionary and not is_ref(c["item"]) and not (c["item"] as Dictionary).is_empty():
				c["item"] = ref(c["item"])
				n += 1
			for pt in c.get("parts", []):
				if pt is Dictionary and pt.has("own_slot") and pt.get("item") is Dictionary and not is_ref(pt["item"]) and not (pt["item"] as Dictionary).is_empty():
					pt["item"] = ref(pt["item"])
					n += 1
	# 2. delivered masterpieces leave the capped history for the holdings archive
	var hist: Variant = _dig(state, ["contracts", "history"])
	if hist is Array:
		for c2 in hist:
			if not (c2 is Dictionary) or not (c2.get("masterpiece") is Dictionary):
				continue
			var mp: Dictionary = c2["masterpiece"]
			var it: Variant = mp.get("item", {})
			if not (it is Dictionary) or (it as Dictionary).is_empty() or is_ref(it) or str(c2.get("outcome", "")) == "failed":
				continue
			if not state.has("item_registry"):
				state["item_registry"] = {"holdings": []}
			if not state["item_registry"].has("holdings"):
				state["item_registry"]["holdings"] = []
			var hold: Array = state["item_registry"]["holdings"]
			var have := false
			for x in hold:
				if x is Dictionary and int(x.get("item", {}).get("uid", -2)) == int(it.get("uid", -1)):
					have = true
			if not have:
				var pid := str(c2.get("patron", ""))
				hold.append({"item": it, "holder": "patron_" + pid, "holder_name": pid, "day": int(c2.get("closed_day", state.get("day", 0))),
					"via": "contract", "data": {"contract": str(c2.get("id", ""))}})
			mp["item"] = ref(it)
			n += 1
			Log.info("Item identity: the masterpiece of %s (uid %d) moved to the holdings archive" % [str(c2.get("id", "")), int(it.get("uid", -1))])
	# 3. one uid, two live holders
	var locs := locations(ALL, state)
	var by_uid := {}
	for x2 in locs:
		var u := int(x2["item"].get("uid", -1))
		if not by_uid.has(u):
			by_uid[u] = []
		(by_uid[u] as Array).append(x2)
	var drops := []
	for u2 in by_uid:
		var group: Array = by_uid[u2]
		if group.size() < 2:
			continue
		group.sort_custom(func(a, b): return _rank(a) < _rank(b))
		for k in range(1, group.size()):
			drops.append(group[k])
			Log.info("Item identity: uid %d was held twice; kept %s, dropped %s" % [u2, str(group[0]["path"]), str(group[k]["path"])])
	for dr in drops:
		if _drop(state, str(dr["path"]), dr["item"]):
			n += 1
	return n


static func _rank(x: Dictionary) -> int:
	var r := AUTHORITY.find(str(x["holder"]))
	return r if r >= 0 else AUTHORITY.size()


## Removes the piece at `path` (a location from locations()): a slot or list entry is removed; an entry that wraps
## the piece under "item" keeps a reference so its readable text survives.
static func _drop(state: Dictionary, path: String, it: Dictionary) -> bool:
	var parent := _parent(state, path)
	if parent.is_empty():
		return false
	var holder: Variant = parent["holder"]
	var key: Variant = parent["key"]
	if holder is Array:
		var arr: Array = holder
		for i in arr.size():   # by identity: earlier drops may have shifted the indices
			if is_same(arr[i], it):
				arr.remove_at(i)
				return true
		return false
	if holder is Dictionary:
		var d: Dictionary = holder
		if not is_same(d.get(key), it):
			return false
		var cs: Variant = state.get("customers", [])
		if str(key) == "item" and cs is Array and (cs as Array).any(func(c): return is_same(c, d)):
			(cs as Array).erase(d)   # a villager waiting with a copy of a piece that is elsewhere simply never came
			return true
		if str(key) == "item":
			d["item"] = ref(it)
		else:
			d.erase(key)
		return true
	return false


## The container and key that hold the value at `path` ("/a/b[2]/item").
static func _parent(state: Dictionary, path: String) -> Dictionary:
	var toks := []
	for part in path.split("/", false):
		var name := part
		var idx := []
		while name.ends_with("]") and name.contains("["):
			var o := name.rfind("[")
			idx.push_front(int(name.substr(o + 1, name.length() - o - 2)))
			name = name.substr(0, o)
		if name != "":
			toks.append(name)
		toks.append_array(idx)
	if toks.is_empty():
		return {}
	var cur: Variant = state
	for i in toks.size() - 1:
		var t: Variant = toks[i]
		if t is int and cur is Array and int(t) < (cur as Array).size():
			cur = cur[t]
		elif t is String and cur is Dictionary and (cur as Dictionary).has(t):
			cur = cur[t]
		else:
			return {}
	return {"holder": cur, "key": toks[-1]}
