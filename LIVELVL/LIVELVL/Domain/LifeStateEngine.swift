import Foundation

struct LifeStateValues: Equatable, Codable, Sendable {
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
        min(1, Double(actionDays(activities: activities, now: now, calendar: calendar))
            / Double(targetDays(weeklyTarget: weeklyTarget)))
    }

    static func actionDays(activities: [StateActivity], now: Date, calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(byAdding: .day, value: -14,
                                        to: calendar.startOfDay(for: now)) else { return 0 }
        return Set(activities.filter { $0.date >= start && $0.date <= now }
            .map { calendar.startOfDay(for: $0.date) }).count
    }

    static func targetDays(weeklyTarget: Int) -> Int {
        Int(ceil(Double(min(7, max(1, weeklyTarget))) * 15 / 7))
    }

    static func settledScore(selfRating: Double, actionScore: Double) -> Double {
        min(10, max(0, selfRating) + min(1, max(0, actionScore)))
    }

    static func isAssessmentDue(
        lastAssessedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate = calendar.date(byAdding: .day, value: 15,
                                         to: calendar.startOfDay(for: lastAssessedAt)) else {
            return false
        }
        return now >= dueDate
    }

    static func daysUntilAssessment(
        lastAssessedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let dueDate = calendar.date(byAdding: .day, value: 15,
                                         to: calendar.startOfDay(for: lastAssessedAt)),
              now < dueDate else { return 0 }
        let start = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        return max(1, calendar.dateComponents([.day], from: start, to: dueDay).day ?? 1)
    }

    static func shouldRemind(
        lastAssessedAt: Date, skippedAt: Date?, now: Date, calendar: Calendar = .current
    ) -> Bool {
        guard isAssessmentDue(lastAssessedAt: lastAssessedAt, now: now, calendar: calendar) else {
            return false
        }
        guard let skippedAt else { return true }
        return isAssessmentDue(lastAssessedAt: skippedAt, now: now, calendar: calendar)
    }
}
