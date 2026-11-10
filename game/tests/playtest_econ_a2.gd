## Rendered play-test phase "a2econ" (Milestone A2 — the ECONOMY worker): what the player sees of the fixes.
## A Ranger asks at the counter for boots the new workshop cannot make: the request card says what is missing and the
## one next step; a craftable request says it can be made; the commissions board shows a boots opportunity beside a
## craftable commission; an adventurer's repair is paid from their purse and the ledger journal names them; a delivered
## commission shows the adventurer's share and the village subsidy as separate lines; the skill tree's renamed node.
## Called from tests/playtest.gd (phase_a2econ). Screenshots: a2econ_*.
extends RefCounted

var pt: Node


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	(Game.state["hirelings"] as Array).clear()
	Shop.customers().clear()
	# ---- 1. boots the workshop cannot make: the card explains and names the next step
	var mira := Adv.get_a("mira")
	mira["status"] = "in_town"
	Shop.customers().append({"npc": "mira", "want": "browse", "seat": 0, "present": true, "arrived": Game.day() * 24 + Game.hour(), "slot": "boots"})
	var r := Shop.request(Shop.customer("mira"))
	pt.expect(str(r.get("availability", "")) == "locked" and str(r.get("why", "")).contains("Skill Tree"), "a2econ: the boots card names the next step (%s)" % str(r.get("why", "")))
	Events.open_panel.emit("shop", {"tab": "customers", "npc": "mira"})
	await pt.wait(0.8)
	await pt.shot("a2econ_boots_card")
	await pt.close_panel()
	var aff0 := Social.aff("mira")
	Shop.dismiss_customer("mira")
	pt.expect(Social.aff("mira") == aff0, "a2econ: declining the boots costs no affection")
	# ---- 2. a request the workshop can make says so
	var sig := Adv.get_a("sigrun")
	sig["status"] = "in_town"
	Shop.customers().append({"npc": "sigrun", "want": "browse", "seat": 1, "present": true, "arrived": Game.day() * 24 + Game.hour(), "slot": "weapon"})
	Events.open_panel.emit("shop", {"tab": "customers", "npc": "sigrun"})
	await pt.wait(0.8)
	await pt.shot("a2econ_weapon_card")
	await pt.close_panel()
	Shop.remove_customer("sigrun")
	# ---- 3. the commissions board: an opportunity beside a craftable commission
	var o1 := Shop.create_order("mira", "boots", "For the Barrow Fields — if you can make them.")
	var kes := Adv.get_a("kestra")
	kes["status"] = "in_town"
	var o2 := Shop.create_order("kestra", "weapon", "")
	var o3 := Shop.create_order("sigrun", "weapon", "")   # a veteran asks for steel: beyond a new forge
	pt.expect(bool(o1.get("opportunity", false)) and not bool(o2.get("opportunity", false)) and bool(o3.get("opportunity", false)), "a2econ: boots and a veteran's steel are opportunities, an iron weapon is not")
	Events.open_panel.emit("orders", {})
	await pt.wait(0.8)
	await pt.shot("a2econ_orders")
	await pt.close_panel()
	# ---- 4. a repair paid from the adventurer's purse, the ledger names them
	var tom := Adv.get_a("tomas")
	tom["status"] = "in_town"
	tom["gold"] = 120
	var slot := ""
	for s in tom["equipment"]:
		if (tom["equipment"][s].get("stats", {}) as Dictionary).has("durability_max"):
			slot = str(s)
			break
	if slot != "":
		var st: Dictionary = tom["equipment"][slot]["stats"]
		st["durability"] = int(float(st["durability_max"]) * 0.3)
		Shop._add_customer("tomas", "repair_own", slot)
		Shop.mark_arrived("tomas", false)
		Events.open_panel.emit("shop", {"tab": "customers", "npc": "tomas"})
		await pt.wait(0.8)
		await pt.shot("a2econ_repair_request")
		await pt.close_panel()
		var g0 := int(tom["gold"])
		var s0 := Game.gold()
		Shop.do_repair("tomas", 90.0)
		pt.expect(g0 - int(tom["gold"]) == Game.gold() - s0 and Game.gold() > s0, "a2econ: Tomas paid %d g from his purse, the smith received the same" % (g0 - int(tom["gold"])))
	# ---- 5. a delivered commission: their share and the village's subsidy, two lines
	kes["gold"] = 200
	o2["min"] = 1
	o2["tier"] = 1
	var blade := Items.make("sword_iron", {"quality": 85.0})
	Game.add_item(blade, false)
	pt.expect(Shop.fulfil(str(o2["id"]), int(blade["uid"])) == "", "a2econ: Kestra's commission delivered")
	Events.open_panel.emit("shop", {"tab": "ledger"})
	await pt.wait(0.6)
	pt.click("Journal")
	await pt.wait(0.6)
	await pt.shot("a2econ_ledger_journal")
	pt.click("Accounts")
	await pt.wait(0.6)
	await pt.shot("a2econ_ledger_accounts")
	await pt.close_panel()
	pt.expect(Payments.unaccounted().is_empty(), "a2econ: every ledger line names its payer or recipient")
	# ---- 6. the renamed skill-tree node
	Events.open_panel.emit("skilltree", {"select": "s_blades"})
	await pt.wait(0.8)
	await pt.shot("a2econ_skilltree_node")
	await pt.close_panel()
