## HallOfFamePanel — the public achievement board: brass plaques on dark oak.
## EN: Opened from the smithy's board (id "smithy") or the podium in the village square (id "square").
##     Shows every plaque of Recognition (masterworks, discoveries, commissions, great deeds, Epic pieces,
##     ceremonies), filterable, with the item itself where it can still be found (hover for its tooltip).
##     With {"ceremony": true}, or opened at the square while the ceremony is gathered, it first plays the
##     short ceremony scene (Ceremony.scene_lines) and the smith is publicly credited.
## DA: Æreshallen: messingplader på mørk eg. Ved torvet vises også ceremonien.
class_name HallOfFamePanel
extends UIWindow

const OAK := Color("#2e1d10")
const OAK_LIGHT := Color("#4a2f19")
const BRASS := Color("#c9a253")
const BRASS_DARK := Color("#6e4a1a")
const ENGRAVE := Color("#2a1a0a")
const FILTERS := [["all", "All honours"], ["famous", "Famous creations"], ["craft", "Masterworks"], ["discovery", "Discoveries"], ["commission", "Commissions"],
	["deed", "Great deeds"], ["epic", "Epic"], ["ceremony", "Ceremonies"]]

var where := "smithy"
var ceremony := false
var filter := "all"
var board: VBoxContainer


func _init(args: Dictionary = {}) -> void:
	where = str(args.get("id", "smithy"))
	ceremony = bool(args.get("ceremony", false))
	super._init("The Hall of Fame", 1420, 860)


func _ready() -> void:
	super._ready()
	# opened at the podium while the square is gathered: that is attending
	if where == "square" and Ceremony.can_attend():
		Ceremony.attend()
		ceremony = true
	if ceremony and str(Ceremony.state().get("status", "")) == "held":
		content.add_child(_ceremony_scene())
	elif where == "square" and Ceremony.scheduled():
		var c := Ceremony.state()
		content.add_child(UIKit.rich("[color=#7e2418][b]A ceremony is planned here on day %d at noon[/b][/color] — %s will be honoured. Be in the square between %d:00 and %d:00." % [
			int(c.get("day", 0)), Talk.npc_name(str(c.get("adv", ""))), Ceremony.START_HOUR, Ceremony.END_HOUR], 20))
	var head := UIKit.hbox(14)
	var t := UIKit.rich("[i]%s · the smith's renown [b]%d[/b] · reputation: [b]%s[/b] · %d plaque%s[/i]" % [
		"The board on the shop wall of the Ironhand forge" if where == "smithy" else "The honours board by the podium in the square",
		Ceremony.smith_renown(), Shop.reputation_word(), Recognition.entries().size(), "" if Recognition.entries().size() == 1 else "s"], 20)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	content.add_child(head)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	for f in FILTERS:
		var key: String = f[0]
		var n := Recognition.entries().size() if key == "all" else (ItemStory.famous_creations().size() if key == "famous" else Recognition.of_kind(key).size())
		var b := UIKit.button("%s (%d)" % [f[1], n], func(): filter = key; _fill(), 0)
		b.name = "Filter_" + key
		tabs.add_child(b)
	content.add_child(tabs)
	var oak := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = OAK
	sb.border_color = BRASS_DARK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	oak.add_theme_stylebox_override("panel", sb)
	oak.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grain := OakGrain.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oak.add_child(grain)
	board = UIKit.vbox(12)
	oak.add_child(UIKit.scroll(board, 470 if not ceremony else 300))
	content.add_child(oak)
	_fill()


func _fill() -> void:
	UIKit.clear(board)
	var crest := UIKit.label("✠  THE HALL OF FAME  ✠", 34, "title", BRASS)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(crest)
	if filter == "famous":
		_famous()
		return
	var es := Recognition.recent(200, [] if filter == "all" else [filter])
	if es.is_empty():
		var l := UIKit.label("No plaques yet. Exceptional pieces, legendary finds, great commissions and deeds done with your work will be honoured here." if filter == "all"
			else "Nothing of this kind has been honoured yet.", 22, "body_italic", Color("#d8c495"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(l)
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	for e in es:
		grid.add_child(_plaque(e))
	board.add_child(grid)


## Famous creations (ItemStory): the smith's named and Epic pieces — the piece, its name, its deeds, its owner now.
func _famous() -> void:
	var fs := ItemStory.famous_creations()
	if fs.is_empty():
		var l := UIKit.label("None of your work is famous yet. Pieces that earn a name or Epic distinction out in the world are remembered here.", 22, "body_italic", Color("#d8c495"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(l)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	for f in fs:
		grid.add_child(_creation(f))
	board.add_child(grid)


func _creation(f: Dictionary) -> Control:
	var epic := bool(f.get("epic", false))
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#d9b46a") if epic else BRASS
	sb.border_color = Recognition.EPIC_COLOR_LIGHT if epic else BRASS_DARK
	sb.set_border_width_all(4 if epic else 3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(660, 190)
	pc.name = "Creation_%d" % int(f["uid"])
	var rivets := Rivets.new()
	rivets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(rivets)
	var h := UIKit.hbox(14)
	var it: Dictionary = f.get("item", {})
	var left := UIKit.vbox(6)
	if not it.is_empty():
		left.add_child(ItemSlot.new(it, 96.0))
	else:
		left.add_child(UIKit.icon("ui/story_lost", 80))
	left.add_child(UIKit.icon("marks/ironhand", 32))
	h.add_child(left)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tags := []
	if bool(f.get("named", false)):
		tags.append("NAMED")
	if epic:
		tags.append("✦ EPIC")
	var r := str(f.get("rarity", "common"))
	if r in ["legendary", "unique", "set", "rare"]:
		tags.append(Items.RARITY_LABEL.get(r, "").to_upper())
	v.add_child(UIKit.label("FAMOUS CREATION" + ("  ·  " + "  ·  ".join(PackedStringArray(tags)) if not tags.is_empty() else ""), 15, "heading",
		Recognition.EPIC_COLOR_LIGHT if epic else Color("#5a3a12")))
	var tl := UIKit.label(str(f.get("name", "")), 26, "heading", ENGRAVE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	if not it.is_empty() and ItemStory.is_named(it):
		v.add_child(UIKit.label("a %s from the Ironhand forge" % str(it.get("base_name", Items.def(it).get("name", ""))).to_lower(), 16, "body_italic", Color("#3a2610")))
	var ds: Array = f.get("deeds", [])
	var lines := []
	for d in ds.slice(maxi(0, ds.size() - 3)):
		lines.append("• Day %d — %s" % [int(d.get("day", 0)), str(d.get("text", ""))])
	var dl := UIKit.label("\n".join(PackedStringArray(lines)), 16, "body", Color("#2a1a0a"))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	v.add_child(UIKit.label("Held now by %s" % str(f.get("owner", "")), 17, "body_bold", Color("#3a2610")))
	if not it.is_empty():
		var u := int(f["uid"])
		var b := UIKit.button("Its story", func(): Events.open_panel.emit("item", {"uid": u}), 140)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
	h.add_child(v)
	pc.add_child(h)
	return pc


## One brass plaque: rivets, the honour's kind, the item (if it can be found), title, text and day.
func _plaque(e: Dictionary) -> Control:
	var kind := str(e.get("kind", ""))
	var epic := kind == "epic"
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRASS if not epic else Color("#d9b46a")
	sb.border_color = BRASS_DARK if not epic else Recognition.EPIC_COLOR_LIGHT
	sb.set_border_width_all(3 if not epic else 4)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(430, 150)
	var rivets := Rivets.new()
	rivets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(rivets)
	var h := UIKit.hbox(12)
	var refs: Dictionary = e.get("refs", {})
	var it := Game.find_uid_anywhere(int(refs.get("uid", -1)))
	if not it.is_empty():
		var slot := ItemSlot.new(it, 76.0)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(slot)
	elif str(refs.get("adv", "")) != "" and Assets.has_tex("portraits/" + str(refs["adv"])):
		var p := UIKit.portrait("portraits/" + str(refs["adv"]), 76)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(p)
	else:
		var ic := UIKit.icon(str(Recognition.KINDS.get(kind, {}).get("icon", "icons/star")), 64)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kl := UIKit.label(("✦ " if epic else "") + str(Recognition.KINDS.get(kind, {}).get("name", kind)).to_upper() + "  ·  DAY %d" % int(e.get("day", 0)), 15, "heading",
		Recognition.EPIC_COLOR_LIGHT if epic else Color("#5a3a12"))
	v.add_child(kl)
	var tl := UIKit.label(str(e.get("title", "")), 22, "heading", ENGRAVE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var xl := UIKit.label(str(e.get("text", "")), 17, "body_italic", Color("#3a2610"))
	xl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(xl)
	h.add_child(v)
	pc.add_child(h)
	return pc


## The ceremony: the honoured adventurer at the podium, the crowd, the toast and the applause.
func _ceremony_scene() -> Control:
	var c := Ceremony.state()
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe2bf")
	sb.border_color = UIKit.RUBRIC
	sb.set_border_width_all(3)
	sb.border_width_left = 8
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	var h := UIKit.hbox(16)
	var adv := str(c.get("adv", ""))
	if adv != "":
		h.add_child(UIKit.portrait("portraits/" + adv, 150))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("A CEREMONY IN THE SQUARE — NOON, DAY %d" % int(c.get("day", Game.day())), 18, "heading", UIKit.RUBRIC))
	var lines := []
	for ln in Ceremony.scene_lines(c):
		var who := str(ln[0])
		lines.append(("[b]%s:[/b] %s" % [Talk.npc_name(who), ln[1]]) if who != "" else str(ln[1]))
	v.add_child(UIKit.rich("\n".join(PackedStringArray(lines)), 20))
	v.add_child(UIKit.rich("[color=#2f6a1e][b]The smith is publicly credited:[/b] +%d renown · reputation up · %s thinks the more of you.[/color]" % [
		Ceremony.RENOWN, Talk.npc_name(adv) if adv != "" else "the village"], 19))
	h.add_child(v)
	var it := Game.find_uid_anywhere(int(c.get("uid", -1)))
	if not it.is_empty():
		var slot := ItemSlot.new(it, 110.0)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(slot)
	pc.add_child(h)
	return pc


## Brass rivets in the plaque's corners.
class Rivets extends Control:
	func _draw() -> void:
		var m := 9.0
		for p in [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
			draw_circle(p, 5.0, Color("#6e4a1a"))
			draw_circle(p - Vector2(1, 1), 3.4, Color("#ecd08a"))
		# a fine engraved inner line
		draw_rect(Rect2(Vector2(16, 16), size - Vector2(32, 32)), Color(0.24, 0.15, 0.05, 0.35), false, 1.0)


## Faint wood grain across the oak board.
class OakGrain extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		var y := 6.0
		while y < size.y:
			var col := Color(0.42, 0.27, 0.14, rng.randf_range(0.10, 0.22))
			var pts := PackedVector2Array()
			var x := 0.0
			var wob := rng.randf_range(0.0, 6.0)
			while x <= size.x:
				pts.append(Vector2(x, y + sin(x / rng.randf_range(90.0, 160.0) + wob) * 2.2))
				x += 24.0
			if pts.size() >= 2:
				draw_polyline(pts, col, 1.4)
			y += rng.randf_range(9.0, 18.0)
