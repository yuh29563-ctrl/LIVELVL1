import SwiftUI

struct CardRewardFlightTransform: Equatable {
    let scale: CGFloat
    let offset: CGSize

    func projectedFrame(of cardFrame: CGRect) -> CGRect {
        let projectedSize = CGSize(
            width: cardFrame.width * scale,
            height: cardFrame.height * scale
        )
        return CGRect(
            x: cardFrame.midX + offset.width - (projectedSize.width / 2),
            y: cardFrame.midY + offset.height - (projectedSize.height / 2),
            width: projectedSize.width,
            height: projectedSize.height
        )
    }
}

struct CardRewardClaimAnimationPlan: Equatable {
    let buttonPressScale: CGFloat
    let buttonPressDuration: TimeInterval
    let liftDuration: TimeInterval
    let travelDuration: TimeInterval
    let implodeDuration: TimeInterval
    let initialCardOpacity: Double
    let arrivalCardScale: CGFloat
    let arrivalCardOpacity: Double
    let usesSpatialFlight: Bool

    init(reduceMotion: Bool) {
        buttonPressScale = reduceMotion ? 1 : 0.94
        buttonPressDuration = reduceMotion ? 0 : 0.1
        liftDuration = reduceMotion ? 0 : 0.12
        travelDuration = reduceMotion ? 0 : 0.44
        implodeDuration = reduceMotion ? 0.2 : 0.16
        initialCardOpacity = 1
        arrivalCardScale = reduceMotion ? 1 : 0
        arrivalCardOpacity = 0
        usesSpatialFlight = !reduceMotion
    }
}

enum CardRewardClaimReadiness {
    static func canClaim(
        collectionTargetFrame: CGRect?,
        reduceMotion: Bool
    ) -> Bool {
        reduceMotion || collectionTargetFrame?.isEmpty == false
    }
}

struct CardRewardFlightPose: Equatable {
    let center: CGPoint
    let scale: CGFloat
    let opacity: Double
}

struct CardRewardFlightTrajectory: Equatable {
    let lift: CardRewardFlightPose
    let approach: CardRewardFlightPose
    let arrival: CardRewardFlightPose

    static func make(
        from cardFrame: CGRect,
        to targetFrame: CGRect
    ) -> CardRewardFlightTrajectory {
        let start = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        let target = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        let approachProgress: CGFloat = 0.72
        let approach = CGPoint(
            x: start.x + ((target.x - start.x) * approachProgress),
            y: start.y + ((target.y - start.y) * approachProgress) - 54
        )
        return CardRewardFlightTrajectory(
            lift: CardRewardFlightPose(
                center: CGPoint(x: start.x, y: start.y - 22),
                scale: 1.02,
                opacity: 1
            ),
            approach: CardRewardFlightPose(
                center: approach,
                scale: 0.34,
                opacity: 1
            ),
            arrival: CardRewardFlightPose(
                center: target,
                scale: 0,
                opacity: 0
            )
        )
    }
}

enum CardRewardFlightGeometry {
    static func offset(from cardFrame: CGRect, to targetFrame: CGRect) -> CGSize {
        CGSize(
            width: targetFrame.midX - cardFrame.midX,
            height: targetFrame.midY - cardFrame.midY
        )
    }

    static func transform(
        from cardFrame: CGRect,
        to targetFrame: CGRect,
        scale: CGFloat
    ) -> CardRewardFlightTransform {
        CardRewardFlightTransform(
            scale: scale,
            offset: offset(from: cardFrame, to: targetFrame)
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
    let onArrived: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var isClaiming = false
    @State private var errorMessage: String?
    @State private var cardScale: CGFloat = 1
    @State private var cardOffset = CGSize.zero
    @State private var cardOpacity = 1.0
    @State private var backdropOpacity = 1.0
    @State private var cardFrame = CGRect.zero
    @State private var claimButtonScale: CGFloat = 1

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
                        .frame(maxWidth: 360)
                        .background {
                            GeometryReader { cardGeometry in
                                Color.clear.preference(
                                    key: CardRewardFramePreferenceKey.self,
                                    value: cardGeometry.frame(in: .global)
                                )
                            }
                        }
                        .scaleEffect(cardScale)
                        .offset(cardOffset)
                        .opacity(cardOpacity)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 36)
                        .frame(
                            minHeight: geometry.size.height,
                            alignment: .center
                        )
                }
                .scrollIndicators(.hidden)
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
            .scaleEffect(claimButtonScale)
            .disabled(
                isClaiming
                    || !CardRewardClaimReadiness.canClaim(
                        collectionTargetFrame: collectionTargetFrame,
                        reduceMotion: reduceMotion
                    )
            )
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
        guard !isClaiming,
              CardRewardClaimReadiness.canClaim(
                  collectionTargetFrame: collectionTargetFrame,
                  reduceMotion: reduceMotion
              ) else {
            return
        }
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
            let plan = CardRewardClaimAnimationPlan(reduceMotion: reduceMotion)
            if plan.buttonPressDuration > 0 {
                withAnimation(.easeOut(duration: plan.buttonPressDuration)) {
                    claimButtonScale = plan.buttonPressScale
                }
                await sleep(for: plan.buttonPressDuration)
            }

            if !plan.usesSpatialFlight {
                withAnimation(.easeOut(duration: plan.implodeDuration)) {
                    cardOpacity = 0
                    backdropOpacity = 0
                }
                await sleep(for: plan.implodeDuration)
            } else {
                let targetFrame = collectionTargetFrame ?? CGRect(
                    x: cardFrame.midX,
                    y: cardFrame.midY,
                    width: 0,
                    height: 0
                )
                let trajectory = CardRewardFlightTrajectory.make(
                    from: cardFrame,
                    to: targetFrame
                )

                withAnimation(.easeOut(duration: plan.liftDuration)) {
                    apply(trajectory.lift)
                }
                await sleep(for: plan.liftDuration)

                withAnimation(.timingCurve(0.18, 0.78, 0.24, 1, duration: plan.travelDuration)) {
                    apply(trajectory.approach)
                    backdropOpacity = 0.12
                }
                await sleep(for: plan.travelDuration)

                withAnimation(.easeIn(duration: plan.implodeDuration)) {
                    apply(trajectory.arrival)
                    backdropOpacity = 0
                }
                await sleep(for: plan.implodeDuration)
            }

            guard !Task.isCancelled else { return }
            onArrived()
        }
    }

    private func apply(_ pose: CardRewardFlightPose) {
        cardScale = pose.scale
        cardOffset = CGSize(
            width: pose.center.x - cardFrame.midX,
            height: pose.center.y - cardFrame.midY
        )
        cardOpacity = pose.opacity
    }

    private func sleep(for duration: TimeInterval) async {
        let milliseconds = Int((duration * 1_000).rounded())
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
