# Ember & Ash — instructions for Claude Code

This repository is **Ember & Ash** (`crosenlund79/DNDBlacksmith`), a Godot 4.3 game in `game/` (`game/project.godot`,
`config/name="Ember & Ash"`).

## 1. Repository verification (permanent project safety requirement)

Before modifying any files:
1. Verify the local repository, project identity, Git remote, active branch, and relevant project files against the intended game.
2. If the repository is incorrect, ambiguous, or cannot be verified, STOP and request clarification.
3. Never modify files belonging to another project.
4. Repeat this verification at the beginning of every new implementation task, including after context compaction or session changes.

Treat this as a permanent project safety requirement, not a one-time instruction.

## 2. Canonical design governance

**The canonical game design is `docs/EMBER_ASH_CANONICAL_VISION.md`** (Design Baseline 1.3; source:
`docs/Ember_and_Ash_Canonical_Vision_and_Roadmap_v1.3.docx`; the v1.2, v1.1 and v1.0 .docx files are kept as the
dated historical copies). It is
the authoritative baseline for what the game is.

1. **Read it first.** Every implementation session must read `docs/EMBER_ASH_CANONICAL_VISION.md` before planning or
   writing code — again after context compaction or a new session.
2. **Classify every implementation request** against it before starting, and state the classification:
   - **ALIGNED** — compatible with the approved design. ALIGNED means design-compatible, **not** automatically
     authorized for implementation: only development the user has explicitly requested may proceed (still following
     the safety contract below).
   - **NEW SCOPE** — adds gameplay, systems or content the design does not approve (see its "NOT APPROVED" items and
     section 15). Name each addition and ask for explicit approval before building it.
   - **CONFLICT** — contradicts a locked decision (e.g. sections 1.2–1.3, 6.1, the D1–D19 decision register, section
     14.1). Quote the conflicting decision, explain the conflict and **STOP** until the user resolves it.
3. **Technical improvements** (refactors, migrations, tests, performance, tooling) are allowed only within explicitly
   authorized work, and must preserve the approved game design.
4. **Recommend, never silently change.** Claude may propose design changes, but must never introduce them silently in
   code, data or documents.
5. **Revisions need approval.** A change to the canonical design requires the user's explicit approval, a version
   increment and an entry in the document's Change history (what changed, why, impacts, date).
   An approved revision must update **both** the current canonical .docx (a new versioned file, e.g.
   `docs/Ember_and_Ash_Canonical_Vision_and_Roadmap_v1.1.docx`, keeping the previous one as history) **and**
   `docs/EMBER_ASH_CANONICAL_VISION.md`, keeping their version number, content and change history synchronized.
6. **Precedence.** The canonical design takes precedence over older roadmap and design documents when they disagree —
   including `docs/Ember_and_Ash_Master_Design_2026-11-09.docx`, earlier iteration briefs, `game/docs/` status notes
   and Claude's own audits/reports (`docs/EMBER_ASH_ARCHITECTURE_REVIEW_2026-11-09.md`,
   `docs/EMBER_ASH_CURRENT_STATUS.md`) and tracking registers (`docs/EMBER_ASH_DECISION_REGISTER.md`,
   `docs/EMBER_ASH_ROADMAP_REGISTER.md`, `docs/EMBER_ASH_PLAYTEST_OBSERVATIONS.md`). Those reports and registers are
   technical evidence and tracking, not creative authority.
7. **Honest status.** Keep the difference between *implemented*, *design approved*, *being evaluated* and *not approved*
   visible. Never report a feature as done because it was requested or designed.

## 3. Development safety contract (canonical section 16.2)

For every implementation run: verify repository identity, branch, remote and Godot project and STOP on mismatch;
secure a recovery point; preserve persistent item identity, saves and creator-art overrides (`template_` sprites are
fallbacks; never overwrite a creator's own art); make contained, testable changes; run the relevant automated and
rendered regressions; test actual gameplay and Windows packaging where possible; report the verified commit/build and
any incomplete items clearly.

## 4. Practical notes

- Automated tests: `cd game && GODOT=<godot binary> ./run_tests.sh full` (compile check, suite, unit tests); suite
  cases live in `game/tests/suite/cases/`, rendered playtests in `game/tests/playtest.gd`. See `game/docs/TESTING.md`.
- The Windows installer is built and smoke-tested by `.github/workflows/windows-installer.yml` when
  `game/RELEASE_VERSION` (or the installer/export files) change.
- Do not commit, push or publish unless the user asks for it.
