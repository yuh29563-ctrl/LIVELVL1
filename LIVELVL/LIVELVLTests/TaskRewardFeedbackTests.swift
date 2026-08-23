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
}
