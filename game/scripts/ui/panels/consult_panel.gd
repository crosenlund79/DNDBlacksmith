## ConsultPanel — an adventurer asks the smith's advice on their gear (The Living Realm 3b, Consult).
## EN: Progressive disclosure: their question and 3–4 concrete recommendations with the odds in words come first;
##     each card shows why in one line; "Details" opens the facts and the reasons behind the odds. Above: where
##     they are bound, what waits there (weak to / resists) and their gear (hover: tooltip, click: inspect).
##     The smith puts forward up to two; the answer comes in their own voice with what it changed.
## DA: En eventyrer beder om råd om sit udstyr: spørgsmål, anbefalinger med odds, hvorfor, detaljer.
class_name ConsultPanel
extends UIWindow

const CARD_W := 690.0
const PROP_ICON := {"fire": "ui/stat_fire", "frost": "ui/stat_frost", "magic": "ui/need_magic", "physical": "ui/stat_damage"}
const KIND_ICON := {"repair": "ui/warn_worn", "buy": "icons/purse_gift", "coat": "icons/coating_flame", "commission": "ui/tb_orders",
	"upgrade": "icons/ingot_steel", "dest": "ui/act_road", "rest": "ui/act_candle", "elsewhere": "ui/ic_travel", "keep": "ui/stat_defence"}

var npc := ""
var body: VBoxContainer
var open_details := {}


func _init(id := "") -> void:
	npc = id
	super._init("A Word of Advice", 1500, 960)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 840))
	_build()


func _build() -> void:
	UIKit.clear(body)
	var a := Adv.get_a(npc)
	var ses := Consult.session(npc)
	if a.is_empty() or ses.is_empty():
		body.add_child(UIKit.label("They have gone.", 24, "body_italic"))
		return
	title_label.text = "A Word of Advice — %s" % a["name"]
	_header(a, ses)
	body.add_child(_facts(a, ses))
	body.add_child(UIKit.divider())
	_counsel(a, ses)


# ------------------------------------------------------------------ who is asking, and what
func _header(a: Dictionary, ses: Dictionary) -> void:
	var row := UIKit.hbox(18)
	row.add_child(UIKit.portrait("portraits/" + npc, 132))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var co := Companies.name_of(npc)
	v.add_child(UIKit.rich("[b]%s[/b] · %s %s, level %d · %d gold · %s%s" % [a["name"], Adv.rating_text(a), a["cls"], int(a["level"]), int(a.get("gold", 0)),
		str(Adv.TRAITS.get(str(a.get("trait", "")), "")).split(" — ")[0], (" · " + co) if co != "" else ""], 22))
	var goals := PackedStringArray()
	for g in Living.goals(a):
		goals.append(str(Living.GOAL_WORD.get(str(g["kind"]), g["kind"])))
	v.add_child(UIKit.rich("[color=#5e421c]Wants: %s · %s[/color]" % [", ".join(goals), Consult.credibility_word(npc)], 18))
	var q := UIKit.rich("[i]“%s”[/i]" % str(ses["question"]), 26)
	q.custom_minimum_size = Vector2(1100, 0)
	v.add_child(q)
	row.add_child(v)
	body.add_child(row)


# ------------------------------------------------------------------ the facts that matter
func _facts(a: Dictionary, ses: Dictionary) -> Control:
	var row := UIKit.hbox(28)
	# where they are bound and what waits there
	var left := UIKit.vbox(6)
	left.custom_minimum_size = Vector2(640, 0)
	var rid := str(ses.get("dest", ""))
	if rid == "":
		left.add_child(UIKit.label("No destination decided yet.", 20, "body_italic"))
	else:
		var hd := UIKit.hbox(8)
		hd.add_child(UIKit.icon("ui/act_road", 34))
		hd.add_child(_wide(UIKit.rich("Bound for [b]%s[/b] — %s, %s" % [Consult.dest_name(rid), WorldSites.danger_word(rid), Consult.danger_text(a, rid)], 21)))
		left.add_child(hd)
		for th in Consult.threats(rid):
			var t := UIKit.hbox(8)
			var weak := str(th.get("weak", ""))
			var res := str(th.get("resist", ""))
			t.add_child(UIKit.icon(str(PROP_ICON.get(weak, "ui/stat_damage")), 26))
			var bits := PackedStringArray()
			if weak != "":
				var have := Consult.coverage(a, weak) > 0
				bits.append("weak to [color=%s][b]%s[/b][/color]%s" % ["#26622f" if have else "#7e2418", weak, "" if have else " (they have none)"])
			if res != "":
				bits.append("resists %s" % res)
			bits.append("hits for %d" % int(th.get("dmg", 0)))
			t.add_child(_wide(UIKit.rich("%s — %s" % [str(th.get("name", "")).capitalize(), ", ".join(bits)], 19)))
			left.add_child(t)
	row.add_child(left)
	# their gear (hover for the tooltip, click to inspect)
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("Their gear — hover to read, click to inspect", 19, "heading_italic", UIKit.RUBRIC))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for slot in Adv.all_slots():
		var it: Dictionary = a["equipment"].get(slot, {})
		if it.is_empty():
			continue
		var s := ItemSlot.new(it, 64.0)
		s.clicked.connect(func(x): Events.open_panel.emit("item", {"uid": int(x.get("uid", -1))}))
		flow.add_child(s)
	right.add_child(flow)
	var warn := PackedStringArray()
	for w in Consult.worn_pieces(a):
		warn.append("%s %s" % [str(w["item"].get("name", "")), "broken" if bool(w["broken"]) else "at %d%%" % int(round(float(w["frac"]) * 100.0))])
	right.add_child(UIKit.rich(("[color=#7e2418]Worn: %s[/color]" % ", ".join(warn)) if not warn.is_empty() else "[color=#26622f]Everything in sound repair.[/color]", 18))
	right.add_child(UIKit.rich("HP %d / %d · strength %d" % [int(a.get("hp", 0)), int(a.get("hp_max", 0)), int(Consult.strength(a))], 18))
	row.add_child(right)
	return row


# ------------------------------------------------------------------ the recommendations
func _counsel(a: Dictionary, ses: Dictionary) -> void:
	var tr := Consult.track_record()
	var left := Consult.picks_left(ses)
	var head := UIKit.hbox(14)
	head.add_child(UIKit.label("Your counsel", 28, "heading"))
	var sub := UIKit.rich("[i]Put forward %s · your record as an adviser: %d proved right, %d wrong[/i]" % [
		("up to %d more" % left) if left > 0 else "nothing more today", int(tr["right"]), int(tr["wrong"])], 19)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sub)
	body.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	for rec in ses["recs"]:
		grid.add_child(_card(a, ses, rec, left))
	body.add_child(grid)
	var foot := UIKit.hbox(12)
	foot.add_child(UIKit.button("Finish the consultation", func():
		Consult.finish(npc)
		close(), 300))
	var hint := UIKit.label("Closing keeps today's consultation open; finishing lets them go.", 17, "body_italic")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	body.add_child(foot)


func _card(a: Dictionary, ses: Dictionary, rec: Dictionary, left: int) -> Control:
	var rid := str(rec["id"])
	var done: Dictionary = (ses["done"] as Dictionary).get(rid, {})
	var pc := PanelContainer.new()
	pc.name = "Rec_" + rid
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#eadcb6")
	sb.border_color = UIKit.INK
	if not done.is_empty():
		sb.border_color = Color("#2f6a1e") if bool(done.get("accepted", false)) else UIKit.RUBRIC
	sb.set_border_width_all(2)
	sb.border_width_left = 6
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(CARD_W, 0)
	var v := UIKit.vbox(5)
	pc.add_child(v)
	var h := UIKit.hbox(10)
	h.add_child(UIKit.icon(str(KIND_ICON.get(str(rec["kind"]), "ui/ic_talk")), 44))
	var hv := UIKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(str(Consult.KIND_WORD.get(str(rec["kind"]), "")).to_upper(), 14, "heading", UIKit.RUBRIC))
	var t := UIKit.rich("[b]%s[/b]" % str(rec["title"]), 21)
	t.custom_minimum_size = Vector2(CARD_W - 90, 0)
	hv.add_child(t)
	h.add_child(hv)
	v.add_child(h)
	v.add_child(UIKit.rich("[i]%s[/i]" % str(rec["why"]), 18))
	var od := Consult.odds(a, rec)
	var col := "#26622f" if float(od["p"]) >= 0.62 else ("#6a5a12" if float(od["p"]) >= 0.45 else "#7e2418")
	# the main reason for and against (the full list is under Details)
	var pro := ""
	var con := ""
	for r in od["reasons"]:
		if float(r[1]) >= 0.02 and pro == "":
			pro = str(r[0]).to_lower()
		elif float(r[1]) <= -0.02 and con == "":
			con = str(r[0]).to_lower()
	var main := "Odds: [color=%s][b]%s[/b][/color]" % [col, od["word"]]
	if pro != "":
		main += " · [color=#26622f]for:[/color] " + pro
	if con != "":
		main += " · [color=#7e2418]against:[/color] " + con
	if done.is_empty():
		v.add_child(UIKit.rich(main, 18))
	# details (progressive disclosure)
	if bool(open_details.get(rid, false)):
		var dv := UIKit.vbox(2)
		for d in rec.get("details", []):
			dv.add_child(UIKit.rich("· %s" % str(d), 17))
		var rs := PackedStringArray()
		for r in od["reasons"]:
			if absf(float(r[1])) >= 0.005:
				rs.append("[color=%s]%s %s[/color]" % ["#26622f" if float(r[1]) > 0.0 else "#7e2418", "+" if float(r[1]) > 0.0 else "−", str(r[0])])
		dv.add_child(UIKit.rich("[i]What weighs with them:[/i] " + " · ".join(rs), 16))
		v.add_child(dv)
	if not done.is_empty():
		var ok := bool(done.get("accepted", false))
		v.add_child(UIKit.rich("[color=%s][b]%s[/b][/color] (%s) %s" % ["#26622f" if ok else "#7e2418", "Accepted" if ok else "Refused", str(done.get("word", "")), str(done.get("text", ""))], 19))
		if str(done.get("effect", "")) != "":
			v.add_child(UIKit.rich("[i]%s[/i]" % str(done["effect"]), 17))
	var bh := UIKit.hbox(8)
	if done.is_empty():
		var b := UIKit.button("Advise this", func(): _advise(rid), 200)
		b.name = "Advise_" + rid
		b.disabled = left <= 0
		bh.add_child(b)
	bh.add_child(UIKit.button("Hide details" if bool(open_details.get(rid, false)) else "Details ▸", func():
		open_details[rid] = not bool(open_details.get(rid, false))
		_build(), 160))
	v.add_child(bh)
	return pc


static func _wide(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _advise(rid: String) -> void:
	var r := Consult.advise(npc, rid)
	if bool(r.get("ok", false)):
		Events.toast.emit("%s: %s" % [Talk.npc_name(npc), "takes your advice" if bool(r["accepted"]) else "won't take your advice"], "good" if bool(r["accepted"]) else "info")
	else:
		Events.toast.emit(str(r.get("text", "")), "bad")
	_build()
