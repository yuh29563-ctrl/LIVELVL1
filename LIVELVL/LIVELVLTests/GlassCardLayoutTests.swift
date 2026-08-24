import Testing
@testable import LIVELVL

struct GlassCardLayoutTests {
    @Test func usesFloatingCardMetrics() {
        #expect(GlassCardLayout.horizontalInset == 16)
        #expect(GlassCardLayout.contentPadding == 20)
        #expect(GlassCardLayout.cornerRadius == 28)
        #expect(GlassCardLayout.shadowRadius == 18)
        #expect(LifeStateCardLayout.horizontalInset == GlassCardLayout.horizontalInset)
    }

    @Test func companionMediaUsesFrostedReadabilityOverlay() {
        #expect(CompanionGlassStyle.mediaScrimOpacity == 0.22)
        #expect(CompanionGlassStyle.frostedMaterialOpacity == 0.72)
        #expect(CompanionGlassStyle.textShadowOpacity == 0.18)
    }

    @Test func reduceMotionAlwaysSelectsFirstMediaFrame() {
        let frames = [
            DecodedMediaFrame(image: .init(), duration: 0.1),
            DecodedMediaFrame(image: .init(), duration: 0.1)
        ]

        #expect(AnimatedMediaView.frameIndex(elapsed: 10, frames: frames, reduceMotion: true) == 0)
        #expect(AnimatedMediaView.frameIndex(elapsed: 0.15, frames: frames, reduceMotion: false) == 1)
    }
}
