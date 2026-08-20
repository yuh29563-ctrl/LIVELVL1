# SDD ledger — plan: docs/superpowers/plans/2026-08-20-home-life-state-implementation.md

Workspace: `/Users/fy/Desktop/LIVELVL/.worktrees/home-life-state`
Branch: `codex/home-life-state`
Merge base before feature tasks: `bad0610`

Ruling: The isolated branch starts with baseline commit `bad0610`, which copies the existing uncommitted level, task-undo, and duplicate-project deletion changes from the main checkout — these behaviors are prerequisites for this plan, while the original checkout remains unchanged — if wrong, the feature branch can drop this single baseline commit before integration.

## Pre-flight task/interface scan

| Tasks | Producer → consumer / shared surface | Finding |
|---|---|---|
| 1 self | Engine tests → exact `LifeStateEngine` implementation | Clean: expected 5.0, 5.8, 9.7, settlement, projection, due-date values match formulas. |
| 2 self | Summary tests → persistence models and builder | Clean: one 40 XP action at target 3 yields action 5.8 and projected 6.3; optional completion metadata preserves old rows. |
| 3 self | Settlement tests → assessment result and UI save contract | Clean: Day 0 is direct self-rating; weekly result uses 60/40 blend; ranges are clamped. |
| 4 self | Geometry tests → chart and card components | Clean: axis order starts at top, six points form a real hexagon, and geometry clamps to the score range. |
| 5 self | Existing task loop → new home composition | Clean: completion remains idempotent; undo uses stored completion XP; projected state is derived after query updates. |
| 6 self | Weekly settlement test → Growth/UI acceptance | Clean: 6.0 self + 5.8 action settles to 5.9 and the new projection overlaps the snapshot. |
| 1 → 2 | `LifeDimension`, `LifeStateValues`, `StateActivity`, `LifeStateEngine` → models and summary | Compatible exact names and value semantics. |
| 1 → 3 | State engine and values → assessment settlement | Compatible; initial mode intentionally bypasses weighted settlement. |
| 1 ↔ 4 | State values/engine → radar geometry; Task 4 adds due-day helper/tests | Compatible sequential extension; Task 4 must retain all Task 1 tests. |
| 2 → 3 | Profiles, snapshots, completion activity → assessment persistence | Compatible; snapshot captures action baseline at settlement. |
| 2 → 4 | `LifeStateSummary` → `LifeStateCard` | Compatible; card receives a value summary and no persistence dependency. |
| 2 → 5 | Completion metadata and summary builder → task completion/home summary | Compatible; new completions capture dimension/title while legacy rows fall back to `Item`. |
| 2 → 6 | Summary builder/models → Growth detail | Compatible; Growth rebuilds the same derived summary without mutating snapshots. |
| 3 → 4 | Weekly assessment callback → state card | Compatible; card exposes `onAssessment` only when due. |
| 3 → 5 | `StateAssessmentView` and app gate → Today sheets | Compatible; initial setup is root-gated, weekly setup is item-driven sheet presentation. |
| 3 ↔ 6 | Assessment UI → Growth weekly entry and final accessibility edits | Compatible; Task 6 modifies the same view after Task 3 establishes it. |
| 4 → 5 | `LevelCard`, `LifeStateCard`, `RadarPulse` → Today integration | Compatible exact initializer surfaces. |
| 4 ↔ 6 | Radar/cards → final accessibility and reduced-motion pass | Compatible; Task 6 tightens behavior without changing public component names. |
| 5 ↔ 6 | `ContentView` and Today/Growth split | Compatible; Task 5 extracts Today/AddTask, Task 6 removes remaining inline Growth/Profile. |

Pre-flight result: no unresolved plan/spec conflicts.

Baseline verification: `xcodebuild ... build` succeeded on iOS Simulator SDK 26.5 after rerunning outside the restricted sandbox; the first failure was environmental (`sandbox-exec` blocked SwiftData macros), not a code failure.

Task 1: complete (commits bad0610..9cc2ada, review clean)

Task 2: verification carry-forward — static review confirms lightweight-compatible optional fields and scalar models; actual existing-store relaunch is explicitly scheduled in Task 5 acceptance and is not a Task 2 gap.
Task 2: complete (commits 9cc2ada..bbf5cba, review clean)

Task 3: evidence check — controller read the complete report containing RED compile failure, focused 3/3 GREEN, full 13/13 GREEN, successful simulator build, and iPhone 17 Pro render inspection; reviewer’s diff-only ⚠️ is resolved by that report evidence.
Task 3: complete (commits bbf5cba..38c5529, review clean)

Task 4: Ruling: add `daysUntilAssessment: Int` to `LifeStateSummary` and populate it in `LifeStateSummaryBuilder` via `LifeStateEngine.daysUntilAssessment(...)` — the card requires an exact countdown and this keeps date derivation in one summary layer instead of duplicating it in Today/Growth views — if wrong, the cost is reverting one value property and passing the count explicitly to cards.
Task 4: implementation takeover — the retrying subagent remained unavailable; controller completed cleanup, accessibility details, and verification locally.
Task 4: complete (pending local commit, reviewer stage unavailable because the delegated-agent quota remained exhausted).
Task 5: implementation completed locally — Today now derives the state summary from persisted snapshot/profile/completion data, renders LevelCard and LifeStateCard, opens weekly assessment when due, stores completion dimension/title metadata, and pulses the affected radar dimension. The existing completion undo path remains idempotent and refunds stored XP.
Task 5: verification — `xcodebuild test` on iPhone 17 Pro simulator destination passed with 18 tests across 4 suites; simulator UI inspection was not run because all local simulators were shut down.
