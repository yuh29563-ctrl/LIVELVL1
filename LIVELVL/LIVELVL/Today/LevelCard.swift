import SwiftUI

struct CompanionJournalNameMetrics: Equatable {
    let pointSize: CGFloat
    let minimumScaleFactor: CGFloat
}

enum CompanionJournalTypography {
    static let handwritingFontName = "LongCang-Regular"
    static let statusPointSize: CGFloat = 20
    static let stagePointSize: CGFloat = 24
    static let summaryPointSize: CGFloat = 20
    static let remainingPointSize: CGFloat = 18

    static func metrics(for name: String) -> CompanionJournalNameMetrics {
        switch name.count {
        case ...4:
            CompanionJournalNameMetrics(pointSize: 56, minimumScaleFactor: 0.82)
        case 5...6:
            CompanionJournalNameMetrics(pointSize: 32, minimumScaleFactor: 0.76)
        default:
            CompanionJournalNameMetrics(pointSize: 24, minimumScaleFactor: 0.68)
        }
    }
}

enum CompanionMediaControlStyle {
    static let photoSymbol = "photo"
    static let animatedPhotoSymbol = "livephoto"
}

struct CompanionJournalComposition: Equatable {
    private static let referenceSize = CGSize(width: 338, height: 376)

    let artworkFrame: CGRect
    let statusFrame: CGRect
    let photoControlFrame: CGRect
    let animatedControlFrame: CGRect
    let titleFrame: CGRect
    let nameFrame: CGRect
    let stageFrame: CGRect
    let summaryFrame: CGRect
    let levelFrame: CGRect
    let xpFrame: CGRect
    let progressFrame: CGRect
    let remainingFrame: CGRect
    let smileFrame: CGRect
    let flowerFrame: CGRect
    let sparklesFrame: CGRect

    var statusOrigin: CGPoint { statusFrame.origin }
    var nameOrigin: CGPoint { nameFrame.origin }
    var stageOrigin: CGPoint { stageFrame.origin }
    var summaryOrigin: CGPoint { summaryFrame.origin }
    var levelOrigin: CGPoint { levelFrame.origin }
    var remainingOrigin: CGPoint { remainingFrame.origin }

    init(in size: CGSize) {
        let scaleX = size.width / Self.referenceSize.width
        let scaleY = size.height / Self.referenceSize.height

        func frame(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: x * scaleX,
                y: y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        artworkFrame = frame(18, 46, 116, 116)
        statusFrame = frame(142, 46, 106, 26)
        photoControlFrame = frame(14, 14, 32, 32)
        animatedControlFrame = frame(292, 14, 32, 32)
        titleFrame = frame(142, 72, 176, 78)
        nameFrame = frame(143, 82, 106, 68)
        stageFrame = frame(252, 116, 52, 28)
        summaryFrame = frame(26, 184, 286, 30)
        levelFrame = frame(26, 252, 86, 36)
        xpFrame = frame(216, 258, 96, 28)
        progressFrame = frame(26, 291, 286, 7)
        remainingFrame = frame(106, 318, 206, 28)
        smileFrame = frame(281, 52, 32, 28)
        flowerFrame = frame(278, 178, 38, 45)
        sparklesFrame = frame(17, 337, 43, 36)
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
    var onChooseAnimatedMedia: () -> Void = {}
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
            GlassCardSurface(
                media: media,
                style: .companionTransparent
            ) {
                CompanionJournalCanvas(
                    presentation: presentation,
                    progress: clampedProgress,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    progressTrackColor: progressTrackColor,
                    media: media,
                    onChooseMedia: onChooseMedia,
                    onRemoveMedia: onRemoveMedia,
                    isRewarding: isRewarding,
                    levelUpFeedback: levelUpFeedback,
                    levelPulseScale: levelPulseScale
                )
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: GlassCardLayout.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            GeometryReader { proxy in
                let composition = CompanionJournalComposition(in: proxy.size)

                ZStack(alignment: .topLeading) {
                    CompanionMediaControlButton(
                        symbol: CompanionMediaControlStyle.photoSymbol,
                        accessibilityLabel: "更换背景图片",
                        action: onChooseMedia
                    )
                    .companionFrame(composition.photoControlFrame)

                    CompanionMediaControlButton(
                        symbol: CompanionMediaControlStyle.animatedPhotoSymbol,
                        accessibilityLabel: "选择背景动图",
                        action: onChooseAnimatedMedia
                    )
                    .companionFrame(composition.animatedControlFrame)
                }
            }
        }
        .padding(.horizontal, GlassCardLayout.horizontalInset)
        .foregroundStyle(primaryTextColor)
        .accessibilityElement(children: .contain)
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

private struct CompanionJournalCanvas: View {
    let presentation: TodayCompanionLevelCardPresentation
    let progress: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let progressTrackColor: Color
    let media: DecodedMedia?
    let onChooseMedia: () -> Void
    let onRemoveMedia: () -> Void
    let isRewarding: Bool
    let levelUpFeedback: Int?
    let levelPulseScale: CGFloat

    private var nameMetrics: CompanionJournalNameMetrics {
        CompanionJournalTypography.metrics(for: presentation.companionName)
    }

    var body: some View {
        GeometryReader { proxy in
            let composition = CompanionJournalComposition(in: proxy.size)

            ZStack(alignment: .topLeading) {
                Menu {
                    Button("更换背景图片", action: onChooseMedia)
                    if media != nil {
                        Button("移除背景图片", role: .destructive, action: onRemoveMedia)
                    }
                } label: {
                    CompanionPolaroidArtwork(
                        definition: presentation.definition,
                        stage: presentation.stage
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(media == nil ? "设置陪伴卡背景图片" : "管理陪伴卡背景图片")
                .frame(
                    width: composition.artworkFrame.width,
                    height: composition.artworkFrame.height
                )
                .position(
                    x: composition.artworkFrame.midX,
                    y: composition.artworkFrame.midY
                )

                CompanionJournalWordmark(
                    text: "正在陪伴",
                    pointSize: CompanionJournalTypography.statusPointSize
                )
                    .foregroundStyle(secondaryTextColor)
                    .companionFrame(composition.statusFrame)

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    CompanionJournalWordmark(
                        text: presentation.companionName,
                        pointSize: nameMetrics.pointSize
                    )
                    .minimumScaleFactor(nameMetrics.minimumScaleFactor)
                    .foregroundStyle(primaryTextColor)
                    .layoutPriority(1)

                    CompanionJournalWordmark(
                        text: presentation.stageTitle,
                        pointSize: CompanionJournalTypography.stagePointSize
                    )
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .companionFrame(composition.titleFrame, alignment: .leading)

                CompanionJournalWordmark(
                    text: presentation.definition.summary,
                    pointSize: CompanionJournalTypography.summaryPointSize
                )
                    .foregroundStyle(secondaryTextColor)
                    .companionFrame(composition.summaryFrame)

                Text("Lv.\(presentation.level)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(
                        levelUpFeedback == nil ? primaryTextColor : TodayVisualTheme.reward
                    )
                    .scaleEffect(levelPulseScale)
                    .companionFrame(composition.levelFrame)

                Text("\(presentation.currentXP) / \(presentation.requiredXP) XP")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isRewarding ? TodayVisualTheme.reward : secondaryTextColor)
                    .companionFrame(composition.xpFrame, alignment: .bottomTrailing)

                GeometryReader { progressProxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(progressTrackColor)
                        Capsule()
                            .fill(isRewarding ? TodayVisualTheme.reward : primaryTextColor)
                            .frame(width: progressProxy.size.width * progress)
                    }
                    .animation(.easeInOut(duration: 0.2), value: isRewarding)
                }
                .companionFrame(composition.progressFrame)

                CompanionJournalWordmark(
                    text: "还需 \(presentation.remainingXP) XP 升级",
                    pointSize: CompanionJournalTypography.remainingPointSize
                )
                .foregroundStyle(secondaryTextColor)
                .companionFrame(composition.remainingFrame)

                CompanionJournalSmile()
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.18))
                    .companionFrame(composition.smileFrame)

                CompanionJournalFlower()
                    .companionFrame(composition.flowerFrame)

                CompanionJournalSparkles()
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.18))
                    .companionFrame(composition.sparklesFrame)
            }
        }
    }
}

private extension View {
    func companionFrame(
        _ frame: CGRect,
        alignment: Alignment = .topLeading
    ) -> some View {
        self
            .frame(width: frame.width, height: frame.height, alignment: alignment)
            .position(x: frame.midX, y: frame.midY)
    }
}

private struct CompanionMediaControlButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(Color.black.opacity(0.78))
                .background(Color.white.opacity(0.88), in: Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct CompanionPolaroidArtwork: View {
    let definition: CollectibleDefinition
    let stage: CompanionStage

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)

            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 0.94, green: 0.95, blue: 0.96))
                .padding(6)

            PixelSpeciesArtwork(
                definition: definition,
                stage: stage,
                isSilhouette: false
            )
            .padding(13)
        }
        .rotationEffect(.degrees(-3))
    }
}

private struct CompanionJournalWordmark: View {
    let text: String
    let pointSize: CGFloat

    var body: some View {
        Text(text)
            .font(.custom(CompanionJournalTypography.handwritingFontName, size: pointSize))
            .lineLimit(1)
            .minimumScaleFactor(0.68)
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
        Canvas { context, size in
            let yellow = Color(red: 1.0, green: 0.82, blue: 0.18)
            let green = Color(red: 0.42, green: 0.68, blue: 0.23)
            let center = CGPoint(x: size.width * 0.38, y: size.height * 0.31)

            for index in 0..<6 {
                let angle = Double(index) * .pi / 3
                let petalCenter = CGPoint(
                    x: center.x + cos(angle) * size.width * 0.16,
                    y: center.y + sin(angle) * size.height * 0.14
                )
                let petal = Path(
                    ellipseIn: CGRect(
                        x: petalCenter.x - size.width * 0.08,
                        y: petalCenter.y - size.height * 0.10,
                        width: size.width * 0.16,
                        height: size.height * 0.20
                    )
                )
                context.fill(petal, with: .color(yellow))
            }

            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                with: .color(.white.opacity(0.94))
            )

            var stem = Path()
            stem.move(to: CGPoint(x: center.x, y: center.y + size.height * 0.10))
            stem.addQuadCurve(
                to: CGPoint(x: size.width * 0.54, y: size.height * 0.94),
                control: CGPoint(x: size.width * 0.40, y: size.height * 0.68)
            )
            context.stroke(stem, with: .color(green), lineWidth: 3)

            let leftLeaf = Path(
                ellipseIn: CGRect(
                    x: size.width * 0.22,
                    y: size.height * 0.65,
                    width: size.width * 0.30,
                    height: size.height * 0.14
                )
            )
            let rightLeaf = Path(
                ellipseIn: CGRect(
                    x: size.width * 0.48,
                    y: size.height * 0.73,
                    width: size.width * 0.30,
                    height: size.height * 0.14
                )
            )
            context.fill(leftLeaf, with: .color(green))
            context.fill(rightLeaf, with: .color(green))
        }
        .rotationEffect(.degrees(-8))
        .accessibilityHidden(true)
    }
}

private struct CompanionJournalSparkles: View {
    var body: some View {
        Canvas { context, size in
            let centers = [
                CGPoint(x: size.width * 0.20, y: size.height * 0.24),
                CGPoint(x: size.width * 0.58, y: size.height * 0.50),
                CGPoint(x: size.width * 0.30, y: size.height * 0.82),
            ]
            let radii = [size.width * 0.14, size.width * 0.10, size.width * 0.08]

            for (center, radius) in zip(centers, radii) {
                var sparkle = Path()
                sparkle.move(to: CGPoint(x: center.x, y: center.y - radius))
                sparkle.addLine(to: CGPoint(x: center.x + radius * 0.32, y: center.y - radius * 0.22))
                sparkle.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                sparkle.addLine(to: CGPoint(x: center.x + radius * 0.30, y: center.y + radius * 0.22))
                sparkle.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                sparkle.addLine(to: CGPoint(x: center.x - radius * 0.30, y: center.y + radius * 0.22))
                sparkle.addLine(to: CGPoint(x: center.x - radius, y: center.y))
                sparkle.addLine(to: CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.22))
                sparkle.closeSubpath()
                context.fill(sparkle, with: .foreground)
            }
        }
        .rotationEffect(.degrees(-7))
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
