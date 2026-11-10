## Hotfix — Mining experience from smelting. The "experts learn little from routine work" damping (×0.4) was judged
## only on the recipe's own skill (Smithing), so once the smith reached Smithing 6 every smelt taught his Mining at 40%
## too, although he was still a Mining-2 novice. Mining 3 (m_rare → the Smithing branch's s_alloy) then needed ~40
## smelts. The damping now also requires expertise in the skill being taught; nothing else changes.
extends SuiteCase

const SMOKE := ["test_expert_smith_still_learns_mining_from_smelting"]


func test_expert_smith_still_learns_mining_from_smelting() -> void:
	train("smithing", 7)   # what s_alloy itself demands
	Game.add_gold(500, "test", "tuition for the test", "test")
	eq(Game.player_level("mining"), 2, "a new smith starts at Mining 2")
	check(Game.player_level("smithing") - Crafting.difficulty("smelt_iron") >= 5, "smelting iron is routine work for a Smithing-7 smith")
	for id in ["m_common", "m_alloys"]:
		eq(SkillTree.unlock(id), "", "%s is learnable at Mining 2" % id)
	check(SkillTree.can_unlock("m_rare") != "", "m_rare is still blocked at Mining 2")
	# one smelt teaches a novice miner at the full rate, while the smith's own (expert) Smithing stays damped
	var m0 := int(Game.player_skills()["mining"]["xp"])
	var s0 := int(Game.player_skills()["smithing"]["xp"])
	give("ore_iron", 2)
	give("coal", 1)
	Vitality.set_fatigue(0.0)
	var it := craft("smelt_iron", 80.0, {"purity": 3})
	if not check(not it.is_empty(), "the smith can smelt iron (%s)" % craft_blocker("smelt_iron")):
		return
	var q := float(it["quality"])   # the job quality the experience is computed from
	var full := int(round(20.0 * (0.6 + q / 200.0)))
	eq(int(Game.player_skills()["mining"]["xp"]) - m0, full, "Mining learns at the full rate from smelting")
	var step_xp: int = (3 + 2) * DB.recipe("smelt_iron")["steps"].size()   # each one-check station step (Crafting.record_step)
	eq(int(Game.player_skills()["smithing"]["xp"]) - s0 - step_xp, int(round(12.0 * (0.6 + q / 200.0) * 0.4)),
		"Smithing, where he is an expert, is still damped as before")
	# keep smelting: Mining 3 is reachable in a practical number of smelts, and the blocked path opens
	var smelts := 1
	while Game.player_level("mining") < 3 and smelts < 40:
		give("ore_iron", 2)
		give("coal", 1)
		Vitality.set_fatigue(0.0)
		if craft("smelt_iron", 80.0, {"purity": 3}).is_empty():
			break
		smelts += 1
	eq(Game.player_level("mining"), 3, "Mining reaches 3 by smelting")
	check(smelts <= 16, "Mining 3 took %d smelts (at most 16 expected)" % smelts)
	eq(SkillTree.unlock("m_rare"), "", "m_rare (gate of the Smithing branch's s_alloy) is now learnable")
	check(not SkillTree.requirements("s_alloy").any(func(q): return str(q["text"]).contains("Rare Mineral") and not q["ok"]),
		"s_alloy no longer waits on Mining")
	note("Mining 3 after %d smelts at Smithing %d" % [smelts, Game.player_level("smithing")])
