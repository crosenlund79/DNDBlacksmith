## Animal — a village cat or dog, or a horse or cow out at grass: a small tabletop token that idles (sits, looks
## about, grazes) and now and then wanders to a nearby spot within its home range (and its paddock, for livestock).
## Iteration 010: targets come from the world's AnimalNav (free ground with a clear straight line) and every step is
## checked, so animals no longer walk through walls or into houses. Horses and cows call now and then (positional).
## No care mechanics.
## DA: Et landsbydyr: sidder, kigger rundt, græsser og lunter af og til et kort stykke — aldrig gennem mure.
class_name AnimalActor
extends Node2D

var sprite: AnimatedSprite2D
var home := Vector2.ZERO
var range_px := 220.0
var bounds := Rect2()          # paddock (livestock): never leaves it
var target := Vector2.ZERO
var moving := false
var wait_t := 0.0
var speed := 60.0
var facing := "s"
var kind := "cat"              # cat | dog | horse | cow
var is_dog := false
var world: Node = null          # VillageWorld (for the walkability grid and positional sounds)
var call_t := 0.0
var rng := RandomNumberGenerator.new()
var _placed := false

const CALLS := {"horse": "sfx/neigh", "cow": "sfx/moo"}


func setup(sheet: String, at: Vector2, rng_px := 220.0, paddock := Rect2(), w: Node = null) -> void:
	world = w
	home = at
	position = at
	range_px = rng_px
	bounds = paddock
	for k in ["dog", "horse", "cow"]:
		if sheet.contains(k):
			kind = k
	is_dog = kind == "dog"
	speed = {"cat": 55.0, "dog": 75.0, "horse": 34.0, "cow": 22.0}[kind]
	rng.seed = hash(sheet + str(at))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.char_frames("chars/" + sheet)
	sprite.offset = Vector2(0, -32)
	add_child(sprite)
	sprite.play("idle_" + ["s", "e", "w"][rng.randi() % 3] if kind in ["horse", "cow"] else "idle_s")
	sprite.frame = rng.randi() % 2
	if kind in ["horse", "cow"]:
		sprite.speed_scale = 0.35       # slow grazing: the head dips and the tail flicks unhurriedly
	wait_t = rng.randf_range(1.0, 6.0)
	call_t = rng.randf_range(20.0, 70.0)


func _nav() -> AnimalNav:
	if world != null and world.has_method("animal_nav"):
		return world.call("animal_nav")
	return null


func _process(delta: float) -> void:
	if Game.ui_blockers > 0:
		return
	step(delta)


## One tick of the wandering logic (also driven directly by the test suite).
func step(delta: float) -> void:
	if not _placed:
		var nav0 := _nav()
		if nav0 != null:
			_placed = true
			if not nav0.free_at(position):
				# spawned on a footprint (a tree grew there, a wall): step out onto free ground
				position = nav0.nearest_free(position)
				home = position
	_calls(delta)
	if moving:
		var d := target - position
		var stp := speed * delta
		var nxt := target if d.length() <= stp else position + d.normalized() * stp
		var nav := _nav()
		if nav != null and not nav.free_at(nxt):
			moving = false
			wait_t = rng.randf_range(1.0, 3.0)
			_play("idle_" + facing)
			return
		position = nxt
		_face(d)
		if position == target:
			moving = false
			wait_t = _idle_time()
			_play("idle_" + facing)
		else:
			_play("walk_" + facing)
		return
	wait_t -= delta
	if wait_t <= 0.0:
		if rng.randf() < 0.25:
			# just look somewhere else
			var looks: Array = ["e", "w", "e", "w", "s", "n"] if kind in ["horse", "cow"] else ["s", "e", "w", "n"]
			facing = looks[rng.randi() % looks.size()]
			_play("idle_" + facing)
			wait_t = rng.randf_range(2.0, 5.0)
			return
		var nav2 := _nav()
		if nav2 == null:
			var a := rng.randf() * TAU
			target = home + Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(40.0, range_px)
		else:
			target = nav2.sample_target(position, home, range_px, bounds, rng)
		if target.distance_to(position) < 4.0:
			wait_t = rng.randf_range(1.0, 3.0)
			return
		moving = true


func _idle_time() -> float:
	match kind:
		"dog":
			return rng.randf_range(2.5, 8.0)
		"horse":
			return rng.randf_range(6.0, 16.0)
		"cow":
			return rng.randf_range(9.0, 22.0)
	return rng.randf_range(4.0, 12.0)


## Occasional calls, positional (they fade with distance and are skipped when the player is far away).
func _calls(delta: float) -> void:
	if not CALLS.has(kind) or world == null:
		return
	call_t -= delta
	if call_t > 0.0:
		return
	call_t = rng.randf_range(35.0, 90.0)
	var pl: Node2D = world.get("player")
	if pl != null and pl.position.distance_to(position) < 1300.0 and is_inside_tree():
		Audio.play_at(CALLS[kind], position, world, -9.0)


func _face(d: Vector2) -> void:
	# livestock read best in profile: they turn side-on unless walking almost straight up or down
	var k := 0.35 if kind in ["horse", "cow"] else 1.0
	if absf(d.x) > absf(d.y) * k:
		facing = "e" if d.x > 0 else "w"
	else:
		facing = "s" if d.y > 0 else "n"


func _play(a: String) -> void:
	if sprite.animation != a and sprite.sprite_frames.has_animation(a):
		sprite.play(a)
