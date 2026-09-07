import Foundation
import SwiftUI
import Testing
import UIKit
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

    @Test func approvedSixPointLayoutKeepsSemanticDomainsAtReferenceAnchors() {
        let expected: [LifeDimension: CGPoint] = [
            .health: CGPoint(x: 0.50, y: 0.06),
            .learning: CGPoint(x: 0.837749907475931, y: 0.255),
            .finance: CGPoint(x: 0.837749907475931, y: 0.645),
            .relationships: CGPoint(x: 0.50, y: 0.84),
            .career: CGPoint(x: 0.162250092524069, y: 0.645),
            .interests: CGPoint(x: 0.162250092524069, y: 0.255)
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

    @Test func fieldEdgesFollowTheVisualClockwiseOrderAndCloseTheHexagon() {
        let edges = LifeFieldEdge.ordered

        #expect(edges == [
            LifeFieldEdge(start: .health, end: .learning),
            LifeFieldEdge(start: .learning, end: .finance),
            LifeFieldEdge(start: .finance, end: .relationships),
            LifeFieldEdge(start: .relationships, end: .career),
            LifeFieldEdge(start: .career, end: .interests),
            LifeFieldEdge(start: .interests, end: .health),
        ])
    }

    @Test func displayedOuterFieldIsARegularHexagonInTheTodayLayout() {
        let size = CGSize(width: 368, height: 360)
        let points = LifeFieldEdge.ordered.map {
            LifeFieldLayout.point(for: $0.start, in: size)
        }
        let sideLengths = zip(points, points.dropFirst() + [points[0]]).map {
            hypot($0.x - $1.x, $0.y - $1.y)
        }

        let reference = try! #require(sideLengths.first)
        #expect(sideLengths.allSatisfy { abs($0 - reference) < 0.01 })
    }

    @Test func edgeSegmentsFollowDynamicOfficialPointsInsteadOfTheVisualCore() {
        let targets: [LifeDimension: CGPoint] = [
            .health: CGPoint(x: 0.50, y: 0.255),
            .learning: CGPoint(x: 0.68, y: 0.3525),
            .finance: CGPoint(x: 0.86, y: 0.645),
            .relationships: CGPoint(x: 0.50, y: 0.645),
            .career: CGPoint(x: 0.23, y: 0.59625),
            .interests: CGPoint(x: 0.32, y: 0.3525),
        ]

        let segments = LifeFieldEdgeParticleGeometry.segments(targets: targets)

        #expect(segments.count == 6)
        #expect(segments.first?.start == targets[.health])
        #expect(segments.first?.end == targets[.learning])
        #expect(segments.last?.start == targets[.interests])
        #expect(segments.last?.end == targets[.health])
        #expect(segments.allSatisfy {
            $0.start != LifeFieldLayout.visualCore
                && $0.end != LifeFieldLayout.visualCore
        })
    }

    @Test func edgeParticlesFlowNormallyAndFreezeForReduceMotion() {
        let targets = Dictionary(
            uniqueKeysWithValues: LifeDimension.allCases.map {
                ($0, LifeFieldLayout.anchor(for: $0, score: 50))
            }
        )
        let movingA = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 0,
            reduceMotion: false,
            targets: targets
        )
        let movingB = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 0.4,
            reduceMotion: false,
            targets: targets
        )
        let frozenA = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 0,
            reduceMotion: true,
            targets: targets
        )
        let frozenB = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 0.8,
            reduceMotion: true,
            targets: targets
        )

        #expect(movingA.count == 108)
        #expect(movingA != movingB)
        #expect(frozenA == frozenB)
        #expect(Set(movingA.map(\.edge)).count == 6)
    }

    @Test func edgeParticlesRemainContinuousAcrossPhaseCycleBoundaries() {
        let targets = Dictionary(
            uniqueKeysWithValues: LifeDimension.allCases.map {
                ($0, LifeFieldLayout.anchor(for: $0, score: 50))
            }
        )
        let beforeBoundary = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 0.999,
            reduceMotion: false,
            targets: targets
        )
        let afterBoundary = LifeFieldEdgeParticleGeometry.samples(
            countPerEdge: 18,
            phase: 1.001,
            reduceMotion: false,
            targets: targets
        )
        let maximumTravel = zip(beforeBoundary, afterBoundary)
            .map { hypot(
                $0.position.x - $1.position.x,
                $0.position.y - $1.position.y
            ) }
            .max() ?? .infinity

        #expect(maximumTravel < 0.01)
    }

    @Test func scoreAnchorsMapZeroFiftyAndHundredToDistinctRadii() {
        let zero = LifeFieldLayout.anchor(for: .health, score: 0)
        let fifty = LifeFieldLayout.anchor(for: .health, score: 50)
        let hundred = LifeFieldLayout.anchor(for: .health, score: 100)

        #expect(zero == CGPoint(x: 0.50, y: 0.45))
        #expect(fifty == CGPoint(x: 0.50, y: 0.255))
        #expect(hundred == CGPoint(x: 0.50, y: 0.06))
        #expect(hypot(fifty.x - 0.50, fifty.y - 0.45) > 0)
        #expect(
            hypot(hundred.x - 0.50, hundred.y - 0.45)
                > hypot(fifty.x - 0.50, fifty.y - 0.45)
        )
    }

    @Test func scoreAnchorsClampValuesOutsideTheDisplayRange() {
        #expect(
            LifeFieldLayout.anchor(for: .learning, score: -25)
                == CGPoint(x: 0.50, y: 0.45)
        )
        let maximum = LifeFieldLayout.anchor(for: .learning, score: 125)
        #expect(abs(maximum.x - 0.837749907475931) < 0.000_001)
        #expect(abs(maximum.y - 0.255) < 0.000_001)
    }

    @Test func radialLinksLayerBetweenBackdropAndDynamicFieldGeometry() {
        #expect(LifeFieldLayerOrder.backdropDots < LifeFieldLayerOrder.radialLinks)
        #expect(LifeFieldLayerOrder.radialLinks < LifeFieldLayerOrder.dynamicEdges)
        #expect(LifeFieldLayerOrder.dynamicEdges < LifeFieldLayerOrder.controls)
    }

    @Test func accessibilitySizesPresentDimensionDetailsOutsideTheCrowdedField() {
        #expect(
            LifeFieldDetailPresentation.style(isAccessibilitySize: false) == .inline
        )
        #expect(
            LifeFieldDetailPresentation.style(isAccessibilitySize: true) == .sheet
        )
    }

    @Test func accessibilityDetailProvidesAScrollContainerForLongSources() async {
        let value = LifeFieldNodePresentation(
            dimension: .learning,
            title: "专注",
            displayValue: 50,
            projectedDisplayValue: 62,
            delta: 12,
            sourceText: "来自 \(String(repeating: "非常长的任务名称", count: 24))",
            assessmentText: "距下次评估 7 天"
        )
        let host = UIHostingController(
            rootView: LifeFieldDimensionDetailSheet(value: value)
                .dynamicTypeSize(.accessibility2)
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        try? await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()

        #expect(
            containsAccessibilityIdentifier(
                "life-field-detail-scroll",
                in: host.view
            )
        )
    }

    @Test func officialAndProjectedNodeAnchorsRemainIndependent() throws {
        let official = LifeStateValues(
            health: 2,
            learning: 5,
            career: 5,
            finance: 5,
            relationships: 5,
            interests: 5
        )
        var projected = official
        projected.health = 8
        let node = try #require(
            LifeFieldNodePresentation.make(official: official, projected: projected).first
        )
        let anchors = LifeFieldLayout.anchors(for: node)

        #expect(abs(anchors.official.x - 0.50) < 0.000_001)
        #expect(abs(anchors.official.y - 0.372) < 0.000_001)
        #expect(abs(anchors.projected.x - 0.50) < 0.000_001)
        #expect(abs(anchors.projected.y - 0.138) < 0.000_001)
        #expect(anchors.official != anchors.projected)
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
        let size = CGSize(width: 368, height: 360)
        let expected: [LifeDimension: CGPoint] = [
            .health: CGPoint(x: 184.00, y: 21.60),
            .learning: CGPoint(x: 305.59, y: 91.80),
            .finance: CGPoint(x: 305.59, y: 232.20),
            .relationships: CGPoint(x: 184.00, y: 302.40),
            .career: CGPoint(x: 62.41, y: 232.20),
            .interests: CGPoint(x: 62.41, y: 91.80)
        ]

        for dimension in LifeDimension.allCases {
            let point = LifeFieldLayout.point(for: dimension, in: size)
            #expect(abs(point.x - (expected[dimension]?.x ?? -1)) < 0.01)
            #expect(abs(point.y - (expected[dimension]?.y ?? -1)) < 0.01)
        }
    }

    @Test func innerAndOuterHexagonsUseTheApprovedQuietContrast() {
        #expect(LifeFieldPolygonPresentation.outerTone == .subtle)
        #expect(LifeFieldPolygonPresentation.innerTone == .strong)
        #expect(LifeFieldPolygonPresentation.outerOpacity == 0.18)
        #expect(LifeFieldPolygonPresentation.innerOpacity == 0.28)
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

    @Test func renderedRadialLinksTargetTheFixedOuterHexagon() {
        let targets = LifeFieldRadialLinkPresentation.targets

        for dimension in LifeDimension.allCases {
            #expect(targets[dimension] == LifeFieldLayout.anchor(for: dimension))
            #expect(targets[dimension] != LifeFieldLayout.anchor(for: dimension, score: 50))
        }
    }

    @Test func radialParticleColorTreatmentIsQuieterWithoutChangingSamples() {
        #expect(LifeFieldRadialLinkPresentation.renderedOpacity(for: 0.5) == 0.18)
        #expect(LifeFieldRadialLinkPresentation.renderedOpacity(for: 0) == 0)
        #expect(LifeFieldRadialLinkPresentation.renderedOpacity(for: 1) == 0.36)
    }

    @Test func particleLinksTerminateAtDynamicOfficialNodePositions() {
        let targets = Dictionary(
            uniqueKeysWithValues: LifeDimension.allCases.map {
                ($0, LifeFieldLayout.anchor(for: $0, score: 50))
            }
        )
        let samples = LifeFieldParticleLinkGeometry.samples(
            countPerLink: 24,
            phase: 0.2,
            reduceMotion: false,
            targets: targets
        )

        for dimension in LifeDimension.allCases {
            let terminal = samples.last { $0.dimension == dimension }
            #expect(terminal?.position == targets[dimension])
            #expect(terminal?.position != LifeFieldLayout.anchor(for: dimension))
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
        #expect(
            learning.accessibilityValue
                == "当前 70，预测 74，来自 阅读 20 分钟，距下次评估 3 天"
        )
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

    private func containsAccessibilityIdentifier(_ identifier: String, in view: UIView) -> Bool {
        if view.accessibilityIdentifier == identifier { return true }
        if let elements = view.accessibilityElements,
           elements.contains(where: { element in
               (element as? UIAccessibilityElement)?.accessibilityIdentifier == identifier
           }) {
            return true
        }
        return view.subviews.contains {
            containsAccessibilityIdentifier(identifier, in: $0)
        }
    }
}
