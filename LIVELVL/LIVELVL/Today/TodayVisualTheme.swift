import SwiftUI

enum TodayVisualTheme {
    static let ink = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let graphite = Color(red: 0.39, green: 0.40, blue: 0.42)
    static let mist = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let cloud = Color(red: 0.94, green: 0.95, blue: 0.96)
    static let reward = Color(red: 0.04, green: 0.65, blue: 0.63)
    static let rewardSoft = Color(red: 0.82, green: 0.95, blue: 0.94)
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
}

struct TaskRewardFeedback: Identifiable, Equatable {
    let id = UUID()
    let itemID: UUID
    let xp: Int
    let dimension: LifeDimension
    let levelBefore: Int
    let levelAfter: Int

    var label: String { "+\(xp) XP" }
    var didLevelUp: Bool { levelAfter > levelBefore }
}

struct PixelSproutView: View {
    private let pixel: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                pixelBlock(.clear)
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(Color(red: 0.36, green: 0.64, blue: 0.28))
                pixelBlock(.clear)
                pixelBlock(Color(red: 0.36, green: 0.64, blue: 0.28))
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(.clear)
            }
            HStack(spacing: 0) {
                pixelBlock(.clear)
                pixelBlock(.clear)
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(.clear)
                pixelBlock(.clear)
            }
            HStack(spacing: 0) {
                pixelBlock(.clear)
                pixelBlock(.clear)
                pixelBlock(.clear)
                pixelBlock(Color(red: 0.25, green: 0.52, blue: 0.22))
                pixelBlock(.clear)
                pixelBlock(.clear)
                pixelBlock(.clear)
            }
            HStack(spacing: 0) {
                pixelBlock(.clear)
                pixelBlock(.clear)
                pixelBlock(Color(red: 0.72, green: 0.57, blue: 0.39))
                pixelBlock(Color(red: 0.84, green: 0.70, blue: 0.50))
                pixelBlock(Color(red: 0.72, green: 0.57, blue: 0.39))
                pixelBlock(.clear)
                pixelBlock(.clear)
            }
        }
        .accessibilityHidden(true)
    }

    private func pixelBlock(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: pixel, height: pixel)
    }
}
