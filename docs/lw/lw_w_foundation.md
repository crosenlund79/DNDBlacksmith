# Worker FOUNDATION (wave 1) — B1 professional foundations

Read `docs/lw/lw_common.md`, `docs/LIVING_WORKSHOP_PROGRESS.md` (lead decisions 1–8), canonical v1.3 §4.2–4.5, §15, D1–D4,
D7, and the decision-register entries STAFF-001 … STAFF-019, TECH-002, TECH-004, PROD-009 (they record today's code: e.g.
the smith's levels still decide ~17 cross-discipline behaviours; apprentices may only make what the smith learned; hirelings
produce goods off-station; no `profession` field exists). Base commit: the lead's brief commit on `claude/living-workshop`.

## The user's brief (verbatim)
**1. Professional foundations — B1.** Implement the approved hybrid workshop profession architecture:
* Shared worker capability model, with separate workshop employees and field hirelings.
* Professions: blacksmith, leatherworker/tailor, runesmith, alchemist/herbalist and arcanist.
* Each worker has independent professional competence, progression and eligibility.
* The player specializes deeply in Smithing. Basic non-smithing tasks remain possible at the player's actual competence;
  mastery belongs to specialists.
* Skill checks, crafting quality, workstation access and task eligibility use the actual worker's competence, not
  automatically the player's.
* Preserve existing apprentices, hirelings, contracts and their legitimate progression.
* Migrate old saves and existing worker skills without losing earned progress.

## You own
A new `scripts/systems/workers.gd` (class `Workers`: the shared capability API — profile of any actor id "player",
apprentice id, hireling id, later "spouse": profession, competence per discipline/skill, `can_do(actor, op/station/recipe)`
with the reason, `check_params(actor, …)`, quality inputs, XP grant routing per actor), `skills.gd`, `apprentices.gd`,
`hirelings.gd` (profile fields only — do not remove their field work), the actor-dependent parts of `crafting.gd` (checks,
quality, eligibility, XP routing — keep the Mining XP hotfix and the steward zero-XP guard in `Game.grant_player_xp`),
`guide.gd`/`reference.gd` eligibility wording, `save_migrations.gd` step **5** + `Game.SAVE_VERSION` 5, and tests.
Do NOT restructure the skill tree / workshop knowledge (KNOWLEDGE, wave 2) or build work orders/station instances
(PRODUCTION, wave 2): leave clean seams (`Workers.can_do`, per-actor `check_params`) they will build on.

## Design within the lead decisions
- Profiles: `profession` (one of blacksmith, leatherworker, runesmith, alchemist, arcanist), competence = existing skill
  levels (SkillSys) per discipline; apprentices gain a profession by migration from their strongest workshop skill (or their
  preference list); new applicants come with a profession; hirelings get a read-only field profile.
- Player: profession blacksmith; deep smithing; non-smithing at his actual levels; NEW non-smithing XP stops at a basic cap
  (pick a constant, e.g. level 5, justify) — existing higher levels are kept (never reduced).
- Eligibility: a worker may do an operation when the workshop knows the Design (today: the tree/known recipes — keep as is
  for now) AND the worker's competence in the station's discipline meets the operation's requirement; specialists are no
  longer limited to what the smith personally learned (remove that rule; update `t_apprentices` with a parallel specialist
  route, do not just delete assertions). Show reasons ("needs a runesmith of level N", "the smith's alchemy is basic").
- Per-actor checks: `check_params(actor, …)` drives zone/speed/quality from the actor's level, not the player's.
- Migration step 5 "worker professions": idempotent; existing apprentices/hirelings keep every level, XP, trait, wage,
  history and contract hours; the player keeps every level; golden saves 0.11.2–0.14.6 migrate.

## Deliverables
`t_lw_foundation.gd` (profiles; per-actor checks and quality; eligibility with reasons; player basic cap with preserved old
levels; specialists not limited by the smith's tree; migration 5 idempotent on golden saves and a schema-4 save with
apprentices; steward zero XP and the Mining XP hotfix still hold); keep all suites green; rendered phase `lw_foundation`
(applicants with professions, a specialist doing work the smith cannot, eligibility reasons in the station panel).
Report per `lw_common.md`, including the exact API (`Workers.*`) the wave-2 workers will use.
