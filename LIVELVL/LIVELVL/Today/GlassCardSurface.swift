import SwiftUI

enum GlassCardLayout {
    static let horizontalInset: CGFloat = 16
    static let contentPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 28
    static let shadowRadius: CGFloat = 18
    static let companionAspectRatio: CGFloat = 2.2
    static let expandedMediaUsesFit = true
    static let contentLayerIsAboveGlass = true
}

enum CompanionGlassStyle {
    static let mediaScrimOpacity: Double = 0
    static let usesTransparentGlass = true
    static let textShadowOpacity: Double = 0.62
    static let textShadowRadius: CGFloat = 2.5
}

enum GlassCardSurfaceStyle: Equatable {
    case standard
    case companionTransparent
}

struct CompanionCardFixedLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? subviews.first?.sizeThatFits(.unspecified).width ?? 0
        return CGSize(width: width, height: width / GlassCardLayout.companionAspectRatio)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }
}

struct GlassCardSurface<Content: View>: View {
    private let media: DecodedMedia?
    private let style: GlassCardSurfaceStyle
    private let content: Content

    init(
        media: DecodedMedia? = nil,
        style: GlassCardSurfaceStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.media = media
        self.style = style
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GlassCardLayout.cornerRadius, style: .continuous)

        Group {
            if style == .companionTransparent {
                Color.clear
                    .background {
                        if let media {
                            AnimatedMediaView(media: media)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else {
                            Color.white.opacity(0.72)
                        }
                    }
                    .overlay {
                        Color.clear
                            .modifier(GlassCardMaterial(shape: shape))
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        content
                            .padding(GlassCardLayout.contentPadding)
                            .shadow(
                                color: .black.opacity(CompanionGlassStyle.textShadowOpacity),
                                radius: CompanionGlassStyle.textShadowRadius,
                                y: 1
                            )
                    }
            } else {
                ZStack {
                    Color.white.opacity(0.72)
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(GlassCardMaterial(shape: shape))
                        .allowsHitTesting(false)
                    content
                        .padding(GlassCardLayout.contentPadding)
                }
            }
        }
        .clipShape(shape)
        .shadow(
            color: .black.opacity(0.10),
            radius: GlassCardLayout.shadowRadius,
            y: 8
        )
    }
}

private struct GlassCardMaterial<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                content.glassEffect(.clear, in: shape)
            }
        } else {
            content.overlay {
                shape.stroke(Color.white.opacity(0.30), lineWidth: 1)
            }
        }
    }
}
