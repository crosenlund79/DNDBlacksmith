## Rendered play-test phase "lw_knowledge" (The Living Workshop — the KNOWLEDGE worker: B2 skill trees, Designs and
## workshop knowledge). What the player sees: the Skill Tree banded YOUR OWN PATH (Smithing, Mining) and THE WORKSHOP'S
## KNOWLEDGE; a seal on the smith's own path with his personal technique; the secret "???" beyond Alloy Production kept
## a mystery; the master tailoring seal beyond the smith's basic stitching, then brought in through a leatherworker taken
## on (the smith could not) and recorded as theirs; the "Workshop knowledge" catalogue (known Designs and who may make
## each, techniques and whom they help, discoveries, the specialist's credit); a station listing Designs; Help's Skill
## Tree entry. Screenshots lwk_<tag>_*. The file also runs on the base build (no WorkshopKnowledge): LWK tag "before"
## takes the same views for BEFORE shots and skips the new views' checks.
## Called from tests/playtest.gd (phase_lw_knowledge).
extends RefCounted

var pt: Node
var WK: Script = null   # WorkshopKnowledge — null on a build before B2
var tag := "after"


func _text(root: Node, needle: String) -> bool:
	return root != null and pt.find_label_containing(root, needle) != null


func _side_text(tp: Node) -> String:
	var t := ""
	var side: Node = tp.get("side")
	for c in side.get_children():
		if c.is_queued_for_deletion() or (c is CanvasItem and not (c as CanvasItem).visible):
			continue
		if c is Label:
			t += (c as Label).text + "\n"
		elif c is RichTextLabel:
			t += (c as RichTextLabel).get_parsed_text() + "\n"
		elif c is Button:
			t += (c as Button).text + "\n"
		elif c is Container:
			for d in c.get_children():
				if d is Label:
					t += (d as Label).text + "\n"
	return t


func _train(skill: String, level: int) -> void:
	var g := 0
	while Game.player_level(skill) < level and g < 200:
		Game.grant_player_xp(skill, SkillSys.xp_needed(Game.player_level(skill) + 1))
		g += 1


func run(p: Node) -> void:
	pt = p
	if ResourceLoader.exists("res://scripts/systems/workshop_knowledge.gd"):
		WK = load("res://scripts/systems/workshop_knowledge.gd")
	tag = "after" if WK != null else "before"
	pt.note("lw_knowledge: %s build" % tag)
	await pt.click("New Game")
	await pt.wait(2.5)
	Shop.customers().clear()
	Game.state["gold"] = 9000
	await pt.wait(1.0)
	Property.dev_grant_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	pt.main.call("rebuild_world")
	await pt.wait(2.0)
	await pt.advance_to(9, 0)
	await _smith_path()
	await _secret()
	await _specialist()
	await _knowledge_view()
	await _station()
	await _help()


func _tree() -> Node:
	var tp: Node = pt.panel()
	return tp if tp is SkillTreePanel else null


# ---------------------------------------------------------------- 1. the smith's own path
func _smith_path() -> void:
	_train("smithing", 6)
	_train("mining", 3)
	for nid in ["s_blades", "m_common", "m_alloys", "m_rare", "s_steel"]:
		SkillTree.unlock_node_force(nid)
	pt.expect(SkillTree.unlock("s_heat") == "", "lw_knowledge: the smith learns Advanced Heat Treatment with his own Smithing 6")
	Events.open_panel.emit("skilltree", {"select": "s_heat"})
	await pt.wait(1.2)
	var tp: Node = _tree()
	pt.expect(tp != null, "lw_knowledge: the Skill Tree opens")
	if tp == null:
		return
	tp.call("_show", "s_heat", true)
	await pt.wait(0.4)
	if WK != null:
		var t := _side_text(tp)
		pt.expect(t.contains("Your own path") and t.contains("Your personal technique"), "lw_knowledge: a smithing seal is the smith's own path, its technique his (%s)" % t.left(160).replace("\n", " / "))
		pt.expect(tp.get("tab_know") != null and pt.find_button(tp, "Workshop knowledge") != null, "lw_knowledge: the panel offers the Workshop knowledge view")
	await pt.shot("lwk_%s_01_tree_smith_path" % tag)


# ---------------------------------------------------------------- 2. the ??? beyond Alloy Production (#49)
func _secret() -> void:
	_train("smithing", 7)
	SkillTree.unlock_node_force("s_alloy")
	var tp: Node = _tree()
	if tp == null:
		return
	if tp.has_method("_do_refresh"):
		tp.call("_do_refresh")
	else:
		tp.call("_refresh")
	await pt.wait(0.3)
	var cv: Object = tp.get("canvas")
	cv.call("select", "s_starsteel")
	await pt.wait(0.6)
	var t := _side_text(tp)
	pt.expect(SkillTree.node_state("s_starsteel") == "hidden" and t.contains("???") and not t.contains("Starsteel"), "lw_knowledge: the secret beyond Alloy Production stays ??? (%s)" % t.left(120).replace("\n", " / "))
	pt.expect(bool(cv.call("visible_node", SkillTree.node("s_starsteel"))), "lw_knowledge: it is drawn as a ??? seal once Alloy Production is known")
	if WK != null:
		pt.expect(not bool(WK.call("knows_design", "starsteel_blade")), "lw_knowledge: the workshop does not know the secret Design")
	await pt.shot("lwk_%s_02_secret_beyond_alloy" % tag)


# ---------------------------------------------------------------- 3. a specialist brings in what the smith could not
func _specialist() -> void:
	for nid in ["l_armour", "l_threads", "l_hides", "l_enchanted", "ta_spin", "ta_garments", "ta_silk", "ta_scholar", "ta_moon"]:
		SkillTree.unlock_node_force(nid)
	_train("enchanted_stitching", 9)   # stops at the basic level
	Game.add_item(Items.make("reagent_aether_dust", {"qty": 1}), false)
	var tp: Node = _tree()
	if tp == null:
		return
	var cv: Object = tp.get("canvas")
	cv.call("select", "ta_archmage")
	tp.call("_show", "ta_archmage", true)
	await pt.wait(0.6)
	var why := SkillTree.can_unlock("ta_archmage")
	pt.expect(why.contains("Enchanted Stitching 6"), "lw_knowledge: the archmage's robe seal needs Stitching 6 — beyond the smith's basic %d (%s)" % [Game.player_level("enchanted_stitching"), why])
	await pt.shot("lwk_%s_03_archmage_beyond_the_smith" % tag)
	var lw := Apprentices.dev_take_on("leatherworker", 7, "journeyman", "Wren Marsh")
	pt.expect(not lw.is_empty(), "lw_knowledge: a leatherworker with Stitching 7 is taken on")
	if lw.is_empty():
		return
	tp.call("_build_skills")
	tp.call("_show", "ta_archmage", true)
	await pt.wait(0.6)
	var t := _side_text(tp)
	if WK != null:
		pt.expect(t.contains("through Wren Marsh"), "lw_knowledge: the seal is ready — learned through the leatherworker (%s)" % t.left(200).replace("\n", " / "))
	await pt.shot("lwk_%s_04_archmage_through_leatherworker" % tag)
	var lb: Button = pt.find_button(tp, "✦ Learn") as Button
	pt.expect(lb != null, "lw_knowledge: the Learn button is there")
	if lb:
		lb.pressed.emit()
	await pt.wait(1.0)
	tp = _tree()
	if tp == null:
		return
	tp.call("_show", "ta_archmage", true)
	await pt.wait(0.5)
	pt.expect(SkillTree.is_unlocked("ta_archmage"), "lw_knowledge: the workshop learned Warded Cloth & the Archmage's Robe")
	if WK != null:
		pt.expect(str(WK.call("brought_by", "ta_archmage")) == str(lw["id"]), "lw_knowledge: recorded as brought in through the leatherworker")
		t = _side_text(tp)
		pt.expect(t.contains("learned through Wren Marsh"), "lw_knowledge: the seal says through whom (%s)" % t.left(200).replace("\n", " / "))
		pt.expect(Crafting.recipe_locked_reason("ward_cloth") == "" and Crafting.recipe_locked_reason("archmage_robe").contains("leatherworker"),
			"lw_knowledge: warded cloth is basic work the smith may now do; the robe itself stays the leatherworker's (%s)" % Crafting.recipe_locked_reason("archmage_robe"))
	await pt.shot("lwk_%s_05_archmage_learned_through_specialist" % tag)


# ---------------------------------------------------------------- 4. the workshop's knowledge
func _knowledge_view() -> void:
	var tp: Node = _tree()
	if tp == null:
		return
	if WK == null:
		tp.call("_show", "", true)
		await pt.wait(0.4)
		await pt.shot("lwk_%s_06_tree_overview" % tag)
		return
	pt.expect(await pt.click("Workshop knowledge", tp), "lw_knowledge: the Workshop knowledge tab")
	await pt.wait(0.8)
	var kv: Node = tp.get("kview")
	pt.expect(_text(kv, "What the workshop knows") and _text(kv, "Designs ·"), "lw_knowledge: the catalogue and its summary")
	pt.expect(_text(kv, "Archmage's Robe") and _text(kv, "Wren Marsh"), "lw_knowledge: the archmage's robe and who may make it")
	await pt.shot("lwk_%s_06_workshop_knowledge" % tag)
	var sc: ScrollContainer = tp.get("kscroll")
	sc.scroll_vertical = 100000
	await pt.wait(0.5)
	pt.expect(_text(kv, "Brought in through your staff") and _text(kv, "Warded Cloth & the Archmage's Robe"), "lw_knowledge: the leatherworker's credit")
	await pt.shot("lwk_%s_07_workshop_knowledge_lower" % tag)
	pt.expect(await pt.click("The Skill Tree", tp), "lw_knowledge: back to the tree")
	await pt.wait(0.4)
	await pt.close_panel()


# ---------------------------------------------------------------- 5. a station's Designs
func _station() -> void:
	await pt.close_panel()
	StationPanel.avail = "all"
	StationPanel.cat = "all"
	StationPanel.everywhere = false
	StationPanel.query = "robe"
	Events.open_panel.emit("station", {"id": "tailors_bench"})
	await pt.wait(1.0)
	if WK != null:
		pt.expect(_text(pt.panel(), "Designs "), "lw_knowledge: the station lists Designs")
	await pt.shot("lwk_%s_08_station_designs" % tag)
	StationPanel.query = ""
	await pt.close_panel()


# ---------------------------------------------------------------- 6. Help
func _help() -> void:
	Events.open_panel.emit("help", {"topic": "skilltree"})
	await pt.wait(1.0)
	var le := _find_line_edit(pt.panel())
	if le:
		le.text = "own path"
		le.text_changed.emit(le.text)
		await pt.wait(0.6)
	if WK != null:
		pt.expect(_text(pt.panel(), "Your own path") or _text(pt.panel(), "The Skill Tree"), "lw_knowledge: Help explains your path and the workshop's knowledge")
	await pt.shot("lwk_%s_09_help_skill_tree" % tag)
	await pt.close_panel()


func _find_line_edit(n: Node) -> LineEdit:
	if n == null:
		return null
	if n is LineEdit:
		return n
	for c in n.get_children():
		var r := _find_line_edit(c)
		if r:
			return r
	return null
