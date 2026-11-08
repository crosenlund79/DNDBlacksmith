## InkIcons — small ink icons beside headings and on buttons, one consistent idiom across panels.
## EN: Icons are the toolbar's ink drawings (ui/tb_*) and the iteration-010 set (ui/ic_*, ui/qt_*), drawn by
##     tools/art/make_ui_icons*.py. A missing texture simply leaves the text alone.
## DA: Små blæk-ikoner ved overskrifter og på knapper, ens på tværs af panelerne.
class_name InkIcons
extends RefCounted


static func tex(id: String) -> Texture2D:
	var full := id if id.contains("/") else "ui/" + id
	if not Assets.has_tex(full):
		return null
	return Assets.get_tex(full)


## A heading with its icon in front (icon about 1.3× the text height).
static func heading(icon_id: String, text: String, size := 24, font := "heading", color := UIKit.INK) -> HBoxContainer:
	var h := UIKit.hbox(8)
	var t := tex(icon_id)
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(size, size) * 1.3
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
	var l := UIKit.label(text, size, font, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## A UIKit button with a small icon before its text.
static func button(icon_id: String, text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := UIKit.button(text, cb, min_w)
	decorate(b, icon_id)
	return b


static func decorate(b: Button, icon_id: String) -> void:
	var t := tex(icon_id)
	if t == null:
		return
	b.icon = t
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_constant_override("h_separation", 8)
