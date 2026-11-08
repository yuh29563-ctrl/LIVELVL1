import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct CardGrowthLifecycleTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([
                Item.self, Progress.self, Completion.self, CoinTransaction.self,
                CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
            ]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    @Test func levelUpPersistsAdultBeforeTheRewardIsAcknowledged() throws {
        let store = try container()
        let context = store.mainContext
        let progress = Progress(totalXP: 195)
        let item = Item(title: "完成学习", dimension: .learning, minutes: 20,
                        difficulty: 2, xp: 20, recurrence: .once)
        context.insert(progress)
        context.insert(item)
        try context.save()

        let result = try TaskRewardCoordinator.complete(
            item: item, progress: progress, in: context,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(result.completion.xp == 20)
        #expect(progress.level == 1)
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(owned.map(\.awardKey) == ["ordinary.level.1"])
        #expect(owned.first?.collectibleID == "growth.star-vortex")
        #expect(owned.first?.isUnseen == true)
        #expect(Set(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey))
            == ["ordinary.level.1", "hidden.learning.first"])
    }

    @Test func leavingAppAcknowledgesAlreadyOwnedAdultBeforeAnimationIsEligible() throws {
        let store = try container()
        let context = store.mainContext
        let progress = Progress(totalXP: 195)
        let item = Item(title: "完成学习", dimension: .learning, minutes: 20,
                        difficulty: 2, xp: 20, recurrence: .once)
        context.insert(progress)
        context.insert(item)
        try context.save()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try TaskRewardCoordinator.complete(item: item, progress: progress, in: context, now: now)
        let pending = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first { $0.kind == .ordinaryMature })
        let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
        let acquiredAt = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first?.acquiredAt)

        try CardRewardService.claim(pending, progress: collection, in: context, now: now)

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey) == ["hidden.learning.first"])
        #expect(collection.activeOrdinaryIndex == 1)
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(owned.count == 1)
        #expect(owned.first?.acquiredAt == acquiredAt)
        #expect(owned.first?.isUnseen == true)
    }

    @Test func reopeningAcknowledgesOnlyAdultsThatWereAlreadyOwned() throws {
        let store = try container()
        let context = store.mainContext
        let now = Date(timeIntervalSince1970: 10_000)
        context.insert(CollectionProgress(highestLevel: 1))
        context.insert(OwnedCollectible(
            awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
            kind: .ordinaryMature, reason: "达到 Lv.1，陪伴成熟", acquiredAt: now
        ))
        context.insert(PendingCardReward(
            awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
            kind: .ordinaryMature, reason: "达到 Lv.1，陪伴成熟", maturityLevel: 1,
            triggeredAt: now, eligibleAt: now.addingTimeInterval(60)
        ))
        context.insert(PendingCardReward(
            awardKey: "hidden.health.first-sixty-minutes", collectibleID: "hidden.long-workout",
            kind: .hiddenDiscovery, reason: "第一次完成足够时长的健康行动",
            triggeredAt: now, eligibleAt: now.addingTimeInterval(60)
        ))
        try context.save()

        let acknowledged = try CardRewardService.acknowledgeAlreadyOwnedOrdinaryRewards(
            in: context, now: now
        )
        #expect(acknowledged == ["ordinary.level.1"])
        #expect(try CardRewardService.acknowledgeAlreadyOwnedOrdinaryRewards(in: context, now: now).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)
            == ["hidden.health.first-sixty-minutes"])
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.activeOrdinaryIndex == 1)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).first?.isUnseen == true)
    }
}
