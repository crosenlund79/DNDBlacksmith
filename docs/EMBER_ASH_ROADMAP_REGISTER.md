# Ember & Ash — Roadmap Register

**Status:** tracking register, created in Run 0 (roadmap reconciliation), 10 November 2026, at development commit
`fa7b5b7` (A1, S1 and A2 integrated). **Updated in Run 0.1** (10 November 2026) on branch `claude/run0.1-integrity`.

**Authority.** The canonical roadmap is [`EMBER_ASH_CANONICAL_VISION.md`](EMBER_ASH_CANONICAL_VISION.md) §12: the original
creative Phases 0–10 remain canonical, and the gate letters A–J are a **recommended technical sequence, not implementation
approval** (§12.2). This register records where each milestone stands and what it depends on. It does not redesign,
reorder or authorise anything; where it notices a risk or a gap it says so and leaves the decision to the user.
Entry details live in [`EMBER_ASH_DECISION_REGISTER.md`](EMBER_ASH_DECISION_REGISTER.md) (IDs such as `TECH-018`) and
[`EMBER_ASH_PLAYTEST_OBSERVATIONS.md`](EMBER_ASH_PLAYTEST_OBSERVATIONS.md) (`OBS-nn`).

---

## 1. Where the project stands

| Milestone | Canonical anchor | State | Commit | In a release? | Evidence | Human acceptance |
|---|---|---|---|---|---|---|
| Pre-canonical baseline (first playable → Living Realm phases 1–5) | Phases 0–5, original scope | Delivered | `154d08a` | build-0.14.6 | 207/207 suite, 383/383 unit (architecture review, 9 Nov) | Not recorded (CV §2) |
| Canonical design locked (v1.0) | CLAUDE.md §2 | Done | `88980b1` | — | DOCX + Markdown | — |
| Canonical v1.1 (Steward Mode approved) | §4.5, D19, §12.2 | Done | `8904d36` | — | DOCX and Markdown identical (checked word for word in Run 0) | — |
| **A1** Protect the Foundation | Gate A (part) | Complete, integrated | `5b8af75` | No | `t_saves` (22 tests: golden saves 0.11.2–0.14.6, idempotence, newer-schema refusal, failure handling), `t_identity` (15, incl. the year-long integrity probe), CI test gate | No |
| **S1** Steward Mode | §4.5, D19, §12.2 priority | Complete, integrated | `e121241` (S1 head `bc9ba1e`) | No | `t_steward` (13, incl. 30- and 365-day soaks), `t_steward_ui` (7) | No |
| **A2** Workshop Reliability & Early-Game Experience | Gate A (part); OBS-01…09 | Complete, integrated | `fa7b5b7` (A2 head `e045d67`) | No | `t_economy_a2` (13), `t_experience_a2` (6), 48/48 rendered phases, Windows CI install-and-launch smoke (run 42727168523) | No |
| **Run 0** Roadmap reconciliation | CLAUDE.md §2, CV §16 | Complete | `3379375`, `f3c1505` | — | three registers | — |
| Canonical v1.2 (editorial clarifications) | CLAUDE.md §2.5 | Done in Run 0.1 | branch `claude/run0.1-integrity` | — | DOCX and Markdown identical (6,019 words) | — |
| **Run 0.1** Canonical corrections & critical integrity | D13, D14, D18; Gate A (part) | Complete on its isolated branch; not integrated | branch `claude/run0.1-integrity` | No | `t_run01` (8 tests), `t_identity` Unique audit, `t_saves` (schema 4), Steward soaks | No |

**Test status at `fa7b5b7`:** compile 221 scripts, suite 283/283, unit 384/384 (Run 0). Real saves untouched by tests
(`t_saves.test_mode_refuses_real_saves`).

**What players have:** the latest release is still **build-0.14.6** (`game/RELEASE_VERSION` 0.14). No published build
contains A1, S1 or A2, and none of them has been accepted by a person playing on Windows (REL-003, REL-004, REL-005).

**Residuals of delivered milestones** (approved, still partial; no milestone scheduled):
- S1: "political commitments" have nothing to defer until G/H/I exist (STW-014); some look-only panels keep minor action
  buttons enabled while the smith is away (STW-026, BUG-003).
- A1: a few exits from the forge still leave no transfer record, e.g. merchant restock (EQ-004); lost or destroyed pieces
  keep their Lore texts but no structured provenance tombstone (EQ-012).
- A2: affordability of ordinary gear for starting adventurers was investigated, not rebalanced; proposals await a decision
  (ECO-011, OBS-04, PROP-015 … PROP-017).
- Baseline: cloaks are not yet in class wish-lists (BUG-037).

**Remaining-work counts by target** (decision register; `APPROVED` + `PROPOSED` + `UNDECIDED`, not yet delivered):

| A-REM | B1 | B2 | C1 | D | E | F | G | H | I | J | BACKLOG |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 17 | 7 | 22 | 9 | 21 | 7 | 13 | 3 | 5 | 19 | 89 |

---

## 2. Milestone map

The Run 0 brief names the work after Gate A as B1, B2 and C1 and then D–J. Canonical §12.2 defines gates B and C; the
mapping used in the registers is:

| Milestone | Canonical gate (§12.2) | Creative phase (§12.1) | Gate wording | Entry condition (§12.3) |
|---|---|---|---|---|
| A-REM | A — Readiness | 0 | "human playtest, versioned save migrations and golden saves, item identity hygiene, trustworthy UI/repair fixes, CI regression tests and common entry points for danger/reputation" | — |
| B1 | B — Staff capability (worker side) | 1, 6 (foundations) | "Shared worker profiles … real profession ability; per-stage skill checks" | **Before B/C:** save migrations and canonical identity boundaries safe; real 0.14.6 gameplay assessed |
| B2 | B — Staff capability (smith and workshop side) | 1, 6 (foundations) | "smith tree and workshop knowledge" (Designs, CV §5) | as B1 |
| C1 | C — Staged production | 1, 5 | "Extend existing queues for several workers and one stable item identity; optional assistance and visible traversal. Prove one multi-discipline Design." | as B1 |
| D | D — Commissions v2 | 5 | "Bulk delivery records and multiple individually named prestige pieces; cooperative exceptional orders" | **Before D/F:** multi-stage production, item transfers and recipient records credible and testable |
| E | E — Equipment depth | 6 | "Advanced affixes, Arcana on existing items, relevant stats, meaningful Sets/Unique behavior, risks and restoration" | — |
| F | F — Negotiation and procurement | 4 | "Shared item valuation; goods-as-payment, escorts, maritime captains and rare supply journeys" | **Before D/F** (above) |
| G | G — World recognition | 7 | "Audience/place reputation; earned renown; credible visitors; independent militia and regional safety" | **Before G/H:** danger, reputation and delivered equipment effects share authoritative state |
| H | H — Regional proof | 9 | "A small, testable conflict with multiple autonomous outcomes, before expanding the civilizations" | **Before G/H** (above) |
| I | I — Civilizations and stories | 8 | "Scale only what H demonstrates; add conditional authored storylines and neutral dealings" | **Before I:** one regional crisis produces several believable outcomes, including de-escalation |
| J | J — Chronicle and campaign | 10 | "Consolidate Lore truth, summarization, long-term history and replayability" | **Before J:** Chronicle is a view of real Lore; routine compression cannot delete meaningful links |

Notes on the mapping (none of them changes canonical):
- **B1/B2 share one design problem.** The capability layer — workshop knowledge versus each actor's competence — appears as
  TECH-002 (B1) and STAFF-018 (B2). Whatever order B1 and B2 run in, the layer has to be designed once for both, together
  with the save migration for existing apprentices and for smiths who already hold high non-smithing levels (STAFF-012,
  STAFF-013, STAFF-015).
- **Per-stage skill checks** are listed by canonical under Gate B; the registers place them in B1 (PROD-009). C1 consumes
  them.
- **Sequence.** Canonical records S1 as the priority after A1 and before B–C (done). It records no ordering between the
  remaining Gate A items and B1; QST-027 asks which Gate A items must close before B/C. Canonical's only stated reordering
  is H before I ("first prove one region", §10.2).
- **Not placed by canonical:** duplicate stations (D6; WS-007, TECH-027), molds and patterns (D11; PROD-020), and the
  Reliquary / heir restoration (canonical leaves its placement within E, I and J open — EQ-041 … EQ-046, EQ-057). These sit
  in BACKLOG until the user places them.

---

## 3. Phase numbering: canonical versus the Living Realm brief

`game/docs/LIVING_REALM_STATUS.md` (and the status audit) use the Living Realm brief's own phases 1–10, which differ from
canonical Phases 0–10. Its phase 7 still reads "Autonomous civilizations, allegiance, world influence", ordered before the
regional prototype — against D15 and §10.2 (TECH-023, CIV-007). Mapping:

| Living Realm phase | Canonical phase (§12.1) | Gate (§12.2) | Standing at `fa7b5b7` |
|---|---|---|---|
| 1 (verify Windows 0.13) | — (not Phase 0: human acceptance still outstanding) | A | CI and rendered checks only; no human playtest recorded |
| 2 (evolving smithy, equipment presentation) | 1 + 2 | — | Delivered in 0.14.6 (original scope) |
| 3 (living adventurers) | 3 | — | Delivered in original scope; truthfulness gaps open (A-REM) |
| 4 (sponsored expeditions) | 4 | F (extensions) | Delivered in original scope; payment-in-equipment, escorts, maritime open |
| 5 (major commissions, workshop production) | 5 | C, D (extensions) | Delivered in original scope; multi-worker pieces, lots, Honor Guard open |
| 6 (affixes, Unique/Set, legacy) | 6 | E | Not started (refinement exists) |
| 7 (civilizations, allegiance, world influence) | 7 + 8 | G, I | Not started; "allegiance" superseded by D15 |
| 8 (stories, regional prototype) | 8 + 9 | H, I | Not started |
| 9 (campaign variation, chronicles) | 10 | J | Not started (a separate Chronicle store exists — a conflict) |
| 10 (broader conflict) | — | I | Not started |

Canonical adds what the Living Realm plan never had: the mayor and militia (§9.1), maritime captains (§8.3), the Reliquary
and heirs (§6.5–6.6), specialist work orders (§4.4) and Steward Mode (§4.5). The Living Realm plan had three items canonical
does not name: talking-item personalities (implemented; HB-050), cross-campaign comparison (HB-059, UNDECIDED) and the
smith's home kingdom (HB-058, UNDECIDED).

---

## 4. Milestones in detail

### 4.1 A-REM — remaining Gate A readiness

**Done in Gate A so far:** versioned migrations, golden saves, idempotence and newer-schema safety (A1); item identity
hygiene for records, trade, purchases and masterpieces (A1); the CI test gate before packaging (A1); one durability
threshold, adventurers paying for repairs and a named payer on every payment (A2); A2's usability fixes (OBS-01…09).

**Still open** (no milestone scheduled after A2; QST-027 asks which must close before B/C):
- **Acceptance:** human Windows gameplay acceptance of the current build (REL-004, UX-011) and of Steward Mode (REL-005,
  STW-027); a published build containing A1+S1+A2 with a human playtest note (REL-003, proposed); the "Before B/C" gate's
  "real 0.14.6 gameplay assessed" (TECH-033) — the user's playtest observations exist but the build they came from and an
  assessment record do not.
- **Common entry points:** one danger entry point (TECH-018, ADV-021) and one reputation entry point (TECH-019, WLD-013).
  Not started. They are the stated prerequisite for G and H (and for escorts in F).
- **Truthful UI and state:** live plans on character sheets, consultation threat data, scouting claims and rumours
  (TECH-017 cluster: ADV-012, ADV-017, WLD-018, WLD-019, LORE-015, UX-007); consultations must not redirect sponsored
  parties (ADV-018, TECH-021); retire the legacy expedition resolver (ADV-020, TECH-020, proposed).
- ~~**Money conservation (D14):** four leaks (ECO-042; BUG-038 … BUG-041).~~ Done in Run 0.1.
- **Identity hygiene, remainder:** relic identification mints a new uid (EQ-007); rune socketing renames pieces (BUG-042);
  a dismissed hireling's gear leaves no record (BUG-017); one item lookup for every system (EQ-006, QST-019, proposed);
  provenance created in a migration step rather than on first read (TECH-011, proposed); a golden save from the next
  release (REL-010, proposed).
- **Documents:** reconcile the repository roadmap note with canonical (TECH-023) and bring player/test docs up to date
  (BUG-049).
- **UI defects:** contracts panel on a closed order (BUG-001); panels fit (UX-013); loot bags and materials under the Loft
  stair (OBS-13, OBS-14); apprentices visible at work, needs a repro (OBS-21).

All A-REM entries:

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| GOV-008 | APPROVED | PARTIAL | Status reporting keeps implemented / design approved / being evaluated / not approved visibly separate; |
| GOV-010 | APPROVED | PARTIAL | §16.2 safety contract per implementation run: |
| GOV-015 | APPROVED | PARTIAL | Autonomy is real: NPC actions, inventories, relationships and plans reflect simulation state, never fabricated flavour. |
| GOV-020 | APPROVED | PARTIAL | Clarity without overload: the player understands actions, blockers and reasonable next steps. |
| TECH-001 | APPROVED | PARTIAL | Gate A readiness complete: human playtest, versioned migrations + golden saves, item identity hygiene, trustworthy UI/repair fixes, CI … |
| TECH-011 | PROPOSED | NOT STARTED | No state-changing reads: legacy items' provenance created in a migration step, not lazily on first read. |
| TECH-014 | APPROVED | PARTIAL | Stronger regression/release gates for Phase 0 beyond the smoke test. |
| TECH-017 | APPROVED | NOT STARTED | Truthful UI: plans, advice threats, power ratings, rumours and toasts derive from live state and the same models used for decisions. |
| TECH-018 | APPROVED | NOT STARTED | One common danger entry point used by decisions, combat, advice, sponsorship and hirelings. |
| TECH-019 | APPROVED | NOT STARTED | One common reputation entry point (facade) so no new code reads `Shop.reputation()` directly. |
| TECH-020 | PROPOSED | NOT STARTED | Legacy expedition resolver removed (old saves' away adventurers migrated), docs updated. |
| TECH-021 | APPROVED | NOT STARTED | A consultation must not silently redirect a sponsored party (respect sponsor objectives or make the conflict explicit). |
| TECH-023 | APPROVED | NOT STARTED | Repository roadmap documents reconciled with the canonical phases (no "allegiance", World Recognition phase present, regional proof before … |
| TECH-033 | APPROVED | PARTIAL | "Before B/C" gate: save migrations and canonical identity boundaries safe; |
| REL-003 | PROPOSED | NOT STARTED | A Windows build containing the Gate A work (A1 + S1 + A2) is published, with a human playtest note attached. |
| REL-004 | APPROVED | PARTIAL | Human Windows gameplay acceptance (real play, equipment UI, production routing, rendered screenshots); |
| REL-005 | APPROVED | NOT STARTED | Player acceptance of Steward Mode on Windows (steward performance vs active play, welcome-back report, rarity of sealed letters). |
| REL-010 | PROPOSED | NOT STARTED | A golden save from the next released build (schema 3, with steward and payment keys) is added the same authentic way. |
| STW-027 | APPROVED | NOT STARTED | A human player accepts Steward Mode on Windows (steward performance against active play, how the report reads, how rare letters are). |
| EQ-006 | PROPOSED | PARTIAL | One lookup used by every system. Today `find_uid_anywhere`, `History.find_item` and `ItemStory.find` go through the registry but keep their … |
| EQ-007 | APPROVED | NOT STARTED | Identifying a relic keeps the identity chain. |
| ADV-012 | APPROVED | NOT STARTED | Character sheets and talk show truthful plans: |
| ADV-017 | APPROVED | PARTIAL | Consultation advice uses the same threat data adventurers actually fight. |
| ADV-018 | APPROVED | NOT STARTED | Sponsored expeditions pursue the agreed objective: |
| ADV-020 | PROPOSED | NOT STARTED | One expedition resolver: the legacy adventurer resolver is retired, old saves' away adventurers are migrated, and the docs updated. |
| ADV-021 | APPROVED | NOT STARTED | One authoritative danger model with a common entry point, used by adventurer decisions, consultations, sponsorship, hirelings, scouting and … |
| WLD-013 | APPROVED | NOT STARTED | A common reputation entry point (facade) so no new code reads the global number directly before audience/place reputation arrives. |
| WLD-018 | APPROVED | NOT STARTED | Scouting knowledge and its claims ("told you the safe paths", "lowers danger for everyone") must affect the danger model adventurers … |
| WLD-019 | APPROVED | PARTIAL | Village talk and rumours derive from real state; |
| UX-007 | APPROVED | PARTIAL | Honest information: progress, work stages, plans, risk, availability, reputation and histories shown in the UI come from actual state. |
| UX-011 | APPROVED | PARTIAL | Validate real Windows gameplay and rendered screenshots as UX acceptance; |
| UX-013 | APPROVED | PARTIAL | Panels fit and stay readable on the 1920×1080 canvas (1600×900 scaled) with no overflow and no hidden controls. |
| LORE-015 | APPROVED | NOT STARTED | Tavern rumours and table talk come from real Lore and state, not invented template facts. |
| BUG-001 | APPROVED | NOT STARTED | Contracts panel opened directly on a closed order must not collapse its right column to one letter per line. |
| BUG-017 | APPROVED | NOT STARTED | A dismissed hireling who leaves with gear in their name records a hand-over event. |
| BUG-042 | APPROVED | NOT STARTED | Socketing a runestone must not overwrite a piece's name or silently change its rarity. |
| BUG-049 | APPROVED | PARTIAL | Player, test and design documents describe the current build. |
| QST-015 | APPROVED | PARTIAL | Decided: "This Master Design / original phase numbering govern; |
| QST-019 | UNDECIDED | NOT STARTED | Should all item lookups (`find_uid_anywhere`, `History.find_item`, `ItemStory.find`) search every holder? Affects Hall of Fame discovery … |
| QST-027 | UNDECIDED | NOT STARTED | Which remaining Gate A items must close before B/C? CV §12.3 "Before B/C" names only migrations, identity boundaries and real 0.14.6 … |
| OBS-13 | APPROVED | NOT STARTED | Loot bags appear beneath the stairs (observation register) |
| OBS-14 | APPROVED | NOT STARTED | Processed materials appear beneath the stairs (observation register) |
| OBS-21 | APPROVED | PARTIAL | Apprentices visible at their workplaces (observation register) |

### 4.2 B1 — worker capabilities and professions

**Purpose (CV §4.2–4.3, D1, D2, D7):** specialists with a personal profession and real ability own their craft; a shared
worker-profile foundation for apprentices and field hirelings without a wholesale merge; herbalism within the Alchemist.
**Today (verified):** no `profession` field anywhere; apprentices may only make what the smith has learned (a test enforces
it); hirelings produce goods with no station and follow different staff rules; the smith's levels still decide 17
cross-discipline behaviours. **Depends on:** the "Before B/C" gate (TECH-033); the professions decision (STAFF-012); a
save-migration step for existing apprentices and hirelings (cross-cutting); the B2 capability layer. **Decisions:** exact
professions and migration (STAFF-012); the future of hireling off-station production (STAFF-004, HA-025); whether the
steward may hire (STW-018). **Risks:** `t_apprentices` and `t_progression` encode the old model and need a parallel
specialist route rather than silent edits; A2's request-feasibility checks (`Shop.slot_capability`, `Adv.can_commission`,
`Contracts._offerable`) rest on the player's gating and must follow the move; the steward's capability checks
(`_order_plan`) must be extended (STW-008, STW-025).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| TECH-002 | APPROVED | NOT STARTED | Capability layer: workshop knowledge separated from actor competence; |
| TECH-004 | APPROVED | NOT STARTED | Shared worker profile for apprentices and hirelings; |
| TECH-028 | PROPOSED | NOT STARTED | Room tier derives from the room's specialists, stations and work, not the player's skill. |
| WS-006 | PROPOSED | NOT STARTED | Room tier derives from the room's specialists, stations and work done, not from the player's level; |
| STAFF-002 | APPROVED | PARTIAL | A shared worker-profile foundation (profession, skills, progression, basic employment logic) for both families. |
| STAFF-004 | PROPOSED | NOT STARTED | Route hireling workshop production through apprentice-style station tasks, or retire it, leaving hirelings as field/expedition staff. |
| STAFF-005 | APPROVED | PARTIAL | Workshop specialists perform suitable work at actual stations. |
| STAFF-006 | APPROVED | NOT STARTED | Specialists own their craft: high-end rune work, arcana, leatherwork and alchemy require qualified people, and staff are not limited to … |
| STAFF-007 | APPROVED | NOT STARTED | Each specialist has a personal profession with real ability (runesmith, arcanist, alchemist, leatherworker/tailor; |
| STAFF-008 | APPROVED | NOT STARTED | Herbalism expertise sits within the Alchemist profession (D7). |
| STAFF-012 | UNDECIDED | NOT STARTED | Exact professions, skill numbers, migration and compatibility, including which existing apprentices become which specialists. |
| STAFF-016 | APPROVED | PARTIAL | Personal specialist progression: profession skills, experience and character progression (D3). |
| PROD-009 | APPROVED | NOT STARTED | Per-stage qualification and skill checks: |
| UX-004 | APPROVED | NOT STARTED | Crafting guidance names the missing qualified worker or specialist instead of telling the smith to raise his own non-smithing skill, once … |
| QST-001 | APPROVED | NOT STARTED | Decided: "Keep distinct workshop and field staff entities with a shared worker-profile foundation." |
| QST-002 | APPROVED | NOT STARTED | Decided: "Basic other-craft knowledge is allowed; |
| QST-007 | APPROVED | NOT STARTED | Decided: "Herbalism sits within the Alchemist profession; |

### 4.3 B2 — the smith's specialisation and workshop Designs

**Purpose (CV §4.2, §5, D2, D3):** a deep personal smithing tree, a shared workshop catalogue of Designs, techniques and
tools, and only basic non-smithing work for the smith. **Today:** one broad skill tree in which the smith can master every
discipline — rejected by CV §1.3 and D2 but live in code (STAFF-014, GOV-026, HA-027, HB-019); "Design" exists only as
player-facing wording in places and as the separate equipment-designer panel (HB-027). **Depends on:** the capability layer
shared with B1; a save-safe migration for smiths who already hold high non-smithing levels. **Decisions:** the ceiling of
the smith's "basic" competence and what happens to existing high levels (STAFF-013, STAFF-015); how the designer panel
relates to canonical Designs. **Do not** rename recipe ids to "design" (626 identifier uses; AR §5.4, PROP-011).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| STAFF-013 | APPROVED | NOT STARTED | Smith competence (D2): basic other-craft work is allowed for continuity, never equal to a true specialist; |
| STAFF-015 | APPROVED | PARTIAL | The smith's progression becomes a deep smithing tree (personal techniques and mastery), evolved carefully from the broad tree with … |
| STAFF-017 | APPROVED | NOT STARTED | Workshop knowledge: a shared catalog of known Designs, techniques, tools, stations, rooms and feasible combinations, distinct from the … |
| STAFF-018 | PROPOSED | NOT STARTED | Capability layer: route every cross-discipline gate and scaling through workshop knowledge (what the forge knows) vs actor competence (who … |
| PROD-018 | APPROVED | PARTIAL | Designs are the player-facing complete production plans (materials, stages, stations, tools, specialist requirements); |
| PROD-019 | APPROVED | PARTIAL | Techniques belong to the individual actor's knowledge; |
| QST-003 | APPROVED | NOT STARTED | Decided: "Deep smithing tree + workshop Designs/knowledge + personal specialist progression." |

### 4.4 C1 — staged collaborative production

**Purpose (CV §4.4, D4, D8):** several qualified workers perform the stages of one order on one item identity at visible
stations; the player may claim a stage; optional, non-blocking help requests; contributors credited; one multi-discipline
Design proved end to end. **Today (verified):** no multi-worker production — an apprentice task has one worker who becomes
the maker; the only multi-hand case is abstract contract hours. Production already exists in four shapes (the smith's
craft job, apprentice tasks, contract hours, the designer panel's staged plan); C1 should reconcile them rather than add a
fifth. **Depends on:** B1 (profession ability, per-stage checks), the D6 decision on duplicate stations (station ids are
keys in Property, Apprentices, World and Contracts), the reserved-uid approach (PROD-011), identity through stages (EQ-010),
the CV §15 open details on assistance and quality (PROD-016) and routing/queue UI (PROD-023). **Must keep working:** the
"contract" task kind, the steward's use of the apprentice API (STW-025), save compatibility for in-flight single-worker
tasks. **Latent defect:** on a re-pinned apprentice task the finishing worker becomes the maker (`apprentices.gd:1484`) —
in staged work that would make the last specialist the maker (PROD-010).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| TECH-003 | APPROVED | NOT STARTED | Staged multi-worker work order: per-stage assignee/state/quality, reserved uid at start, player can claim a stage. |
| WS-012 | APPROVED | PARTIAL | Staff visibly work at real stations and visibly travel between them, including stairs/lift to the Loft; |
| PROD-001 | APPROVED | PARTIAL | Core loop: materials and opportunity → select a Design → smithing → specialists contribute at real stations → collect the finished item → … |
| PROD-002 | APPROVED | PARTIAL | Ordinary work (a dagger, a repair) stays direct and readable; |
| PROD-004 | APPROVED | NOT STARTED | Journey "the collaborative masterpiece": the smith forges, a runesmith, alchemist and leatherworker perform their stages at visible … |
| PROD-005 | APPROVED | NOT STARTED | True multi-worker work orders: different workers perform different stages of one order and one item. |
| PROD-006 | APPROVED | PARTIAL | The player chooses the Design and selects the relevant specialists for its stages. |
| PROD-007 | APPROVED | NOT STARTED | Employees ordinarily coordinate and perform handoffs between stages; |
| PROD-008 | APPROVED | NOT STARTED | The player can intervene in, or claim, a relevant stage of an order and personally perform it. |
| PROD-010 | APPROVED | PARTIAL | One stable item identity through every stage; |
| PROD-011 | PROPOSED | NOT STARTED | Reserve the uid when the order starts and keep the item un-materialised until completion. |
| PROD-012 | APPROVED | PARTIAL | Contributor credit in production (D4): the original maker, the workshop and each specialist contributor receive separate, appropriate credit. |
| PROD-013 | PROPOSED | NOT STARTED | Record `prov.contrib[]` {who, stage, station, day, quality} at completion; |
| PROD-014 | APPROVED | NOT STARTED | Help requests (D8) arise naturally from real, difficult work, are nonintrusive and normally optional; |
| PROD-016 | UNDECIDED | NOT STARTED | Quality formulas, assistance chance/frequency, exceptional-work thresholds and the effect of declining. |
| PROD-022 | APPROVED | PARTIAL | The production ledger shows stages, who, where, progress and blockers from real state; |
| PROD-023 | UNDECIDED | NOT STARTED | Individual worker routing and queue UI details. |
| PROD-026 | PROPOSED | NOT STARTED | Use the Emberwarden Longsword (forge → anvil → rune_engraving_stand → cauldron → grinding_wheel → stitching_table) as the one … |
| EQ-010 | APPROVED | NOT STARTED | Specialist contributors to one item (runesmith, alchemist, leatherworker stages) are recorded separately on the same item without changing … |
| UX-009 | APPROVED | NOT STARTED | Equipment presentation shows fully truthful item credits (maker, workshop, specialist contributors), legacy and upgrades. |
| QST-004 | APPROVED | NOT STARTED | Decided: "Original maker, workshop and specialist contributors can all receive appropriate, separate credit." |
| QST-008 | APPROVED | NOT STARTED | Decided: "Real-work-driven, nonintrusive, normally optional; |

### 4.5 D — Commissions v2

Bulk delivery lot records to recipients, several individually named prestige pieces in one order, cooperative exceptional
orders. **Depends on:** C1 (staged work orders, one identity per piece); a recipient entity for lots (the Muster and the
Watch exist only as contract patrons); contract history is capped at 30 entries (BUG-048). **Decisions:** who names Honor
Guard pieces (distinct from earned Epic); the size of the village subsidy (PROP-013, QST-024).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| TECH-031 | APPROVED | NOT STARTED | Bulk deliveries write lot records to recipients; |
| PROD-015 | APPROVED | NOT STARTED | Only expressly flagged exceptional commissions may require the smith's cooperation (D8 required case). |
| PROD-025 | PROPOSED | NOT STARTED | Run Project Bench stages through staged work orders, with quality from the actual worker's competence. |
| ECO-023 | APPROVED | PARTIAL | Each bulk delivery leaves a persistent lot/delivery record (what, how many, quality, contributors, recipient) that grounds credible … |
| ECO-024 | APPROVED | NOT STARTED | A prestigious commission may contain one or several individually named, persistent exceptional pieces, each with its own identity, makers, … |
| ECO-025 | APPROVED | NOT STARTED | Exceptional, clearly flagged commissions may require the smith's cooperation (help); |
| ECO-026 | APPROVED | PARTIAL | Journey "The Honor Guard": a patron orders standard quantities plus several named, persistent exceptional pieces, and the Project Bench, … |
| ECO-027 | APPROVED | PARTIAL | Acceptance gate before Commissions v2 (D) and Negotiation & procurement (F): |
| QST-005 | APPROVED | PARTIAL | Decided: "Ordinary bulk units plus honest delivery/lot records; |

### 4.6 E — Equipment depth

Affixes with real effects, Arcana on existing items, Sets and a true one-of-one Unique, reworking risk and restoration.
**Depends on:** B1 (specialists own rune, arcane and alchemical work); colliding legendary names (EQ-026) — duplicate Uniques were resolved in Run 0.1 (EQ-024; what old saves' legacy copies
should show is QST-028); an "unusable" item state (only "broken", which
still works at half strength, exists) before the Reliquary. **Decisions:** affix mechanics and rune/arcane/alchemy
boundaries (EQ-027, EQ-033); whether socketing may change rarity (BUG-042); whether other makers' pieces may become Epic
(QST-022); where the Reliquary and heir restoration belong (canonical: E, I or J).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| EQ-022 | APPROVED | PARTIAL | Affixes and rarity have a meaningful influence on actual adventurer decisions (purchases, consultations) and outcomes (combat, expeditions). |
| EQ-023 | APPROVED | PARTIAL | Diablo-like variety: interesting affixes and distinctive magical effects rather than a "Sword +1" ladder (TECHNICAL RECOMMENDATION: |
| EQ-024 | APPROVED | PARTIAL | Unique: a defined Unique artifact exists in exactly ONE authentic instance per campaign and cannot respawn as a duplicate after sale, loss … |
| EQ-025 | APPROVED | NOT STARTED | Set: a collection category with distinctive combined-use mechanics (the exact bonus rules are open). |
| EQ-026 | PROPOSED | NOT STARTED | Legendary names are unique per world, so returning-item recognition never confuses two "Emberfang"s. |
| EQ-027 | UNDECIDED | NOT STARTED | Still to determine: exact affix mechanics, Set bonus rules, the boundaries between arcane and runic effects, and rarity balance. |
| EQ-029 | APPROVED | PARTIAL | Runesmiths inscribe persistent rune effects on existing items; |
| EQ-030 | APPROVED | NOT STARTED | Arcanists can enchant EXISTING equipment years after it was forged, adding deeper arcane properties while its identity, maker and history remain. |
| EQ-032 | APPROVED | PARTIAL | An old, famous piece can become better without becoming a different item: |
| EQ-033 | APPROVED | NOT STARTED | Rune, arcane and alchemical effects get formal, non-duplicated boundaries (permanent vs temporary, and who may apply what). |
| EQ-038 | APPROVED | NOT STARTED | Advanced reforging, rune and arcane improvements carry meaningful risk (damage, dormant enchantments, unstable properties, a difficult … |
| EQ-039 | APPROVED | NOT STARTED | Only an explicitly communicated, extraordinary experiment may permanently destroy the physical item, and its historical record endures. |
| EQ-040 | APPROVED | PARTIAL | A difficult failure may break or disable an item: |
| EQ-052 | APPROVED | PARTIAL | Equipment presentation shows material/craftsmanship, mechanical rarity, affixes and earned Epic history separately. |
| EQ-053 | APPROVED | PARTIAL | Displayed stats are truthful: whatever a sheet or tooltip shows must affect the simulation, or be labelled as not doing so. |
| EQ-056 | APPROVED | PARTIAL | Journey "The famous sword returns": the sword is sold, used in real adventures, earns Epic recognition, is inherited, and is later … |
| EQ-058 | APPROVED | NOT STARTED | Journey "The cost of ambition": an extraordinary, clearly warned reworking fails; |
| BUG-027 | APPROVED | NOT STARTED | Consultation "upgrade" advice can propose refining the adventurer's own piece, not only a commission. |
| QST-013 | APPROVED | PARTIAL | Decided: "Exactly one authentic defined Unique artifact per campaign; |
| QST-017 | APPROVED | NOT STARTED | Decided: "Arcanists may enchant and specialists may refine old existing artifacts while identity remains." |
| QST-028 | UNDECIDED | NOT STARTED | What should a legacy copy of a Unique show the player? Saves from before Run 0.1 may hold more than one Grimhold: |

### 4.7 F — Negotiation, trade and procurement

Shared item valuation, goods as payment, escorts, named sea captains and rare supply journeys. **Depends on:** a shared
valuation replacing about ten price routines (ECO-031, TECH-030); the danger entry point (TECH-018) for escorts; the
"Before D/F" gate. **Decisions:** how sailors are represented (a contact entity rather than plain adventurers; D12 and AR
§5.4), whether escorts cover hireling mine runs, adventurer parties or both. Build on `trade.gd` (CV §7.1).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| TECH-030 | APPROVED | NOT STARTED | Shared item valuation (value to this NPC) replacing ~10 price/negotiation routines. |
| ECO-030 | APPROVED | NOT STARTED | Adventurers may accept gold, crafted equipment or a combination for expeditions, protection and procurement; |
| ECO-031 | APPROVED | PARTIAL | Offers and counter-offers reflect each person's actual needs, personality, relationships, available funds, danger and how useful the … |
| ECO-032 | APPROVED | NOT STARTED | Expeditions and mine runs can negotiate escorts and protection, priced on actual regional danger, as a real risk/benefit choice. |
| ECO-036 | APPROVED | NOT STARTED | The docks offer named, persistent sailors and captains with personalities, skills, availability, relationships and voyage histories, … |
| ECO-037 | APPROVED | NOT STARTED | A captain can be asked to obtain a specialty good: |
| QST-012 | APPROVED | NOT STARTED | Decided: "Named persistent sailors/captains with relationships and simplified real voyages." |

### 4.8 G — World recognition

Reputation by audience and place with gradual spread, earned renown, credible visitors, an independent mayor and militia
equipped by commissions. **Depends on:** the reputation and danger entry points (A-REM), lot records (D), a civic entity
with a real budget (D14), defined audiences and places (D10 open detail). Renown can no longer be bought (removed in Run 0.1; GOV-030, WLD-015);
what remains is credible, regional spread of acclaim. **Decisions:** audiences and places; whether Reeve
Tamsin Hale is the canonical mayor; the role of bandits once militia protection exists (WLD-010).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| WLD-005 | APPROVED | NOT STARTED | The frontier town has an independent mayor: |
| WLD-006 | APPROVED | PARTIAL | The independent militia is equipped through commissions, and delivered goods leave believable traces in the recipient organization (its … |
| WLD-007 | APPROVED | NOT STARTED | Militia equipment improves regional security and mining/trade risks indirectly, gradually and causally — no magical hard-edged safe circle; |
| WLD-009 | APPROVED | PARTIAL | Map feedback on danger/safety is permitted only if it reflects real conditions. |
| WLD-010 | UNDECIDED | NOT STARTED | Decide the role of bandit encounters once militia protection exists ("fewer bandit runs?"). |
| WLD-011 | APPROVED | PARTIAL | Reputation differs by community/profession, person, institution and geography (dwarven artisans, adventurers, traders, nobles, each … |
| WLD-012 | APPROVED | NOT STARTED | News and reputation spread gradually through travel, letters, goods, events and relationships — no instant worldwide fame meter. |
| WLD-014 | APPROVED | NOT STARTED | Danger, reputation and delivered-equipment effects share authoritative state before Gates G/H. |
| WLD-015 | APPROVED | PARTIAL | Renown cannot be purchased: acclaim follows deeds and credible spread; |
| WLD-016 | APPROVED | PARTIAL | Renowned merchants, adventurers and patrons who come are credible persistent people with reasons to come, not rank rewards. |
| WLD-021 | APPROVED | NOT STARTED | Proof journey "A town safer by craftsmanship": |
| QST-010 | APPROVED | NOT STARTED | Decided: "Audience- and place-dependent, gradual information spread through real-world channels." |
| QST-018 | APPROVED | PARTIAL | Decided: "Reputation cannot be bought directly; |

### 4.9 H — Regional crisis proof

A small, testable conflict with several autonomous outcomes including de-escalation. **Depends on:** "Before G/H"; seeded
RNG streams (about 375 global random calls today; LORE-012, CIV-003); Lore roles and indices for conditions.

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| CIV-002 | APPROVED | NOT STARTED | Regional crisis prototype first: a small conflict with a limited cast, interests and locations, showing that equipment, relationships, … |
| CIV-003 | APPROVED | PARTIAL | The crisis proof is testable: reproducible controlled randomness lets unchanged play be compared with changed supply, sponsorship, … |
| LORE-012 | PROPOSED | NOT STARTED | Named, seeded RNG streams per subsystem, so that "unchanged vs changed" campaign comparisons are possible. |

### 4.10 I — Civilizations and authored stories

Only after H succeeds. **Decision:** whether the smith's home lies within one civilization (HB-058).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| CIV-001 | APPROVED | NOT STARTED | Two substantial civilizations (the player's kingdom and a neighbour) with histories, cultures, leaders, champions, competing resource … |
| CIV-004 | APPROVED | NOT STARTED | Freedom of association: the smith may work for either or both civilizations, stay neutral, encourage understanding or ignore high politics; |
| CIV-005 | APPROVED | NOT STARTED | Proof journey "A credible neutral smith": |
| CIV-006 | APPROVED | PARTIAL | Authored conditional stories become eligible only when real world state supports them, take participants, timing and history from the … |
| HB-058 | UNDECIDED | NOT STARTED | The smith's home lies geographically within the starting Kingdom (one of the two civilizations) while he remains an independent craftsman. |

### 4.11 J — Chronicle and campaign

Lore as the single source, the Chronicle as a view, a retention policy that summarises routine activity without losing
meaningful links. **Conflict to resolve:** a separate 400-entry Chronicle store exists beside Lore and is read as
authoritative (LORE-017, GOV-031). **Depends on:** the retention decision (LORE-004), Lore indices, roles and causal links;
converting pre-Iteration-011 Chronicle entries; a multi-year probe (TECH-026, proposed).

| ID | Scope | Delivery | Requirement |
|---|---|---|---|
| GOV-016 | APPROVED | PARTIAL | History persists: significant item, person, ownership and world consequences are not casually reset. |
| TECH-024 | APPROVED | NOT STARTED | Lore stays performant and truthful over long campaigns: |
| TECH-026 | PROPOSED | NOT STARTED | 3–5-year campaign probe (Lore growth, scan cliff, save size) before Chronicle work. |
| TECH-029 | APPROVED | PARTIAL | Deterministic test mode / named RNG streams as needed; |
| LORE-002 | APPROVED | PARTIAL | Lore coverage: every significant world event is recorded in Lore, and the other records (Chronicle feed, journal, memorial, Hall of … |
| LORE-003 | APPROVED | NOT STARTED | Chronicle of the Realm: a readable campaign-history view of actual shared Lore (adventurers, famous equipment, places, workshop … |
| LORE-004 | UNDECIDED | NOT STARTED | Decide the exact Lore indexing and retention policy and the chronology screens. |
| LORE-005 | APPROVED | PARTIAL | Keep consequential history and item provenance permanently. |
| LORE-006 | APPROVED | PARTIAL | As campaigns grow, routine low-value activity may be summarised, without erasing meaningful item events, personal histories or causal chains. |
| LORE-007 | APPROVED | NOT STARTED | Lore events keep roles and causal links, so the Chronicle and any compression keep "why" chains. |
| LORE-008 | APPROVED | NOT STARTED | Lore growth and performance stay acceptable over many in-game years (uncapped Lore growth is flagged). |
| LORE-009 | PROPOSED | NOT STARTED | Index Lore by kind, actor, item and place; |
| LORE-010 | APPROVED | PARTIAL | A world seed produces reproducible starting conditions; |
| LORE-014 | APPROVED | NOT STARTED | Before J: tests prove that the Chronicle is a view of real Lore and that routine compression keeps every meaningful link. |
| LORE-016 | APPROVED | NOT STARTED | Phase 10, campaign integration: a long-term chronicle, campaign differences, coherent consequences and continued play after the crisis. |
| BUG-018 | APPROVED | NOT STARTED | Pruned routine Lore events must not leave adventurer histories silently skipping; |
| PROP-008 | PROPOSED | NOT STARTED | Chronicle "why" view showing an event's causal chain from Lore links. |
| QST-009 | APPROVED | PARTIAL | Decided: "Keep significant history and item provenance permanently; |
| QST-016 | APPROVED | PARTIAL | Decided: "Reproducible beginnings, emergent and potentially different histories; |

### 4.12 BACKLOG

92 entries have no canonical placement or are proposals not yet placed. By prefix: `TECH` 2, `WS` 3, `STAFF` 1, `PROD` 1, `STW` 2, `EQ` 9, `ECO` 2, `ADV` 1, `UX` 1, `LORE` 1, `BUG` 28, `PROP` 20, `QST` 7, `HA` 5, `HB` 9.
Items that need a placement decision rather than a scope decision: duplicate stations (WS-007, TECH-027), molds and
patterns (PROD-020), the Reliquary and heirs (EQ-041 … EQ-046, EQ-057), steward hiring (STW-018), apprentice economics
(STAFF-019, TECH-032, HB-053). All `PROPOSED` entries are listed in the decision register §1.4.

---

## 5. Cross-cutting requirements (every milestone)

- **Safety contract (CV §16.2; GOV-009, GOV-010, REL-009):** verify repository, branch, remote and project; secure a
  recovery point; contained, testable changes; automated and rendered regressions; Windows packaging; honest reporting.
- **Identity (CV §6.1; TECH-005, EQ-001 … EQ-005):** one canonical object per uid through every new feature; the year-long
  integrity probe stays green (TECH-025).
- **Saves (TECH-006 … TECH-010):** every structural change ships a version step and keeps all golden saves loading.
- **Art overrides (GOV-013, UX-010):** `template_` sprites are fallbacks; a creator's own art is never overwritten.
- **Honest information (CV §1.2, §11; UX-007):** new UI derives from live state.
- **Steward compatibility (STW-025):** B1 and C1 must extend the steward's duties and capability checks; the decision
  layer must stay compatible with the multi-specialist workshop (CV §12.2).
- **Ordinary work stays direct (CV §3.1; PROD-002).**
- **Boundaries (CV §1.3, §15; GOV-022 … GOV-035):** no factory floor, freeform building, militia tactics, naval
  simulation, universal crafter, final-war questline, family-tree game, paid renown or separate Chronicle database.
- **Acceptance (CV §11; REL-004):** CI smoke is not acceptance; human Windows play is.
- **Performance (LORE-008):** nothing has been tested beyond 365 in-game days.
- **CI caution:** the Windows workflow publishes a release whenever it runs on the default branch
  (`windows-installer.yml:150`), including a manual dispatch. Verification runs belong on a non-default branch.

---

## 6. Missing dependencies

1. **"Before B/C" (CV §12.3) is only partly met.** Migrations and identity are done (A1); the "real 0.14.6 gameplay
   assessment" has no record, and no build containing A1–A2 has been played by a person (TECH-033, REL-003, REL-004).
2. **Gate A's common entry points for danger and reputation were never built** (TECH-018, TECH-019), yet G, H and F's
   escorts depend on them; the "Before G/H" condition has no prerequisite in place (WLD-014).
3. **B1/B2 need decisions that canonical leaves open:** professions and migration (STAFF-012, CV §15 row 2), the smith's
   basic ceiling (STAFF-013).
4. **C1 needs:** the D6 placement for duplicate stations, CV §15 open details (PROD-016, PROD-023), the reserved-uid design
   (PROD-011), identity through stages (EQ-010).
5. **D and G need a recipient/civic entity** for lot records and militia equipment; none exists, and the village purse
   has no budget (D14 for any mayor-paid commission).
6. **E needs B1** (specialist ownership of runes, arcana, alchemy), an unusable-item state for the Reliquary and a counter service for refining an adventurer's own piece (EQ-032).
7. **F needs a shared valuation** and the danger entry point.
8. **H needs seeded RNG streams and Lore indices; J needs the retention decision** and the Chronicle migration.
9. **A2's request feasibility rides on the player's skill gating** and must move with B1/B2.

## 7. Duplicated work and overlaps

- Production in four shapes (smith's job, apprentice tasks, contract hours, designer plan); contribution recorded in three
  unconnected places; two assistance mechanisms.
- Two staff systems implementing wages, applicants, traits and logs twice.
- About ten price and valuation routines (`Trade.price_factor` is a verbatim copy of `Commerce.price_factor`); difficulty
  factors applied in three places.
- Three danger models, two threat datasets, two destination planners, two adventurer-strength formulas.
- Reputation-like values in five places and three notions of "renown".
- Two history stores (Lore and the capped Chronicle) plus journal and memorial; Epic and Hall of Fame awarded by matching
  Chronicle text; famous pieces tracked twice (Hall of Fame board capped at 80, item-story register uncapped).
- Two "design" concepts (the equipment-designer panel and canonical Designs).
- In the registers: 45 clusters of entries that describe the same requirement from different sources (decision register
  §1.7).

## 8. Conflicts

- **Code versus canonical:** two rejected behaviours are live — the smith masters every craft (to be retired with B2)
  and a separate Chronicle store (preserved and documented by the user's decision until Gate J); renown bought with gold
  was removed in Run 0.1 — and further code falls short of approved requirements (decision register §1.3).
- **Repository documents versus canonical:** `LIVING_REALM_STATUS.md` ("allegiance", phases 4–5 "Done" against original
  scope only, Windows 0.13 "playtested" on CI evidence); `GAMEPLAY.md` "Nobody is locked to a profession" (true of the code,
  not marked as superseded by D2/D7); `ITERATION_011_AUDIT.md` "one shared event system" (the Chronicle store remains);
  `TESTING.md` claims gold never brings the Crown (2,500 gold does).
- **Architecture review versus canonical:** AR D7's default (herbalist as a field profession) and AR §6 "herbalist pending"
  were resolved differently by CV D7; AR D6's "one per type" is acceptable only as an interim slice limit.
- **Older briefs versus canonical:** universal mastery (rejected); the wall and doorway editor (WS-010, UNDECIDED); the
  release-every-iteration rule (superseded by CLAUDE.md and the A2 brief); multiplayer (contradictory older briefs, HB-001).
- **A decision taken without approval:** fatigue holds while the steward runs the forge (BUG-005, UNDECIDED).

## 9. At risk of being forgotten

- The remaining Gate A items have no scheduled milestone (§4.1).
- No player has A1, S1 or A2; nobody has heard the game's synthesised audio (HA-035).
- Baseline systems canonical never names: difficulty modes, talking items, Ironfront, romance, companions, Hall of Fame,
  ceremonies, hireling funerals, fatigue, apprentice independence (decision register §1.5).
- Steward Mode: minimised and post-sleep progression untested (STW-003); inheritance, death and spouse deferral paths
  untested (STW-015); the steward never hires and apprentices leave when independence notices go unanswered (STW-017,
  STW-018); it made only 3 sales of its own in a 365-day soak (STW-019).
- Lore: the pruning cliff above 4,000 events is untested; Chronicle-only records (including hireling deaths) vanish at 400
  entries; nothing runs beyond one in-game year (LORE-008, BUG-018).
- Tests that encode rejected behaviour: `t_progression` and `t_apprentices` (universal mastery). (`t_smithy`'s gold-renown
  assertion was replaced in Run 0.1.)
- CI: the workflow runs only on release-file changes or manual dispatch, integration merges skip CI, rendered tests never
  run in CI, the default branch is unprotected (TECH-014, PROP-006).
- Older open asks: caravan curiosities, compelling advanced requests, softer terrain edges (BUG-031, HB-060 … HB-062);
  known limitations from earlier reports (BUG-020 … BUG-034); no gold floor (BUG-024); balance tuned only against a
  near-perfect test bot (BUG-025).

---

## 10. Decisions needed from the user

**Run 0 / Run 0.1 follow-ups (no milestone depends on code yet):**
1. Answer the clarifications in the observation register (the numbering itself was corrected in Run 0.1).
2. Confirm the baseline features canonical does not name (decision register §1.5), perhaps in a future canonical
   revision. (The editorial points were clarified in canonical v1.2.)
3. Rule on the fatigue-while-away decision taken in S1 (BUG-005); decide what legacy copies of a Unique in old saves
   should show (QST-028); and decide whether to integrate Run 0.1.

**Before the next implementation milestone:**
4. Which Gate A items must close before B/C (QST-027), and whether to authorise an A-REM run (§4.1).
5. Whether to publish a build containing A1+S1+A2 for a human Windows playtest (REL-003), which would also satisfy part of
   "Before B/C".

**Before B1/B2:** professions and migration (STAFF-012); the smith's basic ceiling and existing high levels (STAFF-013);
hireling off-station production (STAFF-004, HA-025); steward hiring (STW-018).
**Before C1:** duplicate stations placement (WS-007); assistance and quality details (PROD-016); routing and queue UI
(PROD-023); the reserved-uid approach (PROD-011).
**Before D:** Honor Guard naming; the commission subsidy (PROP-013, QST-024); permanence of payment records (BUG-048).
**Before E:** rarity change by socketing (BUG-042); Epic for other makers
(QST-022); Reliquary and heir placement.
**Before G:** audiences and places (D10); the mayor.
**Before J:** the Lore retention policy (LORE-004).
**Contradictory sources:** the wall and doorway editor (WS-010, HB-020, QST-023); multiplayer (HB-001); visible
relationship meters (HA-029).
**Proposals:** 65 `PROPOSED` entries, each needing a yes or no (decision register §1.4).

---

## Change history

| Date | Change |
|---|---|
| 10 November 2026 | Created in Run 0 (roadmap reconciliation) at `fa7b5b7`. |
| 10 November 2026 | Run 0.1: milestone rows for canonical v1.2 and Run 0.1; D13, D14 and D18 items marked done; conflicts, at-risk items and decisions updated. |
