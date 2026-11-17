# Next Build Brief — R1 "Integration & Foundation Closure"

*Implementation-ready brief for the highest-priority next build of the [Final Development Roadmap](FINAL_DEVELOPMENT_ROADMAP.md).*
Prepared 17 November 2026 from the [Final Completion Audit](FINAL_COMPLETION_AUDIT.md). **Not authorised until the user
approves it**, together with decisions D-1 … D-5 below.

**Classification against canonical v1.7: ALIGNED.**

- This build is integration, identity hygiene, save safety, CI and documentation (Gate A, canonical §12.2/§12.3, §6.1,
  §16.2).
- It adds no gameplay scope.
- The one behaviour removal is hireling off-station production. It brings code into line with canonical §1.2 and §4.3
  ("a physical workshop matters"), and it is still subject to decision D-5.

---

## Why this build is next

1. **Nothing since 0.14 is in players' hands.**
   - 126 commits (+30,044 lines) are on feature branches.
   - The default branch is at Run 0.1, and fast-forwarding it is conflict-free.
   - Every later build multiplies the integration and save-migration risk if this waits.
2. **The identity principle (§6.1, "IMMUTABLE") is violated by live code.**
   - Socketing renames items and changes their rarity (BUG-042).
   - Identifying a relic replaces the object (EQ-007).
   - Some exits leave no record (BUG-017, EQ-004).
   - These must be fixed before R4–R6 build on identity.
3. **Saves from the playtest builds are unprotected.**
   - No golden save exists for schemas 4–8, so a migration bug in a later build would go unnoticed.
4. **It is small and contained.** It gives the user a real 0.17 build to play while R2/R3 proceed.

---

## Preflight (STOP on any mismatch)

- **Repository:** `crosenlund79/DNDBlacksmith`, remote `origin`.
- **Project:** `game/project.godot` named "Ember & Ash", Godot 4.3.
- **Tree and design:** a clean tree; CLAUDE.md read; canonical **v1.7** read.
- **Baseline:** start from **`65e70b5`** (`claude/living-village-workshop`). Confirm that
  `git merge-base --is-ancestor origin/claude/kind-dijkstra-nqkxn1 65e70b5` still holds. If the default branch has moved,
  STOP and report.
- **Recovery point:** push `backup/pre-r1-<date>` at `65e70b5`. Work on `claude/r1-integration`.
- **Real saves:** never touch `user://saves/`. Tests use isolated data folders.

---

## Decisions required before starting

| # | Decision | Recommended answer |
|---|---|---|
| **D-1** | Fast-forward the default branch `claude/kind-dijkstra-nqkxn1` to the verified R1 head **and publish** it, since pushing a changed `game/RELEASE_VERSION` to the default branch runs the release job. | Yes, as **0.17.0**, after every acceptance gate below is green. If the user prefers no public release yet, push the fast-forward with `[skip ci]` and keep the artifact unpublished. |
| **D-2** | Identifying a relic (EQ-007). | The identified piece **keeps the relic's uid** and its Lore and provenance chain. Its def, name and stats change, and an `identified` event records what it was and who studied it. A stacked relic splits one off first. A roll that produces a Unique goes through `Uniques.can_mint/register` as today. |
| **D-3** | Rune socketing and rarity (BUG-042). | **Never rename.** A Common piece may become Magic only with a recorded `enchanted` provenance event. The display name stays the item's own, or the earned name. |
| **D-4** | Which Gate A items close now (QST-027). | This brief's scope. The truthfulness and entry-point items follow in R2. |
| **D-5** | Hireling off-station production (STAFF-004, HA-025). | **Retire it.** Hirelings stay field and expedition staff; workshop goods come only from station work. Existing saves keep everything already produced. |

---

## Scope (exactly this; nothing else)

### 1. Identity hygiene (§6.1)

| Item | Change | Code anchor |
|---|---|---|
| EQ-007 | Identification keeps the uid and chain per D-2 | `systems/regions.gd:123` `identify()` |
| BUG-042 | Socketing never renames; rarity changes only as a recorded event per D-3 | `systems/crafting.gd:876-886` |
| BUG-017 | A dismissed hireling who leaves with gear records a hand-over (`ItemRegistry.leave` / `Provenance` transfer) | `systems/hirelings.gd:293` `dismiss()` |
| EQ-004 | Remaining exits record a transfer or loss: unsold merchant stock on restock (only for pieces with workshop or significant provenance, otherwise no record needed — state the rule in code); trade-run sale for non-equipment is a no-op today — record it or document why not | `trade.gd` restock, trade-run sale |
| EQ-012 | A lost, buried or destroyed piece leaves a **structured tombstone** (uid, def, name, maker, mark, owners, Epic, last holder, cause, day) in a permanent archive, so its history stays queryable after the physical object is gone | `item_registry.gd` archive, `provenance.gd` `lose`/`destroy` |

**Save step 9** adds the tombstone archive and converts existing `found_note`-only identified relics where the old uid
is recoverable. It is idempotent; old saves load unchanged otherwise.

### 2. Workshop rule

- STAFF-004 and HA-025 per D-5: remove `Hirelings._produce` from `work_hour`. Their allocation becomes field work only.
- Update the hireling panel texts. The v1.7 assignments-first panel already leads with assignments.
- Re-check that the early-game economy stays solvent: run `lw_soak` on both set-ups, plus the S2 poor-start soak.

### 3. Steward look-only panels

- STW-026 and BUG-003: while away, the dossier gift and compare buttons and Help "show me how" are disabled, with a
  tooltip "The steward runs the forge — take it back to act".

### 4. Save safety

- **Golden saves, produced the authentic way.** Use `tests/fixtures/saves/README.md`: `git archive`, the verbatim
  driver, an isolated `XDG_DATA_HOME`, seed 20261109. Produce one from each of:
  - `b362877` (0.15, schema 4);
  - `587399c` (0.16.19, schema 7);
  - `65e70b5` (0.16.21, schema 8);
  - the R1 head (0.17, schema 9).
- Add their rows and SHA-256 to the README.
- `t_saves` covers each one: load → migrate → save → load is identical; `Uniques.audit()` is empty; the identity probe is
  clean.

### 5. CI (TECH-014, part)

- Add `.github/workflows/tests.yml`. It runs `run_tests.sh full` headless on every push to `claude/**`, **never
  publishes**, and uploads the log.
- Rendered phases stay local, because CI has no GPU. Document this.
- Do not change `windows-installer.yml`'s publish rule.

### 6. Documents (BUG-049, TECH-023) — these documents only

- `game/docs/GAMEPLAY.md`, `PLAYGUIDE.md`, `TESTING.md` and `TECHNICAL.md` describe the 0.17 build: Steward Mode, the
  Living Workshop, v1.6 and v1.7.
- `LIVING_REALM_STATUS.md` gets a superseded banner pointing to canonical §12. Remove "allegiance".
- The three registers record S2, the Living Workshop, the pilots, v1.6, v1.7 and R1 as integrated, and give their current
  delivery states. The audit's §8 discrepancies are corrected.
- Add `docs/final_completion/R1_ACCEPTANCE_CHECKLIST.md` (below).

### 7. Integration and release (after every gate is green, per D-1)

- Bump `game/RELEASE_VERSION` to 0.17.
- Fast-forward the default branch to the R1 head.
- Let the workflow build, smoke-test and publish 0.17.0, or push with `[skip ci]` if D-1 says so.
- **Never merge, rebase or force-push any other branch. Delete nothing.**

**Out of scope:** everything in R2–R11, including danger and reputation entry points, truthful plans and rumours,
valuation and the Chronicle. Also out of scope: any `PROPOSED` entry, balance changes beyond keeping soaks solvent after
D-5, art, and new content.

---

## Acceptance gates (all required)

1. **Automated**
   - `run_tests.sh full`: compile 0 failed; suite and unit 100% green.
   - New tests:
     - `t_r1_identity.test_identify_keeps_uid_and_chain`
     - `test_socket_never_renames`
     - `test_socket_rarity_change_recorded`
     - `test_dismissed_hireling_gear_handed_over`
     - `test_restock_exit_rule`
     - `test_tombstone_survives_save_load`
     - `t_r1_workshop.test_hirelings_produce_nothing_off_station`
     - `t_steward_ui.test_look_only_buttons_disabled_away`
     - `t_saves` rows for the four new goldens
2. **Rendered:** all **72** phases of `tests/playtest.gd` pass on the R1 head. List any that need updated expectations,
   with a one-line reason each.
3. **Soak:**
   - `tests/lw_soak.tscn` 365 days, both set-ups, every invariant held (money, goods, identity, Uniques).
   - The S2 poor-start soak stays solvent after D-5.
4. **Year-long identity probe** (`t_identity`) clean, with `Uniques.audit()` empty, on a fresh game and on every golden
   save.
5. **Windows:** the installer workflow builds, installs and launches (smoke) the R1 head. If D-1 allows, it publishes
   0.17.0. Record the run link and artifact link.
6. **Human playtest:**
   - The user plays 0.17 on Windows for at least one in-game month, plus a Steward Mode session.
   - They follow `R1_ACCEPTANCE_CHECKLIST.md`, which covers: the new game and tutorial; ordinary order; collaborative
     masterpiece; refine and socket a named piece (name unchanged); identify a relic (same item in its history); hire,
     assign and dismiss a hireling with gear; steward away 2–3 in-game days and the While You Were Away report; save,
     quit and reload; load a 0.16 save.
   - The result is recorded as REL-004 / REL-005 evidence in the registers. Observations become new OBS entries, not
     silent fixes.

## Report

- **Commits:** the verified commit and branch, the default-branch head after the fast-forward, and the release tag and
  link (or the "not published" state).
- **Evidence:** test counts, rendered phase count, soak figures, and goldens with SHA-256.
- **Status:** the register IDs closed, and anything left open, honestly labelled.
- **Next:** proposed adjustments to R2 from what the playtest shows.
