## The world remembers — one deterministic end-to-end story, every link checked and carried through a reload:
## forged → sold → expedition to a persistent site → its unique master slain with the blade → the site cleared for
## good → the blade named and Epic → its owner falls → it passes on → brought back for repair → recognised once →
## an awakened blade speaks of its own history (and stays quiet when muted).
extends SuiteCase

const SMOKE := ["test_craft_to_reunion"]
const SITE := "whisperwood"


func _in_town(skip := "") -> String:
	var ids := Adv.all().keys()
	ids.sort()
	for id in ids:
		var a := Adv.get_a(str(id))
		if a["status"] == "in_town" and not Shop.refuses(str(id)) and str(id) != skip:
			return str(id)
	return ""


func test_craft_to_reunion() -> void:
	fresh_game()
	seed(4242)
	give("ingot_iron", 6)
	give("leather_cured", 3)
	var it := craft("iron_longsword", 100.0, {"edge": 14, "temper": 12, "fortune": 1})
	var aid := _in_town()
	var heir_id := _in_town(aid)
	if not check(not it.is_empty() and aid != "" and heir_id != "", "a blade is forged; two adventurers are in town"):
		return
	var uid := int(it["uid"])
	eq(str(Provenance.owners(it)[0].get("how", "")), "forged", "1. forged: the chain begins at the anvil")
	# 2. sold
	var a := Adv.get_a(aid)
	a["gold"] = 999
	a["equipment"].erase("weapon")
	Adv.give_item(a, Game.take_uid(uid), 60)
	var w := Game.find_uid_anywhere(uid)
	eq(Provenance.owner_id(w), aid, "2. sold to %s" % a["name"])
	# 3. an expedition to a persistent site; its unique master falls to this very blade
	check(WorldSites.boss_alive(SITE), "3. the Whisperwood's master is alive before the expedition")
	Expeditions.ensure(a)
	a["status"] = "away"
	var e := {"id": "exp_e2e", "party": [aid], "leader": aid, "dest": SITE, "journal": [], "encounters": [], "start": Game.now()}
	var rec := {"boss": true, "outcome": "win", "enemies": [{"kind": "beast", "name": "the Hollow Alpha", "key": "e0"}],
		"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": aid, "weapon_uid": uid, "hit": true}]}
	var xp0 := int(a.get("xp", 0))
	Expeditions._boss_down(e, {"id": "hollow", "name": "The Hollow"}, rec)
	a["status"] = "in_town"
	check(not WorldSites.boss_alive(SITE), "4. the unique master is dead and the site remembers it")
	check(int(a.get("xp", 0)) > xp0 or not (a.get("achievements", []) as Array).is_empty(), "the slayer gains experience / an achievement")
	var slew := Lore.of_item(uid).filter(func(x): return str(x["kind"]) == "slew")
	eq(slew.size(), 1, "5. the kill is ONE Lore event on the blade")
	if not slew.is_empty():
		var ev: Dictionary = slew[0]
		check(str(ev["place"]) == SITE and (ev["actors"] as Array).has(aid), "…tied to the site and the slayer")
		check(Lore.of_place(SITE).any(func(x): return x["id"] == ev["id"]), "…and in the site's own history")
		check((a.get("lore", []) as Array).has(ev["id"]), "…and in the slayer's history")
	# 6. named and Epic
	check(ItemStory.is_named(w), "6. the blade earned a name: %s" % Items.display_name(w))
	check(w.has("epic"), "…and Epic distinction (rarity stays %s)" % str(w.get("rarity", "")))
	var name_now := Items.display_name(w)
	# 7. the owner falls; the blade passes on
	var heir := Adv.get_a(heir_id)
	heir["equipment"].erase("weapon")
	a["status"] = "dead"
	Adv.bequeath(a, [heir_id], SITE, WorldSites.name_of(SITE))
	var holder := "heir" if int(heir["equipment"].get("weapon", {}).get("uid", -1)) == uid else "other"
	check(holder == "heir" or not Game.find_uid_anywhere(uid).is_empty(), "7. the fallen's blade passes on (%s)" % holder)
	w = Game.find_uid_anywhere(uid)
	if not check(not w.is_empty(), "the blade still exists"):
		return
	check(Lore.of_item(uid).any(func(x): return str(x["kind"]) in ["inherited", "recovered"]), "the passing is in its story")
	var who := Provenance.owner_id(w)
	# 8. returned for repair: recognised once
	var card := ItemStory.recognise(w, "repair", who)
	check(not card.is_empty(), "8. back at the counter, the smith recognises it")
	check(ItemStory.recognise(w, "repair", who).is_empty(), "…once only")
	Provenance.workshop(w, "repaired", "Repaired at the Ironhand forge.")
	eq(str(Provenance.maker(w).get("id", "")), "smith", "repairs never change the maker")
	# 9. an awakened blade speaks of its own history; muted, it stays silent
	Settings.values[ItemSpirit.VOICE_KEY] = true
	ItemSpirit.awaken(w, "slew", SITE)
	check(ItemSpirit.awake(w), "9. the deed woke something in the blade")
	var line := ItemSpirit.speak(w, "repair", true)
	check(line != "", "it speaks at the grinding wheel: “%s”" % line)
	check(ItemSpirit.speak(w, "repair", true) == "", "a cooldown keeps it from chattering")
	Settings.values[ItemSpirit.VOICE_KEY] = false
	check(ItemSpirit.quiet_reason(w) != "", "muted (or resting), it says nothing")
	Settings.values[ItemSpirit.VOICE_KEY] = true
	# 10. everything survives a reload
	var n_ev := Lore.of_item(uid).size()
	if not check(save_load("suite_world_remembers"), "10. save and load"):
		return
	w = Game.find_uid_anywhere(uid)
	check(not w.is_empty() and Items.display_name(w) == name_now and w.has("epic"), "name and Epic persist")
	check(not WorldSites.boss_alive(SITE), "the master stays dead")
	eq(Lore.of_item(uid).size(), n_ev, "the story is intact")
	check(Provenance.is_mine(w) and ItemSpirit.awake(w), "still the smith's mark, still awake")
	check(ItemStory.recognise(w, "repair", who).is_empty(), "the reunion is not repeated after loading")
