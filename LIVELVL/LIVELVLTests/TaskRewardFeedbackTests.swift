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
            dimension: .learning
        )

        #expect(feedback.itemID == itemID)
        #expect(feedback.dimension == .learning)
        #expect(feedback.label == "+35 XP")
    }
}
