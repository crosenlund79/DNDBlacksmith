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
	return maxi(1, p)


static func customers() -> Array:
	return Game.state["customers"]


const SEATS := 4


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
	if free_seat() < 0 or randf() > 0.45:
		return
	var pool := []
	for a in Adv.in_town():
		pool.append([a["id"], "browse"])
	for v in ["martha", "tobin", "jory", "eda", "oswin", "wenna"]:
		pool.append([v, "repair"])
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
	customers().append(c)
	Events.customers_changed.emit()


## Called by the world when the customer's figure reaches its seat. Announces them once.
static func mark_arrived(npc: String, notify := true) -> void:
	for c in customers():
		if c["npc"] == npc and not c.get("present", false):
			c["present"] = true
			c["seated"] = Game.day() * 24 + Game.hour()
			if notify:
				Audio.play("sfx/door_bell", -4.0)
				Events.toast.emit("%s is waiting outside the shop." % DB.character(npc).get("name", npc), "info")
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
	Adv.give_item(a, it, price)
	if not married:
		Game.add_gold(price, "sales", "Sold %s to %s" % [it["name"], a["name"]])
	Game.state["stats"]["sold"] += 1
	remove_customer(npc)
	Objectives.on_sold(npc, it)
	if npc == "mira":
		Sim.on_mira_equipped(it, price)
	return ""


static func do_repair(npc: String, quality: float) -> void:
	for c in customers():
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
	if a.is_empty():
		return {}
	if slot == "":
		slot = Adv._weakest_slot(a)
	var stat := "attack" if slot == "weapon" else ("magic" if slot in ["ring", "amulet"] else "protection")
	var current := Items.stat(a["equipment"].get(slot, {}), stat)
	var need: int = maxi(current + 2, int(a["level"]) * 2 + 4)
	var o := {"id": "ord_%d" % Game.new_uid(), "npc": npc, "slot": slot, "stat": stat, "min": need,
		"reward": 40 + int(a["level"]) * 18 + need * 3, "deadline": Game.day() + 3, "status": "open", "note": note}
	orders().append(o)
	Events.orders_changed.emit()
	Events.toast.emit("New commission from %s: %s with %s ≥ %d." % [a["name"], slot, stat, need], "info")
	return o


static func item_meets(o: Dictionary, it: Dictionary) -> bool:
	return Items.slot(it) == o["slot"] and Items.stat(it, o["stat"]) >= int(o["min"])


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
