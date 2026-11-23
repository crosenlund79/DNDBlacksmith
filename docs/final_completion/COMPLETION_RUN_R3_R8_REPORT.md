# The Great Completion Run, R3–R8 — "From One History to a Living Realm": completion report

*What R3–R8 delivered, how each milestone was verified, which decisions were applied as provisional defaults, and what
is still open.* Roadmap: [`FINAL_DEVELOPMENT_ROADMAP.md`](FINAL_DEVELOPMENT_ROADMAP.md) §R3–§R8 · previous build:
[`R2_BUILD_REPORT.md`](R2_BUILD_REPORT.md) · playtest list: [`R3_R8_PLAYTEST_CHECKLIST.md`](R3_R8_PLAYTEST_CHECKLIST.md).

- **Repository:** `crosenlund79/DNDBlacksmith`, Godot 4.3 project `game/` ("Ember & Ash"), verified at the start and
  after every context compaction.
- **Branch:** `claude/completion-r3-r8`, from R2's head `e61053f`. **Recovery point:** `backup/pre-completion-run-20261122`
  (= `e61053f`, pushed).
- **Milestone commits (each verified, committed and pushed on its own):** R3 `e04581a` (+ `aad2fe4`, the world-seed fix),
  R4 `d020bc7`, R5 `2ed2a61`, R6 `47687e9`, R7 `b25e533`, R8 `9271f24`; the R2 golden save and checklist `ca71ff0`, the registers `0cec7ef`, the 0.18 playtest build `47a0690`, and this
  report with the last rendered-phase fix (the branch head).
- **Classification:** ALIGNED — the locked roadmap's R3–R8, approved scope of canonical v1.7 (§6.3–§6.6, §7, §9.1–§9.2,
  §10.3–§10.4, §13 proof journeys, §14.1). Every open design detail was settled by the audit's recommended default and is
  listed in §2 as provisional.
- **Not done, by instruction:** no merge to the default branch, no public release, no tag; R9, R10 and R11 not started;
  no civilization created or named; Reeve Tamsin Hale's title not changed; the 85 proposed additions and the
  user-deferred observations left out; no art replaced or restyled (one new `template_` sprite, §1 R6); real user saves
  never touched (every test, probe and playtest used a test save folder or an isolated `XDG_DATA_HOME`).

## 1. Delivered, milestone by milestone

### R3 — One History (Gate J) · `e04581a`, `aad2fe4`

- **Lore is authoritative; the Chronicle is a view** (`Lore.chron_ids`; `Chronicle.add` records a Lore event). Save
  **step 11** converts an old feed into Lore in its original order. The 400-entry cap is gone.
- **Events with ids, links and indices:** `refs`, `roles` (giver, receiver, heir, escort, captain, visitor …) and causal
  `because` links (`push_cause`/`pop_cause`: a death → the inheritance and the homecoming; a boss kill → the Epic). Indices
  answer `of_item`, `of_actor`, `of_place`, `why`, `consequences`.
- **Retention with digests:** routine workshop events older than 60 days fold into monthly digests per item every 30 days;
  folded ids redirect, so nothing referencing them dangles.
- **Seeded RNG:** streams world / expeditions / commerce / crafting (`rng.gd`), persisted after every draw (about 197
  call sites moved off the global generator). The world seed itself still comes from the global generator — a regression
  where every campaign had the same world was found and fixed in `aad2fe4`, and every seeded result was redone.
- **Deterministic replay:** saves keep floats exactly (a `floats` sidecar; insertion-ordered JSON), so save → load →
  play is bit-identical to playing on (`t_r3_history`).
- **Multi-year probe:** `tests/long_probe.tscn` (§3).

### R4 — Commissions v2 & civic recipients (Gate D) · `d020bc7`

- **Institutions** (`institutions.gd`): the village (Reeve Tamsin Hale), the Brindlewick muster, the Highmarsh Watch —
  supply (bulk counts, mean quality), stock (real pieces; registry holder "institution"), lots, a purse (weekly income;
  the outfitting subsidy is paid from it, owed when short).
- **The Honor Guard journey:** ten helms, ten round shields and three named pieces (Vigil, Hearthward, Millstone) as
  staged work orders; delivery waits for them; pieces land in the muster's stock with a lot record; the steward defers
  named pieces to the smith. **Molds and patterns** (decision 9). Ledger archive and uncapped contract history (BUG-048).

### R5 — Equipment depth (Gate E) · `2ed2a61`

- **Twelve affix effects** that change seeded fights and decisions (keen, embers, haste, warded, bear, fortune, vigor,
  sage, rime, stalwart, leech, thorns); **three sets** of three matched by one maker's mark.
- **Arcane enchantment of existing items** by an arcanist only (enchant / attune at the spellbinding array; a half-done
  binding sleeps). Runes stay socketed (a second rune needs a runesmith 5+); alchemy stays temporary.
- **Risk tiers** stated before every piece of work; **broken / disabled** states; **warned destruction**: only "Temper
  beyond", after the danger is stated and a second click, can disable or destroy (history kept in the tombstone).
- **Consult refine advice**; **Unique legacy copies** labelled; **Epic for any maker** (the workshop's honours stay its own).
- Truthful stats: luck, speed, vitality anywhere, scouting and carry are in play and no longer labelled idle.

### R6 — Legacy: the Reliquary & Heirs · `47687e9`

- **The Reliquary** — a purchasable, placed station (one; a new `template_reliquary` sprite derived from the existing
  `template_display_case`; no creator art touched). It accepts only out-of-service pieces with earned significance; adds
  no fame; a restored piece leaves it.
- **Heirs only from records** (ownership chain; authored families in `characters.json`); a bearer without family leaves
  no heir. Letters, the four answers, custody guards (no sale, pawn or display), the homecoming, all in the item's history.
- **Restore** (Refinement): never destroys. **Grimhold** is bloodline-bound: its ancestral nature sleeps while unusable and
  wakes only with its line's consent (otherwise a harder restoration and held-back strength).
- The item panel can now show a piece held where the smith knows it (Reliquary, an institution, a family's home).

### R7 — Negotiation & Procurement (Gate F) · `b25e533`

- **Goods as payment** (`barter.gd`): valued by the R2 valuation; a piece that serves the taker counts in full and is
  equipped at once (in provenance as "payment"); sponsorships and escorts accept it; a cancel returns it.
- **Escorts** (`escorts.gd`): an adventurer guards a hireling's run; the price follows `Danger.trip`; the cover lowers the
  same odds the ledger shows; refusals name the price or the danger.
- **Named captains** (`captains.gd`): the nine captains of `trade.json` are persistent; each call is their visit; timed
  procurement voyages land, are delayed or are lost (half the deposit back); payment is remembered (trust → terms).

### R8 — World Recognition (Gate G) · `9271f24`

- **The militia** (`militia.gd`): readiness from the muster's real kit; patrols drift toward it (5 %/day); bandits thinned by
  patrol × reach through the one danger model (decision 13); the map shows the real reach. No unit control (WLD-008).
- **Reputation spread:** news travels by travel, ship and letter to the audiences each channel reaches; never instant,
  never double-counted; the village's own standing is unchanged by news leaving it.
- **Credible visitors** (`visitors.gd`): the region's merchant, Guild, Watch and Warden come only for news that reached
  them by a channel; renown cannot be bought. **Political deferral:** civic and lordly letters sealed for the smith.
- **Integration scenario** `t_zz_integration`: forge → sell → equip → deed → spread → visitor → death and inheritance →
  Reliquary → heir → restoration → the muster's patrols → one history → save/load (37 checks).

## 2. Decisions applied (provisional defaults — please confirm or overrule)

| # | Decision (audit §7) | Applied as | Deviation from the audit's default |
|---|---|---|---|
| 6 | Lore retention and indexing | Permanent: provenance, people, places, deaths, Epic, causal chains, anything referenced. Routine workshop events (note, repaired, sharpened, treated) at importance 0 older than 60 days fold into **monthly digests per item**; folded ids redirect | Digests are per item, not per actor/place (the routine events that grow are item events; actor/place feeds are kept whole) |
| 7 | Audiences/places; is the reeve the mayor? | Audiences and places as R2 (no civilizations). **The reeve keeps her title.** The village institution (R4) fills the civic role; R8's political letters come from it | "Promote the reeve to mayor" **not applied**: you asked that existing naming not be rewritten silently — the title is yours to decide |
| 8 | Who names Honor Guard pieces; the subsidy | The patron names them in the order (authored in the template: Vigil, Hearthward, Millstone); earned Epic stays separate; the subsidy is paid from the village purse (owed when it runs short) | — |
| 9 | Molds/patterns | Two casting molds (ring; amulet) and one forged pattern (the muster series: helm, round shield); reusable, no wear; quality 3, 0.75× hours | — |
| 10 | Affixes, sets, magic boundaries | Twelve affix effects; three sets of three, 2- and 3-piece bonuses, matched by one maker's mark; runes socketed (a second rune needs a runesmith 5+), arcana bound by an arcanist only, alchemy temporary | Arcane enchantment is a Refinement action by the arcanist (immediate, at the spellbinding array), not a queued staged work order |
| 11 | States, restoration, heirs, "blood" | worn → broken (half strength; reforge mends) → disabled (unusable; Reliquary-eligible; Restore) → destroyed (only the warned experiment). Heirs only from recorded ownership or authored family. The rite is the heir's consent (a hand on the piece); no gore | Grimhold, the Last Hammer is the one bloodline-bound Unique (data tag) |
| 12 | Sailors; escorts | The nine captains already named in `trade.json` as persistent contacts with voyages and memory (not a naval game). Escorts for hireling runs | Escorts cover **hireling runs only**; adventurer parties are protected by sponsoring them (now payable in goods) |
| 13 | Bandits and the militia | Common bandits (road bandits, crossbowmen, war-hounds; never a named master) at a place are thinned by up to 60 % × patrol × reach, never below one | — |
| 15 | Legacy Unique copies | Shown as "(a contemporary copy)" | — |
| 16 | Epic for other makers | Yes; the workshop's reputation, Hall of Fame and ceremony stay with its own pieces | — |
| — | R6 heir answers (§6.6 wording) | decline · consent with the piece kept in the family's custody (cannot be sold) · consent on condition of its return · a fair sale | The canon's "possible purchase" is the fourth answer |
| — | Political commitments (STW-014) | Letters from the muster, a watch, a lord or the Crown, and visitors' calls, wait **sealed and marked political** while the steward runs the forge | Before R8 only lords' and the Crown's letters were sealed |

## 3. Verification

### 3.1 Per-milestone gates (each on a frozen copy of exactly what was committed)

| Milestone | Compile | Suite | Unit | Focused tests | Rendered phase |
|---|---|---|---|---|---|
| R3 | CI full gate ✓ (Tests run 45085298367 on `e04581a`) | ✓ | ✓ | `t_r3_history` 8/8; 3-year probes clean | (existing regression) |
| R4 (+ R3's seed fix) | CI full gate ✓ (Tests run 45088628547 on `d020bc7`) | ✓ | ✓ | `t_r4_commissions` 7/7 | `honor_guard` 0 failures |
| R5 | 289 / 0 failed | 507/507 | 394/394 | `t_r5_equipment` 10/10 | `equipment_depth` 0 failures |
| R6 | 293 / 0 failed | 515/515 | 394/394 | `t_r6_reliquary` 8/8 | `reliquary` 0 failures |
| R7 | 298 / 0 failed | 521/521 | 394/394 | `t_r7_procurement` 6/6 | `harbour_captains` 0 failures |
| R8 (+ integration) | 303 / 0 failed | 527/527 | 394/394 | `t_r8_recognition` 5/5, `t_zz_integration` 1/1 (37 checks) | `world_recognition` 0 failures |

**Honest note on R3/R4:** their commit messages record the focused tests and probes, not the local suite counts; their
full gate is the CI "Tests" workflow (compile, suite, unit), green on both commits. One R3 leftover was found later — a
`t_contracts` check still read the retired `Game.state["chronicle"]` (a script error inside a test that still passed) —
and fixed in R5's commit. Every CI "Tests" run on the branch (R3 through the report) is green.

Every fallout in older tests was fixed honestly — by stating a fixture's premise or by asserting the new design
decision both ways — never by weakening an assertion: `t_tailoring` compares the material's own attack (a random
Keen affix is not the material); `t_recognition` asserts decision 16 (Epic for any maker, but no workshop honours);
`t_r2_truth` checks that "no effect" labels follow real effects; `t_contracts` reads the Chronicle view; the R4 and R6
fixtures name their premises. Two real bugs were found by the new tests and fixed: a family's piece in custody was
re-claimed by `Game.add_item`, and a day's news merged into an item already carried away never spread.

### 3.2 Saves

- **Golden saves:** all nine — 0.11.2, 0.12.4, 0.13.5, 0.14.6, artifacts 0.15, 0.16.19, 0.16.21, 0.17 and the **new R2
  head** (`branch-r2.json`, schema 10, produced from `e61053f` with the verbatim driver) — load, migrate through steps 11
  and 12, keep every identity, round-trip identically and play on (`t_saves` 27/27).
- **Deterministic replay:** save → load → play is bit-identical to playing on (`t_r3_history`).
- **Real saves untouched:** every run used a test save folder or an isolated `XDG_DATA_HOME`.

### 3.3 Multi-seed, multi-year campaigns (`tests/long_probe.tscn`, final code)

Two years each, three campaigns run in parallel; every audit is clean — 0 dangling event ids, 0 Chronicle lines outside
Lore, 0 duplicate uids, the Unique audit empty.

| Campaign | Lore events | Digests (folded ids) | Chronicle | Causal links | Save | Save / load | Sim per day (last 90 d) |
|---|---|---|---|---|---|---|---|
| seed 9001, steward | 19,184 | 425 (1,707) | 8,975 | 86 | 13.5 MB | 4.6 s / 3.6 s | 374 ms |
| seed 4242, steward | 16,647 | 298 (1,253) | 7,302 | 78 | 11.8 MB | 4.0 s / 3.0 s | 272 ms |
| seed 9001, idle | 11,827 | 10 (20) | 6,729 | 97 | 7.0 MB | 3.0 s / 2.6 s | 78 ms |

Timings were taken with three probes, a rendered regression and test suites running at once on the same machine, so
they overstate a player's cost. R3's earlier three-year probes (seeds 9001 and 4242 with the steward, 9001 idle) were
equally clean: 18.8 / 13.0 / 8.1 MB at day 1,095. For comparison, R2 at three years: 6.9 MB, but with 3,652 dangling ids
and 355 Chronicle lines that were not in Lore.

### 3.4 Identity, Unique and conservation

- `ItemRegistry.scan()` shows no duplicate uid and no shared dict in every new suite test and in the integration
  scenario; the Reliquary, institutions, voyages' goods and families' homes are registered holders.
- One authentic Grimhold throughout (`Uniques.audit()` empty in the probes, the journeys and the rendered phases).
- Conservation: every coin has a payer (escort fees, voyage deposits and refunds, compensation and purchases appear
  as ledger lines with their party); goods paid are the same instances moving holder (`Provenance` "payment").

### 3.5 Balance (20 seeds × 90 days) and the militia comparison

See §4. The militia's effect is shown with seeded campaigns with and without consignments, and with a same-state
counterfactual (patrols set to zero in the very same world) that isolates it: fewer bandits on the nearest bandit road,
a lower live danger there and a safer trade road for a hireling (`t_r8_recognition`).

### 3.6 Rendered regression

**77 of 77 phases pass with 0 failures** — the 72 phases of R2's regression plus the five new ones (`honor_guard`,
`equipment_depth`, `reliquary`, `harbour_captains`, `world_recognition`), on the final code at 1920×1080.

- `identity_a1` failed once on an assertion written before R4 ("the masterpiece is in the holdings archive"); since R4
  an institution patron (the Watch) keeps a delivered masterpiece in its own stock — the suite's `t_identity` and
  `t_contracts` were updated in R4, this rendered phase was missed. Updated to assert the same instance in the Watch's
  stock; rerun: 0 failures.
- `stations` (and `full`, which includes it) failed once: it opens every station and expected a crafting panel, but the
  Reliquary opens its own panel (as the Project Bench opens the contracts). The phase now accepts that, as it did for
  the bench; rerun: `stations`, `full` and its pair `reload` 0 failures.
- `iter2_reload` failed in the long run because it reloads the save its partner `iter2` wrote twenty phases earlier, and
  phases in between write the same slot; run as a pair (`iter2` then `iter2_reload`) both pass with 0 failures.

Screenshots of the new phases were checked by eye; three layout problems found that way were fixed before their
milestones were committed (the refine panel's action row overflowing with eight actions; the escort picker squeezing
the road list; the item panel calling a piece in a family's home "lost").

## 4. Intentional behaviour differences (balance)

1. **R5 makes adventurers stronger, as decision 10 intends** (several affixes did nothing before). 20 seeds × 90 days,
   R4 (19 runs) vs R5 (20): adventurers' gold +26 % (t 3.4), mean level +8.5 % (t 2.1), missing expeditions −59 % (small
   counts), deaths −24 % (not significant), the smith's gold +3.7 %, reputation flat. Not retuned: the lever, if play
   finds it too generous, is Fortune's rate (luck × 3 % per find).
2. **R8 lowers danger only where the muster is armed.** Without consignments nothing changes (patrol 0). With a full kit
   (24 serviceable pieces) the patrols reach 0.90 after 45 days and the Highmarsh road's common bandits fall from 5 to 2
   (rendered `world_recognition`); reach falls off with the road: 1.0 within 1½ days, 0.6 for the 2–3-day bandit roads, 0.33 for the farthest (4–5 days).
3. **R6 Restore** is a new action; it can fail (materials spent) but never harms the piece.
4. **R8 political letters:** the muster's and the Watch's letters now wait sealed while the steward runs the forge
   (before: only lords' and the Crown's).
5. **R3:** the Chronicle keeps everything (no 400 cap); routine workshop events fold into monthly digests.

## 5. Known limitations and risks

- **Save size and load time grow with a long campaign** (one history keeps everything significant). See §3's probe
  figures. Options if it matters in play: fold routine feed lines (party departures and returns) into digests too, or
  compress the save file. Not done in this run.
- **Escorts for adventurer parties** are not a separate mechanism (decision 12 deviation, §2).
- **Digests are per item**, not per actor/place (decision 6 deviation, §2).
- **Militia upkeep:** the kit wears slowly on patrol and is never repaired; over a very long campaign readiness decays
  unless new consignments arrive. Intended as "neglect fades", but untested by players.
- **Visitors** come from the four regional patrons only; a visit brings their letter when one of their orders fits.
- **The Reliquary sprite** is a template derived from existing template art — creator art can override it as usual.
- **Only one bloodline Unique exists** (Grimhold); "not every Unique is bloodline-bound" is honoured by the data tag, but
  with one Unique in the game the distinction cannot yet be seen in play.

## 6. Windows playtest build

- **Version 0.18** on this branch only (`game/RELEASE_VERSION`, commit `47a0690`).
- **GitHub Actions run 45096260470** ("Windows installer", run 23):
  <https://github.com/crosenlund79/DNDBlacksmith/actions/runs/45096260470> — the full test gate (compile, suite, unit)
  passed on CI, the Windows and Linux builds were exported, the packaged Linux build passed its self-check, the NSIS
  installer was built, **installed silently and launched with its self-check on a Windows runner**, and the **"Publish
  release" job was skipped** (it runs only on the default branch). No release, no tag, no merge.
- **Artifact:** `EmberAndAsh-Windows-0.18.23` (about 210 MB; kept until 21 February 2027) —
  <https://github.com/crosenlund79/DNDBlacksmith/actions/runs/45096260470/artifacts/14783514288>
  (download while signed in to GitHub; SHA-256 of the zip `01830159d48a7d71429bcd2af7645b54e8b6e2c576a15310b7d509bef4caffa6`).
- What to try: [`R3_R8_PLAYTEST_CHECKLIST.md`](R3_R8_PLAYTEST_CHECKLIST.md).

## 7. Open items for you

1. **Decision 7:** should Reeve Tamsin Hale be titled mayor? (Not changed, by your instruction.)
2. **Confirm or overrule the provisional defaults in §2**, especially the two deviations (escorts for parties; digests
   per item) and the four heir answers.
3. **Balance after R5** (§4.1): playtest whether adventurers now earn and survive too easily.
4. **Save growth** (§5): decide whether a compression or broader folding step is wanted before 1.0.
5. **Integration and release** remain yours (no merge, release or tag was made). R9–R11 are not started.
