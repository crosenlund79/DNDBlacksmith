## CreaturesPanel — Hale Farm: Bram Hale's hounds, falcons, ponies, mules and cats, and his son Ellery's curious
## creatures (moon-moth, stone-toad, glimmer-fox, pocket drake).
## EN: Left: this week's yard (click a creature). Right: the creature up close, and what to do — buy it for your
##     stores, or for an adventurer in town (a gift, a resale at a fair or steep price, or an introduction where
##     they pay the Hales themselves); commission one that is not in the yard; give a creature you own.
## DA: Hale-gården: almindelige og magiske dyr; køb til dig selv eller til en eventyrer, eller bestil et.
class_name CreaturesPanel
extends UIWindow

var sel := -1                 # index into Commerce.creature_stock()
var adv := ""                 # chosen adventurer id
var head: HBoxContainer
var left: VBoxContainer
var right: VBoxContainer
var line := ""


func _init(args: Dictionary = {}) -> void:
	super._init("Hale Farm", 1640, 940)


func _ready() -> void:
	super._ready()
	head = UIKit.hbox(16)
	content.add_child(head)
	var row := UIKit.hbox(22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	left = UIKit.vbox(8)
	var ls := UIKit.scroll(left, 660)
	ls.custom_minimum_size = Vector2(760, 660)
	row.add_child(ls)
	right = UIKit.vbox(8)
	var rs := UIKit.scroll(right, 660)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rs)
	var s := Commerce.creature_stock()
	for i in s.size():
		if not bool(s[i].get("sold", false)):
			sel = i
			break
	line = Commerce.greeting("hale_elder")
	Events.gold_changed.connect(func(_g): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	title_label.text = str(Commerce.creature_cfg().get("yard", "Hale Farm"))
	UIKit.clear(head)
	for id in ["hale_elder", "hale_younger"]:
		var c := DB.character(id)
		head.add_child(UIKit.portrait("portraits/" + id, 112))
		var v := UIKit.vbox(2)
		v.custom_minimum_size = Vector2(420, 0)
		v.add_child(UIKit.label(str(c.get("name", id)), 24, "heading", UIKit.RUBRIC))
		v.add_child(UIKit.label(str(c.get("title", "")), 18, "body_italic"))
		var l := UIKit.rich("[i]%s[/i]" % (line if id == "hale_elder" else Commerce.greeting("hale_younger")), 18)
		l.custom_minimum_size = Vector2(420, 0)
		v.add_child(l)
		head.add_child(v)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UIKit.rich("Purse\n[font_size=30][b]%d g[/b][/font_size]" % Game.gold(), 20))
	_build_left()
	_build_right()


# ------------------------------------------------------------------ the yard
func _build_left() -> void:
	UIKit.clear(left)
	var s := Commerce.creature_stock()
	for magic in [false, true]:
		left.add_child(UIKit.label("Ellery's curious creatures" if magic else "Bram's beasts", 26, "heading", UIKit.RUBRIC))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		var n := 0
		for i in s.size():
			if Companions.magical(str(s[i]["def"])) == magic:
				grid.add_child(_card(i, s[i]))
				n += 1
		if n == 0:
			left.add_child(UIKit.label("None in the yard this week.", 19, "body_italic"))
		left.add_child(grid)
	var owned := Game.inventory().filter(func(it): return Companions.is_companion(it))
	if not owned.is_empty():
		left.add_child(UIKit.label("Your creatures", 26, "heading", UIKit.RUBRIC))
		for it in owned:
			var uid := int(it["uid"])
			var h := UIKit.hbox(10)
			h.add_child(ItemSlot.new(it, 56))
			var r := UIKit.rich("[b]%s[/b]\n%s" % [it["name"], Companions.stat_line(it)], 18)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(r)
			# Living Workshop #52: the one that walks at the smith's heel (Family.pet; the longest kept unless he chooses)
			if int(Family.pet().get("uid", -1)) == uid:
				h.add_child(UIKit.chip("walks with you", UIKit.RUBRIC))
			elif not bool(it.get("for_sale", false)):
				h.add_child(UIKit.small_button("Take it along", func():
					Family.set_pet(uid)
					_build(), 0))
			var b := UIKit.button("Give to %s" % Talk.npc_name(adv) if adv != "" else "Pick an adventurer →", func():
				var err := Commerce.give_owned_creature(uid, adv)
				Events.toast.emit(err if err != "" else "%s goes to %s." % [it["name"], Talk.npc_name(adv)], "bad" if err != "" else "good")
				_build(), 0)
			b.disabled = adv == ""
			h.add_child(b)
			left.add_child(h)


func _card(i: int, e: Dictionary) -> Control:
	var def_id: String = e["def"]
	var d := DB.item(def_id)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.78, 0.6, 0.55) if i != sel else Color(0.95, 0.85, 0.55, 0.85)
	sb.border_color = UIKit.RUBRIC if i == sel else Color(0.13, 0.08, 0.05, 0.5)
	sb.set_border_width_all(3 if i == sel else 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(368, 0)
	var h := UIKit.hbox(8)
	var ic := UIKit.icon("icons/" + def_id, 72)
	h.add_child(ic)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(str(d.get("name", def_id)), 20, "body_bold"))
	var sl := UIKit.label(Companions.def_stat_line(def_id), 16, "body")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var sold := bool(e.get("sold", false))
	v.add_child(UIKit.label("found a home" if sold else "%d g" % int(e["price"]), 18, "body_bold", UIKit.RUBRIC if sold else UIKit.INK))
	h.add_child(v)
	pc.add_child(h)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			sel = i
			_build())
	pc.modulate = Color(1, 1, 1, 0.55) if sold else Color.WHITE
	return pc


# ------------------------------------------------------------------ the chosen creature
func _build_right() -> void:
	UIKit.clear(right)
	var s := Commerce.creature_stock()
	if sel >= 0 and sel < s.size():
		var e: Dictionary = s[sel]
		var def_id: String = e["def"]
		var d := DB.item(def_id)
		var top := UIKit.hbox(14)
		top.add_child(_mini(str(d.get("creature", def_id))))
		var tv := UIKit.vbox(4)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(str(d.get("name", def_id)), 30, "heading", UIKit.RUBRIC))
		tv.add_child(UIKit.label(Companions.def_stat_line(def_id), 20, "body_bold"))
		var keeper := DB.character(str(d.get("keeper", "hale_elder")))
		tv.add_child(UIKit.label("Raised by %s%s" % [keeper.get("name", "the Hales"), " · magical" if Companions.magical(def_id) else ""], 18, "body_italic"))
		var desc := UIKit.rich("[i]%s[/i]" % d.get("desc", ""), 19)
		desc.custom_minimum_size = Vector2(520, 0)
		tv.add_child(desc)
		top.add_child(tv)
		right.add_child(top)
		var price := int(e["price"])
		if bool(e.get("sold", false)):
			right.add_child(UIKit.label("This one has already gone to a new home.", 20, "body_italic"))
		else:
			var b := UIKit.button("Buy for your own stores — %d g" % price, func():
				var err := Commerce.buy_creature(sel)
				Events.toast.emit(err if err != "" else "The creature is yours — it waits in your stores to keep or give.", "bad" if err != "" else "good")
				_build(), 0)
			b.disabled = not Game.can_afford(price)
			right.add_child(b)
			right.add_child(UIKit.divider())
			_for_adventurer(price)
	right.add_child(UIKit.divider())
	_commissions()


func _mini(creature: String) -> Control:
	var t := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = Assets.get_tex("creatures/" + creature, Vector2i(128, 64))
	at.region = Rect2(0, 0, 64, 64)
	t.texture = at
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.custom_minimum_size = Vector2(180, 180)
	return t


func _for_adventurer(price: int) -> void:
	right.add_child(UIKit.label("For an adventurer", 24, "heading", UIKit.RUBRIC))
	var pool := Adv.all().values().filter(func(a): return str(a["status"]) in ["in_town", "injured"])
	if pool.is_empty():
		right.add_child(UIKit.label("Nobody is in town just now.", 19, "body_italic"))
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for a in pool:
		var id := str(a["id"])
		var has := not Companions.of(a).is_empty()
		var b := UIKit.button("%s (%d g)%s" % [a["name"], int(a["gold"]), " · has %s" % Companions.pet_name(Companions.of(a)) if has else ""], func(): adv = id; _build(), 0)
		b.disabled = adv == id or has
		flow.add_child(b)
	right.add_child(flow)
	if adv == "" or Adv.get_a(adv).is_empty():
		right.add_child(UIKit.label("Choose who the creature is for.", 19, "body_italic"))
		return
	var a := Adv.get_a(adv)
	var nm := str(a["name"])
	var married: bool = Social.spouse() == adv
	right.add_child(UIKit.rich("For [b]%s[/b] — %s, %d gold in their purse." % [nm, Social.band(adv), int(a["gold"])], 19))
	var acts := VBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	_act(acts, "Give it to %s as a gift — you pay %d g" % [nm, price], "gift", 1.0, Game.can_afford(price))
	for m in Commerce.creature_cfg().get("sell_markup", [1.0, 1.15, 1.3]):
		var ask := 0 if married else int(round(price * float(m)))
		var word := "a fair price" if float(m) <= 1.0 else ("a fair margin" if float(m) <= 1.16 else "a steep price")
		_act(acts, "Sell it on at %s — you pay %d g, %s pays you %d g" % [word, price, nm, ask], "sell", float(m), Game.can_afford(price) and int(a["gold"]) >= ask)
	var fee := int(round(price * float(Commerce.creature_cfg().get("finder_fee", 0.1))))
	_act(acts, "Introduce %s to the Hales — they pay %d g, you earn a %d g finder's fee" % [nm, price, fee], "arrange", 1.0, int(a["gold"]) >= price)
	right.add_child(acts)


func _act(box: VBoxContainer, text: String, mode: String, markup: float, ok: bool) -> void:
	var b := UIKit.button("❧ " + text, func():
		var err := Commerce.arrange_creature(sel, adv, mode, markup)
		if err == "":
			line = "\"Off you go, little one. Be good to %s.\"" % Talk.npc_name(adv)
		Events.toast.emit(err if err != "" else "Done — %s has a new companion." % Talk.npc_name(adv), "bad" if err != "" else "good")
		_build(), 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not ok
	box.add_child(b)


func _commissions() -> void:
	right.add_child(UIKit.label("Commission a creature", 24, "heading", UIKit.RUBRIC))
	var cc: Dictionary = Commerce.creature_cfg().get("commission", {})
	var lead: Array = cc.get("lead", [3, 6])
	right.add_child(UIKit.rich("Not in the yard? The Hales will find or raise one: paid in full now, ready in %d–%d days%s." % [int(lead[0]), int(lead[1]),
		(" — delivered straight to %s" % Talk.npc_name(adv)) if adv != "" else " — delivered to your stores"], 18))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for def_id: String in Companions.defs():
		var cost := int(round(Commerce.creature_price(def_id) * float(cc.get("markup", 1.15))))
		var b := UIKit.button("%s — %d g" % [DB.item(def_id).get("name", def_id), cost], func():
			var err := Commerce.commission_creature(def_id, adv)
			Events.toast.emit(err if err != "" else "Commissioned — the Hales will send word.", "bad" if err != "" else "good")
			_build(), 0)
		b.disabled = not Game.can_afford(cost)
		flow.add_child(b)
	right.add_child(flow)
	var orders := Commerce.commissions()
	if not orders.is_empty():
		var lines := []
		for o in orders:
			lines.append("%s%s — due about day %d" % [DB.item(str(o["def"])).get("name", o["def"]), (" for " + Talk.npc_name(str(o["for"]))) if str(o.get("for", "")) != "" else "", int(o["due"])])
		right.add_child(UIKit.rich("[i]On order: %s[/i]" % "; ".join(lines), 18))
