import Foundation

nonisolated struct RewardProductRailPresentation: Equatable, Sendable {
    let name: String
    let priceCoinUnits: Int
    let note: String
    let imageReference: String?
    let balanceCoinUnits: Int?
    let isArchived: Bool

    var showsImage: Bool { imageReference != nil }
    var canRedeem: Bool {
        guard let balanceCoinUnits else { return false }
        return !isArchived && balanceCoinUnits >= priceCoinUnits
    }
    var canArchive: Bool { !isArchived }
    var statusText: String {
        if isArchived { return "已归档" }
        guard balanceCoinUnits != nil else { return "余额不可用" }
        return canRedeem ? "可兑换" : "余额不足"
    }
    var fallbackSystemImageName: String? { nil }
}

nonisolated enum RewardBalancePresentation: Equatable, Sendable {
    case available(Int)
    case unavailable

    var coinUnits: Int? {
        guard case let .available(value) = self else { return nil }
        return value
    }

    var allowsRedemption: Bool {
        if case .available = self { return true }
        return false
    }
}

nonisolated struct RewardRedemptionSubmissionState: Equatable, Sendable {
    private(set) var productID: UUID?
    private(set) var requestKey: String?

    var isSubmitting: Bool { requestKey != nil }

    mutating func begin(productID: UUID) -> String? {
        guard requestKey == nil else { return nil }
        let requestKey = UUID().uuidString
        self.productID = productID
        self.requestKey = requestKey
        return requestKey
    }

    mutating func finish() {
        productID = nil
        requestKey = nil
    }
}

nonisolated enum RewardLedgerGeometry {
    static func samples(
        count: Int,
        balanceCoinUnits: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [LivingDotSample] {
        guard count > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.21 : phase - floor(phase)
        let balanceSeed = Double(abs(balanceCoinUnits % 997)) / 997

        return (0..<count).map { index in
            let x = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            let seed = Double((index * 53 + 17) % 101) / 101
            let angle = (resolvedPhase + seed + balanceSeed * 0.18) * .pi * 2
            let wave = sin(x * .pi * 5 + angle)
            let drift = reduceMotion ? 0 : cos(angle * 0.82 + x * 9) * 0.004

            return LivingDotSample(
                position: CGPoint(
                    x: min(1, max(0, x + drift)),
                    y: min(1, max(0, 0.5 + wave * 0.23))
                ),
                opacity: 0.18 + seed * 0.48,
                diameter: 0.8 + seed * 1.5
            )
        }
    }
}

@MainActor
enum RewardProductEditorRoute: Identifiable {
    enum ID: Hashable {
        case create
        case edit(UUID)
    }

    case create
    case edit(RewardProduct)

    var id: ID {
        switch self {
        case .create: .create
        case let .edit(product): .edit(product.id)
        }
    }

    var product: RewardProduct? {
        guard case let .edit(product) = self else { return nil }
        return product
    }
}
