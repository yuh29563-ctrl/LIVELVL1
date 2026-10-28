import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StateAssessmentSession {
    enum Phase { case introduction, questionnaire, completed }
    private(set) var phase = Phase.introduction
    private(set) var pageIndex = 0
    var answers: [String: AssessmentAnswer] = [:]
    var weeklyTargets: [LifeDimension: Int] = [:]
    var dimension: LifeDimension { LifeDimension.allCases[pageIndex] }
    var isPageComplete: Bool {
        (try? AssessmentQuestionnaire.rating(for: dimension, answers: answers)) != nil
    }

    func start() {
        guard phase == .introduction else { return }
        phase = .questionnaire
    }

    func back() {
        guard phase == .questionnaire, pageIndex > 0 else { return }
        pageIndex -= 1
    }

    @discardableResult
    func advance(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> Bool {
        guard phase == .questionnaire, isPageComplete else { return false }
        guard pageIndex == LifeDimension.allCases.count - 1 else {
            pageIndex += 1
            return false
        }
        try StateAssessmentStore.submit(answers: answers, weeklyTargets: weeklyTargets,
            in: context, now: now, calendar: calendar)
        phase = .completed
        return true
    }
}
