import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct CardRewardServiceTests {
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

    @Test func processingTheSameMaturityTwiceEnqueuesOneReward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 200)
        context.insert(progress)
        try context.save()

        let collectionProgress = try CardRewardService.ensureProgress(in: context)
        let now = Date(timeIntervalSince1970: 1_000)
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        let fetchedProgress = try context.fetch(FetchDescriptor<CollectionProgress>())
        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        #expect(fetchedProgress.first === collectionProgress)
        #expect(pending.map(\.awardKey) == ["ordinary.level.1"])
    }

    @Test func ordinaryRewardsSortBeforeHiddenRewardsAtTheSameTime() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 2_000)
        context.insert(PendingCardReward(
            awardKey: "hidden.study.three-day-streak",
            collectibleID: "hidden.study-streak",
            kind: .hiddenDiscovery,
            reason: "连续 3 天完成学习行动",
            triggeredAt: timestamp,
            eligibleAt: timestamp
        ))
        context.insert(PendingCardReward(
            awardKey: "ordinary.level.1",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟",
            maturityLevel: 1,
            triggeredAt: timestamp,
            eligibleAt: timestamp
        ))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PendingCardReward>())
        let ordered = CardRewardService.ordered(fetched)
        #expect(ordered.map(\.awardKey) == [
            "ordinary.level.1",
            "hidden.study.three-day-streak",
        ])
    }

    @Test func claimingOrdinaryRewardArchivesItAndAdvancesCompanion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(CollectionProgress())
        let pending = PendingCardReward(
            awardKey: "ordinary.level.1",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟",
            maturityLevel: 1,
            triggeredAt: Date(timeIntervalSince1970: 3_000),
            eligibleAt: Date(timeIntervalSince1970: 3_001.6)
        )
        context.insert(pending)
        try context.save()

        let progress = try #require(
            context.fetch(FetchDescriptor<CollectionProgress>()).first
        )
        try CardRewardService.claim(
            pending,
            progress: progress,
            in: context,
            now: Date(timeIntervalSince1970: 3_010)
        )

        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        let remainingPending = try context.fetch(FetchDescriptor<PendingCardReward>())
        let fetchedProgress = try context.fetch(FetchDescriptor<CollectionProgress>())
        #expect(owned.count == 1)
        #expect(owned.first?.awardKey == "ordinary.level.1")
        #expect(remainingPending.isEmpty)
        #expect(fetchedProgress.first?.activeOrdinaryIndex == 1)
        #expect(fetchedProgress.first?.activeStage == .juvenile)
        #expect(fetchedProgress.first?.lastProcessedMaturityLevel == 1)
    }

    @Test func loweringXPCannotRegressHighestLevelOrDuplicateOriginalReward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 200)
        context.insert(progress)
        try context.save()

        _ = try CardRewardService.ensureProgress(in: context)
        let now = Date(timeIntervalSince1970: 4_000)
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )
        progress.totalXP = 0
        try context.save()
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 1,
            completions: [],
            in: context,
            now: now.addingTimeInterval(100),
            calendar: Calendar(identifier: .gregorian)
        )

        let fetchedProgress = try context.fetch(FetchDescriptor<CollectionProgress>())
        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(fetchedProgress.first?.highestLevel == 1)
        #expect(pending.map(\.awardKey) == ["ordinary.level.1"])
        #expect(owned.isEmpty)
    }

    @Test func markingAllSeenClearsEveryUnseenFlag() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(OwnedCollectible(
            awardKey: "ordinary.level.1",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟"
        ))
        context.insert(OwnedCollectible(
            awardKey: "hidden.health.first-sixty-minutes",
            collectibleID: "hidden.long-workout",
            kind: .hiddenDiscovery,
            reason: "第一次完成至少 60 分钟的健康行动"
        ))
        try context.save()

        try CardRewardService.markAllSeen(in: context)

        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(owned.count == 2)
        #expect(owned.allSatisfy { !$0.isUnseen })
    }
}
