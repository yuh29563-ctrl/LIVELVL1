import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
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
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(fetchedProgress.first === collectionProgress)
        #expect(pending.map(\.awardKey) == ["ordinary.level.1"])
        #expect(owned.map(\.awardKey) == ["ordinary.level.1"])
    }

    @Test func levelOneMaturityKeepsTheJuvenileCompanionUntilClaim() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 200)
        context.insert(progress)
        try context.save()

        _ = try CardRewardService.ensureProgress(in: context)
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: Date(timeIntervalSince1970: 1_100),
            calendar: Calendar(identifier: .gregorian)
        )

        let collectionProgress = try #require(
            context.fetch(FetchDescriptor<CollectionProgress>()).first
        )
        #expect(collectionProgress.activeOrdinaryIndex == 0)
        #expect(collectionProgress.activeStage == .juvenile)
        #expect(
            try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)
                == ["ordinary.level.1"]
        )
    }

    @Test func levelTwoMaturityKeepsTheSecondJuvenileUntilAcknowledgment() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 2_200)
        context.insert(progress)
        context.insert(CollectionProgress(
            highestLevel: 1,
            activeOrdinaryIndex: 1,
            activeStage: .juvenile,
            lastProcessedMaturityLevel: 1
        ))
        context.insert(OwnedCollectible(
            awardKey: "ordinary.level.1",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "达到 Lv.1，陪伴成熟"
        ))
        try context.save()

        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 1,
            completions: [],
            in: context,
            now: Date(timeIntervalSince1970: 1_200),
            calendar: Calendar(identifier: .gregorian)
        )

        let collectionProgress = try #require(
            context.fetch(FetchDescriptor<CollectionProgress>()).first
        )
        #expect(collectionProgress.activeOrdinaryIndex == 1)
        #expect(collectionProgress.activeStage == .juvenile)
        #expect(
            try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)
                == ["ordinary.level.2"]
        )
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>())
            .contains { $0.awardKey == "ordinary.level.2" && $0.collectibleID == "ordinary.hare" })
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

    @Test func claimingAfterReachingLevelTwoShowsTheNextJuvenile() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 200)
        context.insert(progress)
        try context.save()

        _ = try CardRewardService.ensureProgress(in: context)
        let levelOneTime = Date(timeIntervalSince1970: 3_100)
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: levelOneTime,
            calendar: Calendar(identifier: .gregorian)
        )
        progress.totalXP = 2_200
        try context.save()
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 1,
            completions: [],
            in: context,
            now: levelOneTime.addingTimeInterval(10),
            calendar: Calendar(identifier: .gregorian)
        )

        let pending = try #require(
            context.fetch(FetchDescriptor<PendingCardReward>())
                .first(where: { $0.awardKey == "ordinary.level.1" })
        )
        let collectionProgress = try #require(
            context.fetch(FetchDescriptor<CollectionProgress>()).first
        )
        try CardRewardService.claim(
            pending,
            progress: collectionProgress,
            in: context,
            now: levelOneTime.addingTimeInterval(20)
        )

        let fetchedProgress = try context.fetch(FetchDescriptor<CollectionProgress>())
        #expect(fetchedProgress.first?.highestLevel == 2)
        #expect(fetchedProgress.first?.activeOrdinaryIndex == 1)
        #expect(fetchedProgress.first?.activeStage == .juvenile)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey)
            == ["ordinary.level.2"])
    }

    @Test func delayedLevelOneAcknowledgmentKeepsLaterMaturedAdultsQueued() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 6_200)
        context.insert(progress)
        try context.save()

        _ = try CardRewardService.ensureProgress(in: context)
        let triggerTime = Date(timeIntervalSince1970: 3_200)
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: triggerTime,
            calendar: Calendar(identifier: .gregorian)
        )
        let levelOneReward = try #require(
            context.fetch(FetchDescriptor<PendingCardReward>())
                .first(where: { $0.awardKey == "ordinary.level.1" })
        )
        let collectionProgress = try #require(
            context.fetch(FetchDescriptor<CollectionProgress>()).first
        )

        try CardRewardService.claim(
            levelOneReward,
            progress: collectionProgress,
            in: context,
            now: triggerTime.addingTimeInterval(2)
        )

        #expect(collectionProgress.highestLevel == 4)
        #expect(collectionProgress.activeOrdinaryIndex == 1)
        #expect(collectionProgress.activeStage == .juvenile)
        #expect(
            Set(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey))
                == ["ordinary.level.2", "ordinary.level.3"]
        )
    }

    @Test func exhaustedCatalogShowsNoOldJuvenileAndDoesNotCreateBacklog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 6_200)
        context.insert(progress)
        try context.save()
        let now = Date(timeIntervalSince1970: 3_500)

        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 0,
            completions: [],
            in: context,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )
        let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(Set(owned.map(\.awardKey)) == [
            "ordinary.level.1", "ordinary.level.2", "ordinary.level.3"
        ])
        #expect(Set(owned.map(\.collectibleID)) == Set(CollectionCatalog.ordinary.map(\.id)))

        for reward in CardRewardService.ordered(try context.fetch(FetchDescriptor<PendingCardReward>())) {
            try CardRewardService.claim(reward, progress: collection, in: context, now: now)
        }
        #expect(collection.activeOrdinaryIndex == CollectionCatalog.ordinary.count)
        #expect(CollectionCatalog.ordinary(at: collection.activeOrdinaryIndex) == nil)

        progress.totalXP = 8_200
        try context.save()
        try CardRewardService.processCompletion(
            progress: progress,
            previousLevel: 4,
            completions: [],
            in: context,
            now: now.addingTimeInterval(100),
            calendar: Calendar(identifier: .gregorian)
        )
        #expect(collection.highestLevel == 5)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).count == 3)
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
        #expect(owned.map(\.awardKey) == ["ordinary.level.1"])
    }

    @Test func rewardProcessingFailureSuppressesSuccessUntilRetrySucceeds() {
        var flow = CompletionRewardFlowState()

        flow.rewardProcessingFailed()

        #expect(flow.requiresRetry)
        #expect(!flow.allowsSuccessFeedback)

        flow.rewardProcessingSucceeded()

        #expect(!flow.requiresRetry)
        #expect(flow.allowsSuccessFeedback)
    }

    @Test func reconciliationProcessesAlreadyPersistedCompletionAndXP() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = Progress(totalXP: 200)
        let completion = Completion(
            itemID: UUID(),
            xp: 200,
            dimension: .learning,
            durationMinutes: 30,
            taskTitle: "学习"
        )
        context.insert(progress)
        context.insert(completion)
        try context.save()
        _ = try CardRewardService.ensureProgress(in: context)

        let persistedCompletions = try context.fetch(FetchDescriptor<Completion>())
        try CardRewardService.reconcile(
            progress: progress,
            completions: persistedCompletions,
            in: context,
            now: Date(timeIntervalSince1970: 4_100),
            calendar: Calendar(identifier: .gregorian)
        )

        let fetchedProgress = try context.fetch(FetchDescriptor<LIVELVL.Progress>())
        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        #expect(fetchedProgress.first?.totalXP == 200)
        #expect(persistedCompletions.count == 1)
        #expect(pending.map(\.awardKey) == ["ordinary.level.1"])
    }

    @Test func recreatedTodayViewReconcilesAMissedRewardWriteWithoutDuplicates() async throws {
        let schema = Schema([
            Item.self,
            Progress.self,
            Completion.self,
            CollectionProgress.self,
            OwnedCollectible.self,
            PendingCardReward.self,
            DimensionProfile.self,
            StateSnapshot.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let persistedStateContext = ModelContext(container)
        persistedStateContext.insert(Progress(totalXP: 200))
        persistedStateContext.insert(Completion(
            itemID: UUID(),
            xp: 200,
            dimension: .learning,
            durationMinutes: 30,
            taskTitle: "学习"
        ))
        persistedStateContext.insert(CollectionProgress())
        try persistedStateContext.save()

        let firstHost = UIHostingController(
            rootView: TodayView().modelContainer(container)
        )
        let firstWindow = UIWindow(frame: UIScreen.main.bounds)
        firstWindow.rootViewController = firstHost
        firstWindow.makeKeyAndVisible()
        defer {
            firstWindow.isHidden = true
            firstWindow.rootViewController = nil
        }

        #expect(await waitUntil {
            let pending = try? container.mainContext.fetch(
                FetchDescriptor<PendingCardReward>()
            )
            return pending?.map(\.awardKey) == ["ordinary.level.1"]
        })

        firstWindow.isHidden = true
        firstWindow.rootViewController = nil

        let recreatedHost = UIHostingController(
            rootView: TodayView().modelContainer(container)
        )
        let recreatedWindow = UIWindow(frame: UIScreen.main.bounds)
        recreatedWindow.rootViewController = recreatedHost
        recreatedWindow.makeKeyAndVisible()
        defer {
            recreatedWindow.isHidden = true
            recreatedWindow.rootViewController = nil
        }

        #expect(await waitUntil {
            let pending = try? container.mainContext.fetch(
                FetchDescriptor<PendingCardReward>()
            )
            return pending?.map(\.awardKey) == ["ordinary.level.1"]
        })
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

    @Test func markingVisibleKeysSeenPreservesOffscreenUnseenRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(OwnedCollectible(
            awardKey: "visible",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "可见"
        ))
        context.insert(OwnedCollectible(
            awardKey: "offscreen",
            collectibleID: "hidden.long-workout",
            kind: .hiddenDiscovery,
            reason: "屏幕外"
        ))
        try context.save()

        try CardRewardService.markSeen(
            awardKeys: ["visible"],
            in: context
        )

        let rows = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(rows.first(where: { $0.awardKey == "visible" })?.isUnseen == false)
        #expect(rows.first(where: { $0.awardKey == "offscreen" })?.isUnseen == true)
    }

    private func waitUntil(
        timeout: Duration = .milliseconds(500),
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if condition() {
                return true
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }

        return condition()
    }
}
