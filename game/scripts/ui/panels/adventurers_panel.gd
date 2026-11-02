## AdventurersPanel — who is active around Brindlewick: class, approximate level and capabilities,
## gear, condition, whereabouts, how they regard the smith, and what happened on their last trip.
## EN: Accuracy grows with familiarity (talk to them, drink with them, equip them) and with rumours
##     from the Velvet Lantern: strangers show a level range and gear by kind; acquaintances show
##     exact levels, named gear and the story of their last expedition.
## DA: Nøjagtigheden vokser med kendskab og rygter: fremmede vises med niveau-interval, bekendte
##     med præcise oplysninger og historien om sidste ekspedition.
class_name AdventurersPanel
extends UIWindow


func _init() -> void:
	super._init("Adventurers of the Tipsy Wyvern", 1600, 880)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("What you know depends on how well you know them — talk, share a drink, equip them, or pay for rumours at the Velvet Lantern.", 19, "body_italic"))
	var body := UIKit.vbox(10)
	var list := Adv.all().values()
	list.sort_custom(func(a, b): return Social.fam(a["id"]) > Social.fam(b["id"]))
	for a in list:
		Adv.ensure(a)
		body.add_child(_row(a))
		body.add_child(UIKit.divider())
	content.add_child(UIKit.scroll(body, 700))


func _know(a: Dictionary) -> float:
	return Social.fam(a["id"]) + (25.0 if Game.has_flag("rumour_" + a["id"]) else 0.0)


func _row(a: Dictionary) -> Control:
	var k := _know(a)
	var row := UIKit.hbox(16)
	var p := UIKit.portrait("portraits/" + str(a["id"]), 116)
	if a["status"] == "dead":
		p.modulate = Color(0.5, 0.45, 0.42)
	row.add_child(p)
	var lv := int(a["level"])
	var level_txt := ("level %d" % lv) if k >= 25.0 else ("around level %d–%d" % [maxi(1, lv - 1), lv + 2])
	var where := ""
	match a["status"]:
		"in_town": where = "In Brindlewick" + ((" — means to head for %s next" % DB.destinations[a["next_dest"]]["name"]) if a.has("next_dest") and k >= 20.0 else "")
		"injured": where = "Recovering at the inn (%d day%s)" % [int(a["injured_days"]), "" if int(a["injured_days"]) == 1 else "s"]
		"away": where = "Away at %s%s" % [DB.destinations[a["dest"]]["name"], (" — back in about %d day%s" % [int(a["days_left"]), "" if int(a["days_left"]) == 1 else "s"]) if k >= 25.0 else ""]
		"dead": where = "Fallen"
	var female: bool = DB.character(a["id"]).get("look", {}).get("female", false)
	var attitude: String = {"hostile": "resents you", "cool": "is cool towards you", "neutral": "knows you by sight", "warm": "likes you", "friendly": "counts you a friend", "devoted": "would walk through fire for you"}.get(Social.band(a["id"]), "")
	var rom := Social.romance(a["id"])
	if rom in ["dating", "courting", "married", "widowed"]:
		attitude += {"dating": " · you've been sharing drinks", "courting": " · you are courting", "married": " · [color=#7e2418]your wife[/color]", "widowed": " · [color=#7e2418]your late wife[/color]"}[rom]
	var gear := []
	for s in a["equipment"]:
		var it: Dictionary = a["equipment"][s]
		if k >= 15.0 or str(it.get("crafted_by", "")).begins_with("Brannoc"):
			var mark := " ⚒" if str(it.get("crafted_by", "")).begins_with("Brannoc") else ""
			gear.append("[color=#%s]%s[/color]%s" % [Items.color(it, false).to_html(false), Items.display_name(it), mark])
		else:
			gear.append("a %s" % Items.type_label(it).to_lower())
	var cond := ""
	if int(a.get("potions", 0)) > 0 and k >= 20.0:
		cond = " · carries %d healing draught%s" % [int(a["potions"]), "" if int(a["potions"]) == 1 else "s"]
	var hist: Array = a.get("history", [])
	var record := ""
	if not hist.is_empty() and k >= 10.0:
		var wins := 0
		var trips := 0
		for e in hist:
			trips += 1
			if str(e["outcome"]).begins_with("success"):
				wins += 1
		record = " · %d of their last %d trips went well" % [wins, trips]
	var lines := "[font_size=28][b]%s[/b][/font_size]  ·  %s %s, %s  ·  [i]%s[/i]\n%s · %s%s\n%s%s · %s\nGear: %s" % [
		a["name"], Adv.rating_text(a), a["cls"], level_txt, Adv.TRAITS.get(a["trait"], ""),
		where, ("She " if female else "He ") + attitude, cond,
		(Adv.skills_text(a).left(1).to_upper() + Adv.skills_text(a).substr(1)) if k >= 15.0 else "Capabilities: hard to judge yet", record, "%d expeditions" % int(a["expeditions"]),
		", ".join(gear) if not gear.is_empty() else "—"]
	if k >= 10.0 and not a.get("log", []).is_empty():
		lines += "\n[color=#5e421c][i]%s[/i][/color]" % "  ".join(a["log"])
	elif a.get("last_report", "") != "":
		lines += "\n[color=#5e421c]%s[/color]" % a["last_report"]
	var lab := UIKit.rich(lines, 19)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	return row
