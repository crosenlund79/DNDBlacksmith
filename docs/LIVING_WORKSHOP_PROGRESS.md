# The Living Workshop (B1 + B2 + C1 + playtest consolidation #37–61) — progress

**Status: COMPLETE (11 November 2026) — on the isolated branch, not integrated, not released.** Isolated branch `claude/living-workshop` (from S2 `fce1f08`). Nothing merged into the
development branch; nothing released. Target: Windows 0.16 acceptance build (Actions artifact, not a release).

## Recovery and baseline (verified on the remote)
| What | Ref | Commit |
|---|---|---|
| Recovery point | `backup/pre-living-workshop-20261111-1121` | `fce1f08` |
| Milestone branch | `claude/living-workshop` | see `git log` |
| S2 (complete) | `claude/s2-living-smithy` | `fce1f08` |
| Development branch (untouched) | `claude/kind-dijkstra-nqkxn1` | `2e854af` |
Baseline at `fce1f08`: compile 235 scripts, suite 334/334, unit 385/385, 52/52 rendered, Windows 0.15.15 CI green. Save schema 4.

## Classification
ALIGNED/approved scope: B1, B2, C1 (canonical §4.2–4.4, §5, D1–D4, D6–D8, gates B/C), multiple station instances (D6),
playtest defects and usability. NEW SCOPE approved by this brief: spouse workshop participation with a configurable
discount cap (#50–51), the pet accompanying the smith (#52), an optional ~5× pace while the steward-smith sleeps (#40),
and the profession list (canonical §15 open detail). → canonical v1.4 at the end, describing what was built.

## Lead decisions (binding for workers; see `docs/lw/lw_common.md`)
1. Professions ↔ disciplines/skills: blacksmith ↔ classic/`smithing` (smelting also trains `mining`, Mining XP hotfix kept);
   leatherworker/tailor ↔ stitching/`enchanted_stitching` (tree branches leather + tailoring); runesmith ↔ runecraft/`runecraft`;
   alchemist/herbalist ↔ alchemy/`alchemy` (D7); arcanist ↔ arcane/`arcane_metalwork`. Field hirelings keep field skills
   (mining, travelling, relic_hunting) and a read-only profile (D1: distinct entities, shared profile; no wholesale merge).
2. The player is the blacksmith: deep personal Smithing; other crafts at his actual competence. New non-smithing gains are
   capped at a basic level (D2); levels already earned in old saves are kept (non-destructive).
3. Checks, quality, station access and eligibility use the acting worker's competence (`actor` everywhere).
4. Workshop knowledge (known Designs/techniques) is separate from personal competence and never grants it; existing unlocks
   and secrets migrate into workshop knowledge; non-smithing knowledge is learnable through a competent worker (no
   player-grind deadlocks). Player-facing "Recipe" → "Design"; internal ids unchanged.
5. Work orders: one uid reserved at creation; stages = the recipe's operations grouped by station; each stage at a real station
   instance by an eligible worker or claimed by the player (existing checks); maker = the forging-stage worker (the smith
   when he forges); `prov.contrib[]` and Lore record specialists; optional help requests (D8, ≤ 1/day, non-blocking);
   interruptions, reassignment and save/load mid-stage without duplication or lost materials.
6. Station instances: several of a type (3–5 for ~5 workers where rooms allow), each with id/location/price; workers spread
   across free instances; layouts, upgrades and saves migrate.
7. Save schema steps: FOUNDATION → 5, KNOWLEDGE → 6, PRODUCTION → 7 (the lead renumbers at merge if needed); everything else
   lazy keys.
8. Steward: opt-in, online only, ZERO player XP (incl. delayed completions, save/load); the steward-smith and apprentices use
   work orders within standing instructions; major decisions deferred.

## Workstreams
| Worker | Wave | Scope | Status | Branch / commits |
|---|---|---|---|---|
| FOUNDATION | 1 | B1 capability/profession model, per-actor checks, migration 5 | **merged** 61bf1f2 (`Workers` API: `game/scripts/systems/workers.gd`; schema 5; smith's other crafts capped at BASIC_LEVEL 5, earned levels kept); worker: full 238/343/390 green, `lw_foundation` 0 fail | `claude/lw-foundation` 07b576b |
| RELIABILITY | 1 | #57, #59–61, #53, #58, #39, #45, #56; verify #41, #48, #49 | **merged** 5fea6d3 (#59–60 root cause: skill-tree panel left old content in layout during rebuilds → message-queue overflow → SIGSEGV; fixed + seeded fuzz test); worker: full 237/346/385, `lw_reliability` 0 fail | `claude/lw-reliability` 46253af |
| UI | 1 | #38, #42, #43, #44, #46, #47, #54–55 | **merged** 653631d, `claude/lw-ui` 9c0bfd8 (#43 not reproduced → hardened); worker: full 242 scripts, suite 342/342, unit 385/385, `lw_ui` 0 fail @1920/1600; lead: compile 242/0, t_lw_ui + t_saves green | `worktree-agent-a99d9abbf2c078959` 9c0bfd8 |
| KNOWLEDGE | 2 | B2 trees, workshop knowledge, Designs naming, migration 6 | **merged** 319ce0f (tree identical to worker's tested 40e58c0, which already contained a5bc210): `WorkshopKnowledge` store; smith's own path = smithing + mining, other crafts learned through the most competent hand; `ar_energy` Smithing-6 gate removed; deadlocks fixed (master max_difficulty 10→12 for Adamantine Warplate; arcanist applicants start at Arcane 3); schema 6 `migrate_workshop_knowledge`; worker: full 250/374/390 green, `lw_knowledge` 0 fail | `claude/lw-knowledge` 40e58c0 |
| PRODUCTION | 2 | #37 station instances + C1 work orders + ledger + Emberwarden chain, migration 7 | **merged** a64e144 (tree identical to worker's 6f3aa7d): instance #1 keeps the type id, further `anvil#2`…; one per pair of hands (min 2, max 5), +25 % per extra; work orders = apprentice tasks with `stages[]` (craft-grouped), uid reserved at creation, maker = forging-stage worker (PROD-010 fixed), `prov` contributors + Lore, smith claims stages, D8 help requests; Ledger stages; steward plans via Workers; schema 7; worker: full 258/399/390 green, `lw_stations` + `lw_emberwarden` 0 fail | `claude/lw-production` 6f3aa7d |
| FAMILY | 2 | #50–52 spouse/pet, #40 steward sleep pace | **merged** 7731642 (tree identical to worker's tested fea54a2): `Family` (spouse serves the counter in shop hours by consent, one NPC identity, no slot; cap 0–25 %, default 0 %, enforced in `Shop.counter_price_reason`); pet follower (Hale Farm creature, existing art); night pace 5× opt-in (default off), restored at 06:00/exit/load/new game; walking-step loss at waypoints fixed in `npc.gd`; worker: full 254/384/390 green, `lw_family` 0 fail | `claude/lw-family` fea54a2 |

## Lead pending
- [x] UI + FOUNDATION merged (61bf1f2): lead full run ALL GREEN — compile 245/0, suite 351/351, unit 390/390; rendered
  `lw_foundation` and `lw_ui` 0 failures on the merged head.
- [x] RELIABILITY merged (5fea6d3; `WhoIsWho.is_opportunity` follows the #56 ask rule): lead full run ALL GREEN — compile
  247/0, suite 363/363, unit 390/390; rendered `lw_reliability` 0 failures. Wave-2 workers told to merge this head.
- [x] Wave 2 (KNOWLEDGE, PRODUCTION, FAMILY) spawned on a9a08ca (WIP → `claude/lw-wip-knowledge|production|family`);
  all workers were paused by the 5-hour usage limit at ~12:5x UTC and resumed at 13:22 UTC from their own transcripts; PRODUCTION's schema step is renumbered to 7 at merge (each worker appends after 5 in its branch).
- [x] Merge wave 2 (a64e144).
- [x] Lead full run on the integrated head c01caba (code unchanged since): compile 258/0, suite 399/399, unit 390/390.
- [x] Canonical v1.4 (501f038; DOCX + MD 6,925 words identical; CLAUDE.md → v1.4). Registers (830dc17): OBS-37 … 61,
  decision register +52 / 55 updated, roadmap B1/B2/C1 delivered on this branch. Evidence cells completed at the end.
- [x] RELEASE_VERSION 0.16 (6ccae6b); pre-acceptance Windows packaging run #16
  https://github.com/crosenlund79/DNDBlacksmith/actions/runs/43046977142 (final artifact rebuilt after acceptance).
- [x] ACCEPTANCE worker merged d0d5362 (`t_lw_acceptance` scenarios a–h; `tests/lw_soak.tscn`; ACC-1 fixed: cancelling a
  work order mid-stage left the smith's craft job behind). Findings F1–F8 → PROP-040 (measured), PROP-046 … 050.
- [x] Lead final run on d0d5362 (the shipping code): compile 260/0, suite 409/409, unit 390/390; soak `both 365`: LW SOAK OK
  (poor 120 → 30,679 g; established 3,000 → 29,102 g; ledger reconciled; 0 duplicate uids; 0 materials off the record;
  305–353 ms per simulated day; save 3.3–3.7 MB at day 365); seeded skill-tree fuzz 1234: 12 rounds, no crash.
- [x] All 59 rendered phases on d0d5362: 58/59 at first; `lw_family` failed once because another customer (Brother Tomas,
  full price) was fairly served before the arranged buyer — test-only fix 554f482 (only the arranged buyer at the counter);
  `lw_family` then passed twice. 59/59.
- [x] Windows 0.16 artifact **`EmberAndAsh-Windows-0.16.19`** (212.7 MB: installer + portable zip), run #19 on 554f482
  https://github.com/crosenlund79/DNDBlacksmith/actions/runs/43073154275 — tests, export, packaged Linux self-check, NSIS
  installer, Windows silent install + launch self-check all green; Publish skipped (non-default branch). Runs #16, #17, #18
  failed only at the runner's apt step (`Temporary failure resolving 'azure.archive.ubuntu.com'` installing NSIS).
- [x] Real saves untouched (`user://saves/` last modified 9 November).
- [x] Consolidated acceptance (§9): full suite, unit, all rendered phases + new e2e, old saves/migration
  idempotence, 30/365-day soaks, conservation, zero steward XP; real saves unchanged.
- [x] Canonical v1.4 (DOCX + MD, change history); registers (decision, observation #37–61, roadmap) — evidence final.
- [x] Windows 0.16 acceptance artifact (see above).
- [x] Final report (in the session). Next: nothing — awaiting the user (Windows playtest, decisions, integration).

## Resume procedure
`git fetch origin && git checkout claude/living-workshop`; read this file, `CLAUDE.md`, the canonical design, and
`docs/lw/*.md` (worker briefs); worker WIP is pushed to `claude/lw-wip-<worker>` branches (see the table). Recreate a
worktree from a WIP branch to continue a worker. Never redo a merged workstream.
