# The Living Workshop — shared conventions for every worker (READ FULLY FIRST)

You are one of the workers on the milestone "The Living Workshop" (B1 + B2 + C1 + playtest #37–61) of **Ember & Ash** (Godot 4.3, GDScript, GL Compatibility; project
in `game/` of your git worktree). The lead merges your branch into `claude/living-workshop`. Read `docs/LIVING_WORKSHOP_PROGRESS.md` (lead decisions 1–8 are binding).

## Governance (from CLAUDE.md — binding)
- Confirm the repo first: `git remote -v` → crosenlund79/DNDBlacksmith; `game/project.godot` → `config/name="Ember & Ash"`.
  Your worktree starts at the commit the lead names in your brief (wave 1: `fce1f08` + this brief commit; S2 complete; save schema 4). STOP and report on mismatch.
- Read `docs/EMBER_ASH_CANONICAL_VISION.md` (v1.3) before coding; it is the design authority. The milestone brief (quoted in your
  worker brief) is the user's explicit decision for its items. Anything else that would change the design: do NOT
  build it — write it in your report as a proposal.
- Registers in `docs/` (decision/roadmap/observation) are owned by the lead: do not edit them. Do not edit the canonical
  documents or CLAUDE.md.
- Preserve: item identity (one object per uid; makers; provenance; Lore), saves (old saves load; new state keys created
  lazily on write; a structural change gets a SaveMigrations step with the number your brief assigns), `template_` art
  fallbacks and creator overrides (never overwrite creator art), Steward Mode (S1/S2: opt-in, online only, ZERO player XP incl.
  delayed completions and save/load, the working smith, the 1.5× pace) and the Mining XP hotfix (`t_mining_xp`).
- Commit on your worktree branch with clear messages (several commits fine). Do NOT push. End each commit message with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01HoR6KAxgu6YHDD8PGQ7LCJ`. No model identifiers elsewhere.
- Never touch real saves (`user://saves/`). Tests run in test mode (A1 isolates them); use unique slot names.

## File ownership
Your brief lists the files you own. Shared core files (`crafting.gd`, `apprentices.gd`, `skills.gd`, `skilltree.gd`,
`property.gd`, `world.gd`, `steward*.gd`, `game.gd`, `save_migrations.gd`, `ui_kit.gd`, `tests/playtest.gd`) are edited only
by their owner in a wave; others make tiny, local edits only if unavoidable and list them in the report. Register your rendered
phase with a minimal change in `tests/playtest.gd` (phase code in its own `tests/playtest_lw_<you>.gd`). Do not edit `docs/`
registers, canonical documents, `CLAUDE.md` or `docs/LIVING_WORKSHOP_PROGRESS.md` (lead-owned).

## Checkpoints
Commit early and often on your worktree branch (a commit per finished sub-item). The lead pushes your branch to
`claude/lw-wip-<you>` for safe keeping. If you are told a usage limit approaches: commit everything (prefix "WIP:") and
write the STATUS section of your report immediately.

## Running Godot (from YOUR worktree's `game/` folder)
- Binary G = `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/godot/Godot_v4.3-stable_linux.x86_64`
- Import once (and after a new `class_name`): `G --headless --path . --import`
- Full automated tests: `GODOT=G ./run_tests.sh full` (compile, suite, unit). Baseline at `fce1f08`: 235 scripts, suite 334/334,
  unit 385/385 — keep everything green (the full run takes ~6 min; run it before your final commit, focused cases meanwhile). One suite case: `G --headless --path . res://tests/suite/suite.tscn -- t_case`.
- Rendered phase (Xvfb): `timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" G --path . --rendering-driver opengl3
  --resolution 1920x1080 res://tests/playtest.tscn -- <phase>`. Screenshots land in
  `/root/.local/share/godot/app_userdata/Ember & Ash/playtest/` (SHARED with the other workers): prefix your screenshot
  names with your phase prefix and copy them out right after the run. LOOK at them (Read tool).
- Before/after evidence: take BEFORE screenshots from the unchanged base (e.g. a second worktree or `git stash`) and
  AFTER from your result; copy to `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/lw/shots/<worker>/`
  named `NN_before_<what>.png` / `NN_after_<what>.png`.
- GDScript pitfalls (warnings are errors): type Variant `:=` values explicitly; `int()` around divisions; no `randf()` in
  `sort_custom`; loop vars over untyped arrays are Variant.

## Report
Write (STATUS section first: done / in progress / not started per item, last test results, breakages, next steps) `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/lw/reports/<worker>.md`: per item —
investigation finding (root cause, evidence), what you changed (files, functions), tests (names) and screenshots, and what
you did NOT do (with reasons); design choices you had to make; proposals; shared files you touched; commit list. Final
reply to the lead ≤ 300 words. Observation outcomes must be honest: implemented / verified / investigated-not-reproduced / deferred — never silently discard one.
