## NoticePanel — the village notice board: job applicants, open commissions and village news; and (iteration 012)
## a separate "Workshop apprentices" tab where would-be apprentices pin their names.
## DA: Landsbyens opslagstavle: ansøgere, åbne bestillinger og nyt fra landsbyen; og en fane med lærlingeansøgere.
class_name NoticePanel
extends UIWindow

var body: VBoxContainer
var tabs_row: HBoxContainer
var tab := "board"


func _init(t := "board") -> void:
	tab = t
	super._init("Village Notice Board", 1400, 800)


func _ready() -> void:
	super._ready()
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 610))
	Events.hirelings_changed.connect(_build)
	Events.apprentices_changed.connect(_build)
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	UIKit.clear(tabs_row)
	var napp := Apprentices.applicants().size() if Apprentices.unlocked() else 0
	for t in [["board", "Hands, commissions & news"], ["apprentices", "Workshop apprentices%s" % ((" (%d)" % napp) if napp > 0 else "")]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tab = key; _build(), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	UIKit.clear(body)
	if tab == "apprentices":
		_apprentices()
		return
	body.add_child(UIKit.label("Seeking work (new faces each week; you cannot choose who turns up) — you employ %d of %d" % [Hire.alive_count(), Hire.MAX_HIRELINGS], 26, "heading"))
	var apps: Array = Game.state["applicants"]
	if apps.is_empty():
		body.add_child(UIKit.label("No new notices pinned this week.", 20, "body_italic"))
	for i in apps.size():
		var a: Dictionary = apps[i]
		var row := UIKit.hbox(16)
		row.add_child(UIKit.portrait("portraits/" + str(a["look"]), 120))
		var skills := []
		var exact := bool(Expeditions.diff().get("detail", true))
		for si in DB.work_skills.size():
			var s: String = DB.work_skills[si]
			var lv := int(a["levels"].get(s, 0))
			if exact:
				skills.append("%s %s" % [SkillSys.skill_name(s), "●".repeat(lv) + "○".repeat(maxi(0, 5 - lv))])
			else:
				# Master: a notice is a boast — only a range until they work for you
				skills.append("%s %d–%d" % [SkillSys.skill_name(s), maxi(0, lv - (si + i) % 2), lv + 1])
		var tl := []
		for tid in a.get("traits", []):
			var tr: Dictionary = Hire.TRAITS.get(tid, {})
			tl.append("[color=%s]%s %s[/color]" % ["#26622f" if tr.get("good", false) else "#9e3a0c", "▲" if tr.get("good", false) else "▼", tr.get("name", tid)])
		var lab := UIKit.rich("[b]%s[/b] · %s · %s\n[i]%s[/i]\n%s\nWage %d g/day · signing fee %d g · [i]potential unknown until they work for you[/i]" % [a["name"], a["race"], "  ".join(tl), a["personality"], "   ".join(skills), a["wage"], a["fee"]], 20)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var idx: int = i
		var b := UIKit.button("Hire", func():
			var err := Hire.hire_applicant(idx)
			if err != "":
				Events.toast.emit(err, "bad")
			else:
				get_tree().call_group("world", "spawn_new_hirelings")
				Events.toast.emit("Welcome aboard, " + a["name"] + ".", "good"), 120)
		row.add_child(b)
		if Hire.alive_count() >= Hire.MAX_HIRELINGS:
			# all three places are taken: offer to replace someone who is at home
			b.disabled = true
			var ob := OptionButton.new()
			for h in Hire.list():
				if h["status"] != "away":
					ob.add_item(("in place of " if h["status"] != "dead" else "for the late ") + str(h["name"]))
					ob.set_item_metadata(ob.item_count - 1, h["id"])
			if ob.item_count > 0:
				var rv := UIKit.vbox(4)
				rv.add_child(ob)
				rv.add_child(UIKit.button("Replace", func():
					var err := Hire.replace(idx, str(ob.get_item_metadata(ob.selected)))
					if err != "":
						Events.toast.emit(err, "bad")
					else:
						get_tree().call_group("world", "spawn_new_hirelings")
						Events.toast.emit("Welcome aboard, " + a["name"] + ".", "good"), 160))
				row.add_child(rv)
		body.add_child(row)
	body.add_child(UIKit.divider())
	body.add_child(UIKit.label("Commissions pinned by adventurers", 26, "heading"))
	var any := false
	for o in Shop.open_orders():
		any = true
		body.add_child(UIKit.rich("• [b]%s[/b] wants a [b]%s[/b] — %d g, due day %d. [i]%s[/i]" % [Talk.npc_name(o["npc"]), Shop.order_text(o), o["reward"], o["deadline"], o.get("note", "")], 20))
	if not any:
		body.add_child(UIKit.label("None at the moment.", 20, "body_italic"))
	body.add_child(UIKit.divider())
	body.add_child(UIKit.label("Village news", 26, "heading"))
	var js: Array = Game.state["journal"]
	var txt := ""
	for i in range(js.size() - 1, maxi(-1, js.size() - 8), -1):
		txt += "• %s\n" % js[i]["text"]
	body.add_child(UIKit.rich(txt, 20))


# ======================================================================= iteration 012: workshop apprentices
## Would-be apprentices: portrait, name, personality, traits, the craft they lean to, their skills, wage and signing
## fee, and a Hire button (or the engine's reason why not).
func _apprentices() -> void:
	var staff := Apprentices.staff()
	body.add_child(UIKit.label("Seeking an apprenticeship at the Ironhand forge — you keep %d of %d places" % [staff.size(), Apprentices.max_staff()], 26, "heading"))
	body.add_child(UIKit.label("Apprentices work inside your smithy, 8:00–18:00, on the work you queue in the Workshop Ledger [%s]. They are not expedition hands." % Settings.key_label("panel_workshop"), 18, "body_italic"))
	var why := Apprentices.hire_reason()
	if not Apprentices.unlocked():
		body.add_child(UIKit.label(Apprentices.unlock_reason(), 21, "body_bold", ApprenticeUI.BAD))
		return
	var apps := Apprentices.applicants()
	if apps.is_empty():
		body.add_child(UIKit.label("No one has pinned a name this week. New applicants come every seven days.", 20, "body_italic"))
	for i in apps.size():
		var p: Dictionary = apps[i]
		var c := ApprenticeUI.card(0)
		c.name = "Applicant_%d" % i
		var row := UIKit.hbox(16)
		c.add_child(row)
		row.add_child(ApprenticeUI.portrait(str(p.get("look", "")), 120))
		var pref := ""
		for d in p.get("prefs", []):
			pref = str(Crafting.DISCIPLINE_NAME.get(str(d), str(d)))
		var prof := str(p.get("profession", ""))   # Living Workshop B1: every applicant comes with a profession
		var lab := UIKit.rich("[font_size=26][b]%s[/b][/font_size] · %s · [color=#7e2418][b]%s[/b][/color]\n[i]%s[/i] — leans to [b]%s[/b]\n%s\n%s\nWage [b]%d g/day[/b] · signing fee [b]%d g[/b]" % [str(p["name"]), str(p.get("race", "")),
			Workers.profession_name(prof) if prof != "" else "apprentice",
			str(p.get("personality", "")), pref.to_lower() if pref != "" else "any craft", ApprenticeUI.traits_bbcode(p.get("traits", []), true),
			ApprenticeUI.levels_text(p.get("levels", {})), int(p.get("wage", 0)), int(p.get("fee", 0))], 19)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var idx: int = i
		var nm := str(p["name"])
		var bv := UIKit.vbox(4)
		var b := UIKit.button("Take on", func():
			var err := Apprentices.hire(idx)
			if err != "":
				Events.toast.emit(err, "bad")
			else:
				Events.toast.emit("%s joins the Ironhand forge as your apprentice." % nm, "good"), 150)
		var afford := Game.can_afford(int(p.get("fee", 0)))
		b.disabled = why != "" or not afford
		bv.add_child(b)
		if why != "" or not afford:
			var wl := UIKit.label(why if why != "" else "You cannot afford the fee.", 15, "body_italic", ApprenticeUI.BAD)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wl.custom_minimum_size = Vector2(220, 0)
			bv.add_child(wl)
		row.add_child(bv)
		body.add_child(c)
	if not staff.is_empty():
		body.add_child(UIKit.divider())
		body.add_child(UIKit.button("Open the Workshop Ledger", func(): close(); Events.open_panel.emit.call_deferred("workshop", {}), 300))
