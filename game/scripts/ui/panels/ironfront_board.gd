## IronfrontBoard — the match table in Barnaby's basement: three fronts per side, hands, gems, log, zoom.
## EN: Drives one match from the static engine (Ironfront.apply / ai_move). Side 0 is the player.
##     Click a card in your hand to lift it, click it again to deploy it; Operation Fortitude then asks
##     for one of your units on the table. The opponent thinks for a moment between moves.
##     Events from the engine become small animations: cards slide in, strength pops, round banners.
## DA: Kampbordet: tre fronter pr. side, hånd, ædelsten, log og forstørrelse af kort.
class_name IronfrontBoard
extends Control

signal finished(m: Dictionary, reward: Dictionary)
signal leave_requested
signal rematch_requested

const ME := 0
const FOE := 1
const ROW_ORDER_FOE := ["air", "arm", "inf"]
const ROW_ORDER_ME := ["inf", "arm", "air"]
const WEATHER_TINT := {"inf": Color(0.55, 0.7, 0.85, 0.32), "arm": Color(0.45, 0.32, 0.16, 0.45), "air": Color(0.75, 0.75, 0.72, 0.35)}
const WEATHER_NAME := {"inf": "Hard Frost", "arm": "Mud", "air": "Fog"}

var m: Dictionary
var opp: Dictionary
var selected_uid := -1
var busy := false
var ai_delay := 0.9
var tips_seen := {}
var views := {}          # uid -> IronfrontCard currently on screen
var rows := {}           # "side:row" -> {panel, box, total}
var _prev_totals := {}
var _ended := false

var hand_box: HBoxContainer
var opp_hand_box: HBoxContainer
var log_label: RichTextLabel
var zoom_holder: Control
var zoom_text: RichTextLabel
var status_label: Label
var pass_btn: Button
var cmd_btn: Button
var coach_label: RichTextLabel
var coach_box: PanelContainer
var fx: Control
var side_info := [{}, {}]     # gems box, score label, hand label, portrait
var weather_label: Label
var round_label: Label


func _init(match_dict: Dictionary, opponent: Dictionary) -> void:
	m = match_dict
	opp = opponent
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(1780, 880)


func _ready() -> void:
	_build()
	_refresh()
	_play_events()
	if int(m["turn"]) == FOE:
		_ai_turn()


# ====================================================================== layout
func _panel(bg: Color, border := Color("#b8923e", 0.6), pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _lbl(t: String, sz := 20, font := "body", col := UIKit.PAPER) -> Label:
	return UIKit.label(t, sz, font, col)


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = Assets.get_tex("ironfront/board", Vector2i(1920, 1080))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 14)
	add_child(mc)
	var cols := UIKit.hbox(12)
	mc.add_child(cols)
	# ---- left: the two commanders
	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(236, 0)
	cols.add_child(left)
	left.add_child(_side_block(FOE))
	var mid := _panel(Color(0, 0, 0, 0.35))
	var mv := UIKit.vbox(4)
	mid.add_child(mv)
	round_label = _lbl("", 22, "title", Color("#e6c46a"))
	mv.add_child(round_label)
	weather_label = _lbl("", 18, "body_italic")
	weather_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weather_label.custom_minimum_size = Vector2(210, 0)
	mv.add_child(weather_label)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(mid)
	left.add_child(_side_block(ME))
	pass_btn = UIKit.button("Pass", _on_pass, 220)
	pass_btn.tooltip_text = "End your part of this round. Your opponent may keep playing."
	left.add_child(pass_btn)
	cmd_btn = UIKit.button("Commander", _on_commander, 220)
	cmd_btn.add_theme_font_size_override("font_size", 19)
	left.add_child(cmd_btn)
	var cb := UIKit.button("Concede", _on_concede, 220)
	cb.tooltip_text = "Fold your cards: the match counts as a loss."
	cb.add_theme_font_size_override("font_size", 18)
	left.add_child(cb)
	# ---- centre: six fronts, banner, hand
	var centre := UIKit.vbox(5)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(centre)
	var ohand := UIKit.hbox(4)
	ohand.alignment = BoxContainer.ALIGNMENT_CENTER
	ohand.custom_minimum_size = Vector2(0, 44)
	opp_hand_box = ohand
	centre.add_child(ohand)
	for r: String in ROW_ORDER_FOE:
		centre.add_child(_row_panel(FOE, r))
	var strip := _panel(Color(0.08, 0.05, 0.03, 0.75), Color("#b8923e"), 4)
	status_label = _lbl("", 26, "title", Color("#e6c46a"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(status_label)
	centre.add_child(strip)
	for r: String in ROW_ORDER_ME:
		centre.add_child(_row_panel(ME, r))
	hand_box = UIKit.hbox(6)
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.custom_minimum_size = Vector2(0, 172)
	centre.add_child(hand_box)
	# ---- right: zoom, coach, log
	var right := UIKit.vbox(6)
	right.custom_minimum_size = Vector2(330, 0)
	cols.add_child(right)
	var zp := _panel(Color(0, 0, 0, 0.4))
	var zv := UIKit.vbox(4)
	zp.add_child(zv)
	zoom_holder = CenterContainer.new()
	zoom_holder.custom_minimum_size = Vector2(300, 300)
	zv.add_child(zoom_holder)
	zoom_text = UIKit.rich("[i]Hover over a card to read it.[/i]", 17, true)
	zoom_text.custom_minimum_size = Vector2(300, 0)
	zv.add_child(zoom_text)
	right.add_child(zp)
	coach_box = _panel(Color("#efe4cc", 0.92), Color("#7e2418"), 8)
	coach_label = UIKit.rich("", 17)
	coach_label.custom_minimum_size = Vector2(300, 0)
	var ch := UIKit.hbox(6)
	var bp := UIKit.portrait("portraits/barnaby", 54)
	ch.add_child(bp)
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_label.custom_minimum_size = Vector2(240, 0)
	ch.add_child(coach_label)
	coach_box.add_child(ch)
	coach_box.visible = false
	right.add_child(coach_box)
	var lp := _panel(Color(0, 0, 0, 0.4))
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label = UIKit.rich("", 16, true)
	log_label.scroll_active = true
	log_label.fit_content = false
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.add_child(log_label)
	right.add_child(lp)
	# ---- effects layer on top
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)


func _side_block(side: int) -> Control:
	var p := _panel(Color(0, 0, 0, 0.42))
	var v := UIKit.vbox(4)
	p.add_child(v)
	var name_s: String = m["sides"][side]["name"]
	var head := UIKit.hbox(8)
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(96, 96)
	var por := TextureRect.new()
	por.texture = Assets.get_tex(str(opp.get("portrait", "portraits/barnaby")) if side == FOE else "portraits/player", Vector2i(256, 256))
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.size = Vector2(96, 96)
	pc.add_child(por)
	# everyone at Barnaby's table wears the green helmet (Barnaby's portrait already has his own)
	var pid: String = str(opp.get("portrait", "portraits/barnaby")) if side == FOE else "portraits/player"
	if not has_own_helmet(pid):
		pc.add_child(_helmet_rect(side))
	head.add_child(pc)
	var hv := UIKit.vbox(2)
	var nl := _lbl(name_s, 21, "title", Color("#e6c46a"))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(120, 0)
	hv.add_child(nl)
	var gems := UIKit.hbox(4)
	hv.add_child(gems)
	var hand_l := _lbl("", 17, "body_italic")
	hv.add_child(hand_l)
	head.add_child(hv)
	v.add_child(head)
	var sc := _lbl("0", 44, "initial", UIKit.PAPER)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	side_info[side] = {"gems": gems, "score": sc, "hand": hand_l, "portrait": pc}
	return p


## True when the portrait's character already wears the green M1 helmet (Barnaby).
static func has_own_helmet(portrait_id: String) -> bool:
	var cid := portrait_id.get_file()
	return DB.character(cid).get("look", {}).get("extras", []).has("helmet_m1")


func _helmet_rect(side: int) -> TextureRect:
	var hel := TextureRect.new()
	hel.texture = Assets.get_tex("ironfront/helmet", Vector2i(256, 256))
	hel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var off: Array = opp.get("helmet", [0, 0, 1.0]) if side == FOE else [0, 0, 1.0]
	var hs := 96.0 * float(off[2])
	hel.size = Vector2(hs, hs)
	hel.position = Vector2((96 - hs) / 2 + float(off[0]), -6 + float(off[1]))
	return hel


func _row_panel(side: int, row: String) -> Control:
	var p := _panel(Color(0, 0, 0, 0.22), Color("#b8923e", 0.35), 3)
	p.custom_minimum_size = Vector2(0, 98)
	var h := UIKit.hbox(8)
	p.add_child(h)
	var lead := UIKit.vbox(0)
	lead.custom_minimum_size = Vector2(70, 0)
	lead.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UIKit.icon("ironfront/row_" + row, 40)
	ic.tooltip_text = Ironfront.ROW_NAMES[row]
	lead.add_child(ic)
	var tot := _lbl("0", 28, "initial", UIKit.PAPER)
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lead.add_child(tot)
	h.add_child(lead)
	var box := UIKit.hbox(4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(box)
	var tag := _lbl("", 16, "body_italic")
	tag.custom_minimum_size = Vector2(66, 0)
	h.add_child(tag)
	rows["%d:%s" % [side, row]] = {"panel": p, "box": box, "total": tot, "tag": tag}
	return p


# ====================================================================== refresh
func _refresh() -> void:
	views.clear()
	var my_turn: bool = int(m["turn"]) == ME and not m["over"] and not busy
	for side in 2:
		var sd: Dictionary = m["sides"][side]
		for r: String in Ironfront.ROWS:
			var rw: Dictionary = rows["%d:%s" % [side, r]]
			var box: HBoxContainer = rw["box"]
			UIKit.clear(box)
			var cards: Array = sd["rows"][r]
			box.add_theme_constant_override("separation", 4 if cards.size() <= 14 else -10)
			for c: Dictionary in cards:
				var v := IronfrontCard.new(c, 62, false, Ironfront.eff(m, side, r, c))
				v.hovered.connect(_zoom)
				v.clicked.connect(_on_board_click)
				if side == ME and _selected_is_decoy() and not c.get("decoy", false) and not Ironfront.has_ability(v.def, "elite"):
					v.highlight = true
				box.add_child(v)
				views[int(c["uid"])] = v
			var total := Ironfront.row_score(m, side, r)
			var key := "%d:%s" % [side, r]
			(rw["total"] as Label).text = str(total)
			if _prev_totals.has(key) and int(_prev_totals[key]) != total:
				_pop(rw["total"], ("+%d" if total > int(_prev_totals[key]) else "%d") % (total - int(_prev_totals[key])),
					Color("#9be07a") if total > int(_prev_totals[key]) else Color("#ff8a6a"), true)
			_prev_totals[key] = total
			var sb: StyleBoxFlat = (rw["panel"] as PanelContainer).get_theme_stylebox("panel")
			sb.bg_color = WEATHER_TINT[r] if m["weather"][r] else Color(0, 0, 0, 0.22)
			var tags: Array[String] = []
			if m["weather"][r]:
				tags.append(WEATHER_NAME[r])
			if int(sd["boost"][r]) > 0:
				tags.append("+%d" % int(sd["boost"][r]))
			(rw["tag"] as Label).text = "\n".join(tags)
		var inf: Dictionary = side_info[side]
		(inf["score"] as Label).text = str(Ironfront.score(m, side))
		var gems: HBoxContainer = inf["gems"]
		UIKit.clear(gems)
		var need := 1 if Ironfront.is_blitz(m) else 2
		for i in need:
			var g := UIKit.icon("ironfront/gem_on" if int(sd["wins"]) > i else "ironfront/gem_off", 28)
			g.tooltip_text = "Rounds won"
			gems.add_child(g)
		var st := "%d in hand · %d in deck" % [sd["hand"].size(), sd["deck"].size()]
		if sd["passed"]:
			st += "\nPASSED"
		(inf["hand"] as Label).text = st
	# hands
	UIKit.clear(hand_box)
	var me: Dictionary = m["sides"][ME]
	var n: int = me["hand"].size()
	var w := minf(108.0, 1180.0 / maxf(1.0, float(n)) - 6.0)
	for c: Dictionary in me["hand"]:
		var v := IronfrontCard.new(c, w, false, int(c["str"]))
		v.set_meta("uid", int(c["uid"]))
		v.hovered.connect(_zoom)
		v.clicked.connect(_on_hand_click)
		v.set_selected.call_deferred(int(c["uid"]) == selected_uid)
		if not my_turn:
			v.modulate = Color(0.75, 0.75, 0.75)
		hand_box.add_child(v)
		views[int(c["uid"])] = v
	UIKit.clear(opp_hand_box)
	var foe: Dictionary = m["sides"][FOE]
	for c: Dictionary in foe["hand"]:
		var shown: bool = foe["reveal_all"] or foe["revealed"].has(c["uid"])
		var v := IronfrontCard.new(c, 30, not shown, -1)
		if shown:
			v.hovered.connect(_zoom)
		opp_hand_box.add_child(v)
	# centre texts
	round_label.text = ("Blitzkrieg" if Ironfront.is_blitz(m) else "Round %d of 3" % int(m["round"]))
	var wl: Array[String] = []
	for r: String in Ironfront.ROWS:
		if m["weather"][r]:
			wl.append("%s on the %s front" % [WEATHER_NAME[r], Ironfront.ROW_NAMES[r]])
	if Ironfront.is_blitz(m):
		var lim := int(Ironfront.data().get("blitz", {}).get("plays", 7))
		wl.append("Orders left: you %d, %s %d" % [lim - int(me["plays"]), foe["name"], lim - int(foe["plays"])])
	weather_label.text = "\n".join(wl) if not wl.is_empty() else "Clear skies, firm ground."
	pass_btn.disabled = not my_turn
	var cm := Ironfront.commander(str(me["commander"]))
	cmd_btn.text = "Order: " + str(cm.get("name", "Commander")).replace("The ", "")
	cmd_btn.tooltip_text = str(cm.get("text", "")) + "\nOnce per match; uses your turn."
	cmd_btn.disabled = not my_turn or me["cmd_used"]
	if m["over"]:
		status_label.text = "The match is over"
	elif busy or int(m["turn"]) == FOE:
		status_label.text = "%s is thinking…" % foe["name"]
	elif selected_uid >= 0:
		status_label.text = "Click a highlighted unit for the decoy" if _selected_is_decoy() else "Click the card again to deploy it"
	elif foe["passed"]:
		status_label.text = "%s has passed — your move (%d to %d)" % [foe["name"], Ironfront.score(m, ME), Ironfront.score(m, FOE)]
	else:
		status_label.text = "Your move — play a card or pass"
	var lines: Array = m["log"].slice(maxi(0, m["log"].size() - 40))
	log_label.text = "\n".join(lines.map(func(l): return str(l).replace("[", "(")))
	_coach()


func _selected_is_decoy() -> bool:
	if selected_uid < 0:
		return false
	for c: Dictionary in m["sides"][ME]["hand"]:
		if int(c["uid"]) == selected_uid:
			return Ironfront.card(str(c["id"])).get("effect", "") == "decoy"
	return false


func _zoom(v: IronfrontCard) -> void:
	UIKit.clear(zoom_holder)
	var big := IronfrontCard.new(v.inst, 208, false, v.strength)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_holder.add_child(big)
	var d := v.def
	var t := "[b]%s[/b]  [i]%s[/i]\n" % [d.get("name", ""), ("%s · strength %d" % [Ironfront.ROW_NAMES.get(str(d.get("row", "")), ""), int(d.get("str", 0))]) if d.get("type", "") == "unit" else "Tactic"]
	var ab := Ironfront.ability_text(d)
	if ab != "":
		t += ab + "\n"
	t += "[i]%s[/i]" % d.get("flavor", "")
	zoom_text.text = t


# ====================================================================== input
func hand_views() -> Array:
	return hand_box.get_children()


func _on_hand_click(v: IronfrontCard) -> void:
	if busy or m["over"] or int(m["turn"]) != ME:
		return
	var uid := int(v.inst["uid"])
	if uid == selected_uid:
		if _selected_is_decoy():
			return
		selected_uid = -1
		play_move({"type": "play", "uid": uid})
		return
	selected_uid = uid
	Audio.play("sfx/page_turn", -10.0)
	_refresh()


func _on_board_click(v: IronfrontCard) -> void:
	if not _selected_is_decoy() or not v.highlight:
		return
	var uid := selected_uid
	selected_uid = -1
	play_move({"type": "play", "uid": uid, "target": int(v.inst["uid"])})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and selected_uid >= 0:
		selected_uid = -1
		_refresh()


func _on_pass() -> void:
	play_move({"type": "pass"})


func _on_concede() -> void:
	if m["over"] or _ended:
		return
	Ironfront.concede(m, ME)
	m["events"].clear()
	_finish(false)


func _on_commander() -> void:
	play_move({"type": "commander"})


## Applies a move for the player (also used by the play-test driver).
func play_move(mv: Dictionary) -> bool:
	if busy or m["over"] or int(m["turn"]) != ME:
		return false
	if not Ironfront.apply(m, ME, mv):
		Audio.play("sfx/error", -8.0)
		return false
	selected_uid = -1
	_after()
	return true


func _after() -> void:
	_refresh()
	var round_ended := _play_events()
	if m["over"]:
		_finish(round_ended)
		return
	if int(m["turn"]) == FOE:
		_ai_turn(round_ended)


func _ai_turn(after_round := false) -> void:
	busy = true
	_refresh()
	await get_tree().create_timer(ai_delay + (2.0 if after_round else 0.0)).timeout
	if not is_inside_tree() or m["over"]:
		busy = false
		return
	var mv := Ironfront.ai_move(m, FOE)
	if mv.is_empty() or not Ironfront.apply(m, FOE, mv):
		Ironfront.apply(m, FOE, {"type": "pass"})
	busy = false
	_after()


# ====================================================================== effects
func _play_events() -> bool:
	var round_ended := false
	var k := 0
	for e: Dictionary in m["events"]:
		var side := int(e.get("side", 0))
		match str(e.get("k", "")):
			"play":
				var v: IronfrontCard = views.get(int(e["uid"]))
				if v:
					v.slide_from(Vector2(0, 260) if side == ME else Vector2(0, -260), k * 0.09)
					k += 1
				Audio.play("sfx/page_turn", -6.0, 0.9)
			"dmg":
				var v: IronfrontCard = views.get(int(e["uid"]))
				if v:
					_pop(v, "-%d" % int(e["n"]), Color("#ff7a5a"))
				Audio.play("sfx/dice_land", -6.0, 0.7)
			"block":
				var v: IronfrontCard = views.get(int(e["uid"]))
				if v:
					_pop(v, "dug in", Color("#e6c46a"))
			"boost":
				var v: IronfrontCard = views.get(int(e["uid"]))
				if v:
					_pop(v, "+%d" % int(e["n"]), Color("#9be07a"))
			"pass":
				_pop(side_info[side]["portrait"], "Pass!", Color("#e6c46a"))
			"commander":
				_pop(side_info[side]["portrait"], "Orders!", Color("#e6c46a"))
				Audio.play("sfx/level_up", -10.0)
			"steal", "reveal":
				Audio.play("sfx/reveal_common", -8.0)
			"round_end":
				round_ended = true
				var w := int(e["winner"])
				var sc: Array = e["scores"]
				var who: String = "Drawn round" if w == 2 else ("You win the round" if w == ME else "%s wins the round" % m["sides"][FOE]["name"])
				_banner("%s\n%d : %d" % [who, int(sc[0]), int(sc[1])], w)
				_prev_totals.clear()
	m["events"].clear()
	return round_ended


func _pop(target: Control, text: String, col: Color, side_offset := false) -> void:
	if not is_instance_valid(target) or fx == null:
		return
	var l := _lbl(text, 30, "initial", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	fx.add_child(l)
	var tr := target.get_global_rect()
	l.global_position = tr.position + (Vector2(tr.size.x + 6, -4) if side_offset else Vector2(tr.size.x / 2 - 18, 0))
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y - 46, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.tween_callback(l.queue_free)


func _banner(text: String, winner: int) -> void:
	var p := _panel(Color(0.1, 0.06, 0.03, 0.92), Color("#e6c46a"), 18)
	var l := _lbl(text, 44, "title", Color("#9be07a") if winner == ME else Color("#ff8a6a") if winner == FOE else Color("#e6c46a"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	fx.add_child(p)
	p.reset_size()
	p.position = (size - p.size) / 2.0 - Vector2(0, 40)
	p.pivot_offset = p.size / 2
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.7)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	Audio.play("sfx/check_great" if winner == ME else "sfx/check_poor", -6.0)


func _finish(after_round: bool) -> void:
	if _ended:
		return
	_ended = true
	busy = true
	_refresh()
	var reward := Ironfront.finish_reward(m)
	finished.emit(m, reward)
	if after_round and is_inside_tree():
		await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	_result_overlay(reward)


func _result_overlay(reward: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	p.custom_minimum_size = Vector2(760, 0)
	cc.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	var res: String = reward.get("result", "draw")
	var head: String = {"win": "Victory!", "loss": "Defeat", "draw": "A Draw"}[res]
	var t := UIKit.title(head, 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", UIKit.RUBRIC if res != "loss" else UIKit.INK)
	v.add_child(t)
	var foe_name: String = m["sides"][FOE]["name"]
	var lines: Array[String] = []
	for i in m["rounds"].size():
		var r: Dictionary = m["rounds"][i]
		lines.append("%s: you %d, %s %d" % ["Blitzkrieg" if Ironfront.is_blitz(m) else "Round %d" % (i + 1), int(r["scores"][0]), foe_name, int(r["scores"][1])])
	var say: String = {"win": "\"Splendid! Textbook envelopment. I shall be drawing diagrams of that for a week.\"",
		"loss": "\"Hard luck — but you held the line longer than most. Same time tomorrow?\"",
		"draw": "\"A stalemate! Very Western Front. Very muddy. Tea?\""}[res]
	if str(opp.get("id", "")) != "barnaby":
		say = {"win": "%s grumbles and pushes the winnings across the felt." % foe_name, "loss": "%s grins and gathers up the cards." % foe_name,
			"draw": "%s shrugs. \"Again sometime.\"" % foe_name}[res]
	var body: String = "\n".join(lines) + "\n\n[i]" + say + "[/i]"
	if int(reward.get("gold", 0)) > 0:
		body += "\n\n[b]+%d gold[/b]" % int(reward["gold"])
	for oid: String in reward.get("unlocked", []):
		body += "\n[b]New opponent at the table:[/b] " + str(Ironfront.opponent(oid).get("name", oid))
	var rt := UIKit.rich(body, 22)
	v.add_child(rt)
	if not reward.get("cards", []).is_empty():
		v.add_child(UIKit.label("New cards for your collection:", 22, "body_bold"))
		var row := UIKit.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for id: String in reward["cards"]:
			var cv := IronfrontCard.new({"id": id}, 150, false, -1)
			cv.hovered.connect(_zoom)
			row.add_child(cv)
		v.add_child(row)
	var bh := UIKit.hbox(12)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(UIKit.button("Rematch", func(): rematch_requested.emit(), 200))
	bh.add_child(UIKit.button("Back to the war-room", func(): leave_requested.emit(), 300))
	v.add_child(bh)


# ====================================================================== tutorial coach
func _tip(id: String, text: String) -> bool:
	if tips_seen.has(id):
		return false
	tips_seen[id] = true
	coach_label.text = text
	coach_box.visible = true
	return true


func _coach() -> void:
	if not m.get("tutorial", false):
		return
	var me: Dictionary = m["sides"][ME]
	var foe: Dictionary = m["sides"][FOE]
	var any_ability := false
	for c: Dictionary in me["hand"]:
		if not Ironfront.card(str(c["id"])).get("abilities", []).is_empty():
			any_ability = true
	if int(m["round"]) == 1 and int(me["plays"]) == 0 and int(m["turn"]) == ME:
		_tip("start", "Welcome to the war-room! Each card fights on its own front: [b]Infantry[/b], [b]Armour[/b] or [b]Air[/b] (the icon top right). Click a card in your hand to lift it, click again to deploy it.")
	elif int(me["plays"]) == 1 and m["rounds"].is_empty():
		_tip("rows", "See the numbers at the left of each row? Those are the front totals; the big number by your portrait is your whole army. The higher army wins the round.")
	elif any_ability and int(me["plays"]) >= 2 and m["rounds"].is_empty():
		_tip("abilities", "The little brass medallions are abilities. Hover a card to read it on the right: Artillery shells the strongest enemy in a row, Supply Line draws a card, Spotters peek at my hand…")
	if foe["passed"] and not me["passed"] and int(m["turn"]) == ME:
		_tip("passed_%d" % int(m["round"]), "I have [b]passed[/b]! I can't play again this round, so you only need to get ahead by one — then pass and keep your other cards for later.")
	if not m["rounds"].is_empty() and int(m["round"]) == 2:
		_tip("round2", "Best of three rounds, and cards do not come back. Winning a round with fewer cards is the whole art. Your [b]Commander[/b] order works once per match.")
	if m["over"]:
		_tip("over", "That's the game! Win matches to earn cards, buy packs from my shelf and build your own deck. Merchants and expeditions turn up rare ones, too.")
		if int(m.get("winner", -1)) == ME:
			coach_label.text = "[b]A victory — and a fine one![/b] You won it the way generals do: strength where it mattered, cards kept back where it didn't. The war-room is yours; my Field Manual explains every card, a lesson at a time."
		return
	# v1.7 (#70): explain each ability the first time it appears on the table, then Barnaby's suggested move and why
	var lines := []
	for sd in [ME, FOE]:
		for row in Ironfront.ROWS:
			for c: Dictionary in m["sides"][sd]["rows"][row]:
				_note_card(str(c["id"]), lines, sd == FOE)
	if int(m["turn"]) == ME:
		for c: Dictionary in me["hand"]:
			_note_card(str(c["id"]), lines, false)
		var sug := Ironfront.suggest(m, ME)
		suggested_uid = int(sug.get("move", {}).get("uid", -1)) if str(sug.get("move", {}).get("type", "")) == "play" else -1
		var head := "" if lines.is_empty() else "\n".join(lines.slice(0, 2)) + "\n\n"
		coach_label.text = head + "[b]Barnaby suggests:[/b] " + str(sug.get("why", ""))
		coach_box.visible = true
		for v in hand_box.get_children():
			if v is CanvasItem:
				(v as CanvasItem).modulate = Color(1.12, 1.05, 0.8) if v.get_meta("uid", -1) == suggested_uid else Color.WHITE


var suggested_uid := -1
var explained := {}


## A card met for the first time in the teaching match: one plain line on what it does.
func _note_card(id: String, lines: Array, foe: bool) -> void:
	if explained.has(id):
		return
	var c := Ironfront.card(id)
	var ab := Ironfront.ability_text(c)
	if ab == "":
		return
	explained[id] = true
	lines.append("[i]%s%s:[/i] %s" % ["Barnaby's " if foe else "", c.get("name", id), ab.replace("\n", " ")])
