import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct DailyTaskXPPresentationTests {
    @Test func committedPartialAndZeroXPThenRevokeRefreshLiveQueries() async throws {
        let container = try ModelContainer(for: Schema([
            Item.self, LIVELVL.Progress.self, Completion.self,
            DimensionProfile.self, StateSnapshot.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
            CoinTransaction.self, JournalEntry.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = LIVELVL.Progress(totalXP: 350)
        let task = Item(title: "界面测试行动", dimension: .learning, minutes: 30,
                        difficulty: 2, xp: 80, recurrence: .daily)
        let secondTask = Item(title: "封顶行动", dimension: .health, minutes: 60,
                              difficulty: 2, xp: 80, recurrence: .daily)
        context.insert(progress)
        context.insert(task)
        context.insert(secondTask)
        context.insert(Completion(itemID: UUID(), xp: 350, date: .now))
        try context.save()
        var observed: TaskXPQuerySnapshot?
        let host = UIHostingController(rootView: TaskXPQueryProbe { observed = $0 }
            .modelContainer(container))
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
        #expect(await waitUntil { observed?.totalXP == 350 && observed?.awards == [350] })

        let result = try TaskRewardCoordinator.complete(item: task, progress: progress, in: context)
        #expect(await waitUntil { observed?.totalXP == 400 && observed?.awards == [50, 350] })
        try CardRewardService.reconcilePersistedRewards(in: context, now: .now, calendar: .current)
        #expect(await waitUntil { observed?.pendingKeys == ["ordinary.level.1"] })
        try TaskRewardCoordinator.complete(item: secondTask, progress: progress, in: context)
        #expect(await waitUntil { observed?.totalXP == 400 && observed?.awards == [0, 50, 350] })
        try TaskRewardCoordinator.revoke(completion: result.completion, progress: progress, in: context)
        #expect(await waitUntil { observed?.totalXP == 350 && observed?.awards == [0, 350] })
        #expect(progress.totalXP == 350)
    }

    private func waitUntil(condition: @escaping @MainActor () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}

private struct TaskXPQuerySnapshot: Equatable {
    let totalXP: Int
    let awards: [Int]
    let pendingKeys: [String]
}

// Observes the same live SwiftData inputs as Today. This protects the boundary
// between the isolated writer and SwiftUI, without depending on simulator AX internals.
private struct TaskXPQueryProbe: View {
    @Query private var progress: [LIVELVL.Progress]
    @Query private var completions: [Completion]
    @Query private var pending: [PendingCardReward]
    let onChange: (TaskXPQuerySnapshot) -> Void

    private var snapshot: TaskXPQuerySnapshot {
        TaskXPQuerySnapshot(totalXP: progress.first?.totalXP ?? 0,
                            awards: completions.map(\.xp).sorted(), pendingKeys: pending.map(\.awardKey).sorted())
    }

    var body: some View {
        Text("\(snapshot.totalXP) XP")
            .onChange(of: snapshot, initial: true) { _, value in onChange(value) }
    }
}
