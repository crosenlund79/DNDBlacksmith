## IronfrontCard — one Ironfront card drawn at any size: face (or back), live strength in the brass seal.
## EN: The face art carries name, row, abilities and flavour; the strength is drawn here because it
##     changes in play (green when boosted, red when damaged or smothered by weather).
##     The visible parts live in `inner`, so containers can lay the card out while tweens slide `inner`.
## DA: Et Ironfront-kort i vilkårlig størrelse; styrken tegnes ovenpå, fordi den ændrer sig.
class_name IronfrontCard
extends Control

signal hovered(card: IronfrontCard)
signal clicked(card: IronfrontCard)

var inst: Dictionary = {}      # match instance {uid, id, str, ...} or {"id": id}
var def: Dictionary = {}
var face_down := false
var strength := -1             # -1: show nothing (tactics, collection)
var base_str := 0
var selected := false
var highlight := false
var inner: Control
var _tex: TextureRect
var _num: Label


func _init(instance: Dictionary, w := 66.0, hidden := false, shown_strength := -1) -> void:
	inst = instance
	def = Ironfront.card(str(inst.get("id", "")))
	face_down = hidden
	strength = shown_strength
	base_str = int(def.get("str", 0))
	custom_minimum_size = Vector2(w, w * 260.0 / 180.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	inner = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size = custom_minimum_size
	add_child(inner)
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.size = custom_minimum_size
	_tex.texture = Assets.get_tex("ironfront/back" if hidden else "cards/" + str(inst.get("id", "")), Vector2i(180, 260))
	inner.add_child(_tex)
	if not hidden and def.get("type", "") == "unit" and strength >= 0:
		_num = Label.new()
		_num.text = str(strength)
		var fs := int(maxf(12.0, w * 0.2))
		_num.add_theme_font_override("font", Assets.font("initial"))
		_num.add_theme_font_size_override("font_size", fs)
		var col := UIKit.INK
		if strength > base_str:
			col = Color("#1f5a1c")
		elif strength < base_str:
			col = Color("#8e1c10")
		_num.add_theme_color_override("font_color", col)
		_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var c := Vector2(55.0 / 360.0, 55.0 / 520.0) * custom_minimum_size
		_num.size = Vector2(w * 0.3, w * 0.3)
		_num.position = c - _num.size / 2 + Vector2(0, -w * 0.01)
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(_num)
	mouse_entered.connect(func(): hovered.emit(self); queue_redraw())
	mouse_exited.connect(queue_redraw)
	resized.connect(_on_resized)


func _on_resized() -> void:
	inner.size = size
	_tex.size = size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


func _draw() -> void:
	var r := Rect2(inner.position, size).grow(2)
	if selected:
		draw_rect(r.grow(3), Color("#e6b84a"), false, 4.0)
	elif highlight:
		draw_rect(r.grow(2), Color("#e6702a", 0.9), false, 3.0)
	elif get_global_rect().has_point(get_global_mouse_position()):
		draw_rect(r, Color("#efe4cc", 0.7), false, 2.0)


func set_selected(v: bool) -> void:
	selected = v
	inner.position.y = -14.0 if v else 0.0
	queue_redraw()


## Slides the visible card in from an offset (the container keeps the slot).
func slide_from(offset: Vector2, delay := 0.0) -> void:
	inner.position = offset
	inner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(inner, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(inner, "position", Vector2.ZERO, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
