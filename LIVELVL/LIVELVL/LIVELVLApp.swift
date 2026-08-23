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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self, Progress.self, Completion.self,
            DimensionProfile.self, StateSnapshot.self,
            CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
