## Militia — the Brindlewick muster, autonomous, equipped by what it really holds (R8 "World Recognition"; WLD-006,
## WLD-007, WLD-009, WLD-010, WLD-014, WLD-021; decision 13). No soldiers to command and no military loop (WLD-008).
## EN: The muster is the R4 institution "muster": its stock is the kit consignments put there (helms, shields, blades,
##     armour — every piece a real item with its maker and lot). From it:
##       readiness()  0..1 — serviceable kit against what a full patrol needs (NEED pieces; a piece counts by its
##                    quality, a broken one by half, an unusable one not at all);
##       patrol()     0..1 — the patrols actually walked: each day it moves DRIFT of the way toward readiness, so new kit
##                    shows over weeks, and neglect fades as slowly (no switch, no instant safe zone);
##       reach(rid)   how far the patrols carry: the nearer a place (fewer days on the road), the more it feels them —
##                    a smooth fall-off, no hard circle;
##       thin(rid, …) decision 13: bandit pressure scales down with the patrols — at a place, the common bandits
##                    (road bandits, crossbowmen, war-hounds; never a named master) number fewer, by up to BANDIT_CUT of
##                    them at full patrol and full reach, and never fewer than one where there were any.
##     Because WorldSites.enemies_at applies thin(), every reader of the one danger model sees the same truth: the live
##     site danger (Danger.site), the hireling and trade roads (Danger.trip), escort prices (Escorts), the parties'
##     choices and the map's words. The patrols wear the kit a little (WEAR_EVERY days, one point of durability).
##     State: Game.state["militia"] = {patrol, last_wear} — created on the first day the muster holds anything.
## DA: Militsen: udstyret den virkelig har, patruljer der langsomt følger det, og færre røvere nær landsbyen.
class_name Militia
extends RefCounted

const INSTITUTION := "muster"
const SLOTS := ["weapon", "armor", "shield", "helmet"]
## Serviceable pieces a fully equipped patrol needs (about a dozen people, each with two pieces).
const NEED := 24.0
## A piece of this score counts as one full piece of kit (an iron helm of good make is about one; finer pieces do not
## count for more than one).
const REF_SCORE := 10.0
## Each day, the patrols move this share of the way toward what the kit allows.
const DRIFT := 0.05
## A place this many days down the road (or nearer) feels the patrols fully; farther ones less.
const REACH_DAYS := 1.5
## At full patrol and full reach, this share of the common bandits are gone.
const BANDIT_CUT := 0.6
const BANDITS := ["bandit", "bandit_archer", "war_hound"]
const WEAR_EVERY := 5


static func st() -> Dictionary:
	var m: Variant = Game.state.get("militia", {})
	return m if m is Dictionary else {}


## The kit the muster holds: usable pieces in the patrol's slots.
static func kit() -> Array:
	return Institutions.stock(INSTITUTION).filter(func(it): return SLOTS.has(Items.slot(it)) and GearDepth.usable(it))


## Serviceable kit in "full pieces": the individual pieces in stock and the bulk supply consignments delivered (R4:
## an order's bench pieces are kept as counts with their mean quality).
static func kit_points() -> float:
	var p := 0.0
	for it in kit():
		var v := minf(1.0, Items.score(it) / REF_SCORE)
		if bool(it.get("broken", false)):
			v *= 0.5
		p += v
	var sup: Dictionary = Institutions.peek(INSTITUTION).get("supply", {})
	for d in sup:
		var n := int(sup[d].get("n", 0))
		if n <= 0 or not SLOTS.has(str(DB.item(str(d)).get("slot", ""))):
			continue
		var q := float(sup[d].get("q_sum", 0.0)) / float(n)
		p += float(n) * minf(1.0, Items.score(Items.make(str(d), {"quality": q})) / REF_SCORE)
	return p


static func readiness() -> float:
	return clampf(kit_points() / NEED, 0.0, 1.0)


static func patrol() -> float:
	return float(st().get("patrol", 0.0))


## How strongly the patrols reach a place: 1 within REACH_DAYS, falling off smoothly with the road's length.
static func reach(rid: String) -> float:
	var d: Dictionary = DB.destinations.get(rid, {})
	if d.is_empty():
		return 0.0
	var r: Array = d.get("days", [1, 1])
	var days := (float(r[0]) + float(r[1])) / 2.0
	return clampf(REACH_DAYS / maxf(0.5, days), 0.0, 1.0)


## The patrols' weight at a place (0..1).
static func effect(rid: String) -> float:
	return patrol() * reach(rid)


static func is_bandit(enemy_id: String) -> bool:
	return BANDITS.has(enemy_id)


## Decision 13: the common bandits at a place, thinned by the patrols. `specs` = [[enemy id, count], …] (a new array).
static func thin(rid: String, specs: Array) -> Array:
	var e := effect(rid)
	if e <= 0.0:
		return specs
	var out := []
	for spec in specs:
		var id := str(spec[0])
		var n := int(spec[1])
		if is_bandit(id) and n > 0:
			n = maxi(1, n - int(round(float(n) * BANDIT_CUT * e)))
		out.append([spec[0], n])
	return out


## How many common bandits stand at a place today (every node).
static func bandits_at(rid: String) -> int:
	var n := 0
	for node in Expeditions.region(rid).get("nodes", []):
		for spec in WorldSites.enemies_at(rid, node):
			if is_bandit(str(spec[0])):
				n += int(spec[1])
	return n


## The daily round: the patrols follow the kit; walking them wears it a little.
static func on_day(day: int) -> void:
	if Game.state.is_empty():
		return
	if not Game.state.get("militia") is Dictionary:
		if Institutions.stock(INSTITUTION).is_empty() and (Institutions.peek(INSTITUTION).get("supply", {}) as Dictionary).is_empty():
			return
		Game.state["militia"] = {"patrol": 0.0, "last_wear": day}
	var m: Dictionary = Game.state["militia"]
	var target := readiness()
	var p := float(m.get("patrol", 0.0))
	m["patrol"] = clampf(p + (target - p) * DRIFT, 0.0, 1.0)
	if day - int(m.get("last_wear", day)) >= WEAR_EVERY:
		m["last_wear"] = day
		for it in kit():
			var s2: Dictionary = it.get("stats", {})
			if s2.has("durability") and int(s2["durability"]) > 0:
				s2["durability"] = int(s2["durability"]) - 1
		var sup: Dictionary = Institutions.peek(INSTITUTION).get("supply", {})
		for d in sup:   # bulk kit wears too: its mean quality slips a little on every patrol cycle
			sup[d]["q_sum"] = maxf(0.0, float(sup[d].get("q_sum", 0.0)) - 0.2 * float(int(sup[d].get("n", 0))))


## A line for the map and the muster's record: what the patrols do here, from real values ("" when nothing).
static func line(rid: String) -> String:
	var e := effect(rid)
	if e < 0.02:
		return ""
	return "Muster patrols reach here (%d%%): fewer bandits on the road." % int(round(e * 100.0))
