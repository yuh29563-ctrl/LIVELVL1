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

    @Test func carouselKeepsCenterSeparateFromExpansion() {
        var state = ArchiveCarouselState()
        state.reconcile(orderedAwardKeys: ["new", "old"])
        #expect(state.centeredAwardKey == "new")

        state.center("old")
        state.expandCentered()

        #expect(state.centeredAwardKey == "old")
        #expect(state.expandedAwardKey == "old")
        state.closeExpanded()
        #expect(state.centeredAwardKey == "old")
        #expect(state.expandedAwardKey == nil)
        #expect(!state.isShowingBack)
    }

    @Test func staleCarouselKeysReconcileWithoutChangingAValidCenter() {
        var state = ArchiveCarouselState()
        state.reconcile(orderedAwardKeys: ["new", "old"])
        state.center("old")
        state.expandCentered()

        state.reconcile(orderedAwardKeys: ["old", "older"])
        #expect(state.centeredAwardKey == "old")
        #expect(state.expandedAwardKey == "old")

        state.reconcile(orderedAwardKeys: ["older"])
        #expect(state.centeredAwardKey == "older")
        #expect(state.expandedAwardKey == nil)
    }

    @Test func transientNilScrollPositionDoesNotDiscardAValidCenter() {
        var state = ArchiveCarouselState()
        state.reconcile(orderedAwardKeys: ["new", "old"])

        state.updateScrollPosition(nil, orderedAwardKeys: ["new", "old"])
        #expect(state.centeredAwardKey == "new")

        state.updateScrollPosition("old", orderedAwardKeys: ["new", "old"])
        #expect(state.centeredAwardKey == "old")

        state.updateScrollPosition(nil, orderedAwardKeys: [])
        #expect(state.centeredAwardKey == nil)
    }

    @Test func onlyCenteredUnobscuredCardBecomesSeen() {
        var visibility = CollectionSeenVisibilityState()
        visibility.center("center")

        let result = visibility.awardKeysToMarkSeen(
            unseenAwardKeys: ["left", "center", "right"],
            isCollectionSelected: true,
            isObscured: false
        )

        #expect(result == ["center"])
    }

    @Test func archiveDepthIsRestrainedAndReducedMotionIsFlat() {
        let normal = ArchiveCardTransform.make(
            normalizedDistance: 1,
            reduceMotion: false
        )
        #expect(normal.scale == 0.88)
        #expect(normal.opacity == 0.55)
        #expect(abs(normal.rotationDegrees) <= 3)

        let reduced = ArchiveCardTransform.make(
            normalizedDistance: -1,
            reduceMotion: true
        )
        #expect(reduced.rotationDegrees == 0)
        #expect(reduced.scale == 0.88)
    }

    @Test func archiveAccessibilityDescribesPositionAndNewState() {
        let value = ArchiveCardAccessibility.value(
            name: "小芽",
            index: 1,
            count: 3,
            isUnseen: true
        )
        #expect(value == "小芽，第 1 张，共 3 张，新收藏")
    }

    @Test func archiveMetadataUsesPersistedKinds() {
        #expect(ArchiveCardMetadata.kindTitle(for: .ordinaryMature) == "成熟卡")
        #expect(ArchiveCardMetadata.kindTitle(for: .hiddenDiscovery) == "隐藏发现")
    }

    @Test func archiveOrganismParticlesAreStableDistinctAndMotionAware() {
        let first = ArchiveOrganismGeometry.samples(
            identifier: "ordinary.sprout",
            count: 180,
            phase: 0.1,
            reduceMotion: false
        )
        let repeated = ArchiveOrganismGeometry.samples(
            identifier: "ordinary.sprout",
            count: 180,
            phase: 0.1,
            reduceMotion: false
        )
        let moved = ArchiveOrganismGeometry.samples(
            identifier: "ordinary.sprout",
            count: 180,
            phase: 0.5,
            reduceMotion: false
        )
        let different = ArchiveOrganismGeometry.samples(
            identifier: "hidden.study-streak",
            count: 180,
            phase: 0.1,
            reduceMotion: false
        )
        let frozenA = ArchiveOrganismGeometry.samples(
            identifier: "ordinary.sprout",
            count: 180,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = ArchiveOrganismGeometry.samples(
            identifier: "ordinary.sprout",
            count: 180,
            phase: 0.8,
            reduceMotion: true
        )

        #expect(first.count == 180)
        #expect(first == repeated)
        #expect(first != moved)
        #expect(first != different)
        #expect(frozenA == frozenB)
        #expect(first.allSatisfy {
            (0...1).contains($0.position.x)
                && (0...1).contains($0.position.y)
                && (0...1).contains($0.opacity)
                && $0.diameter > 0
        })
    }

    @Test func archiveOrganismArmsBranchOutAndRespectReduceMotion() {
        let normalA = ArchiveOrganismGeometry.arms(
            identifier: "ordinary.sprout",
            phase: 0,
            reduceMotion: false
        )
        let normalB = ArchiveOrganismGeometry.arms(
            identifier: "ordinary.sprout",
            phase: 0.4,
            reduceMotion: false
        )
        let frozenA = ArchiveOrganismGeometry.arms(
            identifier: "ordinary.sprout",
            phase: 0,
            reduceMotion: true
        )
        let frozenB = ArchiveOrganismGeometry.arms(
            identifier: "ordinary.sprout",
            phase: 0.9,
            reduceMotion: true
        )

        #expect(normalA.count == 9)
        #expect(normalA.allSatisfy { $0.points.count == 12 })
        #expect(normalA != normalB)
        #expect(frozenA == frozenB)
        #expect(normalA.flatMap(\.points).allSatisfy {
            (0...1).contains($0.x) && (0...1).contains($0.y)
        })
    }
}
