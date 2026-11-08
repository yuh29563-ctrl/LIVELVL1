import Foundation
import SwiftData
import Testing
@testable import LIVELVL

private enum PreHiddenCards {
    @Model final class CollectionProgress {
        @Attribute(.unique) var singletonKey: String = "collection.progress"
        var highestLevel: Int = 1
        var activeOrdinaryIndex: Int = 1
        var activeStageRaw: Int = 0
        var lastProcessedMaturityLevel: Int = 1
        var growthCatalogRevision: Int = 1
        init() {}
    }
}

@MainActor
struct HiddenCardPersistenceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func store(_ url: URL, legacy: Bool = false, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = Schema([LIVELVL.Progress.self, Item.self, Completion.self, CoinTransaction.self,
            legacy ? PreHiddenCards.CollectionProgress.self : CollectionProgress.self,
            OwnedCollectible.self, PendingCardReward.self, JournalEntry.self,
            DimensionProfile.self, StateSnapshot.self, TarotDailyState.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none))
    }
    private func folder() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    @Test func preHiddenDiskStoreMigratesOnceWithoutHistoricalAwardsOrOtherDataChanges() throws {
        let folder = try folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("migration.store")
        try autoreleasepool {
            let container = try store(url, legacy: true), context = container.mainContext
            context.insert(PreHiddenCards.CollectionProgress())
            context.insert(LIVELVL.Progress(totalXP: 200))
            context.insert(OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
                kind: .ordinaryMature, reason: "保留成长卡", acquiredAt: now, isUnseen: false))
            context.insert(Completion(itemID: UUID(), xp: 200, dimension: .learning,
                                      durationMinutes: 20, date: now.addingTimeInterval(-10)))
            context.insert(JournalEntry(dayKey: "keep", dayStart: now, timeZoneIdentifier: "Asia/Shanghai",
                                       title: "保留", body: "原日记", state: .draft, now: now))
            context.insert(CoinTransaction(operationKey: "legacy-xp-import", kind: .legacyImport,
                amountCoinUnits: 300, requestedCoinUnits: 300, sourceID: nil, createdAt: now, note: "原金币"))
            try context.save()
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            try CardRewardService.activateHiddenCards(in: context, now: now, calendar: calendar)
            try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: calendar)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
            context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health, date: now.addingTimeInterval(1)))
            try context.save()
            try CardRewardService.reconcilePersistedRewards(in: context, now: now.addingTimeInterval(2), calendar: calendar)
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            let later = now.addingTimeInterval(10)
            try CardRewardService.activateHiddenCards(in: context, now: later, calendar: .current)
            for _ in 0..<2 {
                try CardRewardService.reconcilePersistedRewards(in: context, now: later, calendar: .current)
            }
            let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
            #expect(collection.hiddenCardsEnabledAt == now)
            #expect(collection.hiddenCardsTimeZoneIdentifier == "Asia/Shanghai")
            #expect(collection.activeOrdinaryIndex == 1)
            #expect(collection.highestLevel == 1)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 200)
            #expect(try context.fetch(FetchDescriptor<JournalEntry>()).first?.body == "原日记")
            #expect(try CoinLedgerService.balance(in: context) == 300)
            let owned = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
            #expect(owned.reason == "保留成长卡" && owned.acquiredAt == now && !owned.isUnseen)
            #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey) == ["hidden.health.first"])
            #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: later))
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            try CardRewardService.reconcilePersistedRewards(in: context, now: now.addingTimeInterval(20), calendar: .current)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
            #expect(Set(try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey))
                == ["ordinary.level.1", "hidden.health.first"])
        }
    }

    @Test func failedClaimAndRevocationKeepCommittedTaskCoinsAndHiddenCard() throws {
        let folder = try folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("rollback.store")
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            let progress = LIVELVL.Progress()
            let task = Item(title: "行动", dimension: .health, minutes: 1, difficulty: 1, xp: 10, recurrence: .once)
            context.insert(progress); context.insert(task); try context.save()
            try CardRewardService.activateHiddenCards(in: context, now: now, calendar: .current)
            _ = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        }
        try autoreleasepool {
            let container = try store(url, allowsSave: false), context = container.mainContext
            context.autosaveEnabled = false
            #expect(throws: (any Error).self) {
                _ = try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: now.addingTimeInterval(2))
            }
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).count == 1)
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: now.addingTimeInterval(3)))
        }
        try autoreleasepool {
            let container = try store(url, allowsSave: false), context = container.mainContext
            context.autosaveEnabled = false
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            let completion = try #require(context.fetch(FetchDescriptor<Completion>()).first)
            #expect(throws: (any Error).self) {
                _ = try TaskRewardCoordinator.revoke(completion: completion, progress: progress, in: context, now: now.addingTimeInterval(4))
            }
            #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 10)
            #expect(try CoinLedgerService.balance(in: context) == 10)
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            let completion = try #require(context.fetch(FetchDescriptor<Completion>()).first)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            #expect(try TaskRewardCoordinator.revoke(completion: completion, progress: progress, in: context, now: now.addingTimeInterval(5)))
        }
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
            #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 0)
            #expect(try CoinLedgerService.balance(in: context) == 0)
        }
    }
    @Test func clockRollbackAndDiskReopenPreserveOriginalAwardMetadata() throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("clock-rollback.store")
        let acquiredAt = now.addingTimeInterval(2)
        try autoreleasepool {
            let container = try store(url), context = container.mainContext
            let progress = LIVELVL.Progress()
            let task = Item(title: "新行动", dimension: .health, minutes: 1, difficulty: 1, xp: 10, recurrence: .once)
            context.insert(progress); context.insert(task); try context.save()
            try CardRewardService.activateHiddenCards(in: context, now: now.addingTimeInterval(-1), calendar: .current)
            _ = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
            #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: acquiredAt))
        }
        for time in [now.addingTimeInterval(-10), now.addingTimeInterval(5)] {
            try autoreleasepool {
                let container = try store(url), context = container.mainContext
                try CardRewardService.activateHiddenCards(in: context, now: time, calendar: .current)
                try CardRewardService.reconcilePersistedRewards(in: context, now: time, calendar: .current)
                let owned = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
                #expect(owned.awardKey == "hidden.health.first")
                #expect(owned.acquiredAt == acquiredAt && owned.isUnseen)
                #expect(owned.reason == "第一次完成健康任务")
                #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
                #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
                #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 1)
                #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 10)
                #expect(try CoinLedgerService.balance(in: context) == 10)
            }
        }
    }

}
