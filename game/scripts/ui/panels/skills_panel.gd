## SkillsPanel — Brannoc's skills, levels, progress and what each unlocks.
## DA: Brannocs færdigheder, niveauer, fremskridt og hvad hver låser op.
class_name SkillsPanel
extends UIWindow


func _init() -> void:
	super._init("Brannoc Ironhand — Skills", 1100, 760)


func _ready() -> void:
	super._ready()
	var h := UIKit.hbox(20)
	h.add_child(UIKit.portrait("portraits/player", 200))
	h.add_child(UIKit.rich("[font_size=30][b]Brannoc Ironhand[/b][/font_size]\n[i]Fifty-eight winters. Twenty of them spent adventuring, the rest hammering. The knee aches; the eye is gone; the hands remember everything.[/i]", 22))
	content.add_child(h)
	content.add_child(InkIcons.button("tb_skilltree", "Open the Skill Tree [%s]" % Settings.key_label("panel_skills"), func(): Events.open_panel.emit("skilltree", {}), 320))
	content.add_child(UIKit.divider())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	var sk := Game.player_skills()
	for s in DB.skill_list:
		var id: String = s["id"]
		grid.add_child(UIKit.label(s["name"] + (" ✦" if s.get("advanced", false) else ""), 24, "heading"))
		grid.add_child(UIKit.label("Level %d" % SkillSys.level(sk, id), 22, "body_bold", UIKit.RUBRIC))
		grid.add_child(UIKit.bar(SkillSys.progress(sk, id), 1.0, 200))
		var d := UIKit.label(s["desc"], 18, "body_italic")
		d.custom_minimum_size = Vector2(420, 0)
		grid.add_child(d)
	content.add_child(grid)
	content.add_child(UIKit.divider())
	content.add_child(UIKit.rich("[b]Specialisations[/b]  ✦ Arcane Metalworking unlocks with the Arcane Foundry (Runecraft 3 + mithril found).  ✦ Enchanted Stitching 3 opens the Thread Spinner, Embroidery Frame and Fitting Mannequin.  Higher discipline skill widens check zones, slows the needle and adds to final quality.", 19))
