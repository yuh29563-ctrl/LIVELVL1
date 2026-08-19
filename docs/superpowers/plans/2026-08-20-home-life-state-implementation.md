# LIVELVL Home Life State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the confirmed C+ home dashboard with permanent level progress, a real six-axis radar chart, rolling 15-day life-state calculation, immediate pending-growth feedback, and six-step initial/weekly self-assessment.

**Architecture:** Keep SwiftData as the persistence source of truth and place all score math in a pure Foundation domain engine that can be tested without rendering SwiftUI. SwiftUI views query persisted models, convert completion records into value inputs, and render focused card components; official scores come from the latest snapshot while projected scores are derived dynamically from the snapshot baseline and current rolling activity.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, iOS 17+, Xcode 26.6; no server and no third-party dependency.

**Spec:** `docs/superpowers/specs/2026-08-19-home-life-state-design.md`

## Global Constraints

- Preserve every existing `Item`, `Completion`, and `Progress` record; schema additions must use lightweight-compatible defaults or optional fields.
- Level remains permanent and immediate: Lv.1 → Lv.2 costs 200 XP, later levels cost 2,000 XP, and cancelling completion returns XP.
- State values are `1.0...10.0`, shown to one decimal place, and never mutate the Level calculation.
- The activity window is the current day plus the previous 14 natural days; every included day has equal weight and day 16 is excluded.
- Official state changes only when assessment is submitted; task completion changes only the projected polygon.
- Each dimension counts at most the first two completions and 80 XP per natural day toward State; all completion XP still counts toward Level.
- The radar chart must use native SwiftUI, with no chart package or custom font dependency.
- Animations must be brief and respect Reduce Motion; VoiceOver must expose the numeric state without depending on the chart shape.
- The active worktree already contains unrelated staged deletions and user edits. Never reset them, and use path-limited commits for every task.

## File Structure

The completed feature should use these responsibilities:

```text
LIVELVL/LIVELVL/
├── LIVELVLApp.swift                         # SwiftData schema registration
├── ContentView.swift                        # onboarding gate and three-tab shell only
├── Item.swift                               # existing task/progress/completion models + GrowthEngine
├── Domain/
│   ├── LifeDimension.swift                  # six dimensions and display order
│   └── LifeStateEngine.swift                # pure 15-day, settlement, projection and due-date math
├── Persistence/
│   └── LifeStateModels.swift                # DimensionProfile and StateSnapshot
├── LifeState/
│   ├── LifeStateSummary.swift               # persisted data → dashboard value state
│   ├── StateAssessmentView.swift            # initial and weekly six-page assessment
│   └── AssessmentSettlement.swift           # pure assessment result construction
├── Today/
│   ├── TodayView.swift                      # home composition and task interactions
│   ├── AddTaskView.swift                    # existing task editor extracted intact
│   ├── LevelCard.swift                      # dark level/XP card
│   ├── LifeStateCard.swift                  # comprehensive score, radar and annotation
│   └── RadarChartView.swift                 # native radar geometry and drawing
├── Growth/
│   └── GrowthView.swift                     # six-dimension detail and weekly assessment entry
└── Profile/
    └── ProfileView.swift                    # existing profile placeholder extracted intact

LIVELVL/LIVELVLTests/
├── LifeStateEngineTests.swift
├── LifeStateSummaryTests.swift
├── AssessmentSettlementTests.swift
└── RadarGeometryTests.swift
```

Do not introduce a view model or global observable store. Screen-local presentation state stays in `@State`; persisted shared state comes from `@Query` and `ModelContext`; reusable calculations use value types and static pure functions.

---

### Task 1: Add the test target and pure life-state engine

**Files:**
- Create: `LIVELVL/LIVELVL/Domain/LifeDimension.swift`
- Create: `LIVELVL/LIVELVL/Domain/LifeStateEngine.swift`
- Create: `LIVELVL/LIVELVLTests/LifeStateEngineTests.swift`
- Modify: `LIVELVL/LIVELVL/Item.swift:1-5`
- Modify: `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: existing `LifeDimension` cases currently declared in `Item.swift`.
- Produces: `LifeDimension`, `LifeStateValues`, `StateActivity`, and `LifeStateEngine`; all later tasks use these exact names.

- [ ] **Step 1: Create an iOS Unit Testing Bundle named `LIVELVLTests`**

Add a target with product type `com.apple.product-type.bundle.unit-test`, bundle identifier `com.livelvl.LIVELVLTests`, deployment target iOS 17.0, host application `LIVELVL`, and a target dependency on `LIVELVL`. Add it to the shared `LIVELVL` scheme's Test action. Keep the existing file-system-synchronized app group; create a synchronized `LIVELVLTests` group for test sources.

Verify the target is visible:

```bash
xcodebuild -project LIVELVL/LIVELVL.xcodeproj -list
```

Expected: targets include `LIVELVL` and `LIVELVLTests`; scheme `LIVELVL` is present.

- [ ] **Step 2: Move the dimension enum and write failing engine tests**

Move the existing enum unchanged into `Domain/LifeDimension.swift` so the display order remains health, learning, career, finance, relationships, interests:

```swift
import Foundation

enum LifeDimension: String, CaseIterable, Codable, Identifiable, Sendable {
    case health, learning, career, finance, relationships, interests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "健康"
        case .learning: "学习"
        case .career: "事业"
        case .finance: "财务"
        case .relationships: "关系"
        case .interests: "兴趣"
        }
    }
}
```

Create `LifeStateEngineTests.swift` with a fixed Gregorian UTC calendar and these tests:

```swift
import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeStateEngineTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    @Test func noActivityReturnsNeutralActionScore() {
        #expect(LifeStateEngine.actionScore(
            activities: [], weeklyTarget: 3, now: date(20), calendar: calendar
        ) == 5.0)
    }

    @Test func oneMediumActionProducesSmallGrowth() {
        let activity = StateActivity(date: date(20), xp: 40)
        #expect(LifeStateEngine.actionScore(
            activities: [activity], weeklyTarget: 3, now: date(20), calendar: calendar
        ) == 5.8)
    }

    @Test func everyDayInsideWindowHasEqualWeight() {
        let today = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(20), xp: 40)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        let oldestIncludedDay = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(6), xp: 40)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        #expect(today == oldestIncludedDay)
    }

    @Test func sixteenthDayIsExcluded() {
        let score = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(5), xp: 80)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        #expect(score == 5.0)
    }

    @Test func dailyCountAndXPUseCaps() {
        let activities = [
            StateActivity(date: date(20, hour: 8), xp: 50),
            StateActivity(date: date(20, hour: 9), xp: 50),
            StateActivity(date: date(20, hour: 10), xp: 80)
        ]
        #expect(LifeStateEngine.actionScore(
            activities: activities, weeklyTarget: 1, now: date(20), calendar: calendar
        ) == 9.7)
    }

    @Test func settlementAndProjectionRoundAndClamp() {
        #expect(LifeStateEngine.settledScore(selfRating: 8.0, actionScore: 7.0) == 7.6)
        #expect(LifeStateEngine.projectedScore(
            officialScore: 6.5, baselineActionScore: 6.0, currentActionScore: 6.8
        ) == 6.8)
        #expect(LifeStateEngine.projectedScore(
            officialScore: 9.9, baselineActionScore: 5.0, currentActionScore: 10.0
        ) == 10.0)
    }

    @Test func assessmentIsDueAfterSevenCalendarDays() {
        #expect(!LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(13, hour: 13), now: date(20, hour: 12), calendar: calendar
        ))
        #expect(LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(13, hour: 12), now: date(20, hour: 12), calendar: calendar
        ))
    }
}
```

- [ ] **Step 3: Run the tests to verify the engine is missing**

```bash
xcodebuild test \
  -project LIVELVL/LIVELVL.xcodeproj \
  -scheme LIVELVL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/LIVELVLStateDerived \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `LifeStateEngine`, `LifeStateValues`, and `StateActivity` do not exist.

- [ ] **Step 4: Implement the minimal pure engine**

Create these exact public-to-module interfaces in `Domain/LifeStateEngine.swift`:

```swift
import Foundation

struct LifeStateValues: Equatable, Sendable {
    var health: Double
    var learning: Double
    var career: Double
    var finance: Double
    var relationships: Double
    var interests: Double

    static let neutral = LifeStateValues(repeating: 5.0)

    init(repeating value: Double) {
        health = value
        learning = value
        career = value
        finance = value
        relationships = value
        interests = value
    }

    init(health: Double, learning: Double, career: Double,
         finance: Double, relationships: Double, interests: Double) {
        self.health = health
        self.learning = learning
        self.career = career
        self.finance = finance
        self.relationships = relationships
        self.interests = interests
    }

    subscript(_ dimension: LifeDimension) -> Double {
        get {
            switch dimension {
            case .health: health
            case .learning: learning
            case .career: career
            case .finance: finance
            case .relationships: relationships
            case .interests: interests
            }
        }
        set {
            switch dimension {
            case .health: health = newValue
            case .learning: learning = newValue
            case .career: career = newValue
            case .finance: finance = newValue
            case .relationships: relationships = newValue
            case .interests: interests = newValue
            }
        }
    }

    var average: Double {
        let total = LifeDimension.allCases.reduce(0.0) { $0 + self[$1] }
        return LifeStateEngine.rounded(total / 6.0)
    }
}

struct StateActivity: Equatable, Sendable {
    let date: Date
    let xp: Int
}

enum LifeStateEngine {
    static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    static func actionScore(
        activities: [StateActivity],
        weeklyTarget: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -14, to: today)!
        let eligible = activities
            .filter { $0.date >= windowStart && $0.date <= now }
            .sorted { $0.date < $1.date }
        let grouped = Dictionary(grouping: eligible) { calendar.startOfDay(for: $0.date) }

        var countedCompletions = 0
        var countedXP = 0
        for dayActivities in grouped.values {
            let firstTwo = Array(dayActivities.prefix(2))
            countedCompletions += firstTwo.count
            countedXP += min(80, firstTwo.reduce(0) { $0 + max(0, $1.xp) })
        }

        let targetCount = Double(min(7, max(1, weeklyTarget))) * 15.0 / 7.0
        let consistency = min(1.0, Double(countedCompletions) / targetCount)
        let intensity = min(1.0, Double(countedXP) / (targetCount * 40.0))
        return rounded(5.0 + 5.0 * (consistency * 0.6 + intensity * 0.4))
    }

    static func settledScore(selfRating: Double, actionScore: Double) -> Double {
        rounded(min(10.0, max(1.0, selfRating * 0.6 + actionScore * 0.4)))
    }

    static func projectedScore(
        officialScore: Double,
        baselineActionScore: Double,
        currentActionScore: Double
    ) -> Double {
        rounded(min(10.0, max(1.0,
            officialScore + (currentActionScore - baselineActionScore) * 0.4
        )))
    }

    static func isAssessmentDue(
        lastAssessedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate = calendar.date(byAdding: .day, value: 7, to: lastAssessedAt) else {
            return false
        }
        return now >= dueDate
    }
}
```

- [ ] **Step 5: Run unit tests and the app build**

Run the Task 1 test command again. Expected: all seven engine tests PASS. Then run:

```bash
xcodebuild build \
  -project LIVELVL/LIVELVL.xcodeproj \
  -scheme LIVELVL \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/LIVELVLStateBuild \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit only Task 1 paths**

```bash
git add LIVELVL/LIVELVL.xcodeproj/project.pbxproj \
  LIVELVL/LIVELVL/Domain/LifeDimension.swift \
  LIVELVL/LIVELVL/Domain/LifeStateEngine.swift \
  LIVELVL/LIVELVL/Item.swift \
  LIVELVL/LIVELVLTests/LifeStateEngineTests.swift
git commit --only -m "feat: add tested life state engine" -- \
  LIVELVL/LIVELVL.xcodeproj/project.pbxproj \
  LIVELVL/LIVELVL/Domain/LifeDimension.swift \
  LIVELVL/LIVELVL/Domain/LifeStateEngine.swift \
  LIVELVL/LIVELVL/Item.swift \
  LIVELVL/LIVELVLTests/LifeStateEngineTests.swift
```

---

### Task 2: Add lightweight-compatible persistence and dashboard summary

**Files:**
- Create: `LIVELVL/LIVELVL/Persistence/LifeStateModels.swift`
- Create: `LIVELVL/LIVELVL/LifeState/LifeStateSummary.swift`
- Create: `LIVELVL/LIVELVLTests/LifeStateSummaryTests.swift`
- Modify: `LIVELVL/LIVELVL/Item.swift:33-35`
- Modify: `LIVELVL/LIVELVL/LIVELVLApp.swift:12-15`

**Interfaces:**
- Consumes: `LifeDimension`, `LifeStateValues`, `StateActivity`, `LifeStateEngine`.
- Produces: `DimensionProfile`, `StateSnapshot`, `DimensionActivityRecord`, `DimensionStateSummary`, `LifeStateSummary`, and `LifeStateSummaryBuilder.build(...)`.

- [ ] **Step 1: Write failing summary and legacy-record tests**

Create tests that prove projected state changes without mutating official state and that old completion rows can still resolve through their task:

```swift
import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeStateSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_776_672_000)

    @Test func activityChangesProjectionButNotOfficialSnapshot() {
        let profiles = LifeDimension.allCases.map {
            DimensionProfile(dimension: $0, selfRating: 6.0, weeklyTarget: 3, lastAssessedAt: now)
        }
        let snapshot = StateSnapshot(
            scores: LifeStateValues(repeating: 6.0),
            actionScores: .neutral,
            assessedAt: now
        )
        let record = DimensionActivityRecord(
            dimension: .learning, taskTitle: "阅读 30 分钟", date: now, xp: 40
        )

        let summary = LifeStateSummaryBuilder.build(
            profiles: profiles,
            snapshot: snapshot,
            activities: [record],
            now: now
        )

        #expect(summary.official.learning == 6.0)
        #expect(summary.projected.learning == 6.3)
        #expect(summary.highlightedChange?.dimension == .learning)
        #expect(summary.highlightedChange?.sourceTitle == "阅读 30 分钟")
    }

    @Test func removingActivityReturnsProjectionToOfficial() {
        let profiles = LifeDimension.allCases.map {
            DimensionProfile(dimension: $0, selfRating: 6.0, weeklyTarget: 3, lastAssessedAt: now)
        }
        let snapshot = StateSnapshot(
            scores: LifeStateValues(repeating: 6.0),
            actionScores: .neutral,
            assessedAt: now
        )
        let summary = LifeStateSummaryBuilder.build(
            profiles: profiles, snapshot: snapshot, activities: [], now: now
        )
        #expect(summary.projected == summary.official)
        #expect(summary.highlightedChange == nil)
    }

    @Test func legacyCompletionFallsBackToCurrentTaskMetadata() {
        let task = Item(
            title: "慢跑", dimension: .health, minutes: 20,
            difficulty: 2, xp: 20, recurrence: .once
        )
        let legacy = Completion(itemID: task.id, xp: 20)
        let record = legacy.stateActivity(fallbackItem: task)
        #expect(record?.dimension == .health)
        #expect(record?.taskTitle == "慢跑")
    }
}
```

- [ ] **Step 2: Run tests to verify persistence types are missing**

Run the Task 1 test command. Expected: FAIL with missing `DimensionProfile`, `StateSnapshot`, and `LifeStateSummaryBuilder`.

- [ ] **Step 3: Add SwiftData models and completion metadata**

Implement `Persistence/LifeStateModels.swift` with stored scalar fields for reliable SwiftData persistence:

```swift
import Foundation
import SwiftData

@Model
final class DimensionProfile {
    @Attribute(.unique) var dimensionRaw: String
    var selfRating: Double
    var weeklyTarget: Int
    var lastAssessedAt: Date

    init(dimension: LifeDimension, selfRating: Double, weeklyTarget: Int, lastAssessedAt: Date) {
        dimensionRaw = dimension.rawValue
        self.selfRating = selfRating
        self.weeklyTarget = weeklyTarget
        self.lastAssessedAt = lastAssessedAt
    }

    var dimension: LifeDimension {
        LifeDimension(rawValue: dimensionRaw) ?? .learning
    }
}

@Model
final class StateSnapshot {
    var assessedAt: Date
    var overallScore: Double
    var health: Double
    var learning: Double
    var career: Double
    var finance: Double
    var relationships: Double
    var interests: Double
    var healthAction: Double
    var learningAction: Double
    var careerAction: Double
    var financeAction: Double
    var relationshipsAction: Double
    var interestsAction: Double

    init(scores: LifeStateValues, actionScores: LifeStateValues, assessedAt: Date) {
        self.assessedAt = assessedAt
        overallScore = scores.average
        health = scores.health
        learning = scores.learning
        career = scores.career
        finance = scores.finance
        relationships = scores.relationships
        interests = scores.interests
        healthAction = actionScores.health
        learningAction = actionScores.learning
        careerAction = actionScores.career
        financeAction = actionScores.finance
        relationshipsAction = actionScores.relationships
        interestsAction = actionScores.interests
    }

    var scores: LifeStateValues {
        LifeStateValues(health: health, learning: learning, career: career,
                        finance: finance, relationships: relationships, interests: interests)
    }

    var actionScores: LifeStateValues {
        LifeStateValues(health: healthAction, learning: learningAction, career: careerAction,
                        finance: financeAction, relationships: relationshipsAction,
                        interests: interestsAction)
    }
}
```

Extend existing `Completion` with optional metadata so existing rows migrate without requiring reset:

```swift
var dimensionRaw: String?
var taskTitle: String?

init(itemID: UUID, xp: Int, dimension: LifeDimension? = nil,
     taskTitle: String? = nil, date: Date = .now) {
    self.itemID = itemID
    self.xp = xp
    self.dimensionRaw = dimension?.rawValue
    self.taskTitle = taskTitle
    self.date = date
}

func stateActivity(fallbackItem: Item?) -> DimensionActivityRecord? {
    guard let dimension = dimensionRaw.flatMap(LifeDimension.init(rawValue:))
            ?? fallbackItem?.dimension else { return nil }
    return DimensionActivityRecord(
        dimension: dimension,
        taskTitle: taskTitle ?? fallbackItem?.title ?? "已完成的行动",
        date: date,
        xp: xp
    )
}
```

Register `DimensionProfile.self` and `StateSnapshot.self` in the app schema. Do not rename or delete existing model properties.

- [ ] **Step 4: Implement the pure dashboard summary builder**

Create `LifeState/LifeStateSummary.swift` with these interfaces:

```swift
import Foundation

struct DimensionActivityRecord: Equatable, Sendable {
    let dimension: LifeDimension
    let taskTitle: String
    let date: Date
    let xp: Int
}

struct DimensionStateSummary: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }
    let dimension: LifeDimension
    let officialScore: Double
    let projectedScore: Double
    let delta: Double
    let sourceTitle: String?
}

struct LifeStateSummary: Equatable, Sendable {
    let official: LifeStateValues
    let projected: LifeStateValues
    let overallScore: Double
    let dimensions: [DimensionStateSummary]
    let highlightedChange: DimensionStateSummary?
    let isAssessmentDue: Bool
}

enum LifeStateSummaryBuilder {
    static func build(
        profiles: [DimensionProfile],
        snapshot: StateSnapshot,
        activities: [DimensionActivityRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> LifeStateSummary {
        var currentActions = LifeStateValues.neutral
        var projected = snapshot.scores
        let profilesByDimension = Dictionary(uniqueKeysWithValues: profiles.map { ($0.dimension, $0) })

        for dimension in LifeDimension.allCases {
            let target = profilesByDimension[dimension]?.weeklyTarget ?? 3
            let inputs = activities
                .filter { $0.dimension == dimension }
                .map { StateActivity(date: $0.date, xp: $0.xp) }
            currentActions[dimension] = LifeStateEngine.actionScore(
                activities: inputs, weeklyTarget: target, now: now, calendar: calendar
            )
            projected[dimension] = LifeStateEngine.projectedScore(
                officialScore: snapshot.scores[dimension],
                baselineActionScore: snapshot.actionScores[dimension],
                currentActionScore: currentActions[dimension]
            )
        }

        let dimensionSummaries = LifeDimension.allCases.map { dimension in
            DimensionStateSummary(
                dimension: dimension,
                officialScore: snapshot.scores[dimension],
                projectedScore: projected[dimension],
                delta: LifeStateEngine.rounded(projected[dimension] - snapshot.scores[dimension]),
                sourceTitle: activities
                    .filter { $0.dimension == dimension }
                    .max(by: { $0.date < $1.date })?.taskTitle
            )
        }
        let highlighted = dimensionSummaries
            .filter { abs($0.delta) >= 0.1 }
            .max { abs($0.delta) < abs($1.delta) }

        return LifeStateSummary(
            official: snapshot.scores,
            projected: projected,
            overallScore: snapshot.overallScore,
            dimensions: dimensionSummaries,
            highlightedChange: highlighted,
            isAssessmentDue: LifeStateEngine.isAssessmentDue(
                lastAssessedAt: snapshot.assessedAt, now: now, calendar: calendar
            )
        )
    }
}
```

- [ ] **Step 5: Run tests and verify the expanded schema builds**

Run all tests. Expected: PASS. Then build the app with the expanded schema. Expected: the test suite passes and the app target compiles without deleting any existing store; actual on-device relaunch persistence is verified in Task 5.

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/LIVELVLStateDerived CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL \
  -sdk iphonesimulator -derivedDataPath /tmp/LIVELVLStateBuild CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 6: Commit only Task 2 paths**

```bash
git add LIVELVL/LIVELVL/Persistence/LifeStateModels.swift \
  LIVELVL/LIVELVL/LifeState/LifeStateSummary.swift \
  LIVELVL/LIVELVLTests/LifeStateSummaryTests.swift \
  LIVELVL/LIVELVL/Item.swift LIVELVL/LIVELVL/LIVELVLApp.swift
git commit --only -m "feat: persist life state snapshots" -- \
  LIVELVL/LIVELVL/Persistence/LifeStateModels.swift \
  LIVELVL/LIVELVL/LifeState/LifeStateSummary.swift \
  LIVELVL/LIVELVLTests/LifeStateSummaryTests.swift \
  LIVELVL/LIVELVL/Item.swift LIVELVL/LIVELVL/LIVELVLApp.swift
```

---

### Task 3: Implement Day 0 and weekly six-page assessment

**Files:**
- Create: `LIVELVL/LIVELVL/LifeState/AssessmentSettlement.swift`
- Create: `LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift`
- Create: `LIVELVL/LIVELVLTests/AssessmentSettlementTests.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift:1-12`

**Interfaces:**
- Consumes: `LifeStateEngine`, `LifeStateValues`, `DimensionProfile`, `StateSnapshot`, `DimensionActivityRecord`.
- Produces: `AssessmentMode`, `AssessmentEntry`, `AssessmentResult`, `AssessmentSettlement.makeResult(...)`, and `StateAssessmentView(mode:)`.

- [ ] **Step 1: Write failing settlement tests**

```swift
import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct AssessmentSettlementTests {
    private let date = Date(timeIntervalSince1970: 1_776_672_000)

    private var entries: [AssessmentEntry] {
        LifeDimension.allCases.map {
            AssessmentEntry(dimension: $0, rating: 8.0, weeklyTarget: 3)
        }
    }

    @Test func initialAssessmentUsesSelfRatingsDirectly() {
        let result = AssessmentSettlement.makeResult(
            mode: .initial,
            entries: entries,
            actionScores: .neutral,
            assessedAt: date
        )
        #expect(result.officialScores == LifeStateValues(repeating: 8.0))
        #expect(result.baselineActionScores == .neutral)
    }

    @Test func weeklyAssessmentBlendsSelfAndAction() {
        let result = AssessmentSettlement.makeResult(
            mode: .weekly,
            entries: entries,
            actionScores: LifeStateValues(repeating: 7.0),
            assessedAt: date
        )
        #expect(result.officialScores == LifeStateValues(repeating: 7.6))
    }

    @Test func entriesAreClampedToSupportedRanges() {
        let invalid = LifeDimension.allCases.map {
            AssessmentEntry(dimension: $0, rating: 12.0, weeklyTarget: 9)
        }
        let result = AssessmentSettlement.makeResult(
            mode: .initial, entries: invalid, actionScores: .neutral, assessedAt: date
        )
        #expect(result.entries.allSatisfy { $0.rating == 10.0 && $0.weeklyTarget == 7 })
    }
}
```

- [ ] **Step 2: Run tests and verify settlement types are missing**

Run all tests. Expected: FAIL with missing assessment types.

- [ ] **Step 3: Implement assessment value types and settlement**

Create `AssessmentSettlement.swift`:

```swift
import Foundation

enum AssessmentMode: String, Identifiable, Sendable {
    case initial
    case weekly
    var id: String { rawValue }
}

struct AssessmentEntry: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }
    let dimension: LifeDimension
    var rating: Double
    var weeklyTarget: Int
}

struct AssessmentResult: Equatable, Sendable {
    let entries: [AssessmentEntry]
    let officialScores: LifeStateValues
    let baselineActionScores: LifeStateValues
    let assessedAt: Date
}

enum AssessmentSettlement {
    static func makeResult(
        mode: AssessmentMode,
        entries: [AssessmentEntry],
        actionScores: LifeStateValues,
        assessedAt: Date
    ) -> AssessmentResult {
        let normalized = LifeDimension.allCases.map { dimension in
            let source = entries.first { $0.dimension == dimension }
                ?? AssessmentEntry(dimension: dimension, rating: 5.0, weeklyTarget: 3)
            return AssessmentEntry(
                dimension: dimension,
                rating: LifeStateEngine.rounded(min(10.0, max(1.0, source.rating))),
                weeklyTarget: min(7, max(1, source.weeklyTarget))
            )
        }
        var selfRatings = LifeStateValues.neutral
        var official = LifeStateValues.neutral
        for entry in normalized {
            selfRatings[entry.dimension] = entry.rating
            official[entry.dimension] = mode == .initial
                ? entry.rating
                : LifeStateEngine.settledScore(
                    selfRating: entry.rating,
                    actionScore: actionScores[entry.dimension]
                )
        }
        return AssessmentResult(
            entries: normalized,
            officialScores: official,
            baselineActionScores: actionScores,
            assessedAt: assessedAt
        )
    }
}
```

- [ ] **Step 4: Build the six-page native assessment UI**

Implement `StateAssessmentView(mode:)` as a `NavigationStack` containing one dimension at a time. Own `[AssessmentEntry]` and `pageIndex` with `@State`; use a visible `Slider(value:in:step:)` for `1.0...10.0` and a `Stepper` for `1...7`. Show `第 N / 6 项`, the dimension name, current one-decimal rating, and the non-diagnostic disclaimer. Declare its persistence dependencies explicitly:

```swift
@Environment(\.modelContext) private var context
@Environment(\.dismiss) private var dismiss
@Query private var profiles: [DimensionProfile]
@Query private var items: [Item]
@Query private var completions: [Completion]
```

Use this save contract:

```swift
private func saveAssessment(at now: Date) {
    let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    let records = completions.compactMap { $0.stateActivity(fallbackItem: itemByID[$0.itemID]) }
    var actionScores = LifeStateValues.neutral
    for entry in entries {
        actionScores[entry.dimension] = LifeStateEngine.actionScore(
            activities: records
                .filter { $0.dimension == entry.dimension }
                .map { StateActivity(date: $0.date, xp: $0.xp) },
            weeklyTarget: entry.weeklyTarget,
            now: now
        )
    }

    let result = AssessmentSettlement.makeResult(
        mode: mode, entries: entries, actionScores: actionScores, assessedAt: now
    )
    for entry in result.entries {
        if let profile = profiles.first(where: { $0.dimension == entry.dimension }) {
            profile.selfRating = entry.rating
            profile.weeklyTarget = entry.weeklyTarget
            profile.lastAssessedAt = now
        } else {
            context.insert(DimensionProfile(
                dimension: entry.dimension,
                selfRating: entry.rating,
                weeklyTarget: entry.weeklyTarget,
                lastAssessedAt: now
            ))
        }
    }
    context.insert(StateSnapshot(
        scores: result.officialScores,
        actionScores: result.baselineActionScores,
        assessedAt: now
    ))
    try? context.save()
    if mode == .weekly { dismiss() }
}
```

For `.weekly`, initialize entries from existing profiles. For `.initial`, use `5.0` and 3. Disable swipe-past-the-end; the last button reads `生成 Day 0 状态` or `更新状态` according to mode.

- [ ] **Step 5: Gate the app only when no snapshot exists**

Replace `ContentView`'s direct `TabView` with this structure so existing task data is preserved and only state setup is requested:

```swift
struct ContentView: View {
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]

    var body: some View {
        if snapshots.isEmpty {
            StateAssessmentView(mode: .initial)
        } else {
            MainTabView()
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("今天", systemImage: "sun.max.fill") }
            GrowthView().tabItem { Label("成长", systemImage: "chart.line.uptrend.xyaxis") }
            ProfileView().tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
    }
}
```

- [ ] **Step 6: Test, build, and commit Task 3**

Run all tests and the simulator build. Expected: tests PASS and `BUILD SUCCEEDED`. Render an initial-assessment preview at an iPhone 17 Pro size and verify Chinese text stays horizontal.

```bash
git add LIVELVL/LIVELVL/LifeState/AssessmentSettlement.swift \
  LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift \
  LIVELVL/LIVELVLTests/AssessmentSettlementTests.swift \
  LIVELVL/LIVELVL/ContentView.swift
git commit --only -m "feat: add life state assessment" -- \
  LIVELVL/LIVELVL/LifeState/AssessmentSettlement.swift \
  LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift \
  LIVELVL/LIVELVLTests/AssessmentSettlementTests.swift \
  LIVELVL/LIVELVL/ContentView.swift
```

---

### Task 4: Draw and verify the double-layer radar chart

**Files:**
- Create: `LIVELVL/LIVELVL/Today/RadarChartView.swift`
- Create: `LIVELVL/LIVELVL/Today/LevelCard.swift`
- Create: `LIVELVL/LIVELVL/Today/LifeStateCard.swift`
- Create: `LIVELVL/LIVELVLTests/RadarGeometryTests.swift`

**Interfaces:**
- Consumes: `LifeStateValues`, `LifeStateSummary`, `LifeDimension`.
- Produces: `RadarGeometry.points(...)`, `RadarPulse`, `RadarChartView`, `LevelCard`, and `LifeStateCard`.

- [ ] **Step 1: Write failing geometry tests**

```swift
import CoreGraphics
import Testing
@testable import LIVELVL

@MainActor
struct RadarGeometryTests {
    @Test func sixFullValuesProduceARealHexagonStartingAtTop() {
        let points = RadarGeometry.points(
            values: LifeStateValues(repeating: 10.0),
            center: CGPoint(x: 100, y: 100),
            radius: 80
        )
        #expect(points.count == 6)
        #expect(abs(points[0].x - 100) < 0.001)
        #expect(abs(points[0].y - 20) < 0.001)
        #expect(abs(points[3].x - 100) < 0.001)
        #expect(abs(points[3].y - 180) < 0.001)
    }

    @Test func scoreIsClampedBeforeConvertingToRadius() {
        let values = LifeStateValues(
            health: 12, learning: 10, career: 10,
            finance: 10, relationships: 10, interests: 10
        )
        let points = RadarGeometry.points(
            values: values, center: CGPoint(x: 50, y: 50), radius: 40
        )
        #expect(abs(points[0].y - 10) < 0.001)
    }
}
```

- [ ] **Step 2: Run tests and verify radar geometry is missing**

Run all tests. Expected: FAIL because `RadarGeometry` is undefined.

- [ ] **Step 3: Implement deterministic radar geometry and paths**

Create this geometry interface at the top of `RadarChartView.swift`:

```swift
import SwiftUI

enum RadarGeometry {
    static func points(
        values: LifeStateValues,
        center: CGPoint,
        radius: CGFloat
    ) -> [CGPoint] {
        LifeDimension.allCases.enumerated().map { index, dimension in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
            let normalized = CGFloat(min(10.0, max(1.0, values[dimension])) / 10.0)
            return CGPoint(
                x: center.x + cos(angle) * radius * normalized,
                y: center.y + sin(angle) * radius * normalized
            )
        }
    }

    static func path(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

struct RadarPulse: Identifiable, Equatable {
    let id = UUID()
    let dimension: LifeDimension
}
```

Build `RadarChartView(official:projected:pulse:)` with `GeometryReader`:

- Draw five closed grid paths for scores 2, 4, 6, 8, 10.
- Draw six center-to-vertex axis lines.
- Draw the official polygon with indigo solid stroke and low-opacity fill.
- Draw the projected polygon with a pale purple dashed stroke and no opaque fill.
- Place the six Chinese labels outside the maximum radius in `LifeDimension.allCases` order.
- Animate every projected-path value change over 0.25 seconds. When `pulse.id` changes after completion, additionally scale only the matching projected vertex marker from 1.0 to 1.28 and back within 0.35 seconds.
- If `@Environment(\.accessibilityReduceMotion)` is true, update the marker without scale animation.
- Combine the visual into one accessibility element whose value reads `综合状态 X；健康 X；学习 X；事业 X；财务 X；关系 X；兴趣 X；待结算变化……`.

- [ ] **Step 4: Implement the two card components**

`LevelCard` receives plain values so it has no persistence dependency:

```swift
struct LevelCard: View {
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int
    let progress: Double
}
```

It renders a charcoal rounded rectangle with `Lv.N`, `currentXP / requiredXP XP`, a purple progress bar, `还需 N XP 升级`, monospaced digits, and sufficient contrast.

`LifeStateCard` uses:

```swift
struct LifeStateCard: View {
    let summary: LifeStateSummary
    let pulse: RadarPulse?
    let onAssessment: () -> Void
}
```

It renders `你的最近 15 天`, `综合状态 X.X`, the double radar, a two-item legend (`正式状态` / `行动预估`), and one annotation. Format annotations exactly as:

```swift
if let change = summary.highlightedChange {
    let sign = change.delta > 0 ? "+" : ""
    Text("\(change.dimension.title)预计 \(sign)\(change.delta, format: .number.precision(.fractionLength(1)))，来自「\(change.sourceTitle ?? "最近行动")」，待下次自测确认。")
} else {
    Text("完成现实行动后，这里会显示待结算的状态变化。")
}
```

When `summary.isAssessmentDue`, show a native bordered button `更新本周状态`; otherwise show `距离下次自评还有 N 天`. Add this exact helper to `LifeStateEngine`:

```swift
static func daysUntilAssessment(
    lastAssessedAt: Date,
    now: Date,
    calendar: Calendar = .current
) -> Int {
    guard let dueDate = calendar.date(byAdding: .day, value: 7, to: lastAssessedAt),
          now < dueDate else { return 0 }
    let start = calendar.startOfDay(for: now)
    let dueDay = calendar.startOfDay(for: dueDate)
    return max(1, calendar.dateComponents([.day], from: start, to: dueDay).day ?? 1)
}
```

Add this test to `LifeStateEngineTests.swift`:

```swift
@Test func daysUntilAssessmentNeverShowsZeroBeforeDueTime() {
    #expect(LifeStateEngine.daysUntilAssessment(
        lastAssessedAt: date(13, hour: 13),
        now: date(20, hour: 12),
        calendar: calendar
    ) == 1)
    #expect(LifeStateEngine.daysUntilAssessment(
        lastAssessedAt: date(13, hour: 12),
        now: date(20, hour: 12),
        calendar: calendar
    ) == 0)
}
```

- [ ] **Step 5: Add deterministic previews and visual checks**

Add `#Preview("C+ Home Cards")` using official values `[6.2, 5.8, 6.5, 5.2, 6.8, 7.1]`, projected learning `6.1`, and an annotation from `阅读 30 分钟`. Add a second `#Preview("Large Text")` using `.environment(\.dynamicTypeSize, .accessibility2)`.

Expected visual behavior: all text is horizontal; the radar is a true hexagon; solid and dashed layers remain distinguishable without relying only on fill color; neither card clips at iPhone 17 Pro width.

- [ ] **Step 6: Test, build, and commit Task 4**

Run all tests and the simulator build. Expected: PASS and `BUILD SUCCEEDED`.

```bash
git add LIVELVL/LIVELVL/Today/RadarChartView.swift \
  LIVELVL/LIVELVL/Today/LevelCard.swift \
  LIVELVL/LIVELVL/Today/LifeStateCard.swift \
  LIVELVL/LIVELVLTests/RadarGeometryTests.swift \
  LIVELVL/LIVELVL/Domain/LifeStateEngine.swift \
  LIVELVL/LIVELVLTests/LifeStateEngineTests.swift
git commit --only -m "feat: add double layer life state radar" -- \
  LIVELVL/LIVELVL/Today/RadarChartView.swift \
  LIVELVL/LIVELVL/Today/LevelCard.swift \
  LIVELVL/LIVELVL/Today/LifeStateCard.swift \
  LIVELVL/LIVELVLTests/RadarGeometryTests.swift \
  LIVELVL/LIVELVL/Domain/LifeStateEngine.swift \
  LIVELVL/LIVELVLTests/LifeStateEngineTests.swift
```

---

### Task 5: Integrate the C+ homepage and immediate pending-growth feedback

**Files:**
- Create: `LIVELVL/LIVELVL/Today/TodayView.swift`
- Create: `LIVELVL/LIVELVL/Today/AddTaskView.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift:14-151`
- Modify: `LIVELVL/LIVELVL/Item.swift` (completion initializer call sites only if still present)

**Interfaces:**
- Consumes: `LevelCard`, `LifeStateCard`, `LifeStateSummaryBuilder`, `StateAssessmentView`, all existing task and XP behavior.
- Produces: the finished homepage and task-to-radar pulse integration.

- [ ] **Step 1: Extract existing task creation without changing its behavior**

Move `AddTaskView` from `ContentView.swift` into `Today/AddTaskView.swift`. Keep title validation, dimension, recurrence, minutes, difficulty and recommended XP behavior unchanged. Build immediately.

Expected: `BUILD SUCCEEDED`; creating a task still saves it through the existing model context.

- [ ] **Step 2: Create the new homepage composition**

Move `TodayView` into `Today/TodayView.swift` and replace the outer `List` with one vertical `ScrollView` and a non-lazy `VStack` because the home content is small and mixed-layout. Use this order:

```swift
ScrollView {
    VStack(spacing: 16) {
        LevelCard(...)
        if let summary {
            LifeStateCard(summary: summary, pulse: radarPulse) {
                presentedSheet = .assessment
            }
        }
        todayActionsSection
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 28)
}
```

Populate `LevelCard` with level-relative XP, not lifetime XP:

```swift
let totalXP = progressItems.first?.totalXP ?? 0
LevelCard(
    level: GrowthEngine.level(for: totalXP),
    currentXP: GrowthEngine.xpInCurrentLevel(for: totalXP),
    requiredXP: GrowthEngine.xpNeededForNextLevel(for: totalXP),
    remainingXP: GrowthEngine.xpNeededForNextLevel(for: totalXP)
        - GrowthEngine.xpInCurrentLevel(for: totalXP),
    progress: GrowthEngine.progressToNextLevel(for: totalXP)
)
```

Add `@Query` collections for `DimensionProfile` and reverse-sorted `StateSnapshot`. Build the summary from the latest snapshot and completion metadata:

```swift
private var lifeStateSummary: LifeStateSummary? {
    guard let snapshot = snapshots.first else { return nil }
    let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    let records = completions.compactMap { completion in
        completion.stateActivity(fallbackItem: itemByID[completion.itemID])
    }
    return LifeStateSummaryBuilder.build(
        profiles: profiles,
        snapshot: snapshot,
        activities: records,
        now: .now
    )
}
```

Use an item-driven sheet enum instead of multiple booleans:

```swift
private enum TodaySheet: String, Identifiable {
    case addTask, assessment
    var id: String { rawValue }
}
```

Map `.addTask` to `AddTaskView()` and `.assessment` to `StateAssessmentView(mode: .weekly)` with `.sheet(item:)`.

- [ ] **Step 3: Make progress creation persistent and completion idempotent**

Remove `progressItems.first ?? Progress()`, because it can mutate an uninserted temporary model. Display XP from `progressItems.first?.totalXP ?? 0` and add:

```swift
@discardableResult
private func storedProgress() -> Progress {
    if let existing = progressItems.first { return existing }
    let created = Progress()
    context.insert(created)
    return created
}
```

In `confirmCompletion()`, guard again against a same-day completion before inserting. Capture metadata in the record:

```swift
guard !isCompleted(item) else { return }
let completion = Completion(
    itemID: item.id,
    xp: item.xp,
    dimension: item.dimension,
    taskTitle: item.title
)
context.insert(completion)
storedProgress().totalXP += item.xp
radarPulse = RadarPulse(dimension: item.dimension)
feedbackMessage = "获得 +\(item.xp) XP · \(item.dimension.title)预增长已记录"
try? context.save()
```

Undo must delete exactly the matching same-day `Completion`, subtract its stored XP with a zero floor, clear `radarPulse`, and show `已取消完成，退回 N XP`. The dashed path retracts through its normal 0.25-second value animation, without a success pulse.

- [ ] **Step 4: Replace the second blocking alert with a light feedback banner**

Keep the confirmation alert before first completion. Replace the result alert with a top overlay or `safeAreaInset(edge: .top)` banner driven by one optional `FeedbackMessage: Identifiable`. Auto-dismiss after 1.8 seconds using a cancellable `.task(id:)`; the banner must remain readable by VoiceOver and must not block task undo. Use this behavior so a newer message cancels the older timer:

```swift
.task(id: feedbackMessage?.id) {
    guard feedbackMessage != nil else { return }
    try? await Task.sleep(for: .seconds(1.8))
    withAnimation { feedbackMessage = nil }
}
```

Trigger one subtle success haptic only after confirmed completion. Do not haptic-loop during radar animation; do not add a settings screen for haptics in this feature.

- [ ] **Step 5: Verify the core interaction manually**

On iPhone 17 Pro Simulator:

1. Note the official and projected learning values.
2. Create `阅读 30 分钟`, Learning, 30 minutes, difficulty 3.
3. Confirm completion.
4. Verify XP increases immediately, official polygon stays fixed, the learning dashed vertex pulses outward, and the source sentence names the task.
5. Tap the completed checkmark again.
6. Verify XP returns exactly, the completion mark clears, and the dashed vertex returns to its previous position.
7. Stop and relaunch the app; verify tasks, XP, profiles and official state remain.

- [ ] **Step 6: Run regression tests, build, and commit Task 5**

Run all test and build commands. Expected: PASS and `BUILD SUCCEEDED`.

```bash
git add LIVELVL/LIVELVL/Today/TodayView.swift \
  LIVELVL/LIVELVL/Today/AddTaskView.swift \
  LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVL/Item.swift
git commit --only -m "feat: integrate home growth feedback" -- \
  LIVELVL/LIVELVL/Today/TodayView.swift \
  LIVELVL/LIVELVL/Today/AddTaskView.swift \
  LIVELVL/LIVELVL/ContentView.swift LIVELVL/LIVELVL/Item.swift
```

---

### Task 6: Finish Growth detail, weekly settlement, accessibility, and end-to-end verification

**Files:**
- Create: `LIVELVL/LIVELVL/Growth/GrowthView.swift`
- Create: `LIVELVL/LIVELVL/Profile/ProfileView.swift`
- Modify: `LIVELVL/LIVELVL/ContentView.swift` (remove old inline `GrowthView` and `ProfileView`)
- Modify: `LIVELVL/LIVELVL/Today/LifeStateCard.swift`
- Modify: `LIVELVL/LIVELVL/Today/RadarChartView.swift`
- Modify: `LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift`
- Test: all files under `LIVELVL/LIVELVLTests/`

**Interfaces:**
- Consumes: all state, assessment, level and projection interfaces from Tasks 1–5.
- Produces: a complete user-visible path for inspecting six scores and settling projected changes.

- [ ] **Step 1: Build Growth as a state explanation screen**

Create `GrowthView` with the same profile/snapshot/completion queries and summary-building method as `TodayView`. Use a native `List` because this page is explanatory rows:

```text
Section: 长期等级
  Lv.N
  current / required XP and progress

Section: 最近 15 天状态
  综合状态 X.X
  健康  正式 X.X  预计 X.X
  学习  正式 X.X  预计 X.X
  ...six dimensions

Section: 状态更新
  更新本周状态 / 距离下次自评还有 N 天

Section: 说明
  等级记录长期积累；状态只描述最近 15 天，不构成医学、心理或财务评估。
```

Present weekly assessment with `.sheet(item:)`. Disable early assessment until seven days have elapsed; never update a snapshot merely by opening this screen.

Move the existing `ProfileView` implementation unchanged into `Profile/ProfileView.swift`, leaving `ContentView.swift` responsible only for the snapshot gate and three-tab shell.

- [ ] **Step 2: Verify weekly settlement with a focused integration test**

Add a test to `AssessmentSettlementTests.swift` that starts with official 6.0 and baseline action 5.0, projects current action 5.8 to 6.3, then submits a weekly self-rating of 6.0 and verifies the new official result is 5.9 (`6.0 × 0.6 + 5.8 × 0.4 = 5.92`) and the new projection equals 5.9 because its baseline action is also 5.8.

Use exact assertions:

```swift
#expect(result.officialScores.learning == 5.9)
#expect(LifeStateEngine.projectedScore(
    officialScore: result.officialScores.learning,
    baselineActionScore: result.baselineActionScores.learning,
    currentActionScore: 5.8
) == 5.9)
```

Run tests. Expected: PASS.

- [ ] **Step 3: Complete accessibility and reduced-motion behavior**

Verify and adjust:

- Level progress exposes `等级 N，当前 current，共需 required，还差 remaining XP`.
- Every task button says either `完成任务，任务名` or `取消完成，任务名`.
- Radar exposes all six official values and the highlighted projected delta as text.
- Dashed projection has a legend and is not distinguished by color alone.
- At Dynamic Type accessibility2, the cards grow vertically and no label becomes one-character-per-line.
- With Reduce Motion enabled, the projected shape updates without pulse scaling.

Add accessibility identifiers `level-card`, `life-state-card`, `radar-chart`, `assessment-next`, and `assessment-save` for repeatable simulator inspection.

- [ ] **Step 4: Run the full acceptance matrix**

Run:

```bash
xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/LIVELVLStateDerived CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath /tmp/LIVELVLStateBuild CODE_SIGNING_ALLOWED=NO
```

Expected: all tests PASS and `BUILD SUCCEEDED`.

Then verify on iPhone 17 Pro Simulator:

- Day 0 requires exactly six pages and produces six persisted values.
- Home shows the dark level card above a true six-sided radar card.
- XP text uses `current / required XP`, not lifetime XP alone.
- One completion changes XP and projected State immediately but not official State.
- Undo restores XP and projected State.
- Activities on all 15 included days are equal; day 16 is absent from calculation.
- Weekly assessment changes official State once and causes projected and official polygons to overlap.
- Relaunch preserves task, completion, XP, profiles, targets, and snapshot.
- No reset, login, network request, third-party package, social, store, AI or character system appears.

- [ ] **Step 5: Commit the finished feature paths**

```bash
git add LIVELVL/LIVELVL/Growth/GrowthView.swift \
  LIVELVL/LIVELVL/Profile/ProfileView.swift \
  LIVELVL/LIVELVL/ContentView.swift \
  LIVELVL/LIVELVL/Today/LifeStateCard.swift \
  LIVELVL/LIVELVL/Today/RadarChartView.swift \
  LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift \
  LIVELVL/LIVELVLTests
git commit --only -m "feat: finish weekly life state experience" -- \
  LIVELVL/LIVELVL/Growth/GrowthView.swift \
  LIVELVL/LIVELVL/Profile/ProfileView.swift \
  LIVELVL/LIVELVL/ContentView.swift \
  LIVELVL/LIVELVL/Today/LifeStateCard.swift \
  LIVELVL/LIVELVL/Today/RadarChartView.swift \
  LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift \
  LIVELVL/LIVELVLTests
```

---

## Completion Gate

Before declaring the feature complete:

1. Run `git status --short` and confirm unrelated pre-existing changes are still present and untouched.
2. Run the complete test suite and simulator build one final time.
3. Inspect the app on iPhone 17 Pro in normal text, accessibility2 text, light mode, dark mode, and Reduce Motion.
4. Confirm the implementation matches every acceptance line in the linked design spec.
5. Use `superpowers:verification-before-completion` before reporting success.
