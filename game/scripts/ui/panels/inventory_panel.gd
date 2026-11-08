## InventoryPanel — stores, the smith's own equipment and stock-for-sale toggles.
## DA: Lager, smedens eget udstyr og markering af varer til salg.
class_name InventoryPanel
extends UIWindow

var grid: GridContainer
var detail: VBoxContainer
var selected: Dictionary = {}
var filter := "all"


func _init() -> void:
	super._init("Stores & Equipment", 1500, 820)


func _ready() -> void:
	super._ready()
	var tabs := UIKit.hbox(8)
	for f in [["all", "Everything"], ["equipment", "Equipment"], ["materials", "Materials"], ["magic", "Runes & Alchemy"], ["relics", "Relics"]]:
		var key: String = f[0]
		tabs.add_child(UIKit.button(f[1], func(): filter = key; _fill(), 0))
	content.add_child(tabs)
	var h := UIKit.hbox(20)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid = GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var sc := UIKit.scroll(grid, 600)
	sc.custom_minimum_size = Vector2(980, 600)
	h.add_child(sc)
	detail = UIKit.vbox(8)
	detail.custom_minimum_size = Vector2(420, 0)
	h.add_child(detail)
	content.add_child(h)
	Events.inventory_changed.connect(_fill)
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
	for it in inv:
		if not _match(it):
			continue
		var s := ItemSlot.new(it, 72.0)
		s.selected = not selected.is_empty() and int(selected.get("uid", -1)) == int(it["uid"])
		s.clicked.connect(_select)
		grid.add_child(s)
	_detail()


func _select(it: Dictionary) -> void:
	selected = it
	_fill()


func _detail() -> void:
	UIKit.clear(detail)
	detail.add_child(UIKit.label("Worn by Brannoc", 26, "heading"))
	var eq: Dictionary = Game.state["player"]["equipment"]
	var row := UIKit.hbox(6)
	for s in ["weapon", "armor", "helmet", "gloves", "boots", "ring"]:
		var it: Dictionary = eq.get(s, {})
		var sl := ItemSlot.new(it, 60.0)
		sl.tooltip_text = s.capitalize() if it.is_empty() else ""
		row.add_child(sl)
	detail.add_child(row)
	detail.add_child(UIKit.label("%d gold · %d items" % [Game.gold(), Game.inventory().size()], 22, "body_bold", UIKit.RUBRIC))
	detail.add_child(UIKit.divider())
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
			it["for_sale"] = not fs
			Events.inventory_changed.emit(), 0))
	if not Items.is_equipment(it) and DB.item(it["def"]).get("type", "") in ["potion", "material", "relic"] and not Regions.is_unidentified(it):
		var tr: bool = it.get("trade", false)
		detail.add_child(UIKit.button("Keep it at home" if tr else "Send with the next trade run", func():
			it["trade"] = not tr
			Events.inventory_changed.emit(), 0))
	if Items.is_equipment(it):
		detail.add_child(UIKit.button("Equip on Brannoc", func(): Game.equip_player(int(it["uid"])); selected = {}, 0))
		var sale: bool = it.get("for_sale", false)
		detail.add_child(UIKit.button("Remove from display" if sale else "Display for sale (%d g)" % Shop.price_of(it), func():
			it["for_sale"] = not sale
			Events.inventory_changed.emit(), 0))
		if sale:
			var ph := UIKit.hbox()
			ph.add_child(UIKit.label("Price:", 20))
			var sb := SpinBox.new()
			sb.min_value = 1
			sb.max_value = 99999
			sb.value = Shop.price_of(it)
			sb.value_changed.connect(func(v): it["price"] = int(v))
			ph.add_child(sb)
			detail.add_child(ph)
	if it["def"] == "potion_healing":
		detail.add_child(UIKit.label("Healing draughts make thoughtful gifts.", 18, "body_italic"))


func _study(uid: int) -> void:
	var c := Crafting.check_params("rune_cleansing_basin")
	Events.open_panel.emit("skillcheck", {"station": "rune_cleansing_basin", "count": 1, "speed": c["speed"], "zone": c["zone"],
		"title": "Studying the relic", "subtitle": "Wash away the grave-earth without damaging what lies beneath",
		"on_done": func(qs: Array):
			var res := Regions.identify(uid, float(qs[0]))
			if not res.is_empty():
				Events.open_panel.emit("reveal", {"item": res})})
