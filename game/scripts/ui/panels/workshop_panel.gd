## WorkshopPanel — the workshop ledger: apprentices, stations and the work queue (iteration 012, key Y).
## EN: Left: the apprentices (portrait, rank and specialty, skills with experience bars, current task and progress,
##     shift status, wage, loyalty) and the stations (in use by whom, free, worn with condition, locked, not set up).
##     Right: the Bottlenecks box (Apprentices.bottlenecks), the queue grouped as customer repairs, commissions,
##     production and upkeep — each task with materials (have/need), time left, expected craftsmanship, costs,
##     priority (up/down), assignee (automatic or a chosen apprentice), progress, state and what blocks it — the
##     pieces recently finished (inspectable), and the controls to add work: a repair or commission from what is
##     waiting, a recipe to craft or prepare with a repeat count, or station upkeep. Automatic assignment toggles here.
##     Parchment, 80 % Ink & Parchment, 20 % Gothic Noir (the dark Bottlenecks plate). Fits 1920×1080.
## DA: Værkstedets regnskab: lærlinge, stationer og arbejdskøen med materialer, tid, kvalitet, prioritet og flaskehalse.
class_name WorkshopPanel
extends UIWindow

const GROUPS := [["contract", "Major contracts", "contracts/crate_goods"], ["repair", "Customer repairs", "ui/act_hammer"], ["commission", "Commissions", "ui/tb_orders"],
	["production", "Production", "ui/tb_designer"], ["maintain", "Upkeep", "ui/tb_property"]]
const STATE_COL := {"working": "#24409a", "queued": "#20140c", "blocked": "#9e3a0c", "done": "#26622f", "failed": "#7e2418", "cancelled": "#8a7a60"}

var left: VBoxContainer
var right_top: VBoxContainer
var queue: VBoxContainer
var adder: VBoxContainer
var add_kind := "craft"
var _pending := false


func _init() -> void:
	super._init("The Workshop Ledger — apprentices & work", 1780, 900)   # #47: was 1840×980 (it covered the HUD)


func _ready() -> void:
	super._ready()
	var h := UIKit.hbox(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left = UIKit.vbox(8)
	var ls := UIKit.scroll(left, 760)
	ls.custom_minimum_size = Vector2(600, 760)
	h.add_child(ls)
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_top = UIKit.vbox(6)
	right.add_child(right_top)
	queue = UIKit.vbox(6)
	var qs := UIKit.scroll(queue, 470)
	qs.name = "QueueScroll"
	right.add_child(qs)
	adder = UIKit.vbox(6)
	right.add_child(adder)
	h.add_child(right)
	content.add_child(h)
	Events.apprentices_changed.connect(_queue_build)
	Events.inventory_changed.connect(_queue_build)
	build()


func _queue_build() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	(func():
		_pending = false
		if is_inside_tree():
			build()).call_deferred()


func build() -> void:
	UIKit.clear(left)
	UIKit.clear(right_top)
	UIKit.clear(queue)
	UIKit.clear(adder)
	_build_left()
	_build_top()
	_build_queue()
	_build_adder()
	if Steward.smith_away():
		_lock_away()


## Steward Mode: while the smith is away the ledger is for looking; the steward plans the work.
func _lock_away() -> void:
	for box in [left, right_top, queue, adder]:
		for n in (box as Node).find_children("*", "BaseButton", true, false):
			if n.name == "StewardButton":
				continue
			(n as BaseButton).disabled = true
			(n as BaseButton).tooltip_text = StewardUI.away_note()


# ======================================================================= left: apprentices & stations
func _build_left() -> void:
	var staff := Apprentices.staff()
	var hd := UIKit.hbox(8)
	hd.add_child(InkIcons.heading("tb_hirelings", "Apprentices  %d / %d" % [staff.size(), Apprentices.max_staff()], 26))
	left.add_child(hd)
	if not Apprentices.unlocked():
		var ul := UIKit.label(Apprentices.unlock_reason(), 18, "body_italic", ApprenticeUI.BAD)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(600, 0)
		left.add_child(ul)
	elif staff.is_empty():
		var nl := UIKit.label("No apprentices yet. Applicants pin their names to the village notice board each week.", 18, "body_italic")
		nl.custom_minimum_size = Vector2(600, 0)
		left.add_child(nl)
	for a in staff:
		left.add_child(_app_card(a))
	var hb := UIKit.hbox(8)
	hb.add_child(InkIcons.button("ic_work", "Notice board — hire", func(): close(); Events.open_panel.emit.call_deferred("notice", {"tab": "apprentices"}), 0))
	hb.add_child(InkIcons.button("tb_property", "Rooms & stations", func(): close(); Events.open_panel.emit.call_deferred("property", {}), 0))
	left.add_child(hb)
	left.add_child(UIKit.divider())
	left.add_child(InkIcons.heading("tb_property", "Stations", 26))
	left.add_child(_stations())


func _app_card(a: Dictionary) -> Control:
	var aid := str(a["id"])
	var c := ApprenticeUI.card(600)
	c.name = "AppCard_" + aid
	var h := UIKit.hbox(10)
	c.add_child(h)
	h.add_child(ApprenticeUI.portrait(str(a.get("look", "")), 84))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp := str(a.get("specialty", ""))
	v.add_child(UIKit.rich("[font_size=22][b]%s[/b][/font_size]  [color=#7e2418]%s · %s%s[/color]" % [str(a["name"]), Workers.title(a), Apprentices.rank_name(a), (" · " + Apprentices.category_name(sp)) if sp != "" else ""], 17))
	var stw := ApprenticeUI.status_word(a)
	var stc := "#24409a" if str(a.get("status", "")) == "working" else "#6e5a40"
	if not (a.get("notice", {}) as Dictionary).is_empty():
		stc = "#9e3a0c"
	v.add_child(UIKit.rich("[color=%s]%s[/color] · wage %d g/day · loyalty: %s · %s" % [stc, stw, int(a.get("wage", 0)), ApprenticeUI.loyalty_word(float(a.get("loyalty", 50.0))), ApprenticeUI.works_text(int(a.get("works", 0)))], 16))
	v.add_child(UIKit.rich(ApprenticeUI.traits_bbcode(a.get("traits", [])), 15))
	v.add_child(ApprenticeUI.skills_grid(a, 90.0, 15))
	var t := Apprentices.task(int(a.get("task", -1)))
	var cur := Apprentices.current(a)
	if not t.is_empty():
		var row := UIKit.hbox(8)
		var tl := UIKit.label("▸ %s" % str(t.get("label", "")), 16, "body_bold")
		tl.clip_text = true
		tl.custom_minimum_size = Vector2(280, 0)
		row.add_child(tl)
		var pb := UIKit.bar(_task_frac(t, a), 1.0, 120)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		v.add_child(row)
	var act := str(cur.get("activity", ""))
	if act != "":
		v.add_child(UIKit.label(act, 15, "body_italic", ApprenticeUI.MUTED))
	var nr := Apprentices.next_rank(a)
	if not nr.is_empty():
		v.add_child(UIKit.label("Next rank — " + str(nr.get("text", "")), 14, "body_italic", ApprenticeUI.MUTED))
	h.add_child(v)
	var bv := UIKit.vbox(4)
	var why := ""
	if str(a.get("status", "")) == "off":
		why = "gone home"
	elif int(a.get("mentored_day", -1)) == Game.day():
		why = "taught today"
	var tb := UIKit.button("Teach (1 h)", func():
		var err := Apprentices.mentor(aid)
		Events.toast.emit(err if err != "" else "You taught %s for an hour." % str(a["name"]), "bad" if err != "" else "good"), 130)
	tb.disabled = why != ""
	tb.tooltip_text = why if why != "" else "Spend an hour at their side: experience and loyalty; their current task counts as supervised."
	tb.add_theme_font_size_override("font_size", 16)
	bv.add_child(tb)
	if str(a.get("notice", {}).get("kind", "")) == "independence":
		var nb := UIKit.button("Answer…", func(): close(); Events.open_panel.emit.call_deferred("apprentice", {"id": aid}), 130)
		nb.add_theme_font_size_override("font_size", 16)
		bv.add_child(nb)
	h.add_child(bv)
	return c


## How far a task is: finished pieces plus the current piece's steps.
func _task_frac(t: Dictionary, a := {}) -> float:
	var rep := maxi(1, int(t.get("repeat", 1)))
	var ops := Apprentices.task_ops(t, a)
	var piece := 0.0
	if bool(t.get("started", false)) and not ops.is_empty():
		var need := maxf(1.0, float(t.get("need", 0.0)))
		piece = (float(t.get("op", 0)) + clampf(float(t.get("progress", 0.0)) / need, 0.0, 1.0)) / float(ops.size())
	if str(t.get("state", "")) == "done":
		return 1.0
	return clampf((float(t.get("done", 0)) + piece) / float(rep), 0.0, 1.0)


func _stations() -> Control:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 2)
	var ids: Array = (Property.st()["stations"] as Dictionary).keys() + (Property.st()["stored"] as Array)
	var installed := ids.filter(func(s): return Property.is_installed(str(s)))
	var others := ids.filter(func(s): return not Property.is_installed(str(s)))
	installed.sort_custom(func(x, y): return str(DB.station(str(x)).get("name", x)) < str(DB.station(str(y)).get("name", y)))
	for sid_v in installed + others:
		var sid := str(sid_v)
		var state := Apprentices.station_state(sid)
		g.add_child(UIKit.label(Property.instance_label(sid), 16, "body_bold"))   # #37: "Anvil #2"
		var col: Color = ApprenticeUI.STATION_COLS.get(state, UIKit.INK)
		var word := str(ApprenticeUI.STATION_WORDS.get(state, state))
		var u := Apprentices.station_user(sid)
		if u == "smith":
			word = "you are working here"
		elif u != "":
			word = "in use — " + str(Apprentices.get_a(u).get("name", "")).split(" ")[0]
		var wl := UIKit.label(word, 15, "body_italic", col)
		wl.custom_minimum_size = Vector2(160, 0)
		g.add_child(wl)
		var cond := Apprentices.station_condition(sid)
		var b := UIKit.bar(cond, 100.0, 80)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "Condition %d%%" % int(round(cond))
		g.add_child(b)
		g.add_child(UIKit.label("%d%%" % int(round(cond)), 14, "body", ApprenticeUI.BAD if Apprentices.is_worn(sid) else ApprenticeUI.MUTED))
	return g


# ======================================================================= right: bottlenecks & header
func _build_top() -> void:
	var row := UIKit.hbox(14)
	var auto := CheckButton.new()
	auto.text = "Automatic assignment"
	auto.button_pressed = bool(Apprentices.st()["auto"])
	auto.toggled.connect(func(on): Apprentices.set_auto(on))
	auto.tooltip_text = "On: idle apprentices take the most urgent work they can do. Off: only tasks you assign are worked."
	row.add_child(auto)
	var wages := 0
	for a in Apprentices.staff():
		wages += int(a.get("wage", 0))
	var sh: Dictionary = Apprentices.cfg("shift")
	var info := UIKit.label("Shift %d:00–%d:00, break %d:00–%d:00 · wages %d g/day · now %s, day %d" % [int(sh.get("start", 8)), int(sh.get("end", 18)),
		int(sh.get("break_start", 12)), int(sh.get("break_end", 13)), wages, Game.time_string(), Game.day()], 17, "body_italic")
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(info)
	# Steward Mode (S1): hand the running forge over from here, or see the steward at work
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var stw := InkIcons.button("act_road", "The steward at work…" if Steward.is_active() else "Hand over to the steward…", func():
		close()
		Events.open_panel.emit.call_deferred("steward", {}), 0)
	stw.name = "StewardButton"
	stw.add_theme_font_size_override("font_size", 17)
	row.add_child(stw)
	right_top.add_child(row)
	# the Bottlenecks plate (dark: the 20 % gothic accent)
	var plate := PanelContainer.new()
	plate.name = "Bottlenecks"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1c12")
	sb.border_color = UIKit.GILT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	plate.add_theme_stylebox_override("panel", sb)
	var pv := UIKit.vbox(2)
	pv.add_child(UIKit.label("BOTTLENECKS", 16, "heading", Color("#e8cc84")))
	var bn := Apprentices.bottlenecks()
	var txt := ""
	if bn.is_empty():
		txt = "[i]Nothing holds the workshop back.[/i]"
	else:
		var shown := PackedStringArray()
		for i in mini(bn.size(), 4):
			shown.append("• " + bn[i])
		if bn.size() > 4:
			shown.append("[i]…and %d more.[/i]" % (bn.size() - 4))
		txt = "\n".join(shown)
	pv.add_child(UIKit.rich(txt, 16, true))
	plate.add_child(pv)
	right_top.add_child(plate)
	_help_requests()
	_contracts_line()


## C1 (D8): a worker's request for a hand — optional: answer it, or let them carry on alone.
func _help_requests() -> void:
	for h in WorkOrders.open_help():
		var row := UIKit.hbox(8)
		row.name = "HelpRequest_%d" % int(h["id"])
		var left_min := int(h.get("expires", 0)) - Game.now()
		var r := UIKit.rich("[color=#7e2418]✋[/color] %s [i](optional — %s left)[/i]" % [str(h["text"]), ApprenticeUI.minutes_text(left_min)], 16)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(r)
		var hid := int(h["id"])
		var yes := UIKit.small_button("Lend a hand (%d min)" % WorkOrders.HELP_MINUTES, func():
			var err := WorkOrders.answer_help(hid, "help")
			Events.toast.emit(err if err != "" else "You spend half an hour at their side.", "bad" if err != "" else "good"), 0)
		yes.name = "HelpYes_%d" % hid
		row.add_child(yes)
		var no := UIKit.small_button("Not now", func(): WorkOrders.answer_help(hid, "decline"), 0)
		no.name = "HelpNo_%d" % hid
		no.tooltip_text = "They carry on alone — the work is not held up, it just goes without your hand."
		row.add_child(no)
		right_top.add_child(row)


## The Living Realm: major contracts in hand and letters waiting (the contract view opens at the Project Bench).
func _contracts_line() -> void:
	if Contracts.active().is_empty() and Contracts.offers().is_empty():
		return
	var row := UIKit.hbox(10)
	var parts := PackedStringArray()
	for c in Contracts.active():
		parts.append("[b]%s[/b] %d/%d pieces, day %d" % [str(c["title"]), int(c["units_done"]), int(c["units_total"]), int(c["deadline"])])
	if not Contracts.offers().is_empty():
		parts.append("[color=#7e2418]%d letter%s waiting[/color]" % [Contracts.offers().size(), "" if Contracts.offers().size() == 1 else "s"])
	var r := UIKit.rich("Major contracts: " + " · ".join(parts), 16)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(r)
	var b := InkIcons.button("contracts/crate_goods", "Contract view", func(): close(); Events.open_panel.emit.call_deferred("contracts", {}), 0)
	b.name = "ContractViewButton"
	b.add_theme_font_size_override("font_size", 16)
	row.add_child(b)
	right_top.add_child(row)


# ======================================================================= right: the queue
func _group_of(t: Dictionary) -> String:
	match str(t.get("kind", "")):
		"repair":
			return "repair"
		"commission":
			return "commission"
		"maintain":
			return "maintain"
		"contract":
			return "contract"
	return "production"


func _build_queue() -> void:
	var open := Apprentices.open_tasks()
	open.sort_custom(func(x, y): return int(x["priority"]) > int(y["priority"]) or (int(x["priority"]) == int(y["priority"]) and int(x["id"]) < int(y["id"])))
	var any := false
	for g in GROUPS:
		var rows := open.filter(func(t): return _group_of(t) == str(g[0]))
		if rows.is_empty():
			continue
		any = true
		queue.add_child(InkIcons.heading(str(g[2]), "%s (%d)" % [g[1], rows.size()], 21))
		for t in rows:
			queue.add_child(_task_row(t))
	if not any:
		queue.add_child(UIKit.label("The queue is empty. Add work below — repairs and commissions waiting in the shop are offered there.", 18, "body_italic"))
	var fin := Apprentices.tasks().filter(func(t): return str(t["state"]) in ["done", "failed"])
	if not fin.is_empty():
		queue.add_child(UIKit.divider())
		queue.add_child(UIKit.label("Recently finished", 20, "heading"))
		for t in fin.slice(maxi(0, fin.size() - 5)):
			queue.add_child(_finished_row(t))


func _task_row(t: Dictionary) -> Control:
	var tid := int(t["id"])
	var c := ApprenticeUI.card(0, Color(0.96, 0.92, 0.82, 0.9))
	c.name = "Task_%d" % tid
	var v := UIKit.vbox(2)
	c.add_child(v)
	# line 1: title, state, priority, assignee, cancel
	var r1 := UIKit.hbox(8)
	var staged := WorkOrders.staged(t)
	var title := UIKit.label(str(t.get("label", "")) + ("  · work order, %d stages" % WorkOrders.stages(t).size() if staged else ""), 18, "body_bold")
	if int(t.get("uid", 0)) > 0:
		title.tooltip_text = "The piece's identity (uid %d) was reserved when the order was made; it keeps it from the first stage to the stores." % int(t["uid"])
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(300, 0)
	r1.add_child(title)
	var st := str(t.get("state", ""))
	r1.add_child(UIKit.label(st, 16, "body_italic", Color(str(STATE_COL.get(st, "#20140c")))))
	var pr := int(t.get("priority", 2))
	var up := UIKit.button("▲", func(): Apprentices.set_priority(tid, pr + 1), 40)
	up.disabled = pr >= 3
	up.tooltip_text = "Raise the priority"
	var dn := UIKit.button("▼", func(): Apprentices.set_priority(tid, pr - 1), 40)
	dn.disabled = pr <= 1
	dn.tooltip_text = "Lower the priority"
	r1.add_child(up)
	var pl := UIKit.label(ApprenticeUI.priority_name(pr), 16, "body_bold", ApprenticeUI.BAD if pr == 3 else (ApprenticeUI.MUTED if pr == 1 else UIKit.INK))
	pl.custom_minimum_size = Vector2(56, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r1.add_child(pl)
	r1.add_child(dn)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(190, 40)
	ob.add_item("Auto (best hand)")
	ob.set_item_metadata(0, "")
	var sel := 0
	for a in Apprentices.staff():
		ob.add_item(str(a["name"]))
		ob.set_item_metadata(ob.item_count - 1, str(a["id"]))
		if str(t.get("assignee", "")) == str(a["id"]):
			sel = ob.item_count - 1
	ob.selected = sel
	ob.item_selected.connect(func(i):
		var err := Apprentices.assign(tid, str(ob.get_item_metadata(i)))
		if err != "":
			Events.toast.emit(err, "bad")
			_queue_build())
	ob.tooltip_text = "Who makes it: automatic, or pin the piece to one apprentice (a work order's other crafts go to those who may do them)." if staged else "Who does it: automatic, or pin it to one apprentice."
	r1.add_child(ob)
	var x := UIKit.button("✕", func():
		var err := Apprentices.cancel_task(tid)
		if err != "":
			Events.toast.emit(err, "bad"), 40)
	x.tooltip_text = "Cancel — materials go back to the stores."
	r1.add_child(x)
	v.add_child(r1)
	# line 2: progress, worker, estimate
	var e := Apprentices.estimate(t)
	var r2 := UIKit.hbox(10)
	var pb := UIKit.bar(_task_frac(t, Apprentices.get_a(str(t.get("worker", "")))), 1.0, 160)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(pb)
	var who := str(Apprentices.get_a(str(t.get("worker", ""))).get("name", ""))
	var est_by := str(Apprentices.get_a(str(e.get("app", ""))).get("name", ""))
	var parts := PackedStringArray()
	if int(t.get("repeat", 1)) > 1:
		parts.append(("%d/%d h worked" if str(t.get("kind", "")) == "contract" else "%d/%d made") % [int(t.get("done", 0)), int(t.get("repeat", 1))])
	if who != "":
		parts.append("[b]%s[/b] at work" % who)
	elif est_by != "":
		parts.append("best hand: %s" % est_by)
	parts.append("time left %s" % ApprenticeUI.minutes_text(int(e.get("minutes", 0))))
	if float(e.get("quality", 0.0)) > 0.0:
		parts.append("expected ~%d%%" % int(round(float(e.get("quality", 0.0)))))
	if int(e.get("cost", 0)) > 0 or int(e.get("wage_cost", 0)) > 0:
		parts.append("materials %d g · wages ~%d g" % [int(e.get("cost", 0)), int(e.get("wage_cost", 0))])
	if bool(t.get("supervised", false)):
		parts.append("[color=#26622f]supervised[/color]")
	var info := UIKit.rich(" · ".join(parts), 15)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(info)
	v.add_child(r2)
	# line 3: materials have/need and the blocker
	var mats: Dictionary = e.get("materials", {})
	var line3 := PackedStringArray()
	if not mats.is_empty():
		var mm := PackedStringArray()
		var ks := mats.keys()
		ks.sort()
		for d in ks:
			var have := Game.count(str(d))
			var need := int(mats[d])
			mm.append("[color=%s]%d/%d %s[/color]" % ["#26622f" if have >= need else "#9e3a0c", mini(have, 999), need, str(DB.item(str(d)).get("name", d))])
		line3.append("Materials " + ", ".join(mm))
	var tk: Dictionary = t.get("taken", {})
	if not tk.is_empty():
		line3.append("[i]in hand: %s[/i]" % ApprenticeUI.defs_text(tk))
	if str(t.get("blocker", "")) != "":
		line3.append("[color=#9e3a0c]⚠ %s[/color]" % str(t["blocker"]))
	if not line3.is_empty():
		v.add_child(UIKit.rich("  ·  ".join(line3), 15))
	if staged:
		v.add_child(_stage_rows(t))
	return c


# ======================================================================= C1: a work order's stages
## Living Workshop C1 (PROD-022): each stage of a work order — what it is, who does it (or did it, how well), where and
## how far, the materials it puts into the piece, and who it is given to (automatic, an apprentice, or "you").
func _stage_rows(t: Dictionary) -> Control:
	var tid := int(t["id"])
	var g := GridContainer.new()
	g.name = "Stages_%d" % tid
	g.columns = 5
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 2)
	var cur := WorkOrders.stage_index(t)
	for s in WorkOrders.stages(t):
		var si := int(s["i"])
		var state := str(s["state"])
		var here := si == cur and not str(t.get("state", "")) in Apprentices.FINISHED
		var glyph: String = {"done": "✓", "working": "▶", "ready": "●", "waiting": "·"}.get(state, "·")
		var col: String = {"done": "#26622f", "working": "#24409a", "ready": "#7e2418", "waiting": "#6e5a40"}.get(state, "#6e5a40")
		var title := UIKit.rich("[color=%s]%s[/color] [b]%d.[/b] %s" % [col, glyph, si + 1, WorkOrders.stage_title(t, si)], 15)
		title.custom_minimum_size = Vector2(330, 0)
		title.name = "StageTitle_%d_%d" % [tid, si]
		g.add_child(title)
		g.add_child(_stage_who(t, s, here))
		var wh := UIKit.rich(_stage_where(t, s, here), 15)
		wh.custom_minimum_size = Vector2(220, 0)
		g.add_child(wh)
		var mt := UIKit.rich(_stage_mats(t, si), 14)
		mt.custom_minimum_size = Vector2(200, 0)
		g.add_child(mt)
		g.add_child(_stage_assign(t, si, state))
	return g


func _first(name: String) -> String:
	return name.split(" ")[0] if name != "" else "?"


func _stage_who(t: Dictionary, s: Dictionary, here: bool) -> Control:
	var tid := int(t["id"])
	var si := int(s["i"])
	var box := UIKit.hbox(6)
	box.custom_minimum_size = Vector2(250, 0)
	var txt := ""
	var by := str(s.get("by", ""))
	var pin := str(s.get("assignee", ""))
	if str(s["state"]) == "done":
		txt = "by [b]%s[/b] %d%%" % ["you" if by == "player" else _first(str(s.get("by_name", by))), int(round(float(s.get("q", 0.0))))]
	elif here and str(t.get("worker", "")) == "player":
		txt = "[b]you[/b] — at work"
	elif here and str(t.get("worker", "")) != "":
		var a := Apprentices.get_a(str(t["worker"]))
		txt = "[b]%s[/b] (%s) at work" % [_first(str(a.get("name", ""))), Workers.profession_name(Workers.profession(a)).to_lower()]
	elif pin == "player":
		txt = "[color=#7e2418][b]yours[/b][/color]"
	elif pin != "":
		txt = "pinned: [b]%s[/b]" % _first(str(Apprentices.get_a(pin).get("name", pin)))
	else:
		var who := WorkOrders.who_can_stage(t, si).filter(func(x): return str(x) != "player")
		if who.is_empty():
			txt = "[color=#9e3a0c]needs %s[/color]" % Workers.a_noun(str(s.get("profession", "")))
		else:
			txt = "[i]%s[/i]" % ", ".join(PackedStringArray(who.map(func(x): return _first(str(Apprentices.get_a(str(x)).get("name", x))))))
	var l := UIKit.rich(txt, 15)
	l.custom_minimum_size = Vector2(150, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)
	if here and pin == "player" and str(t.get("worker", "")) == "" and not str(t.get("state", "")) in Apprentices.FINISHED:
		var op: Dictionary = Crafting.operations(str(t["recipe"]))[int(t.get("op", 0))]
		var go := UIKit.small_button("Go", func():
			close()
			var why := Smithy.walk_to_station(str(op.get("station", "")))
			if why != "":
				Events.toast.emit(why, "bad"), 56)
		go.name = "GoStage_%d" % tid
		go.tooltip_text = "Walk to %s — your stage begins there (%s)." % [Smithy.station_ref(str(op.get("station", ""))), str(op.get("op", "")).to_lower()]
		box.add_child(go)
	return box


func _stage_where(t: Dictionary, s: Dictionary, here: bool) -> String:
	if str(s["state"]) == "done":
		return "[i]at the %s[/i]" % Property.instance_label(str(s.get("at", ""))).to_lower() if str(s.get("at", "")) != "" else ""
	var ops: Array = s["ops"]
	if here and bool(t.get("started", false)):
		var k := ops.find(int(t.get("op", 0))) + 1
		var at := str(t.get("station", ""))
		if at == "":
			at = str(t.get("at", ""))
		var pct := 0
		if float(t.get("need", 0.0)) > 0.0:
			pct = int(clampf(float(t.get("progress", 0.0)) / float(t["need"]), 0.0, 1.0) * 100.0)
		var where := ("at the " + Property.instance_label(at).to_lower()) if at != "" else ("going to " + Smithy.station_ref(str(Crafting.operations(str(t["recipe"]))[int(t.get("op", 0))].get("station", ""))))
		return "step %d/%d · %d%% · %s" % [k, ops.size(), pct, where]
	return "[i]%d step%s[/i]" % [ops.size(), "" if ops.size() == 1 else "s"]


func _stage_mats(t: Dictionary, si: int) -> String:
	var m := WorkOrders.stage_materials(t, si)
	if m.is_empty():
		return ""
	var tk: Dictionary = t.get("taken", {})
	var parts := PackedStringArray()
	for d in m:
		var nm := str(DB.item(str(d)).get("name", d))
		if int(tk.get(str(d), 0)) > 0:
			parts.append("[color=#26622f]%d %s (in hand)[/color]" % [int(m[d]), nm])
		else:
			var have := Game.count(str(d))
			parts.append("[color=%s]%d/%d %s[/color]" % ["#26622f" if have >= int(m[d]) else "#9e3a0c", mini(have, 999), int(m[d]), nm])
	return ", ".join(parts)


func _stage_assign(t: Dictionary, si: int, state: String) -> Control:
	var tid := int(t["id"])
	var ob := OptionButton.new()
	ob.name = "StageAssign_%d_%d" % [tid, si]
	ob.custom_minimum_size = Vector2(150, 32)
	ob.add_theme_font_size_override("font_size", 15)
	ob.add_item("Auto")
	ob.set_item_metadata(0, "")
	var pin := str(WorkOrders.stages(t)[si].get("assignee", ""))
	var sel := 0
	if WorkOrders.stage_reason("player", t, si) == "":
		ob.add_item("You")
		ob.set_item_metadata(ob.item_count - 1, "player")
		if pin == "player":
			sel = ob.item_count - 1
	for a in Apprentices.staff():
		if WorkOrders.stage_reason(a, t, si) == "":
			ob.add_item(_first(str(a["name"])))
			ob.set_item_metadata(ob.item_count - 1, str(a["id"]))
			if pin == str(a["id"]):
				sel = ob.item_count - 1
	ob.selected = sel
	ob.disabled = state == "done" or (si == WorkOrders.stage_index(t) and str(t.get("worker", "")) == "player")
	ob.tooltip_text = "Who does this stage: automatic (the best free hand who may), a chosen apprentice, or you — you then work it yourself at the station with your own checks."
	ob.item_selected.connect(func(i):
		var err := WorkOrders.assign_stage(tid, si, str(ob.get_item_metadata(i)))
		if err != "":
			Events.toast.emit(err, "bad")
			_queue_build())
	return ob


func _finished_row(t: Dictionary) -> Control:
	var h := UIKit.hbox(8)
	for u in (t.get("made", []) as Array).slice(maxi(0, (t.get("made", []) as Array).size() - 4)):
		var it := ItemStory.find(int(u))
		if not it.is_empty():
			h.add_child(ItemSlot.new(it, 44.0))
	var ok := str(t.get("state", "")) == "done"
	var who := ""
	for a in Apprentices.staff():
		if (t.get("made", []) as Array).size() > 0 and str(a["id"]) == str(t.get("worker", "")):
			who = str(a["name"])
	var l := UIKit.rich("[color=%s]%s[/color] %s%s%s" % ["#26622f" if ok else "#7e2418", "✓" if ok else "✗", str(t.get("label", "")),
		("  [i](%d%%)[/i]" % int(round(float(t.get("last_quality", 0.0))))) if float(t.get("last_quality", 0.0)) > 0.0 else "",
		("  [color=#9e3a0c]%s[/color]" % str(t.get("blocker", ""))) if not ok and str(t.get("blocker", "")) != "" else ""], 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if who != "":
		h.add_child(UIKit.label(who, 15, "body_italic"))
	return h


# ======================================================================= right: add work
func _build_adder() -> void:
	adder.add_child(UIKit.divider())
	var row := UIKit.hbox(6)
	row.add_child(UIKit.label("Add work:", 20, "heading"))
	for k in [["repair", "Repair"], ["commission", "Commission"], ["craft", "Craft"], ["prep", "Prepare materials"], ["maintain", "Upkeep"], ["contract", "Contract hours"]]:
		var key: String = k[0]
		var b := UIKit.button(k[1], func(): add_kind = key; UIKit.clear(adder); _build_adder(), 0)
		b.disabled = add_kind == key
		b.add_theme_font_size_override("font_size", 17)
		row.add_child(b)
	adder.add_child(row)
	if not Apprentices.unlocked():
		adder.add_child(_line(Apprentices.unlock_reason(), 17, "body_italic", ApprenticeUI.BAD))
		return
	match add_kind:
		"repair":
			_add_repair()
		"commission":
			_add_commission()
		"craft", "prep":
			_add_recipe(add_kind)
		"maintain":
			_add_maintain()
		"contract":
			_add_contract()


## The Living Realm: hours on a major contract (the hardest recipe of the order decides who is qualified).
func _add_contract() -> void:
	if Contracts.active().is_empty():
		adder.add_child(_line("No major contract in hand. Patrons' letters arrive by messenger; read them at the Project Bench.", 17, "body_italic"))
		return
	var f := _flow()
	for c in Contracts.active():
		var cid := str(c["id"])
		for h in Contracts.cfg("apprentice_hours", [4, 8, 16]):
			var hrs := int(h)
			var b := UIKit.button("%s — %d h" % [str(c["title"]).left(40), hrs], func(): _add_err(Apprentices.add_task("contract", {"target": cid, "repeat": hrs, "priority": 3})), 0)
			b.add_theme_font_size_override("font_size", 16)
			b.disabled = Contracts.ready(cid)
			b.tooltip_text = "Every piece is made — deliver it at the bench." if Contracts.ready(cid) else "Hours of work at the Project Bench or the order's stations, from the patron's crate first."
			f.add_child(b)
	adder.add_child(_line("Major contracts in hand — queue hours of work (the best qualified hand takes them):", 16, "body_italic"))
	adder.add_child(f)


## A wrapped line for the right column (a wrapping label needs a width before the first layout).
func _line(text: String, size := 17, font := "body", color := UIKit.INK) -> Label:
	var l := UIKit.label(text, size, font, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1060, 0)
	return l


func _add_err(r: Dictionary) -> void:
	if r.has("error"):
		Events.toast.emit(str(r["error"]), "bad")
	else:
		Events.toast.emit("Queued: %s" % str(r.get("label", "")), "good")


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	return f


func _add_repair() -> void:
	var f := _flow()
	var n := 0
	for cu in Apprentices.repair_customers():
		var npc := str(cu.get("npc", ""))
		var t := {"kind": "repair", "target": npc}
		var it := Apprentices.repair_item(t)
		if it.is_empty():
			continue
		n += 1
		var b := UIKit.button("%s's %s" % [Talk.npc_name(npc), Items.display_name(it)], func(): _add_err(Apprentices.add_task("repair", {"target": npc})), 0)
		b.add_theme_font_size_override("font_size", 16)
		f.add_child(b)
	for it in Apprentices.worn_in_stores():
		n += 1
		var uid := int(it["uid"])
		var b2 := UIKit.button("Your %s (%d%%)" % [Items.display_name(it), int(round(Items.durability_frac(it) * 100.0))], func(): _add_err(Apprentices.add_task("repair", {"target": uid, "priority": 1})), 0)
		b2.add_theme_font_size_override("font_size", 16)
		f.add_child(b2)
		if n >= 10:
			break
	if n == 0:
		adder.add_child(_line("Nothing to mend: no customer is waiting with a repair and nothing in your stores is worn.", 17, "body_italic"))
	else:
		adder.add_child(_line("Customers waiting at the counter and worn pieces in your stores — click to queue:", 16, "body_italic"))
		adder.add_child(f)


func _add_commission() -> void:
	var f := _flow()
	var n := 0
	for o in Shop.open_orders():
		var oid := str(o.get("id", ""))
		var queued := Apprentices.open_tasks().any(func(t): return str(t["kind"]) == "commission" and str(t["order_id"]) == oid)
		var b := UIKit.button("%s: %s (%d g, day %d)" % [Talk.npc_name(str(o.get("npc", ""))), Shop.order_text(o), int(o.get("reward", 0)), int(o.get("deadline", 0))],
			func(): _add_err(Apprentices.add_task("commission", {"order_id": oid, "priority": 3})), 0)
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = queued
		var rid := Apprentices.commission_recipe(o, {})
		b.tooltip_text = "Already in the queue." if queued else ("Design: %s. You deliver the finished piece yourself." % str(DB.recipe(rid).get("name", "—")) if rid != "" else "No Design you know meets it yet.")
		f.add_child(b)
		n += 1
	if n == 0:
		adder.add_child(_line("No open commissions.", 17, "body_italic"))
	else:
		adder.add_child(_line("Open commissions — the apprentice makes it; you deliver it from the stores:", 16, "body_italic"))
		adder.add_child(f)


## Recipes any apprentice may make now (and the smith has learned); prep = everything that is not equipment.
static func pickable_recipes(kind: String) -> Array:
	var seen := {}
	var out := []
	for a in Apprentices.staff():
		for r in Apprentices.recipes_for(a):
			var rid := str(r["id"])
			if seen.has(rid):
				continue
			var equip := Items.is_equipment({"def": str(r.get("output", ""))})
			if (kind == "prep" and equip) or (kind == "craft" and not equip):
				continue
			seen[rid] = true
			out.append(r)
	out.sort_custom(func(x, y): return str(x.get("name", "")) < str(y.get("name", "")))
	return out


func _add_recipe(kind: String) -> void:
	var recs := pickable_recipes(kind)
	if recs.is_empty():
		adder.add_child(_line("No apprentice can make any %s yet (their rank, their own skill, or Designs the workshop has not learned)." % ("equipment" if kind == "craft" else "materials, potions or runes"), 17, "body_italic"))
		return
	var row := UIKit.hbox(8)
	var ob := OptionButton.new()
	ob.name = "RecipePick"
	ob.custom_minimum_size = Vector2(420, 42)
	for r in recs:
		var miss := Crafting.missing_inputs(str(r["id"]))
		ob.add_item("%s%s" % [str(r.get("name", r["id"])), "" if miss.is_empty() else "  (missing materials)"])
		ob.set_item_metadata(ob.item_count - 1, str(r["id"]))
	row.add_child(ob)
	row.add_child(UIKit.label("×", 20))
	var rep := SpinBox.new()
	rep.min_value = 1
	rep.max_value = 20
	rep.value = 1
	rep.custom_minimum_size = Vector2(90, 40)
	row.add_child(rep)
	var pri := OptionButton.new()
	for p in [[2, "normal"], [3, "urgent"], [1, "low"]]:
		pri.add_item(str(p[1]), int(p[0]))
	row.add_child(pri)
	var who := OptionButton.new()
	who.add_item("Auto")
	who.set_item_metadata(0, "")
	for a in Apprentices.staff():
		who.add_item(str(a["name"]))
		who.set_item_metadata(who.item_count - 1, str(a["id"]))
	row.add_child(who)
	var info := UIKit.rich("", 15)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var upd := func(_i = 0):
		var rid := str(ob.get_item_metadata(ob.selected))
		var r := DB.recipe(rid)
		var ins: Dictionary = r.get("inputs", {})
		var mm := PackedStringArray()
		for d in ins:
			var need := int(ins[d]) * int(rep.value)
			mm.append("[color=%s]%d/%d %s[/color]" % ["#26622f" if Game.count(str(d)) >= need else "#9e3a0c", Game.count(str(d)), need, str(DB.item(str(d)).get("name", d))])
		var e := Apprentices.estimate({"kind": kind, "recipe": rid, "repeat": int(rep.value), "done": 0, "assignee": str(who.get_item_metadata(who.selected))})
		info.text = "%s · ~%s · expected ~%d%% · %s" % [Crafting.DISCIPLINE_NAME.get(str(r.get("discipline", "classic")), ""), ApprenticeUI.minutes_text(int(e.get("minutes", 0))),
			int(round(float(e.get("quality", 0.0)))), ", ".join(mm)]
	ob.item_selected.connect(upd)
	rep.value_changed.connect(upd)
	who.item_selected.connect(upd)
	row.add_child(UIKit.button("Add to queue", func():
		_add_err(Apprentices.add_task(kind, {"recipe": str(ob.get_item_metadata(ob.selected)), "repeat": int(rep.value),
			"priority": pri.get_item_id(pri.selected), "assignee": str(who.get_item_metadata(who.selected))})), 170))
	adder.add_child(row)
	adder.add_child(info)
	upd.call()


func _add_maintain() -> void:
	var f := _flow()
	var n := 0
	for sid_v in (Property.st()["stations"] as Dictionary).keys():
		var sid := str(sid_v)
		if not Property.is_installed(sid):
			continue
		var cond := Apprentices.station_condition(sid)
		if cond >= 99.5:
			continue
		n += 1
		var b := UIKit.button("%s (%d%%)" % [str(DB.station(sid).get("name", sid)), int(round(cond))], func(): _add_err(Apprentices.add_task("maintain", {"target": sid})), 0)
		b.add_theme_font_size_override("font_size", 16)
		f.add_child(b)
	if n == 0:
		adder.add_child(_line("Every station is in good order. (With automatic assignment on, worn stations are put on the upkeep list each morning.)", 17, "body_italic"))
	else:
		adder.add_child(_line("Stations that have seen use — click to put one on the upkeep list:", 16, "body_italic"))
		adder.add_child(f)
