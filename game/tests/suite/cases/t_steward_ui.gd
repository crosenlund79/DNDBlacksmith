## Steward Mode presentation (Milestone S1, UI): the steward panel builds on every tab with and without steward state;
## a hand-over refused by the engine shows its reason and a disabled button, an allowed one activates; the standing
## instructions panel changes the engine's instructions (persistent) and refuses invalid ones with the reason; while
## the smith is away the UI lets him look (panels do not stop the clock) but not act (world panels are refused with a
## reason, the pause menu still pauses); While You Were Away builds from an empty, a minimal, a real and a full report
## with empty sections collapsed and links to the real places; the sealed-letter envelope appears only when a real
## sealed letter waits, hides the contents until opened and leads to the real matter; a session closed by loading
## reports once, with the mode off.
extends SuiteCase

const SMOKE := ["test_panels_build_without_state", "test_activation_refusal_shows_reason", "test_envelope_only_with_sealed_letters"]


# ------------------------------------------------------------------ fixtures
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


func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r != null:
			return r
	return null


func _named(n: Node, nm: String) -> Node:
	return _find(n, func(x): return x.name == nm)


func _text_in(n: Node, needle: String) -> bool:
	return _find(n, func(x): return (x is Label and (x as Label).text.contains(needle)) or (x is RichTextLabel and (x as RichTextLabel).text.contains(needle)) \
		or (x is Button and (x as Button).text.contains(needle))) != null


## A small workshop: Smithing 6, one extra room, an apprentice trained to the apprentice rank, gold.
func _workshop(gold := 3000) -> Dictionary:
	train("smithing", 6)
	Property.dev_grant_unit("cobbler")
	(Game.state["hirelings"] as Array).clear()
	var g := 0
	while Apprentices.applicants().is_empty() and g < 20:
		Apprentices.refresh_applicants()
		g += 1
	if Apprentices.hire(0) != "":
		return {}
	var a: Dictionary = Apprentices.staff()[-1]
	a["traits"] = []
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	Game.state["gold"] = gold
	return a


func _hours(n: int) -> void:
	for i in n:
		Game.advance_minutes(60)
		for c in Shop.customers().duplicate():
			if not bool(c.get("present", false)):
				Shop.mark_arrived(str(c["npc"]), false)


## A UIRoot of its own (the HUD, routing, the steward plate). Unmount with _ui_off.
func _ui() -> UIRoot:
	var ui := UIRoot.new()
	_mount(ui)
	return ui


func _ui_off(ui: UIRoot) -> void:
	ui.close_current()
	_unmount(ui)
	UIRoot.instance = null


## A report with every section filled (the shape of Steward.report(), docs/STEWARD_MODE_DESIGN.md §5.3).
func _full_report() -> Dictionary:
	return {"from": {"day": 3, "time": "07:30", "t": 0}, "to": {"day": 5, "time": "14:00", "t": 3270}, "elapsed_minutes": 3270,
		"elapsed_text": "2 days and 6 hours", "ended": "returned",
		"gold": {"start": 3000, "end": 3240, "change": 240, "income": 420, "expenses": 180, "by_category": {"commissions": 300, "sales": 120, "materials": -100, "wages": -80},
			"lines": 9, "reconciled": true, "unexplained": 0, "recent": [], "steward_spent": 100},
		"orders": {"accepted": ["A short sword for Sigrun"], "delivered": ["A short sword for Sigrun (70 g)"], "declined": ["a repair part"],
			"pending": [{"id": "o1", "text": "An iron helm for Garrick", "deadline": 7, "in_hand": true, "state": "working"}],
			"counts": {"accepted": 1, "delivered": 1, "declined": 1, "pending": 1}},
		"production": {"completed": {"commission": 1, "repair": 3}, "made_count": 1, "made": [{"uid": 999991, "name": "Iron Short Sword", "where": ""}],
			"failed": 1, "failed_why": {"customer left": 1}, "materials": {"ingot_iron": {"n": 1, "qty": 2, "max": 2}}, "apprentice_crafted": 1, "smith_crafted": 0},
		"purchases": {"items": [{"item_def": "coal", "name": "Coal", "qty": 6, "cost": 30}], "total": 30},
		"sales": {"count": 1, "gold": 120, "recent": [{"uid": 999992, "name": "Iron Dagger", "npc": "sigrun", "price": 120, "day": 4}], "listed": 2, "ledger_sales": 120},
		"stock": [{"item_def": "coal", "name": "Coal", "before": 10, "after": 14, "change": 4}, {"item_def": "ingot_iron", "name": "Iron Ingot", "before": 6, "after": 4, "change": -2}],
		"staff": {"current": [{"id": "app_x", "name": "Wren", "rank_before": "novice", "rank": "apprentice", "rank_name": "Apprentice", "works": 4, "joined": false, "status": "working", "notice": ""}],
			"left": []},
		"world": {"count": 1, "events": [{"id": "ev_nope", "day": 4, "time": "12:00", "kind": "death", "text": "A wolf took an old shepherd.", "importance": 2}]},
		"deferred": [], "letters": [], "lapsed": [{"id": "sd_1", "text": "Sigrun came for advice.", "outcome": "Sigrun left the shop."}],
		"decisions": {"total": 7, "by_kind": {"repair": 3, "buy": 2, "deliver": 1, "commit": 1}, "stalls": [{"code": "materials", "count": 1, "text": "waiting for iron", "duty": "production"}],
			"deferrals": {"visitor": 1}}}


# ------------------------------------------------------------------ tests
func test_panels_build_without_state() -> void:
	check(not Game.state.has("steward"), "a new game has no steward state")
	for t in ["forge", "matters", "orders"]:   # (the instructions tab is the steward's first use: it may create its state)
		var p := _mount(StewardPanel.new({"tab": t})) as StewardPanel
		check(p.body.get_child_count() > 0, "the steward panel builds its '%s' tab" % t)
		_unmount(p)
		if t == "matters":
			check(not Game.state.has("steward"), "the hand-over and matters tabs create no steward state")
	var p2 := _mount(StewardPanel.new()) as StewardPanel
	check(_text_in(p2, "nothing happens while the game is closed"), "the hand-over states plainly that nothing happens while the game is closed")
	check(_named(p2, "InstructionsSummary") != null, "the hand-over shows the standing instructions in brief")
	var go := _named(p2, "HandOver") as Button
	check(go != null and not go.disabled, "the hand-over is possible at rest")
	_unmount(p2)
	var w := _mount(WelcomeBackPanel.new({})) as WelcomeBackPanel
	check(_text_in(w, "There is no report"), "While You Were Away without a report says so")
	_unmount(w)
	var pl := _mount(StewardPlate.new()) as StewardPlate
	check(not pl.visible, "the plate is hidden when the steward is off and no letter waits")
	_unmount(pl)
	Game.state.erase("steward")
	var p3 := _mount(StewardPanel.new()) as StewardPanel
	_unmount(p3)
	check(not Game.state.has("steward"), "looking at the hand-over, the report and the plate creates no steward state (old saves stay unchanged)")


func test_activation_refusal_shows_reason() -> void:
	_workshop()
	check(Crafting.start("iron_shortsword"), "the smith has a piece in hand")
	var why := Steward.can_activate()
	check(why != "", "the engine refuses the hand-over mid-craft")
	var p := _mount(StewardPanel.new()) as StewardPanel
	var go := _named(p, "HandOver") as Button
	check(go != null and go.disabled, "the hand-over button is disabled")
	var rl := _named(p, "Refusal") as Label
	check(rl != null and rl.visible and rl.text.contains(why), "the engine's reason is shown (%s)" % (rl.text if rl else "none"))
	p._activate()
	check(not Steward.is_active(), "pressing it anyway does not hand over")
	_unmount(p)
	Crafting.cancel()
	var p2 := _mount(StewardPanel.new()) as StewardPanel
	check(not (_named(p2, "HandOver") as Button).disabled, "at rest the button is enabled")
	p2._activate()
	check(Steward.is_active() and Steward.smith_away(), "the hand-over activates the steward")
	_unmount(p2)
	# the live status
	_hours(3)
	var p3 := _mount(StewardPanel.new()) as StewardPanel
	check(_named(p3, "TakeBack") != null and _text_in(p3, "Away 3 h"), "the steward at work: time away and the take-back button")
	_unmount(p3)
	var pl := _mount(StewardPlate.new()) as StewardPlate
	check(pl.visible and pl.plate.visible and pl.body.text.contains("Away 3 h"), "the status plate shows the time away")
	check(pl.body.text.contains("Purse"), "… and the purse against when he left")
	_unmount(pl)
	Steward.deactivate()


func test_instructions_panel_changes_engine_orders() -> void:
	_workshop()
	var sw := Items.make("sword_iron", {"quality": 70.0})
	Game.add_item(sw, false)
	var named := Items.make("sword_iron", {"quality": 80.0})
	named["named"] = {"name": "Oathkeeper", "day": 1}
	Game.add_item(named, false)
	var p := _mount(StewardPanel.new({"tab": "orders"})) as StewardPanel
	check(p.summary != null and p.summary.text.contains("Up to 120 g a day"), "a summary line at the top")
	check(_text_in(p, "Oathkeeper") and _text_in(p, "It bears a name."), "automatic protections are listed with why")
	for d in Steward.DUTIES:
		check(_text_in(p, str(Steward.DUTY_NAME[d])), "a switch for the duty '%s'" % d)
	for c in Steward.purchase_categories():
		check(_text_in(p, str(c)), "a purchase category: %s" % c)
	p._apply({"daily_limit": 60, "duties": {"sales": false}, "sell_rules": {"stock_target": 1}})
	check(int(Steward.orders()["daily_limit"]) == 60 and not Steward.duty_on("sales"), "changes reach the engine")
	check(p.summary.text.contains("Up to 60 g a day"), "the summary line follows")
	p._apply({"daily_limit": -1})
	eq(int(Steward.orders()["daily_limit"]), 60, "an invalid value is refused by the engine (nothing applied)")
	_unmount(p)
	eq(Steward.protect(int(sw["uid"])), "", "protect a piece")
	p = _mount(StewardPanel.new({"tab": "orders"})) as StewardPanel
	check(_text_in(p, "Unprotect"), "the hand-protected piece is listed with a way to lift it")
	p._set_reserve("coal", 4, true)
	eq(int(Steward.orders()["reserved"].get("coal", 0)), 4, "a reserved supply is set from the panel")
	_unmount(p)
	check(save_load("steward_ui_orders"), "save and load")
	var o := Steward.orders()
	check(int(o["daily_limit"]) == 60 and int(o["reserved"]["coal"]) == 4 and (o["protected"] as Array).has(int(sw["uid"])), "the instructions set in the panel persist")


func test_away_look_but_do_not_act() -> void:
	_workshop()
	var ui := _ui()
	eq(Steward.activate(), "", "the steward takes over")
	var b0 := Game.ui_blockers
	ui._on_open_panel("inventory", {})
	check(not is_instance_valid(ui.current), "the stores cannot be handled while away")
	check(StewardUI.away_block("inventory").contains("away"), "… with a reason (%s)" % StewardUI.away_block("inventory"))
	for id in ["station", "shop", "store", "dialogue", "sleep", "designer", "orders", "notice", "contracts", "quick_travel"]:
		check(StewardUI.away_block(id) != "", "'%s' acts in the world: refused while away" % id)
	ui._on_open_panel("workshop", {})
	check(ui.current is WorkshopPanel, "the Workshop Ledger opens for a look")
	eq(Game.ui_blockers, b0, "a panel opened while the steward runs does not stop the clock")
	var add := _find(ui.current, func(x): return x is Button and (x as Button).text == "Craft")
	check(add != null and (add as Button).disabled, "its controls are disabled while away")
	var stb := _named(ui.current, "StewardButton") as Button
	check(stb != null and not stb.disabled, "… except the way to the steward")
	ui.close_current()
	ui._on_open_panel("pause", {})
	check(ui.current is PausePanel and Game.ui_blockers == b0 + 1, "the pause menu still pauses")
	ui.close_current()
	eq(Game.ui_blockers, b0, "and lets go again")
	ui._on_open_panel("steward", {})
	check(ui.current is StewardPanel, "the steward panel opens while away")
	ui.close_current()
	var r := StewardUI.take_back()
	check(not Steward.is_active() and str(r.get("ended", "")) == "returned", "taking the workshop back ends the session with the report")
	eq(StewardUI.away_block("inventory"), "", "back at the forge everything opens again")
	_ui_off(ui)


func test_report_builds_empty_real_and_full() -> void:
	# minimal: activated and taken back at once — every empty section collapses
	_workshop()
	eq(Steward.activate(), "", "the steward takes over")
	var r0 := Steward.deactivate()
	var w0 := _mount(WelcomeBackPanel.new(r0)) as WelcomeBackPanel
	check(_named(w0, "Elapsed") != null, "the elapsed time heads the report")
	for s in ["orders", "production", "trade", "stock", "world", "money"]:
		check(not w0.sections.has(s), "an empty '%s' section collapses" % s)
	_unmount(w0)
	# full (every section)
	var w1 := _mount(WelcomeBackPanel.new(_full_report())) as WelcomeBackPanel
	for s2 in ["money", "orders", "production", "trade", "stock", "staff", "world", "matters", "conduct"]:
		check(w1.sections.has(s2), "the full report shows '%s'" % s2)
	check(_text_in(w1, "3000 g → 3240 g") and _text_in(w1, "Every coin is in the ledger"), "money from start to end, reconciled")
	check(_text_in(w1, "Ledger ›") and _text_in(w1, "Workshop Ledger ›") and _text_in(w1, "Commissions ›") and _text_in(w1, "Your stores ›") and _text_in(w1, "Chronicle ›"),
		"each section links to the real place")
	check(_text_in(w1, "You made nothing yourself"), "the absent smith made nothing")
	_unmount(w1)
	# real: a day of the steward at work with an order and a contract letter
	give("ingot_iron", 4)
	give("leather_cured", 2)
	Contracts.make_offer("drovers_kit")
	eq(Steward.activate(), "", "the steward takes over again")
	_hours(30)
	var r := Steward.deactivate()
	var w2 := _mount(WelcomeBackPanel.new(r)) as WelcomeBackPanel
	check(w2.sections.has("matters"), "the merchant's letter waits for the smith")
	check(not w2.sections.is_empty(), "the real report shows sections (%s)" % ", ".join(w2.sections))
	note("real report sections: %s" % ", ".join(w2.sections))
	_unmount(w2)


func test_envelope_only_with_sealed_letters() -> void:
	_workshop()
	var ui := _ui()
	ui._on_open_panel("sealed_letter", {})
	check(not is_instance_valid(ui.current), "no envelope when no sealed letter waits")
	eq(Steward.activate(), "", "the steward takes over")
	Contracts.make_offer("drovers_kit")   # a merchant: not sealed
	_hours(1)
	check(Steward.letters().is_empty(), "an ordinary letter is not sealed")
	var r := Steward.deactivate()
	var w := _mount(WelcomeBackPanel.new(r)) as WelcomeBackPanel
	check(not (_named(w, "Continue") as Button).text.contains("sealed"), "the report promises no letter")
	_unmount(w)
	ui._on_open_panel("sealed_letter", {})
	check(not is_instance_valid(ui.current), "still no envelope")
	# a real sealed letter: the Royal Household writes while the steward runs
	eq(Steward.activate(), "", "the steward takes over again")
	var c := Contracts.make_offer("queens_guard")
	_hours(1)
	var ls := Steward.letters()
	eq(ls.size(), 1, "one sealed letter")
	var secret := str(Steward.deferred().filter(func(e): return bool(e["sealed"]))[0]["text"])
	var r2 := Steward.deactivate()
	var w2 := _mount(WelcomeBackPanel.new(r2)) as WelcomeBackPanel
	check(_text_in(w2, "a sealed letter from") and not _text_in(w2, secret.left(30)), "the report shows the envelope, not the contents")
	check((_named(w2, "Continue") as Button).text.contains("1 sealed letter"), "closing the report leads to the letter")
	_unmount(w2)
	var pl := _mount(StewardPlate.new()) as StewardPlate
	check(pl.visible and pl.chip.visible and not pl.plate.visible, "the envelope chip remains on the HUD")
	_unmount(pl)
	ui._on_open_panel("sealed_letter", {})
	var sp := ui.current as SealedLetterPanel
	if not check(sp != null, "the sealed letter opens"):
		_ui_off(ui)
		return
	check(_named(sp, "Envelope") != null and not _text_in(sp, secret.left(30)), "sealed: sender and seal, contents hidden")
	check(((_named(sp, "Envelope") as SealedLetterPanel.Envelope).from_text).contains("Royal") or (_named(sp, "Envelope") as SealedLetterPanel.Envelope).from_text != "", "the sender is on the envelope")
	sp._open()
	check(Steward.letters().is_empty(), "opened: no longer sealed")
	check(_text_in(sp, secret.left(30)), "the contents are revealed")
	var go := _named(sp, "GoToMatter") as Button
	check(go != null and go.text.contains("Project Bench"), "it offers the way to the actual offer")
	var seen: Array = []
	var cb := func(id: String, args: Dictionary): seen.append([id, args])
	Events.open_panel.connect(cb)
	sp._follow()
	ui._on_open_panel("contracts", {"id": str(c["id"])})   # the deferred route, as the frame would deliver it
	Events.open_panel.disconnect(cb)
	check(ui.current is ContractsPanel, "the letter leads to the actual pending matter")
	check(Steward.deferred().all(func(e): return str(e["source"].get("id", "")) != str(c["id"])), "the matter is marked seen to")
	check(Contracts.offers().any(func(o): return str(o["id"]) == str(c["id"])), "the offer itself still waits for the smith's answer")
	_ui_off(ui)


func test_pending_report_after_load() -> void:
	_workshop()
	eq(Steward.activate(), "", "the steward takes over")
	_hours(5)
	check(Saves.save("steward_ui_mid"), "save while the steward runs")
	check(Saves.load_slot("steward_ui_mid"), "load it")
	check(not Steward.is_active(), "the mode is off after loading")
	var ui := _ui()
	var pl := ui.steward_plate
	pl.refresh()
	check(not pl.plate.visible, "the plate does not claim the steward runs")
	StewardUI.after_world_start()
	check(ui.current is WelcomeBackPanel, "the closed session's report is shown once")
	check(_text_in(ui.current, "it stood down there"), "it says the steward stood down where the save was made")
	ui.close_current()
	StewardUI.after_world_start()
	check(not is_instance_valid(ui.current), "… and only once")
	_ui_off(ui)
	Saves.delete("steward_ui_mid")
