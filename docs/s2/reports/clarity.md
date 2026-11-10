# S2 worker CLARITY — workshop clarity and physical presence (report)

## STATUS (checkpoint)
- Worktree branch `worktree-agent-aee738b1431b52975`, HEAD `046800b`, tree clean, nothing uncommitted, not pushed.
- DONE (code + suite test + rendered BEFORE/AFTER): 1 leather batch feedback · 2 check type named (prompt, header, per
  operation; BUG-044) · 3 floor drops clear of stair/lift/doors (keep-clear rule in Property) · 4 potion offers greyed with
  reasons + BUG-043 · 5 optional filters (counter offers/draughts, village counters) · 6 apprentice working sides (3 real
  defects fixed) · 7 contracts panel BUG-001 · 8 contextual hint ring (+ focus ring z fix) · 9 night forge light.
- INVESTIGATED, NOT IMPLEMENTED (by brief): 10 front entrance — options (a)/(b)/(c) below, needs the user's intent.
- NOT STARTED: nothing.
- Last test results (final, on HEAD `046800b`): `run_tests.sh full` — compile 225 scripts, suite 300/300, unit 384/384,
  ALL GREEN. `t_s2_clarity` 9/9. Rendered `s2_clarity` on the result: 0 failures (on the base build: 15, the defects).
- Known breakages: none.
- Next steps: none for this worker; the lead merges the branch. The front entrance waits for the user's intent.


Worktree branch `worktree-agent-aee738b1431b52975`, based on `2e854af`. Verified before any change: remote
`crosenlund79/DNDBlacksmith`, `game/project.godot` `config/name="Ember & Ash"`, HEAD `2e854af`, clean tree. Canonical v1.2
read (§1.2, §3.2, §11, §14, §15), plus OBS-11…16, OBS-21, BUG-001, BUG-043, BUG-044.

**Classification: ALIGNED.** Every item fixes a defect or improves clarity in existing, approved behaviour (CV §1.2
"Clarity without overload", "A physical workshop matters"; §3.2 actions and blockers first; §11 "Honest information",
"Physical legibility"). The S2 brief is the user's explicit decision for these items. No new gameplay system, no
save-schema change (one additive key on new craft records, see item 1), no new art. The front entrance is investigated
only (options below).

**Result:** compile 225 scripts (223 + 2 new), suite 300/300 (291 + 9 new), unit 384/384 — ALL GREEN. Rendered phase
`s2_clarity`: 0 failures on the result (15 failures on the base build: the defects it documents). BEFORE/AFTER screenshots
(1920×1080, all looked at) in `…/scratchpad/s2/shots/clarity/` as `NN_before_<what>.png` / `NN_after_<what>.png`, plus a
few side-by-side crops `cmp_*.png`.

How BEFORE was taken: `git archive 2e854af game` into `…/scratchpad/s2/clarity_base/` with only the new phase file and its
3-line registration copied in. The phase uses only APIs that existed before S2, so the same script produced both sets.

---

## 1. Leather curing: quantity versus quality (OBS-11)

**Finding (verified).** `Crafting.build` adds one unit to any stackable non-equipment output when craftsmanship ≥ 105 %
or the purity die is 6 (all 22 material recipes have only a purity die; none has a fortune die, so materials are always
Common). The result screen showed "Cured Leather ×N" and "Craftsmanship N %"; the dice text never stated the rule (the
data description "a 6 adds a unit" is replaced by the roll explanation), and the 105 % rule appeared nowhere. The batch's
craftsmanship is not carried: inputs are consumed by kind (`Game.remove_def`), product statistics use the recipe's
material table, and plain material stacks merge by def + rarity. So the honest message is "craftsmanship buys quantity,
not grade". No quality-carrying mechanic invented.

**Changed.** `crafting.gd` (`build`, non-XP lines only): `YIELD_BONUS_Q` constant and a `craft.yield` record
`{base, bonus, why, purity}` on new stackable batches (additive key, nothing migrates). `craft_result_panel.gd`:
`CraftResultPanel.yield_lines(item)` + a `YieldNote` under the craftsmanship: "Batch: 3 Cured Leather — the recipe makes 2,
+1 bonus unit because your craftsmanship reached 112 % (105 % or more adds a unit)" / "No bonus unit: that needs 105 %
craftsmanship or a purity 6 — this batch had 98 %, purity 4", and for plain materials "Craftsmanship sets how many units a
batch yields, not their grade: these join your Cured Leather stock and work exactly like the rest in later recipes."
Older records without `yield` are reconstructed from the recipe and the dice.

Tests `t_s2_clarity.test_leather_batch_explained`; shots 01–02.

## 2. Skill-check type before the action (OBS-12, BUG-044)

**Finding.** Header quoted ring zone/needle for every mechanic; the world prompt named no check.
**Changed.** `station_panel.gd`: `StationPanel.check_name(sid)` and `check_line(sid)`. Header: ring → "Check: precision ring
— … target zone 38° and the needle turns 0.52 rev/s (your Smithing 4 widens and slows it)"; others → "Check: Spark & Ember
alignment (not the precision ring) — at average difficulty: tolerance 120 %, pace 92 % of standard …" (the same zone/speed
→ ease/pace conversion MinigameBase uses). Per operation: each recipe row lists "Op (check)" before Begin; the step list
of the work in hand, the work button and the practice button name the check. `world_prompts.gd` `_station`: status
"check: <name>" → "Bellows — [E] Craft (2 ready) · Practise (check: Spark & Ember alignment)" (not for locked stations).
Minigames code (EARLY's) untouched — only its public `mechanic`/`label` are read.
Tests `test_check_type_named_before_the_work`; shots 03–05.

## 3. Loot bags, linen thread and processed materials under the Loft stair (OBS-13/14)

**Finding (reproduced, Loft owned).** All `Game.state.returns` containers (expedition finds, a hireling's haul incl.
trade-run purchases such as linen thread, sponsor deliveries, gifts, recovered gear) were drawn at `smithy_bag` (12.0, 7.6) —
inside the reserved stairwell rect — plus fixed offsets: 4 of 6 bags under the stair picture, competing with it for E. No
world sprite exists for processed materials outside these containers (crafting/apprentices/hireling processing go straight
to the stores). Project Bench crates (`ContractWorld.free_spots`) avoided stations but not the hoist or doorways.
**Changed.** `property.gd`: keep-clear rule `Property.drop_problem(p, half, beside)` (off the stairwell and hoist rects,
≥ 1.6 tiles from any stair/lift, off landings, doorways, the front door and station footprints, wholly inside a room) and
`Property.drop_spots(n)` (clear places in the stock hall, nearest first, a pile's width apart; overflow piles on the
existing places rather than spilling onto the stair). `world.gd` `_refresh_bags` uses it. `data/layout.json` +
`tools/data/make_layout.py`: `smithy_bag` → (14.6, 7.6). `contract_world.gd` `free_spots`: crates pass the same rule.
Tests `test_floor_drops_keep_clear` (1/6/12 drops, world interactables vs the stair picture and its E radius, bench
crates); shot 06.

## 4. Potion/item offers greyed with reasons; BUG-043

**Finding.** Goods branch: every potion an always-enabled button; `sell_goods` refused only on budget and ignored
`looking_for` (whetstone oil filled a healing-draught request). OfferPicker was not reusable (adventurer-only: purse,
slots, purchase_check), so the goods list follows its look (dimmed slot, ✓/✗ line, explicit Sell).
**Changed.** `shop.gd`: `Shop.goods_refusal(c, it)` ("" / "wrong" / "budget") used by `sell_goods` ("Martha asked for
Healing Draught, not Whetstone Oil."). Old customers without `looking_for` still accept any draught. Pricing untouched.
`shop_panel.gd`: `ShopPanel.goods_candidates(c)` + `_goods_offers`: one row per draught, unit price, "Sell one for N g" or
greyed with "✗ not what they asked for — they want Healing Draught" / "✗ over their budget — 71 g; they spend up to 50 g",
buyable first, tooltip reason. The Steward's goods path already sold only `looking_for` and is unaffected.
Tests `test_goods_offers_follow_the_request`; shots 07–08.

## 5. Optional filtering of ineligible items (OBS-16)

Opt-in, **off by default** (canon §3.2: blockers stay discoverable), remembered for the session (static vars, no save):
- Counter: "Only what they would buy" (`OfferPicker.only_buyable`) — draught list and the A2 offer grid; the grid rebuilds
  itself (`OfferPicker.rebuild`) and shows "N hidden"; the draught list says "3 other draughts hidden — … (untick …)".
- Village counters (herbalist, Pell's): "Only what I can buy now" (`HerbalistPanel.only_affordable`, `buy_blocker`) hides
  sold-out/unaffordable cards and counts them; unaffordable cards also show "Your purse holds N g." (the reason was only a
  tooltip).
**Not done:** inventory (it lists the smith's own stores; nothing there is "ineligible" — type tabs already exist); the
station recipe list (already has All / Craftable now / Missing / Locked, default All); caravan/pawn/harbour panels (they
already disable unaffordable rows; same toggle could be added if wanted). Tests `test_optional_filters_hide_only_ineligible`;
shots 08, 10, 12.

## 6. Apprentice visibility at actual workstations (OBS-21)

**Reproduced** (full building, three apprentices with tasks at forge, leather vat and a loom moved to the Loft, a fourth
idle; Steward Mode on): all visible, in their rooms, also upstairs and in Steward Mode — the core works. Real defects found
on the base build by checking every installed station's working side (`ApprenticeActors.work_spot`):
1. **forge** — the apprentice stood on the outer north wall (the "above" side ignored the 86 px figure; shot 19 before);
2. **reagent table** — worked from the arcane room, through a wall;
3. **arcane anvil** — worked from the street outside the south wall (the nav grid outside is walkable).
**Changed** `apprentice_actors.gd`: `_spot_ok` requires the figure inside the room it stands in (`_inside_room`, false
outside the building); `work_spot` requires the station's own room (`room_id`), fallback searches only that room
(`_free_near(p, in_room)`). No new art. Remaining by design / not changed: an apprentice with no task waits in the forge
room; the noon break; field hirelings (Borin) still use the three ground-floor `work_*` spots (`world.gd _smithy_spots`) —
not Loft/stitching/arcane; changing hireling placement was not needed for a reproduced defect. Multi-worker staged
traversal is C1. Tests `test_apprentices_stand_inside_rooms`; shots 19–21.

## 7. Contracts panel collapsing on closed orders (BUG-001)

**Root cause.** `UIKit.label` wraps text longer than 48 characters; the closed-order and letter views put the title and
its subtitle in a VBox with no width of its own, so a long title (the Watch's and the Guild's 61-character orders) gave the
right column one letter per line (reproduced on base: shot 14 before; the 43-character drovers' order did not trigger it,
which is why it was intermittent). The contract-in-hand view already set a 900 px width.
**Changed** `contracts_panel.gd`: one `_header()` for letter and closed views (expanding, word-wrapped, 900 px); the closed
order's summary line keeps 1060 px. Tests `test_contracts_panel_on_a_closed_order` (fails on base: 0 px labels); shots 13–14.

## 8. Restrained contextual highlighting

**Finding.** The existing gilt focus ring (HB-014) was at z −1 inside the floor layer — under every interior floor, so
indoors it never showed (only the faint sprite brightening did). **Changed** `world.gd`: focus ring and the new hint ring at
z 2 (above floors, station bases, the forge shade; below figures). New: one faint, slowly breathing ring (2.5 px, alpha
≈0.2–0.5) on the nearest *usable* station or person within 320 px that is not yet in reach — `station_usable` (the next
step's station during a job; else a station where a recipe can begin; the bench with a contract), `person_usable`
(WorldPrompts verbs beyond "Talk": serve, delivery…), `hint_pick` (pure), `hint_candidates`; refreshed every 0.4 s; hidden
while a window is open or the steward has the forge. Prompt logic unchanged. Tests `test_hint_picks_the_nearest_usable`;
shots 04 (focus ring now visible), 15.

## 9. Warm, flickering evening/night forge light

`world.gd _forge_night_light`: a `Flicker` PointLight (FX.light, #ff6a1c, 640 px, gain 1.7) registered as a night light, so
`_update_light` scales it with `night_amount` (comes up from 17:12, full from 20:24, gone by day) and Flicker breathes it;
added after the night dressing so it keeps the interior cull mask. A rendered probe (not committed) confirmed it is not
cut by a per-item light limit. One extra light; no new art. Tests `test_forge_night_light` (22:00 burns, 18:30 rising,
13:00 off, mask 1); shots 16–18.

## 10. Front entrance — investigated, not implemented

The smithy already has a functional entrance: the north door (plan x 13–15) opens from the main road into the shop; the
roof fades as the smith walks in; the nav graph, customers' seats, display table, door mat, sign and door light are all
there (shots 22–23). What the player cannot see from the street is the doorway itself: every building's roof covers its
whole footprint, there are no facades, and the art set has no door/porch sprite (all props are `template_`). Options:
(a) code-only: a darkened threshold cut into the roof edge over the door plus a brighter door lamp — small, no nav change;
(b) a door hood/awning prop over the door (one new prop with a `template_` fallback);
(c) a second, south "yard" entrance through the material store's loading door (the unit text mentions it) — needs a new
outer door, nav links, `Property` front-door keep-clear and customer routing: larger. Recommend (a) or (b) if the user
meant "I cannot see where the door is"; (c) only on explicit request. Needs the user's intent.

---

## Design choices made
- Bonus-unit wording states the existing rule; "quality not kept" shown only for type `material` (draughts keep quality).
- Filters are opt-in, session-only; hidden rows are always counted on screen.
- Hint "usable" = something to do now (not merely unlocked), one ring at a time; the focus ring's z fix also changes the
  pre-existing focus highlight (it now shows indoors as HB-014 intended).
- Goods customers from old saves without `looking_for` accept any draught (no behaviour change for them).

## Proposals (not built)
- Same "only what I can buy" toggle for caravan, pawn and harbour panels.
- Field hirelings (Borin) visible at stitching/arcane/Loft stations when working in the smithy.
- Front entrance: option (a)/(b) above, pending the user's intent.
- `UIKit.label` auto-wrap > 48 chars is a trap for any box without a width; a lint/test over panels could catch it.

## Files touched outside my list (tiny, local)
- `scripts/systems/crafting.gd` — `build` yield record + constant (no XP path; STEWARD owns XP paths).
- `scripts/systems/shop.gd` — `goods_refusal` + `sell_goods` check (BUG-043, explicitly in my brief; no pricing touched;
  ECONDEV owns pricing).
- `scripts/systems/property.gd` — new drop rule section (my list names its keep-clear rules).
- `scripts/world/contract_world.gd` — two lines in `free_spots` (Project Bench crates were in my brief).
- `tools/data/make_layout.py` — `smithy_bag` spot, mirroring `data/layout.json`.
- `tests/playtest.gd` — 6-line phase registration only.
`world.gd`: only `_refresh_bags`, `_update_focus` (one call), `_set_highlight` (z line), new hint section, new
`_forge_night_light` + one call in `_build_atmosphere`. `Smithy.walk_to_station` untouched.

## Commits (worktree branch, not pushed)
- `52f6029` leather batch says what decided its size (OBS-11)
- `67b0ada` the skill check is named before the work (OBS-12, BUG-044)
- `e7327b7` potion offers follow the request; optional filters (OBS-15, OBS-16, BUG-043)
- `27ba827` contracts panel keeps its width on a closed order (BUG-001)
- `55fb74b` apprentices work from inside their station's room (OBS-21)
- `460ddc2` floor drops clear of the stair, contextual hint, night forge light (OBS-13/14)
- `2a7f3d8` focus and hint rings above interior floors; forge night light tuned
- `046800b` suite case t_s2_clarity and rendered phase s2_clarity
