import Testing
@testable import LIVELVL

struct LivingOSDotFieldTests {
    @Test func samplesAreDeterministicNormalizedAndBounded() {
        let first = LivingDotFieldGeometry.samples(
            columns: 4,
            rows: 3,
            phase: 0.25,
            reduceMotion: false
        )
        let second = LivingDotFieldGeometry.samples(
            columns: 4,
            rows: 3,
            phase: 0.25,
            reduceMotion: false
        )

        #expect(first == second)
        #expect(first.count == 12)
        #expect(first.allSatisfy {
            (0...1).contains($0.position.x) && (0...1).contains($0.position.y)
        })
        #expect(first.allSatisfy {
            (0...1).contains($0.opacity) && $0.diameter > 0
        })
    }

    @Test func reducedMotionFreezesThePointFieldPhase() {
        let first = LivingDotFieldGeometry.samples(
            columns: 5,
            rows: 5,
            phase: 0,
            reduceMotion: true
        )
        let second = LivingDotFieldGeometry.samples(
            columns: 5,
            rows: 5,
            phase: 0.9,
            reduceMotion: true
        )

        #expect(first == second)
    }

    @Test func normalMotionDriftsPositionsWithoutLeavingTheCanvas() {
        let first = LivingDotFieldGeometry.samples(
            columns: 8,
            rows: 8,
            phase: 0,
            reduceMotion: false
        )
        let second = LivingDotFieldGeometry.samples(
            columns: 8,
            rows: 8,
            phase: 0.4,
            reduceMotion: false
        )

        #expect(first.map(\.position) != second.map(\.position))
        #expect(second.allSatisfy {
            (0...1).contains($0.position.x) && (0...1).contains($0.position.y)
        })
    }

    @Test func invalidGridDimensionsProduceNoSamples() {
        #expect(LivingDotFieldGeometry.samples(
            columns: 0,
            rows: 8,
            phase: 0,
            reduceMotion: false
        ).isEmpty)
        #expect(LivingDotFieldGeometry.samples(
            columns: 8,
            rows: -1,
            phase: 0,
            reduceMotion: false
        ).isEmpty)
    }
}
