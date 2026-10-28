import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct StateAssessmentSessionTests {
    @Test func introductionAndIncompleteSectionsCannotWriteAState() throws {
        let container = try makeContainer()
        let session = StateAssessmentSession()
        #expect(session.phase == .introduction)
        #expect(try session.advance(in: container.mainContext) == false)
        session.start()
        session.start()
        #expect(session.phase == .questionnaire)
        #expect(try session.advance(in: container.mainContext) == false)
        #expect(session.pageIndex == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<StateSnapshot>()) == 0)
    }

    @Test func lastSectionSavesSixDimensionsExactlyOnceInsteadOfReturningToIntroduction() throws {
        let container = try makeContainer()
        let session = StateAssessmentSession()
        session.start()
        for (index, dimension) in LifeDimension.allCases.enumerated() {
            for question in AssessmentQuestionnaire.questions(for: dimension) {
                session.answers[question.id] = dimension == .health ? .stronglyAgree : .neutral
            }
            let didSave = try session.advance(in: container.mainContext)
            #expect(didSave == (index == 5))
            #expect(try container.mainContext.fetchCount(FetchDescriptor<StateSnapshot>()) == (index == 5 ? 1 : 0))
        }
        #expect(session.phase == .completed)
        let snapshot = try #require(container.mainContext.fetch(FetchDescriptor<StateSnapshot>()).first)
        #expect(snapshot.selfRatings?.health == 10)
        #expect(snapshot.selfRatings?.learning == 5)
        #expect(snapshot.recordedAnswers?.count == 60)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DimensionProfile>()) == 6)
        #expect(try session.advance(in: container.mainContext) == false)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<StateSnapshot>()) == 1)
    }

    @Test func rejectedSaveKeepsLastSectionAndAllAnswersForRetry() throws {
        let container = try makeContainer()
        container.mainContext.insert(StateSnapshot(scores: .neutral, actionScores: .neutral, assessedAt: .now))
        try container.mainContext.save()
        let session = StateAssessmentSession()
        session.start()
        session.answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map { ($0.id, AssessmentAnswer.neutral) })
        for _ in 0..<5 { #expect(try session.advance(in: container.mainContext) == false) }
        #expect(throws: AssessmentValidationError.self) { try session.advance(in: container.mainContext) }
        #expect(session.phase == .questionnaire)
        #expect(session.pageIndex == 5)
        #expect(session.answers.count == 60)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<StateSnapshot>()) == 1)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema([Item.self, Completion.self, DimensionProfile.self, StateSnapshot.self]),
            configurations: .init(isStoredInMemoryOnly: true))
    }
}
