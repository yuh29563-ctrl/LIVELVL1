import SwiftUI

struct LivingOSPageHeader<Trailing: View>: View {
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTitleSize = LivingOSMetrics.pageTitleSize

    let eyebrow: String?
    let title: String
    let metadata: String?
    let trailing: Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        metadata: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.metadata = metadata
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(LivingOSTheme.graphite)
                }

                Text(title)
                    .font(
                        .system(
                            size: LivingOSMetrics.resolvedPageTitleSize(scaledTitleSize),
                            weight: .bold
                        )
                    )
                    .tracking(-2.2)
                    .foregroundStyle(LivingOSTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let metadata, !metadata.isEmpty {
                    Text(metadata)
                        .font(.system(.footnote, design: .monospaced, weight: .medium))
                        .foregroundStyle(LivingOSTheme.graphite)
                }
            }

            Spacer(minLength: 0)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension LivingOSPageHeader where Trailing == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        metadata: String? = nil
    ) {
        self.init(eyebrow: eyebrow, title: title, metadata: metadata) {
            EmptyView()
        }
    }
}
