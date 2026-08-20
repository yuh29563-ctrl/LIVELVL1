import Foundation

struct DimensionActivityRecord: Equatable, Sendable {
    let dimension: LifeDimension
    let taskTitle: String
    let date: Date
    let xp: Int
}

struct DimensionStateSummary: Identifiable, Equatable, Sendable {
    var id: LifeDimension { dimension }
    let dimension: LifeDimension
    let officialScore: Double
    let projectedScore: Double
    let delta: Double
    let sourceTitle: String?
}

struct LifeStateSummary: Equatable, Sendable {
    let official: LifeStateValues
    let projected: LifeStateValues
    let overallScore: Double
    let dimensions: [DimensionStateSummary]
    let highlightedChange: DimensionStateSummary?
    let daysUntilAssessment: Int
    let isAssessmentDue: Bool
}

enum LifeStateSummaryBuilder {
    static func build(
        profiles: [DimensionProfile],
        snapshot: StateSnapshot,
        activities: [DimensionActivityRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> LifeStateSummary {
        var currentActions = LifeStateValues.neutral
        var projected = snapshot.scores
        let profilesByDimension = Dictionary(uniqueKeysWithValues: profiles.map { ($0.dimension, $0) })

        for dimension in LifeDimension.allCases {
            let target = profilesByDimension[dimension]?.weeklyTarget ?? 3
            let inputs = activities
                .filter { $0.dimension == dimension }
                .map { StateActivity(date: $0.date, xp: $0.xp) }
            currentActions[dimension] = LifeStateEngine.actionScore(
                activities: inputs, weeklyTarget: target, now: now, calendar: calendar
            )
            projected[dimension] = LifeStateEngine.projectedScore(
                officialScore: snapshot.scores[dimension],
                baselineActionScore: snapshot.actionScores[dimension],
                currentActionScore: currentActions[dimension]
            )
        }

        let dimensionSummaries = LifeDimension.allCases.map { dimension in
            DimensionStateSummary(
                dimension: dimension,
                officialScore: snapshot.scores[dimension],
                projectedScore: projected[dimension],
                delta: LifeStateEngine.rounded(projected[dimension] - snapshot.scores[dimension]),
                sourceTitle: activities
                    .filter { $0.dimension == dimension }
                    .max(by: { $0.date < $1.date })?.taskTitle
            )
        }
        let highlighted = dimensionSummaries
            .filter { abs($0.delta) >= 0.1 }
            .max { abs($0.delta) < abs($1.delta) }
        let daysUntilAssessment = LifeStateEngine.daysUntilAssessment(
            lastAssessedAt: snapshot.assessedAt,
            now: now,
            calendar: calendar
        )

        return LifeStateSummary(
            official: snapshot.scores,
            projected: projected,
            overallScore: snapshot.overallScore,
            dimensions: dimensionSummaries,
            highlightedChange: highlighted,
            daysUntilAssessment: daysUntilAssessment,
            isAssessmentDue: daysUntilAssessment == 0
        )
    }
}
