## ItemSlot — an inventory slot with rarity border, legendary star and quantity.
## DA: En inventarplads med sjældenhedsramme, legendarisk stjerne og antal.
class_name ItemSlot
extends Control

signal clicked(item: Dictionary)

var item: Dictionary = {}
var selected := false
var hidden_item := false   # used by the loot reveal ("?")
var size_px := 72.0
var inspectable := true    # right-click opens the item's story (ItemPanel); off inside the panel itself
var show_condition := false   # a durability strip along the bottom edge (equipment sheets), red cross when broken


func _init(it := {}, px := 72.0) -> void:
	item = it
	size_px = px
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(func(): UIRoot.hide_tooltip())


func _on_hover() -> void:
	if not item.is_empty() and not hidden_item:
		UIRoot.show_tooltip(Items.tooltip(item))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(item)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and inspectable \
			and not item.is_empty() and not hidden_item and Items.is_equipment(item) and int(item.get("uid", -1)) > 0:
		UIRoot.hide_tooltip()
		Events.open_panel.emit("item", {"uid": int(item["uid"])})
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(size_px, size_px))
	draw_rect(r, Color(0.13, 0.08, 0.05, 0.18))
	if Assets.has_tex("ui/slot"):
		draw_texture_rect(Assets.get_tex("ui/slot"), r, false)
	if item.is_empty():
		draw_rect(r, Color(0.13, 0.08, 0.05, 0.6), false, 2.0)
		return
	if hidden_item:
		draw_rect(r, Color(0.13, 0.08, 0.05, 0.85), false, 2.0)
		var f := Assets.font("title")
		draw_string(f, Vector2(0, size_px * 0.66), "?", HORIZONTAL_ALIGNMENT_CENTER, size_px, int(size_px * 0.5), Color(0.13, 0.08, 0.05, 0.6))
		return
	var rar: String = item.get("rarity", "common")
	var bc: Color = Items.COL_BORDER.get(rar, Color.GRAY)
	if rar != "common":
		draw_rect(r.grow(-3), Color(bc, 0.18))
	if item.get("arcane_glow", false):
		# bound magic: violet markings glow around the piece
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
		draw_rect(r.grow(-3), Color(0.62, 0.45, 1.0, 0.16 + 0.12 * pulse))
	draw_texture_rect(Assets.get_tex(Items.icon_id(item)), r.grow(-6), false, Color(1, 0.86, 1.0) if item.get("arcane_glow", false) else Color.WHITE)
	draw_rect(r, bc, false, 3.0 if rar != "common" else 2.0)
	if item.has("epic"):
		# Epic distinction: a rose-crimson inner frame with a slow glow, and a small ✦ mark
		var ep := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 520.0)
		draw_rect(r.grow(-5), Color(Recognition.EPIC_COLOR, 0.55 + 0.35 * ep), false, 2.5)
		draw_rect(r.grow(-1), Color(Recognition.EPIC_COLOR, 0.25 * ep), false, 4.0)
		var fe := Assets.font("body_bold")
		draw_string_outline(fe, Vector2(size_px - 22, size_px - 6), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color("#20140c"))
		draw_string(fe, Vector2(size_px - 22, size_px - 6), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Recognition.EPIC_COLOR)
	if selected:
		draw_rect(r.grow(2), Color("#e6702a"), false, 3.0)
	if item.get("star", false):
		draw_texture_rect(Assets.get_tex("icons/star", Vector2i(32, 32)), Rect2(size_px - 26, 2, 24, 24), false)
	if int(item.get("qty", 1)) > 1:
		# #43: the count always fits the slot — grouped digits, shortened (9.9k) only when it would not fit, sized to the
		# slot; the exact number is in the tooltip
		var f2 := Assets.font("body_bold")
		var fs := qty_font_size(size_px)
		var qt := qty_text(int(item["qty"]), size_px)
		draw_string_outline(f2, Vector2(4, size_px - 6), qt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color("#efe4cc"))
		draw_string(f2, Vector2(4, size_px - 6), qt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#20140c"))
	if size_px >= 48.0 and int(item.get("qty", 1)) <= 1 and Provenance.is_mine(item):
		# the smith's own work: the Ironhand mark, struck small in the corner
		var ms := clampf(size_px * 0.3, 18.0, 30.0)
		draw_texture_rect(Assets.get_tex("marks/ironhand", Vector2i(32, 32)), Rect2(3, size_px - ms - 3, ms, ms), false, Color(1, 1, 1, 0.92))
	elif size_px >= 48.0 and int(item.get("qty", 1)) <= 1 and Items.is_equipment(item) and ApprenticeUI.is_apprentice_work(item):
		# iteration 012: an apprentice's piece carries their punch-mark
		var ms2 := clampf(size_px * 0.3, 18.0, 30.0)
		draw_texture_rect(Assets.get_tex(ItemStory.mark_icon(item), Vector2i(32, 32)), Rect2(3, size_px - ms2 - 3, ms2, ms2), false, Color(1, 1, 1, 0.92))
	if item.get("for_sale", false):
		draw_texture_rect(Assets.get_tex("icons/gold", Vector2i(32, 32)), Rect2(2, 2, 20, 20), false)
	if show_condition and Items.is_equipment(item):
		_draw_condition()


## Durability along the bottom edge: green while sound, amber when worn, red when badly worn; a broken piece is crossed.
func _draw_condition() -> void:
	var st: Dictionary = item.get("stats", {})
	var broken: bool = item.get("broken", false)
	if st.has("durability_max") and float(st["durability_max"]) > 0.0:
		var f := Items.durability_frac(item)
		var col := Color("#4c7a34") if f >= 0.5 else (Color("#b8862e") if f >= Items.WORN else Color("#a8321e"))   # red = needs mending
		var h := clampf(size_px * 0.07, 4.0, 7.0)
		var r := Rect2(4, size_px - h - 3, size_px - 8, h)
		draw_rect(r, Color(0.13, 0.08, 0.05, 0.55))
		draw_rect(Rect2(r.position, Vector2(r.size.x * (0.0 if broken else f), r.size.y)), col)
	if broken:
		var c := Color("#7e2418")
		draw_line(Vector2(6, 6), Vector2(size_px - 6, size_px - 6), c, 3.0, true)
		draw_line(Vector2(size_px - 6, 6), Vector2(6, size_px - 6), Color(c, 0.6), 2.0, true)


## The quantity count's font size for a slot of `px` (18 on the usual 72 px slot, never below 14).
static func qty_font_size(px: float) -> int:
	return int(clampf(px * 0.28, 14.0, 18.0))


## The quantity as drawn on a slot of `px`: "9,898" when it fits inside the slot (4 px each side), else "9.9k", "12k"
## or "1.2M" — whichever first fits.
static func qty_text(n: int, px: float) -> String:
	var f := Assets.font("body_bold")
	var fs := qty_font_size(px)
	var room := px - 8.0
	var tries: Array[String] = [UIKit.num(n)]
	if n >= 1000:
		tries.append(("%.1fk" % (n / 1000.0)).replace(".0k", "k"))
		tries.append("%dk" % int(n / 1000))
	if n >= 1000000:
		tries.append(("%.1fM" % (n / 1000000.0)).replace(".0M", "M"))
		tries.append("%dM" % int(n / 1000000))
	for t in tries:
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
			return t
	return tries[-1]


func refresh() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if not item.is_empty() and (item.get("arcane_glow", false) or item.has("epic")):
		queue_redraw()
