## Social — relationships and village memory (no visible meters).
## EN: Per NPC: familiarity (0..100), affection (-100..100), memories of meaningful events and a
##     romance stage. Changes ripple to relatives (family links from data/characters.json), so how
##     you treat an adventurer colours how their family sees you. Attitudes surface through
##     dialogue lines, behaviour and events — never as numbers on screen.
## DA: Pr. person: kendskab, hengivenhed, minder om betydningsfulde hændelser og romantikstadie.
##     Ændringer smitter af på slægtninge, så måden du behandler en eventyrer på, påvirker hvordan
##     familien ser dig. Holdninger vises gennem dialog, adfærd og hændelser — aldrig som tal.
class_name Social
extends RefCounted


static func init_all() -> void:
	for id in DB.characters:
		var k: String = DB.characters[id].get("kind", "")
		if k in ["adventurer", "villager", "hireling", "companion"]:
			ensure(id)
	# a little history so the village feels lived-in
	change("hilde", 12, 30, "", "", false)
	change("aldric", 6, 25, "", "", false)
	change("martha", 4, 20, "", "", false)
	change("borin", 20, 40, "", "", false)


static func ensure(npc: String) -> Dictionary:
	var s: Dictionary = Game.state["social"]
	if not s.has(npc):
		s[npc] = {"fam": 0.0, "aff": 0.0, "memories": [], "romance": "none", "last_talk": -1, "last_gift": -1, "dates": 0}
	return s[npc]


static func aff(npc: String) -> float:
	return float(ensure(npc)["aff"])


static func fam(npc: String) -> float:
	return float(ensure(npc)["fam"])


static func relatives(npc: String) -> Array:
	var out := []
	var c := DB.character(npc)
	for r in c.get("family", {}):
		out.append(r)
	for id in DB.characters:
		if DB.characters[id].get("family", {}).has(npc) and not out.has(id):
			out.append(id)
	return out


static func relation_word(npc: String, other: String) -> String:
	return str(DB.character(npc).get("family", {}).get(other, DB.character(other).get("family", {}).get(npc, "kin")))


## Main entry: adjust affection/familiarity, optionally store a memory, ripple to family.
static func change(npc: String, aff_delta: float, fam_delta: float, mem_key := "", mem_text := "", propagate := true) -> void:
	var e := ensure(npc)
	e["aff"] = clampf(float(e["aff"]) + aff_delta, -100.0, 100.0)
	e["fam"] = clampf(float(e["fam"]) + fam_delta, 0.0, 100.0)
	if mem_key != "":
		remember(npc, mem_key, mem_text, aff_delta)
	if propagate and absf(aff_delta) >= 2.0:
		for r in relatives(npc):
			var re := ensure(r)
			re["aff"] = clampf(float(re["aff"]) + aff_delta * 0.6, -100.0, 100.0)
			if mem_key != "" and absf(aff_delta) >= 6.0:
				var who: String = DB.character(npc).get("name", npc)
				remember(r, "kin_" + mem_key, "What the smith did for my %s, %s: %s" % [relation_word(r, npc), who, mem_text], aff_delta * 0.6)
	if mem_text != "":
		Events.relationship_event.emit(npc, mem_text)


static func remember(npc: String, key: String, text: String, weight: float) -> void:
	var e := ensure(npc)
	e["memories"].append({"day": Game.day(), "key": key, "text": text, "w": weight})
	if e["memories"].size() > 30:
		e["memories"].pop_front()


static func has_memory(npc: String, key: String) -> bool:
	for m in ensure(npc)["memories"]:
		if m["key"] == key:
			return true
	return false


static func strongest_memory(npc: String) -> Dictionary:
	var best := {}
	for m in ensure(npc)["memories"]:
		if best.is_empty() or absf(float(m["w"])) > absf(float(best["w"])):
			best = m
	return best


## Attitude band used to pick dialogue and behaviour.
static func band(npc: String) -> String:
	var a := aff(npc)
	if a <= -40.0:
		return "hostile"
	if a <= -10.0:
		return "cool"
	if a < 15.0:
		return "neutral"
	if a < 40.0:
		return "warm"
	if a < 70.0:
		return "friendly"
	return "devoted"


static func romance(npc: String) -> String:
	return ensure(npc).get("romance", "none")


static func set_romance(npc: String, stage: String) -> void:
	ensure(npc)["romance"] = stage


static func spouse() -> String:
	for id in Game.state["social"]:
		if Game.state["social"][id].get("romance", "") == "married":
			return id
	return ""
