# Ember & Ash — Current Development Status

*Read-only audit, 2026-11-09. No tracked files changed (`git status` clean before and after).*

**Legend:** ✅ verified implemented (code + automated tests, and rendered checks where noted) · 🟡 partially implemented / known gaps · 📋 planned, not started · ❓ unknown / unverified

## 1. Identity, version, release
| Item | Value |
|---|---|
| Repository / remote | `crosenlund79/DNDBlacksmith` (`origin` = https://github.com/crosenlund79/DNDBlacksmith) |
| Godot project | `game/project.godot`, `config/name="Ember & Ash"`, Godot 4.3 |
| Branch | `claude/kind-dijkstra-nqkxn1` — local = remote, 0 unpushed commits, clean tree |
| HEAD | `154d08a` "Release 0.14: The Living Realm milestones 2–5" |
| `game/RELEASE_VERSION` | 0.14 |
| Latest release | **build-0.14.6** from `154d08a` (published 2026-11-09 03:29 UTC): `EmberAndAsh-Setup.exe`, `EmberAndAsh-Windows-portable.zip` |
| Release verification | CI `windows-installer.yml` run on `154d08a`: export ✅, silent install + launch on windows-latest ✅ (`SMOKE OK … stations=30 missing_sprites=0 log_errors=0`), publish ✅ |
| Earlier releases | build-0.13.5 (`3d82c93`), build-0.12.4 (`2ffdaeb`), build-0.12.3 (`114321a`) |
| Backups on remote | `backup/pre-iteration-012-*`, `backup/pre-ux-iteration-*`, `backup/pre-living-realm-20261109-0053` (and older) |

## 2. Completed gameplay systems ✅
Crafting with precision checks, weighted digital + physical dice, rarity/affixes (Common → Legendary/Unique/Set), five disciplines + tailoring, skill tree; property/room purchase & layout editing; hirelings & expeditions; adventurers with durability, autonomous purchases, companions; village life, family/romance; commerce (pawnshop, caravan, rival smith, menagerie, harbour, herbalist); Hall of Fame, Epic, ceremonies; Ironfront card game; navigation, quick travel.
- **Iteration 011 — The World Remembers:** `lore.gd`, `provenance.gd`, `world_sites.gd`, `item_story.gd`, `personality.gd` (tests `t_provenance`, `t_world`, `t_itemstory`, `t_personality`, `t_world_remembers`).
- **Iteration 012 — Apprentices:** `apprentices.gd`, Workshop Ledger (Y), `apprentice_actors.gd` (`t_apprentices`, `t_workshop_ui`, `t_workshop_e2e`).
- **UX iteration:** `guide.gd`, `knowledge.gd`, `venues.gd` (Pell's Provisions counter, shop hours), `world_prompts.gd`, `refinement.gd` + `refine_panel.gd`, dev catalogue `dev_tools.gd` (`t_guide`, `t_venues`, `t_refine`, `t_devtools`, `t_ux_journey`).

## 3–5. The Living Realm run (roadmap phases 2–5) — merged in `154d08a`
| Feature | Status | Files / tests | Known gaps |
|---|---|---|---|
| Evolving Smithy: craft areas, room tiers, the Loft (2nd floor) + aetheric lift, walk-to-next / craft-again, capacity | ✅ | `smithy.gd`, `property.gd` floors, `tools/data/smithy_layout.py`; `t_smithy` (10), `smithy_rl` | Loft camera shows village beyond the area frame (same as inn upstairs); painted room names small; talking items & hireling work spots only consider ground floor |
| Equipment presentation: humanoid sheet, compare | ✅ | `equipment_sheet.gd`, `dossier_panel.gd`; `t_equipment_ui`, `equip_rl` | Counter "⇄" replaces the shop panel (reopen counter) |
| Cloak slot + save migration | ✅ | `Items.migrate_cloak_slots` (`saves.gd`) | Cloaks not in class core wish-lists |
| Soft terrain transitions | ✅ (visual) | `village_ground.gd`, `soft_ground.gdshader` | Stream-bank change subtle |
| Living adventurers: world seed, goals, bonds, retirement, newcomers | ✅ | `living.gd`, `extra_living.py`; `t_living` (90-day soak 3.3 s), `living_rl` | Seed not typeable in New Game (CLI `--seed=N` only); new Lore kinds use default icon |
| Persistent companies | ✅ | `companies.gd` | Rarely break up naturally on Journeyman (lifecycle covered by direct tests) |
| Adventurer consultations & persuasion | ✅ | `consult.gd`, `consult_panel.gd`; `t_consult` (7), `consult_rl` | "Upgrade" advice goes via commission (no refinement of an adventurer's own item); thresholds rough; panel needs scrolling |
| Sponsored expeditions | ✅ | `sponsor.gd`, `sponsor_section.gd`, Expeditions hooks; `t_sponsor` (14), `sponsor_rl` | One negotiation at a time; a trip ≈ 1 day (no extra travel delay); single-item "share" paid in coin |
| Major contracts & Project Bench (patrons → Crown, hour blocks, apprentice hours, masterpiece) | ✅ | `contracts.gd`, `contracts_panel.gd`, `contract_world.gd`, `data/contracts.json`; `t_contracts` (10), `contracts_rl` | Letters only as toast/journal/Chronicle (no messenger NPC); units counted, not item instances (except masterpiece); crates may overlap wall decor; bench at default 150 g |

## 3. Not started / partial (roadmap, per `game/docs/LIVING_REALM_STATUS.md`)
| Phase | Status |
|---|---|
| 6 Equipment affixes & deeper legacy | 📋 not started (existing affixes/refinement/provenance remain) |
| 7 Civilizations, allegiance, world influence | 📋 not started |
| 8 Authored storylines & regional conflict prototype | 📋 not started |
| 9 Campaign variation & historical chronicle | 🟡 world seed + seeded rosters only; no chronicle/comparison work |
| 10 Broader overarching conflict | 📋 not started (depends on 8) |
| Quality items: caravan curiosities' usefulness; underwhelming advanced customer requests | 📋 not addressed |
| Quality items: capacity vs stations, cloak slot, terrain edges, material clarity | ✅ addressed |

## 6. Technical debt, known bugs, incomplete integrations
- No `TODO/FIXME/HACK` markers in `game/scripts`.
- Pell's counter: facing it from behind focuses Aldric instead (he still offers Buy).
- Upgraded (refined) pieces keep their item def; tier is honoured via `Items.tier` (fixed), but names/other def-based checks still see the base def.
- Items crafted from developer-spawned materials count as normal work (dev flag not inherited).
- Talking items have no refinement-specific lines; refinement playtest feeds a fixed check score.
- Apprentice economy is generous (21-day test: ~7.9 k g stock vs ~2.9 k g costs); real income limited by customer demand — balance unreviewed.
- `adventurers.gd`: a guard was added to skip impossible "repair" errands (`Shop.worn_slot` threshold mismatch 0.35 vs 0.4) — root mismatch not unified.
- One intermittent suite failure (`t_guide.knowledge_persists`, save/load) was seen once in a worker run under parallel load; not reproduced in later runs ❓.
- Housekeeping: 28 stale worker branches and their worktrees under `.claude/worktrees/` (local only, merged, no running processes); untracked screenshot `.import` files are generated by `--import`.

## 7. Latest verifiable test results
| Check | Result | When / where |
|---|---|---|
| Compile (all scripts) | 201 scripts, 0 failed | re-run during this audit on `154d08a` |
| Suite (35 case files) | 207 passed, 0 failed, 0 skipped | re-run during this audit |
| Unit/regression runner | 383 passed, 0 failed | re-run during this audit |
| Rendered playtest regression | 43/43 phases, 0 failures | on the 0.14 merge (`ecb3b70`→`154d08a`; `full` and `stations` re-run after a test-only fix) — not re-run in this audit |
| Windows packaged install + launch | SMOKE OK | CI on `154d08a` |

**Unverified ❓:** long-term balance over a full career with all Living Realm systems together (only per-system soaks and the progression planner); performance late in very long campaigns; manual (human) playtesting of the new flows; behaviour on real Windows machines beyond the CI runner's headless smoke test.

## 8. Active / unfinished work
- No running builds, tests or workers. Nothing uncommitted or unpushed.
- Next roadmap step if continued: phase 6 (affixes & legacy), then 7–8 (civilizations; the regional-dispute proof before any wider conflict).
