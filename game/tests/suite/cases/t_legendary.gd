## Canonical v1.6 §6.2 — Legendary crafting: no automatic masterwork bonus; ordinary Designs cap at Rare whatever the
## rolls; only the designated advanced Designs can be Legendary, and only when every gate holds (the qualified worker's
## skill in the Design's craft >= 6, craftsmanship >= 115 % (a master specialist: their 112 % ceiling), fortune >= 95,
## rarity score >= 125). The same pipeline for the smith, specialists, work orders and the steward; found loot and
## existing Legendary pieces unchanged.
extends SuiteCase

const SMOKE := ["test_gates_and_boundaries", "test_real_pieces_through_the_pipeline"]
const DESIGNATED := ["starsteel_blade", "mithril_runeblade", "adamantine_warplate", "dragonscale_armor", "archmage_robe",
	"concord_runestone"]


func test_designations_and_rules_in_data() -> void:
	var lc: Dictionary = DB.crafting["rarity"].get("legendary_crafting", {})
	eq([int(lc.get("skill", 0)), int(lc.get("quality", 0)), int(lc.get("fortune", 0)), int(lc.get("score", 0))], [6, 115, 95, 125],
		"the gates: skill 6, craftsmanship 115 %, fortune 95, score 125")
	eq(str(DB.crafting["rarity"].get("crafted_cap", "")), "rare", "ordinary crafted work caps at Rare")
	var flagged := []
	for rid in DB.recipes:
		if bool(DB.recipe(str(rid)).get("legendary", false)):
			flagged.append(str(rid))
	flagged.sort()
	var want := DESIGNATED.duplicate()
	want.sort()
	eq(flagged, want, "exactly the six reviewed advanced Designs are Legendary Designs")


func test_gates_and_boundaries() -> void:
	var rid := "starsteel_blade"
	var b := Crafting.rarity_bonus(rid)
	check(b > 0.0, "the starmetal brings a rarity bonus (%.0f)" % b)
	eq(str(Crafting.crafted_rarity(rid, 115.0, 95, b, 6)["rarity"]), "legendary", "every gate exactly met: Legendary")
	var cases := {"skill 5": [115.0, 95, b, 5], "craftsmanship 114.9 %": [114.9, 95, b, 6], "fortune 94": [115.0, 94, b, 6]}
	for k in cases:
		var a: Array = cases[k]
		var rv := Crafting.crafted_rarity(rid, float(a[0]), int(a[1]), float(a[2]), int(a[3]))
		eq(str(rv["rarity"]), "rare", "%s: not Legendary — capped at Rare" % k)
		check(not (rv["legendary_why"] as Array).is_empty(), "%s: the reason is given (%s)" % [k, ", ".join(rv["legendary_why"])])
	# the score gate on its own: no material bonus, 115 % and a 95 fortune = 119.5 < 125
	var low := Crafting.crafted_rarity(rid, 115.0, 95, 0.0, 6)
	eq(str(low["rarity"]), "rare", "score 119.5 of 125: not Legendary")
	check(str(low["legendary_why"]).contains("rarity score"), "…because of the score")
	# a master specialist: their 112 % ceiling counts as the craftsmanship gate
	eq(str(Crafting.crafted_rarity("archmage_robe", 112.0, 97, Crafting.rarity_bonus("archmage_robe"), 7, true)["rarity"]), "legendary",
		"a master leatherworker at their ceiling (112 %) with a 97: Legendary")
	eq(str(Crafting.crafted_rarity("archmage_robe", 112.0, 97, Crafting.rarity_bonus("archmage_robe"), 7, false)["rarity"]), "rare",
		"…but 112 % is not enough for anyone else (115 %)")
	# ordinary Designs: never Legendary, however good
	var ord := Crafting.crafted_rarity("iron_longsword", 130.0, 100, 20.0, 10)
	eq(str(ord["rarity"]), "rare", "an ordinary Design at 130 % with a perfect roll: Rare")
	check(bool(ord.get("capped", false)), "…marked as capped")
	# no masterwork bonus in the crafted score; Masterwork is still the craftsmanship distinction
	var mw := Crafting.rarity_eval(120.0, 50, 0.0, true)
	check(bool(mw["masterwork"]) and float(mw["parts"]["masterwork"]) == 0.0, "masterwork: still a distinction, no score bonus")
	# the steward's working smith (craftsmanship never above 110 %) cannot make a Legendary
	eq(str(Crafting.crafted_rarity(rid, StewardSmith.QUALITY_CAP, 100, b, 10)["rarity"]), "rare", "the steward's smith: never Legendary")
	# found loot keeps its own rarity rule (unchanged)
	eq(Items.rarity_from(118.0, 95), "legendary", "found loot: the old rule, unchanged")


func test_rarity_distributions() -> void:
	# craftsmanship around a skilled hand's work and a fair fortune die: the share of each rarity
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var out := {}
	for label in ["ordinary 100 %", "ordinary 115 %", "designated 118 %, skill 7"]:
		var n := {"common": 0, "magic": 0, "rare": 0, "legendary": 0}
		for i in 4000:
			var q := clampf(rng.randfn(100.0 if label.begins_with("ordinary 100") else (115.0 if label.begins_with("ordinary 115") else 118.0), 6.0), 30.0, 130.0)
			var f := rng.randi_range(1, 100)
			var rid := "iron_longsword" if label.begins_with("ordinary") else "starsteel_blade"
			n[str(Crafting.crafted_rarity(rid, q, f, Crafting.rarity_bonus(rid), 7)["rarity"])] += 1
		out[label] = n
		note("%s: %s" % [label, str(n)])
	eq(int(out["ordinary 100 %"]["legendary"]) + int(out["ordinary 115 %"]["legendary"]), 0, "ordinary work: no Legendary at all")
	check(int(out["ordinary 100 %"]["magic"]) + int(out["ordinary 100 %"]["rare"]) > 3000, "ordinary good work stays rewarding (mostly Magic/Rare)")
	check(int(out["ordinary 115 %"]["rare"]) > 3500, "masterful ordinary work: almost always Rare")
	var leg := int(out["designated 118 %, skill 7"]["legendary"])
	check(leg > 40 and leg < 400, "a designated Design in masterful hands: Legendary but rare (%d of 4000)" % leg)


func test_real_pieces_through_the_pipeline() -> void:
	# the smith, smithing 6+, a starsteel blade at 118 % — Legendary only with a 95+ fortune
	train("smithing", 7)
	var d := {"edge": 10, "temper": 10, "fortune": 97}
	var leg := Crafting.build("starsteel_blade", [], 118.0, d, "digital")
	eq(str(leg.get("rarity", "")), "legendary", "the smith's starsteel blade, 118 %, fortune 97: Legendary")
	check(bool(leg.get("star", false)) and (leg["craft"].get("legendary_why", []) as Array).is_empty(), "…starred, nothing missing")
	var near := Crafting.build("starsteel_blade", [], 118.0, {"edge": 10, "temper": 10, "fortune": 90}, "digital")
	eq(str(near.get("rarity", "")), "rare", "the same work, fortune 90: Rare")
	check(str(near["craft"].get("legendary_why", [])).contains("fortune"), "…and the record says why (%s)" % str(near["craft"].get("legendary_why", [])))
	# a work order the smith forged, the arcane stages by a master arcanist (skill 8): the specialist meets the skill gate
	var wo := Crafting.build("mithril_runeblade", [], 117.0, {"edge": 10, "spellweave": 10, "fortune": 98}, "digital",
		{"smith": true, "skill_level": 8, "xp_skills": ["smithing"]})
	eq(str(wo.get("rarity", "")), "legendary", "work order: smith-forged, arcane stages by a master arcanist — Legendary")
	var wo2 := Crafting.build("mithril_runeblade", [], 117.0, {"edge": 10, "spellweave": 10, "fortune": 98}, "digital",
		{"smith": true, "skill_level": int(Game.player_level("arcane_metalwork")), "xp_skills": ["smithing"]})
	eq(str(wo2.get("rarity", "")), "rare", "the same piece with only the smith's basic arcane skill: Rare")
	# a master specialist on their own, at their ceiling
	var sp := Crafting.build("dragonscale_armor", [], 112.0, {"fortune": 99}, "digital",
		{"id": "app_x", "name": "Corwin Vell", "mark": "CV", "level": 8, "rank": "master", "rank_name": "Master", "skill_level": 8})
	eq(str(sp.get("rarity", "")), "legendary", "a master arcanist's dragonscale at 112 %, fortune 99: Legendary")
	var sp2 := Crafting.build("dragonscale_armor", [], 104.0, {"fortune": 99}, "digital",
		{"id": "app_y", "name": "Wren", "mark": "W", "level": 6, "rank": "journeyman", "rank_name": "Journeyman", "skill_level": 6})
	check(str(sp2.get("rarity", "")) in ["rare"], "a journeyman's dragonscale (104 %): Rare at most (its minimum Rare kept)")
	# an ordinary Design: capped, and the record says so
	var ordp := Crafting.build("iron_longsword", [], 125.0, {"edge": 20, "temper": 12, "fortune": 100}, "digital")
	check(str(ordp.get("rarity", "")) == "rare" and bool(ordp["craft"].get("rarity_capped", false)), "an ordinary sword at 125 %: Rare, capped")


func test_existing_legendaries_kept_in_an_old_save() -> void:
	var path := "res://tests/fixtures/saves/build-0.14.6.json"
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(raw is Dictionary, "the 0.14.6 golden save is present"):
		return
	var before := {}
	_collect((raw as Dictionary)["data"], before)
	check(before.size() > 0, "it holds Legendary pieces (%d)" % before.size())
	var f := FileAccess.open(Saves.path("t_leg_old"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(path))
	f.close()
	if not check(Saves.load_slot("t_leg_old"), "it loads"):
		return
	var after := {}
	_collect(Game.state, after)
	for uid in before:
		eq(str(after.get(uid, "?")), "legendary", "piece %s stays Legendary" % uid)
	Saves.delete("t_leg_old")


func _collect(o: Variant, acc: Dictionary) -> void:
	if o is Dictionary:
		var d: Dictionary = o
		if str(d.get("rarity", "")) == "legendary" and d.has("uid"):
			acc[str(int(d["uid"]))] = "legendary"
		for v in d.values():
			_collect(v, acc)
	elif o is Array:
		for v in o:
			_collect(v, acc)
