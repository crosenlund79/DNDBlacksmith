# The Living Realm — roadmap status

What is implemented, tested and released, and what remains. Nothing below is marked done without code, tests and
rendered checks.

| # | Roadmap phase | Status | Evidence |
|---|---|---|---|
| 1 | Verify and playtest Windows 0.13 | **Done** | Release build-0.13.5 from `3d82c93`: CI silent install + launch "SMOKE OK"; rendered regression 37/37 on that commit |
| 2 | Evolving Smithy & equipment presentation | **Done** | `smithy.gd`, Loft floor + lift, room crafts/tiers, walk-to/craft-again (`t_smithy`, `smithy_rl`); humanoid `EquipmentSheet`, cloak slot + migration, soft terrain (`t_equipment_ui`, `equip_rl`) |
| 3 | Living adventurers, persistent parties, consultations | **Done** | `living.gd` (seeded rosters, goals, bonds, retirement, newcomers), `companies.gd` (`t_living`, 90-day soak, `living_rl`); `consult.gd` (`t_consult`, `consult_rl`) |
| 4 | Sponsored expeditions | **Done** | `sponsor.gd` in the dispatch panel and the Expeditions engine (`t_sponsor`, `sponsor_rl`) |
| 5 | Major commissions & integrated workshop production | **Done** | `contracts.gd`, Project Bench, patrons to the Crown, apprentice contract hours (`t_contracts`, `contracts_rl`) |
| 6 | Equipment affixes & deeper item legacy | **Not started** | Existing rarity/affixes/refinement/provenance remain; no new affix work yet |
| 7 | Autonomous civilizations, allegiance, world influence | **Not started** | — |
| 8 | Authored storylines & the regional conflict prototype | **Not started** | — |
| 9 | Campaign variation, chronicles, interconnected consequences | **Partly prepared** | World seed and seeded rosters exist (phase 3); no chronicle/comparison work yet |
| 10 | Broader overarching conflict | **Not started** | Must follow a successful regional prototype (phase 8) |

Outstanding quality items (section 18): workshop capacity vs stations — **fixed** (73 places for 29 stations);
cloak slots — **fixed**; hard-edged terrain — **improved**; material acquisition clarity — **fixed** in the UX iteration;
caravan curiosities and underwhelming advanced customer requests — **not yet addressed**.
