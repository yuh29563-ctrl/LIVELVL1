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

private struct PresentedCardReward {
    let model: PendingCardReward
    let awardKey: String
    let kind: CardRewardKind
    let reason: String
    let definition: CollectibleDefinition
}

@MainActor
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var pendingRewards: [PendingCardReward]
    @Query private var ownedCollectibles: [OwnedCollectible]
    @State private var selectedTab: AppTab = .today
    @State private var attention = CollectionAttentionState()
    @State private var presentedReward: PresentedCardReward?

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

    var body: some View {
        ZStack {
            TabView(selection: selectedTabBinding) {
                TodayView()
                    .tag(AppTab.today)
                    .tabItem { Label("今天", systemImage: "sun.max.fill") }

                CollectionView()
                    .tag(AppTab.collection)
                    .tabItem {
                        CollectionTabLabel(
                            hasUnseenReward: hasUnseenReward
                        )
                    }

                RewardPlaceholderView()
                    .tag(AppTab.rewards)
                    .tabItem { Label("奖励", systemImage: "gift.fill") }

                ProfileView()
                    .tag(AppTab.profile)
                    .tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
            .tint(TodayVisualTheme.ink)
            .accessibilityHidden(presentedReward != nil)
            .background {
                CollectionTabFeedbackBridge(
                    attentionToken: attention.shakeToken,
                    hasUnseenReward: hasUnseenReward,
                    reduceMotion: reduceMotion
                )
                .frame(width: 0, height: 0)
            }

            if let presentedReward {
                CardRewardOverlay(
                    kind: presentedReward.kind,
                    definition: presentedReward.definition,
                    reason: presentedReward.reason,
                    onClaim: {
                        let progress = try CardRewardService.ensureProgress(in: context)
                        try CardRewardService.claim(
                            presentedReward.model,
                            progress: progress,
                            in: context,
                            now: .now
                        )
                    },
                    onClaimed: {
                        attention.registerClaim()
                        self.presentedReward = nil
                    }
                )
                .id(presentedReward.awardKey)
                .zIndex(1)
            }
        }
        .task(id: queueHeadIdentity) {
            await presentQueueHead(queueHeadIdentity)
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

        let waitsBehindCurrentReward = presentedReward != nil
        while presentedReward != nil {
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

        presentedReward = PresentedCardReward(
            model: currentReward,
            awardKey: currentReward.awardKey,
            kind: currentReward.kind,
            reason: currentReward.reason,
            definition: definition
        )
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
        Label("收集", systemImage: "square.grid.2x2.fill")
            .accessibilityLabel(hasUnseenReward ? "收集，有未查看奖励" : "收集")
    }
}

private struct CollectionTabFeedbackBridge: UIViewRepresentable {
    let attentionToken: Int
    let hasUnseenReward: Bool
    let reduceMotion: Bool

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
            reduceMotion: reduceMotion
        )
    }

    final class Coordinator {
        private var lastAnimatedToken = 0

        func scheduleUpdate(
            from sourceView: UIView,
            attentionToken: Int,
            hasUnseenReward: Bool,
            reduceMotion: Bool,
            remainingAttempts: Int = 4
        ) {
            DispatchQueue.main.async { [weak self, weak sourceView] in
                guard let self, let sourceView else { return }
                guard let tabBar = self.findTabBar(from: sourceView) else {
                    guard remainingAttempts > 0 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.scheduleUpdate(
                            from: sourceView,
                            attentionToken: attentionToken,
                            hasUnseenReward: hasUnseenReward,
                            reduceMotion: reduceMotion,
                            remainingAttempts: remainingAttempts - 1
                        )
                    }
                    return
                }

                self.updateBadge(in: tabBar, isVisible: hasUnseenReward)
                guard attentionToken > 0, attentionToken != self.lastAnimatedToken else {
                    return
                }
                self.lastAnimatedToken = attentionToken
                self.animateCollectionItem(in: tabBar, reduceMotion: reduceMotion)
            }
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

        private func updateBadge(in tabBar: UITabBar, isVisible: Bool) {
            guard let collectionItem = tabBar.items?[safe: 1] else { return }
            collectionItem.badgeValue = isVisible ? " " : nil
            collectionItem.badgeColor = UIColor(TodayVisualTheme.reward)
            collectionItem.setBadgeTextAttributes(
                [.foregroundColor: UIColor.clear],
                for: .normal
            )
        }

        private func animateCollectionItem(in tabBar: UITabBar, reduceMotion: Bool) {
            guard let itemView = tabItemViews(in: tabBar)[safe: 1] else { return }

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

        private func tabItemViews(in tabBar: UITabBar) -> [UIControl] {
            tabBar.subviews
                .compactMap { $0 as? UIControl }
                .filter { !$0.isHidden && $0.bounds.width > 20 }
                .sorted { $0.frame.minX < $1.frame.minX }
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
