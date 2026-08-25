import Testing
import UIKit
@testable import LIVELVL

struct TodayCompanionLevelCardTests {
    @Test func mergedCardDescribesTheActiveCompanionInsteadOfTheFixedSprout() {
        let presentation = TodayCompanionLevelCardPresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )

        #expect(presentation.companionName == "月兔")
        #expect(presentation.stageTitle == "成长中")
        #expect(presentation.accessibilityLabel == "正在陪伴，月兔，成长中，等级 2")
        #expect(presentation.accessibilityValue == "当前 80，共需 2000，还差 1920 XP")
    }

    @Test func journalNameTypographyCompactsLongDynamicNames() {
        let shortName = CompanionJournalTypography.metrics(for: "小芽")
        let longName = CompanionJournalTypography.metrics(for: "会陪你散步的小狗")

        #expect(longName.pointSize < shortName.pointSize)
        #expect(longName.minimumScaleFactor < shortName.minimumScaleFactor)
    }

    @Test func companionMediaControlsUseNativePhotoSymbols() {
        #expect(CompanionMediaControlStyle.photoSymbol == "photo")
        #expect(CompanionMediaControlStyle.animatedPhotoSymbol == "livephoto")
    }

    @Test func journalTypographyUsesTheApprovedLargerScale() {
        #expect(CompanionJournalTypography.metrics(for: "月兔").pointSize == 56)
        #expect(CompanionJournalTypography.statusPointSize == 20)
        #expect(CompanionJournalTypography.stagePointSize == 24)
        #expect(CompanionJournalTypography.summaryPointSize == 20)
        #expect(CompanionJournalTypography.remainingPointSize == 18)
    }

    @MainActor
    @Test func bundledChineseHandwritingFontIsRegistered() {
        #expect(UIFont(name: "LongCang-Regular", size: 38) != nil)
    }

    @Test func journalCompositionMatchesTheApprovedReferenceAtPhoneWidth() {
        let composition = CompanionJournalComposition(
            in: CGSize(width: 338, height: 376)
        )

        #expect(composition.artworkFrame == CGRect(x: 18, y: 46, width: 116, height: 116))
        #expect(composition.statusOrigin == CGPoint(x: 142, y: 46))
        #expect(composition.photoControlFrame == CGRect(x: 14, y: 14, width: 32, height: 32))
        #expect(composition.animatedControlFrame == CGRect(x: 292, y: 14, width: 32, height: 32))
        #expect(composition.titleFrame == CGRect(x: 142, y: 72, width: 176, height: 78))
        #expect(composition.nameOrigin == CGPoint(x: 143, y: 82))
        #expect(composition.stageOrigin == CGPoint(x: 252, y: 116))
        #expect(composition.summaryOrigin == CGPoint(x: 26, y: 184))
        #expect(composition.levelOrigin == CGPoint(x: 26, y: 252))
        #expect(composition.progressFrame == CGRect(x: 26, y: 291, width: 286, height: 7))
        #expect(composition.remainingOrigin == CGPoint(x: 106, y: 318))
        #expect(composition.smileFrame == CGRect(x: 281, y: 52, width: 32, height: 28))
        #expect(composition.flowerFrame == CGRect(x: 278, y: 178, width: 38, height: 45))
        #expect(composition.sparklesFrame == CGRect(x: 17, y: 337, width: 43, height: 36))
    }

    @Test func journalCompositionScalesWithoutChangingItsRelativeGeometry() {
        let composition = CompanionJournalComposition(
            in: CGSize(width: 676, height: 752)
        )

        #expect(composition.artworkFrame == CGRect(x: 36, y: 92, width: 232, height: 232))
        #expect(composition.progressFrame == CGRect(x: 52, y: 582, width: 572, height: 14))
        #expect(composition.flowerFrame == CGRect(x: 556, y: 356, width: 76, height: 90))
    }
}
