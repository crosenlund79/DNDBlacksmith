## HirelingsPanel — the Ledger of Hands: who works for you, what they are doing right now, their
## skills and traits, how their working time is split (must total 100%), their gear (the humanoid EquipmentSheet,
## compact, with a compare against a piece from your stores), and where they can be sent — with the odds shown first.
## DA: Personaleledelse: aktuel aktivitet, færdigheder og træk, arbejdsfordeling (100%), udstyr,
##     ekspeditioner med odds, samt seneste arbejde og ekspeditionshistorik.
class_name HirelingsPanel
extends UIWindow

const OUTCOME := {"success": "returned with a full haul", "failed": "came back with little", "success_injured": "returned hurt, haul intact",
	"failed_injured": "came back hurt and empty-handed", "died": "did not come back"}

var body: VBoxContainer
var sliders := {}
static var skills_open := {}   # hireling id -> the optional skills & work-split box is open (v1.7 #73)
static var compare := {}   # hireling id -> uid of the store piece being compared with what they wear


func _init() -> void:
	super._init("Hirelings — Ledger of Hands", 1500, 880)


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(12)
	content.add_child(UIKit.scroll(body, 720))
	Events.hirelings_changed.connect(_build)
	_build()


func _build() -> void:
	UIKit.clear(body)
	sliders.clear()
	var top := UIKit.hbox(12)
	var tl := UIKit.label("You employ %d of %d hands. Applicants appear on the village notice board each week — who turns up is down to chance." % [Hire.alive_count(), Hire.MAX_HIRELINGS], 20, "body_italic")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	# iteration 012: apprentices work inside the smithy and are managed in their own ledger
	var wb := InkIcons.button("tb_property", "Workshop apprentices [%s]" % Settings.key_label("panel_workshop"), func(): close(); Events.open_panel.emit.call_deferred("workshop", {}), 0)
	wb.tooltip_text = "Apprentices are a separate staff: they work at your stations on the work queue. %d of %d places taken." % [Apprentices.staff().size(), Apprentices.max_staff()] if Apprentices.unlocked() else Apprentices.unlock_reason()
	top.add_child(wb)
	body.add_child(top)
	# The Living Realm: commission adventurers (Sponsor) beside sending hirelings
	body.add_child(SponsorSection.new())
	body.add_child(UIKit.divider())
	for h in Hire.list():
		body.add_child(_card(h))
		body.add_child(UIKit.divider())


func _card(h: Dictionary) -> Control:
	var hid: String = h["id"]
	var st: String = h["status"]
	var row := UIKit.hbox(18)
	row.name = "HirelingCard"
	# ---- left (compact): who they are and what they wear
	var left := UIKit.vbox(4)
	left.name = "WhoAndGear"
	left.custom_minimum_size = Vector2(430, 0)
	var who := UIKit.hbox(10)
	who.add_child(UIKit.portrait("portraits/" + str(h["look"]), 92))
	var tl := []
	for tid in Hire.traits_of(h):
		var tr: Dictionary = Hire.TRAITS.get(tid, {})
		tl.append("[color=%s]%s %s[/color]" % ["#26622f" if tr.get("good", false) else "#9e3a0c", "▲" if tr.get("good", false) else "▼", tr.get("name", tid)])
	var idt := UIKit.rich("[font_size=24][b]%s[/b][/font_size]\n%s · %d g/day · [i]%s[/i]\n%s%s" % [h["name"], h["race"], h["wage"], h["personality"],
		Hire.potential_word(h), ("\n" + "  ".join(tl)) if not tl.is_empty() else ""], 17)
	idt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(idt)
	left.add_child(who)
	var gtop := UIKit.hbox(10)
	gtop.add_child(UIKit.label("Gear", 22, "heading"))
	var gs := UIKit.label("power %d" % int(Hire.gear_score(h)), 17, "body_italic")
	gs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gtop.add_child(gs)
	left.add_child(gtop)
	var sheet := EquipmentSheet.new(h.get("equipment", {}), {"compact": true})
	sheet.name = "GearSheet"
	left.add_child(sheet)
	if st != "away" and st != "dead":
		var spare := Game.inventory().filter(func(x): return Items.is_equipment(x) and Items.slot(x) != "")
		if not spare.is_empty():
			var gh := UIKit.hbox(6)
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(250, 36)
			for x in spare:
				ob.add_item("%s (%s)" % [Items.display_name(x), Items.SLOT_LABEL.get(Items.slot(x), Items.slot(x)).to_lower()], int(x["uid"]))
				if int(x["uid"]) == int(compare.get(hid, -1)):
					ob.select(ob.item_count - 1)
			gh.add_child(ob)
			gh.add_child(UIKit.button("Compare", func():
				compare[hid] = -1 if int(compare.get(hid, -1)) == ob.get_item_id(ob.selected) else ob.get_item_id(ob.selected)
				_build(), 0))
			gh.add_child(UIKit.button("Give", func():
				compare.erase(hid)
				if Hire.equip(hid, ob.get_item_id(ob.selected)):
					Events.toast.emit("%s takes the %s." % [h["name"], ob.get_item_text(ob.selected)], "good"), 70))
			left.add_child(gh)
			var cit := Game.find_uid(int(compare.get(hid, -1)))
			if not cit.is_empty() and spare.has(cit):
				var cur: Dictionary = h.get("equipment", {}).get(Items.slot(cit), {})
				var before := Hire.gear_score(h)
				var after := before - Items.score(cur) + Items.score(cit)
				left.add_child(EquipmentSheet.compare_view(cur, cit, "Power %d → %d if %s takes it." % [int(before), int(after), h["name"]], after >= before))
	row.add_child(left)
	# ---- right (prominent): what they are doing, their assignment, where they can be sent
	var right := UIKit.vbox(6)
	right.name = "Assignments"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label(Hire.activity_text(h), 24, "body_bold", UIKit.RUBRIC))
	var asg := UIKit.hbox(8)
	asg.add_child(UIKit.label("Assignment:", 20, "heading"))
	var top := Hire.top_alloc(h)
	asg.add_child(UIKit.label("%s %d%%" % [SkillSys.skill_name(top), int(h["alloc"].get(top, 0))], 20, "body_bold"))
	for p in Hire.PRESETS:
		var pk: String = p
		var pb := UIKit.button(Hire.PRESETS[p], func(): Hire.apply_preset(hid, pk), 0)
		pb.disabled = not (st == "working" or st == "injured")
		asg.add_child(pb)
	var open := bool(skills_open.get(hid, false))
	var sk := UIKit.button(("Skills & work split ▾" if open else "Skills & work split ▸"), func():
		skills_open[hid] = not bool(skills_open.get(hid, false))
		_build(), 0)
	sk.name = "SkillsToggle"
	sk.tooltip_text = "Optional: each skill's level and an exact split of the working day (8:00–18:00)."
	asg.add_child(sk)
	right.add_child(asg)
	if open:
		right.add_child(_skills_box(h))
	var logs: Array = h.get("log", [])
	if not logs.is_empty():
		right.add_child(UIKit.rich("[color=#5e421c][i]%s[/i][/color]" % "\n".join(logs.slice(maxi(0, logs.size() - 2))), 16))
	right.add_child(UIKit.label("Expeditions", 24, "heading"))
	if st == "working":
		for d in DB.destinations.values():
			var locked: bool = d.has("requires_flag") and not Game.has_flag(d["requires_flag"])
			var o := Hire.odds(h, d["id"])
			var line := UIKit.hbox(8)
			var info := UIKit.rich("[b]%s[/b] · %s, %d–%d days · [i]%s[/i] · [color=%s]%s[/color] · success ~%d%% · injury ~%d%%%s" % [d["name"], d["kind"], int(d["days"][0]), int(d["days"][1]), Regions.knowledge_word(Regions.scouted(d["id"])),
				{"safe": "#26622f", "risky": "#735800", "dangerous": "#9e3a0c", "deadly": "#7e2418"}.get(Hire.risk_word(o), "#20140c"), Hire.risk_word(o).capitalize(),
				int(float(o["success"]) * 100.0), int(float(o["injury"]) * 100.0), " · could die" if float(o["death"]) > 0.0 else ""], 16)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(info)
			var did: String = d["id"]
			var purse: OptionButton = null
			if d.get("kind", "") == "trade":
				purse = OptionButton.new()
				for amt in [0, 50, 100, 200]:
					purse.add_item("no purse" if amt == 0 else "%d g purse" % amt, amt)
				purse.tooltip_text = "Gold to spend with the suppliers you know; trade goods you have marked are sold on the way."
				line.add_child(purse)
			var b := UIKit.button("Send", func():
				var opts := {}
				if purse != null:
					opts["budget"] = purse.get_item_id(purse.selected)
				var err := Hire.send(hid, did, opts)
				if err != "":
					Events.toast.emit(err, "bad")
				else:
					Audio.play("sfx/door")
					close(), 80)
			b.disabled = locked
			b.tooltip_text = d["desc"] if not locked else "Nobody knows the way yet."
			line.add_child(b)
			right.add_child(line)
	else:
		right.add_child(UIKit.label("Unavailable — %s." % Hire.activity_text(h).to_lower(), 19, "body_italic"))
	var hist: Array = h.get("history", [])
	if not hist.is_empty():
		var hl := []
		for e in hist.slice(maxi(0, hist.size() - 3)):
			hl.append("Day %d, %s: %s%s" % [int(e["day"]), DB.destinations.get(e["dest"], {}).get("name", e["dest"]), OUTCOME.get(e["outcome"], e["outcome"]),
				(" — " + ", ".join(e["haul"])) if not e["haul"].is_empty() else ""])
		right.add_child(UIKit.rich("[color=#5e421c][i]%s[/i][/color]" % "\n".join(hl), 17))
	if st != "away":
		right.add_child(UIKit.button("Remove from the roll" if st == "dead" else "Dismiss", func(): Hire.dismiss(hid), 220))
	row.add_child(right)
	return row


## The optional skills box: each work skill's level and progress, and the exact split of the working day (sliders that
## must total 100 %, Apply). Secondary (v1.7 #73): new hands start on their best skill, so nothing here is required.
func _skills_box(h: Dictionary) -> Control:
	var hid: String = h["id"]
	var st: String = h["status"]
	var mid := UIKit.vbox(4)
	mid.name = "SkillsBox"
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	for s in DB.work_skills:
		var nm := SkillSys.skill_name(s)
		var m := Hire.trait_mult(h, "mult", s)
		if m > 1.01:
			nm += " ▲"
		elif m < 0.99:
			nm += " ▼"
		grid.add_child(UIKit.label(nm, 18))
		grid.add_child(UIKit.label("Lv %d" % SkillSys.level(h["skills"], s), 18, "body_bold"))
		grid.add_child(UIKit.bar(SkillSys.progress(h["skills"], s), 1.0, 100))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.value = int(h["alloc"].get(s, 0))
		sl.custom_minimum_size = Vector2(150, 22)
		sl.editable = st == "working" or st == "injured"
		sliders[hid + ":" + s] = sl
		grid.add_child(sl)
		var pl := UIKit.label("%d%%" % int(sl.value), 18)
		pl.custom_minimum_size = Vector2(50, 0)
		sl.value_changed.connect(func(v): pl.text = "%d%%" % int(v))
		grid.add_child(pl)
	mid.add_child(grid)
	var total_lab := UIKit.label("", 19, "body_bold")
	var upd := func(_v = 0):
		var tt := 0
		for s in DB.work_skills:
			tt += int((sliders[hid + ":" + s] as HSlider).value)
		total_lab.text = "Total: %d%%" % tt
		total_lab.add_theme_color_override("font_color", Color("#26622f") if tt == 100 else Color("#9e3a0c"))
	for s in DB.work_skills:
		(sliders[hid + ":" + s] as HSlider).value_changed.connect(upd)
	upd.call()
	var ab := UIKit.hbox(8)
	ab.add_child(total_lab)
	ab.add_child(UIKit.button("Apply split", func():
		var alloc := {}
		for s in DB.work_skills:
			alloc[s] = int((sliders[hid + ":" + s] as HSlider).value)
		if Hire.set_alloc(hid, alloc):
			Events.toast.emit("Work schedule updated for " + h["name"], "good")
		else:
			Events.toast.emit("Allocation must total exactly 100%.", "bad"), 0))
	mid.add_child(ab)
	return mid

