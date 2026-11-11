## PropertyPanel — "Property & Workshop": a drawn plan of the whole smithy building.
## EN: Property tab: buy neighbouring rooms (only next to what you own). Workshop layout tab: take down or put
##     up internal walls, cut or brick up doorways, move, turn or store stations — on a copy of the plan that is
##     validated live and applied in one go. Equipment tab: buy the stations the skill tree allows.
## DA: Ejendom & værksted — køb naborum, flyt vægge, døre og arbejdsstationer på en tegnet plan.
class_name PropertyPanel
extends UIWindow

const SC := 34.0            # pixels per tile on the plan

var tab := "property"
var plan: Dictionary = {}
var floor_id := "ground"    # which floor the plan shows (The Living Realm: the Loft)
var tool := "stations"      # stations | merge | split | door | undoor | use | craft
var split_vertical := true
var selected_unit := ""
var carrying := ""          # station being moved / placed
var carry_flip := false
var dirty := false          # something was bought or applied: rebuild the world on close
var view: PlanView
var side: VBoxContainer
var status: RichTextLabel
var tabs_row: HBoxContainer


var show_lift := false      # opened from the old hoist: the property tab explains the lift


## args (optional): {"floor": "loft"} opens on that floor; {"id": "lift"} (the old hoist) opens on the lift.
func _init(args := {}) -> void:
	super._init("Property & Workshop", 1840, 1010)
	floor_id = str(args.get("floor", "ground"))
	if str(args.get("id", "")) == "lift":
		show_lift = true
		floor_id = "loft" if Property.floor_owned("loft") else "ground"
	if Property.floor_def(floor_id).is_empty():
		floor_id = "ground"


## Plan coordinates of the floor shown (its rect's corner; the ground floor is at 0, 0).
func floor_off() -> Vector2:
	return Property.floor_rect(floor_id).position


func set_floor(fid: String) -> void:
	floor_id = fid   # a carried station stays in hand: it can be set down on the other floor
	_build()


func _ready() -> void:
	super._ready()
	plan = Property.plan_copy()
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	var row := UIKit.hbox(18)
	view = PlanView.new(self)
	view.custom_minimum_size = Vector2(30 * SC + 40, 23 * SC + 40)
	row.add_child(view)
	side = UIKit.vbox(8)
	side.custom_minimum_size = Vector2(640, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	content.add_child(row)
	status = UIKit.rich("", 18)
	content.add_child(status)
	_build()


func close() -> void:
	if dirty:
		var main := get_tree().root.get_node_or_null("Main")
		if main and main.has_method("rebuild_world"):
			main.call_deferred("rebuild_world")
	super.close()


func _build() -> void:
	UIKit.clear(tabs_row)
	for t in [["property", "Property"], ["layout", "Workshop layout"], ["equipment", "Equipment"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): _switch(key), 0)
		b.disabled = tab == key
		tabs_row.add_child(b)
	# The Living Realm: the floor switcher (the plan shows one floor at a time)
	if Property.floors().size() > 1:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(26, 0)
		tabs_row.add_child(gap)
		tabs_row.add_child(UIKit.label("Floor:", 19, "body_italic", UIKit.INK))
		for f in Property.floors():
			var fid := str(f["id"])
			var fb := UIKit.button(str(f.get("name", fid)) + ("" if Property.floor_owned(fid) else " (for sale)"), func(): set_floor(fid), 0)
			fb.disabled = floor_id == fid
			fb.name = "Floor_" + fid
			tabs_row.add_child(fb)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(sp)
	var stage_l := UIKit.label("%s · %d gold" % [Property.stage(), Game.gold()], 20, "body_italic", UIKit.INK)
	stage_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	tabs_row.add_child(stage_l)
	UIKit.clear(side)
	match tab:
		"property": _side_property()
		"layout": _side_layout()
		"equipment": _side_equipment()
	_refresh_status()
	view.queue_redraw()


func _switch(key: String) -> void:
	if tab == "layout" and key != "layout":
		carrying = ""
	tab = key
	_build()


# ------------------------------------------------------------------ property tab
func _side_property() -> void:
	side.add_child(UIKit.label("The building", 26, "heading"))
	side.add_child(UIKit.rich("You own a corner of a large old building. Your neighbours will sell their rooms as your business grows — but only rooms that join onto yours. Click a room on the plan.", 18))
	if selected_unit != "":
		var u := Property.unit(selected_unit)
		var stt := Property.unit_state(selected_unit)
		side.add_child(UIKit.divider())
		side.add_child(UIKit.label(str(u.get("name", "")), 28, "heading", UIKit.RUBRIC))
		side.add_child(UIKit.rich("[i]%s[/i]\n%s%s" % [u.get("desc", ""), ("Occupied by " + str(u.get("occupant", ""))) if stt != "owned" else "Yours.",
			("\nIt would make %s." % u.get("becomes", "")) if stt != "owned" and u.get("becomes", "") != "" else ""], 19))
		if stt == "available":
			var price := Property.unit_price(selected_unit)
			var b := UIKit.button("Buy for %d gold" % price, func(): _buy_unit(selected_unit), 320)
			b.disabled = not Game.can_afford(price)
			side.add_child(b)
		elif stt == "unavailable":
			var req := str(u.get("requires", ""))
			side.add_child(UIKit.label(("Buy %s first — the way up is through there." % Property.unit(req).get("name", req)) if req != "" else "Not next to anything you own yet.", 19, "body_italic"))
	if Property.floors().size() > 1 and (show_lift or Property.floor_owned("loft")):
		side.add_child(UIKit.divider())
		side.add_child(_lift_box())
	side.add_child(UIKit.divider())
	for u2 in Property.units():
		var s2 := Property.unit_state(str(u2["id"]))
		var col: String = {"owned": "#26622f", "available": "#7e2418", "unavailable": "#8a7a60"}[s2]
		var upstairs := str(u2.get("floor", "ground")) != "ground"
		var line := UIKit.rich("[color=%s]●[/color] [b]%s[/b]%s — %s%s" % [col, u2["name"], (" [i](%s)[/i]" % Property.floor_name(str(u2["floor"]))) if upstairs else "",
			{"owned": "yours", "available": "for sale", "unavailable": "not adjoining yet" if not u2.has("requires") else "after " + str(Property.unit(str(u2["requires"])).get("name", ""))}[s2],
			(" · %d g" % Property.unit_price(str(u2["id"]))) if s2 == "available" else ""], 18)
		side.add_child(line)


## The aetheric lift: what it does, what it needs, and the purchase.
func _lift_box() -> Control:
	var v := UIKit.vbox(4)
	v.name = "LiftBox"
	v.add_child(UIKit.label("The aetheric lift", 24, "heading", UIKit.RUBRIC))
	if Property.has_lift():
		v.add_child(UIKit.rich("[i]Ilse's old goods hoist, driven by a ley-stone: one step between the leather room and the weaving loft. Your apprentices use it too.[/i]", 18))
		return v
	v.add_child(UIKit.rich("[i]Ilse's old goods hoist runs from the leather room up into the Loft. Set a ley-stone from an Arcane Foundry into it and it carries you — and your apprentices — between the floors in one step.[/i]", 18))
	var why := Property.lift_reason()
	if why != "":
		v.add_child(UIKit.label("🔒 " + why, 18, "body_italic", Color("#8a7a60")))
	else:
		var b := UIKit.button("Rig the lift · %d g" % Property.lift_price(), _buy_lift, 300)
		b.disabled = not Game.can_afford(Property.lift_price())
		b.name = "BuyLift"
		v.add_child(b)
	return v


func _buy_lift() -> void:
	var err := Property.buy_lift()
	if err != "":
		Events.toast.emit(err, "bad")
		return
	Audio.play("sfx/arcane", -4.0)
	dirty = true
	plan = Property.plan_copy()
	_build()


func _buy_unit(uid: String) -> void:
	var err := Property.buy_unit(uid)
	if err != "":
		Events.toast.emit(err, "bad")
		return
	Audio.play("sfx/coins", -2.0)
	dirty = true
	plan = Property.plan_copy()
	_build()


# ------------------------------------------------------------------ layout tab
func _side_layout() -> void:
	side.add_child(UIKit.label("Workshop layout", 26, "heading"))
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	for t in [["stations", "Move stations"], ["merge", "Take down a wall"], ["split", "Put up a wall"], ["door", "Cut a doorway"], ["undoor", "Brick up a doorway"], ["use", "Change a room's use"], ["craft", "Set a room's craft"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): tool = key; carrying = ""; _build(), 0)
		b.disabled = tool == key
		b.add_theme_font_size_override("font_size", 17)
		tools.add_child(b)
	side.add_child(tools)
	var help := {
		"stations": "Click a station to pick it up, click again to set it down (it snaps to a quarter tile). Stations must stand inside one of your rooms, clear of walls, doorways and other stations.",
		"merge": "Click an internal wall between two of your rooms. It comes down when the two rooms together make a rectangle.",
		"split": "Move over one of your rooms and click to divide it along the dotted line; right-click (or the button) turns the line. A doorway is cut in the new wall.",
		"door": "Click a wall between two of your rooms to cut a two-tile doorway there.",
		"undoor": "Click a doorway between two of your rooms to brick it up.",
		"use": "Click one of your rooms to switch it between workshop and living space. Stations only stand in workshop rooms; the shopfront serves customers and the stock hall stays a clear passage.",
		"craft": "Click one of your workshop rooms to choose the craft it is for (its banner): Smithing, Leatherworking & Tailoring, Runecrafting, Alchemy, Arcane Metalworking or any. New stations are set up in a room of their own craft first; mixed rooms are fine.",
	}
	side.add_child(UIKit.rich("[i]%s[/i]" % help[tool], 18))
	if tool == "split":
		side.add_child(UIKit.button("Turn the line (%s)" % ("vertical" if split_vertical else "horizontal"), func(): split_vertical = not split_vertical; _build(), 300))
	if tool == "stations":
		if carrying != "":
			side.add_child(UIKit.rich("Carrying: [b]%s[/b]" % Property.instance_label(carrying), 19))
			var h := UIKit.hbox(6)
			h.add_child(UIKit.button("Turn it", func(): carry_flip = not carry_flip; view.queue_redraw(), 140))
			h.add_child(UIKit.button("Put in storage", func(): Property.store(plan, carrying); carrying = ""; _build(), 200))
			h.add_child(UIKit.button("Cancel", func(): carrying = ""; _build(), 120))
			side.add_child(h)
		var stored: Array = plan["stored"]
		if not stored.is_empty():
			side.add_child(UIKit.label("In storage — click to place", 20, "heading"))
			var flow := HFlowContainer.new()
			for sid in stored:
				var id: String = sid
				var b2 := UIKit.button(Property.instance_label(id), func(): carrying = id; carry_flip = false; _build(), 0)
				b2.add_theme_font_size_override("font_size", 17)
				b2.tooltip_text = "Click to carry it to a spot of your choice."
				flow.add_child(b2)
			side.add_child(flow)
			side.add_child(UIKit.button("Find a spot for everything in storage", _auto_place_all, 380))
		side.add_child(UIKit.rich("[i]Free station places in your workshop rooms: [b]%d[/b] (one per eight square tiles of floor).[/i]" % Property.free_places(plan), 17))
		side.add_child(_capacity_box())
		if not Apprentices.staff().is_empty():
			side.add_child(UIKit.rich("[i][color=#24409a]●[/color] a station in use (initials of who works there) · [color=#9e3a0c]worn[/color] stations slow apprentices down — queue upkeep in the Workshop ledger [%s].[/i]" % Settings.key_label("panel_workshop"), 16))
	side.add_child(UIKit.divider())
	var h2 := UIKit.hbox(10)
	var ok := Property.validate(plan) == ""
	var apply := UIKit.button("Apply changes", _apply, 240)
	apply.disabled = not ok
	h2.add_child(apply)
	h2.add_child(UIKit.button("Discard changes", func(): plan = Property.plan_copy(); carrying = ""; _build(), 240))
	side.add_child(h2)


## Places per craft: stations of the craft you have, and the places in rooms of that craft (crowding at a glance).
func _capacity_box() -> Control:
	var lines := []
	for c in Smithy.capacity_report(plan):
		if int(c["installed"]) == 0 and int(c["places"]) == 0:
			continue
		var tight := int(c["installed"]) > int(c["places"])
		lines.append("%s: %d station%s set up · %d place%s in its rooms%s" % [c["name"], int(c["installed"]), "" if int(c["installed"]) == 1 else "s",
			int(c["places"]), "" if int(c["places"]) == 1 else "s", " [color=#9e3a0c](crowded — some stand in other rooms)[/color]" if tight else ""])
	var r := UIKit.rich("[i]" + "\n".join(lines) + "[/i]", 16)
	r.name = "CapacityBox"
	return r


## Sets up every stored station in a sensible free spot (its usual place, else a room of its own craft).
func _auto_place_all() -> void:
	var failed := []
	for sid in (plan["stored"] as Array).duplicate():
		var why := Property.auto_place(plan, str(sid))
		if why != "":
			failed.append("%s: %s" % [DB.station(str(sid)).get("name", sid), why])
	if failed.is_empty():
		Events.toast.emit("Everything is set up — check the plan, then apply the changes.", "good")
	else:
		Events.toast.emit("No room for " + "; ".join(failed), "bad")
	_build()


func _apply() -> void:
	if carrying != "":
		Events.toast.emit("Set the %s down first." % DB.station(carrying).get("name", carrying), "bad")
		return
	var err := Property.commit(plan)
	if err != "":
		Events.toast.emit(err, "bad")
		return
	Audio.play("sfx/hammer_1", -6.0)
	Events.toast.emit("The workshop is rearranged.", "good")
	Chronicle.add("property", "Brannoc rearranged the workshop.")
	dirty = true
	plan = Property.plan_copy()
	_build()


func _refresh_status() -> void:
	if tab != "layout":
		status.text = "[color=#5e421c]Legend: [color=#26622f]■[/color] yours · [color=#7e2418]■[/color] for sale · [color=#6a6056]■[/color] a neighbour's · doorways in brass · locked doors dark[/color]"
		return
	var err := Property.validate(plan)
	var ok_text := "✓ Every room, every station, the counter and a bed can be reached from the front door."
	if Property.floor_owned("loft"):
		ok_text = "✓ Every room and station on both floors, the counter, a bed, the stair%s can be reached." % (" and the lift" if Property.has_lift() else "")
	status.text = ("[color=#26622f]%s[/color]" % ok_text if err == "" else "[color=#9e3a0c]✗ " + err + "[/color]")


func plan_click(tile: Vector2, button: int) -> void:
	match tab:
		"property":
			var r := Property.room_at_tile(plan["rooms"], tile)
			if not r.is_empty():
				selected_unit = str(r.get("unit", ""))
				_build()
		"layout":
			if button == MOUSE_BUTTON_RIGHT and tool == "split":
				split_vertical = not split_vertical
				_build()
				return
			_layout_click(tile)


func _layout_click(tile: Vector2) -> void:
	var err := ""
	match tool:
		"stations":
			if carrying == "":
				for sid in plan["stations"]:
					if Property.footprint(sid, plan["stations"][sid]).grow(0.15).has_point(tile):
						var host := Property.room_at_tile(plan["rooms"], tile)
						if not host.is_empty() and Property.room_owned(host):
							carrying = sid
							carry_flip = bool(plan["stations"][sid].get("flip", false))
				_build()
				return
			err = Property.place(plan, carrying, tile, carry_flip)
			if err == "":
				carrying = ""
		"merge":
			var w := wall_at(tile)
			err = "Click on an internal wall." if w.is_empty() else Property.merge(plan, w[0], w[1])
		"split":
			var r := Property.room_at_tile(plan["rooms"], tile)
			err = "Click inside one of your rooms." if r.is_empty() else Property.split(plan, str(r["id"]), split_vertical, int(round(tile.x if split_vertical else tile.y)))
		"door":
			var w2 := wall_at(tile)
			if w2.is_empty():
				err = "Click on an internal wall."
			else:
				var e := Property.shared_edge(Property.rect(Property.room_by_id(plan["rooms"], w2[0])), Property.rect(Property.room_by_id(plan["rooms"], w2[1])))
				err = Property.add_door(plan, w2[0], w2[1], int(floor((tile.y if bool(e[0]) else tile.x) - 1.0 + 0.5)))
		"undoor":
			var d := door_at(tile)
			err = "Click on a doorway." if d.is_empty() else Property.remove_door(plan, d)
		"use":
			var r2 := Property.room_at_tile(plan["rooms"], tile)
			err = "Click one of your rooms." if r2.is_empty() else Property.set_kind(plan, str(r2["id"]), "home" if Property.kind(r2) == "workshop" else "workshop")
		"craft":
			var r3 := Property.room_at_tile(plan["rooms"], tile)
			if r3.is_empty():
				err = "Click one of your workshop rooms."
			else:
				var order: Array = [""] + Property.DISCIPLINES
				var nxt: String = order[(order.find(Property.planned_discipline(r3)) + 1) % order.size()]
				err = Property.set_discipline(plan, str(r3["id"]), nxt)
				if err == "":
					Events.toast.emit("%s — %s" % [r3.get("name", ""), Smithy.trade_name(nxt) if nxt != "" else "any craft"], "info")
	if err != "":
		Events.toast.emit(err, "bad")
	else:
		Audio.play("sfx/ui_click", -8.0)
	_build()


## The two owned rooms whose shared wall is under `tile` (within a third of a tile), or [].
func wall_at(tile: Vector2) -> Array:
	var rs: Array = plan["rooms"]
	for i in rs.size():
		for j in range(i + 1, rs.size()):
			var e := Property.shared_edge(Property.rect(rs[i]), Property.rect(rs[j]))
			if e.is_empty():
				continue
			var along := tile.y if bool(e[0]) else tile.x
			var across := tile.x if bool(e[0]) else tile.y
			if absf(across - float(e[1])) < 0.35 and along > float(e[2]) and along < float(e[3]):
				return [str(rs[i]["id"]), str(rs[j]["id"])]
	return []


func door_at(tile: Vector2) -> Dictionary:
	for d in plan["doors"]:
		var c := Property.door_center(plan, d)
		if c != Vector2.INF and c.distance_to(tile) < 1.1:
			return d
	return {}


# ------------------------------------------------------------------ equipment tab
func _side_equipment() -> void:
	side.add_child(UIKit.label("Workshop equipment", 26, "heading"))
	side.add_child(UIKit.rich("Stations you have learned to use (Skill Tree) can be bought here and are delivered to storage; set them up under [b]Workshop layout[/b].", 18))
	var sc := UIKit.vbox(4)
	for disc in ["classic", "runecraft", "alchemy", "stitching", "arcane"]:
		sc.add_child(UIKit.label({"classic": "Traditional smithing", "runecraft": "Runecrafting", "alchemy": "Alchemy", "stitching": "Leatherworking & stitching", "arcane": "Arcane metalworking"}[disc], 21, "heading"))
		for st in DB.stations.values():
			if str(st.get("discipline", "")) != disc:
				continue
			var sid: String = st["id"]
			var h := UIKit.hbox(8)
			var l := UIKit.label(str(st["name"]), 18, "body_bold")
			l.custom_minimum_size = Vector2(240, 0)
			h.add_child(l)
			var owned_n := Property.instance_count(sid)   # Living Workshop #37: several of a type, each bought and placed
			if owned_n > 0:
				var set_up := Property.instances(sid).size()
				var words := ("installed" if owned_n == 1 else "%d set up" % set_up) if set_up > 0 else ""
				if owned_n > set_up:
					words += ("%s%d in storage — place %s in Workshop layout" % [", " if words != "" else "", owned_n - set_up, "it" if owned_n - set_up == 1 else "them"])
				var wl := UIKit.label(words, 17, "body_italic", Color("#26622f") if set_up > 0 else Color("#735800"))
				wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(wl)
				var more := Property.more_reason(sid)
				var nprice := Property.station_price(sid)
				var mb := UIKit.small_button("Another · %d g" % nprice, func(): _buy_station(sid), 170)
				mb.name = "BuyAnother_" + sid
				mb.disabled = more != "" or not Game.can_afford(nprice)
				mb.tooltip_text = more if more != "" else "Buy another %s (#%d) — each further one costs a little more to fit into a working room." % [str(st["name"]).to_lower(), owned_n + 1]
				h.add_child(mb)
			else:
				var why := SkillTree.station_reason(sid)
				if why != "":
					var lk := UIKit.label("🔒 " + why, 16, "body_italic", Color("#8a7a60"))
					lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					h.add_child(lk)
				else:
					var price := Property.station_price(sid)
					var b := UIKit.button("Buy · %d g" % price, func(): _buy_station(sid), 170)
					b.disabled = not Game.can_afford(price)
					h.add_child(b)
			sc.add_child(h)
	side.add_child(UIKit.scroll(sc, 760))


func _buy_station(sid: String) -> void:
	var err := Property.buy_station(sid)
	if err != "":
		Events.toast.emit(err, "bad")
		return
	Audio.play("sfx/coins", -2.0)
	for got in Property.st()["stored"]:   # #37: the bought instance ("anvil#2") joins the plan's storage
		if not (plan["stored"] as Array).has(got) and not (plan["stations"] as Dictionary).has(got):
			(plan["stored"] as Array).append(got)
	_build()


# ======================================================================= the plan
class PlanView extends Control:
	var p: PropertyPanel
	var hover := Vector2(-1, -1)
	const O := Vector2(20, 20)

	func _init(panel: PropertyPanel) -> void:
		p = panel
		mouse_filter = Control.MOUSE_FILTER_STOP

	func tile_of(local: Vector2) -> Vector2:
		return (local - O) / PropertyPanel.SC + p.floor_off()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			hover = tile_of((ev as InputEventMouseMotion).position)
			queue_redraw()
		elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var mb := ev as InputEventMouseButton
			if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				p.plan_click(tile_of(mb.position), mb.button_index)
				accept_event()

	func _px(t: Vector2) -> Vector2:
		return O + (t - p.floor_off()) * PropertyPanel.SC

	func _on_floor(r: Dictionary) -> bool:
		return Property.floor_of_room(r) == p.floor_id

	func _draw() -> void:
		var sc := PropertyPanel.SC
		var plan: Dictionary = p.plan
		var f := Assets.font("heading")
		var fb := Assets.font("body")
		draw_rect(Rect2(Vector2.ZERO, size), Color("#e9dcbc"))
		# rooms (of the floor shown)
		for r in plan["rooms"]:
			if not _on_floor(r):
				continue
			var rr := Property.rect(r)
			var px := Rect2(_px(rr.position), rr.size * sc)
			var owned := Property.room_owned(r)
			var uid := str(r.get("unit", ""))
			var stt := Property.unit_state(uid)
			var col := Color("#f3e8cc") if owned else (Color("#e2c9b0") if stt == "available" else Color("#b9b0a2"))
			if p.tab == "property" and uid == p.selected_unit:
				col = col.lerp(Color("#e8c060"), 0.35)
			draw_rect(px, col)
			if not owned:
				# hatching for rooms that are not his
				var hc := Color("#7e2418", 0.35) if stt == "available" else Color("#4a4038", 0.3)
				var k := 7.0
				var w := px.size.x
				var hh := px.size.y
				while k < w + hh:
					# anti-diagonal hatching clipped to the room: from the top/right edge to the left/bottom edge
					var a := px.position + (Vector2(k, 0) if k <= w else Vector2(w, k - w))
					var b := px.position + (Vector2(0, k) if k <= hh else Vector2(k - hh, hh))
					draw_line(a, b, hc, 1.0)
					k += 14.0
			var name := str(r.get("name", ""))
			if not owned:
				name = str(Property.unit(uid).get("name", name))
			draw_string(fb, px.position + Vector2(6, 18), name, HORIZONTAL_ALIGNMENT_LEFT, px.size.x - 10, 14, Color("#20140c", 0.85))
			if owned:
				var use: String = {"workshop": "workshop", "shop": "shop — customers", "store": "passage", "home": "living space"}.get(Property.kind(r), "")
				if use == "workshop":
					# The Living Realm: the room's craft (planned, else from its stations) and its tier
					var disc := Property.planned_discipline(r)
					if disc == "":
						disc = Property.room_discipline(r)
					use = "workshop · " + (Smithy.trade_name(disc) if disc != "" else "any craft")
					if disc != "" and Property.room_owned(r) and Game.state.has("property"):
						use += " · " + Smithy.TIER_NAMES[Smithy.room_tier(r)]
				draw_string(fb, px.position + Vector2(6, 34), use, HORIZONTAL_ALIGNMENT_LEFT, px.size.x - 10, 12, Color("#7e2418", 0.8) if use.begins_with("workshop") else Color("#5e421c", 0.75))
			else:
				var upa := Property.unit(uid)
				if upa.has("becomes"):
					draw_string(fb, px.position + Vector2(6, 34), "→ " + str(upa["becomes"]), HORIZONTAL_ALIGNMENT_LEFT, px.size.x - 10, 11, Color("#5e421c", 0.7))
		# walls between rooms (with doorway gaps)
		var rs: Array = plan["rooms"]
		for i in rs.size():
			if not _on_floor(rs[i]):
				continue
			for j in range(i + 1, rs.size()):
				var e := Property.shared_edge(Property.rect(rs[i]), Property.rect(rs[j]))
				if e.is_empty():
					continue
				var gaps := []
				for d in plan["doors"]:
					var pair: Array = d["between"]
					if pair.has(rs[i]["id"]) and pair.has(rs[j]["id"]):
						gaps.append([float(d["at"]), float(d["at"]) + float(d["w"]), Property.door_open(plan, d)])
				gaps.sort_custom(func(x, y): return x[0] < y[0])
				var start := float(e[2])
				for g in gaps:
					_wall(e, start, float(g[0]))
					var ga := Vector2(float(e[1]), float(g[0])) if bool(e[0]) else Vector2(float(g[0]), float(e[1]))
					var gb := Vector2(float(e[1]), float(g[1])) if bool(e[0]) else Vector2(float(g[1]), float(e[1]))
					draw_line(_px(ga), _px(gb), Color("#b8923e") if g[2] else Color("#5a3a22"), 6.0 if not g[2] else 3.0)
					start = float(g[1])
				_wall(e, start, float(e[3]))
		# outer wall and the front door (the Loft: its eaves, the stair and the hoist)
		var flr := Property.floor_rect(p.floor_id)
		draw_rect(Rect2(_px(flr.position), flr.size * sc), Color("#20140c"), false, 6.0)
		if p.floor_id == "ground":
			var ent: Array = Property.data().get("entrance", [14.0, 0.6])
			var ep := _px(Vector2(float(ent[0]), 0))
			draw_line(ep - Vector2(sc, 0), ep + Vector2(sc, 0), Color("#e9dcbc"), 8.0)
			draw_string(f, ep + Vector2(-40, -4), "front door", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color("#7e2418"))
		for rv: Rect2 in Property.reserved_rects():
			if not flr.encloses(rv):
				continue
			var rp := Rect2(_px(rv.position), rv.size * sc)
			draw_rect(rp, Color("#5e421c", 0.18))
			draw_rect(rp, Color("#5e421c", 0.6), false, 1.5)
			var is_stair := rv.size.y > rv.size.x + 0.2
			var word := "stair" if is_stair else ("lift" if Property.has_lift() else "hoist")
			draw_string(fb, rp.position + Vector2(2, rp.size.y * 0.5 + 5), word, HORIZONTAL_ALIGNMENT_CENTER, rp.size.x - 4, 12, Color("#5e421c"))
		# stations (of the floor shown)
		for sid in plan["stations"]:
			if sid == p.carrying:
				continue
			var spa: Array = plan["stations"][sid]["pos"]
			if not flr.has_point(Vector2(float(spa[0]), float(spa[1]))):
				continue
			_station(sid, plan["stations"][sid], Color.WHITE)
		# tool previews
		if p.tab == "layout" and hover.x >= 0:
			match p.tool:
				"stations":
					if p.carrying != "":
						var entry := {"pos": [snappedf(hover.x, 0.25), snappedf(hover.y, 0.25)], "flip": p.carry_flip}
						var bad := Property.spot_problem(plan, p.carrying, entry) != ""
						_station(p.carrying, entry, Color(1, 0.55, 0.5, 0.85) if bad else Color(0.8, 1, 0.8, 0.9))
				"merge", "door":
					var w := p.wall_at(hover)
					if not w.is_empty():
						var e2 := Property.shared_edge(Property.rect(Property.room_by_id(rs, w[0])), Property.rect(Property.room_by_id(rs, w[1])))
						if p.tool == "merge":
							var a := Vector2(float(e2[1]), float(e2[2])) if bool(e2[0]) else Vector2(float(e2[2]), float(e2[1]))
							var b2 := Vector2(float(e2[1]), float(e2[3])) if bool(e2[0]) else Vector2(float(e2[3]), float(e2[1]))
							draw_line(_px(a), _px(b2), Color("#9e3a0c"), 8.0)
						else:
							var at := clampf(floor((hover.y if bool(e2[0]) else hover.x) - 0.5), float(e2[2]), float(e2[3]) - 2.0)
							var da := Vector2(float(e2[1]), at) if bool(e2[0]) else Vector2(at, float(e2[1]))
							var db := Vector2(float(e2[1]), at + 2.0) if bool(e2[0]) else Vector2(at + 2.0, float(e2[1]))
							draw_line(_px(da), _px(db), Color("#26622f"), 8.0)
				"split":
					var r := Property.room_at_tile(rs, hover)
					if not r.is_empty() and Property.editable(r) and _on_floor(r):
						var rr2 := Property.rect(r)
						var line: float = round(hover.x if p.split_vertical else hover.y)
						var a2 := Vector2(line, rr2.position.y) if p.split_vertical else Vector2(rr2.position.x, line)
						var b3 := Vector2(line, rr2.end.y) if p.split_vertical else Vector2(rr2.end.x, line)
						draw_dashed_line(_px(a2), _px(b3), Color("#7e2418"), 4.0, 10.0)
				"undoor":
					var d2 := p.door_at(hover)
					if not d2.is_empty():
						draw_circle(_px(Property.door_center(plan, d2)), 14.0, Color("#9e3a0c", 0.6))

	func _wall(e: Array, a: float, b: float) -> void:
		if b - a < 0.01:
			return
		var pa := Vector2(float(e[1]), a) if bool(e[0]) else Vector2(a, float(e[1]))
		var pb := Vector2(float(e[1]), b) if bool(e[0]) else Vector2(b, float(e[1]))
		draw_line(_px(pa), _px(pb), Color("#20140c"), 4.0)

	## Iteration 012: who is working at a station (a small blue roundel with their initials) and whether it is worn.
	func _station_use(sid: String, c: Vector2, sz: Vector2) -> void:
		if not Game.state.has("apprentices") or not Property.is_installed(sid):
			return
		var f := Assets.font("body_bold")
		var u := Apprentices.station_user(sid)
		if u != "":
			var ini := "B.I." if u == "smith" else str(Apprentices.get_a(u).get("mark", {}).get("initials", "?"))
			var at := c + Vector2(sz.x * 0.5 - 6, -sz.y * 0.5 + 6)
			draw_circle(at, 13.0, Color("#24409a", 0.9))
			draw_arc(at, 13.0, 0, TAU, 20, Color("#efe4cc"), 2.0)
			draw_string(f, at + Vector2(-13, 5), ini.replace(".", ""), HORIZONTAL_ALIGNMENT_CENTER, 26, 12, Color("#efe4cc"))
		if Apprentices.is_worn(sid):
			var wt := c + Vector2(-sz.x * 0.5 + 2, sz.y * 0.5 - 2)
			draw_string(f, wt, "worn %d%%" % int(round(Apprentices.station_condition(sid))), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9e3a0c"))

	func _station(sid: String, entry: Dictionary, tint: Color) -> void:
		var sc := PropertyPanel.SC
		var st := DB.station(sid)
		var size: Array = st.get("size", [96, 96])
		var sz := Vector2(float(size[0]), float(size[1])) / 64.0 * sc
		var pa: Array = entry["pos"]
		var c := _px(Vector2(float(pa[0]), float(pa[1])))
		var tex := Assets.get_tex("stations/" + Property.type_of(sid), Vector2i(int(size[0]), int(size[1])))
		if bool(entry.get("flip", false)):
			draw_set_transform(c, 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, Rect2(c - sz * 0.5, sz), false, tint)
		var fp := Property.footprint(sid, entry)
		draw_rect(Rect2(_px(fp.position), fp.size * sc), Color("#20140c", 0.35), false, 1.0)
		_station_use(sid, c, sz)
		if sid == p.carrying or p.tab == "equipment":
			draw_string(Assets.font("body"), c + Vector2(-60, sz.y * 0.5 + 12), Property.instance_label(sid), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color("#20140c"))
