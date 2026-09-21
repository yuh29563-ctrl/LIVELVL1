import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct CollectionTarotPresentationTests {
    @Test func emptyArchiveKeepsTheDailyTarotEntryAvailable() async throws {
        let container = try ModelContainer(
            for: Schema([
                OwnedCollectible.self,
                CollectionProgress.self,
                TarotDailyState.self,
            ]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let controller = UIHostingController(
            rootView: CollectionView().modelContainer(container)
        )
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
        }

        #expect(await waitUntil {
            accessibilityIdentifiers(in: window).contains("collection-tarot-entry")
        })
    }

    @Test func presentingTarotKeepsTheUnderlyingTabBarVisible() async throws {
        let container = try ModelContainer(
            for: Schema([
                OwnedCollectible.self,
                CollectionProgress.self,
                TarotDailyState.self,
            ]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let rootView = TabView {
            CollectionView(initiallyShowsTarot: true)
                .tabItem { Label("收集", systemImage: "square.grid.3x3.fill") }
        }
        .modelContainer(container)
        let controller = UIHostingController(rootView: rootView)
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
        }

        #expect(await waitUntil {
            accessibilityIdentifiers(in: window).contains("tarot-daily-view")
        })
        let tabBar = try #require(
            allSubviews(in: window).compactMap { $0 as? UITabBar }.first
        )
        #expect(!tabBar.isHidden)
        #expect(tabBar.alpha == 1)
    }

    private func accessibilityIdentifiers(in view: UIView) -> [String] {
        var identifiers = view.accessibilityIdentifier.map { [$0] } ?? []
        if let elements = view.accessibilityElements {
            identifiers.append(contentsOf: elements.compactMap { element in
                if let view = element as? UIView {
                    return view.accessibilityIdentifier
                }
                if let element = element as? UIAccessibilityElement {
                    return element.accessibilityIdentifier
                }
                return nil
            })
        }
        for subview in view.subviews {
            identifiers.append(contentsOf: accessibilityIdentifiers(in: subview))
        }
        return identifiers
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + allSubviews(in: $0) }
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

}
