#if DEBUG
import SwiftUI

struct AssessmentIntroPreviewState {
    enum Phase { case introduction, questionnaire, finished }
    private(set) var phase = Phase.introduction
    private(set) var pageIndex = 0
    var answers: [String: AssessmentAnswer] = [:]
    var dimension: LifeDimension { LifeDimension.allCases[pageIndex] }
    var isPageComplete: Bool {
        (try? AssessmentQuestionnaire.rating(for: dimension, answers: answers)) != nil
    }

    mutating func start() {
        guard phase == .introduction else { return }
        phase = .questionnaire
    }

    mutating func advance() {
        guard phase == .questionnaire, isPageComplete else { return }
        if pageIndex == LifeDimension.allCases.count - 1 { phase = .finished }
        else { pageIndex += 1 }
    }

    mutating func back() {
        guard phase == .questionnaire else { return }
        if pageIndex > 0 { pageIndex -= 1 }
        else { showIntroduction() }
    }

    mutating func showIntroduction() { phase = .introduction }
}

// No model context, query, or submission callback: this flow owns only a temporary draft.
struct AssessmentIntroductionPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState(for: .voiceOver) private var sectionHeadingFocused: Bool
    @State private var preview = AssessmentIntroPreviewState()

    var body: some View {
        NavigationStack {
            Group {
                switch preview.phase {
                case .introduction:
                    AssessmentIntroductionView { preview.start() }
                case .questionnaire:
                    questionnaire
                case .finished:
                    finished
                }
            }
            .background(LivingOSTheme.canvas)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: preview.phase)
            .navigationTitle(preview.phase == .introduction ? "" : "自测试答 · 不保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(preview.phase == .introduction ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                if preview.phase != .introduction {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("返回引导") { preview.showIntroduction() }
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var questionnaire: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("第 \(preview.pageIndex + 1)/6 栏 · \(preview.answers.count)/60 题已作答")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: Double(preview.answers.count), total: 60)
                        Text(preview.dimension == .career ? "事业／主要活动" : preview.dimension.title)
                            .font(.title.bold()).accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($sectionHeadingFocused)
                        Text("请按近两周的整体体验作答；写明“目前”的题目按当前状况判断。答案没有对错。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if preview.dimension == .career {
                            Text("先选定目前的一项主要活动，例如工作、学业、家务或照护；本栏十题都围绕它回答。")
                                .font(.subheadline)
                        }
                    }
                    .id("preview-top")
                    ForEach(Array(AssessmentQuestionnaire.questions(for: preview.dimension).enumerated()), id: \.element.id) { index, question in
                        AssessmentQuestionCard(number: index + 1, question: question, answer: preview.answers[question.id]) {
                            preview.answers[question.id] = $0
                        }
                    }
                    Text("每题均需选择，至少保留一个可判断的答案。本次仅预览交互，退出后试答不会保存。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    Button(preview.pageIndex == 0 ? "回到引导" : "上一组") { preview.back() }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                    Spacer()
                    Button(preview.pageIndex == 5 ? "结束预览" : "下一组") { preview.advance() }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                        .disabled(!preview.isPageComplete)
                }
                .padding().background(.regularMaterial)
            }
            .onChange(of: preview.pageIndex) { _, _ in proxy.scrollTo("preview-top", anchor: .top) }
            .task(id: preview.pageIndex) {
                sectionHeadingFocused = false
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
                sectionHeadingFocused = true
            }
        }
    }

    private var finished: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle").font(.largeTitle)
                    .foregroundStyle(TodayVisualTheme.growthAccent).accessibilityHidden(true)
                Text("预览完成").font(.title.bold()).accessibilityAddTraits(.isHeader)
                Text("本次试答没有保存，也没有更新你的六维状态。")
                    .foregroundStyle(.secondary)
                Button("再看引导") { preview.showIntroduction() }.buttonStyle(.borderedProminent)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(26).frame(maxWidth: .infinity)
        }
    }
}

#Preview("独立试答预览") { AssessmentIntroductionPreview() }
#endif
