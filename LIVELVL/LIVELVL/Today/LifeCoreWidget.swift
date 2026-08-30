import SwiftUI

enum LifeCoreArtworkStyle: Equatable, Sendable {
    case pointCloudOrb
}

enum TodaySurfaceContract {
    static let showsAssessmentControl = false
    static let showsTaskSectionTitle = false
}

nonisolated enum LifeCoreDisplayMode: Equatable, Sendable {
    case expanded
    case compact

    static let initial = LifeCoreDisplayMode.expanded

    var toggleSymbolName: String {
        switch self {
        case .expanded: "chevron.up"
        case .compact: "chevron.down"
        }
    }

    mutating func toggle() {
        self = self == .expanded ? .compact : .expanded
    }
}

nonisolated enum LifeCoreCollapseLayout {
    static let minimumTapDimension: CGFloat = 44
}

extension CompanionStage {
    nonisolated var nextArtworkStage: CompanionStage? {
        switch self {
        case .juvenile: .stageTwo
        case .stageTwo: .stageThree
        case .stageThree: .mature
        case .mature: nil
        }
    }
}

nonisolated struct LifeCoreDockMetrics: Equatable, Sendable {
    let dockHeight: CGFloat
    let spacing: CGFloat
    let fieldOriginY: CGFloat
    let fieldHeight: CGFloat
    let sectionHeight: CGFloat

    var dockRange: Range<CGFloat> { 0..<dockHeight }
    var fieldRange: Range<CGFloat> { fieldOriginY..<(fieldOriginY + fieldHeight) }
}

nonisolated enum LifeCoreDockLayout {
    private static let regularFieldHeight: CGFloat = 492
    private static let accessibilityFieldHeight: CGFloat = 590
    private static let regularDockHeight: CGFloat = 44
    private static let accessibilityDockHeight: CGFloat = 64
    private static let regularDockSpacing: CGFloat = 28
    private static let accessibilityDockSpacing: CGFloat = 36

    static func metrics(
        displayMode: LifeCoreDisplayMode,
        isAccessibilitySize: Bool
    ) -> LifeCoreDockMetrics {
        let fieldHeight = isAccessibilitySize
            ? accessibilityFieldHeight
            : regularFieldHeight
        let dockHeight = displayMode == .compact
            ? (isAccessibilitySize ? accessibilityDockHeight : regularDockHeight)
            : 0
        let spacing = displayMode == .compact
            ? (isAccessibilitySize ? accessibilityDockSpacing : regularDockSpacing)
            : 0
        let fieldOriginY = dockHeight + spacing

        return LifeCoreDockMetrics(
            dockHeight: dockHeight,
            spacing: spacing,
            fieldOriginY: fieldOriginY,
            fieldHeight: fieldHeight,
            sectionHeight: fieldOriginY + fieldHeight
        )
    }
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
    var artworkRequest: CompanionPointCloudRequest {
        CompanionPointCloudRequest(
            current: CompanionArtworkID(collectibleID: definition.id, stage: stage),
            next: stage.nextArtworkStage.map {
                CompanionArtworkID(collectibleID: definition.id, stage: $0)
            }
        )
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
    var compactAccessibilityLabel: String {
        "成长卡已折叠，\(accessibilityLabel)"
    }
    var compactAccessibilityHint: String { "轻点展开成长卡" }
    var compactAccessibilityIdentifier: String { "today-life-core-expand" }
    var compactTitleText: String { "\(companionName) · \(levelText)" }
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
    let artworkState: CompanionPointCloudLoader.State
    let isRewarding: Bool
    let levelUpFeedback: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if artworkState == .fallback {
                    LifeCoreArtwork()
                } else {
                    CompanionPointCloudView(
                        loadState: artworkState,
                        mode: .expanded,
                        progress: presentation.progress,
                        rewardToken: levelUpFeedback
                    )
                }
            }
                .frame(maxWidth: .infinity)
                .frame(height: 146)

            VStack(alignment: .leading, spacing: 7) {
                Text(presentation.levelText)
                    .font(.system(LivingOSTypography.lifeCoreLevel, weight: .medium))
                    .contentTransition(.numericText())

                Text(presentation.xpText)
                    .font(.system(.caption2, design: .monospaced, weight: .regular))
                    .foregroundStyle(LivingOSTheme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

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
                    .font(.system(.caption2, design: .monospaced, weight: .regular))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var coreDisplayMode = LifeCoreDisplayMode.initial
    @StateObject private var pointCloudLoader = makeCompanionPointCloudLoader()

    let summary: LifeStateSummary
    let core: LifeCoreWidgetPresentation
    let growthPhase: TodayGrowthPhase
    let levelUpFeedback: Int?

    var body: some View {
        let layout = LifeCoreDockLayout.metrics(
            displayMode: coreDisplayMode,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )

        GeometryReader { proxy in
            let coreWidth = resolvedCoreWidth(containerWidth: proxy.size.width)
            let coreHeight = coreWidth * 1.94

            VStack(spacing: layout.spacing) {
                if coreDisplayMode == .compact {
                    LifeCoreCompactWidget(
                        presentation: core,
                        isRewarding: growthPhase == .core,
                        isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                        action: toggleCoreDisplayMode
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.dockHeight)
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                    .transition(dockTransition)
                    .zIndex(LifeFieldLayerOrder.coreControl)
                }

                ZStack {
                    LifeFieldBackdrop(summary: summary)
                        .zIndex(LifeFieldLayerOrder.backdrop)

                    if coreDisplayMode == .expanded {
                        LifeCoreWidget(
                            presentation: core,
                            artworkState: pointCloudLoader.state,
                            isRewarding: growthPhase == .core,
                            levelUpFeedback: levelUpFeedback
                        )
                        .frame(width: coreWidth, height: coreHeight)
                        .transition(coreTransition)
                        .zIndex(LifeFieldLayerOrder.core)

                        LifeCoreCollapseButton(action: toggleCoreDisplayMode)
                            .offset(
                                x: coreWidth / 2 - LifeCoreCollapseLayout.minimumTapDimension / 2,
                                y: -coreHeight / 2 + LifeCoreCollapseLayout.minimumTapDimension / 2
                            )
                            .transition(.opacity)
                            .zIndex(LifeFieldLayerOrder.coreControl)
                    }

                    LifeFieldView(
                        summary: summary,
                        highlightedDimension: highlightedDimension
                    )
                    .zIndex(LifeFieldLayerOrder.controls)
                }
                .frame(height: layout.fieldHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(sectionAnimation, value: coreDisplayMode)
            .dynamicTypeSize(.large ... .accessibility2)
        }
        .frame(height: layout.sectionHeight, alignment: .top)
        .todayGrowthAnchor(.field)
        .task(id: core.artworkRequest) {
            pointCloudLoader.load(core.artworkRequest)
        }
    }

    private var highlightedDimension: LifeDimension? {
        guard case let .dimension(dimension) = growthPhase else { return nil }
        return dimension
    }

    private var coreTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.88))
    }

    private var dockTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.96, anchor: .top))
    }

    private var sectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.34, dampingFraction: 0.84)
    }

    private func toggleCoreDisplayMode() {
        withAnimation(sectionAnimation) {
            coreDisplayMode.toggle()
        }
    }

    private func resolvedCoreWidth(containerWidth: CGFloat) -> CGFloat {
        guard dynamicTypeSize.isAccessibilitySize else {
            return LivingOSMetrics.coreWidth(containerWidth: containerWidth)
        }
        return min(184, max(156, containerWidth * 0.44))
    }
}

@MainActor
private func makeCompanionPointCloudLoader() -> CompanionPointCloudLoader {
    let provider: any CompanionArtworkDataProviding
    do {
        provider = try BundledCompanionArtworkProvider()
    } catch {
        provider = UnavailableCompanionArtworkProvider()
    }
    return CompanionPointCloudLoader(
        repository: CompanionPointCloudRepository(provider: provider)
    )
}

private nonisolated struct UnavailableCompanionArtworkProvider: CompanionArtworkDataProviding {
    func payload(for id: CompanionArtworkID) async throws -> CompanionArtworkPayload? {
        nil
    }
}

private struct LifeCoreCollapseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: LifeCoreDisplayMode.expanded.toggleSymbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(
                    width: LifeCoreCollapseLayout.minimumTapDimension,
                    height: LifeCoreCollapseLayout.minimumTapDimension
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(LivingOSTheme.graphite)
        .accessibilityLabel("折叠成长卡")
        .accessibilityHint("轻点显示迷你成长状态")
        .accessibilityIdentifier("today-life-core-collapse")
    }
}

private struct LifeCoreCompactWidget: View {
    let presentation: LifeCoreWidgetPresentation
    let isRewarding: Bool
    let isAccessibilitySize: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: isAccessibilitySize ? 4 : 3) {
                    Text(presentation.compactTitleText)
                        .font(
                            isAccessibilitySize
                                ? .subheadline.monospaced().weight(.semibold)
                                : .caption.monospaced().weight(.semibold)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 6) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(LivingOSTheme.mist)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(LivingOSTheme.ink)
                                        .frame(width: proxy.size.width * presentation.progress)
                                }
                        }
                        .frame(height: 4)

                        xpLabel
                    }
                }

                if isRewarding {
                    Circle()
                        .fill(LivingOSTheme.signal)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }

                Image(systemName: LifeCoreDisplayMode.compact.toggleSymbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(LivingOSTheme.ink)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.96), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
        }
        .accessibilityLabel(presentation.compactAccessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.compactAccessibilityHint)
        .accessibilityIdentifier(presentation.compactAccessibilityIdentifier)
        .dynamicTypeSize(.large ... .accessibility1)
    }

    private var xpLabel: some View {
        Text(presentation.xpText)
            .font(.caption2.monospaced())
            .foregroundStyle(LivingOSTheme.graphite)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LifeCoreArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
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
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }
}
