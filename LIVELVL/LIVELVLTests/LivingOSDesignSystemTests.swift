import SwiftUI
import Testing
@testable import LIVELVL

struct LivingOSDesignSystemTests {
    @Test func coreWidthAdaptsWithoutBecomingTooSmallOrDominatingWideLayouts() {
        #expect(LivingOSMetrics.coreWidth(containerWidth: 320) == 124)
        #expect(abs(LivingOSMetrics.coreWidth(containerWidth: 390) - 132.6) < 0.001)
        #expect(LivingOSMetrics.coreWidth(containerWidth: 1_024) == 180)
    }

    @Test func scoreDisplayClampsDomainScoreIntoHundredPointPresentation() {
        #expect(LifeStateDisplayScale.percentage(from: -1) == 0)
        #expect(LifeStateDisplayScale.percentage(from: 0) == 0)
        #expect(LifeStateDisplayScale.percentage(from: 7.84) == 78)
        #expect(LifeStateDisplayScale.percentage(from: 10) == 100)
        #expect(LifeStateDisplayScale.percentage(from: 12) == 100)
    }

    @Test func reduceMotionRemovesSpatialEffectsButKeepsStateFeedback() {
        let normal = LivingOSMotionProfile.resolved(reduceMotion: false)
        let reduced = LivingOSMotionProfile.resolved(reduceMotion: true)

        #expect(normal.allowsParticles)
        #expect(normal.allowsDepthTilt)
        #expect(!reduced.allowsParticles)
        #expect(!reduced.allowsDepthTilt)
        #expect(reduced.stateFadeDuration > 0)
        #expect(reduced.snapDuration <= normal.snapDuration)
    }

    @Test func animationTimelinesPauseForReducedMotionOffscreenAndBackgroundStates() {
        #expect(!LivingOSAnimationActivity.isPaused(
            reduceMotion: false,
            isVisible: true,
            isSceneActive: true
        ))
        #expect(LivingOSAnimationActivity.isPaused(
            reduceMotion: true,
            isVisible: true,
            isSceneActive: true
        ))
        #expect(LivingOSAnimationActivity.isPaused(
            reduceMotion: false,
            isVisible: false,
            isSceneActive: true
        ))
        #expect(LivingOSAnimationActivity.isPaused(
            reduceMotion: false,
            isVisible: true,
            isSceneActive: false
        ))
    }

    @Test func primaryLivingOSTextUsesDynamicTypeRelativeStyles() {
        #expect(LivingOSTypography.rewardsHero == .largeTitle)
        #expect(LivingOSTypography.archiveCaptionTitle == .headline)
        #expect(LivingOSTypography.taskTitle == .body)
    }
}
