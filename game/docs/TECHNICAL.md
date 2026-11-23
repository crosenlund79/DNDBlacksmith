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
- `data.version` is migrated step by step by `SaveMigrations` (`save_migrations.gd`, one step per schema change; the
  current schema is `Game.SAVE_VERSION`). Schema 4 (Run 0.1) adds `uniques`, the campaign's Unique-artifact registry
  (`uniques.gd`): each Unique definition is minted once per campaign (decision D13); saves from before it register the
  lowest-uid piece as authentic and keep any other pieces whole as recorded legacy copies.
- Schemas 5–8 (the Living Workshop and v1.7): worker professions (5), workshop knowledge (6), station instances and
  staged work orders (7), the compact smithy layout (8). **Schema 9 (R1)** adds permanent item **tombstones**
  (`ItemRegistry.tombstone / tombstone_of / tombstones`, `Game.state.item_registry.tombstones`): a lost, buried or
  destroyed piece keeps uid, def, name, maker, mark, owners, origin, earned names and Epic and its Lore event ids, and a
  lost piece found again is marked `recovered`. Step 9 reconstructs tombstones from old saves' `lost`/`destroyed` Lore
  events and marks pieces identified from relics before R1 (`identified.legacy`).
- **Schema 10 (R2)** moves the single `world.rep` (what the village had heard of the smith) into
  `Game.state.reputation.word[audience][place]` (`reputation.gd`): every audience in the village gets the old value, the
  region nothing. Idempotent; the general standing is unchanged.
- **R2 "Truthful World Model" interfaces** (pure reads unless stated):
  - `Danger` (`danger.gd`) — the one danger model. `site(rid)` is the live strength of a place (the strongest group of
    foes actually there, `WorldSites.enemies_at`), `ratio(rid, strength)` at the campaign difficulty, `word(rid)`,
    `threats(rid)` (the foes really there, with weaknesses), `knowledge(rid)` (scouting 0..1),
    `ambush_dc(rid, boss)` (12, +2 at a lair, −up to 3 for well-charted ground) and `trip(dest)` (a hireling's trip
    danger on destinations.json's scale, moved by the place's live strength and lowered by scouting). Parties, fights,
    consultations, sponsorship, hirelings, the map and the sheets all ask here; `Regions.danger` and
    `WorldSites.danger` delegate.
  - `Reputation` (`reputation.gd`) — audiences (villagers, adventurers, traders, artisans, nobility and `civ:<id>`) ×
    places (village, region, `civ:<id>`; decision D-7 — civilizations are not created yet). `standing()` (the old
    `Shop.reputation`), `standing_of(aud, place)`, `word(aud, place)`, `change(delta, why)` (every audience in the
    village; spreading is R8), `word_text()`.
  - `Valuation` (`valuation.gd`) — item worth (`value`, `unit_value`, `catalogue`), the two difficulty factors
    (`smith_buys_factor`, `buyers_factor`), `merchant_price(def, mult)`, `counter_price(def)` and
    `material_cost` / `design_material_cost` (the village counter's price, else the catalogue value — one rule for the
    steward, its working smith and the Workshop Ledger).
  - `Adv.current_plan(a)` — where an adventurer really means to go: a forming party's committed destination (marked when
    it is the smith's sponsorship), else what the expedition planner would choose for their company today
    (`Expeditions.choose_destination(members, true)`, no dice, no side effects — the adventurer's own wish, `next_dest`,
    is one of the things it weighs). Dossier, dialogue and consultations read it; a consultation cannot redirect a
    sponsored party.
  - `Sim.gift_of(npc, …)` — gifts come from what the giver really has: an adventurer's carried loot or purse (the purse
    is paid on the ledger), a shopkeeper's own shelf (stock decremented). Repair parts of a multi-request are a real worn
    spare from the adventurer's pack (`Shop.worn_spare`).
  - `Items.STATS_IN_PLAY` / `stat_in_play` — stats with no effect in play (and inert affixes) are labelled in tooltips
    and left out of equipment-sheet totals and comparisons.
- **R1 identity rules.** `Regions.identify` turns the studied relic into what it was **in place** (same uid; a stacked
  relic is split first, `split_from`; `identified` records what it was; an `identified` Lore event; earlier Lore of the
  relic is linked into the piece's provenance). `Crafting.socket` never renames a piece; a Common → Magic change is
  written on the `enchanted` event (`rarity_from`/`rarity_to`). `Hire.dismiss` hands the hireling's gear over on record
  (`departed` event, holdings archive). `ItemRegistry.retire_stock` keeps merchant stock that has a history (workshop
  work, notable pieces, Lore events) on record when a stock is replaced or a ship or the caravan leaves.
- **R1 field hirelings.** `Hire._produce` does field work only (gathering, quarrying blanks, relic hunting and study,
  road trade); `Hire.NO_FIELD_WORK` (smithing) produces nothing. Workshop goods come only from station work.
- **R1 Steward Mode look-only buttons.** `StewardUI.guard_action(button, route)` and `guard_direct(button)` disable an
  acting button in a look-only panel while the steward runs the forge, with `StewardUI.AWAY_ACTION_TIP`.
- A save from a newer schema is never loaded, migrated or overwritten; the player is told why (`Saves.newer_schema`).
- JSON turns integers into floats; `Saves._restore_ints()` converts integral values back, except keys listed in `FLOAT_KEYS`.

## Template / override system

- **Sprites:** `Assets.get_tex("stations/forge")` looks for `user://overrides/sprites/<id>.png`, then a user-provided `res://assets/sprites/stations/forge.png`, then the shipped template `res://assets/sprites/stations/template_forge.png`. **All Claude-made art is named `template_*`**: drop a same-named file without the prefix next to it and it wins automatically, with no code change; delete it and the template returns. The art scripts in `tools/art/` write `template_` names through `artlib.tpath()`. If none exists it uses a generated parchment placeholder, logs the missing id once, and counts it in the F3 overlay. The whole game runs with zero art.
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

## Station display bases

Every crafting station stands on a painted tabletop base, the same miniature base the characters use, scaled to the station.

- **Generator:** `tools/art/make_station_bases.py` writes `assets/sprites/stations/bases/<id>.png` plus `anchors.json` (where each base's top-face centre sits in its PNG).
- **Tint and surface follow the discipline:** smithing sooty flagstones, runecraft slate, alchemy moss, stitching leather, arcane plum with a gilt ring.
- **Placement:** `world.gd` `_station_base()` puts each base on the floor layer, so the station's lower edge stands on its top face. The geometry mirrors the generator.
- **Visual only:** no collision; station collision and interaction points are unchanged.

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
| `adventurers.gd` | `run_encounters()` (legacy resolver): threats from `destinations.json` (power, dmg, weak, resist), scaled by `Danger.trip`. Offence = level + attack (+magic for casters) + 3 × matching damage type; defence reduces damage proportionally; draughts heal; coatings wear off after 3 trips. `plan_next()` keeps the adventurer's own wish (`next_dest`: a story plan or a pick by level — it pulls the planner +6 when they lead) and the damage type that place is known for (`wish_prop`; each claim checked against the live foes). |
| `shop.gd` | Reputation (delegates to `Reputation`: average village affection × 0.8 + what the village has heard), upkeep, goods customers, disputes, repairs of adventurers' own gear, refusals |
| `inn.gd` (`InnLife`) | Table talk from real state; knucklebones on `Dice`; romance beats (walk, keepsake, wedding, married lines) |
| `crafting.gd` | `treat()` applies coatings and oils. Arcane recipes add `bound` magic (spellweave die). Hirelings on shift add `hireling_assist()` to the skill bonus. `requires_flag` gates forgotten recipes. |

**Developer and soak tools:**
- `dev_panel.gd`: the F10 developer tools; the action is `dev_panel`.
- `tests/soak.tscn`: 28 simulated days, with a printed summary.

**Save compatibility:** every new field is added on first access, so older saves still load:
- adventurers: trait, potions, log, history
- hirelings: traits, log, history
- `world.scouted` (and `world.rep` until schema 10 moved it to `reputation`)

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

## Living village (`expeditions.gd`, `chronicle.gd`)

- **State:** `Game.state["exp"] = {active: {id: expedition}, done: [last 25], parties: {}}`, `Game.state["chronicle"]` (cap 400), `Game.state["offers"]`, `Game.state["difficulty"]`. All plain JSON, saved with the game.
- **Clock:** `Game.now()` is absolute minutes. `Game.advance_minutes` calls `Expeditions.tick()` every five game minutes; each expedition steps while `next_at <= now`. The step is a state machine: `travel_out → moving ⇄ acting → travel_back → finish`. Pause and speed (`Game.paused`, `Game.speed` 1/2/4/8) only change how fast real time feeds the clock.
- **Authority:** the simulation runs in exactly one place (static functions over `Game.state`). UI never simulates: the observer and board only read the expedition dictionaries and interpolate the marker with `Expeditions.marker_pos(e)`. There is no multiplayer in this project; the single simulation is the host-authoritative model a networked version would keep.
- **Records:** every encounter appends a record to `e.encounters` with actions `{t, kind, actor, target, roll, mod, total, vs, hit, crit, dmg, parts, hp_after, weapon_uid, armour_uid, txt}`; the journal `{t, day, time, text, kind, rec}` points at it. The encounter view replays these, revealing live actions as `Game.now()` passes `rec.t + action.t`.
- **Item instances** carry `uid`, `owner`, `history` (cap 12), `crafted_by`, `craft` (quality, dice, operations) and optional `named`. `Game.find_uid_anywhere(uid)` finds an instance in the stores, on an adventurer or a hireling.
- **Difficulty** factors live in `expeditions.json → difficulty` and are read at use: `Expeditions.diff()` (enemy, death, death_dc, heal_rate, prices, wages, loot, observe, detail).
- **UI:** `WantedPanel` (board, `WantedSheet` cards), `DossierPanel`, `ObserverPanel` (`MapView`, `EncounterView`), `DifficultyPanel`. These set `blocks_time = false`; `Game.ui_open` freezes the player while any window is open.

## History: one Lore, the Chronicle as its view (R3, completion run)

Since R3 there is **one** history (canon §10.4, Gate J): `Lore` (`lore.gd`, `Game.state["lore"]`) is authoritative and
the Chronicle of the Realm (`chronicle.gd`) is a *view* of it (`Lore.chron_ids`; save step 11 converted old feeds in
order). `Chronicle.add` records a Lore event and lists it; there is no cap. Events carry `refs`, `roles` (heir, giver,
receiver, escort, captain, visitor …) and `because` (causal links pushed with `Lore.push_cause`); runtime indices answer
`of_item`, `of_actor`, `of_place`, `why` and `consequences`. Retention: routine workshop events (note, repaired,
sharpened, treated) at importance 0 older than 60 days fold into monthly digests per item (`Lore.compact`, every 30
days); folded ids redirect (`Lore.folded`), so nothing that referenced them dangles. Seeded streams (`rng.gd`: world,
expeditions, commerce, crafting) are persisted after every draw and saves keep floats exactly (the `floats` sidecar),
so a saved game replays bit-identically. `tests/long_probe.tscn` runs multi-year campaigns and audits history.

## The completion run R3–R8 (architecture notes)

- **R4 institutions** (`institutions.gd`): the village (Reeve Tamsin Hale — her title is kept; decision 7's
  "mayor" naming is still the user's to make), the muster and the Highmarsh Watch hold supply (bulk counts with mean
  quality), stock (real items, registry holder "institution"), lots, a purse and payments. Contracts can name prestige
  pieces (staged work orders; `given_name`); molds and patterns (`craft_tools.gd`) speed series work.
- **R5 equipment depth** (`gear_depth.gd`): twelve affix effects, three sets matched by maker's mark, arcana bound by
  an arcanist (`Refinement` enchant/attune), states broken → disabled → destroyed (only by the warned experiment).
- **R6 Reliquary & heirs** (`reliquary.gd`, station "reliquary", registry holder "reliquary"): out-of-service pieces
  with earned significance; heirs only from ownership records and `characters.json` families; letters, the four
  answers (decline, custody, return, sale), custody guards on sale/pawn/display, `Refinement` "restore", the
  bloodline tag (Grimhold) and its ancestral nature (`Items.base_stat` × `Reliquary.strength_factor`).
- **R7 procurement**: `barter.gd` (goods as payment, valued by `Valuation`; a piece that serves the taker is equipped),
  `escorts.gd` (hireling escorts priced on `Danger.trip`; cover lowers `Hire.odds`; status "escorting"),
  `captains.gd` (the nine data captains as persistent people: visits, timed voyages, outcomes, memory and trust).
- **R8 world recognition**: `militia.gd` (readiness from the muster's real kit, a patrol that drifts toward it,
  `WorldSites.enemies_at` thins common bandits by patrol × reach), `Reputation` news and channels (`carry`: travel,
  ship, letter — `Expeditions.start/finish`, `Trade._depart`, `Contracts._close`), `visitors.gd` (patrons who come for
  a recorded reason), political letters sealed for the smith (`Steward.POLITICAL_PATRONS`).

## Iteration 009 architecture notes

- **Content modules:** `tools/data/extra_*.py` add ITEMS, CHARACTERS and PROPS without editing `make_data.py`
  (helpers in `make_data_helpers.py`). New data files are read with `DB.extra("name")` (cached).
- **Gating:** `Crafting.station_locked_reason()` asks `Property.station_reason()` (installed in an owned workshop room)
  and `SkillTree.station_reason()`; `Crafting.recipe_locked_reason()` asks `SkillTree.recipe_reason()`.
- **Property state** `Game.state["property"]`: `units`, editable `rooms` (rect, unit, kind), `doors` (between, at, w),
  `stations` {id: {pos, flip}}, `stored`, `next_room`. Edits run on `plan_copy()` and are applied with `commit()`
  after `validate()`. `Main.rebuild_world()` rebuilds the village from the plan. Old saves (no key) own everything.
- **Lazily created state keys** (old saves load): `property`, `skilltree`, `items_seen`, `design_plan`, `trade`,
  `ironfront`, `roisin`, `station_log`, `talk_markers`, `tutorial`, `seen_items`, `player.look`, `player.fatigue`.
- **Saves** go to `Saves.dir` (default `user://saves/`); tests call `Saves.use_test_dir()`.
- **Template art:** every generated image is `template_<name>.png`; a same-named file without the prefix overrides it.
  Iteration 009 art scripts: `make_property_art.py`, `make_ui_icons.py`, `make_checks_ui.py`, `make_trade_art.py`,
  `make_village_art.py`, `make_ironfront_art.py`, `make_player_looks.py` (plus additions to `make_icons.py`).
- **Audio inbox:** `assets/audio/inbox/<id>.(ogg|wav)` sits between user overrides and shipped audio.

## Tests

The permanent suite and the rule for every iteration are described in [`TESTING.md`](TESTING.md).

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
  | `slice` / `slice_reload` | Vertical slice 003–008 route and persistence |
  | `village` | Living Village acceptance: difficulty choice, craft → sell the exact instance → party forms → departs → board and dossiers → live observation (time keeps running) → finishes unobserved → journal, loot, ownership → revisit → commission priorities, offers, employees → save → Master restriction → existing visuals |
  | `village_reload` | Expedition records, chronicle and the sold instance survive a restart |

- `tools/lint/check_gd.py` runs gdtoolkit syntax checks plus heuristics for Godot 4 type-inference errors. It works without the engine.

## Adding content

- Edit `tools/data/make_data.py` (stations, items, characters, props) and run it. It also writes the recipes from `make_recipes.py`.
- To change recipes, operations, materials, dice or rarity, edit `tools/data/make_recipes.py`.
- To change rooms, doors and furniture, edit `tools/data/make_layout.py`.
- Art scripts live in `tools/art/` and audio in `tools/audio/`. All are deterministic and rebuild single assets with `--only=`.
