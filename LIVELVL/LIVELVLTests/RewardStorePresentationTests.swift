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
            count: 48,
            balanceCoinUnits: 275,
            phase: 0,
            reduceMotion: false
        )
        let movingB = RewardLedgerGeometry.samples(
            count: 48,
            balanceCoinUnits: 275,
            phase: 0.4,
            reduceMotion: false
        )
        let frozenA = RewardLedgerGeometry.samples(
            count: 48,
            balanceCoinUnits: 275,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = RewardLedgerGeometry.samples(
            count: 48,
            balanceCoinUnits: 275,
            phase: 0.8,
            reduceMotion: true
        )

        #expect(movingA.count == 48)
        #expect(movingA != movingB)
        #expect(frozenA == frozenB)
        #expect(movingA.allSatisfy {
            (0...1).contains($0.position.x)
                && (0...1).contains($0.position.y)
                && $0.opacity > 0
                && $0.diameter > 0
        })
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
