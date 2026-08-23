import SwiftUI
#if DEBUG
import SwiftData
#endif

struct ProfileView: View {
#if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var resetPresentation: ResetPresentation?
#endif

    var body: some View {
#if DEBUG
        profileContent
            .alert(item: $resetPresentation, content: resetAlert)
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
private extension ProfileView {
    enum ResetPresentation: Identifiable {
        case impact
        case final
        case error(String)

        var id: String {
            switch self {
            case .impact: "impact"
            case .final: "final"
            case .error: "error"
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
        case let .error(message):
            Alert(
                title: Text("重置未完成"),
                message: Text(message),
                dismissButton: .default(Text("好的"))
            )
        }
    }

    func resetAllLocalData() {
        let fileManager = FileManager.default

        do {
            let applicationSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            try LocalDataResetService.reset(
                context: modelContext,
                fileManager: fileManager,
                applicationSupportURL: applicationSupportURL
            )
            resetPresentation = nil
        } catch {
            resetPresentation = .error(error.localizedDescription)
        }
    }
}
#endif
