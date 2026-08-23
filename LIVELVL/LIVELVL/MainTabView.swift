import SwiftUI

enum AppTab: Hashable {
    case today
    case collection
    case rewards
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem { Label("今天", systemImage: "sun.max.fill") }

            CollectionView()
                .tag(AppTab.collection)
                .tabItem { Label("收集", systemImage: "square.grid.2x2.fill") }

            RewardPlaceholderView()
                .tag(AppTab.rewards)
                .tabItem { Label("奖励", systemImage: "gift.fill") }

            ProfileView()
                .tag(AppTab.profile)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(TodayVisualTheme.ink)
    }
}
