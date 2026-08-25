import SwiftUI

struct RewardPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "奖励商城正在准备",
                systemImage: "gift",
                description: Text("下一阶段可以用金币兑换你为自己设定的现实奖励")
            )
            .foregroundStyle(TodayVisualTheme.ink)
            .navigationTitle("奖励")
            .navigationBarTitleDisplayMode(RootTabPageLayout.navigationTitleMode)
        }
    }
}
