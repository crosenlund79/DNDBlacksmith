## ObserverPanel — watch an expedition (Apprentice/Journeyman), or revisit a finished one.
## EN: The parchment map of the region with the points of interest the party has reached, their
##     planned route and a marker that moves along the current leg as game time passes; party health
##     and conditions; the expedition clock and time controls; the timestamped journal. Click any
##     journal entry with ⚔/✦ to inspect that encounter: figures, health bars, every roll, the bonuses
##     (including the smith's item stats), damage, healing and the outcome. During a live fight the
##     actions appear as game time reaches them. Everything shown is read from the one authoritative
##     expedition record — the observer never rolls dice of its own and changes nothing.
## DA: Følg en ekspedition live (lette sværheder) eller genbesøg en afsluttet; alt læses fra den ene
##     autoritative ekspeditionspost.
class_name ObserverPanel
extends UIWindow

var exp_id := ""
var map_view: MapView
var enc_view: EncounterView
var side: VBoxContainer
var journal_box: VBoxContainer
var clock_label: Label
var _last_journal := -1
var _auto_rec := -1
var _t := 0.0


func _init(id: String) -> void:
	exp_id = id
	blocks_time = false
	super._init("", 1780, 980, true)


func _ready() -> void:
	super._ready()
	var e := Expeditions.get_exp(exp_id)
	if e.is_empty():
		content.add_child(UIKit.label("That expedition is no longer on record.", 22, "body_italic", UIKit.PAPER))
		return
	var live: bool = Expeditions.active().has(exp_id)
	if live and not Expeditions.can_observe():
		title_label.text = "Master difficulty"
		content.add_child(UIKit.label("On Master you cannot watch expeditions as they happen — you will hear what happened when they come home.", 22, "body_italic", UIKit.PAPER))
		return
	title_label.text = "%s — %s" % [Expeditions.region(e["dest"]).get("name", ""), "live" if live else "a past expedition"]
	var row := UIKit.hbox(16)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(1120, 630)
	map_view = MapView.new(e)
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(map_view)
	enc_view = EncounterView.new()
	enc_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	enc_view.visible = false
	enc_view.closed_view.connect(func(): _auto_rec = -2)
	stack.add_child(enc_view)
	row.add_child(stack)
	side = UIKit.vbox(6)
	side.custom_minimum_size = Vector2(560, 0)
	row.add_child(side)
	content.add_child(row)
	var jl := UIKit.vbox(2)
	journal_box = jl
	var sc := UIKit.scroll(jl, 190)
	content.add_child(sc)
	_side()
	_journal()


func _process(delta: float) -> void:
	_t += delta
	if map_view == null:
		return
	if _t >= 0.5:
		_t = 0.0
		_side()
		var e := Expeditions.get_exp(exp_id)
		if e.is_empty():
			return
		if e["journal"].size() != _last_journal:
			_journal()
		# a live fight opens itself (until the viewer closes it)
		if Expeditions.active().has(exp_id) and not e["encounters"].is_empty() and _auto_rec != -2:
			var ri: int = e["encounters"].size() - 1
			var rec: Dictionary = e["encounters"][ri]
			if rec.get("kind", "") == "combat" and Game.now() < int(rec["t"]) + int(rec.get("duration", 20)) and _auto_rec != ri:
				_auto_rec = ri
				enc_view.show_record(rec, e, true)


func _side() -> void:
	var e := Expeditions.get_exp(exp_id)
	if e.is_empty() or side == null:
		return
	UIKit.clear(side)
	var live: bool = Expeditions.active().has(exp_id)
	var tm := Game.time_string()
	side.add_child(UIKit.label("Day %d · %s%s" % [Game.day(), tm, "  ·  PAUSED" if Game.paused else ("  ·  ×%d" % Game.speed)], 26, "heading", UIKit.GILT))
	if live:
		var tc := UIKit.hbox(6)
		tc.add_child(UIKit.button("❚❚" if not Game.paused else "▶", func(): Game.toggle_pause(), 70))
		for sp in Game.SPEEDS:
			var v: int = sp
			var b := UIKit.button("×%d" % v, func(): Game.set_speed(v); Game.paused = false, 70)
			b.disabled = Game.speed == v and not Game.paused
			tc.add_child(b)
		side.add_child(tc)
		var phase: String = {"travel_out": "Travelling out", "moving": "On the move", "acting": "At a point of interest", "travel_back": "Returning home"}.get(str(e["phase"]), "")
		var n := Expeditions.node_of(e["dest"], str(e["at"]))
		var leg: Dictionary = e["leg"]
		var to := Expeditions.node_of(e["dest"], str(leg["to"]))
		var prog := clampf((float(Game.now()) - float(leg["t0"])) / maxf(1.0, float(leg["t1"]) - float(leg["t0"])), 0.0, 1.0)
		side.add_child(UIKit.rich("[b]%s[/b] — %s%s\nRoute step %d of %d · leg %d%%" % [phase, n.get("name", "the road") if str(e["phase"]) == "acting" else "towards " + str(to.get("name", "the village")),
			"" if e.get("goal", "") != "search" else " · searching for the missing", mini(int(e["step"]) + 1, (e["route"] as Array).size()), (e["route"] as Array).size(), int(prog * 100)], 20, true))
	else:
		side.add_child(UIKit.rich("[b]%s[/b]\n%s" % [str(e.get("outcome", "")).capitalize(), e.get("summary", "")], 20, true))
	side.add_child(UIKit.divider())
	for id in e["party"]:
		var a := Adv.get_a(id)
		var h := UIKit.hbox(8)
		h.add_child(UIKit.portrait("portraits/" + id, 64))
		var v := UIKit.vbox(0)
		var stt := Expeditions.status_word(a) if a.get("exp", "") == exp_id or not live else Expeditions.status_word(a)
		v.add_child(UIKit.label("%s · %s %d · %s" % [a["name"], a["cls"], int(a["level"]), stt], 18, "body_bold", UIKit.PAPER))
		var hb := UIKit.hbox(6)
		var hp := maxf(0.0, float(a["hp"])) if live else float(e["snap"].get(id, {}).get("hp", a["hp"]))
		hb.add_child(UIKit.bar(hp, float(a["hp_max"]), 160))
		hb.add_child(UIKit.label("%d/%d hp · fatigue %d · morale %d" % [int(hp), int(a["hp_max"]), int(a.get("fatigue", 0)), int(a.get("morale", 0))], 16, "body", UIKit.PAPER))
		v.add_child(hb)
		var w: Dictionary = a["equipment"].get("weapon", {})
		v.add_child(UIKit.label("%s%s" % [Items.display_name(w) if not w.is_empty() else "unarmed", " ⚒ your work" if str(w.get("crafted_by", "")).begins_with("Brannoc") else ""], 15, "body_italic", Items.color(w) if not w.is_empty() else UIKit.PAPER))
		h.add_child(v)
		h.add_child(UIKit.button("Dossier", func(): Events.open_panel.emit("dossier", {"id": id}), 110))
		side.add_child(h)
	if not e["loot"].is_empty():
		side.add_child(UIKit.rich("[color=#dab470]Carried home so far: %s[/color]" % ", ".join(e["loot"].slice(0, 6).map(func(it): return Items.display_name(it))), 17, true))


func _journal() -> void:
	var e := Expeditions.get_exp(exp_id)
	if e.is_empty() or journal_box == null:
		return
	_last_journal = e["journal"].size()
	UIKit.clear(journal_box)
	journal_box.add_child(UIKit.label("Expedition journal — click ⚔ or ✦ to inspect an encounter", 20, "heading", UIKit.GILT))
	for i in range(e["journal"].size() - 1, -1, -1):
		var j: Dictionary = e["journal"][i]
		var ri := int(j.get("rec", -1))
		var mark: String = {"victory": "⚔", "defeat": "⚔", "trap": "✦", "loot": "✦", "discovery": "✦", "rescue": "✦", "fail": "✦", "death": "✝", "missing": "?"}.get(str(j.get("kind", "")), "·")
		var txt := "Day %d %s  %s  %s" % [int(j.get("day", 1)), j.get("time", ""), mark, j["text"]]
		if ri >= 0:
			var b := UIKit.button(txt, func(): enc_view.show_record(e["encounters"][ri], e, false), 0)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			journal_box.add_child(b)
		else:
			journal_box.add_child(UIKit.label(txt, 17, "body", UIKit.PAPER))


## The region map with points of interest, the route and the party marker.
class MapView extends Control:
	var e: Dictionary

	func _init(ex: Dictionary) -> void:
		e = ex
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(_d: float) -> void:
		queue_redraw()

	func _to(p: Vector2) -> Vector2:
		return p * (size / Vector2(1280, 720))

	func _draw() -> void:
		var mid := "ui/maps/map_" + str(e["dest"])
		if Assets.has_tex(mid):
			draw_texture_rect(Assets.get_tex(mid), Rect2(Vector2.ZERO, size), false)
		else:
			draw_texture_rect(Assets.get_tex("ui/panel_parchment"), Rect2(Vector2.ZERO, size), false)
		var reg := Expeditions.region(e["dest"])
		var explored: Array = e["explored"]
		var ink := Color("#20140c")
		var f := Assets.font("heading")
		# links: explored ones strongly inked
		for n in reg.get("nodes", []):
			for l in n["links"]:
				var m := Expeditions.node_of(e["dest"], l)
				var strong: bool = (explored.has(l) and (explored.has(n["id"]) or n["kind"] == "entry"))
				draw_dashed_line(_to(Vector2(n["x"], n["y"])), _to(Vector2(m["x"], m["y"])), Color(0.5, 0.1, 0.05, 0.9) if strong else Color(0.13, 0.08, 0.05, 0.35), 4.0 if strong else 2.0, 10.0)
		# planned route (only on difficulties that allow detail)
		if Expeditions.can_observe():
			var prev := "gate"
			for r in e["route"]:
				var a := Expeditions.node_of(e["dest"], prev)
				var b := Expeditions.node_of(e["dest"], r)
				draw_line(_to(Vector2(a["x"], a["y"])), _to(Vector2(b["x"], b["y"])), Color(0.85, 0.65, 0.2, 0.35), 8.0)
				prev = r
		for n in reg.get("nodes", []):
			var p := _to(Vector2(n["x"], n["y"]))
			var seen: bool = explored.has(n["id"]) or n["kind"] == "entry"
			var col := Color("#7e2418") if n["kind"] == "boss" else ink
			draw_circle(p, 14.0, Color(0.94, 0.89, 0.8, 0.85 if seen else 0.4))
			draw_arc(p, 14.0, 0, TAU, 24, col, 3.0 if seen else 1.5)
			var icon: String = {"encounter": "⚔", "boss": "☠", "trap": "!", "chest": "▣", "resource": "✿", "shrine": "✚", "puzzle": "ᚱ", "traveller": "☺", "entry": "⌂", "path": "·"}.get(n["kind"], "·")
			draw_string(f, p + Vector2(-10, 7), icon, HORIZONTAL_ALIGNMENT_CENTER, 20, 18, col)
			var lab: String = n["name"] if seen else "?"
			draw_string(f, p + Vector2(-110, 36), lab, HORIZONTAL_ALIGNMENT_CENTER, 220, 18, Color(ink, 1.0 if seen else 0.5))
		# the party
		var mp := _to(Expeditions.marker_pos(e))
		if Assets.has_tex("ui/map_marker"):
			draw_texture_rect(Assets.get_tex("ui/map_marker"), Rect2(mp - Vector2(28, 28), Vector2(56, 56)), false)
		else:
			draw_arc(mp, 24.0, 0, TAU, 32, Color("#ffd27a"), 4.0)
		var i := 0
		for id in e["party"]:
			var sheet := Assets.get_tex("chars/" + str(id), Vector2i(768, 512))
			var src := Rect2(0, 0, sheet.get_width() / 6.0, sheet.get_height() / 4.0)
			var off := Vector2((i - (e["party"].size() - 1) * 0.5) * 34.0, -34.0 - absf(sin(Time.get_ticks_msec() / 300.0 + i)) * 3.0)
			draw_texture_rect_region(sheet, Rect2(mp + off - Vector2(32, 44), Vector2(64, 64)), src)
			i += 1


## A fight, rebuilt from its record: figures, health, each roll and bonus, as game time reaches it
## (live) or at a reading pace (revisiting).
class EncounterView extends Control:
	signal closed_view
	var rec: Dictionary = {}
	var ex: Dictionary = {}
	var live := false
	var shown := 0
	var timer := 0.0
	var log_label: RichTextLabel
	var btns: HBoxContainer
	var pop: Array = []   # [pos, text, color, life]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		log_label = UIKit.rich("", 17, true)
		log_label.position = Vector2(20, 400)
		log_label.size = Vector2(1080, 220)
		log_label.fit_content = false
		log_label.scroll_active = true
		log_label.scroll_following = true
		add_child(log_label)
		btns = UIKit.hbox(8)
		btns.position = Vector2(20, 14)
		btns.add_child(UIKit.button("◀ Back to the map", func(): visible = false; closed_view.emit(), 0))
		btns.add_child(UIKit.button("Show all", func(): shown = rec.get("actions", []).size(); _refresh_log(), 0))
		btns.add_child(UIKit.button("Replay", func(): shown = 0; timer = 0.0; live = false; _refresh_log(), 0))
		add_child(btns)

	func show_record(r: Dictionary, e: Dictionary, is_live: bool) -> void:
		rec = r
		ex = e
		live = is_live
		shown = 0
		timer = 0.0
		visible = true
		pop.clear()
		_refresh_log()

	func _process(delta: float) -> void:
		if not visible or rec.is_empty():
			return
		var acts: Array = rec.get("actions", [])
		if live:
			var n := 0
			for a in acts:
				if Game.now() >= int(rec["t"]) + int(a.get("t", 0)):
					n += 1
			if n > shown:
				for k in range(shown, n):
					_popup(acts[k])
				shown = n
				_refresh_log()
		else:
			timer += delta
			if timer >= 0.75 and shown < acts.size():
				timer = 0.0
				_popup(acts[shown])
				shown += 1
				_refresh_log()
		for p in pop:
			p[3] -= delta
			p[0] += Vector2(0, -30) * delta
		pop = pop.filter(func(p): return p[3] > 0.0)
		queue_redraw()

	func _popup(a: Dictionary) -> void:
		var pos := _target_pos(str(a.get("target", "")))
		if a.has("dmg") and a.get("hit", false):
			pop.append([pos + Vector2(0, -60), ("CRIT %d" if a.get("crit", false) else "-%d") % int(a["dmg"]), Color("#ff6a40") if a["kind"] != "enemy" else Color("#ff9a80"), 1.2])
			Audio.play("sfx/hammer_%d" % randi_range(1, 3) if a["kind"] == "attack" else "sfx/check_poor", -10.0)
		elif a.has("heal"):
			pop.append([pos + Vector2(0, -60), "+%d" % int(a["heal"]), Color("#8ad070"), 1.2])
		elif a.get("hit", true) == false:
			pop.append([pos + Vector2(0, -60), "miss", Color("#c8b898"), 0.9])

	func _target_pos(name: String) -> Vector2:
		var party: Array = rec.get("party", [])
		for i in party.size():
			if party[i]["name"] == name:
				return _ppos(i, party.size())
		var en: Array = rec.get("enemies", [])
		for i in en.size():
			if en[i]["name"] == name:
				return _epos(i, en.size())
		return Vector2(560, 200)

	func _ppos(i: int, n: int) -> Vector2:
		return Vector2(250 - (i % 2) * 70, 150 + (i - (n - 1) * 0.5) * 70 + 80)

	func _epos(i: int, n: int) -> Vector2:
		return Vector2(820 + (i % 2) * 90, 150 + (i - (n - 1) * 0.5) * 66 + 80)

	func _refresh_log() -> void:
		var lines := []
		var acts: Array = rec.get("actions", [])
		for k in mini(shown, acts.size()):
			var a: Dictionary = acts[k]
			var ln := "[b]%s[/b]" % a.get("txt", "")
			if a.has("roll"):
				ln += "  [color=#c8b898](d20 %d %+d = %d vs %d)[/color]" % [int(a["roll"]), int(a.get("mod", 0)), int(a.get("total", 0)), int(a.get("vs", 0))]
			var parts: Array = a.get("parts", [])
			if not parts.is_empty() and a.get("hit", true):
				ln += "\n      [color=#dab470]" + " · ".join(parts.map(func(p): return "%s %+d" % [p[0], int(p[1])] if int(p[1]) != 0 else str(p[0]))) + "[/color]"
			lines.append(ln)
		if shown >= acts.size() and not acts.is_empty():
			lines.append("[font_size=22][b]%s[/b][/font_size]%s%s" % [{"victory": "Victory", "retreat": "Retreat", "defeat": "Defeat"}.get(rec.get("outcome", ""), ""),
				("  · %d xp" % int(rec.get("xp", 0))) if int(rec.get("xp", 0)) > 0 else "", ("  · loot: " + ", ".join(rec.get("loot", []))) if not rec.get("loot", []).is_empty() else ""])
		if rec.get("kind", "") != "combat":
			lines = []
			for c in rec.get("checks", []):
				lines.append("[b]%s[/b] tried to %s: %s — [b]%s[/b]" % [c["who"], c["what"], c["txt"], "success" if c["ok"] else "failure"])
			if rec.has("damage"):
				lines.append("%s took %d damage." % [rec["damage"]["who"], int(rec["damage"]["dmg"])])
			if rec.has("loot"):
				lines.append("Found: " + ", ".join(rec["loot"]))
		log_label.text = "\n".join(lines)

	func _hp_now() -> Dictionary:
		var hp := {}
		for p in rec.get("party", []):
			hp[p["name"]] = int(p["hp"])
		for en in rec.get("enemies", []):
			hp[en["name"]] = int(en["hp_max"])
		var acts: Array = rec.get("actions", [])
		for k in mini(shown, acts.size()):
			var a: Dictionary = acts[k]
			if a.has("hp_after"):
				var who := str(a.get("target", a.get("actor", "")))
				if a["kind"] == "potion":
					who = str(a["actor"])
				hp[who] = int(a["hp_after"])
		return hp

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.03, 0.93))
		if Assets.has_tex("ui/panel_dark"):
			draw_texture_rect(Assets.get_tex("ui/panel_dark"), Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.5))
		var f := Assets.font("title")
		var fb := Assets.font("heading")
		draw_string(f, Vector2(0, 50), rec.get("node_name", ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#efe4cc"))
		if rec.get("kind", "") != "combat":
			draw_string(fb, Vector2(0, 90), {"trap": "A trap", "chest": "A locked chest", "puzzle": "A rune door", "traveller": "A traveller"}.get(rec.get("kind", ""), ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color("#c8b898"))
			return
		var hp := _hp_now()
		var acts: Array = rec.get("actions", [])
		var cur: Dictionary = acts[shown - 1] if shown > 0 and shown <= acts.size() else {}
		var party: Array = rec.get("party", [])
		for i in party.size():
			var p: Dictionary = party[i]
			var pos := _ppos(i, party.size())
			var acting := str(cur.get("actor", "")) == str(p["name"])
			var sheet := Assets.get_tex("chars/" + str(p["id"]), Vector2i(768, 512))
			var src := Rect2(sheet.get_width() / 6.0 * (2 if acting else 0), sheet.get_height() / 4.0, sheet.get_width() / 6.0, sheet.get_height() / 4.0)
			var down := int(hp.get(p["name"], 1)) <= 0
			draw_texture_rect_region(sheet, Rect2(pos - Vector2(64, 96) + (Vector2(18, 0) if acting else Vector2.ZERO), Vector2(128, 128)), src, Color(0.5, 0.45, 0.42) if down else Color.WHITE)
			_bar(pos + Vector2(-40, 40), int(hp.get(p["name"], 0)), int(p["hp_max"]), Color("#8ad070"))
			draw_string(fb, pos + Vector2(-90, 66), p["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("#efe4cc"))
			var w: Dictionary = p.get("weapon", {})
			draw_string(fb, pos + Vector2(-110, 84), "%s%s" % [w.get("name", ""), " ⚒" if w.get("crafted", false) else ""], HORIZONTAL_ALIGNMENT_CENTER, 220, 13, Items.COL_DARK.get(w.get("rarity", "common"), Color.WHITE))
		var en: Array = rec.get("enemies", [])
		for i in en.size():
			var eo: Dictionary = en[i]
			var pos := _epos(i, en.size())
			var acting := str(cur.get("actor", "")) == str(eo["name"])
			var tex := Assets.get_tex("enemies/" + str(eo["id"]), Vector2i(256, 128))
			var fw := tex.get_width() / 2.0
			var src := Rect2(fw if acting else 0.0, 0, fw, tex.get_height())
			var sz := Vector2(fw, tex.get_height()) * (128.0 / tex.get_height()) * (1.35 if tex.get_height() > 150 else 1.0)
			var dead := int(hp.get(eo["name"], 1)) <= 0
			draw_texture_rect_region(tex, Rect2(pos - Vector2(sz.x * 0.5, sz.y * 0.75) - (Vector2(18, 0) if acting else Vector2.ZERO), sz), src, Color(0.4, 0.35, 0.33, 0.55) if dead else Color.WHITE)
			_bar(pos + Vector2(-40, 40), int(hp.get(eo["name"], 0)), int(eo["hp_max"]), Color("#ff6a40"))
			draw_string(fb, pos + Vector2(-90, 66), eo["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("#efe4cc"))
			var tags := ("weak to " + str(eo["weak"])) if str(eo.get("weak", "")) != "" else ""
			if str(eo.get("resist", "")) != "":
				tags += ("; " if tags != "" else "") + "resists " + str(eo["resist"])
			if tags != "":
				draw_string(fb, pos + Vector2(-110, 84), tags, HORIZONTAL_ALIGNMENT_CENTER, 220, 13, Color("#c8b898"))
		for p in pop:
			draw_string(f, p[0] - Vector2(60, 0), p[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(p[2], clampf(p[3], 0.0, 1.0)))

	func _bar(at: Vector2, v: int, mx: int, col: Color) -> void:
		draw_rect(Rect2(at, Vector2(80, 8)), Color(0.1, 0.06, 0.04))
		draw_rect(Rect2(at, Vector2(80.0 * clampf(float(v) / maxf(1.0, mx), 0.0, 1.0), 8)), col)
		draw_rect(Rect2(at, Vector2(80, 8)), Color("#20140c"), false, 1.0)
