# S2 "The Living Smithy" — resume point

**Written:** 10 November 2026, before a usage-limit pause. **Status: S2 IN PROGRESS — nothing from S2 is merged into the
development branch, nothing is released.** This file and `docs/s2/` (plan and worker briefs) live only on the isolated branch
`claude/s2-living-smithy`.

## 1. Where everything is (all verified on the remote)

| What | Ref | Commit | Notes |
|---|---|---|---|
| Development branch (default) | `claude/kind-dijkstra-nqkxn1` | `2e854af` | A1, S1, A2, Run 0, Run 0.1 integrated (Run 0.1 merged at the start of S2, `[skip ci]`) |
| Recovery point before S2 | `backup/pre-s2-20261110-1055` | `2e854af` | Branch. The matching tag `pre-s2-20261110-1055` could not be pushed (the session's git proxy refuses tag pushes, HTTP 403). |
| S2 isolated branch | `claude/s2-living-smithy` | this commit | Base `2e854af` + this resume file + `docs/s2/` briefs + **CLARITY merged** (`4d887e3`; full tests green after the merge: 225 scripts, suite 300/300, unit 384/384). |
| WIP checkpoint — STEWARD | `claude/s2-wip-steward` | `07263e0` (or later) | Unverified snapshot of the worker's worktree (17 files). |
| WIP checkpoint — CLARITY | `claude/s2-wip-clarity` | `0af4e53` (or later) | 8 worker commits + snapshot (18 files). |
| WIP checkpoint — EARLY | `claude/s2-wip-early` | `be317d5` (or later) | Unverified snapshot (29 files). |
| WIP checkpoint — ECONDEV | `claude/s2-wip-econdev` | `13fc13b` (or later) | Unverified snapshot (19 files). |
| Latest release | `build-0.14.6` | `154d08a` | Unchanged. |

"(or later)": the workers were asked to commit their own WIP; the lead re-pushes their branches to the same `s2-wip-*` names
whenever they commit (check `git log origin/claude/s2-wip-<worker>`).

## 2. Baseline (recorded at `2e854af`)
- Compile 223 scripts, suite 291/291, unit 384/384 — ALL GREEN. Save schema 4. Canonical v1.2 (DOCX = Markdown, 6,019
  words). Real saves listing captured before any S2 work.
- Disk: 34 merged, clean worker worktrees from earlier milestones were removed (their branches remain).

## 3. Completed so far
**Lead:** preflight; Run 0.1 integration; recovery point; isolated S2 branch; baseline; classification (ALIGNED except two
items of NEW SCOPE explicitly approved by the S2 brief — the steward directing the smith's own visible work, and the 1.5× pace
— to be recorded as canonical v1.3 once built; the S1 rule "fatigue holds while away" is superseded); the plan
(`docs/s2/S2_PLAN.md`) and four worker briefs (`docs/s2/s2_common.md`, `s2_w_steward.md`, `s2_w_clarity.md`,
`s2_w_early.md`, `s2_w_econdev.md`) with the lead's design decisions.

**Workers (in progress, NOT verified by the lead):**
- **CLARITY (§4)** — FINISHED and MERGED into the S2 branch (`4d887e3`, worker report in `docs/s2/reports/clarity.md`): leather-curing batch feedback (OBS-11); skill-check type named before the work
  (OBS-12, BUG-044); potion offers follow the request and are greyed with reasons, optional filters (OBS-15, OBS-16,
  BUG-043); contracts panel keeps its width on closed orders (BUG-001); apprentices work from inside their station's room
  (OBS-21); floor drops kept clear of the Loft stair, contextual hint ring, night forge light (OBS-13/14); suite case
  `t_s2_clarity` and rendered phase `s2_clarity`. Front entrance: status in the worker report.
- **STEWARD (§2–3)** — WIP: new `steward_smith.gd` (the working-smith duty) and `steward_smith_actor.gd` (the visible
  autopilot), changes to `steward.gd`, `vitality.gd`, `crafting.gd`, `game.gd`, `smithy.gd`, `player.gd`, `player_nav.gd`,
  `world.gd`, the steward UI and welcome-back report, `t_s2_steward`, and `t_steward` (fatigue rule). Contains a throwaway
  `t_zz_probe.gd` to drop before merging.
- **EARLY (§5)** — WIP: tutorial, tutorial card, Borin, hud toolbar shortcuts, check overlay and skill-check panel timing,
  settings (auto-walk), guide/reference/objectives wording, docs, `t_s2_early`, rendered phase `s2_early`.
- **ECONDEV (§6–7)** — WIP: pricing (`adventurers.gd`, `commerce.gd`, `shop.gd`, `commerce.json` via
  `tools/data/make_commerce.py`), consultation, gifts (`sim.gd`), developer tools (`dev_panel.gd`, `dev_catalogue_panel.gd`,
  `dev_tools.gd`, `game.gd`, `ui_root.gd`), `t_s2_econdev`, rendered phase `s2_econdev`.

Worker reports (status first) are written to the session scratchpad `…/scratchpad/s2/reports/<worker>.md`; if the scratchpad
is lost, the worker commit messages and this file are the record.

## 4. Pending (in order)
1. CLARITY: done. STEWARD, EARLY and ECONDEV: each finishes its brief, keeps its full test run green, writes its report; the lead re-pushes `s2-wip-*`.
2. **Lead review and merge** into `claude/s2-living-smithy`, one worker at a time (CLARITY merged; next ECONDEV,
   EARLY, STEWARD — the largest last). Expected conflict hot spots: `world.gd` (STEWARD/CLARITY/EARLY), `smithy.gd`
   (STEWARD/EARLY), `crafting.gd` (STEWARD/CLARITY), `shop.gd` (CLARITY/ECONDEV), `station_panel.gd` (CLARITY/EARLY),
   `player_nav.gd` (STEWARD/EARLY), `game.gd` (STEWARD/ECONDEV), `ui_root.gd` (EARLY/ECONDEV), `tests/playtest.gd` (phase
   registrations), `game/README.md`, `docs/TESTING.md`, `docs/PLAYGUIDE.md`. Drop `t_zz_probe.gd`.
3. After each merge: `--import`, `GODOT=<godot> ./run_tests.sh full` green.
4. Full verification (S2 brief §9): fresh and golden (migrated) saves; the first-hour tutorial; the steward smith alone in
   a poor early game and with apprentices; zero personal XP across activation/completion/exit/save-load; consistent 1.5×
   pace; ledger reconciliation; `ItemRegistry.scan` and `Uniques.audit` clean; steward soaks 30/365 (+ poor early game)
   with actual activity and finances; the 48 existing rendered phases + `s2_steward`, `s2_clarity`, `s2_early`,
   `s2_econdev`; real save directory unchanged.
5. Canonical **v1.3** (Steward Mode: the working smith and the default 1.5× pace, exactly as built; the fatigue rule), DOCX
   and Markdown synchronized (word-level check), change history; `CLAUDE.md` pointer.
6. Registers: observation register OBS-22 … (the Nov-10 handwritten observations — originals not available; the S2 brief
   summarises them), statuses for OBS-01 … OBS-21, the §8 deferred proposals (hunting/grocer, donations, survival
   incentives, visible gear, hand-designed adventurers, voices, B1/B2/C1); decision and roadmap registers with S2 evidence.
7. Windows acceptance build: set `game/RELEASE_VERSION` to `0.15` on the S2 branch (a non-default branch never publishes),
   dispatch `.github/workflows/windows-installer.yml` on `claude/s2-living-smithy`, confirm "SMOKE OK" and that the artifact
   `EmberAndAsh-Windows-0.15.<run>` exists (90-day retention). **Merging S2 into the default branch later would publish
   build-0.15.x unless the merge commit carries `[skip ci]`.**
8. Final report (implemented, deferred, before/after screenshots, tests, steward activity and economics, branch/commit,
   backup, Windows download location, readiness for human acceptance). Then STOP — no merge, no release, no B1.

## 5. Blockers and notes
- The **handwritten November 10 observations** are not in any file or message available to Claude; the S2 brief's
  sections 4–8 are used as their summary.
- **Tag pushes** are refused by the session's git proxy (403); branches are used as recovery points.
- **Usage limit**: if a session ends mid-merge, the S2 branch is never left half-merged on the remote — merges are pushed
  only after a green full test run.

## 6. Exact resumption instructions
```bash
cd /home/user/DNDBlacksmith            # or a fresh clone of crosenlund79/DNDBlacksmith
git fetch origin
git checkout claude/s2-living-smithy && git pull --ff-only origin claude/s2-living-smithy
git log --oneline -3 origin/claude/s2-wip-steward origin/claude/s2-wip-clarity origin/claude/s2-wip-early origin/claude/s2-wip-econdev
```
1. Re-read `CLAUDE.md`, `docs/EMBER_ASH_CANONICAL_VISION.md`, this file and `docs/s2/S2_PLAN.md`; verify the repository
   (§1 of CLAUDE.md) and that `origin/backup/pre-s2-20261110-1055` = `2e854af`.
2. For each worker that had not finished: create a worktree from its checkpoint
   (`git worktree add ../s2-<worker> origin/claude/s2-wip-<worker> -b s2-<worker>`), read `docs/s2/s2_common.md` and its brief,
   read its report/commit messages, and continue from its STATUS (or re-run a worker agent with the same brief pointed at
   that worktree). Use a Godot 4.3 binary (`GODOT=<path> ./run_tests.sh full`; first `--import`).
3. Continue with §4 above.
