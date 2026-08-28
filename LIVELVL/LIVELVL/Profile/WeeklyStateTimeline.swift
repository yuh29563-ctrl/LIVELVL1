import Foundation
import CoreGraphics

nonisolated enum YouTimelineCalendar {
    static func resolved(from source: Calendar) -> Calendar {
        var calendar = source
        calendar.firstWeekday = 2
        return calendar
    }
}

nonisolated enum YouStateNodeLayout {
    static let connectorOffset = CGPoint.zero

    static func labelOffset(for dimension: LifeDimension) -> CGFloat {
        switch dimension {
        case .health, .learning, .interests: -28
        case .career, .finance, .relationships: 31
        }
    }
}

struct WeeklyStateDay: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let completedCount: Int
    let xp: Int
}

enum WeeklyStateTimelineBuilder {
    static func build(
        completions: [Completion],
        weekContaining date: Date,
        calendar: Calendar
    ) -> [WeeklyStateDay] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let interval = calendar.dateInterval(of: .day, for: day) else {
                return nil
            }
            let matching = completions.filter {
                $0.date >= interval.start && $0.date < interval.end
            }
            return WeeklyStateDay(
                date: day,
                completedCount: matching.count,
                xp: matching.reduce(0) { $0 + $1.xp }
            )
        }
    }
}
