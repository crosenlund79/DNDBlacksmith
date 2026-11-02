## HirelingsPanel — employee management: portrait, skills, work allocation (must total 100%),
## status and expeditions.
## DA: Personaleledelse: portræt, færdigheder, arbejdsfordeling (skal give 100%), status og ekspeditioner.
class_name HirelingsPanel
extends UIWindow

var body: VBoxContainer
var sliders := {}


func _init() -> void:
	super._init("Hirelings — Ledger of Hands", 1460, 840)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(12)
	content.add_child(UIKit.scroll(body, 680))
	Events.hirelings_changed.connect(_build)
	_build()


func _build() -> void:
	UIKit.clear(body)
	sliders.clear()
	body.add_child(UIKit.label("You employ %d of %d hands. New applicants appear on the village notice board each week." % [Hire.alive_count(), Hire.MAX_HIRELINGS], 20, "body_italic"))
	for h in Hire.list():
		body.add_child(_card(h))
		body.add_child(UIKit.divider())


func _card(h: Dictionary) -> Control:
	var row := UIKit.hbox(18)
	var left := UIKit.vbox(4)
	left.add_child(UIKit.portrait("portraits/" + str(h["look"]), 150))
	var st: String = h["status"]
	var status: String = {"working": "At work in the forge", "away": "On expedition", "injured": "Injured — resting (%d days)" % int(h.get("injured_days", 0)), "dead": "Deceased"}.get(st, st)
	if st == "away":
		var e: Dictionary = h["expedition"]
		status = "At %s — back in %d day%s" % [DB.destinations[e["dest"]]["name"], int(e["days_left"]), "" if int(e["days_left"]) == 1 else "s"]
	left.add_child(UIKit.label(status, 18, "body_italic", UIKit.RUBRIC))
	row.add_child(left)
	var mid := UIKit.vbox(4)
	mid.custom_minimum_size = Vector2(560, 0)
	mid.add_child(UIKit.rich("[font_size=30][b]%s[/b][/font_size]  ·  %s  ·  wage %d g/day\n[i]%s[/i]\nExpeditions: %d · Gear: %d" % [h["name"], h["race"], h["wage"], h["personality"], int(h.get("expeditions", 0)), int(Hire.gear_score(h))], 21))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	for s in DB.work_skills:
		grid.add_child(UIKit.label(SkillSys.skill_name(s), 20))
		grid.add_child(UIKit.label("Lv %d" % SkillSys.level(h["skills"], s), 20, "body_bold"))
		grid.add_child(UIKit.bar(SkillSys.progress(h["skills"], s), 1.0, 120))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.value = int(h["alloc"].get(s, 0))
		sl.custom_minimum_size = Vector2(150, 24)
		sl.editable = st == "working" or st == "injured"
		sliders[h["id"] + ":" + s] = sl
		grid.add_child(sl)
	mid.add_child(UIKit.label("Normal working time (8:00–18:00) — must total 100%:", 19, "heading"))
	mid.add_child(grid)
	var total_lab := UIKit.label("", 20, "body_bold")
	mid.add_child(total_lab)
	var hid: String = h["id"]
	var upd := func(_v = 0):
		var t := 0
		for s in DB.work_skills:
			t += int((sliders[hid + ":" + s] as HSlider).value)
		total_lab.text = "Total: %d%%" % t
		total_lab.add_theme_color_override("font_color", Color("#26622f") if t == 100 else Color("#9e3a0c"))
	for s in DB.work_skills:
		(sliders[hid + ":" + s] as HSlider).value_changed.connect(upd)
	upd.call()
	var ab := UIKit.hbox(8)
	ab.add_child(UIKit.button("Apply allocation", func():
		var alloc := {}
		for s in DB.work_skills:
			alloc[s] = int((sliders[hid + ":" + s] as HSlider).value)
		if Hire.set_alloc(hid, alloc):
			Events.toast.emit("Work schedule updated for " + h["name"], "good")
		else:
			Events.toast.emit("Allocation must total exactly 100%.", "bad"), 220))
	ab.add_child(UIKit.button("Balance to 100%", func():
		var tot := 0.0
		for s in DB.work_skills:
			tot += (sliders[hid + ":" + s] as HSlider).value
		if tot <= 0:
			(sliders[hid + ":mining"] as HSlider).value = 100
			return
		var acc := 0
		var last := ""
		for s in DB.work_skills:
			var v := int(round((sliders[hid + ":" + s] as HSlider).value / tot * 20.0)) * 5
			(sliders[hid + ":" + s] as HSlider).value = v
			acc += v
			if v > 0:
				last = s
		if last != "":
			(sliders[hid + ":" + last] as HSlider).value += 100 - acc, 220))
	mid.add_child(ab)
	row.add_child(mid)
	var right := UIKit.vbox(6)
	right.custom_minimum_size = Vector2(420, 0)
	right.add_child(UIKit.label("Expeditions", 24, "heading"))
	if st == "working":
		for d in DB.destinations.values():
			var locked := d.has("requires_flag") and not Game.has_flag(d["requires_flag"])
			var b := UIKit.button("%s — %s, danger %d, %d–%d days" % [d["name"], d["kind"], int(d["danger"]), int(d["days"][0]), int(d["days"][1])], func():
				var err := Hire.send(hid, d["id"])
				if err != "":
					Events.toast.emit(err, "bad")
				else:
					Audio.play("sfx/door")
					close(), 0)
			b.disabled = locked
			b.tooltip_text = d["desc"] if not locked else "Nobody knows the way yet."
			right.add_child(b)
	else:
		right.add_child(UIKit.label("Unavailable while %s." % status.to_lower(), 20, "body_italic"))
	if st != "away":
		right.add_child(UIKit.button("Dismiss", func(): Hire.dismiss(hid), 160))
	row.add_child(right)
	return row
