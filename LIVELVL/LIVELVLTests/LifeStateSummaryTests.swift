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
