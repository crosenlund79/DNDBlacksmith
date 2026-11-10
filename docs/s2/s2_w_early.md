# S2 worker EARLY — early-game tutorials, controls and progression

Read `s2_common.md` first, then canonical §3.2, §11; `scripts/systems/tutorial.gd` (A2 changed the selling step: it
completes when payment happens at the counter, `serving_at_counter()`), `tutorial_card.gd`, `guide.gd`, `hirelings.gd`
(Borin), the toolbar / `ui_root.gd` shortcuts, `project.godot` input map, `scripts/ui/minigames/*` and the check overlay /
result auto-close, `smithy.gd` (`walk_to_station`, `craft_again`). Decision register BUG-050 (selling-step residual).

## The user's S2 brief (verbatim, your section)
**5. Early-game tutorials, controls and progression**
* Borin begins inside the smithy ready for his tutorial, then resumes normal behavior.
* Investigate dagger availability and current unlock prerequisites.
* Ensure Mira Pell's opening tutorial cannot become blocked by her insufficient gold; preserve economy and player choice.
* Correct misleading Skills navigation (`K` versus `U`) and make actual shortcuts discoverable.
* Correct the `Y` shortcut and toolbar-label mismatch.
* Fix any remaining selling-tutorial timing problems.
* Provide optional automatic walking to the next required crafting station after a skill check; never automatically choose
  consequential actions.
* Reduce unnecessary post-skill-check delay while retaining readable feedback.
* Verify all first-hour tutorial stages on a fresh save and avoid progression softlocks.

## Notes and lead decisions
- Borin: today he may start elsewhere (he goes out on errands/trade runs). He should begin inside the smithy where his
  tutorial step expects him, then follow his normal schedule once that step is done (or skipped). Old saves unaffected.
- Dagger: investigate why/when the dagger can or cannot be made at the start (recipe, skill-tree node, station, materials);
  fix a real defect or misleading text; do not unlock advanced crafts early (A2 rule). Report the prerequisites.
- Mira Pell: since A2 adventurers pay from their own purses; the Run 0.1 playtest showed "Mira Pell … 0 gold, wants boots,
  budget 0 g". Find where the opening tutorial depends on Mira paying and make sure it cannot softlock (e.g. the tutorial
  accepts the step when the order is delivered even if she cannot buy more, or the opening commission's payment is the
  explicit recorded village subsidy/advance that A2 introduced) — no conjured money (canon D14), no free goods; the player
  keeps the choice. Explain the root cause.
- `K` vs `U`: make the real bindings consistent between toolbar tooltips/labels, help text, tutorial text and the input map;
  make shortcuts discoverable (tooltips with the key; Help lists them). `Y`: the toolbar label and the actual action must match.
- Selling tutorial (BUG-050): the gate can still be completed by background income (Borin's hourly sale) while a
  counter-class panel is open; use the A2 ledger `party` field (a customer at the counter) to tell them apart.
- Auto-walk: an optional setting (Settings + Help; default OFF unless you find a strong reason — report it) that, after a
  skill check finishes an operation whose recipe continues at another station, walks the smith there via
  `Smithy.walk_to_station`; it only walks (opens nothing, starts nothing, never picks a recipe). STEWARD uses the same helper:
  extend it backward-compatibly if needed.
- Post-check delay: shorten waits/auto-close timers that add nothing while results stay readable (players can click to skip).
- First hour: walk every tutorial stage on a fresh save (rendered) and in a headless test; find and remove softlocks (e.g.
  missing materials, a customer who never comes, a node that cannot be learned).

## Deliverables
- Code; `tests/suite/cases/t_s2_early.gd` (Borin starts in the smithy then resumes; dagger prerequisites as reported;
  Mira's tutorial completes even with an empty purse without conjured money; K/U/Y bindings match labels and help; the
  selling step ignores background income; auto-walk off by default and only walks when on; every tutorial stage completes on
  a fresh save headless).
- Rendered phase `s2_early` (`tests/playtest_s2_early.gd`): the first hour on a fresh save with screenshots of each tutorial
  stage, the toolbar/Help showing the right keys, the auto-walk in action, the shortened check result; BEFORE/AFTER where
  meaningful (`…/scratchpad/s2/shots/early/`).
- Report per `s2_common.md`.
