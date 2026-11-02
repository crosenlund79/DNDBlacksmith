## Animal — a village cat or dog: a small tabletop token that idles (sits, looks about) and now
## and then trots to a nearby spot within its home range. No care mechanics.
## DA: En landsbykat eller -hund: sidder, kigger rundt og lunter af og til et kort stykke.
class_name AnimalActor
extends Node2D

var sprite: AnimatedSprite2D
var home := Vector2.ZERO
var range_px := 220.0
var target := Vector2.ZERO
var moving := false
var wait_t := 0.0
var speed := 60.0
var facing := "s"
var is_dog := false


func setup(sheet: String, at: Vector2, rng_px := 220.0) -> void:
	home = at
	position = at
	range_px = rng_px
	is_dog = sheet.contains("dog")
	speed = 75.0 if is_dog else 55.0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.char_frames("chars/" + sheet)
	sprite.offset = Vector2(0, -32)
	sprite.scale = Vector2(1.0, 1.0)
	sprite.play("idle_s")
	sprite.frame = randi() % 2
	add_child(sprite)
	wait_t = randf_range(1.0, 6.0)


func _process(delta: float) -> void:
	if Game.ui_blockers > 0:
		return
	if moving:
		var d := target - position
		var step := speed * delta
		if d.length() <= step:
			position = target
			moving = false
			wait_t = randf_range(4.0, 12.0) if not is_dog else randf_range(2.5, 8.0)
			_play("idle_" + facing)
		else:
			position += d.normalized() * step
			_face(d)
			_play("walk_" + facing)
		return
	wait_t -= delta
	if wait_t <= 0.0:
		if randf() < 0.25:
			# just look somewhere else
			facing = ["s", "e", "w", "n"].pick_random()
			_play("idle_" + facing)
			wait_t = randf_range(2.0, 5.0)
			return
		var a := randf() * TAU
		target = home + Vector2(cos(a), sin(a) * 0.6) * randf_range(40.0, range_px)
		moving = true


func _face(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		facing = "e" if d.x > 0 else "w"
	else:
		facing = "s" if d.y > 0 else "n"


func _play(a: String) -> void:
	if sprite.animation != a and sprite.sprite_frames.has_animation(a):
		sprite.play(a)
