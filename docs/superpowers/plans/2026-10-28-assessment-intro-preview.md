# Assessment introduction preview implementation plan

**Goal:** Preview a single layered onboarding screen and six scrollable questionnaire sections without reading or writing a user store.
**Architecture:** DEBUG-only launch argument `--assessment-intro-preview` bypasses the normal app root and lazy persistent container. A local value-state preview owns navigation and answers, reusing the existing question cards and questionnaire validation. The normal assessment entry stays unchanged.
**Tech stack:** SwiftUI, Swift Testing, iOS 17+. Adapt OnboardMate's layered composition and 0.5 second ease-out entrance; preserve its MIT notice. No package dependency.
**Spec:** User-approved “分层动画式自测引导预览” in this chat (2026-10-28).

## Constraints and review focus
- One introductory screen, exact approved title and three explanatory points, unscored six-dimension diagram, accessible start button always actionable.
- Six questionnaire pages of ten statements each; no default answers, back preserves draft, rapid start must not advance twice. Preview completion never submits.
- Local preview only; no changes to normal eligibility, scoring, protected primary files, other worktrees or formal images. No push, merge or worktree removal.
- Dynamic Type content scrolls, primary action remains reachable; Reduce Motion shows all layers immediately, VoiceOver reads title, explanation, action. No repeating animation.
- Focused tests and a targeted simulator preview only; comprehensive QA remains deferred, known CompanionPointCloudRepositoryTests isolation issue excluded.

## Task 1: Safe standalone preview and visual implementation
- [x] Add focused tests for idempotent start, incomplete-section guard, all-excluded guard, back/intro draft retention, six-section completion and fresh preview reset; observe missing implementation failure.
- [x] Implement DEBUG-only `AssessmentIntroPreviewState` and `AssessmentIntroductionPreview`, using the existing questionnaire cards. Share the question card by changing only its visibility.
- [x] Implement `AssessmentIntroductionView(onStart:)` with six labeled nodes and neutral unscored connections, layered one-shot entry, scrollable adaptive copy and pinned action. Existing app uses neutral node colors; retain those plus the existing teal action accent.
- [x] Add DEBUG launch bypass before lazy initialization of the persistent container. Add Xcode previews for normal, accessibility text and Reduce Motion; inspect small-screen rendering on a dedicated SE simulator.
- [x] Preserve the upstream license and attribution. Run focused questionnaire and preview tests.
- [x] Review the isolated diff and simulator screenshots, leave the introduction open for user review, and record verification limits below. User approved the visual revisions and explicitly requested local merge into main.

## Execution record
- Existing isolated branch `codex/life-state-assessment`, base `cdebde6`, clean before changes. Reusing it as continuation; all other worktrees remain untouched.
- The user supplied an approved implementation plan and expressly requested execution; no additional plan-approval round is required.
- First RED: missing AssessmentIntroPreviewState, expected compilation failure. GREEN: 8 focused tests passed.
- User visual revisions: three introduction descriptions reserve at least two lines using a scaled minimum height; allow longer content to expand. Answer circles are symmetric, center smallest but visibly sized (34,31,28,25,28,31,34pt). Equal visual edge gaps replace equal center spacing. 44pt tap targets remain nonoverlapping; narrow rows fall back to labeled choices.
- Geometry RED: missing AssessmentChoiceGeometry. Final GREEN: 10 tests passed, zero skipped, via XcodeBuildMCP test_sim with only AssessmentChoiceLayoutTests, AssessmentIntroPreviewTests and AssessmentQuestionnaireTests. Existing CompanionPointCloudRepositoryTests excluded. Result: ~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-2ff2b8f231d7/result-bundles/test_sim_2026-10-28T04-00-15-544Z_pid14685_550fb625.xcresult.
- Independent read-only reviewer found dark-mode contrast and missing VoiceOver section focus; fixed by a light appearance scoped to the standalone preview and accessibility focus on each question heading. Also corrected resume hint to section-neutral wording.
- Simulator screenshots verified intro, entry to health and revised circles. Small SE preview renders with a pinned reachable start action; maximum text size renders, but exhaustive scrolling/audio VoiceOver/Reduce Motion walkthrough remains manual acceptance, not claimed complete. Comprehensive Debug remains deferred as requested.
- SHA-256 of the iPhone 17 Pro user's default.store, WAL and SHM unchanged after preview interactions. Normal launch stays separate from the preview argument.
- Known unrelated Swift actor-conformance warnings persist for LifeStateValues, RadarChartStyle and CompanionProgressionEvent; none are fixed in this visual scope. No remote push, merge, worktree removal or official-image changes.
- 2026-10-28 pre-merge verification: 122 selected tests passed across the sixteen relevant suites (assessment, migration, XP, presentation and feedback), no failures. Existing CompanionPointCloudRepositoryTests excluded; the previously baseline-reproduced accessibilityDetailProvidesAScrollContainerForLongSources test omitted explicitly. Full-suite testing remains deferred by user instruction. Result: ~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-2ff2b8f231d7/result-bundles/test_sim_2026-10-28T06-49-50-265Z_pid14685_2b48d6dd.xcresult.
- Merge authorization is local only. Preserve all worktrees/branches and primary-checkout local changes; the introduction remains a DEBUG preview, with no automatic integration into normal assessment entry.
