## QuickTravel — a walk across the village at accelerated visual speed that still costs the full walking time.
## EN: A plan is a path of waypoints (with stair "jumps" between floors). Stepping it moves a position along
##     the path and advances the game clock in minutes, in proportion to the distance covered, so the clock
##     ends exactly at the normal walking duration (path length ÷ walking speed). Time-driven systems
##     (schedules, customers, expeditions) see every minute through Game.advance_minutes.
##     The world's PlayerNav drives a plan frame by frame; tests drive it directly.
## DA: Hurtigrejse: smeden går ruten i højt tempo, men uret flyttes præcist den normale gåtid frem.
class_name QuickTravel
extends RefCounted

const SPEED_MULT := 5.0          # visual speed relative to walking

var points := PackedVector2Array()
var jumps := {}                  # index i -> true: the hop from points[i] to points[i+1] is a stairway
var length := 0.0                # walked distance (stair hops excluded)
var minutes := 0                 # the clock cost of the whole walk
var covered := 0.0
var applied := 0                 # minutes already on the clock (advanced here or run naturally)
var idx := 0                     # next waypoint
var pos := Vector2.ZERO
var dest := ""                   # destination id (for messages)


## Game minutes that walking `length_px` normally takes (walking speed, the day-length setting).
static func walk_minutes(length_px: float) -> int:
	if length_px <= 0.0:
		return 0
	var secs := length_px / PlayerBody.WALK
	return maxi(1, int(round(secs * Game.MINUTES_PER_SECOND * float(Settings.get_value("gameplay/time_scale", 1.0)))))


## Length of a path, without its stair hops.
static func path_length(pts: PackedVector2Array, hops := {}) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		if not hops.has(i):
			l += pts[i].distance_to(pts[i + 1])
	return l


## Why quick travel cannot start now ("" = it can). A window that stops the clock, a fade or a scene blocks it.
static func blocked_reason() -> String:
	if Game.state.is_empty():
		return "There is no game running."
	if Game.ui_blockers > 0:
		return "Not now — finish what you are doing first."
	return ""


static func make(pts: PackedVector2Array, hops := {}, dest_id := "") -> QuickTravel:
	var q := QuickTravel.new()
	q.points = pts
	q.jumps = hops
	q.length = path_length(pts, hops)
	q.minutes = walk_minutes(q.length)
	q.pos = pts[0] if pts.size() > 0 else Vector2.ZERO
	q.idx = 1
	q.dest = dest_id
	return q


func done() -> bool:
	return idx >= points.size()


## Minutes that should be on the clock for the distance covered so far.
func minutes_due() -> int:
	if length <= 0.0:
		return minutes
	return int(floor(float(minutes) * clampf(covered / length, 0.0, 1.0)))


## Counts minutes the clock ran by itself during the trip (they are part of the cost, not extra).
func note_natural(m: int) -> void:
	applied += maxi(0, m)


## Moves `dist` pixels along the path (stair hops are instant); returns the new position.
## Advances the clock by whatever the distance now owes. Returns the direction moved in `last_dir`.
var last_dir := Vector2.ZERO


func step(dist: float) -> Vector2:
	var left := dist
	while left > 0.0 and not done():
		if jumps.has(idx - 1):
			pos = points[idx]
			idx += 1
			continue
		var tgt := points[idx]
		var d := tgt - pos
		var l := d.length()
		if l <= left:
			pos = tgt
			covered += l
			left -= l
			idx += 1
		else:
			pos += d / l * left
			covered += left
			left = 0.0
		if l > 0.001:
			last_dir = d / l
	if done():
		covered = length
	_pay()
	return pos


## Puts the owed minutes on the clock.
func _pay() -> void:
	var due := minutes if done() else minutes_due()
	if due > applied:
		var m := due - applied
		applied = due
		Game.advance_minutes(m)


## Stops where we are: the distance already walked has been paid for.
func cancel() -> void:
	_pay()
	points = points.slice(0, idx)
