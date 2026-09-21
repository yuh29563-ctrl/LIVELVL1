import Foundation
import SwiftData

enum TarotOrientation: String, Codable, CaseIterable, Sendable {
    case upright
    case reversed

    var title: String {
        switch self {
        case .upright: "正位"
        case .reversed: "逆位"
        }
    }
}

@Model
final class TarotDailyState {
    @Attribute(.unique) var singletonKey: String
    var dayIdentifier: String
    var candidateCardIDs: [String]
    var candidateOrientationRawValues: [String]
    var selectedIndex: Int?
    var selectedAt: Date?

    init(
        singletonKey: String = "tarot.daily",
        dayIdentifier: String,
        candidateCardIDs: [String],
        candidateOrientations: [TarotOrientation],
        selectedIndex: Int? = nil,
        selectedAt: Date? = nil
    ) {
        self.singletonKey = singletonKey
        self.dayIdentifier = dayIdentifier
        self.candidateCardIDs = candidateCardIDs
        candidateOrientationRawValues = candidateOrientations.map(\.rawValue)
        self.selectedIndex = selectedIndex
        self.selectedAt = selectedAt
    }

    var candidateOrientations: [TarotOrientation] {
        candidateOrientationRawValues.compactMap(TarotOrientation.init(rawValue:))
    }
}

enum TarotCatalog {
    static let cardIDs = cards.map(\.id)
}

enum TarotDailyService {
    static func loadOrCreateState<RNG: RandomNumberGenerator>(
        in context: ModelContext,
        now: Date,
        calendar: Calendar,
        random: inout RNG
    ) throws -> TarotDailyState {
        let states = try context.fetch(FetchDescriptor<TarotDailyState>())
        if let state = states.first(where: { $0.singletonKey == "tarot.daily" }) {
            if resetIfNeeded(state, now: now, calendar: calendar, random: &random) {
                try context.save()
            }
            return state
        }

        let state = makeState(now: now, calendar: calendar, random: &random)
        context.insert(state)
        try context.save()
        return state
    }

    static func makeState<RNG: RandomNumberGenerator>(
        now: Date,
        calendar: Calendar,
        random: inout RNG
    ) -> TarotDailyState {
        let candidates = makeCandidates(random: &random)
        return TarotDailyState(
            dayIdentifier: dayIdentifier(for: now, calendar: calendar),
            candidateCardIDs: candidates.map(\.cardID),
            candidateOrientations: candidates.map(\.orientation)
        )
    }

    @discardableResult
    static func resetIfNeeded<RNG: RandomNumberGenerator>(
        _ state: TarotDailyState,
        now: Date,
        calendar: Calendar,
        random: inout RNG
    ) -> Bool {
        let currentDay = dayIdentifier(for: now, calendar: calendar)
        guard state.dayIdentifier != currentDay else { return false }

        let candidates = makeCandidates(random: &random)
        state.dayIdentifier = currentDay
        state.candidateCardIDs = candidates.map(\.cardID)
        state.candidateOrientationRawValues = candidates.map(\.orientation.rawValue)
        state.selectedIndex = nil
        state.selectedAt = nil
        return true
    }

    @discardableResult
    static func select(
        index: Int,
        at date: Date,
        in state: TarotDailyState
    ) -> Bool {
        guard state.selectedIndex == nil,
              state.candidateCardIDs.indices.contains(index),
              state.candidateOrientationRawValues.indices.contains(index) else {
            return false
        }
        state.selectedIndex = index
        state.selectedAt = date
        return true
    }

    @discardableResult
    static func select(
        index: Int,
        at date: Date,
        in state: TarotDailyState,
        context: ModelContext
    ) throws -> Bool {
        guard select(index: index, at: date, in: state) else { return false }
        try context.save()
        return true
    }

    static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func makeCandidates<RNG: RandomNumberGenerator>(
        random: inout RNG
    ) -> [(cardID: String, orientation: TarotOrientation)] {
        var available = TarotCatalog.cardIDs
        var candidates: [(String, TarotOrientation)] = []

        for _ in 0..<min(3, available.count) {
            let index = Int.random(in: available.indices, using: &random)
            let cardID = available.remove(at: index)
            let orientation: TarotOrientation = Bool.random(using: &random)
                ? .upright
                : .reversed
            candidates.append((cardID, orientation))
        }
        return candidates
    }
}
