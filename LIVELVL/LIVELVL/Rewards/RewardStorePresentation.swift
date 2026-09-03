import Foundation

nonisolated enum RewardProductTrailingAccessory: Equatable, Sendable {
    case image
    case redeem
    case insufficient
    case redeemed
    case archived
}

nonisolated struct RewardProductRailPresentation: Equatable, Sendable {
    let name: String
    let priceCoinUnits: Int
    let note: String
    let imageReference: String?
    let balanceCoinUnits: Int?
    let isArchived: Bool
    let isRedeemed: Bool

    init(
        name: String,
        priceCoinUnits: Int,
        note: String,
        imageReference: String?,
        balanceCoinUnits: Int?,
        isArchived: Bool,
        isRedeemed: Bool = false
    ) {
        self.name = name
        self.priceCoinUnits = priceCoinUnits
        self.note = note
        self.imageReference = imageReference
        self.balanceCoinUnits = balanceCoinUnits
        self.isArchived = isArchived
        self.isRedeemed = isRedeemed
    }

    var showsImage: Bool { imageReference != nil }
    var canRedeem: Bool {
        guard let balanceCoinUnits else { return false }
        return !isArchived && !isRedeemed && balanceCoinUnits >= priceCoinUnits
    }
    var canArchive: Bool { !isArchived }
    var trailingAccessory: RewardProductTrailingAccessory {
        if isArchived { return .archived }
        if isRedeemed { return .redeemed }
        if showsImage { return .image }
        return canRedeem ? .redeem : .insufficient
    }
    var statusText: String {
        if isArchived { return "已归档" }
        if isRedeemed { return "已兑换" }
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

nonisolated struct RewardRedemptionVisibility: Equatable, Sendable {
    let productID: UUID?
    let status: RewardRedemptionStatus
    let isHiddenFromHistory: Bool
}

nonisolated enum RewardProductVisibility {
    static func hiddenProductIDs(
        redemptions: [RewardRedemptionVisibility]
    ) -> Set<UUID> {
        Set(redemptions.compactMap { redemption in
            guard redemption.status != .cancelled else { return nil }
            return redemption.productID
        })
    }
}

nonisolated struct RewardRedemptionHistoryPresentation: Equatable, Sendable {
    let status: RewardRedemptionStatus

    var statusText: String {
        switch status {
        case .pending: "已兑换"
        case .fulfilled: "已兑现"
        case .cancelled: "已取消"
        }
    }

    var canCancel: Bool { status == .pending }
    var canFulfill: Bool { status == .pending }
}

nonisolated struct RewardGuidanceProduct: Equatable, Sendable {
    let id: UUID
    let priceCoinUnits: Int
    let isArchived: Bool
    let isRedeemed: Bool

    init(
        id: UUID,
        priceCoinUnits: Int,
        isArchived: Bool,
        isRedeemed: Bool = false
    ) {
        self.id = id
        self.priceCoinUnits = priceCoinUnits
        self.isArchived = isArchived
        self.isRedeemed = isRedeemed
    }
}

nonisolated enum RewardGuidanceStatus: Equatable, Sendable {
    case affordable
    case progress(missingCoinUnits: Int)

    var displayText: String {
        switch self {
        case .affordable:
            "可兑换"
        case let .progress(missingCoinUnits):
            "还差 \(CoinDisplayFormatter.text(forCoinUnits: missingCoinUnits)) 金币"
        }
    }
}

nonisolated struct RewardGuidanceTarget: Equatable, Sendable {
    let productID: UUID
    let status: RewardGuidanceStatus
}

nonisolated enum RewardGuidanceTargetResolver {
    static func resolve(
        products: [RewardGuidanceProduct],
        balanceCoinUnits: Int?
    ) -> RewardGuidanceTarget? {
        guard let balanceCoinUnits, balanceCoinUnits >= 0 else { return nil }
        let validProducts = products.filter {
            !$0.isArchived && !$0.isRedeemed && $0.priceCoinUnits > 0
        }
        guard let firstProduct = validProducts.first else { return nil }

        if let affordable = validProducts.first(where: {
            balanceCoinUnits >= $0.priceCoinUnits
        }) {
            return RewardGuidanceTarget(
                productID: affordable.id,
                status: .affordable
            )
        }

        let nearest = validProducts.dropFirst().reduce(firstProduct) { current, candidate in
            let currentShortfall = current.priceCoinUnits - balanceCoinUnits
            let candidateShortfall = candidate.priceCoinUnits - balanceCoinUnits
            return candidateShortfall < currentShortfall ? candidate : current
        }
        return RewardGuidanceTarget(
            productID: nearest.id,
            status: .progress(
                missingCoinUnits: nearest.priceCoinUnits - balanceCoinUnits
            )
        )
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

nonisolated enum RewardRedemptionFeedback {
    static let successMessage = "兑换成功"
}

nonisolated enum RewardStoreLayout {
    static let pageTopPadding: CGFloat = 8
    static let balanceTopSpacing: CGFloat = 24
    static let balanceInternalSpacing: CGFloat = 0
    static let productTopSpacing: CGFloat = 69
    static let heroMinimumScale = 0.55

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
    let fillFraction: Double
    let isFilled: Bool
}

nonisolated struct RewardLedgerFill: Equatable, Sendable {
    let fullPointCount: Int
    let partialPointFraction: Double
    let overflowCoinUnits: Int

    var overflowText: String? {
        guard overflowCoinUnits > 0 else { return nil }
        return "+\(CoinDisplayFormatter.text(forCoinUnits: overflowCoinUnits))"
    }
}

nonisolated enum RewardLedgerGeometry {
    static let coinUnitsPerPoint = 100

    static func fill(
        columns: Int,
        rows: Int,
        balanceCoinUnits: Int
    ) -> RewardLedgerFill {
        let pointCount = max(0, columns) * max(0, rows)
        let capacityCoinUnits = pointCount * coinUnitsPerPoint
        let availableCoinUnits = max(0, balanceCoinUnits)
        let visibleCoinUnits = min(availableCoinUnits, capacityCoinUnits)
        let fullPointCount = visibleCoinUnits / coinUnitsPerPoint
        let remainderCoinUnits = visibleCoinUnits % coinUnitsPerPoint
        let partialPointFraction = fullPointCount < pointCount
            ? Double(remainderCoinUnits) / Double(coinUnitsPerPoint)
            : 0

        return RewardLedgerFill(
            fullPointCount: fullPointCount,
            partialPointFraction: partialPointFraction,
            overflowCoinUnits: max(0, availableCoinUnits - capacityCoinUnits)
        )
    }

    static func samples(
        columns: Int,
        rows: Int,
        balanceCoinUnits: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [RewardLedgerSample] {
        samples(
            columns: columns,
            rows: rows,
            displayedBalanceCoinUnits: Double(max(0, balanceCoinUnits)),
            phase: phase,
            reduceMotion: reduceMotion
        )
    }

    static func samples(
        columns: Int,
        rows: Int,
        displayedBalanceCoinUnits: Double,
        phase: Double,
        reduceMotion: Bool
    ) -> [RewardLedgerSample] {
        guard columns > 0, rows > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.21 : phase - floor(phase)
        let availableCoinUnits = max(0, displayedBalanceCoinUnits)
        let balanceSeed = Double(Int(availableCoinUnits.rounded(.down)) % 997) / 997
        let pointCount = columns * rows
        let visibleCoinUnits = min(
            availableCoinUnits,
            Double(pointCount * coinUnitsPerPoint)
        )
        let fullPointCount = min(
            pointCount,
            Int(visibleCoinUnits / Double(coinUnitsPerPoint))
        )
        let partialPointFraction = fullPointCount < pointCount
            ? visibleCoinUnits.truncatingRemainder(dividingBy: Double(coinUnitsPerPoint))
                / Double(coinUnitsPerPoint)
            : 0
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
                let fillIndex = (rows - 1 - row) * columns + column
                let fillFraction: Double
                if fillIndex < fullPointCount {
                    fillFraction = 1
                } else if fillIndex == fullPointCount {
                    fillFraction = partialPointFraction
                } else {
                    fillFraction = 0
                }
                let emptyOpacity = 0.10 + seed * 0.13
                let emptyDiameter = 1.4 + CGFloat(seed) * 0.45

                result.append(
                    RewardLedgerSample(
                        position: CGPoint(
                            x: min(1, max(0, baseX + driftX)),
                            y: min(1, max(0, baseY + driftY))
                        ),
                        opacity: emptyOpacity + (0.92 - emptyOpacity) * fillFraction,
                        diameter: emptyDiameter + (2.25 - emptyDiameter) * CGFloat(fillFraction),
                        row: row,
                        column: column,
                        fillFraction: fillFraction,
                        isFilled: fillFraction == 1
                    )
                )
            }
        }

        return result
    }
}

nonisolated struct RewardGuidanceTrailSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum RewardGuidanceTrailGeometry {
    static func controlPoints(
        start: CGPoint,
        end: CGPoint
    ) -> (first: CGPoint, second: CGPoint) {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lateralBow = min(84, max(48, abs(deltaY) * 0.18))
        return (
            first: CGPoint(
                x: start.x + deltaX * 0.12 - lateralBow,
                y: start.y + max(42, deltaY * 0.28)
            ),
            second: CGPoint(
                x: end.x - deltaX * 0.18 - lateralBow * 0.58,
                y: end.y - max(48, deltaY * 0.20)
            )
        )
    }

    static func samples(
        count: Int,
        phase: Double,
        reduceMotion: Bool,
        start: CGPoint,
        end: CGPoint,
        status: RewardGuidanceStatus
    ) -> [RewardGuidanceTrailSample] {
        guard count > 1 else { return [] }
        let resolvedPhase = reduceMotion ? 0.21 : phase - floor(phase)
        let controls = controlPoints(start: start, end: end)
        let statusOpacity: Double
        switch status {
        case .affordable:
            statusOpacity = 1
        case .progress:
            statusOpacity = 0.48
        }

        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let inverse = 1 - t
            let seed = Double((index * 61 + 23) % 101) / 101
            var position = CGPoint(
                x: inverse * inverse * inverse * start.x
                    + 3 * inverse * inverse * t * controls.first.x
                    + 3 * inverse * t * t * controls.second.x
                    + t * t * t * end.x,
                y: inverse * inverse * inverse * start.y
                    + 3 * inverse * inverse * t * controls.first.y
                    + 3 * inverse * t * t * controls.second.y
                    + t * t * t * end.y
            )
            if index == 0 {
                position = start
            } else if index == count - 1 {
                position = end
            } else if !reduceMotion {
                let taper = sin(t * .pi)
                position.x += sin((resolvedPhase + seed) * .pi * 2 + t * 11)
                    * taper * 2.2
                position.y += cos((resolvedPhase * 0.82 + seed) * .pi * 2 + t * 7)
                    * taper * 1.4
            }
            let flow = reduceMotion
                ? 0.86
                : 0.78 + 0.22 * sin((resolvedPhase + t * 0.72) * .pi * 2)

            return RewardGuidanceTrailSample(
                position: position,
                opacity: (0.24 + t * 0.42 + seed * 0.08) * flow * statusOpacity,
                diameter: 1.5 + CGFloat(t) * 1.5 + CGFloat(seed) * 0.45
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
