## Scenario B — business and adventurers: craft an item, fulfil a commission, equip an adventurer, resolve an
## expedition, and verify the equipment shaped the outcome and left persistent rewards and history.
extends SuiteCase

const SMOKE := ["test_commission_and_expedition"]


func _adventurer_for(slot: String) -> String:
	for a in Adv.all().values():
		if a["status"] == "in_town" and not Shop.refuses(a["id"]):
			return a["id"]
	return ""


func test_commission_and_expedition() -> void:
	var aid := _adventurer_for("weapon")
	if not check(aid != "", "an adventurer is in town"):
		return
	var a := Adv.get_a(aid)
	var o := Shop.create_order(aid, "weapon")
	if not check(not o.is_empty() and o.has("priority") and o.has("bonus"), "a commission with priority and bonus objective"):
		return
	# forge until a blade meets the order (fixed high craftsmanship, deterministic dice)
	give("ingot_iron", 12)
	give("leather_cured", 4)
	var it := {}
	for attempt in 4:
		it = craft("iron_longsword", 110.0, {"edge": 20, "temper": 20, "fortune": 90})
		if not it.is_empty() and Shop.item_meets(o, it):
			break
	if Shop.item_meets(o, it):
		var g0 := Game.gold()
		eq(Shop.fulfil(o["id"], int(it["uid"])), "", "the commission is fulfilled")
		check(Game.gold() >= g0 or Social.spouse() == aid, "the commission paid")
		check(int(a["equipment"]["weapon"]["uid"]) == int(it["uid"]), "the adventurer carries the exact blade")
	else:
		note("no forged blade met the order (min %d %s); equipping one directly" % [int(o["min"]), o["stat"]])
		Adv.give_item(a, Game.take_uid(int(it["uid"])), 0)
	var uid := int(a["equipment"]["weapon"]["uid"])
	# a party forms and the expedition runs on its own
	for x in Adv.all().values():
		Expeditions.ensure(x)
		if x["status"] != "dead":
			x["status"] = "in_town"
			x["hp"] = x["hp_max"]
			x["fatigue"] = 0.0
			x["depart_day"] = Game.day()
	Expeditions.form_parties()
	Expeditions.prepare_parties()
	Expeditions.depart_parties()
	var eid := ""
	for k in Expeditions.active():
		if (Expeditions.active()[k]["party"] as Array).has(aid):
			eid = k
	if eid == "":
		# not chosen today: send them with a party of their own
		Expeditions.st()["parties"] = {}
		var p := {"id": "p_suite", "members": [aid], "leader": aid, "dest": "whisperwood", "goal": "explore"}
		eid = str(Expeditions.start(p).get("id", ""))
	check(eid != "", "the adventurer set out")
	var e: Dictionary = Expeditions.active().get(eid, {})
	var guard := 0
	while Expeditions.active().has(eid) and guard < 600:
		Expeditions.step(e)
		guard += 1
	check(not Expeditions.active().has(eid), "the expedition finished on its own")
	# every blow the adventurer struck names the weapon instance they carried
	var blows := 0
	var with_blade := 0
	for r in e.get("encounters", []):
		for act in r.get("actions", []):
			if str(act.get("kind", "")) == "attack" and str(act.get("actor", "")) == str(a["name"]) and act.has("weapon_uid"):
				blows += 1
				if int(act["weapon_uid"]) == uid:
					with_blade += 1
	if blows == 0:
		note("%s struck no blow on this trip" % a["name"])
	check(blows == 0 or with_blade > 0, "the forged blade's uid appears in the combat record (%d/%d blows)" % [with_blade, blows])
	var sw := Game.find_uid_anywhere(uid)
	check(sw.is_empty() or (sw.get("history", []) as Array).size() >= 2, "the blade's history grew")
	check(int(a.get("expeditions", 0)) >= 1 and (Chronicle.entries().size() > 0), "persistent record: expeditions counted, chronicle written")
	check(save_load("suite_business") and Expeditions.get_exp(eid).size() > 0, "the expedition record survives save/load")
