# S2 worker STEWARD — the autonomous working smith and the 1.5× pace

Read `s2_common.md` (same folder) first, then `docs/EMBER_ASH_CANONICAL_VISION.md` §4.5 / D19, `docs/STEWARD_MODE_DESIGN.md`
(S1 architecture, duties, deferrals, report, soaks), `scripts/systems/steward.gd`, `vitality.gd`, `crafting.gd`, `smithy.gd`
(`walk_to_station`, `craft_again`), the player actor in `scripts/world/`, and `tests/suite/cases/t_steward*.gd`.

## The user's S2 brief (verbatim, your sections)
**2. Steward Mode — Autonomous Working Smith.** Extend S1 so the steward genuinely operates the player blacksmith.
* Independently select feasible routine forging, ordinary repairs, preparation, sensible restocking and commission work.
* Use existing skills, unlocked Designs, real materials, time, equipment, economy and workstations.
* Smith visibly moves to the correct station and performs the work using existing animations.
* Respect working hours, fatigue, sleep, breaks, demand and production capacity.
* ZERO player XP, skill progression, mastery, unlocks or delayed XP while Steward Mode is active.
* Never automate masterpieces, dangerous experiments, protected Unique/Epic items or consequential personal decisions.
* Continue autonomous apprentice/workshop management using existing standing instructions.
* No additional skill requirement merely to activate Steward Mode.
* Maintain real business decisions; never replace the steward with passive time advancement.

**3. Steward simulation speed.** Steward Mode defaults to 1.5× normal game speed.
* Accelerate the complete simulation consistently: world time, NPCs, production, movement, travel, commerce, fatigue and
  event scheduling.
* Do not multiply output, prices, XP or rewards independently.
* Return to normal speed immediately on exit.
* No offline progression or catch-up.
* Ensure deterministic tests remain possible.

From §9 (yours to prove): autonomous smith completing genuine routine work with limited early-game resources and no
apprentices; Steward Mode with apprentices, constraints and changing demand; smith movement, animations, station access,
fatigue and working hours; zero personal XP across activation, completion, exit and save/load; consistent 1.5× world
simulation; inventory, financial and UID integrity; protected historical items and unique artifacts; deferred decisions and
truthful sealed-envelope reports; 30- and 365-day steward soaks, including poor early-game conditions.

## Lead decisions (binding for you; report how you applied them)
1. **Competent, not superior** (canon §4.5): the steward smith's checks resolve automatically at an *average* performance for
   his current skill (reuse an existing automatic-check path, e.g. how apprentices/hirelings or the Project Bench get quality;
   no minigame UI). Never ≥ 115 % craftsmanship, never an anvil naming, never a masterpiece, only known routine non-secret
   Designs he has actually unlocked, real materials from the stores (buying within standing instructions).
2. **Zero XP**: no player XP, skill XP, mastery, tree unlocks or deferred XP while active **and for any work started while
   active** (even if it finishes after exit or after a save/load). Put the guard where XP is granted (one central place if
   possible) and mark steward-started work in its state. Prove it with save/load mid-work.
3. **Fatigue**: S2 supersedes the S1 rule "the smith's fatigue holds while away" (`t_steward.test_fatigue_holds_while_away`,
   register BUG-005): the working smith now tires, takes breaks, eats/rests and sleeps at night by the existing `Vitality`
   rules. Update that S1 test to the new rule (say so). If he does no work (e.g. nothing feasible) his fatigue follows the
   normal resting rules.
4. **Working hours** default 08:00–18:00 with a midday break; outside them he rests/sleeps (existing bed/rest). You may add
   working hours to the standing instructions if it is small; otherwise a constant.
5. **Never**: masterpieces (contract masterpiece slot), refinement / reforge / socketing / enchanting / designer experiments,
   protected, Unique or Epic items, consequential personal decisions (keep S1 deferrals and sealed letters).
6. **Pace**: 1.5× while Steward Mode is active, restored to the previous speed immediately on exit (and on load: a session
   loaded with the mode off is at normal speed). Everything that moves in the world must move consistently (consider
   `Engine.time_scale`, or the existing `Game.speed`, whichever really scales NPC walking, animations, production and the clock
   together — prove it). A 1×/1.5× choice in the steward panel is welcome if cheap; default 1.5×. Headless tests and soaks
   drive `Game.advance_minutes` and must stay deterministic.
7. **One engine for play and tests**: the working-smith duty must run headless in soaks (no VillageWorld): when no world is
   present, walking is time spent (estimate from distance/station), not a physical walk; when the world exists the smith
   physically walks (stairs/lift too) and works at the station with the existing work animation; the camera follows him.
8. **Activation**: remove any skill/level requirement for activating Steward Mode if one exists (keep the real refusals:
   e.g. a minigame or a panel that must close).
9. Look-only rules from S1 (the player looks but does not act) still apply; the steward smith is an autopilot of the player
   avatar, not a new NPC. Truthful report: the welcome-back report lists the smith's own work (what he made, repaired,
   prepared; at what quality; materials used; hours worked) from recorded events.

## Deliverables
- Code as above; `tests/suite/cases/t_s2_steward.gd` covering: early-game smith alone (starting gold/materials, no
  apprentices) produces real routine work over N days with real materials and time; repairs at the counter paid by the
  customer; commission of an ordinary order; restocking within limits; with apprentices and changing demand; zero XP across
  activation/completion/exit/save-load (including work started under the steward finishing after exit); fatigue/hours/sleep
  respected; never masterpieces/refinement/protected items; 1.5× pace on, restored on exit, deterministic headless;
  ledger reconciled; UID integrity (`ItemRegistry.scan` clean, `Uniques.audit` clean).
- Soaks: extend the 30/365-day steward soaks to include the working smith, plus a **poor early-game** soak (starting
  resources, no apprentices). Report actual activity (pieces made by the smith, repairs, preparations, purchases, sales,
  hours worked, sleep) and finances (ledger-reconciled) in your report.
- Rendered phase `s2_steward` (`tests/playtest_s2_steward.gd`): screenshots of the smith walking to and working at stations
  (forge/anvil, a Loft station if reachable), resting/sleeping, the steward panel showing pace and the smith's activity, the
  welcome-back report listing his work. Before/after screenshots where meaningful.
- Report per `s2_common.md`.
