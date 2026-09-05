import SwiftUI

struct YouIdentityCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presentation: YouIdentityPresentation
    let level: Int
    let currentLevelXP: Int
    let requiredLevelXP: Int
    let progress: Double

    var body: some View {
        YouSurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    if layoutMode == .stacked {
                        VStack(alignment: .leading, spacing: 14) {
                            avatar
                            identity
                        }
                    } else {
                        HStack(spacing: 16) {
                            avatar
                            identity
                            Spacer(minLength: 8)
                            levelBadge
                        }
                    }
                }
                if layoutMode == .stacked { levelBadge }

                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if layoutMode == .stacked {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("当前等级进度")
                                Text("\(currentLevelXP) / \(requiredLevelXP) XP").monospacedDigit()
                            }
                        } else {
                            HStack {
                                Text("当前等级进度")
                                Spacer()
                                Text("\(currentLevelXP) / \(requiredLevelXP) XP").monospacedDigit()
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(LivingOSTheme.graphite)
                    ProgressView(value: min(1, max(0, progress)))
                        .tint(LivingOSTheme.ink)
                        .accessibilityLabel("当前等级进度")
                        .accessibilityValue("\(currentLevelXP) / \(requiredLevelXP) XP")
                }
            }
        }
    }

    private var avatar: some View {
        Text(presentation.initials)
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(LivingOSTheme.ink, in: Circle())
            .accessibilityHidden(true)
    }

    private var layoutMode: YouAdaptiveLayoutMode {
        YouAdaptiveLayout.mode(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(presentation.displayName).font(.title3.weight(.bold))
            Text(presentation.status)
                .font(.caption)
                .foregroundStyle(LivingOSTheme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var levelBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("LEVEL")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(LivingOSTheme.graphite)
            Text(level, format: .number)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("等级 \(level)")
    }
}

nonisolated struct YouSettingsListLayout: Equatable, Sendable {
    let sectionHeaderCount = 0
    let separatorIndices: [Int]

    init(rowCount: Int) {
        separatorIndices = rowCount > 1 ? Array(0..<(rowCount - 1)) : []
    }

    func showsSeparator(after rowIndex: Int) -> Bool {
        separatorIndices.contains(rowIndex)
    }
}

struct YouSettingsRows: View {
#if DEBUG
    let onReset: () -> Void
#endif

    private let layout = YouSettingsListLayout(rowCount: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink { StateAssessmentView(mode: .weekly) } label: {
                YouSettingsRow(icon: "waveform.path.ecg", title: "每周评估")
            }
            separator(after: 0)
            NavigationLink { LocalDataPrivacyView() } label: {
                YouSettingsRow(icon: "lock.shield", title: "数据与隐私")
            }
            separator(after: 1)
            NavigationLink { YouFAQView() } label: {
                YouSettingsRow(icon: "questionmark", title: "常见问题")
            }
            separator(after: 2)
            NavigationLink { YouAboutView() } label: {
                YouSettingsRow(icon: "circle", title: "关于 LIVELVL")
            }
            separator(after: 3)
            NavigationLink {
#if DEBUG
                YouPreferencesView(onReset: onReset)
#else
                YouPreferencesView()
#endif
            } label: {
                YouSettingsRow(icon: "gearshape", title: "设置")
            }
        }
    }

    @ViewBuilder
    private func separator(after rowIndex: Int) -> some View {
        if layout.showsSeparator(after: rowIndex) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
    }
}

struct YouSettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.body.weight(.regular)).frame(width: 28)
            Text(title).font(.body.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LivingOSTheme.graphite.opacity(0.7))
        }
        .foregroundStyle(LivingOSTheme.ink)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct LocalDataPrivacyView: View {
    var body: some View {
        YouInformationPage(title: "数据与隐私", sections: [
            ("当前数据方式", "现阶段任务、完成记录、等级、状态评估、收藏卡片、奖励与本地图片只保存在这台设备上。当前版本尚未接入账户或云同步。"),
            ("删除与重置", "删除 App 会移除其本地数据。Debug 构建中的全量重置也会删除本机记录，并且需要两次确认。"),
            ("隐私边界", "LIVE 表的日期详情只显示 XP 与完成数量，不显示任务名称。LIVELVL 当前不接入分析 SDK、网络账户或真实支付。"),
            ("上线前说明", "账户、加密同步、恢复与正式隐私政策将在独立阶段完成；启用前不会显示为已登录或已同步。")
        ])
    }
}

struct YouFAQView: View {
    private let questions: [(String, String)] = [
        ("XP 从哪里来？", "完成 Today 中的任务后，会按照现有任务规则获得 XP。You 页面只读取这些记录，不会改变结算。"),
        ("LIVE 表的颜色代表什么？", "0 XP 为白色，1–99 为浅灰，100–199 为中灰，200–299 为近黑，300 XP 及以上为黑色。"),
        ("为什么折线图从 0–600 开始？", "600 XP 是便于比较的默认显示范围，不是每日获取上限。单日超过 600 时，纵轴会自动扩展并保留真实值。"),
        ("周、月、年趋势如何计算？", "周和月按天汇总，年按月汇总；一周固定从周一开始，当前周期不会绘制未来日期。"),
        ("撤销任务后会怎样？", "对应完成记录被移除后，LIVE 表和趋势会随真实记录一起减少。"),
        ("每周评估是什么？", "每周评估用于更新人生状态。它与 XP 活动历史相互独立，You 页的改版不会删除评估或历史数据。"),
        ("数据会同步到其他设备吗？", "当前不会。此版本仍为本地数据模式；账户、加密同步与恢复会在独立阶段实现。")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(questions.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup {
                        Text(item.1)
                            .font(.body)
                            .foregroundStyle(LivingOSTheme.graphite)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                    } label: {
                        Text(item.0)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(LivingOSTheme.ink)
                            .padding(.vertical, 16)
                    }
                    .tint(LivingOSTheme.ink)
                    Divider()
                }
            }
            .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
            .padding(.bottom, 40)
        }
        .background(LivingOSTheme.canvas)
        .navigationTitle("常见问题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct YouAboutView: View {
    var body: some View {
        YouInformationPage(title: "关于 LIVELVL", sections: [
            ("把成长变成可见的生活记录", "LIVELVL 是一套个人成长操作系统：用行动获得经验，用长期记录看见时间如何累积。"),
            ("这个版本", "版本 \(YouAppMetadata.version)（\(YouAppMetadata.build)）"),
            ("当前阶段", "You 页面提供本地身份预览、LIVE 活动表、XP 趋势、每周评估与基础信息入口。账户与同步尚未开放。")
        ])
    }
}

struct YouInformationPage: View {
    let title: String
    let sections: [(String, String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.0).font(.headline)
                        Text(section.1)
                            .font(.body)
                            .foregroundStyle(LivingOSTheme.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LivingOSMetrics.pageHorizontalInset)
        }
        .background(LivingOSTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct YouPreferencesView: View {
#if DEBUG
    let onReset: () -> Void
#endif

    var body: some View {
        List {
            Section("显示与辅助功能") {
                Text("LIVELVL 会跟随系统的动态字体、VoiceOver 与减少动态效果设置。")
                    .foregroundStyle(.secondary)
            }
#if DEBUG
            Section("开发者") {
                Button("重置所有本地数据", role: .destructive, action: onReset)
            }
#endif
        }
        .scrollContentBackground(.hidden)
        .background(LivingOSTheme.canvas)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum YouAppMetadata {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var footer: String { "LIVELVL · \(version) (\(build)) · LOCAL" }
}
