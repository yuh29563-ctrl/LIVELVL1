import SwiftUI

enum GlassCardLayout {
    static let horizontalInset: CGFloat = 16
    static let contentPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 28
    static let shadowRadius: CGFloat = 18
}

enum CompanionGlassStyle {
    static let mediaScrimOpacity: Double = 0.22
    static let frostedMaterialOpacity: Double = 0.72
    static let textShadowOpacity: Double = 0.18
}

enum GlassCardSurfaceStyle: Equatable {
    case standard
    case companionFrosted
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

        ZStack {
            if let media {
                AnimatedMediaView(media: media)
                if style == .companionFrosted {
                    Color.black.opacity(CompanionGlassStyle.mediaScrimOpacity)
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(CompanionGlassStyle.frostedMaterialOpacity)
                }
            } else {
                Color.white.opacity(0.72)
            }
            content
                .padding(GlassCardLayout.contentPadding)
                .shadow(
                    color: .black.opacity(style == .companionFrosted ? CompanionGlassStyle.textShadowOpacity : 0),
                    radius: style == .companionFrosted ? 1.5 : 0,
                    y: style == .companionFrosted ? 1 : 0
                )
        }
        .clipShape(shape)
        .modifier(GlassCardMaterial(shape: shape))
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
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}
