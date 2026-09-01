import Foundation
import Testing
@testable import LIVELVL

struct CompanionArtworkTests {
    @Test func manifestCanRequestCrispTransparentRasterRendering() throws {
        let manifest = try CompanionArtworkManifest.decode(data: Data(#"""
        {"version":1,"entries":[
          {"collectibleID":"ordinary.hare","stage":"juvenile","resourceName":"ordinary-hare-juvenile","fileExtension":"png","renderMode":"transparentRaster"}
        ]}
        """#.utf8))

        let resource = try #require(
            manifest.resource(for: .init(collectibleID: "ordinary.hare", stage: .juvenile))
        )
        #expect(resource.renderMode == .transparentRaster)
    }

    @Test func manifestDefaultsExistingArtworkToPointCloudRendering() throws {
        let manifest = try CompanionArtworkManifest.decode(data: Data(#"""
        {"version":1,"entries":[
          {"collectibleID":"ordinary.sprout","stage":"juvenile","resourceName":"ordinary-sprout-juvenile","fileExtension":"jpg"}
        ]}
        """#.utf8))

        let resource = try #require(
            manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .juvenile))
        )
        #expect(resource.renderMode == .pointCloud)
    }

    @Test func pilotManifestMapsEverySproutStageInOrder() throws {
        let manifest = try CompanionArtworkManifest.decode(data: Data(#"""
        {"version":1,"entries":[
          {"collectibleID":"ordinary.sprout","stage":"juvenile","resourceName":"ordinary-sprout-juvenile","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"stageTwo","resourceName":"ordinary-sprout-stage-two","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"stageThree","resourceName":"ordinary-sprout-stage-three","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"mature","resourceName":"ordinary-sprout-mature","fileExtension":"jpg"}
        ]}
        """#.utf8))

        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .juvenile))?.name == "ordinary-sprout-juvenile")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .stageTwo))?.name == "ordinary-sprout-stage-two")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .stageThree))?.name == "ordinary-sprout-stage-three")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.sprout", stage: .mature))?.name == "ordinary-sprout-mature")
        #expect(manifest.resource(for: .init(collectibleID: "ordinary.hare", stage: .juvenile)) == nil)
    }

    @Test func invalidStageMakesTheManifestFailClosed() {
        let data = Data(#"{"version":1,"entries":[{"collectibleID":"ordinary.sprout","stage":"unknown","resourceName":"bad","fileExtension":"jpg"}]}"#.utf8)
        #expect(throws: CompanionArtworkManifestError.self) {
            try CompanionArtworkManifest.decode(data: data)
        }
    }

    @Test func duplicateIdentityMakesTheManifestFailClosed() {
        let data = Data(#"""
        {"version":1,"entries":[
          {"collectibleID":"ordinary.sprout","stage":"juvenile","resourceName":"first","fileExtension":"jpg"},
          {"collectibleID":"ordinary.sprout","stage":"juvenile","resourceName":"second","fileExtension":"jpg"}
        ]}
        """#.utf8)

        #expect(throws: CompanionArtworkManifestError.self) {
            try CompanionArtworkManifest.decode(data: data)
        }
    }

    @Test func bundledPilotPayloadsAreReadableJPEGs() async throws {
        let provider = try BundledCompanionArtworkProvider(
            bundle: .main,
            subdirectory: "CompanionArtwork"
        )

        for stage in CompanionStage.allCases {
            let id = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: stage)
            let payload = try #require(try await provider.payload(for: id))
            #expect(payload.data.count > 2)
            #expect(payload.data.prefix(2).elementsEqual([0xFF, 0xD8]))
        }
    }

    @Test func bundledHareJuvenileUsesTheApprovedTransparentArtwork() async throws {
        let provider = try BundledCompanionArtworkProvider(
            bundle: .main,
            subdirectory: "CompanionArtwork"
        )

        let payload = try #require(
            try await provider.payload(
                for: CompanionArtworkID(collectibleID: "ordinary.hare", stage: .juvenile)
            )
        )

        #expect(payload.renderMode == .transparentRaster)
        #expect(payload.data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @Test func bundledProviderReturnsNilForAnUnmappedIdentity() async throws {
        let provider = try BundledCompanionArtworkProvider(
            bundle: .main,
            subdirectory: "CompanionArtwork"
        )

        let payload = try await provider.payload(
            for: CompanionArtworkID(collectibleID: "unmapped", stage: .juvenile)
        )

        #expect(payload == nil)
    }
}
