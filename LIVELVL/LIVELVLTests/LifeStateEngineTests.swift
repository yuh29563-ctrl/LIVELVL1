import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct LifeStateEngineTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    @Test func noActivityReturnsNeutralActionScore() {
        #expect(LifeStateEngine.actionScore(
            activities: [], weeklyTarget: 3, now: date(20), calendar: calendar
        ) == 0)
    }

    @Test func oneMediumActionProducesSmallGrowth() {
        let activity = StateActivity(date: date(20), xp: 40)
        #expect(LifeStateEngine.actionScore(
            activities: [activity], weeklyTarget: 3, now: date(20), calendar: calendar
        ) == 1.0 / 7.0)
    }

    @Test func everyDayInsideWindowHasEqualWeight() {
        let today = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(20), xp: 40)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        let oldestIncludedDay = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(6), xp: 40)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        #expect(today == oldestIncludedDay)
    }

    @Test func sixteenthDayIsExcluded() {
        let score = LifeStateEngine.actionScore(
            activities: [StateActivity(date: date(5), xp: 80)],
            weeklyTarget: 3, now: date(20), calendar: calendar
        )
        #expect(score == 0)
    }

    @Test func dailyCountAndXPUseCaps() {
        let activities = [
            StateActivity(date: date(20, hour: 8), xp: 50),
            StateActivity(date: date(20, hour: 9), xp: 50),
            StateActivity(date: date(20, hour: 10), xp: 80)
        ]
        #expect(LifeStateEngine.actionScore(
            activities: activities, weeklyTarget: 1, now: date(20), calendar: calendar
        ) == 1.0 / 3.0)
    }

    @Test func settlementAndProjectionRoundAndClamp() {
        #expect(LifeStateEngine.settledScore(selfRating: 6.5, actionScore: 0.8) == 7.3)
        #expect(LifeStateEngine.settledScore(selfRating: 9.9, actionScore: 1) == 10)
        #expect(LifeStateEngine.settledScore(selfRating: 0, actionScore: -1) == 0)
    }

    @Test func assessmentIsDueOnFifteenthCalendarDate() {
        #expect(!LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(5, hour: 23), now: date(19, hour: 23), calendar: calendar
        ))
        #expect(LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(5, hour: 23), now: date(20, hour: 0), calendar: calendar
        ))
    }

    @Test func daysUntilAssessmentNeverShowsZeroBeforeDueTime() {
        #expect(LifeStateEngine.daysUntilAssessment(
            lastAssessedAt: date(5, hour: 23),
            now: date(19, hour: 23),
            calendar: calendar
        ) == 1)
        #expect(LifeStateEngine.daysUntilAssessment(
            lastAssessedAt: date(5, hour: 23),
            now: date(20, hour: 0),
            calendar: calendar
        ) == 0)
    }

    @Test func zeroXPAndRepeatedSameDayTasksStillCountExactlyOneActionDay() {
        let activities = [0, 0, 500].map { StateActivity(date: date(20, hour: 8), xp: $0) }
        #expect(LifeStateEngine.actionScore(activities: activities, weeklyTarget: 3,
            now: date(20), calendar: calendar) == 1.0 / 7.0)
    }

    @Test func sevenDistinctActionDaysReachTenPointBonus() {
        let activities = (6...12).map { StateActivity(date: date($0), xp: 0) }
        #expect(LifeStateEngine.actionScore(activities: activities, weeklyTarget: 3,
            now: date(20), calendar: calendar) == 1)
        #expect(LifeStateEngine.actionScore(activities: activities, weeklyTarget: 7,
            now: date(20), calendar: calendar) == 7.0 / 15.0)
    }

    @Test func futureCompletionsAreExcluded() {
        #expect(LifeStateEngine.actionScore(activities: [StateActivity(date: date(21), xp: 50)],
            weeklyTarget: 3, now: date(20), calendar: calendar) == 0)
    }

    @Test func daylightSavingAndTimezoneUseCalendarDatesForWindowAndEligibility() throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let start = try #require(local.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 23)))
        let due = try #require(local.date(from: DateComponents(year: 2026, month: 3, day: 16)))
        #expect(LifeStateEngine.isAssessmentDue(lastAssessedAt: start, now: due, calendar: local))
        #expect(!LifeStateEngine.isAssessmentDue(lastAssessedAt: start, now: due.addingTimeInterval(-1), calendar: local))
        let oldest = try #require(local.date(from: DateComponents(year: 2026, month: 3, day: 2)))
        #expect(LifeStateEngine.actionDays(activities: [
            StateActivity(date: oldest, xp: 0), StateActivity(date: oldest.addingTimeInterval(-1), xp: 0)
        ], now: due, calendar: local) == 1)
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 20)))
        let boundary = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 6, hour: 14)))
        #expect(LifeStateEngine.actionDays(activities: [StateActivity(date: boundary, xp: 0)], now: now, calendar: calendar) == 1)
        #expect(LifeStateEngine.actionDays(activities: [StateActivity(date: boundary, xp: 0)], now: now, calendar: tokyo) == 0)
    }

    @Test func skippedReminderReturnsAfterFifteenDaysWithoutClosingEligibility() {
        #expect(!LifeStateEngine.shouldRemind(lastAssessedAt: date(1), skippedAt: date(16),
            now: date(30), calendar: calendar))
        #expect(LifeStateEngine.shouldRemind(lastAssessedAt: date(1), skippedAt: date(16),
            now: date(31, hour: 0), calendar: calendar))
    }
}
