## PetFollower — the smith's own creature at his heel (The Living Workshop #52).
## EN: When the smith keeps a creature from Hale Farm in his stores (Family.pet: not on display, not promised to an
##     order — never an adventurer's companion), its miniature walks with him through the village, his forge and the
##     loft, with the adventurers' companion behaviour and art (CompanionFollowers.Follower: it trots along the path he
##     actually walked, flyers sway on their stand). It follows an anchor that tracks him wherever it may go with him
##     (WITH_HIM); when he goes into someone else's house, the inn, a shop or the chapel, it waits outside, beside the
##     doorstep, until he comes out. When he stands still it does not settle in a doorway or on a station or other solid
##     footprint: it takes a clear spot beside him instead. The steward's working smith is the same figure, so the
##     creature keeps him company under the steward too. One line in world.gd adds this node.
## DA: Smedens eget dyr følger ham rundt — i landsbyen, smedjen og loftet; andre steder venter det udenfor døren.
class_name PetFollower
extends Node2D

## Where the creature goes with him: outdoors, his own forge and the loft above it.
const WITH_HIM := ["village", "smithy", "smithy_loft"]
## A doorway's keep-clear radius (a door is one or two tiles wide).
const DOOR_R := 56.0
## Seconds he must stand still before it looks for a clear resting spot.
const STILL_AFTER := 0.6
## Beside the doorstep when it waits outside.
const WAIT_SIDE := 44.0

var world: Node
var anchor: Node2D
var pet: Pet = null
var uid := -1
var waiting_outside := false
var _scan_t := 0.0
var _still_t := 0.0
var _last := Vector2.INF
var _doors: Array[Vector2] = []


func _init(w: Node = null) -> void:
	world = w
	name = "PetFollower"
	y_sort_enabled = true


func _ready() -> void:
	anchor = Node2D.new()
	anchor.name = "PetAnchor"
	add_child(anchor)
	_collect_doors()
	_scan()


func _process(delta: float) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_scan()
	var pl: Node2D = world.get("player") if world != null else null
	if pl == null or not is_instance_valid(pl):
		return
	anchor.visible = pl.visible
	var where := str(world.get("area"))
	if WITH_HIM.has(where):
		anchor.position = pl.position
		waiting_outside = false
	elif not waiting_outside:
		waiting_outside = true
		var spots: Dictionary = world.get("spots")
		var door_key := where + "_door_out"
		if spots.has(door_key):
			var side := pet.side if pet != null else 1.0
			anchor.position = (spots[door_key] as Vector2) + Vector2(side * WAIT_SIDE, 6.0)
		# (an upper floor elsewhere — the inn's — is reached from inside: it already waits at that building's door)
	if anchor.position.distance_to(_last) > 1.0:
		_still_t = 0.0
	else:
		_still_t += delta
	_last = anchor.position


## Matches the follower to the smith's pet: added, changed or gone (1 s cadence, like CompanionFollowers).
func _scan() -> void:
	if world == null or Game.state.is_empty() or anchor == null:
		return
	var it := Family.pet()
	var want_uid := int(it.get("uid", -1)) if not it.is_empty() else -1
	if pet != null and (want_uid != uid or not is_instance_valid(pet)):
		if is_instance_valid(pet):
			pet.queue_free()
		pet = null
		uid = -1
	if want_uid < 0 or pet != null:
		return
	var pl: Node2D = world.get("player")
	if pl == null:
		return
	anchor.position = pl.position
	pet = Pet.new()
	pet.host = self
	pet.name = "Pet"
	pet.setup(anchor, it)
	add_child(pet)
	uid = want_uid


func still_for() -> float:
	return _still_t


## Doorway centres: every building's door and the smithy's interior doors.
func _collect_doors() -> void:
	_doors.clear()
	if world == null or not world.has_method("brect"):
		return
	for key in ["buildings", "areas"]:
		for b in DB.layout.get(key, []):
			for d in b.get("doors", []):
				_doors.append(world.call("_door_center", world.call("brect", b), d))
	for d2 in world.get("_room_doors"):
		_doors.append(d2["pos"] as Vector2)


## Should it not rest at `p` (a doorway, a station or another solid footprint)?
func keep_clear(p: Vector2) -> bool:
	for dc in _doors:
		if dc.distance_to(p) < DOOR_R:
			return true
	for r in world.get("solid_rects"):
		if (r as Rect2).grow(6.0).has_point(p):
			return true
	return false


## Where it is (for tests and the playtest).
func pet_position() -> Vector2:
	return pet.position if pet != null else Vector2.INF


## The creature: the adventurers' companion follower, settling clear of doorways and stations when he stands still.
class Pet:
	extends CompanionFollowers.Follower

	var host: PetFollower

	func _trail_point() -> Vector2:
		var p: Vector2 = super._trail_point()
		if host == null or host.still_for() < STILL_AFTER or not host.keep_clear(p):
			return p
		var kp: Vector2 = keeper.position
		for off in [Vector2(side * 38.0, 14.0), Vector2(-side * 38.0, 14.0), Vector2(0.0, 44.0), Vector2(side * 30.0, -30.0), Vector2(-side * 30.0, -30.0)]:
			var q: Vector2 = kp + (off as Vector2)
			if not host.keep_clear(q):
				return q
		return p
