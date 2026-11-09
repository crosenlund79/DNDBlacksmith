## The Living Realm — equipment presentation and the cloak slot (EQUIPMENT worker).
## EN: Cloaks have their own slot (shoulders), so a cloak and an amulet are worn together; adventurers buy and
##     commission cloaks into that slot and wear them on the road; an old save with a cloak in the amulet slot
##     loads with the very same piece (uid, maker, provenance) moved to the cloak slot. The humanoid EquipmentSheet
##     builds for adventurers and hirelings with empty, full and broken gear, every slot at its body region, the
##     full stat list behind its toggle, and the compare view weighs a piece from the stores against what is worn.
## DA: Kappepladsen, migrering af gamle gem og det menneskeformede udstyrsark.
extends SuiteCase

const SMOKE := ["test_cloak_slot_data", "test_cloak_and_amulet_together", "test_sheet_regions"]


func _adv(cls: String) -> Dictionary:
	var ids := Adv.all().keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = Adv.all()[id]
		if str(a.get("cls", "")) == cls and a.get("status", "") != "dead":
			Adv.ensure(a)
			return a
	return {}


func _cloak(def := "cloak_travel", q := 90.0) -> Dictionary:
	var it := Items.make(def, {"quality": q, "crafted_by": "Brannoc Ironhand"})
	Provenance.forged(it)
	return it


func _full_gear() -> Dictionary:
	var eq := {}
	for pair in [["weapon", "sword_iron"], ["shield", "shield_round"], ["armor", "chainmail"], ["helmet", "helm_iron"], ["gloves", "gloves_leather"],
			["boots", "boots_leather"], ["belt", "belt_leather"], ["ring", "ring_silver"], ["amulet", "amulet_silver"], ["cloak", "cloak_warded"]]:
		eq[pair[0]] = Items.make(str(pair[1]), {"quality": 80.0})
	return eq


func test_cloak_slot_data() -> void:
	fresh_game()
	check(Items.SLOTS.has("cloak") and Items.SLOT_LABEL.get("cloak", "") == "Cloak", "the cloak is a real equipment slot")
	for id in ["cloak_travel", "cloak_warded", "cloak_shadow"]:
		eq(str(DB.item(id).get("slot", "")), "cloak", "%s is worn in the cloak slot" % id)
	eq(str(DB.item("amulet_silver").get("slot", "")), "amulet", "amulets keep the amulet slot")
	for s in Items.SLOTS:
		check(EquipmentSheet.region_of(s) != "", "slot %s has a body region on the sheet" % s)
	eq(EquipmentSheet.region_of("cloak"), "shoulders", "the cloak is worn on the shoulders")
	eq(EquipmentSheet.region_of("amulet"), "neck", "the amulet at the neck")
	check(Adv.all_slots().has("cloak"), "adventurers consider the cloak slot")
	check(Shop.slot_ceiling("cloak", "protection") >= 1, "a craftable cloak can meet a commission (ceiling %d)" % Shop.slot_ceiling("cloak", "protection"))
	eq(Shop.preferred_materials(3, "cloak"), ["cloth"], "a customer wants a cloak made of cloth")
	eq(Refinement.material_of(Items.make("cloak_travel")), "cloth", "a cloak refines as cloth")


func test_cloak_and_amulet_together() -> void:
	fresh_game()
	var a := _adv("Wizard")
	if not check(not a.is_empty(), "a wizard lives at the inn"):
		return
	if a["equipment"].get("amulet", {}).is_empty():
		Adv.give_item(a, Items.make("amulet_silver", {"quality": 70.0}), 0)
	var am_uid := int(a["equipment"]["amulet"]["uid"])
	var ck := _cloak("cloak_warded")
	Adv.give_item(a, ck, 0)
	eq(int(a["equipment"].get("cloak", {}).get("uid", -1)), int(ck["uid"]), "the cloak goes to the cloak slot")
	eq(int(a["equipment"].get("amulet", {}).get("uid", -1)), am_uid, "the amulet stays on")
	check(Expeditions.total(a, "ward") >= Items.stat(ck, "ward"), "the cloak's ward counts with the amulet's stats")
	check(Adv.affinity(a, ck) > 1.0, "a wizard favours a good cloak (%.2f)" % Adv.affinity(a, ck))
	check(save_load("suite_eqrl_both"), "saved and loaded")
	var b := Adv.get_a(str(a["id"]))
	check(not b["equipment"].get("cloak", {}).is_empty() and not b["equipment"].get("amulet", {}).is_empty(), "both still worn after save/load")


func test_buy_and_commission_cloak() -> void:
	fresh_game()
	var a := _adv("Ranger")
	if not check(not a.is_empty(), "a ranger lives at the inn"):
		return
	a["gold"] = 900
	a["equipment"].erase("cloak")
	var ck := _cloak("cloak_travel", 95.0)
	ck["for_sale"] = true
	ck["price"] = 40
	Game.add_item(ck, false)
	eq(Adv.purchase_check(a, ck, 40), "", "a ranger would buy a travel cloak")
	check(not Adv.best_stock(a, "cloak").is_empty(), "the cloak on display is what they'd buy for the cloak slot")
	eq(Shop.sell_to(str(a["id"]), int(ck["uid"])), "", "sold at the counter")
	eq(int(a["equipment"].get("cloak", {}).get("uid", -1)), int(ck["uid"]), "the bought cloak is worn in the cloak slot")
	# a commission for a cloak, met by a cloak, delivered into the cloak slot
	a["equipment"].erase("cloak")
	Shop.orders().clear()
	var o := Shop.create_order(str(a["id"]), "cloak", "For the moors.")
	if not check(not o.is_empty(), "a cloak commission is placed"):
		return
	eq(str(o["slot"]), "cloak", "the order names the cloak slot")
	eq(str(o["stat"]), "protection", "a cloak is judged by protection")
	check(int(o["min"]) <= Shop.slot_ceiling("cloak", "protection"), "the order asks no more than a cloak can give")
	var made := _cloak("cloak_shadow", 120.0)
	o["min"] = mini(int(o["min"]), Items.stat(made, "protection"))
	o["tier"] = 1
	Game.add_item(made, false)
	check(Shop.item_meets(o, made), "a shadow cloak meets the cloak commission")
	check(not Shop.item_meets(o, Items.make("amulet_silver")), "an amulet does not")
	eq(Shop.fulfil(str(o["id"]), int(made["uid"])), "", "the commission is delivered")
	eq(int(a["equipment"].get("cloak", {}).get("uid", -1)), int(made["uid"]), "the commissioned cloak is worn in the cloak slot")
	# the road wears it
	var d0 := int(made["stats"]["durability"])
	Expeditions.trip_wear(a)
	check(int(made["stats"]["durability"]) < d0, "the road wears the cloak (%d → %d)" % [d0, int(made["stats"]["durability"])])


func test_old_save_cloak_migrates() -> void:
	fresh_game()
	var a := _adv("Rogue")
	var w := _adv("Wizard")
	if not check(not a.is_empty() and not w.is_empty(), "a rogue and a wizard live at the inn"):
		return
	# an old save: the rogue wears ONLY a cloak, in the amulet slot; the wizard a real amulet
	var ck := _cloak("cloak_shadow")
	Lore.record("note", "test history", {"items": [ck], "importance": 0})
	var uid := int(ck["uid"])
	var maker: Dictionary = Provenance.maker(ck).duplicate(true)
	var events := ItemStory.events_of(ck).size()
	a["equipment"] = {"amulet": ck}
	if w["equipment"].get("amulet", {}).is_empty():
		w["equipment"]["amulet"] = Items.make("amulet_silver", {"quality": 70.0})
	var wam := int(w["equipment"]["amulet"]["uid"])
	# a hireling with a cloak clasped in the amulet slot, and a commission for a cloak filed under "amulet"
	var hs := Hire.list()
	var hck := _cloak("cloak_travel")
	if not hs.is_empty():
		hs[0]["equipment"]["amulet"] = hck
	Shop.orders().append({"id": "ord_eqrl_old", "npc": str(a["id"]), "slot": "amulet", "def": "cloak_warded", "stat": "protection", "min": 1,
		"tier": 1, "reward": 50, "deadline": Game.day() + 3, "status": "open", "note": "", "placed": Game.day()})
	# a save written by 0.14.6 or earlier declares schema 1: loading runs the v1 → v2 step (the cloak walk)
	check(save_as_version("suite_eqrl_old", 1), "the old-shaped save is written (schema 1)")
	check(Saves.load_slot("suite_eqrl_old"), "the old save loads")
	Saves.delete("suite_eqrl_old")
	var a2 := Adv.get_a(str(a["id"]))
	var moved: Dictionary = a2["equipment"].get("cloak", {})
	eq(int(moved.get("uid", -1)), uid, "the same cloak (same uid) now sits in the cloak slot")
	check(not a2["equipment"].has("amulet"), "the amulet slot is free again")
	eq(Provenance.maker(moved).get("name", ""), maker.get("name", ""), "its maker is unchanged")
	eq(int(Provenance.maker(moved).get("day", -1)), int(maker.get("day", -2)), "its maker's day is unchanged")
	eq(ItemStory.events_of(moved).size(), events, "its story is unchanged")
	eq(int(Adv.get_a(str(w["id"]))["equipment"].get("amulet", {}).get("uid", -1)), wam, "a real amulet stays in the amulet slot")
	if not hs.is_empty():
		var h2: Dictionary = Hire.list()[0]
		eq(int(h2["equipment"].get("cloak", {}).get("uid", -1)), int(hck["uid"]), "the hireling's cloak moved too")
	for o in Shop.orders():
		if str(o["id"]) == "ord_eqrl_old":
			eq(str(o["slot"]), "cloak", "a commission for a cloak names the cloak slot")
	eq(Items.migrate_cloak_slots(Game.state), 0, "the migration is idempotent")
	# the sheet shows the migrated cloak at the shoulders
	var sh := EquipmentSheet.new(a2["equipment"], {})
	check(sh.cards.has("cloak") and (sh.cards["cloak"].get_child(0).get_child(0) as ItemSlot).item.get("uid", -1) == uid, "the sheet shows it in the cloak card")
	sh.free()


func test_sheet_regions() -> void:
	fresh_game()
	for eqd in [{}, _full_gear()]:
		var sh := EquipmentSheet.new(eqd, {})
		for d in EquipmentSheet.LAYOUT:
			check(sh.cards.has(str(d[0])), "the sheet has a card for %s" % d[0])
		# every slot sits by its body region: the left column top to bottom follows the body, and so does the right
		for col in [0, 1]:
			var prev := -1.0
			var prev_y := -1.0
			for d in EquipmentSheet.LAYOUT:
				if int(d[1]) != col:
					continue
				var c: Control = sh.cards[str(d[0])]
				var ay := (d[3] as Vector2).y
				check(c.position.y > prev_y and ay > prev, "%s is below the slot above it, card and body alike" % d[0])
				prev = ay
				prev_y = c.position.y
				var fig_mid := sh.fig_pos.x + EquipmentSheet.FIG.x * sh.fig_scale * 0.5
				check((c.position.x < fig_mid) == (col == 0), "%s is on its side of the figure" % d[0])
		sh.free()
	# the main hand (weapon) and off hand (shield) are on opposite sides, the cloak and amulet both shown
	var full := _full_gear()
	var sh2 := EquipmentSheet.new(full, {})
	check((sh2.cards["weapon"] as Control).position.x != (sh2.cards["shield"] as Control).position.x, "main hand and off hand on opposite sides")
	check(sh2.summary().begins_with("10 pieces worn"), "at a glance: %s" % sh2.summary())
	sh2.free()


func test_sheet_states_and_hireling() -> void:
	fresh_game()
	# broken and worn pieces show in the summary and on the slot's condition strip
	var full := _full_gear()
	full["armor"]["broken"] = true
	full["boots"]["stats"]["durability"] = 1
	var sh := EquipmentSheet.new(full, {})
	check(sh.summary().contains("1 broken") and sh.summary().contains("1 worn down"), "summary: %s" % sh.summary())
	var aslot := sh.cards["armor"].get_child(0).get_child(0) as ItemSlot
	check(aslot != null and aslot.show_condition and aslot.item.get("broken", false), "the broken armour's slot shows its condition")
	eq(EquipmentSheet.condition_word(full["armor"]), "broken", "condition word")
	sh.free()
	# a stranger's gear on Master: kind only
	var sh3 := EquipmentSheet.new(_full_gear(), {"known": func(_it): return false})
	var wslot := sh3.cards["weapon"].get_child(0).get_child(0) as ItemSlot
	check(wslot.item.is_empty(), "an unknown piece is not revealed on the card")
	sh3.free()
	# the full stat list sits behind the toggle
	EquipmentSheet.show_stats = false
	var sh4 := EquipmentSheet.new(_full_gear(), {})
	check(not sh4.stats_box.visible, "full stats hidden by default")
	sh4.free()
	EquipmentSheet.show_stats = true
	var sh5 := EquipmentSheet.new(_full_gear(), {})
	check(sh5.stats_box.visible and sh5.stats_box.get_child_count() > 0, "full stats shown when toggled")
	sh5.free()
	EquipmentSheet.show_stats = false
	# hirelings: the compact sheet over their equipment dict, any slot (a cloak too)
	var hs := Hire.list()
	if hs.is_empty():
		skip("no hireling at the start of this build")
		return
	var h: Dictionary = hs[0]
	var hck := _cloak()
	Game.add_item(hck, false)
	check(Hire.equip(str(h["id"]), int(hck["uid"])), "a hireling takes a cloak")
	eq(int(h["equipment"].get("cloak", {}).get("uid", -1)), int(hck["uid"]), "worn in the cloak slot")
	var hsh := EquipmentSheet.new(h["equipment"], {"compact": true})
	check(hsh.compact and hsh.cards.has("cloak") and hsh.cards.has("weapon"), "the compact sheet builds for a hireling")
	check(hsh.doll.custom_minimum_size.x <= 580.0, "it fits the ledger's gear column (%d px)" % int(hsh.doll.custom_minimum_size.x))
	hsh.free()


func test_compare_and_candidates() -> void:
	fresh_game()
	var a := _adv("Fighter")
	if not check(not a.is_empty(), "a fighter lives at the inn"):
		return
	var sw := Items.make("sword_iron", {"quality": 110.0, "rarity": "rare"})
	Game.add_item(sw, false)
	var robe := Items.make("robe_novice", {"quality": 80.0}) if DB.items.has("robe_novice") else {}
	if not robe.is_empty():
		Game.add_item(robe, false)
	var c := DossierPanel.store_candidates(a)
	check((c.get("weapon", []) as Array).has(sw), "the sword in the stores is a candidate for the weapon slot")
	var cv := EquipmentSheet.compare_view(a["equipment"].get("weapon", {}), sw, "would take it", true)
	check(cv.name == "CompareView" and cv.get_child_count() == 1, "the compare view builds")
	cv.free()
	# the sheet offers ⇄ only where there is something to compare
	var sh := EquipmentSheet.new(a["equipment"], {"candidates": c, "on_compare": func(_s): pass})
	check(sh.cards["weapon"].find_child("Compare", true, false) != null, "the weapon card offers a compare")
	check(sh.cards["ring"].find_child("Compare", true, false) == null, "the ring card does not")
	sh.free()
