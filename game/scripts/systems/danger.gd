## Danger — the one authoritative danger model (R2 "Truthful World Model"; TECH-018, ADV-021, ADV-017, WLD-018).
## EN: Every system that weighs danger asks here: adventurer parties choosing where to go, the fights themselves (the
##     ambush check), the smith's consultations, sponsorship offers and prices, hireling trips, the world map and the
##     sheets. Before R2 there were three models: `Regions.danger` (destinations.json's 1–8 scale, lowered by scouting —
##     used by hirelings and the legacy resolver), `Expeditions.rating` / `WorldSites.danger` (the live enemy strength —
##     used by parties, consultations and sponsorship) and destinations.json `threats` (consultation advice), so advice,
##     hireling odds and scouting claims could disagree with what parties actually fight.
##     Now:
##       site(rid)        the live danger of a place as a party meets it today: the strongest group of foes there
##                        (WorldSites.enemies_at: a slain master is gone, growing threats add foes) — what fights hold;
##       ratio(rid, s)    that danger at the campaign difficulty against a party strength `s` (consultations, sponsors);
##       threats(rid)     the foes actually there today, with their weaknesses and resistances (advice, wish lists);
##       knowledge(rid)   0..1, the village's scouting knowledge of the place (Regions.scouted / SCOUT_MAX);
##       ambush_dc(rid)   the DC a party's scout rolls to spot foes first: well-charted ground is easier to read
##                        (up to −3) — the real, fought effect of "the safe paths" a friend tells the smith about;
##       trip(dest)       a hireling's trip danger (destinations.json scale) moved by the place's live state (more or
##                        fewer foes than the place started with) and lowered by scouting knowledge — the same place,
##                        the same facts, for every hand.
##     All reads are pure.
## DA: Én fælles farevurdering for eventyrere, kampe, råd, sponsorater, daglejere, kortet og arkene.
class_name Danger
extends RefCounted

## Scouting lowers a hireling trip's danger by up to this share, and a party's ambush DC by up to AMBUSH_DC_MAX.
const KNOWLEDGE_TRIP := 0.3
const AMBUSH_DC_MAX := 3
## A hireling trip's danger follows the place's live strength, within these bounds of how it started.
const SITE_SCALE_MIN := 0.5
const SITE_SCALE_MAX := 2.0


## The live danger of a place (0 for an unknown id).
static func site(rid: String) -> float:
	if Expeditions.region(rid).is_empty():
		return 0.0
	return Expeditions.rating(rid)


## The danger at the campaign difficulty against a party strength (>1 = stronger than them).
static func ratio(rid: String, strength: float) -> float:
	return site(rid) * float(Expeditions.diff().get("enemy", 1.0)) / maxf(1.0, strength)


## "fair" / "risky" / "dangerous" / "deadly" — the map's and the sheets' word for site().
static func word(rid: String) -> String:
	var r := site(rid)
	if r >= 95.0:
		return "deadly"
	if r >= 70.0:
		return "dangerous"
	if r >= 45.0:
		return "risky"
	return "fair"


## The village's scouting knowledge of a place, 0..1.
static func knowledge(rid: String) -> float:
	return clampf(Regions.scouted(rid) / Regions.SCOUT_MAX, 0.0, 1.0)


## The DC a party's scout rolls to spot the foes first (base DC 12, +2 at a master's lair), less what the village
## knows of the ground: up to −3 when the place is well charted.
static func ambush_dc(rid: String, boss := false) -> int:
	return 12 + (2 if boss else 0) - int(floor(float(AMBUSH_DC_MAX) * knowledge(rid)))


## The foes actually at a place today (every node, each kind once): [{id, name, kind, power, weak, resist}].
static func threats(rid: String) -> Array:
	var out := []
	var seen := {}
	for n in Expeditions.region(rid).get("nodes", []):
		for spec in WorldSites.enemies_at(rid, n):
			var id := str(spec[0])
			if seen.has(id):
				continue
			seen[id] = true
			var en: Dictionary = DB.enemies.get(id, {})
			out.append({"id": id, "name": str(en.get("name", id)), "kind": str(en.get("kind", "")), "power": int(en.get("power", 10)),
				"weak": str(en.get("weak", "")), "resist": str(en.get("resist", ""))})
	return out


## The strength of a place as it started (every node's own foes, the master alive, the starting threat).
static func base_site(rid: String) -> float:
	var r := 0.0
	for n in Expeditions.region(rid).get("nodes", []):
		var p := 0.0
		for e in n.get("enemies", []):
			p += float(DB.enemies.get(str(e[0]), {}).get("power", 10)) * int(e[1])
		r = maxf(r, p)
	return r * WorldSites.threat_factor(WorldSites.START_THREAT)


## How the place stands against how it started (1.0 = unchanged), within SITE_SCALE_MIN..MAX.
static func site_scale(rid: String) -> float:
	var b := base_site(rid)
	if b <= 0.0:
		return 1.0
	return clampf(site(rid) / b, SITE_SCALE_MIN, SITE_SCALE_MAX)


## A hireling's (or the legacy resolver's) trip danger on destinations.json's scale: the place's own danger, moved by
## its live state and lowered by what the village knows of it.
static func trip(dest: String) -> float:
	var d: Dictionary = DB.destinations.get(dest, {})
	return float(d.get("danger", 1)) * site_scale(dest) * (1.0 - KNOWLEDGE_TRIP * knowledge(dest))
