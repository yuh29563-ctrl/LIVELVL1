import SwiftUI

enum TaskRailMetrics {
    static let minimumActionHitTarget: CGFloat = 44
    static let minimumRowHeight: CGFloat = 62
}

struct TaskEditorPresentation: Equatable {
    let isEditingExistingTask: Bool
    let isCompletedToday: Bool

    init(item: Item?, isCompletedToday: Bool) {
        isEditingExistingTask = item != nil
        self.isCompletedToday = isCompletedToday
    }

    var navigationTitle: String {
        isEditingExistingTask ? "编辑任务" : "新任务"
    }

    var allowsFieldEditing: Bool {
        !isCompletedToday
    }

    var showsArchiveAction: Bool {
        isEditingExistingTask
    }

    var showsRevokeToEditAction: Bool {
        isEditingExistingTask && isCompletedToday
    }
}

struct TaskEditorFormState: Equatable {
    var title: String
    var dimension: LifeDimension
    var minutes: Int
    var difficulty: Int
    var recurrence: Recurrence

    init(item: Item?) {
        title = item?.title ?? ""
        dimension = item?.dimension ?? .learning
        minutes = item?.minutes ?? 30
        difficulty = item?.difficulty ?? 3
        recurrence = item?.recurrence ?? .once
    }

    var draft: TaskDraft {
        TaskDraft(
            title: title,
            dimension: dimension,
            minutes: minutes,
            difficulty: difficulty,
            recurrence: recurrence
        )
    }
}

struct TaskEditorSessionState: Equatable {
    private(set) var isLocked: Bool

    init(isCompletedToday: Bool) {
        isLocked = isCompletedToday
    }

    mutating func completionWasRevoked() {
        isLocked = false
    }
}

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
    var displayedXPText: String { xpText ?? "\(baseXP) XP" }
    var accessibilityLabel: String {
        "\(title)，\(dimensionTitle)，\(baseXP) XP，\(isCompleted ? "已完成" : "未完成")"
    }
    var completionAccessibilityLabel: String {
        isCompleted ? "取消完成 \(title)" : "完成 \(title)"
    }
    var editAccessibilityLabel: String { "编辑 \(title)" }
}

struct TaskRailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rewardOpacity = 0.0
    @State private var rewardOffset: CGFloat = 4

    let presentation: TaskRailPresentation
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(LivingOSTheme.ink.opacity(0.72), lineWidth: 1.4)
                        .frame(width: 17, height: 17)

                    if presentation.isCompleted {
                        Circle()
                            .fill(LivingOSTheme.ink)
                            .frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                            .foregroundStyle(LivingOSTheme.surface)
                    }
                }
                .frame(
                    width: TaskRailMetrics.minimumActionHitTarget,
                    height: TaskRailMetrics.minimumActionHitTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presentation.completionAccessibilityLabel)

            Button(action: onEdit) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.title)
                            .font(.system(LivingOSTypography.taskTitle, weight: .medium))
                            .foregroundStyle(LivingOSTheme.ink)
                            .lineLimit(2)

                        Text(presentation.dimensionTitle)
                            .font(.caption)
                            .foregroundStyle(LivingOSTheme.graphite)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 7) {
                        Text(presentation.displayedXPText)
                            .font(.system(.subheadline, design: .monospaced, weight: .medium))
                            .foregroundStyle(
                                presentation.isRewarding
                                    ? TodayVisualTheme.growthAccent
                                    : LivingOSTheme.ink
                            )
                            .contentTransition(.numericText())

                        if presentation.isRewarding {
                            Circle()
                                .fill(TodayVisualTheme.growthAccent)
                                .frame(width: 6, height: 6)
                                .opacity(rewardOpacity)
                                .offset(y: rewardOffset)
                                .accessibilityHidden(true)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.regular))
                            .foregroundStyle(LivingOSTheme.graphite.opacity(0.52))
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: TaskRailMetrics.minimumRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presentation.editAccessibilityLabel)
            .accessibilityValue(
                "\(presentation.dimensionTitle)，\(presentation.baseXP) XP，\(presentation.isCompleted ? "已完成" : "未完成")"
            )
            .accessibilityHint("轻点编辑任务")
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
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

struct TodayTaskSectionHeader: View {
    let presentation: TodayTaskSummaryPresentation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(presentation.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LivingOSTheme.ink)

            Spacer(minLength: 8)

            Text(presentation.progressText)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(LivingOSTheme.graphite)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日任务，已完成 \(presentation.completedCount) 项，共 \(presentation.itemCount) 项")
    }
}
