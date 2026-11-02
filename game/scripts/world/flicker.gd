## Flicker — warm fire light that breathes and crackles.
## DA: Varmt ildlys, der ånder og knitrer.
extends PointLight2D

var base_energy := -1.0
var t := 0.0


func _process(delta: float) -> void:
	if base_energy < 0.0:
		base_energy = energy
	t += delta
	energy = base_energy * (0.86 + 0.08 * sin(t * 7.3) + 0.06 * sin(t * 13.1 + 1.7) + randf() * 0.04)
