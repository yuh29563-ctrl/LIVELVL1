import CoreGraphics
import Testing
@testable import LIVELVL

struct AssessmentChoiceLayoutTests {
    @Test func visibleGapsAreEqualAndTapTargetsDoNotOverlap() throws {
        let centers = try #require(AssessmentChoiceGeometry.centers(in: 338))
        #expect(centers == [22, 74, 123, 169, 215, 264, 316])
        for index in 0..<6 {
            let gap = centers[index + 1] - AssessmentChoiceGeometry.diameters[index + 1] / 2
                - centers[index] - AssessmentChoiceGeometry.diameters[index] / 2
            #expect(abs(gap - 19.5) < 0.001)
            #expect(centers[index + 1] - centers[index] >= 44)
        }
        #expect(centers[0] - 22 == 0)
        #expect(centers[6] + 22 == 338)
    }

    @Test func narrowRowsFallBackBeforeTapTargetsOverlap() throws {
        #expect(AssessmentChoiceGeometry.centers(in: 325) == nil)
        let centers = try #require(AssessmentChoiceGeometry.centers(in: 326))
        #expect(centers[3] == 163)
        #expect(centers[3] - centers[2] == 44)
        #expect(centers[4] - centers[3] == 44)
    }
}
