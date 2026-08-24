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

    @Test func companionCardUsesStableAspectRatioAndFitExpansion() {
        #expect(GlassCardLayout.companionAspectRatio == 2.2)
        #expect(GlassCardLayout.expandedMediaUsesFit)
    }

    @Test func companionMediaUsesTransparentGlassAndReadableText() {
        #expect(CompanionGlassStyle.mediaScrimOpacity == 0)
        #expect(CompanionGlassStyle.usesTransparentGlass)
        #expect(CompanionGlassStyle.textShadowOpacity == 0.62)
        #expect(CompanionGlassStyle.textShadowRadius == 2.5)
        #expect(GlassCardLayout.contentLayerIsAboveGlass)
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
