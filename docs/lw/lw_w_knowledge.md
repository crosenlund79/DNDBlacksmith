# Worker KNOWLEDGE (wave 2) — B2 skill trees, Designs and workshop knowledge

Read `docs/lw/lw_common.md`, `docs/LIVING_WORKSHOP_PROGRESS.md` (decisions 1–8), the FOUNDATION report
(`docs/lw/reports/foundation.md`: the `Workers.*` API, per-actor checks, migration 5), canonical v1.3 §4.2, §5, D2, D3, and
register entries STAFF-013/015/017/018, PROD-018/019, QST-003. Base: the merged wave-1 head the lead names.

## The user's brief (verbatim)
**2. Skill trees, Designs & knowledge — B2.** Separate:
* Personal competence: What an individual worker can actually do.
* Workshop knowledge: Designs, discovered techniques, materials and production methods the workshop knows.
* Professional development: Smithing's deep player tree and appropriate specialist progression.
Rename player-facing Recipes to Designs without needlessly renaming internal identifiers.
Preserve existing unlocks and secret discoveries. Eliminate progression deadlocks and incorrect cross-profession dependencies.
The Mining XP hotfix must remain functional. Workshop knowledge must not magically grant personal mastery.
(#49: the hidden `???` discovery beyond Alloy Production is intentional; preserve its mystery and discovery path.)

## Design within the lead decisions
- Workshop knowledge = which Designs (recipes), techniques and materials the workshop knows; a store separate from any
  person's competence. Migration step **6** "workshop knowledge": every node/recipe known in an old save becomes workshop
  knowledge (secrets and discoveries included); nothing is lost; idempotent.
- The player's tree: deep Smithing (personal techniques). Specialist progression: each profession's competence grows by their
  own work (FOUNDATION) and, where the data has specialist nodes, by their own tree/ranks — not by the player's levels.
- Non-smithing knowledge is acquired through a competent worker (or the player at his basic level) — no node may require the
  player to master another profession (remove those cross-profession gates; list every changed node); no deadlocks (prove
  every Design is reachable from a fresh game with hires; `t_integrity` "every recipe is learned from exactly one node" adapted
  to the new model, not deleted).
- Player-facing text: "Recipe(s)" → "Design(s)" everywhere the player reads it (panels, guide, help, tutorial, toasts); ids,
  data keys and save keys unchanged (AR §5.4: 626 identifier uses).
- Generator: `tools/data/make_skilltree.py` (+ regenerate data) — never hand-edit generated data.

## You own
`skilltree.gd`, `knowledge.gd`, `skilltree_panel.gd`, `data/skilltree.json` via the generator, recipe-visibility/eligibility
wording in `guide.gd`/`reference.gd`/`station_panel.gd` (coordinate: PRODUCTION owns the station panel's work-order parts —
keep your edits to naming and knowledge lines), migration step 6, tests `t_lw_knowledge.gd`, rendered phase `lw_knowledge`
(the player's smithing tree, workshop knowledge view, a specialist learning a Design the smith could not, the `???` node).
Report per `lw_common.md`.
