# Companion Point-Cloud Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the active companion's four stage images as deterministic point-cloud artwork in the expanded Today card and as an interactive, non-obscuring center core after the card docks.

**Architecture:** A manifest-backed provider resolves `collectibleID + CompanionStage` to bundled image data. A pure raster extractor converts black-and-white artwork into bounded normalized point descriptors off the main actor, and an actor repository caches only the active and next descriptors. A shared Canvas renderer serves expanded and collapsed presentations; Today owns only display state and layer placement.

**Tech Stack:** Swift 5, SwiftUI Canvas/TimelineView, ImageIO/CoreGraphics, CryptoKit, Swift Testing, Xcode 26.5, iOS 17+

**Spec:** `docs/superpowers/specs/2026-08-30-companion-point-cloud-core-design.md`

## Global Constraints

- Work only in `/Users/fy/Desktop/LIVELVL/.worktrees/rewards-mvp` on `codex/rewards-mvp`.
- Do not reset, rebase, merge, push, or create another branch.
- Do not modify `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`, `UserInterfaceState.xcuserstate`, or `.tmp/`.
- Do not change companion progression thresholds, collection rules, Archive, Rewards, or You.
- No network, account, cloud, SwiftData migration, or bulk-import UI.
- Use strict RED → GREEN → REFACTOR. Never delete tests, relax assertions, or change product rules to pass.
- After each task, run its focused tests and the Today focused set. Run the full Debug suite only in Task 7 unless a regression requires it earlier.
- Keep the existing card-to-dock layout, arrows, six-dimension geometry, task behavior, and simulator data intact.

---

### Task 1: Four-Stage Artwork Identity and Bundled Manifest

**Files:**
- Create: `LIVELVL/LIVELVL/Today/CompanionArtwork.swift`
- Create: `LIVELVL/LIVELVL/Resources/CompanionArtwork/manifest.json`
- Create: `LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-juvenile.jpg`
- Create: `LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-stage-two.jpg`
- Create: `LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-stage-three.jpg`
- Create: `LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-mature.jpg`
- Create: `LIVELVL/LIVELVLTests/CompanionArtworkTests.swift`

**Interfaces:**
- Produces: `CompanionArtworkID`, `CompanionArtworkPayload`, `CompanionArtworkDataProviding`, `CompanionArtworkManifest`, and `BundledCompanionArtworkProvider`.
- Resource lookup is keyed only by `CompanionArtworkID(collectibleID:stage:)`; views never know filenames.

- [ ] **Step 1: Write failing manifest and identity tests**

Add tests with literal expected mappings:

```swift
import Foundation
import Testing
@testable import LIVELVL

struct CompanionArtworkTests {
    @Test func pilotManifestMapsEverySproutStageInOrder() throws {
        let manifest = try CompanionArtworkManifest.decode(data: Data(#"""
        {"version":1,"entries":[
          {"collectibleID":"ordinary.sprout","stage":"juvenile","resourceName":"ordinary-sprout-juvenile","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"stageTwo","resourceName":"ordinary-sprout-stage-two","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"stageThree","resourceName":"ordinary-sprout-stage-three","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"mature","resourceName":"ordinary-sprout-mature","fileExtension":"jpg"}
        ]}
        """#.utf8))

        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .juvenile))?.name == "ordinary-sprout-juvenile")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .stageTwo))?.name == "ordinary-sprout-stage-two")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .stageThree))?.name == "ordinary-sprout-stage-three")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .mature))?.name == "ordinary-sprout-mature")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.hare", stage: .juvenile)) == nil)
    }

    @Test func invalidStageMakesTheManifestFailClosed() {
        let data = Data(#"{"version":1,"entries":[{"collectibleID":"ordinary.sprout","stage":"unknown","resourceName":"bad","fileExtension":"jpg"}]}"#.utf8)
        #expect(throws: CompanionArtworkManifestError.self) {
            try CompanionArtworkManifest.decode(data: data)
        }
    }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
/usr/bin/xcodebuild -quiet \
  -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LIVELVLTests/CompanionArtworkTests test
```

Expected: build failure because the artwork types do not exist.

- [ ] **Step 3: Add the identity, manifest, and provider boundary**

Implement these exact public shapes in `CompanionArtwork.swift`:

```swift
import CryptoKit
import Foundation

nonisolated struct CompanionArtworkID: Hashable, Codable, Sendable {
    let collectibleID: String
    let stage: CompanionStage
}

nonisolated struct CompanionArtworkResource: Equatable, Sendable {
    let name: String
    let fileExtension: String
}

nonisolated struct CompanionArtworkPayload: Equatable, Sendable {
    let id: CompanionArtworkID
    let data: Data
    let fingerprint: String
}

protocol CompanionArtworkDataProviding: Sendable {
    func payload(for id: CompanionArtworkID) async throws -> CompanionArtworkPayload?
}
```

`CompanionArtworkManifest.decode(data:)` must reject unknown stage names and duplicate identities. `BundledCompanionArtworkProvider(bundle:subdirectory:)` defaults to `Bundle.main` and `"CompanionArtwork"`, loads `manifest.json` plus image files from that subdirectory, computes a lowercase SHA-256 fingerprint, and returns `nil` for unmapped identities.

- [ ] **Step 4: Add the approved pilot assets and manifest**

Copy without altering the originals:

```bash
mkdir -p LIVELVL/LIVELVL/Resources/CompanionArtwork
cp '/Users/fy/Downloads/3-1_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg' LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-juvenile.jpg
cp '/Users/fy/Downloads/3-2_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg' LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-stage-two.jpg
cp '/Users/fy/Downloads/3-3_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg' LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-stage-three.jpg
cp '/Users/fy/Downloads/3-4_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg' LIVELVL/LIVELVL/Resources/CompanionArtwork/ordinary-sprout-mature.jpg
```

Write `manifest.json` with the same four literal entries used by the test. Do not edit `project.pbxproj`; the project uses file-system synchronized groups.

- [ ] **Step 5: Verify GREEN and bundled lookup**

Run the Task 1 test command, then add this app-host integration contract:

```swift
@Test func bundledPilotPayloadsAreReadableJPEGs() async throws {
    let provider = try BundledCompanionArtworkProvider(
        bundle: .main,
        subdirectory: "CompanionArtwork"
    )

    for stage in CompanionStage.allCases {
        let id = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: stage)
        let payload = try #require(try await provider.payload(for: id))
        #expect(payload.data.count > 2)
        #expect(payload.data.prefix(2).elementsEqual([0xFF, 0xD8]))
    }
}
```

Expected: all `CompanionArtworkTests` pass against resources in the hosted app bundle. If the synchronized resource group does not preserve the `CompanionArtwork` subdirectory, stop and report that project-integration evidence; do not edit `project.pbxproj`.

- [ ] **Step 6: Run Today focused tests**

```bash
/usr/bin/xcodebuild -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LIVELVLTests/LifeFieldPresentationTests \
  -only-testing:LIVELVLTests/TodayCompanionLevelCardTests \
  -only-testing:LIVELVLTests/CompanionArtworkTests test
```

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Today/CompanionArtwork.swift \
  LIVELVL/LIVELVL/Resources/CompanionArtwork \
  LIVELVL/LIVELVLTests/CompanionArtworkTests.swift
git commit -m 'feat: add companion stage artwork manifest'
```

---

### Task 2: Deterministic Ink Raster and Point Descriptor

**Files:**
- Create: `LIVELVL/LIVELVL/Today/CompanionPointCloudExtractor.swift`
- Create: `LIVELVL/LIVELVLTests/CompanionPointCloudExtractorTests.swift`

**Interfaces:**
- Consumes: `CompanionArtworkPayload`.
- Produces: `CompanionInkRaster`, `CompanionPointSeed`, `CompanionPointCloudDescriptor`, `CompanionArtworkRasterizer.raster(data:maxDimension:)`, and `CompanionPointCloudExtractor.extract(id:raster:configuration:)`.

- [ ] **Step 1: Write pure extractor tests before production code**

Use hand-built rasters so expectations do not duplicate the implementation:

```swift
@Test func extractorRejectsOuterFrameAndNearWhiteNoise() throws {
    var pixels = Array(repeating: UInt8(250), count: 20 * 20)
    for x in 0..<20 { pixels[x] = 0; pixels[19 * 20 + x] = 0 }
    for y in 0..<20 { pixels[y * 20] = 0; pixels[y * 20 + 19] = 0 }
    pixels[10 * 20 + 10] = 0
    let raster = CompanionInkRaster(width: 20, height: 20, luminance: pixels)

    let descriptor = CompanionPointCloudExtractor.extract(
        id: .init(collectibleID: "ordinary.sprout", stage: .juvenile),
        raster: raster,
        configuration: .pilot
    )

    #expect(descriptor.points.count == 1)
    #expect(descriptor.points[0].position == CGPoint(x: 10.0 / 19.0, y: 10.0 / 19.0))
}

@Test func extractionIsDeterministicAndBounded() {
    let raster = CompanionInkRaster(width: 80, height: 80, luminance: Array(repeating: 0, count: 6_400))
    let id = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: .mature)
    let first = CompanionPointCloudExtractor.extract(id: id, raster: raster, configuration: .pilot)
    let second = CompanionPointCloudExtractor.extract(id: id, raster: raster, configuration: .pilot)
    #expect(first == second)
    #expect(first.points.count == 640)
    #expect(first.points.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
}
```

Add a pilot integration test that extracts all four bundled files and asserts:

```swift
#expect(juvenile.occupiedBounds.width < mature.occupiedBounds.width)
#expect(juvenile.occupiedBounds.height < mature.occupiedBounds.height)
#expect(mature.points.count > juvenile.points.count)
```

- [ ] **Step 2: Run extractor tests and verify RED**

Expected: build failure for missing extractor types.

- [ ] **Step 3: Implement rasterization and deterministic extraction**

Use ImageIO/CoreGraphics, not `UIImage` in the extraction boundary. `CompanionPointCloudExtractionConfiguration.pilot` is fixed to:

```swift
cropFraction = 0.035
inkThreshold = 0.12
maxRasterDimension = 160
maximumPointCount = 640
```

Rasterization draws the image into an 8-bit grayscale buffer while preserving aspect ratio. Extraction ignores the cropped border, converts luminance to `inkWeight = 1 - luminance / 255`, discards values below the threshold, uses a stable hash of artwork identity and pixel coordinates for weighted selection, sorts by stable priority, and prefixes at `maximumPointCount`.

`CompanionPointSeed` contains normalized position, ink weight, and a stable `UInt64` seed. `occupiedBounds` is calculated from accepted points in the original normalized canvas; never renormalize to the accepted-point bounds.

- [ ] **Step 4: Run extractor and artwork tests**

Expected: synthetic border/noise test, deterministic bound test, and all four pilot integration tests pass.

- [ ] **Step 5: Run Today focused tests and commit**

```bash
git add LIVELVL/LIVELVL/Today/CompanionPointCloudExtractor.swift \
  LIVELVL/LIVELVLTests/CompanionPointCloudExtractorTests.swift
git commit -m 'feat: extract deterministic companion point clouds'
```

---

### Task 3: Bounded Repository, Cache, Cancellation, and Fallback State

**Files:**
- Create: `LIVELVL/LIVELVL/Today/CompanionPointCloudRepository.swift`
- Create: `LIVELVL/LIVELVLTests/CompanionPointCloudRepositoryTests.swift`

**Interfaces:**
- Consumes: `CompanionArtworkDataProviding`, `CompanionArtworkRasterizer`, and `CompanionPointCloudExtractor`.
- Produces: actor `CompanionPointCloudRepository`, `CompanionPointCloudRequest`, `CompanionPointCloudPair`, and main-actor `CompanionPointCloudLoader`.

- [ ] **Step 1: Write failing cache and stale-request tests**

Create a controllable actor fake provider that counts payload requests and can suspend a selected identity. Test these behaviors separately:

```swift
@Test func repeatedIdentityUsesOneProviderLoad() async throws {
    let provider = CountingArtworkProvider(payloads: [pilotID: pilotPayload])
    let repository = CompanionPointCloudRepository(provider: provider)
    _ = try await repository.descriptor(for: pilotID)
    _ = try await repository.descriptor(for: pilotID)
    #expect(await provider.requestCount(for: pilotID) == 1)
}

@MainActor @Test func staleLoadCannotReplaceTheNewestArtwork() async {
    let loader = CompanionPointCloudLoader(repository: controlledRepository)
    loader.load(.init(current: slowID, next: nil))
    loader.load(.init(current: fastID, next: nil))
    await controlledRepository.finish(fastID)
    await controlledRepository.finish(slowID)
    #expect(loader.state.current?.id == fastID)
}
```

Also test missing and corrupt payloads produce `.fallback` with no modal error string.

- [ ] **Step 2: Run repository tests and verify RED**

Expected: build failure for missing repository and loader types.

- [ ] **Step 3: Implement the bounded actor repository**

The cache key is `(CompanionArtworkID, fingerprint, rendererVersion: 1)`. Keep an LRU maximum of two descriptors. `descriptor(for:)` returns `nil` for missing data and throws only internal decode/extraction errors; the loader catches either path and publishes `.fallback`.

Define the request and output exactly:

```swift
nonisolated struct CompanionPointCloudRequest: Equatable, Sendable {
    let current: CompanionArtworkID
    let next: CompanionArtworkID?
}

nonisolated struct CompanionPointCloudPair: Equatable, Sendable {
    let current: CompanionPointCloudDescriptor
    let next: CompanionPointCloudDescriptor?
}
```

`CompanionPointCloudLoader.load(_:)` cancels its previous task, captures the request, loads current then optional next, checks cancellation and request equality before publishing, and never lets an old completion overwrite the latest state.

- [ ] **Step 4: Run repository, extractor, and Today focused tests**

Expected: all pass with no new Swift concurrency warnings.

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/Today/CompanionPointCloudRepository.swift \
  LIVELVL/LIVELVLTests/CompanionPointCloudRepositoryTests.swift
git commit -m 'feat: load and cache active companion point clouds'
```

---

### Task 4: Shared Point-Cloud Motion and Canvas Renderer

**Files:**
- Create: `LIVELVL/LIVELVL/Today/CompanionPointCloudView.swift`
- Create: `LIVELVL/LIVELVLTests/CompanionPointCloudMotionTests.swift`

**Interfaces:**
- Consumes: `CompanionPointCloudPair`, XP progress, reward phase, scene phase, Reduce Motion.
- Produces: `CompanionPointCloudMode`, `CompanionPointCloudMotion.samples(...)`, and `CompanionPointCloudView`.

- [ ] **Step 1: Write failing motion and ghost-isolation tests**

Test literal contracts:

```swift
@Test func collapsedMotionMovesNormallyAndFreezesForReduceMotion() {
    let movingA = CompanionPointCloudMotion.samples(descriptor: fixture, mode: .collapsed, phase: 0, reduceMotion: false)
    let movingB = CompanionPointCloudMotion.samples(descriptor: fixture, mode: .collapsed, phase: 0.4, reduceMotion: false)
    let frozenA = CompanionPointCloudMotion.samples(descriptor: fixture, mode: .collapsed, phase: 0, reduceMotion: true)
    let frozenB = CompanionPointCloudMotion.samples(descriptor: fixture, mode: .collapsed, phase: 0.9, reduceMotion: true)
    #expect(movingA != movingB)
    #expect(frozenA == frozenB)
    #expect(movingA.count <= 360)
}

@Test func nextStageGhostNeverBecomesOfficialBeforeProgression() {
    #expect(CompanionPointCloudMotion.ghostOpacity(progress: 0.71, hasNext: true) == 0)
    #expect(CompanionPointCloudMotion.ghostOpacity(progress: 1.0, hasNext: true) == 0.18)
    #expect(CompanionPointCloudMotion.ghostOpacity(progress: 1.0, hasNext: false) == 0)
}
```

Add a test that `.expanded` keeps at most 640 points and `.collapsed` keeps at most 360.

- [ ] **Step 2: Run motion tests and verify RED**

- [ ] **Step 3: Implement restrained deterministic motion**

Use these fixed presentation rules:

- expanded point budget: 640;
- collapsed point budget: 360;
- collapsed visual size: 108pt regular, 120pt accessibility;
- breathing scale: `0.985...1.015` over 8 seconds;
- per-point drift: at most 1.8pt at collapsed size;
- opposing orbital layers derive from each seed and rotate slowly without changing the source silhouette;
- next-stage ghost starts at XP progress `0.72` and ramps linearly to opacity `0.18` at `1.0`;
- reward pulse peaks at scale `1.035` and returns within `0.55s`;
- Reduce Motion uses phase `0.19`, breathing scale `1`, and zero drift.

`CompanionPointCloudView` owns no business data. It receives a load state, mode, progress, and reward token; uses `TimelineView(.animation(minimumInterval: 1 / 24))`; and pauses with the existing `LivingOSAnimationActivity` rule.

- [ ] **Step 4: Run motion, repository, extractor, and Today focused tests**

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/Today/CompanionPointCloudView.swift \
  LIVELVL/LIVELVLTests/CompanionPointCloudMotionTests.swift
git commit -m 'feat: render animated companion point clouds'
```

---

### Task 5: Replace the Expanded Card's Generic Artwork

**Files:**
- Modify: `LIVELVL/LIVELVL/Today/LifeCoreWidget.swift`
- Modify: `LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift`

**Interfaces:**
- Consumes: `LifeCoreWidgetPresentation.definition`, `.stage`, `.progress`, and `CompanionPointCloudLoader`.
- Produces: `LifeCoreWidgetPresentation.artworkRequest` and expanded point-cloud rendering with generic fallback.

- [ ] **Step 1: Write failing presentation tests**

```swift
@Test func lifeCoreRequestsTheCurrentAndNextStageForTheSameCompanion() {
    let stageTwo = makePresentation(definition: CollectionCatalog.ordinary[0], stage: .stageTwo)
    #expect(stageTwo.artworkRequest.current == .init(collectibleID: "ordinary.sprout", stage: .stageTwo))
    #expect(stageTwo.artworkRequest.next == .init(collectibleID: "ordinary.sprout", stage: .stageThree))

    let mature = makePresentation(definition: CollectionCatalog.ordinary[0], stage: .mature)
    #expect(mature.artworkRequest.next == nil)
}
```

Add a test proving a different `CollectibleDefinition.id` produces a different current artwork identity without changing level or XP fields.

- [ ] **Step 2: Run `TodayCompanionLevelCardTests` and verify RED**

- [ ] **Step 3: Add the stage request mapping and shared loader**

Add a nonisolated `CompanionStage.nextArtworkStage` mapping: juvenile → stageTwo → stageThree → mature → nil. `LifeCoreWidgetPresentation.artworkRequest` uses the current definition ID and this mapping.

`TodayLifeFieldSection` owns one `@StateObject CompanionPointCloudLoader` configured with the live bundled repository. Start/restart loading using `.task(id: core.artworkRequest)` so fold/unfold does not duplicate image decoding.

- [ ] **Step 4: Replace only `LifeCoreArtwork` content**

Keep the card shell, XP labels, progress, dimensions, shadow, collapse button, reward indicator, and accessibility semantics. Inside its existing 146pt artwork region, render `CompanionPointCloudView(mode: .expanded)`. If state is `.fallback`, render the existing `LifeCoreArtwork` unchanged.

- [ ] **Step 5: Run Today focused tests and build**

Run the Today focused command and `xcodebuild ... build`. Expected: no warnings, existing default card tests and new artwork-request tests pass.

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/Today/LifeCoreWidget.swift \
  LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift
git commit -m 'feat: show stage artwork in Today growth card'
```

---

### Task 6: Collapsed Center Core, Layering, Tap, and Dissolve Transition

**Files:**
- Modify: `LIVELVL/LIVELVL/Today/LifeCoreWidget.swift`
- Modify: `LIVELVL/LIVELVL/Today/LifeFieldView.swift`
- Modify: `LIVELVL/LIVELVLTests/LifeFieldPresentationTests.swift`
- Modify: `LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift`

**Interfaces:**
- Consumes: the shared loader and `CompanionPointCloudView(mode: .collapsed)`.
- Produces: point-cloud visual below field geometry and a sighted-user center tap target that calls the existing expand action.

- [ ] **Step 1: Write failing layer and interaction contract tests**

Extend layer tests with literal ordering:

```swift
#expect(LifeFieldLayerOrder.backdropDots < LifeFieldLayerOrder.companionCore)
#expect(LifeFieldLayerOrder.companionCore < LifeFieldLayerOrder.dynamicEdges)
#expect(LifeFieldLayerOrder.dynamicEdges < LifeFieldLayerOrder.controls)
#expect(LifeCoreCollapseLayout.centerCoreTapDimension >= 44)
#expect(LifeCoreCollapseLayout.collapsedCoreDimension(isAccessibilitySize: false) == 108)
#expect(LifeCoreCollapseLayout.collapsedCoreDimension(isAccessibilitySize: true) == 120)
```

Add a display-state test that the center core is present only for `.compact`, while the expanded card remains present only for `.expanded`.

- [ ] **Step 2: Run both Today test suites and verify RED**

- [ ] **Step 3: Split backdrop composition without changing geometry**

Refactor `LifeFieldBackdrop` into ordered internal layers: ambient dot field, optional center artwork content, edge particles, outer reference polygon, official polygon. Preserve all current targets and edge calculations byte-for-byte. A generic `@ViewBuilder centerContent` is acceptable; do not use `AnyView`.

The center point cloud is positioned with `LifeFieldLayout.point(for: LifeFieldLayout.visualCore, in: size)` and remains below both polygon strokes and all node views.

- [ ] **Step 4: Add the separate center tap target**

In compact mode, overlay a clear 108/120pt button at the same normalized center. It calls `toggleCoreDisplayMode`, uses `.buttonStyle(.plain)`, and is `.accessibilityHidden(true)` because the dock already exposes the expansion action. Field node controls stay at a higher z-index, so a dimension scoring near zero keeps priority.

- [ ] **Step 5: Coordinate fold/unfold motion**

Use a local `@Namespace` and a stable artwork ID to coordinate the expanded artwork frame and collapsed core frame. The shell retains its current card-to-dock transition. The artwork adds a short seeded scatter/converge envelope; do not move official field points or create radial lines. Under Reduce Motion, disable matched movement and scatter, using opacity only.

- [ ] **Step 6: Run focused tests and simulator smoke test**

On iPhone 17 Pro:

1. Cold-launch and confirm the card defaults expanded.
2. Fold and verify the translucent dock remains below Today.
3. Confirm galaxy point cloud appears at center while all six edges, points, labels, and projected markers remain readable.
4. Tap the center point cloud and confirm the full card expands.
5. Rapidly fold/expand ten times and confirm no stale artwork or crash.

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Today/LifeCoreWidget.swift \
  LIVELVL/LIVELVL/Today/LifeFieldView.swift \
  LIVELVL/LIVELVLTests/LifeFieldPresentationTests.swift \
  LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift
git commit -m 'feat: dissolve collapsed companion into life field'
```

---

### Task 7: Accessibility, Lifecycle, Regression, and Final Acceptance

**Files:**
- Modify if a failing test requires it: `LIVELVL/LIVELVL/Today/CompanionPointCloudView.swift`
- Modify if a failing test requires it: `LIVELVL/LIVELVL/Today/LifeCoreWidget.swift`
- Modify: `LIVELVL/LIVELVLTests/CompanionPointCloudMotionTests.swift`
- Modify: `LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift`

**Interfaces:**
- Finalizes existing interfaces; introduces no new domain model or persistence schema.

- [ ] **Step 1: Add failing lifecycle and accessibility regression tests**

Test that Reduce Motion samples remain identical across phases, inactive/off-screen activity pauses the timeline using `LivingOSAnimationActivity`, the compact dock retains its existing accessibility identifier/value/hint, and the center visual has no second accessibility label.

- [ ] **Step 2: Run the focused tests and verify any new test fails for the intended missing behavior**

- [ ] **Step 3: Implement only the missing lifecycle/accessibility behavior**

Do not add new controls or copy. Preserve the single accessible dock action and current Dynamic Type field heights.

- [ ] **Step 4: Run all focused tests**

```bash
/usr/bin/xcodebuild -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LIVELVLTests/CompanionArtworkTests \
  -only-testing:LIVELVLTests/CompanionPointCloudExtractorTests \
  -only-testing:LIVELVLTests/CompanionPointCloudRepositoryTests \
  -only-testing:LIVELVLTests/CompanionPointCloudMotionTests \
  -only-testing:LIVELVLTests/LifeFieldPresentationTests \
  -only-testing:LIVELVLTests/TodayCompanionLevelCardTests test
```

- [ ] **Step 5: Run the complete Debug test suite**

```bash
/usr/bin/xcodebuild -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected: zero failures. Record the exact suite and test counts.

- [ ] **Step 6: Perform final simulator acceptance without resetting data**

Verify all four pilot stages using controlled debug fixtures or presentation injection, not by mutating progression history. Check expanded artwork, collapse dissolve, center tap expansion, task-reward pulse, next-stage ghost isolation, cold-launch fallback, Dynamic Type, VoiceOver, Reduce Motion, and repeated switching. Restore simulator content size and Reduce Motion settings afterward.

- [ ] **Step 7: Inspect performance and repository hygiene**

Confirm the animation pauses when inactive, only current/next descriptors remain cached, there are no runtime warnings, `git diff --check` passes, and the protected files remain untouched.

- [ ] **Step 8: Commit final regressions if Task 7 changed files**

```bash
git add LIVELVL/LIVELVL/Today/CompanionPointCloudView.swift \
  LIVELVL/LIVELVL/Today/LifeCoreWidget.swift \
  LIVELVL/LIVELVLTests/CompanionPointCloudMotionTests.swift \
  LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift
git commit -m 'test: harden companion point-cloud lifecycle'
```

If Task 7 required no source or test changes, do not create an empty commit.

## Final Handoff

- Report every commit, modified/created file, focused test count, full Debug test count, and simulator acceptance result.
- Keep `codex/rewards-mvp` and `/Users/fy/Desktop/LIVELVL/.worktrees/rewards-mvp` intact.
- Do not push or merge.
