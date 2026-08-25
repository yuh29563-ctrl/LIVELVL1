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
        )

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
        )
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
}
