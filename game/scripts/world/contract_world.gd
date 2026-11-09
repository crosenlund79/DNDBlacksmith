## ContractWorld — the major contract made visible at the Project Bench (The Living Realm, milestone 5).
## EN: Beside an installed Project Bench stand the patron's sealed crate (while it still holds materials) and the
##     finished goods: one crate per quarter of the order, stacked as the hours go in, so production can be seen
##     from across the workshop. Apprentices working the order stand at the bench or its stations (ApprenticeActors).
##     Purely visual (no collision, no interaction of its own); it refreshes a few times a second from Contracts.
## DA: Kontrakten synligt ved projektbænken: mæcenens forseglede kasse og de færdige varer i en voksende stak.
class_name ContractWorld
extends Node2D

const SYNC := 0.5
const STACK := 4          # goods crates when the order is complete

var w: VillageWorld
var _t := 0.0
var _key := ""
var nodes: Array[Node2D] = []


func _ready() -> void:
	name = "ContractWorld"
	w = get_parent() as VillageWorld


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = SYNC
	sync()


## How many goods crates and whether the patron's crate shows, for the first contract in hand.
static func state_now() -> Dictionary:
	if Game.state.is_empty() or not Contracts.bench_installed() or Contracts.active().is_empty():
		return {"goods": 0, "patron": false}
	var c: Dictionary = Contracts.active()[0]
	var frac := float(c["units_done"]) / maxf(1.0, float(c["units_total"]))
	var g := int(ceil(frac * STACK - 0.001)) if int(c["units_done"]) > 0 else 0
	return {"goods": clampi(g, 0, STACK), "patron": not (c["crate"] as Dictionary).is_empty()}


func sync() -> void:
	if w == null or w.ysort == null:
		return
	var s := state_now()
	var key := "%d|%s|%s" % [int(s["goods"]), str(s["patron"]), str(Property.pos_of(Contracts.BENCH)) if Contracts.bench_installed() else ""]
	if key == _key:
		return
	_key = key
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	if not Contracts.bench_installed():
		return
	var tp := Property.pos_of(Contracts.BENCH)
	var pos := w.bpos("smithy", tp.x, tp.y)
	var side := -1.0 if Property.flipped(Contracts.BENCH) else 1.0
	if bool(s["patron"]):
		_crate("contracts/crate_patron", pos + Vector2(-side * 92.0, 22.0), 0)
	for i in int(s["goods"]):
		# two on the floor, then stacked on top of them
		var base := pos + Vector2(side * (88.0 + float(i % 2) * 18.0), 26.0 - float(i % 2) * 6.0)
		_crate("contracts/crate_goods", base, int(i / 2))


func _crate(tex: String, at: Vector2, level: int) -> void:
	var n := Node2D.new()
	n.position = at + Vector2(0, 20)
	var sp := Sprite2D.new()
	sp.texture = Assets.get_tex(tex)
	sp.scale = Vector2(0.72, 0.72)
	sp.offset = Vector2(0, -20 / 0.72 - level * 26.0)
	n.add_child(sp)
	w.ysort.add_child(n)
	nodes.append(n)


func _exit_tree() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
