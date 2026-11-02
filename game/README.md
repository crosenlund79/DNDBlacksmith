# Ember & Ash — first playable build

A straight top-down 2D fantasy blacksmith RPG and village-life simulation for **Godot 4.3+** (GDScript, GL Compatibility renderer).

You are Brannoc Ironhand, an aging, heavyset former adventurer who runs the forge in the village of Brindlewick. You craft equipment, employ hands, send them on expeditions, sell to and arm the adventurers at the neighbouring inn, and live with the consequences.

**Art direction:** `docs/visual_exploration/ink_parchment_gothic_80_20/` (80% Ink & Parchment, 20% Gothic Noir).

## Launching

You need Godot 4.3 or newer (the standard build, not .NET).

| Platform | How |
|---|---|
| **Windows** | Put `Godot_v4.x-stable_win64.exe` in this `game/` folder, or set the `GODOT` environment variable, then double-click **`run_windows.bat`**. The first run imports assets, which takes about a minute. |
| Windows tests | `run_tests_windows.bat` (exit code 0 means all passed; the report is written to `%APPDATA%\Godot\app_userdata\Ember & Ash\logs\test_report.txt`) |
| Linux / macOS | `GODOT=/path/to/godot ./run_linux.sh` (add `--tests` to run the test suite) |
| Editor | Open `game/project.godot` in the Godot editor and press F5 |

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Move (Shift runs) |
| E / Space | Interact (also stops the skill-check needle) |
| I | Inventory |
| H | Hirelings |
| K | Skills |
| J | Adventurers |
| O | Commissions |
| L | Ledger and upgrades |
| Esc | Menu |
| F5 / F9 | Quick save / quick load |
| F3 | Diagnostics overlay |

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
- [`docs/DANSK.md`](docs/DANSK.md): Danish summary (dansk resumé).

Every script starts with an English (EN) and Danish (DA) header comment.
