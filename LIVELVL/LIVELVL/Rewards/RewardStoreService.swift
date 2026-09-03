import Foundation
import SwiftData

enum RewardRedemptionError: LocalizedError, Equatable {
    case insufficientBalance
    case productArchived
    case invalidRequestKey
    case redemptionAlreadyFulfilled

    var errorDescription: String? {
        switch self {
        case .insufficientBalance:
            "金币余额不足"
        case .productArchived:
            "该奖励已归档"
        case .invalidRequestKey:
            "兑换请求无效"
        case .redemptionAlreadyFulfilled:
            "已兑现的奖励不能取消兑换"
        }
    }
}

@MainActor
enum RewardStoreService {
    static func createProduct(
        name: String,
        priceCoinUnits: Int,
        note: String,
        imageReference: String?,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RewardProduct {
        let normalizedName = try RewardProduct.validatedName(name)
        try RewardProduct.validate(name: normalizedName, priceCoinUnits: priceCoinUnits)
        let product = RewardProduct(
            name: normalizedName,
            priceCoinUnits: priceCoinUnits,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            imageReference: imageReference,
            createdAt: now
        )
        context.insert(product)
        try save(context)
        return product
    }

    static func updateProduct(
        _ product: RewardProduct,
        name: String,
        priceCoinUnits: Int,
        note: String,
        imageReference: String?,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let normalizedName = try RewardProduct.validatedName(name)
        try RewardProduct.validate(name: normalizedName, priceCoinUnits: priceCoinUnits)
        product.name = normalizedName
        product.priceCoinUnits = priceCoinUnits
        product.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        product.imageReference = imageReference
        product.updatedAt = now
        try save(context)
    }

    static func archive(
        _ product: RewardProduct,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !product.isArchived else { return }
        product.isArchived = true
        product.updatedAt = now
        try save(context)
    }

    @discardableResult
    static func redeem(
        _ product: RewardProduct,
        requestKey: String,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RewardRedemption {
        let normalizedRequestKey = requestKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRequestKey.isEmpty else {
            throw RewardRedemptionError.invalidRequestKey
        }
        if let existing = try context.fetch(FetchDescriptor<RewardRedemption>())
            .first(where: { $0.requestKey == normalizedRequestKey }) {
            return existing
        }
        guard !product.isArchived else {
            throw RewardRedemptionError.productArchived
        }
        let balance = try CoinLedgerService.balance(in: context)
        guard balance >= product.priceCoinUnits else {
            throw RewardRedemptionError.insufficientBalance
        }

        context.insert(CoinTransaction(
            operationKey: "redemption-debit:\(normalizedRequestKey)",
            kind: .redemptionDebit,
            amountCoinUnits: -product.priceCoinUnits,
            requestedCoinUnits: product.priceCoinUnits,
            sourceID: product.id,
            createdAt: now,
            note: "兑换现实奖励"
        ))
        let redemption = RewardRedemption(
            requestKey: normalizedRequestKey,
            productID: product.id,
            productNameSnapshot: product.name,
            priceCoinUnitsSnapshot: product.priceCoinUnits,
            noteSnapshot: product.note,
            imageReferenceSnapshot: product.imageReference,
            redeemedAt: now,
            status: .pending
        )
        context.insert(redemption)
        try save(context)
        return redemption
    }

    static func fulfill(
        _ redemption: RewardRedemption,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard redemption.status == .pending else { return }
        redemption.status = .fulfilled
        redemption.fulfilledAt = now
        try save(context)
    }

    static func cancel(
        _ redemption: RewardRedemption,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard redemption.status != .cancelled else { return }
        guard redemption.status != .fulfilled else {
            throw RewardRedemptionError.redemptionAlreadyFulfilled
        }

        let operationKey = "redemption-refund:\(redemption.id.uuidString)"
        let transactions = try context.fetch(FetchDescriptor<CoinTransaction>())
        let restoredProductID = try restoreProductIfNeeded(
            for: redemption,
            in: context,
            now: now
        )
        if !transactions.contains(where: { $0.operationKey == operationKey }) {
            context.insert(CoinTransaction(
                operationKey: operationKey,
                kind: .redemptionRefund,
                amountCoinUnits: redemption.priceCoinUnitsSnapshot,
                requestedCoinUnits: redemption.priceCoinUnitsSnapshot,
                sourceID: restoredProductID,
                createdAt: now,
                note: "取消兑换退回金币"
            ))
        }
        redemption.status = .cancelled
        redemption.cancelledAt = now
        try save(context)
    }

    private static func restoreProductIfNeeded(
        for redemption: RewardRedemption,
        in context: ModelContext,
        now: Date
    ) throws -> UUID {
        let products = try context.fetch(FetchDescriptor<RewardProduct>())
        if let productID = redemption.productID,
           let product = products.first(where: { $0.id == productID }) {
            if product.isArchived {
                product.isArchived = false
                product.updatedAt = now
            }
            return product.id
        }

        let restored = RewardProduct(
            name: redemption.productNameSnapshot,
            priceCoinUnits: redemption.priceCoinUnitsSnapshot,
            note: redemption.noteSnapshot,
            imageReference: redemption.imageReferenceSnapshot,
            createdAt: now
        )
        if let productID = redemption.productID {
            restored.id = productID
        } else {
            redemption.productID = restored.id
        }
        context.insert(restored)
        return restored.id
    }

    static func hideFromHistory(
        _ redemption: RewardRedemption,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard redemption.historyHiddenAt == nil else { return }
        redemption.historyHiddenAt = now
        try save(context)
    }

    static func deleteProduct(
        _ product: RewardProduct,
        in context: ModelContext
    ) throws {
        context.delete(product)
        try save(context)
    }

    static func imageReferenceIsInUse(
        _ reference: String,
        in context: ModelContext
    ) throws -> Bool {
        let isUsedByProduct = try context.fetch(FetchDescriptor<RewardProduct>())
            .contains { $0.imageReference == reference }
        if isUsedByProduct { return true }
        return try context.fetch(FetchDescriptor<RewardRedemption>())
            .contains { $0.imageReferenceSnapshot == reference }
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum RewardProductImageStore {
    static let directoryName = "RewardProductImages"

    static func save(
        _ data: Data,
        reference: String? = nil,
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws -> String {
        let reference = reference ?? "\(UUID().uuidString).image"
        let fileURL = try fileURL(
            for: reference,
            applicationSupportURL: applicationSupportURL,
            fileManager: fileManager
        )
        try data.write(to: fileURL, options: [.atomic])
        return reference
    }

    static func load(
        reference: String,
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws -> Data {
        try Data(contentsOf: fileURL(
            for: reference,
            applicationSupportURL: applicationSupportURL,
            fileManager: fileManager
        ))
    }

    static func remove(
        reference: String,
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let url = try fileURL(
            for: reference,
            applicationSupportURL: applicationSupportURL,
            fileManager: fileManager
        )
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private static func fileURL(
        for reference: String,
        applicationSupportURL: URL,
        fileManager: FileManager
    ) throws -> URL {
        guard !reference.isEmpty,
              reference == URL(fileURLWithPath: reference).lastPathComponent,
              reference.hasSuffix(".image") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directoryURL = applicationSupportURL.appending(
            path: directoryName,
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL.appending(path: reference)
    }
}
