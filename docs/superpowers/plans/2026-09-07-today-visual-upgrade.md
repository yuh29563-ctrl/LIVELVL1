# Today Visual Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Today screen hierarchy while preserving every existing product element and interaction.

**Architecture:** Extend the existing Today presentation values for deterministic header and task copy, then compose the existing SwiftUI views in a tighter layout. Keep all persistence and reward state in `TodayView`; visual subviews continue to receive value presentations and closures.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-07-today-visual-upgrade-design.md`

## Global Constraints

- Work only in `/Users/fy/Desktop/LIVELVL/.worktrees/today-visual-upgrade` on `codex/today-visual-upgrade`.
- Preserve all existing Today data, navigation, reward, companion, life-field, journal, accessibility, and Reduce Motion behavior.
- Do not modify the protected main-workspace Xcode state, `.tmp`, or handoff documents.
- Do not add dependencies, change persistence schemas, push, merge, or clean other worktrees.
- Use focused tests before and after each behavioral change, then run the complete test suite and Debug build.

---

### Task 1: Header and Task Presentation Contracts

**Files:**
- Modify: `LIVELVL/LIVELVL/Today/TodayGrowthPresentation.swift`
- Modify: `LIVELVL/LIVELVL/Today/TaskRailView.swift`
- Modify: `LIVELVL/LIVELVLTests/TaskRewardFeedbackTests.swift`
- Modify: `LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift`

**Interfaces:**
- Produces: `TodayHeaderPresentation.eyebrow`, `.dateText`, `TodayTaskSummaryPresentation`, and `TaskRailPresentation.displayedXPText`.

- [x] **Step 1: Add failing presentation tests**

Test a fixed Gregorian date in Asia/Shanghai and expect `LIVELVL` plus `9月7日 · 星期一`. Test task summary clamping and expect a resting row to show `10 XP` while reward feedback shows `+10 XP`.

- [x] **Step 2: Run the two focused suites and verify RED**

Run the `TaskRewardFeedbackTests` and `TodayCompanionLevelCardTests` suites. Expected: compilation failures for the new presentation properties.

- [x] **Step 3: Add minimal pure presentation logic**

Format date components using the injected calendar, clamp task counts to `0...total`, and derive display XP from reward XP or base XP.

- [x] **Step 4: Run the focused suites and verify GREEN**

Expected: both suites pass with existing task and growth contracts unchanged.

### Task 2: Compose the Upgraded Today Screen

**Files:**
- Modify: `LIVELVL/LIVELVL/ContentView.swift`
- Modify: `LIVELVL/LIVELVL/Today/TaskRailView.swift`
- Modify: `LIVELVL/LIVELVL/Today/TodayVisualTheme.swift`
- Modify: `LIVELVL/LIVELVL/Today/LifeCoreWidget.swift`
- Modify: `LIVELVL/LIVELVL/Today/LifeFieldView.swift`
- Modify: `LIVELVL/LIVELVL/Journal/TodayJournalEntryView.swift`
- Modify: `LIVELVL/LIVELVLTests/LivingOSDesignSystemTests.swift`

**Interfaces:**
- Consumes: existing `TodayView` state, `TodayLifeFieldSection`, `TaskRailView`, and `TodayJournalEntryView` actions.
- Produces: the approved header, tighter regular field, regular-hexagon geometry, journal-first content order, and restrained surfaces.

- [x] **Step 1: Add a failing layout contract test**

Expect the regular header offset to be `0`, the regular field height to fit within `380`, the accessibility field to remain at least `590`, and task section visibility to be enabled.

- [x] **Step 2: Run focused layout tests and verify RED**

Run `LivingOSDesignSystemTests` and `TodayCompanionLevelCardTests`. Expected: the old `-28` header offset, 492-point regular field, and hidden task heading fail.

- [x] **Step 3: Implement the approved composition**

Pass the header eyebrow and date to `LivingOSPageHeader`; place the journal entry before the task section, then present a task heading, count, and rows. Tighten only regular-size life-field and central-card metrics. Map normalized life-field geometry through an aspect-ratio-safe display transform so the six outer vertices form a true regular hexagon. Update task row hierarchy while preserving its two actions and accessibility values. Reduce decorative dot density without changing animation state.

- [x] **Step 4: Build and visually inspect**

Build and run on iPhone 17 Pro. Verify all six labels remain readable, the card does not cover controls, task rows and journal are reachable, and the tab bar does not obscure content.

- [x] **Step 5: Run focused Today tests**

Run `LivingOSDesignSystemTests`, `TaskRewardFeedbackTests`, `TodayCompanionLevelCardTests`, `TodayJournalEntryTests`, and `LifeFieldPresentationTests`.

### Task 3: Regression and Delivery

**Files:**
- Modify only if verification reveals an authorized Today defect.

**Interfaces:**
- Finalizes existing interfaces and introduces no new product state.

- [x] **Step 1: Exercise real interactions**

On iPhone 17 Pro, fold and expand the core, open a dimension detail, open and cancel task editing without mutating user data, open and close the journal, and scroll through the page. Verify the separate completion target, Reduce Motion contract, and accessibility Dynamic Type layout through focused tests.

- [x] **Step 2: Run complete verification**

Run the complete Debug test suite, Debug build, `git diff --check`, and inspect repository status.

- [x] **Step 3: Commit the upgrade**

Stage only the new spec, plan, Today source changes, and associated tests. Commit with `feat: refine Today visual hierarchy`.
