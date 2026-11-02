# Ember & Ash — vertical-slice candidate: report

Roadmap iterations 003–008 are built on top of iterations 001–002 (interiors, crafting, minigames, hirelings, waiting area, tabletop figures). This is a **vertical-slice candidate** for extensive playtesting. The required systems work together in a running Godot 4.3 session, but balance is still provisional.

## Content at a glance

| Content | Amount |
|---|---|
| Crafting stations | 26 (all 5 disciplines + the anvil), every one used by at least one recipe |
| Recipes | 33 (smithing 14, leather & stitching 8, alchemy 4, arcane 4, runecraft 3), several multi-discipline |
| Item definitions | 75 (23 materials, including gems, rare minerals and adamantine; 8 relics, including 3 that need identification and a forgotten-recipe scroll) |
| Regions | 5 (Ironroot Mine, Whisperwood, Highmarsh Road, Barrow Fields, Deep Ironroot), each with its own threats, weaknesses and resistances |
| Recurring adventurers | 8, with family ties in the village |
| Villagers | 8 |
| Hireling slots | 3, with weekly applicants |
| Romance | 4 romanceable adventurers, each with personal beats and a full path to marriage |

## What works (verified)

| Iteration | What works | Evidence |
|---|---|---|
| **003 Materials, relics & discovery** | The full material cycle: expedition → bag → progressive reveal → study, smelt or process → craft → sell or equip. Gems and rare minerals depend on region and finder skill. Scouting knowledge lowers danger for everyone and reveals suppliers. Trade runs buy materials with a purse and sell marked trade goods. Unidentified relics turn into ancient arms, components or forgotten recipes. Skilled hirelings brew draughts and oils and prepare runestones from stored materials. | Unit tests; rendered `slice` phase (Borin's bag revealed, a relic studied into a Starstone) |
| **004 The adventurers' world** | Expeditions are fought encounter by encounter. Attack, fire/frost/magic against weaknesses, protection, ward, carried draughts and applied coatings each change fights. Logs credit the gear that mattered. Adventurers have traits, plan their next trip, place orders for its threats (fire for the barrows, steel or better for veterans), buy draughts before leaving, and wear down their gear. The overview shows more the better you know them. | A forged flame blade lifts a rogue's Barrow Fields success from **13% to 90%** (Monte Carlo); in the rendered slice, Garrick buys the Emberwarden at the counter, departs, and the log credits it |
| **005 The village remembers** | Reputation; customer budgets and wants; villagers buying goods; daily upkeep; stock laid out on the display table; disputes (refund or refuse); hostile people refusing to buy or commission; friends sharing road knowledge; devoted friends bringing relics; eggs on the shopfront; family ripple; the grocer and Mira chain. | Tests: helping Mira warms Aldric's deliveries; refusing Kestra sours her and her brother, ends trade, moves reputation, the shop gets egged, and all of it persists |
| **006 A life beyond the anvil** | Table talk drawn from real events; knucklebones with the real dice; personal romance beats; a complete path to marriage; married life (free gear, shared spoils, her greetings, her family's warmth, widowhood if she falls). | Full acquaintance-to-marriage progression in tests; table talk in the rendered slice |
| **007 Masters of the forge** | Jewellery with gem properties; frost coating and equipment treatments; ranger's boots (speed); embroidered hood (ward); the adamantine chain with **bound magic** distinct from runes, plus a violet glow; the four-discipline **Emberwarden**; the forgotten **Starsteel** recipe; hirelings on shift assisting at the bench; repairs of adventurers' own gear. | Tests; the Emberwarden forged legendary through the minigames in the rendered slice and deciding the next expedition |
| **008 Integration** | Developer Tools (F10, separate from normal play); a 28-day soak with careers developing, injuries but no wipe-out, scouting growing and hirelings levelling; the full rendered loop, save, close, Continue, everything intact. | `soak.tscn`; `slice` + `slice_reload` phases, 0 failures |

## Tests

| Suite | Coverage | Result |
|---|---|---|
| `tests/test_runner.tscn` | 108 headless checks, one block per milestone plus regressions | All pass |
| `tests/playtest.tscn` | Rendered phases: earlier iterations plus `slice` and `slice_reload` for this one | 0 failures on the last run of each phase |
| `tests/soak.tscn` | Four simulated weeks | Completes; no adventurer deaths in the sample month (deaths do occur in deeper regions, see tests) |

## What remains shallow

- **Balance is provisional.** Prices, upkeep and wages can push a passive player into debt; there is no hard gold floor. Expedition difficulty was tuned once against a soak run. The minigames and rarity thresholds have not been tuned with human players.
- **Romance content** is a handful of beats per character, not a deep branching story. Married life is a few greeting lines plus the economic effects.
- **Customers and families:** customer preferences are a want and a budget. Families ripple through the relationship memory rather than through bespoke scenes for each family.
- **Hirelings** work from their time allocation and do not craft whole recipes at stations themselves; they assist the smith instead.
- **Trade runs** buy a random mix from known suppliers when no wish list is given. The interface offers only a purse size.
- **Relic identification** uses the circular precision ring at the cleansing basin, not a bespoke minigame.
- **Animals** wander straight lines in a home range. Point lights pass through walls, so the forge glow shows on the roof.

## What is deferred

- Hirelings crafting full recipes at stations.
- Equipment management screens for adventurers and hirelings beyond giving gear from the stores.
- Tactical or visual expedition scenes. Expeditions remain simulations with written logs, by design.
- Seasonal or regional events, more regions, and more recurring characters.
- A deeper economy: supply and demand, competing smiths.
- Localisation of the new text. `DANSK.md` covers the earlier build only.

## Where to start

Read [PLAYGUIDE.md](PLAYGUIDE.md) for the loop, and use Developer Tools (F10) to reach any part quickly. Screenshots of this iteration are in `docs/screenshots/vertical_slice/`.
