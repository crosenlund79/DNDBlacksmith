# Worker PRODUCTION (wave 2) — multiple station instances (#37) and C1 collaborative production

Read `docs/lw/lw_common.md`, `docs/LIVING_WORKSHOP_PROGRESS.md` (decisions 1–8), the FOUNDATION report
(`docs/lw/reports/foundation.md`), canonical v1.3 §4.1, §4.4, §4.5, §5, §6.1, D4, D6, D8, and register entries PROD-001 …
PROD-026, WS-006/007/011/012, TECH-003, TECH-027, EQ-010, UX-009, STW-025 (code anchors: one worker per apprentice task, maker =
finishing worker at `apprentices.gd` ~1484 — a latent C1 defect; station ids are keys in Property, Apprentices, World,
Contracts; four production shapes exist — reconcile, do not add a fifth). Base: the merged wave-1 head the lead names.

## The user's brief (verbatim)
**3. Collaborative production — C1.** Implement genuine staged work orders:
* One persistent item identity/UID from work-order creation through completion, storage, sale, refinement and inheritance.
* Each stage assigned to an eligible worker at a real physical station.
* The smith forges; specialists perform their own stages.
* Workers visibly travel, work, rest and hand off tasks.
* Player may perform eligible stages manually, using existing precision checks.
* Preserve original maker/maker's mark; record specialist contributions and quality in provenance and Lore.
* Optional specialist assistance; significant interventions require appropriate player decisions.
* Clear Ledger showing stage, worker, progress, materials and blockers.
* Support interrupted orders, save/load mid-stage and reassignment without duplication or lost materials.
* Demonstrate the complete Emberwarden Longsword multi-profession production chain.
Do not turn workshop production into an abstract universal crafting menu. Preserve physical workstations and player interaction.

**4. Multiple workstation instances — OBS-37.** Remove the one-per-type limitation. Support multiple forges, bellows, anvils
and other appropriate stations, each with its own identity, location, price and worker availability. For approximately five
workers, 3–5 usable instances of a relevant station should be possible where physical room and resources permit. Workers must
distribute work between available stations rather than all queuing at the original. Integrate with staged work orders,
pathfinding, upgrades and saved layouts.

## Design within the lead decisions
- Station instances first: instance ids (e.g. `anvil#2`) with type, room, position, price (rising per extra instance),
  occupancy; Property buy/place/move/validate per instance (room capacity rules decide 3–5); world, nav, apprentice actors,
  contracts and upgrades resolve type → instances; migration step **7** turns today's single stations into instance #1
  (layouts kept); old saves load.
- Work orders: extend the existing apprentice task (do not add a parallel system): `stages[]` from the recipe operations
  grouped by station type, each with assignee (eligible via `Workers.can_do`), station instance, state, quality, materials
  reserved at start (never consumed twice, returned on cancel), timestamps; the uid reserved at creation and the same item
  dict carried to completion; maker = the forging-stage worker; `prov.contrib[]` {who, profession, stage, station, quality,
  day} + one Lore event; the player may claim a stage and play the existing check at that station; optional help requests
  (D8: ≤ 1/day, expire, never block; significant interventions ask the player); reassignment when a worker is absent;
  save/load mid-stage; the Workshop Ledger shows stage, worker, progress, materials, blockers.
- Steward (S1/S2) must keep working: the steward and the working smith create and advance work orders through the same
  functions; zero player XP holds (`Game.grant_player_xp` guard, steward-begun stages).
- Emberwarden Longsword (`data/recipes.json`: forge → anvil → rune_engraving_stand → cauldron → grinding_wheel →
  stitching_table): the smith forges, a runesmith seats the rune, an alchemist quenches, a leatherworker wraps the grip — one
  uid from order to stores, maker = smith, contributors recorded, visibly worked at each station; sold afterwards with
  provenance intact.

## You own
`property.gd` (instances), `apprentices.gd` (tasks → work orders), `apprentice_actors.gd`, station resolution in `world.gd`
and `player_nav.gd`, `contracts.gd` station use, `smithy.gd`, the work-order parts of `crafting.gd` and `station_panel.gd`, the
Workshop Ledger panel, steward duty adapters for work orders (`steward.gd`/`steward_smith.gd` — keep S2 behaviour), provenance
contributions (`provenance.gd` small additions), migration step 7. Tests `t_lw_production.gd` + an end-to-end
`t_lw_emberwarden.gd`; rendered phases `lw_stations` and `lw_emberwarden` (several anvils used at once; the full chain with
each worker at his station; the ledger; save/load mid-stage). Report per `lw_common.md`; commit at each architectural step.
