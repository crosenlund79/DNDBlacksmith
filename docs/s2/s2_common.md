# S2 "The Living Smithy" — shared conventions for every worker (READ FULLY FIRST)

You are one of four parallel workers on milestone S2 of **Ember & Ash** (Godot 4.3, GDScript, GL Compatibility; project
in `game/` of your git worktree). The lead merges your branch into `claude/s2-living-smithy`.

## Governance (from CLAUDE.md — binding)
- Confirm the repo first: `git remote -v` → crosenlund79/DNDBlacksmith; `game/project.godot` → `config/name="Ember & Ash"`.
  Your worktree starts at `2e854af` (A1, S1, A2, Run 0, Run 0.1 integrated; save schema 4). STOP and report on mismatch.
- Read `docs/EMBER_ASH_CANONICAL_VISION.md` (v1.2) before coding; it is the design authority. The S2 brief (quoted in your
  worker brief) is the user's explicit later decision for its items. Anything else that would change the design: do NOT
  build it — write it in your report as a proposal.
- Registers in `docs/` (decision/roadmap/observation) are owned by the lead: do not edit them. Do not edit the canonical
  documents or CLAUDE.md.
- Preserve: item identity (one object per uid; makers; provenance; Lore), saves (old saves load; new state keys created
  lazily on write; if you need a structural change, tell the lead — schema bumps are lead-owned), `template_` art
  fallbacks and creator overrides (never overwrite creator art), Steward Mode (S1) behaviour unless your brief changes it.
- Commit on your worktree branch with clear messages (several commits fine). Do NOT push. End each commit message with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01HoR6KAxgu6YHDD8PGQ7LCJ`. No model identifiers elsewhere.
- Never touch real saves (`user://saves/`). Tests run in test mode (A1 isolates them); use unique slot names.

## File ownership (stay inside yours; tiny local edits elsewhere only if unavoidable — list them in your report)
- STEWARD: `scripts/systems/steward.gd`, `scripts/ui/*steward*`, `welcome_back_panel.gd`, `sealed_letter.gd`,
  `scripts/systems/vitality.gd`, speed/XP guard code in `scripts/autoload/game.gd` and `crafting.gd`/`skills.gd` (XP paths
  only), smith autopilot in `scripts/world/` (player actor control) — coordinate via `Smithy.walk_to_station`.
- CLARITY: `craft_result_panel.gd`, `station_panel.gd` (header/check wording), world prompts, bag/drop placement and
  highlighting and lighting in `scripts/world/world.gd`, `data/layout.json`, `property.gd` keep-clear rules,
  `shop_panel.gd` (goods/potion branch), `offer_picker.gd`, `inventory_panel.gd` filters, vendor panels,
  `contracts_panel.gd`, `apprentice_actors.gd`.
- EARLY: `tutorial.gd`, `tutorial_card.gd`, Borin's tutorial start (hirelings/world spawn), `guide.gd` wording, toolbar /
  `ui_root.gd` shortcuts and labels, `project.godot` input map, check overlay timing (`scripts/ui/minigames/*`, result
  auto-close), the optional auto-walk setting (`Settings`) and its trigger after a check.
- ECONDEV: `adventurers.gd` pricing (`price_estimate`, `purchase_check`), `commerce.gd`/`trade.gd` pricing and stock data,
  `consult.gd` offers, `sim.gd`/`payments.gd` gift paths, `shop.gd` pricing (NOT the goods/potion branch of the panel),
  `dev_panel.gd`, `dev_catalogue_panel.gd`, `dev_tools.gd`, a dev skill-check bypass hook at the start of a check.
- Shared hot spots: `world.gd` (STEWARD autopilot, CLARITY bags/highlight/light, EARLY auto-walk) — change only the
  functions you need, keep them small, do not reformat. `Smithy.walk_to_station` is THE way to send the smith to a
  station (STEWARD and EARLY both use it; extend it backward-compatibly if needed and say so). `tests/playtest.gd`:
  register your rendered phase with a minimal change (your phase lives in its own `tests/playtest_s2_<you>.gd` like
  `playtest_econ_a2.gd`). `test_runner.gd`: only if you must.

## Running Godot (from YOUR worktree's `game/` folder)
- Binary G = `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/godot/Godot_v4.3-stable_linux.x86_64`
- Import once (and after a new `class_name`): `G --headless --path . --import`
- Full automated tests: `GODOT=G ./run_tests.sh full` (compile, suite, unit). Baseline: 223 scripts, suite 291/291,
  unit 384/384 — keep everything green. One suite case: `G --headless --path . res://tests/suite/suite.tscn -- t_case`.
- Rendered phase (Xvfb): `timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" G --path . --rendering-driver opengl3
  --resolution 1920x1080 res://tests/playtest.tscn -- <phase>`. Screenshots land in
  `/root/.local/share/godot/app_userdata/Ember & Ash/playtest/` (SHARED with the other workers): prefix your screenshot
  names with your phase prefix and copy them out right after the run. LOOK at them (Read tool).
- Before/after evidence: take BEFORE screenshots from the unchanged base (e.g. a second worktree or `git stash`) and
  AFTER from your result; copy to `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/s2/shots/<worker>/`
  named `NN_before_<what>.png` / `NN_after_<what>.png`.
- GDScript pitfalls (warnings are errors): type Variant `:=` values explicitly; `int()` around divisions; no `randf()` in
  `sort_custom`; loop vars over untyped arrays are Variant.

## Report
Write `/tmp/claude-0/-home-user-DNDBlacksmith/7589a0b1-1f83-5372-8ed1-a7b61b59e636/scratchpad/s2/reports/<worker>.md`: per item —
investigation finding (root cause, evidence), what you changed (files, functions), tests (names) and screenshots, and what
you did NOT do (with reasons); design choices you had to make; proposals; shared files you touched; commit list. Final
reply to the lead ≤ 300 words.
