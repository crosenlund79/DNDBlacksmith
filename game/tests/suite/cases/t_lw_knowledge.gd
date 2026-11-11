## The Living Workshop B2 — the smith's own path, the workshop's knowledge and specialist progression (KNOWLEDGE).
## Three separate things: personal competence (each worker's own levels — Workers), the workshop's knowledge (the
## Designs, stations and techniques the forge knows — WorkshopKnowledge, fed by the Skill Tree) and professional
## development (the smith's deep path through Smithing and Mining; a specialist's own craft through their own work,
## ranks and the workshop techniques they are competent to use). Knowledge never grants competence; another craft's
## knowledge comes in through a competent worker (no node asks the smith to master another profession); every Design is
## reachable from a fresh game with hires (no progression deadlock); save step "workshop knowledge" turns an older
## save's learned nodes — secrets and discoveries included — into the workshop's knowledge and loses nothing.
extends SuiteCase

const SMOKE := ["test_three_layers_are_separate", "test_no_cross_profession_gates"]
const GOLDEN := ["build-0.11.2", "build-0.12.4", "build-0.13.5", "build-0.14.6"]
const FIXTURES := "res://tests/fixtures/saves/"


# ------------------------------------------------------------------ fixtures
func _workshop() -> void:
	fresh_game()
	Property.dev_grant_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Game.state["gold"] = 20000
	(Game.state["hirelings"] as Array).clear()


func _golden_data(name: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
	if not doc is Dictionary or not (doc as Dictionary).get("data") is Dictionary:
		return {}
	return Saves._restore_ints(doc["data"])


## The schema version save step "workshop knowledge" produces (looked up by name: the lead may renumber it at merge).
func _step_knowledge() -> int:
	for st in SaveMigrations.STEPS:
		if str(st["name"]) == "workshop knowledge":
			return int(st["to"])
	return -1


## Designs the old tree-based gate knew in a save's data (visible and their node learned, or taught by no node).
func _tree_known(data: Dictionary) -> Array:
	var out := []
	var nodes: Array = (data.get("skilltree", {}) as Dictionary).get("nodes", [])
	var flags: Dictionary = data.get("flags", {})
	for rid in DB.recipes:
		var rf := str(DB.recipe(str(rid)).get("requires_flag", ""))
		if rf != "" and not bool(flags.get(rf, false)):
			continue
		var ni := SkillTree.recipe_node(str(rid))
		if ni == "" or nodes.has(ni):
			out.append(str(rid))
	out.sort()
	return out


## Saves the current game as an older-schema save with some keys removed (what an older build never wrote).
func _save_as_old(slot: String, version: int, erase: Array) -> bool:
	if not Saves.save(slot):
		return false
	var p := Saves.path(slot)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not doc is Dictionary:
		return false
	doc["data"]["version"] = version
	doc["meta"]["version"] = version
	for k in erase:
		(doc["data"] as Dictionary).erase(str(k))
	var tree: Variant = doc["data"].get("skilltree")
	if tree is Dictionary:
		(tree as Dictionary).erase("by")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	return true


func _known_list() -> Array:
	var out := []
	for rid in DB.recipes:
		if Workers.knowledge_reason(str(rid)) == "":
			out.append(str(rid))
	out.sort()
	return out


# ------------------------------------------------------------------ the three layers
func test_three_layers_are_separate() -> void:
	_workshop()
	var k := WorkshopKnowledge.st()
	check(Game.state.has("workshop_knowledge"), "the workshop's knowledge is its own store in the save")
	for rid in SkillTree.node("s_basic")["unlocks"]["recipes"]:
		check(WorkshopKnowledge.knows_design(str(rid)), "a new workshop knows %s (Basic Ironworking)" % rid)
	check(not WorkshopKnowledge.knows_design("steel_longsword") and Workers.knowledge_reason("steel_longsword").contains("Skill tree"),
		"an unlearned Design is not known, with the node to learn: %s" % Workers.knowledge_reason("steel_longsword"))
	eq((k["designs"] as Dictionary).size(), (SkillTree.node("s_basic")["unlocks"]["recipes"] as Array).size() + (SkillTree.node("l_basic")["unlocks"]["recipes"] as Array).size(),
		"a new game's knowledge: the two starting nodes' Designs")
	# competence does not create knowledge
	var rune := Apprentices.dev_take_on("runesmith", 9, "master")
	if not check(not rune.is_empty(), "a master runesmith joins"):
		return
	check(not WorkshopKnowledge.knows_design("ward_runestone") and Workers.can_do(rune, "ward_runestone").contains("Skill tree"),
		"a master runesmith on the staff does not make the workshop know a rune Design (%s)" % Workers.can_do(rune, "ward_runestone"))
	# knowledge does not create competence
	var skills_before := JSON.stringify(Game.player_skills(), "", true)
	var rune_before := JSON.stringify(rune["skills"], "", true)
	SkillTree.unlock_all()
	eq(JSON.stringify(Game.player_skills(), "", true), skills_before, "the whole tree learned: the smith's levels are unchanged")
	eq(JSON.stringify(rune["skills"], "", true), rune_before, "and the runesmith's")
	check(WorkshopKnowledge.knows_design("concord_runestone"), "the workshop knows the Concord runestone now")
	check(Crafting.recipe_locked_reason("concord_runestone").contains("runesmith"), "but the smith still may not make it: %s" % Crafting.recipe_locked_reason("concord_runestone"))
	eq(Workers.can_do(rune, "concord_runestone"), "", "the runesmith may — their own competence")
	# the profile of each layer
	var c := WorkshopKnowledge.counts()
	check(int(c["designs"]) == int(c["designs_total"]) and int(c["stations"]) == DB.stations.size(), "every visible Design and every station is in the catalogue (%s)" % str(c))
	check(not WorkshopKnowledge.knows_design("starsteel_blade"), "a secret Design stays unknown until its discovery, even with its node learned")


func test_no_cross_profession_gates() -> void:
	var owners := {}
	for b in SkillTree.branches():
		owners[str(b["id"])] = str(b.get("owner", ""))
		var prof := str(b.get("profession", ""))
		check(Workers.PROFESSION.has(prof), "branch %s belongs to a profession (%s)" % [b["id"], prof])
		check((Workers.PROFESSION.get(prof, {}).get("skills", []) as Array).has(str(b["skill"])), "branch %s's skill is its profession's" % b["id"])
		eq(owners[str(b["id"])] == "smith", prof == "blacksmith", "branch %s: the smith's own path is exactly the blacksmith's craft" % b["id"])
	eq(owners.get("smithing", ""), "smith", "Traditional Smithing is the smith's own path")
	eq(owners.get("mining", ""), "smith", "Mining & Metallurgy is the smith's own path")
	for bid in ["arcane", "runecraft", "alchemy", "leather", "tailoring"]:
		eq(owners.get(bid, ""), "workshop", "%s is the workshop's knowledge" % bid)
	var bad := []
	for n in SkillTree.nodes():
		var sk: Array = (n["requires"] as Dictionary).get("skill", [])
		var prof := str(SkillTree.branch(str(n["branch"])).get("profession", ""))
		if not sk.is_empty() and not (Workers.PROFESSION[prof]["skills"] as Array).has(str(sk[0])):
			bad.append("%s: %s %d" % [n["id"], sk[0], int(sk[1])])
	check(bad.is_empty(), "no node asks a level of another profession's craft %s" % str(bad))
	check(not (SkillTree.node("ar_energy")["requires"] as Dictionary).has("skill"), "Magical Energy Handling no longer asks the smith's Smithing 6")
	eq(SkillTree.node("ar_energy")["requires"].get("nodes", []), ["s_heat", "r_engrave", "m_mithril"], "it still builds on what the workshop knows")
	# every node beyond the smith's basic level in another craft is a specialist's
	for n in SkillTree.nodes():
		var sk2: Array = (n["requires"] as Dictionary).get("skill", [])
		if sk2.is_empty() or WorkshopKnowledge.node_owner(str(n["id"])) == "smith":
			continue
		if int(sk2[1]) > Workers.BASIC_LEVEL:
			note("%s (%s %d) is brought in by %s" % [n["id"], sk2[0], int(sk2[1]), Workers.a_noun(Workers.skill_profession(str(sk2[0])))])


# ------------------------------------------------------------------ the smith's own path
func test_smith_path_is_personal() -> void:
	_workshop()
	var bs := Apprentices.dev_take_on("blacksmith", 12, "master")
	if not check(not bs.is_empty(), "a master blacksmith joins"):
		return
	train("smithing", 5)
	for nid in ["s_blades", "m_common", "m_alloys", "s_steel"]:
		SkillTree.unlock_node_force(nid)
	var req := SkillTree.requirements("s_heat")
	var row: Dictionary = req.filter(func(x): return str(x["kind"]) == "skill")[0]
	check(not bool(row["ok"]) and str(row["owner"]) == "smith" and str(row["text"]).contains("(you: 5)"), "Advanced Heat Treatment asks the smith's own Smithing 6: %s" % row["text"])
	check(SkillTree.unlock("s_heat") != "", "a master blacksmith on the staff does not learn the smith's path for him")
	train("smithing", 6)
	eq(SkillTree.unlock("s_heat"), "", "his own Smithing 6 does")
	eq(WorkshopKnowledge.brought_by("s_heat"), "player", "the smith brought it in")
	# a technique of his own path is his alone
	var t_smith := SkillTree.quality_bonus("iron_longsword")
	check(t_smith >= 2.0, "the interrupted quench helps the smith's classic weapons (+%.0f)" % t_smith)
	check(SkillTree.quality_bonus("iron_longsword", bs) == 0.0, "it does not help the master blacksmith apprentice — it is the smith's personal mastery")
	check(SkillTree.techniques_for("iron_longsword").all(func(t): return bool(t["personal"])), "listed as personal techniques")


# ------------------------------------------------------------------ another craft: through a competent worker
func test_specialist_brings_knowledge_the_smith_could_not() -> void:
	_workshop()
	for nid in ["l_armour", "l_threads", "l_hides", "l_enchanted", "ta_spin", "ta_garments", "ta_silk", "ta_scholar", "ta_moon"]:
		SkillTree.unlock_node_force(nid)
	train("enchanted_stitching", 9)   # the smith's other crafts stop at the basic level (B1)
	eq(Game.player_level("enchanted_stitching"), Workers.BASIC_LEVEL, "the smith's stitching is basic (%d)" % Workers.BASIC_LEVEL)
	give("reagent_aether_dust", 1)
	var why := SkillTree.can_unlock("ta_archmage")
	check(why.contains("Enchanted Stitching 6"), "the archmage's robe node asks Stitching 6 — beyond the smith: %s" % why)
	var hint: String = SkillTree.requirements("ta_archmage").filter(func(x): return str(x["kind"]) == "skill")[0]["hint"]
	check(hint.contains("leatherworker"), "its hint names a leatherworker: %s" % hint)
	eq(WorkshopKnowledge.bearer("ta_archmage"), "", "nobody can bring it in yet")
	var lw := Apprentices.dev_take_on("leatherworker", 7, "journeyman")
	if not check(not lw.is_empty(), "a leatherworker with Stitching 7 joins"):
		return
	eq(WorkshopKnowledge.bearer("ta_archmage"), str(lw["id"]), "the leatherworker would bring it in")
	var xp_before := JSON.stringify(Game.player_skills(), "", true)
	eq(SkillTree.unlock("ta_archmage"), "", "the workshop learns Warded Cloth & the Archmage's Robe")
	eq(WorkshopKnowledge.brought_by("ta_archmage"), str(lw["id"]), "through the leatherworker")
	eq(str(WorkshopKnowledge.entry("designs", "archmage_robe").get("by", "")), str(lw["id"]), "the Design's record names who brought it")
	check(str(Chronicle.entries()[-1]["text"]).contains("through %s" % lw["name"]), "the chronicle says so: %s" % Chronicle.entries()[-1]["text"])
	eq(JSON.stringify(Game.player_skills(), "", true), xp_before, "the smith gained no level or experience from it")
	check(WorkshopKnowledge.credit(str(lw["id"])).has("ta_archmage"), "it is the leatherworker's credit")
	# knowledge through the specialist, competence stays personal
	check(Workers.knowledge_reason("ward_cloth") == "" and Crafting.recipe_locked_reason("ward_cloth") == "", "warded cloth (basic work) is now known and within the smith's own basic stitching")
	check(Crafting.recipe_locked_reason("archmage_robe").contains("leatherworker"), "the archmage's robe stays a leatherworker's work: %s" % Crafting.recipe_locked_reason("archmage_robe"))
	check(Workers.who_can("archmage_robe").has(str(lw["id"])) or Workers.can_do(lw, "archmage_robe") != "", "who may make it is the leatherworker's own competence (%s)" % Workers.can_do(lw, "archmage_robe"))
	# saved and loaded, the record holds
	check(save_load("suite_lwk_rt"), "saved and loaded")
	eq(WorkshopKnowledge.brought_by("ta_archmage"), str(lw["id"]), "after loading, still through the leatherworker")
	check(WorkshopKnowledge.knows_design("archmage_robe"), "and still known")


func test_knowledge_never_grants_mastery() -> void:
	_workshop()
	for nid in ["r_identify", "r_clean", "r_blank", "r_engrave", "r_stabilise", "r_original", "r_combo"]:
		SkillTree.unlock_node_force(nid)
	Game.player_skills()["runecraft"] = {"lvl": Workers.BASIC_LEVEL, "xp": 0}
	var rune := Apprentices.dev_take_on("runesmith", 7, "journeyman")
	if not check(not rune.is_empty(), "a runesmith joins"):
		return
	var smith_before := SkillTree.quality_bonus("concord_runestone")
	var rune_before := SkillTree.quality_bonus("concord_runestone", rune)
	eq(SkillTree.unlock("r_master"), "", "the workshop learns Master Runecrafting through the runesmith")
	eq(WorkshopKnowledge.brought_by("r_master"), str(rune["id"]), "recorded as the runesmith's")
	check(WorkshopKnowledge.knows_technique("t_runemaster"), "the master runewright technique is the workshop's knowledge")
	eq(SkillTree.quality_bonus("concord_runestone"), smith_before, "it does not help the smith at his basic Runecraft 5")
	eq(SkillTree.quality_bonus("concord_runestone", rune), rune_before + 3.0, "it helps the runesmith, whose own Runecraft 7 meets it")
	check(WorkshopKnowledge.techniques_beyond("concord_runestone").any(func(t): return str(t["name"]) == "Master runewright" and str(t["need"]) == "Runecraft 6"),
		"the smith is told the workshop knows it but it needs Runecraft 6")
	check(Workers.skill_bonus(rune, "concord_runestone") > Workers.skill_bonus(rune, "ward_runestone") - 0.01, "the runesmith's piece carries their technique")
	var q_with := Apprentices.expected_op_quality(rune, "ward_runestone", "rune_engraving_stand")
	(Game.state["workshop_knowledge"]["techniques"] as Dictionary).erase("t_runemaster")
	var q_without := Apprentices.expected_op_quality(rune, "ward_runestone", "rune_engraving_stand")
	check(is_equal_approx(q_with - q_without, 3.0), "the runesmith's own work is 3 points better with the technique (%.1f vs %.1f)" % [q_with, q_without])
	check(Crafting.recipe_locked_reason("concord_runestone").contains("runesmith"), "the smith still may not make the master rune: %s" % Crafting.recipe_locked_reason("concord_runestone"))
	# an older save in which the smith himself learned it with his own high level keeps the technique
	Game.player_skills()["runecraft"] = {"lvl": 12, "xp": 0}
	(Game.state["workshop_knowledge"]["techniques"] as Dictionary)["t_runemaster"] = {"day": 1, "node": "r_master", "by": "player"}
	eq(SkillTree.quality_bonus("concord_runestone"), smith_before + 3.0, "a smith with an old save's Runecraft 12 keeps using it (his own level)")


# ------------------------------------------------------------------ no deadlocks: every Design is reachable
## A finished work's experience for a simulated worker — the formula of Apprentices._finish_op / _finish (expected
## quality, no randomness): 2 per operation in the station's skill, then the Design's experience (at least 8) ×
## (0.6 + quality/200), less for routine work, more for hard work; one more work; rank check.
func _do_work(a: Dictionary, rid: String) -> void:
	var xpc: Dictionary = Apprentices.cfg("xp")
	for o in Crafting.operations(rid):
		Apprentices.add_xp(a, Apprentices.op_skill(rid, str(o.get("station", ""))), float(xpc.get("per_op", 2)))
	var skill := Crafting.recipe_skill(rid)
	var q := Apprentices.expected_quality(a, rid)
	var gap := Apprentices.level(a, skill) - Crafting.difficulty(rid)
	var amt := 8.0
	var rx: Dictionary = DB.recipe(rid).get("xp", {})
	for sk in rx:
		amt = maxf(amt, float(rx[sk]))
	amt *= float(xpc.get("mult", 1.0)) * (0.6 + q / 200.0)
	if gap >= int(xpc.get("routine_gap", 4)):
		amt *= float(xpc.get("routine_mult", 0.35))
	elif gap < 0:
		amt *= float(xpc.get("hard_mult", 1.4))
	Apprentices.add_xp(a, skill, amt)
	a["works"] = int(a["works"]) + 1
	Apprentices._check_rank(a)


## The first skill a worker still lacks for a Design (main operations: the difficulty level; contributions: what the
## Design or station names), or "".
func _blocking_skill(a: Dictionary, rid: String) -> String:
	var req: Dictionary = DB.recipe(rid).get("requires", {})
	for sk in req:
		if Workers.level(a, str(sk)) < int(req[sk]):
			return str(sk)
	for i in Crafting.operations(rid).size():
		var q := Workers.op_requirement(rid, i)
		var need := int(q["level"]) if bool(q["main"]) else int(q["explicit"])
		if Workers.level(a, str(q["skill"])) < need:
			return str(q["skill"])
	return ""


## Hires the weakest real applicant of a profession from the notice board (40 weekly notices looked at).
func _hire_weakest(prof: String) -> Dictionary:
	var best := {}
	var lo := 99
	for i in 40:
		Apprentices.refresh_applicants()
		for c in Apprentices.applicants():
			if str(c.get("profession", "")) != prof:
				continue
			var lv := int((c["levels"] as Dictionary).get(Workers.skill_of(prof), 0))
			if lv < lo:
				lo = lv
				best = (c as Dictionary).duplicate(true)
	if best.is_empty():
		return {}
	(Apprentices.st()["applicants"] as Array).insert(0, best)
	if Apprentices.hire(0) != "":
		return {}
	return Apprentices.staff()[-1]


## A real newcomer of `prof` (the weakest applicant of that profession, novice) works their way up by their own work
## only — always the most useful Design they may make now; no mentoring, no help. Returns {"ok", "works", "level",
## "rank", "missing": [Designs of their craft still out of reach], "stuck": bool, "start"}.
func _career(prof: String) -> Dictionary:
	var disc := Workers.discipline_of(prof)
	var a := _hire_weakest(prof)
	if a.is_empty():
		return {"ok": false, "works": 0, "level": 0, "rank": "", "missing": ["(no %s applied)" % prof], "stuck": true, "start": 0}
	var start := Workers.level(a, Workers.skill_of(prof))
	var targets := []
	for rid in DB.recipes:
		if str(DB.recipe(str(rid)).get("discipline", "")) == disc and WorkshopKnowledge.knows_design(str(rid)):
			targets.append(str(rid))
	var stuck := false
	for step in 900:
		var todo := targets.filter(func(r): return Workers.can_do(a, r) != "")
		if todo.is_empty():
			break
		var want := ""
		for r in todo:
			want = _blocking_skill(a, str(r))
			if want != "":
				break
		var best := ""
		var best_key := -1
		for r in DB.recipes:
			var rid := str(r)
			if Workers.can_do(a, rid) != "":
				continue
			var key := Crafting.difficulty(rid)
			if want != "" and Crafting.recipe_skill(rid) == want:
				key += 100
			elif str(DB.recipe(rid).get("discipline", "")) == disc:
				key += 50
			if key > best_key:
				best_key = key
				best = rid
		if best == "":
			stuck = true
			break
		_do_work(a, best)
	var missing := targets.filter(func(r): return Workers.can_do(a, r) != "")
	return {"ok": missing.is_empty(), "works": int(a["works"]), "level": Workers.level(a, Workers.skill_of(prof)), "rank": str(a["rank"]),
		"missing": missing.map(func(r): return "%s (%s)" % [r, Workers.can_do(a, r)]), "stuck": stuck, "start": start}


func test_every_design_reachable_from_a_fresh_game_with_hires() -> void:
	# 1. competence: a newcomer of each profession, by their own work alone, reaches every Design of their craft
	var reached := {}
	for prof in Workers.PROFESSIONS:
		_workshop()
		SkillTree.unlock_all()
		Game.set_flag("recipe_starsteel")   # the secret Design is reachable once discovered (its discovery: t_lw_reliability)
		var c := _career(str(prof))
		check(bool(c["ok"]) and not bool(c["stuck"]), "%s starting at %s %d (novice) reaches every Design of their craft by their own work — %d works, %s %d, %s%s" % [
			Workers.a_noun(str(prof)), SkillSys.skill_name(Workers.skill_of(str(prof))), int(c.get("start", 0)), int(c["works"]), SkillSys.skill_name(Workers.skill_of(str(prof))), int(c["level"]), c["rank"],
			("" if bool(c["ok"]) else " — missing " + str(c["missing"]))])
		note("%s: from %s %d (novice) to %s %d, %s, after %d works" % [prof, SkillSys.skill_name(Workers.skill_of(str(prof))), int(c.get("start", 0)),
			SkillSys.skill_name(Workers.skill_of(str(prof))), int(c["level"]), c["rank"], int(c["works"])])
		reached[prof] = int(c["level"])
	# 2. knowledge: from a fresh game every node is learned legitimately — the smith's own path by his own levels, another
	#    craft through the smith's basic level or a specialist at a level step 1 showed a newcomer reaches
	fresh_game()
	Property.dev_grant_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	(Game.state["hirelings"] as Array).clear()
	var guard := 0
	var hired := {}
	while SkillTree.learned().size() < SkillTree.nodes().size() and guard < 60:
		guard += 1
		for n in SkillTree.nodes():
			var id: String = n["id"]
			if SkillTree.is_unlocked(id) or not (n["requires"].get("nodes", []) as Array).all(func(p): return SkillTree.is_unlocked(p)):
				continue
			var r: Dictionary = n["requires"]
			if r.has("skill"):
				var sk := str(r["skill"][0])
				var need := int(r["skill"][1])
				if WorkshopKnowledge.node_owner(id) == "smith" or need <= Workers.BASIC_LEVEL:
					train(sk, need)
				elif Workers.best_level(sk)["level"] < need:
					var prof := Workers.skill_profession(sk)
					check(int(reached.get(prof, 0)) >= need, "%s needs %s %d: a %s reaches %d (step 1)" % [id, sk, need, prof, int(reached.get(prof, 0))])
					var spec := Apprentices.dev_take_on(prof, need)
					if not spec.is_empty():
						hired[id] = str(spec["id"])
			for f in r.get("flags", []):
				Game.set_flag(str(f))   # discoveries have sources in play (t_integrity.tree_shape)
			for dd in r.get("items_seen", []):
				give(str(dd), 1)
			for dd in r.get("items", {}):
				give(str(dd), int(r["items"][dd]))
			if Game.gold() < int(r.get("gold", 0)):
				Game.add_gold(int(r["gold"]), "test", "test tuition")
			SkillTree.unlock(id)
	eq(SkillTree.learned().size(), SkillTree.nodes().size(), "every node learned from a fresh game (%d rounds)" % guard)
	for nid in hired:
		eq(WorkshopKnowledge.brought_by(str(nid)), str(hired[nid]), "%s came in through the specialist taken on for it" % nid)
	for p in ["smithing", "mining"]:
		note("the smith's own %s: %d" % [p, Game.player_level(p)])
	for sk in ["runecraft", "alchemy", "enchanted_stitching", "arcane_metalwork"]:
		check(Game.player_level(sk) <= Workers.BASIC_LEVEL, "the smith never had to master %s (%d)" % [sk, Game.player_level(sk)])
	var unknown := []
	for rid in DB.recipes:
		if not WorkshopKnowledge.knows_design(str(rid)):
			unknown.append(str(rid))
	check(unknown.is_empty(), "the workshop knows every Design %s" % str(unknown))
	# 3. every Design: the smith may make it, or the specialist of its craft reaches it (step 1)
	var nobody := []
	var by_smith := 0
	for rid in DB.recipes:
		if Crafting.recipe_locked_reason(str(rid)) == "":
			by_smith += 1
			continue
		var prof2 := Workers.discipline_profession(str(DB.recipe(str(rid)).get("discipline", "classic")))
		if prof2 == "blacksmith":
			nobody.append("%s: %s" % [rid, Crafting.recipe_locked_reason(str(rid))])
	check(nobody.is_empty(), "every smithing Design is the smith's own %s" % str(nobody))
	note("%d of %d Designs the smith makes himself; the rest are specialists' (step 1)" % [by_smith, DB.recipes.size()])


func test_entry_level_and_master_reach() -> void:
	eq(WorkshopKnowledge.entry_level("arcane"), 3, "an arcanist's easiest Design (Charge Mithril) asks Arcane Metalworking 3")
	for d in ["classic", "stitching", "alchemy", "runecraft"]:
		check(WorkshopKnowledge.entry_level(d) <= 1, "%s begins at level %d" % [d, WorkshopKnowledge.entry_level(d)])
	_workshop()
	var seen_arcanist := false
	for i in 40:
		Apprentices.refresh_applicants()
		for c in Apprentices.applicants():
			var disc := Workers.discipline_of(str(c.get("profession", "blacksmith")))
			var lv := int((c["levels"] as Dictionary).get(str(Crafting.DISCIPLINE_SKILL.get(disc, "smithing")), 0))
			check(lv >= WorkshopKnowledge.entry_level(disc) and lv >= 1, "an applicant %s arrives able to begin their craft (%d)" % [c["profession"], lv])
			if str(c.get("profession", "")) == "arcanist":
				seen_arcanist = true
	check(seen_arcanist, "arcanists apply once the Arcane Foundry is bought")
	var hardest := 0
	for rid in DB.recipes:
		hardest = maxi(hardest, Crafting.difficulty(str(rid)))
	check(int(Apprentices.rank_data("master").get("max_difficulty", 0)) >= hardest, "a master's reach covers the hardest Design (%d)" % hardest)


# ------------------------------------------------------------------ save step "workshop knowledge"
func test_migration_workshop_knowledge_golden_saves() -> void:
	var six := _step_knowledge()
	check(six > 0 and six == Game.SAVE_VERSION or six < Game.SAVE_VERSION, "the step is registered (v%d)" % six)
	for g in GOLDEN:
		var data := _golden_data(g)
		if not check(not data.is_empty(), "%s parses" % g):
			continue
		SaveMigrations.run(data, six - 1)
		check(not data.has("workshop_knowledge"), "%s: an older save has no workshop knowledge" % g)
		var known_before := _tree_known(data)
		var rest_before := JSON.stringify(data, "", true)
		var rep := SaveMigrations.run(data, six)
		eq(rep["steps"], ["workshop knowledge"], "%s: the step runs" % g)
		eq(int(data["version"]), six, "%s: now at its schema" % g)
		var k: Dictionary = data.get("workshop_knowledge", {})
		var nodes: Array = data["skilltree"]["nodes"]
		eq((k.get("nodes", {}) as Dictionary).size(), nodes.size(), "%s: every learned node (%d) is the workshop's" % [g, nodes.size()])
		var missing := []
		for nid in nodes:
			for rid in SkillTree.node(str(nid)).get("unlocks", {}).get("recipes", []):
				if not (k["designs"] as Dictionary).has(str(rid)):
					missing.append(str(rid))
			for sid in SkillTree.node(str(nid)).get("unlocks", {}).get("stations", []):
				if not (k["stations"] as Dictionary).has(str(sid)):
					missing.append(str(sid))
		check(missing.is_empty(), "%s: every Design and station of a learned node is known %s" % [g, str(missing)])
		check((k["nodes"] as Dictionary).values().all(func(e): return str(e.get("by", "")) == "player"), "%s: learned through the smith" % g)
		# nothing else changed, and the same Designs are known
		var copy := data.duplicate(true)
		copy.erase("workshop_knowledge")
		copy["version"] = six - 1
		eq(JSON.stringify(copy, "", true), rest_before, "%s: the tree, flags, levels and items are untouched" % g)
		var prev: Dictionary = Game.state
		Game.state = data
		var known_after := _known_list()
		Game.state = prev
		eq(known_after, known_before, "%s: exactly the Designs the old save knew are known (%d)" % [g, known_before.size()])
		var once := JSON.stringify(data, "", true)
		SaveMigrations.apply_step(six, data)
		eq(JSON.stringify(data, "", true), once, "%s: the step again changes nothing" % g)


func test_migration_keeps_secrets_and_discoveries() -> void:
	_workshop()
	train("smithing", 7)
	train("mining", 3)
	for nid in ["s_blades", "m_common", "m_alloys", "m_rare", "s_steel", "s_heat", "s_alloy", "r_identify", "r_clean", "al_simple"]:
		SkillTree.unlock_node_force(nid)
	Game.set_flag("recipe_starsteel")
	Game.set_flag("rune_knowledge")
	eq(SkillTree.unlock("s_starsteel"), "", "the smith learns the secret starsteel node after finding the notes")
	var known := _known_list()
	var tree := JSON.stringify(Game.state["skilltree"], "", true)
	var flags := JSON.stringify(Game.state["flags"], "", true)
	var skills := JSON.stringify(Game.player_skills(), "", true)
	var six := _step_knowledge()
	check(_save_as_old("suite_lwk_old", six - 1, ["workshop_knowledge"]), "written as an older save without workshop knowledge")
	check(Saves.load_slot("suite_lwk_old"), "it loads")
	Saves.delete("suite_lwk_old")
	var steps: Array = Saves.last_load.get("migration", {}).get("steps", [])
	check(steps.has("workshop knowledge"), "the step ran (%s)" % str(steps))
	check(WorkshopKnowledge.knows_design("starsteel_blade") and str(WorkshopKnowledge.entry("designs", "starsteel_blade").get("node", "")) == "s_starsteel",
		"the secret Design is the workshop's knowledge")
	eq(_known_list(), known, "the same Designs are known as before (%d)" % known.size())
	eq(JSON.stringify(Game.state["skilltree"], "", true), tree, "the tree is untouched")
	eq(JSON.stringify(Game.state["flags"], "", true), flags, "every discovery is kept")
	eq(JSON.stringify(Game.player_skills(), "", true), skills, "every level is kept")
	check(WorkshopKnowledge.discoveries().any(func(d): return str(d["flag"]) == "recipe_starsteel"), "the starsteel notes are listed among the discoveries")
	eq(SkillTree.node_state("s_starsteel"), "unlocked", "the node is still learned")


# ------------------------------------------------------------------ the panel: the tree and the workshop's knowledge
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Node) -> Node:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


func _text_of(n: Node) -> String:
	var t := ""
	for c in n.get_children():
		if c.is_queued_for_deletion() or (c is CanvasItem and not (c as CanvasItem).visible):
			continue
		if c is Label:
			t += (c as Label).text + "\n"
		elif c is RichTextLabel:
			t += (c as RichTextLabel).get_parsed_text() + "\n"
		elif c is Button:
			t += (c as Button).text + "\n"
		t += _text_of(c)
	return t


func test_panel_shows_both_layers() -> void:
	_workshop()
	for nid in ["r_identify", "r_clean", "r_blank", "r_engrave", "r_stabilise", "r_original", "r_combo", "s_blades", "m_common", "m_alloys", "s_steel", "s_heat", "s_alloy"]:
		SkillTree.unlock_node_force(nid)
	Game.player_skills()["runecraft"] = {"lvl": Workers.BASIC_LEVEL, "xp": 0}
	var rune := Apprentices.dev_take_on("runesmith", 8, "master")
	if not check(not rune.is_empty(), "a runesmith joins"):
		return
	var tp := SkillTreePanel.new({"select": "r_master"})
	_mount(tp)
	check(tp.body.visible and not tp.kscroll.visible, "it opens on the tree")
	tp._show("r_master", true)
	var page := _text_of(tp.side)
	check(page.contains("The workshop's knowledge") and page.contains("through %s" % rune["name"]), "the master rune seal is the workshop's knowledge, learned through the runesmith: %s" % page.left(300))
	check(page.contains("Helps whoever works it with Runecraft 6"), "its technique says whom it helps")
	tp._show("s_heat", true)
	page = _text_of(tp.side)
	check(page.contains("Your own path") and page.contains("Your personal technique"), "a smithing seal is the smith's own path and personal technique")
	tp._learn("r_master")
	tp._do_refresh()
	eq(WorkshopKnowledge.brought_by("r_master"), str(rune["id"]), "learned from the panel through the runesmith")
	tp._set_view("knowledge")
	check(not tp.body.visible and tp.kscroll.visible and tp.tab_know.button_pressed and not tp.tab_tree.button_pressed, "the knowledge view replaces the tree")
	var kt := _text_of(tp.kview)
	check(kt.contains("What the workshop knows") and kt.contains("Designs ·"), "the catalogue has its summary")
	check(kt.contains("Steel Longsword") and kt.contains("Steelworking"), "known Designs by craft, with the node they came from")
	check(kt.contains("Concord Runestone") and kt.contains(str(rune["name"])), "the master rune Design names who may make it (the runesmith)")
	check(kt.contains("Master runewright") and kt.contains("helps whoever has Runecraft 6"), "techniques say whom they help")
	check(kt.contains("Interrupted quench") and kt.contains("yours"), "the smith's own techniques are his")
	check(kt.contains("Brought in through your staff") and kt.contains("Master Runecrafting"), "the runesmith's credit")
	check(not kt.contains("Starsteel"), "the secret Design is not in the catalogue before its discovery")
	# switching views and refreshing leaves no ghosts
	for i in 3:
		tp._set_view("tree")
		tp._set_view("knowledge")
	var ghosts := 0
	for c in tp.kview.get_children():
		if c.is_queued_for_deletion() and (c as CanvasItem).visible:
			ghosts += 1
	eq(ghosts, 0, "replaced catalogue content leaves the layout at once")
	tp._refresh()
	tp._refresh()
	check(tp._refresh_queued, "refreshes are still gathered once per frame")
	tp._do_refresh()
	_unmount(tp)
	var tk := SkillTreePanel.new({"view": "knowledge"})
	_mount(tk)
	check(tk.kscroll.visible and not tk.body.visible, "it can open on the workshop's knowledge")
	_unmount(tk)
