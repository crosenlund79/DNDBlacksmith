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
	var people := []
	for c in Shop.waiting():
		people.append(c["npc"])
	if npc_focus != "" and not people.has(npc_focus):
		people.push_front(npc_focus)
	if people.is_empty():
		body.add_child(UIKit.label("Nobody is waiting outside. Customers come during opening hours (9:00–18:00) and take a seat by the door; adventurers in town often drop by.", 22, "body_italic"))
		return
	for npc in people:
		var row := UIKit.hbox(16)
		row.add_child(UIKit.portrait("portraits/" + npc, 112))
		var v := UIKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := Adv.get_a(npc)
		var cu := {}
		for c in Shop.customers():
			if c["npc"] == npc:
				cu = c
		if cu.get("want", "") == "repair":
			v.add_child(UIKit.rich("[b]%s[/b] wants their [b]%s[/b] repaired (pays about %d g)." % [Talk.npc_name(npc), cu["item"]["name"], cu["pay"]], 22))
			v.add_child(UIKit.button("Take the job — to the grinding wheel", func(): _repair(npc), 360))
		elif cu.get("want", "") == "goods":
			v.add_child(UIKit.rich("[b]%s[/b] wants a [b]%s[/b] (can spend about %d g)." % [Talk.npc_name(npc), DB.item(cu["looking_for"]).get("name", "draught"), int(cu["budget"])], 22))
			var gh := UIKit.hbox(8)
			var anyg := false
			for it in Game.inventory():
				if DB.item(it["def"]).get("type", "") == "potion" and it["def"] != "ale_mug":
					var b2 := UIKit.button("%s — %d g" % [Items.display_name(it), Shop.price_of(it) / maxi(1, int(it.get("qty", 1)))], func():
						var err2 := Shop.sell_goods(npc, int(it["uid"]))
						Events.toast.emit(err2 if err2 != "" else "%s pays and leaves happy." % Talk.npc_name(npc), "bad" if err2 != "" else "good")
						_build(), 0)
					gh.add_child(b2)
					anyg = true
			if not anyg:
				gh.add_child(UIKit.label("You have no draughts or oils to sell.", 20, "body_italic"))
			v.add_child(gh)
		elif cu.get("want", "") == "dispute":
			v.add_child(UIKit.rich("[b]%s[/b] is disputing your %s — talk to them outside to settle it." % [Talk.npc_name(npc), cu.get("item_name", "work")], 22))
		elif not a.is_empty():
			var married: bool = Social.spouse() == npc
			v.add_child(UIKit.rich("[b]%s[/b], %s %s (level %d) · %d gold%s\nNeeds: [i]%s[/i]" % [a["name"], Adv.rating_text(a), a["cls"], a["level"], a["gold"],
				" · [color=#7e2418]your wife — gear is free[/color]" if married else "", a.get("needs", "") if a.get("needs", "") != "" else "nothing urgent"], 22))
			var offers := UIKit.hbox(8)
			var any := false
			for it in Game.inventory():
				if not Items.is_equipment(it) or (not it.get("for_sale", false) and not married):
					continue
				var why := Adv.purchase_check(a, it, Shop.price_of(it))
				var b := UIKit.button("%s — %s" % [Items.display_name(it), "free" if married else "%d g" % Shop.price_of(it)], func():
					var err := Shop.sell_to(npc, int(it["uid"]))
					Events.toast.emit(err if err != "" else "%s takes the %s." % [a["name"], it["name"]], "bad" if err != "" else "good")
					_build(), 0)
				b.disabled = why != ""
				b.tooltip_text = why
				b.add_theme_color_override("font_color", Items.color(it, false))
				offers.add_child(b)
				any = true
			if not any:
				offers.add_child(UIKit.label("Nothing on display suits them. Put equipment on display from your stores [I].", 20, "body_italic"))
			v.add_child(offers)
		row.add_child(v)
		body.add_child(row)
		body.add_child(UIKit.divider())


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


func _ledger() -> void:
	var by_cat := {}
	var days := {}
	for e in Game.state["ledger"]:
		if Game.day() - int(e["day"]) > 7:
			continue
		by_cat[e["cat"]] = int(by_cat.get(e["cat"], 0)) + int(e["amount"])
		days[e["day"]] = int(days.get(e["day"], 0)) + int(e["amount"])
	var txt := "[b]Purse:[/b] %d gold    [b]Crafted:[/b] %d    [b]Sold:[/b] %d    [b]Legendaries found:[/b] %d\n[b]Standing in Brindlewick:[/b] [i]%s[/i] — it brings customers in (or keeps them away) and shapes what prices people accept.    [b]Daily upkeep:[/b] %d g plus wages\n\n[b]Last seven days by category[/b]\n" % [Game.gold(), Game.state["stats"]["crafted"], Game.state["stats"]["sold"], Game.state["stats"]["legendaries"], Shop.reputation_word(), Shop.UPKEEP + Game.state.get("upgrades", []).size()]
	for k in by_cat:
		txt += "%s: [color=%s]%+d[/color]   " % [str(k).capitalize(), "#26622f" if by_cat[k] >= 0 else "#9e3a0c", by_cat[k]]
	txt += "\n\n[b]Net per day[/b]\n"
	for d in days:
		txt += "Day %d: [color=%s]%+d[/color]   " % [d, "#26622f" if days[d] >= 0 else "#9e3a0c", days[d]]
	body.add_child(UIKit.rich(txt, 21))
	body.add_child(UIKit.divider())
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
		var lab := UIKit.rich("[b]%s[/b] — %d g\n[i]%s[/i]%s" % [u["name"], u["cost"], u["desc"], ("\n[color=#9e3a0c]" + req + "[/color]") if req != "" and not owned else ""], 20)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := UIKit.button("Owned" if owned else "Buy", func(): _buy(u), 140)
		b.disabled = owned or req != "" or not Game.can_afford(int(u["cost"]))
		row.add_child(b)
		body.add_child(row)
	body.add_child(UIKit.divider())
	var journal := "[b]Journal[/b]\n"
	var js: Array = Game.state["journal"]
	for i in range(js.size() - 1, maxi(-1, js.size() - 12), -1):
		journal += "[color=#5e421c]Day %d %s[/color] — %s\n" % [js[i]["day"], js[i]["time"], js[i]["text"]]
	body.add_child(UIKit.rich(journal, 19))


func _buy(u: Dictionary) -> void:
	Game.add_gold(-int(u["cost"]), "upgrades", u["name"])
	Game.state["upgrades"].append(u["id"])
	if u["id"] == "arcane_foundry":
		var sk := Game.player_skills()
		if SkillSys.level(sk, "arcane_metalwork") < 1:
			sk["arcane_metalwork"]["lvl"] = 1
		Game.journal("The Arcane Foundry hums into life. The leyline answers.")
	Events.world_flag_changed.emit("upgrade_" + u["id"])
	Events.toast.emit("Upgrade installed: " + u["name"], "good")
	Audio.play("sfx/level_up", -6.0)
	_build()
