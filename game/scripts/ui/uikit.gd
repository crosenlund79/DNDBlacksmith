## UIKit — small builders for the illustrated parchment interface.
## DA: Små byggefunktioner til den illustrerede pergament-brugerflade.
class_name UIKit
extends RefCounted

const INK := Color("#20140c")
const RUBRIC := Color("#7e2418")
const GILT := Color("#b8923e")
const PAPER := Color("#efe4cc")


static func label(text: String, size := 22, font := "body", color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size := 40) -> Label:
	return label(text, size, "title", INK)


static func rich(bbcode: String, size := 22, dark := false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_override("normal_font", Assets.font("body"))
	r.add_theme_font_override("italics_font", Assets.font("body_italic"))
	r.add_theme_font_override("bold_font", Assets.font("body_bold"))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", PAPER if dark else INK)
	r.custom_minimum_size = Vector2(200, 0)
	return r


static func button(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0:
		b.custom_minimum_size = Vector2(min_w, 46)
	else:
		b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func(): Audio.play("sfx/ui_click", -4.0); cb.call())
	b.mouse_entered.connect(func(): Audio.play("sfx/ui_hover", -10.0))
	return b


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func divider() -> Control:
	if Assets.has_tex("ui/divider"):
		var t := TextureRect.new()
		t.texture = Assets.get_tex("ui/divider")
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.custom_minimum_size = Vector2(0, 22)
		return t
	return HSeparator.new()


static func portrait(id: String, size := 128.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.get_tex(id, Vector2i(256, 256))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	return t


static func icon(id: String, size := 48.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.get_tex(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	return t


static func bar(value: float, max_value := 1.0, w := 160.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = max_value
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, 12)
	return p


static func scroll(child: Control, h := 520.0) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, h)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
