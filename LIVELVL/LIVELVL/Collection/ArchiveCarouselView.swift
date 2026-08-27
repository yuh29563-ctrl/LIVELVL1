import SwiftUI

@MainActor
struct ArchiveCollectiblePresentation: Identifiable {
    var id: String { collectible.awardKey }
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition
}

@MainActor
struct ArchiveCarouselView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let items: [ArchiveCollectiblePresentation]
    @Binding var centeredAwardKey: String?
    let expandedAwardKey: String?
    let onExpand: (String) -> Void

    private let spacing: CGFloat = 16

    var body: some View {
        GeometryReader { container in
            let cardWidth = min(190, max(176, container.size.width * 0.46))
            let cardHeight: CGFloat = 344

            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        GeometryReader { cardProxy in
                            let frame = cardProxy.frame(in: .named("archive-carousel"))
                            let distance = (frame.midX - container.size.width / 2)
                                / (cardWidth + spacing)
                            let transform = ArchiveCardTransform.make(
                                normalizedDistance: distance,
                                reduceMotion: reduceMotion
                            )

                            Button {
                                if centeredAwardKey == item.id {
                                    onExpand(item.id)
                                } else {
                                    withAnimation(.easeInOut(duration: 0.26)) {
                                        centeredAwardKey = item.id
                                    }
                                }
                            } label: {
                                ArchiveCardView(
                                    collectible: item.collectible,
                                    definition: item.definition,
                                    index: index + 1,
                                    count: items.count
                                )
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(transform.scale)
                            .opacity(expandedAwardKey == item.id ? 0 : transform.opacity)
                            .rotation3DEffect(
                                .degrees(transform.rotationDegrees),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.72
                            )
                            .accessibilityFocusedValue(centeredAwardKey == item.id)
                            .accessibilityAdjustableAction { direction in
                                step(from: index, direction: direction)
                            }
                        }
                        .frame(width: cardWidth, height: cardHeight)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: "archive-carousel")
            .scrollIndicators(.hidden)
            .contentMargins(
                .horizontal,
                max(0, (container.size.width - cardWidth) / 2),
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredAwardKey, anchor: .center)
        }
        .frame(height: 366)
    }

    private func step(from index: Int, direction: AccessibilityAdjustmentDirection) {
        let targetIndex: Int
        switch direction {
        case .increment:
            targetIndex = min(items.count - 1, index + 1)
        case .decrement:
            targetIndex = max(0, index - 1)
        @unknown default:
            return
        }
        guard items.indices.contains(targetIndex) else { return }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.34)) {
            centeredAwardKey = items[targetIndex].id
        }
    }
}

private extension View {
    @ViewBuilder
    func accessibilityFocusedValue(_ isFocused: Bool) -> some View {
        if isFocused {
            self.accessibilityAddTraits(.isSelected)
        } else {
            self
        }
    }
}
