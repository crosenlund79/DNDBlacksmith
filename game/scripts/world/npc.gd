## NPC — a villager, adventurer, hireling or companion walking the waypoint graph.
## EN: The world assigns a target spot from the schedule; the NPC paths there with AStar2D,
##     animates by direction, idles with small fidgets and occasionally speaks a short bark.
## DA: Verdenen giver et mål ud fra skemaet; personen finder vej med AStar2D, animeres efter
##     retning, står og pusler, og siger af og til en kort replik.
class_name NPCActor
extends Node2D

signal arrived(npc_id: String)

var npc_id := ""
var display_name := ""
var sprite: AnimatedSprite2D
var label: Label
var bubble: Label
var path: PackedVector2Array = []
var speed := 80.0
var facing := "s"
var target_spot := ""
var idle_t := 0.0
var bubble_t := 0.0
var hidden_after_arrival := false


func setup(id: String, sprite_id: String, name: String) -> void:
	npc_id = id
	display_name = name
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.char_frames(sprite_id)
	sprite.offset = Vector2(0, -32)
	sprite.scale = Vector2(1.15, 1.15)
	sprite.play("idle_s")
	sprite.frame = randi() % 2
	add_child(sprite)
	label = Label.new()
	label.text = name
	label.add_theme_font_override("font", Assets.font("heading"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#efe4cc"))
	label.add_theme_color_override("font_outline_color", Color("#20140c"))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-80, -126)
	label.size = Vector2(160, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	add_child(label)
	bubble = Label.new()
	bubble.add_theme_font_override("font", Assets.font("body_italic"))
	bubble.add_theme_font_size_override("font_size", 18)
	bubble.add_theme_color_override("font_color", Color("#20140c"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe2c0")
	sb.border_color = Color("#20140c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	bubble.add_theme_stylebox_override("normal", sb)
	bubble.position = Vector2(-110, -164)
	bubble.custom_minimum_size = Vector2(220, 0)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.visible = false
	add_child(bubble)
	speed = randf_range(70.0, 92.0)


func go(points: PackedVector2Array) -> void:
	path = points
	if path.size() > 0 and path[0].distance_to(position) < 8.0:
		path.remove_at(0)


func say(text: String, seconds := 3.5) -> void:
	bubble.text = text
	bubble.visible = true
	bubble_t = seconds


func _process(delta: float) -> void:
	if bubble_t > 0.0:
		bubble_t -= delta
		if bubble_t <= 0.0:
			bubble.visible = false
	if path.size() > 0 and Game.ui_blockers == 0:
		var tgt := path[0]
		var d := tgt - position
		var step := speed * delta * (Game.MINUTES_PER_SECOND / 1.6)
		if d.length() <= step:
			position = tgt
			path.remove_at(0)
			if path.is_empty():
				arrived.emit(npc_id)
		else:
			position += d.normalized() * step
		_face(d)
		_play("walk_" + facing)
	else:
		idle_t -= delta
		if idle_t <= 0.0:
			idle_t = randf_range(2.0, 6.0)
			if randf() < 0.35:
				facing = ["s", "e", "w", "n"].pick_random()
		_play("idle_" + facing)


func _face(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		facing = "e" if d.x > 0 else "w"
	else:
		facing = "s" if d.y > 0 else "n"


func _play(a: String) -> void:
	if sprite.animation != a and sprite.sprite_frames.has_animation(a):
		sprite.play(a)


func show_name(on: bool) -> void:
	label.visible = on
