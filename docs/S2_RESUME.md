# S2 "The Living Smithy" — resume point

**Written:** 10 November 2026; **completed:** 11 November 2026. **Status: S2 COMPLETE on its isolated branch
`claude/s2-living-smithy` — verified, ready for human acceptance on Windows. Nothing from S2 is merged into the
development branch, nothing is released.** This file and `docs/s2/` (plan, worker briefs and reports) live only on the
isolated branch.

## 1. Where everything is (all verified on the remote)

| What | Ref | Commit | Notes |
|---|---|---|---|
| Development branch (default) | `claude/kind-dijkstra-nqkxn1` | `2e854af` | A1, S1, A2, Run 0, Run 0.1 integrated (Run 0.1 merged at the start of S2, `[skip ci]`) |
| Recovery point before S2 | `backup/pre-s2-20261110-1055` | `2e854af` | Branch. The matching tag `pre-s2-20261110-1055` could not be pushed (the session's git proxy refuses tag pushes, HTTP 403). |
| S2 isolated branch | `claude/s2-living-smithy` | this commit | Base `2e854af` + this resume file + `docs/s2/` briefs + **CLARITY merged** (`4d887e3`; green: 225 scripts, suite 300/300, unit 384/384) + **ECONDEV merged** (`53fe7b5`; green: 227 scripts, suite 308/308, unit 384/384) + **EARLY merged** (`8d86dd0`; green: 229 scripts, suite 317/317, unit 385/385) + lead fix `29f9edd` (reward package capped by the giver's own payment) + **STEWARD merged** (`2309117`) + lead fixes `415f64f` (autopilot never completes the tutorial's move step) and `81ba92e` (steward test: anvil names only) + **canonical v1.3** (`8974092`). Full suite after STEWARD: 234 scripts, suite 333/333 (one assertion corrected), unit 385/385. `game/RELEASE_VERSION` 0.15 for the acceptance build. |
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
- **STEWARD (§2–3)** — FINISHED and MERGED (`2309117`, report `docs/s2/reports/steward.md`): new `steward_smith.gd` (the working-smith duty) and `steward_smith_actor.gd` (the visible
  autopilot), changes to `steward.gd`, `vitality.gd`, `crafting.gd`, `game.gd`, `smithy.gd`, `player.gd`, `player_nav.gd`,
  `world.gd`, the steward UI and welcome-back report, `t_s2_steward`, and `t_steward` (fatigue rule). Contains a throwaway
  `t_zz_probe.gd` to drop before merging.
- **EARLY (§5)** — FINISHED and MERGED (`8d86dd0`, report `docs/s2/reports/early.md`; Y now opens the Workshop panel and the Workshop Ledger moved to Q; no recipe makes a dagger — adding one is a proposal): tutorial, tutorial card, Borin, hud toolbar shortcuts, check overlay and skill-check panel timing,
  settings (auto-walk), guide/reference/objectives wording, docs, `t_s2_early`, rendered phase `s2_early`.
- **ECONDEV (§6–7)** — FINISHED and MERGED (`53fe7b5`, report `docs/s2/reports/econdev.md`; its change to the `t_steward` soak threshold — periods held by the player's spending limits need ≥ 1 decision instead of ≥ 10 — was reviewed and accepted; STEWARD to reconcile): pricing (`adventurers.gd`, `commerce.gd`, `shop.gd`, `commerce.json` via
  `tools/data/make_commerce.py`), consultation, gifts (`sim.gd`), developer tools (`dev_panel.gd`, `dev_catalogue_panel.gd`,
  `dev_tools.gd`, `game.gd`, `ui_root.gd`), `t_s2_econdev`, rendered phase `s2_econdev`.

Worker reports (status first) are written to the session scratchpad `…/scratchpad/s2/reports/<worker>.md`; if the scratchpad
is lost, the worker commit messages and this file are the record.

## 4. Completion record (11 November 2026)
- **All four workers merged** (CLARITY `4d887e3`, ECONDEV `53fe7b5`, EARLY `8d86dd0`, STEWARD `2309117`); lead fixes
  `29f9edd` (reward package capped by the giver's own payment, D14), `415f64f` (the autopilot never completes the
  tutorial's move step), `81ba92e` (steward test: anvil names only — deed names earned later are history); canonical
  **v1.3** `8974092`; registers `77ded7e`, `b416347` (BUG-051); acceptance version 0.15 `b362877`; Mining XP hotfix
  integrated `4fbfaee` (user request); `iter2` rendered phase brings its own moonwort `70ae07c` (test fragility, not a
  defect: a hireling's alchemy hour may brew a draught from stored moonwort — existing behaviour, HA-025).
- **Automated tests on the final head:** compile 235 scripts, suite 334/334, unit 385/385 — ALL GREEN (golden saves
  0.11.2–0.14.6 migrate to schema 4; zero XP across exit and save/load; pace restored on exit and load; soaks reconciled:
  poor early game 30 d 120 → 4,825 g, 365 d 120 → 31,113 g; with apprentices 30 d 3,000 → 7,025 g, 365 d 3,000 → 30,743 g).
- **Rendered:** the 52-phase regression passed 50/52 at `b362877`; the two failures (`iter2` 3 checks, `iter2_reload` 1
  dependent check) were the moonwort test fragility, fixed in `70ae07c` and both re-run with 0 failures; after the hotfix
  `craft`, `craft_reload`, `steward_s1`, `s2_steward` re-run with 0 failures. Real save directory unchanged.
- **Windows:** CI runs #13 (`b362877`, artifact `EmberAndAsh-Windows-0.15.13`) and #14 (`4fbfaee`, artifact
  `EmberAndAsh-Windows-0.15.14`) passed tests, export, silent install and launch ("SMOKE OK"); publish skipped; latest
  release still build-0.14.6. A final run on the S2 head is recorded in the final report.
- **Open for the user:** QST-028 (Unique legacy copies), QST-029 (front entrance), QST-030 (Y/Q), QST-031 (working-smith
  earnings), PROP-022 … PROP-026; accept S2 after the Windows playtest; integrate (a merge into the default branch would
  publish build-0.15.x unless the merge commit carries `[skip ci]`).

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
