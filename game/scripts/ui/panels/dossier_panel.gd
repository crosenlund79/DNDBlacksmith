## DossierPanel — the illustrated character sheet of one adventurer (route `dossier` {id}).
## EN: A fixed left column (portrait, class, level, renown, whereabouts) and seven pages:
##     Overview (condition, at a glance, plans), Combat (attributes, skills, to-hit, defence, damage and
##     damage types), Equipment (a paper doll with every slot — the actual item instances with rarity,
##     key stats and durability; hover for the full item and its history), Expedition (now and last),
##     Career (level, renown, ambitions, shopping list and savings), Relationships and History.
##     On Master difficulty numbers you have not earned are approximate (`_know()`): strangers show
##     ranges and gear by kind until familiarity (talk, drinks, equipping them) or rumours reveal more.
## DA: Et illustreret karakterark med syv sider. På Mester-sværhed er ukendte tal omtrentlige.
class_name DossierPanel
extends UIWindow

const TABS := ["Overview", "Combat", "Equipment", "Expedition", "Career", "Relationships", "History"]
const CLASS_ICON := {"Fighter": "ui/cls_fighter", "Ranger": "ui/cls_ranger", "Wizard": "ui/cls_wizard", "Rogue": "ui/cls_rogue",
	"Paladin": "ui/cls_paladin", "Cleric": "ui/cls_cleric", "Barbarian": "ui/cls_barbarian", "Bard": "ui/cls_bard"}
const ATTR := [["str", "Strength", "ui/attr_str"], ["dex", "Dexterity", "ui/attr_dex"], ["int", "Intellect", "ui/attr_int"],
	["wis", "Wisdom", "ui/attr_wis"], ["con", "Constitution", "ui/attr_con"]]
## Paper doll: [slot, column (0 left / 1 right), row, anchor on the 360×560 figure].
const DOLL := [["helmet", 0, 0, Vector2(180, 78)], ["armor", 0, 1, Vector2(180, 210)], ["gloves", 0, 2, Vector2(80, 318)],
	["belt", 0, 3, Vector2(180, 300)], ["boots", 0, 4, Vector2(150, 462)],
	["weapon", 1, 0, Vector2(282, 322)], ["shield", 1, 1, Vector2(262, 236)], ["ring", 1, 2, Vector2(286, 330)],
	["amulet", 1, 3, Vector2(180, 140)], ["companion", 1, 4, Vector2(262, 494)]]
const C_HP := Color("#a8321e")
const C_FAT := Color("#b8862e")
const C_MOR := Color("#3c6e8a")
const C_XP := Color("#b8923e")
const C_GOOD := Color("#4c7a34")

var adv_id := ""
var tab := "Overview"
var page: VBoxContainer
var tab_row: HBoxContainer
var left: VBoxContainer


func _init(id: String, start_tab := "Overview") -> void:
	adv_id = id
	tab = start_tab
	blocks_time = false
	super._init("", 1600, 940, false)
	if Assets.has_tex("ui/dossier"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.get_tex("ui/dossier")
		sb.texture_margin_left = 60
		sb.texture_margin_right = 60
		sb.texture_margin_top = 60
		sb.texture_margin_bottom = 60
		sb.content_margin_left = 48
		sb.content_margin_right = 48
		sb.content_margin_top = 32
		sb.content_margin_bottom = 32
		add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	super._ready()
	var body := UIKit.hbox(26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left = UIKit.vbox(8)
	left.custom_minimum_size = Vector2(300, 0)
	body.add_child(left)
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row = UIKit.hbox(6)
	right.add_child(tab_row)
	right.add_child(UIKit.divider())
	page = UIKit.vbox(10)
	var sc := UIKit.scroll(page, 720)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sc)
	body.add_child(right)
	content.add_child(body)
	for t in TABS:
		var b := UIKit.button(t, select_tab.bind(t))
		b.toggle_mode = true
		b.name = "Tab" + t
		b.add_theme_font_size_override("font_size", 20)
		tab_row.add_child(b)
	_build()
	Events.expeditions_changed.connect(_build)
	Events.adventurers_changed.connect(_build)


func select_tab(t: String) -> void:
	tab = t
	_build()


## How much the smith may know: everything on easier settings; on Master, familiarity decides.
func _know() -> float:
	if bool(Expeditions.diff().get("detail", true)):
		return 100.0
	return Social.fam(adv_id) + (25.0 if Game.has_flag("rumour_" + adv_id) else 0.0)


func _a() -> Dictionary:
	return Adv.get_a(adv_id)


func _build() -> void:
	if not is_inside_tree():
		return
	var a := _a()
	if a.is_empty():
		return
	Expeditions.ensure(a)
	Adv.ensure(a)
	title_label.text = "%s — %s" % [a["name"], Expeditions.renown_title(a)]
	for b in tab_row.get_children():
		(b as Button).set_pressed_no_signal(str(b.name) == "Tab" + tab)
		(b as Button).add_theme_color_override("font_color", UIKit.RUBRIC if str(b.name) == "Tab" + tab else UIKit.INK)
	_build_left(a)
	UIKit.clear(page)
	match tab:
		"Overview": _page_overview(a)
		"Combat": _page_combat(a)
		"Equipment": _page_equipment(a)
		"Expedition": _page_expedition(a)
		"Career": _page_career(a)
		"Relationships": _page_relations(a)
		"History": _page_history(a)


# ======================================================================= left column
func _build_left(a: Dictionary) -> void:
	UIKit.clear(left)
	var k := _know()
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0.13, 0.08, 0.05, 0.10), UIKit.GILT, 3, 6))
	var por := UIKit.portrait("portraits/" + adv_id, 270)
	if a["status"] == "dead":
		por.modulate = Color(0.55, 0.5, 0.48)
	frame.add_child(por)
	left.add_child(frame)
	left.add_child(UIKit.label(a["name"], 34, "title"))
	var cls := UIKit.hbox(8)
	cls.add_child(UIKit.icon(CLASS_ICON.get(a["cls"], "ui/cls_fighter"), 44))
	var lv := str(a["level"]) if k >= 25 else "%d–%d" % [maxi(1, int(a["level"]) - 1), int(a["level"]) + 2]
	cls.add_child(UIKit.label("Level %s %s" % [lv, a["cls"]], 24, "body_bold"))
	left.add_child(cls)
	var rn := UIKit.hbox(8)
	rn.add_child(UIKit.icon("ui/renown", 36))
	rn.add_child(UIKit.label("“%s”" % Expeditions.renown_title(a), 22, "body_italic", UIKit.RUBRIC))
	left.add_child(rn)
	var sw := Expeditions.status_word(a)
	var where := sw
	if a["status"] == "away":
		where += " — " + str(Expeditions.region(str(a.get("dest", ""))).get("name", ""))
	left.add_child(_chip(where, WantedPanel.STATUS_COL.get(sw, UIKit.INK)))
	left.add_child(UIKit.label(Adv.TRAITS.get(a.get("trait", ""), ""), 18, "body_italic"))
	var ex := Expeditions.exp_of(adv_id)
	if not ex.is_empty() and Expeditions.can_observe():
		var eid: String = ex["id"]
		left.add_child(UIKit.button("Watch them live", func(): Events.open_panel.emit("observe", {"id": eid}), 270))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	left.add_child(UIKit.button("◂ All adventurers", func(): Events.open_panel.emit("adventurers", {}), 270))


# ======================================================================= pages
func _page_overview(a: Dictionary) -> void:
	var k := _know()
	var row := UIKit.hbox(30)
	var cond := UIKit.vbox(10)
	cond.custom_minimum_size = Vector2(560, 0)
	cond.add_child(_heading("Condition"))
	if k >= 20.0:
		cond.add_child(_meter("ui/stat_hp", "Health", maxf(0.0, float(a["hp"])), float(a["hp_max"]), C_HP, "%d / %d" % [maxi(0, int(a["hp"])), int(a["hp_max"])]))
		cond.add_child(_meter("ui/stat_fatigue", "Fatigue", float(a["fatigue"]), 100.0, C_FAT, "%d" % int(a["fatigue"])))
		cond.add_child(_meter("ui/stat_morale", "Morale", float(a["morale"]), 100.0, C_MOR, "%d" % int(a["morale"])))
		var inj := "Uninjured"
		if a["status"] == "injured":
			inj = "Injured — resting %d more day%s" % [int(a.get("injured_days", 0)), "" if int(a.get("injured_days", 0)) == 1 else "s"]
		elif float(a["hp"]) < float(a["hp_max"]) * 0.5:
			inj = "Wounded — still mending"
		cond.add_child(UIKit.label(inj, 20, "body_bold", UIKit.RUBRIC if inj != "Uninjured" else C_GOOD))
		cond.add_child(UIKit.label("Carries %d healing draught%s · %d gold in the purse" % [int(a.get("potions", 0)), "" if int(a.get("potions", 0)) == 1 else "s", int(a.get("gold", 0))], 19))
	else:
		cond.add_child(UIKit.label("You don't know them well enough to say how they really are.", 19, "body_italic"))
	row.add_child(cond)
	var glance := UIKit.vbox(10)
	glance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glance.add_child(_heading("At a glance"))
	glance.add_child(_icon_line("ui/stat_damage", "%s %s — %s" % [Adv.rating_text(a), a["cls"], Adv.skills_text(a) if k >= 15.0 else "capabilities hard to judge yet"]))
	var c := Adv.completeness(a)
	glance.add_child(_meter("ui/stat_gear", "Gear", float(c.x), float(c.y), C_GOOD, "%d of %d slots" % [c.x, c.y]))
	var ww := Adv.wear_warnings(a)
	if int(ww["broken"]) + int(ww["worn"]) == 0:
		glance.add_child(_icon_line("ui/stat_defence", "All gear sound"))
	if int(ww["broken"]) > 0:
		glance.add_child(_icon_line("ui/warn_broken", "%d piece%s BROKEN — at half strength" % [int(ww["broken"]), "" if int(ww["broken"]) == 1 else "s"], UIKit.RUBRIC))
	if int(ww["worn"]) > 0:
		glance.add_child(_icon_line("ui/warn_worn", "%d piece%s badly worn" % [int(ww["worn"]), "" if int(ww["worn"]) == 1 else "s"], Color("#8a4a10")))
	var pers: String = DB.character(adv_id).get("personality", "")
	if pers != "":
		glance.add_child(UIKit.label(pers, 19, "body_italic"))
	row.add_child(glance)
	page.add_child(row)
	page.add_child(UIKit.divider())
	page.add_child(_heading("What they want next"))
	_shopping_list(a, 4)
	var amb: Array = a.get("ambitions", [])
	if not amb.is_empty():
		page.add_child(_icon_line("ui/renown", str(amb[0])))


func _page_combat(a: Dictionary) -> void:
	var k := _know()
	page.add_child(_heading("Attributes"))
	var ar := UIKit.hbox(14)
	for at in ATTR:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(0.13, 0.08, 0.05, 0.08), Color(0.13, 0.08, 0.05, 0.45), 2, 8))
		var v := UIKit.vbox(2)
		v.custom_minimum_size = Vector2(170, 0)
		v.add_child(UIKit.icon(at[2], 72))
		var val := ("%+d" % Expeditions.attr(a, at[0])) if k >= 30 else "?"
		var lab := UIKit.label(val, 34, "title")
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
		var nm := UIKit.label("%s · %s" % [str(at[0]).to_upper(), at[1]], 17, "body_bold")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		card.add_child(v)
		ar.add_child(card)
	page.add_child(ar)
	page.add_child(_heading("Skills"))
	var sk := UIKit.hbox(8)
	for s in Expeditions.arch(a).get("skills", []):
		sk.add_child(_chip(str(s).replace("_", " ").capitalize(), Color("#5e421c")))
	page.add_child(sk)
	page.add_child(UIKit.label("Fights best with a %s · role in a party: %s" % [" or ".join(Expeditions.arch(a).get("prefers", [])), Expeditions.role(a)], 19, "body_italic"))
	page.add_child(_heading("In a fight"))
	if k < 30:
		page.add_child(UIKit.label("You can only guess how they fight. Get to know them better.", 20, "body_italic"))
		return
	var wp := Expeditions.weapon_profile(a)
	var w: Dictionary = wp["item"]
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 12)
	g.add_child(_big_stat("ui/stat_tohit", "To-hit", "%+d" % int(wp["to_hit"]), "d20 + main attribute + level/2 + affinity + quality"))
	g.add_child(_big_stat("ui/stat_defence", "Defence", "%d" % Expeditions.defence(a), "10 + dex + protection ×0.25 (protection %d)" % Expeditions.total(a, "protection")))
	g.add_child(_big_stat("ui/stat_damage", "Damage", "%.0f" % float(wp["base"]), "per blow with %s, before damage types" % (Items.display_name(w) if not w.is_empty() else "bare hands")))
	g.add_child(_big_stat("ui/stat_hp", "Health", "%d" % int(a["hp_max"]), "maximum hit points"))
	g.add_child(_big_stat("ui/stat_fire", "Fire", "%d" % Expeditions.total(a, "fire"), "×2 against what fears fire"))
	g.add_child(_big_stat("ui/stat_frost", "Frost", "%d" % Expeditions.total(a, "frost"), "×2 against what fears frost"))
	g.add_child(_big_stat("ui/stat_magic", "Magic", "%d" % Expeditions.total(a, "magic"), "spell damage, healing and arcane blows"))
	g.add_child(_big_stat("ui/stat_ward", "Ward", "%d" % Expeditions.total(a, "ward"), "turns the blows of the dead and spirits"))
	page.add_child(g)
	var notes := []
	if not w.is_empty() and Items.condition(w) < 1.0:
		notes.append("[color=#7e2418]The %s is %s: its attack works at %d%%.[/color]" % [w["name"], "broken" if w.get("broken", false) else "worn", int(Items.condition(w) * 100)])
	if int(wp["aff"]) > 0:
		notes.append("A %s favours the %s (+%d to hit)." % [a["cls"], wp["wtype"], int(wp["aff"])])
	var comp: Dictionary = a["equipment"].get("companion", {})
	if not comp.is_empty():
		var bits := []
		for st in ["attack", "protection", "scouting", "heal", "magic", "carry"]:
			if Items.stat(comp, st) > 0:
				bits.append("%s %d" % [st, Items.stat(comp, st)])
		notes.append("Companion [b]%s[/b]: %s." % [Expeditions.companion_name(comp), ", ".join(bits)])
	if not notes.is_empty():
		page.add_child(UIKit.rich("\n".join(notes), 19))


func _page_equipment(a: Dictionary) -> void:
	var doll := PaperDoll.new(self, a)
	page.add_child(doll)
	page.add_child(UIKit.label("Hover a piece for the full item; click it for its maker, history and owners.  ⚒ = made at your forge.", 18, "body_italic"))
	_equipment_histories(a)
	page.add_child(_heading("Wants & plans"))
	_shopping_list(a, 12)


## What their gear has been through (ItemStory): one line per piece with a story, the richest first.
func _equipment_histories(a: Dictionary) -> void:
	var rows := []
	for s in a.get("equipment", {}):
		var it: Dictionary = a["equipment"][s]
		if it.is_empty() or not Provenance.applies(it):
			continue
		var n := ItemStory.events_of(it).size()
		rows.append([n + (100 if ItemStory.is_named(it) or it.has("epic") else 0), it])
	if rows.is_empty():
		return
	rows.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	page.add_child(_heading("Equipment histories"))
	var k := _know()
	for r in rows:
		var it: Dictionary = r[1]
		var known := k >= 15.0 or Provenance.is_mine(it)
		var row := UIKit.hbox(12)
		var sl := ItemSlot.new(it if known else {}, 56.0)
		row.add_child(sl)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Items.display_name(it) if known else "a %s" % Items.type_label(it).to_lower(), 19, "body_bold", Items.color(it, false)))
		v.add_child(UIKit.rich("[i]%s[/i]" % (ItemStory.summary(it) if known else "You don't know its story yet."), 17))
		row.add_child(v)
		if known:
			var u := int(it["uid"])
			var b := UIKit.button("Its story", func(): Events.open_panel.emit("item", {"uid": u}), 140)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		page.add_child(row)


func _page_expedition(a: Dictionary) -> void:
	var ex := Expeditions.exp_of(adv_id)
	page.add_child(_heading("Now"))
	if ex.is_empty():
		var nd: String = DB.destinations.get(str(a.get("next_dest", "")), {}).get("name", "")
		var t := "%s." % Expeditions.status_word(a)
		if a["status"] == "in_town":
			t += " Next departure planned for day %d%s." % [int(a.get("depart_day", Game.day())), (" — means to head for " + nd) if nd != "" and _know() >= 20 else ""]
		page.add_child(UIKit.label(t, 21))
	else:
		var reg := Expeditions.region(str(ex["dest"]))
		page.add_child(UIKit.rich("[b]%s[/b] in [b]%s[/b] — %s" % [Expeditions.status_word(a), reg.get("name", ""), {"travel_out": "on the road out", "moving": "moving to the next place", "acting": "dealing with what they found", "travel_back": "on the road home"}.get(str(ex["phase"]), "")], 21))
		var route: Array = ex.get("route", [])
		page.add_child(_meter("ui/stat_morale", "Progress", float(ex.get("step", 0)), float(maxi(1, route.size())), C_MOR, "%d of %d places" % [int(ex.get("step", 0)), route.size()]))
		var pr := UIKit.hbox(18)
		for id in ex["party"]:
			pr.add_child(_person(str(id), "leader" if id == ex.get("leader", "") else ""))
		page.add_child(pr)
		if Expeditions.can_observe():
			var lines := []
			for j in (ex["journal"] as Array).slice(maxi(0, ex["journal"].size() - 6)):
				lines.append("[color=#5e421c]%s[/color]  %s" % [j.get("time", ""), j["text"]])
			page.add_child(UIKit.rich("\n".join(lines), 18))
	page.add_child(UIKit.divider())
	page.add_child(_heading("Last expedition"))
	var last := {}
	for e in Expeditions.done():
		if (e["party"] as Array).has(adv_id):
			last = e
			break
	if last.is_empty():
		page.add_child(UIKit.label("No expedition on record yet.", 20, "body_italic"))
		return
	var reg2 := Expeditions.region(str(last["dest"]))
	var won: int = (last.get("encounters", []) as Array).filter(func(r): return r.get("outcome", "") == "victory").size()
	page.add_child(UIKit.rich("[b]%s[/b] — %s · %d fight%s won · %d gold" % [reg2.get("name", ""), (str(last.get("outcome", "")) if str(last.get("outcome", "")) != "" else "returned").capitalize(), won, "" if won == 1 else "s", int(last.get("gold", 0))], 21))
	var lp := UIKit.hbox(18)
	for id in last["party"]:
		lp.add_child(_person(str(id), "leader" if id == last.get("leader", "") else ""))
	page.add_child(lp)
	if str(last.get("summary", "")) != "":
		page.add_child(UIKit.label(str(last["summary"]), 19, "body_italic"))
	var tale: Array = []
	for j in last.get("journal", []):
		if str(j["kind"]) in ["victory", "defeat", "death", "trap", "discovery", "loot", "rescue", "wound", "retreat"]:
			tale.append("• " + str(j["text"]))
	page.add_child(UIKit.rich("\n".join(tale.slice(maxi(0, tale.size() - 6))), 18))
	if Expeditions.can_observe():
		var lid: String = last["id"]
		var rb := UIKit.button("Replay on the Board", func(): Events.open_panel.emit("observe", {"id": lid}), 280)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		page.add_child(rb)


func _page_career(a: Dictionary) -> void:
	var lv := int(a["level"])
	var row := UIKit.hbox(30)
	var l := UIKit.vbox(10)
	l.custom_minimum_size = Vector2(520, 0)
	l.add_child(_heading("Level & renown"))
	l.add_child(_meter("ui/stat_damage", "Level %d" % lv, float(a.get("xp", 0)), float(lv * 100), C_XP, "%d / %d xp" % [int(a.get("xp", 0)), lv * 100]))
	var nxt := 0
	var nxt_name := ""
	for t in Expeditions.cfg().get("renown_titles", []):
		if int(a.get("renown", 0)) < int(t[0]):
			nxt = int(t[0])
			nxt_name = str(t[1])
			break
	l.add_child(_meter("ui/renown", "Renown", float(a.get("renown", 0)), float(maxi(1, nxt if nxt > 0 else int(a.get("renown", 0)))), C_XP,
		("%d / %d — “%s” next" % [int(a.get("renown", 0)), nxt, nxt_name]) if nxt > 0 else "%d — the highest title" % int(a.get("renown", 0))))
	l.add_child(UIKit.rich("%d expeditions · %d won · %d foes felled · %d gold of loot%s" % [int(a.get("expeditions", 0)), int(a.get("victories", 0)), int(a.get("kills", 0)),
		int(a.get("loot_value", 0)), (" · cheated death %d×" % int(a["deaths_cheated"])) if int(a.get("deaths_cheated", 0)) > 0 else ""], 19))
	row.add_child(l)
	var r := UIKit.vbox(8)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_heading("Ambitions"))
	var amb: Array = a.get("ambitions", [])
	if amb.is_empty():
		r.add_child(UIKit.label("Content with what they have, for now.", 19, "body_italic"))
	for t in amb:
		r.add_child(_icon_line("ui/renown", str(t)))
	row.add_child(r)
	page.add_child(row)
	var sv: Dictionary = a.get("saving_for", {})
	if not sv.is_empty():
		page.add_child(_meter("icons/gold", "Savings", float(a.get("gold", 0)), float(maxi(1, int(sv["goal"]))), C_XP,
			"%d / %d g for %s" % [int(a.get("gold", 0)), int(sv["goal"]), Shop.slot_phrase(str(sv["slot"]))]))
	page.add_child(_heading("Shopping list"))
	_shopping_list(a, 12)
	var ach: Array = a.get("achievements", [])
	if not ach.is_empty():
		page.add_child(_heading("Deeds"))
		page.add_child(UIKit.rich("\n".join(ach.slice(maxi(0, ach.size() - 6)).map(func(x): return "• Day %d — %s" % [int(x["day"]), x["text"]])), 18))


func _page_relations(a: Dictionary) -> void:
	page.add_child(_heading("With the smith"))
	var att: String = {"hostile": "resents you", "cool": "is cool towards you", "neutral": "knows you by sight", "warm": "likes you", "friendly": "counts you a friend", "devoted": "would walk through fire for you"}.get(Social.band(adv_id), "")
	var rom := Social.romance(adv_id)
	var sm := UIKit.hbox(14)
	sm.add_child(UIKit.portrait("portraits/player", 72) if Assets.has_tex("portraits/player") else UIKit.icon("ui/stat_hp", 56))
	sm.add_child(_wide_rich("%s [b]%s[/b]%s" % [a["name"], att, {"dating": " · you've been sharing drinks", "courting": " · you are courting", "married": " · [color=#7e2418]your wife[/color]", "widowed": " · [color=#7e2418]your late wife[/color]"}.get(rom, "")], 21))
	page.add_child(sm)
	var mem := Social.strongest_memory(adv_id)
	if not mem.is_empty():
		page.add_child(UIKit.label("They remember: “%s”" % str(mem.get("text", "")), 19, "body_italic"))
	var fam := Social.relatives(adv_id)
	if not fam.is_empty():
		page.add_child(_heading("Family"))
		var fr := UIKit.hbox(18)
		for r in fam:
			fr.add_child(_person(str(r), Social.relation_word(adv_id, str(r))))
		page.add_child(fr)
	var friends := []
	var rivals := []
	var known := []
	for oid in a.get("relations", {}):
		var v := float(a["relations"][oid])
		if Adv.get_a(oid).is_empty():
			continue
		if v >= 20.0:
			friends.append([oid, v])
		elif v <= -20.0:
			rivals.append([oid, v])
		elif v != 0.0:
			known.append([oid, v])
	friends.sort_custom(func(x, y): return float(x[1]) > float(y[1]))
	rivals.sort_custom(func(x, y): return float(x[1]) < float(y[1]))
	for grp in [["Friends", friends, C_GOOD], ["Rivals", rivals, UIKit.RUBRIC], ["Acquaintances", known, Color("#8a7a60")]]:
		if grp[0] == "Acquaintances" and (grp[1] as Array).is_empty():
			continue
		page.add_child(_heading(grp[0]))
		if (grp[1] as Array).is_empty():
			page.add_child(UIKit.label("—", 19))
			continue
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 24)
		for p in grp[1]:
			var h := UIKit.hbox(10)
			h.add_child(UIKit.portrait("portraits/" + str(p[0]), 64))
			var v2 := UIKit.vbox(2)
			v2.add_child(UIKit.label(Adv.get_a(str(p[0]))["name"], 20, "body_bold"))
			v2.add_child(_bar(absf(float(p[1])), 100.0, grp[2], 180))
			h.add_child(v2)
			g.add_child(h)
		page.add_child(g)


func _page_history(a: Dictionary) -> void:
	var hb := UIKit.hbox(12)
	hb.add_child(_heading("History"))
	var ob := UIKit.button("Open full history", func(): Events.open_panel.emit("history", {"kind": "npc", "id": adv_id}), 240)
	ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ob)
	page.add_child(hb)
	var rows := []
	for e in Chronicle.about(adv_id):
		if str(e["kind"]) == "gear":
			continue   # the gear log below has every one of them
		rows.append([int(e["t"]), int(e["day"]), str(e["kind"]), str(e["text"])])
	for g in a.get("gear_log", []):
		rows.append([int(g["day"]) * 1440, int(g["day"]), "gear", str(g["text"])])
	rows.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	var lines := []
	for r in rows.slice(0, 28):
		var col: String = {"death": "#7e2418", "victory": "#26622f", "gear": "#735800", "levelup": "#24409a", "renown": "#9e3a0c", "chain": "#8a4a10"}.get(r[2], "#5e421c")
		lines.append("[color=#8a7a60]Day %d[/color]  [color=%s][b]%s[/b][/color]  %s" % [r[1], col, str(r[2]).capitalize(), r[3]])
	page.add_child(UIKit.rich("\n".join(lines) if not lines.is_empty() else "[i]Nothing written about them yet.[/i]", 18))
	var hist: Array = a.get("history", [])
	if not hist.is_empty():
		page.add_child(_heading("Expedition log"))
		var el := []
		for h in hist:
			el.append("Day %d — %s: %s%s" % [int(h["day"]), DB.destinations.get(str(h.get("dest", "")), {}).get("name", str(h.get("dest", ""))),
				str(h.get("outcome", "")).replace("_", " "), (" (%d of %d fights)" % [int(h["wins"]), int(h["fought"])]) if h.has("fought") else ""])
		el.reverse()
		page.add_child(UIKit.rich("\n".join(el), 18))


# ======================================================================= pieces
func _shopping_list(a: Dictionary, n: int) -> void:
	var list: Array = a.get("shopping", [])
	if list.is_empty():
		page.add_child(_icon_line("ui/stat_gear", "Happy with their gear for now."))
		return
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 6)
	for e in list.slice(0, n):
		var icon := "ui/warn_broken" if e["why"] == "broken" else ("ui/warn_worn" if e["why"] == "worn" else ("ui/slot_companion" if e["slot"] == "companion" else "ui/stat_gear"))
		var col: Color = UIKit.RUBRIC if e["why"] == "broken" else UIKit.INK
		var txt := "[b]%s[/b] — %s; %s" % [Adv._slot_name(str(e["slot"])), Adv.WHY_WORD.get(e["why"], e["why"]), Adv.PLAN_WORD.get(e["plan"], e["plan"])]
		if str(e.get("note", "")) != "":
			txt += " [color=#5e421c][i](%s)[/i][/color]" % e["note"]
		var h := UIKit.hbox(8)
		h.add_child(UIKit.icon(icon, 34))
		var r := UIKit.rich("[color=#%s]%s[/color]" % [col.to_html(false), txt], 18)
		r.custom_minimum_size = Vector2(520, 0)
		h.add_child(r)
		g.add_child(h)
	page.add_child(g)


func _wide_rich(t: String, sz: int) -> RichTextLabel:
	var r := UIKit.rich(t, sz)
	r.custom_minimum_size = Vector2(900, 0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _heading(t: String) -> Label:
	return UIKit.label(t, 28, "heading")


func _box(bg: Color, border: Color, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _chip(t: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(col, 0.14), col, 2, 12))
	p.add_child(UIKit.label(t, 19, "body_bold", col))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


static func _bar(v: float, mx: float, col: Color, w := 220.0, h := 16.0) -> ProgressBar:
	var p := UIKit.bar(v, maxf(mx, 0.001), w)
	p.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.08, 0.05, 0.18)
	bg.border_color = Color(0.13, 0.08, 0.05, 0.7)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(4)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


func _meter(icon: String, label: String, v: float, mx: float, col: Color, txt: String) -> HBoxContainer:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.icon(icon, 40))
	var l := UIKit.label(label, 20, "body_bold")
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var b := _bar(v, mx, col, 240, 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	h.add_child(UIKit.label(txt, 19))
	return h


func _icon_line(icon: String, text: String, col := UIKit.INK) -> HBoxContainer:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.icon(icon, 36))
	var l := UIKit.label(text, 20, "body", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


func _big_stat(icon: String, nm: String, val: String, hint: String) -> HBoxContainer:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.icon(icon, 60))
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(nm, 18, "body_bold", Color("#5e421c")))
	v.add_child(UIKit.label(val, 32, "title"))
	h.add_child(v)
	h.tooltip_text = hint
	h.custom_minimum_size = Vector2(240, 0)
	return h


func _person(id: String, sub: String) -> VBoxContainer:
	var v := UIKit.vbox(2)
	var p := UIKit.portrait("portraits/" + id, 84)
	v.add_child(p)
	var o := Adv.get_a(id)
	v.add_child(UIKit.label(o.get("name", DB.character(id).get("name", id)), 18, "body_bold"))
	if not o.is_empty() and o.has("hp_max"):
		v.add_child(_bar(maxf(0.0, float(o["hp"])), float(o["hp_max"]), C_HP, 84, 8))
	if sub != "":
		v.add_child(UIKit.label(sub, 15, "body_italic"))
	if not o.is_empty() and id != adv_id:
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				Events.open_panel.emit("dossier", {"id": id}))
	return v


# ======================================================================= the paper doll
## The equipment page: the figure in the middle, every slot as a card on either side with a leader
## line to where it is worn. Cards show the real item (rarity border), its key stats and durability.
class PaperDoll extends Control:
	const CARD := Vector2(360, 104)
	const DOLL_POS := Vector2(400, 0)
	const DOLL_SIZE := Vector2(330, 513)
	var sheet: DossierPanel
	var a: Dictionary
	var anchors := []   # [card point, doll point]

	func _init(s: DossierPanel, adv: Dictionary) -> void:
		sheet = s
		a = adv
		var slots: Array = DossierPanel.DOLL.duplicate(true)
		var rows := [5, 5]
		for extra in Adv.all_slots():
			var known := false
			for d in slots:
				if d[0] == extra:
					known = true
			if not known:
				var col := 0 if rows[0] <= rows[1] else 1
				slots.append([extra, col, rows[col], Vector2(180, 260)])
				rows[col] += 1
		custom_minimum_size = Vector2(1140, maxf(DOLL_SIZE.y + 20, maxi(rows[0], rows[1]) * (CARD.y + 8)))
		var tr := TextureRect.new()
		tr.texture = Assets.get_tex("ui/paperdoll")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = DOLL_POS
		tr.size = DOLL_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		for d in slots:
			var x := 0.0 if int(d[1]) == 0 else DOLL_POS.x + DOLL_SIZE.x + 40.0
			var pos := Vector2(x, int(d[2]) * (CARD.y + 8))
			var card := _card(str(d[0]))
			card.position = pos
			add_child(card)
			var anc: Vector2 = d[3]
			var dp: Vector2 = DOLL_POS + anc * (DOLL_SIZE.x / 360.0)
			var cp := pos + Vector2(CARD.x if int(d[1]) == 0 else 0.0, CARD.y * 0.5)
			anchors.append([cp, dp, not a["equipment"].get(d[0], {}).is_empty()])

	func _draw() -> void:
		for an in anchors:
			var c := Color(0.13, 0.08, 0.05, 0.55) if an[2] else Color(0.13, 0.08, 0.05, 0.18)
			draw_line(an[0], an[1], c, 2.0, true)
			draw_circle(an[1], 5.0, Color("#7e2418") if an[2] else Color(0.13, 0.08, 0.05, 0.25))

	func _card(slot: String) -> Control:
		var it: Dictionary = a["equipment"].get(slot, {})
		var k := sheet._know()
		var mine := str(it.get("crafted_by", "")).begins_with("Brannoc")
		var p := PanelContainer.new()
		p.custom_minimum_size = CARD
		p.size = CARD
		var border: Color = Items.COL_BORDER.get(it.get("rarity", "common"), Color("#6e6250")) if not it.is_empty() else Color(0.13, 0.08, 0.05, 0.3)
		if it.get("broken", false):
			border = Color("#7e2418")
		p.add_theme_stylebox_override("panel", sheet._box(Color(0.94, 0.89, 0.78, 0.55) if not it.is_empty() else Color(0.13, 0.08, 0.05, 0.05), border, 2, 6))
		var h := UIKit.hbox(10)
		var known := k >= 15.0 or mine or it.is_empty()
		var slot_ui := ItemSlot.new(it if known else {}, 84.0)
		if known and not it.is_empty() and Provenance.applies(it):
			var iu := int(it.get("uid", -1))
			slot_ui.clicked.connect(func(_x): Events.open_panel.emit("item", {"uid": iu}))
		h.add_child(slot_ui)
		if it.is_empty():
			var ghost := TextureRect.new()
			ghost.texture = Assets.get_tex(_ghost(slot))
			ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ghost.modulate = Color(1, 1, 1, 0.22)
			ghost.size = Vector2(64, 64)
			ghost.position = Vector2(10, 10)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_ui.add_child(ghost)
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Adv._slot_name(slot).to_upper(), 14, "body_bold", Color("#8a7a60")))
		if it.is_empty():
			var wanted := false
			for e in a.get("shopping", []):
				if e["slot"] == slot:
					wanted = true
			v.add_child(UIKit.label("— empty —" + ("  (wanted)" if wanted else ""), 18, "body_italic", Color("#8a7a60")))
		elif not known:
			v.add_child(UIKit.label("a %s" % Items.type_label(it).to_lower(), 19, "body_italic"))
		else:
			var nm := Items.display_name(it)
			if nm.length() > 26:
				nm = nm.left(25) + "…"
			v.add_child(UIKit.label(nm + (" ⚒" if mine else ""), 19, "body_bold", Items.color(it, false)))
			v.add_child(UIKit.label(_key_stats(it), 16))
			var st: Dictionary = it.get("stats", {})
			if st.has("durability_max"):
				var dh := UIKit.hbox(6)
				var f := Items.durability_frac(it)
				var col := Color("#4c7a34") if f >= 0.5 else (Color("#b8862e") if f >= 0.25 else Color("#a8321e"))
				var b := DossierPanel._bar(float(st["durability"]), float(st["durability_max"]), col, 130, 10)
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				dh.add_child(b)
				if it.get("broken", false):
					dh.add_child(UIKit.label("BROKEN", 17, "body_bold", Color("#7e2418")))
				else:
					dh.add_child(UIKit.label("%d/%d" % [int(st["durability"]), int(st["durability_max"])], 15, "body", col.darkened(0.2)))
				v.add_child(dh)
		h.add_child(v)
		p.add_child(h)
		if it.get("broken", false):
			_overlay(slot_ui, "ui/warn_broken", Vector2(46, 2), 36.0, 1.0)
		elif not it.is_empty() and not Assets.has_tex(Items.icon_id(it)) and slot == "companion":
			_overlay(slot_ui, "ui/slot_companion", Vector2(12, 12), 60.0, 0.9)
		return p

	func _overlay(host: Control, tex: String, pos: Vector2, sz: float, alpha: float) -> void:
		var t := TextureRect.new()
		t.texture = Assets.get_tex(tex)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position = pos
		t.size = Vector2(sz, sz)
		t.modulate = Color(1, 1, 1, alpha)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(t)

	func _ghost(slot: String) -> String:
		var ex: String = {"weapon": "icons/sword_iron", "shield": "icons/shield_round", "armor": "icons/jerkin_leather", "helmet": "icons/helm_iron",
			"gloves": "icons/gloves_leather", "boots": "icons/boots_leather", "belt": "icons/belt_leather", "ring": "icons/ring_silver",
			"amulet": "icons/amulet_silver", "companion": "ui/slot_companion"}.get(slot, "ui/stat_gear")
		return ex

	func _key_stats(it: Dictionary) -> String:
		var bits := []
		for k in [["attack", "Atk"], ["protection", "Prot"], ["magic", "Mag"], ["fire", "Fire"], ["frost", "Frost"], ["ward", "Ward"],
				["scouting", "Scout"], ["heal", "Heal"], ["carry", "Carry"], ["speed", "Spd"], ["vitality", "Vit"]]:
			var v := Items.stat(it, k[0])
			if v != 0:
				bits.append("%s %d" % [k[1], v])
			if bits.size() >= 4:
				break
		return " · ".join(bits) if not bits.is_empty() else Items.type_label(it)
