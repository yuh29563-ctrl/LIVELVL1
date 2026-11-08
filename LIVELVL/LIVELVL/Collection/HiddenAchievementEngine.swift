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

struct HiddenAchievementRule: Equatable, Sendable {
    let dimension: LifeDimension
    let days: Int

    var id: String {
        let suffix = days == 1 ? "first" : "streak.\(days)"
        return "hidden.\(dimension.rawValue).\(suffix)"
    }
    var reason: String {
        days == 1 ? "第一次完成\(dimension.title)任务" : "连续 \(days) 天完成\(dimension.title)任务"
    }
}

enum HiddenAchievementEngine {
    static let dimensions: [LifeDimension] = [.health, .learning, .finance, .relationships, .career, .interests]
    static let rules = dimensions.flatMap { dimension in
        [1, 7, 14, 21, 28, 35].map { HiddenAchievementRule(dimension: dimension, days: $0) }
    }

    // Return every supported milestone: only revoking its evidence can invalidate an earned card.
    static func eligibleAwards(facts: [CompletionFact], calendar: Calendar) -> [HiddenAchievementAward] {
        var awards: [HiddenAchievementAward] = []
        for dimension in dimensions {
            let byDay = Dictionary(grouping: facts.filter { $0.dimension == dimension }) {
                calendar.startOfDay(for: $0.date)
            }
            var previousDay: Date?
            var streak = 0
            var reached: Set<Int> = []
            for day in byDay.keys.sorted() {
                streak = previousDay.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == day
                    ? streak + 1 : 1
                previousDay = day
                for rule in rules where rule.dimension == dimension && streak >= rule.days {
                    guard reached.insert(rule.days).inserted,
                          let triggeredAt = byDay[day]?.map(\.date).min() else { continue }
                    awards.append(HiddenAchievementAward(awardKey: rule.id, collectibleID: rule.id,
                                                        reason: rule.reason, triggeredAt: triggeredAt))
                }
            }
        }
        return awards.sorted {
            if $0.triggeredAt != $1.triggeredAt { return $0.triggeredAt < $1.triggeredAt }
            return $0.awardKey < $1.awardKey
        }
    }
}
