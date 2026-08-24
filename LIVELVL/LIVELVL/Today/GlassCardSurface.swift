import SwiftUI

enum GlassCardLayout {
    static let horizontalInset: CGFloat = 16
    static let contentPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 28
    static let shadowRadius: CGFloat = 18
}

struct GlassCardSurface<Content: View>: View {
    private let media: DecodedMedia?
    private let content: Content

    init(
        media: DecodedMedia? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.media = media
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GlassCardLayout.cornerRadius, style: .continuous)

        ZStack {
            if let media {
                AnimatedMediaView(media: media)
                    .overlay(Color.black.opacity(0.16))
            } else {
                Color.white.opacity(0.72)
            }
            content
                .padding(GlassCardLayout.contentPadding)
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
