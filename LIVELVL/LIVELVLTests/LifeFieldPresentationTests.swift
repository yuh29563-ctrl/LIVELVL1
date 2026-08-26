import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeFieldPresentationTests {
    @Test func nodesUseTheSixRealDomainsInStableOrder() {
        let official = LifeStateValues(
            health: 7.8,
            learning: 8.6,
            career: 8.3,
            finance: 6.4,
            relationships: 7.9,
            interests: 8.0
        )
        var projected = official
        projected.health = 8.0
        projected.finance = 6.1

        let nodes = LifeFieldNodePresentation.make(
            official: official,
            projected: projected
        )

        #expect(nodes.map(\.dimension) == LifeDimension.allCases)
        #expect(nodes.map(\.title) == ["健康", "学习", "事业", "财务", "关系", "兴趣"])
        #expect(nodes.map(\.displayValue) == [78, 86, 83, 64, 79, 80])
        #expect(nodes.first?.projectedDisplayValue == 80)
        #expect(nodes.first?.delta == 2)
        #expect(nodes[3].delta == -3)
    }

    @Test func summaryNodesExposeRealSourceAndAssessmentTiming() throws {
        let official = LifeStateValues(repeating: 7)
        var projected = official
        projected.learning = 7.4
        let dimensions = LifeDimension.allCases.map { dimension in
            DimensionStateSummary(
                dimension: dimension,
                officialScore: official[dimension],
                projectedScore: projected[dimension],
                delta: projected[dimension] - official[dimension],
                sourceTitle: dimension == .learning ? "阅读 20 分钟" : nil
            )
        }
        let summary = LifeStateSummary(
            official: official,
            projected: projected,
            overallScore: 7,
            dimensions: dimensions,
            highlightedChange: dimensions.first { $0.dimension == .learning },
            daysUntilAssessment: 3,
            isAssessmentDue: false
        )

        let learning = try #require(
            LifeFieldNodePresentation.make(summary: summary)
                .first { $0.dimension == .learning }
        )

        #expect(learning.sourceText == "来自 阅读 20 分钟")
        #expect(learning.assessmentText == "距下次评估 3 天")
        #expect(learning.projectedDisplayValue == 74)
    }

    @Test func tappingTheSameNodeClosesDetail() {
        var state = LifeFieldSelectionState()
        state.toggle(.health)
        #expect(state.selectedDimension == .health)
        state.toggle(.health)
        #expect(state.selectedDimension == nil)
    }

    @Test func staleSelectionClearsWhenItsDimensionIsUnavailable() {
        var state = LifeFieldSelectionState(selectedDimension: .finance)
        state.reconcile(available: [.health, .learning])
        #expect(state.selectedDimension == nil)
    }
}
