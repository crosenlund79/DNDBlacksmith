## Reputation — the one entry point for the smith's standing (R2 "Truthful World Model"; TECH-019, WLD-013, WLD-011 data
## model; decision D-7 approved 17 November 2026).
## EN: Before R2 the standing was one number: the mean affection of the village's adventurers and villagers (×0.8) plus
##     what people had heard (`world.rep`, −60…60), read directly by about a dozen systems. Canonical §9.2 (D10) wants
##     reputation by audience and place, spreading gradually through real channels. R2 lays the data foundation only:
##       AUDIENCES  villagers, adventurers, traders, artisans (and dwarves), nobility — and each civilization
##                  ("civ:<id>"), none of which exists yet;
##       PLACES     the village, the region — and each civilization ("civ:<id>").
##     `word[audience][place]` is what that audience in that place has heard of the smith. Every change still lands on
##     every audience in the village, exactly as the single number behaved, so standing() is unchanged; the region
##     hears nothing yet. Spreading news between places and audiences (and who hears what) is R8, not here. The mayor and
##     civilizations are not created here either.
##     standing()                    the general standing in the village (the old Shop.reputation): what systems read;
##     standing_of(audience, place)  one audience's standing in one place (its own people's affection + its word);
##     word(audience, place)         what they have heard; change(delta, why) as Shop.rep_change did;
##     word_text()                   "notorious" … "renowned" (the old Shop.reputation_word).
##     State: Game.state["reputation"] = {"word": {audience: {place: float}}} (created on first write; reads are pure).
##     Save step 10 moves an older save's `world.rep` into the village cells.
## DA: Ét indgangspunkt for smedens omdømme, med publikum og steder som dimensioner (spredning kommer i R8).
class_name Reputation
extends RefCounted

const AUDIENCES := ["villagers", "adventurers", "traders", "artisans", "nobility"]
const PLACES := ["village", "region"]
const CIV_PREFIX := "civ:"
## The people whose affection counts toward an audience's standing (character kinds); others use the village's mean.
const AUDIENCE_KINDS := {"villagers": ["villager"], "adventurers": ["adventurer"]}
const WORD_MIN := -60.0
const WORD_MAX := 60.0
const AFFECTION_WEIGHT := 0.8


## Every audience: the fixed ones and one per civilization (none yet: civilizations arrive with the regional proof).
static func audiences() -> Array:
	var out := AUDIENCES.duplicate()
	for c in civilizations():
		out.append(CIV_PREFIX + str(c))
	return out


static func places() -> Array:
	var out := PLACES.duplicate()
	for c in civilizations():
		out.append(CIV_PREFIX + str(c))
	return out


## The civilizations known to the data (an empty list until they are designed and built — R9/R10).
static func civilizations() -> Array:
	return (DB.get("civilizations") if DB.get("civilizations") is Array else [])


static func _st() -> Dictionary:
	return Game.state.get("reputation", {}) if Game.state.get("reputation") is Dictionary else {}


static func _w() -> Dictionary:
	if not Game.state.get("reputation") is Dictionary:
		Game.state["reputation"] = {"word": {}}
	var r: Dictionary = Game.state["reputation"]
	if not r.get("word") is Dictionary:
		r["word"] = {}
	return r["word"]


## What `audience` in `place` has heard of the smith (0 when nothing yet).
static func word(audience: String, place := "village") -> float:
	return float(_st().get("word", {}).get(audience, {}).get(place, 0.0))


static func _mean_aff(kinds: Array) -> float:
	var tot := 0.0
	var n := 0
	for npc in Game.state.get("social", {}):
		if str(DB.character(npc).get("kind", "")) in kinds:
			tot += float(Game.state["social"][npc]["aff"])
			n += 1
	return tot / maxf(1.0, n)


## The general standing in the village: the mean affection of its adventurers and villagers and what the village has
## heard — the single figure every system has read since the first builds (unchanged by R2).
static func standing() -> float:
	var w := 0.0
	for a in AUDIENCES:
		w += word(a, "village")
	w /= float(AUDIENCES.size())
	return clampf(_mean_aff(["adventurer", "villager"]) * AFFECTION_WEIGHT + w, -100.0, 100.0)


## One audience's standing in one place: its own people's affection where they are simulated (else the village's) plus
## what it has heard there.
static func standing_of(audience: String, place := "village") -> float:
	var kinds: Array = AUDIENCE_KINDS.get(audience, ["adventurer", "villager"])
	return clampf(_mean_aff(kinds) * AFFECTION_WEIGHT + word(audience, place), -100.0, 100.0)


## Word of the smith's deeds. Where it happens (`place`, the village unless said otherwise) every audience hears it at
## once, as the single number did. R8 (WLD-012, QST-010): it becomes news there, and other places hear it only when a
## real channel carries it (carry: travel, a ship, a letter) — never instantly.
static func change(delta: float, why := "", place := "village") -> void:
	var w := _w()
	for a in audiences():
		if not w.get(a) is Dictionary:
			w[a] = {}
		w[a][place] = clampf(float(w[a].get(place, 0.0)) + delta, WORD_MIN, WORD_MAX)
	if why != "" and absf(delta) >= 3.0:
		Game.journal(("Word gets around: " if delta > 0 else "Tongues wag: ") + why)
	_news(delta, why, place)


# ======================================================================= R8: news and its channels
## How much of a piece of news survives being carried to another place.
const CARRY := 0.5
const NEWS_KEEP := 120
## The channels and the audiences each one reaches.
const CHANNELS := {"travel": ["adventurers", "traders", "villagers"], "ship": ["traders", "artisans"], "letter": ["nobility", "traders"]}


static func news() -> Array:
	return _st().get("news", []) if _st().get("news") is Array else []


## One piece of news per place and day: the day's changes there, summed, with the first reasons.
static func _news(delta: float, why: String, place: String) -> void:
	if absf(delta) < 0.01:
		return
	var r: Dictionary = Game.state["reputation"]
	if not r.get("news") is Array:
		r["news"] = []
	var list: Array = r["news"]
	var today := Game.day()
	var n: Dictionary = {}
	for i in range(list.size() - 1, maxi(-1, list.size() - 6), -1):
		# the day's news at that place, while it has not yet left it (news already carried away stays as it was heard)
		if int(list[i]["day"]) == today and str(list[i]["origin"]) == place and (list[i]["heard"] as Dictionary).size() == 1:
			n = list[i]
			break
	if n.is_empty():
		r["seq"] = int(r.get("seq", 0)) + 1
		n = {"id": "news_%d_%s_%d" % [today, place, int(r["seq"])], "day": today, "origin": place, "delta": 0.0, "why": [], "heard": {place: {}}, "via": {}}
		for a in audiences():
			n["heard"][place][a] = today
		list.append(n)
		while list.size() > NEWS_KEEP:
			list.pop_front()
	n["delta"] = float(n["delta"]) + delta
	if why != "" and (n["why"] as Array).size() < 3:
		(n["why"] as Array).append(why)


## Has `audience` in `place` heard this news?
static func heard(n: Dictionary, place: String, audience: String) -> bool:
	return (n.get("heard", {}).get(place, {}) as Dictionary).has(audience)


## A channel carries what `from` knows to `to`: each audience the channel reaches hears there what it had not heard,
## at CARRY of its weight. Returns how many pieces of news reached someone new.
static func carry(from: String, to: String, channel: String) -> int:
	if from == to or _st().is_empty():
		return 0
	var auds: Array = CHANNELS.get(channel, [])
	var w := _w()
	var moved := 0
	for n in news():
		var any := false
		for a in auds:
			if not heard(n, from, a) or heard(n, to, a):
				continue
			if not (n["heard"] as Dictionary).has(to):
				n["heard"][to] = {}
			n["heard"][to][a] = Game.day()
			if not (n["via"] as Dictionary).has(to):
				n["via"][to] = {}
			n["via"][to][a] = channel   # how this audience there heard it
			if not w.get(a) is Dictionary:
				w[a] = {}
			w[a][to] = clampf(float(w[a].get(to, 0.0)) + float(n["delta"]) * CARRY, WORD_MIN, WORD_MAX)
			any = true
		if any:
			moved += 1
	return moved


## The latest news `audience` in `place` has heard from elsewhere, with its channel ({} when none).
static func latest_heard(place: String, audience: String) -> Dictionary:
	for i in range(news().size() - 1, -1, -1):
		var n: Dictionary = news()[i]
		if str(n["origin"]) != place and heard(n, place, audience) and float(n["delta"]) > 0.0:
			return n
	return {}


## Tests and developer tools: set what the village has heard (every audience).
static func set_village_word(value: float) -> void:
	var w := _w()
	for a in audiences():
		if not w.get(a) is Dictionary:
			w[a] = {}
		w[a]["village"] = clampf(value, WORD_MIN, WORD_MAX)


static func word_text() -> String:
	var r := standing()
	if r <= -25.0:
		return "notorious"
	if r <= -8.0:
		return "poorly thought of"
	if r < 8.0:
		return "a modest name"
	if r < 25.0:
		return "well respected"
	return "renowned"


## Save step 10: an older save's single `world.rep` becomes what every audience in the village has heard; the region
## starts with nothing heard (spreading is R8). Idempotent; returns 1 when it moved a value.
static func migrate(state: Dictionary) -> int:
	var world: Dictionary = state.get("world", {}) if state.get("world") is Dictionary else {}
	if not world.has("rep"):
		return 0
	var v := clampf(float(world["rep"]), WORD_MIN, WORD_MAX)
	world.erase("rep")
	if not state.get("reputation") is Dictionary:
		state["reputation"] = {"word": {}}
	var w: Dictionary = state["reputation"]["word"]
	for a in AUDIENCES:
		if not w.get(a) is Dictionary:
			w[a] = {}
		w[a]["village"] = v
	return 1
