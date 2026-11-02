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
	info.add_child(UIKit.label("Skill check: %d × ring, zone %d°, speed %.2f rev/s (eased by %s %d)" % [c["count"], int(c["zone"]), c["speed"],
		SkillSys.skill_name(Crafting.skill_for_station(station_id)), Game.player_level(Crafting.skill_for_station(station_id))], 18, "body_italic"))
	var why := Crafting.station_locked_reason(station_id)
	if why != "":
		info.add_child(UIKit.label("Locked — " + why, 22, "body_bold", UIKit.RUBRIC))
	head.add_child(info)
	content.add_child(head)
	content.add_child(UIKit.divider())
	var body := UIKit.vbox(10)
	var job := Crafting.job()
	if not job.is_empty():
		var r := DB.recipe(job["recipe"])
		var steps: Array = r["steps"]
		var chain := []
		for i in steps.size():
			var nm: String = DB.station(steps[i])["name"]
			if i < int(job["step"]):
				chain.append("[s]%s[/s]" % nm)
			elif i == int(job["step"]) and not job["awaiting_dice"]:
				chain.append("[b][color=#7e2418]%s[/color][/b]" % nm)
			else:
				chain.append(nm)
		body.add_child(UIKit.rich("[b]Current work:[/b] %s\n%s%s" % [r["name"], " → ".join(chain), "  → [b]Dice[/b]" if job["awaiting_dice"] else ""], 22))
		if job["awaiting_dice"]:
			body.add_child(UIKit.button("Roll the dice and finish the piece", func(): Events.open_panel.emit("dice", {}), 420))
		elif Crafting.current_station() == station_id:
			body.add_child(UIKit.button("Begin work here (%d check%s)" % [c["count"], "s" if c["count"] > 1 else ""], _work, 420))
		else:
			body.add_child(UIKit.label("Next step is at the %s." % DB.station(Crafting.current_station())["name"], 22, "body_italic"))
		body.add_child(UIKit.button("Abandon work (return materials)", func(): Crafting.cancel(), 340))
	else:
		body.add_child(UIKit.label("Recipes using this station", 26, "heading"))
		for rec in Crafting.recipes_for_station(station_id):
			body.add_child(_recipe_row(rec))
	if station_id == "rune_engraving_stand" and why == "":
		body.add_child(UIKit.divider())
		body.add_child(_socket_ui())
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
	for s in rec["steps"]:
		steps.append(DB.station(s)["name"])
	var lock := Crafting.recipe_locked_reason(rec["id"])
	v.add_child(UIKit.rich("[b]%s[/b]  [i]%s[/i]\n%s\n[color=#5e421c]%s[/color]%s" % [rec["name"], rec.get("desc", ""), ", ".join(ins), " → ".join(steps),
		("\n[color=#9e3a0c]" + lock + "[/color]") if lock != "" else ""], 19))
	row.add_child(v)
	var b := UIKit.button("Begin", func(): _start(rec["id"]), 120)
	b.disabled = lock != "" or not Crafting.missing_inputs(rec["id"]).is_empty()
	row.add_child(b)
	return row


func _start(rid: String) -> void:
	if Crafting.start(rid):
		Events.toast.emit("Begun: %s. First step: %s." % [DB.recipe(rid)["name"], DB.station(Crafting.current_station())["name"]], "info")
		if Crafting.current_station() == station_id:
			_work()


func _work() -> void:
	var c := Crafting.check_params(station_id)
	var sid := station_id
	Events.open_panel.emit("skillcheck", {"station": sid, "count": c["count"], "speed": c["speed"], "zone": c["zone"],
		"title": DB.station(sid)["name"], "on_done": _on_work_done.bind(sid)})
	Audio.play("sfx/" + str(DB.station(sid).get("sfx", "hammer")).replace("hammer", "hammer_1"), -2.0)


func _on_work_done(qs: Array, sid: String) -> void:
	Crafting.record_step(sid, qs)
	if Crafting.job().get("awaiting_dice", false):
		Events.open_panel.emit("dice", {})
	else:
		Events.toast.emit("Step done. Next: %s." % DB.station(Crafting.current_station()).get("name", "?"), "info")


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
