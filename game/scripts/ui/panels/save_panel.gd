## SavePanel — save to / load from the versioned slots.
## DA: Gem i / indlæs fra de versionerede pladser.
class_name SavePanel
extends UIWindow

var mode := "save"


func _init(m: String) -> void:
	mode = m
	super._init("Save Game" if m == "save" else "Load Game", 820, 600)


func _ready() -> void:
	super._ready()
	for slot in Saves.SLOTS:
		if mode == "save" and slot in ["autosave", "quicksave"]:
			continue
		var m := Saves.meta(slot)
		var desc := "— empty —" if m.is_empty() else "Day %d, %s · %d gold · saved %s" % [int(m.get("day", 0)), m.get("time", ""), int(m.get("gold", 0)), m.get("saved_at", "")]
		if int(m.get("seed", -1)) >= 0:
			desc += " · world seed %d" % int(m["seed"])   # The Living Realm: the campaign's world seed
		var nv := Saves.newer_schema(slot)   # a newer build's save: shown, explained, never loaded or overwritten here
		if nv > 0:
			desc = "made by a newer version of Ember & Ash (save format %d) — kept exactly as it is" % nv
		var row := UIKit.hbox(12)
		var lab := UIKit.label("%s: %s" % [slot.replace("_", " ").capitalize(), desc], 21)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var s: String = slot
		var b := UIKit.button("Save" if mode == "save" else "Load", func():
			if mode == "save":
				if Saves.save(s):
					Events.toast.emit("Saved to %s." % s, "good")
					Objectives.complete("save_game")
				close()
			else:
				close()
				get_tree().root.get_node("Main").call("load_slot", s), 140)
		b.disabled = (mode == "load" and m.is_empty()) or nv > 0
		if nv > 0:
			b.tooltip_text = Saves.newer_text(nv)
			lab.tooltip_text = Saves.newer_text(nv)
			lab.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(b)
		content.add_child(row)
