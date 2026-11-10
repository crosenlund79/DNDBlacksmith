## Vitality — the blacksmith's fatigue. Light-touch: no hunger, no thirst, just tired hands.
## EN: Game.state["player"]["fatigue"] runs 0 (fresh) .. 100 (spent); a missing key means 0.
##     It rises with every crafting operation (Crafting.record_step) and a little with each waking hour.
##     Above ~40 it lowers work_factor() (1.0 → 0.75 at 100), which the skill checks fold into difficulty,
##     and near exhaustion you walk a touch slower. Sleeping in your bed clears it; resting an hour in the
##     quarters, or a meal or drink at the inn, takes some off. Warnings are toasted as thresholds pass.
## DA: Smedens træthed (0..100). Stiger ved smedearbejde og vågne timer; over ~40 falder arbejdsevnen
##     (1,0 → 0,75). Søvn nulstiller, hvile og et måltid på kroen hjælper lidt.
class_name Vitality
extends RefCounted

const MAX := 100.0
const WAKING_PER_HOUR := 1.5        # an ordinary day awake (16 h) adds ~24
const STEP_BASE := 2.0              # each crafting operation…
const STEP_PER_CHECK := 0.5         # …plus a little per skill check in it
const REST_PER_HOUR := 25.0
const WARNINGS := [
	[60.0, "Your arms are heavy. A rest would do you good.", "info"],
	[80.0, "Your hands are getting unsteady — rest soon.", "bad"],
	[95.0, "You are exhausted. Sleep, before the hammer slips.", "bad"],
]


static func _p() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("player"):
		return {}
	return Game.state["player"]


static func fatigue() -> float:
	return float(_p().get("fatigue", 0.0))


static func energy() -> float:
	return MAX - fatigue()


static func set_fatigue(v: float) -> void:
	var p := _p()
	if p.is_empty():
		return
	var old := fatigue()
	var nv := clampf(v, 0.0, MAX)
	p["fatigue"] = nv
	_warn(old, nv)
	Events.fatigue_changed.emit(nv)


## Adds fatigue (negative amounts rest).
static func add_fatigue(amount: float) -> void:
	set_fatigue(fatigue() + amount)


## Multiplier for work effectiveness: 1.0 below 40 fatigue, falling linearly to 0.75 at 100.
static func work_factor() -> float:
	var f := fatigue()
	if f <= 40.0:
		return 1.0
	return 1.0 - 0.25 * clampf((f - 40.0) / 60.0, 0.0, 1.0)


## Walking speed multiplier: only the truly exhausted slow down.
static func move_factor() -> float:
	return 0.85 if fatigue() >= 90.0 else 1.0


static func band() -> String:
	var f := fatigue()
	if f < 25.0:
		return "Fresh"
	if f < 45.0:
		return "Steady"
	if f < 65.0:
		return "Tired"
	if f < 85.0:
		return "Weary"
	return "Exhausted"


## Called by Sim.on_hour: a waking hour (sleep and rest hours are exempt).
## S2: also while the steward runs the forge — the smith keeps working under it and tires, rests and sleeps by these
## same rules (StewardSmith); the S1 rule "fatigue holds while away" is superseded.
static func on_hour() -> void:
	if _p().is_empty():
		return
	if Game.now() <= int(_p().get("resting_until", -1)):
		return
	add_fatigue(WAKING_PER_HOUR)


## One crafting operation with `checks` skill checks (Crafting.record_step).
static func on_craft_step(checks: int) -> void:
	add_fatigue(STEP_BASE + STEP_PER_CHECK * checks)


## Rest for `minutes` (armchair / bed): takes fatigue off and keeps those hours from adding any.
## With fade, the screen fades and the clock advances (needs the UI); tests call it with fade=false.
static func rest(minutes := 60, fade := true) -> void:
	_p()["resting_until"] = Game.now() + minutes
	add_fatigue(-REST_PER_HOUR * minutes / 60.0)
	if fade:
		Events.request_fade.emit("You put your feet up by the hearth for an hour…", minutes)


## A full night's sleep: fatigue is cleared (the caller advances the clock).
static func sleep(minutes := 0) -> void:
	_p()["resting_until"] = Game.now() + minutes
	set_fatigue(0.0)


## A meal, a drink or a pot of tea: a small lift.
static func refresh(amount := 8.0) -> void:
	add_fatigue(-amount)


static func status_text() -> String:
	var f := fatigue()
	if f >= 80.0:
		return "Your hands are unsteady (work suffers)."
	if f > 40.0:
		return "You are tiring (work slightly harder)."
	return "You feel ready for the anvil."


static func _warn(old: float, nv: float) -> void:
	for w in WARNINGS:
		if old < float(w[0]) and nv >= float(w[0]):
			Events.toast.emit(str(w[1]), str(w[2]))
