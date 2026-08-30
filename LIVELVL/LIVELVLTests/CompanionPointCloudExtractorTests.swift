import CoreGraphics
import Foundation
import Testing
@testable import LIVELVL

struct CompanionPointCloudExtractorTests {
    @Test func extractorRejectsOuterFrameAndNearWhiteNoise() throws {
        var pixels = Array(repeating: UInt8(250), count: 20 * 20)
        for x in 0..<20 {
            pixels[x] = 0
            pixels[19 * 20 + x] = 0
        }
        for y in 0..<20 {
            pixels[y * 20] = 0
            pixels[y * 20 + 19] = 0
        }
        pixels[10 * 20 + 10] = 0
        let raster = CompanionInkRaster(width: 20, height: 20, luminance: pixels)

        let descriptor = CompanionPointCloudExtractor.extract(
            id: .init(collectibleID: "ordinary.sprout", stage: .juvenile),
            raster: raster,
            configuration: .pilot
        )

        #expect(descriptor.points.count == 1)
        #expect(descriptor.points[0].position == CGPoint(x: 10.0 / 19.0, y: 10.0 / 19.0))
    }

    @Test func extractionIsDeterministicAndBounded() {
        let raster = CompanionInkRaster(
            width: 80,
            height: 80,
            luminance: Array(repeating: 0, count: 6_400)
        )
        let id = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: .mature)

        let first = CompanionPointCloudExtractor.extract(id: id, raster: raster, configuration: .pilot)
        let second = CompanionPointCloudExtractor.extract(id: id, raster: raster, configuration: .pilot)

        #expect(first == second)
        #expect(first.points.count == 640)
        #expect(first.points.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
    }

    @Test func bundledPilotArtworkPreservesRelativeStageScale() async throws {
        let provider = try BundledCompanionArtworkProvider(
            bundle: .main,
            subdirectory: "CompanionArtwork"
        )

        var descriptors: [CompanionStage: CompanionPointCloudDescriptor] = [:]
        for stage in CompanionStage.allCases {
            let id = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: stage)
            let payload = try #require(try await provider.payload(for: id))
            let raster = try #require(
                CompanionArtworkRasterizer.raster(
                    data: payload.data,
                    maxDimension: CompanionPointCloudExtractionConfiguration.pilot.maxRasterDimension
                )
            )
            descriptors[stage] = CompanionPointCloudExtractor.extract(
                id: payload.id,
                raster: raster,
                configuration: .pilot
            )
        }

        let juvenile = try #require(descriptors[.juvenile])
        let mature = try #require(descriptors[.mature])
        #expect(juvenile.occupiedBounds.width < mature.occupiedBounds.width)
        #expect(juvenile.occupiedBounds.height < mature.occupiedBounds.height)
        #expect(mature.points.count > juvenile.points.count)
    }
}
