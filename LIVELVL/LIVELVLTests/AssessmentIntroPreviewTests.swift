import Testing
@testable import LIVELVL

@MainActor
struct AssessmentIntroPreviewTests {
    @Test func rapidStartDoesNotSkipHealthOrResetAnswers() {
        var preview = AssessmentIntroPreviewState()
        #expect(preview.phase == .introduction)
        #expect(preview.answers.isEmpty)
        preview.start()
        preview.answers["health.01"] = .neutral
        preview.start()
        #expect(preview.phase == .questionnaire)
        #expect(preview.dimension == .health)
        #expect(preview.answers["health.01"] == .neutral)
    }

    @Test func incompleteOrEntirelyExcludedSectionCannotAdvance() {
        var preview = AssessmentIntroPreviewState()
        preview.start()
        preview.advance()
        #expect(preview.dimension == .health)
        for question in AssessmentQuestionnaire.questions(for: .health) {
            preview.answers[question.id] = .notApplicable
        }
        preview.advance()
        #expect(preview.dimension == .health)
        preview.answers["health.01"] = .neutral
        preview.advance()
        #expect(preview.dimension == .learning)
    }

    @Test func backAndIntroductionPreserveTheDraft() {
        var preview = AssessmentIntroPreviewState()
        preview.start()
        for question in AssessmentQuestionnaire.questions(for: .health) {
            preview.answers[question.id] = .neutral
        }
        preview.advance()
        preview.answers["learning.01"] = .stronglyAgree
        preview.back()
        #expect(preview.dimension == .health)
        preview.showIntroduction()
        preview.start()
        #expect(preview.answers.count == 11)
        preview.advance()
        #expect(preview.dimension == .learning)
        #expect(preview.answers["learning.01"] == .stronglyAgree)
    }

    @Test func sixSectionsFinishLocallyAndRepeatedFinishIsHarmless() {
        var preview = AssessmentIntroPreviewState()
        preview.start()
        let expected: [LifeDimension] = [.health, .learning, .career, .finance, .relationships, .interests]
        for dimension in expected {
            #expect(preview.dimension == dimension)
            for question in AssessmentQuestionnaire.questions(for: dimension) {
                preview.answers[question.id] = .neutral
            }
            preview.advance()
        }
        #expect(preview.phase == .finished)
        preview.advance()
        #expect(preview.phase == .finished)
        #expect(preview.answers.count == 60)
        preview.showIntroduction()
        preview.start()
        #expect(preview.dimension == .interests)
        #expect(AssessmentIntroPreviewState().answers.isEmpty)
    }
}
