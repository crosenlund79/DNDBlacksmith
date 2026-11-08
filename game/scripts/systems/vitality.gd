## Vitality — the blacksmith's fatigue (stub until implemented).
## DA: Smedens træthed.
class_name Vitality


## Multiplier for work effectiveness (1.0 = fresh; lower when tired).
static func work_factor() -> float:
	return 1.0


static func add_fatigue(_amount: float) -> void:
	pass
