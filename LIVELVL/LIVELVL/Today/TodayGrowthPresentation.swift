import SwiftUI

nonisolated struct TodayHeaderPresentation: Equatable, Sendable {
    let itemCount: Int
    let eyebrow: String
    let dateText: String

    init(
        itemCount: Int,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.itemCount = max(0, itemCount)
        eyebrow = "LIVELVL"

        let components = calendar.dateComponents([.month, .day, .weekday], from: now)
        let weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let weekdayIndex = min(7, max(1, components.weekday ?? 1)) - 1
        dateText = "\(components.month ?? 1)月\(components.day ?? 1)日 · \(weekdays[weekdayIndex])"
    }

    var showsAddTaskAction: Bool { true }
    var minimumTapDimension: CGFloat { 44 }
    var accessibilityIdentifier: String { "today-add-task-button" }

    func actionTopPadding(isAccessibilitySize: Bool) -> CGFloat {
        isAccessibilitySize ? 20 : 11
    }
}

nonisolated struct TodayTaskSummaryPresentation: Equatable, Sendable {
    let completedCount: Int
    let itemCount: Int

    init(completedCount: Int, itemCount: Int) {
        let resolvedItemCount = max(0, itemCount)
        self.itemCount = resolvedItemCount
        self.completedCount = min(resolvedItemCount, max(0, completedCount))
    }

    var title: String { "今日任务" }
    var progressText: String { "\(completedCount) / \(itemCount)" }
}

struct TodayHeaderAddTaskButton: View {
    let presentation: TodayHeaderPresentation
    let isAccessibilitySize: Bool
    let action: () -> Void

    func activate() {
        action()
    }

    var body: some View {
        Button(action: activate) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .regular))
                .frame(
                    minWidth: presentation.minimumTapDimension,
                    minHeight: presentation.minimumTapDimension
                )
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.88))
                        .overlay {
                            Circle()
                                .stroke(LivingOSTheme.mist.opacity(0.8), lineWidth: 0.7)
                        }
                        .shadow(color: .black.opacity(0.055), radius: 9, y: 4)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(LivingOSTheme.ink)
        .accessibilityLabel("新建任务")
        .accessibilityHint("打开任务创建页面")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .padding(
            .top,
            presentation.actionTopPadding(isAccessibilitySize: isAccessibilitySize)
        )
    }
}

enum TodayGrowthPhase: Equatable, Sendable {
    case idle
    case task(UUID)
    case dimension(LifeDimension)
    case core
    case levelUp(Int)
}

struct TodayGrowthPresentationState: Equatable, Sendable {
    private(set) var phase: TodayGrowthPhase = .idle
    private(set) var feedback: TaskRewardFeedback?

    mutating func begin(_ value: TaskRewardFeedback) {
        feedback = value
        phase = .task(value.id)
    }

    mutating func advance() {
        guard let feedback else {
            phase = .idle
            return
        }

        switch phase {
        case .task:
            phase = .dimension(feedback.dimension)
        case .dimension:
            guard feedback.xp > 0 else {
                finish()
                return
            }
            phase = .core
        case .core:
            if feedback.didLevelUp {
                phase = .levelUp(feedback.levelAfter)
            } else {
                finish()
            }
        case .levelUp:
            finish()
        case .idle:
            break
        }
    }

    mutating func finish() {
        phase = .idle
        feedback = nil
    }

    mutating func cancel() {
        finish()
    }
}

nonisolated enum TodayGrowthPresentationActivity {
    static func shouldAdvance(hasFeedback: Bool, isSceneActive: Bool) -> Bool {
        hasFeedback && isSceneActive
    }
}

nonisolated struct XPFlowSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum XPFlowGeometry {
    static let maximumSampleCount = 18

    static func joinProgress(
        start: CGPoint,
        dimension: CGPoint,
        core: CGPoint
    ) -> Double {
        let firstLength = distance(from: start, to: dimension)
        let secondLength = distance(from: dimension, to: core)
        let totalLength = firstLength + secondLength
        guard totalLength > 0 else { return 0.5 }
        return firstLength / totalLength
    }

    static func samples(
        start: CGPoint,
        dimension: CGPoint,
        core: CGPoint,
        progress: Double,
        phase: Double,
        reduceMotion: Bool
    ) -> [XPFlowSample] {
        guard !reduceMotion else { return [] }
        let resolvedProgress = min(1, max(0, progress))
        guard resolvedProgress > 0 else { return [] }

        let join = joinProgress(start: start, dimension: dimension, core: core)
        let firstCount = min(
            maximumSampleCount - 1,
            max(2, Int((Double(maximumSampleCount - 1) * join).rounded()) + 1)
        )

        if resolvedProgress <= join {
            let localProgress = join > 0 ? resolvedProgress / join : 1
            let endpoint = interpolate(from: start, to: dimension, progress: localProgress)
            let count = max(2, Int((Double(firstCount) * localProgress).rounded(.up)))
            return segmentSamples(
                from: start,
                to: endpoint,
                count: min(firstCount, count),
                phase: phase,
                seedOffset: 0
            )
        }

        let first = segmentSamples(
            from: start,
            to: dimension,
            count: firstCount,
            phase: phase,
            seedOffset: 0
        )
        let availableSecondCount = maximumSampleCount - firstCount + 1
        let localProgress = (resolvedProgress - join) / max(0.000_001, 1 - join)
        let endpoint = interpolate(from: dimension, to: core, progress: localProgress)
        let secondCount = max(
            2,
            min(
                availableSecondCount,
                Int((Double(availableSecondCount) * localProgress).rounded(.up))
            )
        )
        let second = segmentSamples(
            from: dimension,
            to: endpoint,
            count: secondCount,
            phase: phase,
            seedOffset: firstCount
        )

        return first + second.dropFirst()
    }

    private static func segmentSamples(
        from start: CGPoint,
        to end: CGPoint,
        count: Int,
        phase: Double,
        seedOffset: Int
    ) -> [XPFlowSample] {
        guard count > 1 else { return [] }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(0.000_001, hypot(dx, dy))
        let perpendicular = CGPoint(x: -dy / length, y: dx / length)

        return (0..<count).map { index in
            let progress = CGFloat(index) / CGFloat(count - 1)
            let seed = Double((index + seedOffset) * 47 % 101) / 101
            let taper = sin(Double(progress) * .pi)
            let dance = sin((phase + seed) * .pi * 2 + Double(progress) * 9)
            let lateral = CGFloat(dance * taper * (1.2 + seed * 1.8))
            let position = CGPoint(
                x: start.x + dx * progress + perpendicular.x * lateral,
                y: start.y + dy * progress + perpendicular.y * lateral
            )

            return XPFlowSample(
                position: position,
                opacity: 0.34 + seed * 0.48,
                diameter: 1 + CGFloat(seed) * 1.5
            )
        }
    }

    private static func interpolate(
        from start: CGPoint,
        to end: CGPoint,
        progress: Double
    ) -> CGPoint {
        let resolved = CGFloat(min(1, max(0, progress)))
        return CGPoint(
            x: start.x + (end.x - start.x) * resolved,
            y: start.y + (end.y - start.y) * resolved
        )
    }

    private static func distance(from start: CGPoint, to end: CGPoint) -> Double {
        hypot(end.x - start.x, end.y - start.y)
    }
}

enum TodayGrowthAnchor: Hashable {
    case field
    case task(UUID)
}

struct TodayGrowthAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [TodayGrowthAnchor: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TodayGrowthAnchor: Anchor<CGRect>],
        nextValue: () -> [TodayGrowthAnchor: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

extension View {
    func todayGrowthAnchor(_ role: TodayGrowthAnchor) -> some View {
        anchorPreference(key: TodayGrowthAnchorPreferenceKey.self, value: .bounds) {
            [role: $0]
        }
    }
}

struct XPFlowOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var routeProgress = 0.0
    @State private var isVisible = false

    let phase: TodayGrowthPhase
    let start: CGPoint
    let dimension: CGPoint
    let core: CGPoint

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: pausesTimeline)) { timeline in
            let motionPhase = reduceMotion
                ? 0.2
                : timeline.date.timeIntervalSinceReferenceDate / 2.4
            let samples = XPFlowGeometry.samples(
                start: start,
                dimension: dimension,
                core: core,
                progress: routeProgress,
                phase: motionPhase,
                reduceMotion: reduceMotion
            )

            Canvas { context, _ in
                for sample in samples {
                    let diameter = sample.diameter
                    let rect = CGRect(
                        x: sample.position.x - diameter / 2,
                        y: sample.position.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity * phaseOpacity))
                    )
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: phase) {
            let target = targetProgress
            guard !reduceMotion else {
                routeProgress = target
                return
            }
            withAnimation(.easeInOut(duration: animationDuration)) {
                routeProgress = target
            }
        }
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }

    private var targetProgress: Double {
        switch phase {
        case .idle:
            0
        case .task:
            0.06
        case .dimension:
            XPFlowGeometry.joinProgress(start: start, dimension: dimension, core: core)
        case .core, .levelUp:
            1
        }
    }

    private var phaseOpacity: Double {
        if case .levelUp = phase { return 0.38 }
        return 1
    }

    private var animationDuration: Double {
        switch phase {
        case .task: 0.16
        case .dimension: 0.38
        case .core: 0.42
        case .levelUp, .idle: 0.2
        }
    }
}
