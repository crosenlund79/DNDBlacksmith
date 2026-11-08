## WorkshopServices — station-panel sections for the services that add to a piece's history:
## sharpening adventurers' blades at the grinding wheel and reforging a piece at the anvil (with the forge).
## Both run a skill check, then ItemStory.sharpen / ItemStory.reforge record a Provenance.workshop event; the
## result is shown on a parchment card (FamiliarCard, mode "service"). Enchanting and treatment already exist
## (Rune Engraving Stand, Infusion Rack).
## DA: Værkstedsydelser: slibning ved slibestenen og omsmedning ved ambolten — begge skriver i genstandens historie.
class_name WorkshopServices
extends RefCounted


## The services section for a station ({} = none here). Returns null when the station offers none.
static func build(station_id: String) -> Control:
	match station_id:
		"grinding_wheel":
			return _sharpen_ui()
		"anvil":
			return _reforge_ui()
	return null


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


static func _reforge_ui() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("Reforge a piece", 26, "heading"))
	v.add_child(UIKit.label("Rework a piece at forge and anvil: it is made whole, and fine work can raise its craftsmanship a little. The maker's mark and any earned name are kept. One coal.", 18, "body_italic"))
	var items := Game.inventory().filter(func(x): return Items.is_equipment(x))
	if items.is_empty():
		v.add_child(UIKit.label("Nothing in your stores to rework.", 19, "body_italic"))
		return v
	var h := UIKit.hbox()
	var ob := OptionButton.new()
	ob.name = "ReforgeChoice"
	for x in items:
		ob.add_item("%s (%d%%)" % [Items.display_name(x), int(round(float(x.get("quality", 0))))], int(x["uid"]))
	h.add_child(ob)
	var b := UIKit.button("Reforge (1 coal)", func():
		var u := ob.get_item_id(maxi(0, ob.selected))
		if Game.count("coal") < 1:
			Events.toast.emit("You need a sack of coal to heat the forge for reforging.", "bad")
			return
		var c := Crafting.check_params("anvil")
		Events.open_panel.emit("skillcheck", {"station": "anvil", "count": 1, "speed": c["speed"], "zone": c["zone"], "title": "Reforging at the anvil",
			"on_done": func(qs: Array): reforge_done(u, float(qs[0]))}), 240)
	b.disabled = Game.count("coal") < 1
	b.tooltip_text = "" if Game.count("coal") >= 1 else "You need coal."
	h.add_child(b)
	v.add_child(h)
	return v


static func reforge_done(uid: int, q: float) -> void:
	var r := ItemStory.reforge(uid, q)
	if not bool(r.get("ok", false)):
		Events.toast.emit(str(r.get("text", "")), "bad")
		return
	Audio.play("sfx/hammer_2", -4.0)
	Events.open_panel.emit("familiar", {"mode": "service", "uid": uid, "result": r})
