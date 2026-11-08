## Shop — customers, stock, purchases, repairs and special orders (commissions).
## EN: Items flagged `for_sale` are shop stock. During opening hours customers walk to the
##     counter: villagers want repairs or small goods, adventurers browse stock or place special
##     orders matched to their class, level and upcoming danger. Unserved customers leave unhappy.
## DA: Genstande markeret `for_sale` er butikkens lager. I åbningstiden går kunder til disken:
##     landsbyboere vil have reparationer, eventyrere kigger på varer eller afgiver særlige
##     bestillinger. Kunder, der ikke bliver betjent, går utilfredse.
class_name Shop
extends RefCounted


static func stock() -> Array:
	return Game.inventory().filter(func(it): return it.get("for_sale", false))


static func price_of(it: Dictionary) -> int:
	if it.has("price"):
		return int(it["price"])
	var p := Items.value(it)
	if Game.has_upgrade("display_cases"):
		p = int(p * 1.1)
	# difficulty: Apprentice buyers pay a little more, Master buyers haggle harder
	p = int(round(p * float(Expeditions.diff().get("prices", 1.0))))
	return maxi(1, p)


static func customers() -> Array:
	return Game.state["customers"]


const SEATS := 4
const UPKEEP := 4


# ------------------------------------------------------------------ reputation
## The workshop's standing in Brindlewick: how people regard the smith, plus what they have heard
## (good sales, disputes settled or refused, adventurers saved or lost by the smith's work).
static func reputation() -> float:
	var tot := 0.0
	var n := 0
	for npc in Game.state["social"]:
		var k: String = DB.character(npc).get("kind", "")
		if k in ["adventurer", "villager"]:
			tot += float(Game.state["social"][npc]["aff"])
			n += 1
	var base := tot / maxf(1.0, n)
	return clampf(base * 0.8 + float(Game.state["world"].get("rep", 0.0)), -100.0, 100.0)


static func rep_change(delta: float, why := "") -> void:
	var w: Dictionary = Game.state["world"]
	w["rep"] = clampf(float(w.get("rep", 0.0)) + delta, -60.0, 60.0)
	if why != "" and absf(delta) >= 3.0:
		Game.journal(("Word gets around: " if delta > 0 else "Tongues wag: ") + why)


static func reputation_word() -> String:
	var r := reputation()
	if r <= -25.0:
		return "notorious"
	if r <= -8.0:
		return "poorly thought of"
	if r < 8.0:
		return "a modest name"
	if r < 25.0:
		return "well respected"
	return "renowned"


## Daily running costs: coal, rent to the reeve, the odd broken tool.
static func pay_upkeep() -> void:
	var cost: int = UPKEEP + Game.state.get("upgrades", []).size()
	Game.add_gold(-cost, "upkeep", "Coal, rent and tools")


# ------------------------------------------------------------------ offers from returning adventurers
## Materials, relics and spare gear an adventurer brings home and offers to the smith (3 days).
static func offers() -> Array:
	if not Game.state.has("offers"):
		Game.state["offers"] = []
	return Game.state["offers"]


static func add_offer(adv_id: String, it: Dictionary, announce := true) -> void:
	var a := Adv.get_a(adv_id)
	if a.is_empty() or it.is_empty():
		return
	var price := maxi(2, int(Items.value(it) * (0.55 if Social.band(adv_id) in ["friendly", "devoted"] else 0.75)))
	if Social.spouse() == adv_id:
		price = 0
	it["owner"] = adv_id
	offers().append({"id": "off_%d" % Game.new_uid(), "from": adv_id, "item": it, "price": price, "day": Game.day()})
	if announce and (Regions.is_unidentified(it) or it.get("rarity", "common") in ["rare", "legendary"] or DB.item(it["def"]).get("tags", []).has("rare")):
		Chronicle.add("discovery", "%s brought home %s and offers it to the forge." % [a["name"], Items.display_name(it)], {"adv": adv_id, "item": str(it["uid"])}, true)
		Events.toast.emit("%s offers you %s (%d g) — see the shop counter." % [a["name"], Items.display_name(it), price], "good")


static func accept_offer(oid: String) -> String:
	for o in offers():
		if o["id"] != oid:
			continue
		var price := int(o["price"])
		if not Game.can_afford(price):
			return "You cannot afford it."
		var a := Adv.get_a(o["from"])
		Game.add_gold(-price, "materials", "Bought %s from %s" % [o["item"]["name"], a.get("name", "")])
		a["gold"] = int(a.get("gold", 0)) + price
		var it: Dictionary = o["item"]
		it["owner"] = "smith"
		Items.add_history(it, "Sold to the forge by %s for %d g." % [a.get("name", ""), price])
		Game.add_item(it)
		offers().erase(o)
		Social.change(o["from"], 2.0, 2.0)
		# the relic hunter: a relic sold to the forge earns a special commission
		if Regions.is_unidentified(it) and Shop.open_orders().filter(func(x): return x["npc"] == o["from"]).is_empty():
			var ord := create_order(o["from"], "", "Since you have the relic I found — make me something worthy of the barrows.")
			if not ord.is_empty():
				ord["reward"] = int(ord["reward"]) + 60
		return ""
	return "That offer is gone."


static func decline_offer(oid: String) -> void:
	for o in offers():
		if o["id"] == oid:
			offers().erase(o)
			# they sell it on at the market instead
			var a := Adv.get_a(o["from"])
			if not a.is_empty():
				a["gold"] = int(a.get("gold", 0)) + int(Items.value(o["item"]) * 0.4)
			return


static func expire_offers() -> void:
	for o in offers().duplicate():
		if Game.day() - int(o["day"]) >= 3:
			offers().erase(o)


## An adventurer's most worn piece, if anything is below 40% durability.
static func worn_slot(a: Dictionary) -> String:
	for slot in a.get("equipment", {}):
		var st: Dictionary = a["equipment"][slot].get("stats", {})
		if st.has("durability_max") and float(st["durability"]) < float(st["durability_max"]) * 0.4:
			return slot
	return ""


## Would this person deal with the smith at all?
static func refuses(npc: String) -> bool:
	return Social.band(npc) == "hostile"


static func sell_goods(npc: String, uid: int) -> String:
	var it := Game.find_uid(uid)
	var c := {}
	for x in customers():
		if x["npc"] == npc:
			c = x
	if it.is_empty() or c.is_empty():
		return "Nothing to sell."
	var price := price_of(it) / maxi(1, int(it.get("qty", 1)))
	if price > int(c.get("budget", 0)):
		return "%s can't afford that." % Talk.npc_name(npc)
	if int(it.get("qty", 1)) > 1:
		it["qty"] = int(it["qty"]) - 1
	else:
		Game.inventory().erase(it)
	Game.add_gold(price, "sales", "Sold %s to %s" % [it["name"], Talk.npc_name(npc)])
	Social.change(npc, 3.0, 3.0)
	rep_change(0.5)
	remove_customer(npc)
	Events.inventory_changed.emit()
	return ""


## A customer whose gear failed them comes back. Refund (costly, but people remember fairness)
## or refuse (cheap now, dear later).
static func settle_dispute(npc: String, refund: bool) -> String:
	var c := {}
	for x in customers():
		if x["npc"] == npc and x["want"] == "dispute":
			c = x
	if c.is_empty():
		return ""
	var amount := int(c.get("refund", 20))
	remove_customer(npc)
	if refund:
		Game.add_gold(-amount, "refunds", "Refund to %s" % Talk.npc_name(npc))
		Social.change(npc, 8.0, 4.0, "refund_" + str(Game.day()), "The smith refunded me without argument when his work failed.")
		rep_change(4.0, "the smith stands by his work.")
		return "You count out %d g. \"That's... fair of you, smith.\"" % amount
	Social.change(npc, -18.0, 4.0, "refused_" + str(Game.day()), "The smith refused to make good on gear that failed me.")
	rep_change(-6.0, "the smith won't stand by his work.")
	return "\"Then everyone will hear how the Ironhand forge treats its customers.\""


## Called when an adventurer comes home hurt with the smith's poor work: a dispute at the shop.
static func raise_dispute(npc: String, it: Dictionary) -> void:
	if customers().any(func(c): return c["npc"] == npc) or free_seat() < 0:
		return
	var seat := free_seat()
	customers().append({"npc": npc, "want": "dispute", "arrived": Game.day() * 24 + Game.hour(), "seat": seat, "present": false,
		"item_name": it.get("name", "gear"), "refund": maxi(15, int(Items.value(it) * 0.5))})
	Events.customers_changed.emit()


# ------------------------------------------------------------------ explicit customer requests
## What each slot is judged by, and which materials a customer would like it made from.
const SLOT_STAT := {"weapon": "attack", "ring": "magic", "amulet": "magic"}


## "a pair of boots", "an amulet", "a weapon" — for request sentences.
static func slot_phrase(slot: String) -> String:
	match slot:
		"boots", "gloves":
			return "a pair of " + slot
		"armor":
			return "a suit of armour"
		"amulet":
			return "an amulet"
	return "a " + slot


static func stat_for_slot(slot: String) -> String:
	return str(SLOT_STAT.get(slot, "protection"))


static func preferred_materials(level: int, slot: String) -> Array:
	if slot in ["boots", "gloves", "belt"]:
		return ["leather"]
	if slot in ["ring", "amulet"]:
		return ["silver", "gems"]
	return ["steel", "mithril"] if level >= 5 else ["iron", "steel"]


static func customer(npc: String) -> Dictionary:
	for c in customers():
		if c["npc"] == npc:
			return c
	return {}


## Fills in an adventurer customer's explicit wish (slot, stat, minimum, property, materials).
## Stored on the customer when they set out; old saves get it computed on demand.
static func _equipment_wish(c: Dictionary, a: Dictionary) -> void:
	var slot := str(c.get("slot", ""))
	if slot == "":
		slot = str(a.get("needs", ""))
	if slot == "":
		slot = Adv._weakest_slot(a)
	c["slot"] = slot
	var stat := str(c.get("stat", stat_for_slot(slot)))
	c["stat"] = stat
	if not c.has("min"):
		c["min"] = Items.stat(a.get("equipment", {}).get(slot, {}), stat) + 1
	if not c.has("prop"):
		c["prop"] = str(a.get("wants_prop", "")) if slot == "weapon" else ""
	if not c.has("materials"):
		c["materials"] = preferred_materials(int(a.get("level", 1)), slot)


## The customer's request as data for a card: {kind, npc, name, headline, slot, item_def, stat, min,
## prop, materials, budget, reward, reward_text, deadline, priority, note, summary}. Works for any
## waiting customer (repair / goods / browse / dispute) and for adventurers you are only talking to.
static func request(c: Dictionary) -> Dictionary:
	var npc := str(c.get("npc", ""))
	var want := str(c.get("want", "browse"))
	var r := {"kind": want, "npc": npc, "name": Talk.npc_name(npc)}
	match want:
		"repair":
			var it: Dictionary = c.get("item", {})
			r["item_def"] = str(it.get("def", ""))
			r["slot"] = Items.slot(it) if not it.is_empty() else ""
			r["headline"] = "Repair: %s" % it.get("name", "gear")
			var st: Dictionary = it.get("stats", {})
			if st.has("durability_max"):
				r["condition"] = "durability %d / %d" % [int(st.get("durability", 0)), int(st["durability_max"])]
			if it.get("broken", false):
				r["condition"] = "broken"
			r["reward"] = int(c.get("pay", 10))
			r["reward_text"] = "about %d g, more for fine work" % int(c.get("pay", 10))
		"goods":
			var d := str(c.get("looking_for", "potion_healing"))
			r["item_def"] = d
			r["headline"] = "Wants: %s" % DB.item(d).get("name", "a draught")
			r["budget"] = int(c.get("budget", 40))
			r["reward_text"] = "pays your price, up to %d g" % int(c.get("budget", 40))
		"dispute":
			r["headline"] = "Dispute: their %s failed them" % c.get("item_name", "gear")
			r["reward_text"] = "wants %d g back" % int(c.get("refund", 20))
		_:
			var a := Adv.get_a(npc)
			r["kind"] = "equipment"
			if a.is_empty():
				r["headline"] = "Browsing your wares"
			else:
				_equipment_wish(c, a)
				r["slot"] = c["slot"]
				r["stat"] = c["stat"]
				r["min"] = int(c["min"])
				r["prop"] = str(c.get("prop", ""))
				r["materials"] = c["materials"]
				r["budget"] = int(a.get("gold", 0))
				var sl := str(c["slot"])
				r["headline"] = ("Wants better %s" % ("armour" if sl == "armor" else sl)) if sl in ["boots", "gloves", "armor"] else ("Wants a better %s" % sl)
				r["reward_text"] = "pays your display price, remembers fine work" if Social.spouse() != npc else "your wife: gear is free"
	r["summary"] = request_summary(r)
	return r


## A commission as a request card (same look as the counter).
static func order_request(o: Dictionary) -> Dictionary:
	var a := Adv.get_a(str(o["npc"]))
	var tier := int(o.get("tier", 1))
	var mats: Array = preferred_materials(int(a.get("level", 1)), str(o["slot"]))
	if tier == 2:
		mats = ["steel", "mithril"]
	elif tier == 3:
		mats = ["mithril", "starsteel"]
	elif tier >= 4:
		mats = ["adamantine"]
	var stat := str(o["stat"])
	var bonus: Dictionary = o.get("bonus", {})
	var r := {"kind": "commission", "npc": str(o["npc"]), "name": Talk.npc_name(str(o["npc"])), "slot": str(o["slot"]), "stat": stat,
		"min": int(o["min"]), "prop": "", "materials": mats, "material_required": tier >= 2, "reward": int(o["reward"]),
		"deadline": int(o["deadline"]), "priority": str(o.get("priority", "")), "headline": "Commission: %s" % slot_phrase(str(o["slot"])),
		"note": str(o.get("note", "")), "reward_text": "%d g" % int(o["reward"])}
	if not bonus.is_empty():
		r["reward_text"] += " + %d g bonus for %s" % [int(bonus.get("gold", 0)), bonus.get("text", "")]
	r["summary"] = request_summary(r)
	return r


## One line for toasts and lists: "a weapon (attack 7+, frost; iron or steel; budget 120 g)".
static func request_summary(r: Dictionary) -> String:
	match str(r.get("kind", "")):
		"repair":
			return "a repair of their %s (pays about %d g)" % [str(r.get("headline", "")).trim_prefix("Repair: "), int(r.get("reward", 0))]
		"goods":
			return "%s (budget %d g)" % [DB.item(str(r.get("item_def", ""))).get("name", "a draught"), int(r.get("budget", 0))]
		"dispute":
			return "to settle a dispute: %s" % r.get("reward_text", "")
	if not r.has("slot"):
		return "to look at your wares"
	var attrs := "%s ≥ %d" % [r["stat"], int(r.get("min", 0))]
	if str(r.get("prop", "")) != "" and r["prop"] != r["stat"]:
		attrs += ", " + str(r["prop"])
	var mats: Array = r.get("materials", [])
	var out := "%s (%s; %s" % [slot_phrase(str(r["slot"])), attrs, " or ".join(PackedStringArray(mats))]
	if r.has("budget"):
		out += "; budget %d g)" % int(r["budget"])
	elif r.has("reward"):
		out += "; reward %d g)" % int(r["reward"])
	else:
		out += ")"
	return out


## Customers who have physically arrived and sat down in the waiting area.
static func waiting() -> Array:
	return customers().filter(func(c): return c.get("present", true))


static func free_seat() -> int:
	for i in SEATS:
		if not customers().any(func(c): return int(c.get("seat", -1)) == i):
			return i
	return -1


## Hourly: maybe a customer sets out for the smithy (they are only announced once they sit down).
static func customer_hour(h: int) -> void:
	if h < 9 or h >= 18:
		return
	var now := Game.day() * 24 + h
	for c in customers().duplicate():
		if c.get("present", true):
			if now - int(c.get("seated", c["arrived"])) >= 3:
				customers().erase(c)
				Social.change(c["npc"], -3.0, 1.0, "", "", false)
				Events.toast.emit("%s gave up waiting outside the shop." % DB.character(c["npc"]).get("name", c["npc"]), "bad")
		elif now - int(c["arrived"]) >= 3:
			customers().erase(c)          # never made it here; nobody noticed
	if free_seat() < 0 or randf() > clampf(0.45 * (1.0 + reputation() / 120.0), 0.15, 0.75):
		return
	var pool := []
	for a in Adv.in_town():
		if not refuses(a["id"]):
			pool.append([a["id"], "repair_own" if worn_slot(a) != "" else "browse"])
	for v in ["martha", "tobin", "jory", "eda", "oswin", "wenna"]:
		if not refuses(v):
			pool.append([v, "goods" if randf() < 0.35 else "repair"])
	pool.shuffle()
	for p in pool:
		if customers().any(func(c): return c["npc"] == p[0]):
			continue
		_add_customer(p[0], p[1])
		break


static func _add_customer(npc: String, want: String) -> void:
	var seat := free_seat()
	if seat < 0:
		return
	var c := {"npc": npc, "want": want, "arrived": Game.day() * 24 + Game.hour(), "seat": seat, "present": false}
	if want == "repair":
		var defs := ["sword_iron", "axe_hand", "dagger", "helm_iron", "shield_round"]
		var it := Items.make(defs.pick_random(), {"quality": randf_range(50, 75)})
		if it["stats"].has("durability"):
			it["stats"]["durability"] = int(int(it["stats"]["durability_max"]) * randf_range(0.2, 0.5))
		c["item"] = it
		c["pay"] = randi_range(8, 18)
	elif want == "repair_own":
		var a2 := Adv.get_a(npc)
		var slot2 := worn_slot(a2)
		c["want"] = "repair"
		c["own_slot"] = slot2
		c["item"] = a2["equipment"][slot2]
		c["pay"] = 10 + int(Items.value(c["item"]) * 0.06)
	elif want == "goods":
		c["budget"] = randi_range(30, 80)
		c["looking_for"] = ["potion_healing", "oil_whetstone"].pick_random()
	else:
		var a := Adv.get_a(npc)
		c["budget"] = int(a.get("gold", 0))
		c["looking_for"] = a.get("needs", "")
		if not a.is_empty():
			_equipment_wish(c, a)
	customers().append(c)
	Events.customers_changed.emit()


## Called by the world when the customer's figure reaches its seat (VillageWorld._on_npc_arrived).
## This is the ONLY place a waiting customer is announced: setting out (_add_customer) is silent.
static func mark_arrived(npc: String, notify := true) -> void:
	for c in customers():
		if c["npc"] == npc and not c.get("present", false):
			c["present"] = true
			c["seated"] = Game.day() * 24 + Game.hour()
			if notify:
				Audio.play("sfx/door_bell", -4.0)
				Events.toast.emit("%s is waiting at your shop: wants %s." % [Talk.npc_name(npc), request(c)["summary"]], "info")
			Events.customers_changed.emit()


## Politely sends a waiting customer away; their seat is freed.
static func dismiss_customer(npc: String) -> void:
	for c in customers().duplicate():
		if c["npc"] == npc:
			customers().erase(c)
			Social.change(npc, -1.0, 0.5, "", "", false)
			Events.customers_changed.emit()


static func remove_customer(npc: String) -> void:
	for c in customers().duplicate():
		if c["npc"] == npc:
			customers().erase(c)
	Events.customers_changed.emit()


static func sell_to(npc: String, uid: int) -> String:
	var a := Adv.get_a(npc)
	var it := Game.find_uid(uid)
	if a.is_empty() or it.is_empty():
		return "Nothing to sell."
	var price := price_of(it)
	var why := Adv.purchase_check(a, it, price)
	if why != "":
		return "%s %s." % [a["name"], why]
	it = Game.take_uid(uid)
	it.erase("for_sale")
	var married := Social.spouse() == npc
	Items.add_history(it, "Sold to %s for %d g." % [a["name"], price] if not married else "Given to %s, the smith's wife." % a["name"])
	Adv.give_item(a, it, price)
	if not married:
		Game.add_gold(price, "sales", "Sold %s to %s" % [it["name"], a["name"]])
	Game.state["stats"]["sold"] += 1
	rep_change(1.0 if float(it.get("quality", 70)) >= 85.0 else 0.3)
	remove_customer(npc)
	Objectives.on_sold(npc, it)
	if npc == "mira":
		Sim.on_mira_equipped(it, price)
	return ""


static func do_repair(npc: String, quality: float) -> void:
	for c in customers():
		if c["npc"] == npc and c["want"] == "repair" and c.has("own_slot"):
			# an adventurer's own worn gear: restore its durability (well done = nearly as new)
			var a := Adv.get_a(npc)
			var it: Dictionary = a.get("equipment", {}).get(c["own_slot"], {})
			var st: Dictionary = it.get("stats", {})
			if st.has("durability_max"):
				st["durability"] = maxi(int(st["durability"]), int(float(st["durability_max"]) * clampf(0.55 + quality / 250.0, 0.5, 1.0)))
			if it.get("broken", false):
				it.erase("broken")
				Chronicle.add("item", "Brannoc mended %s's broken %s." % [a.get("name", npc), it.get("name", "blade")], {"adv": npc, "item": str(it.get("uid", ""))})
			Items.add_history(it, "Repaired at the Ironhand forge (%d%%)." % int(quality))
			var pay2 := int(round(float(c["pay"]) * (0.5 + quality / 100.0 * 0.7)))
			Game.add_gold(pay2, "repairs", "Repaired %s's %s" % [a.get("name", npc), it.get("name", "gear")])
			Social.change(npc, 5.0 if quality >= 75 else -2.0, 4.0, "repair_" + str(Game.day()), "Brannoc mended my %s %s." % [it.get("name", "gear"), "beautifully" if quality >= 95 else "well enough"])
			Game.grant_player_xp("smithing", 10)
			remove_customer(npc)
			return
		if c["npc"] == npc and c["want"] == "repair":
			var pay := int(round(float(c["pay"]) * (0.5 + quality / 100.0 * 0.7)))
			Game.add_gold(pay, "repairs", "Repaired %s's %s" % [DB.character(npc)["name"], c["item"]["name"]])
			Social.change(npc, 4.0 if quality >= 75 else -2.0, 4.0, "repair_" + str(Game.day()),
				"Mended my %s %s." % [c["item"]["name"], "beautifully" if quality >= 95 else ("well enough" if quality >= 75 else "poorly")])
			Game.grant_player_xp("smithing", 8)
			remove_customer(npc)
			return


# ------------------------------------------------------------------ special orders
static func orders() -> Array:
	return Game.state["orders"]


static func open_orders() -> Array:
	return orders().filter(func(o): return o["status"] == "open")


## Creates a commission from an adventurer for their weakest slot.
static func create_order(npc: String, slot := "", note := "") -> Dictionary:
	var a := Adv.get_a(npc)
	if a.is_empty() or refuses(npc):
		return {}
	if slot == "":
		slot = Adv._weakest_slot(a)
	var stat := "attack" if slot == "weapon" else ("magic" if slot in ["ring", "amulet"] else "protection")
	var current := Items.stat(a["equipment"].get(slot, {}), stat)
	var need: int = maxi(current + 2, int(a["level"]) * 2 + 4)
	# what the next trip demands: a damage type its threats fear, a better metal for veterans
	var prop := str(a.get("wants_prop", ""))
	var tier := 2 if int(a["level"]) >= 5 and slot in ["weapon", "armor", "shield"] else 1
	if prop != "" and slot == "weapon":
		stat = prop
		need = 3 + int(a["level"]) / 3
	# never ask for more than any craftable piece for that slot can give (found by the integrity suite)
	need = mini(need, slot_ceiling(slot, stat))
	var dest_name: String = DB.destinations.get(a.get("next_dest", ""), {}).get("name", "")
	if note == "" and dest_name != "":
		note = "For %s%s." % [dest_name, (" — they say the things there fear " + prop) if prop != "" else ""]
	var o := {"id": "ord_%d" % Game.new_uid(), "npc": npc, "slot": slot, "stat": stat, "min": need, "tier": tier,
		"reward": 40 + int(a["level"]) * 18 + need * 3 + (30 if tier >= 2 else 0) + (25 if prop != "" else 0), "deadline": Game.day() + 3, "status": "open", "note": note,
		"placed": Game.day()}
	_set_priority(o, a)
	orders().append(o)
	Events.orders_changed.emit()
	Events.toast.emit("New commission from %s: %s." % [a["name"], order_text(o)], "info")
	return o


## Every commission has a priority (what the customer cares about most) and a bonus objective.
## quality: pays more, and a bonus for fine craftsmanship · speed: a short deadline, a bonus for
## delivering by the next day · cost: a thin purse, but the customer remembers the favour.
const PRIORITY := {
	"quality": {"name": "Quality first", "desc": "pays well; bonus for craftsmanship of 75% or more"},
	"speed": {"name": "Needed fast", "desc": "short deadline; bonus if delivered by tomorrow"},
	"cost": {"name": "Tight purse", "desc": "less coin, but they will not forget the kindness"},
}


static func _set_priority(o: Dictionary, a: Dictionary) -> void:
	var risk := float(a.get("risk", 0.5))
	var r := randf()
	var pri := "speed" if r < 0.2 + risk * 0.2 else ("cost" if int(a.get("gold", 0)) < 60 and r < 0.75 else "quality")
	o["priority"] = pri
	match pri:
		"quality":
			o["reward"] = int(o["reward"] * 1.2)
			o["bonus"] = {"kind": "fine", "min": 75, "gold": 30 + int(a.get("level", 1)) * 5, "text": "craftsmanship 75%+"}
		"speed":
			o["deadline"] = Game.day() + 2
			o["bonus"] = {"kind": "early", "by": Game.day() + 1, "gold": 25 + int(a.get("level", 1)) * 4, "text": "delivered by day %d" % (Game.day() + 1)}
		"cost":
			o["reward"] = int(o["reward"] * 0.7)
			o["bonus"] = {"kind": "rare", "gold": 20, "rel": 10.0, "text": "rare quality or better (they will remember it)"}


static func bonus_met(o: Dictionary, it: Dictionary) -> bool:
	var b: Dictionary = o.get("bonus", {})
	match str(b.get("kind", "")):
		"fine":
			return float(it.get("craft", {}).get("quality", 0.0)) >= float(b.get("min", 75))
		"early":
			return Game.day() <= int(b.get("by", 0))
		"rare":
			return it.get("rarity", "") in ["rare", "legendary", "unique", "set"]
	return false


static func item_meets(o: Dictionary, it: Dictionary) -> bool:
	return Items.slot(it) == o["slot"] and Items.stat(it, o["stat"]) >= int(o["min"]) and Items.tier(it) >= int(o.get("tier", 1))


static func order_text(o: Dictionary) -> String:
	return "%s with %s ≥ %d%s" % [o["slot"], o["stat"], int(o["min"]), (", " + Items.TIER_WORD[int(o["tier"])]) if int(o.get("tier", 1)) >= 2 else ""]


static func order_terms(o: Dictionary) -> String:
	var p: Dictionary = PRIORITY.get(o.get("priority", ""), {})
	if p.is_empty():
		return ""
	return "%s — %s. Bonus: %s (+%d g)" % [p["name"], p["desc"], o.get("bonus", {}).get("text", ""), int(o.get("bonus", {}).get("gold", 0))]


static func fulfil(order_id: String, uid: int) -> String:
	for o in orders():
		if o["id"] != order_id or o["status"] != "open":
			continue
		var it := Game.find_uid(uid)
		if it.is_empty() or not item_meets(o, it):
			return "That doesn't meet the order."
		it = Game.take_uid(uid)
		it.erase("for_sale")
		var a := Adv.get_a(o["npc"])
		var margin := Items.stat(it, o["stat"]) - int(o["min"])
		var bonus := int(margin * 4 + (40 if it.get("rarity") in ["rare", "legendary", "unique", "set"] else 0))
		var reward := int(o["reward"]) + bonus
		var got_bonus := bonus_met(o, it)
		if got_bonus:
			reward += int(o["bonus"].get("gold", 0))
			Social.change(o["npc"], float(o["bonus"].get("rel", 4.0)), 4.0, "bonus_" + o["id"], "Brannoc did better than I asked: %s." % o["bonus"].get("text", ""))
			Events.toast.emit("Bonus objective met — %s (+%d g)." % [o["bonus"].get("text", ""), int(o["bonus"].get("gold", 0))], "good")
		o["bonus_met"] = got_bonus
		o["delivered_uid"] = int(it["uid"])
		Items.add_history(it, "Commissioned by %s (%s)." % [a["name"], PRIORITY.get(o.get("priority", ""), {}).get("name", "commission")])
		Chronicle.add("commission", "Brannoc delivered %s's commission: %s%s." % [a["name"], Items.display_name(it), " — and beat the bonus" if got_bonus else ""], {"adv": o["npc"], "uid": int(it["uid"])})
		if Social.spouse() == o["npc"]:
			reward = 0
		else:
			a["gold"] = maxi(0, int(a["gold"]) - reward / 2)   # the village/guild covers the rest
		Adv.give_item(a, it, 0)
		if reward > 0:
			Game.add_gold(reward, "commissions", "Commission for %s" % a["name"])
		o["status"] = "done"
		Social.change(o["npc"], 10.0 + margin, 8.0, "order_" + o["id"], "Brannoc delivered my %s, and it was %s." % [it["name"], "superb" if margin >= 4 else "as promised"])
		# exceptional work is sometimes rewarded with something rare
		if margin >= 5 or it.get("rarity") in ["legendary", "rare"]:
			Game.state["returns"].append(Loot.make_container("package_reward", Loot.roll_table("reward", 10.0), a["name"],
				"%s left this for you: 'Work like yours deserves more than coin.'" % a["name"]))
			Events.inventory_changed.emit()   # world redraws the waiting bags
			Events.toast.emit("%s left you a reward package in the workshop!" % a["name"], "good")
		Events.orders_changed.emit()
		Objectives.on_sold(o["npc"], it)
		if o["npc"] == "mira":
			Sim.on_mira_equipped(it, reward)
		return ""
	return "Order not found."


static func expire_orders() -> void:
	for o in orders():
		if o["status"] == "open" and Game.day() > int(o["deadline"]):
			o["status"] = "expired"
			Social.change(o["npc"], -8.0, 2.0, "order_missed_" + o["id"], "The smith never delivered what I ordered.")
	Events.orders_changed.emit()


## Buys a workshop upgrade from the ledger ("" = done). Same rules as the ledger shows.
static func buy_upgrade(id: String) -> String:
	var u: Dictionary = DB.upgrades.get(id, {})
	if u.is_empty():
		return "No such upgrade."
	if Game.has_upgrade(id):
		return "Already installed."
	var r: Dictionary = u.get("requires", {})
	if r.has("skill") and Game.player_level(r["skill"][0]) < int(r["skill"][1]):
		return "Needs %s %d." % [SkillSys.skill_name(r["skill"][0]), int(r["skill"][1])]
	if r.has("flag") and not Game.has_flag(r["flag"]):
		return "Needs mithril in your stores first."
	if not Game.can_afford(int(u["cost"])):
		return "You cannot afford it."
	Game.add_gold(-int(u["cost"]), "upgrades", u["name"])
	(Game.state["upgrades"] as Array).append(id)
	if id == "arcane_foundry":
		var sk := Game.player_skills()
		if SkillSys.level(sk, "arcane_metalwork") < 1:
			sk["arcane_metalwork"]["lvl"] = 1
		Game.journal("The Arcane Foundry hums into life. The leyline answers.")
	Events.world_flag_changed.emit("upgrade_" + id)
	Events.toast.emit("Upgrade installed: " + str(u["name"]), "good")
	Audio.play("sfx/level_up", -6.0)
	return ""


## The best a well-made craftable piece for `slot` reaches in `stat` (item range top × 1.2 for craftsmanship).
static func slot_ceiling(slot: String, stat: String) -> int:
	var best := 1
	for r in DB.recipes.values():
		var d := DB.item(str(r["output"]))
		if str(d.get("slot", "")) != slot:
			continue
		var v: Variant = d.get("stats", {}).get(stat, 0)
		var top := float(v[1]) if v is Array else float(v)
		best = maxi(best, int(floor(top * 1.2)))
	return best
