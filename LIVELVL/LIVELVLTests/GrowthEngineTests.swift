import Testing
@testable import LIVELVL

struct GrowthEngineTests {
    @Test func levelBoundaries() {
        #expect(GrowthEngine.level(for: 0) == 0)
        #expect(GrowthEngine.level(for: 199) == 0)
        #expect(GrowthEngine.level(for: 200) == 1)
        #expect(GrowthEngine.level(for: 2_199) == 1)
        #expect(GrowthEngine.level(for: 2_200) == 2)
        #expect(GrowthEngine.level(for: 4_200) == 3)
    }

    @Test func progressUsesTwoHundredThenTwoThousand() {
        #expect(GrowthEngine.xpInCurrentLevel(for: 100) == 100)
        #expect(GrowthEngine.xpNeededForNextLevel(for: 100) == 200)
        #expect(GrowthEngine.progressToNextLevel(for: 100) == 0.5)
        #expect(GrowthEngine.xpInCurrentLevel(for: 2_700) == 500)
        #expect(GrowthEngine.xpNeededForNextLevel(for: 2_700) == 2_000)
        #expect(GrowthEngine.progressToNextLevel(for: 2_700) == 0.25)
    }
}
