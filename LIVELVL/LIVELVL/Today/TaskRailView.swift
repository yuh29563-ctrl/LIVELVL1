import SwiftUI

struct TaskRailPresentation: Equatable, Sendable {
    let title: String
    let dimensionTitle: String
    let baseXP: Int
    let isCompleted: Bool
    let rewardXP: Int?

    init(item: Item, completed: Bool, rewardXP: Int?) {
        title = item.title
        dimensionTitle = item.dimension.title
        baseXP = max(0, item.xp)
        isCompleted = completed
        self.rewardXP = rewardXP.map { max(0, $0) }
    }

    var isRewarding: Bool { rewardXP != nil }
    var xpText: String? {
        rewardXP.map { "+\($0) XP" }
    }
    var accessibilityLabel: String {
        "\(title)，\(dimensionTitle)，\(baseXP) XP，\(isCompleted ? "已完成" : "未完成")"
    }
    var accessibilityActionLabel: String {
        isCompleted ? "取消完成 \(title)" : "完成 \(title)"
    }
}

struct TaskRailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rewardOpacity = 0.0
    @State private var rewardOffset: CGFloat = 4

    let presentation: TaskRailPresentation
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(LivingOSTheme.ink.opacity(0.72), lineWidth: 1.4)
                        .frame(width: 17, height: 17)

                    if presentation.isCompleted {
                        Circle()
                            .fill(LivingOSTheme.ink)
                            .frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(LivingOSTheme.surface)
                    }
                }
                .frame(width: 24, height: 44)

                Text(presentation.title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(LivingOSTheme.ink)
                    .lineLimit(2)

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    if let xpText = presentation.xpText {
                        Text(xpText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(LivingOSTheme.ink)
                            .contentTransition(.numericText())

                        Circle()
                            .fill(LivingOSTheme.signal)
                            .frame(width: 6, height: 6)
                            .opacity(rewardOpacity)
                            .offset(y: rewardOffset)
                            .accessibilityHidden(true)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(LivingOSTheme.graphite.opacity(0.52))
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityActionLabel)
        .task(id: presentation.rewardXP) {
            rewardOpacity = presentation.isRewarding ? 0 : 1
            rewardOffset = reduceMotion ? 0 : 4
            guard presentation.isRewarding else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                rewardOpacity = 1
                rewardOffset = reduceMotion ? 0 : -4
            }
        }
    }
}
