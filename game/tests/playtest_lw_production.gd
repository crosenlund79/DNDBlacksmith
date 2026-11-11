## Rendered play-test phases of The Living Workshop's PRODUCTION worker (#37 station instances, C1 work orders).
## "lw_stations": three anvils and three forges in the workshop, bought one by one ("Another · price"), each placed
##   and shown as its own instance; three journeymen working at three anvils at once instead of queueing at the first;
##   the Ledger's station list and the panel of "Anvil #2". Shots lws_*.
## "lw_emberwarden": the Emberwarden Longsword as one work order — "Order it" at the anvil, the Ledger's five stages,
##   the ember marker and "Your stage" at the forge, the smith's forging, the runesmith at the rune engraving stand,
##   a save and load in the middle of the rune stage, the alchemist at the cauldron, the smith's honing at the grinding
##   wheel, the leatherworker at the stitching table, the finished sword's origin (maker and contributors) and history,
##   and the sword sold with its provenance. Shots lwe_*.
## Called from tests/playtest.gd (phase_lw_stations, phase_lw_emberwarden).
extends RefCounted

const EMBER := "emberwarden_longsword"
const FIN := ["done", "failed", "cancelled"]

var pt: Node


func _w() -> VillageWorld:
	return pt.W()


func _text(root: Node, needle: String) -> bool:
	if root == null:
		return false
	if pt.find_label_containing(root, needle) != null:
		return true
	for n in root.find_children("*", "RichTextLabel", true, false):   # rich text not laid out yet: its source
		if (n as RichTextLabel).text.contains(needle):
			return true
	return false


func _start(gold := 20000) -> void:
	await pt.click("New Game")
	await pt.wait(2.5)
	Shop.customers().clear()
	Game.state["gold"] = gold
	await pt.grant_full_workshop()   # every room and station; the workshop knows every Design
	pt.note(ApprenticeDev.unlock())


## Looks at a world position (the smith stands well below it, out of the way, so the camera frames it).
func _look(pos: Vector2, zoom := 0.8) -> void:
	var w := _w()
	await pt.tp(pos + Vector2(0, 290))
	w.camera.zoom = Vector2(zoom, zoom)
	w.camera.reset_smoothing()
	await pt.wait(1.4)


func _zoom_reset() -> void:
	_w().camera.zoom = Vector2.ONE


## Buys another of a type and sets it up in a free spot. Returns the instance id ("" on failure).
func _another(t: String) -> String:
	var before := Property.instances(t, false)
	var err := Property.buy_station(t)
	pt.expect(err == "", "another %s is bought (%s)" % [t, err])
	var iid := ""
	for x in Property.instances(t, false):
		if not before.has(x):
			iid = str(x)
	if iid == "":
		return ""
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, iid)
	pt.expect(why == "" and Property.commit(plan) == "", "%s is set up (%s)" % [iid, why])
	return iid


## Advances the clock in 5-minute steps until `cond` holds (at most `max_min`); returns whether it did.
func _until(cond: Callable, max_min := 600) -> bool:
	var g := 0
	while not cond.call() and g < max_min:
		Game.advance_minutes(5)
		g += 5
	return cond.call()


# ======================================================================= lw_stations
func run_stations(p: Node) -> void:
	pt = p
	await _start()
	var hands := []
	for nm in ["Tobin Brand", "Wren Holt", "Corwin Vell", "Ada Marsh"]:
		var a := Apprentices.dev_take_on("blacksmith", 6, "journeyman", nm)
		if not a.is_empty():
			hands.append(a)
	pt.expect(hands.size() == 4, "lw_stations: four journeyman blacksmiths on the staff (%d)" % hands.size())
	pt.expect(Property.max_instances("anvil") == 5, "lw_stations: five pairs of hands may keep five anvils busy (%d)" % Property.max_instances("anvil"))
	var a2 := _another("anvil")
	var a3 := _another("anvil")
	_another("forge")
	_another("forge")
	pt.note("   anvils %s · forges %s" % [str(Property.instances("anvil")), str(Property.instances("forge"))])
	pt.main.call("rebuild_world")
	await pt.wait(2.5)
	pt.expect(pt.find_entry("station", a2) != {} and pt.find_entry("station", a3) != {}, "lw_stations: each anvil is its own place in the world (%s, %s)" % [a2, a3])
	# the property panel: equipment (another, at its price) and the layout with the instances
	Events.open_panel.emit("property", {})
	await pt.wait(0.9)
	await pt.click("Equipment")
	await pt.wait(0.7)
	pt.expect(_text(pt.panel(), "3 set up"), "lw_stations: the equipment list says three anvils are set up")
	var more := pt.panel().find_child("BuyAnother_anvil", true, false) as Button
	pt.expect(more != null and more.text.begins_with("Another ·"), "lw_stations: …and offers another at its price (%s)" % (more.text if more else "none"))
	await pt.shot("lws_property_equipment")
	await pt.click("Workshop layout")
	await pt.wait(0.7)
	await pt.shot("lws_layout_instances")
	await pt.close_panel()
	# three hatchets each for three of them: they spread over the anvils and forges
	for d in [["ingot_iron", 40], ["coal", 40]]:
		Game.add_item(Items.make(str(d[0]), {"qty": int(d[1])}), false)
	var tasks := []
	for i in 3:
		var t := Apprentices.add_task("craft", {"recipe": "iron_hatchet", "repeat": 4, "assignee": str(hands[i]["id"])})
		pt.expect(not t.has("error"), "lw_stations: hatchets queued for %s (%s)" % [hands[i]["name"], t.get("error", "")])
		tasks.append(t)
	await pt.advance_to(8, 0)
	var best := 0
	var g := 0
	while g < 160:
		Game.advance_minutes(5)
		g += 1
		var used := {}
		for t2 in tasks:
			var at := str(t2.get("station", ""))
			if Property.type_of(at) == "anvil" and str(t2.get("state", "")) == "working":
				used[at] = true
		best = maxi(best, used.size())
		if used.size() >= 3:
			break
	pt.note("   anvils in use at once: %d" % best)
	pt.expect(best >= 2, "lw_stations: several anvils are worked at the same time (%d at once)" % best)
	await pt.wait(1.0)   # the figures walk to their places
	var c := Vector2.ZERO
	for sid in Property.instances("anvil"):
		c += _w().station_pos(str(sid))
	c /= float(Property.instances("anvil").size())
	await _look(c, 0.95)
	await pt.wait(1.5)
	await pt.shot("lws_three_anvils_at_work")
	_zoom_reset()
	Events.open_panel.emit("workshop", {})
	await pt.wait(0.9)
	pt.expect(_text(pt.panel(), "Anvil #2"), "lw_stations: the Ledger lists Anvil #2 on its own")
	await pt.shot("lws_ledger_stations")
	await pt.close_panel()
	Events.open_panel.emit("station", {"id": a2})
	await pt.wait(0.9)
	pt.expect(pt.panel() is StationPanel and (pt.panel() as StationPanel).station_id == a2, "lw_stations: Anvil #2 opens its own panel")
	await pt.shot("lws_station_anvil2")
	await pt.close_panel()


## Waits (real time, at most `max_s` seconds) until a worker's figure has walked up to its station — the handoff
## happens in game time, the figure crosses the workshop at walking pace.
func _wait_figure(a: Dictionary, sid: String, max_s := 20.0) -> void:
	var aa := _w().get_node_or_null("ApprenticeActors")
	var waited := 0.0
	while waited < max_s:
		var n: Node2D = aa.actors.get(str(a["id"])) if aa != null else null
		if n != null and n.visible and n.position.distance_to(_w().station_pos(sid)) < 150.0 and (n as NPCActor).path.is_empty():
			break
		await pt.wait(0.25)
		waited += 0.25
	pt.note("   %s walked to the %s in %.1f s" % [str(a["name"]).split(" ")[0], sid, waited])


## The item inspection overlay (ItemPanel), or null.
func _item_overlay() -> Node:
	var stack: Array = [pt.get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ItemPanel:
			return n
		stack.append_array(n.get_children())
	return null


func _close_item() -> void:
	await pt.press("cancel")   # the inspection is an overlay
	await pt.wait(0.3)


## Where a worker's figure stands, seen against the station they work at (logged, and checked: beside it).
func _figure_at(a: Dictionary, sid: String, what: String) -> void:
	var aa := _w().get_node_or_null("ApprenticeActors")
	var n: Node2D = aa.actors.get(str(a["id"])) if aa != null else null
	var sp := _w().station_pos(sid)
	var d := n.position.distance_to(sp) if n != null else -1.0
	pt.note("   %s's figure: %s, %d px from the %s (visible %s)" % [str(a["name"]), str(n.position) if n != null else "none", int(d), sid, str(n != null and n.visible)])
	pt.expect(n != null and n.visible and d >= 0.0 and d < 170.0, "%s: %s stands at the %s" % [what, str(a["name"]).split(" ")[0], Property.instance_label(sid).to_lower()])


# ======================================================================= lw_emberwarden
var rune := {}
var alch := {}
var leath := {}


func _smith_steps_here() -> void:
	# the smith's checks at the station he stands at (the minigame's outcome, as the suite plays it): good, steady work
	var qs := []
	for i in int(Crafting.current_op().get("checks", 1)):
		qs.append(104.0)
	Crafting.record_step(Crafting.smith_instance(), qs)
	await pt.wait(0.4)


func _walk_smith_to(sid: String) -> void:
	await _look(_w().station_pos(Smithy.instance_for_smith(sid, _w())), 0.85)


func run_emberwarden(p: Node) -> void:
	pt = p
	await _start()
	var g := 0
	while Game.player_level("smithing") < 8 and g < 50:
		Game.grant_player_xp("smithing", SkillSys.xp_needed(Game.player_level("smithing") + 1))
		g += 1
	rune = Apprentices.dev_take_on("runesmith", 7, "journeyman", "Edda Vell")
	alch = Apprentices.dev_take_on("alchemist", 7, "journeyman", "Mira Holt")
	leath = Apprentices.dev_take_on("leatherworker", 7, "journeyman", "Wren Marsh")
	pt.expect(not rune.is_empty() and not alch.is_empty() and not leath.is_empty(), "lw_emberwarden: a runesmith, an alchemist and a leatherworker are on the staff")
	for d in DB.recipe(EMBER)["inputs"]:
		Game.add_item(Items.make(str(d), {"qty": int(DB.recipe(EMBER)["inputs"][d])}), false)
	pt.main.call("rebuild_world")
	await pt.wait(2.0)
	await pt.advance_to(8, 0)
	# 1. at the anvil: the Emberwarden is beyond the smith alone — "Order it"
	StationPanel.avail = "all"
	StationPanel.cat = "all"
	StationPanel.everywhere = false
	StationPanel.query = "Emberwarden"
	Events.open_panel.emit("station", {"id": "anvil"})
	await pt.wait(0.9)
	pt.expect(pt.find_button(pt.panel(), "Order it") != null, "lw_emberwarden: the anvil offers to order the Emberwarden as a work order")
	await pt.shot("lwe_anvil_order_it")
	await pt.click("Order it")
	await pt.wait(0.8)
	await pt.close_panel()
	StationPanel.query = ""
	var t := {}
	for x in Apprentices.open_tasks():
		if str(x.get("recipe", "")) == EMBER:
			t = x
	pt.expect(not t.is_empty(), "lw_emberwarden: the work order is queued")
	if t.is_empty():
		return
	var tid := int(t["id"])
	var uid := int(t.get("uid", 0))
	pt.note("   order #%d, uid %d reserved, stages %s" % [tid, uid, str(WorkOrders.stages(t).map(func(s): return "%s:%s" % [s["disc"], s["assignee"]]))])
	pt.expect(uid > 0 and Game.find_uid(uid).is_empty(), "lw_emberwarden: the sword's uid is reserved and nothing half-made sits in the stores")
	# 2. the Ledger: five stages, two of them the smith's
	Events.open_panel.emit("workshop", {})
	await pt.wait(0.9)
	pt.expect(pt.panel().find_child("Stages_%d" % tid, true, false) != null, "lw_emberwarden: the Ledger shows the order's stages")
	pt.expect(_text(pt.panel(), "yours"), "lw_emberwarden: …the forging and the honing are the smith's")
	await pt.shot("lwe_ledger_stages")
	await pt.close_panel()
	# 3. the forge: the ember marker, then his stage
	Game.advance_minutes(5)
	await _walk_smith_to("forge")
	await pt.shot("lwe_forge_marker")
	Events.open_panel.emit("station", {"id": Smithy.instance_for_smith("forge", _w())})
	await pt.wait(0.9)
	pt.expect(pt.panel().find_child("MyStage", true, false) != null, "lw_emberwarden: the forge offers his stage of the order")
	await pt.shot("lwe_forge_your_stage")
	await pt.close_panel()
	pt.expect(WorkOrders.begin_smith_stage(tid) == "", "lw_emberwarden: he takes up his stage")
	Events.open_panel.emit("station", {"id": Crafting.smith_instance()})
	await pt.wait(0.9)
	await pt.shot("lwe_forge_order_job")
	await pt.close_panel()
	await _smith_steps_here()
	await _walk_smith_to("anvil")
	await _smith_steps_here()
	pt.expect(not Crafting.active() and str(WorkOrders.stages(t)[0]["by"]) == "player", "lw_emberwarden: the smith forged the blade; it goes on to the rune stage")
	# 4. the runesmith at the rune engraving stand
	pt.expect(_until(func(): return str(t.get("worker", "")) == str(rune["id"]) and float(t.get("progress", 0.0)) > 8.0, 300), "lw_emberwarden: the runesmith seats the rune")
	await pt.wait(1.0)
	await _look(_w().station_pos(str(t.get("station", "rune_engraving_stand"))), 0.85)
	await _wait_figure(rune, str(t.get("station", "rune_engraving_stand")))
	_figure_at(rune, str(t.get("station", "rune_engraving_stand")), "lw_emberwarden")
	await pt.shot("lwe_runesmith_at_rune_stand")
	Events.open_panel.emit("workshop", {})
	await pt.wait(0.9)
	await pt.shot("lwe_ledger_rune_stage")
	await pt.close_panel()
	# 5. saved and loaded in the middle of the rune stage
	var mid := JSON.stringify({"ops": t["ops_done"], "taken": t["taken"], "uid": t["uid"]})
	var inv := [Game.count("ingot_steel"), Game.count("runestone_ember"), Game.count("sword_emberwarden")]
	pt.expect(Saves.save("lw_ember_mid"), "lw_emberwarden: saved mid-stage")
	pt.main.call("load_slot", "lw_ember_mid")
	await pt.wait(3.0)
	Saves.delete("lw_ember_mid")
	t = Apprentices.task(tid)
	rune = Apprentices.get_a(str(rune["id"]))
	alch = Apprentices.get_a(str(alch["id"]))
	leath = Apprentices.get_a(str(leath["id"]))
	pt.expect(not t.is_empty() and JSON.stringify({"ops": t["ops_done"], "taken": t["taken"], "uid": t["uid"]}) == mid, "lw_emberwarden: after loading the order is exactly as it was")
	pt.expect([Game.count("ingot_steel"), Game.count("runestone_ember"), Game.count("sword_emberwarden")] == inv, "lw_emberwarden: no material came back or doubled")
	await pt.wait(1.0)
	await _look(_w().station_pos(str(t.get("station", "rune_engraving_stand")) if str(t.get("station", "")) != "" else "rune_engraving_stand"), 0.85)
	if str(t.get("station", "")) != "":
		_figure_at(rune, str(t["station"]), "lw_emberwarden after loading")
	await pt.shot("lwe_after_load_runesmith")
	# 6. the alchemist at the cauldron
	pt.expect(_until(func(): return str(t.get("worker", "")) == str(alch["id"]) and float(t.get("progress", 0.0)) > 8.0, 400), "lw_emberwarden: the alchemist quenches the edge")
	await pt.wait(1.0)
	await _look(_w().station_pos(str(t.get("station", "cauldron"))), 0.85)
	await _wait_figure(alch, str(t.get("station", "cauldron")))
	_figure_at(alch, str(t.get("station", "cauldron")), "lw_emberwarden")
	await pt.shot("lwe_alchemist_at_cauldron")
	# 7. the smith's honing at the grinding wheel
	pt.expect(_until(func(): return not WorkOrders.waiting_for_smith().is_empty(), 400), "lw_emberwarden: the honing waits for the smith")
	await _walk_smith_to("grinding_wheel")
	Events.open_panel.emit("station", {"id": Smithy.instance_for_smith("grinding_wheel", _w())})
	await pt.wait(0.9)
	await pt.shot("lwe_wheel_your_stage")
	await pt.close_panel()
	pt.expect(WorkOrders.begin_smith_stage(tid) == "", "lw_emberwarden: he hones the burning edge")
	await _smith_steps_here()
	# 8. the leatherworker at the stitching table
	pt.expect(_until(func(): return str(t.get("worker", "")) == str(leath["id"]) and float(t.get("progress", 0.0)) > 5.0, 300), "lw_emberwarden: the leatherworker wraps the grip")
	await pt.wait(1.0)
	await _look(_w().station_pos(str(t.get("station", "stitching_table"))), 0.85)
	await _wait_figure(leath, str(t.get("station", "stitching_table")))
	_figure_at(leath, str(t.get("station", "stitching_table")), "lw_emberwarden")
	await pt.shot("lwe_leatherworker_at_table")
	pt.expect(_until(func(): return str(t["state"]) in FIN, 300), "lw_emberwarden: the order is finished (%s)" % str(t.get("state", "")))
	# 9. the finished sword: maker, contributors, history
	var it := Game.find_uid(uid)
	pt.expect(not it.is_empty() and str(it.get("def", "")) == "sword_emberwarden", "lw_emberwarden: the sword is in the stores under the reserved uid %d" % uid)
	if it.is_empty():
		return
	pt.expect(str(Provenance.maker(it).get("id", "")) == Provenance.SMITH_ID, "lw_emberwarden: the smith is the maker")
	pt.expect(Provenance.contributors(it).size() == 3, "lw_emberwarden: three specialists recorded (%d)" % Provenance.contributors(it).size())
	pt.note("   contributors: %s" % str(Provenance.contributors(it).map(func(e): return "%s (%s) %d%%" % [e["name"], e["profession"], int(e["quality"])])))
	Events.open_panel.emit("item", {"uid": uid, "tab": "Overview"})
	await pt.wait(1.0)
	pt.expect(_text(_item_overlay(), "Stages worked by") and _text(_item_overlay(), "Edda Vell"), "lw_emberwarden: the sword's origin names the specialists beside the maker")
	await pt.shot("lwe_item_origin")
	await _close_item()
	Events.open_panel.emit("item", {"uid": uid, "tab": "History"})
	await pt.wait(1.0)
	pt.expect(_text(_item_overlay(), "worked their stages"), "lw_emberwarden: the sword's history holds the contributors' Lore event")
	await pt.shot("lwe_item_history")
	await _close_item()
	# 10. sold with its provenance
	it["for_sale"] = true
	var sold := ""
	for aid in Adv.all():
		var a: Dictionary = Adv.all()[aid]
		a["gold"] = 9000
		it["price"] = 1
		if Shop.sell_to(str(aid), uid) == "":
			sold = str(aid)
			break
	pt.expect(sold != "", "lw_emberwarden: an adventurer buys the Emberwarden")
	var held := Game.find_uid_anywhere(uid)
	pt.expect(not held.is_empty() and str(Provenance.maker(held).get("id", "")) == Provenance.SMITH_ID and Provenance.contributors(held).size() == 3,
		"lw_emberwarden: in the buyer's hands it is the same sword, maker and contributors intact")
	Events.open_panel.emit("item", {"uid": uid, "tab": "Owners"})
	await pt.wait(1.0)
	await pt.shot("lwe_item_sold")
	await _close_item()
	var sc := ItemRegistry.scan()
	pt.expect((sc["dup"] as Array).is_empty() and (sc["stray"] as Array).is_empty(), "lw_emberwarden: identity clean (%s)" % ItemRegistry.scan_text(sc))
