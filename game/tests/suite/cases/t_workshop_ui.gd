## Iteration 012 apprentice presentation: the Workshop Ledger builds with 0, 1 and 3 apprentices and shows their
## tasks and the bottlenecks; the notice board's apprentice tab hires through the engine; the talk panel teaches and
## answers an independence notice; the living miniatures follow the shift (in at 8, break at noon, gone at 18) and
## stand at a free working side of their station, clear of its footprint; occupied stations explain themselves in the
## interaction prompt; activity bubbles in plain words; the apprentice maker line on items; Y opens the ledger; the
## developer shortcuts; and nothing new is stored (save/load of the engine state still round-trips with actors shown).
extends SuiteCase

const SMOKE := ["test_ledger_builds", "test_actors_follow_shift"]


# ------------------------------------------------------------------ fixtures
func _setup(n := 1, rooms := 0) -> Array:
	fresh_game()
	train("smithing", 6)
	Game.state["gold"] = 20000
	var extra := ["cobbler", "laundry", "weaver"]
	for i in mini(rooms, extra.size()):
		Property.dev_grant_unit(extra[i])
	(Game.state["hirelings"] as Array).clear()
	var out := []
	for i in n:
		var g := 0
		while Apprentices.applicants().is_empty() and g < 20:
			Apprentices.refresh_applicants()
			g += 1
		if not check(Apprentices.hire(0) == "", "hire an apprentice"):
			break
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []
		out.append(a)
	return out


func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Control) -> Control:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


func _world() -> VillageWorld:
	var w := VillageWorld.new()
	_host().add_child(w)
	if PlayerNav.of(w) == null:
		var nav := PlayerNav.new()
		nav.name = "PlayerNav"
		w.add_child(nav)
		nav.setup(w, w.player)
	return w


func _to(hour: int, minute := 0) -> void:
	var m := int(Game.state["minute"]) % 1440
	var target := hour * 60 + minute
	Game.advance_minutes((target - m + 1440) % 1440)


func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r != null:
			return r
	return null


func _text_in(n: Node, needle: String) -> bool:
	return _find(n, func(x): return (x is Label and (x as Label).text.contains(needle)) or (x is RichTextLabel and (x as RichTextLabel).text.contains(needle)) \
		or (x is Button and (x as Button).text.contains(needle))) != null


# ------------------------------------------------------------------ tests
func test_ledger_builds() -> void:
	# 0 apprentices (locked, then unlocked), 1 and 3: the panel builds, shows the cards, queue rows and bottlenecks
	fresh_game()
	var p0 := _mount(WorkshopPanel.new())
	check(_text_in(p0, "Apprentices  0 /"), "0 apprentices: the heading counts the places")
	check(_text_in(p0, Apprentices.unlock_reason().substr(0, 20)), "locked: the panel says why")
	_unmount(p0)
	var staff := _setup(1)
	var a: Dictionary = staff[0]
	give("ingot_iron", 4)
	var preps := WorkshopPanel.pickable_recipes("prep")
	check(not preps.is_empty(), "a novice can prepare something")
	var t: Dictionary = Apprentices.add_task("prep", {"recipe": str(preps[0]["id"])}) if not preps.is_empty() else {"error": "none"}
	var p1 := _mount(WorkshopPanel.new()) as WorkshopPanel
	check(p1.left.get_node_or_null("AppCard_" + str(a["id"])) != null, "1 apprentice: their card is shown")
	check(_find(p1, func(x): return x.name == "Bottlenecks") != null, "the Bottlenecks box is shown")
	if not t.has("error"):
		check(_find(p1, func(x): return x.name == "Task_%d" % int(t["id"])) != null, "the queued task has a row")
	check(_find(p1, func(x): return x.name == "RecipePick") != null or WorkshopPanel.pickable_recipes("craft").is_empty(), "the add-work box offers recipes")
	for k in ["repair", "commission", "prep", "maintain", "craft"]:
		p1.add_kind = k
		p1.build()
	_unmount(p1)
	# three apprentices need two more workshop rooms
	var s3 := _setup(3, 2)
	eq(s3.size(), 3, "three apprentices hired with two extra rooms")
	var p3 := _mount(WorkshopPanel.new()) as WorkshopPanel
	var cards := 0
	for x in s3:
		if p3.left.get_node_or_null("AppCard_" + str(x["id"])) != null:
			cards += 1
	eq(cards, 3, "3 apprentices: three cards")
	check(p3.get_combined_minimum_size().x <= 1900.0 and p3.get_combined_minimum_size().y <= 1080.0,
		"the ledger fits 1920×1080 (%s)" % str(p3.get_combined_minimum_size()))
	_unmount(p3)
	eq(UIRoot.panel_for_action("panel_workshop"), "workshop", "its key opens the workshop ledger")
	# S2: Y opens the toolbar's "Workshop" (rooms & stations) so key and label match; the ledger moved to Q
	check((Settings.DEFAULT_KEYS["panel_workshop"] as Array).has(KEY_Q), "panel_workshop is bound to Q")


func test_notice_board_hires() -> void:
	fresh_game()
	var nb := _mount(NoticePanel.new("apprentices")) as NoticePanel
	check(_text_in(nb, Apprentices.unlock_reason().substr(0, 20)), "locked: the apprentice tab says why")
	_unmount(nb)
	train("smithing", 6)
	Game.state["gold"] = 5000
	Apprentices.refresh_applicants()
	var name := str(Apprentices.applicants()[0]["name"])
	nb = _mount(NoticePanel.new("apprentices")) as NoticePanel
	check(nb.body.get_node_or_null("Applicant_0") != null, "the applicant's card is pinned up")
	var b := _find(nb.body, func(x): return x is Button and (x as Button).text == "Take on") as Button
	if check(b != null and not b.disabled, "a Take on button"):
		b.pressed.emit()
	eq(Apprentices.staff().size(), 1, "taking one on hires through the engine")
	eq(str(Apprentices.staff()[0]["name"]), name, "the right person was hired")
	_unmount(nb)
	# the place is full: the next button is disabled with the engine's reason
	Apprentices.refresh_applicants()
	nb = _mount(NoticePanel.new("apprentices")) as NoticePanel
	var b2 := _find(nb.body, func(x): return x is Button and (x as Button).text == "Take on") as Button
	check(b2 == null or b2.disabled, "no place left: the button is disabled")
	check(_text_in(nb, "room for 1 apprentice"), "and says why (%s)" % Apprentices.hire_reason())
	_unmount(nb)


func test_talk_panel_teach_and_independence() -> void:
	var staff := _setup(1)
	var a: Dictionary = staff[0]
	_to(9)
	var tp := _mount(ApprenticeTalkPanel.new(str(a["id"]))) as ApprenticeTalkPanel
	check(tp.card_host.get_node_or_null("ApprenticeCard") != null, "their card is shown")
	var xp_before := int(a["skills"][Apprentices.best_skill(a)]["xp"]) + 1000 * Apprentices.level(a, Apprentices.best_skill(a))
	var t0 := Game.now()
	tp._teach()
	check(Game.now() - t0 >= 60, "teaching takes an hour")
	check(int(a["skills"][Apprentices.best_skill(a)]["xp"]) + 1000 * Apprentices.level(a, Apprentices.best_skill(a)) > xp_before, "and they learn")
	eq(int(a["mentored_day"]), Game.day(), "mentored today")
	tp._how()
	tp._recent()
	check(tp.text.text.length() > 10, "they tell you about their work")
	_unmount(tp)
	# independence: asked, then blessed from the talk panel — a farewell, and an alumnus
	ApprenticeDev.independence()
	eq(str(a["notice"].get("kind", "")), "independence", "the dev shortcut gives an independence notice")
	tp = _mount(ApprenticeTalkPanel.new(str(a["id"]))) as ApprenticeTalkPanel
	check(tp.text.text.contains("workshop of my own"), "they ask for your blessing")
	check(_text_in(tp.opts, "blessing"), "the answer is offered")
	tp._answer("bless")
	check(Apprentices.staff().is_empty(), "they left with your blessing")
	eq(Apprentices.alumni().size(), 1, "and are a former apprentice now")
	check(tp.text.text.contains("strike your own mark"), "a farewell scene")
	_unmount(tp)


func test_actors_follow_shift() -> void:
	var staff := _setup(2, 1)
	var a: Dictionary = staff[0]
	_to(7)
	eq(ApprenticeActors.present_ids().size(), 0, "07:00 — nobody in the workshop yet")
	_to(9)
	eq(ApprenticeActors.present_ids().size(), 2, "09:00 — both on shift")
	_to(12, 30)
	eq(str(ApprenticeActors.plan_for(a)["kind"]), "break", "12:30 — on the midday break")
	check(bool(ApprenticeActors.plan_for(a)["present"]), "the break is taken in the house")
	_to(19)
	eq(ApprenticeActors.present_ids().size(), 0, "19:00 — gone home")
	# in the world: a task at the anvil puts them at a free side of it, with a ring and a prompt
	_to(7, 50)
	give("ingot_iron", 4)
	give("leather_cured", 2)
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "assignee": str(a["id"])})
	check(not t.has("error"), "a longsword queued (%s)" % t.get("error", ""))
	var w := _world()
	var acts := w.get_node("ApprenticeActors") as ApprenticeActors
	acts.sync()
	check(acts.actors.has(str(a["id"])) and not (acts.actors[str(a["id"])] as NPCActor).visible, "07:50 — the actor exists but is not in the smithy")
	var g := 0
	while Apprentices.station_user("forge") != str(a["id"]) and Apprentices.station_user("anvil") != str(a["id"]) and g < 60:
		Game.advance_minutes(5)
		g += 1
	acts.sync()
	var n: NPCActor = acts.actors.get(str(a["id"]))
	check(n != null and n.visible, "on shift — the miniature is in the smithy")
	check(w.npcs.has(str(a["id"])) and n.get_meta("apprentice", false), "registered as an apprentice NPC")
	var sid := str(ApprenticeActors.plan_for(a)["station"])
	check(sid != "", "they are bound for a station (%s)" % sid)
	if sid != "":
		var ws := acts.work_spot(sid)
		var nav := PlayerNav.of(w)
		check(nav.walkable(ws["pos"]) and nav.clear_at(ws["pos"], 16.0), "the working side of the %s is clear floor (not inside the station or a wall)" % sid)
		var st := DB.station(sid)
		var foot := Rect2(w.station_pos(sid) - Vector2(float(st["size"][0]), float(st["size"][1])) * Vector2(0.38, 0.28), Vector2(float(st["size"][0]), float(st["size"][1])) * Vector2(0.76, 0.56))
		check(not foot.has_point(ws["pos"]), "they stand outside its footprint")
		check(w.room_at("smithy", ws["pos"]) != "", "inside a room of the smithy")
		# jump them there (time moved in one go) and check the ring and the prompt
		acts._last_now = -1
		acts.sync()
		check(n.position.distance_to(ws["pos"]) < 8.0, "after a time jump they are at their place")
		if Apprentices.station_user(sid) == str(a["id"]):
			check(acts.rings().has(sid), "a ring marks the station in use")
			var pr := ApprenticeActors.station_prompt(sid, "Anvil")
			check(pr.contains(str(a["name"]).split(" ")[0]) and pr.contains("step aside"), "the prompt says who works there (%s)" % pr)
		var bub := ApprenticeUI.bubble(a)
		check(str(bub.get("text", "")) != "" and not str(bub["text"]).begins_with("Waiting"), "a plain activity bubble (%s)" % bub.get("text", ""))
	# the break and the end of the day
	_to(12, 20)
	acts._last_now = -1
	acts.sync()
	eq(str(acts._goal.get(str(a["id"]), {}).get("kind", "")), "break", "at noon they go to their break")
	check(acts.rings().is_empty(), "nobody holds a station at the break")
	_to(18, 30)
	acts._last_now = -1
	acts.sync()
	check(not n.visible, "after 18:00 they have gone home")
	# save/load with actors: the presentation stores nothing of its own
	check(save_load("suite_w12_ui"), "save/load round-trip")
	check(not Game.state.has("apprentice_actors"), "no presentation state in the save")
	eq(Apprentices.staff().size(), 2, "the staff survives the round-trip")
	_unmount(w)


func test_words_and_maker_line() -> void:
	eq(ApprenticeUI.gerund("Draw out the blade"), "drawing out the blade", "gerund: draw")
	eq(ApprenticeUI.gerund("Heat the billet"), "heating the billet", "gerund: heat")
	eq(ApprenticeUI.gerund("Cut, punch and fit"), "cutting, punch and fit", "gerund: cut,")
	eq(ApprenticeUI.gerund("Forge the blank"), "forging the blank", "gerund: forge")
	eq(ApprenticeUI.gerund("Steam-bend the stave"), "steam-bending the stave", "gerund: hyphenated")
	eq(ApprenticeUI.gerund("Spin a thread"), "spinning a thread", "gerund: doubling")
	# an apprentice's piece: the maker line names them, the forge, their mark and the supervisor
	var staff := _setup(1)
	var a: Dictionary = staff[0]
	a["rank"] = "apprentice"
	a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "assignee": str(a["id"]), "supervised": true})
	_to(8)
	var g := 0
	while not str(t["state"]) in ["done", "failed"] and g < 400:
		Game.advance_minutes(15)
		g += 1
	if not check(str(t["state"]) == "done", "the longsword is finished"):
		return
	var it := Game.find_uid(int(t["made"][0]))
	check(ApprenticeUI.is_apprentice_work(it), "apprentice work is recognised")
	var line := ApprenticeUI.maker_line(it)
	check(line.contains(str(a["name"])) and line.contains("apprentice at the Ironhand forge"), "maker line: %s" % line)
	check(line.contains(str(a["mark"]["desc"])), "the maker line describes their mark")
	check(line.contains("under the eye of"), "supervised work says so")
	check(Items.tooltip(it).contains("your apprentice"), "the tooltip says it is your apprentice's work")
	eq(ItemStory.mark_icon(it), "marks/apprentice", "the apprentice punch-mark icon is drawn and used")
	# the item panel shows it
	var ip := _mount(ItemPanel.new(int(it["uid"]))) as Control
	check(_text_in(ip, "apprentice at the Ironhand forge"), "the inspection names the apprentice and the forge")
	_unmount(ip)
	# the smith's own piece is not apprentice work
	train("smithing", 6)
	var own := craft("iron_longsword") if craft_blocker("iron_longsword") == "" else {}
	if not own.is_empty():
		check(not ApprenticeUI.is_apprentice_work(own), "the smith's own piece is not apprentice work")
		eq(ApprenticeUI.maker_line(own), "", "and has no apprentice maker line")


func test_dev_shortcuts() -> void:
	fresh_game()
	Game.state["gold"] = 5000
	ApprenticeDev.unlock()
	check(Apprentices.unlocked(), "unlock")
	ApprenticeDev.add_applicant()
	check(not Apprentices.applicants().is_empty(), "an applicant")
	ApprenticeDev.hire_one()
	eq(Apprentices.staff().size(), 1, "hire one")
	var a: Dictionary = Apprentices.staff()[0]
	ApprenticeDev.promote()
	eq(str(a["rank"]), "apprentice", "promote")
	ApprenticeDev.advance_shift()
	check(Game.hour() in [8, 12, 13, 18] and int(Game.state["minute"]) % 60 == 0, "advance to a shift change (%s)" % Game.time_string())
	var t := Apprentices.add_task("craft", {"recipe": "iron_longsword"})
	if not t.has("error"):
		ApprenticeDev.give_materials()
		check(Crafting.missing_inputs("iron_longsword").is_empty(), "materials for the queue")
