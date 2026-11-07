## WantedPanel — the MOST WANTED board at the Tipsy Wyvern: Brindlewick's adventurers pinned up as
## parchment sheets, ranked by renown earned in the world (not by a timer).
## EN: Tabs: Most Wanted · Active Expeditions · At the Inn · Legends & History. Click a sheet for the
##     adventurer's dossier; click an expedition to observe it (Apprentice/Journeyman) or to read what
##     is known of it (Master: departures, destinations, rumours — the rest when they come home).
##     The board never pauses the world: expeditions keep moving while it is open.
## DA: Tavlen over landsbyens eventyrere, rangeret efter ry. Faner, dossierer og ekspeditionsvisning.
class_name WantedPanel
extends UIWindow

const STATUS_COL := {"At the Inn": Color("#26622f"), "Recruiting": Color("#735800"), "Preparing": Color("#735800"),
	"Adventuring": Color("#24409a"), "Returning": Color("#24409a"), "Recovering": Color("#9e3a0c"), "Missing": Color("#7e2418"), "Fallen": Color("#20140c")}

var tab := "wanted"
var body: Control
var tabs_row: HBoxContainer


func _init(t := "wanted") -> void:
	tab = t
	blocks_time = false
	super._init("Most Wanted", 1680, 940, true)
	if Assets.has_tex("ui/wanted_board"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.get_tex("ui/wanted_board")
		sb.texture_margin_left = 80
		sb.texture_margin_right = 80
		sb.texture_margin_top = 110
		sb.texture_margin_bottom = 70
		sb.content_margin_left = 54
		sb.content_margin_right = 54
		sb.content_margin_top = 34
		sb.content_margin_bottom = 40
		add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	super._ready()
	title_label.text = "✦ MOST WANTED ✦"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("#efe4cc"))
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	body = UIKit.vbox(10)
	var sc := UIKit.scroll(body, 690)
	content.add_child(sc)
	Events.expeditions_changed.connect(_build)
	Events.chronicle_added.connect(func(_e): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	UIKit.clear(tabs_row)
	for t in [["wanted", "Most Wanted"], ["active", "Active Expeditions"], ["inn", "At the Inn"], ["legends", "Legends & History"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; _build(), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(spacer)
	var dl := UIKit.label("Difficulty: %s%s" % [Expeditions.diff().get("name", ""), "" if Expeditions.can_observe() else " — what is known, not what is happening"], 18, "body_italic", UIKit.PAPER)
	dl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tabs_row.add_child(dl)
	UIKit.clear(body)
	match tab:
		"wanted":
			_sheets(_ranked().filter(func(a): return a["status"] != "dead"), true)
		"inn":
			_sheets(_ranked().filter(func(a): return a["status"] in ["in_town", "injured"]), false)
		"active":
			_active()
		"legends":
			_legends()


func _ranked() -> Array:
	var list := Adv.all().values()
	for a in list:
		Expeditions.ensure(a)
	list.sort_custom(func(a, b): return int(a.get("renown", 0)) > int(b.get("renown", 0)))
	return list


func _sheets(list: Array, numbered: bool) -> void:
	if list.is_empty():
		body.add_child(UIKit.label("No one here right now.", 22, "body_italic", UIKit.PAPER))
		return
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	var rank := 0
	for a in list:
		rank += 1
		var s := WantedSheet.new(a, rank if numbered else 0)
		s.pressed.connect(func(id): Events.open_panel.emit("dossier", {"id": id}))
		grid.add_child(s)
	body.add_child(grid)


func _active() -> void:
	var exps := Expeditions.active().values()
	var parties: Array = Expeditions.st()["parties"].values()
	if exps.is_empty() and parties.is_empty():
		body.add_child(UIKit.label("No one is out on the roads right now. Parties gather at the Wyvern at dawn and leave at eight.", 22, "body_italic", UIKit.PAPER))
	for p in parties:
		var names: Array = p["members"].map(func(i): return Adv.get_a(i)["name"])
		body.add_child(_card(UIKit.rich("[font_size=26][b]Forming at the Wyvern[/b][/font_size] — %s\nBound for [b]%s[/b]%s · leaving at 08:00" % [", ".join(names), Expeditions.region(p["dest"]).get("name", ""), " to search for the missing" if p.get("goal", "") == "search" else ""], 21), p["members"], []))
	for e in exps:
		var names2: Array = e["party"].map(func(i): return Adv.get_a(i)["name"])
		var reg := Expeditions.region(e["dest"])
		var txt := ""
		if Expeditions.can_observe():
			var n := Expeditions.node_of(e["dest"], str(e["at"]))
			var last: Dictionary = e["journal"][-1] if not e["journal"].is_empty() else {}
			txt = "[font_size=26][b]%s[/b][/font_size] — %s\n%s · %s · step %d of %d\n[i]%s %s[/i]" % [reg.get("name", ""), ", ".join(names2), _phase_word(e), n.get("name", "on the road"),
				mini(int(e["step"]) + 1, (e["route"] as Array).size()), (e["route"] as Array).size(), last.get("time", ""), last.get("text", "")]
		else:
			txt = "[font_size=26][b]%s[/b][/font_size] — %s\nLeft on day %d at %s. %s\n[i]Master difficulty: you will learn what happened when they come home.[/i]" % [reg.get("name", ""), ", ".join(names2),
				int(e["start"]) / 1440 + 1, "%02d:%02d" % [(int(e["start"]) % 1440) / 60, int(e["start"]) % 60], _rumour(e)]
		var btns := []
		if Expeditions.can_observe():
			var eid: String = e["id"]
			btns.append(UIKit.button("Observe Expedition", func(): Events.open_panel.emit("observe", {"id": eid}), 260))
		body.add_child(_card(UIKit.rich(txt, 21), e["party"], btns))


func _phase_word(e: Dictionary) -> String:
	return {"travel_out": "Travelling out", "moving": "On the move", "acting": "At a point of interest", "travel_back": "Returning home"}.get(str(e["phase"]), str(e["phase"]))


## Master difficulty: only what a traveller might say on the road.
func _rumour(e: Dictionary) -> String:
	var hours := (Game.now() - int(e["start"])) / 60
	if hours < 6:
		return "No word yet."
	var n := Expeditions.node_of(e["dest"], str(e["at"]))
	return "A carter says he saw them near %s." % n.get("name", "the road").to_lower()


func _legends() -> void:
	body.add_child(UIKit.label("Hall of renown", 28, "heading", UIKit.GILT))
	var top := _ranked().slice(0, 3)
	var hl := []
	for a in top:
		hl.append("[b]%s[/b] — %s, %d renown. %s" % [a["name"], Expeditions.renown_title(a), int(a.get("renown", 0)), (a["achievements"][-1]["text"] if not a.get("achievements", []).is_empty() else "")])
	body.add_child(UIKit.rich("\n".join(hl), 21, true))
	var fallen := _ranked().filter(func(a): return a["status"] == "dead")
	if not fallen.is_empty():
		body.add_child(UIKit.label("The fallen", 28, "heading", UIKit.GILT))
		body.add_child(UIKit.rich("\n".join(fallen.map(func(a): return "[b]%s[/b] — %s" % [a["name"], a.get("last_report", "fell on the road")])), 21, true))
	var legends := Chronicle.recent(12, ["legend", "chain", "victory", "death", "missing", "rescue", "renown"])
	if not legends.is_empty():
		body.add_child(UIKit.label("Told and retold", 28, "heading", UIKit.GILT))
		body.add_child(UIKit.rich("\n".join(legends.map(func(c): return "[color=#c8b898]Day %d %s[/color] — %s" % [int(c["day"]), c["time"], c["text"]])), 20, true))
	body.add_child(UIKit.label("Past expeditions (click to revisit)", 28, "heading", UIKit.GILT))
	for e in Expeditions.done().slice(0, 12):
		var eid: String = e["id"]
		var names: Array = e["party"].map(func(i): return Adv.get_a(i).get("name", i))
		var row := UIKit.hbox(10)
		var lab := UIKit.rich("Day %d — [b]%s[/b] at %s: %s" % [int(e["start"]) / 1440 + 1, ", ".join(names), Expeditions.region(e["dest"]).get("name", ""), e.get("summary", e.get("outcome", ""))], 19, true)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		row.add_child(UIKit.button("Revisit", func(): Events.open_panel.emit("observe", {"id": eid}), 140))
		body.add_child(row)


func _card(text: Control, party: Array, btns: Array) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Assets.panel_style("parchment"))
	var h := UIKit.hbox(14)
	for id in party:
		h.add_child(UIKit.portrait("portraits/" + str(id), 86))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	for b in btns:
		h.add_child(b)
	p.add_child(h)
	return p


## One pinned parchment sheet for an adventurer.
class WantedSheet extends Control:
	signal pressed(id: String)
	var a: Dictionary
	var rank := 0

	func _init(adv: Dictionary, r: int) -> void:
		a = adv
		rank = r
		custom_minimum_size = Vector2(286, 386)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Open %s's dossier" % a["name"]

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Audio.play("sfx/page_turn", -6.0)
			pressed.emit(a["id"])

	func _draw() -> void:
		var r := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		var tilt := deg_to_rad(float((absi(a["id"].hash()) % 5) - 2) * 0.8)
		draw_set_transform(size * 0.5, tilt, Vector2.ONE)
		var rr := Rect2(-r.size * 0.5, r.size)
		if Assets.has_tex("ui/wanted_sheet"):
			draw_texture_rect(Assets.get_tex("ui/wanted_sheet"), rr, false)
		else:
			draw_rect(rr, Color("#e6d4a8"))
			draw_rect(rr, Color("#5e421c"), false, 2.0)
		var ink := Color("#20140c")
		var f := Assets.font("title")
		var fb := Assets.font("heading")
		var fi := Assets.font("body_italic")
		var x0 := rr.position.x
		var w := rr.size.x
		var y := rr.position.y + 14
		if rank > 0:
			draw_string(f, Vector2(x0 + 14, y + 30), "#%d" % rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#7e2418"))
		var pr := Rect2(Vector2(-62, y + 6), Vector2(124, 124))
		draw_rect(pr.grow(4), ink)
		draw_texture_rect(Assets.get_tex("portraits/" + str(a["id"]), Vector2i(256, 256)), pr, false, Color(0.55, 0.5, 0.48) if a["status"] == "dead" else Color.WHITE)
		y += 152
		draw_string(f, Vector2(x0, y), a["name"], HORIZONTAL_ALIGNMENT_CENTER, w, 25, ink)
		y += 26
		draw_string(fi, Vector2(x0, y), Expeditions.renown_title(a), HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color("#7e2418"))
		y += 24
		draw_string(fb, Vector2(x0, y), "Level %d %s · renown %d" % [int(a["level"]), a["cls"], int(a.get("renown", 0))], HORIZONTAL_ALIGNMENT_CENTER, w, 18, ink)
		y += 26
		var sw := Expeditions.status_word(a)
		var sc: Color = WantedPanel.STATUS_COL.get(sw, ink)
		var where := ""
		if a["status"] == "away" and Expeditions.can_observe():
			where = " — " + Expeditions.region(str(a.get("dest", ""))).get("name", "")
		elif a["status"] == "away":
			where = " — " + Expeditions.region(str(a.get("dest", ""))).get("name", "")
		draw_string(fb, Vector2(x0, y), sw + where, HORIZONTAL_ALIGNMENT_CENTER, w, 19, sc)
		y += 14
		var ach: Array = a.get("achievements", [])
		var note := str(ach[-1]["text"]) if not ach.is_empty() else str(a.get("last_report", ""))
		if note != "":
			draw_multiline_string(fi, Vector2(x0 + 18, y + 18), note, HORIZONTAL_ALIGNMENT_CENTER, w - 36, 16, 3, Color("#5e421c"))
		if Assets.has_tex("ui/wax_seal"):
			draw_texture_rect(Assets.get_tex("ui/wax_seal"), Rect2(Vector2(rr.end.x - 62, rr.end.y - 62), Vector2(50, 50)), false)
		if Assets.has_tex("ui/pin"):
			draw_texture_rect(Assets.get_tex("ui/pin"), Rect2(Vector2(-14, rr.position.y - 10), Vector2(28, 28)), false)
		if a["status"] in ["dead", "missing"]:
			var stamp := "ui/stamp_fallen" if a["status"] == "dead" else "ui/stamp_missing"
			draw_set_transform(size * 0.5, tilt - 0.25, Vector2.ONE)
			if Assets.has_tex(stamp):
				draw_texture_rect(Assets.get_tex(stamp), Rect2(Vector2(-110, -10), Vector2(220, 80)), false, Color(1, 1, 1, 0.92))
			else:
				draw_string(f, Vector2(-110, 40), "FALLEN" if a["status"] == "dead" else "MISSING", HORIZONTAL_ALIGNMENT_CENTER, 220, 40, Color(0.6, 0.1, 0.06, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
