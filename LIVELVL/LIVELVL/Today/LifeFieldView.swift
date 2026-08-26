import SwiftUI

struct LifeFieldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = LifeFieldSelectionState()

    let summary: LifeStateSummary

    private var nodes: [LifeFieldNodePresentation] {
        LifeFieldNodePresentation.make(summary: summary)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LivingDotField(columns: 34, rows: 45)
                    .opacity(0.72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)

                LifeFieldOutline()
                    .stroke(LivingOSTheme.graphite.opacity(0.15), lineWidth: 0.7)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 52)

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    LifeFieldNode(
                        value: node,
                        isSelected: selection.selectedDimension == node.dimension,
                        reduceMotion: reduceMotion,
                        action: {
                            withAnimation(
                                reduceMotion
                                    ? .easeInOut(duration: 0.2)
                                    : .spring(response: 0.34, dampingFraction: 0.82)
                            ) {
                                selection.toggle(node.dimension)
                            }
                        }
                    )
                    .frame(width: nodeWidth(for: index), alignment: nodeAlignment(for: index))
                    .position(nodePosition(for: index, in: size))
                    .zIndex(selection.selectedDimension == node.dimension ? 2 : 1)
                }
            }
        }
        .frame(minHeight: 470, idealHeight: 520, maxHeight: 560)
        .onChange(of: nodes.map(\.dimension)) { _, dimensions in
            selection.reconcile(available: Set(dimensions))
        }
    }

    private func nodePosition(for index: Int, in size: CGSize) -> CGPoint {
        let normalized: CGPoint
        switch index {
        case 0: normalized = CGPoint(x: 0.50, y: 0.10)
        case 1: normalized = CGPoint(x: 0.84, y: 0.30)
        case 2: normalized = CGPoint(x: 0.84, y: 0.69)
        case 3: normalized = CGPoint(x: 0.50, y: 0.90)
        case 4: normalized = CGPoint(x: 0.16, y: 0.69)
        default: normalized = CGPoint(x: 0.16, y: 0.30)
        }
        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func nodeWidth(for index: Int) -> CGFloat {
        index == 0 || index == 3 ? 180 : 132
    }

    private func nodeAlignment(for index: Int) -> Alignment {
        switch index {
        case 1, 2: .trailing
        case 4, 5: .leading
        default: .center
        }
    }
}

private struct LifeFieldNode: View {
    let value: LifeFieldNodePresentation
    let isSelected: Bool
    let reduceMotion: Bool
    let action: () -> Void

    private var signedDelta: String {
        value.delta > 0 ? "+\(value.delta)" : "\(value.delta)"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                VStack(spacing: 0) {
                    Text(value.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(value.displayValue, format: .number)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(LivingOSTheme.graphite)
                }

                ZStack {
                    Circle()
                        .stroke(
                            LivingOSTheme.graphite.opacity(isSelected ? 0.36 : 0.14),
                            lineWidth: 0.8
                        )
                        .frame(width: 38, height: 38)

                    Circle()
                        .fill(LivingOSTheme.ink)
                        .frame(width: isSelected ? 20 : 17, height: isSelected ? 20 : 17)

                    if isSelected {
                        Circle()
                            .fill(LivingOSTheme.signal)
                            .frame(width: 5, height: 5)
                            .offset(x: 16, y: -15)
                            .accessibilityHidden(true)
                    }
                }

                if isSelected {
                    VStack(spacing: 2) {
                        Text("NEXT \(value.projectedDisplayValue)  \(signedDelta)")
                            .foregroundStyle(value.delta == 0 ? LivingOSTheme.graphite : LivingOSTheme.ink)
                        Text(value.sourceText)
                        Text(value.assessmentText)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
                }
            }
            .foregroundStyle(LivingOSTheme.ink)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value.title)
        .accessibilityValue(
            "当前 \(value.displayValue)，预测 \(value.projectedDisplayValue)，\(value.sourceText)，\(value.assessmentText)"
        )
        .accessibilityHint(isSelected ? "轻点收起状态" : "轻点查看具体状态")
    }
}

private struct LifeFieldOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.75),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75),
            CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25)
        ]

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }
}
