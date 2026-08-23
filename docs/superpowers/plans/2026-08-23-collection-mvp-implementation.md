# LIVELVL Collection MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete first collection loop: Lv.0 companion growth, ordinary maturity rewards, automatic hidden discoveries, a persistent claim queue, collection/catalog UI, and a Debug-only reset.

**Architecture:** Collectible content lives in a static catalog; SwiftData persists only progression, ownership, and pending rewards. Pure engines calculate progression and hidden achievements. A root-level presenter consumes pending rewards above the four-tab UI, while one service performs idempotent award creation and atomic claims.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, iOS 17+

**Spec:** `docs/superpowers/specs/2026-08-23-collection-mvp-design.md`

## Global Constraints

- Start `codex/collection-mvp` from the latest `main`; do not implement the reward store.
- Use `LIVELVL/LIVELVL.xcodeproj`; the project uses synchronized file groups.
- Keep white, black, and gray as persistent colors. Tiffany blue is transient feedback only.
- Ship 3 ordinary placeholder definitions and 2 hidden placeholder definitions.
- Collection progression uses historical highest level and never regresses after XP undo.
- Reaching maturity creates a pending reward; the next juvenile appears only after a successful claim.
- A pending reward survives relaunch, appears over any tab, and never forces tab selection.
- Respect Reduce Motion and VoiceOver; do not communicate locked state by color alone.
- Add no packages, networking, authentication, or cloud storage.
- Never stage `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`.

## File Map

- `LIVELVL/LIVELVL/Item.swift`: Lv.0 math and completion duration snapshots.
- `LIVELVL/LIVELVL/Collection/CollectibleDefinition.swift`: immutable catalog.
- `LIVELVL/LIVELVL/Collection/CompanionProgressionEngine.swift`: pure level timeline.
- `LIVELVL/LIVELVL/Collection/HiddenAchievementEngine.swift`: pure achievement rules.
- `LIVELVL/LIVELVL/Persistence/CollectionModels.swift`: progression, ownership, pending queue.
- `LIVELVL/LIVELVL/Collection/CardRewardService.swift`: idempotent trigger/claim mutations.
- `LIVELVL/LIVELVL/MainTabView.swift`: four tabs and root reward presenter.
- `LIVELVL/LIVELVL/Collection/CompanionCardView.swift`: today hero and placeholder art.
- `LIVELVL/LIVELVL/Collection/CardRewardOverlay.swift`: global claim UI.
- `LIVELVL/LIVELVL/Collection/CollectionView.swift`: featured card and two-column grid.
- `LIVELVL/LIVELVL/Collection/CollectibleCardView.swift`: small/enlarged/flipped card.
- `LIVELVL/LIVELVL/Collection/CatalogView.swift`: lit and silhouette atlas.
- `LIVELVL/LIVELVL/Rewards/RewardPlaceholderView.swift`: future-store placeholder.
- `LIVELVL/LIVELVL/Profile/ProfileView.swift`: profile and Debug reset UI.
- `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`: explicit local deletion.
- `LIVELVL/LIVELVL/ContentView.swift`: root gate and today task integration.
- `LIVELVL/LIVELVL/LIVELVLApp.swift`: SwiftData schema registration.

---

### Task 1: Introduce Lv.0

**Files:**
- Create: `LIVELVL/LIVELVLTests/GrowthEngineTests.swift`
- Modify: `LIVELVL/LIVELVL/Item.swift`

**Interfaces:**
- Produces: existing `GrowthEngine` APIs with Lv.0 semantics.
- Consumes: none.

- [ ] **Step 1: Write the failing boundary tests**

```swift
import Testing
@testable import LIVELVL

struct GrowthEngineTests {
    @Test func levelBoundaries() {
        #expect(GrowthEngine.level(for: 0) == 0)
        #expect(GrowthEngine.level(for: 199) == 0)
        #expect(GrowthEngine.level(for: 200) == 1)
        #expect(GrowthEngine.level(for: 2_199) == 1)
        #expect(GrowthEngine.level(for: 2_200) == 2)
        #expect(GrowthEngine.level(for: 4_200) == 3)
    }

    @Test func progressUsesTwoHundredThenTwoThousand() {
        #expect(GrowthEngine.xpInCurrentLevel(for: 100) == 100)
        #expect(GrowthEngine.xpNeededForNextLevel(for: 100) == 200)
        #expect(GrowthEngine.progressToNextLevel(for: 100) == 0.5)
        #expect(GrowthEngine.xpInCurrentLevel(for: 2_700) == 500)
        #expect(GrowthEngine.xpNeededForNextLevel(for: 2_700) == 2_000)
        #expect(GrowthEngine.progressToNextLevel(for: 2_700) == 0.25)
    }
}
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLCollectionTests CODE_SIGNING_ALLOWED=NO -only-testing:LIVELVLTests/GrowthEngineTests
```

Expected: FAIL because 0 XP currently reports Lv.1.

- [ ] **Step 3: Replace the level formulas**

```swift
static func level(for xp: Int) -> Int {
    let safeXP = max(0, xp)
    guard safeXP >= 200 else { return 0 }
    return 1 + (safeXP - 200) / 2_000
}

static func xpInCurrentLevel(for xp: Int) -> Int {
    let safeXP = max(0, xp)
    guard safeXP >= 200 else { return safeXP }
    return (safeXP - 200) % 2_000
}

static func xpNeededForNextLevel(for xp: Int) -> Int {
    level(for: xp) == 0 ? 200 : 2_000
}
```

Keep `progressToNextLevel` as the ratio of the latter two functions.

- [ ] **Step 4: Run focused and full tests**

Run the focused command, then the same command without `-only-testing`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/Item.swift LIVELVL/LIVELVLTests/GrowthEngineTests.swift
git commit -m "feat: start progression at level zero"
```

### Task 2: Add the Static Catalog and Pure Progression Timeline

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/CollectibleDefinition.swift`
- Create: `LIVELVL/LIVELVL/Collection/CompanionProgressionEngine.swift`
- Create: `LIVELVL/LIVELVLTests/CompanionProgressionEngineTests.swift`

**Interfaces:**
- Produces: `CollectibleKind`, `CompanionStage`, `CollectibleDefinition`, `CollectionCatalog`, `CompanionProgressionEvent`, `CompanionProgressionEngine.event(forReachedLevel:)`.
- Consumes: none.

- [ ] **Step 1: Write the exact timeline test**

```swift
import Testing
@testable import LIVELVL

struct CompanionProgressionEngineTests {
    @Test func approvedTimeline() {
        #expect(CompanionProgressionEngine.event(forReachedLevel: 0) == .active(index: 0, stage: .juvenile))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 1) == .matured(index: 0, nextIndex: 1, maturityLevel: 1))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 2) == .active(index: 1, stage: .stageTwo))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 3) == .active(index: 1, stage: .stageThree))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 4) == .matured(index: 1, nextIndex: 2, maturityLevel: 4))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 5) == .active(index: 2, stage: .stageTwo))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 6) == .active(index: 2, stage: .stageThree))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 7) == .matured(index: 2, nextIndex: 3, maturityLevel: 7))
    }
}
```

- [ ] **Step 2: Run it and confirm missing-type failures**

Use the Task 1 command with `-only-testing:LIVELVLTests/CompanionProgressionEngineTests`.

- [ ] **Step 3: Define focused catalog types**

```swift
enum CollectibleKind: String, Codable, Sendable { case ordinary, hidden }
enum CompanionStage: Int, Codable, CaseIterable, Sendable {
    case juvenile, stageTwo, stageThree, mature
}

struct CollectibleDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: CollectibleKind
    let ordinaryIndex: Int?
    let symbolName: String
    let silhouetteSymbolName: String
    let summary: String
    let details: String
    let hiddenRuleID: String?
}
```

Define these stable IDs in `CollectionCatalog`:

- Ordinary: `ordinary.sprout` / 小芽 / `leaf.fill`; `ordinary.hare` / 月兔 / `hare.fill`; `ordinary.tortoise` / 慢慢 / `tortoise.fill`.
- Hidden: `hidden.study-streak` / 书页鸟 / `bird.fill` / rule `study.three-day-streak`; `hidden.long-workout` / 长跑鱼 / `fish.fill` / rule `health.first-sixty-minutes`.

Expose `ordinary`, `hidden`, `all`, `definition(id:)`, and bounds-checked `ordinary(at:)`.

- [ ] **Step 4: Implement the pure event mapping**

```swift
enum CompanionProgressionEvent: Equatable, Sendable {
    case active(index: Int, stage: CompanionStage)
    case matured(index: Int, nextIndex: Int, maturityLevel: Int)
}

enum CompanionProgressionEngine {
    static func event(forReachedLevel rawLevel: Int) -> CompanionProgressionEvent {
        let level = max(0, rawLevel)
        if level == 0 { return .active(index: 0, stage: .juvenile) }
        if level == 1 { return .matured(index: 0, nextIndex: 1, maturityLevel: 1) }
        switch (level - 1) % 3 {
        case 1: return .active(index: (level - 1) / 3 + 1, stage: .stageTwo)
        case 2: return .active(index: (level - 1) / 3 + 1, stage: .stageThree)
        default:
            let index = (level - 4) / 3 + 1
            return .matured(index: index, nextIndex: index + 1, maturityLevel: level)
        }
    }
}
```

- [ ] **Step 5: Run focused/full tests and commit**

```bash
git add LIVELVL/LIVELVL/Collection/CollectibleDefinition.swift LIVELVL/LIVELVL/Collection/CompanionProgressionEngine.swift LIVELVL/LIVELVLTests/CompanionProgressionEngineTests.swift
git commit -m "feat: define collectible catalog and growth timeline"
```

### Task 3: Persist Collection State and Completion Snapshots

**Files:**
- Create: `LIVELVL/LIVELVL/Persistence/CollectionModels.swift`
- Create: `LIVELVL/LIVELVLTests/CollectionPersistenceTests.swift`
- Modify: `LIVELVL/LIVELVL/Item.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift`
- Modify: `LIVELVL/LIVELVL/LIVELVLApp.swift`

**Interfaces:**
- Produces: `CardRewardKind`, `CollectionProgress`, `OwnedCollectible`, `PendingCardReward`, `Completion.durationMinutes`, and `Completion.recordedDimension`.
- Consumes: `CompanionStage`.

- [ ] **Step 1: Write an in-memory round-trip test**

```swift
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct CollectionPersistenceTests {
    @Test func modelsRoundTrip() throws {
        let schema = Schema([CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self])
        let container = try ModelContainer(for: schema, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.insert(CollectionProgress())
        context.insert(PendingCardReward(
            awardKey: "ordinary.level.1", collectibleID: "ordinary.sprout",
            kind: .ordinaryMature, reason: "达到 Lv.1", maturityLevel: 1,
            triggeredAt: Date(timeIntervalSince1970: 10),
            eligibleAt: Date(timeIntervalSince1970: 11.6)
        ))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.highestLevel == 0)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).first?.awardKey == "ordinary.level.1")
    }
}
```

- [ ] **Step 2: Run it and confirm missing-model failures**

Use `-only-testing:LIVELVLTests/CollectionPersistenceTests`.

- [ ] **Step 3: Implement the models**

`CollectionProgress` has unique `singletonKey = "collection.progress"`, `highestLevel = 0`, `activeOrdinaryIndex = 0`, `activeStageRaw = CompanionStage.juvenile.rawValue`, and `lastProcessedMaturityLevel = -1`.

`OwnedCollectible` has unique `awardKey`, `collectibleID`, `kindRaw`, `reason`, `acquiredAt`, and `isUnseen`.

`PendingCardReward` has unique `awardKey`, `collectibleID`, `kindRaw`, `reason`, optional `maturityLevel`, `triggeredAt`, and `eligibleAt`. `eligibleAt` persists when the card may cover the UI, so relaunch does not restart the feedback delay.

Use:

```swift
enum CardRewardKind: String, Codable, Sendable {
    case ordinaryMature, hiddenDiscovery
}
```

Each raw-backed model exposes a read-only typed `kind`; `CollectionProgress.activeStage` has get/set adapters.

- [ ] **Step 4: Snapshot duration on completion**

Add optional `durationMinutes: Int?` to `Completion` and its initializer, defaulting to `nil` for existing rows. Add `recordedDimension: LifeDimension?` from `dimensionRaw`. Pass `item.minutes` from `TodayView.confirmCompletion()`.

- [ ] **Step 5: Register all three models**

Add to `LIVELVLApp`'s schema:

```swift
CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
```

- [ ] **Step 6: Run focused/full tests and commit**

```bash
git add LIVELVL/LIVELVL/Persistence/CollectionModels.swift LIVELVL/LIVELVL/Item.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVL/LIVELVLApp.swift LIVELVL/LIVELVLTests/CollectionPersistenceTests.swift
git commit -m "feat: persist collection rewards and progression"
```

### Task 4: Detect the Two Hidden Achievements

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/HiddenAchievementEngine.swift`
- Create: `LIVELVL/LIVELVLTests/HiddenAchievementEngineTests.swift`

**Interfaces:**
- Produces: `CompletionFact`, `HiddenAchievementAward`, and `HiddenAchievementEngine.newAwards(facts:alreadyAwardedKeys:calendar:)`.
- Consumes: `LifeDimension`.

- [ ] **Step 1: Write failing rule tests**

Test these exact cases:

```swift
let threeDays = [0, 1, 2].map {
    CompletionFact(itemID: UUID(), date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                   dimension: .learning, durationMinutes: 30)
}
#expect(HiddenAchievementEngine.newAwards(
    facts: threeDays, alreadyAwardedKeys: [], calendar: utcCalendar
).map(\.awardKey) == ["hidden.study.three-day-streak"])

let duplicateDay = [0, 0, 1].map {
    CompletionFact(itemID: UUID(), date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                   dimension: .learning, durationMinutes: 30)
}
#expect(HiddenAchievementEngine.newAwards(
    facts: duplicateDay, alreadyAwardedKeys: [], calendar: utcCalendar
).isEmpty)

let workout = CompletionFact(itemID: UUID(), date: .now, dimension: .health, durationMinutes: 60)
#expect(HiddenAchievementEngine.newAwards(
    facts: [workout], alreadyAwardedKeys: [], calendar: utcCalendar
).map(\.awardKey) == ["hidden.health.first-sixty-minutes"])
```

Define `utcCalendar` as Gregorian with GMT zero. Add a fourth assertion passing both award keys in `alreadyAwardedKeys` and expecting no awards.

- [ ] **Step 2: Run focused tests and confirm failure**

Use `-only-testing:LIVELVLTests/HiddenAchievementEngineTests`.

- [ ] **Step 3: Implement value types and rules**

```swift
struct CompletionFact: Equatable, Sendable {
    let itemID: UUID
    let date: Date
    let dimension: LifeDimension
    let durationMinutes: Int
}

struct HiddenAchievementAward: Equatable, Sendable {
    let awardKey: String
    let collectibleID: String
    let reason: String
    let triggeredAt: Date
}
```

The engine groups learning facts by calendar day and detects three consecutive distinct days. It emits:

- `hidden.study.three-day-streak`, collectible `hidden.study-streak`, reason `连续 3 天完成学习行动`.
- `hidden.health.first-sixty-minutes`, collectible `hidden.long-workout`, reason `第一次完成至少 60 分钟的健康行动`.

Filter keys already awarded and sort by `triggeredAt`, then `awardKey`.

- [ ] **Step 4: Run focused/full tests and commit**

```bash
git add LIVELVL/LIVELVL/Collection/HiddenAchievementEngine.swift LIVELVL/LIVELVLTests/HiddenAchievementEngineTests.swift
git commit -m "feat: detect hidden collection achievements"
```

### Task 5: Add the Idempotent Reward Service

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/CardRewardService.swift`
- Create: `LIVELVL/LIVELVLTests/CardRewardServiceTests.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift`

**Interfaces:**
- Produces: `ensureProgress(in:)`, `processCompletion(progress:previousLevel:completions:in:now:calendar:)`, `ordered(_:)`, `claim(_:progress:in:now:)`, `markAllSeen(in:)`.
- Consumes: Tasks 2–4 types.

- [ ] **Step 1: Write failing in-memory integration tests**

Create an in-memory container containing `Item`, `Progress`, `Completion`, and all collection models. Write four tests with these exact outcomes:

1. Processing `Progress(totalXP: 200)` twice leaves one pending key: `["ordinary.level.1"]`.
2. At the same timestamp, `ordered([hidden, ordinary])` returns ordinary first.
3. Claiming `ordinary.level.1` creates one owned row, removes pending, sets index 1, stage juvenile, and last maturity level 1.
4. After triggering Lv.1, lowering total XP to zero and processing again leaves highest level 1 and exactly one original reward.

Use SwiftData fetches for every assertion; do not mock the model context.

- [ ] **Step 2: Run focused tests and confirm failure**

Use `-only-testing:LIVELVLTests/CardRewardServiceTests`.

- [ ] **Step 3: Implement singleton setup and stable ordering**

`ensureProgress` fetches/inserts the singleton. `ordered` sorts ordinary before hidden, then by trigger time, then award key. Before insert, compare against keys in both pending and owned rows.

- [ ] **Step 4: Implement completion processing**

The service:

1. Updates `highestLevel = max(highestLevel, progress.level)`.
2. Visits newly reached levels only.
3. Applies non-maturity stage changes immediately.
4. Creates ordinary key `ordinary.level.<level>` with reason `达到 Lv.<level>，陪伴成熟`; it does not change active species yet.
5. Builds facts only from completions with both dimension and duration snapshots.
6. Inserts new hidden awards.
7. Sets rewards from this completion to `eligibleAt = now + 1.6 seconds` when `progress.level > previousLevel`, otherwise `now + 0.8 seconds`.
8. Saves once.

Capture `previousLevel` before adding XP. Call the service from `confirmCompletion()` only after the completion and XP save, passing that captured level; never call from a SwiftUI getter or `body`.

- [ ] **Step 5: Implement atomic claim**

For an ordinary claim, insert `OwnedCollectible`, remove pending, set `lastProcessedMaturityLevel`, and advance to the next catalog index at juvenile stage in one save. If catalog content is exhausted, archive the card and keep the final available companion without duplicate award generation. For hidden claim, insert owned and remove pending without changing companion. On save error, roll back so pending remains.

- [ ] **Step 6: Implement seen mutation**

`markAllSeen` sets all owned rows to `isUnseen = false` and saves once.

- [ ] **Step 7: Run focused/full tests and commit**

```bash
git add LIVELVL/LIVELVL/Collection/CardRewardService.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVLTests/CardRewardServiceTests.swift
git commit -m "feat: queue and claim collectible rewards"
```

### Task 6: Install the Four-Tab Shell

**Files:**
- Create: `LIVELVL/LIVELVL/MainTabView.swift`
- Create: `LIVELVL/LIVELVL/Collection/CollectionView.swift`
- Create: `LIVELVL/LIVELVL/Rewards/RewardPlaceholderView.swift`
- Create: `LIVELVL/LIVELVL/Profile/ProfileView.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift`

**Interfaces:**
- Produces: `AppTab`, module-visible `MainTabView`, and compile-ready destination views.
- Consumes: `TodayView`.

- [ ] **Step 1: Create the exact tab structure**

```swift
enum AppTab: Hashable { case today, collection, rewards, profile }

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView().tag(AppTab.today).tabItem { Label("今天", systemImage: "sun.max.fill") }
            CollectionView().tag(AppTab.collection).tabItem { Label("收集", systemImage: "square.grid.2x2.fill") }
            RewardPlaceholderView().tag(AppTab.rewards).tabItem { Label("奖励", systemImage: "gift.fill") }
            ProfileView().tag(AppTab.profile).tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(TodayVisualTheme.ink)
    }
}
```

- [ ] **Step 2: Add destination states**

Collection empty copy: `还没有成熟的陪伴 / 继续行动，第一张卡片会来到这里`.

Reward copy: `奖励商城正在准备 / 下一阶段可以用金币兑换你为自己设定的现实奖励`.

Move the existing Profile content unchanged into its new file.

- [ ] **Step 3: Remove old navigation code**

Delete the private old `MainTabView`, old `GrowthView`, and old `ProfileView` from `ContentView.swift`. Keep weekly assessment reachable from the Today state card.

- [ ] **Step 4: Build and inspect**

```bash
xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLCollectionBuild CODE_SIGNING_ALLOWED=NO
```

Expected: exactly 今天 / 收集 / 奖励 / 我的.

- [ ] **Step 5: Commit**

```bash
git add LIVELVL/LIVELVL/MainTabView.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVL/Collection/CollectionView.swift LIVELVL/LIVELVL/Rewards/RewardPlaceholderView.swift LIVELVL/LIVELVL/Profile/ProfileView.swift
git commit -m "feat: add collection and reward tabs"
```

### Task 7: Add the Today Companion Hero

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/CompanionCardView.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift`

**Interfaces:**
- Produces: `CompanionCardView(definition:stage:)`, `PixelSpeciesArtwork(definition:stage:isSilhouette:)`.
- Consumes: catalog, collection progress, theme.

- [ ] **Step 1: Build placeholder art**

Render the definition SF Symbol in black/gray, scale it progressively by stage, and add at most three small square pixels near its base. Silhouette mode uses the silhouette symbol and graphite at 25% opacity.

- [ ] **Step 2: Build the hero**

Use labels `正在陪伴` and `幼体 / 成长中 / 渐渐成熟 / 成熟体`, min height 132, corner radius 22, white fill, restrained shadow, 92×84 artwork, name, and summary. Combine name/stage for VoiceOver.

- [ ] **Step 3: Insert above LevelCard**

Query `CollectionProgress`, ensure the singleton on appearance, resolve the active ordinary definition, and make the companion hero the first Today section. Level, state, and tasks follow.

- [ ] **Step 4: Make task and level feedback sequential**

Extend `TaskRewardFeedback` with `levelBefore: Int`, `levelAfter: Int`, and `var didLevelUp: Bool { levelAfter > levelBefore }`. Update its initializer call and existing tests. In `confirmCompletion()`, capture `levelBefore` before adding XP and `levelAfter` after adding XP. Replace the existing single feedback sleep with this sequence:

1. Keep task XP float, light row shake, and dimension pulse active for 800 ms.
2. Clear task/dimension feedback.
3. If `levelAfter > levelBefore`, set `levelUpFeedback = levelAfter`, show `升级至 Lv.<levelAfter>` above `LevelCard`, lightly pulse the level number in Tiffany blue for 800 ms, then clear it.
4. With Reduce Motion, keep the same timing but use opacity/color only.

Add a focused test to `TaskRewardFeedbackTests.swift` asserting a new pure property `didLevelUp` is false for equal levels and true when `levelAfter > levelBefore`. This gives the root pending-reward presenter a real 1.6-second feedback sequence to wait behind.

- [ ] **Step 5: Build and inspect**

Verify approximately one-sixth-screen hero, no hearts/stars, no clipping at Large Dynamic Type.

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/Collection/CompanionCardView.swift LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVL/Today/LevelCard.swift LIVELVL/LIVELVL/Today/TodayVisualTheme.swift LIVELVL/LIVELVLTests/TaskRewardFeedbackTests.swift
git commit -m "feat: show active companion on today"
```

### Task 8: Present Rewards Globally

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/CardRewardOverlay.swift`
- Create: `LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift`
- Modify: `LIVELVL/LIVELVL/MainTabView.swift`

**Interfaces:**
- Produces: `CollectionAttentionState`, `CardRewardOverlay`, `CollectionTabLabel`.
- Consumes: ordered pending queue and claim service.

- [ ] **Step 1: Test attention state**

```swift
@Test func claimRegistersAttention() {
    var state = CollectionAttentionState()
    state.registerClaim()
    #expect(state.shakeToken == 1)
    #expect(state.hasUnseenReward)
    state.markSeen()
    #expect(!state.hasUnseenReward)
}
```

The value starts at token 0/unseen false; `registerClaim` increments and marks unseen.

- [ ] **Step 2: Run focused test, implement the value, rerun**

Use `-only-testing:LIVELVLTests/CardRewardPresentationTests`.

- [ ] **Step 3: Build overlay behavior**

Overlay the full tab with 28% black dimming, title `陪伴成熟` or `隐藏发现`, artwork, name, exact reason, and Tiffany-blue `收下`. Block background taps. Call the service first; only after success animate scale to 0.15 and offset toward the Collection tab. On failure keep it open with `领取失败，请重试`. Reduce Motion uses a 0.2-second fade. Move VoiceOver focus to title.

- [ ] **Step 4: Host it in MainTabView**

Query pending/owned rows, sort with the service, and place the first reward in a `ZStack` over `TabView` only when `Date.now >= reward.eligibleAt`. A task keyed by the queue head sleeps only until its persisted `eligibleAt`; if that time already passed after relaunch, present immediately. After claim, increment attention, keep `selectedTab` unchanged, and reveal the next reward after 250 ms.

- [ ] **Step 5: Animate the Collection label**

Show an unseen dot. On a new token, perform two small horizontal offsets and one short Tiffany pulse. Reduce Motion skips offsets and keeps the pulse. Selecting Collection calls `markAllSeen` and clears attention.

- [ ] **Step 6: Test manually and commit**

Force-quit with the card open, relaunch, claim it, verify no tab switch and exactly two light shakes.

```bash
git add LIVELVL/LIVELVL/Collection/CardRewardOverlay.swift LIVELVL/LIVELVL/MainTabView.swift LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift
git commit -m "feat: present collectible rewards globally"
```

### Task 9: Build Collection Cards and Catalog

**Files:**
- Create: `LIVELVL/LIVELVL/Collection/CollectibleCardView.swift`
- Create: `LIVELVL/LIVELVL/Collection/CatalogView.swift`
- Modify: `LIVELVL/LIVELVL/Collection/CollectionView.swift`

**Interfaces:**
- Produces: small card, expanded card, catalog.
- Consumes: owned rows, catalog, artwork, seen service.

- [ ] **Step 1: Implement the approved collection layout**

Query owned cards newest-first. Show title and top-right `books.vertical.fill` catalog button, then a featured latest card (or active companion when empty), then a two-flexible-column `LazyVGrid` with spacing 14. Mark visible rows seen on appearance.

- [ ] **Step 2: Implement card enlargement and flip**

Small cards use a roughly 3:4 aspect ratio. Selection overlays an expanded front without recreating the underlying scroll view. Tapping the expanded card flips to the back; tapping dimmed outside closes. Back fields: name, kind, acquired time, exact reason, summary, details, and four stage labels for ordinary cards. Use Y-axis `rotation3DEffect`; Reduce Motion crossfades.

- [ ] **Step 3: Implement CatalogView**

Iterate `CollectionCatalog.all` in two columns. Unlocked cards show art/name/`已发现`. Locked ordinary cards show gray silhouette/name/`尚未发现`. Locked hidden cards show gray silhouette/`隐藏物种`/`尚未发现`, revealing no rule or name. Header shows unique unlocked count over catalog count.

- [ ] **Step 4: Verify interaction and accessibility**

Confirm enlarge → flip → outside close, preserved scroll, VoiceOver source/reason, and text labels for locked state.

- [ ] **Step 5: Run full tests and commit**

```bash
git add LIVELVL/LIVELVL/Collection/CollectionView.swift LIVELVL/LIVELVL/Collection/CollectibleCardView.swift LIVELVL/LIVELVL/Collection/CatalogView.swift
git commit -m "feat: add collection cards and catalog"
```

### Task 10: Add Debug Full Reset

**Files:**
- Create: `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`
- Create: `LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift`
- Modify: `LIVELVL/LIVELVL/Profile/ProfileView.swift`

**Interfaces:**
- Produces: `LocalDataResetService.reset(context:fileManager:applicationSupportURL:)`.
- Consumes: every current SwiftData model.

- [ ] **Step 1: Write the reset test**

Use an in-memory schema with all current models, insert one of each, and create `RewardProductImages/sample.bin` under a UUID-named temporary directory. After reset, assert every fetch is empty and the image directory does not exist.

- [ ] **Step 2: Run focused test and confirm failure**

Use `-only-testing:LIVELVLTests/LocalDataResetServiceTests`.

- [ ] **Step 3: Implement explicit deletion**

```swift
try context.delete(model: PendingCardReward.self)
try context.delete(model: OwnedCollectible.self)
try context.delete(model: CollectionProgress.self)
try context.delete(model: Completion.self)
try context.delete(model: Item.self)
try context.delete(model: Progress.self)
try context.delete(model: StateSnapshot.self)
try context.delete(model: DimensionProfile.self)
try context.save()
```

Then remove only `applicationSupportURL/RewardProductImages` when present. The reward-store branch extends this explicit list with coins/products/history.

- [ ] **Step 4: Add Debug-only double confirmation**

Under `#if DEBUG`, first show the affected data list; its destructive action opens `最后确认`; only `确认重置` calls the service. Surface errors instead of claiming success. Empty snapshots naturally return `ContentView` to Day 0.

- [ ] **Step 5: Test Debug and build Release**

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLCollectionTests CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'generic/platform=iOS Simulator' -configuration Release -derivedDataPath /tmp/LIVELVLCollectionRelease CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 6: Commit**

```bash
git add LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift LIVELVL/LIVELVL/Profile/ProfileView.swift LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift
git commit -m "feat: add debug local data reset"
```

### Task 11: Final Verification and Handoff

**Files:**
- Modify: `docs/HANDOFF.md`

**Interfaces:**
- Produces: verified MVP and accurate next-chat handoff.
- Consumes: all prior tasks.

- [ ] **Step 1: Check source control hygiene**

```bash
git diff --check
git status --short
git diff -- LIVELVL/LIVELVL.xcodeproj/project.pbxproj
```

Expected: no whitespace failures, no unintended user-state file, no manual source-membership edits.

- [ ] **Step 2: Run a clean full suite**

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLCollectionFinal CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 3: Run the simulator acceptance path**

1. Debug reset, complete Day 0, verify Lv.0/first juvenile/four tabs.
2. Reach 200 XP; verify task/dimension feedback precedes maturity.
3. Force-quit before `收下`; relaunch and verify the same pending card.
4. Claim; verify flight, Tiffany pulse, two light shakes, no tab switch, archive, and immediate second juvenile.
5. Open Collection; clear unseen, enlarge, flip, close outside, preserve scroll.
6. Open Catalog; verify lit/silhouette states and hidden secrecy.
7. Complete one 60-minute Health task; verify automatic hidden card and unchanged active companion.
8. Use unit fixtures for the three-day Learning rule; verify one idempotent card.
9. Undo XP; verify display can fall while collection/companion never regress.
10. Enable Reduce Motion; verify fade/color replacement.
11. Reset; verify Day 0 and all local business data cleared.

- [ ] **Step 4: Update HANDOFF.md**

Record the branch and final commit, four tabs, Lv.0 formula, ordinary timeline, two hidden fixtures, Debug reset, test result/count, simulator device/OS, and next branch `codex/reward-store-mvp`. Remove outdated claims that Level only rises or Growth remains a tab.

- [ ] **Step 5: Commit docs, review, and finish branch**

```bash
git add docs/HANDOFF.md
git commit -m "docs: record collection MVP verification"
```

Invoke `superpowers:requesting-code-review`, fix confirmed findings, rerun the clean suite, then invoke `superpowers:finishing-a-development-branch`. Merge to `main` before starting the reward-store branch.
