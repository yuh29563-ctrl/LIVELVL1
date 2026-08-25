import Foundation
import SwiftData

enum CoinTransactionKind: String, Codable, Sendable {
    case legacyImport
    case taskEarned
    case taskRevoked
    case redemptionDebit
}

enum RewardRedemptionStatus: String, Codable, Sendable {
    case pending
    case fulfilled
}

enum RewardValidationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidPrice

    var errorDescription: String? {
        switch self {
        case .emptyName: "奖励名称不能为空"
        case .invalidPrice: "奖励价格必须大于 0"
        }
    }
}

enum CoinLedgerError: Error, Equatable, LocalizedError {
    case negativeBalance

    var errorDescription: String? {
        switch self {
        case .negativeBalance: "金币账本余额不能为负"
        }
    }
}

@Model
final class CoinTransaction {
    var id: UUID
    @Attribute(.unique) var operationKey: String
    var kindRaw: String
    var amountCoinUnits: Int
    var requestedCoinUnits: Int
    var sourceID: UUID?
    var createdAt: Date
    var note: String

    init(
        operationKey: String,
        kind: CoinTransactionKind,
        amountCoinUnits: Int,
        requestedCoinUnits: Int,
        sourceID: UUID?,
        createdAt: Date,
        note: String
    ) {
        id = UUID()
        self.operationKey = operationKey
        kindRaw = kind.rawValue
        self.amountCoinUnits = amountCoinUnits
        self.requestedCoinUnits = max(0, requestedCoinUnits)
        self.sourceID = sourceID
        self.createdAt = createdAt
        self.note = note
    }

    var kind: CoinTransactionKind {
        get { CoinTransactionKind(rawValue: kindRaw) ?? .taskEarned }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class RewardProduct {
    @Attribute(.unique) var id: UUID
    var name: String
    var priceCoinUnits: Int
    var note: String
    var imageReference: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(
        name: String,
        priceCoinUnits: Int,
        note: String = "",
        imageReference: String? = nil,
        createdAt: Date = .now
    ) {
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.priceCoinUnits = priceCoinUnits
        self.note = note
        self.imageReference = imageReference
        self.createdAt = createdAt
        updatedAt = createdAt
        isArchived = false
    }

    static func validate(name: String, priceCoinUnits: Int) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RewardValidationError.emptyName
        }
        guard priceCoinUnits > 0 else {
            throw RewardValidationError.invalidPrice
        }
    }
}

@Model
final class RewardRedemption {
    var id: UUID
    @Attribute(.unique) var requestKey: String
    var productID: UUID?
    var productNameSnapshot: String
    var priceCoinUnitsSnapshot: Int
    var noteSnapshot: String
    var imageReferenceSnapshot: String?
    var redeemedAt: Date
    var statusRaw: String
    var fulfilledAt: Date?

    init(
        requestKey: String,
        productID: UUID?,
        productNameSnapshot: String,
        priceCoinUnitsSnapshot: Int,
        noteSnapshot: String,
        imageReferenceSnapshot: String?,
        redeemedAt: Date,
        status: RewardRedemptionStatus
    ) {
        id = UUID()
        self.requestKey = requestKey
        self.productID = productID
        self.productNameSnapshot = productNameSnapshot
        self.priceCoinUnitsSnapshot = priceCoinUnitsSnapshot
        self.noteSnapshot = noteSnapshot
        self.imageReferenceSnapshot = imageReferenceSnapshot
        self.redeemedAt = redeemedAt
        statusRaw = status.rawValue
        fulfilledAt = nil
    }

    var status: RewardRedemptionStatus {
        get { RewardRedemptionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
