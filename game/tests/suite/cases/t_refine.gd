## Refinement (UX iteration): refine, rework, upgrade and reforge an existing piece — stat calculations, the
## per-piece budget and craftsmanship ceiling, no rarity change and no stats beyond a fresh piece, proportionate
## failure, and identity kept through many improvements and save/load (uid, maker & mark, name, rarity, Epic,
## owners, every earlier Lore event + exactly one new event per improvement, an awakened spirit still awake).
extends SuiteCase

const SMOKE := ["test_refine_raises_quality", "test_identity_kept"]


func _sword(q := 84.0, fortune := 1) -> Dictionary:
	give("ingot_iron", 4)
	give("leather_cured", 2)
	return craft("iron_longsword", q, {"edge": 12, "temper": 8, "fortune": fortune})


func _kinds(it: Dictionary) -> Array:
	return ItemStory.events_of(it).map(func(e): return str(e.get("kind", "")))


func _events(it: Dictionary) -> Array:
	return (Provenance.st(it).get("events", []) as Array).duplicate()


func _stats_within_fresh(it: Dictionary, before: Dictionary, what: String) -> void:
	var cap := Refinement.fresh_cap(it)
	for k in it["stats"]:
		if cap.has(k) and not str(k) in ["durability"]:
			check(int(it["stats"][k]) <= maxi(int(cap[k]), int(before.get(k, 0))), "%s: %s %d stays within a fresh piece's %d" % [what, k, int(it["stats"][k]), int(cap[k])])


# ------------------------------------------------------------------ refine
func test_refine_raises_quality() -> void:
	fresh_game()
	var it := _sword(84.0)
	if not check(not it.is_empty(), "a sword is forged"):
		return
	var uid := int(it["uid"])
	give("reagent_salt", 2)
	var salt0 := Game.count("reagent_salt")
	var q0 := float(it["quality"])
	var atk0 := int(it["stats"]["attack"])
	var rar0 := str(it["rarity"])
	var p := Refinement.plan(it, "refine")
	check(bool(p["ok"]), "refining is possible (%s)" % str(p["why"]))
	eq(str(p["station"]), "grinding_wheel", "a metal piece is refined at the grinding wheel")
	check(not (p["rows"] as Array).is_empty(), "the plan shows a before / after comparison")
	var r := Refinement.perform(uid, "refine", 110.0)
	check(bool(r.get("ok", false)), "refined: " + str(r.get("text", "")))
	eq(str(r["outcome"]), "success", "a 110% check succeeds")
	var w := Game.find_uid(uid)
	check(float(w["quality"]) > q0, "craftsmanship rose (%.1f → %.1f)" % [q0, float(w["quality"])])
	check(float(w["quality"]) <= Refinement.ceiling(w) + 0.01, "… but not past the ceiling %.1f" % Refinement.ceiling(w))
	check(int(w["stats"]["attack"]) >= atk0, "attack did not fall")
	eq(str(w["rarity"]), rar0, "the rarity is unchanged")
	eq(Game.count("reagent_salt"), salt0 - 1, "one salt (polishing grit) was used")
	eq(Refinement.used(w, "refine"), 1, "one refinement counted")
	check(_kinds(w).has("refined"), "a 'refined' event in its history")
	var ev := Lore.event(str(r["event"]))
	eq(str(ev.get("data", {}).get("action", "")), "refine", "the event's data names the action")
	check(not (ev.get("data", {}).get("changes", []) as Array).is_empty(), "… and lists the stat changes")
	eq(str(ev.get("data", {}).get("smith", "")), Provenance.SMITH_ID, "… and the smith")
	check((ev.get("data", {}).get("materials", {}) as Dictionary).has("reagent_salt"), "… and the materials")


func test_refine_budget_and_ceiling() -> void:
	fresh_game()
	var it := _sword(84.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	var before := (it["stats"] as Dictionary).duplicate()
	give("reagent_salt", 6)
	var salt0 := Game.count("reagent_salt")
	var qs := []
	for i in 3:
		var r := Refinement.perform(uid, "refine", 118.0)
		check(bool(r.get("ok", false)) and str(r.get("outcome", "")) == "success", "refine %d succeeds" % (i + 1))
		qs.append(float(Game.find_uid(uid)["quality"]))
	var w := Game.find_uid(uid)
	check(float(qs[2]) - float(qs[1]) <= float(qs[1]) - float(qs[0]) + 0.01, "each refinement gives no more than the last (%s)" % str(qs))
	var p := Refinement.plan(w, "refine")
	check(not bool(p["ok"]), "a fourth refinement is refused")
	var r4 := Refinement.perform(uid, "refine", 118.0)
	check(not bool(r4.get("ok", true)), "perform refuses it too: " + str(r4.get("text", "")))
	eq(Game.count("reagent_salt"), salt0 - 3, "no grit spent on the refused attempt")
	check(float(w["quality"]) <= Refinement.ceiling(w) + 0.01, "never past the ceiling")
	check(Refinement.ceiling(w) <= Refinement.origin_quality(w) + 15.01, "the ceiling is the original work +15 at most")
	_stats_within_fresh(w, before, "after three refinements")


func test_refine_failure_is_small() -> void:
	fresh_game()
	var it := _sword(90.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	give("reagent_salt", 2)
	var q0 := float(it["quality"])
	var n0 := _events(it).size()
	var r := Refinement.perform(uid, "refine", 20.0)
	check(bool(r.get("ok", false)), "the attempt is made")
	eq(str(r["outcome"]), "fail", "a 20% check slips")
	var w := Game.find_uid(uid)
	check(not w.is_empty(), "the piece still exists")
	check(q0 - float(w["quality"]) > 0.0 and q0 - float(w["quality"]) <= 3.01, "only a little craftsmanship is lost (%.1f → %.1f)" % [q0, float(w["quality"])])
	check(int(w["stats"]["durability"]) >= 1, "durability stays above zero")
	eq(Refinement.used(w, "refine"), 0, "a slip does not use the budget")
	eq(_events(w).size(), n0 + 1, "the slip is one event in its history")
	var mid := Refinement.perform(uid, "refine", 60.0)
	eq(str(mid.get("outcome", "")), "partial", "a 60% check does not take")


# ------------------------------------------------------------------ rework
func test_rework_within_legal_range() -> void:
	fresh_game()
	Property.dev_grant_all()
	var it := _sword(92.0)
	if not check(not it.is_empty(), "a sword"):
		return
	Items.apply_rarity(it, "rare")   # setup: a rare piece with two affixes
	var uid := int(it["uid"])
	var name0 := str(it["name"])
	var naff := (it["affixes"] as Array).size()
	var ts := Refinement.rework_targets(it)
	var aff: Dictionary = {}
	for t in ts:
		if str(t["kind"]) == "affix":
			aff = t
			break
	if not check(not aff.is_empty(), "the rare sword has an affix to re-cut"):
		return
	give("reagent_salt", 4)
	give("coal", 4)
	give("ingot_iron", 4)
	var r := Refinement.perform(uid, "rework", 100.0, {"target": str(aff["id"]), "roll": 20})
	check(bool(r.get("ok", false)), "reworked: " + str(r.get("text", r)))
	var w := Game.find_uid(uid)
	var i := int(str(aff["id"]).get_slice(":", 1))
	eq(int(w["affixes"][i]["value"]), int(aff["hi"]), "a natural 20 gives the top of the legal range")
	var r2 := Refinement.perform(uid, "rework", 100.0, {"target": str(aff["id"]), "roll": 1})
	check(bool(r2.get("ok", false)), "reworked again")
	eq(int(w["affixes"][i]["value"]), int(aff["lo"]), "a 1 gives the bottom of the legal range")
	eq(str(w["rarity"]), "rare", "the rarity is unchanged")
	eq((w["affixes"] as Array).size(), naff, "no affix added or removed")
	eq(str(w["name"]), name0, "the name is unchanged")
	var p := Refinement.plan(w, "rework", {"target": str(aff["id"])})
	check(not bool(p["ok"]), "the rework budget (2) is spent")
	eq(Refinement.used(w, "rework"), 2, "two reworks counted")


func test_rework_base_stat() -> void:
	fresh_game()
	var it := _sword(92.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	var before := (it["stats"] as Dictionary).duplicate()
	give("ingot_iron", 2)
	give("coal", 2)
	var t := Refinement._target(it, "stat:attack")
	eq(str(Refinement.station_for(it, "rework", "stat:attack")), "anvil", "a physical stat is re-cut at the anvil")
	var r := Refinement.perform(uid, "rework", 100.0, {"target": "stat:attack", "roll": 20})
	check(bool(r.get("ok", false)), "reworked the edge: " + str(r.get("text", r)))
	var w := Game.find_uid(uid)
	eq(int(w["stats"]["attack"]), int(t["hi"]), "the edge die at 20 gives the top of the range")
	_stats_within_fresh(w, before, "after a re-cut edge")


# ------------------------------------------------------------------ upgrade
func test_upgrade_one_material_step() -> void:
	fresh_game()
	var it := _sword(92.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	give("ingot_steel", 2)
	give("coal", 2)
	var p0 := Refinement.plan(it, "upgrade")
	eq(str(p0.get("next_step", {}).get("to", "")), "steel", "iron work steps up to steel")
	var gate := Crafting.recipe_locked_reason("smelt_steel")
	if gate != "":
		check(not bool(p0["ok"]) and str(p0["why"]).contains("Steel"), "without the know-how the upgrade is refused: " + str(p0["why"]))
		sys("skilltree", "unlock_all")
	train("smithing", 6)
	var atk0 := int(it["stats"]["attack"])
	var dur0 := int(it["stats"]["durability_max"])
	var before := (it["stats"] as Dictionary).duplicate()
	var r := Refinement.perform(uid, "upgrade", 100.0)
	check(bool(r.get("ok", false)) and str(r.get("outcome", "")) == "success", "upgraded: " + str(r.get("text", r)))
	var w := Game.find_uid(uid)
	eq(Refinement.material_of(w), "steel", "it is steel work now")
	check(int(w["stats"]["attack"]) > atk0, "attack rose (%d → %d)" % [atk0, int(w["stats"]["attack"])])
	check(int(w["stats"]["attack"]) <= maxi(int(round(atk0 * 1.18)) + 1, atk0), "by no more than the material ratio")
	check(int(w["stats"]["durability_max"]) >= dur0, "durability did not fall")
	var cap := Refinement.fresh_cap(w, "steel")
	check(int(w["stats"]["attack"]) <= maxi(int(cap["attack"]), atk0), "never past a fresh steel piece (%d)" % int(cap["attack"]))
	eq(str(w["def"]), "sword_iron", "the same kind of piece (def unchanged)")
	eq(Items.tier(w), 2, "orders asking for steel or better accept it")
	eq(str(w["rarity"]), str(it["rarity"]), "rarity unchanged")
	check(Items.tooltip(w).contains("Steel work"), "the tooltip says it was upgraded")
	var p2 := Refinement.plan(w, "upgrade")
	check(not bool(p2["ok"]), "only one material step per piece")
	_stats_within_fresh(w, before, "after the upgrade")


func test_upgrade_failure_spends_material_only() -> void:
	fresh_game()
	sys("skilltree", "unlock_all")
	train("smithing", 6)
	var it := _sword(92.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	give("ingot_steel", 1)
	give("coal", 1)
	var steel0 := Game.count("ingot_steel")
	var atk0 := int(it["stats"]["attack"])
	var r := Refinement.perform(uid, "upgrade", 30.0)
	check(bool(r.get("ok", false)), "the attempt is made")
	eq(str(r["outcome"]), "fail", "a 30% check fails")
	var w := Game.find_uid(uid)
	eq(Refinement.material_of(w), "iron", "still iron work")
	eq(int(w["stats"]["attack"]), atk0, "attack unchanged")
	eq(Game.count("ingot_steel"), steel0 - 1, "the steel was spent")
	eq(Refinement.used(w, "upgrade"), 0, "the upgrade can still be tried again")


# ------------------------------------------------------------------ reforge, same pipeline
func test_reforge_same_format() -> void:
	fresh_game()
	var it := _sword(80.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	it["stats"]["durability"] = 0
	it["broken"] = true
	give("coal", 1)
	var r := ItemStory.reforge(uid, 110.0)
	check(bool(r.get("ok", false)), "reforged through the old entry point")
	eq(str(r.get("kind", "")), "reforged", "kind reforged")
	var ev := Lore.event(str(r.get("event", "")))
	eq(str(ev.get("kind", "")), "reforged", "one 'reforged' Lore event")
	eq(str(ev.get("data", {}).get("action", "")), "reforge", "with the same data format as the others")
	check(str(ev.get("text", "")).begins_with("Reforged at the Ironhand forge"), "the history line reads as before: " + str(ev.get("text", "")))
	var w := Game.find_uid(uid)
	check(not w.get("broken", false), "made whole")


# ------------------------------------------------------------------ identity through everything, and save/load
func test_identity_kept() -> void:
	fresh_game()
	Property.dev_grant_all()
	sys("skilltree", "unlock_all")
	train("smithing", 8)
	var it := _sword(84.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	Recognition.grant_epic(it, "a test deed")
	ItemStory.name_item(it, "Hearthguard", "masterwork", "a test name")
	ItemSpirit.awaken(it, "deed")
	var awake0 := ItemSpirit.awake(it)
	check(awake0, "the sword's spirit is awake")
	var maker0 := (Provenance.maker(it) as Dictionary).duplicate()
	var owners0 := Provenance.owners(it).duplicate(true)
	var ev0 := _events(it)
	var name0 := str(it["name"])
	var rar0 := str(it["rarity"])
	give("reagent_salt", 6)
	give("coal", 8)
	give("ingot_iron", 4)
	give("ingot_steel", 2)
	var done := 0
	for step in [["refine", 112.0, {}], ["refine", 100.0, {}], ["rework", 100.0, {"target": "stat:attack", "roll": 15}], ["upgrade", 100.0, {}],
			["reforge", 110.0, {}], ["refine", 30.0, {}], ["reforge", 115.0, {}]]:
		var r := Refinement.perform(uid, str(step[0]), float(step[1]), step[2])
		if check(bool(r.get("ok", false)), "%s: %s" % [str(step[0]), str(r.get("text", r))]):
			done += 1
	var w := Game.find_uid(uid)
	eq(int(w["uid"]), uid, "the same uid")
	eq(str(Provenance.maker(w).get("id", "")), str(maker0.get("id", "")), "the same maker")
	eq(str(Provenance.maker(w).get("mark", "")), str(maker0.get("mark", "")), "the same mark")
	eq(int(Provenance.maker(w).get("day", -1)), int(maker0.get("day", -2)), "the same day of making")
	eq(str(w["name"]), name0, "the same name")
	eq(ItemStory.earned_name(w), "Hearthguard", "the earned name kept")
	eq(str(w["rarity"]), rar0, "the same rarity")
	check(w.has("epic"), "Epic kept")
	eq(Provenance.owners(w).size(), owners0.size(), "the owners kept")
	eq(ItemSpirit.awake(w), awake0, "the spirit is as awake as before")
	var ev1 := _events(w)
	for e in ev0:
		check(ev1.has(e), "the earlier event %s is kept" % str(e))
	eq(ev1.size(), ev0.size() + done, "exactly one new event per improvement")
	var ks := _kinds(w)
	for k in ["forged", "refined", "reworked", "upgraded", "reforged"]:
		check(ks.has(k), "its story records '%s'" % k)
	check(save_load("suite_refine_identity"), "save/load")
	var b := Game.find_uid(uid)
	eq(str(Provenance.maker(b).get("id", "")), str(maker0.get("id", "")), "the maker survives save/load")
	eq(_events(b).size(), ev1.size(), "the events survive save/load")
	eq(Refinement.used(b, "refine"), 2, "the refine count survives save/load")
	eq(Refinement.material_of(b), "steel", "the upgrade survives save/load")
	eq(ItemSpirit.awake(b), awake0, "the spirit survives save/load")


func test_many_reforges_keep_the_forging() -> void:
	fresh_game()
	var it := _sword(84.0)
	if not check(not it.is_empty(), "a sword"):
		return
	var uid := int(it["uid"])
	var first := str(_events(it)[0])
	give("coal", 30)
	for i in 30:
		Refinement.perform(uid, "reforge", 100.0)
	var w := Game.find_uid(uid)
	check(_events(w).has(first), "the forging is still in its record after 30 reforges")
	check(_kinds(w).has("forged"), "… and in its story")
	check(float(w["quality"]) <= Refinement.ceiling(w) + 0.01, "repeated reforging never passes the ceiling")


func test_apprentice_piece_keeps_maker() -> void:
	fresh_game()
	var maker := {"id": "app_suite", "name": "Tomas Reed", "mark": "app_suite", "level": 3, "supervised": true, "rank": "apprentice"}
	var it := Crafting.build("iron_longsword", [], 88.0, {"edge": 10, "temper": 6, "fortune": 1}, "digital", maker)
	if not check(not it.is_empty(), "an apprentice's sword"):
		return
	var uid := int(it["uid"])
	give("reagent_salt", 1)
	var r := Refinement.perform(uid, "refine", 105.0)
	check(bool(r.get("ok", false)), "the apprentice's piece can be refined")
	var w := Game.find_uid(uid)
	eq(str(Provenance.maker(w).get("id", "")), "app_suite", "the apprentice is still the maker")
	eq(str(Provenance.maker(w).get("supervisor", "")), Provenance.SMITH_ID, "under the smith's eye, as before")
	check(save_load("suite_refine_app"), "save/load")
	eq(str(Provenance.maker(Game.find_uid(uid)).get("id", "")), "app_suite", "and after save/load")


func test_old_piece_without_record() -> void:
	fresh_game()
	var it := _sword(84.0)
	if not check(not it.is_empty(), "a sword"):
		return
	it.erase("refine")
	eq(Refinement.left(it, "refine"), 3, "a piece from an old save has its full budget")
	eq(Refinement.material_of(it), "iron", "its material comes from its recipe")
	check(save_load("suite_refine_old"), "an old-shaped piece saves and loads")
	check(not Game.find_uid(int(it["uid"])).has("refine"), "nothing is added until it is worked on")
