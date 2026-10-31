import Foundation

nonisolated struct LifeFieldEntranceState: Equatable, Sendable {
    private var hasStarted = false
    private(set) var assessedAt: Date?
    private(set) var generation = 0
    private(set) var shouldAnimate = false

    mutating func begin(assessedAt: Date?, reduceMotion: Bool) -> Bool {
        guard !hasStarted || self.assessedAt != assessedAt else { return false }
        hasStarted = true
        self.assessedAt = assessedAt
        generation &+= 1
        shouldAnimate = !reduceMotion
        return shouldAnimate
    }

    mutating func resetForNextAppearance() {
        hasStarted = false
        assessedAt = nil
        shouldAnimate = false
        generation &+= 1
    }
}

enum LifeFieldDetailPresentationStyle: Equatable, Sendable {
    case inline
    case sheet
}

nonisolated enum LifeFieldDetailPresentation {
    static func style(isAccessibilitySize: Bool) -> LifeFieldDetailPresentationStyle {
        isAccessibilitySize ? .sheet : .inline
    }
}

struct LifeFieldNodePresentation: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }

    let dimension: LifeDimension
    let title: String
    let displayValue: Int
    let projectedDisplayValue: Int
    let delta: Int
    let sourceText: String
    let assessmentText: String
    var actionText: String = ""

    var accessibilityValue: String {
        ["当前 \(projectedDisplayValue)", "自测基线 \(displayValue)",
         "行动加成 +\(max(0, delta))", actionText, sourceText, assessmentText]
            .filter { !$0.isEmpty }.joined(separator: "，")
    }

    static func make(
        official: LifeStateValues,
        projected: LifeStateValues
    ) -> [Self] {
        LifeDimension.allCases.map { dimension in
            make(
                dimension: dimension,
                official: official[dimension],
                projected: projected[dimension],
                sourceTitle: nil,
                assessmentText: "等待评估"
            )
        }
    }

    static func make(summary: LifeStateSummary) -> [Self] {
        let summaries = Dictionary(
            uniqueKeysWithValues: summary.dimensions.map { ($0.dimension, $0) }
        )
        let assessmentText = summary.isAssessmentDue
            ? "评估已到期"
            : "距下次评估 \(summary.daysUntilAssessment) 天"

        return LifeDimension.allCases.map { dimension in
            let detail = summaries[dimension]
            var node = make(
                dimension: dimension,
                official: detail?.officialScore ?? summary.official[dimension],
                projected: detail?.projectedScore ?? summary.projected[dimension],
                sourceTitle: detail?.sourceTitle,
                assessmentText: assessmentText
            )
            if let detail, detail.targetDays > 0 {
                node.actionText = "十五天行动 \(detail.actionDays)/\(detail.targetDays) 天"
            }
            return node
        }
    }

    private static func make(
        dimension: LifeDimension,
        official: Double,
        projected: Double,
        sourceTitle: String?,
        assessmentText: String
    ) -> Self {
        let current = LifeStateDisplayScale.percentage(from: official)
        let future = LifeStateDisplayScale.percentage(from: projected)
        return Self(
            dimension: dimension,
            title: dimension.title,
            displayValue: current,
            projectedDisplayValue: future,
            delta: future - current,
            sourceText: sourceTitle.map { "来自 \($0)" } ?? "暂无近期行动",
            assessmentText: assessmentText
        )
    }
}

struct LifeFieldSelectionState: Equatable, Sendable {
    private(set) var selectedDimension: LifeDimension?

    init(selectedDimension: LifeDimension? = nil) {
        self.selectedDimension = selectedDimension
    }

    mutating func toggle(_ value: LifeDimension) {
        selectedDimension = selectedDimension == value ? nil : value
    }

    mutating func clear() {
        selectedDimension = nil
    }

    mutating func reconcile(available: Set<LifeDimension>) {
        if let selectedDimension, !available.contains(selectedDimension) {
            self.selectedDimension = nil
        }
    }
}
