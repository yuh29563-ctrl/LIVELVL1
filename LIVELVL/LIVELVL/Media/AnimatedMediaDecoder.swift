import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct DecodedMediaFrame {
    let image: UIImage
    let duration: TimeInterval
}

struct DecodedMedia {
    let kind: UserCardMediaKind
    let frames: [DecodedMediaFrame]

    var isAnimated: Bool { frames.count > 1 }
    var firstFrame: UIImage? { frames.first?.image }
}

enum MediaDecodingError: Error, Equatable {
    case invalidData
    case unsupportedFormat
    case frameDecodingFailed
}

enum AnimatedMediaDecoder {
    static func decode(
        data: Data,
        maxPixelSize: Int,
        allowsAnimation: Bool
    ) throws -> DecodedMedia {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw MediaDecodingError.invalidData
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw MediaDecodingError.invalidData }
        guard let typeIdentifier = CGImageSourceGetType(source) as String? else {
            throw MediaDecodingError.unsupportedFormat
        }

        let isGIF = typeIdentifier == UTType.gif.identifier
        let isPNG = typeIdentifier == UTType.png.identifier
        guard isGIF || isPNG || typeIdentifier == UTType.jpeg.identifier else {
            throw MediaDecodingError.unsupportedFormat
        }

        let frameCount = allowsAnimation && (isGIF || isPNG) ? count : 1
        let kind: UserCardMediaKind = isGIF ? .gif : (frameCount > 1 ? .apng : .image)
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize)
        ] as CFDictionary

        var frames: [DecodedMediaFrame] = []
        frames.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options) else {
                throw MediaDecodingError.frameDecodingFailed
            }
            frames.append(
                DecodedMediaFrame(
                    image: UIImage(cgImage: cgImage),
                    duration: frameDuration(source: source, index: index)
                )
            )
        }
        return DecodedMedia(kind: kind, frames: frames)
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? 0.1
        return duration > 0.02 ? duration : 0.1
    }
}
