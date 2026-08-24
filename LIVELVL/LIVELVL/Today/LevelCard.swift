import SwiftUI

struct CompanionJournalNameMetrics: Equatable {
    let pointSize: CGFloat
    let minimumScaleFactor: CGFloat
}

struct CompanionJournalGlyphStyle: Equatable {
    let rotationDegrees: Double
    let baselineOffset: CGFloat
}

enum CompanionJournalTypography {
    static func metrics(for name: String) -> CompanionJournalNameMetrics {
        switch name.count {
        case ...4:
            CompanionJournalNameMetrics(pointSize: 38, minimumScaleFactor: 0.82)
        case 5...6:
            CompanionJournalNameMetrics(pointSize: 28, minimumScaleFactor: 0.76)
        default:
            CompanionJournalNameMetrics(pointSize: 21, minimumScaleFactor: 0.68)
        }
    }

    static func glyphStyles(for text: String) -> [CompanionJournalGlyphStyle] {
        let rotations = [-1.8, 1.2, -0.7, 2.1, -1.1]
        let offsets: [CGFloat] = [0.8, -0.6, 1.2, -0.9, 0.3]

        return text.indices.enumerated().map { index, _ in
            CompanionJournalGlyphStyle(
                rotationDegrees: rotations[index % rotations.count],
                baselineOffset: offsets[index % offsets.count]
            )
        }
    }
}

struct TodayCompanionLevelCardPresentation: Equatable {
    let definition: CollectibleDefinition
    let stage: CompanionStage
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int

    var companionName: String { definition.name }
    var stageTitle: String { stage.todayTitle }
    var accessibilityLabel: String {
        "正在陪伴，\(companionName)，\(stageTitle)，等级 \(level)"
    }
    var accessibilityValue: String {
        "当前 \(currentXP)，共需 \(requiredXP)，还差 \(remainingXP) XP"
    }
}

struct TodayCompanionLevelCard: View {
    let presentation: TodayCompanionLevelCardPresentation
    let progress: Double
    var media: DecodedMedia?
    var onChooseMedia: () -> Void = {}
    var onRemoveMedia: () -> Void = {}
    var isRewarding = false
    var levelUpFeedback: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var levelPulseScale = 1.0

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var primaryTextColor: Color {
        media == nil ? TodayVisualTheme.ink : .white
    }

    private var secondaryTextColor: Color {
        media == nil ? TodayVisualTheme.graphite : .white.opacity(0.88)
    }

    private var progressTrackColor: Color {
        media == nil ? TodayVisualTheme.mist : .white.opacity(0.42)
    }

    var body: some View {
        CompanionCardFixedLayout {
            ZStack(alignment: .topTrailing) {
                GlassCardSurface(
                    media: media,
                    style: .companionTransparent
                ) {
                    HStack(alignment: .center, spacing: 14) {
                        CompanionPolaroidArtwork(
                            definition: presentation.definition,
                            stage: presentation.stage
                        )

                        CompanionJournalDetails(
                            presentation: presentation,
                            progress: clampedProgress,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            progressTrackColor: progressTrackColor,
                            isRewarding: isRewarding,
                            levelUpFeedback: levelUpFeedback,
                            levelPulseScale: levelPulseScale
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button("更换背景图片", action: onChooseMedia)
                    if media != nil {
                        Button("移除背景图片", role: .destructive, action: onRemoveMedia)
                    }
                } label: {
                    Image(systemName: media == nil ? "photo" : "photo.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel(media == nil ? "设置陪伴卡背景图片" : "管理陪伴卡背景图片")
                .padding(12)
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: GlassCardLayout.cornerRadius,
                style: .continuous
            )
        )
        .padding(.horizontal, GlassCardLayout.horizontalInset)
        .foregroundStyle(primaryTextColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .task(id: levelUpFeedback) {
            levelPulseScale = 1
            guard levelUpFeedback != nil, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.20).repeatCount(2, autoreverses: true)) {
                levelPulseScale = 1.045
            }
        }
    }
}

private struct CompanionPolaroidArtwork: View {
    let definition: CollectibleDefinition
    let stage: CompanionStage

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.93))
                .shadow(color: .black.opacity(0.20), radius: 5, y: 3)

            PixelSpeciesArtwork(
                definition: definition,
                stage: stage,
                isSilhouette: false
            )
            .padding(.horizontal, 8)
            .padding(.top, 9)
            .padding(.bottom, 17)

            Capsule()
                .fill(Color(red: 0.92, green: 0.82, blue: 0.55).opacity(0.78))
                .frame(width: 38, height: 11)
                .rotationEffect(.degrees(1.5))
                .offset(y: -5)
        }
        .frame(width: 88, height: 102)
        .rotationEffect(.degrees(-2))
        .accessibilityHidden(true)
    }
}

private struct CompanionJournalDetails: View {
    let presentation: TodayCompanionLevelCardPresentation
    let progress: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let progressTrackColor: Color
    let isRewarding: Bool
    let levelUpFeedback: Int?
    let levelPulseScale: CGFloat

    private var nameMetrics: CompanionJournalNameMetrics {
        CompanionJournalTypography.metrics(for: presentation.companionName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                CompanionJournalWordmark(
                    text: "正在陪伴",
                    pointSize: 14,
                    weight: .medium
                )

                Text(presentation.stageTitle)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .overlay {
                        Capsule().stroke(secondaryTextColor.opacity(0.82), lineWidth: 1)
                    }

                CompanionJournalSmile()
                    .frame(width: 22, height: 15)
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.18))

                Spacer(minLength: 34)
            }
            .foregroundStyle(secondaryTextColor)

            HStack(alignment: .center, spacing: 5) {
                ViewThatFits(in: .horizontal) {
                    CompanionJournalWordmark(
                        text: presentation.companionName,
                        pointSize: nameMetrics.pointSize,
                        weight: .semibold
                    )

                    Text(presentation.companionName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(nameMetrics.minimumScaleFactor)
                }

                CompanionJournalFlower()
                    .frame(width: 19, height: 19)
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.18))

                Spacer(minLength: 0)
            }
            .foregroundStyle(primaryTextColor)

            Text(presentation.definition.summary)
                .font(.caption2.weight(.medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Lv.\(presentation.level)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(
                        levelUpFeedback == nil ? primaryTextColor : TodayVisualTheme.reward
                    )
                    .scaleEffect(levelPulseScale)

                Spacer(minLength: 6)

                Text("\(presentation.currentXP) / \(presentation.requiredXP) XP")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isRewarding ? TodayVisualTheme.reward : secondaryTextColor)
                    .fixedSize(horizontal: true, vertical: false)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(progressTrackColor)
                    Capsule()
                        .fill(isRewarding ? TodayVisualTheme.reward : primaryTextColor)
                        .frame(width: proxy.size.width * progress)
                }
                .animation(.easeInOut(duration: 0.2), value: isRewarding)
            }
            .frame(height: 6)

            Text("还需 \(presentation.remainingXP) XP 升级")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
        }
    }
}

private struct CompanionJournalWordmark: View {
    let text: String
    let pointSize: CGFloat
    let weight: Font.Weight

    var body: some View {
        let characters = Array(text)
        let styles = CompanionJournalTypography.glyphStyles(for: text)

        HStack(alignment: .firstTextBaseline, spacing: -1.5) {
            ForEach(characters.indices, id: \.self) { index in
                Text(String(characters[index]))
                    .font(.system(size: pointSize, weight: weight, design: .rounded))
                    .rotationEffect(.degrees(styles[index].rotationDegrees))
                    .offset(y: styles[index].baselineOffset)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct CompanionJournalSmile: View {
    var body: some View {
        Canvas { context, size in
            let lineWidth = max(1.4, size.width * 0.08)
            var smile = Path()
            smile.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.48))
            smile.addQuadCurve(
                to: CGPoint(x: size.width * 0.82, y: size.height * 0.42),
                control: CGPoint(x: size.width * 0.52, y: size.height * 1.02)
            )
            context.stroke(smile, with: .foreground, lineWidth: lineWidth)

            for x in [0.30, 0.69] {
                let eye = Path(
                    ellipseIn: CGRect(
                        x: size.width * x,
                        y: size.height * 0.14,
                        width: lineWidth,
                        height: lineWidth
                    )
                )
                context.fill(eye, with: .foreground)
            }
        }
        .rotationEffect(.degrees(4))
        .accessibilityHidden(true)
    }
}

private struct CompanionJournalFlower: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .frame(width: 5, height: 10)
                    .offset(y: -5)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 5, height: 5)
        }
        .rotationEffect(.degrees(-8))
        .accessibilityHidden(true)
    }
}

struct LevelCard: View {
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let remainingXP: Int
    let progress: Double
    var isRewarding = false
    var levelUpFeedback: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var levelPulseScale = 1.0

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                PixelSproutView()
                    .padding(10)
                    .background(
                        TodayVisualTheme.cloud,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        levelText
                        Spacer(minLength: 16)
                        xpText
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        levelText
                        xpText
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TodayVisualTheme.mist)
                    Capsule()
                        .fill(isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.ink)
                        .frame(width: proxy.size.width * clampedProgress)
                }
                .animation(.easeInOut(duration: 0.2), value: isRewarding)
            }
            .frame(height: 9)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("等级进度")
            .accessibilityValue("等级 \(level)，当前 \(currentXP)，共需 \(requiredXP)，还差 \(remainingXP) XP")

            Text("还需 \(remainingXP) XP 升级")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(TodayVisualTheme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .foregroundStyle(TodayVisualTheme.ink)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 6)
        .task(id: levelUpFeedback) {
            levelPulseScale = 1
            guard levelUpFeedback != nil, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.20).repeatCount(2, autoreverses: true)) {
                levelPulseScale = 1.045
            }
        }
    }

    private var levelText: some View {
        Text("Lv.\(level)")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(levelUpFeedback == nil ? TodayVisualTheme.ink : TodayVisualTheme.reward)
            .scaleEffect(levelPulseScale)
            .animation(.easeInOut(duration: 0.2), value: levelUpFeedback)
    }

    private var xpText: some View {
        Text("\(currentXP) / \(requiredXP) XP")
            .font(.headline.monospacedDigit())
            .foregroundStyle(isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.graphite)
            .animation(.easeInOut(duration: 0.2), value: isRewarding)
            .fixedSize(horizontal: true, vertical: false)
    }
}
