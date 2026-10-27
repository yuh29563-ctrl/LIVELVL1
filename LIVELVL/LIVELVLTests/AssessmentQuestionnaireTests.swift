import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct AssessmentQuestionnaireTests {
    @Test func sixtyStableQuestionsCoverEachDimensionOncePerPosition() {
        let questions = AssessmentQuestionnaire.questions
        #expect(questions.count == 60)
        #expect(Set(questions.map(\.id)).count == 60)
        for dimension in LifeDimension.allCases {
            let group = AssessmentQuestionnaire.questions(for: dimension)
            #expect(group.count == 10)
            #expect(group.first?.id == "\(dimension.rawValue).01")
            #expect(group.last?.id == "\(dimension.rawValue).10")
        }
    }

    @Test func sevenChoicesMapToZeroFiftyAndHundredAndExclusionsDoNotBecomeNeutral() throws {
        let questions = AssessmentQuestionnaire.questions(for: .health)
        var answers = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, AssessmentAnswer.notApplicable) })
        answers[questions[0].id] = .stronglyDisagree
        answers[questions[1].id] = .stronglyAgree
        #expect(try AssessmentQuestionnaire.rating(for: .health, answers: answers) == 5)
        answers[questions[0].id] = .neutral
        answers[questions[1].id] = .neutral
        #expect(try AssessmentQuestionnaire.rating(for: .health, answers: answers) == 5)
        answers[questions[0].id] = .stronglyAgree
        answers[questions[1].id] = .stronglyAgree
        #expect(try AssessmentQuestionnaire.rating(for: .health, answers: answers) == 10)
    }

    @Test func missingAnswersAndAnEntirelyExcludedDimensionCannotBeSubmitted() {
        #expect(throws: AssessmentValidationError.self) {
            try AssessmentQuestionnaire.rating(for: .learning, answers: [:])
        }
        let answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions(for: .learning)
            .map { ($0.id, AssessmentAnswer.notApplicable) })
        #expect(throws: AssessmentValidationError.self) {
            try AssessmentQuestionnaire.rating(for: .learning, answers: answers)
        }
    }

    @Test func fullAnswerSetProducesIndependentDimensionScoresAndRoundTrips() throws {
        let answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map {
            ($0.id, $0.dimension == .health ? AssessmentAnswer.stronglyAgree : .neutral)
        })
        let entries = try AssessmentQuestionnaire.entries(answers: answers, weeklyTargets: [.health: 4])
        #expect(entries.first { $0.dimension == .health }?.rating == 10)
        #expect(entries.first { $0.dimension == .learning }?.rating == 5)
        #expect(entries.first { $0.dimension == .health }?.weeklyTarget == 4)
        let data = try JSONEncoder().encode(answers)
        #expect(try JSONDecoder().decode([String: AssessmentAnswer].self, from: data) == answers)
    }
}
