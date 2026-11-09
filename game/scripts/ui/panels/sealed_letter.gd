## SealedLetterPanel — sealed correspondence left while the smith was away (Milestone S1, canonical v1.1 §4.5).
## EN: Shown only for real sealed letters (Steward.letters(): unopened, sealed deferrals from actual world events). The
##     envelope shows what a real letter shows — the sender, the day it arrived, the address and the wax seal — and
##     hides the contents. "Break the seal" reads it through Steward.open_letter(id) and offers the action that leads
##     to the actual pending matter (its route; the matter is then marked seen to); "Later" keeps it sealed (the
##     envelope chip on the HUD remains until it is opened). Several letters are taken one at a time.
## DA: Forseglede breve: kuverten viser afsender, dag og laksegl, men ikke indholdet. "Bryd seglet" åbner brevet og
##     fører til den egentlige sag; "Senere" lader det ligge forseglet.
class_name SealedLetterPanel
extends UIWindow

var letter_id := ""
var opened: Dictionary = {}
var stage: VBoxContainer


func _init(args := {}) -> void:
	letter_id = str(args.get("id", ""))
	super._init("A Sealed Letter", 980, 700)


func _ready() -> void:
	super._ready()
	stage = UIKit.vbox(10)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)
	if letter_id == "":
		var ls := Steward.letters()
		if not ls.is_empty():
			letter_id = str(ls[0]["id"])
	build()


func _entry() -> Dictionary:
	for e in Steward.deferred(true):
		if str(e["id"]) == letter_id:
			return e
	return {}


func build() -> void:
	UIKit.clear(stage)
	var e := _entry()
	if e.is_empty():
		stage.add_child(UIKit.label("There is no sealed letter waiting.", 22, "body_italic"))
		stage.add_child(UIKit.button("Close", close, 200))
		return
	if opened.is_empty():
		_envelope(e)
	else:
		_letter()


func _envelope(e: Dictionary) -> void:
	var n := Steward.letters().size()
	stage.add_child(UIKit.label("Left at the smithy while you were away%s." % ((" — %d sealed letters wait" % n) if n > 1 else ""), 18, "body_italic", Color("#6e5a40")))
	var env := Envelope.new()
	env.name = "Envelope"
	env.from_text = StewardUI.sender(e)
	env.day_text = "Arrived day %d, %s" % [int(e.get("day", 0)), str(e.get("time", ""))]
	env.to_text = "To Master %s\nThe Smithy, Brindlewick" % str(Game.state.get("player", {}).get("name", "Smith"))
	env.custom_minimum_size = Vector2(900, 440)
	stage.add_child(env)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ob := UIKit.button("Break the seal", _open, 280)
	ob.name = "OpenLetter"
	row.add_child(ob)
	var later := UIKit.button("Later", close, 180)
	later.name = "Later"
	later.tooltip_text = "It stays sealed; the envelope on the screen reminds you."
	row.add_child(later)
	stage.add_child(row)


func _open() -> void:
	opened = Steward.open_letter(letter_id)
	Audio.play("sfx/page_turn", -4.0)
	build()


func _letter() -> void:
	var paper := PanelContainer.new()
	paper.name = "LetterText"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f3ead2")
	sb.border_color = Color("#8a6a3a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 5
	paper.add_theme_stylebox_override("panel", sb)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("%s · %s" % [StewardUI.kind_name(str(opened.get("kind", ""))), "day %d, %s" % [int(opened.get("day", 0)), str(opened.get("time", ""))]], 18, "heading", UIKit.RUBRIC))
	var t := UIKit.rich("[i]%s[/i]" % str(opened.get("text", "")), 23)
	t.custom_minimum_size = Vector2(840, 0)
	v.add_child(t)
	v.add_child(UIKit.label("— " + StewardUI.sender(opened), 20, "heading_italic"))
	if bool(opened.get("resolved", false)) and str(opened.get("outcome", "")) != "":
		var oc := UIKit.label("Since then: " + str(opened["outcome"]), 18, "body_italic", Color("#6e5a40"))
		oc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		oc.custom_minimum_size = Vector2(840, 0)
		v.add_child(oc)
	paper.add_child(v)
	stage.add_child(paper)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var act: Dictionary = opened.get("action", {})
	var can_go := str(act.get("route", "")) != "" and not bool(opened.get("resolved", false))
	if can_go:
		var go := UIKit.button(_go_text(str(act["route"])), _follow, 320)
		go.name = "GoToMatter"
		if Steward.smith_away():
			go.disabled = true
			go.tooltip_text = StewardUI.away_note()
		row.add_child(go)
	var rest := Steward.letters().size()
	if rest > 0:
		row.add_child(UIKit.button("Next letter (%d)" % rest, func():
			letter_id = str(Steward.letters()[0]["id"])
			opened = {}
			build(), 0))
	var keep := UIKit.button("Keep it for later" if can_go else "Put it away", _put_away, 0)
	keep.name = "PutAway"
	row.add_child(keep)
	stage.add_child(row)


func _go_text(route: String) -> String:
	match route:
		"contracts": return "Read the offer at the Project Bench"
		"apprentice": return "Speak with your apprentice"
		"history": return "See the piece's history"
		"dossier": return "See who it concerns"
		"orders": return "See the commission"
		"shop": return "Go to the counter"
		"consult": return "Hear them out"
		"workshop": return "Open the Workshop Ledger"
	return "Go to the matter"


func _follow() -> void:
	var act: Dictionary = opened.get("action", {})
	Steward.resolve(letter_id)
	close()
	StewardUI.go(act)


func _put_away() -> void:
	# a letter whose matter is already settled (or leads nowhere) is seen to once read; others stay in Matters waiting
	if bool(opened.get("resolved", false)) or str(opened.get("action", {}).get("route", "")) == "":
		Steward.resolve(letter_id)
	close()


## The envelope: parchment, flap folds, the address in a hand, the sender in the corner, the wax seal on the flap.
class Envelope extends Control:
	var from_text := ""
	var day_text := ""
	var to_text := ""

	func _draw() -> void:
		var w := minf(size.x, 760.0)
		var h := minf(size.y - 10.0, 420.0)
		var r := Rect2(Vector2((size.x - w) * 0.5, 4.0), Vector2(w, h))
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.28))
		draw_rect(r, Color("#e9dcb8"))
		# paper grain: faint horizontal fibres
		for i in 18:
			var y := r.position.y + 12.0 + i * (h - 24.0) / 18.0
			draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y + 1.5), Color(0.55, 0.42, 0.25, 0.06), 1.0)
		var ink := Color("#3a2614")
		# the folds: the back flaps meet in the centre; the top flap carries the seal
		var c := r.position + Vector2(w * 0.5, h * 0.52)
		draw_line(r.position + Vector2(0, h), c, Color(0.45, 0.33, 0.18, 0.55), 2.0)
		draw_line(r.end, c, Color(0.45, 0.33, 0.18, 0.55), 2.0)
		var flap := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), c])
		draw_colored_polygon(flap, Color("#dfcfa4"))
		draw_polyline(PackedVector2Array([r.position, c, Vector2(r.end.x, r.position.y)]), Color(0.38, 0.27, 0.14, 0.8), 2.5)
		draw_rect(r, ink, false, 2.5)
		# the sender (top-left) and the day (top-right), as written on the outside
		var f := Assets.font("heading_italic")
		var fb := Assets.font("body_italic")
		draw_string(f, r.position + Vector2(24, 38), _fit(f, from_text, w * 0.55, 24), HORIZONTAL_ALIGNMENT_LEFT, w * 0.55, 24, ink)
		draw_string(fb, r.position + Vector2(w - 24 - 300, 38), day_text, HORIZONTAL_ALIGNMENT_RIGHT, 300, 18, Color("#6e5a40"))
		# the address in the lower half
		var lines := to_text.split("\n")
		for i in lines.size():
			draw_string(f, r.position + Vector2(w * 0.5 - 230, h - 92 + i * 34), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 460, 26 if i == 0 else 21, ink)
		# the wax seal where the flaps meet
		var s := 104.0
		if Assets.has_tex("ui/wax_seal"):
			draw_texture_rect(Assets.get_tex("ui/wax_seal"), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
			draw_circle(c, s * 0.42, Color("#7e2418"))

	## `t` shortened at a word boundary (with an ellipsis) so it fits `width` at `size` — never cut mid-word.
	static func _fit(font: Font, t: String, width: float, size: int) -> String:
		if font == null or font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return t
		var words := t.split(" ")
		while words.size() > 1:
			words.remove_at(words.size() - 1)
			var cand := " ".join(words).rstrip(" ,;:—-") + "…"
			if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				return cand
		return words[0] + "…"
