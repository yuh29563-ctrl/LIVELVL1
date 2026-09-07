import SwiftUI

enum LifeFieldLabelPlacement: Equatable, Sendable {
    case above
    case below
}

nonisolated struct LifeFieldNodeAnchors: Equatable, Sendable {
    let official: CGPoint
    let projected: CGPoint
}

nonisolated enum LifeFieldLayerOrder {
    static let backdropDots = 0.0
    static let companionCore = 1.0
    static let radialLinks = 1.5
    static let dynamicEdges = 2.0
    static let controls = 3.0
    static let expandedCore = 3.5
    static let coreControl = 4.0
}

nonisolated enum LifeFieldLayout {
    static let visualCore = CGPoint(x: 0.50, y: 0.45)
    private static let verticalRadius = 0.39
    private static let horizontalRadius = verticalRadius * CGFloat(3).squareRoot() / 2

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

    static func anchor(for dimension: LifeDimension, score: Int) -> CGPoint {
        let outer = anchor(for: dimension)
        let progress = CGFloat(min(100, max(0, score))) / 100
        return CGPoint(
            x: visualCore.x + (outer.x - visualCore.x) * progress,
            y: visualCore.y + (outer.y - visualCore.y) * progress
        )
    }

    static func anchors(for node: LifeFieldNodePresentation) -> LifeFieldNodeAnchors {
        LifeFieldNodeAnchors(
            official: anchor(for: node.dimension, score: node.displayValue),
            projected: anchor(for: node.dimension, score: node.projectedDisplayValue)
        )
    }

    static func point(for dimension: LifeDimension, in size: CGSize) -> CGPoint {
        let normalized = anchor(for: dimension)
        return point(for: normalized, in: size)
    }

    static func point(for normalized: CGPoint, in size: CGSize) -> CGPoint {
        let scale = min(size.width, size.height)
        let center = CGPoint(
            x: visualCore.x * size.width,
            y: visualCore.y * size.height
        )
        return CGPoint(
            x: center.x + (normalized.x - visualCore.x) * scale,
            y: center.y + (normalized.y - visualCore.y) * scale
        )
    }

    static func labelPlacement(for dimension: LifeDimension) -> LifeFieldLabelPlacement {
        switch dimension {
        case .health, .learning, .interests: .above
        case .career, .finance, .relationships: .below
        }
    }
}

nonisolated struct LifeFieldEdge: Equatable, Hashable, Sendable {
    let start: LifeDimension
    let end: LifeDimension

    static let ordered: [LifeFieldEdge] = [
        LifeFieldEdge(start: .health, end: .learning),
        LifeFieldEdge(start: .learning, end: .finance),
        LifeFieldEdge(start: .finance, end: .relationships),
        LifeFieldEdge(start: .relationships, end: .career),
        LifeFieldEdge(start: .career, end: .interests),
        LifeFieldEdge(start: .interests, end: .health),
    ]
}

nonisolated struct LifeFieldEdgeSegment: Equatable, Sendable {
    let edge: LifeFieldEdge
    let start: CGPoint
    let end: CGPoint
}

nonisolated struct LifeFieldEdgeParticleSample: Equatable, Sendable {
    let edge: LifeFieldEdge
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum LifeFieldEdgeParticleGeometry {
    static func segments(
        targets: [LifeDimension: CGPoint]
    ) -> [LifeFieldEdgeSegment] {
        LifeFieldEdge.ordered.map { edge in
            LifeFieldEdgeSegment(
                edge: edge,
                start: targets[edge.start] ?? LifeFieldLayout.anchor(for: edge.start),
                end: targets[edge.end] ?? LifeFieldLayout.anchor(for: edge.end)
            )
        }
    }

    static func presentationSamples(
        phase: Double,
        reduceMotion: Bool,
        targets: [LifeDimension: CGPoint]
    ) -> [LifeFieldEdgeParticleSample] {
        samples(
            countPerEdge: 22,
            phase: phase,
            reduceMotion: reduceMotion,
            targets: targets
        )
    }

    static func samples(
        countPerEdge: Int,
        phase: Double,
        reduceMotion: Bool,
        targets: [LifeDimension: CGPoint]
    ) -> [LifeFieldEdgeParticleSample] {
        guard countPerEdge > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.19 : phase
        let edgeSegments = segments(targets: targets)
        var result: [LifeFieldEdgeParticleSample] = []
        result.reserveCapacity(edgeSegments.count * countPerEdge)

        for (edgeIndex, segment) in edgeSegments.enumerated() {
            let dx = segment.end.x - segment.start.x
            let dy = segment.end.y - segment.start.y
            let length = max(0.0001, hypot(dx, dy))
            let perpendicular = CGPoint(x: -dy / length, y: dx / length)

            for index in 0..<countPerEdge {
                let base = Double(index) / Double(countPerEdge)
                let seed = Double(((edgeIndex + 1) * 97 + index * 41) % 101) / 101
                let progress = (base + resolvedPhase * 0.18 + seed * 0.025)
                    .truncatingRemainder(dividingBy: 1)
                let dance = sin((resolvedPhase + seed) * .pi * 2 + progress * 11)
                let lateral = dance * 0.0035
                let x = segment.start.x + dx * progress + perpendicular.x * lateral
                let y = segment.start.y + dy * progress + perpendicular.y * lateral

                result.append(
                    LifeFieldEdgeParticleSample(
                        edge: segment.edge,
                        position: CGPoint(
                            x: min(1, max(0, x)),
                            y: min(1, max(0, y))
                        ),
                        opacity: 0.22 + seed * 0.32,
                        diameter: 0.9 + seed * 1.1
                    )
                )
            }
        }

        return result
    }
}

nonisolated struct LifeFieldParticleLinkSample: Equatable, Sendable {
    let dimension: LifeDimension
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum LifeFieldRadialLinkPresentation {
    private static let opacityMultiplier = 0.36

    static var targets: [LifeDimension: CGPoint] {
        Dictionary(
            uniqueKeysWithValues: LifeDimension.allCases.map {
                ($0, LifeFieldLayout.anchor(for: $0))
            }
        )
    }

    static func renderedOpacity(for sampleOpacity: Double) -> Double {
        min(1, max(0, sampleOpacity * opacityMultiplier))
    }
}

nonisolated enum LifeFieldPolygonTone: Equatable {
    case strong
    case subtle
}

nonisolated enum LifeFieldPolygonPresentation {
    static let outerTone: LifeFieldPolygonTone = .subtle
    static let innerTone: LifeFieldPolygonTone = .strong
    static let outerOpacity = 0.18
    static let innerOpacity = 0.28
}

nonisolated enum LifeFieldParticleLinkGeometry {
    static func presentationSamples(
        phase: Double,
        reduceMotion: Bool,
        targets: [LifeDimension: CGPoint]? = nil
    ) -> [LifeFieldParticleLinkSample] {
        samples(
            countPerLink: 88,
            phase: phase,
            reduceMotion: reduceMotion,
            targets: targets
        )
    }

    static func samples(
        countPerLink: Int,
        phase: Double,
        reduceMotion: Bool,
        targets: [LifeDimension: CGPoint]? = nil
    ) -> [LifeFieldParticleLinkSample] {
        guard countPerLink > 0 else { return [] }
        let resolvedPhase = reduceMotion ? 0.19 : phase - floor(phase)
        let center = LifeFieldLayout.visualCore
        var result: [LifeFieldParticleLinkSample] = []
        result.reserveCapacity(LifeDimension.allCases.count * countPerLink)

        for (dimensionIndex, dimension) in LifeDimension.allCases.enumerated() {
            let target = targets?[dimension] ?? LifeFieldLayout.anchor(for: dimension)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection = LifeFieldSelectionState()
    @State private var presentedDetail: LifeFieldNodePresentation?

    let summary: LifeStateSummary
    let highlightedDimension: LifeDimension?

    private var nodes: [LifeFieldNodePresentation] {
        LifeFieldNodePresentation.make(summary: summary)
    }

    private var detailPresentationStyle: LifeFieldDetailPresentationStyle {
        LifeFieldDetailPresentation.style(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(nodes) { node in
                    let anchors = LifeFieldLayout.anchors(for: node)
                    let isSelected = selection.selectedDimension == node.dimension
                    let isRewardTarget = highlightedDimension == node.dimension

                    if node.delta != 0 {
                        LifeFieldProjectedMarker(
                            isRewardTarget: isRewardTarget,
                            reduceMotion: reduceMotion
                        )
                        .position(LifeFieldLayout.point(for: anchors.projected, in: size))
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                            value: node.projectedDisplayValue
                        )
                    }

                    LifeFieldOfficialNode(
                        isSelected: isSelected,
                        action: { activate(node) }
                    )
                    .position(LifeFieldLayout.point(for: anchors.official, in: size))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                        value: node.displayValue
                    )

                    LifeFieldNodeLabel(
                        value: node,
                        isSelected: isSelected,
                        isRewardTarget: isRewardTarget,
                        showsInlineDetail: detailPresentationStyle == .inline,
                        reduceMotion: reduceMotion,
                        action: { activate(node) }
                    )
                    .frame(width: nodeWidth(for: node.dimension), alignment: .center)
                    .position(LifeFieldLayout.point(for: node.dimension, in: size))
                    .zIndex(isSelected ? 2 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: nodes.map(\.dimension)) { _, dimensions in
            selection.reconcile(available: Set(dimensions))
        }
        .sheet(item: $presentedDetail) { value in
            LifeFieldDimensionDetailSheet(value: value)
        }
    }

    private func activate(_ node: LifeFieldNodePresentation) {
        guard detailPresentationStyle == .inline else {
            presentedDetail = node
            selection.clear()
            return
        }

        withAnimation(
            reduceMotion
                ? .easeInOut(duration: 0.2)
                : .spring(response: 0.34, dampingFraction: 0.82)
        ) {
            selection.toggle(node.dimension)
        }
    }

    private func nodeWidth(for dimension: LifeDimension) -> CGFloat {
        dimension == .health || dimension == .relationships ? 180 : 104
    }
}

struct LifeFieldBackdrop<CenterContent: View>: View {
    let summary: LifeStateSummary
    private let centerContent: CenterContent

    init(
        summary: LifeStateSummary,
        @ViewBuilder centerContent: () -> CenterContent
    ) {
        self.summary = summary
        self.centerContent = centerContent()
    }

    private var nodes: [LifeFieldNodePresentation] {
        LifeFieldNodePresentation.make(summary: summary)
    }

    private var officialTargets: [LifeDimension: CGPoint] {
        Dictionary(
            uniqueKeysWithValues: nodes.map { node in
                (node.dimension, LifeFieldLayout.anchors(for: node).official)
            }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LivingDotField(columns: 34, rows: 45)
                    .opacity(0.34)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)
                    .zIndex(LifeFieldLayerOrder.backdropDots)

                centerContent
                    .position(LifeFieldLayout.point(for: LifeFieldLayout.visualCore, in: size))
                    .zIndex(LifeFieldLayerOrder.companionCore)

                LifeFieldParticleLinks(targets: LifeFieldRadialLinkPresentation.targets)
                    .zIndex(LifeFieldLayerOrder.radialLinks)

                LifeFieldEdgeParticles(targets: officialTargets)
                    .zIndex(LifeFieldLayerOrder.dynamicEdges)

                LifeFieldPolygon(
                    normalizedPoints: LifeFieldEdge.ordered.map {
                        LifeFieldLayout.anchor(for: $0.start)
                    }
                )
                .stroke(
                    LivingOSTheme.graphite.opacity(LifeFieldPolygonPresentation.outerOpacity),
                    lineWidth: 0.6
                )
                .zIndex(LifeFieldLayerOrder.dynamicEdges)

                LifeFieldPolygon(
                    normalizedPoints: LifeFieldEdge.ordered.compactMap {
                        officialTargets[$0.start]
                    }
                )
                .stroke(
                    LivingOSTheme.graphite.opacity(LifeFieldPolygonPresentation.innerOpacity),
                    lineWidth: 0.85
                )
                .zIndex(LifeFieldLayerOrder.dynamicEdges)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeFieldNodeLabel: View {
    let value: LifeFieldNodePresentation
    let isSelected: Bool
    let isRewardTarget: Bool
    let showsInlineDetail: Bool
    let reduceMotion: Bool
    let action: () -> Void

    private var signedDelta: String {
        value.delta > 0 ? "+\(value.delta)" : "\(value.delta)"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                nodeLabel
                    .offset(y: labelOffset)

                if isSelected && showsInlineDetail {
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
}

struct LifeFieldDimensionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let value: LifeFieldNodePresentation

    private var signedDelta: String {
        value.delta > 0 ? "+\(value.delta)" : "\(value.delta)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 28) {
                        metric(title: "当前", value: value.displayValue)
                        metric(title: "预测", value: value.projectedDisplayValue)
                        metric(title: "变化", text: signedDelta)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        Text(value.sourceText)
                        Text(value.assessmentText)
                    }
                    .font(.body)
                    .foregroundStyle(LivingOSTheme.graphite)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("life-field-detail-scroll")
            .navigationTitle(value.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func metric(title: String, value: Int) -> some View {
        metric(title: title, text: value.formatted())
    }

    private func metric(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LivingOSTheme.graphite)
            Text(text)
                .font(.title2.monospacedDigit())
                .foregroundStyle(LivingOSTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LifeFieldOfficialNode: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
            Circle()
                .stroke(
                        LivingOSTheme.graphite.opacity(isSelected ? 0.42 : 0.14),
                        lineWidth: isSelected ? 1 : 0.7
                )
                .frame(width: 32, height: 32)

            Circle()
                .fill(LivingOSTheme.ink)
                .frame(
                        width: isSelected ? 15 : 12,
                        height: isSelected ? 15 : 12
                )
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

private struct LifeFieldProjectedMarker: View {
    let isRewardTarget: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    TodayVisualTheme.growthAccent.opacity(0.78),
                    style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5])
                )
                .frame(width: 20, height: 20)

            if isRewardTarget {
                Circle()
                    .stroke(TodayVisualTheme.growthAccent.opacity(0.78), lineWidth: 1)
                    .frame(width: 28, height: 28)
                    .scaleEffect(reduceMotion ? 1 : 1.22)
                    .opacity(reduceMotion ? 0.65 : 0.18)
            }
        }
        .frame(width: 44, height: 44)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.46).repeatCount(2, autoreverses: true),
            value: isRewardTarget
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeFieldEdgeParticles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    let targets: [LifeDimension: CGPoint]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let phase = reduceMotion
                ? 0.19
                : timeline.date.timeIntervalSinceReferenceDate / 8.0
            let samples = LifeFieldEdgeParticleGeometry.presentationSamples(
                phase: phase,
                reduceMotion: reduceMotion,
                targets: targets
            )

            Canvas { context, size in
                for sample in samples {
                    let diameter = sample.diameter
                    let point = LifeFieldLayout.point(for: sample.position, in: size)
                    let rect = CGRect(
                        x: point.x - diameter / 2,
                        y: point.y - diameter / 2,
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

private struct LifeFieldParticleLinks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    let targets: [LifeDimension: CGPoint]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let phase = reduceMotion
                ? 0.19
                : timeline.date.timeIntervalSinceReferenceDate / 8.0
            let samples = LifeFieldParticleLinkGeometry.presentationSamples(
                phase: phase,
                reduceMotion: reduceMotion,
                targets: targets
            )

            Canvas { context, size in
                for sample in samples {
                    let diameter = sample.diameter
                    let point = LifeFieldLayout.point(for: sample.position, in: size)
                    let rect = CGRect(
                        x: point.x - diameter / 2,
                        y: point.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            LivingOSTheme.ink.opacity(
                                LifeFieldRadialLinkPresentation.renderedOpacity(
                                    for: sample.opacity
                                )
                            )
                        )
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

private struct LifeFieldPolygon: Shape {
    let normalizedPoints: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let points = normalizedPoints.map {
            LifeFieldLayout.point(for: $0, in: rect.size)
        }

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
