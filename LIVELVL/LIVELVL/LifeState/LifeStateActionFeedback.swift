import Foundation

struct LifeStateActionFeedback {
    let before: DimensionStateSummary
    let after: DimensionStateSummary

    var text: String {
        let days = "近十五天行动 \(after.actionDays)/\(after.targetDays) 天"
        let increase = (after.projectedScore - before.projectedScore) * 10
        if increase >= 0.05 {
            return "\(after.dimension.title)：\(days)，状态 \(number(before.projectedScore * 10)) → \(number(after.projectedScore * 10))（+\(number(increase))）。"
        }
        return "已记录\(after.dimension.title)行动，\(days)。今天已计入的行动日和已达上限的分数不会重复增加。"
    }

    private func number(_ value: Double) -> String { String(format: "%.1f", value) }
}
