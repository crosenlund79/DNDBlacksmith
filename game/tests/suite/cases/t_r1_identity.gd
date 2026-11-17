## R1 "Integration & Foundation Closure" — item identity hygiene (canonical §6.1 "one creation, one authentic history").
##  EQ-007  identifying a relic keeps its uid, its Lore and its chain (decision D-2); a stacked relic is split first;
##  BUG-042 setting a rune never renames the piece; a Common → Magic change is recorded on the event (decision D-3);
##  BUG-017 a hireling who is let go leaves with their gear on record (a hand-over event, the holdings archive);
##  EQ-004  a merchant's unsold stock with a history is kept on record when it is replaced; rolled stock needs none;
##  EQ-012  a lost or destroyed piece leaves a permanent structured tombstone that survives save/load;
##  save step 9 builds tombstones for old saves' lost/destroyed pieces and is idempotent.
extends SuiteCase

const SMOKE := ["test_identify_keeps_uid_and_chain", "test_socket_never_renames", "test_tombstone_survives_save_load"]


func _relic(def := "relic_unknown_arms", qty := 1) -> Dictionary:
	var r := Items.make(def, {"qty": qty})
	Game.add_item(r, false)
	return r


func test_identify_keeps_uid_and_chain() -> void:
	var r := _relic("relic_unknown_arms")
	var uid := int(r["uid"])
	var ev := Lore.record("found", "A relic was dug from the barrow mound.", {"items": [r], "place": "barrow_fields", "importance": 1})
	var res := Regions.identify(uid, 95.0, "Brannoc")
	check(not res.is_empty(), "the relic is identified")
	eq(int(res.get("uid", -1)), uid, "the identified piece keeps the relic's uid")
	check(not Game.find_uid(uid).is_empty(), "the piece with that uid is in the stores")
	eq(Game.inventory().filter(func(x): return int(x.get("uid", -1)) == uid).size(), 1, "exactly one piece holds that uid")
	check(Game.inventory().filter(func(x): return str(x.get("def", "")) == "relic_unknown_arms").is_empty(), "the relic itself is not left behind")
	var was: Dictionary = res.get("identified", {})
	eq(str(was.get("def", "")), "relic_unknown_arms", "what it was is recorded on the piece")
	eq(str(was.get("by", "")), "Brannoc", "and who studied it")
	var kinds := []
	for e in Lore.st()["order"]:
		var le: Dictionary = Lore.st()["events"][e]
		if (le.get("items", []) as Array).has(uid):
			kinds.append(str(le["kind"]))
	check(kinds.has("found") and kinds.has("identified"), "its Lore keeps the finding and the study (%s)" % str(kinds))
	if Provenance.applies(res):
		check((Provenance.st(res).get("events", []) as Array).has(ev), "an identified piece of equipment carries the relic's earlier events")
	check(save_load("suite_r1_identify"), "save → load")
	var back := Game.find_uid(uid)
	check(not back.is_empty() and str(back.get("identified", {}).get("def", "")) == "relic_unknown_arms", "after save/load it is the same identified piece")
	eq(Uniques.audit().size(), 0, "no Unique is held twice")


func test_identify_splits_a_stack_first() -> void:
	var r := _relic("relic_unknown_tablet", 3)
	var stack_uid := int(r["uid"])
	var res := Regions.identify(stack_uid, 90.0, "Brannoc")
	check(not res.is_empty(), "one relic of the stack is identified")
	check(int(res.get("uid", -1)) != stack_uid, "the studied relic was split off as its own piece")
	eq(int(res.get("split_from", -1)), stack_uid, "and remembers the stack it came from")
	var stack := Game.find_uid(stack_uid)
	eq(int(stack.get("qty", 0)), 2, "the stack keeps its uid with one fewer relic")
	eq(str(stack.get("def", "")), "relic_unknown_tablet", "the stack is still unidentified")


func test_socket_never_renames() -> void:
	train("runecraft", 3)
	var it := craft("iron_longsword", 90.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	var name0 := str(it["name"])
	var uid := int(it["uid"])
	give("runestone_ember", 1)
	check(Crafting.socket(uid, "runestone_ember", 90.0), "a runestone is set into it")
	var after := Game.find_uid(uid)
	eq(str(after["name"]), name0, "the piece keeps its own name")
	check(not str(after["name"]).begins_with("Runed"), "no 'Runed' prefix")


func test_socket_rarity_change_recorded() -> void:
	train("runecraft", 3)
	var it := craft("iron_longsword", 90.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	it["rarity"] = "common"
	var uid := int(it["uid"])
	give("runestone_ember", 1)
	check(Crafting.socket(uid, "runestone_ember", 90.0), "a runestone is set into a Common piece")
	var after := Game.find_uid(uid)
	eq(str(after["rarity"]), "magic", "it is Magic now (it carries a rune's property)")
	var rec := {}
	for id in Provenance.st(after).get("events", []):
		var e := Lore.event(str(id))
		if str(e.get("kind", "")) == "enchanted":
			rec = e
	eq(str(rec.get("data", {}).get("rarity_from", "")), "common", "the event records the rarity it had")
	eq(str(rec.get("data", {}).get("rarity_to", "")), "magic", "and the rarity it has now")
	check(str(rec.get("text", "")).contains("Magic"), "the history line says so: " + str(rec.get("text", "")))


func test_dismissed_hireling_gear_handed_over() -> void:
	var h := Hire._new_entry("r1h", "Test Hand", "applicant_1", "Human", "", {"mining": 3}, 3)
	h["traits"] = []
	Hire.list().append(h)
	var it := craft("iron_longsword", 88.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	var uid := int(it["uid"])
	check(Hire.equip("r1h", uid), "the hireling takes it up")
	Hire.dismiss("r1h")
	check(Hire.get_h("r1h").is_empty(), "the hireling is let go")
	var held := ItemRegistry.where(uid)
	eq(str(held.get("holder", "")), "holdings", "the piece is kept whole in the holdings archive")
	var kinds := []
	for id in Provenance.st(ItemRegistry.find(uid)).get("events", []):
		kinds.append(str(Lore.event(str(id)).get("kind", "")))
	check(kinds.has("departed"), "its history records the hand-over (%s)" % str(kinds))
	eq((ItemRegistry.scan()["dup"] as Array).size(), 0, "no uid is held twice")


func test_restock_exit_rule() -> void:
	var it := craft("iron_longsword", 90.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	Game.inventory().erase(it)   # it went to the caravan's wagons (as a sold piece does)
	var rolled := Items.make("sword_iron", {"quality": 70.0})
	var stock := [{"def": str(it["def"]), "item": it, "price": 100}, {"def": "sword_iron", "item": rolled, "price": 50},
		{"def": "coal", "qty": 4, "price": 2}]
	eq(ItemRegistry.retire_stock(stock, "caravan_master", "the Brask caravan"), 1, "only the piece with a history is kept on record")
	eq(str(ItemRegistry.where(int(it["uid"])).get("holder", "")), "holdings", "the forge's piece stays findable")
	check(ItemRegistry.where(int(rolled["uid"])).is_empty(), "stock the merchant rolled for its own shelf needs no record")


func test_tombstone_survives_save_load() -> void:
	var it := craft("iron_longsword", 95.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	var uid := int(it["uid"])
	it["named"] = "Greywater"
	Provenance.destroy(it, "shattered on a troll's skull")
	Game.inventory().erase(it)
	var t := ItemRegistry.tombstone_of(uid)
	check(not t.is_empty(), "a tombstone is written")
	eq(str(t.get("cause", "")), "destroyed", "its cause")
	eq(str(t.get("named", "")), "Greywater", "its earned name")
	eq(str(t.get("maker", {}).get("id", "")), Provenance.SMITH_ID, "its maker")
	check(str(t.get("event", "")) != "", "it points to the Lore event")
	check(save_load("suite_r1_tomb"), "save → load")
	var t2 := ItemRegistry.tombstone_of(uid)
	eq(str(t2.get("named", "")), "Greywater", "the tombstone survives save/load")


func test_lost_piece_recovered_keeps_tombstone() -> void:
	var it := craft("iron_longsword", 90.0)
	if not check(not it.is_empty(), "a longsword is forged"):
		return
	Provenance.lose(it, "the Barrow Fields", "dropped in the mud", "barrow_fields")
	check(not ItemRegistry.tombstone_of(int(it["uid"])).is_empty(), "losing a piece writes a tombstone")
	Provenance.transfer(it, "garrick", "found", "barrow_fields")
	check(ItemRegistry.tombstone_of(int(it["uid"])).has("recovered"), "a lost piece that is found again keeps its tombstone, marked recovered")


func test_save_step_9_builds_tombstones_idempotently() -> void:
	var data := {"lore": {"order": ["ev_1", "ev_2"], "events": {
		"ev_1": {"id": "ev_1", "kind": "destroyed", "day": 12, "text": "Old Fang was destroyed — melted in dragonfire.", "items": [9001]},
		"ev_2": {"id": "ev_2", "kind": "forged", "day": 3, "text": "Forged.", "items": [9002]}}}}
	eq(ItemRegistry.migrate_tombstones(data), 1, "one tombstone reconstructed from the Lore event")
	var t: Dictionary = data.get("item_registry", {}).get("tombstones", {}).get("9001", {})
	eq(str(t.get("cause", "")), "destroyed", "its cause")
	eq(int(t.get("day", 0)), 12, "its day")
	check(bool(t.get("reconstructed", false)), "marked as reconstructed (the piece itself no longer exists)")
	var snap := JSON.stringify(data)
	eq(ItemRegistry.migrate_tombstones(data), 0, "running it again adds nothing")
	eq(JSON.stringify(data), snap, "and changes nothing")
