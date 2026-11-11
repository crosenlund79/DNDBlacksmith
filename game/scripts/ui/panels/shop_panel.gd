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
	super._init("The Shop Counter", 1260, 720)   # #47: was 1320×780


func _ready() -> void:
	super._ready()
	var tabs := UIKit.hbox(8)
	for t in [["customers", "Customers & Offers"], ["stock", "Stock on Display"], ["ledger", "Ledger & Upgrades"]]:
		var key: String = t[0]
		tabs.add_child(UIKit.small_button(t[1], func(): tab = key; _build(), 0))
	content.add_child(tabs)
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 560))
	Events.inventory_changed.connect(_build)
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	UIKit.clear(body)
	match tab:
		"customers": _customers()
		"stock": _stock()
		"ledger": _ledger()


## Living Workshop #54–55: who is who at the counter, in this order — the customers waiting at your counter (they give
## up after a few hours), the finds returning adventurers offer for sale (not customers), and a line for the
## commission opportunities in town (adventurers who need something forged and have not been asked; the Commissions
## book lists them). Each section has its own word and colour (WhoIsWho).
func _customers() -> void:
	var people := []
	for c in Shop.waiting():
		people.append(c["npc"])
	if npc_focus != "" and not people.has(npc_focus):
		people.push_front(npc_focus)
	var sh := UIKit.hbox(10)
	sh.name = "Section_waiting"
	sh.add_child(UIKit.heading("Waiting at your counter (%d of %d seats)" % [Shop.waiting().size(), Shop.SEATS]))
	sh.add_child(WhoIsWho.chip("waiting", true))
	body.add_child(sh)
	if people.is_empty():
		body.add_child(UIKit.note("Nobody is waiting outside. Customers come during opening hours (9:00–18:00) and take a seat by the door; adventurers in town often drop by."))
	for npc in people:
		_customer_row(npc)
	_offers()
	_opportunities_line()


## A summary line under the counter: who in town would order something if asked (the Commissions book has the list).
func _opportunities_line() -> void:
	var opp := WhoIsWho.opportunities()
	if opp.is_empty():
		return
	var h := UIKit.hbox(10)
	h.name = "Section_opportunity"
	h.add_child(WhoIsWho.chip("opportunity", true))
	var names := PackedStringArray()
	for a in opp.slice(0, 4):
		names.append("%s (%s)" % [a["name"], WhoIsWho.need_text(a)])
	var l := UIKit.label("Commission opportunities in town: %s%s — ask them what they need forged." % [", ".join(names), (" and %d more" % (opp.size() - 4)) if opp.size() > 4 else ""], UIKit.FS_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UIKit.small_button("Commissions book", func(): Events.open_panel.emit("orders", {}), 0))
	body.add_child(h)


func _customer_row(npc: String) -> void:
	var row := UIKit.hbox(12)
	row.name = "Customer_" + npc
	row.add_child(UIKit.portrait("portraits/" + npc, 80))
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := Adv.get_a(npc)
	var cu := Shop.customer(npc)
	var waiting: bool = not cu.is_empty() and cu.get("present", true)
	# the explicit request card: what they want, attributes, materials, budget and reward
	var req := Shop.request(cu if not cu.is_empty() else {"npc": npc, "want": "browse"})
	var wh := UIKit.hbox(10)
	var who := UIKit.rich("[b]%s[/b]%s" % [Talk.npc_name(npc), (" · adventurer · %s %s, level %d · %d gold" % [Adv.rating_text(a), a["cls"], a["level"], a["gold"]]) if not a.is_empty() else " · villager"], UIKit.FS_SMALL)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(who)
	if waiting:
		wh.add_child(WhoIsWho.chip("waiting", true))
	v.add_child(wh)
	v.add_child(CustomerCard.build(req))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	if cu.get("want", "") == "multi":
		_multi_parts(v, cu, npc)
	elif cu.get("want", "") == "repair":
		actions.add_child(UIKit.small_button("Take the job — to the grinding wheel", func(): _repair(npc), 0))
		var rit: Dictionary = cu.get("item", {})
		if cu.has("own_slot"):
			rit = a.get("equipment", {}).get(str(cu["own_slot"]), rit)
		if Items.is_equipment(rit):
			var ruid := int(rit.get("uid", -1))
			actions.add_child(UIKit.small_button("Inspect the piece", func(): Events.open_panel.emit("item", {"uid": ruid}), 0))
			if waiting:
				(func(): ItemStory.at_counter(npc)).call_deferred()   # "A Familiar Creation" — once per reunion
	elif cu.get("want", "") == "goods":
		v.add_child(_goods_offers(npc, cu))   # S2 (OBS-15, BUG-043): what they asked for, the rest greyed with why
	elif cu.get("want", "") == "dispute":
		actions.add_child(UIKit.note("Talk to them outside to settle it."))
	elif cu.get("want", "") == "advice":   # The Living Realm 3b (Consult)
		actions.add_child(UIKit.small_button("Hear them out — advise on their gear", func(): Events.open_panel.emit("consult", {"id": npc}), 0))
	elif not a.is_empty():
		# A2: a compact grid of the pieces on display with a details view and an explicit "Sell for N g" (OfferPicker)
		if OfferPicker.candidates(npc, req).is_empty():
			actions.add_child(UIKit.note("Nothing on display suits them. Put equipment on display from your stores [I]."))
		else:
			v.add_child(OfferPicker.new(npc, req, func(): _build.call_deferred()))
	if waiting and cu.get("want", "") != "dispute":
		var dis := UIKit.small_button("Ask them to come back another time", func():
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


## The draughts and oils in the stores a "goods" customer could be offered: [{item, price (one unit), why ("" = they
## would buy it; else the reason in words)}], those they would buy first. Ale is the inn's, not the counter's.
static func goods_candidates(c: Dictionary) -> Array:
	var out := []
	var want := str(c.get("looking_for", ""))
	for it in Game.inventory():
		if DB.item(str(it["def"])).get("type", "") != "potion" or str(it["def"]) == "ale_mug":
			continue
		var price := Shop.price_of(it) / maxi(1, int(it.get("qty", 1)))
		var why := ""
		match Shop.goods_refusal(c, it):
			"wrong":
				why = "not what they asked for — they want %s" % DB.item(want).get("name", want)
			"budget":
				why = "over their budget — %d g; they spend up to %d g" % [price, int(c.get("budget", 0))]
		out.append({"item": it, "price": price, "why": why})
	out.sort_custom(func(x, y): return (0 if str(x["why"]) == "" else 1) < (0 if str(y["why"]) == "" else 1))
	return out


## One row per draught: what it costs and either "Sell one" or, greyed, why they would not buy it. With the optional
## "only what they would buy" filter on (off by default), the others are hidden and counted.
func _goods_offers(npc: String, cu: Dictionary) -> Control:
	var box := UIKit.vbox(4)
	box.name = "GoodsOffers"
	var want := str(cu.get("looking_for", ""))
	var top := UIKit.hbox(12)
	var cap := UIKit.label("From your stores — they want %s" % DB.item(want).get("name", "a draught"), 17, "heading_italic", UIKit.RUBRIC)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cap)
	top.add_child(OfferPicker.filter_toggle(func(): _build.call_deferred()))
	box.add_child(top)
	var list := goods_candidates(cu)
	var hidden := 0
	for c in list:
		var why := str(c["why"])
		if why != "" and OfferPicker.only_buyable:
			hidden += 1
			continue
		var it: Dictionary = c["item"]
		var row := UIKit.hbox(10)
		row.name = "Goods_%d" % int(it["uid"])
		var slot := ItemSlot.new(it, 48.0)
		if why != "":
			slot.modulate = Color(0.62, 0.58, 0.52, 0.55)
		row.add_child(slot)
		var info := UIKit.rich("[b]%s[/b] — %d g each%s" % [Items.display_name(it), int(c["price"]),
			("\n[color=#7e2418]✗ %s[/color]" % why) if why != "" else "\n[color=#26622f]✓ what they asked for, within their budget[/color]"], 18)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var uid := int(it["uid"])
		var b := UIKit.button("Sell one for %d g" % int(c["price"]), func():
			var err := Shop.sell_goods(npc, uid)
			Events.toast.emit(err if err != "" else "%s pays and leaves happy." % Talk.npc_name(npc), "bad" if err != "" else "good")
			_build(), 220)
		b.name = "SellGoods"
		b.disabled = why != ""
		b.tooltip_text = ("They would not buy it: %s." % why) if why != "" else "%s pays %d g and takes one." % [Talk.npc_name(npc), int(c["price"])]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		box.add_child(row)
	if list.is_empty():
		box.add_child(UIKit.label("You have no draughts or oils to sell.", 20, "body_italic"))
	elif hidden > 0:
		box.add_child(UIKit.label("%d other draught%s hidden — not what they asked for or over their budget (untick the filter to see them)." % [hidden, "" if hidden == 1 else "s"], 17, "body_italic", Color("#5e421c")))
	if not list.is_empty() and list.filter(func(x): return str(x["why"]) == "").is_empty():
		box.add_child(UIKit.label("Nothing in your stores fits their request.", 18, "body_italic"))
	return box


## Finds brought home from expeditions, offered to the forge (they go elsewhere after three days).
func _offers() -> void:
	var offs := Shop.offers()
	if offs.is_empty():
		return
	body.add_child(UIKit.divider())
	var oh := UIKit.hbox(10)
	oh.name = "Section_offers"
	oh.add_child(UIKit.heading("Finds offered by returning adventurers (%d)" % offs.size()))
	oh.add_child(UIKit.note("for sale to you — not customers", UIKit.FS_MIN))
	body.add_child(oh)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for o in offs:
		var it: Dictionary = o["item"]
		var a := Adv.get_a(str(o["from"]))
		# #47: a compact tile — the piece beside its words, small buttons
		var col := UIKit.hbox(8)
		col.custom_minimum_size = Vector2(290, 0)
		col.add_child(ItemSlot.new(it, 56.0))
		var cv := UIKit.vbox(2)
		cv.add_child(UIKit.rich("[b]%s[/b]\nfrom %s · %s · %d day%s left" % [Items.display_name(it), a.get("name", "?"), "free" if int(o["price"]) == 0 else "%d g" % int(o["price"]),
			3 - (Game.day() - int(o["day"])), "" if 3 - (Game.day() - int(o["day"])) == 1 else "s"], UIKit.FS_MIN))
		col.add_child(cv)
		var h := UIKit.hbox(4)
		var oid: String = o["id"]
		h.add_child(UIKit.small_button("Buy", func():
			var err := Shop.accept_offer(oid)
			Events.toast.emit(err if err != "" else "Bought — it is in your stores.", "bad" if err != "" else "good")
			_build(), 64))
		h.add_child(UIKit.small_button("Decline", func(): Shop.decline_offer(oid); _build(), 0))
		if Items.is_equipment(it):
			var ouid := int(it["uid"])
			h.add_child(UIKit.small_button("Inspect", func(): Events.open_panel.emit("item", {"uid": ouid}), 0))
			var ofrom := str(o["from"])
			(func(): ItemStory.present(it, "offer", ofrom)).call_deferred()   # your own work among the finds
		cv.add_child(h)
		grid.add_child(col)
	body.add_child(grid)
	body.add_child(UIKit.divider())


## A multi-order: every part on its own card with availability and its own Accept / Decline / Repair.
func _multi_parts(v: VBoxContainer, cu: Dictionary, npc: String) -> void:
	v.add_child(UIKit.note("Take on what you can — each part can be accepted or declined on its own."))
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
				var rb := UIKit.small_button("Repair it", func(): _repair_part(npc, pid), 150)
				rb.disabled = not bool(r.get("available", true))
				bx.add_child(rb)
			else:
				var ab := UIKit.small_button("Accept", func():
					var err := Shop.accept_part(npc, pid)
					if err != "":
						Events.toast.emit(err, "bad")
					_build(), 150)
				ab.tooltip_text = "Becomes a commission: deliver it by the deadline." + ("" if bool(r.get("available", true)) else "\nYou cannot make it yet — %s." % r.get("why", ""))
				bx.add_child(ab)
			bx.add_child(UIKit.small_button("Decline", func():
				Shop.decline_part(npc, pid)
				_build(), 150))
		row.add_child(bx)
		v.add_child(row)


func _repair_part(npc: String, pid: String) -> void:
	ItemSpirit.speak_repair(npc, pid)
	var c := Crafting.check_params("grinding_wheel")
	Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Repair at the grinding wheel",
		"on_done": func(qs: Array):
			Shop.repair_part(npc, pid, float(qs[0]))
			Events.toast.emit("Repair done (%d%%)." % int(qs[0]), "good")})


func _repair(npc: String) -> void:
	ItemSpirit.speak_repair(npc)
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
			Shop.set_for_sale(int(x["uid"]), not x.get("for_sale", false)))
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
	"subsidy": ["Village subsidy", "ui/tb_orders"],   # A2: the village's recorded share of adventurers' commissions
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
