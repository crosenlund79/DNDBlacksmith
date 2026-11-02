## AdventurersPanel — who is active around Brindlewick, their approximate abilities and gear.
## EN: Information is approximate (no exact hidden numbers); rumours from the Velvet Lantern add detail.
## DA: Oplysningerne er omtrentlige; rygter fra Velvet Lantern giver flere detaljer.
class_name AdventurersPanel
extends UIWindow


func _init() -> void:
	super._init("Adventurers of the Tipsy Wyvern", 1500, 840)


func _ready() -> void:
	super._ready()
	var body := UIKit.vbox(10)
	var list := Adv.all().values()
	list.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	for a in list:
		var row := UIKit.hbox(16)
		var p := UIKit.portrait("portraits/" + str(a["id"]), 116)
		if a["status"] == "dead":
			p.modulate = Color(0.5, 0.45, 0.42)
		row.add_child(p)
		var where := ""
		match a["status"]:
			"in_town": where = "In Brindlewick (usually at the Wyvern)"
			"injured": where = "Recovering at the inn"
			"away": where = "Away at %s%s" % [DB.destinations[a["dest"]]["name"], (" — back in about %d day%s" % [int(a["days_left"]), "" if int(a["days_left"]) == 1 else "s"]) if Game.has_flag("rumour_" + a["id"]) or Social.fam(a["id"]) >= 25 else ""]
			"dead": where = "Fallen"
		var attitude: String = {"hostile": "resents you", "cool": "is cool towards you", "neutral": "knows you by sight", "warm": "likes you", "friendly": "counts you a friend", "devoted": "would walk through fire for you"}.get(Social.band(a["id"]), "")
		var rom := Social.romance(a["id"])
		if rom in ["dating", "courting", "married"]:
			attitude += {"dating": " · you've been sharing drinks", "courting": " · you are courting", "married": " · [color=#7e2418]your wife[/color]"}[rom]
		var gear := []
		for s in a["equipment"]:
			var it: Dictionary = a["equipment"][s]
			gear.append("[color=#%s]%s[/color]" % [Items.color(it, false).to_html(false), Items.display_name(it)])
		var lab := UIKit.rich("[font_size=28][b]%s[/b][/font_size]  ·  %s %s, level %d  ·  [i]%s[/i]\n%s · %s\nGear: %s\n[color=#5e421c]%s[/color]" % [
			a["name"], Adv.rating_text(a), a["cls"], a["level"], DB.character(a["id"]).get("personality", ""),
			where, "She " + attitude if DB.character(a["id"]).get("look", {}).get("female", false) else "He " + attitude,
			", ".join(gear) if not gear.is_empty() else "—", a.get("last_report", "")], 20)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		body.add_child(row)
		body.add_child(UIKit.divider())
	content.add_child(UIKit.scroll(body, 680))
