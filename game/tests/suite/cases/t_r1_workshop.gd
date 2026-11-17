## R1 (decision D-5; STAFF-004, HA-025; canonical §1.2 "a physical workshop matters", §4.3): field hirelings do field
## work only. In their allocated hours they gather (ore, coal, herbs, salt, runestone blanks), hunt and study relics and
## trade on the roads; they no longer turn stored materials into finished goods without a station, and smithing has no
## field work. Station production by the smith and the workshop's specialists is untouched.
extends SuiteCase

const SMOKE := ["test_hirelings_produce_nothing_off_station"]


func _hand(alloc: Dictionary, levels: Dictionary) -> Dictionary:
	var h := Hire._new_entry("r1w", "Field Hand", "applicant_3", "Human", "", levels, 3)
	h["traits"] = []
	var full := {}
	for s in DB.work_skills:
		full[s] = int(alloc.get(s, 0))
	h["alloc"] = full
	Hire.list().append(h)
	return h


func _work(hours: int) -> void:
	var m0: int = Game.state["minute"]
	Game.state["minute"] = 10 * 60
	for i in hours:
		Hire.work_hour(10)
	Game.state["minute"] = m0


func test_hirelings_produce_nothing_off_station() -> void:
	_hand({"alchemy": 50, "runecraft": 50}, {"alchemy": 8, "runecraft": 8})
	give("herb_moonwort", 6)
	give("herb_emberleaf", 4)
	give("reagent_salt", 4)
	give("runestone_blank", 4)
	var finished := ["potion_healing", "oil_whetstone", "runestone_ember", "runestone_ward"]
	var before := {}
	for d in finished + ["herb_moonwort", "herb_emberleaf", "reagent_salt", "runestone_blank"]:
		before[d] = Game.count(d)
	_work(48)
	for d in finished:
		eq(Game.count(d), int(before[d]), "no %s is made without a station" % d)
	for d in ["herb_moonwort", "herb_emberleaf", "reagent_salt", "runestone_blank"]:
		check(Game.count(d) >= int(before[d]), "stored %s is not consumed" % d)
	check(Game.count("herb_moonwort") + Game.count("herb_emberleaf") + Game.count("reagent_salt") + Game.count("runestone_blank")
		> int(before["herb_moonwort"]) + int(before["herb_emberleaf"]) + int(before["reagent_salt"]) + int(before["runestone_blank"]),
		"the hand gathered raw materials in the field")
	Hire.list().erase(Hire.get_h("r1w"))


func test_smithing_has_no_field_work() -> void:
	_hand({"smithing": 100}, {"smithing": 6})
	give("ore_iron", 6)
	var ore := Game.count("ore_iron")
	var ingots := Game.count("ingot_iron")
	var g0 := Game.gold()
	_work(24)
	check(Game.count("ore_iron") >= ore, "no ore is consumed by off-station smelting (Borin's own mining may add some)")
	eq(Game.count("ingot_iron"), ingots, "no ingot appears")
	eq(Game.gold(), g0, "no horseshoes are sold")
	check(Hire.NO_FIELD_WORK.has("smithing"), "smithing is marked as having no field work (the hireling panel says so)")
	Hire.list().erase(Hire.get_h("r1w"))


func test_field_work_still_pays() -> void:
	_hand({"mining": 50, "travelling": 50}, {"mining": 5, "travelling": 4})
	var ore := Game.count("ore_iron") + Game.count("coal") + Game.count("ore_copper") + Game.count("ore_silver")
	var g0 := Game.gold()
	_work(48)
	check(Game.count("ore_iron") + Game.count("coal") + Game.count("ore_copper") + Game.count("ore_silver") > ore, "mining brings in ore and coal")
	check(Game.gold() > g0, "road trade brings in coin (payer 'market')")
	Hire.list().erase(Hire.get_h("r1w"))


func test_relic_study_is_field_work() -> void:
	_hand({"relic_hunting": 100}, {"relic_hunting": 6})
	var r := Items.make("relic_unknown_tablet")
	Game.add_item(r, false)
	var uid := int(r["uid"])
	_work(48)
	var it := Game.find_uid(uid)
	check(not it.is_empty() and not Regions.is_unidentified(it), "the hand studied the relic (the same piece, identified)")
	Hire.list().erase(Hire.get_h("r1w"))
