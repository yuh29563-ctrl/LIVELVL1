import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var items: [Item]
    @Query private var completions: [Completion]
    @Query private var progressItems: [Progress]
    @Query private var profiles: [DimensionProfile]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var statusFieldHeight: CGFloat = 310

#if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var resetPresentation: ResetPresentation?
    let reportResetFailure: (LocalDataResetFailure) -> Void
    private let debugResetActionConfiguration: DebugResetActionConfiguration
    private let debugResetActionTrigger: DebugResetActionTrigger?

    init(
        reportResetFailure: @escaping (LocalDataResetFailure) -> Void = { _ in },
        debugResetActionConfiguration: DebugResetActionConfiguration = .live,
        debugResetActionTrigger: DebugResetActionTrigger? = nil
    ) {
        self.reportResetFailure = reportResetFailure
        self.debugResetActionConfiguration = debugResetActionConfiguration
        self.debugResetActionTrigger = debugResetActionTrigger
    }
#endif

    var body: some View {
#if DEBUG
        profileContent
            .alert(item: $resetPresentation, content: resetAlert)
            .onAppear {
                debugResetActionTrigger?.install { resetAllLocalData() }
            }
            .onDisappear {
                debugResetActionTrigger?.uninstall()
            }
#else
        profileContent
#endif
    }

    private var profileContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    YouIdentityHeader(level: level)

                    YouPageTitle()
                        .padding(.top, 26)

                    Text("个人操作系统 · 诊断中")
                        .font(.body)
                        .foregroundStyle(LivingOSTheme.graphite)
                        .padding(.top, 2)

                    YouStateHeadline(score: overallDisplayScore)
                        .padding(.top, 28)

                    YouStateField(nodes: dimensionNodes)
                        .frame(height: statusFieldHeight)
                        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 38 : 0)

                    WeeklyStateTimelineView(
                        days: weeklyDays,
                        now: .now,
                        calendar: timelineCalendar
                    )
                    .padding(.top, 10)

                    Group {
#if DEBUG
                        YouSettingsRows(onReset: { resetPresentation = .impact })
#else
                        YouSettingsRows()
#endif
                    }
                    .padding(.top, 26)

                    Text("LIVELVL · LOCAL FIRST")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(LivingOSTheme.graphite.opacity(0.72))
                        .padding(.top, 24)
                }
                .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                .padding(.top, 18)
                .padding(.bottom, RootTabPageLayout.contentBottomPadding)
            }
            .background(LivingOSTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var level: Int {
        progressItems.first?.level ?? 0
    }

    private var currentSummary: LifeStateSummary? {
        guard let snapshot = snapshots.first else { return nil }
        let itemByID = items.reduce(into: [UUID: Item]()) { result, item in
            result[item.id] = item
        }
        let activities = completions.compactMap {
            $0.stateActivity(fallbackItem: itemByID[$0.itemID])
        }
        return LifeStateSummaryBuilder.build(
            profiles: profiles,
            snapshot: snapshot,
            activities: activities,
            now: .now,
            calendar: calendar
        )
    }

    private var overallDisplayScore: Int {
        LifeStateDisplayScale.percentage(from: currentSummary?.overallScore ?? 5)
    }

    private var dimensionNodes: [LifeFieldNodePresentation] {
        guard let currentSummary else {
            return LifeFieldNodePresentation.make(
                official: .neutral,
                projected: .neutral
            )
        }
        return LifeFieldNodePresentation.make(summary: currentSummary)
    }

    private var weeklyDays: [WeeklyStateDay] {
        WeeklyStateTimelineBuilder.build(
            completions: completions,
            weekContaining: .now,
            calendar: timelineCalendar
        )
    }

    private var timelineCalendar: Calendar {
        YouTimelineCalendar.resolved(from: calendar)
    }
}

#if DEBUG
extension ProfileView {
    struct DebugResetActionConfiguration {
        let applicationSupportURL: () throws -> URL
        let removeItem: (FileManager, URL) throws -> Void

        nonisolated static var live: Self {
            Self(
                applicationSupportURL: {
                    try FileManager.default.url(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: false
                    )
                },
                removeItem: { try $0.removeItem(at: $1) }
            )
        }
    }

    @MainActor
    final class DebugResetActionTrigger {
        private var action: (() -> Void)?

        var isReady: Bool {
            action != nil
        }

        @discardableResult
        func perform() -> Bool {
            guard let action else { return false }
            action()
            return true
        }

        fileprivate func install(_ action: @escaping () -> Void) {
            self.action = action
        }

        fileprivate func uninstall() {
            action = nil
        }
    }
}

private extension ProfileView {
    enum ResetPresentation: Identifiable {
        case impact
        case final

        var id: String {
            switch self {
            case .impact: "impact"
            case .final: "final"
            }
        }
    }

    func resetAlert(for presentation: ResetPresentation) -> Alert {
        switch presentation {
        case .impact:
            Alert(
                title: Text("重置所有本地数据？"),
                message: Text("""
                将永久删除：
                • 任务与完成记录
                • 经验、等级与人生状态评估
                • 收藏卡片与待领取奖励
                • 本地奖励图片
                """),
                primaryButton: .destructive(Text("继续重置")) {
                    resetPresentation = .final
                },
                secondaryButton: .cancel(Text("取消"))
            )
        case .final:
            Alert(
                title: Text("最后确认"),
                message: Text("此操作无法撤销。"),
                primaryButton: .destructive(Text("确认重置"), action: resetAllLocalData),
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    func resetAllLocalData() {
        let fileManager = FileManager.default

        do {
            let applicationSupportURL = try debugResetActionConfiguration.applicationSupportURL()
            LocalDataResetAction.perform(
                context: modelContext,
                fileManager: fileManager,
                applicationSupportURL: applicationSupportURL,
                removeItem: debugResetActionConfiguration.removeItem,
                reportFailure: reportResetFailure
            )
            resetPresentation = nil
        } catch {
            resetPresentation = nil
            reportResetFailure(LocalDataResetFailure(error: error))
        }
    }
}
#endif
