import SwiftUI

enum GlassCardLayout {
    static let horizontalInset: CGFloat = 16
    static let contentPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 28
    static let shadowRadius: CGFloat = 18
    static let contentLayerIsAboveGlass = true
}

enum CompanionGlassStyle {
    static let mediaScrimOpacity: Double = 0
    static let frostedMaterialOpacity: Double = 0.88
    static let frostedTintOpacity: Double = 0
    static let textHaloOpacity: Double = 0.82
    static let textHaloRadius: CGFloat = 2.5
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
            } else {
                Color.white.opacity(0.72)
            }
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(GlassCardMaterial(shape: shape))
                .allowsHitTesting(false)
            content
                .padding(GlassCardLayout.contentPadding)
                .shadow(
                    color: .white.opacity(style == .companionFrosted ? CompanionGlassStyle.textHaloOpacity : 0),
                    radius: style == .companionFrosted ? CompanionGlassStyle.textHaloRadius : 0,
                    y: 0
                )
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
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}
