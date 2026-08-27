import CoreGraphics
import Foundation

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
