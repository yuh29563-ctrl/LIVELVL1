import Foundation
import SwiftData
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct CardRewardPresentationTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Item.self,
            Progress.self,
            Completion.self,
            CollectionProgress.self,
            OwnedCollectible.self,
            PendingCardReward.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    private func snapshot(awardKey: String = "ordinary.level.1") -> PresentedCardReward {
        PresentedCardReward(
            awardKey: awardKey,
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟",
            definition: CollectionCatalog.ordinary[0]
        )
    }

    @Test func claimRegistersAttention() {
        var state = CollectionAttentionState()
        let token = state.registerClaim()
        #expect(token == 1)
        #expect(state.shakeToken == 1)
        #expect(state.hasUnseenReward)
        state.markSeen()
        #expect(!state.hasUnseenReward)
    }

    @Test func staleIdlePresentationDismissesWhenItsPendingRowDisappears() {
        let reward = snapshot()
        var state = CardRewardPresentationState()
        state.present(reward)

        let didDismiss = state.reconcile(liveAwardKeys: [])

        #expect(didDismiss)
        #expect(state.presentedReward == nil)
    }

    @Test func locallyClaimedSnapshotSurvivesUntilItsMatchingTabFeedbackCompletes() {
        let reward = snapshot()
        var state = CardRewardPresentationState()
        state.present(reward)
        let didBeginClaim = state.beginSuccessfulClaim(awardKey: reward.awardKey)
        #expect(didBeginClaim)

        let didDismissEarly = state.reconcile(liveAwardKeys: [])
        #expect(!didDismissEarly)
        #expect(state.presentedReward == reward)

        let didBeginWaiting = state.waitForCollectionFeedback(
            awardKey: reward.awardKey,
            attentionToken: 7
        )
        #expect(didBeginWaiting)
        let wrongFeedbackAwardKey = state.finishSuccessfulClaim(feedbackToken: 6)
        #expect(wrongFeedbackAwardKey == nil)
        #expect(state.presentedReward == reward)
        let completedAwardKey = state.finishSuccessfulClaim(feedbackToken: 7)
        #expect(completedAwardKey == reward.awardKey)
        #expect(state.presentedReward == nil)
        #expect(state.finishSuccessfulClaim(feedbackToken: 7) == nil)
    }

    @Test func futureRewardNoOpDoesNotReportAClaimPostcondition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 8_000)
        context.insert(PendingCardReward(
            awardKey: "ordinary.level.1",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟",
            maturityLevel: 1,
            triggeredAt: now,
            eligibleAt: now.addingTimeInterval(10)
        ))
        try context.save()

        let didClaim = try CardRewardClaimCoordinator.claim(
            awardKey: "ordinary.level.1",
            in: context,
            now: now
        )

        #expect(!didClaim)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
    }

    @Test func eligibleRewardReportsSuccessOnlyAfterPersistencePostconditions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 9_000)
        context.insert(PendingCardReward(
            awardKey: "hidden.health.first-sixty-minutes",
            collectibleID: "hidden.long-workout",
            kind: .hiddenDiscovery,
            reason: "第一次完成至少 60 分钟的健康行动",
            triggeredAt: now.addingTimeInterval(-2),
            eligibleAt: now.addingTimeInterval(-1)
        ))
        try context.save()

        let didClaim = try CardRewardClaimCoordinator.claim(
            awardKey: "hidden.health.first-sixty-minutes",
            in: context,
            now: now
        )

        #expect(didClaim)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(
            try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)
                == ["hidden.health.first-sixty-minutes"]
        )
    }

    @Test func latestFeedbackGenerationRejectsObsoleteRetryAndDuplicateAnimation() throws {
        var state = CollectionTabFeedbackGenerationState()
        let obsolete = state.replaceDesiredState(
            attentionToken: 1,
            hasUnseenReward: true,
            reduceMotion: false
        )
        let latest = state.replaceDesiredState(
            attentionToken: 2,
            hasUnseenReward: false,
            reduceMotion: true
        )

        #expect(!state.isCurrent(obsolete))
        #expect(state.takeAnimationToken(for: obsolete) == nil)
        #expect(state.isCurrent(latest))
        #expect(state.takeAnimationToken(for: latest) == 2)
        #expect(state.takeAnimationToken(for: latest) == nil)

        state.cancel()
        #expect(!state.isCurrent(latest))
    }

    @Test func reducedMotionCollectionAttentionUsesNoSpatialTransform() {
        let plan = CollectionTabFeedbackAnimationPlan(reduceMotion: true)

        #expect(plan.shakeTranslations.isEmpty)
        #expect(plan.bounceScales.isEmpty)
        #expect(plan.initialPulseScale == 1)
        #expect(plan.finalPulseScale == 1)
    }

    @Test func ordinaryCollectionAttentionRetainsItsSmallSpatialFeedback() {
        let plan = CollectionTabFeedbackAnimationPlan(reduceMotion: false)

        #expect(plan.shakeTranslations == [0, -5, 4, -3, 2, 0])
        #expect(plan.bounceScales == [1, 0.88, 1.16, 0.96, 1])
        #expect(plan.initialPulseScale == 0.65)
        #expect(plan.finalPulseScale == 1.45)
    }

    @Test func successiveRewardStartsExactlyAQuarterSecondAfterDismissalCompletes() {
        var handoff = CardRewardHandoffState()
        let dismissalCompletedAt = Date(timeIntervalSince1970: 12_000)
        handoff.recordDismissalCompletion(at: dismissalCompletedAt)

        #expect(handoff.generation == 1)
        #expect(
            handoff.presentationNotBefore(
                rewardEligibleAt: dismissalCompletedAt.addingTimeInterval(-5)
            ) == dismissalCompletedAt.addingTimeInterval(0.25)
        )
    }

    @Test func laterRewardEligibilityRemainsAuthoritativeAfterDismissal() {
        var handoff = CardRewardHandoffState()
        let dismissalCompletedAt = Date(timeIntervalSince1970: 12_100)
        let eligibleAt = dismissalCompletedAt.addingTimeInterval(2)
        handoff.recordDismissalCompletion(at: dismissalCompletedAt)

        #expect(handoff.presentationNotBefore(rewardEligibleAt: eligibleAt) == eligibleAt)
    }

    @Test func collectionTargetResolvesByStableIdentityAfterReordering() throws {
        let today = UITabBarItem(title: "Today", image: nil, selectedImage: nil)
        let collection = UITabBarItem(
            title: "任意本地化标题",
            image: UIImage(systemName: CollectionTabIdentity.systemImageName),
            selectedImage: nil
        )
        let rewards = UITabBarItem(title: "Rewards", image: nil, selectedImage: nil)
        let profile = UITabBarItem(title: "Profile", image: nil, selectedImage: nil)
        let tabBar = UITabBar()
        tabBar.items = [profile, rewards, collection, today]

        let resolved = try #require(CollectionTabTargetResolver.item(in: tabBar))

        #expect(resolved === collection)
    }

    @Test func collectionTargetUsesTheCollectionItemPositionInsteadOfAnAdjacentTab() throws {
        let today = UITabBarItem(title: "今天", image: nil, selectedImage: nil)
        let collection = UITabBarItem(title: "收集", image: nil, selectedImage: nil)
        collection.accessibilityIdentifier = CollectionTabIdentity.accessibilityIdentifier
        let rewards = UITabBarItem(title: "奖励", image: nil, selectedImage: nil)
        let profile = UITabBarItem(title: "我的", image: nil, selectedImage: nil)
        let tabBar = UITabBar(frame: CGRect(x: 0, y: 0, width: 400, height: 60))
        tabBar.items = [today, collection, rewards, profile]

        let controls = (0..<4).map { index in
            let control = UIControl(frame: CGRect(x: CGFloat(index) * 100, y: 0, width: 100, height: 60))
            tabBar.addSubview(control)
            return control
        }

        let target = try #require(CollectionTabTargetResolver.itemView(in: tabBar))

        #expect(target === controls[1])
    }

    @Test func collectionTargetIgnoresExtraUIKitControlsAndChoosesTheNearestStableSlot() throws {
        let today = UITabBarItem(title: "今天", image: nil, selectedImage: nil)
        let collection = UITabBarItem(title: "收集", image: nil, selectedImage: nil)
        collection.accessibilityIdentifier = CollectionTabIdentity.accessibilityIdentifier
        let rewards = UITabBarItem(title: "奖励", image: nil, selectedImage: nil)
        let profile = UITabBarItem(title: "我的", image: nil, selectedImage: nil)
        let tabBar = UITabBar(frame: CGRect(x: 0, y: 0, width: 400, height: 60))
        tabBar.items = [today, collection, rewards, profile]

        let decorationControl = UIControl(frame: CGRect(x: 0, y: 0, width: 20, height: 60))
        tabBar.addSubview(decorationControl)
        let controls = (0..<4).map { index in
            let control = UIControl(frame: CGRect(x: CGFloat(index) * 100, y: 0, width: 100, height: 60))
            tabBar.addSubview(control)
            return control
        }

        let target = try #require(CollectionTabTargetResolver.itemView(in: tabBar))

        #expect(target === controls[1])
    }

    @Test func collectionTargetFallsBackToTheStableSlotBeforeUIKitCreatesItemControls() throws {
        let today = UITabBarItem(title: "今天", image: nil, selectedImage: nil)
        let collection = UITabBarItem(title: "收集", image: nil, selectedImage: nil)
        collection.accessibilityIdentifier = CollectionTabIdentity.accessibilityIdentifier
        let rewards = UITabBarItem(title: "奖励", image: nil, selectedImage: nil)
        let profile = UITabBarItem(title: "我的", image: nil, selectedImage: nil)
        let tabBar = UITabBar(frame: CGRect(x: 0, y: 0, width: 400, height: 80))
        tabBar.items = [today, collection, rewards, profile]

        let target = try #require(CollectionTabTargetResolver.targetFrame(in: tabBar))

        #expect(target == CGRect(x: 128, y: 18, width: 44, height: 44))
    }

    @Test func flightOffsetUsesMeasuredFramesInEitherLayoutDirection() {
        let cardFrame = CGRect(x: 100, y: 200, width: 200, height: 300)
        let standardTarget = CGRect(x: 70, y: 760, width: 60, height: 40)
        let rtlTarget = CGRect(x: 310, y: 760, width: 60, height: 40)

        #expect(
            CardRewardFlightGeometry.offset(from: cardFrame, to: standardTarget)
                == CGSize(width: -100, height: 430)
        )
        #expect(
            CardRewardFlightGeometry.offset(from: cardFrame, to: rtlTarget)
                == CGSize(width: 140, height: 430)
        )
    }

    @Test func offCenterCardLocalTransformLandsOnMeasuredTarget() {
        let scrollFrame = CGRect(x: 0, y: 0, width: 400, height: 800)
        let cardFrame = CGRect(x: 40, y: 100, width: 240, height: 320)
        let targetFrame = CGRect(x: 280, y: 720, width: 40, height: 40)

        let transform = CardRewardFlightGeometry.transform(
            from: cardFrame,
            to: targetFrame,
            scale: 0.15
        )
        let projectedCardFrame = transform.projectedFrame(of: cardFrame)

        #expect(abs(projectedCardFrame.midX - 300) < 0.001)
        #expect(abs(projectedCardFrame.midY - 740) < 0.001)
        #expect(abs(projectedCardFrame.width - 36) < 0.001)
        #expect(abs(projectedCardFrame.height - 48) < 0.001)

        let legacyScaledX = (cardFrame.midX - scrollFrame.midX) * 0.15
        let legacyScaledY = (cardFrame.midY - scrollFrame.midY) * 0.15
        let legacyScrollAnchoredCenter = CGPoint(
            x: scrollFrame.midX + legacyScaledX + 140,
            y: scrollFrame.midY + legacyScaledY + 480
        )
        #expect(abs(legacyScrollAnchoredCenter.x - 334) < 0.001)
        #expect(abs(legacyScrollAnchoredCenter.y - 859) < 0.001)
        #expect(legacyScrollAnchoredCenter != CGPoint(x: 300, y: 740))
    }

    @Test func standardClaimFlightKeepsTheRewardVisibleUntilItsCollectionArrival() {
        let plan = CardRewardClaimAnimationPlan(reduceMotion: false)

        #expect(plan.buttonPressScale == 0.94)
        #expect(plan.buttonPressDuration == 0.1)
        #expect(plan.liftDuration == 0.12)
        #expect(plan.travelDuration == 0.44)
        #expect(plan.implodeDuration == 0.16)
        #expect(plan.initialCardOpacity == 1)
        #expect(plan.arrivalCardScale == 0)
        #expect(plan.arrivalCardOpacity == 0)
        #expect(plan.usesSpatialFlight)
    }

    @Test func flightTrajectoryUsesTheOverlayCenterInsteadOfAnUnmeasuredCardFrame() {
        let overlayFrame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let targetFrame = CGRect(
            x: 109.6666666667,
            y: 795,
            width: 98,
            height: 54
        )

        let trajectory = CardRewardFlightTrajectory.make(
            in: overlayFrame,
            to: targetFrame
        )

        #expect(trajectory.lift.center == CGPoint(x: 201, y: 415))
        #expect(trajectory.lift.scale == 1.02)
        #expect(abs(trajectory.approach.center.x - 170.52) < 0.001)
        #expect(abs(trajectory.approach.center.y - 660.2) < 0.001)
        #expect(trajectory.approach.scale == 0.34)
        #expect(trajectory.approach.opacity == 1)
        #expect(abs(trajectory.arrival.center.x - 158.6666666667) < 0.001)
        #expect(trajectory.arrival.center.y == 822)
        #expect(trajectory.arrival.scale == 0)
        #expect(trajectory.arrival.opacity == 0)
        #expect(trajectory.arrival.center.x < overlayFrame.midX)
    }

    @Test func spatialClaimWaitsForATargetWhileReducedMotionCanFadeInPlace() {
        #expect(!CardRewardClaimReadiness.canClaim(
            collectionTargetFrame: nil,
            reduceMotion: false
        ))
        #expect(CardRewardClaimReadiness.canClaim(
            collectionTargetFrame: CGRect(x: 10, y: 20, width: 44, height: 44),
            reduceMotion: false
        ))
        #expect(CardRewardClaimReadiness.canClaim(
            collectionTargetFrame: nil,
            reduceMotion: true
        ))
    }

    @Test func reducedMotionClaimAvoidsSpatialFlight() {
        let plan = CardRewardClaimAnimationPlan(reduceMotion: true)

        #expect(plan.buttonPressScale == 1)
        #expect(plan.implodeDuration == 0.2)
        #expect(!plan.usesSpatialFlight)
    }
}
