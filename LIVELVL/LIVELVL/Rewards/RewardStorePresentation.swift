import Foundation

nonisolated enum RewardProductTrailingAccessory: Equatable, Sendable {
    case image
    case redeem
    case insufficient
    case archived
}

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
    var trailingAccessory: RewardProductTrailingAccessory {
        if showsImage { return .image }
        if isArchived { return .archived }
        return canRedeem ? .redeem : .insufficient
    }
    var statusText: String {
        if isArchived { return "已归档" }
        guard balanceCoinUnits != nil else { return "余额不可用" }
        return canRedeem ? "可兑换" : "余额不足"
    }
    var fallbackSystemImageName: String? { nil }
    var accessibilityLabel: String {
        let price = CoinDisplayFormatter.text(forCoinUnits: priceCoinUnits)
        let noteText = note.isEmpty ? "" : "，\(note)"
        return "\(name)，\(price) 金币\(noteText)，\(statusText)"
    }
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

nonisolated enum RewardStoreLayout {
    static let pageTopPadding: CGFloat = 8
    static let balanceTopSpacing: CGFloat = 24
    static let balanceInternalSpacing: CGFloat = 0
    static let productTopSpacing: CGFloat = 69
    static let particleTrailTopOffset: CGFloat = 125

    static func usesVerticalBalanceLayout(isAccessibilitySize: Bool) -> Bool {
        isAccessibilitySize
    }
}

nonisolated struct RewardLedgerSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
    let row: Int
    let column: Int
    let isFilled: Bool
}

nonisolated enum RewardLedgerGeometry {
    static func samples(
        columns: Int,
        rows: Int,
        balanceCoinUnits: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [RewardLedgerSample] {
        guard columns > 0, rows > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.21 : phase - floor(phase)
        let balanceSeed = Double(abs(balanceCoinUnits % 997)) / 997
        let cycleBalance = abs(balanceCoinUnits % 1_000)
        let filledColumns = min(
            columns,
            max(0, Int((Double(cycleBalance) / 1_000 * Double(columns)).rounded()))
        )
        var result: [RewardLedgerSample] = []
        result.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let baseX = columns == 1 ? 0.5 : Double(column) / Double(columns - 1)
                let baseY = rows == 1 ? 0.5 : Double(row) / Double(rows - 1)
                let index = row * columns + column
                let seed = Double((index * 53 + 17) % 101) / 101
                let angle = (resolvedPhase + seed + balanceSeed * 0.18) * .pi * 2
                let driftX = reduceMotion ? 0 : cos(angle + baseY * 4) * 0.003
                let driftY = reduceMotion ? 0 : sin(angle * 0.82 + baseX * 8) * 0.006
                let isFilled = row == rows - 1 && column < filledColumns

                result.append(
                    RewardLedgerSample(
                        position: CGPoint(
                            x: min(1, max(0, baseX + driftX)),
                            y: min(1, max(0, baseY + driftY))
                        ),
                        opacity: isFilled ? 0.92 : 0.10 + seed * 0.13,
                        diameter: isFilled ? 2.25 : 1.4 + CGFloat(seed) * 0.45,
                        row: row,
                        column: column,
                        isFilled: isFilled
                    )
                )
            }
        }

        return result
    }
}

nonisolated struct RewardPageTrailSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
    let usesLightInk: Bool
}

nonisolated enum RewardPageTrailGeometry {
    static func samples(
        count: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [RewardPageTrailSample] {
        guard count > 1, !reduceMotion else { return [] }
        let resolvedPhase = phase - floor(phase)

        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let inverse = 1 - t
            let seed = Double((index * 61 + 23) % 101) / 101
            let baseX = inverse * inverse * 0.48
                + 2 * inverse * t * 0.40
                + t * t * 0.82
            let taper = sin(t * .pi)
            let dance = sin((resolvedPhase + seed) * .pi * 2 + t * 13)
            let driftX = dance * taper * 0.008
            let driftY = cos((resolvedPhase * 0.8 + seed) * .pi * 2) * taper * 0.004

            return RewardPageTrailSample(
                position: CGPoint(
                    x: min(1, max(0, baseX + driftX)),
                    y: min(1, max(0, t + driftY))
                ),
                opacity: 0.16 + t * 0.56 + seed * 0.12,
                diameter: 1 + CGFloat(t) * 1.4 + CGFloat(seed) * 0.55,
                usesLightInk: t > 0.66
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
