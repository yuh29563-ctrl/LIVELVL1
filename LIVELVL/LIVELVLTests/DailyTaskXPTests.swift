import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct DailyTaskXPTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([
                Item.self, LIVELVL.Progress.self, Completion.self, CoinTransaction.self,
                CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
            ]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    private func item(xp: Int = 80) -> Item {
        Item(title: "行动", dimension: .learning, minutes: 30,
             difficulty: 2, xp: xp, recurrence: .daily)
    }

    @Test func partialAwardCapsXPButKeepsFullCoins() throws {
        let store = try container()
        let context = store.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = LIVELVL.Progress(totalXP: 350)
        let task = item()
        context.insert(progress)
        context.insert(task)
        context.insert(Completion(itemID: UUID(), xp: 350, date: now))
        try context.save()

        let completion = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)

        #expect(completion.completion.xp == 50)
        #expect(completion.completion.nominalXP == 80)
        #expect(completion.wasCreated)
        #expect(progress.totalXP == 400)
        #expect(try CoinLedgerService.balance(in: context) == 80)
    }

    @Test func legacyOverCapStillAllowsZeroXPCompletionAndCoins() throws {
        let store = try container()
        let context = store.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = LIVELVL.Progress(totalXP: 650)
        let task = item()
        context.insert(progress)
        context.insert(task)
        context.insert(Completion(itemID: UUID(), xp: 650, date: now))
        try context.save()

        let completion = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)

        #expect(completion.completion.xp == 0)
        #expect(progress.totalXP == 650)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 2)
        #expect(try CoinLedgerService.balance(in: context) == 80)
    }

    @Test func repeatedCompletionDoesNotAwardTwice() throws {
        let store = try container()
        let context = store.mainContext
        let progress = LIVELVL.Progress()
        let task = item()
        context.insert(progress)
        context.insert(task)
        try context.save()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let first = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)
        let second = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context, now: now)

        #expect(first.completion.id == second.completion.id)
        #expect(!second.wasCreated)
        #expect(progress.totalXP == 80)
        #expect(try CoinLedgerService.balance(in: context) == 80)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
    }

    @Test func zeroXPFeedbackNeverFlowsIntoTheGrowthCore() {
        let feedback = TaskRewardFeedback(itemID: UUID(), xp: 0, dimension: .learning,
                                          levelBefore: 1, levelAfter: 1)
        var state = TodayGrowthPresentationState()
        state.begin(feedback)
        state.advance()
        #expect(state.phase == .idle)
        #expect(state.feedback == nil)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func revokeReleasesOnlyActualXPAndDoesNotTopUpOtherRecords() throws {
        let store = try container()
        let context = store.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = LIVELVL.Progress()
        let firstTask = item(xp: 350)
        let secondTask = item()
        let thirdTask = item(xp: 30)
        context.insert(progress)
        for task in [firstTask, secondTask, thirdTask] { context.insert(task) }
        try context.save()
        let first = try TaskRewardCoordinator.complete(item: firstTask, progress: progress, in: context, now: now).completion
        let second = try TaskRewardCoordinator.complete(item: secondTask, progress: progress, in: context, now: now).completion
        let third = try TaskRewardCoordinator.complete(item: thirdTask, progress: progress, in: context, now: now).completion
        #expect(second.xp == 50)
        #expect(third.xp == 0)

        #expect(try TaskRewardCoordinator.revoke(completion: first, progress: progress, in: context))
        #expect(progress.totalXP == 50)
        #expect(second.xp == 50)
        #expect(third.xp == 0)
        #expect(try CoinLedgerService.balance(in: context) == 110)

        #expect(try TaskRewardCoordinator.revoke(completion: second, progress: progress, in: context))
        #expect(progress.totalXP == 0)
        #expect(try CoinLedgerService.balance(in: context) == 30)
        #expect(try !TaskRewardCoordinator.revoke(completion: second, progress: progress, in: context))
        #expect(progress.totalXP == 0)
        #expect(try CoinLedgerService.balance(in: context) == 30)

        let again = try TaskRewardCoordinator.complete(item: secondTask, progress: progress, in: context, now: now)
        #expect(again.wasCreated)
        #expect(again.completion.xp == 80)
        #expect(progress.totalXP == 80)
        #expect(try CoinLedgerService.balance(in: context) == 110)
    }

    @Test func midnightResetsAllowanceAndCrossDayRevokeCannotIncreaseTodayAllowance() throws {
        let store = try container()
        let context = store.mainContext
        let midnight = try #require(utc.date(from: DateComponents(year: 2026, month: 9, day: 22)))
        let progress = LIVELVL.Progress()
        let task = item(xp: 500)
        context.insert(progress)
        context.insert(task)
        try context.save()
        let yesterday = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context,
                                                           now: midnight.addingTimeInterval(-1), calendar: utc).completion
        let today = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context,
                                                       now: midnight, calendar: utc).completion
        #expect(yesterday.xp == 400)
        #expect(today.xp == 400)
        try TaskRewardCoordinator.revoke(completion: yesterday, progress: progress, in: context, now: midnight)
        let preview = try TaskRewardCoordinator.preview(nominalXP: 80,
            completions: context.fetch(FetchDescriptor<Completion>()), now: midnight, calendar: utc)
        #expect(preview.awardedXP == 0)
        #expect(progress.totalXP == 400)
    }

    @Test func timeZoneChangeRegroupsDatesWithoutChangingRecordedXP() throws {
        let date = try #require(utc.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 20)))
        let earlier = Completion(itemID: UUID(), xp: 350, date: date.addingTimeInterval(-12 * 3600))
        var shanghai = utc
        shanghai.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let old = try TaskRewardCoordinator.preview(nominalXP: 80, completions: [earlier], now: date, calendar: utc)
        let new = try TaskRewardCoordinator.preview(nominalXP: 80, completions: [earlier], now: date, calendar: shanghai)
        #expect(old.awardedXP == 50)
        #expect(new.awardedXP == 80)
        #expect(earlier.xp == 350)
    }

    @Test(arguments: [(2026, 3, 8, 23), (2026, 11, 1, 25)])
    func daylightSavingUsesCalendarDays(year: Int, month: Int, day: Int, hours: Int) throws {
        var calendar = utc
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let noon = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        let interval = try DailyTaskXPPolicy.day(containing: noon, calendar: calendar)
        #expect(interval.duration == Double(hours * 3600))
        let records = [
            Completion(itemID: UUID(), xp: 80, date: interval.start.addingTimeInterval(-1)),
            Completion(itemID: UUID(), xp: 100, date: interval.start),
            Completion(itemID: UUID(), xp: 250, date: interval.end.addingTimeInterval(-1)),
            Completion(itemID: UUID(), xp: 80, date: interval.end)
        ]
        let allowance = try TaskRewardCoordinator.preview(nominalXP: 80, completions: records, now: noon, calendar: calendar)
        #expect(allowance.earnedXP == 350)
        #expect(allowance.awardedXP == 50)
    }

    @Test func savingUsesLatestAllowanceInsteadOfPreviouslyPreviewedAmount() throws {
        let store = try container()
        let context = store.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = LIVELVL.Progress()
        let first = item(xp: 380)
        let second = item(xp: 80)
        context.insert(progress)
        context.insert(first)
        context.insert(second)
        try context.save()
        let preview = try TaskRewardCoordinator.preview(nominalXP: 80, completions: [], now: now, calendar: utc)
        #expect(preview.awardedXP == 80)
        _ = try TaskRewardCoordinator.complete(item: first, progress: progress, in: context, now: now, calendar: utc)
        let result = try TaskRewardCoordinator.complete(item: second, progress: progress, in: context, now: now, calendar: utc)
        #expect(result.completion.xp == 20)
    }

    @Test func reversalUsesOriginalCoinLedgerEvenIfSnapshotDiffers() throws {
        let store = try container()
        let context = store.mainContext
        let completion = Completion(itemID: UUID(), xp: 20, nominalXP: 80)
        context.insert(completion)
        context.insert(CoinTransaction(operationKey: "task-earned:\(completion.id!.uuidString)",
            kind: .taskEarned, amountCoinUnits: 60, requestedCoinUnits: 60,
            sourceID: completion.id, createdAt: .now, note: "旧流水"))
        try context.save()
        try CoinLedgerService.reverseTask(completion: completion, in: context)
        let reversal = try #require(context.fetch(FetchDescriptor<CoinTransaction>()).first { $0.kind == .taskRevoked })
        #expect(reversal.requestedCoinUnits == 60)
        #expect(reversal.amountCoinUnits == -60)
    }

    @Test func zeroXPCountsAsActivityAndKeepsBehaviorFacts() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let completion = Completion(itemID: UUID(), xp: 0, dimension: .health,
            durationMinutes: 60, taskTitle: "运动", date: now, nominalXP: 80)
        let days = YouActivityHistoryBuilder.year(completions: [completion],
            year: utc.component(.year, from: now), now: now, calendar: utc)
        let day = try #require(days.first { utc.isDate($0.date, inSameDayAs: now) })
        #expect(day.xp == 0)
        #expect(day.completedCount == 1)
        #expect(day.hasActivity)
        #expect(completion.stateActivity(fallbackItem: nil)?.taskTitle == "运动")
    }

    @Test func completedRowAndVoiceOverUsePersistedActualXP() {
        let task = item()
        let completion = Completion(itemID: task.id, xp: 20, nominalXP: 80)
        let row = TaskRailPresentation(item: task, completed: true, rewardXP: nil, completion: completion)
        #expect(row.displayedXPText == "20 XP")
        #expect(row.accessibilityValue.contains("实际获得 20 XP"))
        #expect(row.accessibilityValue.contains("标称 80 XP"))
        let zero = Completion(itemID: task.id, xp: 0, nominalXP: 80)
        let zeroRow = TaskRailPresentation(item: task, completed: true, rewardXP: nil, completion: zero)
        #expect(zeroRow.displayedXPText == "0 XP")
        #expect(zeroRow.accessibilityValue.contains("实际获得 0 XP"))
    }
}
