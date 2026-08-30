import Foundation
import Testing
@testable import LIVELVL

struct CompanionArtworkTests {
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

    @Test func bundledProviderReturnsNilForAnUnmappedIdentity() async throws {
        let provider = try BundledCompanionArtworkProvider(
            bundle: .main,
            subdirectory: "CompanionArtwork"
        )

        let payload = try await provider.payload(
            for: CompanionArtworkID(collectibleID: "ordinary.hare", stage: .juvenile)
        )

        #expect(payload == nil)
    }
}
