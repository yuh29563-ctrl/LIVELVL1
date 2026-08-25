import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct CoinLedgerTests {
    @Test func coinUnitsDisplayWithOneDecimal() {
        #expect(CoinDisplayFormatter.text(forCoinUnits: 0) == "0.0")
        #expect(CoinDisplayFormatter.text(forCoinUnits: 1) == "0.1")
        #expect(CoinDisplayFormatter.text(forCoinUnits: 123) == "12.3")
    }

    @Test func legacyXPImportsExactlyOnce() throws {
        let schema = Schema([Progress.self, CoinTransaction.self])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let progress = Progress(totalXP: 250)
        context.insert(progress)
        try context.save()

        try CoinLedgerService.ensureLegacyXPImported(progress: progress, in: context)
        try CoinLedgerService.ensureLegacyXPImported(progress: progress, in: context)

        #expect(try CoinLedgerService.balance(in: context) == 250)
        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 1)
    }

    @Test func taskAwardIsIdempotentAndReversalIsBounded() throws {
        let schema = Schema([Completion.self, CoinTransaction.self])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let completion = Completion(itemID: UUID(), xp: 80)
        context.insert(completion)
        try context.save()

        try CoinLedgerService.awardTask(completion: completion, in: context)
        try CoinLedgerService.awardTask(completion: completion, in: context)
        #expect(try CoinLedgerService.balance(in: context) == 80)

        try CoinLedgerService.reverseTask(completion: completion, in: context)
        try CoinLedgerService.reverseTask(completion: completion, in: context)
        #expect(try CoinLedgerService.balance(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).count == 2)
    }

    @Test func reversalOnlyRemovesAvailableBalance() throws {
        let schema = Schema([Completion.self, CoinTransaction.self])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let completion = Completion(itemID: UUID(), xp: 80)
        context.insert(completion)
        context.insert(CoinTransaction(
            operationKey: "prior-debit",
            kind: .redemptionDebit,
            amountCoinUnits: -30,
            requestedCoinUnits: 30,
            sourceID: nil,
            createdAt: .now,
            note: "已兑换"
        ))
        try context.save()

        try CoinLedgerService.awardTask(completion: completion, in: context)
        try CoinLedgerService.reverseTask(completion: completion, in: context)

        #expect(try CoinLedgerService.balance(in: context) == 0)
        let reversal = try context.fetch(FetchDescriptor<CoinTransaction>())
            .first { $0.kind == .taskRevoked }
        #expect(reversal?.requestedCoinUnits == 80)
        #expect(reversal?.amountCoinUnits == -50)
    }
}
