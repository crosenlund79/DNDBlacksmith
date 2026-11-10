# S2 worker EARLY — §5 early-game tutorials, controls and progression

## STATUS

All nine brief items DONE, tested and committed on the worktree branch `worktree-agent-a045bee15616692ba` (base `2e854af`;
commits listed at the end). Nothing pushed.

| Brief item | State | Evidence |
|---|---|---|
| Borin begins inside the smithy, then resumes | DONE | `t_s2_early.test_borin_starts_in_smithy_then_resumes`; shots 01, 02 |
| Dagger availability and prerequisites | DONE: investigated, the misleading guide line fixed; **no Design added** (proposal) | `test_dagger_prerequisites` |
| Mira Pell's opening never blocked by her gold | DONE | `test_mira_empty_purse_completes_without_conjured_money`, `test_mira_with_coin_pays_her_share`, `test_lapsed_commission_and_gone_borin_never_freeze_the_guide`; shots 14–17, 20 |
| K vs U, shortcuts discoverable | DONE (+ a real defect found: hotkeys never counted for the tutorial) | `test_keys_match_labels_and_help`; shots 03–08, 18 |
| Y shortcut vs toolbar label | DONE: Y = the toolbar's Workshop; the Workshop Ledger moved to Q (lead may prefer the alternative below) | same test; shots 03, 05 |
| Selling-tutorial timing (BUG-050) | DONE, reproduced first | `test_selling_step_ignores_background_income`, unit check in `test_runner`; shot 13 |
| Optional auto-walk after a check | DONE, **default OFF** | `test_auto_walk_off_by_default_and_only_walks`; shots 08, 10, 11 |
| Shorter post-check delay | DONE: 2.05 s → 1.3 s of game time | rendered measurement; shot 09 |
| First hour on a fresh save, no softlocks | DONE: headless and rendered; four softlocks/defects fixed | `test_every_tutorial_stage_completes_on_fresh_save`; rendered `s2_early` 0 failures |

Last results (commit `00e239d` = final code; later commits only add the report/BEFORE material if any):
- `GODOT=… ./run_tests.sh full`: compile **225 scripts, 0 failed**; suite **300/300** (291 + 9 new); unit **385/385**
  (384 + 1 new BUG-050 check) — ALL GREEN.
- Rendered `playtest.tscn -- s2_early` on the S2 code: **0 failures** (log: `…/scratchpad/s2/shots/early/log_after.txt`).
- BEFORE run of the same phase on the base scripts: see "Before/after" below.
- Related rendered regressions on `00e239d`: `a2_experience` 0 failures, `checks` 0 failures.
- Real saves (`user://saves/`) unchanged (Nov 9 timestamps, as in `s2/realsaves_before.txt`); the shared settings file was
  not written by the tests (auto-walk toggled in memory only).

Known breakages: none. Not done: Windows packaging/acceptance (lead), canonical/register edits (lead-owned).

Classification (CLAUDE.md §2): **ALIGNED** — all items are fixes to approved behaviour named in the user's S2 brief
(canonical §3.2 "the player always knows what to do", §11 clarity/honest information, D14 for Mira). The Y/Q rebinding is
a UX decision inside the brief's item; a dagger Design would be **NEW SCOPE** (content) and was not built.

---

## 1. Borin begins inside the smithy, then resumes his schedule

**Finding.** A new game starts at 07:30; `VillageWorld.spot_for` shows a working hireling only from 08:00 (`work_<top
allocation>`), so Borin was invisible for the first in-game half hour and then appeared at the inn door (he has no
`home`, `_home_spot` → `inn_door_out`) and walked over — while objective 1 says "Speak with Borin in the workshop" and the
play guide says "Talk to Borin in the stock hall".

**Change.** `Hire.tutorial_spot(h)` (hirelings.gd): on day 1, while `talk_borin` is not done and he is `working`, before
18:00, Borin stands at `TUTORIAL_SPOT` = the layout's stock-hall spot `work_relic_hunting` (16.4, 8.0) — a step east of
where a new game puts the smith (15, 7.5); talked to before 08:00 he goes straight to his work spot instead of leaving and
coming back; otherwise (talk done, away, evening, day ≥ 2, old saves) "" = his ordinary schedule. `VillageWorld.spot_for`
asks it first (3 lines). `Hire.hud_status` says "working" (not "resting") while he waits; the activity bubble says
"a word, boss?" (activity_bubbles.gd, 2 lines). New helper `Hire.top_alloc`.
**Tests.** `t_s2_early.test_borin_starts_in_smithy_then_resumes` (07:30 hold, spot inside an owned room, 17:00 hold,
19:00 none, talk → his work spot then none from 08:30, sent away → none, day 2 → none, save/load).
**Rendered.** `01_after_borin_at_start` (07:34, Borin beside the smith, "[E] Talk"), `02_after_borin_dialogue`;
`01_before_borin_at_start` (nobody there).

## 2. Dagger availability and prerequisites (investigation)

**Finding.** No Design makes a dagger: none of the 95 recipes in `data/recipes.json` has `output: "dagger"` (not even a
secret or locked one). The item exists only as: the starting display piece (`Game.new_game`, q74, for sale), the
starting weapon of Rangers, Wizards, Rogues and Bards (`Adv.START_GEAR` — Mira's own weapon is a dagger), loot tables, the
pawnbroker's house stock (`commerce.json` pawn `house_stock`) and the caravan's wanted list. So there are no unlock
prerequisites to report: it cannot be made at any level, and nothing in the skill tree, stations or materials changes
that. The misleading part was the guide: with no dagger in the stores, "how to get" said *"No known way to get Dagger
yet — explore, trade and listen for rumours"*, implying a Design might turn up. The Equipment Designer already hides the
empty "Dagger" type.
Nearest blades on a new game, no skill-tree node needed: **Iron Shortsword** (forge → anvil → grinding wheel; 1 iron ingot
+ 1 cured leather; attack 6–10) and **Iron Longsword** (forge → anvil → quench trough → grinding wheel; 2 ingots + 1
leather; attack 8–12); steel blades stay behind «Steelworking» (A2 rule kept: nothing unlocked early).
**Change.** `Guide.no_design(def)` and its use at the end of `Guide._item_step`: for an equipment piece no Design makes,
"No Design makes Dagger — the workshop cannot forge it. Such pieces come into the smithy by trade, loot or a customer's own
kit; for the same slot, ask the Equipment Designer what you can make." (only when no Design at all makes it, so no secret
is revealed).
**Test.** `test_dagger_prerequisites`. **Proposals** (not built): (a) an "Iron Dagger" Design (forge → anvil → grinding
wheel, 1 iron ingot + 1 cured leather, difficulty 1, no node) — canon §3.1 names "a local dagger" as the model of ordinary
work, but it is new content and touches request feasibility (A2), so it needs the user's approval; (b) `Guide.sources` has
no pawnbroker source, so Quell's occasional dagger is not listed (ECONDEV/lead).

## 3. Mira Pell's opening never blocked by her gold

**Root cause.** The opening objective `serve_mira` completes only through `Objectives.on_sold("mira")`, i.e. a counter sale
(`Shop.sell_to`) or delivering Aldric's commission (`Shop.fulfil`). (1) Before 15:00 on day 1 the commission does not exist
yet, and a counter sale needs her purse: she starts with ~48–78 g (59 g on seed 9001) while a q75 Iron Longsword costs 63 g
→ "can't afford it"; with an emptied purse (Run 0.1: "Mira Pell … 0 gold, budget 0 g") no sale is possible at all — and the
objective line only said "sell or deliver it". (2) Delivery never depended on her purse (A2: her share = what she has, up
to half; the rest is the recorded village subsidy) — but with an empty purse the only ledger line is `subsidy`/`village`, so
the tutorial's "Serve a customer" (which listened for a positive `sales/repairs/commissions` line) never completed.
(3) If the commission lapsed (deadline day 3, she leaves that morning) or could not be placed, `serve_mira` could never
complete: the HUD asked for it for ever (a soft-lock of the guide).
**Change (no conjured money, no free goods, economy untouched).** `Objectives.on_sold` calls `Tutorial.on_served(npc)`:
serving someone in person counts for the selling step whoever paid. `Objectives.text()` is live for `serve_mira`: before
Aldric — "her father Aldric comes by at 15:00 to commission it. Or sell her a piece she can afford."; with the commission —
"Deliver Mira's commission (Commissions [O]) by day 3 — she pays her share from her purse, the village subsidy the rest. Or
sell her a piece she can afford." `Objectives.check()` (wired via `Tutorial.wire` to orders, hours and loading): once
Aldric has asked and no Mira commission is open or delivered, `serve_mira` closes as **missed** (`miss()`, state key
`objectives.missed` created lazily) with an honest toast, and the chain moves on. She still cannot buy what she cannot
afford; the player still chooses to sell, deliver or not serve her (the world keeps its own consequences:
`Shop.expire_orders`).
**Tests.** `test_mira_empty_purse_completes_without_conjured_money` (purse 0: counter sale refused; delivery: objective done
— not missed — and selling step done; no coin in her name; exactly one `subsidy`/`village` line equal to the order's
recorded subsidy; the smith's gold rises by exactly that; `Payments.unaccounted()` empty; purse stays 0; save/load),
`test_mira_with_coin_pays_her_share`, `test_lapsed_commission_and_gone_borin_never_freeze_the_guide`.
**Rendered.** 14 (objective line), 15 (Commissions), 16 (after delivery: "Serve a customer — done"), 17 (ledger: "Village
subsidy: Mira Pell's commission +N g" and Borin's market line), 20 (second new game: commission lapsed, guide moved on).
**Observation for the lead/ECONDEV (not my files):** delivering to a penniless Mira can still trigger the A2 commission
"reward package" (`Shop.fulfil`, a loot roll capped at half the reward) "left by" her — a gift from someone with an empty
purse (D14 smell).

## 4. K vs U and discoverable shortcuts

**Finding.** In-game texts were consistent (K = Skill Tree, U = skill levels), but (a) the player docs said **"K | Skills"**
(PLAYGUIDE.md, DANSK.md "K | Færdigheder"); (b) **a real defect**: hotkeys opened panels by calling
`UIRoot._on_open_panel` directly, bypassing `Events.open_panel`, so pressing K — exactly what the tutorial step "Know your
craft" tells you — never completed it (only a toolbar click did); the same for J ("Meet the adventurers") and the toolbar
glow was not cleared by keys; (c) right-click keys (U, B, G, Y) were only in tooltips, and Help's hotkey list was a hand-written
string missing G, P, +/−, F5/F9, Shift.
**Change.** `UIRoot._unhandled_input` emits `Events.open_panel` for every panel key (UIRoot still routes it).
`Settings.HOTKEY_HELP` + `keys_label/key_name/controls_text` (Esc, +, − named readably) — the single source for Help
("The toolbar and hotkeys", generated), the Settings controls line, and `{action}` placeholders in tutorial steps
(`Tutorial.step_text`) and objective lines (`Objectives._keys`). The toolbar draws each right-click panel's own key as a
small badge at the socket's upper left (`HudToolbar.RIGHT`, tooltip "Right-click (or U): your skill levels"). Docs: PLAYGUIDE,
DANSK, README controls tables corrected.
**Test.** `test_keys_match_labels_and_help`: every toolbar key opens what its button opens, every right-click key opens its
right-click panel, every key bound once, Help lists every action with the real key, no unfilled `{}` in tutorial/objective
text. **Rendered.** 03/04 tooltips and badges, 06 K, 07 Help, 08 Settings, 18 tutorial complete via K/J/Y.

## 5. Y shortcut vs toolbar label

**Finding.** The toolbar button labelled **Workshop** (rooms, stations, furnishings: `PropertyPanel`) had no key; **Y**
opened a different panel, "The Workshop Ledger" (apprentices, `WorkshopPanel`), mentioned only in that button's tooltip.
The tutorial's last step ("open Workshop to buy and furnish rooms") completes on the property panel, so the documented
"workshop" key could not complete it.
**Change.** New action `panel_property` = **Y** → the Workshop button's panel (badge Y on the button); `panel_workshop`
(the ledger) → **Q** ("queue"), shown as the button's right-click badge. All "Workshop Ledger (Y)" strings now use the
live key (guide.gd, contracts.gd toast, reference.gd); docs (PLAYGUIDE, README, GAMEPLAY, TESTING) updated;
`t_workshop_ui` assertion updated to Q. **Alternative for the lead** (if moving the ledger's key is unwanted): keep Y on the
ledger and rename the button "Property" instead — one-line changes in `Settings.DEFAULT_KEYS` and `HudToolbar.BUTTONS`.

## 6. Selling-tutorial timing (BUG-050)

**Reproduced first** (base, headless): with a counter-class panel open (`serving_override`) Borin's hourly
"sold horseshoes and nails" (`Hire._produce`, party `market`) completed "Serve a customer". **Change.**
`Tutorial.party_served(party)`: the ledger payer must be a person (adventurer or character — never market, village,
collector, farm) whom the smith is serving: seated at the counter, or the open conversation's / consultation's partner, or
someone with a commission on the open Commissions board. `_on_gold` requires it. Test hooks `served_override` (and the
existing `serving_override`). Rendered shot 13 (a market sale during a conversation leaves the step in place; BEFORE: done).
Known edge kept: an apprentice's repair for a customer seated at the counter while the smith has the counter open counts.

## 7. Optional auto-walk

`Settings` "gameplay/auto_walk" (**default off**: it closes the station panel and moves the camera without a click — a
change to the familiar flow that players should opt into; the brief's default), a checkbox in Settings and a Help entry.
`Smithy.auto_walk_target/auto_walk_next` + one call in `StationPanel._on_work_done`: when a check finished an operation and
the recipe continues at a **different, installed** station, the panel closes and the smith walks there. It only walks:
nothing opens on arrival, no check starts, no recipe is chosen, never towards the dice, never with the steward in charge.
`Smithy.walk_to_station(sid, w = null, use_on_arrival := true)` and `PlayerNav.walk_to_entity(e, use := true)` were
extended **backward-compatibly** (STEWARD's calls unchanged). Rendered 10/11: forge check → walked to the anvil in 0.6 s,
arrived with nothing open and step 2 waiting.

## 8. Post-check delay

Last round → banner pause 0.55 s → 0.3 s (`CheckOverlay.LAST_ROUND_PAUSE`, used by the ring and every minigame); banner
1.5 s → 1.0 s (`RESULT_SECS`); click/E/Space skips after 0.1 s (was 0.25 s). Between-round pauses unchanged (readable
per-round grades). Measured in game time in the rendered phase (anvil, 2 checks): banner at 0.26 s, flow continues at
**1.34 s** (base design 2.05 s; BEFORE measurement below). Shot 09: the banner (grade, %, pips, "continuing…").

## 9. First hour on a fresh save

Walked every tutorial step and objective headless (`test_every_tutorial_stage_completes_on_fresh_save`) and rendered
(`s2_early`: 07:30 start → Borin → keys/Help/Settings → Borin sent → longsword with auto-walk → dice → BUG-050 → Mira's
commission with an empty purse → K/J/Y → inn → night → Borin's bag → quick-save → all objectives done; then a second
new game where the commission lapses). Softlocks/defects found and fixed: (1) `serve_mira` after a lapsed/unplaced
commission; (2) Borin dead (or gone): `talk_borin`, `send_borin`, `open_bag` now close as missed; his bag gone without
being opened (and he is not away): `open_bag` closes; (3) K/J/Y hotkeys never completed their tutorial steps;
(4) quick-save (F5) did not complete "Save your game" (now does; line names both); (5) a subsidy-only delivery did not
complete the selling step. Checked, no softlock: customers do come on day 1 (seed 9001: Varn 10:00, Eda 12:00, Pip 16:00,
Kestra 17:00, some able to buy); starting materials make three longswords; `watch_depart` completes on any departure
(Borin's own); the inn has adventurers in the evening. Also fixed: a stale `UIRoot.instance` access in
`Tutorial._on_hirelings` between leaving a game and the next HUD (script error seen when starting a second new game).

## Before / after (`…/scratchpad/s2/shots/early/`, `NN_before_*` / `NN_after_*`, logs `log_before.txt`, `log_after.txt`)

Same phase, same steps: BEFORE = base scripts (`2e854af`, checked out temporarily into the worktree, then restored);
AFTER = `00e239d`. Pairs share the number.

| # | Subject | BEFORE (base) | AFTER (S2) |
|---|---|---|---|
| 01 | 07:34, new game | Borin nowhere (not visible) | Borin beside the smith in the stock hall, "[E] Talk" |
| 02 | talking to Borin | — (impossible before 08:00) | dialogue at 07:37; objective 1 done |
| 03/04 | toolbar tooltips | Workshop has no key; right-click keys only in text | Workshop [Y]; small right-click keys U, B, Q, G on the sockets |
| 05 | pressing Y | opens the Workshop **Ledger** (apprentices) | opens Property & Workshop (what the button says) |
| 07 | Help › hotkeys | hand-written list (no G, P, +/−, F5/F9) | complete, generated from the bindings |
| 08 | Settings | old controls line | Auto-walk checkbox (off) + generated controls |
| 09 | check result | banner after 0.53 s, flow on at **2.12 s** game time | banner after 0.26 s, flow on at **1.34 s** |
| 10/11 | after the forge check | station panel stays; walk by button | (auto-walk on) panel closes, smith walks to the anvil, nothing opens |
| 13 | Borin's market sale during a conversation | **"Serve a customer — done"** (BUG-050) | step stays "Serve a customer" |
| 14 | objective at 07:5x / 15:3x | "sell or deliver it (Orders [O])" | live line: Aldric at 15:00 / deliver by day 3, who pays |
| 16 | Mira's commission delivered, purse 0 | objective done; selling step was already (wrongly) ticked by the market sale | "Serve a customer — done" from the delivery itself |
| 17 | ledger | subsidy line | subsidy line (same economy) |
| 18 | after K, J, Y | tutorial still at "Know your craft" (keys never counted) | tutorial complete |
| 19 | after the night, bag, quick-save | objective still "Speak with Borin in the workshop" (he was never there to talk to before being sent) | every objective done |
| 20 | second game, commission lapsed (day 5) | stuck on "Mira needs gear … (Orders [O])"; a script error (stale UIRoot) when starting it | guide moved on to the inn |

Note on 20 (AFTER): Borin still stands in the stock hall at 07:38 on day 5 because the test jumps four days in about a
second of real time — NPCs walk in real frames, so he is still on his way out (the schedule says off duty; his card says
"resting"). In play he leaves as the hours pass.

## Design choices made

Y/Q split (above); Borin's spot = the stock hall beside the smith, hold through his first working day only (evening his
own); auto-walk default off; missed objectives count as done (and are listed in `objectives.missed`) so the chain moves on
and old stuck saves are released on load (one toast); `serving_override` without `served_override` keeps the A2 test
semantics ("serving whoever pays in person").

## Shared / others' files touched (minimal)

`world.gd` (`spot_for`, 3 lines), `player_nav.gd` (`walk_to_entity` param + 2 checks), `smithy.gd` (walk_to_station param,
auto-walk funcs), `station_panel.gd` (`_on_work_done`, 4 lines — CLARITY also edits this file), `activity_bubbles.gd`
(2 lines), `contracts.gd` (toast key), `reference.gd` (hotkeys/auto-walk/workshop entries — the Steward line untouched),
`hirelings.gd` (tutorial_spot, top_alloc, hud_status), `test_runner.gd` (BUG-050 check, payer on the repair line),
`t_workshop_ui.gd` (Q), `playtest_contracts_rl.gd` (toast text), `playtest.gd` (phase registration), docs PLAYGUIDE, DANSK,
README, GAMEPLAY, TESTING (row for `t_s2_early`). Not touched: `project.godot` (the input map lives in `Settings`), saves
schema (one lazily created key `objectives.missed`), canonical docs, registers, CLAUDE.md, creator art.

## Merge notes for the lead

- `world.gd`, `station_panel.gd`: my hunks are in `spot_for` (hireling branch) and `_on_work_done` (after the toast) —
  separate from CLARITY's header/prompt/bag/light changes.
- `Smithy.walk_to_station(sid, w, use_on_arrival := true)` and `PlayerNav.walk_to_entity(e, use := true)`: if STEWARD
  also extended these, keep both parameters (mine defaults to the old behaviour).
- `UIRoot._unhandled_input` now emits `Events.open_panel` for panel keys; ECONDEV's skill-check bypass sits on the
  "skillcheck" route, which keys never open, so no interaction.
- `docs/TESTING.md`: one new row after `t_run01` (others add rows at the same spot).
- `t_workshop_ui` now asserts Q for the Workshop Ledger; STEWARD/contracts/workshop12 phases press the *action*
  `panel_workshop`, which still opens the ledger.

## Proposals (not built)

1. An "Iron Dagger" Design (canon §3.1 "a local dagger"), new content → user approval.
2. A pawnbroker source in `Guide.sources` (Quell's house stock includes daggers).
3. A2 commission reward package from a penniless customer (D14) — review with ECONDEV.
4. If the lead prefers: keep Y on the Workshop Ledger and rename the toolbar button "Property" (instead of moving the
   ledger to Q).

## Commits (worktree branch `worktree-agent-a045bee15616692ba`, not pushed)

- `cdaa983` S2 early WIP: Borin in the smithy, K/U/Y/Q keys, selling step (BUG-050), Mira's empty purse, auto-walk,
  shorter check result
- `00e239d` S2 early WIP: panel hotkeys go through Events.open_panel (K/J/Y count for the tutorial, clear the toolbar
  glow); Borin's waiting bubble; rendered phase measures game time — **final code; full suite green on it**
