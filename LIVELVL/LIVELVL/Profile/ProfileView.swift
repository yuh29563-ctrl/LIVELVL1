import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var completions: [Completion]
    @Query private var progressItems: [Progress]
    @Environment(\.calendar) private var calendar

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
                VStack(alignment: .leading, spacing: 22) {
                    YouIdentityCard(
                        presentation: identityPresentation,
                        level: level,
                        currentLevelXP: currentLevelXP,
                        requiredLevelXP: requiredLevelXP,
                        progress: levelProgress
                    )

                    YouLiveTableView(
                        completions: completions,
                        now: .now,
                        calendar: timelineCalendar
                    )

                    YouXPTrendView(
                        completions: completions,
                        now: .now,
                        calendar: timelineCalendar
                    )

                    Group {
#if DEBUG
                        YouSettingsRows(onReset: { resetPresentation = .impact })
#else
                        YouSettingsRows()
#endif
                    }

                    Text(YouAppMetadata.footer)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(LivingOSTheme.graphite.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .center)
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

    private var totalXP: Int {
        max(0, progressItems.first?.totalXP ?? 0)
    }

    private var currentLevelXP: Int {
        GrowthEngine.xpInCurrentLevel(for: totalXP)
    }

    private var requiredLevelXP: Int {
        GrowthEngine.xpNeededForNextLevel(for: totalXP)
    }

    private var levelProgress: Double {
        GrowthEngine.progressToNextLevel(for: totalXP)
    }

    private var timelineCalendar: Calendar {
        YouTimelineCalendar.resolved(from: calendar)
    }

    private var identityPresentation: YouIdentityPresentation {
#if DEBUG
        .development
#else
        .localOnly
#endif
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
