import SwiftUI

struct CollectionView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "还没有成熟的陪伴",
                systemImage: "square.grid.2x2",
                description: Text("继续行动，第一张卡片会来到这里")
            )
            .foregroundStyle(TodayVisualTheme.ink)
            .navigationTitle("收集")
        }
    }
}
