import SwiftUI

struct LifeStateCard: View {
    let summary: LifeStateSummary
    let pulse: RadarPulse?
    let onAssessment: () -> Void

    @ScaledMetric(relativeTo: .body) private var radarHeight: CGFloat = 276

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("你的最近 15 天")
                    .font(.headline)
                    .foregroundStyle(TodayVisualTheme.graphite)
                Text("综合状态 \(summary.overallScore, format: .number.precision(.fractionLength(1)))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(pulse == nil ? TodayVisualTheme.ink : TodayVisualTheme.reward)
                    .animation(.easeInOut(duration: 0.2), value: pulse?.id)
            }

            RadarChartView(
                official: summary.official,
                projected: summary.projected,
                pulse: pulse
            )
            .frame(height: radarHeight)

            HStack(spacing: 22) {
                legendItem(title: "正式状态", color: TodayVisualTheme.ink, dashed: false)
                legendItem(
                    title: "行动预估",
                    color: TodayVisualTheme.graphite,
                    dashed: true
                )
            }
            .font(.subheadline)
            .foregroundStyle(TodayVisualTheme.graphite)

            annotation
                .font(.subheadline)
                .foregroundStyle(TodayVisualTheme.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    TodayVisualTheme.cloud,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            if summary.isAssessmentDue {
                Button("更新本周状态", action: onAssessment)
                    .buttonStyle(.bordered)
                    .tint(TodayVisualTheme.ink)
            } else {
                Text("距离下次自评还有 \(summary.daysUntilAssessment) 天")
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 16, y: 6)
    }

    @ViewBuilder
    private var annotation: some View {
        if let change = summary.highlightedChange {
            let sign = change.delta > 0 ? "+" : ""
            Text("\(change.dimension.title)预计 \(sign)\(change.delta, format: .number.precision(.fractionLength(1)))，来自「\(change.sourceTitle ?? "最近行动")」，待下次自测确认。")
        } else {
            Text("完成现实行动后，这里会显示待结算的状态变化。")
        }
    }

    private func legendItem(title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 8) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 24, y: 4))
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: dashed ? [5, 4] : [])
            )
            .frame(width: 24, height: 8)

            Text(title)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct HomeCardsPreview: View {
    let defaultScrollAnchor: UnitPoint
    private let summary: LifeStateSummary

    init(defaultScrollAnchor: UnitPoint = .top) {
        self.defaultScrollAnchor = defaultScrollAnchor
        let official = LifeStateValues(
            health: 6.2,
            learning: 5.8,
            career: 6.5,
            finance: 5.2,
            relationships: 6.8,
            interests: 7.1
        )
        var projected = official
        projected.learning = 6.1
        let dimensions = LifeDimension.allCases.map { dimension in
            DimensionStateSummary(
                dimension: dimension,
                officialScore: official[dimension],
                projectedScore: projected[dimension],
                delta: LifeStateEngine.rounded(projected[dimension] - official[dimension]),
                sourceTitle: dimension == .learning ? "阅读 30 分钟" : nil
            )
        }
        summary = LifeStateSummary(
            official: official,
            projected: projected,
            overallScore: official.average,
            dimensions: dimensions,
            highlightedChange: dimensions.first { $0.dimension == .learning },
            daysUntilAssessment: 3,
            isAssessmentDue: false
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LevelCard(
                    level: 8,
                    currentXP: 480,
                    requiredXP: 800,
                    remainingXP: 320,
                    progress: 0.6
                )
                LifeStateCard(
                    summary: summary,
                    pulse: RadarPulse(dimension: .learning),
                    onAssessment: {}
                )
            }
            .padding(16)
        }
        .defaultScrollAnchor(defaultScrollAnchor)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}

#Preview("C+ Home Cards", traits: .fixedLayout(width: 402, height: 874)) {
    HomeCardsPreview()
}

#Preview("Large Text", traits: .fixedLayout(width: 402, height: 874)) {
    HomeCardsPreview(defaultScrollAnchor: .bottom)
        .environment(\.dynamicTypeSize, .accessibility2)
}
