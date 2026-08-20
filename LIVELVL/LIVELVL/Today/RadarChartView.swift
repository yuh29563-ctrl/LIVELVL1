import SwiftUI

enum RadarGeometry {
    static func points(
        values: LifeStateValues,
        center: CGPoint,
        radius: CGFloat
    ) -> [CGPoint] {
        LifeDimension.allCases.enumerated().map { index, dimension in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
            let normalized = CGFloat(min(10.0, max(1.0, values[dimension])) / 10.0)
            return CGPoint(
                x: center.x + cos(angle) * radius * normalized,
                y: center.y + sin(angle) * radius * normalized
            )
        }
    }

    static func path(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

struct RadarPulse: Identifiable, Equatable {
    let id = UUID()
    let dimension: LifeDimension
}

struct RadarChartView: View {
    let official: LifeStateValues
    let projected: LifeStateValues
    let pulse: RadarPulse?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var labelMargin: CGFloat = 24
    @State private var pulsingDimension: LifeDimension?
    @State private var markerScale = 1.0

    private let projectedColor = Color(red: 0.64, green: 0.48, blue: 0.92)

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = max(
                0,
                min(proxy.size.width, proxy.size.height) / 2 - labelMargin - 12
            )
            let fullPoints = RadarGeometry.points(
                values: LifeStateValues(repeating: 10),
                center: center,
                radius: radius
            )
            let projectedPoints = RadarGeometry.points(
                values: projected,
                center: center,
                radius: radius
            )
            let projectedAnimation: Animation? = reduceMotion
                ? nil
                : .easeInOut(duration: 0.25)

            ZStack {
                ForEach([2.0, 4.0, 6.0, 8.0, 10.0], id: \.self) { score in
                    RadarGeometry.path(points: RadarGeometry.points(
                        values: LifeStateValues(repeating: score),
                        center: center,
                        radius: radius
                    ))
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }

                ForEach(Array(fullPoints.enumerated()), id: \.offset) { _, point in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                }

                RadarPolygonShape(values: official, radius: radius)
                    .fill(Color.indigo.opacity(0.14))

                RadarPolygonShape(values: official, radius: radius)
                    .stroke(
                        Color.indigo,
                        style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)
                    )

                RadarPolygonShape(values: projected, radius: radius)
                    .stroke(
                        projectedColor,
                        style: StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [6, 5]
                        )
                    )
                    .animation(projectedAnimation, value: projected)

                ForEach(Array(LifeDimension.allCases.enumerated()), id: \.element) { index, dimension in
                    Circle()
                        .fill(projectedColor)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dimension == pulsingDimension ? markerScale : 1)
                        .position(projectedPoints[index])
                        .animation(projectedAnimation, value: projected)
                }

                ForEach(Array(LifeDimension.allCases.enumerated()), id: \.element) { index, dimension in
                    let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
                    Text(dimension.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .position(
                            x: center.x + cos(angle) * (radius + labelMargin),
                            y: center.y + sin(angle) * (radius + labelMargin)
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("最近十五天生命状态雷达图")
        .accessibilityValue(accessibilityValue)
        .task(id: pulse?.id) {
            markerScale = 1
            pulsingDimension = pulse?.dimension
            guard pulse != nil, !reduceMotion else {
                return
            }

            // Let the projected polygon finish its 0.25-second transition first.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.175)) {
                markerScale = 1.28
            }
            try? await Task.sleep(for: .milliseconds(175))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.175)) {
                markerScale = 1
            }
        }
    }

    private var accessibilityValue: String {
        let dimensions = LifeDimension.allCases.map { dimension in
            let delta = projected[dimension] - official[dimension]
            let deltaText = abs(delta) >= 0.05
                ? "，待结算\(delta >= 0 ? "+" : "")\(formatted(delta))"
                : ""
            return "\(dimension.title) \(formatted(official[dimension]))\(deltaText)"
        }
        return (["综合状态 \(formatted(official.average))"] + dimensions)
            .joined(separator: "；")
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

private struct RadarPolygonShape: Shape {
    var values: LifeStateValues
    let radius: CGFloat

    typealias Pair = AnimatablePair<CGFloat, CGFloat>
    typealias Quartet = AnimatablePair<Pair, Pair>

    var animatableData: AnimatablePair<Quartet, Pair> {
        get {
            AnimatablePair(
                AnimatablePair(
                    AnimatablePair(CGFloat(values.health), CGFloat(values.learning)),
                    AnimatablePair(CGFloat(values.career), CGFloat(values.finance))
                ),
                AnimatablePair(CGFloat(values.relationships), CGFloat(values.interests))
            )
        }
        set {
            values.health = Double(newValue.first.first.first)
            values.learning = Double(newValue.first.first.second)
            values.career = Double(newValue.first.second.first)
            values.finance = Double(newValue.first.second.second)
            values.relationships = Double(newValue.second.first)
            values.interests = Double(newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        RadarGeometry.path(points: RadarGeometry.points(
            values: values,
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius
        ))
    }
}
