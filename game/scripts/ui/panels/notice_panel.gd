## NoticePanel — the village notice board: job applicants, open commissions and village news.
## DA: Landsbyens opslagstavle: ansøgere, åbne bestillinger og nyt fra landsbyen.
class_name NoticePanel
extends UIWindow

var body: VBoxContainer


func _init() -> void:
	super._init("Village Notice Board", 1400, 800)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(10)
	content.add_child(UIKit.scroll(body, 660))
	Events.hirelings_changed.connect(_build)
	_build()


func _build() -> void:
	UIKit.clear(body)
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
