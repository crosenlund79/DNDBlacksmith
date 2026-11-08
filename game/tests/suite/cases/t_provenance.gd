## The world remembers — core: stable item identity, permanent makers, owner chains, one shared record per event,
## inheritance without duplication, and migration of items from saves made before provenance existed.
extends SuiteCase

const SMOKE := ["test_identity_through_life", "test_one_record_per_event"]


func _sword() -> Dictionary:
	give("ingot_iron", 6)
	give("leather_cured", 2)
	return craft("iron_longsword", 104.0, {"edge": 15, "temper": 10, "fortune": 40})


## Every equipment instance anywhere in the world, by uid (to catch duplicates).
func _census() -> Dictionary:
	var seen := {}
	for it in Lore._all_items():
		var u := int(it.get("uid", -1))
		seen[u] = int(seen.get(u, 0)) + 1
	for p in Game.state.get("commerce", {}).get("pawn", {}).get("pledges", []):
		var u2 := int(p.get("item", {}).get("uid", -1))
		seen[u2] = int(seen.get(u2, 0)) + 1
	return seen


func test_identity_through_life() -> void:
	var it := _sword()
	if not check(not it.is_empty(), "the sword is forged"):
		return
	var uid := int(it["uid"])
	check(Provenance.is_mine(it) and str(Provenance.maker(it).get("mark", "")) == "ironhand", "the Ironhand mark is struck at forging")
	check(Provenance.owner_id(it) == "smith", "the smith owns it first")
	check(Lore.of_item(uid).size() >= 1 and str(Lore.of_item(uid)[0]["kind"]) == "forged", "its story begins with the forging")
	# sold to an adventurer
	var a: Dictionary = Adv.all().values()[0]
	a["gold"] = 999
	a["equipment"].erase("weapon")
	Adv.give_item(a, Game.take_uid(uid), 50)
	check(Provenance.owner_id(it) == str(a["id"]) and Provenance.owners(it).size() == 2, "sold: the owner chain grows (%d owners)" % Provenance.owners(it).size())
	# repaired and enchanted by the smith — maker unchanged
	Provenance.workshop(it, "repaired", "Repaired at the Ironhand forge.")
	Provenance.workshop(it, "reforged", "Reforged at the Ironhand forge.")
	eq(str(Provenance.maker(it).get("id", "")), "smith", "repairs and reforging never change the maker")
	# a rival smith cannot claim it
	Provenance.set_maker(it, "rival_smith", "Maren Tallowgate", "salt_anvil", "the Salt Anvil")
	eq(str(Provenance.maker(it).get("mark", "")), "ironhand", "the original creator is permanent")
	# save / load: same uid, same maker, same story
	var n_events := Lore.of_item(uid).size()
	check(save_load("suite_prov"), "save and load")
	var again := Game.find_uid_anywhere(uid)
	check(not again.is_empty() and Provenance.is_mine(again) and Lore.of_item(uid).size() == n_events, "identity, maker and story survive save/load")
	eq(int(_census().get(uid, 0)), 1, "exactly one instance of the sword exists")


func test_one_record_per_event() -> void:
	var it := _sword()
	var a: Dictionary = Adv.all().values()[1]
	var ev := Lore.record("slew", "%s slew a test wyrm with %s." % [a["name"], Items.display_name(it)], {"items": [it], "actors": [a["id"]], "place": "whisperwood", "importance": 3})
	var in_item: bool = Provenance.st(it)["events"].has(ev)
	var in_adv := (a.get("lore", []) as Array).has(ev)
	var in_place := Lore.of_place("whisperwood").any(func(e): return e["id"] == ev)
	check(in_item and in_adv and in_place, "one event, referenced by the item, the adventurer and the place")
	var hits := 0
	for e in Provenance.story(it):
		if str(e.get("text", "")).contains("test wyrm"):
			hits += 1
	eq(hits, 1, "the item's story shows the event once (the history index does not duplicate it)")


func test_inheritance_no_duplicates() -> void:
	var it := _sword()
	var uid := int(it["uid"])
	var ads: Array = Adv.all().values()
	var dead: Dictionary = ads[0]
	var heir: Dictionary = ads[1]
	for x in [dead, heir]:
		x["equipment"].erase("weapon")
	dead["equipment"]["weapon"] = Game.take_uid(uid)
	Provenance.transfer(it, str(dead["id"]), "sold")
	dead["status"] = "dead"
	Adv.bequeath(dead, [heir["id"]], "barrow_fields", "the Barrow Fields")
	var holder := ""
	if int(heir["equipment"].get("weapon", {}).get("uid", -1)) == uid:
		holder = "heir"
	elif not Game.state["returns"].filter(func(c): return c.get("contents", []).any(func(x): return int(x.get("uid", -1)) == uid)).is_empty():
		holder = "forge"
	check(holder != "", "the fallen's blade passes on (to %s)" % holder)
	check(not dead["equipment"].has("weapon"), "it no longer sits with the dead")
	eq(int(_census().get(uid, 0)) + (1 if holder == "forge" else 0), 1, "no duplicate appears")
	check(Provenance.is_mine(it), "and it is still the smith's work")


func test_pawn_round_trip() -> void:
	if not has_system("commerce"):
		skip("commerce not in this build")
		return
	var it := _sword()
	var uid := int(it["uid"])
	eq(Commerce.pawn_item(uid), "", "pawned")
	eq(Provenance.owner_id(it), "pawnbroker", "the pawnbroker holds it")
	Game.state["gold"] = 5000
	var pid: String = Commerce.pledges()[-1]["id"]
	eq(Commerce.redeem(pid), "", "redeemed")
	var back := Game.find_uid(uid)
	check(not back.is_empty() and Provenance.owner_id(back) == "smith" and Provenance.is_mine(back), "the same blade comes back, still marked")
	eq(int(_census().get(uid, 0)), 1, "one instance only")


func test_old_save_migration() -> void:
	# an item from before provenance: only crafted_by / owner / history
	var old := Items.make("sword_steel", {"quality": 90.0, "crafted_by": "Brannoc Ironhand"})
	old["owner"] = "mira"
	old["history"] = [{"day": 3, "text": "Forged at the Ironhand forge (90% craftsmanship)."}, {"day": 5, "text": "Sold to Mira Pell."}]
	check(not old.has("prov"), "a legacy item has no provenance yet")
	check(Provenance.is_mine(old), "it is recognised as the smith's from crafted_by")
	var p := Provenance.st(old)
	check(str(p["maker"]["mark"]) == "ironhand" and Provenance.owner_id(old) == "mira", "migration builds maker and current owner")
	eq(Provenance.story(old).size(), 2, "the legacy notes appear in its story")
	var anc := Items.make("sword_steel", {"crafted_by": "a smith of the barrow-kings' age"})
	eq(str(Provenance.maker(anc).get("mark", "")), "barrow", "ancient pieces keep their own maker identity")
