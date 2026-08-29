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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let items: [ArchiveCollectiblePresentation]
    @Binding var centeredAwardKey: String?
    let expandedAwardKey: String?
    @AccessibilityFocusState.Binding var focusedCard: CollectionCardFocusTarget?
    let onExpand: (String) -> Void

    var body: some View {
        GeometryReader { container in
            let layout = ArchiveCarouselLayout.make(containerWidth: container.size.width)
            let cardWidth = layout.cardSize.width
            let captionHeight = ArchiveCarouselLayout.resolvedCaptionHeight(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let totalHeight = layout.cardSize.height + layout.cardCaptionSpacing + captionHeight

            ScrollView(.horizontal) {
                LazyHStack(spacing: layout.cardSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        GeometryReader { cardProxy in
                            let frame = cardProxy.frame(in: .named("archive-carousel"))
                            let distance = (frame.midX - container.size.width / 2)
                                / (cardWidth + layout.cardSpacing)
                            let transform = ArchiveCardTransform.make(
                                normalizedDistance: distance,
                                reduceMotion: reduceMotion
                            )

                            VStack(spacing: layout.cardCaptionSpacing) {
                                Button {
                                    if centeredAwardKey == item.id {
                                        onExpand(item.id)
                                    } else if reduceMotion {
                                        centeredAwardKey = item.id
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
                                .frame(width: cardWidth, height: layout.cardSize.height)
                                .scaleEffect(transform.scale)
                                .opacity(expandedAwardKey == item.id ? 0 : transform.opacity)
                                .rotation3DEffect(
                                    .degrees(transform.yawDegrees),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.58
                                )
                                .rotationEffect(.degrees(transform.rollDegrees))
                                .offset(y: transform.verticalOffset)
                                .accessibilityFocused(
                                    $focusedCard,
                                    equals: .grid(awardKey: item.id)
                                )
                                .accessibilityFocusedValue(centeredAwardKey == item.id)
                                .accessibilityAdjustableAction { direction in
                                    step(from: index, direction: direction)
                                }

                                ArchiveCardCaption(
                                    presentation: ArchiveCardCaptionPresentation(
                                        name: item.definition.name,
                                        kindTitle: ArchiveCardMetadata.kindTitle(
                                            for: item.collectible.kind
                                        ),
                                        sourceTitle: item.collectible.collectionSourceTitle,
                                        awardKey: item.collectible.awardKey,
                                        acquiredAt: item.collectible.acquiredAt,
                                        calendar: .current
                                    )
                                )
                                .frame(height: captionHeight, alignment: .top)
                                .opacity(max(0, 1 - abs(distance) * 2.4))
                                .accessibilityHidden(abs(distance) >= 0.5)
                            }
                            .frame(width: cardWidth, height: totalHeight, alignment: .top)
                            .zIndex(1 - abs(distance))
                        }
                        .frame(width: cardWidth, height: totalHeight)
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
        .frame(
            height: ArchiveCarouselLayout.make(containerWidth: 368).cardSize.height
                + ArchiveCarouselLayout.make(containerWidth: 368).cardCaptionSpacing
                + ArchiveCarouselLayout.resolvedCaptionHeight(
                    isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                )
        )
    }

    private func step(from index: Int, direction: AccessibilityAdjustmentDirection) {
        let increment: Bool
        switch direction {
        case .increment:
            increment = true
        case .decrement:
            increment = false
        @unknown default:
            return
        }
        guard let destination = ArchiveAccessibilityNavigation.destination(
            awardKeys: items.map(\.id),
            from: index,
            increment: increment
        ) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.34)) {
            centeredAwardKey = destination.awardKey
        }
        focusedCard = destination.focusTarget
    }
}

private struct ArchiveCardCaption: View {
    let presentation: ArchiveCardCaptionPresentation

    var body: some View {
        VStack(spacing: 8) {
            Text(presentation.title)
                .font(.system(LivingOSTypography.archiveCaptionTitle, design: .monospaced, weight: .medium))
                .foregroundStyle(LivingOSTheme.ink)

            Text(presentation.kindTitle)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)

            Text(presentation.levelText)
                .font(.system(.footnote, design: .monospaced, weight: .medium))
                .foregroundStyle(LivingOSTheme.ink)

            Rectangle()
                .fill(LivingOSTheme.graphite.opacity(0.36))
                .frame(width: 14, height: 0.5)

            Text(presentation.acquiredText)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(presentation.title)，\(presentation.kindTitle)，\(presentation.levelText)，\(presentation.acquiredText)"
        )
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
