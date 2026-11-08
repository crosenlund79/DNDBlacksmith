## Trade — the herbalist's shop, merchant ships at Brindlewick harbour and special import orders.
## EN: The herbalist (Maud Fennimore) restocks common alchemy ingredients every morning. Merchant ships
##     (a southern spice trader, a dwarven ore barge, a far-north whaler) call every few days and stay
##     two; each brings a changing hold of rare materials and some finished equipment. At the harbour
##     the smith can also order a known material from abroad: a deposit now, the balance when the goods
##     arrive after a lead time that grows with rarity. Data: data/trade.json (tools/data/make_trade.py).
## DA: Urtekonen fylder op hver morgen; handelsskibe anløber havnen med få dages mellemrum; særlige
##     importordrer betales med depositum og restbeløb ved levering.
##
## Public API (static):
##   herbalist_stock() -> Array[{def, qty, price}]          buy_herbalist(def, qty) -> String ("" = ok)
##   herbalist_line() -> String
##   current_ship() -> Dictionary ({} when none docked)       next_arrival() -> Dictionary {type, name, captain, at, days}
##   buy_from_ship(index, qty) -> String                      ship_type(type) -> Dictionary
##   importables() -> Array[{def, tier, price, deposit, lead}] place_import(def, qty) -> String
##   imports() -> Array (open orders: status "ordered" | "arrived")   collect_delivery(id) -> String
##   deliveries() -> Array (status "arrived")                 knows(def) -> bool    mark_seen(def)
##   on_day(), on_hour(h)                                      dev_force_ship(type), dev_finish_imports()
## State: Game.state["trade"] = {herb: {day, stock}, ship: {}, next: {}, orders: [], history: [], seen: {}, seq}
class_name Trade
extends RefCounted

const IRONFRONT_PATH := "res://scripts/systems/ironfront.gd"


static func cfg() -> Dictionary:
	var d: Variant = DB.extra("trade")
	return d if d is Dictionary else {}


static func st() -> Dictionary:
	if not Game.state.has("trade"):
		Game.state["trade"] = {"herb": {"day": 0, "stock": []}, "ship": {}, "next": {}, "orders": [], "history": [], "seen": {}, "seq": 0}
	var t: Dictionary = Game.state["trade"]
	for k in ["ship", "next", "seen"]:
		if not t.has(k):
			t[k] = {}
	for k in ["orders", "history"]:
		if not t.has(k):
			t[k] = []
	if t["next"].is_empty() and t["ship"].is_empty():
		_schedule_next(int(cfg().get("schedule", {}).get("first_after_days", 2)))
	return t


## Buying price factor: on Apprentice (prices 1.15) goods are cheaper, on Master (0.9) dearer.
static func price_factor() -> float:
	return 1.0 / maxf(0.5, float(Expeditions.diff().get("prices", 1.0)))


static func _new_id(prefix: String) -> String:
	var t: Dictionary = Game.state["trade"]
	t["seq"] = int(t.get("seq", 0)) + 1
	return "%s_%d" % [prefix, int(t["seq"])]


# ------------------------------------------------------------------ knowledge
static func mark_seen(def_id: String) -> void:
	if def_id != "" and not DB.item(def_id).is_empty():
		st()["seen"][def_id] = true


## Does the smith know this material exists (held, seen, rumoured, or used by a recipe they know)?
## Exotic and legendary goods must have been seen or held — no recipe hints, no secret content.
static func knows(def_id: String) -> bool:
	var t := st()
	if t["seen"].has(def_id) or Game.count(def_id) > 0 or Game.has_flag("heard_" + def_id):
		return true
	var tier: String = str(cfg().get("imports", {}).get(def_id, {}).get("tier", "common"))
	if tier in ["exotic", "legendary"]:
		return false
	if def_id == "ore_mithril" and Game.has_flag("found_mithril"):
		return true
	for r in DB.recipes.values():
		if (r.get("inputs", {}) as Dictionary).has(def_id) and SkillTree.recipe_reason(str(r["id"])) == "":
			return true
	return false


static func _scan_inventory() -> void:
	var seen: Dictionary = st()["seen"]
	for it in Game.inventory():
		seen[str(it["def"])] = true


# ------------------------------------------------------------------ herbalist
static func herbalist_stock() -> Array:
	var h: Dictionary = st()["herb"]
	if int(h.get("day", 0)) != Game.day() or not h.has("stock"):
		_restock_herbalist()
	for e in h["stock"]:
		mark_seen(str(e["def"]))
	return h["stock"]


static func _restock_herbalist() -> void:
	var h: Dictionary = st()["herb"]
	var out := []
	for e in cfg().get("herbalist", {}).get("stock", []):
		var q := randi_range(int(e[2][0]), int(e[2][1]))
		out.append({"def": str(e[0]), "qty": q, "price": maxi(1, int(round(float(e[1]) * price_factor())))})
	h["day"] = Game.day()
	h["stock"] = out


static func herbalist_line() -> String:
	var lines: Array = cfg().get("herbalist", {}).get("lines", [])
	return str(lines[Game.day() % lines.size()]) if not lines.is_empty() else ""


static func buy_herbalist(def_id: String, qty := 1) -> String:
	for e in herbalist_stock():
		if e["def"] != def_id:
			continue
		qty = mini(qty, int(e["qty"]))
		if qty <= 0:
			return "Sold out until tomorrow."
		var cost := int(e["price"]) * qty
		if not Game.can_afford(cost):
			return "You cannot afford it (%d g)." % cost
		Game.add_gold(-cost, "materials", "Herbalist: %d × %s" % [qty, DB.item(def_id).get("name", def_id)])
		Game.add_item(Items.make(def_id, {"qty": qty, "quality": randf_range(68, 90)}), false)
		e["qty"] = int(e["qty"]) - qty
		mark_seen(def_id)
		return ""
	return "The herbalist does not sell that."


# ------------------------------------------------------------------ ships
static func ship_type(type: String) -> Dictionary:
	return cfg().get("ships", {}).get(type, {})


static func current_ship() -> Dictionary:
	return st()["ship"]


## The next expected ship: {type, name, captain, at (game minute), days (whole days away, 0 = today)}.
static func next_arrival() -> Dictionary:
	var n: Dictionary = st()["next"]
	if n.is_empty():
		return {}
	var out := n.duplicate()
	out["days"] = maxi(0, int(ceil(float(int(n["at"]) - Game.now()) / 1440.0)))
	return out


static func _schedule_next(after_days: int) -> void:
	var t: Dictionary = Game.state["trade"]
	var sc: Dictionary = cfg().get("schedule", {})
	var types: Array = cfg().get("ships", {}).keys()
	if types.is_empty():
		return
	var last: String = str(t.get("last_type", ""))
	var pool := types.filter(func(x): return x != last)
	var type: String = str(pool[randi() % pool.size()]) if not pool.is_empty() else str(types[0])
	var names: Array = ship_type(type).get("names", [["A merchant ship", "her captain"]])
	var nm: Array = names[randi() % names.size()]
	var arrive_day := Game.day() + maxi(1, after_days)
	t["next"] = {"type": type, "name": str(nm[0]), "captain": str(nm[1]), "at": (arrive_day - 1) * 1440 + int(sc.get("arrive_hour", 7)) * 60}


static func _dock(type: String, ship_name := "", captain := "") -> void:
	var t := st()
	var sd := ship_type(type)
	if sd.is_empty():
		return
	if ship_name == "":
		var nm: Array = (sd.get("names", [["A merchant ship", "her captain"]]) as Array).pick_random()
		ship_name = str(nm[0])
		captain = str(nm[1])
	var stay := int(cfg().get("schedule", {}).get("stay", 2))
	var stock := []
	var pf := price_factor()
	for e in sd.get("stock", []):
		if randf() > float(e[3]):
			continue
		var d := DB.item(str(e[0]))
		if d.is_empty():
			continue
		stock.append({"def": str(e[0]), "qty": randi_range(int(e[2][0]), int(e[2][1])),
			"price": maxi(1, int(round(float(d.get("value", 5)) * float(e[1]) * pf)))})
		mark_seen(str(e[0]))
	for e in sd.get("equipment", []):
		if randf() > float(e[2]):
			continue
		var it := Items.make(str(e[0]), {"quality": randf_range(62, 92), "rarity": "magic" if randf() < 0.25 else "common"})
		if it.is_empty():
			continue
		Items.add_history(it, "Brought to Brindlewick aboard %s." % ship_name)
		stock.append({"def": str(e[0]), "qty": 1, "item": it, "price": maxi(1, int(round(Items.value(it) * float(e[1]) * pf)))})
	# special Ironfront cards (only when the Ironfront system exists)
	if randf() < float(sd.get("ironfront_chance", 0.0)):
		var card: Variant = _ironfront_call("random_card", ["rare"])
		if card is String and str(card) != "":
			stock.append({"card": str(card), "qty": 1, "price": int(round(120 * pf)), "def": ""})
	t["ship"] = {"type": type, "name": ship_name, "captain": captain, "arrived": Game.now(), "leaves": Game.now() + stay * 1440, "stock": stock}
	t["last_type"] = type
	t["next"] = {}
	Chronicle.add("trade", "%s (%s) docked at Brindlewick harbour — %s." % [ship_name, captain, str(sd.get("desc", "")).to_lower().trim_suffix(".")], {"ship": type})
	Events.toast.emit("%s has docked at the harbour — %s." % [ship_name, sd.get("label", "a merchant ship")], "good")


static func _depart() -> void:
	var t := st()
	var s: Dictionary = t["ship"]
	if s.is_empty():
		return
	Chronicle.add("trade", "%s cast off and left Brindlewick harbour." % s["name"], {"ship": s["type"]})
	t["ship"] = {}
	var g: Array = cfg().get("schedule", {}).get("gap", [3, 6])
	_schedule_next(randi_range(int(g[0]), int(g[1])))


static func buy_from_ship(index: int, qty := 1) -> String:
	var s := current_ship()
	if s.is_empty():
		return "No ship is in the harbour."
	var stock: Array = s["stock"]
	if index < 0 or index >= stock.size():
		return "That is no longer aboard."
	var e: Dictionary = stock[index]
	qty = mini(qty, int(e["qty"]))
	if qty <= 0:
		return "Sold out."
	var cost := int(e["price"]) * qty
	if not Game.can_afford(cost):
		return "You cannot afford it (%d g)." % cost
	if e.has("card"):
		var ok: Variant = _ironfront_call("grant_card", [str(e["card"]), "harbour"])
		if ok == null:
			return "The card cannot be traded right now."
		Game.add_gold(-cost, "imports", "Ironfront card from %s" % s["name"])
		e["qty"] = 0
		return ""
	var what: String = DB.item(str(e["def"])).get("name", e["def"])
	Game.add_gold(-cost, "imports", "%s: %d × %s" % [s["name"], qty, what])
	if e.has("item"):
		var it: Dictionary = (e["item"] as Dictionary).duplicate(true)
		it["uid"] = Game.new_uid()
		Game.add_item(it, false)
		e.erase("item")
	else:
		Game.add_item(Items.make(str(e["def"]), {"qty": qty, "quality": randf_range(70, 92)}), false)
	e["qty"] = int(e["qty"]) - qty
	mark_seen(str(e["def"]))
	if DB.item(str(e["def"])).get("tags", []).has("dragon"):
		Chronicle.add("trade", "The smith bought %s from %s for %d gold." % [what.to_lower(), s["name"], cost], {"item": e["def"]}, true)
	return ""


## Calls Ironfront (another worker's system) only when it exists; returns null otherwise.
static func _ironfront_call(fn: String, args: Array) -> Variant:
	if not ResourceLoader.exists(IRONFRONT_PATH):
		return null
	var s: Variant = load(IRONFRONT_PATH)
	if not (s is Script):
		return null
	for m in (s as Script).get_script_method_list():
		if str(m.get("name", "")) == fn:
			return (s as Script).callv(fn, args)
	return null


# ------------------------------------------------------------------ special imports
static func import_info(def_id: String) -> Dictionary:
	var c: Dictionary = cfg().get("imports", {}).get(def_id, {})
	if c.is_empty():
		return {}
	var unit := maxi(1, int(round(float(DB.item(def_id).get("value", 5)) * float(c.get("mult", 1.8)) * price_factor())))
	var lead: Array = c.get("lead", [3, 5])
	return {"def": def_id, "tier": str(c.get("tier", "common")), "unit": unit, "lead": [int(lead[0]), int(lead[1])],
		"deposit_share": float(cfg().get("harbour", {}).get("deposit", 0.4))}


## Importable goods the smith knows of, cheapest first.
static func importables() -> Array:
	var out := []
	for d in cfg().get("imports", {}):
		if knows(str(d)) and not DB.item(str(d)).is_empty():
			out.append(import_info(str(d)))
	out.sort_custom(func(a, b): return int(a["unit"]) < int(b["unit"]))
	return out


static func imports() -> Array:
	return st()["orders"]


static func deliveries() -> Array:
	return imports().filter(func(o): return o["status"] == "arrived")


static func place_import(def_id: String, qty := 1) -> String:
	if not knows(def_id):
		return "The harbourmaster has never heard of such a thing."
	var info := import_info(def_id)
	if info.is_empty():
		return "That cannot be shipped to Brindlewick."
	qty = clampi(qty, 1, 20)
	var open := imports().size()
	if open >= int(cfg().get("harbour", {}).get("max_open", 4)):
		return "The order book is full — collect or wait for earlier orders first."
	var total := int(info["unit"]) * qty
	var deposit := int(ceil(total * float(info["deposit_share"])))
	if not Game.can_afford(deposit):
		return "The deposit is %d g — you cannot afford it." % deposit
	var lead := randi_range(int(info["lead"][0]), int(info["lead"][1]))
	var nm: String = DB.item(def_id).get("name", def_id)
	var o := {"id": _new_id("imp"), "def": def_id, "qty": qty, "total": total, "deposit": deposit, "balance": total - deposit,
		"placed": Game.day(), "due": Game.day() + lead, "status": "ordered", "tier": info["tier"]}
	imports().append(o)
	Game.add_gold(-deposit, "imports", "Import deposit: %d × %s" % [qty, nm])
	Chronicle.add("trade", "The smith ordered %d × %s from abroad (%d g, due in about %d days)." % [qty, nm, total, lead], {"item": def_id})
	return ""


static func collect_delivery(oid: String) -> String:
	for o in imports():
		if o["id"] != oid:
			continue
		if o["status"] != "arrived":
			return "Not arrived yet — expected on day %d." % int(o["due"])
		var bal := int(o["balance"])
		if not Game.can_afford(bal):
			return "The balance is %d g — you cannot afford it yet." % bal
		var nm: String = DB.item(str(o["def"])).get("name", o["def"])
		if bal > 0:
			Game.add_gold(-bal, "imports", "Import balance: %d × %s" % [int(o["qty"]), nm])
		var it := Items.make(str(o["def"]), {"qty": int(o["qty"]), "quality": randf_range(72, 94)})
		Game.add_item(it, false)
		mark_seen(str(o["def"]))
		o["status"] = "collected"
		o["collected"] = Game.day()
		imports().erase(o)
		var h: Array = st()["history"]
		h.append(o)
		while h.size() > 20:
			h.pop_front()
		Chronicle.add("trade", "Collected an import at the harbour: %d × %s." % [int(o["qty"]), nm], {"item": o["def"]}, str(o.get("tier", "")) in ["exotic", "legendary"])
		Events.toast.emit("Collected %d × %s from the harbour." % [int(o["qty"]), nm], "good")
		return ""
	return "No such order."


static func _arrive_imports() -> void:
	for o in imports():
		if o["status"] == "ordered" and Game.day() >= int(o["due"]):
			_mark_arrived(o)


static func _mark_arrived(o: Dictionary) -> void:
	o["status"] = "arrived"
	var nm: String = DB.item(str(o["def"])).get("name", o["def"])
	Chronicle.add("trade", "An import has arrived at the harbour: %d × %s (%d g balance due)." % [int(o["qty"]), nm, int(o["balance"])], {"item": o["def"]})
	Events.toast.emit("Your import of %s has arrived — collect it at the harbour." % nm, "good")


# ------------------------------------------------------------------ clock (called from Sim)
static func on_day() -> void:
	st()
	_restock_herbalist()
	_arrive_imports()


static func on_hour(_h: int) -> void:
	var t := st()
	if not t["ship"].is_empty() and Game.now() >= int(t["ship"]["leaves"]):
		_depart()
	if t["ship"].is_empty() and not t["next"].is_empty() and Game.now() >= int(t["next"]["at"]):
		var n: Dictionary = t["next"]
		_dock(str(n["type"]), str(n["name"]), str(n["captain"]))
	_scan_inventory()


# ------------------------------------------------------------------ dev helpers
static func dev_force_ship(type := "") -> void:
	var t := st()
	if type == "" or ship_type(type).is_empty():
		type = str(cfg().get("ships", {}).keys().pick_random())
	t["ship"] = {}
	_dock(type)


static func dev_finish_imports() -> void:
	for o in imports():
		if o["status"] == "ordered":
			o["due"] = Game.day()
			_mark_arrived(o)


## The type of the ship moored at the quay ("" when none) — the village draws props/ship_<type>.
static func docked_ship() -> String:
	return str(current_ship().get("type", ""))
