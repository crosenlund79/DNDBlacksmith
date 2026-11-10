## ContractsPanel — the Project Bench: patrons' letters and the contract view (The Living Realm, milestone 5).
## EN: Opens from the Project Bench ([E]), the Workshop Ledger (Y) and the letter toast. Left: patrons' sealed letters
##     (who writes and WHY — the accomplishments that earned it — the order, terms, Accept / Decline), the contracts in
##     hand, the patrons' standing (which tier is open, what the next needs) and the record of past orders. Right: the
##     selected contract — what to do next first (work a block of 1/2/4 hours, deliver, find a rare material), then
##     the progress bar of hours, units produced per line, craftsmanship so far against the minimum, the deadline,
##     payment and reputation at stake, the patron's crate and the materials still needed, rare materials with the
##     Guide's next step, the masterpiece slot, who has put hours in and the apprentices assigned (assign one here),
##     and the bench's log. 80 % Ink & Parchment, 20 % Gothic Noir (the dark "next step" plate). Fits 1920×1080.
## DA: Projektbænken: mæcenernes breve og kontraktvisningen — timer, stykker, kvalitet, frist, materialer, mesterstykke.
class_name ContractsPanel
extends UIWindow

var sel := ""
var left: VBoxContainer
var right: VBoxContainer
var _pending := false


func _init(args := {}) -> void:
	super._init("The Project Bench — major contracts", 1840, 980)
	sel = str(args.get("id", ""))


func _ready() -> void:
	super._ready()
	var h := UIKit.hbox(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left = UIKit.vbox(8)
	var ls := UIKit.scroll(left, 860)
	ls.custom_minimum_size = Vector2(700, 860)
	h.add_child(ls)
	right = UIKit.vbox(8)
	var rs := UIKit.scroll(right, 860)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rs)
	content.add_child(h)
	Events.orders_changed.connect(_queue_build)
	Events.apprentices_changed.connect(_queue_build)
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
	UIKit.clear(right)
	if sel == "" or Contracts.get_c(sel).is_empty() or str(Contracts.get_c(sel).get("status", "")) in ["declined", "expired"]:
		sel = str(Contracts.active()[0]["id"]) if not Contracts.active().is_empty() else (str(Contracts.offers()[0]["id"]) if not Contracts.offers().is_empty() else "")
	_build_left()
	var c := Contracts.get_c(sel)
	if c.is_empty():
		_build_empty()
	elif str(c["status"]) == "offered":
		_build_offer(c)
	elif str(c["status"]) in Contracts.FINISHED:
		_build_closed(c)
	else:
		_build_contract(c)


func _wrap(text: String, size := 18, font := "body", color := UIKit.INK, w := 660.0) -> Label:
	var l := UIKit.label(text, size, font, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


# ======================================================================= left: letters, contracts, standing, record
func _build_left() -> void:
	if not Contracts.bench_installed():
		var nb := _wrap("No Project Bench in your workshop yet. Buy one under Property & Workshop › Equipment and set it up in a workshop room — major orders are worked there in blocks of hours.", 17, "body_italic", Color("#9e3a0c"))
		left.add_child(nb)
		left.add_child(InkIcons.button("tb_property", "Property & Workshop", func(): close(); Events.open_panel.emit.call_deferred("property", {}), 0))
	left.add_child(InkIcons.heading("icons/recipe_scroll", "Letters from patrons", 26))
	if Contracts.offers().is_empty():
		left.add_child(_wrap("No letter waits. Patrons write rarely — when your work gives them reason to.", 17, "body_italic"))
	for o in Contracts.offers():
		left.add_child(_row(o, "letter"))
	left.add_child(UIKit.divider())
	left.add_child(InkIcons.heading("ui/tb_orders", "Contracts in hand  %d / %d" % [Contracts.active().size(), int(Contracts.cfg("max_active", 2))], 26))
	if Contracts.active().is_empty():
		left.add_child(_wrap("None.", 17, "body_italic"))
	for c in Contracts.active():
		left.add_child(_row(c, "active"))
	left.add_child(UIKit.divider())
	left.add_child(_standing())
	var hist := Contracts.history()
	if not hist.is_empty():
		left.add_child(UIKit.divider())
		left.add_child(UIKit.label("Past orders", 22, "heading"))
		for i in range(hist.size() - 1, maxi(-1, hist.size() - 6), -1):
			var h: Dictionary = hist[i]
			var o := str(h.get("outcome", ""))
			var col := "#26622f" if o in ["excellent", "good"] else "#7e2418"
			left.add_child(UIKit.rich("[color=%s]%s[/color] · %s · [i]%s[/i] · day %d%s" % [col, Contracts.OUTCOME_WORD.get(o, o), str(h["title"]),
				str(Contracts.patron(str(h["patron"])).get("name", "")), int(h.get("closed_day", 0)), (" · %d g" % int(h.get("paid", 0))) if int(h.get("paid", 0)) > 0 else ""], 15))


func _row(c: Dictionary, kind: String) -> Control:
	var card := ApprenticeUI.card(660, Color(0.97, 0.92, 0.80, 0.95) if str(c["id"]) == sel else Color(0.94, 0.89, 0.78, 0.85))
	card.name = "Row_" + str(c["id"])
	var h := UIKit.hbox(10)
	card.add_child(h)
	h.add_child(UIKit.icon("contracts/letter" if kind == "letter" else "contracts/crate_goods", 54))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pn := Contracts.patron_name(str(c["patron"]))
	v.add_child(UIKit.rich("[b]%s[/b]" % str(c["title"]), 17))
	if kind == "letter":
		v.add_child(UIKit.rich("[i]%s[/i] · answer by day %d" % [pn, int(c["expires"])], 15))
	else:
		var left_days := int(c["deadline"]) - Game.day()
		v.add_child(UIKit.rich("[i]%s[/i] · %d/%d pieces · %s" % [pn, int(c["units_done"]), int(c["units_total"]),
			("[color=#9e3a0c]%d days late[/color]" % -left_days) if left_days < 0 else "%d days left" % left_days], 15))
		var pb := UIKit.bar(Contracts.progress(c), 1.0, 400)
		v.add_child(pb)
	h.add_child(v)
	var cid := str(c["id"])
	var b := UIKit.button("Open" if cid != sel else "Shown", func(): sel = cid; build(), 100)
	b.disabled = cid == sel
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return card


func _standing() -> Control:
	var v := UIKit.vbox(3)
	v.add_child(InkIcons.heading("icons/star", "Your standing with patrons", 22))
	var s := Contracts.standing()
	var names := {1: "Merchants & the village muster", 2: "The Watch & the Guild", 3: "Great lords", 4: "The Royal Household"}
	for t in [1, 2, 3, 4]:
		if int(s["tier"]) >= t:
			var r: Array = s["reasons"].get(str(t), [])
			v.add_child(UIKit.rich("[color=#26622f]✓[/color] [b]%s[/b] — [i]%s[/i]" % [names[t], ", ".join(PackedStringArray(r.map(func(x): return str(x))))], 15))
		else:
			v.add_child(UIKit.rich("[color=#8a7a60]○ %s — next: %s[/color]" % [names[t], str(s["missing"].get(str(t), ""))], 15))
			break   # progressive: the next tier only
	return v


# ======================================================================= right: an offer
func _build_empty() -> void:
	right.add_child(UIKit.label("No contract open", 30, "heading"))
	right.add_child(_wrap("Wealthy merchants, the village muster, the Highmarsh Watch, the Merchants' Guild and great lords send letters when your name gives them reason: pieces forged, a good name, orders delivered well, famous work in the Hall of Fame. A letter says why it came. Large orders are not forged piece by piece: you work them here in blocks of hours, and your apprentices can put their hours in too.", 18, "body", UIKit.INK, 1000))


func _terms(c: Dictionary) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 2)
	var rows := [["The order", Contracts.units_text(c)],
		["Craftsmanship", "at least %d%% on average" % int(c["min_q"])],
		["Work", "about %d hours" % int(ceil(float(c["hours_total"])))],
		["Deadline", ("%d days" % int(c["days"])) if str(c["status"]) == "offered" else "day %d" % int(c["deadline"])],
		["Payment", "%d g — %d g advance on accepting, the rest on delivery" % [int(c["pay"]), int(c["advance"])]],
		["At stake", "reputation ±%d and the patron's favour" % int(c["rep"])],
		["The patron sends", Contracts.defs_text(c["crate_sent"])]]
	if not (c["rare"] as Dictionary).is_empty():
		rows.append(["You must find", Contracts.defs_text(c["rare"]) + " (rare)"])
	if not (c["masterpiece"] as Dictionary).is_empty():
		rows.append(["Masterpiece", "%s, forged by your own hand, %d%%+" % [c["masterpiece"]["label"], int(c["masterpiece"]["min_q"])]])
	for r in rows:
		g.add_child(UIKit.label(str(r[0]), 17, "body_bold"))
		var l := UIKit.label(str(r[1]), 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(820, 0)
		g.add_child(l)
	return g


func _build_offer(c: Dictionary) -> void:
	var p := Contracts.patron(str(c["patron"]))
	right.add_child(_header("contracts/letter", str(c["title"]), 28, "A sealed letter from %s" % Contracts.patron_name(str(c["patron"])), 19, UIKit.RUBRIC))
	right.add_child(_wrap(str(c["text"]), 18, "body", UIKit.INK, 1060))
	if str(c.get("why", "")) != "":
		right.add_child(_plate("WHY THIS LETTER CAME", str(c["why"]) + ("  «%s»" % str(p.get("voice", "")) if str(p.get("voice", "")) != "" else "")))
	right.add_child(_terms(c))
	var row := UIKit.hbox(10)
	var cid := str(c["id"])
	var acc := UIKit.button("Accept the order", func():
		var err := Contracts.accept(cid)
		if err != "":
			Events.toast.emit(err, "bad")
		sel = cid
		build(), 240)
	acc.name = "AcceptButton"
	row.add_child(acc)
	row.add_child(UIKit.button("Decline", func():
		Contracts.decline(cid)
		sel = ""
		build(), 140))
	right.add_child(row)
	if not Contracts.bench_installed():
		right.add_child(_wrap("You can accept now; the work itself needs a Project Bench in a workshop room.", 16, "body_italic", Color("#9e3a0c"), 1060))


## The dark plate (the 20 % gothic accent): a caption and a line of text.
func _plate(caption: String, text: String) -> Control:
	var plate := PanelContainer.new()
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
	pv.add_child(UIKit.label(caption, 16, "heading", Color("#e8cc84")))
	var r := UIKit.rich(text, 17, true)
	r.custom_minimum_size = Vector2(1040, 0)
	pv.add_child(r)
	plate.add_child(pv)
	return plate


## The icon-and-title header of the right column. BUG-001 (S2): UIKit.label wraps text longer than 48 characters, so a
## long title ("Forty blades and twenty round shields for the Highmarsh Watch") in a box with no width of its own
## collapsed the whole column to one letter per line — the header now takes the column's width, wrapping by words.
func _header(icon: String, title: String, tsize: int, sub: String, ssize: int, scol: Color, sfont := "body_italic") -> Control:
	var hh := UIKit.hbox(14)
	hh.name = "Header"
	hh.add_child(UIKit.icon(icon, 96))
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UIKit.label(title, tsize, "heading")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(900, 0)
	hv.add_child(t)
	var sl := UIKit.label(sub, ssize, sfont, scol)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(900, 0)
	hv.add_child(sl)
	hh.add_child(hv)
	return hh


# ======================================================================= right: a finished order
func _build_closed(c: Dictionary) -> void:
	var o := str(c.get("outcome", ""))
	var good := o in ["excellent", "good"]
	right.add_child(_header("contracts/crate_goods", str(c["title"]), 26, "%s — %s" % [Contracts.OUTCOME_WORD.get(o, o), Contracts.patron_name(str(c["patron"]))],
		20, Color("#26622f") if good else UIKit.RUBRIC, "body_bold"))
	var lg: Array = c.get("log", [])
	if not lg.is_empty():
		right.add_child(_plate("THE ORDER IS CLOSED", str(lg[-1]["text"])))
	var paid := UIKit.rich("Paid on delivery: [b]%d g[/b] (advance %d g)  ·  Reputation %+d  ·  Craftsmanship %d%%  ·  Hours: %s" % [int(c.get("paid", 0)), int(c["advance"]),
		int(round(float(c.get("rep_change", 0.0)))), int(round(Contracts.quality(c))), " · ".join(PackedStringArray(Contracts.contributors(c).map(func(x): return "%s %.1f h" % [x["name"], float(x["hours"])])))], 17)
	paid.custom_minimum_size = Vector2(1060, 0)   # S2 (BUG-001): the line keeps the column's width even without the plate
	right.add_child(paid)
	var mp: Dictionary = c.get("masterpiece", {})
	if not mp.is_empty() and not (mp.get("item", {}) as Dictionary).is_empty() and o != "failed":
		var h := UIKit.hbox(10)
		var mpi := ItemRegistry.resolve(mp["item"])   # the record refers to the piece kept in the holdings archive
		h.add_child(ItemSlot.new(mpi, 56.0))
		h.add_child(UIKit.label("%s now belongs to %s." % [Items.display_name(mpi), str(Contracts.patron(str(c["patron"])).get("name", ""))], 17, "body_italic"))
		right.add_child(h)
	if good:
		right.add_child(_wrap("Word of the order travels: patrons weigh delivered orders when they decide whom to write to next.", 16, "body_italic", ApprenticeUI.MUTED, 1060))


# ======================================================================= right: a contract in hand
func _build_contract(c: Dictionary) -> void:
	var cid := str(c["id"])
	var hh := UIKit.hbox(14)
	hh.add_child(UIKit.icon("stations/project_bench", 96))
	var hv := UIKit.vbox(2)
	var t := UIKit.label(str(c["title"]), 26, "heading")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(900, 0)
	hv.add_child(t)
	hv.add_child(UIKit.label("For %s" % Contracts.patron_name(str(c["patron"])), 18, "body_italic", UIKit.RUBRIC))
	hh.add_child(hv)
	right.add_child(hh)
	# 1. what to do next (progressive disclosure: the action first)
	right.add_child(_next_plate(c))
	right.add_child(_actions(c))
	# 2. progress
	right.add_child(_progress(c))
	# 3. materials, rare materials, masterpiece
	right.add_child(UIKit.divider())
	right.add_child(_materials(c))
	if not (c["masterpiece"] as Dictionary).is_empty():
		right.add_child(_masterpiece(c))
	# 4. hands at work
	right.add_child(UIKit.divider())
	right.add_child(_workers(c))
	# 5. log & the full terms
	var lg: Array = c.get("log", [])
	if not lg.is_empty():
		right.add_child(UIKit.label("The bench's log", 20, "heading"))
		for e in lg.slice(maxi(0, lg.size() - 4)):
			right.add_child(UIKit.rich("[color=#6e5a40]day %d %s[/color] — %s" % [int(e["day"]), str(e["time"]), str(e["text"])], 15))
	var ab := UIKit.button("Give up the order…", func():
		var err := Contracts.abandon(cid)
		if err != "":
			Events.toast.emit(err, "bad")
		build(), 0)
	ab.tooltip_text = "The patron is displeased: reputation and favour suffer; the advance is returned and the crate goes back."
	ab.add_theme_font_size_override("font_size", 15)
	ab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(ab)


func _next_plate(c: Dictionary) -> Control:
	var cid := str(c["id"])
	var txt := ""
	if Contracts.ready(cid):
		var o := Contracts.outcome_now(c)
		txt = "Every piece is made. Deliver the order: %s — %d g on delivery, reputation %+d." % [str(Contracts.OUTCOME_WORD.get(o["outcome"], "")), int(o["pay"]), int(round(float(o["rep"])))]
		if not bool(o["masterpiece"]):
			txt += " [color=#ffb08a]The masterpiece is not laid in yet (pay is lower without it).[/color]"
	else:
		var why := Contracts.can_work(cid)
		if why == "":
			txt = "Work a block of hours at the bench. Time passes and you tire; your skill sets the pace and the craftsmanship. Apprentices can put their hours in too (below)."
		else:
			txt = why
			var rm := Contracts.rare_missing(c)
			if why.contains("needs") and not rm.is_empty():
				var d := str(rm.keys()[0])
				txt += "\n" + str(Guide.how_to_get(d, int(rm[d]) + Game.count(d)).get("text", ""))
	return _plate("NEXT STEP", txt)


func _actions(c: Dictionary) -> Control:
	var cid := str(c["id"])
	var row := UIKit.hbox(10)
	var why := Contracts.can_work(cid)
	for hrs in Contracts.cfg("blocks", [1, 2, 4]):
		var n := int(hrs)
		var b := InkIcons.button("act_hammer", "Work %d h" % n, func(): _work(cid, n), 150)
		b.name = "Work%dh" % n
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else "Spend %d hour%s at the bench (fatigue +%d)." % [n, "" if n == 1 else "s", int(Contracts._f("fatigue_per_hour", 4.0) * n)]
		row.add_child(b)
	var del := UIKit.button("Deliver the order", func():
		var r := Contracts.deliver(cid)
		if r.has("error") and str(r["error"]) != "":
			Events.toast.emit(str(r["error"]), "bad")
		else:
			Audio.play("sfx/coins", -2.0)
		build(), 220)
	del.name = "DeliverButton"
	del.disabled = not Contracts.ready(cid)
	row.add_child(del)
	var fl := UIKit.label("You: %s (%d%% fatigue)" % [Vitality.band(), int(round(Vitality.fatigue()))], 16, "body_italic")
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	return row


func _work(cid: String, hours: int) -> void:
	var r := Contracts.work(cid, hours)
	if str(r.get("error", "")) != "":
		Events.toast.emit(str(r["error"]), "bad")
		return
	Audio.play("sfx/hammer", -4.0)
	Events.request_fade.emit("%d hour%s at the Project Bench…" % [int(r["hours"]), "" if int(r["hours"]) == 1 else "s"], 0)
	Events.toast.emit("%d h at the bench: %d piece%s finished, ~%d%% craftsmanship." % [int(r["hours"]), int(r["units"]), "" if int(r["units"]) == 1 else "s", int(round(float(r["quality"])))], "info")
	build()


func _progress(c: Dictionary) -> Control:
	var v := UIKit.vbox(4)
	var r1 := UIKit.hbox(10)
	r1.add_child(UIKit.label("Hours", 18, "body_bold"))
	var pb := UIKit.bar(float(c["hours_done"]), float(c["hours_total"]), 560)
	pb.name = "HoursBar"
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(pb)
	r1.add_child(UIKit.label("%.1f / %.1f h" % [float(c["hours_done"]), float(c["hours_total"])], 17))
	v.add_child(r1)
	# units per line, with the piece's icon
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 18)
	for l in c["lines"]:
		var lh := UIKit.hbox(6)
		lh.add_child(UIKit.icon(Items.icon_id({"def": str(l["def"])}), 40))
		lh.add_child(UIKit.label("%d / %d %s" % [Contracts.line_done(c, l), int(l["n"]), Guide.iname(str(l["def"]))], 17, "body_bold"))
		lh.add_child(UIKit.label("(%.2f h each)" % float(l["hpu"]), 15, "body_italic", ApprenticeUI.MUTED))
		g.add_child(lh)
	v.add_child(g)
	# quality against the minimum, deadline, pay
	var q := Contracts.quality(c)
	var qok := q >= float(c["min_q"]) or float(c["q_hours"]) <= 0.0
	var left_days := int(c["deadline"]) - Game.day()
	var o := Contracts.outcome_now(c)
	var pay_txt := "advance %d g paid, %d g more on delivery" % [int(c["advance"]), int(c["pay"]) - int(c["advance"])]
	if float(c["q_hours"]) > 0.0:
		pay_txt += " (as it stands: %s, %d g)" % [str(Contracts.OUTCOME_WORD.get(o["outcome"], "")).to_lower(), int(o["pay"])]
	v.add_child(UIKit.rich("Craftsmanship so far: [b][color=%s]%s[/color][/b] (at least %d%%)  ·  Deadline: [b]day %d[/b] — %s\nPayment: %s  ·  Reputation at stake ±%d" % [
		"#26622f" if qok else "#9e3a0c", ("%d%%" % int(round(q))) if float(c["q_hours"]) > 0.0 else "—", int(c["min_q"]), int(c["deadline"]),
		("[color=#9e3a0c]%d days late[/color]" % -left_days) if left_days < 0 else ("%d days left" % left_days), pay_txt, int(c["rep"])], 16))
	return v


func _materials(c: Dictionary) -> Control:
	var v := UIKit.vbox(4)
	v.add_child(InkIcons.heading("contracts/crate_patron", "Materials", 22))
	v.add_child(UIKit.rich("[b]The patron's crate[/b] (used first): %s" % Contracts.defs_text(c["crate"]), 16))
	var need := Contracts.materials_needed(c)
	if not need.is_empty():
		var mm := PackedStringArray()
		var ks := need.keys()
		ks.sort()
		for d in ks:
			var have := int((c["crate"] as Dictionary).get(d, 0)) + Game.count(str(d))
			mm.append("[color=%s]%d/%d %s[/color]" % ["#26622f" if have >= int(need[d]) else "#9e3a0c", mini(have, 9999), int(need[d]), Guide.iname(str(d))])
		v.add_child(UIKit.rich("[b]Still needed[/b] (crate + your stores): " + ", ".join(mm), 16))
	if not (c["rare"] as Dictionary).is_empty():
		var rm := Contracts.rare_missing(c)
		v.add_child(UIKit.rich("[b]Rare materials[/b] — needed from piece %d on: %s · laid in: %s" % [int(floor(float(c["units_total"]) * Contracts._f("rare_at", 0.5))) + 1,
			Contracts.defs_text(c["rare"]), Contracts.defs_text(c["rare_in"])], 16))
		for d in rm:
			var hs := UIKit.hbox(8)
			var step := Guide.how_to_get(str(d), int(rm[d]) + Game.count(str(d)))
			var l := UIKit.label("%s — %s" % [Guide.iname(str(d)), str(step.get("text", ""))], 15, "body_italic", Color("#8a5a10"))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(840, 0)
			hs.add_child(l)
			var act: Dictionary = step.get("action", {})
			if not act.is_empty() and str(act.get("route", "")) != "":
				var route := str(act["route"])
				var args: Dictionary = act.get("args", {})
				hs.add_child(UIKit.button("Show me", func(): close(); Events.open_panel.emit.call_deferred(route, args), 120))
			v.add_child(hs)
	return v


func _masterpiece(c: Dictionary) -> Control:
	var cid := str(c["id"])
	var mp: Dictionary = c["masterpiece"]
	var v := UIKit.vbox(4)
	v.add_child(InkIcons.heading("icons/star", "The masterpiece: %s" % str(mp["label"]), 22))
	if int(mp.get("uid", -1)) >= 0:
		var h := UIKit.hbox(10)
		h.add_child(ItemSlot.new(mp.get("item", {}), 56.0))
		h.add_child(UIKit.label("Laid into the order: %s (%d%%)." % [Items.display_name(mp.get("item", {})), int(round(float(mp.get("item", {}).get("quality", 0.0))))], 17, "body_bold", Color("#26622f")))
		v.add_child(h)
		return v
	v.add_child(_wrap("Forge it yourself at the stations as usual (one of: %s, at least %d%% craftsmanship), then lay it into the order here." % [
		", ".join(PackedStringArray((mp["defs"] as Array).map(func(d): return Guide.iname(str(d))))), int(mp["min_q"])], 16, "body_italic", UIKit.INK, 1060))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	for it in Contracts.masterpiece_candidates(cid):
		var uid := int(it["uid"])
		var why := Contracts.masterpiece_reason(cid, it)
		var hb := UIKit.hbox(6)
		hb.add_child(ItemSlot.new(it, 48.0))
		var b := UIKit.button("Lay in (%d%%)" % int(round(float(it.get("quality", 0.0)))), func():
			var err := Contracts.lay_in_masterpiece(cid, uid)
			Events.toast.emit(err if err != "" else "The masterpiece waits at the bench with the order.", "bad" if err != "" else "good")
			build(), 0)
		b.disabled = why != ""
		b.tooltip_text = why
		hb.add_child(b)
		f.add_child(hb)
	if f.get_child_count() > 0:
		v.add_child(f)
	return v


func _workers(c: Dictionary) -> Control:
	var cid := str(c["id"])
	var v := UIKit.vbox(4)
	v.add_child(InkIcons.heading("tb_hirelings", "Hands at work", 22))
	var cs := Contracts.contributors(c)
	if cs.is_empty():
		v.add_child(UIKit.label("Nobody has put an hour in yet.", 16, "body_italic"))
	else:
		var parts := PackedStringArray()
		for x in cs:
			parts.append("%s %.1f h" % [str(x["name"]), float(x["hours"])])
		v.add_child(UIKit.rich("Hours so far: " + " · ".join(parts), 16))
	for t in Contracts.tasks_for(cid):
		var w := Apprentices.get_a(str(t.get("worker", "")))
		var who := str(w.get("name", "")) if not w.is_empty() else str(Apprentices.get_a(str(t.get("assignee", ""))).get("name", "an apprentice"))
		var act := str(Apprentices.current(w).get("activity", "")) if not w.is_empty() else ""
		v.add_child(UIKit.rich("▸ [b]%s[/b] — %d of %d h%s%s" % [who, int(t.get("done", 0)), int(t.get("repeat", 1)),
			(" · [i]%s[/i]" % act) if act != "" else "", (" · [color=#9e3a0c]%s[/color]" % str(t["blocker"])) if str(t.get("blocker", "")) != "" else ""], 16))
	if not Apprentices.unlocked() or Apprentices.staff().is_empty():
		v.add_child(_wrap("Apprentices can put their hours in once you have some (notice board › Workshop apprentices).", 15, "body_italic", ApprenticeUI.MUTED, 1060))
		return v
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label("Assign:", 17, "body_bold"))
	var tmp := {"kind": "contract", "recipe": Contracts.main_recipe(cid), "target": cid}
	for a in Apprentices.staff():
		var aid := str(a["id"])
		var e := Apprentices.eligible(a, tmp)
		if e == "" and Contracts.tasks_for(cid).any(func(x): return str(x.get("assignee", "")) == aid):
			e = "%s already has hours on this order." % str(a["name"])
		var hrs: int = int((Contracts.cfg("apprentice_hours", [8]) as Array)[1]) if (Contracts.cfg("apprentice_hours", [8]) as Array).size() > 1 else 8
		var b := UIKit.button("%s (%d h)" % [str(a["name"]).split(" ")[0], hrs], func():
			var r := Apprentices.add_task("contract", {"target": cid, "repeat": hrs, "assignee": aid, "priority": 3})
			Events.toast.emit(str(r["error"]) if r.has("error") else "%s will put %d hours into the order." % [str(a["name"]), hrs], "bad" if r.has("error") else "good")
			build(), 0)
		b.disabled = e != ""
		b.tooltip_text = e if e != "" else "Queue %d hours of contract work for %s (urgent)." % [hrs, str(a["name"])]
		b.add_theme_font_size_override("font_size", 16)
		row.add_child(b)
	v.add_child(row)
	return v
