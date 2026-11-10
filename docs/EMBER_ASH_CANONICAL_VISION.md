<!--
  Markdown edition of docs/Ember_and_Ash_Canonical_Vision_and_Roadmap_v1.2.docx (Design Baseline 1.2, 10 November 2026).
  The .docx is the approved source; this file reproduces its text faithfully for use in the repository (generated from
  the .docx, so both share one revision history — see "Revision history" at the end). Only formatting was adapted for
  Markdown (boxed callouts → blockquotes). The v1.1 and v1.0 .docx files are kept as the dated historical copies. Revisions require
  explicit user approval, a version increment and matching updates to both files (CLAUDE.md §2.5).
-->

*THE WORLD REMEMBERS*

# EMBER & ASH — CANONICAL GAME VISION & DEVELOPMENT ROADMAP

> **THE PROMISE**
>
> **Forge something that matters.**
>
> A blacksmith may create a sword, see it travel through generations, repair it when it returns, and discover that its history helped shape the fate of a realm. The smith need not become its hero.

**DESIGN BASELINE 1.2**

9 November 2026 · Authoritative creative direction

*Technical delivery remains subject to implementation milestones and testing.*

# Document charter

This document is the **single canonical map for the intended game**. It supersedes earlier creative-roadmap wording where our later decisions are more specific; it does **not** erase the original roadmap or pretend future features have shipped.

| **Field**             | **Rule**                                                                                                                                                |
|-----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| Document authority    | User-approved creative intent and gameplay boundaries; implementation design remains reviewable.                                                        |
| Status                | Design baseline locked as v1.0; revised to v1.1 (Steward Mode, 9 November 2026) and v1.2 (editorial clarifications, 10 November 2026). New gameplay scope requires explicit approval and a recorded revision. |
| Code baseline at adoption | Claude read-only audit: commit 154d08a, release build-0.14.6, Godot 4.3 (9 November 2026). Later delivery status is tracked in the repository’s roadmap register, not here.                                                              |
| Technical evidence    | Claude status audit, Extra High architecture report and the repository’s decision, roadmap and playtest-observation registers are evidence, not the game’s creative authority.                                                 |
| What this does not do | Does not authorize coding, rewriting saves, building systems, or publishing releases.                                                                   |

## Decision language

| **Label**                | **Meaning**                                                                  |
|--------------------------|------------------------------------------------------------------------------|
| LOCKED DESIGN            | Explicitly chosen gameplay direction or standing non-negotiable principle.   |
| TARGET                   | Approved future capability, whether or not present in code today.            |
| OPEN DETAIL              | Balancing, specific UI rules, data shape or lore not yet decided.            |
| TECHNICAL RECOMMENDATION | Claude’s proposed engineering approach, pending our implementation approval. |
| NOT APPROVED             | An alternative, optional addition or genre expansion not in scope.           |

## Reading order

**Part I (Sections 1–3):** The fantasy, player promise and current state. **Part II (Sections 4–11):** Locked gameplay systems. **Part III (Sections 12–16):** Roadmap, proof journeys, governance and unresolved implementation detail.

> **PRINCIPLE**
>
> **The design is stable. The implementation may evolve.**
>
> We can change a technical approach if it better serves the approved game. We do not quietly change what the game is about.

# 1 What Ember & Ash is

Ember & Ash is a **craft-first blacksmith simulation in a genuinely autonomous medieval-fantasy world**. The player starts with a modest, slightly neglected smithy and develops it into a renowned, working establishment while adventurers, traders, families, institutions and two civilizations pursue their own lives.

The player’s influence comes through **craftsmanship, equipment, advice, trade, commissions, employment and relationships**. The world must react meaningfully but continue without the player.

## 1.1 The two equal halves

| **The smithy**                                                                                                                                               | **The living realm**                                                                                                                                                             |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Hands-on smithing, deep technique, meaningful quality rolls, specialist collaboration, physical rooms, workshop growth, commerce and personal relationships. | Independent adventurers and companies; genuine plans, expeditions, families and reputations; persistent items and events; two civilizations in a conflict that may be prevented. |

## 1.2 Non-negotiable boundaries

- **The smith is the protagonist.** No obligation to become a combat hero, military commander, political ruler or king.

- **Autonomy is real.** NPC actions, inventories, relationships and plans must reflect simulation state, not fabricated flavor text.

- **History persists.** Significant item, person, ownership and world consequences are not casually reset.

- **A physical workshop matters.** Real stations, rooms, workers and movement; not one abstract menu with decorative sprites.

- **Depth over sprawl.** Build interconnections rather than separate factory, navy, military, management or conquest games.

- **No compulsory allegiance or war.** Work with both civilizations; peace is genuinely possible; ignoring the crisis is legitimate.

- **Clarity without overload.** The player understands actions, blockers and reasonable next steps.

- **Scope by approval.** No extra gameplay system is introduced just because it sounds exciting.

## 1.3 What the game must not become

Not a Satisfactory-style production floor of infinite anvils; not a freeform building simulator; not a militia tactics game; not a full sailing simulator; not a universal-crafting protagonist who masters every profession; not an inevitable final-war questline.

# 2 Verified reality and the future boundary

At adoption, the **technical baseline** was release **build-0.14.6**, commit **154d08a**. The Extra High read-only review reproduced 201 script compilations, 207/207 suite tests and 383/383 unit tests. Earlier rendered tests and Windows smoke checks were reported but not independently rerun in that review. Human Windows gameplay acceptance remains outstanding. Delivery after adoption (Milestones A1, S1, A2 and later runs) is tracked in docs/EMBER_ASH_ROADMAP_REGISTER.md; this section is not updated for it.

| **Already implemented / reported verified**                                                                                                   | **Still absent or incomplete for our final design**                                                                                                                        |
|-----------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Persistent Lore and provenance; identifiable equipment; refinement; apprentice queues; village UX and crafting guidance.                      | True multi-worker work orders, profession-owned stages, automatic handoffs, smithing-only deep progression and collaborative assistance.                                   |
| Evolving Smithy Loft/lift; equipment sheets; living adventurers and companies; consultations; sponsored expeditions; Project Bench contracts. | Bulk delivery consequences, several named masterpieces in one order, items-as-payment, maritime characters, escorts and militia safety.                                    |
| Existing rarity/affix seeds and crafting data: 23 of 95 designs span several disciplines.                                                     | Distinct Set/Unique mechanics, deeper meaningful affixes, audience/region reputation, civilizations, regional crisis, authored conditional stories and campaign Chronicle. |

## 2.1 Known architectural constraints, not changes to our vision

- Player levels currently gate roughly fifteen cross-discipline behaviors; **specialists cannot yet own their craft**.

- Apprentice work is largely one-worker-per-order; hirelings and apprentices follow **different staff rules**.

- Equipment identity is strong in the forge but vulnerable across **records, trade, copies and save/load**.

- Existing saves need explicit versioned migrations before major structural changes.

- There is one global reputation number, several danger and pricing models, and some player-facing character plans that do not reflect live state.

- A one-year light simulation was fast, but uncapped Lore growth may matter over longer campaigns.

These are technical findings from the 9 November architecture audit. They justify sequencing and safety work, **not** an unapproved rewrite or abandonment of working functionality.

# 3 The intended moment-to-moment experience

**Materials and opportunity → select a Design → perform smithing → specialists contribute at real stations → collect the finished item → sell, trade, keep, refine or fulfill a commission → the world uses and remembers it → new opportunities appear.**

## 3.1 Ordinary work and exceptional work

A local dagger or repair should remain direct, readable and satisfying. An exceptional commission may involve multiple rooms, rare materials, skilled employees, occasional player assistance and difficult decisions. Complexity belongs where it adds meaning, not on every mundane order.

## 3.2 The player always knows what to do

The game reveals immediate actions and blockers first, practical next steps second, and full dependency paths only when requested. Basic usability guidance is free. Paid discoveries are for genuinely unusual secrets, never basic instructions.

# 4 The evolving physical workshop

## 4.1 Expansion without factory building

Begin with a rundown, spatially constrained smithy. Upgrade through **predefined, purchasable rooms and improvements**, retaining meaningful walkable layouts, stations, staff activity, multiple floors and convenient navigation. The building should visually become a beautiful, busy establishment rather than an industrial production hall.

**Multiple instances of a station type are permitted**, but capacity is constrained by plausible room size, layout, staffing and operating needs. No infinite rows of anvils, unconstrained duplication or freeform industrial optimization. Exact room/station limits remain a balancing and architecture detail.

## 4.2 Three layers of competence

| **Owner**                  | **Responsibility**                                                                                                                               |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **The smith**              | Personal, substantially deeper smithing techniques and mastery; limited basic work in other disciplines, never equal to a true specialist.       |
| **The workshop**           | Shared catalog of known Designs, techniques, tools, stations, rooms and feasible production combinations.                                        |
| **Individual specialists** | Personal profession, skills, experience and character progression; high-end rune work, arcana, leatherwork and alchemy require qualified people. |

The existing broad skill tree should **evolve carefully** into personal smithing progression plus workshop knowledge, with save-safe migration. The player is allowed basic non-smithing activity for continuity, but advanced craft mastery is not grindable by the smith.

## 4.3 Employees are real participants

Preserve the two existing staff entity families where technically useful: **workshop apprentices/specialists** and **field hirelings**. Give them compatible worker-profile foundations for professions, skills, progression and basic employment logic. Avoid a risky wholesale merge.

Workshop specialists perform suitable work at actual stations. The alchemist profession includes herbalism expertise; the existing village herbalist remains a supplier. “Druid” may be a character tradition or background, **not** another mandatory workshop profession.

## 4.4 Hybrid production: the central operational model

- The player chooses the **Design**, selects relevant specialists and can personally perform smithing stages.

- Employees ordinarily coordinate and perform handoffs between stages; the player can intervene or claim relevant work.

- Each stage is done by an **actually qualified person** in an appropriate room at a visible station.

- The same item retains a stable identity through stages; its **original maker does not change** when a specialist contributes.

- Each contributor can earn **individual recognition**, while the workshop and original maker also gain appropriate credit.

- Finished equipment goes to **finished-goods storage**; the player chooses its disposition.

- Some help requests arise naturally from real, difficult work. Optional requests can be declined; employees continue, potentially without a bonus. Only expressly flagged exceptional work may require cooperation.

The actual mechanic for stage persistence, assignment, movement, work-blocks and assistance is **technical implementation**, not new creative scope. It must preserve the physical, believable workshop.

## 4.5 Steward Mode

Steward Mode lets the player explicitly hand the running workshop to a steward and take it back later. It is a **genuine autonomous workshop manager**, not passive time advancement, and it acts only through the same actions and world state as ordinary play.

- **Explicit and online only.** The player activates and exits Steward Mode. It progresses only while the game is running and the mode is active, including when minimized where the operating system permits. There is no offline progression or catch-up, including after a save is reopened.

- **Routine business, really done.** The steward evaluates the workshop and independently accepts suitable ordinary orders, assigns available employees, plans production, replenishes materials, manages stock and handles ordinary sales, and it responds to unavailable workers, shortages and production bottlenecks.

- **Nothing is conjured.** It uses real inventory, money, contracts, production time, people, skills and world simulation; it never creates goods, money, work or accomplishments. Employees progress by the normal rules; the absent smith gains no crafting experience. It never automates work that needs a specialist, station or capability the workshop does not have.

- **The player sets the boundaries.** Persistent, understandable standing instructions cover spending limits and permitted purchases, allowed activities, protected items and reserved supplies, and the rules for ordinary orders and selling.

- **The steward defers; it does not decide.** Unique, Epic and historically significant equipment, dangerous reworking, extraordinary commissions, political commitments, inheritance, major relationships and other consequential personal decisions are left for the smith. The world is never frozen for them: significant visitors may leave requests or correspondence, and existing timers continue.

- **Competent, not superior.** The steward manages well but never outperforms the active player’s craftsmanship or judgment.

- **While You Were Away.** On return the player sees the actual elapsed game time, financial changes, completed and pending production and orders, purchases, sales, stock and employee activity, significant world developments, and outstanding decisions and correspondence. Every claim is backed by recorded events and real state changes, without duplicates or invented narrative.

- **Sealed correspondence.** Genuinely significant deferred matters that come from an actual world event or visitor may arrive as a sealed letter whose contents stay unknown until the player opens it. Opening it leads to the actual pending matter and preserves the player’s agency. Letters are special, not guaranteed on every return.

- **One engine for play and testing.** The same steward decision engine drives the playable mode and seeded, accelerated, headless soak tests (test environment only).

# 5 Designs, molds and craft knowledge

**Designs** are the player-facing name for complete equipment production plans, including applicable materials, stages, stations, tools and specialist requirements. Existing internal “recipe” keys or save formats do **not** have to be renamed wholesale. Maintain compatibility.

**Molds, patterns, forms, jigs and dies** are craftable reusable physical aids for operations where they make sense. Casting uses molds; forged work may use patterns and dies. They can unlock specialized work, but are **not universally required** and, at this stage, **have no durability/wear**. Do not create a tool-replacement chore.

**Techniques** belong to the individual actor’s knowledge; **Designs** belong to workshop planning; **tools** are tangible production prerequisites. A Design may be entirely smithing-based or may depend on multiple specialists.

# 6 Equipment: rarity, memory and transformation

## 6.1 Identity is sacred

> **IMMUTABLE PRINCIPLE**
>
> **One creation. One authentic history.**
>
> Across forging, handoffs, repairs, refinement, rune work, enchantment, alchemical treatment, ownership transfers, retirement and restoration: preserve the original item identity, maker, maker’s mark, names, ownership and earned historical recognition. Record changes as events; do not silently replace the item.

Physical possession, historical records and snapshots must remain distinct. A single canonical sword must not turn into several independently mutable objects after save/load or trade. A truly destroyed item may cease to be physically usable, but its Lore record must remain.

## 6.2 Rarity and earned significance

| **Classification**                | **Design rule**                                                                                                                                        |
|-----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Common / Magic / Rare / Legendary | Mechanical quality and affixes with meaningful influence on actual adventurer decisions and outcomes; detailed balancing remains open.                 |
| Unique                            | A defined Unique artifact exists in **exactly one authentic instance per campaign**. It cannot respawn as a duplicate after sale, loss or inheritance. |
| Set                               | A collection category with distinctive combined-use mechanics; exact bonus rules are not yet fixed.                                                    |
| **Epic**                          | **Not a rarity tier.** Historical recognition earned through actual deeds. A Common sword may become Epic; a Legendary weapon might never do so.       |

The game favors interesting Diablo-like affixes and effects over a simple “Sword +1” ladder. This is **not** a commitment to a D&D rules conversion.

## 6.3 Different kinds of specialist magic

**Runesmiths** inscribe persistent rune effects. **Arcanists** create deeper arcane properties and can enchant **existing** equipment years after its original forging. **Alchemists** produce oils, potions, botanical preparations and coatings, often temporary. Exact effect overlap and permanent-versus-temporary boundaries must be formalized without duplicating the system.

An old, famous sword should be capable of **becoming better without becoming a different sword**. This is a core gameplay pillar, not an edge-case upgrade.

## 6.4 Reworking risk and irreversible choices

| **Activity**                                     | **Permitted consequence**                                                                                                          |
|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Routine restoration / refinement                 | Low risk; failure may cost materials, time or durability. Permanent destruction is not an ordinary outcome.                        |
| Advanced reforging, runes or arcane improvements | Meaningful risk of damage, dormant enchantments, unstable properties or a difficult recovery process.                              |
| Extraordinary warned experiment                  | An explicitly communicated high-stakes choice may permanently destroy the **physical** item. Its unique historical record endures. |

Danger must be visible **before** a risky decision. Restoration difficulty should respond to real skill, tools, specialist help, history and materials; the player should never lose an irreplaceable heirloom from an ordinary, poorly explained check.

## 6.5 The Reliquary: a workshop with a conscience

Add a **magically secured, purchasable physical display case** within the smithy, linked to existing historical-recognition systems rather than a standalone museum. It may exhibit **only broken or unusable equipment that has earned genuine historical significance**. Mechanical Legendary rarity alone does not suffice; working equipment belongs in the world.

The smith’s ethos: **“A sword was forged to be wielded, not admired behind glass.”** The Reliquary honors the service of an item that can no longer fulfill its purpose. Once restored to working order, it leaves the cabinet and may return to active use. Exhibition never manufactures fame; history earned the recognition.

## 6.6 Ancestral restoration and the heir’s claim

A credible **living heir or descendant**, grounded in actual family and ownership history, can recognize an ancestral relic and request its restoration. Particularly ancient or bloodline-bound Unique artifacts may need a descendant’s cooperation to recover their full magical nature.

The player can **write to an heir**, explain the project, offer compensation and negotiate consent, costs, restoration conditions and possible purchase. An heir can decline, accept restoration while **refusing to transfer ownership**, or insist that the restored weapon be returned to their family. The smith must honor agreed terms.

Attempting restoration without ancestral involvement may be exceptionally demanding, expensive, risky or unable to restore the complete ancestral enchantment. **Not every Unique item is bloodline-bound**, and no ancestor should be invented just to trigger a quest. “Blood” as the literal ritual medium, exact eligibility and genealogical validation remain open implementation/story details.

Keep **permission to restore** separate from **rightful ownership**. Record the project, contributors, compensation, conditions and transfer in the same item’s history. A restoration can create a powerful story even when the smith receives no artifact to keep.

# 7 Business, commissions and fair exchange

## 7.1 Commerce should circulate real things

Finished goods can be stored, sold, traded, retained, commissioned or reworked. Trading an item transfers the **same identifiable object** with its provenance, not a fresh randomly generated replacement. Existing shop, pawnshop, caravan, harbor and rival-smith systems are foundations to extend, not replace without evidence.

## 7.2 Two kinds of orders

| **Ordinary bulk contract**                                                                                                                                                                                                                   | **Prestigious commission**                                                                                                                                                                          |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Specified number of goods and minimum quality. Workers and the Project Bench handle batches. Ordinary units need not become dozens of fully simulated historical item objects; a persistent **lot/delivery record** can ground consequences. | Exceptional standards and **one or several individually named, persistent pieces**, e.g. an Honor Guard set. Every notable item has its own identity, makers, specialist contributions and history. |

Large projects include time commitments, deadlines, equipment requirements, worker capacity, patron-provided standard materials when appropriate, rare acquisitions, payment and credible consequences. An optional masterpiece may accompany ordinary bulk work. Avoid forcing the smith to manually forge forty identical swords.

## 7.3 Negotiate with real people

Adventurers may accept **gold, crafted equipment or a combination** for expeditions, protection and procurement. Offers reflect actual needs, personality, relationships, available funds, danger and usefulness of the specific equipment. An adventurer receiving a sword may truly equip and use it.

**Money must have a plausible origin.** Adventurers pay for repairs and purchases from real funds; organizations pay for contracts. Any village/guild subsidy is explicit and recorded. Negotiated exceptions are possible without creating an entirely new economic-simulation game.

# 8 Adventurers, parties and maritime contacts

## 8.1 Independent life is the requirement

Adventurers pursue actual personal ambitions, routines, purchases, relationships, party life, preparation, recovery, injury, death, retirement and discoveries. Their character sheets reveal **truthful, appropriately knowable** plans, activities, progression, equipment and expedition history, never invented status text or secret facts the smith could not know.

Persistent named companies gain their own histories and reputations. Membership changes because of actual circumstances. Consultations let adventurers request meaningful equipment advice; trust and persuasion matter, but the NPC may reject a recommendation. Sponsored expeditions pursue agreed objectives and produce real, timed, persistent outcomes.

## 8.2 Protection and procurement

Expeditions and mine runs can negotiate escorts and protection based on actual regional danger. The smith may commission recovery of materials, relics, salvage and information, but cannot micromanage offscreen battles or order a party’s every move.

## 8.3 Docks as a relationship, not a catalogue

The docks offer **named, persistent sailors and captains** with personalities, skills, availability, relationships and voyage histories. The smith asks them to obtain specialty goods, negotiates terms and experiences a credible timed success, delay or failure. This can reuse a simplified expedition/sponsor framework without turning sailors into ordinary land adventurers or the game into naval exploration.

# 9 The town, reputation and the wider world

## 9.1 The independent mayor and militia

The frontier town has a mayor and its own militia. The blacksmith may equip them through commissions and influence regional security, mining and trade risks **indirectly**. The player does not recruit, position or command soldiers. Delivered goods must leave believable traces in the world or the recipient organization.

Improved safety should be gradual and causal, **not a magical hard-edged circle** on the map. Map feedback is permitted if it reflects real conditions. A dedicated military-management loop is explicitly out of scope.

## 9.2 Reputation is earned and travels

Reputation differs by **community/profession, person, institution and geography**. Dwarven artisans, adventurers, traders, nobles and each civilization may judge the smith differently. News spreads over time through travel, letters, goods, events and relationships; it does not instantly update a worldwide fame meter.

**Renown cannot be purchased outright.** Paying 2,500 gold must not grant genuine respect. Publicity might increase awareness where justified, but admiration follows believable accomplishments, reputation and testimony.

Renowned merchants, adventurers and patrons who visit should be **credible persistent people** with reasons to come, not disposable rank rewards.

# 10 Civilizations, conflict and authored stories

## 10.1 A preventable conflict

Two substantial civilizations with histories, competing resource interests, leaders, champions and legitimate grievances can drift toward tension, diplomacy, deterrence or war. Neither is required to be the evil side. **War can be entirely prevented**, and the same conflict may resolve differently across campaigns.

The blacksmith may work for either or both, remain relatively neutral, encourage understanding or ignore high politics. Actions have consequences but **no forced allegiance selector, countdown to mandatory battle, or scripted single peace solution**. Play continues after the crisis ends.

## 10.2 First prove one region

Before scaling to kingdom-wide politics, construct a **small regional conflict prototype** using limited characters, interests and locations. Test whether actual equipment, relationships, commissions, resource conditions, expeditions and rumors can plausibly influence escalation, reconciliation and outcomes. A regional proof-of-causality is mandatory before large-scale conflict simulation.

## 10.3 Authored storytelling belongs inside reality

Memorable authored events become eligible when actual world state supports them: an injured returning adventurer, a disputed relic, an ancestral claim, a commission inspired by a real victory. Participants, circumstances, timing, history and outcome come from the simulation and shared Lore. Stories may move on without the player. Never fabricate dead ancestors, arbitrary artifacts or contradictory histories to make a script trigger.

## 10.4 Replayability and the Chronicle

A world seed produces reproducible **starting conditions**. Normal campaigns remain free to diverge through independent lives and decisions; testing can employ reproducible controlled randomness when needed. The Chronicle of the Realm presents **actual shared Lore**, not a parallel history database.

Keep consequential history and item provenance permanently. As campaigns grow, **routine low-value activity may be summarized**, without erasing meaningful item events, personal histories or causal chains. The game should remember what matters and remain performant after many in-game years.

# 11 User experience and visual identity

- Progressive disclosure: actions and blockers first; recommended routes second; full dependency explanations on request.

- Physical legibility: visible stations, workers and rooms; navigation shortcuts reduce friction without eliminating place.

- Honest information: progress, work stages, plans, risk, availability, reputation and histories derive from actual state.

- Equipment presentation: separate material/craftsmanship, mechanical rarity, affixes and **earned Epic history**.

- Preserve the existing visual identity and the `template_` fallback / creator-art override system.

- Validate real Windows gameplay and screenshots as well as headless automation; CI smoke alone is not acceptance.

# 12 The canonical roadmap

The **original Phase 0–10 creative roadmap remains canonical**. The architectural audit’s A–J milestone letters are a **recommended technical delivery sequence**, not a new creative direction or permission to start development. Phase completion is measured against the **original implemented scope** and separately against newly approved extensions.

## 12.1 Creative phases, with the confirmed 0.14.6 baseline

| **Phase**                            | **Vision and current standing**                                                                                                                      |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0 — Release foundation               | 0.14.6 exists and automated tests are green. Full human gameplay acceptance and stronger regression/release gates still needed.                      |
| 1 — Evolving Smithy                  | Rooms, Loft/lift and visuals in 0.14.6. Future specialist flow, meaningful duplicate station capacity and constrained artisan layout.                |
| 2 — Equipment presentation           | Humanoid sheets and cloak slot in 0.14.6. Extend to fully truthful item credits, legacy and upgrades.                                                |
| 3 — Living adventurers               | Goals, companies and consultations in 0.14.6. Improve truthfulness, relationships and consequential links.                                           |
| 4 — Sponsored expeditions            | Basic sponsor system in 0.14.6. Extend to equipment-based payment, escorts, protection and maritime contacts.                                        |
| 5 — Major commissions                | Project Bench and original bulk model in 0.14.6. Extend to world-facing delivery lots, multi-worker pieces and multiple named Honor Guard artifacts. |
| 6 — Equipment depth                  | Rarity/affix seeds exist; deeper effect semantics, specialist refinement and lasting reuse of famous items are future work.                          |
| 7 — World recognition                | Regional/community reputation, earned renown, real famous visitors and militia consequences are future work.                                         |
| 8 — Authored stories & civilizations | Two-civilization backdrop and conditional stories are future work, after a credible smaller proof.                                                   |
| 9 — Regional crisis prototype        | Future proof gate before full civilization simulation; variable outcomes including peace.                                                            |
| 10 — Campaign integration            | Long-term chronicle, campaign differences, coherent consequences and continued play after the crisis.                                                |

## 12.2 Proposed technical sequence (not implementation approval)

| **Gate**                        | **Purpose and dependence**                                                                                                                                                                |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A — Readiness                   | First: human playtest, versioned save migrations and golden saves, item identity hygiene, trustworthy UI/repair fixes, CI regression tests and common entry points for danger/reputation. |
| B — Staff capability            | Shared worker profiles; smith tree and workshop knowledge; real profession ability; per-stage skill checks.                                                                               |
| C — Staged production           | Extend existing queues for several workers and one stable item identity; optional assistance and visible traversal. Prove one multi-discipline Design.                                    |
| D — Commissions v2              | Bulk delivery records and multiple individually named prestige pieces; cooperative exceptional orders.                                                                                    |
| E — Equipment depth             | Advanced affixes, Arcana on existing items, relevant stats, meaningful Sets/Unique behavior, risks and restoration.                                                                       |
| F — Negotiation and procurement | Shared item valuation; goods-as-payment, escorts, maritime captains and rare supply journeys.                                                                                             |
| G — World recognition           | Audience/place reputation; earned renown; credible visitors; independent militia and regional safety.                                                                                     |
| H — Regional proof              | A small, testable conflict with multiple autonomous outcomes, before expanding the civilizations.                                                                                         |
| I — Civilizations and stories   | Scale only what H demonstrates; add conditional authored storylines and neutral dealings.                                                                                                 |
| J — Chronicle and campaign      | Consolidate Lore truth, summarization, long-term history and replayability.                                                                                                               |

**Steward Mode (S1)** is the approved next development priority, following Gate A1 “Protect the Foundation” (versioned save migrations, golden saves, equipment identity and the CI test gate, integrated at commit 5b8af75) and preceding the Specialist Workshop (Gates B–C). Its decision layer must stay compatible with the future multi-specialist workshop. This records priority; it is not a claim that the feature is implemented.

**Reliquary / ancestral restoration** is an approved **creative target**, but its engineering placement within E, I and J must be determined from prerequisites (persistent identity, damage state, ownership/lineage evidence, story triggers). Do not claim it is implemented or create a separate “heir game.”

## 12.3 Acceptance gates

- **Before B/C:** save migrations and canonical identity boundaries must be safe; real 0.14.6 gameplay must be assessed.

- **Before D/F:** multi-stage production, item transfers and recipient records must be credible and testable.

- **Before G/H:** danger, reputation and delivered equipment effects must share authoritative state.

- **Before I:** one regional crisis must produce several believable outcomes, including de-escalation.

- **Before J:** Chronicle must be a view of real Lore; routine history compression cannot delete meaningful links.

# 13 Proof journeys: what the finished systems must make possible

**The ordinary order**

A smith can produce a basic item without hiring every specialty. Requirements, blockers, material sources, work and stock are legible.

**The collaborative masterpiece**

The smith forges a blade; a runesmith, alchemist and leatherworker perform their stages at visible stations; help is offered only when meaningful; one item identity and all contributors survive saving.

**The famous sword returns**

A sword is sold, used in actual adventures, earns Epic historical recognition, is inherited and later enchanted/refined without losing its maker or history.

**The Honor Guard**

A patron orders standard quantities plus several individually named, persistent exceptional pieces; the Project Bench, staff and recipient records agree.

**A town safer by craftsmanship**

The independent militia receives real equipment consignments and the region becomes credibly safer, without player unit control.

**The sailor who remembers**

A named captain negotiates to retrieve a rare ingredient, undertakes a timed journey, remembers payment and reports a truthful outcome.

**A credible neutral smith**

The player can craft for both sides of a tense dispute; trust and suspicion differ by audience while war remains preventable.

**A relic and its heir**

A broken historically significant weapon rests in the Reliquary; a real descendant seeks restoration, negotiates terms and may demand its return. The smith can restore it without becoming its owner.

**The cost of ambition**

An extraordinary, clearly warned reworking fails. Damage and restoration matter, and even an irreversible loss does not delete the artifact from historical memory.

# 14 Decision register — approved creative canon

The following records the eighteen architectural decisions (D1–D18) explicitly settled after the Extra High audit, and decision D19 (Steward Mode), added in v1.1. These are **creative commitments**; implementation and tuning remain conditional on stability, review and tests.

| **Decision**             | **Locked direction**                                                                                                                                                       |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| D1 Employee systems      | Keep distinct workshop and field staff entities with a shared worker-profile foundation.                                                                                   |
| D2 Smith competence      | Basic other-craft knowledge is allowed; advanced mastery belongs to specialists.                                                                                           |
| D3 Progression           | Deep smithing tree + workshop Designs/knowledge + personal specialist progression.                                                                                         |
| D4 Recognition           | Original maker, workshop and specialist contributors can all receive appropriate, separate credit.                                                                         |
| D5 Orders                | Ordinary bulk units plus honest delivery/lot records; prestigious orders may contain multiple named persistent artifacts.                                                  |
| D6 Stations              | Multiple of a type may exist, tightly constrained by believable artisan-space limits.                                                                                      |
| D7 Herbalism             | Herbalism sits within the Alchemist profession; Druid is a possible background, not a required class.                                                                      |
| D8 Help requests         | Real-work-driven, nonintrusive, normally optional; exceptional flagged commissions may require help.                                                                       |
| D9 Lore retention        | Keep significant history and item provenance permanently; summarize routine activity safely.                                                                               |
| D10 Reputation geography | Audience- and place-dependent, gradual information spread through real-world channels.                                                                                     |
| D11 Craft tools          | Specialized craftable molds/patterns where relevant; reusable without durability loss.                                                                                     |
| D12 Maritime contacts    | Named persistent sailors/captains with relationships and simplified real voyages.                                                                                          |
| D13 Unique               | Exactly one authentic defined Unique artifact per campaign; Epic is earned history.                                                                                        |
| D14 Economy              | Payments have real payers; subsidies are explicit and recorded.                                                                                                            |
| D15 Canonical roadmap    | The original Phase 0–10 roadmap and numbering of the Master Design, as restated in §12.1, govern over other roadmap documents (where the Master Design’s wording differs, this document prevails); no forced political allegiance.                                                                                      |
| D16 Replayability        | Reproducible beginnings, emergent and potentially different histories; deterministic test mode as needed.                                                                  |
| D17 Historic upgrades    | Arcanists may enchant and specialists may refine old existing artifacts while identity remains.                                                                            |
| D18 Earned renown        | Reputation cannot be bought directly; acclaim follows actual deeds and credible spread.                                                                                    |
| D19 Steward Mode         | Explicit, online-only autonomous workshop management within standing instructions; real actions only; consequential matters deferred; truthful While You Were Away report. |

## 14.1 Later design additions now included

- **Reworking risk (Option B):** difficult failures may break or disable an item; only exceptional, explicitly warned attempts may permanently destroy its physical form; history persists.

- **Reliquary (Option A):** a magically secured workshop display holds only unusable, historically meaningful equipment; functional items should be used, and restored pieces leave the display.

- **Heir restoration:** real descendants can unlock exceptional restoration possibilities and negotiate, consent, refuse, or commission restoration while retaining the right to take the weapon home.

- **Ancestral binding:** some truly Unique items may depend on heir cooperation for full restoration; non-heir attempts can be difficult, expensive, incomplete or riskier. Not universal across all Unique items.

- **Steward Mode (D19):** an explicit, online-only autonomous workshop manager acting within the player’s standing instructions; it defers consequential matters, reports truthfully on return and may deliver sealed correspondence from real events. Approved 9 November 2026 as the next development priority (v1.1).

# 15 Open details, not invitations to change direction

| **Still to determine**                                                                 | **What is already fixed**                                                                                             |
|----------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Exact room capacities; multi-station spacing; individual worker routing and queue UI   | Believable artisan workshop; multiple stations permitted, no factory grid.                                            |
| Exact professions, skill numbers, migration and compatibility                          | Deep smith tree; qualified specialists; personal credit; old saves preserved.                                         |
| Quality formulas, assistance chance/frequency, exceptional-work thresholds             | Requests come from actual work, can normally be ignored, with special required cases clearly flagged.                 |
| Affix mechanics, sets, arcane/runic boundaries and rarity balance                      | Unique is truly one-of-one; Epic is historical; existing item may be enchanted without replacement.                   |
| Physical damage states, restoration costs, ritual requirements and heirs’ legal claims | Routine upgrades never casually delete relics; important restoration retains identity and respects consent/ownership. |
| Civilization names, map, leaders, conflict grievances and exact chronology             | Two credible sides, no forced allegiance, preventable war, regional proof first.                                      |
| Exact Lore indexing/retention policy and chronology screens                            | History must be true; significant causal records and provenance remain available.                                     |

Other mechanics that would meaningfully widen scope—full naval travel, family-tree management, militia tactics, unlimited factory placement, compulsory Druid profession, paid instant renown, separate chronicle truth database—remain **outside the approved design** unless explicitly revisited.

# 16 How we lock, change and build from this map

## 16.1 Authority and revision control

- **Treat this document (v1.2) as the canonical game-design direction.** Store it with the project and retain a dated versioned copy.

- Any new scope or reversal requires an explicit decision. Add a short change record: what changed, why, impacts and date.

- Engineering may choose different implementation structures when they preserve the locked experience. If the code cannot support an approved feature reasonably, return with evidence and options rather than silently replacing it.

- Claude audits and implementation reports may inform sequencing; they do not override this document’s creative decisions.

- Keep an honest difference between **implemented**, **design approved**, **being evaluated** and **not approved**. No work begins from this document alone.

## 16.2 Development safety contract

For every future Claude Code implementation run: verify repository identity, branch, remote and Godot project, and **STOP on mismatch**; secure a recovery point; preserve persistent item identity, saves and creator art overrides; make contained, testable changes; run relevant automated and rendered regressions; test actual gameplay and Windows packaging; report the verified commit/build and incomplete items clearly.

## 16.3 Our decision-making standard

> **FINAL NORTH STAR**
>
> **The game is not about becoming the hero.**
>
> It is about being the craftsperson whose work becomes part of a living world’s history. Even when a sword is shattered, an heir may one day return to the forge, and the world remembers why it mattered.

# Appendix — Sources and evidence boundary

Design sources: **Ember & Ash Master Roadmap Handover** (20261109_Roadmap.txt; not stored in the repository — its content survives as consolidated in the Master Design); **Master Game Design & Development Roadmap** (9 November 2026; docs/Ember_and_Ash_Master_Design_2026-11-09.docx); eighteen whiteboard observations and subsequent decisions in our Ember & Ash design discussion (recorded only as summarised in the Master Design and in this document), including D1–D18, reworking risk, the Reliquary and heir-led restoration.

Technical evidence: **EMBER_ASH_CURRENT_STATUS.md** and **EMBER_ASH_ARCHITECTURE_REVIEW_2026-11-09.md**, both dated 9 November 2026, assessing build 0.14.6 / commit 154d08a. Technical reports verify the baseline, not future completion. Delivery status after adoption is tracked in docs/EMBER_ASH_DECISION_REGISTER.md, docs/EMBER_ASH_ROADMAP_REGISTER.md and docs/EMBER_ASH_PLAYTEST_OBSERVATIONS.md (from 10 November 2026), which are evidence and tracking, not design authority.

# Revision history

| Version               | Change                                                                                                                                                                 |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1.0 — 9 November 2026 | Design Baseline 1.0 adopted as the canonical game design.                                                                                                              |
| 1.1 — 9 November 2026 | Added §4.5 Steward Mode, its priority in §12 and decision D19 (§14, §14.1); version labels updated. All v1.0 decisions are unchanged. Approved explicitly by the user. |
| 1.2 — 10 November 2026 | Editorial clarifications only, requested by the user (Run 0.1): the charter, §2 and the appendix date the 0.14.6 code baseline to the document’s adoption and point to the repository registers for later delivery status; the appendix says where each design source is kept; §14 counts D19 alongside the eighteen audit decisions; D15 names the Master Design’s Phase 0–10 roadmap as restated in §12.1 and confirms that this document prevails over the Master Design’s wording; version labels updated. No design decision, scope, priority or boundary changed. |
