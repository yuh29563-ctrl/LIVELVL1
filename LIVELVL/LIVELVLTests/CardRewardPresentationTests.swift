import Testing
@testable import LIVELVL

struct CardRewardPresentationTests {
    @Test func claimRegistersAttention() {
        var state = CollectionAttentionState()
        state.registerClaim()
        #expect(state.shakeToken == 1)
        #expect(state.hasUnseenReward)
        state.markSeen()
        #expect(!state.hasUnseenReward)
    }
}
