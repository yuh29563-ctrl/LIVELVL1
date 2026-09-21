import CoreGraphics
import Foundation
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

    @Test func restingArchiveCardsShareOneGroundBaseline() {
        let center = ArchiveCardTransform.make(normalizedDistance: 0, reduceMotion: false)
        let left = ArchiveCardTransform.make(normalizedDistance: -1, reduceMotion: false)
        let right = ArchiveCardTransform.make(normalizedDistance: 1, reduceMotion: false)

        #expect(center.verticalOffset == 0)
        #expect(left.verticalOffset == 0)
        #expect(right.verticalOffset == 0)
    }

    @Test func archiveCardsLiftTenPointsBetweenRestingPositions() {
        let leftHalfway = ArchiveCardTransform.make(
            normalizedDistance: -0.5,
            reduceMotion: false
        )
        let rightHalfway = ArchiveCardTransform.make(
            normalizedDistance: 0.5,
            reduceMotion: false
        )

        #expect(abs(leftHalfway.verticalOffset + 10) < 0.001)
        #expect(abs(rightHalfway.verticalOffset + 10) < 0.001)
    }

    @Test func archiveSidesKeepMirroredYawRollAndStaticDepth() {
        let left = ArchiveCardTransform.make(normalizedDistance: -1, reduceMotion: false)
        let right = ArchiveCardTransform.make(normalizedDistance: 1, reduceMotion: false)

        #expect(abs(left.scale - 0.82) < 0.001)
        #expect(abs(right.scale - 0.82) < 0.001)
        #expect(abs(left.opacity - 0.72) < 0.001)
        #expect(abs(right.opacity - 0.72) < 0.001)
        #expect(left.yawDegrees == -right.yawDegrees)
        #expect(left.rollDegrees == -right.rollDegrees)
        #expect(abs(left.yawDegrees - 28) < 0.001)
        #expect(abs(right.yawDegrees + 28) < 0.001)
        #expect(abs(left.rollDegrees - 3) < 0.001)
        #expect(abs(right.rollDegrees + 3) < 0.001)
    }

    @Test func reducedMotionRemovesLiftButKeepsStableSpatialDepth() {
        let ordinary = ArchiveCardTransform.make(
            normalizedDistance: -0.5,
            reduceMotion: false
        )
        let reduced = ArchiveCardTransform.make(
            normalizedDistance: -0.5,
            reduceMotion: true
        )

        #expect(reduced.verticalOffset == 0)
        #expect(reduced.scale == ordinary.scale)
        #expect(reduced.opacity == ordinary.opacity)
        #expect(reduced.yawDegrees == ordinary.yawDegrees)
        #expect(reduced.rollDegrees == ordinary.rollDegrees)
    }

    @Test func archiveProjectionAnchorsTheCenterAndMirrorsSideCasts() {
        let center = ArchiveCardProjectionStyle.make(normalizedDistance: 0)
        let left = ArchiveCardProjectionStyle.make(normalizedDistance: -1)
        let right = ArchiveCardProjectionStyle.make(normalizedDistance: 1)

        #expect(abs(center.contactWidthRatio - 0.58) < 0.001)
        #expect(abs(center.contactOpacity - 0.27) < 0.001)
        #expect(abs(center.penumbraWidthRatio - 0.86) < 0.001)
        #expect(abs(center.penumbraOpacity - 0.075) < 0.001)
        #expect(abs(center.castLength - 8) < 0.001)
        #expect(center.castHorizontalOffset == 0)

        #expect(center.contactWidthRatio < left.contactWidthRatio)
        #expect(center.contactOpacity > left.contactOpacity)
        #expect(abs(left.castHorizontalOffset + right.castHorizontalOffset) < 0.001)
        #expect(left.castHorizontalOffset > 0)
        #expect(right.castHorizontalOffset < 0)
        #expect(abs(left.castLength - 54) < 0.001)
        #expect(abs(right.castLength - 54) < 0.001)
    }

    @Test func archiveArtworkOccupiesMostOfTheCardWithoutChangingItsRatio() {
        let cardSize = CGSize(width: 240, height: 364.8)
        let frame = ArchiveArtworkComposition.frame(in: cardSize)

        #expect(abs(frame.width / cardSize.width - 0.86) < 0.001)
        #expect(abs(frame.height / cardSize.height - 0.86) < 0.001)
        #expect(abs(frame.midX - cardSize.width / 2) < 0.001)
        #expect(abs(frame.midY - cardSize.height / 2) < 0.001)
    }

    @Test func archiveArrivalOnlyCompletesWhileItIsActuallyVisible() {
        #expect(ArchiveArrivalPresentationActivity.shouldAdvance(
            isCollectionSelected: true,
            isObscured: false,
            isSceneActive: true
        ))
        #expect(!ArchiveArrivalPresentationActivity.shouldAdvance(
            isCollectionSelected: false,
            isObscured: false,
            isSceneActive: true
        ))
        #expect(!ArchiveArrivalPresentationActivity.shouldAdvance(
            isCollectionSelected: true,
            isObscured: true,
            isSceneActive: true
        ))
        #expect(!ArchiveArrivalPresentationActivity.shouldAdvance(
            isCollectionSelected: true,
            isObscured: false,
            isSceneActive: false
        ))
    }

    @Test func closingExpandedArchiveRestoresFocusToItsCarouselCard() {
        #expect(
            ArchiveAccessibilityFocusRestoration.target(awardKey: "core-12")
                == .grid(awardKey: "core-12")
        )
    }

    @Test func voiceOverAdjustmentMovesCenterAndFocusTogether() throws {
        let first = try #require(
            ArchiveAccessibilityNavigation.destination(
                awardKeys: ["a", "b", "c"],
                from: 0,
                increment: true
            )
        )
        #expect(first.awardKey == "b")
        #expect(first.focusTarget == .grid(awardKey: "b"))

        let second = try #require(
            ArchiveAccessibilityNavigation.destination(
                awardKeys: ["a", "b", "c"],
                from: 1,
                increment: true
            )
        )
        #expect(second.awardKey == "c")
        #expect(second.focusTarget == .grid(awardKey: "c"))
    }

    @Test func reducedMotionNeverAnimatesArchiveArrivalCentering() {
        #expect(ArchiveArrivalMotion.allowsAnimatedCentering(reduceMotion: false))
        #expect(!ArchiveArrivalMotion.allowsAnimatedCentering(reduceMotion: true))
    }

    @Test func expandedArchiveCardClearsTheHeaderOnIPhone17Pro() {
        let frame = ArchiveExpandedLayout.cardFrame(
            in: CGSize(width: 368, height: 717)
        )

        #expect(frame == CGRect(x: 66, y: 132, width: 236, height: 470))
        #expect(frame.minY > 112)
    }

    @Test func archiveCarouselUsesTheApprovedResponsiveCardScale() {
        let compact = ArchiveCarouselLayout.make(containerWidth: 340)
        let iPhone17Pro = ArchiveCarouselLayout.make(containerWidth: 374)

        #expect(abs(compact.cardSize.width - 224) < 0.01)
        #expect((0.62...0.66).contains(compact.cardSize.width / 340))
        #expect(abs(compact.cardSize.height / compact.cardSize.width - 1.52) < 0.001)
        #expect(abs(compact.cardCaptionSpacing - 32) < 0.01)
        #expect(abs(compact.captionHeight - 112) < 0.01)
        #expect(abs(ArchiveCarouselLayout.captionLineSpacing - 10) < 0.01)
        #expect(abs(compact.totalHeight - 600.48) < 0.01)

        #expect(abs(iPhone17Pro.cardSize.width - 239.36) < 0.01)
        #expect((0.62...0.66).contains(iPhone17Pro.cardSize.width / 374))
        #expect((224...248).contains(iPhone17Pro.cardSize.width))
        #expect(abs(iPhone17Pro.cardSize.height / iPhone17Pro.cardSize.width - 1.52) < 0.001)
    }

    @Test func archiveCaptionExpandsAtAccessibilitySizesWithoutChangingTheCard() {
        #expect(ArchiveCarouselLayout.resolvedCaptionHeight(isAccessibilitySize: false) == 112)
        #expect(ArchiveCarouselLayout.resolvedCaptionHeight(isAccessibilitySize: true) == 236)
        #expect(abs(ArchiveCarouselLayout.resolvedTotalHeight(
            containerWidth: 340,
            isAccessibilitySize: false
        ) - 600.48) < 0.01)
        #expect(abs(ArchiveCarouselLayout.resolvedTotalHeight(
            containerWidth: 340,
            isAccessibilitySize: true
        ) - 716.48) < 0.01)
        #expect(!ArchiveCarouselLayout.usesVerticalPageScroll(isAccessibilitySize: false))
        #expect(ArchiveCarouselLayout.usesVerticalPageScroll(isAccessibilitySize: true))
    }

    @Test func archiveCaptionKeepsPersistedIdentityLevelAndAcquisitionDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26))!
        let caption = ArchiveCardCaptionPresentation(
            name: "CORE-12",
            kindTitle: "成熟卡",
            sourceTitle: "陪伴成熟",
            awardKey: "ordinary.level.12",
            acquiredAt: date,
            calendar: calendar
        )

        #expect(caption.title == "CORE-12")
        #expect(caption.kindTitle == "成熟卡")
        #expect(caption.levelText == "LV 12")
        #expect(caption.acquiredText == "获得于 08 / 26")
    }

    @Test func archiveTarotEntryDescribesReadyChoosingAndCompletedStates() {
        let ready = ArchiveTarotEntryPresentation(status: .ready)
        let choosing = ArchiveTarotEntryPresentation(status: .choosing)
        let completed = ArchiveTarotEntryPresentation(
            status: .completed(
                cardName: "星星",
                englishName: "THE STAR",
                orientation: "正位",
                artworkAssetName: "TarotRWS17"
            )
        )

        #expect(ready.detail == "今天尚未抽取 · 免费一次")
        #expect(ready.actionTitle == "抽一张")
        #expect(choosing.detail == "牌阵已准备 · 选择尚未完成")
        #expect(choosing.actionTitle == "继续")
        #expect(completed.title == "星星 · THE STAR")
        #expect(completed.detail == "正位 · 点击再次查看今日解析")
        #expect(completed.actionTitle == "查看")
        #expect(completed.artworkAssetName == "TarotRWS17")
        #expect(completed.accessibilityLabel == "今日塔罗，星星，正位，查看今日解读")
    }

    @Test func archiveCardContentClearsDrawPreviewAtStandardSizes() {
        let layout = ArchiveCarouselLayout.make(containerWidth: 368)
        let captionEnd = layout.cardSize.height
            + layout.cardCaptionSpacing
            + layout.captionHeight
            + ArchiveCarouselLayout.cardContentVerticalOffset
        let captionDrawerGap = layout.totalHeight
            - ArchiveCarouselLayout.drawPreviewBottomInset
            - ArchiveCarouselLayout.drawPreviewHeight
            - captionEnd

        #expect(captionDrawerGap >= 24)
    }

    @Test func archivePageKeepsCarouselAboveTheTabBarAtStandardHeight() {
        #expect(ArchiveCarouselLayout.pageTopPadding == 34)
    }

    @Test func archiveDrawPreviewUsesOneCornerRadius() {
        #expect(ArchiveCarouselLayout.drawPreviewCornerRadius == 22)
    }

    @Test func archiveHeaderShowsTheCenteredPositionWithinOwnedCards() {
        let keys = ["ordinary.sprout", "ordinary.hare", "ordinary.tortoise"]

        #expect(ArchiveCarouselPosition.displayIndex(
            awardKey: "ordinary.hare",
            awardKeys: keys
        ) == 2)
        #expect(ArchiveCarouselPosition.displayIndex(
            awardKey: nil,
            awardKeys: keys
        ) == 1)
        #expect(ArchiveCarouselPosition.displayIndex(
            awardKey: nil,
            awardKeys: []
        ) == 0)
    }

    @Test func expandedArchiveHidesCarouselCaptionsBehindTheDetailCard() {
        #expect(ArchiveCarouselCaptionVisibility.opacity(
            isExpanded: false,
            normalizedDistance: 0
        ) == 1)
        #expect(ArchiveCarouselCaptionVisibility.opacity(
            isExpanded: true,
            normalizedDistance: 0
        ) == 0)
    }

    @Test func archiveAccessibilityDescribesPositionAndNewState() {
        let value = ArchiveCardAccessibility.value(
            name: "小芽",
            index: 1,
            count: 3,
            isUnseen: true,
            sourceTitle: "陪伴成熟"
        )
        #expect(value == "小芽，第 1 张，共 3 张，新收藏，获得来源 陪伴成熟")
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

    @Test func claimedCardLandsAtMostOncePerPresentationSession() {
        var state = ArchiveArrivalPresentationState()
        state.registerClaimed(awardKey: "ordinary.level.4")

        #expect(
            state.takeArrivalIfNeeded(validAwardKeys: ["ordinary.level.4"])
                == "ordinary.level.4"
        )
        state.markCompleted(awardKey: "ordinary.level.4")
        #expect(state.takeArrivalIfNeeded(validAwardKeys: ["ordinary.level.4"]) == nil)
    }

    @Test func arrivalWaitsForThePersistedOwnedRow() {
        var state = ArchiveArrivalPresentationState()
        state.registerClaimed(awardKey: "hidden.study")

        #expect(state.takeArrivalIfNeeded(validAwardKeys: []) == nil)
        #expect(
            state.takeArrivalIfNeeded(validAwardKeys: ["hidden.study"])
                == "hidden.study"
        )
    }

    @Test func successiveClaimsKeepTheirArrivalOrderUntilEachCardSettles() {
        var state = ArchiveArrivalPresentationState()
        state.registerClaimed(awardKey: "ordinary.level.4")
        state.registerClaimed(awardKey: "hidden.study")
        let validAwardKeys: Set<String> = ["ordinary.level.4", "hidden.study"]

        #expect(state.takeArrivalIfNeeded(validAwardKeys: validAwardKeys) == "ordinary.level.4")
        state.markCompleted(awardKey: "ordinary.level.4")
        #expect(state.takeArrivalIfNeeded(validAwardKeys: validAwardKeys) == "hidden.study")
    }

    @Test func archiveArrivalTraceFlowsFromTabToTheCenteredCard() throws {
        let samples = ArchiveArrivalTraceGeometry.samples(
            progress: 1,
            phase: 0.2,
            reduceMotion: false
        )
        let first = try #require(samples.first)
        let last = try #require(samples.last)

        #expect(samples.count == 48)
        #expect(abs(first.position.x - 0.50) < 0.03)
        #expect(first.position.y > 1)
        #expect(abs(last.position.x - 0.50) < 0.03)
        #expect(last.position.y < 0.72)
        #expect(samples.allSatisfy { $0.opacity > 0 && $0.diameter > 0 })
    }

    @Test func archiveArrivalParticlesDanceNormallyAndDisappearForReduceMotion() {
        let movingA = ArchiveArrivalTraceGeometry.samples(
            progress: 0.7,
            phase: 0,
            reduceMotion: false
        )
        let movingB = ArchiveArrivalTraceGeometry.samples(
            progress: 0.7,
            phase: 0.4,
            reduceMotion: false
        )
        let reduced = ArchiveArrivalTraceGeometry.samples(
            progress: 1,
            phase: 0.4,
            reduceMotion: true
        )

        #expect(movingA != movingB)
        #expect(reduced.isEmpty)
    }
}
