## Rendered play-test phases of the overnight build "Beyond the Safe Roads" (canonical v1.6).
## beyond_map: the world map with the three dangerous regions revealed (Starfall Observatory, Weeping Fortress,
## Blackglass Rift), each site's page, and an observer on the road to one of them. Shots beyond_*.
## Called from tests/playtest.gd (phase_beyond_map).
extends RefCounted

const NEW := ["starfall_observatory", "weeping_fortress", "blackglass_rift"]

var pt: Node


func _shot(name: String) -> void:
	await pt.shot("beyond_%s" % name)


func run_map(p: Node) -> void:
	pt = p
	await pt.click("New Game")
	await pt.wait(2.5)
	# the places beyond: found from the dangerous places nearer home (their neighbours known too)
	for rid in ["ravens_hold", "sunken_temple", "drakes_crag"] + NEW:
		WorldSites.reveal(rid, "explored" if NEW.has(rid) else "rumour")
	for rid in NEW:
		pt.expect(WorldSites.is_discovered(rid) and Game.has_flag("site_" + rid), "beyond: %s is on the map and a destination" % rid)
	# a party bound for the Weeping Fortress, so the map shows a company on the road
	var ids := ["sigrun", "garrick", "tomas"]
	for id in ids:
		var a := Adv.get_a(id)
		a["status"] = "in_town"
		a["level"] = 9
	var e := Expeditions.start({"id": "p_beyond", "members": ids, "leader": ids[0], "dest": "weeping_fortress", "goal": "explore"})
	e["leg"]["t1"] = Game.now() + 180
	e["leg"]["t0"] = Game.now() - 60
	await pt.press("panel_world_map")
	await pt.wait(1.0)
	pt.expect(pt.panel() is WorldMapPanel, "beyond: the world map opens")
	await _shot("world_map")
	var wp := pt.panel() as WorldMapPanel
	if wp == null:
		return
	for rid in NEW:
		wp.select(rid)
		await pt.wait(0.6)
		await _shot("site_" + rid)
	await pt.close_panel()
	Events.open_panel.emit("observe", {"id": str(e["id"])})
	await pt.wait(1.0)
	await _shot("observer_fortress")
	await pt.close_panel()
