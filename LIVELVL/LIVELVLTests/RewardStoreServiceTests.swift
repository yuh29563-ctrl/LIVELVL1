import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct RewardStoreServiceTests {
    @Test func displayPriceConvertsToIntegerCoinUnits() throws {
        #expect(try CoinDisplayFormatter.coinUnits(fromDisplayText: "12.3") == 123)
        #expect(try CoinDisplayFormatter.coinUnits(fromDisplayText: " 0.1 ") == 1)
        #expect(throws: RewardValidationError.invalidPrice) {
            try CoinDisplayFormatter.coinUnits(fromDisplayText: "12.34")
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CoinTransaction.self,
            RewardProduct.self,
            RewardRedemption.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    private func makeProduct(in context: ModelContext, price: Int = 50) throws -> RewardProduct {
        let product = try RewardStoreService.createProduct(
            name: "看一场电影",
            priceCoinUnits: price,
            note: "周末兑现",
            imageReference: "movie.image",
            in: context,
            now: Date(timeIntervalSince1970: 1_000)
        )
        return product
    }

    private func seedBalance(_ units: Int, in context: ModelContext) throws {
        context.insert(CoinTransaction(
            operationKey: "seed-\(units)-\(UUID().uuidString)",
            kind: .legacyImport,
            amountCoinUnits: units,
            requestedCoinUnits: units,
            sourceID: nil,
            createdAt: .now,
            note: "测试余额"
        ))
        try context.save()
    }

    @Test func productCanBeCreatedEditedAndArchivedWithoutDeletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = try makeProduct(in: context)

        try RewardStoreService.updateProduct(
            product,
            name: "看一场特别的电影",
            priceCoinUnits: 75,
            note: "和朋友一起",
            imageReference: "movie-2.image",
            in: context,
            now: Date(timeIntervalSince1970: 1_100)
        )
        try RewardStoreService.archive(product, in: context, now: Date(timeIntervalSince1970: 1_200))

        #expect(product.name == "看一场特别的电影")
        #expect(product.priceCoinUnits == 75)
        #expect(product.note == "和朋友一起")
        #expect(product.imageReference == "movie-2.image")
        #expect(product.isArchived)
        #expect(try context.fetch(FetchDescriptor<RewardProduct>()).count == 1)
    }

    @Test func insufficientBalanceDoesNotCreateDebitOrRedemption() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = try makeProduct(in: context, price: 100)
        try seedBalance(99, in: context)

        #expect(throws: RewardRedemptionError.insufficientBalance) {
            try RewardStoreService.redeem(
                product,
                requestKey: "request-insufficient",
                in: context,
                now: Date(timeIntervalSince1970: 1_300)
            )
        }
        #expect(try CoinLedgerService.balance(in: context) == 99)
        #expect(try context.fetch(FetchDescriptor<RewardRedemption>()).isEmpty)
        #expect(
            try context.fetch(FetchDescriptor<CoinTransaction>())
                .allSatisfy { $0.kind != .redemptionDebit }
        )
    }

    @Test func redemptionIsAtomicIdempotentAndKeepsProductSnapshotAfterEdit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = try makeProduct(in: context, price: 50)
        try seedBalance(100, in: context)

        let first = try RewardStoreService.redeem(
            product,
            requestKey: "request-atomic",
            in: context,
            now: Date(timeIntervalSince1970: 1_400)
        )
        let duplicate = try RewardStoreService.redeem(
            product,
            requestKey: "request-atomic",
            in: context,
            now: Date(timeIntervalSince1970: 1_500)
        )
        try RewardStoreService.updateProduct(
            product,
            name: "改名后的电影",
            priceCoinUnits: 90,
            note: "新备注",
            imageReference: nil,
            in: context,
            now: Date(timeIntervalSince1970: 1_600)
        )

        #expect(first.id == duplicate.id)
        #expect(try CoinLedgerService.balance(in: context) == 50)
        #expect(try context.fetch(FetchDescriptor<RewardRedemption>()).count == 1)
        #expect(first.productNameSnapshot == "看一场电影")
        #expect(first.priceCoinUnitsSnapshot == 50)
        #expect(first.noteSnapshot == "周末兑现")

        try RewardStoreService.fulfill(first, in: context, now: Date(timeIntervalSince1970: 1_700))
        try RewardStoreService.fulfill(first, in: context, now: Date(timeIntervalSince1970: 1_800))
        #expect(first.status == .fulfilled)
        #expect(first.fulfilledAt == Date(timeIntervalSince1970: 1_700))
    }

    @Test func archivedProductCannotBeRedeemed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = try makeProduct(in: context)
        try seedBalance(100, in: context)
        try RewardStoreService.archive(product, in: context)

        #expect(throws: RewardRedemptionError.productArchived) {
            try RewardStoreService.redeem(
                product,
                requestKey: "request-archived",
                in: context
            )
        }
    }
}

@MainActor
struct RewardProductImageStoreTests {
    @Test func savesLoadsAndReplacesImageWithoutChangingTheHistoricalFile() throws {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: applicationSupportURL) }

        let reference = try RewardProductImageStore.save(
            Data([0x01, 0x02]),
            applicationSupportURL: applicationSupportURL
        )
        let imageURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
            .appending(path: reference)
        #expect(reference.hasSuffix(".image"))
        #expect(fileManager.fileExists(atPath: imageURL.path))
        #expect(
            try RewardProductImageStore.load(
                reference: reference,
                applicationSupportURL: applicationSupportURL
            ) == Data([0x01, 0x02])
        )

        let replacement = try RewardProductImageStore.save(
            Data([0x03]),
            applicationSupportURL: applicationSupportURL
        )
        #expect(replacement != reference)
        #expect(
            try RewardProductImageStore.load(
                reference: reference,
                applicationSupportURL: applicationSupportURL
            ) == Data([0x01, 0x02])
        )
        #expect(
            try RewardProductImageStore.load(
                reference: replacement,
                applicationSupportURL: applicationSupportURL
            ) == Data([0x03])
        )
    }
}
