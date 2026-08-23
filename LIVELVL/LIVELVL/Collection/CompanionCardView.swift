import SwiftUI

struct CompanionCardView: View {
    let definition: CollectibleDefinition
    let stage: CompanionStage

    var body: some View {
        HStack(spacing: 18) {
            PixelSpeciesArtwork(
                definition: definition,
                stage: stage,
                isSilhouette: false
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("正在陪伴")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TodayVisualTheme.graphite)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        companionName
                        stageLabel
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        companionName
                        stageLabel
                    }
                }

                Text(definition.summary)
                    .font(.subheadline)
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.055), radius: 14, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在陪伴，\(definition.name)，\(stage.todayTitle)")
        .accessibilityValue(definition.summary)
    }

    private var companionName: some View {
        Text(definition.name)
            .font(.title3.bold())
            .foregroundStyle(TodayVisualTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var stageLabel: some View {
        Text(stage.todayTitle)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(TodayVisualTheme.graphite)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PixelSpeciesArtwork: View {
    let definition: CollectibleDefinition
    let stage: CompanionStage
    let isSilhouette: Bool

    private var symbolSize: CGFloat {
        switch stage {
        case .juvenile: 42
        case .stageTwo: 50
        case .stageThree: 58
        case .mature: 66
        }
    }

    private var pixelCount: Int {
        switch stage {
        case .juvenile: 1
        case .stageTwo: 2
        case .stageThree, .mature: 3
        }
    }

    private var artworkColor: Color {
        isSilhouette ? TodayVisualTheme.graphite.opacity(0.25) : TodayVisualTheme.ink
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: isSilhouette ? definition.silhouetteSymbolName : definition.symbolName)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(artworkColor)
                .frame(width: symbolSize, height: symbolSize)
                .padding(.bottom, 9)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<pixelCount, id: \.self) { index in
                    Rectangle()
                        .fill(artworkColor.opacity(isSilhouette ? 1 : 0.58 + Double(index) * 0.14))
                        .frame(width: index == 1 ? 5 : 4, height: index == 1 ? 5 : 4)
                }
            }
            .padding(.bottom, 7)
        }
        .frame(width: 92, height: 84)
        .background(
            TodayVisualTheme.cloud,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}

extension CompanionStage {
    var todayTitle: String {
        switch self {
        case .juvenile: "幼体"
        case .stageTwo: "成长中"
        case .stageThree: "渐渐成熟"
        case .mature: "成熟体"
        }
    }
}

#Preview("Companion Hero") {
    CompanionCardView(
        definition: CollectionCatalog.ordinary[0],
        stage: .stageTwo
    )
    .padding()
    .background(TodayVisualTheme.pageBackground)
}

#Preview("Companion Hero Large Text") {
    CompanionCardView(
        definition: CollectionCatalog.ordinary[1],
        stage: .mature
    )
    .padding()
    .background(TodayVisualTheme.pageBackground)
    .environment(\.dynamicTypeSize, .accessibility2)
}
