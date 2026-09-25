import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct TaskRewardCoordinatorTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Item.self,
            Progress.self,
            Completion.self,
            CoinTransaction.self,
            CollectionProgress.self,
            OwnedCollectible.self,
            PendingCardReward.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    private func makeItem(xp: Int = 80) -> Item {
        Item(
            title: "读书 20 分钟",
            dimension: .learning,
            minutes: 20,
            difficulty: 2,
            xp: xp,
            recurrence: .once
        )
    }

    @Test func completingTaskPersistsXPCompletionAndCoinAwardTogether() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = LIVELVL.Progress()
        let item = makeItem()
        context.insert(progress)
        context.insert(item)
        try context.save()

        let completion = try TaskRewardCoordinator.complete(
            item: item,
            progress: progress,
            in: context,
            now: Date(timeIntervalSince1970: 1_000)
        ).completion

        #expect(completion.itemID == item.id)
        #expect(progress.totalXP == 80)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
        #expect(try CoinLedgerService.balance(in: context) == 80)
        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).map(\.kind) == [.taskEarned])
    }

    @Test func revokingTaskRemovesCompletionRollsBackXPAndOnlyReversesAvailableCoins() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = LIVELVL.Progress()
        let item = makeItem(xp: 80)
        context.insert(progress)
        context.insert(item)
        context.insert(CoinTransaction(
            operationKey: "redemption:prior",
            kind: .redemptionDebit,
            amountCoinUnits: -30,
            requestedCoinUnits: 30,
            sourceID: nil,
            createdAt: .now,
            note: "已兑换"
        ))
        try context.save()

        let completion = try TaskRewardCoordinator.complete(
            item: item,
            progress: progress,
            in: context,
            now: Date(timeIntervalSince1970: 1_100)
        ).completion
        try TaskRewardCoordinator.revoke(
            completion: completion,
            progress: progress,
            in: context,
            now: Date(timeIntervalSince1970: 1_200)
        )

        #expect(progress.totalXP == 0)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try CoinLedgerService.balance(in: context) == 0)
        let transactions = try context.fetch(FetchDescriptor<CoinTransaction>())
        let reversal = try #require(transactions.first { $0.kind == .taskRevoked })
        #expect(reversal.amountCoinUnits == -50)
        #expect(reversal.requestedCoinUnits == 80)
    }

    @Test func editingTaskUpdatesFutureTemplateWithoutRewritingCompletionSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = makeItem(xp: 20)
        let originalID = item.id
        let originalCreatedAt = item.createdAt
        let completion = Completion(
            itemID: item.id,
            xp: 20,
            dimension: .learning,
            durationMinutes: 20,
            taskTitle: "读书 20 分钟"
        )
        context.insert(item)
        context.insert(completion)
        try context.save()

        try TaskMutationService.update(
            item,
            draft: TaskDraft(
                title: " 跑步 45 分钟 ",
                dimension: .health,
                minutes: 45,
                difficulty: 4,
                recurrence: .weekly
            ),
            in: context
        )

        #expect(item.id == originalID)
        #expect(item.createdAt == originalCreatedAt)
        #expect(item.title == "跑步 45 分钟")
        #expect(item.dimension == .health)
        #expect(item.minutes == 45)
        #expect(item.difficulty == 4)
        #expect(item.recurrence == .weekly)
        #expect(item.xp == 65)
        #expect(completion.taskTitle == "读书 20 分钟")
        #expect(completion.recordedDimension == .learning)
        #expect(completion.durationMinutes == 20)
        #expect(completion.xp == 20)
    }

    @Test func archivingAndRestoringTaskPreservesCompletionAndRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = LIVELVL.Progress()
        let item = makeItem(xp: 80)
        context.insert(progress)
        context.insert(item)
        try context.save()
        _ = try TaskRewardCoordinator.complete(item: item, progress: progress, in: context)

        try TaskMutationService.archive(item, in: context)

        #expect(item.isArchived)
        #expect(TodayTaskCollection.activeItems(from: [item]).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
        #expect(progress.totalXP == 80)
        #expect(try CoinLedgerService.balance(in: context) == 80)

        try TaskMutationService.restore(item, in: context)

        #expect(!item.isArchived)
        #expect(TodayTaskCollection.activeItems(from: [item]).map(\.id) == [item.id])
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
        #expect(progress.totalXP == 80)
        #expect(try CoinLedgerService.balance(in: context) == 80)
    }
}
