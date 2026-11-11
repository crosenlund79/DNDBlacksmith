## SavePanel — save to / load from the versioned slots.
## EN: Living Workshop #42: ten slots of the player's own (Saves.MANUAL_SLOTS) plus the autosave and the quick-save on
##     the Load screen, as one compact list (slot · day, time, purse, when saved · button) that scrolls when it must.
##     Every write is the atomic, verified write with a .bak of the previous save (Saves.save, A1); a save from a newer
##     build is listed, explained and never loaded or overwritten here.
## DA: Gem i / indlæs fra de versionerede pladser — ti egne pladser, autosave og hurtiggem, som én kompakt liste.
class_name SavePanel
extends UIWindow

var mode := "save"
var rows: VBoxContainer


func _init(m: String) -> void:
	mode = m
	super._init("Save Game" if m == "save" else "Load Game", 1000, 0)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label(
		"Ten slots of your own. Saving over a slot keeps the save it replaces as a backup." if mode == "save"
		else "Your ten slots, the autosave and the quick-save. Choose a game to continue.", UIKit.FS_SMALL, "body_italic"))
	rows = UIKit.vbox(4)
	rows.name = "SlotRows"
	var slots: Array = Saves.manual_slots() if mode == "save" else Saves.SLOTS
	for slot in slots:
		rows.add_child(_row(str(slot)))
	# 12 rows of ~44 px fit the canvas without a scroll; the scroll stays for safety on unusual setups
	content.add_child(UIKit.scroll(rows, mini(slots.size() * 46, 600)))


## One slot: its name, what is in it and the action. Named "SlotRow_<slot>" (tests, play-tests).
func _row(slot: String) -> Control:
	var m := Saves.meta(slot)
	var nv := Saves.newer_schema(slot)   # a newer build's save: shown, explained, never loaded or overwritten here
	var bak := m.is_empty() and FileAccess.file_exists(Saves.path(slot).trim_suffix(".json") + ".bak")
	var desc := "— empty —"
	if not m.is_empty():
		desc = "Day %d, %s · %d gold · saved %s" % [int(m.get("day", 0)), m.get("time", ""), int(m.get("gold", 0)), str(m.get("saved_at", "")).replace("T", " ").left(16)]
		if int(m.get("seed", -1)) >= 0:
			desc += " · world seed %d" % int(m["seed"])   # The Living Realm: the campaign's world seed
	elif bak:
		desc = "— only a backup copy (loading uses it) —"
	if nv > 0:
		desc = "made by a newer version of Ember & Ash (save format %d) — kept exactly as it is" % nv
	var row := PanelContainer.new()
	row.name = "SlotRow_" + slot
	row.add_theme_stylebox_override("panel", UIKit.row_style(not m.is_empty() or bak))
	var h := UIKit.hbox(12)
	row.add_child(h)
	var nm := UIKit.label(Saves.slot_label(slot), UIKit.FS_BODY, "body_bold", UIKit.INK if slot.begins_with("slot_") else UIKit.RUBRIC)
	nm.custom_minimum_size = Vector2(118, 0)
	h.add_child(nm)
	var lab := UIKit.label(desc, UIKit.FS_SMALL, "body" if not m.is_empty() else "body_italic")
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long line wraps inside the row, never off the window
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lab)
	var s := slot
	var b := UIKit.button("Save" if mode == "save" else "Load", func():
		if mode == "save":
			if Saves.save(s):
				Events.toast.emit("Saved to %s." % Saves.slot_label(s), "good")
				Objectives.complete("save_game")
			close()
		else:
			close()
			get_tree().root.get_node("Main").call("load_slot", s), 120)
	b.name = "SlotButton_" + slot
	b.disabled = (mode == "load" and m.is_empty() and not bak) or nv > 0
	if mode == "save" and not m.is_empty() and nv == 0:
		b.tooltip_text = "Replaces the save in %s — the one it replaces is kept as a backup." % Saves.slot_label(slot)
	if nv > 0:
		b.tooltip_text = Saves.newer_text(nv)
		lab.tooltip_text = Saves.newer_text(nv)
		lab.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(b)
	return row
