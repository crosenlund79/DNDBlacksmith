## MemorialPanel — a small quiet window for remembrance: a headstone read close up, a word with a
## friendly ghost, the memory a vase of wildflowers keeps.
## DA: Et lille, stille vindue: gravstenen, et ord med et venligt genfærd, minderne i vasen.
class_name MemorialPanel
extends UIWindow

const GHOST_TINT := Color(0.8, 0.9, 1.0, 0.6)


## kind: "grave" | "ghost" | "vase". portrait: a portrait id ("" for none).
func _init(kind: String, title_text: String, bbcode: String, portrait := "") -> void:
	super._init(title_text, 860, 360)
	var row := UIKit.hbox(24)
	if portrait != "":
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#2a1c12") if kind != "ghost" else Color("#1a2230")
		sb.border_color = UIKit.INK
		sb.set_border_width_all(2)
		sb.set_content_margin_all(4)
		frame.add_theme_stylebox_override("panel", sb)
		var p := UIKit.portrait(portrait, 180)
		if kind == "ghost":
			p.modulate = GHOST_TINT
		elif kind == "grave":
			p.modulate = Color(0.86, 0.82, 0.74)
		frame.add_child(p)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
	elif kind == "vase":
		var t := TextureRect.new()
		t.texture = Assets.get_tex("props/vase_flowers" if not Memorial.vase().is_empty() else "props/vase", Vector2i(48, 64))
		t.custom_minimum_size = Vector2(120, 160)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		row.add_child(t)
	var txt := UIKit.rich(bbcode, 21)
	txt.custom_minimum_size = Vector2(560, 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	content.add_child(row)
	var close_row := UIKit.hbox()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	close_row.add_child(UIKit.button({"ghost": "Goodnight", "grave": "Bow your head", "vase": "Leave them be"}.get(kind, "Close"), close, 220))
	content.add_child(close_row)
