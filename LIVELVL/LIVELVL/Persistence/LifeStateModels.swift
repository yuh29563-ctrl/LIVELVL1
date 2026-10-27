import Foundation
import SwiftData

@Model
final class DimensionProfile {
    @Attribute(.unique) var dimensionRaw: String
    var selfRating: Double
    var weeklyTarget: Int
    var lastAssessedAt: Date

    init(dimension: LifeDimension, selfRating: Double, weeklyTarget: Int, lastAssessedAt: Date) {
        dimensionRaw = dimension.rawValue
        self.selfRating = selfRating
        self.weeklyTarget = weeklyTarget
        self.lastAssessedAt = lastAssessedAt
    }

    var dimension: LifeDimension {
        LifeDimension(rawValue: dimensionRaw) ?? .learning
    }
}

@Model
final class StateSnapshot {
    var assessedAt: Date
    var overallScore: Double
    var health: Double
    var learning: Double
    var career: Double
    var finance: Double
    var relationships: Double
    var interests: Double
    var healthAction: Double
    var learningAction: Double
    var careerAction: Double
    var financeAction: Double
    var relationshipsAction: Double
    var interestsAction: Double
    var assessmentVersion: Int? = nil
    var selfRatingsData: Data? = nil
    var assessmentAnswersData: Data? = nil
    var reminderSkippedAt: Date? = nil

    init(scores: LifeStateValues, actionScores: LifeStateValues, assessedAt: Date) {
        self.assessedAt = assessedAt
        overallScore = scores.average
        health = scores.health
        learning = scores.learning
        career = scores.career
        finance = scores.finance
        relationships = scores.relationships
        interests = scores.interests
        healthAction = actionScores.health
        learningAction = actionScores.learning
        careerAction = actionScores.career
        financeAction = actionScores.finance
        relationshipsAction = actionScores.relationships
        interestsAction = actionScores.interests
    }

    var scores: LifeStateValues {
        LifeStateValues(health: health, learning: learning, career: career,
                        finance: finance, relationships: relationships, interests: interests)
    }

    var actionScores: LifeStateValues {
        LifeStateValues(health: healthAction, learning: learningAction, career: careerAction,
                        finance: financeAction, relationships: relationshipsAction,
                        interests: interestsAction)
    }

    var selfRatings: LifeStateValues? {
        guard let selfRatingsData else { return nil }
        return try? JSONDecoder().decode(LifeStateValues.self, from: selfRatingsData)
    }

    var recordedAnswers: [String: AssessmentAnswer]? {
        guard let assessmentAnswersData else { return nil }
        return try? JSONDecoder().decode([String: AssessmentAnswer].self, from: assessmentAnswersData)
    }
}
