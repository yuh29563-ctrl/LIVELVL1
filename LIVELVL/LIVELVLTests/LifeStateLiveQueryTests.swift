import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct LifeStateLiveQueryTests {
    @Test func firstAssessmentReplacesIntroductionWithTodayWithoutRestart() async throws {
        let container = try fullContainer()
        let host = UIHostingController(rootView: ContentView().modelContainer(container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        #expect(await waitUntil { host.view.window != nil })
        #expect(tabController(in: host) == nil)
        let session = StateAssessmentSession()
        session.start()
        session.answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map { ($0.id, AssessmentAnswer.neutral) })
        for _ in 0..<6 { try session.advance(in: container.mainContext) }
        #expect(await waitUntil { self.tabController(in: host)?.selectedIndex == 0 })
    }

    @Test func successfulAssessmentFromProfileReturnsToToday() async throws {
        let container = try fullContainer()
        let context = container.mainContext
        let oldDate = try #require(Calendar.current.date(byAdding: .day, value: -16, to: .now))
        context.insert(StateSnapshot(scores: .neutral, actionScores: .neutral, assessedAt: oldDate))
        try context.save()
        let host = UIHostingController(rootView: MainTabView(debugInitialTab: .profile).modelContainer(container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        #expect(await waitUntil { self.tabController(in: host)?.selectedIndex == 3 })
        let session = StateAssessmentSession()
        session.start()
        session.answers = Dictionary(uniqueKeysWithValues: AssessmentQuestionnaire.questions.map { ($0.id, AssessmentAnswer.neutral) })
        for _ in 0..<6 { try session.advance(in: context) }
        #expect(session.phase == .completed)
        #expect(await waitUntil { self.tabController(in: host)?.selectedIndex == 0 })
    }

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
        let session = StateAssessmentSession()
        session.start()
        for (index, dimension) in LifeDimension.allCases.enumerated() {
            for question in AssessmentQuestionnaire.questions(for: dimension) {
                session.answers[question.id] = .neutral
            }
            #expect(try session.advance(in: context, now: now, calendar: calendar) == (index == 5))
        }
        #expect(session.phase == .completed)
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

    private func tabController(in controller: UIViewController) -> UITabBarController? {
        if let tab = controller as? UITabBarController { return tab }
        for child in controller.children {
            if let tab = tabController(in: child) { return tab }
        }
        return nil
    }

    private func fullContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema([
            Item.self, Progress.self, Completion.self, DimensionProfile.self, StateSnapshot.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self, UserCardMedia.self,
            CoinTransaction.self, RewardProduct.self, RewardRedemption.self, JournalEntry.self, TarotDailyState.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
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
