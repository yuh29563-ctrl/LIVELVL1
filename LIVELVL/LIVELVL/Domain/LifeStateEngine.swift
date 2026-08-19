import Foundation

struct LifeStateValues: Equatable, Sendable {
    var health: Double
    var learning: Double
    var career: Double
    var finance: Double
    var relationships: Double
    var interests: Double

    static let neutral = LifeStateValues(repeating: 5.0)

    init(repeating value: Double) {
        health = value
        learning = value
        career = value
        finance = value
        relationships = value
        interests = value
    }

    init(health: Double, learning: Double, career: Double,
         finance: Double, relationships: Double, interests: Double) {
        self.health = health
        self.learning = learning
        self.career = career
        self.finance = finance
        self.relationships = relationships
        self.interests = interests
    }

    subscript(_ dimension: LifeDimension) -> Double {
        get {
            switch dimension {
            case .health: health
            case .learning: learning
            case .career: career
            case .finance: finance
            case .relationships: relationships
            case .interests: interests
            }
        }
        set {
            switch dimension {
            case .health: health = newValue
            case .learning: learning = newValue
            case .career: career = newValue
            case .finance: finance = newValue
            case .relationships: relationships = newValue
            case .interests: interests = newValue
            }
        }
    }

    var average: Double {
        let total = LifeDimension.allCases.reduce(0.0) { $0 + self[$1] }
        return LifeStateEngine.rounded(total / 6.0)
    }
}

struct StateActivity: Equatable, Sendable {
    let date: Date
    let xp: Int
}

enum LifeStateEngine {
    static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    static func actionScore(
        activities: [StateActivity],
        weeklyTarget: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -14, to: today)!
        let eligible = activities
            .filter { $0.date >= windowStart && $0.date <= now }
            .sorted { $0.date < $1.date }
        let grouped = Dictionary(grouping: eligible) { calendar.startOfDay(for: $0.date) }

        var countedCompletions = 0
        var countedXP = 0
        for dayActivities in grouped.values {
            let firstTwo = Array(dayActivities.prefix(2))
            countedCompletions += firstTwo.count
            countedXP += min(80, firstTwo.reduce(0) { $0 + max(0, $1.xp) })
        }

        let targetCount = Double(min(7, max(1, weeklyTarget))) * 15.0 / 7.0
        let consistency = min(1.0, Double(countedCompletions) / targetCount)
        let intensity = min(1.0, Double(countedXP) / (targetCount * 40.0))
        return rounded(5.0 + 5.0 * (consistency * 0.6 + intensity * 0.4))
    }

    static func settledScore(selfRating: Double, actionScore: Double) -> Double {
        rounded(min(10.0, max(1.0, selfRating * 0.6 + actionScore * 0.4)))
    }

    static func projectedScore(
        officialScore: Double,
        baselineActionScore: Double,
        currentActionScore: Double
    ) -> Double {
        rounded(min(10.0, max(1.0,
            officialScore + (currentActionScore - baselineActionScore) * 0.4
        )))
    }

    static func isAssessmentDue(
        lastAssessedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate = calendar.date(byAdding: .day, value: 7, to: lastAssessedAt) else {
            return false
        }
        return now >= dueDate
    }
}
