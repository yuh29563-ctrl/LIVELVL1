import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import LIVELVL

struct AnimatedMediaDecoderTests {
    @Test func decodesStaticImageAsSingleFrame() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .pngData { renderer in
                UIColor.systemBlue.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }

        let decoded = try AnimatedMediaDecoder.decode(
            data: image,
            maxPixelSize: 64,
            allowsAnimation: true
        )

        #expect(decoded.kind == .image)
        #expect(decoded.frames.count == 1)
        #expect(decoded.isAnimated == false)
        #expect(decoded.firstFrame != nil)
    }

    @Test func rejectsInvalidMediaData() {
        #expect(throws: MediaDecodingError.invalidData) {
            try AnimatedMediaDecoder.decode(
                data: Data([0x01, 0x02, 0x03]),
                maxPixelSize: 64,
                allowsAnimation: true
            )
        }
    }

    @Test func decodesAnimatedGIFAndCanFreezeItToFirstFrame() throws {
        let firstImage = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .image { renderer in
                UIColor.systemBlue.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        let secondImage = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .image { renderer in
                UIColor.systemPink.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.gif.identifier as CFString,
            2,
            nil
        ) else {
            Issue.record("Unable to create GIF destination")
            return
        }
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 0.1
            ]
        ] as CFDictionary
        CGImageDestinationAddImage(destination, firstImage.cgImage!, frameProperties)
        CGImageDestinationAddImage(destination, secondImage.cgImage!, frameProperties)
        #expect(CGImageDestinationFinalize(destination))

        let animated = try AnimatedMediaDecoder.decode(
            data: data as Data,
            maxPixelSize: 64,
            allowsAnimation: true
        )
        let frozen = try AnimatedMediaDecoder.decode(
            data: data as Data,
            maxPixelSize: 64,
            allowsAnimation: false
        )

        #expect(animated.kind == .gif)
        #expect(animated.frames.count == 2)
        #expect(animated.isAnimated)
        #expect(frozen.frames.count == 1)
        #expect(frozen.isAnimated == false)
    }
}
