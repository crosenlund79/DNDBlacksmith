## StationPanel — the interface of a crafting station: purpose, recipes, current job step,
## runestone setting (engraving stand) and practice checks.
## DA: Et håndværksstations brugerflade: formål, opskrifter, aktuelt trin, isætning af runesten
##     og øvelsesprøver.
class_name StationPanel
extends UIWindow

var station_id := ""


func _init(id: String) -> void:
	station_id = id
	var st := DB.station(id)
	super._init(st.get("name", id), 980, 700)


func _ready() -> void:
	super._ready()
	_build()
	Events.crafting_changed.connect(_build)
	Events.inventory_changed.connect(_build)


func _build() -> void:
	UIKit.clear(content)
	var st := DB.station(station_id)
	var head := UIKit.hbox(18)
	head.add_child(UIKit.icon("stations/" + station_id, 128))
	var info := UIKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(Crafting.DISCIPLINE_NAME.get(st.get("discipline", ""), ""), 22, "heading_italic", UIKit.RUBRIC))
	info.add_child(UIKit.label(st.get("purpose", ""), 22))
	var c := Crafting.check_params(station_id)
	info.add_child(UIKit.label("Precision ring at average difficulty: zone %d°, needle %.2f rev/s (your %s %d widens and slows it)" % [int(c["zone"]), c["speed"],
		SkillSys.skill_name(Crafting.skill_for_station(station_id)), Game.player_level(Crafting.skill_for_station(station_id))], 18, "body_italic"))
	var why := Crafting.station_locked_reason(station_id)
	if why != "":
		info.add_child(UIKit.label("Locked — " + why, 22, "body_bold", UIKit.RUBRIC))
	head.add_child(info)
	var hist := UIKit.button("History", func(): Events.open_panel.emit("history", {"kind": "station", "id": station_id}), 120)
	hist.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(hist)
	content.add_child(head)
	content.add_child(UIKit.divider())
	var body := UIKit.vbox(10)
	var job := Crafting.job()
	if not job.is_empty():
		var r := DB.recipe(job["recipe"])
		var ops := Crafting.operations(job["recipe"])
		body.add_child(UIKit.rich("[b]Current work:[/b] %s  [i](%s, %s)[/i]" % [r["name"], Crafting.material(job["recipe"]).get("name", ""), Crafting.difficulty_word(job["recipe"])], 22))
		var done: Array = job.get("ops", [])
		var lines := []
		for i in ops.size():
			var o: Dictionary = ops[i]
			var nm := "%d. %s — %s (%d check%s)" % [i + 1, o["op"], DB.station(o["station"]).get("name", o["station"]), int(o.get("checks", 1)), "s" if int(o.get("checks", 1)) > 1 else ""]
			if i < int(job["step"]):
				var q := float(done[i]["q"]) if i < done.size() else 0.0
				lines.append("[color=#5e421c][s]%s[/s]  [b]%d%%[/b][/color]" % [nm, int(round(q))])
			elif i == int(job["step"]) and not job["awaiting_dice"]:
				lines.append("[b][color=#7e2418]▶ %s[/color][/b]" % nm)
			else:
				lines.append(nm)
		lines.append(("[b][color=#7e2418]▶ Roll the dice[/color][/b]" if job["awaiting_dice"] else "Then: roll the dice"))
		body.add_child(UIKit.rich("\n".join(lines), 20))
		if job["awaiting_dice"]:
			body.add_child(UIKit.button("Roll the dice and finish the piece", func(): Events.open_panel.emit("dice", {}), 420))
		elif Crafting.current_station() == station_id:
			var op := Crafting.op_params()
			body.add_child(UIKit.button("%s (%d check%s)" % [op["op"], op["count"], "s" if op["count"] > 1 else ""], _work, 520))
		else:
			body.add_child(UIKit.label("Next: %s at the %s." % [Crafting.current_op().get("op", ""), DB.station(Crafting.current_station())["name"]], 22, "body_italic"))
		body.add_child(UIKit.button("Abandon work (return materials)", func(): Crafting.cancel(), 340))
	else:
		body.add_child(UIKit.label("Recipes using this station", 26, "heading"))
		for rec in Crafting.recipes_for_station(station_id):
			body.add_child(_recipe_row(rec))
	if station_id == "rune_engraving_stand" and why == "":
		body.add_child(UIKit.divider())
		body.add_child(_socket_ui())
	if station_id == "infusion_rack" and why == "":
		body.add_child(UIKit.divider())
		body.add_child(_treat_ui())
	if why == "":
		body.add_child(UIKit.divider())
		body.add_child(UIKit.button("Practise a check (no materials, a little experience)", _practice, 460))
	content.add_child(UIKit.scroll(body, 470))


func _recipe_row(rec: Dictionary) -> Control:
	var row := UIKit.hbox(14)
	row.add_child(UIKit.icon("icons/" + str(DB.item(rec["output"]).get("icon", rec["output"])), 56))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ins := []
	for id in rec["inputs"]:
		var need := int(rec["inputs"][id])
		var have := Game.count(id)
		ins.append("[color=%s]%s %d/%d[/color]" % ["#26622f" if have >= need else "#9e3a0c", DB.item(id).get("name", id), have, need])
	var steps := []
	for o in Crafting.operations(rec["id"]):
		steps.append(str(o["op"]))
	var lock := Crafting.recipe_locked_reason(rec["id"])
	var req := []
	for sk in rec.get("requires", {}):
		req.append("%s %d" % [SkillSys.skill_name(sk), int(rec["requires"][sk])])
	var meta := "[color=#5e421c]%d operations · %s · difficulty %d (%s)%s[/color]" % [steps.size(), Crafting.material(rec["id"]).get("name", ""),
		Crafting.difficulty(rec["id"]), Crafting.difficulty_word(rec["id"]), (" · needs " + ", ".join(req)) if not req.is_empty() else ""]
	v.add_child(UIKit.rich("[b]%s[/b]  [i]%s[/i]\n%s\n%s\n[color=#5e421c][i]%s[/i][/color]%s" % [rec["name"], rec.get("desc", ""), ", ".join(ins), meta, " → ".join(steps),
		("\n[color=#9e3a0c]" + lock + "[/color]") if lock != "" else ""], 19))
	row.add_child(v)
	var b := UIKit.button("Begin", func(): _start(rec["id"]), 120)
	b.disabled = lock != "" or not Crafting.missing_inputs(rec["id"]).is_empty()
	row.add_child(b)
	return row


func _start(rid: String) -> void:
	if Crafting.start(rid):
		Events.toast.emit("Begun: %s. First: %s at the %s." % [DB.recipe(rid)["name"], Crafting.current_op().get("op", ""), DB.station(Crafting.current_station())["name"]], "info")
		if Crafting.current_station() == station_id:
			_work()


func _work() -> void:
	var c := Crafting.op_params()
	if c.is_empty():
		return
	var sid := station_id
	Events.open_panel.emit("skillcheck", {"station": sid, "count": c["count"], "speed": c["speed"], "zone": c["zone"],
		"title": c["op"], "subtitle": "%s · %s" % [DB.station(sid)["name"], DB.recipe(Crafting.job()["recipe"]).get("name", "")],
		"on_done": _on_work_done.bind(sid)})
	Audio.play("sfx/" + str(DB.station(sid).get("sfx", "hammer")).replace("hammer", "hammer_1"), -2.0)


func _on_work_done(qs: Array, sid: String) -> void:
	Crafting.record_step(sid, qs)
	if Crafting.job().get("awaiting_dice", false):
		Events.open_panel.emit("dice", {})
	else:
		var avg := 0.0
		for q in qs:
			avg += float(q)
		avg /= maxf(1.0, qs.size())
		Events.toast.emit("%s — %d%%. Next: %s at the %s." % [Crafting.grade(avg), int(round(avg)), Crafting.current_op().get("op", "?"),
			DB.station(Crafting.current_station()).get("name", "?")], "good" if avg >= 90.0 else "info")


func _practice() -> void:
	var c := Crafting.check_params(station_id)
	var sid := station_id
	Events.open_panel.emit("skillcheck", {"station": sid, "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Practice — " + DB.station(sid)["name"],
		"on_done": func(qs: Array): Game.grant_player_xp(Crafting.skill_for_station(sid), 2 + int(float(qs[0]) / 40.0))})


func _on_socket_pressed(ob_item: OptionButton, ob_rune: OptionButton) -> void:
	var uid := ob_item.get_item_id(ob_item.selected)
	var rd: String = ob_rune.get_item_metadata(ob_rune.selected)
	Events.open_panel.emit("skillcheck", {"station": "rune_engraving_stand", "count": 1, "speed": 0.6, "zone": 28.0,
		"title": "Setting the runestone", "on_done": _on_socket_done.bind(uid, rd)})


func _on_socket_done(qs: Array, uid: int, rd: String) -> void:
	if Crafting.socket(uid, rd, float(qs[0])):
		Events.toast.emit("The runestone settles into the metal with a hum.", "good")
		Audio.play("sfx/rune_hum")


func _socket_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Set a runestone into equipment", 26, "heading"))
	var items := Game.inventory().filter(func(it): return Items.is_equipment(it) and it.get("sockets", []).size() < 2)
	var runes := Game.inventory().filter(func(it): return DB.item(it["def"]).get("type") == "runestone" and it["def"] != "runestone_blank")
	if items.is_empty() or runes.is_empty():
		v.add_child(UIKit.label("You need a finished runestone and a piece of equipment.", 20, "body_italic"))
		return v
	var h := UIKit.hbox()
	var ob_item := OptionButton.new()
	for it in items:
		ob_item.add_item(Items.display_name(it), int(it["uid"]))
	var ob_rune := OptionButton.new()
	for r in runes:
		ob_rune.add_item(r["name"])
		ob_rune.set_item_metadata(ob_rune.item_count - 1, r["def"])
	h.add_child(ob_item)
	h.add_child(ob_rune)
	h.add_child(UIKit.button("Engrave and set", _on_socket_pressed.bind(ob_item, ob_rune), 220))
	v.add_child(h)
	return v


## Infusion rack: brush an oil or coating onto a piece of equipment (lasts a few expeditions).
func _treat_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Treat equipment with an oil or coating", 26, "heading"))
	var items := Game.inventory().filter(func(x): return Items.is_equipment(x))
	var coats := Game.inventory().filter(func(x): return x["def"] in Crafting.TREATMENTS)
	if items.is_empty() or coats.is_empty():
		v.add_child(UIKit.label("You need a whetstone oil, flame or frost coating, and a piece of equipment.", 20, "body_italic"))
		return v
	var h := UIKit.hbox()
	var ob_item := OptionButton.new()
	for x in items:
		ob_item.add_item(Items.display_name(x), int(x["uid"]))
	var ob_coat := OptionButton.new()
	for c in coats:
		ob_coat.add_item(c["name"])
		ob_coat.set_item_metadata(ob_coat.item_count - 1, c["def"])
	h.add_child(ob_item)
	h.add_child(ob_coat)
	h.add_child(UIKit.button("Apply", func():
		var msg := Crafting.treat(ob_item.get_item_id(ob_item.selected), str(ob_coat.get_item_metadata(ob_coat.selected)))
		Events.toast.emit(msg, "good" if msg.begins_with("The") else "bad"), 160))
	v.add_child(h)
	return v
