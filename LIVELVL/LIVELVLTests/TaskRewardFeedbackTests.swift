import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct TaskRewardFeedbackTests {
    @Test func completionFeedbackKeepsRewardAndDimensionTogether() {
        let itemID = UUID()

        let feedback = TaskRewardFeedback(
            itemID: itemID,
            xp: 35,
            dimension: .learning,
            levelBefore: 2,
            levelAfter: 2
        )

        #expect(feedback.itemID == itemID)
        #expect(feedback.dimension == .learning)
        #expect(feedback.label == "+35 XP")
    }

    @Test func levelUpRequiresAnIncreasedLevel() {
        let unchanged = TaskRewardFeedback(
            itemID: UUID(),
            xp: 20,
            dimension: .health,
            levelBefore: 3,
            levelAfter: 3
        )
        let increased = TaskRewardFeedback(
            itemID: UUID(),
            xp: 50,
            dimension: .career,
            levelBefore: 3,
            levelAfter: 4
        )

        #expect(unchanged.didLevelUp == false)
        #expect(increased.didLevelUp == true)
    }

    @Test func growthMovesFromTaskThroughDimensionIntoCoreAndLevelUp() {
        let feedback = TaskRewardFeedback(
            itemID: UUID(),
            xp: 20,
            dimension: .health,
            levelBefore: 1,
            levelAfter: 2
        )
        var state = TodayGrowthPresentationState()

        state.begin(feedback)
        #expect(state.phase == .task(feedback.id))
        #expect(state.feedback == feedback)

        state.advance()
        #expect(state.phase == .dimension(.health))

        state.advance()
        #expect(state.phase == .core)

        state.advance()
        #expect(state.phase == .levelUp(2))

        state.advance()
        #expect(state.phase == .idle)
        #expect(state.feedback == nil)
    }

    @Test func growthWithoutLevelUpFinishesAfterReachingTheCore() {
        let feedback = TaskRewardFeedback(
            itemID: UUID(),
            xp: 10,
            dimension: .learning,
            levelBefore: 2,
            levelAfter: 2
        )
        var state = TodayGrowthPresentationState()

        state.begin(feedback)
        state.advance()
        state.advance()
        state.advance()

        #expect(state.phase == .idle)
        #expect(state.feedback == nil)
    }

    @Test func revokeOrFailureCancelsTheEntireGrowthPresentation() {
        var state = TodayGrowthPresentationState()
        state.begin(
            TaskRewardFeedback(
                itemID: UUID(),
                xp: 10,
                dimension: .learning,
                levelBefore: 1,
                levelAfter: 1
            )
        )

        state.cancel()

        #expect(state.phase == .idle)
        #expect(state.feedback == nil)
    }

    @Test func xpFlowUsesAtMostEighteenParticlesAndPassesThroughTheDimension() throws {
        let start = CGPoint(x: 340, y: 680)
        let dimension = CGPoint(x: 310, y: 220)
        let core = CGPoint(x: 190, y: 360)

        let samples = XPFlowGeometry.samples(
            start: start,
            dimension: dimension,
            core: core,
            progress: 1,
            phase: 0.2,
            reduceMotion: false
        )

        #expect(samples.count <= 18)
        #expect(samples.first?.position == start)
        #expect(samples.last?.position == core)
        #expect(samples.contains { $0.position == dimension })
        #expect(samples.allSatisfy { $0.opacity > 0 && $0.diameter >= 1 })
    }

    @Test func xpFlowStopsAtTheDimensionBeforeEnteringTheCore() {
        let start = CGPoint(x: 340, y: 680)
        let dimension = CGPoint(x: 310, y: 220)
        let core = CGPoint(x: 190, y: 360)
        let join = XPFlowGeometry.joinProgress(
            start: start,
            dimension: dimension,
            core: core
        )

        let samples = XPFlowGeometry.samples(
            start: start,
            dimension: dimension,
            core: core,
            progress: join,
            phase: 0.2,
            reduceMotion: false
        )

        #expect(samples.last?.position == dimension)
        #expect(!samples.contains { $0.position == core })
    }

    @Test func reduceMotionRemovesTheSpatialXPParticlePath() {
        let samples = XPFlowGeometry.samples(
            start: CGPoint(x: 340, y: 680),
            dimension: CGPoint(x: 310, y: 220),
            core: CGPoint(x: 190, y: 360),
            progress: 1,
            phase: 0.8,
            reduceMotion: true
        )

        #expect(samples.isEmpty)
    }
}
