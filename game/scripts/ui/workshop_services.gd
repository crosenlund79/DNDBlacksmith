## WorkshopServices — station-panel sections for the services that add to a piece's history:
## sharpening adventurers' blades at the grinding wheel, and improving the smith's own pieces (Refinement: refine,
## rework, upgrade, reforge) — a short "at a glance" block that opens the improvement bench (RefinePanel).
## Every service records ONE Provenance.workshop event; the result is shown with a before / after comparison.
## Enchanting and treatment already exist (Rune Engraving Stand, Infusion Rack).
## DA: Værkstedsydelser: slibning ved slibestenen og forbedring af udstyr — alt skrives i genstandens historie.
class_name WorkshopServices
extends RefCounted


## The services section for a station. Returns null when the station offers none.
static func build(station_id: String) -> Control:
	var v := UIKit.vbox(10)
	if station_id == "grinding_wheel":
		v.add_child(_sharpen_ui())
	if not Refinement.actions_at(station_id).is_empty():
		if v.get_child_count() > 0:
			v.add_child(UIKit.divider())
		v.add_child(_improve_ui(station_id))
	if v.get_child_count() == 0:
		v.free()
		return null
	return v


static func _sharpen_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Sharpen a blade", 26, "heading"))
	v.add_child(UIKit.label("A fresh edge: +attack for two expeditions and a little wear taken off. Adventurers in town pay a small fee. Written into the blade's history.", 18, "body_italic"))
	var h := UIKit.hbox()
	var ob := OptionButton.new()
	ob.name = "SharpenChoice"
	var choices := []
	for pair in ItemStory.blades_in_town():
		var aid: String = pair[0]
		var w: Dictionary = pair[1]
		ob.add_item("%s's %s" % [Talk.npc_name(aid), Items.display_name(w)])
		choices.append([aid, int(w["uid"])])
	for it in Game.inventory():
		if Items.slot(it) == "weapon":
			ob.add_item("Your stores: %s" % Items.display_name(it))
			choices.append(["", int(it["uid"])])
	if choices.is_empty():
		v.add_child(UIKit.label("No blade to sharpen: no adventurer in town carries one and your stores hold none.", 19, "body_italic"))
		return v
	h.add_child(ob)
	h.add_child(UIKit.button("Sharpen at the wheel", func():
		var ch: Array = choices[maxi(0, ob.selected)]
		var c := Crafting.check_params("grinding_wheel")
		Events.open_panel.emit("skillcheck", {"station": "grinding_wheel", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Sharpening at the grinding wheel",
			"on_done": func(qs: Array): sharpen_done(str(ch[0]), int(ch[1]), float(qs[0]))}), 280))
	v.add_child(h)
	return v


static func sharpen_done(aid: String, uid: int, q: float) -> void:
	var it := ItemStory.find(uid)
	var r := ItemStory.sharpen(it, q, aid)
	if not bool(r.get("ok", false)):
		Events.toast.emit(str(r.get("text", "")), "bad")
		return
	Audio.play("sfx/grind", -4.0)
	Events.open_panel.emit("familiar", {"mode": "service", "uid": uid, "result": r})


## Improving the smith's own pieces here: what this station does, the best candidate and its one obstacle, and
## the button that opens the improvement bench (before / after, the check, the result).
static func _improve_ui(station_id: String) -> Control:
	var v := UIKit.vbox(6)
	var here: Array = Refinement.actions_at(station_id)
	var names := PackedStringArray()
	for a in here:
		names.append(str(Refinement.LABEL[a]))
	v.add_child(UIKit.label("Improve a piece — " + " · ".join(names), 26, "heading"))
	var items := Game.inventory().filter(func(x): return Items.is_equipment(x))
	if items.is_empty():
		v.add_child(UIKit.label("Nothing in your stores to improve.", 19, "body_italic"))
		return v
	# at a glance: how many pieces could take each action here right now
	var bits := PackedStringArray()
	for a in here:
		var n := 0
		var why := ""
		for x in items:
			var p := Refinement.plan(x, a, {"station": station_id})
			if bool(p["ok"]) and str(p["station"]) == station_id:
				n += 1
			elif why == "" and str(p["station"]) == station_id:
				why = str(p["why"])
		bits.append(("[b]%s[/b] %d piece%s ready" % [Refinement.LABEL[a], n, "" if n == 1 else "s"]) if n > 0 else
			"[b]%s[/b] [color=#9a2a14]%s[/color]" % [Refinement.LABEL[a], why if why != "" else "not here for these pieces"])
	v.add_child(UIKit.rich(" · ".join(bits), 19))
	var b := UIKit.button("Open the improvement bench (before / after)", func():
		Events.open_panel.emit("refine", {"station": station_id}), 0)
	b.name = "OpenRefine"
	v.add_child(b)
	return v


static func reforge_done(uid: int, q: float) -> void:
	var r := ItemStory.reforge(uid, q)
	if not bool(r.get("ok", false)):
		Events.toast.emit(str(r.get("text", "")), "bad")
		return
	Audio.play("sfx/hammer_2", -4.0)
	Events.open_panel.emit("familiar", {"mode": "service", "uid": uid, "result": r})
