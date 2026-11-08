## AnimalNav — where the village animals may walk (iteration 010).
## EN: A coarse grid (16 px cells) over the village marking every solid footprint (walls, props, trees, water,
##     fences) grown by the animal's radius, and every building rect grown by a margin, as blocked. Animals pick
##     wander targets with `sample_target` (inside their home range and optional paddock bounds, with a clear straight
##     line) and check each step with `free_at`, so they never walk through walls or into houses.
## DA: Et grovt gitter over landsbyen: dyr vælger kun mål, de kan gå lige hen til uden at gå gennem mure.
class_name AnimalNav
extends RefCounted

const CELL := 16.0

var origin := Vector2.ZERO
var gw := 0
var gh := 0
var blocked := PackedByteArray()
var houses: Array[Rect2] = []


## `solids`: Rect2 footprints (as passed to VillageWorld._solid); `building_rects`: house rects (animals stay outside).
static func create(solids: Array, building_rects: Array, map_px: Vector2, radius := 10.0, house_margin := 26.0) -> AnimalNav:
	var n := AnimalNav.new()
	n.origin = Vector2(-64, -64)
	n.gw = int(ceil((map_px.x + 128.0) / CELL))
	n.gh = int(ceil((map_px.y + 128.0) / CELL))
	n.blocked.resize(n.gw * n.gh)
	n.blocked.fill(0)
	for r in solids:
		n._mark((r as Rect2).grow(radius))
	for r in building_rects:
		n.houses.append((r as Rect2).grow(house_margin))
		n._mark((r as Rect2).grow(house_margin))
	# the map border itself
	n._mark(Rect2(-64, -64, map_px.x + 128, 64 + radius))
	n._mark(Rect2(-64, map_px.y - radius, map_px.x + 128, 64 + radius))
	n._mark(Rect2(-64, -64, 64 + radius, map_px.y + 128))
	n._mark(Rect2(map_px.x - radius, -64, 64 + radius, map_px.y + 128))
	return n


func _mark(r: Rect2) -> void:
	var a := Vector2i(floori((r.position.x - origin.x) / CELL), floori((r.position.y - origin.y) / CELL))
	var b := Vector2i(floori((r.end.x - origin.x) / CELL), floori((r.end.y - origin.y) / CELL))
	for y in range(maxi(a.y, 0), mini(b.y, gh - 1) + 1):
		for x in range(maxi(a.x, 0), mini(b.x, gw - 1) + 1):
			blocked[y * gw + x] = 1


func free_at(p: Vector2) -> bool:
	var x := floori((p.x - origin.x) / CELL)
	var y := floori((p.y - origin.y) / CELL)
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return false
	return blocked[y * gw + x] == 0


func in_house(p: Vector2) -> bool:
	for r in houses:
		if r.has_point(p):
			return true
	return false


func segment_clear(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, int(a.distance_to(b) / 8.0))
	for i in n + 1:
		if not free_at(a.lerp(b, float(i) / n)):
			return false
	return true


## A reachable wander target: within `range_px` of `home` (elliptical, flatter north-south), inside `bounds` when
## given, on free ground with a clear straight line from `from`. Returns `from` when nothing suitable is found.
func sample_target(from: Vector2, home: Vector2, range_px: float, bounds: Rect2, rng: RandomNumberGenerator, tries := 12) -> Vector2:
	for i in tries:
		var a := rng.randf() * TAU
		var p := home + Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(32.0, range_px)
		if bounds.size != Vector2.ZERO:
			p = p.clamp(bounds.position, bounds.end)
		if p.distance_to(from) < 24.0:
			continue
		if free_at(p) and segment_clear(from, p):
			return p
	return from


## The nearest free point to `p` (spiral search), or `p` itself if none within `max_r`.
func nearest_free(p: Vector2, max_r := 320.0) -> Vector2:
	if free_at(p):
		return p
	var r := CELL
	while r <= max_r:
		for k in 16:
			var q := p + Vector2(cos(TAU * k / 16.0), sin(TAU * k / 16.0)) * r
			if free_at(q):
				return q
		r += CELL
	return p
