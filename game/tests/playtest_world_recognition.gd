## Rendered play-test phase "world_recognition" (R8 "World Recognition"): the Brindlewick muster receives a consignment
## of helms and shields; over the following weeks its patrols grow; the world map's page for the Highmarsh road says,
## from real values, that the patrols reach it and the bandits there are fewer; word of a deed sails out with a ship
## and a Highmarsh merchant comes in person, saying how they heard. Called from tests/playtest.gd.
extends RefCounted

var pt: Node


func _shot(name: String) -> void:
	await pt.wait(0.8)
	await pt.shot(name)


func run(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	var road := "highmarsh_road"
	var b0 := Militia.bandits_at(road)
	Institutions.receive("muster", "smith", [{"def": "helm_iron", "n": 12}, {"def": "shield_round", "n": 12}], [], 88.0, [], {"playtest": true})
	pt.expect(Militia.readiness() > 0.5, "world_recognition: the muster's kit is real (readiness %.2f)" % Militia.readiness())
	pt.expect(Militia.patrol() == 0.0, "world_recognition: no patrols the day the kit arrives")
	for d in 45:
		Game.advance_minutes(1440)
	await pt.wait(1.0)
	pt.expect(Militia.patrol() > 0.3, "world_recognition: after weeks the patrols walk (%.2f)" % Militia.patrol())
	pt.expect(Militia.bandits_at(road) < b0, "world_recognition: fewer bandits on the Highmarsh road (%d < %d)" % [Militia.bandits_at(road), b0])
	Events.open_panel.emit("world_map", {"site": road})
	await _shot("world_recognition_map")
	var ml: Node = pt.panel().find_child("MilitiaLine", true, false) if pt.panel() != null else null
	pt.expect(ml != null and str((ml as RichTextLabel).text).contains("%"), "world_recognition: the map states the patrols' real reach")
	await pt.close_panel()
	# word sails out, and a visitor comes for it
	Reputation.change(9.0, "the smith's helms turned an ambush on the Highmarsh road")
	var nm: Array = Trade.ship_type("spice")["names"][0]
	if not Trade.current_ship().is_empty():
		Trade._depart()
	Trade._dock("spice", str(nm[0]), str(nm[1]))
	Trade._depart()
	pt.expect(Reputation.word("traders", "region") > 0.0, "world_recognition: the region's traders heard it from the ship")
	var before := Visitors.log_list().size()
	for d in 6:
		Game.advance_minutes(1440)
		if Visitors.log_list().size() > before:
			break
	await pt.wait(1.0)
	var log := Visitors.log_list()
	pt.expect(log.size() > before, "world_recognition: a visitor came for the news")
	if log.size() > before:
		var v: Dictionary = log[-1]
		pt.note("world_recognition: %s came (via %s): %s" % [str(v["name"]), str(v["via"]), str(v["why"])])
	Events.open_panel.emit("history", {})
	await _shot("world_recognition_chronicle")
	await pt.close_panel()
