import SwiftUI

struct LifeStateStatusCard: View {
    let summary: LifeStateSummary
    let onAssessment: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("六维状态").font(.headline).accessibilityAddTraits(.isHeader)
            Text("节点显示当前状态（0–100）：自测确定基线，最近十五天的行动最多加 10 分。点击节点查看依据。")
                .font(.subheadline).foregroundStyle(.secondary)
            if let date = summary.assessedAt {
                Text("上次自测：\(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if summary.isAssessmentDue {
                if summary.shouldRemindForAssessment {
                    Text("十五天过去了，是否更新您的状态？").font(.headline)
                } else {
                    Text("本次提醒已跳过，您仍可随时补测。").font(.subheadline)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { assessmentActions }
                    VStack(alignment: .leading, spacing: 8) { assessmentActions }
                }
            } else {
                Text("距离下次自测还有 \(summary.daysUntilAssessment) 天")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var assessmentActions: some View {
        Button("更新状态", action: onAssessment).buttonStyle(.borderedProminent)
        if summary.shouldRemindForAssessment {
            Button("这次跳过", action: onSkip).buttonStyle(.bordered)
        }
    }
}
