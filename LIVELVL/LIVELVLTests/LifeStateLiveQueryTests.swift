import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct LifeStateLiveQueryTests {
    @Test func submissionAndSkipRefreshVisibleStateWithoutRestart() async throws {
        let container = try ModelContainer(for: Schema([
            Item.self, Completion.self, DimensionProfile.self, StateSnapshot.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        let oldDate = try #require(calendar.date(byAdding: .day, value: -15, to: now))
        context.insert(StateSnapshot(scores: .neutral, actionScores: .neutral, assessedAt: oldDate))
        for dimension in LifeDimension.allCases {
            context.insert(DimensionProfile(dimension: dimension, selfRating: 6, weeklyTarget: 3, lastAssessedAt: oldDate))
        }
        context.insert(Completion(itemID: UUID(), xp: 0, dimension: .health,
            taskTitle: "锻炼", date: now, nominalXP: 80))
        try context.save()
        var observed: StateQuerySnapshot?
        let host = UIHostingController(rootView: StateQueryProbe(now: now, calendar: calendar) {
            observed = $0
        }.modelContainer(container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        #expect(await waitUntil { observed?.snapshotCount == 1 && observed?.selfRating == 6 })
        try StateAssessmentStore.skipReminder(in: context, now: now, calendar: calendar)
        #expect(await waitUntil { observed?.skippedAt == now })
        let answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map { ($0.id, AssessmentAnswer.neutral) })
        try StateAssessmentStore.submit(answers: answers, weeklyTargets: [:], in: context, now: now, calendar: calendar)
        #expect(await waitUntil { observed?.snapshotCount == 2 && observed?.selfRating == 5 })
        #expect(observed?.skippedAt == nil)
        #expect(abs((observed?.currentHealth ?? 0) - (5 + 1.0 / 7)) < 0.00001)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
        for _ in 0..<150 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}

private struct StateQuerySnapshot: Equatable {
    let snapshotCount: Int
    let selfRating: Double?
    let currentHealth: Double?
    let skippedAt: Date?
}

private struct StateQueryProbe: View {
    @Query(sort: \StateSnapshot.assessedAt, order: .reverse) private var snapshots: [StateSnapshot]
    @Query private var profiles: [DimensionProfile]
    @Query private var completions: [Completion]
    let now: Date
    let calendar: Calendar
    let observe: (StateQuerySnapshot) -> Void

    private var state: StateQuerySnapshot {
        let summary = snapshots.first.map {
            LifeStateSummaryBuilder.build(profiles: profiles, snapshot: $0,
                activities: completions.compactMap { $0.stateActivity(fallbackItem: nil) },
                now: now, calendar: calendar)
        }
        return StateQuerySnapshot(snapshotCount: snapshots.count,
            selfRating: profiles.first { $0.dimension == .health }?.selfRating,
            currentHealth: summary?.projected.health, skippedAt: snapshots.first?.reminderSkippedAt)
    }

    var body: some View {
        Text("状态")
            .onChange(of: state, initial: true) { _, value in observe(value) }
    }
}
