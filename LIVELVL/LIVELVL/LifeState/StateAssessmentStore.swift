import Foundation
import SwiftData

@MainActor
enum StateAssessmentStore {
    @discardableResult
    static func submit(
        answers: [String: AssessmentAnswer],
        weeklyTargets: [LifeDimension: Int],
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> StateSnapshot {
        let entries = try AssessmentQuestionnaire.entries(answers: answers, weeklyTargets: weeklyTargets)
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        let latest = try latestSnapshot(in: writer)
        if let latest, !LifeStateEngine.isAssessmentDue(
            lastAssessedAt: latest.assessedAt, now: now, calendar: calendar
        ) {
            throw AssessmentValidationError.notDue
        }
        let profiles = try writer.fetch(FetchDescriptor<DimensionProfile>())
        let items = try writer.fetch(FetchDescriptor<Item>())
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let activities = try writer.fetch(FetchDescriptor<Completion>())
            .compactMap { $0.stateActivity(fallbackItem: itemByID[$0.itemID]) }
        var actions = LifeStateValues(repeating: 0)
        var bases = LifeStateValues.neutral
        for entry in entries {
            bases[entry.dimension] = entry.rating
            actions[entry.dimension] = LifeStateEngine.actionScore(
                activities: activities.filter { $0.dimension == entry.dimension }
                    .map { StateActivity(date: $0.date, xp: $0.xp) },
                weeklyTarget: entry.weeklyTarget, now: now, calendar: calendar)
        }
        let result = AssessmentSettlement.makeResult(
            mode: latest == nil ? .initial : .weekly, entries: entries, actionScores: actions, assessedAt: now)
        let snapshot = StateSnapshot(scores: result.officialScores, actionScores: actions, assessedAt: now)
        snapshot.assessmentVersion = AssessmentQuestionnaire.version
        snapshot.selfRatingsData = try JSONEncoder().encode(bases)
        snapshot.assessmentAnswersData = try JSONEncoder().encode(answers)
        do {
            for entry in entries {
                if let profile = profiles.first(where: { $0.dimension == entry.dimension }) {
                    profile.selfRating = entry.rating
                    profile.weeklyTarget = entry.weeklyTarget
                    profile.lastAssessedAt = now
                } else {
                    writer.insert(DimensionProfile(dimension: entry.dimension, selfRating: entry.rating,
                        weeklyTarget: entry.weeklyTarget, lastAssessedAt: now))
                }
            }
            writer.insert(snapshot)
            try writer.save()
        } catch {
            writer.rollback()
            throw error
        }
        _ = try context.fetch(FetchDescriptor<DimensionProfile>())
        return try context.fetch(FetchDescriptor<StateSnapshot>()).first {
            $0.persistentModelID == snapshot.persistentModelID
        } ?? snapshot
    }

    static func skipReminder(
        in context: ModelContext, now: Date = .now, calendar: Calendar = .current
    ) throws {
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        guard let snapshot = try latestSnapshot(in: writer),
              LifeStateEngine.isAssessmentDue(lastAssessedAt: snapshot.assessedAt, now: now, calendar: calendar)
        else { return }
        do {
            snapshot.reminderSkippedAt = now
            try writer.save()
        } catch {
            writer.rollback()
            throw error
        }
        _ = try context.fetch(FetchDescriptor<StateSnapshot>())
    }

    private static func latestSnapshot(in context: ModelContext) throws -> StateSnapshot? {
        var request = FetchDescriptor<StateSnapshot>(sortBy: [SortDescriptor(\StateSnapshot.assessedAt, order: .reverse)])
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
