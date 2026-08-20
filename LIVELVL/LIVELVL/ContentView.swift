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
        .tint(.indigo)
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var context
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
                Section { levelHeader }
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
                Section("今日行动") {
                    if items.isEmpty {
                        ContentUnavailableView("今天还没有任务", systemImage: "checkmark.circle", description: Text("创建一个值得完成的现实行动吧"))
                    }
                    ForEach(items) { item in
                        taskRow(item)
                    }
                }
            }
            .navigationTitle("今天")
            .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $showAdd) { AddTaskView() }
            .sheet(isPresented: $showAssessment) { StateAssessmentView(mode: .weekly) }
            .alert("确认完成任务？", isPresented: $showConfirm) {
                Button("确认完成") { confirmCompletion() }
                Button("先不完成", role: .cancel) { pendingItemID = nil }
            } message: {
                Text("完成后将获得对应 XP。误触时再次点击勾选按钮可以取消，并退回 XP。")
            }
            .alert("任务状态已更新", isPresented: $showMessage) { Button("好的") {} } message: { Text(message) }
            .onAppear(perform: ensureProgress)
        }
    }

    private var levelHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv.\(progress.level)").font(.largeTitle.bold())
                Spacer()
                Text("\(progress.totalXP) XP").foregroundStyle(.secondary)
            }
            ProgressView(value: GrowthEngine.progressToNextLevel(for: progress.totalXP))
                .tint(.indigo)
            Text("还需 \(GrowthEngine.xpNeededForNextLevel(for: progress.totalXP) - GrowthEngine.xpInCurrentLevel(for: progress.totalXP)) XP 升级")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("把今天的一点行动，记成成长。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func taskRow(_ item: Item) -> some View {
        let completed = isCompleted(item)
        return HStack(spacing: 12) {
            Button { toggle(item) } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed ? .green : .indigo)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading) {
                Text(item.title).strikethrough(completed)
                Text("\(item.dimension.title) · \(item.xp) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
            message = "已取消完成，退回 \(completion.xp) XP"
            showMessage = true
        } else {
            pendingItemID = item.id
            showConfirm = true
        }
    }

    private func confirmCompletion() {
        guard let id = pendingItemID, let item = items.first(where: { $0.id == id }) else { return }
        context.insert(Completion(
            itemID: item.id,
            xp: item.xp,
            dimension: item.dimension,
            taskTitle: item.title
        ))
        progress.totalXP += item.xp
        try? context.save()
        pendingItemID = nil
        radarPulse = RadarPulse(dimension: item.dimension)
        message = "获得 +\(item.xp) XP"
        showMessage = true
    }

    private func ensureProgress() {
        guard progressItems.isEmpty else { return }
        context.insert(Progress())
        try? context.save()
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
