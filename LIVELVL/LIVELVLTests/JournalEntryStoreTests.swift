import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct JournalEntryStoreTests {
    @Test func savingTwiceOnTheSameDayUpdatesOneEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let morning = try #require(makeDate(year: 2026, month: 9, day: 6, hour: 8, timeZone: timeZone))
        let evening = try #require(makeDate(year: 2026, month: 9, day: 6, hour: 21, timeZone: timeZone))

        let first = try JournalEntryStore.save(
            title: "清晨",
            body: "第一段",
            state: .draft,
            for: morning,
            timeZone: timeZone,
            in: context
        )
        let second = try JournalEntryStore.save(
            title: "今天",
            body: "更新后的内容",
            state: .completed,
            for: evening,
            timeZone: timeZone,
            in: context
        )

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 1)
        #expect(first?.id == second?.id)
        #expect(entries.first?.title == "今天")
        #expect(entries.first?.body == "更新后的内容")
        #expect(entries.first?.state == .completed)
    }

    @Test func anEmptyDraftDoesNotCreateAnEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))

        let result = try JournalEntryStore.save(
            title: "   ",
            body: "\n",
            state: .draft,
            for: Date(timeIntervalSince1970: 0),
            timeZone: timeZone,
            in: context
        )

        #expect(result == nil)
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }

    @Test func dayKeyUsesTheSelectedTimeZoneAtDateBoundaries() throws {
        let shanghai = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let instant = Date(timeIntervalSince1970: 0)

        #expect(JournalEntryStore.dayKey(for: instant, timeZone: shanghai) == "1970-01-01|Asia/Shanghai")
        #expect(JournalEntryStore.dayKey(for: instant, timeZone: losAngeles) == "1969-12-31|America/Los_Angeles")
    }

    @Test func bodyIsLimitedToOneHundredThousandCharacters() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))

        let entry = try JournalEntryStore.save(
            title: "长日记",
            body: String(repeating: "日", count: 100_001),
            state: .draft,
            for: Date(timeIntervalSince1970: 0),
            timeZone: timeZone,
            in: context
        )

        #expect(entry?.body.count == 100_000)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([JournalEntry.self])
        return try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))
    }
}
