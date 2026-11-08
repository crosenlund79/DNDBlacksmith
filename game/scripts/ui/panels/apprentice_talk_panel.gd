## ApprenticeTalkPanel — a word with one of the workshop apprentices in the smithy (iteration 012).
## EN: Left: their card (portrait, rank, traits, skills, loyalty, wage, mark). Right: what they say and your choices —
##     how the work is going, teach them for an hour (Apprentices.mentor), their recent work and memories, the
##     workshop ledger, and letting them go (with a confirmation). When they have asked to open a workshop of their
##     own, the answer is given here: with your blessing (a farewell) or asking them to stay (a raise).
## DA: En snak med en lærling: hvordan arbejdet går, undervisning, seneste arbejde, afsked og svar på ønsket om
##     at gå selvstændigt.
class_name ApprenticeTalkPanel
extends UIWindow

var app_id := ""
var text: RichTextLabel
var opts: VBoxContainer
var card_host: VBoxContainer


func _init(id: String) -> void:
	app_id = id
	super._init(Talk.npc_name(id), 1440, 700)


func _ready() -> void:
	super._ready()
	var a := Apprentices.get_a(app_id)
	title_label.text += "  ·  %s of the Ironhand forge" % Apprentices.rank_name(a)
	var h := UIKit.hbox(22)
	card_host = UIKit.vbox(0)
	h.add_child(card_host)
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = UIKit.rich("", 22)
	v.add_child(text)
	opts = UIKit.vbox(6)
	v.add_child(opts)
	h.add_child(v)
	content.add_child(h)
	_refresh_card()
	text.text = _greeting(a)
	_options()


func _a() -> Dictionary:
	return Apprentices.get_a(app_id)


func _refresh_card() -> void:
	UIKit.clear(card_host)
	var a := _a()
	if not a.is_empty():
		card_host.add_child(info_card(a))


## Their card: portrait, rank and specialty, personality, traits, skills, loyalty, wage, works and their mark.
static func info_card(a: Dictionary) -> Control:
	var c := ApprenticeUI.card(440)
	c.name = "ApprenticeCard"
	var v := UIKit.vbox(6)
	c.add_child(v)
	var top := UIKit.hbox(12)
	top.add_child(ApprenticeUI.portrait(str(a.get("look", "")), 130))
	var nv := UIKit.vbox(2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(str(a.get("name", "")), 27, "heading")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(nm)
	var sp := str(a.get("specialty", ""))
	nv.add_child(UIKit.label("%s%s" % [Apprentices.rank_name(a), (" · " + Apprentices.category_name(sp)) if sp != "" else ""], 19, "body_italic", UIKit.RUBRIC))
	nv.add_child(UIKit.label("%s · %s" % [str(a.get("race", "")), str(a.get("personality", ""))], 16, "body_italic"))
	nv.add_child(UIKit.label("Wage %d g/day · %d works" % [int(a.get("wage", 0)), int(a.get("works", 0))], 17))
	top.add_child(nv)
	v.add_child(top)
	var tr := UIKit.rich(ApprenticeUI.traits_bbcode(a.get("traits", []), true), 16)
	tr.custom_minimum_size = Vector2(400, 0)
	v.add_child(tr)
	v.add_child(UIKit.divider())
	v.add_child(ApprenticeUI.skills_grid(a, 120.0, 17))
	var nr := Apprentices.next_rank(a)
	if not nr.is_empty():
		v.add_child(UIKit.label("Next: " + str(nr.get("text", "")), 16, "body_italic", ApprenticeUI.MUTED))
	var lo := UIKit.hbox(8)
	lo.add_child(UIKit.label("Loyalty", 18, "body_bold"))
	var b := UIKit.bar(float(a.get("loyalty", 50.0)), 100.0, 150)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lo.add_child(b)
	lo.add_child(UIKit.label(ApprenticeUI.loyalty_word(float(a.get("loyalty", 50.0))), 17, "body_italic"))
	v.add_child(lo)
	var mk: Dictionary = a.get("mark", {})
	var mh := UIKit.hbox(8)
	mh.add_child(UIKit.icon("marks/apprentice" if Assets.has_tex("marks/apprentice") else "marks/hand", 40))
	var ml := UIKit.label(str(mk.get("name", "")), 16, "body_italic")
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(340, 0)
	mh.add_child(ml)
	v.add_child(mh)
	return c


func _greeting(a: Dictionary) -> String:
	if a.is_empty():
		return "[i]They are no longer here.[/i]"
	var first := str(a["name"]).split(" ")[0]
	var nt: Dictionary = a.get("notice", {})
	if str(nt.get("kind", "")) == "independence":
		return "[b]%s[/b] wipes their hands and doesn't quite meet your eye. \"Master Brannoc… I've been thinking. I'd like to open a workshop of my own — here in Brindlewick, if you'll give me your blessing. I could go in %d days.\"" % [first, maxi(0, int(nt.get("due", 0)) - Game.day())]
	if str(nt.get("kind", "")) == "leave":
		return "[b]%s[/b] has their tools rolled up in oilcloth. \"I've not been paid, master. If it isn't put right by day %d, I'm gone.\"" % [first, int(nt.get("due", 0))]
	match str(a.get("status", "")):
		"break":
			return "[b]%s[/b] looks up from a heel of bread. \"Back at it at one, master.\"" % first
		"off":
			return "[b]%s[/b] is pulling on their coat. \"Shift's over — I'll be here at eight.\"" % first
	var act := str(a.get("activity", ""))
	return "[b]%s[/b] straightens up. \"Master?\"%s" % [first, ("  [i](%s)[/i]" % act.to_lower()) if act != "" else ""]


func _options() -> void:
	UIKit.clear(opts)
	var a := _a()
	if a.is_empty():
		opts.add_child(UIKit.button("❧ Farewell", close, 0))
		return
	if str(a.get("notice", {}).get("kind", "")) == "independence":
		_opt("Go with my blessing — open your own workshop.", func(): _answer("bless"))
		_opt("Stay a while longer — I'll raise your wage.", func(): _answer("stay"))
	_opt("How is the work going?", _how)
	var why_not := _mentor_reason(a)
	var mb := _opt("Let me show you something. (teach them for an hour)", _teach)
	if why_not != "":
		mb.disabled = true
		mb.tooltip_text = why_not
		mb.text += "  — " + why_not
	_opt("What have you made lately?", _recent)
	_opt("Open the workshop ledger. [%s]" % Settings.key_label("panel_workshop"), func(): close(); Events.open_panel.emit.call_deferred("workshop", {}))
	_opt("I have to let you go…", _dismiss_ask)
	_opt("Back to work.", close)


func _opt(label: String, cb: Callable) -> Button:
	var b := UIKit.button("❧ " + label, cb, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	opts.add_child(b)
	return b


func _mentor_reason(a: Dictionary) -> String:
	if str(a.get("status", "")) == "off":
		return "gone home for the day"
	if int(a.get("mentored_day", -1)) == Game.day():
		return "already taught today"
	return ""


func _how() -> void:
	var a := _a()
	var lines := PackedStringArray()
	var t := Apprentices.task(int(a.get("task", -1)))
	if t.is_empty():
		lines.append("\"Nothing on my bench right now, master. Give me something in the ledger and I'll get to it.\"")
	else:
		var e := Apprentices.estimate(t, a)
		lines.append("\"I'm on [b]%s[/b]%s.\"" % [str(t.get("label", "")), (" — %d of %d done" % [int(t["done"]), int(t["repeat"])]) if int(t.get("repeat", 1)) > 1 else ""])
		if str(t.get("blocker", "")) != "":
			lines.append("[color=#9e3a0c]%s[/color]" % str(t["blocker"]))
		lines.append("[i]About %s left; I'd expect around %d%% craftsmanship.[/i]" % [ApprenticeUI.minutes_text(int(e.get("minutes", 0))), int(round(float(e.get("quality", 0.0))))])
	var nr := Apprentices.next_rank(a)
	if not nr.is_empty():
		lines.append("\"To be named %s I need %d works and %s %d — I'm at %d and %d.\"" % [str(nr["name"]).to_lower(), int(nr["works"]), str(nr["skill_name"]), int(nr["skill"]), int(nr["have_works"]), int(nr["have_skill"])])
	var lg: Array = (Apprentices.st()["log"] as Array).filter(func(l): return str(l.get("app", "")) == app_id)
	if not lg.is_empty():
		lines.append("[color=#6e5a40][i]Day %d, %s — %s[/i][/color]" % [int(lg[-1]["day"]), str(lg[-1]["time"]), str(lg[-1]["text"])])
	text.text = "\n".join(lines)
	_options()


func _teach() -> void:
	var a := _a()
	var before := SkillSys.level(a.get("skills", {}), Apprentices.best_skill(a))
	var err := Apprentices.mentor(app_id)
	if err != "":
		text.text = "[color=#9e3a0c]%s[/color]" % err
		_options()
		return
	a = _a()
	var lg: Array = (Apprentices.st()["log"] as Array).filter(func(l): return str(l.get("app", "")) == app_id)
	var line := str(lg[-1]["text"]) if not lg.is_empty() else "You spend an hour at their side."
	var gain := SkillSys.level(a.get("skills", {}), Apprentices.best_skill(a)) > before
	text.text = "%s\n[i]An hour passes. %s[/i]" % [line, "Something falls into place — they have grown in skill." if gain else "They will remember it at the anvil tomorrow."]
	Events.toast.emit("You taught %s for an hour." % str(a.get("name", "")), "good")
	_refresh_card()
	_options()


func _recent() -> void:
	var a := _a()
	var lines := PackedStringArray()
	var cr: Array = a.get("creations", [])
	if not cr.is_empty():
		lines.append("[b]Pieces they are proud of[/b]")
		for c in cr.slice(maxi(0, cr.size() - 4)):
			if c is Dictionary:
				lines.append("• %s [color=#6e5a40](day %d, %d%%)[/color]" % [str(c.get("name", "")), int(c.get("day", 0)), int(round(float(c.get("quality", 0.0))))])
			else:
				var it := ItemStory.find(int(c))
				if not it.is_empty():
					lines.append("• %s" % Items.display_name(it))
	var mem: Array = a.get("memories", [])
	if not mem.is_empty():
		lines.append("[b]What they remember[/b]")
		for i in range(mem.size() - 1, maxi(-1, mem.size() - 6), -1):
			lines.append("• [i]%s[/i] [color=#6e5a40](day %d)[/color]" % [str(mem[i].get("text", "")), int(mem[i].get("day", 0))])
	if lines.is_empty():
		lines.append("\"Nothing worth telling yet, master. Give me time.\"")
	text.text = "\n".join(lines)
	_options()


func _dismiss_ask() -> void:
	var a := _a()
	text.text = "Let [b]%s[/b] go from the workshop? Their unfinished work goes back to the queue and its materials to the stores. They will not come back." % str(a.get("name", ""))
	UIKit.clear(opts)
	_opt("Yes — let them go.", func():
		var err := Apprentices.dismiss(app_id)
		if err != "":
			text.text = "[color=#9e3a0c]%s[/color]" % err
			_options()
			return
		text.text = "[i]%s unties the apron, folds it on the bench and goes without a word.[/i]" % str(a.get("name", ""))
		UIKit.clear(opts)
		_opt("Farewell.", close))
	_opt("No — I spoke too soon.", func(): text.text = _greeting(_a()); _options())


func _answer(choice: String) -> void:
	var a := _a()
	var name := str(a.get("name", ""))
	var first := name.split(" ")[0]
	var mark := str(a.get("mark", {}).get("desc", ""))
	var works := int(a.get("works", 0))
	var err := Apprentices.answer_notice(app_id, choice)
	if err != "":
		text.text = "[color=#9e3a0c]%s[/color]" % err
		_options()
		return
	if choice == "bless":
		text.text = ("You take %s's hand in both of yours. \"You came to me a novice who didn't know a drift from a fuller. %d pieces later you're a master. Go — and strike your own mark true.\"\n\n" +
			"[i]%s looks round the smithing hall one last time, at the anvil and the quench and the soot on the beams, and goes out into Brindlewick with your blessing. From now on their work carries %s — and nobody else's.[/i]") % [first, works, first, mark if mark != "" else "their own mark"]
		UIKit.clear(card_host)
		UIKit.clear(opts)
		_opt("Farewell, %s." % first, close)
		return
	_refresh_card()
	text.text = "\"Not yet, then.\" %s grins and ties the apron back on. \"Not for a long while.\"\n[i]Their wage rises; they will not ask again for months.[/i]" % first
	_options()
