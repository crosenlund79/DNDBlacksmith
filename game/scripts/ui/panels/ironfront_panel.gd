## IronfrontPanel — Barnaby's basement war-room: choose an opponent, build decks, browse the collection,
## buy packs and singles, read the rules, play a tutorial, and play matches on the full-screen board.
## EN: Opened with Events.open_panel.emit("ironfront", {"id": <interactable or npc id>, "page": optional}).
##     Game time stands still while it is open (UIWindow.blocks_time). A match plays music/ironfront and
##     restores the previous music afterwards.
## DA: Barnabys krigsrum i kælderen: modstandere, kortbunker, samling, butik, regler og selve kampbordet.
class_name IronfrontPanel
extends UIWindow

var page := "menu"
var body: Control
var board: IronfrontBoard
var _prev_music := ""
var _last_opp := "barnaby"
var _last_mode := "standard"
var _last_tutorial := false
# deck builder
var _edit: Dictionary = {}
var _edit_idx := -1
var _builder_msg: RichTextLabel
var _builder_list: VBoxContainer
var _builder_grid: GridContainer
var _builder_count: Label
# collection
var _col_filter := ""
var _zoom_box: VBoxContainer
var _pack_reveal: Array = []


func _init(args: Dictionary = {}) -> void:
	super._init("Ironfront — Barnaby's War-Room", 1880, 1040)
	blocks_time = true
	page = str(args.get("page", "menu"))
	_intro = bool(args.get("tutorial", false))


var _intro := false


func _ready() -> void:
	super._ready()
	Ironfront.st()
	_show(page)
	if _intro:
		# answering Barnaby's invitation: straight into the coached introductory match
		call_deferred("_start", "barnaby", "standard", true)


func close() -> void:
	_restore_music()
	super.close()


func _exit_tree() -> void:
	_restore_music()
	super._exit_tree()


func _restore_music() -> void:
	if _prev_music != "":
		Audio.play_music(_prev_music)
		_prev_music = ""


# ====================================================================== navigation
func _show(p: String) -> void:
	page = p
	UIKit.clear(content)
	board = null
	add_theme_stylebox_override("panel", Assets.panel_style("dark" if p == "match" else "parchment"))
	title_label.add_theme_color_override("font_color", UIKit.PAPER if p == "match" else UIKit.INK)
	if p != "match":
		title_label.text = "Ironfront — Barnaby's War-Room"
		content.add_child(_nav())
	match p:
		"menu": _menu()
		"decks": _decks()
		"collection": _collection()
		"shop": _shop()
		"rules": _rules()


func _nav() -> Control:
	var h := UIKit.hbox(10)
	for it in [["menu", "The Table"], ["decks", "Deck Builder"], ["collection", "Collection"], ["shop", "Barnaby's Shelf"], ["rules", "Rules & Tutorial"]]:
		var id: String = it[0]
		var b := UIKit.button(("❧ " if id == page else "") + str(it[1]), func(): _show(id), 0)
		h.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UIKit.label("%d gold · %d cards" % [Game.gold(), Ironfront.collection_size()], 24, "heading"))
	return h


func _scroll(child: Control, h := 760.0) -> ScrollContainer:
	return UIKit.scroll(child, h)


# ====================================================================== menu
func _menu() -> void:
	var cols := UIKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var left := UIKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var greet := UIKit.hbox(14)
	greet.add_child(_helmeted_portrait("portraits/barnaby", 120))
	var gv := UIKit.vbox(4)
	gv.add_child(UIKit.title("Barnaby Quill's basement", 34))
	var g := UIKit.rich("[i]\"Welcome, welcome! Mind the map pins. Helmet on — regulations, you understand. Tonight's question: [b]Standard[/b] — best of three rounds and every card counts — or [b]Blitzkrieg[/b]: one round, eight cards, everything hits hard and fast?\"[/i]", 21)
	g.custom_minimum_size = Vector2(900, 0)
	gv.add_child(g)
	greet.add_child(gv)
	left.add_child(greet)
	left.add_child(UIKit.divider())
	left.add_child(UIKit.label("Who sits down across the felt?", 26, "heading"))
	var list := UIKit.vbox(8)
	for o: Dictionary in Ironfront.opponents():
		list.add_child(_opp_row(o))
	left.add_child(_scroll(list, 600))
	# right: deck
	var right := UIKit.vbox(10)
	right.custom_minimum_size = Vector2(520, 0)
	cols.add_child(right)
	right.add_child(UIKit.label("Your deck", 28, "heading"))
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 22)
	for i in Ironfront.decks().size():
		ob.add_item(str(Ironfront.decks()[i].get("name", "Deck %d" % (i + 1))), i)
	ob.select(clampi(int(Ironfront.st()["active"]), 0, maxi(0, Ironfront.decks().size() - 1)))
	ob.item_selected.connect(func(i): Ironfront.set_active(i); _show("menu"))
	right.add_child(ob)
	var d := Ironfront.active_deck()
	var errs := Ironfront.validate_deck(d, Ironfront.st()["collection"])
	var cm := Ironfront.commander(str(d.get("commander", "")))
	var info := "[b]%s[/b] · %d cards\nCommander: [b]%s[/b] — %s" % [Ironfront.data().get("factions", {}).get(str(d.get("faction", "")), {}).get("name", "?"),
		Ironfront.deck_size(d), cm.get("name", "none"), cm.get("text", "")]
	if not errs.is_empty():
		info += "\n[color=#7e2418]Not ready: %s[/color]" % str(errs[0])
	right.add_child(UIKit.rich(info, 21))
	var fan := HBoxContainer.new()
	fan.add_theme_constant_override("separation", -40)
	var ids: Array = d.get("cards", {}).keys()
	ids.sort_custom(func(a, b): return int(Ironfront.card(a).get("str", 0)) > int(Ironfront.card(b).get("str", 0)))
	for id: String in ids.slice(0, 7):
		fan.add_child(IronfrontCard.new({"id": id}, 96, false, -1))
	right.add_child(fan)
	right.add_child(UIKit.button("Edit this deck", func(): _open_builder(int(Ironfront.st()["active"])), 0))
	right.add_child(UIKit.divider())
	var rec := "Matches played: %d · Won: %d" % [int(Ironfront.st().get("matches", 0)), Ironfront.total_wins()]
	right.add_child(UIKit.label(rec, 21, "body_italic"))
	if not Ironfront.st().get("tutorial_done", false):
		right.add_child(UIKit.rich("[i]New to the game? Barnaby will walk you through a first match.[/i]", 20))
		right.add_child(UIKit.button("Play the tutorial match", func(): _start("barnaby", "standard", true), 0))


func _helmeted_portrait(id: String, sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	var p := UIKit.portrait(id, sz)
	p.size = Vector2(sz, sz)
	c.add_child(p)
	if not IronfrontBoard.has_own_helmet(id):
		var h := UIKit.icon("ironfront/helmet", sz)
		h.size = Vector2(sz, sz)
		h.position = Vector2(0, -sz * 0.06)
		c.add_child(h)
	return c


func _opp_row(o: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.border_color = Color("#20140c", 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var h := UIKit.hbox(14)
	p.add_child(h)
	var unlocked := Ironfront.is_unlocked(str(o["id"]))
	var por := _helmeted_portrait(str(o.get("portrait", "")), 100)
	if not unlocked:
		por.modulate = Color(0.4, 0.35, 0.3)
	h.add_child(por)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stars := "★".repeat(int(o.get("tier", 1))) + "☆".repeat(3 - int(o.get("tier", 1)))
	v.add_child(UIKit.label("%s  %s" % [o["name"], stars], 26, "heading"))
	var rec := Ironfront.record(str(o["id"]))
	var dk: Dictionary = o.get("deck", {})
	var t := "[i]%s[/i] — %s\nDeck: %s · Record: %d won, %d lost, %d drawn" % [o.get("title", ""), o.get("style", ""), dk.get("name", ""),
		int(rec.get("w", 0)), int(rec.get("l", 0)), int(rec.get("d", 0))]
	if not unlocked:
		t = "[i]Not at the table yet.[/i] " + Ironfront.unlock_hint(str(o["id"]))
	var r := UIKit.rich(t, 19)
	r.custom_minimum_size = Vector2(640, 0)
	v.add_child(r)
	h.add_child(v)
	var bv := UIKit.vbox(6)
	var oid: String = o["id"]
	var b1 := UIKit.button("Standard", func(): _start(oid, "standard"), 180)
	var b2 := UIKit.button("Blitzkrieg", func(): _start(oid, "blitz"), 180)
	b1.disabled = not unlocked
	b2.disabled = not unlocked
	b1.tooltip_text = "Best of three rounds; ten cards; one more card each new round."
	b2.tooltip_text = "One round, eight cards, at most seven orders each. Units strike as they land (Assault), the first two get +2."
	bv.add_child(b1)
	bv.add_child(b2)
	h.add_child(bv)
	return p


# ====================================================================== match
func _start(opp_id: String, mode: String, tutorial := false) -> void:
	var d := Ironfront.active_deck()
	if tutorial:
		d = Ironfront.data().get("starter_deck", {})
	var errs := Ironfront.validate_deck(d, {} if tutorial else Ironfront.st()["collection"])
	if not errs.is_empty():
		Events.toast.emit("Your deck is not ready: " + str(errs[0]), "bad")
		_open_builder(int(Ironfront.st()["active"]))
		return
	var o := Ironfront.opponent(opp_id)
	_last_opp = opp_id
	_last_mode = mode
	_last_tutorial = tutorial
	var ai: Dictionary = o.get("ai", {}).duplicate()
	if tutorial:
		ai = {"skill": 0.3, "bluff": 0.0, "greed": 0.8}
	var seed := int(Time.get_ticks_usec() % 1000003) + int(Game.state.get("day", 1)) * 7919
	var pname := str(DB.character("player").get("name", "Brannoc")).split(" ")[0]
	var m := Ironfront.new_match(d, o.get("deck", {}), mode, seed, {"names": [pname, o.get("name", "Barnaby")], "opp": opp_id,
		"ai": [{}, ai], "tutorial": tutorial})
	if _prev_music == "":
		var cur: Variant = Audio.get("_music_id")
		_prev_music = str(cur) if cur != null else ""
	Audio.play_music("music/ironfront")
	_show("match")
	title_label.text = "Ironfront — %s vs %s · %s%s" % [pname, o.get("name", ""), "Blitzkrieg" if mode == "blitz" else "Standard", " · Tutorial" if tutorial else ""]
	board = IronfrontBoard.new(m, o)
	content.add_child(board)
	board.leave_requested.connect(func(): _restore_music(); _show("menu"))
	board.rematch_requested.connect(func(): _start(_last_opp, _last_mode, _last_tutorial))
	var greet := str(o.get("greet", ""))
	if greet != "" and not tutorial:
		Events.toast.emit(greet, "info")


# ====================================================================== deck builder
func _decks() -> void:
	if _edit.is_empty():
		_edit_idx = int(Ironfront.st()["active"])
		_edit = Ironfront.active_deck().duplicate(true)
	var cols := UIKit.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	# left: deck meta and list
	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(470, 0)
	cols.add_child(left)
	var pick := OptionButton.new()
	for i in Ironfront.decks().size():
		pick.add_item(str(Ironfront.decks()[i].get("name", "Deck")), i)
	if _edit_idx >= 0 and _edit_idx < Ironfront.decks().size():
		pick.select(_edit_idx)
	else:
		pick.add_item("(new deck)", 999)
		pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i): _open_builder(pick.get_item_id(i)))
	left.add_child(pick)
	var name_e := LineEdit.new()
	name_e.text = str(_edit.get("name", "New deck"))
	name_e.add_theme_font_size_override("font_size", 22)
	name_e.text_changed.connect(func(t): _edit["name"] = t)
	left.add_child(name_e)
	var fh := UIKit.hbox(8)
	fh.add_child(UIKit.label("Faction", 22))
	var fo := OptionButton.new()
	var facs := ["allies", "axis", "soviet"]
	for i in facs.size():
		fo.add_item(str(Ironfront.data()["factions"][facs[i]]["name"]), i)
	fo.select(maxi(0, facs.find(str(_edit.get("faction", "allies")))))
	fo.item_selected.connect(func(i): _set_faction(facs[i]))
	fh.add_child(fo)
	left.add_child(fh)
	var chh := UIKit.hbox(8)
	chh.add_child(UIKit.label("Commander", 22))
	var co := OptionButton.new()
	var cms := Ironfront.commanders(str(_edit.get("faction", "allies")))
	for i in cms.size():
		co.add_item(str(cms[i]["name"]), i)
		if cms[i]["id"] == _edit.get("commander", ""):
			co.select(i)
	co.item_selected.connect(func(i): _edit["commander"] = cms[i]["id"]; _builder_refresh())
	co.tooltip_text = "\n".join(cms.map(func(c): return "%s: %s" % [c["name"], c["text"]]))
	chh.add_child(co)
	left.add_child(chh)
	_builder_count = UIKit.label("", 22, "body_bold")
	left.add_child(_builder_count)
	_builder_list = UIKit.vbox(2)
	left.add_child(_scroll(_builder_list, 430))
	_builder_msg = UIKit.rich("", 19)
	left.add_child(_builder_msg)
	var bh := UIKit.hbox(8)
	bh.add_child(UIKit.button("Save deck", _save_deck, 0))
	bh.add_child(UIKit.button("New", func(): _open_builder(-1), 0))
	bh.add_child(UIKit.button("Delete", _delete_deck, 0))
	left.add_child(bh)
	# right: available cards
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIKit.rich("[b]Your cards for this faction[/b] — [i]+ adds a copy, − removes one. Rules: %d–%d cards, at least %d units; up to 3 of a common, 2 of an uncommon, 1 of a rare or special.[/i]" % [
		int(Ironfront.deck_rules()["min"]), int(Ironfront.deck_rules()["max"]), int(Ironfront.deck_rules().get("min_units", 0))], 19))
	_builder_grid = GridContainer.new()
	_builder_grid.columns = 8
	_builder_grid.add_theme_constant_override("h_separation", 10)
	_builder_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_scroll(_builder_grid, 760))
	_builder_refresh()


func _open_builder(idx: int) -> void:
	if idx >= 0 and idx < Ironfront.decks().size():
		_edit_idx = idx
		_edit = Ironfront.decks()[idx].duplicate(true)
	else:
		_edit_idx = -1
		_edit = {"name": "New deck", "faction": "allies", "commander": "supreme_commander", "cards": {}}
	_show("decks")


func _set_faction(f: String) -> void:
	_edit["faction"] = f
	var cms := Ironfront.commanders(f)
	_edit["commander"] = cms[0]["id"] if not cms.is_empty() else ""
	var keep := {}
	for id: String in _edit.get("cards", {}):
		if Ironfront.card(id).get("faction", "") in [f, "neutral"]:
			keep[id] = _edit["cards"][id]
	_edit["cards"] = keep
	_show("decks")


func _adjust(id: String, delta: int) -> void:
	var cards: Dictionary = _edit.get("cards", {})
	var n := clampi(int(cards.get(id, 0)) + delta, 0, mini(Ironfront.max_copies(id), Ironfront.owned(id)))
	if n == 0:
		cards.erase(id)
	else:
		cards[id] = n
	_edit["cards"] = cards
	_builder_refresh()


func _builder_refresh() -> void:
	if _builder_list == null:
		return
	UIKit.clear(_builder_list)
	var cards: Dictionary = _edit.get("cards", {})
	var ids: Array = cards.keys()
	ids.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
	var units := 0
	for id: String in ids:
		var c := Ironfront.card(id)
		if c["type"] == "unit":
			units += int(cards[id])
		var h := UIKit.hbox(6)
		h.add_child(UIKit.button("−", func(): _adjust(id, -1), 50))
		var lbl := UIKit.label("%d×  %s  %s" % [int(cards[id]), c["name"], ("(%s %d)" % [Ironfront.ROW_NAMES[c["row"]], int(c["str"])]) if c["type"] == "unit" else "(tactic)"], 19)
		h.add_child(lbl)
		_builder_list.add_child(h)
	_builder_count.text = "%d cards · %d units" % [Ironfront.deck_size(_edit), units]
	var errs := Ironfront.validate_deck(_edit, Ironfront.st()["collection"])
	_builder_msg.text = "[color=#2a5a1c]Ready for battle.[/color]" if errs.is_empty() else "[color=#7e2418]" + "\n".join(errs.slice(0, 3)) + "[/color]"
	UIKit.clear(_builder_grid)
	var f: String = _edit.get("faction", "allies")
	for c: Dictionary in Ironfront.all_cards():
		if not (c["faction"] in [f, "neutral"]) or Ironfront.owned(str(c["id"])) <= 0:
			continue
		var id: String = c["id"]
		var v := UIKit.vbox(2)
		var cv := IronfrontCard.new({"id": id}, 150, false, -1)
		cv.tooltip_text = "%s\n%s" % [c["name"], Ironfront.ability_text(c)]
		cv.clicked.connect(func(_x): _adjust(id, 1))
		v.add_child(cv)
		var h := UIKit.hbox(4)
		h.add_child(UIKit.button("−", func(): _adjust(id, -1), 50))
		h.add_child(UIKit.label("%d/%d" % [int(cards.get(id, 0)), Ironfront.owned(id)], 20, "body_bold"))
		h.add_child(UIKit.button("+", func(): _adjust(id, 1), 50))
		v.add_child(h)
		_builder_grid.add_child(v)


func _sort_key(id: String) -> String:
	var c := Ironfront.card(id)
	return "%d%s%03d" % [0 if c["type"] == "unit" else 1, {"inf": "a", "arm": "b", "air": "c"}.get(str(c.get("row", "")), "d"), 99 - int(c.get("str", 0))]


func _save_deck() -> void:
	_edit_idx = Ironfront.save_deck(_edit_idx, _edit)
	var errs := Ironfront.validate_deck(_edit, Ironfront.st()["collection"])
	if errs.is_empty():
		Ironfront.set_active(_edit_idx)
		Events.toast.emit("Deck '%s' saved and set as your active deck." % _edit.get("name", ""), "good")
	else:
		Events.toast.emit("Deck saved, but it is not legal yet: " + str(errs[0]), "info")
	_show("decks")


func _delete_deck() -> void:
	if _edit_idx >= 0 and Ironfront.decks().size() > 1:
		Ironfront.delete_deck(_edit_idx)
		Events.toast.emit("Deck scrapped.", "info")
	_open_builder(int(Ironfront.st()["active"]))


# ====================================================================== collection
func _collection() -> void:
	var cols := UIKit.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var left := UIKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var fh := UIKit.hbox(8)
	for it in [["", "All"], ["allies", "Western Allies"], ["axis", "Axis"], ["soviet", "Soviets"], ["neutral", "Tactics"]]:
		var fid: String = it[0]
		fh.add_child(UIKit.button(("❧ " if fid == _col_filter else "") + str(it[1]), func(): _col_filter = fid; _show("collection"), 0))
	var owned_n := Ironfront.all_cards().filter(func(c): return Ironfront.owned(c["id"]) > 0).size()
	fh.add_child(UIKit.label("   %d of %d cards discovered" % [owned_n, Ironfront.all_cards().size()], 22, "body_italic"))
	left.add_child(fh)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for c: Dictionary in Ironfront.all_cards():
		if _col_filter != "" and c["faction"] != _col_filter:
			continue
		var v := UIKit.vbox(0)
		var cv := IronfrontCard.new({"id": c["id"]}, 150, false, -1)
		var n := Ironfront.owned(str(c["id"]))
		if n <= 0:
			cv.modulate = Color(0.35, 0.32, 0.3)
		cv.hovered.connect(_col_zoom)
		v.add_child(cv)
		var t := ("× %d" % n) if n > 0 else ("not found yet" if not c.get("special", false) else "merchants & exploration")
		var l := UIKit.label(t, 17, "body_italic")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		grid.add_child(v)
	left.add_child(_scroll(grid, 780))
	_zoom_box = UIKit.vbox(6)
	_zoom_box.custom_minimum_size = Vector2(340, 0)
	_zoom_box.add_child(UIKit.rich("[i]Hover a card to read it.[/i]", 20))
	cols.add_child(_zoom_box)


func _col_zoom(v: IronfrontCard) -> void:
	if _zoom_box == null:
		return
	UIKit.clear(_zoom_box)
	_zoom_box.add_child(IronfrontCard.new(v.inst, 320, false, -1))
	var d := v.def
	var t := "[b]%s[/b] — %s %s\n%s\n[i]%s[/i]" % [d["name"], Ironfront.RARITY_NAMES.get(str(d["rarity"]), ""),
		("%s, strength %d" % [Ironfront.ROW_NAMES.get(str(d.get("row", "")), ""), int(d.get("str", 0))]) if d["type"] == "unit" else "tactic",
		Ironfront.ability_text(d), d.get("flavor", "")]
	var r := UIKit.rich(t, 19)
	r.custom_minimum_size = Vector2(330, 0)
	_zoom_box.add_child(r)


# ====================================================================== shop
func _shop() -> void:
	var cols := UIKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var left := UIKit.vbox(10)
	left.custom_minimum_size = Vector2(560, 0)
	cols.add_child(left)
	left.add_child(UIKit.title("A sealed pack", 32))
	var cfg := Ironfront.shop_cfg()
	left.add_child(UIKit.rich("[i]\"Five cards, wrapped in genuine field-dispatch paper. At least one uncommon, guaranteed — I wrap them myself.\"[/i]\n\n%d cards for [b]%d gold[/b]. Special cards are never in packs: those turn up with travelling merchants and in the ruins adventurers explore." % [int(cfg.get("pack_size", 5)), int(cfg.get("pack_price", 60))], 21))
	var bb := UIKit.button("Buy a pack (%d g)" % int(cfg.get("pack_price", 60)), _buy_pack, 0)
	bb.disabled = not Game.can_afford(int(cfg.get("pack_price", 60)))
	left.add_child(bb)
	if not _pack_reveal.is_empty():
		left.add_child(UIKit.label("You open the pack:", 22, "body_bold"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for id: String in _pack_reveal:
			var cv := IronfrontCard.new({"id": id}, 104, false, -1)
			cv.tooltip_text = str(Ironfront.card(id).get("name", ""))
			row.add_child(cv)
		left.add_child(row)
	var right := UIKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIKit.title("Singles on the shelf today", 32))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	for id: String in Ironfront.shop_singles():
		var v := UIKit.vbox(4)
		v.add_child(IronfrontCard.new({"id": id}, 170, false, -1))
		var price := Ironfront.single_price(id)
		var b := UIKit.button("Buy · %d g" % price, func(): _buy_single(id), 170)
		b.disabled = not Game.can_afford(price)
		v.add_child(b)
		v.add_child(UIKit.label("owned: %d" % Ironfront.owned(id), 17, "body_italic"))
		grid.add_child(v)
	right.add_child(grid)
	right.add_child(UIKit.rich("[i]The shelf changes every morning.[/i]", 19))


func _buy_pack() -> void:
	var ids := Ironfront.buy_pack()
	if ids.is_empty():
		Events.toast.emit("Not enough gold for a pack.", "bad")
		return
	_pack_reveal = ids
	Audio.play("sfx/reveal_rare" if ids.any(func(i): return Ironfront.card(i)["rarity"] == "rare") else "sfx/reveal_common", -4.0)
	_show("shop")


func _buy_single(id: String) -> void:
	if Ironfront.buy_single(id):
		Events.toast.emit("%s added to your collection." % Ironfront.card(id)["name"], "good")
	_show("shop")


# ====================================================================== rules
const RULES := """[b]The war in a nutshell.[/b] Two commanders each draw [b]10 cards[/b] from a deck of 22–30. Players take turns: [b]play one card[/b], use your [b]commander's order[/b] (once per match), or [b]pass[/b]. Once you pass you are out until the next round; your opponent may keep playing. When both have passed, the higher total strength wins the round and a [b]red gem[/b]. A drawn round gives both sides a gem. [b]Best of three[/b]; two gems take the match. Cards played are spent — at the start of rounds two and three each side draws just one more card, so winning a round cheaply is the whole art.

[b]Three fronts.[/b] Every unit fights on its own row: [b]Infantry[/b], [b]Armour[/b] or [b]Air[/b] — the icon at the top right of the card. Its strength sits in the brass seal.

[b]Abilities.[/b] [i]Spotter[/i] reveals two cards in the enemy hand. [i]Artillery N[/i] hits the strongest enemy unit in a row; [i]Barrage N[/i] hits every unit in a row. [i]Assault N[/i] strikes the weakest enemy in the same row. [i]Entrench[/i] ignores weather and the first hit. [i]Combined Arms N[/i] adds N while you have a unit in another row. [i]Supply Line[/i] draws a card. [i]Reinforce[/i] calls the rest of the company (or the paratroopers in the plane) straight out of your deck. [i]Medic[/i] returns your strongest fallen unit to your hand. [i]Rally[/i] lifts the rest of its row. [i]Elite[/i] units ignore everything.

[b]Tactics.[/b] Weather — [i]Mud[/i] (Armour), [i]Fog[/i] (Air), [i]Hard Frost[/i] (Infantry) — sets every non-entrenched unit in that row, on both sides, to 1. [i]Smoke Screen[/i] clears it. [i]Air Superiority[/i] clears fog and lifts your Air. [i]Blitzkrieg Doctrine[/i] lifts your Armour. [i]Pincer Movement[/i] destroys the strongest enemy unit if it has 8 or more. [i]Bletchley Park Codebreakers[/i] read the enemy hand and steal a card. [i]Operation Fortitude[/i] swaps a rubber decoy for one of your units, which goes back to your hand to be played again. [i]Rolling Barrage[/i] shells the most crowded enemy row.

[b]Blitzkrieg.[/b] One round only. Eight cards, at most seven orders each. Every unit attacks as it lands (Assault +1), and your first two units get +2 for momentum. Highest total wins outright.

[b]Collecting.[/b] Win matches for cards and gold (tougher opponents pay better), buy packs and singles on Barnaby's shelf, and keep an eye out for special cards with travelling merchants or in the ruins the adventurers explore."""


func _rules() -> void:
	var cols := UIKit.hbox(24)
	content.add_child(cols)
	var r := UIKit.rich(RULES, 20)
	r.custom_minimum_size = Vector2(1240, 0)
	cols.add_child(_scroll(r, 800))
	var right := UIKit.vbox(12)
	right.custom_minimum_size = Vector2(440, 0)
	cols.add_child(right)
	right.add_child(_helmeted_portrait("portraits/barnaby", 160))
	right.add_child(UIKit.rich("[i]\"Rules are all very well, but the felt teaches faster. Sit down for a practice match: I will play gently and talk you through it.\"[/i]", 21))
	right.add_child(UIKit.button("Tutorial match with Barnaby", func(): _start("barnaby", "standard", true), 0))
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", -30)
	for id in ["tiger", "spitfire", "codebreakers"]:
		ex.add_child(IronfrontCard.new({"id": id}, 150, false, -1))
	right.add_child(ex)
