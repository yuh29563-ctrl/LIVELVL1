import Foundation
import Observation

@MainActor
@Observable
final class TarotDayClock {
    private(set) var currentDate: Date

    @ObservationIgnored private let fixedCalendar: Calendar?
    @ObservationIgnored private let nowProvider: @MainActor () -> Date

    init(
        calendar: Calendar? = nil,
        now: @escaping @MainActor () -> Date = { .now }
    ) {
        fixedCalendar = calendar
        nowProvider = now
        currentDate = now()
    }

    var calendar: Calendar {
        fixedCalendar ?? .current
    }

    var dayIdentifier: String {
        TarotDailyService.dayIdentifier(for: currentDate, calendar: calendar)
    }

    func now() -> Date {
        nowProvider()
    }

    func refresh() {
        currentDate = nowProvider()
    }

    func waitUntilNextDay() async {
        refresh()
        guard let boundary = Self.nextDayBoundary(
            after: currentDate,
            calendar: calendar
        ) else { return }

        let interval = max(0, boundary.timeIntervalSince(currentDate))
        do {
            try await Task.sleep(for: .seconds(interval))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        refresh()
    }

    nonisolated static func nextDayBoundary(
        after date: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
    }
}
