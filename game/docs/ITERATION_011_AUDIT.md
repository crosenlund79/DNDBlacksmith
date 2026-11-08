# Iteration 011 — "The World Remembers": audit

Each requirement of the brief is marked **implemented**, **partial** or **missing**, with the code and test evidence.
Suite = `tests/suite/suite.tscn` (89 cases); rendered = `tests/playtest.tscn -- <phase>` (33 phases).

## Parallel work merged

| Worker branch | Merged | Conflicts resolved |
|---|---|---|
| Equipment personalities (`personality.gd`, `spirit_voice.gd`, `data/personalities.json`) | yes | — |
| Persistent world (`world_sites.gd`, `world_map_panel.gd`, three new regions) | yes | `_boss_down`: the kill is written once by `WorldSites.on_boss_down` |
| Item stories (`item_story.gd`, `item_panel.gd`, `familiar_card.gd`, `workshop_services.gd`, mark art) | yes | `_boss_down` calls `ItemStory.on_boss_kill` after the world record; Epic is one Lore event plus `ItemStory.on_epic`; repairs call both the voice and the story hooks |

## Requirements

| # | Requirement | Status | Code | Tests |
|---|---|---|---|---|
| 1 | Persistent, discoverable sites (forest, mines, road, barrows, deep halls, bandit stronghold, temple, crag) with state: name, description, region, danger, discoveries, resources, inhabitants, threats, events, changes | implemented | `world_sites.gd` (`site`, `conditions`, `inhabitants`, `finds`, `events`), `extra_world011.py` | `t_world.sites_persist`, `discovery_of_new_site`; rendered `world11` |
| 2 | Defeated unique enemies never respawn; at most a weaker successor | implemented | `WorldSites.on_boss_down`, `_successor_arrives`, `enemies_at` | `t_world.unique_boss_stays_dead`, `t_world_remembers` |
| 3 | Resources deplete and regrow | implemented | `WorldSites.take`, `daily` | `t_world.depletion_and_regrowth` |
| 4 | Parchment world map | implemented | `world_map_panel.gd` (G, or right-click Map) | rendered `world11` (`w11_world_map.jpg`) |
| 5 | Adventurers choose destinations by themselves | implemented | `WorldSites.appeal`, `capable` | `t_world.destination_respects_capability` |
| 6 | Every item keeps a stable identity: uid, maker, date and place, mark, materials, quality, rarity, owners, workshop work, battles, names, Epic, loss and destruction | implemented | `provenance.gd` | `t_provenance.identity_through_life`, `t_itemstory.maker_never_changes` |
| 7 | One shared event system with no duplicates or contradictions; light records for routine items, rich for exceptional ones | implemented | `lore.gd` (one event, ids in item, adventurer and place; pruning keeps referenced and important events) | `t_provenance.one_record_per_event`, `t_world.lore_events_carry_the_place` |
| 8 | Histories survive trade, loot, inheritance, resale, death, recovery, pawning and save/load | implemented | `Provenance.transfer` at every hand-over; `Adv.bequeath` | `t_provenance` (inheritance, pawn), `t_world.lost_gear_recovered`, `t_world_remembers` |
| 9 | Item-history view with icons and links | implemented | `item_panel.gd` (Overview / History / Owners; links to adventurers and to the site on the world map) | rendered `story11` (`story11_item_history.jpg`) |
| 10 | Maker's mark on every crafted piece, visible in inspection and history; other smiths' marks; the creator never changes; the smith recognises their own work | implemented | `Provenance.MARKS`, `set_maker` (fixed once), `marks/template_*`, tooltip line | `t_itemstory.maker_never_changes`, `t_provenance` |
| 11 | Named equipment earned through history; Legendary = rarity, Epic = earned, both possible; names persist; Hall of Fame; rumours, village reactions, commissions | implemented | `ItemStory.on_boss_kill` / `check_names` / `famous_creations` / `rumour_line` / `fame_commission`, `Recognition.grant_epic` | `t_itemstory` (naming, Legendary vs Epic, famous creations and commission) |
| 12 | "A Familiar Creation": recognised once per significant reunion; contextual dialogue; workshop work recorded; surprising histories through customers | implemented | `ItemStory.recognise`, `familiar_card.gd`, `talk_options`, `stranger_visit`, `workshop_services.gd` | `t_itemstory.reunion_once_per_occasion`, stranger test; rendered `story11` |
| 13 | Personalities: uncommon, woken by events, authored lines tied to real history, cooldowns, mute, optional sound, deterministic, no AI service | implemented | `personality.gd` (30% of candidates, per-item 240 min and global 90 min cooldowns, `rare` setting, uid-seeded choice), `data/personalities.json`, `sfx/spirit_whisper` | `t_personality` (10 tests); rendered `spirit11` |
| 14 | End to end: craft → sell → expedition → unique kill → site change and XP → name and Epic → owner dies → passes on → back for repair → recognised → speaks; persists after reload | implemented | — | **`t_world_remembers.craft_to_reunion` (28 checks)** |
| 15 | Presentation: world map, inspection, sheet histories, Hall of Fame, journal and notifications, workshop dialogue; controls kept; `template_` art only | implemented | panels above; new art limited to `marks/template_*` and `ui/template_story_*` | rendered `world11`, `story11`, `spirit11` |
| 16 | Tests: identity, maker, no duplicates, world persistence, unique enemies, rarity vs Epic, naming and Hall of Fame, reunions without repeats, personality frequency, context, cooldowns and mute, save migration, deterministic end-to-end | implemented | `t_provenance`, `t_world`, `t_itemstory`, `t_personality`, `t_world_remembers` | 89/89 |
| 17 | Saves remain compatible | implemented | lazy migration: `Provenance._migrate` (from `crafted_by`, `owner`, `history`), `WorldSites.site`, `Lore.st`, `ItemStory.st` | `t_provenance.old_save_migration`; `t_world.sites_persist` (old saves) |
| 18 | Windows installer built, installed, launched and published | implemented | `.github/workflows/windows-installer.yml` | CI: silent install + `--smoke-test` → `SMOKE OK … log_errors=0` |

## Omissions found and fixed during the audit

- Links from an item's history to a place opened the world map without selecting the site: the panel reads `site`, the link sent `id`.
- A newly forged piece's chain of owners began with "held, day 0" instead of "forged".
- `WorldSites.on_boss_down` read a missing node id when an encounter has no map node (script error).
- After the merge, a repeated great deed is recorded as kind `deed`. The story icon, the item summary and the personality "significant event" list now treat it like `epic`.
- The `hire10` rendered phase could fail when the day's schedule put the priest next to the grave; the test now steps round to another side, as a player would.
- Developer tools (F10): open the world map, a stranger's old blade, wake a weapon.

## Results

- Compile check: 154 scripts, 0 failed.
- Suite: 89 passed, 0 failed.
- Unit and regression tests: 383 passed, 0 failed.
- Rendered regression: 33/33 phases with 0 failures. 32 passed on the first run; `hire10` was fixed and rerun alone. `story11` and `spirit11` were rerun after the last fix.
- Screenshots: `docs/screenshots/iteration_011/`.

## Known limitations

- The wilderness cannot be played on foot; sites are visited by adventurers and seen through the map and the expedition observer.
- Routine (importance 0) events that no item still lists are pruned after 4,000 events. An adventurer's history then skips them silently.
- Chronicle entries written before this iteration are not converted into Lore events. An old item's legacy notes appear in its story as plain notes.
- Epic distinction is reserved for the smith's own work. Names can also be earned by rare or better pieces made by others.
- Item voices use one synthesised whisper sound and authored English lines only.
