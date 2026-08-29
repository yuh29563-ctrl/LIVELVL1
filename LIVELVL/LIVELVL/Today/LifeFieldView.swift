import SwiftUI

enum LifeFieldLabelPlacement: Equatable, Sendable {
    case above
    case below
}

nonisolated enum LifeFieldLayout {
    static let visualCore = CGPoint(x: 0.50, y: 0.45)
    private static let horizontalRadius = 0.36
    private static let verticalRadius = 0.39

    static func anchor(for dimension: LifeDimension) -> CGPoint {
        switch dimension {
        case .health:
            CGPoint(x: visualCore.x, y: visualCore.y - verticalRadius)
        case .learning:
            CGPoint(
                x: visualCore.x + horizontalRadius,
                y: visualCore.y - verticalRadius / 2
            )
        case .finance:
            CGPoint(
                x: visualCore.x + horizontalRadius,
                y: visualCore.y + verticalRadius / 2
            )
        case .relationships:
            CGPoint(x: visualCore.x, y: visualCore.y + verticalRadius)
        case .career:
            CGPoint(
                x: visualCore.x - horizontalRadius,
                y: visualCore.y + verticalRadius / 2
            )
        case .interests:
            CGPoint(
                x: visualCore.x - horizontalRadius,
                y: visualCore.y - verticalRadius / 2
            )
        }
    }

    static func point(for dimension: LifeDimension, in size: CGSize) -> CGPoint {
        let normalized = anchor(for: dimension)
        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    static func labelPlacement(for dimension: LifeDimension) -> LifeFieldLabelPlacement {
        switch dimension {
        case .health, .learning, .interests: .above
        case .career, .finance, .relationships: .below
        }
    }
}

nonisolated struct LifeFieldParticleLinkSample: Equatable, Sendable {
    let dimension: LifeDimension
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum LifeFieldParticleLinkGeometry {
    static func presentationSamples(
        phase: Double,
        reduceMotion: Bool
    ) -> [LifeFieldParticleLinkSample] {
        samples(
            countPerLink: 88,
            phase: phase,
            reduceMotion: reduceMotion
        )
    }

    static func samples(
        countPerLink: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [LifeFieldParticleLinkSample] {
        guard countPerLink > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.19 : phase - floor(phase)
        let center = LifeFieldLayout.visualCore
        var result: [LifeFieldParticleLinkSample] = []
        result.reserveCapacity(LifeDimension.allCases.count * countPerLink)

        for (dimensionIndex, dimension) in LifeDimension.allCases.enumerated() {
            let target = LifeFieldLayout.anchor(for: dimension)
            let dx = target.x - center.x
            let dy = target.y - center.y
            let length = max(0.0001, hypot(dx, dy))
            let perpendicular = CGPoint(x: -dy / length, y: dx / length)

            for index in 0..<countPerLink {
                let t = countPerLink == 1
                    ? 1.0
                    : Double(index) / Double(countPerLink - 1)
                let seed = Double(((dimensionIndex + 1) * 131 + index * 43) % 101) / 101
                let dance = sin((resolvedPhase + seed) * .pi * 2 + t * 13)
                let taper = sin(t * .pi)
                let lateral = dance * 0.012 * taper
                let longitudinal = cos((resolvedPhase * 0.8 + seed) * .pi * 2)
                    * 0.003 * taper
                let resolvedT = min(1, max(0, t + longitudinal))
                let endpointEmphasis = pow(abs(t * 2 - 1), 1.4)

                result.append(
                    LifeFieldParticleLinkSample(
                        dimension: dimension,
                        position: CGPoint(
                            x: center.x + dx * resolvedT + perpendicular.x * lateral,
                            y: center.y + dy * resolvedT + perpendicular.y * lateral
                        ),
                        opacity: 0.26 + endpointEmphasis * 0.22 + seed * 0.16,
                        diameter: 1 + seed * 1.4
                    )
                )
            }
        }

        return result
    }
}

struct LifeFieldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = LifeFieldSelectionState()

    let summary: LifeStateSummary
    let highlightedDimension: LifeDimension?

    private var nodes: [LifeFieldNodePresentation] {
        LifeFieldNodePresentation.make(summary: summary)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LivingDotField(columns: 34, rows: 45)
                    .opacity(0.72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)

                LifeFieldParticleLinks()

                LifeFieldOutline()
                    .stroke(LivingOSTheme.graphite.opacity(0.15), lineWidth: 0.7)

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    LifeFieldNode(
                        value: node,
                        isSelected: selection.selectedDimension == node.dimension,
                        isRewardTarget: highlightedDimension == node.dimension,
                        reduceMotion: reduceMotion,
                        action: {
                            withAnimation(
                                reduceMotion
                                    ? .easeInOut(duration: 0.2)
                                    : .spring(response: 0.34, dampingFraction: 0.82)
                            ) {
                                selection.toggle(node.dimension)
                            }
                        }
                    )
                    .frame(width: nodeWidth(for: node.dimension), alignment: .center)
                    .position(nodePosition(for: node.dimension, in: size))
                    .zIndex(selection.selectedDimension == node.dimension ? 2 : 1)
                }
            }
        }
        .frame(minHeight: 470, idealHeight: 520, maxHeight: 560)
        .onChange(of: nodes.map(\.dimension)) { _, dimensions in
            selection.reconcile(available: Set(dimensions))
        }
    }

    private func nodePosition(for dimension: LifeDimension, in size: CGSize) -> CGPoint {
        LifeFieldLayout.point(for: dimension, in: size)
    }

    private func nodeWidth(for dimension: LifeDimension) -> CGFloat {
        dimension == .health || dimension == .relationships ? 180 : 104
    }
}

private struct LifeFieldNode: View {
    let value: LifeFieldNodePresentation
    let isSelected: Bool
    let isRewardTarget: Bool
    let reduceMotion: Bool
    let action: () -> Void

    private var signedDelta: String {
        value.delta > 0 ? "+\(value.delta)" : "\(value.delta)"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                nodeDot

                nodeLabel
                    .offset(y: labelOffset)

                if isSelected {
                    VStack(spacing: 2) {
                        Text("NEXT \(value.projectedDisplayValue)  \(signedDelta)")
                            .foregroundStyle(value.delta == 0 ? LivingOSTheme.graphite : LivingOSTheme.ink)
                        Text(value.sourceText)
                        Text(value.assessmentText)
                    }
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: detailOffset)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
                }
            }
            .foregroundStyle(LivingOSTheme.ink)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isRewardTarget && !reduceMotion ? 1.08 : 1)
        .accessibilityLabel(value.title)
        .accessibilityValue(value.accessibilityValue)
        .accessibilityHint(isSelected ? "轻点收起状态" : "轻点查看具体状态")
    }

    private var labelOffset: CGFloat {
        LifeFieldLayout.labelPlacement(for: value.dimension) == .above ? -27 : 31
    }

    private var detailOffset: CGFloat {
        LifeFieldLayout.labelPlacement(for: value.dimension) == .above ? 54 : -54
    }

    private var nodeLabel: some View {
        VStack(spacing: 0) {
            Text(value.title)
                .font(.system(LivingOSTypography.lifeNodeTitle, weight: .medium))
            Text(value.displayValue, format: .number)
                .font(.system(.caption, design: .monospaced, weight: .regular))
                .foregroundStyle(LivingOSTheme.graphite)
        }
    }

    private var nodeDot: some View {
        ZStack {
            Circle()
                .stroke(
                    LivingOSTheme.graphite.opacity(isSelected || isRewardTarget ? 0.42 : 0.14),
                    lineWidth: isRewardTarget ? 1 : 0.7
                )
                .frame(width: 32, height: 32)

            Circle()
                .fill(LivingOSTheme.ink)
                .frame(
                    width: isSelected || isRewardTarget ? 15 : 12,
                    height: isSelected || isRewardTarget ? 15 : 12
                )

            if isSelected || isRewardTarget {
                Circle()
                    .fill(LivingOSTheme.signal)
                    .frame(width: 5, height: 5)
                    .offset(x: 14, y: -13)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct LifeFieldParticleLinks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let phase = reduceMotion
                ? 0.19
                : timeline.date.timeIntervalSinceReferenceDate / 8.0
            let samples = LifeFieldParticleLinkGeometry.presentationSamples(
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

private struct LifeFieldOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            LifeFieldLayout.point(for: .health, in: rect.size),
            LifeFieldLayout.point(for: .learning, in: rect.size),
            LifeFieldLayout.point(for: .finance, in: rect.size),
            LifeFieldLayout.point(for: .relationships, in: rect.size),
            LifeFieldLayout.point(for: .career, in: rect.size),
            LifeFieldLayout.point(for: .interests, in: rect.size)
        ]

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }
}
