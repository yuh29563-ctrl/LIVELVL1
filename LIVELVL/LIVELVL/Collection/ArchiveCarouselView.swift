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
        ArchiveCarouselContainerLayout(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        ) {
            GeometryReader { container in
                let layout = ArchiveCarouselLayout.make(containerWidth: container.size.width)
                let cardWidth = layout.cardSize.width
                let captionHeight = ArchiveCarouselLayout.resolvedCaptionHeight(
                    isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                )
                let totalHeight = ArchiveCarouselLayout.resolvedTotalHeight(
                    containerWidth: container.size.width,
                    isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                )

                ZStack(alignment: .top) {
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
                                    let projection = ArchiveCardProjectionStyle.make(
                                        normalizedDistance: distance
                                    )

                                    VStack(spacing: layout.cardCaptionSpacing) {
                                        ZStack(alignment: .bottom) {
                                            ArchiveCardProjection(
                                                cardWidth: cardWidth,
                                                style: projection
                                            )
                                            .offset(
                                                y: projection.castLength + 20
                                            )
                                            .opacity(expandedAwardKey == item.id ? 0 : 1)
                                            .accessibilityHidden(true)
                                            .allowsHitTesting(false)

                                            Button {
                                                if centeredAwardKey == item.id {
                                                    onExpand(item.id)
                                                } else {
                                                    withAnimation(centeringAnimation) {
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
                                            .scaleEffect(transform.scale, anchor: .bottom)
                                            .opacity(expandedAwardKey == item.id ? 0 : transform.opacity)
                                            .rotation3DEffect(
                                                .degrees(transform.yawDegrees),
                                                axis: (x: 0, y: 1, z: 0),
                                                anchor: .bottom,
                                                perspective: 0.58
                                            )
                                            .rotationEffect(
                                                .degrees(transform.rollDegrees),
                                                anchor: .bottom
                                            )
                                            .offset(y: transform.verticalOffset)
                                            .accessibilityFocused(
                                                $focusedCard,
                                                equals: .grid(awardKey: item.id)
                                            )
                                            .accessibilityFocusedValue(centeredAwardKey == item.id)
                                            .accessibilityAdjustableAction { direction in
                                                step(from: index, direction: direction)
                                            }

                                        }
                                        .frame(
                                            width: cardWidth,
                                            height: layout.cardSize.height,
                                            alignment: .bottom
                                        )

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
                                        .offset(y: 8)
                                        .opacity(
                                            ArchiveCarouselCaptionVisibility.opacity(
                                                isExpanded: expandedAwardKey != nil,
                                                normalizedDistance: distance
                                            )
                                        )
                                        .accessibilityHidden(
                                            expandedAwardKey != nil || abs(distance) >= 0.5
                                        )
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
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $centeredAwardKey, anchor: .center)
                    .animation(centeringAnimation, value: centeredAwardKey)
                }
            }
        }
    }

    private var centeringAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.90)
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
        withAnimation(centeringAnimation) {
            centeredAwardKey = destination.awardKey
        }
        focusedCard = destination.focusTarget
    }
}

struct ArchiveSceneLightField: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: LivingOSTheme.canvas, location: 0),
                        .init(color: Color.white.opacity(0.70), location: 0.32),
                        .init(color: LivingOSTheme.mist.opacity(0.38), location: 0.66),
                        .init(color: LivingOSTheme.graphite.opacity(0.055), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.74), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.30),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.58
                )

                RadialGradient(
                    colors: [LivingOSTheme.graphite.opacity(0.045), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.72),
                    startRadius: 0,
                    endRadius: size.width * 0.86
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ArchiveCardProjection: View {
    let cardWidth: CGFloat
    let style: ArchiveCardProjectionStyle

    private var projectionHeight: CGFloat { style.castLength + 20 }

    var body: some View {
        ZStack(alignment: .top) {
            Canvas { context, size in
                let center = size.width / 2
                let startHalfWidth = cardWidth * style.contactWidthRatio * 0.46
                let endCenter = center + style.castHorizontalOffset
                let endHalfWidth = cardWidth * style.penumbraWidthRatio * 0.48
                var cast = Path()
                cast.move(to: CGPoint(x: center - startHalfWidth, y: 2))
                cast.addLine(to: CGPoint(x: center + startHalfWidth, y: 2))
                cast.addLine(to: CGPoint(x: endCenter + endHalfWidth, y: style.castLength))
                cast.addLine(to: CGPoint(x: endCenter - endHalfWidth, y: style.castLength))
                cast.closeSubpath()
                context.fill(
                    cast,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.black.opacity(style.castOpacity),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: center, y: 0),
                        endPoint: CGPoint(x: endCenter, y: style.castLength)
                    )
                )
            }
            .blur(radius: 7)

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(style.penumbraOpacity),
                            Color.black.opacity(style.penumbraOpacity * 0.42),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: cardWidth * style.penumbraWidthRatio * 0.54
                    )
                )
                .frame(
                    width: cardWidth * style.penumbraWidthRatio,
                    height: max(18, style.penumbraHeight + 5)
                )
                .blur(radius: 3.5)

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(style.contactOpacity * 0.82),
                            Color.black.opacity(style.contactOpacity * 0.52),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: cardWidth * style.contactWidthRatio * 0.52
                    )
                )
                .frame(
                    width: cardWidth * style.contactWidthRatio,
                    height: max(10, style.contactHeight + 5)
                )
                .blur(radius: 2.4)
        }
        .frame(width: cardWidth + 120, height: projectionHeight, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ArchiveCarouselContainerLayout: Layout {
    let isAccessibilitySize: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 368
        return CGSize(
            width: width,
            height: ArchiveCarouselLayout.resolvedTotalHeight(
                containerWidth: width,
                isAccessibilitySize: isAccessibilitySize
            )
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}

private struct ArchiveCardCaption: View {
    let presentation: ArchiveCardCaptionPresentation

    var body: some View {
        VStack(spacing: ArchiveCarouselLayout.captionLineSpacing) {
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
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
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
