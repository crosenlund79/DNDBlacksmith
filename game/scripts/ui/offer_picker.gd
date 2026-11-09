## OfferPicker — offering a piece to an adventurer at the counter (Milestone A2, observation 9).
## EN: Replaces the long list of name buttons with a compact grid of item slots (rarity frames, the usual tooltip on
##     hover, right-click to inspect; a ✓ marks pieces they would buy, those they would not are dimmed) and a details
##     view: the selected piece against what they wear in that slot, the price, the verdict in their terms (would buy /
##     why not, matches the request) and an explicit "Sell for N g" button — choosing a piece never sells it. The sale
##     runs through Shop.sell_to, the same mechanics the steward and consultations use.
## DA: Kompakt valg af en genstand til en eventyrer: gitter med rammer, detaljer (deres stykke mod dette, pris, svar)
##     og en tydelig "Sælg for N g".
class_name OfferPicker
extends HBoxContainer

const SLOT_PX := 60.0
const COLS := 8
const ROWS_SHOWN := 3
const DETAIL_W := 540.0

var npc := ""
var req: Dictionary = {}
var on_sold: Callable
var sel_uid := -1
var grid: GridContainer
var detail: VBoxContainer
var cells := {}   # uid -> the cell Control


func _init(npc_id: String, request: Dictionary, sold_cb := Callable()) -> void:
	name = "OfferPicker"
	npc = npc_id
	req = request
	on_sold = sold_cb
	add_theme_constant_override("separation", 16)


func _ready() -> void:
	var left := UIKit.vbox(4)
	var cap := UIKit.label("On display — ✓ they would buy it (green: what they asked for)", 17, "heading_italic", UIKit.RUBRIC)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(cap)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var list := candidates(npc, req)
	var rows := int(ceil(float(list.size()) / COLS))
	var sc := UIKit.scroll(grid, mini(rows, ROWS_SHOWN) * (SLOT_PX + 6.0))
	sc.name = "OfferGridScroll"
	sc.custom_minimum_size.x = COLS * (SLOT_PX + 6.0) + 14.0
	left.add_child(sc)
	var foot := UIKit.label("%d piece%s · hover to read, right-click to inspect" % [list.size(), "" if list.size() == 1 else "s"], 15, "body_italic", Color("#5e421c"))
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(foot)
	add_child(left)
	for c in list:
		grid.add_child(_cell(c))
	detail = UIKit.vbox(6)
	detail.name = "OfferDetail"
	detail.custom_minimum_size = Vector2(DETAIL_W, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detail)
	# start on the best piece they would buy (nothing is sold until the smith presses Sell)
	for c in list:
		if str(c["why"]) == "":
			sel_uid = int(c["item"]["uid"])
			break
	_detail()


## The pieces that can be offered: [{item, price, why ("" = would buy), fits (matches the request)}], those they
## would buy first (matching the request before others), then by rating.
static func candidates(npc_id: String, request: Dictionary) -> Array:
	var a := Adv.get_a(npc_id)
	var out := []
	if a.is_empty():
		return out
	var married: bool = Social.spouse() == npc_id
	for it in Game.inventory():
		if not Items.is_equipment(it) or (not it.get("for_sale", false) and not married):
			continue
		var price := Shop.price_of(it)
		var why := Adv.purchase_check(a, it, price)
		var fits: bool = Items.slot(it) == str(request.get("slot", "")) and Items.stat(it, str(request.get("stat", ""))) >= int(request.get("min", 0))
		out.append({"item": it, "price": 0 if married else price, "why": why, "fits": fits})
	out.sort_custom(func(x, y):
		var kx := (0 if str(x["why"]) == "" else 2) + (0 if bool(x["fits"]) else 1)
		var ky := (0 if str(y["why"]) == "" else 2) + (0 if bool(y["fits"]) else 1)
		if kx != ky:
			return kx < ky
		return Items.score(x["item"]) > Items.score(y["item"]))
	return out


func _cell(c: Dictionary) -> Control:
	var it: Dictionary = c["item"]
	var uid := int(it["uid"])
	var box := Control.new()
	box.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	var s := ItemSlot.new(it, SLOT_PX)
	s.selected = uid == sel_uid
	s.clicked.connect(func(_x): select_uid(uid))
	if str(c["why"]) != "":
		s.modulate = Color(0.62, 0.58, 0.52, 0.55)   # they would not buy it: dimmed (the tooltip and details say why)
	box.add_child(s)
	if str(c["why"]) == "":
		# a round badge in the bottom-left corner (the top-left holds the display coin): green = matches the request
		var badge := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#2f6a1e") if bool(c["fits"]) else Color("#6a5a12")
		sb.border_color = UIKit.PAPER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		badge.add_theme_stylebox_override("panel", sb)
		var mark := UIKit.label("✓", 14, "body_bold", UIKit.PAPER)
		badge.add_child(mark)
		badge.position = Vector2(2, SLOT_PX - 22)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(badge)
	cells[uid] = s
	return box


## Shows this piece in the details view (choosing never sells).
func select_uid(uid: int) -> void:
	if cells.has(sel_uid) and is_instance_valid(cells[sel_uid]):
		(cells[sel_uid] as ItemSlot).selected = false
		(cells[sel_uid] as ItemSlot).queue_redraw()
	sel_uid = uid
	if cells.has(uid) and is_instance_valid(cells[uid]):
		(cells[uid] as ItemSlot).selected = true
		(cells[uid] as ItemSlot).queue_redraw()
		var sc := find_child("OfferGridScroll", true, false) as ScrollContainer
		if sc != null:
			sc.ensure_control_visible.call_deferred(cells[uid])
	_detail()


func _current() -> Dictionary:
	for c in candidates(npc, req):
		if int(c["item"]["uid"]) == sel_uid:
			return c
	return {}


func _detail() -> void:
	for ch in detail.get_children():   # removed at once, so the new Sell button is the only one in the tree
		detail.remove_child(ch)
		ch.queue_free()
	var a := Adv.get_a(npc)
	var c := _current()
	if a.is_empty() or c.is_empty():
		var hint := UIKit.label("Choose a piece to see it against what %s wears." % str(a.get("name", "they")).split(" ")[0], 19, "body_italic")
		hint.custom_minimum_size.x = DETAIL_W
		detail.add_child(hint)
		return
	var it: Dictionary = c["item"]
	var sl := Items.slot(it)
	var cur: Dictionary = a.get("equipment", {}).get(sl, {})
	var first := str(a["name"]).split(" ")[0]
	var nm := UIKit.label(Items.display_name(it), 24, "heading", Items.color(it, false))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = DETAIL_W
	detail.add_child(nm)
	# theirs → this one
	var row := UIKit.hbox(10)
	var theirs := UIKit.vbox(2)
	var ts := ItemSlot.new(cur, 64.0)
	theirs.add_child(ts)
	theirs.add_child(UIKit.label("theirs", 15, "body_italic", Color("#5e421c")))
	row.add_child(theirs)
	var arrow := UIKit.label("→", 30, "body_bold")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var mine := UIKit.vbox(2)
	mine.add_child(ItemSlot.new(it, 64.0))
	mine.add_child(UIKit.label("yours", 15, "body_italic", Color("#5e421c")))
	row.add_child(mine)
	var facts := UIKit.vbox(2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stat := Shop.stat_for_slot(sl)
	var d := Items.stat(it, stat) - Items.stat(cur, stat)
	facts.add_child(_line("%s: [b]%s[/b]" % [Adv._slot_name(sl), str(cur.get("name", "nothing worn")) if not cur.is_empty() else "nothing worn"], 18))
	facts.add_child(_line("%s %d → [b]%d[/b] [color=%s](%s%d)[/color]" % [stat.capitalize(), Items.stat(cur, stat), Items.stat(it, stat),
		"#26622f" if d > 0 else ("#7e2418" if d < 0 else "#5e421c"), "+" if d >= 0 else "−", absi(d)], 18))
	facts.add_child(_line("Rated %d → [b]%d[/b]" % [int(Items.score(cur)), int(Items.score(it))], 18))
	row.add_child(facts)
	detail.add_child(row)
	# price and verdict
	var price := int(c["price"])
	var why := str(c["why"])
	var verdict := ""
	if why == "":
		verdict = "[color=#26622f][b]✓ %s would buy it[/b][/color]%s" % [first, " — and it matches the request." if bool(c["fits"]) else "."]
	else:
		verdict = "[color=#7e2418][b]✗ %s %s[/b][/color]" % [first, why]
		if why == "can't afford it":
			verdict += " (%d g in the purse)." % int(a.get("gold", 0))
		else:
			verdict += "."
	detail.add_child(_line("Price: [b]%s[/b]" % ("free (your spouse)" if Social.spouse() == npc else "%d g" % price), 19))
	detail.add_child(_line(verdict, 19))
	var bh := UIKit.hbox(8)
	var uid := int(it["uid"])
	var sell := UIKit.button("Sell for %d g" % price if Social.spouse() != npc else "Give it to %s" % first, func(): _sell(uid), 220)
	sell.name = "SellButton"
	sell.disabled = why != ""
	sell.tooltip_text = ("%s %s." % [first, why]) if why != "" else "%s pays %d g and takes it now." % [first, price]
	bh.add_child(sell)
	var cmp := UIKit.button("⇄ Compare", func(): Events.open_panel.emit("dossier", {"id": npc, "compare": uid}), 0)
	cmp.tooltip_text = "Their full sheet with this piece against what they wear"
	bh.add_child(cmp)
	bh.add_child(UIKit.button("Inspect", func(): Events.open_panel.emit("item", {"uid": uid}), 0))
	detail.add_child(bh)


## One line of rich text that never wraps (its height does not depend on the width it is given).
static func _line(bb: String, size: int) -> RichTextLabel:
	var r := UIKit.rich(bb, size)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.custom_minimum_size = Vector2(0, 0)
	return r


func _sell(uid: int) -> void:
	var a := Adv.get_a(npc)
	var it := Game.find_uid(uid)
	var nm := str(it.get("name", "it"))
	var err := Shop.sell_to(npc, uid)
	Events.toast.emit(err if err != "" else "%s takes %s." % [a.get("name", "They"), ("the " + nm) if not nm.contains(",") else nm], "bad" if err != "" else "good")
	if on_sold.is_valid():
		on_sold.call()
