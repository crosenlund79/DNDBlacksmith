# R1 "Integration & Foundation Closure" — build report

*What R1 delivered, how it was verified, and what is still open.*
Brief: [`NEXT_BUILD_BRIEF.md`](NEXT_BUILD_BRIEF.md) · roadmap: [`FINAL_DEVELOPMENT_ROADMAP.md`](FINAL_DEVELOPMENT_ROADMAP.md) ·
human playtest: [`R1_ACCEPTANCE_CHECKLIST.md`](R1_ACCEPTANCE_CHECKLIST.md).

- **Branch:** `claude/r1-integration`, from `be92b9a`, which contains `65e70b5`.
- **Recovery point:** `backup/pre-r1-20261117`.
- **Final commit and installer:** see §5.
- **Classification:** ALIGNED (Gate A remainder; no new gameplay scope).

## 1. Decisions applied

| Decision | Applied as |
|---|---|
| **D-1** deferred | No merge into the default branch, no release, no tag. Version 0.17 is built as a **private Windows artifact** only. On a non-default branch the installer workflow cannot publish (`windows-installer.yml:150`). |
| **D-2** approved | A studied relic keeps its uid, provenance and Lore. A stack is split first. |
| **D-3** approved | Rune socketing keeps the name. A Common → Magic change is written on the `enchanted` event (`rarity_from`/`rarity_to`). |
| **D-4** approved | The bounded R1 scope below. R2 is untouched. |
| **D-5** conditional → **verified, applied** | Off-station hireling production was removed after checking its four conditions (§3). |

## 2. Delivered

| ID | What | Code | Tests |
|---|---|---|---|
| EQ-007 | Identification in place (same uid); stack split (`split_from`); `identified` record and Lore event; earlier relic Lore linked into provenance; Uniques re-registered under the kept uid | `regions.gd` `identify/_single_piece/_become` | `t_r1_identity` (identify, split) |
| BUG-042 | Socketing never renames; rarity change recorded | `crafting.gd` `socket` | `t_r1_identity` (2 tests) |
| BUG-017 | Dismissed hireling's gear: `departed` Lore event and holdings archive | `hirelings.gd` `_leave_with_gear` | `t_r1_identity` |
| EQ-004 | `ItemRegistry.retire_stock`: at every restock (pawn, rival) and every ship or caravan departure, pieces with a history are kept on record; rolled merchant stock and non-equipment need none | `item_registry.gd`, `commerce.gd`, `trade.gd` | `t_r1_identity` |
| EQ-012 | Permanent structured tombstones (`ItemRegistry.tombstone/tombstone_of/tombstones`), written by `Provenance.lose/destroy`, marked `recovered` on return; **save step 9** (schema 9) reconstructs them from old saves' Lore and marks pre-R1 identified relics | `item_registry.gd`, `provenance.gd`, `save_migrations.gd`, `game.gd` | `t_r1_identity` (3 tests), `t_saves` |
| STAFF-004 / HA-025 (D-5) | Hirelings do field work only (mining, herbs and salt, runestone blanks, relic hunting and study, road trade); no off-station potions, oils, runestones, ingots or horseshoes; Smithing labelled "(no field work)" | `hirelings.gd` `_produce`, `NO_FIELD_WORK`; `hirelings_panel.gd` | `t_r1_workshop` (4); `test_runner`, `t_s2_early`, `t_experience_a2` updated to the new rule |
| STW-026 / BUG-003 | Acting buttons in look-only panels are disabled while away, with the reason: Improve it…, Craft record, Help's next-step action into an acting panel, the Skill Tree's Learn (also refused in `_learn`) | `steward_ui.gd` `guard_action/guard_direct`; `item_panel.gd`, `guide_ui.gd`, `skilltree_panel.gd` | `t_steward_ui.test_look_only_buttons_disabled_away` |
| REL-010 | Golden saves made by each build's own code: 0.15 (`b362877`, schema 4), 0.16.19 (`587399c`, 7), 0.16.21 (`65e70b5`, 8), 0.17 (`32b7be0`, 9); SHA-256 in the fixtures README | `tests/fixtures/saves/` | `t_saves` (26 tests, incl. `Uniques.audit()` on every golden) |
| TECH-014 (part) | `.github/workflows/tests.yml`: the full headless suite on every push to `claude/**`; never publishes | — | CI run 44161928108: success |
| BUG-049, TECH-023 | `game/docs` (GAMEPLAY, PLAYGUIDE, TESTING, TECHNICAL) describe 0.17; `LIVING_REALM_STATUS.md` marked superseded | — | — |
| Registers | Decision register (14 IDs, counts recomputed, change history), roadmap register (milestone rows; "what players have" corrected), observation register (R1 note) | — | — |

## 3. D-5 verification (before removal)

**Field work preserved.** Mining, herb and salt gathering, quarrying runestone blanks, relic hunting and study, and road
trade all stay (`t_r1_workshop.test_field_work_still_pays`, `test_relic_study_is_field_work`).

**Station production untouched.** No station or apprentice code was changed. The established-workshop soak still makes
137 pieces and batches, including 15 staged work orders.

**Existing saves preserved.** No saved data changes meaning. All golden saves from 0.11.2 to 0.17 load, migrate, round-trip
and play on.

**Early economy viable.** Same seed, Borin plus two hired applicants, the steward running the workshop for 84 days:

| Run | Day 28 | Day 56 | Day 84 |
|---|---|---|---|
| With processing | 4,886 | 8,104 | 12,891 |
| Without processing | 4,880 | 9,277 | 12,441 |

That is −3.5 % at day 84, within run-to-run spread. The S2 poor-start soak stays solvent: 120 → 31,585 g over 365 days.

**What was removed.** The two applicants alone had turned stored materials into 156 runestones, 37 potions and 10 oils
over 84 days without a station.

## 4. Verification

| Gate | Result |
|---|---|
| Compile | **274 scripts, 0 failed** |
| Suite (full) | **461 passed, 0 failed** (505 s) |
| Unit & regression | **394 passed, 0 failed** |
| CI `tests.yml` on `b823dd2` | success (run 44161928108) |
| Rendered phases | **72 / 72 pass**. 68 passed first time. Four had **stale expectations, pre-existing and failing identically on the pre-R1 baseline `65e70b5`**; they were updated (one line each below) and re-run green. |
| 365-day soak, both set-ups | money conserved and reconciled; materials balanced (nothing un-itemised); identity clean (1,653 and 1,482 items, 0 duplicate uids, 0 shared, 0 strays); zero player XP under the steward (xp withheld 15,556 / 9,916). Poor: 120 → 31,585 g, 295 ms per day. Established: 3,000 → 31,232 g, 490 ms per day. **One scheduling invariant fails** ("nobody waited for a station while another of its kind stood free": 2 quarter-hours in 365 days, established set-up). It fails **identically on the pre-R1 baseline** with the same seed. Not caused by R1; listed in §6. |
| Year-long identity probe | inside the full suite (`t_identity`) |
| Golden saves | 8 (0.11.2 … 0.17): load, migrate to schema 9, round-trip identically, play on, no duplicate uid, `Uniques.audit()` empty |
| Windows installer | see §5 |
| Human playtest | **pending** — `R1_ACCEPTANCE_CHECKLIST.md` |

**Rendered expectations updated in R1** (each failed the same way on `65e70b5`):

- `interiors`: toured the smithy rooms at their pre-v1.7 coordinates. It now tours the ground-floor rooms from the
  world's own room list. The Loft and basement are toured by `lvw_layout`.
- `craft` #9: expected a Legendary from the iron longsword. Canonical v1.6 §6.2 makes ordinary Designs Rare at most; the
  expectation now checks Rare with craftsmanship above 100 %.
- `lvw_dev`: the ×4 clock ratio was counted in whole game minutes over 1.5 s, so it flipped between 4.0 and 5.0. The
  clock is now timed over 6 s, standing still, and gives 4.5×.
- `s2_steward`: the smith's 1.5× walking speed was measured as straight-line displacement over 0.4 s, which turns corners
  in the compact smithy. It is now the distance walked while moving (306 px/s against his own 230; the clock is exactly
  2.40 game min/s).

## 5. Build

*(Filled in once the private Windows installer workflow on this branch has finished.)*

## 6. Open items

1. **Pre-existing soak invariant (est set-up), registered as BUG-062:** a worker briefly waits for a station while another instance of its type
   is free (2 quarter-hours per 365 days). It is identical on `65e70b5`. The likely cause is a tick-ordering race: a
   task keeps its "Waiting for" blocker until its next tick after another worker frees an instance in the same tick.
   This is a scheduling detail, outside R1's bounded scope.
2. **D-5 follow-up decision:** hireling **Smithing** now has no field work; the slider is labelled. Keep it, or drop it
   from the hireling allocation?
3. **Relic study by hirelings:** this was kept as field work. The player studies a relic at the cleansing basin; a
   relic-hunting hireling studies it without a station. Confirm this is acceptable under D-5.
4. **Human Windows acceptance** of 0.17 (REL-004, REL-005/STW-027): pending the user's playtest with the checklist.
5. **Engine noise:** "Invalid polygon data, triangulation failed" errors appear in every rendered run on the baseline
   too. They are not new.
6. **Not integrated, not released** (D-1). Integration of everything since Run 0.1 remains a user decision.
