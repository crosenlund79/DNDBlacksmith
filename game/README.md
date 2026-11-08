# Ember & Ash — first playable build

A straight top-down 2D fantasy blacksmith RPG and village-life simulation for **Godot 4.3+** (GDScript, GL Compatibility renderer).

You are Brannoc Ironhand, an aging, heavyset former adventurer who runs the forge in the village of Brindlewick. You craft equipment, employ hands, send them on expeditions, sell to and arm the adventurers at the neighbouring inn, and live with the consequences.

**Art direction:** `docs/visual_exploration/ink_parchment_gothic_80_20/` (80% Ink & Parchment, 20% Gothic Noir).

## Windows installer

Every iteration publishes a Windows installer through GitHub Actions (`.github/workflows/windows-installer.yml`):
the project is exported with Godot 4.3, packaged with NSIS (`installer/ember_and_ash.nsi`), installed silently and
launched with its `--smoke-test` self-check on a Windows runner, then attached to a GitHub release.
Latest: <https://github.com/crosenlund79/DNDBlacksmith/releases/latest/download/EmberAndAsh-Setup.exe>.

## Launching

You need Godot 4.3 or newer (the standard build, not .NET).

| Platform | How |
|---|---|
| **Windows** | Put `Godot_v4.x-stable_win64.exe` in this `game/` folder, or set the `GODOT` environment variable, then double-click **`run_windows.bat`**. The first run imports assets, which takes about a minute. |
| Windows tests | `run_tests_windows.bat` (exit code 0 means all passed; the report is written to `%APPDATA%\Godot\app_userdata\Ember & Ash\logs\test_report.txt`) |
| Linux / macOS | `GODOT=/path/to/godot ./run_linux.sh` (add `--tests` to run the test suite) |
| Editor | Open `game/project.godot` in the Godot editor and press F5 |

## Tests

The tests are verified with **Godot 4.3.stable.official.77dcf97d8**.

| Test | Command (from `game/`) |
|---|---|
| **Everything** (compile check, regression & progression suite, unit tests) | `GODOT=/path/to/godot ./run_tests.sh` (or `run_tests_windows.bat`); `./run_tests.sh smoke` for the fast subset — see `docs/TESTING.md` |
| Compile check: every script loads with the autoloads present | `godot --headless --path . res://tests/compile_all.tscn` |
| Regression & progression suite (scenarios A–F, integrity checks) | `godot --headless --path . res://tests/suite/suite.tscn -- full` |
| Unit and regression tests (383) | `godot --headless --path . res://tests/test_runner.tscn` |
| Rendered play-test: real main scene, synthetic input, screenshots in `user://playtest/` | `godot --path . res://tests/playtest.tscn -- full`, then `-- reload` in a new process to test save → restart → continue |

Other play-test phases are `smoke`, `stations`, `interiors`, `nav`, `minigames`, `craft`, `iter2`, `slice`, `village` (follow with `village_reload`) and, for iteration 009, `property`, `skilltree`, `checks`, `trade`, `interface`, `character`, `ironfront` and `village9`. On a machine with no display, wrap the play-tests in `xvfb-run -a -s "-screen 0 1920x1080x24"` and add `--rendering-driver opengl3`.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Move (Shift runs) |
| E / Space | Interact (also stops the skill-check needle) |
| Bottom toolbar | Inventory, Skill Tree (right-click: skill levels), Hirelings, Adventurers (right-click: Most Wanted), Commissions, Ledger, Crafting (equipment designer), Workshop (property), Map, Help |
| I | Inventory |
| H | Hirelings |
| K | Skill tree (U: skill levels) |
| T | Quick travel (radial map of destinations; time passes as if you walked) |
| Left click | Walk there / use an object / talk to a person (Settings → Click to move) |
| J | Adventurers |
| O | Commissions |
| B | The MOST WANTED board (also at the board in the inn) |
| P | Pause / resume time |
| − / + | Slow down / speed up time (×1, ×2, ×4, ×8) |
| L | Ledger and upgrades |
| Esc | Menu |
| F5 / F9 | Quick save / quick load |
| M | Map of Brindlewick |
| F1 | Help & searchable reference |
| F3 | Diagnostics overlay |
| F10 | Developer tools: time, any item, gold, skills, property, stations, skill tree, progression presets, trade, Ironfront |

## The first-day loop

The HUD objective guides you through it:

1. Talk to Borin.
2. Assign him to mining and send him to Ironroot Mine.
3. Choose the Iron Longsword recipe at the anvil.
4. Work the forge, anvil, quenching trough and grinding wheel using the circular skill checks.
5. Roll the dice (digital or physical).
6. Equip Mira before she leaves for the Barrow Fields.
7. Visit the Tipsy Wyvern next door.
8. Sleep, and watch the adventurers leave at dawn.
9. Open Borin's bag when he returns; it holds a legendary.
10. Save.

## Documentation

- [`docs/TECHNICAL.md`](docs/TECHNICAL.md): architecture, systems, data, saves, the asset/audio override system and tests.
- [`docs/GAMEPLAY.md`](docs/GAMEPLAY.md): what each system does, and what is simplified in this build.
- [`docs/PLAYGUIDE.md`](docs/PLAYGUIDE.md): how to play, including the iteration 009 route.
- [`docs/TESTING.md`](docs/TESTING.md): the permanent regression & progression suite and the rule for every iteration.
- [`docs/DANSK.md`](docs/DANSK.md): Danish summary (dansk resumé).

Every script starts with an English (EN) and Danish (DA) header comment.
