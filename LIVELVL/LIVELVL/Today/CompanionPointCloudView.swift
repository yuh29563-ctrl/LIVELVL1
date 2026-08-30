import SwiftUI

nonisolated enum CompanionPointCloudMode: Equatable, Sendable {
    case expanded
    case collapsed

    var maximumPointCount: Int {
        switch self {
        case .expanded: 640
        case .collapsed: 360
        }
    }

    func visualDimension(isAccessibilitySize: Bool) -> CGFloat? {
        guard self == .collapsed else {
            return nil
        }
        return isAccessibilitySize ? 120 : 108
    }
}

nonisolated struct CompanionPointCloudSample: Equatable, Sendable {
    let position: CGPoint
    let offset: CGSize
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum CompanionPointCloudMotion {
    static let breathingDuration: TimeInterval = 8

    private static let maximumDrift: CGFloat = 1.8
    private static let ghostStartProgress = 0.72
    private static let maximumGhostOpacity = 0.18
    private static let rewardPeakTime: TimeInterval = 0.18
    private static let rewardEndTime: TimeInterval = 0.55

    static func samples(
        descriptor: CompanionPointCloudDescriptor,
        mode: CompanionPointCloudMode,
        phase: Double,
        reduceMotion: Bool
    ) -> [CompanionPointCloudSample] {
        let motionPhase = resolvedPhase(phase, reduceMotion: reduceMotion)
        return descriptor.points.prefix(mode.maximumPointCount).map { point in
            CompanionPointCloudSample(
                position: point.position,
                offset: driftOffset(
                    seed: point.seed,
                    phase: motionPhase,
                    reduceMotion: reduceMotion
                ),
                opacity: min(0.96, 0.22 + point.inkWeight * 0.7),
                diameter: pointDiameter(inkWeight: point.inkWeight, mode: mode)
            )
        }
    }

    static func resolvedPhase(_ phase: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0.19 : phase - floor(phase)
    }

    static func breathingScale(phase: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion else {
            return 1
        }
        return 1 + sin(resolvedPhase(phase, reduceMotion: false) * .pi * 2) * 0.015
    }

    static func ghostOpacity(progress: Double, hasNext: Bool) -> Double {
        guard hasNext else {
            return 0
        }
        let clampedProgress = min(1, max(0, progress))
        guard clampedProgress > ghostStartProgress else {
            return 0
        }
        let ramp = (clampedProgress - ghostStartProgress) / (1 - ghostStartProgress)
        return ramp * maximumGhostOpacity
    }

    static func rewardPulseScale(elapsed: TimeInterval, reduceMotion: Bool) -> Double {
        guard !reduceMotion, elapsed > 0, elapsed < rewardEndTime else {
            return 1
        }
        if elapsed <= rewardPeakTime {
            return 1 + 0.035 * elapsed / rewardPeakTime
        }
        let returnProgress = (elapsed - rewardPeakTime) / (rewardEndTime - rewardPeakTime)
        return 1.035 - 0.035 * returnProgress
    }

    private static func driftOffset(
        seed: UInt64,
        phase: Double,
        reduceMotion: Bool
    ) -> CGSize {
        guard !reduceMotion else {
            return .zero
        }

        let direction = seed & 1 == 0 ? 1.0 : -1.0
        let originAngle = unitValue(seed: seed, shift: 8) * .pi * 2
        let angle = originAngle + direction * phase * .pi * 2
        let radius = maximumDrift * (0.35 + unitValue(seed: seed, shift: 24) * 0.65)
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }

    private static func pointDiameter(
        inkWeight: Double,
        mode: CompanionPointCloudMode
    ) -> CGFloat {
        let modeScale = mode == .collapsed ? 0.86 : 1.0
        return (0.8 + min(1, max(0, inkWeight)) * 1.5) * modeScale
    }

    private static func unitValue(seed: UInt64, shift: UInt64) -> Double {
        Double((seed >> shift) & 0xffff) / Double(UInt16.max)
    }
}

struct CompanionPointCloudView<RewardToken: Equatable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var rewardPulseStartedAt: Date?

    let loadState: CompanionPointCloudLoader.State
    let mode: CompanionPointCloudMode
    let progress: Double
    let rewardToken: RewardToken

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            if case let .loaded(pair) = loadState {
                let phase = reduceMotion
                    ? 0.19
                    : timeline.date.timeIntervalSinceReferenceDate
                        / CompanionPointCloudMotion.breathingDuration
                let scale = max(
                    CompanionPointCloudMotion.breathingScale(
                        phase: phase,
                        reduceMotion: reduceMotion
                    ),
                    CompanionPointCloudMotion.rewardPulseScale(
                        elapsed: rewardElapsed(at: timeline.date),
                        reduceMotion: reduceMotion
                    )
                )

                pointCloudCanvas(pair: pair, phase: phase)
                    .scaleEffect(scale)
            }
        }
        .frame(
            width: mode.visualDimension(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize),
            height: mode.visualDimension(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        )
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: rewardToken) {
            rewardPulseStartedAt = reduceMotion ? nil : .now
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pointCloudCanvas(
        pair: CompanionPointCloudPair,
        phase: Double
    ) -> some View {
        let currentSamples = CompanionPointCloudMotion.samples(
            descriptor: pair.current,
            mode: mode,
            phase: phase,
            reduceMotion: reduceMotion
        )
        let nextSamples = pair.next.map {
            CompanionPointCloudMotion.samples(
                descriptor: $0,
                mode: mode,
                phase: phase,
                reduceMotion: reduceMotion
            )
        } ?? []
        let ghostOpacity = CompanionPointCloudMotion.ghostOpacity(
            progress: progress,
            hasNext: pair.next != nil
        )

        return Canvas { context, size in
            draw(
                samples: nextSamples,
                opacity: ghostOpacity,
                color: LivingOSTheme.graphite,
                in: &context,
                size: size
            )
            draw(
                samples: currentSamples,
                opacity: 1,
                color: LivingOSTheme.ink,
                in: &context,
                size: size
            )
        }
    }

    private func draw(
        samples: [CompanionPointCloudSample],
        opacity: Double,
        color: Color,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard opacity > 0 else {
            return
        }
        for sample in samples {
            let rect = CGRect(
                x: sample.position.x * size.width + sample.offset.width - sample.diameter / 2,
                y: sample.position.y * size.height + sample.offset.height - sample.diameter / 2,
                width: sample.diameter,
                height: sample.diameter
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(sample.opacity * opacity))
            )
        }
    }

    private func rewardElapsed(at date: Date) -> TimeInterval {
        guard let rewardPulseStartedAt else {
            return .infinity
        }
        return date.timeIntervalSince(rewardPulseStartedAt)
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }
}
