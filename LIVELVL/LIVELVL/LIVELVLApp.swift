//
//  LIVELVLApp.swift
//  LIVELVL
//
//  Created by FY on 2026/8/18.
//

import SwiftUI
import SwiftData

@main
struct LIVELVLApp: App {
    // Lazy initialization keeps the standalone design preview away from the user's store.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self, Progress.self, Completion.self,
            DimensionProfile.self, StateSnapshot.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
            UserCardMedia.self,
            CoinTransaction.self, RewardProduct.self, RewardRedemption.self,
            JournalEntry.self,
            TarotDailyState.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--assessment-intro-preview") {
                AssessmentIntroductionPreview()
            } else {
                ContentView().modelContainer(Self.sharedModelContainer)
            }
#else
            ContentView().modelContainer(Self.sharedModelContainer)
#endif
        }
    }
}
