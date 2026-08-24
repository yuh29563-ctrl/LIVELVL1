import Testing
@testable import LIVELVL

@MainActor
struct CollectionViewStateTests {
    private enum SeenFailure: Error {
        case saveFailed
    }

    @Test func staleSelectionClosesAndResetsTheCardFace() {
        var state = CollectionSelectionState()
        state.select(focusTarget: .grid(awardKey: "owned.latest"))
        state.setShowingBack(true)

        state.reconcile(validAwardKeys: [])

        #expect(state.selectedAwardKey == nil)
        #expect(!state.isShowingBack)
    }

    @Test func liveSelectionSurvivesQueryReconciliation() {
        var state = CollectionSelectionState()
        state.select(focusTarget: .grid(awardKey: "owned.latest"))
        state.setShowingBack(true)

        state.reconcile(validAwardKeys: ["owned.latest", "owned.older"])

        #expect(state.selectedAwardKey == "owned.latest")
        #expect(state.isShowingBack)
    }

    @Test func closingExpandedFeaturedCardRestoresFocusToItsInitiator() {
        var state = CollectionSelectionState()
        let initiator = CollectionCardFocusTarget.featured(awardKey: "owned.latest")
        state.select(focusTarget: initiator)
        state.setShowingBack(true)

        let focusTarget = state.close()

        #expect(focusTarget == initiator)
        #expect(state.selectedAwardKey == nil)
        #expect(!state.isShowingBack)
    }

    @Test func closingExpandedGridCardRestoresFocusToItsInitiator() {
        var state = CollectionSelectionState()
        let initiator = CollectionCardFocusTarget.grid(awardKey: "owned.older")
        state.select(focusTarget: initiator)

        #expect(state.close() == initiator)
    }

    @Test func claimOnSelectedCollectionMarksVisibleCardOnlyAfterOverlayDismissal() {
        var visibility = CollectionSeenVisibilityState()
        let claimedCard = CollectionCardFocusTarget.featured(
            awardKey: "ordinary.level.1"
        )
        visibility.appeared(claimedCard)
        let unseenKeys: Set<String> = ["ordinary.level.1"]

        #expect(visibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenKeys,
            isCollectionSelected: true,
            isObscured: true
        ).isEmpty)
        #expect(visibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenKeys,
            isCollectionSelected: true,
            isObscured: false
        ) == unseenKeys)
    }

    @Test func leavingCollectionBeforeDismissalPreservesTheClaimAsUnseen() {
        var visibility = CollectionSeenVisibilityState()
        visibility.appeared(.grid(awardKey: "ordinary.level.1"))

        #expect(visibility.awardKeysToMarkSeen(
            unseenAwardKeys: ["ordinary.level.1"],
            isCollectionSelected: false,
            isObscured: false
        ).isEmpty)
    }

    @Test func failedSeenAttemptReportsRetryWithoutSignalingSuccess() {
        var state = CollectionSeenRetryState()
        let didBegin = state.beginAttempt(hasUnseenCollectibles: true)
        #expect(didBegin)

        let shouldSignalSeen = state.finishAttempt(
            .failure(SeenFailure.saveFailed)
        )

        #expect(!shouldSignalSeen)
        #expect(state.needsRetry)
        #expect(state.errorMessage == "未能更新查看状态")
        let didBeginRetry = state.beginAttempt(hasUnseenCollectibles: true)
        #expect(didBeginRetry)
    }

    @Test func successfulSeenRetryClearsErrorAndSignalsPersistenceSuccess() {
        var state = CollectionSeenRetryState()
        let didBegin = state.beginAttempt(hasUnseenCollectibles: true)
        #expect(didBegin)
        _ = state.finishAttempt(.failure(SeenFailure.saveFailed))
        let didBeginRetry = state.beginAttempt(hasUnseenCollectibles: true)
        #expect(didBeginRetry)

        let shouldSignalSeen = state.finishAttempt(.success(()))

        #expect(shouldSignalSeen)
        #expect(!state.needsRetry)
        #expect(state.errorMessage == nil)
    }

    @Test func seenAttemptIsIdempotentWithoutUnseenRows() {
        var state = CollectionSeenRetryState()

        let didBegin = state.beginAttempt(hasUnseenCollectibles: false)
        #expect(!didBegin)
        #expect(!state.isAttempting)
        #expect(!state.needsRetry)
    }
}
