import CoreGraphics
import Foundation
import Testing
@testable import LIVELVL

struct CompanionPointCloudMotionTests {
    @Test func transparentRasterIsRenderedDirectlyOnlyWhenSourceDataExists() {
        #expect(
            CompanionArtworkLayerKind.resolve(
                renderMode: .transparentRaster,
                hasSourceImageData: true
            ) == .transparentRaster
        )
        #expect(
            CompanionArtworkLayerKind.resolve(
                renderMode: .transparentRaster,
                hasSourceImageData: false
            ) == .pointCloud
        )
        #expect(
            CompanionArtworkLayerKind.resolve(
                renderMode: .pointCloud,
                hasSourceImageData: true
            ) == .pointCloud
        )
    }

    @Test func collapsedMotionMovesNormallyAndFreezesForReduceMotion() {
        let movingA = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0,
            reduceMotion: false
        )
        let movingB = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0.4,
            reduceMotion: false
        )
        let frozenA = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0.9,
            reduceMotion: true
        )

        #expect(movingA != movingB)
        #expect(frozenA == frozenB)
        #expect(movingA.count <= 360)
    }

    @Test func nextStageGhostNeverBecomesOfficialBeforeProgression() {
        #expect(CompanionPointCloudMotion.ghostOpacity(progress: 0.71, hasNext: true) == 0)
        #expect(CompanionPointCloudMotion.ghostOpacity(progress: 0.72, hasNext: true) == 0)
        #expect(CompanionPointCloudMotion.ghostOpacity(progress: 0.86, hasNext: true) == 0.09)
        #expect(CompanionPointCloudMotion.ghostOpacity(progress: 1.0, hasNext: true) == 0.18)
        #expect(CompanionPointCloudMotion.ghostOpacity(progress: 1.0, hasNext: false) == 0)
    }

    @Test func eachModeKeepsItsFixedPointBudget() {
        let expanded = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .expanded,
            phase: 0,
            reduceMotion: false
        )
        let collapsed = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0,
            reduceMotion: false
        )

        #expect(expanded.count == 640)
        #expect(collapsed.count == 360)
    }

    @Test func collapsedDriftNeverExceedsOnePointEightPoints() {
        let samples = CompanionPointCloudMotion.samples(
            descriptor: fixture,
            mode: .collapsed,
            phase: 0.37,
            reduceMotion: false
        )

        #expect(samples.allSatisfy { hypot($0.offset.width, $0.offset.height) <= 1.8 })
    }

    @Test func breathingUsesEightSecondRangeAndFreezesForReduceMotion() {
        #expect(CompanionPointCloudMotion.breathingScale(phase: 0.25, reduceMotion: false) == 1.015)
        #expect(CompanionPointCloudMotion.breathingScale(phase: 0.75, reduceMotion: false) == 0.985)
        #expect(CompanionPointCloudMotion.breathingScale(phase: 0.25, reduceMotion: true) == 1)
        #expect(CompanionPointCloudMotion.breathingDuration == 8)
    }

    @Test func rewardPulsePeaksAndReturnsWithinPointFiveFiveSeconds() {
        #expect(CompanionPointCloudMotion.rewardPulseScale(elapsed: 0, reduceMotion: false) == 1)
        #expect(CompanionPointCloudMotion.rewardPulseScale(elapsed: 0.18, reduceMotion: false) == 1.035)
        #expect(CompanionPointCloudMotion.rewardPulseScale(elapsed: 0.55, reduceMotion: false) == 1)
        #expect(CompanionPointCloudMotion.rewardPulseScale(elapsed: 0.18, reduceMotion: true) == 1)
    }

    @Test func reduceMotionUsesFixedPhaseAndCollapsedSizeTracksAccessibility() {
        #expect(CompanionPointCloudMotion.resolvedPhase(0.83, reduceMotion: true) == 0.19)
        #expect(CompanionPointCloudMode.collapsed.visualDimension(isAccessibilitySize: false) == 108)
        #expect(CompanionPointCloudMode.collapsed.visualDimension(isAccessibilitySize: true) == 120)
        #expect(CompanionPointCloudMode.expanded.visualDimension(isAccessibilitySize: false) == nil)
    }

    @Test func reduceMotionFreezesEveryPointCloudModeAndTimelinePolicyPausesWhenInactive() {
        for mode in [CompanionPointCloudMode.expanded, .collapsed] {
            let first = CompanionPointCloudMotion.samples(
                descriptor: fixture,
                mode: mode,
                phase: 0.12,
                reduceMotion: true
            )
            let later = CompanionPointCloudMotion.samples(
                descriptor: fixture,
                mode: mode,
                phase: 0.87,
                reduceMotion: true
            )

            #expect(first == later)
        }

        #expect(!CompanionPointCloudTimelinePolicy(
            reduceMotion: false,
            isVisible: true,
            isSceneActive: true
        ).isPaused)
        #expect(CompanionPointCloudTimelinePolicy(
            reduceMotion: false,
            isVisible: false,
            isSceneActive: true
        ).isPaused)
        #expect(CompanionPointCloudTimelinePolicy(
            reduceMotion: false,
            isVisible: true,
            isSceneActive: false
        ).isPaused)
        #expect(CompanionPointCloudTimelinePolicy(
            reduceMotion: true,
            isVisible: true,
            isSceneActive: true
        ).isPaused)
    }

    private var fixture: CompanionPointCloudDescriptor {
        let points: [CompanionPointSeed] = (0..<700).map { index in
            let x = CGFloat(index % 35) / 34
            let y = CGFloat(index / 35) / 19
            let inkWeight = 0.35 + Double(index % 13) / 20
            return CompanionPointSeed(
                position: CGPoint(x: x, y: y),
                inkWeight: inkWeight,
                seed: UInt64(index + 1)
            )
        }
        return CompanionPointCloudDescriptor(
            id: CompanionArtworkID(collectibleID: "ordinary.sprout", stage: .stageThree),
            points: points,
            occupiedBounds: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
    }
}
