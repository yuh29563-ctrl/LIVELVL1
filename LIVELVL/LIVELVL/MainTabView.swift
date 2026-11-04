import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case today
    case collection
    case rewards
    case profile

    var title: String {
        switch self {
        case .today: "今天"
        case .collection: "收集"
        case .rewards: "奖励"
        case .profile: "我的"
        }
    }

    var systemImageName: String {
        switch self {
        case .today: "sun.max"
        case .collection: CollectionTabIdentity.systemImageName
        case .rewards: "gift"
        case .profile: "person"
        }
    }
}

struct CollectionAttentionState: Equatable, Sendable {
    private(set) var shakeToken = 0
    private(set) var hasUnseenReward = false

    @discardableResult
    mutating func registerClaim() -> Int {
        shakeToken += 1
        hasUnseenReward = true
        return shakeToken
    }

    mutating func markSeen() {
        hasUnseenReward = false
    }
}

struct CardRewardHandoffState: Equatable, Sendable {
    private(set) var generation = 0
    private var dismissalCompletedAt: Date?

    mutating func recordDismissalCompletion(at date: Date) {
        generation &+= 1
        dismissalCompletedAt = date
    }

    func presentationNotBefore(rewardEligibleAt: Date) -> Date {
        guard let dismissalCompletedAt else { return rewardEligibleAt }
        return max(
            rewardEligibleAt,
            dismissalCompletedAt.addingTimeInterval(0.25)
        )
    }
}

private struct RewardQueueHeadIdentity: Hashable {
    let awardKey: String
    let eligibleAt: Date
}

private struct RewardPresentationTaskIdentity: Hashable {
    let queueHead: RewardQueueHeadIdentity?
    let handoffGeneration: Int
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
    private var awaitedFeedbackToken: Int?

    mutating func present(_ reward: PresentedCardReward) {
        presentedReward = reward
        locallyClaimingAwardKey = nil
        awaitedFeedbackToken = nil
    }

    @discardableResult
    mutating func reconcile(liveAwardKeys: Set<String>) -> Bool {
        guard let presentedReward,
              !liveAwardKeys.contains(presentedReward.awardKey),
              locallyClaimingAwardKey != presentedReward.awardKey else {
            return false
        }
        self.presentedReward = nil
        awaitedFeedbackToken = nil
        return true
    }

    mutating func beginSuccessfulClaim(awardKey: String) -> Bool {
        guard presentedReward?.awardKey == awardKey,
              locallyClaimingAwardKey == nil else {
            return false
        }
        locallyClaimingAwardKey = awardKey
        awaitedFeedbackToken = nil
        return true
    }

    mutating func waitForCollectionFeedback(
        awardKey: String,
        attentionToken: Int
    ) -> Bool {
        guard locallyClaimingAwardKey == awardKey,
              attentionToken > 0 else {
            return false
        }
        awaitedFeedbackToken = attentionToken
        return true
    }

    mutating func finishSuccessfulClaim(feedbackToken: Int) -> String? {
        guard awaitedFeedbackToken == feedbackToken,
              let locallyClaimingAwardKey else {
            return nil
        }
        self.locallyClaimingAwardKey = nil
        awaitedFeedbackToken = nil
        presentedReward = nil
        return locallyClaimingAwardKey
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

struct CollectionTabFeedbackAnimationPlan: Equatable, Sendable {
    let shakeTranslations: [CGFloat]
    let bounceScales: [CGFloat]
    let initialPulseScale: CGFloat
    let finalPulseScale: CGFloat

    init(reduceMotion: Bool) {
        if reduceMotion {
            shakeTranslations = []
            bounceScales = []
            initialPulseScale = 1
            finalPulseScale = 1
        } else {
            shakeTranslations = [0, -5, 4, -3, 2, 0]
            bounceScales = [1, 0.88, 1.16, 0.96, 1]
            initialPulseScale = 0.65
            finalPulseScale = 1.45
        }
    }
}

enum CollectionTabIdentity {
    static let accessibilityIdentifier = "main-tab.collection"
    static let systemImageName = "circle.grid.3x3.fill"
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
        guard let items = tabBar.items,
              let collectionIndex = items.firstIndex(where: {
                  $0.accessibilityIdentifier == CollectionTabIdentity.accessibilityIdentifier
                      || $0.image?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
                      || $0.selectedImage?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
              }) else {
            return nil
        }

        let controls = descendantViews(of: tabBar)
            .compactMap { $0 as? UIControl }
            .filter { control in
                var ancestor = control.superview
                while let current = ancestor, current !== tabBar {
                    if current is UIControl {
                        return false
                    }
                    ancestor = current.superview
                }
                return ancestor === tabBar
                    && control.bounds.width > 0
                    && control.bounds.width < tabBar.bounds.width
                    && control.bounds.height > 0
            }

        guard !controls.isEmpty else { return nil }
        let slotWidth = tabBar.bounds.width / CGFloat(items.count)
        let visualIndex = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? items.count - 1 - collectionIndex
            : collectionIndex
        let targetMidX = tabBar.bounds.minX
            + (slotWidth * (CGFloat(visualIndex) + 0.5))
        return controls.min { lhs, rhs in
            let lhsMidX = lhs.convert(lhs.bounds, to: tabBar).midX
            let rhsMidX = rhs.convert(rhs.bounds, to: tabBar).midX
            return abs(lhsMidX - targetMidX) < abs(rhsMidX - targetMidX)
        }
    }

    static func targetFrame(in tabBar: UITabBar) -> CGRect? {
        guard let items = tabBar.items,
              !items.isEmpty,
              let collectionIndex = items.firstIndex(where: {
                  $0.accessibilityIdentifier == CollectionTabIdentity.accessibilityIdentifier
                      || $0.image?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
                      || $0.selectedImage?.accessibilityIdentifier == CollectionTabIdentity.systemImageName
              }) else {
            return nil
        }

        let slotWidth = tabBar.bounds.width / CGFloat(items.count)
        let visualIndex = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? items.count - 1 - collectionIndex
            : collectionIndex
        let contentHeight = max(
            44,
            tabBar.bounds.height - tabBar.safeAreaInsets.bottom
        )
        let center = CGPoint(
            x: tabBar.bounds.minX + (slotWidth * (CGFloat(visualIndex) + 0.5)),
            y: tabBar.bounds.minY + (contentHeight / 2)
        )
        return CGRect(
            x: center.x - 22,
            y: center.y - 22,
            width: 44,
            height: 44
        )
    }

    private static func descendantViews(of root: UIView) -> [UIView] {
        root.subviews.flatMap { [$0] + descendantViews(of: $0) }
    }
}

@MainActor
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var pendingRewards: [PendingCardReward]
    @Query private var ownedCollectibles: [OwnedCollectible]
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse) private var stateSnapshots: [StateSnapshot]
    @State private var selectedTab: AppTab = .today
    @State private var attention = CollectionAttentionState()
    @State private var presentation = CardRewardPresentationState()
    @State private var handoff = CardRewardHandoffState()
    @State private var archiveArrival = ArchiveArrivalPresentationState()
    @State private var collectionTabFrameInWindow: CGRect?
    @State private var didResolveLaunchRewards = false
    @State private var autoAcknowledgedAwardKeys: Set<String> = []
#if DEBUG
    let reportLocalDataResetFailure: (LocalDataResetFailure) -> Void
    private let debugResetActionConfiguration: ProfileView.DebugResetActionConfiguration
    private let debugResetActionTrigger: ProfileView.DebugResetActionTrigger?

    init(
        reportLocalDataResetFailure: @escaping (LocalDataResetFailure) -> Void = { _ in },
        debugResetActionConfiguration: ProfileView.DebugResetActionConfiguration = .live,
        debugResetActionTrigger: ProfileView.DebugResetActionTrigger? = nil,
        debugInitialTab: AppTab = .today
    ) {
        self.reportLocalDataResetFailure = reportLocalDataResetFailure
        self.debugResetActionConfiguration = debugResetActionConfiguration
        self.debugResetActionTrigger = debugResetActionTrigger
        _selectedTab = State(initialValue: debugInitialTab)
    }
#endif

    private var orderedPendingRewards: [PendingCardReward] {
        CardRewardService.ordered(pendingRewards)
    }

    private var queueHead: PendingCardReward? {
        guard didResolveLaunchRewards else { return nil }
        return orderedPendingRewards.first {
            !autoAcknowledgedAwardKeys.contains($0.awardKey)
                && CollectionCatalog.definition(id: $0.collectibleID) != nil
        }
    }

    private var blocksForOrdinaryReward: Bool {
        !didResolveLaunchRewards || pendingRewards.contains {
            $0.kind == .ordinaryMature && !autoAcknowledgedAwardKeys.contains($0.awardKey)
        }
    }

    private var queueHeadIdentity: RewardQueueHeadIdentity? {
        queueHead.map {
            RewardQueueHeadIdentity(awardKey: $0.awardKey, eligibleAt: $0.eligibleAt)
        }
    }

    private var rewardPresentationTaskIdentity: RewardPresentationTaskIdentity {
        RewardPresentationTaskIdentity(
            queueHead: queueHeadIdentity,
            handoffGeneration: handoff.generation
        )
    }

    private var hasUnseenReward: Bool {
        attention.hasUnseenReward || ownedCollectibles.contains(where: \.isUnseen)
    }

    private var livePendingAwardKeys: Set<String> {
        Set(pendingRewards.map(\.awardKey))
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tag(AppTab.today)
                    .tabItem {
                        Label(AppTab.today.title, systemImage: AppTab.today.systemImageName)
                    }

                CollectionView(
                    isCollectionSelected: selectedTab == .collection,
                    isObscured: blocksForOrdinaryReward || presentation.presentedReward != nil,
                    arrivalState: $archiveArrival,
                    onMarkedSeen: { attention.markSeen() }
                )
                    .tag(AppTab.collection)
                    .tabItem {
                        CollectionTabLabel(
                            hasUnseenReward: hasUnseenReward
                        )
                        .accessibilityIdentifier(CollectionTabIdentity.accessibilityIdentifier)
                    }

                RewardStoreView()
                    .tag(AppTab.rewards)
                    .tabItem {
                        Label(AppTab.rewards.title, systemImage: AppTab.rewards.systemImageName)
                    }

                Group {
#if DEBUG
                    ProfileView(
                        reportResetFailure: reportLocalDataResetFailure,
                        debugResetActionConfiguration: debugResetActionConfiguration,
                        debugResetActionTrigger: debugResetActionTrigger
                    )
#else
                    ProfileView()
#endif
                }
                    .tag(AppTab.profile)
                    .tabItem {
                        Label(AppTab.profile.title, systemImage: AppTab.profile.systemImageName)
                    }
            }
            .tint(TodayVisualTheme.ink)
            .allowsHitTesting(!blocksForOrdinaryReward && presentation.presentedReward == nil)
            .accessibilityHidden(blocksForOrdinaryReward || presentation.presentedReward != nil)
            .background {
                CollectionTabFeedbackBridge(
                    attentionToken: attention.shakeToken,
                    hasUnseenReward: hasUnseenReward,
                    reduceMotion: reduceMotion,
                    targetFrameInWindow: $collectionTabFrameInWindow,
                    attentionAnimationCompleted: completeClaimAfterCollectionFeedback
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
                    onArrived: {
                        let token = attention.registerClaim()
                        _ = presentation.waitForCollectionFeedback(
                            awardKey: presentedReward.awardKey,
                            attentionToken: token
                        )
                    }
                )
                .id(presentedReward.awardKey)
                .zIndex(1)
            }
        }
        .task(id: rewardPresentationTaskIdentity) {
            await presentQueueHead(rewardPresentationTaskIdentity)
        }
        .onChange(of: livePendingAwardKeys, initial: true) { _, liveAwardKeys in
            if presentation.reconcile(liveAwardKeys: liveAwardKeys) {
                handoff.recordDismissalCompletion(at: .now)
            }
        }
        .onChange(of: stateSnapshots.first?.persistentModelID) { _, newSnapshot in
            if newSnapshot != nil {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.5)) {
                    selectedTab = .today
                }
            }
        }
        .onAppear {
            guard !didResolveLaunchRewards else { return }
            acknowledgeUnfinishedOrdinaryRewards()
            didResolveLaunchRewards = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                acknowledgeUnfinishedOrdinaryRewards()
                presentation = CardRewardPresentationState()
                handoff.recordDismissalCompletion(at: .now)
            }
        }
    }

    private func acknowledgeUnfinishedOrdinaryRewards() {
        do {
            autoAcknowledgedAwardKeys.formUnion(
                try CardRewardService.acknowledgeAlreadyOwnedOrdinaryRewards(
                    in: context,
                    now: .now
                )
            )
        } catch {
            // Keep any unacknowledged reward in the queue for the next launch.
        }
    }

    private func presentQueueHead(_ taskIdentity: RewardPresentationTaskIdentity) async {
        guard taskIdentity == rewardPresentationTaskIdentity,
              presentation.presentedReward == nil,
              let identity = taskIdentity.queueHead,
              let reward = queueHead,
              reward.awardKey == identity.awardKey else {
            return
        }

        let remainingDelay = handoff.presentationNotBefore(
            rewardEligibleAt: reward.eligibleAt
        ).timeIntervalSinceNow
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

        guard !Task.isCancelled,
              taskIdentity == rewardPresentationTaskIdentity,
              presentation.presentedReward == nil,
              queueHeadIdentity == identity,
              let currentReward = queueHead,
              currentReward.awardKey == identity.awardKey,
              Date.now >= handoff.presentationNotBefore(
                rewardEligibleAt: currentReward.eligibleAt
              ),
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

    private func completeClaimAfterCollectionFeedback(_ feedbackToken: Int) {
        guard let awardKey = presentation.finishSuccessfulClaim(
            feedbackToken: feedbackToken
        ) else {
            return
        }
        archiveArrival.registerClaimed(awardKey: awardKey)
        handoff.recordDismissalCompletion(at: .now)
    }

}

@MainActor
struct CollectionTabLabel: View {
    let hasUnseenReward: Bool

    var body: some View {
        Label(AppTab.collection.title, systemImage: AppTab.collection.systemImageName)
            .accessibilityLabel(
                hasUnseenReward
                    ? "\(AppTab.collection.title)，有未查看奖励"
                    : AppTab.collection.title
            )
    }
}

private struct CollectionTabFeedbackBridge: UIViewRepresentable {
    let attentionToken: Int
    let hasUnseenReward: Bool
    let reduceMotion: Bool
    @Binding var targetFrameInWindow: CGRect?
    let attentionAnimationCompleted: (Int) -> Void

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
            },
            attentionAnimationCompleted: attentionAnimationCompleted
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
        private var attentionAnimationCompleted: ((Int) -> Void)?

        func scheduleUpdate(
            from sourceView: UIView,
            attentionToken: Int,
            hasUnseenReward: Bool,
            reduceMotion: Bool,
            targetFrameDidChange: @escaping (CGRect?) -> Void,
            attentionAnimationCompleted: @escaping (Int) -> Void
        ) {
            let request = generationState.replaceDesiredState(
                attentionToken: attentionToken,
                hasUnseenReward: hasUnseenReward,
                reduceMotion: reduceMotion
            )
            self.targetFrameDidChange = targetFrameDidChange
            self.attentionAnimationCompleted = attentionAnimationCompleted
            enqueue(request, from: sourceView, remainingAttempts: 4, delay: 0)
        }

        func cancel() {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            targetFrameDidChange = nil
            attentionAnimationCompleted = nil
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
                  let fallbackTargetFrame = CollectionTabTargetResolver.targetFrame(in: tabBar),
                  let window = sourceView.window else {
                retry(
                    request,
                    from: sourceView,
                    remainingAttempts: remainingAttempts
                )
                return
            }

            updateBadge(collectionItem, isVisible: request.hasUnseenReward)
            let itemView = CollectionTabTargetResolver.itemView(in: tabBar)
            let targetFrameInTabBar = itemView?.convert(itemView?.bounds ?? .zero, to: tabBar)
                ?? fallbackTargetFrame
            targetFrameDidChange?(tabBar.convert(targetFrameInTabBar, to: window))
            guard let animationToken = generationState.takeAnimationToken(for: request) else {
                return
            }
            if let itemView {
                animateCollectionItem(
                    itemView,
                    reduceMotion: request.reduceMotion
                ) { [weak self] in
                    self?.attentionAnimationCompleted?(animationToken)
                }
            } else {
                animateCollectionFallback(
                    in: tabBar,
                    frame: fallbackTargetFrame,
                    reduceMotion: request.reduceMotion
                ) { [weak self] in
                    self?.attentionAnimationCompleted?(animationToken)
                }
            }
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

        private func animateCollectionItem(
            _ itemView: UIView,
            reduceMotion: Bool,
            completion: @escaping () -> Void
        ) {
            let plan = CollectionTabFeedbackAnimationPlan(reduceMotion: reduceMotion)
            if !plan.shakeTranslations.isEmpty {
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shake.values = plan.shakeTranslations
                shake.keyTimes = [0, 0.16, 0.36, 0.56, 0.76, 1]
                shake.duration = 0.42
                shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                itemView.layer.add(shake, forKey: "collectionAttentionShake")
            }

            if !plan.bounceScales.isEmpty {
                let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
                bounce.values = plan.bounceScales
                bounce.keyTimes = [0, 0.2, 0.5, 0.75, 1]
                bounce.duration = 0.42
                bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                itemView.layer.add(bounce, forKey: "collectionAttentionBounce")
            }

            let pulseView = UIView(frame: itemView.bounds.insetBy(dx: 4, dy: 2))
            pulseView.isUserInteractionEnabled = false
            pulseView.backgroundColor = UIColor(TodayVisualTheme.reward).withAlphaComponent(0.1)
            pulseView.layer.borderColor = UIColor(TodayVisualTheme.reward).withAlphaComponent(0.55).cgColor
            pulseView.layer.borderWidth = 2
            pulseView.layer.cornerRadius = min(pulseView.bounds.width, pulseView.bounds.height) / 2
            itemView.insertSubview(pulseView, at: 0)
            pulseView.transform = CGAffineTransform(
                scaleX: plan.initialPulseScale,
                y: plan.initialPulseScale
            )
            UIView.animate(
                withDuration: 0.46,
                delay: 0,
                options: [.allowUserInteraction, .curveEaseOut]
            ) {
                pulseView.transform = CGAffineTransform(
                    scaleX: plan.finalPulseScale,
                    y: plan.finalPulseScale
                )
                pulseView.alpha = 0
            } completion: { _ in
                pulseView.removeFromSuperview()
                completion()
            }
        }

        private func animateCollectionFallback(
            in tabBar: UITabBar,
            frame: CGRect,
            reduceMotion: Bool,
            completion: @escaping () -> Void
        ) {
            let targetView = UIView(frame: frame)
            targetView.isUserInteractionEnabled = false
            targetView.backgroundColor = .clear
            tabBar.addSubview(targetView)
            animateCollectionItem(targetView, reduceMotion: reduceMotion) {
                targetView.removeFromSuperview()
                completion()
            }
        }
    }
}
