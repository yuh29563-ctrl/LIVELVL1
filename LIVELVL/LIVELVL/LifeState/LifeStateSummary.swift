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
    var actionDays: Int = 0
    var targetDays: Int = 0
}

struct LifeStateSummary: Equatable, Sendable {
    let official: LifeStateValues
    let projected: LifeStateValues
    let overallScore: Double
    let dimensions: [DimensionStateSummary]
    let highlightedChange: DimensionStateSummary?
    let daysUntilAssessment: Int
    let isAssessmentDue: Bool
    var assessedAt: Date? = nil
    var shouldRemindForAssessment: Bool = false
}

enum LifeStateSummaryBuilder {
    static func build(
        profiles: [DimensionProfile],
        snapshot: StateSnapshot,
        activities: [DimensionActivityRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> LifeStateSummary {
        var currentActions = LifeStateValues(repeating: 0)
        var bases = snapshot.selfRatings ?? snapshot.scores
        let profilesByDimension = Dictionary(uniqueKeysWithValues: profiles.map { ($0.dimension, $0) })
        // Legacy snapshots contain the old 60/40 blend. Keep them untouched and
        // use the original profile self-ratings until the first new questionnaire.
        if snapshot.selfRatings == nil {
            for dimension in LifeDimension.allCases {
                if let profile = profilesByDimension[dimension] { bases[dimension] = profile.selfRating }
            }
        }
        var projected = bases

        for dimension in LifeDimension.allCases {
            let target = profilesByDimension[dimension]?.weeklyTarget ?? 3
            let inputs = activities
                .filter { $0.dimension == dimension }
                .map { StateActivity(date: $0.date, xp: $0.xp) }
            currentActions[dimension] = LifeStateEngine.actionScore(
                activities: inputs, weeklyTarget: target, now: now, calendar: calendar
            )
            projected[dimension] = LifeStateEngine.settledScore(
                selfRating: bases[dimension],
                actionScore: currentActions[dimension]
            )
        }

        let dimensionSummaries = LifeDimension.allCases.map { dimension in
            DimensionStateSummary(
                dimension: dimension,
                officialScore: bases[dimension],
                projectedScore: projected[dimension],
                delta: projected[dimension] - bases[dimension],
                sourceTitle: activities
                    .filter { activity in
                        LifeStateEngine.actionDays(activities: [StateActivity(date: activity.date, xp: activity.xp)],
                            now: now, calendar: calendar) > 0
                    }
                    .filter { $0.dimension == dimension }
                    .max(by: { $0.date < $1.date })?.taskTitle,
                actionDays: LifeStateEngine.actionDays(
                    activities: activities.filter { $0.dimension == dimension }
                        .map { StateActivity(date: $0.date, xp: $0.xp) }, now: now, calendar: calendar),
                targetDays: LifeStateEngine.targetDays(weeklyTarget: profilesByDimension[dimension]?.weeklyTarget ?? 3)
            )
        }
        let highlighted = dimensionSummaries
            .filter { $0.delta > 0 }
            .max { abs($0.delta) < abs($1.delta) }
        let daysUntilAssessment = LifeStateEngine.daysUntilAssessment(
            lastAssessedAt: snapshot.assessedAt,
            now: now,
            calendar: calendar
        )

        return LifeStateSummary(
            official: bases,
            projected: projected,
            overallScore: projected.average,
            dimensions: dimensionSummaries,
            highlightedChange: highlighted,
            daysUntilAssessment: daysUntilAssessment,
            isAssessmentDue: daysUntilAssessment == 0,
            assessedAt: snapshot.assessedAt,
            shouldRemindForAssessment: LifeStateEngine.shouldRemind(
                lastAssessedAt: snapshot.assessedAt, skippedAt: snapshot.reminderSkippedAt,
                now: now, calendar: calendar)
        )
    }
}
