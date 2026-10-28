import SwiftUI

nonisolated enum AssessmentChoiceGeometry {
    static let diameters: [CGFloat] = [34, 31, 28, 25, 28, 31, 34]
    static let minimumWidth: CGFloat = 326

    static func centers(in width: CGFloat) -> [CGFloat]? {
        guard width >= minimumWidth else { return nil }
        // Endpoint buttons retain their full 44pt touch area inside the row.
        let edgeInset = (44 - diameters[0]) / 2
        let gap = (width - edgeInset * 2 - diameters.reduce(0, +)) / 6
        var centers: [CGFloat] = [22]
        for index in 1..<diameters.count {
            centers.append(centers[index - 1] + (diameters[index - 1] + diameters[index]) / 2 + gap)
        }
        return centers
    }
}

struct AssessmentChoiceRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: max(proposal.width ?? AssessmentChoiceGeometry.minimumWidth,
                          AssessmentChoiceGeometry.minimumWidth), height: 44)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let centers = AssessmentChoiceGeometry.centers(in: bounds.width) else { return }
        for (index, subview) in subviews.enumerated() where index < centers.count {
            subview.place(at: CGPoint(x: bounds.minX + centers[index], y: bounds.midY),
                anchor: .center, proposal: ProposedViewSize(width: 44, height: 44))
        }
    }
}
