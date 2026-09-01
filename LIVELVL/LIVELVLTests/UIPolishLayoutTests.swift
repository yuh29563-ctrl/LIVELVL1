import Testing
@testable import LIVELVL

struct UIPolishLayoutTests {
    @Test func livingOSTabsKeepStableCopyAndCollectionIdentity() {
        #expect(AppTab.today.title == "今天")
        #expect(AppTab.collection.title == "收集")
        #expect(AppTab.rewards.title == "奖励")
        #expect(AppTab.profile.title == "我的")
        #expect(AppTab.collection.systemImageName == CollectionTabIdentity.systemImageName)
        #expect(LivingOSMetrics.pageTitleSize == 56)
    }

    @Test func rootTabPagesUseCompactVerticalInsets() {
        #expect(RootTabPageLayout.navigationTitleMode == .inline)
        #expect(RootTabPageLayout.contentTopPadding == 0)
        #expect(RootTabPageLayout.contentBottomPadding == 16)
    }

    @Test func assessmentNavigationUsesSymmetricButtonSlots() {
        #expect(AssessmentNavigationLayout.buttonSlotCount == 2)
        #expect(AssessmentNavigationLayout.buttonHorizontalPadding == 16)
        #expect(AssessmentNavigationLayout.buttonSpacing == 12)
        #expect(AssessmentNavigationLayout.buttonWidthsAreEqual)
    }
}
