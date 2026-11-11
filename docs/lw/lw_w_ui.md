# Worker UI (wave 1) — interface and information

Read `docs/lw/lw_common.md` and `docs/LIVING_WORKSHOP_PROGRESS.md`. Base: the lead's brief commit on `claude/living-workshop`.

## The user's items (verbatim)
* #38: Adventurer health-history curve using actual recorded health, without fabricating historical values.
* #42: Support 10 safe save slots.
* #43: Fix clipped gold/quantity counters at upper-left.
* #44: Make caravan arrival more noticeable.
* #46: Material inventory ledger showing accumulated acquisitions and current remaining stock. Preserve accurate historical
  data; clearly distinguish unknown pre-existing history.
* #47: Significantly reduce oversized buttons, wasted space and panel crowding throughout relevant interfaces. Maintain
  readability, scaling and keyboard access.
* #54–55: Clearly distinguish waiting customers, commission opportunities and visiting adventurers. Make inn commission
  opportunities discoverable.

## Notes
- #38: draw from health values the game actually records (expedition records, injuries, Lore, daily snapshots if any). If
  history is not recorded, start recording now (lazily, capped) and show "no record before day N" — never invent points.
- #42: 10 manual slots (+ autosave, quicksave), atomic writes and `.bak` as today (A1), the Load screen, newer-schema refusal;
  `t_saves` patterns; old saves in slots 1–3 untouched.
- #43: HUD top-left counters (gold, quantities) must not clip at 1920×1080 and 1600×900 with large numbers.
- #44: a clear, non-intrusive arrival notice (toast + a marker/journal line + sound if one exists) using existing assets.
- #46: record material acquisitions/consumption from now on (where Game.add_item/remove_def happen for materials, via a small
  hook) and show per material: acquired (by source), used, remaining; for history before the feature: "unknown before
  day N". Preserve the ledger (gold) as is.
- #47: reduce oversized buttons and wasted space: start with the shared UIKit sizes/margins and the worst panels (inventory,
  shop counter, station panel, steward panels, dossier, ledger, help); keep readability (min font sizes), scaling and keyboard
  focus. Wave-2 workers will build new panels on your UIKit changes — keep APIs backward compatible. Before/after screenshots.
- #54–55: distinguish at a glance (labels/icons/sections) waiting customers, commission opportunities (incl. those raised at the
  inn) and visiting adventurers; make inn commission opportunities discoverable (where they are offered, a hint/marker).

## You own
`dossier_panel.gd` (health curve), `saves.gd`/`save_panel.gd` (slots), the HUD (`hud*.gd`), caravan arrival notices
(`commerce.gd`/`trade.gd` notice code only), a new material-ledger panel (+ a small hook in `game.gd` add/remove for materials —
coordinate: FOUNDATION also edits `game.gd` only for SAVE_VERSION; keep your hook small), `ui_kit.gd` and the panels you
resize, `shop_panel.gd` sections, inn/talk commission-opportunity hints. Tests `t_lw_ui.gd`; rendered phase `lw_ui` with
before/after screenshots at 1920×1080 and 1600×900.
Report per `lw_common.md` with observation-by-observation outcomes.
