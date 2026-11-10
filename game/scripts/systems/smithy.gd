## Smithy — the evolving smithy (The Living Realm, milestone 2a): discipline areas, rooms that grow with the smith,
## the floors and the way between them, and fewer wasted steps between stations.
## EN: Everything here is read from EXISTING state — Property (owned units, rooms, stations, the Loft and its lift),
##     the smith's skills, the shop's reputation, the Hall of Fame and his purse — so it is deterministic and needs no
##     state of its own (the lift lives in Property's state). Rooms carry a craft ("trade"): the discipline whose
##     stations stand there, else the craft the room is meant for (its sign; set in the layout editor). Each workshop
##     room has a tier — 0 Modest, 1 Established, 2 Masterwork — that the world dresses (banner trim, a runner, a
##     rack of the craft, lamps and a plaque of famous works). After an operation the next station is marked and the
##     station panel offers "Walk to the <station>"; a finished piece offers "Craft again" when the materials allow.
## DA: Den voksende smedje: håndværksområder, rum der udvikler sig med smedens fremgang, loftet og elevatoren, og
##     færre gentagne skridt mellem stationerne. Alt udledes af eksisterende tilstand.
##
## Public API (static):
##   trade(r) -> String                         a room's craft ("" = none)
##   trade_name(disc) -> String                 "Smithing", "Leatherworking & Tailoring", …
##   room_tier(r) -> int                        0 modest · 1 established · 2 masterwork (owned workshop rooms)
##   tier_info(r) -> Dictionary                 {tier, name, next}  — `next` says what the next tier needs
##   renown() -> Dictionary                     {ok, why}  reputation ≥ 25 or ≥ 3 Hall of Fame plaques (earned, never bought: D18)
##   capacity_report(plan := {}) -> Array       per discipline {disc, name, stations, installed, places, rooms, free}
##   floor_hint(sid) -> String                  "" on the ground floor, else "upstairs in the Loft"
##   craft_again_reason(rid) -> String          "" when the same recipe can be started again now
##   craft_again(rid) -> String                 starts it and walks to its first station ("" = done)
##   walk_to_station(sid) -> String             auto-walk (stairs/lift included) to a station and use it ("" = on the way)
class_name Smithy
extends RefCounted

const NAMES := {"classic": "Smithing", "stitching": "Leatherworking & Tailoring", "runecraft": "Runecrafting",
	"alchemy": "Alchemy", "arcane": "Arcane Metalworking"}
## The short names painted beside a room's banner.
const SIGN_NAMES := {"classic": "SMITHING", "stitching": "LEATHER & TAILORING", "runecraft": "RUNECRAFT", "alchemy": "ALCHEMY",
	"arcane": "ARCANE METALWORK"}
const TIER_NAMES := ["Modest", "Established", "Masterwork"]
## Skill needed for each tier (the room's craft), and how many of its stations must stand in the room.
const TIER_SKILL := [0, 6, 12]
const TIER_STATIONS := [0, 2, 3]
const RENOWN_REP := 25.0
const RENOWN_PLAQUES := 3


# ------------------------------------------------------------------ discipline areas
static func trade(r: Dictionary) -> String:
	var d := Property.room_discipline(r)
	return d if d != "" else Property.planned_discipline(r)


static func trade_name(disc: String) -> String:
	return str(NAMES.get(disc, "Workshop"))


static func _in_room(r: Dictionary, disc: String) -> int:
	var n := 0
	for sid in Property.stations_in(r):
		if Property.is_installed(str(sid)) and str(DB.station(str(sid)).get("discipline", "")) == disc:
			n += 1
	return n


# ------------------------------------------------------------------ tiers (deterministic, from real progress)
static func renown() -> Dictionary:
	if Game.state.is_empty():
		return {"ok": false, "why": ""}
	var rep := Shop.reputation()
	var plaques := (Game.state.get("hall_of_fame", []) as Array).size()
	if rep >= RENOWN_REP:
		return {"ok": true, "why": "the village calls the forge renowned"}
	if plaques >= RENOWN_PLAQUES:
		return {"ok": true, "why": "%d plaques hang in the Hall of Fame" % plaques}
	# Run 0.1 (D18, canon §9.2): renown is earned, never bought — a full purse no longer counts as renown
	return {"ok": false, "why": "renown — a renowned name (reputation %d of %d) or %d Hall of Fame plaques (now %d)" % [int(rep), int(RENOWN_REP), RENOWN_PLAQUES, plaques]}


static func room_tier(r: Dictionary) -> int:
	return int(tier_info(r)["tier"])


static func tier_info(r: Dictionary) -> Dictionary:
	var out := {"tier": 0, "name": TIER_NAMES[0], "next": ""}
	if Game.state.is_empty() or r.is_empty() or not Property.room_owned(r) or Property.kind(r) != "workshop":
		return out
	var disc := trade(r)
	if disc == "":
		out["next"] = "Give the room a craft or set up stations to make it a workshop of its trade."
		return out
	var skill := Game.player_level(str(Crafting.DISCIPLINE_SKILL.get(disc, "smithing")))
	var n := _in_room(r, disc)
	var sk_name := SkillSys.skill_name(str(Crafting.DISCIPLINE_SKILL.get(disc, "smithing")))
	var t := 0
	if skill >= TIER_SKILL[1] and n >= TIER_STATIONS[1]:
		t = 1
		if skill >= TIER_SKILL[2] and n >= TIER_STATIONS[2] and bool(renown()["ok"]):
			t = 2
	out["tier"] = t
	out["name"] = TIER_NAMES[t]
	if t < 2:
		var need := []
		if skill < TIER_SKILL[t + 1]:
			need.append("%s %d (now %d)" % [sk_name, TIER_SKILL[t + 1], skill])
		if n < TIER_STATIONS[t + 1]:
			need.append("%d of its stations in the room (now %d)" % [TIER_STATIONS[t + 1], n])
		if t + 1 == 2 and not bool(renown()["ok"]):
			need.append(str(renown()["why"]))
		out["next"] = "%s needs %s." % [TIER_NAMES[t + 1], ", ".join(need)]
	return out


# ------------------------------------------------------------------ capacity & crowding
## Per discipline: how many stations exist, how many are installed, and the places in owned workshop rooms whose craft
## it is (its trade). `free` = places − stations of the craft standing there.
static func capacity_report(plan := {}) -> Array:
	if plan.is_empty():
		plan = Property.plan_copy()
	var out := []
	for disc: String in Property.DISCIPLINES:
		var total := 0
		var inst := 0
		for st in DB.stations.values():
			if str(st.get("discipline", "")) == disc:
				total += 1
				if (plan["stations"] as Dictionary).has(str(st["id"])) and Property.is_installed(str(st["id"])):
					inst += 1
		var places := 0
		var rooms := []
		var used := 0
		for r in plan["rooms"]:
			if not Property.room_owned(r) or Property.kind(r) != "workshop":
				continue
			var t := Property.planned_discipline(r)
			if t == "":
				t = Property.room_discipline(r)
			if t != disc:
				continue
			places += Property.capacity(r)
			rooms.append(str(r.get("name", r["id"])))
			used += Property.count_in(plan, r)
		out.append({"disc": disc, "name": trade_name(disc), "stations": total, "installed": inst, "places": places,
			"rooms": rooms, "free": places - used})
	return out


# ------------------------------------------------------------------ floors and walking
## "the Anvil", "the Forge / Hearth" — a station's name after "the" (names that begin with "The" are not doubled).
static func station_ref(sid: String) -> String:
	var n := str(DB.station(sid).get("name", sid))
	return "the " + (n.substr(4) if n.begins_with("The ") else n)


## The floor the smith stands on (from the area the world last put him in).
static func player_floor() -> String:
	if Game.state.is_empty():
		return "ground"
	var a := str((Game.state.get("player", {}) as Dictionary).get("area", Property.BID))
	for f in Property.floors():
		if str(f.get("area", "")) == a:
			return str(f["id"])
	return "ground"


## Where a station is, seen from the smith's floor: "" on his floor, else "upstairs in The Loft" / "downstairs".
static func floor_hint(sid: String) -> String:
	if Game.state.is_empty() or not Property.is_installed(sid):
		return ""
	var f := Property.station_floor(sid)
	if f == player_floor():
		return ""
	return "downstairs on the ground floor" if f == "ground" else "upstairs in %s" % Property.floor_name(f).replace("The ", "the ")


static func _world() -> VillageWorld:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("world") as VillageWorld


## Walk (click-to-move, stairs and lift included) to a station and use it on arrival.
## S2: use_on_arrival = false only walks there (the optional auto-walk after a check: nothing opens, nothing starts).
## Backward compatible: the two-argument form behaves exactly as before.
static func walk_to_station(sid: String, w: VillageWorld = null, use_on_arrival := true) -> String:
	if w == null:
		w = _world()
	if w == null:
		return "Nowhere to walk."
	var nav := PlayerNav.of(w)
	if nav == null:
		return "Nowhere to walk."
	for e in w.interactables:
		if str(e.get("kind", "")) == "station" and str(e.get("id", "")) == sid:
			return "" if nav.walk_to_entity(e, use_on_arrival) else "There is no way to the %s from here." % DB.station(sid).get("name", sid)
	return "The %s is not set up in the workshop." % DB.station(sid).get("name", sid)


## S2: the optional auto-walk (Settings "gameplay/auto_walk", off unless the player turns it on). Called when a skill
## check has finished an operation at `done_sid`: if the recipe continues at a different station that is set up, the
## smith walks there. It only walks — it opens nothing, starts no work, never chooses a recipe or rolls the dice; the
## dice, a finished piece, the steward in charge or the next step at the same station leave him where he is.
## Returns the station he set off for ("" = no walk). `force` = ignore the setting (tests).
const AUTO_WALK_KEY := "gameplay/auto_walk"


static func auto_walk_target(done_sid: String, force := false) -> String:
	if not force and not bool(Settings.get_value(AUTO_WALK_KEY, false)):
		return ""
	if not Crafting.active() or bool(Crafting.job().get("awaiting_dice", false)) or Steward.is_active():
		return ""
	var nsid := Crafting.current_station()
	if nsid == "" or nsid == done_sid or not Property.is_installed(nsid):
		return ""
	return nsid


static func auto_walk_next(done_sid: String, w: VillageWorld = null) -> String:
	var nsid := auto_walk_target(done_sid)
	if nsid == "":
		return ""
	return nsid if walk_to_station(nsid, w, false) == "" else ""


static func craft_again_reason(rid: String) -> String:
	if rid == "" or DB.recipe(rid).is_empty():
		return "No recipe."
	if Crafting.active():
		return "Finish the current work first."
	var why := Crafting.recipe_locked_reason(rid)
	if why != "":
		return why
	var miss := Crafting.missing_inputs(rid)
	if not miss.is_empty():
		var parts := []
		for d in miss:
			parts.append("%d× %s" % [int(miss[d]), DB.item(str(d)).get("name", d)])
		return "Missing " + ", ".join(parts)
	return ""


## Starts the same recipe again and sets off for its first station (walking is skipped without a world, e.g. tests).
static func craft_again(rid: String, walk := true) -> String:
	var why := craft_again_reason(rid)
	if why != "":
		return why
	if not Crafting.start(rid):
		return "It could not be started."
	Events.toast.emit("Again: %s. First: %s at %s%s." % [DB.recipe(rid).get("name", rid), Crafting.current_op().get("op", ""),
		station_ref(Crafting.current_station()), (" (" + floor_hint(Crafting.current_station()) + ")") if floor_hint(Crafting.current_station()) != "" else ""], "info")
	if walk:
		walk_to_station(Crafting.current_station())
	return ""
