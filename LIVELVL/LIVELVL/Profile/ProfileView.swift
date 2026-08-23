import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack { List { Section("我的") { Text("本地数据与隐私"); Text("现实奖励目标将在下一阶段加入") }; Section("产品") { Text("LIVELVL · 现实人生 RPG").foregroundStyle(.secondary) } }.navigationTitle("我的") }
    }
}
