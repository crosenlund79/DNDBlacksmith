## The F10 developer catalogue (UX iteration): searching every item, spawning with quantity / rarity / craftsmanship,
## adding money (ledger "Developer tools"), and developer items never counting for anything earned — Hall of Fame,
## Epic, names, objectives, the skill tree's "items seen", knowledge flags, the encyclopedia, apprentices' fame.
extends SuiteCase

const SMOKE := ["test_search_and_spawn", "test_dev_items_earn_nothing"]


func test_search_and_spawn() -> void:
	fresh_game()
	check(DevTools.spawn("sword_iron", 1).is_empty(), "S2: with cheats off nothing spawns")
	DevTools.set_enabled(true)   # S2: the developer tools work only while cheats are switched on for the session
	eq(DevTools.search("").size(), DB.items.size(), "an empty search lists every item")
	var found := DevTools.search("longsword")
	check(found.any(func(d): return str(d["id"]) == "sword_iron"), "searching 'longsword' finds the Iron Longsword")
	check(DevTools.search("sword_iron").any(func(d): return str(d["id"]) == "sword_iron"), "searching by id works")
	var weapons := DevTools.search("", 1)
	check(not weapons.is_empty() and weapons.all(func(d): return str(d.get("type", "")) == "weapon"), "the Weapons filter lists only weapons")
	check(DevTools.search("coal", 1).is_empty(), "coal is not a weapon")
	var n0 := Game.inventory().size()
	var made := DevTools.spawn("sword_iron", 2, "rare", 110.0)
	eq(made.size(), 2, "two swords spawned")
	eq(Game.inventory().size(), n0 + 2, "both in the stores")
	if made.size() < 2:
		return
	var a: Dictionary = made[0]
	var b: Dictionary = made[1]
	check(int(a["uid"]) > 0 and int(a["uid"]) != int(b["uid"]), "each has its own valid uid")
	eq(str(a["rarity"]), "rare", "with the chosen rarity")
	eq(int(round(float(a["quality"]))), 110, "with the chosen craftsmanship")
	check(bool(a.get("dev", false)), "marked as a developer item")
	eq(str(Provenance.maker(a).get("name", "")), "Developer tools", "maker: Developer tools")
	eq(str(Provenance.maker(a).get("mark", "")), "unknown", "no maker's mark")
	eq(Provenance.owner_id(a), Provenance.SMITH_ID, "held by the smith")
	check(not (Provenance.st(a).get("events", []) as Array).is_empty(), "with a provenance record")
	check(DevTools.spawn("no_such_item", 1).is_empty(), "an unknown id spawns nothing")
	# stacks stay apart from real stock
	var real0 := Game.count("coal")
	DevTools.spawn("coal", 7)
	eq(Game.count("coal"), real0 + 7, "seven coal added")
	var dev_stacks := Game.inventory().filter(func(x): return str(x["def"]) == "coal" and bool(x.get("dev", false)))
	eq(dev_stacks.size(), 1, "one developer coal stack")
	if not dev_stacks.is_empty():
		eq(int(dev_stacks[0]["qty"]), 7, "… of seven, not merged into the real coal")
	check(save_load("suite_dev_spawn"), "save/load")
	check(bool(Game.find_uid(int(a["uid"])).get("dev", false)), "the developer mark survives save/load")


func test_money() -> void:
	fresh_game()
	var g0 := Game.gold()
	DevTools.add_money(500)
	eq(Game.gold(), g0, "S2: with cheats off no money is added")
	DevTools.set_enabled(true)
	DevTools.add_money(500)
	eq(Game.gold(), g0 + 500, "500 gold added")
	var last: Dictionary = Game.state["ledger"][-1]
	eq(str(last["note"]), "Developer tools", "logged in the ledger as Developer tools")
	eq(str(last["cat"]), "dev", "in the developer category (left out of the accounts)")
	DevTools.add_money(-200)
	eq(Game.gold(), g0 + 300, "a negative amount takes money away")


func test_dev_items_earn_nothing() -> void:
	fresh_game()
	DevTools.set_enabled(true)
	var made := DevTools.spawn("sword_steel", 1, "legendary", 125.0)
	if not check(made.size() == 1, "a legendary developer sword"):
		return
	var it: Dictionary = made[0]
	check(not Recognition.made_by_smith(it), "a developer piece is not the smith's work")
	check(not Recognition.grant_epic(it, "a test deed"), "it cannot earn Epic")
	check(not it.has("epic"), "no Epic")
	check(not ItemStory.can_be_named(it), "it cannot be named")
	check(not ItemStory.name_item(it, "Testbrand", "masterwork", "test"), "naming it is refused")
	var hall0 := Recognition.entries().size()
	Recognition.on_crafted(it)
	eq(Recognition.entries().size(), hall0, "no Hall of Fame entry")
	ItemStory.mark_famous(it, "a test deed")
	check(not ItemStory.st()["famous"].has(str(it["uid"])), "not among the famous creations")
	# knowledge: items seen, flags, encyclopedia
	check(not Game.state.get("items_seen", {}).has("dragon_scale"), "dragon scale not seen yet")
	DevTools.spawn("dragon_scale", 1)
	check(not Game.state.get("items_seen", {}).has("dragon_scale"), "a spawned dragon scale is not 'seen' by the skill tree")
	check(not Game.has_flag("dragon_lore"), "and teaches no dragon lore")
	Reference.note_seen()
	check(not Reference.seen().has("dragon_scale"), "nor does it enter the encyclopedia")
	DevTools.spawn("ore_mithril", 1)
	check(not Game.has_flag("found_mithril"), "spawned mithril ore sets no discovery flag")
	# objectives: selling a developer piece to Mira completes nothing
	Objectives.on_sold("mira", it)
	check(not Objectives.is_done("serve_mira"), "selling a developer piece completes no objective")
	# apprentices' fame skips developer pieces
	check(Apprentices.famous_works({"creations": [int(it["uid"])]}).is_empty(), "no apprentice fame from a developer piece")
	# a real sword still counts
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var real := craft("iron_longsword", 92.0, {"edge": 12, "temper": 8, "fortune": 1})
	check(Recognition.made_by_smith(real), "a forged sword is still the smith's work")


## #75–76: a chosen skill raised by N levels and the simulation's pace — only while cheats are on, back to normal when
## they go off, on a load or a new game; the steward keeps its own pace.
func test_skill_levels_and_pace() -> void:
	fresh_game()
	DevTools.end_session()
	var before := Game.player_level("smithing")
	eq(DevTools.raise_skill("smithing", 3), -1, "cheats off: no skill raise")
	eq(Game.player_level("smithing"), before, "…the level is unchanged")
	check(not DevTools.set_sim_pace(4.0, true), "cheats off: no faster pace")
	eq(Engine.time_scale, 1.0, "…normal speed")
	DevTools.set_enabled(true)
	eq(DevTools.raise_skill("smithing", 3), before + 3, "cheats on: smithing +3")
	eq(DevTools.raise_skill("leatherworking", 2), Game.player_level("leatherworking"), "any chosen skill (leatherworking)")
	eq(DevTools.raise_skill("smithing", 99), int(DB.skill_curve.get("max_level", 20)), "clamped to the curve's maximum")
	var steps := Engine.max_physics_steps_per_frame
	check(DevTools.set_sim_pace(8.0, true), "cheats on: ×8")
	eq([Engine.time_scale, DevTools.sim_pace()], [8.0, 8.0], "the whole engine runs at ×8")
	check(Engine.max_physics_steps_per_frame >= 10, "physics may take enough steps a frame to keep up")
	check(not DevTools.set_sim_pace(3.0, true) or DevTools.sim_pace() == 1.0, "only the listed paces (×3 → normal)")
	DevTools.set_sim_pace(16.0, true)
	DevTools.set_sim_pace(1.0, true)
	eq([Engine.time_scale, Engine.max_physics_steps_per_frame], [1.0, steps], "back to normal, physics as before")
	DevTools.set_sim_pace(4.0, true)
	DevTools.set_enabled(false)
	eq(Engine.time_scale, 1.0, "switching cheats off returns to normal speed")
	DevTools.set_enabled(true)
	DevTools.set_sim_pace(4.0, true)
	fresh_game()
	DevTools.end_session()
	eq([Engine.time_scale, DevTools.enabled()], [1.0, false], "a new game or a load: normal speed, cheats off")
	check(not Game.state.has("dev_pace") and not JSON.stringify(Game.state).contains("time_scale"), "the pace is never saved")
