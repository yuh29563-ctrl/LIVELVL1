import CoreGraphics

nonisolated struct ArchiveCardTransform: Equatable, Sendable {
    let scale: CGFloat
    let opacity: Double
    let rotationDegrees: Double

    static func make(
        normalizedDistance: CGFloat,
        reduceMotion: Bool
    ) -> Self {
        let signedDistance = max(-1, min(1, normalizedDistance))
        let distance = abs(signedDistance)
        return Self(
            scale: 1 - 0.12 * distance,
            opacity: 1 - 0.45 * Double(distance),
            rotationDegrees: reduceMotion ? 0 : Double(signedDistance) * -3
        )
    }
}

nonisolated struct ArchiveCarouselState: Equatable, Sendable {
    private(set) var centeredAwardKey: String?
    private(set) var expandedAwardKey: String?
    private(set) var isShowingBack = false

    mutating func reconcile(orderedAwardKeys: [String]) {
        if let centeredAwardKey {
            if !orderedAwardKeys.contains(centeredAwardKey) {
                self.centeredAwardKey = orderedAwardKeys.first
            }
        } else {
            centeredAwardKey = orderedAwardKeys.first
        }

        if let expandedAwardKey,
           !orderedAwardKeys.contains(expandedAwardKey) {
            self.expandedAwardKey = nil
            isShowingBack = false
        }
    }

    mutating func center(_ awardKey: String?) {
        centeredAwardKey = awardKey
    }

    mutating func updateScrollPosition(
        _ awardKey: String?,
        orderedAwardKeys: [String]
    ) {
        if let awardKey, orderedAwardKeys.contains(awardKey) {
            centeredAwardKey = awardKey
        } else if orderedAwardKeys.isEmpty {
            centeredAwardKey = nil
        }
    }

    mutating func expandCentered() {
        expandedAwardKey = centeredAwardKey
        isShowingBack = false
    }

    mutating func setShowingBack(_ value: Bool) {
        guard expandedAwardKey != nil else {
            isShowingBack = false
            return
        }
        isShowingBack = value
    }

    mutating func closeExpanded() {
        expandedAwardKey = nil
        isShowingBack = false
    }
}
