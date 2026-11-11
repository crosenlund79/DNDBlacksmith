## UIKit — small builders for the illustrated parchment interface.
## DA: Små byggefunktioner til den illustrerede pergament-brugerflade.
class_name UIKit
extends RefCounted

const INK := Color("#20140c")
const RUBRIC := Color("#7e2418")
const GILT := Color("#b8923e")
const PAPER := Color("#efe4cc")
## Quieter ink for secondary lines (hints, "unknown before day N").
const FADED := Color("#6a5a44")

## Living Workshop #47 — one set of sizes for the whole interface (on the 1920×1080 canvas; 1600×900 is the same canvas
## scaled by 0.83, so FS_MIN 16 still reads as ~13 px there). Panels built after #47 use these instead of literal numbers;
## the older builders keep their signatures and defaults (only the default button height went down, 46 → BUTTON_H).
const FS_TITLE := 34      # window titles (UIWindow; was 38)
const FS_HEADING := 24    # section headings
const FS_BODY := 20       # ordinary text
const FS_SMALL := 18      # secondary text, list rows
const FS_MIN := 16        # never smaller: the readability floor
const BUTTON_H := 38      # default button height (was 46)
const BUTTON_FS := 21     # default button text (the theme's 24 made every button oversized)
const BUTTON_SMALL_H := 32
const BUTTON_SMALL_FS := 18
const GAP := 8            # default spacing inside a panel


static func label(text: String, size := 22, font := "body", color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Only long text wraps: a wrapping Label in a grid/row cell with no width collapses to one
	# character per line. Short labels keep their natural width.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 48 else TextServer.AUTOWRAP_OFF
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


## A parchment button. #47: BUTTON_H high with BUTTON_FS text by default (a caller's own font-size override still
## wins); `min_w` as before. Keyboard focus and the click/hover sounds are unchanged.
static func button(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_w, 0.0), BUTTON_H)
	b.add_theme_font_override("font", Assets.font("heading"))   # the theme's button face, also outside a themed window
	b.add_theme_font_size_override("font_size", BUTTON_FS)
	b.pressed.connect(func(): Audio.play("sfx/ui_click", -4.0); cb.call())
	b.mouse_entered.connect(func(): Audio.play("sfx/ui_hover", -10.0))
	return b


## A small button for rows and secondary actions (list rows, filters, "Inspect").
static func small_button(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := button(text, cb, min_w)
	b.custom_minimum_size = Vector2(maxf(min_w, 0.0), BUTTON_SMALL_H)
	b.add_theme_font_size_override("font_size", BUTTON_SMALL_FS)
	return b


## A tab button for a row of tabs (toggle mode; `on` marks the open one in rubric ink).
static func tab_button(text: String, cb: Callable, on := false) -> Button:
	var b := small_button(text, cb)
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	b.add_theme_color_override("font_color", RUBRIC if on else INK)
	return b


## A section heading (FS_HEADING, the heading face).
static func heading(text: String, size := FS_HEADING) -> Label:
	return label(text, size, "heading", INK)


## A quiet secondary line (hints, honest gaps such as "no record before day 12"). A long note wraps; it then fills
## the row it is in and never narrows below 360 px (a wrapping label given no width would stack one letter per line
## in a row or a flow).
static func note(text: String, size := FS_SMALL) -> Label:
	var l := label(text, maxi(size, FS_MIN), "body_italic", FADED)
	if text.length() > 48:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 360
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## A faint row background for lists (save slots, ledger rows). `filled` false = an empty slot (only a hairline).
static func row_style(filled := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.05, 0.07 if filled else 0.0)
	sb.border_color = Color(0.13, 0.08, 0.05, 0.22)
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## A small coloured chip (a status word on a card: "Waiting at the counter", "Commission").
static func chip(text: String, col: Color, size := FS_MIN) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, "body_bold", col.darkened(0.25))
	p.add_child(l)
	return p


## A whole number with grouped thousands: 1234567 → "1,234,567" (#43: purses and stock counts stay readable).
static func num(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


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
