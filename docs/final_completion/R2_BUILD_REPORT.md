# R2 "Truthful World Model" — build report

*What R2 delivered, how it was verified, and what is still open.*
Roadmap: [`FINAL_DEVELOPMENT_ROADMAP.md`](FINAL_DEVELOPMENT_ROADMAP.md) §R2 · previous build: [`R1_BUILD_REPORT.md`](R1_BUILD_REPORT.md).

- **Branch:** `claude/r2-truthful-world`, from R1's verified head `a6ecaf9` (`claude/r1-integration`).
- **Recovery point:** `backup/pre-r2-20261117` (= `a6ecaf9`, pushed).
- **Final commit:** see §6.
- **Classification:** ALIGNED. R2 is roadmap R2 / canonical Gate A entry points (CV §12.2 A, §12.3 "Before G/H",
  §11 honest information, §1.2 "inventories … reflect simulation state"). It adds no new gameplay or content, and no
  balance change except where a rule was untruthful (§3). Decision D-7 is applied as data dimensions only.
- **Not done, by instruction:** no merge, no publication, no tag, no change to the default branch. R3 was not started.

## 1. Decision applied

| Decision | Applied as |
|---|---|
| **D-7** approved (data dimensions only) | Audiences `villagers`, `adventurers`, `traders`, `artisans` (artisans and dwarves), `nobility`, and one `civ:<id>` per civilization. Places `village`, `region`, and one `civ:<id>` per civilization. The data lives in `Game.state.reputation.word[audience][place]`. No civilization exists, so the civ lists are empty (`Reputation.civilizations()` reads a `civilizations` data table that does not exist yet). There is no spreading: every change lands on every audience in the village, exactly as the old single number did. The region hears nothing yet (R8). Reeve Tamsin Hale is untouched. |

## 2. Delivered

| Requirement | What | Code | Tests |
|---|---|---|---|
| **1. Unified danger** (TECH-018, ADV-021, ADV-017, WLD-018) | `Danger` is the one model. `site(rid)` is the live strength (the strongest group of foes really there, `WorldSites.enemies_at`); also `ratio(rid, strength)`, `word`, `threats` (the foes really there, with weaknesses), `knowledge` (scouting 0–1), `ambush_dc` (12, +2 at a lair, up to −3 on charted ground) and `trip(dest)` (a hireling's danger on destinations.json's scale × the place's live strength against its start × (1 − 0.3 × knowledge)). **Callers:** party choice, the ambush check in fights, consultations, sponsorship, hirelings, the legacy resolver, the world map, the consult and sponsor panels. `Regions.danger` and `WorldSites.danger`/`danger_word` delegate. | `danger.gd` (new); `regions.gd`, `world_sites.gd`, `expeditions.gd`, `hirelings.gd`, `adventurers.gd`, `consult.gd`, `sponsor.gd`, UI panels | `t_r2_truth` ×5 (static scan of every script; old model reproduced on an unchanged place; live state moves the trip danger; scouting lowers the ambush DC; consultation threats are the foes fought) |
| **2. Reputation foundation** (TECH-019, WLD-013, WLD-011 data model, WLD-014 part) | `Reputation` provides `standing()` (the old `Shop.reputation`, same formula), `standing_of(audience, place)`, `word`, `change`, `word_text` and `migrate`. Every reader and writer in systems and UI calls it. `Shop.reputation`/`rep_change`/`reputation_word` remain only as delegating names, and a static scan forbids calling them. **Save schema 10** moves `world.rep` into the village cells: idempotent, standing unchanged. | `reputation.gd` (new); `save_migrations.gd` step 10; `game.gd` `SAVE_VERSION := 10`; ~15 call sites | `t_r2_truth` ×2; `t_saves`: all 8 golden saves keep the standing exactly; `t_lw_acceptance` step list |
| **3. Truthful characters** (ADV-012, ADV-018, TECH-021) | `Adv.current_plan(a)`: a forming party's committed destination ("bound for X (your sponsorship)"), otherwise the planner's own answer for their company today (`Expeditions.choose_destination(members, true)`: no dice, no side effects). It is shown in the dossier ("as things stand they lean towards X"), dialogue and rumours, and used for consultations. The strength word uses `Expeditions.power`, the formula decisions use; its bands were quantile-matched to the old words over 220 snapshots (correlation 0.95). **A consultation never redirects a sponsored party:** no "safer place" advice, and applying it is refused with the reason. | `adventurers.gd`, `expeditions.gd`, `consult.gd`, `dossier_panel.gd`, `talk.gd` | `t_r2_truth` ×6; `t_consult` |
| **4. Honest rumours** (LORE-015, WLD-019) | A paid rumour words a real fact (`Talk.rumour_facts`): a plan, a worn piece, a full purse after a recent success, an adventurer away, an injury, or recent Lore of importance ≥ 2. With nothing true to tell, the rumour-seller says so. Table talk names the place a fallen adventurer really died (`died_where`; older deaths say "The road"). | `talk.gd`, `data/dialogue.json` "rumours", `inn.gd`, `expeditions.gd`, `adventurers.gd` | `t_r2_truth` ×2 |
| **5. Real possessions** (ECO-045, BUG-046, BUG-047) | `Sim.gift_of`: an adventurer gives a piece of their own loot (taken from the pack) or coin from their own purse (paid on the ledger), still within the A2 gift cap. A shopkeeper (Aldric, the herbalist) gives a unit off their own shelf (stock decremented). Anyone else gives nothing. The commission reward package and the gratitude relic follow the same rule (the relic must really be carried). A multi-request's repair part is a real worn spare in the adventurer's pack (`Shop.worn_spare`, `loot_uid`); with none, no repair part is offered. Pawn-house stock reads "Bought in by Silas Quell for the house shelf", with no invented pledge. | `sim.gd`, `shop.gd`, `commerce.gd`, `payments.gd` | `t_r2_truth` ×4; `t_economy_a2` gift cap; `t_recognition` (real spare); `t_s2_econdev` ledger conservation |
| **6. Shared valuation** (TECH-030 part) | `Valuation` provides `value`, `unit_value`, `catalogue`, `smith_buys_factor`/`buyers_factor` (the factor that was written out twice, verbatim, in `Trade` and `Commerce`), `merchant_price` (guide, caravan, imports, ship stock, steward) and `counter_price`/`material_cost`/`design_material_cost`. That last group is **one material-cost rule:** the steward and its working smith used the village counter's price, the Workshop Ledger the bare catalogue value; the Ledger now shows what the steward plans with. | `valuation.gd` (new); `trade.gd`, `commerce.gd`, `guide.gd`, `steward.gd`, `steward_smith.gd`, `apprentices.gd`, `shop.gd` | `t_r2_truth` ×2 |
| **7. Accurate presentation** (EQ-053) | `Items.STATS_IN_PLAY` (attack, protection, magic, fire, frost, ward, heal; vitality on amulets) and `stat_in_play`. Tooltips and the craft result label stats and affixes that have no effect in play ("no effect in play yet"). The equipment sheet's columns, totals, key stats and compare view leave them out. | `items.gd`, `craft_result_panel.gd`, `equipment_sheet.gd` | `t_r2_truth` ×1 |

**New test tools:**
- `t_r2_truth`: 21 tests.
- `tests/world_probe.tscn -- [days] [seed] [steward|idle]`: a deterministic 90-day world fingerprint, about 11 s per run.

## 3. Intentional behaviour differences

R2 changes behaviour only where an old rule stated or used something untrue:

1. **Scouting reaches the parties.** Before R2, "told you the safe paths" lowered only hirelings' danger. Now a well-charted place also lowers the party scout's ambush DC (up to −3). An ablation (this effect off, 20 seeds) showed no measurable effect on deaths.
2. **Hireling trip danger follows the place.** On an unchanged place it equals the old figure exactly (tested). A place with its master slain is safer; one with growing threats is more dangerous (within 0.5–2×).
3. **Gifts cost the giver.** Coin gifts leave the giver's purse and are paid on the ledger; item gifts leave their pack or shelf. Adventurers end 90 days with 11% less gold on average (t = −1.54, not significant). The A2 cap is unchanged.
4. **No conjured spare parts.** An adventurer with no worn spare brings no repair part.
5. **Display only:**
   - the strength word (new bands, the decision formula);
   - the Ledger's material cost (counter prices);
   - stats with no effect are labelled or left out of totals;
   - rumours and plans as above.

**Not changed:**
- **The adventurer's own wish** (`next_dest`): a story plan such as Mira's Barrow Fields, or a pick by level, with a +6 pull on the planner when they lead. An R2 draft made this wish mirror the planner's preview. The 20-seed comparison then showed fewer deaths (3.35 → 2.10, t = −2.05). An ablation ruled out the scouting change, and the cause was the lost pull, so the pre-R2 rule was restored. The sheets show the planner's real answer, which includes that pull ("as Garrick had planned").
- **The wish list's weakness rule** (destinations.json). See §7 item 1.

## 4. Seeded comparisons (90 days, steward)

The comparison is 20 seeds (101–120), pre-R2 tree (`a6ecaf9` + the probe) against R2's final code, mean ± sd:

| Metric | Pre-R2 | R2 | Δ | t |
|---|---|---|---|---|
| Smith's gold | 13,717 ± 918 | 13,882 ± 1,430 | +1.2 % | 0.43 |
| Reputation (standing) | 99.9 | 100.0 | — | 1.45 |
| Adventurers dead | 3.35 ± 2.33 | 3.00 ± 1.64 | −0.35 | −0.55 |
| Missing or gone | 1.65 | 1.65 | 0 | 0.00 |
| Retired | 1.70 | 1.80 | +0.10 | 0.24 |
| Mean level | 5.50 | 5.47 | −0.5 % | −0.13 |
| Adventurers' purses | 2,703 ± 618 | 2,397 ± 640 | −11.3 % | −1.54 |
| Expeditions returned / retreated / missing | 20.2 / 3.9 / 0.9 | 19.65 / 4.45 / 0.9 | — | −0.94 / 0.99 / 0.00 |
| Lore events | 1,733 | 1,761 | +1.6 % | 0.93 |

No metric differs at |t| ≥ 1.6.

**Single seeds:**
- At an intermediate R2 checkpoint (before the plan and gift changes), seed 9001 gave a 90-day fingerprint byte-identical to the baseline in both steward and idle modes, with the danger, reputation, valuation, rumour and stat changes in place.
- The final code diverges from the first changed draw: gifts no longer roll loot tables, spare parts are not conjured, and scouting changes ambush checks. The world is chaotic, so single-seed outcomes differ. The 20-seed aggregate is the comparison.

**Request mix** (requests the workshop cannot yet make), 16 seeds × 21 days: **34.4% on both trees** (303 of 882 pre-R2, 315 of 915 R2).

## 5. Verification

| Gate | Result |
|---|---|
| Compile | **279 scripts, 0 failed** |
| Suite (full) | **482 passed, 0 failed** (476 s) |
| Unit & regression | **394 passed, 0 failed** |
| CI `tests.yml` | success on `c31043e` (run 44202356026) and on the final code `823196f` (run 44204299128) |
| Save migration | schema 10; step 10 idempotent; every golden save (0.11.2 … 0.17) loads, migrates to 10, keeps the smith's standing exactly, round-trips and plays on (`t_saves` 26/26) |
| Rendered phases | **in progress:** 8 of 72 passed on the final code (smoke, full, reload, diag, stations, panels, interiors, nav — 0 failures); the 22 phases for characters, consultations, sponsorship, taverns, shops and equipment are running, then the rest |
| Windows installer | not built: the roadmap marks R2 internal, and R1's playtest raised no truthfulness issue. One can be built as a private artifact on request (§7). |

**Tests changed in R2.** Each of these was checked against the pre-R2 tree before it was changed:

- **Fixtures moved to the facades:** `t_contracts`, `t_run01`, `t_smithy`, `t_s2_econdev` and `playtest_smithy_rl` set reputation with `Reputation.set_village_word` instead of writing `world.rep`.
- **`t_consult`:** "bound for X" fixtures form a real party, because writing `next_dest` by hand never decided where anyone went.
- **`t_recognition.multi_order_partial`:** the adventurer carries a real worn spare (BUG-046).
- **`t_lw_acceptance` schema-4 save:** expects step 10 too.
- **`t_economy_a2.request_feasibility_mix`:**
  - It used one seed against a 30% line; that seed measured 29% before R2.
  - Over 16 seeds both trees measure 34.4%, so the old line sat below the pre-R2 average.
  - The test now measures those 16 seeds against a 40% line ("most requests are things the workshop can make").
  - **This loosens the test's number. The rule it checks is unchanged.**
- **`t_s2_econdev.ledger_60_days_conserved`:** a coin gift is paid in the daily tick, where Barnaby may already have bought a road-found Ironfront card from the same adventurer. That payment comes from his till, so it has no smith ledger line. The check now adds Barnaby's recorded purchases (his shelf records them) for the same adventurer and day. Instrumented: Mira's purse 27 → 33 (a card sale) → 27 (her 6 g gift).

## 6. Build

| Item | Value |
|---|---|
| Branch | `claude/r2-truthful-world` (pushed) |
| Verified code commit | `823196f` (CI run 44204299128); the docs, registers and this report are committed on top of it |
| Releases, tags, default branch | unchanged; nothing merged, published or tagged |

## 7. Open items and unresolved inconsistencies

1. **Wish-list weakness rule (needs a decision).** "Wants a fire weapon for X" uses destinations.json's threat list, the pre-R2 rule.
   - **It is true:** every weakness it names is shared by at least two kinds of foe really at X (`t_r2_truth.test_wish_list_claims_are_true`, at the start and after 60 days).
   - **It is incomplete:** the live foes at Whisperwood (wolf, bear, alpha) and Ironroot Mine (brood mother, spider) also fear fire, but the rule wishes for nothing there.
   - **Calibrating it is a balance change:** using the live foes raised the share of requests beyond an early workshop from 31.7% to 40.8% (4 seeds). It was left unchanged.
2. **`Valuation.value_to(npc, item)` is not built.** The roadmap's R2 text names it, but "value to this person" is ECO-031 (Gate F). R2 consolidated the duplicated sums only. Negotiation routines in sponsor, consult and shop keep their own logic. TECH-030 stays PARTIAL.
3. **Roadmap acceptance "a test per panel":** plans, danger words and rumours are tested at the interface every panel calls (`current_plan`, `Danger.word`, `rumour_facts`), plus static scans. There is no per-panel string test; the panels are covered by the rendered phases.
4. **Still conjured, outside R2's three named cases:**
   - Villagers' plain-repair requests create the item to be repaired (ECO-043/BUG-014, UNDECIDED).
   - Aldric's weekly provisions bake bread from nothing (QST-024).
5. **Affix effects remain inert** (EQ-022, R5). They are now labelled as such.
6. **Reputation is data only:** the region and civilizations hear nothing until R8. Mayor and civilizations untouched (D-7).
7. **Pre-existing:** BUG-062 (soak station-wait race; R2 did not touch scheduling). Engine "triangulation failed" noise in rendered runs.
8. **Not integrated, not released** (D-1 still applies).
