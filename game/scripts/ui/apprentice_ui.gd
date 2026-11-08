## ApprenticeUI — words and small pictures for the workshop apprentices, shared by the panels, the item views and
## the world (iteration 012): the maker line on apprentice-made pieces, short activity bubbles, status and phase
## words, station states, and the colours used for them.
## DA: Fælles tekster for lærlingene: mesterlinjen på deres arbejde, aktivitetsbobler og statusord.
class_name ApprenticeUI
extends RefCounted

const GOOD := Color("#26622f")
const BAD := Color("#9e3a0c")
const WARN := Color("#735800")
const MUTED := Color("#6e5a40")
const STATION_WORDS := {"not_installed": "not installed", "locked": "locked", "busy": "in use", "worn": "worn", "free": "free"}
const STATION_COLS := {"not_installed": Color("#8a7a60"), "locked": Color("#7e2418"), "busy": Color("#24409a"), "worn": Color("#9e3a0c"), "free": Color("#26622f")}
const KIND_NAMES := {"repair": "Repair", "commission": "Commission", "craft": "Crafting", "prep": "Preparation", "maintain": "Upkeep"}
const KIND_ICONS := {"repair": "ui/act_hammer", "commission": "ui/tb_orders", "craft": "ui/tb_designer", "prep": "icons/ingot_iron", "maintain": "ui/tb_property"}
const PRIORITY_NAMES := {1: "low", 2: "normal", 3: "urgent"}


static func _ready_state() -> bool:
	return not Game.state.is_empty() and Game.state.has("apprentices")


# ======================================================================= the maker line on a piece
## Is this piece the work of an apprentice (current or former)? (Their mark resolves through Apprentices.mark_info.)
static func is_apprentice_work(it: Dictionary) -> bool:
	if it.is_empty() or Provenance.is_mine(it):
		return false
	var mk := Provenance.maker(it)
	return str(mk.get("workshop", "")) == "ironhand" or not Apprentices.mark_info(str(mk.get("mark", ""))).is_empty()


static func _pron(maker_id: String) -> String:
	for pool in [Apprentices.staff(), Apprentices.alumni()] if _ready_state() else []:
		for a in pool:
			if str(a.get("id", "")) == maker_id:
				return "her" if bool(a.get("female", false)) else "his"
	return "their"


## "Made by Tomas Reed, apprentice at the Ironhand forge — his mark: the initials T.R. punched small …, under the eye
## of Brannoc Ironhand." ("" when it is not apprentice work.) `rich` adds bold/italic BBCode.
static func maker_line(it: Dictionary, rich := false) -> String:
	if not is_apprentice_work(it):
		return ""
	var mk := Provenance.maker(it)
	var info := Apprentices.mark_info(str(mk.get("mark", mk.get("id", ""))))
	var name := str(mk.get("name", info.get("maker", "an apprentice")))
	var at_forge := str(mk.get("workshop", "")) == "ironhand"
	var role := "apprentice at the Ironhand forge" if at_forge else ("once an apprentice at the Ironhand forge, now at " + str(mk.get("place", "a workshop of their own")))
	if at_forge and bool(info.get("alumni", false)):
		role = "then an apprentice at the Ironhand forge"
	var mark_desc := str(info.get("desc", Provenance.mark(it).get("desc", "")))
	var out := ("Made by [b]%s[/b], %s" if rich else "Made by %s, %s") % [name, role]
	if mark_desc != "":
		out += (" — %s mark: [i]%s[/i]" if rich else " — %s mark: %s") % [_pron(str(mk.get("id", ""))), mark_desc]
	if str(mk.get("supervisor", "")) == "smith":
		out += ", under the eye of %s" % Provenance.SMITH_NAME
	return out + "."


## A short version for tooltips and cards: "Tomas Reed, your apprentice (under your eye)".
static func maker_short(it: Dictionary) -> String:
	if not is_apprentice_work(it):
		return ""
	var mk := Provenance.maker(it)
	var info := Apprentices.mark_info(str(mk.get("mark", "")))
	var who := "your apprentice" if not bool(info.get("alumni", false)) else "once your apprentice"
	if str(mk.get("workshop", "")) != "ironhand":
		who = "once your apprentice, in a workshop of their own"
	return "%s, %s%s" % [str(mk.get("name", "")), who, " (under your eye)" if str(mk.get("supervisor", "")) == "smith" else ""]


# ======================================================================= activity words
## Imperative recipe step ("Draw out the blade") → gerund ("drawing out the blade").
static func gerund(op: String) -> String:
	var t := op.strip_edges()
	if t == "":
		return ""
	var sp := t.find(" ")
	var first := (t if sp < 0 else t.substr(0, sp)).to_lower()
	var rest := "" if sp < 0 else t.substr(sp)
	var punct := ""
	if first.ends_with(","):
		punct = ","
		first = first.trim_suffix(",")
	var parts := first.split("-")
	var w := parts[parts.size() - 1]
	parts[parts.size() - 1] = _ing(w)
	return "-".join(parts) + punct + rest


static func _ing(w: String) -> String:
	if w.length() < 2:
		return w + "ing"
	if w == "distil":
		return "distilling"
	if w.ends_with("ie"):
		return w.substr(0, w.length() - 2) + "ying"
	if w.ends_with("e") and not w.ends_with("ee"):
		return w.substr(0, w.length() - 1) + "ing"
	var v := "aeiou"
	var n := w.length()
	var groups := 0
	var prev_v := false
	for ch in w:
		var is_v := v.contains(ch)
		if is_v and not prev_v:
			groups += 1
		prev_v = is_v
	if groups == 1 and n >= 3 and not v.contains(w[n - 1]) and v.contains(w[n - 2]) and not v.contains(w[n - 3]) and not "wxy".contains(w[n - 1]):
		return w + w[n - 1] + "ing"
	return w + "ing"


## {icon, text} for an apprentice's activity bubble ("drawing out the blade", "mending Mira's helmet", "on a break").
static func bubble(a: Dictionary) -> Dictionary:
	var cur := Apprentices.current(a)
	match str(cur.get("phase", "off")):
		"off":
			return {"icon": "ui/act_road", "text": "home for the night"}
		"break":
			return {"icon": "icons/bread_cheese", "text": "on a break"}
		"carrying":
			var def := str(cur.get("carrying", ""))
			var nm := str(DB.item(def).get("name", "materials")).to_lower() if def != "" else "materials"
			return {"icon": ("icons/" + def) if def != "" and Assets.has_tex("icons/" + def) else "ui/act_road", "text": "fetching " + nm}
	var t := Apprentices.task(int(a.get("task", -1)))
	if t.is_empty():
		return {"icon": "ui/act_hammer", "text": "sweeping the floor"}
	var act := str(a.get("activity", ""))
	if act.begins_with("Waiting"):
		return {"icon": "ui/act_zzz", "text": act.substr(0, 1).to_lower() + act.substr(1)}
	var sid := str(cur.get("station", ""))
	var icon := station_icon(sid)
	match str(t.get("kind", "")):
		"repair":
			var it := Apprentices.repair_item(t)
			var who := str(t.get("target", ""))
			var whose := ""
			if who != "" and not who.is_valid_int():
				whose = Talk.npc_name(who).split(" ")[0] + "'s "
			return {"icon": icon, "text": "mending %s%s" % [whose if whose != "" else "a ", str(Items.def(it).get("name", "piece")).to_lower() if not it.is_empty() else "piece"]}
		"maintain":
			return {"icon": "ui/tb_property", "text": "tending the " + str(DB.station(str(t.get("target", ""))).get("name", "station")).to_lower()}
	if str(cur.get("phase", "")) != "working":
		return {"icon": "ui/act_road", "text": "going to the " + str(DB.station(sid).get("name", "station")).to_lower() if sid != "" else "about the workshop"}
	var ops := Apprentices.task_ops(t, a)
	var op: Dictionary = ops[mini(int(t.get("op", 0)), ops.size() - 1)] if not ops.is_empty() else {}
	var txt := gerund(str(op.get("op", "working")))
	if txt.length() > 34:
		txt = txt.substr(0, 32).strip_edges() + "…"
	return {"icon": icon, "text": txt}


static func station_icon(sid: String) -> String:
	var disc := str(DB.station(sid).get("discipline", "classic"))
	match disc:
		"alchemy":
			return "icons/potion_healing"
		"runecraft":
			return "icons/runestone_blank" if Assets.has_tex("icons/runestone_blank") else "ui/act_hammer"
		"stitching":
			return "icons/thread_linen" if Assets.has_tex("icons/thread_linen") else "ui/act_hammer"
	return "ui/act_hammer"


## A plain word for where an apprentice is in the day.
static func status_word(a: Dictionary) -> String:
	if not str(a.get("notice", {}).get("kind", "")).is_empty():
		var k := str(a["notice"]["kind"])
		if k == "independence":
			return "asking to set up on their own"
		if k == "leave":
			return "has given notice (unpaid)"
	match str(a.get("status", "")):
		"working":
			return "on shift" if int(a.get("task", -1)) != -1 else "on shift, idle"
		"break":
			return "on the midday break"
		"off":
			return "off duty (shift 8:00–18:00)"
	return str(a.get("status", ""))


static func priority_name(p: int) -> String:
	return str(PRIORITY_NAMES.get(clampi(p, 1, 3), "normal"))


static func minutes_text(m: int) -> String:
	if m <= 0:
		return "—"
	if m < 60:
		return "%d min" % m
	var shift_min := 9 * 60
	if m >= shift_min:
		return "~%.1f shifts" % (float(m) / float(shift_min))
	return "%dh %02dm" % [int(m / 60), m % 60]


static func defs_text(m: Dictionary) -> String:
	var parts := PackedStringArray()
	var ks := m.keys()
	ks.sort()
	for d in ks:
		parts.append("%d %s" % [int(m[d]), str(DB.item(str(d)).get("name", d))])
	return ", ".join(parts)


# ======================================================================= card pieces
static func traits_bbcode(traits: Array, with_desc := false) -> String:
	var tr: Dictionary = Apprentices.cfg("traits")
	var out := PackedStringArray()
	for tid in traits:
		var d: Dictionary = tr.get(str(tid), {})
		var good := bool(d.get("good", true))
		var s := "[color=%s]%s %s[/color]" % ["#26622f" if good else "#9e3a0c", "▲" if good else "▼", str(d.get("name", tid))]
		if with_desc and str(d.get("desc", "")) != "":
			s += " — [i]%s[/i]" % str(d["desc"])
		out.append(s)
	return ("\n" if with_desc else "  ").join(out)


static func skill_short(sk: String) -> String:
	return str({"smithing": "Smithing", "runecraft": "Runes", "alchemy": "Alchemy", "enchanted_stitching": "Stitching", "arcane_metalwork": "Arcane"}.get(sk, SkillSys.skill_name(sk)))


## Skill dots for an applicant's levels {skill: lvl}: "Smithing ●●○○○".
static func levels_text(levels: Dictionary) -> String:
	var parts := PackedStringArray()
	for sk: String in Apprentices._skill_ids():
		var lv := int(levels.get(sk, 0))
		if lv <= 0 and sk != "smithing":
			continue
		parts.append("%s %s" % [skill_short(sk), "●".repeat(mini(lv, 5)) + "○".repeat(maxi(0, 5 - lv))])
	return "   ".join(parts)


## A small grid of an apprentice's skills: name, level, xp bar (only the skills they have, smithing always).
static func skills_grid(a: Dictionary, bar_w := 90.0, size := 17) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 2)
	var sk_set: Dictionary = a.get("skills", {})
	for sk: String in Apprentices._skill_ids():
		var lv := SkillSys.level(sk_set, sk)
		if lv <= 0 and sk != "smithing" and SkillSys.progress(sk_set, sk) <= 0.0:
			continue
		g.add_child(UIKit.label(skill_short(sk), size))
		g.add_child(UIKit.label("Lv %d" % lv, size, "body_bold"))
		var b := UIKit.bar(SkillSys.progress(sk_set, sk), 1.0, bar_w)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(b)
	return g


## A framed portrait (the applicant look).
static func portrait(look: String, size := 110.0) -> Control:
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#20140c")
	fsb.set_content_margin_all(3)
	fsb.border_color = UIKit.GILT
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.add_child(UIKit.portrait("portraits/" + look, size))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return frame


## A soft parchment card container.
static func card(min_w := 0.0, tint := Color(0.94, 0.89, 0.78, 0.92)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.border_color = Color(UIKit.INK, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	if min_w > 0.0:
		p.custom_minimum_size = Vector2(min_w, 0)
	return p


static func works_text(n: int) -> String:
	return "no works yet" if n <= 0 else ("1 work" if n == 1 else "%d works" % n)


static func loyalty_word(v: float) -> String:
	if v >= 80.0:
		return "devoted"
	if v >= 60.0:
		return "content"
	if v >= 40.0:
		return "uneasy"
	if v >= 20.0:
		return "unhappy"
	return "on the point of leaving"
