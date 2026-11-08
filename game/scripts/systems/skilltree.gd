## SkillTree — the blacksmith's branching progression (stub: everything open until implemented).
## DA: Smedens færdighedstræ.
class_name SkillTree


static func init_new() -> void:
	pass


## "" when the station may be used, otherwise the reason (shown in tooltips).
static func station_reason(_station_id: String) -> String:
	return ""


## "" when the recipe is known and allowed, otherwise the reason.
static func recipe_reason(_recipe_id: String) -> String:
	return ""
