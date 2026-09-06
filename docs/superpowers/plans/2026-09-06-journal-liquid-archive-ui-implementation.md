# Journal Liquid Archive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved Liquid Archive journal editor, focus mode, archive layer, and Today navigation in native SwiftUI.

**Architecture:** `TodayView` owns only the full-screen route. `JournalLiquidArchiveView` coordinates local editing state and persists one `JournalEntry` per natural day through `JournalEntryStore`; focused child views render the title/body editor, archive, material surfaces, and entrance choreography.

**Tech Stack:** SwiftUI, Swift Concurrency, FocusState, native materials/gradients, iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-06-journal-liquid-archive-ui-design.md`

## Global Constraints

- Deployment target remains iOS 17.0.
- Do not modify `project.pbxproj`, `*.xcuserstate`, or `.tmp/`.
- Do not commit, merge, rebase, or push during this pass.
- Preserve existing unrelated and untracked work.
- Saving status must reflect actual SwiftData saves; failed flushes cannot dismiss silently.
- Respect Reduce Motion and accessibility Dynamic Type.

---

### Task 1: Journal Screen and Motion Components

**Files:**
- Create: `LIVELVL/LIVELVL/Journal/JournalLiquidArchiveView.swift`

**Interfaces:**
- Consumes: `LivingOSTheme.signal`, SwiftData `ModelContext`, and a dismiss closure.
- Produces: `JournalLiquidArchiveView(onClose:)` and private focused presentation components.

- [x] **Step 1: Define the screen state and public view interface**

Create `JournalLiquidArchiveView` with `@Binding var draft: String`, `let onClose: () -> Void`, `@FocusState` for editor focus, and local archive/completion/entrance states.

- [x] **Step 2: Build the continuous silver writing page**

Compose a full-screen `ZStack` with an optical gradient field, navigation, date hero, time rail, native title field and `TextEditor`, privacy copy, and a bottom material dock. Keep the black completion control available while editing and show truthful autosave status in the dock.

- [x] **Step 3: Add the approved choreography**

Animate the black cover away on appear, derive focus-mode opacity/blur/offset from the editor focus, slide the archive overlay from the trailing edge, and spring the completion control. The focus-state check dismisses the keyboard and confirms completion; the keyboard toolbar can dismiss without completing. Replace large transforms with opacity when Reduce Motion is enabled.

- [x] **Step 4: Add accessibility adaptations**

Add labels and identifiers to close, history, editor, photo preview, and completion controls. Reduce decorative title scale and allow archive metadata to wrap for accessibility sizes.

- [x] **Step 5: Compile the new screen**

Run the simulator build. Expected: build succeeds without new warnings or errors from `JournalLiquidArchiveView.swift`.

### Task 2: Today Navigation

**Files:**
- Modify: `LIVELVL/LIVELVL/ContentView.swift`
- Existing: `LIVELVL/LIVELVL/Journal/TodayJournalEntryView.swift`

**Interfaces:**
- Consumes: `JournalLiquidArchiveView(onClose:)`.
- Produces: Today entry opens the journal; persistence remains owned by the journal domain.

- [x] **Step 1: Add Today route state**

Add `@State private var isShowingJournal = false` to `TodayView`.

- [x] **Step 2: Wire the existing entry**

Change `TodayJournalEntryView(onOpen: {})` to set `isShowingJournal = true`.

- [x] **Step 3: Present the destination full-screen**

Attach `fullScreenCover(isPresented:)` to Today and initialize `JournalLiquidArchiveView`; its close action sets the route false.

- [x] **Step 4: Verify the route manually**

Build and run, enter a title and body, close the page, reopen it, and confirm the same daily entry is restored.

### Task 3: End-to-End Visual Verification

**Files:**
- Verify only; no planned source changes.

**Interfaces:**
- Consumes: completed Tasks 1–2.
- Produces: build/test evidence and simulator screenshots.

- [x] **Step 1: Run the existing test suite**

Run the `LIVELVL` simulator test action. Expected: all existing tests pass.

- [x] **Step 2: Verify default state**

Open the journal and capture the settled default editor. Check silver background, date hierarchy, red time marker, and truthful session status.

- [x] **Step 3: Verify focus state**

Tap the editor and type Chinese text. Check that header chrome recedes, editor expands, the keyboard remains usable, and the dock compresses.

- [x] **Step 4: Verify archive state**

Dismiss the keyboard, open Archive, verify metadata-only presentation, then close it.

- [x] **Step 5: Check repository hygiene**

Run `git diff --check` and `git status --short`. Expected: no whitespace errors and no protected-file changes.

### Task 4: Daily Entry Persistence and Autosave

**Files:**
- Create: `LIVELVL/LIVELVL/Journal/JournalEntry.swift`
- Modify: `LIVELVL/LIVELVL/Journal/JournalLiquidArchiveView.swift`
- Modify: `LIVELVL/LIVELVL/LIVELVLApp.swift`
- Modify: `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`
- Create: `LIVELVL/LIVELVLTests/JournalEntryStoreTests.swift`
- Modify: `LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift`

- [x] **Step 1: Test and implement one-entry-per-day persistence**

Use a time-zone-qualified day key, update the existing daily entry on repeated saves, and avoid creating empty drafts.

- [x] **Step 2: Add title and truthful autosave states**

Place a native title field above the body. Debounce edits by 750 ms and show idle, saving, saved, and failed states backed by real `ModelContext.save()` results.

- [x] **Step 3: Flush every exit path**

Flush on close, completion, archive opening, and app backgrounding. Block dismissal after a failed save and offer retry or copy recovery.

- [x] **Step 4: Verify persistence in the simulator**

Enter a title and body, observe `已自动保存`, close and reopen, then complete the entry and confirm Archive shows one metadata-only completed row.
