# Worker FAMILY (wave 2) — the living workshop's family (#50–52) and steward sleep pace (#40)

Read `docs/lw/lw_common.md`, `docs/LIVING_WORKSHOP_PROGRESS.md` (decisions 1–8), the FOUNDATION report
(`docs/lw/reports/foundation.md`), canonical v1.3 §4.5 (Steward Mode, the working smith, the pace), D14, and the existing family
code (romance/marriage: `inn.gd`, `roisin.gd`, `social.gd`; creature companions: `companions.gd`, Hale Farm). Base: the merged
wave-1 head the lead names.

## The user's brief (verbatim)
**5. Living workshop & family — OBS-50–52**
* A spouse may voluntarily participate in the workshop without consuming a normal employee slot.
* Primarily handle customer interactions, sales and appropriate support work; other work follows actual competence.
* Player configures spouse's maximum permitted customer discount, including zero.
* Preserve realistic business accounting, scheduling, relationship identity and existing family mechanics.
* Show the player's owned pet physically accompanying the blacksmith when appropriate, reusing existing art and companion
  behavior.
Do not create unlimited free production, duplicate staff identities or new compulsory micromanagement.
(#40) Offer optional faster time advancement (approximately 5×) when sleeping during Steward Mode, with coherent world
simulation and restoration of normal speed.

## Design within the lead decisions
- Spouse: an opt-in arrangement (asked in conversation; she may decline by personality/relationship) using the FOUNDATION
  capability model for her competence (actor id `spouse:<npc>` or her own id) — no apprentice record, no employee slot; works
  the counter during her hours (serves waiting customers: sales at display prices minus at most the configured discount,
  repairs only if competent, never commissions requiring decisions); every sale is a normal ledger line (party = the buyer;
  money to the forge's purse); her schedule and relationship identity unchanged; the steward may use her counter work.
- Discount cap: a setting in the workshop/steward or family panel (0–N %, default 0 % or a modest value — justify); enforced in
  the sale path; tested.
- Pet: if the player owns a creature (Hale Farm), it follows the smith at a short distance in the world (existing creature art
  and companion movement), stays out of doorways/stations, waits outside where it cannot enter; never for adventurers' companions.
- Sleep pace: while Steward Mode is active and the steward-smith sleeps, an optional 5× pace (setting, default off or on —
  justify) — the whole simulation consistently (`Engine.time_scale` as in S2), back to 1.5× on waking and 1× on exit; never
  outside Steward Mode; zero XP unchanged.

## You own
Spouse/counter code (`shop.gd` counter-service path only, `social.gd`/`inn.gd`/`roisin.gd` small hooks), a family/workshop
settings panel section, pet follower (`scripts/world/` new small actor + a minimal `world.gd` hook), `steward.gd` /
`steward_smith.gd` sleep-pace parts (coordinate: PRODUCTION edits steward work-order adapters — keep your changes to the pace).
Tests `t_lw_family.gd`; rendered phase `lw_family` (the spouse at the counter, a sale within the cap, the pet following, the
steward sleep pace). Report per `lw_common.md`.
