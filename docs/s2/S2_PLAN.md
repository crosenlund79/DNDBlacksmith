# S2 "The Living Smithy" — lead plan and state (keep up to date; survives context compaction)

## Baseline (verified)
- Repo crosenlund79/DNDBlacksmith, Godot 4.3 project "Ember & Ash". Canonical v1.2 (DOCX = MD, 6,019 words).
- Dev branch `claude/kind-dijkstra-nqkxn1` = `2e854af` (A1, S1, A2, Run 0, Run 0.1 integrated; Run 0.1 merged in this run,
  `[skip ci]`, tree identical to verified `9eb5f40`).
- Recovery point: branch `backup/pre-s2-20261110-1055` = `2e854af` (pushed, verified). Tag push refused by git proxy (403).
- S2 branch: `claude/s2-living-smithy` from `2e854af` (pushed). Save schema 4. Latest release still build-0.14.6.
- Baseline tests RECORDED on 2e854af: compile 223 scripts, suite 291/291, unit 384/384, ALL GREEN (`s2/baseline_full.out`).
- Real saves listing: `…/scratchpad/s2/realsaves_before.txt`.
- Disk: removed 34 merged clean worktrees and stale scratch (23 GB free at start).

## Classification
- ALIGNED: §4 clarity, §5 early game, §6 commerce defects, §7 dev tools, §9 verification, §10 build, §11 registers.
- NEW SCOPE approved by the S2 brief (user's explicit later decision): the steward directs the smith's own visible
  routine work (canonical §4.5 says "absent smith"); default 1.5× pace in Steward Mode. → canonical v1.3 revision at the
  end (DOCX + MD synced, change history), describing exactly what was built.
- Superseded: S1 lead decision "fatigue holds while away" (BUG-005) — S2 says the working smith respects fatigue/sleep.
- Missing source: the handwritten November 10 observations (not in any file); the S2 brief summarises them.

## Design decisions set by the lead (within the brief; report them)
1. Steward smith quality = "competent, not superior": automatic checks at an average performance for his skill; never
   ≥ 115 % craftsmanship, never an anvil naming, never a masterpiece; only known, routine, non-secret Designs.
2. Zero player XP/skill/mastery/unlocks while Steward Mode is active AND for any work started under it (even if it
   finishes after exit or after save/load).
3. Pace 1.5× by default (option 1× / 1.5× in the steward panel if cheap); whole simulation consistent; exit restores.
4. Steward smith never: masterpieces, refinement/reforge/socket/enchant, designer experiments, protected/Unique/Epic
   items, consequential personal decisions (existing deferrals).
5. Working hours default 08:00–18:00 with a midday break; sleeps at night; fatigue rises and he rests (BUG-005 resolved).
6. Auto-walk after a skill check: optional setting (default off? → worker proposes; lead decides), walks only.

## Workers (worktrees; lead merges into claude/s2-living-smithy)
| Worker | Brief | Status | Branch/commit |
|---|---|---|---|
| STEWARD (§2, §3) | s2_w_steward.md | running (spawned 10 Nov) | worktree |
| CLARITY (§4) | s2_w_clarity.md | running (spawned 10 Nov) | worktree |
| EARLY (§5) | s2_w_early.md | running (spawned 10 Nov) | worktree |
| ECONDEV (§6, §7) | s2_w_econdev.md | running (spawned 10 Nov) | worktree |

## Lead tasks
- [ ] §1 consolidation: observation register OBS-22+ for the Nov-10 items (from the brief), statuses for 1–21, superseded.
- [ ] Merge workers; resolve conflicts; full tests; rendered regression (48 + new phases); real saves unchanged.
- [ ] Soaks 30/365 incl. poor early-game; zero-XP; UID integrity; golden saves.
- [ ] Canonical v1.3 (Steward smith + pace), DOCX+MD synced; CLAUDE.md pointer.
- [ ] Registers (decision, observation, roadmap) updated with S2 evidence.
- [ ] Windows acceptance artifact via workflow_dispatch on the S2 branch; verify artifact exists (name, run link, size).
- [ ] Final report with before/after screenshots.

## Build/version decision
- Acceptance build labelled 0.15 (`game/RELEASE_VERSION` 0.14 → 0.15 on the S2 branch, lead commit before the final CI
  dispatch). Non-default branch → artifact only (EmberAndAsh-Windows-0.15.<run>, 90-day retention). Report: merging S2 into
  the default branch would publish build-0.15.x unless the merge commit carries [skip ci].

## New observations from the S2 brief (Nov-10 handwritten originals missing) → OBS-22 …
22 Borin inside smithy for tutorial · 23 dagger availability/prereqs · 24 Mira's tutorial blocked by gold · 25 K vs U +
shortcut discoverability · 26 Y shortcut vs toolbar label · 27 optional auto-walk after a check · 28 post-check delay ·
29 linen thread under Loft stairs (clarifies OBS-14) · 30 contextual highlighting · 31 evening/night forge light ·
32 front entrance · 33 steward operates the smith (visible) · 34 steward 1.5× pace · 35 hireling hunting meat/rawhide +
grocer sales (DEFERRED) · 36 developer testing tools · (37 survival incentives = OBS-10; donations = OBS-17; visible gear =
OBS-18; hand-designed adventurers/backstories = OBS-19; voices = OBS-20: all DEFERRED by §8).
