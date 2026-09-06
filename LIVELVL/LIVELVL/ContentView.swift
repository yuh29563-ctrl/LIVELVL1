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

private struct TodayGrowthTaskID: Hashable {
    let sequenceID: UUID?
    let isSceneActive: Bool
}

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [Item]
    @Query private var completions: [Completion]
    @Query private var progressItems: [Progress]
    @Query private var collectionProgressItems: [CollectionProgress]
    @Query private var profiles: [DimensionProfile]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
    @State private var showAdd = false
    @State private var selectedTask: Item?
    @State private var pendingArchivedItemID: UUID?
    @State private var archivedUndoItemID: UUID?
    @State private var showConfirm = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var pendingItemID: UUID?
    @State private var growthPresentation = TodayGrowthPresentationState()
    @State private var feedbackSequenceID: UUID?
    @State private var levelUpFeedback: Int?
    @State private var rewardFlow = CompletionRewardFlowState()
    @State private var isShowingJournal = false

    private var progress: Progress { progressItems.first ?? Progress() }
    private var rewardFeedback: TaskRewardFeedback? { growthPresentation.feedback }
    private var activeItems: [Item] { TodayTaskCollection.activeItems(from: items) }
    private var headerPresentation: TodayHeaderPresentation {
        TodayHeaderPresentation(itemCount: activeItems.count)
    }

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
                    LivingOSPageHeader(title: "Today") {
                        if headerPresentation.showsAddTaskAction {
                            TodayHeaderAddTaskButton(
                                presentation: headerPresentation,
                                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                            ) {
                                showAdd = true
                            }
                        }
                    }
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                    .padding(.top, 10)
                    .offset(
                        y: TodayLayout.headerOffset(
                            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                        )
                    )

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
                            growthPhase: growthPresentation.phase,
                            levelUpFeedback: levelUpFeedback
                        )
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(LivingOSTheme.mist)
                            .frame(height: 0.5)

                        TodayJournalEntryView(onOpen: { isShowingJournal = true })
                            .padding(.vertical, 16)

                        if activeItems.isEmpty {
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

                        ForEach(activeItems) { item in
                            TaskRailView(
                                presentation: TaskRailPresentation(
                                    item: item,
                                    completed: isCompleted(item),
                                    rewardXP: rewardFeedback?.itemID == item.id
                                        ? rewardFeedback?.xp
                                        : nil
                                ),
                                onToggle: { toggle(item) },
                                onEdit: { selectedTask = item }
                            )
                            .todayGrowthAnchor(.task(item.id))
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
            .overlayPreferenceValue(TodayGrowthAnchorPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    growthOverlay(anchors: anchors, proxy: proxy)
                }
            }
            .background(LivingOSTheme.canvas)
            .fullScreenCover(isPresented: $isShowingJournal) {
                JournalLiquidArchiveView(onClose: { isShowingJournal = false })
            }
            .sheet(isPresented: $showAdd) { TaskEditorView() }
            .sheet(item: $selectedTask, onDismiss: presentArchiveUndoIfNeeded) { item in
                TaskEditorView(
                    item: item,
                    completion: todayCompletion(for: item),
                    progress: progress,
                    onArchived: { pendingArchivedItemID = $0 }
                )
            }
            .alert("确认完成任务？", isPresented: $showConfirm) {
                Button("确认完成") { confirmCompletion() }
                Button("先不完成", role: .cancel) { pendingItemID = nil }
            } message: {
                Text("完成后将获得对应 XP。误触时再次点击勾选按钮可以取消，并退回 XP。")
            }
            .alert("任务状态已更新", isPresented: $showMessage) { Button("好的") {} } message: { Text(message) }
            .alert("任务已取消", isPresented: Binding(
                get: { archivedUndoItemID != nil },
                set: { isPresented in
                    if !isPresented { archivedUndoItemID = nil }
                }
            )) {
                Button("撤销") { restoreArchivedTask() }
                Button("好的", role: .cancel) { archivedUndoItemID = nil }
            } message: {
                Text("任务已从 Today 隐藏，历史完成记录与奖励保持不变。")
            }
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
                if phase == .active {
                    reconcilePersistedRewards()
                }
            }
            .task(id: TodayGrowthTaskID(
                sequenceID: feedbackSequenceID,
                isSceneActive: scenePhase == .active
            )) {
                guard let feedback = growthPresentation.feedback,
                      feedbackSequenceID == feedback.id,
                      TodayGrowthPresentationActivity.shouldAdvance(
                        hasFeedback: true,
                        isSceneActive: scenePhase == .active
                      ) else { return }

                try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 180))
                guard !Task.isCancelled, scenePhase == .active else { return }
                withAnimation(growthAnimation) {
                    growthPresentation.advance()
                }

                try? await Task.sleep(for: .milliseconds(reduceMotion ? 140 : 420))
                guard !Task.isCancelled, scenePhase == .active else { return }
                withAnimation(growthAnimation) {
                    growthPresentation.advance()
                }

                try? await Task.sleep(for: .milliseconds(reduceMotion ? 140 : 460))
                guard !Task.isCancelled, scenePhase == .active else { return }
                withAnimation(growthAnimation) {
                    growthPresentation.advance()
                }

                guard feedback.didLevelUp else {
                    feedbackSequenceID = nil
                    return
                }

                withAnimation(growthAnimation) { levelUpFeedback = feedback.levelAfter }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, scenePhase == .active else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    levelUpFeedback = nil
                    growthPresentation.advance()
                }
                feedbackSequenceID = nil
            }
    }

    @ViewBuilder
    private func growthOverlay(
        anchors: [TodayGrowthAnchor: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if let feedback = growthPresentation.feedback,
           let taskAnchor = anchors[.task(feedback.itemID)],
           let fieldAnchor = anchors[.field] {
            let taskFrame = proxy[taskAnchor]
            let fieldFrame = proxy[fieldAnchor]
            let dimensionAnchor = currentSummary.flatMap { summary in
                LifeFieldNodePresentation.make(summary: summary)
                    .first { $0.dimension == feedback.dimension }
                    .map { LifeFieldLayout.anchors(for: $0).projected }
            } ?? LifeFieldLayout.anchor(for: feedback.dimension)
            let start = CGPoint(x: taskFrame.maxX - 42, y: taskFrame.midY)
            let dimension = CGPoint(
                x: fieldFrame.minX + dimensionAnchor.x * fieldFrame.width,
                y: fieldFrame.minY + dimensionAnchor.y * fieldFrame.height
            )
            let core = CGPoint(
                x: fieldFrame.minX + LifeFieldLayout.visualCore.x * fieldFrame.width,
                y: fieldFrame.minY + LifeFieldLayout.visualCore.y * fieldFrame.height
            )

            XPFlowOverlay(
                phase: growthPresentation.phase,
                start: start,
                dimension: dimension,
                core: core
            )
        }
    }

    private var growthAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.3, dampingFraction: 0.84)
    }

    private func isCompleted(_ item: Item) -> Bool {
        todayCompletion(for: item) != nil
    }

    private func todayCompletion(for item: Item) -> Completion? {
        completions.first {
            $0.itemID == item.id && Calendar.current.isDateInToday($0.date)
        }
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
            cancelGrowthPresentation()
            message = "已取消完成，退回 \(completion.xp) XP"
            showMessage = true
        } else {
            pendingItemID = item.id
            showConfirm = true
        }
    }

    private func confirmCompletion() {
        guard let id = pendingItemID,
              let item = activeItems.first(where: { $0.id == id }) else { return }
        let levelBefore = progress.level
        do {
            _ = try TaskRewardCoordinator.complete(
                item: item,
                progress: progress,
                in: context
            )
        } catch {
            pendingItemID = nil
            cancelGrowthPresentation()
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
            cancelGrowthPresentation()
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
        growthPresentation.begin(feedback)
        feedbackSequenceID = feedback.id
    }

    private func cancelGrowthPresentation() {
        growthPresentation.cancel()
        feedbackSequenceID = nil
        levelUpFeedback = nil
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

    private func presentArchiveUndoIfNeeded() {
        guard let pendingArchivedItemID else { return }
        archivedUndoItemID = pendingArchivedItemID
        self.pendingArchivedItemID = nil
    }

    private func restoreArchivedTask() {
        guard let id = archivedUndoItemID,
              let item = items.first(where: { $0.id == id }) else {
            archivedUndoItemID = nil
            return
        }
        do {
            try TaskMutationService.restore(item, in: context)
            archivedUndoItemID = nil
        } catch {
            archivedUndoItemID = nil
            message = "恢复任务失败，请重试"
            showMessage = true
        }
    }
}

private enum TaskEditorAlert: Identifiable {
    case archive
    case error(String)

    var id: String {
        switch self {
        case .archive: "archive"
        case .error(let message): "error:\(message)"
        }
    }
}

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let item: Item?
    let completion: Completion?
    let progress: Progress?
    let onArchived: (UUID) -> Void

    @State private var form: TaskEditorFormState
    @State private var session: TaskEditorSessionState
    @State private var alert: TaskEditorAlert?

    init(
        item: Item? = nil,
        completion: Completion? = nil,
        progress: Progress? = nil,
        onArchived: @escaping (UUID) -> Void = { _ in }
    ) {
        self.item = item
        self.completion = completion
        self.progress = progress
        self.onArchived = onArchived
        _form = State(initialValue: TaskEditorFormState(item: item))
        _session = State(initialValue: TaskEditorSessionState(
            isCompletedToday: completion != nil
        ))
    }

    private var presentation: TaskEditorPresentation {
        TaskEditorPresentation(item: item, isCompletedToday: session.isLocked)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：学习英语 30 分钟", text: $form.title)
                    Picker("生活维度", selection: $form.dimension) {
                        ForEach(LifeDimension.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("重复", selection: $form.recurrence) {
                        ForEach(Recurrence.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(
                        "预计 \(form.minutes) 分钟",
                        value: $form.minutes,
                        in: 5...240,
                        step: 5
                    )
                    Picker("难度 \(form.difficulty)/5", selection: $form.difficulty) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Text("系统推荐：\(form.draft.recommendedXP) XP")
                        .foregroundStyle(.secondary)
                }
                .disabled(!presentation.allowsFieldEditing)

                if presentation.showsRevokeToEditAction {
                    Section {
                        Text("该任务今天已经完成。先取消完成，才能修改任务内容。")
                            .foregroundStyle(.secondary)
                        Button("取消完成并编辑") { revokeCompletionForEditing() }
                    }
                }

                if presentation.showsArchiveAction {
                    Section {
                        Button("取消任务", role: .destructive) {
                            alert = .archive
                        }
                    } footer: {
                        Text("任务将从 Today 隐藏；历史完成记录、XP 和金币保持不变。")
                    }
                }
            }
            .navigationTitle(presentation.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "添加" : "保存") { saveTask() }
                        .disabled(
                            !presentation.allowsFieldEditing
                                || form.draft.normalizedTitle.isEmpty
                        )
                }
            }
            .alert(item: $alert) { alert in
                switch alert {
                case .archive:
                    Alert(
                        title: Text("取消这个任务？"),
                        message: Text("任务会从 Today 隐藏，但不会删除历史记录或撤销奖励。"),
                        primaryButton: .destructive(Text("取消任务")) { archiveTask() },
                        secondaryButton: .cancel(Text("保留任务"))
                    )
                case .error(let message):
                    Alert(
                        title: Text("操作失败"),
                        message: Text(message),
                        dismissButton: .default(Text("好的"))
                    )
                }
            }
        }
    }

    private func saveTask() {
        do {
            if let item {
                try TaskMutationService.update(item, draft: form.draft, in: context)
            } else {
                let draft = form.draft
                context.insert(Item(
                    title: draft.normalizedTitle,
                    dimension: draft.dimension,
                    minutes: draft.minutes,
                    difficulty: draft.difficulty,
                    xp: draft.recommendedXP,
                    recurrence: draft.recurrence
                ))
                try context.save()
            }
            dismiss()
        } catch {
            context.rollback()
            alert = .error("任务未保存，请重试。")
        }
    }

    private func revokeCompletionForEditing() {
        guard let completion, let progress else {
            alert = .error("未找到今天的完成记录，请关闭后重试。")
            return
        }
        do {
            try TaskRewardCoordinator.revoke(
                completion: completion,
                progress: progress,
                in: context
            )
            session.completionWasRevoked()
        } catch {
            alert = .error("取消完成失败，请重试。")
        }
    }

    private func archiveTask() {
        guard let item else { return }
        do {
            try TaskMutationService.archive(item, in: context)
            onArchived(item.id)
            dismiss()
        } catch {
            alert = .error("任务未取消，请重试。")
        }
    }
}
