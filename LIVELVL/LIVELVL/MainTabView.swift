import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case today
    case collection
    case rewards
    case profile
}

struct CollectionAttentionState: Equatable, Sendable {
    private(set) var shakeToken = 0
    private(set) var hasUnseenReward = false

    mutating func registerClaim() {
        shakeToken += 1
        hasUnseenReward = true
    }

    mutating func markSeen() {
        hasUnseenReward = false
    }
}

private struct RewardQueueHeadIdentity: Hashable {
    let awardKey: String
    let eligibleAt: Date
}

struct PresentedCardReward: Equatable, Sendable {
    let awardKey: String
    let kind: CardRewardKind
    let reason: String
    let definition: CollectibleDefinition
}

struct CardRewardPresentationState: Equatable, Sendable {
    private(set) var presentedReward: PresentedCardReward?
    private var locallyClaimingAwardKey: String?

    mutating func present(_ reward: PresentedCardReward) {
        presentedReward = reward
        locallyClaimingAwardKey = nil
    }

    mutating func reconcile(liveAwardKeys: Set<String>) {
        guard let presentedReward,
              !liveAwardKeys.contains(presentedReward.awardKey),
              locallyClaimingAwardKey != presentedReward.awardKey else {
            return
        }
        self.presentedReward = nil
    }

    mutating func beginSuccessfulClaim(awardKey: String) -> Bool {
        guard presentedReward?.awardKey == awardKey,
              locallyClaimingAwardKey == nil else {
            return false
        }
        locallyClaimingAwardKey = awardKey
        return true
    }

    mutating func finishSuccessfulClaim(awardKey: String) {
        guard locallyClaimingAwardKey == awardKey else { return }
        locallyClaimingAwardKey = nil
        presentedReward = nil
    }
}

@MainActor
enum CardRewardClaimCoordinator {
    static func claim(
        awardKey: String,
        in context: ModelContext,
        now: Date
    ) throws -> Bool {
        let liveReward = try context.fetch(FetchDescriptor<PendingCardReward>())
            .first { $0.awardKey == awardKey }
        guard let liveReward, liveReward.eligibleAt <= now else { return false }

        let progress = try CardRewardService.ensureProgress(in: context)
        try CardRewardService.claim(
            liveReward,
            progress: progress,
            in: context,
            now: now
        )

        let pendingStillExists = try context.fetch(FetchDescriptor<PendingCardReward>())
            .contains { $0.awardKey == awardKey }
        let ownedExists = try context.fetch(FetchDescriptor<OwnedCollectible>())
            .contains { $0.awardKey == awardKey }
        return !pendingStillExists && ownedExists
    }
}

struct CollectionTabFeedbackRequest: Equatable, Sendable {
    fileprivate let generation: Int
    let attentionToken: Int
    let hasUnseenReward: Bool
    let reduceMotion: Bool
}

struct CollectionTabFeedbackGenerationState: Equatable, Sendable {
    private var generation = 0
    private var desiredState: CollectionTabFeedbackRequest?
    private var lastAnimatedToken = 0

    mutating func replaceDesiredState(
        attentionToken: Int,
        hasUnseenReward: Bool,
        reduceMotion: Bool
    ) -> CollectionTabFeedbackRequest {
        generation &+= 1
        let request = CollectionTabFeedbackRequest(
            generation: generation,
            attentionToken: attentionToken,
            hasUnseenReward: hasUnseenReward,
            reduceMotion: reduceMotion
        )
        desiredState = request
        return request
    }

    func isCurrent(_ request: CollectionTabFeedbackRequest) -> Bool {
        desiredState == request && request.generation == generation
    }

    mutating func takeAnimationToken(
        for request: CollectionTabFeedbackRequest
    ) -> Int? {
        guard isCurrent(request), request.attentionToken > lastAnimatedToken else {
            return nil
        }
        lastAnimatedToken = request.attentionToken
        return request.attentionToken
    }

    mutating func cancel() {
        generation &+= 1
        desiredState = nil
    }
}

enum CollectionTabIdentity {
    static let accessibilityIdentifier = "main-tab.collection"
    static let systemImageName = "square.grid.2x2.fill"
}

@MainActor
enum CollectionTabTargetResolver {
    static func item(in tabBar: UITabBar) -> UITabBarItem? {
        tabBar.items?.first {
            $0.accessibilityIdentifier == CollectionTabIdentity.accessibilityIdentifier
                || $0.image?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
                || $0.selectedImage?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
        }
    }

    static func itemView(in tabBar: UITabBar) -> UIView? {
        guard let stableMarkerView = descendantViews(of: tabBar).first(where: {
            $0.accessibilityIdentifier == CollectionTabIdentity.accessibilityIdentifier
                || $0.accessibilityIdentifier == CollectionTabIdentity.systemImageName
        }) else {
            return nil
        }

        var ancestor: UIView? = stableMarkerView
        while let current = ancestor, current !== tabBar {
            if current is UIControl {
                return current
            }
            ancestor = current.superview
        }
        return stableMarkerView
    }

    private static func descendantViews(of root: UIView) -> [UIView] {
        root.subviews.flatMap { [$0] + descendantViews(of: $0) }
    }
}

@MainActor
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var pendingRewards: [PendingCardReward]
    @Query private var ownedCollectibles: [OwnedCollectible]
    @State private var selectedTab: AppTab = .today
    @State private var attention = CollectionAttentionState()
    @State private var presentation = CardRewardPresentationState()
    @State private var collectionTabFrameInWindow: CGRect?

    private var orderedPendingRewards: [PendingCardReward] {
        CardRewardService.ordered(pendingRewards)
    }

    private var queueHead: PendingCardReward? {
        orderedPendingRewards.first {
            CollectionCatalog.definition(id: $0.collectibleID) != nil
        }
    }

    private var queueHeadIdentity: RewardQueueHeadIdentity? {
        queueHead.map {
            RewardQueueHeadIdentity(awardKey: $0.awardKey, eligibleAt: $0.eligibleAt)
        }
    }

    private var hasUnseenReward: Bool {
        attention.hasUnseenReward || ownedCollectibles.contains(where: \.isUnseen)
    }

    private var livePendingAwardKeys: Set<String> {
        Set(pendingRewards.map(\.awardKey))
    }

    var body: some View {
        ZStack {
            TabView(selection: selectedTabBinding) {
                TodayView()
                    .tag(AppTab.today)
                    .tabItem { Label("今天", systemImage: "sun.max.fill") }

                CollectionView {
                    attention.markSeen()
                }
                    .tag(AppTab.collection)
                    .tabItem {
                        CollectionTabLabel(
                            hasUnseenReward: hasUnseenReward
                        )
                        .accessibilityIdentifier(CollectionTabIdentity.accessibilityIdentifier)
                    }

                RewardPlaceholderView()
                    .tag(AppTab.rewards)
                    .tabItem { Label("奖励", systemImage: "gift.fill") }

                ProfileView()
                    .tag(AppTab.profile)
                    .tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
            .tint(TodayVisualTheme.ink)
            .accessibilityHidden(presentation.presentedReward != nil)
            .background {
                CollectionTabFeedbackBridge(
                    attentionToken: attention.shakeToken,
                    hasUnseenReward: hasUnseenReward,
                    reduceMotion: reduceMotion,
                    targetFrameInWindow: $collectionTabFrameInWindow
                )
                .frame(width: 0, height: 0)
            }

            if let presentedReward = presentation.presentedReward {
                CardRewardOverlay(
                    kind: presentedReward.kind,
                    definition: presentedReward.definition,
                    reason: presentedReward.reason,
                    collectionTargetFrame: collectionTabFrameInWindow,
                    onClaim: {
                        let didClaim = try CardRewardClaimCoordinator.claim(
                            awardKey: presentedReward.awardKey,
                            in: context,
                            now: .now
                        )
                        guard didClaim else { return false }
                        return presentation.beginSuccessfulClaim(
                            awardKey: presentedReward.awardKey
                        )
                    },
                    onClaimed: {
                        attention.registerClaim()
                        presentation.finishSuccessfulClaim(
                            awardKey: presentedReward.awardKey
                        )
                    }
                )
                .id(presentedReward.awardKey)
                .zIndex(1)
            }
        }
        .task(id: queueHeadIdentity) {
            await presentQueueHead(queueHeadIdentity)
        }
        .onChange(of: livePendingAwardKeys, initial: true) { _, liveAwardKeys in
            presentation.reconcile(liveAwardKeys: liveAwardKeys)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                selectedTab = newTab
                guard newTab == .collection else { return }
                markCollectionSeen()
            }
        )
    }

    private func presentQueueHead(_ identity: RewardQueueHeadIdentity?) async {
        guard let identity,
              let reward = queueHead,
              reward.awardKey == identity.awardKey else {
            return
        }

        let remainingDelay = reward.eligibleAt.timeIntervalSinceNow
        if remainingDelay > 0 {
            do {
                try await Task.sleep(for: .seconds(remainingDelay))
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }

        let waitsBehindCurrentReward = presentation.presentedReward != nil
        while presentation.presentedReward != nil {
            do {
                try await Task.sleep(for: .milliseconds(25))
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }

        if waitsBehindCurrentReward {
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }

        guard !Task.isCancelled,
              queueHeadIdentity == identity,
              let currentReward = queueHead,
              currentReward.awardKey == identity.awardKey,
              Date.now >= currentReward.eligibleAt,
              let definition = CollectionCatalog.definition(id: currentReward.collectibleID) else {
            return
        }

        presentation.present(PresentedCardReward(
            awardKey: currentReward.awardKey,
            kind: currentReward.kind,
            reason: currentReward.reason,
            definition: definition
        ))
    }

    private func markCollectionSeen() {
        do {
            try CardRewardService.markAllSeen(in: context)
            attention.markSeen()
        } catch {
            return
        }
    }
}

@MainActor
struct CollectionTabLabel: View {
    let hasUnseenReward: Bool

    var body: some View {
        Label("收集", systemImage: CollectionTabIdentity.systemImageName)
            .accessibilityLabel(hasUnseenReward ? "收集，有未查看奖励" : "收集")
    }
}

private struct CollectionTabFeedbackBridge: UIViewRepresentable {
    let attentionToken: Int
    let hasUnseenReward: Bool
    let reduceMotion: Bool
    @Binding var targetFrameInWindow: CGRect?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.scheduleUpdate(
            from: uiView,
            attentionToken: attentionToken,
            hasUnseenReward: hasUnseenReward,
            reduceMotion: reduceMotion,
            targetFrameDidChange: { measuredFrame in
                guard targetFrameInWindow != measuredFrame else { return }
                targetFrameInWindow = measuredFrame
            }
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    @MainActor
    final class Coordinator {
        private var generationState = CollectionTabFeedbackGenerationState()
        private var pendingWorkItem: DispatchWorkItem?
        private var targetFrameDidChange: ((CGRect?) -> Void)?

        func scheduleUpdate(
            from sourceView: UIView,
            attentionToken: Int,
            hasUnseenReward: Bool,
            reduceMotion: Bool,
            targetFrameDidChange: @escaping (CGRect?) -> Void
        ) {
            let request = generationState.replaceDesiredState(
                attentionToken: attentionToken,
                hasUnseenReward: hasUnseenReward,
                reduceMotion: reduceMotion
            )
            self.targetFrameDidChange = targetFrameDidChange
            enqueue(request, from: sourceView, remainingAttempts: 4, delay: 0)
        }

        func cancel() {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            targetFrameDidChange = nil
            generationState.cancel()
        }

        private func enqueue(
            _ request: CollectionTabFeedbackRequest,
            from sourceView: UIView,
            remainingAttempts: Int,
            delay: TimeInterval
        ) {
            pendingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak sourceView] in
                guard let self, let sourceView,
                      self.generationState.isCurrent(request) else {
                    return
                }
                self.apply(
                    request,
                    from: sourceView,
                    remainingAttempts: remainingAttempts
                )
            }
            pendingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func apply(
            _ request: CollectionTabFeedbackRequest,
            from sourceView: UIView,
            remainingAttempts: Int
        ) {
            guard generationState.isCurrent(request),
                  let tabBar = findTabBar(from: sourceView) else {
                retry(
                    request,
                    from: sourceView,
                    remainingAttempts: remainingAttempts
                )
                return
            }
            guard generationState.isCurrent(request),
                  let collectionItem = CollectionTabTargetResolver.item(in: tabBar),
                  let itemView = CollectionTabTargetResolver.itemView(in: tabBar),
                  let window = sourceView.window else {
                retry(
                    request,
                    from: sourceView,
                    remainingAttempts: remainingAttempts
                )
                return
            }

            updateBadge(collectionItem, isVisible: request.hasUnseenReward)
            targetFrameDidChange?(itemView.convert(itemView.bounds, to: window))
            guard generationState.takeAnimationToken(for: request) != nil else {
                return
            }
            animateCollectionItem(itemView, reduceMotion: request.reduceMotion)
        }

        private func retry(
            _ request: CollectionTabFeedbackRequest,
            from sourceView: UIView,
            remainingAttempts: Int
        ) {
            guard remainingAttempts > 0 else {
                targetFrameDidChange?(nil)
                return
            }
            enqueue(
                request,
                from: sourceView,
                remainingAttempts: remainingAttempts - 1,
                delay: 0.05
            )
        }

        private func findTabBar(from sourceView: UIView) -> UITabBar? {
            guard let rootViewController = sourceView.window?.rootViewController else {
                return nil
            }
            return findTabBarController(in: rootViewController)?.tabBar
        }

        private func findTabBarController(in viewController: UIViewController) -> UITabBarController? {
            if let tabBarController = viewController as? UITabBarController {
                return tabBarController
            }
            for child in viewController.children {
                if let tabBarController = findTabBarController(in: child) {
                    return tabBarController
                }
            }
            if let presentedViewController = viewController.presentedViewController {
                return findTabBarController(in: presentedViewController)
            }
            return nil
        }

        private func updateBadge(_ collectionItem: UITabBarItem, isVisible: Bool) {
            collectionItem.badgeValue = isVisible ? " " : nil
            collectionItem.badgeColor = UIColor(TodayVisualTheme.reward)
            collectionItem.setBadgeTextAttributes(
                [.foregroundColor: UIColor.clear],
                for: .normal
            )
        }

        private func animateCollectionItem(_ itemView: UIView, reduceMotion: Bool) {
            if !reduceMotion {
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shake.values = [0, -3, 3, -3, 3, 0]
                shake.keyTimes = [0, 0.16, 0.36, 0.56, 0.76, 1]
                shake.duration = 0.3
                shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                itemView.layer.add(shake, forKey: "collectionAttentionShake")
            }

            let pulseView = UIView(frame: itemView.bounds.insetBy(dx: 4, dy: 2))
            pulseView.isUserInteractionEnabled = false
            pulseView.backgroundColor = UIColor(TodayVisualTheme.reward).withAlphaComponent(0.18)
            pulseView.layer.cornerRadius = min(pulseView.bounds.width, pulseView.bounds.height) / 2
            itemView.insertSubview(pulseView, at: 0)
            pulseView.transform = CGAffineTransform(scaleX: 0.78, y: 0.78)
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                options: [.allowUserInteraction, .curveEaseOut]
            ) {
                pulseView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                pulseView.alpha = 0
            } completion: { _ in
                pulseView.removeFromSuperview()
            }
        }
    }
}
