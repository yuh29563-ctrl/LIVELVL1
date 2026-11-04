enum CompanionProgressionEvent: Equatable, Sendable {
    case active(index: Int, stage: CompanionStage)
    case matured(index: Int, nextIndex: Int, maturityLevel: Int)
}

enum CompanionProgressionEngine {
    static func event(
        forReachedLevel rawLevel: Int,
        nextOrdinaryIndex: Int? = nil
    ) -> CompanionProgressionEvent {
        let level = max(0, rawLevel)
        if level == 0 { return .active(index: 0, stage: .juvenile) }
        let index = max(0, nextOrdinaryIndex ?? level - 1)
        return .matured(index: index, nextIndex: index + 1, maturityLevel: level)
    }
}
