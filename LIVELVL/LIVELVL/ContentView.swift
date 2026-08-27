import SwiftUI
import SwiftData
#if DEBUG
import Combine
#endif

struct ContentView: View {
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
#if DEBUG
    @StateObject private var debugPresentation: DebugPresentationState
    private let debugResetActionConfiguration: ProfileView.DebugResetActionConfiguration
    private let debugResetActionTrigger: ProfileView.DebugResetActionTrigger?
    private let debugInitialTab: AppTab

    init(
        debugPresentation: DebugPresentationState = DebugPresentationState(),
        debugResetActionConfiguration: ProfileView.DebugResetActionConfiguration = .live,
        debugResetActionTrigger: ProfileView.DebugResetActionTrigger? = nil,
        debugInitialTab: AppTab = .today
    ) {
        _debugPresentation = StateObject(wrappedValue: debugPresentation)
        self.debugResetActionConfiguration = debugResetActionConfiguration
        self.debugResetActionTrigger = debugResetActionTrigger
        self.debugInitialTab = debugInitialTab
    }
#endif

    var body: some View {
#if DEBUG
        rootContent
            .alert(item: $debugPresentation.resetFailure) { failure in
                Alert(
                    title: Text(failure.title),
                    message: Text(failure.message),
                    dismissButton: .default(Text("好的"))
                )
            }
#else
        rootContent
#endif
    }

    @ViewBuilder
    private var rootContent: some View {
#if DEBUG
        switch debugPresentation.root(hasSnapshots: !snapshots.isEmpty) {
        case .initialAssessment:
            StateAssessmentView(mode: .initial)
                .accessibilityIdentifier("content-root-initial-assessment")
        case .mainTabs:
            MainTabView(
                reportLocalDataResetFailure: { debugPresentation.report($0) },
                debugResetActionConfiguration: debugResetActionConfiguration,
                debugResetActionTrigger: debugResetActionTrigger,
                debugInitialTab: debugInitialTab
            )
        }
#else
        if snapshots.isEmpty {
            StateAssessmentView(mode: .initial)
        } else {
            MainTabView()
        }
#endif
    }
}

#if DEBUG
extension ContentView {
    final class DebugPresentationState: ObservableObject {
        enum Root: Equatable {
            case initialAssessment
            case mainTabs
        }

        @Published var resetFailure: LocalDataResetFailure?

        func root(hasSnapshots: Bool) -> Root {
            hasSnapshots ? .mainTabs : .initialAssessment
        }

        func report(_ failure: LocalDataResetFailure) {
            resetFailure = failure
        }
    }
}
#endif

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [Item]
    @Query private var completions: [Completion]
    @Query private var progressItems: [Progress]
    @Query private var collectionProgressItems: [CollectionProgress]
    @Query private var profiles: [DimensionProfile]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
    @State private var showAdd = false
    @State private var showConfirm = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var pendingItemID: UUID?
    @State private var rewardFeedback: TaskRewardFeedback?
    @State private var feedbackSequenceID: UUID?
    @State private var levelUpFeedback: Int?
    @State private var rewardFlow = CompletionRewardFlowState()

    private var progress: Progress { progressItems.first ?? Progress() }

    private var activeCompanion: (definition: CollectibleDefinition, stage: CompanionStage) {
        guard let collectionProgress = collectionProgressItems.first else {
            return (CollectionCatalog.ordinary[0], .juvenile)
        }
        let definition = CollectionCatalog.ordinary(at: collectionProgress.activeOrdinaryIndex)
            ?? CollectionCatalog.ordinary[0]
        return (definition, collectionProgress.activeStage)
    }

    private var currentSummary: LifeStateSummary? {
        guard let snapshot = snapshots.first else { return nil }
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let activities = completions.compactMap { $0.stateActivity(fallbackItem: itemByID[$0.itemID]) }
        return LifeStateSummaryBuilder.build(
            profiles: profiles,
            snapshot: snapshot,
            activities: activities,
            now: .now
        )
    }

    private var lifeCorePresentation: LifeCoreWidgetPresentation {
        let companion = activeCompanion
        let currentXP = GrowthEngine.xpInCurrentLevel(for: progress.totalXP)
        let requiredXP = GrowthEngine.xpNeededForNextLevel(for: progress.totalXP)
        return LifeCoreWidgetPresentation(
            definition: companion.definition,
            stage: companion.stage,
            level: progress.level,
            currentXP: currentXP,
            requiredXP: requiredXP,
            remainingXP: requiredXP - currentXP
        )
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LivingOSPageHeader(title: "Today")
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                    .padding(.top, 10)
                    .offset(y: -28)

                    if let levelUpFeedback {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(LivingOSTheme.signal)
                                .frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                            Text("SYSTEM LEVEL \(levelUpFeedback)")
                        }
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(LivingOSTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                            .padding(.top, 8)
                            .accessibilityLabel("升级至等级 \(levelUpFeedback)")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let currentSummary {
                        TodayLifeFieldSection(
                            summary: currentSummary,
                            core: lifeCorePresentation,
                            isRewarding: rewardFeedback != nil,
                            levelUpFeedback: levelUpFeedback
                        )
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(LivingOSTheme.mist)
                            .frame(height: 0.5)

                        if items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("今天还没有任务")
                                    .font(.system(size: 17, weight: .medium))
                                Text("创建一个值得完成的现实行动。")
                                    .font(.subheadline)
                                    .foregroundStyle(LivingOSTheme.graphite)
                                Button("创建任务") { showAdd = true }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LivingOSTheme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                        }

                        ForEach(items) { item in
                            TaskRailView(
                                presentation: TaskRailPresentation(
                                    item: item,
                                    completed: isCompleted(item),
                                    rewardXP: rewardFeedback?.itemID == item.id
                                        ? rewardFeedback?.xp
                                        : nil
                                ),
                                onToggle: { toggle(item) }
                            )
                        }
                    }
                    .contextMenu {
                        Button("新建任务", systemImage: "plus") { showAdd = true }
                    }
                    .accessibilityAction(named: "新建任务") { showAdd = true }
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                    .padding(.bottom, RootTabPageLayout.contentBottomPadding)
                }
        }
            .background(LivingOSTheme.canvas)
            .sheet(isPresented: $showAdd) { AddTaskView() }
            .alert("确认完成任务？", isPresented: $showConfirm) {
                Button("确认完成") { confirmCompletion() }
                Button("先不完成", role: .cancel) { pendingItemID = nil }
            } message: {
                Text("完成后将获得对应 XP。误触时再次点击勾选按钮可以取消，并退回 XP。")
            }
            .alert("任务状态已更新", isPresented: $showMessage) { Button("好的") {} } message: { Text(message) }
            .alert("奖励处理未完成", isPresented: Binding(
                get: { rewardFlow.requiresRetry },
                set: { _ in }
            )) {
                Button("重试") { retryRewardProcessing() }
            } message: {
                Text("任务和 XP 已保存，但收藏奖励尚未处理。请重试补发奖励。")
            }
            .onAppear {
                ensureProgress()
                reconcilePersistedRewards()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                reconcilePersistedRewards()
            }
            .task(id: feedbackSequenceID) {
                guard let feedback = rewardFeedback, feedbackSequenceID == feedback.id else { return }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    rewardFeedback = nil
                }

                guard feedback.didLevelUp else {
                    feedbackSequenceID = nil
                    return
                }

                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.28)) {
                    levelUpFeedback = feedback.levelAfter
                }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    levelUpFeedback = nil
                }
                feedbackSequenceID = nil
            }
    }

    private func isCompleted(_ item: Item) -> Bool {
        completions.contains { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }
    }

    private func toggle(_ item: Item) {
        if let completion = completions.first(where: { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }) {
            do {
                try TaskRewardCoordinator.revoke(
                    completion: completion,
                    progress: progress,
                    in: context
                )
            } catch {
                message = "取消完成失败，请重试"
                showMessage = true
                return
            }
            rewardFeedback = nil
            feedbackSequenceID = nil
            levelUpFeedback = nil
            message = "已取消完成，退回 \(completion.xp) XP"
            showMessage = true
        } else {
            pendingItemID = item.id
            showConfirm = true
        }
    }

    private func confirmCompletion() {
        guard let id = pendingItemID, let item = items.first(where: { $0.id == id }) else { return }
        let levelBefore = progress.level
        do {
            _ = try TaskRewardCoordinator.complete(
                item: item,
                progress: progress,
                in: context
            )
        } catch {
            pendingItemID = nil
            message = "任务保存失败，请重试"
            showMessage = true
            return
        }
        let levelAfter = progress.level

        do {
            let persistedCompletions = try context.fetch(FetchDescriptor<Completion>())
            try CardRewardService.processCompletion(
                progress: progress,
                previousLevel: levelBefore,
                completions: persistedCompletions,
                in: context,
                now: .now,
                calendar: .current
            )
            rewardFlow.rewardProcessingSucceeded()
        } catch {
            rewardFlow.rewardProcessingFailed()
            pendingItemID = nil
            rewardFeedback = nil
            feedbackSequenceID = nil
            levelUpFeedback = nil
            return
        }

        guard rewardFlow.allowsSuccessFeedback else { return }
        pendingItemID = nil
        let feedback = TaskRewardFeedback(
            itemID: item.id,
            xp: item.xp,
            dimension: item.dimension,
            levelBefore: levelBefore,
            levelAfter: levelAfter
        )
        rewardFeedback = feedback
        feedbackSequenceID = feedback.id
    }

    private func retryRewardProcessing() {
        reconcilePersistedRewards(showSuccessMessage: true)
    }

    private func reconcilePersistedRewards(showSuccessMessage: Bool = false) {
        do {
            try CardRewardService.reconcilePersistedRewards(
                in: context,
                now: .now,
                calendar: .current
            )
            rewardFlow.rewardProcessingSucceeded()
            if showSuccessMessage {
                message = "收藏奖励已补发"
                showMessage = true
            }
        } catch {
            rewardFlow.rewardProcessingFailed()
        }
    }

    private func ensureProgress() {
        let currentProgress: Progress
        if progressItems.isEmpty {
            currentProgress = Progress()
            context.insert(currentProgress)
            try? context.save()
        } else {
            currentProgress = progressItems[0]
        }
        _ = try? CoinLedgerService.ensureLegacyXPImported(
            progress: currentProgress,
            in: context
        )
        _ = try? CardRewardService.ensureProgress(in: context)
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var minutes = 30
    @State private var difficulty = 3
    @State private var dimension: LifeDimension = .learning
    @State private var recurrence: Recurrence = .once
    private var xp: Int { GrowthEngine.recommendedXP(minutes: minutes, difficulty: difficulty) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("例如：学习英语 30 分钟", text: $title)
                Picker("生活维度", selection: $dimension) { ForEach(LifeDimension.allCases) { Text($0.title).tag($0) } }
                Picker("重复", selection: $recurrence) { ForEach(Recurrence.allCases) { Text($0.title).tag($0) } }
                Stepper("预计 \(minutes) 分钟", value: $minutes, in: 5...240, step: 5)
                Picker("难度 \(difficulty)/5", selection: $difficulty) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }
                Text("系统推荐：\(xp) XP").foregroundStyle(.secondary)
            }
            .navigationTitle("新任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        context.insert(Item(title: title, dimension: dimension, minutes: minutes, difficulty: difficulty, xp: xp, recurrence: recurrence))
                        try? context.save()
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
