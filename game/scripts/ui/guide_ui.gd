## GuideUI — shared widgets that show Guide's answers: readiness badges, "show me how" boxes with an action
## button, source lists, dependency trees and links into the encyclopedia. Used by the Help panel, the station
## recipe view and the counters that sell knowledge.
## EN: Links are bbcode [url=<topic>] metas: item:<def>, recipe:<id>, station:<id>, knowledge, skilltree:<node>,
##     venue:<id>, route:<panel>. follow(meta, back) opens the right panel; `back` lets the Help panel offer a
##     way back to where the player came from (e.g. the station).
## DA: Fælles widgets til vejledningen: status, "vis mig hvordan", kilder, afhængighedstræ og links.
class_name GuideUI
extends RefCounted

const LINK_COLOR := "#7e2418"
const ACTION_CAPTION := {"help": "Read about it", "skilltree": "Open the Skill Tree", "property": "Open Property & Workshop",
	"map": "Show on the map", "hirelings": "Open Hirelings", "workshop": "Open the Workshop Ledger", "shop": "Open the counter",
	"skills": "Your skill levels", "harbour": "The harbour"}


# ------------------------------------------------------------------ links
static func link(topic: String, text: String) -> String:
	return "[url=%s][color=%s]%s[/color][/url]" % [topic, LINK_COLOR, text]


static func item_link(def: String) -> String:
	return link("item:" + def, Guide.iname(def))


static func recipe_link(rid: String) -> String:
	return link("recipe:" + rid, str(DB.recipe(rid).get("name", rid)))


static func station_link(sid: String) -> String:
	return link("station:" + sid, Guide.sname(sid))


## Opens what a link points at. Encyclopedia topics open the Help panel (with a way back when given).
static func follow(meta: String, back := {}) -> void:
	if meta.begins_with("item:") or meta.begins_with("recipe:") or meta.begins_with("station:") or meta == "knowledge":
		var args := {"topic": meta}
		if not back.is_empty():
			args["back"] = back
		Events.open_panel.emit("help", args)
	elif meta.begins_with("skilltree:"):
		Events.open_panel.emit("skilltree", {"select": meta.substr(10)})
	elif meta.begins_with("venue:"):
		Events.open_panel.emit("map", {"venue": meta.substr(6)})
	elif meta.begins_with("route:"):
		Events.open_panel.emit(meta.substr(6), {})


static func do_action(action: Dictionary, back := {}) -> void:
	if action.is_empty():
		return
	var args: Dictionary = (action.get("args", {}) as Dictionary).duplicate()
	if str(action["route"]) == "help" and not back.is_empty():
		args["back"] = back
	Events.open_panel.emit(str(action["route"]), args)


static func action_caption(action: Dictionary) -> String:
	if action.is_empty():
		return ""
	if str(action["route"]) == "map":
		return "Show %s on the map" % Guide.venue_name(str(action.get("args", {}).get("venue", "")))
	return str(ACTION_CAPTION.get(str(action["route"]), "Open"))


## A rich label whose [url] links call on_meta(meta) (default: follow with no way back).
static func rich_links(bbcode: String, size := 20, on_meta := Callable()) -> RichTextLabel:
	var r := UIKit.rich(bbcode, size)
	r.meta_underlined = true
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	if on_meta.is_valid():
		r.meta_clicked.connect(func(m: Variant): on_meta.call(str(m)))
	else:
		r.meta_clicked.connect(func(m: Variant): follow(str(m)))
	return r


# ------------------------------------------------------------------ states
static func state_color(state: String) -> String:
	return str(Guide.STATE_COLOR.get(state, "#20140c"))


static func state_icon(state: String, size := 30.0) -> TextureRect:
	var ic := UIKit.icon(str(Guide.STATE_ICON.get(state, "ui/guide_unavailable")), size)
	ic.tooltip_text = str(Guide.STATE_WORD.get(state, state))
	return ic


## Icon + short coloured word ("Ready", "Missing 2", "Locked").
static func badge(state: String, text := "", size := 30.0) -> HBoxContainer:
	var h := UIKit.hbox(6)
	h.add_child(state_icon(state, size))
	var l := UIKit.label(text if text != "" else str(Guide.STATE_WORD.get(state, state)), int(size * 0.66), "body_bold", Color(state_color(state)))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## The short at-a-glance word for a recipe: "Ready" / "Missing 3" / "Locked".
static func recipe_badge_text(rs: Dictionary) -> String:
	match str(rs["state"]):
		"ready":
			return "Ready"
		"missing":
			var n := 0
			for d in rs["missing"]:
				n += int(rs["missing"][d])
			return "Missing %d" % n
		"locked":
			return "Locked"
	return "Unknown"


static func glyph(state: String) -> String:
	var g: String = {"ready": "✓", "have": "✓", "obtainable": "◷", "missing": "◷", "locked": "✗", "unavailable": "–", "hidden": "?"}.get(state, "·")
	return "[color=%s][b]%s[/b][/color]" % [state_color(state), g]


# ------------------------------------------------------------------ show me how
## "Show me how": the one next step for a recipe or item, with a button when it leads somewhere.
static func next_step_box(id: String, on_meta := Callable(), back := {}, step := {}) -> VBoxContainer:
	var v := UIKit.vbox(4)
	var ns: Dictionary = step if not step.is_empty() else Guide.next_step(id)
	if str(ns.get("text", "")) == "":
		return v
	var h := UIKit.hbox(12)
	h.add_child(UIKit.icon("ui/guide_obtainable" if not str(ns["text"]).begins_with("Everything is ready") else "ui/guide_ready", 34))
	var t := rich_links("[b]Next:[/b] %s" % str(ns["text"]), 21, on_meta)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var act: Dictionary = ns.get("action", {})
	if not act.is_empty():
		var b := UIKit.button(action_caption(act), func(): do_action(act, back), 0)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.name = "NextStepAction"
		h.add_child(b)
	v.add_child(h)
	if str(ns.get("why", "")) != "":
		v.add_child(UIKit.label(str(ns["why"]), 17, "body_italic", Color(0.37, 0.26, 0.11)))
	return v


# ------------------------------------------------------------------ sources
static func source_line(s: Dictionary) -> String:
	var line := "%s [b]%s[/b]" % [glyph(str(s["state"])), str(s["how"])]
	if str(s.get("when", "")) != "":
		line += "  [color=#5e421c][i]— %s[/i][/color]" % str(s["when"])
	if str(s.get("why", "")) != "" and str(s["state"]) in ["locked", "unavailable", "obtainable"]:
		line += "\n      [color=%s][i]%s[/i][/color]" % [state_color(str(s["state"])), str(s["why"])]
	return line


## Every way to get an item; the first `limit` shown, the rest behind a toggle.
static func sources_block(def: String, on_meta := Callable(), limit := 4) -> VBoxContainer:
	var v := UIKit.vbox(4)
	var src := Guide.sources(def)
	if src.is_empty():
		v.add_child(UIKit.label("No known source yet — explore, trade and listen for rumours.", 19, "body_italic"))
		return v
	var lines := []
	for s in src:
		var ln := source_line(s)
		if str(s["kind"]) == "craft":
			ln = ln.replace("[b]%s[/b]" % str(s["how"]), "[b]Make it:[/b] " + recipe_link(str(s["id"])) + " [color=#5e421c](%s)[/color]" % str(s["where"]))
		lines.append(ln)
	var first := rich_links("\n".join(lines.slice(0, limit)), 19, on_meta)
	v.add_child(first)
	if lines.size() > limit:
		var rest := rich_links("\n".join(lines.slice(limit)), 19, on_meta)
		rest.visible = false
		var tog := UIKit.button("Show %d more way%s ▾" % [lines.size() - limit, "" if lines.size() - limit == 1 else "s"], func(): pass, 0)
		tog.pressed.connect(func():
			rest.visible = not rest.visible
			tog.text = ("Fewer ▴" if rest.visible else "Show %d more way%s ▾" % [lines.size() - limit, "" if lines.size() - limit == 1 else "s"]))
		tog.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(rest)
		v.add_child(tog)
	return v


# ------------------------------------------------------------------ dependency tree
static func tree_text(t: Dictionary) -> String:
	var lines := []
	for l in Guide.tree_lines(t):
		var n: Dictionary = l["node"]
		var ind := "      ".repeat(int(l["depth"]))
		var st := str(n.get("state", ""))
		match str(n["type"]):
			"item":
				lines.append("%s%s %d× %s  [color=#5e421c](have %d)[/color]%s%s" % [ind, glyph(st), int(n["qty"]), item_link(str(n["id"])), int(n["have"]),
					"  [color=#5e421c][i]intermediate[/i][/color]" if bool(n.get("intermediate", false)) else "", "  [i](see above)[/i]" if bool(n.get("cycle", false)) else ""])
			"recipe":
				lines.append("%s%s [b]%s[/b]%s" % [ind, glyph("ready" if st == "ready" else ("missing" if st == "missing" else "locked")), recipe_link(str(n["id"])),
					(" ×%d" % int(n["times"])) if int(n.get("times", 1)) > 1 else ""])
			"station":
				lines.append("%s%s at %s%s" % [ind, glyph(st), link("station:" + str(n["id"]), Guide.the_station(str(n["id"]))), ("  [color=#7e2418][i]%s[/i][/color]" % str(n.get("why", ""))) if st != "ready" else ""])
	return "\n".join(lines)


static func tree_block(id: String, on_meta := Callable()) -> RichTextLabel:
	return rich_links(tree_text(Guide.tree(id)), 18, on_meta)


## A collapsible "Full details" section built lazily (fill(v) is called on first open).
static func expander(caption: String, fill: Callable, open := false) -> VBoxContainer:
	var v := UIKit.vbox(6)
	var body := UIKit.vbox(6)
	body.visible = false
	var b := UIKit.button(caption + " ▸", func(): pass, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var built := [false]
	var toggle := func():
		if not built[0]:
			built[0] = true
			fill.call(body)
		body.visible = not body.visible
		b.text = caption + (" ▾" if body.visible else " ▸")
	b.pressed.connect(toggle)
	v.add_child(b)
	v.add_child(body)
	if open:
		toggle.call()
	return v


# ------------------------------------------------------------------ knowledge for sale
## The knowledge a seller offers, as rows with a buy button (for the pawnshop, the harbour, the herbalist).
static func knowledge_box(seller: String, on_change := Callable()) -> VBoxContainer:
	var v := UIKit.vbox(10)
	var offers := Knowledge.offers(seller)
	var hv := UIKit.hbox(12)
	hv.add_child(UIKit.icon("ui/guide_knowledge", 44))
	var intro := UIKit.rich("[b]What %s knows[/b]\n[i]Hints say where and how — the discovery itself is still yours to make. What you buy stays in Help › Knowledge & Notes.[/i]" % Knowledge.seller_name(seller), 19)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(intro)
	v.add_child(hv)
	if offers.is_empty():
		v.add_child(UIKit.label("Nothing left to tell you just now.", 20, "body_italic"))
		return v
	for o in offers:
		var row := UIKit.hbox(14)
		var t := UIKit.rich("[b]%s[/b]  [color=#5e421c][i]%s[/i][/color]\n%s" % [str(o["title"]), "hint" if str(o["kind"]) == "hint" else "complete knowledge",
			str(o["text"]) if bool(o["bought"]) else "[i]%s[/i]" % str(o["teaser"])], 19)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		if bool(o["bought"]):
			row.add_child(badge("have", "Known", 26))
		else:
			var oid := str(o["id"])
			var b := UIKit.button("Pay %d g" % int(o["price"]), func():
				var why := Knowledge.buy(oid)
				Events.toast.emit(why if why != "" else "Learned: %s — see Help › Knowledge & Notes." % str(o["title"]), "bad" if why != "" else "good")
				if on_change.is_valid():
					on_change.call(), 150)
			b.disabled = not bool(o["can_buy"])
			b.tooltip_text = str(o["why"])
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(row)
		v.add_child(UIKit.divider())
	return v
