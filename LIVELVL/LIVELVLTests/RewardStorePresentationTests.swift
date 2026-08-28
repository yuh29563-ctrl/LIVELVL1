import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct RewardStorePresentationTests {
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

    @Test func horizontalLedgerDotsDriftNormallyAndFreezeForReduceMotion() {
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
        #expect(movingA.filter(\.isFilled).count == 7)
        #expect(movingA.filter { $0.isFilled }.allSatisfy { $0.row == 5 })
        #expect(movingA.allSatisfy {
            (0...1).contains($0.position.x)
                && (0...1).contains($0.position.y)
                && $0.opacity > 0
                && $0.diameter > 0
        })
    }

    @Test func approvedRewardsLayoutUsesTheReferenceVerticalRhythm() {
        #expect(RewardStoreLayout.pageTopPadding == 8)
        #expect(RewardStoreLayout.balanceTopSpacing == 24)
        #expect(RewardStoreLayout.balanceInternalSpacing == 0)
        #expect(RewardStoreLayout.productTopSpacing == 69)
        #expect(RewardStoreLayout.particleTrailTopOffset == 125)
    }

    @Test func rewardPageTrailCurvesFromTheLedgerTowardTheProductRows() throws {
        let start = RewardPageTrailGeometry.samples(
            count: 42,
            phase: 0,
            reduceMotion: false
        )
        let moved = RewardPageTrailGeometry.samples(
            count: 42,
            phase: 0.4,
            reduceMotion: false
        )
        let reduced = RewardPageTrailGeometry.samples(
            count: 42,
            phase: 0.4,
            reduceMotion: true
        )
        let first = try #require(start.first)
        let last = try #require(start.last)

        #expect(start.count == 42)
        #expect(abs(first.position.x - 0.48) < 0.02)
        #expect(first.position.y < 0.02)
        #expect(abs(last.position.x - 0.82) < 0.02)
        #expect(last.position.y > 0.98)
        #expect(start != moved)
        #expect(reduced.isEmpty)
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
