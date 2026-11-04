import Testing
@testable import LIVELVL

struct CompanionProgressionEngineTests {
    @Test func approvedTimeline() {
        #expect(CompanionProgressionEngine.event(forReachedLevel: 0) == .active(index: 0, stage: .juvenile))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 1) == .matured(index: 0, nextIndex: 1, maturityLevel: 1))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 2) == .matured(index: 1, nextIndex: 2, maturityLevel: 2))
        #expect(CompanionProgressionEngine.event(forReachedLevel: 3) == .matured(index: 2, nextIndex: 3, maturityLevel: 3))
    }
}
