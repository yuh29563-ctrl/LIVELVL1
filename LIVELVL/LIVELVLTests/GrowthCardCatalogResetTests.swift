import Foundation
import SwiftData
import Testing
@testable import LIVELVL

private enum PreGrowthCatalog {
    @Model final class CollectionProgress {
        @Attribute(.unique) var singletonKey: String = "collection.progress"
        var highestLevel: Int = 4
        var activeOrdinaryIndex: Int = 2
        var activeStageRaw: Int = 0
        var lastProcessedMaturityLevel: Int = 3
        init() {}
    }
}

@MainActor
struct GrowthCardCatalogResetTests {
    private func store(_ url: URL, legacy: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Item.self, LIVELVL.Progress.self, Completion.self, CoinTransaction.self,
            legacy ? PreGrowthCatalog.CollectionProgress.self : CollectionProgress.self,
            OwnedCollectible.self, PendingCardReward.self, JournalEntry.self,
            DimensionProfile.self, StateSnapshot.self, TarotDailyState.self
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: url, cloudKitDatabase: .none
        ))
    }

    @Test func oldDiskStoreResetsOnlyLevelAndTestCardsOnce() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("growth.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try autoreleasepool {
            let container = try store(url, legacy: true)
            let context = container.mainContext
            context.insert(LIVELVL.Progress(totalXP: 6_200))
            context.insert(PreGrowthCatalog.CollectionProgress())
            context.insert(OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "ordinary.sprout",
                kind: .ordinaryMature, reason: "旧测试"))
            context.insert(PendingCardReward(awardKey: "ordinary.level.4", collectibleID: "ordinary.hare",
                kind: .ordinaryMature, reason: "旧测试", maturityLevel: 4, triggeredAt: now, eligibleAt: now))
            context.insert(Item(title: "保留任务", dimension: .learning, minutes: 20, difficulty: 1, xp: 20, recurrence: .daily))
            context.insert(Completion(itemID: UUID(), xp: 80, date: now))
            context.insert(CoinTransaction(operationKey: "legacy-xp-import", kind: .legacyImport,
                amountCoinUnits: 500, requestedCoinUnits: 500, sourceID: nil, createdAt: now, note: "保留金币"))
            context.insert(JournalEntry(dayKey: "keep", dayStart: now, timeZoneIdentifier: "Asia/Shanghai",
                title: "保留日记", body: "内容不动", state: .draft, now: now))
            context.insert(StateSnapshot(scores: LifeStateValues(repeating: 60),
                actionScores: LifeStateValues(repeating: 0), assessedAt: now))
            context.insert(DimensionProfile(dimension: .learning, selfRating: 60, weeklyTarget: 3, lastAssessedAt: now))
            try context.save()
        }
        try autoreleasepool {
            let container = try store(url)
            let context = container.mainContext
            try GrowthCardCatalogReset.applyIfNeeded(in: context)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            #expect(progress.totalXP == 0)
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<JournalEntry>()).first?.body == "内容不动")
            #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 1)
            #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).first?.health == 60)
            #expect(try context.fetchCount(FetchDescriptor<DimensionProfile>()) == 1)
            #expect(try CoinLedgerService.balance(in: context) == 500)
            #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.activeOrdinaryIndex == 0)
#if DEBUG
            try TaskRewardCoordinator.debugAdvanceOneLevel(progress: progress, in: context, now: now)
#endif
        }
        try autoreleasepool {
            let container = try store(url)
            let context = container.mainContext
            try GrowthCardCatalogReset.applyIfNeeded(in: context)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.level == 1)
            let owned = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
            #expect(owned.collectibleID == "growth.star-vortex")
            #expect(owned.awardKey == "ordinary.level.1")
            #expect(try CoinLedgerService.balance(in: context) == 500)
        }
    }
}
