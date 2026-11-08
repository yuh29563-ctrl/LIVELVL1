import UIKit
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct PermanentCollectionCardTests {
    @Test func journeyGuidesHaveStableOrderAndCompleteBackCopy() {
        let cards = PermanentCollectionCatalog.cards
        #expect(cards.map(\.id) == [
            "permanent.journey.awareness", "permanent.journey.action",
            "permanent.journey.memory", "permanent.journey.rewards",
            "permanent.journey.growth"
        ])
        #expect(cards.map(\.number) == [1, 2, 3, 4, 5])
        #expect(cards.allSatisfy { !$0.story.isEmpty && !$0.paragraphs.isEmpty })
        #expect(cards[1].paragraphs.joined().contains("400 XP"))
        #expect(cards[4].paragraphs.joined().contains("这五张指引卡会一直留在这里"))
    }

    @Test func permanentCardsPrecedeEarnedCardsWithoutCreatingOwnedRecords() throws {
        let store = try ModelContainer(for: OwnedCollectible.self,
                                       configurations: .init(isStoredInMemoryOnly: true))
        let earned = OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
                                     kind: .ordinaryMature, reason: "测试")
        store.mainContext.insert(earned)
        try store.mainContext.save()
        let items = ArchiveCollectiblePresentation.items(owned: [earned])
        #expect(items.map(\.id) == PermanentCollectionCatalog.cards.map(\.id) + [earned.awardKey])
        #expect(try store.mainContext.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
        #expect(earned.isUnseen)
        #expect(ArchiveCollectiblePresentation.items(owned: []).count == 5)
    }

    @Test func futurePermanentCardsAlsoPrecedeAllEarnedCards() {
        let future = PermanentCollectionCard(id: "permanent.future", number: 6, title: "新功能",
            series: "新功能指引", artworkName: "JourneyGuide01", story: "故事", paragraphs: ["说明"])
        let earned = OwnedCollectible(awardKey: "ordinary.level.99", collectibleID: "growth.star-vortex",
                                     kind: .ordinaryMature, reason: "测试")
        let cards = PermanentCollectionCatalog.cards + [future]
        #expect(ArchiveCollectiblePresentation.items(owned: [earned], permanentCards: cards).map(\.id)
                == cards.map(\.id) + [earned.awardKey])
        var state = ArchiveCarouselState()
        state.reconcile(orderedAwardKeys: cards.map(\.id))
        #expect(state.centeredAwardKey == cards.first?.id)
        state.expandCentered()
        state.setShowingBack(true)
        state.closeExpanded()
        #expect(state.centeredAwardKey == cards.first?.id)
        #expect(!state.isShowingBack)
    }

    @Test func everyGuideImageDecodesWithRealTransparency() throws {
        for card in PermanentCollectionCatalog.cards {
            let image = try #require(UIImage(named: card.artworkName)?.cgImage)
            #expect(image.width == 512)
            #expect(image.height == 512)
            #expect(image.alphaInfo == .premultipliedLast || image.alphaInfo == .premultipliedFirst)
        }
    }
}
