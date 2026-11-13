## WorldMapPanel — the parchment map of the land around Brindlewick, as the adventurers have made it known.
## EN: Brindlewick in the middle, the old roads, every discovered site with its icon (cleared sites wear a gilt
##     laurel, threatened ones a red ring, recent notable events small wax seals), fog over places nobody has
##     found yet, and the parties on the road or at a site as pennants with their leader's name. Click a site
##     for its page: description, danger and status, conditions, who lives there, what can be found, resources,
##     lost equipment known to lie there, who is there now (with a link to the expedition's observer) and its
##     history — the Lore events placed there. Everything is read from WorldSites / Lore / Expeditions.
## DA: Verdenskortet: opdagede steder, tåge over det ukendte, grupper på vejen, segl for nylige begivenheder;
##     klik et sted for dets side med tilstand, beboere, fund, tabt udstyr, hvem der er der nu og historik.
class_name WorldMapPanel
extends UIWindow

const MAP_SIZE := Vector2(1600, 1000)
## History icons by event kind, used when the event's own icon is not drawn (yet).
const KIND_ICON := {"slew": "icons/sword_iron", "battle": "icons/sword_iron", "survived": "icons/shield_round", "death": "icons/flowers_remembrance",
	"lost": "icons/flowers_remembrance", "discovery": "icons/relic_map", "found": "icons/chest_recovered", "recovered": "icons/chest_recovered",
	"threat": "icons/relic_idol", "arrived": "icons/bag_traveller", "inherited": "icons/chest_recovered", "given": "icons/gold"}

var view: WorldView
var side: VBoxContainer
var selected := ""
var _acc := 0.0
var _sig := ""


func _init(args := {}) -> void:
	selected = str(args.get("site", ""))
	blocks_time = false   # the world keeps moving while the smith looks at the map
	super._init("The Lands about Brindlewick", 1800, 990)


func _ready() -> void:
	super._ready()
	var row := UIKit.hbox(16)
	view = WorldView.new()
	view.custom_minimum_size = Vector2(1216, 760)
	view.panel = self
	row.add_child(view)
	side = UIKit.vbox(6)
	side.custom_minimum_size = Vector2(520, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	content.add_child(row)
	content.add_child(UIKit.label("Click a place for its page. The adventurers find new places; you hear of others by rumour. [%s] opens this map." % Settings.key_label("panel_world_map"), 17, "body_italic"))
	_fill_side()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		var sig := "%s|%d|%d|%d" % [selected, Expeditions.active().size(), (Lore.st()["order"] as Array).size(), WorldSites.discovered_ids().size()]
		if sig != _sig:
			_fill_side()


func select(id: String) -> void:
	selected = id
	_fill_side()
	view.queue_redraw()


# ======================================================================= the side page
func _fill_side() -> void:
	if side == null:
		return
	_sig = "%s|%d|%d|%d" % [selected, Expeditions.active().size(), (Lore.st()["order"] as Array).size(), WorldSites.discovered_ids().size()]
	UIKit.clear(side)
	if selected == "" or not WorldSites.cfg().has(selected):
		_overview()
	else:
		_site_page(selected)


func _overview() -> void:
	side.add_child(UIKit.label("Known places", 28, "heading"))
	var box := UIKit.vbox(4)
	for id in WorldSites.ids():
		var sid := str(id)
		if not WorldSites.is_discovered(sid):
			continue
		var h := UIKit.hbox(8)
		h.add_child(UIKit.icon("ui/world/site_" + WorldSites.icon_of(sid), 44))
		var b := UIKit.button(WorldSites.name_of(sid), func(): select(sid), 230)
		h.add_child(b)
		h.add_child(UIKit.rich("[i]%s · %s[/i]" % [WorldSites.status_word(sid), WorldSites.danger_word(sid)], 17))
		box.add_child(h)
	var unknown := WorldSites.ids().filter(func(i): return not WorldSites.is_discovered(str(i))).size()
	if unknown > 0:
		box.add_child(UIKit.label("%d place%s still lie in the fog." % [unknown, "" if unknown == 1 else "s"], 18, "body_italic"))
	side.add_child(UIKit.scroll(box, 330))
	side.add_child(UIKit.divider())
	side.add_child(UIKit.label("On the road", 24, "heading"))
	var rb := UIKit.vbox(3)
	if Expeditions.active().is_empty():
		rb.add_child(UIKit.label("No party is out right now.", 18, "body_italic"))
	for e in Expeditions.active().values():
		rb.add_child(_party_row(e))
	side.add_child(UIKit.scroll(rb, 170))
	side.add_child(UIKit.divider())
	var recent := []
	for id in WorldSites.ids():
		for ev in WorldSites.recent_seals(str(id), 14):
			recent.append(ev)
	recent.sort_custom(func(a, b): return int(a["t"]) > int(b["t"]))
	side.add_child(UIKit.label("Lately", 24, "heading"))
	var lb := UIKit.vbox(2)
	for ev in recent.slice(0, 6):
		lb.add_child(UIKit.rich("[color=#7e2418]Day %d[/color] — %s" % [int(ev["day"]), str(ev["text"])], 16))
	if recent.is_empty():
		lb.add_child(UIKit.label("Nothing of note in the last fortnight.", 17, "body_italic"))
	side.add_child(UIKit.scroll(lb, 150))


func _party_row(e: Dictionary) -> Control:
	var h := UIKit.hbox(6)
	var lead := Adv.get_a(str(e["leader"]))
	h.add_child(UIKit.portrait("portraits/" + str(e["leader"]), 40))
	var phase: String = {"travel_out": "on the road to", "moving": "exploring", "acting": "at work in", "travel_back": "coming home from"}.get(str(e["phase"]), "at")
	var others := (e["party"] as Array).size() - 1
	var r := UIKit.rich("[b]%s[/b]%s — %s %s" % [lead.get("name", "?"), (" + %d" % others) if others > 0 else "", phase, WorldSites.name_of(str(e["dest"]))], 17)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(r)
	if Expeditions.can_observe():
		var eid := str(e["id"])
		h.add_child(UIKit.button("Observe", func(): Events.open_panel.emit("observe", {"id": eid}), 110))
	return h


func _site_page(id: String) -> void:
	var s := WorldSites.site(id)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.button("◀ All places", func(): select(""), 150))
	head.add_child(UIKit.label(WorldSites.name_of(id), 30, "heading"))
	side.add_child(head)
	var page := UIKit.vbox(6)
	if not WorldSites.is_discovered(id):
		page.add_child(UIKit.label("Nobody in Brindlewick knows this place yet. Adventurers exploring nearby may find it — or a rumour may reach the Wyvern.", 19, "body_italic"))
		side.add_child(page)
		return
	var tw: String = WorldSites.TYPE_WORD.get(WorldSites.type_of(id), "Place")
	var st := WorldSites.status_word(id)
	var stc: String = {"cleared": "#26622f", "threatened": "#7e2418", "reoccupied": "#9e3a0c"}.get(st, "#5e421c")
	var found := ""
	if str(s.get("found_how", "")) == "rumour":
		found = " · heard of by rumour on day %d" % int(s["found_day"])
	elif str(s.get("found_how", "")) == "explored" and not (s.get("found_by", []) as Array).is_empty():
		found = " · found by %s on day %d" % [WorldSites._names(s["found_by"]), int(s["found_day"])]
	page.add_child(UIKit.rich("[i]%s[/i]%s\n%s" % [tw, found, str(WorldSites.info(id).get("desc", ""))], 18))
	page.add_child(UIKit.rich("Danger: [b]%s[/b] (%.0f)   ·   Status: [b][color=%s]%s[/color][/b]   ·   Expeditions: %d" % [WorldSites.danger_word(id), WorldSites.danger(id), stc, st.capitalize(), int(s["visits"])], 18))
	var conds := WorldSites.conditions(id)
	for c in conds:
		page.add_child(UIKit.rich("[color=#7e2418]•[/color] [i]%s[/i]" % str(c), 17))
	# who is there now
	var here := WorldSites.activity(id)
	page.add_child(_heading("Who is there now"))
	if here.is_empty():
		page.add_child(UIKit.label("No party at present.", 17, "body_italic"))
	for e in here:
		page.add_child(_party_row(e))
	# inhabitants
	page.add_child(_heading("Inhabitants and threats"))
	var inh := []
	for x in WorldSites.inhabitants(id):
		inh.append("%s%s%s" % ["[color=#7e2418]☠ [/color]" if bool(x["boss"]) else "", ("[b]%s[/b]" % x["name"]) if bool(x["boss"]) else str(x["name"]),
			(" [i](fears %s)[/i]" % x["weak"]) if str(x["weak"]) != "" else ""])
	if not bool(s["boss"]["alive"]):
		inh.append("[color=#26622f]✓[/color] [s]%s[/s] — slain" % str((s["boss"]["slain"] as Array)[-1].get("name", "")) if not (s["boss"]["slain"] as Array).is_empty() else "")
	inh.append("[i]Also: %s[/i]" % ", ".join(WorldSites.info(id).get("folk", [])))
	page.add_child(UIKit.rich("\n".join(inh), 17))
	# resources
	page.add_child(_heading("Resources"))
	var rr := []
	for nid in s["resources"]:
		var n := Expeditions.node_of(id, str(nid))
		if str(n.get("kind", "")) == "boss":
			continue
		var v := float(s["resources"][nid])
		var word := "rich" if v >= 0.75 else ("fair" if v >= 0.4 else ("thin" if v >= 0.15 else "exhausted"))
		rr.append("%s — [b]%s[/b] (%d%%)" % [n.get("name", nid), word, int(v * 100)])
	page.add_child(UIKit.rich("\n".join(rr) if not rr.is_empty() else "[i]Nothing to gather.[/i]", 17))
	# finds
	var fd := WorldSites.finds(id)
	page.add_child(_heading("To be found there"))
	var fl := []
	if not (fd["materials"] as Array).is_empty():
		fl.append("Materials: " + ", ".join((fd["materials"] as Array).slice(0, 8)))
	if not (fd["relics"] as Array).is_empty():
		fl.append("Relics: " + ", ".join(fd["relics"]))
	if bool(fd["equipment"]):
		fl.append("Old arms and armour")
	if not (fd["creatures"] as Array).is_empty():
		fl.append("Creatures: " + ", ".join(fd["creatures"]))
	if not (fd["commissions"] as Array).is_empty():
		fl.append("Brings commissions for " + ", ".join(fd["commissions"]))
	page.add_child(UIKit.rich("\n".join(fl), 17))
	# lost equipment
	var lost := WorldSites.lost(id)
	if not lost.is_empty():
		page.add_child(_heading("Lost equipment known to lie here"))
		for x in lost:
			var it: Dictionary = x["item"]
			var h := UIKit.hbox(6)
			h.add_child(ItemSlot.new(it, 44))
			var lr := UIKit.rich("[b]%s[/b] — %s's, lost at %s on day %d%s" % [Items.display_name(it), x.get("owner_name", "?"), Expeditions.node_of(id, str(x.get("node", ""))).get("name", "?"),
				int(x.get("day", 0)), " · [color=#735800]Ironhand work[/color]" if Provenance.is_mine(it) else ""], 16)
			lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lr)
			page.add_child(h)
	# history: the Lore events placed here
	page.add_child(_heading("History"))
	var evs := WorldSites.events(id)
	evs.reverse()
	if evs.is_empty():
		page.add_child(UIKit.label("Nothing of note has happened here yet.", 17, "body_italic"))
	for ev in evs.slice(0, 24):
		var eh := UIKit.hbox(6)
		var ic := str(ev.get("icon", ""))
		if not Assets.has_tex(ic):
			ic = str(KIND_ICON.get(str(ev.get("kind", "")), "icons/recipe_scroll"))
		eh.add_child(UIKit.icon(ic, 28))
		var col := "#7e2418" if int(ev.get("importance", 1)) >= 2 else "#5e421c"
		var et := UIKit.rich("[color=%s]Day %d[/color] — %s" % [col, int(ev["day"]), str(ev["text"])], 16)
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eh.add_child(et)
		page.add_child(eh)
	side.add_child(UIKit.scroll(page, 820))


func _heading(t: String) -> Control:
	return UIKit.label(t, 22, "heading", UIKit.RUBRIC)


# ======================================================================= the map
class WorldView extends Control:
	var panel: WorldMapPanel
	var hover := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(_d: float) -> void:
		queue_redraw()

	func _k() -> float:
		return size.x / 1600.0

	func _to(p: Vector2) -> Vector2:
		return p * _k()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			hover = _site_at(ev.position)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var id := _site_at(ev.position)
			panel.select(id)
			accept_event()

	func _site_at(p: Vector2) -> String:
		var best := ""
		var bd := 60.0 * _k() + 10.0
		for id in WorldSites.ids():
			var d := _to(WorldSites.world_pos(str(id))).distance_to(p)
			if d < bd:
				bd = d
				best = str(id)
		return best

	## Where a party is now: on the road out or home, or at the site.
	static func party_pos(e: Dictionary) -> Vector2:
		var site := WorldSites.world_pos(str(e["dest"]))
		var vil := Vector2(800, 520)
		var leg: Dictionary = e.get("leg", {})
		var f := clampf((float(Game.now()) - float(leg.get("t0", 0))) / maxf(1.0, float(leg.get("t1", 1)) - float(leg.get("t0", 0))), 0.0, 1.0)
		if not Expeditions.can_observe():
			f = 0.5
		match str(e.get("phase", "")):
			"travel_out":
				return vil.lerp(site, f)
			"travel_back":
				return site.lerp(vil, f)
		return site

	func _draw() -> void:
		var k := _k()
		var map_tex := Assets.get_tex("ui/maps/world_map", Vector2i(1600, 1000))
		draw_texture_rect(map_tex, Rect2(Vector2.ZERO, size), false)
		var ink := Color("#20140c")
		var f := Assets.font("heading")
		var fb := Assets.font("body")
		# tracks to places found later (the old roads are on the map itself)
		for id in WorldSites.ids():
			var sid := str(id)
			if not WorldSites.is_discovered(sid) or WorldSites.info(sid).get("known", false):
				continue
			var near: Array = WorldSites.info(sid).get("near", [])
			var from := "ironroot_mine" if near.is_empty() else str(near[0])
			draw_dashed_line(_to(WorldSites.world_pos(from)), _to(WorldSites.world_pos(sid)), Color(0.36, 0.22, 0.1, 0.75), 3.0, 9.0)
		# places
		for id in WorldSites.ids():
			var sid := str(id)
			var p := _to(WorldSites.world_pos(sid))
			if not WorldSites.is_discovered(sid):
				var fog := Assets.get_tex("ui/world/fog", Vector2i(220, 150))
				draw_texture_rect(fog, Rect2(p - Vector2(110, 80) * k * 1.1, Vector2(220, 150) * k * 1.1), false, Color(1, 1, 1, 0.92))
				draw_string(fb, p + Vector2(-80, 6), "Unknown", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color(ink, 0.55))
				continue
			var st := WorldSites.status_word(sid)
			var sel := panel != null and panel.selected == sid
			if sel or hover == sid:
				draw_circle(p + Vector2(0, -16) * k, 70.0 * k, Color(1.0, 0.9, 0.6, 0.35 if sel else 0.2))
			if st == "threatened":
				draw_arc(p + Vector2(0, -16) * k, 66.0 * k, 0, TAU, 40, Color(0.55, 0.1, 0.06, 0.8), 3.0)
			var tex := Assets.get_tex("ui/world/site_" + WorldSites.icon_of(sid), Vector2i(160, 140))
			var sz := Vector2(160, 140) * k * 0.95
			draw_texture_rect(tex, Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.82), sz), false)
			if st == "cleared":
				draw_texture_rect(Assets.get_tex("ui/world/cleared", Vector2i(64, 64)), Rect2(p + Vector2(34, -70) * k, Vector2(40, 40)), false)
			# seals for recent notable events
			var seals := WorldSites.recent_seals(sid, 10).size()
			for i in mini(seals, 3):
				draw_texture_rect(Assets.get_tex("ui/world/seal", Vector2i(64, 64)), Rect2(p + Vector2(-70 + i * 14, -74) * k, Vector2(30, 30)), false)
			# name plate
			var nm := WorldSites.name_of(sid)
			var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 18.0
			var plate := Rect2(p + Vector2(-w * 0.5, 22 * k), Vector2(w, 26))
			draw_rect(plate, Color(0.93, 0.87, 0.74, 0.88))
			draw_rect(plate, Color(ink, 0.7), false, 1.5)
			draw_string(f, plate.position + Vector2(0, 20), nm, HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color("#7e2418") if st == "cleared" else ink)
		# Brindlewick
		var vp := _to(Vector2(800, 520))
		var vw := f.get_string_size("Brindlewick", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 20.0
		var vr := Rect2(vp + Vector2(-vw * 0.5, 62 * k), Vector2(vw, 30))
		draw_rect(vr, Color(0.93, 0.87, 0.74, 0.92))
		draw_rect(vr, Color("#8a6a2a"), false, 2.0)
		draw_string(f, vr.position + Vector2(0, 23), "Brindlewick", HORIZONTAL_ALIGNMENT_CENTER, vw, 22, ink)
		# parties
		var by_dest := {}
		for e in Expeditions.active().values():
			var pos := _to(party_pos(e))
			var n: int = by_dest.get(str(e["dest"]) + str(e["phase"]), 0)
			by_dest[str(e["dest"]) + str(e["phase"])] = n + 1
			pos += Vector2(40 + n * 26, -28 + n * 30) * (k if str(e["phase"]) in ["moving", "acting"] else 0.4)
			var pt := Assets.get_tex("ui/world/party", Vector2i(48, 72))
			draw_texture_rect(pt, Rect2(pos - Vector2(16, 46), Vector2(32, 48)), false)
			var lead := str(Adv.get_a(str(e["leader"])).get("name", "?")).split(" ")[0]
			var lab := lead + (" +%d" % ((e["party"] as Array).size() - 1) if (e["party"] as Array).size() > 1 else "")
			var lw := fb.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10.0
			draw_rect(Rect2(pos + Vector2(12, -40), Vector2(lw, 22)), Color(0.13, 0.08, 0.05, 0.82))
			draw_string(fb, pos + Vector2(17, -24), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#efe4cc"))
		# hover hint
		if hover != "" and WorldSites.is_discovered(hover):
			var hp := _to(WorldSites.world_pos(hover))
			var txt := "%s — %s, %s" % [WorldSites.name_of(hover), WorldSites.status_word(hover), WorldSites.danger_word(hover)]
			var tw := fb.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0
			var tr := Rect2(hp + Vector2(-tw * 0.5, 52 * k), Vector2(tw, 22))
			draw_rect(tr, Color(0.13, 0.08, 0.05, 0.85))
			draw_string(fb, tr.position + Vector2(7, 16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#efe4cc"))
