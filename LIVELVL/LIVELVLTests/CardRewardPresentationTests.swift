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
        state.registerClaim()
        #expect(state.shakeToken == 1)
        #expect(state.hasUnseenReward)
        state.markSeen()
        #expect(!state.hasUnseenReward)
    }

    @Test func staleIdlePresentationDismissesWhenItsPendingRowDisappears() {
        let reward = snapshot()
        var state = CardRewardPresentationState()
        state.present(reward)

        state.reconcile(liveAwardKeys: [])

        #expect(state.presentedReward == nil)
    }

    @Test func locallyClaimedSnapshotSurvivesOnlyThroughItsSuccessAnimation() {
        let reward = snapshot()
        var state = CardRewardPresentationState()
        state.present(reward)
        let didBeginClaim = state.beginSuccessfulClaim(awardKey: reward.awardKey)
        #expect(didBeginClaim)

        state.reconcile(liveAwardKeys: [])
        #expect(state.presentedReward == reward)

        state.finishSuccessfulClaim(awardKey: reward.awardKey)
        #expect(state.presentedReward == nil)
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
}
