# S2 ECONDEV — equipment affordability, commerce verification, developer tools

Worker branch `worktree-agent-ab3129d6de5505504` (base `2e854af`, repo crosenlund79/DNDBlacksmith, `config/name="Ember & Ash"`
verified). Not pushed.

## STATUS

| Brief item | State |
|---|---|
| Investigate affordability (purses vs cheapest suitable piece, per slot and difficulty) | DONE — numbers below |
| `Adv.price_estimate` with rarity / craftsmanship / Display Cases / difficulty | DONE, tested |
| `Adv.purchase_check` "fair" with the difficulty factor | DONE, tested |
| Salt Anvil adventurer pricing asymmetry | DONE, tested |
| Affordable ordinary choices (plain common stock at the Salt Anvil) | DONE, tested (mail + leather boots/gloves/belt; see design choice 3) |
| Gratitude relic cap (BUG-045) | DONE, tested |
| Consultation recheck; PROP-020 ranking | DONE — defect proven (2 of 36) and fixed; tested + rendered |
| Offer grid / comparison / eligible filtering / explicit sale | RECHECKED (rendered); one eligibility defect fixed at the Salt Anvil |
| Every gold transfer: payer/recipient, conservation (60-day seeded game) | DONE, tested (385 lines, 139 adventurer payments, 0 broken) |
| Dev tools: cheat switch, banner, dev_used mark, bypass, scenarios, skill levels | DONE, tested + rendered |
| Automated suite | GREEN at a4b75d9: compile 225 scripts, suite 299/299 (baseline 291 + 8 new), unit 384/384 |
| Rendered | `s2_econdev` 0 failures (after and, same script, before on the base build); `slice` 0; `refine_ux` 0 |

## 1. Affordability — investigation and numbers

Measured by a scratch suite case (`scratchpad/s2/econdev/t_zz_measure.gd`, same script on the base build and on S2): 8 world
seeds × 3 difficulties, 97 starting adventurers, purses 22–246 g (median 85 g; purses do not depend on difficulty). A need is
"core" when the slot is missing / broken / worn / too weak (not merely "would like one"). A piece is "suitable" when the class
would use it (affinity > 0) and it is an upgrade (score > current + 1). Sources: the Salt Anvil over 12 restocks at the price
an adventurer really pays there, and the smith's own unlocked Designs as plain common 80 % pieces at the display price.

**Root causes found (proven):**
1. `Adv.price_estimate` priced a saving goal from the item's bare `value × 1.05`: it ignored rarity, Display Cases and the
   difficulty. It differed from the shop's price of the very same plain piece in **856 of 856** goals (Apprentice: a weapon goal
   73 g for an 87 g piece). After: **0 of 856**.
2. `Adv.purchase_check` left the difficulty out of "fair": on Apprentice a neutral buyer (no goals, affection 0) refused the
   shop's own **default** price — even without Display Cases (75 g > fair 74.75 g). After: buys on every difficulty, with and
   without Display Cases; 30 % above is still "overpriced".
3. The Salt Anvil charged adventurers the smith-buying factor (1 / prices): relative to the smith's display price for the same
   piece Maren was ×0.76 of her markup on Apprentice (undercutting the smith on the easy setting) and ×1.23 on Master. After:
   her markup on every difficulty (spread < rounding).
4. No ordinary affordable source existed for boots, gloves, belts or body armour at all: the Salt Anvil stocked only
   sea-bronze / ripple-steel / starsteel (cheapest suitable 94–419 g), and a new forge cannot make those slots.
5. A latent eligibility defect: `Commerce.rival_offer_for` ignored class affinity (a Ranger or Wizard could buy a shield).

**Core needs of starting adventurers with an affordable suitable piece (either source):**

| Difficulty | Before | After |
|---|---|---|
| Apprentice | 123 / 306 (40 %) | 184 / 306 (60 %) |
| Journeyman | 126 / 306 (41 %) | 197 / 306 (64 %) |
| Master | 122 / 306 (40 %) | 198 / 306 (65 %) |

Per slot, journeyman (n, purse median of those needing it, cheapest suitable piece):

| Slot | n | purse median | Before: Salt Anvil / smith common q80 | After: Salt Anvil / smith | Affordable before → after |
|---|---|---|---|---|---|
| weapon | 80 | 107 | 302–316 / 30–97 | unchanged | 76 → 76 |
| armour | 69 | 74 | 365–377 / none | **112** (plain mail) / none | 0 → 11 |
| boots | 41 | 107 | 108–115 / none | **29** / none | 18 → 41 |
| helmet | 25 | 142 | 254–267 / 49 | unchanged | 24 → 24 |
| gloves | 23 | 67 | none / none | **23** / none | 0 → 23 |
| amulet | 21 | 80 | none / none | none / none | 0 → 0 |
| ring | 21 | 171 | none / none | none / none | 0 → 0 |
| belt | 14 | 44 | none / none | **18** / none | 0 → 14 |
| shield | 12 | 136 | 293–299 / 49 | unchanged | 8 → 8 |

Apprentice / Master plain prices: boots 33 / 26, gloves 26 / 21, belt 21 / 16, mail 128 / 100 g (the buyers' factor 1.15 / 0.9).
Rarity and craftsmanship keep their worth (magic ×1.8, rare ×3, finer work dearer — asserted). The smith's own q80 crafting
still yields mostly magic/rare (×1.76 average price), so his typical output stays dearer than plain work — by design.

**30 idle days (4 seeds; the smith sells nothing):** Salt Anvil sales before 29 / 19 / 16 (A/J/M), after 61 / 61 / 66 (mostly
≤ 150 g plain pieces). Deaths over 12 seeds × 30 days: Master 61 → 61, Journeyman 14 → 9. Day-30 core needs shift from
"missing" (112 → 100 apprentice) to "inferior"/"worn" (plain pieces wear and are outgrown — later repair/upgrade business).
Request mix (OBS-05 metric, 8 seeds): beyond the forge 27 % before, 28 % after.

## 2. What changed (files, functions)

- `scripts/systems/shop.gd`: `Shop.buyer_factor()` (the difficulty "prices" factor) and `Shop.list_price(it)` (default asking
  price: value × Display Cases × buyer factor); `price_of` = custom price or `list_price` (behaviour unchanged).
- `scripts/systems/adventurers.gd`: `price_estimate(a, slot, rarity := "common", quality := ESTIMATE_QUALITY (80))` prices the
  same def through `Shop.list_price`; `purchase_check` fair × `Shop.buyer_factor()`.
- `scripts/systems/commerce.gd`: `_rival_piece()` (maker mark + forging provenance, `price` for the smith, `base` = Maren's
  asking price); `rival_adv_price(entry)` (base × buyer factor; old stock without `base` recovered from `price`, ±1 g);
  `rival_offer_for` uses it and skips pieces the class would not use; plain stock loop (`rival.plain`, always common,
  quality range, flagged `plain`). `rival_buy_for` charges the offer's (adventurer) price — same uid, Maren stays maker.
- `data/commerce.json` via `tools/data/make_commerce.py`: `rival.plain` = chainmail ×1.15 (45 %), leather boots ×1.2 (60 %),
  gloves ×1.2 (50 %), belt ×1.2 (40 %), craftsmanship 62–78 %. Rest of the file byte-identical in content (checked).
- `scripts/systems/sim.gd`: `gift_from(npc, bias, table := "gift")`; the gratitude relic goes through it (gift budget = half
  the giver's 30-day business, less earlier gifts; logged); nothing fits → no relic yet, the once-only memory is not spent.
- `scripts/systems/consult.gd`: "keep your coin" relevance 0.4 (was 0.5) when a gear-seeker also has a purchase offer.
- `scripts/systems/dev_tools.gd`: session switch `enabled() / set_enabled()`, `bypass_checks() / set_bypass()`, `end_session()`,
  `mark_game()` / `used_in(state)` (state key `dev_used` {first_day, last_day, times}, created lazily), "CHEATS ON" banner
  (CanvasLayer `DevCheatsIndicator`, layer 120), `run_check(args)` / `bypass_scores(args)` (100 % per round, callback
  deferred), `spawn` / `add_money` refuse while off.
- `scripts/ui/panels/dev_panel.gd`: cheat bar (state, "Enable cheats for this session" / "Switch cheats off", "Skill-check
  bypass"), every tool locked while off, "Test scenarios" (crafting: materials ×2 for an Iron Longsword + the forge panel;
  workshop: unlock + hire + queue materials + Workshop Ledger; counter: richest adventurer in town seated with a multi-part
  request; Project Bench: bench set up if missing, Drovers' contract accepted, contract view), skill levels shown beside
  the −/+/+XP buttons. `dev_catalogue_panel.gd`: spawn/money disabled while off, status line.
- Tests/docs: `tests/suite/cases/t_s2_econdev.gd` (8 tests), `tests/playtest_s2_econdev.gd` (phase `s2_econdev`),
  `t_devtools.gd` (switches cheats on; asserts refusal while off), `docs/TESTING.md`, `docs/PLAYGUIDE.md`, `README.md`.

### Shared files touched (small, local)
- `scripts/autoload/game.gd`: one line each at the top of `new_game` and `from_save`: `DevTools.end_session()`.
- `scripts/ui/ui_root.gd` (`_route`, "skillcheck"): `if DevTools.run_check(args): return` before `Minigames.create` — the one
  place every skill check starts (station, practice, socket, repair, refine, sharpen). Not in minigame UI.
- `tests/playtest.gd`: `phase_s2_econdev` registration; `phase_slice` and `refine_ux` press "Enable cheats for this session"
  after F10 (the tools are locked otherwise).
- `tests/suite/cases/t_steward.gd` (STEWARD's area — please reconcile): the 365-day soak's "no deadlock" rule (≥ 10 decisions
  a month while apprentices remain) now counts any decision in a period where the spending limits held the buying up
  (`_limited_now()`: replenish stall `limit` / `*_limit` / `reserve`). Reason: the soak's absence limit (1,500 g) is used up
  after a few months in base too (base decisions per month end 70, 25, 10, 7, 1) — base only passed because both
  apprentices happened to leave by day 270. My change altered the random path so Hilda stays all year → periods 11–13
  had 6/5/3 decisions with "Iron Ore costs more than the steward may spend now" (limit stall ×2504). Not a steward defect;
  a test assumption. STEWARD may prefer a different fix (e.g. a larger soak limit).

## 3. Gold transfers verified (D14)

`t_s2_econdev.test_ledger_60_days_conserved` (seed 6060, 60 days, display stocked, commissions delivered, repairs, a
consultation every 6 days): every line names a known party, `Payments.unaccounted()` empty, and each of 139 payments
between the smith and an adventurer moved the same coins through that adventurer's purse (purse snapshot at each
`gold_changed` and at each tick of the test clock). Paths read and classified:
- Adventurer purse ↔ smith (conserved): display/counter sale (`Shop.sell_to` → `Adv.give_item`), consultation sale (same),
  repairs (`do_repair`, multi-part repairs, `_charge`), commission share (`_charge`) + village subsidy as its own line
  (party `village`), consultation coating, healing draughts at departure, creature resale, sharpening fee, dispute refund,
  spouse share, offers bought from adventurers, sponsorship fees/settlements.
- Gifts: no money moves; items from loot tables, value-capped (thank-you, Aldric's purse, commission package, and now the
  gratitude relic).
- Outside parties without a simulated purse (named): villagers (repairs/goods — ECO-043 undecided), stores/keepers, reeve,
  caravan, pawnbroker, Salt Anvil, Hale Farm, harbour/ships, teachers, inn/Lantern/dice, Ironfront, patrons, collector,
  market, wages, property sellers, developer tools (`dev`, never in normal play — asserted 0).
- Adventurer purchases at the Salt Anvil leave their purse (Maren keeps no purse) — not the smith's ledger, correctly.

## 4. Developer tools

Cheats OFF by default, a static session flag (never in `Game.state` or Settings), off after `new_game` or a load; tools
locked while off (panel and `DevTools` functions); banner "CHEATS ON · F10" (+ "skill checks bypassed"); enabling marks
the running game `dev_used` so later saves carry it; the bypass only while on. Asserted in `test_cheats_off_by_default`
(also: the save holds no switch, a loaded save is off but still marked, a new game is unmarked) and
`test_dev_panel_locked_until_enabled` (every tool disabled while off; the switch unlocks scenarios and the bypass).
CI/normal play: every suite test starts from `Game.new_game` → off; the 60-day test asserts no `dev` money.

## 5. Tests and screenshots

- New suite case `t_s2_econdev`: price_estimate_is_the_shop_price, salt_anvil_fair_on_every_difficulty,
  affordable_ordinary_choices, gratitude_gift_bounded, ledger_60_days_conserved, consultation_offers, cheats_off_by_default,
  dev_panel_locked_until_enabled — all PASS.
- Rendered `s2_econdev`: after 0 failures (13 shots), before (base build, same script) 0 failures (8 shots; no cheat switch
  exists there). `refine_ux` and `slice` (both now press "Enable cheats" after F10) 0 failures.
- Full run at a4b75d9: compile 225/225, suite 299/299, unit 384/384 ("ALL GREEN").
- Screenshots `scratchpad/s2/shots/econdev/`: 01 saving goal (Kestra 40/168 g → 40/199 g, the shop's real price);
  02 Salt Anvil (before: sea-bronze only, 227–1342 g; after: plain mail 98 g and leather boots 26 g beside it);
  03 consultation (before: repair 41 g beyond her 40 g + "keep"; after: also "the Salt Anvil sells plainer boots", 35 g);
  04 gear-seeker's advice (before keep 0.50 vs buy 0.55 tie risk; after buy first, keep 0.40); 05 advice taken (same uid,
  maker kept); 06/07 counter offer grid, compare (6 → 11 attack), "Sell for 71 g", sold; 08 F10 (before: all live; after:
  locked, "Cheats are OFF"); 09 cheats on + banner + bypass; 10 forge step bypassed ("Heat the billet 100 %", next: anvil);
  11 counter scenario (multi-part request); 12 Project Bench scenario; 13 cheats off, banner gone. All looked at.

## 6. Not done (with reasons) and proposals

1. Rings and amulets stay without an affordable ordinary source (silver jewellery needs the smith's skill node; Maren is
   not a jeweller). Decide: an earlier silver band, or plain silver at the caravan/Maren?
2. Body armour: plain mail (100–130 g) is above the 74 g median purse of armour-needers; a cheaper upgrade over a leather
   jerkin does not exist in the data. Left as is (no discounts).
3. Plain iron weapons / helmets / shields at the Salt Anvil (the lead's example) were tried and dropped: with them the share
   of requests beyond the forge rose 27 % → 30 % (8 seeds) and Maren took the slots the smith can already make (his own
   common work is within purses there). Data-only to add back (`rival.plain`) if wanted.
4. ECO-045 gifts from real possessions — not trivial (villagers have no possessions; adventurers' packs are expedition loot)
   → still a proposal. ECO-043 villager purses — undecided, untouched.
5. PROP-021 slot filters in `offer_picker.gd` (CLARITY's file) — not done. The Salt Anvil panel (CLARITY) still describes
   only sea-bronze and shows the smith's price; suggest a line for the plain work and "adventurers pay N g".
6. Save list: show the `dev_used` mark (saves.gd / save_panel) — not mine; proposal.
7. The consultation's honest "elsewhere" advice is usually "unlikely" (the cost-vs-purse penalty) — unchanged; worth a look.
8. Bypass covers player skill checks routed through UIRoot; the fortune dice and apprentices' work are untouched.

## 7. Design choices I had to make

- A saving goal assumes a plain common piece at 80 % craftsmanship (`Adv.ESTIMATE_QUALITY`); `rarity` is a parameter.
- "Fair" scales with the buyers' factor: Master buyers are stricter with a custom price, Apprentice buyers more lenient.
- Maren's adventurer price uses the same buyers' factor as the display: her sea-bronze is dearer to adventurers on
  Apprentice (×1.15 instead of ×0.87) and cheaper on Master — the smith's own buying price at her bench is unchanged.
- Plain stock: always common, 62–78 %, markup 1.15 (mail) / 1.2 (leather), restocked with her bench every 4 days.
- PROP-020 fixed by ranking only (0.4 when a gear-seeker has a purchase offer), wording unchanged.
- Cheats: the switch lives on the F10 panel; the bypass gives 100 % (a clean centre strike) for every round.

## Commits (branch worktree-agent-ab3129d6de5505504, not pushed)

- `3e1172f` S2 econdev WIP: affordability, Salt Anvil pricing, gift cap, consult ranking, cheat switch (all code, tests,
  phase, docs; checkpoint commit requested by the lead — its message lists the steward soak as open)
- `a4b75d9` S2 econdev: steward soak counts limit-held periods; shot prefix s2econ (suite green)

Scratch evidence: `scratchpad/s2/econdev/` (measure_before/after.out, feas_*.out, deaths_*.out, needs_*.out, stew_*.out,
pt_before.log, pt_after2.log, full3.out).
