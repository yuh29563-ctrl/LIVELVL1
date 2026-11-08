import Foundation
import ImageIO
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct HiddenCardPresentationTests {
    @Test func catalogDoesNotRevealUndiscoveredHiddenCardsOrCounts() {
        let visible = CollectionCatalog.visibleDefinitions(ownedIDs: [])
        #expect(visible == CollectionCatalog.ordinary)
        #expect(visible.count == 111)
        let discovered: Set<String> = ["hidden.health.first", "hidden.learning.streak.7"]
        let revealed = CollectionCatalog.visibleDefinitions(ownedIDs: discovered)
        #expect(revealed.count == 113)
        #expect(Set(revealed.filter { $0.kind == .hidden }.map(\.id)) == discovered)
        #expect(CollectionCatalog.hidden.map(\.id) == HiddenAchievementEngine.rules.map(\.id))
        #expect(CollectionCatalog.hidden.count == 36)
        #expect(CollectionCatalog.hidden.allSatisfy { !$0.details.isEmpty && $0.ordinaryIndex == nil })
    }

    @Test func reclaimedHiddenCardCanAnimateArrivalAgainWhenReearned() {
        var arrival = ArchiveArrivalPresentationState()
        let key = "hidden.health.first"
        arrival.registerClaimed(awardKey: key)
        #expect(arrival.takeArrivalIfNeeded(validAwardKeys: [key]) == key)
        arrival.markCompleted(awardKey: key)
        #expect(arrival.takeArrivalIfNeeded(validAwardKeys: []) == nil)
        arrival.registerClaimed(awardKey: key)
        #expect(arrival.takeArrivalIfNeeded(validAwardKeys: [key]) == key)
    }

    @Test func allHiddenArtHasOnlyOneMatureImage() async throws {
        let provider = try BundledCompanionArtworkProvider()
        var seen: Set<String> = []
        for card in CollectionCatalog.hidden {
            let payload = try #require(try await provider.payload(for: .init(collectibleID: card.id, stage: .mature)))
            let source = try #require(CGImageSourceCreateWithData(payload.data as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 512 && image.height == 512)
            #expect(payload.renderMode == .transparentRaster)
            #expect(seen.insert(payload.fingerprint).inserted)
            for stage in [CompanionStage.juvenile, .stageTwo, .stageThree] {
                let unexpected = try await provider.payload(for: .init(collectibleID: card.id, stage: stage))
                #expect(unexpected == nil)
            }
        }
    }
}
