import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct RewardModelsTests {
    @Test func modelsRoundTrip() throws {
        let schema = Schema([
            CoinTransaction.self,
            RewardProduct.self,
            RewardRedemption.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let transaction = CoinTransaction(
            operationKey: "legacy-xp-import",
            kind: .legacyImport,
            amountCoinUnits: 123,
            requestedCoinUnits: 123,
            sourceID: nil,
            createdAt: Date(timeIntervalSince1970: 10),
            note: "首次导入"
        )
        let product = RewardProduct(
            name: "看一场电影",
            priceCoinUnits: 100,
            note: "周末兑现",
            imageReference: "image-1.png",
            createdAt: Date(timeIntervalSince1970: 11)
        )
        let redemption = RewardRedemption(
            requestKey: "request-1",
            productID: product.id,
            productNameSnapshot: product.name,
            priceCoinUnitsSnapshot: product.priceCoinUnits,
            noteSnapshot: product.note,
            imageReferenceSnapshot: product.imageReference,
            redeemedAt: Date(timeIntervalSince1970: 12),
            status: .pending
        )
        context.insert(transaction)
        context.insert(product)
        context.insert(redemption)
        try context.save()

        let storedTransaction = try #require(
            context.fetch(FetchDescriptor<CoinTransaction>()).first
        )
        let storedProduct = try #require(
            context.fetch(FetchDescriptor<RewardProduct>()).first
        )
        let storedRedemption = try #require(
            context.fetch(FetchDescriptor<RewardRedemption>()).first
        )
        #expect(storedTransaction.operationKey == "legacy-xp-import")
        #expect(storedTransaction.amountCoinUnits == 123)
        #expect(storedProduct.imageReference == "image-1.png")
        #expect(storedProduct.isArchived == false)
        #expect(storedRedemption.status == .pending)
        #expect(storedRedemption.productNameSnapshot == "看一场电影")
    }

    @Test func validationRejectsBlankNamesAndNonPositivePrices() {
        #expect(throws: RewardValidationError.emptyName) {
            try RewardProduct.validate(name: "  ", priceCoinUnits: 10)
        }
        #expect(throws: RewardValidationError.invalidPrice) {
            try RewardProduct.validate(name: "看电影", priceCoinUnits: 0)
        }
    }
}
