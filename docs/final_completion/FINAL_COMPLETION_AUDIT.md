# Ember & Ash — Final Completion Audit

*Read-only audit of the approved design against the actual game, made to define the finish line.*
Audited 17 November 2026 against **Canonical Vision v1.7** (`docs/EMBER_ASH_CANONICAL_VISION.md`). Code baseline:
**`65e70b5`** on `claude/living-village-workshop`. This is documentation only: no game code, asset, canonical document
or register was changed.

Companion documents: [`FINAL_DEVELOPMENT_ROADMAP.md`](FINAL_DEVELOPMENT_ROADMAP.md) (the ordered builds) ·
[`NEXT_BUILD_BRIEF.md`](NEXT_BUILD_BRIEF.md) (the next build, ready to implement).

---

## 0. Verdict

**The smithy half of Ember & Ash is essentially complete. The living-realm half is about one-third built.**

- **The smithy half is built and tested.** This covers the workshop, the professions, the Designs, staged production,
  Steward Mode, item identity, the village and the dangerous regions, from canonical §3–§5, §6.1, §6.2's Legendary rule,
  §4.5 and §11.
- **The living-realm half is mostly missing.** The canonical promise that *"the world uses and remembers"* the smith's work
  through commissions to institutions, deep equipment, recognition, conflict and Chronicle (§6.3–§6.6, §7.2–§10) is about
  one-third built.
  - Of the nine canonical proof journeys (§13), **2 are complete, 2 are partial and 5 have not been started**.
  - The **mayor and militia, regional reputation, civilizations and crisis, sea captains, escorts, the Reliquary and
    heirs, arcane enchantment of existing items, Set mechanics, reworking risk, and the Chronicle as a view of Lore do not
    exist in code.**
- **The finished work has not been integrated or released.**
  - The default branch is still at Run 0.1 (`2e854af`, 10 November). 126 commits (+30,044 lines) of S2, the Living
    Workshop, three pilots, v1.6 and v1.7 exist only on feature branches.
  - The latest public release is still **build-0.14.6** (9 Nov).
  - Human acceptance exists only as playtest observations, not as a recorded acceptance.

So "feature-complete" is still about **ten bounded builds away**. They are mostly world-side systems, built on
foundations that already exist: Lore, provenance, staged work orders, regions, contracts and patrons, the trade docks, and
the steward's deferral. None of them needs a rewrite. The detailed sequence is in the roadmap.

| Measure | Result |
|---|---|
| Canonical proof journeys (§13) | 2 complete · 2 partial · 5 missing |
| Canonical creative phases 0–10 (§12.1) | 1 complete (Phase 1, molds aside) · 5 partial (0, 2, 3, 4, 5) · 1 largely missing (6) · 4 missing (7, 8, 9, 10) |
| Approved register requirements at LW close (decision register, 649 entries) | 315 verified · 49 implemented · 60 partial · 63 not started (of 487 approved) |
| Approved additions after LW (v1.5 biographies, v1.6 sections 1–3, v1.7 OBS-64 … 76) | all implemented and tested on the branch (`t_biography`, `t_legendary`, `t_regions`, `t_seasons`, `t_compact_smithy`, `t_rare_materials`, `t_ironfront_intro`) |
| Automated tests on `65e70b5`, re-run 17 Nov | all green: compile 272/0 failed, suite 443/443, unit 392/392 |
| Published build | **build-0.14.6** (GitHub latest release, 9 Nov 2026, commit `154d08a`) — A1, S1, A2, Run 0.1 and everything later are in no release |

---

## 1. Preflight

| Check | Result |
|---|---|
| Repository | `crosenlund79/DNDBlacksmith`, remote `origin` = `https://github.com/crosenlund79/DNDBlacksmith` |
| Godot project | `game/project.godot`, `config/name="Ember & Ash"`, Godot 4.3 |
| CLAUDE.md and canonical | read in full; canonical Design Baseline **1.7** (DOCX v1.7 + Markdown) |
| Working tree | clean; audit branch `claude/final-completion-audit` created from `65e70b5` |
| Branches inspected | all 50 remote branches. **All are contained in `65e70b5`** except: `claude/sprite-artist-catalogue` (`4350b11`, one docs-only commit on top of `65e70b5`), and `hotfix/mining-xp` / `claude/mining-xp-hotfix-ponkqb` (`c8baf4e`), whose change was cherry-picked into the line as `4fbfaee` (BUG-051; `t_mining_xp` present). **No conflicting or lost work.** |
| Stability work after the catalogue | none exists (no branch newer than `4350b11`) |
| Newest verified development baseline | **`65e70b5`** (`claude/living-village-workshop`, 13 Nov 2026; Windows artifact EmberAndAsh-Windows-0.16.21, run 43475441787) |
| Default branch | `claude/kind-dijkstra-nqkxn1` at `2e854af` (Run 0.1). It is an **ancestor** of `65e70b5`, so integration is a fast-forward with no merge conflict |
| Nothing reset, deleted, merged or overwritten | confirmed |

---

## 2. Evidence base and method

### 2.1 Sources compared

Canonical v1.7 (authority) · the decision register (649 entries, last updated at the Living Workshop, 11 Nov) · the
roadmap register (last updated 11 Nov) · the playtest observation register (OBS-01 … OBS-76, updated 13 Nov) · `game/docs`
· the S2/LW progress files · the test suite and rendered phases · **the code itself**.

### 2.2 How claims were checked

The registers stopped tracking delivery at the Living Workshop. Every pillar below was therefore re-checked in the code at
`65e70b5`:

- I grepped the systems for each canonical capability: militia, mayor, civilizations, captains, escorts, Reliquary, heirs,
  Sets, enchantment, audiences, danger, reputation and lots.
- I read the relevant functions.
- I confirmed that **no world-side system was touched after the Living Workshop**. `git log 587399c..65e70b5` shows no
  change to `adventurers`, `consult`, `sponsor`, `regions`, `shop`, `lore`, `chronicle` or `contracts`. The registers'
  LW-era statuses for those areas are therefore still accurate, and the spot checks below confirm them.

Spot-checked open defects:

| Entry | Code evidence at `65e70b5` | Still open? |
|---|---|---|
| BUG-042 rune socketing renames/re-rarifies | `crafting.gd:880-882`: a Common piece becomes `"magic"` and is renamed `"Runed " + name` | **yes** |
| EQ-007 identifying a relic breaks the identity chain | `regions.gd:123-147`: the relic is erased and a freshly rolled item (new uid) added | **yes** |
| TECH-018/ADV-021 one danger model | `Regions.danger` (adventurers, hirelings) and `WorldSites.danger` (sponsor, map) and `Consult.danger_ratio` coexist | **yes** |
| TECH-019/WLD-011 reputation by audience/place | one `Shop.reputation()` read directly by 6 files; no `audience` concept anywhere | **yes** |
| GOV-031/LORE-017 Chronicle is a view of Lore | separate `Chronicle` store (`CAP 400`) with **71** `Chronicle.add` call sites vs **37** `Lore.record` | **yes** |
| ECO-036 named persistent captains | ships carry a random name/captain string pair per docking (`trade.gd:210-224`); no captain entity | **yes** |
| EQ-025 Sets | one item tagged `set` (`wyvernscale_pauldron`); no set-bonus code | **yes** |
| EQ-030 arcanist enchants existing items | refinement has refine/rework/upgrade/reforge only (`refinement.gd:21`); no arcane enchantment of an existing piece | **yes** |
| EQ-042 Reliquary | the word appears only as an unidentified relic's name | **yes** |
| WLD-005/006 mayor, militia | only "the reeve" as a rent payee (`payments.gd:23`); no civic entity | **yes** |
| PROD-020 molds/patterns (D11) | no mold, pattern, jig or die anywhere in code or data | **yes** |

### 2.3 Automated test status (re-run for this audit)

`GODOT=… ./run_tests.sh full` on `65e70b5`, 17 Nov 2026: **ALL GREEN — compile 272 scripts / 0 failed, suite 443 passed / 0 failed (427 s), unit 392 passed / 0 failed**.
Also present but not re-run (cost): 72 rendered phases (`tests/playtest.gd`), the 365-day steward soak
(`tests/lw_soak.tscn`), the seeded skill-tree fuzz. Last full rendered run: the Living Workshop (59/59 on `d0d5362`); the
v1.6/v1.7 phases were run individually when built.

---

## 3. The nine proof journeys (canonical §13)

| Journey | Status | Evidence / what is missing |
|---|---|---|
| **The ordinary order** | **COMPLETE** | A basic item without specialists; blockers, sources and stock legible — `t_workshop_e2e`, `t_ux_journey`, `t_guide`, S2 clarity work. |
| **The collaborative masterpiece** | **COMPLETE** | Emberwarden Longsword: forge → anvil → rune → cauldron → grinding → stitching, one uid, every contributor, save/load — `t_lw_emberwarden`, `t_lw_production`, rendered `lw_production`. |
| **The famous sword returns** | **PARTIAL** | Sold, used, Epic, inherited (`Adv.bequeath`), refined/reworked/upgraded keeping uid (`t_refine`, `t_world_remembers`). **Missing:** arcane enchantment of the existing piece (EQ-030); consultation advice to refine one's own piece (BUG-027). |
| **The Honor Guard** | **PARTIAL** | Bulk orders at the Project Bench with one optional masterpiece (`t_contracts.test_masterpiece_slot`). **Missing:** several individually named pieces in one order (ECO-024), lot records at a recipient (TECH-031, ECO-023), staged work for bench pieces (PROD-025). |
| **A town safer by craftsmanship** | **MISSING** | No mayor, no militia entity, no causal safety model (WLD-005/006/007/021). |
| **The sailor who remembers** | **MISSING** | No persistent captains, voyages or procurement contracts (ECO-036/037). |
| **A credible neutral smith** | **MISSING** | No civilizations, no audience reputation, no dispute (CIV-001/004/005, WLD-011). |
| **A relic and its heir** | **MISSING** | No Reliquary, no unusable-item state, no heir negotiation (EQ-042 … 046, EQ-057). |
| **The cost of ambition** | **MISSING** | Refinement failure is a small recoverable loss only; no advanced risk tiers, dormant/disabled states or warned destruction (EQ-038/039/040, EQ-058). |

---

## 4. Requirement status by pillar

Status: **COMPLETE** = implemented and verified by automated tests (human Windows acceptance tracked separately in §5);
**PARTIAL** = implemented but missing essential behaviour; **MISSING** = approved but not implemented; **BLOCKED** =
cannot proceed without a named decision or dependency. IDs refer to the decision register (`EMBER_ASH_DECISION_REGISTER.md`)
or the observation register.

### 4.1 Blacksmith progression

| Requirement (canonical) | Status | Evidence · gap |
|---|---|---|
| Deep personal smithing tree; other crafts capped at basic (§4.2, D2, D3) | COMPLETE | `Workers.BASIC_LEVEL` 5, smith path smithing + mining; `t_lw_knowledge`, `t_progression`, `t_lw_foundation` |
| Legendary only from designated advanced Designs and exceptional work (§6.2 v1.6) | COMPLETE | `t_legendary` (5 tests) |
| Rare materials chiefly from dangerous places (§7.1 v1.7) | COMPLETE | `t_rare_materials` |
| Progression that stays satisfying across a full campaign | **PARTIAL** | Mechanics exist; pacing was tuned only against a near-perfect test bot (BUG-025) and soaks; the working smith's earnings question is open (QST-031). No mid/late-game pacing evidence from human play. |
| Molds, patterns, jigs and dies, reusable, no wear (§5, D11) | **MISSING** | none in code or data (PROD-020; canonical never placed it in a gate) |

### 4.2 Workshop, professions, Designs and exceptional equipment

| Requirement | Status | Evidence · gap |
|---|---|---|
| Rundown smithy → purchasable rooms, floors, lift; compact ground floor, loft quarters, excavatable basement (§4.1 v1.7) | COMPLETE | `t_property`, `t_compact_smithy`, rendered `lvw` phases |
| Several stations of a type within room limits (§4.4, D6) | COMPLETE | station instances, save step 7; `t_lw_production`. Exact capacities remain an open detail (WS-011, QST-025) |
| Five professions, per-worker competence, workshop knowledge (§4.2–4.3, D1, D7) | COMPLETE | `t_lw_foundation`, `t_lw_knowledge`, `t_employees` |
| Staged multi-worker work orders, one identity, contributors, help requests (§4.4, D4, D8) | COMPLETE | `t_lw_production` (14), `t_lw_emberwarden`; assistance values and queue UI are interim open details (PROD-016, PROD-023) |
| Family at the workshop, pet (§4.3 v1.4) | COMPLETE | `t_lw_family` (10), pilot 004 |
| Steward Mode (§4.5, D19) | **COMPLETE (automated), acceptance outstanding** | `t_steward` (13), `t_steward_ui`, `t_s2_steward` (14), 30/365-day soaks. Residuals: steward never brews goods or restocks potions (STW-019, PARTIAL); look-only panels keep some action buttons (STW-026, BUG-003); "political commitments" have nothing to defer until G–I exist (STW-014). Human acceptance (REL-005, STW-027) not recorded. |
| Hireling off-station production (§1.2 "physical workshop") | **PARTIAL** | hirelings still produce goods from allocation without a station (STAFF-004, HA-025); a decision is pending |
| Exceptional equipment: Common/Magic/Rare/Legendary with meaningful affixes (§6.2) | **PARTIAL** | affixes are stat bonuses that feed combat (fire/frost vs weakness, `expeditions.gd:965`); no distinctive effects; displayed values not all used (EQ-022, EQ-023, EQ-053) |
| Unique exactly one per campaign (D13) | COMPLETE (mechanism) | `Uniques` registry, `t_run01`, `t_identity`. Only **one** Unique is defined (Grimhold); legacy-copy display undecided (QST-028) |
| Set: combined-use mechanics (§6.2) | **MISSING** | one item tagged `set`, no bonus mechanics (EQ-025); rules are an open detail (EQ-027) |
| Runes, arcana and alchemy as distinct specialist magic; arcanists enchant **existing** equipment (§6.3, D17) | **MISSING** (runes PARTIAL) | rune socketing exists (and violates §6.1, BUG-042); no arcane enchantment of an existing piece (EQ-030); boundaries not formalised (EQ-033) |
| Reworking risk tiers; warned destruction; history endures (§6.4, §14.1) | **MISSING** | refinement fail = small recoverable loss (`refinement.gd:33-34`); only "broken" (half strength) exists (EQ-038/039/040) |

### 4.3 Item identity, refinement, inheritance and legacy

| Requirement | Status | Evidence · gap |
|---|---|---|
| One creation, one authentic history (§6.1) | **PARTIAL** | registry, provenance, transfers, golden-save migrations: `t_identity` (15, incl. year-long probe), `t_provenance`, `t_saves` (22). **Live violations:** BUG-042 (socketing renames/re-rarifies), EQ-007 (identification mints a new uid); BUG-017 (dismissed hireling's gear leaves no record); EQ-004 (some exits, e.g. merchant restock, record no transfer); EQ-012 (no structured tombstone for lost/destroyed pieces) |
| Refinement keeps the same object (§6.3, D17) | COMPLETE for refine/rework/upgrade/reforge | `t_refine` (12) |
| Inheritance between adventurers | COMPLETE | `Adv.bequeath` (`adventurers.gd:1024`), `t_world_remembers` |
| Reliquary (§6.5, Option A) | **MISSING** | EQ-042 (needs an unusable state, EQ-040) |
| Ancestral restoration and the heir's claim (§6.6) | **MISSING · BLOCKED on decisions** | EQ-043 … 046, EQ-057; damage states, restoration costs and heir eligibility are open details (EQ-041). Named NPC families exist in `characters.json` and ownership chains in provenance, so credible heirs can be grounded without inventing ancestors |
| Epic as earned history (§6.2) | COMPLETE (own pieces) | Hall of Fame / recognition: `t_recognition`. Whether other makers' pieces may become Epic is open (QST-022) |

### 4.4 Autonomous adventurers, commerce and the living village

| Requirement | Status | Evidence · gap |
|---|---|---|
| Independent lives, companies, consultations, sponsored expeditions (§8.1) | COMPLETE (original scope) | `t_adventurers`, `t_living`, `t_consult`, `t_sponsor`, `t_social` |
| Authored biographies (§8.1 v1.5) | COMPLETE | `t_biography` |
| Three dangerous regions with guardians and successors (§8.1 v1.6) | COMPLETE | `t_regions`, rendered `beyond_map`. **Art gap:** 14 of their enemies have no sprite and show a placeholder card (`docs/sprite_catalogue` on its branch) |
| Character sheets and talk show **truthful** plans; rumours from real state (§1.2, §8.1, §11) | **PARTIAL** | legacy destination shown instead of live plan (ADV-012); paid rumours state template facts (LORE-015, WLD-019); scouting claims an effect nobody feels (WLD-018); consultation can silently redirect a sponsored party (ADV-018, TECH-021); gifts, spare parts and pawn histories conjured (ECO-045, BUG-046, BUG-047) |
| One authoritative danger model (Gate A) | **MISSING** | three danger models (TECH-018, ADV-021) |
| Commerce circulates the same identifiable objects (§7.1) | COMPLETE (core) | `t_commerce`, `t_trade`, `t_identity`; residual exits EQ-004 |
| Payments have real payers (D14) | COMPLETE | Run 0.1 fixes, `t_run01`, `Payments` ledger; villagers' purses and the commission subsidy are open questions (ECO-043, QST-024) |
| Bulk lots and several named prestige pieces (§7.2, D5) | **PARTIAL** | see Honor Guard (§3) |
| Goods as payment for expeditions/protection/procurement (§7.3) | **MISSING** | ECO-030; offers partly reflect needs (ECO-031 PARTIAL); about ten price routines, no shared valuation (TECH-030) |
| Escorts and protection priced on regional danger (§8.2) | **MISSING** | ECO-032 (depends on the danger model) |
| Named persistent sailors and captains, timed voyages (§8.3, D12) | **MISSING** | ECO-036, ECO-037 |
| Living village, illustrated maps, compact UI, Ironfront introduction, seasons (§4.1, §11 v1.6–1.7) | COMPLETE | `t_village10`, `t_venues`, `t_seasons`, `t_ironfront_intro`, `t_ironfront`, OBS-64 … 76 |

### 4.5 Reputation, regional influence and the preventable conflict

| Requirement | Status | Evidence · gap |
|---|---|---|
| Independent mayor and militia equipped by commissions; gradual causal safety (§9.1) | **MISSING** | WLD-005, WLD-006 (only contract patrons "the muster", "the Watch"), WLD-007, WLD-021 |
| Reputation by community, person, institution and place; gradual spread (§9.2, D10) | **MISSING** | one global number (`shop.gd:70`); no facade (TECH-019) — **BLOCKED** on the audiences/places decision (D10 open detail) |
| Renown cannot be bought (D18) | COMPLETE | removed in Run 0.1 (`t_run01`) |
| Credible renowned visitors (§9.2) | **PARTIAL** | contract patrons and the Royal Household letter exist; no persistent visitor cast with reasons to come (WLD-016) |
| Two civilizations; preventable conflict; regional proof first (§10.1–10.2) | **MISSING · BLOCKED** | CIV-001 … 005; names, map, leaders and grievances are open details (CV §15) only the user can settle |
| Authored stories inside reality (§10.3) | **PARTIAL** | Lore-conditioned events exist (World Remembers, spirit voices, memorials); no authored conditional storylines (CIV-006) |

### 4.6 World consequences, Lore and the Chronicle

| Requirement | Status | Evidence · gap |
|---|---|---|
| Lore and provenance as the shared memory (§10.4, D9) | **PARTIAL** | Lore exists (`CAP 4000` with pruning of routine, unreferenced events); no roles, causal links or indices (LORE-007, LORE-009) |
| Chronicle is a **view** of Lore, not a separate store (§10.4, §15) | **MISSING (conflict)** | separate Chronicle store, 71 writers (GOV-031, LORE-017); kept by the user's decision until Gate J |
| Routine activity summarised without losing meaningful links; performant over years (D9) | **MISSING** | pruning, not summarising; nothing tested beyond 365 days; hireling deaths in the Chronicle vanish at 400 entries (LORE-006, LORE-008, BUG-018, TECH-024) |
| Reproducible starting conditions; deterministic test mode (§10.4, D16) | **PARTIAL** | seeded dice in parts; about 375 global random calls; no named streams (LORE-010, LORE-012, TECH-029) |
| Campaign integration, play after the crisis (Phase 10) | **MISSING** | LORE-016 |

### 4.7 Steward Mode, saves and long-term simulation integrity

| Requirement | Status | Evidence · gap |
|---|---|---|
| Versioned migrations, newer-schema refusal, real saves untouched by tests | COMPLETE | `t_saves` (22), schema **8**, `save_migrations.gd` |
| Golden saves from every released or playtested build | **PARTIAL** | goldens exist for 0.11.2, 0.12.4, 0.13.5, 0.14.6 only; **none from the playtest artifacts** 0.15 (schema 4), 0.16.19 (schema 7) or 0.16.21 (schema 8), which playtesters may hold (REL-010) |
| Money and goods conservation over long runs | COMPLETE (365 days) | `lw_soak` conservation checks |
| Long campaigns (multi-year) | **MISSING evidence** | no probe beyond one year (TECH-026, LORE-008) |

### 4.8 UI usability, performance, tutorials and release quality

| Requirement | Status | Evidence · gap |
|---|---|---|
| Progressive disclosure, blockers first (§3.2, §11) | COMPLETE (smithy) | `t_guide`, `t_ux_journey`, S2 clarity, OBS-01 … 61 |
| Compact panels, floating tooltips, icon categories, compact HUD, assignments-first hireling panel (§11 v1.7) | COMPLETE | OBS-69, 71, 73; `t_lw_ui` |
| Tutorials for the early game, minigames and Ironfront | COMPLETE | `t_s2_early`, `t_ironfront_intro`, minigame tutorials |
| Honest information everywhere (§11) | **PARTIAL** | the truthfulness gaps in §4.4 and EQ-053 |
| Performance | **PARTIAL** | seasons measured in rendered play; no frame or memory budget for multi-year saves |
| Human Windows gameplay acceptance (§11, REL-004) | **PARTIAL** | the user's own playtests produced OBS-22 … 76, but no acceptance has been recorded and no build since 0.14 is published |
| Regression gates in CI (TECH-014) | **PARTIAL** | CI runs tests only when release files change; rendered tests never run in CI; **a push to the default branch publishes a release** (`windows-installer.yml:150`) |
| Player and test documentation current (BUG-049, TECH-023) | **PARTIAL** | `game/docs` predate S2/LW/v1.6/v1.7 in places; `LIVING_REALM_STATUS.md` still frames "allegiance" |
| Final art | **PARTIAL** | all 918 sprites are `template_` placeholders; 19 pictures missing (Sprite Artist's Catalogue). The override system is ready; art production is the user's track, not a code build |

---

## 5. Release-quality status

| Gate | State |
|---|---|
| Integrated code on the default branch | **No.** 126 commits behind; a fast-forward is possible |
| Public build | build-0.14.6 only (GitHub latest release) |
| Automated suite | green: 272 compiled, 443/443 suite, 392/392 unit (17 Nov) |
| Rendered regression | per phase; no full 72-phase run since the Living Workshop |
| Soak | 365-day steward soak, both set-ups; nothing longer |
| Save migration | 0.11.2 → schema 8 proven for released builds; playtest builds unproven |
| Windows packaging | installer + install-and-launch smoke green (0.16.21, run 43475441787) |
| Human acceptance | observations only; no recorded acceptance of A1–v1.7 |

---

## 6. Kept separate: not requirements

These are **not** part of the finish line unless the user promotes them.

- **85 `PROPOSED` entries** (decision register §1.4) — e.g. PROP-022 … 050 balance follow-ups, hunting and the grocer, a
  dagger Design, cheap rings and amulets, more counter filters, steward stage claiming, per-type station caps; EQ-026
  unique Legendary names; LORE-009/012 (proposed, but the roadmap uses them as the means for approved requirements, see the
  roadmap). Default recommendation: **defer to post-1.0** except where a build brief names one as the chosen means.
- **Deferred by the user (S2 §8):** OBS-10 survival incentives, OBS-17 donating equipment, OBS-18 visible equipped gear,
  OBS-19 hand-designed adventurer looks, OBS-20 voices, OBS-35 hunting/grocer.
- **`UNDECIDED` older asks:** wall/doorway editing (WS-010, QST-023), multiplayer (HB-001), visible relationship meters
  (HA-029), cross-campaign comparison (HB-059, LORE-013), Danish localisation (UX-015, BUG-035, HA-010), caravan
  curiosities and compelling advanced requests (HB-060, HB-061), front entrance (OBS-32, QST-029).
- **`REJECTED` by canonical (stay out):** factory floor, freeform building, militia tactics, naval simulation, universal
  crafter, final-war questline, family-tree game, paid renown, separate Chronicle truth database (the existing one must be
  retired, not extended).
- **Optional polish:** softer terrain transitions (HB-062, partly done), slot filters on other counters (PROP-025), art
  (separate track).

---

## 7. Unresolved decisions (numbered; the roadmap says which build each one gates)

| # | Decision | Gates | Recommendation |
|---|---|---|---|
| **1** | **Integrate `65e70b5` into the default branch and publish a playtest release.** A push to the default branch publishes a release, because `game/RELEASE_VERSION` changes. | R1 | Approve a fast-forward at the end of R1 and publish it as **0.17.0**, the first public build since 0.14. |
| 2 | Relic identification semantics (EQ-007): keep the relic's uid and record "identified as …", or a new uid linked by an `identified_from` event? | R1 | Keep the uid when the relic is a single piece (it *is* the same object, now understood); split a stack first. |
| 3 | Rune socketing (BUG-042): may it raise rarity? | R1 | Keep name; allow Common→Magic only as a recorded "enchanted" event, never a rename. |
| 4 | Which remaining Gate A items close before new world features (QST-027). | R1/R2 | The R1 + R2 scope as written. |
| 5 | Hireling off-station production (STAFF-004/HA-025) and steward hiring (STW-018). | R1 | Retire off-station production (hirelings stay field staff); the steward does not hire before 1.0. |
| 6 | Lore retention and indexing policy (LORE-004). | R3 | Permanent: provenance, people, places, deaths, Epic, causal chains. Summarised: routine trade/work into monthly digests per actor/place. |
| 7 | Audiences and places for reputation (D10 open detail); is Reeve Tamsin Hale the mayor? | R2 (data model), R8 | Audiences: villagers, adventurers, traders, artisans/dwarves, nobility, each civilization. Places: village, region, each civilization. Promote the reeve to mayor. |
| 8 | Honor Guard naming: who names the named pieces? The commission subsidy (QST-024)? | R4 | The patron names them in the order; earned Epic stays separate. The subsidy is explicit and recorded, paid from the village purse. |
| 9 | Molds/patterns (D11): which operations? | R4 | Casting molds for 3–4 cast Designs, a pattern for one forged series; reusable, no wear. |
| 10 | Affix mechanics, Set rules, rune/arcane/alchemy boundaries (EQ-027, EQ-033). | R5 | Runes = permanent socketed effects; arcana = permanent deep properties on existing items (arcanist only); alchemy = temporary coatings/charges. Sets = 2- and 3-piece bonuses on 3 small sets. Affixes = 12 effects with real combat/decision hooks. |
| 11 | Damage states, restoration costs, heir eligibility, the literal "blood" medium (EQ-041). | R6 | States: worn → broken (half strength) → **disabled** (unusable, Reliquary-eligible) → destroyed (warned experiments only). Heirs only from recorded ownership or authored family. Blood as a symbolic consent ritual, not gore. |
| 12 | Sailors as a contact entity (D12); do escorts cover hireling runs, adventurer parties or both? | R7 | A light "contact" entity reusing the sponsor framework; escorts for both. |
| 13 | Role of bandits once the militia exists (WLD-010). | R8 | Bandit pressure scales down causally with the militia's real equipment and patrols. |
| 14 | **Civilization canon:** names, map, leaders, grievances, chronology; is the smith's home inside one of them (HB-058)? | R9/R10 | **User-authored.** Claude can offer a draft for approval. This is the single biggest creative input still missing. |
| 15 | Legacy copies of a Unique in pre-Run-0.1 saves (QST-028). | R5 | Show them as "a contemporary copy", not the artifact. |
| 16 | Epic for other makers' pieces (QST-022). | R5 | Yes, the history is the item's, not the maker's. |
| 17 | Baseline features that canonical never names (difficulty modes, talking items, Ironfront, romance, companions, Hall of Fame, ceremonies, funerals, fatigue, apprentice independence; decision register §1.5). | R11 | Confirm them in a v1.8 revision so 1.0 has no unlabelled scope. |
| 18 | The 85 `PROPOSED` entries. | — | Defer all to post-1.0 by default, rather than spend time on case-by-case triage. |
| 19 | What "1.0" means: art (final or template), audio, languages. | R11 | 1.0 = feature-complete + accepted; English only; template art allowed where creator art is not yet delivered. |

---

## 8. Register discrepancies noted (for the next register update — not changed here)

- The decision and roadmap registers stop at the Living Workshop (11 Nov); v1.5, v1.6 and v1.7 work appears only in the
  observation register and commit history.
- Roadmap register §1 still says "the latest release is build-0.14.6"; `RELEASE_VERSION` on the default branch reads 0.14,
  on the baseline 0.16.
- The roadmap register lists S2 and LW as "not integrated". This is still true, and now also covers the pilots, v1.6 and v1.7.

---

*Generated for the user's Final Completion Audit request, 17 November 2026. Evidence: code and tests at `65e70b5`;
registers as committed. Nothing in this document authorises implementation.*
