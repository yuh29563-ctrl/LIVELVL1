import Foundation
import SwiftData

enum RewardRedemptionError: LocalizedError, Equatable {
    case insufficientBalance
    case productArchived
    case invalidRequestKey

    var errorDescription: String? {
        switch self {
        case .insufficientBalance:
            "金币余额不足"
        case .productArchived:
            "该奖励已归档"
        case .invalidRequestKey:
            "兑换请求无效"
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
        guard redemption.status != .fulfilled else { return }
        redemption.status = .fulfilled
        redemption.fulfilledAt = now
        try save(context)
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
