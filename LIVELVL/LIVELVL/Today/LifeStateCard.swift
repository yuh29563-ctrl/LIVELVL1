import SwiftUI

enum LifeStateCardLayout {
    static let horizontalInset = GlassCardLayout.horizontalInset
    static let radarStyle: RadarChartStyle = .darkEditorial
}

struct LifeStateCard: View {
    let summary: LifeStateSummary
    let pulse: RadarPulse?
    let onAssessment: () -> Void

    @ScaledMetric(relativeTo: .body) private var radarHeight: CGFloat = 276

    var body: some View {
        GlassCardSurface(style: .lifeStateDotWave) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("你的最近 15 天")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.68))
                    Text("综合状态 \(summary.overallScore * 10, format: .number.precision(.fractionLength(1)))")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(pulse == nil ? Color.white : TodayVisualTheme.reward)
                        .animation(.easeInOut(duration: 0.2), value: pulse?.id)
                }

                RadarChartView(
                    official: summary.official,
                    projected: summary.projected,
                    pulse: pulse,
                    style: LifeStateCardLayout.radarStyle
                )
                .frame(height: radarHeight)

                HStack(spacing: 22) {
                    legendItem(title: "自测基线", color: .white, dashed: false)
                    legendItem(
                        title: "当前状态",
                        color: Color.white.opacity(0.62),
                        dashed: true
                    )
                }
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))

                annotation
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                if summary.isAssessmentDue {
                    Button("更新状态", action: onAssessment)
                        .buttonStyle(.bordered)
                        .tint(.white)
                } else {
                    Text("距离下次自评还有 \(summary.daysUntilAssessment) 天")
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, LifeStateCardLayout.horizontalInset)
    }

    @ViewBuilder
    private var annotation: some View {
        if let change = summary.highlightedChange {
            let sign = change.delta > 0 ? "+" : ""
            Text("\(change.dimension.title)行动加成 \(sign)\(change.delta * 10, format: .number.precision(.fractionLength(1)))，来自「\(change.sourceTitle ?? "最近行动")」。")
        } else {
            Text("当前状态由自测基线与最近十五天行动加成组成，每维最多加 10 分。")
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
