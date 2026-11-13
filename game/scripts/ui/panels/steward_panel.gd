## StewardPanel — Steward Mode: the hand-over, the live status, the standing instructions and the matters waiting.
## EN: Three tabs. "The forge" — when the smith is at work: what the steward will do (the standing instructions in
##     brief), the plain confirmation that it runs only while the game runs, the engine's reason when a hand-over is not
##     possible, and the button; while the steward runs: time away, purse then and now, spending against the limits,
##     what holds it up, its log and the session's ledger lines, and "Take the workshop back". "Standing instructions"
##     — a summary line at the top, then every instruction the engine knows (spending, permitted purchases, duties,
##     ordinary-order rules, selling rules, protected pieces with the automatic protections and why, reserved
##     supplies), each change validated by Steward.set_orders (persistent engine state). "Matters waiting" — what the
##     steward left for the smith, each leading to the real matter (sealed letters stay sealed until opened).
##     Opened while the steward runs, the panel does not stop the clock. Fits 1920×1080.
## DA: Overdragelse, status, stående instrukser og ventende sager. Stopper ikke tiden, mens forvalteren arbejder.
class_name StewardPanel
extends UIWindow

var tab := "forge"
var tabs_row: HBoxContainer
var body: VBoxContainer
var summary: RichTextLabel
var refusal: Label
var _pending := false


func _init(args := {}) -> void:
	super._init("The Steward", 1520, 700)   # #47: was 930; v1.7 #69: 1560×800 → 1520×700
	tab = str(args.get("tab", "forge"))


func _ready() -> void:
	super._ready()
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	body = UIKit.vbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	Events.steward_changed.connect(_on_changed)
	build()


func _on_changed() -> void:
	# the instructions tab keeps its controls (a rebuild would steal the focus from a number being typed)
	if tab == "orders":
		if is_instance_valid(summary):
			summary.text = _summary_text()
		return
	if _pending or not is_inside_tree():
		return
	_pending = true
	(func():
		_pending = false
		if is_inside_tree():
			build()).call_deferred()


func build() -> void:
	UIKit.clear(tabs_row)
	UIKit.clear(body)
	var nd := Steward.deferred().size()
	for t in [["forge", "The steward at work" if Steward.is_active() else "Hand-over"], ["orders", "Standing instructions"],
			["matters", "Matters waiting (%d)" % nd]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; build(), 0)
		b.name = "Tab_" + key
		b.disabled = tab == key
		tabs_row.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(sp)
	if Steward.smith_away():
		tabs_row.add_child(UIKit.label("The clock keeps running while this is open.", 17, "body_italic", Color("#6e5a40")))
	match tab:
		"orders": _orders()
		"matters": _matters()
		_:
			if Steward.is_active():
				_status()
			else:
				_handover()


# ======================================================================= hand-over (mode off)
func _handover() -> void:
	var h := UIKit.hbox(24)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIKit.vbox(10)
	left.custom_minimum_size = Vector2(800, 0)
	left.add_child(UIKit.label("Hand the running forge to your steward", 30, "heading", UIKit.RUBRIC))
	var intro := UIKit.rich("While you are away the steward runs the [b]routine business[/b] of the workshop through the same actions you would take: "
		+ "it takes on suitable ordinary commissions, buys materials at the village counters, keeps the display stocked, "
		+ "serves waiting customers and delivers finished orders. [b]It sets you to routine work[/b] — ordinary forging, customers' repairs and "
		+ "smelting at a steady, average standard, in working hours, with your breaks and your night's sleep — and [i]you gain no experience "
		+ "from it[/i]. It never makes masterpieces, never reworks or enchants, and leaves anything consequential (major contracts, famous "
		+ "pieces, personal matters) for you.", 20)
	intro.custom_minimum_size = Vector2(780, 0)
	left.add_child(intro)
	# the confirmation
	var conf := PanelContainer.new()
	conf.name = "Confirmation"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1c12")
	sb.border_color = UIKit.GILT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	conf.add_theme_stylebox_override("panel", sb)
	var cv := UIKit.vbox(6)
	cv.add_child(UIKit.label("BEFORE YOU GO", 17, "heading", Color("#e8cc84")))
	var ct := UIKit.rich("[b]The steward will run the forge while the game runs; nothing happens while the game is closed.[/b]\n"
		+ "The whole village keeps moving at the steward's pace (%s pauses); you are back at your own speed the moment you return. Loading a save always finds you back at the forge, with the mode off. "
		% Settings.key_label("time_pause")
		+ "While away you can look around, but not act in the world. Take the workshop back from the steward's plate or with %s." % StewardUI.key(), 19, true)
	ct.custom_minimum_size = Vector2(740, 0)
	cv.add_child(ct)
	conf.add_child(cv)
	left.add_child(conf)
	left.add_child(_pace_row())
	var why := StewardUI.can_activate()
	refusal = UIKit.label(("Not now: " + why) if why != "" else "", 19, "body_bold", UIKit.RUBRIC)
	refusal.name = "Refusal"
	refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refusal.custom_minimum_size = Vector2(780, 0)
	refusal.visible = why != ""
	left.add_child(refusal)
	var row := UIKit.hbox(12)
	var go := UIKit.button("Hand over the forge", _activate, 300)
	go.name = "HandOver"
	go.disabled = why != ""
	go.tooltip_text = why
	row.add_child(go)
	row.add_child(UIKit.button("Not now", close, 160))
	var lr := Steward.last_report()
	if not lr.is_empty():
		row.add_child(UIKit.button("Read the last report (day %d)" % int(lr.get("to", {}).get("day", 0)), func():
			close()
			Events.open_panel.emit.call_deferred("welcome_back", {"report": lr, "old": true}), 0))
	left.add_child(row)
	h.add_child(left)
	# the standing instructions in brief
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(InkIcons.heading("tb_ledger", "Your standing instructions", 26))
	var o := StewardUI.orders()
	var sm := UIKit.rich(StewardUI.summary_bbcode(o), 18)
	sm.name = "InstructionsSummary"
	sm.custom_minimum_size = Vector2(620, 0)
	right.add_child(sm)
	right.add_child(UIKit.button("Change the instructions", func(): tab = "orders"; build(), 0))
	var waiting := Steward.deferred().size()
	if waiting > 0:
		right.add_child(UIKit.label("%d matter%s from an earlier absence still wait%s for you." % [waiting, "" if waiting == 1 else "s", "s" if waiting == 1 else ""], 18, "body_italic", UIKit.RUBRIC))
	h.add_child(right)
	body.add_child(h)


## S2: the steward's pace — normal (1×) or half again as fast (1.5×, the default); the whole simulation moves with it.
func _pace_row(with_note := false) -> HBoxContainer:
	var row := UIKit.hbox(10)
	row.name = "PaceRow"
	var cur := Steward.pace() if not Game.state.is_empty() and Game.state.has("steward") else float(StewardUI.orders().get("pace", 1.5))
	row.add_child(UIKit.label("Pace while away:", 19, "body_bold"))
	for p in [1.0, 1.5]:
		var pv: float = p
		var b := UIKit.button("%s %s" % ["Normal" if pv <= 1.0 else "Steward's pace", StewardUI.pace_text(pv)], func():
			var why := Steward.set_orders({"pace": pv})
			if why != "":
				Events.toast.emit(why, "bad")
			build(), 0)
		b.name = "Pace_%s" % ("1" if pv <= 1.0 else "15")
		b.disabled = absf(cur - pv) < 0.01
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	# Living Workshop #40: optionally, the nights pass at 5× while the smith sleeps (back to this pace when he wakes)
	var night := bool(StewardUI.orders().get("sleep_pace", false))
	var nb := UIKit.button("Nights %s× while you sleep: %s" % [str(int(Steward.SLEEP_PACE)), "on" if night else "off"], func():
		var why2 := Steward.set_orders({"sleep_pace": not night})
		if why2 != "":
			Events.toast.emit(why2, "bad")
		build(), 0)
	nb.name = "SleepPace"
	nb.tooltip_text = "While the steward runs the forge and you are asleep in your bed, the whole village moves %s× as fast; your own pace returns the moment you wake. Never outside Steward Mode." % str(int(Steward.SLEEP_PACE))
	nb.add_theme_font_size_override("font_size", 17)
	nb.add_theme_color_override("font_color", UIKit.RUBRIC if night else UIKit.INK)
	nb.custom_minimum_size = Vector2(0, 38)
	nb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nb)
	if with_note:
		var note := UIKit.label("the clock, people, walking and work all move together", 16, "body_italic", Color("#6e5a40"))
		note.autowrap_mode = TextServer.AUTOWRAP_OFF
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(note)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return row


func _activate() -> void:
	var why := StewardUI.hand_over()
	if why != "":
		Audio.play("sfx/error", -8.0)
		refusal.text = "Not now: " + why
		refusal.visible = true
		Events.toast.emit(why, "bad")
		return
	close()


# ======================================================================= live status (mode on)
func _status() -> void:
	var s := Steward.status()
	var since := int(Steward.st()["since"].get("gold", s.get("gold", 0)))
	var gold := int(s.get("gold", 0))
	var top := UIKit.hbox(24)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.rich("[font_size=26][b]Away %s[/b][/font_size]   [color=#6e5a40]since day %d, %s · now day %d, %s · pace %s[/color]" % [
		StewardUI.elapsed(int(s.get("elapsed_minutes", 0))), int(s.get("since_day", 0)), str(s.get("since_time", "")), Game.day(), Game.time_string(),
		StewardUI.pace_text(float(s.get("pace", 1.5)))], 19))
	var o := Steward.orders()
	v.add_child(UIKit.rich("Purse [b]%d g[/b] (%d g when you left, [color=%s]%s[/color]) · spent today %d of %d g · this absence %d of %d g · keeps at least %d g · may still spend %d g now" % [
		gold, since, "#26622f" if gold >= since else "#7e2418", StewardUI.signed(gold - since), int(s.get("spent_today", 0)), int(o["daily_limit"]),
		int(s.get("spent_session", 0)), int(o["session_limit"]), int(s.get("reserve", 0)), int(s.get("spendable", 0))], 18))
	top.add_child(v)
	var back := UIKit.button("Take the workshop back", func(): StewardUI.take_back(), 320)
	back.name = "TakeBack"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(back)
	body.add_child(top)
	body.add_child(_smith_card(s.get("smith", {})))
	var stalls: Array = s.get("stalls", [])
	if not stalls.is_empty():
		var sl := PackedStringArray()
		for x in stalls:
			sl.append("‼ [b]%s:[/b] %s" % [str(x.get("name", "")), str(x.get("text", ""))])
		var st_r := UIKit.rich("[color=#9e3a0c]%s[/color]" % "\n".join(sl), 18)
		st_r.custom_minimum_size = Vector2(1400, 0)
		body.add_child(st_r)
	body.add_child(UIKit.divider())
	var h := UIKit.hbox(20)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := UIKit.vbox(4)
	lv.add_child(InkIcons.heading("ic_work", "What the steward did", 24))
	var logbox := UIKit.vbox(2)
	var lg := Steward.recent_log(40)
	for i in range(lg.size() - 1, -1, -1):
		var e: Dictionary = lg[i]
		var r := UIKit.rich(StewardUI.log_line(e, true), 17)
		r.custom_minimum_size = Vector2(820, 0)
		logbox.add_child(r)
	var ls := UIKit.scroll(logbox, 420)
	ls.custom_minimum_size = Vector2(860, 420)
	lv.add_child(ls)
	h.add_child(lv)
	var rv := UIKit.vbox(4)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(InkIcons.heading("tb_ledger", "Ledger lines while you are away", 24))
	var led := UIKit.vbox(2)
	var rec: Array = Steward.st()["acc"].get("recent", [])
	if rec.is_empty():
		led.add_child(UIKit.label("No money has moved yet.", 17, "body_italic"))
	for i2 in range(rec.size() - 1, maxi(-1, rec.size() - 41), -1):
		var l: Dictionary = rec[i2]
		var amt := int(l.get("amount", 0))
		var lr := UIKit.rich("[color=#6e5a40]day %d %s[/color] [color=%s][b]%s[/b][/color] %s — %s" % [int(l.get("day", 0)), str(l.get("time", "")),
			"#26622f" if amt >= 0 else "#7e2418", StewardUI.signed(amt), str(l.get("cat", "")), str(l.get("note", ""))], 16)
		lr.custom_minimum_size = Vector2(560, 0)
		led.add_child(lr)
	var rs := UIKit.scroll(led, 420)
	rs.custom_minimum_size = Vector2(580, 420)
	rv.add_child(rs)
	h.add_child(rv)
	body.add_child(h)


## S2: the smith himself at work under the steward — what he is doing now, how tired he is, what he has done so far
## this absence, the piece in his hands — and the pace.
func _smith_card(sm: Dictionary) -> Control:
	var c := ApprenticeUI.card(1480)
	c.name = "SmithAtWork"
	var h := UIKit.hbox(18)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(InkIcons.heading("ic_work", "You, at work under the steward", 22))
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]" % str(sm.get("activity", "—")))
	var piece: Dictionary = sm.get("piece", {})
	var bits := PackedStringArray()
	bits.append("%s, fatigue %d" % [str(sm.get("band", Vitality.band())), int(round(float(sm.get("fatigue", Vitality.fatigue()))))])
	var hrs: Array = sm.get("hours", [8, 18])
	bits.append("works %02d:00–%02d:00, midday hour off, asleep 22:00–6:00" % [int(hrs[0]), int(hrs[1])])
	if not piece.is_empty():
		bits.append("in hand: %s (step %d of %d)" % [str(piece.get("name", "")), int(piece.get("step", 0)) + 1, int(piece.get("steps", 1))])
	lines.append("[color=#6e5a40]%s[/color]" % " · ".join(bits))
	var mins := int(sm.get("minutes", 0))
	lines.append("This absence: %d piece%s made, %d repair%s, %d h %02d min at the stations · no experience gained (the steward's work)" % [int(sm.get("made", 0)),
		"" if int(sm.get("made", 0)) == 1 else "s", int(sm.get("repairs", 0)), "" if int(sm.get("repairs", 0)) == 1 else "s", int(mins / 60), mins % 60])
	if not bool(sm.get("on", true)):
		lines.append("[color=#7e2418]His own work is switched off in the standing instructions: he only rests and sleeps.[/color]")
	var r := UIKit.rich("\n".join(lines), 18)
	r.name = "SmithStatus"
	r.custom_minimum_size = Vector2(1400, 0)
	v.add_child(r)
	v.add_child(_pace_row(true))
	h.add_child(v)
	c.add_child(h)
	return c


# ======================================================================= standing instructions
func _summary_text() -> String:
	return "[b]In short:[/b] " + StewardUI.summary_line(Steward.orders())


func _apply(patch: Dictionary) -> void:
	var why := Steward.set_orders(patch)
	if why != "":
		Audio.play("sfx/error", -8.0)
		Events.toast.emit(why, "bad")
		build()


func _card(title: String, icon_id: String, w := 740.0) -> VBoxContainer:
	var c := ApprenticeUI.card(w)
	var v := UIKit.vbox(4)
	v.add_child(InkIcons.heading(icon_id, title, 22))
	c.add_child(v)
	v.set_meta("card", c)
	return v


func _num(parent: Control, text: String, value: int, lo: int, hi: int, step: int, cb: Callable, suffix := "", tip := "") -> SpinBox:
	var row := UIKit.hbox(8)
	var l := UIKit.label(text, 18)
	l.custom_minimum_size = Vector2(330, 0)
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = value
	sb.suffix = suffix
	sb.custom_minimum_size = Vector2(150, 38)
	sb.tooltip_text = tip
	sb.value_changed.connect(func(v): cb.call(int(v)))
	row.add_child(sb)
	if tip != "":
		var t := UIKit.label(tip, 15, "body_italic", Color("#6e5a40"))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
	parent.add_child(row)
	return sb


func _check(parent: Control, text: String, on: bool, cb: Callable, tip := "") -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.tooltip_text = tip
	c.flat = true
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", UIKit.INK)
	c.add_theme_color_override("font_pressed_color", UIKit.INK)
	c.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
	c.toggled.connect(func(v): cb.call(v))
	parent.add_child(c)
	return c


func _orders() -> void:
	var o := Steward.orders()
	summary = UIKit.rich(_summary_text(), 19)
	summary.name = "OrdersSummary"
	summary.custom_minimum_size = Vector2(1480, 0)
	body.add_child(summary)
	body.add_child(UIKit.label("Every change is kept with your save and applies at once — also while the steward is at work.", 16, "body_italic", Color("#6e5a40")))
	var cols := UIKit.hbox(16)
	var c1 := UIKit.vbox(10)
	var c2 := UIKit.vbox(10)
	cols.add_child(c1)
	cols.add_child(c2)
	body.add_child(UIKit.scroll(cols, 640))
	# spending
	var sp := _card("Spending", "tb_ledger")
	_num(sp, "Most it may spend in one day", int(o["daily_limit"]), 0, 100000, 10, func(v): _apply({"daily_limit": v}), " g")
	_num(sp, "Most it may spend while you are away", int(o["session_limit"]), 0, 1000000, 50, func(v): _apply({"session_limit": v}), " g", "never below the daily limit")
	_num(sp, "Never let the purse fall below", int(o["reserve"]), 0, 1000000, 10, func(v): _apply({"reserve": v}), " g", "wages and upkeep still come from the daily loop")
	c1.add_child(sp.get_meta("card"))
	# purchases
	var pc := _card("Permitted purchases", "qt_market")
	pc.add_child(UIKit.label("Only at the village counters, only while they are open, only for work already planned.", 16, "body_italic", Color("#6e5a40")))
	var grid := GridContainer.new()
	grid.columns = 3
	var cats: Array = o["buy_categories"]
	for c in Steward.purchase_categories():
		var cat := str(c)
		_check(grid, cat, cats.has(cat), func(on):
			var cur: Array = Steward.orders()["buy_categories"]
			if on and not cur.has(cat):
				cur.append(cat)
			elif not on:
				cur.erase(cat)
			_apply({"buy_categories": cur}))
	pc.add_child(grid)
	pc.add_child(UIKit.label("Imports, ships, the caravan, the pawnbroker and the rival smith are never used.", 16, "body_italic", Color("#6e5a40")))
	c1.add_child(pc.get_meta("card"))
	# duties
	var du := _card("Allowed activities", "ic_work")
	var dg := GridContainer.new()
	dg.columns = 2
	for d in Steward.DUTIES:
		var dk := str(d)
		_check(dg, str(Steward.DUTY_NAME.get(dk, dk)), bool(o["duties"].get(dk, false)), func(on): _apply({"duties": {dk: on}}))
	du.add_child(dg)
	du.add_child(UIKit.label("Never: hiring or dismissing, masterpieces, refinement, enchanting or experiments, major contracts, imports — those stay with you.", 16, "body_italic", Color("#6e5a40")))
	c1.add_child(du.get_meta("card"))
	# S2: the smith's own working day under the steward, and the pace
	var wk := _card("Your own work while away", "ic_work")
	wk.name = "SmithWork"
	var hrs: Array = o.get("smith_hours", [8, 18])
	_num(wk, "Start work at (hour)", int(hrs[0]), 5, 12, 1, func(v): _apply({"smith_hours": [v, int(Steward.orders()["smith_hours"][1])]}), ":00")
	_num(wk, "Stop work at (hour)", int(hrs[1]), 13, 21, 1, func(v): _apply({"smith_hours": [int(Steward.orders()["smith_hours"][0]), v]}), ":00",
		"the midday hour by the hearth; to bed at 22:00, up at 6:00")
	wk.add_child(UIKit.label("Routine smithing Designs you know, at a steady average standard (never a masterwork); no experience is gained.", 16, "body_italic", Color("#6e5a40")))
	wk.add_child(_pace_row())
	c2.add_child(wk.get_meta("card"))
	# ordinary orders
	var orr: Dictionary = o["order_rules"]
	var oc := _card("Ordinary orders", "tb_orders")
	_num(oc, "Hardest work it takes on (difficulty)", int(orr["max_difficulty"]), 1, 10, 1, func(v): _apply({"order_rules": {"max_difficulty": v}}))
	_num(oc, "Smallest reward worth the work", int(orr["min_reward"]), 0, 100000, 5, func(v): _apply({"order_rules": {"min_reward": v}}), " g")
	_num(oc, "Days to spare before a deadline", int(orr["deadline_margin"]), 0, 5, 1, func(v): _apply({"order_rules": {"deadline_margin": v}}))
	_check(oc, "Politely decline parts the workshop cannot make", bool(orr["decline_unsuitable"]), func(on): _apply({"order_rules": {"decline_unsuitable": on}}))
	oc.add_child(UIKit.label("Fame-inspired and family commissions and major contract letters are always left for you.", 16, "body_italic", Color("#6e5a40")))
	c2.add_child(oc.get_meta("card"))
	# selling
	var sr: Dictionary = o["sell_rules"]
	var sc := _card("Selling", "story_sale")
	_num(sc, "Lowest price, % of a piece's value", int(sr["min_price_pct"]), 50, 300, 5, func(v): _apply({"sell_rules": {"min_price_pct": v}}), " %", "never below its materials")
	_num(sc, "Pieces to keep on display", int(sr["stock_target"]), 0, 12, 1, func(v): _apply({"sell_rules": {"stock_target": v}}))
	_check(sc, "Put new workshop pieces on display", bool(sr["list_new_work"]), func(on): _apply({"sell_rules": {"list_new_work": on}}))
	_check(sc, "Also display my ordinary stored pieces", bool(sr["list_existing"]), func(on): _apply({"sell_rules": {"list_existing": on}}))
	_check(sc, "Serve goods customers from my shelf", bool(sr["sell_goods"]), func(on): _apply({"sell_rules": {"sell_goods": on}}))
	c2.add_child(sc.get_meta("card"))
	# protected pieces
	c2.add_child(_protected_card(o).get_meta("card"))
	# reserved supplies
	c1.add_child(_reserved_card(o).get_meta("card"))


func _protected_card(o: Dictionary) -> VBoxContainer:
	var pv := _card("Protected pieces", "need_protection")
	pv.name = "Protected"
	var mine: Array = o["protected"]
	var auto := PackedStringArray()
	var ordinary: Array = []
	for it in Game.inventory():
		if not Items.is_equipment(it):
			continue
		var uid := int(it["uid"])
		if mine.has(uid):
			continue
		var why := Steward.protection_reason(it)
		if why != "":
			auto.append("[b]%s[/b] — %s" % [StewardUI.piece_name(it), why])
		else:
			ordinary.append(it)
	if mine.is_empty():
		pv.add_child(UIKit.label("You have protected nothing by hand.", 17, "body_italic"))
	for u in mine:
		var uid2 := int(u)
		var it2 := ItemRegistry.find(uid2)
		var row := UIKit.hbox(8)
		var l := UIKit.label(StewardUI.piece_name(it2) if not it2.is_empty() else "(piece no. %d, no longer here)" % uid2, 18, "body_bold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UIKit.button("Unprotect", func():
			var why2 := Steward.protect(uid2, false)
			if why2 != "":
				Events.toast.emit(why2, "bad")
			build(), 0)
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(0, 36)
		row.add_child(b)
		pv.add_child(row)
	if not ordinary.is_empty():
		var add := UIKit.hbox(8)
		var ob := OptionButton.new()
		ob.name = "ProtectPick"
		ob.custom_minimum_size = Vector2(470, 38)
		for it3 in ordinary:
			ob.add_item(StewardUI.piece_name(it3))
			ob.set_item_metadata(ob.item_count - 1, int(it3["uid"]))
		add.add_child(ob)
		add.add_child(UIKit.button("Protect", func():
			if ob.selected < 0:
				return
			var why3 := Steward.protect(int(ob.get_item_metadata(ob.selected)))
			if why3 != "":
				Events.toast.emit(why3, "bad")
			build(), 0))
		pv.add_child(add)
	if not auto.is_empty():
		pv.add_child(UIKit.label("Always protected, whatever you choose:", 17, "heading"))
		var ar := UIKit.rich("\n".join(auto.slice(0, 8)) + ("\n[i]… and %d more[/i]" % (auto.size() - 8) if auto.size() > 8 else ""), 16)
		ar.custom_minimum_size = Vector2(680, 0)
		pv.add_child(ar)
	else:
		pv.add_child(UIKit.label("Epic, named, legendary and historically significant pieces are always protected.", 16, "body_italic", Color("#6e5a40")))
	return pv


func _reserved_card(o: Dictionary) -> VBoxContainer:
	var rv := _card("Reserved supplies", "tb_inventory")
	rv.name = "Reserved"
	rv.add_child(UIKit.label("The steward never lets these fall below the number you set (work and sales leave them alone).", 16, "body_italic", Color("#6e5a40")))
	var res: Dictionary = o["reserved"]
	for d in res:
		var dk := str(d)
		var row := UIKit.hbox(8)
		var l := UIKit.label("%s (you have %d)" % [str(DB.item(dk).get("name", dk)), Game.count(dk)], 18)
		l.custom_minimum_size = Vector2(380, 0)
		row.add_child(l)
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 999
		sb.value = int(res[d])
		sb.custom_minimum_size = Vector2(120, 36)
		sb.value_changed.connect(func(v): _set_reserve(dk, int(v), false))
		row.add_child(sb)
		var b := UIKit.button("Remove", func(): _set_reserve(dk, 0, true), 0)
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(0, 36)
		row.add_child(b)
		rv.add_child(row)
	var defs: Array = []
	for it in Game.inventory():
		var d2 := str(it["def"])
		if Items.is_equipment(it) or res.has(d2) or defs.has(d2):
			continue
		defs.append(d2)
	defs.sort()
	if not defs.is_empty():
		var add := UIKit.hbox(8)
		var ob := OptionButton.new()
		ob.name = "ReservePick"
		ob.custom_minimum_size = Vector2(360, 38)
		for d3 in defs:
			ob.add_item("%s (%d)" % [str(DB.item(str(d3)).get("name", d3)), Game.count(str(d3))])
			ob.set_item_metadata(ob.item_count - 1, str(d3))
		add.add_child(ob)
		var n := SpinBox.new()
		n.min_value = 1
		n.max_value = 999
		n.value = 2
		n.custom_minimum_size = Vector2(110, 38)
		add.add_child(n)
		add.add_child(UIKit.button("Keep in stock", func():
			if ob.selected >= 0:
				_set_reserve(str(ob.get_item_metadata(ob.selected)), int(n.value), true), 0))
		rv.add_child(add)
	return rv


func _set_reserve(def_id: String, n: int, rebuild: bool) -> void:
	var why := Steward.reserve(def_id, n)
	if why != "":
		Events.toast.emit(why, "bad")
	if rebuild or why != "":
		build()


# ======================================================================= matters waiting
func _matters() -> void:
	var list := UIKit.vbox(6)
	var d := Steward.deferred()
	if d.is_empty():
		list.add_child(UIKit.label("Nothing waits for you.", 20, "body_italic"))
	for e in d:
		list.add_child(_matter_row(e))
	var lapsed: Array = Steward.deferred(true).filter(func(x): return str(x.get("resolved_by", "")) == "world")
	if not lapsed.is_empty():
		list.add_child(UIKit.divider())
		list.add_child(UIKit.label("Settled without you (the world does not wait)", 20, "heading"))
		for i in range(lapsed.size() - 1, maxi(-1, lapsed.size() - 13), -1):
			var x: Dictionary = lapsed[i]
			var r := UIKit.rich("[color=#6e5a40]day %d[/color] %s — [i]%s[/i]" % [int(x.get("resolved_day", x.get("day", 0))), _visible_text(x), str(x.get("outcome", ""))], 16)
			r.custom_minimum_size = Vector2(1400, 0)
			list.add_child(r)
	body.add_child(UIKit.scroll(list, 660))


## The text of a matter as the smith may see it: an unopened sealed letter shows only its envelope.
static func _visible_text(e: Dictionary) -> String:
	if bool(e.get("sealed", false)) and not bool(e.get("opened", false)):
		return "A sealed letter — %s" % StewardUI.sender(e)
	return str(e.get("text", ""))


func _matter_row(e: Dictionary) -> Control:
	var id := str(e["id"])
	var c := ApprenticeUI.card(1440)
	c.name = "Matter_" + id
	var h := UIKit.hbox(12)
	c.add_child(h)
	var sealed := bool(e.get("sealed", false)) and not bool(e.get("opened", false))
	if sealed and Assets.has_tex("ui/wax_seal"):
		h.add_child(UIKit.icon("ui/wax_seal", 40))
	var r := UIKit.rich("[color=#7e2418][b]%s[/b][/color] [color=#6e5a40]· day %d %s[/color]\n%s" % [StewardUI.kind_name(str(e.get("kind", ""))), int(e.get("day", 0)),
		str(e.get("time", "")), _visible_text(e)], 17)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(r)
	if sealed:
		h.add_child(UIKit.button("Open the letter", func(): close(); Events.open_panel.emit.call_deferred("sealed_letter", {"id": id}), 0))
	else:
		var route := str(e.get("action", {}).get("route", ""))
		if route != "" and not Steward.smith_away():
			h.add_child(UIKit.button("Go to it", func(): close(); StewardUI.follow(id), 0))
		h.add_child(UIKit.button("Seen to", func(): Steward.resolve(id); build(), 0))
	return c
