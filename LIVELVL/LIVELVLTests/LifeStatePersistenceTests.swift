import Foundation
import SwiftData
import Testing
@testable import LIVELVL

// Frozen main 1602449 layout, before questionnaire fields were added.
private enum PreQuestionnaireStore {
    @Model final class StateSnapshot {
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
        init(date: Date) {
            assessedAt = date; overallScore = 7.1
            health = 7.1; learning = 7.1; career = 7.1
            finance = 7.1; relationships = 7.1; interests = 7.1
            healthAction = 8; learningAction = 8; careerAction = 8
            financeAction = 8; relationshipsAction = 8; interestsAction = 8
        }
    }
}

@MainActor
struct LifeStatePersistenceTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12))!
    }
    private var answers: [String: AssessmentAnswer] {
        Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map { ($0.id, .neutral) })
    }
    private func container(_ url: URL, legacy: Bool = false, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = Schema([
            legacy ? PreQuestionnaireStore.StateSnapshot.self : StateSnapshot.self,
            DimensionProfile.self, Item.self, Completion.self, LIVELVL.Progress.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self, CoinTransaction.self
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none))
    }

    @Test func legacyDiskStoreMigratesThenQuestionnairePersistsAndReopensWithoutCompounding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.store")
        try autoreleasepool {
            let old = try container(url, legacy: true)
            let context = old.mainContext
            context.autosaveEnabled = false
            context.insert(PreQuestionnaireStore.StateSnapshot(date: date(5)))
            for dimension in LifeDimension.allCases {
                context.insert(DimensionProfile(dimension: dimension, selfRating: 6.5,
                    weeklyTarget: 3, lastAssessedAt: date(5)))
            }
            context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health,
                taskTitle: "封顶后的锻炼", date: date(20), nominalXP: 80))
            context.insert(LIVELVL.Progress(totalXP: 6200))
            context.insert(CollectionProgress(highestLevel: 4, activeOrdinaryIndex: 1,
                activeStage: .stageThree, lastProcessedMaturityLevel: 1))
            context.insert(OwnedCollectible(awardKey: "ordinary.level.1", collectibleID: "ordinary.sprout",
                kind: .ordinaryMature, reason: "旧奖励", acquiredAt: date(5), isUnseen: true))
            context.insert(PendingCardReward(awardKey: "ordinary.level.4", collectibleID: "ordinary.hare",
                kind: .ordinaryMature, reason: "待领取", maturityLevel: 4, triggeredAt: date(5), eligibleAt: date(5)))
            context.insert(CoinTransaction(operationKey: "legacy", kind: .legacyImport,
                amountCoinUnits: 6200, requestedCoinUnits: 6200, sourceID: nil, createdAt: date(5), note: "旧金币"))
            try context.save()
        }
        try autoreleasepool {
            let upgraded = try container(url)
            let context = upgraded.mainContext
            let old = try #require(context.fetch(FetchDescriptor<StateSnapshot>()).first)
            #expect(old.assessmentVersion == nil)
            #expect(old.scores.health == 7.1)
            let summary = LifeStateSummaryBuilder.build(
                profiles: try context.fetch(FetchDescriptor<DimensionProfile>()), snapshot: old,
                activities: [], now: date(20), calendar: calendar)
            #expect(summary.official.health == 6.5)
            let new = try StateAssessmentStore.submit(answers: answers, weeklyTargets: [:],
                in: context, now: date(20), calendar: calendar)
            #expect(new.assessmentVersion == 1)
            #expect(new.selfRatings?.health == 5)
            #expect(abs(new.scores.health - (5 + 1.0 / 7)) < 0.00001)
            #expect(new.recordedAnswers == answers)
        }
        try autoreleasepool {
            let reopened = try container(url)
            let context = reopened.mainContext
            let snapshots = try context.fetch(FetchDescriptor<StateSnapshot>(sortBy: [SortDescriptor(\StateSnapshot.assessedAt, order: .reverse)]))
            #expect(snapshots.count == 2)
            let latest = try #require(snapshots.first)
            #expect(latest.selfRatings?.health == 5)
            #expect(latest.recordedAnswers == answers)
            let activities = try context.fetch(FetchDescriptor<Completion>()).compactMap { $0.stateActivity(fallbackItem: nil) }
            let summary = LifeStateSummaryBuilder.build(profiles: try context.fetch(FetchDescriptor<DimensionProfile>()),
                snapshot: latest, activities: activities, now: date(20), calendar: calendar)
            #expect(abs(summary.projected.health - (5 + 1.0 / 7)) < 0.00001)
            #expect(snapshots.last?.scores.health == 7.1)
            #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 6200)
            #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).first?.amountCoinUnits == 6200)
            #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).first?.isUnseen == true)
            #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).first?.awardKey == "ordinary.level.4")
            #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).first?.activeStage == .stageThree)
            #expect(throws: AssessmentValidationError.self) {
                try StateAssessmentStore.submit(answers: answers, weeklyTargets: [:], in: context,
                    now: date(20), calendar: calendar)
            }
            #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).count == 2)
        }
    }

    @Test func skipReminderPersistsWithoutChangingEligibilityOrTheAssessment() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("skip.store")
        try autoreleasepool {
            let store = try container(url)
            store.mainContext.insert(StateSnapshot(scores: .neutral, actionScores: .neutral, assessedAt: date(5)))
            try store.mainContext.save()
            try StateAssessmentStore.skipReminder(in: store.mainContext, now: date(20), calendar: calendar)
        }
        let reopened = try container(url)
        let snapshot = try #require(reopened.mainContext.fetch(FetchDescriptor<StateSnapshot>()).first)
        #expect(snapshot.assessedAt == date(5))
        #expect(snapshot.reminderSkippedAt == date(20))
        #expect(LifeStateEngine.isAssessmentDue(lastAssessedAt: snapshot.assessedAt, now: date(20), calendar: calendar))
        #expect(!LifeStateEngine.shouldRemind(lastAssessedAt: snapshot.assessedAt,
            skippedAt: snapshot.reminderSkippedAt, now: date(21), calendar: calendar))
    }

    @Test func failedSubmissionLeavesProfilesAndSnapshotUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let store = try container(url)
            store.mainContext.insert(StateSnapshot(scores: .neutral, actionScores: .neutral, assessedAt: date(5)))
            store.mainContext.insert(DimensionProfile(dimension: .health, selfRating: 8,
                weeklyTarget: 3, lastAssessedAt: date(5)))
            try store.mainContext.save()
        }
        let readonly = try container(url, allowsSave: false)
        let context = readonly.mainContext
        let session = StateAssessmentSession()
        session.start()
        session.answers = answers
        session.weeklyTargets = [.health: 6]
        for _ in 0..<5 { try session.advance(in: context, now: date(20), calendar: calendar) }
        #expect(throws: (any Error).self) {
            try session.advance(in: context, now: date(20), calendar: calendar)
        }
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).first?.selfRating == 8)
        #expect(!context.hasChanges)
        #expect(session.phase == .questionnaire)
        #expect(session.pageIndex == 5)
        #expect(session.answers == answers)
        #expect(session.weeklyTargets == [.health: 6])
        let writable = try container(url)
        #expect(try session.advance(in: writable.mainContext, now: date(20), calendar: calendar))
        #expect(session.phase == .completed)
        #expect(try session.advance(in: writable.mainContext, now: date(20), calendar: calendar) == false)
        let snapshots = try writable.mainContext.fetch(FetchDescriptor<StateSnapshot>(sortBy: [SortDescriptor(\StateSnapshot.assessedAt, order: .reverse)]))
        #expect(snapshots.count == 2)
        #expect(snapshots.first?.recordedAnswers == answers)
        #expect(try writable.mainContext.fetch(FetchDescriptor<DimensionProfile>()).first { $0.dimension == .health }?.weeklyTarget == 6)
    }
}
