import SwiftUI

struct LevelCard: View {
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int
    let progress: Double
    var isRewarding = false

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                PixelSproutView()
                    .padding(10)
                    .background(
                        TodayVisualTheme.cloud,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        levelText
                        Spacer(minLength: 16)
                        xpText
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        levelText
                        xpText
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TodayVisualTheme.mist)
                    Capsule()
                        .fill(isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.ink)
                        .frame(width: proxy.size.width * clampedProgress)
                }
                .animation(.easeInOut(duration: 0.2), value: isRewarding)
            }
            .frame(height: 9)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("等级进度")
            .accessibilityValue("等级 \(level)，当前 \(currentXP)，共需 \(requiredXP)，还差 \(remainingXP) XP")

            Text("还需 \(remainingXP) XP 升级")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(TodayVisualTheme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .foregroundStyle(TodayVisualTheme.ink)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 6)
    }

    private var levelText: some View {
        Text("Lv.\(level)")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
    }

    private var xpText: some View {
        Text("\(currentXP) / \(requiredXP) XP")
            .font(.headline.monospacedDigit())
            .foregroundStyle(isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.graphite)
            .animation(.easeInOut(duration: 0.2), value: isRewarding)
            .fixedSize(horizontal: true, vertical: false)
    }
}
