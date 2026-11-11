## HealthLog — an adventurer's health over time, only from values the game actually recorded (Living Workshop #38).
## EN: Two real sources, merged for the character sheet's curve:
##     1. the health log, recorded from now on: every hour (Sim.on_hour) a point is written for an adventurer the first
##        time, and then whenever their health has moved by a tenth of their maximum since the last point (or the
##        maximum changed, or they fell); nothing while it holds steady, so a quiet or retired adventurer costs no
##        space. Capped at CAP points each (the oldest drop first). Kept lazily on the adventurer as
##        a["hp_log"] = [[minute, hp, hp_max, kind], …]; Game.state["health_since"] is the day recording began in
##        this save (day 1 for a new game, the first hour after loading for an older one).
##     2. the fight records the expedition archive already keeps (Expeditions.active()/done(): each combat's
##        party health before the fight and their state after it).
##     The curve ends at their health now (live state). Nothing is interpolated or invented: before the first recorded
##     point the sheet says "No record before day N".
## DA: En eventyrers helbred over tid — kun fra værdier, spillet faktisk har registreret; intet opfindes.
class_name HealthLog
extends RefCounted

const KEY := "hp_log"
const CAP := 120
## kind → words (tooltips and tests)
const KIND_WORD := {"h": "health recorded", "f": "before a fight", "a": "after a fight", "x": "fell", "n": "now"}


## Hourly (Sim.on_hour): a point for each adventurer whose health moved (and a first point for each).
static func on_hour(_h: int) -> void:
	if Game.state.is_empty():
		return
	if not Game.state.has("health_since"):
		Game.state["health_since"] = Game.day()
	for a in Adv.all().values():
		sample(a)


## Records the adventurer's current health when it is worth a point (see the header). `force` always writes one.
static func sample(a: Dictionary, kind := "h", force := false) -> void:
	if not a.has("hp") or not a.has("hp_max"):
		return
	var hp := maxi(0, int(a["hp"]))
	var mx := maxi(1, int(a["hp_max"]))
	var dead := str(a.get("status", "")) == "dead"
	var lg: Array = a.get(KEY, [])
	if not lg.is_empty() and not force:
		var last: Array = lg[-1]
		if dead and int(last[1]) == 0:
			return   # the fall is recorded once
		var moved := absi(int(last[1]) - hp) >= maxi(1, int(round(mx * 0.1))) or int(last[2]) != mx or (dead and hp == 0)
		if not moved:
			return
	if dead:
		kind = "x"
	lg.append([Game.now(), hp, mx, kind])
	while lg.size() > CAP:
		lg.pop_front()
	a[KEY] = lg


## Every recorded point for an adventurer, oldest first: [{t, hp, max, kind}] — the log merged with the fight records
## still in the expedition archive (same minute → the log's point wins). [] when nothing was ever recorded.
static func points(adv_id: String) -> Array:
	var a := Adv.get_a(adv_id)
	if a.is_empty():
		return []
	var by_t := {}
	for e in (Expeditions.active().values() + Expeditions.done()):
		if not (e is Dictionary) or not (e.get("party", []) as Array).has(adv_id):
			continue
		for rec in e.get("encounters", []):
			if not (rec is Dictionary) or str(rec.get("kind", "")) != "combat" or not rec.has("t"):
				continue
			var t0 := int(rec["t"])
			for p in rec.get("party", []):
				if str(p.get("id", "")) == adv_id:
					by_t[t0] = {"t": t0, "hp": maxi(0, int(p.get("hp", 0))), "max": int(p.get("hp_max", 1)), "kind": "f"}
			var snap: Dictionary = (rec.get("party_snap", {}) as Dictionary).get(adv_id, {})
			if not snap.is_empty():
				var t1 := t0 + 1   # the record keeps the party's state when the fight was written up, right after it
				by_t[t1] = {"t": t1, "hp": maxi(0, int(snap.get("hp", 0))), "max": int(snap.get("hp_max", 1)), "kind": "a"}
	for p in a.get(KEY, []):
		if p is Array and (p as Array).size() >= 3:
			by_t[int(p[0])] = {"t": int(p[0]), "hp": int(p[1]), "max": int(p[2]), "kind": str(p[3]) if (p as Array).size() > 3 else "h"}
	var ts := by_t.keys()
	ts.sort()
	var out := []
	for t in ts:
		out.append(by_t[t])
	# the curve ends at their health now — the live value, not a recorded one (kind "n"; never stored)
	if not out.is_empty() and int(out[-1]["t"]) < Game.now() and a.has("hp") and a.has("hp_max"):
		out.append({"t": Game.now(), "hp": maxi(0, int(a["hp"])), "max": int(a["hp_max"]), "kind": "n"})
	return out


## How many of these points are records (the live "now" point is not one).
static func recorded(pts: Array) -> int:
	return pts.filter(func(p): return str(p["kind"]) != "n").size()


## The day of the first recorded point (0 when there is none).
static func first_day(pts: Array) -> int:
	return int(int(pts[0]["t"]) / 1440) + 1 if not pts.is_empty() else 0


## The honest caption under the curve.
static func caption(pts: Array) -> String:
	if pts.is_empty():
		var since := int(Game.state.get("health_since", Game.day()))
		return "No health recorded yet — the record began on day %d." % since
	var d := first_day(pts)
	var n := recorded(pts)
	if d <= 1:
		return "Recorded from day 1 · %d point%s." % [n, "" if n == 1 else "s"]
	return "No record before day %d · %d point%s since." % [d, n, "" if n == 1 else "s"]
