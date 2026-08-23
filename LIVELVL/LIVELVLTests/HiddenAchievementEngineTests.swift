import Foundation
import Testing
@testable import LIVELVL

struct HiddenAchievementEngineTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func awardsStudyStreakAfterThreeConsecutiveDays() {
        let threeDays = [0, 1, 2].map {
            CompletionFact(
                itemID: UUID(),
                date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                dimension: .learning,
                durationMinutes: 30
            )
        }

        #expect(HiddenAchievementEngine.newAwards(
            facts: threeDays,
            alreadyAwardedKeys: [],
            calendar: utcCalendar
        ).map(\.awardKey) == ["hidden.study.three-day-streak"])
    }

    @Test func doesNotCountDuplicateFactsOnOneDayAsDistinctStreakDays() {
        let duplicateDay = [0, 0, 1].map {
            CompletionFact(
                itemID: UUID(),
                date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                dimension: .learning,
                durationMinutes: 30
            )
        }

        #expect(HiddenAchievementEngine.newAwards(
            facts: duplicateDay,
            alreadyAwardedKeys: [],
            calendar: utcCalendar
        ).isEmpty)
    }

    @Test func awardsFirstSixtyMinuteHealthAction() {
        let workout = CompletionFact(
            itemID: UUID(),
            date: .now,
            dimension: .health,
            durationMinutes: 60
        )

        #expect(HiddenAchievementEngine.newAwards(
            facts: [workout],
            alreadyAwardedKeys: [],
            calendar: utcCalendar
        ).map(\.awardKey) == ["hidden.health.first-sixty-minutes"])
    }

    @Test func suppressesAlreadyAwardedHiddenAchievements() {
        let threeDays = [0, 1, 2].map {
            CompletionFact(
                itemID: UUID(),
                date: Date(timeIntervalSince1970: Double($0 * 86_400)),
                dimension: .learning,
                durationMinutes: 30
            )
        }
        let workout = CompletionFact(
            itemID: UUID(),
            date: .now,
            dimension: .health,
            durationMinutes: 60
        )

        #expect(HiddenAchievementEngine.newAwards(
            facts: threeDays + [workout],
            alreadyAwardedKeys: [
                "hidden.study.three-day-streak",
                "hidden.health.first-sixty-minutes"
            ],
            calendar: utcCalendar
        ).isEmpty)
    }
}
