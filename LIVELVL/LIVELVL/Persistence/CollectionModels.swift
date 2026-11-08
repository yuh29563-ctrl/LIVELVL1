import Foundation
import SwiftData

enum CardRewardKind: String, Codable, Sendable {
    case ordinaryMature
    case hiddenDiscovery
}

@Model
final class CollectionProgress {
    @Attribute(.unique) var singletonKey: String
    var highestLevel: Int
    var activeOrdinaryIndex: Int
    var activeStageRaw: Int
    var lastProcessedMaturityLevel: Int
    var growthCatalogRevision: Int = 0
    var hiddenCardsEnabledAt: Date? = nil
    var hiddenCardsTimeZoneIdentifier: String? = nil

    init(
        singletonKey: String = "collection.progress",
        highestLevel: Int = 0,
        activeOrdinaryIndex: Int = 0,
        activeStage: CompanionStage = .juvenile,
        lastProcessedMaturityLevel: Int = -1,
        growthCatalogRevision: Int = 1
    ) {
        self.singletonKey = singletonKey
        self.highestLevel = highestLevel
        self.activeOrdinaryIndex = activeOrdinaryIndex
        activeStageRaw = activeStage.rawValue
        self.lastProcessedMaturityLevel = lastProcessedMaturityLevel
        self.growthCatalogRevision = growthCatalogRevision
    }

    var activeStage: CompanionStage {
        get { CompanionStage(rawValue: activeStageRaw) ?? .juvenile }
        set { activeStageRaw = newValue.rawValue }
    }
}

@Model
final class OwnedCollectible {
    @Attribute(.unique) var awardKey: String
    var collectibleID: String
    var kindRaw: String
    var reason: String
    var acquiredAt: Date
    var isUnseen: Bool

    init(
        awardKey: String,
        collectibleID: String,
        kind: CardRewardKind,
        reason: String,
        acquiredAt: Date = .now,
        isUnseen: Bool = true
    ) {
        self.awardKey = awardKey
        self.collectibleID = collectibleID
        kindRaw = kind.rawValue
        self.reason = reason
        self.acquiredAt = acquiredAt
        self.isUnseen = isUnseen
    }

    var kind: CardRewardKind {
        CardRewardKind(rawValue: kindRaw) ?? .ordinaryMature
    }
}

@Model
final class PendingCardReward {
    @Attribute(.unique) var awardKey: String
    var collectibleID: String
    var kindRaw: String
    var reason: String
    var maturityLevel: Int?
    var triggeredAt: Date
    var eligibleAt: Date

    init(
        awardKey: String,
        collectibleID: String,
        kind: CardRewardKind,
        reason: String,
        maturityLevel: Int? = nil,
        triggeredAt: Date,
        eligibleAt: Date
    ) {
        self.awardKey = awardKey
        self.collectibleID = collectibleID
        kindRaw = kind.rawValue
        self.reason = reason
        self.maturityLevel = maturityLevel
        self.triggeredAt = triggeredAt
        self.eligibleAt = eligibleAt
    }

    var kind: CardRewardKind {
        CardRewardKind(rawValue: kindRaw) ?? .ordinaryMature
    }
}
