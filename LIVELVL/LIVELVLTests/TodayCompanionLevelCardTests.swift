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

    @MainActor
    @Test func bundledChineseHandwritingFontIsRegistered() {
        #expect(UIFont(name: "MaShanZheng-Regular", size: 38) != nil)
    }
}
