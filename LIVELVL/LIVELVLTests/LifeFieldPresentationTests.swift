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
        #expect(nodes.map(\.title) == ["身体", "专注", "成长", "秩序", "连接", "恢复"])
        #expect(nodes.map(\.displayValue) == [78, 86, 83, 64, 79, 80])
        #expect(nodes.first?.projectedDisplayValue == 80)
        #expect(nodes.first?.delta == 2)
        #expect(nodes[3].delta == -3)
    }

    @Test func approvedSixPointLayoutKeepsSemanticDomainsAtReferenceAnchors() {
        let expected: [LifeDimension: CGPoint] = [
            .health: CGPoint(x: 0.50, y: 0.06),
            .learning: CGPoint(x: 0.86, y: 0.255),
            .finance: CGPoint(x: 0.86, y: 0.645),
            .relationships: CGPoint(x: 0.50, y: 0.84),
            .career: CGPoint(x: 0.14, y: 0.645),
            .interests: CGPoint(x: 0.14, y: 0.255)
        ]
        for dimension in LifeDimension.allCases {
            let anchor = LifeFieldLayout.anchor(for: dimension)
            #expect(abs(anchor.x - (expected[dimension]?.x ?? -1)) < 0.000_001)
            #expect(abs(anchor.y - (expected[dimension]?.y ?? -1)) < 0.000_001)
        }
        #expect(LifeFieldLayout.labelPlacement(for: .health) == .above)
        #expect(LifeFieldLayout.labelPlacement(for: .relationships) == .below)
        #expect(LifeFieldLayout.labelPlacement(for: .career) == .below)
    }

    @Test func everyOpposingNodePairSharesTheExactVisualCore() {
        let opposingPairs: [(LifeDimension, LifeDimension)] = [
            (.health, .relationships),
            (.learning, .career),
            (.finance, .interests)
        ]

        for (first, second) in opposingPairs {
            let firstPoint = LifeFieldLayout.anchor(for: first)
            let secondPoint = LifeFieldLayout.anchor(for: second)
            let midpoint = CGPoint(
                x: (firstPoint.x + secondPoint.x) / 2,
                y: (firstPoint.y + secondPoint.y) / 2
            )
            #expect(abs(midpoint.x - LifeFieldLayout.visualCore.x) < 0.000_001)
            #expect(abs(midpoint.y - LifeFieldLayout.visualCore.y) < 0.000_001)
        }
    }

    @Test func referenceHexagonVerticesMapToTheApprovedIPhoneField() {
        let size = CGSize(width: 368, height: 492)
        let expected: [LifeDimension: CGPoint] = [
            .health: CGPoint(x: 184.00, y: 29.52),
            .learning: CGPoint(x: 316.48, y: 125.46),
            .finance: CGPoint(x: 316.48, y: 317.34),
            .relationships: CGPoint(x: 184.00, y: 413.28),
            .career: CGPoint(x: 51.52, y: 317.34),
            .interests: CGPoint(x: 51.52, y: 125.46)
        ]

        for dimension in LifeDimension.allCases {
            let point = LifeFieldLayout.point(for: dimension, in: size)
            #expect(abs(point.x - (expected[dimension]?.x ?? -1)) < 0.01)
            #expect(abs(point.y - (expected[dimension]?.y ?? -1)) < 0.01)
        }
    }

    @Test func sixParticleLinksRunFromTheVisualCoreToTheExactHexagonNodes() {
        let samples = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 24,
            phase: 0.2,
            reduceMotion: false
        )

        #expect(samples.count == LifeDimension.allCases.count * 24)
        for dimension in LifeDimension.allCases {
            let origin = samples.first { $0.dimension == dimension }
            let target = LifeFieldLayout.anchor(for: dimension)
            let terminal = samples.last { $0.dimension == dimension }
            #expect(origin?.position == CGPoint(x: 0.50, y: 0.45))
            #expect(terminal != nil)
            #expect(abs((terminal?.position.x ?? 0) - target.x) < 0.02)
            #expect(abs((terminal?.position.y ?? 0) - target.y) < 0.02)
        }
    }

    @Test func everyConnectorKeepsEnoughVisibleParticlesBetweenCoreAndNode() {
        let samples = LifeFieldParticleLinkGeometry.presentationSamples(
            phase: 0.2,
            reduceMotion: false
        )

        #expect(samples.count >= LifeDimension.allCases.count * 84)
        for dimension in LifeDimension.allCases {
            let visible = samples.filter {
                $0.dimension == dimension && $0.opacity >= 0.24 && $0.diameter >= 1
            }
            #expect(visible.count >= 72)
        }
    }

    @Test func linkParticlesDriftNormallyAndFreezeForReduceMotion() {
        let movingA = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 18,
            phase: 0,
            reduceMotion: false
        )
        let movingB = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 18,
            phase: 0.4,
            reduceMotion: false
        )
        let frozenA = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 18,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 18,
            phase: 0.8,
            reduceMotion: true
        )

        #expect(movingA != movingB)
        #expect(frozenA == frozenB)
        #expect(movingB.allSatisfy {
            (0...1).contains($0.position.x) && (0...1).contains($0.position.y)
        })
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
