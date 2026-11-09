# Steward Mode — architecture (Milestone S1)

*Technical design for canonical v1.1 §4.5 "Steward Mode". Implementation detail may evolve; the canonical rules may not.*

## 1. What it is
The player explicitly hands the running workshop to a **steward** and later takes it back. While Steward Mode is
active and the game process is running, game time keeps flowing (at the chosen speed) and the steward manages the
**routine business** of the forge through the game's existing actions. It never acts while the mode is off, never
acts offline, and never catches up after a save is reopened.

## 2. Principles (from the canonical design)
- **Same actions, same world.** Every steward action calls the existing system function a player action would call
  (buy at a counter, accept an order, queue an apprentice task, sell from the display, pay wages through the normal
  daily loop). No direct state edits, no duplicate mechanics, nothing conjured.
- **Within standing instructions.** Spending limits, allowed activities, protected items and reserved supplies,
  ordinary order and selling rules — persistent, editable by the player.
- **Defer, never decide the consequential.** Unique/Epic/historically significant equipment, dangerous reworking,
  extraordinary commissions, political commitments, inheritance, major relationships and personal decisions are not
  the steward's to take. The world is not frozen for them: visitors leave requests or letters, existing timers run.
- **Competent, not superior.** The steward does not craft (the smith is away and gains no crafting XP); it organises
  employees, stock and commerce. Its choices are deliberately conservative and use only what the workshop can do.
- **Truthful reporting.** Everything shown on return comes from a recorded steward event, a ledger line, a Lore
  event, or a state difference measured at activation and at return.

## 3. Components
| Component | File | Role |
|---|---|---|
| `Steward` (decision layer) | `scripts/systems/steward.gd` | State, activation, the decision cycle, standing instructions, deferrals, the steward log, the session snapshot and the return report. Pure GDScript; no UI. |
| Steward actions | inside `steward.gd` (`_act_*`) | Thin adapters that call existing APIs (`Trade.buy_store`, `Apprentices.add_task`/`assign`, `Shop` order & sale functions, `Contracts.decline` …) and record the outcome. |
| Deferral & correspondence | `steward.gd` (`defer`, `letters`) | Collects matters the steward may not decide, from real events; marks the genuinely significant ones as sealed letters. |
| UI | `scripts/ui/panels/steward_panel.gd`, `welcome_back_panel.gd`, `sealed_letter.gd` (UI worker) | Activate/exit, standing instructions, live status, While You Were Away, sealed correspondence. |
| Tests | `tests/suite/cases/t_steward.gd`, soak runner | Same engine, headless, seeded, accelerated. |

The decision layer is written as **evaluate → choose → act through an adapter → record**, with each routine concern a
small "duty" (orders, staffing, production planning, replenishment, stock & sales, upkeep). The future multi-specialist
workshop plugs in new duties or new adapters (e.g. assigning a staged work order) without changing the cycle.

## 4. State (`Game.state["steward"]`, lazy; saved; old saves gain it on first touch)
```
{ active: bool, since: {t, day, gold, snapshot…}, orders: {standing instructions}, log: [{t, day, kind, text, data}],
  deferred: [{id, t, kind, text, source{lore|order|contract|notice|visitor…}, sealed: bool, opened: bool, resolved: bool}],
  stats: {decisions, by_kind{}, stalled{}}, last_report: {…} }
```
**No offline progression:** activation is a runtime flag; a loaded save always starts with Steward Mode OFF (the
saved flag is cleared on load and recorded as "the steward stood down when the game was closed"). No catch-up code
exists; time advances only through `Game._process` → `advance_minutes`.

## 5. The cycle
`Steward.tick()` runs from `Game.advance_minutes` every 15 game minutes **only while active**, after the world has
simulated that span. Each duty: read live state → decide within the instructions → call an adapter → log. A duty that
cannot act (no money within limits, shop closed, no qualified worker, missing station) records a *stall reason* once
per change, so stalled operations are visible in the report and the soak statistics.

## 6. Testing
The soak runner activates the same `Steward` in a seeded headless game and advances time (accelerated) for N days,
asserting no invented resources (every gold change is a ledger line; items enter only through real acquisitions), no
duplicate uids (A1 `ItemRegistry.scan`), no deadlocks, spending within limits, protected items untouched, deferrals
recorded, a truthful report, save/load mid-session (mode off after load, no catch-up), and 365-day stability.
