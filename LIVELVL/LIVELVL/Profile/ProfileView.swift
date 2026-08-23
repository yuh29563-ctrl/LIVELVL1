import SwiftUI
#if DEBUG
import SwiftData
#endif

struct ProfileView: View {
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
            List {
                Section("我的") {
                    Text("本地数据与隐私")
                    Text("现实奖励目标将在下一阶段加入")
                }

#if DEBUG
                Section("开发者") {
                    Button("重置所有本地数据", role: .destructive) {
                        resetPresentation = .impact
                    }
                }
#endif

                Section("产品") {
                    Text("LIVELVL · 现实人生 RPG")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
        }
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
