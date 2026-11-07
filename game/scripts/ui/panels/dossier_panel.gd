## DossierPanel — a parchment dossier for one adventurer: who they are, what they can do, what they
## carry (the actual item instances — the smith's own work shown with its real name, stats, history),
## how they are, whom they like, what they have done, and where they are now.
## EN: On Master difficulty, numbers you have not earned are approximate: strangers show ranges and
##     gear by kind until familiarity (talk, drinks, equipping them) or rumours reveal more.
## DA: Et dossier for én eventyrer. På Mester-sværhed er ukendte tal omtrentlige.
class_name DossierPanel
extends UIWindow

var adv_id := ""


func _init(id: String) -> void:
	adv_id = id
	blocks_time = false
	super._init("", 1500, 900, false)
	if Assets.has_tex("ui/dossier"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.get_tex("ui/dossier")
		sb.texture_margin_left = 60
		sb.texture_margin_right = 60
		sb.texture_margin_top = 60
		sb.texture_margin_bottom = 60
		sb.content_margin_left = 48
		sb.content_margin_right = 48
		sb.content_margin_top = 36
		sb.content_margin_bottom = 36
		add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	super._ready()
	_build()
	Events.expeditions_changed.connect(_build)


## How much the smith may know: everything on easier settings; on Master, familiarity decides.
func _know() -> float:
	if bool(Expeditions.diff().get("detail", true)):
		return 100.0
	return Social.fam(adv_id) + (25.0 if Game.has_flag("rumour_" + adv_id) else 0.0)


func _build() -> void:
	if not is_inside_tree():
		return
	UIKit.clear(content)
	var a := Adv.get_a(adv_id)
	Expeditions.ensure(a)
	var k := _know()
	var c := DB.character(adv_id)
	title_label.text = "%s — %s" % [a["name"], Expeditions.renown_title(a)]
	var top := UIKit.hbox(24)
	var left := UIKit.vbox(6)
	left.custom_minimum_size = Vector2(300, 0)
	var por := UIKit.portrait("portraits/" + adv_id, 240)
	if a["status"] == "dead":
		por.modulate = Color(0.55, 0.5, 0.48)
	left.add_child(por)
	left.add_child(UIKit.rich("[b]%s[/b], level %s %s\n[i]%s[/i]\n%s" % [a["name"], str(a["level"]) if k >= 25 else "%d–%d" % [maxi(1, int(a["level"]) - 1), int(a["level"]) + 2],
		a["cls"], c.get("personality", ""), Adv.TRAITS.get(a.get("trait", ""), "")], 20))
	var sw := Expeditions.status_word(a)
	var where := sw
	if a["status"] == "away":
		where += " — " + Expeditions.region(str(a.get("dest", ""))).get("name", "")
	left.add_child(UIKit.label(where, 22, "body_bold", WantedPanel.STATUS_COL.get(sw, UIKit.INK)))
	var ex := Expeditions.exp_of(adv_id)
	if not ex.is_empty() and Expeditions.can_observe():
		var eid: String = ex["id"]
		left.add_child(UIKit.button("Observe Expedition", func(): Events.open_panel.emit("observe", {"id": eid}), 260))
	top.add_child(left)
	# --- middle: condition, attributes, skills
	var mid := UIKit.vbox(6)
	mid.custom_minimum_size = Vector2(470, 0)
	mid.add_child(UIKit.label("Condition", 26, "heading"))
	if k >= 20.0:
		var hpb := UIKit.hbox(8)
		hpb.add_child(UIKit.label("Health %d / %d" % [maxi(0, int(a["hp"])), int(a["hp_max"])], 20, "body_bold"))
		hpb.add_child(UIKit.bar(maxf(0.0, float(a["hp"])), float(a["hp_max"]), 200))
		mid.add_child(hpb)
		mid.add_child(UIKit.label("Fatigue %d · morale %d · carries %d healing draught%s" % [int(a["fatigue"]), int(a["morale"]), int(a.get("potions", 0)), "" if int(a.get("potions", 0)) == 1 else "s"], 19))
	else:
		mid.add_child(UIKit.label("You don't know them well enough to say how they really are.", 19, "body_italic"))
	if a["status"] == "injured":
		mid.add_child(UIKit.label("Injured — resting %d more day%s" % [int(a.get("injured_days", 0)), "" if int(a.get("injured_days", 0)) == 1 else "s"], 19, "body_bold", UIKit.RUBRIC))
	mid.add_child(UIKit.label("Attributes & skills", 26, "heading"))
	var at := []
	for key in ["str", "dex", "int", "wis", "con"]:
		at.append("%s %s" % [key.to_upper(), ("%+d" % Expeditions.attr(a, key)) if k >= 30 else "?"])
	mid.add_child(UIKit.label("   ".join(at), 20, "body_bold"))
	var wp := Expeditions.weapon_profile(a)
	if k >= 30:
		mid.add_child(UIKit.rich("Defence [b]%d[/b] (10 + dex + protection ×0.25) · to-hit [b]%+d[/b] · damage [b]%.0f[/b] per blow before damage types\nFire %d · frost %d · magic %d · ward %d" % [
			Expeditions.defence(a), int(wp["to_hit"]), float(wp["base"]), Expeditions.total(a, "fire"), Expeditions.total(a, "frost"), Expeditions.total(a, "magic"), Expeditions.total(a, "ward")], 19))
	var sk: Array = Expeditions.arch(a).get("skills", [])
	mid.add_child(UIKit.rich("Skills: [i]%s[/i] · fights best with a %s" % [", ".join(sk.map(func(x): return str(x).replace("_", " "))), " or ".join(Expeditions.arch(a).get("prefers", []))], 19))
	top.add_child(mid)
	# --- right: relationships
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("Relationships", 26, "heading"))
	var att: String = {"hostile": "resents you", "cool": "is cool towards you", "neutral": "knows you by sight", "warm": "likes you", "friendly": "counts you a friend", "devoted": "would walk through fire for you"}.get(Social.band(adv_id), "")
	var rom := Social.romance(adv_id)
	right.add_child(UIKit.rich("With the smith: [b]%s[/b]%s" % [att, {"dating": " · you've been sharing drinks", "courting": " · you are courting", "married": " · [color=#7e2418]your wife[/color]", "widowed": " · [color=#7e2418]your late wife[/color]"}.get(rom, "")], 19))
	var friends := []
	var rivals := []
	for oid in a.get("relations", {}):
		var v := float(a["relations"][oid])
		var o := Adv.get_a(oid)
		if o.is_empty():
			continue
		if v >= 20.0:
			friends.append(o["name"])
		elif v <= -20.0:
			rivals.append(o["name"])
	right.add_child(UIKit.rich("Friends: %s\nRivals: %s" % [", ".join(friends) if not friends.is_empty() else "—", ", ".join(rivals) if not rivals.is_empty() else "—"], 19))
	right.add_child(UIKit.label("Record", 26, "heading"))
	right.add_child(UIKit.rich("%d expeditions · %d won · %d foes felled · %d gold of loot · renown %d%s" % [int(a.get("expeditions", 0)), int(a.get("victories", 0)), int(a.get("kills", 0)),
		int(a.get("loot_value", 0)), int(a.get("renown", 0)), (" · cheated death %d×" % int(a["deaths_cheated"])) if int(a.get("deaths_cheated", 0)) > 0 else ""], 19))
	var ach: Array = a.get("achievements", [])
	if not ach.is_empty():
		right.add_child(UIKit.rich("\n".join(ach.slice(maxi(0, ach.size() - 5)).map(func(x): return "• Day %d — %s" % [int(x["day"]), x["text"]])), 18))
	top.add_child(right)
	content.add_child(top)
	content.add_child(UIKit.divider())
	# --- equipment: the actual instances
	content.add_child(UIKit.label("Carried — hover for the full item, its maker and its history", 24, "heading"))
	var eqrow := UIKit.hbox(10)
	for slot in ["weapon", "armor", "shield", "helmet", "gloves", "boots", "belt", "ring", "amulet"]:
		var it: Dictionary = a["equipment"].get(slot, {})
		var col := UIKit.vbox(2)
		var mine := str(it.get("crafted_by", "")).begins_with("Brannoc")
		if k >= 15.0 or mine or it.is_empty():
			col.add_child(ItemSlot.new(it, 78.0))
			col.add_child(UIKit.label((Items.display_name(it) + (" ⚒" if mine else "")) if not it.is_empty() else slot.capitalize(), 15, "body", Items.color(it, false) if not it.is_empty() else Color("#8a7a60")))
			if not it.is_empty() and it.get("stats", {}).has("durability_max"):
				col.add_child(UIKit.label("dur. %d/%d%s" % [int(it["stats"]["durability"]), int(it["stats"]["durability_max"]), " BROKEN" if it.get("broken", false) else ""], 14, "body_italic", UIKit.RUBRIC if it.get("broken", false) else UIKit.INK))
		else:
			col.add_child(ItemSlot.new({}, 78.0))
			col.add_child(UIKit.label("a %s" % Items.type_label(it).to_lower(), 15, "body_italic"))
		col.custom_minimum_size = Vector2(140, 0)
		eqrow.add_child(col)
	content.add_child(eqrow)
	# --- notable victories and defeats, from the chronicle
	var notes := Chronicle.about(adv_id, ["victory", "death", "missing", "rescue", "legend", "chain", "levelup", "return"]).slice(-6)
	if not notes.is_empty():
		content.add_child(UIKit.rich("[color=#5e421c]%s[/color]" % "\n".join(notes.map(func(e): return "Day %d %s — %s" % [int(e["day"]), e["time"], e["text"]])), 17))
