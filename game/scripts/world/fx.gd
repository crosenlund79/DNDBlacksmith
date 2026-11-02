## FX — small helpers for lights and particles (Godot 2D, Compatibility-renderer friendly).
## EN: Radial light textures, flickering fire lights, embers, smoke and magical motes.
## DA: Radiale lysteksturer, flakkende ildlys, gløder, røg og magiske gnister.
class_name FX
extends RefCounted

static var _light_tex: Texture2D


static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex


static func light(color: Color, radius: float, energy := 1.0, flicker := false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 128.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	if flicker:
		l.set_script(load("res://scripts/world/flicker.gd"))
	return l


static func embers(amount := 18) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 1.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 18.0
	p.direction = Vector2(0.3, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color("#ffd27a"))
	g.set_color(1, Color(0.9, 0.3, 0.05, 0.0))
	p.color_ramp = g
	return p


static func smoke(amount := 10) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 4.0
	p.direction = Vector2(0.6, -1)
	p.spread = 12.0
	p.gravity = Vector2(6, -8)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 10.0
	p.scale_amount_max = 22.0
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.3, 0.27, 0.35))
	g.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
	p.color_ramp = g
	return p


static func motes(color: Color, amount := 12, radius := 40.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.9))
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	return p


static func sparks() -> CPUParticles2D:
	var p := embers(26)
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 120)
	p.lifetime = 0.8
	return p
