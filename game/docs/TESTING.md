# Ember & Ash — the permanent test suite

The suite proves, every iteration, that the major systems work together and that progression from a
village forge to legendary dragon armour stays achievable. It lives in the repository and is kept, never
recreated.

## One command

| What | Command (from `game/`) |
|---|---|
| Everything: compile check, regression & progression suite, unit tests | `GODOT=/path/to/godot ./run_tests.sh` |
| Fast smoke subset for routine changes | `GODOT=/path/to/godot ./run_tests.sh smoke` |
| Windows | `run_tests_windows.bat [smoke\|full]` |
| One suite case only | `godot --headless --path . res://tests/suite/suite.tscn -- t_property` |
| Rendered play-tests (need a display or `xvfb-run`) | `godot --path . res://tests/playtest.tscn -- <phase>` |

Exit code 0 means green. Reports go to `user://logs/suite_report.txt` and `user://logs/test_report.txt`.

**Real saves are never touched.** The suite redirects saves to `user://test_saves/` (`Saves.use_test_dir()`).
Each test starts from a fresh, seeded new game (`seed(9001)`), and the crafting fixture uses fixed check scores and
dice, so runs are deterministic.

## Layout

| Path | What |
|---|---|
| `tests/suite/suite.tscn` → `suite_runner.gd` | Discovers `tests/suite/cases/*.gd`, runs every `test_*`, prints PASS / FAIL / SKIPPED with diagnostics |
| `tests/suite/suite_case.gd` (`SuiteCase`) | Base class: `check`, `eq`, `note`, `skip`; fixtures `fresh_game`, `craft`, `craft_blocker`, `give`, `train`, `days`, `save_load`, `has_system`, `sys` |
| `tests/suite/cases/` | The cases (below). A case lists its fast tests in `const SMOKE := [...]` |
| `tests/test_runner.tscn` | The long-standing unit and regression tests (383 checks) |
| `tests/compile_all.tscn` | Every script compiles with the autoloads present |
| `tests/playtest.tscn -- <phase>` | Rendered play-tests with synthetic input and screenshots |

## Cases

| Case | Covers |
|---|---|
| `t_core` | Startup data and state, an iron longsword from a genuine new game, resource consumption, item statistics, unique positive inventory, save/load in the test folder |
| `t_progression` | **Scenario A — beginner to master.** A planner learns the skill tree up to Legendary Arcane Craftsmanship and forges Dragonscale Armour using only real systems: skill XP from actual crafting, materials from the herbalist, merchant ships, special imports, hireling trade runs and expeditions or crafted from other materials, stations bought and placed through Property, rooms bought when the workshop is full, knowledge from restoring a rune tablet and holding a dragon scale. Gold is credited as business income (the only stand-in; earning is covered by scenario B) |
| `t_business` | **Scenario B.** Craft, fulfil a commission with priority and bonus, equip the adventurer, run the expedition, check the forged blade's uid in the combat record and its history, and persistence |
| `t_employees` | **Scenario C.** Recruit, hidden potential, assign work, gain experience over a working day, send Borin out, collect the haul, smelt what came home, pay wages |
| `t_property` | **Scenario D.** Modest start, buy adjoining rooms, place and relocate stations, partitions and doorways, trapping layouts refused, persistence, old saves keep the whole building |
| `t_ironfront` | **Scenario E.** A full match against the AI, rewards, a new deck made active, persistence; Blitzkrieg |
| `t_social` | **Scenario F.** Family ripple, memories, gifts, fatigue from crafting and its effect, rest and sleep, finds offered at the counter, the herbalist, persistence |
| `t_trade` | Import orders from deposit to delivery, ships visit and their schedule persists |
| `t_village10` | Every building has a non-solid sign clear of its doorway, the new venues (pawnshop, rival forge, the Hales, caravan camp, ceremony stage, graveyard plots) have their spots on the nav graph and their interactables, the caravan comes and goes, wander targets never fall inside a building, five simulated minutes of wandering never put an animal in a house or on a footprint, horses and cows stay in their paddocks |
| `t_integrity` | Broken references (recipes, stations, loot, ships, tree), tree shape (unique ids, prerequisites exist, no cycles, every recipe and station learned from exactly one node, every station purchasable, every required knowledge findable), every required material has a source, every room can eventually be bought and the whole building is reachable, commissions never ask for more than a craftable piece can give |

## Bugs the suite has already caught (kept as regressions)

- Every station fitted into the starting rooms, so the workshop never needed to grow. Stations now stand only in
  workshop rooms, each with a capacity (`t_progression` shows the rooms bought).
- Belt commissions could ask for protection 14 when the best belt reaches 9 (`t_integrity.commissions_possible`).
- The Arcane Foundry upgrade could only be bought through the UI; `Shop.buy_upgrade()` is now shared.

## Every future iteration

1. Run the baseline suite (`./run_tests.sh`) before changing anything, and note the result.
2. Implement the new work.
3. Extend the suite for the new mechanics: a case in `tests/suite/cases/`, fixtures in `SuiteCase` if reusable,
   and add the new content to `t_integrity` and `t_progression` where it belongs to progression.
4. Rerun the baseline and the progression scenarios.
5. Fix newly introduced regressions — and add a test for every significant bug fixed.
6. Report the remaining failures honestly, with their diagnostics.

Keep the suite practical: tests that guarantee real gameplay, not test counts.
