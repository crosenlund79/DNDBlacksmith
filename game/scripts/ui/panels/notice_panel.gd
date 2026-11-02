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
	body.add_child(UIKit.label("Seeking work (new faces each week; you cannot choose who turns up)", 26, "heading"))
	var apps: Array = Game.state["applicants"]
	if apps.is_empty():
		body.add_child(UIKit.label("No new notices pinned this week.", 20, "body_italic"))
	for i in apps.size():
		var a: Dictionary = apps[i]
		var row := UIKit.hbox(16)
		row.add_child(UIKit.portrait("portraits/" + str(a["look"]), 120))
		var skills := []
		for s in DB.work_skills:
			var lv := int(a["levels"].get(s, 0))
			skills.append("%s %s" % [SkillSys.skill_name(s), "●".repeat(lv) + "○".repeat(maxi(0, 5 - lv))])
		var lab := UIKit.rich("[b]%s[/b] · %s\n[i]%s[/i]\n%s\nWage %d g/day · signing fee %d g" % [a["name"], a["race"], a["personality"], "   ".join(skills), a["wage"], a["fee"]], 20)
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
		body.add_child(row)
	body.add_child(UIKit.divider())
	body.add_child(UIKit.label("Commissions pinned by adventurers", 26, "heading"))
	var any := false
	for o in Shop.open_orders():
		any = true
		body.add_child(UIKit.rich("• [b]%s[/b] wants a [b]%s[/b] with %s ≥ %d — %d g, due day %d. [i]%s[/i]" % [Talk.npc_name(o["npc"]), o["slot"], o["stat"], o["min"], o["reward"], o["deadline"], o.get("note", "")], 20))
	if not any:
		body.add_child(UIKit.label("None at the moment.", 20, "body_italic"))
	body.add_child(UIKit.divider())
	body.add_child(UIKit.label("Village news", 26, "heading"))
	var js: Array = Game.state["journal"]
	var txt := ""
	for i in range(js.size() - 1, maxi(-1, js.size() - 8), -1):
		txt += "• %s\n" % js[i]["text"]
	body.add_child(UIKit.rich(txt, 20))
