# The Living Workshop (B1 + B2 + C1 + playtest consolidation #37–61) — progress

**Status: IN PROGRESS.** Isolated branch `claude/living-workshop` (from S2 `fce1f08`). Nothing merged into the
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
| RELIABILITY | 1 | #57, #59–61, #53, #58, #39, #45, #56; verify #41, #48, #49 | spawned (229a1af) | WIP `claude/lw-wip-reliability` |
| UI | 1 | #38, #42, #43, #44, #46, #47, #54–55 | **merged** 653631d, `claude/lw-ui` 9c0bfd8 (#43 not reproduced → hardened); worker: full 242 scripts, suite 342/342, unit 385/385, `lw_ui` 0 fail @1920/1600; lead: compile 242/0, t_lw_ui + t_saves green | `worktree-agent-a99d9abbf2c078959` 9c0bfd8 |
| KNOWLEDGE | 2 | B2 trees, workshop knowledge, Designs naming, migration 6 | brief `docs/lw/lw_w_knowledge.md` (031101b); after FOUNDATION | |
| PRODUCTION | 2 | #37 station instances + C1 work orders + ledger + Emberwarden chain, migration 7 | brief `docs/lw/lw_w_production.md` (031101b); after FOUNDATION | |
| FAMILY | 2 | #50–52 spouse/pet, #40 steward sleep pace | brief `docs/lw/lw_w_family.md` (031101b); after FOUNDATION | |

## Lead pending
- [x] UI + FOUNDATION merged (61bf1f2): lead full run ALL GREEN — compile 245/0, suite 351/351, unit 390/390.
- [ ] Merge RELIABILITY (still running; #59–60 crash reproduced, root cause in progress).
- [ ] Wave 2 (KNOWLEDGE, PRODUCTION, FAMILY) spawned on the merged head; PRODUCTION's schema step is renumbered to 7 at merge (each worker appends after 5 in its branch).
- [ ] Merge wave 2; consolidated acceptance (§9): full suite, unit, all rendered phases + new e2e, old saves/migration
  idempotence, 30/365-day soaks, conservation, zero steward XP; real saves unchanged.
- [ ] Canonical v1.4 (DOCX + MD, change history); registers (decision, observation #37–61, roadmap).
- [ ] Windows 0.16 acceptance artifact (RELEASE_VERSION 0.16 on this branch; workflow_dispatch; verify artifact exists).
- [ ] Final report.

## Resume procedure
`git fetch origin && git checkout claude/living-workshop`; read this file, `CLAUDE.md`, the canonical design, and
`docs/lw/*.md` (worker briefs); worker WIP is pushed to `claude/lw-wip-<worker>` branches (see the table). Recreate a
worktree from a WIP branch to continue a worker. Never redo a merged workstream.
