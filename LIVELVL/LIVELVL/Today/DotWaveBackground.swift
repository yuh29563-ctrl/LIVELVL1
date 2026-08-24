import SwiftUI

enum DotWaveField {
    static func gridPoints(
        in size: CGSize,
        spacing: CGFloat,
        inset: CGFloat
    ) -> [CGPoint] {
        guard spacing > 0, size.width >= inset, size.height >= inset else { return [] }

        var points: [CGPoint] = []
        var y = inset
        while y <= size.height - inset {
            var x = inset
            while x <= size.width - inset {
                points.append(CGPoint(x: x, y: y))
                x += spacing
            }
            y += spacing
        }
        return points
    }

    static func intensity(at point: CGPoint, phase: Double) -> Double {
        let normalizedPhase = phase - floor(phase)
        let x = Double(point.x)
        let y = Double(point.y)
        let tau = Double.pi * 2
        let bend = 0.085 * sin(tau * (x + normalizedPhase))
            + 0.035 * sin(tau * (2 * x - normalizedPhase))
        let wave = 0.5 + 0.5 * cos(tau * (y + bend - normalizedPhase))
        return wave * wave * (3 - 2 * wave)
    }

    static func phase(
        elapsed: TimeInterval,
        duration: TimeInterval,
        reduceMotion: Bool
    ) -> Double {
        guard !reduceMotion else { return 0.18 }
        guard duration > 0 else { return 0 }
        let remainder = elapsed.truncatingRemainder(dividingBy: duration)
        return (remainder < 0 ? remainder + duration : remainder) / duration
    }
}

struct DotWaveBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 14
    private let inset: CGFloat = 7
    private let cycleDuration: TimeInterval = 10

    var body: some View {
        Group {
            if reduceMotion {
                dotCanvas(phase: DotWaveField.phase(
                    elapsed: 0,
                    duration: cycleDuration,
                    reduceMotion: true
                ))
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    dotCanvas(phase: DotWaveField.phase(
                        elapsed: context.date.timeIntervalSinceReferenceDate,
                        duration: cycleDuration,
                        reduceMotion: false
                    ))
                }
            }
        }
        .background(Color(red: 0.955, green: 0.958, blue: 0.965))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func dotCanvas(phase: Double) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let points = DotWaveField.gridPoints(in: size, spacing: spacing, inset: inset)
            let width = max(size.width, 1)
            let height = max(size.height, 1)

            for point in points {
                let normalizedPoint = CGPoint(x: point.x / width, y: point.y / height)
                let intensity = DotWaveField.intensity(at: normalizedPoint, phase: phase)
                let radius = 0.3 + 1.7 * intensity
                let opacity = 0.025 + 0.19 * intensity
                let dot = CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: dot),
                    with: .color(Color.gray.opacity(opacity))
                )
            }
        }
    }
}
