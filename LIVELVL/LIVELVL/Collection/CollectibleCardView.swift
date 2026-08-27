import SwiftUI

@MainActor
struct CollectibleCardView: View {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition

    var body: some View {
        VStack(spacing: 12) {
            PixelSpeciesArtwork(
                definition: definition,
                stage: .mature,
                isSilhouette: false
            )
            .frame(maxHeight: .infinity)

            VStack(spacing: 4) {
                Text(definition.name)
                    .font(.headline)
                    .foregroundStyle(TodayVisualTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(collectible.collectionSourceTitle)
                    .font(.caption)
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayVisualTheme.mist.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(collectible.accessibilityDescription(for: definition))
        .accessibilityHint("双击放大卡片")
    }
}

@MainActor
struct FeaturedCollectibleCardView: View {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition

    var body: some View {
        HStack(spacing: 18) {
            PixelSpeciesArtwork(
                definition: definition,
                stage: .mature,
                isSilhouette: false
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("最近获得")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TodayVisualTheme.graphite)

                Text(definition.name)
                    .font(.title3.bold())
                    .foregroundStyle(TodayVisualTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(collectible.reason)
                    .font(.subheadline)
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .lineLimit(2)
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
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("最近获得，\(collectible.accessibilityDescription(for: definition))")
        .accessibilityHint("双击放大卡片")
    }
}

@MainActor
struct ExpandedCollectibleCardOverlay: View {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition
    @Binding var isShowingBack: Bool
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isCardFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(0.32)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)

                card
                    .frame(
                        width: min(geometry.size.width - 44, 370),
                        height: min(geometry.size.height - 76, 590)
                    )
                    .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            isCardFocused = true
        }
    }

    private var card: some View {
        ZStack(alignment: .topTrailing) {
            cardFaces
                .background(
                    Color.white,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.16), radius: 26, y: 12)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture(perform: flip)
                .accessibilityFocused($isCardFocused)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .padding(16)
            }
            .accessibilityLabel("关闭卡片")
        }
    }

    @ViewBuilder
    private var cardFaces: some View {
        if reduceMotion {
            ZStack {
                if isShowingBack {
                    back
                        .transition(.opacity)
                } else {
                    front
                        .transition(.opacity)
                }
            }
        } else {
            ZStack {
                front
                    .opacity(isShowingBack ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isShowingBack ? -180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .allowsHitTesting(!isShowingBack)
                    .accessibilityHidden(isShowingBack)

                back
                    .opacity(isShowingBack ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isShowingBack ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .allowsHitTesting(isShowingBack)
                    .accessibilityHidden(!isShowingBack)
            }
        }
    }

    private var front: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(collectible.collectionSourceTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TodayVisualTheme.graphite)

                PixelSpeciesArtwork(
                    definition: definition,
                    stage: .mature,
                    isSilhouette: false
                )
                .scaleEffect(1.65)
                .padding(.vertical, 30)

                VStack(spacing: 10) {
                    Text(definition.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(TodayVisualTheme.ink)
                        .multilineTextAlignment(.center)

                    Text(definition.summary)
                        .font(.body)
                        .foregroundStyle(TodayVisualTheme.graphite)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label("轻点卡片查看背面", systemImage: "rotate.3d")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TodayVisualTheme.graphite)
            }
            .frame(maxWidth: .infinity, minHeight: 510)
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(collectible.accessibilityDescription(for: definition))
        .accessibilityHint("双击查看卡片背面")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            flip()
        }
    }

    private var back: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(definition.name)
                        .font(.title.bold())
                        .foregroundStyle(TodayVisualTheme.ink)

                    Text(definition.summary)
                        .font(.subheadline)
                        .foregroundStyle(TodayVisualTheme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                CardDetailRow(title: "类别", value: collectible.collectionKindTitle)
                CardDetailRow(title: "获得来源", value: collectible.collectionSourceTitle)
                CardDetailRow(
                    title: "获得时间",
                    value: collectible.acquiredAt.formatted(date: .long, time: .shortened)
                )
                CardDetailRow(title: "获得原因", value: collectible.reason)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("详细介绍")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TodayVisualTheme.graphite)
                    Text(definition.details)
                        .font(.body)
                        .foregroundStyle(TodayVisualTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if definition.kind == .ordinary {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("成长阶段")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TodayVisualTheme.graphite)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                ForEach(Self.ordinaryStageLabels, id: \.self) { label in
                                    StageLabel(title: label)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Self.ordinaryStageLabels, id: \.self) { label in
                                    StageLabel(title: label)
                                }
                            }
                        }
                    }
                }

                Label("轻点卡片返回正面", systemImage: "rotate.3d")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityHint("双击返回卡片正面")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            flip()
        }
    }

    private func flip() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.5)) {
            isShowingBack.toggle()
        }
        isCardFocused = true
    }

    private static let ordinaryStageLabels = ["幼体", "第二形态", "第三形态", "成熟体"]
}

private struct CardDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TodayVisualTheme.graphite)
            Text(value)
                .font(.body)
                .foregroundStyle(TodayVisualTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StageLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(TodayVisualTheme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                TodayVisualTheme.cloud,
                in: Capsule()
            )
            .fixedSize(horizontal: true, vertical: true)
    }
}

extension OwnedCollectible {
    var collectionKindTitle: String {
        kind == .ordinaryMature ? "普通物种" : "隐藏物种"
    }

    var collectionSourceTitle: String {
        kind == .ordinaryMature ? "陪伴成熟" : "隐藏发现"
    }

    func accessibilityDescription(for definition: CollectibleDefinition) -> String {
        "\(definition.name)，\(collectionKindTitle)，获得来源，\(collectionSourceTitle)，获得原因，\(reason)"
    }
}
