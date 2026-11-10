# S2 worker ECONDEV — equipment affordability, commerce verification and developer tools

Read `s2_common.md` first, then canonical §7 (D14), `docs/EMBER_ASH_PLAYTEST_OBSERVATIONS.md` OBS-04/OBS-06/OBS-09, decision
register ECO-011, ECO-043 … ECO-046, PROP-013 … PROP-021, BUG-045, and the A2 economy worker notes in the registers.

## The user's S2 brief (verbatim, your sections)
**6. Equipment affordability and commerce**
* Investigate starting adventurers' inability to afford ordinary equipment.
* Correct proven pricing defects, including rarity multipliers and difficulty-specific pricing where necessary.
* Ensure affordable ordinary-quality choices are available without granting advanced crafting abilities.
* Preserve quality, rarity and meaningful craftsmanship value.
* Recheck consultation sale offers, compact offer grids, item comparison, eligible-item filtering and explicit selling
  confirmation.
* Verify gift rewards, commission subsidies, repair payments and all gold transfers against real sources and recipients.
* Avoid arbitrary discounts, fabricated purchases, unlimited profit or unapproved new trade mechanics.
* Preserve item UIDs, original makers, provenance and history across every transaction.

**7. Developer testing tools.** Extend the existing developer cheat menu, not a parallel system. Provide developer-only:
* Gold/material/item spawning.
* Skill/XP/progression adjustment.
* Fast access to crafting, workshop and commission test scenarios.
* Optional skill-check bypass for explicit testing.
* Clear indication when cheats are enabled.
Normal gameplay, saves and CI integrity tests must not accidentally run with cheats active.

## Known findings (Run 0/A2; verify)
- Starting purses 22–241 g; the Salt Anvil stocks only sea-bronze at 203–818 g; the smith's commons at q80 cost 16–86 g, but
  q80 crafting yields 9 common / 16 magic / 5 rare of 30 (×1.8 / ×3 price).
- `Adv.price_estimate` (adventurers.gd ~725) uses the base value only: ignores rarity and quality multipliers, the display
  factor and difficulty — their saving goals and "can I afford it" logic are wrong.
- `Commerce.price_factor` is a documented reciprocal (not inverted); the real asymmetry: the Salt Anvil's stock is priced
  with the player-buying factor, so on Apprentice an adventurer pays Maren ×0.87 while paying the smith ×1.15; and
  `Adv.purchase_check`'s "fair" leaves the difficulty factor out (a neutral adventurer judges the default price overpriced
  on Apprentice with Display Cases).
- Gifts: the "deep gratitude" relic satchel (sim.gd `_social_events`, `Loot.roll_table("gratitude")`) bypasses the A2 cap
  (BUG-045). Gifts are loot-table rolls, not the giver's possessions (ECO-045, proposal — do not implement possessions-based
  gifts unless trivial and clearly within D14; report).
- Consultation: "keep your coin" (relevance 0.5, consult.gd ~437) outranks a purchase offer (0.45) for gear-seekers (PROP-020);
  the offer grid has no slot filters (PROP-021; CLARITY owns optional filtering in `offer_picker.gd` — coordinate through
  your report, do not edit that file).

## Lead decisions
- Fix proven defects (price_estimate with rarity/quality/difficulty as `Shop.price_of` computes; the Salt Anvil adventurer
  pricing asymmetry; purchase_check fairness with difficulty; the gratitude satchel cap). For "affordable ordinary-quality
  choices": the minimal approved route is ordinary stock that already exists in the world being priced and stocked
  sensibly (e.g. a few plain common iron pieces at the Salt Anvil within starting purses — this was proposal PROP-015 and is
  now explicitly requested), **not** discounts, conjured purchases or new trade mechanics. Report numbers before/after
  (purses vs cheapest suitable piece per slot, per difficulty).
- Consultation ranking (PROP-020): fix only if the recheck proves gear-seekers with suitable affordable stock are steered to
  "keep your kit"; otherwise report.
- Verify every `add_gold` path again (Run 0.1 fixed four leaks): a 60-day seeded game's ledger has a payer/recipient on each
  line and conserved transfers where a purse exists; repairs, subsidies, gifts.
- Dev tools: extend `dev_panel.gd` / `dev_catalogue_panel.gd` / `dev_tools.gd` (F10). Cheats are a session flag that is never
  saved and is OFF by default; a visible "CHEATS ON" indicator while any cheat is enabled; the skill-check bypass applies only
  while explicitly enabled (hook at the start of a check, e.g. in `Crafting`, not in minigame UI owned by EARLY); scenario
  buttons (crafting, workshop with apprentices, commission at the counter, contract at the bench) built from existing state
  setters; XP/skill/progression adjusters. Saves made while cheats were on are marked (e.g. a `dev_used` flag); tests assert
  cheats are off in normal play and CI (`t_s2_econdev`).

## Deliverables
- Code; `tests/suite/cases/t_s2_econdev.gd` (price_estimate matches the shop's real price; Salt Anvil fairness per
  difficulty; affordable ordinary choices exist for starting purses on every difficulty without new crafting abilities;
  gratitude gifts capped; 60-day ledger conserved; consultation offers rechecked; cheats off by default, not saved, indicator
  shown when on, bypass only when on).
- Rendered phase `s2_econdev` (`tests/playtest_s2_econdev.gd`): affordability before/after (an adventurer's view of prices),
  consultation offer grid with comparison and explicit sale, the dev menu with the cheats indicator and scenarios
  (`…/scratchpad/s2/shots/econdev/`).
- Report per `s2_common.md` with the numbers.
