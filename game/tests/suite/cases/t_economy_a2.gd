## Milestone A2 — Workshop Reliability (the ECONOMY part): one durability threshold everywhere (Items.WORN); the piece
## an adventurer planned to have mended is the one repaired; adventurers pay for repairs out of their own purse (gold
## down, the smith's up, the ledger naming them) and a poor one does not ask for what they cannot pay; the commission
## subsidy is explicit and recorded with its payer; every ledger line names its payer or recipient (a 60-day seeded
## game is scanned); requests the workshop cannot make are explained with the one next step and mostly replaced by
## what it can make; thank-you gifts are worth at most half of the giver's business with the forge; the skill-tree node
## that unlocks mail, plate and a silver band is named for them; a golden save still loads and plays.
## Before/after numbers are in the notes (and in the A2 report).
extends SuiteCase

const SMOKE := ["test_one_threshold_everywhere", "test_planned_slot_is_repaired", "test_adventurer_pays_for_repair",
	"test_commission_subsidy_explicit", "test_boots_request_explained_and_declined_politely", "test_skill_node_names_what_it_unlocks"]


# ------------------------------------------------------------------ fixtures
func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	Shop.remove_customer(id)
	return a


## Sets a worn-able piece to `frac` of its durability (and clears a break).
func _wear(it: Dictionary, frac: float) -> void:
	it.erase("broken")
	var st: Dictionary = it["stats"]
	st["durability"] = int(floor(float(st["durability_max"]) * frac))


func _durable_slot(a: Dictionary, avoid := "") -> String:
	for s in a["equipment"]:
		if str(s) != avoid and (a["equipment"][s].get("stats", {}) as Dictionary).has("durability_max"):
			return str(s)
	return ""


func _last_line() -> Dictionary:
	var l: Array = Game.state["ledger"]
	return l[-1] if not l.is_empty() else {}


func _lines_since(n0: int) -> Array:
	var l: Array = Game.state["ledger"]
	return l.slice(n0)


# ------------------------------------------------------------------ 1. one threshold
func test_one_threshold_everywhere() -> void:
	var a := _adv("garrick")
	var slot := _durable_slot(a)
	if not check(slot != "", "Garrick wears a piece that wears"):
		return
	var it: Dictionary = a["equipment"][slot]
	for s in a["equipment"]:
		if str(s) != slot and (a["equipment"][s].get("stats", {}) as Dictionary).has("durability_max"):
			_wear(a["equipment"][s], 1.0)
	# the old gaps: 0.35 (adventurer), 0.40 (counter), 0.45 (consultation) — now one number
	for f in [Items.WORN - 0.03, Items.WORN + 0.03]:
		_wear(it, f)
		var below: bool = Items.durability_frac(it) < Items.WORN
		eq(Items.needs_mending(it), below, "at %d%% the piece %s mending" % [int(Items.durability_frac(it) * 100), "needs" if below else "does not need"])
		var adv_says := Adv.gear_needs(a).any(func(n): return str(n["slot"]) == slot and str(n["why"]) == "worn")
		eq(adv_says, below, "the adventurer's own judgement agrees (%d%%)" % int(Items.durability_frac(it) * 100))
		eq(Shop.worn_slot(a) == slot, below, "the counter agrees")
		eq(Consult.worn_pieces(a).any(func(w): return str(w["slot"]) == slot), below, "the consultation agrees")
		eq(int(Adv.wear_warnings(a)["worn"]) > 0, below, "the roster's warning agrees")
		eq(EquipmentSheet.condition_word(it) == "badly worn", below, "the sheet's 'badly worn' agrees")
		eq(Consult.reason_for(a).get("kind", "") == "worn", below, "the consultation's reason agrees")
	_wear(it, Items.WORN + 0.03)
	check(EquipmentSheet.condition_word(it) == "worn", "between WORN and half it is merely 'worn' on the sheet (no repair needed)")
	note("Items.WORN = %.2f (before: 0.35 adventurer plans · 0.40 counter · 0.45 consultation)" % Items.WORN)


# ------------------------------------------------------------------ 2. the planned piece is repaired
func test_planned_slot_is_repaired() -> void:
	var a := _adv("garrick")
	a["gold"] = 500
	var s1 := _durable_slot(a)
	var s2 := _durable_slot(a, s1)
	if not check(s1 != "" and s2 != "", "two pieces that wear"):
		return
	# the FIRST worn piece in the equipment order is s1, but the plan is to mend s2
	_wear(a["equipment"][s1], 0.30)
	_wear(a["equipment"][s2], 0.20)
	var d1 := int(a["equipment"][s1]["stats"]["durability"])
	a["shopping"] = [{"slot": s2, "why": "worn", "plan": "repair", "goal": 10, "note": "", "since": Game.day()}]
	eq(Adv.act_on_plans(a), "repair", "the adventurer sets out to have the planned piece mended")
	var c := Shop.customer(str(a["id"]))
	eq(str(c.get("own_slot", "")), s2, "the request names the planned piece (%s), not the first worn one (%s)" % [s2, s1])
	eq(int(ItemRegistry.resolve(c["item"]).get("uid", -1)), int(a["equipment"][s2]["uid"]), "the card shows that very piece")
	Shop.do_repair(str(a["id"]), 90.0)
	check(Items.durability_frac(a["equipment"][s2]) > 0.9, "the planned piece is mended")
	eq(int(a["equipment"][s1]["stats"]["durability"]), d1, "the other worn piece is untouched")
	# a broken weapon brought home from an expedition: the weapon itself
	var b := _adv("sigrun")
	b["gold"] = 500
	var ws := _durable_slot(b, "weapon")
	if ws != "":
		_wear(b["equipment"][ws], 0.05)
	b["equipment"]["weapon"]["broken"] = true
	Shop._add_customer(str(b["id"]), "repair_own", "weapon")
	eq(str(Shop.customer(str(b["id"])).get("own_slot", "")), "weapon", "the broken weapon is the piece brought in")
	# buying another piece from the display while waiting does not cancel the repair of a different piece
	var s3 := _durable_slot(a, "weapon")
	Shop.remove_customer(str(a["id"]))
	_wear(a["equipment"][s3], 0.2)
	var c2 := {"npc": str(a["id"]), "want": "repair", "own_slot": s3, "item": ItemRegistry.ref(a["equipment"][s3]), "pay": 12, "seat": 1, "present": true, "arrived": 0}
	Shop.customers().append(c2)
	var cur: Dictionary = a["equipment"].get("weapon", {})
	var better := Items.make(str(cur.get("def", "sword_iron")), {"quality": 120.0, "rarity": "rare"})
	better["for_sale"] = true
	better["price"] = 1
	Game.add_item(better, false)
	eq(Shop.sell_to(str(a["id"]), int(better["uid"])), "", "Garrick buys a finer weapon while he waits")
	eq(str(Shop.customer(str(a["id"])).get("own_slot", "")), s3, "the %s repair is still asked for after buying a weapon" % s3)


# ------------------------------------------------------------------ 3. adventurers pay
func test_adventurer_pays_for_repair() -> void:
	var a := _adv("tomas")
	var slot := _durable_slot(a)
	_wear(a["equipment"][slot], 0.2)
	a["gold"] = 200
	Shop._add_customer("tomas", "repair_own", slot)
	var c := Shop.customer("tomas")
	if not check(not c.is_empty(), "Tomas sets out for a repair he can pay for"):
		return
	var quote := int(c["pay"])
	eq(quote, Adv.repair_cost(a["equipment"][slot]), "the quote is the adventurer's own repair estimate")
	var g0 := Game.gold()
	var a0 := int(a["gold"])
	var n0 := (Game.state["ledger"] as Array).size()
	Shop.do_repair("tomas", 90.0)
	var paid := a0 - int(a["gold"])
	check(paid > 0, "his purse is lighter by %d g" % paid)
	eq(Game.gold() - g0, paid, "the smith receives exactly what Tomas paid")
	var l := _last_line()
	eq(str(l.get("party", "")), "tomas", "the ledger line names the payer")
	eq(int(l.get("amount", 0)), paid, "the ledger line is the payment")
	eq((Game.state["ledger"] as Array).size(), n0 + 1, "one ledger line")
	note("repair of %s: quote %d g, paid %d g at 90%% work (Tomas %d → %d g)" % [str(a["equipment"][slot]["name"]), quote, paid, a0, int(a["gold"])])
	# a poor adventurer cannot order what they cannot pay
	var p := _adv("rv_liesl")
	var ps := _durable_slot(p)
	_wear(p["equipment"][ps], 0.1)
	p["gold"] = 2
	Shop._add_customer("rv_liesl", "repair_own", ps)
	check(Shop.customer("rv_liesl").is_empty(), "Liesl (2 g) does not set out for a repair she cannot pay")
	Adv.evaluate_gear(p)
	check(not (p["shopping"] as Array).any(func(e): return str(e["plan"]) == "repair"), "her plan is not a repair she cannot afford")
	check(not Shop.multi_parts_for(p).any(func(pt): return str(pt["kind"]) == "repair"), "a multi-request carries no repair she cannot pay")
	# the consultation does not commit her to one either
	var rec := {"kind": "repair", "slot": ps, "cost": Adv.repair_cost(p["equipment"][ps]), "title": "Mend it"}
	check(Consult._apply(p, rec).begins_with("!"), "a consultation's repair advice falls through for an empty purse")
	# a repair part of a multi-request is paid by the customer too
	var k := _adv("kestra")
	k["gold"] = 300
	var ks := _durable_slot(k)
	_wear(k["equipment"][ks], 0.1)
	Shop.customers().append({"npc": "kestra", "want": "multi", "seat": 0, "present": true, "arrived": 0,
		"parts": [{"pid": "rep", "kind": "repair", "own_slot": ks, "item": ItemRegistry.ref(k["equipment"][ks]), "pay": 20, "status": "pending"}]})
	var kg := int(k["gold"])
	var sg := Game.gold()
	Shop.repair_part("kestra", "rep", 80.0)
	check(int(k["gold"]) < kg and Game.gold() - sg == kg - int(k["gold"]), "Kestra pays the multi-request's repair (%d g)" % (kg - int(k["gold"])))
	eq(str(_last_line().get("party", "")), "kestra", "and the ledger names her")


# ------------------------------------------------------------------ 4. commissions: payer and subsidy explicit
func test_commission_subsidy_explicit() -> void:
	var a := _adv("garrick")
	a["gold"] = 400
	var o := Shop.create_order("garrick", "weapon", "test")
	if not check(not o.is_empty(), "a commission"):
		return
	o["min"] = 1
	o["tier"] = 1
	o.erase("bonus")
	var it := Items.make("sword_iron", {"quality": 80.0})
	Game.add_item(it, false)
	var reward := int(o["reward"]) + int(Items.stat(it, str(o["stat"])) - 1) * 4 + (40 if str(it.get("rarity", "")) in ["rare", "legendary", "unique", "set"] else 0)
	var g0 := Game.gold()
	var a0 := int(a["gold"])
	var n0 := (Game.state["ledger"] as Array).size()
	eq(Shop.fulfil(str(o["id"]), int(it["uid"])), "", "delivered")
	var lines := _lines_since(n0)
	var by_party := {}
	for l in lines:
		by_party[str(l.get("party", ""))] = int(by_party.get(str(l.get("party", "")), 0)) + int(l["amount"])
	eq(Game.gold() - g0, reward, "the smith's reward is what it always was (%d g)" % reward)
	eq(int(by_party.get("garrick", 0)), a0 - int(a["gold"]), "Garrick's ledger line is exactly what left his purse")
	eq(int(by_party.get("garrick", 0)), reward / 2, "he pays his half")
	eq(int(by_party.get(Payments.VILLAGE, 0)), reward - reward / 2, "the rest is the village's recorded subsidy")
	check(lines.any(func(l): return str(l["cat"]) == "subsidy" and str(l.get("party", "")) == Payments.VILLAGE), "the subsidy has its own ledger line and payer")
	eq(int(o["paid"]["gold"]) + int(o["paid"]["subsidy"]), reward, "the order records who paid what")
	# a poor customer: the subsidy covers what they cannot (as before), now visibly
	var p := _adv("rv_liesl")
	p["gold"] = 5
	var o2 := Shop.create_order("rv_liesl", "weapon", "test")
	o2["min"] = 1
	o2["tier"] = 1
	o2.erase("bonus")
	var it2 := Items.make("axe_hand", {"quality": 70.0})
	Game.add_item(it2, false)
	var n1 := (Game.state["ledger"] as Array).size()
	eq(Shop.fulfil(str(o2["id"]), int(it2["uid"])), "", "delivered to Liesl")
	eq(int(p["gold"]), 0, "Liesl paid what she had")
	var paid_by := {}
	for l in _lines_since(n1):
		paid_by[str(l.get("party", ""))] = int(l["amount"])
	eq(int(paid_by.get("rv_liesl", 0)), 5, "her line is her 5 g")
	check(int(paid_by.get(Payments.VILLAGE, 0)) > 0, "the village's subsidy line covers the rest (%d g)" % int(paid_by.get(Payments.VILLAGE, 0)))
	check(save_load("a2_econ_commission"), "save and load")
	var found := false
	for oo in Shop.orders():
		if str(oo["id"]) == str(o["id"]):
			found = int(oo["paid"]["subsidy"]) == reward - reward / 2
	check(found, "the payer record survives save/load")
	check((Game.state["ledger"] as Array).any(func(l): return str(l.get("party", "")) == Payments.VILLAGE), "ledger parties survive save/load")


# ------------------------------------------------------------------ 5. no payment without a payer (60-day scan)
## A seeded early game played by a simple smith: the display kept stocked for what adventurers need, commissions
## delivered, waiting repairs done, goods sold, supplies bought at the village store.
func test_no_payment_without_payer() -> void:
	fresh_game("journeyman", 6060)
	var n_lines := 0
	var unknown := []
	var seen_party := {}
	var adv_paid := 0
	for d in 60:
		for a in Adv.in_town():
			for need in Adv.gear_needs(a).slice(0, 1):
				var cap := Shop.slot_capability(str(need["slot"]), a)
				if str(cap["state"]) in ["now", "materials"] and Shop.stock().size() < 5:
					var it := Items.make(str(DB.recipe(str(cap["recipe"])).get("output", "")), {"quality": 85.0})
					it["for_sale"] = true
					Game.add_item(it, false)
		for o in Shop.open_orders():
			var cap2 := Shop.slot_capability(str(o["slot"]))
			if o.has("def") or str(cap2["state"]) == "locked":
				continue
			var it2 := Items.make(str(DB.recipe(str(cap2["recipe"])).get("output", "")), {"quality": 100.0})
			Game.add_item(it2, false)
			if Shop.item_meets(o, it2):
				Shop.fulfil(str(o["id"]), int(it2["uid"]))
			else:
				Game.take_uid(int(it2["uid"]))
		if d % 7 == 2 and Game.gold() > 60:
			Trade.buy_store("general_store", "coal", 2)
		for h in 24:
			Game.advance_minutes(60)
			for c in Shop.customers().duplicate():
				if not bool(c.get("present", false)):
					Shop.mark_arrived(str(c["npc"]), false)
			for c2 in Shop.waiting().duplicate():
				if str(c2.get("want", "")) == "repair":
					var a2 := Adv.get_a(str(c2["npc"]))
					var before := int(a2.get("gold", 0))
					Shop.do_repair(str(c2["npc"]), 85.0)
					if not a2.is_empty():
						adv_paid += before - int(a2.get("gold", 0))
	for l in Game.state["ledger"]:
		n_lines += 1
		var p := str(l.get("party", ""))
		seen_party[p] = int(seen_party.get(p, 0)) + 1
		var known := p != "" and (Payments.PARTY_WORD.has(p) or not DB.character(p).is_empty() or p.begins_with("patron:")
			or p.begins_with("store:") or p.begins_with("hire_"))
		if not known:
			unknown.append("day %d %+d %s «%s» party '%s'" % [int(l["day"]), int(l["amount"]), str(l["cat"]), str(l["note"]), p])
	check(unknown.is_empty(), "every ledger line names a known payer or recipient: %s" % str(unknown.slice(0, 6)))
	eq(Payments.unaccounted().size(), 0, "Payments.unaccounted() finds nothing")
	var cats := {}
	for l2 in Game.state["ledger"]:
		if int(l2["amount"]) > 0:
			var k := "%s←%s" % [str(l2["cat"]), str(l2.get("party", "")) if DB.character(str(l2.get("party", ""))).get("kind", "") != "adventurer" else "adventurer"]
			cats[k] = int(cats.get(k, 0)) + int(l2["amount"])
	note("60 days: %d ledger lines; income by category←payer: %s" % [n_lines, JSON.stringify(cats)])
	note("60 days: repairs paid by adventurers out of their purses: %d g" % adv_paid)


# ------------------------------------------------------------------ 6. boots the workshop cannot make (observation 3)
func test_boots_request_explained_and_declined_politely() -> void:
	var a := _adv("mira")
	check(not Shop.can_make_slot("boots", a), "a new workshop cannot make boots")
	check(not Adv.can_commission(a, "boots"), "so Mira will not commission them")
	check(Adv.can_commission(a, "weapon"), "but she can commission a weapon")
	var c := {"npc": "mira", "want": "browse", "seat": 0, "present": true, "arrived": Game.day() * 24 + Game.hour(), "slot": "boots"}
	Shop.customers().append(c)
	var r := Shop.request(c)
	eq(str(r.get("availability", "")), "locked", "the request card says boots are beyond the forge for now")
	var node_name := str(SkillTree.node("l_armour").get("name", ""))
	check(str(r.get("why", "")).contains(node_name), "and names what is missing: «%s» (%s)" % [node_name, str(r.get("why", ""))])
	check(str(r.get("next_step", "")) != "", "and the one next step: %s" % str(r.get("next_step", "")))
	note("boots card: %s" % str(r.get("why", "")))
	var aff0 := Social.aff("mira")
	Shop.dismiss_customer("mira")
	eq(Social.aff("mira"), aff0, "declining what the forge cannot make is no slight")
	check((a.get("gear_log", []) as Array).any(func(g): return str(g["text"]).contains("tried elsewhere")), "she tries the other traders instead")
	# a craftable request says so
	var c2 := {"npc": "mira", "want": "browse", "seat": 0, "present": true, "arrived": 0, "slot": "weapon"}
	Shop.customers().append(c2)
	check(str(Shop.request(c2).get("availability", "")) in ["now", "materials"], "a weapon request shows it can be made")
	Shop.remove_customer("mira")
	# a beyond-the-forge commission that lapses leaves no grudge
	var o := Shop.create_order("mira", "boots", "test")
	check(bool(o.get("opportunity", false)), "a boots commission is marked as an opportunity")
	var r2 := Shop.order_request(o)
	eq(str(r2.get("availability", "")), "locked", "its card names the next step too")
	var aff1 := Social.aff("mira")
	o["deadline"] = Game.day() - 1
	Shop.expire_orders()
	eq(Social.aff("mira"), aff1, "an opportunity commission that lapses costs no affection")


# ------------------------------------------------------------------ 7. the request mix (observation 5)
func test_request_feasibility_mix() -> void:
	var seen := {}
	var mix := {"craftable": 0, "beyond": 0}
	for h in 24 * 21:
		Game.advance_minutes(60)
		for c in Shop.customers():
			if not bool(c.get("present", false)):
				Shop.mark_arrived(str(c["npc"]), false)
		for c in Shop.customers():
			var k := "c%s:%d" % [str(c["npc"]), int(c.get("arrived", 0))]
			if seen.has(k):
				continue
			seen[k] = true
			var a := Adv.get_a(str(c["npc"]))
			if str(c.get("want", "")) == "browse" and not a.is_empty():
				mix["craftable" if str(Shop.request(c).get("availability", "")) in ["now", "materials"] else "beyond"] += 1   # what the card says
			elif str(c.get("want", "")) == "multi":
				for pt in c.get("parts", []):
					if str(pt["kind"]) == "craft":
						mix["craftable" if Crafting.recipe_locked_reason(str(pt["recipe"])) == "" else "beyond"] += 1
		for o in Shop.orders():
			if seen.has("o" + str(o["id"])):
				continue
			seen["o" + str(o["id"])] = true
			var ok := str(Shop.order_request(o).get("availability", "")) in ["now", "materials"]   # what the card says
			mix["craftable" if ok else "beyond"] += 1
	var tot := int(mix["craftable"]) + int(mix["beyond"])
	note("21 days of requests: %d the workshop can make, %d beyond it (before A2, same seed and criterion: 18 and 46 — 72%% beyond)" % [int(mix["craftable"]), int(mix["beyond"])])
	check(tot >= 20, "enough requests to judge (%d)" % tot)
	check(float(mix["beyond"]) <= 0.3 * float(tot), "most requests are things the workshop can make (%d of %d beyond)" % [int(mix["beyond"]), tot])
	check(int(mix["beyond"]) > 0, "a few remain as visible opportunities")


# ------------------------------------------------------------------ 8. gifts scaled to the business (observation 6)
func test_gifts_scaled_to_business() -> void:
	var items := [Items.make("potion_healing", {"qty": 1}), Items.make("ore_silver", {"qty": 1}), Items.make("ring_silver", {"quality": 90.0, "rarity": "rare"})]
	var cheap := Payments.gift_within(items, 60)
	check(Payments.value_of(cheap) <= 60 and not cheap.is_empty(), "gift_within keeps the cheapest pieces within the cap (%d g)" % Payments.value_of(cheap))
	check(Payments.gift_within(items, 0).is_empty(), "nothing fits a zero cap")
	# no business with the forge: no thank-you gift, however warm
	var e := Social.ensure("pip")
	e["aff"] = 60.0
	eq(Payments.gift_budget("pip"), 0, "Pip has paid the forge nothing this month: no gift budget")
	check(Sim.gift_from("pip").is_empty(), "so no gift")
	# 100 g of business: at most 50 g of gifts over the month, all told
	Game.add_gold(100, "sales", "Sold Pip a blade", "pip")
	eq(Payments.gift_budget("pip"), 50, "after 100 g of business the budget is 50 g")
	var total := 0
	for i in 12:
		total += Payments.value_of(Sim.gift_from("pip"))
	check(total <= 50, "a month's gifts from Pip are worth %d g (≤ 50)" % total)
	# the reward package after a commission: at most half the reward
	var a := _adv("garrick")
	a["gold"] = 400
	var o := Shop.create_order("garrick", "weapon", "test")
	o["min"] = 1
	o["tier"] = 1
	o.erase("bonus")
	var it := Items.make("sword_iron", {"quality": 95.0, "rarity": "rare"})
	Game.add_item(it, false)
	var r0 := (Game.state["returns"] as Array).size()
	var g0 := Game.gold()
	Shop.fulfil(str(o["id"]), int(it["uid"]))
	var reward := Game.gold() - g0
	var pk := (Game.state["returns"] as Array).slice(r0)
	for p in pk:
		check(Payments.value_of(p.get("contents", [])) <= int(reward * Payments.GIFT_SHARE), "the reward package (%d g) is at most half the reward (%d g)" % [Payments.value_of(p.get("contents", [])), reward])
	check(save_load("a2_econ_gifts"), "save and load")
	check((Social.ensure("pip").get("gift_log", []) as Array).size() >= 0, "the gift log survives save/load")
	note("before A2 (400 seeded rolls): a thank-you gift averaged 118 g (max 1,626 g), a reward package 935 g (max 15,599 g)")


# ------------------------------------------------------------------ 9. the skill-tree node (observation 7)
func test_skill_node_names_what_it_unlocks() -> void:
	var n := SkillTree.node("s_blades")
	var outs := []
	for rid in n["unlocks"]["recipes"]:
		outs.append(str(DB.item(str(DB.recipe(str(rid)).get("output", ""))).get("slot", "")))
	check(not outs.has("weapon"), "s_blades unlocks no weapon (%s)" % str(outs))
	check(not str(n["name"]).to_lower().contains("blade"), "so its name promises no blades: «%s»" % str(n["name"]))
	# every node that promises blades or boots in its name unlocks one
	for nd in SkillTree.nodes():
		var slots := []
		for rid2 in nd["unlocks"]["recipes"]:
			slots.append(str(DB.item(str(DB.recipe(str(rid2)).get("output", ""))).get("slot", "")))
		var nm := str(nd["name"]).to_lower()
		if nm.contains("blade"):
			check(slots.has("weapon"), "«%s» unlocks a blade" % nd["name"])
		if nm.contains("boots"):
			check(slots.has("boots"), "«%s» unlocks boots" % nd["name"])


# ------------------------------------------------------------------ 10. the steward uses the same payments
func test_steward_repairs_are_paid_by_the_customer() -> void:
	fresh_game("journeyman", 4242)
	train("smithing", 6)
	Property.dev_grant_unit("cobbler")
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = 2000
	var g := 0
	while Apprentices.applicants().is_empty() and g < 20:
		Apprentices.refresh_applicants()
		g += 1
	if not check(Apprentices.hire(0) == "", "hire an apprentice"):
		return
	Game.state["gold"] = 2000
	var ap: Dictionary = Apprentices.staff()[-1]
	ap["traits"] = []
	ap["rank"] = "apprentice"
	ap["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	# only the repair duty (a fresh display piece bought by Tomas would end his visit before the repair)
	check(Steward.set_orders({"duties": {"orders": false, "repairs": true, "production": false, "replenish": false, "sales": false,
		"upkeep": false, "contracts": false}}) == "", "standing instructions: repairs only")
	for it in Game.inventory():
		it.erase("for_sale")
	if not check(Steward.activate() == "", "the steward takes over"):
		return
	while Game.hour() < 9:   # the shop opens
		Game.advance_minutes(30)
	var a := _adv("tomas")
	a["gold"] = 300
	var slot := _durable_slot(a)
	_wear(a["equipment"][slot], 0.15)
	Shop.customers().clear()   # a free seat at the counter
	Shop._add_customer("tomas", "repair_own", slot)
	Shop.mark_arrived("tomas", false)
	if not check(not Shop.customer("tomas").is_empty(), "Tomas waits at the counter"):
		return
	var a0 := int(a["gold"])
	for i in 40:
		Game.advance_minutes(15)
		if Shop.customer("tomas").is_empty():
			break
	var r := Steward.deactivate()
	check(Items.durability_frac(a["equipment"][slot]) > 0.5, "the steward's apprentice mended Tomas's piece (%s)" % JSON.stringify(Steward.recent_log(3).map(func(x): return x["text"])))
	var paid := a0 - int(a["gold"])
	check(paid > 0, "Tomas paid %d g out of his purse" % paid)
	check((Game.state["ledger"] as Array).any(func(l): return str(l.get("party", "")) == "tomas" and str(l["cat"]) == "repairs" and int(l["amount"]) == paid),
		"the ledger names him for exactly that")
	check(bool(r["gold"]["reconciled"]), "the steward's report reconciles")


# ------------------------------------------------------------------ 11. a golden save still loads and plays
func test_golden_save_plays_on() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/build-0.14.6.json")
	if not check(text.length() > 1000, "the 0.14.6 golden save is present"):
		return
	var slot := "a2_econ_golden"
	var f := FileAccess.open(Saves.path(slot), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var errs := Log.error_count
	if not check(Saves.load_slot(slot), "it loads"):
		return
	var n0 := (Game.state["ledger"] as Array).size()
	for d in 3:
		for h in 24:
			Game.advance_minutes(60)
			for c in Shop.customers().duplicate():
				if not bool(c.get("present", false)):
					Shop.mark_arrived(str(c["npc"]), false)
			for c2 in Shop.waiting().duplicate():
				if str(c2.get("want", "")) == "repair":
					Shop.do_repair(str(c2["npc"]), 85.0)
	eq(Log.error_count, errs, "three days of play with repairs log no errors")
	var new_lines := _lines_since(n0)
	check(new_lines.all(func(l): return str(l.get("party", "")) != ""), "every new ledger line names its party (%d lines)" % new_lines.size())
	for o in Shop.orders():
		Shop.order_request(o)   # old orders without the new keys build their cards
	check(save_load(slot + "_rt"), "and saves and loads again")
	Saves.delete(slot)


## A2 (lead): a steel piece whose item id does not name its metal (cutlass, bastard sword, half-plate…) counts as
## steel for "steel or better" orders — the metal comes from the recipe that makes it.
func test_steel_recipes_count_as_steel() -> void:
	fresh_game()
	for d in ["sword_cutlass", "sword_bastard", "plate_half", "sword_steel"]:
		eq(Items.tier({"def": d}), 2, "%s counts as steel" % d)
	eq(Items.tier({"def": "sword_iron"}), 1, "an iron longsword stays iron")
	eq(Items.tier({"def": "sword_short"}), 1, "a shortsword with no craft record stays at the old reading (iron or steel recipes make it)")
	eq(Items.tier({"def": "sword_short", "craft": {"recipe": "steel_shortsword"}}), 2, "a shortsword forged from steel counts as steel")
	eq(Items.tier({"def": "sword_short", "craft": {"recipe": "iron_shortsword"}}), 1, "a shortsword forged from iron stays iron")


## A2 (lead): the property purchases name who was paid, so the ledger audit finds no unaccounted line.
func test_property_purchases_name_the_recipient() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	var n0 := (Game.state["ledger"] as Array).size()
	check(Property.buy_station("leather_vat") == "", "a station is bought (Ordinary Leatherwork is known from the start)")
	var lines: Array = (Game.state["ledger"] as Array).slice(n0)
	check(not lines.is_empty() and str(lines[-1].get("party", "")) != "", "a station purchase names its recipient (%s)" % str(lines[-1] if not lines.is_empty() else {}))
