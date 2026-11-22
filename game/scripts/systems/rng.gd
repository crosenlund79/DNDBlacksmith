## Rng — named, seeded random streams for the simulation (R3 "One History"; LORE-012 as the means for TECH-029,
## LORE-010 and CIV-003).
## EN: Before R3 every system drew from Godot's one global generator, whose state is never saved: a loaded game
##     continued with different luck than the same game left running, and crafting a sword changed what the next
##     expedition met. Now each part of the simulation draws from its own stream:
##       "world"        village life, people, hirelings, apprentices, companies, social events (the default);
##       "expeditions"  parties, fights, loot, the sites, hireling trips and scouting;
##       "commerce"     customers, merchants, prices, trade, the docks, contracts and sponsorship;
##       "crafting"     the smith's and the workshop's dice and rolls.
##     Each stream is seeded from the campaign's world seed and its name, so the same seed gives the same campaign
##     (until the player chooses differently), and a stream's state is saved with the game (as a string: JSON cannot
##     hold a 64-bit integer exactly), so save → load → continue reproduces the uninterrupted run bit for bit.
##     Purely visual randomness (particles, idle animations in scripts/world and scripts/ui) stays on the global
##     generator: it changes nothing that is remembered.
##     State: Game.state["rng"] = {"seed": world_seed the streams were made from, "<stream>": "<state>"}.
## DA: Navngivne, seedede tilfældighedsstrømme pr. delsystem; deres tilstand gemmes med spillet.
class_name Rng
extends RefCounted

const STREAMS := ["world", "expeditions", "commerce", "crafting"]

static var _gens := {}
static var _for: Dictionary = {}


static func _seed_now() -> int:
	return int(Game.state.get("world_seed", 0))


## The generator for a stream, (re)built when the game state changed (new game, load) or the world seed did.
static func gen(stream: String) -> RandomNumberGenerator:
	if not is_same(_for, Game.state):
		_gens = {}
		_for = Game.state
	var st: Dictionary = Game.state.get("rng", {}) if Game.state.get("rng") is Dictionary else {}
	var ws := _seed_now()
	if not st.is_empty() and int(st.get("seed", ws)) != ws and not Game.state.is_empty():
		# the world seed was (re)made after the streams started (a new game sets it while generating the roster)
		st = {}
		Game.state["rng"] = st
		_gens = {}
	var g: RandomNumberGenerator = _gens.get(stream)
	if g == null:
		g = RandomNumberGenerator.new()
		g.seed = absi(hash("%d|rng|%s" % [ws, stream]))
		if st.has(stream):
			g.state = int(str(st[stream]))
		elif not Game.state.is_empty():
			if not Game.state.get("rng") is Dictionary:
				Game.state["rng"] = {"seed": ws}
			Game.state["rng"]["seed"] = ws
		_gens[stream] = g
	return g


## Writes every live stream's state into the game state (Game.to_save calls it).
static func persist() -> void:
	if not is_same(_for, Game.state) or Game.state.is_empty():
		return
	var st: Dictionary = Game.state.get("rng", {}) if Game.state.get("rng") is Dictionary else {}
	st["seed"] = _seed_now()
	for k in _gens:
		st[k] = str((_gens[k] as RandomNumberGenerator).state)
	Game.state["rng"] = st


## Tests and developer tools: restart every stream from a seed of choice (also seeds the global generator).
static func reseed(n: int) -> void:
	seed(n)
	_gens = {}
	_for = Game.state
	var st := {"seed": _seed_now()}
	for s in STREAMS:
		var g := RandomNumberGenerator.new()
		g.seed = absi(hash("%d|reseed|%s" % [n, s]))
		_gens[s] = g
		st[s] = str(g.state)
	if not Game.state.is_empty():
		Game.state["rng"] = st


## After every draw the stream's state is written back into the game state, so the state is always exactly what a
## save would hold (saving never changes it).
static func _keep(stream: String, g: RandomNumberGenerator) -> void:
	if Game.state.is_empty():
		return
	var st: Variant = Game.state.get("rng")
	if not st is Dictionary:
		st = {"seed": _seed_now()}
		Game.state["rng"] = st
	st[stream] = str(g.state)


static func f(stream: String) -> float:
	var g := gen(stream)
	var v := g.randf()
	_keep(stream, g)
	return v


static func i(stream: String) -> int:
	var g := gen(stream)
	var v := g.randi()
	_keep(stream, g)
	return v


static func ri(stream: String, lo: int, hi: int) -> int:
	var g := gen(stream)
	var v := g.randi_range(lo, hi)
	_keep(stream, g)
	return v


static func rf(stream: String, lo: float, hi: float) -> float:
	var g := gen(stream)
	var v := g.randf_range(lo, hi)
	_keep(stream, g)
	return v


static func fn(stream: String, mean := 0.0, dev := 1.0) -> float:
	var g := gen(stream)
	var v := g.randfn(mean, dev)
	_keep(stream, g)
	return v


static func pick(stream: String, arr: Array) -> Variant:
	if arr.is_empty():
		return null
	var g := gen(stream)
	var v: Variant = arr[g.randi() % arr.size()]
	_keep(stream, g)
	return v


## Shuffles in place (Fisher–Yates on the stream).
static func shuffle(stream: String, arr: Array) -> void:
	var g := gen(stream)
	for k in range(arr.size() - 1, 0, -1):
		var j := g.randi() % (k + 1)
		var tmp: Variant = arr[k]
		arr[k] = arr[j]
		arr[j] = tmp
	_keep(stream, g)
