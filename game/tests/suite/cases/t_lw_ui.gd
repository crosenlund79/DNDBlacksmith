## The Living Workshop — interface and information (the UI worker; playtest #38, #42–44, #46–47, #54–55).
## #43 the HUD's top-left plate takes the size of what it shows (a seven-digit purse in grouped digits, never cut) and
## the tutorial card sits under it; item-slot counts fit every slot size. #42 ten manual slots plus the autosave and
## quick-save: the same atomic write and .bak, older slot files untouched, a newer build's save refused and never
## overwritten, the Save/Load screens list every slot and fit the canvas. #44 the caravan's arrival: toast, journal
## line, HUD chip while it is camped. #38 health over time from recorded values only (the log and the expedition
## archive's fight records), "no record before day N" for an older save, capped, kept through save/load, drawn on the
## character sheet. #46 the material ledger: starting stores, purchases with their seller, crafting, use, a change
## that bypassed the hooks booked as "not itemised", an older save's stock shown as "before the record, origin unknown",
## the gold ledger untouched. #54–55 waiting customers, open commissions, commission opportunities and visiting
## adventurers told apart on the counter, the Commissions book, the roster, in conversation and in the world prompt.
## #47 the UIKit sizes (backward compatible) and the reworked panels fit the 1920×1080 canvas.
extends SuiteCase

const SMOKE := ["test_ten_save_slots", "test_material_ledger_sources"]
const CANVAS := Vector2(1920, 1080)


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


func _ui() -> UIRoot:
	var ui := UIRoot.new()
	_mount(ui)
	return ui


func _ui_off(ui: UIRoot) -> void:
	ui.close_current()
	_unmount(ui)
	UIRoot.instance = null


func _text_in(n: Node, needle: String) -> bool:
	for c in n.find_children("*", "Label", true, false):
		if (c as Label).text.contains(needle):
			return true
	for c in n.find_children("*", "RichTextLabel", true, false):
		if (c as RichTextLabel).get_parsed_text().contains(needle):
			return true
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).text.contains(needle):
			return true
	return false


## The size a window asks for (UIWindow's declared minimum, before content). Headless, a word-wrapping label keeps the
## one-character-per-line height it measured before its container gave it a width, so the laid-out size of panels
## with wrapped text is measured where it is real: in the rendered phase lw_ui (tests/playtest_lw_ui.gd, every panel
## at 1920×1080 and 1600×900). Panels without wrapped text are measured here as laid out.
func _declared(p: Control) -> Vector2:
	return p.custom_minimum_size


func _fits(p: Control, what: String, laid_out := false) -> void:
	var ms := p.get_combined_minimum_size() if laid_out else _declared(p)
	check(ms.x <= CANVAS.x and ms.y <= CANVAS.y, "%s fits the 1920×1080 canvas (%d×%d)" % [what, int(ms.x), int(ms.y)])


func _bytes(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _bak(slot: String) -> String:
	return Saves.path(slot).trim_suffix(".json") + ".bak"


# ------------------------------------------------------------------ #43 counters
func test_hud_counters_fit() -> void:
	eq(UIKit.num(1234567), "1,234,567", "grouped digits")
	eq(UIKit.num(-4200), "-4,200", "grouped negative")
	eq(UIKit.num(999), "999", "short numbers unchanged")
	var ui := _ui()
	Game.state["gold"] = 1234567
	ui._refresh_hud()
	ui._layout_left()
	eq(ui.gold_label.text, "1,234,567 gold", "the HUD shows the whole purse")
	var f := ui.gold_label.get_theme_font("font")
	var need := f.get_string_size(ui.gold_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.gold_label.get_theme_font_size("font_size")).x
	check(ui.gold_label.get_combined_minimum_size().x + 0.5 >= need, "the purse label asks for its whole text (%d ≥ %d)" % [int(ui.gold_label.get_combined_minimum_size().x), int(need)])
	check(ui.hud_plate.size.x + 0.5 >= ui.hud_plate.get_combined_minimum_size().x and ui.hud_plate.get_combined_minimum_size().x > need,
		"the plate holds it (%d ≥ %d)" % [int(ui.hud_plate.size.x), int(ui.hud_plate.get_combined_minimum_size().x)])
	check(ui.tutorial_card.position.y >= ui.hud_plate.position.y + ui.hud_plate.size.y, "the tutorial card sits below the plate")
	# a ten-digit purse still fits on the canvas
	Game.state["gold"] = 1234567890
	ui._refresh_hud()
	ui._layout_left()
	check(ui.hud_plate.position.x + ui.hud_plate.get_combined_minimum_size().x < CANVAS.x - 360.0, "a ten-digit purse keeps clear of the minimap")
	_ui_off(ui)
	# item-slot counts fit every slot size the game uses
	var fb := Assets.font("body_bold")
	for px in [44.0, 48.0, 56.0, 64.0, 72.0, 92.0]:
		for n in [2, 37, 999, 1250, 9898, 12345, 99999, 123456, 2500000]:
			var t := ItemSlot.qty_text(n, px)
			var w := fb.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, ItemSlot.qty_font_size(px)).x
			if w > px - 8.0:
				check(false, "the count %d fits a %d px slot ('%s' is %d px)" % [n, int(px), t, int(w)])
	eq(ItemSlot.qty_text(9898, 72.0), "9,898", "a four-digit count is shown whole on the usual slot")
	check(ItemSlot.qty_text(2500000, 44.0).ends_with("M"), "a huge count is shortened on a small slot")


# ------------------------------------------------------------------ #42 ten save slots
func test_ten_save_slots() -> void:
	eq(Saves.MANUAL_SLOTS, 10, "ten manual slots")
	eq(Saves.manual_slots().size(), 10, "manual_slots lists ten")
	check(Saves.SLOTS.has("autosave") and Saves.SLOTS.has("quicksave") and Saves.SLOTS.size() == 12, "plus the autosave and the quick-save")
	eq(Saves.slot_label("slot_10"), "Slot 10", "slot names")
	# an earlier build's saves in slots 1–3 stay byte-identical while the new slots are used
	for s in ["slot_1", "slot_2", "slot_3"]:
		check(Saves.save(s), "an earlier save in %s" % s)
	var old := {}
	for s in ["slot_1", "slot_2", "slot_3"]:
		old[s] = _bytes(Saves.path(s))
	for i in range(4, 11):
		Game.add_gold(1, "test", "slot %d" % i)
		check(Saves.save("slot_%d" % i), "saved to slot %d" % i)
	for s in old:
		eq(_bytes(Saves.path(s)), old[s], "%s is untouched" % s)
	eq(int(Saves.meta("slot_10").get("gold", -1)), Game.gold(), "slot 10's meta reads back")
	# the same atomic write: the previous save becomes the .bak
	var first := _bytes(Saves.path("slot_10"))
	Game.add_gold(5, "test", "again")
	check(Saves.save("slot_10"), "saved over slot 10")
	eq(_bytes(_bak("slot_10")), first, "the replaced save is kept as slot 10's backup")
	check(not FileAccess.file_exists(Saves.path("slot_10") + ".tmp"), "no temp file is left")
	eq(Saves.latest_slot(), "slot_10", "Continue picks the newest of all twelve")
	var gold := Game.gold()
	check(Saves.load_slot("slot_10") and Game.gold() == gold, "slot 10 loads")
	# a newer build's save in slot 8: listed, explained, never loaded or overwritten
	check(save_as_version("slot_8", Game.SAVE_VERSION + 1), "a newer build's save in slot 8")
	var nb := _bytes(Saves.path("slot_8"))
	check(not Saves.save("slot_8"), "saving over it is refused")
	check(not Saves.load_slot("slot_8"), "loading it is refused")
	eq(_bytes(Saves.path("slot_8")), nb, "slot 8 is byte-identical")
	Saves.notice = ""
	# the screens
	var sp := _mount(SavePanel.new("save")) as SavePanel
	eq(sp.rows.get_child_count(), 10, "the Save screen offers the ten manual slots")
	var b8 := sp.find_child("SlotButton_slot_8", true, false) as Button
	check(b8 != null and b8.disabled, "the newer save's slot cannot be saved over")
	check(_text_in(sp, "made by a newer version"), "…and says why")
	var b10 := sp.find_child("SlotButton_slot_10", true, false) as Button
	check(b10 != null and not b10.disabled and b10.tooltip_text.contains("backup"), "an occupied slot says the replaced save is kept as a backup")
	_fits(sp, "the Save screen")
	_unmount(sp)
	Saves.delete("slot_9")
	DirAccess.copy_absolute(Saves.path("slot_10"), _bak("slot_9"))   # only a backup left in slot 9
	var lp := _mount(SavePanel.new("load")) as SavePanel
	eq(lp.rows.get_child_count(), 12, "the Load screen lists all twelve")
	var l9 := lp.find_child("SlotButton_slot_9", true, false) as Button
	check(l9 != null and not l9.disabled, "a slot with only its backup can still be loaded (load_slot falls back to it)")
	check(Saves.load_slot("slot_9") and bool(Saves.last_load.get("from_backup", false)), "…and it does")
	_fits(lp, "the Load screen")
	_unmount(lp)
	for s in Saves.SLOTS:
		Saves.delete(s)


# ------------------------------------------------------------------ #44 the caravan
func test_caravan_arrival_notice() -> void:
	var toasts := []
	var cb := func(t: String, _k: String): toasts.append(t)
	Events.toast.connect(cb)
	if Commerce.caravan_present():
		Commerce.dev_caravan_leave()
	var jn := (Game.state["journal"] as Array).size()
	Commerce.dev_force_caravan()
	check(Commerce.caravan_present(), "the caravan is camped")
	check(toasts.any(func(t): return str(t).contains("caravan") and str(t).contains("stays")), "the toast says it arrived and how long it stays")
	var j: Array = Game.state["journal"]
	check(j.size() > jn and str(j[-1]["text"]).contains("caravan"), "a journal line records the arrival")
	check(TalkMarkers.wants_to_talk("caravan_master") != "", "the caravan master is marked on the map")
	var ui := _ui()
	ui._refresh_hud()
	check(ui.caravan_chip.visible and ui.caravan_chip.text.contains("leaves in"), "the HUD chip shows while it is camped: " + ui.caravan_chip.text)
	Commerce.dev_caravan_leave()
	ui._refresh_hud()
	check(not ui.caravan_chip.visible, "the chip goes when the caravan leaves")
	check(str((Game.state["journal"] as Array)[-1]["text"]).contains("caravan"), "the departure is in the journal")
	_ui_off(ui)
	Events.toast.disconnect(cb)


# ------------------------------------------------------------------ #38 health over time
func test_health_from_records_only() -> void:
	var a := Adv.get_a("elowen")
	Expeditions.ensure(a)
	check(HealthLog.points("elowen").is_empty(), "nothing is recorded before the first hour")
	check(HealthLog.caption([]).begins_with("No health recorded yet"), "…and the sheet says so")
	Game.advance_minutes(60)
	eq(int(Game.state.get("health_since", -1)), 1, "a new game records from day 1")
	var pts := HealthLog.points("elowen")
	check(pts.size() == 1 and int(pts[0]["hp"]) == int(a["hp"]), "the first point is her actual health")
	# a wound: the next hour records the real value, nothing in between is invented
	a["hp"] = maxi(1, int(a["hp_max"]) / 3)
	var wounded := int(a["hp"])
	HealthLog.on_hour(13)
	pts = HealthLog.points("elowen")
	eq(int(pts[-1]["hp"]), wounded, "the wound is recorded as it was")
	var before := pts.size()
	HealthLog.on_hour(14)
	eq(HealthLog.points("elowen").size(), before, "no point when nothing changed")
	# every logged value is one the adventurer actually had (recorded hour by hour as days pass)
	var seen := {}
	for i in 72:
		Game.advance_minutes(60)
		var lg: Array = a.get(HealthLog.KEY, [])
		seen[int(lg[-1][0])] = int(lg[-1][1])
		check(int(lg[-1][1]) <= int(a["hp_max"]), "never above the maximum")
	check((a[HealthLog.KEY] as Array).size() <= HealthLog.CAP, "capped at %d points" % HealthLog.CAP)
	# fight records from the expedition archive are merged as they were written
	var fought := 0
	for e in Expeditions.active().values() + Expeditions.done():
		for rec in e.get("encounters", []):
			if str(rec.get("kind", "")) != "combat":
				continue
			for p in rec.get("party", []):
				var ps := HealthLog.points(str(p["id"]))
				var hit := ps.filter(func(x): return int(x["t"]) == int(rec["t"]))
				check(not hit.is_empty() and int(hit[0]["hp"]) == maxi(0, int(p["hp"])), "a fight's recorded health is on the curve")
				fought += 1
	note("fight points checked: %d" % fought)
	# an older save: the record begins when it is first played with this build
	Game.state.erase("health_since")
	a.erase(HealthLog.KEY)
	Game.state["day"] = 30
	HealthLog.on_hour(9)
	eq(int(Game.state["health_since"]), 30, "an older save records from the day it is played")
	var p2 := HealthLog.points("elowen").filter(func(x): return str(x["kind"]) != "f" and str(x["kind"]) != "a")
	check(not p2.is_empty() and HealthLog.first_day(p2) == 30, "the first logged point is day 30")
	check(HealthLog.caption(p2).begins_with("No record before day 30"), "the sheet says there is no record before then: " + HealthLog.caption(p2))
	# the log survives a save and load
	var n := (a[HealthLog.KEY] as Array).size()
	check(save_load("lw_ui_health"), "save and load")
	eq((Adv.get_a("elowen").get(HealthLog.KEY, []) as Array).size(), n, "the health log is kept")
	# the character sheet draws it
	var dp := _mount(DossierPanel.new("elowen")) as DossierPanel
	check(dp.find_child("HealthCurve", true, false) != null, "the character sheet draws the curve")
	check(_text_in(dp, "No record before day 30"), "…with the honest caption")
	_unmount(dp)


# ------------------------------------------------------------------ #46 the material ledger
func _src(d: String, starts: String) -> int:
	for r in MaterialLedger.rows():
		if str(r["def"]) == d:
			for s in r["sources"]:
				if str(s[0]).begins_with(starts):
					return int(s[1])
	return 0


func _row(d: String) -> Dictionary:
	for r in MaterialLedger.rows():
		if str(r["def"]) == d:
			return r
	return {}


func test_material_ledger_sources() -> void:
	check(MaterialLedger.complete(), "a new game's record is complete from day 1")
	eq(_src("ore_iron", "Starting stores"), 8, "the starting iron ore is recorded as the starting stores")
	eq(int(_row("ore_iron")["before"]), 0, "nothing of unknown origin in a new game")
	var ledger_lines := (Game.state["ledger"] as Array).size()
	# bought at a village counter: the seller is named
	Game.state["gold"] = 500
	var err := Trade.buy_store("general_store", "coal", 3) if Trade.store_stock("general_store").any(func(e): return str(e["def"]) == "coal") else "no coal"
	if err == "":
		check(_src("coal", "Bought — ") == 3, "coal bought at Pell's is recorded with its seller")
		eq((Game.state["ledger"] as Array).size(), ledger_lines + 1, "the gold ledger has its one purchase line, as always")
	else:
		note("store purchase skipped: " + err)
	# smelting: ore used, ingots made at your stations
	var ore0 := Game.count("ore_iron")
	var it := craft("smelt_iron", 90.0)
	check(not it.is_empty(), "iron is smelted")
	var used := ore0 - Game.count("ore_iron")
	eq(int(_row("ore_iron")["used"]), used, "the ore used is recorded")
	check(_src("ingot_iron", "Made at your stations") >= 1, "the ingots are recorded as made at your stations")
	# a change that bypasses the hooks (e.g. a sale of materials to the caravan): counted, never given a source
	for x in Game.inventory():
		if str(x["def"]) == "reagent_salt":
			x["qty"] = int(x["qty"]) - 1
			break
	eq(int(_row("reagent_salt")["unitemised"]), -1, "a change the ledger did not see is shown as not itemised")
	Game.add_item(Items.make("reagent_salt", {"qty": 2}), false)
	eq(int(_row("reagent_salt")["remaining"]), Game.count("reagent_salt"), "remaining is the stores' real count")
	var r := _row("reagent_salt")
	var tot := int(r["before"]) - int(r["used"]) + int(r["unitemised"])
	for s in r["sources"]:
		tot += int(s[1])
	eq(tot, int(r["remaining"]), "acquired − used ± not itemised + before = remaining")
	# developer tools are their own source
	var dv := Items.make("coal", {"qty": 4})
	dv["dev"] = true
	Game.add_item(dv, false)
	eq(_src("coal", "Developer tools"), 4, "developer stacks are recorded apart")
	# the record survives a save and load
	var rows_before := JSON.stringify(MaterialLedger.rows())
	check(save_load("lw_ui_mats"), "save and load")
	eq(JSON.stringify(MaterialLedger.rows()), rows_before, "the ledger reads the same after loading")


func test_material_ledger_older_save() -> void:
	# an older save: no ledger yet, a journal, day 12 — what is on hand has no recorded origin
	Game.state.erase(MaterialLedger.KEY)
	Game.state["day"] = 12
	var coal := Game.count("coal")
	check(MaterialLedger.st().is_empty(), "nothing recorded before the first movement")
	var p := _mount(MaterialLedgerPanel.new()) as MaterialLedgerPanel
	check(_text_in(p, "its origin is not recorded"), "the panel says the stock's origin is not recorded")
	_unmount(p)
	check(Game.remove_def("coal", 2), "two coal used")
	eq(MaterialLedger.since_day(), 12, "the record begins on day 12")
	check(not MaterialLedger.complete(), "…and is not complete")
	var r := _row("coal")
	eq(int(r["before"]), coal, "the coal on hand before is shown with unknown origin")
	eq(int(r["used"]), 2, "the use is recorded")
	eq(int(r["remaining"]), coal - 2, "remaining")
	check(r["sources"].is_empty(), "no source is invented for what was there before")
	p = _mount(MaterialLedgerPanel.new()) as MaterialLedgerPanel
	check(_text_in(p, "Recorded from day 12"), "the panel names the day the record began")
	check(_text_in(p, "origin unknown"), "…and shows the earlier stock apart")
	check(p.find_child("Mat_coal", true, false) != null, "coal has its row")
	_fits(p, "the material ledger")
	_unmount(p)


# ------------------------------------------------------------------ #54–55 who is who
func test_who_is_who() -> void:
	var opp: Dictionary = {}
	for a in Adv.all().values():
		if str(a["status"]) == "in_town":
			a["needs"] = "helmet"
			if WhoIsWho.is_opportunity(a):
				opp = a
				break
	check(not opp.is_empty(), "an adventurer in town needs something forged")
	var id := str(opp["id"])
	eq(WhoIsWho.kind_of(id), "opportunity", "they are a commission opportunity")
	check(WhoIsWho.opportunities().has(opp), "listed among the opportunities")
	var o: Array = Talk.options(id, "inn").filter(func(x): return str(x["id"]) == "order")
	check(not o.is_empty() and str(o[0]["label"]).contains("commission opportunity"), "the conversation names the opportunity")
	var pr := WorldPrompts.npc_actions(id, "inn")
	check((pr["actions"] as Array).has("Commission?"), "the world prompt says so: %s" % str(pr["actions"]))
	var op := _mount(OrdersPanel.new()) as OrdersPanel
	check(op.find_child("Opp_" + id, true, false) != null, "the Commissions book lists them under opportunities")
	check(op.find_child("Section_commission", true, false) != null and op.find_child("Section_opportunity", true, false) != null, "…in its own section")
	_fits(op, "the Commissions book")
	_unmount(op)
	# asking turns the opportunity into a commission
	Talk.choose(id, "order", "inn")
	eq(WhoIsWho.kind_of(id), "commission", "after asking, an open commission")
	check(not WhoIsWho.opportunities().has(opp), "…and no longer an opportunity")
	# a waiting customer
	var other := ""
	for a in Adv.all().values():
		if str(a["status"]) == "in_town" and str(a["id"]) != id:
			other = str(a["id"])
			break
	Shop._add_customer("martha", "repair")
	Shop.mark_arrived("martha", false)
	eq(WhoIsWho.kind_of("martha"), "waiting", "a customer at the counter is waiting")
	if other != "":
		var oa := Adv.get_a(other)
		oa["needs"] = ""
		eq(WhoIsWho.kind_of(other), "visiting", "an adventurer with no business is visiting")
		oa["needs"] = "boots"
	var sp := _mount(ShopPanel.new("customers")) as ShopPanel
	var w := sp.find_child("Section_waiting", true, false)
	check(w != null, "the counter opens with the customers waiting at it")
	var off := sp.find_child("Section_offers", true, false)
	if off != null:
		check(w.get_index() < off.get_index(), "waiting customers come before the finds offered for sale")
	check(sp.find_child("Customer_martha", true, false) != null, "Martha's request is on the counter")
	if not WhoIsWho.opportunities().is_empty():
		check(sp.find_child("Section_opportunity", true, false) != null, "the counter mentions the opportunities in town")
	_fits(sp, "the counter")
	_unmount(sp)
	var ap := _mount(AdventurersPanel.new()) as AdventurersPanel
	check(ap.find_child("KindLegend", true, false) != null, "the roster explains the marks")
	var card := ap.find_child("Card_" + id, true, false)
	check(card != null and card.find_child("Kind_commission", true, false) != null, "the roster marks the open commission")
	_fits(ap, "the adventurers' roster")
	_unmount(ap)


# ------------------------------------------------------------------ #47 sizes
func test_uikit_sizes_and_panels_fit() -> void:
	var b := UIKit.button("Begin", func(): pass)
	eq(b.custom_minimum_size.y, float(UIKit.BUTTON_H), "buttons are BUTTON_H high")
	eq(b.get_theme_font_size("font_size"), UIKit.BUTTON_FS, "…with BUTTON_FS text")
	var w := UIKit.button("Wide", func(): pass, 200)
	eq(w.custom_minimum_size.x, 200.0, "min_w still works (backward compatible)")
	var s := UIKit.small_button("Inspect", func(): pass)
	check(s.custom_minimum_size.y < b.custom_minimum_size.y and s.get_theme_font_size("font_size") >= UIKit.FS_MIN, "a small button, still readable")
	check(UIKit.note("x", 10).get_theme_font_size("font_size") >= UIKit.FS_MIN, "notes never go below the readability floor")
	check(UIKit.BUTTON_H < 46 and UIKit.FS_TITLE < 38, "smaller than before #47 (buttons 46, titles 38)")
	b.free()
	w.free()
	s.free()
	var win := _mount(UIWindow.new("Test", 400, 200)) as UIWindow
	var x := win.find_child("CloseButton", true, false) as Button
	check(x != null and x.custom_minimum_size.y == float(UIKit.BUTTON_H), "the close button follows BUTTON_H")
	check(x != null and x.focus_mode != Control.FOCUS_NONE, "buttons keep keyboard focus")
	_unmount(win)
	# the reworked windows ask for less room than before #47 (declared sizes then; the rendered phase lw_ui measures
	# the laid-out sizes at 1920×1080 and 1600×900)
	var before := {"steward": Vector2(1560, 930), "inventory": Vector2(1560, 900), "dossier": Vector2(1600, 940),
		"shop": Vector2(1320, 780), "orders": Vector2(1240, 760), "adventurers": Vector2(1640, 900), "station": Vector2(1220, 860)}
	var panels := {"steward": StewardPanel.new(), "inventory": InventoryPanel.new(), "dossier": DossierPanel.new("elowen"),
		"shop": ShopPanel.new("customers"), "orders": OrdersPanel.new(), "adventurers": AdventurersPanel.new(), "station": StationPanel.new("anvil")}
	for k in panels:
		var p: Control = _mount(panels[k])
		var ms := _declared(p)
		var bf: Vector2 = before[k]
		_fits(p, k)
		check(ms.x <= bf.x and ms.y <= bf.y and ms.x * ms.y < bf.x * bf.y, "%s asks for less room than before (%d×%d < %d×%d)" % [k, int(ms.x), int(ms.y), int(bf.x), int(bf.y)])
		_unmount(p)
