import SwiftUI

enum GlassCardLayout {
    static let horizontalInset: CGFloat = 16
    static let contentPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 28
    static let shadowRadius: CGFloat = 18
    static let companionAspectRatio: CGFloat = 0.9
    static let contentLayerIsAboveGlass = true
}

enum CompanionGlassStyle {
    static let mediaScrimOpacity: Double = 0
    static let usesTransparentGlass = false
    static let textShadowOpacity: Double = 0.62
    static let textShadowRadius: CGFloat = 2.5
}

enum LifeStateGlassStyle {
    static let usesFrostedMaterial = true
    static let usesDarkSurface = true
    static let materialOpacity: Double = 1
    static let gradientOpacity: Double = 0.90
    static let topLuminance: Double = 0.20
    static let middleWarmRed: Double = 0.17
    static let middleWarmBlue: Double = 0.12
    static let bottomLuminance: Double = 0.08
    static let dotSurfaceOpacity: Double = 0.62
    static let borderOpacity: Double = 0.28
    static let borderWidth: CGFloat = 1
    static let highlightOpacity: Double = 0.34
}

enum GlassCardSurfaceStyle: Equatable {
    case standard
    case companionTransparent
    case lifeStateDotWave
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
                        content
                            .shadow(
                                color: .black.opacity(CompanionGlassStyle.textShadowOpacity),
                                radius: CompanionGlassStyle.textShadowRadius,
                                y: 1
                            )
                    }
            } else if style == .lifeStateDotWave {
                ZStack {
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(LifeStateGlassStyle.materialOpacity)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(
                                        color: Color(
                                            red: LifeStateGlassStyle.topLuminance,
                                            green: LifeStateGlassStyle.topLuminance,
                                            blue: LifeStateGlassStyle.topLuminance + 0.01
                                        ),
                                        location: 0
                                    ),
                                    .init(
                                        color: Color(
                                            red: LifeStateGlassStyle.middleWarmRed,
                                            green: 0.145,
                                            blue: LifeStateGlassStyle.middleWarmBlue
                                        ),
                                        location: 0.48
                                    ),
                                    .init(
                                        color: Color(
                                            red: LifeStateGlassStyle.bottomLuminance,
                                            green: LifeStateGlassStyle.bottomLuminance,
                                            blue: LifeStateGlassStyle.bottomLuminance + 0.01
                                        ),
                                        location: 1
                                    ),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottom
                            )
                        )
                        .opacity(LifeStateGlassStyle.gradientOpacity)
                    DotWaveBackground(appearance: .dark)
                        .opacity(LifeStateGlassStyle.dotSurfaceOpacity)
                    content
                        .padding(GlassCardLayout.contentPadding)
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(LifeStateGlassStyle.highlightOpacity),
                                Color.white.opacity(LifeStateGlassStyle.borderOpacity * 0.35),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: LifeStateGlassStyle.borderWidth
                    )
                    .allowsHitTesting(false)
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
