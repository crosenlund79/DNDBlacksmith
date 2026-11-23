# Ember & Ash — Playtest checklist for the completion-run build 0.18 (R3–R8)

A short, practical list for playing the build. Each line says what to try and what should happen. Tick it, or note
what happened instead. Developer Tools (F10, with cheats on) can speed things up — use them to grant gold, stations or
skills, not to fake outcomes you want to judge.

> Saves: the build reads saves from 0.11 onwards (schema 12 now). Keep a copy of a save you care about before loading
> it in a test build. Nothing in this build touches the save folder except your own saving.

## R3 — One history

- [ ] Open the History / Chronicle: lines read like before, nothing is missing from an older save you load.
- [ ] Open a well-used piece's History tab: its events agree with what the Chronicle said about it.
- [ ] After a death on an expedition, the fallen adventurer's blade comes home in a chest; its history says it was
      carried home after the death (the "because" link shows as a follow-on event).
- [ ] Play a few in-game months: saving and loading stay quick enough (note the time if it feels slow).

## R4 — Commissions v2 and civic recipients

- [ ] The reeve's Honor Guard letter (muster) arrives once the forge has the standing: ten helms, ten round shields and
      three named pieces (Vigil, Hearthward, Millstone).
- [ ] The named pieces appear as work orders; lay them in from the contract view; delivery is refused until all are in.
- [ ] After delivery, the contract record shows where the pieces went (the Brindlewick muster) and the lot.
- [ ] Molds and patterns (Skill Tree) make series pieces faster at the Project Bench.

## R5 — Equipment depth

- [ ] Item tooltips list each affix's effect separately from the stats (e.g. "Keen — critical hits on 19–20").
- [ ] Three matched pieces of one set from your mark give the set's line; mixed makers do not.
- [ ] With an arcanist on staff, the Spellbinding Array offers Enchant: the risk line is shown before you begin.
- [ ] The anvil's "Temper beyond" asks for a second, deliberate click after stating the danger. Without it nothing happens.
- [ ] A ruined (unusable) piece cannot be refined, reworked or sold as working kit.

## R6 — The Reliquary and heirs

- [ ] Buy the Reliquary (station list) and place it in the smithy. Interact: the panel opens.
- [ ] A working Epic piece is refused ("forged to be wielded"); a broken piece nobody remembers is refused.
- [ ] A broken or unusable piece with a remembered deed can be laid in. Your reputation does not change.
- [ ] If its last bearer fell and had family in the village (Garrick → Martha, Mira → Aldric, Kestra → Tobin), that
      relative writes a few days later. A bearer without family: no heir — and no one appears out of nowhere.
- [ ] Write back (choose a compensation; optionally offer to buy). The next day: decline, custody, "send it home", or a sale.
- [ ] Custody: the piece cannot be put on display or pawned. "Send it home": restore it ("Restore" at the anvil) and it
      leaves your forge for the family.
- [ ] Grimhold, the Last Hammer (if you ever have it): restored without its line's consent it stays weaker; with consent it wakes.
- [ ] Hand the forge to the steward: heir letters wait sealed; the steward never answers them.

## R7 — Negotiation and procurement

- [ ] Harbour → Captains: the captain in port is named; commission a voyage (deposit now). They sail when the ship leaves.
- [ ] The voyage lands on its day, is delayed (with a new day), or is lost (half the deposit back) — the Chronicle says which.
- [ ] Pay promptly; on the captain's next visit they mention it and their price is a little better.
- [ ] Leave a landed cargo unpaid for over a week: it is sold elsewhere and the captain trusts you less.
- [ ] Hirelings ledger: each road has an escort picker; the escort's price rises with the road's danger, and the
      injury figure shown with an escort is lower. The escort is away while the hireling is.
- [ ] Sponsor an adventurer and pay partly with a piece from your stores: if it serves them, they wear it at once.

## R8 — World recognition

- [ ] Deliver an order to the Brindlewick muster (the Honor Guard). Over the following weeks the world map's page for
      the Highmarsh road shows "Muster patrols reach here (N%)", and the bandits listed there thin out.
- [ ] Nothing changes the day the kit arrives; the change is gradual. Farther places are less affected.
- [ ] After a ship sails or a party sets out, news of your work can reach the region; a Highmarsh merchant, the Guild,
      the Watch or a Warden may come in person — the Chronicle says what they heard and how.
- [ ] A full purse alone brings no visitor and no renown.
- [ ] With the steward in charge, the muster's, a watch's or a lord's letters wait sealed and marked political.

## General

- [ ] No panel is cut off at 1920×1080 (the refine panel's eight actions wrap onto two rows).
- [ ] Note anything that feels too generous after R5's affix effects (adventurers earn and survive somewhat more).
- [ ] Note the save size and load time after a long session (R3 keeps the whole history).
