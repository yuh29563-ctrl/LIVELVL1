import CoreGraphics
import Foundation
import ImageIO

nonisolated struct CompanionInkRaster: Equatable, Sendable {
    let width: Int
    let height: Int
    let luminance: [UInt8]
}

nonisolated struct CompanionPointSeed: Equatable, Sendable {
    let position: CGPoint
    let inkWeight: Double
    let seed: UInt64
}

nonisolated struct CompanionPointCloudDescriptor: Equatable, Sendable {
    let id: CompanionArtworkID
    let points: [CompanionPointSeed]
    let occupiedBounds: CGRect
}

nonisolated struct CompanionPointCloudExtractionConfiguration: Equatable, Sendable {
    let cropFraction: Double
    let inkThreshold: Double
    let maxRasterDimension: Int
    let maximumPointCount: Int

    static let pilot = Self(
        cropFraction: 0.035,
        inkThreshold: 0.12,
        maxRasterDimension: 160,
        maximumPointCount: 640
    )
}

nonisolated enum CompanionArtworkRasterizer {
    static func raster(data: Data, maxDimension: Int) -> CompanionInkRaster? {
        guard maxDimension > 0,
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        let sourceLongestSide = max(image.width, image.height)
        guard sourceLongestSide > 0 else {
            return nil
        }

        let scale = min(1, Double(maxDimension) / Double(sourceLongestSide))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        var luminance = Array(repeating: UInt8(255), count: width * height)

        let didDraw = luminance.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }

            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didDraw else {
            return nil
        }
        return CompanionInkRaster(width: width, height: height, luminance: luminance)
    }
}

nonisolated enum CompanionPointCloudExtractor {
    static func extract(
        id: CompanionArtworkID,
        raster: CompanionInkRaster,
        configuration: CompanionPointCloudExtractionConfiguration
    ) -> CompanionPointCloudDescriptor {
        guard raster.width > 0,
              raster.height > 0,
              raster.luminance.count == raster.width * raster.height,
              configuration.maximumPointCount > 0 else {
            return CompanionPointCloudDescriptor(id: id, points: [], occupiedBounds: .zero)
        }

        let horizontalCrop = min(raster.width / 2, Int((Double(raster.width) * configuration.cropFraction).rounded(.up)))
        let verticalCrop = min(raster.height / 2, Int((Double(raster.height) * configuration.cropFraction).rounded(.up)))
        var candidates: [Candidate] = []
        candidates.reserveCapacity(min(raster.luminance.count, configuration.maximumPointCount * 2))

        for y in verticalCrop..<(raster.height - verticalCrop) {
            for x in horizontalCrop..<(raster.width - horizontalCrop) {
                let luminance = raster.luminance[y * raster.width + x]
                let inkWeight = 1 - Double(luminance) / 255
                guard inkWeight >= configuration.inkThreshold else {
                    continue
                }

                let seed = stableSeed(id: id, x: x, y: y)
                let point = CompanionPointSeed(
                    position: CGPoint(
                        x: normalizedCoordinate(x, length: raster.width),
                        y: normalizedCoordinate(y, length: raster.height)
                    ),
                    inkWeight: inkWeight,
                    seed: seed
                )
                candidates.append(Candidate(point: point, priority: Double(seed) / Double(UInt64.max) / inkWeight))
            }
        }

        candidates.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.point.seed < rhs.point.seed
        }

        let points = candidates.prefix(configuration.maximumPointCount).map(\.point)
        return CompanionPointCloudDescriptor(
            id: id,
            points: points,
            occupiedBounds: occupiedBounds(of: points)
        )
    }
}

private nonisolated struct Candidate {
    let point: CompanionPointSeed
    let priority: Double
}

private nonisolated func normalizedCoordinate(_ coordinate: Int, length: Int) -> CGFloat {
    guard length > 1 else {
        return 0
    }
    return CGFloat(coordinate) / CGFloat(length - 1)
}

private nonisolated func occupiedBounds(of points: [CompanionPointSeed]) -> CGRect {
    guard let first = points.first else {
        return .zero
    }

    var minimumX = first.position.x
    var maximumX = first.position.x
    var minimumY = first.position.y
    var maximumY = first.position.y
    for point in points.dropFirst() {
        minimumX = min(minimumX, point.position.x)
        maximumX = max(maximumX, point.position.x)
        minimumY = min(minimumY, point.position.y)
        maximumY = max(maximumY, point.position.y)
    }

    return CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX,
        height: maximumY - minimumY
    )
}

private nonisolated func stableSeed(id: CompanionArtworkID, x: Int, y: Int) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325

    for byte in id.collectibleID.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    hash ^= 0xff
    hash &*= 0x100000001b3

    mix(UInt64(id.stage.rawValue), into: &hash)
    mix(UInt64(x), into: &hash)
    mix(UInt64(y), into: &hash)

    hash ^= hash >> 30
    hash &*= 0xbf58476d1ce4e5b9
    hash ^= hash >> 27
    hash &*= 0x94d049bb133111eb
    hash ^= hash >> 31
    return hash
}

private nonisolated func mix(_ value: UInt64, into hash: inout UInt64) {
    for shift in stride(from: 0, through: 56, by: 8) {
        hash ^= (value >> UInt64(shift)) & 0xff
        hash &*= 0x100000001b3
    }
}
