## Rendered play-test phase "s2_econdev" (Milestone S2 — the ECONDEV worker): what the player sees of the fixes.
##  1. Affordability, on Apprentice: a starting Rogue's saving goal in her Career page (the shop's real price), the Salt
##     Anvil's bench with plain everyday pieces, and a consultation that points a buyer the forge is too dear for to a
##     plain piece there — at the price she would pay.
##  2. Consultation and counter: a gear-seeker's advice puts the piece she would buy before "keep your coin"; the
##     advice is taken and she wears the very piece; at the counter the compact offer grid compares her piece with
##     yours and nothing sells until "Sell for N g".
##  3. The developer tools (F10): locked while cheats are off; "CHEATS ON" banner once enabled; the skill-check bypass
##     plays a forge step without the minigame; the counter and Project Bench scenarios; cheats off again.
## Runs on older builds too (new functions are called only when present), so the same script takes the "before" shots.
## Shot names: s2econ_<tag>_* (tag from the S2ECON_TAG environment variable, default "after").
## Called from tests/playtest.gd (phase_s2_econdev).
extends RefCounted

var pt: Node
var tag := "after"


func _shot(n: String) -> void:
	await pt.wait(0.5)
	await pt.shot("s2econ_%s_%s" % [tag, n])


## Calls a static function of a system script when this build has it (null otherwise).
func _call(path: String, method: String, args := []) -> Variant:
	var sc: Script = load(path)
	for m in sc.get_script_method_list():
		if m["name"] == method:
			return sc.callv(method, args)
	return null


func _has(path: String, method: String) -> bool:
	var sc: Script = load(path)
	for m in sc.get_script_method_list():
		if m["name"] == method:
			return true
	return false


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	Shop.remove_customer(id)
	return a


func _seat(npc: String, want: String) -> void:
	Shop.customers().clear()
	Shop._add_customer(npc, want)
	for c in Shop.customers():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func run(p: Node) -> void:
	pt = p
	tag = OS.get_environment("S2ECON_TAG") if OS.get_environment("S2ECON_TAG") != "" else "after"
	await pt.click("New Game")
	await pt.wait(2.5)
	(Game.state["hirelings"] as Array).clear()
	Shop.customers().clear()
	Expeditions.set_difficulty("apprentice")
	await _affordability()
	await _consult_and_counter()
	await _dev_tools()


# ------------------------------------------------------------------ 1. affordability, as an adventurer meets it
func _affordability() -> void:
	var a := _adv("kestra")
	a["equipment"].erase("boots")
	a["gold"] = 40
	a["goals"] = [{"kind": "gear", "since": 1, "target": int(Adv.gear_score(a) * 1.3) + 8}]
	Adv.evaluate_gear(a)
	var sv: Dictionary = a.get("saving_for", {})
	pt.note("s2econ: Kestra (%s, level %d, 40 g) saves for %s: goal %d g" % [a["cls"], int(a["level"]), str(sv.get("slot", "-")), int(sv.get("goal", 0))])
	if not sv.is_empty():
		var goal_def := ""
		var best := 0
		for id in DB.items:
			var d: Dictionary = DB.items[id]
			if str(d.get("slot", "")) == str(sv["slot"]) and Adv.affinity(a, {"def": id}) > 0.0 and int(d.get("value", 0)) <= 60 + int(a["level"]) * 45 and int(d.get("value", 0)) > best:
				best = int(d.get("value", 0))
				goal_def = str(id)
		var real := Shop.price_of(Items.make(goal_def, {"quality": 80.0, "rarity": "common"})) if goal_def != "" else 0
		pt.note("s2econ: the shop asks %d g for a plain %s at 80%% — the goal is %d g" % [real, goal_def, int(sv["goal"])])
		if tag == "after":
			pt.expect(int(sv["goal"]) == real, "s2econ: her saving goal is the shop's real price (%d g)" % real)
	Events.open_panel.emit("dossier", {"id": "kestra", "tab": "Career"})
	await pt.wait(0.9)
	await _shot("01_saving_goal")
	await pt.close_panel()
	# the Salt Anvil's bench: plain everyday pieces beside her sea-bronze
	Commerce.st()["rival"].erase("stock")
	var plain := 0
	for k in 6:
		plain = 0
		for e in Commerce.rival_stock():
			if bool(e.get("plain", false)):
				plain += 1
		if plain >= 4 or tag != "after":
			break
		Commerce.st()["rival"].erase("stock")
	if tag == "after":
		pt.expect(plain >= 1, "s2econ: the Salt Anvil has %d plain everyday pieces" % plain)
	for e in Commerce.rival_stock():
		if e.has("item"):
			var adv_p: Variant = _call("res://scripts/systems/commerce.gd", "rival_adv_price", [e])
			pt.note("s2econ: Salt Anvil %s — the smith pays %d g, an adventurer pays %d g" % [str(e["item"]["name"]), int(e["price"]), int(adv_p) if adv_p != null else int(e["price"])])
	Events.open_panel.emit("rival_smith", {})
	await pt.wait(0.9)
	await _shot("02_salt_anvil")
	await pt.close_panel()
	# a buyer the forge is too dear for: the honest advice names a plain piece at her price
	var b := _adv("kestra")
	b["equipment"].erase("gloves")
	var star := Items.make("sword_starsteel", {"quality": 80.0})
	star["stats"]["durability"] = int(int(star["stats"]["durability_max"]) * 0.2)
	b["equipment"]["weapon"] = star
	b["gold"] = Adv.repair_cost(star) - 1
	var ro := {}
	for k in 12:
		ro = Commerce.rival_offer_for(b)
		if not ro.is_empty() or tag != "after":
			break
		Commerce.st()["rival"].erase("stock")
	var kinds := Consult.recommendations(b).map(func(r): return "%s (%d g)" % [str(r["kind"]), int(r["cost"])])
	pt.note("s2econ: Kestra with %d g, a worn starsteel blade: advice %s" % [int(b["gold"]), str(kinds)])
	if tag == "after":
		pt.expect(str(kinds).contains("elsewhere"), "s2econ: she is pointed to the Salt Anvil's plain %s for %d g" % [str(ro.get("item", {}).get("name", "?")), int(ro.get("price", 0))])
	Consult.st()["sessions"].erase("kestra")
	Events.open_panel.emit("consult", {"id": "kestra"})
	await pt.wait(0.9)
	await _shot("03_consult_salt_anvil")
	await pt.close_panel()
	Consult.st()["sessions"].erase("kestra")


# ------------------------------------------------------------------ 2. consultation and the counter
func _consult_and_counter() -> void:
	Expeditions.set_difficulty("journeyman")
	for it in Game.inventory().duplicate():
		if Items.is_equipment(it):
			Game.take_uid(int(it["uid"]))
	# a gear-seeker with a sound kit, an easy trip and a better shield in the stores
	var s := _adv("sigrun")
	for sl in s["equipment"]:
		var it2: Dictionary = s["equipment"][sl]
		it2.erase("broken")
		if it2.get("stats", {}).has("durability_max"):
			it2["stats"]["durability"] = int(it2["stats"]["durability_max"])
	s["equipment"]["weapon"]["coating"] = {"name": "Flame Coating", "stat": "fire", "value": 4, "uses": 3}
	s["next_dest"] = "ironroot_mine"
	s["goals"] = [{"kind": "gear", "since": 1, "target": int(Adv.gear_score(s) * 1.3) + 8}]
	s["gold"] = 400
	Social.change("sigrun", 80.0, 40.0, "", "", false)
	var kite := Items.make("shield_kite", {"quality": 96.0, "rarity": "common"})
	Provenance.forged(kite)
	Game.add_item(kite, false)
	var helm := Items.make("helm_iron", {"quality": 92.0, "rarity": "common"})
	Provenance.forged(helm)
	Game.add_item(helm, false)
	var ses := Consult.session("sigrun")
	var order := (ses["recs"] as Array).map(func(r): return "%s %.2f" % [str(r["kind"]), float(r["relevance"])])
	pt.note("s2econ: Sigrun's advice, in order: %s" % str(order))
	var buy := {}
	for r in ses["recs"]:
		if str(r["kind"]) == "buy" and buy.is_empty():
			buy = r
	Events.open_panel.emit("consult", {"id": "sigrun"})
	await pt.wait(0.9)
	await _shot("04_consult_offer")
	if not buy.is_empty():
		for sd in range(1, 400):
			Game.state["world_seed"] = sd
			if Consult.roll("sigrun", str(buy["id"])) < 0.3:
				break
		var uid := int(buy["uid"])
		var maker := str(Provenance.maker(Game.find_uid(uid)).get("name", ""))
		var cp: Control = pt.panel()
		if cp != null and cp.has_method("_advise"):
			cp.call("_advise", str(buy["id"]))
		await pt.wait(0.8)
		var worn: Dictionary = s["equipment"].get(str(buy["slot"]), {})
		pt.expect(int(worn.get("uid", -1)) == uid and str(Provenance.maker(worn).get("name", "")) == maker, "s2econ: Sigrun took the advice and wears the very piece (uid %d, maker %s)" % [uid, maker])
		await _shot("05_consult_sold")
	await pt.close_panel()
	Consult.finish("sigrun")
	# the counter: compact offer grid, comparison, explicit sale
	var pip := _adv("pip")
	pip["gold"] = 400
	var good := Items.make("sword_iron", {"quality": 96.0})
	Provenance.forged(good)
	good["for_sale"] = true
	Game.add_item(good, false)
	for def in ["dagger", "axe_hand", "mace_flanged", "helm_iron", "shield_round", "boots_leather", "chainmail", "sword_short"]:
		var o := Items.make(def, {"quality": 82.0})
		o["for_sale"] = true
		Game.add_item(o, false)
	_seat("pip", "browse")
	Events.open_panel.emit("shop", {"npc": "pip"})
	await pt.wait(0.9)
	var picker: Node = pt.panel().find_child("OfferPicker", true, false) if pt.panel() else null
	pt.expect(picker != null, "s2econ: the counter shows the compact offer grid")
	if picker != null:
		picker.call("select_uid", int(good["uid"]))
		await pt.wait(0.4)
		pt.expect(not Game.find_uid(int(good["uid"])).is_empty(), "s2econ: choosing a piece does not sell it")
		await _shot("06_offer_compare")
		var sell: Button = pt.find_button(picker, "Sell for")
		pt.expect(sell != null, "s2econ: an explicit 'Sell for N g' button")
		if sell != null:
			var g0 := Game.gold()
			var p0 := int(pip["gold"])
			sell.pressed.emit()
			await pt.wait(0.6)
			pt.expect(int(pip["equipment"].get("weapon", {}).get("uid", -1)) == int(good["uid"]) and p0 - int(pip["gold"]) == Game.gold() - g0,
				"s2econ: Pip wears the same longsword and paid from his purse what the smith received (%d g)" % (Game.gold() - g0))
			await _shot("07_offer_sold")
	await pt.close_panel()


# ------------------------------------------------------------------ 3. the developer tools
func _dev_tools() -> void:
	Shop.customers().clear()
	await pt.press("dev_panel")
	await pt.wait(0.8)
	pt.expect(pt.panel() is DevPanel, "s2econ: F10 opens the developer tools")
	await _shot("08_dev_tools_off")
	if not _has("res://scripts/systems/dev_tools.gd", "set_enabled"):
		pt.note("s2econ: this build has no cheat switch (before S2): every tool is live in normal play")
		await pt.close_panel()
		return
	pt.expect(pt.find_button(pt.panel(), "Smithing kit") == null, "s2econ: with cheats off the tools are locked")
	await pt.click("Enable cheats for this session")
	await pt.wait(0.4)
	pt.expect(bool(_call("res://scripts/systems/dev_tools.gd", "indicator_visible")), "s2econ: the CHEATS ON banner shows")
	await pt.click("Skill-check bypass")
	await _shot("09_dev_tools_on")
	# crafting scenario + bypass: the forge step is done without the minigame
	await pt.click("Crafting: materials, then the forge")
	await pt.wait(1.0)
	pt.expect(pt.panel() is StationPanel, "s2econ: the crafting scenario opens the forge")
	var rid := "iron_longsword"
	if pt.panel() is StationPanel:
		pt.panel().call("_start", rid)
		await pt.wait(1.0)
		pt.expect(Crafting.active() and Crafting.current_station() != "forge", "s2econ: the forge step was bypassed (next: %s)" % Crafting.current_station())
		await _shot("10_bypassed_check")
	await pt.close_panel()
	if Crafting.active():
		Crafting.cancel()
	# the counter scenario
	await pt.press("dev_panel")
	await pt.wait(0.6)
	await pt.click("Commission request at the counter")
	await pt.wait(1.0)
	pt.expect(pt.panel() is ShopPanel, "s2econ: the counter scenario seats a customer with a request")
	await _shot("11_scenario_counter")
	await pt.close_panel()
	# the Project Bench scenario (sets the bench up, rebuilds the world)
	await pt.press("dev_panel")
	await pt.wait(0.6)
	await pt.click("Contract at the Project Bench")
	await pt.wait(3.0)
	pt.expect(not Contracts.active().is_empty(), "s2econ: a contract is accepted at the Project Bench")
	await _shot("12_scenario_contract")
	await pt.close_panel()
	# cheats off: the banner goes
	await pt.press("dev_panel")
	await pt.wait(0.6)
	await pt.click("Switch cheats off")
	await pt.close_panel()
	pt.expect(not bool(_call("res://scripts/systems/dev_tools.gd", "indicator_visible")), "s2econ: cheats off — the banner is gone")
	await _shot("13_cheats_off")
