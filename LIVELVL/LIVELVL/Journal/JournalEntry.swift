import Foundation
import SwiftData

enum JournalEntryState: String, Codable {
    case draft
    case completed
}

@Model
final class JournalEntry {
    @Attribute(.unique) var dayKey: String
    var id: UUID
    var dayStart: Date
    var timeZoneIdentifier: String
    var title: String
    var body: String
    var stateRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var deletedAt: Date?

    var state: JournalEntryState {
        get { JournalEntryState(rawValue: stateRawValue) ?? .draft }
        set { stateRawValue = newValue.rawValue }
    }

    init(
        dayKey: String,
        dayStart: Date,
        timeZoneIdentifier: String,
        title: String,
        body: String,
        state: JournalEntryState,
        now: Date
    ) {
        self.dayKey = dayKey
        id = UUID()
        self.dayStart = dayStart
        self.timeZoneIdentifier = timeZoneIdentifier
        self.title = title
        self.body = body
        stateRawValue = state.rawValue
        createdAt = now
        updatedAt = now
        completedAt = state == .completed ? now : nil
    }
}

@MainActor
enum JournalEntryStore {
    static let maximumBodyLength = 100_000

    static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d|%@",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            timeZone.identifier
        )
    }

    static func entry(
        for date: Date,
        timeZone: TimeZone,
        in context: ModelContext
    ) throws -> JournalEntry? {
        let key = dayKey(for: date, timeZone: timeZone)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.dayKey == key }
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    static func save(
        title: String,
        body: String,
        state: JournalEntryState,
        for date: Date,
        timeZone: TimeZone,
        in context: ModelContext
    ) throws -> JournalEntry? {
        let existing = try entry(for: date, timeZone: timeZone, in: context)
        let isBlank = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard existing != nil || !isBlank || state == .completed else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let normalizedBody = String(body.prefix(maximumBodyLength))
        let entry = existing ?? JournalEntry(
            dayKey: dayKey(for: date, timeZone: timeZone),
            dayStart: calendar.startOfDay(for: date),
            timeZoneIdentifier: timeZone.identifier,
            title: title,
            body: normalizedBody,
            state: state,
            now: date
        )

        if existing == nil {
            context.insert(entry)
        }
        entry.title = title
        entry.body = normalizedBody
        entry.state = state
        entry.updatedAt = date
        entry.completedAt = state == .completed ? (entry.completedAt ?? date) : nil
        try context.save()
        return entry
    }
}
