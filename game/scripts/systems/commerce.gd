## Commerce — the travelling caravan, Quell's pawnshop, the rival smith at the Salt Anvil and the Hales' creature yard.
## EN: The Brask caravan rolls into the caravan camp every 6–10 days and stays two: curiosities, exotic materials,
##     fine equipment, sometimes an Ironfront special, and a "goods wanted" list it pays a premium for.
##     Silas Quell pays 40 % of value for a pledge and holds it ten days; redeeming costs 65 %; after that it goes
##     on his shelf. Maren Tallowgate sells sea-bronze and ripple-steel work the smith cannot make yet (and
##     adventurers sometimes buy from her). Bram and Ellery Hale sell ordinary and magical companion creatures to
##     the smith, or to an adventurer through the smith (gift, resale or a straight introduction).
##     Data: data/commerce.json (tools/data/make_commerce.py); items/characters: tools/data/extra_commerce.py.
## DA: Karavanen, pantelåneren, den rivaliserende smed og Hale-familiens dyr.
##
## Public API (static):
##   cfg() -> Dictionary                    st() -> Dictionary (Game.state["commerce"])
##   -- caravan --
##   caravan_present() -> bool              caravan() -> Dictionary ({} when away: {master, arrived, leaves, stock, wanted})
##   next_caravan() -> Dictionary {at, days}  buy_caravan(index, qty := 1) -> String     wanted_offer(uid) -> int
##   sell_wanted(uid, qty := 1) -> String   dev_force_caravan()  dev_caravan_leave()
##   -- pawnshop --
##   pawnable(it) -> String ("" = can pawn)   pawn_payout(it, qty) -> int   pawn_buyback(it) -> int
##   pawn_item(uid, qty := 0) -> String      pledges() -> Array            redeem(pledge_id) -> String
##   house_stock() -> Array                  buy_house(index) -> String    pawn_log() -> Array
##   -- rival smith --
##   rival_stock() -> Array                  buy_rival(index) -> String
##   rival_offer_for(a) -> Dictionary {index, item, price} (no change)    rival_buy_for(a) -> Dictionary (buys, equips)
##   rivalry_band() -> "low"|"mid"|"high"    hall_of_fame_count() -> int
##   -- creatures --
##   creature_stock() -> Array               creature_price(def) -> int    buy_creature(index) -> String
##   arrange_creature(index, adv_id, mode, markup := 1.15) -> String  (mode "gift" | "sell" | "arrange")
##   commission_creature(def, for_adv := "") -> String   commissions() -> Array
##   creature_offer_for(a) -> Dictionary {index, def, price} (no change)   creature_buy_for(a, offer := {}) -> Dictionary
##   -- world & talk --
##   spot_for(id, hour) -> String ("-" = not a commerce character)   greeting(npc) -> String
##   talk_options(npc) -> Array   talk_choose(npc, opt) -> Dictionary ({} = not handled)
##   on_day(), on_hour(h)
## State: Game.state["commerce"] = {seq, caravan: {}, caravan_next: {at}, pawn: {pledges, house, log},
##   rival: {day, stock, tip, tip_day, sales}, creatures: {day, stock, orders}}
class_name Commerce
extends RefCounted

const IRONFRONT_PATH := "res://scripts/systems/ironfront.gd"
const NPCS := ["rival_smith", "pawnbroker", "caravan_master", "hale_elder", "hale_younger"]


static func cfg() -> Dictionary:
	var d: Variant = DB.extra("commerce")
	return d if d is Dictionary else {}


static func st() -> Dictionary:
	if not Game.state.has("commerce"):
		Game.state["commerce"] = {"seq": 0}
	var c: Dictionary = Game.state["commerce"]
	for k in ["caravan", "caravan_next", "pawn", "rival", "creatures"]:
		if not c.has(k) or not (c[k] is Dictionary):
			c[k] = {}
	var p: Dictionary = c["pawn"]
	for k in ["pledges", "log"]:
		if not p.has(k):
			p[k] = []
	if not p.has("house"):
		p["house"] = {}
	if not (c["creatures"] as Dictionary).has("orders"):
		c["creatures"]["orders"] = []
	if not (c["rival"] as Dictionary).has("sales"):
		c["rival"]["sales"] = []
	if c["caravan"].is_empty() and c["caravan_next"].is_empty():
		_schedule_caravan(int(cfg().get("caravan", {}).get("schedule", {}).get("first_after_days", 5)))
	return c


static func _new_id(prefix: String) -> String:
	var c: Dictionary = Game.state["commerce"]
	c["seq"] = int(c.get("seq", 0)) + 1
	return "%s_%d" % [prefix, int(c["seq"])]


static func price_factor() -> float:
	return 1.0 / maxf(0.5, float(Expeditions.diff().get("prices", 1.0)))


static func _iname(def_id: String) -> String:
	return str(DB.item(def_id).get("name", def_id))


## Value of a single unit of an item instance.
static func unit_value(it: Dictionary) -> int:
	var one := it.duplicate()
	one["qty"] = 1
	return maxi(1, Items.value(one))


## Takes `qty` units of an inventory item by uid (splits stacks). Returns the taken instance or {}.
static func _take(uid: int, qty: int) -> Dictionary:
	var it := Game.find_uid(uid)
	if it.is_empty():
		return {}
	var have := int(it.get("qty", 1))
	if qty <= 0 or qty >= have:
		return Game.take_uid(uid)
	it["qty"] = have - qty
	var part: Dictionary = it.duplicate(true)
	part["qty"] = qty
	part["uid"] = Game.new_uid()
	Events.inventory_changed.emit()
	return part


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


# ====================================================================== caravan
static func caravan_present() -> bool:
	return not caravan().is_empty()


static func caravan() -> Dictionary:
	return st()["caravan"]


static func next_caravan() -> Dictionary:
	var n: Dictionary = st()["caravan_next"]
	if n.is_empty():
		return {}
	var out := n.duplicate()
	out["days"] = maxi(0, int(ceil(float(int(n["at"]) - Game.now()) / 1440.0)))
	return out


static func _schedule_caravan(after_days: int) -> void:
	var c: Dictionary = Game.state["commerce"]
	var sc: Dictionary = cfg().get("caravan", {}).get("schedule", {})
	var arrive_day := Game.day() + maxi(1, after_days)
	c["caravan_next"] = {"at": (arrive_day - 1) * 1440 + int(sc.get("arrive_hour", 9)) * 60}


static func _caravan_arrive() -> void:
	var c := st()
	var cc: Dictionary = cfg().get("caravan", {})
	var pf := price_factor()
	var stock := []
	for e in cc.get("stock", []):
		if randf() > float(e[3]) or DB.item(str(e[0])).is_empty():
			continue
		stock.append({"def": str(e[0]), "qty": randi_range(int(e[2][0]), int(e[2][1])),
			"price": maxi(1, int(round(float(DB.item(str(e[0])).get("value", 5)) * float(e[1]) * pf)))})
	for key in ["equipment", "curiosities"]:
		for e in cc.get(key, []):
			if randf() > float(e[2]) or DB.item(str(e[0])).is_empty():
				continue
			var eq := Items.is_equipment({"def": str(e[0])})
			var it := Items.make(str(e[0]), {"quality": randf_range(68, 94), "rarity": ("magic" if randf() < 0.3 else "common") if eq else "common"})
			if it.is_empty():
				continue
			Items.add_history(it, "Came to Brindlewick with the Brask caravan.")
			stock.append({"def": str(e[0]), "qty": 1, "item": it, "kind": key,
				"price": maxi(1, int(round(Items.value(it) * float(e[1]) * pf)))})
	if randf() < float(cc.get("ironfront_chance", 0.0)):
		var card: Variant = _ironfront_call("random_card", ["special" if randf() < 0.35 else "rare"])
		if card is String and str(card) != "":
			stock.append({"card": str(card), "def": "", "qty": 1, "price": int(round(float(cc.get("ironfront_price", 140)) * pf))})
	# goods wanted: a few things the caravan pays a premium for
	var pool: Array = (cc.get("wanted", []) as Array).duplicate()
	pool.shuffle()
	var wanted := []
	for e in pool.slice(0, int(cc.get("wanted_count", 3))):
		if DB.item(str(e[0])).is_empty():
			continue
		wanted.append({"def": str(e[0]), "mult": float(e[1]), "max": int(cc.get("wanted_max", 4)), "taken": 0})
	var stay := int(cc.get("schedule", {}).get("stay", 2))
	c["caravan"] = {"master": "caravan_master", "arrived": Game.now(), "leaves": Game.now() + stay * 1440, "stock": stock, "wanted": wanted}
	c["caravan_next"] = {}
	var who := Talk.npc_name("caravan_master")
	Chronicle.add("trade", "The Brask caravan rolled into the caravan camp — %s and three painted wagons of curios, exotic goods and fine arms." % who, {"npc": "caravan_master"})
	Events.toast.emit("The travelling caravan has arrived at the caravan camp!", "good")
	TalkMarkers.flag("caravan_master", "The caravan is in town — curios, exotic goods, and wants to buy")


static func _caravan_depart() -> void:
	var c := st()
	if c["caravan"].is_empty():
		return
	c["caravan"] = {}
	Chronicle.add("trade", "The Brask caravan packed up its wagons and took the east road out of Brindlewick.", {"npc": "caravan_master"})
	Events.toast.emit("The caravan has left Brindlewick.", "info")
	TalkMarkers.clear("caravan_master")
	var g: Array = cfg().get("caravan", {}).get("schedule", {}).get("gap", [6, 10])
	_schedule_caravan(randi_range(int(g[0]), int(g[1])))


static func buy_caravan(index: int, qty := 1) -> String:
	var cv := caravan()
	if cv.is_empty():
		return "The caravan is not in town."
	var stock: Array = cv["stock"]
	if index < 0 or index >= stock.size():
		return "That has already been sold."
	var e: Dictionary = stock[index]
	qty = mini(qty, int(e["qty"]))
	if qty <= 0:
		return "Sold out."
	var cost := int(e["price"]) * qty
	if not Game.can_afford(cost):
		return "You cannot afford it (%d g)." % cost
	if e.has("card"):
		var ok: Variant = _ironfront_call("grant_card", [str(e["card"]), "caravan"])
		if ok == null or not bool(ok):
			return "The card cannot be traded right now."
		Game.add_gold(-cost, "caravan", "Ironfront card from the caravan")
		e["qty"] = 0
		return ""
	var what := _iname(str(e["def"]))
	Game.add_gold(-cost, "caravan", "Caravan: %d × %s" % [qty, what])
	if e.has("item"):
		var it: Dictionary = (e["item"] as Dictionary).duplicate(true)
		it["uid"] = Game.new_uid()
		Game.add_item(it, false)
		e.erase("item")
	else:
		Game.add_item(Items.make(str(e["def"]), {"qty": qty, "quality": randf_range(70, 92)}), false)
	e["qty"] = int(e["qty"]) - qty
	Trade.mark_seen(str(e["def"]))
	if cost >= 400:
		Chronicle.add("trade", "The smith bought %s from the travelling caravan for %d gold." % [what.to_lower(), cost], {"item": e["def"]})
	return ""


static func _wanted_entry(def_id: String) -> Dictionary:
	for w in caravan().get("wanted", []):
		if str(w["def"]) == def_id:
			return w
	return {}


## What the caravan pays per unit for this inventory item (0 = not wanted / no more wanted).
static func wanted_offer(uid: int) -> int:
	var it := Game.find_uid(uid)
	if it.is_empty() or not caravan_present():
		return 0
	var w := _wanted_entry(str(it["def"]))
	if w.is_empty() or int(w["taken"]) >= int(w["max"]):
		return 0
	return maxi(1, int(round(unit_value(it) * float(w["mult"]))))


static func sell_wanted(uid: int, qty := 1) -> String:
	var it := Game.find_uid(uid)
	if it.is_empty():
		return "You no longer have that."
	var unit := wanted_offer(uid)
	if unit <= 0:
		return "The caravan is not buying that."
	var w := _wanted_entry(str(it["def"]))
	qty = clampi(qty, 1, mini(int(it.get("qty", 1)), int(w["max"]) - int(w["taken"])))
	var nm := str(it.get("name", _iname(str(it["def"]))))
	_take(uid, qty)
	w["taken"] = int(w["taken"]) + qty
	Game.add_gold(unit * qty, "caravan", "Sold to the caravan: %d × %s" % [qty, nm])
	return ""


static func dev_force_caravan() -> void:
	st()["caravan"] = {}
	_caravan_arrive()


static func dev_caravan_leave() -> void:
	_caravan_depart()


# ====================================================================== pawnshop
static func pawn_cfg() -> Dictionary:
	return cfg().get("pawn", {})


## "" when the item can be pledged, otherwise the reason.
static func pawnable(it: Dictionary) -> String:
	if it.is_empty():
		return "Nothing to pledge."
	var d := Items.def(it)
	var never: Array = pawn_cfg().get("never", ["container", "quest"])
	if str(d.get("type", "")) in never:
		return "Quell will not take that."
	for t in d.get("tags", []):
		if str(t) in never or str(t) in ["recipe", "key"]:
			return "That is not his to hold."
	if it.get("quest", false) or it.get("hall_of_fame", false) or it.get("epic", false):
		return "Some things are not for pawning."
	if unit_value(it) <= 1:
		return "Not worth a ticket."
	return ""


static func pawn_payout(it: Dictionary, qty := 1) -> int:
	return maxi(1, int(round(unit_value(it) * float(pawn_cfg().get("payout", 0.4))))) * maxi(1, qty)


static func pawn_buyback(it: Dictionary) -> int:
	return maxi(2, int(round(Items.value(it) * float(pawn_cfg().get("buyback", 0.65)))))


static func _shelf_price(it: Dictionary) -> int:
	return maxi(2, int(round(Items.value(it) * float(pawn_cfg().get("sale", 0.85)))))


static func pledges() -> Array:
	return st()["pawn"]["pledges"]


static func pawn_log() -> Array:
	return st()["pawn"]["log"]


static func _log(text: String, amount: int) -> void:
	var l := pawn_log()
	l.append({"day": Game.day(), "text": text, "amount": amount})
	while l.size() > 40:
		l.pop_front()


## Pledge an inventory item (qty units of a stack, 0 = all). The smith gets the payout at once.
static func pawn_item(uid: int, qty := 0) -> String:
	var it := Game.find_uid(uid)
	var why := pawnable(it)
	if why != "":
		return why
	if pledges().filter(func(p): return p["status"] == "held").size() >= int(pawn_cfg().get("max_pledges", 30)):
		return "Quell's strongroom is full of your pledges already."
	var n := int(it.get("qty", 1)) if qty <= 0 else mini(qty, int(it.get("qty", 1)))
	var pay := pawn_payout(it, n)
	var taken := _take(uid, n)
	if taken.is_empty():
		return "You no longer have that."
	taken.erase("for_sale")
	var hold := int(pawn_cfg().get("hold_days", 10))
	var p := {"id": _new_id("pl"), "item": taken, "payout": pay, "buyback": pawn_buyback(taken), "day": Game.day(),
		"due": Game.day() + hold, "status": "held"}
	pledges().append(p)
	var nm := Items.display_name(taken)
	Game.add_gold(pay, "pawn", "Pawned %s" % nm)
	_log("Pawned %s for %d g (ticket %s, redeem by day %d)." % [nm, pay, p["id"], int(p["due"])], pay)
	if str(taken.get("rarity", "common")) in ["rare", "legendary", "unique", "set"]:
		Chronicle.add("trade", "The smith pawned %s at Quell's for %d gold." % [nm, pay], {"item": taken["def"]})
	return ""


## Redeem a held pledge at the buy-back price, or buy a forfeited one off the shelf at the sale price.
static func redeem(pledge_id: String) -> String:
	for p in pledges():
		if p["id"] != pledge_id:
			continue
		var it: Dictionary = p["item"]
		var cost := int(p["buyback"]) if p["status"] == "held" else _shelf_price(it)
		if not Game.can_afford(cost):
			return "That costs %d g — you cannot afford it." % cost
		var nm := Items.display_name(it)
		Game.add_gold(-cost, "pawn", ("Redeemed %s" if p["status"] == "held" else "Bought back %s off the shelf") % nm)
		var back: Dictionary = it.duplicate(true)
		Game.add_item(back, false)
		pledges().erase(p)
		_log("%s %s for %d g." % ["Redeemed" if p["status"] == "held" else "Bought back", nm, cost], -cost)
		return ""
	return "No such ticket."


## Price of a pledge right now (buy-back while held, shelf price once forfeited).
static func pledge_price(p: Dictionary) -> int:
	return int(p["buyback"]) if p["status"] == "held" else _shelf_price(p["item"])


static func house_stock() -> Array:
	var h: Dictionary = st()["pawn"]["house"]
	if int(h.get("week", -1)) != int((Game.day() - 1) / 7) or not h.has("stock"):
		var out := []
		for e in pawn_cfg().get("house_stock", []):
			if randf() > float(e[2]) or DB.item(str(e[0])).is_empty():
				continue
			var it := Items.make(str(e[0]), {"quality": randf_range(55, 85), "qty": 1})
			Items.add_history(it, "Sat on Silas Quell's shelf, unredeemed.")
			out.append({"def": str(e[0]), "item": it, "price": maxi(2, int(round(Items.value(it) * float(e[1]) * float(pawn_cfg().get("sale", 0.85)) * price_factor())))})
		h["week"] = int((Game.day() - 1) / 7)
		h["stock"] = out
	return h["stock"]


static func buy_house(index: int) -> String:
	var s := house_stock()
	if index < 0 or index >= s.size():
		return "Already sold."
	var e: Dictionary = s[index]
	if not Game.can_afford(int(e["price"])):
		return "You cannot afford it (%d g)." % int(e["price"])
	var it: Dictionary = (e["item"] as Dictionary).duplicate(true)
	it["uid"] = Game.new_uid()
	Game.add_gold(-int(e["price"]), "pawn", "Bought %s at the pawnshop" % Items.display_name(it))
	Game.add_item(it, false)
	_log("Bought %s for %d g." % [Items.display_name(it), int(e["price"])], -int(e["price"]))
	s.remove_at(index)
	return ""


static func _pawn_day() -> void:
	var keep := int(pawn_cfg().get("forfeit_keep_days", 20))
	for p in pledges().duplicate():
		if p["status"] == "held" and Game.day() > int(p["due"]):
			p["status"] = "forfeit"
			p["forfeit_day"] = Game.day()
			var nm := Items.display_name(p["item"])
			Items.add_history(p["item"], "Pawned by the smith and never redeemed.")
			_log("Ticket %s lapsed: %s is on Quell's shelf now." % [p["id"], nm], 0)
			Events.toast.emit("Your pledge %s has lapsed — it is for sale on Quell's shelf." % nm, "bad")
		elif p["status"] == "forfeit" and Game.day() > int(p.get("forfeit_day", Game.day())) + keep:
			_log("%s was sold to a passing buyer." % Items.display_name(p["item"]), 0)
			pledges().erase(p)


# ====================================================================== rival smith
static func rival_cfg() -> Dictionary:
	return cfg().get("rival", {})


static func rival_stock() -> Array:
	var r: Dictionary = st()["rival"]
	var every := maxi(1, int(rival_cfg().get("restock_days", 4)))
	if not r.has("stock") or Game.day() - int(r.get("day", -999)) >= every:
		var out := []
		var pf := price_factor()
		for e in rival_cfg().get("stock", []):
			if randf() > float(e[2]) or DB.item(str(e[0])).is_empty():
				continue
			var it := Items.make(str(e[0]), {"quality": randf_range(82, 104), "rarity": "magic" if randf() < 0.2 else "common", "crafted_by": "Maren Tallowgate"})
			Items.add_history(it, "Forged at the Salt Anvil by Maren Tallowgate.")
			out.append({"def": str(e[0]), "qty": 1, "item": it, "price": maxi(1, int(round(Items.value(it) * float(e[1]) * pf)))})
		for e in rival_cfg().get("materials", []):
			if randf() > float(e[3]) or DB.item(str(e[0])).is_empty():
				continue
			out.append({"def": str(e[0]), "qty": randi_range(int(e[2][0]), int(e[2][1])),
				"price": maxi(1, int(round(float(DB.item(str(e[0])).get("value", 5)) * float(e[1]) * pf)))})
		r["stock"] = out
		r["day"] = Game.day()
	return r["stock"]


static func buy_rival(index: int, qty := 1) -> String:
	var s := rival_stock()
	if index < 0 or index >= s.size():
		return "Already sold."
	var e: Dictionary = s[index]
	qty = mini(qty, int(e["qty"]))
	if qty <= 0:
		return "Sold out."
	var cost := int(e["price"]) * qty
	if not Game.can_afford(cost):
		return "You cannot afford it (%d g)." % cost
	var what := _iname(str(e["def"]))
	Game.add_gold(-cost, "materials" if not e.has("item") else "equipment", "The Salt Anvil: %d × %s" % [qty, what])
	if e.has("item"):
		var it: Dictionary = (e["item"] as Dictionary).duplicate(true)
		it["uid"] = Game.new_uid()
		Game.add_item(it, false)
		e.erase("item")
	else:
		Game.add_item(Items.make(str(e["def"]), {"qty": qty, "quality": randf_range(75, 92)}), false)
	e["qty"] = int(e["qty"]) - qty
	Trade.mark_seen(str(e["def"]))
	return ""


## What the adventurer would buy at the Salt Anvil today ({} = nothing). Does not change anything.
static func rival_offer_for(a: Dictionary) -> Dictionary:
	if a.is_empty():
		return {}
	var gold := int(a.get("gold", 0))
	var best := {}
	var best_gain := 1.5
	var s := rival_stock()
	for i in s.size():
		var e: Dictionary = s[i]
		if not e.has("item") or int(e["qty"]) <= 0 or int(e["price"]) > gold:
			continue
		var it: Dictionary = e["item"]
		var slot := Items.slot(it)
		if slot == "":
			continue
		var gain := Items.score(it) - Items.score(a.get("equipment", {}).get(slot, {}))
		if gain > best_gain:
			best_gain = gain
			best = {"index": i, "item": it, "price": int(e["price"]), "slot": slot}
	return best


## The adventurer buys the best upgrade they can afford at the Salt Anvil and wears it.
## Returns {item, price, slot} or {} when nothing suits them. (Called by Adv.buy_elsewhere.)
static func rival_buy_for(a: Dictionary) -> Dictionary:
	var o := rival_offer_for(a)
	if o.is_empty():
		return {}
	var s := rival_stock()
	var e: Dictionary = s[int(o["index"])]
	var it: Dictionary = (e["item"] as Dictionary).duplicate(true)
	it["uid"] = Game.new_uid()
	e.erase("item")
	e["qty"] = 0
	var price := int(o["price"])
	a["gold"] = int(a.get("gold", 0)) - price
	var slot := str(o["slot"])
	var eq: Dictionary = a.get("equipment", {})
	if eq.has(slot) and not (eq[slot] as Dictionary).is_empty():
		if not a.has("loot"):
			a["loot"] = []
		a["loot"].append(eq[slot])
	eq[slot] = it
	a["equipment"] = eq
	it["owner"] = str(a.get("id", ""))
	Items.add_history(it, "Bought by %s at the Salt Anvil." % a.get("name", "an adventurer"))
	var sales: Array = st()["rival"]["sales"]
	sales.append({"day": Game.day(), "adv": str(a.get("id", "")), "item": str(it["name"]), "price": price})
	while sales.size() > 20:
		sales.pop_front()
	Chronicle.add("trade", "%s bought %s at Maren Tallowgate's Salt Anvil for %d gold." % [a.get("name", "An adventurer"), str(it["name"]).to_lower(), price],
		{"adv": a.get("id", ""), "npc": "rival_smith"})
	Events.adventurers_changed.emit()
	return {"item": it, "price": price, "slot": slot}


static func rival_sales() -> Array:
	return st()["rival"]["sales"]


## The smith's standing as Maren sees it: shop reputation plus Hall of Fame honours.
static func rivalry_band() -> String:
	var rep := Shop.reputation()
	var hof := hall_of_fame_count()
	if rep >= 70.0 or hof >= 3:
		return "high"
	if rep >= 40.0 or hof >= 1:
		return "mid"
	return "low"


## Number of Hall of Fame entries (works with whatever shape the Hall of Fame state has; 0 when absent).
static func hall_of_fame_count() -> int:
	var h: Variant = Game.state.get("hall_of_fame")
	if h is Array:
		return (h as Array).size()
	if h is Dictionary:
		for k in ["entries", "items", "honours", "plaques"]:
			if (h as Dictionary).get(k) is Array:
				return ((h as Dictionary)[k] as Array).size()
		return (h as Dictionary).size()
	return 0


static func _rival_rivalry_line() -> String:
	var lines: Dictionary = rival_cfg().get("lines", {}).get("rivalry", {})
	var pool: Array = []
	if hall_of_fame_count() > 0 and randf() < 0.6:
		pool = lines.get("hof", [])
	if pool.is_empty():
		pool = lines.get(rivalry_band(), [])
	var extra := ""
	var sales := rival_sales()
	if not sales.is_empty() and Game.day() - int(sales[-1]["day"]) <= 7:
		var s: Dictionary = sales[-1]
		extra = "\n\n\"%s bought my %s last week. Paid full price, too. Just so you know.\"" % [Talk.npc_name(str(s["adv"])), str(s["item"]).to_lower()]
	return (str(pool[randi() % pool.size()]) if not pool.is_empty() else "\"Hm.\"") + extra


static func _rival_tip() -> String:
	var r: Dictionary = st()["rival"]
	if int(r.get("tip_day", -99)) == Game.day():
		return "\"One tip a day, smith. I'm generous, not daft.\""
	var tips: Array = rival_cfg().get("lines", {}).get("tips", [])
	if tips.is_empty():
		return "\"Keep your fire clean.\""
	var i := int(r.get("tip", 0)) % tips.size()
	var t: Dictionary = tips[i]
	r["tip"] = i + 1
	r["tip_day"] = Game.day()
	if str(t.get("flag", "")) != "":
		Game.set_flag(str(t["flag"]))
	Social.change("rival_smith", 1.0, 2.0)
	return str(t["text"])


# ====================================================================== creatures
static func creature_cfg() -> Dictionary:
	return cfg().get("creatures", {})


static func creature_price(def_id: String) -> int:
	return maxi(1, int(round(float(DB.item(def_id).get("value", 50)) * price_factor())))


## The Hales' yard this week: [{def, price, quality, sold}]. Ordinary beasts are usually in; magical ones rarely.
static func creature_stock() -> Array:
	var c: Dictionary = st()["creatures"]
	var every := maxi(1, int(creature_cfg().get("restock_days", 7)))
	if not c.has("stock") or Game.day() - int(c.get("day", -999)) >= every:
		var out := []
		for key in ["ordinary", "magical"]:
			for e in creature_cfg().get(key, []):
				if DB.item(str(e[0])).is_empty() or randf() > float(e[1]):
					continue
				out.append({"def": str(e[0]), "price": creature_price(str(e[0])), "quality": randf_range(80, 100), "sold": false})
		# at least one magical creature to wonder at, and the plain ones are never all gone
		if not out.any(func(x): return Companions.magical(str(x["def"]))):
			var mg: Array = creature_cfg().get("magical", [])
			if not mg.is_empty():
				var m: Array = mg[randi() % mg.size()]
				out.append({"def": str(m[0]), "price": creature_price(str(m[0])), "quality": randf_range(80, 100), "sold": false})
		c["stock"] = out
		c["day"] = Game.day()
	return c["stock"]


static func _stock_entry(index: int) -> Dictionary:
	var s := creature_stock()
	if index < 0 or index >= s.size():
		return {}
	var e: Dictionary = s[index]
	return {} if bool(e.get("sold", false)) else e


## Buy a creature for the smith (into the stores — to keep, give or sell on).
static func buy_creature(index: int) -> String:
	var e := _stock_entry(index)
	if e.is_empty():
		return "That one has already gone to a new home."
	var price := int(e["price"])
	if not Game.can_afford(price):
		return "You cannot afford it (%d g)." % price
	var it := Companions.make(str(e["def"]), float(e["quality"]))
	Game.add_gold(-price, "creatures", "Hale Farm: %s" % it["name"])
	Game.add_item(it, false)
	e["sold"] = true
	Chronicle.add("trade", "The smith bought %s from Hale Farm." % it["name"], {"item": e["def"]}, Companions.magical(str(e["def"])))
	return ""


## Arrange a creature for an adventurer in town.
##   "gift"    — the smith pays the Hales; the adventurer gets it free (a warm gesture).
##   "sell"    — the smith pays the Hales and sells it on at `markup` (1.0 fair … 1.3 steep); they pay the smith.
##   "arrange" — an introduction: the adventurer pays the Hales; the smith gets a small finder's fee.
static func arrange_creature(index: int, adv_id: String, mode: String, markup := 1.15) -> String:
	var e := _stock_entry(index)
	if e.is_empty():
		return "That one has already gone to a new home."
	var a := Adv.get_a(adv_id)
	if a.is_empty() or str(a.get("status", "")) in ["dead", "missing", "away"]:
		return "They are not in Brindlewick."
	if not Companions.of(a).is_empty():
		return "%s already keeps %s." % [a["name"], Companions.pet_name(Companions.of(a))]
	var price := int(e["price"])
	var it := Companions.make(str(e["def"]), float(e["quality"]))
	var married: bool = Social.spouse() == adv_id
	match mode:
		"gift":
			if not Game.can_afford(price):
				return "You cannot afford it (%d g)." % price
			Game.add_gold(-price, "creatures", "A gift for %s: %s" % [a["name"], it["name"]])
			Companions.give(a, it, "A gift from the smith to %s." % a["name"])
			Social.change(adv_id, 10.0 + price / 60.0, 6.0, "creature_" + str(it["uid"]), "Brannoc gave me %s." % it["name"])
		"sell":
			if not Game.can_afford(price):
				return "You cannot afford it (%d g)." % price
			var ask := int(round(price * clampf(markup, 1.0, 1.6)))
			if married:
				ask = 0
			if int(a.get("gold", 0)) < ask:
				return "%s cannot afford %d g." % [a["name"], ask]
			Game.add_gold(-price, "creatures", "Hale Farm: %s for %s" % [it["name"], a["name"]])
			a["gold"] = int(a["gold"]) - ask
			if ask > 0:
				Game.add_gold(ask, "sales", "%s bought %s" % [a["name"], it["name"]])
			Companions.give(a, it, "Bought through the smith by %s for %d gold." % [a["name"], ask])
			var mood := 4.0 if markup <= 1.01 else (1.5 if markup <= 1.16 else -3.0)
			Social.change(adv_id, mood, 4.0, "creature_" + str(it["uid"]), "The smith found me %s%s." % [it["name"], "" if mood > 0 else " — and charged dearly for it"])
		"arrange":
			if int(a.get("gold", 0)) < price:
				return "%s cannot afford %d g." % [a["name"], price]
			a["gold"] = int(a["gold"]) - price
			var fee := int(round(price * float(creature_cfg().get("finder_fee", 0.1))))
			if fee > 0:
				Game.add_gold(fee, "sales", "Finder's fee from Hale Farm (%s)" % a["name"])
			Companions.give(a, it, "Bought at Hale Farm by %s, introduced by the smith." % a["name"])
			Social.change(adv_id, 2.5, 4.0, "creature_" + str(it["uid"]), "The smith introduced me to the Hales — and %s." % it["name"])
		_:
			return "Unknown arrangement."
	e["sold"] = true
	Chronicle.add("social", "%s now keeps %s, from Hale Farm." % [a["name"], it["name"]], {"adv": adv_id, "item": e["def"]}, Companions.magical(str(e["def"])))
	return ""


## Give a companion from the smith's stores to an adventurer in town, as a gift.
static func give_owned_creature(uid: int, adv_id: String) -> String:
	var it := Game.find_uid(uid)
	if not Companions.is_companion(it):
		return "You have no such creature."
	var a := Adv.get_a(adv_id)
	if a.is_empty() or str(a.get("status", "")) in ["dead", "missing", "away"]:
		return "They are not in Brindlewick."
	if not Companions.of(a).is_empty():
		return "%s already keeps %s." % [a["name"], Companions.pet_name(Companions.of(a))]
	Game.take_uid(uid)
	Companions.give(a, it, "A gift from the smith to %s." % a["name"])
	Social.change(adv_id, 8.0 + Items.value(it) / 60.0, 6.0, "creature_" + str(it["uid"]), "Brannoc gave me %s." % it["name"])
	Chronicle.add("social", "%s now keeps %s, a gift from the smith." % [a["name"], it["name"]], {"adv": adv_id}, Companions.magical(str(it["def"])))
	return ""


static func commissions() -> Array:
	return st()["creatures"]["orders"]


## Order a creature that is not in the yard this week (magical ones especially). Paid in full now
## (`markup` over the yard price); it arrives after a few days — to the smith, or straight to `for_adv` as a gift.
static func commission_creature(def_id: String, for_adv := "") -> String:
	if not Companions.defs().has(def_id):
		return "The Hales do not raise that."
	var cc: Dictionary = creature_cfg().get("commission", {})
	var price := int(round(creature_price(def_id) * float(cc.get("markup", 1.15))))
	if not Game.can_afford(price):
		return "A commission costs %d g — you cannot afford it." % price
	if for_adv != "":
		var a := Adv.get_a(for_adv)
		if a.is_empty() or str(a.get("status", "")) in ["dead", "missing"]:
			return "No such adventurer."
		if not Companions.of(a).is_empty():
			return "%s already keeps a companion." % a["name"]
	var lead: Array = cc.get("lead", [3, 6])
	var days := randi_range(int(lead[0]), int(lead[1]))
	var o := {"id": _new_id("cr"), "def": def_id, "for": for_adv, "price": price, "placed": Game.day(), "due": Game.day() + days, "status": "ordered"}
	commissions().append(o)
	Game.add_gold(-price, "creatures", "Commissioned from Hale Farm: %s" % _iname(def_id))
	Chronicle.add("trade", "The smith commissioned a %s from Hale Farm%s." % [_iname(def_id).to_lower(), (" for " + Talk.npc_name(for_adv)) if for_adv != "" else ""], {"item": def_id})
	return ""


static func _creature_day() -> void:
	for o in commissions().duplicate():
		if Game.day() < int(o["due"]):
			continue
		var target := str(o.get("for", ""))
		var a := Adv.get_a(target) if target != "" else {}
		if target != "" and not a.is_empty() and str(a.get("status", "")) in ["away", "injured"]:
			continue   # wait until they are back in town
		var it := Companions.make(str(o["def"]), randf_range(88, 102))
		if target != "" and not a.is_empty() and str(a.get("status", "")) == "in_town" and Companions.of(a).is_empty():
			Companions.give(a, it, "Commissioned by the smith from Hale Farm as a gift for %s." % a["name"])
			Social.change(target, 10.0 + int(o["price"]) / 60.0, 6.0, "creature_" + str(it["uid"]), "The smith commissioned %s for me." % it["name"])
			Events.toast.emit("%s has been delivered to %s." % [it["name"], a["name"]], "good")
			Chronicle.add("social", "%s received %s, commissioned by the smith from Hale Farm." % [a["name"], it["name"]], {"adv": target}, true)
		else:
			Game.add_item(it, false)
			Events.toast.emit("Hale Farm has delivered %s to your stores." % it["name"], "good")
		commissions().erase(o)


## A creature a (rich, companion-less) adventurer would like from the Hales' yard ({} = none). No change.
## {index, def, price}. Evaluating wants and effects is the Adventurer worker's business.
static func creature_offer_for(a: Dictionary) -> Dictionary:
	if a.is_empty() or not Companions.of(a).is_empty():
		return {}
	var gold := int(a.get("gold", 0))
	var likes: Dictionary = {"Ranger": ["comp_hunting_falcon", "comp_glimmer_fox", "comp_war_hound"],
		"Fighter": ["comp_war_hound", "comp_fell_pony", "comp_pack_mule"], "Wizard": ["comp_stone_toad", "comp_moon_moth", "comp_mouser_cat"],
		"Rogue": ["comp_glimmer_fox", "comp_mouser_cat", "comp_hunting_falcon"], "Paladin": ["comp_war_hound", "comp_fell_pony", "comp_moon_moth"],
		"Cleric": ["comp_moon_moth", "comp_pack_mule", "comp_mouser_cat"], "Barbarian": ["comp_war_hound", "comp_pocket_drake", "comp_pack_mule"],
		"Bard": ["comp_mouser_cat", "comp_glimmer_fox", "comp_hunting_falcon"]}
	var pref: Array = likes.get(str(a.get("cls", "")), ["comp_war_hound", "comp_pack_mule"])
	var s := creature_stock()
	for want in pref:
		for i in s.size():
			var e: Dictionary = s[i]
			if bool(e.get("sold", false)) or str(e["def"]) != str(want):
				continue
			# "rich": the creature costs no more than two-thirds of their purse
			if int(e["price"]) * 3 <= gold * 2:
				return {"index": i, "def": str(e["def"]), "price": int(e["price"])}
	return {}


## The adventurer buys a creature at Hale Farm themselves. Returns {item, price} or {}.
static func creature_buy_for(a: Dictionary, offer := {}) -> Dictionary:
	var o: Dictionary = offer if not offer.is_empty() else creature_offer_for(a)
	if o.is_empty():
		return {}
	var e := _stock_entry(int(o["index"]))
	if e.is_empty() or str(e["def"]) != str(o["def"]) or int(a.get("gold", 0)) < int(e["price"]):
		return {}
	var it := Companions.make(str(e["def"]), float(e["quality"]))
	if Companions.give(a, it, "Bought at Hale Farm by %s." % a.get("name", "an adventurer")) != "":
		return {}
	a["gold"] = int(a["gold"]) - int(e["price"])
	e["sold"] = true
	Chronicle.add("social", "%s bought %s at Hale Farm." % [a.get("name", "An adventurer"), it["name"]], {"adv": a.get("id", "")}, Companions.magical(str(e["def"])))
	return {"item": it, "price": int(e["price"])}


# ====================================================================== world schedule & talk
## Where a commerce character stands at this hour; "" = not about; "-" = not a commerce character.
## (The village worker's spots: pawn_counter, rival_smith_counter, rival_smith_forge, hale_yard, hale_study, caravan_camp.)
static func spot_for(id: String, h: int) -> String:
	match id:
		"pawnbroker":
			return "pawn_counter" if h >= 8 and h < 19 else ""
		"rival_smith":
			if h >= 7 and h < 12:
				return "rival_smith_forge"
			if h >= 12 and h < 18:
				return "rival_smith_counter"
			return "inn_bar" if h >= 19 and h < 22 else ""
		"hale_elder":
			if h >= 6 and h < 18:
				return "hale_yard"
			return "inn_t2" if h >= 19 and h < 21 else ""
		"hale_younger":
			if h >= 16 and h < 17:
				return "pond_2"
			return "hale_study" if h >= 8 and h < 21 else ""
		"caravan_master":
			return "caravan_camp" if caravan_present() and h >= 7 and h < 22 else ""
	return "-"


static func greeting(npc: String) -> String:
	match npc:
		"rival_smith":
			var g: Array = rival_cfg().get("lines", {}).get("greet", [])
			return str(g[randi() % g.size()]) if not g.is_empty() else ""
		"pawnbroker":
			var p: Array = pawn_cfg().get("lines", [])
			return str(p[Game.day() % p.size()]) if not p.is_empty() else ""
		"caravan_master":
			if not caravan_present():
				return "\"The wagons are on the road, smith. I came back for my hat.\""
			var c: Array = cfg().get("caravan", {}).get("lines", [])
			return str(c[randi() % c.size()]) if not c.is_empty() else ""
		"hale_elder", "hale_younger":
			var l: Array = creature_cfg().get("lines", {}).get(npc, [])
			return str(l[randi() % l.size()]) if not l.is_empty() else ""
	return ""


static func talk_options(npc: String) -> Array:
	match npc:
		"rival_smith":
			return [{"id": "c_rival_shop", "label": "Browse the Salt Anvil's wares"}, {"id": "c_rival_talk", "label": "Talk shop"},
				{"id": "c_rival_jab", "label": "Trade friendly jabs"}, {"id": "c_rival_tip", "label": "Ask for a smith's tip"}]
		"pawnbroker":
			return [{"id": "c_pawn", "label": "Pledge or redeem something"}]
		"caravan_master":
			return [{"id": "c_caravan", "label": "See the wagons"}] if caravan_present() else []
		"hale_elder", "hale_younger":
			return [{"id": "c_creatures", "label": "See the creatures"}, {"id": "c_hale_talk", "label": "Ask about the creatures"}]
	return []


static func talk_choose(npc: String, opt: String) -> Dictionary:
	match opt:
		"c_rival_shop":
			Events.open_panel.emit.call_deferred("rival_smith", {"id": "rival_smith"})
			return {"text": "\"Look, don't drool.\"", "action": "close"}
		"c_rival_talk":
			Social.change(npc, 1.0, 2.0)
			var s: Array = rival_cfg().get("lines", {}).get("shop", [])
			return {"text": str(s[randi() % s.size()]) if not s.is_empty() else "\"Hot iron, cold beer.\""}
		"c_rival_jab":
			Social.change(npc, 1.5, 2.0)
			return {"text": _rival_rivalry_line()}
		"c_rival_tip":
			return {"text": _rival_tip()}
		"c_pawn":
			Events.open_panel.emit.call_deferred("pawn", {"id": "pawn"})
			return {"text": "\"Let us see what you have.\"", "action": "close"}
		"c_caravan":
			Events.open_panel.emit.call_deferred("caravan", {"id": "caravan"})
			return {"text": "\"Come, come — mind the camel. There is no camel. Mind it anyway.\"", "action": "close"}
		"c_creatures":
			Events.open_panel.emit.call_deferred("creatures", {"id": "hale"})
			return {"text": "\"Come and meet them.\"", "action": "close"}
		"c_hale_talk":
			Social.change(npc, 1.0, 2.0)
			var key := "talk_elder" if npc == "hale_elder" else "talk_younger"
			var l: Array = creature_cfg().get("lines", {}).get(key, [])
			return {"text": str(l[randi() % l.size()]) if not l.is_empty() else "\"They're good creatures.\""}
	return {}


# ====================================================================== clock (called from Sim)
static func on_day() -> void:
	st()
	_pawn_day()
	_creature_day()


static func on_hour(_h: int) -> void:
	var c := st()
	if not c["caravan"].is_empty() and Game.now() >= int(c["caravan"]["leaves"]):
		_caravan_depart()
	if c["caravan"].is_empty() and not c["caravan_next"].is_empty() and Game.now() >= int(c["caravan_next"]["at"]):
		_caravan_arrive()
