import Testing
@testable import LIVELVL

struct CompanionProgressionEngineTests {
    @Test func approvedTimeline() {
        #expect(CompanionProgressionEngine.event(forReachedLevel: 0) == .active(index: 0, stage: .juvenile))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 1) == .matured(index: 0, nextIndex: 1, maturityLevel: 1))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 2) == .active(index: 1, stage: .stageTwo))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 3) == .active(index: 1, stage: .stageThree))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 4) == .matured(index: 1, nextIndex: 2, maturityLevel: 4))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 5) == .active(index: 2, stage: .stageTwo))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 6) == .active(index: 2, stage: .stageThree))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 7) == .matured(index: 2, nextIndex: 3, maturityLevel: 7))
    }
}
