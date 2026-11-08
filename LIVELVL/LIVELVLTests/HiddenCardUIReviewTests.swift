import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct HiddenCardUIReviewTests {
    private func capture<V: View>(_ view: V, named name: String, delay: Double = 0.6) async throws {
        let host = UIHostingController(rootView: view
            .environment(\.scenePhase, .active))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = UIScreen.main.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .seconds(delay))
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let pixels = try #require(image.cgImage?.dataProvider?.data) as Data
        #expect(stride(from: 0, to: pixels.count, by: 400).contains { pixels[$0] > 10 })
        let data = try #require(image.pngData())
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hidden-ui-\(name).png")
        try data.write(to: path)
        #expect(window.bounds.height > 800)
        print("HIDDEN_UI_ARTIFACT:\(path.path)")
    }

    @Test func rendersRewardLibraryAndBothFacesUsingIsolatedData() async throws {
        let schema = Schema([Item.self, LIVELVL.Progress.self, Completion.self,
            DimensionProfile.self, StateSnapshot.self, CollectionProgress.self,
            OwnedCollectible.self, PendingCardReward.self, UserCardMedia.self,
            CoinTransaction.self, RewardProduct.self, RewardRedemption.self,
            JournalEntry.self, TarotDailyState.self])
        let container = try ModelContainer(for: schema, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date.now
        let progress = LIVELVL.Progress()
        context.insert(progress)
        context.insert(StateSnapshot(scores: LifeStateValues(repeating: 60),
                                     actionScores: LifeStateValues(repeating: 0), assessedAt: now))
        try context.save()
        try CardRewardService.activateHiddenCards(in: context, now: now.addingTimeInterval(-1), calendar: .current)
        #expect(CollectionCatalog.visibleDefinitions(ownedIDs: []).count == 111)
        try await capture(NavigationStack { CatalogView() }.modelContainer(container), named: "locked-catalog")
        let record = Completion(itemID: UUID(), xp: 0, dimension: .health, date: now)
        context.insert(record); try context.save()
        try CardRewardService.processCompletion(progress: progress, previousLevel: 0,
            completions: [record], in: context, now: now, calendar: .current)
        try await capture(MainTabView().modelContainer(container), named: "first-reward", delay: 1.8)
        #expect(try CardRewardClaimCoordinator.claim(awardKey: "hidden.health.first", in: context, now: .now))
        let owned = try #require(context.fetch(FetchDescriptor<OwnedCollectible>()).first)
        let definition = try #require(CollectionCatalog.definition(id: owned.collectibleID))
        let item = ArchiveCollectiblePresentation(collectible: owned, definition: definition)
        try await capture(ArchiveExpandedView(item: item, isShowingBack: .constant(false), onClose: {})
            .background(TodayVisualTheme.pageBackground), named: "front")
        try await capture(ArchiveExpandedView(item: item, isShowingBack: .constant(true), onClose: {})
            .background(TodayVisualTheme.pageBackground), named: "back")
        try await capture(MainTabView(debugInitialTab: .collection).modelContainer(container), named: "collection")
        #expect(CollectionCatalog.visibleDefinitions(ownedIDs: [owned.collectibleID]).count == 112)
    }
}
