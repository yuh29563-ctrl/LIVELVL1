import Foundation

nonisolated enum TarotCardFlipEffects {
    static func shadowPulse(at angle: Double) -> Double {
        let lift = abs(sin(angle * .pi / 180))
        let pulse = pow(lift, 3)
        return pulse < 0.000_001 ? 0 : min(1, pulse)
    }
}

nonisolated struct TarotCardFlipState: Equatable, Sendable {
    private(set) var completedHalfTurns = 0
    private(set) var isFlipping = false

    var showsBack: Bool {
        !completedHalfTurns.isMultiple(of: 2)
    }

    var acceptsInput: Bool {
        !isFlipping
    }

    var targetAngle: Double {
        Double(completedHalfTurns + (isFlipping ? 1 : 0)) * 180
    }

    mutating func begin() -> Bool {
        guard !isFlipping else { return false }
        isFlipping = true
        return true
    }

    mutating func complete() {
        guard isFlipping else { return }
        completedHalfTurns += 1
        isFlipping = false
    }
}
