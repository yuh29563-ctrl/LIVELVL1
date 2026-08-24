import SwiftUI

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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GlassCardSurface(
                media: media,
                style: media == nil ? .standard : .companionFrosted
            ) {
                HStack(alignment: .top, spacing: 18) {
                    PixelSpeciesArtwork(
                        definition: presentation.definition,
                        stage: presentation.stage,
                        isSilhouette: false
                    )
                    .frame(width: 112, height: 132)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("正在陪伴")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TodayVisualTheme.graphite)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(presentation.companionName)
                                .font(.title3.bold())
                            Text(presentation.stageTitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(TodayVisualTheme.graphite)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(presentation.companionName)
                                .font(.title3.bold())
                            Text(presentation.stageTitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(TodayVisualTheme.graphite)
                        }
                    }

                    Text(presentation.definition.summary)
                        .font(.caption)
                        .foregroundStyle(TodayVisualTheme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Lv.\(presentation.level)")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(levelUpFeedback == nil ? TodayVisualTheme.ink : TodayVisualTheme.reward)
                                .scaleEffect(levelPulseScale)
                            Spacer(minLength: 8)
                            Text("\(presentation.currentXP) / \(presentation.requiredXP) XP")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(isRewarding ? TodayVisualTheme.reward : TodayVisualTheme.graphite)
                                .fixedSize(horizontal: true, vertical: false)
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
                        .frame(height: 8)

                        Text("还需 \(presentation.remainingXP) XP 升级")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(TodayVisualTheme.graphite)
                    }
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
            .padding(12)
            .accessibilityLabel(media == nil ? "设置陪伴卡背景图片" : "管理陪伴卡背景图片")
        }
        .padding(.horizontal, GlassCardLayout.horizontalInset)
        .foregroundStyle(TodayVisualTheme.ink)
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
