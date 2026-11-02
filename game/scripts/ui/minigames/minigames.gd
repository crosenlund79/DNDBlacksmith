## Minigames — picks the skill check for a station.
## EN: data/crafting.json "minigames" maps station ids to a specialised check
##     (align, edge, multihit, rune, rings). Stations without an entry keep the original circular
##     precision ring (SkillCheckPanel). args may force one with "minigame": "<type>" or "ring".
## DA: Vælger færdighedsprøven for en station ud fra data; ellers den klassiske ring.
class_name Minigames
extends RefCounted

const TYPES := ["align", "edge", "multihit", "rune", "rings"]


static func config_for(station: String) -> Dictionary:
	var all: Dictionary = DB.crafting.get("minigames", {})
	var c: Variant = all.get(station, {})
	return c if c is Dictionary else {}


static func type_for(args: Dictionary) -> String:
	if args.has("minigame"):
		return str(args["minigame"])
	return str(config_for(str(args.get("station", ""))).get("type", "ring"))


static func create(args: Dictionary) -> Control:
	var c := config_for(str(args.get("station", "")))
	match type_for(args):
		"align":
			return AlignGame.new(args, c)
		"edge":
			return EdgeGame.new(args, c)
		"multihit":
			return MultiHitGame.new(args, c)
		"rune":
			return RuneGame.new(args, c)
		"rings":
			return RingsGame.new(args, c)
	return SkillCheckPanel.new(args)


static func label(type: String) -> String:
	return {"align": "Spark & Ember alignment", "edge": "Edge control", "multihit": "Multi-hit sequence",
		"rune": "Rune stabilisation", "rings": "Ring contact"}.get(type, "Precision ring")
