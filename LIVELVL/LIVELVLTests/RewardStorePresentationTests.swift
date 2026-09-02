import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct RewardStorePresentationTests {
    @Test func accessibilityBalanceMovesTheLedgerBelowTheNumber() {
        #expect(!RewardStoreLayout.usesVerticalBalanceLayout(isAccessibilitySize: false))
        #expect(RewardStoreLayout.usesVerticalBalanceLayout(isAccessibilitySize: true))
        #expect(RewardStoreLayout.heroMinimumScale == 0.55)
    }

    @Test func unavailableBalanceNeverEnablesRedemption() {
        let balance = RewardBalancePresentation.unavailable

        #expect(balance.coinUnits == nil)
        #expect(!balance.allowsRedemption)
    }

    @Test func textOnlyProductReportsAffordabilityWithoutAnIcon() {
        let row = RewardProductRailPresentation(
            name: "看一场电影",
            priceCoinUnits: 180,
            note: "周末",
            imageReference: nil,
            balanceCoinUnits: 275,
            isArchived: false
        )

        #expect(!row.showsImage)
        #expect(row.canRedeem)
        #expect(row.statusText == "可兑换")
        #expect(row.fallbackSystemImageName == nil)
        #expect(row.trailingAccessory == .redeem)
        #expect(row.accessibilityLabel == "看一场电影，18.0 金币，周末，可兑换")
    }

    @Test func productImageOccupiesTheReferenceTrailingMediaSlot() {
        let row = RewardProductRailPresentation(
            name: "一杯咖啡",
            priceCoinUnits: 50,
            note: "完成本周目标后",
            imageReference: "coffee.jpg",
            balanceCoinUnits: 275,
            isArchived: false
        )

        #expect(row.trailingAccessory == .image)
    }

    @Test func insufficientProductUsesTextState() {
        let row = RewardProductRailPresentation(
            name: "周末旅行",
            priceCoinUnits: 1_200,
            note: "",
            imageReference: nil,
            balanceCoinUnits: 275,
            isArchived: false
        )

        #expect(!row.canRedeem)
        #expect(row.statusText == "余额不足")
        #expect(row.trailingAccessory == .insufficient)
        #expect(row.accessibilityLabel == "周末旅行，120.0 金币，余额不足")
    }

    @Test func unavailableBalanceUsesAnUnavailableStateInsteadOfInsufficient() {
        let row = RewardProductRailPresentation(
            name: "看一场电影",
            priceCoinUnits: 180,
            note: "",
            imageReference: nil,
            balanceCoinUnits: nil,
            isArchived: false
        )

        #expect(!row.canRedeem)
        #expect(row.statusText == "余额不可用")
    }

    @Test func archivedProductDoesNotExposeArchivingAgain() {
        let row = RewardProductRailPresentation(
            name: "旧奖励",
            priceCoinUnits: 100,
            note: "",
            imageReference: nil,
            balanceCoinUnits: 500,
            isArchived: true
        )

        #expect(!row.canRedeem)
        #expect(!row.canArchive)
        #expect(row.statusText == "已归档")
    }

    @Test func redeemedProductShowsRedeemedAndCannotBeRedeemedAgain() {
        let row = RewardProductRailPresentation(
            name: "已兑换奖励",
            priceCoinUnits: 100,
            note: "",
            imageReference: nil,
            balanceCoinUnits: 500,
            isArchived: false,
            isRedeemed: true
        )

        #expect(!row.canRedeem)
        #expect(row.statusText == "已兑换")
        #expect(row.trailingAccessory == .redeemed)
        #expect(row.accessibilityLabel == "已兑换奖励，10.0 金币，已兑换")
    }

    @Test func repeatConfirmationReusesOneSubmissionUntilFinish() throws {
        let productID = UUID()
        var state = RewardRedemptionSubmissionState()
        let firstAttempt = state.begin(productID: productID)
        let first = try #require(firstAttempt)

        #expect(state.begin(productID: productID) == nil)
        #expect(state.requestKey == first)
        state.finish()
        #expect(!state.isSubmitting)
    }

    @Test func ledgerMapsIntegerCoinUnitsToFullPartialAndOverflowPoints() {
        let cases: [(coinUnits: Int, full: Int, partial: Double, overflow: Int)] = [
            (0, 0, 0, 0),
            (1, 0, 0.01, 0),
            (10, 0, 0.10, 0),
            (275, 2, 0.75, 0),
            (1_440, 14, 0.40, 0),
            (1_565, 15, 0.65, 0),
            (14_400, 144, 0, 0),
            (14_525, 144, 0, 125),
        ]

        for item in cases {
            let fill = RewardLedgerGeometry.fill(
                columns: 24,
                rows: 6,
                balanceCoinUnits: item.coinUnits
            )

            #expect(fill.fullPointCount == item.full)
            #expect(abs(fill.partialPointFraction - item.partial) < 0.000_1)
            #expect(fill.overflowCoinUnits == item.overflow)
        }

        #expect(RewardLedgerGeometry.fill(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 14_525
        ).overflowText == "+12.5")
    }

    @Test func ledgerFillsBottomRowLeftToRightBeforeMovingUp() throws {
        let samples = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 2_575,
            phase: 0,
            reduceMotion: true
        )
        let bottomRow = samples.filter { $0.row == 5 }
        let nextRow = samples.filter { $0.row == 4 }

        #expect(bottomRow.count == 24)
        #expect(bottomRow.allSatisfy { $0.fillFraction == 1 })
        #expect(nextRow.first { $0.column == 0 }?.fillFraction == 1)
        #expect(nextRow.first { $0.column == 1 }?.fillFraction == 0.75)
        #expect(nextRow.first { $0.column == 2 }?.fillFraction == 0)
    }

    @Test func ledgerDotsDriftNormallyAndFreezeForReduceMotion() {
        let movingA = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 275,
            phase: 0,
            reduceMotion: false
        )
        let movingB = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 275,
            phase: 0.4,
            reduceMotion: false
        )
        let frozenA = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 275,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            balanceCoinUnits: 275,
            phase: 0.8,
            reduceMotion: true
        )

        #expect(movingA.count == 144)
        #expect(movingA != movingB)
        #expect(frozenA == frozenB)
        #expect(movingA.filter(\.isFilled).count == 2)
        #expect(movingA.filter(\.isFilled).allSatisfy { $0.row == 5 })
        #expect(abs((movingA.first { $0.row == 5 && $0.column == 2 }?.fillFraction ?? 0) - 0.75) < 0.000_1)
        #expect(movingA.allSatisfy {
            (0...1).contains($0.position.x)
                && (0...1).contains($0.position.y)
                && $0.opacity > 0
                && $0.diameter > 0
        })
    }

    @Test func ledgerVisualCanInterpolateBetweenIntegerBalances() {
        let samples = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            displayedBalanceCoinUnits: 237.5,
            phase: 0,
            reduceMotion: true
        )

        #expect(samples.filter(\.isFilled).count == 2)
        #expect(abs((samples.first { $0.row == 5 && $0.column == 2 }?.fillFraction ?? 0) - 0.375) < 0.000_1)
    }

    @Test func approvedRewardsLayoutUsesTheReferenceVerticalRhythm() {
        #expect(RewardStoreLayout.pageTopPadding == 8)
        #expect(RewardStoreLayout.balanceTopSpacing == 24)
        #expect(RewardStoreLayout.balanceInternalSpacing == 0)
        #expect(RewardStoreLayout.productTopSpacing == 69)
    }

    @Test func guidanceTrailUsesMeasuredEndpointsAndFreezesForReduceMotion() throws {
        let source = CGPoint(x: 42, y: 118)
        let destination = CGPoint(x: 314, y: 526)
        let start = RewardGuidanceTrailGeometry.samples(
            count: 42,
            phase: 0,
            reduceMotion: false,
            start: source,
            end: destination,
            status: .affordable
        )
        let moved = RewardGuidanceTrailGeometry.samples(
            count: 42,
            phase: 0.4,
            reduceMotion: false,
            start: source,
            end: destination,
            status: .affordable
        )
        let reducedA = RewardGuidanceTrailGeometry.samples(
            count: 42,
            phase: 0,
            reduceMotion: true,
            start: source,
            end: destination,
            status: .affordable
        )
        let reducedB = RewardGuidanceTrailGeometry.samples(
            count: 42,
            phase: 0.8,
            reduceMotion: true,
            start: source,
            end: destination,
            status: .affordable
        )
        let first = try #require(start.first)
        let last = try #require(start.last)

        #expect(start.count == 42)
        #expect(first.position == source)
        #expect(last.position == destination)
        #expect(start != moved)
        #expect(reducedA == reducedB)
        #expect(reducedA.first?.position == source)
        #expect(reducedA.last?.position == destination)
    }

    @Test func progressGuidanceTrailIsLighterThanAffordableTrail() {
        let source = CGPoint(x: 20, y: 80)
        let destination = CGPoint(x: 280, y: 460)
        let affordable = RewardGuidanceTrailGeometry.samples(
            count: 32,
            phase: 0.2,
            reduceMotion: false,
            start: source,
            end: destination,
            status: .affordable
        )
        let progress = RewardGuidanceTrailGeometry.samples(
            count: 32,
            phase: 0.2,
            reduceMotion: false,
            start: source,
            end: destination,
            status: .progress(missingCoinUnits: 25)
        )

        #expect(!affordable.isEmpty)
        #expect(zip(progress, affordable).allSatisfy { $0.opacity < $1.opacity })
    }

    @Test func trailingGuidanceBowsIntoOpenSpaceBeforeEnteringTheTarget() throws {
        let samples = RewardGuidanceTrailGeometry.samples(
            count: 41,
            phase: 0,
            reduceMotion: true,
            start: CGPoint(x: 270, y: 150),
            end: CGPoint(x: 300, y: 560),
            status: .affordable
        )
        let midpoint = try #require(samples.count > 20 ? samples[20] : nil)

        #expect(midpoint.position.x < 260)
    }

    @Test func guidanceSelectsTheFirstAffordableProductInDisplayOrder() throws {
        let first = UUID()
        let second = UUID()
        let target = try #require(RewardGuidanceTargetResolver.resolve(
            products: [
                RewardGuidanceProduct(id: first, priceCoinUnits: 250, isArchived: false),
                RewardGuidanceProduct(id: second, priceCoinUnits: 100, isArchived: false),
            ],
            balanceCoinUnits: 275
        ))

        #expect(target.productID == first)
        #expect(target.status == .affordable)
    }

    @Test func guidanceSelectsTheSmallestShortfallWhenNothingIsAffordable() throws {
        let far = UUID()
        let nearest = UUID()
        let middle = UUID()
        let target = try #require(RewardGuidanceTargetResolver.resolve(
            products: [
                RewardGuidanceProduct(id: far, priceCoinUnits: 500, isArchived: false),
                RewardGuidanceProduct(id: nearest, priceCoinUnits: 300, isArchived: false),
                RewardGuidanceProduct(id: middle, priceCoinUnits: 400, isArchived: false),
            ],
            balanceCoinUnits: 275
        ))

        #expect(target.productID == nearest)
        #expect(target.status == .progress(missingCoinUnits: 25))
        #expect(target.status.displayText == "还差 2.5 金币")
    }

    @Test func guidanceExcludesArchivedAndInvalidProducts() throws {
        let archived = UUID()
        let invalid = UUID()
        let active = UUID()
        let target = try #require(RewardGuidanceTargetResolver.resolve(
            products: [
                RewardGuidanceProduct(id: archived, priceCoinUnits: 100, isArchived: true),
                RewardGuidanceProduct(id: invalid, priceCoinUnits: 0, isArchived: false),
                RewardGuidanceProduct(id: active, priceCoinUnits: 300, isArchived: false),
            ],
            balanceCoinUnits: 275
        ))

        #expect(target.productID == active)
        #expect(target.status == .progress(missingCoinUnits: 25))
    }

    @Test func guidanceExcludesRedeemedProducts() throws {
        let redeemed = UUID()
        let available = UUID()
        let target = try #require(RewardGuidanceTargetResolver.resolve(
            products: [
                RewardGuidanceProduct(
                    id: redeemed,
                    priceCoinUnits: 100,
                    isArchived: false,
                    isRedeemed: true
                ),
                RewardGuidanceProduct(
                    id: available,
                    priceCoinUnits: 200,
                    isArchived: false,
                    isRedeemed: false
                ),
            ],
            balanceCoinUnits: 500
        ))

        #expect(target.productID == available)
        #expect(target.status == .affordable)
        #expect(RewardGuidanceTargetResolver.resolve(
            products: [
                RewardGuidanceProduct(
                    id: redeemed,
                    priceCoinUnits: 100,
                    isArchived: false,
                    isRedeemed: true
                ),
            ],
            balanceCoinUnits: 500
        ) == nil)
    }

    @Test func guidanceIsAbsentWithoutAUsableBalanceOrValidProduct() {
        let product = RewardGuidanceProduct(
            id: UUID(),
            priceCoinUnits: 100,
            isArchived: false
        )

        #expect(RewardGuidanceTargetResolver.resolve(
            products: [product],
            balanceCoinUnits: nil
        ) == nil)
        #expect(RewardGuidanceTargetResolver.resolve(
            products: [product],
            balanceCoinUnits: -1
        ) == nil)
        #expect(RewardGuidanceTargetResolver.resolve(
            products: [],
            balanceCoinUnits: 275
        ) == nil)
    }

    @Test func guidanceRecalculatesFromThePostRedemptionBalance() throws {
        let first = UUID()
        let second = UUID()
        let products = [
            RewardGuidanceProduct(id: first, priceCoinUnits: 200, isArchived: false),
            RewardGuidanceProduct(id: second, priceCoinUnits: 150, isArchived: false),
        ]

        let before = try #require(RewardGuidanceTargetResolver.resolve(
            products: products,
            balanceCoinUnits: 275
        ))
        let after = try #require(RewardGuidanceTargetResolver.resolve(
            products: products,
            balanceCoinUnits: 75
        ))

        #expect(before == RewardGuidanceTarget(productID: first, status: .affordable))
        #expect(after == RewardGuidanceTarget(
            productID: second,
            status: .progress(missingCoinUnits: 75)
        ))
    }

    @Test func editorRouteCarriesTheExactProductIntoTheSheet() {
        let product = RewardProduct(
            name: "看电影",
            priceCoinUnits: 180,
            imageReference: "poster.image"
        )
        let route = RewardProductEditorRoute.edit(product)

        #expect(route.product === product)
        #expect(route.id == .edit(product.id))
    }
}
