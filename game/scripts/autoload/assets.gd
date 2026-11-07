## Assets — sprite/texture/font template & override system.
## EN: Shipped art is TEMPLATE art: res://assets/sprites/<dir>/template_<name>.png.
##     get_tex("stations/forge") resolves, in order:
##       1. user://overrides/sprites/stations/forge.png        (modder / artist override, outside the project)
##       2. res://assets/sprites/stations/forge.png            (a user-provided asset with the same name and no
##                                                                template_ prefix — replaces the template, no code change)
##       3. res://assets/sprites/stations/template_forge.png   (the shipped Claude-made template)
##       4. a generated placeholder (parchment card with the id) so missing art never crashes.
##     Fonts and the shared Theme are also built here.
## DA: get_tex("stations/forge") slår op i rækkefølge: brugeroverskrivning, medfølgende grafik,
##     og ellers en genereret pladsholder, så manglende grafik aldrig får spillet til at gå ned.
##     Skrifttyper og det fælles Theme bygges også her.
extends Node

const SPRITE_ROOT := "res://assets/sprites/"
const OVERRIDE_ROOT := "user://overrides/sprites/"
const FONT_ROOT := "res://assets/fonts/"

var _cache := {}
var missing: Array[String] = []
var fonts := {}
var theme: Theme


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OVERRIDE_ROOT)
	_load_fonts()
	theme = _build_theme()


func has_tex(id: String) -> bool:
	return FileAccess.file_exists(OVERRIDE_ROOT + id + ".png") or _exists(SPRITE_ROOT + id + ".png") \
		or _exists(SPRITE_ROOT + template_id(id) + ".png")


## "stations/forge" → "stations/template_forge"
static func template_id(id: String) -> String:
	var slash := id.rfind("/")
	return id.substr(0, slash + 1) + "template_" + id.substr(slash + 1)


func _exists(p: String) -> bool:
	return ResourceLoader.exists(p) or FileAccess.file_exists(p)


func _load_shipped(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p)
	if FileAccess.file_exists(p):
		return _load_raw(p)
	return null


func get_tex(id: String, fallback_size := Vector2i(64, 64)) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	var ov := OVERRIDE_ROOT + id + ".png"
	if FileAccess.file_exists(ov):
		tex = _load_raw(ov)
	if tex == null:
		tex = _load_shipped(SPRITE_ROOT + id + ".png")              # user-provided, same name
	if tex == null:
		tex = _load_shipped(SPRITE_ROOT + template_id(id) + ".png") # shipped template
	if tex == null:
		if not missing.has(id):
			missing.append(id)
			Log.warn("Missing sprite '%s' — using placeholder" % id)
		tex = _placeholder(id, fallback_size)
	_cache[id] = tex
	return tex


func _load_raw(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _placeholder(id: String, size: Vector2i) -> Texture2D:
	var img := Image.create(max(size.x, 8), max(size.y, 8), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.86, 0.78, 0.6, 0.85))
	var ink := Color(0.13, 0.08, 0.05)
	for x in img.get_width():
		img.set_pixel(x, 0, ink)
		img.set_pixel(x, img.get_height() - 1, ink)
	for y in img.get_height():
		img.set_pixel(0, y, ink)
		img.set_pixel(img.get_width() - 1, y, ink)
		var d := int(float(y) / img.get_height() * img.get_width())
		if d < img.get_width():
			img.set_pixel(d, y, Color(0.5, 0.14, 0.09))
	return ImageTexture.create_from_image(img)


## Slices a character sheet (6 cols x 4 rows of 128 px) into SpriteFrames.
## Rows: 0 S, 1 E, 2 N, 3 W. Cols 0-1 idle, 2-5 walk.
func char_frames(sprite_id: String) -> SpriteFrames:
	var key := "frames:" + sprite_id
	if _cache.has(key):
		return _cache[key]
	var sheet := get_tex(sprite_id, Vector2i(768, 512))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var dirs := ["s", "e", "n", "w"]
	var cell := Vector2(sheet.get_width() / 6.0, sheet.get_height() / 4.0)
	for r in 4:
		for anim in ["idle", "walk"]:
			var name: String = anim + "_" + dirs[r]
			frames.add_animation(name)
			frames.set_animation_loop(name, true)
			frames.set_animation_speed(name, 2.0 if anim == "idle" else 8.0)
			var cols := [0, 1] if anim == "idle" else [2, 3, 4, 5]
			for c in cols:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(c * cell.x, r * cell.y, cell.x, cell.y)
				frames.add_frame(name, at)
	_cache[key] = frames
	return frames


# ------------------------------------------------------------------ fonts & theme
const FONT_FILES := {
	"title": "im-fell-english-sc-latin-400-normal.woff2",
	"heading": "im-fell-english-latin-400-normal.woff2",
	"heading_italic": "im-fell-english-latin-400-italic.woff2",
	"body": "eb-garamond-latin-400-normal.woff2",
	"body_italic": "eb-garamond-latin-400-italic.woff2",
	"body_bold": "eb-garamond-latin-600-normal.woff2",
	"initial": "grenze-latin-800-normal.woff2",
	"blackletter": "grenze-gotisch-latin-800-normal.woff2",
}


func _load_fonts() -> void:
	for key in FONT_FILES:
		var path: String = FONT_ROOT + FONT_FILES[key]
		var f: Font = null
		if ResourceLoader.exists(path):
			f = load(path)
		elif FileAccess.file_exists(path):
			var ff := FontFile.new()
			if ff.load_dynamic_font(path) == OK:
				f = ff
		if f == null:
			Log.warn("Font '%s' missing — using engine default" % key)
			f = ThemeDB.fallback_font
		fonts[key] = f


func font(key: String) -> Font:
	return fonts.get(key, ThemeDB.fallback_font)


func panel_style(kind := "parchment") -> StyleBox:
	var id := "ui/panel_parchment" if kind == "parchment" else "ui/panel_dark"
	if has_tex(id):
		var sb := StyleBoxTexture.new()
		sb.texture = get_tex(id)
		sb.texture_margin_left = 48
		sb.texture_margin_right = 48
		sb.texture_margin_top = 48
		sb.texture_margin_bottom = 48
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 24
		sb.content_margin_bottom = 24
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = Color("#e6d4a8") if kind == "parchment" else Color("#1e140c")
	f.border_color = Color("#20140c") if kind == "parchment" else Color("#b8923e")
	f.set_border_width_all(3)
	f.set_corner_radius_all(4)
	f.set_content_margin_all(22)
	f.shadow_color = Color(0, 0, 0, 0.45)
	f.shadow_size = 10
	return f


func _button_style(state: String) -> StyleBox:
	var id := "ui/button_" + state
	if has_tex(id):
		var sb := StyleBoxTexture.new()
		sb.texture = get_tex(id)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			sb.set_texture_margin(side, 18)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = {"normal": Color("#dcc79a"), "hover": Color("#ecc98a"), "pressed": Color("#b89a66"), "disabled": Color("#cdbd9a", 0.5)}.get(state, Color("#dcc79a"))
	f.border_color = Color("#20140c") if state != "hover" else Color("#e6702a")
	f.set_border_width_all(2)
	f.set_corner_radius_all(3)
	f.set_content_margin_all(8)
	return f


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 22
	var ink := Color("#20140c")
	t.set_color("font_color", "Label", ink)
	t.set_color("default_color", "RichTextLabel", ink)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("italics_font", "RichTextLabel", font("body_italic"))
	t.set_font("bold_font", "RichTextLabel", font("body_bold"))
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "Button", _button_style(s))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#e6702a")
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", font("heading"))
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", Color("#7e2418"))
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(0.13, 0.08, 0.05, 0.4))
	t.set_stylebox("panel", "PanelContainer", panel_style("parchment"))
	t.set_stylebox("panel", "Panel", panel_style("parchment"))
	var line := StyleBoxFlat.new()
	line.bg_color = Color(1, 1, 1, 0.35)
	line.border_color = ink
	line.set_border_width_all(1)
	line.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_color("font_color", "LineEdit", ink)
	t.set_stylebox("normal", "SpinBox", line)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.13, 0.08, 0.05, 0.25)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#7e2418")
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", ink)
	t.set_color("font_color", "CheckBox", ink)
	t.set_color("font_hover_color", "CheckBox", Color("#7e2418"))
	t.set_font_size("font_size", "TooltipLabel", 20)
	t.set_color("font_color", "TooltipLabel", Color("#efe4cc"))
	t.set_stylebox("panel", "TooltipPanel", panel_style("dark"))
	var sep := StyleBoxLine.new()
	sep.color = Color(0.13, 0.08, 0.05, 0.5)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	return t
