## S2 "The Living Smithy" — §5 early-game tutorials, controls and progression (EARLY worker).
## Borin waits in the smithy for his first talk, then keeps his own schedule; the dagger's real prerequisites (no Design
## makes one) and an honest guide line; Mira Pell's opening commission completes the guide even with an empty purse —
## her share is what she has, the recorded village subsidy pays the rest, nothing is conjured and she still cannot buy
## what she cannot afford; a lapsed commission (or Borin gone) never freezes the opening; the K/U/Y/Q keys, the toolbar
## labels, Help and the tutorial agree; the selling step ignores background income (BUG-050, the ledger's payer); the
## auto-walk is off by default and, when on, only walks; every tutorial stage completes on a fresh save.
extends SuiteCase

const SMOKE := ["test_keys_match_labels_and_help", "test_selling_step_ignores_background_income"]


func _reset_overrides() -> void:
	Tutorial.serving_override = null
	Tutorial.served_override = ""


func _to_hour(h: int, m := 0) -> void:
	var cur := int(Game.state["minute"]) % 1440
	Game.advance_minutes((h * 60 + m - cur + 1440) % 1440)


func _ledger_since(n: int) -> Array:
	return (Game.state["ledger"] as Array).slice(n)


# ------------------------------------------------------------------ 1. Borin
func test_borin_starts_in_smithy_then_resumes() -> void:
	var b := Hire.get_h("borin")
	eq(Game.time_string(), "07:30", "a new game starts at 07:30")
	eq(Hire.tutorial_spot(b), Hire.TUTORIAL_SPOT, "before his shift Borin is already waiting in the smithy")
	eq(Hire.hud_status(b), "working", "his card says he is at work there, not resting")
	var sp: Array = DB.building("smithy").get("spots", {}).get(Hire.TUTORIAL_SPOT, [])
	check(sp.size() == 2, "his spot exists in the smithy's layout")
	if sp.size() == 2:
		var room := Property.room_at_tile(Property.rooms(), Vector2(float(sp[0]), float(sp[1])))
		check(not room.is_empty() and Property.room_owned(room), "that spot is inside a room the new smith owns (%s)" % str(room.get("id", "?")))
	_to_hour(17)
	eq(Hire.tutorial_spot(b), Hire.TUTORIAL_SPOT, "through his first working day he waits there for the talk")
	_to_hour(19)
	eq(Hire.tutorial_spot(b), "", "the evening is his own (the inn), talk or no talk")
	fresh_game()
	b = Hire.get_h("borin")
	Talk.choose("borin", "talk", "smithy")
	check(Objectives.is_done("talk_borin"), "talking to him completes the first objective")
	eq(Hire.tutorial_spot(b), "work_" + Hire.top_alloc(b), "talked to before 8:00, he stays at his own work instead of leaving")
	_to_hour(8, 30)
	eq(Hire.tutorial_spot(b), "", "from his shift on, his ordinary schedule applies")
	fresh_game()
	b = Hire.get_h("borin")
	eq(Hire.send("borin", "ironroot_mine"), "", "he can be sent out without the talk")
	eq(Hire.tutorial_spot(b), "", "away on an expedition: no hold")
	fresh_game()
	b = Hire.get_h("borin")
	days(1)
	eq(Hire.tutorial_spot(b), "", "from day 2 (or an old save) the hold never applies")
	check(save_load("t_s2e_borin"), "save/load")
	eq(Hire.tutorial_spot(Hire.get_h("borin")), "", "still none after loading")


# ------------------------------------------------------------------ 2. the dagger
func test_dagger_prerequisites() -> void:
	var makers := DB.recipes.values().filter(func(r): return str(r.get("output", "")) == "dagger")
	eq(makers.size(), 0, "no Design (known, locked or secret) makes a Dagger: it cannot be forged at any level")
	check(not DB.item("dagger").is_empty(), "the Dagger exists as an item (starter stock, adventurers' kit, loot, pawnbroker)")
	var starter := Game.inventory().filter(func(it): return str(it.get("def", "")) == "dagger")
	check(starter.size() == 1 and bool(starter[0].get("for_sale", false)), "a new game starts with one dagger on display")
	check(Guide.no_design("dagger") != "", "the guide says so plainly")
	eq(Guide.no_design("sword_iron"), "", "a piece some Design makes is not reported as unmakeable")
	Game.take_uid(int(starter[0]["uid"]))
	var how := str(Guide.how_to_get("dagger").get("text", ""))
	check(how.begins_with("No Design makes"), "how to get one: '%s' (not 'listen for rumours')" % how)
	# the nearest blades are open from the start — nothing advanced is unlocked early
	for rid in ["iron_shortsword", "iron_longsword"]:
		eq(craft_blocker(rid), "", "%s needs nothing more on a new game" % rid)
	check(Crafting.recipe_locked_reason("steel_shortsword").contains("Steelworking"), "steel blades stay behind «Steelworking»")
	note("dagger: no recipe; iron shortsword/longsword: no prerequisites (forge, anvil, grinding wheel / + quench trough)")


# ------------------------------------------------------------------ 3. Mira's opening commission with an empty purse
func test_mira_empty_purse_completes_without_conjured_money() -> void:
	Tutorial.wire()
	Tutorial.restart()
	for id in ["move", "interact", "craft", "dice"]:
		Tutorial.complete(id)
	for id in ["talk_borin", "send_borin", "select_recipe", "craft_sword"]:
		Objectives.complete(id)
	check(Objectives.text().contains("15:00"), "before Aldric comes the objective says when he will: " + Objectives.text())
	_to_hour(15, 30)
	var o := Objectives.mira_order()
	check(not o.is_empty(), "Aldric's commission for Mira is open")
	if o.is_empty():
		return
	check(Objectives.text().contains("Deliver Mira's commission"), "the objective now says how: " + Objectives.text())
	var mira := Adv.get_a("mira")
	mira["gold"] = 0
	var sword := craft("iron_longsword", 92.0)
	check(not sword.is_empty() and Shop.item_meets(o, sword), "a well-made iron longsword meets her commission (attack %d ≥ %d)" % [Items.stat(sword, "attack"), int(o["min"])])
	if sword.is_empty():
		return
	# the economy is untouched: she cannot buy what she cannot afford
	sword["for_sale"] = true
	var refusal := Shop.sell_to("mira", int(sword["uid"]))
	check(refusal.contains("can't afford"), "an over-the-counter sale is still refused: " + refusal)
	check(not Objectives.is_done("serve_mira") and not Tutorial.is_done("customer"), "a refused sale completes nothing")
	# the smith delivers the commission in person (the Commissions board open)
	var g0 := Game.gold()
	var l0 := (Game.state["ledger"] as Array).size()
	Tutorial.serving_override = true
	Tutorial.served_override = "mira"
	var err := Shop.fulfil(str(o["id"]), int(sword["uid"]))
	_reset_overrides()
	eq(err, "", "the commission is delivered")
	check(Objectives.is_done("serve_mira") and not Objectives.was_missed("serve_mira"), "the opening objective is done (served, not missed)")
	check(Tutorial.is_done("customer"), "the selling step is done — serving her counts even though the subsidy paid")
	eq(int(Adv.get_a("mira")["gold"]), 0, "her purse stays at 0 (never negative)")
	var lines := _ledger_since(l0)
	var rec: Dictionary = o.get("paid", {})
	var paid := lines.filter(func(l): return str(l.get("party", "")) == "mira")
	var sub := lines.filter(func(l): return str(l.get("cat", "")) == "subsidy" and str(l.get("party", "")) == Payments.VILLAGE)
	eq(paid.size(), 0, "no coin in her name")
	eq(int(rec.get("gold", -1)), 0, "the order records her share as 0")
	check(sub.size() == 1 and int(sub[0]["amount"]) == int(rec.get("subsidy", -1)) and int(rec.get("subsidy", 0)) > 0,
		"one recorded village-subsidy line pays the whole reward (%s)" % str(sub))
	eq(Game.gold() - g0, int(rec.get("subsidy", -1)), "the smith received exactly the recorded subsidy — nothing else")
	check(Payments.unaccounted().is_empty(), "every ledger line names its payer")
	check(save_load("t_s2e_mira"), "save/load")
	check(Objectives.is_done("serve_mira") and Tutorial.is_done("customer"), "both survive save/load")


func test_mira_with_coin_pays_her_share() -> void:
	_to_hour(15, 30)
	var o := Objectives.mira_order()
	var sword := craft("iron_longsword", 92.0)
	if o.is_empty() or sword.is_empty():
		check(false, "setup")
		return
	var mira := Adv.get_a("mira")
	var purse := int(mira["gold"])
	var g0 := Game.gold()
	eq(Shop.fulfil(str(o["id"]), int(sword["uid"])), "", "delivered")
	var rec: Dictionary = o.get("paid", {})
	var total := int(rec.get("gold", 0)) + int(rec.get("subsidy", 0))
	eq(purse - int(mira["gold"]), mini(purse, int(total / 2.0)), "she paid her half from her purse (%d g of %d g)" % [purse - int(mira["gold"]), purse])
	eq(Game.gold() - g0, total, "the smith's total is her share plus the recorded subsidy")


# ------------------------------------------------------------------ 4. nothing in the opening waits for ever
func test_lapsed_commission_and_gone_borin_never_freeze_the_guide() -> void:
	Tutorial.wire()   # what the HUD does: the objectives listen to the clock and the orders
	for id in ["talk_borin", "send_borin", "select_recipe", "craft_sword"]:
		Objectives.complete(id)
	eq(str(Game.state["objectives"]["current"]), "serve_mira", "serving Mira is the current objective")
	days(4)   # her commission (deadline day 3) lapses unserved
	check(Objectives.is_done("serve_mira") and Objectives.was_missed("serve_mira"), "the lapsed commission closes the objective as missed")
	check(str(Game.state["objectives"]["current"]) != "serve_mira", "the guide moved on to: " + Objectives.text())
	check(save_load("t_s2e_lapse"), "save/load")
	check(Objectives.was_missed("serve_mira"), "the missed mark survives save/load")
	# Borin dies on his first trip: nobody to talk to and no bag of his
	fresh_game()
	var b := Hire.get_h("borin")
	Hire.force_outcome = "death"
	eq(Hire.send("borin", "ironroot_mine"), "", "sent")
	var guard := 0
	while str(b.get("status", "")) == "away" and guard < 8:
		days(1)
		guard += 1
	eq(str(b["status"]), "dead", "(forced) he did not come back")
	Objectives.check()
	check(Objectives.is_done("talk_borin") and Objectives.is_done("open_bag"), "his steps close instead of waiting for ever")


# ------------------------------------------------------------------ 5. keys, labels, Help and tutorial agree
func test_keys_match_labels_and_help() -> void:
	# hotkeys handled outside HOTKEY_PANELS (UIRoot._unhandled_input)
	var special := {"panel_ledger": "shop", "panel_map": "map", "panel_help": "help", "panel_wanted": "wanted"}
	for b in HudToolbar.BUTTONS:
		var action := str(b[3])
		if action == "":
			continue
		var opens := UIRoot.panel_for_action(action) if not special.has(action) else str(special[action])
		eq(opens, str(b[4]), "the %s button's key %s opens what the button opens" % [b[1], Settings.key_label(action)])
		var r: Array = HudToolbar.RIGHT.get(str(b[6]), [])
		if r.size() > 1:
			var ra := str(r[1])
			var ropens := UIRoot.panel_for_action(ra) if not special.has(ra) else str(special[ra])
			eq(ropens, str(b[6]), "the %s button's right-click key %s opens its right-click panel" % [b[1], Settings.key_label(ra)])
	eq(Settings.key_label("panel_skills"), "K", "K = the Skill Tree")
	eq(UIRoot.panel_for_action("panel_skills"), "skilltree", "K opens the Skill Tree")
	eq(Settings.key_label("panel_skill_levels"), "U", "U = skill levels")
	eq(UIRoot.panel_for_action("panel_skill_levels"), "skills", "U opens the skill levels")
	eq(Settings.key_label("panel_property"), "Y", "Y = the toolbar's Workshop")
	eq(UIRoot.panel_for_action("panel_property"), "property", "Y opens Property & Workshop — what the Workshop button opens")
	var ws: Array = HudToolbar.BUTTONS.filter(func(x): return str(x[0]) == "property")
	check(ws.size() == 1 and str(ws[0][1]) == "Workshop" and str(ws[0][3]) == "panel_property", "the Workshop button carries Y")
	eq(UIRoot.panel_for_action("panel_workshop"), "workshop", "the Workshop Ledger keeps its own key (%s)" % Settings.key_label("panel_workshop"))
	# every key is bound once
	var seen := {}
	for action in Settings.DEFAULT_KEYS:
		for k in Settings.DEFAULT_KEYS[action]:
			check(not seen.has(k), "key %s is bound once (%s, %s)" % [Settings.key_name(int(k)), str(seen.get(k, "")), action])
			seen[k] = action
	# Help lists every shortcut with the real key
	for h in Settings.HOTKEY_HELP:
		check(Settings.DEFAULT_KEYS.has(str(h[0])), "Help names a real action: " + str(h[0]))
	for action in Settings.DEFAULT_KEYS:
		if str(action).begins_with("move_") or action == "dev_panel":
			continue
		check(Settings.HOTKEY_HELP.any(func(h): return str(h[0]) == action), "Help lists %s" % action)
	var help := ""
	for e in Reference.tab_entries("basics"):
		if str(e.get("title", "")) == "The toolbar and hotkeys":
			help = str(e["body"])
	for pair in [["K", "Skill Tree"], ["U", "Skill levels"], ["Y", "Workshop (rooms"], ["Q", "Workshop Ledger"], ["G", "World map"]]:
		check(help.contains("[b]%s[/b] %s" % pair), "Help: %s → %s" % pair)
	# the tutorial names the real keys, and the step that says "Workshop" completes on what Y opens
	for s in Tutorial.STEPS:
		check(not Tutorial.step_text(s).contains("{"), "tutorial step %s has every key filled in" % s["id"])
	var sk := Tutorial.step_text(Tutorial.STEPS[Tutorial.index_of("skills")])
	check(sk.contains("Skill Tree with K") and sk.contains("U (or a right-click"), "the skills step: " + sk)
	var pr: Dictionary = Tutorial.STEPS[Tutorial.index_of("progress")]
	check(Tutorial.step_text(pr).contains("Workshop (Y)") and (pr["on"] as Array).has("panel:" + UIRoot.panel_for_action("panel_property")), "the progress step names Y and completes on it")
	for o in Objectives.ORDER:
		check(not Objectives._keys(str(o[1])).contains("{"), "objective %s has every key filled in" % o[0])


# ------------------------------------------------------------------ 6. BUG-050: the selling step ignores background income
func test_selling_step_ignores_background_income() -> void:
	Tutorial.restart()
	for id in ["move", "interact", "craft", "dice"]:
		Tutorial.complete(id)
	Shop.customers().clear()
	# a counter-class panel is open (a conversation with Pip): before S2 Borin's hourly sale ticked the step here
	Tutorial.serving_override = true
	Tutorial.served_override = "pip"
	var borin := Hire.get_h("borin")
	borin["alloc"] = {"smithing": 100}
	Game.remove_def("ore_iron", Game.count("ore_iron"))
	_to_hour(10)
	var g0 := Game.gold()
	for i in 8:
		Hire.work_hour(10)
		Tutorial._on_gold(Game.gold())
	check(Game.gold() > g0, "Borin sold horseshoes (%d g, payer 'market')" % (Game.gold() - g0))
	check(not Tutorial.is_done("customer"), "his sale does not complete the selling step while a counter panel is open")
	# an adventurer buying a draught from the display by himself (not the one being served)
	Game.add_gold(30, "sales", "Varn bought a healing draught", "varn")
	Tutorial._on_gold(Game.gold())
	check(not Tutorial.is_done("customer"), "a purchase by someone the smith is not serving does not count")
	# the customer at the counter pays
	Shop._add_customer("pip", "browse")
	Shop.mark_arrived("pip", false)
	Game.add_gold(40, "sales", "Sold a hand axe to Pip", "pip")
	Tutorial._on_gold(Game.gold())
	_reset_overrides()
	check(Tutorial.is_done("customer"), "the customer seated at the counter paying completes it")


# ------------------------------------------------------------------ 7. auto-walk
func test_auto_walk_off_by_default_and_only_walks() -> void:
	var fresh: Node = load("res://scripts/autoload/settings.gd").new()
	eq(bool(fresh.get("values").get(Smithy.AUTO_WALK_KEY, true)), false, "the shipped default is off")
	fresh.free()
	var was: Variant = Settings.values.get(Smithy.AUTO_WALK_KEY, false)
	Settings.values[Smithy.AUTO_WALK_KEY] = false
	check(Crafting.start("iron_longsword"), "a longsword is begun")
	var st0 := Crafting.current_station()
	var n := int(Crafting.op_params().get("count", 1))
	var qs := []
	for i in n:
		qs.append(90.0)
	Crafting.record_step(st0, qs)
	var nxt := Crafting.current_station()
	check(nxt != st0, "the recipe continues at another station (%s → %s)" % [st0, nxt])
	eq(Smithy.auto_walk_target(st0), "", "setting off: no walk")
	Settings.values[Smithy.AUTO_WALK_KEY] = true
	eq(Smithy.auto_walk_target(st0), nxt, "setting on: the walk goes to the next station")
	eq(Smithy.auto_walk_target(nxt), "", "never when the next step is at the station just used")
	var step0 := int(Crafting.job()["step"])
	eq(Smithy.auto_walk_next(st0), "", "no world here: nothing happens (headless)")
	eq(int(Crafting.job()["step"]), step0, "walking starts no work")
	check(not Crafting.job().get("awaiting_dice", false), "and rolls no dice")
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false):
		var s := Crafting.current_station()
		var q2 := []
		for i in int(Crafting.op_params().get("count", 1)):
			q2.append(90.0)
		Crafting.record_step(s, q2)
	eq(Smithy.auto_walk_target(st0), "", "awaiting the dice: no walk (the dice panel is the player's)")
	Crafting.cancel()
	eq(Smithy.auto_walk_target(st0), "", "no work: no walk")
	Settings.values[Smithy.AUTO_WALK_KEY] = was


# ------------------------------------------------------------------ 8. the first hour, every stage, on a fresh save
func test_every_tutorial_stage_completes_on_fresh_save() -> void:
	Tutorial.wire()
	check(Tutorial.enabled() and str(Tutorial.current().get("id", "")) == "move", "a fresh game starts the tutorial at 'move'")
	eq(str(Game.state["objectives"]["current"]), "talk_borin", "and the objectives at Borin")
	eq(Hire.tutorial_spot(Hire.get_h("borin")), Hire.TUTORIAL_SPOT, "Borin is there to be talked to")
	Tutorial.on_moved(300.0)
	Events.open_panel.emit("dialogue", {"npc": "borin"})
	Talk.choose("borin", "talk", "smithy")
	check(Tutorial.is_done("move") and Tutorial.is_done("interact") and Objectives.is_done("talk_borin"), "move, interact, talk to Borin")
	Events.open_panel.emit(UIRoot.panel_for_action("panel_hirelings"), {})
	eq(Hire.send("borin", "ironroot_mine"), "", "send Borin to Ironroot Mine")
	check(Objectives.is_done("send_borin") and Tutorial.is_done("hirelings"), "send_borin and the hirelings step")
	# craft the longsword through every station (the check UI emits station_worked for each check)
	check(Crafting.start("iron_longsword"), "the longsword starts with the starting materials")
	check(Objectives.is_done("select_recipe"), "select_recipe")
	var guard := 0
	while Crafting.active() and not Crafting.job().get("awaiting_dice", false) and guard < 12:
		guard += 1
		var st := Crafting.current_station()
		var qs := []
		for i in int(Crafting.op_params().get("count", 1)):
			qs.append(92.0)
			Events.station_worked.emit(st, 92.0)
		Crafting.record_step(st, qs)
	var sword := Crafting.finish({"edge": 12, "temper": 12, "fortune": 50}, "digital")
	check(not sword.is_empty() and Tutorial.is_done("craft") and Tutorial.is_done("dice") and Objectives.is_done("craft_sword"), "craft, dice, craft_sword")
	# Aldric's commission at 15:00; delivered at the Commissions board
	_to_hour(15, 30)
	var o := Objectives.mira_order()
	check(not o.is_empty() and Shop.item_meets(o, sword), "Mira's commission is open and the sword meets it")
	if not o.is_empty():
		Tutorial.serving_override = true
		Tutorial.served_override = "mira"
		eq(Shop.fulfil(str(o["id"]), int(sword["uid"])), "", "delivered to Mira")
		_reset_overrides()
	check(Objectives.is_done("serve_mira") and Tutorial.is_done("customer"), "serve_mira and the selling step")
	Events.open_panel.emit(UIRoot.panel_for_action("panel_skills"), {})   # K
	Events.open_panel.emit(UIRoot.panel_for_action("panel_adventurers"), {})   # J
	Events.open_panel.emit(UIRoot.panel_for_action("panel_property"), {})   # Y
	check(Tutorial.is_done("skills") and Tutorial.is_done("adventurers") and Tutorial.is_done("progress"), "skills (K), adventurers (J), progress (Y)")
	check(Tutorial.current().is_empty() and not Tutorial.enabled(), "the tutorial card is complete and switches off")
	# the inn: an adventurer in town at the Tipsy Wyvern
	var adv := ""
	for a in Adv.in_town():
		adv = str(a["id"])
		break
	check(adv != "", "an adventurer is in town on day 1")
	if adv != "":
		Talk.choose(adv, "talk", "inn")
	check(Objectives.is_done("visit_inn"), "visit_inn")
	# departures (the world completes watch_depart when anyone sets out — Borin did) and Borin's bag
	Objectives.complete("watch_depart")   # VillageWorld._on_departed, verified in the rendered phase s2_early
	var guard2 := 0
	while str(Hire.get_h("borin").get("status", "")) == "away" and guard2 < 6:
		days(1)
		guard2 += 1
	var bag := {}
	for c in Game.state["returns"]:
		if str(c.get("from", "")).begins_with("Borin"):
			bag = c
	check(not bag.is_empty() or Objectives.is_done("open_bag"), "Borin came back with a bag (or the guide moved on)")
	eq(str(Game.state["objectives"]["current"]), "open_bag" if not bag.is_empty() else "save_game", "the guide points at his bag")
	if not bag.is_empty():
		var lp := LootPanel.new(int(bag["uid"]))
		lp._take()   # what "Take everything" does (it closes the panel: queue_free)
	check(Objectives.is_done("open_bag"), "open_bag")
	Objectives.complete("save_game")   # SavePanel / the quick-save key, verified in the rendered phase s2_early
	eq(str(Game.state["objectives"]["current"]), "", "every objective done — no stage was left waiting")
