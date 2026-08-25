import Testing
@testable import LIVELVL

struct UIPolishLayoutTests {
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
