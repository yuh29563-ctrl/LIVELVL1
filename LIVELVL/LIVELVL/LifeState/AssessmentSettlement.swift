import Foundation

enum AssessmentMode: String, Identifiable, Sendable {
    case initial
    case weekly

    var id: String { rawValue }
}

struct AssessmentEntry: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }
    let dimension: LifeDimension
    var rating: Double
    var weeklyTarget: Int
}

struct AssessmentResult: Equatable, Sendable {
    let entries: [AssessmentEntry]
    let officialScores: LifeStateValues
    let baselineActionScores: LifeStateValues
    let assessedAt: Date
}

enum AssessmentSettlement {
    static func makeResult(
        mode: AssessmentMode,
        entries: [AssessmentEntry],
        actionScores: LifeStateValues,
        assessedAt: Date
    ) -> AssessmentResult {
        let normalized = LifeDimension.allCases.map { dimension in
            let source = entries.first { $0.dimension == dimension }
                ?? AssessmentEntry(dimension: dimension, rating: 5.0, weeklyTarget: 3)
            return AssessmentEntry(
                dimension: dimension,
                rating: min(10.0, max(0.0, source.rating)),
                weeklyTarget: min(7, max(1, source.weeklyTarget))
            )
        }
        var official = LifeStateValues.neutral
        for entry in normalized {
            official[entry.dimension] = LifeStateEngine.settledScore(
                    selfRating: entry.rating,
                    actionScore: actionScores[entry.dimension]
                )
        }
        return AssessmentResult(
            entries: normalized,
            officialScores: official,
            baselineActionScores: actionScores,
            assessedAt: assessedAt
        )
    }
}
