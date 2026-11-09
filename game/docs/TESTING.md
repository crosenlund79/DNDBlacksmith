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
| `t_tailoring` | Iteration 010 textiles: fibres spun and woven at the loom and sewn into a robe at the cutting table and tailor's bench (the robe lends magic, a warded cloak ward), tailoring nodes gate the recipes, weapon/armour variants differ (greatsword > shortsword attack, rapier faster, plate > chainmail > leather), save/load |
| `t_trade` | Import orders from deposit to delivery, ships visit and their schedule persists |
| `t_adventurers` | Durability falls in real fights (weapon, armour, shield, boots) and on the road, worn and broken gear lowers combat numbers and damage dealt, a missing slot is filled from the display, broken gear leads to a repair request or commission, a poor adventurer saves, class preferences read from item data, the companion slot strikes/guards/scouts/heals/carries, and the new state persists |

| `t_world` | Iteration 011 world: sites persist through save/load (old saves gain them lazily), a slain unique boss stays dead over many later expeditions and only a weaker, announced successor may move in, gathering depletes and regrows, growing threats raise danger, new sites are discovered by explorers, the delve map and rumours, gear lost in a wipe is found by a later party with its history unbroken (same uid, same maker), a weak party never picks the deadliest site and classes have their favourite places, and every site event is one Lore event placed there (read back as the site's history, the killer's and the weapon's) |

| `t_provenance` | Iteration 011 provenance: one uid through forging, sale, repair, reforging and save/load; the chain of owners begins at the anvil; the maker can never be overwritten; one Lore event referenced by item, adventurer and place (no duplicate lines in the story); inheritance without duplicates; a pawn round-trip; old-save migration from `crafted_by`/`owner`/`history` |
| `t_personality` | Iteration 011 equipment personalities: only a minority of pieces are candidates and ordinary ones never speak, a piece awakens after a real deed and stays awake through save/load, innate legendaries wake at the forge, the temperament follows its history deterministically, lines are filled from its real history, the same input gives the same line, per-item and global cooldowns prevent spam, mute silences it, workshop hooks (repair, sharpen, reforge, enchant) speak. Rendered: `playtest.tscn -- spirit11` |
| `t_world_remembers` | **End-to-end.** Forged → sold → expedition at a persistent site → its unique master slain with that blade (one Lore event shared by blade, slayer and site) → site cleared for good → blade named and Epic → owner dies → blade passes on → back for repair → recognised once → awakened blade speaks, cooldown and mute respected → everything (name, Epic, dead master, story, reunion, spirit) survives save/load |
| `t_itemstory` | Iteration 011 item stories: the maker never changes through enchanting, reforging, resale, repair and sharpening (another smith's piece keeps its own mark), a boss kill names the blade once (authored pattern, one `named` Lore event, persists through save/load, never re-rolled), survival and campaign names, Legendary vs Epic distinct and both possible, a reunion is acknowledged once per occasion (also after loading; a recovered chest counts), famous creations on the Hall of Fame with deeds and owner, rumours and a fame commission, reforging keeps uid/maker/name/Epic and adds history, a stranger brings a lost Ironhand blade from the circulating pool, talking to the owner about it. Rendered: `playtest.tscn -- story11` |
| `t_village10` | Every building has a non-solid sign clear of its doorway, the new venues (pawnshop, rival forge, the Hales, caravan camp, ceremony stage, graveyard plots) have their spots on the nav graph and their interactables, the caravan comes and goes, wander targets never fall inside a building, five simulated minutes of wandering never put an animal in a house or on a footprint, horses and cows stay in their paddocks |
| `t_apprentices` | Iteration 012 workshop apprentices (`Apprentices`): unlock gate and staff limit, signing fee, daily wages, unpaid wages → notice → leaving, dismissal (refused mid-operation); eligibility by rank, skill, discipline training and the smith's own unlocks; queue priorities, automatic and pinned assignment; materials taken at start and returned exactly on cancel/dismissal, repeat counts; one worker per station and the smith's priority; a station removed mid-task blocks it; wear and automatic upkeep; 5-minute ticks vs one long advance give identical results; quality novice < master ≤ 112% < the smith's exceptional work, rarity possible; mistakes proportionate (one cheap unit at most); rank-up, specialty, mentoring once a day; the apprentice as maker (mark, workshop, supervisor) through reforge, sale, repair and save/load; Epic/Hall of Fame and naming for workshop work; the maker recognises a returning piece once; customer repair; commission fulfilment; independence (bless → alumni whose own pieces reach adventurers, stay → raise); save/load mid-work; old saves. `t_progression` notes when apprentices unlock in the planner's career |
| `t_workshop_ui` | Iteration 012 apprentice presentation: the Workshop Ledger (Y) builds with 0, 1 and 3 apprentices and fits 1920×1080 (cards, queue rows, Bottlenecks, add-work for every kind), the notice board's Workshop apprentices tab hires through the engine and shows the engine's reason when full, the talk panel teaches for an hour and answers an independence notice with a farewell, the miniatures follow the shift (in at 8, break at noon, gone after 18) and stand on clear floor beside their station (outside its footprint, inside a smithy room) with a ring and an explaining prompt, plain activity bubbles, the apprentice maker line in tooltip and inspection with the punch-mark icon, the dev shortcuts, and save/load with actors shown. Rendered: `playtest.tscn -- workshop12` |
| `t_refine` | UX iteration equipment refinement (`Refinement`): refine raises craftsmanship (ceiling = original +15, capped by skill; diminishing returns) and stats follow; the per-piece budget (refine 3, rework 2, upgrade 1) refuses more without spending materials; a slip costs at most 3 points and a little wear, never the piece or the budget; rework re-rolls one affix or the main stat within its legal range (d20 1 → bottom, 20 → top), rarity/affixes/name unchanged; upgrade iron → steel needs the know-how, scales by the material ratio, never past a fresh steel piece, one step only; a failed upgrade spends only the material; reforge keeps its old entry point and history line in the shared event format; identity through seven improvements and save/load (uid, maker, mark, day, name, earned name, rarity, Epic, owners, every earlier event + one new event each, spirit awake); 30 reforges keep the forging event; an apprentice's piece keeps its maker; an old piece without a record. Rendered: `playtest.tscn -- refine_ux` |
| `t_devtools` | The F10 developer catalogue (`DevTools`): search by name/id/type and kind filter, spawn equipment with quantity/rarity/craftsmanship (valid uids, maker "Developer tools", no mark, held by the smith, marked `dev`), developer stacks kept apart, money in the ledger as "Developer tools"; developer pieces earn nothing (Epic, names, Hall of Fame, famous creations, skill-tree items seen, dragon lore / mithril flags, encyclopedia, objectives, apprentices' fame). Rendered: `playtest.tscn -- refine_ux` |

| `t_venues` | UX iteration (world): `Venues` is the one source of opening hours — every keeper stands at the counter exactly in opening hours (sampled each hour; Aldric away on delivery days), open/closed/away status text, the map card (categories from real stock, purchasing counter or not, travel id) and `MapPanel {"venue": id}`, who sells what (`Venues.selling`), Pell's Provisions sells at the data price, caps at what is left, sells out, restocks next morning and survives save/load (old saves gain it lazily), a closed counter does not open its screen, every venue with a counter has a quick-travel destination with an honest line, and the prompts for a station, a shop (open/closed) and a person (available actions; greyed ones with a reason). Rendered: `playtest.tscn -- world_ux` |

| `t_guide` | UX iteration guidance (`Guide`, `Knowledge`): Raw Hide → Cured Leather → Iron Longsword fully explained (tree with intermediates and the missing Leather Vat, readiness states, the next step changing from "buy at Pell's, open now" to "opens tomorrow" to "set up the vat" to "cure leather now" to "begin the sword"), every listed source is real (herbalist, docked ship, import, crafting, trade run, expedition; Pell's purchasing when present), every recipe input has a source, secrecy (forgotten recipes, gated routes, exotic imports stay hidden until earned), bought hints persist through save/load and show in Help › Knowledge & Notes, have/obtainable/locked/unavailable, recursion terminates for every recipe, old saves. Rendered: `playtest.tscn -- guide_ux` |
| `t_living` | The Living Realm 3a, living adventurers (`Living`, `Companies`): the same world seed reproduces the same roster, friendships and companies (different seeds differ; ten seeds stay within level 1–5, purse 20–260, gear 35–80; the eight established adventurers keep class, level and Mira's day-3 errand); goals change behaviour (a wealth-seeker takes more risk and picks more dangerous places, a gear-seeker pays for an upgrade a wealth-seeker calls overpriced; an achieved goal is one Lore event and is replaced); friendships from shared roads and rescues, rivalries from competing for glory (rival goal; rivals not invited), grief; retirement (gear to a friend with its owner chain, the smith's work offered back, stays or leaves) and a newcomer, one Lore event each; companies set out together, strike off the fallen, recruit, split over a quarrel, disband after a losing streak (reason kept, one Lore event), friends found new ones; 30 days of companies on the road; save/load and an old save (lazy goals/bonds, a world seed, reserves queue, companies form gradually); a 90-day soak (healthy roster, timings) and 20 identical days from the same seed. Rendered: `playtest.tscn -- living_rl` |

| `t_smithy` | The Living Realm 2a, the evolving smithy (`Smithy`, `Property` floors & lift): every workshop room has a craft and a banner, auto-placement keeps a craft together (a full leather room sends the loom up to the weaving loft); room tiers follow real progress (new game Modest; skill + stations → Established; + renown → Masterwork) and the tier dressing never touches a station, a doorway, the stair or the hoist while every station stays reachable on foot; the Loft only after Ilse's room and the West Garret only next to it; stations craft upstairs and persist; the aetheric lift (needs the Loft and an Arcane Foundry) and the stair move the smith between floors in one step, and click-walks plan through them; an apprentice works at the anvil upstairs (reachable working side, task done); "Walk to the …" and "Craft again"; old saves (before the Loft: gain its rooms unowned; before property: never own it); every station reachable in the fully bought building, and the capacity report per craft. Rendered: `playtest.tscn -- smithy_rl` |

| `t_consult` | The Living Realm 3b, adventurer consultations (`Consult`): adventurers come to the counter for equipment advice in credible moments (a defeat or wound, broken or worn gear, a destination whose threats their kit handles badly, a gear goal), rate-limited (10–17 only, one approach every few days in the village, a per-adventurer cooldown; skippable, no penalty for ignoring); recommendations built from real gear and threat data (durability, weak-to/resists, danger against their strength, display stock, coatings in the stores, commissions, safer known sites, rest, the Salt Anvil); persuasion odds move with skill, relationship, reputation, credibility, purse and temper; seeded refusals in their own voice; accepted advice changes the purchase, repair, commission, coating, destination or departure; credibility and the relationship after the next expedition, one Lore event for notable cases; save/load and an old save. Rendered: `playtest.tscn -- consult_rl` |

| `t_sponsor` | The Living Realm 4, sponsored expeditions (`Sponsor`): objectives come from real site data (loot tables of the site's places, lost equipment by uid, relics, salvage, discovery beyond the site), every objective node is reachable; acceptance depends on danger against strength, pay, goals (a coin-seeker asks more), the smith's friendship and name, gear (a broken blade must be mended first); refusal with a reason, counter-offers (higher fee/share, or a safer site with the same material), two counter rounds then a last word; gold moves once (escrow until the 08:00 departure, full refund on cancel or a failed departure, nothing on refusal); the party runs as an ordinary Expeditions party heading for the objective's node over real game time and the outcome follows what happened (success, partial, failure when picked bare, a wipe is a loss), bonus by outcome, the party's share; delivered items arrive once on the returns shelf (recovered lost gear keeps uid, maker and history, last hand-over "recovered"); a discovery reveals the site through the existing hook; one `sponsored` Lore event per sponsorship; companies; save/load mid-expedition; old saves. Rendered: `playtest.tscn -- sponsor_rl` |
| `t_integrity` | Broken references (recipes, stations, loot, ships, tree), tree shape (unique ids, prerequisites exist, no cycles, every recipe and station learned from exactly one node, every station purchasable, every required knowledge findable), every required material has a source, every room can eventually be bought and the whole building is reachable, commissions never ask for more than a craftable piece can give |

## Packaged-build check

`EmberAndAsh.exe --headless -- --smoke-test` (or `godot --path game -- --smoke-test`) starts a new game, runs the
world, and writes `SMOKE OK|FAIL …` (data counts, missing sprites, UI, logged errors) to stdout and
`user://smoke_test.txt`, exiting 0 on success. The installer workflow runs it on the exported Linux build and on the
installed Windows build before publishing a release.

## Bugs the suite has already caught (kept as regressions)

- Every station fitted into the starting rooms, so the workshop never needed to grow. Stations now stand only in
  workshop rooms, each with a capacity (`t_progression` shows the rooms bought).
- Belt commissions could ask for protection 14 when the best belt reaches 9 (`t_integrity.commissions_possible`).
- The Arcane Foundry upgrade could only be bought through the UI; `Shop.buy_upgrade()` is now shared.
- (iteration 010) The unit tests were unseeded and failed now and then; `test_runner` now seeds its RNG.
- (iteration 010) A Journeyman loss "found dead" by an Apprentice search party broke the Apprentice no-death rule check:
  the test helper that brings everyone home now clears stale missing records.
- (iteration 010) The Hall of Fame board was rejected as clashing with the wall: furniture clash checks now account
  for quarter-turn rotation.

## Every future iteration

1. Run the baseline suite (`./run_tests.sh`) before changing anything, and note the result.
2. Implement the new work.
3. Extend the suite for the new mechanics: a case in `tests/suite/cases/`, fixtures in `SuiteCase` if reusable,
   and add the new content to `t_integrity` and `t_progression` where it belongs to progression.
4. Rerun the baseline and the progression scenarios.
5. Fix newly introduced regressions — and add a test for every significant bug fixed.
6. Report the remaining failures honestly, with their diagnostics.

Keep the suite practical: tests that guarantee real gameplay, not test counts.
