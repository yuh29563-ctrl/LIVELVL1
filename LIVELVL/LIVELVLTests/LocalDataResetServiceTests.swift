import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct LocalDataResetServiceTests {
    private enum ForcedResetError: LocalizedError {
        case save
        case remove

        var errorDescription: String? {
            switch self {
            case .save: "测试保存错误"
            case .remove: "测试文件错误"
            }
        }
    }

    @Test func resetDeletesJournalEntries() throws {
        let container = try ModelContainer(
            for: Schema([JournalEntry.self]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(JournalEntry(
            dayKey: "2026-09-06|Asia/Shanghai",
            dayStart: Date(timeIntervalSince1970: 0),
            timeZoneIdentifier: "Asia/Shanghai",
            title: "今天",
            body: "应该被清除",
            state: .draft,
            now: Date(timeIntervalSince1970: 0)
        ))
        try context.save()

        try LocalDataResetService.reset(
            context: context,
            fileManager: .default,
            applicationSupportURL: FileManager.default.temporaryDirectory
        )

        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }

    @Test func resetDeletesTheDailyTarotState() throws {
        let container = try ModelContainer(
            for: Schema([TarotDailyState.self]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(TarotDailyState(
            dayIdentifier: "2026-09-16",
            candidateCardIDs: Array(TarotCatalog.cardIDs.prefix(3)),
            candidateOrientations: [.upright, .reversed, .upright]
        ))
        try context.save()

        try LocalDataResetService.reset(
            context: context,
            fileManager: .default,
            applicationSupportURL: FileManager.default.temporaryDirectory
        )

        #expect(try context.fetch(FetchDescriptor<TarotDailyState>()).isEmpty)
    }

    @Test func resetDeletesRewardLedgerProductsRedemptionsAndImages() throws {
        let schema = Schema([
            CoinTransaction.self,
            RewardProduct.self,
            RewardRedemption.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let product = RewardProduct(name: "看电影", priceCoinUnits: 50)
        context.insert(CoinTransaction(
            operationKey: "reset-coin",
            kind: .legacyImport,
            amountCoinUnits: 50,
            requestedCoinUnits: 50,
            sourceID: nil,
            createdAt: .now,
            note: "测试"
        ))
        context.insert(product)
        context.insert(RewardRedemption(
            requestKey: "reset-redemption",
            productID: product.id,
            productNameSnapshot: product.name,
            priceCoinUnitsSnapshot: product.priceCoinUnits,
            noteSnapshot: product.note,
            imageReferenceSnapshot: nil,
            redeemedAt: .now,
            status: .pending
        ))
        try context.save()

        let applicationSupportURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: imageDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: imageDirectoryURL.appending(path: "sample.image"))
        defer { try? FileManager.default.removeItem(at: applicationSupportURL) }

        try LocalDataResetService.reset(
            context: context,
            fileManager: .default,
            applicationSupportURL: applicationSupportURL
        )

        #expect(try context.fetch(FetchDescriptor<CoinTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RewardProduct>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RewardRedemption>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: imageDirectoryURL.path))
    }

    @Test func hostedResetActionPresentsPartialFailureAfterSnapshotDeletion() async throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        insertEveryModel(in: context, suffix: "hosted-reset")
        try context.save()

        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: imageDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: imageDirectoryURL.appending(path: "sample.bin"))

        let expectedMessage = "数据记录已清除，但奖励图片清理失败：测试文件错误"
        let resetTrigger = ProfileView.DebugResetActionTrigger()
        let resetConfiguration = ProfileView.DebugResetActionConfiguration(
            applicationSupportURL: { applicationSupportURL },
            removeItem: { _, _ in throw ForcedResetError.remove }
        )
        let hostingController = UIHostingController(
            rootView: ContentView(
                debugResetActionConfiguration: resetConfiguration,
                debugResetActionTrigger: resetTrigger,
                debugInitialTab: .profile
            )
                .modelContainer(container)
        )
        let previousKeyWindow = currentKeyWindow()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        defer {
            hostingController.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
            try? fileManager.removeItem(at: applicationSupportURL)
        }

        #expect(await waitUntil { resetTrigger.isReady })
        #expect(hostingController.view.window === window)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).count == 1)
        #expect(
            !accessibilityIdentifiers(in: hostingController.view)
                .contains("content-root-initial-assessment")
        )

        #expect(resetTrigger.perform())

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).isEmpty)
        #expect(fileManager.fileExists(atPath: imageDirectoryURL.path))

        #expect(
            await waitUntil {
                accessibilityIdentifiers(in: hostingController.view)
                    .contains("content-root-initial-assessment")
            }
        )
        #expect(await waitUntil { hostingController.presentedViewController != nil })

        let alertController = hostingController.presentedViewController as? UIAlertController
        #expect(alertController?.title == "重置未完成")
        #expect(alertController?.message == expectedMessage)

        alertController?.dismiss(animated: false)
        #expect(await waitUntil { hostingController.presentedViewController == nil })
    }

    @Test func imageRemovalFailureReportsPartialResetAndKeepsImageDirectory() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        insertEveryModel(in: context, suffix: "remove-failure")
        try context.save()

        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        let unrelatedURL = applicationSupportURL.appending(path: "keep.bin")
        try fileManager.createDirectory(
            at: imageDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: imageDirectoryURL.appending(path: "sample.bin"))
        try Data([0x02]).write(to: unrelatedURL)
        defer { try? fileManager.removeItem(at: applicationSupportURL) }

        var errorMessage: String?
        do {
            try LocalDataResetService.reset(
                context: context,
                fileManager: fileManager,
                applicationSupportURL: applicationSupportURL,
                removeItem: { _, _ in throw ForcedResetError.remove }
            )
            Issue.record("Expected image removal to fail")
        } catch {
            errorMessage = error.localizedDescription
        }

        #expect(errorMessage?.contains("数据记录已清除") == true)
        #expect(errorMessage?.contains("奖励图片清理失败") == true)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).isEmpty)
        #expect(fileManager.fileExists(atPath: imageDirectoryURL.path))
        #expect(fileManager.fileExists(atPath: unrelatedURL.path))
    }

    @Test func saveFailureRollsBackEveryStagedDeletion() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        insertEveryModel(in: context, suffix: "saved")
        try context.save()

        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: imageDirectoryURL,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: applicationSupportURL) }

        #expect(throws: ForcedResetError.save) {
            try LocalDataResetService.reset(
                context: context,
                fileManager: fileManager,
                applicationSupportURL: applicationSupportURL,
                save: { _ in throw ForcedResetError.save }
            )
        }

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Completion>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).count == 1)
        #expect(fileManager.fileExists(atPath: imageDirectoryURL.path))
    }

    @Test func resetDiscardsUnsavedInsertedModelsBeforeDeletion() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        insertEveryModel(in: context, suffix: "unsaved")

        try LocalDataResetService.reset(
            context: context,
            fileManager: .default,
            applicationSupportURL: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        )

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).isEmpty)
    }

    @Test func resetDeletesEveryBusinessModelAndOnlyRewardProductImages() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let item = Item(
            title: "测试行动",
            dimension: .learning,
            minutes: 30,
            difficulty: 2,
            xp: 25,
            recurrence: .once
        )
        context.insert(PendingCardReward(
            awardKey: "pending",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            maturityLevel: 1,
            triggeredAt: timestamp,
            eligibleAt: timestamp
        ))
        context.insert(OwnedCollectible(
            awardKey: "owned",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            acquiredAt: timestamp
        ))
        context.insert(CollectionProgress())
        context.insert(Completion(
            itemID: item.id,
            xp: 25,
            dimension: .learning,
            durationMinutes: 30,
            taskTitle: "测试行动",
            date: timestamp
        ))
        context.insert(item)
        context.insert(Progress(totalXP: 25))
        context.insert(StateSnapshot(
            scores: LifeStateValues(repeating: 6),
            actionScores: LifeStateValues(repeating: 5),
            assessedAt: timestamp
        ))
        context.insert(DimensionProfile(
            dimension: .learning,
            selfRating: 6,
            weeklyTarget: 3,
            lastAssessedAt: timestamp
        ))
        try context.save()

        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rewardProductImagesURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        let unrelatedURL = applicationSupportURL.appending(path: "keep.bin")
        try fileManager.createDirectory(
            at: rewardProductImagesURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: rewardProductImagesURL.appending(path: "sample.bin"))
        try Data([0x02]).write(to: unrelatedURL)
        defer { try? fileManager.removeItem(at: applicationSupportURL) }

        try LocalDataResetService.reset(
            context: context,
            fileManager: fileManager,
            applicationSupportURL: applicationSupportURL
        )

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).isEmpty)
        #expect(!fileManager.fileExists(atPath: rewardProductImagesURL.path))
        #expect(fileManager.fileExists(atPath: unrelatedURL.path))
    }

    private func insertEveryModel(in context: ModelContext, suffix: String) {
        let timestamp = Date(timeIntervalSince1970: 2_000)
        let item = Item(
            title: "测试行动 \(suffix)",
            dimension: .learning,
            minutes: 30,
            difficulty: 2,
            xp: 25,
            recurrence: .once
        )
        context.insert(PendingCardReward(
            awardKey: "pending.\(suffix)",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            maturityLevel: 1,
            triggeredAt: timestamp,
            eligibleAt: timestamp
        ))
        context.insert(OwnedCollectible(
            awardKey: "owned.\(suffix)",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            acquiredAt: timestamp
        ))
        context.insert(CollectionProgress(singletonKey: "collection.\(suffix)"))
        context.insert(Completion(
            itemID: item.id,
            xp: 25,
            dimension: .learning,
            durationMinutes: 30,
            taskTitle: item.title,
            date: timestamp
        ))
        context.insert(item)
        context.insert(Progress(totalXP: 25))
        context.insert(StateSnapshot(
            scores: LifeStateValues(repeating: 6),
            actionScores: LifeStateValues(repeating: 5),
            assessedAt: timestamp
        ))
        context.insert(DimensionProfile(
            dimension: .learning,
            selfRating: 6,
            weeklyTarget: 3,
            lastAssessedAt: timestamp
        ))
    }

    private func accessibilityIdentifiers(in view: UIView) -> [String] {
        var identifiers = view.accessibilityIdentifier.map { [$0] } ?? []
        if let elements = view.accessibilityElements {
            for element in elements {
                if let identifier = accessibilityIdentifier(for: element) {
                    identifiers.append(identifier)
                }
            }
        }
        let elementCount = view.accessibilityElementCount()
        if elementCount > 0 {
            for index in 0..<elementCount {
                if let element = view.accessibilityElement(at: index),
                   let identifier = accessibilityIdentifier(for: element) {
                    identifiers.append(identifier)
                }
            }
        }
        for subview in view.subviews {
            identifiers.append(contentsOf: accessibilityIdentifiers(in: subview))
        }
        return identifiers
    }

    private func accessibilityIdentifier(for element: Any) -> String? {
        if let view = element as? UIView {
            return view.accessibilityIdentifier
        }
        if let element = element as? UIAccessibilityElement {
            return element.accessibilityIdentifier
        }
        return nil
    }

    private func currentKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
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
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }

        return condition()
    }
}
