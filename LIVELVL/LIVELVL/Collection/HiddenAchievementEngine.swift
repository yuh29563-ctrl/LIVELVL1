import Foundation

struct CompletionFact: Equatable, Sendable {
    let itemID: UUID
    let date: Date
    let dimension: LifeDimension
    let durationMinutes: Int
}

struct HiddenAchievementAward: Equatable, Sendable {
    let awardKey: String
    let collectibleID: String
    let reason: String
    let triggeredAt: Date
}

enum HiddenAchievementEngine {
    private static let studyAwardKey = "hidden.study.three-day-streak"
    private static let healthAwardKey = "hidden.health.first-sixty-minutes"

    static func newAwards(
        facts: [CompletionFact],
        alreadyAwardedKeys: [String],
        calendar: Calendar
    ) -> [HiddenAchievementAward] {
        let alreadyAwarded = Set(alreadyAwardedKeys)
        var awards: [HiddenAchievementAward] = []

        if !alreadyAwarded.contains(studyAwardKey),
           let triggeredAt = studyStreakTriggerDate(facts: facts, calendar: calendar) {
            awards.append(HiddenAchievementAward(
                awardKey: studyAwardKey,
                collectibleID: "hidden.study-streak",
                reason: "连续 3 天完成学习行动",
                triggeredAt: triggeredAt
            ))
        }

        if !alreadyAwarded.contains(healthAwardKey),
           let triggeredAt = facts
            .filter({ $0.dimension == .health && $0.durationMinutes >= 60 })
            .map(\.date)
            .min() {
            awards.append(HiddenAchievementAward(
                awardKey: healthAwardKey,
                collectibleID: "hidden.long-workout",
                reason: "第一次完成至少 60 分钟的健康行动",
                triggeredAt: triggeredAt
            ))
        }

        return awards.sorted {
            if $0.triggeredAt != $1.triggeredAt {
                return $0.triggeredAt < $1.triggeredAt
            }
            return $0.awardKey < $1.awardKey
        }
    }

    private static func studyStreakTriggerDate(
        facts: [CompletionFact],
        calendar: Calendar
    ) -> Date? {
        let learningFacts = facts.filter { $0.dimension == .learning }
        let factsByDay = Dictionary(grouping: learningFacts) {
            calendar.startOfDay(for: $0.date)
        }
        let days = factsByDay.keys.sorted()
        guard days.count >= 3 else { return nil }

        var consecutiveDays = 1
        for index in 1..<days.count {
            let previousDay = days[index - 1]
            let currentDay = days[index]
            let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDay)

            if nextDay == currentDay {
                consecutiveDays += 1
                if consecutiveDays == 3 {
                    return factsByDay[currentDay]?.map(\.date).min()
                }
            } else {
                consecutiveDays = 1
            }
        }

        return nil
    }
}
