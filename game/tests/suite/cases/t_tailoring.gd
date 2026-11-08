## Textile & Tailoring and the wider equipment range (iteration 010): fibres are spun and woven into cloth at the
## real stations and sewn into a robe that helps a spellcaster; the tailoring nodes gate the recipes; weapon and
## armour variants differ the way their kind should (two-handers hit harder, rapiers are faster, plate protects
## more than mail, mail more than leather); everything survives save/load.
extends SuiteCase

const SMOKE := ["test_nodes_gate_tailoring", "test_variants_differ"]


func _make(rid: String, q := 96.0, dice := {"edge": 12, "guard": 12, "temper": 12, "spellweave": 10, "fortune": 50}) -> Dictionary:
	Vitality.set_fatigue(0.0)
	return craft(rid, q, dice)


## Learn a node the legitimate way: its prerequisites first, then the node's own requirements are checked by unlock().
func _learn(id: String) -> String:
	if SkillTree.is_unlocked(id):
		return ""
	for p in SkillTree.node(id).get("requires", {}).get("nodes", []):
		var e := _learn(str(p))
		if e != "":
			return e
	var req: Dictionary = SkillTree.node(id).get("requires", {})
	Game.add_gold(int(req.get("gold", 0)) + 50, "commissions", "tuition (test)")
	return SkillTree.unlock(id)


func test_nodes_gate_tailoring() -> void:
	fresh_game()
	Property.dev_grant_all()
	check(SkillTree.recipe_node("weave_linen") == "ta_spin" and SkillTree.recipe_node("archmage_robe") == "ta_archmage",
		"the tailoring recipes belong to tailoring nodes")
	check(SkillTree.station_node("loom") == "ta_spin" and SkillTree.station_node("cutting_table") == "ta_garments"
		and SkillTree.station_node("tailors_bench") == "ta_garments", "the loom, cutting table and tailor's bench are taught by the tree")
	check(craft_blocker("weave_linen") != "" and craft_blocker("novice_robe") != "", "a new smith cannot weave or tailor yet")
	check(Crafting.station_locked_reason("loom") != "", "the loom is locked at the start: %s" % Crafting.station_locked_reason("loom"))
	# ta_spin needs Enchanted Stitching 1 and flax in hand at least once
	check(SkillTree.unlock("ta_spin") != "", "spinning & weaving needs skill and flax first")
	train("enchanted_stitching", 1)
	give("flax_bundle", 1)
	eq(SkillTree.unlock("ta_spin"), "", "with flax seen and the skill, Spinning & Weaving is learned")
	check(SkillTree.recipe_reason("weave_linen") == "" and SkillTree.recipe_reason("novice_robe") != "",
		"weaving is open, garments still need the next node")
	check(SkillTree.unlock("ta_garments") != "", "garments need more skill (and the boots/armour node)")
	train("enchanted_stitching", 2)
	eq(_learn("ta_garments"), "", "Cutting & Plain Garments learned once its prerequisites are met")
	check(SkillTree.recipe_reason("archmage_robe") != "", "the archmage's robe stays out of reach")
	check(craft_blocker("archmage_robe") != "", "archmage robe blocked: %s" % craft_blocker("archmage_robe"))


func test_weave_and_sew_robe() -> void:
	fresh_game()
	Property.dev_grant_all()
	train("enchanted_stitching", 3)
	give("flax_bundle", 1)
	eq(_learn("ta_garments"), "", "learned spinning, weaving and plain garments")
	# fibres from the village: fleece and flax
	give("wool_fleece", 10)
	give("flax_bundle", 2)
	for i in 5:
		check(not _make("spin_wool").is_empty(), "spun wool yarn (%d)" % (i + 1))
	check(Game.count("yarn_wool") >= 9, "yarn on the shelf: %d" % Game.count("yarn_wool"))
	for i in 3:
		var c := _make("weave_wool")
		check(not c.is_empty() and c.get("def", "") == "cloth_wool", "wove woollen cloth on the loom (%d)" % (i + 1))
	check(not _make("spin_flax").is_empty(), "spun linen thread from flax")
	eq(Game.count("cloth_wool") >= 3 and Game.count("thread_linen") >= 1, true, "cloth and thread ready for the robe")
	var ops: Array = Crafting.operations("novice_robe").map(func(o): return o["station"])
	check(ops.has("cutting_table") and ops.has("tailors_bench"), "the robe is cut and sewn at the new stations %s" % str(ops))
	var robe := _make("novice_robe")
	check(not robe.is_empty() and robe.get("def", "") == "robe_novice", "a Novice's Robe came off the tailor's bench")
	check(Items.slot(robe) == "armor" and (DB.item("robe_novice").get("tags", []) as Array).has("robe"), "a robe is worn as (light) armour and tagged robe")
	check(Items.stat(robe, "magic") > 0, "the robe lends magic: %d" % Items.stat(robe, "magic"))
	# a warded garment for casters, crafted at the top of the line
	SkillTree.unlock_all()
	train("enchanted_stitching", 8)
	for d in ["cloth_ethereal", "runestone_ward", "thread_ethereal"]:
		give(d, 2)
	var cloak := _make("warded_cloak")
	check(not cloak.is_empty() and Items.stat(cloak, "ward") > 0 and Items.stat(cloak, "magic") > 0,
		"a Warded Cloak gives ward %d and magic %d" % [Items.stat(cloak, "ward"), Items.stat(cloak, "magic")])
	var uid := int(robe.get("uid", 0))
	var mag := Items.stat(robe, "magic")
	check(save_load("suite_tailoring"), "saved and loaded")
	var back := Game.find_uid(uid)
	check(not back.is_empty() and Items.stat(back, "magic") == mag, "the robe and its magic survive save/load")
	check(SkillTree.is_unlocked("ta_garments"), "tailoring nodes survive save/load")


func test_variants_differ() -> void:
	fresh_game()
	Property.dev_grant_all()
	SkillTree.unlock_all()
	train("smithing", 12)
	train("enchanted_stitching", 12)
	var made := {}
	for rid in ["iron_shortsword", "steel_shortsword", "steel_greatsword", "steel_rapier", "steel_great_axe", "iron_hatchet",
			"leather_jerkin", "iron_chainmail", "full_plate", "steel_half_plate", "shortbow", "recurve_bow"]:
		var r := DB.recipe(rid)
		for d in r["inputs"]:
			give(str(d), int(r["inputs"][d]))
		var it := _make(rid)
		check(not it.is_empty(), "crafted %s" % rid)
		made[rid] = it
	var a := func(rid: String, st: String) -> int: return Items.stat(made.get(rid, {}), st)
	check(a.call("steel_greatsword", "attack") > a.call("steel_shortsword", "attack"), "greatsword attack %d > shortsword %d" % [a.call("steel_greatsword", "attack"), a.call("steel_shortsword", "attack")])
	check(a.call("steel_rapier", "speed") > a.call("steel_greatsword", "speed"), "rapier speed %d > greatsword %d" % [a.call("steel_rapier", "speed"), a.call("steel_greatsword", "speed")])
	check(a.call("steel_shortsword", "attack") > a.call("iron_shortsword", "attack"), "steel makes a better shortsword than iron (%d > %d)" % [a.call("steel_shortsword", "attack"), a.call("iron_shortsword", "attack")])
	check(a.call("steel_great_axe", "attack") > a.call("iron_hatchet", "attack"), "great axe out-hits a hatchet")
	var plate: int = a.call("full_plate", "protection")
	var mail: int = a.call("iron_chainmail", "protection")
	var leather: int = a.call("leather_jerkin", "protection")
	check(plate > mail and mail > leather, "protection: plate %d > chainmail %d > leather %d" % [plate, mail, leather])
	check(a.call("steel_half_plate", "durability") > a.call("leather_jerkin", "durability"), "plate outlasts leather")
	check(a.call("recurve_bow", "attack") > a.call("shortbow", "attack"), "recurve bow out-shoots a shortbow")
	# progression: early variants early, heavy ones late
	check(SkillTree.recipe_node("iron_shortsword") == "s_basic" and SkillTree.recipe_node("steel_greatsword") == "s_great"
		and SkillTree.recipe_node("full_plate") == "s_armour", "shortsword early, greatsword after steel, full plate at master armourcraft")
	check((SkillTree.node("s_great").get("requires", {}).get("nodes", []) as Array).has("s_heat"), "two-handed arms come after heat treatment (after steel)")
