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
var nav: PlayerNav          # point-and-click walking and quick travel (created with the body)


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
	_attach_nav.call_deferred()


func _attach_nav() -> void:
	var w := get_parent()
	while w != null and not (w is VillageWorld):
		w = w.get_parent()
	if w == null or PlayerNav.of(w) != null:
		return
	var n := PlayerNav.new()
	n.name = "PlayerNav"
	w.add_child(n)
	n.setup(w as VillageWorld, self)


func _physics_process(delta: float) -> void:
	# Steward Mode: while the steward runs the forge the smith is away — his miniature fades out and stays put
	var away := Steward.smith_away()
	sprite.modulate.a = move_toward(sprite.modulate.a, 0.0 if away else 1.0, delta * 2.0)
	if frozen or away or Game.ui_blockers > 0 or Game.ui_open > 0:
		velocity = Vector2.ZERO
		_anim(Vector2.ZERO)
		if nav and nav.traveling():
			nav.stop_travel()        # something opened on the way: stop where we are
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := RUN if Input.is_action_pressed("run") else WALK
	if nav and nav.active():
		if dir != Vector2.ZERO:
			nav.stop_travel()
			nav.cancel()             # the keyboard always wins over a click
		elif nav.traveling():
			var tdir := nav.travel_step(delta)
			velocity = Vector2.ZERO
			sprite.speed_scale = 2.2
			_anim_dir(tdir)
			_footstep(delta, 0.12)
			return
		else:
			dir = nav.steer(delta)
	velocity = dir * spd * Vitality.move_factor()
	move_and_slide()
	_anim(dir)
	if dir != Vector2.ZERO:
		_footstep(delta, 0.34 if spd == WALK else 0.26)


func _footstep(delta: float, every: float) -> void:
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = every
		Audio.play("sfx/footstep_%d" % randi_range(1, 2), -18.0, randf_range(0.9, 1.1))


## Walk animation in a direction without touching the run-speed scale (quick travel).
func _anim_dir(dir: Vector2) -> void:
	if dir.length() > 0.1:
		if absf(dir.x) > absf(dir.y):
			facing = "e" if dir.x > 0 else "w"
		else:
			facing = "s" if dir.y > 0 else "n"
		_play("walk_" + facing)
	else:
		_play("idle_" + facing)


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
