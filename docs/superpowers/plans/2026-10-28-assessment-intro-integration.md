# Formal assessment introduction integration

User clarification: the approved introduction belongs before the real questionnaire. Completing all six sections must persist and update the six-dimensional state, then return home. Returning to introduction is not a successful assessment outcome.

Continue in isolated branch codex/assessment-intro-integration from main 7e2a270. Preserve the primary checkout's protected local changes, other worktrees, XP/currency/collection/tarot behavior and all existing assessment scoring/date rules. No push or deletion. Full Debug remains deferred.

- [x] RED: StateAssessmentSessionTests fails on missing StateAssessmentSession.
- [x] Add a production session that owns introduction, six questionnaire sections and successful completion. Only the last completed section invokes the existing atomic StateAssessmentStore.submit. Failed save retains answers; repeated finish does not save again.
- [x] Make the approved introduction available outside DEBUG and mount it inside the real StateAssessmentView. Final button is 更新六维状态. On successful initial submission, the existing root @Query switches to Today; periodic submission dismisses its sheet. Carry the section VoiceOver focus behavior into the real view.
- [x] Verify the production session's persistence, rejected-save retry state and repeated submission; use the real session in the existing hosted @Query test to prove live six-dimensional state refresh.
- [x] Focused tests and targeted normal-launch simulator check. Review the change and keep it isolated for user acceptance; no fake scores or forced eligibility in user data.

## Verification and review
- Three production session tests verify no writes during introduction/incomplete sections, exactly one snapshot after six sections, and failed submission retaining the final section and draft.
- Hosted ContentView with an empty store transitions to Today after the first actual submission, without restart. Hosted MainTabView starting on Profile returns to Today after successful submission. The profile route was observed RED before adding the latest-snapshot observer, then GREEN.
- Actual SQLite read-only save fails without altering stored profiles. Session answers and weekly targets survive; retry against a writable container succeeds and repeated final submission creates no duplicate.
- Final focused run: 127 passed, no failures across seventeen suites. Result: ~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-2ff2b8f231d7/result-bundles/test_sim_2026-10-28T07-41-40-563Z_pid14685_36fb9715.xcresult. The previously recorded unrelated AX scroll test and CompanionPointCloudRepositoryTests remain explicitly excluded; this is not full unified Debug acceptance.
- Independent read-only reviewer found no confirmed correctness defect. Both requested coverage additions (empty-store root routing and physical write failure followed by retry) are now covered by passing tests.
- Normal launch without --assessment-intro-preview succeeded on iPhone 17 Pro. UI showed the real introduction/questionnaire, then Today with the latest six state values after assessment; cooldown shows fifteen days. No synthetic answers were injected into user storage by code or launch flags.
- The old DEBUG-only standalone preview remains available solely for design checks; normal app launch uses the persistent flow. No main merge or remote push is included in this follow-up fix yet.

## Completion animation follow-up
- User requested a smooth transition into home after finishing. Initial assessment now crossfades out while Today gently enters from 14pt below over 0.5s. Reduce Motion uses opacity only over 0.2s. Reset-to-assessment stays immediate.
- Successful submission keeps the final questionnaire in place during removal, with a disabled 状态已更新 checkmark action; no intermediate loading page. Failed saves preserve the questionnaire and never navigate. Pending section-focus work does not refocus a completed form.
- Periodic successful-assessment tab routing scopes the same easing to the Today handoff; native sheet/navigation dismissal remains intact.
- 27 focused state-session, live-UI, reset and reward-feedback regression tests passed after the final focus guard. Result: ~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-2ff2b8f231d7/result-bundles/test_sim_2026-10-28T08-06-00-725Z_pid14685_cb613ee2.xcresult. Independent static review found no actionable regression. Normal simulator launch also succeeded with the existing assessment intact. No assessment was forced or resubmitted to replay the animation on user data; visual timing of a full on-device completion remains user acceptance.
