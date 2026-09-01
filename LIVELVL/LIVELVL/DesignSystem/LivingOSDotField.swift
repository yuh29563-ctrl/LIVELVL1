import SwiftUI

nonisolated struct LivingDotSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated enum LivingDotFieldGeometry {
    static func samples(
        columns: Int,
        rows: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [LivingDotSample] {
        guard columns > 0, rows > 0 else { return [] }

        let normalizedPhase = phase - floor(phase)
        let resolvedPhase = reduceMotion ? 0.18 : normalizedPhase

        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                let x = columns == 1 ? 0.5 : Double(column) / Double(columns - 1)
                let y = rows == 1 ? 0.5 : Double(row) / Double(rows - 1)
                let wave = (sin((x + y + resolvedPhase) * .pi * 2) + 1) / 2
                let seed = Double(((column &* 37) ^ (row &* 101)) % 97) / 97
                let angle = (resolvedPhase + seed) * .pi * 2
                let driftScale = reduceMotion ? 0 : 0.006
                let driftedX = min(1, max(0, x + cos(angle + y * 7) * driftScale))
                let driftedY = min(1, max(0, y + sin(angle * 0.86 + x * 9) * driftScale))

                return LivingDotSample(
                    position: CGPoint(x: driftedX, y: driftedY),
                    opacity: 0.08 + wave * 0.22,
                    diameter: 1 + wave * 0.8
                )
            }
        }
    }
}

struct LivingDotField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    let columns: Int
    let rows: Int
    var color = LivingOSTheme.ink

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let phase = reduceMotion
                ? 0.18
                : timeline.date.timeIntervalSinceReferenceDate / 12.0
            let samples = LivingDotFieldGeometry.samples(
                columns: columns,
                rows: rows,
                phase: phase,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                for sample in samples {
                    let diameter = sample.diameter
                    let origin = CGPoint(
                        x: sample.position.x * size.width - diameter / 2,
                        y: sample.position.y * size.height - diameter / 2
                    )
                    let rect = CGRect(
                        origin: origin,
                        size: CGSize(width: diameter, height: diameter)
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(sample.opacity))
                    )
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }
}
