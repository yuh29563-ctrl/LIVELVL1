import SwiftUI

struct AnimatedMediaView: View {
    let media: DecodedMedia

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        if media.frames.isEmpty {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 0.05)) { context in
                let index = Self.frameIndex(
                    elapsed: context.date.timeIntervalSince(startDate),
                    frames: media.frames,
                    reduceMotion: reduceMotion
                )
                Image(uiImage: media.frames[index].image)
                    .resizable()
                    .scaledToFill()
            }
            .onChange(of: media.frames.count) { _, _ in
                startDate = Date()
            }
        }
    }

    static func frameIndex(
        elapsed: TimeInterval,
        frames: [DecodedMediaFrame],
        reduceMotion: Bool
    ) -> Int {
        guard !frames.isEmpty, !reduceMotion, frames.count > 1 else { return 0 }
        let totalDuration = frames.reduce(0) { $0 + max($1.duration, 0.1) }
        guard totalDuration > 0 else { return 0 }
        var remaining = elapsed.truncatingRemainder(dividingBy: totalDuration)
        for (index, frame) in frames.enumerated() {
            let duration = max(frame.duration, 0.1)
            if remaining < duration { return index }
            remaining -= duration
        }
        return frames.count - 1
    }
}
