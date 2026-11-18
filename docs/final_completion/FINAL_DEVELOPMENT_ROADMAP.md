# Ember & Ash — Final Development Roadmap

*The finite route from the current baseline (`65e70b5`, canonical v1.7) to a feature-complete, accepted Ember & Ash 1.0.*
17 November 2026. Evidence and requirement status: [`FINAL_COMPLETION_AUDIT.md`](FINAL_COMPLETION_AUDIT.md). The next
build, ready to implement: [`NEXT_BUILD_BRIEF.md`](NEXT_BUILD_BRIEF.md).

**Rules for every build.** These come from CLAUDE.md and canonical §16.2 and are not repeated per build:

- Verify the repository and STOP on mismatch; secure a recovery point.
- One isolated branch per build.
- A save-schema step and golden save for every structural change.
- Item identity, saves and creator-art overrides preserved.
- Full suite + unit + the build's rendered phases + affected older phases; Windows CI install-and-launch smoke.
- Registers updated; honest report.
- No new frameworks, no rewrites.
- Each build extends the systems named in its scope. A build that finds the approved design unbuildable returns with
  evidence and options; it does not substitute a different design.

---

## The route at a glance

| # | Build | Canonical gate | Closes (journeys) | Needs decisions (audit §7) | Windows playtest |
|---|---|---|---|---|---|
| **R1** | **Integration & Foundation Closure** | A | identity hygiene; first public build since 0.14 | 1, 2, 3, 4, 5 | **Yes — public 0.17** |
| R2 | Truthful World Model | A (entry points) | honest plans, rumours, danger; shared valuation | 7 (data model only) | No (internal) |
| R3 | One History | J foundation, H prerequisite | Chronicle as a view of Lore; seeded streams | 6 | No (internal) |
| R4 | Commissions v2 & Civic Recipients | D | **The Honor Guard** | 8, 9 | Yes |
| R5 | Equipment Depth | E | **The famous sword returns**, **The cost of ambition** | 10, 15, 16 | Yes |
| R6 | Legacy: the Reliquary & Heirs | E/I (§12.2 placement) | **A relic and its heir** | 11 | No (rolled into R7's) |
| R7 | Negotiation & Procurement | F | **The sailor who remembers** | 12 | Yes |
| R8 | World Recognition | G | **A town safer by craftsmanship** | 7, 13 | Yes |
| R9 | Regional Crisis Proof | H | the §12.3 "Before I" gate | 14 (regional part) | **Yes — gate review** |
| R10 | Civilizations, Stories & the Chronicle | I + J | **A credible neutral smith**; Phase 10 | 14 | Yes |
| R11 | Release Hardening → 1.0 | Phase 0 | human acceptance of everything | 17, 19 | **Yes — release candidate** |

**Ten implementation builds and one hardening phase.** The order follows dependencies:

1. **Truth first (R1–R3).** The world features write into the danger model, the reputation model and Lore. These must
   exist and be honest before anything is added on top. This is canonical §12.3's "Before G/H" and "Before J" gates, done
   once and early, not three times.
2. **Production and equipment depth (R4–R6).** These extend the strongest existing systems: staged work orders, contracts
   and refinement.
3. **The outward world (R7–R10).** These depend on everything before them. H precedes I as canonical §10.2 requires.

**Not on this route** (audit §6): the 85 `PROPOSED` entries, the six user-deferred observations, the `UNDECIDED` older
asks, everything canonical rejects, and art production. Art runs in parallel on the user's track through the override
system; see `docs/sprite_catalogue/`.

**Biggest risks across the route:**

- The civilization canon is still unwritten (decision 14). R9 cannot start without it, so it is the critical path's only
  creative dependency.
- R2/R3 touch many call sites (danger, reputation, 71 Chronicle writers). They must keep behaviour and saves identical
  where no truth change is intended.
- Late human acceptance would hide balance problems. Hence a public playtest build after R1 and a playtest after most
  builds.

---

## R1 — Integration & Foundation Closure  *(next build — see NEXT_BUILD_BRIEF.md)*

**Purpose.** Put the finished work in players' hands and stop the identity principle being violated by live code.

**Scope.**

- Fast-forward the default branch to the R1 head (decision 1) and publish 0.17.0.
- Golden saves from the 0.15 (schema 4), 0.16 (schemas 7–8) and 0.17 builds.
- Identity residuals: EQ-007, BUG-042, BUG-017, EQ-004 (remaining exits), EQ-012 (structured tombstone).
- Retire hireling off-station production (STAFF-004/HA-025, decision 5).
- Steward look-only actions (STW-026, BUG-003).
- CI: a non-publishing test workflow on every push to `claude/**` (TECH-014).
- Documents: `game/docs` and the registers brought up to v1.7 (BUG-049, TECH-023).
- A written human-acceptance checklist (REL-004, REL-005/STW-027).

**Systems.** `regions.gd`, `crafting.gd`, `hirelings.gd`, `provenance.gd`, `steward*.gd`, `save_migrations.gd`,
`tests/fixtures/saves`, `.github/workflows`.

**Closes.** EQ-007, BUG-042, BUG-017, EQ-004, EQ-012, STAFF-004, HA-025, STW-026, BUG-003, REL-010, TECH-014
(part), BUG-049, TECH-023, QST-027, TECH-033.

**Prerequisites.** Decisions 1–5.

**Risks.**

- Publishing is irreversible in practice.
- Goldens must be produced the authentic way, by the old builds' own code.
- Retiring hireling production changes the early economy; soaks must stay solvent.

**Acceptance.** The full gate list is in the brief. In short:

- Full suite and unit green.
- All 72 rendered phases.
- 365-day soak, both set-ups, every invariant held.
- Every golden from 0.11.2 to 0.17 loads, migrates idempotently and passes `Uniques.audit()`.
- New identity tests for each fixed defect.
- Windows installer smoke.
- The user plays 0.17 against the checklist and records the result.

**Windows build:** yes, **public**.

## R2 — Truthful World Model  *(delivered on branch `claude/r2-truthful-world`, not integrated — see [R2_BUILD_REPORT.md](R2_BUILD_REPORT.md))*

**Purpose.** One danger model, one reputation entry point and honest information, so every later world feature reads
and writes real state.

**Scope.**

- **Danger.** `Danger` as the single entry point used by adventurer decisions, combat, consultations, sponsorship,
  hirelings, scouting and the map (TECH-018, ADV-021, ADV-017, WLD-018). It merges `Regions.danger`, `WorldSites.danger`
  and `Consult.danger_ratio` without changing outcomes except where the old models disagreed.
- **Reputation.** A `Reputation` facade with the audience/place **data model** (TECH-019, WLD-013, WLD-011 groundwork).
  Its initial values come from the current global number, and there is no spread yet (that is R8).
- **Truthful plans.** Character sheets and talk show the live plan (ADV-012). Consultations no longer silently redirect a
  sponsored party (ADV-018, TECH-021).
- **Honest rumours.** Rumours and table talk come from Lore and state (LORE-015, WLD-019).
- **No conjuring.** Gifts, spare parts and pawn histories come from real possessions or are not claimed (ECO-045,
  BUG-046, BUG-047).
- **Shared valuation.** `Valuation.value_to(npc, item)` replaces the duplicated price routines where they disagree
  (TECH-030; `Trade.price_factor` duplicates `Commerce.price_factor`).
- **Displayed stats are truthful** (EQ-053).

**Closes.** TECH-017, TECH-018, TECH-019, TECH-021, ADV-012, ADV-017, ADV-018, ADV-021, WLD-013, WLD-018, WLD-019,
LORE-015, ECO-045, BUG-046, BUG-047, TECH-030, EQ-053; WLD-014 (part).

**Prerequisites.** R1; decision 7 (audiences and places, data shape only).

**Risks.** A wide call-site change. Mitigation: facades first, a call-site switch per system, and golden-save outcome
comparisons on seeded runs.

**Acceptance.**

- A test asserting no file outside the facades reads `Shop.reputation()` or a region's raw danger.
- A seeded 90-day comparison: identical outcomes where no rule changed, and the documented differences elsewhere.
- Rendered phases: dossier, consult, sponsor, tavern.
- Every UI string about plans, danger and rumours traced to a state field (a test per panel).

**Windows build:** no (internal), unless the R1 playtest reports truthfulness issues the user wants to check.

## R3 — One History

**Purpose.** Make Lore the single source of history before the world starts producing much more of it.

**Scope.**

- **Fold the Chronicle into Lore.** The Chronicle store becomes a view over Lore: its 71 writers move to `Lore.record`
  with Chronicle importance, and a save step migrates existing entries (GOV-031, LORE-017, BUG-018, LORE-002).
- **Roles, causal links and indices.** Lore events get roles and causal links (`because: [event ids]`), with indices by
  kind, actor, item and place (LORE-007, LORE-009 as the means).
- **Retention.** The policy from decision 6: summarise routine events into digests, never delete linked or significant
  ones (LORE-004, LORE-006, TECH-024).
- **Seeded randomness.** Named, seeded RNG streams for world, expeditions, commerce and crafting dice (LORE-012 as the
  means; CIV-003, TECH-029, LORE-010).
- **A long-campaign probe.** A 3-year headless probe of Lore size, save size and scan time (TECH-026).

**Closes.** GOV-031, LORE-017, LORE-002, LORE-005, LORE-006, LORE-007, LORE-008, LORE-014, TECH-024, TECH-029, BUG-018;
CIV-003 (means).

**Prerequisites.** R1; decision 6.

**Risks.** Migrating the Chronicle must not lose the hireling-death records or the Hall of Fame and Epic awards that match
Chronicle text today. These must be re-anchored to Lore ids first.

**Acceptance.**

- A test proving every Chronicle line is a Lore event.
- A compression test showing every provenance/person/causal link survives.
- Golden saves from 0.11.2 to R3 migrate with the same Hall of Fame and Epic results.
- A seeded run reproduces bit-identically.
- The 3-year probe stays within the budgets set in the brief: save size, load time and per-day sim time.

**Windows build:** no.

## R4 — Commissions v2 & Civic Recipients

**Purpose.** The Honor Guard: prestigious orders with several named, persistent pieces, honest bulk lots to a real
recipient, and the first civic institutions.

**Scope.**

- **Recipient institutions.** The village (mayor, promoted from the reeve per decision 7) and its militia become
  recipients with real stock, budget and payer records, initially passive (WLD-005, WLD-006 groundwork). Existing patrons
  "the muster" and "the Watch" map onto them.
- **Lot records.** Every bulk delivery writes a lot record at the recipient: what, how many, quality, contributors and day
  (TECH-031, ECO-023). Contract history is no longer capped (BUG-048).
- **Named prestige pieces.** A prestige order may name 1–N pieces, each a staged work order with its own uid, makers and
  contributors (ECO-024; PROD-025 as the means). The patron names them (decision 8).
- **Flagged exceptional commissions** may require the smith's cooperation, flagged in the letter (PROD-015, ECO-025).
- **Molds and patterns.** A minimal set, reusable with no wear, unlocking the chosen cast/forged Designs (PROD-020, D11,
  decision 9).

**Closes.** TECH-031, ECO-023, ECO-024, ECO-025, ECO-026, ECO-027, PROD-015, PROD-025, PROD-020, QST-005, QST-011,
BUG-048; WLD-005 and WLD-006 (part).

**Prerequisites.** R1–R3 (lots and named pieces write Lore with links); decisions 8 and 9.

**Risks.** The bench's hour model and staged orders must coexist, so in-flight contracts in saves need a migration.
Commission pacing must stay achievable.

**Acceptance.**

- A Honor Guard end-to-end test: patron letter → 20 standard units + 3 named pieces → staged work by three workers →
  delivery → lot and named pieces at the militia → save/load → Lore chain.
- Golden-save migration of an in-flight contract.
- A rendered `honor_guard` phase.
- Steward handling: ordinary lots allowed, named pieces deferred.

**Windows build:** yes.

## R5 — Equipment Depth

**Purpose.** Make equipment meaningful and old pieces improvable, with visible risk.

**Scope.**

- **Affixes.** An effect model for affixes, with about 12 effects that change real combat and decision outcomes, shown
  separately in the item presentation (EQ-022, EQ-023, EQ-052, decision 10).
- **Sets.** Three small sets with 2- and 3-piece bonuses (EQ-025).
- **Magic boundaries.** Runes = permanent socket effects, arcana = permanent deep properties (arcanist only), alchemy =
  temporary (EQ-033, EQ-029).
- **Arcane enchantment of existing items.** A staged work order on the **existing uid** (EQ-030, QST-017, D17).
- **Risk tiers.** Advanced reforging, runes and arcana carry real risk: broken, **disabled**, dormant or unstable states,
  with recovery work (EQ-038, EQ-040).
- **Warned destruction.** An explicitly warned extraordinary experiment may destroy the physical item; its history
  endures in a tombstone from R1 (EQ-039).
- **Advice.** Consultation advice can recommend refining the adventurer's own piece (BUG-027).
- **Unique and Epic rules.** Display of legacy Unique copies (QST-028, decision 15); Epic for other makers' pieces
  (QST-022, decision 16).

**Closes.** EQ-022, EQ-023, EQ-025, EQ-027, EQ-029, EQ-030, EQ-032, EQ-033, EQ-038, EQ-039, EQ-040, EQ-052, EQ-056,
EQ-058, BUG-027, QST-013, QST-017, QST-022, QST-028; UX-009, EQ-054.

**Prerequisites.** R2 (valuation and truthful stats), R3 (tombstones and links); decisions 10, 15 and 16.

**Risks.**

- Balance: affixes now matter in combat. Retune against seeded expedition runs, not the bot alone.
- An irreplaceable heirloom must never be lost to an ordinary check.

**Acceptance.**

- Journey tests "the famous sword returns" (sold → used → Epic → inherited → enchanted by an arcanist, same uid, maker
  and history after save/load) and "the cost of ambition" (warned → fails → disabled or destroyed → Lore intact).
- A test that no ordinary or advanced action can destroy an item without the warned flag.
- A seeded combat comparison showing each affix changes outcomes.
- Rendered `equipment_depth`.

**Windows build:** yes.

## R6 — Legacy: the Reliquary & Heirs

**Purpose.** Honour broken famous pieces and give real descendants a say in restoring them.

**Scope.**

- **The Reliquary.** A purchasable display case in the smithy that accepts only **disabled or broken** pieces with earned
  significance. Restored pieces leave it (EQ-042).
- **Heir detection.** Heirs come from recorded ownership chains and authored NPC families (`characters.json` families,
  `Adv.bequeath` records); no invented ancestors (EQ-043, decision 11).
- **The negotiation letter.** The heir may decline, consent without transfer, or demand the piece's return. The agreed
  terms are enforced and recorded (EQ-044, EQ-045).
- **Ancestral binding** for the bloodline-bound Unique only; a non-heir restoration is harder or incomplete (EQ-046).
- **Steward deferral.** Heir matters arrive as sealed correspondence when the steward runs the forge.

**Closes.** EQ-041, EQ-042, EQ-043, EQ-044, EQ-045, EQ-046, EQ-057; GOV-016 (part).

**Prerequisites.** R5 (states and restoration), R3 (ownership and causal chains); decision 11.

**Risks.**

- Heir eligibility must be provable from data.
- Never fabricate a descendant to trigger the story (§10.3).

**Acceptance.**

- A journey test "a relic and its heir": a disabled Epic piece in the Reliquary → a real heir found from recorded data →
  each of the three answers → restoration → ownership per the terms → Lore.
- A negative test: no heir is ever generated without a recorded link.

**Windows build:** no (tested in R7's playtest).

## R7 — Negotiation & Procurement

**Purpose.** Pay people with things as well as gold, protect journeys and trade through named captains.

**Scope.**

- **Goods as payment.** Adventurers accept gold, crafted equipment or both for expeditions, protection and procurement,
  valued by the R2 valuation; a sword given is really equipped (ECO-030, ECO-031).
- **Escorts.** Escorts and protection for expeditions and hireling runs, priced on the R2 danger model (ECO-032,
  decision 12).
- **Named captains.** A small cast of named persistent captains and sailors as a light contact entity reusing the sponsor
  framework. They take procurement voyages that are timed, succeed, are delayed or fail, are remembered and are reported
  truthfully (ECO-036, ECO-037, QST-012, D12). The harbour's ship visits become their visits.

**Closes.** ECO-030, ECO-031, ECO-032, ECO-036, ECO-037, QST-012.

**Prerequisites.** R2 (danger, valuation) and R3 (memory); decision 12.

**Risks.** This must not become a naval game (§1.3). Voyages are timed records, not sailing.

**Acceptance.**

- A journey test "the sailor who remembers" (negotiate → voyage → outcome → the captain remembers the payment on the next
  visit).
- An escort test where danger changes the price and outcome.
- A goods-payment test where the item ends equipped and in provenance.
- Rendered `harbour_captains`.

**Windows build:** yes, covering R6 and R7.

## R8 — World Recognition

**Purpose.** Make the smith's work change the region gradually, causally and audience by audience.

**Scope.**

- **The militia.** It becomes autonomous: it receives consignments (R4 lots), its real equipment raises patrol strength,
  and that lowers regional danger through the R2 model. The change is gradual, with no hard circle, and the map shows
  real values only (WLD-006, WLD-007, WLD-009, WLD-014, WLD-021). Bandits scale down with it (WLD-010, decision 13).
- **Reputation spread.** News spreads per audience and place through travel, letters, goods and events (WLD-011,
  WLD-012, QST-010).
- **Credible visitors.** A persistent cast of renowned visitors with reasons to come (WLD-016).
- **Renown.** Acclaim follows deeds and credible spread; it cannot be bought (WLD-015, QST-018).
- **Political deferral.** Steward deferral of political commitments (STW-014).

**Closes.** WLD-005 to WLD-016 and WLD-021, QST-010, QST-018, STW-014.

**Prerequisites.** R2, R4; decisions 7 and 13.

**Risks.** Safety must be causal and slow. Test with seeded comparisons, not hand-tuned thresholds.

**Acceptance.**

- A journey test "a town safer by craftsmanship": a seeded campaign with and without consignments, where the difference
  in danger, bandit encounters and trade risk is explained by state.
- A reputation spread test: a deed in place A is not known in place B until a channel carries it.

**Windows build:** yes.

## R9 — Regional Crisis Proof (Gate H)

**Purpose.** Prove that a small conflict can escalate, de-escalate or resolve in several ways because of real supply,
relationships and expeditions, before any civilization scaling (§10.2).

**Scope.**

- A limited cast: two factions within the region, a contested resource and two or three locations, from the user's canon
  (decision 14, regional part).
- Tension driven by state: equipment delivered (lots and named pieces), reputation by audience, resource conditions,
  expedition outcomes and rumours.
- Several outcomes including peace. There is no allegiance selector and no countdown (CIV-002, CIV-003).

**Closes.** CIV-002, CIV-003, and the §12.3 "Before I" gate.

**Prerequisites.** R2, R3, R4 and R8; decision 14 (regional).

**Risks.** If the proof fails to produce believable de-escalation, **stop and return with evidence** (canonical §10.2).
Do not scale.

**Acceptance.**

- 20 seeded campaigns under different supply, sponsorship and relationship choices produce at least three distinct
  outcomes including peace.
- Each outcome is explainable from Lore causal chains.
- The neutral smith is viable.
- The user reviews a gate playtest.

**Windows build:** yes. This is the **gate review**; the user approves before R10.

## R10 — Civilizations, Stories & the Chronicle (Gates I + J)

**Purpose.** Scale only what R9 proved to two civilizations, add conditional authored stories, and present the campaign
as the Chronicle of the Realm.

**Scope.**

- **Two civilizations.** They have the user's canon of histories, leaders, champions and interests (CIV-001), and the
  smith's home is placed according to decision 14 (HB-058).
- **Freedom of association and neutral dealings** (CIV-004, CIV-005).
- **Conditional stories.** Authored storylines become eligible only from real state (CIV-006, §10.3).
- **The Chronicle of the Realm.** A readable view over Lore with a "why" chain (LORE-003). Campaign integration means play
  continues after the crisis, with coherent consequences (LORE-016).

**Closes.** CIV-001, CIV-004, CIV-005, CIV-006, HB-058, LORE-003, LORE-016, GOV-016.

**Prerequisites.** A passed R9 gate; decision 14.

**Risks.** Scope sprawl. Scale only R9's mechanisms: no war simulation and no military management.

**Acceptance.**

- A journey test "a credible neutral smith" (crafts for both sides; trust differs by audience; war is prevented in at
  least one seeded run).
- Chronicle view tests: every line is Lore, and the causal chain is shown.
- A 3-year campaign probe continues past the crisis.

**Windows build:** yes.

## R11 — Release Hardening → 1.0

**Purpose.** Ship a complete, stable, accepted game.

**Scope.** No new features. This phase covers:

- **Human Windows playtesting.** A full campaign by the user, against a written acceptance script covering all nine
  journeys, Steward Mode, saves and performance.
- **Full-campaign simulations.** 5-year seeded headless campaigns in three set-ups (poor start, staffed workshop, steward
  heavy), with conservation, identity, Unique and Lore invariants.
- **Migration tests.** Every golden from 0.11.2 to the release candidate, plus saves from the playtests.
- **Performance.** Budgets for frame time in the busiest scenes, load and save time, save size and per-day sim time at
  year 5.
- **Installer verification** on a clean Windows machine: install, upgrade over 0.17 with saves kept, uninstall.
- **Balance passes** from human data.
- **Docs.** The player guide, a canonical v1.8 confirming the unnamed baseline features (decision 17), and the registers.
- **Bug-fix only from here.**

**Acceptance.**

- Zero open defects of severity A/B.
- All nine journeys accepted by the user on Windows.
- Soaks green.
- Budgets met.
- The 1.0 release published from the default branch.

**Windows build:** yes: release candidates, then 1.0.

---

## What "done" means

Ember & Ash 1.0 is done when all of the following are true:

1. All nine proof journeys pass both as automated tests and in the user's Windows playtest.
2. Every `APPROVED` requirement in the registers is `VERIFIED` or explicitly moved by the user.
3. No live code contradicts canonical, so the Chronicle store is gone.
4. Saves from every public build load.
5. A 5-year campaign stays within budget.
6. The 1.0 installer is published.

Anything else is post-1.0.
