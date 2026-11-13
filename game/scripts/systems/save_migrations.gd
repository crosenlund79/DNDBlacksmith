## SaveMigrations — explicit, ordered save-schema steps (Milestone A1 "Protect the Foundation").
## EN: A save file records the schema version of its data (`data.version`). On load, `run()` applies exactly the
##     steps from that version up to `Game.SAVE_VERSION`, one at a time and in order, records the new version in
##     the data after each step and logs every step. Each step is a static function that converts the data
##     dictionary in place and is safe on data that already has the target shape (running it twice changes
##     nothing). A save from a NEWER version than this build is never down-converted: it loads best-effort with
##     a warning.
##     Rules for future steps:
##       - one step per schema change, appended at the end of STEPS; bump Game.SAVE_VERSION to the new `to`;
##       - conversions of EXISTING data belong here; lazily created NEW keys may stay in their system's getter;
##       - never delete history (Lore, provenance, records) — convert it;
##       - add a golden-save test (tests/suite/cases/t_saves.gd) that proves the step on authentic old saves.
## DA: Eksplicitte, ordnede trin for gemte spil: v(n) → v(n+1). Hvert trin konverterer data og kan køres igen
##     uden at ændre noget. Et gemt spil fra en nyere version indlæses så godt som muligt med en advarsel.
class_name SaveMigrations
extends RefCounted

## The ordered step list: entry i converts version i → i + 1 (`to` = i + 1). Keep `Game.SAVE_VERSION` equal to
## the last `to` (t_saves checks it).
const STEPS := [
	{"to": 1, "name": "early containers",
		"what": "Prototype saves (no version) gain the returns, customers and orders lists."},
	{"to": 2, "name": "formalise the per-load fix-ups",
		"what": "Cloaks worn in the amulet slot move to the cloak slot (same instance) and cloak commissions name the cloak slot; saves from before the property system own the whole ground floor and every station (legacy); saves from before the Loft gain its unowned rooms and doorways; saves from before the skill tree learn every node their skills already meet."},
	{"to": 3, "name": "canonical item identity",
		"what": "Records that only refer to a piece (finished-expedition loot, repair requests for an adventurer's own piece) become uid + snapshot references; a delivered contract masterpiece moves to the holdings archive (out of the capped history); one uid held by two live holders keeps the most authoritative one. Same instances, same uids (ItemRegistry.migrate_records)."},
	{"to": 4, "name": "campaign Unique registry",
		"what": "Run 0.1 (decision D13): every piece or record of a Unique artifact in the save is registered; the lowest uid is the authentic piece and any others are kept whole as recorded legacy copies, so the campaign never mints that Unique again (Uniques.scan_state)."},
	{"to": 5, "name": "worker professions",
		"what": "The Living Workshop B1: the smith is the blacksmith; every workshop apprentice (on the staff or gone), and every waiting applicant, gains a profession from their strongest workshop skill (ties: their preferred discipline, then smithing). Every level, experience point, trait, wage, rank, log, memory, creation, task and contract hour is kept; the smith keeps every level (other crafts simply stop growing past the basic level from now on); field hirelings are unchanged (Workers.migrate_professions)."},
	{"to": 6, "name": "workshop knowledge",
		"what": "The Living Workshop B2: every Skill Tree node the save has learned — secret nodes and their discoveries included — becomes the workshop's knowledge: its Designs, stations and techniques, recorded as learned through the smith on the day the tree noted. The tree, every flag and discovery, every level and every item stay exactly as they were; nothing is removed (WorkshopKnowledge.migrate_state)."},
	{"to": 7, "name": "station instances and work orders",
		"what": "The Living Workshop #37 and C1: every station already in the workshop becomes instance #1 of its type under the same id (layouts, storage, wear and the stations' history unchanged; a station both set up and listed in storage is kept set up once); every open apprentice task that makes a Design becomes a staged work order — its operations grouped into stages by station discipline, the stages already worked marked done by whoever worked them, the current stage with its worker — and an open order for equipment reserves the uid its piece will carry. Materials in hand, progress, workers and finished pieces are kept (Property.migrate_instances, Apprentices.migrate_work_orders)."},
	{"to": 8, "name": "the compact smithy",
		"what": "Canonical v1.7 (#64–66): the ground floor is the compact 19 × 18 smithy; the quarters and the household rooms are in the Loft, the material store and the arcane foundry in the dug-out basement. Each moved room keeps its id, unit and stations (same place within the room); a room the player made in the removed part of the old ground floor is dropped and its stations go to storage; doorways for moved rooms come from the data; a save that owned the foundry also owns the cellar dig that leads to it; a plan that would not validate stores the moved rooms' stations to re-place; the smith, if he stood where the millpond now lies, is set down inside the front door. Units, upgrades, items and stations are never removed (Property.migrate_layout_v17)."},
]


## The schema version this code writes (the last step's target).
static func latest() -> int:
	return STEPS.size()


## The schema version a data dictionary declares (0 = a prototype save without one).
static func version_of(data: Dictionary) -> int:
	var v: Variant = data.get("version", 0)
	if v is int or v is float:
		return int(v)
	if v is String and (v as String).is_valid_int():
		return int(v)
	return 0


## Upgrades `data` in place from its version to `target` (default: Game.SAVE_VERSION), step by step.
## Returns a report: {"from", "to", "steps": [names applied], "newer": bool (the save is from a newer build)}.
static func run(data: Dictionary, target := -1) -> Dictionary:
	if target < 0:
		target = Game.SAVE_VERSION
	var v := version_of(data)
	var report := {"from": v, "to": v, "steps": [], "newer": false}
	if v > target:
		report["newer"] = true
		Log.warn("Save is from a newer version (schema %d, this build reads %d) — loading best-effort" % [v, target])
		return report
	while v < target:
		var to := v + 1
		if not apply_step(to, data):
			Log.error("Save migration v%d → v%d is missing — the save stays at v%d" % [v, to, v])
			break
		data["version"] = to
		(report["steps"] as Array).append(str(STEPS[to - 1]["name"]))
		Log.info("Save migrated v%d → v%d (%s)" % [v, to, str(STEPS[to - 1]["name"])])
		v = to
	report["to"] = v
	return report


## Applies the single step that produces version `to`. Returns false if no such step exists.
static func apply_step(to: int, data: Dictionary) -> bool:
	match to:
		1:
			_v0_to_v1(data)
		2:
			_v1_to_v2(data)
		3:
			_v2_to_v3(data)
		4:
			_v3_to_v4(data)
		5:
			_v4_to_v5(data)
		6:
			migrate_workshop_knowledge(data)
		7:
			_migrate_station_instances_and_work_orders(data)
		8:
			var rep := Property.migrate_layout_v17(data)
			if rep != "":
				Log.info("  the compact smithy: " + rep)
		_:
			return false
	return true


# ======================================================================= the steps
## v0 → v1: early prototypes lacked these containers.
static func _v0_to_v1(data: Dictionary) -> void:
	for key in ["returns", "customers", "orders"]:
		if not data.has(key):
			data[key] = []


## v1 → v2: the conversions that 0.14.6 and earlier ran on every load or lazily on first touch, made explicit.
## Every part is idempotent and keeps item instances (uid, maker, provenance, story) untouched.
static func _v1_to_v2(data: Dictionary) -> void:
	# The Living Realm: cloaks have their own slot; older saves wore them in the amulet's
	var cloaks := Items.migrate_cloak_slots(data)
	if cloaks > 0:
		Log.info("  moved %d cloak(s) from the amulet slot to the cloak slot" % cloaks)
	# Property and skill-tree conversions read the save through Game.state: bind it for the duration
	if not data.get("player") is Dictionary:
		return
	_with_state(data, func() -> void:
		var had_property := data.has("property")
		var had_floors := had_property and (data["property"] as Dictionary).has("floors_v")
		Property.st()          # legacy (pre-property) ownership, then the Loft's rooms for pre-Loft saves
		if not had_property:
			Log.info("  a save from before the property system: the whole ground floor and every station are owned")
		elif not had_floors:
			Log.info("  the Loft's rooms and doorways were added (unowned)")
		var had_tree := data.has("skilltree")
		SkillTree.ensure()     # pre-skill-tree saves learn every node their skills already meet
		if not had_tree:
			Log.info("  a save from before the skill tree: nodes learned from the smith's skills")
	)


## v2 → v3 (Milestone A1): one canonical physical item per uid. Idempotent (a second pass changes nothing).
static func _v2_to_v3(data: Dictionary) -> void:
	if not data.get("player") is Dictionary:
		return
	_with_state(data, func() -> void:
		var n := ItemRegistry.migrate_records(data)
		if n > 0:
			Log.info("  item identity: %d record(s) converted" % n)
	)


## v3 → v4 (Run 0.1): the campaign's Unique registry. Idempotent; no item is changed, moved or removed.
static func _v3_to_v4(data: Dictionary) -> void:
	var n := Uniques.scan_state(data)
	if n > 0:
		var r: Dictionary = data["uniques"]
		for d in r:
			Log.info("  Unique %s: authentic uid %d, %d legacy cop%s kept" % [d, int(r[d]["uid"]), (r[d]["copies"] as Array).size(),
				"y" if (r[d]["copies"] as Array).size() == 1 else "ies"])


## v4 → v5 (The Living Workshop B1): worker professions. Idempotent; only a missing profession is written.
static func _v4_to_v5(data: Dictionary) -> void:
	var n := Workers.migrate_professions(data)
	if n > 0:
		var ap: Variant = data.get("apprentices", {})
		var staff: Array = (ap as Dictionary).get("staff", []) if ap is Dictionary else []
		for a in staff:
			Log.info("  %s: %s" % [str(a.get("name", "?")), Workers.profession_name(str(a.get("profession", "")))])
		Log.info("  %d workshop worker(s) given a profession" % n)


## v5 → v6 (The Living Workshop B2): the workshop's knowledge, taken from the tree's learned nodes. Idempotent; nothing
## is removed, no level, flag, node or item changes. (Named for its content so the lead can renumber it at merge.)
static func migrate_workshop_knowledge(data: Dictionary) -> void:
	if not data.get("player") is Dictionary:
		return
	_with_state(data, func() -> void:
		var n := WorkshopKnowledge.migrate_state()
		if n > 0:
			var k: Dictionary = data["workshop_knowledge"]
			Log.info("  workshop knowledge: %d Design(s), %d station(s), %d technique(s) from %d learned node(s)" % [(k["designs"] as Dictionary).size(),
				(k["stations"] as Dictionary).size(), (k["techniques"] as Dictionary).size(), (k["nodes"] as Dictionary).size()])
	)


## v6 → v7 (The Living Workshop #37 + C1): station instances and staged work orders. Idempotent: a second pass finds
## nothing to change. Instance #1 keeps the type id, so no layout key moves; open Design tasks gain their stages.
static func _migrate_station_instances_and_work_orders(data: Dictionary) -> void:
	var n := Property.migrate_instances(data)
	if n > 0:
		Log.info("  station instances: %d storage entr%s tidied" % [n, "y" if n == 1 else "ies"])
	var w := Apprentices.migrate_work_orders(data)
	if w > 0:
		Log.info("  %d open task%s became staged work orders" % [w, "" if w == 1 else "s"])


## Runs `fn` with Game.state pointing at `data` (systems read the save through Game.state), then restores it.
static func _with_state(data: Dictionary, fn: Callable) -> void:
	var prev: Dictionary = Game.state
	Game.state = data
	fn.call()
	Game.state = prev
