## Player — Brannoc Ironhand: responsive top-down movement with directional animation.
## DA: Brannoc Ironhand: responsiv bevægelse set fra oven med retningsbestemt animation.
class_name PlayerBody
extends CharacterBody2D

const WALK := 230.0
const RUN := 340.0

var sprite: AnimatedSprite2D
var facing := "s"
var frozen := false
var _step_t := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20.0
	col.shape = c
	col.position = Vector2(0, -6)
	add_child(col)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.char_frames("chars/player")
	sprite.offset = Vector2(0, -32)
	sprite.scale = Vector2(1.1, 1.1)
	sprite.play("idle_s")
	add_child(sprite)
	Events.appearance_changed.connect(refresh_look)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if frozen or Game.ui_blockers > 0 or Game.ui_open > 0:
		velocity = Vector2.ZERO
		_anim(Vector2.ZERO)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := RUN if Input.is_action_pressed("run") else WALK
	velocity = dir * spd * Vitality.move_factor()
	move_and_slide()
	_anim(dir)
	if dir != Vector2.ZERO:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.34 if spd == WALK else 0.26
			Audio.play("sfx/footstep_%d" % randi_range(1, 2), -18.0, randf_range(0.9, 1.1))


func _anim(dir: Vector2) -> void:
	if dir.length() > 0.1:
		if absf(dir.x) > absf(dir.y):
			facing = "e" if dir.x > 0 else "w"
		else:
			facing = "s" if dir.y > 0 else "n"
		sprite.speed_scale = 1.35 if Input.is_action_pressed("run") else 1.0
		_play("walk_" + facing)
	else:
		sprite.speed_scale = 1.0
		_play("idle_" + facing)


func _play(a: String) -> void:
	if sprite.animation != a:
		sprite.play(a)


## Re-slice the sheet after the appearance changed (keeps the current animation).
func refresh_look() -> void:
	var a := sprite.animation
	sprite.sprite_frames = Assets.char_frames("chars/player")
	sprite.play(a)


func facing_vector() -> Vector2:
	return {"s": Vector2.DOWN, "n": Vector2.UP, "e": Vector2.RIGHT, "w": Vector2.LEFT}[facing]
