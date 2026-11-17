# R1 Acceptance Checklist — human Windows playtest of build 0.17 (private artifact)

*For the user's own Windows play session of the R1 build. It records REL-004 and REL-005/STW-027 evidence (human
acceptance of the current build and of Steward Mode).*

- **Build under test:** see the R1 report for the installer artifact link and commit.
- **Installing:** the artifact is private. It is **not** a release; nothing is published or tagged (decision D-1).
- **Saves:** installing 0.17 does not touch saves; they live in `%APPDATA%\Godot\app_userdata\Ember & Ash\saves\`.
  To be extra safe, copy that folder before you start.

**How to use it.** Tick each box and write a short note: what you saw, and anything odd. Put anything surprising
under **Observations**. It becomes a new OBS entry in the observation register, never a silent fix.

---

## A. Install and first start

- [ ] The installer runs and the game launches from the Start menu (no error dialog).
- [ ] The main menu reads cleanly at your screen size; New Game starts.
- [ ] **New game and tutorial:** the first steps (move, interact, craft, dice, serve a customer) guide you without
      getting stuck. Note anything unclear.

## B. The ordinary order (canonical §13)

- [ ] Forge an ordinary piece from start to finish. The materials, stations, check and dice are all clear.
- [ ] Sell or deliver it to a customer at the counter. The money and the piece's history show who bought it.

## C. The collaborative masterpiece

- [ ] Hire at least one specialist at the notice board.
- [ ] Queue a multi-craft Design (e.g. the Emberwarden Longsword) in the Workshop Ledger (Q).
- [ ] Watch the stages pass between workers. Claim one stage yourself.
- [ ] The finished piece shows its maker and every stage worker ("Stages worked by") and its history.

## D. Identity — R1's fixes

- [ ] **Refine and socket a named piece:** name a piece (or use an Epic one), refine it, then set a runestone into it.
      **Its name does not change**, and its history has a line for the rune. A Common piece that becomes Magic says so
      in that line.
- [ ] **Identify a relic:** study an unidentified relic (stores → "Study the relic (at the cleansing basin)"). Open the result's history. **It is
      the same piece**: the "found" line from the expedition is still there, followed by "identified".
- [ ] With a stack of 2+ relics: studying one leaves the rest as an unidentified stack.

## E. Hirelings — R1 field work (decision D-5)

- [ ] **Hire, assign, dismiss:** hire a hireling and give them a piece of gear from your stores.
- [ ] Set their work split. **Smithing shows "(no field work)"** with an explanation on hover.
- [ ] After a working day they bring in ore, coal, herbs, salt or runestone blanks (or trade income); they do **not**
      turn your stored herbs into potions or your blanks into runestones.
- [ ] **Dismiss them:** the journal records that they were let go. The gear they wore leaves with them, and its
      hand-over is written into the piece's own record (checked by the automated tests; the piece itself is no longer
      in the village to inspect).
- [ ] *Judgement:* does the early economy still feel fair without hirelings making potions and runestones? Note how.

## F. Steward Mode (REL-005 / STW-027)

- [ ] Set the standing instructions (spending limit, what may be sold, a protected piece).
- [ ] Hand over (N) and let the steward run **2–3 in-game days** (1.5× pace).
- [ ] While away, open a few panels: you can look. **"Improve it…" in an item panel, a Skill Tree "Learn" button and
      Help's next-step action into an acting panel are greyed out**, with the reason on hover.
- [ ] Take the workshop back. The **While You Were Away** report reads clearly. Its money, orders, production and sales
      match what you see in the ledger and the stores. No invented events.
- [ ] Any sealed letter refers to something that really happened.
- [ ] *Judgement:* the steward is competent but not better than you; the smith earned no experience while away.

## G. Saves

- [ ] **Save, quit, reload:** save to a slot, quit to the desktop, start the game again and load. Everything is as
      you left it, including the queued work orders and hirelings.
- [ ] **Load an older save:** load a save made with the **0.16** playtest build (if you have one). It loads, and you
      can play on. Note anything that looks wrong: items, rooms, staff, money.
- [ ] Optional: a save from **0.15** (S2) or **0.14.6** (the last public release) loads too.

## H. Performance and presentation

- [ ] The village and the workshop run smoothly at your resolution, including in rain or snow.
- [ ] Panels fit the screen; nothing is cut off or hidden.

---

## Result

| Area | Accepted? | Notes |
|---|---|---|
| A. Install and first start | | |
| B. Ordinary order | | |
| C. Collaborative masterpiece | | |
| D. Identity fixes | | |
| E. Hirelings (D-5) | | |
| F. Steward Mode | | |
| G. Saves | | |
| H. Performance | | |

**Overall:** ☐ accepted ☐ accepted with observations ☐ not accepted

**Observations** (each becomes an OBS entry):

1.
2.
3.

*Tester · date · Windows version · in-game days played:*
