# S2 STEWARD — the autonomous working smith and the 1.5× pace

## STATUS (final)
Worktree branch `worktree-agent-a4f8b2d9ef189213c`, base 2e854af (verified: origin crosenlund79/DNDBlacksmith,
`config/name="Ember & Ash"`). Commits: **7d75489** (engine, guard, pace, UI, suite case — WIP checkpoint),
**754519e** (rendered phase, S1 playtest rule, pace-row layout, work spot), **e03e716** (load-proof pace measurement,
design doc §10). Not pushed.
Classification: **ALIGNED** — an extension of D19 / canon §4.5 inside its rules (real actions, nothing conjured,
competent-not-superior, consequential matters deferred, truthful report, online only). Note for the lead: canon §4.5
speaks of "the absent smith"; the S2 brief (the user's later explicit decision) makes him work under the steward —
I implemented the brief and kept every §4.5 guarantee (no experience, average performance, deferrals).

Tests: full `run_tests.sh full` ALL GREEN at the engine state (compile 226, suite **305/305** = 291 + 14 new, unit
**384/384**, 402 s). After the last two commits (smithy.gd use=false walk branch, steward panel layout, playtests,
doc) re-ran the touched cases: t_steward_ui, t_smithy, t_navigation, t_world 29/29; compile 227 scripts, 0 failed.
Rendered: `s2_steward` **0 failures** (run 3); `steward_s1` 0 failures on my branch (and 0 on the base for BEFORE).
Not done: Windows packaging/human gameplay (not available here).

## Per brief item
**2. Autonomous working smith** — DONE.
- Finding: S1 never drove `Crafting`; the player figure faded out (`player.gd`), fatigue was frozen (`Vitality.on_hour`),
  no smith work path existed. Apprentice and Project-Bench code already had automatic quality paths.
- Change: new `scripts/systems/steward_smith.gd` (duty `smith`, on by default). Every 5 game minutes
  (`Game.advance_minutes`, like apprentices) he: takes a seated customer's repair (or a multi-visitor's repair part) when
  he can finish before they give up → walks to the grinding wheel → `Shop.do_repair` / `Shop.repair_part` (customer pays
  from own purse, ledger names payer); otherwise starts his queued work with `Crafting.start` (real materials; reserves
  and apprentice-committed materials left alone) → per operation walks to the station, works `(30+12·checks)/smith_pace`
  minutes, `Crafting.record_step` (existing fatigue rule) → `Crafting.build` as the smith (`craft.steward=true`).
  Queue: commissions (committed by the orders duty when no apprentice can make it in time — `_order_plan` now tries
  apprentices, then `StewardSmith.order_plan`), preparation (smelting, when no apprentice can — `_queue_prep`),
  restocking (display below `stock_target`, counting apprentice restock tasks). His queue's materials are in
  `Steward._needs()`, so replenishment buys them within the limits. Repairs between operations come first.
- Competent, not superior (lead decision 1): each check = `Contracts.smith_hour_quality(rid, seeded rng)` (the Project
  Bench's automatic path), piece quality = weighted mean, capped at **110** (below HoF craftsmanship 112, masterwork
  115, anvil naming 120). Only routine Designs: classic smithing, unlocked, no secret node, no forgotten/teaching/
  legendary-grade recipe, difficulty ≤ order rule and ≤ his level (cached per day: `routine_ids()`).
- Never (decision 5): masterpiece slot untouched, no refinement/reforge/socket/coating/enchant/designer; protected,
  Unique, Epic pieces never repaired — `Steward.defer_protected_repair` (shared with the S1 duty).
- Apprentices/workshop management (S1 duties) unchanged and continue; the smith has station priority (existing rule).
- Activation (decision 8): no skill/level requirement existed; verified a fresh Smithing-4 smith with no staff can hand
  over. `can_activate` now also accepts a piece the steward's smith left in hand (only the player's own piece refuses).
- World (decision 7, 9): `scripts/world/steward_smith_actor.gd` walks the player's own figure via
  `Smithy.walk_to_station(sid, w, false)` (extended backward-compatibly: `use=false` → walk to the station's working side
  `ApprenticeActors.work_spot`, nothing opens; default behaviour unchanged) and `PlayerNav.walk_to_entity(e, use)` /
  new `walk_to_point(p)`; reports arrival; apprentices' strike/stir motion, the world's sparks/flash per operation,
  workshop sounds, a bubble with his activity. Stairs and lift work (Loft anvil shot). Camera follows (player camera).
  Player body: visible, ignores keyboard/clicks while away, keeps walking while look-only panels are open.
- Report (decision 9): `report().smith` and a "Your own work under the steward" section in While You Were Away: hours at
  the stations, pieces (quality, purpose, for whom), repairs (who, quality, paid), prepared, materials used, nights,
  breaks, rests, the piece still in hand, anything set down, "no experience gained (N points withheld)".
**Zero XP** (decision 2) — DONE. Central guard: `Game.grant_player_xp` refuses while `Steward.xp_blocked()` (mode
active OR a steward-marked Crafting job is being recorded: `record_step`/`build` hold the job's `steward` mark). A piece
begun under the steward gives nothing when finished after the return or after loading a save (tested with a save made
mid-piece). Also no teaching flag, no objective completion, craft record `xp = {}`. Withheld amounts counted.
**Fatigue/hours/sleep** (decisions 3, 4) — DONE. S1 hold removed from `Vitality.on_hour`; S1 test
`test_fatigue_holds_while_away` rewritten as `test_fatigue_follows_vitality_rules_while_away` (BUG-005 superseded).
Standing instruction `smith_hours` (default 8–18, validated), 12–13 break by the hearth (`Vitality.rest`), rest an hour
at fatigue ≥ 80, home outside hours, 22–6 asleep in bed (`Vitality.sleep`). On return a steward-set rest/sleep ends.
**3. Pace** (decision 6) — DONE. `Engine.time_scale = pace` (1.5 default, instruction `pace` 1.0/1.5 with a choice on
the hand-over, status and instructions tabs) and `Game.speed` held at 1 — one scale for the clock (`Game._process`),
NPC/apprentice/smith walking (delta-based), animations, tweens, timers. `Game.set_speed` while active is remembered for
the return. Restored at once on exit, on load, on a new game (+ safety in `Game._process`). Rendered proof (against
summed unscaled frame time, immune to load clamping): clock **2.40** game-min/s and smith walk **335 px/s** (own 230) at
1.5×; **1.60** after return. Headless: deterministic (two seeded runs identical).

## Tests (t_s2_steward.gd, 14): activation_needs_no_skill, early_smith_alone_does_real_work, counter_repair_paid_by_
customer, protected_repair_left_for_the_smith, commission_made_by_the_smith, restock_within_limits, with_apprentices_and_
changing_demand, zero_xp_across_exit_and_save_load, hours_breaks_rest_and_sleep, never_masterwork_secret_or_masterpiece,
pace_on_restored_on_exit_and_load, deterministic_headless, soak_poor_early_30_days, soak_poor_early_365_days. Each checks
ledger reconciliation / ItemRegistry.scan / Uniques.audit where relevant. t_steward.gd: fatigue test rewritten; soak
"smith crafted nothing" → "report counts exactly what he crafted" (S2 supersedes).

## Soaks (headless, ledger-reconciled, 0 duplicate uids / 0 strays, Uniques.audit clean, skills unchanged)
| | days | ms/day | smith pieces | smith repairs | other | gold |
|---|---|---|---|---|---|---|
| Poor early (120 g, starting materials, no apprentices) | 30 | 127 | 29 | 88 (+1322 g) | 38 ingots smelted, 145 h at stations, 30 nights/30 breaks, bought 452 g | 120 → 5213 (207 lines) |
| Poor early | 365 | 332 | 79 | 1285 (+21209 g) | 95 ingots, 1169 h, 365 nights; bought 1498 g of 1500 limit | 120 → 33371 (1936 lines) |
| S1 workshop (2 apprentices + smith) | 30 | 175 | in 42 total | 82 | apprentices 25+16 works | 3000 → 6662 |
| S1 workshop | 365 | 255 | in 117 total | 1278 | apprentices → journeyman/apprentice | 3000 → 30225 |
Sealed letters arise from real events (e.g. a hatchet he made earned Epic → one sealed letter). XP withheld: 15 739 pts/yr.
Lead FYI on `_soak` thresholds: with the working smith the S1 365-day soak had 213–330 decisions every month; keep
ECONDEV's `_limited_now()` relaxation for limit-bound months, but 10 remains a fair floor for months with staff.

## Screenshots (looked at) — scratchpad/s2/shots/steward/
s2st_01 hand-over with pace choice · 02 walking to a station · 03 at the forge's working side with bubble · 04 at the
anvil · 05 panel "You, at work under the steward" + pace · 06 plate with "You:" line and pace · 07 midday break by the
hearth · 08 asleep in his bed · 09 next morning · 10/11 While You Were Away with his work · 12 the Loft anvil.
Before/after (base 2e854af vs branch, phase steward_s1): 01_before/after_smith_away_handover (faded vs present),
02_before/after_steward_running (absent smith ×4 clock vs smith walking, pace 1.5×), 03 status panel, 04 report, 05
hand-over text.

## Design choices
Quality cap 110 (not 114) to stay below every recognition threshold; classic smithing only (other crafts are
specialists' — D2); apprentices keep first claim on commissions (S1 behaviour), the smith on counter repairs when free;
legendary rarity can still come from the fortune die as for apprentices (such pieces are protected/deferred, not sold);
working hours a small instruction, break/bed fixed (12–13, 22–6); walks headless = 0.45 min/tile, +3 min/floor, 4 min to
the quarters; world walk stuck-fallback after 4×estimate+30 min.

## Proposals / for other workers
- EARLY: `Tutorial.on_moved` counts the autopilot's walking (tutorial "Find your feet" completed while away) and
  `item_crafted`/`station_worked` notify on steward/apprentice pieces — suggest ignoring while `Steward.smith_away()`.
- Performance: 365-day soaks now 93–121 s (late-year world is richer); consider running one 365-day soak only in CI.
- Project Bench hours by the smith himself not automated (Contracts.work advances the clock itself); apprentices still
  do contract hours (S1).
- Apprentices do not yet see the smith's repair station as busy (he waits if one holds the wheel).

## Shared files touched (small, local)
`autoload/game.gd` (new_game reset, pace safety in _process, set_speed guard, smith tick hook, XP guard),
`systems/crafting.gd` (XP holds for marked jobs, no teach/objective under the steward), `systems/smithy.gd`
(walk_to_station `use` param), `systems/vitality.gd` (S1 hold removed), `world/player.gd`, `world/player_nav.gd`
(walk without use, walk_to_point, optional marker), `world/world.gd` (one add_child line), `tests/playtest.gd` (phase
registration), `tests/playtest_steward_s1.gd` (one expectation → S2 rule), `tests/suite/cases/t_steward.gd`,
`docs/STEWARD_MODE_DESIGN.md` (§10). New: `systems/steward_smith.gd`, `world/steward_smith_actor.gd`,
`tests/suite/cases/t_s2_steward.gd`, `tests/playtest_s2_steward.gd`. No schema bump (state keys created lazily).
