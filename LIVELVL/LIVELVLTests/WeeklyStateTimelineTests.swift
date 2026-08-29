import Foundation
import Testing
@testable import LIVELVL

struct WeeklyStateTimelineTests {
    @Test func youTimelineAlwaysUsesMondayAsTheFirstWeekday() {
        var source = Calendar(identifier: .gregorian)
        source.firstWeekday = 1

        let resolved = YouTimelineCalendar.resolved(from: source)

        #expect(resolved.firstWeekday == 2)
    }

    @Test func youNodeLabelsStayAwayFromTheConnectorCenter() {
        #expect(YouStateNodeLayout.labelOffset(for: .health) < -20)
        #expect(YouStateNodeLayout.labelOffset(for: .relationships) > 20)
        #expect(YouStateNodeLayout.connectorOffset == .zero)
    }

    @Test func accessibilityTimelineUsesTheScaledColumnWidth() {
        #expect(
            YouTimelineLayout.dayWidth(
                isAccessibilitySize: true,
                scaledMetricWidth: 118
            ) == 118
        )
        #expect(
            YouTimelineLayout.dayWidth(
                isAccessibilitySize: false,
                scaledMetricWidth: 118
            ) == nil
        )
    }

    @Test func timelineReturnsSevenOrderedDaysAndAggregatesXP() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 12))
        )
        let monday = try #require(calendar.dateInterval(of: .weekOfYear, for: now)?.start)
        let lateMonday = try #require(calendar.date(byAdding: .hour, value: 23, to: monday))
        let tuesday = try #require(calendar.date(byAdding: .day, value: 1, to: monday))
        let nextMonday = try #require(calendar.date(byAdding: .day, value: 7, to: monday))
        let completions = [
            Completion(itemID: UUID(), xp: 20, dimension: .health, taskTitle: "跑步", date: monday),
            Completion(itemID: UUID(), xp: 15, dimension: .learning, taskTitle: "阅读", date: lateMonday),
            Completion(itemID: UUID(), xp: 30, dimension: .career, taskTitle: "复盘", date: tuesday),
            Completion(itemID: UUID(), xp: 999, dimension: .finance, taskTitle: "下周", date: nextMonday),
        ]

        let days = WeeklyStateTimelineBuilder.build(
            completions: completions,
            weekContaining: now,
            calendar: calendar
        )

        #expect(days.count == 7)
        #expect(days.map(\.date) == days.map(\.date).sorted())
        #expect(days.first?.completedCount == 2)
        #expect(days.first?.xp == 35)
        #expect(days.dropFirst().first?.completedCount == 1)
        #expect(days.dropFirst().first?.xp == 30)
        #expect(days.reduce(0) { $0 + $1.completedCount } == 3)
    }

    @Test func timelineDayAccessibilityIncludesDateCountAndXP() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 26))
        )
        let day = WeeklyStateDay(date: date, completedCount: 2, xp: 35)

        #expect(
            YouTimelineAccessibility.value(
                day: day,
                isToday: true,
                calendar: calendar
            ) == "8 月 26 日，完成 2 项，获得 35 XP，今天"
        )
    }
}
