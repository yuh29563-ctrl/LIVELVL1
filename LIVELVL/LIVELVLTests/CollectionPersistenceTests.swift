import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct CollectionPersistenceTests {
    @Test func modelsRoundTrip() throws {
        let schema = Schema([CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self])
        let container = try ModelContainer(for: schema, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.insert(CollectionProgress())
        context.insert(PendingCardReward(
            awardKey: "ordinary.level.1", collectibleID: "ordinary.sprout",
            kind: .ordinaryMature, reason: "达到 Lv.1", maturityLevel: 1,
            triggeredAt: Date(timeIntervalSince1970: 10),
            eligibleAt: Date(timeIntervalSince1970: 11.6)
        ))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.highestLevel == 0)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).first?.awardKey == "ordinary.level.1")
    }
}
