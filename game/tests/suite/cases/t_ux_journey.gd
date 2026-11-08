## A normal player's journey (UX iteration): choose an Iron Longsword, see what is missing, learn how to get it
## from the game's own guidance, acquire everything through ordinary play (buy raw hide at Pell's Provisions in opening
## hours, buy and set up a Leather Vat, cure the leather), forge the blade, refine it at the grinding wheel — and find
## the same piece afterwards: same uid, maker, mark and name, a longer history. Then save and load.
extends SuiteCase

const SMOKE := ["test_longsword_journey"]


func _at_hour(h: int) -> void:
	var m := int(Game.state["minute"])
	var target := h * 60
	Game.advance_minutes((target - m + 1440) % 1440)


func test_longsword_journey() -> void:
	fresh_game()
	_at_hour(9)
	Game.state["gold"] = 400
	Game.remove_def("leather_cured", Game.count("leather_cured"))
	Game.remove_def("leather_hide", Game.count("leather_hide"))
	# 1. what is missing, and why
	var rs := Guide.recipe_status("iron_longsword")
	eq(str(rs["state"]), "missing", "1. the longsword shows as missing materials")
	check(rs["missing"].has("leather_cured") and not rs["missing"].has("ingot_iron"), "only the cured leather is missing (%s)" % str(rs["missing"]))
	check(Reference.topic_visible("item:leather_cured"), "the missing ingredient has its own encyclopedia page")
	# 2. how to proceed: one recommended step, with alternatives behind it
	var ns := Guide.next_step("recipe:iron_longsword")
	check(str(ns["text"]) != "" and not (ns["action"] as Dictionary).is_empty(), "2. one next step with an action: %s" % ns["text"])
	check(Guide.alternatives("recipe:iron_longsword").size() >= 2, "alternatives exist for the curious")
	var hide_src: Array = Guide.sources("leather_hide").map(func(s): return str(s["kind"]) + ":" + str(s["id"]))
	check(hide_src.has("vendor:general_store"), "raw hide can be bought at Pell's Provisions (%s)" % str(hide_src))
	check(Venues.is_open("general_store"), "Pell's is open at 9:00 (%s)" % Venues.status_text("general_store"))
	# 3. acquire through play — the long way, curing our own leather
	var g0 := Game.gold()
	eq(Trade.buy_store("general_store", "leather_hide", 2), "", "3. two raw hides bought at Pell's")
	check(Game.gold() < g0 and Game.count("leather_hide") == 2, "paid for and in the stores")
	eq(str(Guide.recipe_status("cure_leather")["state"]), "locked", "curing is locked: no vat yet")
	eq(Property.buy_station("leather_vat"), "", "a Leather Vat is bought")
	var plan := Property.plan_copy()
	eq(Property.auto_place(plan, "leather_vat"), "", "and set up in the workshop")
	eq(Property.commit(plan), "", "the layout is accepted")
	eq(str(Guide.recipe_status("cure_leather")["state"]), "ready", "curing is ready now")
	var cured := craft("cure_leather", 92.0)
	check(not cured.is_empty() and Game.count("leather_cured") >= 1, "the hides are cured into leather")
	eq(str(Guide.recipe_status("iron_longsword")["state"]), "ready", "the longsword is ready")
	# 4. forge it
	var sword := craft("iron_longsword", 98.0, {"edge": 12, "temper": 12, "fortune": 20})
	if not check(not sword.is_empty(), "4. the Iron Longsword is forged"):
		return
	var uid := int(sword["uid"])
	var name0 := Items.display_name(sword)
	var q0 := float(sword["quality"])
	var events0 := Lore.of_item(uid).size()
	# 5. refine it at the grinding wheel (salt as grit, the real check passed as a fixed score)
	give("reagent_salt", 2)
	var p := Refinement.plan(sword, "refine", {"station": "grinding_wheel"})
	check(bool(p.get("ok", false)), "5. the refinement can begin: %s" % str(p.get("why", "")))
	var r := Refinement.perform(uid, "refine", 104.0, {"station": "grinding_wheel"})
	check(bool(r.get("ok", false)), "refined: %s" % str(r.get("text", r)))
	var w := Game.find_uid(uid)
	if not check(not w.is_empty(), "the same piece is still in the stores"):
		return
	check(float(w["quality"]) > q0, "craftsmanship rose (%.0f%% → %.0f%%)" % [q0, float(w["quality"])])
	# 6. identity and history
	eq(int(w["uid"]), uid, "6. same uid")
	eq(str(Provenance.maker(w).get("id", "")), Provenance.SMITH_ID, "same maker")
	eq(str(Provenance.mark(w).get("name", "")), "the Ironhand mark", "same mark")
	eq(Items.display_name(w), name0, "same name")
	var kinds: Array = Lore.of_item(uid).map(func(e): return str(e["kind"]))
	eq(Lore.of_item(uid).size(), events0 + 1, "exactly one new history event")
	check(kinds.has("forged") and kinds.has("refined"), "the history keeps the forging and adds the refinement (%s)" % str(kinds))
	var ev: Dictionary = Lore.of_item(uid).filter(func(e): return str(e["kind"]) == "refined")[0]
	check(not (ev.get("data", {}) as Dictionary).is_empty(), "the refinement records materials, outcome and changes")
	# 7. reload
	if not check(save_load("suite_ux_journey"), "7. save and load"):
		return
	w = Game.find_uid(uid)
	check(not w.is_empty() and Lore.of_item(uid).size() == events0 + 1 and float(w["quality"]) > q0, "the refined piece and its history persist")
	check(Property.is_installed("leather_vat"), "the vat stays in the workshop")
