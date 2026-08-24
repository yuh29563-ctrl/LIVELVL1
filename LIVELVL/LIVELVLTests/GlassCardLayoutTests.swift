import SwiftUI
import Testing
import UIKit

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
            DecodedMediaFrame(image: .init(), duration: 0.1),
        ]

        #expect(AnimatedMediaView.frameIndex(elapsed: 10, frames: frames, reduceMotion: true) == 0)
        #expect(AnimatedMediaView.frameIndex(elapsed: 0.15, frames: frames, reduceMotion: false) == 1)
    }

    @MainActor
    @Test func portraitMediaCannotRenderAboveTheFixedCardViewport() throws {
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 200)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 200))
        }
        let media = DecodedMedia(
            kind: .image,
            frames: [DecodedMediaFrame(image: portrait, duration: 0.1)]
        )
        let presentation = TodayCompanionLevelCardPresentation(
            definition: CollectionCatalog.ordinary[0],
            stage: .juvenile,
            level: 1,
            currentXP: 10,
            requiredXP: 2_000,
            remainingXP: 1_990
        )
        let canvas = ZStack(alignment: .topLeading) {
            Color.green
            TodayCompanionLevelCard(
                presentation: presentation,
                progress: 0.005,
                media: media
            )
            .frame(width: 252)
            .offset(x: 24, y: 40)
        }
        .frame(width: 300, height: 260)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        let renderedImage = try #require(renderer.uiImage)
        let rendered = try #require(renderedImage.cgImage)
        let pixel = try pixelRGBA(in: rendered, x: 150, y: 12)

        #expect(pixel.green > pixel.red)
    }

    private func pixelRGBA(in image: CGImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8) {
        let cropY = image.height - y - 1
        let cropped = try #require(image.cropping(to: CGRect(x: x, y: cropY, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(
            CGContext(
                data: &bytes,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (bytes[0], bytes[1])
    }
}
