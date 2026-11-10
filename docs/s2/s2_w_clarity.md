# S2 worker CLARITY — workshop clarity and physical presence

Read `s2_common.md` first, then the canonical §1.2, §3.2, §11, and `docs/EMBER_ASH_PLAYTEST_OBSERVATIONS.md` OBS-11 … OBS-16,
OBS-21 (current behaviour and code anchors are recorded there) and decision-register BUG-001, BUG-043, BUG-044.

## The user's S2 brief (verbatim, your section)
**4. Workshop clarity and physical presence**
* Fix leather-curing quantity-versus-quality feedback.
* State skill-check type before the action.
* Prevent loot bags, linen thread and processed materials appearing beneath Loft stairs.
* Grey out unaffordable potion/item offers with reasons.
* Provide optional filtering of ineligible or unusable items.
* Verify apprentice visibility at actual workstations; correct real defects without unnecessary new art.
* Correct the contracts panel collapsing on closed orders.
* Add restrained contextual highlighting of nearby usable stations and people.
* Use existing lighting infrastructure for warm, flickering evening/night forge lighting.
* Investigate a functional exterior/front entrance; implement only if compatible with existing navigation without major
  restructuring.

## What Run 0 already found (verify; do not trust blindly)
- Leather curing (OBS-11): `cure_leather` 2 Raw Hide → 2 Cured Leather at `leather_vat`; +1 unit when craftsmanship ≥ 105 %
  or purity = 6 (`crafting.gd` ~661–664); the result panel shows "Cured Leather ×N" and "Craftsmanship N%" but never states the
  bonus rule; batch quality is silently lost when material stacks merge (`game.gd` ~221–231). Minimum honest fix: say what
  produced the extra unit (or why none) and that leather quality does not carry into products (unless you find it does).
  Do not invent a new quality-carrying mechanic.
- Skill-check type (OBS-12, BUG-044): the station panel header names the mechanic but quotes precision-ring zone/needle values
  for every mechanic; the world interaction prompt (`WorldPrompts._station`) does not name it. State the check type (and per
  operation) before the player commits.
- Under the Loft stair (OBS-13/14): every `Game.state.returns` bag is drawn at spot `smithy_bag` = smithy (12.0, 7.6) +
  offsets, z 0; the Loft stair `props/stairs_up` is at the loft's `down_stairs` = smithy (12.4, 7.4), z 1. The user now names
  **linen thread** and processed materials too: find every floor drop (returns bags incl. hireling processing/trade-run
  hauls, sponsor deliveries, Project Bench crates, anything else) and keep them clear of stairs/lift/doors with a keep-clear
  rule (Property validation), not only by moving one spot. Reproduce with the Loft owned (before/after screenshots).
- Potion offers (OBS-15, BUG-043): the counter "goods" branch of `ShopPanel` lists every potion as always-enabled buttons;
  `Shop.sell_goods` refuses afterwards ("can't afford") and ignores the customer's `looking_for`. Grey out what they cannot
  afford or did not ask for, with the reason; selling must match the request (fix BUG-043). Prefer reusing the A2
  `OfferPicker` pattern for consistency if it fits.
- Optional filtering (OBS-16): add an optional "show only what they can use/afford" style filter where lists show ineligible
  items (offer grid, potion list, vendor/inventory where it makes sense). Default must keep blockers discoverable (canon §3.2):
  filtering is opt-in.
- Apprentice visibility (OBS-21): on-shift apprentices walk to and work at the station of their operation
  (`apprentice_actors.gd`, tested by `t_workshop_ui.test_actors_follow_shift`). Gaps: idle apprentices wait in the forge room;
  field hirelings (Borin) stand only by ground-floor classic/alchemy/runecraft stations; Loft stations; Steward Mode.
  Reproduce the user's situation as best you can and fix real defects; no new art.
- Contracts panel (BUG-001): opened directly on a closed order its right column collapses to one letter per line.
- Highlighting: restrained contextual highlight (outline/glow) of the nearest usable station or person in reach; must not
  clutter; respect existing prompt logic.
- Lighting: warm, flickering forge light at evening/night using the existing light infrastructure (light masks/PointLights
  already used for lanterns/windows; `world.gd` ~1436–1496). No new art; keep performance.
- Front entrance: investigate (layout, doors, navigation); implement only if it fits existing navigation without major
  restructuring; otherwise report options.

## Deliverables
- Code; `tests/suite/cases/t_s2_clarity.gd` (logic tests: leather result text states the rule; check type stated in prompt and
  panel; no floor drop overlaps a stair/lift/door with the Loft owned; goods offers disabled with reasons and sell_goods honours
  the request; optional filter hides ineligible items only when enabled; contracts panel builds on a closed order with a
  sensible width; highlight picks the nearest usable target; night forge light present).
- Rendered phase `s2_clarity` (`tests/playtest_s2_clarity.gd`) with BEFORE/AFTER screenshots at 1920×1080 for each item
  (copy to `…/scratchpad/s2/shots/clarity/`). LOOK at them.
- Report per `s2_common.md`.
