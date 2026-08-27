import SwiftUI

@MainActor
struct ArchiveExpandedView: View {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition
    @Binding var isShowingBack: Bool
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let cardFrame = ArchiveExpandedLayout.cardFrame(in: geometry.size)

            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    cardFaces
                        .frame(
                            width: cardFrame.width,
                            height: cardFrame.height
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius: LivingOSMetrics.archiveCardCornerRadius,
                                style: .continuous
                            )
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), LivingOSTheme.mist.opacity(0.64)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: LivingOSMetrics.archiveCardCornerRadius,
                                    style: .continuous
                                )
                                .stroke(Color.white, lineWidth: 1)
                            }
                        }
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: LivingOSMetrics.archiveCardCornerRadius,
                                style: .continuous
                            )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 24, y: 12)
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: LivingOSMetrics.archiveCardCornerRadius,
                                style: .continuous
                            )
                        )
                        .onTapGesture(perform: flip)
                        .accessibilityFocused($isFocused)

                    Spacer(minLength: 0)
                }
                .padding(.top, cardFrame.minY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(LivingOSTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.72), in: Circle())
                        }
                        .accessibilityLabel("关闭卡片")
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            isFocused = true
        }
    }

    @ViewBuilder
    private var cardFaces: some View {
        if reduceMotion {
            ZStack {
                if isShowingBack {
                    back.transition(.opacity)
                } else {
                    front.transition(.opacity)
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
        VStack(spacing: 12) {
            ArchiveOrganismArtwork(identifier: definition.id)
                .frame(height: 300)
                .padding(.horizontal, 12)

            VStack(spacing: 5) {
                Text(definition.name.uppercased())
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                Text(ArchiveCardMetadata.kindTitle(for: collectible.kind))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                Text(collectible.collectionSourceTitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                Text("获得于 \(collectible.acquiredAt.formatted(date: .numeric, time: .omitted))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
            }
            .padding(.bottom, 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(definition.name)，\(ArchiveCardMetadata.kindTitle(for: collectible.kind))")
        .accessibilityHint("双击查看卡片背面")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { flip() }
    }

    private var back: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(definition.name)
                    .font(.title.bold())
                Text(definition.summary)
                    .foregroundStyle(LivingOSTheme.graphite)
                Rectangle()
                    .fill(LivingOSTheme.mist)
                    .frame(height: 0.5)
                ArchiveDetailRow(title: "类别", value: ArchiveCardMetadata.kindTitle(for: collectible.kind))
                ArchiveDetailRow(title: "获得来源", value: collectible.collectionSourceTitle)
                ArchiveDetailRow(title: "获得原因", value: collectible.reason)
                ArchiveDetailRow(
                    title: "获得时间",
                    value: collectible.acquiredAt.formatted(date: .long, time: .shortened)
                )
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityHint("双击返回卡片正面")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { flip() }
    }

    private func flip() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.34)) {
            isShowingBack.toggle()
        }
    }
}

private struct ArchiveDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)
            Text(value)
                .font(.body)
                .foregroundStyle(LivingOSTheme.ink)
        }
    }
}
