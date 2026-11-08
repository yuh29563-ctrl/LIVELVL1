import SwiftUI
import UIKit

struct GrowthCardArtwork: View {
    let collectibleID: String
    var stage: CompanionStage = .mature
    @State private var image: UIImage?
    private static let provider = try? BundledCompanionArtworkProvider()

    private var request: CompanionArtworkID {
        CompanionArtworkID(collectibleID: collectibleID, stage: stage)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "sparkles").resizable().scaledToFit()
                    .foregroundStyle(LivingOSTheme.graphite.opacity(0.35))
                    .padding(20)
            }
        }
        .accessibilityHidden(true)
        .task(id: request) {
            image = nil
            guard let provider = Self.provider else { return }
            let payload = try? await provider.payload(for: request)
            guard !Task.isCancelled else { return }
            image = payload.flatMap { UIImage(data: $0.data) }
        }
    }
}
