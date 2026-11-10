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
| UI | `scripts/ui/steward_ui.gd` (shared helpers, the away gate), `steward_plate.gd` (non-blocking status plate), `panels/steward_panel.gd` (hand-over, standing instructions, matters waiting), `panels/welcome_back_panel.gd` (While You Were Away), `panels/sealed_letter.gd` (sealed correspondence) | Activate/exit (toolbar socket, key N, Workshop Ledger), standing instructions, live status, While You Were Away, sealed letters; look-but-do-not-act while away. |
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

---

*Sections 3.1–8 below were added by the S1 ENGINE implementation (they extend §3–§6; the names above are kept).*

## 3.1 Public API — `Steward` (`scripts/systems/steward.gd`, static)
| Call | Returns / effect |
|---|---|
| `can_activate() -> String` | `""` or why not: no game; already active; the smith has a craft in hand (`Crafting.active()`); he is working a block at the Project Bench (`Contracts.smith_working`). Modal panels are the UI's concern (it calls this from its own panel). |
| `activate() -> String` | `""` or why not. Takes the snapshot (`since`), resets the session accumulators (`acc`), notes every apprentice task that already exists (only what it does from now on counts), turns the runtime flag on, logs `activate`, and records the matters already waiting (contract letters, notices, advice/dispute visitors, fame/spouse orders) as **unsealed** deferrals. |
| `deactivate() -> Dictionary` | The While-You-Were-Away report (`report()` + `ended: "returned"`), also kept as `last_report()`. Mode off. |
| `is_active() -> bool` / `smith_away() -> bool` | Runtime flag AND the saved flag. `smith_away()` is what the world/UI should read to keep the player character from acting; `Apprentices._supervised` reads it (the absent smith supervises nobody). |
| `tick()` | Called by `Game.advance_minutes` every 15 game minutes (`TICK_MINUTES`) only while active; a cheap no-op otherwise. |
| `on_loaded()` | Called by `Game.from_save`. Clears the runtime flag; if the save was made while the steward ran, the session is closed with the state **as saved** (`ended: "closed"`, log `stood_down`, `pending_report = true`). Nothing is simulated or caught up. Does nothing (creates no key) for saves without steward state. |
| `orders() -> Dictionary` | A deep copy of the standing instructions (see §4.1). |
| `default_orders() -> Dictionary` | The defaults. |
| `set_orders(patch: Dictionary) -> String` | Validates and merges a partial patch; `""` or why not (nothing applied on refusal). Unknown keys, negative limits, unknown categories/duties/materials are refused; `session_limit` is lifted to at least `daily_limit`. |
| `protect(uid: int, on := true) -> String` / `reserve(def_id: String, n: int) -> String` | Convenience wrappers over `set_orders`. |
| `protection_reason(it: Dictionary) -> String` | `""` for an ordinary piece, else why the steward will never sell, list, hand over or rework it: explicit protection, Epic, named/title, legendary/unique/set, `Provenance.is_notable`, Hall of Fame plaque, ItemStory famous creation, developer piece. |
| `purchase_categories() -> Array` | `Venues` categories the village counters deal in (for the instructions panel). `Venues.CATEGORY_ORDER` is the full validated list. |
| `duty_on(d: String) -> bool` | Is a duty (`DUTIES`) switched on. `DUTY_NAME[d]` is its player-facing name. |
| `spendable() -> int` | Gold the steward may still spend now (min of daily left, session left, purse − reserve). |
| `min_price(it) -> int` | The selling rules' floor for a piece (value × `min_price_pct`, never below its materials' cost). |
| `defer(kind, text, source, sealed := false, action := {}) -> Dictionary` | Records a matter from a real event (de-duplicated by `source.key`; returns `{}` if already known). |
| `deferred(include_resolved := false) -> Array` | Matters waiting for the smith (entries, see §4.1). |
| `letters() -> Array` | Sealed, unopened letters. |
| `open_letter(id) -> Dictionary` | Marks opened; `{id, kind, from, text, day, time, sealed, resolved, outcome, action {route, args}}` — `action` opens the panel of the actual pending matter (`Events.open_panel.emit(route, args)`; `route` may be `""` when nothing is left to open). `{}` if unknown. |
| `resolve(id) -> String` | The smith has seen to it (`""` or why not). |
| `status() -> Dictionary` | Live status: `{active, since_day, since_time, elapsed_minutes, decisions, last (log entry), stalls [{duty, name, code, text}], deferred, letters, spent_today, spent_session, spendable, gold, reserve}`. |
| `recent_log(n := 20) -> Array` | The last log entries `{t, day, time, kind, text, data}`. |
| `report() -> Dictionary` / `last_report()` / `take_pending_report()` | See §5.3. `take_pending_report()` returns the report of a session closed by loading once, then `{}`. |
| `stats() -> Dictionary` | Lifetime `{decisions, by_kind{}, stalled{code: {n, text, duty}}}`. |
| `note_ledger(amount, cat, note)` | Called by `Game.add_gold` while active: every ledger line of the session is summed (the ledger itself is capped at 400 lines). |

Signal: `Events.steward_changed` (after every cycle, activation, instruction change, letter opened/resolved).

## 4.1 State in detail (`Game.state["steward"]`)
```
active: bool            sessions: int           next_id: int (deferral ids "sd_N")
orders: { daily_limit 120, session_limit 1500, reserve 150,
          buy_categories ["Ore & metal","Coal & fuel","Hides & leather","Thread & fibre","Wood","Herbs","Reagents"],
          duties {orders, repairs, production, replenish, sales, upkeep, contracts: bool (all on)},
          protected [uid], reserved {def: min kept},
          order_rules {max_difficulty 4, min_reward 20, deadline_margin 1 (days), decline_unsuitable true},
          sell_rules {min_price_pct 100, list_new_work true, list_existing false, stock_target 3, sell_goods true} }
since:  {t, day, time, gold, inv {def: n}, equip [uid], staff {id: {name, rank, works}}, orders_open [id],
         taken {def: n} (materials held by tasks), lore_next, crafted, apprentice_crafted, sold_stat}
acc:    session accumulators — ledger {cat: sum}, income, expense, lines, recent [last 80 ledger lines], spent,
        day_spent {day: g}, bought {def: [qty, cost]}, sold [..60], sold_n, sold_gold, made [uid], made_n,
        completed {task kind: n}, produced {def: {n, qty, max}}, failed, failed_why {}, accepted [], delivered [],
        declined [], listed, provisions {def: n}, deferrals {kind: n}, task_seen {}, lore_seen, staff_seen [],
        staff_left [], decisions, by_kind {}, stalled {}
log:    [{t, day, time, kind, text, data}] (cap 400)   kinds: activate, deactivate, stood_down, commit, accept,
        decline, deliver, repair, repair_left, order_left, restock, prep, contract_hours, assign, cancel, buy, list,
        sell, provisions, reserve_ok, stall, defer   (activate/deactivate/stood_down/stall/defer/order_left/
        repair_left/reserve_ok are not counted as decisions)
deferred: [{id, t, day, time, kind, text, source {type, id, key, from, arrived?}, sealed, opened, resolved,
           outcome, resolved_by "world"?, resolved_day?, action {route, args}, from}]  (settled ones pruned past 120)
dkeys:  {source key: id} de-duplication index (also "sealed_piece:<uid>" — one sealed letter per piece, ever)
stats:  {decisions, by_kind, stalled}   stall {duty: "code|text"}   seen {}   mine {task id: purpose}
last_report {}   pending_report bool
```
No item dictionaries are ever stored (only uids, defs as `item_def`, names) — `ItemRegistry.scan` finds no strays.

## 5.1 Duties and their adapters (each: evaluate → choose → act → record, or stall once per change)
| Duty | Acts through | Rules |
|---|---|---|
| **upkeep** | `Sim.take_delivery()` (Aldric's weekly provisions at the door, 9–17, the same action as talking to him) | Watches the reserve: at/below it a `reserve` stall is recorded and every discretionary purchase stops; wages and upkeep stay with the daily loop. |
| **orders** | `Shop.accept_part` / `Shop.decline_part` (counter visitors with several requests), `Apprentices.add_task("commission", {order_id, recipe, priority 3})`, `Shop.fulfil(order, uid)` | Ordinary only: never fame-inspired (`inspired_by`) or the spouse's orders (deferred). Taken on only if an apprentice can make it (`Apprentices.commission_recipe` + `can_make`), the smith knows the recipe, difficulty ≤ `max_difficulty`, stations installed, materials obtainable (stores beyond reserves and committed work, a permitted village counter, or apprentice preparation two levels deep), reward ≥ `min_reward`, and the estimated work + preparation + the queue already waiting fits the shift minutes left before the deadline minus `deadline_margin`. Board orders are planned hourly and re-planned only when the staff changed (or after 4 h for material reasons). Delivers only pieces an apprentice made **for that order** (`for_order`); a remarkable result (protected) is deferred instead. Repair parts and parts beyond the workshop are declined (`decline_unsuitable`). Major contract letters are **never** accepted or declined (deferred). |
| **repairs** | `Apprentices.add_task("repair", {target: npc, priority 3})` | Once per visit. Protected pieces (Epic, named, …) are deferred (one matter per piece per absence). Queued only if the slowest hand ×1.25, behind the urgent queue, can finish before the customer gives up (`Shop.customer_hour`: 3 h, checked 9–18); otherwise left (`repair_left`). |
| **production** | `Apprentices.add_task("craft"/"prep"/"contract")`, `Apprentices.assign` (only when automatic assignment is off), `Apprentices.cancel_task` (only its own unstarted tasks whose reason is gone) | Restock (hourly, 8–17): one ordinary equipment piece at a time while the display holds fewer than `stock_target` pieces — recipes the smith knows, an apprentice can make, stations installed, ordinary materials only, positive margin at the apprentice's expected quality, within `spendable()`. Prep: materials the counters do not sell (e.g. iron ingots) are prepared by an apprentice (`prep`, priority 3, ≤6 runs). Contract hours: 4 apprentice hours (priority 1) on contracts the smith **already accepted**, when an apprentice qualifies. Stalls from its own blocked tasks (`materials`, `station`, `station_busy`, `skill`, `unlearned`, `other`), `no_staff`, `restock`, `no_source`. The steward never hires, dismisses, mentors or answers notices. |
| **replenish** | `Trade.buy_store(store, def, qty)` at `general_store` / `herbalist` | Only for materials the open apprentice tasks still need (+ reserved minimum), only while `Venues.is_open(store)`, only in permitted categories, never more than `spendable()`; stalls `category`, `reserve`, `daily_limit`, `session_limit`, `sold_out`, `limit`, `refused`. Imports, ships, caravan, pawn and rival are never used. |
| **sales** | `Shop.set_for_sale(uid, true)`, `Shop.set_price` (only up to the rules' floor), `Shop.sell_to(npc, uid)`, `Shop.sell_goods(npc, uid)` | Lists (hourly) the pieces apprentices made during the session (`list_new_work`) and, if allowed, the smith's other ordinary stored equipment (`list_existing`, off by default) — never protected pieces or commission pieces. Serves waiting "browse" customers (best displayed piece passing `Adv.purchase_check` at the listed price ≥ `min_price`) and "goods" customers from stacks the smith has put on the shelf, respecting reserves. Never sells to the spouse. |
| **contracts** | (see production) | Switch for the apprentice hours on accepted contracts. |

New shared functions (used by the player path too): `Shop.set_for_sale(uid, on) -> String` and `Shop.set_price(uid, price) -> String` (the stores panel and the shop's stock tab now call them instead of editing the dictionary).

## 5.2 Deferrals and sealed letters (only from real events; visitors every 15 min, everything else hourly)
| Source (real state / Lore) | kind | Sealed? | action route |
|---|---|---|---|
| `Contracts.offers()` (a patron's letter) | `contract` | patron kind `royal` or `leader` (tier 3–4) | `contracts {id}` |
| `Apprentices.st().notices` (independence) | `notice` | yes | `apprentice {id}` |
| an apprentice's unpaid-wage `leave` notice | `staff` | no | `workshop` |
| waiting customer `want: advice` (Consult) | `visitor` | no | `consult {id}` |
| waiting customer `want: dispute` | `dispute` | no | `shop {npc}` |
| the spouse at the counter or ordering | `personal` | no | `shop` / `orders` |
| open order with `inspired_by` (ItemStory fame commission) | `fame_commission` | no | `orders` |
| repair of a protected piece | `repair` | no | `shop {npc}` |
| a commission piece that turned out remarkable | `remarkable` | no | `orders` |
| Lore `epic` / `named` of a workshop piece | `deed` | the first Epic (importance 3) of a piece from the smith's **own** hand | `history {kind: item, id}` |
| Lore `deed` / `awakened` (importance ≥2) of a workshop piece | `deed` | no | `history` |
| Lore `lost` / `destroyed` (importance ≥2) of a workshop piece | `loss` | if the piece was famous (named/Epic/notable) | `history` |
| Lore `death` of a bearer of workshop work, or of the spouse | `death` | spouse, or the bearer of a famous piece | `dossier {id}` |
| Lore `inherited` of a notable workshop piece | `inheritance` | no | `history` |
| Lore `sponsored` (sponsored expedition outcome) | `sponsorship` | no | `dossier {id}` |

At most one sealed letter per piece, ever. Matters already waiting at activation are recorded unsealed. The world is not
frozen: when the underlying matter ends without the smith (offer lapsed, visitor left, notice ran out, order expired) the
entry is resolved with `resolved_by: "world"` and an `outcome` sentence (listed in the report as `lapsed`). In the soaks
sealed letters were rare: none in the 30-day run, two (both independence notices) in 365 days.

## 5.3 The report (`report()`; `deactivate()` adds `ended: "returned"`, a session closed by loading `ended: "closed"`)
```
from {day, time, t}  to {day, time, t}  elapsed_minutes  elapsed_text
gold {start, end, change, income, expenses, by_category {cat: sum}, lines, reconciled (bool), unexplained,
      recent [ledger lines], steward_spent}
orders {accepted [text], delivered [text], declined [text], pending [{id, text, deadline, in_hand, state}],
        counts {accepted, delivered, declined, pending}}
production {completed {kind: n}, made_count, made [{uid, name, where}] (last 40), failed, failed_why {},
            materials {def: {n, qty, max}}, apprentice_crafted, smith_crafted}
purchases {items [{item_def, name, qty, cost}], total}
sales {count, gold, recent [{uid, name, npc, price, day}], listed, ledger_sales}
stock [{item_def, name, before, after, change}]
staff {current [{id, name, rank_before, rank, rank_name, works (in the session), joined, status, notice}],
       left [{id, day, how}]}
world {count, events [{id, day, time, kind, text, importance}] (Lore importance ≥ 2, last 30; the steward's own
       sales/deliveries excluded)}
deferred [{id, kind, text, day, sealed}]  letters [{id, kind, from, day}]  lapsed [{id, text, outcome}]
decisions {total, by_kind {}, stalls [{code, count, text, duty}], deferrals {kind: n}}
```
Every number comes from the steward log, the session's ledger lines, Lore, or the snapshot difference; `gold.reconciled`
is `gold change == Σ ledger lines of the session`.

## 6.1 Tests and soak results (`tests/suite/cases/t_steward.gd`, 11 tests)
SMOKE: activation & runtime flag, instructions validated & saved, save/load mid-session → mode OFF, contract letters
deferred & sealed, protected pieces. Also: commission queued → made by an apprentice → delivered (ledger line, apprentice as
maker); replenishment only at open counters within daily/session limits; the reserve stops spending; independence notice,
advice visitor and an Epic deed deferred (sealed where due) with letters leading to the real matter, visitors lapsing;
30-day and 365-day soaks.

The soak (`_soak(days)`) is a seeded new game (seed 4242): Smithing 6, one extra workshop room, 3000 g, two apprentices
(one trained to the apprentice rank), field hirelings let go (so every item entering the stores is accounted for), three of
the smith's own pieces in the stores (a named blade, a legendary axe, a hand-protected helm). Headless there is no world to
walk customers to their seats, so the soak seats them each hour exactly as `VillageWorld` does (`Shop.mark_arrived`). It
asserts: spending per day and per session within the limits; every purchase kept the reserve; the report reconciles; every
new equipment uid in the stores was made by an apprentice in the session; stackable materials grew by no more than bought +
prepared (+1 per batch) + Aldric's provisions; protected pieces still in the stores and off the display; the smith's skills
and crafted count unchanged; 0 duplicate uids before, after and after save/load; ≥10 decisions in every month with staff.

| | 30 days | 365 days |
|---|---|---|
| Time (headless) | 3.3 s (110 ms/day) | 45.4 s (124 ms/day) |
| Decisions | 109 — repair 32, buy 14, decline 10, deliver 9, list 8, prep 8, restock 8, commit 6, accept 5, provisions 5, sell 3, cancel 1 | 972 — repair 583, decline 90, buy 88, provisions 53, deliver 45, accept 39, prep 29, commit 14, list 10, restock 10, cancel 8, sell 3 |
| Orders | 11 taken on, 9 delivered, 10 parts declined, 2 open | 53 taken on, 45 delivered, 90 parts declined |
| Production | 25 pieces; repairs 32, commissions 9, restock 8, prep 8, upkeep 1; 0 failed | 84 pieces; repairs 582, commissions 45, upkeep 33, prep 29, restock 10; 1 failed (a customer left mid-repair) |
| Purchases / sales | 112 g of materials; steward sold 3 pieces (327 g); display & counter sales in the ledger 663 g | 900 g; 3 steward sales (327 g); ledger sales 943 g |
| Gold | 3000 → 5000, reconciled over 121 ledger lines | 3000 → 16 350, reconciled over 1377 lines |
| Stalls | materials ×9 (iron ingots waiting for smelting), skill ×1 | materials ×31, sold_out ×2, no_staff ×2, skill ×1 |
| Deferrals | visitor 10, deed 11, fame commission 6, repair 6, contract 5; 0 sealed; 26 lapsed without the smith | visitor 67, contract 61, deed 44, repair 44, fame commission 24, notice 2; 2 sealed (independence); 75 lapsed |
| Staff | both kept; the novice ranked up by normal rules | both became masters and left to open their own workshops (days 183 and 290, unanswered independence notices); afterwards the steward keeps house (provisions, deferrals) — it never hires |
| Identity | 0 duplicates, 0 strays | 0 duplicates, 0 strays (777 items) |

## 7. Assessment (S1 ENGINE, 9 November 2026)
**Workshop & production.** `Apprentices` already exposes everything the steward needs as callable functions: `add_task`
(repair/commission/craft/prep/maintain/contract), `assign`, `cancel_task`, `set_priority`, `can_make`, `eligible`,
`commission_recipe`, `estimate`, `expected_quality`, `task_problem`, `bottlenecks`; its 5-minute `tick` runs from
`Game.advance_minutes` regardless of the player. Station upkeep tasks are already added by `Apprentices.on_day` when
automatic assignment is on. Pieces go through `Crafting.build` with the apprentice as maker — no player XP
(`player := maker.is_empty()`). Supervision read `smith_room`, which the world keeps setting from the player's position:
**narrow fix** — `_supervised` now also returns false while `Steward.smith_away()`. `Crafting` itself (the smith's own work)
is never driven by the steward. `Property`/`Smithy` are only read (`is_installed`). `Contracts`: `offers()`, `accept`,
`decline`, `active()`, `task_problem`, `main_recipe` — the steward reads offers (deferral) and adds apprentice hours to
accepted contracts.

**Commerce.** `Shop`: `waiting()`, `sell_to`, `sell_goods`, `accept_part`, `decline_part`, `fulfil`, `open_orders()` are
callable; commissions on the board are already open (placed by adventurers), so "accepting" one means committing the
workshop's work to it. **Player-only gap:** putting a piece on display / setting its price was a direct dictionary edit in
two UI panels — added `Shop.set_for_sale` / `Shop.set_price` and switched `inventory_panel.gd` and `shop_panel.gd` to them.
Counter repairs at the grinding wheel (`Shop.do_repair` by the smith, `repair_part`) are the smith's own work (XP) — the
steward only uses the apprentice repair task (which calls `do_repair(npc, q, by)` without XP). `Trade.buy_store` has no
opening-hours check by design (the counters check `Venues`) — the steward checks `Venues.is_open` itself. Imports, ships,
the caravan, pawn and rival smith are left to the smith. Customers are seated only by the world (`Shop.mark_arrived`).

**Employees.** Wages, loyalty, rank-ups, specialties and independence all run in `Apprentices.on_day`/`_complete` by the
normal rules. Hiring, dismissal, mentoring and answering notices are personal decisions — not steward duties. Field
hirelings (`Hire`) keep their own work allocation; the steward does not send them anywhere.

**World simulation.** `Sim.on_hour/on_day`, `Adv`, `Expeditions`, `Living`, `Consult`, `Sponsor` all run from the clock
regardless of the player; their significant outcomes are recorded once in `Lore` (`Lore.st().next` is a watermark) and the
steward reads them hourly — no new triggers.

**Saves & identity.** `Game.add_gold` caps the ledger at 400 lines, so the steward sums the session's lines itself
(`note_ledger`). `Saves.load_slot → Game.from_save` is the one load path: `Steward.on_loaded()` there turns the mode off.
`ItemRegistry.scan` walks the whole state for item-shaped dicts, so the steward stores only uids/names. Old saves gain the
`steward` key only when the steward is first used (fresh-game load→save idempotence untouched).

**Known gaps / for the lead.** (1) The player's fatigue (`Vitality.on_hour`) keeps rising while he is away — whether the
absent smith rests is a design/UI decision, not changed here. (2) The steward does not hire replacements; a long absence
can end with masters leaving on unanswered independence notices — truthful, but the UI should make the sealed notice
visible. (3) Potions/goods are never produced by the steward (shelf stacks merge and cannot tell the steward's batch from
the smith's), and the display is not restocked while `stock_target` unsold pieces stand there. (4) Repairs of the smith's
own worn pieces in the stores are not queued (his property). (5) Customers' seating needs the world (or the soak's
stand-in). (6) The steward is deliberately slower than an active player: it takes on fewer repairs than an apprentice
could attempt, so that it never starts work a customer will walk away from.

## 8. Shared files touched by S1 ENGINE (small, local)
`autoload/game.gd` (tick hook every 15 min while active; `note_ledger` in `add_gold`; `Steward.on_loaded()` in
`from_save`), `autoload/events.gd` (`signal steward_changed`), `systems/shop.gd` (`set_for_sale`, `set_price`),
`systems/apprentices.gd` (`_supervised` respects `smith_away`), `ui/panels/inventory_panel.gd` and
`ui/panels/shop_panel.gd` (display toggles/price through the new Shop functions).

## 9. Lead integration notes
- **Fatigue holds while away** (`vitality.gd` `on_hour`): the smith gains no waking fatigue (and no rest) while the
  steward runs the forge, so a long session never returns an exhausted smith. Test: `t_steward.fatigue_holds_while_away`.
- **Sealed letters stay sealed** (`contracts.gd` `_announce`): a contract letter arriving while the smith is away is
  announced with its sender only (toast, journal, Chronicle); its subject is revealed when the player opens it. Test:
  `t_steward.letter_contents_stay_sealed_while_away`.

---

*Section 10 was added by the S2 STEWARD worker (10 November 2026). Where it differs from §§1–9 above, S2 supersedes S1
(user's S2 brief, items 2–3): the smith is no longer "away doing nothing" — he works under the steward.*

## 10. S2 — the working smith and the steward's pace
**Engine.** `StewardSmith` (`scripts/systems/steward_smith.gd`) is the steward's duty `smith` ("The smith's own routine
work"). `Game.advance_minutes` calls `StewardSmith.tick(5)` every 5 game minutes while the mode is active (like the
apprentices); `Steward.tick` calls `StewardSmith.plan()` hourly (and when he is idle, at most every 30 min). He acts only
through existing actions: `Crafting.start` (materials leave the stores), one `Crafting.record_step` per operation at the
operation's station (fatigue by `Vitality.on_craft_step`), `Crafting.build` as the smith (provenance: his own hand;
`craft.steward = true`), `Shop.do_repair` / `Shop.repair_part` (the customer pays from their own purse, A2).
Commissions are committed to him by the orders duty when no apprentice can make them in time (`_order_plan` →
`StewardSmith.order_plan`); preparation (smelting) is queued to him when no apprentice can (`_queue_prep` →
`enqueue_prep`); restocking (`_plan_restock`) keeps the display at `stock_target`, counting apprentice restock tasks.
His queued work's materials are part of `Steward._needs()`, so replenishment buys them within the limits.
**Competent, not superior.** Each check resolves automatically at `Contracts.smith_hour_quality(rid, rng)` (the Project
Bench's automatic estimate: skill vs difficulty, freshness, a little seeded chance), never above `QUALITY_CAP = 110`
(below the Hall of Fame craftsmanship 112, masterwork 115, anvil naming 120). Only routine Designs: classic smithing,
unlocked, no secret node, no forgotten/teaching/legendary-grade recipe, difficulty ≤ the order rule and ≤ his level.
Never masterpieces (contract slot), refinement, reforging, sockets, coatings, enchanting, designer experiments,
protected / Unique / Epic pieces (a protected customer piece is deferred: `Steward.defer_protected_repair`).
**His day.** Standing instruction `smith_hours` (default `[8, 18]`, validated 5–12 / 13–21, ≥ 4 h); 12–13 the midday
break by the hearth (`Vitality.rest`); fatigue ≥ 80 → an hour's rest; outside his hours at home; 22–6 asleep in his bed
(`Vitality.sleep`, the bed's rule). The S1 rule "fatigue holds while away" is gone (`Vitality.on_hour`).
**One engine.** Walking is a state (`smith.goal`, `walking`): headless, an estimate from station positions (0.45 min a
tile, +3 min a floor, 4 min to the quarters); with a `VillageWorld`, `StewardSmithActor` (`scripts/world/`) walks the
player's own figure with PlayerNav (`Smithy.walk_to_station(sid, w, false)` — to the station's working side, stairs
and lift included; nothing opens) and reports arrival; game time passes while he walks. At the station: the
apprentices' work motion, the world's sparks/flash after each operation, a bubble with his activity. The player body
ignores keyboard and clicks while away but keeps walking while look-only panels are open.
**Zero experience.** `Game.grant_player_xp` refuses while `Steward.xp_blocked()`: the mode is active, or a marked job
(`Game.state.craft.steward`) is being recorded (`Crafting.record_step` / `build` hold the mark) — so a piece begun under
the steward gives nothing when the smith finishes it after the return or after a load. No teaching flag, no objective;
withheld amounts are counted (`stats.xp_withheld`, report `smith.xp_withheld`).
**Pace.** Standing instruction `pace` (1.0 / 1.5, default 1.5). On activation `Engine.time_scale = pace` and
`Game.speed = 1` (one scale for the clock, walking, animations, tweens and timers); `Game.set_speed` while active is
remembered for the return; `restore_pace()` on exit, on load, on a new game and (safety) from `Game._process`.
Headless tests drive `advance_minutes` and are unaffected (determinism test in `t_s2_steward`).
**Report.** `report().smith`: pieces made (quality, purpose, for whom), repairs (who, quality, paid), prepared,
materials used, minutes at the stations, walking minutes, operations, nights, breaks, rests, the piece still in hand,
anything set down at the return, `xp_unchanged` (skills now vs the activation snapshot) and `xp_withheld`.
**State added (lazy, no schema bump):** `steward.smith` {act, place, goal, walking, job (a repair in hand), op_progress,
op_need, queue [{id, purpose, recipe, order_id?, repeat, done, def?}], …}, `steward.acc.smith`, orders `smith_hours`,
`pace`, snapshot `skills`, `fatigue`, `stats.xp_withheld`; the Crafting job's `steward` mark.
