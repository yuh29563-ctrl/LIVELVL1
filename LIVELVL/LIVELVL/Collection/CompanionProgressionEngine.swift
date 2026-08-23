enum CompanionProgressionEvent: Equatable, Sendable {
    case active(index: Int, stage: CompanionStage)
    case matured(index: Int, nextIndex: Int, maturityLevel: Int)
}

enum CompanionProgressionEngine {
    static func event(forReachedLevel rawLevel: Int) -> CompanionProgressionEvent {
        let level = max(0, rawLevel)
        if level == 0 { return .active(index: 0, stage: .juvenile) }
        if level == 1 { return .matured(index: 0, nextIndex: 1, maturityLevel: 1) }
        switch (level - 1) % 3 {
        case 1: return .active(index: (level - 1) / 3 + 1, stage: .stageTwo)
        case 2: return .active(index: (level - 1) / 3 + 1, stage: .stageThree)
        default:
            let index = (level - 4) / 3 + 1
            return .matured(index: index, nextIndex: index + 1, maturityLevel: level)
        }
    }
}
