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
