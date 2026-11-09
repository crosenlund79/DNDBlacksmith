## Rendered play-test phase "consult_rl" (The Living Realm 3b, consultations): Sigrun — broken blade, bound for the
## Barrow Fields with nothing that bites with fire — comes to the counter for advice; the world shows her seated
## with her question; the counter card; the dialogue; the consultation screen (question, threats, gear,
## 3–4 recommendations with odds in words), its details; an acceptance (she buys the fire blade on display) and a
## refusal (Varn, a reckless barbarian who will not turn back from Drake's Crag). Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot_panel(name: String) -> void:
	await pt.wait(0.5)
	await pt.shot(name)


## Picks a world seed for which today's roll for this advice satisfies `low` (accept) or not (refuse).
func _seed_roll(npc: String, rid: String, low: bool) -> void:
	for s in range(1, 400):
		Game.state["world_seed"] = s
		var x := Consult.roll(npc, rid)
		if (low and x < 0.3) or (not low and x > 0.85):
			return


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	await pt.advance_to(11, 0)
	# Sigrun: a broken sword, bound for the Barrow Fields, nothing that bites with fire
	var a := Adv.get_a("sigrun")
	Expeditions.ensure(a)
	a["status"] = "in_town"
	a["next_dest"] = "barrow_fields"
	a["gold"] = 900
	a["equipment"]["weapon"]["stats"]["durability"] = 0
	a["equipment"]["weapon"]["broken"] = true
	var armor: Dictionary = a["equipment"].get("armor", {})
	if not armor.is_empty():
		armor["stats"]["durability"] = int(int(armor["stats"]["durability_max"]) * 0.3)
	var blade := Items.make("sword_emberwarden", {"quality": 92.0})
	Provenance.forged(blade)
	blade["for_sale"] = true
	Game.add_item(blade, false)
	Social.change("sigrun", 30.0, 20.0, "", "", false)
	Shop.customers().clear()
	var cu := Consult.approach("sigrun")
	pt.expect(str(cu.get("want", "")) == "advice", "consult: Sigrun sets out for the counter to ask advice")
	pt.W()._update_schedules(true)
	await pt.wait(0.6)
	pt.expect(bool(Shop.customer("sigrun").get("present", false)), "consult: she is seated outside the shop")
	await pt.tp(pt.W().spots["wait_seat_0"] + Vector2(0, -170))
	await pt.wait(0.8)
	await pt.shot("consult_rl_at_counter")
	# the counter: her card
	Events.open_panel.emit("shop", {})
	await pt.wait(0.8)
	await pt.shot("consult_rl_shop_card")
	pt.expect(await pt.click("Hear them out", pt.panel()), "consult: the counter offers to hear her out")
	await pt.wait(0.8)
	pt.expect(pt.panel() is ConsultPanel, "consult: the consultation opens from the counter")
	await _shot_panel("consult_rl_screen")
	var ses := Consult.session("sigrun")
	pt.expect((ses["recs"] as Array).size() >= 3, "consult: %d recommendations" % (ses["recs"] as Array).size())
	pt.note("recs: " + " | ".join((ses["recs"] as Array).map(func(r): return "%s [%s]" % [r["title"], Consult.odds(a, r)["word"]])))
	var buy := {}
	for r in ses["recs"]:
		if str(r["kind"]) == "buy":
			buy = r
	pt.expect(not buy.is_empty(), "consult: the fire blade on display is among the advice")
	if not buy.is_empty():
		await pt.click("Details", pt.panel())
		await _shot_panel("consult_rl_details")
		_seed_roll("sigrun", str(buy["id"]), true)
		var b: Button = pt.panel().find_child("Advise_" + str(buy["id"]), true, false)
		pt.expect(b != null, "consult: the Advise button for the blade")
		if b != null:
			b.pressed.emit()
			await pt.wait(0.6)
		pt.expect(int(a["equipment"]["weapon"]["uid"]) == int(blade["uid"]), "consult: she bought the Emberwarden on the smith's advice")
		await _shot_panel("consult_rl_accepted")
	pt.close_panel()
	await pt.wait(0.3)
	# a refusal: Varn will not turn back from Drake's Crag
	var v := Adv.get_a("varn")
	Expeditions.ensure(v)
	v["status"] = "in_town"
	v["trait"] = "reckless"
	v["goals"] = [{"kind": "renown", "target": 9999, "since": 1}]
	WorldSites.site("drakes_crag")["discovered"] = true
	v["next_dest"] = "drakes_crag"
	v["level"] = 1
	v["hp_max"] = Expeditions.hp_max(v)
	v["hp"] = v["hp_max"]
	pt.expect(await pt.talk_to("varn") or true, "consult: talk to Varn")
	await pt.wait(0.3)
	if pt.panel() is DialoguePanel:
		await pt.shot("consult_rl_dialogue")
		await pt.click("Talk about their gear", pt.panel())
		await pt.wait(0.8)
	else:
		Events.open_panel.emit("consult", {"id": "varn"})
		await pt.wait(0.8)
	pt.expect(pt.panel() is ConsultPanel, "consult: Varn's consultation from the dialogue")
	var vs := Consult.session("varn")
	var dest := {}
	for r in vs["recs"]:
		if str(r["kind"]) == "dest":
			dest = r
	pt.expect(not dest.is_empty(), "consult: 'Don't go to Drake's Crag with this kit' is advised")
	if not dest.is_empty() and pt.panel() is ConsultPanel:
		_seed_roll("varn", str(dest["id"]), false)
		var b2: Button = pt.panel().find_child("Advise_" + str(dest["id"]), true, false)
		if b2 != null:
			b2.pressed.emit()
			await pt.wait(0.6)
		pt.expect(not bool(vs["done"].get(str(dest["id"]), {}).get("accepted", true)), "consult: Varn refuses, in his own voice")
		pt.expect(str(v["next_dest"]) == "drakes_crag", "consult: his plan is unchanged")
		await _shot_panel("consult_rl_refused")
	pt.close_panel()
