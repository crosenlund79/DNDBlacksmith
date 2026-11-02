## MainMenu — EMBER & ASH title screen: aged ledger, ember light, real typography.
## DA: Titelskærm: gammel hovedbog, glødende lys og ægte typografi.
class_name MainMenu
extends Control

var main: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Assets.theme
	var bg := TextureRect.new()
	bg.texture = Assets.get_tex("ui/menu_background", Vector2i(1920, 1080))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	# embers drifting up from the forge (bottom-left)
	var em := FX.embers(70)
	em.position = Vector2(200, 1060)
	em.emission_sphere_radius = 220.0
	em.lifetime = 4.0
	em.initial_velocity_max = 90.0
	add_child(em)
	var col := VBoxContainer.new()
	col.position = Vector2(250, 120)
	col.custom_minimum_size = Vector2(700, 0)
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var hdr := UIKit.label("Ledger of Ember & Ash · the Forge at Brindlewick", 26, "heading_italic", Color("#4a3420"))
	col.add_child(hdr)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.custom_minimum_size = Vector2(700, 0)
	title.add_theme_font_override("normal_font", Assets.font("title"))
	title.add_theme_font_size_override("normal_font_size", 118)
	title.add_theme_color_override("default_color", Color("#20140c"))
	title.push_color(Color("#7e2418"))
	title.push_font(Assets.font("initial"), 170)
	title.add_text("E")
	title.pop()
	title.pop()
	title.add_text("mber & Ash")
	col.add_child(title)
	col.add_child(UIKit.label("A blacksmith's chronicle", 28, "heading_italic", Color("#5e421c")))
	col.add_child(UIKit.divider())
	var has_save := Saves.latest_slot() != ""
	var entries := [
		["I.", "Continue", func(): main.call("continue_game"), has_save],
		["II.", "New Game", func(): main.call("new_game"), true],
		["III.", "Load Game", func(): _sub(SavePanel.new("load")), has_save],
		["IV.", "Settings", func(): _sub(SettingsPanel.new()), true],
		["V.", "Credits", _credits, true],
		["VI.", "Quit", func(): get_tree().quit(), true],
	]
	for e in entries:
		var b := UIKit.button("%s   %s" % [e[0], e[1]], e[2], 520)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 34)
		b.disabled = not e[3]
		col.add_child(b)
	var ver := UIKit.label("v0.1 · first playable build", 20, "body_italic", Color("#c8b898"))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-420, -48)
	ver.size = Vector2(400, 30)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)


func _sub(w: UIWindow) -> void:
	add_child(w)


func _credits() -> void:
	var w := UIWindow.new("Credits", 900, 620)
	w.content.add_child(UIKit.rich("[b]Ember & Ash[/b] — first playable build.\n\nArt: procedural ink-and-parchment illustration pipeline (docs/visual_exploration, direction 80:20).\nAudio: procedurally synthesised effects, ambience and music.\nFonts (SIL Open Font License): IM Fell English & IM Fell English SC (Igino Marini), EB Garamond (Georg Duffner, Octavio Pardo), Grenze & Grenze Gotisch (Omnibus-Type). Licences in assets/fonts.\nEngine: Godot 4 (MIT).", 22))
	add_child(w)
