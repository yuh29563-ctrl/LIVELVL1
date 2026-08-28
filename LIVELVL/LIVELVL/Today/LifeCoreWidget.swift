import SwiftUI

enum LifeCoreArtworkStyle: Equatable, Sendable {
    case pointCloudOrb
}

enum TodaySurfaceContract {
    static let showsAssessmentControl = false
    static let showsTaskSectionTitle = false
}

struct LifeCoreWidgetPresentation: Equatable, Sendable {
    static let showsMediaControlsOnMainSurface = false
    static let allowsOpeningLegacyDetail = false
    static let artworkStyle: LifeCoreArtworkStyle = .pointCloudOrb

    let definition: CollectibleDefinition
    let stage: CompanionStage
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int

    var companionName: String { definition.name }
    var stageTitle: String { stage.todayTitle }
    var cornerRadius: CGFloat { LivingOSMetrics.coreCornerRadius }
    var progress: Double {
        guard requiredXP > 0 else { return 0 }
        return min(1, max(0, Double(currentXP) / Double(requiredXP)))
    }
    var levelText: String { "LV \(level)" }
    var xpText: String { "\(max(0, currentXP)) / \(max(0, requiredXP)) XP" }
    var remainingText: String { "下一形态 \(max(0, remainingXP)) XP" }
    var accessibilityLabel: String {
        "正在陪伴，\(companionName)，\(stageTitle)，等级 \(level)"
    }
    var accessibilityValue: String {
        "当前 \(max(0, currentXP))，共需 \(max(0, requiredXP))，还差 \(max(0, remainingXP)) XP"
    }
}

nonisolated enum LifeCoreParticleGeometry {
    static func samples(
        columns: Int,
        rows: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [LivingDotSample] {
        guard columns > 0, rows > 0 else { return [] }

        let resolvedPhase = reduceMotion ? 0.17 : phase - floor(phase)
        var result: [LivingDotSample] = []
        result.reserveCapacity(columns * rows / 2)

        for row in 0..<rows {
            for column in 0..<columns {
                let baseX = columns == 1 ? 0.5 : Double(column) / Double(columns - 1)
                let baseY = rows == 1 ? 0.5 : Double(row) / Double(rows - 1)
                let x = baseX - 0.5
                let y = baseY

                let plumeWidth = 0.035 + 0.16 * bell(y, center: 0.55, spread: 0.32)
                let plume = bell(x, center: 0, spread: plumeWidth)
                    * bell(y, center: 0.53, spread: 0.48)

                let orbX = x / 0.265
                let orbY = (y - 0.60) / 0.19
                let orbRadius = sqrt(orbX * orbX + orbY * orbY)
                let orbBody = bell(orbRadius, center: 0.64, spread: 0.48)
                let orbRing = bell(orbRadius, center: 1.0, spread: 0.12)

                let hash = hashValue(column: column, row: row)
                let density = max(plume * 0.82, max(orbBody * 0.92, orbRing))
                let threshold = 0.11 + hash * 0.43
                guard density > threshold else { continue }

                let angle = resolvedPhase * .pi * 2 + hash * .pi * 2
                let verticalDrift = sin(angle + baseY * 8.0) * 0.0065
                let horizontalDrift = cos(angle * 0.82 + baseY * 11.0) * 0.006
                let px = min(1, max(0, baseX + horizontalDrift * (0.4 + density)))
                let py = min(1, max(0, baseY + verticalDrift * (0.4 + density)))
                let sparkle = 0.72 + 0.28 * sin(angle + hash * 9.0)

                result.append(
                    LivingDotSample(
                        position: CGPoint(x: px, y: py),
                        opacity: min(0.94, 0.16 + density * 0.68 * sparkle),
                        diameter: 0.75 + density * 1.45 + hash * 0.45
                    )
                )
            }
        }

        return result
    }

    private static func bell(_ value: Double, center: Double, spread: Double) -> Double {
        let normalized = (value - center) / max(0.0001, spread)
        return exp(-(normalized * normalized))
    }

    private static func hashValue(column: Int, row: Int) -> Double {
        let value = (column &* 73_856_093) ^ (row &* 19_349_663) ^ 0x5f3759df
        return Double(abs(value % 10_000)) / 10_000
    }
}

struct LifeCoreWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale = 1.0

    let presentation: LifeCoreWidgetPresentation
    let isRewarding: Bool
    let levelUpFeedback: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LifeCoreArtwork()
                .frame(maxWidth: .infinity)
                .frame(height: 146)

            VStack(alignment: .leading, spacing: 7) {
                Text(presentation.levelText)
                    .font(.system(size: 18, weight: .medium))
                    .contentTransition(.numericText())

                Text(presentation.xpText)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.ink)
                    .contentTransition(.numericText())

                GeometryReader { proxy in
                    Capsule()
                        .fill(LivingOSTheme.mist)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LivingOSTheme.ink)
                                .frame(width: proxy.size.width * presentation.progress)
                        }
                }
                .frame(height: 5)

                Text(presentation.remainingText)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 13)
        .frame(maxHeight: .infinity)
        .foregroundStyle(LivingOSTheme.ink)
        .background {
            RoundedRectangle(cornerRadius: presentation.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.82), LivingOSTheme.mist.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: presentation.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: presentation.cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        .scaleEffect(pulseScale)
        .overlay(alignment: .topTrailing) {
            if isRewarding {
                Circle()
                    .fill(LivingOSTheme.signal)
                    .frame(width: 6, height: 6)
                    .padding(13)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .task(id: levelUpFeedback) {
            pulseScale = 1
            guard levelUpFeedback != nil, !reduceMotion else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.64)) {
                pulseScale = 1.04
            }
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                pulseScale = 1
            }
        }
    }
}

struct TodayLifeFieldSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: LifeStateSummary
    let core: LifeCoreWidgetPresentation
    let growthPhase: TodayGrowthPhase
    let levelUpFeedback: Int?

    var body: some View {
        GeometryReader { proxy in
            let coreWidth = resolvedCoreWidth(containerWidth: proxy.size.width)

            ZStack {
                LifeFieldView(
                    summary: summary,
                    highlightedDimension: highlightedDimension
                )

                LifeCoreWidget(
                    presentation: core,
                    isRewarding: growthPhase == .core,
                    levelUpFeedback: levelUpFeedback
                )
                .frame(width: coreWidth, height: coreWidth * 1.94)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 590 : 492)
        .todayGrowthAnchor(.field)
    }

    private var highlightedDimension: LifeDimension? {
        guard case let .dimension(dimension) = growthPhase else { return nil }
        return dimension
    }

    private func resolvedCoreWidth(containerWidth: CGFloat) -> CGFloat {
        guard dynamicTypeSize.isAccessibilitySize else {
            return LivingOSMetrics.coreWidth(containerWidth: containerWidth)
        }
        return min(184, max(156, containerWidth * 0.44))
    }
}

private struct LifeCoreArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion
                ? 0.17
                : timeline.date.timeIntervalSinceReferenceDate / 7.5
            let samples = LifeCoreParticleGeometry.samples(
                columns: 27,
                rows: 43,
                phase: phase,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                for sample in samples {
                    let diameter = sample.diameter
                    let rect = CGRect(
                        x: sample.position.x * size.width - diameter / 2,
                        y: sample.position.y * size.height - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity))
                    )
                }

                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.60)
                let outerDiameter = min(size.width * 0.53, size.height * 0.38)
                let outerRect = CGRect(
                    x: center.x - outerDiameter / 2,
                    y: center.y - outerDiameter / 2,
                    width: outerDiameter,
                    height: outerDiameter
                )
                let innerRect = outerRect.insetBy(dx: outerDiameter * 0.12, dy: outerDiameter * 0.12)

                context.stroke(
                    Path(ellipseIn: outerRect),
                    with: .color(LivingOSTheme.ink.opacity(0.78)),
                    lineWidth: 1.2
                )
                context.fill(
                    Path(ellipseIn: innerRect),
                    with: .color(LivingOSTheme.ink.opacity(0.96))
                )
                context.stroke(
                    Path(ellipseIn: innerRect.insetBy(dx: 2.2, dy: 2.2)),
                    with: .color(Color.white.opacity(0.9)),
                    lineWidth: 2.2
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
