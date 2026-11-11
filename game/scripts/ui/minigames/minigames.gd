## Minigames — picks the skill check for a station, and knows how to teach each one.
## EN: data/crafting.json "minigames" maps station ids to a specialised check
##     (align, edge, multihit, rune, rings). Stations without an entry keep the original circular
##     precision ring (SkillCheckPanel). args may force one with "minigame": "<type>" or "ring".
##     Tutorials: the first time a mechanic appears, its how-to card (TUTORIAL) is shown before the
##     check starts (CheckOverlay). Dismissed cards are remembered in Settings
##     ("gameplay/check_tutorials_seen") — they are about the PLAYER's knowledge of the controls,
##     not the character's, so they persist across saves and new games, like the assist option.
## DA: Vælger færdighedsprøven for en station ud fra data; ellers den klassiske ring. Første gang
##     en mekanik dukker op, vises et lille illustreret kort med vejledning (gemt i indstillingerne).
class_name Minigames
extends RefCounted

const TYPES := ["align", "edge", "multihit", "rune", "rings"]
const SEEN_KEY := "gameplay/check_tutorials_seen"

## false suppresses the automatic first-time cards (automated play-tests); "?" still works.
static var auto_tutorials := true

## How-to cards: what to watch, which keys, and what scores well. {key} is replaced by the interact key.
const TUTORIAL := {
	"ring": {"name": "The Precision Ring",
		"watch": "A needle sweeps around the ring towards the ember-coloured target zone.",
		"keys": "{key} (or Space / left click) stops the needle.",
		"score": "Stop it in the bright gold centre for more than 100%. The zone's edge gives about 70%; outside it the work falls away fast."},
	"align": {"name": "Spark & Ember Alignment",
		"watch": "Two rings drift with the airflow: the inner Spark wheel and the outer Ember ring. Each has a notch that must face the vent at the top.",
		"keys": "A/D or ←/→ turn the Spark wheel, W/S or ↑/↓ turn the Ember ring (or drag them). {key}, Space or a click on the hearth pumps the bellows.",
		"score": "Pump when BOTH notches glow gold under the vent. The closer the pair, the hotter the flame — a perfect pair beats 100%."},
	"edge": {"name": "Edge Control",
		"watch": "The gold circle on the gauge is the sweet spot. It wanders as the stone wears, and the grit kicks the blade now and then.",
		"keys": "W/S or ↑/↓ set the angle, A/D or ←/→ the pressure — or simply move the mouse.",
		"score": "Keep your dot inside the gold circle for the whole pass. Steady control all the way through beats one lucky moment."},
	"multihit": {"name": "Multi-Hit Sequence",
		"watch": "Glowing violet sections lie around the ring. The needle waits a moment, then makes ONE quick sweep.",
		"keys": "{key}, Space or a click as the needle crosses each section.",
		"score": "Every section struck counts the same; strike them all for an exceptional weave. Presses outside a section cost a little."},
	"rune": {"name": "Rune Stabilisation",
		"watch": "A charged rune drifts and surges above the engraved socket on the piece.",
		"keys": "Move the mouse — the rune follows it, a little late — or push it with W/A/S/D / the arrows.",
		"score": "Guide it into the socket, then hold it calm in the inner ring while the binding fills. Close and steady beats 100%."},
	"rings": {"name": "Ring Contact",
		"watch": "A still ring waits in the vessel; a second ring appears and closes in on it (or grows out towards it).",
		"keys": "{key}, Space or a click the instant the two rings touch.",
		"score": "An exact contact beats 100%. Too early or too late spoils the mixture in proportion to the gap."},
}


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


## LW #58: the check for setting a runestone into a piece at the Rune Engraving Stand, from the smith's Runecraft against
## the rune's own Design (Crafting.check_params, with fatigue and the assist option) like every other check. Before, the
## station panel opened it with a fixed zone 28 / speed 0.6, the same for a novice and a master.
static func socket_check(rune_def: String) -> Dictionary:
	var rid := ""
	for r in DB.recipes.values():
		if str(r.get("output", "")) == rune_def:
			rid = str(r["id"])
			break
	return Crafting.check_params("rune_engraving_stand", rid, 1)


static func label(type: String) -> String:
	return {"align": "Spark & Ember alignment", "edge": "Edge control", "multihit": "Multi-hit sequence",
		"rune": "Rune stabilisation", "rings": "Ring contact"}.get(type, "Precision ring")


## The mechanic name used by tutorials ("ring" for the classic check).
static func mechanic(args: Dictionary) -> String:
	var t := type_for(args)
	return t if TUTORIAL.has(t) else "ring"


static func tutorial(type: String) -> Dictionary:
	var d: Dictionary = TUTORIAL.get(type, TUTORIAL["ring"]).duplicate()
	for k in ["watch", "keys", "score"]:
		d[k] = str(d[k]).replace("{key}", Settings.key_label("interact"))
	return d


static func tutorial_seen(type: String) -> bool:
	var seen: Variant = Settings.get_value(SEEN_KEY, [])
	return seen is Array and (seen as Array).has(type)


static func set_tutorial_seen(type: String, on := true) -> void:
	var seen: Array = []
	var cur: Variant = Settings.get_value(SEEN_KEY, [])
	if cur is Array:
		seen = (cur as Array).duplicate()
	if on and not seen.has(type):
		seen.append(type)
	elif not on:
		seen.erase(type)
	Settings.set_value(SEEN_KEY, seen)


static func reset_tutorials() -> void:
	Settings.set_value(SEEN_KEY, [])


## Should this check open with its how-to card? Only real checks, the first time, when allowed.
static func should_auto_tutorial(args: Dictionary) -> bool:
	return auto_tutorials and not bool(args.get("practice", false)) and not bool(args.get("no_tutorial", false)) \
		and not tutorial_seen(mechanic(args))


## Arguments for a no-consequence practice run of the same mechanic at tutorial difficulty.
static func practice_args(args: Dictionary) -> Dictionary:
	var station := str(args.get("station", ""))
	var p := Crafting.tutorial_params(station) if station != "" and not DB.station(station).is_empty() else {"speed": float(args.get("speed", 0.55)) * 0.62, "zone": minf(float(args.get("zone", 34.0)) * 1.55, 90.0)}
	var out := {"station": station, "count": 1, "speed": p["speed"], "zone": p["zone"], "practice": true,
		"title": "Practice — " + str(tutorial(mechanic(args))["name"]), "subtitle": "Tutorial difficulty · nothing you do here affects your work"}
	if args.has("minigame"):
		out["minigame"] = args["minigame"]
	return out
