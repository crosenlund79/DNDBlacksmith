## History — collects the event history of a person, an item or a workstation from the records the
## other systems already keep (Chronicle, Social memories, the ledger, orders, item histories,
## adventurer and hireling logs) plus a small per-station work log kept here.
## EN: Every collector returns entries {day:int, time:String, kind:String, text:String, q?:float}
##     sorted newest first. kind is one of: deed, memory, trade, gift, expedition, commission, work,
##     craft, owner, note — the History panel groups and colours by it.
## DA: Samler historikken for en person, en genstand eller en arbejdsstation fra eksisterende optegnelser.
class_name History
extends RefCounted

const STATION_CAP := 40


# ======================================================================= station log
static func station_log() -> Dictionary:
	if not Game.state.has("station_log"):
		Game.state["station_log"] = {}
	return Game.state["station_log"]


## Appends a line to a workstation's log (capped). `extra` may carry q (quality), item (uid), rarity.
static func log_station(station_id: String, text: String, extra := {}) -> void:
	if station_id == "":
		return
	var lg := station_log()
	if not lg.has(station_id):
		lg[station_id] = []
	var e := {"day": Game.day(), "time": Game.time_string(), "text": text}
	e.merge(extra)
	(lg[station_id] as Array).append(e)
	while (lg[station_id] as Array).size() > STATION_CAP:
		(lg[station_id] as Array).pop_front()


## Called once when a piece is finished (Crafting.finish): every station that worked on it logs it.
static func log_crafted(it: Dictionary) -> void:
	var cr: Dictionary = it.get("craft", {})
	var seen := {}
	for o in cr.get("ops", []):
		var st := str(o.get("station", ""))
		if st == "" or seen.has(st):
			continue
		seen[st] = true
		log_station(st, "%s — %s for %s" % [Items.display_name(it), str(o.get("op", "worked")).to_lower(), str(cr.get("recipe_name", "a commission"))],
			{"q": float(o.get("q", 0.0)), "final_q": float(cr.get("quality", it.get("quality", 0.0))), "item": int(it.get("uid", 0)),
			"rarity": str(it.get("rarity", "common"))})


static func station_entries(station_id: String) -> Array:
	var out := []
	for e in station_log().get(station_id, []):
		var q := float(e.get("q", -1.0))
		var txt := str(e["text"])
		if q >= 0.0:
			txt += " · step %d%%, finished piece %d%% (%s)" % [int(round(q)), int(round(float(e.get("final_q", q)))), Items.RARITY_LABEL.get(str(e.get("rarity", "common")), "Common")]
		out.append({"day": int(e["day"]), "time": str(e.get("time", "")), "kind": "craft", "text": txt, "q": q, "item": int(e.get("item", 0))})
	return _sorted(out)


# ======================================================================= people
static func _refs_hit(refs: Dictionary, id: String) -> bool:
	for k in refs:
		var v: Variant = refs[k]
		if v is Array:
			if (v as Array).has(id):
				return true
		elif str(v) == id:
			return true
	return false


static func _chronicle_kind(k: String) -> String:
	if k in ["departure", "return", "victory", "defeat", "death", "missing", "rescue", "discovery", "chain"]:
		return "expedition"
	if k in ["sale", "item", "relic"]:
		return "trade"
	if k == "commission":
		return "commission"
	return "deed"


static func npc_entries(npc: String) -> Array:
	var out := []
	var name := Talk.npc_name(npc)
	for e in Chronicle.entries():
		if _refs_hit(e.get("refs", {}), npc):
			out.append({"day": int(e["day"]), "time": str(e.get("time", "")), "kind": _chronicle_kind(str(e["kind"])), "text": str(e["text"])})
	if Game.state.get("social", {}).has(npc):
		for m in Social.ensure(npc)["memories"]:
			var key := str(m.get("key", ""))
			var kind := "gift" if key.begins_with("gift") or key.begins_with("gave_gift") else "memory"
			out.append({"day": int(m["day"]), "time": "", "kind": kind, "text": "%s remembers: “%s”" % [name, str(m["text"])], "w": float(m.get("w", 0.0))})
	# purchases and payments: the ledger names the person in its note
	if name != "" and name != npc:
		for l in Game.state.get("ledger", []):
			var note := str(l.get("note", ""))
			if note.contains(name):
				out.append({"day": int(l["day"]), "time": "", "kind": "trade", "text": "%s (%+d g)" % [note, int(l["amount"])]})
	for o in Game.state.get("orders", []):
		if str(o.get("npc", "")) == npc:
			var st := str(o.get("status", "open"))
			out.append({"day": int(o.get("placed", Game.day())), "time": "", "kind": "commission",
				"text": "Commission: %s — %s" % [Shop.order_text(o), st]})
	var a := Adv.get_a(npc)
	if not a.is_empty():
		for h in a.get("history", []):
			var reg := Expeditions.region(str(h.get("dest", "")))
			var dest: String = reg.get("name", DB.destinations.get(str(h.get("dest", "")), {}).get("name", str(h.get("dest", "somewhere"))))
			out.append({"day": int(h.get("day", 0)), "time": "", "kind": "expedition",
				"text": "Expedition to %s — %s." % [dest, str(h.get("outcome", "")).replace("_", ", ")]})
	var hl := Hire.get_h(npc)
	if not hl.is_empty():
		out.append({"day": int(hl.get("hired_day", 1)), "time": "", "kind": "work", "text": "Hired at the Ironhand forge (%d g a day)." % int(hl.get("wage", 0))})
		for line in hl.get("log", []):
			var s := str(line)
			var d := 0
			if s.begins_with("Day "):
				d = int(s.substr(4, s.find(" ", 4) - 4))
			out.append({"day": d, "time": "", "kind": "work", "text": s.substr(s.find("— ") + 2) if s.contains("— ") else s})
	return _dedupe(_sorted(out))


# ======================================================================= items
static func item_entries(it: Dictionary) -> Array:
	var out := []
	if it.is_empty():
		return out
	var cr: Dictionary = it.get("craft", {})
	if not cr.is_empty():
		var steps := []
		for o in cr.get("ops", []):
			steps.append("%s at %s %d%%" % [str(o.get("op", "")), DB.station(str(o.get("station", ""))).get("name", str(o.get("station", ""))), int(round(float(o.get("q", 0))))])
		out.append({"day": int(cr.get("day", 1)), "time": "", "kind": "craft",
			"text": "Crafted to the %s Design%s: %s. Final craftsmanship %d%%." % [str(cr.get("recipe_name", "")),
				(" in " + str(cr["material"])) if str(cr.get("material", "")) != "" else "", "; ".join(steps) if not steps.is_empty() else "worked by hand",
				int(round(float(cr.get("quality", it.get("quality", 0)))))], "q": float(cr.get("quality", 0))})
	for h in it.get("history", []):
		var txt := str(h["text"])
		var kind := "owner" if txt.begins_with("Sold to") or txt.begins_with("Given to") or txt.contains("bought") else "note"
		if txt.begins_with("Forged") and not cr.is_empty():
			kind = "craft"
		out.append({"day": int(h["day"]), "time": "", "kind": kind, "text": txt})
	var uid := str(it.get("uid", ""))
	if uid != "":
		for e in Chronicle.entries():
			var rf: Dictionary = e.get("refs", {})
			if str(rf.get("item", "")) == uid or str(rf.get("uid", "")) == uid:
				out.append({"day": int(e["day"]), "time": str(e.get("time", "")), "kind": "deed", "text": str(e["text"])})
	return _dedupe(_sorted(out))


## The chain of hands an item passed through, oldest first (maker → buyers → current holder).
static func owner_chain(it: Dictionary) -> Array:
	var chain := []
	if str(it.get("crafted_by", "")) != "":
		chain.append(str(it["crafted_by"]))
	elif not it.get("craft", {}).is_empty():
		chain.append("Brannoc Ironhand")
	for h in it.get("history", []):
		var t := str(h["text"])
		for pre in ["Sold to ", "Given to "]:
			if t.begins_with(pre):
				var rest := t.substr(pre.length())
				var cut := rest.length()
				for sep in [" for ", ",", "."]:
					var i := rest.find(sep)
					if i > 0 and i < cut:
						cut = i
				chain.append(rest.substr(0, cut))
	var holder := str(it.get("owner", ""))
	if holder == "smith" and (chain.is_empty() or chain[-1] != "Brannoc Ironhand"):
		chain.append("Brannoc Ironhand")
	return chain


# ======================================================================= helpers
static func _sorted(arr: Array) -> Array:
	for i in arr.size():
		arr[i]["_i"] = i
	arr.sort_custom(func(a, b): return int(a["day"]) > int(b["day"]) or (int(a["day"]) == int(b["day"]) and int(a["_i"]) > int(b["_i"])))
	return arr


static func _dedupe(arr: Array) -> Array:
	var seen := {}
	var out := []
	for e in arr:
		var k := "%d|%s" % [int(e["day"]), str(e["text"])]
		if seen.has(k):
			continue
		seen[k] = true
		out.append(e)
	return out


## An item instance anywhere in the world (stores, the smith's own gear, adventurers, hirelings, offers).
static func find_item(uid: int) -> Dictionary:
	# stores, adventurers' and hirelings' gear, the smith's own gear, offers at the counter (ItemRegistry)
	return ItemRegistry.find(uid, ItemRegistry.HISTORY)
