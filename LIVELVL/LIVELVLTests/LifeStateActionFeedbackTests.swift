import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeStateActionFeedbackTests {
    @Test func voiceOverReadsActionDayProgressEvenForZeroXP() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = StateSnapshot(scores: .neutral,
            actionScores: LifeStateValues(repeating: 0), assessedAt: now)
        let summary = LifeStateSummaryBuilder.build(profiles: [], snapshot: snapshot,
            activities: [DimensionActivityRecord(dimension: .health, taskTitle: "锻炼",
                date: now, xp: 0)], now: now)
        let node = try #require(LifeFieldNodePresentation.make(summary: summary).first { $0.dimension == .health })
        #expect(node.accessibilityValue.contains("十五天行动 1/7 天"))
    }
    @Test func actionDayReportsBeforeAfterAndActualIncrease() {
        let before = DimensionStateSummary(dimension: .health, officialScore: 6.5,
            projectedScore: 6.5, delta: 0, sourceTitle: nil, actionDays: 0, targetDays: 7)
        let after = DimensionStateSummary(dimension: .health, officialScore: 6.5,
            projectedScore: 6.5 + 1.0 / 7, delta: 1.0 / 7, sourceTitle: "训练", actionDays: 1, targetDays: 7)
        let feedback = LifeStateActionFeedback(before: before, after: after)
        #expect(feedback.text.contains("65.0 → 66.4"))
        #expect(feedback.text.contains("+1.4"))
        #expect(feedback.text.contains("1/7"))
    }

    @Test func sameDayAndMaximumScoreDoNotInventGrowth() {
        let value = DimensionStateSummary(dimension: .learning, officialScore: 10,
            projectedScore: 10, delta: 0, sourceTitle: "阅读", actionDays: 2, targetDays: 7)
        let feedback = LifeStateActionFeedback(before: value, after: value)
        #expect(!feedback.text.contains("+"))
        #expect(feedback.text.contains("已记录"))
        #expect(feedback.text.contains("2/7"))
    }
}
