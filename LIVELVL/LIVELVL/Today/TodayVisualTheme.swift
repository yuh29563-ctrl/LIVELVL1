import SwiftUI

enum TodayVisualTheme {
    static let ink = LivingOSTheme.ink
    static let graphite = LivingOSTheme.graphite
    static let mist = LivingOSTheme.mist
    static let cloud = LivingOSTheme.surface
    static let reward = LivingOSTheme.ink
    static let rewardSoft = LivingOSTheme.mist
    static let pageBackground = LivingOSTheme.canvas
    static let growthAccent = Color(
        red: 20.0 / 255.0,
        green: 132.0 / 255.0,
        blue: 136.0 / 255.0
    )
}

nonisolated enum TodayLayout {
    static func headerOffset(isAccessibilitySize: Bool) -> CGFloat {
        0
    }
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
