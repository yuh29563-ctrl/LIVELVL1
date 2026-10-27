import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeStateSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_776_672_000)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

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
        #expect(abs(summary.projected.learning - (6 + 1.0 / 7.0)) < 0.00001)
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

    @Test func summaryReportsOneDayBeforeExactDueTime() {
        let snapshot = StateSnapshot(
            scores: .neutral,
            actionScores: .neutral,
            assessedAt: date(5, hour: 13)
        )

        let summary = LifeStateSummaryBuilder.build(
            profiles: [],
            snapshot: snapshot,
            activities: [],
            now: date(19, hour: 12),
            calendar: calendar
        )

        #expect(summary.daysUntilAssessment == 1)
        #expect(!summary.isAssessmentDue)
    }

    @Test func summaryReportsDueAtExactTime() {
        let snapshot = StateSnapshot(
            scores: .neutral,
            actionScores: .neutral,
            assessedAt: date(5, hour: 12)
        )

        let summary = LifeStateSummaryBuilder.build(
            profiles: [],
            snapshot: snapshot,
            activities: [],
            now: date(20, hour: 12),
            calendar: calendar
        )

        #expect(summary.daysUntilAssessment == 0)
        #expect(summary.isAssessmentDue)
    }

    @Test func newSnapshotBaselineSurvivesActionExpiryAndIsNeverCompounded() throws {
        let snapshot = StateSnapshot(scores: LifeStateValues(repeating: 7.3),
            actionScores: LifeStateValues(repeating: 0.8), assessedAt: date(20, hour: 12))
        snapshot.selfRatingsData = try JSONEncoder().encode(LifeStateValues(repeating: 6.5))
        let record = DimensionActivityRecord(dimension: .health, taskTitle: "旧训练",
            date: date(6, hour: 12), xp: 0)
        let first = LifeStateSummaryBuilder.build(profiles: [], snapshot: snapshot,
            activities: [record], now: date(20, hour: 12), calendar: calendar)
        #expect(abs(first.projected.health - (6.5 + 1.0 / 7)) < 0.00001)
        let expired = LifeStateSummaryBuilder.build(profiles: [], snapshot: snapshot,
            activities: [record], now: date(21, hour: 12), calendar: calendar)
        #expect(expired.projected.health == 6.5)
        #expect(expired.dimensions.first?.sourceTitle == nil)
        #expect(snapshot.scores.health == 7.3)
    }
}
