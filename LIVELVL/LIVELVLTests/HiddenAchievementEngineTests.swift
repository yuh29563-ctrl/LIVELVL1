import Foundation
import Testing
@testable import LIVELVL

struct HiddenAchievementEngineTests {
    private var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func facts(_ days: [Int], dimension: LifeDimension = .health,
                       start: Date = Date(timeIntervalSince1970: 1_767_182_400),
                       calendar: Calendar? = nil) -> [CompletionFact] {
        let calendar = calendar ?? utc
        return days.map { CompletionFact(itemID: UUID(),
            date: calendar.date(byAdding: .day, value: $0, to: start)!,
            dimension: dimension, durationMinutes: 0) }
    }
    private func awards(_ facts: [CompletionFact], calendar: Calendar? = nil) -> [HiddenAchievementAward] {
        HiddenAchievementEngine.eligibleAwards(facts: facts, calendar: calendar ?? utc)
    }

    @Test func everyDimensionUnlocksFirstWithoutDurationOrOtherDimensions() {
        for dimension in LifeDimension.allCases {
            let result = awards(facts([0], dimension: dimension))
            #expect(result.map(\.awardKey) == ["hidden.\(dimension.rawValue).first"])
        }
        #expect(awards([]).isEmpty)
    }
    @Test func allMilestoneBoundariesUseDistinctConsecutiveDays() {
        for day in 1...36 {
            let result = awards(facts(Array(0..<day)))
            let expected = ["hidden.health.first"] + [7, 14, 21, 28, 35]
                .filter { day >= $0 }.map { "hidden.health.streak.\($0)" }
            #expect(result.map(\.awardKey) == expected)
            for award in result {
                let count = award.awardKey == "hidden.health.first" ? 1 : Int(award.awardKey.split(separator: ".").last!)!
                #expect(award.triggeredAt == facts([count - 1]).first?.date)
            }
        }
    }
    @Test func duplicateDaysGapsAndDimensionsDoNotCombine() {
        #expect(awards(facts([0, 0, 1, 2, 3, 4, 5])).count == 1)
        #expect(awards(facts([0, 1, 2, 4, 5, 6, 7])).count == 1)
        let mixed = facts([0, 2, 4, 6]) + facts([1, 3, 5], dimension: .learning)
        #expect(Set(awards(mixed).map(\.awardKey)) == ["hidden.health.first", "hidden.learning.first"])
    }
    @Test func laterBreakKeepsHistoricalMilestonesAndAlternateStreakCanSupportThem() {
        let original = facts(Array(0..<7))
        #expect(awards(original + facts([10])).count == 2)
        #expect(awards(Array(original.dropFirst(3)) + facts(Array(10..<17))).count == 2)
        #expect(awards(Array(original.dropFirst())).count == 1)
    }
    @Test func calendarDaysCrossYearAndBothDaylightSavingTransitions() {
        for (zone, year, month, day) in [("UTC", 2026, 12, 28),
                                        ("America/Los_Angeles", 2026, 3, 5),
                                        ("America/Los_Angeles", 2026, 10, 29)] {
            var calendar = utc
            calendar.timeZone = TimeZone(identifier: zone)!
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
            let records = facts(Array(0..<7), start: start, calendar: calendar)
            #expect(awards(records.reversed(), calendar: calendar).map(\.awardKey)
                == ["hidden.health.first", "hidden.health.streak.7"])
        }
    }
}
