import SwiftData
import SwiftUI

@MainActor
struct TarotDailyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var states: [TarotDailyState]

    @State private var presentation = TarotDailyPresentationState()
    @State private var errorMessage: String?
    @AccessibilityFocusState private var isRevealHeadingFocused: Bool

    let dayClock: TarotDayClock

    init(dayClock: TarotDayClock? = nil) {
        self.dayClock = dayClock ?? TarotDayClock()
    }

    private var todayIdentifier: String {
        dayClock.dayIdentifier
    }

    private var state: TarotDailyState? {
        states.first {
            $0.singletonKey == "tarot.daily" && $0.dayIdentifier == todayIdentifier
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            TarotVisualTheme.stage.ignoresSafeArea()

            Group {
                if let state {
                    if presentation.showsReading, let selection = selection(in: state) {
                        TarotReadingPage(
                            definition: selection.definition,
                            orientation: selection.orientation,
                            onFinish: { dismiss() }
                        )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                        selectionStage(state: state)
                            .transition(.opacity)
                    }
                } else if let errorMessage {
                    errorState(message: errorMessage)
                } else {
                    ProgressView()
                        .tint(TarotVisualTheme.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("正在准备今日塔罗")
                }
            }

            navigationHeader
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("tarot-daily-view")
        .task(id: todayIdentifier) {
            dayClock.refresh()
            presentation.begin(dayIdentifier: todayIdentifier)
            prepareToday()
        }
    }

    private var navigationHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.09), in: Circle())
            }
            .accessibilityLabel("返回收集")

            Spacer()

            Text("今日塔罗 · DAILY TAROT")
                .font(.system(.caption, design: .serif, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Color.white.opacity(0.64))

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .zIndex(10)
    }

    private func selectionStage(state: TarotDailyState) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 9) {
                    Text(todayTitle)
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(TarotVisualTheme.gold.opacity(0.82))
                    Text(presentation.chosenIndex == nil ? "选择一张牌" : "你选择的牌")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(TarotVisualTheme.paper)
                    Text(
                        presentation.chosenIndex == nil
                            ? "只选择此刻最吸引你的那张。"
                            : "牌面正在显现。"
                    )
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.47))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 58)
                .padding(.top, 126)

                TarotSelectionSpread(
                    state: state,
                    chosenIndex: presentation.chosenIndex,
                    isRevealed: presentation.isCardRevealed,
                    onChoose: choose
                )
                .frame(height: 376)
                .padding(.top, 6)

                if presentation.chosenIndex == nil {
                    Text("三张牌已经固定\n离开后再次进入仍是同一组")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.38))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                } else if let selection = selection(in: state), presentation.isCardRevealed {
                    VStack(spacing: 6) {
                        Text(selection.definition.name)
                            .font(.system(.title2, design: .serif, weight: .semibold))
                        Text("\(selection.definition.romanNumeral) · \(selection.orientation.title)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(TarotVisualTheme.gold)
                    }
                    .foregroundStyle(TarotVisualTheme.paper)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(selection.definition.name)，\(selection.orientation.title)"
                    )
                    .accessibilityFocused($isRevealHeadingFocused)
                    .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 700, alignment: .top)
        }
        .scrollIndicators(.hidden)
    }

    private var todayTitle: String {
        var format = Date.FormatStyle.dateTime
            .month(.wide)
            .day()
            .locale(Locale(identifier: "en_US_POSIX"))
        format.timeZone = dayClock.calendar.timeZone
        return dayClock.currentDate.formatted(format).uppercased()
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 18) {
            Text("今日塔罗暂时无法打开")
                .font(.title3.weight(.semibold))
                .foregroundStyle(TarotVisualTheme.paper)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
            Button("返回收集") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(TarotVisualTheme.gold)
                .foregroundStyle(TarotVisualTheme.stage)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prepareToday() {
        guard state == nil else {
            restorePersistedSelection()
            return
        }
        var random = SystemRandomNumberGenerator()
        do {
            let state = try TarotDailyService.loadOrCreateState(
                in: context,
                now: dayClock.now(),
                calendar: dayClock.calendar,
                random: &random
            )
            restorePersistedSelection(from: state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePersistedSelection(from explicitState: TarotDailyState? = nil) {
        presentation.restore(
            selectedIndex: (explicitState ?? state)?.selectedIndex,
            on: todayIdentifier
        )
    }

    private func choose(_ index: Int) {
        guard presentation.chosenIndex == nil, let state else { return }
        let selectionDayIdentifier = todayIdentifier
        do {
            guard try TarotDailyService.select(
                index: index,
                at: dayClock.now(),
                in: state,
                context: context
            ) else { return }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
            presentation.choose(index: index, on: selectionDayIdentifier)
        }

        guard !reduceMotion else {
            presentation.reveal(on: selectionDayIdentifier)
            presentation.showReading(on: selectionDayIdentifier)
            isRevealHeadingFocused = true
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.48)) {
                presentation.reveal(on: selectionDayIdentifier)
            }
            isRevealHeadingFocused = true
            try? await Task.sleep(for: .milliseconds(920))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.90)) {
                presentation.showReading(on: selectionDayIdentifier)
            }
        }
    }

    private func selection(
        in state: TarotDailyState
    ) -> (definition: TarotCardDefinition, orientation: TarotOrientation)? {
        guard let index = presentation.chosenIndex ?? state.selectedIndex,
              state.candidateCardIDs.indices.contains(index),
              state.candidateOrientations.indices.contains(index),
              let definition = TarotCatalog.definition(id: state.candidateCardIDs[index]) else {
            return nil
        }
        return (definition, state.candidateOrientations[index])
    }
}

private struct TarotSelectionSpread: View {
    let state: TarotDailyState
    let chosenIndex: Int?
    let isRevealed: Bool
    let onChoose: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let baseWidth = min(106, width * 0.265)
            let baseHeight = baseWidth * 1.727

            ZStack {
                ForEach(0..<min(3, state.candidateCardIDs.count), id: \.self) { index in
                    let isChosen = chosenIndex == index
                    let horizontalPosition = chosenIndex == nil
                        ? width * [0.20, 0.50, 0.80][index]
                        : width * 0.50
                    Button {
                        onChoose(index)
                    } label: {
                        tarotCard(index: index, isChosen: isChosen)
                            .frame(width: baseWidth, height: baseHeight)
                            .scaleEffect(isChosen ? 1.48 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(chosenIndex != nil)
                    .position(
                        x: horizontalPosition,
                        y: 184 + (chosenIndex == nil ? [10, -7, 10][index] : 0)
                    )
                    .rotationEffect(.degrees(chosenIndex == nil ? [-6, 0, 6][index] : 0))
                    .opacity(chosenIndex == nil || isChosen ? 1 : 0)
                    .zIndex(isChosen ? 2 : 1)
                    .accessibilityLabel(accessibilityLabel(for: index, isChosen: isChosen))
                }
            }
        }
    }

    @ViewBuilder
    private func tarotCard(index: Int, isChosen: Bool) -> some View {
        if isChosen, isRevealed,
           state.candidateOrientations.indices.contains(index),
           let definition = TarotCatalog.definition(id: state.candidateCardIDs[index]) {
            TarotCardFaceView(
                definition: definition,
                orientation: state.candidateOrientations[index]
            )
            .transition(.opacity)
        } else {
            TarotCardBackView()
        }
    }

    private func accessibilityLabel(for index: Int, isChosen: Bool) -> String {
        guard isChosen, isRevealed,
              state.candidateOrientations.indices.contains(index),
              let definition = TarotCatalog.definition(id: state.candidateCardIDs[index]) else {
            return "未揭晓塔罗牌\(["一", "二", "三"][index])"
        }
        return "\(definition.name)，\(state.candidateOrientations[index].title)"
    }
}

struct TarotCardBackView: View {
    var body: some View {
        Image("TarotRWSBack")
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: .black.opacity(0.36), radius: 12, y: 8)
            .aspectRatio(825.0 / 1425.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct TarotCardFaceView: View {
    let definition: TarotCardDefinition
    let orientation: TarotOrientation

    var body: some View {
        Image(definition.artworkAssetName)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .rotationEffect(orientation == .reversed ? .degrees(180) : .zero)
            .shadow(color: .black.opacity(0.42), radius: 20, y: 13)
            .aspectRatio(0.596, contentMode: .fit)
    }
}

private struct TarotInteractiveCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let definition: TarotCardDefinition
    let orientation: TarotOrientation

    @State private var flip = TarotCardFlipState()
    @State private var hapticTrigger = 0

    var body: some View {
        Button(action: turnCard) {
            Group {
                if reduceMotion {
                    reducedMotionSurface
                } else {
                    TarotCardFlipSurface(
                        definition: definition,
                        orientation: orientation,
                        angle: flip.targetAngle
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(flip.acceptsInput)
        .sensoryFeedback(
            .impact(weight: .light, intensity: 0.65),
            trigger: hapticTrigger
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(flip.showsBack ? "轻点显示牌面" : "轻点显示牌背")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var reducedMotionSurface: some View {
        if flip.showsBack {
            TarotCardBackView()
                .id("tarot-back")
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else {
            TarotCardFaceView(definition: definition, orientation: orientation)
                .id("tarot-face")
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var accessibilityLabel: String {
        if flip.showsBack {
            return "塔罗牌背面"
        }
        return "\(definition.name)，\(orientation.title)"
    }

    private func turnCard() {
        guard !flip.isFlipping else { return }

        if reduceMotion {
            _ = flip.begin()
            withAnimation(.easeInOut(duration: 0.18)) {
                flip.complete()
            }
            hapticTrigger += 1
            return
        }

        withAnimation(.spring(response: 0.60, dampingFraction: 0.79, blendDuration: 0.08)) {
            _ = flip.begin()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(245))
            guard !Task.isCancelled else { return }
            hapticTrigger += 1
            try? await Task.sleep(for: .milliseconds(375))
            guard !Task.isCancelled else { return }
            flip.complete()
        }
    }
}

private struct TarotCardFlipSurface: View, Animatable {
    let definition: TarotCardDefinition
    let orientation: TarotOrientation
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let radians = angle * .pi / 180
        let lift = abs(sin(radians))
        let shadowPulse = TarotCardFlipEffects.shadowPulse(at: angle)

        cardSurface
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.17 * lift),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0.05, y: 1, z: 0),
                perspective: 0.62
            )
            .rotationEffect(.degrees(sin(radians) * 1.4))
            .scaleEffect(1 + lift * 0.025)
            .offset(x: sin(radians) * 7, y: -lift * 6)
            .shadow(
                color: .black.opacity(shadowPulse * 0.20),
                radius: 9 + shadowPulse * 11,
                y: 7 + shadowPulse * 7
            )
    }

    @ViewBuilder
    private var cardSurface: some View {
        if showsBack {
            TarotCardBackView()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        } else {
            TarotCardFaceView(definition: definition, orientation: orientation)
        }
    }

    private var showsBack: Bool {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positiveAngle = normalized >= 0 ? normalized : normalized + 360
        return positiveAngle >= 90 && positiveAngle < 270
    }
}

private struct TarotReadingPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let definition: TarotCardDefinition
    let orientation: TarotOrientation
    let onFinish: () -> Void

    private var reading: TarotReading { definition.reading(for: orientation) }

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = geometry.safeAreaInsets.bottom
            let sheetHeight = dynamicTypeSize.isAccessibilitySize
                ? geometry.size.height * 0.70
                : min(400, geometry.size.height * 0.43)

            ZStack(alignment: .bottom) {
                TarotVisualTheme.stage.ignoresSafeArea()

                TarotInteractiveCard(definition: definition, orientation: orientation)
                    .frame(width: min(174, geometry.size.width * 0.43))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 104)

                readingSheet(bottomPadding: max(30, safeBottom + 14))
                    .frame(height: sheetHeight + safeBottom)
                    .background(TarotVisualTheme.paper)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityAction(.escape, onFinish)
    }

    private func readingSheet(bottomPadding: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(definition.romanNumeral) · MAJOR ARCANA")
                            .font(.system(.caption2, design: .monospaced, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(TarotVisualTheme.wine)
                        Text(definition.name)
                            .font(.system(.title, design: .serif, weight: .semibold))
                        Text(definition.englishName)
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .tracking(1.1)
                            .foregroundStyle(TarotVisualTheme.ink.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(orientation.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TarotVisualTheme.wine)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(TarotVisualTheme.wine.opacity(0.10), in: Capsule())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(definition.name)，\(orientation.title)")

                readingSection(title: "今日主题", body: reading.theme)
                    .padding(.top, 14)
                readingSection(title: "需要留意", body: reading.attention)
                readingSection(title: "行动建议", body: reading.action)

                Button("完成今日解读", action: onFinish)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(TarotVisualTheme.paper)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(TarotVisualTheme.ink, in: RoundedRectangle(cornerRadius: 15))
                    .padding(.top, 12)
                    .padding(.bottom, bottomPadding)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func readingSection(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .frame(width: 72, alignment: .leading)
                .padding(.top, 2)

            Text(body)
                .font(.system(.caption, design: .default))
                .foregroundStyle(TarotVisualTheme.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Divider().overlay(TarotVisualTheme.ink.opacity(0.10))
        }
        .accessibilityElement(children: .combine)
    }
}

private enum TarotVisualTheme {
    static let stage = Color(red: 18 / 255, green: 20 / 255, blue: 25 / 255)
    static let ink = Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)
    static let paper = Color(red: 246 / 255, green: 241 / 255, blue: 225 / 255)
    static let gold = Color(red: 204 / 255, green: 169 / 255, blue: 92 / 255)
    static let wine = Color(red: 109 / 255, green: 41 / 255, blue: 55 / 255)
}

#Preview {
    NavigationStack {
        TarotDailyView()
    }
    .modelContainer(for: TarotDailyState.self, inMemory: true)
}
