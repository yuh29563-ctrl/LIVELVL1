import SwiftData
import SwiftUI

struct StateAssessmentView: View {
    let mode: AssessmentMode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [DimensionProfile]
    @Query private var items: [Item]
    @Query private var completions: [Completion]

    @State private var entries = Self.defaultEntries
    @State private var pageIndex = 0
    @State private var initializedWeeklyEntries = false

    private static var defaultEntries: [AssessmentEntry] {
        LifeDimension.allCases.map {
            AssessmentEntry(dimension: $0, rating: 5.0, weeklyTarget: 3)
        }
    }

    private var currentEntry: AssessmentEntry {
        entries[pageIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("第 \(pageIndex + 1) / \(LifeDimension.allCases.count) 项")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(pageIndex + 1), total: Double(LifeDimension.allCases.count))
                        .tint(.indigo)
                }

                VStack(spacing: 12) {
                    Text(currentEntry.dimension.title)
                        .font(.largeTitle.bold())
                    Text("当前评分 \(currentEntry.rating, format: .number.precision(.fractionLength(1))) / 10")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 20) {
                    Slider(
                        value: ratingBinding,
                        in: 1.0...10.0,
                        step: 0.1
                    ) {
                        Text("自我评分")
                    }
                    .accessibilityValue("\(currentEntry.rating, format: .number.precision(.fractionLength(1)))")

                    Stepper(value: weeklyTargetBinding, in: 1...7) {
                        Text("每周行动目标 \(currentEntry.weeklyTarget) 次")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(20)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

                Text("此评估仅用于自我觉察，不构成医疗、心理或财务诊断。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack(spacing: AssessmentNavigationLayout.buttonSpacing) {
                    Button("上一项") {
                        pageIndex -= 1
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(pageIndex == 0)

                    Button(pageIndex == entries.count - 1 ? completionTitle : "下一项") {
                        if pageIndex == entries.count - 1 {
                            saveAssessment(at: .now)
                        } else {
                            pageIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AssessmentNavigationLayout.buttonHorizontalPadding)
            .padding(.vertical, 16)
            .navigationTitle(mode == .initial ? "Day 0 状态评估" : "每周状态评估")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: initializeWeeklyEntriesIfNeeded)
    }

    private var ratingBinding: Binding<Double> {
        Binding(
            get: { currentEntry.rating },
            set: { entries[pageIndex].rating = $0 }
        )
    }

    private var weeklyTargetBinding: Binding<Int> {
        Binding(
            get: { currentEntry.weeklyTarget },
            set: { entries[pageIndex].weeklyTarget = $0 }
        )
    }

    private var completionTitle: String {
        mode == .initial ? "生成 Day 0 状态" : "更新状态"
    }

    private func initializeWeeklyEntriesIfNeeded() {
        guard mode == .weekly, !initializedWeeklyEntries else { return }
        entries = LifeDimension.allCases.map { dimension in
            let profile = profiles.first { $0.dimension == dimension }
            return AssessmentEntry(
                dimension: dimension,
                rating: profile?.selfRating ?? 5.0,
                weeklyTarget: profile?.weeklyTarget ?? 3
            )
        }
        initializedWeeklyEntries = true
    }

    private func saveAssessment(at now: Date) {
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let records = completions.compactMap { $0.stateActivity(fallbackItem: itemByID[$0.itemID]) }
        var actionScores = LifeStateValues.neutral
        for entry in entries {
            actionScores[entry.dimension] = LifeStateEngine.actionScore(
                activities: records
                    .filter { $0.dimension == entry.dimension }
                    .map { StateActivity(date: $0.date, xp: $0.xp) },
                weeklyTarget: entry.weeklyTarget,
                now: now
            )
        }

        let result = AssessmentSettlement.makeResult(
            mode: mode, entries: entries, actionScores: actionScores, assessedAt: now
        )
        for entry in result.entries {
            if let profile = profiles.first(where: { $0.dimension == entry.dimension }) {
                profile.selfRating = entry.rating
                profile.weeklyTarget = entry.weeklyTarget
                profile.lastAssessedAt = now
            } else {
                context.insert(DimensionProfile(
                    dimension: entry.dimension,
                    selfRating: entry.rating,
                    weeklyTarget: entry.weeklyTarget,
                    lastAssessedAt: now
                ))
            }
        }
        context.insert(StateSnapshot(
            scores: result.officialScores,
            actionScores: result.baselineActionScores,
            assessedAt: now
        ))
        try? context.save()
        if mode == .weekly { dismiss() }
    }
}

#Preview("初始状态评估", traits: .fixedLayout(width: 402, height: 874)) {
    StateAssessmentView(mode: .initial)
        .modelContainer(for: [
            Item.self,
            Completion.self,
            DimensionProfile.self,
            StateSnapshot.self,
        ], inMemory: true)
}
