## DevCataloguePanel — the developer catalogue (route `dev_catalogue`, from F10's Developer Tools). Testing only.
## EN: Left: every item definition, searchable by name / id / type, filtered by kind. Right: the chosen item with
##     quantity, rarity and craftsmanship (where they apply) and "Spawn into stores"; below: money presets and a
##     custom amount. Everything spawned is marked as a developer item (DevTools) and never counts for fame.
## DA: Udviklerkatalog: søg alle genstande, vælg antal/sjældenhed/kvalitet og læg dem i lageret; tilføj penge.
class_name DevCataloguePanel
extends UIWindow

const ROW_LIMIT := 120

var query := ""
var filter := 0
var chosen := ""
var list_box: VBoxContainer
var detail: VBoxContainer
var count_label: Label
var out: RichTextLabel
var search_edit: LineEdit


func _init(start_query := "") -> void:
	query = start_query
	super._init("Developer catalogue — testing only (F10)", 1560, 880, true)
	name = "DevCatalogue"


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.rich("[color=#c8b898][i]Every item in the game. Spawned pieces are marked [b]Developer tools[/b] and never count for the Hall of Fame, Epic, names, objectives or knowledge.[/i][/color]", 18, true))
	var top := UIKit.hbox(10)
	search_edit = LineEdit.new()
	search_edit.name = "CatalogueSearch"
	search_edit.placeholder_text = "Search by name, id or type…"
	search_edit.text = query
	search_edit.clear_button_enabled = true
	search_edit.custom_minimum_size = Vector2(460, 44)
	search_edit.add_theme_font_size_override("font_size", 20)
	search_edit.text_changed.connect(func(t: String): query = t; _fill())
	top.add_child(search_edit)
	var ob := OptionButton.new()
	ob.name = "CatalogueFilter"
	for i in DevTools.FILTERS.size():
		ob.add_item(str(DevTools.FILTERS[i][0]), i)
	ob.add_theme_font_size_override("font_size", 18)
	ob.item_selected.connect(func(i: int): filter = i; _fill())
	top.add_child(ob)
	count_label = UIKit.label("", 18, "body_italic", UIKit.PAPER)
	top.add_child(count_label)
	content.add_child(top)
	var row := UIKit.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box = UIKit.vbox(2)
	var sc := UIKit.scroll(list_box, 560)
	sc.custom_minimum_size = Vector2(820, 560)
	row.add_child(sc)
	detail = UIKit.vbox(10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	content.add_child(row)
	content.add_child(_money_row())
	out = UIKit.rich("", 18, true)
	content.add_child(out)
	_fill()
	_detail()
	search_edit.call_deferred("grab_focus")


func _fill() -> void:
	UIKit.clear(list_box)
	var found := DevTools.search(query, filter)
	count_label.text = "%d item%s" % [found.size(), "" if found.size() == 1 else "s"]
	var n := 0
	for d in found:
		if n >= ROW_LIMIT:
			list_box.add_child(UIKit.label("… %d more — narrow the search." % (found.size() - ROW_LIMIT), 17, "body_italic", UIKit.PAPER))
			break
		list_box.add_child(_row(d))
		n += 1
	if found.is_empty():
		list_box.add_child(UIKit.label("Nothing matches “%s”." % query, 19, "body_italic", UIKit.PAPER))


func _row(d: Dictionary) -> Control:
	var id := str(d["id"])
	var b := Button.new()
	b.name = "Row_" + id
	b.custom_minimum_size = Vector2(0, 46)
	b.flat = id != chosen
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = Assets.get_tex("icons/" + str(d.get("icon", id)))
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 36)
	b.text = "  %s    · %s · %s" % [str(d.get("name", id)), id, Items.type_label({"def": id})]
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", UIKit.INK if id == chosen else UIKit.PAPER)
	b.add_theme_color_override("font_hover_color", Color("#ffd27a"))
	b.pressed.connect(func(): chosen = id; _fill(); _detail())
	return b


func _detail() -> void:
	UIKit.clear(detail)
	if chosen == "":
		detail.add_child(UIKit.label("Choose an item on the left.", 20, "body_italic", UIKit.PAPER))
		return
	var d := DB.item(chosen)
	var eq := DevTools.is_equipment_def(chosen)
	var h := UIKit.hbox(14)
	# a picture only (no uid, nothing made)
	var sample := {"uid": -1, "def": chosen, "name": str(d.get("name", chosen)), "qty": 1, "rarity": "common", "quality": 90.0,
		"stats": {}, "affixes": [], "sockets": []}
	var slot := ItemSlot.new(sample, 96.0)
	slot.inspectable = false
	h.add_child(slot)
	var v := UIKit.vbox(2)
	v.add_child(UIKit.label(str(d.get("name", chosen)), 28, "heading", UIKit.PAPER))
	v.add_child(UIKit.label("%s · id %s%s" % [Items.type_label({"def": chosen}), chosen, " · stacks" if bool(d.get("stack", false)) else ""], 17, "body_italic", UIKit.PAPER))
	h.add_child(v)
	detail.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(UIKit.label("Quantity", 19, "body_bold", UIKit.PAPER))
	var qty := SpinBox.new()
	qty.name = "SpawnQty"
	qty.min_value = 1
	qty.max_value = 999 if bool(d.get("stack", false)) else 20
	qty.value = 5 if bool(d.get("stack", false)) else 1
	grid.add_child(qty)
	var rar := OptionButton.new()
	rar.name = "SpawnRarity"
	if eq:
		grid.add_child(UIKit.label("Rarity", 19, "body_bold", UIKit.PAPER))
		var tags: Array = d.get("tags", [])
		if tags.has("unique") or tags.has("set"):
			rar.add_item("Unique" if tags.has("unique") else "Set")
			rar.disabled = true
		else:
			for r in DevTools.RARITY_CHOICES:
				rar.add_item(str(Items.RARITY_LABEL.get(r, r)))
		grid.add_child(rar)
	var ql := SpinBox.new()
	ql.name = "SpawnQuality"
	ql.min_value = 10
	ql.max_value = 125
	ql.value = 90
	ql.suffix = "%"
	if DevTools.has_quality(chosen):
		grid.add_child(UIKit.label("Craftsmanship", 19, "body_bold", UIKit.PAPER))
		grid.add_child(ql)
	detail.add_child(grid)
	var spawn := UIKit.button("Spawn into stores", func():
		var r := ""
		if eq and not rar.disabled:
			r = str(DevTools.RARITY_CHOICES[maxi(0, rar.selected)])
		var made := DevTools.spawn(chosen, int(qty.value), r, float(ql.value) if DevTools.has_quality(chosen) else -1.0)
		_say("%s ×%d spawned%s" % [str(d.get("name", chosen)), int(qty.value), (" (%s)" % Items.RARITY_LABEL.get(r, r)) if r != "" else ""] if not made.is_empty() else "Could not spawn it"), 320)
	spawn.name = "SpawnButton"
	detail.add_child(spawn)
	var desc := str(d.get("desc", ""))
	if desc != "":
		detail.add_child(UIKit.rich("[i][color=#c8b898]%s[/color][/i]" % desc, 17, true))


func _money_row() -> Control:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.label("Money", 24, "heading", UIKit.GILT))
	for amt in DevTools.MONEY_PRESETS:
		var a: int = amt
		h.add_child(UIKit.button("+%d g" % a, func(): DevTools.add_money(a); _say("%+d gold" % a), 0))
	var le := LineEdit.new()
	le.name = "MoneyAmount"
	le.placeholder_text = "custom (e.g. 2500 or -200)"
	le.custom_minimum_size = Vector2(260, 44)
	h.add_child(le)
	h.add_child(UIKit.button("Add", func():
		if not le.text.strip_edges().is_valid_int():
			_say("Type a whole number of gold first")
			return
		DevTools.add_money(int(le.text))
		_say("%+d gold" % int(le.text)), 0))
	h.add_child(UIKit.button("Back to Developer Tools", func():
		close()
		Events.open_panel.emit.call_deferred("dev_panel", {}), 0))
	return h


func _say(t: String) -> void:
	out.text = "[color=#c8b898]%s — %d g in the purse, %d things in the stores[/color]" % [t, Game.gold(), Game.inventory().size()]
