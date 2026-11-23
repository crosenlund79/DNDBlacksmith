## Rendered play-test phase "harbour_captains" (R7 "Negotiation & Procurement"): Skipper Durra Coalbrow brings the ore
## barge in — her first visit; the smith commissions a voyage for steel; she sails; the cargo lands on its day and is
## paid in full; on her next visit she remembers the payment and her terms are better; the hirelings' ledger offers an
## escort priced on the road's danger. Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.wait(0.7)
	await pt.shot(name)


func _dock(type: String, idx: int) -> void:
	var nm: Array = Trade.ship_type(type)["names"][idx]
	if not Trade.current_ship().is_empty():
		Trade._depart()
	Trade._dock(type, str(nm[0]), str(nm[1]))


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Game.state["gold"] = 6000
	Trade.mark_seen("ingot_steel")
	Trade.mark_seen("ore_silver")
	_dock("barge", 0)
	var c := Captains.in_port()
	pt.expect(str(c.get("name", "")) == "Skipper Durra Coalbrow", "harbour_captains: Skipper Durra Coalbrow is in port")
	Events.open_panel.emit("harbour", {"tab": "captains"})
	await _shot("harbour_captains_first_visit")
	pt.expect(pt.panel() is HarbourPanel and pt.panel().find_child("CaptainInPort", true, false) != null, "harbour_captains: the Captains tab shows her")
	await pt.close_panel()
	var q1 := Captains.quote(str(c["id"]), "ingot_steel", 4)
	pt.expect(Captains.commission("ingot_steel", 4, int(q1["deposit"])) == "", "harbour_captains: a voyage for 4 steel ingots is agreed")
	var v: Dictionary = Captains.voyages(str(c["id"]))[0]
	Trade._depart()
	pt.expect(str(v["status"]) == "at_sea", "harbour_captains: she sailed with the order")
	Captains.force[str(v["id"])] = "success"
	for i in 12:
		if str(v["status"]) != "at_sea":
			break
		Game.advance_minutes(1440)
	await pt.wait(0.8)
	pt.expect(str(v["status"]) == "arrived", "harbour_captains: the cargo landed")
	Events.open_panel.emit("harbour", {"tab": "captains"})
	await _shot("harbour_captains_landed")
	await pt.close_panel()
	pt.expect(Captains.collect(str(v["id"])) == "", "harbour_captains: paid in full and collected")
	_dock("barge", 0)
	Events.open_panel.emit("harbour", {"tab": "captains"})
	await _shot("harbour_captains_she_remembers")
	var g: Node = pt.panel().find_child("Greeting", true, false) if pt.panel() != null else null
	pt.expect(g != null and str((g as RichTextLabel).text).contains("paid in full"), "harbour_captains: on her next visit she remembers the payment")
	await pt.close_panel()
	var q2 := Captains.quote(str(c["id"]), "ingot_steel", 4)
	pt.expect(int(q2["unit"]) < int(q1["unit"]), "harbour_captains: and her price is better (%d < %d g)" % [int(q2["unit"]), int(q1["unit"])])
	# the escort offer in the hirelings' ledger
	Events.open_panel.emit("hirelings", {})
	await _shot("harbour_captains_escort_offer")
	var found := false
	if pt.panel() != null:
		for n in pt.panel().find_children("Escort_*", "OptionButton", true, false):
			if (n as OptionButton).item_count > 1:
				found = true
	pt.expect(found, "harbour_captains: an escort can be chosen for a hireling's run, with its price")
	await pt.close_panel()
