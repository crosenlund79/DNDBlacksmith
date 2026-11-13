## Seasons — canonical v1.6 §11: four atmospheric seasons of 21 days each, an 84-day cycle that begins in spring on
## Day 1, and the weather over Brindlewick.
## PRESENTATION ONLY. Everything here is a pure function of the saved calendar (day and minute) and the saved world seed,
## read without writing anything, and it never draws from the game's random number generators. No gameplay system
## reads it: it changes nothing in crafting, combat, expeditions, movement, NPC behaviour, the economy, resources,
## health, fatigue, the calendar, ageing or chronology. Because it is derived from saved values only, the same moment
## looks the same after a save and load or a time skip — there is no season state to save.
## Used by the village's SeasonDressing (palette, snow, particles, light, weather sounds) and the HUD clock tooltip.
class_name Seasons
extends RefCounted

const LENGTH := 21                    # days in a season
const CYCLE := 84                     # four seasons
const ORDER := ["spring", "summer", "autumn", "winter"]
const NAMES := {"spring": "Spring", "summer": "Summer", "autumn": "Autumn", "winter": "Winter"}
const BLEND_DAYS := 3.0               # the last three days of a season turn smoothly into the next
const PERIOD_MIN := 360               # the weather holds for a quarter of a day, then may change …
const RAMP_MIN := 90.0                # … fading out and in over an hour and a half

## The weather each season may bring: [kind, weight, lowest amount, highest amount]. "clear" and "sun" have no
## particles; the others are drawn by SeasonDressing.
const WEATHER := {
	"spring": [["clear", 30, 0.4, 1.0], ["mist", 24, 0.35, 0.8], ["light_rain", 30, 0.3, 0.7], ["blossom", 16, 0.5, 1.0]],
	"summer": [["sun", 52, 0.5, 1.0], ["clear", 22, 0.4, 1.0], ["showers", 26, 0.35, 0.85]],
	"autumn": [["clear", 16, 0.4, 1.0], ["leaves", 28, 0.5, 1.0], ["rain", 30, 0.4, 0.95], ["fog", 26, 0.4, 0.9]],
	"winter": [["overcast", 26, 0.4, 0.9], ["snow", 56, 0.35, 1.0], ["fog", 18, 0.35, 0.75]],
}
const WEATHER_NAMES := {"clear": "clear skies", "sun": "sunshine", "mist": "morning mist", "light_rain": "light rain",
	"blossom": "drifting blossom", "showers": "summer showers", "leaves": "falling leaves", "rain": "rain", "fog": "fog",
	"overcast": "grey skies", "snow": "snowfall"}


## 0 spring, 1 summer, 2 autumn, 3 winter (Day 1 is the first day of spring).
static func index_of(day: int) -> int:
	return (posmod(day - 1, CYCLE)) / LENGTH


static func season(day: int) -> String:
	return ORDER[index_of(day)]


## 1 … 21
static func day_of_season(day: int) -> int:
	return posmod(day - 1, LENGTH) + 1


static func label(day: int) -> String:
	return "%s, day %d of %d" % [NAMES[season(day)], day_of_season(day), LENGTH]


## How much of each season shows at this moment: the season itself, turning into the next over its last BLEND_DAYS
## days (continuous across midnight and across the season's change). {season: weight}, weights sum to 1.
static func weights(day: int, minute: int) -> Dictionary:
	var i := index_of(day)
	var d := float(day_of_season(day) - 1) + float(clampi(minute, 0, 1439)) / 1440.0   # 0 … 21
	var t := smoothstep(float(LENGTH) - BLEND_DAYS, float(LENGTH), d)
	var w := {"spring": 0.0, "summer": 0.0, "autumn": 0.0, "winter": 0.0}
	w[ORDER[i]] = 1.0 - t
	w[ORDER[(i + 1) % 4]] = float(w[ORDER[(i + 1) % 4]]) + t
	return w


## The weather at this moment: {kind, amount 0…1, wind −1…1}. Deterministic in (world seed, day, minute).
static func weather(day: int, minute: int, seed_ := -1) -> Dictionary:
	var sd := _seed() if seed_ < 0 else seed_
	var abs_min := (day - 1) * 1440 + clampi(minute, 0, 1439)
	var p := floori(float(abs_min) / PERIOD_MIN)
	var f := float(abs_min - p * PERIOD_MIN)
	var cur := _period(sd, p)
	var amount := float(cur["amount"])
	if f < RAMP_MIN:
		var prev := _period(sd, p - 1)
		var k := smoothstep(0.0, RAMP_MIN, f)
		amount = lerpf((float(prev["amount"]) + amount) * 0.5, amount, k) if prev["kind"] == cur["kind"] else amount * k
	elif f > PERIOD_MIN - RAMP_MIN:
		var nxt := _period(sd, p + 1)
		var k2 := smoothstep(float(PERIOD_MIN) - RAMP_MIN, float(PERIOD_MIN), f)
		amount = lerpf(amount, (float(nxt["amount"]) + amount) * 0.5, k2) if nxt["kind"] == cur["kind"] else amount * (1.0 - k2)
	var wind := sin(float(abs_min) / 1440.0 * TAU * 0.37 + _h(sd, 77, 3) * TAU) * 0.6 + (_h(sd, floori(float(abs_min) / 1440.0), 5) - 0.5) * 0.8
	return {"kind": str(cur["kind"]), "amount": clampf(amount, 0.0, 1.0), "wind": clampf(wind, -1.0, 1.0)}


## The weather of one quarter-day period: picked from the season of that period's middle (late in a season, sometimes
## already from the next one — the first snow at the end of autumn).
static func _period(sd: int, p: int) -> Dictionary:
	var mid := p * PERIOD_MIN + PERIOD_MIN / 2
	var day := floori(float(mid) / 1440.0) + 1
	var w := weights(day, posmod(mid, 1440))
	var i := index_of(day)
	var s: String = ORDER[i]
	var nxt: String = ORDER[(i + 1) % 4]
	if _h(sd, p, 1) < float(w[nxt]):
		s = nxt
	var table: Array = WEATHER[s]
	var total := 0.0
	for row in table:
		total += float(row[1])
	var r := _h(sd, p, 2) * total
	var pick: Array = table[table.size() - 1]
	for row in table:
		r -= float(row[1])
		if r < 0.0:
			pick = row
			break
	return {"kind": str(pick[0]), "amount": lerpf(float(pick[2]), float(pick[3]), _h(sd, p, 4)), "season": s}


## A fixed hash in [0, 1) — independent of the game's random number generators and of call order.
static func _h(a: int, b: int, c: int) -> float:
	var x := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	x = x & 0xffffffff
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0xffffffff
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0xffffffff
	x = (x >> 16) ^ x
	return float(x & 0xffffff) / 16777216.0


## The saved world seed, read without creating it (an old save without one gets the same sky as any other).
static func _seed() -> int:
	return absi(int(Game.state.get("world_seed", 0))) if not Game.state.is_empty() else 0


## Now, from the saved calendar.
static func now() -> Dictionary:
	var day := Game.day()
	var minute := int(Game.state.get("minute", 720))
	return {"day": day, "minute": minute, "season": season(day), "weights": weights(day, minute), "weather": weather(day, minute)}


## For the HUD clock's tooltip: "Spring, day 3 of 21 — light rain".
static func describe(day: int, minute: int) -> String:
	var w := weather(day, minute)
	var word := str(WEATHER_NAMES.get(str(w["kind"]), str(w["kind"])))
	if float(w["amount"]) < 0.15 and str(w["kind"]) not in ["clear", "sun"]:
		word = "clearing"
	return "%s — %s" % [label(day), word]
