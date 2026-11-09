# Golden saves — authentic save files written by past releases

These files are **not hand-written**. Each one was produced by the *released code* of an earlier build, running
headless, playing a new game for about a month through that build's own systems, and saving through that build's
own `Saves.save`. They let `tests/suite/cases/t_saves.gd` prove that real old saves load, migrate to the current
schema (`SaveMigrations`, `Game.SAVE_VERSION`) and survive load → save → load unchanged.

**Never edit these files.** If a future release needs a new golden save, produce it the same way (below) and add a
row; do not regenerate the existing ones unless their release code is used again.

| File | Release (tag) | Commit | Schema | Game day | Gold | SHA-256 |
|---|---|---|---|---|---|---|
| `build-0.11.2.json` | build-0.11.2 (0.11) | `f723715` | 1 | 31 | 4055 | `ef111783d4faf4fe2072ff0c55bb41ffa00496a914ac98add12001c1e0cad5a1` |
| `build-0.12.4.json` | build-0.12.4 (0.12) | `2ffdaeb` | 1 | 31 | 4867 | `ed00dc3449ae5e153fdf10e2f2995e499f01888c210d10ec1b7c14dfee2d617c` |
| `build-0.13.5.json` | build-0.13.5 (0.13) | `3d82c93` | 1 | 31 | 4608 | `5f2883c18546d077ac874cbede20b691f22c9c34d1a68980fa77e2dfff67eda8` |
| `build-0.14.6.json` | build-0.14.6 (0.14) | `154d08a` | 1 | 32 | 4609 | `1e706fd6206511bf11611df9ed23812dc4060d0ebb7b48dec5d03a5b5489474d` |

- **Produced:** 9 November 2026 (each file's `meta.saved_at` records the moment), Milestone A1 "Protect the
  Foundation".
- **Engine:** Godot `4.3.stable.official.77dcf97d8`, headless, Linux.
- **Seed:** the driver calls `seed(20261109)` before `Game.new_game("journeyman")`.

## How they were made (reproducible)

1. Extract the release outside the repository: `git archive <commit> game | tar -x -C <scratch>/vXXXX`
   (no checkout, no change to this repository's history).
2. Copy the driver into the extracted tree as `golden_driver/driver.gd` with a one-node `driver.tscn`.
   The driver's source is kept here, verbatim, as [`golden_driver.gd.txt`](golden_driver.gd.txt) (renamed so it is
   never compiled into this project). It only calls the old release's public system functions; systems that a
   release does not have (apprentices before 0.13, contracts before 0.14) are skipped.
3. Run with the user data folder isolated (so no real save folder can be touched):
   `XDG_DATA_HOME=<scratch>/xdg_vXXXX godot --headless --path <scratch>/vXXXX/game --import`, then
   `... res://golden_driver/driver.tscn`. The driver sets `Saves.dir = "user://golden_saves/"`, plays, and calls
   `Saves.save("slot_1")`; the resulting `slot_1.json` was copied here unchanged.

### What the driver plays (30 days, hour by hour through `Game.advance_minutes(60)`)

- **08:00** — smelts iron ore into ingots at the crucible and forge when stock is low (`smelt_iron`); fulfils open
  commissions (from stock, or by forging a matching piece); forges one or two of the cheapest unlocked equipment
  recipes for the display (`for_sale`). Crafting goes through `Crafting.start` → `record_step` per station (check
  scores 72–96 %) → `Crafting.roll_dice` (the digital dice) → `Crafting.finish`.
- **Mondays** — idle hirelings (Borin) are sent mining (`Hire.send(id, "ironroot_mine")`), as in the soak test.
- **09:00–18:00** — the counter: arriving customers are seated (`Shop.mark_arrived`, what the world does when the
  figure reaches its seat); repairs are done (`Shop.do_repair`); browsing adventurers buy and equip display pieces
  they can afford (`Adv.purchase_check` → `Shop.sell_to`); others are politely dismissed.
- **19:00** — bags returned from hireling trips are unpacked into the stores.
- **22:00** — the smith sleeps (`Vitality.sleep(480)`; the hourly loop advances the clock).
- **Apprentices (0.13, 0.14)** — once teaching is unlocked (Smithing 6, or the first room next door bought with
  `Property.buy_unit("cobbler")` from day 10), an applicant is hired (`Apprentices.hire(0)`) and commissions and
  smelting are queued for them (`Apprentices.add_task`).
- **Contracts (0.14)** — no letter had arrived by day 8, so the driver asks the contracts system for the
  `drovers_kit` letter (`Contracts.make_offer`, the function the daily check uses) and accepts it; the Project Bench
  is bought and placed (`Property.buy_station`, `auto_place`, `commit`); the smith works two-hour blocks
  (`Contracts.work`) and delivers the order (`Contracts.deliver`).
- Adventurers, expeditions, companies, the village and the world simulation run on their own throughout.

### What each file contains

| Release | Driver summary |
|---|---|
| 0.11.2 | 106 pieces crafted (37 smelts), 4 sold over the counter, 6 commissions fulfilled, 102 repairs, 5 mining trips. |
| 0.12.4 | 100 crafted (35 smelts), 5 sold, 8 commissions, 98 repairs, 5 mining trips. Provenance and Lore present. |
| 0.13.5 | 107 crafted (37 smelts), 6 sold, 9 commissions, 92 repairs, 5 mining trips; cobbler room bought (day 10); apprentice Krag Drummond hired (day 11) with 2 queued tasks. |
| 0.14.6 | 130 crafted (44 smelts), 11 sold, 6 commissions, 90 repairs, 5 mining trips; apprentice Milo Wick hired (day 10) with 4 tasks; contract `ct_1` (drovers' kit) accepted day 6, 18 h worked, delivered day 16 (3 days late, outcome "good"); 25 finished expeditions. |

All four declare schema version 1 (`meta.version` and `data.version`): every release up to 0.14.6 wrote version 1.

### Notes

- 0.11.2's own code printed one runtime error during the run (`shop.gd:449`, `_add_customer`, an invalid key access
  while seating a customer). It is a bug in that release, not in the driver, and the save is as that release wrote
  it.
- All four saves contain uids that appear more than once (the same item referenced from several places, e.g.
  expedition records and live equipment). That is exactly the identity issue Milestone A1's identity work
  addresses; these files are its authentic "before" evidence and must not be "fixed" by hand.
