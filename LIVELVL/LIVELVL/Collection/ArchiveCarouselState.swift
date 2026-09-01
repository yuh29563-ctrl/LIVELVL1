import CoreGraphics
import Foundation

nonisolated struct ArchiveCardTransform: Equatable, Sendable {
    let scale: CGFloat
    let opacity: Double
    let yawDegrees: Double
    let rollDegrees: Double
    let verticalOffset: CGFloat

    static func make(
        normalizedDistance: CGFloat,
        reduceMotion: Bool
    ) -> Self {
        guard !reduceMotion else {
            return Self(
                scale: 1,
                opacity: 1,
                yawDegrees: 0,
                rollDegrees: 0,
                verticalOffset: 0
            )
        }
        let signedDistance = max(-1, min(1, normalizedDistance))
        let distance = abs(signedDistance)
        let direction: Double = signedDistance < 0 ? -1 : (signedDistance > 0 ? 1 : 0)
        let depthProgress = pow(distance, 0.82)
        let turnProgress = sin(distance * .pi / 2)
        let travelHeight = 22 * pow(distance, 1.5)
            - 6.5 * sin(distance * .pi)
        return Self(
            scale: 1 - 0.18 * depthProgress,
            opacity: 1 - 0.3 * Double(depthProgress),
            yawDegrees: direction * -28 * Double(turnProgress),
            rollDegrees: direction * -3 * Double(turnProgress),
            verticalOffset: travelHeight
        )
    }
}

nonisolated enum ArchiveArrivalPresentationActivity {
    static func shouldAdvance(
        isCollectionSelected: Bool,
        isObscured: Bool,
        isSceneActive: Bool
    ) -> Bool {
        isCollectionSelected && !isObscured && isSceneActive
    }
}

nonisolated enum ArchiveArrivalMotion {
    static func allowsAnimatedCentering(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

nonisolated struct ArchiveAccessibilityNavigationDestination: Equatable, Sendable {
    let awardKey: String
    let focusTarget: CollectionCardFocusTarget
}

nonisolated enum ArchiveAccessibilityNavigation {
    static func destination(
        awardKeys: [String],
        from index: Int,
        increment: Bool
    ) -> ArchiveAccessibilityNavigationDestination? {
        guard awardKeys.indices.contains(index), !awardKeys.isEmpty else { return nil }
        let targetIndex = increment
            ? min(awardKeys.count - 1, index + 1)
            : max(0, index - 1)
        let awardKey = awardKeys[targetIndex]
        return ArchiveAccessibilityNavigationDestination(
            awardKey: awardKey,
            focusTarget: .grid(awardKey: awardKey)
        )
    }
}

nonisolated struct ArchiveCarouselLayout: Equatable, Sendable {
    let cardSize: CGSize
    let cardSpacing: CGFloat
    let captionHeight: CGFloat
    let cardCaptionSpacing: CGFloat
    let totalHeight: CGFloat

    static func resolvedCaptionHeight(isAccessibilitySize: Bool) -> CGFloat {
        isAccessibilitySize ? 194 : 150
    }

    static func usesVerticalPageScroll(isAccessibilitySize: Bool) -> Bool {
        isAccessibilitySize
    }

    static func make(containerWidth: CGFloat) -> Self {
        let width = min(196, max(192, containerWidth * 12 / 23))
        let height = width * 1.75
        let captionHeight: CGFloat = 150
        let spacing: CGFloat = 16
        return Self(
            cardSize: CGSize(width: width, height: height),
            cardSpacing: -8,
            captionHeight: captionHeight,
            cardCaptionSpacing: spacing,
            totalHeight: height + spacing + captionHeight
        )
    }
}

nonisolated struct ArchiveCardCaptionPresentation: Equatable, Sendable {
    let title: String
    let kindTitle: String
    let sourceTitle: String
    let levelText: String
    let acquiredText: String

    init(
        name: String,
        kindTitle: String,
        sourceTitle: String,
        awardKey: String,
        acquiredAt: Date,
        calendar: Calendar
    ) {
        title = name.uppercased()
        self.kindTitle = kindTitle
        self.sourceTitle = sourceTitle
        if awardKey.hasPrefix("ordinary.level."),
           let level = Int(awardKey.split(separator: ".").last ?? "") {
            levelText = "LV \(level)"
        } else {
            levelText = "DISCOVERY"
        }
        let components = calendar.dateComponents([.month, .day], from: acquiredAt)
        acquiredText = String(
            format: "获得于 %02d / %02d",
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

nonisolated enum ArchiveExpandedLayout {
    static func cardFrame(in containerSize: CGSize) -> CGRect {
        let width = max(180, min(236, containerSize.width - 80))
        let height = max(280, min(470, containerSize.height - 150))
        let top = min(132, max(24, containerSize.height - height - 24))
        return CGRect(
            x: (containerSize.width - width) / 2,
            y: top,
            width: width,
            height: height
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

nonisolated struct ArchiveArrivalPresentationState: Equatable, Sendable {
    private var pendingAwardKeys: [String] = []
    private var completedAwardKeys: Set<String> = []

    mutating func registerClaimed(awardKey: String) {
        guard !completedAwardKeys.contains(awardKey),
              !pendingAwardKeys.contains(awardKey) else { return }
        pendingAwardKeys.append(awardKey)
    }

    mutating func takeArrivalIfNeeded(validAwardKeys: Set<String>) -> String? {
        pendingAwardKeys.first {
            validAwardKeys.contains($0) && !completedAwardKeys.contains($0)
        }
    }

    mutating func markCompleted(awardKey: String) {
        completedAwardKeys.insert(awardKey)
        pendingAwardKeys.removeAll { $0 == awardKey }
    }
}

nonisolated struct ArchiveArrivalTraceSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum ArchiveArrivalTraceGeometry {
    static func samples(
        progress: Double,
        phase: Double,
        reduceMotion: Bool
    ) -> [ArchiveArrivalTraceSample] {
        guard !reduceMotion else { return [] }
        let resolvedProgress = min(1, max(0, progress))
        guard resolvedProgress > 0 else { return [] }

        let count = 48
        let visibleCount = min(count, max(1, Int(ceil(Double(count) * resolvedProgress))))
        let resolvedPhase = phase - floor(phase)

        return (0..<visibleCount).map { index in
            let t = count == 1 ? 1 : Double(index) / Double(count - 1)
            let seed = Double((index * 47 + 19) % 101) / 101
            let taper = sin(t * .pi)
            let dance = sin((resolvedPhase + seed) * .pi * 2 + t * 12)
            let curve = sin(t * .pi) * 0.024
            let lateral = dance * taper * 0.008
            let y = 1.04 - (0.37 * t)

            return ArchiveArrivalTraceSample(
                position: CGPoint(x: 0.5 + curve + lateral, y: y),
                opacity: 0.18 + 0.62 * t + seed * 0.12,
                diameter: 0.8 + seed * 1.4
            )
        }
    }
}
