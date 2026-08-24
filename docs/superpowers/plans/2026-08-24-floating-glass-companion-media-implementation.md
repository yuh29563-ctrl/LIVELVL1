# Floating Glass Companion Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add floating Liquid Glass companion and six-dimension cards with persistent local photo/GIF/APNG backgrounds for the companion card.

**Architecture:** Keep progression, reward, and collection domains unchanged. Add a small SwiftData media-reference model backed by an atomic Application Support file store, a pure media-type decoder, and a SwiftUI/UIKit animated-image renderer. The Today cards receive media state explicitly; iOS 26 uses native Liquid Glass and iOS 17–25 uses a material fallback.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PhotosUI, ImageIO, UIKit, Swift Testing, iOS 17+.

**Spec:** `docs/superpowers/specs/2026-08-24-floating-glass-companion-media-design.md`

## Global Constraints

- This is an in-app visual/media feature, not a WidgetKit home-screen widget.
- Keep the minimum deployment target at iOS 17; gate Liquid Glass with `#available(iOS 26, *)`.
- Support static images, GIF, and APNG in the first version; do not add Live Photo or video backgrounds.
- Use `PhotosPicker` for local selection and preserve original media bytes.
- Store media bytes under Application Support/UserCardMedia; SwiftData stores only the media reference.
- Use `scaledToFill` and clip media to the card shape; never resize the card to fit the source image.
- Reduce Motion displays the first frame for animated media and does not play the animation.
- Do not modify progression, SwiftData business models, reward queues, collection logic, or the reward flight animation.
- Never stage `project.pbxproj` or `UserInterfaceState.xcuserstate`.
- The project uses synchronized file groups; new Swift files should not require manual project-file edits.
- Every production change follows TDD: write a failing test, observe the failure, implement the smallest fix, then rerun focused and full tests.

---

## File Map

- `LIVELVL/LIVELVL/Persistence/UserCardMedia.swift`: SwiftData media reference and media-kind value type.
- `LIVELVL/LIVELVL/Persistence/UserCardMediaStore.swift`: atomic local file save/load/delete operations.
- `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`: delete media references and `UserCardMedia` files during reset.
- `LIVELVL/LIVELVL/LIVELVLApp.swift`: register `UserCardMedia` in the schema.
- `LIVELVL/LIVELVL/Media/AnimatedMediaDecoder.swift`: ImageIO type detection, first-frame decoding, and bounded animated-frame decoding.
- `LIVELVL/LIVELVL/Media/AnimatedMediaView.swift`: SwiftUI/UIKit renderer for GIF/APNG playback and Reduce Motion first-frame behavior.
- `LIVELVL/LIVELVL/Today/GlassCardSurface.swift`: iOS 26 Liquid Glass surface and iOS 17 material fallback.
- `LIVELVL/LIVELVL/Today/TodayCompanionMediaState.swift`: view-facing media loading/selection state without persistence in `body`.
- `LIVELVL/LIVELVL/Today/LevelCard.swift`: floating glass companion card, background media, camera/remove actions.
- `LIVELVL/LIVELVL/Today/LifeStateCard.swift`: floating glass six-dimension card.
- `LIVELVL/LIVELVL/ContentView.swift`: query media reference, load state on lifecycle, pass media/actions into the companion card.
- `LIVELVL/LIVELVLTests/UserCardMediaStoreTests.swift`: media type, atomic store, replacement, and deletion tests.
- `LIVELVL/LIVELVLTests/AnimatedMediaDecoderTests.swift`: static/GIF/APNG/Reduce Motion decoder tests.
- `LIVELVL/LIVELVLTests/GlassCardLayoutTests.swift`: floating card metrics and fallback contract tests.
- `LIVELVL/LIVELVLTests/TodayCompanionMediaStateTests.swift`: controller load/import/remove state tests.
- `LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift`: extend existing reset coverage for user card media.

Before feature commits, isolate the already-approved spacing polish changes into their own small commit if they remain uncommitted. Do not combine them with the media feature commit.

## Task 1: Add the Media Reference Model and Atomic Local Store

**Files:**
- Create: `LIVELVL/LIVELVL/Persistence/UserCardMedia.swift`
- Create: `LIVELVL/LIVELVL/Persistence/UserCardMediaStore.swift`
- Modify: `LIVELVL/LIVELVL/LIVELVLApp.swift`
- Create: `LIVELVL/LIVELVLTests/UserCardMediaStoreTests.swift`

**Interfaces:**
- `enum UserCardMediaKind: String, Codable, Sendable { case image, gif, apng }`.
- `@Model final class UserCardMedia { var id: UUID; var fileName: String; var kindRaw: String; var updatedAt: Date; init(fileName: String, kind: UserCardMediaKind, updatedAt: Date = .now) }`.
- `struct UserCardMediaStore { let rootURL: URL; let fileManager: FileManager; func url(for: UserCardMedia) -> URL; func save(data: Data, kind: UserCardMediaKind, replacing old: UserCardMedia?, now: Date, in context: ModelContext) throws -> UserCardMedia; func load(_ media: UserCardMedia) throws -> Data; func delete(_ media: UserCardMedia, from context: ModelContext) throws }`.

- [ ] **Step 1: Write failing store tests**

  Use a UUID-named temporary directory and an in-memory SwiftData container. Test that saving PNG data creates one reference and one file, replacing it leaves one active reference and removes the old file after the context save, loading returns identical bytes, and delete removes both the reference and file.

- [ ] **Step 2: Run focused tests and verify failure**

  Run:

  ```bash
  xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLMediaStoreRed CODE_SIGNING_ALLOWED=NO -only-testing:LIVELVLTests/UserCardMediaStoreTests
  ```

  Expected: compile failure because `UserCardMedia` and `UserCardMediaStore` do not exist.

- [ ] **Step 3: Implement the smallest model/store**

  Create the `UserCardMedia` model, add it to the app schema, create the directory when saving, write to a UUID temporary filename, atomically move it to the final UUID filename, insert the model, and expose load/delete operations. Keep old media untouched until the new write and context save succeed.

- [ ] **Step 4: Run focused tests and verify green**

  Rerun the focused command. Expected: all media-store tests pass with no project-file changes.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Persistence/UserCardMedia.swift LIVELVL/LIVELVL/Persistence/UserCardMediaStore.swift LIVELVL/LIVELVL/LIVELVLApp.swift LIVELVL/LIVELVLTests/UserCardMediaStoreTests.swift
  git commit -m "feat: persist user card media references"
  ```

## Task 2: Decode Static Images, GIF, and APNG Safely

**Files:**
- Create: `LIVELVL/LIVELVL/Media/AnimatedMediaDecoder.swift`
- Create: `LIVELVL/LIVELVLTests/AnimatedMediaDecoderTests.swift`

**Interfaces:**
- `struct DecodedMediaFrame: Equatable { let image: UIImage; let duration: TimeInterval }`.
- `struct DecodedMedia { let kind: UserCardMediaKind; let frames: [DecodedMediaFrame]; var isAnimated: Bool { frames.count > 1 }; var firstFrame: UIImage? { frames.first?.image } }`.
- `enum AnimatedMediaDecoder { static func decode(data: Data, maxPixelSize: Int, allowsAnimation: Bool) throws -> DecodedMedia }`.

- [ ] **Step 1: Write failing decoder tests**

  Add small test fixtures in the test target using generated 1-frame PNG data and minimal GIF/APNG data. Assert PNG returns `.image` with one frame, GIF/APNG return the correct kind with multiple frames when animation is allowed, and both return one first frame when `allowsAnimation` is false. Assert invalid bytes throw a typed decoding error.

- [ ] **Step 2: Run focused tests and verify failure**

  Run:

  ```bash
  xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLMediaDecoderRed CODE_SIGNING_ALLOWED=NO -only-testing:LIVELVLTests/AnimatedMediaDecoderTests
  ```

  Expected: compile failure because the decoder types do not exist.

- [ ] **Step 3: Implement ImageIO decoding**

  Use `CGImageSourceCreateWithData` for type detection and frame count, read frame properties for duration, downsample each frame to `maxPixelSize`, and return only the first frame when animation is disabled. Reject unsupported or malformed data with a stable `MediaDecodingError.invalidData` case.

- [ ] **Step 4: Run focused tests and verify green**

  Rerun the focused command and confirm all fixtures pass, including Reduce Motion first-frame behavior.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Media/AnimatedMediaDecoder.swift LIVELVL/LIVELVLTests/AnimatedMediaDecoderTests.swift
  git commit -m "feat: decode local animated card media"
  ```

## Task 3: Add Glass Surface and Animated Media Rendering

**Files:**
- Create: `LIVELVL/LIVELVL/Today/GlassCardSurface.swift`
- Create: `LIVELVL/LIVELVL/Media/AnimatedMediaView.swift`
- Create: `LIVELVL/LIVELVLTests/GlassCardLayoutTests.swift`

**Interfaces:**
- `enum GlassCardLayout { static let horizontalInset: CGFloat = 16; static let cornerRadius: CGFloat = 28; static let contentPadding: CGFloat = 20 }`.
- `struct GlassCardSurface<Content: View>: View { let background: AnyView?; let content: Content; init(background: AnyView? = nil, @ViewBuilder content: () -> Content) }`.
- `struct AnimatedMediaView: View { let media: DecodedMedia; let reduceMotion: Bool }`.

- [ ] **Step 1: Write failing layout and renderer contract tests**

  Assert the shared floating-card metrics are 16pt horizontal inset, 28pt corner radius, and 20pt internal content padding. Add a test fixture that creates a two-frame decoded media value and verifies the first-frame presentation contract used by Reduce Motion.

- [ ] **Step 2: Run focused tests and verify failure**

  Run:

  ```bash
  xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLGlassRed CODE_SIGNING_ALLOWED=NO -only-testing:LIVELVLTests/GlassCardLayoutTests
  ```

  Expected: compile failure because the shared glass and media views do not exist.

- [ ] **Step 3: Implement the surfaces and renderer**

  Put the background media behind the card content, apply `scaledToFill` and clipping before the glass modifier, and use `GlassEffectContainer`/`.glassEffect` only under `#available(iOS 26, *)`. Use `.ultraThinMaterial` in the fallback. Implement `AnimatedMediaView` with a UIKit `UIImageView` bridge for multiple frames and a static first frame when `reduceMotion` is true.

- [ ] **Step 4: Run focused tests and build both availability paths**

  Run the focused test, then build Debug for iPhone 17 Pro and a generic iOS Simulator destination. Expected: tests pass and iOS 17 deployment compilation remains clean.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Today/GlassCardSurface.swift LIVELVL/LIVELVL/Media/AnimatedMediaView.swift LIVELVL/LIVELVLTests/GlassCardLayoutTests.swift
  git commit -m "feat: add floating glass card surfaces"
  ```

## Task 4: Persist and Select the Companion Background

**Files:**
- Create: `LIVELVL/LIVELVL/Today/TodayCompanionMediaState.swift`
- Modify: `LIVELVL/LIVELVL/Today/LevelCard.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift`

**Interfaces:**
- `struct TodayCompanionMediaState { var media: UserCardMedia?; var decoded: DecodedMedia?; var isLoading: Bool; var errorMessage: String? }`.
- `@MainActor final class TodayCompanionMediaController: ObservableObject { @Published private(set) var state: TodayCompanionMediaState; func load() async; func importMedia(item: PhotosPickerItem) async; func removeMedia() throws }`.
- `TodayCompanionLevelCard(..., media: DecodedMedia?, onChooseMedia: @escaping () -> Void, onRemoveMedia: @escaping () -> Void)`.

- [ ] **Step 1: Write failing state tests**

  Test that a controller with no reference resolves to empty state, successful import stores a media reference and decoded media, invalid data leaves the previous media unchanged with an error, and remove clears the reference and file. Use injected store/context closures so tests exercise real store behavior without UI mocks.

- [ ] **Step 2: Run focused tests and verify failure**

  Run the state test through the full test target with `-only-testing:LIVELVLTests/TodayCompanionMediaStateTests` after adding the test file. Expected: compile failure because the controller does not exist.

- [ ] **Step 3: Implement controller and card integration**

  Query the singleton media reference from `ContentView`, load it in `.task`/`.onAppear`, and pass decoded media explicitly into `TodayCompanionLevelCard`. Add a `PhotosPicker` camera action and a remove action in the card. Keep persistence out of `body`; save only after successful decode and atomic file write. Add accessibility labels exactly as specified.

- [ ] **Step 4: Run focused tests and build**

  Run the focused state tests and a Debug build. Expected: media selection compiles, the default card remains unchanged without media, and the existing reward feedback path remains intact.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Today/TodayCompanionMediaState.swift LIVELVL/LIVELVL/Today/LevelCard.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVLTests/TodayCompanionMediaStateTests.swift
  git commit -m "feat: add companion card background media"
  ```

## Task 5: Migrate the Six-Dimension Card to Floating Glass

**Files:**
- Modify: `LIVELVL/LIVELVL/Today/LifeStateCard.swift`
- Modify: `LIVELVL/LIVELVLTests/GlassCardLayoutTests.swift`

**Interfaces:**
- Keep `LifeStateCard(summary:pulse:onAssessment:)` unchanged for callers; only replace its outer surface with `GlassCardSurface` and apply the shared floating metrics.

- [ ] **Step 1: Extend the failing layout test**

  Add an assertion that both Today card surfaces use the same `GlassCardLayout.horizontalInset`, `cornerRadius`, and `contentPadding` values.

- [ ] **Step 2: Run the focused test and verify it fails for the new surface usage**

  Run `-only-testing:LIVELVLTests/GlassCardLayoutTests`. Expected: failure until `LifeStateCard` consumes the shared surface metrics.

- [ ] **Step 3: Implement the minimal LifeStateCard migration**

  Replace only the outer white background/shadow with `GlassCardSurface`; preserve radar sizing, annotations, assessment button, accessibility, and state flow. Keep the six-dimension card photo-free in this version.

- [ ] **Step 4: Run focused tests and inspect the preview/build**

  Run the focused test and build Debug. Confirm the card remains readable at Large Dynamic Type.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Today/LifeStateCard.swift LIVELVL/LIVELVLTests/GlassCardLayoutTests.swift
  git commit -m "feat: float six-dimension card with glass surface"
  ```

## Task 6: Extend Debug Reset for User Media

**Files:**
- Modify: `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`
- Modify: `LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift`

**Interfaces:**
- Keep `LocalDataResetService.reset(context:fileManager:applicationSupportURL:save:removeItem:)` unchanged for existing callers; add explicit deletion of `UserCardMedia` rows and the `UserCardMedia` directory.

- [ ] **Step 1: Add failing reset assertions**

  Extend the existing in-memory reset fixture with one `UserCardMedia` row and a file under `UserCardMedia/sample.gif`. Assert both the fetch and directory are empty after reset. Add a failure test asserting a media-directory removal error is surfaced as a partial reset error.

- [ ] **Step 2: Run the focused reset tests and verify failure**

  Run `-only-testing:LIVELVLTests/LocalDataResetServiceTests`. Expected: the new media assertions fail because the reset service only knows `RewardProductImages`.

- [ ] **Step 3: Implement explicit media cleanup**

  Delete `UserCardMedia` rows with the other business models, save once, then remove only the exact `Application Support/UserCardMedia` directory. Preserve the existing rollback and partial-failure behavior.

- [ ] **Step 4: Run focused and full tests**

  Run the reset suite, then the complete Debug test suite. Expected: all tests pass and no existing reset behavior changes.

- [ ] **Step 5: Commit**

  ```bash
  git add LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift
  git commit -m "feat: reset user card media with local data"
  ```

## Task 7: Full Verification and Simulator Acceptance

**Files:**
- Modify: `docs/HANDOFF.md` only if the user requests a handoff update after acceptance.

- [ ] **Step 1: Check source-control hygiene**

  Run:

  ```bash
  git diff --check
  git status --short
  git diff -- LIVELVL/LIVELVL.xcodeproj/project.pbxproj
  ```

  Confirm no `project.pbxproj` or `UserInterfaceState.xcuserstate` is staged.

- [ ] **Step 2: Run the complete Debug test suite**

  ```bash
  xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLFloatingGlassFinal CODE_SIGNING_ALLOWED=NO
  ```

  Expected: `** TEST SUCCEEDED **` with all prior tests plus the new media tests passing.

- [ ] **Step 3: Install and inspect the real simulator UI**

  Build/install the Debug app on the booted iPhone 17 Pro. Verify:

  1. No-media companion card has the floating glass surface and remains readable.
  2. Six-dimension card uses the same floating surface and does not touch the screen edges.
  3. Select a static photo; it fills and crops inside the companion card.
  4. Select a GIF and APNG; each animates on iOS 26.5.
  5. Enable Reduce Motion; animated media freezes to its first frame.
  6. Replace and remove the media; relaunch and confirm the persisted state.
  7. Use Debug reset and confirm the media file and reference are removed.
  8. Complete a task and verify the existing reward feedback and reward flight are unchanged.

- [ ] **Step 4: Review the final diff and commit only feature files**

  Ensure commits contain source/tests for this feature only; do not add generated Xcode state. Do not push or merge.
