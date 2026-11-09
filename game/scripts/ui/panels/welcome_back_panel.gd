## WelcomeBackPanel — "While You Were Away": the steward's report on return (Milestone S1, canonical v1.1 §4.5).
## EN: Built only from Steward.report() (deactivate() / take_pending_report() / last_report()): the actual elapsed game
##     time; money from start to end with income and expenses by category (and whether every coin is in the ledger);
##     orders taken on, delivered, declined and pending; production; purchases and sales; stock changes; employee
##     activity; significant world developments; what waits for the smith and what settled without him; the steward's
##     own conduct (decisions and what held it up). Every section links to the real place (the ledger, the workshop
##     ledger, the commissions, the stores, a piece, the Chronicle, the pending matter). Empty sections collapse.
##     Unopened sealed letters show only their envelope here — closing the report brings the sealed-letter popup.
## DA: "Mens du var væk": rapporten ved hjemkomst, kun fra forvalterens optegnelser, regnskabet, Lore og forskellen
##     mellem før og nu. Hver sektion har et link til det rigtige sted; tomme sektioner vises ikke.
class_name WelcomeBackPanel
extends UIWindow

const SEC_W := 700.0

var report: Dictionary
var old := false
var _to_link := false
var sections: Array[String] = []   # the names of the sections shown (tests)


func _init(r: Dictionary = {}, is_old := false) -> void:
	report = r
	old = is_old
	super._init("While You Were Away", 1560, 960)


func _ready() -> void:
	super._ready()
	build()


func build() -> void:
	UIKit.clear(content)
	sections.clear()
	var r := report
	if r.is_empty():
		content.add_child(UIKit.label("There is no report: the steward has not run the forge yet.", 22, "body_italic"))
		content.add_child(UIKit.button("Close", close, 200))
		return
	var fr: Dictionary = r.get("from", {})
	var to: Dictionary = r.get("to", {})
	var how := str(r.get("ended", ""))
	var head := UIKit.rich("[font_size=28][b]%s away[/b][/font_size]   [color=#6e5a40]day %d, %s → day %d, %s%s[/color]" % [str(r.get("elapsed_text", "")),
		int(fr.get("day", 0)), str(fr.get("time", "")), int(to.get("day", 0)), str(to.get("time", "")),
		"  · the steward stood down when the game was closed; nothing happened while it was closed" if how == "closed" else ""], 19)
	head.name = "Elapsed"
	head.custom_minimum_size = Vector2(1480, 0)
	content.add_child(head)
	if old:
		content.add_child(UIKit.label("An earlier report, kept in the steward's book.", 16, "body_italic", Color("#6e5a40")))
	var cols := UIKit.hbox(16)
	var c1 := UIKit.vbox(10)
	var c2 := UIKit.vbox(10)
	cols.add_child(c1)
	cols.add_child(c2)
	var sc := UIKit.scroll(cols, 720)
	sc.name = "ReportScroll"
	content.add_child(sc)
	var left_n := 0
	var right_n := 0
	for s in [_money(r), _matters(r), _orders(r), _production(r), _trade(r), _staff(r), _stock(r), _world(r), _conduct(r)]:
		if s == null:
			continue
		var card: Control = s
		# keep the columns about even: each card goes to the shorter one (estimated by its line count)
		var weight := int(card.get_meta("weight", 4))
		if left_n <= right_n:
			c1.add_child(card)
			left_n += weight
		else:
			c2.add_child(card)
			right_n += weight
	if sections.is_empty():
		c1.add_child(UIKit.label("A quiet spell: nothing of note happened.", 20, "body_italic"))
	var row := UIKit.hbox(12)
	var n_letters := Steward.letters().size()
	var cont := UIKit.button("Back to the forge" + ("  ·  %d sealed letter%s" % [n_letters, "" if n_letters == 1 else "s"] if n_letters > 0 else ""), close, 360)
	cont.name = "Continue"
	row.add_child(cont)
	content.add_child(row)


func close() -> void:
	var letters := not _to_link and not old and not Steward.letters().is_empty()
	super.close()
	if letters:
		Events.open_panel.emit.call_deferred("sealed_letter", {})


## A section card: a heading with its icon, a link to the real place, and its body (null when empty).
func _section(id: String, title: String, icon_id: String, link_text := "", route := "", args := {}) -> VBoxContainer:
	var c := ApprenticeUI.card(SEC_W)
	c.name = "Sec_" + id
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(8)
	var hd := InkIcons.heading(icon_id, title, 23)
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hd)
	if link_text != "":
		h.add_child(_link(link_text, {"route": route, "args": args}))
	v.add_child(h)
	c.add_child(v)
	v.set_meta("card", c)
	sections.append(id)
	return v


func _link(text: String, action: Dictionary) -> Button:
	var b := UIKit.button(text + " ›", func(): _go(action), 0)
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _go(action: Dictionary) -> void:
	_to_link = true
	close()
	StewardUI.go(action)


func _text(parent: Control, bb: String, size := 17) -> RichTextLabel:
	var r := UIKit.rich(bb, size)
	r.custom_minimum_size = Vector2(SEC_W - 40, 0)
	parent.add_child(r)
	return r


func _done(v: VBoxContainer, weight: int) -> Control:
	var c: Control = v.get_meta("card")
	c.set_meta("weight", weight)
	return c


static func _list(items: Array, n := 6) -> String:
	var out := PackedStringArray()
	for i in mini(items.size(), n):
		out.append("• " + str(items[i]))
	if items.size() > n:
		out.append("[i]… and %d more[/i]" % (items.size() - n))
	return "\n".join(out)


# ======================================================================= sections
func _money(r: Dictionary) -> Variant:
	var g: Dictionary = r.get("gold", {})
	if g.is_empty() or (int(g.get("lines", 0)) == 0 and int(g.get("change", 0)) == 0):
		return null
	var v := _section("money", "Money", "tb_ledger", "Ledger", "shop", {"tab": "ledger"})
	var ch := int(g.get("change", 0))
	_text(v, "[font_size=22][b]%d g → %d g[/b][/font_size]  [color=%s][b]%s[/b][/color]   income %d g · expenses %d g" % [int(g.get("start", 0)), int(g.get("end", 0)),
		"#26622f" if ch >= 0 else "#7e2418", StewardUI.signed(ch), int(g.get("income", 0)), int(g.get("expenses", 0))], 18)
	var cats: Dictionary = g.get("by_category", {})
	var keys := cats.keys()
	keys.sort_custom(func(a, b): return absi(int(cats[a])) > absi(int(cats[b])))
	var parts := PackedStringArray()
	for k in keys:
		if int(cats[k]) != 0:
			parts.append("%s [color=%s]%s[/color]" % [str(k), "#26622f" if int(cats[k]) > 0 else "#7e2418", StewardUI.signed(int(cats[k]))])
	if not parts.is_empty():
		_text(v, "By category: " + " · ".join(parts), 16)
	var rec := "Every coin is in the ledger (%d lines)." % int(g.get("lines", 0)) if bool(g.get("reconciled", true)) else "[color=#7e2418]%d g are not explained by ledger lines.[/color]" % int(g.get("unexplained", 0))
	_text(v, "[i]%s The steward spent %d g on materials.[/i]" % [rec, int(g.get("steward_spent", 0))], 15)
	return _done(v, 4)


func _orders(r: Dictionary) -> Variant:
	var o: Dictionary = r.get("orders", {})
	var cn: Dictionary = o.get("counts", {})
	if int(cn.get("accepted", 0)) + int(cn.get("delivered", 0)) + int(cn.get("declined", 0)) + int(cn.get("pending", 0)) == 0:
		return null
	var v := _section("orders", "Orders", "tb_orders", "Commissions", "orders")
	_text(v, "Taken on [b]%d[/b] · delivered [b]%d[/b] · declined [b]%d[/b] · open now [b]%d[/b]" % [int(cn.get("accepted", 0)), int(cn.get("delivered", 0)),
		int(cn.get("declined", 0)), int(cn.get("pending", 0))], 18)
	var w := 2
	if not (o.get("delivered", []) as Array).is_empty():
		_text(v, "[b]Delivered[/b]\n" + _list(o["delivered"], 5), 16)
		w += 2
	if not (o.get("accepted", []) as Array).is_empty():
		_text(v, "[b]Taken on[/b]\n" + _list(o["accepted"], 4), 16)
		w += 2
	var pend: Array = o.get("pending", [])
	if not pend.is_empty():
		var pl: Array = []
		for p in pend:
			pl.append("%s — by day %d [color=#6e5a40](%s)[/color]" % [str(p.get("text", "")), int(p.get("deadline", 0)), str(p.get("state", ""))])
		_text(v, "[b]Still open[/b]\n" + _list(pl, 5), 16)
		w += 2
	if not (o.get("declined", []) as Array).is_empty():
		_text(v, "[color=#6e5a40]Declined: %s[/color]" % "; ".join(PackedStringArray((o["declined"] as Array).slice(0, 3))) + (" …" if (o["declined"] as Array).size() > 3 else ""), 15)
		w += 1
	return _done(v, w)


func _production(r: Dictionary) -> Variant:
	var p: Dictionary = r.get("production", {})
	var comp: Dictionary = p.get("completed", {})
	if comp.is_empty() and int(p.get("made_count", 0)) == 0 and int(p.get("failed", 0)) == 0 and (p.get("materials", {}) as Dictionary).is_empty():
		return null
	var v := _section("production", "Production", "ic_work", "Workshop Ledger", "workshop")
	var parts := PackedStringArray()
	for k in comp:
		parts.append("%d %s" % [int(comp[k]), str(StewardUI.COMPLETED_NAME.get(str(k), str(k)))])
	if not parts.is_empty():
		_text(v, "Your apprentices finished " + ", ".join(parts) + ".", 17)
	var made: Array = p.get("made", [])
	if not made.is_empty():
		var row := HFlowContainer.new()
		row.custom_minimum_size = Vector2(SEC_W - 40, 0)
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 4)
		for i in range(made.size() - 1, maxi(-1, made.size() - 9), -1):
			var m: Dictionary = made[i]
			var uid := int(m.get("uid", -1))
			if str(m.get("where", "")) != "":
				row.add_child(_link(str(m.get("name", "")), {"route": "item", "args": {"uid": uid}}))
			else:
				row.add_child(UIKit.label(str(m.get("name", "")), 16, "body_italic"))
		v.add_child(row)
		if made.size() > 8:
			_text(v, "[i]%d pieces in all.[/i]" % int(p.get("made_count", made.size())), 15)
	var mats: Dictionary = p.get("materials", {})
	if not mats.is_empty():
		var ml := PackedStringArray()
		for d in mats:
			ml.append("%s ×%d" % [str(DB.item(str(d)).get("name", d)), int(mats[d].get("qty", mats[d].get("n", 0)))])
		_text(v, "Prepared: " + ", ".join(ml), 16)
	if int(p.get("failed", 0)) > 0:
		var why := PackedStringArray()
		for k2 in p.get("failed_why", {}):
			why.append("%s ×%d" % [str(k2), int(p["failed_why"][k2])])
		_text(v, "[color=#7e2418]%d task%s failed%s.[/color]" % [int(p["failed"]), "" if int(p["failed"]) == 1 else "s", (" (" + ", ".join(why) + ")") if not why.is_empty() else ""], 16)
	if int(p.get("smith_crafted", 0)) == 0:
		_text(v, "[i]You made nothing yourself — you were away (no crafting experience gained).[/i]", 15)
	return _done(v, 5)


func _trade(r: Dictionary) -> Variant:
	var pu: Dictionary = r.get("purchases", {})
	var sa: Dictionary = r.get("sales", {})
	var items: Array = pu.get("items", [])
	if items.is_empty() and int(sa.get("count", 0)) == 0 and int(sa.get("listed", 0)) == 0 and int(sa.get("ledger_sales", 0)) == 0:
		return null
	var v := _section("trade", "Purchases & sales", "story_sale", "Your stores", "inventory")
	var w := 1
	if not items.is_empty():
		var bl: Array = []
		for b in items:
			bl.append("%s ×%d — %d g" % [str(b.get("name", "")), int(b.get("qty", 0)), int(b.get("cost", 0))])
		_text(v, "[b]Bought at the village counters: %d g[/b]\n%s" % [int(pu.get("total", 0)), _list(bl, 5)], 16)
		w += 2
	var sl := PackedStringArray()
	if int(sa.get("count", 0)) > 0:
		sl.append("the steward sold [b]%d[/b] piece%s for %d g" % [int(sa["count"]), "" if int(sa["count"]) == 1 else "s", int(sa.get("gold", 0))])
	if int(sa.get("listed", 0)) > 0:
		sl.append("put %d on display" % int(sa["listed"]))
	if int(sa.get("ledger_sales", 0)) != 0:
		sl.append("all sales in the ledger %d g" % int(sa["ledger_sales"]))
	if not sl.is_empty():
		var line := ", ".join(sl)
		_text(v, line.left(1).to_upper() + line.substr(1) + ".", 17)
	var rec: Array = sa.get("recent", [])
	if not rec.is_empty():
		var rl: Array = []
		for x in rec:
			rl.append("%s to %s for %d g (day %d)" % [str(x.get("name", "")), Talk.npc_name(str(x.get("npc", ""))), int(x.get("price", 0)), int(x.get("day", 0))])
		rl.reverse()
		_text(v, _list(rl, 4), 16)
		w += 2
	return _done(v, w)


func _stock(r: Dictionary) -> Variant:
	var st: Array = r.get("stock", [])
	if st.is_empty():
		return null
	var v := _section("stock", "Stock changes", "tb_inventory", "Your stores", "inventory")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	var sorted := st.duplicate()
	sorted.sort_custom(func(a, b): return absi(int(a["change"])) > absi(int(b["change"])))
	for i in mini(sorted.size(), 12):
		var x: Dictionary = sorted[i]
		var ch := int(x.get("change", 0))
		var l := UIKit.rich("%s  [color=#6e5a40]%d → %d[/color] [color=%s][b]%s%d[/b][/color]" % [str(x.get("name", "")), int(x.get("before", 0)), int(x.get("after", 0)),
			"#26622f" if ch > 0 else "#7e2418", "+" if ch > 0 else "", ch], 16)
		l.custom_minimum_size = Vector2(320, 0)
		grid.add_child(l)
	v.add_child(grid)
	if sorted.size() > 12:
		_text(v, "[i]… and %d more kinds[/i]" % (sorted.size() - 12), 15)
	return _done(v, 2 + int(mini(sorted.size(), 12) / 2))


func _staff(r: Dictionary) -> Variant:
	var s: Dictionary = r.get("staff", {})
	var cur: Array = s.get("current", [])
	var left: Array = s.get("left", [])
	if cur.is_empty() and left.is_empty():
		return null
	var v := _section("staff", "Your people", "tb_hirelings", "Workshop Ledger", "workshop")
	for a in cur:
		var rank := str(a.get("rank_name", a.get("rank", "")))
		var up := str(a.get("rank_before", "")) != "" and str(a.get("rank_before", "")) != str(a.get("rank", ""))
		var bits := PackedStringArray()
		bits.append("%d piece%s of work finished" % [int(a.get("works", 0)), "" if int(a.get("works", 0)) == 1 else "s"])
		if up:
			bits.append("[color=#26622f]rose to %s[/color]" % rank)
		if bool(a.get("joined", false)):
			bits.append("joined while you were away")
		if str(a.get("notice", "")) != "":
			bits.append("[color=#7e2418]has given notice (%s)[/color]" % str(a["notice"]))
		_text(v, "[b]%s[/b], %s — %s" % [str(a.get("name", "")), rank, ", ".join(bits)], 16)
	for lf in left:
		_text(v, "[color=#7e2418]%s left on day %d (%s).[/color]" % [Talk.npc_name(str(lf.get("id", ""))), int(lf.get("day", 0)), str(lf.get("how", ""))], 16)
	return _done(v, 1 + cur.size() + left.size())


func _world(r: Dictionary) -> Variant:
	var w: Dictionary = r.get("world", {})
	var ev: Array = w.get("events", [])
	if ev.is_empty():
		return null
	var v := _section("world", "In the wider world", "ic_history", "Chronicle", "wanted", {"tab": "legends"})
	for i in range(ev.size() - 1, maxi(-1, ev.size() - 7), -1):
		var e: Dictionary = ev[i]
		var h := UIKit.hbox(6)
		var t := UIKit.rich("[color=#6e5a40]day %d[/color] %s" % [int(e.get("day", 0)), str(e.get("text", ""))], 16)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var lk := StewardUI.world_link(str(e.get("id", "")))
		if str(lk.get("route", "")) != "wanted":
			h.add_child(_link("See", lk))
		v.add_child(h)
	if int(w.get("count", 0)) > 6:
		_text(v, "[i]%d events in all.[/i]" % int(w["count"]), 15)
	return _done(v, 1 + mini(ev.size(), 6))


func _matters(r: Dictionary) -> Variant:
	var d: Array = r.get("deferred", [])
	var lapsed: Array = r.get("lapsed", [])
	if d.is_empty() and lapsed.is_empty():
		return null
	var v := _section("matters", "Waiting for you", "story_note", "All matters", "steward", {"tab": "matters"})
	# the report's list is the state at return; what the smith has seen to since is not shown again
	var live := {}
	for e0 in Steward.deferred():
		live[str(e0["id"])] = e0
	var n := 0
	for e in d:
		var id := str(e.get("id", ""))
		if not live.has(id):
			continue
		n += 1
		if n > 6:
			continue
		var full: Dictionary = live[id]
		var sealed := bool(full.get("sealed", false)) and not bool(full.get("opened", false))
		var h := UIKit.hbox(6)
		var t := UIKit.rich("[color=#7e2418][b]%s[/b][/color] %s" % [StewardUI.kind_name(str(e.get("kind", ""))),
			("— a sealed letter from %s, unopened" % StewardUI.sender(full)) if sealed else str(e.get("text", ""))], 16)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		if sealed:
			var b := UIKit.button("Open ›", func(): _to_link = true; close(); Events.open_panel.emit.call_deferred("sealed_letter", {"id": id}), 0)
			b.add_theme_font_size_override("font_size", 16)
			b.custom_minimum_size = Vector2(0, 34)
			h.add_child(b)
		elif str(full.get("action", {}).get("route", "")) != "":
			var b2 := UIKit.button("Go to it ›", func(): _to_link = true; close(); StewardUI.follow(id), 0)
			b2.add_theme_font_size_override("font_size", 16)
			b2.custom_minimum_size = Vector2(0, 34)
			h.add_child(b2)
		v.add_child(h)
	if n > 6:
		_text(v, "[i]… and %d more (All matters).[/i]" % (n - 6), 15)
	if n == 0 and not d.is_empty():
		_text(v, "[i]You have seen to everything the steward left for you.[/i]", 16)
	if not lapsed.is_empty():
		var ll: Array = []
		for x in lapsed:
			ll.append("%s — [i]%s[/i]" % [str(x.get("text", "")).left(90), str(x.get("outcome", ""))])
		_text(v, "[color=#6e5a40][b]Settled without you[/b] (%d)\n%s[/color]" % [lapsed.size(), _list(ll, 3)], 15)
	return _done(v, 2 + mini(n, 6) + mini(lapsed.size(), 3))


func _conduct(r: Dictionary) -> Variant:
	var dc: Dictionary = r.get("decisions", {})
	var bk: Dictionary = dc.get("by_kind", {})
	var stalls: Array = dc.get("stalls", [])
	if int(dc.get("total", 0)) == 0 and stalls.is_empty():
		return null
	var v := _section("conduct", "The steward's book", "story_note")
	var keys := bk.keys()
	keys.sort_custom(func(a, b): return int(bk[a]) > int(bk[b]))
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s %d" % [str(k).replace("_", " "), int(bk[k])])
	_text(v, "[b]%d decisions[/b]%s" % [int(dc.get("total", 0)), (": " + ", ".join(parts)) if not parts.is_empty() else ""], 16)
	if not stalls.is_empty():
		var sl: Array = []
		for s in stalls:
			sl.append("%s ×%d — %s" % [str(Steward.DUTY_NAME.get(str(s.get("duty", "")), s.get("code", ""))), int(s.get("count", 0)), str(s.get("text", ""))])
		_text(v, "[color=#9e3a0c][b]What held it up[/b]\n%s[/color]" % _list(sl, 4), 15)
	return _done(v, 2 + mini(stalls.size(), 4))
