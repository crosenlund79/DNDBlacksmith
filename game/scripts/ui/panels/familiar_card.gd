## FamiliarCard — "A Familiar Creation": the restrained moment when one of the smith's pieces comes back
## (route `familiar` {uid, data} — data from ItemStory.card_data). Also shows the result of a workshop service
## (sharpening, reforging) with {mode: "service", uid, result}. Opened over the current panel; never repeats for
## the same reunion (ItemStory.recognise stores it).
## DA: "En kendt skabelse" — et pergamentkort når smedens eget værk vender tilbage; også resultatet af slibning/omsmedning.
class_name FamiliarCard
extends UIWindow

var args: Dictionary
var uid := -1


func _init(a: Dictionary = {}) -> void:
	args = a
	uid = int(a.get("uid", -1))
	super._init("", 1000, 0)
	name = "FamiliarCard"


func _ready() -> void:
	super._ready()
	var it := ItemStory.find(uid)
	if str(args.get("mode", "")) == "service":
		_service(it, args.get("result", {}))
	else:
		_reunion(it, args.get("data", {}))


func _reunion(it: Dictionary, d: Dictionary) -> void:
	title_label.text = "A Familiar Creation"
	title_label.add_theme_color_override("font_color", UIKit.RUBRIC)
	content.add_child(UIKit.label(str(d.get("occasion_text", "It came back to the forge.")), 21, "body_italic"))
	var h := UIKit.hbox(20)
	var col := UIKit.vbox(8)
	if not it.is_empty():
		var s := ItemSlot.new(it, 128.0)
		s.inspectable = false
		col.add_child(s)
	var mk := UIKit.hbox(6)
	mk.add_child(UIKit.icon("marks/" + str(d.get("mark", "ironhand")), 40))
	mk.add_child(UIKit.label(str(d.get("mark_name", "")), 15, "body_italic"))
	col.add_child(mk)
	h.add_child(col)
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(720, 0)
	var nm := UIKit.label(str(d.get("name", "")), 34, "title", Items.color(it, false) if not it.is_empty() else UIKit.INK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	if str(d.get("named", "")) != "":
		v.add_child(UIKit.label("once called %s" % str(d.get("base", "")), 18, "heading_italic", Color("#6e5a40")))
	var day := int(d.get("day", 0))
	var ago := int(d.get("days_ago", 0))
	v.add_child(UIKit.rich("[b]You forged this on day %d[/b]%s." % [day, (" — %d day%s ago" % [ago, "" if ago == 1 else "s"]) if ago > 0 else ", this very day"], 22))
	var ach: Array = d.get("achievements", [])
	if not ach.is_empty():
		v.add_child(UIKit.label("What it has done", 22, "heading"))
		for t in ach:
			var r := UIKit.hbox(8)
			var t_s := str(t.get("text", "")) if t is Dictionary else str(t)
			var kind := str(t.get("kind", "note")) if t is Dictionary else "note"
			r.add_child(UIKit.icon(ItemStory.story_icon(kind, t_s), 30))
			var l := UIKit.rich(t_s, 18)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			v.add_child(r)
	var jr: Array = d.get("journey", [])
	if jr.size() > 1:
		v.add_child(UIKit.label("Its journey", 22, "heading"))
		var parts := []
		for o in jr:
			parts.append("[b]%s[/b] [color=#7a6a50](%s, day %d)[/color]" % [str(o.get("name", "")), ItemPanel._how_word(str(o.get("how", ""))), int(o.get("from", 0))])
		v.add_child(UIKit.rich("  →  ".join(PackedStringArray(parts)), 18))
	h.add_child(v)
	content.add_child(h)
	content.add_child(UIKit.label("You know the weight of it before you look at the mark.", 18, "body_italic", Color("#6e5a40")))
	_buttons(it)


func _service(it: Dictionary, r: Dictionary) -> void:
	var kind := str(r.get("kind", "sharpened"))
	title_label.text = {"sharpened": "Sharpened at the Wheel", "reforged": "Reforged at the Anvil"}.get(kind, "Workshop work")
	var h := UIKit.hbox(20)
	if not it.is_empty():
		var s := ItemSlot.new(it, 128.0)
		s.inspectable = false
		h.add_child(s)
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(720, 0)
	if not it.is_empty():
		v.add_child(UIKit.label(Items.display_name(it), 30, "title", Items.color(it, false)))
		var mk := Provenance.maker(it)
		var mh := UIKit.hbox(6)
		mh.add_child(UIKit.icon(ItemStory.mark_icon(it), 32))
		var ml := UIKit.label("Made by %s — the maker and the name stay as they were." % str(mk.get("name", "")), 17, "body_italic")
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mh.add_child(ml)
		v.add_child(mh)
	var b: Dictionary = r.get("before", {})
	var a: Dictionary = r.get("after", {})
	var rows := []
	if absf(float(a.get("quality", 0)) - float(b.get("quality", 0))) >= 0.5:
		rows.append("Craftsmanship  [b]%d%%[/b] → [b][color=#2f6a1e]%d%%[/color][/b]" % [int(round(float(b.get("quality", 0)))), int(round(float(a.get("quality", 0))))])
	for k in ["attack", "protection"]:
		if int(a.get(k, 0)) != int(b.get(k, 0)):
			rows.append("%s  [b]%d[/b] → [b][color=#2f6a1e]%d[/color][/b]" % [k.capitalize(), int(b.get(k, 0)), int(a.get(k, 0))])
	if int(a.get("durability_max", 0)) > 0:
		rows.append("Durability  %d/%d → [b]%d/%d[/b]%s" % [int(b.get("durability", 0)), int(b.get("durability_max", 0)), int(a.get("durability", 0)), int(a.get("durability_max", 0)),
			"  [color=#2f6a1e](no longer broken)[/color]" if bool(b.get("broken", false)) and not bool(a.get("broken", false)) else ""])
	if not it.is_empty() and it.has("coating") and kind == "sharpened":
		rows.append("[color=#8a4a10]%s: +%d attack for %d expeditions[/color]" % [it["coating"].get("name", ""), int(it["coating"].get("value", 0)), int(it["coating"].get("uses", 0))])
	v.add_child(UIKit.rich("\n".join(PackedStringArray(rows)), 21))
	var hr := UIKit.hbox(8)
	hr.add_child(UIKit.icon(ItemStory.story_icon(kind), 36))
	var t := UIKit.rich("[i]Written into its history: %s[/i]" % str(r.get("text", "")), 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	v.add_child(hr)
	h.add_child(v)
	content.add_child(h)
	_buttons(it)


func _buttons(it: Dictionary) -> void:
	var b := UIKit.hbox(10)
	if not it.is_empty() and Items.is_equipment(it):
		var u := uid
		b.add_child(UIKit.button("Inspect its story", func():
			close()
			Events.open_panel.emit.call_deferred("item", {"uid": u, "tab": "History"}), 260))
	b.add_child(UIKit.button("Set it down", close, 200))
	content.add_child(b)
