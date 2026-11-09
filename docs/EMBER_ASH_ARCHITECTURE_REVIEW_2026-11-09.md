# Ember & Ash — Architecture & Roadmap Review (read-only, Extra High)

*9 November 2026 · Baseline `154d08a` "Release 0.14: The Living Realm milestones 2–5" · release `build-0.14.6`*
*Inputs: `EMBER_ASH_CURRENT_STATUS.md` (audit of 9 Nov), `Ember_and_Ash_Master_Design_2026-11-09.docx`, the repository.*
*Nothing in the repository was changed: `git status` was clean before and after. Tests and probes ran on a scratch copy outside the repo.*

---

## Summary

**Overall verdict.** The codebase is in good shape for its size, which is about 50,000 lines of GDScript across 152 script files.
- The core pattern is sound and consistently followed: one JSON-serialisable state, logic in static systems, the world only showing that state, and a strong test culture.
- Equipment identity is the strongest part, which matters most for this game's promise. Items keep their uid, maker, Lore links, and are improved in place.
- The 0.14 claims hold up. The release exists at the stated commit, and I reproduced the test results exactly.

**But the next stages of the roadmap rest on assumptions the code does not support yet.** Five structural issues should be settled before the Hybrid Workshop, bulk commissions, regional reputation or civilizations are built on top:

1. **The player is assumed to master every craft.** The player's own level is hard-wired into skill-tree gating, station and recipe gating, check difficulty, room tiers, contract quality and refinement. That is about 15 call sites. Apprentices must pass the same player-level gates. This directly contradicts the agreed Hybrid Workshop (Option C).
2. **There is no work order with stages for different workers.** An apprentice task has one worker who does the whole recipe. The player's crafting job is a separate single slot. Contracts count abstract hours. However, the data is ready: 23 of 95 recipes already use stations from more than one discipline.
3. **There are two parallel staff systems with different rules.** Hirelings brew potions and runestones without any skill-tree gate. Apprentices are gated by the player's tree. Wages, applicants, traits and logs are all implemented twice.
4. **The rule "one item, one identity" has gaps.** None of these breaks play today, but each will multiply with handoffs, payment in goods and maritime procurement:
   - Several purchase paths copy an item and give it a new uid.
   - Records hold live item dictionaries. In my probe these were shared in memory, and every one became a separate copy after save and load.
   - Commission masterpieces live only inside a contract history capped at 30 entries.
   - `Game.find_uid_anywhere` misses most of the places an item can be.
5. **The save format has no real schema version.** `SAVE_VERSION` has been 1 since the start. The format changes through "create on first read" getters, which can add keys but cannot convert a structure. The next milestones change structures: task shape, staff professions, reputation.

**Roadmap challenge, in brief.**
- The repository's roadmap and the Master Design's roadmap number their phases differently and disagree in substance:
  - The repository's phase 7 is "civilizations, *allegiance*", which conflicts with the freedom-of-association principle.
  - The repository roadmap has no World Recognition (reputation) phase.
  - It also puts civilizations before the regional prototype.
- Phases 3–5 are "Done" in their original scope, but most of the whiteboard additions for those phases are not implemented:
  - equipment as payment, mining protection and maritime procurement;
  - several named pieces per order (the Honor Guard example), and staged multi-worker production;
  - player-assisted exceptional work.
- The Master Design itself says the Phase 6 foundations (designs vs tools, specialist skill requirements) "may need to be addressed before phases 4–5 scale". **The code confirms this.** I recommend pulling those foundations forward and leaving affix depth where it is.

**Recommended next milestone.** First, a short **Readiness milestone (A)**: human playtest of 0.14.6, the suite in CI, a save-migration framework, identity hygiene in records, and small correctness fixes. Then the **Specialist Workshop vertical slice (B+C)**, which builds one existing multi-discipline design end to end with real specialists. That design is the Emberwarden Longsword: forge → anvil → rune stand → cauldron → grinding wheel → stitching table. Details are in §6.

**Not verified in this audit.** Rendered playtests (they need a display), human Windows playtesting, balance over a whole career, and behaviour beyond a simulated year.

---

## 0. Preflight and method

| Check | Result |
|---|---|
| Remote | `origin` = `https://github.com/crosenlund79/DNDBlacksmith` ✅ |
| Godot project | `game/project.godot`, `config/name="Ember & Ash"`, features `4.3`, GL Compatibility ✅ |
| Commit | HEAD `154d08a`, clean tree ✅ |
| Branch | The session checkout is `claude/sweet-bohr-3tj95k`. The status report names `claude/kind-dijkstra-nqkxn1`. **Both point to the same commit `154d08a`**, so the code is identical and there was no reason to stop. Note that the remote has **no `main` branch**: the development branch doubles as the release line. |
| Release | GitHub `build-0.14.6` targets `154d08afce…`, published 2026-11-09 03:29 UTC, with `EmberAndAsh-Setup.exe` and `EmberAndAsh-Windows-portable.zip` ✅ |
| `RELEASE_VERSION` | 0.14 ✅ |

**Evidence labels used throughout:**
- **[T]** — confirmed by running something (tests or a probe) in this audit.
- **[V]** — confirmed by reading the code. Some reading was done by three read-only sub-audits. Every claim behind a Critical or Important finding was re-checked by me in the code.
- **[I]** — inferred from the code; not executed.
- **[R]** — reported by the status documents; not re-verified here.

**What was run.** Godot 4.3-stable, headless, on a copy of `game/` in the scratchpad. User data was redirected to the scratchpad too.

| Run | Result |
|---|---|
| Compile check | 201 scripts, 0 failed **[T]** |
| Suite (`full`) | **207 passed, 0 failed, 0 skipped**, 44 s **[T]**. Two sub-steps in a venue test print "skipped … keeper not in this world". These are informational. |
| Unit/regression runner | **383 passed, 0 failed** **[T]** |
| Long-campaign probe | Scratch-only script, not in the repo. Simulates 365 days with light management, then checks every item uid for duplicates and compares JSON before and after a save/load. Results in §4 and Appendix A. **[T]** |
| Rendered playtests | **Not re-run**: they need a display. The status report's 43/43 stands as **[R]**. |

---

## 1. Architectural health assessment

### 1.1 What is strong (keep it)

- **One authoritative, serialisable state and a simulation that does not depend on the world scene.**
  - `Game.state` holds only plain data (`game.gd:30-82`). Systems are static functions. `Sim.on_hour/on_day` run whether or not anyone is watching (`sim.gd:11-41`). The world and UI mirror state and never drive it.
  - Apprentice figures copy the simulation and play the work motion only when they have reached their station (`apprentice_actors.gd:62-127, 208`).
  - This is exactly the "physical but truthful" workshop the design asks for.
- **Equipment identity and history.**
  - uid, `prov.maker` written once (`provenance.gd:86-98`), an owner chain, and Lore events linked by uid rather than by copying the item (`lore.gd:35-59`).
  - Refinement changes the existing object in place and adds one event (`refinement.gd:442-485`). Apprentice work keeps its own maker plus workshop and supervisor (`provenance.gd:120-137`).
  - This is a good base for the invariant "the same item through every stage".
- **One build pipeline for the smith and apprentices.** `Crafting.build(..., maker)` (`crafting.gd:589-725`) creates the item for both, so dice, rarity, provenance and Hall of Fame cannot drift between the two.
- **Recipes are already designs.**
  - 95 recipes, each a list of operations at specific stations (`data/recipes.json`). 23 of them span more than one discipline. **[V]**
  - The design's "Design = whole-workshop outcome with stages" is already in the data. What is missing is *who* does each stage.
- **Sponsored expeditions reuse the expedition engine through hooks** (`sponsor.gd:524-526`; `expeditions.gd:427, 446, 462, 534, 1295, 1400`) rather than forking it. This is the right pattern for maritime procurement and escorts.
- **Test discipline.**
  - 35 suite cases written as player journeys (progression scenario A, business scenario B, the end-to-end "world remembers" case), plus integrity checks over the data, an old-save test for each new system, and deterministic seeds.
  - The suite and unit tests are green on a fresh run **[T]**.
- **Long-campaign performance is fine for now.**
  - 365 simulated days took 20 s headless. A day costs 34–56 ms, and the worst single day was 92 ms. A full save takes 156 ms and a load 236 ms at 1.8 MB **[T]**.
  - At 1.6 game-minutes per real second, the simulation cost is negligible.

### 1.2 Structural weaknesses

| # | Weakness | Evidence | Why it matters for the roadmap |
|---|---|---|---|
| W1 | **The player is assumed to master every craft** | `skilltree.gd:159`; `crafting.gd:77-118, 180-181, 216-228, 339-341`; `smithy.gd:86`; `contracts.gd:569-586`; `refinement.gd:473`; treating and socketing grant the *player* alchemy/runecraft XP (`crafting.gd:758, 780`) [V] | Blocks the Hybrid Workshop and the specialist professions (§4 C1). |
| W2 | **No multi-worker, multi-stage production entity** | Apprentice tasks have one `worker`, and that worker continues to the next operation (`apprentices.gd:652-657, 1372-1379`). The player job is the single slot `Game.state["craft"]` (`crafting.gd:141-149`). Contracts count abstract hours (`contracts.gd:522-554`) [V] | Journey 18.2, Commissions v2, specialist treatments (C2). |
| W3 | **Mechanisms implemented more than once** | See the list below the table. | Every new mechanic has to be wired 2–3 times, or behaviour diverges (C3, I3, I4, I9). |
| W4 | **Identity gaps at system boundaries** | Shared references [T]; new uid on purchase copies (`commerce.gd:222-223, 402-403`, `trade.gd:292-293`) [V]; `find_uid_anywhere` covers 3 container types (`game.gd:270-284`) [V]; masterpiece kept in capped history (`contracts.gd:839-841`) [V] | Handoffs, goods as payment, procurement and returning items all cross these boundaries (C4). |
| W5 | **Save format has no real schema version** | `SAVE_VERSION := 1` (`game.gd:10`); `migrate()` has one branch for very old saves plus the cloak move (`saves.gd:129-144`); getters create keys and records when read (`provenance.gd:31-36`, `world_sites.gd:71`, `Adv.ensure`) [V] | Changing a structure (tasks, staff, reputation) needs real migrations (C5). |
| W6 | **Reputation is one global number** | `Shop.reputation()` = average affection × 0.8 + `world.rep` (`shop.gd:38-55`). It feeds customer rate, sponsor prices, consult odds, purchase tolerance, contract tiers, renown and rivalry. Renown can also be bought: 2,500 gold (`smithy.gd:69`) [V] | World Recognition, visitors, militia and civilizations all need audience- and place-specific reputation (I1). |
| W7 | **Truthfulness gaps** | `next_dest` is set once (`adventurers.gd:138-139`) yet shown as the plan; Consult reads threats from `DB.destinations` (`consult.gd:100-101`) while fights use the expedition enemy data; the dossier shows `Adv.power` rather than the formula used for decisions [V] | Breaks "never invent an outcome" and the agreed truthful character sheets (I6). |
| W8 | **Release gate is a smoke test only** | `.github/workflows/windows-installer.yml` exports, runs `--smoke-test`, then publishes. It never runs the suite or unit tests [V] | Regressions can ship whenever a worker skips the local run (I10). |

W3 in detail — mechanisms that exist two or three times:
- Two staff systems (C3).
- Three expedition resolvers: the hireling odds roll, the legacy `Adv._resolve`, and the live `Expeditions` engine.
- Three danger models: `Regions.danger` (`regions.gd:46-48`), `Expeditions.rating` (`expeditions.gd:396-403`), and the per-site threat.
- About ten separate price and negotiation routines.
- Three "find an item" enumerations.
- Formulas repeated in several files: `gear_score`, party strength, repair cost.

### 1.3 Health scorecard

| Area | Health | One-line evidence |
|---|---|---|
| State and simulation architecture | **Good** | Single state, static systems, clock-driven simulation [V] |
| Equipment identity and provenance | **Good inside the forge, Fair at the boundaries** | In-place refinement and Lore by uid [V]; copy-with-new-uid and shared-reference splits at trade and record boundaries [T/V] |
| Crafting data model ("designs") | **Good** | Operations per station, 23 multi-discipline recipes [V] |
| Workshop staff model | **Weak for the agreed design** | Two systems; no professions; the player's levels gate staff [V] |
| Production orchestration | **Weak for the agreed design** | No staged work order; contracts are counters [V] |
| Persistence and migrations | **Fair** | Atomic write with a `.bak`, JSON round-trip identical [T]; no version gating; reads that change state; unchecked rename (`saves.gd:73-85`) [V] |
| Adventurer simulation | **Good but duplicated** | Living, Companies, Expeditions and Sponsor are well integrated [V]; a legacy resolver is still alive [V] |
| Economy cohesion | **Fair** | Money appears from nowhere in repairs (`shop.gd:557-558`, the adventurer never pays) [V]; generous apprentice output (§4) |
| World response (reputation, safety) | **Weak** | One global number; no militia; no route risk [V] |
| History and Chronicle base | **Fair** | Lore has ids, actors, items, place and data, but Chronicle (64 direct writes) and journal run in parallel; no roles or causal links [V] |
| Tests and CI | **Good locally, Weak in CI** | 207 + 383 green [T]; CI runs the smoke test only [V] |
| Long-campaign performance | **Good to 1 year, Watch beyond** | 34→56 ms per day; Lore 2,746 events per year, uncapped above importance 0 [T] |

### 1.4 Gameplay cohesion: the six journeys from the design (§18)

| Journey | Today | Missing pieces | Readiness |
|---|---|---|---|
| 18.1 Everyday local order | Works. Orders, Guide blockers and next steps, the craft. Apprentices can fulfil commissions (`t_apprentices.commission_fulfilment`) [T] | Guide texts assume the *player* lacks a skill ("Raise it by crafting work that trains X", `skilltree.gd:161`) rather than "no qualified worker" | **High** |
| 18.2 Multi-specialist masterpiece | The design data exists (`emberwarden_longsword` spans 4 disciplines). An apprentice can be re-pinned by hand between operations (`apprentices.gd:777-784`) | Professions, per-stage assignment, credit for each contribution, assist check, "the same blade" from the start | **Low** |
| 18.3 Equipment becomes history | Works end to end (`t_world_remembers`) [T] | Trading *for* a sword (goods as payment) is missing; identity splits on some purchase paths | **Medium-high** |
| 18.4 Village protection | Muster and Watch exist only as contract patrons (`data/contracts.json`); deliveries leave no trace in the world | Civic entity, armoury of delivered lots, safety modifier at one place in the code, a report or map | **Low** |
| 18.5 Sailors and rare supplies | Harbour = ship catalogue plus guaranteed imports, no NPC agent (`trade.gd:268-410`) | Sea contacts, negotiation, timed outcome with a chance of failure | **Low** (the Sponsor pattern can be reused) |
| 18.6 Neutral craftsman | Nothing yet | Civilizations, audience-specific reputation, propagation | **None** (correctly deferred) |

**Cohesion critique.** Each loop is coherent on its own, but they join only through gold and one global reputation number. Three examples:

- **Danger.** The player's scouting improves the *hireling* and legacy danger model, not the live adventurer engine. Yet the toast says "told you the safe paths" (`sim.gd:143-144`; `regions.gd:46-48`).
- **Advice.** Consult advice is based on threat data that differs from what adventurers actually fight.
- **Contracts.** Delivered contracts move reputation but nothing physical: forty swords for the Watch change no watchman's equipment.

These are exactly the causal links the design's world-response phases depend on, which is why §5 puts consolidation before extension.

---

## 2. Evidence-based implementation status

### 2.1 Baseline claims vs. this audit

| Status-report claim | Verdict |
|---|---|
| HEAD `154d08a`, clean tree, release build-0.14.6 published from it | ✅ [V] (GitHub API) |
| Compile 201/0 · suite 207/0/0 · unit 383/0 | ✅ reproduced exactly [T] |
| Rendered playtests 43/43 | Not re-run [R] |
| Windows packaged install and launch "SMOKE OK" | Not re-run. The CI design matches the claim [V, R] |
| "73 places for 29 stations" | ⚠️ **30 stations.** `project_bench` was added and is missing from the `PRICE` table, so it falls back to 150 gold (`property.gd:690-691`) [V] |
| "Talking items & hireling work spots only consider ground floor" | Hireling spots: confirmed (`world.gd:2493`). **Apprentices do work upstairs** (`t_smithy`), but that test teleports the figure, so walking the stairs in real time is not tested [V] |
| Durability guard: "0.35 vs 0.4 mismatch" | ⚠️ The guard is not the real risk. The real risks are a third threshold of 0.45, the wrong slot being repaired, and repairs never charged (§4.3) [V] |
| Apprentice economy "generous" | ✅ The cause is identified in §4.3 [V/I] |
| `t_guide.knowledge_persists` flaky once | Not reproduced [T]. Likely cause: every suite run shares one `user://test_saves/` folder that `use_test_dir()` empties at start (`saves.gd:25-31`), so two parallel runs delete each other's files. The unchecked rename would hide that [I] |
| "No TODO/FIXME" | True, but there are dead and legacy paths instead. The legacy expedition resolver (`adventurers.gd:196-203, 227-409`) is kept alive by `test_runner.gd` and still documented as *the* combat model in `TECHNICAL.md:151` [V] |

### 2.2 Status by Master Design area

✅ implemented and tested · 🟡 partial · ❌ missing · ⚠️ implemented in a way that conflicts with an agreed decision

| Design area | Status | Notes |
|---|---|---|
| Physical smithy: rooms, purchases, Loft, lift, tiers | ✅ / ⚠️ | ⚠️ Room tier is the *player's* skill in that room's craft (`smithy.gd:78-105`). Renown can be met with gold alone (`smithy.gd:69`) |
| Predefined, purchasable rooms (not freeform) | ✅ | The Property editor still allows layout editing; acceptable |
| Hybrid workshop (Option C) | 🟡 | Automated apprentice production, visible work, supervision (+3) and mentoring exist. Specialists, handoffs and help requests do not |
| Deep smith tree vs specialist professions | ⚠️ | One 56-node tree covering all crafts, gated by the player's levels (`skilltree.gd:159`) |
| Collaborative help requests | ❌ | The nearest hook is `Apprentices.st().notices` (non-blocking, has a due day) |
| Same item routed between stations | 🟡 | Within one recipe the *work* moves between stations, but the item exists only at completion. No reserved uid, no per-stage credit |
| Designs (terminology) | 🟡 | The data model is ready. "recipe" appears 626 times as an identifier across 42 files, plus about 200 quoted strings |
| Molds, patterns, dies, jigs | ❌ | No representation at all |
| Persistent identity across lifecycle | ✅ / 🟡 | Strong for forge, refinement, sale, inheritance and pawn redemption. Breaks on purchase copies, record aliases, relic identification (new item, `regions.gd:128-142`), and the stranger pool copies (`item_story.gd:778`) |
| Rarity tiers vs Epic | 🟡 | Epic is separate (good). Only 10 flat affixes. `speed` and `luck` are not used by the adventurer simulation. Set and Unique have no mechanics. Legendary names come from a pool of 12 (`items.gd:22-36`) |
| Runes / arcana / alchemy effects | 🟡 | Existing boundaries: runes = permanent socket affixes, at most 2, and Common becomes Magic named "Runed …" (`crafting.gd:764-782`); arcane = a "bound" property added at creation only (`:641-651`); alchemy = coatings lasting 3 trips (`:741-761`). Player-only |
| Sales, storage, trading | ✅ | Stores = player inventory plus `for_sale`. Shop, pawnshop, caravan, rival smith, harbour |
| Bulk orders and commissions | 🟡 | Counters plus **one** masterpiece slot. Apprentice hours count. No lot record; no Honor Guard (several named pieces) |
| Adventurer negotiation, goods as payment | ❌ | Sponsor terms are fee, bonus and share only (`sponsor.gd:341, 464`) |
| Docks, maritime procurement | ⚠️ | Catalogue and guaranteed imports: the "disconnected catalogue" the design wants to replace |
| Independent adventurer lives and sheets | ✅ / 🟡 | Seeded roster, goals, bonds, companies, retirement [T]. Truthfulness gaps (W7) |
| Consultations | ✅ / ⚠️ | Advice changes real decisions [T], but is based on a different threat table than the fights |
| Sponsored expeditions | ✅ | On the real engine, with escrow, counter-offers and real delivery [T] |
| Mining protection, escorts | ❌ | Travel legs are plain timers; no travel risk (`expeditions.gd:521-525`) |
| Mayor, militia, regional safety | ❌ | Patrons only; three danger models |
| Regional and professional reputation, propagation | ❌ | One global number; changes apply instantly |
| Credible visitors through reputation | 🟡 | Patron letters cite real accomplishments (good); "stranger" visits come from the item pool |
| Two civilizations, authored stories, crisis prototype | ❌ | Seeds only: ItemStory naming patterns, fame commissions, site threat growth |
| Chronicle and replayability | 🟡 | World seed affects only the roster. 253 calls to the global RNG versus 6 seeded generators. Lore is a reasonable base |
| UX layers, guidance, honest prompts | ✅ | `guide.gd`, `knowledge.gd`, `world_prompts.gd` [T] |
| `template_` art override pipeline | ✅ | `assets.gd` [V] |
| Windows acceptance | 🟡 | Smoke test on CI only; no human playtest recorded |

### 2.3 Proven vs. assumed

- **Proven by automated tests** [T]: crafting and progression to Dragonscale Armour; apprentice production, provenance and save/load mid-task; contracts (offers, hours, crate, delivery); sponsorship end to end; living roster, a 90-day soak and determinism for the seeded roster; identity through refinement, sale, repair, inheritance and save/load; old-save loading for every Living Realm system; JSON save round-trip over a whole year (probe).
- **Proven only in rendered phases** [R]: physical walking, multi-floor navigation by the player, UI layouts at 1920×1080.
- **Assumptions with no test behind them:**
  - Balance over a whole career with all systems on together. The progression test credits gold as "business income".
  - Apprentice economics under real customer demand.
  - Lore growth after about 18 months of game time.
  - Shared references surviving save/load: they do not [T].
  - Consult advice interacting with sponsored parties: Consult can rewrite a party's destination (`consult.gd:664-670`) with no check for sponsorship [V]; the effect is [I].
  - Apprentices walking stairs in real time.
  - Windows behaviour on real hardware.
  - That bulk contract units mean anything to the world.

---

## 3. Design-to-code dependency map

### 3.1 Concept → code anchors → gap

| Design concept | Code anchors (files · state) | Gap | Depends on |
|---|---|---|---|
| Design ("recipe") | `data/recipes.json` (operations per station) · `Crafting.operations` | UI wording only | — |
| Stage of production | `recipe.operations[]`; `apprentice task.ops_done[{by, station}]` (`apprentices.gd:1365`) | Per-stage assignee, state and quality | Professions, capability |
| Specialist profession | none (apprentice `prefs`/`specialty`; hireling `alloc`) | Profession field, competence by discipline, progression | Staff model decision |
| Capability gating | `SkillTree.*_reason`, `Crafting.*_locked_reason`, `check_params` | Separate *workshop knowledge* (what we know how to make) from *actor competence* (who can do it) | — |
| Work order / job | `Game.state.craft` (player); `apprentices.tasks[]`; `contracts.active[]` | One staged entity used by all three | Capability; save migration framework |
| Persistent item through stages | `Items.make` (uid at creation); `Provenance.forged` | Reserved uid at order start; `prov.contrib[]` | Identity hygiene |
| Help request / assist | `notices` (`apprentices.gd:317, 1786`); supervision +3; `check_params` | A non-blocking request with a smithing check; recorded without needing the player's job | Work order |
| Finished goods | Player inventory (`for_sale`, `for_order`) | Probably sufficient (decision) | — |
| Molds / patterns | none | Operation-level `tool` requirement (optional) | Designs, work order |
| Rarity / affixes / effects | `items.gd` AFFIXES, `Crafting.socket/treat`, arcane `bound` | Affix model, per-profession effect rules, stats that matter in the simulation | Professions, work order |
| Bulk vs prestige orders | `contracts.gd`; `shop.gd` orders | Lot record per delivery; N named pieces; required stages | Work order |
| Negotiation / payment | `sponsor.gd` evaluate/counter; ~10 price routines | Shared valuation (usefulness *to that NPC*); goods move with provenance | Identity hygiene |
| Maritime procurement | `trade.gd` ships and imports; Sponsor contract flow | Sea contacts; voyage via the expedition engine or a timed outcome | Valuation; contact entity decision |
| Protection / escort | none | Travel risk on route legs; escort party | Unified danger model |
| Militia / safety | patrons in `contracts.json` only | Civic organisation entity, armoury from lots, threat modifier | Lots; unified danger; reputation |
| Regional reputation | `Shop.reputation()` used everywhere | `Reputation.of(audience, place)` plus propagation | Place model (only "brindlewick" today) |
| Credible visitors | contract letters; consult visits; stranger visits | Visitors with their own state drawn from reputation | Reputation |
| Civilizations / crisis | none | Faction, leader and resource state; dispute model | Reputation, safety, lots, authored-story hooks |
| Authored conditional stories | ItemStory patterns (`item_story.gd`), Lore queries | Condition engine over Lore and state; expiry | Lore roles and indices |
| Chronicle | `lore.gd` (event store), `chronicle.gd` (400 text lines) | Make Lore authoritative (coverage, roles, causal links); Chronicle = view | Lore retention decision |
| Campaign comparison | `living.gd` world seed | Seeded RNG streams per subsystem | — |

### 3.2 Dependency graph

```
A. Readiness ──────────────┬──────────────────────────────────────────────┐
  (CI gate, migrations,    │                                              │
   identity hygiene,       ▼                                              ▼
   truth/money fixes)  B. Capability & professions ──► C. Staged work orders ──► D. Commissions v2
                           │                              │                       (lots, N named pieces)
                           │                              ▼                          │
                           │                         E. Equipment depth              │
                           │                            (affixes, effect rules)       │
                           ▼                                                         ▼
               F. Shared valuation / negotiation ──► F2. Goods as payment, maritime, escorts
                                                         ▲
               G0. Unified danger model ─────────────────┘
                     │
               G. World recognition (reputation audience×place, propagation, visitors,
                     │                  civic militia fed by D lots)
                     ▼
               H. Regional crisis prototype (minimal two-faction foundation, one region)
                     ▼
               I. Civilizations at scale + authored conditional stories
                     ▼
               J. Chronicle & campaign integration (Lore as the single source; RNG streams)
```

These steps are cheap and can sit in A or B to save rework later:
- A thin `Reputation` facade, so no new code reads `Shop.reputation()` directly.
- A single `Items.WORN` threshold.
- A danger function that everything goes through, before militia or escorts exist.

---

## 4. Critical conflicts and risks

Priority: **Critical** (blocks agreed design or risks data integrity) · **Important** (causes rework, drift or incoherence) · **Optional**.
Complexity (relative): **S** contained, one module · **M** several modules · **L** cross-cutting with migration · **XL** a new subsystem with broad integration.

### 4.1 Critical

**C1 — The player is assumed to master every craft (conflicts with the agreed Hybrid Workshop).** Priority Critical · Complexity L · Confidence High.
- **Evidence [V]:**
  - Skill-tree requirements read `Game.player_level` (`skilltree.gd:159`; legacy path `:97`).
  - Station and recipe gating (`crafting.gd:77-118`) is also applied to apprentices, via `recipes_for`, `add_task` and `_work` (`apprentices.gd:532, 665-667, 1177`).
  - Check zone and speed use the player's level in the *station's* discipline (`crafting.gd:180-181, 216-228`). Quality bonus uses the player's level (`:339-341`).
  - Room tier (`smithy.gd:86`) and contract bench quality and pace (`contracts.gd:569-586`) both use the player's level.
  - Refinement records the smith as the worker (`refinement.gd:473`) and gives the smith XP.
  - Treat and socket give the player alchemy and runecraft XP (`crafting.gd:758, 780`).
  - Station purchase needs the player's tree (`property.gd:706`). Apprentice hiring unlocks at the player's smithing 6 (`apprentices.gd:144`).
- **Impact:** professions cannot own their craft. A smith who ignores alchemy can never get an Established alchemy room, a capable alchemist apprentice, or alchemy contracts at decent quality.
- **Inconsistency [V]:** apprentices judge every operation by the *recipe's* skill (`apprentices.gd:1281`), while the player is judged by each *station's* skill.
- **Recommendation:** add a capability layer and route every gate through it. This changes behaviour but not the save format (no new keys).
  - **Workshop knowledge:** what the forge knows. Keep the skill tree's station and recipe unlocks, but let a qualified specialist's competence satisfy non-smithing requirements, or move those nodes to a workshop catalogue. This is decision D3.
  - **Actor competence:** the skill of the worker doing *this* stage.
  - `check_params(station, recipe, {actor})` picks the actor's skill.
  - Room tier counts the best specialist working that room.
  - Keep the smith's tree as the deep *smithing* tree.

**C2 — No staged, multi-worker work order.** Priority Critical (for journey 18.2 and Commissions v2) · Complexity L–XL · Confidence High.
- **Evidence [V]:**
  - A task has a single `worker`, assigned to whole tasks (`apprentices.gd:652-657, 1057-1135`), who continues after each operation (`:1372-1379`).
  - Eligibility looks at the recipe's discipline, not each station's (`:506-513`). The finishing worker alone sets maker, skill bonus and XP (`:1396-1405, 1484-1508`).
  - The player job is separate (`crafting.gd:141-149`) and `record_step` requires it (`:305-308`).
  - Contracts' `contrib{who: hours}` produces no items (`contracts.gd:544`).
- **Useful foundations already there:**
  - `ops_done[].by`.
  - Manual re-pinning that keeps the materials (`apprentices.gd:777-784`).
  - `Crafting.build(maker)`.
  - Multi-discipline recipe data.
- **Recommendation:** extend the existing apprentice task into a *work order* rather than writing a new system. Each stage gets `{station, discipline, assignee, state, quality, by}`.
  - Assign each stage separately by profession.
  - **Reserve the uid when the order starts.**
  - Record contributions in `prov.contrib[]` at completion. The maker is the forging stage's worker.
  - Let the player *claim* a stage, which unifies the player's job with the order.
  - Keep the item un-materialised until completion. This avoids half-built items in the stores while still giving "the same blade" a stable identity from the start.

**C3 — Two staff systems with different rules.** Priority Critical (must be decided before professions) · Complexity M (shared profile) to L (merging) · Confidence High.
- **Evidence [V]:**
  - Hirelings (`state.hirelings`, at most 3, all 8 skills, `alloc` percentages) produce potions, oils and runestones at a fixed quality of 60 + 6 × level, with **no station, no Crafting pipeline and no skill-tree gate** (`hirelings.gd:325-350`).
  - Apprentices (`state.apprentices.staff`, 5 skills, ranks, data-driven traits) are fully gated.
  - Both refresh applicants weekly, pay wages, have traits and logs, and draw ids from the item uid counter (`apprentices.gd:266`, `hirelings.gd:213`).
- **Impact:** professions would have to be built twice, or one route bypasses the other.
- **Recommendation:** do **not** merge the entities now. Hireling ids are wired into expeditions, `find_uid_anywhere`, Borin's objectives and world spots, so merging is high-risk.
  - Extract a shared *worker profile*: skills, profession, traits, wage rules.
  - Make hirelings the field and expedition staff. Route their station production through apprentice-style tasks, or retire it.
  - This is decision D1.

**C4 — Gaps in the identity invariant at system boundaries.** Priority Critical as a prerequisite (no visible bug yet) · Complexity M · Confidence High.
- **Shared references split by save/load [T].**
  - At day 120 the probe found **18** uids held in two places at once: `customers[].item` and an adventurer's equipment; `exp.done[].loot` and adventurers' equipment or `offers[].item`.
  - In memory all 18 were the *same object*. After save and load all 18 were *separate copies*.
  - Today the repair path re-reads the adventurer's slot (`shop.gd:548`), so no wrong outcome was observed. But any future code that changes an item through a record will fork it.
- **Copies given new uids [V].** Purchases from the caravan, pawnshop house stock and harbour do `duplicate(true)` plus `new_uid()` (`commerce.gd:222-223, 402-403, 468-469, 510-511`; `trade.gd:292-293`). Rival and pawn stock already carry forge and transfer events under the old uid, so their history splits.
- **Possible same-uid duplicate [V/I].** The ItemStory "stranger" pool deep-copies pieces and can put a copy back into play (`item_story.gd:774-787`). `circulating()` does not see player equipment, pledges, contracts, lost gear or return bags.
- **Lookups and records [V]:**
  - `find_uid_anywhere` searches the inventory, adventurers' equipment and hirelings' equipment only (`game.gd:270-284`).
  - Three other enumerations differ: `Lore._all_items`, `ItemStory._known_items` and `History.find_item`.
  - The commission masterpiece exists only inside `contracts.history`, capped at 30 (`contracts.gd:837-841`). It is lost from state once 30 more contracts close.
  - Several exits record no transfer or loss: caravan sale, villager goods, trade-run sales, forfeited pledges sold on, expired offers.
  - Provenance applies to equipment only (`provenance.gd:26-27`), so a runesmith's runestone loses its maker when socketed.
- **Recommendation:**
  - Records store **uid plus a small snapshot**, never the live dict.
  - Keep one item registry (or a `where(uid)` helper) used by every lookup.
  - Every transfer out of the forge records a transfer or loss.
  - Archive delivered masterpieces outside the capped history (e.g. a patron "holdings" list).
  - Purchase copies keep the uid when the item already had an identity.
  - Add `prov.contrib[]` so collaborator credit never touches the maker.

**C5 — Implicit save schema.** Priority Critical before any change to data structures · Complexity S–M · Confidence High.
- **Evidence [V]:**
  - `SAVE_VERSION` is 1 (`game.gd:10`). `migrate()` has a v0→v1 branch plus the cloak walk (`saves.gd:129-144`).
  - The format evolves through getters that create missing keys when read. These cannot *convert* data: for example a task's single `worker` becoming per-stage assignees, or a global `world.rep` becoming per-audience reputation.
  - Reads that change state mean saving straight after a load can differ without any game action. For example, an item tooltip calls `Provenance.st`, which creates a `prov` record for a legacy item that has `crafted_by` but no `prov` yet (`items.gd:371-372`, `provenance.gd:31-36`). JSON was identical in the probe, so the effect is not yet observed.
  - `save()` ignores the result of copy, remove and rename (`saves.gd:79-84`).
- **Recommendation:**
  - Version steps (`v1→v2…`) with explicit converters, run once on load.
  - A folder of **golden saves** from 0.12, 0.13 and 0.14 checked in for tests.
  - Check rename results.
  - A "load → save → load is idempotent" test over the whole state.

### 4.2 Important

| ID | Finding | Evidence | Recommendation | Cx | Conf. |
|---|---|---|---|---|---|
| I1 | **Reputation is one global number feeding about 8 systems.** Renown can be bought with gold | `shop.gd:38-55`; `smithy.gd:60-71`; consumers listed in W6 [V] | Add a `Reputation` facade now (the same number behind it). Later replace it with audience × place plus propagation. Drop gold as a renown path (decision) | S now, L later | High |
| I2 | **Three danger models; no travel risk.** Scouting affects only the hireling and legacy models | `regions.gd:44-49`; `expeditions.gd:394-404`; `world_sites.gd:215-246`; travel legs are timers (`expeditions.gd:521-525`) [V] | Route decisions *and* combat through `WorldSites.enemies_at` and threat. Retire `Regions.danger`, or make hirelings use the same. Required before escorts and militia | M | High |
| I3 | **About ten separate price and negotiation routines**; no item-as-payment path | `sponsor.gd:292-423`; `consult.gd:473-558`; `adventurers.gd:453-469`; `shop.gd:88, 587-718`; `commerce.gd:243-311, 655-703`; `trade.gd:268-368` [V] | A shared valuation helper (item value *to this NPC*: usefulness, need, relationship, uniqueness) before goods-as-payment and maritime procurement | M | Medium-high |
| I4 | **Bulk contracts leave no trace in the world; one masterpiece slot**; the bench uses the player's skill for every recipe | `contracts.gd:494-554, 569-586, 702-722` [V] | Keep counters for bulk; that matches the design. On delivery, write a **lot record** (def, count, quality, contributors, recipient) to the recipient. Add N named-piece slots for the Honor Guard. Run bench stages through work orders | M | High |
| I5 | **Apprentice economics** (detail in §4.3) | `t_workshop_e2e.gd:131-185` [V] | Fix the measurement first; retune after professions | S / M | Medium |
| I6 | **Truthfulness defects** in sheets, advice and toasts | `next_dest` set once (`adventurers.gd:138-139`); Consult threat source (`consult.gd:100-101`); dossier `Adv.power`; random tavern rumours (`talk.gd:322-330`); "safe paths" toast [V] | Derive "plans" from the live planner; one threat source; one power formula. Rumours draw from Lore | S–M | High |
| I7 | **Money is not conserved.** Repairs are paid by nobody; the village covers half a commission | `shop.gd:557-558` (no adventurer gold deducted); `shop.gd:700` ("the village/guild covers the rest") [V] | Charge the adventurer, or record the subsidy explicitly (decision D14) | S | High |
| I8 | **Lore growth.** Importance ≥ 1 is never pruned. Past 4,000 events every `record()` rebuilds the item list and does an O(n²) removal | `lore.gd:12, 128-145` [V]; 7.5 events per day in light play [T] → cap hit around day 530 in light play, earlier in busy play [I] | Index by kind, actor, item and place. Decide retention: summarise or archive old routine events and keep notable ones (D9). Cap adventurer `loot` and `lore` lists | M | Medium |
| I9 | **Legacy expedition resolver still alive and documented** | `adventurers.gd:196-203, 227-409`; `TECHNICAL.md:151` [V] | Migrate old saves' away adventurers on load, delete the legacy path, update the docs | S–M | High |
| I10 | **CI does not run tests** | `windows-installer.yml` [V] | Run compile, suite and unit (headless) as a required job before export | S | High |
| I11 | **Room tier and renown conflict with specialists and regional reputation** | `smithy.gd:60-105` [V] | Tier from the room's specialists, stations and work done; renown from reputation | S | High |
| I12 | **One station per type in the whole workshop** | `property.gd:702-704`; stations keyed by id in `property.stations` [V] | A "lively workplace" or bulk throughput may need two anvils. Decide (D6) *before* work orders, because station ids are keys in Property, Apprentices (`station_user`), World and Contracts | M–L | High |
| I13 | **Consult can redirect a sponsored party** | `consult.gd:664-670` (no sponsorship check) [V]; effect [I] | Respect sponsor objectives or make the conflict explicit | S | Medium |
| I14 | **Determinism is limited.** World seed affects only the roster | 253 global RNG calls versus 6 seeded generators [V] | Needed only for phases H and J. Introduce named RNG streams progressively | M | High |
| I15 | **Contradictions in the roadmap documents** | `docs/LIVING_REALM_STATUS.md` phases 6–10 vs Master Design §13 [V] | One canonical roadmap (see §5.1) | S | High |

### 4.3 Technical debt register (reported items re-assessed)

| Item | Severity | Assessment |
|---|---|---|
| **Contract item identity** (units counted, not items) | **Important** | Counters are the *right* model for bulk: the design does not want 40 forged swords by hand. The real problems are four. (a) Deliveries leave nothing in the world. (b) The masterpiece survives only in a 30-entry history. (c) Only one named piece per order. (d) Bench quality comes from the player's skill whatever the craft. Do **not** turn units into 40 item instances; add lot records instead (I4, C4). |
| **Durability thresholds** | **Important** (small fix) | Three thresholds: 0.35 (`adventurers.gd:620, 673`), 0.4 (`shop.gd:149`), 0.45 (`consult.gd:162`). The guard at `adventurers.gd:885-886` is not the main hazard. The real problems are three. (a) `worn_slot` repairs the *first* worn piece, not the one planned, so the note names one slot while another is repaired. (b) Pieces between 0.35 and 0.45 show "All gear sound" while the adventurer is sent to the counter. (c) The adventurer never pays for an own-gear repair. **Fix:** one constant, carry the planned slot, charge the adventurer. Cx S. |
| **Apprentice economics** | **Important** (don't tune yet) | `t_workshop_e2e` values *unsold* output at list price (`:177`) with no demand cap. At apprentice quality around 78 the rarity score (0.75 q + 0.35 × d100) gives roughly 27 % Common, 57 % Magic, 16 % Rare [I]. Labour is about 10 % of cost [V]. **Recommendation:** measure realised sales against demand in a soak. Retune after professions and work orders, which change who produces what. |
| **Save/load reliability** | **Critical** (C5) + Important | JSON round-trip identical over a year [T]; atomic write with `.bak` [V]. Gaps: no version steps; reads that change state; unchecked rename; shared references split (C4); shared `test_saves` folder (likely flake). Legacy `test_runner` calls `Saves` without `use_test_dir()` [V]. After my run the real `saves/` folder was empty, so the impact appears nil; confirm. |
| **Long-campaign performance** | **Watch** (I8) | 365 days: 34→56 ms per day, save 1.8 MB, 156 ms / 236 ms save/load [T]. The scan cliff past 4,000 Lore events and the uncapped adventurer `loot` and `lore` lists are the scaling risks [V/I]. Run a 3–5-year probe before Chronicle work. |
| **Unverified gameplay integration** | **Important** | No human playtest of 0.14. Stair walking by apprentices untested. Consult × Sponsor interaction untested. No whole-career balance pass. Hireling and apprentice production rules differ. |
| Refined pieces keep their base item def | Optional | `Items.tier()` honours the refined material; names still use the base def. Fine until affixes depend on the def. |
| Dev-spawned materials crafted into normal work | Optional | A dev-only concern; document it. |
| Talking items have no refinement lines | Optional | Content. |
| Stale worktrees and untracked `.import` files | Optional | Housekeeping. Not observed in this clean checkout. |
| Hard-coded "Brannoc Ironhand" (47 string occurrences; `Provenance.SMITH_NAME`; `is_mine` falls back to `begins_with("Brannoc")`) | Optional | Matters only if the smith's name becomes customisable. |

---

## 5. Challenging the roadmap

### 5.1 Where the roadmap contradicts the code or itself

1. **Two roadmaps with different numbering and substance.**

   | # | Master Design §13 | Repository `docs/LIVING_REALM_STATUS.md` (and the status report) |
   |---|---|---|
   | 6 | Equipment Depth (*including* the designs/tools and specialist foundations) | Equipment affixes & deeper legacy |
   | 7 | World Recognition (reputation, visitors, militia) | Autonomous civilizations, **allegiance**, world influence |
   | 8 | Authored Narrative & Civilizations | Authored storylines & regional conflict prototype |
   | 9 | Regional Crisis Prototype | Campaign variation, chronicles |
   | 10 | Campaign Integration | Broader overarching conflict |

   - The repository version has **no reputation phase**.
   - It frames civilizations around **allegiance**, against "freedom of association; no UI forces allegiance".
   - It schedules civilizations *before* the prototype, against "build only necessary foundations until the compact prototype proves causality".
   - **Adopt the Master Design's ordering as canonical** and fix the repository document in the next implementation run.
2. **"Done" phases 3–5 are done only in their original scope.** These whiteboard additions are open:
   - truthful plans with knowledge limits (partial);
   - gold/equipment/mixed payment, mining protection, maritime procurement (missing);
   - bulk vs several named pieces, combined worker stages, player-assisted exceptional work (missing).

   Track them explicitly as "4b" and "5b" follow-ups, or the next run will assume they exist.
3. **Phase 6 bundles a prerequisite with an enhancement.**
   - Its "designs vs tools, smith-specific progression, specialist skill requirements" part is a *prerequisite* for the Hybrid Workshop and for scaling 4 and 5.
   - Affix depth is an *enhancement* that can follow.
   - **Split it:** foundations (milestones B and C) now; affixes (E) after.
4. **"Reuse existing systems" holds in some places and not others:**
   - **Holds:** Sponsor-style hooks for maritime procurement and escorts; apprentice tasks as the base for work orders; Lore as the Chronicle store.
   - **Does not hold:**
     - Militia "through existing systems": no civic entity exists, and danger is split three ways.
     - Reputation: one number.
     - Sailors as `Adv` entities would enter every `Adv.all()` loop (`in_town()` filters on status only) and the Living roster logic.

### 5.2 Prerequisites vs. enhancements

| Item | Genuine prerequisite for | Optional / can wait |
|---|---|---|
| Capability layer (C1) | Hybrid workshop, professions, room tiers, contracts by specialists | — |
| Shared worker profile (C3) | Professions without duplication | Merging the two entity types |
| Staged work order with reserved uid (C2) | Journey 18.2, Commissions v2, specialist treatments, Honor Guard | Visible carried half-made items |
| Save migration framework (C5) | Any of the above | — |
| Identity hygiene (C4) | Goods as payment, maritime, handoffs, returning items, Chronicle | Provenance for non-equipment items (decision) |
| Unified danger function (I2) | Escorts, militia safety, regional crisis | Map safety overlay |
| Reputation facade (I1, S) | Avoiding rework in F and G | — |
| Reputation audiences and propagation | Visitors, militia response, civilizations | Rumour UI polish |
| Lot records (I4) | Militia equipped by deliveries; recipient-side history | — |
| Lore roles and indices (I8) | Authored conditional stories, Chronicle | Cross-campaign comparison |
| Seeded RNG streams (I14) | The crisis prototype's comparisons (design §11.4) | Everything earlier |
| Molds / patterns | — | Wholly optional (D11) |
| Recipe → Design wording | — | UI-only; any time |

### 5.3 Proposed revised sequence (designed to minimise rework)

Milestone letters avoid clashing with the phase numbers. Each milestone keeps the physical workshop, saves and `template_` art intact.

| Milestone | Contents | Cx | Unlocks | Main regression areas |
|---|---|---|---|---|
| **A. Readiness** (design Phase 0) | Human Windows playtest of 0.14.6. CI test gate. Version-step migrations plus golden saves plus a load/save idempotence test. Identity hygiene in records (uid plus snapshot). One `where(uid)` registry. Transfer and loss records on every exit. Masterpiece archive. Fixes: repair slot, threshold and charging; `next_dest`, Consult threat source, dossier power. Remove the legacy resolver. Facades: `Reputation`, `Items.WORN`, a single danger function (signature only). Fix the roadmap document | M (mostly S items) | Safe ground for every later step | `t_adventurers`, `t_consult`, `t_contracts`, `t_provenance`, `t_itemstory`, `t_commerce`, `test_runner` |
| **B. Capability & professions** (Phase 6 foundations) | Shared worker profile with profession. Capability gating (workshop knowledge vs actor competence). Per-actor `check_params`. Fix the apprentice per-station skill. Room tier from specialists. Hireling production routed through or retired | L | Specialists own their craft | `t_progression`, `t_apprentices`, `t_smithy`, `t_guide`, `t_integrity` |
| **C. Staged work orders** | Stages, per-stage assignment, reserved uid, `prov.contrib[]`, player claims a stage, optional help request (non-blocking) with a smithing check, ledger UI, "Design" wording in that UI | L–XL | Journey 18.2; feeds D and E | `t_apprentices`, `t_workshop_ui`, `t_workshop_e2e`, `t_contracts`, `t_refine` |
| **D. Commissions v2** | Bulk via work orders and the bench. Lot records to recipients. N named pieces (Honor Guard). Required-collaboration flag on exceptional orders | M | Journey 18.4 groundwork | `t_contracts`, `t_business` |
| **E. Equipment depth** (Phase 6 proper) | Affix model with tiers and conditions. Effect rules per profession (runes, arcane, alchemy). Every stat used by the simulation. Set and Unique mechanics. Unique legendary names per world | L | Meaningful magic items | `t_tailoring`, `t_refine`, `t_itemstory`, `t_adventurers` |
| **F. Valuation, negotiation, procurement** | Shared valuation. Goods as payment (real transfer). Mining protection and escorts on the unified danger model. Maritime procurement via sea contacts on the Sponsor pattern | M–L | Journeys 18.3 (trade-for) and 18.5 | `t_sponsor`, `t_trade`, `t_commerce` |
| **G. World recognition** (Phase 7) | Reputation by audience × place, propagation by travellers, goods and Lore. Credible visitors. Civic militia entity with an armoury from lots. Threat modifier and report | L | Journey 18.4 | `t_living`, `t_consult`, `t_contracts`, `t_world` |
| **H. Regional crisis prototype** (Phase 9 in the design, *moved before* civilizations at scale) | Minimal two-faction foundation in one region, dispute dynamics, several outcomes. Seeded RNG streams for "unchanged vs changed" comparisons | XL | The proof gate | new |
| **I. Civilizations & authored stories** (Phase 8 scaled) | Only after H succeeds. Condition engine over Lore and state | XL | Journey 18.6 | broad |
| **J. Chronicle & campaign integration** (Phase 10) | Lore as the single source (coverage, roles, causal links); Chronicle as a view; retention policy | L | Campaign history | broad |

Two notes on ordering:
- A–C, E and F follow the Master Design's order: foundations before scaling 4 and 5, then Phase 6.
- The one deliberate change is **H before I**. The design itself demands that ("prove a small conflict before scaling up").

### 5.4 Rework traps to avoid

- **Don't rename** recipe ids, keys or APIs to "design". Change player-facing wording only: 626 identifier uses and save data are keyed by recipe ids.
- **Don't merge** hirelings into apprentices as entities in one step (C3).
- **Don't turn** bulk contract units into individual items (I4).
- **Don't add** sailors as plain `Adv` entities without a domain filter. Prefer a contact entity, or `domain: "sea"` excluded from Living and Consult loops.
- **Don't build** militia safety, escorts or a map overlay before one danger function exists (I2).
- **Don't create** a Chronicle database; extend Lore (J).
- **Don't build** professions *and* affixes in the same run: the effect rules depend on the professions decision.

---

## 6. Recommended next implementation milestone

### Prerequisite run — Milestone A "Readiness" (Cx M, mostly small items)

Order within the run:
1. **Human playtest of 0.14.6 on Windows** (the design's Phase 0): smithy floors, contracts, sponsorship and consultations played by a person. Record the findings.
2. **CI gate:** compile, suite and unit tests headless before export (I10).
3. **Save framework (C5):** version steps; golden saves from 0.12, 0.13 and 0.14; whole-state load → save → load idempotence test; checked rename; a separate test-save folder per run.
4. **Identity hygiene (C4):**
   - records hold uid plus a snapshot;
   - a `where(uid)` registry used by all lookups;
   - transfer and loss events on every exit;
   - purchase copies keep existing identities;
   - masterpiece archive;
   - a probe-style test asserting **no duplicate uids** across state and **no shared item dicts** across containers.
5. **Small correctness and truth fixes:** I6, I7, the durability trio, I9, I13.
6. **Facades:** `Reputation.of()`, `Items.WORN`, one danger entry point (behaviour unchanged).
7. **Roadmap document** brought into line with the Master Design (I15).

**Acceptance:**
- All existing tests green, plus the new identity, idempotence and golden-save tests.
- The 365-day probe shows 0 duplicate uids before *and* after load.
- A Windows build is published, with a human playtest note attached.

### Next milestone — "The Specialist Workshop" vertical slice (B + C, Cx L)

**Goal.** Prove the agreed Option C on existing content, end to end, without regressing physical presence, saves or provenance.

**In scope:**
1. **Worker profile with profession** (data-driven) on apprentices, using the existing skill sets. Hirelings get the field read-only. Professions: blacksmith (the player), leatherworker/tailor, runesmith, alchemist, arcanist. Herbalist is pending decision D7.
2. **Capability layer** (C1): workshop knowledge vs actor competence. The player keeps the smithing tree. Non-smithing stages need a competent specialist, or the player at the player's own skill, depending on decision D2.
3. **Per-actor checks:** `check_params(..., {actor})`. Apprentices use each *station's* discipline skill.
4. **Staged work order** (C2):
   - extend `Apprentices` tasks with `stages[]`;
   - assign each stage by profession;
   - reserve the uid at start;
   - record `prov.contrib[]` at completion; the maker is the forging stage's worker;
   - convert in-flight tasks in a version-step migration.
5. **The player claims a stage:** the smith walks to the anvil and plays the existing minigame for that stage.
6. **One optional help request** (non-blocking, expires, no penalty in the slice). Example: "steady the blade while I seat the rune", resolved by a smithing check that adds a recorded bonus to that stage.
7. **Ledger UI:** stages, who, where, blockers ("no runesmith on staff"). "Design" wording in this flow.
8. **Physical presence:** each stage's worker walks to its station, including the Loft (test real-time walking, not teleport). Hireling ground-floor spots are left as-is.

**Out of scope:** affixes, reputation, molds, new rooms, contract changes beyond compatibility, sailors, merging hirelings.

**Acceptance (journey 18.2, reduced):**
- **Emberwarden Longsword** (`data/recipes.json`: forge → anvil → rune_engraving_stand → cauldron → grinding_wheel → stitching_table): the smith forges, a runesmith seats the rune, an alchemist quenches, a leatherworker wraps the grip.
- Each stage is visibly worked at its station.
- **One uid from order start to stores.** Maker = the smith. `contrib` lists each specialist with stage, day and quality.
- One Lore "forged" event plus contribution data, with no duplicate events.
- Save and load mid-stage, an old save with an in-flight single-worker task, and the 0.14 golden save all load.
- Rendered playtest phase plus a Windows build.
- Existing suites green (§5.3 regression list).

**Prerequisites:**
- Milestone A done.
- Decisions D1, D2, D3, D4, D6 and D8 (§7). D5, D7 and D11 can wait.
- A verified backup branch before the run.

**Main risks:**
- Contract apprentice hours (task kind "contract") must keep working.
- `t_progression` assumes the player levels every discipline. This scenario will need a parallel "specialist route" rather than a rewrite.
- Skill-tree semantics (D3) touch many UI texts in `guide.gd`.

---

## 7. Unresolved design questions (for us to decide)

Ordered by when they block work. "Recommended default" is my suggestion, not a decision.

| ID | Question | Why it matters now | Options | Recommended default | Blocks |
|---|---|---|---|---|---|
| D1 | How do hirelings and apprentices relate? | Professions would otherwise be built twice (C3) | (a) Merge entities; (b) shared profile, hirelings = field staff, apprentices = station staff; (c) status quo | **(b)**; route or retire hireling station production | B |
| D2 | Can the smith personally do non-smithing stages at all? | Defines gating and the "smith is not an alchemist" boundary | (a) Locked; (b) allowed at the smith's own (low) skill; (c) allowed only with a specialist present | **(b)** for continuity with current saves; specialists clearly better | B |
| D3 | Is the skill tree the *smith's* techniques or the *workshop's* knowledge? | 54 of 56 nodes gate on player levels in every craft | (a) Split: smith techniques tree plus workshop designs catalogue; (b) keep one tree but let specialists satisfy non-smithing nodes | **(a)** long term, **(b)** for the slice | B |
| D4 | What does collaborator credit mean? | Provenance, Epic, Hall of Fame, "is it ours" | Contributors recorded only; or they also share fame and recognition | Record `contrib[]`; fame stays with the maker and the workshop; specialists remember their stages (apprentice `creations`) | C |
| D5 | Bulk units: counters or items? | Contract identity debt | Counters plus lot record; or real items | **Counters plus lot record** | D |
| D6 | More than one station of the same type? | Throughput, visible activity, station ids used as keys | (a) No; (b) allow numbered instances | Decide before C; (a) for the slice, (b) later if bulk needs it | C/D |
| D7 | Herbalist vs alchemist, and which room or station hosts herbalism? | No herbalism skill exists; the herbalist is a venue | (a) Herbalist = supplier/gatherer profession (field); (b) a sub-specialty of alchemy | (a) | B |
| D8 | Help requests: frequency, declining, required cases | Avoid interruptions; avoid blocked queues | — | Optional, expiring, at most 1 per in-game day; never blocks the queue; required only on flagged commissions | C |
| D9 | Lore retention for long campaigns | Growth and scan costs (I8) | Unlimited; summarise routine events into period digests; archive | Keep importance ≥ 1 forever; turn old routine events into digests | J (indices earlier) |
| D10 | Reputation audiences and geography | Only "brindlewick" exists as a place | Communities (crafters, merchants, adventurers, nobles, village, each civ) × places (region list) | Start with 4–5 audiences × 3 places | G |
| D11 | Molds and patterns: needed, and do they wear? | Busywork risk | None; tool requirement on specific operations; wearing tools | Tool requirement on a few casting operations only; no wear | E (optional) |
| D12 | Sailors: persistent named people or contacts? | Docks cost and roster pollution | Full adventurers; lightweight contacts with relationships; anonymous | **Contacts** (named, relationship, no Living lifecycle) | F |
| D13 | Rarity semantics: what makes Set and Unique different? | Phase 6 design | — | Defer to E; Epic stays separate | E |
| D14 | Should the village subsidise commissions, and who pays for adventurers' repairs? | Money conservation (I7) | — | Adventurers pay; any subsidy is explicit and recorded | A |
| D15 | Which roadmap numbering is canonical, and is "allegiance" dropped? | Document conflict (I15) | — | Master Design numbering; replace "allegiance" with "relationships / standing" | A |
| D16 | How reproducible must campaigns be (same seed + same choices = same history)? | Crisis comparisons, Chronicle | — | Reproducible *world generation*; comparisons at prototype scale only | H |
| D17 | Boundaries between runes, arcane and alchemy | Competing upgrade systems | Keep today's boundaries (runes = permanent socket affixes; arcane = intrinsic "bound" property at creation; alchemy = temporary coatings) or redefine | Keep and formalise them; decide whether arcane can be applied after forging | E |
| D18 | Can renown be bought (2,500 gold)? | Conflicts with reputation-based recognition | — | Remove the gold path when reputation becomes regional | G |

---

## 8. Optional improvements (outside the agreed scope)

All are **optional proposals**: none is required by the Master Design, and none should be done without approval.

1. **A whole-career balance harness:** an extended soak with a scripted "reasonable player" reporting gold, output, sales against demand, and Lore growth. It would make I5 and I8 measurable. Cx M.
2. **Consolidate duplicated formulas** (`gear_score`, party strength, repair cost, stat totals and coatings) into one helper each. Cx S.
3. **Make legendary names unique per world**, so two "Emberfang"s never confuse returning-item recognition. Cx S.
4. **Replace `Items.tier()` string matching** (`items.gd:138-150`) with a data field. Cx S.
5. **Make the smith's name a single constant**, if a customisable smith is ever wanted (47 hard-coded occurrences). Cx S.
6. **Release hygiene:** a protected `main` branch that only receives released commits, and a backup branch per release. Cx S.
7. **Cache `Shop.reputation()` and `DB.items` scans per hour or per day.** The daily adventurer gear evaluation multiplies adventurers × slots × stock × NPCs. Not needed yet [T]. Cx S.
8. **A Chronicle "why" view:** show the causal chain of an event from Lore data links once roles and causes exist. Cx M, after J.
9. **Remove dead branches:** Chronicle kinds `legend` and `honour` are read but never written (`recognition.gd:133`, `personality.gd:193`). Also the unused `Crafting.assistant_name`, and the `unlock.skill` recipe path, which no recipe uses. Cx S.
10. **Bring stale docs up to date:** the skill tree docstring says six branches but there are seven; the station count; `TECHNICAL.md` still names the legacy combat model. Cx S.

---

## Appendix A — Probe evidence (scratch-only; not in the repository)

The script simulated a seeded journeyman game with light management: weekly mining trips, repairs at 80 %, returned bags opened. Each row is a 30-day bucket.

| Day | ms per day (average / worst) | Save size | Lore events | Largest state keys |
|---|---|---|---|---|
| 30 | 34 / 56 | 633 KB | 227 | exp 323k, adventurers 90k, chronicle 78k, lore 61k |
| 120 | 42 / 56 | 1,046 KB | 923 | exp 381k, lore 253k, adventurers 216k |
| 240 | 54 / 88 | 1,447 KB | 1,786 | lore 505k, exp 377k, adventurers 345k |
| 360 | 56 / 92 | 1,849 KB | 2,705 | lore 773k, adventurers 476k, exp 376k |

- **Totals:** 365 days in 20.2 s. Save took 156 ms and load 236 ms at day 365.
- **JSON round-trip** (stringify → parse → `_restore_ints` → `migrate` → stringify): **identical**, both before and after a real save and load.
- **Uid scan at day 120:** 186 distinct item uids; **18 held in two places at once**; all 18 the *same object* in memory; **after save and load, all 18 separate copies.**
  - Example: `adventurers/pip/equipment/weapon` and `customers[3]/item`.
  - Example: `exp/done[4]/loot[0]` and `offers[0]/item`.
- **Uid scan at day 365:** 11 such pairs.

## Appendix B — Files most often cited

`scripts/autoload/game.gd`, `saves.gd`; `scripts/systems/crafting.gd`, `apprentices.gd`, `hirelings.gd`, `contracts.gd`, `provenance.gd`, `refinement.gd`, `lore.gd`, `smithy.gd`, `property.gd`, `shop.gd`, `consult.gd`, `sponsor.gd`, `expeditions.gd`, `adventurers.gd`, `commerce.gd`, `trade.gd`, `item_story.gd`, `regions.gd`, `world_sites.gd`, `skilltree.gd`; `data/recipes.json`, `data/contracts.json`; `tests/suite/cases/t_workshop_e2e.gd`; `.github/workflows/windows-installer.yml`; `docs/LIVING_REALM_STATUS.md`, `docs/TECHNICAL.md`.

*End of report. No development has been started; implementation awaits your explicit approval.*
