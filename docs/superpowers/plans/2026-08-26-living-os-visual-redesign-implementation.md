# LIVELVL Living OS Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Today, Archive, Rewards, and You as the approved silver-gray, black-and-white, motion-first Living OS while preserving every existing XP, coin, collectible, reward-queue, persistence, and real-tab-coordinate invariant.

**Architecture:** Add a value-driven design system and deterministic Canvas renderer, then migrate one page at a time. Business services remain independent from UI; pure presentation states own selection, snapping, submission, and motion phases so every behavior receives a failing Swift Testing test before SwiftUI integration.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, Canvas, TimelineView, iOS 17+, Xcode 26.5, iPhone 17 Pro Simulator.

**Spec:** `docs/superpowers/specs/2026-08-26-living-os-visual-redesign.md`

## Global Constraints

- Work only in `/Users/fy/Desktop/LIVELVL/.worktrees/rewards-mvp` on `codex/rewards-mvp`.
- Do not push, merge, or modify the user's main-worktree `project.pbxproj`, `UserInterfaceState.xcuserstate`, or `.tmp/`.
- Minimum deployment remains iOS 17.0; add no third-party dependencies.
- Keep the real system `TabView`/`UITabBar`; never replace it with a fake tab bar.
- Preserve `PendingCardReward`, `OwnedCollectible`, `CollectionProgress`, `CardRewardService`, reward queue order, and measured UIKit Collection-tab targeting.
- Keep reality rewards isolated from collection rewards; never move coin behavior into `CardRewardService`.
- Keep `1 XP = 1 coinUnit` and `10 coinUnit = 1.0 coin`.
- Use the real dimensions `健康 / 学习 / 事业 / 财务 / 关系 / 兴趣`.
- Do not delete tests. Replace obsolete hand-journal assertions with approved Living OS assertions and retain all domain coverage.
- Every behavior follows red → correct failure → minimal green → focused tests → full Debug tests → simulator check → commit.
- Check every spatial claim-flight change against the real iPhone 17 Pro coordinate.
- Reduce Motion changes presentation only; persisted and user-visible results remain identical.
- Draw point fields and paths in `Canvas`; never instantiate one View per particle.

## Authoritative baseline

Run before Task 1:

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug -destination 'platform=iOS Simulator,id=CDEFD7CB-0175-4A46-BC1E-12BD8E9B37D9'
```

Expected on `4fee021`: `115 tests in 25 suites passed` and `** TEST SUCCEEDED **`. The baseline can emit one existing `Unbalanced calls to begin/end appearance transitions` warning during the hosted reset test. Investigate only if frequency changes or a runtime transition defect appears.

## File map

- `DesignSystem/LivingOSTheme.swift`: color, spacing, typography, surface, reference metrics.
- `DesignSystem/LivingOSMotion.swift`: motion profile and Reduce Motion resolution.
- `DesignSystem/LivingOSDotField.swift`: deterministic point geometry and Canvas renderer.
- `DesignSystem/LivingOSPageHeader.swift`: shared editorial header.
- `Today/LifeFieldPresentation.swift`: six-node mapping and selection.
- `Today/LifeFieldView.swift`: field and compact dimension detail.
- `Today/LifeCoreWidget.swift`: iOS-widget-style core.
- `Today/TaskRailView.swift`: hairline task rows.
- `Today/TodayGrowthPresentation.swift`: XP-to-core phase state and overlay.
- `Collection/ArchiveCarouselState.swift`: center, expansion, transform, arrival.
- `Collection/ArchiveCarouselView.swift`: horizontal snapping and depth.
- `Collection/ArchiveCardView.swift`: rounded monochrome card.
- `Collection/ArchiveExpandedView.swift`: matched expansion and card faces.
- `Rewards/RewardStorePresentation.swift`: balance/error and stable submission UI state.
- `Profile/WeeklyStateTimeline.swift`: seven-day pure aggregation.

Xcode uses synchronized root groups, so new Swift files require no `project.pbxproj` edit.

---

### Task 1: Living OS metrics, score mapping, and motion profile

**Files:**
- Create: `LIVELVL/LIVELVL/DesignSystem/LivingOSTheme.swift`
- Create: `LIVELVL/LIVELVL/DesignSystem/LivingOSMotion.swift`
- Modify: `LIVELVL/LIVELVL/Today/TodayVisualTheme.swift:1-18`
- Test: `LIVELVL/LIVELVLTests/LivingOSDesignSystemTests.swift`

**Interfaces:**
- Produces `LivingOSTheme`, `LivingOSMetrics`, `LifeStateDisplayScale.percentage(from:)`, and `LivingOSMotionProfile.resolved(reduceMotion:)`.
- `TodayVisualTheme` temporarily aliases new values while pages migrate.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
@testable import LIVELVL

struct LivingOSDesignSystemTests {
    @Test func referenceMetricsMatchApprovedPreview() {
        #expect(LivingOSMetrics.pageHorizontalInset == 24)
        #expect(LivingOSMetrics.coreCornerRadius == 26)
        #expect(LivingOSMetrics.archiveCardCornerRadius == 28)
        #expect(LivingOSMetrics.coreWidthFraction == 0.34)
    }

    @Test func scoreDisplayUsesHundredPointsWithoutChangingDomainValues() {
        #expect(LifeStateDisplayScale.percentage(from: 0) == 0)
        #expect(LifeStateDisplayScale.percentage(from: 7.84) == 78)
        #expect(LifeStateDisplayScale.percentage(from: 10) == 100)
        #expect(LifeStateDisplayScale.percentage(from: 12) == 100)
    }

    @Test func reduceMotionRemovesSpatialEffectsButKeepsStateFade() {
        let normal = LivingOSMotionProfile.resolved(reduceMotion: false)
        let reduced = LivingOSMotionProfile.resolved(reduceMotion: true)
        #expect(normal.allowsParticles && normal.allowsDepthTilt)
        #expect(!reduced.allowsParticles && !reduced.allowsDepthTilt)
        #expect(reduced.stateFadeDuration > 0)
    }
}
```

- [ ] **Step 2: Verify correct failure**

Run:

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug -destination 'platform=iOS Simulator,id=CDEFD7CB-0175-4A46-BC1E-12BD8E9B37D9' -only-testing:LIVELVLTests/LivingOSDesignSystemTests
```

Expected: FAIL because the new types do not exist.

- [ ] **Step 3: Implement minimal values**

```swift
import SwiftUI

enum LivingOSTheme {
    static let canvas = Color(red: 244.0 / 255.0, green: 245.0 / 255.0, blue: 246.0 / 255.0)
    static let surface = Color(red: 248.0 / 255.0, green: 249.0 / 255.0, blue: 250.0 / 255.0)
    static let ink = Color(red: 11.0 / 255.0, green: 12.0 / 255.0, blue: 13.0 / 255.0)
    static let graphite = Color(red: 102.0 / 255.0, green: 106.0 / 255.0, blue: 112.0 / 255.0)
    static let mist = Color(red: 217.0 / 255.0, green: 220.0 / 255.0, blue: 225.0 / 255.0)
    static let signal = Color(red: 1, green: 59.0 / 255.0, blue: 48.0 / 255.0)
}

enum LivingOSMetrics {
    static let pageHorizontalInset: CGFloat = 24
    static let coreCornerRadius: CGFloat = 26
    static let archiveCardCornerRadius: CGFloat = 28
    static let coreWidthFraction: CGFloat = 0.34
}

enum LifeStateDisplayScale {
    static func percentage(from score: Double) -> Int {
        Int((min(10, max(0, score)) * 10).rounded())
    }
}
```

`LivingOSMotionProfile` contains `allowsParticles`, `allowsDepthTilt`, `stateFadeDuration`, and `snapDuration`; normal resolves to `true/true/0.2/0.34`, reduced resolves to `false/false/0.2/0.2`.

- [ ] **Step 4: Run focused and full tests**

Expected: focused PASS; full suite has at least 118 tests and zero failures.

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/DesignSystem LIVELVL/LIVELVL/Today/TodayVisualTheme.swift LIVELVL/LIVELVLTests/LivingOSDesignSystemTests.swift && git commit -m "feat: add Living OS design tokens"
```

---

### Task 2: Deterministic dot geometry and Canvas renderer

**Files:**
- Create: `LIVELVL/LIVELVL/DesignSystem/LivingOSDotField.swift`
- Test: `LIVELVL/LIVELVLTests/LivingOSDotFieldTests.swift`

**Interfaces:**
- Consumes Living OS colors and motion.
- Produces `LivingDotSample`, `LivingDotFieldGeometry.samples(columns:rows:phase:reduceMotion:)`, and `LivingDotField`.

- [ ] **Step 1: Write failing deterministic tests**

```swift
import Testing
@testable import LIVELVL

struct LivingOSDotFieldTests {
    @Test func samplesAreStableNormalizedAndBounded() {
        let a = LivingDotFieldGeometry.samples(columns: 4, rows: 3, phase: 0.25, reduceMotion: false)
        let b = LivingDotFieldGeometry.samples(columns: 4, rows: 3, phase: 0.25, reduceMotion: false)
        #expect(a == b)
        #expect(a.count == 12)
        #expect(a.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
        #expect(a.allSatisfy { (0...1).contains($0.opacity) && $0.diameter > 0 })
    }

    @Test func reducedMotionFreezesPhase() {
        let a = LivingDotFieldGeometry.samples(columns: 5, rows: 5, phase: 0, reduceMotion: true)
        let b = LivingDotFieldGeometry.samples(columns: 5, rows: 5, phase: 0.9, reduceMotion: true)
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Run and verify missing-type failure**

- [ ] **Step 3: Implement samples and one Canvas**

```swift
struct LivingDotSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

enum LivingDotFieldGeometry {
    static func samples(columns: Int, rows: Int, phase: Double, reduceMotion: Bool) -> [LivingDotSample] {
        guard columns > 0, rows > 0 else { return [] }
        let p = reduceMotion ? 0.18 : phase.truncatingRemainder(dividingBy: 1)
        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                let x = columns == 1 ? 0.5 : Double(column) / Double(columns - 1)
                let y = rows == 1 ? 0.5 : Double(row) / Double(rows - 1)
                let wave = (sin((x + y + p) * .pi * 2) + 1) / 2
                return LivingDotSample(position: CGPoint(x: x, y: y), opacity: 0.08 + wave * 0.22, diameter: 1 + wave * 0.8)
            }
        }
    }
}
```

`LivingDotField` uses one `Canvas`; normalized points scale into its size. Use `TimelineView(.animation)` only for normal motion and freeze at phase `0.18` for Reduce Motion.

- [ ] **Step 4: Run focused tests and build standard/reduced previews**

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/DesignSystem/LivingOSDotField.swift LIVELVL/LIVELVLTests/LivingOSDotFieldTests.swift && git commit -m "feat: add deterministic Living OS dot fields"
```

---

### Task 3: Editorial header and real system tab shell

**Files:**
- Create: `LIVELVL/LIVELVL/DesignSystem/LivingOSPageHeader.swift`
- Modify: `LIVELVL/LIVELVL/MainTabView.swift:1-18,368-420,510-526`
- Modify test: `LIVELVL/LIVELVLTests/UIPolishLayoutTests.swift`
- Regression: `LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift`

**Interfaces:**
- Produces `AppTab.title`, `AppTab.systemImageName`, and `LivingOSPageHeader`.
- Preserves `CollectionTabIdentity`, `CollectionTabTargetResolver`, and `CollectionTabFeedbackBridge`.

- [ ] **Step 1: Add failing tab assertions**

```swift
@Test func livingOSTabsKeepStableCopyAndCollectionIdentity() {
    #expect(AppTab.today.title == "今天")
    #expect(AppTab.collection.title == "收集")
    #expect(AppTab.rewards.title == "奖励")
    #expect(AppTab.profile.title == "我的")
    #expect(AppTab.collection.systemImageName == CollectionTabIdentity.systemImageName)
    #expect(LivingOSMetrics.pageTitleSize == 56)
}
```

- [ ] **Step 2: Run `UIPolishLayoutTests` and verify missing metadata failure**

- [ ] **Step 3: Implement metadata and header**

```swift
extension AppTab {
    var title: String {
        switch self { case .today: "今天"; case .collection: "收集"; case .rewards: "奖励"; case .profile: "我的" }
    }
    var systemImageName: String {
        switch self { case .today: "sun.max"; case .collection: CollectionTabIdentity.systemImageName; case .rewards: "gift"; case .profile: "person" }
    }
}
```

Add `pageTitleSize = 56`. `LivingOSPageHeader` takes `eyebrow`, `title`, `metadata`, and a trailing ViewBuilder. It has no card background. Continue using real `.tabItem` labels and never hide the UIKit tab bar.

- [ ] **Step 4: Run layout and coordinate tests**

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Debug -destination 'platform=iOS Simulator,id=CDEFD7CB-0175-4A46-BC1E-12BD8E9B37D9' -only-testing:LIVELVLTests/UIPolishLayoutTests -only-testing:LIVELVLTests/CardRewardPresentationTests
```

Expected: stable identity, slot fallback, RTL, measured target, and overlay-center flight tests all pass.

- [ ] **Step 5: Build and confirm Collection is still the second real tab item**

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/DesignSystem/LivingOSPageHeader.swift LIVELVL/LIVELVL/MainTabView.swift LIVELVL/LIVELVLTests/UIPolishLayoutTests.swift && git commit -m "feat: restyle the Living OS app shell"
```

---

### Task 4: Six-dimension Today field and node interaction

**Files:**
- Create: `LIVELVL/LIVELVL/Today/LifeFieldPresentation.swift`
- Create: `LIVELVL/LIVELVL/Today/LifeFieldView.swift`
- Test: `LIVELVL/LIVELVLTests/LifeFieldPresentationTests.swift`

**Interfaces:**
- Consumes `LifeStateSummary`, `LifeDimension.allCases`, score display scale, and `LivingDotField`.
- Produces `LifeFieldNodePresentation`, `LifeFieldSelectionState`, and `LifeFieldView`.

- [ ] **Step 1: Write failing mapping and selection tests**

```swift
import Testing
@testable import LIVELVL

struct LifeFieldPresentationTests {
    @Test func nodesUseTheSixRealDomainsInStableOrder() {
        let values = LifeStateValues(health: 7.8, learning: 8.6, career: 8.3, finance: 6.4, relationships: 7.9, interests: 8.0)
        let nodes = LifeFieldNodePresentation.make(official: values, projected: values)
        #expect(nodes.map(\.dimension) == LifeDimension.allCases)
        #expect(nodes.map(\.title) == ["健康", "学习", "事业", "财务", "关系", "兴趣"])
        #expect(nodes.map(\.displayValue) == [78, 86, 83, 64, 79, 80])
    }

    @Test func tappingTheSameNodeClosesDetail() {
        var state = LifeFieldSelectionState()
        state.toggle(.health)
        #expect(state.selectedDimension == .health)
        state.toggle(.health)
        #expect(state.selectedDimension == nil)
    }

    @Test func staleSelectionClears() {
        var state = LifeFieldSelectionState(selectedDimension: .finance)
        state.reconcile(available: [.health, .learning])
        #expect(state.selectedDimension == nil)
    }
}
```

- [ ] **Step 2: Verify missing-type failure**

- [ ] **Step 3: Implement pure presentation types**

```swift
struct LifeFieldNodePresentation: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }
    let dimension: LifeDimension
    let title: String
    let displayValue: Int
    let projectedDisplayValue: Int
    let delta: Int

    static func make(official: LifeStateValues, projected: LifeStateValues) -> [Self] {
        LifeDimension.allCases.map { dimension in
            let current = LifeStateDisplayScale.percentage(from: official[dimension])
            let future = LifeStateDisplayScale.percentage(from: projected[dimension])
            return Self(dimension: dimension, title: dimension.title, displayValue: current, projectedDisplayValue: future, delta: future - current)
        }
    }
}

struct LifeFieldSelectionState: Equatable, Sendable {
    private(set) var selectedDimension: LifeDimension?
    init(selectedDimension: LifeDimension? = nil) { self.selectedDimension = selectedDimension }
    mutating func toggle(_ value: LifeDimension) { selectedDimension = selectedDimension == value ? nil : value }
    mutating func clear() { selectedDimension = nil }
    mutating func reconcile(available: Set<LifeDimension>) {
        if let selectedDimension, !available.contains(selectedDimension) { self.selectedDimension = nil }
    }
}
```

`LifeFieldView` places exactly six black nodes around the center, draws one low-contrast point field, and adds a hairline ring plus tiny signal only to the selection. Its compact in-field detail contains current value, projected change, source task, and assessment timing; no sheet or modal.

- [ ] **Step 4: Run tests, standard preview, and Accessibility 2 preview**

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/Today/LifeFieldPresentation.swift LIVELVL/LIVELVL/Today/LifeFieldView.swift LIVELVL/LIVELVLTests/LifeFieldPresentationTests.swift && git commit -m "feat: add the interactive six-dimension life field"
```

---

### Task 5: Rounded Life Core widget and typographic task rails

**Files:**
- Create: `LIVELVL/LIVELVL/Today/LifeCoreWidget.swift`
- Create: `LIVELVL/LIVELVL/Today/TaskRailView.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift:47-560`
- Modify: `LIVELVL/LIVELVL/Today/LevelCard.swift:1-420`
- Modify test: `LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift`
- Retain: `TodayCompanionMediaStateTests`, `AnimatedMediaDecoderTests`, `UserCardMediaStoreTests`

**Interfaces:**
- Consumes current companion definition/stage, `GrowthEngine`, `Item`, and existing media store/controller.
- Produces `LifeCoreWidgetPresentation`, `LifeCoreWidget`, and `TaskRailView`.

- [ ] **Step 1: Replace obsolete journal assertions with failing core assertions**

Do not delete the suite or active-companion accessibility test. Replace hand-font/composition assertions with:

```swift
@Test func lifeCoreUsesApprovedWidgetMetricsAndStableProgress() {
    let value = LifeCoreWidgetPresentation(
        definition: CollectionCatalog.ordinary[1], stage: .stageTwo,
        level: 2, currentXP: 80, requiredXP: 2_000, remainingXP: 1_920
    )
    #expect(value.cornerRadius == 26)
    #expect(value.progress == 0.04)
    #expect(value.levelText == "LV 2")
    #expect(value.remainingText == "下一形态 1920 XP")
}

@Test func mainCoreUsesCanonicalMonochromeArtwork() {
    #expect(!LifeCoreWidgetPresentation.showsMediaControlsOnMainSurface)
    #expect(LifeCoreWidgetPresentation.artworkStyle == .monochromePixel)
}
```

- [ ] **Step 2: Verify missing-presentation failure**

- [ ] **Step 3: Implement the presentation**

```swift
enum LifeCoreArtworkStyle: Equatable, Sendable { case monochromePixel }

struct LifeCoreWidgetPresentation: Equatable, Sendable {
    static let showsMediaControlsOnMainSurface = false
    static let artworkStyle: LifeCoreArtworkStyle = .monochromePixel
    let definition: CollectibleDefinition
    let stage: CompanionStage
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int
    var cornerRadius: CGFloat { LivingOSMetrics.coreCornerRadius }
    var progress: Double { requiredXP == 0 ? 0 : min(1, max(0, Double(currentXP) / Double(requiredXP))) }
    var levelText: String { "LV \(level)" }
    var remainingText: String { "下一形态 \(remainingXP) XP" }
}
```

`LifeCoreWidget` uses one 26 pt continuous rounded silver surface, clips canonical monochrome artwork, and places level/XP/progress/remaining text inside. Existing stored media is not deleted; media customization moves to secondary growth detail. `TaskRailView` keeps completion, title, dimension, XP, optional `+XP`, and a hairline; remove icon tiles, white rounded row backgrounds, and shadows.

- [ ] **Step 4: Recompose Today while preserving domain methods**

Use `LivingOSPageHeader(title: "Today")`, `LifeFieldView`, centered `LifeCoreWidget`, and task rails. Keep `toggle`, `confirmCompletion`, `retryRewardProcessing`, and `ensureProgress` service calls intact. Put add-task in the task section header as a 44×44 control.

- [ ] **Step 5: Run Today, media, task, coin, and summary suites plus full Debug**

- [ ] **Step 6: Compare Today on iPhone 17 Pro with `today-final.png`**

Check 26 pt corners, ~34% core width, six real dimensions, task hairlines, no handwriting/teal, and Accessibility 2.

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Today/LifeCoreWidget.swift LIVELVL/LIVELVL/Today/TaskRailView.swift LIVELVL/LIVELVL/Today/LevelCard.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVLTests/TodayCompanionLevelCardTests.swift && git commit -m "feat: rebuild Today around the Life Core"
```

---

### Task 6: XP-to-core phase state and particle flow

**Files:**
- Create: `LIVELVL/LIVELVL/Today/TodayGrowthPresentation.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift` feedback state and `.task(id:)`
- Modify test: `LIVELVL/LIVELVLTests/TaskRewardFeedbackTests.swift`
- Regression: `LIVELVL/LIVELVLTests/CardRewardServiceTests.swift`

**Interfaces:**
- Consumes `TaskRewardFeedback` only after existing completion, coin, and collection processing succeeds.
- Produces `TodayGrowthPresentationState`, `TodayGrowthPhase`, and `XPFlowOverlay`.

- [ ] **Step 1: Add failing phase and cancellation tests**

```swift
@Test func growthMovesFromTaskThroughDimensionIntoCoreAndLevelUp() {
    let feedback = TaskRewardFeedback(itemID: UUID(), xp: 20, dimension: .health, levelBefore: 1, levelAfter: 2)
    var state = TodayGrowthPresentationState()
    state.begin(feedback)
    #expect(state.phase == .task(feedback.id))
    state.advance(); #expect(state.phase == .dimension(.health))
    state.advance(); #expect(state.phase == .core)
    state.advance(); #expect(state.phase == .levelUp(2))
    state.finish(); #expect(state.phase == .idle)
}

@Test func revokeOrFailureCancelsPresentation() {
    var state = TodayGrowthPresentationState()
    state.begin(TaskRewardFeedback(itemID: UUID(), xp: 10, dimension: .learning, levelBefore: 1, levelAfter: 1))
    state.cancel()
    #expect(state.phase == .idle)
    #expect(state.feedback == nil)
}
```

- [ ] **Step 2: Verify missing-state failure**

- [ ] **Step 3: Implement the finite state**

```swift
enum TodayGrowthPhase: Equatable, Sendable {
    case idle
    case task(UUID)
    case dimension(LifeDimension)
    case core
    case levelUp(Int)
}

struct TodayGrowthPresentationState: Equatable, Sendable {
    private(set) var phase: TodayGrowthPhase = .idle
    private(set) var feedback: TaskRewardFeedback?
    mutating func begin(_ value: TaskRewardFeedback) { feedback = value; phase = .task(value.id) }
    mutating func advance() {
        guard let feedback else { phase = .idle; return }
        switch phase {
        case .task: phase = .dimension(feedback.dimension)
        case .dimension: phase = .core
        case .core: phase = feedback.didLevelUp ? .levelUp(feedback.levelAfter) : .idle
        case .levelUp: phase = .idle
        case .idle: break
        }
    }
    mutating func finish() { phase = .idle; feedback = nil }
    mutating func cancel() { finish() }
}
```

`XPFlowOverlay` uses at most 18 Canvas samples from task anchor through dimension to core. Reduce Motion skips the path and cross-fades values. Drive advances with one cancellable task. Cancel on revoke, save failure, collection-processing failure, scene background, or disappearance. Never move domain calls into the renderer.

- [ ] **Step 4: Run phase, task/coin, reward queue, and full tests**

- [ ] **Step 5: Simulator-check normal completion, level-up, failure, and Reduce Motion**

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/Today/TodayGrowthPresentation.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVLTests/TaskRewardFeedbackTests.swift && git commit -m "feat: animate XP into the Life Core"
```

---

### Task 7: Archive carousel state, depth math, and centered seen semantics

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift`
- Modify: `LIVELVL/LIVELVL/Collection/CollectionView.swift:1-104`
- Modify test: `LIVELVL/LIVELVLTests/CollectionViewStateTests.swift`

**Interfaces:**
- Produces `ArchiveCarouselState` and `ArchiveCardTransform`.
- Changes `CollectionSeenVisibilityState` from visible-set semantics to one centered key.

- [ ] **Step 1: Add failing center, transform, and seen tests**

```swift
@Test func carouselKeepsCenterSeparateFromExpansion() {
    var state = ArchiveCarouselState()
    state.reconcile(orderedAwardKeys: ["new", "old"])
    #expect(state.centeredAwardKey == "new")
    state.center("old")
    state.expandCentered()
    #expect(state.centeredAwardKey == "old")
    #expect(state.expandedAwardKey == "old")
    state.closeExpanded()
    #expect(state.centeredAwardKey == "old")
    #expect(state.expandedAwardKey == nil)
}

@Test func onlyCenteredUnobscuredCardBecomesSeen() {
    var visibility = CollectionSeenVisibilityState()
    visibility.center("center")
    let result = visibility.awardKeysToMarkSeen(
        unseenAwardKeys: ["left", "center", "right"],
        isCollectionSelected: true,
        isObscured: false
    )
    #expect(result == ["center"])
}

@Test func depthIsRestrainedAndReducedMotionIsFlat() {
    let normal = ArchiveCardTransform.make(normalizedDistance: 1, reduceMotion: false)
    #expect(normal.scale == 0.88)
    #expect(abs(normal.rotationDegrees) <= 3)
    let reduced = ArchiveCardTransform.make(normalizedDistance: 1, reduceMotion: true)
    #expect(reduced.rotationDegrees == 0)
}
```

- [ ] **Step 2: Verify failure comes from the missing carousel API**

- [ ] **Step 3: Implement state and transform**

```swift
struct ArchiveCardTransform: Equatable, Sendable {
    let scale: CGFloat
    let opacity: Double
    let rotationDegrees: Double
    static func make(normalizedDistance: CGFloat, reduceMotion: Bool) -> Self {
        let distance = min(1, abs(normalizedDistance))
        return Self(
            scale: 1 - 0.12 * distance,
            opacity: 1 - 0.45 * Double(distance),
            rotationDegrees: reduceMotion ? 0 : Double(max(-1, min(1, normalizedDistance))) * -3
        )
    }
}

struct ArchiveCarouselState: Equatable, Sendable {
    private(set) var centeredAwardKey: String?
    private(set) var expandedAwardKey: String?
    private(set) var isShowingBack = false
    mutating func reconcile(orderedAwardKeys: [String]) {
        if let centeredAwardKey {
            if !orderedAwardKeys.contains(centeredAwardKey) {
                self.centeredAwardKey = orderedAwardKeys.first
            }
        } else {
            centeredAwardKey = orderedAwardKeys.first
        }
        if let expandedAwardKey, !orderedAwardKeys.contains(expandedAwardKey) {
            self.expandedAwardKey = nil
            isShowingBack = false
        }
    }
    mutating func center(_ key: String) { centeredAwardKey = key }
    mutating func expandCentered() { expandedAwardKey = centeredAwardKey; isShowingBack = false }
    mutating func setShowingBack(_ value: Bool) { isShowingBack = value }
    mutating func closeExpanded() { expandedAwardKey = nil; isShowingBack = false }
}
```

- [ ] **Step 4: Run Collection state, seen persistence, and full tests**

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift LIVELVL/LIVELVL/Collection/CollectionView.swift LIVELVL/LIVELVLTests/CollectionViewStateTests.swift && git commit -m "feat: model Archive carousel interaction"
```

---

### Task 8: Archive carousel, rounded pixel cards, and continuous expansion

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/ArchiveCarouselView.swift`
- Create: `LIVELVL/LIVELVL/Collection/ArchiveCardView.swift`
- Create: `LIVELVL/LIVELVL/Collection/ArchiveExpandedView.swift`
- Modify: `LIVELVL/LIVELVL/Collection/CollectionView.swift:105-430`
- Modify: `LIVELVL/LIVELVL/Collection/CollectibleCardView.swift:1-360`
- Retain: `LIVELVL/LIVELVL/Collection/CatalogView.swift`

**Interfaces:**
- Consumes carousel state, `OwnedCollectible`, `CollectibleDefinition`, `PixelSpeciesArtwork`, and stable `awardKey`.
- Produces native view-aligned horizontal scrolling and matched-geometry expansion.

- [ ] **Step 1: Add failing accessibility and metadata tests**

```swift
@Test func archiveAccessibilityDescribesPositionAndNewState() {
    let value = ArchiveCardAccessibility.value(name: "小芽", index: 1, count: 3, isUnseen: true)
    #expect(value == "小芽，第 1 张，共 3 张，新收藏")
}

@Test func archiveMetadataUsesPersistedKinds() {
    #expect(ArchiveCardMetadata.kindTitle(for: .ordinaryMature) == "成熟卡")
    #expect(ArchiveCardMetadata.kindTitle(for: .hidden) == "隐藏发现")
}
```

- [ ] **Step 2: Verify missing-helper failure**

- [ ] **Step 3: Build card and native carousel**

Use `ScrollView(.horizontal)`, `LazyHStack`, `.scrollTargetLayout()`, `.scrollPosition(id:)`, and `.scrollTargetBehavior(.viewAligned)`. Clamp central card width to 52–58% of available width and reveal neighbors with content margins. Feed geometry-derived center distance into `ArchiveCardTransform`. Do not add a competing manual DragGesture unless native scrolling fails a documented simulator case.

`ArchiveCardView` uses a 28 pt continuous silver surface, canonical monochrome artwork, and optional tiny signal. It exposes adjustable previous/next actions and no trading-card ornament.

- [ ] **Step 4: Replace featured-plus-grid main page**

Keep the `CollectionView` public type. Compose `LivingOSPageHeader(title: "Archive", metadata: "owned / catalog")`, filter/catalog NavigationLink, carousel, selected metadata, retry rail, and the existing Catalog route. Empty state shows the active companion and “第一张卡正在成长”.

- [ ] **Step 5: Replace black modal with matched expansion**

Use one namespace and stable award key. `ArchiveExpandedView` retains front/back information and focus restoration. Normal motion flips; Reduce Motion cross-fades. Remove the dark overlay and expand over the Living OS canvas.

- [ ] **Step 6: Run Collection tests and simulator swipe acceptance**

Seed three cards and verify finger tracking, ≤3° tilt, one-card snap, no loop, stable center, close-to-origin focus, VoiceOver adjustable action, and Accessibility 2.

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Collection/ArchiveCarouselView.swift LIVELVL/LIVELVL/Collection/ArchiveCardView.swift LIVELVL/LIVELVL/Collection/ArchiveExpandedView.swift LIVELVL/LIVELVL/Collection/CollectionView.swift LIVELVL/LIVELVL/Collection/CollectibleCardView.swift LIVELVL/LIVELVLTests/CollectionViewStateTests.swift && git commit -m "feat: rebuild collection as the Archive carousel"
```

---

### Task 9: One-shot card landing after the protected tab flight

**Files:**
- Modify: `LIVELVL/LIVELVL/MainTabView.swift:311-488`
- Modify: `LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift`
- Modify: `LIVELVL/LIVELVL/Collection/CollectionView.swift`
- Modify test: `LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift`
- Modify test: `LIVELVL/LIVELVLTests/CollectionViewStateTests.swift`

**Interfaces:**
- Produces `ArchiveArrivalPresentationState.registerClaimed(awardKey:)`, `takeArrivalIfNeeded(validAwardKeys:)`, and `markCompleted(awardKey:)`.
- MainTab passes a presentation-only arrival key; `CardRewardOverlay` geometry stays unchanged.

- [ ] **Step 1: Add failing one-shot and sequencing tests**

```swift
@Test func claimedCardLandsAtMostOncePerPresentationSession() {
    var state = ArchiveArrivalPresentationState()
    state.registerClaimed(awardKey: "ordinary.level.4")
    #expect(state.takeArrivalIfNeeded(validAwardKeys: ["ordinary.level.4"]) == "ordinary.level.4")
    state.markCompleted(awardKey: "ordinary.level.4")
    #expect(state.takeArrivalIfNeeded(validAwardKeys: ["ordinary.level.4"]) == nil)
}

@Test func arrivalWaitsForOwnedRow() {
    var state = ArchiveArrivalPresentationState()
    state.registerClaimed(awardKey: "hidden.study")
    #expect(state.takeArrivalIfNeeded(validAwardKeys: []) == nil)
    #expect(state.takeArrivalIfNeeded(validAwardKeys: ["hidden.study"]) == "hidden.study")
}
```

Add a CardReward assertion that successful feedback exposes the matching award key before clearing; stale and duplicate tokens expose none.

- [ ] **Step 2: Verify failure without touching flight production code**

- [ ] **Step 3: Implement presentation handoff**

Add the concrete one-shot state in `ArchiveCarouselState.swift`:

```swift
struct ArchiveArrivalPresentationState: Equatable, Sendable {
    private var pendingAwardKey: String?
    private var completedAwardKeys: Set<String> = []

    mutating func registerClaimed(awardKey: String) {
        guard !completedAwardKeys.contains(awardKey) else { return }
        pendingAwardKey = awardKey
    }

    mutating func takeArrivalIfNeeded(validAwardKeys: Set<String>) -> String? {
        guard let pendingAwardKey,
              validAwardKeys.contains(pendingAwardKey),
              !completedAwardKeys.contains(pendingAwardKey) else { return nil }
        return pendingAwardKey
    }

    mutating func markCompleted(awardKey: String) {
        completedAwardKeys.insert(awardKey)
        if pendingAwardKey == awardKey { pendingAwardKey = nil }
    }
}
```

Change `finishSuccessfulClaim(feedbackToken:)` to return the completed `awardKey?` while preserving guards. MainTab registers that key after UIKit feedback completes and records dismissal at the same point. Archive scrolls to the persisted key, draws a short bottom-to-card trace, settles, and marks presentation complete. Reduce Motion scrolls/fades with no trace. The landing never inserts, deletes, or claims a SwiftData record.

- [ ] **Step 4: Run all flight, queue, and Collection suites**

Expected: stable target identity, slot fallback, RTL, overlay-center, queue order, persistence, and offscreen-unseen tests remain green.

- [ ] **Step 5: Verify real coordinates on iPhone 17 Pro**

Trigger a card, tap “收下”, capture overlay center, mid-arc, zero-scale arrival at actual Collection center, UIKit pulse completion, unchanged current tab, then Archive landing. Reject flight toward Rewards or offscreen.

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/MainTabView.swift LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift LIVELVL/LIVELVL/Collection/CollectionView.swift LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift LIVELVL/LIVELVLTests/CollectionViewStateTests.swift && git commit -m "feat: land claimed cards in the Archive deck"
```

---

### Task 10: Typographic Rewards with optional user images and stable submission

**Files:**
- Create: `LIVELVL/LIVELVL/Rewards/RewardStorePresentation.swift`
- Modify: `LIVELVL/LIVELVL/Rewards/RewardStoreView.swift:1-520`
- Test: `LIVELVL/LIVELVLTests/RewardStorePresentationTests.swift`
- Keep unchanged: `CoinLedger.swift`, `RewardModels.swift`, `RewardStoreService.swift`, `TaskRewardCoordinator.swift`

**Interfaces:**
- Consumes immutable ledger balance and existing reward product/redemption services.
- Produces `RewardProductRailPresentation`, `RewardRedemptionSubmissionState`, and `RewardBalancePresentation`.

- [ ] **Step 1: Write failing no-icon and idempotent-submission tests**

```swift
import Foundation
import Testing
@testable import LIVELVL

struct RewardStorePresentationTests {
    @Test func unavailableBalanceNeverEnablesRedemption() {
        let balance = RewardBalancePresentation.unavailable
        #expect(balance.coinUnits == nil)
        #expect(!balance.allowsRedemption)
    }

    @Test func textOnlyProductReportsAffordabilityWithoutAnIcon() {
        let row = RewardProductRailPresentation(
            name: "看一场电影", priceCoinUnits: 180, note: "周末", imageReference: nil,
            balanceCoinUnits: 275, isArchived: false
        )
        #expect(!row.showsImage)
        #expect(row.canRedeem)
        #expect(row.statusText == "可兑换")
        #expect(row.fallbackSystemImageName == nil)
    }

    @Test func insufficientProductUsesTextState() {
        let row = RewardProductRailPresentation(
            name: "周末旅行", priceCoinUnits: 1_200, note: "", imageReference: nil,
            balanceCoinUnits: 275, isArchived: false
        )
        #expect(!row.canRedeem)
        #expect(row.statusText == "余额不足")
    }

    @Test func repeatConfirmationReusesOneSubmissionUntilFinish() throws {
        let productID = UUID()
        var state = RewardRedemptionSubmissionState()
        let first = try #require(state.begin(productID: productID))
        #expect(state.begin(productID: productID) == nil)
        #expect(state.requestKey == first)
        state.finish()
        #expect(!state.isSubmitting)
    }
}
```

- [ ] **Step 2: Verify missing-type failure**

- [ ] **Step 3: Implement row and submission state**

```swift
struct RewardProductRailPresentation: Equatable, Sendable {
    let name: String
    let priceCoinUnits: Int
    let note: String
    let imageReference: String?
    let balanceCoinUnits: Int
    let isArchived: Bool
    var showsImage: Bool { imageReference != nil }
    var canRedeem: Bool { !isArchived && balanceCoinUnits >= priceCoinUnits }
    var statusText: String { isArchived ? "已归档" : (canRedeem ? "可兑换" : "余额不足") }
    var fallbackSystemImageName: String? { nil }
}

enum RewardBalancePresentation: Equatable, Sendable {
    case available(Int)
    case unavailable

    var coinUnits: Int? {
        guard case let .available(value) = self else { return nil }
        return value
    }

    var allowsRedemption: Bool {
        if case .available = self { return true }
        return false
    }
}

struct RewardRedemptionSubmissionState: Equatable, Sendable {
    private(set) var productID: UUID?
    private(set) var requestKey: String?
    var isSubmitting: Bool { requestKey != nil }
    mutating func begin(productID: UUID) -> String? {
        guard requestKey == nil else { return nil }
        let key = UUID().uuidString
        self.productID = productID; requestKey = key
        return key
    }
    mutating func finish() { productID = nil; requestKey = nil }
}
```

- [ ] **Step 4: Rebuild page around real ledger data**

Use `LivingOSPageHeader(title: "Rewards")`, history/plus, large one-decimal balance, one horizontal point ledger, pending count, and hairline reward rails. Render `RewardProductImageView` only when `imageReference != nil`; remove gift fallback. Keep PhotosPicker as `添加图片/替换图片` and keep local image storage unchanged.

Catch balance errors into unavailable UI rather than treating errors as zero for redemption. Confirmation includes name, cost, and post-balance. Disable while submission is active, pass its stable key to `RewardStoreService.redeem`, and finish state in every success/error path.

- [ ] **Step 5: Run presentation, coin, model, service, coordinator, and reset suites**

- [ ] **Step 6: Simulator-check create/edit/archive, insufficient/success/repeat, history, image replacement, relaunch**

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Rewards/RewardStorePresentation.swift LIVELVL/LIVELVL/Rewards/RewardStoreView.swift LIVELVL/LIVELVLTests/RewardStorePresentationTests.swift && git commit -m "feat: rebuild Rewards as a typographic ledger"
```

---

### Task 11: You page and deterministic weekly timeline

**Files:**
- Create: `LIVELVL/LIVELVL/Profile/WeeklyStateTimeline.swift`
- Modify: `LIVELVL/LIVELVL/Profile/ProfileView.swift:1-180`
- Test: `LIVELVL/LIVELVLTests/WeeklyStateTimelineTests.swift`
- Regression: `AssessmentSettlementTests`, `LifeStateSummaryTests`, `LocalDataResetServiceTests`

**Interfaces:**
- Consumes `Progress`, `Completion`, latest state snapshot, profiles, and `LifeStateSummaryBuilder`.
- Produces `WeeklyStateDay` and `WeeklyStateTimelineBuilder.build(completions:weekContaining:calendar:)`.

- [ ] **Step 1: Write failing seven-day aggregation test**

```swift
import Foundation
import Testing
@testable import LIVELVL

struct WeeklyStateTimelineTests {
    @Test func timelineReturnsSevenOrderedDaysAndAggregatesXP() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 12)))
        let monday = try #require(calendar.dateInterval(of: .weekOfYear, for: now)?.start)
        let completion = Completion(itemID: UUID(), xp: 20, dimension: .health, taskTitle: "跑步", date: monday)
        let days = WeeklyStateTimelineBuilder.build(completions: [completion], weekContaining: now, calendar: calendar)
        #expect(days.count == 7)
        #expect(days.map(\.date) == days.map(\.date).sorted())
        #expect(days.first?.completedCount == 1)
        #expect(days.first?.xp == 20)
    }
}
```

- [ ] **Step 2: Verify missing-builder failure**

- [ ] **Step 3: Implement calendar-safe aggregation**

```swift
struct WeeklyStateDay: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let completedCount: Int
    let xp: Int
}

enum WeeklyStateTimelineBuilder {
    static func build(completions: [Completion], weekContaining date: Date, calendar: Calendar) -> [WeeklyStateDay] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let interval = calendar.dateInterval(of: .day, for: day) else { return nil }
            let matching = completions.filter { interval.contains($0.date) }
            return WeeklyStateDay(date: day, completedCount: matching.count, xp: matching.reduce(0) { $0 + $1.xp })
        }
    }
}
```

- [ ] **Step 4: Rebuild Profile as You without breaking Debug injection**

Keep the `ProfileView` type, Debug initializer, two alerts, failure callback, and reset action trigger. Query progress, completions, profiles, and snapshots. Render `LIVELVL`, `YOU / LEVEL n`, `You`, hundred-point overall state, six real dimensions, seven-day timeline, and hairline rows `每周评估 / 数据与隐私 / 设置`. Weekly assessment opens existing `StateAssessmentView(mode: .weekly)`. Debug reset moves under Settings/developer and remains Debug-only.

- [ ] **Step 5: Run timeline, assessment, summary, and reset tests**

- [ ] **Step 6: Inspect You on simulator**

Verify no hard-coded `FY`, no account/avatar implication, current-day signal, empty days, Accessibility 2, VoiceOver order, and Debug reset.

- [ ] **Step 7: Commit**

```bash
git add LIVELVL/LIVELVL/Profile/WeeklyStateTimeline.swift LIVELVL/LIVELVL/Profile/ProfileView.swift LIVELVL/LIVELVLTests/WeeklyStateTimelineTests.swift && git commit -m "feat: rebuild profile as the You status system"
```

---

### Task 12: Accessibility, Reduce Motion, performance, and obsolete-style audit

**Files:**
- Modify only new Living OS views with a proven audit failure.
- Modify tests: `LivingOSDesignSystemTests.swift`, `LivingOSDotFieldTests.swift`, `CollectionViewStateTests.swift`, `RewardStorePresentationTests.swift`, `UIPolishLayoutTests.swift`.
- Retain all decoder/media files and tests.

**Interfaces:**
- Produces no business API; closes cross-cutting acceptance gaps.

- [ ] **Step 1: Add failing accessibility-value tests**

Add exact model assertions: Today core includes companion/stage/level/XP; life node includes current/projected/source; Archive includes index/count/new/source; Rewards includes price/affordability/status; You day includes date/completion count/XP. Add one assertion proving every spatial presentation model returns zero tilt and no particles under Reduce Motion.

- [ ] **Step 2: Confirm failures are missing labels or motion gates**

- [ ] **Step 3: Implement labels, actions, focus, and gates**

Every target is at least 44×44 pt. Archive exposes adjustable previous/next and restores focus after closing detail. Life nodes announce detail. Reward images are described through product context only when present. A red signal dot is hidden from accessibility only if adjacent text/value already communicates the state.

- [ ] **Step 4: Run obsolete-style source audit**

```bash
rg -n "LongCang|MaShan|CompanionJournal|TodayVisualTheme\.reward|0\.04, green: 0\.65" LIVELVL/LIVELVL --glob '*.swift'
```

Expected: no active main-page use of hand typography, journal composition, or teal. Compatibility/media code may remain only off the primary surface and must retain tests.

- [ ] **Step 5: Audit performance**

Verify one Canvas per field/overlay, no point-level `ForEach`, stable carousel IDs, lazy neighboring cards, no per-frame catalog parsing, and paused timelines offscreen/inactive. If any motion visibly drops frames, invoke `superpowers:systematic-debugging` before `swiftui-performance-audit` or ETTrace.

- [ ] **Step 6: Inspect Dynamic Type, VoiceOver, and Reduce Motion**

On iPhone 17 Pro inspect standard, Accessibility 2, VoiceOver focus/actions, and Reduce Motion on all four pages plus expanded Archive.

- [ ] **Step 7: Run full Debug tests and commit only proven audit fixes**

Before staging, inspect changed names and stage only the explicit source/test paths that failed the audit; exclude project/user state.

```bash
git diff --name-only
git add LIVELVL/LIVELVL/DesignSystem/LivingOSTheme.swift LIVELVL/LIVELVL/DesignSystem/LivingOSMotion.swift LIVELVL/LIVELVL/DesignSystem/LivingOSDotField.swift
git add LIVELVL/LIVELVL/Today/LifeFieldView.swift LIVELVL/LIVELVL/Today/LifeCoreWidget.swift LIVELVL/LIVELVL/Today/TaskRailView.swift LIVELVL/LIVELVL/Today/TodayGrowthPresentation.swift
git add LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift LIVELVL/LIVELVL/Collection/ArchiveCarouselView.swift LIVELVL/LIVELVL/Collection/ArchiveCardView.swift LIVELVL/LIVELVL/Collection/ArchiveExpandedView.swift
git add LIVELVL/LIVELVL/Rewards/RewardStorePresentation.swift LIVELVL/LIVELVL/Rewards/RewardStoreView.swift LIVELVL/LIVELVL/Profile/WeeklyStateTimeline.swift LIVELVL/LIVELVL/Profile/ProfileView.swift
git add LIVELVL/LIVELVLTests/LivingOSDesignSystemTests.swift LIVELVL/LIVELVLTests/LivingOSDotFieldTests.swift LIVELVL/LIVELVLTests/CollectionViewStateTests.swift LIVELVL/LIVELVLTests/RewardStorePresentationTests.swift LIVELVL/LIVELVLTests/UIPolishLayoutTests.swift
git diff --cached --name-only
git commit -m "fix: complete Living OS accessibility and motion audit"
```

---

### Task 13: Final regression, Release build, and simulator proof

**Files:**
- Modify only source/test files required by a reproduced defect and its regression test.
- Keep screenshots outside the target unless repository retention is explicitly needed.

**Interfaces:**
- Verifies the complete spec and produces handoff evidence.

- [ ] **Step 1: Run complete Debug tests from a clean process**

Run the authoritative command. Expected: zero failures and no decrease from the new total established by Tasks 1–12.

- [ ] **Step 2: Build Release**

```bash
xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -configuration Release -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`; Release has no Debug reset entry.

- [ ] **Step 3: Execute complete iPhone 17 Pro scenario**

Verify, in order: assessment if needed; task creation; completion; correct node response; XP core flow; revoke; level-up morph; node detail; collection queue; real-coordinate claim flight; Archive landing; carousel previous/next; expand/front/back/close; reward create/edit/archive; insufficient balance; success; repeated tap; pending→fulfilled; image add/replace; force quit/relaunch persistence; Debug reset.

- [ ] **Step 4: Verify accessibility variants**

Repeat representative actions with Accessibility 2, VoiceOver, and Reduce Motion. Business results must match normal motion.

- [ ] **Step 5: Compare with all reference assets**

Use `docs/design-assets/living-os-v1/README.md`. Compare hierarchy, major proportions, 26/28 pt continuous corners, silver/black/white palette, restrained red signal, no stock reward icons, real pixel cards, and all four Archive motion states. Do not use cross-device raw pixel diff.

- [ ] **Step 6: Debug every discrepancy before completion**

For any test failure, visual defect, coordinate error, duplicate transaction, stale state, or warning with runtime impact: invoke `superpowers:systematic-debugging`, reproduce, identify root cause, add a regression test, fix, and rerun focused + full tests + simulator acceptance.

- [ ] **Step 7: Audit repository state**

```bash
git status --short --branch
git diff --check
git log --oneline 4fee021..HEAD
git diff --name-only 4fee021..HEAD
```

Expected: clean worktree, no `project.pbxproj`, `xcuserstate`, or `.tmp/`, small ordered commits, no push, no merge.

- [ ] **Step 8: Review and completion gate**

Invoke `superpowers:requesting-code-review`; handle findings with `superpowers:receiving-code-review`; rerun the completion audit; invoke `superpowers:verification-before-completion`. Mark the active goal complete only when every spec acceptance item has direct evidence.
