## Guide — how to get any item and how to make any recipe, generated from the real data and systems.
## EN: Nothing here is written per item. Sources are read from trade.json (Pell's Provisions, the herbalist,
##     merchant ships, special imports), commerce.json (the Brask caravan, the Salt Anvil), suppliers.json
##     (hireling trade runs), loot tables of hireling destinations and adventurer sites, hireling work output,
##     recipes (with their real locks: skill tree, skills, stations, rooms), apprentices and the weekly
##     delivery. Starting stock is not a source. Secrets stay secret: recipes behind a discovery flag, gated
##     destinations, exotic imports the smith has never heard of are never listed.
##     Progressive disclosure for the UI: status()/recipe_status() at a glance, next_step() "show me how",
##     sources()/tree()/alternatives() for the full details.
## DA: Hvordan man skaffer en ting, og hvordan man laver en opskrift — genereret af de rigtige data.
##
## Public API (static):
##   sources(def) -> Array[{kind, id, name, where, how, price, chance, when, state, why, link {route, args}, rank}]
##       kind: craft|vendor|ship|import|caravan|trade_run|hireling_work|expedition|site|delivery|apprentice
##       state: ready (can be done right now) | obtainable (possible, later or elsewhere) | locked (public obstacle)
##   status(def, qty := 1) -> "have"|"obtainable"|"locked"|"unavailable"
##   recipe_status(rid) -> {state "ready"|"missing"|"locked"|"hidden", obstacles [{kind, id, text, link, ...}], missing {def: n}}
##   tree(id, depth := 4, qty := 1) -> {type "item"|"recipe"|"station", id, name, state, children, ...}  ("recipe:<id>" or a def)
##   next_step(id) -> {text, action {route, args} | {}, why}          alternatives(id) -> Array[source]
##   best_source(def) -> Dictionary     tooltip_line(def) -> String    recipes_making(def) / recipes_using(def)
##   venue_name(id) / venue_open(id) / venue_when(id)   (asks Venues when that system exists)
class_name Guide
extends RefCounted

const VENUES_PATH := "res://scripts/systems/venues.gd"
## Fallback keeper hours (world.gd spot_for / Commerce.spot_for) for when the Venues registry is absent.
const VENUES := {
	"general_store": {"name": "Pell's Provisions", "keeper": "aldric", "open": 7, "close": 19},
	"herbalist": {"name": "Fennimore's Simples", "keeper": "herbalist", "open": 8, "close": 18},
	"harbour": {"name": "Brindlewick Harbour", "keeper": "harbourmaster", "open": 6, "close": 19},
	"pawn": {"name": "Quell's Pledges & Loans", "keeper": "pawnbroker", "open": 8, "close": 19},
	"rival_smith": {"name": "The Salt Anvil", "keeper": "rival_smith", "open": 7, "close": 18},
	"caravan": {"name": "The Brask Caravan", "keeper": "caravan_master", "open": 7, "close": 22},
}
const KIND_ORDER := ["vendor", "craft", "ship", "caravan", "rival", "import", "trade_run", "hireling_work", "apprentice", "expedition", "delivery", "site"]
const STATE_BASE := {"ready": 0, "obtainable": 10, "locked": 20, "unavailable": 30}
const STATE_ICON := {"ready": "ui/guide_ready", "have": "ui/guide_ready", "obtainable": "ui/guide_obtainable", "missing": "ui/guide_obtainable",
	"locked": "ui/guide_locked", "unavailable": "ui/guide_unavailable", "hidden": "ui/guide_unavailable"}
const STATE_WORD := {"ready": "Ready", "have": "In your stores", "obtainable": "Obtainable", "missing": "Missing materials",
	"locked": "Locked", "unavailable": "No known source", "hidden": "Unknown"}
const STATE_COLOR := {"ready": "#26622f", "have": "#26622f", "obtainable": "#8a5a10", "missing": "#8a5a10", "locked": "#7e2418",
	"unavailable": "#6b5b45", "hidden": "#6b5b45"}


# ======================================================================= venues
static func _venues_call(method: String, args: Array) -> Variant:
	if not ResourceLoader.exists(VENUES_PATH):
		return null
	var sc: Script = load(VENUES_PATH)
	for m in sc.get_script_method_list():
		if str(m["name"]) == method:
			return sc.callv(method, args)
	return null


static func venue_name(id: String) -> String:
	var v: Variant = _venues_call("name_of", [id])
	if v is String and str(v) != "":
		return str(v)
	return str(VENUES.get(id, {}).get("name", id.capitalize()))


static func _hours(id: String) -> Array:
	var v: Variant = _venues_call("hours", [id])
	if v is Array and (v as Array).size() >= 2:
		return [int(v[0]), int(v[1])]
	var f: Dictionary = VENUES.get(id, {})
	return [int(f.get("open", 0)), int(f.get("close", 24))]


static func venue_open(id: String) -> bool:
	var v: Variant = _venues_call("is_open", [id])
	if v is bool:
		return bool(v)
	var h := _hours(id)
	return Game.hour() >= int(h[0]) and Game.hour() < int(h[1])


## "open now, until 19:00" / "opens at 7:00" / "opens tomorrow at 7:00"
static func venue_when(id: String) -> String:
	var h := _hours(id)
	if venue_open(id):
		return "open now, until %d:00" % int(h[1])
	if Game.hour() < int(h[0]):
		return "opens at %d:00" % int(h[0])
	return "opens tomorrow at %d:00" % int(h[0])


static func _map_link(venue: String) -> Dictionary:
	return {"route": "map", "args": {"venue": venue}}


static func _help_link(topic: String) -> Dictionary:
	return {"route": "help", "args": {"topic": topic}}


# ======================================================================= small helpers
static func iname(def: String) -> String:
	return str(DB.item(def).get("name", def.capitalize().replace("_", " ")))


static func sname(sid: String) -> String:
	return str(DB.station(sid).get("name", sid.capitalize().replace("_", " ")))


## "the Anvil", "the Forge / Hearth" — for sentences ("at the …"), without doubling a name's own "The".
static func the_station(sid: String) -> String:
	var n := sname(sid)
	return ("the " + n.substr(4)) if n.begins_with("The ") else "the " + n


static func _pf() -> float:
	return Trade.price_factor()


static func _has_hireling() -> bool:
	return Game.state.has("hirelings") and Hire.alive_count() > 0


static func recipe_visible(rid: String) -> bool:
	return Reference.recipe_visible(rid)


## Visible recipes that make this item (unlocked first, then by difficulty, then id).
static func recipes_making(def: String) -> Array:
	var out := []
	for r in DB.recipes.values():
		if str(r.get("output", "")) == def and recipe_visible(str(r["id"])):
			out.append(r)
	out.sort_custom(func(a, b):
		var la := Crafting.recipe_locked_reason(str(a["id"])) != ""
		var lb := Crafting.recipe_locked_reason(str(b["id"])) != ""
		if la != lb:
			return lb
		if int(a.get("difficulty", 0)) != int(b.get("difficulty", 0)):
			return int(a.get("difficulty", 0)) < int(b.get("difficulty", 0))
		return str(a["id"]) < str(b["id"]))
	return out


## Visible recipes that use this item.
static func recipes_using(def: String) -> Array:
	var out := []
	for r in DB.recipes.values():
		if (r.get("inputs", {}) as Dictionary).has(def) and recipe_visible(str(r["id"])):
			out.append(r)
	out.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return out


static func _src(out: Array, kind: String, id: String, name: String, where: String, how: String, state: String, why := "", when := "",
		link := {}, price := -1, chance := -1.0) -> Dictionary:
	var s := {"kind": kind, "id": id, "name": name, "where": where, "how": how, "state": state, "why": why, "when": when,
		"link": link, "price": price, "chance": chance}
	out.append(s)
	return s


# ======================================================================= sources
static func sources(def: String) -> Array:
	var out := []
	if DB.item(def).is_empty() or Game.state.is_empty():
		return out
	_src_craft(def, out)
	_src_vendor(def, "general_store", out)
	_src_vendor(def, "herbalist", out)
	_src_ships(def, out)
	_src_caravan(def, out)
	_src_rival(def, out)
	_src_import(def, out)
	_src_trade_run(def, out)
	_src_hireling_work(def, out)
	_src_expedition(def, out)
	_src_site(def, out)
	_src_delivery(def, out)
	for s in out:
		s["rank"] = _rank(s)
	out.sort_custom(func(a, b):
		if int(a["rank"]) != int(b["rank"]):
			return int(a["rank"]) < int(b["rank"])
		if int(a["price"]) != int(b["price"]):
			return int(a["price"]) < int(b["price"])
		return str(a["id"]) < str(b["id"]))
	return out


static func _rank(s: Dictionary) -> int:
	var base := int(STATE_BASE.get(str(s["state"]), 30))
	if str(s["state"]) == "obtainable":
		if str(s["kind"]) == "craft" and bool(s.get("inputs_ready", false)):
			base = 5    # every missing input can be had right now
		elif str(s["kind"]) == "vendor" and bool(s.get("opens_today", false)):
			base = 8    # the shop opens later today
	return base * 100 + KIND_ORDER.find(str(s["kind"])) * 5


static func _src_craft(def: String, out: Array) -> void:
	for r in recipes_making(def):
		var rid := str(r["id"])
		var steps: Array = r.get("steps", [])
		var first := the_station(str(steps[0])) if not steps.is_empty() else "the workshop"
		var where_parts := []
		for s in steps:
			if not where_parts.has(sname(str(s))):
				where_parts.append(sname(str(s)))
		var lock := Crafting.recipe_locked_reason(rid)
		var miss := Crafting.missing_inputs(rid)
		var state := "locked" if lock != "" else ("ready" if miss.is_empty() else "obtainable")
		var why := lock
		var inputs_ready := true
		if lock == "" and not miss.is_empty():
			var parts := []
			for d in miss:
				parts.append("%d× %s" % [int(miss[d]), iname(str(d))])
				var ok := false
				for s2 in _quick_sources(str(d)):
					if str(s2["state"]) == "ready":
						ok = true
				inputs_ready = inputs_ready and ok
			why = "missing " + ", ".join(parts)
		var s := _src(out, "craft", rid, str(r.get("name", rid)), " → ".join(where_parts),
			"Make it: %s at %s" % [str(r.get("name", rid)), first], state, why, "", _help_link("recipe:" + rid))
		s["inputs_ready"] = inputs_ready and lock == "" and not miss.is_empty()
		s["yield"] = int(r.get("qty", 1))
		# an apprentice can prepare materials (not equipment) from the same recipe
		if lock == "" and not Items.is_equipment({"def": def}) and Game.state.has("apprentices") and not Apprentices.staff().is_empty():
			_src(out, "apprentice", rid, "Your apprentice", "Workshop Ledger (Y)",
				"Queue “%s” for an apprentice — Workshop Ledger (Y)" % str(r.get("name", rid)), "obtainable" if not miss.is_empty() else "ready",
				why, "during their shift, 8:00–18:00", {"route": "workshop", "args": {}})


## Buy-now sources only (no recursion): vendors open and stocked, a docked ship or caravan with it.
static func _quick_sources(def: String) -> Array:
	var out := []
	_src_vendor(def, "general_store", out)
	_src_vendor(def, "herbalist", out)
	_src_ships(def, out)
	_src_caravan(def, out)
	return out


static func _vendor_rows(venue: String) -> Array:
	var key := "general_store" if venue == "general_store" else "herbalist"
	return Trade.cfg().get(key, {}).get("stock", [])


## Today's stock of a vendor without restocking it here: {def: qty} or {} when unknown (not yet stocked today).
static func _vendor_today(venue: String) -> Dictionary:
	var out := {}
	var rows: Variant = null
	if venue == "herbalist":
		var h: Dictionary = Game.state.get("trade", {}).get("herb", {})
		if int(h.get("day", 0)) == Game.day():
			rows = h.get("stock", [])
	else:
		var g: Dictionary = Game.state.get("trade", {}).get("store", {})
		if int(g.get("day", -1)) == Game.day():
			rows = g.get("stock", [])
	if rows is Array:
		for e in rows:
			if e is Dictionary:
				out[str(e.get("def", ""))] = int(e.get("qty", 0))
	return out


static func _src_vendor(def: String, venue: String, out: Array) -> void:
	for e in _vendor_rows(venue):
		if str(e[0]) != def:
			continue
		var price := maxi(1, int(round(float(e[1]) * _pf())))
		var today := _vendor_today(venue)
		var open := venue_open(venue)
		var sold_out := today.has(def) and int(today[def]) <= 0
		var state := "ready" if open and not sold_out else "obtainable"
		var when := "sold out until tomorrow" if sold_out else venue_when(venue)
		var s := _src(out, "vendor", venue, venue_name(venue), venue_name(venue), "Buy at %s (%d g each)" % [venue_name(venue), price],
			state, "", when, _map_link(venue), price)
		s["opens_today"] = not open and not sold_out and Game.hour() < int(_hours(venue)[0])
		return


static func _src_ships(def: String, out: Array) -> void:
	var ships: Dictionary = Trade.cfg().get("ships", {})
	var t: Dictionary = Game.state.get("trade", {})
	var cur: Dictionary = t.get("ship", {})
	var nxt: Dictionary = t.get("next", {})
	var types := ships.keys()
	types.sort()
	for type in types:
		var sd: Dictionary = ships[type]
		var row: Array = []
		for e in sd.get("stock", []):
			if str(e[0]) == def:
				row = e
		if row.is_empty():
			continue
		var label := str(sd.get("label", type))
		var price := maxi(1, int(round(float(DB.item(def).get("value", 5)) * float(row[1]) * _pf())))
		var chance := float(row[3])
		if str(cur.get("type", "")) == str(type):
			var held := 0
			for st in cur.get("stock", []):
				if str(st.get("def", "")) == def and not st.has("item"):
					held = int(st.get("qty", 0))
					price = int(st.get("price", price))
			if held > 0:
				var open := venue_open("harbour")
				_src(out, "ship", str(type), str(cur.get("name", label)), "Brindlewick Harbour",
					"Buy from %s at the quay (%d g each)" % [str(cur.get("name", label)), price], "ready" if open else "obtainable", "",
					"in port now" + ("" if open else " — the quay " + venue_when("harbour")), _map_link("harbour"), price, chance)
				continue
		var when := "calls every few days; carries it on about %d%% of voyages" % int(round(chance * 100.0))
		if str(nxt.get("type", "")) == str(type):
			var days := maxi(0, int(ceil(float(int(nxt.get("at", 0)) - Game.now()) / 1440.0)))
			when = ("expected today" if days == 0 else "next ship in ~%d day%s" % [days, "" if days == 1 else "s"]) + " (carries it on about %d%% of voyages)" % int(round(chance * 100.0))
		_src(out, "ship", str(type), label, "Brindlewick Harbour", "Buy from the %s when she is in port (~%d g)" % [label.to_lower(), price],
			"obtainable", "", when, _map_link("harbour"), price, chance)


static func _src_caravan(def: String, out: Array) -> void:
	var cc: Dictionary = Commerce.cfg().get("caravan", {})
	var row: Array = []
	for e in cc.get("stock", []):
		if str(e[0]) == def:
			row = e
	if row.is_empty():
		return
	var price := maxi(1, int(round(float(DB.item(def).get("value", 5)) * float(row[1]) * _pf())))
	var label := str(cc.get("label", "The Brask Caravan"))
	if Commerce.caravan_present():
		for st in Commerce.caravan().get("stock", []):
			if str(st.get("def", "")) == def and not st.has("item") and int(st.get("qty", 0)) > 0:
				var open := venue_open("caravan")
				_src(out, "caravan", "caravan", label, "the caravan camp", "Buy from the caravan (%d g each)" % int(st.get("price", price)),
					"ready" if open else "obtainable", "", "camped in the village now", _map_link("caravan"), int(st.get("price", price)), float(row[3]))
				return
	var n := Commerce.next_caravan()
	var when := "visits every week or so"
	if not n.is_empty():
		when = "next visit in ~%d day%s" % [int(n["days"]), "" if int(n["days"]) == 1 else "s"]
	_src(out, "caravan", "caravan", label, "the caravan camp", "Buy from the caravan when it visits (~%d g)" % price, "obtainable", "",
		when + " (brings it about %d%% of visits)" % int(round(float(row[3]) * 100.0)), _map_link("caravan"), price, float(row[3]))


static func _src_rival(def: String, out: Array) -> void:
	var rc: Dictionary = Commerce.rival_cfg()
	for e in rc.get("materials", []):
		if str(e[0]) != def:
			continue
		var price := maxi(1, int(round(float(DB.item(def).get("value", 5)) * float(e[1]) * _pf())))
		_src(out, "rival", "rival_smith", str(rc.get("shop", "The Salt Anvil")), str(rc.get("shop", "The Salt Anvil")),
			"Buy from your rival at %s (~%d g, when in stock)" % [str(rc.get("shop", "The Salt Anvil")), price], "obtainable", "",
			venue_when("rival_smith") + "; restocks every few days", _map_link("rival_smith"), price, float(e[3]))
		return


static func _src_import(def: String, out: Array) -> void:
	var info := Trade.import_info(def)
	if info.is_empty():
		return
	var lead: Array = info["lead"]
	if Trade.knows(def):
		_src(out, "import", def, "Special import", "Brindlewick Harbour",
			"Order it from the harbourmaster (%d g each, %d%% deposit)" % [int(info["unit"]), int(round(float(info["deposit_share"]) * 100.0))],
			"obtainable", "", "arrives %d–%d days after ordering" % [int(lead[0]), int(lead[1])], _map_link("harbour"), int(info["unit"]))
	elif not str(info["tier"]) in ["exotic", "legendary"]:
		_src(out, "import", def, "Special import", "Brindlewick Harbour", "Order it from the harbourmaster", "locked",
			"The harbourmaster only orders goods you know — hold or see it once, or learn a recipe that uses it", "", _map_link("harbour"), int(info["unit"]))


static func _src_trade_run(def: String, out: Array) -> void:
	var keys := DB.suppliers.keys()
	keys.sort()
	keys.erase("village")
	keys.push_front("village")
	for k in keys:
		if str(k) == "_doc":
			continue
		var row: Array = []
		for e in DB.suppliers[k]:
			if str(e[0]) == def:
				row = e
		if row.is_empty():
			continue
		var price := int(row[1])
		var where := "the village markets"
		var state := "obtainable"
		var why := ""
		if str(k) != "village":
			var dest := _discoverer(str(k))
			where = str(dest.get("name", "the road"))
			if not Game.has_flag(str(k)):
				state = "locked"
				why = "No supplier known yet — send hirelings to %s until they find one" % where if not dest.is_empty() else "No supplier known yet"
		if state == "obtainable" and not _has_hireling():
			state = "locked"
			why = "Hire someone first (Hirelings, H)"
		_src(out, "trade_run", str(k), "Hireling trade run", where,
			"Send a hireling on a trade run with a purse (~%d g each from %s)" % [price, where], state, why, "back in a few days",
			{"route": "hirelings", "args": {}}, price)
		return


static func _discoverer(flag: String) -> Dictionary:
	for d in DB.destinations.values():
		if str(d.get("discovers", "")) == flag:
			return d
	return {}


static func _src_hireling_work(def: String, out: Array) -> void:
	for skill in Hire.WORK_OUTPUT:
		var hit := false
		for e in Hire.WORK_OUTPUT[skill]:
			if str(e[0]) == def:
				hit = true
		if (skill == "mining" and def == "ore_silver") or (skill == "alchemy" and def == "potion_healing"):
			hit = true
		if not hit:
			continue
		_src(out, "hireling_work", str(skill), "Hireling work", "the workshop",
			"Give a hireling %s work in their day (Hirelings › allocation)" % SkillSys.skill_name(str(skill)),
			"obtainable" if _has_hireling() else "locked", "" if _has_hireling() else "Hire someone first (Hirelings, H)",
			"during work hours", {"route": "hirelings", "args": {}})
		return


static func _loot_share(table: String, def: String) -> float:
	var t: Dictionary = DB.loot.get(table, {})
	var total := 0.0
	var mine := 0.0
	for e in t.get("entries", []):
		total += float(e[1])
		if str(e[0]) == def:
			mine += float(e[1])
	return mine / total if total > 0.0 else 0.0


static func _src_expedition(def: String, out: Array) -> void:
	var ds := DB.destinations.values()
	ds.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	for d in ds:
		var share := _loot_share(str(d.get("loot", "")), def)
		if share <= 0.0:
			continue
		if str(d.get("requires_flag", "")) != "" and not Game.has_flag(str(d["requires_flag"])):
			continue    # a route nobody knows yet stays secret
		var days: Array = d.get("days", [1, 2])
		_src(out, "expedition", str(d["id"]), str(d.get("name", d["id"])), "%s (%s exit)" % [str(d.get("name", "")), str(d.get("exit", ""))],
			"Send a hireling to %s (%d–%d days)" % [str(d.get("name", d["id"])), int(days[0]), int(days[1])],
			"obtainable" if _has_hireling() else "locked", "" if _has_hireling() else "Hire someone first (Hirelings, H)",
			"in about %d%% of the haul" % maxi(1, int(round(share * 100.0))), {"route": "hirelings", "args": {}}, -1, share)


static func _src_site(def: String, out: Array) -> void:
	var regs: Dictionary = Expeditions.cfg().get("regions", {})
	var ids := regs.keys()
	ids.sort()
	var names := []
	var first := ""
	for rid in ids:
		if not WorldSites.is_discovered(str(rid)):
			continue
		for n in regs[rid].get("nodes", []):
			if str(n.get("loot", "")) != "" and _loot_share(str(n["loot"]), def) > 0.0:
				if first == "":
					first = str(rid)
				names.append(str(regs[rid].get("name", rid)))
				break
	if not names.is_empty():
		_src(out, "site", first, "Adventurers' finds", ", ".join(names),
			"Adventurers back from %s offer their finds at your counter" % (", ".join(names.slice(0, names.size() - 1)) + " or " + str(names[-1]) if names.size() > 1 else str(names[0])),
			"obtainable", "", "when a party returns", {"route": "shop", "args": {}})


static func _src_delivery(def: String, out: Array) -> void:
	var friendly := Social.band("aldric") in ["friendly", "devoted", "warm"]
	if def == "bread_cheese" or (def == "herb_moonwort" and friendly):
		_src(out, "delivery", "aldric", "Aldric's weekly delivery", "your door", "Take Aldric's weekly provisions when he calls",
			"obtainable", "", "on day 3, then every 7th day", {})


# ======================================================================= status
static func status(def: String, qty := 1) -> String:
	if Game.count(def) >= qty:
		return "have"
	var best := "unavailable"
	for s in sources(def):
		var st := str(s["state"])
		if st in ["ready", "obtainable"]:
			return "obtainable"
		if st == "locked":
			best = "locked"
	return best


static func recipe_status(rid: String) -> Dictionary:
	var r := DB.recipe(rid)
	var out := {"state": "ready", "obstacles": [], "missing": {}}
	if r.is_empty() or not recipe_visible(rid):
		out["state"] = "hidden"
		return out
	var obs: Array = out["obstacles"]
	var ni := SkillTree.recipe_node(rid)
	if ni != "" and not SkillTree.is_unlocked(ni):
		var n := SkillTree.node(ni)
		var can := SkillTree.can_unlock(ni)
		obs.append({"kind": "node", "id": ni, "text": "Learn «%s» in the Skill Tree (%s)%s" % [str(n.get("name", ni)),
			str(SkillTree.branch(str(n.get("branch", ""))).get("name", "")), (" — " + can.trim_prefix("Requires ").strip_edges() + " first") if can != "" else ""],
			"link": {"route": "skilltree", "args": {"select": ni}}})
	var req: Dictionary = r.get("requires", {})
	for sk in req:
		if Game.player_level(str(sk)) < int(req[sk]):
			obs.append(_skill_obstacle(str(sk), int(req[sk])))
	var u: Dictionary = r.get("unlock", {})
	if u.has("skill"):
		var usk: Array = u["skill"]
		if Game.player_level(str(usk[0])) < int(usk[1]):
			obs.append(_skill_obstacle(str(usk[0]), int(usk[1])))
	var seen := {}
	for s in r.get("steps", []):
		var sid := str(s)
		if seen.has(sid):
			continue
		seen[sid] = true
		var why := Crafting.station_locked_reason(sid)
		if why != "":
			obs.append({"kind": "station", "id": sid, "text": "%s — %s" % [sname(sid), why], "why": why, "link": _help_link("station:" + sid)})
	var miss := Crafting.missing_inputs(rid)
	out["missing"] = miss
	for d in r.get("inputs", {}):
		if miss.has(d):
			var need := int(r["inputs"][d])
			obs.append({"kind": "input", "id": str(d), "need": need, "have": Game.count(str(d)),
				"text": "%d× %s missing (you have %d of %d)" % [int(miss[d]), iname(str(d)), Game.count(str(d)), need], "link": _help_link("item:" + str(d))})
	for o in obs:
		if str(o["kind"]) != "input":
			out["state"] = "locked"
			return out
	if not miss.is_empty():
		out["state"] = "missing"
	return out


static func _skill_obstacle(sk: String, lvl: int) -> Dictionary:
	return {"kind": "skill", "id": sk, "level": lvl, "link": {"route": "skills", "args": {}},
		"text": "%s %d needed (you: %d)" % [SkillSys.skill_name(sk), lvl, Game.player_level(sk)]}


# ======================================================================= dependency tree
## Recursive dependencies of a recipe ("recipe:<id>") or an item (a def, or "item:<def>"); cycle-safe, depth-limited.
static func tree(id: String, depth := 4, qty := 1) -> Dictionary:
	if id.begins_with("recipe:"):
		return _tree_recipe(id.substr(7), depth, maxi(1, qty), [])
	return _tree_item(id.trim_prefix("item:"), depth, maxi(1, qty), [])


static func _tree_item(def: String, depth: int, qty: int, path: Array) -> Dictionary:
	var makers := recipes_making(def)
	var node := {"type": "item", "id": def, "name": iname(def), "qty": qty, "have": Game.count(def), "state": status(def, qty),
		"intermediate": not makers.is_empty(), "children": [], "cycle": path.has("item:" + def)}
	if node["cycle"] or depth <= 0 or makers.is_empty():
		return node
	var r: Dictionary = makers[0]
	var crafts := int(ceil(float(maxi(0, qty - Game.count(def))) / float(maxi(1, int(r.get("qty", 1))))))
	(node["children"] as Array).append(_tree_recipe(str(r["id"]), depth - 1, maxi(1, crafts), path + ["item:" + def]))
	return node


static func _tree_recipe(rid: String, depth: int, times: int, path: Array) -> Dictionary:
	var r := DB.recipe(rid)
	var rs := recipe_status(rid)
	var node := {"type": "recipe", "id": rid, "name": str(r.get("name", rid)), "times": times, "state": str(rs["state"]),
		"children": [], "cycle": path.has("recipe:" + rid)}
	if node["cycle"] or depth <= 0 or r.is_empty():
		return node
	var p2: Array = path + ["recipe:" + rid]
	for d in r.get("inputs", {}):
		(node["children"] as Array).append(_tree_item(str(d), depth - 1, int(r["inputs"][d]) * times, p2))
	var seen := {}
	for s in r.get("steps", []):
		if seen.has(str(s)):
			continue
		seen[str(s)] = true
		var why := Crafting.station_locked_reason(str(s))
		(node["children"] as Array).append({"type": "station", "id": str(s), "name": sname(str(s)), "state": "ready" if why == "" else "locked",
			"why": why, "children": []})
	return node


## Tree flattened into indented lines for display: [{depth, node}].
static func tree_lines(t: Dictionary, d := 0, out: Array = []) -> Array:
	out.append({"depth": d, "node": t})
	for c in t.get("children", []):
		tree_lines(c, d + 1, out)
	return out


# ======================================================================= the next step
## ONE recommended next action for a recipe ("recipe:<id>" or a recipe id) or an item ("item:<def>" or a def).
static func next_step(id: String) -> Dictionary:
	if id.begins_with("recipe:") or (not id.begins_with("item:") and not DB.recipe(id).is_empty() and DB.item(id).is_empty()):
		return _recipe_step(id.trim_prefix("recipe:"), [])
	var def := id.trim_prefix("item:")
	return _item_step(def, 1, [], "")


static func station_step(sid: String, why: String) -> Dictionary:
	if why.begins_with("Bought, but not set up"):
		return {"text": "Set up %s in your workshop — Property & Workshop › Workshop layout" % the_station(sid), "action": {"route": "property", "args": {}},
			"why": "It is in storage; a station only works when placed in a room you own."}
	if why.begins_with("Not in your workshop"):
		return {"text": "Buy a %s (%d g) — Property & Workshop › Equipment" % [sname(sid), Property.station_price(sid)], "action": {"route": "property", "args": {}},
			"why": "The recipe needs it and your workshop has none."}
	var ni := SkillTree.station_node(sid)
	if ni != "" and not SkillTree.is_unlocked(ni):
		return {"text": "Learn «%s» in the Skill Tree to use %s" % [str(SkillTree.node(ni).get("name", ni)), the_station(sid)],
			"action": {"route": "skilltree", "args": {"select": ni}}, "why": why}
	return {"text": "%s: %s" % [sname(sid), why], "action": _help_link("station:" + sid), "why": why}


static func _recipe_step(rid: String, visiting: Array) -> Dictionary:
	var r := DB.recipe(rid)
	var rs := recipe_status(rid)
	if str(rs["state"]) == "hidden":
		return {"text": "", "action": {}, "why": "unknown"}
	for o in rs["obstacles"]:
		match str(o["kind"]):
			"node":
				return {"text": str(o["text"]), "action": o["link"], "why": "%s is taught by a skill-tree node you have not learned." % str(r.get("name", rid))}
			"skill":
				return {"text": "Raise %s to %d (you: %d) — craft simpler pieces or practise at a station" % [SkillSys.skill_name(str(o["id"])),
					int(o["level"]), Game.player_level(str(o["id"]))], "action": {}, "why": "%s needs more skill than you have yet." % str(r.get("name", rid))}
			"station":
				return station_step(str(o["id"]), str(o["why"]))
	var miss: Dictionary = rs["missing"]
	for d in r.get("inputs", {}):
		if miss.has(d):
			var st := _item_step(str(d), int(miss[d]), visiting + [rid], str(r.get("name", rid)))
			if str(st.get("text", "")) != "":
				return st
	var steps: Array = r.get("steps", [])
	var first := the_station(str(steps[0])) if not steps.is_empty() else "the workshop"
	return {"text": "Everything is ready — begin %s at %s" % [str(r.get("name", rid)), first], "action": {}, "why": ""}


## How to get n of an item (counting what is already in the stores).
static func how_to_get(def: String, n := 1) -> Dictionary:
	return _item_step(def, n, [], "")


static func _item_step(def: String, n: int, visiting: Array, for_what: String) -> Dictionary:
	var have := Game.count(def)
	if have >= n:
		return {"text": "You have enough %s (%d)." % [iname(def), have], "action": {}, "why": ""}
	var need := n - have
	var why := ("%s needs %d× %s; you have %d." % [for_what, n, iname(def), have]) if for_what != "" else "You have %d %s." % [have, iname(def)]
	for s in sources(def):
		var st := str(s["state"])
		if st == "locked" or st == "unavailable":
			continue
		if str(s["kind"]) == "craft" and st == "obtainable":
			if visiting.has(str(s["id"])) or visiting.size() > 5:
				continue
			var sub := _recipe_step(str(s["id"]), visiting)
			if str(sub.get("text", "")) != "":
				sub["why"] = why + " Make it: " + str(s["name"]) + "."
				return sub
			continue
		return {"text": _phrase(s, need, def), "action": s.get("link", {}), "why": why, "source": s}
	# nothing obtainable — explain the first public obstacle
	for s in sources(def):
		if str(s["state"]) == "locked":
			if str(s["kind"]) == "craft":
				var sub2 := _recipe_step(str(s["id"]), visiting + [def])
				if str(sub2.get("text", "")) != "":
					sub2["why"] = why
					return sub2
			return {"text": "%s — %s" % [str(s["how"]), str(s["why"])], "action": s.get("link", {}), "why": why, "source": s}
	return {"text": "No known way to get %s yet — explore, trade and listen for rumours." % iname(def), "action": {}, "why": why}


## One imperative line for a source and a quantity.
static func _phrase(s: Dictionary, need: int, def: String) -> String:
	match str(s["kind"]):
		"vendor":
			return "Buy %d %s at %s (%s, %d g each)" % [need, iname(def), str(s["name"]), str(s["when"]), int(s["price"])]
		"ship", "caravan":
			if str(s["state"]) == "ready":
				return "Buy %d %s from %s (%s, %d g each)" % [need, iname(def), str(s["name"]), str(s["when"]), int(s["price"])]
		"craft":
			return "%s — %s" % [str(s["how"]), "you have everything for it" if str(s["state"]) == "ready" else str(s["why"])]
	return str(s["how"]) + ((" — " + str(s["when"])) if str(s["when"]) != "" else "")


## The other ways (every source except the one next_step chose), for "full details".
static func alternatives(id: String) -> Array:
	var ns := next_step(id)
	var def := id.trim_prefix("item:")
	if id.begins_with("recipe:") or (not DB.recipe(id).is_empty() and DB.item(id).is_empty()):
		var rs := recipe_status(id.trim_prefix("recipe:"))
		def = ""
		for d in rs["missing"]:
			def = str(d)
			break
	if def == "":
		return []
	var chosen: Dictionary = ns.get("source", {})
	return sources(def).filter(func(s): return chosen.is_empty() or not (str(s["kind"]) == str(chosen.get("kind", "")) and str(s["id"]) == str(chosen.get("id", ""))))


## The best current source as a single source dictionary ({} when none).
static func best_source(def: String) -> Dictionary:
	for s in sources(def):
		if str(s["state"]) in ["ready", "obtainable"]:
			return s
	return {}


## One line for an item tooltip: the best current source ("" when none is known).
static func tooltip_line(def: String) -> String:
	if Game.state.is_empty() or not Reference.item_visible(def):
		return ""
	var s := best_source(def)
	if s.is_empty():
		return ""
	match str(s["kind"]):
		"vendor", "ship", "caravan", "rival", "import":
			var tail := ""
			if str(s["state"]) == "ready":
				tail = " · open now" if str(s["kind"]) == "vendor" else " · in port now" if str(s["kind"]) == "ship" else ""
			else:
				tail = {"ship": " · when in port", "caravan": " · when it visits", "rival": " · when in stock", "import": " · to order"}.get(str(s["kind"]), "")
			return "%s · %d g%s" % [str(s["name"]), int(s["price"]), tail]
		"craft":
			var r := DB.recipe(str(s["id"]))
			var steps: Array = r.get("steps", [])
			return "%s at %s" % [str(s["name"]), the_station(str(steps[0])) if not steps.is_empty() else "the workshop"]
	return str(s["how"])
