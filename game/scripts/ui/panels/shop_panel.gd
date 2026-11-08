## ShopPanel — the counter: waiting customers, stock on display, the business ledger and upgrades.
## DA: Disken: ventende kunder, udstillede varer, regnskabet og værkstedsopgraderinger.
class_name ShopPanel
extends UIWindow

var tab := "customers"
var npc_focus := ""
var body: VBoxContainer


func _init(t := "customers", npc := "") -> void:
	tab = t
	npc_focus = npc
	super._init("The Shop Counter", 1320, 780)


func _ready() -> void:
	super._ready()
	var tabs := UIKit.hbox(8)
	for t in [["customers", "Customers & Offers"], ["stock", "Stock on Display"], ["ledger", "Ledger & Upgrades"]]:
		var key: String = t[0]
		tabs.add_child(UIKit.button(t[1], func(): tab = key; _build(), 0))
	content.add_child(tabs)
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 600))
	Events.inventory_changed.connect(_build)
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	UIKit.clear(body)
	match tab:
		"customers": _customers()
		"stock": _stock()
		"ledger": _ledger()


func _customers() -> void:
	_offers()
	var people := []
	for c in Shop.waiting():
		people.append(c["npc"])
	if npc_focus != "" and not people.has(npc_focus):
		people.push_front(npc_focus)
	if people.is_empty():
		body.add_child(UIKit.label("Nobody is waiting outside. Customers come during opening hours (9:00–18:00) and take a seat by the door; adventurers in town often drop by.", 22, "body_italic"))
		return
	body.add_child(UIKit.label("Waiting at the shop (%d of %d seats)" % [Shop.waiting().size(), Shop.SEATS], 26, "heading"))
	for npc in people:
		var row := UIKit.hbox(16)
		row.add_child(UIKit.portrait("portraits/" + npc, 112))
		var v := UIKit.vbox(8)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := Adv.get_a(npc)
		var cu := Shop.customer(npc)
		var waiting: bool = not cu.is_empty() and cu.get("present", true)
		# the explicit request card: what they want, attributes, materials, budget and reward
		var req := Shop.request(cu if not cu.is_empty() else {"npc": npc, "want": "browse"})
		var who := UIKit.rich("[b]%s[/b]%s" % [Talk.npc_name(npc), (" · %s %s, level %d · %d gold" % [Adv.rating_text(a), a["cls"], a["level"], a["gold"]]) if not a.is_empty() else ""], 21)
		v.add_child(who)
		v.add_child(CustomerCard.build(req))
		var actions := HFlowContainer.new()
		actions.add_theme_constant_override("h_separation", 8)
		actions.add_theme_constant_override("v_separation", 6)
		if cu.get("want", "") == "multi":
			_multi_parts(v, cu, npc)
		elif cu.get("want", "") == "repair":
			actions.add_child(UIKit.button("Take the job — to the grinding wheel", func(): _repair(npc), 360))
			var rit: Dictionary = cu.get("item", {})
			if cu.has("own_slot"):
				rit = a.get("equipment", {}).get(str(cu["own_slot"]), rit)
			if Items.is_equipment(rit):
				var ruid := int(rit.get("uid", -1))
				actions.add_child(UIKit.button("Inspect the piece", func(): Events.open_panel.emit("item", {"uid": ruid}), 0))
				if waiting:
					(func(): ItemStory.at_counter(npc)).call_deferred()   # "A Familiar Creation" — once per reunion
		elif cu.get("want", "") == "goods":
			var anyg := false
			for it in Game.inventory():
				if DB.item(it["def"]).get("type", "") == "potion" and it["def"] != "ale_mug":
					var b2 := UIKit.button("%s — %d g" % [Items.display_name(it), Shop.price_of(it) / maxi(1, int(it.get("qty", 1)))], func():
						var err2 := Shop.sell_goods(npc, int(it["uid"]))
						Events.toast.emit(err2 if err2 != "" else "%s pays and leaves happy." % Talk.npc_name(npc), "bad" if err2 != "" else "good")
						_build(), 0)
					actions.add_child(b2)
					anyg = true
			if not anyg:
				actions.add_child(UIKit.label("You have no draughts or oils to sell.", 20, "body_italic"))
		elif cu.get("want", "") == "dispute":
			actions.add_child(UIKit.label("Talk to them outside to settle it.", 20, "body_italic"))
		elif not a.is_empty():
			var married: bool = Social.spouse() == npc
			var any := false
			for it in Game.inventory():
				if not Items.is_equipment(it) or (not it.get("for_sale", false) and not married):
					continue
				var why := Adv.purchase_check(a, it, Shop.price_of(it))
				var fits: bool = Items.slot(it) == str(req.get("slot", "")) and Items.stat(it, str(req.get("stat", ""))) >= int(req.get("min", 0))
				var b := UIKit.button("%s%s — %s" % ["✓ " if fits and why == "" else "", Items.display_name(it), "free" if married else "%d g" % Shop.price_of(it)], func():
					var err := Shop.sell_to(npc, int(it["uid"]))
					Events.toast.emit(err if err != "" else "%s takes %s." % [a["name"], ("the " + str(it["name"])) if not str(it["name"]).contains(",") else str(it["name"])], "bad" if err != "" else "good")
					_build(), 0)
				b.disabled = why != ""
				b.tooltip_text = why if why != "" else ("Matches the request." if fits else "")
				b.add_theme_color_override("font_color", Items.color(it, false))
				actions.add_child(b)
				any = true
			if not any:
				actions.add_child(UIKit.label("Nothing on display suits them. Put equipment on display from your stores [I].", 20, "body_italic"))
		if waiting and cu.get("want", "") != "dispute":
			var dis := UIKit.button("Ask them to come back another time", func():
				Shop.dismiss_customer(npc)
				Events.toast.emit("%s gets up from the bench and heads off." % Talk.npc_name(npc), "info")
				if npc_focus == npc:
					npc_focus = ""
				_build(), 0)
			dis.tooltip_text = "Frees their seat; they don't mind much."
			actions.add_child(dis)
		v.add_child(actions)
		row.add_child(v)
		body.add_child(row)
		body.add_child(UIKit.divider())


## Finds brought home from expeditions, offered to the forge (they go elsewhere after three days).
func _offers() -> void:
	var offs := Shop.offers()
	if offs.is_empty():
		return
	body.add_child(UIKit.label("Offered by returning adventurers", 26, "heading"))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	for o in offs:
		var it: Dictionary = o["item"]
		var a := Adv.get_a(str(o["from"]))
		var col := UIKit.vbox(3)
		col.custom_minimum_size = Vector2(250, 0)
		col.add_child(ItemSlot.new(it, 64.0))
		col.add_child(UIKit.rich("[b]%s[/b]\nfrom %s · %s · %d day%s left" % [Items.display_name(it), a.get("name", "?"), "free" if int(o["price"]) == 0 else "%d g" % int(o["price"]),
			3 - (Game.day() - int(o["day"])), "" if 3 - (Game.day() - int(o["day"])) == 1 else "s"], 17))
		var h := UIKit.hbox(6)
		var oid: String = o["id"]
		h.add_child(UIKit.button("Buy", func():
			var err := Shop.accept_offer(oid)
			Events.toast.emit(err if err != "" else "Bought — it is in your stores.", "bad" if err != "" else "good")
			_build(), 110))
		h.add_child(UIKit.button("Decline", func(): Shop.decline_offer(oid); _build(), 110))
		if Items.is_equipment(it):
			var ouid := int(it["uid"])
			h.add_child(UIKit.button("Inspect", func(): Events.open_panel.emit("item", {"uid": ouid}), 110))
			var ofrom := str(o["from"])
			(func(): ItemStory.present(it, "offer", ofrom)).call_deferred()   # your own work among the finds
		col.add_child(h)
		grid.add_child(col)
	body.add_child(grid)
	body.add_child(UIKit.divider())


## A multi-order: every part on its own card with availability and its own Accept / Decline / Repair.
func _multi_parts(v: VBoxContainer, cu: Dictionary, npc: String) -> void:
	v.add_child(UIKit.label("Take on what you can — each part can be accepted or declined on its own.", 19, "body_italic"))
	for pt in cu.get("parts", []):
		var pid := str(pt.get("pid", ""))
		var r := Shop.part_request(cu, pt)
		var row := UIKit.hbox(10)
		var card := CustomerCard.build(r)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var bx := UIKit.vbox(6)
		bx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if str(pt.get("status", "pending")) == "pending":
			if str(pt.get("kind", "")) == "repair":
				var rb := UIKit.button("Repair it", func(): _repair_part(npc, pid), 200)
				rb.disabled = not bool(r.get("available", true))
				bx.add_child(rb)
			else:
				var ab := UIKit.button("Accept", func():
					var err := Shop.accept_part(npc, pid)
					if err != "":
						Events.toast.emit(err, "bad")
					_build(), 200)
				ab.tooltip_text = "Becomes a commission: deliver it by the deadline." + ("" if bool(r.get("available", true)) else "\nYou cannot make it yet — %s." % r.get("why", ""))
				bx.add_child(ab)
			bx.add_child(UIKit.button("Decline", func():
				Shop.decline_part(npc, pid)
				_build(), 200))
		row.add_child(bx)
		v.add_child(row)


func _repair_part(npc: String, pid: String) -> void:
	var c := Crafting.check_params("grinding_wheel")
	Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Repair at the grinding wheel",
		"on_done": func(qs: Array):
			Shop.repair_part(npc, pid, float(qs[0]))
			Events.toast.emit("Repair done (%d%%)." % int(qs[0]), "good")})


func _repair(npc: String) -> void:
	var c := Crafting.check_params("grinding_wheel")
	Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Repair at the grinding wheel",
		"on_done": _on_repair_done.bind(npc)})


func _on_repair_done(qs: Array, npc: String) -> void:
	Shop.do_repair(npc, float(qs[0]))
	Events.toast.emit("Repair done (%d%%)." % int(qs[0]), "good")


func _stock() -> void:
	body.add_child(UIKit.label("Click an item to toggle whether it is on display. Displayed items show a coin.", 20, "body_italic"))
	var grid := GridContainer.new()
	grid.columns = 14
	for it in Game.inventory():
		if not Items.is_equipment(it):
			continue
		var s := ItemSlot.new(it, 72.0)
		s.clicked.connect(func(x):
			x["for_sale"] = not x.get("for_sale", false)
			Events.inventory_changed.emit())
		grid.add_child(s)
	body.add_child(grid)


## The ledger: sub-tabs Summary (status of the business), Accounts (income and expenses by category for
## today, the week and everything recorded), Journal (entries and recent transactions) and Upgrades.
var ledger_tab := "summary"

const LEDGER_CAT := {
	"sales": ["Sales", "icons/sword_steel"], "repairs": ["Repairs", "ui/tb_designer"], "commissions": ["Commissions", "ui/tb_orders"],
	"inn": ["The inn", "icons/ale_mug"], "materials": ["Materials", "icons/ingot_iron"], "trade": ["Trade", "icons/shipment_miner"],
	"wages": ["Wages & fees", "ui/tb_hirelings"], "upkeep": ["Upkeep", "ui/tb_property"], "upgrades": ["Upgrades", "icons/star"],
	"refunds": ["Refunds", "icons/purse_gift"], "family": ["Household", "icons/bread_cheese"],
}


func _ledger() -> void:
	var row := UIKit.hbox(8)
	for t in [["summary", "Summary"], ["accounts", "Accounts"], ["journal", "Journal"], ["upgrades", "Upgrades"]]:
		var key: String = t[0]
		var b := UIKit.button(("❧ " if key == ledger_tab else "") + str(t[1]), func(): ledger_tab = key; _build(), 170)
		if key == ledger_tab:
			b.add_theme_color_override("font_color", UIKit.RUBRIC)
			b.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
		row.add_child(b)
	body.add_child(row)
	body.add_child(UIKit.divider())
	match ledger_tab:
		"summary": _ledger_summary()
		"accounts": _ledger_accounts()
		"journal": _ledger_journal()
		_: _ledger_upgrades()


static func _cat_info(cat: String) -> Array:
	return LEDGER_CAT.get(cat, [cat.capitalize(), "icons/gold"])


## Gold held at the end of each of the last `n` days (rebuilt backwards from the purse and the ledger).
static func _balance_series(n := 7) -> Array:
	var out := []
	var today := Game.day()
	for i in range(mini(n - 1, today), -1, -1):
		var d := today - i
		var after := 0
		for e in Game.state["ledger"]:
			if int(e["day"]) > d:
				after += int(e["amount"])
		out.append([d, Game.gold() - after])
	return out


func _ledger_summary() -> void:
	var series := _balance_series(7)
	var first: int = series[0][1]
	var delta := Game.gold() - first
	var top := UIKit.hbox(24)
	var purse := UIKit.vbox(2)
	purse.custom_minimum_size = Vector2(380, 0)
	purse.add_child(UIKit.label("Purse", 22, "heading_italic", UIKit.RUBRIC))
	var ph := UIKit.hbox(8)
	ph.add_child(UIKit.icon("icons/gold", 44))
	ph.add_child(UIKit.label("%d gold" % Game.gold(), 40, "title"))
	purse.add_child(ph)
	var trend := "steady"
	if delta > 0:
		trend = "rising — %+d g this week" % delta
	elif delta < 0:
		trend = "falling — %+d g this week" % delta
	purse.add_child(UIKit.rich("Trend: [color=%s][b]%s[/b][/color]" % ["#26622f" if delta >= 0 else "#9e3a0c", trend], 20))
	purse.add_child(UIKit.rich("Standing in Brindlewick: [i]%s[/i]" % Shop.reputation_word(), 20))
	top.add_child(purse)
	top.add_child(_sparkline(series))
	body.add_child(top)
	body.add_child(UIKit.divider())
	# status cards
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var open := Shop.open_orders()
	var ready := 0
	for o in open:
		for it in Game.inventory():
			if Items.is_equipment(it) and Shop.item_meets(o, it):
				ready += 1
				break
	grid.add_child(_card("ui/tb_orders", "Open commissions", str(open.size()),
		("%d ready to deliver" % ready) if ready > 0 else ("none ready yet" if not open.is_empty() else "ask adventurers what they need"),
		"Commissions", func(): Events.open_panel.emit("orders", {})))
	var offs := Shop.offers()
	grid.add_child(_card("icons/package_reward", "Offers waiting", str(offs.size()), "finds from returning adventurers" if not offs.is_empty() else "nothing offered right now",
		"See offers", func(): tab = "customers"; _build()))
	var waiting := Shop.waiting().size()
	grid.add_child(_card("ui/tb_adventurers", "Customers outside", str(waiting), "seated by the shop door" if waiting > 0 else "the bench is empty",
		"Counter", func(): tab = "customers"; _build()))
	var wages := 0
	for h in Hire.list():
		if str(h.get("status", "")) != "dead":
			wages += int(h.get("wage", 0))
	wages = int(round(wages * float(Expeditions.diff().get("wages", 1.0))))
	var upkeep: int = Shop.UPKEEP + Game.state.get("upgrades", []).size()
	grid.add_child(_card("ui/tb_hirelings", "Due each morning", "%d g" % (wages + upkeep), "wages %d g · upkeep %d g" % [wages, upkeep],
		"Hirelings", func(): Events.open_panel.emit("hirelings", {})))
	var away_h := 0
	for h in Hire.list():
		if str(h.get("status", "")) == "away":
			away_h += 1
	var parties := Expeditions.active().size()
	grid.add_child(_card("ui/tb_map", "Expeditions out", str(parties + away_h), "%d adventuring part%s · %d hireling%s away" % [parties, "y" if parties == 1 else "ies", away_h, "" if away_h == 1 else "s"],
		"Adventurers", func(): Events.open_panel.emit("adventurers", {})))
	var stt: Dictionary = Game.state["stats"]
	grid.add_child(_card("icons/star", "Work of your hands", "%d" % int(stt["crafted"]), "crafted · %d sold · %d legendary" % [int(stt["sold"]), int(stt["legendaries"])], "", Callable()))
	body.add_child(grid)


func _card(icon: String, title: String, value: String, sub: String, btn: String, cb: Callable) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.9, 0.78, 0.55)
	sb.border_color = Color("#20140c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(404, 0)
	var h := UIKit.hbox(12)
	h.add_child(UIKit.icon(icon, 60))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := UIKit.hbox(10)
	tr.add_child(UIKit.label(value, 30, "title"))
	var tl := UIKit.label(title, 19, "heading_italic", UIKit.RUBRIC)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(tl)
	v.add_child(tr)
	v.add_child(UIKit.label(sub, 17, "body_italic"))
	if btn != "":
		var b := UIKit.button(btn, cb, 0)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
	h.add_child(v)
	p.add_child(h)
	return p


func _sparkline(series: Array) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(760, 160)
	c.draw.connect(func():
		var lo := 1e9
		var hi := -1e9
		for s in series:
			lo = minf(lo, float(s[1]))
			hi = maxf(hi, float(s[1]))
		if hi - lo < 10.0:
			hi = lo + 10.0
		var sz := c.size
		var x0 := 50.0
		var w := sz.x - x0 - 16.0
		var y0 := 16.0
		var hgt := sz.y - 46.0
		c.draw_rect(Rect2(x0, y0, w, hgt), Color(1, 1, 1, 0.12))
		c.draw_rect(Rect2(x0, y0, w, hgt), Color("#20140c"), false, 1.5)
		var f := Assets.font("body")
		var pts := PackedVector2Array()
		for i in series.size():
			var px := x0 + w * (float(i) / maxf(1.0, series.size() - 1.0))
			var py := y0 + hgt * (1.0 - (float(series[i][1]) - lo) / (hi - lo))
			pts.append(Vector2(px, py))
			c.draw_string(f, Vector2(px - 14, sz.y - 10), ("Day %d" % int(series[i][0])) if int(series[i][0]) > 0 else "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5e421c"))
		var poly := pts.duplicate()
		poly.append(Vector2(x0 + w, y0 + hgt))
		poly.append(Vector2(x0, y0 + hgt))
		c.draw_colored_polygon(poly, Color(0.72, 0.57, 0.24, 0.25))
		c.draw_polyline(pts, Color("#7e2418"), 2.5, true)
		for p in pts:
			c.draw_circle(p, 3.5, Color("#20140c"))
		c.draw_string(f, Vector2(2, y0 + 12), str(int(hi)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5e421c"))
		c.draw_string(f, Vector2(2, y0 + hgt), str(int(lo)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5e421c"))
		c.draw_string(Assets.font("heading_italic"), Vector2(x0 + 6, y0 + 18), "Gold held, last seven days", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#20140c")))
	return c


func _ledger_accounts() -> void:
	var today := Game.day()
	var sums := {}    # cat -> [today, week, all]
	for e in Game.state["ledger"]:
		var cat := str(e["cat"])
		if cat == "dev":
			continue
		if not sums.has(cat):
			sums[cat] = [0, 0, 0]
		var a := int(e["amount"])
		var d := int(e["day"])
		sums[cat][2] += a
		if today - d < 7:
			sums[cat][1] += a
		if d == today:
			sums[cat][0] += a
	body.add_child(UIKit.label("Money in and out, by category (%d transactions recorded; the ledger keeps the last 400)." % Game.state["ledger"].size(), 19, "body_italic"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	for t in ["", "", "Today", "This week", "All recorded"]:
		grid.add_child(UIKit.label(t, 20, "heading", UIKit.RUBRIC))
	var tot_in := [0, 0, 0]
	var tot_out := [0, 0, 0]
	for section in ["in", "out"]:
		grid.add_child(Control.new())
		grid.add_child(UIKit.label("Income" if section == "in" else "Expenses", 24, "heading"))
		for _i in 3:
			grid.add_child(Control.new())
		var any := false
		var cats := sums.keys()
		cats.sort()
		for cat in cats:
			var s: Array = sums[cat]
			var is_in: bool = int(s[2]) > 0 or (int(s[2]) == 0 and int(s[1]) >= 0)
			if (section == "in") != is_in:
				continue
			any = true
			var info := _cat_info(str(cat))
			grid.add_child(UIKit.icon(str(info[1]), 34))
			grid.add_child(UIKit.label(str(info[0]), 20))
			for i in 3:
				grid.add_child(_amount(int(s[i])))
				if section == "in":
					tot_in[i] += int(s[i])
				else:
					tot_out[i] += int(s[i])
		if not any:
			grid.add_child(Control.new())
			grid.add_child(UIKit.label("nothing yet", 18, "body_italic"))
			for _i in 3:
				grid.add_child(Control.new())
		grid.add_child(Control.new())
		grid.add_child(UIKit.label("Total " + ("income" if section == "in" else "expenses"), 20, "body_bold"))
		for i in 3:
			grid.add_child(_amount(tot_in[i] if section == "in" else tot_out[i], true))
	grid.add_child(UIKit.icon("icons/gold", 34))
	grid.add_child(UIKit.label("Net", 24, "heading"))
	for i in 3:
		grid.add_child(_amount(int(tot_in[i]) + int(tot_out[i]), true, 24))
	body.add_child(grid)


func _amount(v: int, bold := false, sz := 20) -> Label:
	var l := UIKit.label("%+d g" % v if v != 0 else "—", sz, "body_bold" if bold else "body", Color("#26622f") if v > 0 else (Color("#9e3a0c") if v < 0 else Color("#5e421c")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(130, 0)
	return l


func _ledger_journal() -> void:
	var h := UIKit.hbox(24)
	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.label("Journal", 26, "heading"))
	var js: Array = Game.state["journal"]
	var jt := ""
	for i in range(js.size() - 1, maxi(-1, js.size() - 20), -1):
		jt += "[color=#7e2418]Day %d %s[/color] — %s\n" % [js[i]["day"], js[i]["time"], js[i]["text"]]
	left.add_child(UIKit.rich(jt if jt != "" else "[i]Nothing written yet.[/i]", 19))
	h.add_child(left)
	var right := UIKit.vbox(4)
	right.custom_minimum_size = Vector2(520, 0)
	right.add_child(UIKit.label("Recent transactions", 26, "heading"))
	var l: Array = Game.state["ledger"]
	for i in range(l.size() - 1, maxi(-1, l.size() - 18), -1):
		var e: Dictionary = l[i]
		var r := UIKit.hbox(8)
		r.add_child(UIKit.icon(str(_cat_info(str(e["cat"]))[1]), 26))
		var t := UIKit.label("Day %d · %s" % [int(e["day"]), str(e.get("note", ""))], 17)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.clip_text = true
		t.custom_minimum_size = Vector2(300, 0)
		r.add_child(t)
		r.add_child(_amount(int(e["amount"]), false, 17))
		right.add_child(r)
	h.add_child(right)
	body.add_child(h)


func _ledger_upgrades() -> void:
	body.add_child(UIKit.label("Workshop upgrades", 28, "heading"))
	for u in DB.upgrades.values():
		var row := UIKit.hbox(12)
		var owned := Game.has_upgrade(u["id"])
		var req := ""
		var r: Dictionary = u.get("requires", {})
		if r.has("skill") and Game.player_level(r["skill"][0]) < int(r["skill"][1]):
			req = "needs %s %d" % [SkillSys.skill_name(r["skill"][0]), int(r["skill"][1])]
		if r.has("flag") and not Game.has_flag(r["flag"]):
			req += (", " if req != "" else "") + "needs mithril in your stores"
		row.add_child(UIKit.icon("icons/star" if owned else "ui/tb_property", 44))
		var lab := UIKit.rich("[b]%s[/b] — %d g\n[i]%s[/i]%s" % [u["name"], u["cost"], u["desc"], ("\n[color=#9e3a0c]" + req + "[/color]") if req != "" and not owned else ""], 20)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := UIKit.button("Owned" if owned else "Buy", func(): _buy(u), 140)
		b.disabled = owned or req != "" or not Game.can_afford(int(u["cost"]))
		row.add_child(b)
		body.add_child(row)


func _buy(u: Dictionary) -> void:
	var err := Shop.buy_upgrade(str(u["id"]))
	if err != "":
		Events.toast.emit(err, "bad")
	_build()
