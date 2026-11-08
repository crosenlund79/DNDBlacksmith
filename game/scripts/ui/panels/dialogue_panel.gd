## DialoguePanel — who you are talking to (an organised villager card), their words and your choices.
## EN: The left card shows portrait, name and role, home and work, standing with the smith as a meter and a
##     word, family, a few recent memories and buttons for their History (and an adventurer's character
##     sheet). Consequences of choices are applied by Talk.
## DA: Venstre kort viser portræt, navn, rolle, hjem og arbejde, forholdet til smeden, familie og minder.
class_name DialoguePanel
extends UIWindow

var npc := ""
var area := ""
var text: RichTextLabel
var opts: VBoxContainer


func _init(id: String, a: String) -> void:
	npc = id
	area = a
	super._init(Talk.npc_name(id), 1420, 640)


func _ready() -> void:
	super._ready()
	var c := DB.character(npc)
	var sub := str(c.get("title", c.get("cls", "")))
	if sub != "":
		title_label.text += "  ·  " + sub
	var h := UIKit.hbox(22)
	h.add_child(info_card(npc))
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = UIKit.rich("", 24)
	v.add_child(text)
	opts = UIKit.vbox(6)
	v.add_child(opts)
	h.add_child(v)
	content.add_child(h)
	text.text = Talk.greeting(npc)
	# a waiting customer states plainly what they want (the same card as at the counter)
	var cu := Shop.customer(npc)
	if not cu.is_empty() and cu.get("present", true):
		var card := CustomerCard.build(Shop.request(cu))
		v.add_child(card)
		v.move_child(card, text.get_index() + 1)
		(func(): ItemStory.at_counter(npc)).call_deferred()   # a piece from your own forge on the counter: "A Familiar Creation"
	_options()


# ======================================================================= the villager card
## A clear, organised card about who you are talking to: portrait, name and role, home and work,
## standing with the smith (a meter and a word, never a number), family, a few recent memories, and
## buttons for their History (and an adventurer's character sheet).
static func info_card(id: String) -> Control:
	var c := DB.character(id)
	var hl := Hire.get_h(id)
	var adv: Dictionary = Adv.get_a(id) if Game.state.has("adventurers") else {}
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.78, 0.92)
	sb.border_color = Color(UIKit.INK, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(430, 0)
	card.name = "VillagerCard"
	var v := UIKit.vbox(6)
	card.add_child(v)
	# portrait + name and role
	var top := UIKit.hbox(12)
	var pid := "portraits/" + id
	if not hl.is_empty():
		pid = "portraits/" + str(hl["look"])
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#20140c")
	fsb.set_content_margin_all(3)
	fsb.border_color = UIKit.GILT
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.add_child(UIKit.portrait(pid, 150))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(frame)
	var nv := UIKit.vbox(2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(Talk.npc_name(id), 28, "heading")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(nm)
	var role := role_of(id)
	if role != "":
		var rl := UIKit.label(role, 19, "body_italic", UIKit.RUBRIC)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(rl)
	if c.has("age"):
		nv.add_child(UIKit.label("Age %s" % str(c["age"]), 17, "body_italic"))
	top.add_child(nv)
	v.add_child(top)
	v.add_child(UIKit.divider())
	# home and work
	var home := str(c.get("home", ""))
	var work := str(c.get("work", ""))
	if not hl.is_empty():
		work = "smithy"
	if home != "":
		v.add_child(_row("ic_home", "Home", place_name(home)))
	if work != "":
		v.add_child(_row("ic_work", "Works at", (place_name(work) + " (home)") if work == home else place_name(work)))
	# standing with the smith: a meter and a word
	if Game.state.has("social"):
		var st := UIKit.hbox(8)
		st.add_child(_ico("ic_standing"))
		st.add_child(UIKit.label("Standing", 19, "body_bold"))
		var bar := UIKit.bar((Social.aff(id) + 100.0) / 200.0, 1.0, 140)
		bar.name = "StandingMeter"
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(140, 14)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(3)
		var band := Social.band(id)
		var cols := {"hostile": Color("#a4341e"), "cool": Color("#9a6a1e"), "neutral": Color("#8a7a5a"),
			"warm": Color("#6a8a3e"), "friendly": Color("#4e7a2e"), "devoted": Color("#b8923e")}
		fill.bg_color = cols.get(band, Color("#8a7a5a"))
		bar.add_theme_stylebox_override("fill", fill)
		st.add_child(bar)
		var word := band.capitalize()
		var rom := Social.romance(id)
		if rom not in ["none", ""]:
			word += " · " + rom.capitalize()
		st.add_child(UIKit.label(word, 18, "body_italic"))
		v.add_child(st)
		var fw := Social.fam(id)
		var know := "A stranger to you"
		if fw >= 60.0:
			know = "Knows you well"
		elif fw >= 25.0:
			know = "Knows you"
		elif fw > 0.0:
			know = "Barely knows you"
		var kl := UIKit.label(know, 16, "body_italic")
		var kh := UIKit.hbox(0)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(36, 0)
		kh.add_child(pad)
		kh.add_child(kl)
		v.add_child(kh)
	# family
	var rel: Array = Social.relatives(id) if Game.state.has("social") else []
	if not rel.is_empty():
		var parts := []
		for r in rel:
			parts.append("%s (%s)" % [Talk.npc_name(str(r)), Social.relation_word(id, str(r))])
		v.add_child(_row("ic_family", "Family", ", ".join(parts)))
	# recent memories, short
	var mems: Array = Social.ensure(id).get("memories", []) if Game.state.has("social") else []
	if not mems.is_empty():
		v.add_child(_row("ic_memory", "Remembers", ""))
		var shown := 0
		for i in range(mems.size() - 1, -1, -1):
			var m: Dictionary = mems[i]
			var t := str(m.get("text", ""))
			if t.length() > 70:
				t = t.substr(0, 68).strip_edges() + "…"
			var w := float(m.get("w", 0.0))
			var col := "#4e6a2e" if w > 0.0 else ("#7e2418" if w < 0.0 else "#20140c")
			var ml := UIKit.rich("[color=%s]•[/color] [i]%s[/i] [color=#7a6a50](day %d)[/color]" % [col, t, int(m.get("day", 0))], 16)
			ml.custom_minimum_size = Vector2(390, 0)
			v.add_child(ml)
			shown += 1
			if shown >= 3:
				break
	# buttons
	var btns := UIKit.hbox(8)
	btns.add_child(InkIcons.button("ic_history", "History", func(): Events.open_panel.emit("history", {"kind": "npc", "id": id}), 0))
	if not adv.is_empty() or str(c.get("kind", "")) == "adventurer":
		btns.add_child(InkIcons.button("ic_sheet", "Character sheet", func(): Events.open_panel.emit("dossier", {"id": id}), 0))
	v.add_child(btns)
	return card


static func role_of(id: String) -> String:
	var hl := Hire.get_h(id)
	if not hl.is_empty():
		return "Your hireling" + ((" — " + str(hl.get("role", ""))) if str(hl.get("role", "")) != "" else "")
	var a: Dictionary = Adv.get_a(id) if Game.state.has("adventurers") else {}
	var c := DB.character(id)
	if not a.is_empty():
		return "%s, level %d — adventurer" % [str(a.get("cls", c.get("cls", ""))), int(a.get("level", 1))]
	return str(c.get("title", c.get("cls", "")))


## A building, area or place id as the village names it.
static func place_name(id: String) -> String:
	match id:
		"harbour":
			return "The harbour"
		"square":
			return "The square"
	for b in DB.layout.get("buildings", []) + DB.layout.get("areas", []):
		if str(b.get("id", "")) == id:
			return str(b.get("name", id))
	return id.capitalize()


static func _ico(icon_id: String) -> Control:
	var r := TextureRect.new()
	r.texture = InkIcons.tex(icon_id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(28, 28)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func _row(icon_id: String, label: String, value: String) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(_ico(icon_id))
	var lab := UIKit.label(label, 19, "body_bold")
	lab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(lab)
	if value != "":
		var l := UIKit.label(value, 19)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
	return row


func _options() -> void:
	UIKit.clear(opts)
	for o in Talk.options(npc, area):
		var oid: String = o["id"]
		var why := str(o.get("disabled", ""))
		# an expected option that is not possible right now stays visible, greyed, with its reason
		var b := UIKit.button("❧ " + o["label"] + (("  — " + why) if why != "" else ""), func(): _choose(oid), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if why != "":
			b.disabled = true
			b.tooltip_text = why[0].to_upper() + why.substr(1) + "."
		opts.add_child(b)


func _choose(oid: String) -> void:
	if oid == "bye":
		close()
		return
	var r := Talk.choose(npc, oid, area)
	var action: String = r.get("action", "")
	if action == "close":
		close()
		return
	if action == "close_later":
		text.text = r.get("text", "")
		UIKit.clear(opts)
		opts.add_child(UIKit.button("❧ Farewell", close, 0))
		return
	if action != "":
		var who := npc
		match action:
			"hirelings": Events.open_panel.emit("hirelings", {})
			"shop": Events.open_panel.emit("shop", {"npc": who})
			"repair":
				ItemSpirit.speak_repair(who)
				var c := Crafting.check_params("grinding_wheel")
				Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Repair at the grinding wheel",
					"on_done": _on_repair_done.bind(who)})
		return
	if r.has("fade"):
		Events.request_fade.emit(r["fade"], int(r.get("minutes", 60)))
	text.text = r.get("text", "")
	_options()


func _on_repair_done(qs: Array, who: String) -> void:
	Shop.do_repair(who, float(qs[0]))
	Events.toast.emit("Repair finished (%d%%)." % int(qs[0]), "good")
	close()
