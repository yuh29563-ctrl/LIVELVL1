import SwiftUI

struct LevelCard: View {
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int
    let progress: Double

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(Color(red: 0.62, green: 0.45, blue: 0.95))
                        .frame(width: proxy.size.width * clampedProgress)
                }
            }
            .frame(height: 9)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("等级进度")
            .accessibilityValue("等级 \(level)，当前 \(currentXP)，共需 \(requiredXP)，还差 \(remainingXP) XP")

            Text("还需 \(remainingXP) XP 升级")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .foregroundStyle(Color.white)
        .background(
            Color(red: 0.105, green: 0.11, blue: 0.135),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var levelText: some View {
        Text("Lv.\(level)")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
    }

    private var xpText: some View {
        Text("\(currentXP) / \(requiredXP) XP")
            .font(.headline.monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.84))
            .fixedSize(horizontal: true, vertical: false)
    }
}
