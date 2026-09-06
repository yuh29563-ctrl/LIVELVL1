# Journal Liquid Archive UI Design

## Goal

Turn the existing `THE NOTE` card into a functional entrance for a native SwiftUI journal concept screen that reproduces the approved **Liquid Archive** direction: premium silver-gray material, high-contrast typography, one signal-red accent, and motion-led interaction.

## Scope

- Open the journal from the existing Today entry card.
- Present a full-screen editor for today's entry.
- Support one local entry per natural day with a title and body.
- Persist changes through a truthful 750 ms debounced autosave, with immediate flush on close, completion, and backgrounding.
- Provide a privacy-safe archive overlay containing saved date, state, and character-count metadata; never show title or body previews.
- Tapping a saved row opens a read-only sheet with its original date, full title, and scrollable body. Closing the sheet returns to the archive without editing today's draft.
- Implement the book-to-page entrance, focus-mode chrome retreat, archive slide, and completion feedback.
- Respect Reduce Motion and accessibility Dynamic Type.

Photo importing, authentication, soft deletion, and recovery behavior described in `docs/JOURNAL-MODULE-HANDOFF.md` remain out of scope for this focused implementation pass.

## Visual Language

- Background: layered light-gray and silver gradients with a slow optical light field.
- Typography: large condensed-feeling system display type for `TODAY`; serif body copy for an editorial writing surface.
- Structure: one continuous page instead of stacked cards. A thin time rail and small red signal dot provide orientation.
- Controls: circular and capsule-shaped translucent surfaces with restrained highlights and shadows.
- Color: graphite, black, silver, white, and exactly one signal red accent.

## Interaction and Motion

1. Entry: a black `THE NOTE` cover scales and rotates into the destination, then dissolves to reveal the silver page.
2. Focus: when the editor receives focus, navigation and the hero title blur, fade, and lift; the writing region expands upward and the bottom dock compresses while retaining a black confirmation control.
3. Archive: the archive is an in-page translucent layer that slides from the trailing edge and reveals metadata rows in sequence.
4. Completion: while writing, the black check control flushes pending changes, marks today's entry completed, and returns to Today. A separate keyboard-toolbar action only dismisses the keyboard and keeps the current entry state.
5. Reduce Motion: all large transforms become short opacity transitions; the ambient light field becomes static.

## Accessibility

- Every icon-only control has an explicit Chinese accessibility label.
- Touch targets are at least 44 points.
- TextEditor remains a native editable control.
- At accessibility Dynamic Type sizes, the large decorative title reduces in scale and the archive row wraps vertically.
- Decorative light fields and entry cover are hidden from accessibility.

## Saving Semantics

The editor stores title and body in SwiftData on this device. The bottom status is driven by real persistence results and displays `无需手动保存`, `正在自动保存…`, `已自动保存`, or `自动保存失败 · 轻触重试`. A failed flush blocks silent dismissal and offers retry and copy recovery paths. Automatic local saving protects against interrupted editing but does not promise recovery after app deletion or device loss.

## Acceptance Criteria

- Tapping `THE NOTE` opens the new full-screen view.
- The screen visually matches the approved Liquid Archive concept at iPhone 17 Pro size.
- Tapping the editor visibly transitions to focus mode and allows typing.
- The title field sits above the body and both values reload after leaving and reopening the journal.
- Tapping history shows a metadata-only overlay and can dismiss it.
- Archive rows show full dates across months and years. Selecting a row reads that exact saved entry, with fallbacks for an empty title or body.
- Repeated saves on the same date update one entry instead of creating duplicates.
- Closing, completing, and backgrounding flush pending edits; completion returns to Today.
- The app builds and the existing test suite passes.
- Simulator screenshots verify default, focus, and archive states.
