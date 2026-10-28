#if DEBUG
import SwiftUI

// Layered composition and entrance adapted from OnboardMate, Copyright (c) 2024 Kirlos Yousef.
// Upstream: github.com/KirlosYousef/OnboardMate; see ThirdPartyNotices/OnboardMate-LICENSE.txt.
struct AssessmentIntroductionView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var descriptionMinimumHeight = 40
    @State private var revealedLayer = 0
    var previewReduceMotion = false
    let onStart: () -> Void
    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("LIVELVL").font(.caption.monospaced().weight(.semibold)).tracking(3)
                    Spacer()
                    Text("六维状态自测").font(.caption)
                }
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

                AssessmentIntroductionDiagram()
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .frame(height: typeSize.isAccessibilitySize ? 150 : 205)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(revealedLayer >= 1 || reduceMotion ? 1 : 0.96)
                    .opacity(revealedLayer >= 1 || reduceMotion ? 1 : 0.02)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("了解此刻的自己")
                        .font(.largeTitle.bold()).tracking(-1)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("从你的真实感受开始，\n看见生活的不同面向。")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilitySortPriority(3)
                .opacity(revealedLayer >= 2 || reduceMotion ? 1 : 0.02)
                .offset(y: revealedLayer >= 2 || reduceMotion ? 0 : 6)

                VStack(alignment: .leading, spacing: 24) {
                    introductionPoint("circle.hexagongrid", title: "六个维度",
                        text: "健康、学习、主要活动、财务、人际与兴趣。")
                    introductionPoint("slider.horizontal.3", title: "按真实感受回答",
                        text: "回顾近两周，选择符合程度；无法判断时可选“不适用”。")
                    introductionPoint("chart.xyaxis.line", title: "让行动留下变化",
                        text: "自测确定状态基线，最近十五天的任务表现带来行动加成。")
                }
                .accessibilitySortPriority(2)
                .opacity(revealedLayer >= 2 || reduceMotion ? 1 : 0.02)
            }
            .padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 24)
            .frame(maxWidth: 540, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(LivingOSTheme.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                Button(action: onStart) {
                    HStack {
                        Spacer()
                        Text("开始自测").font(.headline)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                        Spacer()
                    }
                    .padding(.vertical, 17).padding(.horizontal, 12)
                    .frame(minHeight: 54)
                    .foregroundStyle(.white)
                    .background(LivingOSTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("assessment-intro-start")
                .accessibilityHint("进入问答，每栏十题，可以返回修改")
                Text("6 栏 · 每栏 10 题 · 答案没有对错")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 12)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
            .background(LivingOSTheme.canvas)
            .opacity(revealedLayer >= 3 || reduceMotion ? 1 : 0.92)
            .accessibilitySortPriority(1)
        }
        .task {
            guard revealedLayer == 0 else { return }
            guard !reduceMotion else { revealedLayer = 3; return }
            for layer in 1...3 {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) { revealedLayer = layer }
                do { try await Task.sleep(for: .milliseconds(110)) }
                catch { return }
            }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { revealedLayer = 3 }
        }
        .preferredColorScheme(.light)
    }

    private func introductionPoint(_ symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(TodayVisualTheme.growthAccent)
                .frame(width: 24, height: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                    .frame(minHeight: descriptionMinimumHeight, alignment: .topLeading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AssessmentIntroductionDiagram: View {
    // Unscored diagram: node radius carries no personal-state measurement.
    private let dimensions: [LifeDimension] = [.health, .learning, .finance, .relationships, .career, .interests]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width * 0.32, geometry.size.height * 0.4)
            ZStack {
                Circle().fill(.white.opacity(0.6)).frame(width: radius * 2.2)
                    .overlay(Circle().stroke(LivingOSTheme.mist.opacity(0.6), lineWidth: 0.7))
                Path { path in
                    for index in dimensions.indices {
                        path.move(to: center)
                        path.addLine(to: point(index, center: center, radius: radius))
                    }
                }
                .stroke(LivingOSTheme.mist, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                VStack(spacing: 4) {
                    Image(systemName: "sparkle").font(.title2)
                        .foregroundStyle(TodayVisualTheme.growthAccent)
                    Text("此刻的你").font(.caption.weight(.medium))
                }
                .frame(width: 78, height: 78)
                .background(.white, in: Circle())
                .overlay(Circle().stroke(LivingOSTheme.mist.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
                ForEach(Array(dimensions.enumerated()), id: \.element) { index, dimension in
                    HStack(spacing: 5) {
                        Circle().fill(TodayVisualTheme.growthAccent).frame(width: 4, height: 4)
                        Text(dimension == .career ? "主要活动" : dimension == .relationships ? "人际" : dimension.title)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(LivingOSTheme.mist.opacity(0.7), lineWidth: 0.7))
                    .position(point(index, center: center, radius: radius))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func point(_ index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(index) * .pi / 3 - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius * 1.45, y: center.y + sin(angle) * radius)
    }
}

#Preview("自测引导") { AssessmentIntroductionView(onStart: {}) }
#Preview("大字体") {
    AssessmentIntroductionView(onStart: {}).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("减少动态效果") {
    AssessmentIntroductionView(previewReduceMotion: true, onStart: {})
}
#endif
