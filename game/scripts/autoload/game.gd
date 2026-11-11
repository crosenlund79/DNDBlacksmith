## Game — the authoritative, serialisable world state and the in-game clock.
## EN: Everything that must survive save/load lives in `state` (plain Dictionaries/Arrays so it
##     serialises to JSON). Systems in scripts/systems read and mutate it; the world scene only
##     visualises it. The clock advances while the world is active and no blocking UI is open.
## DA: Alt der skal overleve gem/indlæs ligger i `state` (rene Dictionaries/Arrays, så det kan
##     gemmes som JSON). Systemerne i scripts/systems læser og ændrer det; verdensscenen viser det
##     blot. Uret går, mens verdenen er aktiv, og ingen blokerende brugerflade er åben.
extends Node

## The save-schema version this build writes; SaveMigrations.STEPS converts every older version up to it.
const SAVE_VERSION := 4
const MINUTES_PER_SECOND := 1.6   # one in-game day ≈ 15 real minutes
const DAY_START_HOUR := 6

var state: Dictionary = {}
var running := false
var ui_blockers := 0
var ui_open := 0     # windows on screen (some — the Most Wanted board, the observer — let time run)
var _acc := 0.0
## Single-player time controls: pause and acceleration (1x, 2x, 4x, 8x). The simulation advances
## only through advance_minutes(), whatever the frame rate, so faster time never skips events.
var paused := false
var speed := 1
const SPEEDS := [1, 2, 4, 8]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------------ new game
func new_game(difficulty := "journeyman") -> void:
	DevTools.end_session()   # S2: developer cheats never carry into a new game
	Steward.on_new_game()   # S2: no steward session (or its pace) carries over into a new game
	state = {
		"version": SAVE_VERSION,
		"day": 1, "minute": 7 * 60 + 30,
		"gold": 120,
		"next_uid": 1,
		"ledger": [],
		"journal": [],
		"flags": {},
		"upgrades": [],
		"player": {
			"id": "player", "name": "Brannoc Ironhand",
			"skills": SkillSys.new_set({"smithing": 4, "mining": 2, "alchemy": 1, "runecraft": 1, "travelling": 3,
				"relic_hunting": 2, "arcane_metalwork": 0, "enchanted_stitching": 1}),
			"inventory": [], "equipment": {},
			"pos": [], "area": "smithy",
		},
		"hirelings": [],
		"applicants": [],
		"adventurers": {},
		"social": {},
		"orders": [],
		"customers": [],
		"craft": {},
		"returns": [],          # bags waiting to be collected in the workshop
		"world": {"eggs": false, "eggs_by": "", "last_delivery_week": 0, "delivery_pending": false},
		"objectives": {},
		"stats": {"crafted": 0, "sold": 0, "legendaries": 0},
		"difficulty": "journeyman",
		"chronicle": [],
		"exp": {"active": {}, "done": [], "parties": {}},
		"offers": [],
	}
	# starting materials — enough to try every open discipline once or twice
	for pair in [["ore_iron", 8], ["coal", 10], ["ingot_iron", 6], ["ingot_steel", 2], ["leather_cured", 5], ["leather_hide", 4],
			["thread_linen", 4], ["ore_silver", 2], ["herb_emberleaf", 4], ["herb_moonwort", 4], ["reagent_salt", 3], ["runestone_blank", 2]]:
		add_item(Items.make(pair[0], {"qty": pair[1]}), false)
	var starter := Items.make("dagger", {"quality": 74.0})
	starter["for_sale"] = true
	add_item(starter, false)
	Hire.hire_from_character("borin")
	Adv.init_population()
	Hire.refresh_applicants()
	Social.init_all()
	Objectives.init()
	state["difficulty"] = difficulty if DB.expeditions.get("difficulty", {}).has(difficulty) else "journeyman"
	Expeditions.init_world()
	Property.init_new()
	SkillTree.init_new()
	Ironfront.invite_new()
	journal("Day 1. The forge is cold, Borin is restless and Mira Pell keeps glancing at the shop window.")
	Log.info("New game created")


# ------------------------------------------------------------------ clock
func _process(delta: float) -> void:
	if Steward.pace_on() and not Steward.is_active():
		Steward.restore_pace()   # S2: the steward's pace never outlives its session (exit, load or a new game)
	if not running or ui_blockers > 0 or state.is_empty() or paused:
		return
	_acc += delta * MINUTES_PER_SECOND * float(Settings.get_value("gameplay/time_scale", 1.0)) * speed
	if _acc >= 1.0:
		var m := int(_acc)
		_acc -= m
		advance_minutes(m)


## Absolute game time in minutes since the start of day 1 (the expedition clock).
func now() -> int:
	return (day() - 1) * 1440 + int(state.get("minute", 0))


func set_speed(v: int) -> void:
	if Steward.is_active() and v != 1:
		Steward.speed_request(v)   # S2: the steward keeps one pace for the whole simulation; the choice applies on return
		v = 1
	speed = v if SPEEDS.has(v) else 1
	Events.time_changed.emit(day(), int(state.get("minute", 0)))


func toggle_pause() -> void:
	paused = not paused
	Events.time_changed.emit(day(), int(state.get("minute", 0)))


func advance_minutes(m: int) -> void:
	for i in m:
		state["minute"] += 1
		if state["minute"] % 5 == 0:
			Expeditions.tick()
			Apprentices.tick(5)   # workshop apprentices work in the same 5-minute steps (sleep and travel included)
			if Steward.is_active():
				StewardSmith.tick(5)   # S2: the smith working under the steward, in the same steps
		if state["minute"] % 60 == 0:
			if state["minute"] >= 24 * 60:
				state["minute"] = 0
				state["day"] += 1
				Sim.on_day(state["day"])
				Events.day_started.emit(state["day"])
			Sim.on_hour(state["day"], hour())
			Events.hour_passed.emit(state["day"], hour())
		if state["minute"] % Steward.TICK_MINUTES == 0 and Steward.is_active():
			Steward.tick()   # Steward Mode: the routine business, only while the player has handed it over
	Events.time_changed.emit(state["day"], state["minute"])


## Skips forward to `target_hour` (next occurrence), simulating every hour on the way.
func skip_to_hour(target_hour: int) -> void:
	var mins: int = ((target_hour * 60) - state["minute"] + 24 * 60) % (24 * 60)
	if mins == 0:
		mins = 24 * 60
	advance_minutes(mins)


func block_time(on: bool) -> void:
	ui_blockers = max(0, ui_blockers + (1 if on else -1))


func day() -> int:
	return state.get("day", 1)


func hour() -> int:
	return int(state.get("minute", 0) / 60)


func time_of_day() -> float:
	return state.get("minute", 0) / 1440.0


func is_night() -> bool:
	var h := hour()
	return h >= 21 or h < 5


func is_work_hours() -> bool:
	var h := hour()
	return h >= 8 and h < 18


func weekday_name() -> String:
	return ["Moonday", "Tiwsday", "Wodensday", "Thunorsday", "Frigsday", "Seternday", "Sunnday"][(day() - 1) % 7]


func time_string() -> String:
	var m: int = state.get("minute", 0)
	return "%02d:%02d" % [m / 60, m % 60]


# ------------------------------------------------------------------ gold & ledger
func gold() -> int:
	return state.get("gold", 0)


## `party` names the other side of the payment (Milestone A2, canon D14): who paid the smith for an income line, who
## received the smith's coin for an expense — an NPC id ("garrick") or a recorded outside party ("village",
## "caravan", "pawnbroker", "patron:<id>" … see Payments.party_name). Ledger lines written before A2 have none.
func add_gold(amount: int, category: String, note: String, party := "") -> void:
	state["gold"] += amount
	var line := {"day": day(), "amount": amount, "cat": category, "note": note}
	if party != "":
		line["party"] = party
	state["ledger"].append(line)
	MaterialLedger.note_gold(line)   # Living Workshop #46: a purchase names the seller of what arrives with it
	if Steward.is_active():
		Steward.note_ledger(amount, category, note)   # the report reconciles every coin of the time away
	if state["ledger"].size() > 400:
		state["ledger"].pop_front()
	Events.gold_changed.emit(state["gold"])
	if amount != 0:
		Audio.play("sfx/coins", -6.0)


func can_afford(amount: int) -> bool:
	return gold() >= amount


# ------------------------------------------------------------------ inventory (player)
func new_uid() -> int:
	state["next_uid"] += 1
	return state["next_uid"]


func inventory() -> Array:
	return state["player"]["inventory"]


func add_item(item: Dictionary, notify := true) -> void:
	if item.is_empty():
		return
	MaterialLedger.on_add(item)   # Living Workshop #46: materials in, with their source (no-op for other items)
	if not bool(item.get("dev", false)):
		SkillTree.note_item(str(item["def"]))   # skill-tree requirement "have held this material" (not by dev tools)
	if Provenance.applies(item) and Provenance.owner_id(item) != "smith" and item.has("prov"):
		ItemStory.on_returned(item, str(item.get("_arrives_how", "received")))   # "A Familiar Creation"
		Provenance.transfer(item, "smith", str(item.get("_arrives_how", "received")), "brindlewick")
	item.erase("_arrives_how")
	var inv := inventory()
	if DB.item(item["def"]).get("stack", false):
		# batches of different rarity (a flawless potion, an exquisite runestone) keep their own stack
		var plain: bool = DB.item(item["def"]).get("type", "") == "material" or not item.has("craft")
		for it in inv:
			if plain and it["def"] == item["def"] and it.get("rarity", "common") == item.get("rarity", "common") \
					and bool(it.get("dev", false)) == bool(item.get("dev", false)):   # developer stacks stay apart
				it["qty"] = int(it.get("qty", 1)) + int(item.get("qty", 1))
				if item["def"] == "ore_mithril" and not bool(item.get("dev", false)):
					set_flag("found_mithril")
				Events.inventory_changed.emit()
				return
	inv.append(item)
	var learns := not bool(item.get("dev", false))   # developer-tool spawns set no knowledge flags
	if learns and item["def"] == "ore_mithril" and not has_flag("found_mithril"):
		set_flag("found_mithril")
		journal("Mithril! The Arcane Foundry is within reach.")
	if learns and item["def"] == "relic_map":
		set_flag("delve_map")
	if notify:
		Events.toast.emit("Received: " + Items.display_name(item), "legendary" if item.get("rarity") == "legendary" else "info")
	Events.inventory_changed.emit()


func count(def_id: String) -> int:
	var n := 0
	for it in inventory():
		if it["def"] == def_id:
			n += int(it.get("qty", 1))
	return n


func remove_def(def_id: String, qty: int) -> bool:
	if count(def_id) < qty:
		return false
	MaterialLedger.on_remove(def_id, qty)   # Living Workshop #46: materials used
	var inv := inventory()
	for i in range(inv.size() - 1, -1, -1):
		if qty <= 0:
			break
		var it: Dictionary = inv[i]
		if it["def"] != def_id:
			continue
		var have := int(it.get("qty", 1))
		if have > qty:
			it["qty"] = have - qty
			qty = 0
		else:
			qty -= have
			inv.remove_at(i)
	Events.inventory_changed.emit()
	return true


func find_uid(uid: int) -> Dictionary:
	for it in inventory():
		if int(it.get("uid", -1)) == uid:
			return it
	return {}


## Finds an item instance in the smith's stores or worn by an adventurer or a hireling. The lookup goes through
## ItemRegistry (the one map of where items are); this scope is kept as it was because gameplay reads it
## (Hall of Fame entries, awakenings). ItemRegistry.find(uid) searches every physical holder.
func find_uid_anywhere(uid: int) -> Dictionary:
	return ItemRegistry.find(uid, ItemRegistry.WORN)


func take_uid(uid: int) -> Dictionary:
	var inv := inventory()
	for i in inv.size():
		if int(inv[i].get("uid", -1)) == uid:
			var it: Dictionary = inv[i]
			inv.remove_at(i)
			Events.inventory_changed.emit()
			return it
	return {}


func equip_player(uid: int) -> void:
	var it := take_uid(uid)
	if it.is_empty():
		return
	var slot: String = DB.item(it["def"]).get("slot", "")
	if slot == "":
		add_item(it, false)
		return
	var eq: Dictionary = state["player"]["equipment"]
	if eq.has(slot):
		add_item(eq[slot], false)
	eq[slot] = it
	Events.inventory_changed.emit()


# ------------------------------------------------------------------ flags, journal, upgrades
func has_flag(f: String) -> bool:
	return state["flags"].get(f, false)


func set_flag(f: String, v := true) -> void:
	state["flags"][f] = v
	Events.world_flag_changed.emit(f)


func journal(text: String) -> void:
	state["journal"].append({"day": day(), "time": time_string(), "text": text})
	if state["journal"].size() > 120:
		state["journal"].pop_front()


func has_upgrade(id: String) -> bool:
	return state["upgrades"].has(id)


func player_skills() -> Dictionary:
	return state["player"]["skills"]


func player_level(skill: String) -> int:
	return SkillSys.level(player_skills(), skill)


## The one place the smith's own experience is granted. S2 (Steward Mode): none at all while the steward runs the
## forge, nor for work begun under it (marked jobs, even when finished after the return or after loading a save) —
## no experience, so no level, no tree requirement met by it, nothing deferred (Steward.xp_blocked).
func grant_player_xp(skill: String, amount: int) -> void:
	if Steward.xp_blocked():
		Steward.note_xp_withheld(skill, amount)
		return
	SkillSys.add_xp(player_skills(), skill, amount, "player")


# ------------------------------------------------------------------ serialisation
func to_save() -> Dictionary:
	state["version"] = SAVE_VERSION
	return state


func from_save(data: Dictionary) -> void:
	DevTools.end_session()   # S2: a loaded save starts with developer cheats off (a session switch, never saved)
	state = data
	Steward.on_loaded()   # a loaded save always starts with Steward Mode OFF — no offline progress, no catch-up
	Events.game_loaded.emit()
