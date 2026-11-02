# Ember & Ash — technical overview

## Architecture

```
scenes/main.tscn → scripts/main.gd    state machine: MainMenu ⇄ (VillageWorld + UIRoot)
scripts/autoload/                     singletons (project.godot [autoload])
  log.gd       levelled logging, ring buffer, user://logs/ember_ash.log
  events.gd    global signal bus
  settings.gd  user://settings.cfg, runtime InputMap (rebindable), display options
  assets.gd    sprite/font template + override system, SpriteFrames from sheets, shared Theme
  audio.gd     buses (Music/SFX/Ambience/UI), sound override system, music crossfade, ambience layers
  db.gd        read-only JSON data from res://data
  game.gd      authoritative serialisable world state + in-game clock
  saves.gd     versioned save slots with migration and backups
scripts/systems/   pure game logic (static, RefCounted), operating on Game.state
  items, skills, dice, crafting, loot, social, hirelings, adventurers, shop, sim, talk, objectives
scripts/world/     the playable village (world.gd), player, NPCs, lights and particles
scripts/ui/        UIRoot (HUD, toasts, tooltip, fades, panel routing), widgets, panels/*
data/              items, stations, characters, destinations, loot tables, upgrades, skills,
                   props, dialogue, names                    (tools/data/make_data.py)
                   recipes + crafting balance                (tools/data/make_recipes.py)
                   layout: rooms, doors, furniture, spots    (tools/data/make_layout.py)
assets/            sprites/, audio/, fonts/   (art from tools/art, audio from tools/audio)
tests/             test_runner.tscn — automated tests (headless); playtest.tscn — rendered
                   play-test driver with synthetic input and screenshots; compile_all.tscn
tools/             data, art, audio generators and a GDScript lint (tools/lint/check_gd.py)
```

**Design rules**

- **State lives in `Game.state`.** It holds only Dictionaries, Arrays and scalars, so it serialises straight to JSON.
- **Logic is separate from presentation.** Systems mutate the state; the world and UI only visualise it and react through `Events` signals.
- **The world never drives the simulation.** `Sim.on_hour`/`on_day` run from the clock wherever the player is, so the village keeps living.

## Clock

- `Game.MINUTES_PER_SECOND = 1.6`, so one day lasts about 15 real minutes. Settings can scale this ×0.5 or ×2.
- Modal UI windows pause the clock through `Game.block_time()`.
- Sleeping fast-forwards to 06:00 and simulates every hour on the way.

## Saves

- Slots `slot_1..3`, `autosave` (written on sleep) and `quicksave` (F5), stored at `user://saves/<slot>.json` as `{meta, data}`.
- Writes are atomic: temp file, then rename. The previous file is kept as `<slot>.bak` and used automatically if the main file is unreadable.
- `data.version` is migrated step by step in `Saves.migrate()`.
- JSON turns integers into floats; `Saves._restore_ints()` converts integral values back, except keys listed in `FLOAT_KEYS`.

## Template / override system

- **Sprites:** `Assets.get_tex("stations/forge")` looks for `user://overrides/sprites/<id>.png`, then `res://assets/sprites/<id>.png`. If neither exists it uses a generated parchment placeholder, logs the missing id once, and counts it in the F3 overlay. The whole game runs with zero art.
- **Audio:** `Audio.play("sfx/hammer_1")` looks for `user://overrides/audio/<id>.(ogg|wav)`, then `res://assets/audio/...`. Missing sounds are skipped silently.
- **Raw files:** both systems also load files that have not been imported (raw PNG through `Image.load_from_file`, a minimal WAV reader, `FontFile.load_dynamic_font`). This makes a first run from the command line robust.
- **Character sheets:** 768×512 px, 6 columns × 4 rows of 128 px. Rows are S, E, N, W; columns 0–1 are idle, 2–5 are walk.

## Rendering

- Straight top-down, GL Compatibility renderer, canvas_items stretch with `expand` aspect, so widescreen and ultrawide screens see more of the world.
- **Ground:** a repeating grass texture. Roads are textured `Line2D` with ink edges; the square is a textured `Polygon2D`.
- Actors and props share a Y-sorted layer.
- **Lighting:** a `CanvasModulate` day/night grade, `PointLight2D` fire lights with flicker, door and window and lantern lights that switch on at dusk, and `CPUParticles2D` for embers, smoke, bubbles and arcane motes.

## Multi-room interiors (data-driven)

`tools/data/make_layout.py` writes the interior plan of every building into `data/layout.json`:

| Key | Meaning |
|---|---|
| `rooms` | `[{id, name, rect, floor, tint, wall}]`, rect in tiles relative to the building |
| `room_doors` | `[{between: [a, b], at, w}]`, a doorway in the wall the two rooms share |
| `furniture` | `[[prop, x, y, rotDeg]]`, placed from the shared prop library (`data/props.json`) |
| `spots`, `interact`, `tables` | NPC destinations, interactables (bed, ledger, counter) and inn tables |
| `station_pos` | the smithy's crafting stations, grouped by discipline room |
| `customer_rooms` | rooms that customers may enter (the shop only) |

**How `world.gd` builds a building:**

- **Floors and roof:** one floor texture per room (tinted). The roof hides the whole building while the player is inside.
- **Walls:** interior walls are derived automatically from the edges that rooms share. Doorway gaps are cut where `room_doors` says. Outer walls keep their exterior door.
- **Room name:** `room_at(building, pos)` names the current room; the HUD banner shows it on entry.
- **Navigation:** every room gets a hub node, each doorway a pair of nodes, and each exterior door an outside/inside pair joined to the outdoor network. NPC paths therefore run room to room through doorways.
- **The inn's upper floor** is a separate graph island reached by the stairs. The stairs are a floor change: the player and NPCs are moved there, they do not walk.

Adding a room is a data change: add a rect and a door to `make_layout.py`, then re-run it.

## Skill-check minigames (`scripts/ui/minigames/`)

- `Minigames.create(args)` picks the check for a station from `crafting.json` → `minigames`. Without an entry it returns the original `SkillCheckPanel` ring.
- **Shared contract:** every check takes `args {station, count, speed, zone, title, subtitle, on_done}` and calls `on_done(qualities)` with one value per round.
- **Skill:** it arrives as `zone` and `speed` from `Crafting.check_params()`. `MinigameBase` turns them into `ease` and `pace`:

  | Minigame | ease scales | pace scales |
  |---|---|---|
  | Align | alignment window | airflow drift |
  | Edge | sweet-spot size | wander amplitude |
  | Multi-hit | section width | sweep speed |
  | Rune | binding tolerance | swirl and surges |
  | Rings | contact window | ring speed |

- Continuous precision goes through `Crafting.check_quality`, so all checks share one quality curve. The exception is multi-hit, which scores by hit count.
- Every round emits `Events.station_worked`, so the world shows sparks, steam and similar effects at the station.
- Frame time is clamped to 50 ms, so a hitch can never jump a needle or rune past its target.

## Hirelings (`hirelings.gd`)

- **Traits** (`Hire.TRAITS`) scale per-skill output (`mult`), experience (`xp`), expedition danger and injury, and haul quality.
- **`Hire.odds(h, dest)`** gives the success, injury and death probabilities. The ledger shows them before sending, and `_resolve` uses the same numbers.
- **New hireling fields,** added to older saves on first access:
  - `traits`
  - `activity`
  - `log` (last 6 results)
  - `history` (last 8 expeditions)
- **`Hire.replace()`** dismisses an employee and hires an applicant in one step. `Hire.equip()` moves gear from the stores to an employee.

## Customers

- `Shop.customer_hour` sends a customer only when one of `Shop.SEATS` (4) seats is free. The customer gets a `seat` index and `present = false`.
- `spot_for()` routes them to `wait_seat_<n>`. When the figure arrives, `Shop.mark_arrived()` sets `present`, rings the bell and posts the single notification.
- The patience timer runs from `seated`.
- `Shop.dismiss_customer()` frees the seat.
- `Shop.waiting()` lists only the seated customers; the shop panel and dialogue use it.

## Figures, animals and atmosphere

- **Character sheets:** `tools/art/make_minis.py` + `miniature.py` write them in the existing 6×4 layout:
  - rows: front, side, back, mirrored side
  - columns: 2 idle, 4 walk
  - base fixed in every cell
- **Loader:** unchanged. The sprite offset is now (0, −32), which puts the base on the actor's feet.
- **Animals:** `AnimalActor` (`scripts/world/animal.gd`) uses the same sheet format.
- **Breeze:** `shaders/sway.gdshader` is a shared material. Its phase comes from world position, and its strength depends on the plant kind (`world.gd` `SWAY`).
- **Dust:** CPUParticles2D emitters over the streets and the workshop and inn rooms.
- **Forge corner:** a radial soot gradient over the forge room's floor, a warm hearth light, smoke and embers.

## Vertical-slice systems (iterations 003–008)

**New and extended systems:**

| Module | What it holds |
|---|---|
| `regions.gd` (`Regions`) | Scouting knowledge per destination (`world.scouted`), danger after scouting, supplier discovery (`suppliers.json`), trade runs, relic identification, reading recipe scrolls |
| `adventurers.gd` | `run_encounters()`: threats from `destinations.json` (power, dmg, weak, resist). Offence = level + attack (+magic for casters) + 3 × matching damage type; defence reduces damage proportionally; draughts heal; coatings wear off after 3 trips. `plan_next()` sets the next trip and the damage type it calls for. |
| `shop.gd` | Reputation (average village affection × 0.8 + `world.rep`), upkeep, goods customers, disputes, repairs of adventurers' own gear, refusals |
| `inn.gd` (`InnLife`) | Table talk from real state; knucklebones on `Dice`; romance beats (walk, keepsake, wedding, married lines) |
| `crafting.gd` | `treat()` applies coatings and oils. Arcane recipes add `bound` magic (spellweave die). Hirelings on shift add `hireling_assist()` to the skill bonus. `requires_flag` gates forgotten recipes. |

**Developer and soak tools:**
- `dev_panel.gd`: the F10 developer tools; the action is `dev_panel`.
- `tests/soak.tscn`: 28 simulated days, with a printed summary.

**Save compatibility:** every new field is added on first access, so older saves still load:
- adventurers: trait, potions, log, history
- hirelings: traits, log, history
- `world.scouted` and `world.rep`

## NPCs

- `AStar2D` waypoint graph: densified road polylines, outdoor spots, room hubs, doorway pairs and interior spots (see above).
- `world.spot_for(id)` is the schedule. It covers customers, hirelings by work allocation, adventurers by status and hour, villagers by routine, and the companions.
- Departures walk to the village exit for the destination; returns walk in from it.

## Crafting (`crafting.gd`, data in `recipes.json` + `crafting.json`)

**A recipe** is a list of operations, each `{station, op, checks, weight}`, plus:

- `material`, `difficulty`, `category`, `requires` (skill levels), `inputs` and `output`
- `dice`: attribute → expression

`steps` (the station list) is kept for compatibility. A station may appear more than once (heat → hammer → re-heat).

**Difficulty against skill:**

- Effective difficulty = recipe difficulty + material difficulty.
- The gap between that and the relevant skill scales the zone width (±6% per level, clamped) and the needle speed (±5% per level).
- Skill also adds +1.4° of zone per level and slows the needle by 1.5% per level.
- Workshop upgrades (Runewright's Tools, Alchemist's Kit) add zone width at their discipline.
- None of this ever stops the needle for the player.

**Check quality** is continuous: `120 − 50 × (offset / half-zone)^1.3` inside the zone (centre 120%, edge 70%). Outside the zone it falls from 65% to 10%. Frame time is clamped, so a hitch cannot skip the needle past the zone.

**Operation quality** is the mean of its checks.

**Final craftsmanship** = weighted mean of all checks + 0.4% per skill level, clamped to 1–130%.

**Stats** = lerp(min, max, q × 0.85) × material factor × main die (0.85–1.15) × (1 + 1% per skill level):

- Durability uses the material's durability factor and the temper die.
- Magic uses the spellweave die.
- Potions and runestones use the potency or resonance die (0.8–1.2).

**Rarity** (all values in `crafting.json`):

- score = quality × 0.75 + fortune × 0.35 + material bonus + 8 per runestone input
- A masterwork (quality ≥ 115) adds a further 26.
- Thresholds: magic 68, rare 88, legendary 112.
- So a masterwork reaches legendary even with a fortune of 1. Sloppy work cannot reach it even with 100.
- Equipment gets affixes and a legendary name. Potions and runestones get Fine, Exquisite or Flawless and a stronger effect.

**Experience:** recipe XP × (0.6 + q/200). It drops to 40% when the smith's level exceeds the difficulty by 5 or more (routine work for an expert).

**The record:** `item["craft"]` stores:

- the recipe and material
- the operations with every check
- base quality and skill bonus
- each die (expression, faces, total) and the mode
- the rarity score and its parts
- XP and day

It is saved with the item, and the results panel can be reopened from the stores.

## Tests

- `tests/test_runner.tscn` covers dice, quality and rarity, skills, recipe/operation data integrity, beginner-vs-expert difficulty, masterwork legendaries with poor rolls, material stat differences, physical dice records, runestones, hireling allocation and expeditions (including the guaranteed legendary in Borin's first bag), adventurer expeditions and sales, social ripple to relatives, loot containers, and save/load round-trips.
- `tests/playtest.tscn -- <phase>` drives the real game with synthetic input and saves screenshots to `user://playtest/`. The phases are:

  | Phase | What it covers |
  |---|---|
  | `smoke` | Starts the game |
  | `full` | A full play-through |
  | `reload` | Restart and load |
  | `stations` | All 26 stations open |
  | `interiors` | Every room and its detection |
  | `nav` | Every spot is reachable |
  | `craft` | The 10 crafting demonstrations |
  | `craft_reload` | Crafted items survive restart and the record reopens |
  | `minigames` | Each specialised check played well and badly |
  | `iter2` | Figures, waiting area, animals, atmosphere, recruitment, the ledger, expeditions and risk, crafts through minigames |
  | `iter2_reload` | Hireling states and histories persist |

- `tools/lint/check_gd.py` runs gdtoolkit syntax checks plus heuristics for Godot 4 type-inference errors. It works without the engine.

## Adding content

- Edit `tools/data/make_data.py` (stations, items, characters, props) and run it. It also writes the recipes from `make_recipes.py`.
- To change recipes, operations, materials, dice or rarity, edit `tools/data/make_recipes.py`.
- To change rooms, doors and furniture, edit `tools/data/make_layout.py`.
- Art scripts live in `tools/art/` and audio in `tools/audio/`. All are deterministic and rebuild single assets with `--only=`.
