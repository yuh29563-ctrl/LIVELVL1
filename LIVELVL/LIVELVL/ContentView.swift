import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]

    var body: some View {
        if snapshots.isEmpty {
            StateAssessmentView(mode: .initial)
        } else {
            MainTabView()
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("今天", systemImage: "sun.max.fill") }
            GrowthView().tabItem { Label("成长", systemImage: "chart.line.uptrend.xyaxis") }
            ProfileView().tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(TodayVisualTheme.ink)
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var items: [Item]
    @Query private var completions: [Completion]
    @Query private var progressItems: [Progress]
    @Query private var profiles: [DimensionProfile]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
    @State private var showAdd = false
    @State private var showAssessment = false
    @State private var showConfirm = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var pendingItemID: UUID?
    @State private var radarPulse: RadarPulse?
    @State private var rewardFeedback: TaskRewardFeedback?
    @State private var rewardFlow = CompletionRewardFlowState()

    private var progress: Progress { progressItems.first ?? Progress() }

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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LevelCard(
                        level: progress.level,
                        currentXP: GrowthEngine.xpInCurrentLevel(for: progress.totalXP),
                        requiredXP: GrowthEngine.xpNeededForNextLevel(for: progress.totalXP),
                        remainingXP: GrowthEngine.xpNeededForNextLevel(for: progress.totalXP) - GrowthEngine.xpInCurrentLevel(for: progress.totalXP),
                        progress: GrowthEngine.progressToNextLevel(for: progress.totalXP),
                        isRewarding: rewardFeedback != nil
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                if let currentSummary {
                    Section {
                        LifeStateCard(
                            summary: currentSummary,
                            pulse: radarPulse,
                            onAssessment: { showAssessment = true }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
                Section("今日任务") {
                    if items.isEmpty {
                        ContentUnavailableView("今天还没有任务", systemImage: "checkmark.circle", description: Text("创建一个值得完成的现实行动吧"))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(items) { item in
                        TaskRowView(
                            item: item,
                            completed: isCompleted(item),
                            feedback: rewardFeedback,
                            onToggle: { toggle(item) }
                        )
                        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TodayVisualTheme.pageBackground)
            .navigationTitle("今天")
            .toolbar {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .tint(TodayVisualTheme.ink)
            }
            .sheet(isPresented: $showAdd) { AddTaskView() }
            .sheet(isPresented: $showAssessment) { StateAssessmentView(mode: .weekly) }
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
            .onAppear(perform: ensureProgress)
            .task(id: rewardFeedback?.id) {
                guard rewardFeedback != nil else { return }
                let duration: Duration = reduceMotion ? .milliseconds(650) : .milliseconds(1_150)
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    rewardFeedback = nil
                    radarPulse = nil
                }
            }
        }
    }

    private func isCompleted(_ item: Item) -> Bool {
        completions.contains { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }
    }

    private func toggle(_ item: Item) {
        if let completion = completions.first(where: { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }) {
            context.delete(completion)
            progress.totalXP = max(0, progress.totalXP - completion.xp)
            try? context.save()
            radarPulse = nil
            rewardFeedback = nil
            message = "已取消完成，退回 \(completion.xp) XP"
            showMessage = true
        } else {
            pendingItemID = item.id
            showConfirm = true
        }
    }

    private func confirmCompletion() {
        guard let id = pendingItemID, let item = items.first(where: { $0.id == id }) else { return }
        let previousLevel = progress.level
        let completion = Completion(
            itemID: item.id,
            xp: item.xp,
            dimension: item.dimension,
            durationMinutes: item.minutes,
            taskTitle: item.title
        )
        context.insert(completion)
        progress.totalXP += item.xp
        do {
            try context.save()
        } catch {
            context.rollback()
            pendingItemID = nil
            message = "任务保存失败，请重试"
            showMessage = true
            return
        }

        do {
            let persistedCompletions = try context.fetch(FetchDescriptor<Completion>())
            try CardRewardService.processCompletion(
                progress: progress,
                previousLevel: previousLevel,
                completions: persistedCompletions,
                in: context,
                now: .now,
                calendar: .current
            )
            rewardFlow.rewardProcessingSucceeded()
        } catch {
            rewardFlow.rewardProcessingFailed()
            pendingItemID = nil
            radarPulse = nil
            rewardFeedback = nil
            return
        }

        guard rewardFlow.allowsSuccessFeedback else { return }
        pendingItemID = nil
        radarPulse = RadarPulse(dimension: item.dimension)
        rewardFeedback = TaskRewardFeedback(
            itemID: item.id,
            xp: item.xp,
            dimension: item.dimension
        )
    }

    private func retryRewardProcessing() {
        do {
            let persistedCompletions = try context.fetch(FetchDescriptor<Completion>())
            try CardRewardService.reconcile(
                progress: progress,
                completions: persistedCompletions,
                in: context,
                now: .now,
                calendar: .current
            )
            rewardFlow.rewardProcessingSucceeded()
            message = "收藏奖励已补发"
            showMessage = true
        } catch {
            rewardFlow.rewardProcessingFailed()
        }
    }

    private func ensureProgress() {
        if progressItems.isEmpty {
            context.insert(Progress())
            try? context.save()
        }
        _ = try? CardRewardService.ensureProgress(in: context)
    }
}

private struct TaskRowView: View {
    let item: Item
    let completed: Bool
    let feedback: TaskRewardFeedback?
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeOffset: CGFloat = 0
    @State private var rewardOffset: CGFloat = 6
    @State private var rewardOpacity = 0.0

    private var isRewarding: Bool {
        feedback?.itemID == item.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dimensionSymbol)
                .font(.headline)
                .foregroundStyle(TodayVisualTheme.ink)
                .frame(width: 42, height: 42)
                .background(
                    TodayVisualTheme.cloud,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TodayVisualTheme.ink)
                    .strikethrough(completed)
                Text("\(item.dimension.title) · \(item.xp) XP")
                    .font(.caption)
                    .foregroundStyle(TodayVisualTheme.graphite)
            }

            Spacer(minLength: 8)

            if isRewarding, let feedback {
                HStack(spacing: 5) {
                    Text(feedback.label)
                        .font(.caption.bold().monospacedDigit())
                    PixelFeedbackParticles()
                }
                .foregroundStyle(TodayVisualTheme.reward)
                .opacity(rewardOpacity)
                .offset(y: rewardOffset)
                .accessibilityHidden(true)
            }

            Button(action: onToggle) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.ink
                    )
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(completed ? "取消完成 \(item.title)" : "完成 \(item.title)")
        }
        .padding(14)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 10, y: 4)
        .offset(x: shakeOffset)
        .task(id: feedback?.id) {
            shakeOffset = 0
            rewardOffset = 6
            rewardOpacity = 0
            guard isRewarding else { return }

            withAnimation(.easeOut(duration: 0.22)) {
                rewardOffset = -7
                rewardOpacity = 1
            }

            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.07)) { shakeOffset = 2.5 }
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.07)) { shakeOffset = -2.5 }
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.08)) { shakeOffset = 0 }
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.24)) {
                rewardOffset = -20
                rewardOpacity = 0
            }
        }
    }

    private var dimensionSymbol: String {
        switch item.dimension {
        case .health: "figure.walk"
        case .learning: "book.closed"
        case .career: "briefcase"
        case .finance: "banknote"
        case .relationships: "person.2"
        case .interests: "paintpalette"
        }
    }
}

private struct PixelFeedbackParticles: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            Rectangle().frame(width: 3, height: 3)
            Rectangle().frame(width: 4, height: 4).opacity(0.55)
        }
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

struct GrowthView: View {
    @Query private var progressItems: [Progress]
    @Query private var profiles: [DimensionProfile]
    @Query private var items: [Item]
    @Query private var completions: [Completion]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse)
    private var snapshots: [StateSnapshot]
    @State private var showAssessment = false
    private var progress: Progress { progressItems.first ?? Progress() }

    private var summary: LifeStateSummary? {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LevelCard(
                        level: progress.level,
                        currentXP: GrowthEngine.xpInCurrentLevel(for: progress.totalXP),
                        requiredXP: GrowthEngine.xpNeededForNextLevel(for: progress.totalXP),
                        remainingXP: GrowthEngine.xpNeededForNextLevel(for: progress.totalXP) - GrowthEngine.xpInCurrentLevel(for: progress.totalXP),
                        progress: GrowthEngine.progressToNextLevel(for: progress.totalXP)
                    )

                    if let summary {
                        LifeStateCard(
                            summary: summary,
                            pulse: nil,
                            onAssessment: { showAssessment = true }
                        )
                    }

                    Text("等级记录长期积累，状态记录最近 15 天。它们彼此独立。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("成长")
            .sheet(isPresented: $showAssessment) { StateAssessmentView(mode: .weekly) }
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack { List { Section("我的") { Text("本地数据与隐私"); Text("现实奖励目标将在下一阶段加入") }; Section("产品") { Text("LIVELVL · 现实人生 RPG").foregroundStyle(.secondary) } }.navigationTitle("我的") }
    }
}
