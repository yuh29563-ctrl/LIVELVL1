import SwiftUI

enum CardRewardFlightGeometry {
    static func offset(from cardFrame: CGRect, to targetFrame: CGRect) -> CGSize {
        CGSize(
            width: targetFrame.midX - cardFrame.midX,
            height: targetFrame.midY - cardFrame.midY
        )
    }
}

private struct CardRewardFramePreferenceKey: PreferenceKey {
    static var defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

@MainActor
struct CardRewardOverlay: View {
    let kind: CardRewardKind
    let definition: CollectibleDefinition
    let reason: String
    let collectionTargetFrame: CGRect?
    let onClaim: () throws -> Bool
    let onClaimed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var isClaiming = false
    @State private var errorMessage: String?
    @State private var cardScale: CGFloat = 1
    @State private var cardOffset = CGSize.zero
    @State private var cardOpacity = 1.0
    @State private var backdropOpacity = 1.0
    @State private var cardFrame = CGRect.zero

    private var title: String {
        kind == .ordinaryMature ? "陪伴成熟" : "隐藏发现"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(0.28 * backdropOpacity)
                    .ignoresSafeArea()

                ScrollView {
                    rewardCard
                        .background {
                            GeometryReader { cardGeometry in
                                Color.clear.preference(
                                    key: CardRewardFramePreferenceKey.self,
                                    value: cardGeometry.frame(in: .global)
                                )
                            }
                        }
                        .frame(maxWidth: 360)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 36)
                        .frame(
                            minHeight: geometry.size.height,
                            alignment: .center
                        )
                }
                .scrollIndicators(.hidden)
                .scaleEffect(cardScale)
                .offset(cardOffset)
                .opacity(cardOpacity)
                .onPreferenceChange(CardRewardFramePreferenceKey.self) {
                    cardFrame = $0
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                isTitleFocused = true
            }
        }
        .ignoresSafeArea()
    }

    private var rewardCard: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TodayVisualTheme.graphite)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)

            PixelSpeciesArtwork(
                definition: definition,
                stage: .mature,
                isSilhouette: false
            )
            .scaleEffect(1.25)
            .padding(.vertical, 8)

            VStack(spacing: 8) {
                Text(definition.name)
                    .font(.title2.bold())
                    .foregroundStyle(TodayVisualTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reason)
                    .font(.body)
                    .foregroundStyle(TodayVisualTheme.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                claim()
            } label: {
                HStack(spacing: 8) {
                    if isClaiming {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    }
                    Text("收下")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    TodayVisualTheme.reward,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isClaiming)
            .accessibilityLabel(isClaiming ? "正在收下" : "收下")
        }
        .padding(24)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 24, y: 10)
    }

    private func claim() {
        guard !isClaiming else { return }
        isClaiming = true
        errorMessage = nil

        do {
            guard try onClaim() else {
                errorMessage = "领取失败，请重试"
                isClaiming = false
                return
            }
        } catch {
            errorMessage = "领取失败，请重试"
            isClaiming = false
            return
        }

        Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) {
                    cardOpacity = 0
                    backdropOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                let flightOffset = collectionTargetFrame.map {
                    CardRewardFlightGeometry.offset(from: cardFrame, to: $0)
                } ?? .zero
                withAnimation(.easeInOut(duration: 0.45)) {
                    cardScale = 0.15
                    cardOffset = flightOffset
                    cardOpacity = 0.08
                    backdropOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(450))
            }

            guard !Task.isCancelled else { return }
            onClaimed()
        }
    }
}
