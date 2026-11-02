## Dice — tabletop dice for equipment generation (automatic or physical entry).
## EN: Expressions like "1d20", "2d6+1", "1d100". Automatic mode rolls here; physical mode lets the
##     player roll real dice and type the faces — both feed the same stat calculations.
## DA: Udtryk som "1d20" og "2d6+1". Automatisk tilstand slår her; fysisk tilstand lader
##     spilleren slå med rigtige terninger og indtaste værdierne — begge bruger samme beregning.
class_name Dice
extends RefCounted


static func parse(expr: String) -> Dictionary:
	var e := expr.strip_edges().to_lower()
	var mod := 0
	if e.contains("+"):
		var p := e.split("+")
		e = p[0]
		mod = int(p[1])
	var parts := e.split("d")
	var n := int(parts[0]) if parts[0] != "" else 1
	var sides := int(parts[1]) if parts.size() > 1 else 6
	return {"n": max(n, 1), "sides": max(sides, 2), "mod": mod}


static func roll(expr: String) -> Dictionary:
	var p := parse(expr)
	var faces: Array = []
	var total: int = p["mod"]
	for i in p["n"]:
		var f := randi_range(1, p["sides"])
		faces.append(f)
		total += f
	return {"expr": expr, "faces": faces, "total": total}


## Validates physical faces typed by the player. Returns {} if invalid.
static func from_faces(expr: String, faces: Array) -> Dictionary:
	var p := parse(expr)
	if faces.size() != p["n"]:
		return {}
	var total: int = p["mod"]
	for f in faces:
		var v := int(f)
		if v < 1 or v > int(p["sides"]):
			return {}
		total += v
	return {"expr": expr, "faces": faces, "total": total}


static func sides(expr: String) -> int:
	return int(parse(expr)["sides"])
