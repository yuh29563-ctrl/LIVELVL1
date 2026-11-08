import Foundation
import SwiftData
import Testing
@testable import LIVELVL

// Frozen Completion layout from main 2db7726, before nominalXP existed.
// Keeping the entity name and all original attributes exercises real disk migration.
private enum PreDailyCapStore {
    @Model final class Completion {
        var id: UUID?
        var itemID: UUID
        var date: Date
        var xp: Int
        var dimensionRaw: String?
        var durationMinutes: Int?
        var taskTitle: String?

        init(itemID: UUID, date: Date) {
            id = nil // Includes the oldest records without a completion UUID.
            self.itemID = itemID
            self.date = date
            xp = 650
            dimensionRaw = "learning"
            durationMinutes = 60
            taskTitle = "旧行动"
        }
    }
}

@MainActor
struct DailyTaskXPPersistenceTests {
    private func schema(legacy: Bool = false) -> Schema {
        Schema([
            Item.self, LIVELVL.Progress.self,
            legacy ? PreDailyCapStore.Completion.self : Completion.self,
            DimensionProfile.self, StateSnapshot.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
            UserCardMedia.self, CoinTransaction.self, RewardProduct.self, RewardRedemption.self,
            JournalEntry.self, TarotDailyState.self
        ])
    }

    private func store(at url: URL, legacy: Bool = false, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = schema(legacy: legacy)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none
        ))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("daily-xp-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func oldDiskStorePreservesExistingRecordsWhileBackfillingMissingRewards() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let itemID = UUID()

        try autoreleasepool {
            let legacy = try store(at: url, legacy: true)
            let context = legacy.mainContext
            context.autosaveEnabled = false
            context.insert(PreDailyCapStore.Completion(itemID: itemID, date: date))
            context.insert(LIVELVL.Progress(totalXP: 6_200))
            context.insert(CollectionProgress(highestLevel: 4, activeOrdinaryIndex: 1,
                activeStage: .stageThree, lastProcessedMaturityLevel: 1))
            context.insert(OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "ordinary.sprout",
                kind: .ordinaryMature, reason: "旧获得原因", acquiredAt: date, isUnseen: false))
            context.insert(OwnedCollectible(awardKey: "hidden.study.three-day-streak", collectibleID: "hidden.study-streak",
                kind: .hiddenDiscovery, reason: "旧隐藏奖励", acquiredAt: date, isUnseen: true))
            context.insert(PendingCardReward(awardKey: "ordinary.level.4", collectibleID: "ordinary.hare",
                kind: .ordinaryMature, reason: "旧待领取", maturityLevel: 4,
                triggeredAt: date, eligibleAt: date.addingTimeInterval(1.6)))
            context.insert(CoinTransaction(operationKey: "legacy-xp-import", kind: .legacyImport,
                amountCoinUnits: 6_200, requestedCoinUnits: 6_200, sourceID: nil, createdAt: date, note: "旧金币"))
            try context.save()
        }

        try autoreleasepool {
            let upgraded = try store(at: url)
            let context = upgraded.mainContext
            context.autosaveEnabled = false
            let legacy = try #require(context.fetch(FetchDescriptor<Completion>()).first)
            #expect(legacy.nominalXP == nil)
            #expect(legacy.recordedNominalXP == 650)
            #expect(legacy.xp == 650)
            #expect(legacy.itemID == itemID)
            #expect(legacy.id == nil)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            #expect(progress.totalXP == 6_200)
            let task = Item(title: "新行动", dimension: .health, minutes: 60, difficulty: 2, xp: 80, recurrence: .daily)
            context.insert(task)
            try context.save()
            try CardRewardService.activateHiddenCards(in: context, now: date.addingTimeInterval(1), calendar: .current)
            let result = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: date.addingTimeInterval(1))
            #expect(result.completion.xp == 0)
            #expect(result.completion.nominalXP == 80)
            #expect(try CoinLedgerService.balance(in: context) == 6_280)
        }

        try autoreleasepool {
            let reopened = try store(at: url)
            let context = reopened.mainContext
            context.autosaveEnabled = false
            let records = try context.fetch(FetchDescriptor<Completion>())
            #expect(records.count == 2)
            let legacy = try #require(records.first { $0.itemID == itemID })
            #expect(legacy.xp == 650)
            #expect(legacy.recordedNominalXP == 650)
            #expect(legacy.date == date)
            #expect(legacy.taskTitle == "旧行动")
            let task = try #require(context.fetch(FetchDescriptor<Item>()).first)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            let repeated = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: date)
            #expect(!repeated.wasCreated)
            #expect(repeated.completion.nominalXP == 80)
            #expect(progress.totalXP == 6_200)
            #expect(try CoinLedgerService.balance(in: context) == 6_280)
            #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 2)
            let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
            #expect(collection.highestLevel == 4)
            #expect(collection.activeOrdinaryIndex == 1)
            #expect(collection.activeStage == .stageThree)
            #expect(collection.lastProcessedMaturityLevel == 1)
            let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
            #expect(owned.count == 4)
            #expect(owned.first { $0.awardKey == "ordinary.level.2" }?.collectibleID == "growth.star-vortex")
            #expect(owned.first { $0.awardKey == "ordinary.level.3" }?.collectibleID == "growth.light-tree")
            #expect(owned.first { $0.awardKey == "ordinary.level.1" }?.isUnseen == false)
            #expect(owned.first { $0.awardKey == "hidden.study.three-day-streak" }?.isUnseen == true)
            #expect(owned.first { $0.awardKey == "ordinary.level.1" }?.reason == "旧获得原因")
            let rewards = try context.fetch(FetchDescriptor<PendingCardReward>())
            #expect(Set(rewards.map(\.awardKey)) == ["ordinary.level.2", "ordinary.level.3", "ordinary.level.4", "hidden.health.first"])
            let pending = try #require(rewards.first { $0.awardKey == "ordinary.level.4" })
            #expect(pending.awardKey == "ordinary.level.4")
            #expect(pending.collectibleID == "ordinary.hare")
            #expect(pending.eligibleAt == date.addingTimeInterval(1.6))
        }
    }

    @Test func failedDiskSaveRollsBackCompletionXPCoinsAndAdultCardTogether() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let writable = try store(at: url)
            let context = writable.mainContext
            context.insert(LIVELVL.Progress(totalXP: 195))
            context.insert(Item(title: "行动", dimension: .learning, minutes: 30,
                                difficulty: 2, xp: 80, recurrence: .daily))
            try context.save()
        }
        let readonly = try store(at: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
        let task = try #require(context.fetch(FetchDescriptor<Item>()).first)
        #expect(throws: (any Error).self) {
            try TaskRewardCoordinator.complete(item: task, progress: progress, in: context)
        }
        #expect(progress.totalXP == 195)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func failedDiskRevokePreservesCompletionXPAndCoins() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly-revoke.store")
        try autoreleasepool {
            let writable = try store(at: url)
            let context = writable.mainContext
            let progress = LIVELVL.Progress()
            let task = Item(title: "行动", dimension: .learning, minutes: 30,
                            difficulty: 2, xp: 80, recurrence: .daily)
            context.insert(progress)
            context.insert(task)
            try context.save()
            try TaskRewardCoordinator.complete(item: task, progress: progress, in: context)
        }
        let readonly = try store(at: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
        let completion = try #require(context.fetch(FetchDescriptor<Completion>()).first)
        #expect(throws: (any Error).self) {
            try TaskRewardCoordinator.revoke(completion: completion, progress: progress, in: context)
        }
        #expect(progress.totalXP == 80)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
        #expect(try CoinLedgerService.balance(in: context) == 80)
        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 1)
        #expect(!context.hasChanges)
    }

    @Test func zeroXPCompletionKeepsBehaviorFactsWithoutUnmappedHiddenRewards() throws {
        let container = try ModelContainer(for: schema(), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = LIVELVL.Progress(totalXP: 400)
        let task = Item(title: "运动", dimension: .health, minutes: 60, difficulty: 2, xp: 80, recurrence: .daily)
        context.insert(progress)
        context.insert(task)
        context.insert(CollectionProgress(highestLevel: 1))
        context.insert(Completion(itemID: UUID(), xp: 400, date: now))
        try context.save()
        let result = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        #expect(result.completion.xp == 0)
        for _ in 0..<2 {
            try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
        }
        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        #expect(Set(pending.map(\.awardKey)) == ["ordinary.level.1", "hidden.health.first"])
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.collectibleID) == ["growth.star-vortex"])
        #expect(result.completion.durationMinutes == 60)
        #expect(result.completion.recordedDimension == .health)
        #expect(progress.totalXP == 400)
        #expect(try CoinLedgerService.balance(in: context) == 80)
    }

    @Test func adultCardAndTaskRewardsSurviveDiskReopenWithoutReaward() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("card-retry.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try autoreleasepool {
            let writable = try store(at: url)
            let context = writable.mainContext
            let progress = LIVELVL.Progress()
            let task = Item(title: "行动", dimension: .learning, minutes: 30, difficulty: 2, xp: 200, recurrence: .daily)
            context.insert(progress)
            context.insert(task)
            try context.save()
            try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        }
        try autoreleasepool {
            let readonly = try store(at: url, allowsSave: false)
            readonly.mainContext.autosaveEnabled = false
            try CardRewardService.reconcilePersistedRewards(in: readonly.mainContext, now: now, calendar: .current)
            #expect(Set(try readonly.mainContext.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)) == ["ordinary.level.1", "hidden.learning.first"])
            #expect(try readonly.mainContext.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey) == ["ordinary.level.1"])
        }
        try autoreleasepool {
            let recovered = try store(at: url)
            let context = recovered.mainContext
            for _ in 0..<2 {
                try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
            }
            #expect(Set(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)) == ["ordinary.level.1", "hidden.learning.first"])
            let adult = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
            #expect(adult.awardKey == "ordinary.level.1")
            #expect(adult.isUnseen)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 200)
            #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
            #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 1)
            #expect(try CoinLedgerService.balance(in: context) == 200)
        }
    }

    @Test func reopenAcknowledgesAdultOnDisk() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("adult-reopen.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try autoreleasepool {
            let store = try store(at: url)
            let context = store.mainContext
            let progress = LIVELVL.Progress(totalXP: 195)
            let task = Item(title: "升级任务", dimension: .learning, minutes: 20,
                            difficulty: 2, xp: 20, recurrence: .once)
            context.insert(progress)
            context.insert(task)
            try context.save()
            try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).count == 1)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).count == 2)
        }
        try autoreleasepool {
            let reopened = try store(at: url)
            let acknowledged = try CardRewardService.acknowledgeAlreadyOwnedOrdinaryRewards(
                in: reopened.mainContext, now: now
            )
            #expect(acknowledged == ["ordinary.level.1"])
        }
        try autoreleasepool {
            let reopened = try store(at: url)
            let context = reopened.mainContext
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey) == ["hidden.learning.first"])
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).first?.isUnseen == true)
            #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.activeOrdinaryIndex == 1)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 215)
            #expect(try CoinLedgerService.balance(in: context) == 20)
        }
    }

    @Test func diskRoundTripKeepsPartialAwardAndRevokeRemainsIdempotent() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("partial.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try autoreleasepool {
            let writable = try store(at: url)
            let context = writable.mainContext
            let progress = LIVELVL.Progress(totalXP: 350)
            let task = Item(title: "行动", dimension: .learning, minutes: 30, difficulty: 2, xp: 80, recurrence: .daily)
            context.insert(progress)
            context.insert(task)
            context.insert(Completion(itemID: UUID(), xp: 350, date: now))
            try context.save()
            try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        }
        try autoreleasepool {
            let reopened = try store(at: url)
            let context = reopened.mainContext
            let task = try #require(context.fetch(FetchDescriptor<Item>()).first)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            let completion = try #require(context.fetch(FetchDescriptor<Completion>()).first { $0.itemID == task.id })
            let row = TaskRailPresentation(item: task, completed: true, rewardXP: nil, completion: completion)
            #expect(row.displayedXPText == "50 XP")
            #expect(row.accessibilityValue.contains("标称 80 XP"))
            #expect(try TaskRewardCoordinator.revoke(completion: completion, progress: progress, in: context))
            #expect(try !TaskRewardCoordinator.revoke(completion: completion, progress: progress, in: context))
            #expect(progress.totalXP == 350)
            #expect(try CoinLedgerService.balance(in: context) == 0)
        }
        try autoreleasepool {
            let reopened = try store(at: url)
            let context = reopened.mainContext
            #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 2)
            let task = try #require(context.fetch(FetchDescriptor<Item>()).first)
            let progress = try #require(context.fetch(FetchDescriptor<LIVELVL.Progress>()).first)
            let again = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
            #expect(again.wasCreated)
            #expect(again.completion.xp == 50)
            #expect(progress.totalXP == 400)
            #expect(try CoinLedgerService.balance(in: context) == 80)
        }
    }

}
