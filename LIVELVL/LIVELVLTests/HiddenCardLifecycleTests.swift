import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct HiddenCardLifecycleTests {
    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private func store() throws -> ModelContainer {
        try ModelContainer(for: Schema([Item.self, LIVELVL.Progress.self, Completion.self,
            CoinTransaction.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self]),
            configurations: .init(isStoredInMemoryOnly: true))
    }

    @Test func currentCompletionCreatesOneHiddenRewardAndRetryDoesNotDuplicate() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        context.insert(progress)
        let completion = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(completion)
        try context.save()
        for _ in 0..<2 {
            try CardRewardService.processCompletion(progress: progress, previousLevel: 0,
                completions: [completion], in: context, now: now, calendar: .current)
        }
        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        #expect(pending.map(\.awardKey) == ["hidden.health.first"])
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
    }

    @Test func revokingLastEvidenceReclaimsPendingAndOwnedHiddenCardsOnly() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        let completion = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(progress); context.insert(completion); context.insert(CollectionProgress())
        context.insert(OwnedCollectible(awardKey: "hidden.health.first", collectibleID: "hidden.health.first",
                                       kind: .hiddenDiscovery, reason: "第一次完成健康任务"))
        context.insert(PendingCardReward(awardKey: "hidden.health.first", collectibleID: "hidden.health.first",
            kind: .hiddenDiscovery, reason: "第一次完成健康任务", triggeredAt: now, eligibleAt: now))
        context.insert(OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
                                       kind: .ordinaryMature, reason: "保持成长卡"))
        context.insert(OwnedCollectible(awardKey: "hidden.legacy.keep", collectibleID: "hidden.legacy.keep",
                                       kind: .hiddenDiscovery, reason: "保留旧隐藏卡"))
        context.insert(PendingCardReward(awardKey: "hidden.legacy.pending", collectibleID: "hidden.legacy.pending",
            kind: .hiddenDiscovery, reason: "保留旧队列", triggeredAt: now, eligibleAt: now))
        try context.save()
        #expect(try TaskRewardCoordinator.revoke(completion: completion, progress: progress,
                                                in: context, now: now.addingTimeInterval(1)))
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey) == ["hidden.legacy.pending"])
        #expect(Set(try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey))
            == ["ordinary.level.1", "hidden.legacy.keep"])
    }
    @Test func activationIsOnceAndHistoricalOrFutureOrUnclassifiedRecordsNeverQualify() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress(totalXP: 0)
        context.insert(progress)
        context.insert(Completion(itemID: UUID(), xp: 80, dimension: .learning,
                                  durationMinutes: 60, date: now.addingTimeInterval(-1)))
        try context.save()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        try CardRewardService.activateHiddenCards(in: context, now: now, calendar: calendar)
        try CardRewardService.activateHiddenCards(in: context, now: now.addingTimeInterval(100), calendar: .current)
        context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health,
                                  date: now.addingTimeInterval(10)))
        context.insert(Completion(itemID: UUID(), xp: 80, date: now))
        try context.save()
        try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
        let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
        #expect(collection.hiddenCardsEnabledAt == now)
        #expect(collection.hiddenCardsTimeZoneIdentifier == "Asia/Shanghai")
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        let current = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(current); try context.save()
        try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey) == ["hidden.health.first"])
    }

    @Test func claimRevokeAndReearnUsesOneIdentityAndKeepsRecordedDimension() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        let task = Item(title: "新行动", dimension: .health, minutes: 1, difficulty: 1, xp: 10, recurrence: .daily)
        context.insert(progress); context.insert(task); try context.save()
        try CardRewardService.activateHiddenCards(in: context, now: now, calendar: .current)
        let completed = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        task.dimension = .learning; try context.save()
        try CardRewardService.reconcilePersistedRewards(in: context, now: now.addingTimeInterval(2), calendar: .current)
        #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context,
                                                   now: now.addingTimeInterval(2)))
        #expect(try !CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context,
                                                    now: now.addingTimeInterval(3)))
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey) == ["hidden.health.first"])
        #expect(try TaskRewardCoordinator.revoke(completion: completed.completion, progress: progress,
                                                in: context, now: now.addingTimeInterval(4)))
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        task.dimension = .health; try context.save()
        _ = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now.addingTimeInterval(5))
        #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context,
                                                   now: now.addingTimeInterval(7)))
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
        #expect(try CoinLedgerService.balance(in: context) == 10)
    }

    @Test func staleClaimCannotUseDeletedEvidenceFromAnotherContext() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        let record = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(progress); context.insert(record); try context.save()
        try CardRewardService.processCompletion(progress: progress, previousLevel: 0,
            completions: [record], in: context, now: now, calendar: .current)
        let staleReward = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first)
        let writer = ModelContext(store)
        for record in try writer.fetch(FetchDescriptor<Completion>()) { writer.delete(record) }
        try writer.save()
        let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
        try CardRewardService.claim(staleReward, progress: collection, in: context, now: now.addingTimeInterval(2))
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
    }

    @Test func revocationRemovesOnlyUnsupportedMilestonesAndKeepsOtherDimensions() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        context.insert(progress)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        try CardRewardService.activateHiddenCards(in: context, now: now, calendar: calendar)
        var records: [Completion] = []
        for day in 0..<35 {
            let record = Completion(itemID: UUID(), xp: 0, dimension: .health,
                date: calendar.date(byAdding: .day, value: day, to: now)!)
            context.insert(record); records.append(record)
        }
        context.insert(Completion(itemID: UUID(), xp: 0, dimension: .learning, date: now))
        try context.save()
        let later = calendar.date(byAdding: .day, value: 40, to: now)!
        try CardRewardService.reconcilePersistedRewards(in: context, now: later, calendar: .current)
        for reward in try context.fetch(FetchDescriptor<PendingCardReward>()) {
            try CardRewardService.claim(reward, progress: try CardRewardService.ensureProgress(in: context),
                                        in: context, now: later.addingTimeInterval(2))
        }
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 7)
        #expect(try TaskRewardCoordinator.revoke(completion: records[20], progress: progress, in: context, now: later.addingTimeInterval(3)))
        #expect(Set(try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)) ==
            ["hidden.health.first", "hidden.health.streak.7", "hidden.health.streak.14", "hidden.learning.first"])
    }

    @Test func zeroXPCompletionUnlocksHiddenCardInTheSameTransaction() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress(totalXP: 400)
        let task = Item(title: "健康", dimension: .health, minutes: 1, difficulty: 1, xp: 10, recurrence: .daily)
        context.insert(progress); context.insert(task)
        context.insert(Completion(itemID: UUID(), xp: 400, date: now))
        try context.save()
        try CardRewardService.activateHiddenCards(in: context, now: now, calendar: .current)
        let result = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        #expect(result.completion.xp == 0)
        #expect(progress.totalXP == 400)
        #expect(try CoinLedgerService.balance(in: context) == 10)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).contains { $0.awardKey == "hidden.health.first" })
    }

    @Test func switchingSuppliedTimeZoneCannotRegroupEnabledCalendarDays() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        context.insert(progress)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = utc.startOfDay(for: now)
        try CardRewardService.activateHiddenCards(in: context, now: start, calendar: utc)
        for day in 0..<7 {
            let date = utc.date(byAdding: .hour, value: day * 24 + (day.isMultiple(of: 2) ? 1 : 23), to: start)!
            context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health, date: date))
        }
        try context.save()
        var changed = utc
        changed.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let later = utc.date(byAdding: .day, value: 8, to: start)!
        try CardRewardService.reconcilePersistedRewards(in: context, now: later, calendar: changed)
        #expect(Set(try context.fetch(FetchDescriptor<PendingCardReward>()).map(\.awardKey))
            == ["hidden.health.first", "hidden.health.streak.7"])
    }

    @Test func clockRollbackKeepsEarnedCardButRealRevocationStillReclaimsIt() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        context.insert(progress); try context.save()
        let enabledAt = now.addingTimeInterval(-1)
        try CardRewardService.activateHiddenCards(in: context, now: enabledAt, calendar: .current)
        let record = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(record); try context.save()
        try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
        let acquiredAt = now.addingTimeInterval(2)
        #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: acquiredAt))
        let rollback = now.addingTimeInterval(-10)
        try CardRewardService.reconcilePersistedRewards(in: context, now: rollback, calendar: .current)
        let owned = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
        #expect(owned.awardKey == "hidden.health.first")
        #expect(owned.acquiredAt == acquiredAt && owned.isUnseen)
        #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 1)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.hiddenCardsEnabledAt == enabledAt)
        #expect(try TaskRewardCoordinator.revoke(completion: record, progress: progress, in: context, now: rollback))
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
    }

    @Test func clockRollbackKeepsPendingStreakWithoutIssuingFutureMilestones() throws {
        let store = try store(), context = store.mainContext
        let progress = LIVELVL.Progress()
        context.insert(progress)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        try CardRewardService.activateHiddenCards(in: context, now: now, calendar: calendar)
        for day in 0..<7 {
            context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health,
                date: calendar.date(byAdding: .day, value: day, to: now)!))
        }
        try context.save()
        let reached = calendar.date(byAdding: .day, value: 6, to: now)!
        try CardRewardService.reconcilePersistedRewards(in: context, now: reached, calendar: calendar)
        let initial = try context.fetch(FetchDescriptor<PendingCardReward>())
        let originalDates = Dictionary(uniqueKeysWithValues: initial.map { ($0.awardKey, [$0.triggeredAt, $0.eligibleAt]) })
        #expect(Set(originalDates.keys) == ["hidden.health.first", "hidden.health.streak.7"])
        context.insert(Completion(itemID: UUID(), xp: 0, dimension: .learning,
            date: calendar.date(byAdding: .day, value: 8, to: now)!))
        try context.save()
        let rollback = calendar.date(byAdding: .day, value: 5, to: now)!
        for time in [rollback, rollback, reached.addingTimeInterval(2)] {
            try CardRewardService.reconcilePersistedRewards(in: context, now: time, calendar: calendar)
            let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
            #expect(Dictionary(uniqueKeysWithValues: pending.map { ($0.awardKey, [$0.triggeredAt, $0.eligibleAt]) }) == originalDates)
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        }
        #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.streak.7", in: context,
                                                   now: reached.addingTimeInterval(3)))
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 1)
    }

}
