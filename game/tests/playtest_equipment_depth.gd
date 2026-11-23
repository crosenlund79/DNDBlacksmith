## Rendered play-test phase "equipment_depth" (R5): an arcanist at the spellbinding array binds a deep property into an
## existing sword (the risk stated before the work), the item card then shows its effects, arcana and set apart from its
## plain stats, and the anvil's "Temper beyond" states its danger and asks for a deliberate second click.
## Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.wait(0.7)
	await pt.shot(name)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	Property.dev_grant_all()
	SkillTree.unlock_all()
	if not Game.has_upgrade("arcane_foundry"):
		(Game.state["upgrades"] as Array).append("arcane_foundry")
	Game.state["gold"] = 9000
	var arc := Apprentices.dev_take_on("arcanist", 9, "journeyman", "Ysolde Marr")
	pt.expect(not arc.is_empty(), "equipment_depth: an arcanist joins the staff")
	for pair in [["infusion_aether", 4], ["thread_ethereal", 4], ["ingot_steel", 6], ["coal", 6]]:
		Game.add_item(Items.make(str(pair[0]), {"qty": int(pair[1])}), false)
	var sword := Items.make("sword_steel", {"quality": 96.0})
	Provenance.forged(sword)
	(sword["affixes"] as Array).append({"id": "keen", "stat": "attack", "value": 4})
	(sword["affixes"] as Array).append({"id": "leech", "stat": "leech", "value": 2})
	sword["rarity"] = "rare"
	Game.add_item(sword, false)
	var uid := int(sword["uid"])
	# the arcanist's binding: the screen states who does it and the risk
	Events.open_panel.emit("refine", {"station": "spellbinding_array", "uid": uid, "action": "enchant"})
	await _shot("equipment_depth_enchant_plan")
	pt.expect(pt.panel() is RefinePanel, "equipment_depth: the binding screen opens at the spellbinding array")
	var risk: Node = pt.panel().find_child("Risk", true, false) if pt.panel() != null else null
	pt.expect(risk != null, "equipment_depth: the risk is stated before the work")
	await pt.close_panel()
	var r := Refinement.perform(uid, "enchant", 96.0, {"target": "lambent"})
	pt.expect(bool(r.get("ok", false)), "equipment_depth: the arcanist binds Lambent into the same sword (%s)" % str(r.get("summary", r.get("text", ""))))
	# the item card: effects, arcana and set, apart from the stats
	Events.open_panel.emit("item", {"uid": uid, "tab": "Overview"})
	await _shot("equipment_depth_item_card")
	await pt.close_panel()
	var tip := Items.tooltip(Game.find_uid(uid))
	pt.expect(tip.contains("Keen") and tip.contains("Arcane: Lambent") and tip.contains("Set: Hearthguard"), "equipment_depth: the tooltip shows its effects, its arcana and its set")
	# the warned experiment
	Events.open_panel.emit("refine", {"station": "anvil", "uid": uid, "action": "experiment"})
	await _shot("equipment_depth_experiment_warning")
	var rk: Node = pt.panel().find_child("Risk", true, false) if pt.panel() != null else null
	pt.expect(rk != null and str((rk as RichTextLabel).text).contains("EXTRAORDINARY"), "equipment_depth: the experiment's danger is stated plainly")
	var go: Button = pt.panel().find_child("BeginWork", true, false) if pt.panel() != null else null
	pt.expect(go != null and str(go.text).contains("read the danger"), "equipment_depth: the first button only shows the danger (%s)" % (go.text if go else "?"))
	await pt.close_panel()
	pt.expect(not Game.find_uid(uid).is_empty(), "equipment_depth: nothing happened to the sword without the second, deliberate click")
