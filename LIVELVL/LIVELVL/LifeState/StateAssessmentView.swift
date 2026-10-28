import SwiftData
import SwiftUI

struct StateAssessmentView: View {
    let mode: AssessmentMode
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [DimensionProfile]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse) private var snapshots: [StateSnapshot]
    @State private var answers: [String: AssessmentAnswer] = [:]
    @State private var weeklyTargets: [LifeDimension: Int] = [:]
    @State private var pageIndex = 0
    @State private var now = Date.now
    @State private var initialized = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var dimension: LifeDimension { LifeDimension.allCases[pageIndex] }
    private var questions: [AssessmentQuestion] { AssessmentQuestionnaire.questions(for: dimension) }
    private var canUpdate: Bool {
        guard let latest = snapshots.first else { return true }
        return LifeStateEngine.isAssessmentDue(lastAssessedAt: latest.assessedAt, now: now)
    }
    private var isPageComplete: Bool {
        (try? AssessmentQuestionnaire.rating(for: dimension, answers: answers)) != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if canUpdate { questionnaire }
                else { waitingContent }
            }
            .background(LivingOSTheme.canvas)
            .navigationTitle(mode == .initial ? "初次状态自测" : "十五日状态自测")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode != .initial {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("稍后再测") { dismiss() }
                    }
                }
            }
            .alert("暂未保存", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("好的") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
        .onAppear {
            refreshDate()
            guard !initialized else { return }
            weeklyTargets = Dictionary(uniqueKeysWithValues: profiles.map { ($0.dimension, $0.weeklyTarget) })
            initialized = true
        }
        .onChange(of: scenePhase) { _, value in if value == .active { refreshDate() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in refreshDate() }
        .task(id: now) {
            guard scenePhase == .active,
                  let tomorrow = Calendar.current.date(byAdding: .day, value: 1,
                    to: Calendar.current.startOfDay(for: now)) else { return }
            do { try await Task.sleep(for: .seconds(max(0.05, tomorrow.timeIntervalSinceNow))) }
            catch { return }
            guard !Task.isCancelled else { return }
            refreshDate()
        }
    }

    private var questionnaire: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("第 \(pageIndex + 1)/6 组 · \(answers.count)/60 题已作答")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: Double(answers.count), total: 60)
                        Text(dimension == .career ? "事业／主要活动" : dimension.title)
                            .font(.title.bold()).accessibilityAddTraits(.isHeader)
                        Text("请按近两周的整体体验作答；写明“目前”的题目按当前状况判断。答案没有对错。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if dimension == .career {
                            Text("先选定你目前的一项主要活动，例如工作、学业、家务或照护；本组十题都围绕它回答。")
                                .font(.subheadline)
                        }
                    }
                    .id("assessment-top")
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        AssessmentQuestionCard(number: index + 1, question: question, answer: answers[question.id]) {
                            answers[question.id] = $0
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(value: Binding(
                            get: { weeklyTargets[dimension] ?? 3 },
                            set: { weeklyTargets[dimension] = $0 }
                        ), in: 1...7) {
                            Text("每周行动目标：\(weeklyTargets[dimension] ?? 3) 天")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("十五天目标 \(LifeStateEngine.targetDays(weeklyTarget: weeklyTargets[dimension] ?? 3)) 天；同一天完成多项任务只记一个行动日，最多加 10 分。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    Text("每组十题均需选择，至少保留一个可判断的答案。“不适用／无法判断”不计分。本自测用于自我觉察，采用 LIVELVL 自有计分规则。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    Button("上一组") { pageIndex -= 1 }
                        .buttonStyle(.bordered).disabled(pageIndex == 0 || isSaving)
                    Spacer()
                    Button(pageIndex == 5 ? "保存状态" : "下一组") {
                        if pageIndex == 5 { save() } else { pageIndex += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isPageComplete || isSaving)
                }
                .padding()
                .background(.regularMaterial)
            }
            .onChange(of: pageIndex) { _, _ in proxy.scrollTo("assessment-top", anchor: .top) }
        }
    }

    private var waitingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("状态自测每十五天开放一次").font(.title2.bold())
                if let latest = snapshots.first {
                    Text("距离下次自测还有 \(LifeStateEngine.daysUntilAssessment(lastAssessedAt: latest.assessedAt, now: now)) 天")
                    Text("上次自测：\(latest.assessedAt.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                }
                Text("这期间完成任务，仍会更新对应维度的行动加成。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private func refreshDate() { now = .now }
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try StateAssessmentStore.submit(answers: answers, weeklyTargets: weeklyTargets, in: context)
            if mode != .initial { dismiss() }
        } catch { saveError = error.localizedDescription }
    }
}

struct AssessmentQuestionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let number: Int
    let question: AssessmentQuestion
    let answer: AssessmentAnswer?
    let select: (AssessmentAnswer) -> Void
    private var gradedAnswers: [AssessmentAnswer] { AssessmentAnswer.allCases.filter { $0 != .notApplicable } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(number). \(question.statement)")
                .font(.headline).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if question.id == "health.06" {
                Text("未进行训练时，可选择“不适用／无法判断”。")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if question.id == "health.07" {
                Text("可考虑蔬果搭配、食物多样性，以及高盐高糖食物的摄入。")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if question.id == "finance.07" {
                Text("没有相关财务承诺时，可选择“不适用／无法判断”。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if dynamicTypeSize.isAccessibilitySize { labeledChoices }
            else {
                ViewThatFits(in: .horizontal) {
                    VStack(spacing: 8) {
                        AssessmentChoiceRowLayout {
                            ForEach(gradedAnswers) { choice in
                                let diameter = AssessmentChoiceGeometry.diameters[choice.rawValue]
                                Button { select(choice) } label: {
                                    Circle()
                                        .fill(answer == choice ? Color.indigo : Color.clear)
                                        .overlay(Circle().stroke(Color.indigo.opacity(0.7), lineWidth: 1.5))
                                        .frame(width: diameter, height: diameter)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(choice.title)
                                .accessibilityValue(answer == choice ? "已选择" : "未选择")
                                .accessibilityAddTraits(answer == choice ? [.isSelected] : [])
                            }
                        }
                        HStack {
                            Text("完全不同意")
                            Spacer()
                            Text("完全同意")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    labeledChoices
                }
            }
            if let answer, answer != .notApplicable {
                Text("已选：\(answer.title)").font(.subheadline).foregroundStyle(.indigo)
            }
            Button("不适用／无法判断") { select(.notApplicable) }
                .font(.subheadline).frame(minHeight: 44)
                .foregroundStyle(answer == .notApplicable ? Color.indigo : Color.secondary)
                .accessibilityValue(answer == .notApplicable ? "已选择" : "未选择")
                .accessibilityAddTraits(answer == .notApplicable ? [.isSelected] : [])
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var labeledChoices: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(gradedAnswers) { choice in
                Button { select(choice) } label: {
                    HStack {
                        Text(choice.title).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if answer == choice { Image(systemName: "checkmark.circle.fill") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityValue(answer == choice ? "已选择" : "未选择")
                .accessibilityAddTraits(answer == choice ? [.isSelected] : [])
            }
        }
        .buttonStyle(.plain)
    }
}
