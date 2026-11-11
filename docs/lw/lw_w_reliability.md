# Worker RELIABILITY (wave 1) — playtest defects (reliability, crafting checks, world behaviour)

Read `docs/lw/lw_common.md` and `docs/LIVING_WORKSHOP_PROGRESS.md`. Base: the lead's brief commit on `claude/living-workshop`.
Investigate first (reproduce, find the root cause, cite code), then fix clear defects. Never guess a cause.

## The user's items (verbatim)
* #57: Find and fix shields disappearing when equipped by the blacksmith; protect UID/ownership.
* #59–60: Investigate/reproduce crashes around skill-tree interactions, including after moving newly purchased stations.
  Verify autosave and recovery; do not guess the cause.
* #61: Prevent commissions requesting impossible equipment/material combinations. Validate against actual obtainable
  Designs and production capabilities.
* #39: Investigate adventurers clustering during village movement; improve natural distribution without breaking real
  schedules.
* #53: Investigate excessive difficulty of Weave Linen Cloth precision checks.
* #58: Investigate excessive difficulty of weapon rune binding. Fix interaction/precision problems without making mastery
  meaningless.
* #45: Investigate unusually valuable early-game adventurer equipment versus available spending money (Day 17, level-7
  paladin, 2,279g Adamantine armor, unable to afford 261g boots).
* #56: Examine unusually easy commission acquisition from directly asking adventurers. Record findings for the later balance
  pass; fix clear rule defects only.
* #41: Mining progression was corrected by `4fbfaee`; verify, do not redesign.
* #48: Manual store pricing exists; preserve and make discoverable.
* #49: The hidden `???` discovery beyond Alloy Production is intentional; preserve its mystery and discovery path.

## Notes
- #57: the smith's own equipment (player equipment slots, equip/unequip from inventory, shield slot vs weapon two-handed
  rules?) — reproduce in a test; protect uid and ownership (`ItemRegistry.scan` clean).
- #59–60: drive the skill-tree panel after buying and moving stations (Property plan editor) headless and rendered; capture
  the Godot error/stack; check autosave timing and the `.bak` recovery path. KNOWLEDGE (wave 2) will rework the tree: keep
  your crash fix minimal and add a regression test.
- #61: commission/request generation (`Shop.create_order`, `Adv` wants, A2's `slot_capability`, contracts) must only ask for
  def/material/stat combinations some known or obtainable Design can produce; keep the A2 "visible opportunity" share honest.
- #53/#58: compare the check parameters (data/crafting.json minigames, station difficulty, op difficulty) with other checks
  at equal skill; fix interaction/precision bugs (e.g. hit windows, input handling, speed at low levels) — not blanket nerfs.
  FOUNDATION (parallel) moves checks to per-actor parameters: change only the minigame/check DATA and minigame code, not
  `crafting.gd` check_params.
- #39: schedule spots/jitter (`world.gd` spot assignment, `living.gd`): spread people around real destinations.
- #45/#56: investigate and record numbers; fix only clear rule defects (e.g. starting gear valued wrongly, a commission path
  that skips a rule). No economy rebalance.

## You own
The equipment/equip code paths for the player, `skilltree_panel.gd` (crash fix only), `property_panel.gd` (crash fix only),
`shop.gd` order generation, `adventurers.gd` request/want generation, `contracts.gd` offer feasibility, minigame code and
`data/crafting.json` minigame params, `world.gd` schedule-spot distribution only, `living.gd`, `consult.gd`/`talk.gd`
commission asks. Tests: `t_lw_reliability.gd`; rendered phase `lw_reliability` (shield equipped and kept; the skill tree after
moving a bought station; a weave and a rune binding at a normal skill; a commission card that is makeable).
Report per `lw_common.md` with observation-by-observation outcomes and numbers (#45, #56).
