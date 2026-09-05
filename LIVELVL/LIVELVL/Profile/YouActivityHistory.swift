import Foundation

nonisolated enum YouTimelineCalendar {
    static func resolved(from source: Calendar) -> Calendar {
        var calendar = source
        calendar.firstWeekday = 2
        return calendar
    }
}

nonisolated enum YouAdaptiveLayoutMode: Equatable, Sendable {
    case compact
    case stacked
}

nonisolated enum YouAdaptiveLayout {
    static func mode(isAccessibilitySize: Bool) -> YouAdaptiveLayoutMode {
        isAccessibilitySize ? .stacked : .compact
    }
}

nonisolated enum YouXPIntensity: Int, CaseIterable, Equatable, Sendable {
    case empty
    case light
    case medium
    case dark
    case black

    init(xp: Int) {
        switch max(0, xp) {
        case 0:
            self = .empty
        case 1..<100:
            self = .light
        case 100..<200:
            self = .medium
        case 200..<300:
            self = .dark
        default:
            self = .black
        }
    }

    var accessibilityName: String {
        switch self {
        case .empty: "白色"
        case .light: "浅灰"
        case .medium: "中灰"
        case .dark: "近黑"
        case .black: "黑色"
        }
    }
}

nonisolated struct YouDailyActivity: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let xp: Int
    let completedCount: Int
    let isFuture: Bool

    var intensity: YouXPIntensity {
        YouXPIntensity(xp: xp)
    }
}

nonisolated enum YouXPTrendPeriod: String, CaseIterable, Equatable, Sendable {
    case week
    case month
    case year

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

nonisolated struct YouXPTrendPoint: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let xp: Int
    let completedCount: Int
}

nonisolated struct YouXPTrendSeries: Equatable, Sendable {
    let period: YouXPTrendPeriod
    let interval: DateInterval
    let points: [YouXPTrendPoint]
    let totalXP: Int
    let yMaximum: Int
}

nonisolated struct YouXPTrendAxis: Equatable, Sendable {
    let values: [Date]
    let labelValues: [Date]
    let domain: ClosedRange<Date>
    let centersLabelsBetweenValues = false
    let labelAnchorX = 0.5

    init?(series: YouXPTrendSeries) {
        guard let first = series.points.first?.date,
              let last = series.points.last?.date else {
            return nil
        }
        let defaultStep: TimeInterval = series.period == .year ? 30 * 86_400 : 86_400
        let step = series.points.dropFirst().first.map {
            max(1, $0.date.timeIntervalSince(first))
        } ?? defaultStep
        values = series.points.map(\.date)
        labelValues = series.period == .month
            ? Self.readableMonthLabelValues(values)
            : values
        let edgePadding = series.period == .month ? step : step / 2
        domain = first.addingTimeInterval(-edgePadding)...last.addingTimeInterval(edgePadding)
    }

    private static func readableMonthLabelValues(_ values: [Date]) -> [Date] {
        guard values.count > 2 else { return values }

        var indices = [0]
        var index = 4
        while index < values.count {
            indices.append(index)
            index += 5
        }

        let finalIndex = values.count - 1
        if indices.last != finalIndex {
            if let previousIndex = indices.last,
               previousIndex != 0,
               finalIndex - previousIndex < 3 {
                indices.removeLast()
            }
            indices.append(finalIndex)
        }

        return indices.map { values[$0] }
    }
}

nonisolated struct YouYearGridCell: Identifiable, Equatable, Sendable {
    var id: Date { activity.date }

    let activity: YouDailyActivity
    let column: Int
    let row: Int
}

nonisolated struct YouYearGridLayout: Equatable, Sendable {
    let cells: [YouYearGridCell]
    let weekCount: Int

    init(days: [YouDailyActivity], calendar: Calendar) {
        guard let firstDay = days.first else {
            cells = []
            weekCount = 0
            return
        }
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        guard let gridStart = mondayCalendar.dateInterval(
            of: .weekOfYear,
            for: firstDay.date
        )?.start else {
            cells = []
            weekCount = 0
            return
        }

        cells = days.map { activity in
            let dayOffset = mondayCalendar.dateComponents(
                [.day],
                from: gridStart,
                to: mondayCalendar.startOfDay(for: activity.date)
            ).day ?? 0
            return YouYearGridCell(
                activity: activity,
                column: dayOffset / 7,
                row: dayOffset % 7
            )
        }
        weekCount = (cells.map(\.column).max() ?? -1) + 1
    }
}

nonisolated struct YouIdentityPresentation: Equatable, Sendable {
    let displayName: String
    let initials: String
    let status: String

    static let development = Self(
        displayName: "LIVELVL USER",
        initials: "LV",
        status: "开发预览 · 未连接同步"
    )

    static let localOnly = Self(
        displayName: "YOU",
        initials: "LV",
        status: "本地资料 · 未连接账户"
    )
}

nonisolated enum YouActivityAccessibility {
    static func value(
        activity: YouDailyActivity,
        isToday: Bool,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.month, .day], from: activity.date)
        let date = "\(components.month ?? 0) 月 \(components.day ?? 0) 日"
        if activity.isFuture {
            return "\(date)，未来日期"
        }
        let today = isToday ? "，今天" : ""
        return "\(date)\(today)，完成 \(activity.completedCount) 项，获得 \(activity.xp) XP，\(activity.intensity.accessibilityName)"
    }
}

nonisolated enum YouXPTrendNavigation {
    static func canMoveForward(
        period: YouXPTrendPeriod,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let anchorInterval = YouActivityHistoryBuilder.interval(
            for: period,
            containing: anchor,
            calendar: calendar
        ), let currentInterval = YouActivityHistoryBuilder.interval(
            for: period,
            containing: now,
            calendar: calendar
        ) else {
            return false
        }
        return anchorInterval.start < currentInterval.start
    }
}

nonisolated enum YouActivityHistoryBuilder {
    static func year(
        completions: [Completion],
        year: Int,
        now: Date,
        calendar: Calendar
    ) -> [YouDailyActivity] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(byAdding: .year, value: 1, to: start) else {
            return []
        }

        let matching = completions.filter { $0.date >= start && $0.date < end }
        let grouped = Dictionary(grouping: matching) {
            calendar.startOfDay(for: $0.date)
        }
        let today = calendar.startOfDay(for: now)
        var result: [YouDailyActivity] = []
        var date = start

        while date < end {
            let dayCompletions = grouped[date] ?? []
            result.append(YouDailyActivity(
                date: date,
                xp: dayCompletions.reduce(0) { $0 + max(0, $1.xp) },
                completedCount: dayCompletions.count,
                isFuture: date > today
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = next
        }

        return result
    }

    static func availableYears(
        completions: [Completion],
        now: Date,
        calendar: Calendar
    ) -> [Int] {
        let currentYear = calendar.component(.year, from: now)
        let earliestYear = completions
            .map { calendar.component(.year, from: $0.date) }
            .min()
            .map { min($0, currentYear) }
            ?? currentYear
        return Array(earliestYear...currentYear)
    }

    static func trend(
        completions: [Completion],
        period: YouXPTrendPeriod,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> YouXPTrendSeries {
        guard let fullInterval = interval(
            for: period,
            containing: anchor,
            calendar: calendar
        ) else {
            return YouXPTrendSeries(
                period: period,
                interval: DateInterval(start: anchor, end: anchor),
                points: [],
                totalXP: 0,
                yMaximum: 600
            )
        }

        let todayEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now
        let visibleEnd = min(fullInterval.end, todayEnd)
        guard fullInterval.start < visibleEnd else {
            return YouXPTrendSeries(
                period: period,
                interval: fullInterval,
                points: [],
                totalXP: 0,
                yMaximum: 600
            )
        }

        let matching = completions.filter {
            $0.date >= fullInterval.start && $0.date < visibleEnd
        }
        let pointComponent: Calendar.Component = period == .year ? .month : .day
        var points: [YouXPTrendPoint] = []
        var pointStart = fullInterval.start

        while pointStart < visibleEnd {
            guard let pointEnd = calendar.date(
                byAdding: pointComponent,
                value: 1,
                to: pointStart
            ) else {
                break
            }
            let pointCompletions = matching.filter {
                $0.date >= pointStart && $0.date < min(pointEnd, visibleEnd)
            }
            points.append(YouXPTrendPoint(
                date: pointStart,
                xp: pointCompletions.reduce(0) { $0 + max(0, $1.xp) },
                completedCount: pointCompletions.count
            ))
            pointStart = pointEnd
        }

        let maximumXP = points.map(\.xp).max() ?? 0
        let yMaximum = max(600, Int(ceil(Double(maximumXP) / 100.0)) * 100)
        return YouXPTrendSeries(
            period: period,
            interval: fullInterval,
            points: points,
            totalXP: points.reduce(0) { $0 + $1.xp },
            yMaximum: yMaximum
        )
    }

    fileprivate static func interval(
        for period: YouXPTrendPeriod,
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        var resolvedCalendar = calendar
        resolvedCalendar.firstWeekday = 2
        return resolvedCalendar.dateInterval(
            of: period.calendarComponent,
            for: date
        )
    }
}
