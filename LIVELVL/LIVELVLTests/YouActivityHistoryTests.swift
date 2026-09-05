import Foundation
import Testing
@testable import LIVELVL

struct YouActivityHistoryTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 2
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    @Test func xpIntensityUsesApprovedBoundaries() {
        #expect(YouXPIntensity(xp: 0) == .empty)
        #expect(YouXPIntensity(xp: 1) == .light)
        #expect(YouXPIntensity(xp: 99) == .light)
        #expect(YouXPIntensity(xp: 100) == .medium)
        #expect(YouXPIntensity(xp: 199) == .medium)
        #expect(YouXPIntensity(xp: 200) == .dark)
        #expect(YouXPIntensity(xp: 299) == .dark)
        #expect(YouXPIntensity(xp: 300) == .black)
        #expect(YouXPIntensity(xp: 600) == .black)
    }

    @Test func yearAggregatesCompletionCountAndNonnegativeXPByDay() throws {
        let firstID = UUID()
        let secondID = UUID()
        let completions = [
            Completion(itemID: firstID, xp: 80, date: date(2026, 2, 3, hour: 8)),
            Completion(itemID: secondID, xp: 45, date: date(2026, 2, 3, hour: 20)),
            Completion(itemID: UUID(), xp: -50, date: date(2026, 2, 3, hour: 21)),
            Completion(itemID: UUID(), xp: 900, date: date(2025, 12, 31)),
        ]

        let days = YouActivityHistoryBuilder.year(
            completions: completions,
            year: 2026,
            now: date(2026, 9, 4),
            calendar: calendar
        )
        let februaryThird = try #require(days.first {
            calendar.isDate($0.date, inSameDayAs: date(2026, 2, 3))
        })

        #expect(days.count == 365)
        #expect(februaryThird.completedCount == 3)
        #expect(februaryThird.xp == 125)
        #expect(februaryThird.intensity == .medium)
    }

    @Test func leapYearIncludesFebruaryTwentyNinthAndMarksFutureDays() throws {
        let now = date(2024, 2, 1)
        let days = YouActivityHistoryBuilder.year(
            completions: [],
            year: 2024,
            now: now,
            calendar: calendar
        )
        let leapDay = try #require(days.first {
            calendar.isDate($0.date, inSameDayAs: date(2024, 2, 29))
        })

        #expect(days.count == 366)
        #expect(leapDay.isFuture)
        #expect(!days[0].isFuture)
    }

    @Test func availableYearsSpanEarliestCompletionThroughCurrentYear() {
        let completions = [
            Completion(itemID: UUID(), xp: 20, date: date(2024, 5, 1)),
            Completion(itemID: UUID(), xp: 20, date: date(2026, 1, 1)),
        ]

        #expect(YouActivityHistoryBuilder.availableYears(
            completions: completions,
            now: date(2026, 9, 4),
            calendar: calendar
        ) == [2024, 2025, 2026])
        #expect(YouActivityHistoryBuilder.availableYears(
            completions: [],
            now: date(2026, 9, 4),
            calendar: calendar
        ) == [2026])
    }

    @Test func removingCompletionReducesThatDaysSummary() throws {
        let retained = Completion(itemID: UUID(), xp: 80, date: date(2026, 8, 5))
        let revoked = Completion(itemID: UUID(), xp: 50, date: date(2026, 8, 5))
        let before = YouActivityHistoryBuilder.year(
            completions: [retained, revoked],
            year: 2026,
            now: date(2026, 9, 4),
            calendar: calendar
        )
        let after = YouActivityHistoryBuilder.year(
            completions: [retained],
            year: 2026,
            now: date(2026, 9, 4),
            calendar: calendar
        )
        let dayBefore = try #require(before.first {
            calendar.isDate($0.date, inSameDayAs: retained.date)
        })
        let dayAfter = try #require(after.first {
            calendar.isDate($0.date, inSameDayAs: retained.date)
        })

        #expect(dayBefore.xp == 130)
        #expect(dayBefore.completedCount == 2)
        #expect(dayAfter.xp == 80)
        #expect(dayAfter.completedCount == 1)
    }

    @Test func weeklyTrendStartsMondayAndAggregatesEachDay() {
        let completions = [
            Completion(itemID: UUID(), xp: 20, date: date(2026, 8, 24)),
            Completion(itemID: UUID(), xp: 30, date: date(2026, 8, 25)),
            Completion(itemID: UUID(), xp: 999, date: date(2026, 8, 31)),
        ]

        let series = YouActivityHistoryBuilder.trend(
            completions: completions,
            period: .week,
            anchor: date(2026, 8, 26),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        #expect(series.points.count == 7)
        #expect(calendar.component(.weekday, from: series.points[0].date) == 2)
        #expect(series.points[0].xp == 20)
        #expect(series.points[1].xp == 30)
        #expect(series.totalXP == 50)
    }

    @Test func currentMonthTrendStopsAtToday() {
        let completions = [
            Completion(itemID: UUID(), xp: 100, date: date(2026, 9, 2)),
            Completion(itemID: UUID(), xp: 999, date: date(2026, 9, 5)),
        ]

        let series = YouActivityHistoryBuilder.trend(
            completions: completions,
            period: .month,
            anchor: date(2026, 9, 1),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        #expect(series.points.count == 4)
        #expect(series.points.map(\.xp) == [0, 100, 0, 0])
        #expect(series.totalXP == 100)
    }

    @Test func annualTrendAggregatesMonthsAndStopsAtCurrentMonth() {
        let completions = [
            Completion(itemID: UUID(), xp: 40, date: date(2026, 1, 2)),
            Completion(itemID: UUID(), xp: 60, date: date(2026, 1, 18)),
            Completion(itemID: UUID(), xp: 30, date: date(2026, 9, 1)),
            Completion(itemID: UUID(), xp: 999, date: date(2026, 10, 1)),
        ]

        let series = YouActivityHistoryBuilder.trend(
            completions: completions,
            period: .year,
            anchor: date(2026, 5, 1),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        #expect(series.points.count == 9)
        #expect(series.points.first?.xp == 100)
        #expect(series.points.last?.xp == 30)
        #expect(series.totalXP == 130)
    }

    @Test func trendAxisStartsAtSixHundredAndExpandsByHundreds() {
        let empty = YouActivityHistoryBuilder.trend(
            completions: [],
            period: .week,
            anchor: date(2026, 9, 4),
            now: date(2026, 9, 4),
            calendar: calendar
        )
        let aboveRange = YouActivityHistoryBuilder.trend(
            completions: [Completion(
                itemID: UUID(),
                xp: 750,
                date: date(2026, 9, 4)
            )],
            period: .week,
            anchor: date(2026, 9, 4),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        #expect(empty.yMaximum == 600)
        #expect(aboveRange.yMaximum == 800)
        #expect(aboveRange.points.last?.xp == 750)
    }

    @Test func trendNavigationCannotMoveBeyondCurrentPeriod() {
        #expect(YouXPTrendNavigation.canMoveForward(
            period: .month,
            anchor: date(2026, 8, 1),
            now: date(2026, 9, 4),
            calendar: calendar
        ))
        #expect(!YouXPTrendNavigation.canMoveForward(
            period: .month,
            anchor: date(2026, 9, 1),
            now: date(2026, 9, 4),
            calendar: calendar
        ))
    }

    @Test func yearGridUsesMondayRowsAndContinuousWeekColumns() throws {
        let days = YouActivityHistoryBuilder.year(
            completions: [],
            year: 2026,
            now: date(2026, 9, 4),
            calendar: calendar
        )
        let layout = YouYearGridLayout(days: days, calendar: calendar)
        let januaryFirst = try #require(layout.cells.first)
        let januaryFifth = try #require(layout.cells.first {
            calendar.isDate($0.activity.date, inSameDayAs: date(2026, 1, 5))
        })

        #expect(januaryFirst.row == 3)
        #expect(januaryFirst.column == 0)
        #expect(januaryFifth.row == 0)
        #expect(januaryFifth.column == 1)
        #expect(layout.weekCount == 53)
    }

    @Test func activityAccessibilityDoesNotRevealTaskNames() {
        let activity = YouDailyActivity(
            date: date(2026, 9, 4),
            xp: 125,
            completedCount: 3,
            isFuture: false
        )

        let value = YouActivityAccessibility.value(
            activity: activity,
            isToday: true,
            calendar: calendar
        )

        #expect(value == "9 月 4 日，今天，完成 3 项，获得 125 XP，中灰")
        #expect(!value.contains("任务"))
    }

    @Test func futureActivityAccessibilityDistinguishesAnEmptyFutureDay() {
        let activity = YouDailyActivity(
            date: date(2026, 9, 5),
            xp: 0,
            completedCount: 0,
            isFuture: true
        )

        #expect(YouActivityAccessibility.value(
            activity: activity,
            isToday: false,
            calendar: calendar
        ) == "9 月 5 日，未来日期")
    }

    @Test func identityPresentationNeverClaimsDevelopmentPreviewIsSynced() {
        #expect(YouIdentityPresentation.development.displayName == "LIVELVL USER")
        #expect(YouIdentityPresentation.development.status == "开发预览 · 未连接同步")
        #expect(YouIdentityPresentation.localOnly.status == "本地资料 · 未连接账户")
    }

    @Test func accessibilityTextUsesStackedCardHeaders() {
        #expect(YouAdaptiveLayout.mode(isAccessibilitySize: false) == .compact)
        #expect(YouAdaptiveLayout.mode(isAccessibilitySize: true) == .stacked)
    }

    @Test func trendAxisUsesTheExactDatesOfItsVisibleNodesAndPadsBothEdges() throws {
        let series = YouActivityHistoryBuilder.trend(
            completions: [Completion(itemID: UUID(), xp: 40, date: date(2026, 9, 1))],
            period: .week,
            anchor: date(2026, 9, 4),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        let axis = try #require(YouXPTrendAxis(series: series))

        #expect(axis.values == series.points.map(\.date))
        #expect(axis.domain.lowerBound < series.points[0].date)
        #expect(axis.domain.upperBound > series.points[series.points.count - 1].date)
    }

    @Test func trendAxisAnchorsEachLabelCenterToItsNodeTick() throws {
        let series = YouActivityHistoryBuilder.trend(
            completions: [],
            period: .month,
            anchor: date(2026, 9, 4),
            now: date(2026, 9, 4),
            calendar: calendar
        )

        let axis = try #require(YouXPTrendAxis(series: series))

        #expect(!axis.centersLabelsBetweenValues)
        #expect(axis.labelAnchorX == 0.5)
    }

    @Test func monthlyTrendKeepsEveryDailyNodeButUsesReadableDateLabels() throws {
        let series = YouActivityHistoryBuilder.trend(
            completions: [],
            period: .month,
            anchor: date(2026, 1, 1),
            now: date(2026, 1, 31),
            calendar: calendar
        )

        let axis = try #require(YouXPTrendAxis(series: series))
        let labelDays = axis.labelValues.map { calendar.component(.day, from: $0) }

        #expect(axis.values.count == 31)
        #expect(labelDays == [1, 5, 10, 15, 20, 25, 31])
    }

    @Test func monthlyTrendReservesOneDayAroundItsEdgeLabels() throws {
        let series = YouActivityHistoryBuilder.trend(
            completions: [],
            period: .month,
            anchor: date(2026, 1, 1),
            now: date(2026, 1, 31),
            calendar: calendar
        )

        let axis = try #require(YouXPTrendAxis(series: series))
        let first = try #require(series.points.first?.date)
        let last = try #require(series.points.last?.date)

        #expect(first.timeIntervalSince(axis.domain.lowerBound) == 86_400)
        #expect(axis.domain.upperBound.timeIntervalSince(last) == 86_400)
    }

    @Test func settingsRowsUseOnlyInternalSeparatorsWithoutSectionHeaders() {
        let layout = YouSettingsListLayout(rowCount: 5)

        #expect(layout.sectionHeaderCount == 0)
        #expect(layout.separatorIndices == [0, 1, 2, 3])
    }
}
