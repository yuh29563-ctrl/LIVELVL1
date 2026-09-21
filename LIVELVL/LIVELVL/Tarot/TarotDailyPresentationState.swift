import Foundation

struct TarotDailyPresentationState: Equatable, Sendable {
    private(set) var dayIdentifier: String?
    private(set) var chosenIndex: Int?
    private(set) var isCardRevealed = false
    private(set) var showsReading = false

    mutating func begin(dayIdentifier: String) {
        guard self.dayIdentifier != dayIdentifier else { return }
        self.dayIdentifier = dayIdentifier
        chosenIndex = nil
        isCardRevealed = false
        showsReading = false
    }

    mutating func choose(index: Int, on dayIdentifier: String) {
        guard self.dayIdentifier == dayIdentifier else { return }
        chosenIndex = index
    }

    mutating func reveal(on dayIdentifier: String) {
        guard self.dayIdentifier == dayIdentifier else { return }
        isCardRevealed = true
    }

    mutating func showReading(on dayIdentifier: String) {
        guard self.dayIdentifier == dayIdentifier else { return }
        showsReading = true
    }

    mutating func restore(selectedIndex: Int?, on dayIdentifier: String) {
        guard let selectedIndex else { return }
        choose(index: selectedIndex, on: dayIdentifier)
        reveal(on: dayIdentifier)
        showReading(on: dayIdentifier)
    }
}
