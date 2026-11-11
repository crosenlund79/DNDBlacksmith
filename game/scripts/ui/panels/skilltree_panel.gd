## SkillTreePanel — the Skill Tree (the smith's own path and the workshop's knowledge) and the workshop's catalogue.
## EN: Two views. "The Skill Tree": an inked parchment chart; branches as labelled columns under two bands — YOUR OWN
##     PATH (Traditional Smithing, Mining & Metallurgy: the smith's own levels and personal techniques) and THE
##     WORKSHOP'S KNOWLEDGE (the other crafts: learned through a competent hand, the smith at his basic level or a
##     specialist on the staff). Nodes are inked medallions joined by prerequisite lines (gilt once learned). States:
##     learned (gilt), available (glowing, "Learn"), locked (grey, padlock), secret ("???" once a predecessor is known,
##     otherwise not drawn). Mouse wheel zooms, dragging pans, hovering or clicking a node shows its description, exact
##     requirements (✓/✗), through whom it was or would be learned and what it unlocks (Designs, stations, techniques —
##     whose a technique is). Prerequisites from a distant branch are shown as small branch seals instead of long lines.
##     "Workshop knowledge": the catalogue (WorkshopKnowledge) — the Designs the workshop knows by craft and who may make
##     each (personal competence), its techniques and whom they help, the materials it works, its discoveries and what
##     each specialist brought in. Knowing a Design never makes anyone able to make it.
##     Opened with Events.open_panel.emit("skilltree", {}) (optional args: {"select": node_id, "view": "knowledge"}).
##     Rebuilds are gathered once per frame and replaced content leaves the layout at once (LW #59–60: _clear).
## DA: Færdighedstræet (smedens egen sti og værkstedets viden) og værkstedets katalog over kendte Designs, teknikker,
##     materialer og opdagelser — og hvem der kan lave hvad.
class_name SkillTreePanel
extends UIWindow

var canvas: TreeCanvas
var side: VBoxContainer
var skill_row: HBoxContainer
var shown := "-"
## B2: "tree" (the chart) or "knowledge" (the workshop's catalogue).
var view := "tree"
var body: HBoxContainer
var kscroll: ScrollContainer
var kview: VBoxContainer
var tab_tree: Button
var tab_know: Button


func _init(args := {}) -> void:
	super._init("The Skill Tree", 1800, 980)
	canvas = TreeCanvas.new()
	canvas.selected = str(args.get("select", ""))
	view = "knowledge" if str(args.get("view", "")) == "knowledge" else "tree"


func _ready() -> void:
	super._ready()
	title_label.text = "✦ The Skill Tree — Your Path & the Workshop's Knowledge ✦"
	var tabs := UIKit.hbox(8)
	tab_tree = UIKit.tab_button("The Skill Tree", func(): _set_view("tree"), view == "tree")
	tab_tree.name = "TabTree"
	tabs.add_child(tab_tree)
	tab_know = UIKit.tab_button("Workshop knowledge", func(): _set_view("knowledge"), view == "knowledge")
	tab_know.name = "TabKnowledge"
	tabs.add_child(tab_know)
	var tnote := UIKit.note("Your own path: Smithing and Mining, by your own levels. The other crafts are the workshop's knowledge, learned through a competent hand. Knowing a Design is not being able to make it.", 17)
	tnote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tnote)
	content.add_child(tabs)
	skill_row = UIKit.hbox(10)
	content.add_child(skill_row)
	body = UIKit.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	kview = UIKit.vbox(8)
	kview.name = "KnowledgeView"
	kview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kscroll = UIKit.scroll(kview, 760)
	kscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(kscroll)
	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(1240, 700)
	canvas.focus_changed.connect(_on_focus)
	left.add_child(canvas)
	var foot := UIKit.hbox(10)
	var hint := UIKit.label("Mouse wheel: zoom · drag: pan · click a seal for its details", 17, "body_italic")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	foot.add_child(_legend_chip("Learned", "unlocked"))
	foot.add_child(_legend_chip("Ready to learn", "available"))
	foot.add_child(_legend_chip("Locked", "locked"))
	foot.add_child(UIKit.button("Fit the whole tree", func(): canvas.fit_all(), 220))
	foot.add_child(UIKit.button("Top", func(): canvas.reset_view(), 90))
	foot.add_child(InkIcons.button("ic_work", "Skill levels [%s]" % Settings.key_label("panel_skill_levels"), func(): Events.open_panel.emit("skills", {}), 220))
	left.add_child(foot)
	var sp := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.92)
	sb.border_color = Color(UIKit.INK, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sp.add_theme_stylebox_override("panel", sb)
	sp.custom_minimum_size = Vector2(440, 0)
	side = UIKit.vbox(8)
	var sc := UIKit.scroll(side, 760)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.add_child(sc)
	body.add_child(sp)
	Events.crafting_changed.connect(_refresh)
	Events.inventory_changed.connect(_refresh)
	Events.skill_level_up.connect(func(_w, _s, _l): _refresh())
	_build_skills()
	_on_focus(canvas.selected)
	_set_view(view)


## Shows the chart or the catalogue (the catalogue is built when shown, once — never per frame).
func _set_view(v: String) -> void:
	view = v
	var tree := v == "tree"
	skill_row.visible = tree
	body.visible = tree
	kscroll.visible = not tree
	tab_tree.set_pressed_no_signal(tree)
	tab_know.set_pressed_no_signal(not tree)
	if not tree:
		_build_knowledge()


func _legend_chip(text: String, state: String) -> Control:
	var h := UIKit.hbox(4)
	var dot := LegendDot.new(state)
	h.add_child(dot)
	h.add_child(UIKit.label(text, 17))
	return h


## LW #59–60: learning a node fires several signals (gold, inventory, crafting, level-up) in one frame; each used to
## rebuild the branch row and the side page at once. They are gathered into one rebuild at the end of the frame.
var _refresh_queued := false


func _refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_build_skills()
	canvas.queue_redraw()
	_show(shown, true)
	if view == "knowledge":
		_build_knowledge()


## LW #59–60: empties a row or page before it is rebuilt. UIKit.clear only queues the old children for deletion, so
## until the end of the frame they still took part in layout beside the new ones: the side page held two pages and the
## branch row two or three rows at once (the chart was briefly laid out 3,400–5,300 px wide), and the window, the chart
## and the side page's scroll bar were resized back and forth within the frame. A seeded run of buying, moving and
## learning while browsing the tree (tests/playtest_lw_probe.gd) ended in "Message queue out of memory" — a flood of
## deferred layout calls — and a crash (SIGSEGV). Hidden children leave the layout at once; they are still freed at the
## end of the frame (safe for the Learn button whose own press rebuilt the page).
static func _clear(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.queue_free()


func _build_skills() -> void:
	_clear(skill_row)
	for b in SkillTree.branches():
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Color(str(b["colour"])), 0.12)
		sb.border_color = Color(Color(str(b["colour"])), 0.7)
		sb.set_border_width_all(0)
		sb.border_width_top = 3
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIKit.vbox(2)
		var sk := str(b["skill"])
		var nb := SkillTree.branch_nodes(str(b["id"])).filter(func(n): return SkillTree.node_state(n["id"]) != "hidden" or SkillTree.is_unlocked(n["id"]))
		var head := UIKit.label(str(b["name"]), 17, "heading", Color(str(b["colour"])).darkened(0.25))
		head.clip_text = true
		v.add_child(head)
		var row := UIKit.hbox(8)
		var own := WorkshopKnowledge.branch_owner(str(b["id"])) == "smith"
		var best := Workers.best_level(sk)
		if own or str(best["actor"]) == "player":
			var mine := UIKit.label("You %d" % Game.player_level(sk), 17, "body_bold")
			mine.clip_text = true
			mine.custom_minimum_size = Vector2(60, 0)
			mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mine.tooltip_text = ("Your own path: your %s level." if own else "Your %s level — the workshop's best hand in it.") % SkillSys.skill_name(sk)
			row.add_child(mine)
			var bar := UIKit.bar(SkillSys.progress(Game.player_skills(), sk), 1.0, 40)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.tooltip_text = "%d / %d experience to the next level" % [int(Game.player_skills().get(sk, {}).get("xp", 0)), SkillSys.xp_needed(Game.player_level(sk) + 1)]
			row.add_child(bar)
		else:
			var who := UIKit.label("%s %d · you %d" % [str(best["name"]).split(" ")[0], int(best["level"]), Game.player_level(sk)], 17, "body_bold")
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			who.clip_text = true
			who.custom_minimum_size = Vector2(60, 0)
			who.tooltip_text = "The workshop's best hand in %s: %s (%d). Yours: %d." % [SkillSys.skill_name(sk).to_lower(), best["name"], int(best["level"]), Game.player_level(sk)]
			row.add_child(who)
		row.add_child(UIKit.label("%d/%d" % [SkillTree.count_learned(str(b["id"])), nb.size()], 16, "body_italic"))
		v.add_child(row)
		card.add_child(v)
		skill_row.add_child(card)


func _on_focus(id: String) -> void:
	_show(id, false)


## Side panel: description, requirements and unlocks of the focused node (hover, else selection).
func _show(id: String, force: bool) -> void:
	if id == shown and not force:
		return
	shown = id
	_clear(side)
	if id == "" or SkillTree.node(id).is_empty():
		side.add_child(UIKit.label("Your Path & the Workshop", 28, "title"))
		side.add_child(UIKit.rich("[b]Your own path[/b] — Traditional Smithing and Mining & Metallurgy — is the blacksmith's craft: its seals need your own levels and their techniques are yours.\n\n[b]The workshop's knowledge[/b] — the other five crafts — is learned through a competent hand: you, at your basic level of that craft, or a specialist on your staff. Each seal adds Designs, stations and techniques to what the workshop knows.\n\nKnowing a Design is not being able to make it: who may make it is each worker's own competence. Gilt seals are known; a seal that [color=#9e3a0c][b]glows[/b][/color] can be learned now.\n\n[i]Hover over a seal to read it; click it to keep it open here.[/i]", 19))
		var ready := SkillTree.nodes().filter(func(n): return SkillTree.node_state(n["id"]) == "available")
		if not ready.is_empty():
			side.add_child(UIKit.divider())
			side.add_child(UIKit.label("Ready to learn", 22, "heading", UIKit.RUBRIC))
			for n in ready:
				var nid: String = n["id"]
				side.add_child(UIKit.button("✦ " + str(n["name"]), func(): canvas.select(nid), 0))
		return
	var n := SkillTree.node(id)
	var st := SkillTree.node_state(id)
	var b := SkillTree.branch(str(n["branch"]))
	if st == "hidden":
		side.add_child(UIKit.label("???", 30, "title"))
		side.add_child(UIKit.rich("[i]Something lies beyond %s — a secret of the craft. You will need to discover it in the world before it can even be named.[/i]" % _pre_names(n), 19))
		return
	var tl := UIKit.label(str(n["name"]), 28, "title")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(tl)
	var badge := {"unlocked": "[color=#5e421c]✦ Learned[/color]", "available": "[color=#9e3a0c][b]✦ Ready to learn[/b][/color]", "locked": "[color=#6a5e50]Locked[/color]"}
	side.add_child(UIKit.rich("[i]%s[/i] · %s%s" % [b.get("name", ""), badge.get(st, st), "  · [color=#5a3e8a]secret[/color]" if n.get("secret", false) else ""], 18))
	var own := WorkshopKnowledge.node_owner(id) == "smith"
	side.add_child(UIKit.rich("[color=%s][b]%s[/b][/color]" % ["#7e2418" if own else "#2e4e6e", "Your own path — your levels, your techniques" if own else "The workshop's knowledge — learned through a competent hand"], 17))
	side.add_child(UIKit.rich(str(n.get("desc", "")), 19))
	# requirements
	var reqs := SkillTree.requirements(id)
	if not reqs.is_empty():
		side.add_child(UIKit.label("Requirements", 22, "heading", UIKit.RUBRIC))
		var lines := []
		for q in reqs:
			lines.append("[color=%s]%s %s[/color]" % ["#26622f" if q["ok"] or st == "unlocked" else "#9e3a0c", "✓" if q["ok"] or st == "unlocked" else "✗", q["text"]])
		side.add_child(UIKit.rich("\n".join(lines), 18))
	# learn
	if st == "unlocked":
		var day := int(Game.state.get("skilltree", {}).get("day", {}).get(id, 0))
		var by := WorkshopKnowledge.brought_by(id)
		var since := (" since day %d" % day) if day > 0 else ""
		var txt := "Known to you%s." % since
		if not own:
			txt = "Known to the workshop%s — learned through %s." % [since, WorkshopKnowledge.who_text(by)]
		var kl := UIKit.label(txt, 18, "body_italic")
		kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(kl)
	elif st == "available":
		var bearer := WorkshopKnowledge.bearer(id)
		var via := not own and bearer != "player" and bearer != ""
		var lb := UIKit.button(("✦ Learn through %s" % str(Workers.resolve(bearer)["name"])) if via else ("✦ Learn %s" % n["name"]), _learn.bind(id), 0)
		lb.name = "LearnButton"
		lb.clip_text = true   # a long name never widens the side page (and the window)
		lb.tooltip_text = lb.text
		side.add_child(lb)
		if not own and bearer != "":
			var wl := UIKit.note("The workshop learns it through %s. Nobody's skills change." % WorkshopKnowledge.who_text(bearer), 17)
			side.add_child(wl)
	else:
		var why := UIKit.label(SkillTree.can_unlock(id), 18, "body_italic", Color("#9e3a0c"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(why)
	# unlocks
	var u: Dictionary = n.get("unlocks", {})
	side.add_child(UIKit.divider())
	side.add_child(UIKit.label("Unlocks", 22, "heading", UIKit.RUBRIC))
	for s in u.get("stations", []):
		side.add_child(_unlock_row("stations/" + str(s), "Station: " + str(DB.station(str(s)).get("name", s)), _station_tip(str(s))))
	for r in u.get("recipes", []):
		var rid := str(r)
		if not SkillTree.recipe_visible(rid):
			side.add_child(_unlock_row("", "A forgotten Design (???)", "[i]Its notes are still lost among the relics.[/i]"))
			continue
		var rec := DB.recipe(rid)
		side.add_child(_unlock_row("icons/" + str(DB.item(str(rec.get("output", ""))).get("icon", rec.get("output", ""))), "Design: " + str(rec.get("name", rid)), _recipe_tip(rid)))
	for t in u.get("techniques", []):
		side.add_child(UIKit.rich(_technique_text(t, id), 18))
	var kids := SkillTree.children(id).filter(func(c): return SkillTree.node_state(c["id"]) != "hidden")
	if not kids.is_empty():
		side.add_child(UIKit.rich("[color=#5e421c][i]Leads on to: %s[/i][/color]" % ", ".join(kids.map(func(c): return str(c["name"]))), 17))


## A technique's lines on a node page: whose it is (B2) — the smith's own (his path), the workshop's method, or a craft
## technique that helps whoever works at the node's level by their own skill (and who that is now).
func _technique_text(t: Dictionary, nid: String) -> String:
	var head := "[b]Technique — %s[/b]\n[i]%s[/i]" % [t.get("name", ""), t.get("desc", "")]
	if float(t.get("quality", 0)) <= 0.0:
		return "[b]Method — %s[/b]\n[i]%s[/i]\n[color=#5e421c]Known to the workshop once learned; anyone working it may use it.[/color]" % [t.get("name", ""), t.get("desc", "")]
	if WorkshopKnowledge.node_owner(nid) == "smith":
		return head + "\n[color=#7e2418]Your personal technique — it helps your own work only.[/color]"
	var sk: Array = SkillTree.node(nid)["requires"].get("skill", [])
	if sk.is_empty():
		return head
	var who := []
	for aid in Workers.workshop_actors():
		if WorkshopKnowledge.technique_applies(str(aid), nid):
			who.append("you" if str(aid) == "player" else str(Workers.resolve(str(aid))["name"]))
	return head + "\n[color=#2e4e6e]Helps whoever works it with %s %d of their own%s.[/color]" % [SkillSys.skill_name(str(sk[0])), int(sk[1]),
		(" — now: " + ", ".join(who)) if not who.is_empty() else " — nobody on your staff yet"]


func _pre_names(n: Dictionary) -> String:
	var names := []
	for p in n["requires"].get("nodes", []):
		names.append(str(SkillTree.node(str(p)).get("name", p)))
	return " and ".join(names)


func _unlock_row(icon_id: String, text: String, tip: String) -> Control:
	var h := UIKit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_id != "":
		var ic := UIKit.icon(icon_id, 40)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var l := UIKit.label(text, 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var wrap := MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(h)
	wrap.mouse_entered.connect(func(): UIRoot.show_tooltip(tip))
	wrap.mouse_exited.connect(func(): UIRoot.hide_tooltip())
	return wrap


func _station_tip(sid: String) -> String:
	var st := DB.station(sid)
	var t := "[b]%s[/b]\n[i]%s[/i]" % [st.get("name", sid), st.get("purpose", "")]
	var why := Crafting.station_locked_reason(sid)
	if why != "":
		t += "\n[color=#ff9a7a]Not usable yet: %s[/color]" % why
	elif not Property.is_installed(sid):
		t += "\n[color=#ffcf7a]Learned stations must still be bought and installed in the workshop.[/color]"
	else:
		t += "\n[color=#9adf9a]Ready in your workshop.[/color]"
	return t


func _recipe_tip(rid: String) -> String:
	var r := DB.recipe(rid)
	var ins := []
	for i in r.get("inputs", {}):
		ins.append("%d× %s (have %d)" % [int(r["inputs"][i]), DB.item(str(i)).get("name", i), Game.count(str(i))])
	var t := "[b]%s[/b]\n[i]%s[/i]\n%s · difficulty %d\nNeeds: %s" % [r.get("name", rid), r.get("desc", ""), Crafting.DISCIPLINE_NAME.get(r.get("discipline", ""), ""), Crafting.difficulty(rid), ", ".join(ins)]
	var why := Crafting.recipe_locked_reason(rid)
	var known := Workers.knowledge_reason(rid) == ""
	if known:
		var who := _who_names(rid)
		t += "\n[color=#cfe0ff]Known to the workshop · may make it: %s[/color]" % (", ".join(who) if not who.is_empty() else "nobody yet")
	if why != "":
		t += "\n[color=#ff9a7a]%s: %s[/color]" % ["You cannot make it yourself" if known else "Unavailable", why]
	elif not Crafting.missing_inputs(rid).is_empty():
		t += "\n[color=#ffcf7a]Known — some materials are missing.[/color]"
	else:
		t += "\n[color=#9adf9a]Can be made now.[/color]"
	return t


## Who on the workshop's staff may make a Design (each worker's own competence): ["you", "Edda Vell"].
static func _who_names(rid: String) -> Array:
	var out := []
	for aid in Workers.who_can(rid):
		out.append("you" if str(aid) == "player" else str(Workers.resolve(str(aid))["name"]))
	return out


# ======================================================================= the workshop's knowledge (B2)
const DISC_ORDER := ["classic", "stitching", "runecraft", "alchemy", "arcane"]


## The catalogue view: built when shown (and on a gathered refresh while shown) — a handful of rich-text blocks, never
## one control per Design, so a rebuild stays light.
func _build_knowledge() -> void:
	if kview == null:
		return
	_clear(kview)
	var c := WorkshopKnowledge.counts()
	kview.add_child(UIKit.label("What the workshop knows", 28, "title"))
	var intro := UIKit.rich("The workshop's knowledge belongs to the forge, not to anyone in it: the [b]Designs[/b] it can plan, the stations it knows how to set up, the techniques and materials it has learned — through you on your own path, or through a competent hand in another craft. [b]It never makes anyone more skilled.[/b] Who may make a Design is each worker's own competence, shown beside it.", 19)
	intro.fit_content = true
	kview.add_child(intro)
	var sum := UIKit.label("%d of %d Designs · %d stations · %d techniques and methods" % [int(c["designs"]), int(c["designs_total"]), int(c["stations"]), int(c["techniques"])], 21, "body_bold", UIKit.RUBRIC)
	sum.name = "KnowledgeSummary"
	kview.add_child(sum)
	var by := WorkshopKnowledge.designs_by_discipline()
	for disc in DISC_ORDER:
		var ids: Array = by.get(disc, [])
		if ids.is_empty():
			continue
		kview.add_child(UIKit.label("%s — %d Design%s" % [str(Crafting.DISCIPLINE_NAME.get(disc, disc)), ids.size(), "" if ids.size() == 1 else "s"], 22, "heading", UIKit.RUBRIC))
		var lines := []
		for rid in ids:
			var e := WorkshopKnowledge.entry("designs", str(rid))
			var nid := str(e.get("node", SkillTree.recipe_node(str(rid))))
			var who := _who_names(str(rid))
			var make := "[color=#26622f]%s[/color]" % ", ".join(who) if not who.is_empty() else "[color=#9e3a0c]%s[/color]" % _nobody_text(str(rid))
			var from := str(SkillTree.node(nid).get("name", "")) if nid != "" else "common knowledge"
			var through := ""
			if str(e.get("by", "player")) != "player":
				through = " through %s" % str(WorkshopKnowledge.who_text(str(e["by"])))
			lines.append("[b]%s[/b]  [color=#6a5e50][i]%s%s[/i][/color] — %s" % [DB.recipe(str(rid)).get("name", rid), from, through, make])
		var blk := UIKit.rich("\n".join(lines), 18)
		blk.fit_content = true
		blk.name = "Designs_" + disc
		kview.add_child(blk)
	# techniques and methods
	var known_t: Dictionary = WorkshopKnowledge.st()["techniques"]
	if not known_t.is_empty():
		kview.add_child(UIKit.label("Techniques and methods — %d" % known_t.size(), 22, "heading", UIKit.RUBRIC))
		var tl := []
		for tid in known_t:
			var nid2 := str((known_t[tid] as Dictionary).get("node", ""))
			for t in SkillTree.node(nid2).get("unlocks", {}).get("techniques", []):
				if str(t.get("id", "")) != str(tid):
					continue
				var whose := "a method the workshop knows"
				if float(t.get("quality", 0)) > 0.0:
					if WorkshopKnowledge.node_owner(nid2) == "smith":
						whose = "[color=#7e2418]yours — your own path[/color]"
					else:
						var sk: Array = SkillTree.node(nid2)["requires"].get("skill", ["", 0])
						var users := []
						for aid in Workers.workshop_actors():
							if WorkshopKnowledge.technique_applies(str(aid), nid2):
								users.append("you" if str(aid) == "player" else str(Workers.resolve(str(aid))["name"]))
						whose = "[color=#2e4e6e]helps whoever has %s %d — %s[/color]" % [SkillSys.skill_name(str(sk[0])), int(sk[1]), ", ".join(users) if not users.is_empty() else "nobody on the staff yet"]
				tl.append("[b]%s[/b] — %s\n   [i][color=#6a5e50]%s[/color][/i]" % [t.get("name", tid), whose, t.get("desc", "")])
		var tb := UIKit.rich("\n".join(tl), 18)
		tb.fit_content = true
		tb.name = "Techniques"
		kview.add_child(tb)
	# materials, discoveries, credit
	var mats := WorkshopKnowledge.materials()
	if not mats.is_empty():
		kview.add_child(UIKit.label("Materials the workshop works", 22, "heading", UIKit.RUBRIC))
		var mb := UIKit.rich(" · ".join(mats.values()), 18)
		mb.fit_content = true
		kview.add_child(mb)
	var disc_l := WorkshopKnowledge.discoveries()
	kview.add_child(UIKit.label("Discoveries", 22, "heading", UIKit.RUBRIC))
	var dl := []
	for d in disc_l:
		dl.append("[b]%s[/b] — [i]%s[/i]" % [d["name"], d["hint"]])
	var db := UIKit.rich("\n".join(dl) if not dl.is_empty() else "[i]None yet. Some knowledge cannot be bought or taught — it is found in the world.[/i]", 18)
	db.fit_content = true
	kview.add_child(db)
	var cl := []
	var seen := {}
	for nid3 in (WorkshopKnowledge.st()["nodes"] as Dictionary):
		var who3 := WorkshopKnowledge.brought_by(str(nid3))
		if who3 == "player" or seen.has(who3):
			continue
		seen[who3] = true
		var names := WorkshopKnowledge.credit(who3).map(func(x): return str(SkillTree.node(str(x)).get("name", x)))
		cl.append("[b]%s[/b]: %s" % [WorkshopKnowledge.who_text(who3), ", ".join(names)])
	kview.add_child(UIKit.label("Brought in through your staff", 22, "heading", UIKit.RUBRIC))
	var cb := UIKit.rich("\n".join(cl) if not cl.is_empty() else "[i]Nothing yet — a specialist on your staff can bring in their craft's knowledge beyond your own basic level.[/i]", 18)
	cb.fit_content = true
	cb.name = "Credit"
	kview.add_child(cb)
	var rest := int(c["designs_total"]) - int(c["designs"])
	if rest > 0:
		kview.add_child(UIKit.note("Not known yet: %d Design%s — the Skill Tree shows where each is learned." % [rest, "" if rest == 1 else "s"], 18))


## Why nobody on the staff may make a known Design, in a few words.
static func _nobody_text(rid: String) -> String:
	var q := Workers.specialist_need("player", rid)
	if not q.is_empty():
		for aid in Workers.workshop_actors():
			if str(aid) != "player" and Workers.profession(str(aid)) == str(q["profession"]):
				var r := Workers.can_do(str(aid), rid)
				return "%s, your %s: %s" % [str(Workers.resolve(str(aid))["name"]), str(q["profession"]) if Workers.PROFESSION.has(str(q["profession"])) else "specialist",
					(r.left(1).to_lower() + r.substr(1)).trim_suffix(".")]
		return "needs %s (%s %d)" % [Workers.a_noun(str(q["profession"])), SkillSys.skill_name(str(q["skill"])), int(q["level"])]
	var why := Crafting.recipe_locked_reason(rid)
	return "not yet: " + (why.left(70) + ("…" if why.length() > 70 else ""))


func _learn(id: String) -> void:
	var why := SkillTree.unlock(id)
	if why != "":
		Events.toast.emit(why, "bad")
		Audio.play("sfx/error")
		return
	canvas.celebrate(id)
	_refresh()


func close() -> void:
	UIRoot.hide_tooltip()
	super.close()


# ======================================================================= legend dot
class LegendDot extends Control:
	var state := ""

	func _init(s: String) -> void:
		state = s
		custom_minimum_size = Vector2(26, 26)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		TreeCanvas.draw_seal(self, Vector2(13, 13), 10.0, state, null, 0.0)


# ======================================================================= the chart
class TreeCanvas extends Control:
	signal focus_changed(id: String)

	const COL_W := 262.0
	const ROW_H := 146.0
	const ORIGIN := Vector2(140, 178)
	const R := 36.0
	const FAR := 1.2          # prerequisites further than this many columns away are drawn as seals

	var zoom := 0.74
	var offset := Vector2(10, 4)
	var selected := ""
	var hovered := ""
	var dragging := false
	var press_pos := Vector2.ZERO
	var pressed := false
	var t := 0.0
	var flash := {}           # node id -> seconds since learned
	var states := {}          # node id -> state, recomputed once per frame

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _ready() -> void:
		if selected != "":
			call_deferred("select", selected)

	func _process(delta: float) -> void:
		t += delta
		for k in flash.keys():
			flash[k] = float(flash[k]) + delta
			if float(flash[k]) > 1.6:
				flash.erase(k)
		queue_redraw()

	# ---------------------------------------------------------------- geometry
	func world(n: Dictionary) -> Vector2:
		return ORIGIN + Vector2(float(n["x"]) * COL_W, float(n["y"]) * ROW_H)

	func scr(w: Vector2) -> Vector2:
		return w * zoom + offset

	func world_size() -> Vector2:
		var maxy := 0.0
		var maxx := 5.0
		for n in SkillTree.nodes():
			maxy = maxf(maxy, float(n["y"]))
		for b in SkillTree.branches():
			maxx = maxf(maxx, float(b["x"]))   # iteration 010: a seventh column (Textiles & Tailoring)
		return Vector2(ORIGIN.x * 2.0 + maxx * COL_W, ORIGIN.y + maxy * ROW_H + 120.0)

	func state_of(id: String) -> String:
		if not states.has(id):
			states[id] = SkillTree.node_state(id)
		return states[id]

	func visible_node(n: Dictionary) -> bool:
		if state_of(n["id"]) != "hidden":
			return true
		for p in n["requires"].get("nodes", []):
			if SkillTree.is_unlocked(str(p)):
				return true
		return false

	func node_at(pos: Vector2) -> String:
		for n in SkillTree.nodes():
			if visible_node(n) and scr(world(n)).distance_to(pos) <= (R + 6.0) * zoom:
				return n["id"]
		return ""

	func reset_view() -> void:
		zoom = clampf(size.x / world_size().x, 0.6, 1.0) if size.x > 0 else 0.8
		offset = Vector2((size.x - world_size().x * zoom) * 0.5, 4)
		queue_redraw()

	func fit_all() -> void:
		var ws := world_size()
		zoom = clampf(minf(size.x / ws.x, size.y / ws.y), 0.3, 1.6)
		offset = (size - ws * zoom) * 0.5
		queue_redraw()

	func select(id: String) -> void:
		selected = id
		var n := SkillTree.node(id)
		if not n.is_empty() and size.x > 0:
			var p := scr(world(n))
			if p.y < 60 or p.y > size.y - 90:
				offset.y += size.y * 0.45 - p.y
			if p.x < 60 or p.x > size.x - 60:
				offset.x += size.x * 0.5 - p.x
			clamp_view()
		focus_changed.emit(id)
		queue_redraw()

	func celebrate(id: String) -> void:
		flash[id] = 0.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and size.x > 0 and not has_meta("viewed"):
			set_meta("viewed", true)
			reset_view()

	# ---------------------------------------------------------------- input
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed:
				var f := 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
				zoom_at(mb.position, f)
				accept_event()
			elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				if mb.pressed:
					pressed = true
					dragging = false
					press_pos = mb.position
				else:
					if pressed and not dragging and mb.button_index == MOUSE_BUTTON_LEFT:
						var id := node_at(mb.position)
						selected = id
						focus_changed.emit(id)
						if id != "":
							Audio.play("sfx/page_turn", -8.0)
					pressed = false
					dragging = false
				accept_event()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if pressed and (dragging or mm.position.distance_to(press_pos) > 5.0):
				dragging = true
				offset += mm.relative
				clamp_view()
				queue_redraw()
			else:
				var h := node_at(mm.position)
				if h != hovered:
					hovered = h
					focus_changed.emit(h if h != "" else selected)
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW

	## Keeps at least part of the chart in view.
	func clamp_view() -> void:
		var ws := world_size() * zoom
		offset.x = clampf(offset.x, minf(0.0, size.x - ws.x) - 200.0, maxf(0.0, size.x - ws.x) + 200.0)
		offset.y = clampf(offset.y, minf(0.0, size.y - ws.y) - 160.0, maxf(0.0, size.y - ws.y) + 160.0)

	func zoom_at(p: Vector2, f: float) -> void:
		var nz := clampf(zoom * f, 0.35, 1.7)
		var w := (p - offset) / zoom
		zoom = nz
		offset = p - w * zoom
		clamp_view()
		queue_redraw()

	# ---------------------------------------------------------------- drawing
	func _draw() -> void:
		states.clear()
		var ws := world_size()
		draw_rect(Rect2(Vector2.ZERO, size), Color("#e9dcc0"))
		# branch columns and header banners
		var fh := Assets.font("title")
		var fb := Assets.font("body_bold")
		var fi := Assets.font("body_italic")
		for b in SkillTree.branches():
			var cx := ORIGIN.x + float(b["x"]) * COL_W
			var col := Color(str(b["colour"]))
			var r := Rect2(scr(Vector2(cx - COL_W * 0.5 + 6, 18)), Vector2(COL_W - 12, ws.y - 30) * zoom)
			draw_rect(r, Color(col, 0.07 if int(b["x"]) % 2 == 0 else 0.04))
			draw_line(scr(Vector2(cx + COL_W * 0.5, 20)), scr(Vector2(cx + COL_W * 0.5, ws.y - 10)), Color(UIKit.INK, 0.12), 1.0)
			_banner(b, cx, fh, fi)
			if str(b["id"]) == "arcane" and not SkillTree.is_unlocked("ar_energy"):
				_sealed_note(cx, fi)
		_bands(fi)
		# prerequisite lines
		for n in SkillTree.nodes():
			if not visible_node(n):
				continue
			var p1 := world(n)
			for pid in n["requires"].get("nodes", []):
				var pn := SkillTree.node(str(pid))
				if pn.is_empty() or not visible_node(pn):
					continue
				if absf(float(pn["x"]) - float(n["x"])) > FAR:
					continue
				_edge(world(pn), p1, SkillTree.is_unlocked(str(pid)), SkillTree.is_unlocked(n["id"]))
		# nodes
		for n in SkillTree.nodes():
			if not visible_node(n):
				continue
			_node(n, fb)

	## B2: the two kinds of branch, named above their columns — YOUR OWN PATH and THE WORKSHOP'S KNOWLEDGE.
	func _bands(fi: Font) -> void:
		var groups := {"smith": [], "workshop": []}
		for b in SkillTree.branches():
			(groups[WorkshopKnowledge.branch_owner(str(b["id"]))] as Array).append(float(b["x"]))
		var fs := int(maxf(9.0, 18.0 * zoom))
		var fbold := Assets.font("body_bold")
		for g in groups:
			var xs: Array = groups[g]
			if xs.is_empty():
				continue
			var x0 := ORIGIN.x + float(xs.min()) * COL_W - COL_W * 0.5 + 14
			var x1 := ORIGIN.x + float(xs.max()) * COL_W + COL_W * 0.5 - 14
			var col := Color("#7e2418") if g == "smith" else Color("#2e4e6e")
			var txt := "YOUR OWN PATH — your own levels" if g == "smith" else "THE WORKSHOP'S KNOWLEDGE — through a competent hand: you at your basic level, or a specialist"
			var a := scr(Vector2(x0, 14))
			var bpt := scr(Vector2(x1, 14))
			var sz := fbold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var mid := (a.x + bpt.x) * 0.5
			draw_line(a, Vector2(mid - sz.x * 0.5 - 8, a.y), Color(col, 0.6), maxf(1.0, 1.6 * zoom))
			draw_line(Vector2(mid + sz.x * 0.5 + 8, a.y), bpt, Color(col, 0.6), maxf(1.0, 1.6 * zoom))
			draw_string(fbold, Vector2(mid - sz.x * 0.5, a.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.darkened(0.15))

	## The arcane branch starts sealed: a large faint padlock and a line of explanation in its empty column.
	func _sealed_note(cx: float, fi: Font) -> void:
		var c := scr(Vector2(cx, ORIGIN.y + ROW_H * 1.6))
		var k := 30.0 * zoom
		var col := Color("#5a3e8a", 0.35)
		draw_arc(c + Vector2(0, -k * 0.7), k * 0.75, PI, TAU, 20, col, 6.0 * zoom, true)
		draw_rect(Rect2(c + Vector2(-k, -k * 0.7), Vector2(k * 2.0, k * 1.7)), col)
		draw_circle(c + Vector2(0, k * 0.1), k * 0.25, Color("#e9dcc0"))
		var fs := int(maxf(8.0, 17.0 * zoom))
		var w := (COL_W - 50) * zoom
		draw_multiline_string(fi, c + Vector2(-w * 0.5, k * 1.6 + fs), "Sealed. Arcane metalwork opens once the workshop knows advanced heat treatment and rune engraving and has handled mithril.",
			HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5, Color("#3e2a5a", 0.8))

	func _banner(b: Dictionary, cx: float, fh: Font, fi: Font) -> void:
		var col := Color(str(b["colour"]))
		var top := scr(Vector2(cx, 34))
		var w := (COL_W - 40) * zoom
		var name: String = b["name"]
		var fs := int(maxf(9.0, 21.0 * zoom))
		var lines := [name]
		if fh.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			var cut := name.find(" & ")
			lines = [name.substr(0, cut + 2), name.substr(cut + 3)] if cut > 0 else [name]
		for i in lines.size():
			var ln: String = lines[i]
			var sz := fh.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(fh, top + Vector2(-sz.x * 0.5, fs * (i + 0.6)), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.darkened(0.35))
		# ornament: rule with a diamond and two curls
		var y := top.y + fs * (lines.size() + 0.35)
		var hw := 110.0 * zoom
		draw_line(Vector2(top.x - hw, y), Vector2(top.x - 10 * zoom, y), Color(UIKit.INK, 0.7), maxf(1.0, 1.6 * zoom))
		draw_line(Vector2(top.x + 10 * zoom, y), Vector2(top.x + hw, y), Color(UIKit.INK, 0.7), maxf(1.0, 1.6 * zoom))
		var d := 7.0 * zoom
		draw_colored_polygon(PackedVector2Array([Vector2(top.x, y - d), Vector2(top.x + d, y), Vector2(top.x, y + d), Vector2(top.x - d, y)]), col)
		draw_arc(Vector2(top.x - hw - 5 * zoom, y), 5 * zoom, PI * 0.5, PI * 2.0, 10, Color(UIKit.INK, 0.7), maxf(1.0, 1.4 * zoom))
		draw_arc(Vector2(top.x + hw + 5 * zoom, y), 5 * zoom, -PI, PI * 0.5, 10, Color(UIKit.INK, 0.7), maxf(1.0, 1.4 * zoom))
		var sk := str(b["skill"])
		var sub := "%s %d · yours" % [SkillSys.skill_name(sk), Game.player_level(sk)]
		if WorkshopKnowledge.branch_owner(str(b["id"])) != "smith":
			var best := Workers.best_level(sk)
			sub = "%s %d · %s" % [SkillSys.skill_name(sk), int(best["level"]), "you" if str(best["actor"]) == "player" else str(best["name"])]
		var fs2 := int(maxf(8.0, 16.0 * zoom))
		var s2 := fi.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		draw_string(fi, Vector2(top.x - s2.x * 0.5, y + fs2 * 1.3), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(UIKit.INK, 0.75))

	func _edge(a: Vector2, b: Vector2, a_known: bool, b_known: bool) -> void:
		var col := Color(UIKit.INK, 0.22)
		var w := 2.0
		if a_known and b_known:
			col = UIKit.GILT
			w = 4.0
		elif a_known:
			col = Color(UIKit.INK, 0.6)
			w = 2.6
		var p0 := a + Vector2(0, R)
		var p3 := b - Vector2(0, R)
		var pts := PackedVector2Array()
		if absf(a.x - b.x) < 4.0:
			pts = PackedVector2Array([scr(p0), scr(p3)])
		else:
			var dy := maxf(30.0, (p3.y - p0.y) * 0.5)
			var c1 := p0 + Vector2(0, dy)
			var c2 := p3 - Vector2(0, dy)
			for i in 25:
				var s := float(i) / 24.0
				var u := 1.0 - s
				pts.append(scr(u * u * u * p0 + 3.0 * u * u * s * c1 + 3.0 * u * s * s * c2 + s * s * s * p3))
		if a_known and b_known:
			draw_polyline(pts, Color(UIKit.INK, 0.55), (w + 2.5) * zoom, true)
		draw_polyline(pts, col, w * zoom, true)

	func _node(n: Dictionary, fb: Font) -> void:
		var id: String = n["id"]
		var st := state_of(id)
		var c := scr(world(n))
		var r := R * zoom
		var tex: Texture2D = null
		if st != "hidden":
			tex = Assets.get_tex(_icon(n))
		var pulse := 0.5 + 0.5 * sin(t * 3.2)
		draw_seal(self, c, r, st, tex, pulse)
		if id == selected or id == hovered:
			draw_arc(c, r + 9 * zoom, 0, TAU, 48, Color(UIKit.RUBRIC, 0.9 if id == selected else 0.5), 2.2 * zoom, true)
		if flash.has(id):
			var k := float(flash[id]) / 1.6
			draw_arc(c, r * (1.0 + k * 1.6), 0, TAU, 48, Color(UIKit.GILT, 1.0 - k), 5.0 * zoom * (1.0 - k) + 1.0, true)
		# far prerequisites: little seals in the branch colour at the medallion's shoulder
		var far := []
		for pid in n["requires"].get("nodes", []):
			var pn := SkillTree.node(str(pid))
			if not pn.is_empty() and absf(float(pn["x"]) - float(n["x"])) > FAR:
				far.append(pn)
		for i in far.size():
			var pn: Dictionary = far[i]
			var bc := Color(str(SkillTree.branch(str(pn["branch"])).get("colour", "#20140c")))
			var sp := c + Vector2(-r - 8 * zoom - i * 26 * zoom, -r * 0.5)
			draw_circle(sp, 12 * zoom, bc if SkillTree.is_unlocked(pn["id"]) else bc.lerp(Color("#cfc5b0"), 0.55))
			draw_arc(sp, 12 * zoom, 0, TAU, 20, UIKit.INK, 1.4 * zoom, true)
			var ini := str(SkillTree.branch(str(pn["branch"])).get("name", "?")).substr(0, 1)
			var fsz := int(maxf(7.0, 15.0 * zoom))
			var isz := fb.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
			draw_string(fb, sp + Vector2(-isz.x * 0.5, fsz * 0.36), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UIKit.PAPER)
		# name (two lines max) and a "ready" note
		if st == "hidden":
			return
		var name: String = str(n["name"])
		var fs := int(maxf(8.0, 19.0 * zoom))
		var lw := 210.0 * zoom
		var col := UIKit.INK if st != "locked" else Color(UIKit.INK, 0.62)
		var nl := 1 if fb.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= lw - 4 else 2
		var tw := minf(lw, fb.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10)
		draw_rect(Rect2(c + Vector2(-tw * 0.5, r + fs * 0.15), Vector2(tw, fs * 1.08 * nl + 4)), Color("#e9dcc0", 0.88))
		draw_multiline_string(fb, c + Vector2(-lw * 0.5, r + fs * 1.15), name, HORIZONTAL_ALIGNMENT_CENTER, lw, fs, 2, col)
		if st == "available":
			var fs3 := int(maxf(7.0, 14.0 * zoom))
			var lines := nl
			var note := "✦ ready to learn"
			var nsz := fb.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3)
			draw_string(fb, c + Vector2(-nsz.x * 0.5, r + fs * 1.15 + fs * lines * 1.05 + 2), note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Color("#9e3a0c"))

	func _icon(n: Dictionary) -> String:
		if n.has("icon") and Assets.has_tex(str(n["icon"])):
			return str(n["icon"])
		var u: Dictionary = n.get("unlocks", {})
		for rid in u.get("recipes", []):
			if SkillTree.recipe_visible(str(rid)):
				var out := str(DB.recipe(str(rid)).get("output", ""))
				return "icons/" + str(DB.item(out).get("icon", out))
		for s in u.get("stations", []):
			return "stations/" + str(s)
		return "icons/star"

	## A medallion: shadow, rim, face, icon and state marks. Shared with the legend.
	static func draw_seal(ci: CanvasItem, c: Vector2, r: float, st: String, tex: Texture2D, pulse: float) -> void:
		var ink := UIKit.INK
		ci.draw_circle(c + Vector2(r * 0.08, r * 0.12), r * 1.02, Color(0, 0, 0, 0.22))
		match st:
			"unlocked":
				ci.draw_circle(c, r, Color("#b8923e"))
				ci.draw_circle(c, r * 0.84, Color("#f1dfa8"))
				ci.draw_circle(c + Vector2(-r * 0.12, -r * 0.14), r * 0.6, Color("#f8ecc6"))
				ci.draw_arc(c, r * 0.84, 0, TAU, 40, Color("#7a5a1e"), maxf(1.0, r * 0.05), true)
			"available":
				ci.draw_circle(c, r * (1.18 + 0.08 * pulse), Color(1.0, 0.62, 0.25, 0.18 + 0.2 * pulse))
				ci.draw_circle(c, r, Color("#f4ead2"))
				ci.draw_arc(c, r * 0.86, 0, TAU, 40, Color(UIKit.RUBRIC, 0.6), maxf(1.0, r * 0.04), true)
				ci.draw_arc(c, r * 1.06, 0, TAU, 48, Color(0.9, 0.45, 0.12, 0.55 + 0.45 * pulse), maxf(1.5, r * 0.09), true)
			"locked":
				ci.draw_circle(c, r, Color("#cfc5b0"))
				ci.draw_arc(c, r * 0.84, 0, TAU, 40, Color(ink, 0.3), maxf(1.0, r * 0.04), true)
			"hidden":
				ci.draw_circle(c, r, Color("#3a2e26"))
				ci.draw_arc(c, r * 0.84, 0, TAU, 40, Color(UIKit.GILT, 0.5), maxf(1.0, r * 0.04), true)
		ci.draw_arc(c, r, 0, TAU, 56, ink, maxf(1.2, r * 0.07), true)
		if tex:
			var s := r * 1.18
			var mod := Color.WHITE
			if st == "locked":
				mod = Color(0.55, 0.52, 0.48, 0.55)
			ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, mod)
		if st == "hidden":
			var f := Assets.font("title")
			var fs := int(maxf(8.0, r * 0.62))
			var sz := f.get_string_size("???", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			ci.draw_string(f, c + Vector2(-sz.x * 0.5, fs * 0.35), "???", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#e8d8b0"))
		if st == "locked":
			# padlock at the lower right
			var p := c + Vector2(r * 0.62, r * 0.58)
			var k := r * 0.26
			ci.draw_arc(p + Vector2(0, -k * 0.55), k * 0.62, PI, TAU, 12, ink, maxf(1.0, k * 0.28), true)
			ci.draw_rect(Rect2(p + Vector2(-k, -k * 0.55), Vector2(k * 2.0, k * 1.6)), Color("#8a8070"))
			ci.draw_rect(Rect2(p + Vector2(-k, -k * 0.55), Vector2(k * 2.0, k * 1.6)), ink, false, maxf(1.0, k * 0.2))
			ci.draw_circle(p + Vector2(0, k * 0.15), k * 0.22, ink)
		if st == "unlocked":
			# a small gilt star on the rim
			var sp := c + Vector2(r * 0.7, -r * 0.7)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var rr := r * (0.2 if i % 2 == 0 else 0.09)
				pts.append(sp + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, Color("#f4d070"))
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, maxf(1.0, r * 0.03), true)
