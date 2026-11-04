import Foundation

nonisolated struct DailyTaskXPAllowance: Equatable, Sendable {
    let day: DateInterval
    let earnedXP: Int
    let nominalXP: Int
    let awardedXP: Int
    let remainingXP: Int
}

nonisolated enum DailyTaskXPPolicy {
    static let limit = 400

    enum Error: Swift.Error { case invalidDay }

    static func day(containing date: Date, calendar: Calendar) throws -> DateInterval {
        guard let interval = calendar.dateInterval(of: .day, for: date), interval.duration > 0 else {
            throw Error.invalidDay
        }
        return interval
    }

    static func allowance(
        nominalXP: Int, earnedXP: Int, now: Date, calendar: Calendar
    ) throws -> DailyTaskXPAllowance {
        let earned = max(0, earnedXP)
        let nominal = max(0, nominalXP)
        let remaining = max(0, limit - earned)
        return DailyTaskXPAllowance(
            day: try day(containing: now, calendar: calendar),
            earnedXP: earned, nominalXP: nominal,
            awardedXP: min(nominal, remaining), remainingXP: remaining
        )
    }
}
