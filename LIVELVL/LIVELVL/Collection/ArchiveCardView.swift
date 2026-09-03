import SwiftUI

enum ArchiveCardAccessibility {
    static func value(
        name: String,
        index: Int,
        count: Int,
        isUnseen: Bool,
        sourceTitle: String
    ) -> String {
        let newState = isUnseen ? "，新收藏" : ""
        return "\(name)，第 \(index) 张，共 \(count) 张\(newState)，获得来源 \(sourceTitle)"
    }
}

enum ArchiveCardMetadata {
    static func kindTitle(for kind: CardRewardKind) -> String {
        switch kind {
        case .ordinaryMature: "成熟卡"
        case .hiddenDiscovery: "隐藏发现"
        }
    }
}

nonisolated struct ArchiveOrganismSample: Equatable, Sendable {
    let position: CGPoint
    let opacity: Double
    let diameter: CGFloat
}

nonisolated struct ArchiveOrganismArm: Equatable, Sendable {
    let points: [CGPoint]
}

nonisolated enum ArchiveOrganismGeometry {
    static func arms(
        identifier: String,
        phase: Double,
        reduceMotion: Bool
    ) -> [ArchiveOrganismArm] {
        let seed = stableSeed(identifier)
        let resolvedPhase = reduceMotion ? 0.23 : phase - floor(phase)
        let armCount = 9
        let pointCount = 12

        return (0..<armCount).map { arm in
            let armSeed = unit(seed &+ UInt64(arm + 1) &* 0x9E37_79B9)
            let baseAngle = Double(arm) / Double(armCount) * .pi * 2
                + armSeed * 0.56
            let points = (0..<pointCount).map { index in
                let t = Double(index) / Double(pointCount - 1)
                let pointSeed = unit(seed ^ UInt64(arm * 97 + index * 31 + 7))
                let radius = 0.055 + t * (0.31 + armSeed * 0.08)
                let curl = sin(t * .pi * (1.7 + armSeed) + pointSeed * 1.8)
                    * (0.08 + t * 0.22)
                let dance = reduceMotion
                    ? 0
                    : sin(resolvedPhase * .pi * 2 + t * 5 + armSeed * 4)
                        * 0.018 * t
                let angle = baseAngle + curl + dance
                return CGPoint(
                    x: min(1, max(0, 0.5 + cos(angle) * radius * 0.78)),
                    y: min(1, max(0, 0.47 + sin(angle) * radius))
                )
            }
            return ArchiveOrganismArm(points: points)
        }
    }

    static func samples(
        identifier: String,
        count: Int,
        phase: Double,
        reduceMotion: Bool
    ) -> [ArchiveOrganismSample] {
        guard count > 0 else { return [] }
        let seed = stableSeed(identifier)
        let resolvedPhase = reduceMotion ? 0.23 : phase - floor(phase)

        return (0..<count).map { index in
            let a = unit(seed &+ UInt64(index) &* 0x9E37_79B9)
            let b = unit(seed ^ (UInt64(index + 17) &* 0x85EB_CA6B))
            let c = unit(seed &+ UInt64(index + 91) &* 0xC2B2_AE35)
            let bodyCount = max(1, Int(Double(count) * 0.58))

            let basePosition: CGPoint
            let strength: Double
            if index < bodyCount {
                let radius = pow(a, 0.62) * 0.22
                let angle = b * .pi * 2 + sin(c * .pi * 2) * 0.35
                basePosition = CGPoint(
                    x: 0.5 + cos(angle) * radius,
                    y: 0.47 + sin(angle) * radius * 1.12
                )
                strength = 1 - min(1, radius / 0.24)
            } else {
                let armCount = 9
                let arm = index % armCount
                let armAngle = Double(arm) / Double(armCount) * .pi * 2
                    + unit(seed &+ UInt64(arm) * 41) * 0.52
                let t = Double(index - bodyCount) / Double(max(1, count - bodyCount - 1))
                let radius = 0.12 + t * 0.34
                let curl = sin(t * .pi * 3 + c * 2.2) * 0.28
                basePosition = CGPoint(
                    x: 0.5 + cos(armAngle + curl) * radius * (0.72 + a * 0.22),
                    y: 0.47 + sin(armAngle + curl) * radius
                )
                strength = 0.42 + (1 - t) * 0.42
            }

            let motionAngle = resolvedPhase * .pi * 2 + b * .pi * 2
            let motionScale = reduceMotion ? 0 : 0.0065
            let x = min(1, max(0, basePosition.x + cos(motionAngle) * motionScale))
            let y = min(1, max(0, basePosition.y + sin(motionAngle * 0.87) * motionScale))

            return ArchiveOrganismSample(
                position: CGPoint(x: x, y: y),
                opacity: min(0.96, 0.28 + strength * 0.6 + c * 0.08),
                diameter: 0.8 + strength * 1.9 + a * 0.7
            )
        }
    }

    private static func stableSeed(_ value: String) -> UInt64 {
        value.utf8.reduce(1_469_598_103_934_665_603) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func unit(_ value: UInt64) -> Double {
        var x = value
        x ^= x >> 33
        x &*= 0xff51afd7ed558ccd
        x ^= x >> 33
        return Double(x % 10_000) / 10_000
    }
}

struct ArchiveCardView: View {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition
    let index: Int
    let count: Int

    var body: some View {
        GeometryReader { geometry in
            let cardSize = geometry.size
            let artworkFrame = ArchiveArtworkComposition.frame(in: cardSize)

            ZStack {
                ArchiveOrganismArtwork(identifier: definition.id)
                    .frame(width: artworkFrame.width, height: artworkFrame.height)
                    .position(x: artworkFrame.midX, y: artworkFrame.midY)
                    .blendMode(.multiply)

                VStack {
                    HStack {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LivingOSTheme.ink.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)

                        Spacer()

                        if collectible.isUnseen {
                            Circle()
                                .fill(LivingOSTheme.signal)
                                .frame(width: 6, height: 6)
                                .padding(19)
                                .accessibilityHidden(true)
                        }
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.90), location: 0),
                            .init(color: LivingOSTheme.mist.opacity(0.52), location: 0.58),
                            .init(color: Color.white.opacity(0.72), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.98), location: 0),
                                    .init(color: Color.white.opacity(0.54), location: 0.44),
                                    .init(color: LivingOSTheme.graphite.opacity(0.13), location: 0.84),
                                    .init(color: Color.white.opacity(0.76), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
                        .inset(by: 1.2)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.30),
                                    Color.clear,
                                    Color.black.opacity(0.035)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.6
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.clear, location: 0.76),
                                    .init(color: LivingOSTheme.graphite.opacity(0.018), location: 0.92),
                                    .init(color: LivingOSTheme.ink.opacity(0.095), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.multiply)
                }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
        )
        .contentShape(
            RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            ArchiveCardAccessibility.value(
                name: definition.name,
                index: index,
                count: count,
                isUnseen: collectible.isUnseen,
                sourceTitle: collectible.collectionSourceTitle
            )
        )
        .accessibilityHint("双击展开卡片，上下滑动切换卡片")
    }
}

struct ArchiveOrganismArtwork: View {
    let identifier: String

    var body: some View {
        let phase = 0.23
        let samples = ArchiveOrganismGeometry.samples(
            identifier: identifier,
            count: 340,
            phase: phase,
            reduceMotion: true
        )
        let arms = ArchiveOrganismGeometry.arms(
            identifier: identifier,
            phase: phase,
            reduceMotion: true
        )

        Canvas { context, size in
                for (armIndex, arm) in arms.enumerated() {
                    guard let first = arm.points.first else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in arm.points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    context.stroke(
                        path,
                        with: .color(LivingOSTheme.ink.opacity(0.64)),
                        style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                    )

                    if arm.points.count > 8 {
                        let root = arm.points[6]
                        let tip = arm.points[9]
                        let direction: CGFloat = armIndex.isMultiple(of: 2) ? 1 : -1
                        var branch = Path()
                        branch.move(to: CGPoint(x: root.x * size.width, y: root.y * size.height))
                        branch.addLine(to: CGPoint(
                            x: min(size.width, max(0, tip.x * size.width + direction * size.width * 0.055)),
                            y: min(size.height, max(0, tip.y * size.height - size.height * 0.035))
                        ))
                        context.stroke(
                            branch,
                            with: .color(LivingOSTheme.ink.opacity(0.42)),
                            style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                        )
                    }
                }

                for sample in samples {
                    let diameter = sample.diameter
                    let rect = CGRect(
                        x: sample.position.x * size.width - diameter / 2,
                        y: sample.position.y * size.height - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity))
                    )
                }

                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.47)
                let bodySize = min(size.width, size.height) * 0.26
                let body = CGRect(
                    x: center.x - bodySize / 2,
                    y: center.y - bodySize / 2,
                    width: bodySize,
                    height: bodySize
                )
                context.fill(Path(ellipseIn: body), with: .color(LivingOSTheme.ink.opacity(0.92)))

                for offset in [-0.19, 0.08, 0.25] {
                    let holeSize = bodySize * (offset == 0.25 ? 0.20 : 0.15)
                    let hole = CGRect(
                        x: center.x + bodySize * offset - holeSize / 2,
                        y: center.y - bodySize * (0.16 + offset * 0.18) - holeSize / 2,
                        width: holeSize,
                        height: holeSize
                    )
                    context.fill(Path(ellipseIn: hole), with: .color(Color.white.opacity(0.94)))
                }
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
