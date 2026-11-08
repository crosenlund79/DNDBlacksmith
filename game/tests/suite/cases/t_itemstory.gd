## Item stories (iteration 011): the maker's mark is permanent, names are earned once and never re-rolled,
## Legendary and Epic stay distinct, reunions are acknowledged once per occasion, the Hall of Fame lists famous
## creations, fame brings a special commission, and the workshop services (sharpening, reforging) add history.
extends SuiteCase

const SMOKE := ["test_maker_never_changes", "test_boss_naming_persists", "test_reunion_once_per_occasion"]


func _in_town_adv(skip := "") -> String:
	var ids := Adv.all().keys()
	ids.sort()
	for id in ids:
		var a := Adv.get_a(str(id))
		if a["status"] == "in_town" and not Shop.refuses(str(id)) and str(id) != skip:
			return str(id)
	return ""


## A plain (common) iron longsword: a low fortune die keeps the rarity common.
func _sword(q := 92.0) -> Dictionary:
	give("ingot_iron", 6)
	give("leather_cured", 3)
	return craft("iron_longsword", q, {"edge": 12, "temper": 12, "fortune": 1})


func _boss_fight(aid: String, uid: int, boss := "The Barrow King", kind := "undead") -> void:
	var a := Adv.get_a(aid)
	Expeditions.ensure(a)
	a["status"] = "away"
	a["hp"] = a["hp_max"]
	var e := {"id": "exp_story", "party": [aid], "leader": aid, "dest": "barrow_fields", "journal": [], "encounters": []}
	var rec := {"boss": true, "enemies": [{"kind": kind, "name": boss, "key": "e0"}],
		"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": aid, "weapon_uid": uid, "hit": true}]}
	Expeditions._boss_down(e, {"name": "The Barrow Hall"}, rec)
	a["status"] = "in_town"


func _kinds(it: Dictionary) -> Array:
	return ItemStory.events_of(it).map(func(e): return str(e.get("kind", "")))


# ------------------------------------------------------------------ the maker's mark
func test_maker_never_changes() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var it := _sword()
	if not check(not it.is_empty() and aid != "", "a sword is forged and an adventurer is in town"):
		return
	var uid := int(it["uid"])
	check(Provenance.is_mine(it), "the forged sword is the smith's")
	eq(str(Provenance.mark(it).get("name", "")), "the Ironhand mark", "it carries the Ironhand mark")
	check(Items.tooltip(it).contains("the Ironhand mark"), "the tooltip shows the maker's mark")
	# enchant (a rune set at the engraving stand)
	give("runestone_ember")
	check(Crafting.socket(uid, "runestone_ember", 90.0), "a runestone is set into it")
	# reforge at the anvil
	give("coal", 2)
	var r := ItemStory.reforge(uid, 110.0)
	check(bool(r.get("ok", false)), "it is reforged")
	# resale: sold to an adventurer, repaired for them, offered back and bought by the forge
	var a := Adv.get_a(aid)
	a["gold"] = 500
	Adv.give_item(a, Game.take_uid(uid), 40)
	var w: Dictionary = a["equipment"]["weapon"]
	w["stats"]["durability"] = 3
	Shop.customers().append({"npc": aid, "want": "repair", "own_slot": "weapon", "pay": 10, "present": true, "seat": 0, "arrived": 0})
	Shop.do_repair(aid, 90.0)
	ItemStory.sharpen(w, 80.0, aid)
	a["equipment"].erase("weapon")
	Shop.add_offer(aid, w, false)
	Game.add_gold(1000, "test", "test purse")
	var oid := str(Shop.offers()[-1]["id"])
	eq(Shop.accept_offer(oid), "", "the forge buys it back")
	var back := Game.find_uid(uid)
	check(not back.is_empty(), "the same piece (uid) is back in the stores")
	eq(str(Provenance.maker(back).get("id", "")), Provenance.SMITH_ID, "the maker is still the smith after enchanting, reforging, resale, repair and sharpening")
	eq(str(Provenance.maker(back).get("mark", "")), "ironhand", "the mark is unchanged")
	var ks := _kinds(back)
	for k in ["forged", "enchanted", "reforged", "sold", "repaired", "sharpened", "bought"]:
		check(ks.has(k), "the story records '%s' (%s)" % [k, str(ks)])
	# another smith's piece keeps its own maker through the same treatment
	var rival := Items.make("sword_steel", {"quality": 85.0})
	Provenance.set_maker(rival, "rival_smith", "Maren Tallowgate", "salt_anvil", "the Salt Anvil, Brindlewick")
	Game.add_item(rival, false)
	ItemStory.reforge(int(rival["uid"]), 100.0)
	Provenance.set_maker(rival, Provenance.SMITH_ID, Provenance.SMITH_NAME, "ironhand", "")
	eq(str(Provenance.maker(rival).get("id", "")), "rival_smith", "a Salt Anvil piece keeps its maker after reforging at the Ironhand forge")
	check(not Provenance.is_mine(rival), "and it is not counted as the smith's work")
	check(Items.tooltip(rival).contains("Salt Anvil"), "its tooltip names its own mark")
	check(save_load("suite_story_maker"), "save/load")
	eq(str(Provenance.maker(Game.find_uid(uid)).get("id", "")), Provenance.SMITH_ID, "the maker survives save/load")


# ------------------------------------------------------------------ names earned through history
func test_boss_naming_persists() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var it := _sword()
	if not check(not it.is_empty() and aid != "", "a sword and an adventurer"):
		return
	var uid := int(it["uid"])
	var base := str(it["name"])
	Adv.give_item(Adv.get_a(aid), Game.take_uid(uid), 0)
	_boss_fight(aid, uid)
	var w := Game.find_uid_anywhere(uid)
	check(ItemStory.is_named(w), "the killing blow on a boss names the blade")
	var nm := ItemStory.earned_name(w)
	check(nm in ["Gravebane", "The Barrow-Breaker", "Bane of the Barrow King"], "the name follows an authored pattern naming the real foe ('%s')" % nm)
	eq(str(w["name"]), nm, "the piece is called by its name")
	eq(str(w["base_name"]), base, "and remembers what it was")
	check(str(w["named"].get("why", "")).contains("The Barrow King"), "the reason names the enemy")
	var named_ev := ItemStory.events_of(w).filter(func(e): return str(e["kind"]) == "named")
	eq(named_ev.size(), 1, "exactly one 'named' Lore event")
	check(not Recognition.of_kind("named").is_empty(), "the naming is on the Hall of Fame")
	check(Chronicle.entries().any(func(e): return str(e.get("refs", {}).get("event", "")) == str(named_ev[0]["id"])), "the village hears of it (Chronicle)")
	eq(ItemStory.bane_name(w, "The Barrow King", "undead"), ItemStory.bane_name(w, "The Barrow King", "undead"), "the pattern is deterministic")
	# a second deed never re-rolls the name
	_boss_fight(aid, uid, "Grimfang the Old", "beast")
	eq(ItemStory.earned_name(Game.find_uid_anywhere(uid)), nm, "a second boss kill keeps the name")
	check(not ItemStory.name_item(w, "Something Else", "boss", "test"), "name_item refuses to rename")
	check(save_load("suite_story_name"), "save/load")
	var w2 := Game.find_uid_anywhere(uid)
	eq(ItemStory.earned_name(w2), nm, "the name persists through save/load")
	eq(ItemStory.events_of(w2).filter(func(e): return str(e["kind"]) == "named").size(), 1, "still one naming event after loading")
	_boss_fight(aid, uid, "The Toll Troll", "humanoid")
	eq(ItemStory.earned_name(Game.find_uid_anywhere(uid)), nm, "never re-rolled after loading either")


func test_survival_and_campaign_names() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var sw := _sword()
	if not check(not sw.is_empty() and aid != "", "a sword and an adventurer"):
		return
	var a := Adv.get_a(aid)
	Expeditions.ensure(a)
	Adv.give_item(a, Game.take_uid(int(sw["uid"])), 0)
	ItemStory.on_day()   # first sighting: the baseline
	a["deaths_cheated"] = int(a.get("deaths_cheated", 0)) + ItemStory.SURVIVAL_N
	ItemStory.on_day()
	var w: Dictionary = a["equipment"]["weapon"]
	check(ItemStory.is_named(w) and str(w["named"]["kind"]) == "survival", "surviving death %d times names it (%s)" % [ItemStory.SURVIVAL_N, ItemStory.earned_name(w)])
	check(ItemStory.earned_name(w) in ["Last Breath", "Death's Refusal"], "an authored survival name")
	check(_kinds(w).has("survived"), "the survivals are in its story")
	# many campaigns
	var b := _in_town_adv(aid)
	var sw2 := _sword()
	if not check(not sw2.is_empty() and b != "", "a second sword and adventurer"):
		return
	var ab := Adv.get_a(b)
	Expeditions.ensure(ab)
	Adv.give_item(ab, Game.take_uid(int(sw2["uid"])), 0)
	ItemStory.on_day()
	ab["expeditions"] = int(ab.get("expeditions", 0)) + ItemStory.CAMPAIGN_N
	ItemStory.on_day()
	eq(ItemStory.earned_name(ab["equipment"]["weapon"]), "Old Faithful", "many campaigns earn “Old Faithful”")


# ------------------------------------------------------------------ Legendary vs Epic
func test_legendary_and_epic_distinct() -> void:
	fresh_game()
	var it := _sword()
	if not check(not it.is_empty(), "a sword"):
		return
	Items.apply_rarity(it, "legendary")
	eq(str(it["rarity"]), "legendary", "made Legendary")
	check(not Recognition.is_epic(it), "Legendary is not Epic")
	check(Recognition.grant_epic(it, "held the bridge alone"), "Epic is earned by a deed")
	eq(str(it["rarity"]), "legendary", "Epic leaves the rarity as it was — the piece is both")
	check(Recognition.is_epic(it), "and it is Epic")
	var plain := _sword()
	var r0 := str(plain["rarity"])
	check(r0 != "legendary", "a second, non-legendary sword (%s)" % r0)
	check(Recognition.grant_epic(plain, "saved a child from the river"), "a non-legendary piece can be Epic")
	eq(str(plain["rarity"]), r0, "and keeps its rarity")
	check(_kinds(plain).has("epic"), "the Epic distinction is an event in its history")
	var f := ItemStory.famous_creations()
	check(f.any(func(x): return int(x["uid"]) == int(plain["uid"]) and bool(x["epic"]) and str(x["rarity"]) == r0), "famous creations keep Epic and rarity apart")


# ------------------------------------------------------------------ reunions
func test_reunion_once_per_occasion() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var it := _sword()
	if not check(not it.is_empty() and aid != "", "a sword and an adventurer"):
		return
	var uid := int(it["uid"])
	Adv.give_item(Adv.get_a(aid), Game.take_uid(uid), 0)
	var w := Game.find_uid_anywhere(uid)
	check(ItemStory.recognise(w, "repair", aid).is_empty(), "a plain, fresh piece is not made a moment of")
	_boss_fight(aid, uid)
	var d := ItemStory.recognise(w, "repair", aid)
	check(not d.is_empty(), "a named piece back at the counter is recognised")
	eq(int(d.get("day", -1)), int(Provenance.maker(w).get("day", -2)), "the card says the day it was forged")
	check(not (d.get("achievements", []) as Array).is_empty(), "the card lists its achievements")
	check((d.get("journey", []) as Array).size() >= 2, "the card shows the ownership journey")
	check(ItemStory.recognise(w, "repair", aid).is_empty(), "the same reunion is not repeated")
	check(not ItemStory.at_counter(aid), "nor on the counter again")
	eq((Provenance.st(w)["reunions"] as Array).size(), 1, "one reunion stored")
	check(not ItemStory.recognise(w, "shown", aid).is_empty(), "a different occasion is acknowledged once")
	check(ItemStory.recognise(w, "shown", aid).is_empty(), "…and only once")
	eq(_kinds(w).filter(func(k): return k == "reunion").size(), 2, "each reunion is one Lore event")
	check(save_load("suite_story_reunion"), "save/load")
	w = Game.find_uid_anywhere(uid)
	check(ItemStory.recognise(w, "repair", aid).is_empty(), "reunions are remembered after loading")
	# a recovered chest brings it home: recognised once through Game.add_item
	var a := Adv.get_a(aid)
	a["equipment"].erase("weapon")
	w["_arrives_how"] = "recovered"
	Game.add_item(w, false)
	check(ItemStory.has_reunion(w, "recovered", aid), "coming home in a recovered chest is a reunion")
	eq(Provenance.owner_id(w), Provenance.SMITH_ID, "and the forge holds it again")


# ------------------------------------------------------------------ Hall of Fame and commissions
func test_famous_creations_and_commission() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var it := _sword()
	if not check(not it.is_empty() and aid != "", "a sword and an adventurer"):
		return
	var uid := int(it["uid"])
	Adv.give_item(Adv.get_a(aid), Game.take_uid(uid), 0)
	_boss_fight(aid, uid)
	var fs := ItemStory.famous_creations()
	if not check(not fs.is_empty(), "the Hall of Fame lists famous creations"):
		return
	var f: Dictionary = fs[0]
	eq(int(f["uid"]), uid, "the famous creation is the named blade")
	eq(str(f["name"]), ItemStory.earned_name(Game.find_uid_anywhere(uid)), "under its earned name")
	eq(str(f["owner"]), str(Adv.get_a(aid)["name"]), "with its current owner")
	check((f["deeds"] as Array).size() >= 2, "and its deeds (named + Epic)")
	check(bool(f["epic"]), "the boss kill also made it Epic")
	check(ItemStory.rumour_line("martha").contains(str(f["name"])), "the village talks about it")
	# fame brings a commission from another adventurer: "a blade like Wolfbane"
	var n0 := Shop.orders().size()
	ItemStory.on_day()
	var ord := {}
	for o in Shop.orders():
		if int(o.get("inspired_by", -1)) == uid:
			ord = o
	if not check(not ord.is_empty(), "a special commission follows the fame (%d orders before)" % n0):
		return
	check(str(ord["npc"]) != aid, "from another adventurer")
	check(str(ord["note"]).contains(str(f["name"])), "the note names the famous piece: %s" % ord["note"])
	eq(str(ord["slot"]), "weapon", "for the same kind of piece")
	check(ItemStory.fame_commission(uid).is_empty(), "only one such commission per piece")
	check(save_load("suite_story_fame"), "save/load")
	check(not ItemStory.famous_creations().is_empty() and ItemStory.st()["fame_orders"].has(str(uid)), "famous creations and fame orders persist")


# ------------------------------------------------------------------ workshop services
func test_reforge_keeps_identity() -> void:
	fresh_game()
	var it := _sword(80.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	Recognition.grant_epic(it, "test deed")
	ItemStory.name_item(it, "Hearthguard", "masterwork", "a test name")
	it["stats"]["durability"] = 0
	it["broken"] = true
	var q0 := float(it["quality"])
	var atk0 := Items.base_stat(it, "attack")
	Game.remove_def("coal", Game.count("coal"))
	check(not bool(ItemStory.reforge(uid, 110.0).get("ok", true)), "reforging needs coal")
	give("coal", 1)
	var r := ItemStory.reforge(uid, 110.0)
	check(bool(r.get("ok", false)), "reforged with coal")
	var w := Game.find_uid(uid)
	eq(int(w["uid"]), uid, "the uid is kept")
	eq(str(Provenance.maker(w)["id"]), Provenance.SMITH_ID, "the maker is kept")
	eq(ItemStory.earned_name(w), "Hearthguard", "the earned name is kept")
	check(w.has("epic"), "the Epic distinction is kept")
	check(float(w["quality"]) > q0, "fine rework raised the craftsmanship (%d → %d)" % [int(q0), int(w["quality"])])
	check(Items.base_stat(w, "attack") >= atk0, "the stats are not lowered")
	check(not w.get("broken", false) and int(w["stats"]["durability"]) == int(w["stats"]["durability_max"]), "made whole again")
	check(_kinds(w).has("reforged"), "a 'reforged' event in its history")
	eq(int(Provenance.st(w).get("reforged", 0)), 1, "counted once")
	eq(Game.count("coal"), 0, "one coal was used")
	# sharpening an adventurer's blade at the wheel
	var aid := _in_town_adv()
	var a := Adv.get_a(aid)
	var blade: Dictionary = a["equipment"].get("weapon", {})
	if blade.is_empty():
		skip("no adventurer weapon to sharpen")
		return
	var g0 := Game.gold()
	var s := ItemStory.sharpen(blade, 90.0, aid)
	check(bool(s.get("ok", false)), "the blade is sharpened")
	eq(str(blade.get("coating", {}).get("name", "")), "Fresh Edge", "with a fresh edge")
	check(_kinds(blade).has("sharpened"), "a 'sharpened' event in its history")
	check(Game.gold() > g0, "the adventurer paid for it")


# ------------------------------------------------------------------ a stranger with an old blade, talk about it
func test_stranger_and_talk() -> void:
	fresh_game()
	var aid := _in_town_adv()
	var it := _sword()
	if not check(not it.is_empty() and aid != "", "a sword and an adventurer"):
		return
	var uid := int(it["uid"])
	var a := Adv.get_a(aid)
	Adv.give_item(a, Game.take_uid(uid), 0)
	_boss_fight(aid, uid)
	# talk: the owner can be asked about it, and tells its real story
	var opts := Talk.options(aid, "village")
	var opt := {}
	for o in opts:
		if str(o["id"]) == "itemstory_%d" % uid:
			opt = o
	check(not opt.is_empty() and str(opt["label"]).begins_with("Ask about"), "the owner can be asked about the piece")
	var r := Talk.choose(aid, "itemstory_%d" % uid, "village")
	var w := Game.find_uid_anywhere(uid)
	check(str(r.get("text", "")).contains("Day") and str(r.get("text", "")).contains(ItemStory.earned_name(w)), "the story is told from its real events")
	check(ItemStory.has_reunion(w, "shown", aid), "being shown it is a reunion")
	# the pool: the smith's pieces are remembered; one that leaves the world can come back with a stranger
	ItemStory.on_day()
	check(ItemStory.st()["pool"].has(str(uid)), "the piece is remembered in the circulating pool")
	a["equipment"].erase("weapon")
	Provenance.lose(w, "the Barrow Fields", "buried with its owner", "barrow_fields")
	check(ItemStory.circulating().any(func(x): return int(x["uid"]) == uid), "a lost piece circulates")
	for c in Shop.customers().duplicate():
		Shop.remove_customer(str(c["npc"]))
	var cu := ItemStory.stranger_visit()
	if not check(not cu.is_empty(), "a stranger arrives with an old blade"):
		return
	var old: Dictionary = cu["item"]
	eq(int(old["uid"]), uid, "it is the very same piece")
	eq(str(Provenance.maker(old)["id"]), Provenance.SMITH_ID, "still bearing the Ironhand mark")
	eq(Provenance.owner_id(old), str(cu["npc"]), "now owned by the stranger")
	Shop.mark_arrived(str(cu["npc"]), false)
	check(ItemStory.at_counter(str(cu["npc"])), "the smith recognises it at the counter")
	Shop.do_repair(str(cu["npc"]), 90.0)
	check(_kinds(old).has("repaired"), "the repair joins its history")
	check(save_load("suite_story_stranger"), "save/load")
	check(Game.state.has("item_story") and ItemStory.st()["pool"].has(str(uid)), "the pool persists")
