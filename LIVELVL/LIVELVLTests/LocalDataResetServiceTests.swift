import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct LocalDataResetServiceTests {
    private enum ForcedResetError: Error {
        case save
        case remove
    }

    @Test func partialFailureRemainsPresentableAfterSnapshotDeletion() throws {
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
        insertEveryModel(in: context, suffix: "root-presentation")
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

        var rootPresentation: LocalDataResetFailure?
        LocalDataResetAction.perform(
            context: context,
            fileManager: fileManager,
            applicationSupportURL: applicationSupportURL,
            removeItem: { _, _ in throw ForcedResetError.remove },
            reportFailure: { rootPresentation = $0 }
        )

        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(rootPresentation?.title == "重置未完成")
        #expect(rootPresentation?.message.contains("数据记录已清除") == true)
        #expect(rootPresentation?.message.contains("奖励图片清理失败") == true)
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
}
