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
        ) == 5.0)
    }

    @Test func oneMediumActionProducesSmallGrowth() {
        let activity = StateActivity(date: date(20), xp: 40)
        #expect(LifeStateEngine.actionScore(
            activities: [activity], weeklyTarget: 3, now: date(20), calendar: calendar
        ) == 5.8)
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
        #expect(score == 5.0)
    }

    @Test func dailyCountAndXPUseCaps() {
        let activities = [
            StateActivity(date: date(20, hour: 8), xp: 50),
            StateActivity(date: date(20, hour: 9), xp: 50),
            StateActivity(date: date(20, hour: 10), xp: 80)
        ]
        #expect(LifeStateEngine.actionScore(
            activities: activities, weeklyTarget: 1, now: date(20), calendar: calendar
        ) == 9.7)
    }

    @Test func settlementAndProjectionRoundAndClamp() {
        #expect(LifeStateEngine.settledScore(selfRating: 8.0, actionScore: 7.0) == 7.6)
        #expect(LifeStateEngine.projectedScore(
            officialScore: 6.5, baselineActionScore: 6.0, currentActionScore: 6.8
        ) == 6.8)
        #expect(LifeStateEngine.projectedScore(
            officialScore: 9.9, baselineActionScore: 5.0, currentActionScore: 10.0
        ) == 10.0)
    }

    @Test func assessmentIsDueAfterSevenCalendarDays() {
        #expect(!LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(13, hour: 13), now: date(20, hour: 12), calendar: calendar
        ))
        #expect(LifeStateEngine.isAssessmentDue(
            lastAssessedAt: date(13, hour: 12), now: date(20, hour: 12), calendar: calendar
        ))
    }
}
