## InventoryPanel — stores, the smith's own equipment and stock-for-sale toggles.
## DA: Lager, smedens eget udstyr og markering af varer til salg.
class_name InventoryPanel
extends UIWindow

## A2 layout: a fixed window that fits 1920×1080 (and 1600×900, the same canvas scaled) however many pieces the stores
## hold — the grid and the details column scroll on their own, and the details column can be collapsed (the grid then
## widens; clicking a piece opens it again; a right-click still opens the full inspection).
const WIN := Vector2(1560, 900)
const SLOT := 72.0
const GAP := 8
const DETAIL_W := 440.0
## Whether the details column is open (kept for the session).
static var details_open := true

var grid: GridContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var grid_scroll: ScrollContainer
var count_label: Label
var toggle: Button
var selected: Dictionary = {}
var filter := "all"


func _init() -> void:
	super._init("Stores & Equipment", WIN.x, WIN.y)


func _ready() -> void:
	super._ready()
	var tabs := UIKit.hbox(8)
	for f in [["all", "Everything"], ["equipment", "Equipment"], ["materials", "Materials"], ["magic", "Runes & Alchemy"], ["relics", "Relics"]]:
		var key: String = f[0]
		tabs.add_child(UIKit.button(f[1], func(): filter = key; _fill(), 0))
	count_label = UIKit.label("", 19, "body_italic", Color("#5e421c"))
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(count_label)
	toggle = UIKit.button("", func(): set_details(not details_open), 190)
	toggle.name = "DetailsToggle"
	tabs.add_child(toggle)
	content.add_child(tabs)
	var h := UIKit.hbox(20)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid_scroll = UIKit.scroll(grid, 400)
	grid_scroll.name = "GridScroll"
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(grid_scroll)
	detail = UIKit.vbox(8)
	detail_scroll = UIKit.scroll(detail, 400)
	detail_scroll.name = "DetailScroll"
	detail_scroll.custom_minimum_size.x = DETAIL_W
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(detail_scroll)
	content.add_child(h)
	Events.inventory_changed.connect(_fill)
	set_details(details_open)


## Opens or collapses the details column (the grid takes the room).
func set_details(on: bool) -> void:
	details_open = on
	detail_scroll.visible = on
	toggle.text = "Hide details ◂" if on else "Details ▸"
	toggle.tooltip_text = "Collapse the details column for a wider grid." if on else "Show the details column (also opens when you click a piece)."
	# columns that fit the grid's width (window minus margins, the scrollbar and, when open, the details column)
	var w := WIN.x - 60.0 - 18.0 - ((DETAIL_W + 20.0) if on else 0.0)
	grid.columns = maxi(6, int((w + GAP) / (SLOT + GAP)))
	_fill()


func _match(it: Dictionary) -> bool:
	var t: String = DB.item(it["def"]).get("type", "")
	match filter:
		"equipment": return Items.is_equipment(it)
		"materials": return t == "material"
		"magic": return t in ["runestone", "potion"]
		"relics": return t in ["relic", "container"]
	return true


func _fill() -> void:
	UIKit.clear(grid)
	var inv := Game.inventory().duplicate()
	var order := ["legendary", "unique", "set", "rare", "magic", "common"]
	inv.sort_custom(func(a, b): return order.find(a.get("rarity", "common")) < order.find(b.get("rarity", "common")))
	var shown := 0
	for it in inv:
		if not _match(it):
			continue
		var s := ItemSlot.new(it, SLOT)
		s.selected = not selected.is_empty() and int(selected.get("uid", -1)) == int(it["uid"])
		s.clicked.connect(_select)
		grid.add_child(s)
		shown += 1
	count_label.text = "%d of %d shown" % [shown, inv.size()] if shown != inv.size() else "%d pieces" % inv.size()
	_detail()


func _select(it: Dictionary) -> void:
	selected = it
	if not details_open:
		set_details(true)   # a click on a piece opens the details again
	else:
		_fill()
	ItemSpirit.speak(it, "inspect")   # an awakened piece may remark on being looked over


## LW #57: every slot the smith can wear (shield, cloak, belt and amulet were missing: a piece put on there vanished),
## plus any other slot he wears something in. A worn piece can be selected and taken off again.
func _worn_slots() -> Array:
	var out: Array = Game.PLAYER_SLOTS.duplicate()
	var eq: Dictionary = Game.state["player"]["equipment"]
	for s in eq:
		if not out.has(str(s)) and eq[s] is Dictionary and not (eq[s] as Dictionary).is_empty():
			out.append(str(s))
	return out


func _detail() -> void:
	UIKit.clear(detail)
	detail.add_child(UIKit.label("Worn by Brannoc", 26, "heading"))
	var eq: Dictionary = Game.state["player"]["equipment"]
	var row := GridContainer.new()
	row.name = "WornSlots"
	row.columns = 5
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for s in _worn_slots():
		var it: Dictionary = eq.get(s, {})
		var sl := ItemSlot.new(it, 60.0)
		sl.name = "Worn_" + str(s)
		sl.tooltip_text = str(s).capitalize() if it.is_empty() else ""
		if not it.is_empty():
			sl.selected = not selected.is_empty() and int(selected.get("uid", -1)) == int(it.get("uid", -2))
			sl.clicked.connect(_select)
		row.add_child(sl)
	detail.add_child(row)
	detail.add_child(UIKit.label("%d gold · %d items" % [Game.gold(), Game.inventory().size()], 22, "body_bold", UIKit.RUBRIC))
	detail.add_child(UIKit.divider())
	var worn := "" if selected.is_empty() else Game.player_worn_slot(int(selected["uid"]))
	if worn != "":
		_worn_detail(worn)
		return
	if selected.is_empty() or Game.find_uid(int(selected["uid"])).is_empty():
		detail.add_child(UIKit.label("Select an item to inspect it.", 20, "body_italic"))
		return
	var it := Game.find_uid(int(selected["uid"]))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	p.add_child(UIKit.rich(Items.tooltip(it), 20, true))
	detail.add_child(p)
	if it.has("craft"):
		detail.add_child(UIKit.button("Read the record of the work", func(): Events.open_panel.emit("craft_result", {"item": it, "fresh": false}), 0))
	if Items.is_equipment(it):
		var iuid := int(it["uid"])
		detail.add_child(UIKit.button("Inspect — its maker, history and owners", func(): Events.open_panel.emit("item", {"uid": iuid}), 0))
	elif it.has("craft") or not it.get("history", []).is_empty():
		detail.add_child(UIKit.button("History of this piece", func(): Events.open_panel.emit("history", {"kind": "item", "id": str(it["uid"])}), 0))
	if Regions.is_unidentified(it):
		detail.add_child(UIKit.button("Study the relic (at the cleansing basin)", func(): _study(int(it["uid"])), 0))
	if it["def"] == "recipe_scroll":
		detail.add_child(UIKit.button("Read the notes", func():
			Events.toast.emit(Regions.read_recipe(int(it["uid"])), "good")
			selected = {}, 0))
	if DB.item(it["def"]).get("type", "") == "potion" and it["def"] != "ale_mug":
		var fs: bool = it.get("for_sale", false)
		detail.add_child(UIKit.button("Take off the shop shelf" if fs else "Put on the shop shelf (adventurers buy before they leave)", func():
			Shop.set_for_sale(int(it["uid"]), not fs), 0))
	if not Items.is_equipment(it) and DB.item(it["def"]).get("type", "") in ["potion", "material", "relic"] and not Regions.is_unidentified(it):
		var tr: bool = it.get("trade", false)
		detail.add_child(UIKit.button("Keep it at home" if tr else "Send with the next trade run", func():
			it["trade"] = not tr
			Events.inventory_changed.emit(), 0))
	if Items.is_equipment(it):
		detail.add_child(UIKit.button("Equip on Brannoc", func(): Game.equip_player(int(it["uid"])), 0))   # stays selected: shown as worn
		var sale: bool = it.get("for_sale", false)
		var disp := UIKit.button("Remove from display" if sale else "Display for sale (%d g)" % Shop.price_of(it), func():
			Shop.set_for_sale(int(it["uid"]), not sale), 0)
		detail.add_child(disp)
		# LW #48: the asking price is the smith's to set — shown for every piece (before it goes on display too), with
		# the usual price beside it and a way back to it (the manual price itself is unchanged: Shop.set_price)
		var ph := UIKit.hbox(8)
		ph.name = "PriceRow"
		var pl := UIKit.label("Your price:", 20, "body_bold")
		pl.tooltip_text = "You set the asking price. Buyers pay it if they think it fair; the usual price follows the piece's value."
		ph.add_child(pl)
		var sb := SpinBox.new()
		sb.name = "PriceBox"
		sb.min_value = 1
		sb.max_value = 99999
		sb.suffix = "g"
		sb.value = Shop.price_of(it)
		sb.tooltip_text = pl.tooltip_text
		var puid := int(it["uid"])
		sb.value_changed.connect(func(v):
			Shop.set_price(puid, int(v))
			if not sale:
				disp.text = "Display for sale (%d g)" % int(v))
		ph.add_child(sb)
		var usual := Shop.list_price(it)
		ph.add_child(UIKit.label("usual %d g" % usual, 18, "body_italic"))
		if it.has("price") and int(it["price"]) != usual:
			var rb := UIKit.button("Usual price", func():
				Shop.set_price(puid, usual)
				Events.inventory_changed.emit(), 0)
			rb.tooltip_text = "Back to the usual price for this piece (%d g)." % usual
			ph.add_child(rb)
		detail.add_child(ph)
	if it["def"] == "potion_healing":
		detail.add_child(UIKit.label("Healing draughts make thoughtful gifts.", 18, "body_italic"))


## A piece the smith wears: what it is, its record, and taking it off (back to the stores — same piece, same uid).
func _worn_detail(slot: String) -> void:
	var it: Dictionary = Game.state["player"]["equipment"].get(slot, {})
	detail.add_child(UIKit.label("You wear this (%s)" % slot.capitalize(), 20, "body_italic"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Assets.panel_style("dark"))
	p.add_child(UIKit.rich(Items.tooltip(it), 20, true))
	detail.add_child(p)
	var iuid := int(it.get("uid", -1))
	detail.add_child(UIKit.button("Inspect — its maker, history and owners", func(): Events.open_panel.emit("item", {"uid": iuid}), 0))
	var off := UIKit.button("Take it off (back to the stores)", func():
		Game.unequip_player(slot)
		selected = Game.find_uid(iuid), 0)
	off.name = "TakeOff"
	detail.add_child(off)


func _study(uid: int) -> void:
	var c := Crafting.check_params("rune_cleansing_basin")
	Events.open_panel.emit("skillcheck", {"station": "rune_cleansing_basin", "count": 1, "speed": c["speed"], "zone": c["zone"],
		"title": "Studying the relic", "subtitle": "Wash away the grave-earth without damaging what lies beneath",
		"on_done": func(qs: Array):
			var res := Regions.identify(uid, float(qs[0]))
			if not res.is_empty():
				Events.open_panel.emit("reveal", {"item": res})})
