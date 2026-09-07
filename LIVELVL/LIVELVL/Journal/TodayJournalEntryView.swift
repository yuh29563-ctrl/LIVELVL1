import SwiftUI

struct TodayJournalEntryPresentation: Equatable, Sendable {
    let title = "THE NOTE"
    let subtitle = "记录今天留下的痕迹"
    let accessibilityLabel = "日记本，记录今天留下的痕迹"
    let accessibilityIdentifier = "today-journal-entry"
    let minimumTapHeight: CGFloat = 44
}

struct TodayJournalEntryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presentation: TodayJournalEntryPresentation
    let onOpen: () -> Void

    init(
        presentation: TodayJournalEntryPresentation = TodayJournalEntryPresentation(),
        onOpen: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onOpen = onOpen
    }

    var body: some View {
        Button(action: activate) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleCard
                } else {
                    referenceCard
                }
            }
            .frame(maxWidth: .infinity, minHeight: presentation.minimumTapHeight)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
    }

    func activate() {
        onOpen()
    }

    // Reference card bounds are 1826 × 430 in the 2048-wide composition.
    // Keep one scale for the artwork, typography, bevels and control placement.
    private var referenceCard: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 1826
            ZStack(alignment: .topLeading) {
                JournalCardSurface(cornerRadius: 80)

                JournalBookArtwork()

                VStack(alignment: .leading, spacing: 14) {
                    Text(presentation.title)
                        .font(.custom("HelveticaNeue-Medium", size: 90))
                        .tracking(1)
                        .foregroundStyle(Color.black)
                    Text(presentation.subtitle)
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(Color(white: 0.59))
                }
                .fixedSize()
                .offset(x: 720, y: 128)

                JournalEntryArrow()
                    .frame(width: 190, height: 190)
                    .offset(x: 1560, y: 120)

                Circle()
                    .fill(TodayVisualTheme.growthAccent)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Circle().stroke(.white.opacity(0.2), lineWidth: 2)
                    }
                    .offset(x: 1730, y: 84)
            }
            .frame(width: 1826, height: 430)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(1826.0 / 430, contentMode: .fit)
    }

    private var accessibleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(presentation.title).font(.title2.weight(.medium))
                Spacer(minLength: 8)
                Image(systemName: "arrow.right").font(.title2)
            }
            Text(presentation.subtitle)
                .font(.body)
                .foregroundStyle(LivingOSTheme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(LivingOSTheme.ink)
        .padding(20)
        .background { JournalCardSurface(cornerRadius: 18) }
    }
}

private struct JournalBookArtwork: View {
    var body: some View {
        // Display only the reference's book and particles. The card, copy and
        // arrow are native views; soft edges blend the artwork into the surface.
        Image("JournalBookReference")
            .resizable()
            .interpolation(.high)
            .frame(width: 2048, height: 2048.0 / 3)
            .offset(x: -111, y: -119)
            .frame(width: 710, height: 430, alignment: .topLeading)
            .clipped()
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .accessibilityHidden(true)
    }
}

private struct JournalCardSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [
                Color.white.opacity(0.98),
                LivingOSTheme.surface,
                Color.white.opacity(0.96),
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: .black.opacity(0.065), radius: cornerRadius * 0.42,
                    x: 0, y: cornerRadius * 0.28)
            .shadow(color: .black.opacity(0.025), radius: cornerRadius * 0.12,
                    x: 0, y: cornerRadius * 0.10)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [
                    .white.opacity(0.98), .white.opacity(0.28), .white.opacity(0.90),
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: cornerRadius * 0.035)
            }
    }
}

private struct JournalEntryArrow: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.04), .white.opacity(0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .white.opacity(0.6), radius: 10, x: -4, y: -5)
                .shadow(color: .black.opacity(0.025), radius: 14, x: 4, y: 8)
            Circle()
                .strokeBorder(LinearGradient(colors: [
                    .white.opacity(0.58), .white.opacity(0.08), .white.opacity(0.38),
                ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            Path { path in
                path.move(to: CGPoint(x: 67, y: 95))
                path.addLine(to: CGPoint(x: 120, y: 95))
                path.move(to: CGPoint(x: 97, y: 72))
                path.addLine(to: CGPoint(x: 120, y: 95))
                path.addLine(to: CGPoint(x: 97, y: 118))
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
