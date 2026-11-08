## CompanionFollowers — adventurers' creature companions following them about the village.
## EN: For every adventurer whose NPC is visible and who keeps a companion (Companions.of), a small creature
##     miniature (creatures/<id>, two 64×64 frames) trots behind them along the path they actually walked (their
##     position history), so it goes through doorways and round walls exactly as they did. Ground creatures
##     trot; flying ones (falcon, moth, drake) bob above a soft shadow. One hook in world.gd adds this node.
## DA: Eventyrernes dyr følger dem gennem landsbyen ad den vej, de selv gik.
class_name CompanionFollowers
extends Node2D

const FOLLOW_DIST := 46.0     # how far behind along the trail the creature keeps
const SIDE := 16.0            # sideways offset so it does not stand inside its keeper
const TRAIL_STEP := 6.0

var world: Node
var followers := {}            # adv id -> Follower
var _scan_t := 0.0


func _init(w: Node = null) -> void:
	world = w
	y_sort_enabled = true
	name = "CompanionFollowers"


func _ready() -> void:
	_scan()


func _process(delta: float) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_scan()


## Adds, updates and removes followers to match who keeps which companion.
func _scan() -> void:
	if world == null or Game.state.is_empty() or not Game.state.has("adventurers"):
		return
	var npcs: Dictionary = world.get("npcs") if world.get("npcs") is Dictionary else {}
	var want := {}
	for a in Adv.all().values():
		var comp := Companions.of(a)
		var id := str(a.get("id", ""))
		if comp.is_empty() or not npcs.has(id):
			continue
		want[id] = comp
	for id in followers.keys():
		var f: Follower = followers[id]
		if not want.has(id) or f.sprite_id != Companions.sprite(want[id]):
			f.queue_free()
			followers.erase(id)
	for id in want:
		if not followers.has(id):
			var f := Follower.new()
			f.setup(npcs[id], want[id])
			add_child(f)
			followers[id] = f


## The follower attached to an adventurer (null when none) — used by tests and the playtest.
func follower_of(adv_id: String) -> Node2D:
	return followers.get(adv_id, null)


class Follower:
	extends Node2D

	var keeper: Node2D
	var sprite_id := ""
	var spr: Sprite2D
	var shadow: Polygon2D
	var fly := false
	var trail: Array[Vector2] = []
	var anim_t := 0.0
	var bob_t := 0.0
	var moving := false
	var side := 1.0

	func setup(k: Node2D, comp: Dictionary) -> void:
		keeper = k
		sprite_id = Companions.sprite(comp)
		fly = Companions.flying(comp)
		side = -1.0 if absi(str(comp.get("uid", 0)).hash()) % 2 == 0 else 1.0
		shadow = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			var t := TAU * i / 16.0
			pts.append(Vector2(cos(t) * 14.0, sin(t) * 5.0))
		shadow.polygon = pts
		shadow.color = Color(0.12, 0.07, 0.04, 0.28)
		shadow.visible = fly
		add_child(shadow)
		spr = Sprite2D.new()
		spr.texture = Assets.get_tex(sprite_id, Vector2i(128, 64))
		spr.hframes = 2
		spr.offset = Vector2(0, -24)
		spr.scale = Vector2(1.1, 1.1)
		add_child(spr)
		position = keeper.position + Vector2(side * SIDE, 10)
		trail.append(keeper.position)
		visible = keeper.visible

	func _process(delta: float) -> void:
		if keeper == null or not is_instance_valid(keeper):
			queue_free()
			return
		if not keeper.visible:
			visible = false
			trail.clear()
			return
		if not visible:
			# reappearing (out of the inn, back from the road): start right beside the keeper
			visible = true
			position = keeper.position + Vector2(side * SIDE, 10)
			trail.clear()
		var kp: Vector2 = keeper.position
		if trail.is_empty() or trail[trail.size() - 1].distance_to(kp) >= TRAIL_STEP:
			if not trail.is_empty() and trail[trail.size() - 1].distance_to(kp) > 400.0:
				trail.clear()   # the keeper took the stairs or was teleported: no trail across the map
				position = kp + Vector2(side * SIDE, 10)
			trail.append(kp)
			while trail.size() > 80:
				trail.remove_at(0)
		var target := _trail_point()
		var d := target - position
		moving = d.length() > 3.0
		if moving:
			var sp := clampf(d.length() * 4.0, 30.0, 420.0)
			position += d.normalized() * minf(d.length(), sp * delta)
			if absf(d.x) > 1.0:
				spr.flip_h = d.x < 0.0
		elif absf(kp.x - position.x) > 4.0:
			spr.flip_h = kp.x < position.x
		anim_t += delta * (7.0 if moving else 1.6)
		spr.frame = int(anim_t) % 2
		if fly:
			bob_t += delta
			spr.offset = Vector2(0, -44 + sin(bob_t * 3.2) * 5.0)
			shadow.scale = Vector2.ONE * (0.9 + 0.08 * sin(bob_t * 3.2))
		else:
			spr.offset = Vector2(0, -24 - (absf(sin(anim_t * PI)) * 2.0 if moving else 0.0))

	## The point FOLLOW_DIST behind the keeper along the trail, nudged sideways.
	func _trail_point() -> Vector2:
		var acc := 0.0
		var i := trail.size() - 1
		while i > 0:
			var seg := trail[i].distance_to(trail[i - 1])
			if acc + seg >= FOLLOW_DIST:
				var p := trail[i].lerp(trail[i - 1], (FOLLOW_DIST - acc) / maxf(seg, 0.001))
				var dir := (trail[i] - trail[i - 1]).normalized()
				return p + Vector2(-dir.y, dir.x) * side * SIDE * 0.6
			acc += seg
			i -= 1
		return trail[0] + Vector2(side * SIDE, 10) if not trail.is_empty() else position
